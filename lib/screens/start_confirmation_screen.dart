import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../models/employee.dart';

class StartConfirmationScreen extends StatefulWidget {
  final Employee employee;
  final DateTime startedAt;

  const StartConfirmationScreen({
    super.key,
    required this.employee,
    required this.startedAt,
  });

  @override
  State<StartConfirmationScreen> createState() =>
      _StartConfirmationScreenState();
}

class _StartConfirmationScreenState extends State<StartConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    });
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final timeStr = _fmtTime(widget.startedAt);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_fill, size: 96),
            const SizedBox(height: 12),
            Text(
              'Zmiana rozpoczęta o $timeStr',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Pracownik: ${widget.employee.name}',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
