import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../backup/backup_providers.dart';
import '../backup/backup_service.dart';
import 'cloud_gateway.dart';

/// The backend. Offline unless `main` overrides it with a configured
/// Supabase gateway; tests override it with a fake.
final cloudGatewayProvider = Provider<CloudGateway>(
  (ref) => const OfflineCloudGateway(),
);

/// The signed-in person (null when signed out or offline).
final cloudUserProvider = StreamProvider<CloudUser?>((ref) async* {
  final cloud = ref.watch(cloudGatewayProvider);
  yield cloud.currentUser;
  yield* cloud.userChanges;
});

/// Cloud backups, newest first. Invalidate after a change.
final cloudBackupsProvider = FutureProvider<List<CloudBackup>>((ref) async {
  final cloud = ref.watch(cloudGatewayProvider);
  final user = ref.watch(cloudUserProvider).value;
  if (!cloud.available || user == null) return const [];
  return cloud.listBackups();
});

final cloudBackupServiceProvider = Provider<CloudBackupService>(
  (ref) => CloudBackupService(
    ref.watch(cloudGatewayProvider),
    ref.watch(backupServiceProvider),
  ),
);

/// Cloud backup = the normal backup file, always password-protected, so
/// only ciphertext leaves the phone (CLAUDE.md §7: Vault data is only ever
/// synced as ciphertext).
class CloudBackupService {
  CloudBackupService(this.cloud, this.backups);
  final CloudGateway cloud;
  final BackupService backups;

  /// How many cloud backups are kept; older ones are removed after upload.
  static const keep = 10;
  static const minPassword = 6;

  Future<CloudBackup> upload(String password) async {
    if (password.trim().length < minPassword) {
      throw const CloudException(
        'Use a password of at least $minPassword characters.',
      );
    }
    final file = await backups.create(password: password, label: 'cloud');
    final name = p.basename(file.path);
    final bytes = await file.readAsBytes();
    await cloud.uploadBackup(name, Uint8List.fromList(bytes));
    final all = await cloud.listBackups();
    for (final old in all.skip(keep)) {
      try {
        await cloud.deleteBackup(old.name);
      } catch (_) {
        // Pruning is best effort; the new backup is safe.
      }
    }
    return CloudBackup(
      name: name,
      createdAt: DateTime.now(),
      bytes: bytes.length,
    );
  }

  /// Downloads [name] into the phone's backups folder and returns the file,
  /// ready for the normal restore flow (password, summary, confirm).
  Future<File> download(String name) async {
    final bytes = await cloud.downloadBackup(name);
    final dir = await backups.backupsDir();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    if (!BackupService.isEncrypted(file)) {
      await file.delete();
      throw const CloudException('That cloud file is not an Ascent backup.');
    }
    return file;
  }
}
