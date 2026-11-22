import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/backup/backup_providers.dart';
import '../../core/cloud/cloud_gateway.dart';
import '../../core/cloud/cloud_providers.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

/// "Cloud" on the Backup screen: sign in with an emailed code, keep
/// password-protected backups in your own private folder, restore on any
/// phone. Shown only when this build has a cloud project (CLAUDE.md §7).
class CloudBackupSection extends ConsumerStatefulWidget {
  const CloudBackupSection({super.key, required this.onRestore});

  /// Runs the Backup screen's normal restore flow for a downloaded file.
  final Future<void> Function(File file) onRestore;

  @override
  ConsumerState<CloudBackupSection> createState() =>
      _CloudBackupSectionState();
}

class _CloudBackupSectionState extends ConsumerState<CloudBackupSection> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _codeSentTo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  CloudGateway get _cloud => ref.read(cloudGatewayProvider);

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } on CloudException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Nothing changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  Future<void> _sendCode() => _run(() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      throw const CloudException('Enter your email, e.g. name@example.com.');
    }
    await _cloud.sendCode(email);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _codeSentTo = email);
  });

  Future<void> _verify() => _run(() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      throw const CloudException('Enter the 6-digit code from the email.');
    }
    await _cloud.verifyCode(_codeSentTo!, code);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _codeSentTo = null;
      _code.clear();
    });
    ref.invalidate(cloudBackupsProvider);
  });

  Future<void> _upload() => _run(() async {
    await ref.read(cloudBackupServiceProvider).upload(_password.text);
    HapticFeedback.lightImpact();
    ref
      ..invalidate(cloudBackupsProvider)
      ..invalidate(backupListProvider);
    if (mounted) {
      AscentSnackBar.success(context, message: 'Backed up to the cloud');
    }
  });

  Future<void> _signOut() => _run(() async {
    await _cloud.signOut();
    ref.invalidate(cloudBackupsProvider);
  });

  Future<void> _actions(CloudBackup b) async {
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: humanWhen(b.createdAt),
      actions: const [
        AscentAction(
          'restore',
          'Restore this backup',
          Icons.settings_backup_restore_rounded,
        ),
        AscentAction(
          'delete',
          'Delete from the cloud',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'restore':
        File? file;
        await _run(() async {
          file = await ref.read(cloudBackupServiceProvider).download(b.name);
        });
        if (file != null && mounted) await widget.onRestore(file!);
      case 'delete':
        final ok = await AscentDialog.confirm(
          context: context,
          title: 'Delete this cloud backup?',
          content: 'It is removed from the cloud. It cannot be undone.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (ok == true) {
          await _run(() async {
            await _cloud.deleteBackup(b.name);
            ref.invalidate(cloudBackupsProvider);
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(cloudGatewayProvider);
    if (!cloud.available) return const SizedBox.shrink();
    final g = context.glass;
    final user = ref.watch(cloudUserProvider).value ?? cloud.currentUser;
    final children = <Widget>[
      Row(
        children: [
          Icon(Icons.cloud_outlined, size: 20, color: g.inkSecondary),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              'Cloud',
              style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
            ),
          ),
          if (user != null)
            AscentButton.ghost(
              key: const ValueKey('cloud_sign_out'),
              label: 'Sign out',
              compact: true,
              onPressed: _busy ? null : _signOut,
            ),
        ],
      ),
      const SizedBox(height: AppSpace.s4),
      Text(
        user == null
            ? 'Keep an encrypted copy in your own private cloud folder, so a '
                  'new or reset phone gets everything back.'
            : 'Signed in as ${user.email ?? 'you'}. Backups are encrypted '
                  'with your password before they leave the phone.',
        style: AscentTextStyles.supportingText.copyWith(
          color: g.inkSecondary,
        ),
      ),
      const SizedBox(height: AppSpace.s12),
      if (user == null && _codeSentTo == null) ...[
        AppTextField(
          key: const ValueKey('cloud_email'),
          controller: _email,
          hintText: 'e.g. name@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: AppSpace.s12),
        AscentButton.tonal(
          key: const ValueKey('cloud_send_code'),
          label: 'Email me a sign-in code',
          icon: Icons.mail_outline_rounded,
          expanded: true,
          loading: _busy,
          onPressed: _busy ? null : _sendCode,
        ),
      ] else if (user == null) ...[
        Text(
          'We sent a 6-digit code to $_codeSentTo.',
          style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
        ),
        const SizedBox(height: AppSpace.s8),
        AppTextField(
          key: const ValueKey('cloud_code'),
          controller: _code,
          hintText: '6-digit code',
          keyboardType: TextInputType.number,
          autofocus: true,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: AppSpace.s12),
        AscentButton.tonal(
          key: const ValueKey('cloud_verify'),
          label: 'Sign in',
          expanded: true,
          loading: _busy,
          onPressed: _busy ? null : _verify,
        ),
        AscentButton.ghost(
          label: 'Use another email',
          onPressed: _busy
              ? null
              : () => setState(() {
                  _codeSentTo = null;
                  _code.clear();
                }),
        ),
      ] else ...[
        AppTextField(
          key: const ValueKey('cloud_password'),
          controller: _password,
          obscureText: true,
          hintText: 'Backup password (needed to restore)',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _upload(),
        ),
        const SizedBox(height: AppSpace.s12),
        AscentButton.tonal(
          key: const ValueKey('cloud_upload'),
          label: 'Back up to the cloud',
          icon: Icons.cloud_upload_outlined,
          expanded: true,
          loading: _busy,
          onPressed: _busy ? null : _upload,
        ),
        const SizedBox(height: AppSpace.s12),
        _CloudList(onTap: _busy ? null : _actions),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpace.s8),
        Text(
          _error!,
          key: const ValueKey('cloud_error'),
          style: AscentTextStyles.caption.copyWith(color: g.errorInk),
        ),
      ],
    ];
    return Container(
      key: const ValueKey('cloud_section'),
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        borderRadius: AppGeometry.roundedr20,
        border: Border.all(color: g.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CloudList extends ConsumerWidget {
  const _CloudList({required this.onTap});
  final void Function(CloudBackup)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final async = ref.watch(cloudBackupsProvider);
    if (async.isLoading) {
      return Text(
        'Checking the cloud…',
        style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
      );
    }
    if (async.hasError) {
      return Text(
        'Offline · cloud backups show when you are connected.',
        key: const ValueKey('cloud_offline'),
        style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
      );
    }
    final list = async.value ?? const [];
    if (list.isEmpty) {
      return Text(
        'No cloud backups yet.',
        style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
      );
    }
    return Column(
      children: [
        for (final (i, b) in list.indexed) ...[
          Divider(height: 1, thickness: 1, color: g.line),
          InkWell(
            key: ValueKey('cloud_row_$i'),
            onTap: onTap == null ? null : () => onTap!(b),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: g.inkSecondary,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(
                      humanDay(b.createdAt),
                      style: AscentTextStyles.body.copyWith(color: g.ink),
                    ),
                  ),
                  Text(
                    [
                      humanWhen(b.createdAt).split(' at ').last,
                      if (b.bytes > 0)
                        '${(b.bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    ].join(' · '),
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Icon(Icons.more_horiz_rounded, size: 20, color: g.inkMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
