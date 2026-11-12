import '../../home/widgets/home_module_row.dart';
import '../../../app/theme/monochrome_surfaces.dart';
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

    if (!isUnlocked) {
      return HomeModuleRow(
        key: const ValueKey('home_vault_card'),
        title: 'Private Vault',
        icon: Icons.lock_outline_rounded,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/vault');
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING (Strict Rule 18 Adherence) ─────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Vault',
            textAlign: TextAlign.center,
            style: AscentTextStyles.interfaceSection.copyWith(
              color: g.ink,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: AppSpace.s12),

        // ── SASSY TRANSPARENT BORDERED SURFACE (Full Width) ────────────
        SizedBox(
          width: double.infinity,
          child: GlassSurface(
            key: const ValueKey('home_vault_card'),
            borderRadius: BorderRadius.zero,
            padding: const EdgeInsets.symmetric(vertical: 22),
            fillColor: Colors.transparent,
            hasShadow: false,
            enableBlur: false,
            customBorder: Border(
              bottom: BorderSide(
                color: MonochromeSurfaces.of(context).separator,
              ),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/vault');
            },
            child: _buildUnlockedContent(context, g, count, items),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: g.sage.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: g.sage.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(Icons.lock_open_rounded, color: g.sage, size: 26),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Text(
          'Vault Unlocked',
          textAlign: TextAlign.center,
          style: AscentTextStyles.interfaceDisplay.copyWith(
            color: g.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count items accessible in secure session',
          textAlign: TextAlign.center,
          style: AscentTextStyles.interfaceLabel.copyWith(color: g.inkMuted),
        ),
        if (count > 0) ...[
          const SizedBox(height: AppSpace.s12),
          Wrap(
            alignment: WrapAlignment.center,
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
