import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../database/app_database.dart';

/// A backup file found on this phone.
@immutable
class BackupInfo {
  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.bytes,
    required this.auto,
    required this.encrypted,
  });
  final File file;
  final DateTime createdAt;
  final int bytes;

  /// Made by the daily automatic backup (kept to the last 7).
  final bool auto;
  final bool encrypted;
}

/// What a backup holds, read before restoring so the person can confirm.
@immutable
class BackupSummary {
  const BackupSummary({
    required this.schemaVersion,
    required this.counts,
    required this.createdAt,
  });
  final int schemaVersion;

  /// Rows per kind: things, thoughts, medicines, money, reminders.
  final Map<String, int> counts;
  final DateTime? createdAt;
}

/// The backup could not be read; [message] is shown to the person as is.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local backup and restore (CLAUDE.md §7: always offline).
///
/// A backup is one file: a consistent copy of the database made with
/// `VACUUM INTO`, with the app's preferences stored inside it in
/// `backup_restore_state`. It can be protected with a password (AES-256-GCM,
/// key from PBKDF2-SHA256), which is recommended for copies shared off the
/// phone because the Vault's own key is built into the app.
///
/// Restoring never swaps the live database while it is open: the checked
/// file is staged, and [applyPendingRestore] moves it in at the next launch,
/// keeping the replaced data as a safety copy.
class BackupService {
  BackupService(
    this.db,
    this.prefs, {
    Future<Directory> Function()? documents,
    DateTime Function()? clock,
  }) : _documents = documents ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final SharedPreferences prefs;
  final Future<Directory> Function() _documents;
  final DateTime Function() _clock;

  static const extension = '.ascentbackup';
  static const lastBackupKey = 'ascent_last_backup_at_v1';
  static const autoBackupKey = 'ascent_auto_backup_v1';
  static const pendingRestoreKey = 'ascent_pending_restore_v1';
  static const restoredNoticeKey = 'ascent_restore_notice_v1';
  static const keepAuto = 7;
  static const dbFileName = 'ascent_db.sqlite';
  static const stagedFileName = 'ascent_db.restore.sqlite';
  static const _magic = 'ASCENTBK1';
  static const _iterations = 120000;

  /// Preferences that describe this copy of the app, not the person's data.
  static const _deviceOnlyKeys = {
    lastBackupKey,
    pendingRestoreKey,
    restoredNoticeKey,
  };

