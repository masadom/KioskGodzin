import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/admin_repository.dart';
import '../../../models/employee.dart';

enum EmployeesView { table, byRole, byShiftNo }

class EmployeesTab extends StatefulWidget {
  const EmployeesTab({super.key});

  @override
  State<EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<EmployeesTab> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  List<Employee> _employees = [];
  bool _loading = false;
  EmployeesView _view = EmployeesView.table;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = await AdminRepoProvider.instance;
      final query = _searchCtrl.text.trim();
      final emps = await repo.listEmployees(
        search: query.isEmpty ? null : query,
      );
      setState(() => _employees = emps);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEmployeeDialog({Employee? employee}) async {
    final nameCtrl = TextEditingController(text: employee?.name ?? '');
    final pinCtrl = TextEditingController(text: employee?.pin ?? '');
    final isEdit = employee != null;

    final repo = await AdminRepoProvider.instance;
    List<String> roles = await repo.listRoles();
    List<int> shiftNos = await repo.listShiftNumbers();
    String role =
        employee?.role ?? (roles.isNotEmpty ? roles.first : 'Pracownik');
    int? shiftNo = employee?.shiftNo;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edytuj pracownika' : 'Dodaj pracownika'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Imię i nazwisko',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Rola'),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => role = v ?? role),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj nową rolę'),
                    onPressed: () async {
                      final c = TextEditingController();
                      final ok2 = await showDialog<bool>(
                        context: ctx,
                        builder: (cCtx) => AlertDialog(
                          title: const Text('Nowa rola'),
                          content: TextField(
                            controller: c,
                            decoration: const InputDecoration(
                              labelText: 'Nazwa roli',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(cCtx, false),
                              child: const Text('Anuluj'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(cCtx, true),
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                      );
                      if (ok2 == true && c.text.trim().isNotEmpty) {
                        await repo.addRole(c.text.trim());
                        roles = await repo.listRoles();
                        setStateDialog(() => role = c.text.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: shiftNo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nr zmiany (opcjonalnie)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('— brak —'),
                    ),
                    ...shiftNos.map(
                      (n) => DropdownMenuItem<int?>(
                        value: n,
                        child: Text('Zmiana $n'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setStateDialog(() => shiftNo = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj numer zmiany'),
                    onPressed: () async {
                      final c = TextEditingController();
                      final ok2 = await showDialog<bool>(
                        context: ctx,
                        builder: (cCtx) => AlertDialog(
                          title: const Text('Dodaj numer zmiany'),
                          content: TextField(
                            controller: c,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Nr'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(cCtx, false),
                              child: const Text('Anuluj'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(cCtx, true),
                              child: const Text('Dodaj'),
                            ),
                          ],
                        ),
                      );
                      final v = int.tryParse(c.text.trim());
                      if (ok2 == true && v != null) {
                        await repo.addShiftNumber(v);
                        shiftNos = await repo.listShiftNumbers();
                        setStateDialog(() => shiftNo = v);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PIN musi być unikalny.',
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
              child: Text(isEdit ? 'Zapisz' : 'Dodaj'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (name.isEmpty || pin.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uzupełnij imię i PIN.')));
      return;
    }

    try {
      final repo2 = await AdminRepoProvider.instance;
      if (isEdit) {
        await repo2.updateEmployee(
          id: employee!.id,
          name: name,
          pin: pin,
          role: role,
          shiftNo: shiftNo,
        );
      } else {
        await repo2.addEmployee(
          name: name,
          pin: pin,
          role: role,
          shiftNo: shiftNo,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Zapisano pracownika.' : 'Dodano pracownika.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  Future<void> _deleteEmployee(Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć pracownika?'),
        content: Text('Pracownik #${e.id} – ${e.name} zostanie usunięty.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final repo = await AdminRepoProvider.instance;
      await repo.deleteEmployee(e.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usunięto pracownika.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
    }
  }

  // --- grupowanie ---
  Map<String, List<Employee>> _groupByRole() {
    final map = <String, List<Employee>>{};
    for (final e in _employees) {
      final k = e.role.toString();
      map.putIfAbsent(k, () => <Employee>[]).add(e);
    }
    return map;
  }

  Map<String, List<Employee>> _groupByShiftNo() {
    final map = <String, List<Employee>>{};
    for (final e in _employees) {
      final k = e.shiftNo?.toString() ?? '— brak —';
      map.putIfAbsent(k, () => <Employee>[]).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_view == EmployeesView.table) {
      body = Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Imię i nazwisko')),
                DataColumn(label: Text('PIN')),
                DataColumn(label: Text('Rola')),
                DataColumn(label: Text('Nr zmiany')),
                DataColumn(label: Text('Akcje')),
              ],
              rows: _employees
                  .map(
                    (e) => DataRow(
                      cells: [
                        DataCell(Text(e.id.toString())),
                        DataCell(Text(e.name)),
                        DataCell(Text(e.pin)),
                        DataCell(Text(e.role)),
                        DataCell(Text(e.shiftNo?.toString() ?? '—')),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Edytuj',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showEmployeeDialog(employee: e),
                              ),
                              IconButton(
                                tooltip: 'Usuń',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteEmployee(e),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );
    } else {
      final groups = _view == EmployeesView.byRole
          ? _groupByRole()
          : _groupByShiftNo();
      final keys = groups.keys.toList()..sort((a, b) => a.compareTo(b));
      body = ListView.separated(
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final key = keys[i];
          final list = groups[key]!..sort((a, b) => a.name.compareTo(b.name));
          final header = _view == EmployeesView.byRole
              ? 'Rola: $key'
              : (key == '— brak —' ? 'Nr zmiany: — brak —' : 'Nr zmiany: $key');

          return Card(
            child: ExpansionTile(
              title: Text('$header  •  ${list.length}'),
              children: list
                  .map(
                    (e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.person),
                      title: Text(e.name),
                      subtitle: Text(
                        'PIN: ${e.pin} • Rola: ${e.role} • Zmiana: ${e.shiftNo?.toString() ?? '—'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Edytuj',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEmployeeDialog(employee: e),
                          ),
                          IconButton(
                            tooltip: 'Usuń',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteEmployee(e),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pasek narzędzi (wyszukiwarka + akcje)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Szukaj (imię / PIN / rola)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Wyczyść',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _scheduleSearch();
                              _searchFocus.requestFocus();
                            },
                          ),
                  ),
                  onSubmitted: (_) => _load(),
                  onChanged: (_) => _scheduleSearch(),
                ),
              ),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.filter_alt),
                label: const Text('Szukaj'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 16),
              // 👇 przycisk dodawania PRACOWNIKA (wraca do UI)
              FilledButton.icon(
                onPressed: () => _showEmployeeDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('Dodaj pracownika'),
              ),
              const SizedBox(width: 16),
              SegmentedButton<EmployeesView>(
                segments: const [
                  ButtonSegment(
                    value: EmployeesView.table,
                    label: Text('Tabela'),
                    icon: Icon(Icons.table_chart),
                  ),
                  ButtonSegment(
                    value: EmployeesView.byRole,
                    label: Text('Grupa: Rola'),
                    icon: Icon(Icons.badge),
                  ),
                  ButtonSegment(
                    value: EmployeesView.byShiftNo,
                    label: Text('Grupa: Nr zmiany'),
                    icon: Icon(Icons.swap_calls),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: body),
        ],
      ),
    );
  }
}
