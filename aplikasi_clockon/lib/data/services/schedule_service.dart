import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../restapi.dart';
import '../../config.dart';
import '../models/schedule_model.dart';

enum _OperationType { create, update, delete }

class _ScheduleOperation {
  final String operationId;
  final _OperationType type;
  final ScheduleModel? model;
  final String? id;
  final Map<String, dynamic>? updates;

  _ScheduleOperation({
    required this.operationId,
    required this.type,
    this.model,
    this.id,
    this.updates,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'type': type.toString(),
      'model': model?.toJson(),
      'id': id,
      'updates': updates,
    };
  }

  factory _ScheduleOperation.fromJson(Map<String, dynamic> json) {
    return _ScheduleOperation(
      operationId: json['operationId'],
      type: _OperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      model: json['model'] != null
          ? ScheduleModel.fromJson(json['model'])
          : null,
      id: json['id'],
      updates: json['updates'],
    );
  }
}

class ScheduleService {
  final DataService _api = DataService();

  // Queue to prevent race conditions
  final _operationQueue = StreamController<_ScheduleOperation>.broadcast();
  final _pendingOperations = <String, Completer<bool>>{};

  // Offline cache for failed operations
  static const String _PENDING_OPERATIONS_KEY = 'pending_schedule_operations';

  ScheduleService() {
    _initializeQueueProcessor();
  }

  void _initializeQueueProcessor() {
    _operationQueue.stream.asyncMap(_processOperation).listen((result) {
      // Handle completed operations
    });
  }

  Future<bool> _processOperation(_ScheduleOperation operation) async {
    try {
      bool result = false;

      switch (operation.type) {
        case _OperationType.create:
          result = await _executeCreateSchedule(operation.model!);
          break;
        case _OperationType.update:
          result = await _executeUpdateSchedule(
            operation.id!,
            operation.updates!,
          );
          break;
        case _OperationType.delete:
          result = await _executeDeleteSchedule(operation.id!);
          break;
      }

      // Complete the pending operation
      final completer = _pendingOperations[operation.operationId];
      if (completer != null) {
        completer.complete(result);
        _pendingOperations.remove(operation.operationId);
      }

      // If operation failed, save to offline cache
      if (!result) {
        await _saveToOfflineCache(operation);
      }

      return result;
    } catch (e) {
      debugPrint('Operation processing error: $e');
      return false;
    }
  }

