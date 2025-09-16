import 'package:sqflite/sqflite.dart';

import '../models/employee.dart';
import '../models/shift.dart';
import 'shift_repository.dart';
import 'db.dart';

class LocalShiftRepository implements ShiftRepository {
  final Database _db;
  LocalShiftRepository(this._db);

  static Future<LocalShiftRepository> create() async {
    final db = await AppDatabase.instance.db;
    return LocalShiftRepository(db);
  }

  @override
  Future<Employee?> findEmployeeByPin(String pin) async {
    final rows = await _db.query(
      'employees',
      where: 'pin = ?',
      whereArgs: [pin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  @override
  Future<Shift?> findActiveShiftForEmployee(int employeeId) async {
    final rows = await _db.query(
      'shifts',
      where: 'employee_id = ? AND ended_at IS NULL',
      whereArgs: [employeeId],
      limit: 1,
      orderBy: 'id DESC',
    );
    if (rows.isEmpty) return null;
    return Shift.fromMap(rows.first);
  }

  @override
  Future<Shift> startShift(int employeeId) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.insert('shifts', {
      'employee_id': employeeId,
      'started_at': now,
      'ended_at': null,
    });
    final row = await _db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return Shift.fromMap(row.first);
  }

  @override
  Future<void> endShiftByEmployee(int employeeId) async {
    final active = await findActiveShiftForEmployee(employeeId);
    if (active == null) return;
    await _db.update(
      'shifts',
      {'ended_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [active.id],
    );
  }
}
