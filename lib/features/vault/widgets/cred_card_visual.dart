import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';

/// Available luxury card skins inspired by premium card designs.
enum CredCardSkin {
  obsidian,  // HDFC Infinia / CRED Black obsidian with champagne gold trim
  sapphire,  // ICICI Sapphiro / Midnight Navy with platinum trim
  emerald,   // Amex Centurion / Jade Emerald with brass gold trim
  burgundy,  // Axis Magnus / Merlot Silk with rose gold trim
  aurum,     // SBI Aurum / Champagne Royal Gold
  titanium,  // OneCard / Apple Card brushed metal
  aurora,    // Cyber Frost holographic sheen
}

extension CredCardSkinExtension on CredCardSkin {
  String get label {
    switch (this) {
      case CredCardSkin.obsidian:
        return 'Obsidian Black';
      case CredCardSkin.sapphire:
        return 'Midnight Sapphire';
      case CredCardSkin.emerald:
        return 'Imperial Emerald';
      case CredCardSkin.burgundy:
        return 'Burgundy Velvet';
      case CredCardSkin.aurum:
        return 'Royal Aurum Gold';
      case CredCardSkin.titanium:
        return 'Brushed Titanium';
      case CredCardSkin.aurora:
        return 'Holo Cyber Frost';
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case CredCardSkin.obsidian:
        return [const Color(0xFF13151A), const Color(0xFF1E222A), const Color(0xFF0D0F12)];
      case CredCardSkin.sapphire:
        return [const Color(0xFF09142A), const Color(0xFF142952), const Color(0xFF0A1833)];
      case CredCardSkin.emerald:
        return [const Color(0xFF062319), const Color(0xFF0F4232), const Color(0xFF08281E)];
      case CredCardSkin.burgundy:
        return [const Color(0xFF2E0914), const Color(0xFF4E1426), const Color(0xFF24060F)];
      case CredCardSkin.aurum:
        return [const Color(0xFF2B200A), const Color(0xFF523E17), const Color(0xFF261C08)];
      case CredCardSkin.titanium:
        return [const Color(0xFF22252C), const Color(0xFF383D48), const Color(0xFF1C1E24)];
      case CredCardSkin.aurora:
        return [const Color(0xFF112238), const Color(0xFF1A385C), const Color(0xFF16253B)];
    }
  }

  Color get borderColor {
    switch (this) {
      case CredCardSkin.obsidian:
        return const Color(0xFFD4AF37).withValues(alpha: 0.35);
      case CredCardSkin.sapphire:
        return const Color(0xFF64B5F6).withValues(alpha: 0.35);
      case CredCardSkin.emerald:
        return const Color(0xFF81C784).withValues(alpha: 0.35);
      case CredCardSkin.burgundy:
        return const Color(0xFFF48FB1).withValues(alpha: 0.35);
      case CredCardSkin.aurum:
        return const Color(0xFFFFD54F).withValues(alpha: 0.45);
      case CredCardSkin.titanium:
        return const Color(0xFFE0E0E0).withValues(alpha: 0.35);
      case CredCardSkin.aurora:
        return const Color(0xFF80DEEA).withValues(alpha: 0.45);
    }
  }

  Color get metallicAccent {
    switch (this) {
      case CredCardSkin.obsidian:
      case CredCardSkin.aurum:
      case CredCardSkin.emerald:
        return const Color(0xFFE5C07B);
      case CredCardSkin.sapphire:
      case CredCardSkin.titanium:
      case CredCardSkin.aurora:
        return const Color(0xFFE2E8F0);
      case CredCardSkin.burgundy:
        return const Color(0xFFFFAB91);
    }
  }
}

class CredCardTheme {
  const CredCardTheme._();

