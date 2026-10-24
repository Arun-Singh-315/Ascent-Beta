import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/vault_item_model.dart';
import 'cred_card_visual.dart';

class VaultItemCard extends StatefulWidget {
  const VaultItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavoriteToggle,
  });

  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  State<VaultItemCard> createState() => _VaultItemCardState();
}

class _VaultItemCardState extends State<VaultItemCard> {
  bool _revealed = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final item = widget.item;

    switch (item.category) {
      case VaultCategory.card:
        return _buildPaymentCard(context, g);
      case VaultCategory.idDoc:
        return _buildIdDocCard(context, g);
      case VaultCategory.login:
        return _buildLoginCard(context, g);
      case VaultCategory.document:
        return _buildDocumentCard(context, g);
      case VaultCategory.note:
        return _buildNoteCard(context, g);
    }
  }

  // ── 1. PAYMENT CARD (CRED-Style Luxury Physical Card Visual) ───────────
  Widget _buildPaymentCard(BuildContext context, AscentGlass g) {
    final fields = widget.item.fields;
    final cardNumber = fields['cardNumber'] as String? ?? '';
    final bankName = fields['bankName'] as String? ?? widget.item.title;
    final cardTier = fields['cardTier'] as String? ?? (fields['cardType'] as String? ?? '');
    final cardBrand = fields['cardBrand'] as String? ?? 'Card';
    final cardholder = fields['cardholderName'] as String? ?? '';
    final expiry = fields['expiry'] as String? ?? '';
    final skinName = fields['skin'] as String?;
    final CredCardSkin? skin = skinName != null
        ? CredCardSkin.values.firstWhere(
            (s) => s.name == skinName,
            orElse: () => CredCardTheme.resolve('$bankName $cardTier'),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: CredCardVisual(
        bankName: bankName,
        cardTier: cardTier,
        cardholderName: cardholder,
        cardNumber: cardNumber,
        expiryDate: expiry,
        cardBrand: cardBrand,
        skin: skin,
        onTap: widget.onTap,
      ),
    );
  }

  // ── 2. ID DOCUMENT CARD ───────────────────────────────────────────────
  Widget _buildIdDocCard(BuildContext context, AscentGlass g) {
    final fields = widget.item.fields;
    final docType = fields['docType'] as String? ?? 'Official ID';
    final docNumber = fields['docNumber'] as String? ?? '';
    final holderName = fields['holderName'] as String? ?? '';

    final maskedNumber = _revealed
        ? docNumber
        : (docNumber.length > 4
            ? '${docNumber.substring(0, 2)}••••${docNumber.substring(docNumber.length - 2)}'
            : '••••');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(AppSpace.s16),
        fillColor: context.isDark ? null : Colors.white,
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: g.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.badge_outlined, color: g.clay, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.title,
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: g.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: g.line.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          docType,
                          style: TextStyle(fontSize: 10, color: g.inkMuted, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          maskedNumber,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: g.inkMuted,
                          ),
                        ),
                      ),
                      if (holderName.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.s6),
                        Text(
                          holderName,
                          style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (docNumber.isNotEmpty)
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 18, color: g.clay),
                onPressed: () => _copyToClipboard(context, docNumber, '$docType number'),
                tooltip: 'Copy document number',
              ),
          ],
        ),
      ),
    );
  }

  // ── 3. LOGIN & CREDENTIAL CARD ─────────────────────────────────────────
  Widget _buildLoginCard(BuildContext context, AscentGlass g) {
    final fields = widget.item.fields;
    final username = fields['username'] as String? ?? '';
    final password = fields['password'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(AppSpace.s16),
        fillColor: context.isDark ? null : Colors.white,
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: g.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.key_outlined, color: g.clay, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    username.isNotEmpty ? username : 'No username',
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (password.isNotEmpty)
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 18, color: g.clay),
                onPressed: () => _copyToClipboard(context, password, 'Password'),
                tooltip: 'Copy password',
              ),
          ],
        ),
      ),
    );
  }

  // ── 4. SECURE DOCUMENT / FILE CARD ────────────────────────────────────
  Widget _buildDocumentCard(BuildContext context, AscentGlass g) {
    final mediaCount = widget.item.mediaPaths.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(AppSpace.s16),
        fillColor: context.isDark ? null : Colors.white,
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: g.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.folder_special_outlined, color: g.clay, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    mediaCount > 0 ? '$mediaCount private file(s) attached' : 'No attachments',
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  // ── 5. PRIVATE NOTE CARD ──────────────────────────────────────────────
  Widget _buildNoteCard(BuildContext context, AscentGlass g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(AppSpace.s16),
        fillColor: context.isDark ? null : Colors.white,
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: g.clay.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_outline_rounded, color: g.clay, size: 22),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'Confidential Encrypted Note',
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
