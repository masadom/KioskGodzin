import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const _dbName = 'time_kiosk.db';
  // ⬇ podnieśliśmy wersję, by dodać unikalny indeks PIN
  static const _dbVersion = 2;

  Database? _db;
  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            pin TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE shifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employee_id INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            FOREIGN KEY(employee_id) REFERENCES employees(id)
          );
        ''');
        // Unikalność PIN-u
        await db.execute(
          'CREATE UNIQUE INDEX idx_employees_pin ON employees(pin);',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Dodaj unikalny indeks jeśli baza była już utworzona wcześniej
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_pin ON employees(pin);',
          );
        }
      },
    );
  }
}