  /// Automatically matches bank / tier keywords to the most authentic card skin.
  static CredCardSkin resolve(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('infinia') || lower.contains('hdfc') || lower.contains('black') || lower.contains('regalia')) {
      return CredCardSkin.obsidian;
    }
    if (lower.contains('sapphiro') || lower.contains('icici') || lower.contains('navy') || lower.contains('coral') || lower.contains('standard chartered')) {
      return CredCardSkin.sapphire;
    }
    if (lower.contains('magnus') || lower.contains('axis') || lower.contains('burgundy') || lower.contains('merlot') || lower.contains('atlas')) {
      return CredCardSkin.burgundy;
    }
    if (lower.contains('aurum') || lower.contains('sbi') || lower.contains('gold') || lower.contains('champagne')) {
      return CredCardSkin.aurum;
    }
    if (lower.contains('amex') || lower.contains('american express') || lower.contains('emerald') || lower.contains('centurion')) {
      return CredCardSkin.emerald;
    }
    if (lower.contains('onecard') || lower.contains('apple') || lower.contains('metal') || lower.contains('titanium') || lower.contains('slate')) {
      return CredCardSkin.titanium;
    }
    if (lower.contains('cyber') || lower.contains('frost') || lower.contains('aurora') || lower.contains('neo')) {
      return CredCardSkin.aurora;
    }
    return CredCardSkin.obsidian;
  }
}

/// A photorealistic CRED-grade physical card rendering widget.
class CredCardVisual extends StatefulWidget {
  const CredCardVisual({
    super.key,
    required this.bankName,
    required this.cardTier,
    required this.cardholderName,
    required this.cardNumber,
    required this.expiryDate,
    required this.cardBrand,
    this.skin,
    this.showActions = true,
    this.onTap,
    this.onCardSaved,
  });

  final String bankName;
  final String cardTier;
  final String cardholderName;
  final String cardNumber;
  final String expiryDate;
  final String cardBrand;
  final CredCardSkin? skin;
  final bool showActions;
  final VoidCallback? onTap;
  final ValueChanged<String>? onCardSaved;

  @override
  State<CredCardVisual> createState() => _CredCardVisualState();
}

class _CredCardVisualState extends State<CredCardVisual> {
  bool _revealed = false;
  final GlobalKey _cardRepaintKey = GlobalKey();
  bool _isExporting = false;

  CredCardSkin get _resolvedSkin =>
      widget.skin ?? CredCardTheme.resolve('${widget.bankName} ${widget.cardTier}');

  String _formatCardNumber(String raw, bool revealed) {
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '•••• •••• •••• ••••';

    if (revealed) {
      final buffer = StringBuffer();
      for (int i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(clean[i]);
      }
      return buffer.toString();
    } else {
      final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
      return '•••• •••• •••• $last4';
    }
  }

