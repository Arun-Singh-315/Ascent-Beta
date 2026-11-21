import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'backup_service.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Backups on this phone, newest first. Invalidate after making or
/// deleting one.
final backupListProvider = FutureProvider<List<BackupInfo>>(
  (ref) => ref.watch(backupServiceProvider).list(),
);
