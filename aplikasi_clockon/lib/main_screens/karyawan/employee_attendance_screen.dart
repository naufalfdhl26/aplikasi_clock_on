import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/theme/app_theme.dart';
import '../../data/models/location_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/services/wifi_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/schedule_service.dart';
import '../../data/services/shift_service.dart';

import '../../data/models/attendance_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../utils/route_observer.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with RouteAware {
  bool _isLoading = false;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  bool _hasApprovedPermissionToday = false;

  String _checkInTime = '--:--';
  String _checkOutTime = '--:--';

  String _wifiSsid = 'Tidak terhubung';
  String _wifiBssid = '-';

  List<LocationModel> _matchedOffices = [];
  final WifiService _wifiService = WifiService();
  final LocationService _locationService = LocationService();
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  final ScheduleService _scheduleService = ScheduleService();
  final ShiftService _shiftService = ShiftService();
  ShiftModel? _todayShift;
  String? _todayShiftCode;
  bool _hasShiftAssignmentToday = false;
  bool _isWithinShiftCheckIn = false;
  bool _isWithinShiftCheckOut = false;
  String? _adminId;
  String? _employeeId;
  String? _lastSavedAttendanceKey;

  @override
  void initState() {
    super.initState();
    _loadEmployeeCredentials();
    _requestPermissionsAndCheckWifi();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  void _loadEmployeeCredentials() async {
    final user = _authService.currentUser;
    if (user == null) return;
    final emp = await _authService.fetchEmployeeByEmail(user.email ?? '');
    if (emp != null) {
      // store employee and admin info, then load dependent data
      setState(() {
        _employeeId = emp['id']?.toString();
        _adminId =
            emp['createdByAdminId']?.toString() ??
            emp['createdby']?.toString() ??
            emp['createdBy']?.toString();
      });

      // Check approved permission and today's shift
      _checkApprovedPermissionToday();
      await _loadTodayShift(emp);
      // Load today's attendance from server and local cache
      await _loadTodayAttendance();
      await _loadLocalAttendanceForToday(merge: true);
    }
  }

  Future<void> _checkApprovedPermissionToday() async {
    if (_employeeId == null) return;
    try {
      final has = await _permissionService.isPermissionApprovedForDate(
        _employeeId!,
        DateTime.now(),
      );
      setState(() => _hasApprovedPermissionToday = has);
    } catch (e) {
      debugPrint('Error checking approved permission: $e');
    }
  }

  Future<void> _requestPermissionsAndCheckWifi() async {
    final hasPermission = await _permissionService.requestLocationPermission();
    if (!hasPermission) {
      _showMessage("Izin lokasi diperlukan untuk mendeteksi Wi-Fi", false);
      setState(() {
        _wifiSsid = 'Izin lokasi ditolak';
        _wifiBssid = '-';
        _matchedOffices = [];
      });
      return;
    }
    await _checkWifiStatus();
  }

  // Load today's shift assignment for the current employee and evaluate allowed windows
  Future<void> _loadTodayShift(Map<String, dynamic> emp) async {
    if (_employeeId == null) return;
    try {
      final schedule = await _scheduleService.fetchScheduleByEmployeeId(
        _employeeId!,
      );
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final code = schedule?.assignments[todayKey] ?? '';

      if (code.isEmpty) {
        setState(() {
          _hasShiftAssignmentToday = false;
          _todayShift = null;
          _todayShiftCode = null;
          _isWithinShiftCheckIn = false;
          _isWithinShiftCheckOut = false;
        });
        return;
      }

      // Try to fetch shifts from admin, fallback to empty admin if not available
      final adminId = _adminId ?? '';
      final rawShifts = await _shiftService.fetchAllShifts(adminId);
      ShiftModel? found;
      for (final rs in rawShifts) {
        try {
          final sm = ShiftModel.fromMap(Map<String, dynamic>.from(rs));
          if (sm.code == code) {
            found = sm;
            break;
          }
        } catch (_) {}
      }

      // Fallback: try fetching without admin filter
      if (found == null) {
        final fallback = await _shiftService.fetchAllShifts('');
        for (final rs in fallback) {
          try {
            final sm = ShiftModel.fromMap(Map<String, dynamic>.from(rs));
            if (sm.code == code) {
              found = sm;
              break;
            }
          } catch (_) {}
        }
      }

      setState(() {
        _hasShiftAssignmentToday = true;
        _todayShift = found;
        _todayShiftCode = code;
      });

      // Clear local cache if it belongs to a different shift (prevents stale lockout)
      await _clearLocalAttendanceForTodayIfShiftMismatch();

      _evaluateShiftWindows();
    } catch (e) {
      debugPrint('Error loading today\'s shift: $e');
    }
  }

  Future<void> _loadTodayAttendance() async {
    if (_employeeId == null) return;
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final recs = await _attendanceService.fetchAttendanceByDateRange(
        _employeeId!,
        start,
        end,
      );

      AttendanceModel? today;
      for (final r in recs) {
        if (r.date.year == now.year &&
            r.date.month == now.month &&
            r.date.day == now.day) {
          today = r;
          break;
        }
      }

      setState(() {
        if (today != null) {
          _hasCheckedIn = (today.checkin != null);
          _hasCheckedOut = (today.checkout != null);
          if (today.checkin != null) {
            _checkInTime = DateFormat('HH:mm').format(today.checkin!);
          }
          if (today.checkout != null) {
            _checkOutTime = DateFormat('HH:mm').format(today.checkout!);
          }
        } else {
          _hasCheckedIn = false;
          _hasCheckedOut = false;
          _checkInTime = '--:--';
          _checkOutTime = '--:--';
        }
      });

      // Merge local cache so UX reflects most recent local interactions
      await _loadLocalAttendanceForToday(merge: true);
    } catch (e) {
      debugPrint('Error loading today attendance: $e');
      await _loadLocalAttendanceForToday(merge: true);
    }
  }

  void _evaluateShiftWindows() {
    if (!_hasShiftAssignmentToday || _todayShift == null) {
      setState(() {
        _isWithinShiftCheckIn = false;
        _isWithinShiftCheckOut = false;
      });
      return;
    }

    final now = DateTime.now();
    final shift = _todayShift!;

    DateTime shiftStart = DateTime(
      now.year,
      now.month,
      now.day,
      shift.startTime.hour,
      shift.startTime.minute,
      shift.startTime.second,
    );
    DateTime shiftEnd = DateTime(
      now.year,
      now.month,
      now.day,
      shift.endTime.hour,
      shift.endTime.minute,
      shift.endTime.second,
    );
    if (!shiftEnd.isAfter(shiftStart)) {
      // overnight shift
      shiftEnd = shiftEnd.add(const Duration(days: 1));
    }

    final checkInStart = shiftStart.subtract(
      Duration(minutes: shift.toleranceMinutes),
    );
    final checkInEnd = shiftEnd; // allow check-in until shift end

    final checkOutStart = shiftEnd.subtract(
      Duration(minutes: shift.toleranceMinutes),
    );
    final checkOutEnd = shiftEnd.add(const Duration(hours: 24));

    setState(() {
      _isWithinShiftCheckIn =
          now.isAtSameMomentAs(checkInStart) ||
          (now.isAfter(checkInStart) &&
              now.isBefore(checkInEnd.add(const Duration(seconds: 1))));
      _isWithinShiftCheckOut =
          now.isAtSameMomentAs(checkOutStart) ||
          (now.isAfter(checkOutStart) &&
              now.isBefore(checkOutEnd.add(const Duration(seconds: 1))));
    });
  }

  Future<void> _checkWifiStatus() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final hasPermission = await _permissionService.requestLocationPermission();
    if (!hasPermission) {
      _showMessage("Izin lokasi diperlukan untuk mendeteksi Wi-Fi", false);
      setState(() {
        _wifiSsid = 'Izin lokasi ditolak';
        _wifiBssid = '-';
        _matchedOffices = [];
      });
      return;
    }

    final wifi = await _wifiService.getCurrentWifi();
    final ssid = wifi['ssid'] ?? 'Tidak terhubung';
    final bssid = wifi['bssid'] ?? '-';

    final offices = await _locationService.fetchAllLocations();
    final matched = offices
        .where((office) => office.matchesWifi(ssid, bssid))
        .toList();

    setState(() {
      _wifiSsid = ssid;
      _wifiBssid = bssid;
      _matchedOffices = matched;
    });
  }

  void _refreshWifi() async {
    setState(() => _isLoading = true);
    await _requestPermissionsAndCheckWifi();
    setState(() => _isLoading = false);
  }

  void _simulateCheckIn() async {
    // Refresh latest server attendance to avoid duplicate actions
    await _loadTodayAttendance();
    if (_hasCheckedIn) {
      _showMessage('Anda sudah melakukan check-in hari ini.', false);
      return;
    }

    // Prevent check-in when employee has an approved leave today
    if (_hasApprovedPermissionToday) {
      _showMessage(
        'Anda sedang izin hari ini. Check-in tidak tersedia.',
        false,
      );
      return;
    }

    // Schedule/shift checks
    if (!_hasShiftAssignmentToday) {
      _showMessage('Tidak ada jadwal hari ini', false);
      return;
    }
    if (!_isWithinShiftCheckIn) {
      _showMessage('Diluar jam shift', false);
      return;
    }

    if (_matchedOffices.isEmpty) {
      _showMessage("Anda harus terhubung ke Wi-Fi kantor", false);
      return;
    }

    setState(() => _isLoading = true);
    final employeeId = _employeeId ?? 'EMPLOYEE_ID_HERE';
    try {
      await _attendanceService.checkIn(employeeId: employeeId);
      final now = DateTime.now();
      final checkinIso = DateFormat('HH:mm:ss').format(now);
      setState(() {
        _hasCheckedIn = true;
        _checkInTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });

      // Persist locally and notify schedule
      await _saveLocalAttendanceForToday();
      try {
        final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
        debugPrint(
          'AttendanceScreen: notify check-in for $employeeId date:$key checkin:$checkinIso',
        );
        AttendanceService.notifyAttendanceUpdated(
          employeeId,
          key,
          checkin: checkinIso,
        );
      } catch (_) {}

      _showMessage("Check-in berhasil!", true);
    } catch (e) {
      _showMessage('Check-in gagal: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _simulateCheckOut() async {
    // Refresh latest server attendance to avoid duplicate actions and ensure state
    await _loadTodayAttendance();
    if (!_hasCheckedIn) {
      _showMessage("Harus check-in dulu", false);
      return;
    }

    if (_hasCheckedOut) {
      _showMessage('Anda sudah melakukan check-out hari ini.', false);
      return;
    }

    // Schedule/shift checks
    if (!_hasShiftAssignmentToday) {
      _showMessage('Tidak ada jadwal hari ini', false);
      return;
    }

    if (!_isWithinShiftCheckOut) {
      _showMessage('Diluar jam shift', false);
      return;
    }

    if (_matchedOffices.isEmpty) {
      _showMessage("Harus terhubung ke Wi-Fi kantor", false);
      return;
    }

    setState(() => _isLoading = true);
    final employeeId = _employeeId ?? 'EMPLOYEE_ID_HERE';
    try {
      await _attendanceService.checkOut(employeeId: employeeId);
      final now = DateTime.now();
      final checkoutIso = DateFormat('HH:mm:ss').format(now);
      setState(() {
        _hasCheckedOut = true;
        _checkOutTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });

      // Persist locally and notify schedule
      await _saveLocalAttendanceForToday();
      try {
        final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
        debugPrint(
          'AttendanceScreen: notify check-out for $employeeId date:$key checkout:$checkoutIso',
        );
        AttendanceService.notifyAttendanceUpdated(
          employeeId,
          key,
          checkout: checkoutIso,
        );
      } catch (_) {}

      _showMessage("Check-out berhasil!", true);
    } catch (e) {
      _showMessage('Check-out gagal: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _localAttendanceKey([String? shiftCode]) {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final shiftSuffix = (shiftCode ?? _todayShift?.code ?? '').trim();
    return 'attendance_${_employeeId}_$date${shiftSuffix.isNotEmpty ? '_$shiftSuffix' : ''}';
  }

  Future<void> _saveLocalAttendanceForToday() async {
    final employeeId = _employeeId ?? 'EMPLOYEE_ID_HERE'; // Pastikan tidak null
    if (employeeId == 'EMPLOYEE_ID_HERE') {
      debugPrint('AttendanceScreen: WARNING - saving with fallback employeeId');
    }
    try {
      final key = _localAttendanceKey();
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'checkin': _hasCheckedIn ? _checkInTime : null,
        'checkout': _hasCheckedOut ? _checkOutTime : null,
        'shiftCode': _todayShift?.code ?? '',
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(key, payload);
      setState(() => _lastSavedAttendanceKey = key);
      debugPrint(
        'AttendanceScreen: saved local attendance key=$key payload=$payload',
      );
    } catch (e) {
      debugPrint('Error saving local attendance: $e');
    }
  }

  Future<void> _clearLocalAttendanceForTodayIfShiftMismatch() async {
    if (_employeeId == null) return;
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('attendance_${_employeeId}_$date'),
      );
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final Map<String, dynamic> data = jsonDecode(raw);
        final cachedShift = (data['shiftCode'] as String?) ?? '';
        final currentShift = _todayShift?.code ?? '';
        if (cachedShift.isNotEmpty && cachedShift != currentShift) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      debugPrint('Error clearing stale local attendance: $e');
    }
  }

  Future<void> _loadLocalAttendanceForToday({bool merge = false}) async {
    if (_employeeId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localAttendanceKey();
      final raw = prefs.getString(key);
      debugPrint(
        'AttendanceScreen: loading local attendance for key=$key raw=$raw',
      );

      if (raw == null) {
        // Backward-compatibility: try any date key and prefer matching shift
        final datePrefix =
            'attendance_${_employeeId}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
        final keys = prefs
            .getKeys()
            .where((k) => k.startsWith(datePrefix))
            .toList();
        if (keys.isEmpty) return;
        final fallbackRaw = prefs.getString(keys.first);
        if (fallbackRaw == null) return;
        final data = jsonDecode(fallbackRaw) as Map<String, dynamic>;

        final cachedShift = (data['shiftCode'] as String?) ?? '';
        final currentShift = _todayShift?.code ?? '';
        if (cachedShift.isNotEmpty && cachedShift != currentShift) {
          await prefs.remove(keys.first);
          return;
        }

        _applyLocalAttendanceData(data, merge: merge);
        return;
      }

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedShift = (data['shiftCode'] as String?) ?? '';
      final currentShift = _todayShift?.code ?? '';
      if (cachedShift.isNotEmpty && cachedShift != currentShift) {
        await prefs.remove(key);
        return;
      }

      _applyLocalAttendanceData(data, merge: merge);
    } catch (e) {
      debugPrint('Error loading local attendance: $e');
    }
  }

  void _applyLocalAttendanceData(
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    try {
      setState(() {
        final localCheckin = data['checkin'] as String?;
        final localCheckout = data['checkout'] as String?;

        if (merge) {
          if (!_hasCheckedIn && localCheckin != null) {
            _hasCheckedIn = true;
            _checkInTime = localCheckin;
          }
          if (!_hasCheckedOut && localCheckout != null) {
            _hasCheckedOut = true;
            _checkOutTime = localCheckout;
          }
        } else {
          _hasCheckedIn = localCheckin != null;
          _hasCheckedOut = localCheckout != null;
          _checkInTime = localCheckin ?? '--:--';
          _checkOutTime = localCheckout ?? '--:--';
        }
      });
    } catch (e) {
      debugPrint('Error applying local attendance data: $e');
    }
  }

  @override
  void didPopNext() {
    // Screen became visible again (returned to) — reload local and server attendance
    _loadLocalAttendanceForToday(merge: true);
    _loadTodayAttendance();
  }

  @override
  void didPush() {
    // Screen was pushed — ensure local attendance is loaded
    _loadLocalAttendanceForToday(merge: true);
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  void _openLeaveForm() {
    String selectedType = 'Cuti';
    TextEditingController reasonController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Ajukan Izin / Cuti",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Isi formulir pengajuan izin atau cuti Anda",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.category),
                        labelText: "Jenis",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Cuti", child: Text("Cuti")),
                        DropdownMenuItem(value: "Izin", child: Text("Izin")),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedType = value!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.description),
                        labelText: "Alasan",
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            "Batal",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (reasonController.text.trim().isEmpty) {
                              _showMessage("Alasan harus diisi!", false);
                              return;
                            }

                            Navigator.pop(context);
                            setState(() => _isLoading = true);

                            try {
                              final emp = await _authService
                                  .fetchEmployeeByEmail(
                                    _authService.currentUser?.email ?? '',
                                  );
                              final employeeName =
                                  emp?['name'] ??
                                  emp?['nama'] ??
                                  emp?['fullName'] ??
                                  _authService.currentUser?.displayName ??
                                  '';
                              final employeeDivision =
                                  emp?['division'] ?? emp?['divisi'];
                              final employeeAvatarPath =
                                  emp?['avatarPath'] ?? emp?['avatar_path'];

                              final success = await _permissionService
                                  .submitPermissionRequest(
                                    employeeId: _employeeId ?? '',
                                    employeeName: employeeName,
                                    employeeEmail:
                                        _authService.currentUser?.email ?? '',
                                    employeeDivision: employeeDivision,
                                    employeeAvatarPath: employeeAvatarPath,
                                    type: selectedType,
                                    reason: reasonController.text.trim(),
                                    leaveDate: selectedDate,
                                  );

                              if (success) {
                                _showMessage(
                                  "Pengajuan izin berhasil dikirim!",
                                  true,
                                );
                              } else {
                                _showMessage(
                                  "Gagal mengirim pengajuan izin",
                                  false,
                                );
                              }
                            } catch (e) {
                              _showMessage("Error: $e", false);
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Kirim",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Gradient
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_month,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getCurrentDay(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _getCurrentDate(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Visibility(
                    visible: _lastSavedAttendanceKey != null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow.shade700),
                      ),
                      child: Text(
                        'Local attendance key: ' +
                            (_lastSavedAttendanceKey ?? ''),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  _attendanceStatusCard(),
                  const SizedBox(height: 20),
                  _wifiCard(),
                  const SizedBox(height: 40),
                  _buildButtonSection(),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonSection() {
    // Build single action widget (check-in or check-out)
    final checkInEnabled =
        !_isLoading &&
        !_hasCheckedIn &&
        _matchedOffices.isNotEmpty &&
        !_hasApprovedPermissionToday &&
        _hasShiftAssignmentToday &&
        _isWithinShiftCheckIn;

    String? checkInReason;
    if (_hasApprovedPermissionToday) {
      checkInReason = "Anda sedang izin hari ini. Check-in tidak tersedia.";
    } else if (!_hasShiftAssignmentToday) {
      checkInReason = "Tidak ada jadwal hari ini";
    } else if (!_isWithinShiftCheckIn) {
      checkInReason = "Diluar jam shift";
    } else if (_matchedOffices.isEmpty) {
      checkInReason = "Bukan Wi-Fi kantor";
    }

    final checkOutEnabled =
        !_isLoading &&
        !_hasCheckedOut &&
        _matchedOffices.isNotEmpty &&
        _hasShiftAssignmentToday &&
        _isWithinShiftCheckOut &&
        _hasCheckedIn;

    String? checkOutReason;
    if (!_hasCheckedIn) {
      checkOutReason = "Harus check-in dulu";
    } else if (!_hasShiftAssignmentToday) {
      checkOutReason = "Tidak ada jadwal hari ini";
    } else if (!_isWithinShiftCheckOut) {
      checkOutReason = "Diluar jam shift";
    } else if (_matchedOffices.isEmpty) {
      checkOutReason = "Bukan Wi-Fi kantor";
    }

    // Choose a single action widget: check-in if not yet, else check-out, else completed
    Widget actionWidget;
    if (!_hasCheckedIn) {
      actionWidget = _attendanceActionButton(
        text: "CHECK-IN SEKARANG",
        icon: Icons.fingerprint,
        color: Colors.green,
        enabled: checkInEnabled,
        reason: checkInReason,
        onPressed: _simulateCheckIn,
      );
    } else if (!_hasCheckedOut) {
      actionWidget = _attendanceActionButton(
        text: "CHECK-OUT SEKARANG",
        icon: Icons.logout,
        color: AppColors.primary,
        enabled: checkOutEnabled,
        reason: checkOutReason,
        onPressed: _simulateCheckOut,
      );
    } else {
      actionWidget = _attendanceActionButton(
        text: "Anda telah absen",
        icon: Icons.check_circle,
        color: AppColors.primary,
        enabled: false,
        completed: true,
        completedText: "Check-in: $_checkInTime • Check-out: $_checkOutTime",
        onPressed: () {},
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [actionWidget],
    );
  }

  Widget _attendanceActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required bool enabled,
    String? reason,
    required VoidCallback onPressed,
    bool completed = false,
    String? completedText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: (!completed && enabled)
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.8)],
                  )
                : null,
            color: (!completed && enabled)
                ? null
                : (completed ? AppColors.primary : Colors.grey.shade300),
            boxShadow: (!completed && enabled)
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton.icon(
            onPressed: (!completed && enabled) ? onPressed : null,
            icon: Icon(
              completed ? Icons.check : icon,
              color: Colors.white,
              size: 24,
            ),
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (completedText != null)
                  Text(
                    completedText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        if (!enabled && reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              reason,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _wifiCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _matchedOffices.isNotEmpty
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _matchedOffices.isNotEmpty ? Icons.wifi : Icons.wifi_off,
                    color: _matchedOffices.isNotEmpty
                        ? Colors.green
                        : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _matchedOffices.isNotEmpty
                            ? "Terhubung ke Wi-Fi kantor"
                            : "Bukan Wi-Fi kantor",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "SSID: $_wifiSsid",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                  onPressed: _isLoading ? null : _refreshWifi,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_matchedOffices.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _matchedOffices
                    .map(
                      (o) => Chip(
                        label: Text(
                          o.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Status Absensi Hari Ini",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _timeBox("Check-in", _checkInTime, Colors.green),
                Container(width: 60, height: 1, color: Colors.grey.shade300),
                _timeBox("Check-out", _checkOutTime, AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeBox(String label, String time, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.access_time, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    const bulan = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];
    return "${now.day} ${bulan[now.month - 1]} ${now.year}";
  }

  String _getCurrentDay() {
    const hari = [
      "Minggu",
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
    ];
    return hari[DateTime.now().weekday % 7];
  }
}
