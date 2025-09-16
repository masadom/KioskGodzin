import 'dart:convert';
import 'package:http/http.dart' as http;

class EmployeesApi {
  final http.Client _client;
  final String baseUrl;
  EmployeesApi(this._client, {required this.baseUrl});

  /// Zwraca true, jeśli JEST już taki PIN (czyli zajęty).
  Future<bool> isPinTaken(String pin, {int? excludeId}) async {
    final uri = Uri.parse('$baseUrl/employees?pin=$pin');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('PIN_CHECK_FAILED (${resp.statusCode})');
    }
    final List list = jsonDecode(resp.body);
    if (excludeId == null) {
      return list.isNotEmpty;
    }
    return list.any((e) => e['id'] != excludeId);
  }

  Future<void> createEmployee(Map<String, dynamic> payload) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/employees'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode == 409) {
      throw Exception('PIN_NOT_UNIQUE');
    }
    if (resp.statusCode >= 400) {
      throw Exception('CREATE_FAILED (${resp.statusCode})');
    }
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> payload) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/employees/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode == 409) {
      throw Exception('PIN_NOT_UNIQUE');
    }
    if (resp.statusCode >= 400) {
      throw Exception('UPDATE_FAILED (${resp.statusCode})');
    }
  }
}