  Future<void> _saveAndShareCardImage(BuildContext context) async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);

    try {
      final boundary = _cardRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/ascent_card_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      widget.onCardSaved?.call(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 20),
                SizedBox(width: 10),
                Text('CRED-style card image ready!'),
              ],
            ),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.amberAccent,
              onPressed: () {
                Share.shareXFiles([XFile(file.path)], text: '${widget.bankName} ${widget.cardTier} Card');
              },
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Also offer native share sheet directly
        await Share.shareXFiles([XFile(file.path)], text: '${widget.bankName} ${widget.cardTier} Card');
      }
    } catch (e) {
      debugPrint('Error exporting card image: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final skin = _resolvedSkin;
    final formattedNumber = _formatCardNumber(widget.cardNumber, _revealed);
    final cleanHolder = widget.cardholderName.trim().isEmpty ? 'CARDHOLDER' : widget.cardholderName.trim().toUpperCase();
    final cleanBank = widget.bankName.trim().isEmpty ? 'Ascent Bank' : widget.bankName.trim();
    final cleanTier = widget.cardTier.trim().isEmpty ? 'Signature' : widget.cardTier.trim();
    final cleanExpiry = widget.expiryDate.trim().isEmpty ? '12/28' : widget.expiryDate.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── CARD CANVAS WITH REPAINT BOUNDARY ───────────────────────────
        GestureDetector(
          onTap: widget.onTap,
          child: RepaintBoundary(
            key: _cardRepaintKey,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpace.s6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: skin.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: skin.borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Diagonal Holographic Sheen
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-1.5, -1.0),
                              end: const Alignment(1.5, 1.0),
                              stops: const [0.0, 0.45, 0.55, 1.0],
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.05),
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card Content
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── TOP ROW: BANK NAME & CONTACTLESS ICON ───
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        cleanBank,
                                        style: TextStyle(
                                          color: skin.metallicAccent,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        cleanTier,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.s12),
                              Icon(
                                Icons.contactless_rounded,
                                color: skin.metallicAccent.withValues(alpha: 0.85),
                                size: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s16),

                          // ── EMV CHIP GRAPHIC ────────────────────────
                          const EmvChipWidget(),
                          const SizedBox(height: AppSpace.s18),

                          // ── EMBOSSED CARD NUMBER ────────────────────
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formattedNumber,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.2,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    offset: const Offset(0, 1.5),
                                    blurRadius: 3,
                                  ),
                                  Shadow(
                                    color: skin.metallicAccent.withValues(alpha: 0.3),
                                    offset: const Offset(0, -0.5),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.s16),

                          // ── BOTTOM ROW: HOLDER, EXPIRY & BRAND LOGO ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Cardholder Name
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CARDHOLDER',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        cleanHolder,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.s8),

                              // Expiry
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VALID THRU',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.45),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'EXP: $cleanExpiry',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpace.s8),

                              // Brand Badge
                              _CardBrandBadge(brand: widget.cardBrand),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── INTERACTIVE CONTROLS (Reveal, Copy, Download Image) ─────────
        if (widget.showActions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Eye reveal toggle
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _revealed = !_revealed);
                  },
                  icon: Icon(
                    _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16,
                    color: g.inkMuted,
                  ),
                  label: Text(
                    _revealed ? 'Hide Number' : 'Reveal Number',
                    style: TextStyle(color: g.inkMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),

                Wrap(
                  spacing: 4,
                  children: [
                    // Copy card number
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: 18, color: g.clay),
                      tooltip: 'Copy card number',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: widget.cardNumber.replaceAll(RegExp(r'\s+'), '')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Card number copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),

                    // Download / Export Card Image (CRED-style snapshot)
                    IconButton(
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.download_rounded, size: 18, color: g.clay),
                      tooltip: 'Save card image (CRED style)',
                      onPressed: () => _saveAndShareCardImage(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Realistic brass EMV Chip with circuit contact traces.
class EmvChipWidget extends StatelessWidget {
  const EmvChipWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [Color(0xFFE5C07B), Color(0xFFD4AF37), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EmvChipPainter(),
      ),
    );
  }
}

class _EmvChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B6B23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Horizontal contact boundary lines
    canvas.drawLine(Offset(0, size.height * 0.33), Offset(size.width, size.height * 0.33), paint);
    canvas.drawLine(Offset(0, size.height * 0.67), Offset(size.width, size.height * 0.67), paint);

    // Vertical contact boundary lines
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), paint);

    // Inner rounded center pad
    final innerPaint = Paint()
      ..color = const Color(0xFF9E7C2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final centerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.32,
        height: size.height * 0.36,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(centerRect, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official brand logos (Visa, Mastercard, RuPay, Amex, Discover).
class _CardBrandBadge extends StatelessWidget {
  const _CardBrandBadge({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    final lower = brand.toLowerCase();
    if (lower.contains('visa')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'VISA',
          style: TextStyle(
            color: Color(0xFF1A1F71),
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (lower.contains('mastercard')) {
      return SizedBox(
        width: 38,
        height: 24,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEB001B),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF79E1B).withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (lower.contains('rupay')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RuPay',
              style: TextStyle(
                color: Color(0xFF0C4688),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.play_arrow_rounded, color: Color(0xFFF37021), size: 10),
          ],
        ),
      );
    } else if (lower.contains('amex') || lower.contains('american express')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF006FCF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'AMEX',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // Default generic card badge
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        brand.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
