import 'dart:convert';

enum VaultCategory {
  card,
  idDoc,
  login,
  document,
  note;

  String get displayName {
    switch (this) {
      case VaultCategory.card:
        return 'Cards & Banking';
      case VaultCategory.idDoc:
        return 'IDs & Documents';
      case VaultCategory.login:
        return 'Logins & Keys';
      case VaultCategory.document:
        return 'Secure Files';
      case VaultCategory.note:
        return 'Private Notes';
    }
  }

  String get shortName {
    switch (this) {
      case VaultCategory.card:
        return 'Cards';
      case VaultCategory.idDoc:
        return 'IDs';
      case VaultCategory.login:
        return 'Logins';
      case VaultCategory.document:
        return 'Files';
      case VaultCategory.note:
        return 'Notes';
    }
  }

  static VaultCategory fromString(String val) {
    for (final cat in VaultCategory.values) {
      if (cat.name.toLowerCase() == val.toLowerCase()) return cat;
    }
    return VaultCategory.card;
  }
}

class VaultItem {
  final int? id;
  final String title;
  final VaultCategory category;
  final String? subtitle;
  final Map<String, dynamic> fields;
  final List<String> mediaPaths;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultItem({
    this.id,
    required this.title,
    required this.category,
    this.subtitle,
    required this.fields,
    this.mediaPaths = const [],
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  VaultItem copyWith({
    int? id,
    String? title,
    VaultCategory? category,
    String? subtitle,
    Map<String, dynamic>? fields,
    List<String>? mediaPaths,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      subtitle: subtitle ?? this.subtitle,
      fields: fields ?? this.fields,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category.name,
      'subtitle': subtitle,
      'fields_json': jsonEncode(fields),
      'media_paths_json': jsonEncode(mediaPaths),
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VaultItem.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? decryptedFields}) {
    final fieldsRaw = decryptedFields ?? (map['fields_json'] != null 
        ? (jsonDecode(map['fields_json'] as String) as Map<String, dynamic>)
        : <String, dynamic>{});
        
    final mediaRaw = map['media_paths_json'] != null
        ? (jsonDecode(map['media_paths_json'] as String) as List<dynamic>).cast<String>()
        : <String>[];

    return VaultItem(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Untitled',
      category: VaultCategory.fromString(map['category'] as String? ?? 'card'),
      subtitle: map['subtitle'] as String?,
      fields: fieldsRaw,
      mediaPaths: mediaRaw,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int? ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int? ?? 0),
    );
  }
}
