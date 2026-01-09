// ignore_for_file: prefer_interpolation_to_compose_strings, non_constant_identifier_names

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:async';

class DataService {
  Future insertAdmin(
    String appid,
    String name,
    String email,
    String password,
    String companyname,
    String createdat,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'admin',
          'appid': appid,
          'name': name,
          'email': email,
          'password': password,
          'companyname': companyname,
          'createdat': createdat,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future insertAttendance(
    String appid,
    String employeeid,
    String date,
    String checkin,
    String checkout,
    String status,
    String wifissid,
    String wifibssid,
    String approved,
    String createdat,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'attendance',
          'appid': appid,
          'employeeid': employeeid,
          'date': date,
          'checkin': checkin,
          'checkout': checkout,
          'status': status,
          'wifissid': wifissid,
          'wifibssid': wifibssid,
          'approved': approved,
          'createdat': createdat,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future insertAttendanceSummary(
    String appid,
    String hadir,
    String telat,
    String izin,
    String alpha,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'attendance_summary',
          'appid': appid,
          'hadir': hadir,
          'telat': telat,
          'izin': izin,
          'alpha': alpha,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future insertEmployee(
    String appid,
    String name,
    String email,
    String password,
    String division,
    String locationid,
    String position,
    String isactive,
    String scheduleid,
    String createdat,
    String createdby,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    final body = {
      'token': '693b109f23173f13b93c2060',
      'project': 'clockon',
      'collection': 'employee',
      'appid': appid,
      'name': name,
      'email': email,
      'password': password,
      'division': division,
      'locationid': locationid,
      'position': position,
      'isactive': isactive,
      'scheduleid': scheduleid,
      'createdat': createdat,
    };

    if (createdby.isNotEmpty) {
      body['createdby'] = createdby;
    }

    debugPrint('=== insertEmployee POST Body ===');
    body.forEach((k, v) => debugPrint('  $k: $v'));

    try {
      final response = await http.post(Uri.parse(uri), body: body);

      debugPrint('insertEmployee HTTP Status: ${response.statusCode}');
      debugPrint('insertEmployee Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      debugPrint('insertEmployee error: $e');
      // Print error here
      return '[]';
    }
  }

  Future insertLocation(
    String appid,
    String name,
    String address,
    String latitude,
    String longtitude,
    String radius,
    String ssid,
    String bssid,
    String createdat,
    String updateat,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'location',
          'appid': appid,
          'name': name,
          'address': address,
          'latitude': latitude,
          'longtitude': longtitude,
          'radius': radius,
          'ssid': ssid,
          'bssid': bssid,
          'createdat': createdat,
          'updateat': updateat,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future insertPermission(
    String appid,
    String permissionId,
    String employeeId,
    String employeeName,
    String employeeEmail,
    String employeeDivision,
    String employeeAvatarPath,
    String type,
    String reason,
    String leaveDate,
    String shiftId,
    String shiftLabel,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'permission',
          'appid': appid,
          'id': permissionId,
          'employeeId': employeeId,
          'employeeName': employeeName,
          'employeeEmail': employeeEmail,
          'employeeDivision': employeeDivision,
          'employeeAvatarPath': employeeAvatarPath,
          'type': type,
          'reason': reason,
          'leaveDate': leaveDate,
          'shiftId': shiftId,
          'shiftLabel': shiftLabel,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future insertDivision(
    String appid,
    String name,
    String createdat,
    String updateat,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    try {
      final response = await http.post(
        Uri.parse(uri),
        body: {
          'token': '693b109f23173f13b93c2060',
          'project': 'clockon',
          'collection': 'division',
          'appid': appid,
          'name': name,
          'createdat': createdat,
          'updateat': updateat,
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        return '[]';
      }
    } catch (e) {
      return '[]';
    }
  }

  Future insertSchedule(
    String appid,
    String name,
    String startTime,
    String endTime,
    String days,
    String employees,
    String status,
    String createdat,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    final body = {
      'token': '693b109f23173f13b93c2060',
      'project': 'clockon',
      'collection': 'schedule',
      'appid': appid,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'days': days,
      'employees': employees,
      'status': status,
      'createdat': createdat,
    };

    debugPrint('=== insertSchedule POST Body ===');
    body.forEach((key, value) {
      debugPrint('  $key: $value');
    });

    // Retry logic with exponential backoff - 5 attempts
    const int maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint('insertSchedule - Attempt ${retryCount + 1}/$maxRetries');
        debugPrint('insertSchedule - Sending POST request to: $uri');

        final response = await http
            .post(Uri.parse(uri), body: body)
            .timeout(const Duration(seconds: 15));

        debugPrint(
          'insertSchedule - Response status code: ${response.statusCode}',
        );
        debugPrint('insertSchedule - Response body: ${response.body}');

        if (response.statusCode == 200) {
          return response.body;
        } else {
          debugPrint(
            'insertSchedule - Failed with status ${response.statusCode}',
          );
          return '[]';
        }
      } catch (e, s) {
        retryCount++;
        debugPrint('insertSchedule - Exception on attempt $retryCount: $e');
        debugPrint('insertSchedule - Exception type: ${e.runtimeType}');
        debugPrint('insertSchedule - Stacktrace: $s');

        if (retryCount >= maxRetries) {
          debugPrint('insertSchedule - All $maxRetries retries failed');
          return '[]';
        }

        // Exponential backoff: 500ms, 1s, 2s, 4s, 8s
        final delayMs = (500 * math.pow(2, retryCount - 1)).toInt();
        debugPrint('insertSchedule - Retrying after ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return '[]';
  }

  Future insertShift(
    String appid,
    String code,
    String label,
    String startTime,
    String endTime,
    String adminId,
    String? color,
  ) async {
    String uri = 'https://api.247go.app/v5/insert/';

    final body = {
      'token': '693b109f23173f13b93c2060',
      'project': 'clockon',
      'collection': 'shift',
      'appid': appid,
      'code': code,
      'label': label,
      'startTime': startTime,
      'endTime': endTime,
      'createdby': adminId,
    };
    if (color != null && color.isNotEmpty) {
      body['color'] = color;
    }

    debugPrint('=== insertShift POST Body ===');
    body.forEach((key, value) {
      debugPrint('  $key: $value');
    });

    try {
      final response = await http.post(Uri.parse(uri), body: body);

      debugPrint('insertShift HTTP Status: ${response.statusCode}');
      debugPrint('insertShift Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return response.body;
      } else {
        return '[]';
      }
    } catch (e) {
      debugPrint('insertShift error: $e');
      return '[]';
    }
  }

  Future selectAll(
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_all/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectId(
    String token,
    String project,
    String collection,
    String appid,
    String id,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_id/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/id/' +
        id;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectWhere(
    String token,
    String project,
    String collection,
    String appid,
    String where_field,
    String where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/where_field/' +
        Uri.encodeComponent(where_field) +
        '/where_value/' +
        Uri.encodeComponent(where_value);

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectOrWhere(
    String token,
    String project,
    String collection,
    String appid,
    String or_where_field,
    String or_where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_or_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/or_where_field/' +
        or_where_field +
        '/or_where_value/' +
        or_where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectWhereLike(
    String token,
    String project,
    String collection,
    String appid,
    String wlike_field,
    String wlike_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_where_like/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wlike_field/' +
        wlike_field +
        '/wlike_value/' +
        wlike_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectWhereIn(
    String token,
    String project,
    String collection,
    String appid,
    String win_field,
    String win_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_where_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/win_field/' +
        win_field +
        '/win_value/' +
        win_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future selectWhereNotIn(
    String token,
    String project,
    String collection,
    String appid,
    String wnotin_field,
    String wnotin_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/select_where_not_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wnotin_field/' +
        wnotin_field +
        '/wnotin_value/' +
        wnotin_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future removeAll(
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_all/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid;

    try {
      final response = await http.delete(Uri.parse(uri));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Print error here
      return false;
    }
  }

  Future removeId(
    String token,
    String project,
    String collection,
    String appid,
    String id,
  ) async {
    // For web, return false with notice - CORS policy prevents delete operations
    if (kIsWeb) {
      debugPrint(
        'removeId (web) - Delete operation not supported on web platform due to CORS restrictions',
      );
      return false;
    }

    String uri =
        'https://api.247go.app/v5/remove_id/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/id/' +
        id;

    try {
      debugPrint('removeId - Request URI: $uri');

      final response = await http
          .delete(Uri.parse(uri))
          .timeout(const Duration(seconds: 15));

      debugPrint('removeId - Response status: ${response.statusCode}');
      debugPrint('removeId - Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('removeId error: $e');
      return false;
    }
  }

  Future removeWhere(
    String token,
    String project,
    String collection,
    String appid,
    String where_field,
    String where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/where_field/' +
        where_field +
        '/where_value/' +
        where_value;

    try {
      debugPrint('removeWhere - Request URI: $uri');

      final response = kIsWeb
          ? await http
                .post(
                  Uri.parse(uri),
                  headers: {'Content-Type': 'application/json'},
                )
                .timeout(const Duration(seconds: 15))
          : await http
                .delete(Uri.parse(uri))
                .timeout(const Duration(seconds: 15));

      debugPrint('removeWhere - Response status: ${response.statusCode}');
      debugPrint('removeWhere - Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('removeWhere error: $e');
      return false;
    }
  }

  Future removeOrWhere(
    String token,
    String project,
    String collection,
    String appid,
    String or_where_field,
    String or_where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_or_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/or_where_field/' +
        or_where_field +
        '/or_where_value/' +
        or_where_value;

    try {
      final response = await http.delete(Uri.parse(uri));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Print error here
      return false;
    }
  }

  Future removeWhereLike(
    String token,
    String project,
    String collection,
    String appid,
    String wlike_field,
    String wlike_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_where_like/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wlike_field/' +
        wlike_field +
        '/wlike_value/' +
        wlike_value;

    try {
      final response = await http.delete(Uri.parse(uri));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Print error here
      return false;
    }
  }

  Future removeWhereIn(
    String token,
    String project,
    String collection,
    String appid,
    String win_field,
    String win_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_where_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/win_field/' +
        win_field +
        '/win_value/' +
        win_value;

    try {
      final response = await http.delete(Uri.parse(uri));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Print error here
      return false;
    }
  }

  Future removeWhereNotIn(
    String token,
    String project,
    String collection,
    String appid,
    String wnotin_field,
    String wnotin_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/remove_where_not_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wnotin_field/' +
        wnotin_field +
        '/wnotin_value/' +
        wnotin_value;

    try {
      final response = await http.delete(Uri.parse(uri));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Print error here
      return false;
    }
  }

  Future updateAll(
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_all/';

    try {
      final response = await http.put(
        Uri.parse(uri),
        body: {
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future updateId(
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
    String id,
  ) async {
    String uri = 'https://api.247go.app/v5/update_id/id/' + id + '/';

    // Retry logic with exponential backoff - 5 attempts
    const int maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        debugPrint('updateId - Attempt ${retryCount + 1}/$maxRetries');
        debugPrint('updateId - Sending POST request to: $uri');
        debugPrint('  Field: $update_field');
        debugPrint('  Value: $update_value');
        debugPrint('  Collection: $collection, ID: $id');

        final requestBody = {
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
          'id': id,
        };

        debugPrint('updateId - Request body: $requestBody');

        // Use POST on web to avoid PUT CORS/preflight issues in some servers.
        final response =
            await (kIsWeb
                    ? http.post(Uri.parse(uri), body: requestBody)
                    : http.put(Uri.parse(uri), body: requestBody))
                .timeout(const Duration(seconds: 15));

        debugPrint('updateId - Response status code: ${response.statusCode}');
        debugPrint('updateId - Response body: ${response.body}');

        if (response.statusCode == 200) {
          debugPrint('updateId - SUCCESS status 200');
          debugPrint('updateId - Response body (success): ${response.body}');
          // Optional: cek apakah response.body mengandung error tersembunyi
          if (response.body.toLowerCase().contains('error') ||
              response.body.toLowerCase().contains('fail')) {
            debugPrint('updateId - WARNING: Response body contains error/fail');
          }
          return true;
        } else {
          debugPrint('updateId - Failed with status ${response.statusCode}');
          debugPrint('updateId - Response body (fail): ${response.body}');
          return false;
        }
      } catch (e, s) {
        retryCount++;
        debugPrint('updateId - Exception on attempt $retryCount: $e');
        debugPrint('updateId - Exception type: ${e.runtimeType}');
        debugPrint('updateId - Stacktrace: $s');

        // Check if it's a network error and handle differently
        bool isNetworkError =
            e.toString().contains('Failed to fetch') ||
            e.toString().contains('Network') ||
            e.toString().contains('timeout') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('SocketException');

        if (isNetworkError) {
          debugPrint(
            'updateId - Network error detected, will retry with longer delay',
          );
          // For network errors, use longer delay
          final delayMs = (1000 * math.pow(2, retryCount - 1)).toInt();
          debugPrint('updateId - Retrying after ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          // For other errors, use standard delay
          final delayMs = (500 * math.pow(2, retryCount - 1)).toInt();
          debugPrint('updateId - Retrying after ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }

        if (retryCount >= maxRetries) {
          debugPrint('updateId - All $maxRetries retries failed');
          return false;
        }
      }
    }

    return false;
  }

  Future updateWhere(
    String where_field,
    String where_value,
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_where/';

    try {
      final body = {
        'where_field': where_field,
        'where_value': where_value,
        'update_field': update_field,
        'update_value': update_value,
        'token': token,
        'project': project,
        'collection': collection,
        'appid': appid,
      };
      final response = kIsWeb
          ? await http.post(Uri.parse(uri), body: body)
          : await http.put(Uri.parse(uri), body: body);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future updateOrWhere(
    String or_where_field,
    String or_where_value,
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_or_where/';

    try {
      final response = await http.put(
        Uri.parse(uri),
        body: {
          'or_where_field': or_where_field,
          'or_where_value': or_where_value,
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future updateWhereLike(
    String wlike_field,
    String wlike_value,
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_where_like/';

    try {
      final response = await http.put(
        Uri.parse(uri),
        body: {
          'wlike_field': wlike_field,
          'wlike_value': wlike_value,
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future updateWhereIn(
    String win_field,
    String win_value,
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_where_in/';

    try {
      final response = await http.put(
        Uri.parse(uri),
        body: {
          'win_field': win_field,
          'win_value': win_value,
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future updateWhereNotIn(
    String wnotin_field,
    String wnotin_value,
    String update_field,
    String update_value,
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri = 'https://api.247go.app/v5/update_where_not_in/';

    try {
      final response = await http.put(
        Uri.parse(uri),
        body: {
          'wnotin_field': wnotin_field,
          'wnotin_value': wnotin_value,
          'update_field': update_field,
          'update_value': update_value,
          'token': token,
          'project': project,
          'collection': collection,
          'appid': appid,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future firstAll(
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_all/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future firstWhere(
    String token,
    String project,
    String collection,
    String appid,
    String where_field,
    String where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/where_field/' +
        where_field +
        '/where_value/' +
        where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future firstOrWhere(
    String token,
    String project,
    String collection,
    String appid,
    String or_where_field,
    String or_where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_or_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/or_where_field/' +
        or_where_field +
        '/or_where_value/' +
        or_where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future firstWhereLike(
    String token,
    String project,
    String collection,
    String appid,
    String wlike_field,
    String wlike_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_where_like/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wlike_field/' +
        wlike_field +
        '/wlike_value/' +
        wlike_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future firstWhereIn(
    String token,
    String project,
    String collection,
    String appid,
    String win_field,
    String win_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_where_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/win_field/' +
        win_field +
        '/win_value/' +
        win_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future firstWhereNotIn(
    String token,
    String project,
    String collection,
    String appid,
    String wnotin_field,
    String wnotin_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/first_where_not_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wnotin_field/' +
        wnotin_field +
        '/wnotin_value/' +
        wnotin_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastAll(
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_all/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastWhere(
    String token,
    String project,
    String collection,
    String appid,
    String where_field,
    String where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/where_field/' +
        where_field +
        '/where_value/' +
        where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastOrWhere(
    String token,
    String project,
    String collection,
    String appid,
    String or_where_field,
    String or_where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_or_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/or_where_field/' +
        or_where_field +
        '/or_where_value/' +
        or_where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastWhereLike(
    String token,
    String project,
    String collection,
    String appid,
    String wlike_field,
    String wlike_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_where_like/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wlike_field/' +
        wlike_field +
        '/wlike_value/' +
        wlike_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastWhereIn(
    String token,
    String project,
    String collection,
    String appid,
    String win_field,
    String win_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_where_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/win_field/' +
        win_field +
        '/win_value/' +
        win_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future lastWhereNotIn(
    String token,
    String project,
    String collection,
    String appid,
    String wnotin_field,
    String wnotin_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/last_where_not_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wnotin_field/' +
        wnotin_field +
        '/wnotin_value/' +
        wnotin_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomAll(
    String token,
    String project,
    String collection,
    String appid,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_all/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomWhere(
    String token,
    String project,
    String collection,
    String appid,
    String where_field,
    String where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/where_field/' +
        where_field +
        '/where_value/' +
        where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomOrWhere(
    String token,
    String project,
    String collection,
    String appid,
    String or_where_field,
    String or_where_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_or_where/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/or_where_field/' +
        or_where_field +
        '/or_where_value/' +
        or_where_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomWhereLike(
    String token,
    String project,
    String collection,
    String appid,
    String wlike_field,
    String wlike_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_where_like/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wlike_field/' +
        wlike_field +
        '/wlike_value/' +
        wlike_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomWhereIn(
    String token,
    String project,
    String collection,
    String appid,
    String win_field,
    String win_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_where_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/win_field/' +
        win_field +
        '/win_value/' +
        win_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }

  Future randomWhereNotIn(
    String token,
    String project,
    String collection,
    String appid,
    String wnotin_field,
    String wnotin_value,
  ) async {
    String uri =
        'https://api.247go.app/v5/random_where_not_in/token/' +
        token +
        '/project/' +
        project +
        '/collection/' +
        collection +
        '/appid/' +
        appid +
        '/wnotin_field/' +
        wnotin_field +
        '/wnotin_value/' +
        wnotin_value;

    try {
      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Return an empty array
        return '[]';
      }
    } catch (e) {
      // Print error here
      return '[]';
    }
  }
}
