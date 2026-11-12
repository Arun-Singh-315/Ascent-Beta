import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/glass_theme.dart';
import 'home_day_design.dart';
import 'home_header_scene.dart';

class HomeCompactHeader extends StatelessWidget {
  const HomeCompactHeader({
    super.key,
    required this.name,
    required this.onReturnToTop,
    this.now,
  });
  final String name;
  final VoidCallback onReturnToTop;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final time = now ?? DateTime.now();
    final g = context.glass;
    final design = HomeDesign.of(context);
    return Material(
      key: const ValueKey('home_compact_header'),
      color: design.surface,
      child: InkWell(
        onTap: onReturnToTop,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: g.line.withValues(alpha: .8), width: .8)),
            boxShadow: [
              BoxShadow(
                color: g.shadow.withValues(alpha: .06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              ExcludeSemantics(
                child: ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: HomeHeaderScene(
                      flat: true,
                      now: time,
                      child: FittedBox(child: HomeCelestialMark(now: time)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      HomeDayDesign.at(time).greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: g.inkMuted),
                    ),
                    Text(
                      name.trim().isEmpty ? 'Your day' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Return to top',
                child: Icon(Icons.keyboard_arrow_up_rounded, color: g.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
