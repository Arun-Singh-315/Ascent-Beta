import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/merlot_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _companyInputController = TextEditingController();
  List<String> _targetCompanies = [];
  DateTime? _interviewDate;
  int _weeklyHours = 10;
  String _studyWindow = 'morning';
  bool _profileLoaded = false;

  // Collapsible section visibility states to keep UI calm & decluttered
  bool _expandCareerGoals = false;
  bool _expandGpsTelemetry = false;
  bool _expandDataStorage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _companyInputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileStreamProvider).value;
    if (profile != null) {
      _initFromProfile(profile);
    }
  }

  void _initFromProfile(UserProfile? profile) {
    if (profile == null || _profileLoaded) return;
    _profileLoaded = true;
    _nameController.text = profile.name;
    _roleController.text = profile.targetRole;
    _interviewDate = profile.interviewDate;
    _weeklyHours = profile.weeklyHoursAvailable;
    _studyWindow = profile.preferredStudyWindow;
    try {
      final decoded = jsonDecode(profile.targetCompanies) as List<dynamic>;
      _targetCompanies = decoded.map((e) => e.toString()).toList();
    } catch (_) {
      _targetCompanies = [];
    }
  }

  bool _isSaving = false;
  bool _savedSuccess = false;

  Future<void> _persistAndReturn() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final current = await profileDao.getProfile();

      await profileDao.upsertProfile(
        UserProfileTableCompanion(
          id: drift.Value(current?.id ?? 1),
          name: drift.Value(_nameController.text.trim()),
          targetRole: drift.Value(_roleController.text.trim()),
          targetCompanies: drift.Value(jsonEncode(_targetCompanies)),
          interviewDate: drift.Value(_interviewDate),
          weeklyHoursAvailable: drift.Value(_weeklyHours),
          preferredStudyWindow: drift.Value(_studyWindow),
          onboardingComplete: const drift.Value(true),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) {
        setState(() {
          _savedSuccess = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  void _confirmResetData() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
      ),
      builder: (ctx) {
        final g = ctx.glass;
        return Container(
          padding: const EdgeInsets.all(AppSpace.s24),
          decoration: BoxDecoration(
            color: g.bg,
            borderRadius: const BorderRadius.vertical(
              top: AppGeometry.radiusr24,
            ),
            border: Border(
              top: BorderSide(
                color: g.coral.withValues(alpha: 0.3),
                width: AppBorderScale.w1point5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTag(
                  width: 50,
                  height: 50,
                  nightDecoration: BoxDecoration(
                    color: g.coralSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: g.coral.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: g.coral,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reset All Data?',
                  style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will wipe all tasks, applications, consistency history, and reset your onboarding flow. This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: g.inkMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AscentButton.outlined(
                        label: 'Cancel',
                        compact: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AscentButton.destructive(
                        label: 'Reset Everything',
                        onPressed: () async {
                          final nav = Navigator.of(ctx);
                          nav.pop();
                          final prefs = ref.read(sharedPreferencesProvider);
                          await prefs.clear();
                          final db = ref.read(databaseProvider);
                          await db.customStatement(
                            'DELETE FROM insight_dismissals;',
                          );
                          await db.customStatement(
                            'DELETE FROM interview_prep;',
                          );
                          await db.customStatement('DELETE FROM resumes;');
                          await db.customStatement(
                            'DELETE FROM application_status_history;',
                          );
                          await db.customStatement('DELETE FROM applications;');
                          await db.customStatement('DELETE FROM tasks;');
                          await db.customStatement('DELETE FROM series;');
                          await db.customStatement('DELETE FROM study_phases;');
                          await db.customStatement('DELETE FROM dsa_logs;');
                          await db.customStatement(
                            'DELETE FROM time_sessions;',
                          );
                          await db.customStatement(
                            'DELETE FROM consistency_logs;',
                          );
                          await db.customStatement(
                            'DELETE FROM user_profiles;',
                          );

                          if (mounted) {
                            context.go('/onboarding');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGpsBatteryGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.transparent,
      builder: (ctx) {
        final g = ctx.glass;
        return Container(
          padding: const EdgeInsets.all(AppSpace.s20),
          decoration: BoxDecoration(
            color: g.bg,
            borderRadius: const BorderRadius.vertical(
              top: AppGeometry.radiusr24,
            ),
            border: Border(
              top: BorderSide(color: g.edge, width: AppBorderScale.w1point5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.edge,
                    borderRadius: AppGeometry.roundedr2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpace.s10),
                    nightDecoration: BoxDecoration(
                      color: g.sageSoft,
                      borderRadius: AppGeometry.roundedr12,
                      border: Border.all(color: g.sage.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      Icons.battery_saver_rounded,
                      color: g.sage,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Walk Tracking Setup',
                          style: AscentTextStyles.headlineMedium
                              .copyWith(color: g.ink)
                              .merge(AppTypeRoles.typeRole30),
                        ),
                        Text(
                          'Prevent Android from killing GPS when locked',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _guideStep(
                number: '1',
                title: 'Open Android App Settings',
                description:
                    'Long press Ascent icon on home screen > App info (or go to Phone Settings > Apps > Ascent).',
              ),
              const SizedBox(height: 12),
              _guideStep(
                number: '2',
                title: 'Set Battery to "Unrestricted"',
                description:
                    'Under Battery or App Battery Usage, change setting to "Unrestricted" for uninterrupted route GPS.',
              ),
              const SizedBox(height: 12),
              _guideStep(
                number: '3',
                title: 'Allow Location While Using App',
                description:
                    'Ascent runs a foreground walking service with real-time route polyline & step tracking.',
              ),
              const SizedBox(height: 18),
              AscentButton.primary(
                label: 'Understood, Got it! 👍',
                expanded: true,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _guideStep({
    required String number,
    required String title,
    required String description,
  }) {
    final g = context.glass;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: g.sageSoft,
          child: Text(
            number,
            style: AppTypeRoles.typeRole7.copyWith(color: g.sage),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AscentTextStyles.labelMedium
                    .copyWith(color: g.ink)
                    .merge(AppTypeRoles.typeRole9),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: g.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final profileAsync = ref.watch(userProfileStreamProvider);
    final themeMode = ref.watch(themeModeProvider);
    final dayPreset = ref.watch(dayThemePresetProvider);
    final translucencyPreset = ref.watch(glassTranslucencyPresetProvider);

    if (profileAsync.hasValue && profileAsync.value != null) {
      _initFromProfile(profileAsync.value);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _persistAndReturn();
      },
      child: AscentScaffold(
        title: 'Settings',
        subtitle: 'Preferences & profile',
        showBackButton: true,
        onBack: _persistAndReturn,
        glow2: g.slateSoft,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s8),
            child: TextButton.icon(
              onPressed: _persistAndReturn,
              icon: _savedSuccess
                  ? Icon(Icons.check_rounded, color: g.clay, size: 18)
                  : const SizedBox.shrink(),
              label: Text(
                _savedSuccess ? 'Saved' : 'Save',
                style: AscentTextStyles.labelLarge
                    .copyWith(color: g.clay)
                    .merge(AppTypeRoles.typeRole9),
              ),
            ),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s8,
          ),
          children: [
            // ── Section 1: Appearance & Theme (Always Visible at Top) ────────
            _SectionHeader(title: 'Appearance & Theme', dotColor: g.clay),
            AscentCard(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Display Mode',
                          style: AscentTextStyles.labelMedium
                              .copyWith(color: g.ink)
                              .merge(AppTypeRoles.typeRole2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          themeMode == ThemeMode.dark
                              ? 'Night Mode'
                              : (themeMode == ThemeMode.light
                                    ? 'Day Mode'
                                    : 'System Auto'),
                          textAlign: TextAlign.end,
                          style: AscentTextStyles.captionMedium
                              .copyWith(color: g.clay)
                              .merge(AppTypeRoles.typeRole8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ThemeOption(
                        label: 'Day / Light',
                        icon: Icons.light_mode_rounded,
                        isSelected: themeMode == ThemeMode.light,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.light);
                        },
                      ),
                      const SizedBox(width: 8),
                      _ThemeOption(
                        label: 'Night / Dark',
                        icon: Icons.dark_mode_rounded,
                        isSelected: themeMode == ThemeMode.dark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.dark);
                        },
                      ),
                      const SizedBox(width: 8),
                      _ThemeOption(
                        label: 'System Auto',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: themeMode == ThemeMode.system,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(ThemeMode.system);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Active Theme Feedback Banner
                  if (themeMode == ThemeMode.light)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: g.clay.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: g.clay,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Apple Liquid Glass Theme is active. Frosted surfaces with dynamic depth and high-contrast typography.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: g.clay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (themeMode == ThemeMode.dark)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            color: Color(0xFFFF6B4A),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Night Glass Theme is active. Deep obsidian glass and vibrant neon clay accents.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: g.edge),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.brightness_auto_rounded,
                            color: g.clay,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'System Auto is active. Ascent automatically matches your device setting (${context.isDark ? "currently Night Glass" : "currently Luminous Day"}).',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  Divider(color: g.line, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Glass Translucency',
                          style: AscentTextStyles.labelMedium
                              .copyWith(color: g.ink)
                              .merge(AppTypeRoles.typeRole2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          translucencyPreset ==
                                  GlassTranslucencyPreset.subtleFrosted
                              ? 'Subtle Frosted'
                              : translucencyPreset ==
                                      GlassTranslucencyPreset.highContrast
                                  ? 'High Contrast'
                                  : 'Balanced Liquid (Default)',
                          textAlign: TextAlign.end,
                          style: AscentTextStyles.captionMedium
                              .copyWith(color: g.clay)
                              .merge(AppTypeRoles.typeRole8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DayPresetOption(
                        label: 'Subtle',
                        subtitle: 'Airy Glass',
                        colorSwatch: g.slate,
                        icon: Icons.blur_on_rounded,
                        isSelected: translucencyPreset ==
                            GlassTranslucencyPreset.subtleFrosted,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(glassTranslucencyPresetProvider.notifier)
                              .setPreset(GlassTranslucencyPreset.subtleFrosted);
                        },
                      ),
                      const SizedBox(width: 8),
                      _DayPresetOption(
                        label: 'Balanced',
                        subtitle: 'Signature',
                        colorSwatch: g.clay,
                        icon: Icons.auto_awesome_rounded,
                        isSelected: translucencyPreset ==
                            GlassTranslucencyPreset.balancedLiquid,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(glassTranslucencyPresetProvider.notifier)
                              .setPreset(
                                GlassTranslucencyPreset.balancedLiquid,
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                      _DayPresetOption(
                        label: 'Contrast',
                        subtitle: 'Crisp Day',
                        colorSwatch: g.amber,
                        icon: Icons.contrast_rounded,
                        isSelected: translucencyPreset ==
                            GlassTranslucencyPreset.highContrast,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(glassTranslucencyPresetProvider.notifier)
                              .setPreset(
                                GlassTranslucencyPreset.highContrast,
                              );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 2: Target Profile & Identity (Always Visible) ────────
            _SectionHeader(
              title: 'Target Profile & Identity',
              dotColor: g.slate,
            ),
            AscentCard(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Name',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex Hunter',
                      hintStyle: AscentTextStyles.bodyMedium.copyWith(
                        color: g.inkMuted,
                      ),
                      filled: true,
                      fillColor: g.fill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s14,
                        vertical: AppSpace.s12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(color: g.edge),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(color: g.edge),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.clay,
                          width: AppBorderScale.w1point2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Target Role',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _roleController,
                    style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                    decoration: InputDecoration(
                      hintText: 'e.g. Senior Software Engineer',
                      hintStyle: AscentTextStyles.bodyMedium.copyWith(
                        color: g.inkMuted,
                      ),
                      filled: true,
                      fillColor: g.fill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s14,
                        vertical: AppSpace.s12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(color: g.edge),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(color: g.edge),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.clay,
                          width: AppBorderScale.w1point2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AI Copilot Identity Sub-section
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: g.clay),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Copilot Name',
                          style: AscentTextStyles.labelMedium
                              .copyWith(color: g.ink)
                              .merge(AppTypeRoles.typeRole8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Personalize the identity of your on-device planner copilot.',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final currentName = ref.watch(assistantNameProvider);
                      return _AssistantNameEditor(currentName: currentName);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── ADVANCED / COLLAPSIBLE SECTIONS (Clean & uncluttered) ────────
            _SectionHeader(
              title: 'Advanced Options & Tools',
              dotColor: g.inkMuted,
            ),

            // ── Collapsible 1: Career Goals & Target Companies ──────────────
            _CollapsibleSettingsCard(
              icon: Icons.track_changes_rounded,
              iconTint: g.slate,
              title: 'Career Milestones & Companies',
              subtitle: 'Weekly study budget, deadline & target companies',
              isExpanded: _expandCareerGoals,
              onToggle: () =>
                  setState(() => _expandCareerGoals = !_expandCareerGoals),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Study Budget',
                        style: AscentTextStyles.labelMedium
                            .copyWith(color: g.ink)
                            .merge(AppTypeRoles.typeRole8),
                      ),
                      Text(
                        '$_weeklyHours hrs / wk',
                        style: AscentTextStyles.monoCode
                            .copyWith(color: g.clay)
                            .merge(AppTypeRoles.typeRole9),
                      ),
                    ],
                  ),
                  Slider(
                    value: _weeklyHours.toDouble(),
                    min: 5,
                    max: 40,
                    divisions: 7,
                    activeColor: g.clay,
                    inactiveColor: g.edge,
                    onChanged: (val) =>
                        setState(() => _weeklyHours = val.round()),
                  ),
                  const SizedBox(height: 12),

                  // Target Interview Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Interview Date',
                            style: AscentTextStyles.labelMedium
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole8),
                          ),
                          Text(
                            _interviewDate != null
                                ? DateFormat.yMMMd().format(_interviewDate!)
                                : 'No deadline set',
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      AscentButton.outlined(
                        label: _interviewDate == null ? 'Set Date' : 'Change',
                        compact: true,
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _interviewDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _interviewDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target Companies
                  Text(
                    'Target Companies',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _companyInputController,
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: g.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add company (e.g. Stripe)',
                            hintStyle: AscentTextStyles.bodySmall.copyWith(
                              color: g.inkMuted,
                            ),
                            filled: true,
                            fillColor: g.fill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s12,
                              vertical: AppSpace.s10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppGeometry.roundedr10,
                              borderSide: BorderSide(color: g.edge),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppGeometry.roundedr10,
                              borderSide: BorderSide(color: g.edge),
                            ),
                          ),
                          onSubmitted: (val) {
                            final text = val.trim();
                            if (text.isNotEmpty &&
                                !_targetCompanies.contains(text)) {
                              setState(() {
                                _targetCompanies.add(text);
                                _companyInputController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          color: g.clay,
                        ),
                        onPressed: () {
                          final text = _companyInputController.text.trim();
                          if (text.isNotEmpty &&
                              !_targetCompanies.contains(text)) {
                            setState(() {
                              _targetCompanies.add(text);
                              _companyInputController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_targetCompanies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _targetCompanies.map((c) {
                        return AppTag.label(
                          label: Text(c),
                          labelStyle: AscentTextStyles.labelSmall.copyWith(
                            color: g.ink,
                          ),
                          backgroundColor: g.fill,
                          side: BorderSide(color: g.edge),
                          deleteIcon: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: g.inkMuted,
                          ),
                          onDeleted: () =>
                              setState(() => _targetCompanies.remove(c)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Collapsible 2: Walk & Background Telemetry ───────────────────
            _CollapsibleSettingsCard(
              icon: Icons.directions_walk_rounded,
              iconTint: g.sage,
              title: 'Walk & GPS Telemetry',
              subtitle: 'Background GPS & battery optimization setup',
              isExpanded: _expandGpsTelemetry,
              onToggle: () =>
                  setState(() => _expandGpsTelemetry = !_expandGpsTelemetry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background Walk Tracking',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Allows Ascent to record accurate GPS routes, steps, and distance while your device is locked in your pocket.',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: g.inkMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AscentButton.outlined(
                    label: 'View Android Battery Guide',
                    icon: Icons.battery_saver_rounded,
                    compact: true,
                    expanded: true,
                    onPressed: () => _showGpsBatteryGuide(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Collapsible 4: Data & Storage ────────────────────────────────
            _CollapsibleSettingsCard(
              icon: Icons.inventory_2_outlined,
              iconTint: g.amber,
              title: 'Data & Storage Management',
              subtitle: 'JSON backup export, database restore & wipe',
              isExpanded: _expandDataStorage,
              onToggle: () =>
                  setState(() => _expandDataStorage = !_expandDataStorage),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppTag(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      nightDecoration: BoxDecoration(
                        color: g.slateSoft,
                        borderRadius: AppGeometry.roundedr10,
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: g.slate,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Save or restore a backup',
                      style: AscentTextStyles.labelMedium
                          .copyWith(color: g.ink)
                          .merge(AppTypeRoles.typeRole8),
                    ),
                    subtitle: Text(
                      'Records, settings and resume files',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: g.inkMuted,
                    ),
                    onTap: () => context.push('/backup'),
                  ),
                  _Divider(color: g.line),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppTag(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      nightDecoration: BoxDecoration(
                        color: g.coralSoft,
                        borderRadius: AppGeometry.roundedr10,
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: g.coral,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Reset All Data',
                      style: AscentTextStyles.labelMedium
                          .copyWith(color: g.coral)
                          .merge(AppTypeRoles.typeRole8),
                    ),
                    subtitle: Text(
                      'Wipe local database and restart onboarding',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    onTap: _confirmResetData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color dotColor;

  const _SectionHeader({required this.title, this.dotColor = AppPalette.grey});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s4, bottom: AppSpace.s8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AscentTextStyles.labelSmall
                .copyWith(
                  color: g.ink,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                )
                .merge(AppTypeRoles.typeRole31),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return AppDivider(height: 20, thickness: 0.8, color: color);
  }
}

class _CollapsibleSettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconTint;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSettingsCard({
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AscentCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            color: AppPalette.transparent,
            child: AppTapArea(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggle();
              },
              borderRadius: AppGeometry.roundedr16,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s14,
                ),
                child: Row(
                  children: [
                    AppTag(
                      width: 36,
                      height: 36,
                      nightDecoration: BoxDecoration(
                        color: iconTint.withValues(alpha: 0.12),
                        borderRadius: AppGeometry.roundedr10,
                        border: Border.all(
                          color: iconTint.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(icon, color: iconTint, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AscentTextStyles.labelMedium
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole32),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AscentTextStyles.bodySmall
                                .copyWith(color: g.inkMuted)
                                .merge(AppTypeRoles.typeRole23),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s4,
                      ),
                      nightDecoration: BoxDecoration(
                        color: isExpanded ? g.claySoft : g.fill,
                        borderRadius: AppGeometry.roundedr12,
                        border: Border.all(
                          color: isExpanded
                              ? g.clay.withValues(alpha: 0.3)
                              : g.edge,
                          width: AppBorderScale.w0point8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? 'Hide' : 'Show',
                            style: AscentTextStyles.labelSmall
                                .copyWith(
                                  color: isExpanded ? g.clay : g.inkMuted,
                                )
                                .merge(AppTypeRoles.typeRole33),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isExpanded ? g.clay : g.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            AppDivider(height: 1, thickness: 0.8, color: g.line),
            Padding(padding: const EdgeInsets.all(AppSpace.s16), child: child),
          ],
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Expanded(
      child: AppTapArea(
        onTap: onTap,
        borderRadius: AppGeometry.roundedr16,
        child: AppCard(
          selected: isSelected,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s16,
            horizontal: AppSpace.s8,
          ),
          nightDecoration: BoxDecoration(
            color: isSelected ? context.accentPrimary : g.fill,
            borderRadius: AppGeometry.roundedr16,
            border: Border.all(
              color: isSelected ? context.accentPrimary : g.edge,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.accentPrimary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.18)
                      : (context.isDark
                            ? g.edge.withValues(alpha: 0.4)
                            : g.clay.withValues(alpha: 0.08)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppPalette.white : g.inkSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AscentTextStyles.labelSmall
                      .copyWith(
                        color: isSelected ? AppPalette.white : g.ink,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      )
                      .merge(AppStateTypography.stateType1(state0: isSelected)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPresetOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color colorSwatch;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayPresetOption({
    required this.label,
    required this.subtitle,
    required this.colorSwatch,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Expanded(
      child: AppTapArea(
        onTap: onTap,
        borderRadius: AppGeometry.roundedr12,
        child: AppCard(
          selected: isSelected,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s12,
            horizontal: AppSpace.s8,
          ),
          nightDecoration: BoxDecoration(
            color: isSelected ? colorSwatch : g.fill,
            borderRadius: AppGeometry.roundedr12,
            border: Border.all(
              color: isSelected ? colorSwatch : g.edge,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : colorSwatch,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    icon,
                    color: isSelected ? AppPalette.white : g.inkSecondary,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: isSelected ? AppPalette.white : g.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.90)
                        : g.inkMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantNameEditor extends ConsumerStatefulWidget {
  final String currentName;

  const _AssistantNameEditor({required this.currentName});

  @override
  ConsumerState<_AssistantNameEditor> createState() =>
      _AssistantNameEditorState();
}

class _AssistantNameEditorState extends ConsumerState<_AssistantNameEditor> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void didUpdateWidget(covariant _AssistantNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentName != widget.currentName && !_isEditing) {
      _controller.text = widget.currentName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (_) {
                  if (!_isEditing) setState(() => _isEditing = true);
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.psychology_outlined,
                    size: 20,
                    color: g.clay,
                  ),
                  hintText: 'e.g. Riya',
                  filled: true,
                  fillColor: g.fill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s14,
                    vertical: AppSpace.s12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(color: g.edge),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(color: g.edge),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(color: g.clay),
                  ),
                ),
                style: AscentTextStyles.bodyMedium
                    .copyWith(color: g.ink)
                    .merge(AppTypeRoles.typeRole8),
              ),
            ),
            const SizedBox(width: 8),
            AscentButton.primary(
              label: 'Update',
              compact: true,
              expanded: false,
              onPressed: () {
                final newName = _controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(assistantNameProvider.notifier).setName(newName);
                  setState(() => _isEditing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Assistant renamed to $newName'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['Riya', 'Aria', 'Jarvis', 'Nova'].map((preset) {
            final isSelected = widget.currentName == preset;
            return AppPill.choice(
              label: Text(preset),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _controller.text = preset;
                  ref.read(assistantNameProvider.notifier).setName(preset);
                  setState(() => _isEditing = false);
                }
              },
              labelStyle: AscentTextStyles.labelSmall
                  .copyWith(
                    color: isSelected ? AppPalette.white : g.inkSecondary,
                  )
                  .merge(AppStateTypography.stateType6(state0: isSelected)),
              selectedColor: g.clay,
              backgroundColor: g.fill,
              side: BorderSide(color: isSelected ? g.clay : g.edge),
            );
          }).toList(),
        ),
      ],
    );
  }
}
