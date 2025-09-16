// lib/data/admin_remote_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/employee.dart';
import '../models/shift.dart';
import '../models/absence.dart';
import 'admin_repository.dart';
import '../services/auth_service.dart';

/// Zdalna implementacja repozytorium – łączy się z gatewayem (Express) lub bezpośrednio z JSON Serverem.
/// UŻYWA BEZWZGLĘDNYCH URL-i (baseUrl) i zawsze dokleja nagłówek Authorization (jeśli token jest).
class AdminRemoteRepository implements AdminRepository {
  AdminRemoteRepository({required this.baseUrl});

  /// Np. http://192.168.50.96:3100  (GATEWAY)  — bez końcowego /
  final String baseUrl;

  // ───────────────────────── Helpers ─────────────────────────

  Uri _u(String pathAndQuery) => Uri.parse('$baseUrl$pathAndQuery');

  Future<Map<String, String>> _headers() async {
    final t = await AuthService.token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  int _asInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  bool _isNullish(dynamic v) =>
      v == null || v.toString().toLowerCase() == 'null' || v.toString().isEmpty;

  /// Stabilny liczbowy ID dla dowolnego `id` z JSON Servera (int/string).
  int _surrogateIdForRaw(dynamic rawId) {
    if (rawId is int && rawId > 0) return rawId;
    final s = rawId?.toString() ?? '';
    final parsed = int.tryParse(s);
    if (parsed != null && parsed > 0) return parsed;
    return s.hashCode & 0x7fffffff; // dodatni hash
  }

  /// Pobierz surową listę z kolekcji (bez mapowania na modele).
  Future<List<Map<String, dynamic>>> _getRaw(
    String collection, {
    String? query,
  }) async {
    final url = query == null ? _u('/$collection') : _u('/$collection?$query');
    final res = await http.get(url, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} GET /$collection: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw Exception('Unexpected response for /$collection');
  }

  /// Znajdź „rawId” (takie jak w db.json) po liczbowym ID lub po surogacie.
  Future<String?> _findRawIdByIntLoose(String collection, int intId) async {
    final rows = await _getRaw(collection);
    for (final m in rows) {
      final raw = m['id'];
      final surr = _surrogateIdForRaw(raw);
      if (surr == intId) return raw?.toString();
      final asInt = _asInt(raw);
      if (asInt == intId) return raw?.toString();
    }
    return null;
  }

  // ───────────────────────── Employees ─────────────────────────

  @override
  Future<List<Employee>> listEmployees({String? search}) async {
    final q = (search == null || search.trim().isEmpty)
        ? null
        : '_sort=id&_order=asc&q=${Uri.encodeQueryComponent(search.trim())}';
    final rows = await _getRaw('employees', query: q ?? '_sort=id&_order=asc');
    return rows
        .map(
          (m) => Employee(
            id: _asInt(m['id']),
            name: (m['name'] ?? '').toString(),
            pin: (m['pin'] ?? '').toString(),
            role: (m['role'] ?? '').toString(),
            shiftNo: m['shift_no'] == null ? null : _asInt(m['shift_no']),
          ),
        )
        .toList();
  }

  @override
  Future<Employee> addEmployee({
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  }) async {
    final body = jsonEncode({
      'name': name,
      'pin': pin,
      'role': role,
      'shift_no': shiftNo,
    });
    final res = await http.post(
      _u('/employees'),
      headers: await _headers(),
      body: body,
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode} POST /employees: ${res.body}');
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Employee(
      id: _asInt(m['id']),
      name: (m['name'] ?? '').toString(),
      pin: (m['pin'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      shiftNo: m['shift_no'] == null ? null : _asInt(m['shift_no']),
    );
  }

  @override
  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  }) async {
    // najpierw spróbuj po /employees/{id}, potem po rawId (dla stringowych ID w db.json)
    final payload = jsonEncode({
      'name': name,
      'pin': pin,
      'role': role,
      'shift_no': shiftNo,
    });

    var res = await http.patch(
      _u('/employees/$id'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode == 200) {
      final m = Map<String, dynamic>.from(jsonDecode(res.body));
      return Employee(
        id: _asInt(m['id']),
        name: (m['name'] ?? '').toString(),
        pin: (m['pin'] ?? '').toString(),
        role: (m['role'] ?? '').toString(),
        shiftNo: m['shift_no'] == null ? null : _asInt(m['shift_no']),
      );
    }
    final rawId = await _findRawIdByIntLoose('employees', id);
    if (rawId == null) {
      throw Exception('Pracownik #$id nie znaleziony (remote)');
    }
    res = await http.patch(
      _u('/employees/$rawId'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'HTTP ${res.statusCode} PATCH /employees/$rawId: ${res.body}',
      );
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Employee(
      id: _asInt(m['id']),
      name: (m['name'] ?? '').toString(),
      pin: (m['pin'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      shiftNo: m['shift_no'] == null ? null : _asInt(m['shift_no']),
    );
  }

  @override
  Future<void> deleteEmployee(int id) async {
    var res = await http.delete(
      _u('/employees/$id'),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;

    // fallback po rawId
    final rawId = await _findRawIdByIntLoose('employees', id);
    if (rawId == null) {
      throw Exception('Pracownik #$id nie istnieje (remote)');
    }
    res = await http.delete(_u('/employees/$rawId'), headers: await _headers());
    if (!(res.statusCode == 200 || res.statusCode == 204)) {
      throw Exception(
        'HTTP ${res.statusCode} DELETE /employees/$rawId: ${res.body}',
      );
    }
  }

  // ───────────────────────── Shifts ─────────────────────────

  @override
  Future<List<Shift>> listShifts({int? employeeId, bool? onlyActive}) async {
    final params = <String>[];
    params.add('_sort=id');
    params.add('_order=desc');
    if (employeeId != null) params.add('employee_id=$employeeId');
    if (onlyActive == true) {
      params.add('ended_at=null');
    } else if (onlyActive == false) {
      params.add('ended_at_ne=null'); // json-server: != null
    }
    final res = await http.get(
      _u('/shifts?${params.join('&')}'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} GET /shifts: ${res.body}');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return list.map((m) {
      final sid = _surrogateIdForRaw(m['id']); // stabilny liczbowy id
      return Shift(
        id: sid,
        employeeId: _asInt(m['employee_id']),
        startedAt: _asDate(m['started_at']) ?? DateTime.now(),
        endedAt: _asDate(m['ended_at']),
      );
    }).toList();
  }

  @override
  Future<void> endShift(int shiftId) async {
    final body = jsonEncode({'ended_at': DateTime.now().toIso8601String()});

    // 1) po int id
    var res = await http.patch(
      _u('/shifts/$shiftId'),
      headers: await _headers(),
      body: body,
    );
    if (res.statusCode == 200) return;

    // 2) fallback po rawId
    final rawId = await _findRawIdByIntLoose('shifts', shiftId);
    if (rawId == null) throw Exception('Nie znaleziono zmiany #$shiftId');

    res = await http.patch(
      _u('/shifts/$rawId'),
      headers: await _headers(),
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'HTTP ${res.statusCode} PATCH /shifts/$rawId: ${res.body}',
      );
    }
  }

  @override
  Future<Shift> updateShift({
    required int shiftId,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) async {
    final payload = jsonEncode({
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    });

    var res = await http.patch(
      _u('/shifts/$shiftId'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode == 200) {
      final m = Map<String, dynamic>.from(jsonDecode(res.body));
      return Shift(
        id: _surrogateIdForRaw(m['id']),
        employeeId: _asInt(m['employee_id']),
        startedAt: _asDate(m['started_at']) ?? startedAt,
        endedAt: _asDate(m['ended_at']),
      );
    }
    final rawId = await _findRawIdByIntLoose('shifts', shiftId);
    if (rawId == null)
      throw Exception('Zmiana #$shiftId nie istnieje (remote)');

    res = await http.patch(
      _u('/shifts/$rawId'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'HTTP ${res.statusCode} PATCH /shifts/$rawId: ${res.body}',
      );
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Shift(
      id: _surrogateIdForRaw(m['id']),
      employeeId: _asInt(m['employee_id']),
      startedAt: _asDate(m['started_at']) ?? startedAt,
      endedAt: _asDate(m['ended_at']),
    );
  }

  @override
  Future<void> deleteShift(int shiftId) async {
    var res = await http.delete(
      _u('/shifts/$shiftId'),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;

    final rawId = await _findRawIdByIntLoose('shifts', shiftId);
    if (rawId == null)
      throw Exception('Zmiana #$shiftId nie istnieje (remote)');

    res = await http.delete(_u('/shifts/$rawId'), headers: await _headers());
    if (!(res.statusCode == 200 || res.statusCode == 204)) {
      throw Exception(
        'HTTP ${res.statusCode} DELETE /shifts/$rawId: ${res.body}',
      );
    }
  }

  @override
  Future<Shift> addShiftManual({
    required int employeeId,
    required DateTime startedAt,
    DateTime? endedAt,
  }) async {
    final payload = jsonEncode({
      'employee_id': employeeId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    });
    final res = await http.post(
      _u('/shifts'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode} POST /shifts: ${res.body}');
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Shift(
      id: _surrogateIdForRaw(m['id']),
      employeeId: _asInt(m['employee_id']),
      startedAt: _asDate(m['started_at']) ?? startedAt,
      endedAt: _asDate(m['ended_at']),
    );
  }

  // ───────────────────────── Dictionaries (roles, work_shifts) ─────────────────────────

  @override
  Future<List<String>> listRoles() async {
    final rows = await _getRaw('roles', query: '_sort=name&_order=asc');
    return rows
        .map((m) => (m['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<void> addRole(String role) async {
    // json-server: sprawdź czy istnieje
    final existing = await _getRaw(
      'roles',
      query: 'name=${Uri.encodeQueryComponent(role)}',
    );
    if (existing.isNotEmpty) return;

    final res = await http.post(
      _u('/roles'),
      headers: await _headers(),
      body: jsonEncode({'name': role}),
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode} POST /roles: ${res.body}');
    }
  }

  @override
  Future<List<int>> listShiftNumbers() async {
    final rows = await _getRaw('work_shifts', query: '_sort=no&_order=asc');
    return rows.map((m) => _asInt(m['no'])).where((n) => n > 0).toList();
  }

  @override
  Future<void> addShiftNumber(int no) async {
    final existing = await _getRaw(
      'work_shifts',
      query: 'no=${Uri.encodeQueryComponent('$no')}',
    );
    if (existing.isNotEmpty) return;

    final res = await http.post(
      _u('/work_shifts'),
      headers: await _headers(),
      body: jsonEncode({'no': no}),
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode} POST /work_shifts: ${res.body}');
    }
  }

  // ───────────────────────── Absences (calendar) ─────────────────────────

  @override
  Future<List<Absence>> listAbsences({required DateTime month}) async {
    // Bierzemy wszystkie, a potem filtrujemy w kliencie – prostsze z json-serverem.
    final res = await http.get(
      _u('/absences?_sort=start_date&_order=asc'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} GET /absences: ${res.body}');
    }
    final rows = (jsonDecode(res.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);

    return rows
        .map((m) {
          return Absence(
            id: _asInt(m['id']),
            employeeId: _asInt(m['employee_id']),
            type: (m['type'] ?? 'URLOP').toString(),
            startDate: _asDate(m['start_date']) ?? first,
            endDate: _asDate(m['end_date']) ?? first,
          );
        })
        .where((a) {
          // przecinają miesiąc
          return a.endDate.isAfter(first) && a.startDate.isBefore(next);
        })
        .toList();
  }

  @override
  Future<Absence> addAbsence({
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await http.post(
      _u('/absences'),
      headers: await _headers(),
      body: jsonEncode({
        'employee_id': employeeId,
        'type': type,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('HTTP ${res.statusCode} POST /absences: ${res.body}');
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Absence(
      id: _asInt(m['id']),
      employeeId: _asInt(m['employee_id']),
      type: (m['type'] ?? '').toString(),
      startDate: _asDate(m['start_date']) ?? startDate,
      endDate: _asDate(m['end_date']) ?? endDate,
    );
  }

  @override
  Future<void> deleteAbsence(int id) async {
    var res = await http.delete(_u('/absences/$id'), headers: await _headers());
    if (res.statusCode == 200 || res.statusCode == 204) return;

    final rawId = await _findRawIdByIntLoose('absences', id);
    if (rawId == null) throw Exception('Absence #$id nie istnieje (remote)');

    res = await http.delete(_u('/absences/$rawId'), headers: await _headers());
    if (!(res.statusCode == 200 || res.statusCode == 204)) {
      throw Exception(
        'HTTP ${res.statusCode} DELETE /absences/$rawId: ${res.body}',
      );
    }
  }

  @override
  Future<Absence> updateAbsence({
    required int id,
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final payload = jsonEncode({
      'employee_id': employeeId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    var res = await http.patch(
      _u('/absences/$id'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode == 200) {
      final m = Map<String, dynamic>.from(jsonDecode(res.body));
      return Absence(
        id: _asInt(m['id']),
        employeeId: _asInt(m['employee_id']),
        type: (m['type'] ?? '').toString(),
        startDate: _asDate(m['start_date']) ?? startDate,
        endDate: _asDate(m['end_date']) ?? endDate,
      );
    }

    final rawId = await _findRawIdByIntLoose('absences', id);
    if (rawId == null) throw Exception('Absence #$id nie istnieje (remote)');

    res = await http.patch(
      _u('/absences/$rawId'),
      headers: await _headers(),
      body: payload,
    );
    if (res.statusCode != 200) {
      throw Exception(
        'HTTP ${res.statusCode} PATCH /absences/$rawId: ${res.body}',
      );
    }
    final m = Map<String, dynamic>.from(jsonDecode(res.body));
    return Absence(
      id: _asInt(m['id']),
      employeeId: _asInt(m['employee_id']),
      type: (m['type'] ?? '').toString(),
      startDate: _asDate(m['start_date']) ?? startDate,
      endDate: _asDate(m['end_date']) ?? endDate,
    );
  }
}
