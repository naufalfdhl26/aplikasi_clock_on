// BulkShiftService: stateless helper for previewing and applying bulk shift assignments
// - Accepts shift definitions as List<Map<String,String>> compatible with existing screen `_shifts`
// - Provides previewBulkAssign() to surface conflicts, and generateAssignments() to produce assignment map
// - Keeps logic testable and independent of UI and persistence layer

import 'package:intl/intl.dart';

// Simple result models
class BulkConflict {
  final String employeeId;
  final String employeeName;
  final String date; // yyyy-MM-dd
  final String reason;
  final String existing; // existing shift (may be empty)

  BulkConflict({
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.reason,
    this.existing = '',
  });
}

class BulkPreviewResult {
  final int targetsCount;
  final int dateCount;
  final List<BulkConflict> conflicts;

  BulkPreviewResult({
    required this.targetsCount,
    required this.dateCount,
    required this.conflicts,
  });
}

typedef IsEmployeeOnLeave = bool Function(String employeeId, DateTime date);

class BulkShiftService {
  // shifts: list of shift definitions with keys: 'code', 'label', 'start', 'end'
  // start/end formats: 'HH:mm' or ISO time. OFF can be represented with empty start/end or 'OFF' code.
  final List<Map<String, String>> shifts;
  final double minRestHours;
  final IsEmployeeOnLeave? isEmployeeOnLeave; // optional hook (leave handled elsewhere)

  BulkShiftService({required this.shifts, this.minRestHours = 8.0, this.isEmployeeOnLeave});

  // Normalize shift lookup
  Map<String, String>? _getShiftDef(String code) {
    try {
      return shifts.firstWhere((s) => (s['code'] ?? '').toString() == code);
    } catch (e) {
      return null;
    }
  }

