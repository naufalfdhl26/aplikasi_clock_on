import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/attendance_model.dart';
import '../models/employee_model.dart';

class AdminReportService {
  final DataService _api = DataService();

  /// Fetch all attendance records for a given month
  Future<List<AttendanceModel>> fetchAttendanceByMonth({
    required int year,
    required int month,
  }) async {
    try {
      final res = await _api.selectAll(token, project, 'attendance', appid);
      if (res == null || res == '[]') {
        debugPrint('❌ No attendance response from API');
        return [];
      }

      debugPrint('📦 Raw response length: ${res.length} chars');

      dynamic decoded;
      try {
        decoded = jsonDecode(res);
      } catch (e) {
        debugPrint('JSON decode error in fetchAttendanceByMonth: $e');
        return [];
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

      debugPrint('📦 Total items in response: ${items.length}');

      // Parse all attendance records
      final allAttendance = items.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return AttendanceModel.fromJson(map);
      }).toList();

      debugPrint(
        '📊 Total attendance records parsed: ${allAttendance.length}',
      );

      // Debug: Print sample of parsed records
      if (allAttendance.isNotEmpty) {
        debugPrint('📝 Sample parsed records:');
        for (
          var i = 0;
          i < (allAttendance.length > 3 ? 3 : allAttendance.length);
          i++
        ) {
          final att = allAttendance[i];
          debugPrint(
            '   [$i] Employee: "${att.employeeId}", Status: ${att.status}, Date: ${att.date}',
          );
        }
      }

      debugPrint('📅 Filtering for year: $year, month: $month');

      // Filter by month and year
      final filtered = allAttendance.where((att) {
        return att.date.year == year && att.date.month == month;
      }).toList();

      debugPrint('✅ Filtered attendance records: ${filtered.length}');
      if (filtered.isNotEmpty) {
        debugPrint(
          '   First record: ${filtered.first.employeeId} - ${filtered.first.status} - ${filtered.first.date}',
        );
      }

      return filtered;
    } catch (e, st) {
      debugPrint('fetchAttendanceByMonth error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  /// Calculate statistics from attendance records
  Map<String, int> calculateStatistics(List<AttendanceModel> records) {
    debugPrint('\n📊 === CALCULATE STATISTICS ===');
    debugPrint('📊 Processing ${records.length} records');

    int hadir = 0;
    int cuti = 0;
    int tidakHadir = 0;
    int izin = 0;

    for (final record in records) {
      final status = record.status.trim().toLowerCase();
      
      debugPrint('   Checking: "$status"');

      if (status.contains('present') || status.contains('hadir') || status == 'h') {
        hadir++;
      } else if (status.contains('leave') || status.contains('cuti') || status == 'c') {
        cuti++;
      } else if (status.contains('permission') || status.contains('izin') || status == 'i') {
        izin++;
      } else if (status.contains('absent') || status.contains('alpha') || status == 'a') {
        tidakHadir++;
      } else {
        debugPrint('   ⚠️  Unknown status: "$status"');
      }
    }

    final result = {
      'Hadir': hadir,
      'Cuti': cuti,
      'Tidak Hadir': tidakHadir,
      'Izin': izin,
    };
    
    debugPrint('📊 Final stats: $result');
    return result;
  }

  /// Fetch all employees
  Future<List<EmployeeModel>> fetchAllEmployees() async {
    try {
      final res = await _api.selectAll(token, project, 'employee', appid);
      debugPrint(
        '👥 Employee API Response: ${res?.substring(0, res.length > 100 ? 100 : res.length)}...',
      );
      if (res == null || res == '[]') return [];

      dynamic decoded;
      try {
        decoded = jsonDecode(res);
      } catch (e) {
        debugPrint('JSON decode error in fetchAllEmployees: $e');
        return [];
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

      final employees = items
          .map(
            (e) => EmployeeModel.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      debugPrint('👥 Total employees fetched: ${employees.length}');
      return employees;
    } catch (e, st) {
      debugPrint('fetchAllEmployees error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  /// Get attendance summary grouped by division
  Future<List<Map<String, dynamic>>> getDivisionAttendanceSummary({
    required int year,
    required int month,
  }) async {
    try {
      debugPrint('\n🔍 Getting division summary for $year-$month');
      final employees = await fetchAllEmployees();
      final attendance = await fetchAttendanceByMonth(year: year, month: month);
      debugPrint(
        '📋 Processing ${employees.length} employees and ${attendance.length} attendance records',
      );

      // Debug: Print sample employees
      if (employees.isNotEmpty) {
        debugPrint('👥 Sample employees:');
        for (
          var i = 0;
          i < (employees.length > 3 ? 3 : employees.length);
          i++
        ) {
          final emp = employees[i];
          debugPrint(
            '   [$i] ID: "${emp.id}", Name: ${emp.name}, Division: ${emp.division}',
          );
        }
      }

      // Group employees by division
      final divisionMap = <String, List<EmployeeModel>>{};
      for (final employee in employees) {
        final division = employee.division.isEmpty
            ? 'Tidak Ada Divisi'
            : employee.division;
        if (!divisionMap.containsKey(division)) {
          divisionMap[division] = [];
        }
        divisionMap[division]!.add(employee);
      }

      final summary = <Map<String, dynamic>>[];

      // Calculate statistics per division
      for (final entry in divisionMap.entries) {
        final divisionName = entry.key;
        final divisionEmployees = entry.value;

        int hadir = 0;
        int cuti = 0;
        int tidakHadir = 0;
        int izin = 0;
        int totalKaryawan = divisionEmployees.length;

        // Get all attendance records for employees in this division
        for (final employee in divisionEmployees) {
          final employeeAttendance = attendance.where((att) {
            // Normalize both IDs for comparison
            final attEmpId = (att.employeeId).trim().toLowerCase();
            final empId = (employee.id).trim().toLowerCase();
            return attEmpId == empId;
          }).toList();

          if (employeeAttendance.isNotEmpty) {
            debugPrint(
              '👤 Employee ${employee.name} (${employee.id}): ${employeeAttendance.length} records',
            );
          }

          for (final record in employeeAttendance) {
            final status = record.status.toLowerCase();

            if (status.contains('present') || status.contains('hadir')) {
              hadir++;
            } else if (status.contains('leave') || status.contains('cuti')) {
              cuti++;
            } else if (status.contains('permission') ||
                status.contains('izin')) {
              izin++;
            } else if (status.contains('absent') || status.contains('alpha')) {
              tidakHadir++;
            }
          }
        }

        summary.add({
          'division': divisionName,
          'totalKaryawan': totalKaryawan,
          'hadir': hadir,
          'cuti': cuti,
          'tidakHadir': tidakHadir,
          'izin': izin,
          'total': hadir + cuti + tidakHadir + izin,
        });
      }

      // Sort by division name
      summary.sort(
        (a, b) => a['division'].toString().compareTo(b['division'].toString()),
      );

      return summary;
    } catch (e, st) {
      debugPrint('getDivisionAttendanceSummary error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  /// Get daily attendance data for a specific month
  Future<List<Map<String, dynamic>>> getDailyAttendance({
    required int year,
    required int month,
  }) async {
    try {
      debugPrint('\n📅 Getting daily attendance for $year-$month');
      final employees = await fetchAllEmployees();
      final attendance = await fetchAttendanceByMonth(year: year, month: month);

      debugPrint(
        '📋 Processing ${employees.length} employees and ${attendance.length} attendance records for daily view',
      );

      // Create employee lookup map for faster access
      final employeeMap = <String, EmployeeModel>{};
      for (final employee in employees) {
        employeeMap[employee.id.trim().toLowerCase()] = employee;
      }

      // Convert attendance records to daily format
      final dailyData = <Map<String, dynamic>>[];

      for (final record in attendance) {
        final employeeId = record.employeeId.trim().toLowerCase();
        final employee = employeeMap[employeeId];

        if (employee != null) {
          // Format check-in and check-out times
          String checkInTime = '-';
          String checkOutTime = '-';

          if (record.checkin != null) {
            checkInTime = DateFormat('HH:mm').format(record.checkin!);
          }
          if (record.checkout != null) {
            checkOutTime = DateFormat('HH:mm').format(record.checkout!);
          }

          dailyData.add({
            'employeeName': employee.name,
            'date': record.date,
            'status': record.status,
            'checkInTime': checkInTime,
            'checkOutTime': checkOutTime,
          });
        }
      }

      // Sort by date (newest first) and then by employee name
      dailyData.sort((a, b) {
        final dateCompare = (b['date'] as DateTime).compareTo(a['date'] as DateTime);
        if (dateCompare != 0) return dateCompare;
        return (a['employeeName'] as String).compareTo(b['employeeName'] as String);
      });

      debugPrint('✅ Daily attendance data prepared: ${dailyData.length} records');
      return dailyData;
    } catch (e, st) {
      debugPrint('getDailyAttendance error: $e');
      debugPrint(st.toString());
      return [];
    }
  }
}
