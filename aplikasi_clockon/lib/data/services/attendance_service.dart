import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../restapi.dart';
import '../../config.dart';
import 'wifi_service.dart';
import 'location_service.dart';
import '../models/location_model.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final DataService _api = DataService();
  final WifiService _wifiService = WifiService();
  final LocationService _locationService = LocationService();

  // Broadcast stream to notify attendance updates (employeeId, date)
  static final StreamController<Map<String, String>>
  _attendanceUpdateController =
      StreamController<Map<String, String>>.broadcast();

  /// Stream of attendance update events. Each event is a map with keys
  /// 'employeeId' and 'date' (yyyy-MM-dd).
  static Stream<Map<String, String>> get attendanceUpdates =>
      _attendanceUpdateController.stream;

  /// Notify listeners that an attendance record for [employeeId] on [date]
  /// was updated (e.g., check-in or check-out).
  /// Notify listeners that an attendance record was updated.
  /// Optionally include `checkin` and `checkout` (ISO or HH:mm:ss) so
  /// listeners can update UI immediately without re-fetching from server.
  static void notifyAttendanceUpdated(
    String employeeId,
    String date, {
    String? checkin,
    String? checkout,
  }) {
    try {
      final payload = <String, String>{'employeeId': employeeId, 'date': date};
      if (checkin != null) payload['checkin'] = checkin;
      if (checkout != null) payload['checkout'] = checkout;
      // Debug: log payload so UI can verify events are emitted
      try {
        debugPrint('notifyAttendanceUpdated payload: $payload');
      } catch (_) {}
      _attendanceUpdateController.add(payload);
    } catch (_) {}
  }

  Future<List<LocationModel>> _getLocations() async {
    return _locationService.fetchAllLocations();
  }

  Future<Map<String, dynamic>> getCurrentWifi() async {
    final data = await _wifiService.getCurrentWifi();
    return data;
  }

  Future<bool> isConnectedToOfficeWifi() async {
    final wifi = await getCurrentWifi();
    final locations = await _getLocations();
    if (wifi['ssid'] == null || wifi['ssid'] == 'Tidak terhubung') return false;
    for (final loc in locations) {
      if (loc.matchesWifi(wifi['ssid'] ?? '', wifi['bssid'] ?? '')) return true;
    }
    return false;
  }

  Future<String> checkIn({
    required String employeeId,
    String checkinTime = '',
  }) async {
    final wifi = await getCurrentWifi();
    final dt = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(dt);
    final time = checkinTime.isNotEmpty
        ? checkinTime
        : DateFormat('HH:mm:ss').format(dt);

    final res = await _api.insertAttendance(
      appid,
      employeeId,
      date,
      time,
      '',
      'present',
      wifi['ssid'] ?? '',
      wifi['bssid'] ?? '',
      '0',
      dt.toIso8601String(),
    );

    return res ?? '[]';
  }

  Future<String> checkOut({
    required String employeeId,
    String checkoutTime = '',
  }) async {
    final wifi = await getCurrentWifi();
    final dt = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(dt);
    final time = checkoutTime.isNotEmpty
        ? checkoutTime
        : DateFormat('HH:mm:ss').format(dt);

    final res = await _api.insertAttendance(
      appid,
      employeeId,
      date,
      '',
      time,
      'present',
      wifi['ssid'] ?? '',
      wifi['bssid'] ?? '',
      '0',
      dt.toIso8601String(),
    );

    return res ?? '[]';
  }

  /// Fetch all attendance records for a specific employee
  Future<List<AttendanceModel>> fetchAttendanceByEmployee(
    String employeeId,
  ) async {
    try {
      debugPrint('=== fetchAttendanceByEmployee Debug ===');
      debugPrint('Employee ID: $employeeId');

      final res = await _api.selectWhere(
        token,
        project,
        'attendance',
        appid,
        'employeeId',
        employeeId,
      );

      if (res == null) {
        debugPrint('selectWhere returned null');
        return [];
      }

      debugPrint('selectWhere(attendance) response: $res');

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

      debugPrint('Processing ${items.length} attendance items');
      final attendances = items
          .map(
            (e) =>
                AttendanceModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      debugPrint(
        'Successfully parsed ${attendances.length} AttendanceModel objects',
      );
      return attendances;
    } catch (e, st) {
      debugPrint('fetchAttendanceByEmployee error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  /// Fetch attendance records for specific date range
  Future<List<AttendanceModel>> fetchAttendanceByDateRange(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final all = await fetchAttendanceByEmployee(employeeId);
      return all.where((att) {
        return att.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            att.date.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      debugPrint('fetchAttendanceByDateRange error: $e');
      return [];
    }
  }
}
