class Shift {
  final int id;
  final int employeeId;
  final DateTime startedAt;
  final DateTime? endedAt;

  Shift({
    required this.id,
    required this.employeeId,
    required this.startedAt,
    this.endedAt,
  });

  factory Shift.fromMap(Map<String, Object?> map) => Shift(
    id: map['id'] as int,
    employeeId: map['employee_id'] as int,
    startedAt: DateTime.parse(map['started_at'] as String),
    endedAt: map['ended_at'] != null
        ? DateTime.parse(map['ended_at'] as String)
        : null,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
  };
}
