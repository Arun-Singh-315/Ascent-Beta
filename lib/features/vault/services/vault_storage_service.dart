import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../models/vault_item_model.dart';
import 'vault_security_service.dart';

class VaultStorageService {
  VaultStorageService({
    required this.db,
    required this.security,
  });

  final AppDatabase db;
  final VaultSecurityService security;

  final _changeController = StreamController<void>.broadcast();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS vault_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        subtitle TEXT,
        fields_json TEXT NOT NULL,
        media_paths_json TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_vault_items_category ON vault_items(category);
    ''');
    _initialized = true;
  }

  Future<int> insertItem(VaultItem item) async {
    await init();
    final encryptedFields = security.encrypt(jsonEncode(item.fields));
    final mediaJson = jsonEncode(item.mediaPaths);

    final result = await db.customInsert(
      '''
      INSERT INTO vault_items (
        title, category, subtitle, fields_json, media_paths_json, is_favorite, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable<String>(item.title),
        Variable<String>(item.category.name),
        Variable<String>(item.subtitle ?? ''),
        Variable<String>(encryptedFields),
        Variable<String>(mediaJson),
        Variable<int>(item.isFavorite ? 1 : 0),
        Variable<int>(item.createdAt.millisecondsSinceEpoch),
        Variable<int>(item.updatedAt.millisecondsSinceEpoch),
      ],
    );

    _changeController.add(null);
    return result;
  }

  Future<void> updateItem(VaultItem item) async {
    if (item.id == null) return;
    await init();
    final encryptedFields = security.encrypt(jsonEncode(item.fields));
    final mediaJson = jsonEncode(item.mediaPaths);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.customUpdate(
      '''
      UPDATE vault_items SET
        title = ?,
        category = ?,
        subtitle = ?,
        fields_json = ?,
        media_paths_json = ?,
        is_favorite = ?,
        updated_at = ?
      WHERE id = ?
      ''',
      variables: [
        Variable<String>(item.title),
        Variable<String>(item.category.name),
        Variable<String>(item.subtitle ?? ''),
        Variable<String>(encryptedFields),
        Variable<String>(mediaJson),
        Variable<int>(item.isFavorite ? 1 : 0),
        Variable<int>(now),
        Variable<int>(item.id!),
      ],
    );

    _changeController.add(null);
  }

  Future<void> deleteItem(int id) async {
    await init();
    final item = await getItemById(id);
    if (item != null) {
      // Cascading file deletion for attached private media
      for (final path in item.mediaPaths) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            await file.delete();
          }
        } catch (_) {
          // Best effort file deletion
        }
      }
    }

    await db.customUpdate(
      'DELETE FROM vault_items WHERE id = ?',
      variables: [Variable<int>(id)],
    );

    _changeController.add(null);
  }

  Future<VaultItem?> getItemById(int id) async {
    await init();
    final rows = await db.customSelect(
      'SELECT * FROM vault_items WHERE id = ? LIMIT 1',
      variables: [Variable<int>(id)],
    ).get();

    if (rows.isEmpty) return null;
    return _mapRowToItem(rows.first);
  }

  Future<List<VaultItem>> getAllItems({VaultCategory? category}) async {
    await init();
    final query = category != null
        ? 'SELECT * FROM vault_items WHERE category = ? ORDER BY is_favorite DESC, updated_at DESC'
        : 'SELECT * FROM vault_items ORDER BY is_favorite DESC, updated_at DESC';

    final variables = category != null ? [Variable<String>(category.name)] : <Variable>[];
    final rows = await db.customSelect(query, variables: variables).get();

    return rows.map(_mapRowToItem).toList();
  }

  Stream<List<VaultItem>> watchAllItems({VaultCategory? category}) async* {
    await init();
    yield await getAllItems(category: category);
    await for (final _ in _changeController.stream) {
      yield await getAllItems(category: category);
    }
  }

  VaultItem _mapRowToItem(QueryRow row) {
    final encryptedFields = row.read<String>('fields_json');
    final decryptedString = security.decrypt(encryptedFields);

    Map<String, dynamic> fields = {};
    try {
      if (decryptedString.isNotEmpty) {
        fields = Map<String, dynamic>.from(jsonDecode(decryptedString) as Map);
      }
    } catch (_) {
      fields = {};
    }

    final mediaRaw = row.readNullable<String>('media_paths_json');
    List<String> mediaPaths = [];
    if (mediaRaw != null && mediaRaw.isNotEmpty) {
      try {
        mediaPaths = (jsonDecode(mediaRaw) as List<dynamic>).cast<String>();
      } catch (_) {}
    }

    final subtitle = row.readNullable<String>('subtitle');
    return VaultItem(
      id: row.read<int>('id'),
      title: row.read<String>('title'),
      category: VaultCategory.fromString(row.read<String>('category')),
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      fields: fields,
      mediaPaths: mediaPaths,
      isFavorite: (row.read<int>('is_favorite')) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('updated_at')),
    );
  }

  void dispose() {
    _changeController.close();
  }
}
