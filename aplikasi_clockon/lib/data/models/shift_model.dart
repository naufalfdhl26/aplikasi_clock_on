// ShiftModel: Represents work shift configurations (master data)
class ShiftModel {
  final String id;
  final String code;
  final String label;
  final DateTime startTime;
  final DateTime endTime;
  final int toleranceMinutes;
  final bool isActive;
  final String? description;
  final String? color;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShiftModel({
    required this.id,
    required this.code,
    required this.label,
    required this.startTime,
    required this.endTime,
    this.toleranceMinutes = 15,
    this.isActive = true,
    this.description,
    this.color,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Duration of the shift, accounts for overnight shifts
  Duration get duration {
    final s = DateTime(
      2000,
      1,
      1,
      startTime.hour,
      startTime.minute,
      startTime.second,
    );
    var e = DateTime(2000, 1, 1, endTime.hour, endTime.minute, endTime.second);
    if (!e.isAfter(s)) {
      // overnight shift, add one day
      e = e.add(const Duration(days: 1));
    }
    return e.difference(s);
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: _asString(map['id'] ?? map['_id']) ?? '',
      code:
          _asString(
            map['code'] ?? map['shiftCode'] ?? map['code_shift'] ?? map['kode'],
          ) ??
          '',
      label:
          _asString(
            map['label'] ?? map['name'] ?? map['nama'] ?? map['label_shift'],
          ) ??
          '',
      startTime: _parseTime(
        map['startTime'] ??
            map['starttime'] ??
            map['checkInTime'] ??
            map['check_in_time'],
      ),
      endTime: _parseTime(
        map['endTime'] ??
            map['endtime'] ??
            map['checkOutTime'] ??
            map['check_out_time'],
      ),
      toleranceMinutes:
          _asInt(
            map['toleranceMinutes'] ??
                map['tolerance_minutes'] ??
                map['tolerance'],
          ) ??
          15,
      isActive: (map['isActive'] ?? map['is_active'] ?? map['active']) == null
          ? true
          : _asBool(map['isActive'] ?? map['is_active'] ?? map['active']),
      description: _asString(map['description'] ?? map['deskripsi']),
      color: _asString(map['color'] ?? map['warna']),
      createdBy: _asString(
        map['createdby'] ?? map['createdBy'] ?? map['created_by'],
      ),
      createdAt: _parseDate(
        map['createdAt'] ?? map['createdat'] ?? map['created_at'],
      ),
      updatedAt: _parseDate(
        map['updatedAt'] ?? map['updatedat'] ?? map['updated_at'],
      ),
    );
  }

  factory ShiftModel.fromJson(Map<String, dynamic> json) =>
      ShiftModel.fromMap(json);

  String? get name => null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'label': label,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'toleranceMinutes': toleranceMinutes,
    'isActive': isActive,
    'description': description,
    'color': color,
    'createdby': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toJson() => toMap();

  ShiftModel copyWith({
    String? id,
    String? code,
    String? label,
    DateTime? startTime,
    DateTime? endTime,
    int? toleranceMinutes,
    bool? isActive,
    String? description,
    String? color,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ShiftModel(
    id: id ?? this.id,
    code: code ?? this.code,
    label: label ?? this.label,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    toleranceMinutes: toleranceMinutes ?? this.toleranceMinutes,
    isActive: isActive ?? this.isActive,
    description: description ?? this.description,
    color: color ?? this.color,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() =>
      'ShiftModel(id: $id, code: $code, label: $label, startTime: $startTime, endTime: $endTime, toleranceMinutes: $toleranceMinutes, isActive: $isActive, color: $color)';
}

// Helper functions
String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  if (value is int) return value != 0;
  return false;
}

DateTime _parseTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      // Try parsing HH:mm:ss format
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        return DateTime(2000, 1, 1, hour, minute, second);
      }
    }
  }
  return DateTime(2000, 1, 1, 0, 0, 0);
}

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}
