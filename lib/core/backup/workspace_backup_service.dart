import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

abstract interface class BackupPreferences {
  Map<String, Object> snapshot();
  Future<void> replace(Map<String, Object> values);
}

class SharedBackupPreferences implements BackupPreferences {
  SharedBackupPreferences(this.preferences);
  final SharedPreferences preferences;
  @override
  Map<String, Object> snapshot() => {
    for (final key in preferences.getKeys()) key: preferences.get(key)!,
  };
  @override
  Future<void> replace(Map<String, Object> values) async {
    for (final key in preferences.getKeys().difference(values.keys.toSet())) {
      if (!await preferences.remove(key)) {
        throw StateError('Could not clear a preference');
      }
    }
    for (final entry in values.entries) {
      final value = entry.value;
      final success = switch (value) {
        bool v => await preferences.setBool(entry.key, v),
        int v => await preferences.setInt(entry.key, v),
        double v => await preferences.setDouble(entry.key, v),
        String v => await preferences.setString(entry.key, v),
        List<String> v => await preferences.setStringList(entry.key, v),
        _ => throw FormatException('Unsupported setting type'),
      };
      if (!success) throw StateError('Could not save a preference');
    }
  }
}

class BackupPreview {
  const BackupPreview(
    this.createdAt,
    this.tableCounts,
    this.fileCount,
    this.settingCount,
  );
  final DateTime createdAt;
  final Map<String, int> tableCounts;
  final int fileCount, settingCount;
  int get recordCount => tableCounts.values.fold(0, (a, b) => a + b);
}

class RestoreRecoveryRequired implements Exception {
  const RestoreRecoveryRequired();
  @override
  String toString() =>
      'Records were restored. Restart Ascent to finish recovering settings.';
}

String _canonical(Object? value) {
  Object? sorted(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sorted(item[key])};
    }
    if (item is List) return item.map(sorted).toList();
    return item;
  }

  return jsonEncode(sorted(value));
}

String _digest(Object value) =>
    sha256.convert(utf8.encode(_canonical(value))).toString();
String _encode(Map<String, dynamic> payload) =>
    jsonEncode({'payload': payload, 'sha256': _digest(payload)});
Map<String, dynamic> _decode(String raw) {
  if (utf8.encode(raw).length > WorkspaceBackupService.maxBytes) {
    throw const FormatException('Backup exceeds 64 MB');
  }
  final envelope = jsonDecode(raw);
  if (envelope is! Map || envelope['payload'] is! Map) {
    throw const FormatException(
      'This is an older partial export or an unsupported backup. No data was changed.',
    );
  }
  final payload = Map<String, dynamic>.from(envelope['payload'] as Map);
  if (envelope['sha256'] != _digest(payload)) {
    throw const FormatException(
      'Backup checksum does not match. No data was changed.',
    );
  }
  return payload;
}

