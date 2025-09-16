import 'package:flutter/material.dart';
import 'package:kiosk_godzin/screens/admin/admin_screen.dart';

import '../../services/auth_service.dart';
import 'admin_login_screen.dart';

/// Ekran wejściowy do panelu administratora.
/// - jeśli jest token -> przejście do AdminScreen,
/// - jeśli nie ma tokena -> przycisk "Zaloguj jako admin".
class AdminEntryScreen extends StatefulWidget {
  const AdminEntryScreen({super.key});

  @override
  State<AdminEntryScreen> createState() => _AdminEntryScreenState();
}

class _AdminEntryScreenState extends State<AdminEntryScreen> {
  bool _checking = true;
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final t = await AuthService.token;
    if (!mounted) return;
    setState(() {
      _hasToken = t != null && t.isNotEmpty;
      _checking = false;
    });
    if (_hasToken) {
      // jeżeli już zalogowany, przejdź od razu do panelu
      _goToAdmin();
    }
  }

  void _goToAdmin() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AdminScreen()));
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminLoginScreen(
          onSuccess: () {
            // po udanym logowaniu od razu wpuść do panelu
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AdminScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    setState(() => _hasToken = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wylogowano.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Panel administratora')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dostęp do panelu admina',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_hasToken) ...[
                    const Text('Jesteś zalogowany.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _goToAdmin,
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Przejdź do panelu'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Wyloguj'),
                    ),
                  ] else ...[
                    const Text(
                      'Aby kontynuować, zaloguj się jako administrator.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(Icons.lock),
                      label: const Text('Zaloguj jako admin'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
