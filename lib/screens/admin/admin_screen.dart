import 'package:flutter/material.dart';
import 'package:kiosk_godzin/screens/admin/admin_calendar_tab.dart';
import 'package:kiosk_godzin/screens/admin/tabs/active_tab.dart';
import 'package:kiosk_godzin/screens/admin/tabs/completed_tab.dart';
import 'package:kiosk_godzin/screens/admin/tabs/employees_tab.dart';
import 'package:kiosk_godzin/screens/admin/tabs/settings_tab.dart';
import 'package:kiosk_godzin/screens/admin/tabs/summary_tab.dart';
import 'package:kiosk_godzin/screens/admin_login_screen.dart';
import '../../services/auth_service.dart';
import '../admin_login_screen.dart';
// ...reszta importów (tabs)

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _token;
  int _index = 0;

  final _tabs = const [
    (label: 'Pracownicy', icon: Icons.people, widget: EmployeesTab()),
    (
      label: 'Aktywne zmiany',
      icon: Icons.playlist_add_check,
      widget: ActiveTab(),
    ),
    (label: 'Zakończone', icon: Icons.history, widget: CompletedTab()),
    (label: 'Podsumowanie', icon: Icons.summarize, widget: SummaryTab()),
    (
      label: 'Kalendarz',
      icon: Icons.calendar_month,
      widget: AdminCalendarTab(),
    ),
    (label: 'Ustawienia', icon: Icons.settings, widget: SettingsTab()),
  ];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final t = await AuthService.token;
    if (!mounted) return;
    setState(() => _token = t);
  }

  void _onLoginSuccess() {
    _loadToken();
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    setState(() {
      _token = null;
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel admina')),
        body: AdminLoginScreen(onSuccess: _onLoginSuccess),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index].label),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: _tabs
                .map(
                  (t) => NavigationRailDestination(
                    icon: Icon(t.icon),
                    label: Text(t.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _tabs[_index].widget),
        ],
      ),
    );
  }
}
