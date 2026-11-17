import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.onOpen,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onOpen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: AppBorder.all(c.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: c.warmShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(AppRadius.iconChip),
                ),
                child: Icon(icon, size: 18, color: c.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: trailing!,
                  ),
                ),
              ],
              if (onOpen != null)
                InkResponse(
                  onTap: onOpen,
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.chevron_right_rounded, size: 22, color: c.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
