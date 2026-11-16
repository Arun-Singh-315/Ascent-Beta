import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../core/services/festival_service.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_chip.dart';
import 'home_day_design.dart';
import 'home_weather.dart';

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({super.key, required this.profile, this.now});
  final UserProfile? profile;
  final DateTime? now;

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader> {
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now ?? DateTime.now();
    final day = HomeDayDesign.at(now, dark: dark);
    final rawName = widget.profile?.name.trim() ?? '';
    final name = rawName.replaceAll(';)', '').trim();
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    final dob = widget.profile?.dateOfBirth;
    final sign = dob == null ? null : const CosmicProfileService().getZodiac(dob);
    final todayFestival = ref.watch(todayFestivalProvider);
    final streak = math.max(
      ref.watch(studyStreakProvider).displayStreakDays,
      ref.watch(currentStreakStreamProvider).value ?? 0,
    );
    final showStreak = streak > 0;

    final quote = todayFestival?.thought ??
        (day.cue.isNotEmpty ? day.cue : 'Rising with unwavering discipline and offering gratitude to the source of life.');

    return Container(
      key: const ValueKey('home_day_header'),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.headerTop,
            dark ? c.surfaceAlt : c.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Rd.header),
        ),
        border: Border(
          bottom: BorderSide(
            color: c.border.withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : c.border).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar | Date | Weather pill (right)
          Row(
            children: [
              // Avatar
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('home_profile_button'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/settings');
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accentTint,
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Centre: Date caption
              Expanded(
                child: Text(
                  DateFormat('EEE, d MMM').format(now),
                  key: const ValueKey('home_date'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),

              // Right: Weather capsule (no redundant icon button beside day/night toggle)
              const SizedBox(width: 8),
              const Flexible(
                child: HomeWeather(),
              ),
            ],
          ),

          // Row 2: Greeting & Name (top margin 20)
          const SizedBox(height: 20),
          Text(
            day.greeting,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name.isEmpty ? 'Your day, your pace.' : name,
            key: const ValueKey('home_user_name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.2,
            ),
          ),

          // Row 3: Chip row (top margin 14) — uses Wrap to guarantee zero horizontal scrolling!
          if (todayFestival != null || sign != null || showStreak) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (todayFestival != null)
                  AppChip(
                    key: const ValueKey('home_festival_banner'),
                    icon: Icons.wb_sunny_rounded,
                    iconColor: c.warn,
                    label: 'Happy ${todayFestival.name}! ✨',
                  ),
                if (sign != null)
                  AppChip(
                    key: const ValueKey('home_rashi'),
                    label: '${sign.name} · ${sign.vedicRashi} · ${sign.element.label}',
                  ),
                if (showStreak)
                  AppChip(
                    key: const ValueKey('home_streak_chip'),
                    icon: Icons.local_fire_department_rounded,
                    iconColor: c.warn,
                    label: '$streak day streak',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(studyStreakCardVisibleProvider.notifier).toggle();
                    },
                  ),
              ],
            ),
          ],

          // Row 4: Quote line in italic textSecondary, max 2 lines (top margin 12)
          const SizedBox(height: 12),
          Text(
            quote,
            key: const ValueKey('home_day_cue'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
