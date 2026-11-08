import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../shared/widgets/glass_surface.dart';

/// Care's visual language: soft mineral surfaces, clear ink and blue actions.
/// The ambient colours are decorative; they never encode a medical status.
class CarePanel extends StatelessWidget {
  const CarePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.hero = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final surface = Theme.of(context).colorScheme.surface;
    return GlassSurface(
      radius: hero ? 28 : 24,
      padding: padding,
      onTap: onTap,
      customBorder: Border.all(color: g.ink.withValues(alpha: .07)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: hero
            ? [
                Color.alphaBlend(
                  const Color(
                    0xFF879783,
                  ).withValues(alpha: g.isDark ? .20 : .17),
                  surface,
                ),
                Color.alphaBlend(
                  const Color(
                    0xFFD4B99A,
                  ).withValues(alpha: g.isDark ? .10 : .17),
                  surface,
                ),
              ]
            : [
                surface,
                Color.alphaBlend(g.sage.withValues(alpha: .025), surface),
              ],
      ),
      child: child,
    );
  }
}

class CareEyebrow extends StatelessWidget {
  const CareEyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: context.glass.inkSecondary,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      height: 1.5,
    ),
  );
}

class CareBloom extends StatelessWidget {
  const CareBloom({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Transform.rotate(
                angle: i * math.pi / 2 + math.pi / 4,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: size * .35,
                    height: size * .59,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF81977E,
                      ).withValues(alpha: .35 + i * .09),
                      borderRadius: BorderRadius.circular(size * .3),
                    ),
                  ),
                ),
              ),
            Container(
              width: size * .35,
              height: size * .35,
              decoration: BoxDecoration(
                color: g.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: size * .19,
                color: g.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CareHero extends StatelessWidget {
  const CareHero({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.child,
    this.compact = false,
  });
  final bool compact;
  final String eyebrow, title;
  final String? description;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.45;
    return CarePanel(
      hero: true,
      padding: EdgeInsets.all(large || compact ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CareEyebrow(eyebrow)),
              const SizedBox(width: 12),
              CareBloom(size: large || compact ? 36 : 52),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: context.glass.ink,
              fontSize: large
                  ? 22
                  : compact
                  ? 27
                  : 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.15,
              height: 1.13,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: TextStyle(
                color: context.glass.inkSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 22), child!],
        ],
      ),
    );
  }
}

class CareIcon extends StatelessWidget {
  const CareIcon(this.icon, {super.key, this.size = 44, this.muted = false});
  final IconData icon;
  final double size;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final blue = g.isDark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (muted ? g.inkMuted : blue).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, size: size * .47, color: muted ? g.inkMuted : blue),
    );
  }
}

class CarePill extends StatelessWidget {
  const CarePill(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.glass.ink.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: context.glass.inkSecondary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: context.glass.inkSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class CareSectionHeading extends StatelessWidget {
  const CareSectionHeading(
    this.title, {
    super.key,
    this.icon = Icons.favorite_border_rounded,
  });
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Icon(icon, size: 18, color: context.glass.inkSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
            ),
          ),
        ),
      ],
    ),
  );
}

IconData careMedicineIcon(String type) => switch (type) {
  'drops' || 'syrup' => Icons.water_drop_outlined,
  'injection' => Icons.vaccines_outlined,
  _ => Icons.medication_outlined,
};
