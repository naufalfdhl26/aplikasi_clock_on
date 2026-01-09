import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/employee_model.dart';

class EmployeeService {
  final DataService _api = DataService();

  Future<List<EmployeeModel>> fetchAllEmployees() async {
    try {
      final res = await _api.selectAll(token, project, 'employee', appid);
      if (res == null) return [];

      debugPrint('selectAll(employee) response: $res');

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

      return items
          .map(
            (e) => EmployeeModel.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e, st) {
      debugPrint('fetchAllEmployees error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<bool> createEmployee(EmployeeModel model) async {
    try {
      // Send admin email as createdby if present, otherwise admin id
      final createdByValue =
          (model.createdByAdminEmail ?? model.createdByAdminId) ?? '';
      final res = await _api.insertEmployee(
        appid,
        model.name,
        model.email,
        model.password,
        model.division,
        model.locationId ?? '',
        model.position ?? '',
        model.isActive ? '1' : '0',
        model.scheduleId ?? '',
        model.createdAt.toIso8601String(),
        createdByValue,
      );
      debugPrint('insertEmployee response: $res');
      return res != null && res != '[]';
    } catch (e) {
      debugPrint('createEmployee error: $e');
      return false;
    }
  }

  Future<bool> updateEmployee(String id, Map<String, dynamic> updates) async {
    try {
      // Update each field, try updateId first; if it fails, try updateWhere as fallback
      for (final entry in updates.entries) {
        final field = entry.key;
        final value = entry.value.toString();

        var ok = await _api.updateId(
          field,
          value,
          token,
          project,
          'employee',
          appid,
          id,
        );

        if (!ok) {
          // fallback to updateWhere (where id = id)
          ok = await _api.updateWhere(
            'id',
            id,
            field,
            value,
            token,
            project,
            'employee',
            appid,
          );
        }

        if (!ok) {
          debugPrint('updateEmployee: failed to update $field for id $id');
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('updateEmployee error: $e');
      return false;
    }
  }

  Future<bool> deleteEmployee(String id) async {
    try {
      final ok = await _api.removeId(token, project, 'employee', appid, id);
      return ok == true;
    } catch (e) {
      debugPrint('deleteEmployee error: $e');
      return false;
    }
  }
}
