import 'package:flutter/material.dart';
import '../../../data/admin_repository.dart';
import '../../../models/employee.dart';
import '../../../models/shift.dart';
import '../../../utils/time_utils.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  List<Employee> _employees = [];
  List<Shift> _active = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = await AdminRepoProvider.instance;
      final emps = await repo.listEmployees();
      final act = await repo.listShifts(onlyActive: true);
      setState(() {
        _employees = emps;
        _active = act.where((s) => s.endedAt == null).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _end(Shift s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakończyć zmianę?'),
        content: Text('Pracownik #${s.employeeId}, zmiana #${s.id}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zakończ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = await AdminRepoProvider.instance;
      await repo.endShift(s.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zakończono zmianę.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    }
  }

  Employee _empById(int id) => _employees.firstWhere(
    (e) => e.id == id,
    orElse: () => Employee(id: id, name: '-', pin: ''),
  );

  // role -> shiftNo -> shifts
  Map<String, Map<String, List<Shift>>> _groupActive() {
    final map = <String, Map<String, List<Shift>>>{};
    for (final s in _active) {
      final emp = _empById(s.employeeId);
      final role = emp.role.isNotEmpty ? emp.role : '— brak roli —';
      final shiftKey = emp.shiftNo?.toString() ?? '— brak —';

      map.putIfAbsent(role, () => <String, List<Shift>>{});
      map[role]!.putIfAbsent(shiftKey, () => <Shift>[]);
      map[role]![shiftKey]!.add(s);
    }
    // sortuj listy w każdej grupie po czasie startu
    for (final sub in map.values) {
      for (final k in sub.keys) {
        sub[k]!.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupActive();
    final roles = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 🔄 Pasek narzędzi z odświeżeniem
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Odśwież'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : roles.isEmpty
                ? const Center(child: Text('Brak aktywnych zmian'))
                : ListView.separated(
                    itemCount: roles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final role = roles[i];
                      final byShift = grouped[role]!;
                      final shiftKeys = byShift.keys.toList()
                        ..sort((a, b) {
                          if (a == '— brak —' && b == '— brak —') return 0;
                          if (a == '— brak —') return 1;
                          if (b == '— brak —') return -1;
                          return int.parse(a).compareTo(int.parse(b));
                        });

                      return Card(
                        child: ExpansionTile(
                          title: Text('Rola: $role'),
                          children: shiftKeys.map((sk) {
                            final label = sk == '— brak —'
                                ? 'Nr zmiany: — brak —'
                                : 'Nr zmiany: $sk';
                            final shifts = byShift[sk]!;
                            return ExpansionTile(
                              leading: const Icon(Icons.access_time),
                              title: Text('$label  •  ${shifts.length}'),
                              children: shifts.map((s) {
                                final emp = _empById(s.employeeId);
                                final dur = DateTime.now().difference(
                                  s.startedAt,
                                );
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person),
                                  title: Text(emp.name),
                                  subtitle: Text(
                                    'Start: ${fmtDateTimePretty(s.startedAt)}   •   Czas: ${fmtDuration(dur)}',
                                  ),
                                  trailing: FilledButton.tonal(
                                    onPressed: () => _end(s),
                                    child: const Text('Zakończ'),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
