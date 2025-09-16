import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SettingsService {
  static const _kBaseUrl = 'server_base_url';

  /// Zwraca zapamiętany baseUrl (np. http://192.168.1.50:3000) lub null.
  static Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl);
  }

  /// Zapisuje baseUrl po normalizacji (dopina http:// i obcina trailing slash).
  static Future<void> setBaseUrl(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalizeBaseUrl(input);
    await prefs.setString(_kBaseUrl, normalized);
  }

  /// Czyści zapisane ustawienia (opcjonalnie).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBaseUrl);
  }

  /// Prosty “ping” – GET /employees, oczekujemy 200.
  static Future<bool> testConnection(String baseUrl) async {
    try {
      final res = await http.get(
        Uri.parse('${normalizeBaseUrl(baseUrl)}/employees'),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dopina http:// jeśli brak i obcina końcowe /.
  static String normalizeBaseUrl(String input) {
    var s = input.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), '');
    return s;
  }
}
