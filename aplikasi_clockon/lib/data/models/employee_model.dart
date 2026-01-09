class EmployeeModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String division;
  final String? locationId;
  final String? position;
  final bool isActive;
  final String? scheduleId;
  final String? createdByAdminId;
  final String? createdByAdminEmail;
  final DateTime createdAt;
  final String? photo;
  final String? phone;
  final String? avatarPath; // avatar path karyawan

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.division,
    this.locationId,
    this.position,
    this.scheduleId,
    this.createdByAdminId,
    this.createdByAdminEmail,
    this.isActive = true,
    required this.password,
    DateTime? createdAt,
    this.photo,
    this.phone,
    this.avatarPath,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EmployeeModel.fromJson(Map<String, dynamic> json) =>
      EmployeeModel.fromMap(Map<String, dynamic>.from(json));

  /// Backwards compatible factory that accepts a map (like other models)
  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: _asString(map['id'] ?? map['_id']) ?? '',
      name: _asString(map['name'] ?? map['nama']) ?? '',
      email: _asString(map['email']) ?? '',
      division: _asString(map['division'] ?? map['divisi']) ?? '',
      locationId: _asString(
        map['locationId'] ?? map['lokasi'] ?? map['location_id'],
      ),
      position: _asString(map['position'] ?? map['posisi']),
      createdByAdminId: _asString(
        map['createdByAdminId'] ??
            map['createdby'] ??
            map['created_by'] ??
            map['adminid'],
      ),
      createdByAdminEmail: _asString(
        map['createdByAdminEmail'] ??
            map['createdby_email'] ??
            map['createdby'],
      ),
      scheduleId: _asString(map['scheduleId'] ?? map['schedule_id']),
      isActive: _parseBool(
        map['isActive'] ?? map['isactive'] ?? map['is_active'] ?? true,
      ),
      password: _asString(map['password']) ?? '',
      createdAt: _parseDate(
        map['createdAt'] ?? map['created_at'] ?? map['createdat'],
      ),
      photo: _asString(map['photo']),
      phone: _asString(map['phone']),
      avatarPath: _asString(map['avatarPath'] ?? map['avatar_path']),
    );
  }

  // Helper: safe string conversion
  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  // Helper: safe bool parsing
  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    if (v is int) return v == 1;
    return false;
  }

  // Helper: safe date parsing
  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'division': division,
    // write canonical `locationId`; keep legacy `lokasi` for compatibility
    'locationId': locationId,
    'lokasi': locationId,
    'position': position,
    'scheduleId': scheduleId,
    'isActive': isActive,
    'createdByAdminId': createdByAdminId,
    'createdByAdminEmail': createdByAdminEmail,
    'createdAt': createdAt.toIso8601String(),
    'photo': photo,
    'phone': phone,
    'avatarPath': avatarPath,
  };
}
