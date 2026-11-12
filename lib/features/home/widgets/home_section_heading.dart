import 'package:flutter/material.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/home_design.dart';
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
  });
  final String title;
  final String? subtitle;
  final bool centered;
  final bool cutout;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final titleWidget = Text(
      title,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: AscentTextStyles.homeTitle.copyWith(
        color: design.primaryText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );

    // For non-centered headings, add a 3×16 accent bar to the left of title
    final labelContent = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!centered)
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
