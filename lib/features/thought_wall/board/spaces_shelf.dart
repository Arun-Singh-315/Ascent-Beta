import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import 'board_cards.dart';
import 'board_logic.dart';
import 'space_style.dart';

final pinnedSpacesProvider =
    NotifierProvider<PinnedSpacesNotifier, Set<String>>(
      PinnedSpacesNotifier.new,
    );

class PinnedSpacesNotifier extends Notifier<Set<String>> {
  static const _prefKey = 'pinned_spaces_keys_v1';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(_prefKey)?.toSet() ?? <String>{};
  }

  Future<void> toggle(String spaceKey) async {
    final next = Set<String>.from(state);
    if (!next.add(spaceKey)) {
      next.remove(spaceKey);
    }
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_prefKey, next.toList());
  }
}

/// A distinct navigation section, with creation separate from saved spaces.
class SpacesShelf extends ConsumerWidget {
  const SpacesShelf({
    super.key,
    required this.spaces,
    required this.archivedCount,
    required this.onOpen,
    required this.onNew,
    required this.onOpenArchive,
  });

  final List<SpaceSummary> spaces;
  final int archivedCount;
  final ValueChanged<SpaceSummary> onOpen;
  final VoidCallback onNew;
  final VoidCallback onOpenArchive;

  void _showAllSpacesSheet(
    BuildContext context,
    WidgetRef ref,
    Set<String> pinned,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _AllSpacesSheet(spaces: spaces, onOpen: onOpen, onNew: onNew),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final pinned = ref.watch(pinnedSpacesProvider);

    // Sort: pinned spaces first, then remaining spaces in original order
    final sorted = List<SpaceSummary>.from(spaces)
      ..sort((a, b) {
        final aPinned = pinned.contains(a.key);
        final bPinned = pinned.contains(b.key);
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        return 0;
      });

    // Display at most 2 spaces on the shelf so they fit comfortably on phone screens
    const maxOnShelf = 2;
    final displaySpaces = sorted.take(maxOnShelf).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        key: const ValueKey('spaces_shelf'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: g.controlOutline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Spaces',
                      style: AscentTextStyles.sectionHeading.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: g.claySoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: g.line.withValues(alpha: g.isDark ? 0.35 : 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${spaces.length}',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.clay,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                _CompactNewSpaceButton(onTap: onNew),
              ],
            ),
            const SizedBox(height: 14),
            if (displaySpaces.isEmpty)
              Text(
                'Give your thoughts a place to belong.',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final space in displaySpaces)
                  _CompactSpacePill(
                    key: ValueKey('space_tile_${space.key}'),
                    icon: spaceStyleFor(space.name).icon,
                    label: space.name,
                    accent: spaceAccentFor(g, space.key),
                    count: space.total,
                    isPinned: pinned.contains(space.key),
                    onTap: () => onOpen(space),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      final willPin = !pinned.contains(space.key);
                      ref.read(pinnedSpacesProvider.notifier).toggle(space.key);
                      AscentSnackBar.show(
                        context,
                        message: willPin
                            ? 'Pinned "${space.name}" to shelf'
                            : 'Unpinned "${space.name}"',
                        icon: willPin
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      );
                    },
                  ),
                if (archivedCount > 0)
                  _CompactSpacePill(
                    key: const ValueKey('space_tile_archive'),
                    icon: Icons.archive_outlined,
                    label: 'Archive',
                    accent: g.inkMuted,
                    count: archivedCount,
                    onTap: onOpenArchive,
                  ),
                TextButton.icon(
                  key: const ValueKey('space_tile_all'),
                  onPressed: () => _showAllSpacesSheet(context, ref, pinned),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNewSpaceButton extends StatelessWidget {
  const _CompactNewSpaceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      key: const ValueKey('space_tile_new'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: g.primaryButtonBg.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: g.primaryButtonBg.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: g.primaryButtonBg),
              const SizedBox(width: 4),
              Text(
                'New space',
                style: AscentTextStyles.labelMedium.copyWith(
                  color: g.primaryButtonBg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactSpacePill extends StatelessWidget {
  const _CompactSpacePill({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.onLongPress,
    this.count,
    this.isPinned = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int? count;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: g.recessed,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPinned
                  ? g.clay.withValues(alpha: 0.6)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08)),
              width: isPinned ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: g.ink,
                    fontWeight: isPinned ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isPinned) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.push_pin_rounded,
                  size: 10,
                  color: g.primaryButtonBg,
                ),
              ],
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: g.primaryButtonBg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: g.primaryButtonBg.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: g.primaryButtonBg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSpacesSheet extends ConsumerStatefulWidget {
  const _AllSpacesSheet({
    required this.spaces,
    required this.onOpen,
    required this.onNew,
  });

  final List<SpaceSummary> spaces;
  final ValueChanged<SpaceSummary> onOpen;
  final VoidCallback onNew;

  @override
  ConsumerState<_AllSpacesSheet> createState() => _AllSpacesSheetState();
}

class _AllSpacesSheetState extends ConsumerState<_AllSpacesSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final pinned = ref.watch(pinnedSpacesProvider);

    final filtered = widget.spaces.where((s) {
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final aPinned = pinned.contains(a.key);
      final bPinned = pinned.contains(b.key);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return 0;
    });

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s20,
            0,
            AppSpace.s20,
            AppSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'All Spaces',
                    style: AscentTextStyles.sectionHeading.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: g.claySoft.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.spaces.length}',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.clay,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNew();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New space'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              TextField(
                onChanged: (val) => setState(() => _query = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search spaces...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: g.inkMuted,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: g.fill.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: g.line.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: g.line.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Flexible(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s24),
                          child: Text(
                            'No spaces found',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final space = filtered[index];
                          final isPinned = pinned.contains(space.key);
                          final accent = spaceAccentFor(g, space.key);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s8,
                              vertical: 2,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                spaceStyleFor(space.name).icon,
                                size: 18,
                                color: accent,
                              ),
                            ),
                            title: Text(
                              space.name,
                              style: AscentTextStyles.labelLarge.copyWith(
                                color: g.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${space.total} entries · ${space.done} done',
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: g.inkSecondary,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: isPinned
                                  ? 'Unpin from shelf'
                                  : 'Pin to shelf',
                              icon: Icon(
                                isPinned
                                    ? Icons.push_pin_rounded
                                    : Icons.push_pin_outlined,
                                size: 18,
                                color: isPinned ? g.clay : g.inkMuted,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(pinnedSpacesProvider.notifier)
                                    .toggle(space.key);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onOpen(space);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
