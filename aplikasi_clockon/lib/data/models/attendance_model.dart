class AttendanceModel {
  final String id;
  final String employeeId;
  final DateTime date;
  final DateTime? checkin;
  final DateTime? checkout;
  final String status;
  final String? wifiSsid;
  final String? wifiBssid;
  final bool? approved;
  final DateTime createdAt;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkin,
    this.checkout,
    required this.status,
    this.wifiSsid,
    this.wifiBssid,
    this.approved,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    try {
      // Helper to safely parse dates or time-only strings.
      // If `value` is time-only like '08:30' or '08:30:15', and a dateStr
      // is available, we combine them into an ISO datetime before parsing.
      DateTime? parseDate(dynamic value, [String? dateForTime]) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String && value.isNotEmpty) {
          // Direct parse first (handles ISO datetimes and full dates)
          try {
            return DateTime.parse(value);
          } catch (_) {
            // If parsing fails, check for time-only formats like HH:mm or HH:mm:ss
            final timeOnly = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');
            if (timeOnly.hasMatch(value) && dateForTime != null) {
              // Combine date and time into an ISO-like string
              final combined = dateForTime.contains('T')
                  ? dateForTime.split('T').first + 'T' + value
                  : dateForTime + 'T' + value;
              try {
                return DateTime.parse(combined);
              } catch (_) {
                // As fallback, try parsing with a space separator
                try {
                  return DateTime.parse(
                    dateForTime.split('T').first + ' ' + value,
                  );
                } catch (_) {
                  return null;
                }
              }
            }
            return null;
          }
        }
        return null;
      }

      final dateStr = json['date'] ?? json['createdAt'] ?? json['createdat'];
      DateTime parsedDate = DateTime.now();
      if (dateStr != null) {
        final parsed = parseDate(dateStr);
        if (parsed != null) parsedDate = parsed;
      }

      return AttendanceModel(
        id: (json['id'] ?? '').toString(),
        employeeId: (json['employeeId'] ?? json['employeeid'] ?? '').toString(),
        date: parsedDate,
        checkin: parseDate(json['checkin'], dateStr?.toString()),
        checkout: parseDate(json['checkout'], dateStr?.toString()),
        status: (json['status'] ?? 'unknown').toString(),
        wifiSsid: json['wifiSsid']?.toString() ?? json['wifissid']?.toString(),
        wifiBssid:
            json['wifiBssid']?.toString() ?? json['wifibssid']?.toString(),
        approved: json['approved'] != null
            ? (json['approved'].toString().toLowerCase() == 'true' ||
                  json['approved'] == 1)
            : false,
        createdAt:
            parseDate(json['createdAt'] ?? json['createdat']) ?? DateTime.now(),
      );
    } catch (e) {
      // Fallback untuk parsing error
      return AttendanceModel(
        id: json['id']?.toString() ?? '',
        employeeId:
            (json['employeeId'] ?? json['employeeid'])?.toString() ?? '',
        date: DateTime.now(),
        status: json['status']?.toString() ?? 'unknown',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'date': date.toIso8601String(),
    'checkin': checkin?.toIso8601String(),
    'checkout': checkout?.toIso8601String(),
    'status': status,
    'wifiSsid': wifiSsid,
    'wifiBssid': wifiBssid,
    'approved': approved,
    'createdAt': createdAt.toIso8601String(),
  };
}
