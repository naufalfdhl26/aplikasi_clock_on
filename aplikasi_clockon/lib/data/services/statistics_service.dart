import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/attendance_summary_model.dart';
import 'permission_service.dart';
import 'schedule_service.dart';

class StatisticsService {
  final DataService _api = DataService();

  /// Fetch attendance records for an employee and compute monthly summary
  Future<AttendanceSummary> fetchEmployeeMonthlySummary(
    String employeeId,
    int year,
    int month,
  ) async {
    try {
      final res = await _api.selectWhere(
        token,
        project,
        'attendance',
        appid,
        'employeeid',
        employeeId,
      );
      if (res == null) return AttendanceSummary.empty();

      dynamic decoded;
      try {
        decoded = jsonDecode(res);
      } catch (e) {
        debugPrint('JSON decode error in stats: $e');
        return AttendanceSummary.empty();
      }

      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        final data = decoded['data'];
        items = data is List ? data : [data];
      } else if (decoded is Map) {
        items = [decoded];
      }

      int hadir = 0;
      int cuti = 0;
      int izin = 0;
      int alpha = 0;

      // Track dates seen in attendance and izin/cuti-specific dates so we don't double-count
      final Set<String> recordedDates = <String>{};
      final Set<String> izinDatesFromAttendance = <String>{};
      final Set<String> cutiDatesFromAttendance = <String>{};

      for (final e in items) {
        try {
          final Map<String, dynamic> item = Map<String, dynamic>.from(e as Map);
          final dateStr = (item['date'] ?? item['createdat'] ?? '') as String;
          if (dateStr.isEmpty) continue;
          final dt = DateTime.parse(dateStr);
          if (dt.year != year || dt.month != month) continue;

          final dateKey =
              '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          recordedDates.add(dateKey);

          final statusRaw = (item['status'] ?? '').toString().toLowerCase();

          if (statusRaw.contains('present') ||
              statusRaw.contains('hadir') ||
              statusRaw == 'h') {
            hadir++;
          } else if (statusRaw.contains('cuti') || statusRaw == 'c') {
            cuti++;
            cutiDatesFromAttendance.add(dateKey);
          } else if (statusRaw.contains('izin') || statusRaw == 'i') {
            izin++;
            izinDatesFromAttendance.add(dateKey);
          } else if (statusRaw.contains('alpha') ||
              statusRaw.contains('absent') ||
              statusRaw == 'a') {
            alpha++;
          } else {
            // If status unknown but checkin missing, count as alpha
            final checkin = item['checkin'];
            if (checkin == null || (checkin as String).isEmpty) {
              alpha++;
            } else {
              hadir++;
            }
          }
        } catch (e) {
          debugPrint('Error parsing attendance item in stats: $e');
        }
      }

      // Include approved permissions (izin/cuti) stored in the 'permission' collection
      try {
        final permissionService = PermissionService();
        final perms = await permissionService.fetchAllPermissions();
        final Set<String> approvedIzinDates = <String>{};
        final Set<String> approvedCutiDates = <String>{};

        for (final p in perms) {
          try {
            if (p.employeeId == employeeId &&
                p.status.toLowerCase() == 'approved') {
              final pDate = p.leaveDate;
              if (pDate.year == year && pDate.month == month) {
                final pk =
                    '${pDate.year.toString().padLeft(4, '0')}-${pDate.month.toString().padLeft(2, '0')}-${pDate.day.toString().padLeft(2, '0')}';

                // Kategorikan berdasarkan jenis permission
                final leaveType = (p.type ?? '').toLowerCase();
                if (leaveType.contains('cuti') || leaveType.contains('leave')) {
                  approvedCutiDates.add(pk);
                } else {
                  // Default ke izin jika bukan cuti
                  approvedIzinDates.add(pk);
                }
              }
            }
          } catch (_) {}
        }

        // Count permissions that were not already represented by attendance records
        final newIzinDates = approvedIzinDates.difference(
          izinDatesFromAttendance,
        );
        izin += newIzinDates.length;

        final newCutiDates = approvedCutiDates.difference(
          cutiDatesFromAttendance,
        );
        cuti += newCutiDates.length;

        // Compute 'alpha' by looking at scheduled assignments: if a date has a scheduled shift but
        // no attendance and no approved permission, count as alpha.
        final scheduleService = ScheduleService();
        final schedule = await scheduleService.fetchScheduleByEmployeeId(
          employeeId,
        );
        if (schedule != null) {
          final assignments = schedule.assignments;
          for (final entry in assignments.entries) {
            try {
              final dateKey =
                  entry.key; // already normalized to yyyy-MM-dd by service
              final shiftCode = entry.value.toString();
              if (dateKey.startsWith(
                '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}',
              )) {
                // Consider only assigned shifts with a non-empty code
                if (shiftCode.isNotEmpty &&
                    shiftCode != '-' &&
                    !recordedDates.contains(dateKey) &&
                    !approvedIzinDates.contains(dateKey) &&
                    !approvedCutiDates.contains(dateKey)) {
                  alpha++;
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Error fetching permissions or schedules for stats: $e');
      }

      return AttendanceSummary(
        hadir: hadir,
        cuti: cuti,
        izin: izin,
        alpha: alpha,
      );
    } catch (e) {
      debugPrint('fetchEmployeeMonthlySummary error: $e');
      return AttendanceSummary.empty();
    }
  }
}
