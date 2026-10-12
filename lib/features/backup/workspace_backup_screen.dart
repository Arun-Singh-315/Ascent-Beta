import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/backup/workspace_backup_service.dart';
import '../../core/backup/workspace_restart.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/walk/walk_tracking_service.dart';
import '../../features/chai_break/chai_break_provider.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../app/theme/glass_theme.dart';

class WorkspaceBackupScreen extends ConsumerStatefulWidget {
  const WorkspaceBackupScreen({super.key});
  @override
  ConsumerState<WorkspaceBackupScreen> createState() =>
      _WorkspaceBackupScreenState();
}

class _WorkspaceBackupScreenState extends ConsumerState<WorkspaceBackupScreen> {
  bool _busy = false;
  String? _status;
  bool _failed = false;
  Future<WorkspaceBackupService> _service() async => WorkspaceBackupService(
    ref.read(databaseProvider),
    SharedBackupPreferences(ref.read(sharedPreferencesProvider)),
    await getApplicationDocumentsDirectory(),
  );
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _status = null;
    });
    try {
      await action();
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status = e.message;
        });
      }
    } on RestoreRecoveryRequired catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status =
              'Records restored. Reopen Ascent to finish settings recovery.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status =
              'Could not finish. Check file access and available storage, then try again. Missing resume files must be reattached before exporting.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    final service = await _service();
    final raw = await service.export();
    final preview = await service.inspect(raw);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final uri = await FilePicker.saveFile(
      fileName: 'Ascent-$date.json',
      bytes: Uint8List.fromList(utf8.encode(raw)),
      mimeType: 'application/json',
    );
    if (mounted) {
      setState(
        () => _status = uri == null
            ? 'Save cancelled.'
            : 'Backup saved: ${preview.recordCount} records, ${preview.settingCount} settings and ${preview.fileCount} resume files.',
      );
    }
  });
  Future<bool> _canRestore() async {
    final active = await ref
        .read(timeSessionDaoProvider)
        .getActiveFocusSession();
    final learning =
        ref.exists(learningHubProvider) &&
        ref.read(learningHubProvider).isPlaying;
    final chai =
        ref.exists(chaiBreakProvider) && ref.read(chaiBreakProvider).isRunning;
    final walk =
        ref.exists(walkTrackingProvider) &&
        ref.read(walkTrackingProvider).status != WalkTrackingStatus.idle;
    if (active?.status == 'running' || learning || chai || walk) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status =
              'Pause Focus, Learning and Chai, and finish any active walk before restoring.';
        });
      }
      return false;
    }
    return true;
  }

  Future<void> _restore() => _run(() async {
    if (!await _canRestore()) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked?.path == null) return;
    final file = File(picked!.path!);
    if (await file.length() > WorkspaceBackupService.maxBytes) {
      throw const FormatException('Backup exceeds 64 MB.');
    }
    final raw = await file.readAsString();
    final service = await _service();
    final preview = await service.inspect(raw);
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace this workspace?'),
        content: SingleChildScrollView(
          child: Text(
            'Backup from ${preview.createdAt.toLocal().toString().substring(0, 16)}\n\n${preview.recordCount} records · ${preview.settingCount} settings · ${preview.fileCount} resume files\n\nThis replaces current records and settings. A recovery copy is saved on this device first. Restored Focus sessions and walks remain paused. Device alarms are rebuilt separately.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace and restore'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || !await _canRestore()) return;
    // Capture before restarting/disposal so no later WidgetRef access is needed.
    final restart = ref.read(restartWorkspaceProvider);
    await service.restore(raw, confirmed: true);
    await finishRestoredAlerts(
      ref.read(databaseProvider),
      ref.read(sharedPreferencesProvider),
    );
    await restart();
  });
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return PopScope(
      canPop: !_busy,
      child: AscentScaffold(
        title: 'Back up & restore',
        subtitle: 'Keep your workspace recoverable',
        onBack: _busy ? () {} : null,
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.backup_rounded, size: 48, color: g.clay),
            const SizedBox(height: 20),
            const Text(
              'Your records, settings and resume files',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Includes thoughts, tasks, reminders, challenges, learning progress, expenses, health logs, chat and writing drafts. Save the file somewhere private that you can access if you change phones.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Save backup file'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore backup'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Restore requires a backup made with this version of the backup format. Older partial JSON exports cannot restore the whole workspace. Linked web content and device notification/location permissions are not included.',
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Checking and preparing your workspace…'),
            ],
            if (_status != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status!,
                  style: TextStyle(color: _failed ? g.clay : g.sage),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
