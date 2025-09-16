import 'package:flutter/material.dart';
import '../../../data/admin_repository.dart';
import '../../../services/settings_service.dart';
import '../../../config.dart';
import '../../../services/auth_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _ctrl = TextEditingController();
  bool _testing = false;
  String? _current;
  final _curPass = TextEditingController();
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await SettingsService.getBaseUrl();
    setState(() {
      _current = saved ?? AppConfig.baseUrl;
      _ctrl.text = _current!;
    });
  }

  Future<void> _save() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj adres serwera (np. 192.168.1.50:3000)'),
        ),
      );
      return;
    }
    await SettingsService.setBaseUrl(input);
    AdminRepoProvider.reset(); // repo zacznie używać nowego baseUrl
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Zapisano adres serwera.')));
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final ok = await SettingsService.testConnection(_ctrl.text);
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Połączenie OK ✅' : 'Brak połączenia ❌')),
    );
  }

  Future<void> _resetToDefault() async {
    await SettingsService.clear();
    AdminRepoProvider.reset();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Przywrócono domyślne: ${AppConfig.baseUrl}')),
    );
  }

  Future<void> _changePassword() async {
    if (_newPass.text != _newPass2.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nowe hasła nie są takie same.')),
      );
      return;
    }
    if (_newPass.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasło musi mieć co najmniej 8 znaków.')),
      );
      return;
    }
    setState(() => _changing = true);
    final ok = await AuthService.changePassword(
      currentPassword: _curPass.text,
      newPassword: _newPass.text,
    );
    if (!mounted) return;
    setState(() => _changing = false);
    if (ok) {
      _curPass.clear();
      _newPass.clear();
      _newPass2.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hasło zmienione.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zmiana hasła nie powiodła się. Sprawdź obecne hasło.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ustawienia serwera', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Adres serwera (host:port lub pełny URL)',
                hintText: 'np. 192.168.1.50:3000 lub http://192.168.1.50:3000',
                prefixIcon: Icon(Icons.router),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Aktualnie używany: ${_current ?? '-'}'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Zapisz'),
              ),
              FilledButton.tonalIcon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: const Text('Test połączenia'),
              ),
              OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Domyślne'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zmiana hasła administratora',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _curPass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Obecne hasło',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nowe hasło (min. 8 znaków)',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newPass2,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Powtórz nowe hasło',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _changing ? null : _changePassword,
                      icon: _changing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Zmień hasło'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Text(
            'Wskazówki:\n'
            '• W sieci lokalnej wpisz IP serwera, np. 192.168.1.50:3000\n'
            '• Jeśli podasz tylko host:port, aplikacja dopisze http:// automatycznie\n'
            '• Po zapisaniu repozytorium od razu używa nowego adresu (nie trzeba restartować aplikacji)',
          ),
        ],
      ),
    );
  }
}