  Future<Directory> backupsDir() async {
    final dir = Directory(p.join((await _documents()).path, 'backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  DateTime? get lastBackupAt {
    final raw = prefs.getString(lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Daily automatic backup; on unless the person turned it off.
  bool get autoEnabled => prefs.getBool(autoBackupKey) ?? true;

  Future<void> setAutoEnabled(bool on) => prefs.setBool(autoBackupKey, on);

  String _stamp(DateTime t) =>
      '${t.year}-${_pad2(t.month)}-${_pad2(t.day)}-${_pad2(t.hour)}${_pad2(t.minute)}${_pad2(t.second)}';
  static String _pad2(int v) => v.toString().padLeft(2, '0');

  /// Makes a backup now and returns its file.
  Future<File> create({
    String? password,
    bool auto = false,
    String? label,
  }) async {
    final now = _clock();
    final dir = await backupsDir();
    final tmp = File(
      p.join(dir.path, '.tmp-${now.microsecondsSinceEpoch}.sqlite'),
    );
    if (tmp.existsSync()) await tmp.delete();
    try {
      final path = tmp.path.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$path'");
      _writePrefsInto(tmp, now);
      final name =
          '${label ?? (auto ? 'auto' : 'Ascent-backup')}-${_stamp(now)}$extension';
      final out = File(p.join(dir.path, name));
      if (password != null && password.isNotEmpty) {
        final bytes = await tmp.readAsBytes();
        await out.writeAsBytes(
          await encryptBytes(bytes, password),
          flush: true,
        );
      } else {
        await tmp.copy(out.path);
      }
      await prefs.setString(lastBackupKey, now.toIso8601String());
      if (auto) await _pruneAuto(dir);
      return out;
    } finally {
      if (tmp.existsSync()) await tmp.delete();
    }
  }

  /// Runs the daily backup when it is on and the last one is a day old.
  Future<File?> runAutoIfDue() async {
    if (!autoEnabled) return null;
    final last = lastBackupAt;
    if (last != null && _clock().difference(last) < const Duration(hours: 24)) {
      return null;
    }
    return create(auto: true);
  }

  void _writePrefsInto(File file, DateTime now) {
    final map = <String, Object?>{};
    for (final k in prefs.getKeys()) {
      if (_deviceOnlyKeys.contains(k)) continue;
      final v = prefs.get(k);
      map[k] = switch (v) {
        bool() => {'t': 'b', 'v': v},
        int() => {'t': 'i', 'v': v},
        double() => {'t': 'd', 'v': v},
        String() => {'t': 's', 'v': v},
        List() => {'t': 'l', 'v': v.map((e) => '$e').toList()},
        _ => null,
      };
    }
    map.removeWhere((_, v) => v == null);
    final store = sql.sqlite3.open(file.path);
    try {
      store.execute('DELETE FROM backup_restore_state');
      store.execute(
        'INSERT INTO backup_restore_state (id, preferences_json) VALUES (?, ?)',
        [
          'prefs',
          jsonEncode({'createdAt': now.toIso8601String(), 'prefs': map}),
        ],
      );
    } finally {
      store.close();
    }
  }

  Future<void> _pruneAuto(Directory dir) async {
    final autos = (await list()).where((b) => b.auto).toList();
    for (final b in autos.skip(keepAuto)) {
      if (b.file.existsSync()) await b.file.delete();
    }
  }

  /// Backups on this phone, newest first.
  Future<List<BackupInfo>> list() async {
    final dir = await backupsDir();
    final out = <BackupInfo>[];
    for (final e in dir.listSync().whereType<File>()) {
      final name = p.basename(e.path);
      if (!name.endsWith(extension) || name.startsWith('.')) continue;
      final stat = e.statSync();
      out.add(
        BackupInfo(
          file: e,
          createdAt: stat.modified,
          bytes: stat.size,
          auto: name.startsWith('auto-'),
          encrypted: isEncrypted(e),
        ),
      );
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  static bool isEncrypted(File f) {
    final raf = f.openSync();
    try {
      final head = raf.readSync(_magic.length);
      return utf8.decode(head, allowMalformed: true) == _magic;
    } finally {
      raf.closeSync();
    }
  }

  /// Opens [file] (asking for [password] if it is protected) into a plain
  /// SQLite copy and checks it is an Ascent backup this version can read.
  Future<(File, BackupSummary)> open(File file, {String? password}) async {
    final dir = await backupsDir();
    final plain = File(
      p.join(dir.path, '.open-${_clock().microsecondsSinceEpoch}.sqlite'),
    );
    if (isEncrypted(file)) {
      if (password == null || password.isEmpty) {
        throw const BackupException(
          'This backup is protected. Enter its password.',
        );
      }
      final bytes = await file.readAsBytes();
      await plain.writeAsBytes(
        await decryptBytes(bytes, password),
        flush: true,
      );
    } else {
      await file.copy(plain.path);
    }
    try {
      return (plain, inspect(plain, supported: db.schemaVersion));
    } catch (_) {
      if (plain.existsSync()) await plain.delete();
      rethrow;
    }
  }

  /// Reads what a plain backup file holds, or throws [BackupException].
  static BackupSummary inspect(File plain, {required int supported}) {
    sql.Database store;
    try {
      store = sql.sqlite3.open(plain.path, mode: sql.OpenMode.readOnly);
    } catch (_) {
      throw const BackupException('This file is not an Ascent backup.');
    }
    try {
      final tables = {
        for (final r in store.select(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          r['name'] as String,
      };
      if (!tables.containsAll({'tasks', 'thoughts', 'backup_restore_state'})) {
        throw const BackupException('This file is not an Ascent backup.');
      }
      final version =
          store.select('PRAGMA user_version').first.values.first as int;
      if (version > supported) {
        throw const BackupException(
          'This backup was made by a newer version of Ascent. Update the app, then restore.',
        );
      }
      int count(String table) => tables.contains(table)
          ? store.select('SELECT COUNT(*) AS c FROM $table').first['c'] as int
          : 0;
      DateTime? created;
      final row = store.select(
        "SELECT preferences_json FROM backup_restore_state WHERE id = 'prefs'",
      );
      if (row.isNotEmpty) {
        final json = jsonDecode(row.first['preferences_json'] as String);
        created = DateTime.tryParse('${json['createdAt']}');
      }
      return BackupSummary(
        schemaVersion: version,
        createdAt: created,
        counts: {
          'things': count('tasks'),
          'thoughts': count('thoughts'),
          'medicines': count('medicines'),
          'money': count('finance_transactions'),
          'reminders': count('reminders'),
        },
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('This backup could not be read.');
    } finally {
      store.close();
    }
  }

  /// Stages [plain] (from [open]) to replace the data at the next launch,
  /// after saving a safety copy of what is here now.
  Future<void> stageRestore(File plain) async {
    await create(label: 'before-restore');
    final docs = await _documents();
    await plain.copy(p.join(docs.path, stagedFileName));
    if (plain.existsSync()) await plain.delete();
    await prefs.setBool(pendingRestoreKey, true);
  }

  /// Called at startup before the database opens. Moves a staged restore in
  /// and brings back its preferences. Returns true when a restore happened.
  static Future<bool> applyPendingRestore(
    SharedPreferences prefs, {
    Future<Directory> Function()? documents,
  }) async {
    if (prefs.getBool(pendingRestoreKey) != true) return false;
    final docs = await (documents ?? getApplicationDocumentsDirectory)();
    final staged = File(p.join(docs.path, stagedFileName));
    await prefs.remove(pendingRestoreKey);
    if (!staged.existsSync()) return false;
    final live = p.join(docs.path, dbFileName);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('$live$suffix');
      if (f.existsSync()) await f.delete();
    }
    await staged.rename(live);

    // Bring back the preferences that travelled inside the backup.
    final store = sql.sqlite3.open(live);
    try {
      final rows = store.select(
        "SELECT preferences_json FROM backup_restore_state WHERE id = 'prefs'",
      );
      if (rows.isNotEmpty) {
        final json = jsonDecode(rows.first['preferences_json'] as String);
        final map = (json['prefs'] as Map).cast<String, dynamic>();
        for (final k in prefs.getKeys().toList()) {
          if (!_deviceOnlyKeys.contains(k)) await prefs.remove(k);
        }
        for (final e in map.entries) {
          final v = e.value as Map;
          switch (v['t']) {
            case 'b':
              await prefs.setBool(e.key, v['v'] as bool);
            case 'i':
              await prefs.setInt(e.key, v['v'] as int);
            case 'd':
              await prefs.setDouble(e.key, (v['v'] as num).toDouble());
            case 's':
              await prefs.setString(e.key, v['v'] as String);
            case 'l':
              await prefs.setStringList(e.key, (v['v'] as List).cast<String>());
          }
        }
      }
      store.execute("DELETE FROM backup_restore_state WHERE id = 'prefs'");
    } finally {
      store.close();
    }
    await prefs.setString(
      restoredNoticeKey,
      'Your backup is restored. Welcome back.',
    );
    return true;
  }

  // Password protection ------------------------------------------------------

  static Future<Uint8List> encryptBytes(
    Uint8List plain,
    String password,
  ) async {
    final rnd = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rnd.nextInt(256)));
    final nonce = Uint8List.fromList(
      List.generate(12, (_) => rnd.nextInt(256)),
    );
    final key = await compute(_deriveKey, (password, salt));
    final cipher = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    ).encryptBytes(plain, iv: enc.IV(nonce));
    return Uint8List.fromList([
      ...utf8.encode(_magic),
      ...salt,
      ...nonce,
      ...cipher.bytes,
    ]);
  }

  static Future<Uint8List> decryptBytes(Uint8List data, String password) async {
    final m = _magic.length;
    if (data.length < m + 28) {
      throw const BackupException('This backup file is damaged.');
    }
    final salt = data.sublist(m, m + 16);
    final nonce = data.sublist(m + 16, m + 28);
    final body = data.sublist(m + 28);
    final key = await compute(_deriveKey, (password, salt));
    try {
      final out = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      ).decryptBytes(enc.Encrypted(body), iv: enc.IV(nonce));
      return Uint8List.fromList(out);
    } catch (_) {
      throw const BackupException('That password does not open this backup.');
    }
  }

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  static Uint8List _deriveKey((String, Uint8List) input) {
    final (password, salt) = input;
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(password));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return Uint8List.fromList(out);
  }
}
