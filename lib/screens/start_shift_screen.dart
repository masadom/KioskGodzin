import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../data/shift_repository.dart';
import 'start_confirmation_screen.dart';
import 'login_screen.dart';

class StartShiftScreen extends StatefulWidget {
  final Employee employee;
  const StartShiftScreen({super.key, required this.employee});

  @override
  State<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends State<StartShiftScreen> {
  bool _busy = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    final repo = await ShiftRepoProvider.instance;

    try {
      final existing = await repo.findActiveShiftForEmployee(
        widget.employee.id,
      );
      final startedAt =
          existing?.startedAt ??
          (await repo.startShift(widget.employee.id)).startedAt;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StartConfirmationScreen(
            employee: widget.employee,
            startedAt: startedAt,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się rozpocząć zmiany: $e')),
      );
    }
  }

  void _cancel() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rozpoczęcie zmiany')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Witaj, ${widget.employee.name}',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aby rozpocząć pracę, naciśnij przycisk poniżej.\n'
                  'Po starcie pokażemy godzinę i wrócimy do logowania.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _start,
                  child: _busy
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
                            'Rozpocznij zmianę',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: _cancel, child: const Text('Anuluj')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
