// lib/data/admin_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kiosk_godzin/services/settings_service.dart';

import '../config.dart';
import '../models/employee.dart';
import '../models/shift.dart';
import '../models/absence.dart';

import 'admin_remote_repository.dart';
import 'admin_local_repository.dart';

/// Kontrakt repozytorium panelu admina (wspólny dla remote/local).
abstract class AdminRepository {
  // Employees
  Future<List<Employee>> listEmployees({String? search});
  Future<Employee> addEmployee({
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  });
  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String pin,
    required String role,
    int? shiftNo,
  });
  Future<void> deleteEmployee(int id);

  // Shifts
  Future<List<Shift>> listShifts({int? employeeId, bool? onlyActive});
  Future<void> endShift(int shiftId);
  Future<Shift> updateShift({
    required int shiftId,
    required DateTime startedAt,
    required DateTime? endedAt,
  });
  Future<void> deleteShift(int shiftId);

  /// Ręczne dodanie zmiany (np. korekta w „Zakończone”).
  Future<Shift> addShiftManual({
    required int employeeId,
    required DateTime startedAt,
    DateTime? endedAt,
  });

  // Dictionaries
  Future<List<String>> listRoles();
  Future<void> addRole(String role);
  Future<List<int>> listShiftNumbers();
  Future<void> addShiftNumber(int no);

  // Absences
  Future<List<Absence>> listAbsences({required DateTime month});
  Future<Absence> addAbsence({
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<void> deleteAbsence(int id);

  /// Edycja istniejącej nieobecności.
  Future<Absence> updateAbsence({
    required int id,
    required int employeeId,
    required String type,
    required DateTime startDate,
    required DateTime endDate,
  });
}

class AdminRepoProvider {
  static AdminRepository? _cached;

  static Future<AdminRepository> get instance async {
    if (_cached != null) return _cached!;

    // Pobierz baseUrl z ustawień, w razie braku użyj AppConfig.baseUrl
    final stored = await SettingsService.getBaseUrl();
    final effectiveBaseUrl = (stored != null && stored.isNotEmpty)
        ? stored
        : AppConfig.baseUrl;

    if (kIsWeb) {
      _cached = AdminRemoteRepository(baseUrl: effectiveBaseUrl);
      return _cached!;
    }

    if (AppConfig.useRemote) {
      _cached = AdminRemoteRepository(baseUrl: effectiveBaseUrl);
    } else {
      _cached = AdminLocalRepository();
    }
    return _cached!;
  }

  /// Wyczyszczenie cache (np. po zmianie baseUrl w Ustawieniach)
  static void reset() {
    _cached = null;
  }
}
