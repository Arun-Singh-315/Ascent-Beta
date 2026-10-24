import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/vault_item_model.dart';
import '../providers/vault_providers.dart';
import 'vault_item_editor_sheet.dart';

class VaultItemDetailSheet extends StatefulWidget {
  const VaultItemDetailSheet({
    super.key,
    required this.item,
  });

  final VaultItem item;

  static Future<void> show(BuildContext context, VaultItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VaultItemDetailSheet(item: item),
    );
  }

  @override
  State<VaultItemDetailSheet> createState() => _VaultItemDetailSheetState();
}

class _VaultItemDetailSheetState extends State<VaultItemDetailSheet> {
  bool _revealSecrets = false;

  void _copy(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vault Item?'),
        content: Text(
          'Are you sure you want to delete "${widget.item.title}"? Associated secure scans and encrypted records will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.of(ctx).pop(); // close dialog
              if (widget.item.id != null) {
                await ref.read(vaultStorageServiceProvider).deleteItem(widget.item.id!);
              }
              if (context.mounted) {
                Navigator.of(context).pop(); // close sheet
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final item = widget.item;
    final fields = item.fields;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(AppSpace.s20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : const Color(0xFFF9FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: g.line),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HANDLE ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.inkMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s16),

              // ── TITLE & ACTIONS ─────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: g.clay.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getCategoryIcon(item.category), color: g.clay, size: 22),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.category.displayName,
                          style: AscentTextStyles.caption.copyWith(color: g.clay, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (ctx, ref, _) => Wrap(
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: g.inkMuted, size: 20),
                          onPressed: () {
                            Navigator.of(context).pop();
                            VaultItemEditorSheet.show(context, item: item);
                          },
                          tooltip: 'Edit item',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDelete(context, ref),
                          tooltip: 'Delete item',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),

              // ── REVEAL TOGGLE ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Encrypted Details',
                    style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _revealSecrets = !_revealSecrets),
                    icon: Icon(
                      _revealSecrets ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 16,
                      color: g.clay,
                    ),
                    label: Text(
                      _revealSecrets ? 'Hide Secrets' : 'Reveal Secrets',
                      style: TextStyle(color: g.clay, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),

              // ── STRUCTURED DETAIL TILES ─────────────────────────────────
              ..._buildCategoryDetails(context, g, item, fields),

              // ── ATTACHMENTS ─────────────────────────────────────────────
              if (item.mediaPaths.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s16),
                Text(
                  'Attached Media & Scans (${item.mediaPaths.length})',
                  style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 14),
                ),
                const SizedBox(height: AppSpace.s8),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: item.mediaPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      final path = item.mediaPaths[idx];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(path),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: g.line,
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(VaultCategory category) {
    switch (category) {
      case VaultCategory.card:
        return Icons.credit_card_rounded;
      case VaultCategory.idDoc:
        return Icons.badge_outlined;
      case VaultCategory.login:
        return Icons.key_outlined;
      case VaultCategory.document:
        return Icons.folder_special_outlined;
      case VaultCategory.note:
        return Icons.lock_outline_rounded;
    }
  }

  List<Widget> _buildCategoryDetails(
    BuildContext context,
    AscentGlass g,
    VaultItem item,
    Map<String, dynamic> fields,
  ) {
    final widgets = <Widget>[];

    void addTile(String label, String? value, {bool sensitive = false, bool isMono = false}) {
      if (value == null || value.trim().isEmpty) return;
      final displayValue = sensitive && !_revealSecrets ? '••••••••' : value;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s8),
          child: GlassSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s14, vertical: AppSpace.s10),
            fillColor: context.isDark ? null : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AscentTextStyles.caption.copyWith(color: g.inkMuted, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        displayValue,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 14,
                          fontFamily: isMono ? 'monospace' : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 18, color: g.clay),
                  onPressed: () => _copy(context, value, label),
                  tooltip: 'Copy $label',
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (item.category) {
      case VaultCategory.card:
        addTile('Bank / Issuer', fields['bankName'] as String?);
        addTile('Card Number', fields['cardNumber'] as String?, isMono: true, sensitive: true);
        addTile('Expiry Date', fields['expiry'] as String?, isMono: true);
        addTile('CVV / Security Code', fields['cvv'] as String?, sensitive: true, isMono: true);
        addTile('Cardholder Name', fields['cardholderName'] as String?);
        break;

      case VaultCategory.idDoc:
        addTile('Document Type', fields['docType'] as String?);
        addTile('Document Number', fields['docNumber'] as String?, isMono: true, sensitive: true);
        addTile('Holder Name', fields['holderName'] as String?);
        break;

      case VaultCategory.login:
        addTile('Website / Service', fields['website'] as String?);
        addTile('Username / Email', fields['username'] as String?);
        addTile('Password', fields['password'] as String?, sensitive: true, isMono: true);
        break;

      case VaultCategory.document:
        addTile('Notes', fields['notes'] as String?);
        break;

      case VaultCategory.note:
        addTile('Secret Content', fields['content'] as String?, sensitive: true);
        break;
    }

    return widgets;
  }
}
