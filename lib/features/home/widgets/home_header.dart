import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../core/services/festival_service.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/capped_chip_wrap.dart';
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

  (String, IconData, String) _getDayPeriodInfo(int hour) {
    if (hour >= 5 && hour < 12) {
      return ('Good morning,', Icons.wb_twilight_rounded, 'Morning focus');
    } else if (hour >= 12 && hour < 17) {
      return ('Good afternoon,', Icons.wb_sunny_rounded, 'Peak hours');
    } else if (hour >= 17 && hour < 21) {
      return ('Good evening,', Icons.wb_twilight_rounded, 'Golden hour');
    } else {
      return ('Good night,', Icons.nights_stay_rounded, 'Quiet hours');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now ?? DateTime.now();
    final day = HomeDayDesign.at(now, dark: dark);
    final (greeting, periodIcon, periodSubtitle) = _getDayPeriodInfo(now.hour);

    final rawName = widget.profile?.name.trim() ?? '';
    final name = rawName.replaceAll(';)', '').trim();
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    final role = widget.profile?.targetRole.trim() ?? '';
    final dob = widget.profile?.dateOfBirth;
    final sign = dob == null ? null : const CosmicProfileService().getZodiac(dob);
    final todayFestival = ref.watch(todayFestivalProvider);
    final assistantName = ref.watch(assistantNameProvider);

    final streak = math.max(
      ref.watch(studyStreakProvider).displayStreakDays,
      ref.watch(currentStreakStreamProvider).value ?? 0,
    );
    final showStreak = streak > 0;

    final quote = todayFestival?.thought ??
        (day.cue.isNotEmpty
            ? day.cue
            : 'Rising with unwavering discipline and offering gratitude to the source of life.');

    final streakLabel = streak >= 30
        ? '$streak · Fire'
        : (streak >= 7 ? '$streak · Blaze' : '$streak');
    final streakIcon = streak >= 30
        ? Icons.whatshot_rounded
        : Icons.local_fire_department_rounded;

    return Container(
      key: const ValueKey('home_day_header'),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        18,
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
          bottom: Radius.circular(AppRadius.header),
        ),
        border: AppBorder.bottom(c.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Profile Avatar | Date + Diurnal subtitle | Weather pill
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

              // Date caption & period
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEE, d MMM').format(now),
                      key: const ValueKey('home_date'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      periodSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Weather capsule
              const SizedBox(width: 8),
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: HomeWeather(),
                ),
              ),
            ],
          ),

          // Row 2: Dynamic greeting + User Name + Role
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                periodIcon,
                size: 14,
                color: c.accent,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            name.isEmpty ? 'Your space' : name,
            key: const ValueKey('home_user_name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          if (role.isNotEmpty && role.toLowerCase() != 'inner peace') ...[
            const SizedBox(height: 2),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ],

          // Row 3: AI Gateway button (Ask Riya) + Streak chip
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Centralized AI Assistant Gateway button (Rule 4)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home_assistant_button'),
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/ai-assistant');
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 120,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: c.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ask $assistantName',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.accent,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Streak Chip
              if (showStreak)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('home_streak_chip'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(studyStreakCardVisibleProvider.notifier).toggle();
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            streakIcon,
                            size: 16,
                            color: c.warn,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            streakLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Row 4: Festival / Rashi contextual chips
          if (todayFestival != null || sign != null) ...[
            const SizedBox(height: 10),
            CappedChipWrap(
              maxRows: 2,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (todayFestival != null)
                  AppChip(
                    key: const ValueKey('home_festival_banner'),
                    icon: Icons.celebration_rounded,
                    iconColor: c.warn,
                    label: 'Happy ${todayFestival.name}! ✨',
                  ),
                if (sign != null)
                  AppChip(
                    key: const ValueKey('home_rashi'),
                    label: '${sign.name} · ${sign.vedicRashi} · ${sign.element.label}',
                  ),
              ],
            ),
          ],

          // Row 5: Quote / Day Cue
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
