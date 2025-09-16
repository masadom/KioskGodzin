import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kiosk_godzin/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'package:flutter/foundation.dart'; // dla debugPrint
import 'settings_service.dart';
import '../config.dart'; // jeśli używasz AppConfig.baseUrl fallback

class AuthService {
  static const _kToken = 'admin_jwt';

  static Future<String?> get token async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  static get instance => null;

  static Future<void> setToken(String? t) async {
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove(_kToken);
    } else {
      await p.setString(_kToken, t);
    }
  }

  static Future<bool> login(String password) async {
    final base =
        await SettingsService.getBaseUrl() ?? AppConfig.baseUrl; // fallback!
    final normalized = SettingsService.normalizeBaseUrl(base);
    final url = Uri.parse('$normalized/auth/login');

    try {
      debugPrint('[Auth] POST $url'); // << LOG
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}),
      );
      debugPrint('[Auth] status=${res.statusCode} body=${res.body}'); // << LOG

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final t = json['token'] as String?;
        if (t != null) {
          await setToken(t);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[Auth] error: $e'); // << LOG
      return false;
    }
  }

  static Future<void> logout() => setToken(null);

  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final base = await SettingsService.getBaseUrl() ?? AppConfig.baseUrl;
    final url = Uri.parse(
      '${SettingsService.normalizeBaseUrl(base)}/auth/change-password',
    );

    try {
      final token = await AuthService.token;
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      debugPrint(
        '[Auth] change-password status=${res.statusCode} body=${res.body}',
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[Auth] change-password error: $e');
      return false;
    }
  }
}
