// lib/data/admin_local_repository.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/employee.dart';
import '../models/shift.dart';
import '../models/absence.dart';
import 'admin_repository.dart';

/// Lokalna implementacja repozytorium administracyjnego oparta o SQLite (sqflite).
/// Uwaga: sqflite nie działa na WEB. Użyj tej klasy tylko na platformach mobilnych/desktop.
class AdminLocalRepository implements AdminRepository {
  AdminLocalRepository();

  Database? _db;

  // ---------- INIT / SCHEMA ----------

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, 'kiosk_godzin.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Pracownicy
        await db.execute('''
          CREATE TABLE employees(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            pin TEXT NOT NULL UNIQUE,
            role TEXT NOT NULL,
            shift_no INTEGER
          )
        ''');

        // Zmiany
        await db.execute('''
          CREATE TABLE shifts(
            id INTEGER PRIMARY KEY,
            employee_id INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            FOREIGN KEY(employee_id) REFERENCES employees(id) ON DELETE CASCADE
          )
        ''');

        // Role (słownik)
        await db.execute('''
          CREATE TABLE roles(
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE
          )
        ''');

        // Numery zmian (słownik)
        await db.execute('''
          CREATE TABLE work_shifts(
            id INTEGER PRIMARY KEY,
            no INTEGER NOT NULL UNIQUE
          )
        ''');

        // Nieobecności
        await db.execute('''
          CREATE TABLE absences(
            id INTEGER PRIMARY KEY,
            employee_id INTEGER NOT NULL,
            type TEXT NOT NULL,           -- 'URLOP' | 'L4' | 'INNE'
            start_date TEXT NOT NULL,     -- ISO8601 (YYYY-MM-DDTHH:mm:ss)
            end_date TEXT NOT NULL,
            FOREIGN KEY(employee_id) REFERENCES employees(id) ON DELETE CASCADE
          )
        ''');

