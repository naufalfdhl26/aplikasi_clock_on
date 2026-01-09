import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../config.dart';

class UploadService {
  // Test koneksi ke server
  Future<bool> testConnection() async {
    try {
      print('Testing connection to server...');
      final uri = Uri.parse('https://clockon.247go.app/api/');
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection timeout after 5 seconds');
            },
          );
      print('Connection test SUCCESS: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 500;
    } on SocketException catch (e) {
      print('Connection test FAILED: SocketException - ${e.message}');
      print(
        'Kemungkinan: HP tidak ada koneksi internet atau server tidak bisa diakses',
      );
      return false;
    } on TimeoutException catch (e) {
      print('Connection test FAILED: Timeout - $e');
      return false;
    } catch (e) {
      print('Connection test FAILED: $e');
      return false;
    }
  }

  // Upload XFile (works on web and mobile)
  Future<Map<String, dynamic>?> uploadEmployeeXFile(
    String employeeId,
    XFile xFile,
  ) async {
    if (kIsWeb) {
      // Use html.HttpRequest for web
      final bytes = await xFile.readAsBytes();
      final filename = xFile.name;

      final formData = html.FormData();
      formData.appendBlob('file', html.Blob([bytes]), filename);
      formData.append('token', token);
      formData.append('project', project);
      formData.append('appid', appid);
      formData.append('id', employeeId);

      final completer = Completer<Map<String, dynamic>?>();
      final request = html.HttpRequest();
      request.open('POST', baseUrlClockonFileEmployee);
      request.onLoad.listen((event) {
        print('Upload response status: ${request.status}');
        print('Upload response text: ${request.responseText}');
        if (request.status == 200) {
          completer.complete({'raw': request.responseText ?? ''});
        } else {
          completer.completeError(
            Exception(
              'File upload failed: ${request.status} - ${request.responseText}',
            ),
          );
        }
      });
      request.onError.listen((event) {
        print('Upload network error: ${request.status}');
        completer.completeError(
          Exception('File upload failed: Network error - ${request.status}'),
        );
      });
      request.onTimeout.listen((event) {
        completer.completeError(Exception('File upload failed: Timeout'));
      });
      request.timeout = 30000; // 30 seconds timeout
      print('Starting upload to: $baseUrlClockonFileEmployee');
      print('File size: ${bytes.length} bytes');
      print('Filename: $filename');
      request.send(formData);
      return completer.future;
    } else {
      // Use http.MultipartRequest for mobile
      try {
        final uri = Uri.parse(baseUrlClockonFileEmployee);
        print('Uploading to: $uri');

        final req = http.MultipartRequest('POST', uri);
        req.fields['token'] = token;
        req.fields['project'] = project;
        req.fields['appid'] = appid;
        req.fields['id'] = employeeId;

        final bytes = await xFile.readAsBytes();
        final filename = xFile.name;
        print('File size: ${bytes.length} bytes');

        req.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );

        final streamed = await req.send();
        print('Response status: ${streamed.statusCode}');
        final resp = await http.Response.fromStream(streamed);
        print('Response body: ${resp.body}');

        if (resp.statusCode == 200) {
          return {'raw': resp.body};
        }
        throw Exception(
          'File upload failed: ${resp.statusCode} - ${resp.body}',
        );
      } catch (e) {
        print('Upload error: $e');
        if (e.toString().contains('Failed host lookup')) {
          throw Exception(
            'Tidak ada koneksi internet. Pastikan HP terhubung ke WiFi/Data.',
          );
        }
        rethrow;
      }
    }
  }

  // Upload a file for employee; returns API response or throws.
  Future<Map<String, dynamic>?> uploadEmployeeFile(
    String employeeId,
    File file,
  ) async {
    final uri = Uri.parse(baseUrlClockonFileEmployee);
    final req = http.MultipartRequest('POST', uri);
    req.fields['token'] = token;
    req.fields['project'] = project;
    req.fields['appid'] = appid;
    req.fields['id'] = employeeId;
    final filename = path.basename(file.path);
    req.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: filename),
    );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      // The API may return JSON with file URL information
      try {
        return {'raw': resp.body};
      } catch (e) {
        return {'raw': resp.body};
      }
    }
    throw Exception('File upload failed: ${resp.statusCode}');
  }

  // Upload XFile for admin (works on web and mobile)
  Future<Map<String, dynamic>?> uploadAdminXFile(
    String adminId,
    XFile xFile,
  ) async {
    if (kIsWeb) {
      // Use html.HttpRequest for web
      final bytes = await xFile.readAsBytes();
      final filename = xFile.name;

      final formData = html.FormData();
      formData.appendBlob('file', html.Blob([bytes]), filename);
      formData.append('token', token);
      formData.append('project', project);
      formData.append('appid', appid);
      formData.append('id', adminId);

      final completer = Completer<Map<String, dynamic>?>();
      final request = html.HttpRequest();
      request.open('POST', baseUrlClockonFileAdmin);
      request.onLoad.listen((event) {
        if (request.status == 200) {
          completer.complete({'raw': request.responseText ?? ''});
        } else {
          completer.completeError(
            Exception(
              'File upload failed: ${request.status} - ${request.responseText}',
            ),
          );
        }
      });
      request.onError.listen((event) {
        completer.completeError(
          Exception('File upload failed: Network error - ${request.status}'),
        );
      });
      request.onTimeout.listen((event) {
        completer.completeError(Exception('File upload failed: Timeout'));
      });
      request.timeout = 30000; // 30 seconds timeout
      request.send(formData);
      return completer.future;
    } else {
      // Use http.MultipartRequest for mobile
      final uri = Uri.parse(baseUrlClockonFileAdmin);
      final req = http.MultipartRequest('POST', uri);
      req.fields['token'] = token;
      req.fields['project'] = project;
      req.fields['appid'] = appid;
      req.fields['id'] = adminId;

      final bytes = await xFile.readAsBytes();
      final filename = xFile.name;

      req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        return {'raw': resp.body};
      }
      throw Exception('File upload failed: ${resp.statusCode}');
    }
  }

  // Upload a file for admin; returns API response or throws.
  Future<Map<String, dynamic>?> uploadAdminFile(
    String adminId,
    File file,
  ) async {
    final uri = Uri.parse(baseUrlClockonFileAdmin);
    final req = http.MultipartRequest('POST', uri);
    req.fields['token'] = token;
    req.fields['project'] = project;
    req.fields['appid'] = appid;
    req.fields['id'] = adminId;
    final filename = path.basename(file.path);
    req.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: filename),
    );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      try {
        return {'raw': resp.body};
      } catch (e) {
        return {'raw': resp.body};
      }
    }
    throw Exception('File upload failed: ${resp.statusCode}');
  }
}
