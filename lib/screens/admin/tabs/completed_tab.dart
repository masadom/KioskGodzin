import 'package:flutter/material.dart';
import '../../../data/admin_repository.dart';
import '../../../models/employee.dart';
import '../../../models/shift.dart';
import '../../../utils/time_utils.dart';

class CompletedTab extends StatefulWidget {
  const CompletedTab({super.key});

  @override
  State<CompletedTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends State<CompletedTab> {
  List<Employee> _employees = [];
  List<Shift> _shifts = [];
  bool _loading = false;
  DateTime _day = DateTime.now();

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
      final all = await repo.listShifts(onlyActive: false);
      setState(() {
        _employees = emps;
        _shifts =
            all
                .where(
                  (s) =>
                      s.endedAt != null &&
                      s.startedAt.year == _day.year &&
                      s.startedAt.month == _day.month &&
                      s.startedAt.day == _day.day,
                )
                .toList()
              ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
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

  // zmiana dnia + auto-odświeżenie
  Future<void> _setDay(DateTime d) async {
    setState(() => _day = DateTime(d.year, d.month, d.day));
    await _load();
  }

  Employee _empById(int id) => _employees.firstWhere(
    (e) => e.id == id,
    orElse: () => Employee(id: id, name: '-', pin: ''),
  );

  Future<void> _addShift() async {
    final repo = await AdminRepoProvider.instance;
    final emps = List<Employee>.from(_employees)
      ..sort((a, b) => a.name.compareTo(b.name));

    int? employeeId;
    final startCtrl = TextEditingController(
      text: DateTime(_day.year, _day.month, _day.day, 8, 0).toIso8601String(),
    );
    final endCtrl = TextEditingController(
      text: DateTime(_day.year, _day.month, _day.day, 16, 0).toIso8601String(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Dodaj zakończoną zmianę'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  value: employeeId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— wybierz pracownika —'),
                    ),
                    ...emps.map(
                      (e) => DropdownMenuItem<int?>(
                        value: e.id,
                        child: Text(e.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setStateDialog(() => employeeId = v),
                  decoration: const InputDecoration(labelText: 'Pracownik'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Start (ISO 8601, np. 2025-09-13T08:00:00)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Koniec (ISO 8601, np. 2025-09-13T16:00:00)',
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Użyj pełnego formatu ISO lub wpisz ręcznie godzinę.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || employeeId == null) return;

    try {
      final s = DateTime.parse(startCtrl.text.trim());
      final e = DateTime.parse(endCtrl.text.trim());
      if (e.isBefore(s)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koniec nie może być przed startem.')),
        );
        return;
      }
      await repo.addShiftManual(
        employeeId: employeeId!,
        startedAt: s,
        endedAt: e,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dodano zmianę.')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $err')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      await _setDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Poprzedni dzień',
                    onPressed: () =>
                        _setDay(_day.subtract(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  InkWell(
                    onTap: _pickDate, // szybki wybór daty + auto-refresh
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Następny dzień',
                    onPressed: () => _setDay(_day.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Odśwież'),
              ),
              FilledButton.icon(
                onPressed: _addShift,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj zmianę'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                ? const Center(child: Text('Brak zakończonych zmian tego dnia'))
                : ListView.separated(
                    itemCount: _shifts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = _shifts[i];
                      final e = _empById(s.employeeId);
                      final dur = (s.endedAt ?? s.startedAt).difference(
                        s.startedAt,
                      );
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(e.name),
                        subtitle: Text(
                          'Start: ${fmtDateTimePretty(s.startedAt)}   •   Koniec: ${fmtDateTimePretty(s.endedAt!)}   •   Czas: ${fmtDuration(dur)}',
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
