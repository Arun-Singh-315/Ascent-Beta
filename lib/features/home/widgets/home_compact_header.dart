import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../capture/capture_button.dart';
import 'home_day_design.dart';

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
    final c = context.c;
    final time = now ?? DateTime.now();
    final cleanName = name.replaceAll(';)', '').trim();
    final greeting = cleanName.isEmpty
        ? 'Good day'
        : '${HomeDayDesign.at(time).greeting} $cleanName';
    final initial = cleanName.isEmpty ? 'A' : cleanName[0].toUpperCase();

    return Material(
      key: const ValueKey('home_compact_header'),
      color: c.surface.withValues(alpha: 0.95),
      child: InkWell(
        onTap: onReturnToTop,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentTint,
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const CaptureButton.nav(),
            ],
          ),
        ),
      ),
    );
  }
}
