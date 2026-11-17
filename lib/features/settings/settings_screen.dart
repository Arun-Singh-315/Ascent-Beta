import 'package:flutter/cupertino.dart'
    show
        CupertinoSegmentedControl,
        CupertinoSliverNavigationBar,
        CupertinoSwitch;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/database/app_database.dart';
import '../../core/database/dev_database_seeder.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/security/app_lock_provider.dart';
import '../../core/streak/study_streak_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/home/widgets/day_one_tutorial_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/opaque_overlay_surface.dart';

/// iOS Settings-Style Screen for Ascent.
///
/// Features:
/// - Collapsing [CupertinoSliverNavigationBar] with large title "Settings".
/// - User profile hero card at top with initials avatar and tap-to-edit.
/// - Inset grouped list cards on warm `groupedBackground` with continuous corners.
/// - Leading 30px rounded-square tinted icon tiles.
/// - Hairline dividers inset 58dp from left.
/// - Adaptive [CupertinoSwitch] and [CupertinoSegmentedControl].
/// - Developer / Debug utilities hidden behind `kDebugMode` section.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _profileLoaded = false;
  bool _voiceOutput = true;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _initFromProfile(UserProfile? profile) {
    if (profile == null || _profileLoaded) return;
    _profileLoaded = true;
    _nameController.text = profile.name;
    _roleController.text = profile.targetRole;
    _dateOfBirth = profile.dateOfBirth;
  }

  Future<void> _saveProfileChanges() async {
    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final current = await profileDao.getProfile();

      await profileDao.upsertProfile(
        UserProfileTableCompanion(
          id: drift.Value(current?.id ?? 1),
          name: drift.Value(_nameController.text.trim()),
          targetRole: drift.Value(_roleController.text.trim()),
          dateOfBirth: drift.Value(_dateOfBirth),
          targetCompanies: drift.Value(current?.targetCompanies ?? '[]'),
          interviewDate: drift.Value(current?.interviewDate),
          weeklyHoursAvailable: drift.Value(current?.weeklyHoursAvailable ?? 10),
          preferredStudyWindow:
              drift.Value(current?.preferredStudyWindow ?? 'Morning (6 AM - 9 AM)'),
          onboardingComplete: const drift.Value(true),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      if (mounted) {
        AscentSnackBar.show(context, message: 'Profile updated');
      }
    } catch (_) {}
  }

  void _showEditProfileSheet(BuildContext context, UserProfile? profile) {
    HapticFeedback.lightImpact();
    final c = context.c;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: OpaqueOverlaySurface(
            isSheet: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SafeArea(
              top: false,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                await _saveProfileChanges();
                                if (mounted) setState(() {});
                              },
                              child: Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: c.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _nameController,
                          labelText: 'Your Name',
                          hintText: 'What should we call you?',
                          prefixIcon: Icon(Icons.person_outline, color: c.textTertiary),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _roleController,
                          labelText: 'Role / Focus',
                          hintText: 'e.g. Creator, Student, Builder',
                          prefixIcon: Icon(Icons.work_outline, color: c.textTertiary),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setSheetState(() => _dateOfBirth = picked);
                              setState(() => _dateOfBirth = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cake_outlined, size: 20, color: c.textTertiary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _dateOfBirth != null
                                        ? DateFormat('d MMMM yyyy').format(_dateOfBirth!)
                                        : 'Select Date of Birth',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _dateOfBirth != null ? c.textPrimary : c.textTertiary,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showChangeAssistantNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    final c = context.c;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Assistant Name',
          style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: AppTextField(
          controller: controller,
          hintText: 'e.g. Jarvis',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(assistantNameProvider.notifier).setName(newName);
                Navigator.pop(ctx);
                AscentSnackBar.show(context, message: 'Assistant name updated');
              }
            },
            child: Text('Save', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSetPinDialog(
    BuildContext context, {
    bool isChanging = false,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    final c = context.c;

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.border),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  isChanging ? 'Change Master PIN' : 'Set Master PIN',
                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set a 4-digit PIN to secure your Ascent workspace.',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  key: const ValueKey('set_pin_input'),
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  hintText: 'New 4-digit PIN',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  key: const ValueKey('confirm_pin_input'),
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  hintText: 'Confirm PIN',
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: c.alert,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
              ),
              FilledButton(
                key: const ValueKey('save_pin_button'),
                style: FilledButton.styleFrom(backgroundColor: c.primary),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
                    setDialogState(() => errorText = 'PIN must be exactly 4 digits');
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => errorText = 'PINs do not match');
                    return;
                  }
                  await ref.read(appLockProvider.notifier).setPin(pin);
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx, true);
                  }
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _seed20DaysTestData() async {
    HapticFeedback.mediumImpact();
    AscentSnackBar.show(context, message: 'Seeding 20 days of test data...');
    try {
      final db = ref.read(databaseProvider);
      await DevDatabaseSeeder.seed20DaysData(db);
      ref.invalidate(userProfileStreamProvider);
      ref.invalidate(todayActivitiesProvider);
      ref.invalidate(allRemindersProvider);
      ref.invalidate(todayWaterMlStreamProvider);
      ref.invalidate(todayMedicineLogsStreamProvider);
      ref.invalidate(todayWalkDistanceStreamProvider);
      ref.invalidate(studyStreakProvider);
      if (mounted) {
        AscentSnackBar.show(context, message: '20 days data successfully populated');
      }
    } catch (e) {
      if (mounted) {
        AscentSnackBar.show(context, message: 'Seeding failed: $e');
      }
    }
  }

  Future<void> _confirmResetData() async {
    HapticFeedback.heavyImpact();
    final c = context.c;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset All Data?', style: TextStyle(color: c.alert, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete all records, activities, thoughts, and reset your onboarding flow. This action cannot be undone.',
          style: TextStyle(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.alert),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.clear();
        final db = ref.read(databaseProvider);
        await db.wipeAllUserData();
        try {
          await NotificationService.instance.cancelAll();
        } catch (_) {}

        if (mounted) {
          context.go('/onboarding');
        }
      } catch (e) {
        if (mounted) {
          AscentSnackBar.show(context, message: 'Reset failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.value;
    _initFromProfile(profile);

    final themeMode = ref.watch(themeModeProvider);
    final assistantName = ref.watch(assistantNameProvider);
    final rawBoostTone = ref.watch(rawBoostToneEnabledProvider);
    final thingsCheckIns = ref.watch(thingsCheckInsEnabledProvider);
    final lockState = ref.watch(appLockProvider);
    final lockNotifier = ref.read(appLockProvider.notifier);

    final userName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : 'Arun Singh Visen';
    final userRole = profile?.targetRole.trim().isNotEmpty == true
        ? profile!.targetRole.trim()
        : 'Personal Life OS';
    final initials = userName.isNotEmpty
        ? userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'A';

    return Scaffold(
      backgroundColor: c.groupedBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Collapsing Large Title Sliver Navigation Bar
          CupertinoSliverNavigationBar(
            leading: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: c.textPrimary,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                splashRadius: 22,
                tooltip: 'Back',
              ),
            ),
            largeTitle: Text(
              'Settings',
              style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: c.groupedBg.withValues(alpha: 0.85),
            border: null,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              child: Column(
                children: [
                  // ── Top User Profile Card ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showEditProfileSheet(context, profile),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.border, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: c.warmShadow,
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar circle with initials
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  initials.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: c.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Name & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      userRole,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: c.textTertiary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Section 1: Appearance ──────────────────────────────
                  _SectionHeader(title: 'APPEARANCE'),
                  _InsetGroupCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _IconTile(
                              icon: Icons.palette_outlined,
                              bgColor: c.primaryContainer,
                              iconColor: c.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Theme',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            CupertinoSegmentedControl<ThemeMode>(
                              children: {
                                ThemeMode.system: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Auto', style: TextStyle(fontSize: 12.5, color: c.textPrimary)),
                                ),
                                ThemeMode.light: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Light', style: TextStyle(fontSize: 12.5, color: c.textPrimary)),
                                ),
                                ThemeMode.dark: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Dark', style: TextStyle(fontSize: 12.5, color: c.textPrimary)),
                                ),
                              },
                              groupValue: themeMode,
                              onValueChanged: (mode) {
                                HapticFeedback.selectionClick();
                                ref.read(themeModeProvider.notifier).setThemeMode(mode);
                              },
                              borderColor: c.border,
                              selectedColor: c.primaryContainer,
                              unselectedColor: c.surface,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Section 2: Assistant ────────────────────────────────
                  _SectionHeader(title: 'ASSISTANT'),
                  _InsetGroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.auto_awesome_rounded,
                        iconBg: c.primaryContainer,
                        iconColor: c.primary,
                        title: 'Companion Name',
                        value: assistantName,
                        onTap: () => _showChangeAssistantNameDialog(context, assistantName),
                      ),
                      _DividerLine(),
                      _SettingsRow(
                        icon: Icons.tune_rounded,
                        iconBg: c.goldTint,
                        iconColor: c.gold,
                        title: 'Tone',
                        value: rawBoostTone ? 'Action & Momentum' : 'Thoughtful & Calm',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(rawBoostToneEnabledProvider.notifier)
                              .setEnabled(!rawBoostTone);
                        },
                      ),
                      _DividerLine(),
                      _SettingsToggleRow(
                        icon: Icons.volume_up_outlined,
                        iconBg: c.accent2Tint,
                        iconColor: c.accent2,
                        title: 'Voice Output',
                        value: _voiceOutput,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _voiceOutput = val);
                        },
                      ),
                    ],
                  ),

                  // ── Section 3: Notifications & Schedule ────────────────
                  _SectionHeader(title: 'NOTIFICATIONS & SCHEDULE'),
                  _InsetGroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.notifications_active_outlined,
                        iconBg: c.primaryContainer,
                        iconColor: c.primary,
                        title: 'Scheduled Alerts & Alarms',
                        value: 'System Active',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          AscentSnackBar.show(context, message: 'Alarms & notifications enabled');
                        },
                      ),
                      _DividerLine(),
                      _SettingsToggleRow(
                        icon: Icons.checklist_rounded,
                        iconBg: c.goldTint,
                        iconColor: c.gold,
                        title: 'Dayboard Check-ins',
                        value: thingsCheckIns,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          ref.read(thingsCheckInsEnabledProvider.notifier).setEnabled(val);
                        },
                      ),
                    ],
                  ),

                  // ── Section 4: Privacy & Data ──────────────────────────
                  _SectionHeader(title: 'PRIVACY & DATA'),
                  _InsetGroupCard(
                    children: [
                      _SettingsToggleRow(
                        icon: Icons.fingerprint_rounded,
                        iconBg: c.primaryContainer,
                        iconColor: c.primary,
                        title: 'Require App Lock',
                        value: lockState.isEnabled,
                        onChanged: (val) async {
                          HapticFeedback.selectionClick();
                          if (val && !lockState.hasMasterPin) {
                            final setPin = await _showSetPinDialog(context);
                            if (setPin == true) {
                              await lockNotifier.toggleAppLock(true);
                            }
                          } else {
                            await lockNotifier.toggleAppLock(val);
                          }
                        },
                      ),
                      if (lockState.hasMasterPin) ...[
                        _DividerLine(),
                        _SettingsRow(
                          icon: Icons.password_rounded,
                          iconBg: c.primaryContainer,
                          iconColor: c.primary,
                          title: 'Change Master PIN',
                          onTap: () => _showSetPinDialog(context, isChanging: true),
                        ),
                      ],
                      _DividerLine(),
                      _SettingsRow(
                        icon: Icons.archive_outlined,
                        iconBg: c.goldTint,
                        iconColor: c.gold,
                        title: 'Save or Restore Backup',
                        value: 'JSON Export',
                        onTap: () => context.push('/backup'),
                      ),
                      _DividerLine(),
                      _SettingsRow(
                        icon: Icons.cleaning_services_outlined,
                        iconBg: c.accent2Tint,
                        iconColor: c.accent2,
                        title: 'Clear Cache & Temp Media',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          AscentSnackBar.show(context, message: 'Cache cleaned (0 KB freed)');
                        },
                      ),
                    ],
                  ),

                  // ── Section 5: About ────────────────────────────────────
                  _SectionHeader(title: 'ABOUT'),
                  _InsetGroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.school_outlined,
                        iconBg: c.primaryContainer,
                        iconColor: c.primary,
                        title: 'Replay Welcome Tour',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          DayOneTutorialDialog.show(context, userName: userName);
                        },
                      ),
                      _DividerLine(),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        iconBg: c.surfaceAlt,
                        iconColor: c.textSecondary,
                        title: 'Version',
                        value: 'Ascent v1.0.0 (42)',
                      ),
                      _DividerLine(),
                      _SettingsRow(
                        icon: Icons.code_rounded,
                        iconBg: c.surfaceAlt,
                        iconColor: c.textSecondary,
                        title: 'Open Source Licenses',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showLicensePage(
                            context: context,
                            applicationName: 'Ascent',
                            applicationVersion: '1.0.0',
                          );
                        },
                      ),
                    ],
                  ),

                  // ── Section 6: Developer Options (Debug Only) ───────────
                  if (kDebugMode) ...[
                    _SectionHeader(title: 'DEVELOPER OPTIONS'),
                    _InsetGroupCard(
                      children: [
                        _SettingsRow(
                          icon: Icons.auto_fix_high_rounded,
                          iconBg: c.primaryContainer,
                          iconColor: c.primary,
                          title: 'Seed 20 Days Test Data',
                          onTap: _seed20DaysTestData,
                        ),
                        _DividerLine(),
                        _SettingsRow(
                          icon: Icons.delete_forever_rounded,
                          iconBg: c.alertTint,
                          iconColor: c.alert,
                          title: 'Reset All Data',
                          onTap: _confirmResetData,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _InsetGroupCard extends StatelessWidget {
  const _InsetGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: c.warmShadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: iconColor),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _IconTile(icon: icon, bgColor: iconBg, iconColor: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: c.textSecondary,
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.textTertiary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _IconTile(icon: icon, bgColor: iconBg, iconColor: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: c.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 58,
      color: c.border,
    );
  }
}
