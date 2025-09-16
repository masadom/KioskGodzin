import 'dart:convert';
import 'package:http/http.dart' as http;

/// Używaj URL w postaci: http://<host>:<port>/api  (UWAGA: /api na końcu!)
/// Przykład: EmployeesApi(baseUrl: 'http://192.168.1.50:3000/api')
class EmployeesApi {
  final String baseUrl;
  final http.Client _http;

  String? _bearerToken;

  EmployeesApi({required String baseUrl, http.Client? httpClient})
    : baseUrl = _normalizeBase(baseUrl),
      _http = httpClient ?? http.Client();

  /// Ustaw token po zalogowaniu admina
  void setAuthToken(String? token) {
    _bearerToken = token;
  }

  /// ---------- PUBLICZNE METODY (używaj w zakładkach) ----------

  /// Lista pracowników (zakładka „Pracownicy”)
  Future<List<dynamic>> fetchEmployees() async {
    final json = await _getJson('/admin/employees');
    final ok = json['ok'] == true;
    if (!ok || json['data'] is! List) {
      throw const FormatException(
        'Niepoprawny format JSON dla /admin/employees.',
      );
    }
    return json['data'] as List<dynamic>;
  }

  /// Podsumowanie (zakładka „Podsumowanie”/„Dashboard”)
  Future<Map<String, dynamic>> fetchSummary() async {
    final json = await _getJson('/admin/summary');
    final ok = json['ok'] == true;
    if (!ok || json['data'] is! Map) {
      throw const FormatException(
        'Niepoprawny format JSON dla /admin/summary.',
      );
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  /// Ostatnie zdarzenia (zakładka „Zdarzenia”/„Logi”)
  Future<List<dynamic>> fetchEvents({int limit = 500}) async {
    final json = await _getJson('/admin/events');
    final ok = json['ok'] == true;
    if (!ok || json['data'] is! List) {
      throw const FormatException('Niepoprawny format JSON dla /admin/events.');
    }
    final list = json['data'] as List;
    // Opcjonalnie przytnij po stronie klienta
    return list.length > limit ? list.sublist(list.length - limit) : list;
  }

  /// Ustawienia (prosta zakładka)
  Future<Map<String, dynamic>> fetchSettings() async {
    final json = await _getJson('/admin/settings');
    final ok = json['ok'] == true;
    if (!ok || json['data'] is! Map) {
      throw const FormatException(
        'Niepoprawny format JSON dla /admin/settings.',
      );
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  /// ---------- POMOCNICZE: CRUD pracowników (jeśli używasz z UI) ----------

  Future<Map<String, dynamic>> createEmployee({
    required String name,
    String? cardUid, // jeśli nie używacie kart, nie podawaj
    bool active = true,
  }) async {
    final json = await _postJson(
      '/admin/employees',
      body: {
        'name': name,
        if (cardUid != null && cardUid.isNotEmpty) 'cardUid': cardUid,
        'active': active,
      },
    );
    if (json['ok'] != true || json['data'] is! Map) {
      throw const FormatException('Nie udało się dodać pracownika.');
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  Future<Map<String, dynamic>> updateEmployee(
    int id, {
    String? name,
    String? cardUid,
    bool? active,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (cardUid != null) body['cardUid'] = cardUid;
    if (active != null) body['active'] = active;

    final json = await _putJson('/admin/employees/$id', body: body);
    if (json['ok'] != true || json['data'] is! Map) {
      throw const FormatException('Nie udało się zaktualizować pracownika.');
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  Future<void> deleteEmployee(int id) async {
    final json = await _deleteJson('/admin/employees/$id');
    if (json['ok'] != true) {
      throw const FormatException('Nie udało się usunąć pracownika.');
    }
  }

  /// ---------- RDZEŃ: BEZPIECZNE REQUESTY JSON ----------

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _makeUri(path);
    final resp = await _http.get(uri, headers: _headers(extra: headers));

    _ensureSuccessStatus(resp);
    return _decodeJsonOrThrow(resp);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _makeUri(path);
    final resp = await _http.post(
      uri,
      headers: _headers(extra: headers),
      body: jsonEncode(body),
    );

    _ensureSuccessStatus(resp);
    return _decodeJsonOrThrow(resp);
  }

  Future<Map<String, dynamic>> _putJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final uri = _makeUri(path);
    final resp = await _http.put(
      uri,
      headers: _headers(extra: headers),
      body: jsonEncode(body),
    );

    _ensureSuccessStatus(resp);
    return _decodeJsonOrThrow(resp);
  }

  Future<Map<String, dynamic>> _deleteJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final uri = _makeUri(path);
    final resp = await _http.delete(uri, headers: _headers(extra: headers));

    _ensureSuccessStatus(resp);
    return _decodeJsonOrThrow(resp);
  }

  /// ---------- NISKIE POZIOMY: walidacja i dekodowanie ----------

  Map<String, String> _headers({Map<String, String>? extra}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (_bearerToken != null && _bearerToken!.isNotEmpty)
        'Authorization': 'Bearer $_bearerToken',
      ...?extra,
    };
  }

  Uri _makeUri(String path) {
    // pilnujemy pojedynczych ukośników: baseUrl(/api) + /coś
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  void _ensureSuccessStatus(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final preview = resp.body.trim();
      if (preview.startsWith('<!DOCTYPE') || preview.startsWith('<html')) {
        throw const FormatException(
          'Serwer zwrócił HTML (prawdopodobnie nie-/api, 404 lub proxy).',
        );
      }
      throw FormatException(
        'HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? 'Error'}',
      );
    }
  }

  Map<String, dynamic> _decodeJsonOrThrow(http.Response resp) {
    final ct = resp.headers['content-type'] ?? '';
    final body = resp.body.trim();

    // Twardy check na HTML
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      throw const FormatException(
        'Serwer zwrócił HTML zamiast JSON. Sprawdź bazowy adres /api.',
      );
    }

    // Czasem serwer nie ustawia poprawnie Content-Type – próbujemy z dekoderem
    try {
      final parsed = jsonDecode(body);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Niepoprawny JSON (oczekiwano obiektu).');
      }
      return parsed;
    } catch (e) {
      throw FormatException('Błąd dekodowania JSON: $e');
    }
  }

  /// Zapewnij, że baseUrl zawsze kończy się na /api (bez podwójnych ukośników)
  static String _normalizeBase(String input) {
    var s = input.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    // jeśli ktoś podał bez /api – dopnij
    if (!s.toLowerCase().endsWith('/api')) {
      s = '$s/api';
    }
    return s;
  }
}
