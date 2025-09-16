import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Serwis autoryzacji dla panelu admina kiosku.
///
/// Backend (gateway.js):
/// - POST /api/admin/login            { password }
/// - POST /api/admin/password         { currentPassword, newPassword }   (Bearer)
class AuthService {
  // ========= SINGLETON / KONFIG =========
  static AuthService? _instance;

  /// Zainicjalizuj singleton (wywołaj raz na starcie aplikacji).
  static void configure({required String baseUrl, http.Client? httpClient}) {
    _instance = AuthService._internal(baseUrl: baseUrl, httpClient: httpClient);
  }

  /// Dostęp do instancji (rzuci, jeśli nie skonfigurowano).
  static AuthService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'AuthService not configured. Call AuthService.configure(baseUrl: ...) before using it.',
      );
    }
    return i;
  }

  /// Statyczne WRAPPERY — żeby działały istniejące wywołania typu:
  /// AuthService.login(...), AuthService.logout(), AuthService.changePassword(...)
  static Future<String> login(String password) => instance._login(password);
  static Future<String> token() => instance._token();
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => instance._changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );
  static Future<bool> logout() => instance._logout();

  // ========= INSTANCJA =========

  final String
  baseUrl; // np. 'http://192.168.50.96:3000' (bez /api też może być)
  final http.Client _http;

  String? _memToken;
  static const _tokenKey = 'authToken';

  AuthService._internal({required this.baseUrl, http.Client? httpClient})
    : _http = (httpClient ?? http.Client());

  // ------------------------------ PUBLIC (instancyjne) ------------------------------

  /// Logowanie — instancyjnie (wrapper statyczny wyżej).
  Future<String> _login(String password) async {
    final normalized = _normalizeBase(baseUrl); // np. http://host:port/api
    final url = Uri.parse('$normalized/admin/login');

    final body = jsonEncode({'password': password.trim()});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };

    // diag
    // ignore: avoid_print
    print('[Auth] POST $url');
    final resp = await _http.post(url, headers: headers, body: body);
    // ignore: avoid_print
    print('[Auth] status: ${resp.statusCode}');
    final snippet = resp.body.length > 200
        ? resp.body.substring(0, 200)
        : resp.body;
    // ignore: avoid_print
    print('[Auth] body: $snippet');

    if (resp.statusCode != 200) {
      final text = resp.body.trim();
      if (text.startsWith('<!DOCTYPE') || text.startsWith('<html')) {
        throw Exception(
          'Serwer zwrócił HTML zamiast JSON (sprawdź adres API / ścieżkę).',
        );
      }
      throw Exception(
        'HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? 'Error'} – $snippet',
      );
    }

    final Map<String, dynamic> json = _decodeJsonObject(resp.body);
    if (json['ok'] == true && json['token'] is String) {
      final t = json['token'] as String;
      await _setToken(t);
      return t;
    }

    final err = (json['error'] ?? 'InvalidCredentials').toString();
    final msg = (json['message'] ?? 'Logowanie nieudane').toString();
    throw Exception('$err – $msg');
  }

  /// Zmiana hasła admina — instancyjnie.
  Future<bool> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final normalized = _normalizeBase(baseUrl);
    final url = Uri.parse('$normalized/admin/password');

    final tkn = await _token(); // zawsze zwraca String (może być pusty)
    if (tkn.isEmpty) {
      throw Exception('Brak tokena – najpierw zaloguj się.');
    }

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $tkn',
    };

    final body = jsonEncode({
      'currentPassword': currentPassword.trim(),
      'newPassword': newPassword.trim(),
    });

    // ignore: avoid_print
    print('[Auth] POST $url (change password)');
    final resp = await _http.post(url, headers: headers, body: body);
    // ignore: avoid_print
    print('[Auth] status: ${resp.statusCode}');
    final snippet = resp.body.length > 200
        ? resp.body.substring(0, 200)
        : resp.body;
    // ignore: avoid_print
    print('[Auth] body: $snippet');

    if (resp.statusCode != 200) {
      final text = resp.body.trim();
      if (text.startsWith('<!DOCTYPE') || text.startsWith('<html')) {
        throw Exception(
          'Serwer zwrócił HTML zamiast JSON (sprawdź adres API).',
        );
      }
      throw Exception(
        'HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? 'Error'} – $snippet',
      );
    }

    final Map<String, dynamic> json = _decodeJsonObject(resp.body);
    if (json['ok'] == true) {
      return true;
    }
    final err = (json['error'] ?? 'ChangePasswordFailed').toString();
    final msg = (json['message'] ?? 'Zmiana hasła nieudana').toString();
    throw Exception('$err – $msg');
  }

  /// Wylogowanie — czyści token; zwracamy bool (true), by uniknąć użycia wartości typu void.
  Future<bool> _logout() async {
    _memToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    // ignore: avoid_print
    print('[Auth] logout – token cleared.');
    return true;
  }

  /// Aktualny token (nigdy null; najwyżej pusty string).
  Future<String> _token() async {
    if (_memToken != null) return _memToken!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey) ?? '';
    _memToken = stored.isNotEmpty ? stored : null;
    return _memToken ?? '';
  }

  /// Czy zalogowany.
  Future<bool> isLoggedIn() async {
    final t = await _token();
    return t.isNotEmpty;
  }

  // ------------------------------ INTERNALS ------------------------------

  Future<void> _setToken(String token) async {
    _memToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final text = body.trim();
    if (text.startsWith('<!DOCTYPE') || text.startsWith('<html')) {
      throw Exception('Serwer zwrócił HTML zamiast JSON (sprawdź adres API).');
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Oczekiwano JSON-owego obiektu.');
    } catch (e) {
      throw Exception('Błąd dekodowania JSON: $e');
    }
  }

  /// Usuwa duplikaty protokołu, obcina trailing slash i dopina /api.
  static String _normalizeBase(String input) {
    var s = input.trim();

    // Redukcja wielokrotnego protokołu (np. http://http//host)
    final proto = RegExp(r'^(https?:\/\/)+', caseSensitive: false);
    if (proto.hasMatch(s)) {
      s = s.replaceFirst(
        proto,
        s.toLowerCase().startsWith('https://') ? 'https://' : 'http://',
      );
    } else if (!s.toLowerCase().startsWith('http://') &&
        !s.toLowerCase().startsWith('https://')) {
      s = 'http://$s';
    }

    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (!s.toLowerCase().endsWith('/api')) s = '$s/api';
    return s;
  }
}
