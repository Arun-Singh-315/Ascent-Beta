import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/backup/backup_providers.dart';
import '../../core/backup/backup_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/ascent_switch_row.dart';

/// Backup and restore (CLAUDE.md §7). One tap makes a backup file you can
/// keep anywhere; a daily one stays on the phone; restoring shows what is
/// inside first and keeps a safety copy of the current data.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _password = TextEditingController();
  bool _protect = false;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  BackupService get _service => ref.read(backupServiceProvider);

  Future<void> _backUpNow() async {
    if (_protect && _password.text.trim().length < 4) {
      AscentSnackBar.error(
        context,
        message: 'Use a password of at least 4 characters.',
      );
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      final file = await _service.create(
        password: _protect ? _password.text.trim() : null,
      );
      ref.invalidate(backupListProvider);
      if (!mounted) return;
      AscentSnackBar.show(context, message: 'Backup saved');
      // The backup is made; a share sheet that fails is not a failed backup.
      try {
        await _share(file);
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not make a backup. Nothing changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(File file) => SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: 'Ascent backup. Keep it somewhere safe, like Google Drive.',
    ),
  );

  Future<String?> _askPassword() => showAscentFrostedDialog<String>(
    context: context,
    builder: (context) => _PasswordDialog(),
  );

  Future<void> _restore(File file) async {
    String? password;
    if (BackupService.isEncrypted(file)) {
      password = await _askPassword();
      if (password == null || !mounted) return;
    }
    setState(() => _busy = true);
    File? plain;
    try {
      final (opened, summary) = await _service.open(file, password: password);
      plain = opened;
      if (!mounted) return;
      final c = summary.counts;
      String n(int v, String one, String many) => '$v ${v == 1 ? one : many}';
      final made = summary.createdAt == null
          ? ''
          : 'Made ${humanWhen(summary.createdAt!)}. ';
      final ok = await AscentDialog.confirm(
        context: context,
        title: 'Restore this backup?',
        content:
            '$made'
            '${n(c['things']!, 'thing', 'things')}, '
            '${n(c['thoughts']!, 'thought', 'thoughts')}, '
            '${n(c['medicines']!, 'medicine', 'medicines')}, '
            '${n(c['money']!, 'money entry', 'money entries')}.\n\n'
            'It replaces what is on this phone now. Your current data is saved '
            'first as a safety backup. Ascent will close; open it again to '
            'finish.',
        confirmLabel: 'Restore',
        isDestructive: true,
        icon: Icons.settings_backup_restore_rounded,
      );
      if (ok != true || !mounted) {
        if (plain.existsSync()) await plain.delete();
        return;
      }
      HapticFeedback.mediumImpact();
      await _service.stageRestore(plain);
      plain = null;
      await SystemNavigator.pop();
    } on BackupException catch (e) {
      if (mounted) AscentSnackBar.error(context, message: e.message);
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not read that backup. Nothing changed.',
        );
      }
    } finally {
      if (plain != null && plain.existsSync()) await plain.delete();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndRestore() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (!mounted || result.isEmpty) return;
      final path = result.single.path;
      if (path == null) return;
      await _restore(File(path));
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not open that file.');
      }
    }
  }

  Future<void> _actions(BackupInfo b) async {
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: humanWhen(b.createdAt),
      actions: const [
        AscentAction('share', 'Share or save', Icons.ios_share_rounded),
        AscentAction(
          'restore',
          'Restore this backup',
          Icons.settings_backup_restore_rounded,
        ),
        AscentAction(
          'delete',
          'Delete',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'share':
        await _share(b.file);
      case 'restore':
        await _restore(b.file);
      case 'delete':
        final ok = await AscentDialog.confirm(
          context: context,
          title: 'Delete this backup?',
          content: 'This copy is removed from the phone. It cannot be undone.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (ok == true) {
          if (b.file.existsSync()) await b.file.delete();
          ref.invalidate(backupListProvider);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final service = ref.watch(backupServiceProvider);
    final last = service.lastBackupAt;
    final backups = ref.watch(backupListProvider).value ?? const [];
    final stale =
        last == null ||
        DateTime.now().difference(last) > const Duration(days: 7);
    final border = Border.all(
      color: g.ink.withValues(alpha: g.isDark ? .16 : .12),
    );

    Widget section(List<Widget> children, {Key? key}) => Container(
      key: key,
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return AscentScaffold(
      title: 'Backup & restore',
      subtitle: 'A copy of everything you have added',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          section(key: const ValueKey('backup_status'), [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (stale ? g.warningInk : g.successInk).withValues(
                        alpha: .6,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    stale
                        ? Icons.cloud_off_outlined
                        : Icons.verified_user_outlined,
                    color: stale ? g.warningInk : g.successInk,
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        last == null ? 'Not backed up yet' : 'Last backup',
                        style: AscentTextStyles.caption.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                      Text(
                        last == null
                            ? 'Make your first backup'
                            : humanWhen(last),
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            Text(
              'Includes Things, Mind, Medicine, Money, Vault and your settings. '
              'Keep a copy off the phone, like in Google Drive, so a lost or '
              'reset phone does not lose it.',
              style: AscentTextStyles.bodyMedium.copyWith(
                color: g.inkSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            AscentSwitchRow(
              key: const ValueKey('backup_protect'),
              title: 'Protect with a password',
              helper:
                  'Recommended when you share the file. You need it to '
                  'restore.',
              value: _protect,
              onChanged: (v) => setState(() => _protect = v),
            ),
            if (_protect) ...[
              const SizedBox(height: AppSpace.s8),
              AppTextField(
                key: const ValueKey('backup_password'),
                controller: _password,
                obscureText: true,
                hintText: 'Backup password',
              ),
            ],
            const SizedBox(height: AppSpace.s16),
            AscentButton.primary(
              key: const ValueKey('backup_now'),
              label: 'Back up now',
              icon: Icons.backup_outlined,
              expanded: true,
              loading: _busy,
              onPressed: _busy ? null : _backUpNow,
            ),
          ]),
          const SizedBox(height: AppSpace.s16),
          section([
            AscentSwitchRow(
              key: const ValueKey('backup_auto'),
              title: 'Back up every day',
              helper:
                  'Keeps the last ${BackupService.keepAuto} on this '
                  'phone.',
              value: service.autoEnabled,
              onChanged: (v) async {
                await service.setAutoEnabled(v);
                if (mounted) setState(() {});
              },
            ),
          ]),
          const SizedBox(height: AppSpace.s24),
          Text(
            'On this phone',
            style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s8),
          if (backups.isEmpty)
            Text(
              'No backups here yet. Back up now to make one.',
              style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
            )
          else
            section([
              for (var i = 0; i < backups.length; i++) ...[
                if (i > 0) Divider(height: 1, color: g.line),
                InkWell(
                  key: ValueKey('backup_row_$i'),
                  onTap: _busy ? null : () => _actions(backups[i]),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      children: [
                        Icon(
                          backups[i].encrypted
                              ? Icons.lock_outline_rounded
                              : Icons.description_outlined,
                          size: 20,
                          color: g.inkSecondary,
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                humanDay(backups[i].createdAt),
                                style: AscentTextStyles.listRowTitle.copyWith(
                                  color: g.ink,
                                ),
                              ),
                              Text(
                                [
                                  humanWhen(
                                    backups[i].createdAt,
                                  ).split(' at ').last,
                                  '${(backups[i].bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                  if (backups[i].auto) 'Daily',
                                  if (backups[i].encrypted) 'Protected',
                                ].join(' · '),
                                style: AscentTextStyles.caption.copyWith(
                                  color: g.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.more_horiz_rounded, color: g.inkMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          const SizedBox(height: AppSpace.s20),
          AscentButton.secondary(
            key: const ValueKey('backup_restore_file'),
            label: 'Restore from a file',
            icon: Icons.settings_backup_restore_rounded,
            expanded: true,
            onPressed: _busy ? null : _pickAndRestore,
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AscentDialog(
    title: 'Backup password',
    contentWidget: AppTextField(
      key: const ValueKey('restore_password'),
      controller: _c,
      autofocus: true,
      obscureText: true,
      hintText: 'Password',
      onChanged: (_) => setState(() {}),
      onSubmitted: (v) {
        if (v.isNotEmpty) Navigator.pop(context, v);
      },
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpace.s8,
        children: [
          AscentButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AscentButton.tonal(
            key: const ValueKey('restore_password_ok'),
            label: 'Open',
            compact: true,
            onPressed: _c.text.isEmpty
                ? null
                : () => Navigator.pop(context, _c.text),
          ),
        ],
      ),
    ],
  );
}
