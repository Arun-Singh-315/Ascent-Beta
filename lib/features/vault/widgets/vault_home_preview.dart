import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/vault_item_model.dart';
import '../providers/vault_providers.dart';

class VaultHomePreview extends ConsumerWidget {
  const VaultHomePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isUnlocked = ref.watch(vaultSessionUnlockedProvider);
    final count = ref.watch(vaultItemCountProvider);
    final items = ref.watch(vaultItemsStreamProvider).value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING (Strict Rule 18 Adherence) ─────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Vault',
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/vault');
              },
              icon: Icon(
                isUnlocked ? Icons.lock_open_rounded : Icons.shield_outlined,
                size: 16,
                color: g.clay,
              ),
              label: Text(
                isUnlocked ? 'Open' : 'Unlock',
                style: TextStyle(color: g.clay, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpace.s12),

        // ── UNIFIED GLASS SURFACE ─────────────────────────────────────
        GlassSurface(
          key: const ValueKey('home_vault_card'),
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.all(AppSpace.s16),
          enableBlur: Theme.of(context).brightness == Brightness.light,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/vault');
          },
          child: isUnlocked
              ? _buildUnlockedContent(context, g, count, items)
              : _buildLockedContent(context, g, count),
        ),
      ],
    );
  }

  Widget _buildLockedContent(BuildContext context, AscentGlass g, int count) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: g.clay.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.shield_rounded, color: g.clay, size: 24),
        ),
        const SizedBox(width: AppSpace.s14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encrypted & Locked',
                style: AscentTextStyles.displaySmall.copyWith(
                  color: g.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count > 0
                    ? '$count secure item(s) protected'
                    : 'Cards, IDs, logins & docs',
                style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: g.fill.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: g.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint_rounded, size: 16, color: g.clay),
              const SizedBox(width: 4),
              Text(
                'Unlock',
                style: TextStyle(
                  color: g.clay,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedContent(
    BuildContext context,
    AscentGlass g,
    int count,
    List<VaultItem> items,
  ) {
    final cardCount = items
        .where((i) => i.category == VaultCategory.card)
        .length;
    final idCount = items
        .where((i) => i.category == VaultCategory.idDoc)
        .length;
    final loginCount = items
        .where((i) => i.category == VaultCategory.login)
        .length;
    final otherCount = count - (cardCount + idCount + loginCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: g.sage.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_open_rounded, color: g.sage, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vault Unlocked',
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: g.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count items accessible in secure session',
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (count > 0) ...[
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (cardCount > 0)
                _buildBadge(g, Icons.credit_card, '$cardCount Cards'),
              if (idCount > 0)
                _buildBadge(g, Icons.badge_outlined, '$idCount IDs'),
              if (loginCount > 0)
                _buildBadge(g, Icons.key_outlined, '$loginCount Logins'),
              if (otherCount > 0)
                _buildBadge(g, Icons.folder_outlined, '$otherCount Files'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBadge(AscentGlass g, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: g.fill.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: g.line.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: g.clay),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: g.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
