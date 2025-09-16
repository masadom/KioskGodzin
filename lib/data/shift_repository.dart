import '../models/employee.dart';
import '../models/shift.dart';

// ważne: jawne importy klas implementacji
import 'shift_local_repository.dart' show LocalShiftRepository;
import 'shift_remote_repository.dart' show RemoteShiftRepository;

import '../config.dart';

abstract class ShiftRepository {
  Future<Employee?> findEmployeeByPin(String pin);
  Future<Shift?> findActiveShiftForEmployee(int employeeId);
  Future<Shift> startShift(int employeeId);
  // zdalnie kończymy po employeeId (bo ID shiftu może być stringiem)
  Future<void> endShiftByEmployee(int employeeId);
}

class ShiftRepoProvider {
  static ShiftRepository? _instance;

  static Future<ShiftRepository> get instance async {
    if (_instance != null) return _instance!;
    if (AppConfig.useRemote) {
      _instance = RemoteShiftRepository(baseUrl: AppConfig.baseUrl);
    } else {
      _instance = await LocalShiftRepository.create();
    }
    return _instance!;
  }
}
