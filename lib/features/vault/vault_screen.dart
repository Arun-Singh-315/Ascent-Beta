import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../shared/widgets/glass_surface.dart';
import 'models/vault_item_model.dart';
import 'providers/vault_providers.dart';
import 'widgets/vault_item_card.dart';
import 'widgets/vault_item_detail_sheet.dart';
import 'widgets/vault_item_editor_sheet.dart';
import 'widgets/vault_lock_view.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> with WidgetsBindingObserver {
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-lock vault when app is backgrounded or hidden
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(vaultSessionUnlockedProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isUnlocked = ref.watch(vaultSessionUnlockedProvider);

    return Scaffold(
      backgroundColor: g.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: g.ink, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ascent Vault',
          style: AscentTextStyles.homeTitle.copyWith(
            color: g.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isUnlocked) ...[
            IconButton(
              icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, color: g.ink),
              onPressed: () {
                setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _searchController.clear();
                    ref.read(vaultSearchQueryProvider.notifier).setQuery('');
                  }
                });
              },
              tooltip: 'Search vault',
            ),
            IconButton(
              icon: Icon(Icons.lock_outline_rounded, color: g.clay),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(vaultSessionUnlockedProvider.notifier).lock();
              },
              tooltip: 'Lock vault now',
            ),
          ],
        ],
      ),
      body: isUnlocked
          ? _buildUnlockedVault(context, g)
          : VaultLockView(
              onUnlocked: () {
                setState(() {});
              },
            ),
      floatingActionButton: isUnlocked
          ? FloatingActionButton.extended(
              backgroundColor: g.clay,
              foregroundColor: Colors.white,
              onPressed: () => VaultItemEditorSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add to Vault', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildUnlockedVault(BuildContext context, AscentGlass g) {
    final items = ref.watch(vaultFilteredItemsProvider);
    final selectedCategory = ref.watch(vaultCategoryFilterProvider);

    return Column(
      children: [
        // ── SEARCH BAR (if open) ──────────────────────────────────────────
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: g.ink, fontSize: 14),
              onChanged: (val) => ref.read(vaultSearchQueryProvider.notifier).setQuery(val),
              decoration: InputDecoration(
                hintText: 'Search cards, IDs, usernames...',
                hintStyle: TextStyle(color: g.inkMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: g.inkMuted, size: 20),
                filled: true,
                fillColor: g.fill.withValues(alpha: 0.25),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: g.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: g.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: g.clay)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

        // ── CATEGORY FILTER CHIPS ─────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: selectedCategory == null,
                  label: const Text('All'),
                  selectedColor: g.clay.withValues(alpha: 0.18),
                  checkmarkColor: g.clay,
                  labelStyle: TextStyle(
                    color: selectedCategory == null ? g.clay : g.inkMuted,
                    fontWeight: selectedCategory == null ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  onSelected: (_) => ref.read(vaultCategoryFilterProvider.notifier).setCategory(null),
                ),
              ),
              ...VaultCategory.values.map((cat) {
                final selected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    label: Text(cat.shortName),
                    selectedColor: g.clay.withValues(alpha: 0.18),
                    checkmarkColor: g.clay,
                    labelStyle: TextStyle(
                      color: selected ? g.clay : g.inkMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) => ref.read(vaultCategoryFilterProvider.notifier).setCategory(cat),
                  ),
                );
              }),
            ],
          ),
        ),

        // ── ITEMS LIST / EMPTY STATE ──────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState(context, g, selectedCategory)
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: AppSpace.s16,
                    right: AppSpace.s16,
                    top: AppSpace.s8,
                    bottom: 88, // padding for FAB
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    return VaultItemCard(
                      item: item,
                      onTap: () => VaultItemDetailSheet.show(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AscentGlass g, VaultCategory? category) {
    final title = category != null ? 'No ${category.displayName} in Vault' : 'Your Vault is Empty';
    final desc = category != null
        ? 'Store and protect your ${category.shortName.toLowerCase()} with AES-256 encryption.'
        : 'Keep payment cards, national IDs, passwords, and private scans encrypted and secure.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.clay.withValues(alpha: 0.1),
                border: Border.all(color: g.clay.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.enhanced_encryption_outlined, color: g.clay, size: 38),
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              title,
              style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              desc,
              style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: g.clay,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => VaultItemEditorSheet.show(context, category: category ?? VaultCategory.card),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Item', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
