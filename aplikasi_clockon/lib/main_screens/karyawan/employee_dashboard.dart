import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/statistics_service.dart';
import '../../data/services/schedule_service.dart';
import '../../data/services/shift_service.dart';
import '../../data/models/attendance_summary_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/models/schedule_model.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final AuthService _authService = AuthService();
  final StatisticsService _statsService = StatisticsService();
  final ScheduleService _scheduleService = ScheduleService();
  final ShiftService _shiftService = ShiftService();

  String _email = 'employee@email.com';
  String? _avatarPath;
  AttendanceSummary _summary = AttendanceSummary.empty();
  bool _loadingSummary = true;

  String? _todayShiftName;
  String? _todayShiftTime;
  String _shiftStatus = 'Tidak Tersedia';
  bool _loadingShift = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final emp = await _authService.fetchEmployeeByEmail(user.email ?? '');
    debugPrint('🔍 Employee data: $emp');
    if (emp != null) {
      setState(() {
        _email = (emp['email'] ?? user.email ?? _email).toString();
        _avatarPath =
            (emp['avatarPath'] ??
                    emp['avatar_path'] ??
                    emp['avatar'] ??
                    emp['avatarUrl'])
                ?.toString();
      });

      // Fetch monthly attendance summary for current employee
      final empId = (emp['id'] ?? emp['_id'] ?? '').toString();
      debugPrint('🔍 Employee ID loaded: $empId');
      debugPrint('🔍 Created By Admin ID: ${emp['createdByAdminId']}');
      if (empId.isNotEmpty) {
        // Load today's shift
        await _loadTodayShift(empId, emp);

        final now = DateTime.now();
        final stats = await _statsService.fetchEmployeeMonthlySummary(
          empId,
          now.year,
          now.month,
        );
        if (mounted) {
          setState(() {
            _summary = stats;
            _loadingSummary = false;
          });
        }
      } else {
        debugPrint('❌ Employee ID is empty');
        if (mounted) {
          setState(() {
            _loadingSummary = false;
            _loadingShift = false;
          });
        }
      }
    } else {
      debugPrint('❌ Employee data is null');
      setState(() {
        _email = user.email ?? _email;
        _loadingSummary = false;
        _loadingShift = false;
      });
    }
  }

  Future<void> _loadTodayShift(
    String employeeId,
    Map<String, dynamic> emp,
  ) async {
    try {
      debugPrint('=== LOAD TODAY SHIFT ===');
      final today = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(today);

      debugPrint('📅 Today date key: $todayKey');
      debugPrint('👤 Employee ID: $employeeId');

      // Step 1: Load all schedules
      final schedules = await _scheduleService.fetchAllSchedules();
      debugPrint('📊 Total schedules: ${schedules.length}');

      // Step 2: Find this employee's schedule (may be null)
      ScheduleModel? employeeSchedule;
      for (final s in schedules) {
        if (s.employeeId == employeeId) {
          employeeSchedule = s;
          debugPrint('✅ Found employee schedule');
          debugPrint('📋 All assignments: ${s.assignments}');
          break;
        }
      }

      // Step 3: Get shift code for today. If not assigned in schedule, fallback to employee field
      String? shiftCode;
      if (employeeSchedule != null) {
        shiftCode = employeeSchedule.assignments[todayKey];
      }
      debugPrint('🔑 Shift code for $todayKey (from schedule): $shiftCode');

      if (shiftCode == null || shiftCode.isEmpty) {
        final fallbackShift =
            emp['shift'] ??
            emp['shiftId'] ??
            emp['shiftCode'] ??
            emp['schedule'];
        shiftCode = fallbackShift?.toString();
        debugPrint('🔁 Fallback employee shift value: $shiftCode');
      }

      if (shiftCode == null || shiftCode.isEmpty) {
        debugPrint('❌ No shift assigned for today (and no employee fallback)');
        setState(() {
          _todayShiftName = null;
          _todayShiftTime = null;
          _shiftStatus = 'Tidak Ada Shift';
          _loadingShift = false;
        });
        return;
      }

      // Make a non-null shift key for comparisons
      final String shiftKey = shiftCode;

      // Step 4: Load shifts (prefer admin-specific, fallback to global)
      final createdByAdminId = emp['createdByAdminId'];
      debugPrint('👨‍💼 Admin ID: $createdByAdminId');

      final adminIdArg = createdByAdminId?.toString() ?? '';
      final rawShifts = await _shiftService.fetchAllShifts(adminIdArg);
      debugPrint(
        '📚 Total shifts fetched: ${rawShifts.length} (adminIdArg="$adminIdArg")',
      );

      // Step 5: Find matching shift (match by code or id)
      ShiftModel? todayShift;
      for (final rs in rawShifts) {
        try {
          final sm = ShiftModel.fromMap(Map<String, dynamic>.from(rs));
          debugPrint(
            '  - Checking shift: ${sm.label} (code=${sm.code}, id=${sm.id})',
          );
          if (sm.code == shiftKey || sm.id == shiftKey) {
            todayShift = sm;
            debugPrint('✅ Match found! Shift: ${sm.label}');
            break;
          }
        } catch (e) {
          debugPrint('  - Error parsing shift: $e');
        }
      }

      if (todayShift == null) {
        debugPrint('❌ No matching shift found');
        setState(() {
          _todayShiftName = null;
          _todayShiftTime = null;
          _shiftStatus = 'Tidak Ada Shift';
          _loadingShift = false;
        });
        return;
      }

      // Step 6: Calculate status
      final now = DateTime.now();
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      final startTime = TimeOfDay(
        hour: todayShift.startTime.hour,
        minute: todayShift.startTime.minute,
      );
      final endTime = TimeOfDay(
        hour: todayShift.endTime.hour,
        minute: todayShift.endTime.minute,
      );

      String status = 'Belum Dimulai';
      if (_isTimeBefore(currentTime, startTime)) {
        status = 'Belum Dimulai';
      } else if (_isTimeBefore(currentTime, endTime)) {
        status = 'Sedang Berlangsung';
      } else {
        status = 'Sudah Selesai';
      }

      debugPrint('⏰ Status: $status');

      final startTimeStr = _formatTimeOfDay(startTime);
      final endTimeStr = _formatTimeOfDay(endTime);

      // Step 7: Update UI
      if (mounted) {
        setState(() {
          _todayShiftName = todayShift!.label;
          _todayShiftTime = '$startTimeStr - $endTimeStr';
          _shiftStatus = status;
          _loadingShift = false;
        });
      }
      debugPrint('✅ Shift loaded successfully: ${todayShift.label}');
    } catch (e, st) {
      debugPrint('❌ ERROR: $e');
      debugPrint('Stack: $st');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isTimeBefore(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour < time2.hour) return true;
    if (time1.hour > time2.hour) return false;
    return time1.minute < time2.minute;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadEmail();
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.9),
                    AppColors.secondary.withOpacity(0.9),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.0),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(_avatarPath!),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white24,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat datang,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '$_email 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Semangat bekerja hari ini!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Shift Today Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Shift Hari Ini",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_loadingShift
                                ? 'Memuat...'
                                : (_todayShiftName != null
                                      ? '$_todayShiftName ($_todayShiftTime)'
                                      : 'Tidak ada shift hari ini')),
                            style: TextStyle(
                              fontSize: 14,
                              color: _todayShiftName != null
                                  ? Colors.grey.shade700
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                _shiftStatus,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _shiftStatus,
                              style: TextStyle(
                                color: _getStatusColor(_shiftStatus),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Attendance Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ringkasan Kehadiran Bulan Ini",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _summaryCard(
                        Icons.check_circle,
                        "Hadir",
                        _loadingSummary ? '...' : '${_summary.hadir}',
                        AppColors.success,
                        Colors.green.withOpacity(0.1),
                      ),
                      _summaryCard(
                        Icons.beach_access,
                        "Cuti",
                        _loadingSummary ? '...' : '${_summary.cuti}',
                        AppColors.warning,
                        Colors.orange.withOpacity(0.1),
                      ),
                      _summaryCard(
                        Icons.work_off,
                        "Izin",
                        _loadingSummary ? '...' : '${_summary.izin}',
                        AppColors.info,
                        Colors.blue.withOpacity(0.1),
                      ),
                      _summaryCard(
                        Icons.close,
                        "Alpha",
                        _loadingSummary ? '...' : '${_summary.alpha}',
                        AppColors.error,
                        Colors.red.withOpacity(0.1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    IconData icon,
    String title,
    String value,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sedang Berlangsung':
        return Colors.green.shade700;
      case 'Belum Dimulai':
        return Colors.orange.shade700;
      case 'Sudah Selesai':
        return Colors.grey.shade600;
      case 'Tidak Ada Shift':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
