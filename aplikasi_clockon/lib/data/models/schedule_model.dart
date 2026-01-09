import 'dart:convert';

// ScheduleModel: Represents employee shift assignments for a date range
// Maps: employeeId → { date (yyyy-MM-dd) → shiftCode }
class ScheduleModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final Map<String, String> assignments; // date -> shiftCode
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.assignments = const {},
    this.status = 'Aktif',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    final raw = map['assignments'] ?? map['assignment'] ?? map['days'] ?? {};
    final assignments = <String, String>{};
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            assignments[k.toString()] = v.toString();
          });
        }
      } catch (_) {
        // ignore parse errors, leave assignments empty
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        assignments[k.toString()] = v.toString();
      });
    }

    return ScheduleModel(
      id: _asString(map['id'] ?? map['_id']) ?? '',
      employeeId:
          _asString(
            map['employeeId'] ?? map['employee_id'] ?? map['employees'],
          ) ??
          '',
      employeeName:
          _asString(
            map['employeeName'] ?? map['employee_name'] ?? map['nama'],
          ) ??
          '',
      assignments: assignments,
      status: _asString(map['status']) ?? 'Aktif',
      createdAt: _parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: _parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) =>
      ScheduleModel.fromMap(json);

  Map<String, dynamic> toMap() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'assignments': assignments,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toJson() => toMap();

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return DateTime.now();
  }

  ScheduleModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    Map<String, String>? assignments,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      assignments: assignments ?? this.assignments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
