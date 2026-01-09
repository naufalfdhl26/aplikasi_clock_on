import 'dart:convert';
import 'package:aplikasi_clockon/data/models/shift_model.dart';
import 'package:aplikasi_clockon/restapi.dart';

class ShiftRepository {
  final DataService _dataService = DataService();

  static const String _token = '693b109f23173f13b93c2060';
  static const String _project = 'clockon';
  static const String _collection = 'shift';

  /// Insert shift baru
  Future<ShiftModel?> insertShift({
    required String appId,
    required String shiftCode,
    required String shiftName,
    required String startTime,
    required String endTime,
    required String adminId,
    int toleranceMinutes = 15,
    bool isActive = true,
    String? description,
    String? color,
  }) async {
    try {
      final response = await _dataService.insertShift(
        appId,
        shiftCode,
        shiftName,
        startTime,
        endTime,
        adminId,
        color,
      );

      if (response != null && response != '[]') {
        final data = jsonDecode(response);
        return ShiftModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error inserting shift: $e');
      return null;
    }
  }

  /// Ambil semua shift
  Future<List<ShiftModel>> getAllShifts(String appId) async {
    try {
      final response = await _dataService.selectAll(
        _token,
        _project,
        _collection,
        appId,
      );
      if (response != null && response != '[]') {
        final decoded = jsonDecode(response);
        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          final d = decoded['data'];
          items = d is List ? d : [d];
        } else if (decoded is Map) {
          items = [decoded];
        }

        return items
            .map((json) => ShiftModel.fromMap(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching shifts: $e');
      return [];
    }
  }

  /// Ambil shift berdasarkan ID
  Future<ShiftModel?> getShiftById(String appId, String shiftId) async {
    try {
      final response = await _dataService.selectId(
        _token,
        _project,
        _collection,
        appId,
        shiftId,
      );
      if (response != null && response != '[]') {
        final decoded = jsonDecode(response);
        Map<String, dynamic> map;
        if (decoded is Map && decoded.containsKey('data')) {
          map = (decoded['data'] is List)
              ? (decoded['data'][0] as Map<String, dynamic>)
              : (decoded['data'] as Map<String, dynamic>);
        } else if (decoded is Map) {
          map = decoded as Map<String, dynamic>;
        } else {
          return null;
        }
        return ShiftModel.fromMap(map);
      }
      return null;
    } catch (e) {
      print('Error fetching shift: $e');
      return null;
    }
  }

  /// Ambil shift berdasarkan kode shift
  Future<ShiftModel?> getShiftByCode(String appId, String shiftCode) async {
    try {
      final response = await _dataService.selectWhere(
        _token,
        _project,
        _collection,
        appId,
        'code',
        shiftCode,
      );

      if (response != null && response != '[]') {
        final List<dynamic> data = jsonDecode(response);
        if (data.isNotEmpty) {
          return ShiftModel.fromMap(data[0] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching shift by code: $e');
      return null;
    }
  }

  /// Update shift
  Future<bool> updateShift(
    String appId,
    String shiftId,
    ShiftModel updatedShift,
  ) async {
    try {
      // Update core fields individually (API expects update_field/update_value strings)
      final updates = {
        'code': updatedShift.code,
        'label': updatedShift.label,
        'startTime': updatedShift.startTime.toIso8601String(),
        'endTime': updatedShift.endTime.toIso8601String(),
        'toleranceMinutes': updatedShift.toleranceMinutes.toString(),
        'isActive': updatedShift.isActive ? 'true' : 'false',
        'description': updatedShift.description ?? '',
        'color': updatedShift.color ?? '',
      };

      for (final entry in updates.entries) {
        await _dataService.updateId(
          entry.key,
          entry.value,
          _token,
          _project,
          _collection,
          appId,
          shiftId,
        );
      }

      return true;
    } catch (e) {
      print('Error updating shift: $e');
      return false;
    }
  }

  /// Hapus shift
  Future<bool> deleteShift(String appId, String shiftId) async {
    try {
      final result = await _dataService.removeId(
        _token,
        _project,
        _collection,
        appId,
        shiftId,
      );

      return result;
    } catch (e) {
      print('Error deleting shift: $e');
      return false;
    }
  }

  /// Cari shift berdasarkan nama
  Future<List<ShiftModel>> searchShiftByName(String appId, String name) async {
    try {
      final response = await _dataService.selectWhereLike(
        _token,
        _project,
        _collection,
        appId,
        'label',
        name,
      );

      if (response != null && response != '[]') {
        final List<dynamic> data = jsonDecode(response);
        return data
            .map((json) => ShiftModel.fromMap(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error searching shifts: $e');
      return [];
    }
  }

  /// Ambil shift aktif saja
  Future<List<ShiftModel>> getActiveShifts(String appId) async {
    try {
      final response = await _dataService.selectWhere(
        _token,
        _project,
        _collection,
        appId,
        'isActive',
        'true',
      );

      if (response != null && response != '[]') {
        final List<dynamic> data = jsonDecode(response);
        return data
            .map((json) => ShiftModel.fromMap(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching active shifts: $e');
      return [];
    }
  }
}
