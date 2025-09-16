import 'package:flutter/material.dart';
import '../../../data/admin_repository.dart';
import '../../../models/employee.dart';
import '../../../models/shift.dart';

class SummaryTab extends StatefulWidget {
  const SummaryTab({super.key});

  @override
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = false;

  List<Employee> _employees = [];
  List<Shift> _allShifts = [];

  // sort
  bool _sortAsc = false;
  int _sortColumnIndex = 2; // domyślnie sortuj po godzinach malejąco

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
      final shifts = await repo.listShifts(
        onlyActive: false,
      ); // bierzemy wszystkie zakończone
      setState(() {
        _employees = emps;
        _allShifts = shifts.where((s) => s.endedAt != null).toList();
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

  // „klipsuj” zmianę do ram miesiąca, żeby poprawnie liczyć przekraczające granice
  Duration _clippedDurationInMonth(Shift s, DateTime monthStart) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final start = s.startedAt.isBefore(monthStart) ? monthStart : s.startedAt;
    final end = (s.endedAt ?? s.startedAt).isAfter(monthEnd)
        ? monthEnd
        : (s.endedAt ?? s.startedAt);
    if (!end.isAfter(start)) return Duration.zero;
    return end.difference(start);
  }

  Map<int, Duration> _sumByEmployee() {
    final monthStart = DateTime(_month.year, _month.month, 1);
    final monthEnd = DateTime(_month.year, _month.month + 1, 1);

    final map = <int, Duration>{};
    for (final s in _allShifts) {
      // interesują nas tylko zmiany, które PRZECINAJĄ miesiąc
      final ends = s.endedAt!;
      final intersects =
          ends.isAfter(monthStart) && s.startedAt.isBefore(monthEnd);
      if (!intersects) continue;

      final d = _clippedDurationInMonth(s, monthStart);
      if (d == Duration.zero) continue;

      map.update(s.employeeId, (prev) => prev + d, ifAbsent: () => d);
    }
    return map;
  }

  String _fmtHours(Duration d) {
    final hours = d.inMinutes / 60.0;
    return hours
        .toStringAsFixed(2)
        .replaceAll('.', ','); // 2 miejsca po przecinku, PL format
  }

  Future<void> _pickMonth() async {
    // prosty wybór miesiąca poprzez datePicker (bierzemy tylko year+month)
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Wybierz dowolny dzień miesiąca',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      await _load(); // auto-odświeżenie po zmianie miesiąca
    }
  }

  @override
  Widget build(BuildContext context) {
    final sums = _sumByEmployee();

    // połącz z nazwami pracowników
    final rows = <({int id, String name, String role, Duration dur})>[];
    for (final e in _employees) {
      final d = sums[e.id] ?? Duration.zero;
      rows.add((id: e.id, name: e.name, role: e.role, dur: d));
    }

    // sortowanie
    rows.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // ID
          cmp = a.id.compareTo(b.id);
          break;
        case 1: // Nazwa
          cmp = a.name.compareTo(b.name);
          break;
        case 2: // Godziny
          cmp = a.dur.compareTo(b.dur);
          break;
        case 3: // Rola
          cmp = a.role.compareTo(b.role);
          break;
        default:
          cmp = a.dur.compareTo(b.dur);
      }
      return _sortAsc ? cmp : -cmp;
    });

    final labelMonth =
        '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

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
                    tooltip: 'Poprzedni miesiąc',
                    onPressed: () async {
                      setState(
                        () =>
                            _month = DateTime(_month.year, _month.month - 1, 1),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        'Miesiąc: $labelMonth',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Następny miesiąc',
                    onPressed: () async {
                      setState(
                        () =>
                            _month = DateTime(_month.year, _month.month + 1, 1),
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Odśwież'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        sortAscending: _sortAsc,
                        sortColumnIndex: _sortColumnIndex,
                        columns: [
                          DataColumn(
                            label: const Text('ID'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Pracownik'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Godziny (miesiąc)'),
                            numeric: true,
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                          DataColumn(
                            label: const Text('Rola'),
                            onSort: (i, asc) => setState(() {
                              _sortColumnIndex = i;
                              _sortAsc = asc;
                            }),
                          ),
                        ],
                        rows: rows
                            .map(
                              (r) => DataRow(
                                cells: [
                                  DataCell(Text(r.id.toString())),
                                  DataCell(Text(r.name)),
                                  DataCell(Text(_fmtHours(r.dur))),
                                  DataCell(Text(r.role)),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
