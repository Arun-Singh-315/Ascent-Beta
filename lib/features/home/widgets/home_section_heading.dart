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
    this.showIndicator = true,
    this.showDivider = false,
  });
  final String title;
  final String? subtitle;
  final bool centered;
  final bool cutout;
  final Widget? leading, trailing;
  final Color? dotColor;
  final Color? titleColor;
  final bool showIndicator;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: AscentTextStyles.homeTitle.copyWith(
        color: titleColor ?? design.primaryText,
        fontSize: 17,
        fontWeight: FontWeight.w600,
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
        if (!centered && leading == null && dotColor != null && showIndicator)
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
        else if (!centered && leading == null && showIndicator)
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
            style: HomeType.supporting.copyWith(color: design.secondaryText),
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
          if (showDivider) ...[
            labelContent,
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1.0,
                color: (dotColor ?? design.separator).withValues(alpha: 0.22),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            Expanded(
              child: cutout
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ColoredBox(
                        color: design.canvas,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: labelContent,
                        ),
                      ),
                    )
                  : labelContent,
            ),
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
    this.framed = true,
    this.diagonal = false,
  });

  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final bool framed, diagonal;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final arrowColor =
        color ??
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
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: framed
                  ? HomeDesign.of(context).canvas
                  : Colors.transparent,
              border: framed
                  ? Border.all(
                      color: arrowColor.withValues(alpha: dark ? 0.5 : 0.4),
                      width: 1.1,
                    )
                  : null,
            ),
            child: Icon(
              diagonal ? Icons.north_east_rounded : Icons.arrow_forward_rounded,
              size: 20,
              color: arrowColor,
            ),
          ),
        ),
      ),
    );
  }
}
