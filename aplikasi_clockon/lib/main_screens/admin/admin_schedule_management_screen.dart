import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import '../../../utils/theme/app_theme.dart';
import '../../data/services/employee_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/schedule_service.dart';
import '../../data/services/shift_service.dart';
import '../../data/services/division_service.dart';
import '../../data/models/schedule_model.dart';
import 'package:aplikasi_clockon/core/services/bulk_shift_service.dart';

class AdminScheduleManagementScreen extends StatefulWidget {
  const AdminScheduleManagementScreen({super.key});

  @override
  State<AdminScheduleManagementScreen> createState() =>
      _AdminScheduleManagementScreenState();
}

class _AdminScheduleManagementScreenState
    extends State<AdminScheduleManagementScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final AuthService _authService = AuthService();
  final ScheduleService _scheduleService = ScheduleService();
  final ShiftService _shiftService = ShiftService();

  bool _isLoading = false;

  // Debug and polling controls
  final bool _debugMode = false;
  final bool _enablePolling =
      false; // disabled by default to avoid race conditions

  // Controllers to improve scrolling behavior
  final ScrollController _verticalController = ScrollController();
  // Shared controller for horizontal sync between header, body rows and summary
  final ScrollController _horizontalController = ScrollController();

  // Polling timer to refresh schedules from GoCloud periodically
  Timer? _pollTimer;

  final String _selectedDivision = 'Semua';
  String _selectedGroup = 'Semua';
  String _searchEmployee = '';
  DateTime _startDate = DateTime.now();
  final DivisionService _divisionService = DivisionService();
  List<String> _divisions = ['Semua'];
  List<String> _groups = ['Semua'];

  List<Map<String, String>> _shifts = [
    {'code': 'PAGI', 'label': 'Shift Pagi'},
    {'code': 'SIANG', 'label': 'Shift Siang'},
    {'code': 'MALAM', 'label': 'Shift Malam'},
    {'code': 'OFF', 'label': 'Off'},
  ];

  // Preset color options for shifts (label -> hex)
  final List<Map<String, String>> _colorOptions = [
    {'name': 'Biru', 'hex': '#2196F3'},
    {'name': 'Hijau', 'hex': '#4CAF50'},
    {'name': 'Kuning', 'hex': '#FFEB3B'},
    {'name': 'Merah', 'hex': '#F44336'},
  ];

  List<Map<String, dynamic>> _employees = [];
  final Map<String, Map<String, String>> _shiftCalendar = {};
  // loaded schedules mapped by employeeId
  final Map<String, ScheduleModel> _schedulesByEmployee = {};

  // Bulk shift service (wired after shifts are loaded)
  BulkShiftService? _bulkShiftService;

  bool _hasUnsavedChanges = false;

  // Shift panel collapsible state
  final bool _isShiftPanelExpanded = true;
  final String _shiftSearchQuery = '';

  String _getShiftDuration(String code) {
    if (code.isEmpty) return '';
    final sh = _shifts.firstWhere(
      (s) => (s['code'] ?? '') == code,
      orElse: () => <String, String>{},
    );
    final start = sh.containsKey('start') ? (sh['start'] ?? '') : '';
    final end = sh.containsKey('end') ? (sh['end'] ?? '') : '';

    // Treat OFF or missing times as Off
    final label = (sh['label'] ?? '').toString().toLowerCase();
    if (code.toUpperCase() == 'OFF' ||
        label.contains('off') ||
        (start.isEmpty && end.isEmpty)) {
      return 'Off';
    }

    // Normalize HH:MM or ISO time strings for display
    String normalize(String t) {
      if (t.isEmpty) return '';
      // if format HH:mm or HH:mm:ss, keep as-is
      final parts = t.split(':');
      if (parts.length >= 2 && parts[0].length <= 2) {
        return parts.sublist(0, parts.length >= 3 ? 3 : 2).join(':');
      }
      try {
        final dt = DateTime.parse(t);
        return DateFormat('HH:mm').format(dt);
      } catch (_) {
        return t;
      }
    }

    final ns = normalize(start);
    final ne = normalize(end);
    if (ns.isEmpty && ne.isEmpty) return '';
    return '$ns - $ne';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // start periodic schedule refresh from GoCloud only if enabled
    if (_enablePolling) {
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!_hasUnsavedChanges) await _reloadSchedules();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;

      final eList = await _employeeService.fetchAllEmployees();
      // load divisions
      try {
        final dlist = await _divisionService.fetchAllDivisions();
        _divisions = ['Semua'];
        _divisions.addAll(dlist.map((d) => d.name.toString()));
      } catch (_) {}

      // Load shifts from backend for current admin
      if (user != null) {
        try {
          final shiftList = await _shiftService.fetchAllShifts(user.uid);
          if (shiftList.isNotEmpty) {
            _shifts = shiftList.map((s) {
              return {
                'id': s['_id']?.toString() ?? s['id']?.toString() ?? '',
                'code': s['code']?.toString() ?? '',
                'label': s['label']?.toString() ?? '',
                'start':
                    s['startTime']?.toString() ?? s['start']?.toString() ?? '',
                'end': s['endTime']?.toString() ?? s['end']?.toString() ?? '',
                'color': s['color']?.toString() ?? '',
              };
            }).toList();
            debugPrint('Loaded ${_shifts.length} shifts from backend');
            // initialize bulk shift service after shifts loaded
            _bulkShiftService = BulkShiftService(
              shifts: _shifts,
              minRestHours: 8.0,
            );
          }
        } catch (e) {
          debugPrint('Error loading shifts: $e');
          // Fallback: initialize with empty shifts to prevent null service
          _bulkShiftService = BulkShiftService(shifts: [], minRestHours: 8.0);
        }

        // Load existing schedules for admin's employees
        try {
          final schedules = await _scheduleService.fetchAllSchedules();
          for (final s in schedules) {
            if (s.employeeId.isNotEmpty) {
              _schedulesByEmployee[s.employeeId] = s;
              // populate visible calendar assignments so UI reflects saved schedules
              try {
                final raw = _normalizeAssignments(s.assignments);
                _shiftCalendar[s.employeeId] = _normalizeAssignmentDates(raw);
              } catch (_) {
                // fallback
                _shiftCalendar[s.employeeId] = _normalizeAssignments(
                  s.assignments,
                );
              }
            }
          }
          _log('Loaded ${_schedulesByEmployee.length} schedules');
          // debug sample to help trace missing mapping issues
          try {
            _log('Schedule employeeIds: ${_schedulesByEmployee.keys.toList()}');
            if (_schedulesByEmployee.isNotEmpty) {
              final sample = _schedulesByEmployee.entries.first;
              _log(
                'Sample schedule for ${sample.key}: ${sample.value.assignments}',
              );
            }
            _log('_shiftCalendar size: ${_shiftCalendar.length}');
            if (_shiftCalendar.isNotEmpty) {
              final se = _shiftCalendar.entries.first;
              _log('Sample _shiftCalendar for ${se.key}: ${se.value}');
            }
          } catch (_) {}
        } catch (e) {
          debugPrint('Error loading schedules: $e');
        }

        final adminEmail = user.email;
        _employees = eList
            .where(
              (e) =>
                  e.createdByAdminEmail == adminEmail ||
                  e.createdByAdminId == adminEmail,
            )
            .map(
              (e) => {
                'id': e.id,
                'name': e.name,
                'division': e.division.isNotEmpty ? e.division : 'Umum',
                // map group to division by default; later can use a dedicated group field
                'group': e.division.isNotEmpty ? e.division : 'Umum',
              },
            )
            .toList();
        _log('Loaded ${_employees.length} employees for admin $adminEmail');
        _log('Employee IDs: ${_employees.map((e) => e['id']).toList()}');

        // populate groups list from employees (group defaults to division)
        _groups = ['Semua'];
        final uniq = _employees
            .map((e) => e['group'] ?? e['division'] ?? 'Umum')
            .toSet();
        _groups.addAll(
          uniq.where((g) => g != null && g.isNotEmpty).cast<String>().toList(),
        );

        // Check if schedules are properly mapped
        _log('Schedules loaded: ${_schedulesByEmployee.length}');
        _log('Schedule employee IDs: ${_schedulesByEmployee.keys.toList()}');

        // Check for employees without schedules
        final employeesWithoutSchedules = _employees.where((emp) {
          final empId = emp['id'];
          return !_schedulesByEmployee.containsKey(empId);
        }).toList();
        _log(
          'Employees without schedules: ${employeesWithoutSchedules.length}',
        );
        if (employeesWithoutSchedules.isNotEmpty) {
          _log(
            'Sample employees without schedules: ${employeesWithoutSchedules.take(3).map((e) => {'id': e['id'], 'name': e['name']}).toList()}',
          );
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _reloadSchedules() async {
    try {
      final schedules = await _scheduleService.fetchAllSchedules();
      _schedulesByEmployee.clear();
      _shiftCalendar.clear();
      for (final s in schedules) {
        if (s.employeeId.isNotEmpty) {
          _schedulesByEmployee[s.employeeId] = s;
          try {
            final raw = _normalizeAssignments(s.assignments);
            _shiftCalendar[s.employeeId] = _normalizeAssignmentDates(raw);
          } catch (_) {
            _shiftCalendar[s.employeeId] = _normalizeAssignments(s.assignments);
          }
        }
      }
      _log('Reloaded ${_schedulesByEmployee.length} schedules');
      try {
        _log(
          'After reload schedule employeeIds: ${_schedulesByEmployee.keys.toList()}',
        );
        _log('After reload _shiftCalendar size: ${_shiftCalendar.length}');
      } catch (_) {}
      setState(() {});
    } catch (e) {
      debugPrint('Error reloading schedules: $e');
    }
  }

  List<DateTime> get _visibleDates =>
      List.generate(14, (i) => _startDate.add(Duration(days: i)));

  List<Map<String, dynamic>> get _filteredEmployees {
    var filtered = _employees;

    _log('Total employees before filter: ${_employees.length}');
    _log('Selected division: $_selectedDivision');
    _log('Search employee: $_searchEmployee');

    // Filter by selected group (falls back to division)
    if (_selectedGroup != 'Semua') {
      filtered = filtered
          .where(
            (e) => (e['group'] ?? e['division'] ?? 'Umum') == _selectedGroup,
          )
          .toList();
      _log('After group filter: ${filtered.length}');
    }

    // Filter by search employee
    if (_searchEmployee.isNotEmpty) {
      final search = _searchEmployee.toLowerCase();
      filtered = filtered
          .where((e) => (e['name'] ?? '').toLowerCase().contains(search))
          .toList();
      _log('After search filter: ${filtered.length}');
    }

    _log('Final filtered employees: ${filtered.length}');

    // Check if filtered employees have schedules
    final filteredWithoutSchedules = filtered.where((emp) {
      final empId = emp['id'];
      return !_schedulesByEmployee.containsKey(empId);
    }).toList();
    debugPrint(
      'Filtered employees without schedules: ${filteredWithoutSchedules.length}',
    );
    if (filteredWithoutSchedules.isNotEmpty) {
      debugPrint(
        'Sample filtered employees without schedules: ${filteredWithoutSchedules.take(3).map((e) => {'id': e['id'], 'name': e['name']}).toList()}',
      );
    }

    return filtered;
  }

  Color _shiftColor(String code) {
    // Try to find color in shift definition first
    final sh = _shifts.firstWhere(
      (s) => (s['code'] ?? '') == code,
      orElse: () => <String, String>{},
    );
    final colorValue = sh['color'] ?? '';
    Color parseHex(String hex) {
      try {
        var c = hex.toString().replaceAll('#', '');
        if (c.length == 6) c = 'FF$c';
        return Color(int.parse(c, radix: 16));
      } catch (_) {
        return Colors.transparent;
      }
    }

    if (colorValue.isNotEmpty) {
      final parsed = parseHex(colorValue.toString());
      if (parsed != Colors.transparent) return parsed;
    }

    // Fallback palette (Opsi A)
    switch (code.toUpperCase()) {
      case 'PAGI':
        return const Color(0xFF4CAF50); // hijau
      case 'SIANG':
        return const Color(0xFF2196F3); // biru
      case 'MALAM':
        return const Color.fromARGB(255, 255, 123, 0); // kuning
      case 'OFF':
        return const Color(0xFFF44336); // merah
      default:
        return const Color(0xFF9E9E9E); // grey
    }
  }

  // Controlled logger respecting `_debugMode`
  void _log(String msg) {
    if (_debugMode) debugPrint(msg);
  }

  // Normalizes various forms of assignments into Map<String, String>
  Map<String, String> _normalizeAssignments(dynamic raw) {
    try {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      if (raw is String) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is Map) {
            return parsed.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {}
      }
      if (raw is Function) {
        try {
          final r = raw();
          if (r is Map) {
            return r.map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        } catch (_) {}
      }
    } catch (_) {}
    return {};
  }

  // Ensure assignment keys are normalized to 'yyyy-MM-dd' when possible
  Map<String, String> _normalizeAssignmentDates(Map<String, String> raw) {
    final out = <String, String>{};
    for (final entry in raw.entries) {
      var k = entry.key;
      final v = entry.value;
      // try parsing common date/time formats and reformat to yyyy-MM-dd
      try {
        final dt = DateTime.parse(k);
        k = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {
        // also handle keys that may contain trailing time or timezone separated by space
        try {
          final maybe = k.split(' ').first;
          final dt2 = DateTime.parse(maybe);
          k = DateFormat('yyyy-MM-dd').format(dt2);
        } catch (_) {
          // leave as-is
        }
      }
      out[k] = v;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Konfirmasi Keluar'),
              content: const Text(
                'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin keluar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Keluar Tanpa Simpan'),
                ),
              ],
            ),
          );
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildFilterBar(),
                  Expanded(child: _buildTable()),
                ],
              ),
            ),
            Expanded(flex: 1, child: _buildShiftPanel()),
          ],
        ),
      ),
    );
  }

  // ================= FILTER =================
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Group selector (maps to division by default)
          DropdownButton<String>(
            value: _selectedGroup,
            items: _groups
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGroup = v!),
          ),

          // Bulk assign button for selected group
          ElevatedButton(
            onPressed: () async {
              if (_selectedGroup == 'Semua') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pilih group terlebih dahulu')),
                );
                return;
              }
              await _openBulkAssignDialog();
            },
            child: const Text('Assign to Group'),
          ),

          // manual refresh button (fetch latest from backend)
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _reloadSchedules();
              setState(() => _isLoading = false);
            },
            icon: const Icon(Icons.refresh),
          ),

          ElevatedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
            child: const Text('Pilih Tanggal'),
          ),

          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari karyawan',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchEmployee = v),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveShiftCalendarToSchedule() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('=== _saveShiftCalendarToSchedule Debug ===');
      debugPrint('Total employees in _shiftCalendar: ${_shiftCalendar.length}');
      debugPrint('ShiftCalendar keys: ${_shiftCalendar.keys.toList()}');

      // For each employee in the calendar, build assignments and create/update schedule
      final List<String> failedEmployees = [];
      final entries = _shiftCalendar.entries
          .toList(); // Create a copy to avoid concurrent modification
      for (final entry in entries) {
        final empId = entry.key;
        final rawAssignments = _normalizeAssignments(entry.value);

        // normalize date keys to yyyy-MM-dd and trim values
        final assignments = <String, String>{};
        for (final a in rawAssignments.entries) {
          var k = a.key;
          final v = a.value.toString().trim();
          try {
            final dt = DateTime.parse(k);
            k = DateFormat('yyyy-MM-dd').format(dt);
          } catch (_) {
            try {
              final maybe = k.split(' ').first;
              final dt2 = DateTime.parse(maybe);
              k = DateFormat('yyyy-MM-dd').format(dt2);
            } catch (_) {
              // leave key as-is
            }
          }
          if (v.isNotEmpty) assignments[k] = v;
        }

        debugPrint('Processing employee: $empId');
        debugPrint('  Assignments count: ${assignments.length}');
        debugPrint('  Assignments: $assignments');

        try {
          var existing = _schedulesByEmployee[empId];
          debugPrint('  Existing schedule found: ${existing != null}');

          // Determine final assignments by merging existing with calendar changes
          Map<String, String> finalAssignments = Map.from(assignments);
          if (existing != null) {
            final existingAssignments = _normalizeAssignments(
              existing.assignments,
            );
            finalAssignments = Map<String, String>.from(existingAssignments)
              ..addAll(assignments);
            debugPrint(
              '  Merged assignments: ${finalAssignments.length} total',
            );
          }

          // If we have an existing schedule with id, update it
          if (existing != null && existing.id.isNotEmpty) {
            debugPrint('  Updating existing schedule ID: ${existing.id}');
            debugPrint('  assignments (akan dikirim ke backend):');
            finalAssignments.forEach((k, v) {
              debugPrint('    $k: $v');
            });
            debugPrint('  assignments (JSON): ${finalAssignments.toString()}');
            final updateOk = await _scheduleService.updateSchedule(
              existing.id,
              {'assignments': finalAssignments},
            );
            debugPrint('  Update result: $updateOk');
            if (!updateOk) {
              // try to fetch latest schedule and retry
              debugPrint(
                '  Update failed, fetching latest schedule and retrying',
              );
              final fetched = await _scheduleService.fetchScheduleByEmployeeId(
                empId,
              );
              if (fetched != null) {
                existing = fetched;
                final existingAssignments = _normalizeAssignments(
                  existing.assignments,
                );
                finalAssignments = Map<String, String>.from(existingAssignments)
                  ..addAll(assignments);
                final retryOk = await _scheduleService.updateSchedule(
                  existing.id,
                  {'assignments': finalAssignments},
                );
                debugPrint(
                  '  Retry update assignments (JSON): ${finalAssignments.toString()}',
                );
                debugPrint('  Retry update result: $retryOk');
                if (!retryOk) {
                  debugPrint('  FAILED: retry updateSchedule returned false');
                  failedEmployees.add(empId);
                  continue;
                }
              } else {
                debugPrint(
                  '  FAILED: could not fetch existing schedule to retry',
                );
                failedEmployees.add(empId);
                continue;
              }
            }

            // update local caches
            _schedulesByEmployee[empId] = existing.copyWith(
              assignments: finalAssignments,
            );
            _shiftCalendar[empId] = finalAssignments;
          } else {
            // No existing schedule in memory; check server
            debugPrint(
              '  Checking for existing schedule before creating new one',
            );
            final existingSchedule = await _scheduleService
                .fetchScheduleByEmployeeId(empId);
            if (existingSchedule != null) {
              debugPrint(
                '  Found existing schedule for employee, updating instead of creating new',
              );
              final existingAssignments = _normalizeAssignments(
                existingSchedule.assignments,
              );
              finalAssignments = Map<String, String>.from(existingAssignments)
                ..addAll(assignments);
              debugPrint(
                '  assignments (update existing, JSON): ${finalAssignments.toString()}',
              );
              final updateOk = await _scheduleService.updateSchedule(
                existingSchedule.id,
                {'assignments': finalAssignments},
              );
              debugPrint('  Update existing schedule result: $updateOk');
              if (!updateOk) {
                debugPrint('  FAILED: updateSchedule returned false');
                failedEmployees.add(empId);
                continue;
              }

              // update local caches
              _schedulesByEmployee[empId] = existingSchedule.copyWith(
                assignments: finalAssignments,
              );
              _shiftCalendar[empId] = finalAssignments;
            } else {
              // Create new schedule only if none exists
              debugPrint('  No existing schedule found, creating new schedule');
              final employee = _employees.firstWhere(
                (e) => e['id'] == empId,
                orElse: () => <String, String>{},
              );
              final name = employee['name'] ?? '';

              bool ok = false;
              try {
                final model = ScheduleModel(
                  id: '',
                  employeeId: empId,
                  employeeName: name,
                  assignments: finalAssignments,
                  status: 'Aktif',
                );
                ok = await _schedule_service_createWrapper(model);
                debugPrint('  Create result: $ok');
              } catch (inner, st2) {
                debugPrint('  INNER EXCEPTION during model/create: $inner');
                debugPrint(st2.toString());
                rethrow;
              }

              if (!ok) {
                debugPrint('  FAILED: createSchedule returned false');
                failedEmployees.add(empId);
                continue;
              }

              // fetch newly created schedule to get its id and update local cache
              final created = await _schedule_service_fetchByEmployeeWrapper(
                empId,
              );
              if (created != null) {
                _schedulesByEmployee[empId] = created.copyWith(
                  assignments: finalAssignments,
                );
                _shiftCalendar[empId] = finalAssignments;
              } else {
                // still consider as success but keep local calendar
                _shiftCalendar[empId] = finalAssignments;
              }
            }
          }
        } catch (e) {
          debugPrint('  EXCEPTION: Failed saving schedule for $empId: $e');
          failedEmployees.add(empId);
        }
      }

      if (failedEmployees.isNotEmpty) {
        debugPrint('Failed employees: ${failedEmployees.join(",")}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan jadwal untuk: ${failedEmployees.join(", ")}',
            ),
          ),
        );
        // Do not reload on failure to preserve unsaved changes
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jadwal tersimpan')));
      _hasUnsavedChanges = false;
      // restart polling timer after save
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!_hasUnsavedChanges) {
          await _reloadSchedules();
        }
      });
      // reload schedules only
      await _reloadSchedules();
    } catch (e) {
      debugPrint('saveShiftCalendar error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan jadwal')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Safe wrapper to create schedule and handle exceptions
  Future<bool> _schedule_service_createWrapper(ScheduleModel model) async {
    try {
      return await _scheduleService.createSchedule(model);
    } catch (e) {
      debugPrint('create wrapper error: $e');
      return false;
    }
  }

  // Safe wrapper to fetch schedule by employee id
  Future<ScheduleModel?> _schedule_service_fetchByEmployeeWrapper(
    String empId,
  ) async {
    try {
      return await _scheduleService.fetchScheduleByEmployeeId(empId);
    } catch (e) {
      debugPrint('fetchByEmployee wrapper error: $e');
      return null;
    }
  }

  Future<void> _updateShiftForEmployeeDate(
    String empId,
    String dateKey,
    String newShiftCode,
  ) async {
    debugPrint('\n=== _updateShiftForEmployeeDate START ===');
    debugPrint('Employee ID: $empId');
    debugPrint('Date Key: $dateKey');
    debugPrint('New Shift Code: $newShiftCode');
    debugPrint('Current time: ${DateTime.now()}');

    try {
      // Normalize dateKey
      var normalizedDateKey = dateKey;
      try {
        final dt = DateTime.parse(dateKey);
        normalizedDateKey = DateFormat('yyyy-MM-dd').format(dt);
        debugPrint('Normalized dateKey: $normalizedDateKey');
      } catch (e) {
        debugPrint('Failed to parse dateKey, using as-is: $e');
      }

      var existing = _schedulesByEmployee[empId];
      debugPrint('Existing schedule in memory: ${existing?.id ?? "null"}');
      debugPrint(
        'Cache state - Total employees in cache: ${_schedulesByEmployee.length}',
      );
      debugPrint('Cache keys: ${_schedulesByEmployee.keys.toList()}');
      if (existing != null) {
        debugPrint(
          '  - Current assignments count: ${existing.assignments.length}',
        );
        debugPrint('  - Current assignments: ${existing.assignments}');
      }

      if (existing != null && existing.id.isNotEmpty) {
        debugPrint('Branch: UPDATE EXISTING SCHEDULE');
        // Update existing schedule
        final updatedAssignments = Map<String, String>.from(
          existing.assignments,
        );
        updatedAssignments[normalizedDateKey] = newShiftCode;
        debugPrint('Updated assignments: $updatedAssignments');

        bool success = false;
        int retryCount = 0;
        const maxRetries = 2;

        while (!success && retryCount <= maxRetries) {
          success = await _scheduleService.updateSchedule(existing.id, {
            'assignments': updatedAssignments,
          });
          debugPrint(
            'Update API response (attempt ${retryCount + 1}): $success',
          );

          if (!success && retryCount < maxRetries) {
            debugPrint('Update failed, retrying in 1 second...');
            await Future.delayed(const Duration(seconds: 1));
            retryCount++;
          } else {
            break;
          }
        }

        if (success) {
          debugPrint('SUCCESS: Updating local cache');
          debugPrint(
            'Before cache update - _schedulesByEmployee[$empId] id: ${_schedulesByEmployee[empId]?.id}',
          );
          _schedulesByEmployee[empId] = existing.copyWith(
            assignments: updatedAssignments,
          );
          debugPrint(
            'After cache update - _schedulesByEmployee[$empId] id: ${_schedulesByEmployee[empId]?.id}',
          );
          _shiftCalendar[empId] = updatedAssignments;
          debugPrint(
            'Updated _shiftCalendar[$empId]: ${_shiftCalendar[empId]}',
          );
          debugPrint('Calling setState to refresh UI');
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shift tersimpan'),
              duration: Duration(milliseconds: 1500),
            ),
          );
          debugPrint('=== _updateShiftForEmployeeDate SUCCESS (update) ===\n');
        } else {
          debugPrint('FAILED: Update API returned false');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan shift')),
          );
          debugPrint(
            '=== _updateShiftForEmployeeDate FAILED (update api) ===\n',
          );
        }
      } else {
        // Check if employee has schedule on server
        debugPrint('Branch: FETCH FROM SERVER OR CREATE NEW');
        debugPrint(
          'No existing schedule in memory for $empId, fetching from server',
        );
        final serverSchedule = await _scheduleService.fetchScheduleByEmployeeId(
          empId,
        );
        debugPrint('Server schedule result: ${serverSchedule?.id ?? "null"}');

        if (serverSchedule != null) {
          debugPrint('Found schedule on server, updating it');
          // Found on server, update it
          final updatedAssignments = Map<String, String>.from(
            serverSchedule.assignments,
          );
          debugPrint('Server assignments before merge: $updatedAssignments');
          updatedAssignments[normalizedDateKey] = newShiftCode;
          debugPrint('Assignments after merge: $updatedAssignments');

          bool success = false;
          int retryCount = 0;
          const maxRetries = 2;

          while (!success && retryCount <= maxRetries) {
            success = await _scheduleService.updateSchedule(serverSchedule.id, {
              'assignments': updatedAssignments,
            });
            debugPrint(
              'Update server API response (attempt ${retryCount + 1}): $success',
            );

            if (!success && retryCount < maxRetries) {
              debugPrint('Update server failed, retrying in 1 second...');
              await Future.delayed(const Duration(seconds: 1));
              retryCount++;
            } else {
              break;
            }
          }

          if (success) {
            debugPrint('SUCCESS: Updating local cache with server schedule');
            debugPrint('Server schedule ID: ${serverSchedule.id}');
            _schedulesByEmployee[empId] = serverSchedule.copyWith(
              assignments: updatedAssignments,
            );
            debugPrint(
              'After update - _schedulesByEmployee[$empId] id: ${_schedulesByEmployee[empId]?.id}',
            );
            _shiftCalendar[empId] = updatedAssignments;
            debugPrint(
              'Updated _shiftCalendar[$empId]: ${_shiftCalendar[empId]}',
            );
            debugPrint('Calling setState to refresh UI');
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shift tersimpan'),
                duration: Duration(milliseconds: 1500),
              ),
            );
            debugPrint(
              '=== _updateShiftForEmployeeDate SUCCESS (update server) ===\n',
            );
          } else {
            debugPrint('FAILED: Update server schedule returned false');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan shift')),
            );
            debugPrint(
              '=== _updateShiftForEmployeeDate FAILED (update server) ===\n',
            );
          }
        } else {
          // No existing schedule, create new one
          debugPrint('No schedule found on server, creating new schedule');
          final employee = _employees.firstWhere(
            (e) => e['id'] == empId,
            orElse: () => <String, String>{},
          );
          final name = employee['name'] ?? '';
          debugPrint('Employee name: $name');
          final newSchedule = ScheduleModel(
            id: '',
            employeeId: empId,
            employeeName: name,
            assignments: {normalizedDateKey: newShiftCode},
            status: 'Aktif',
          );
          debugPrint('Creating schedule with: $newSchedule');

          bool success = false;
          int retryCount = 0;
          const maxRetries = 2;

          while (!success && retryCount <= maxRetries) {
            success = await _scheduleService.createSchedule(newSchedule);
            debugPrint(
              'Create API response (attempt ${retryCount + 1}): $success',
            );

            if (!success && retryCount < maxRetries) {
              debugPrint('Create failed, retrying in 1 second...');
              await Future.delayed(const Duration(seconds: 1));
              retryCount++;
            } else {
              break;
            }
          }

          if (success) {
            debugPrint('SUCCESS: Fetching created schedule to get ID');
            // Fetch the created schedule to get its ID
            final created = await _scheduleService.fetchScheduleByEmployeeId(
              empId,
            );
            debugPrint('Fetched created schedule: ${created?.id ?? "null"}');

            if (created != null) {
              debugPrint('Updating local cache with created schedule');
              _schedulesByEmployee[empId] = created;
              _shiftCalendar[empId] = created.assignments;
            } else {
              debugPrint(
                'Could not fetch created schedule, using local calendar only',
              );
              _shiftCalendar[empId] = {normalizedDateKey: newShiftCode};
            }
            debugPrint('Calling setState to refresh UI');
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shift tersimpan'),
                duration: Duration(milliseconds: 1500),
              ),
            );
            debugPrint(
              '=== _updateShiftForEmployeeDate SUCCESS (create) ===\n',
            );
          } else {
            debugPrint('FAILED: Create schedule returned false');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan shift')),
            );
            debugPrint(
              '=== _updateShiftForEmployeeDate FAILED (create api) ===\n',
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('EXCEPTION in _updateShiftForEmployeeDate: $e');
      debugPrint('Stack trace: $st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error updating shift')));
      debugPrint('=== _updateShiftForEmployeeDate EXCEPTION ===\n');
    }
  }

  // ================= TABLE =================
  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double nameColWidth = 220.0;
        final double dateColWidth =
            120.0; // used for header and each date column
        final double summaryHeight =
            100.0; // fixed height for summary area (reduced to avoid overflow)

        // total width should account for date columns and name column
        // add small buffer per column for borders/margins
        final totalWidth =
            nameColWidth + _visibleDates.length * (dateColWidth + 2);
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: totalWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  // header
                  Row(
                    children: [
                      _headerCell('Karyawan', nameColWidth),
                      ..._visibleDates.map(
                        (d) => _headerCell(
                          DateFormat('dd\nEEE', 'id_ID').format(d),
                          dateColWidth,
                        ),
                      ),
                    ],
                  ),

                  // rows (vertical scroll) with better performance
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        if (_hasUnsavedChanges) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Simpan perubahan terlebih dahulu sebelum refresh',
                              ),
                            ),
                          );
                          return;
                        }
                        await _reloadSchedules();
                      },
                      child: ListView.builder(
                        controller: _verticalController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredEmployees.length,
                        // fixed height per row improves render performance
                        itemExtent: 58,
                        itemBuilder: (context, index) {
                          final emp = _filteredEmployees[index];
                          return RepaintBoundary(
                            key: ValueKey(emp['id']),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: nameColWidth,
                                  child: _nameCell(
                                    '${emp['name']} (${emp['division']})',
                                    nameColWidth,
                                  ),
                                ),
                                ..._visibleDates.map((d) {
                                  final key = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(d);
                                  final status =
                                      _shiftCalendar[emp['id']]?[key] ?? '';
                                  return SizedBox(
                                    width: dateColWidth,
                                    child: _shiftDropdownCell(
                                      emp['id'],
                                      key,
                                      status,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // summary (now inside same horizontal scroll)
                  Container(
                    height: summaryHeight,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: _visibleDates.map((d) {
                        final key = DateFormat('yyyy-MM-dd').format(d);
                        return SizedBox(
                          width: dateColWidth,
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: 1,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                        'id_ID',
                                      ).format(d),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._shifts.map((s) {
                                      final code = s['code'] ?? '';
                                      final cnt = _countShiftOnDate(key, code);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: _shiftColor(code),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(s['label'] ?? ''),
                                              ],
                                            ),
                                            Text(
                                              cnt.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // spacer to give room for horizontal scrollbar and avoid bottom overflow
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _shiftDropdownCell(String empId, String dateKey, String status) {
    return Container(
      height: 56,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: _shiftColor(status),
        borderRadius: BorderRadius.circular(6),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Klik untuk ubah shift',
        onSelected: (v) async {
          debugPrint('\n=== DROPDOWN SELECTED ===');
          debugPrint('Employee ID: $empId');
          debugPrint('Date Key: $dateKey');
          debugPrint('Current status: $status');
          debugPrint('Selected shift code: $v');
          debugPrint('Timestamp: \'${DateTime.now().toIso8601String()}\'');
          // Log assignments sebelum update
          final assignmentsBefore = _shiftCalendar[empId]?.toString() ?? '-';
          debugPrint('Assignments before update: $assignmentsBefore');
          // Auto-save immediately on selection
          await _updateShiftForEmployeeDate(empId, dateKey, v);
          // Log assignments sesudah update
          final assignmentsAfter = _shiftCalendar[empId]?.toString() ?? '-';
          debugPrint('Assignments after update: $assignmentsAfter');
        },
        itemBuilder: (_) => _shifts
            .map(
              (s) => PopupMenuItem(value: s['code'], child: Text(s['label']!)),
            )
            .toList(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.isEmpty ? '—' : status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.isEmpty ? '' : _getShiftDuration(status),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openShiftEditDialog(
    String empId,
    String dateKey,
    String currentStatus,
  ) {
    String selectedShift = currentStatus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shift'),
        content: Builder(
          builder: (ctx) {
            final shiftCodes = _shifts
                .map((s) => (s['code'] ?? '').toString())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList();
            final items = shiftCodes
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      _shifts.firstWhere(
                            (s) => (s['code'] ?? '') == code,
                            orElse: () => {'label': code},
                          )['label'] ??
                          code,
                    ),
                  ),
                )
                .toList();
            final safeValue = shiftCodes.contains(selectedShift)
                ? selectedShift
                : null;
            return DropdownButtonFormField<String>(
              initialValue: safeValue,
              items: items,
              onChanged: (v) => selectedShift = v ?? '',
              decoration: const InputDecoration(labelText: 'Pilih Shift'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedShift != currentStatus) {
                _updateShiftForEmployeeDate(empId, dateKey, selectedShift);
              }
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBulkAssignDialog() async {
    DateTime selectedFrom = _startDate;
    DateTime selectedTo = _startDate.add(const Duration(days: 6));
    String selectedShift = _shifts.isNotEmpty
        ? (_shifts.first['code'] ?? '')
        : '';
    bool forceApply = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Assign Shift to Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dari'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(selectedFrom),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedFrom,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setInnerState(() => selectedFrom = picked);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sampai'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(selectedTo),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedTo,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setInnerState(() => selectedTo = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Build a safe, deduplicated list of shift codes for the dropdown
                    Builder(
                      builder: (ctx) {
                        final shiftCodes = _shifts
                            .map((s) => (s['code'] ?? '').toString())
                            .where((c) => c.isNotEmpty)
                            .toSet()
                            .toList();
                        final items = shiftCodes
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text(
                                  _shifts.firstWhere(
                                        (s) => (s['code'] ?? '') == code,
                                        orElse: () => {'label': code},
                                      )['label'] ??
                                      code,
                                ),
                              ),
                            )
                            .toList();
                        final safeValue = shiftCodes.contains(selectedShift)
                            ? selectedShift
                            : null;
                        return DropdownButtonFormField<String>(
                          initialValue: safeValue,
                          items: items,
                          onChanged: (v) =>
                              setInnerState(() => selectedShift = v ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Pilih Shift',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: forceApply,
                          onChanged: (v) =>
                              setInnerState(() => forceApply = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Force apply konflik (abaikan peringatan)',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () async {
                    // Preview
                    final preview = await _previewBulkAssign(
                      _selectedGroup,
                      selectedFrom,
                      selectedTo,
                      selectedShift,
                    );

                    // Show preview dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Preview Bulk Assign'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Target karyawan: ${preview['targetsCount']}',
                                ),
                                Text('Dates: ${preview['dateCount']}'),
                                const SizedBox(height: 8),
                                Text(
                                  'Potensi konflik: ${preview['conflicts'].length}',
                                ),
                                const SizedBox(height: 8),
                                if ((preview['conflicts'] as List).isNotEmpty)
                                  ...((preview['conflicts'] as List)
                                      .take(8)
                                      .map(
                                        (c) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            '${c['employeeName']} • ${c['date']} • ${c['reason']} (existing: ${c['existing'] ?? '-'})',
                                          ),
                                        ),
                                      )),
                                if ((preview['conflicts'] as List).length > 8)
                                  Text(
                                    '...and ${(preview['conflicts'] as List).length - 8} more',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Tutup'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx); // close preview
                              Navigator.pop(context); // close main dialog
                              await _applyBulkAssign(
                                group: _selectedGroup,
                                from: selectedFrom,
                                to: selectedTo,
                                shiftCode: selectedShift,
                                force: forceApply,
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Preview'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _applyBulkAssign(
                      group: _selectedGroup,
                      from: selectedFrom,
                      to: selectedTo,
                      shiftCode: selectedShift,
                      force: forceApply,
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignShiftToGroup(
    String group,
    DateTime date,
    String shiftCode,
  ) async {
    setState(() => _isLoading = true);
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final targets = _employees
          .where((e) => (e['group'] ?? e['division'] ?? 'Umum') == group)
          .toList();
      if (targets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada karyawan pada group ini')),
        );
        return;
      }

      // Update local calendar for each target employee
      for (final emp in targets) {
        final empId = emp['id'];
        final existing = _shiftCalendar[empId] ?? {};
        final updated = Map<String, String>.from(existing);
        updated[dateKey] = shiftCode;
        _shiftCalendar[empId] = updated;
      }

      _hasUnsavedChanges = true;

      // Persist changes using existing save routine which handles create/update/merge
      await _saveShiftCalendarToSchedule();
    } catch (e, st) {
      debugPrint('bulk assign error: $e');
      debugPrint(st.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal assign shift ke group')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ================= BULK PREVIEW & APPLY (delegates to BulkShiftService) =================

  Future<Map<String, dynamic>> _previewBulkAssign(
    String group,
    DateTime from,
    DateTime to,
    String shiftCode,
  ) async {
    final targets = _employees
        .where((e) => (e['group'] ?? e['division'] ?? 'Umum') == group)
        .toList();
    if (_bulkShiftService == null) {
      return {
        'targetsCount': targets.length,
        'dateCount': to.difference(from).inDays.abs() + 1,
        'conflicts': [],
      };
    }

    final res = await _bulkShiftService!.previewBulkAssign(
      employees: targets,
      existingCalendar: _shiftCalendar,
      shiftCode: shiftCode,
      from: from,
      to: to,
    );

    final conflicts = res.conflicts
        .map(
          (c) => {
            'employeeId': c.employeeId,
            'employeeName': c.employeeName,
            'date': c.date,
            'reason': c.reason,
            'existing': c.existing,
          },
        )
        .toList();

    return {
      'targetsCount': res.targetsCount,
      'dateCount': res.dateCount,
      'conflicts': conflicts,
    };
  }

  Future<void> _applyBulkAssign({
    required String group,
    required DateTime from,
    required DateTime to,
    required String shiftCode,
    bool force = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final targets = _employees
          .where((e) => (e['group'] ?? e['division'] ?? 'Umum') == group)
          .toList();
      if (_bulkShiftService == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Service belum siap')));
        setState(() => _isLoading = false);
        return;
      }

      // preview to check conflicts
      final preview = await _bulkShiftService!.previewBulkAssign(
        employees: targets,
        existingCalendar: _shiftCalendar,
        shiftCode: shiftCode,
        from: from,
        to: to,
      );

      if (preview.conflicts.isNotEmpty && !force) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terdapat ${preview.conflicts.length} konflik. Gunakan Preview untuk melihat detail atau centang Force apply.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final assignments = _bulkShiftService!.generateAssignments(
        employees: targets,
        from: from,
        to: to,
        shiftCode: shiftCode,
        existingCalendar: _shiftCalendar,
        overwrite: true,
        force: force,
      );

      // merge assignments into local calendar
      for (final e in assignments.entries) {
        final eid = e.key;
        final merged = Map<String, String>.from(_shiftCalendar[eid] ?? {});
        merged.addAll(e.value);
        _shiftCalendar[eid] = merged;
      }

      _hasUnsavedChanges = true;

      await _saveShiftCalendarToSchedule();
    } catch (e, st) {
      debugPrint('apply bulk assign error: $e');
      debugPrint(st.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal apply bulk assign')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openShiftDialog({Map<String, String>? data}) {
    final codeCtrl = TextEditingController(text: data?['code'] ?? '');
    final nameCtrl = TextEditingController(text: data?['label'] ?? '');
    final startCtrl = TextEditingController(text: data?['start'] ?? '');
    final endCtrl = TextEditingController(text: data?['end'] ?? '');
    String selectedColor = data?['color'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data == null ? 'Tambah Shift' : 'Edit Shift'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Kode Shift'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Shift'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Jam Mulai (HH:MM)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Jam Selesai (HH:MM)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedColor.isEmpty ? null : selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Warna (opsional)',
                ),
                items: _colorOptions
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['hex'],
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c['hex'] != null
                                    ? (Color(
                                        int.parse(
                                          c['hex']!.replaceAll('#', '0xFF'),
                                        ),
                                      ))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Text(c['name'] ?? c['hex'] ?? ''),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => selectedColor = v ?? '',
                isExpanded: true,
              ),
            ],
          ),
        ),
        actions: [
          if (data != null)
            TextButton(
              onPressed: () async {
                // delete from backend if possible
                final shiftId = data['id'] ?? '';
                final shiftCode = data['code'] ?? '';
                if (shiftId.isNotEmpty) {
                  // Check whether shift is referenced anywhere before deleting
                  final inUse = await _shiftService.isShiftInUse(shiftId);
                  if (inUse) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Shift tidak dapat dihapus karena masih digunakan',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final ok = await _shiftService.deleteShift(shiftId);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal menghapus shift')),
                    );
                    return;
                  }
                  await _loadData();
                } else {
                  _shifts.removeWhere((s) => s['code'] == data['code']);
                  setState(() {});
                }
                Navigator.pop(context);
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              _handleShiftSave(
                data: data,
                code: codeCtrl.text.trim().toUpperCase(),
                label: nameCtrl.text.trim(),
                start: startCtrl.text.trim(),
                end: endCtrl.text.trim(),
                color: selectedColor.trim(),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShiftSave({
    Map<String, String>? data,
    required String code,
    required String label,
    required String start,
    required String end,
    String? color,
  }) async {
    debugPrint('=== _handleShiftSave START ===');
    debugPrint('Data: $data');
    debugPrint(
      'Code: $code, Label: $label, Start: $start, End: $end, Color: $color',
    );

    if (code.isEmpty || label.isEmpty) {
      debugPrint('Validation failed: code or label empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode dan nama wajib diisi')),
      );
      return;
    }

    // Validate time format (must contain colon)
    if (start.isNotEmpty && !start.contains(':')) {
      debugPrint('Validation failed: start time format invalid');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format jam mulai salah. Gunakan format HH:MM, contoh: 17:00')),
      );
      return;
    }
    if (end.isNotEmpty && !end.contains(':')) {
      debugPrint('Validation failed: end time format invalid');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format jam selesai salah. Gunakan format HH:MM, contoh: 17:00')),
      );
      return;
    }

    // Validate shift times are logical
    if (start.isNotEmpty && end.isNotEmpty) {
      try {
        final startTime = DateTime.parse('2023-01-01 $start:00');
        final endTime = DateTime.parse('2023-01-01 $end:00');
        if (startTime.isAfter(endTime) || startTime.isAtSameMomentAs(endTime)) {
          debugPrint('Validation failed: illogical shift times');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jam shift tidak logis')),
          );
          return;
        }

        // Validate shift duration does not exceed 24 hours
        final duration = endTime.difference(startTime);
        if (duration.inHours > 24 || (duration.inHours == 24 && duration.inMinutes > 0)) {
          debugPrint('Validation failed: shift duration exceeds 24 hours');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Durasi shift tidak boleh lebih dari 24 jam')),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error parsing times: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format jam tidak valid (gunakan HH:MM)')),
        );
        return;
      }
    }

    // basic uniqueness check locally
    debugPrint('Checking uniqueness for code: $code');
    debugPrint('Current shifts: ${_shifts.map((s) => s['code']).toList()}');
    final exists = _shifts.any(
      (s) =>
          (s['code'] ?? '') == code &&
          (data == null || s['code'] != data['code']),
    );
    debugPrint('Exists check result: $exists');
    if (exists) {
      debugPrint('Validation failed: code already exists');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kode shift sudah ada')));
      return;
    }

    final user = _authService.currentUser;
    final adminId = user?.uid ?? '';
    debugPrint('Admin ID: $adminId');

    if (data == null) {
      // create
      debugPrint('Creating new shift');
      final ok = await _shiftService.createShift(
        code: code,
        label: label,
        startTime: start,
        endTime: end,
        adminId: adminId,
        color: color,
      );
      debugPrint('Create result: $ok');
      if (!ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan shift')));
        return;
      }
      await _loadData();
      Navigator.pop(context);
    } else {
      // update
      final shiftId = data['id'] ?? '';
      final oldCode = data['code'] ?? '';
      debugPrint('Updating shift with ID: $shiftId, Old Code: $oldCode');
      debugPrint('Data ID: ${data['id']}');
      if (shiftId.isNotEmpty) {
        final ok = await _shift_service_updateWrapper(
          shiftId,
          code,
          label,
          start,
          end,
          color,
          oldCode,
        );
        debugPrint('Update result: $ok');
        if (!ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Gagal mengubah shift')));
          return;
        }
        debugPrint('Reloading data after update');
        await _loadData();
        debugPrint('Data reloaded, closing dialog');
        Navigator.pop(context);
      } else {
        // local-only update
        debugPrint('Local-only update');
        final idx = _shifts.indexWhere(
          (s) => (s['code'] ?? '') == data['code'],
        );
        if (idx != -1) {
          _shifts[idx] = {
            'code': code,
            'label': label,
            'start': start,
            'end': end,
            'color': color ?? '',
          };
          setState(() {});
          Navigator.pop(context);
        }
      }
    }
    debugPrint('=== _handleShiftSave END ===');
  }

  Future<bool> _shift_service_updateWrapper(
    String shiftId,
    String code,
    String label,
    String start,
    String end,
    String? color,
    String? oldCode,
  ) async {
    // Use ShiftService.updateShift which accepts color and oldCode now
    try {
      final ok = await _shiftService.updateShift(
        shiftId: shiftId,
        code: code,
        label: label,
        startTime: start,
        endTime: end,
        color: color,
        oldCode: oldCode,
      );
      return ok;
    } catch (e) {
      debugPrint('update wrapper error: $e');
      return false;
    }
  }

  // ================= CELLS =================
  Widget _headerCell(String text, double width) {
    return Container(
      width: width,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border.all(color: Colors.white),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _nameCell(String text, [double width = 220]) {
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade100,
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // ================= SUMMARY PANEL =================
  int _countShiftOnDate(String dateKey, String code) {
    var count = 0;
    for (final emp in _filteredEmployees) {
      final eid = emp['id'];
      final assigned = _shiftCalendar[eid]?[dateKey] ?? '';
      if (assigned == code) count += 1;
    }
    return count;
  }

  // ================= SHIFT PANEL =================
  Widget _buildShiftPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Shift',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => _openShiftDialog(),
                tooltip: 'Tambah Shift',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _shifts.length,
              itemBuilder: (context, index) {
                final s = _shifts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Color indicator
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _shiftColor(s['code'] ?? ''),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Shift details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['label'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s['code'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s['start'] ?? '-'} - ${s['end'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              onPressed: () => _openShiftDialog(
                                data: Map<String, String>.from(s),
                              ),
                              tooltip: 'Edit Shift',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Konfirmasi Hapus'),
                                    content: Text(
                                      'Yakin ingin menghapus shift ${s['label']}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final shiftId = s['id'] ?? '';
                                  final shiftCode = s['code'] ?? '';
                                  bool ok = false;
                                  if (shiftId.isNotEmpty) {
                                    final inUse = await _shiftService
                                        .isShiftInUse(shiftId);
                                    if (inUse) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Shift tidak dapat dihapus karena masih digunakan',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }
                                    ok = await _shiftService.deleteShift(
                                      shiftId,
                                    );
                                  }
                                  if (ok) {
                                    // Only remove from local list if delete succeeded
                                    _shifts.removeWhere(
                                      (x) => x['code'] == shiftCode,
                                    );
                                    // Hapus dari semua schedule di UI
                                    for (final empId in _shiftCalendar.keys) {
                                      _shiftCalendar[empId]?.removeWhere(
                                        (key, value) => value == shiftCode,
                                      );
                                    }
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Shift berhasil terhapus',
                                        ),
                                      ),
                                    );
                                    await _loadData();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Gagal menghapus shift'),
                                      ),
                                    );
                                  }
                                }
                              },
                              tooltip: 'Hapus Shift',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }
}
