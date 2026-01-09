class DivisionModel {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DivisionModel({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  /// Produce both canonical and legacy keys to keep compatibility with
  /// different backend expectations (camelCase and snake/lowercase).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt?.toIso8601String(),
        'createdat': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'updateat': updatedAt?.toIso8601String(),
      };

  factory DivisionModel.fromMap(Map<String, dynamic> m) {
    String asString(dynamic v) => v == null ? '' : v.toString();

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    // Accept many legacy/casing variants returned by the backend
    final id = asString(m['id'] ?? m['ID'] ?? m['_id'] ?? m['Id']);
    final name = asString(m['name'] ?? m['nama'] ?? m['Name']);
    final createdAt = parseDate(
      m['createdAt'] ?? m['createdat'] ?? m['created_at'] ?? m['CreatedAt'],
    );
    final updatedAt = parseDate(
      m['updatedAt'] ?? m['updateat'] ?? m['updated_at'] ?? m['UpdatedAt'] ?? m['updateAt'] ?? m['updateat'],
    );

    return DivisionModel(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
