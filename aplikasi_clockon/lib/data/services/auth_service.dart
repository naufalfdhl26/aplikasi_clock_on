import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../restapi.dart';
import '../../config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DataService _api = DataService();

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Fetch employee record from GoCloud API by email
  Future<Map<String, dynamic>?> fetchEmployeeByEmail(String email) async {
    try {
      final response = await _api.selectWhere(
        token,
        project,
        'employee',
        appid,
        'email',
        email,
      );
      if (response == null) return null;
      debugPrint('selectWhere(employee,email=$email) response: $response');

      dynamic decoded;
      try {
        decoded = jsonDecode(response);
      } catch (e) {
        debugPrint('fetchEmployeeByEmail JSON decode error: $e');
        return null;
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

      if (items.isEmpty) return null;
      final item = Map<String, dynamic>.from(items[0] as Map);
      // Normalize id field: backend may return 'id' or '_id'
      if (item['id'] == null && item['_id'] != null) {
        item['id'] = item['_id']?.toString();
      }
      return item;
    } catch (e) {
      debugPrint('fetchEmployeeByEmail error: $e');
      return null;
    }
  }

  // Fetch admin record from GoCloud API by email
  Future<Map<String, dynamic>?> fetchAdminByEmail(String email) async {
    try {
      final response = await _api.selectWhere(
        token,
        project,
        'admin',
        appid,
        'email',
        email,
      );
      if (response == null) return null;
      debugPrint('selectWhere(admin,email=$email) response: $response');

      dynamic decoded;
      try {
        decoded = jsonDecode(response);
      } catch (e) {
        debugPrint('fetchAdminByEmail JSON decode error: $e');
        return null;
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

      if (items.isEmpty) return null;
      final item = Map<String, dynamic>.from(items[0] as Map);
      // Normalize id field: backend may return 'id' or '_id'
      if (item['id'] == null && item['_id'] != null) {
        item['id'] = item['_id']?.toString();
      }
      return item;
    } catch (e) {
      debugPrint('fetchAdminByEmail error: $e');
      return null;
    }
  }
}
