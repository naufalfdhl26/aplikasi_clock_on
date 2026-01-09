class PermissionModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final String? employeeDivision;
  final String? employeeAvatarPath;
  final String type;
  final String reason;
  final DateTime leaveDate;
  final String? scheduleId; // ID of the employee's schedule record
  final String? shiftId; // ID of the shift record
  final String status;
  final String? adminId;
  final String? adminEmail;
  final DateTime? processedAt;
  final DateTime createdAt;

  PermissionModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    this.employeeDivision,
    this.employeeAvatarPath,
    required this.type,
    required this.reason,
    required this.leaveDate,
    this.scheduleId,
    this.shiftId,
    this.status = 'pending',
    this.adminId,
    this.adminEmail,
    this.processedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PermissionModel.fromJson(Map<String, dynamic> json) =>
      PermissionModel.fromMap(Map<String, dynamic>.from(json));

  factory PermissionModel.fromMap(Map<String, dynamic> map) {
    return PermissionModel(
      id: _asString(map['id'] ?? map['_id']) ?? '',
      employeeId: _asString(map['employeeId'] ?? map['employee_id']) ?? '',
      employeeName:
          _asString(map['employeeName'] ?? map['employee_name']) ?? '',
      employeeEmail:
          _asString(map['employeeEmail'] ?? map['employee_email']) ?? '',
      employeeDivision: _asString(
        map['employeeDivision'] ?? map['employee_division'],
      ),
      employeeAvatarPath: _asString(
        map['employeeAvatarPath'] ?? map['employee_avatar_path'],
      ),
      type: _asString(map['type']) ?? '',
      reason: _asString(map['reason']) ?? '',
      leaveDate:
          _parseDate(map['leaveDate'] ?? map['leave_date']) ?? DateTime.now(),
      scheduleId: _asString(map['scheduleId'] ?? map['schedule_id']),
      shiftId: _asString(map['shiftId'] ?? map['shift_id']),
      status: _asString(map['status']) ?? 'pending',
      adminId: _asString(map['adminId'] ?? map['admin_id']),
      adminEmail: _asString(map['adminEmail'] ?? map['admin_email']),
      processedAt: _parseDate(map['processedAt'] ?? map['processed_at']),
      createdAt:
          _parseDate(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
    );
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'employeeEmail': employeeEmail,
    'employeeDivision': employeeDivision,
    'employeeAvatarPath': employeeAvatarPath,
    'type': type,
    'reason': reason,
    'leaveDate': leaveDate.toIso8601String(),
    'scheduleId': scheduleId,
    'shiftId': shiftId,
    'status': status,
    'adminId': adminId,
    'adminEmail': adminEmail,
    'processedAt': processedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
