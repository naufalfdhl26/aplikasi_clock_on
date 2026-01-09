import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../utils/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/schedule_service.dart';
import '../../data/services/shift_service.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/admin_report_service.dart';
import '../../data/services/permission_service.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/permission_model.dart';

class EmployeeScheduleScreen extends StatefulWidget {
  const EmployeeScheduleScreen({super.key});

  @override
  State<EmployeeScheduleScreen> createState() => _EmployeeScheduleScreenState();
}

class _EmployeeScheduleScreenState extends State<EmployeeScheduleScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _currentDate;
  late String _monthLabel;
  late List<DateTime> _daysOfMonth;
  late Map<String, Map<String, dynamic>> _attendanceData;

  final AuthService _auth = AuthService();
  final ScheduleService _scheduleService = ScheduleService();
  final ShiftService _shiftService = ShiftService();
  final AttendanceService _attendanceService = AttendanceService();
  final PermissionService _permissionService = PermissionService();
  final AdminReportService _adminReportService = AdminReportService();

  StreamSubscription<Map<String, String>>? _attendanceSub;

  String? _employeeId;
  Map<String, String> _scheduleAssignments = {};
  Map<String, ShiftModel> _shiftsByCode = {};
  List<AttendanceModel> _attendanceRecords = [];
  List<PermissionModel> _permissions = [];
  bool _isLoading = true;
  Map<String, String> _adminStatusByDate = {};

  late AnimationController _animationController;
  String? _lastDebugInfo;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _monthLabel = DateFormat("MMMM yyyy", "id_ID").format(_currentDate);
    _daysOfMonth = _generateDaysInMonth(_currentDate.year, _currentDate.month);
    _attendanceData = {};

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _loadEmployeeSchedule();

    // Listen to attendance updates and refresh schedule when relevant
    _attendanceSub = AttendanceService.attendanceUpdates.listen((event) async {
      try {
        debugPrint('ScheduleViewer: attendance event received: $event');
        final eid = event['employeeId'];
        final date = event['date'];
        if (eid == _employeeId && date != null) {
          debugPrint(
            'ScheduleViewer: event matches current employee ($_employeeId) for date: $date',
          );
          final monthPrefix =
              '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}';
          if (date.startsWith(monthPrefix)) {
            // If event includes checkin/checkout times, apply immediately to the
            // existing attendance map to avoid waiting for server aggregation.
            final key = date;
            final rec = _attendanceData[key];
            final updated = Map<String, dynamic>.from(
              rec ?? {'status': 'PC', 'checkin': '--:--', 'checkout': '--:--'},
            );

            final evtCheckin = event['checkin'];
            final evtCheckout = event['checkout'];
            if (evtCheckin != null) {
              // try to format to HH:mm for display
              try {
                final parts = evtCheckin.split(':');
                if (parts.length >= 2) {
                  updated['checkin'] =
                      '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
                } else {
                  updated['checkin'] = evtCheckin;
                }
              } catch (_) {
                updated['checkin'] = evtCheckin;
              }
            }
            if (evtCheckout != null) {
              try {
                final parts = evtCheckout.split(':');
                if (parts.length >= 2) {
                  updated['checkout'] =
                      '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
                } else {
                  updated['checkout'] = evtCheckout;
                }
              } catch (_) {
                updated['checkout'] = evtCheckout;
              }
            }

            // Prefer any locally persisted attendance for this date (saved by AttendanceScreen)
            try {
              final prefs = await SharedPreferences.getInstance();
              final datePrefixKey = 'attendance_${_employeeId}_$date';
              final localKeys = prefs
                  .getKeys()
                  .where((k) => k.startsWith(datePrefixKey))
                  .toList();
              if (localKeys.isNotEmpty) {
                final localRaw = prefs.getString(localKeys.first);
                debugPrint(
                  'ScheduleViewer: found local cached attendance key=${localKeys.first} raw=$localRaw',
                );
                if (localRaw != null) {
                  final localData =
                      jsonDecode(localRaw) as Map<String, dynamic>;
                  final lci = (localData['checkin'] as String?) ?? null;
                  final lco = (localData['checkout'] as String?) ?? null;
                  if (lci != null) updated['checkin'] = _formatTimeString(lci);
                  if (lco != null) updated['checkout'] = _formatTimeString(lco);
                }
              }
            } catch (e) {
              debugPrint(
                'ScheduleViewer: error reading local prefs for $date -> $e',
              );
            }

            // Determine status based on available times and shift/tolerance
            final scheduleCode = _scheduleAssignments[key] ?? '';
            final hasShift =
                scheduleCode.isNotEmpty &&
                _shiftsByCode.containsKey(scheduleCode);
            String status;
            if (updated['checkin'] != null &&
                updated['checkin'] != '--:--' &&
                updated['checkout'] != null &&
                updated['checkout'] != '--:--') {
              // both present -> H or L
              if (hasShift) {
                try {
                  final checkParts = (updated['checkin'] ?? '')
                      .toString()
                      .split(':');
                  final chHour = int.tryParse(checkParts[0]) ?? 0;
                  final chMin = int.tryParse(checkParts[1]) ?? 0;
                  final shift = _shiftsByCode[scheduleCode]!;
                  final shiftMinutes =
                      shift.startTime.hour * 60 + shift.startTime.minute;
                  final checkinMinutes = chHour * 60 + chMin;
                  if (checkinMinutes > shiftMinutes + shift.toleranceMinutes) {
                    status = 'L';
                  } else {
                    status = 'H';
                  }
                } catch (_) {
                  status = 'H';
                }
              } else {
                status = 'H';
              }
            } else if (updated['checkin'] != null &&
                    updated['checkin'] != '--:--' ||
                updated['checkout'] != null && updated['checkout'] != '--:--') {
              status = 'PC';
            } else {
              status = 'A';
            }

            debugPrint(
              'ScheduleViewer: applying event override for $key -> status:$status checkin:${updated['checkin']} checkout:${updated['checkout']}',
            );
            setState(() {
              _attendanceData[key] = {
                'status': status,
                'checkin': updated['checkin'] ?? '--:--',
                'checkout': updated['checkout'] ?? '--:--',
              };
              _lastDebugInfo =
                  'Event $key: ${updated['checkin'] ?? '--:--'}/${updated['checkout'] ?? '--:--'}';
            });

            // Try to fetch admin-reported status for this date and prefer it
            try {
              final adminMonthAttendance = await _adminReportService
                  .fetchAttendanceByMonth(
                    year: _currentDate.year,
                    month: _currentDate.month,
                  );
              for (final a in adminMonthAttendance) {
                if (a.employeeId.trim().toLowerCase() ==
                        _employeeId?.trim().toLowerCase() &&
                    _formatDate(a.date) == key) {
                  final adminCode = _mapAdminStatusToCode(a.status ?? '');
                  debugPrint(
                    'ScheduleViewer: event->applied admin status for $key -> ${a.status} ($adminCode)',
                  );
                  setState(() {
                    _attendanceData[key] = {
                      'status': adminCode,
                      'checkin': _attendanceData[key]?['checkin'] ?? '--:--',
                      'checkout': _attendanceData[key]?['checkout'] ?? '--:--',
                    };
                    _lastDebugInfo =
                        'Admin status applied for $key: ${a.status}';
                  });
                  break;
                }
              }
            } catch (e) {
              debugPrint('ScheduleViewer: admin fetch on event failed: $e');
            }

            // Also trigger a full reload in background to keep data consistent
            // with server (non-blocking)
            unawaited(_loadEmployeeSchedule());
          }
        }
      } catch (e) {
        debugPrint('ScheduleViewer event handler error: $e');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    try {
      _attendanceSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadEmployeeSchedule() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final emp = await _auth.fetchEmployeeByEmail(user.email ?? '');
      if (emp == null) return;

      _employeeId = emp['id']?.toString();

      // Load schedule assignments
      final schedules = await _scheduleService.fetchAllSchedules();
      for (final s in schedules) {
        if (s.employeeId == _employeeId) {
          final createdByAdminId = emp['createdByAdminId'];
          if (createdByAdminId != null) {
            final rawShifts = await _shiftService.fetchAllShifts(
              createdByAdminId.toString(),
            );
            final map = <String, ShiftModel>{};
            for (final rs in rawShifts) {
              try {
                final sm = ShiftModel.fromMap(Map<String, dynamic>.from(rs));
                if (sm.code.isNotEmpty) map[sm.code] = sm;
              } catch (_) {}
            }
            _shiftsByCode = map;
          }

          _scheduleAssignments = Map<String, String>.from(s.assignments);

          // Ensure we have shift models for all assigned codes (so per-day rows can show times)
          final assignedCodes = _scheduleAssignments.values
              .where((c) => c.isNotEmpty)
              .toSet();
          if (assignedCodes.isNotEmpty) {
            try {
              final fallback = await _shiftService.fetchAllShifts('');
              final map = Map<String, ShiftModel>.from(_shiftsByCode);
              for (final rs in fallback) {
                try {
                  final sModel = ShiftModel.fromMap(
                    Map<String, dynamic>.from(rs),
                  );
                  if (sModel.code.isNotEmpty &&
                      assignedCodes.contains(sModel.code)) {
                    map[sModel.code] = sModel;
                  }
                } catch (_) {}
              }
              _shiftsByCode = map;
            } catch (_) {}
          }

          break;
        }
      }

      // Load attendance records for current month
      if (_employeeId != null) {
        final startDate = DateTime(_currentDate.year, _currentDate.month, 1);
        final endDate = DateTime(_currentDate.year, _currentDate.month + 1, 0);
        _attendanceRecords = await _attendanceService
            .fetchAttendanceByDateRange(_employeeId!, startDate, endDate);

        debugPrint(
          'ScheduleViewer: fetched attendance records count=${_attendanceRecords.length}',
        );
        // Also fetch admin-reported monthly attendance (contains normalized status)
        _adminStatusByDate.clear();
        try {
          final adminMonthAttendance = await _adminReportService
              .fetchAttendanceByMonth(
                year: _currentDate.year,
                month: _currentDate.month,
              );
          debugPrint(
            'ScheduleViewer: adminMonthAttendance count=${adminMonthAttendance.length}',
          );
          // Store admin status by date for later override of UI
          for (final a in adminMonthAttendance) {
            if (a.employeeId.trim().toLowerCase() ==
                _employeeId?.trim().toLowerCase()) {
              final dkey = _formatDate(a.date);
              final code = _mapAdminStatusToCode(a.status ?? '');
              _adminStatusByDate[dkey] = code;
              debugPrint(
                'ScheduleViewer: admin status for $dkey -> ${a.status} ($code)',
              );
            }
          }
        } catch (e) {
          debugPrint('Error fetching admin monthly attendance: $e');
          debugPrint(
            'ScheduleViewer: exception caught while fetching admin attendance',
          );
        }

        // Load permissions for current month
        final allPermissions = await _permissionService.fetchAllPermissions();
        _permissions = allPermissions.where((p) {
          return p.employeeId == _employeeId &&
              p.leaveDate.year == _currentDate.year &&
              p.leaveDate.month == _currentDate.month;
        }).toList();
      }

      // Build attendance data map
      _buildAttendanceDataMap();

      // Apply any admin-provided status overrides so UI shows admin status immediately
      _applyAdminStatusOverrides();

      // Apply any local attendance overrides (from SharedPreferences) so
      // recent checkin/checkout actions on this device appear immediately
      // in the schedule view even if server hasn't aggregated yet.
      await _applyLocalAttendanceOverrides();

      // Ensure today's status is updated by date if local/server records exist
      await _ensureTodayStatusFromLocalOrRecords();
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureTodayStatusFromLocalOrRecords() async {
    if (_employeeId == null) return;
    try {
      final todayKey = _formatDate(DateTime.now());
      final current = _attendanceData[todayKey];
      if (current != null && (current['status'] ?? '') != 'A') {
        // already has non-Alpha status
        return;
      }

      // Check SharedPreferences for any local key for today
      final prefs = await SharedPreferences.getInstance();
      final localKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('attendance_${_employeeId}_$todayKey'))
          .toList();

      Map<String, dynamic>? localData;
      if (localKeys.isNotEmpty) {
        final raw = prefs.getString(localKeys.first);
        if (raw != null) localData = jsonDecode(raw) as Map<String, dynamic>;
      }

      // Check server-fetched attendanceRecords for today
      final serverList = _attendanceRecords
          .where((a) => _formatDate(a.date) == todayKey)
          .toList();

      if (localData == null && serverList.isEmpty) return;

      String status = 'PC';
      String checkin = '--:--';
      String checkout = '--:--';

      // Prefer local data for immediacy
      if (localData != null) {
        final lci = (localData['checkin'] as String?) ?? null;
        final lco = (localData['checkout'] as String?) ?? null;
        if (lci != null) checkin = _formatTimeString(lci);
        if (lco != null) checkout = _formatTimeString(lco);

        if (lci != null && lco != null) {
          // compute H/L using today's shift
          final scheduleCode = _scheduleAssignments[todayKey] ?? '';
          if (scheduleCode.isNotEmpty &&
              _shiftsByCode.containsKey(scheduleCode)) {
            try {
              final parts = lci.split(':');
              final chHour = int.tryParse(parts[0]) ?? 0;
              final chMin = int.tryParse(parts[1]) ?? 0;
              final shift = _shiftsByCode[scheduleCode]!;
              final shiftMinutes =
                  shift.startTime.hour * 60 + shift.startTime.minute;
              final checkinMinutes = chHour * 60 + chMin;
              status = (checkinMinutes > shiftMinutes + shift.toleranceMinutes)
                  ? 'L'
                  : 'H';
            } catch (_) {
              status = 'H';
            }
          } else {
            status = 'H';
          }
        } else {
          status = 'PC';
        }
      } else {
        // Use server record
        final a = serverList.first;
        if (a.checkin != null) checkin = DateFormat('HH:mm').format(a.checkin!);
        if (a.checkout != null)
          checkout = DateFormat('HH:mm').format(a.checkout!);
        if (a.checkin != null && a.checkout != null) {
          final scheduleCode = _scheduleAssignments[todayKey] ?? '';
          if (scheduleCode.isNotEmpty &&
              _shiftsByCode.containsKey(scheduleCode)) {
            try {
              final chHour = a.checkin!.hour;
              final chMin = a.checkin!.minute;
              final shift = _shiftsByCode[scheduleCode]!;
              final shiftMinutes =
                  shift.startTime.hour * 60 + shift.startTime.minute;
              final checkinMinutes = chHour * 60 + chMin;
              status = (checkinMinutes > shiftMinutes + shift.toleranceMinutes)
                  ? 'L'
                  : 'H';
            } catch (_) {
              status = 'H';
            }
          } else {
            status = 'H';
          }
        } else {
          status = 'PC';
        }
      }

      setState(() {
        _attendanceData[todayKey] = {
          'status': status,
          'checkin': checkin,
          'checkout': checkout,
        };
        _lastDebugInfo = 'Today status adjusted by date: $status';
      });
    } catch (e) {
      debugPrint('Error ensuring today status: $e');
    }
  }

  Future<void> _applyLocalAttendanceOverrides() async {
    if (_employeeId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final datePrefix = 'attendance_${_employeeId}_';
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith(datePrefix))
          .toList();
      debugPrint(
        'ScheduleViewer: found local attendance keys: ${keys.join(', ')}',
      );
      setState(() {
        _lastDebugInfo = keys.isEmpty
            ? null
            : 'Found local keys: ${keys.join(', ')}';
      });

      var changed = false;
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final data = jsonDecode(raw) as Map<String, dynamic>;
        // extract date from key
        final parts = k.split('_');
        if (parts.length < 3) continue;
        final date = parts[2]; // YYYY-MM-DD

        final checkin = (data['checkin'] as String?) ?? null;
        final checkout = (data['checkout'] as String?) ?? null;

        final rec =
            _attendanceData[date] ??
            {'status': 'A', 'checkin': '--:--', 'checkout': '--:--'};
        final updated = Map<String, dynamic>.from(rec);

        if (checkin != null) {
          final hhmm = _formatTimeString(checkin);
          updated['checkin'] = hhmm;
        }
        if (checkout != null) {
          final hhmm = _formatTimeString(checkout);
          updated['checkout'] = hhmm;
        }

        // Recompute status...
        // (kode status sama seperti sebelumnya)
        String status;
        final scheduleCode = _scheduleAssignments[date] ?? '';
        final hasShift =
            scheduleCode.isNotEmpty && _shiftsByCode.containsKey(scheduleCode);
        if (updated['checkin'] != null &&
            updated['checkin'] != '--:--' &&
            updated['checkout'] != null &&
            updated['checkout'] != '--:--') {
          if (hasShift) {
            try {
              final parts = (data['checkin'] as String).split(':');
              final chHour = int.tryParse(parts[0]) ?? 0;
              final chMin = int.tryParse(parts[1]) ?? 0;
              final shift = _shiftsByCode[scheduleCode]!;
              final shiftMinutes =
                  shift.startTime.hour * 60 + shift.startTime.minute;
              final checkinMinutes = chHour * 60 + chMin;
              if (checkinMinutes > shiftMinutes + shift.toleranceMinutes) {
                status = 'L';
              } else {
                status = 'H';
              }
            } catch (_) {
              status = 'H';
            }
          } else {
            status = 'H';
          }
        } else if (updated['checkin'] != null &&
                updated['checkin'] != '--:--' ||
            updated['checkout'] != null && updated['checkout'] != '--:--') {
          status = 'PC';
        } else {
          status = 'A';
        }

        updated['status'] = status;
        _attendanceData[date] = updated;
        changed = true;
      }

      if (changed) {
        setState(() {
          _lastDebugInfo = 'Local override applied';
        });
      }
    } catch (e) {
      debugPrint('Error applying local attendance overrides: $e');
    }
  }

  String _formatTimeString(String s) {
    // s may be ISO datetime or HH:mm:ss or HH:mm
    try {
      if (s.contains('T')) {
        final dt = DateTime.parse(s);
        return DateFormat('HH:mm').format(dt);
      }
      final parts = s.split(':');
      if (parts.length >= 2)
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      return s;
    } catch (_) {
      return s;
    }
  }

  void _buildAttendanceDataMap() {
    final Map<String, Map<String, dynamic>> data = {};

    for (var day in _daysOfMonth) {
      final key = _formatDate(day);

      // Check if there's a shift assignment for this day
      final scheduleCode = _scheduleAssignments[key] ?? '';
      final hasShiftAssignment = scheduleCode.isNotEmpty;

      // Check if this is weekend
      final isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

      // Check for permission on this day
      final permission = _permissions.where((p) {
        return _formatDate(p.leaveDate) == key && p.status == 'approved';
      }).firstOrNull;

      // Check for attendance record on this day
      final attendance = _attendanceRecords.where((a) {
        return _formatDate(a.date) == key;
      }).firstOrNull;

      // Determine status
      String status;
      String checkin = '--:--';
      String checkout = '--:--';

      // Priority 1: Check if there's no shift assignment (not scheduled)
      if (!hasShiftAssignment) {
        // No shift assigned - show as not available/grey
        status = 'TS'; // Tidak Tersedia / Not Scheduled
        checkin = '--:--';
        checkout = '--:--';
      } else if (permission != null) {
        // Priority 2: Has approved permission
        if (permission.type.toLowerCase().contains('cuti')) {
          status = 'C';
        } else {
          status = 'I';
        }
      } else if (attendance != null) {
        // Priority 3: Has attendance record
        // If server/admin supplied a status string, prefer it (normalized via admin report)
        if (attendance.status.trim().isNotEmpty) {
          status = _mapAdminStatusToCode(attendance.status);
          checkin = '--:--';
          checkout = '--:--';
        } else {
          if (attendance.checkin != null) {
            checkin = DateFormat('HH:mm').format(attendance.checkin!);
          }
          if (attendance.checkout != null) {
            checkout = DateFormat('HH:mm').format(attendance.checkout!);
          }

          // Only mark as 'H' (Present) when both check-in and check-out exist.
          if (attendance.checkin != null && attendance.checkout != null) {
            final checkinTime = attendance.checkin!;
            if (_shiftsByCode.containsKey(scheduleCode)) {
              final shift = _shiftsByCode[scheduleCode]!;
              final shiftStart = shift.startTime;

              // Compare time only
              final shiftMinutes = shiftStart.hour * 60 + shiftStart.minute;
              final checkinMinutes = checkinTime.hour * 60 + checkinTime.minute;

              if (checkinMinutes > shiftMinutes + shift.toleranceMinutes) {
                status = 'L'; // Late
              } else {
                status = 'H'; // Present
              }
            } else {
              status = 'H';
            }
          } else if (attendance.checkin != null ||
              attendance.checkout != null) {
            // Partial presence, waiting for the other action
            status = 'PC'; // Partial / Menunggu aksi lain
          } else {
            status = 'A'; // Absent or invalid record
          }
        }
      } else if (isWeekend) {
        // Weekend - Libur (but only if has shift assignment)
        status = 'LIBUR';
      } else if (day.isAfter(DateTime.now())) {
        // Future date with shift assignment
        status = 'BH'; // Belum Hadir
      } else {
        // Past date with shift assignment but no attendance - Alpha
        status = 'A';
      }

      data[key] = {'status': status, 'checkin': checkin, 'checkout': checkout};
    }

    _attendanceData = data;
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _mapAdminStatusToCode(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('hadir') || s.contains('present') || s == 'h') return 'H';
    if (s.contains('terlambat') || s.contains('late')) return 'L';
    if (s.contains('cuti') || s == 'c') return 'C';
    if (s.contains('izin') || s.contains('permission') || s == 'i') return 'I';
    if (s.contains('alpha') || s.contains('absent') || s == 'a') return 'A';
    return 'PC';
  }

  void _applyAdminStatusOverrides() {
    if (_adminStatusByDate.isEmpty) return;
    var changed = false;
    _adminStatusByDate.forEach((date, code) {
      final rec =
          _attendanceData[date] ??
          {'status': 'A', 'checkin': '--:--', 'checkout': '--:--'};
      if (rec['status'] != code) {
        _attendanceData[date] = {
          'status': code,
          'checkin': rec['checkin'] ?? '--:--',
          'checkout': rec['checkout'] ?? '--:--',
        };
        changed = true;
      }
    });
    if (changed) {
      setState(() {
        _lastDebugInfo = 'Admin overrides applied';
      });
    }
  }

  void _changeMonth(int delta) {
    final newDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
    setState(() {
      _currentDate = newDate;
      _monthLabel = DateFormat("MMMM yyyy", "id_ID").format(_currentDate);
      _daysOfMonth = _generateDaysInMonth(
        _currentDate.year,
        _currentDate.month,
      );
      _attendanceData = {};
    });
    _loadEmployeeSchedule();
    _animationController.reset();
    _animationController.forward();
  }

  List<DateTime> _generateDaysInMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final nextMonthFirst = DateTime(year, month + 1, 1);
    final days = nextMonthFirst.difference(first).inDays;
    return List.generate(days, (i) => DateTime(year, month, i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _splitIntoWeeks(_daysOfMonth);

    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat jadwal...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: true,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        'Jadwal Kerja',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(80),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => _changeMonth(-1),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _monthLabel,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeMonth(1),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey.shade50, Colors.white],
                  ),
                ),
                child: Column(
                  children: [
                    if (_lastDebugInfo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.yellow.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.yellow.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _lastDebugInfo!,
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: weeks.length,
                        itemBuilder: (context, weekIndex) {
                          return SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.5),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: Interval(weekIndex * 0.2, 1.0),
                                  ),
                                ),
                            child: FadeTransition(
                              opacity: _animationController,
                              child: _buildWeekCard(
                                weeks[weekIndex],
                                weekIndex + 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWeekCard(List<DateTime> week, int weekNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Minggu $weekNumber',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('d MMM', 'id_ID').format(week.first)} - ${DateFormat('d MMM', 'id_ID').format(week.last)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          ...week.map((day) => _buildDayRow(day)),
        ],
      ),
    );
  }

  Widget _buildDayRow(DateTime day) {
    final key = _formatDate(day);
    final record = _attendanceData[key] ?? {};
    final status = record['status'] ?? '-';
    final checkin = record['checkin'] ?? '--:--';
    final checkout = record['checkout'] ?? '--:--';

    final scheduleCode = _scheduleAssignments[key] ?? '';
    final hasShiftAssignment = scheduleCode.isNotEmpty;
    String displayShift;
    String shiftTimes = '';

    // Only show shift if it's assigned by admin
    if (hasShiftAssignment && _shiftsByCode.containsKey(scheduleCode)) {
      final sm = _shiftsByCode[scheduleCode]!;
      final st = DateFormat('HH:mm').format(sm.startTime);
      final et = DateFormat('HH:mm').format(sm.endTime);
      displayShift = sm.label.toUpperCase();
      shiftTimes = '$st\u2013$et';
    } else if (hasShiftAssignment) {
      // Has assignment but shift not found in database
      displayShift = 'SHIFT $scheduleCode';
      shiftTimes = '--:-- & --:--';
    } else {
      // No shift assignment from admin
      displayShift = 'TIDAK TERSEDIA';
      shiftTimes = '';
    }

    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: day.weekday >= DateTime.saturday
                      ? Colors.orange.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: day.weekday >= DateTime.saturday
                        ? Colors.orange.withOpacity(0.3)
                        : AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE', 'id_ID').format(day),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      day.day.toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayShift,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: hasShiftAssignment
                            ? AppColors.primaryDark
                            : Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shiftTimes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        shiftTimes,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Check-in/check-out times are intentionally hidden in this view.
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'H':
        return const Color(0xFF10B981); // Green
      case 'L':
        return const Color(0xFFF59E0B); // Orange
      case 'PC':
        return const Color(0xFFF59E0B); // Orange (partial)
      case 'I':
        return const Color(0xFF3B82F6); // Blue
      case 'C':
        return const Color(0xFF8B5CF6); // Purple
      case 'A':
        return const Color(0xFFEF4444); // Red
      case 'BH':
        return const Color(0xFF9CA3AF); // Grey
      case 'TS':
        return const Color(0xFFD1D5DB); // Light Grey
      case 'LIBUR':
        return const Color(0xFF6B7280); // Medium Grey
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'H':
        return 'Hadir';
      case 'L':
        return 'Terlambat';
      case 'PC':
        return 'Menunggu Checkout';
      case 'I':
        return 'Izin';
      case 'C':
        return 'Cuti';
      case 'A':
        return 'Alpha';
      case 'BH':
        return 'Belum Hadir';
      case 'TS':
        return '--';
      case 'LIBUR':
        return 'Libur';
      default:
        return '--';
    }
  }

  List<List<DateTime>> _splitIntoWeeks(List<DateTime> days) {
    final List<List<DateTime>> weeks = [];
    List<DateTime> currentWeek = [];

    for (final day in days) {
      currentWeek.add(day);
      if (currentWeek.length == 7 || day == days.last) {
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }

    return weeks;
  }
}
