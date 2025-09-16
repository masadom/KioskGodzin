class Absence {
  final int id;
  final int employeeId;
  final String type; // 'L4' | 'URLOP' | inne
  final DateTime startDate;
  final DateTime endDate;

  Absence({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  factory Absence.fromMap(Map<String, dynamic> m) => Absence(
    id: (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}') ?? 0,
    employeeId: (m['employee_id'] is int)
        ? m['employee_id'] as int
        : int.tryParse('${m['employee_id']}') ?? 0,
    type: (m['type'] ?? '').toString(),
    startDate: DateTime.parse((m['start_date'] ?? '').toString()),
    endDate: DateTime.parse((m['end_date'] ?? '').toString()),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'type': type,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
  };
}
