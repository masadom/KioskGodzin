import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../utils/format.dart';
import '../data/shift_repository.dart';
import 'confirmation_screen.dart';
import 'login_screen.dart';

class ActiveShiftScreen extends StatefulWidget {
  final Employee employee;
  final Shift activeShift;

  const ActiveShiftScreen({
    super.key,
    required this.employee,
    required this.activeShift,
  });

  @override
  State<ActiveShiftScreen> createState() => _ActiveShiftScreenState();
}

class _ActiveShiftScreenState extends State<ActiveShiftScreen> {
  bool _ending = false;

  Future<void> _end() async {
    setState(() => _ending = true);
    final repo = await ShiftRepoProvider.instance;
    final endedAt = DateTime.now();

    try {
      // ZAMIANA: kończymy po employeeId (działa dla stringowych ID w JSON Server)
      await repo.endShiftByEmployee(widget.employee.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ConfirmationScreen(endedAt: endedAt)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zakończyć zmiany: $e')),
      );
    }
  }

  void _logoutWithoutEnding() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final startedStr = fmtDateTimeShort(widget.activeShift.startedAt);
    return Scaffold(
      appBar: AppBar(title: const Text('Aktywna zmiana')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pracownik: ${widget.employee.name}',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Twoja zmiana trwa od: $startedStr',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _ending ? null : _end,
                  child: _ending
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 24.0,
                          ),
                          child: Text(
                            'Zakończ zmianę',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _logoutWithoutEnding,
                  child: const Text('Wyloguj (bez kończenia)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
