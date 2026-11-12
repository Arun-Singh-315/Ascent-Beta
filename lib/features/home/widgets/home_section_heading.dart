import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';

class HomeSectionHeading extends StatelessWidget {
  const HomeSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.centered = false,
    this.leading,
    this.trailing,
    this.cutout = false,
    this.dotColor,
    this.titleColor,
  });
  final String title;
  final String? subtitle;
  final bool centered;
  final bool cutout;
  final Widget? leading, trailing;
  final Color? dotColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: AscentTextStyles.homeTitle.copyWith(
        color: titleColor ?? design.primaryText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );

    // Accent indicator to the left of title
    final effectiveDotColor = dotColor ?? context.accentPrimary;
    final labelContent = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!centered && leading == null && dotColor != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: effectiveDotColor,
                  shape: BoxShape.circle,
                ),
              ),
              Flexible(child: titleWidget),
            ],
          )
        else if (!centered && leading == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: context.accentPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(child: titleWidget),
            ],
          )
        else
          titleWidget,
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: HomeType.supporting.copyWith(
              color: design.secondaryText,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (centered)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48),
              child: leading ?? const SizedBox(width: 48),
            )
          else
            ?leading,
          Expanded(child: labelContent),
          if (centered)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48),
              child: trailing ?? const SizedBox(width: 48),
            )
          else
            ?trailing,
        ],
      ),
    );
  }
}

/// Circular glass launcher button (→) used across all Home section headers
/// for opening their respective full screens (Things, Mindspace, Plans, Commitments).
class HomeSectionArrowButton extends StatelessWidget {
  const HomeSectionArrowButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Open',
    this.color,
  });

  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final arrowColor = color ??
        (dark
            ? SharedControlColors.actionBlueDark
            : SharedControlColors.actionBlue);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.85),
              border: Border.all(
                color: arrowColor.withValues(alpha: dark ? 0.5 : 0.4),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: arrowColor,
            ),
          ),
        ),
      ),
    );
  }
}
