import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/employee.dart';
import '../models/shift.dart';
import 'shift_repository.dart';

int _asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
String _asString(dynamic v) => v?.toString() ?? '';
DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

bool _isNullish(dynamic v) {
  if (v == null) return true;
  final s = v.toString().trim().toLowerCase();
  return s.isEmpty || s == 'null';
}

class RemoteShiftRepository implements ShiftRepository {
  final String baseUrl;
  RemoteShiftRepository({required this.baseUrl});

  @override
  Future<Employee?> findEmployeeByPin(String pin) async {
    final res = await http.get(Uri.parse('$baseUrl/employees?pin=$pin'));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (list.isEmpty) return null;
    final m = list.first;
    return Employee(
      id: _asInt(m['id']),
      name: _asString(m['name']),
      pin: _asString(m['pin']),
    );
  }

  @override
  Future<Shift?> findActiveShiftForEmployee(int employeeId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/shifts?employee_id=$employeeId&_sort=id&_order=desc'),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final m in list) {
      // Usunięto if _asInt(m['employee_id']) != employeeId, bo API filtruje
      if (_isNullish(m['ended_at'])) {
        final started = _asDate(m['started_at']);
        if (started == null) continue;
        return Shift(
          id: _asInt(
            m['id'],
          ), // lokalnie trzymamy int (0, jeśli id jest nieliczbowe)
          employeeId: employeeId,
          startedAt: started,
          endedAt: null,
        );
      }
    }
    return null;
  }

  @override
  Future<Shift> startShift(int employeeId) async {
    final nowIso = DateTime.now().toIso8601String();
    final res = await http.post(
      Uri.parse('$baseUrl/shifts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'employee_id': employeeId,
        'started_at': nowIso,
        'ended_at': null,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return Shift(
      id: _asInt(m['id']),
      employeeId: _asInt(m['employee_id']),
      startedAt: _asDate(m['started_at']) ?? DateTime.now(),
      endedAt: null,
    );
  }

  @override
  Future<void> endShiftByEmployee(int employeeId) async {
    // Znajdź aktywną zmianę dla pracownika, ustal „surowe” id (może być string) i zapatchuj
    final listRes = await http.get(
      Uri.parse('$baseUrl/shifts?employee_id=$employeeId&_sort=id&_order=desc'),
    );
    if (listRes.statusCode != 200) {
      throw Exception('HTTP ${listRes.statusCode}: ${listRes.body}');
    }
    final list = (jsonDecode(listRes.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    Map<String, dynamic>? active;
    for (final m in list) {
      if (_isNullish(m['ended_at'])) {
        active = m;
        break;
      }
    }
    if (active == null) return;

    final rawId = _asString(active['id']);
    final res = await http.patch(
      Uri.parse('$baseUrl/shifts/$rawId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ended_at': DateTime.now().toIso8601String()}),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