  Future<bool> _executeCreateSchedule(ScheduleModel model) async {
    const int maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint(
          '=== createSchedule Debug - Attempt ${retryCount + 1}/$maxRetries ===',
        );

        // Validate input data
        if (model.employeeId.isEmpty || model.employeeName.isEmpty) {
          debugPrint('createSchedule FAILED: Invalid employee data');
          return false;
        }

        // Ensure assignments are properly formatted
        final validatedAssignments = _validateAndNormalizeAssignments(
          model.assignments,
        );

        // Calculate start and end dates from assignments
        String startTime = model.createdAt.toIso8601String();
        String endTime = model.updatedAt.toIso8601String();

        if (validatedAssignments.isNotEmpty) {
          final dates = validatedAssignments.keys
              .map((dateStr) {
                try {
                  return DateTime.parse(dateStr);
                } catch (_) {
                  return null;
                }
              })
              .where((date) => date != null)
              .cast<DateTime>()
              .toList();

          if (dates.isNotEmpty) {
            dates.sort();
            startTime = DateFormat('yyyy-MM-dd').format(dates.first);
            endTime = DateFormat('yyyy-MM-dd').format(dates.last);
          }
        }

        // insertSchedule expects: appid, name, startTime, endTime, days, employees, status, createdat
        final res = await _api
            .insertSchedule(
              appid,
              model.employeeName,
              startTime,
              endTime,
              jsonEncode(validatedAssignments),
              model.employeeId,
              model.status,
              model.createdAt.toIso8601String(),
            )
            .timeout(const Duration(seconds: 30));

        debugPrint('insertSchedule response: $res');

        if (res == null) {
          debugPrint('insertSchedule returned null');
          throw Exception('API returned null response');
        }

        // Enhanced success detection
        final success = _isApiResponseSuccessful(res);
        if (success) {
          debugPrint('createSchedule SUCCESS');
          return true;
        } else {
          debugPrint('createSchedule FAILED: Invalid response format');
          throw Exception('Invalid API response format');
        }
      } catch (e) {
        retryCount++;
        debugPrint('createSchedule - Exception on attempt $retryCount: $e');

        if (retryCount >= maxRetries) {
          debugPrint('createSchedule - All $maxRetries retries failed');
          return false;
        }

        // Exponential backoff with jitter
        final baseDelay = 500 * math.pow(2, retryCount - 1);
        final jitter = math.Random().nextInt(100);
        final delayMs = (baseDelay + jitter).toInt();
        debugPrint('createSchedule - Retrying after ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }

  Future<bool> _executeUpdateSchedule(
    String id,
    Map<String, dynamic> updates,
  ) async {
    const int maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint(
          '=== updateSchedule Debug - Attempt ${retryCount + 1}/$maxRetries ===',
        );

        // Validate schedule ID
        if (id.isEmpty) {
          debugPrint('updateSchedule FAILED: Invalid schedule ID');
          return false;
        }

        for (final entry in updates.entries) {
          // Map 'assignments' to 'days' for backend compatibility
          String fieldToUse = entry.key;
          if (entry.key == 'assignments') {
            fieldToUse = 'days';
          }

          // Validate and encode value
          String valueStr = _encodeFieldValue(entry.value);

          debugPrint(
            'Updating field: $fieldToUse with value: ${valueStr.substring(0, math.min(100, valueStr.length))}...',
          );

          final success = await _api
              .updateId(
                fieldToUse,
                valueStr,
                token,
                project,
                'schedule',
                appid,
                id,
              )
              .timeout(const Duration(seconds: 45));

          if (!success) {
            debugPrint('Failed to update field: $fieldToUse');
            throw Exception('Failed to update field: $fieldToUse');
          }

          debugPrint('Successfully updated field: $fieldToUse');
        }

        debugPrint('updateSchedule completed successfully');
        return true;
      } catch (e) {
        retryCount++;
        debugPrint('updateSchedule - Exception on attempt $retryCount: $e');
        debugPrint('Exception type: ${e.runtimeType}');

        // Check if it's a network error
        bool isNetworkError =
            e.toString().contains('Failed to fetch') ||
            e.toString().contains('Network') ||
            e.toString().contains('timeout') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('SocketException');

        if (isNetworkError) {
          debugPrint('Network error detected, will retry with longer delay');
        }

        if (retryCount >= maxRetries) {
          debugPrint('updateSchedule - All $maxRetries retries failed');
          return false;
        }

        // Exponential backoff with jitter (longer delays for network errors)
        final baseDelay = isNetworkError
            ? 4000 * math.pow(2, retryCount - 1)
            : // Network errors: 4s, 8s, 16s, 32s
              1000 *
                  math.pow(2, retryCount - 1); // Other errors: 1s, 2s, 4s, 8s

        final jitter = math.Random().nextInt(isNetworkError ? 1000 : 200);
        final delayMs = (baseDelay + jitter).toInt();
        debugPrint('updateSchedule - Retrying after ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }

  Future<bool> _executeDeleteSchedule(String id) async {
    try {
      debugPrint('=== deleteSchedule Debug ===');
      debugPrint('Schedule ID: $id');

      if (id.isEmpty) {
        debugPrint('deleteSchedule FAILED: Invalid schedule ID');
        return false;
      }

      await _api
          .removeId(token, project, 'schedule', appid, id)
          .timeout(const Duration(seconds: 15));

      debugPrint('deleteSchedule completed successfully');
      return true;
    } catch (e) {
      debugPrint('deleteSchedule error: $e');
      return false;
    }
  }

  Map<String, String> _validateAndNormalizeAssignments(dynamic rawAssignments) {
    try {
      if (rawAssignments == null) return {};

      Map<String, String> assignments = {};

      if (rawAssignments is Map) {
        assignments = rawAssignments.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      } else if (rawAssignments is String) {
        try {
          final parsed = jsonDecode(rawAssignments);
          if (parsed is Map) {
            assignments = parsed.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
        } catch (_) {}
      }

      // Validate date formats and normalize
      final normalized = <String, String>{};
      for (final entry in assignments.entries) {
        var dateKey = entry.key;
        final value = entry.value.trim();

        if (value.isEmpty) continue;

        // Try to parse and normalize date
        try {
          final date = DateTime.parse(dateKey);
          dateKey = DateFormat('yyyy-MM-dd').format(date);
        } catch (_) {
          // Keep original if not parseable
        }

        normalized[dateKey] = value;
      }

      return normalized;
    } catch (e) {
      debugPrint('Error validating assignments: $e');
      return {};
    }
  }

  String _encodeFieldValue(dynamic value) {
    try {
      if (value is Map || value is List) {
        return jsonEncode(value);
      } else {
        return value.toString();
      }
    } catch (e) {
      debugPrint('Error encoding field value: $e');
      return value.toString();
    }
  }

  bool _isApiResponseSuccessful(String response) {
    try {
      final parsed = jsonDecode(response);

      if (parsed is List) {
        return parsed.isNotEmpty;
      }

      if (parsed is Map) {
        // Check for common success indicators
        if (parsed.containsKey('_id') &&
            parsed['_id'] != null &&
            parsed['_id'].toString().isNotEmpty) {
          return true;
        }
        if (parsed.containsKey('id') &&
            parsed['id'] != null &&
            parsed['id'].toString().isNotEmpty) {
          return true;
        }
        if (parsed.containsKey('success') && parsed['success'] == true) {
          return true;
        }
        if (parsed.containsKey('status') &&
            parsed['status'].toString().toLowerCase() == 'success') {
          return true;
        }

        // Non-empty map as fallback
        return parsed.isNotEmpty;
      }

      // String response - check if not empty and not '[]'
      return response.isNotEmpty && response != '[]';
    } catch (_) {
      // Not JSON - treat as success if not empty and not '[]'
      return response.isNotEmpty && response != '[]';
    }
  }

  Future<void> _saveToOfflineCache(_ScheduleOperation operation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingOps = prefs.getStringList(_PENDING_OPERATIONS_KEY) ?? [];

      final operationData = jsonEncode({
        'id': operation.operationId,
        'type': operation.type.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'data': operation.toJson(),
      });

      pendingOps.add(operationData);
      await prefs.setStringList(_PENDING_OPERATIONS_KEY, pendingOps);

      debugPrint(
        'Saved failed operation to offline cache: ${operation.operationId}',
      );
    } catch (e) {
      debugPrint('Error saving to offline cache: $e');
    }
  }

  Future<void> syncOfflineOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingOps = prefs.getStringList(_PENDING_OPERATIONS_KEY) ?? [];

      if (pendingOps.isEmpty) return;

      debugPrint('Syncing ${pendingOps.length} offline operations...');

      final successfulOps = <String>[];

      for (final opData in pendingOps) {
        try {
          final parsed = jsonDecode(opData);
          final operation = _ScheduleOperation.fromJson(parsed['data']);

          final success = await _processOperation(operation);
          if (success) {
            successfulOps.add(parsed['id']);
          }
        } catch (e) {
          debugPrint('Error processing offline operation: $e');
        }
      }

      // Remove successful operations from cache
      if (successfulOps.isNotEmpty) {
        final remainingOps = pendingOps.where((op) {
          try {
            final parsed = jsonDecode(op);
            return !successfulOps.contains(parsed['id']);
          } catch (_) {
            return true; // Keep if can't parse
          }
        }).toList();

        await prefs.setStringList(_PENDING_OPERATIONS_KEY, remainingOps);
        debugPrint(
          'Synced ${successfulOps.length} operations, ${remainingOps.length} remaining',
        );
      }
    } catch (e) {
      debugPrint('Error syncing offline operations: $e');
    }
  }

  Future<List<ScheduleModel>> fetchAllSchedules() async {
    try {
      final res = await _api.selectAll(token, project, 'schedule', appid);
      if (res == null) return [];

      debugPrint('selectAll(schedule) response: $res');

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
        var data = decoded['data'];
        // sometimes API wraps the data as a JSON string
        if (data is String) {
          try {
            final parsed = jsonDecode(data);
            data = parsed;
          } catch (_) {}
        }
        items = data is List ? data : (data == null ? [] : [data]);
      } else if (decoded is Map) {
        items = [decoded];
      }

      final out = <ScheduleModel>[];
      for (final e in items) {
        try {
          if (e is String) {
            final parsed = jsonDecode(e);
            if (parsed is Map) {
              out.add(ScheduleModel.fromMap(Map<String, dynamic>.from(parsed)));
            }
          } else if (e is Map) {
            out.add(ScheduleModel.fromMap(Map<String, dynamic>.from(e)));
          }
        } catch (ex) {
          debugPrint('skip invalid schedule item: $ex');
        }
      }
      return out;
    } catch (e, st) {
      debugPrint('fetchAllSchedules error: $e');
      debugPrint(st.toString());
      return [];
    }
  }

  Future<bool> createSchedule(ScheduleModel model) async {
    // Retry logic with exponential backoff - 5 attempts
    const int maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint(
          '=== createSchedule Debug - Attempt ${retryCount + 1}/$maxRetries ===',
        );
        debugPrint('Employee ID: ${model.employeeId}');
        debugPrint('Employee Name: ${model.employeeName}');
        debugPrint('Assignments: ${model.assignments}');
        debugPrint('Status: ${model.status}');

        // Calculate start and end dates from assignments
        String startTime = model.createdAt.toIso8601String();
        String endTime = model.updatedAt.toIso8601String();

        if (model.assignments.isNotEmpty) {
          final dates = model.assignments.keys
              .map((dateStr) {
                try {
                  return DateTime.parse(dateStr);
                } catch (_) {
                  return null;
                }
              })
              .where((date) => date != null)
              .cast<DateTime>()
              .toList();

          if (dates.isNotEmpty) {
            dates.sort();
            startTime = DateFormat('yyyy-MM-dd').format(dates.first);
            endTime = DateFormat('yyyy-MM-dd').format(dates.last);
          }
        }

        // insertSchedule expects: appid, name, startTime, endTime, days, employees, status, createdat
        // For new employee-assignment model, map fields appropriately
        final res = await _api.insertSchedule(
          appid,
          model.employeeName,
          startTime,
          endTime,
          jsonEncode(model.assignments), // days -> assignments JSON
          model.employeeId, // employees -> employeeId
          model.status,
          model.createdAt.toIso8601String(),
        );
        debugPrint('insertSchedule response: $res');

        if (res == null) {
          debugPrint('insertSchedule returned null');
          return false;
        }

        // API sometimes returns '[]' or JSON string. Try parsing to detect success.
        try {
          final parsed = jsonDecode(res);
          if (parsed is List) {
            // non-empty list -> success
            if (parsed.isNotEmpty) {
              debugPrint('createSchedule SUCCESS: Non-empty list response');
              return true;
            }
          }
          if (parsed is Map) {
            // common success shapes: {"_id": "..."} or {"id": "..."} or {"success": true}
            if ((parsed['_id'] != null &&
                    parsed['_id'].toString().isNotEmpty) ||
                (parsed['id'] != null && parsed['id'].toString().isNotEmpty) ||
                (parsed['success'] == true)) {
              debugPrint('createSchedule SUCCESS: Valid response map');
              return true;
            }
            // fallback: non-empty map
            if (parsed.isNotEmpty) {
              debugPrint('createSchedule SUCCESS: Non-empty map response');
              return true;
            }
          }
        } catch (_) {
          // not JSON — fall through to string check
        }

        // final fallback: any non-empty non-'[]' response considered success
        final resStr = res.toString();
        if (resStr.isNotEmpty && resStr != '[]') {
          debugPrint('createSchedule SUCCESS: Non-empty string response');
          return true;
        }

        // If we get here, response was empty or '[]' - consider it a failure
        debugPrint('createSchedule FAILED: Empty or invalid response');
        return false;
      } catch (e, st) {
        retryCount++;
        debugPrint('createSchedule - Exception on attempt $retryCount: $e');
        debugPrint('createSchedule - Exception type: ${e.runtimeType}');
        debugPrint('createSchedule - Stacktrace: $st');

        if (retryCount >= maxRetries) {
          debugPrint('createSchedule - All $maxRetries retries failed');
          return false;
        }

        // Exponential backoff: 500ms, 1s, 2s, 4s, 8s
        final delayMs = (500 * math.pow(2, retryCount - 1)).toInt();
        debugPrint('createSchedule - Retrying after ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }

  Future<bool> updateSchedule(String id, Map<String, dynamic> updates) async {
    // Use queue system to prevent concurrent API calls
    final operationId = 'update_${id}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<bool>();
    _pendingOperations[operationId] = completer;

    final operation = _ScheduleOperation(
      operationId: operationId,
      type: _OperationType.update,
      id: id,
      updates: updates,
    );

    _operationQueue.add(operation);

    return completer.future;
  }

  Future<bool> deleteSchedule(String id) async {
    try {
      await _api.removeId(token, project, 'schedule', appid, id);
      return true;
    } catch (e) {
      debugPrint('deleteSchedule error: $e');
      return false;
    }
  }

  Future<ScheduleModel?> fetchScheduleByEmployeeId(String employeeId) async {
    try {
      debugPrint('=== fetchScheduleByEmployeeId Debug ===');
      debugPrint('Employee ID: $employeeId');

      // Fetch all schedules and filter client-side to ensure correct employee
      final allSchedules = await fetchAllSchedules();
      debugPrint(
        'Fetched ${allSchedules.length} schedules, filtering for employeeId: $employeeId',
      );

      // Find the schedule with matching employeeId
      ScheduleModel? matchingSchedule;
      try {
        matchingSchedule = allSchedules.firstWhere(
          (schedule) => schedule.employeeId == employeeId,
        );
      } catch (e) {
        // No matching schedule found
        matchingSchedule = null;
      }

      if (matchingSchedule != null) {
        debugPrint(
          'Found matching schedule: ${matchingSchedule.id} for employee: ${matchingSchedule.employeeName}',
        );
        return matchingSchedule;
      } else {
        debugPrint('No schedule found for employeeId: $employeeId');
        return null;
      }
    } catch (e, st) {
      debugPrint('fetchScheduleByEmployeeId error: $e');
      debugPrint(st.toString());
      return null;
    }
  }
}