/// Versioned, same-schema portable workspace backup. SQLite owns the durable
/// restore journal so preference synchronization can finish after app death.
class WorkspaceBackupService {
  WorkspaceBackupService(this.db, this.preferences, this.documents);
  final AppDatabase db;
  final BackupPreferences preferences;
  final Directory documents;
  static const maxBytes = 64 * 1024 * 1024;
  static const maxFileBytes = 40 * 1024 * 1024;
  List<TableInfo> get _tables => db.allTables
      .where((t) => t.actualTableName != 'backup_restore_state')
      .toList();
  String _sqlName(String name) {
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(name)) {
      throw const FormatException('Invalid schema identifier');
    }
    return '"$name"';
  }

  Future<String> export() => _export();

  Future<String> _export({bool safetyCopy = false}) async {
    if (await _hasPending()) throw const RestoreRecoveryRequired();
    final tables = await db.transaction(() async {
      final result = <String, dynamic>{};
      for (final table in _tables) {
        result[table.actualTableName] =
            (await db
                    .customSelect(
                      'SELECT * FROM ${_sqlName(table.actualTableName)}',
                    )
                    .get())
                .map((r) => r.data)
                .toList();
      }
      return result;
    });
    final files = <Map<String, dynamic>>[];
    var totalBytes = 0;
    final missingFiles = <String>[];
    for (final path
        in (tables['resumes'] as List)
            .map((r) => r['file_path'] as String)
            .toSet()) {
      final file = File(path);
      if (!await file.exists()) {
        if (safetyCopy) {
          missingFiles.add(path);
          continue;
        }
        throw StateError(
          'A saved resume file is missing. Reattach it in Resume Vault before exporting.',
        );
      }
      totalBytes += await file.length();
      if (totalBytes > maxFileBytes) {
        throw StateError('Resume files exceed the 40 MB backup limit.');
      }
      final bytes = await file.readAsBytes();
      files.add({
        'source': path,
        'bytes': base64Encode(bytes),
        'sha256': sha256.convert(bytes).toString(),
      });
    }
    final payload = <String, dynamic>{
      'format': 'ascent.workspace',
      'version': 1,
      'schema': db.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
      'preferences': preferences.snapshot(),
      'files': files,
      if (missingFiles.isNotEmpty) 'missingResumeFiles': missingFiles,
    };
    final raw = await compute(_encode, payload);
    if (utf8.encode(raw).length > maxBytes) {
      throw StateError('Workspace exceeds the 64 MB backup limit.');
    }
    return raw;
  }

  Future<Map<String, dynamic>> _validated(String raw) async {
    final payload = await compute(_decode, raw);
    // Backups from 1.0.7 keep their quiet reminder behavior after upgrading.
    if (payload['format'] == 'ascent.workspace' && payload['version'] == 1 && payload['schema'] == 14 && db.schemaVersion == 15 && payload['tables'] is Map && payload['tables']['reminders'] is List) {
      for (final row in payload['tables']['reminders'] as List) {
        if (row is Map) row['alarm_enabled'] = 0;
      }
      payload['schema'] = 15;
    }
    if (payload['format'] != 'ascent.workspace' ||
        payload['version'] != 1 ||
        payload['schema'] != db.schemaVersion) {
      throw const FormatException(
        'Unsupported backup version. Use the same Ascent backup schema. No data was changed.',
      );
    }
    if (payload['createdAt'] is! String ||
        DateTime.tryParse(payload['createdAt']) == null ||
        payload['tables'] is! Map ||
        payload['preferences'] is! Map ||
        payload['files'] is! List) {
      throw const FormatException('Incomplete backup');
    }
    final tables = payload['tables'] as Map;
    final names = _tables.map((t) => t.actualTableName).toSet();
    if (tables.keys.toSet().difference(names).isNotEmpty ||
        names.difference(tables.keys.toSet()).isNotEmpty) {
      throw const FormatException('Backup must include every workspace table');
    }
    var records = 0;
    for (final name in names) {
      final rows = tables[name];
      if (rows is! List || (records += rows.length) > 200000) {
        throw const FormatException('Invalid record count');
      }
      final columns = await db
          .customSelect('PRAGMA table_info(${_sqlName(name)})')
          .get();
      final columnNames = columns.map((c) => c.data['name'] as String).toSet();
      for (final row in rows) {
        if (row is! Map ||
            row.keys.toSet().difference(columnNames).isNotEmpty ||
            columnNames.difference(row.keys.toSet()).isNotEmpty) {
          throw const FormatException('Invalid record columns');
        }
        for (final column in columns) {
          final value = row[column.data['name']];
          if (value == null) {
            if (column.data['notnull'] == 1 || column.data['pk'] == 1) {
              throw const FormatException('Required record value missing');
            }
            continue;
          }
          final type = column.data['type'] as String;
          final valid = switch (type) {
            'INTEGER' => value is int,
            'REAL' => value is num && value.isFinite,
            'TEXT' => value is String,
            _ => false,
          };
          if (!valid) throw const FormatException('Invalid record value');
        }
      }
    }
    _preferences(payload['preferences'] as Map);
    final sources = <String>{};
    var bytesTotal = 0;
    for (final file in payload['files'] as List) {
      if (file is! Map ||
          file['source'] is! String ||
          file['bytes'] is! String ||
          !sources.add(file['source'])) {
        throw const FormatException('Invalid file manifest');
      }
      final bytes = base64Decode(file['bytes']);
      bytesTotal += bytes.length;
      if (bytesTotal > maxFileBytes ||
          sha256.convert(bytes).toString() != file['sha256']) {
        throw const FormatException('Invalid file checksum or size');
      }
    }
    final referenced = (tables['resumes'] as List)
        .map((r) => r['file_path'])
        .toSet();
    if (referenced.difference(sources).isNotEmpty ||
        sources.difference(referenced).isNotEmpty) {
      throw const FormatException('Resume attachments are incomplete');
    }
    return payload;
  }

  Map<String, Object> _preferences(Map values) => values.map((key, value) {
    if (key is! String || key.isEmpty || key.length > 256) {
      throw const FormatException('Invalid setting key');
    }
    if (value is List) {
      if (value.any((v) => v is! String)) {
        throw const FormatException('Invalid setting list');
      }
      return MapEntry(key, value.cast<String>());
    }
    if (!(value is String ||
        value is int ||
        value is bool ||
        (value is double && value.isFinite))) {
      throw const FormatException('Invalid setting value');
    }
    return MapEntry(key, value as Object);
  });

  Future<BackupPreview> inspect(String raw) async {
    final payload = await _validated(raw);
    return BackupPreview(
      DateTime.parse(payload['createdAt']),
      (payload['tables'] as Map).map(
        (key, rows) => MapEntry(key as String, (rows as List).length),
      ),
      (payload['files'] as List).length,
      (payload['preferences'] as Map).length,
    );
  }

  Future<bool> _hasPending() async =>
      (await db.customSelect('SELECT id FROM backup_restore_state').get())
          .isNotEmpty;
  Future<bool> recoverPreferences() async {
    final rows = await db
        .customSelect('SELECT preferences_json FROM backup_restore_state')
        .get();
    if (rows.isEmpty) return false;
    await preferences.replace(
      _preferences(
        jsonDecode(rows.single.data['preferences_json'] as String) as Map,
      ),
    );
    await db.customStatement('DELETE FROM backup_restore_state');
    return true;
  }

  Future<void> restore(String raw, {bool confirmed = false}) async {
    if (!confirmed) throw StateError('Review and confirmation required');
    if (await _hasPending()) throw const RestoreRecoveryRequired();
    final payload = await _validated(raw);
    // Keep an actual recovery copy before replacing the workspace.
    await documents.create(recursive: true);
    final safety = await _export(safetyCopy: true);
    await File(
      p.join(
        documents.path,
        'ascent-before-restore-${DateTime.now().microsecondsSinceEpoch}.json',
      ),
    ).writeAsString(safety, flush: true);
    final imported = await Directory(
      p.join(
        documents.path,
        'restored-resumes-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    final restoredPreferences = _preferences(payload['preferences'] as Map);
    restoredPreferences['ascent_restore_alert_sync_v1'] = true;
    if (restoredPreferences['ascent_active_walk_is_active'] == true &&
        restoredPreferences['ascent_active_walk_is_paused'] != true) {
      restoredPreferences['ascent_active_walk_is_paused'] = true;
      restoredPreferences['ascent_active_walk_pause_start_time'] =
          DateTime.parse(payload['createdAt']).millisecondsSinceEpoch;
    }
    final paths = <String, String>{};
    try {
      var i = 0;
      for (final file in payload['files'] as List) {
        // Never trust paths in a backup as destinations. Use generated names.
        final path = p.join(
          imported.path,
          '${i++}${p.extension(file['source']).replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '')}',
        );
        await File(path).writeAsBytes(base64Decode(file['bytes']), flush: true);
        paths[file['source']] = path;
      }
      await db.transaction(() async {
        await db.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in _tables.reversed) {
          await db.customStatement(
            'DELETE FROM ${_sqlName(table.actualTableName)}',
          );
        }
        for (final table in _tables) {
          final name = table.actualTableName;
          for (final rawRow in payload['tables'][name] as List) {
            final row = Map<String, dynamic>.from(rawRow as Map);
            if (name == 'resumes') row['file_path'] = paths[row['file_path']];
            if (name == 'time_sessions' && row['status'] == 'running') {
              final at = DateTime.fromMillisecondsSinceEpoch(
                ((row['last_heartbeat_at'] ?? row['started_at']) as int) * 1000,
              );
              final intervals =
                  jsonDecode(row['paused_intervals'] as String) as List;
              intervals.add({
                'pausedAt': at.toIso8601String(),
                'resumedAt': null,
              });
              row['paused_intervals'] = jsonEncode(intervals);
              row['status'] = 'paused';
            }
            final keys = row.keys.toList();
            await db.customStatement(
              'INSERT INTO ${_sqlName(name)} (${keys.map(_sqlName).join(',')}) VALUES (${List.filled(keys.length, '?').join(',')})',
              keys.map((key) => row[key]).toList(),
            );
          }
        }
        if ((await db.customSelect('PRAGMA foreign_key_check').get())
            .isNotEmpty) {
          throw const FormatException(
            'Backup contains broken record links. No records were changed.',
          );
        }
        await db
            .into(db.backupRestoreTable)
            .insert(
              BackupRestoreTableCompanion.insert(
                id: 'pending',
                preferencesJson: jsonEncode(restoredPreferences),
              ),
            );
      });
    } catch (_) {
      await imported.delete(recursive: true);
      rethrow;
    }
    db.markTablesUpdated(db.allTables.toSet());
    try {
      await recoverPreferences();
    } catch (_) {
      throw const RestoreRecoveryRequired();
    }
  }
}
