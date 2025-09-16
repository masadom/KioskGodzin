import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/admin_entry_screen.dart';
import 'config.dart';
// UWAGA: import db.dart zostawiamy, ale nie odpalamy go na webie
import 'data/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-inicjalizacja SQLite tylko wtedy, gdy:
  // - nie jesteśmy na webie
  // - i nie używamy zdalnego API (mock/serwer)
  if (!kIsWeb && !AppConfig.useRemote) {
    await AppDatabase.instance.db;
  }

  runApp(const TimeKioskApp());
}

class TimeKioskApp extends StatelessWidget {
  const TimeKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kiosk Czasu Pracy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginScreen(),
        // Web: przejdź pod http://localhost:PORT/#/admin
        '/admin': (_) => const AdminEntryScreen(),
      },
    );
  }
}
