class Employee {
  final int id;
  final String name;
  final String pin;
  final String role; // nowość
  final int? shiftNo; // nowość, może być null

  Employee({
    required this.id,
    required this.name,
    required this.pin,
    this.role = 'Pracownik',
    this.shiftNo,
  });

  factory Employee.fromMap(Map<String, dynamic> m) => Employee(
    id: (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}') ?? 0,
    name: (m['name'] ?? '').toString(),
    pin: (m['pin'] ?? '').toString(),
    role: (m['role'] ?? 'Pracownik').toString(),
    shiftNo: m['shift_no'] == null
        ? null
        : (m['shift_no'] is int
              ? m['shift_no'] as int
              : int.tryParse('${m['shift_no']}')),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pin': pin,
    'role': role,
    'shift_no': shiftNo,
  };
}
