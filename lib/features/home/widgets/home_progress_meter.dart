import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';

/// Ten visual intervals representing the actual saved total against its goal.
class HomeProgressMeter extends StatelessWidget {
  const HomeProgressMeter({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final fraction = value.clamp(0.0, 1.0);
    return Semantics(
      label: 'Daily goal progress',
      value: '${(fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var index = 0; index < 10; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  key: ValueKey('home_progress_segment_$index'),
                  height: 13,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: design.wellnessEdge),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (fraction * 10 - index).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: design.wellnessInk),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
