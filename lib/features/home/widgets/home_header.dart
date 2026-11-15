import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../core/services/festival_service.dart';
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
          colors: [c.headerTop, c.bg],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Rd.header),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar | Date | Weather & Theme actions
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),

              // Right: Weather & Theme action buttons (40px outlined circle, surface fill)
              _HeaderIconButton(
                key: const ValueKey('home_weather_button'),
                icon: Icons.wb_sunny_outlined,
                tooltip: 'Weather',
                onTap: () => showWeatherForecastSheet(context),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                key: const ValueKey('home_day_night_toggle'),
                icon: dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                tooltip: dark ? 'Day mode' : 'Night mode',
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
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

          // Row 3: Scrollable chip row (top margin 14)
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                if (todayFestival != null) ...[
                  AppChip(
                    key: const ValueKey('home_festival_banner'),
                    icon: Icons.wb_sunny_rounded,
                    iconColor: c.warn,
                    label: 'Happy ${todayFestival.name}! ✨',
                  ),
                  const SizedBox(width: 8),
                ],
                if (sign != null) ...[
                  AppChip(
                    key: const ValueKey('home_rashi'),
                    label: '${sign.name} · ${sign.vedicRashi} · ${sign.element.label}',
                  ),
                  const SizedBox(width: 8),
                ],
                const HomeWeather(),
              ],
            ),
          ),

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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}
