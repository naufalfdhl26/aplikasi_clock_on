import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasi_clockon/core/services/bulk_shift_service.dart';
import 'package:intl/intl.dart';

void main() {
  group('BulkShiftService', () {
    final shifts = [
      {'code': 'MORNING', 'label': 'Morning', 'start': '08:00', 'end': '16:00'},
      {'code': 'NIGHT', 'label': 'Night', 'start': '22:00', 'end': '06:00'},
      {'code': 'OFF', 'label': 'Off', 'start': '', 'end': ''},
    ];

    late BulkShiftService svc;

    setUp(() {
      svc = BulkShiftService(shifts: shifts, minRestHours: 8.0);
    });

    test('overnight shift end is next day', () {
      final date = DateTime(2025, 12, 20);
      final range = svc.shiftStartEndOnDate('NIGHT', date);
      final start = range['start']!;
      final end = range['end']!;
      expect(end.isAfter(start), true);
      expect(end.day, equals(start.add(const Duration(days: 1)).day));
    });

    test('rest hours calculation detects short rest', () {
      final prevDate = DateTime(2025, 12, 19);
      final newDate = DateTime(2025, 12, 20);
      final restH = svc.restHoursBetween('NIGHT', prevDate, 'MORNING', newDate);
      // NIGHT ends at 06:00, MORNING starts 08:00 => 2 hours
      expect(restH, closeTo(2.0, 0.1));
      expect(restH < svc.minRestHours, true);
    });

    test('previewBulkAssign finds insufficient rest conflict', () async {
      final emp = [{'id': 'e1', 'name': 'Budi', 'group': 'Toko'}];
      final existingCalendar = {
        'e1': {
          DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 19)): 'NIGHT',
        }
      };

      final res = await svc.previewBulkAssign(
        employees: emp,
        existingCalendar: existingCalendar,
        shiftCode: 'MORNING',
        from: DateTime(2025, 12, 20),
        to: DateTime(2025, 12, 20),
      );

      expect(res.conflicts.isNotEmpty, true);
      final conflict = res.conflicts.first;
      expect(conflict.reason.toLowerCase(), contains('insufficient rest'));
    });

    test('generateAssignments respects overwrite flag', () {
      final emp = [{'id': 'e1', 'name': 'Ani', 'group': 'Toko'}];
      final existing = {
        'e1': {DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 21)): 'MORNING'}
      };

      // overwrite = false should skip overwriting existing
      final out1 = svc.generateAssignments(
        employees: emp,
        from: DateTime(2025, 12, 21),
        to: DateTime(2025, 12, 21),
        shiftCode: 'OFF',
        existingCalendar: existing,
        overwrite: false,
        force: false,
      );
      expect(out1['e1']![DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 21))], 'MORNING');

      // overwrite = true should replace
      final out2 = svc.generateAssignments(
        employees: emp,
        from: DateTime(2025, 12, 21),
        to: DateTime(2025, 12, 21),
        shiftCode: 'OFF',
        existingCalendar: existing,
        overwrite: true,
        force: false,
      );
      expect(out2['e1']![DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 21))], 'OFF');
    });

    test('generateDefaultAssignmentsForRange applies rules per weekday', () {
      final emp = [{'id': 'e1', 'name': 'Siti', 'group': 'Toko'}];
      final rules = {
        'Toko': {1: 'MORNING', 2: 'MORNING', 3: 'MORNING', 4: 'MORNING', 5: 'MORNING', 6: 'OFF', 7: 'OFF'}
      };

      final from = DateTime(2025, 12, 15); // Monday
      final to = DateTime(2025, 12, 21); // Sunday
      final defaults = svc.generateDefaultAssignmentsForRange(emp, from, to, rules);
      expect(defaults.containsKey('e1'), true);
      // Monday should be MORNING
      expect(defaults['e1']![DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 15))], 'MORNING');
      // Saturday should be OFF
      expect(defaults['e1']![DateFormat('yyyy-MM-dd').format(DateTime(2025, 12, 20))], 'OFF');
    });
  });
}
