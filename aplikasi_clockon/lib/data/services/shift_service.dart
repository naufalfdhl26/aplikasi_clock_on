import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../restapi.dart';
import '../../config.dart';

class ShiftService {
  final DataService _api = DataService();

  Future<List<Map<String, dynamic>>> fetchAllShifts(String adminId) async {
    try {
      final res = await _api.selectAll(token, project, 'shift', appid);
      if (res == null) return [];

      debugPrint('selectAll(shift) response: $res');

      dynamic decoded;
      try {
        decoded = jsonDecode(res);
      } catch (e) {
        debugPrint('JSON decode error: $e');
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

      // If adminId is empty, return all shifts (no filter)
      if (adminId.isEmpty) {
        return items.cast<Map<String, dynamic>>().toList();
      }

      // Filter shifts by adminId
      return items
          .where((e) {
            final createdBy = e is Map
                ? (e['createdby'] ?? e['createdBy'])
                : null;
            return createdBy == adminId;
          })
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e, st) {
      debugPrint('fetchAllShifts error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<bool> createShift({
    required String code,
    required String label,
    required String startTime,
    required String endTime,
    required String adminId,
    String? color,
  }) async {
    try {
      debugPrint('=== createShift Debug ===');
      debugPrint('Code: $code, Label: $label');
      debugPrint('Start: $startTime, End: $endTime');
      debugPrint('Admin ID: $adminId');

      final res = await _api.insertShift(
        appid,
        code,
        label,
        startTime,
        endTime,
        adminId,
        color,
      );
      debugPrint('insertShift response: $res');
      return res != null && res != '[]';
    } catch (e, st) {
      debugPrint('createShift error: $e');
      debugPrint(st.toString());
      return false;
    }
  }

  Future<bool> updateShift({
    required String shiftId,
    required String code,
    required String label,
    required String startTime,
    required String endTime,
    String? color,
    String? oldCode,
  }) async {
    try {
      debugPrint('=== updateShift Debug ===');
      debugPrint('Shift ID: $shiftId, Old Code: $oldCode, New Code: $code');

      final updates = {
        'code': code,
        'label': label,
        'startTime': startTime,
        'endTime': endTime,
      };

      // Only include color if it's provided and not empty (consistent with insertShift)
      if (color != null && color.isNotEmpty) {
        updates['color'] = color;
      }

      for (final entry in updates.entries) {
        debugPrint(
          'updateShift: updating field ${entry.key} to ${entry.value}',
        );
        final result = await _api.updateId(
          entry.key,
          entry.value,
          token,
          project,
          'shift',
          appid,
          shiftId,
        );
        debugPrint('updateShift: updateId result for ${entry.key}: $result');
        // Jika response mengandung 'parameter not complete', hentikan dan return false
        if (result is String && result.contains('parameter not complete')) {
          debugPrint(
            'updateShift: parameter not complete for field ${entry.key}',
          );
          return false;
        }
      }

      // If code changed, update all schedules that use the old code
      if (oldCode != null && oldCode != code) {
        debugPrint('Code changed from $oldCode to $code, updating schedules');
        await _updateSchedulesWithOldCode(oldCode, code);
      }

      return true;
    } catch (e) {
      debugPrint('updateShift error: $e');
      return false;
    }
  }

  Future<void> _updateSchedulesWithOldCode(
    String oldCode,
    String newCode,
  ) async {
    try {
      // Get all schedules
      final schedules = await _api.selectAll(token, project, 'schedule', appid);
      if (schedules == null || schedules == '[]') return;

      dynamic decoded;
      try {
        decoded = jsonDecode(schedules);
      } catch (e) {
        debugPrint('JSON decode error in _updateSchedulesWithOldCode: $e');
        return;
      }

      List<dynamic> scheduleList = [];
      if (decoded is List) {
        scheduleList = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        scheduleList = decoded['data'] ?? [];
      }

      for (final s in scheduleList) {
        final scheduleId = s['_id']?.toString() ?? s['id']?.toString();
        final assignments = s['assignments'];
        if (scheduleId == null || assignments == null) continue;

        Map<String, String> assignmentMap = {};
        if (assignments is Map) {
          assignmentMap = assignments.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        } else if (assignments is String) {
          try {
            final parsed = jsonDecode(assignments);
            if (parsed is Map) {
              assignmentMap = parsed.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              );
            }
          } catch (_) {}
        }

        // Check if any assignment uses the old code
        bool needsUpdate = false;
        final updatedAssignments = Map<String, String>.from(assignmentMap);
        for (final entry in assignmentMap.entries) {
          if (entry.value == oldCode) {
            updatedAssignments[entry.key] = newCode;
            needsUpdate = true;
          }
        }

        if (needsUpdate) {
          debugPrint(
            'Updating schedule $scheduleId: replacing $oldCode with $newCode',
          );
          final updateResult = await _api.updateId(
            'assignments',
            jsonEncode(updatedAssignments),
            token,
            project,
            'schedule',
            appid,
            scheduleId,
          );
          debugPrint('Schedule update result: $updateResult');
        }
      }
    } catch (e) {
      debugPrint('_updateSchedulesWithOldCode error: $e');
    }
  }

  Future<bool> deleteShift(String shiftId) async {
    try {
      // Return the actual result from the API so callers can react to failure
      final result = await _api.removeId(
        token,
        project,
        'shift',
        appid,
        shiftId,
      );
      return result == true;
    } catch (e) {
      debugPrint('deleteShift error: $e');
      return false;
    }
  }

  /// Check whether the shift is referenced in any schedules or employees.
  /// Returns `true` when the shift is in use and should not be deleted.
  Future<bool> isShiftInUse(String shiftId) async {
    try {
      // Fetch shift to obtain its code (some relations reference the code)
      final shiftRaw = await _api.selectId(
        token,
        project,
        'shift',
        appid,
        shiftId,
      );
      if (shiftRaw == null || shiftRaw == '[]') return false;

      String? code;
      try {
        final decoded = jsonDecode(shiftRaw);
        if (decoded is Map) {
          code = decoded['code'] ?? decoded['data']?['code'];
        } else if (decoded is List && decoded.isNotEmpty) {
          code = decoded[0]['code'];
        }
      } catch (e) {
        debugPrint('isShiftInUse: error decoding shift: $e');
      }

      // 1) Check schedules for assignments using this shift code
      if (code != null && code.isNotEmpty) {
        final schedulesRaw = await _api.selectAll(
          token,
          project,
          'schedule',
          appid,
        );
        if (schedulesRaw != null && schedulesRaw != '[]') {
          try {
            final decoded = jsonDecode(schedulesRaw);
            List<dynamic> scheduleList = [];
            if (decoded is List) {
              scheduleList = decoded;
            } else if (decoded is Map && decoded.containsKey('data'))
              scheduleList = decoded['data'] ?? [];

            for (final s in scheduleList) {
              if (s == null) continue;
              final assignments = s['assignments'];
              Map<String, dynamic> map = {};
              if (assignments is Map) {
                map = Map<String, dynamic>.from(assignments);
              } else if (assignments is String) {
                try {
                  final parsed = jsonDecode(assignments);
                  if (parsed is Map) map = Map<String, dynamic>.from(parsed);
                } catch (_) {}
              }
              for (final v in map.values) {
                if (v == code) return true;
              }
            }
          } catch (e) {
            debugPrint('isShiftInUse: error decoding schedules: $e');
          }
        }
      }

      // 2) Check employees for direct references (best-effort)
      final employeesRaw = await _api.selectAll(
        token,
        project,
        'employee',
        appid,
      );
      if (employeesRaw != null && employeesRaw != '[]') {
        try {
          final decoded = jsonDecode(employeesRaw);
          List<dynamic> empList = [];
          if (decoded is List) {
            empList = decoded;
          } else if (decoded is Map && decoded.containsKey('data'))
            empList = decoded['data'] ?? [];

          for (final e in empList) {
            if (e == null) continue;
            // Common fields that might reference a shift
            final candidate =
                (e['shift'] ??
                        e['shiftId'] ??
                        e['schedule'] ??
                        e['scheduleid'] ??
                        e['scheduleId'])
                    ?.toString() ??
                '';
            if (candidate.isEmpty) continue;
            if (candidate == shiftId || candidate == code) return true;
          }
        } catch (e) {
          debugPrint('isShiftInUse: error decoding employees: $e');
        }
      }

      return false;
    } catch (e) {
      debugPrint('isShiftInUse error: $e');
      // On error, be conservative and indicate it's in use to avoid accidental deletion
      return true;
    }
  }
}
