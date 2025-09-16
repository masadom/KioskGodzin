import 'package:flutter/material.dart';
import 'package:kiosk_godzin/screens/admin/tabs/summary_tab.dart';
import 'tabs/employees_tab.dart';
import 'tabs/active_tab.dart';
import 'tabs/completed_tab.dart';
import 'tabs/settings_tab.dart';
import 'admin_calendar_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_index].label)),
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
