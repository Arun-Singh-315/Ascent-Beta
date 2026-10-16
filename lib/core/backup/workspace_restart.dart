import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rebuild the provider container after a verified restore; no stale timers or
/// cached settings may continue writing into the restored workspace.
final restartWorkspaceProvider = Provider<Future<void> Function()>((ref) {
  throw UnimplementedError('Workspace restart is configured by main');
});
