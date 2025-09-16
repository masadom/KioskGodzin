import 'package:flutter/material.dart';
import 'package:kiosk_godzin/widgets/keypad.dart';
import 'package:kiosk_godzin/widgets/pin_dots.dart';
import '../models/employee.dart';
import '../data/shift_repository.dart';
import 'start_shift_screen.dart';
import 'active_shift_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  String? _error;

  void _appendDigit(String d) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final repo = await ShiftRepoProvider.instance;
    final Employee? employee = await repo.findEmployeeByPin(_pin);
    if (employee == null) {
      setState(() => _error = 'Nieprawidłowy PIN');
      return;
    }

    final active = await repo.findActiveShiftForEmployee(employee.id);
    if (!mounted) return;
    if (active != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ActiveShiftScreen(employee: employee, activeShift: active),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StartShiftScreen(employee: employee)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Zaloguj się',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wprowadź swój PIN, aby rozpocząć lub zakończyć zmianę.',
                  ),
                  const SizedBox(height: 24),
                  PinDots(length: _pin.length),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  Keypad(
                    onDigit: _appendDigit,
                    onBackspace: _backspace,
                    onSubmit: _submit,
                    enabled: true,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _pin = '';
                      _error = null;
                    }),
                    child: const Text('Wyczyść'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
