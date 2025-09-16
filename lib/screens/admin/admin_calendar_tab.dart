import 'package:flutter/material.dart';
import '../../data/admin_repository.dart';
import '../../models/employee.dart';
import '../../models/absence.dart';

class AdminCalendarTab extends StatefulWidget {
  const AdminCalendarTab({super.key});

  @override
  State<AdminCalendarTab> createState() => _AdminCalendarTabState();
}

class _AdminCalendarTabState extends State<AdminCalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = false;

  List<Employee> _employees = [];
  List<Absence> _absences = [];

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
      final abs = await repo.listAbsences(month: _month);
      if (!mounted) return;
      setState(() {
        _employees = emps;
        _absences = abs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd ładowania kalendarza: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Pomocnicze
  String get _labelMonth =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 1);

  // Absencje w danym dniu
  List<Absence> _absencesOn(DateTime day) {
    final start = _monthStart(_month);
    final end = _monthEnd(_month);
    return _absences.where((a) {
      // pokaż tylko przecinające bieżący miesiąc
      final s = a.startDate.isBefore(start) ? start : a.startDate;
      final e = a.endDate.isAfter(end) ? end : a.endDate;
      return !day.isBefore(s) && !day.isAfter(e);
    }).toList();
  }

  // Kolor przypisany pracownikowi – tylko tym, którzy mają absencje w tym miesiącu
  final Map<int, Color> _colorCache = {};
  Color _colorForEmployee(int id) {
    return _colorCache.putIfAbsent(
      id,
      () => Colors.primaries[id % Colors.primaries.length].shade400,
    );
  }

  // Lista pracowników z absencjami w tym miesiącu
  List<Employee> _employeesWithAbsencesThisMonth() {
    final setIds = <int>{};
    final start = _monthStart(_month);
    final end = _monthEnd(_month);
    for (final a in _absences) {
      if (a.endDate.isAfter(start) && a.startDate.isBefore(end)) {
        setIds.add(a.employeeId);
      }
    }
    final list = _employees.where((e) => setIds.contains(e.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Wybierz dowolny dzień miesiąca',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      await _load(); // auto-refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _monthEnd(
      _month,
    ).difference(_monthStart(_month)).inDays;
    final firstWeekday = _monthStart(_month).weekday; // 1..7 (1=pon)
    final leadingEmpty = (firstWeekday + 6) % 7; // ile pustych przed 1 dniem

    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7.0).ceil();

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
                        'Miesiąc: $_labelMonth',
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
                : Row(
                    children: [
                      // Kalendarz
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (ctx, cons) {
                            final cellW =
                                (cons.maxWidth - 6 * 8) / 7; // paddingi
                            final cellH = cellW * 0.9;
                            return Column(
                              children: [
                                // Nagłówki dni tygodnia
                                Row(
                                  children: const [
                                    Expanded(child: Center(child: Text('Pn'))),
                                    Expanded(child: Center(child: Text('Wt'))),
                                    Expanded(child: Center(child: Text('Śr'))),
                                    Expanded(child: Center(child: Text('Cz'))),
                                    Expanded(child: Center(child: Text('Pt'))),
                                    Expanded(child: Center(child: Text('So'))),
                                    Expanded(child: Center(child: Text('Nd'))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                        ),
                                    itemCount: rows * 7,
                                    itemBuilder: (ctx, i) {
                                      if (i < leadingEmpty ||
                                          i >= leadingEmpty + daysInMonth) {
                                        return const SizedBox.shrink();
                                      }
                                      final dayNum = i - leadingEmpty + 1;
                                      final date = DateTime(
                                        _month.year,
                                        _month.month,
                                        dayNum,
                                      );
                                      final abs = _absencesOn(date);

                                      // unikalni pracownicy z absencjami tego dnia
                                      final empIds = abs
                                          .map((a) => a.employeeId)
                                          .toSet()
                                          .toList();

                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.black12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$dayNum',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // kropki / etykiety
                                            if (empIds.isEmpty)
                                              const SizedBox.shrink()
                                            else
                                              Expanded(
                                                child: Tooltip(
                                                  message: empIds
                                                      .map((id) {
                                                        final e = _employees
                                                            .firstWhere(
                                                              (x) => x.id == id,
                                                              orElse: () =>
                                                                  Employee(
                                                                    id: id,
                                                                    name: '-',
                                                                    pin: '',
                                                                  ),
                                                            );
                                                        // pokaż typy (L4/URLOP) skrótowo
                                                        final types = abs
                                                            .where(
                                                              (a) =>
                                                                  a.employeeId ==
                                                                  id,
                                                            )
                                                            .map((a) => a.type)
                                                            .toSet()
                                                            .join(',');
                                                        return '${e.name} [$types]';
                                                      })
                                                      .join('\n'),
                                                  child: Wrap(
                                                    spacing: 4,
                                                    runSpacing: 4,
                                                    children: empIds.take(6).map((
                                                      id,
                                                    ) {
                                                      return Container(
                                                        width: 14,
                                                        height: 14,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _colorForEmployee(
                                                                id,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                3,
                                                              ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Legenda: tylko pracownicy z absencją w bieżącym miesiącu
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Legenda (tylko osoby z nieobecnościami)',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView(
                                    children: _employeesWithAbsencesThisMonth()
                                        .map((e) {
                                          return ListTile(
                                            dense: true,
                                            leading: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: _colorForEmployee(e.id),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                            title: Text(e.name),
                                            subtitle: Text(e.role),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
