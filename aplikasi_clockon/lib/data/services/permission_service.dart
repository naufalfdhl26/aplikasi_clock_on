import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/permission_model.dart';
import 'shift_service.dart';
import 'schedule_service.dart';

class PermissionService {
  final DataService _api = DataService();
  final ShiftService _shiftService = ShiftService();
  final ScheduleService _scheduleService = ScheduleService();

  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) return true;
    final status2 = await Permission.storage.request();
    return status2.isGranted;
  }

  Future<bool> requestAllForUpload() async {
    final loc = await requestLocationPermission();
    final storage = await requestStoragePermission();
    return loc && storage;
  }

  Future<List<PermissionModel>> fetchAllPermissions() async {
    try {
      debugPrint('=== fetchAllPermissions Debug ===');
      debugPrint(
        'Calling selectAll with token: $token, project: $project, collection: permission, appid: $appid',
      );

      final res = await _api.selectAll(token, project, 'permission', appid);
      if (res == null) {
        debugPrint('selectAll returned null');
        return [];
      }

      debugPrint('selectAll(permission) response: $res');

      dynamic decoded;
      try {
        decoded = jsonDecode(res);
        debugPrint('JSON decoded successfully');
      } catch (e) {
        debugPrint('JSON decode error: $e');
        return [];
      }

      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
        debugPrint('Decoded as List with ${items.length} items');
      } else if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        items = data is List ? data : [data];
        debugPrint('Decoded as Map with data key, items: ${items.length}');
      } else if (decoded is Map) {
        items = [decoded];
        debugPrint('Decoded as Map, treating as single item');
      }

      debugPrint('Processing ${items.length} permission items');
      final permissions = items
          .map(
            (e) => PermissionModel.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      debugPrint(
        'Successfully parsed ${permissions.length} PermissionModel objects',
      );
      return permissions;
    } catch (e, st) {
      debugPrint('fetchAllPermissions error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<bool> submitPermissionRequest({
    required String employeeId,
    required String employeeName,
    required String employeeEmail,
    String? employeeDivision,
    String? employeeAvatarPath,
    required String type,
    required String reason,
    required DateTime leaveDate,
  }) async {
    try {
      debugPrint('=== submitPermissionRequest Debug ===');
      // Pastikan semua field tidak kosong
      final safeEmployeeId = (employeeId.isNotEmpty)
          ? employeeId
          : 'UNKNOWN_EMPLOYEE_ID';
      final safeEmployeeName = (employeeName.isNotEmpty)
          ? employeeName
          : 'UNKNOWN_EMPLOYEE_NAME';
      final safeEmployeeEmail = (employeeEmail.isNotEmpty)
          ? employeeEmail
          : 'UNKNOWN_EMPLOYEE_EMAIL';
      final safeEmployeeDivision = employeeDivision ?? '';
      final safeEmployeeAvatarPath = employeeAvatarPath ?? '';
      final safeType = (type.isNotEmpty) ? type : 'izin';
      final safeReason = (reason.isNotEmpty) ? reason : '-';
      final safeLeaveDate = leaveDate;

      // Get the shift and schedule info for this employee on the leave date
      String? shiftId;
      String? shiftLabel;
      String? scheduleId;
      try {
        final shiftInfo = await _getEmployeeShiftForDate(
          safeEmployeeId,
          safeLeaveDate,
        );
        shiftId = shiftInfo['shiftId'] ?? '';
        shiftLabel = shiftInfo['shiftLabel'] ?? '';
        scheduleId = shiftInfo['scheduleId'] ?? '';
        debugPrint(
          'Shift for date $safeLeaveDate: $shiftId, Shift Label: $shiftLabel, Schedule ID: $scheduleId',
        );
      } catch (e) {
        debugPrint('Error getting shift info: $e');
        shiftId = '';
        shiftLabel = '';
        scheduleId = '';
      }

      final permissionId = DateTime.now().millisecondsSinceEpoch.toString();
      final createdAt = DateTime.now().toIso8601String();

      debugPrint('-- Data yang dikirim ke insertPermission --');
      debugPrint('permissionId: $permissionId');
      debugPrint('employeeId: $safeEmployeeId');
      debugPrint('employeeName: $safeEmployeeName');
      debugPrint('employeeEmail: $safeEmployeeEmail');
      debugPrint('employeeDivision: $safeEmployeeDivision');
      debugPrint('employeeAvatarPath: $safeEmployeeAvatarPath');
      debugPrint('type: $safeType');
      debugPrint('reason: $safeReason');
      debugPrint('leaveDate: ${safeLeaveDate.toIso8601String()}');
      debugPrint('shiftId: $shiftId');
      debugPrint('status: pending');
      debugPrint('createdAt: $createdAt');

      final res = await _api.insertPermission(
        appid,
        permissionId,
        safeEmployeeId,
        safeEmployeeName,
        safeEmployeeEmail,
        safeEmployeeDivision,
        safeEmployeeAvatarPath,
        safeType,
        safeReason,
        safeLeaveDate.toIso8601String(),
        shiftId ?? '',
        shiftLabel ?? '',
      );

      debugPrint('insertPermission response: $res');
      return res != null && res != '[]';
    } catch (e, st) {
      debugPrint('submitPermissionRequest error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  Future<Map<String, String?>> _getEmployeeShiftForDate(
    String employeeId,
    DateTime date,
  ) async {
    try {
      debugPrint('=== _getEmployeeShiftForDate Debug ===');
      debugPrint('Employee ID: $employeeId, Date: $date');

      // Get all schedules
      final schedules = await _scheduleService.fetchAllSchedules();
      final shifts = await _shiftService.fetchAllShifts('');

      debugPrint(
        'Found ${schedules.length} schedules and ${shifts.length} shifts',
      );

      // Format date to match schedule format (yyyy-MM-dd)
      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      debugPrint('Looking for date key: $dateKey');

      // Find schedule for this employee
      final employeeSchedule = schedules
          .where((s) => s.employeeId == employeeId)
          .toList();
      debugPrint(
        'Found ${employeeSchedule.length} schedules for employee $employeeId',
      );

      if (employeeSchedule.isNotEmpty) {
        final schedule = employeeSchedule.first;
        final assignments = schedule.assignments;
        debugPrint('Schedule assignments: $assignments');

        // Check if this date has an assignment
        if (assignments.containsKey(dateKey)) {
          final shiftCode = assignments[dateKey];
          debugPrint('Found shift code for date $dateKey: $shiftCode');

          if (shiftCode != null && shiftCode.isNotEmpty) {
            // Find the shift details
            final shift = shifts.where((s) => s['code'] == shiftCode).toList();
            if (shift.isNotEmpty) {
              debugPrint('Found shift details: ${shift.first}');
              return {
                'shiftId': shift.first['id'],
                'shiftLabel': shift.first['label'],
                'scheduleId': schedule.id,
              };
            } else {
              debugPrint('Shift code $shiftCode not found in shifts list');
            }
          } else {
            debugPrint('Shift code is null or empty');
          }
        } else {
          debugPrint('Date $dateKey not found in assignments');
        }
      } else {
        debugPrint('No schedule found for employee $employeeId');
      }

      debugPrint('Returning null shift info');
      return {'shiftId': null, 'scheduleId': null};
    } catch (e) {
      debugPrint('_getEmployeeShiftForDate error: $e');
      return {'shiftId': null, 'scheduleId': null};
    }
  }

  Future<bool> updatePermissionStatus({
    required String permissionId,
    required String status,
    required String adminId,
    required String adminEmail,
  }) async {
    try {
      debugPrint('=== updatePermissionStatus Debug ===');
      debugPrint('Permission ID: $permissionId, Status: $status');
      debugPrint('Admin ID: $adminId, Admin Email: $adminEmail');

      // First, try to update status
      // Normalize status to lowercase for storage and comparison
      final normalizedStatus = status.toLowerCase();
      debugPrint('Updating status field to $normalizedStatus');
      var statusResult = await _api.updateId(
        'status',
        normalizedStatus,
        token,
        project,
        'permission',
        appid,
        permissionId,
      );
      debugPrint('Status update result: $statusResult');

      // Fallback: try updateWhere if updateId failed
      if (!statusResult) {
        debugPrint(
          'updateId failed for status, attempting updateWhere fallback',
        );
        statusResult = await _api.updateWhere(
          'id',
          permissionId,
          'status',
          normalizedStatus,
          token,
          project,
          'permission',
          appid,
        );
        debugPrint('updateWhere(status) fallback result: $statusResult');
      }

      if (!statusResult) {
        debugPrint('FAILED to update status field after fallback');
        return false;
      }

      // Update admin info
      debugPrint('Updating adminId field to $adminId');
      // Update admin info and processedAt - these are best-effort.
      var adminIdResult = await _api.updateId(
        'adminId',
        adminId,
        token,
        project,
        'permission',
        appid,
        permissionId,
      );
      debugPrint('AdminId update result: $adminIdResult');
      if (!adminIdResult) {
        debugPrint('AdminId updateId failed, trying updateWhere fallback');
        adminIdResult = await _api.updateWhere(
          'id',
          permissionId,
          'adminId',
          adminId,
          token,
          project,
          'permission',
          appid,
        );
        debugPrint('updateWhere(adminId) fallback result: $adminIdResult');
      }

      debugPrint('Updating adminEmail field to $adminEmail');
      var adminEmailResult = await _api.updateId(
        'adminEmail',
        adminEmail,
        token,
        project,
        'permission',
        appid,
        permissionId,
      );
      debugPrint('AdminEmail update result: $adminEmailResult');
      if (!adminEmailResult) {
        debugPrint('AdminEmail updateId failed, trying updateWhere fallback');
        adminEmailResult = await _api.updateWhere(
          'id',
          permissionId,
          'adminEmail',
          adminEmail,
          token,
          project,
          'permission',
          appid,
        );
        debugPrint(
          'updateWhere(adminEmail) fallback result: $adminEmailResult',
        );
      }

      debugPrint('Updating processedAt field');
      var processedAtResult = await _api.updateId(
        'processedAt',
        DateTime.now().toIso8601String(),
        token,
        project,
        'permission',
        appid,
        permissionId,
      );
      debugPrint('ProcessedAt update result: $processedAtResult');
      if (!processedAtResult) {
        debugPrint('processedAt updateId failed, trying updateWhere fallback');
        processedAtResult = await _api.updateWhere(
          'id',
          permissionId,
          'processedAt',
          DateTime.now().toIso8601String(),
          token,
          project,
          'permission',
          appid,
        );
        debugPrint(
          'updateWhere(processedAt) fallback result: $processedAtResult',
        );
      }

      // If approved and has shift info, update the schedule
      if (normalizedStatus == 'approved') {
        debugPrint('Status is approved, updating schedule...');
        await _updateScheduleForApprovedPermission(permissionId);
      }

      debugPrint('updatePermissionStatus completed successfully');
      return true;
    } catch (e) {
      debugPrint('updatePermissionStatus error: $e');
      return false;
    }
  }

  /// Returns true if the given employee has an Approved permission for [date].
  Future<bool> isPermissionApprovedForDate(
    String employeeId,
    DateTime date,
  ) async {
    try {
      final permissions = await fetchAllPermissions();
      for (final p in permissions) {
        if (p.employeeId == employeeId) {
          final pDate = p.leaveDate;
          if (pDate.year == date.year &&
              pDate.month == date.month &&
              pDate.day == date.day) {
            if (p.status.toLowerCase() == 'approved') return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('isPermissionApprovedForDate error: $e');
      return false;
    }
  }

  Future<void> _updateScheduleForApprovedPermission(String permissionId) async {
    try {
      // Get the permission details
      final permissions = await fetchAllPermissions();
      final permission = permissions
          .where((p) => p.id == permissionId)
          .toList();
      if (permission.isEmpty) return;

      final perm = permission.first;

      debugPrint(
        'Updating schedule for approved permission: ${perm.employeeName} (${perm.employeeId}) on ${perm.leaveDate}',
      );

      // Format the date to match schedule format (yyyy-MM-dd)
      final dateKey =
          '${perm.leaveDate.year.toString().padLeft(4, '0')}-${perm.leaveDate.month.toString().padLeft(2, '0')}-${perm.leaveDate.day.toString().padLeft(2, '0')}';

      // Find the schedule for this specific employee
      final schedules = await _scheduleService.fetchAllSchedules();
      final employeeSchedule = schedules
          .where((s) => s.employeeId == perm.employeeId)
          .toList();

      if (employeeSchedule.isEmpty) {
        debugPrint('No schedule found for employee ${perm.employeeId}');
        return;
      }

      final schedule = employeeSchedule.first;
      final assignments = schedule.assignments;
      debugPrint('Employee schedule assignments: $assignments');

      // Check if this employee has an assignment on the leave date
      if (assignments.containsKey(dateKey)) {
        final currentShift = assignments[dateKey];
        debugPrint('Current shift for date $dateKey: $currentShift');

        // Update the assignment to mark as izin
        final updatedAssignments = Map<String, String>.from(assignments);
        updatedAssignments[dateKey] = 'IZIN'; // Mark as izin

        final updateResult = await _api.updateId(
          'assignments',
          jsonEncode(updatedAssignments),
          token,
          project,
          'schedule',
          appid,
          schedule.id,
        );
        debugPrint('Schedule update result: $updateResult');

        if (updateResult) {
          debugPrint(
            'Successfully updated schedule for employee ${perm.employeeId}',
          );
        } else {
          debugPrint(
            'Failed to update schedule for employee ${perm.employeeId}',
          );
        }
      } else {
        debugPrint(
          'No assignment found for employee ${perm.employeeId} on date $dateKey',
        );
      }
    } catch (e) {
      debugPrint('_updateScheduleForApprovedPermission error: $e');
    }
  }
}