        // Dane przykładowe
        await db.insert('roles', {
          'id': 1,
          'name': 'Pracownik',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.insert('roles', {
          'id': 2,
          'name': 'Kierownik',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.insert('work_shifts', {
          'id': 1,
          'no': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.insert('work_shifts', {
          'id': 2,
          'no': 2,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      },
    );
    return _db!;
  }

  Future<int> _nextId(Database db, String table) async {
    final res = await db.rawQuery('SELECT MAX(id) AS max_id FROM $table');
    final dynamic v = res.isNotEmpty ? res.first['max_id'] : null;
    final maxId = (v is int) ? v : (v is num ? v.toInt() : 0);
    return maxId + 1;
  }

  int _asInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  // ---------- EMPLOYEES ----------

  @override
  Future<List<Employee>> listEmployees({String? search}) async {
    final db = await _database;
    List<Map<String, Object?>> rows;
    if (search == null || search.trim().isEmpty) {
      rows = await db.query('employees', orderBy: 'id ASC');
    } else {
      final q = '%${search.trim()}%';
      rows = await db.query(
        'employees',
        where:
            'name LIKE ? OR pin LIKE ? OR role LIKE ? OR CAST(shift_no AS TEXT) LIKE ?',
        whereArgs: [q, q, q, q],
        orderBy: 'id ASC',
      );
    }
    return rows
        .map(
          (m) => Employee(
            id: _asInt(m['id']),
            name: (m['name'] ?? '').toString(),
            pin: (m['pin'] ?? '').toString(),
            role: (m['role'] ?? '').toString(),
            shiftNo: m['shift_no'] == null ? null : _asInt(m['shift_no']),
          ),
        )
        .toList();
  }

  @override
  Future<Employee> addEmployee({
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  }) async {
    final db = await _database;

    // unikalność PIN
    final existing = await db.query(
      'employees',
      where: 'pin = ?',
      whereArgs: [pin],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('PIN "$pin" jest już używany przez innego pracownika.');
    }

    final id = await _nextId(db, 'employees');
    await db.insert('employees', {
      'id': id,
      'name': name,
      'pin': pin,
      'role': role,
      'shift_no': shiftNo,
    });

    return Employee(id: id, name: name, pin: pin, role: role, shiftNo: shiftNo);
  }

  @override
  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  }) async {
    final db = await _database;

    // unikalność PIN (z wyłączeniem aktualnego id)
    final clash = await db.query(
      'employees',
      where: 'pin = ? AND id <> ?',
      whereArgs: [pin, id],
      limit: 1,
    );
    if (clash.isNotEmpty) {
      throw Exception('PIN "$pin" jest już używany przez innego pracownika.');
    }

    final count = await db.update(
      'employees',
      {'name': name, 'pin': pin, 'role': role, 'shift_no': shiftNo},
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (count == 0) {
      throw Exception('Pracownik #$id nie istnieje (local).');
    }
    return Employee(id: id, name: name, pin: pin, role: role, shiftNo: shiftNo);
  }

  @override
  Future<void> deleteEmployee(int id) async {
    final db = await _database;
    // Na FK ustawiliśmy ON DELETE CASCADE dla shifts/absences,
    // ale sqflite domyślnie nie włącza foreign_keys. Włączmy ochronnie:
    await db.execute('PRAGMA foreign_keys = ON;');
    final count = await db.delete(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw Exception('Pracownik #$id nie istnieje (local).');
    }
  }

  // ---------- SHIFTS ----------

  @override
  Future<List<Shift>> listShifts({int? employeeId, bool? onlyActive}) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];

    if (employeeId != null) {
      where.add('employee_id = ?');
      args.add(employeeId);
    }
    if (onlyActive != null) {
      if (onlyActive) {
        where.add('ended_at IS NULL');
      } else {
        where.add('ended_at IS NOT NULL');
      }
    }

    final rows = await db.query(
      'shifts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'id DESC',
    );
    return rows
        .map(
          (m) => Shift(
            id: _asInt(m['id']),
            employeeId: _asInt(m['employee_id']),
            startedAt: DateTime.parse(
              (m['started_at'] ?? DateTime.now().toIso8601String()).toString(),
            ),
            endedAt: _asDate(m['ended_at']),
          ),
        )
        .toList();
  }

  @override
  Future<void> endShift(int shiftId) async {
    final db = await _database;
    final nowIso = DateTime.now().toIso8601String();
    final count = await db.update(
      'shifts',
      {'ended_at': nowIso},
      where: 'id = ?',
      whereArgs: [shiftId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (count == 0) {
      throw Exception('Zmiana #$shiftId nie istnieje (local).');
    }
  }

  @override
  Future<Shift> updateShift({
    required int shiftId,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) async {
    final db = await _database;
    final count = await db.update(
      'shifts',
      {
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [shiftId],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (count == 0) {
      throw Exception('Zmiana #$shiftId nie istnieje (local).');
    }
    return Shift(
      id: shiftId,
      employeeId: 0,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  @override
  Future<void> deleteShift(int shiftId) async {
    final db = await _database;
    final count = await db.delete(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
    if (count == 0) {
      throw Exception('Zmiana #$shiftId nie istnieje (local).');
    }
  }

  /// ➕ Dodanie zmiany manualnie (np. w zakładce „Zakończone”)
  @override
  Future<Shift> addShiftManual({
    required int employeeId,
    required DateTime startedAt,
    DateTime? endedAt,
  }) async {
    final db = await _database;
    final id = await _nextId(db, 'shifts');
    await db.insert('shifts', {
      'id': id,
      'employee_id': employeeId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return Shift(
      id: id,
      employeeId: employeeId,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  // ---------- ROLES & WORK SHIFTS (słowniki) ----------

  @override
  Future<List<String>> listRoles() async {
    final db = await _database;
    final rows = await db.query('roles', orderBy: 'name ASC');
    return rows
        .map((m) => (m['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<void> addRole(String role) async {
    final db = await _database;
    // jeśli już istnieje, nic nie rób
    final exists = await db.query(
      'roles',
      where: 'name = ?',
      whereArgs: [role],
      limit: 1,
    );
    if (exists.isNotEmpty) return;

    final id = await _nextId(db, 'roles');
    await db.insert('roles', {
      'id': id,
      'name': role,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  @override
  Future<List<int>> listShiftNumbers() async {
    final db = await _database;
    final rows = await db.query('work_shifts', orderBy: 'no ASC');
    return rows.map((m) => _asInt(m['no'])).where((n) => n > 0).toList();
  }

  @override
  Future<void> addShiftNumber(int no) async {
    final db = await _database;
    final exists = await db.query(
      'work_shifts',
      where: 'no = ?',
      whereArgs: [no],
      limit: 1,
    );
    if (exists.isNotEmpty) return;

    final id = await _nextId(db, 'work_shifts');
    await db.insert('work_shifts', {
      'id': id,
      'no': no,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  // ---------- ABSENCES (kalendarz) ----------

  @override
  Future<List<Absence>> listAbsences({required DateTime month}) async {
    final db = await _database;
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);

    // pobierz wszystkie, potem odfiltruj na poziomie Darta (prościej niż skomplikowany BETWEEN)
    final rows = await db.query('absences', orderBy: 'start_date ASC');
    final all = rows
        .map(
          (m) => Absence(
            id: _asInt(m['id']),
            employeeId: _asInt(m['employee_id']),
            type: (m['type'] ?? 'URLOP').toString(),
            startDate: DateTime.parse((m['start_date'] ?? '').toString()),
            endDate: DateTime.parse((m['end_date'] ?? '').toString()),
          ),
        )
        .toList();

    return all.where((a) {
      // zakres (s..e) przecina się z miesiącem [first, next)
      return a.endDate.isAfter(first) && a.startDate.isBefore(next);
    }).toList();
  }

  @override
  Future<Absence> addAbsence({
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _database;
    final id = await _nextId(db, 'absences');
    await db.insert('absences', {
      'id': id,
      'employee_id': employeeId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });
    return Absence(
      id: id,
      employeeId: employeeId,
      type: type,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<void> deleteAbsence(int id) async {
    final db = await _database;
    final count = await db.delete('absences', where: 'id = ?', whereArgs: [id]);
    if (count == 0) {
      throw Exception('Absence #$id nie istnieje (local).');
    }
  }

  /// ✏️ Edycja istniejącej nieobecności
  @override
  Future<Absence> updateAbsence({
    required int id,
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _database;
    final count = await db.update(
      'absences',
      {
        'employee_id': employeeId,
        'type': type,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (count == 0) {
      throw Exception('Absence #$id nie istnieje (local).');
    }
    return Absence(
      id: id,
      employeeId: employeeId,
      type: type,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
