// lib/config.dart
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Używamy zdalnego API
  static const bool useRemote = true;

  // <<< USTAW ADRES GATEWAYA (port 3100), NIE json-servera >>>
  static const String _gatewayHostPort = '192.168.50.96:3100';

  static String get baseUrl {
    final url = 'http://$_gatewayHostPort';
    // Web i mobile używają tego samego gatewaya
    return url;
  }
}