  // Parse a time string (HH:mm or ISO), return DateTime for the given base date
  DateTime _parseTimeOnDate(String timeStr, DateTime date) {
    if (timeStr.isEmpty) return DateTime(date.year, date.month, date.day);
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        return DateTime(date.year, date.month, date.day, h, m, s);
      }
      final dt = DateTime.parse(timeStr);
      return DateTime(date.year, date.month, date.day, dt.hour, dt.minute, dt.second);
    } catch (_) {
      return DateTime(date.year, date.month, date.day);
    }
  }

  // Return start & end datetimes for a shift on the supplied date (handles overnight)
  Map<String, DateTime> shiftStartEndOnDate(String code, DateTime date) {
    final def = _getShiftDef(code);
    final dayBase = DateTime(date.year, date.month, date.day);

    if (def == null) {
      // treat as OFF (no working hours)
      return {'start': dayBase, 'end': dayBase};
    }

    final startStr = def['start'] ?? '';
    final endStr = def['end'] ?? '';

    if (startStr.isEmpty && endStr.isEmpty) {
      // OFF
      return {'start': dayBase, 'end': dayBase};
    }

    final s = _parseTimeOnDate(startStr, dayBase);
    var e = _parseTimeOnDate(endStr, dayBase);
    if (!e.isAfter(s)) {
      // overnight; end is next day
      e = e.add(const Duration(days: 1));
    }
    return {'start': s, 'end': e};
  }

  // Compute rest hours between prev shift (prevDate) and new shift (newDate)
  double restHoursBetween(String? prevCode, DateTime prevDate, String newCode, DateTime newDate) {
    if (prevCode == null || prevCode.isEmpty) return double.infinity;

    final prev = shiftStartEndOnDate(prevCode, prevDate);
    final next = shiftStartEndOnDate(newCode, newDate);
    final prevEnd = prev['end']!;
    final newStart = next['start']!;
    final diffMinutes = newStart.difference(prevEnd).inMinutes;
    return diffMinutes / 60.0;
  }

  // Generate default assignments for a range based on a simple rulemap:
  // rules: Map<String(groupOrDivision), Map<int(weekday, 1-7), String(shiftCode)>>
  Map<String, Map<String, String>> generateDefaultAssignmentsForRange(
    List<Map<String, dynamic>> employees,
    DateTime from,
    DateTime to,
    Map<String, Map<int, String>> rules,
  ) {
    final out = <String, Map<String, String>>{}; // empId -> { yyyy-MM-dd: shiftCode }

    for (final emp in employees) {
      final eid = emp['id'] as String;
      final group = (emp['group'] ?? emp['division'] ?? '').toString();
      final groupRules = rules[group] ?? {};
      final empMap = <String, String>{};
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        final wd = d.weekday; // 1..7 Mon..Sun
        final defaultShift = groupRules[wd] ?? groupRules[0] ?? ''; // 0 can be fallback
        if (defaultShift.isNotEmpty) {
          empMap[DateFormat('yyyy-MM-dd').format(d)] = defaultShift;
        }
      }
      if (empMap.isNotEmpty) out[eid] = empMap;
    }

    return out;
  }

  // Preview bulk assign and detect conflicts (leave check optional via isEmployeeOnLeave)
  Future<BulkPreviewResult> previewBulkAssign({
    required List<Map<String, dynamic>> employees,
    required Map<String, Map<String, String>> existingCalendar, // empId -> {date: shiftCode}
    required String shiftCode,
    required DateTime from,
    required DateTime to,
  }) async {
    final targets = employees;
    final conflicts = <BulkConflict>[];
    final minRest = minRestHours;

    for (final emp in targets) {
      final eid = emp['id'] as String;
      final name = emp['name'] ?? '';

      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        final key = DateFormat('yyyy-MM-dd').format(d);
        final existing = existingCalendar[eid]?[key] ?? '';

        // Leave check (optional)
        if ((isEmployeeOnLeave?.call(eid, d) ?? false) && shiftCode.toUpperCase() != 'CUTI' && shiftCode.toUpperCase() != 'LEAVE') {
          conflicts.add(BulkConflict(employeeId: eid, employeeName: name, date: key, reason: 'Employee on leave', existing: existing));
          continue;
        }

        // Double shift on same date
        if (existing.isNotEmpty && existing != shiftCode) {
          conflicts.add(BulkConflict(employeeId: eid, employeeName: name, date: key, reason: 'Existing assignment will be overwritten', existing: existing));
        }

        // Check rest hours with previous day
        final prev = d.subtract(const Duration(days: 1));
        final prevKey = DateFormat('yyyy-MM-dd').format(prev);
        final prevCode = existingCalendar[eid]?[prevKey] ?? '';
        if (prevCode.isNotEmpty) {
          final rest = restHoursBetween(prevCode, prev, shiftCode, d);
          if (rest < minRest) {
            conflicts.add(BulkConflict(employeeId: eid, employeeName: name, date: key, reason: 'Insufficient rest from previous shift (${rest.toStringAsFixed(1)}h)', existing: prevCode));
          }
        }

        // Check rest with next day
        final next = d.add(const Duration(days: 1));
        final nextKey = DateFormat('yyyy-MM-dd').format(next);
        final nextCode = existingCalendar[eid]?[nextKey] ?? '';
        if (nextCode.isNotEmpty) {
          final rest = restHoursBetween(shiftCode, d, nextCode, next);
          if (rest < minRest) {
            conflicts.add(BulkConflict(employeeId: eid, employeeName: name, date: key, reason: 'Insufficient rest before next shift (${rest.toStringAsFixed(1)}h)', existing: nextCode));
          }
        }
      }
    }

    return BulkPreviewResult(targetsCount: targets.length, dateCount: from.difference(to).inDays.abs() + 1, conflicts: conflicts);
  }

  // Generate assignment map for apply: empId -> { date: shiftCode }
  Map<String, Map<String, String>> generateAssignments({
    required List<Map<String, dynamic>> employees,
    required DateTime from,
    required DateTime to,
    required String shiftCode,
    Map<String, Map<String, String>>? existingCalendar,
    bool overwrite = true, // if false, skip dates where existing assignment exists
    bool force = false, // if true, ignore conflicts
  }) {
    final out = <String, Map<String, String>>{};

    for (final emp in employees) {
      final eid = emp['id'] as String;
      final base = Map<String, String>.from(existingCalendar?[eid] ?? {});
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        final key = DateFormat('yyyy-MM-dd').format(d);
        final existing = base[key] ?? '';
        if (existing.isNotEmpty && !overwrite && !force) continue;
        base[key] = shiftCode;
      }
      out[eid] = base;
    }

    return out;
  }
}
