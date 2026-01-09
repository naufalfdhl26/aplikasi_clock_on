class LocationModel {
  final String id;
  final String name;
  final String? address;

  final double latitude;
  final double longtitude;
  final double radius;

  final List<String> ssid; // SSID kantor
  final List<String> bssid; // BSSID kantor

  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocationModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longtitude,
    this.radius = 0,
    this.ssid = const [],
    this.bssid = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Normalisasi SSID → lowercase tanpa spasi
  List<String> get normalizedSsids =>
      ssid.map((e) => e.trim().toLowerCase()).toList();

  /// Normalisasi BSSID → lowercase
  List<String> get normalizedBssids =>
      bssid.map((e) => e.trim().toLowerCase()).toList();

  /// Cek apakah SSID/BSSID user cocok dengan kantor ini
  bool matchesWifi(String ssid, String bssid) {
    final s = ssid.trim().toLowerCase();
    final b = bssid.trim().toLowerCase();

    return normalizedSsids.contains(s) || normalizedBssids.contains(b);
  }

  /// Kantor punya lokasi GPS
  bool get hasGps => latitude != 0 && longtitude != 0;

  /// Convert to Map → untuk API / GoCloud / local storage
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "address": address,
      "latitude": latitude,
      "longtitude": longtitude,
      "radius": radius,
      "ssid": ssid,
      "bssid": bssid,
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String(),
    };
  }

  /// Factory from Map
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    String asString(dynamic v) => v == null ? '' : v.toString();

    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s) ?? 0;
    }

    List<String> toListOfString(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      final s = v.toString();
      if (s.isEmpty) return [];
      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    final id = asString(map['id'] ?? map['ID'] ?? map['_id']);
    final name = asString(map['name'] ?? map['nama'] ?? map['title']);
    final address = map['address'] != null ? asString(map['address']) : null;

    final latitude = toDouble(
      map['latitude'] ?? map['lat'] ?? map['latitude_str'],
    );
    final longtitude = toDouble(
      map['longtitude'] ?? map['longitude'] ?? map['lng'],
    );
    final radius = toDouble(map['radius'] ?? map['rad']);

    final ssid = toListOfString(
      map['ssid'] ?? map['ssids'] ?? map['wifi_ssid'],
    );
    final bssid = toListOfString(
      map['bssid'] ?? map['bssids'] ?? map['wifi_bssid'],
    );

    // created/updated could be named differently on server
    final createdAt = parseDate(
      map['createdAt'] ?? map['createdat'] ?? map['created_at'],
    );
    final updatedAt = parseDate(
      map['updatedAt'] ?? map['updateat'] ?? map['updated_at'],
    );

    return LocationModel(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longtitude: longtitude,
      radius: radius,
      ssid: ssid,
      bssid: bssid,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Copy update sebagian field
  LocationModel copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longtitude,
    double? radius,
    List<String>? ssid,
    List<String>? bssid,
    DateTime? updatedAt,
  }) {
    return LocationModel(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longtitude: longtitude ?? this.longtitude,
      radius: radius ?? this.radius,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
