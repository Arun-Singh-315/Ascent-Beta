import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../../shared/widgets/locked_commitment_tile.dart';

/// Keeps private details and editor drafts covered whenever the session relocks.
class PromisePrivacyGuard extends ConsumerWidget {
  const PromisePrivacyGuard({
    super.key,
    required this.promise,
    required this.child,
  });
  final PromiseModel promise;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(promiseByIdProvider(promise.id)).value ?? promise;
    if (!current.isPrivate ||
        ref.watch(unlockedPromiseIdsProvider).contains(current.id)) {
      return child;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LockedCommitmentTile(
          label: 'Private commitment',
          onTap: () async {
            final authenticated = await ref
                .read(vaultSecurityServiceProvider)
                .authenticateBiometrics(reason: 'Unlock private commitment');
            if (authenticated && context.mounted) {
              ref.read(unlockedPromiseIdsProvider.notifier).unlock(current.id);
            }
          },
        ),
      ),
    );
  }
}
