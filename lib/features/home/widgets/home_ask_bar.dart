import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/brand_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/settings_provider.dart';
import '../../ai_assistant/assistant_suggestions.dart';

/// "Ask Riya anything…" near the top of Home, with two suggestions for the
/// time of day. The assistant is the glue of the app, so it sits where the
/// thumb starts, not at the bottom of the feed.
class HomeAskBar extends ConsumerWidget {
  const HomeAskBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final name = ref.watch(assistantNameProvider);
    final suggestions = assistantSuggestions(DateTime.now()).take(2).toList();
    void open([String? prompt]) {
      HapticFeedback.selectionClick();
      context.open(
        prompt == null
            ? '/ai-assistant'
            : '/ai-assistant?prompt=${Uri.encodeComponent(prompt)}',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Ask $name',
            child: InkWell(
              key: const ValueKey('home_ask_bar'),
              borderRadius: BorderRadius.circular(24),
              onTap: open,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                decoration: BoxDecoration(
                  color: g.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: BrandPalette.assistantViolet.withValues(alpha: .35),
                  ),
                  boxShadow: g.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: BrandPalette.assistantIndigo.withValues(
                              alpha: .10,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            BrandPalette.assistantIndigo,
                            BrandPalette.assistantViolet,
                            BrandPalette.assistantPink,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        'Ask $name anything…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.body.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                    ),
                    Icon(Icons.mic_none_rounded, color: g.inkMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, i) => ActionChip(
                key: ValueKey('home_ask_suggestion_$i'),
                avatar: Icon(
                  Icons.north_east_rounded,
                  size: 14,
                  color: g.actionInk,
                ),
                label: Text(
                  suggestions[i],
                  style: AscentTextStyles.caption.copyWith(color: g.ink),
                ),
                backgroundColor: g.surface.withValues(alpha: .7),
                side: BorderSide(color: g.line),
                shape: const StadiumBorder(),
                onPressed: () => open(suggestions[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
