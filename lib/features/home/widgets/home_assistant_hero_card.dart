import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Minimal Sand & Dusk Hero Gateway Card for Ascent AI Assistant (Aria).
///
/// Follows the design rules:
/// - Plain card: `surface` fill, 1px warm border, very soft shadow.
/// - Small `secondaryContainer` avatar with sparkle icon.
/// - Title: "Ask Aria" (dynamic, defaulting to Aria).
/// - Subtitle: "Plan your day or ask anything".
/// - Soft "Chat" button: `primaryContainer` pill with `onPrimaryContainer` text.
/// - No gradient borders, no glows, no "AI" badge.
class HomeAssistantHeroCard extends ConsumerWidget {
  const HomeAssistantHeroCard({
    super.key,
    this.assistantName,
    this.onTap,
  });

  final String? assistantName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final configuredName = ref.watch(assistantNameProvider);
    final name = assistantName ??
        (configuredName.trim().isEmpty || configuredName == 'Riya'
            ? 'Aria'
            : configuredName.trim());

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxCardWidth = math.min(
      math.max(0.0, screenWidth - 32),
      336.0,
    );

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCardWidth),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: c.border,
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A5C4A3E),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: 'Ask $name',
              child: InkWell(
                key: const ValueKey('home_assistant_button'),
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (onTap != null) {
                    onTap!();
                  } else {
                    context.push('/ai-assistant');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Small secondaryContainer avatar with sparkle icon
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.secondaryContainer,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ask $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Plan your day or ask anything',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Soft "Chat" button
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
