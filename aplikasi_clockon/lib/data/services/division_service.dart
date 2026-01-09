import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/division_model.dart';

class DivisionService {
  final DataService _api = DataService();

  Future<List<DivisionModel>> fetchAllDivisions() async {
    try {
      final res = await _api.selectAll(token, project, 'division', appid);
      if (res == null) return [];

      debugPrint('selectAll(division) response: $res');

      final decoded = jsonDecode(res);
      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          items = decoded['data'];
        } else if (decoded['result'] is List) {
          items = decoded['result'];
        } else if (decoded.values.any((v) => v is List)) {
          items = decoded.values.firstWhere((v) => v is List) as List<dynamic>;
        } else {
          items = [decoded];
        }
      } else {
        return [];
      }

      return items
          .map((e) => DivisionModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('fetchAllDivisions error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<DivisionModel?> createDivision(DivisionModel model) async {
    try {
      final res = await _api.insertDivision(
        appid,
        model.name,
        model.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        model.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      );
      if (res == null || res == '[]') return model;
      return model;
    } catch (e) {
      debugPrint('createDivision error: $e');
      return null;
    }
  }

  Future<bool> updateDivision(DivisionModel model) async {
    try {
      await _api.updateId(
        'name',
        model.name,
        token,
        project,
        'division',
        appid,
        model.id,
      );
      return true;
    } catch (e) {
      debugPrint('updateDivision error: $e');
      return false;
    }
  }

  Future<bool> deleteDivision(String id) async {
    try {
      final removed = await _api.removeId(
        token,
        project,
        'division',
        appid,
        id,
      );
      return removed == true;
    } catch (e) {
      debugPrint('deleteDivision error: $e');
      return false;
    }
  }
}
