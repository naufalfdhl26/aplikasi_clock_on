import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/location_model.dart';

class LocationService {
  final DataService _api = DataService();

  Future<List<LocationModel>> fetchAllLocations() async {
    try {
      final res = await _api.selectAll(token, project, 'location', appid);
      if (res == null) return [];

      // Debug log raw response to help troubleshooting
      debugPrint('selectAll(location) response: $res');

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
          // single object → wrap
          items = [decoded];
        }
      } else {
        return [];
      }

      return items
          .map((e) => LocationModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      debugPrint('fetchAllLocations error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<LocationModel?> createLocation(LocationModel model) async {
    try {
      final res = await _api.insertLocation(
        appid,
        model.name,
        model.address ?? '',
        model.latitude.toString(),
        model.longtitude.toString(),
        model.radius.toString(),
        model.ssid.join(','),
        model.bssid.join(','),
        model.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        model.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      );
      // Log raw insert response for debugging
      debugPrint('insertLocation response: ${res?.toString()}');
      // If API didn't persist, return null so UI doesn't show a local-only item
      if (res == null || res == '[]') return null;
      // Optionally parse returned object here to get server-side id
      try {
        final parsed = jsonDecode(res);
        if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
          final map = Map<String, dynamic>.from(parsed.first);
          // Merge server-generated id if present
          final serverId = map['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            return model.copyWith().copyWith();
          }
        }
      } catch (_) {
        // ignore parse errors
      }

      return model;
    } catch (e) {
      debugPrint('createLocation error: $e');
      return null;
    }
  }

  Future<bool> updateLocation(LocationModel model) async {
    try {
      await _api.updateId(
        'name',
        model.name,
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'address',
        model.address ?? '',
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'latitude',
        model.latitude.toString(),
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'longtitude',
        model.longtitude.toString(),
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'radius',
        model.radius.toString(),
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'ssid',
        model.ssid.join(','),
        token,
        project,
        'location',
        appid,
        model.id,
      );
      await _api.updateId(
        'bssid',
        model.bssid.join(','),
        token,
        project,
        'location',
        appid,
        model.id,
      );
      return true;
    } catch (e) {
      debugPrint('updateLocation error: $e');
      return false;
    }
  }

  Future<bool> deleteLocation(String id) async {
    try {
      final removed = await _api.removeId(
        token,
        project,
        'location',
        appid,
        id,
      );
      return removed == true;
    } catch (e) {
      debugPrint('deleteLocation error: $e');
      return false;
    }
  }
}
