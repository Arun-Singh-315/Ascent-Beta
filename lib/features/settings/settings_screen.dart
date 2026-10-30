import '../../shared/widgets/ascent_switch.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../home/widgets/island_customization_sheet.dart';
import '../../core/security/app_lock_provider.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../core/services/cosmic_profile_service.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alarm_bridge.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../features/home/widgets/day_one_tutorial_card.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import 'package:geolocator/geolocator.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  List<String> _targetCompanies = [];
  DateTime? _interviewDate;
  DateTime? _dateOfBirth;
  int _weeklyHours = 10;
  String _studyWindow = 'morning';
  bool _profileLoaded = false;

  // Collapsible section visibility states to keep UI calm & decluttered
  bool _expandGpsTelemetry = false;
  bool _expandDataStorage = false;
  bool _expandHelpGuides = false;

  // Live Permission & System Access States
  bool _notificationsAllowed = false;
  bool _alarmsAllowed = false;
  bool _locationAllowed = false;
  bool _locationServiceOn = true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final profile = ref.read(userProfileStreamProvider).value;
    if (profile != null) {
      _initFromProfile(profile);
    }
    _checkAllPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    if (!mounted) return;
    try {
      bool notif = false;
      try {
        notif = await NotificationService.instance.areNotificationsEnabled();
      } catch (_) {}
      LocationPermission locPerm = LocationPermission.denied;
      bool locService = true;
      try {
        locPerm = await Geolocator.checkPermission();
        locService = await Geolocator.isLocationServiceEnabled();
      } catch (_) {}

      bool alarmReady = notif;
      try {
        final access = await ReminderAlarmBridge.access();
        alarmReady = access['exact'] == true;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _notificationsAllowed = notif;
          _locationAllowed =
              locPerm == LocationPermission.always ||
              locPerm == LocationPermission.whileInUse;
          _locationServiceOn = locService;
          _alarmsAllowed = alarmReady;
        });
      }
    } catch (_) {}
  }

  Future<void> _openSystemAppSettings() async {
    HapticFeedback.lightImpact();
    try {
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Open phone Settings > Apps > Ascent to manage permissions.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Open phone Settings > Apps > Ascent to manage permissions.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openLocationSettings() async {
    HapticFeedback.lightImpact();
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open device Location Settings to enable GPS.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _requestNotificationAccess() async {
    HapticFeedback.lightImpact();
    try {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.requestExactAlarmsPermission();
    } catch (_) {}
    await _checkAllPermissions();
  }

  Future<void> _requestLocationAccess() async {
    HapticFeedback.lightImpact();
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        await _openSystemAppSettings();
      } else {
        final service = await Geolocator.isLocationServiceEnabled();
        if (!service) {
          await _openLocationSettings();
        }
      }
    } catch (_) {}
    await _checkAllPermissions();
  }

  Future<void> _requestAlarmAccess() async {
    HapticFeedback.lightImpact();
    try {
      await ReminderAlarmBridge.requestAccess();
    } catch (_) {
      await _openSystemAppSettings();
    }
    await _checkAllPermissions();
  }

  void _initFromProfile(UserProfile? profile) {
    if (profile == null || _profileLoaded) return;
    _profileLoaded = true;
    _nameController.text = profile.name;
    _roleController.text = profile.targetRole;
    _interviewDate = profile.interviewDate;
    _dateOfBirth = profile.dateOfBirth;
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
          dateOfBirth: drift.Value(_dateOfBirth),
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
                          await db.wipeAllUserData();
                          try {
                            await NotificationService.instance.cancelAll();
                          } catch (_) {}

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
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  AscentButton.outlined(
                    label: 'Open Phone App Settings',
                    icon: Icons.open_in_new_rounded,
                    compact: true,
                    expanded: false,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openSystemAppSettings();
                    },
                  ),
                  AscentButton.outlined(
                    label: 'Understood, Got it! 👍',
                    compact: true,
                    expanded: false,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
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

  Widget _buildPermissionsSection() {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'App Permissions & System Access',
          dotColor: g.sage,
        ),
        AscentCard(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Background Activity & Service Access',
                style: AscentTextStyles.labelMedium
                    .copyWith(color: g.ink)
                    .merge(AppTypeRoles.typeRole2),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage essential OS permissions so background timers, walk tracking, and reminder alarms run reliably without interruption.',
                style: AscentTextStyles.bodySmall.copyWith(
                  color: g.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              // 1. Notifications & Reminders
              _buildPermissionTile(
                icon: Icons.notifications_active_outlined,
                iconColor: g.clay,
                iconBg: g.claySoft,
                title: 'Notifications & Alerts',
                subtitle:
                    'Scheduled reminders, study focus intervals & daily briefing',
                isGranted: _notificationsAllowed,
                grantedLabel: 'Allowed',
                actionLabel: 'Allow Notifications',
                onAction: _requestNotificationAccess,
              ),

              _Divider(color: g.line),

              // 2. Alarms & Exact Timing
              _buildPermissionTile(
                icon: Icons.alarm_on_outlined,
                iconColor: g.amber,
                iconBg: g.amberSoft,
                title: 'Exact Alarms & Ringing',
                subtitle:
                    'Reliable lock-screen ringing & full-screen alarm popups',
                isGranted: _alarmsAllowed,
                grantedLabel: 'Ready',
                actionLabel: 'Configure Alarms',
                onAction: _requestAlarmAccess,
              ),

              _Divider(color: g.line),

              // 3. Location & GPS
              _buildPermissionTile(
                icon: Icons.location_on_outlined,
                iconColor: g.sage,
                iconBg: g.sageSoft,
                title: 'GPS Walk Tracking',
                subtitle:
                    'Outdoor walking routes, live step count & distance tracking',
                isGranted: _locationAllowed && _locationServiceOn,
                grantedLabel: 'Active',
                neededLabel: !_locationServiceOn ? 'GPS Off' : 'Needed',
                actionLabel: !_locationServiceOn
                    ? 'Turn On GPS'
                    : 'Allow Location',
                onAction: _requestLocationAccess,
              ),

              const SizedBox(height: 14),
              _Divider(color: g.line),
              const SizedBox(height: 12),

              // Phone Shortcuts & Battery Saver Guide
              Text(
                'Phone Settings & Battery Savers',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Android battery savers kill background GPS & timers when phone is locked. Tap below to jump directly to Ascent\'s App Info, grant permissions, and set Battery to "Unrestricted".',
                style: AscentTextStyles.bodySmall.copyWith(
                  color: g.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 360;
                  final btn1 = AscentButton.outlined(
                    label: 'App Info & Battery',
                    icon: Icons.open_in_new_rounded,
                    compact: true,
                    expanded: stack,
                    onPressed: _openSystemAppSettings,
                  );
                  final btn2 = AscentButton.outlined(
                    label: 'Location Settings',
                    icon: Icons.location_on_outlined,
                    compact: true,
                    expanded: stack,
                    onPressed: _openLocationSettings,
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        btn1,
                        const SizedBox(height: AppSpace.s8),
                        btn2,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: btn1),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(child: btn2),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool isGranted,
    required String grantedLabel,
    String neededLabel = 'Needed',
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTag(
            padding: const EdgeInsets.all(AppSpace.s8),
            nightDecoration: BoxDecoration(
              color: iconBg,
              borderRadius: AppGeometry.roundedr10,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.labelMedium
                          .copyWith(color: g.ink)
                          .merge(AppTypeRoles.typeRole8),
                    ),
                    AppTag(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s2,
                      ),
                      nightDecoration: BoxDecoration(
                        color: isGranted ? g.sageSoft : g.coralSoft,
                        borderRadius: AppGeometry.roundedr8,
                        border: Border.all(
                          color: isGranted
                              ? g.sage.withValues(alpha: 0.3)
                              : g.coral.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            size: 12,
                            color: isGranted ? g.sage : g.coral,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGranted ? grantedLabel : neededLabel,
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: isGranted ? g.sage : g.coral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: g.inkMuted,
                    height: 1.3,
                  ),
                ),
                if (!isGranted) ...[
                  const SizedBox(height: AppSpace.s6),
                  AscentButton.outlined(
                    label: actionLabel,
                    compact: true,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
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

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final g = ctx.glass;
          return AlertDialog(
            backgroundColor: g.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: g.line),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: g.clay),
                const SizedBox(width: 8),
                Text(
                  isChanging ? 'Change Master PIN' : 'Set Master PIN',
                  style: AscentTextStyles.headlineMedium.copyWith(color: g.ink),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set a 4-digit PIN to secure your Ascent workspace and prevent unauthorized access.',
                  style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('set_pin_input'),
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  style: TextStyle(
                    letterSpacing: 4,
                    color: g.ink,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'New 4-digit PIN',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('confirm_pin_input'),
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  style: TextStyle(
                    letterSpacing: 4,
                    color: g.ink,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: g.coral,
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
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('save_pin_button'),
                style: FilledButton.styleFrom(backgroundColor: g.clay),
                onPressed: () async {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length < 4) {
                    setDialogState(() => errorText = 'PIN must be 4 digits');
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => errorText = 'PINs do not match');
                    return;
                  }
                  final ok = await ref
                      .read(appLockProvider.notifier)
                      .setPin(pin);
                  if (ok && dialogCtx.mounted) {
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

  Widget _buildSecuritySection() {
    final g = context.glass;
    final lockState = ref.watch(appLockProvider);
    final notifier = ref.read(appLockProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Security & App Lock', dotColor: g.coral),
        AscentCard(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Require App Lock',
                          style: AscentTextStyles.labelMedium.copyWith(
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Require PIN or Biometrics whenever Ascent opens',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AscentSwitch(
                    key: const ValueKey('setting_app_lock_switch'),
                    value: lockState.isEnabled,
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      if (val && !lockState.hasMasterPin) {
                        final setPin = await _showSetPinDialog(context);
                        if (setPin == true) {
                          await notifier.toggleAppLock(true);
                        }
                      } else {
                        await notifier.toggleAppLock(val);
                      }
                    },
                  ),
                ],
              ),
              if (lockState.hasMasterPin) ...[
                const SizedBox(height: 8),
                Divider(color: g.line, height: 1),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showSetPinDialog(context, isChanging: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.password_rounded,
                              size: 20,
                              color: g.clay,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Change Master PIN',
                              style: AscentTextStyles.labelMedium.copyWith(
                                color: g.ink,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: g.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: g.line, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow Notifications When Locked',
                          style: AscentTextStyles.labelMedium.copyWith(
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Deliver reminders even while app lock is engaged',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AscentSwitch(
                    key: const ValueKey('setting_allow_notifications_switch'),
                    value: lockState.allowNotifications,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      notifier.setAllowNotifications(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: g.line, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Redact Notification Content',
                          style: AscentTextStyles.labelMedium.copyWith(
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hide private task and thought text on notifications when locked',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AscentSwitch(
                    key: const ValueKey('setting_redact_notifications_switch'),
                    value: lockState.redactNotificationContent,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      notifier.setRedactContent(val);
                    },
                  ),
                ],
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
                  AscentSegmentedControl<GlassTranslucencyPreset>(
                    segments: const [
                      AscentSegment(
                        value: GlassTranslucencyPreset.subtleFrosted,
                        label: 'Subtle',
                      ),
                      AscentSegment(
                        value: GlassTranslucencyPreset.balancedLiquid,
                        label: 'Balanced',
                      ),
                      AscentSegment(
                        value: GlassTranslucencyPreset.highContrast,
                        label: 'Contrast',
                      ),
                    ],
                    selected: translucencyPreset,
                    onChanged: (value) => ref
                        .read(glassTranslucencyPresetProvider.notifier)
                        .setPreset(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            AscentCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.blur_on_rounded, color: g.clay),
                title: const Text('Dynamic Island'),
                subtitle: const Text(
                  'Glass finish, compact view and what appears',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showIslandCustomization(context),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 2: Profile & Identity (Always Visible) ──────────────
            _SectionHeader(title: 'Profile & Assistant', dotColor: g.slate),
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
                      fillColor: g.recessed,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                        vertical: AppSpace.s14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.controlOutline,
                          width: AscentDimensions.controlOutlineWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.controlOutline,
                          width: AscentDimensions.controlOutlineWidth,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.focusRing,
                          width: AscentDimensions.focusRingWidth,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Date of Birth',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    key: const ValueKey('settings_dob_picker'),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: now,
                        builder: (ctx, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme
                                  .copyWith(
                                    primary: g.clay,
                                    onPrimary: Colors.white,
                                    surface: g.fill,
                                    onSurface: g.ink,
                                  ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _dateOfBirth = picked);
                      }
                    },
                    borderRadius: AppGeometry.roundedr12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                        vertical: AppSpace.s14,
                      ),
                      decoration: BoxDecoration(
                        color: g.recessed,
                        borderRadius: AppGeometry.roundedr12,
                        border: Border.all(
                          color: g.controlOutline,
                          width: AscentDimensions.controlOutlineWidth,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 18,
                            color: _dateOfBirth != null ? g.clay : g.inkMuted,
                          ),
                          const SizedBox(width: AppSpace.s10),
                          Expanded(
                            child: Text(
                              _dateOfBirth != null
                                  ? DateFormat(
                                      'd MMMM yyyy',
                                    ).format(_dateOfBirth!)
                                  : 'Select date of birth',
                              style: AscentTextStyles.bodyMedium.copyWith(
                                color: _dateOfBirth != null
                                    ? g.ink
                                    : g.inkMuted,
                              ),
                            ),
                          ),
                          if (_dateOfBirth != null)
                            IconButton(
                              tooltip: 'Clear birth date',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: g.inkMuted,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _dateOfBirth = null);
                              },
                            )
                          else
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: g.inkMuted,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_dateOfBirth != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        const service = CosmicProfileService();
                        final sign = service.getZodiac(_dateOfBirth!);
                        return Padding(
                          padding: const EdgeInsets.only(left: 2, top: 2),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${sign.symbol} ${sign.name} · ${sign.vedicRashi}',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: g.clay,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '(${sign.element.icon} ${sign.element.label})',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: g.inkMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 14),

                  Text(
                    'Your Role / Focus',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: g.ink)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _roleController,
                    style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                    decoration: InputDecoration(
                      hintText: 'e.g. Creator, Student, Builder',
                      hintStyle: AscentTextStyles.bodyMedium.copyWith(
                        color: g.inkMuted,
                      ),
                      filled: true,
                      fillColor: g.recessed,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                        vertical: AppSpace.s14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.controlOutline,
                          width: AscentDimensions.controlOutlineWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.controlOutline,
                          width: AscentDimensions.controlOutlineWidth,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppGeometry.roundedr12,
                        borderSide: BorderSide(
                          color: g.focusRing,
                          width: AscentDimensions.focusRingWidth,
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

            // ── Section 3: App Permissions & System Access (Always Visible) ─
            _buildPermissionsSection(),
            const SizedBox(height: 20),

            // ── Section 4: Security & App Lock ──────────────────────────────
            _buildSecuritySection(),
            const SizedBox(height: 20),

            // ── ADVANCED / COLLAPSIBLE SECTIONS (Clean & uncluttered) ────────
            // ── ADVANCED / COLLAPSIBLE SECTIONS (Clean & uncluttered) ────────
            _SectionHeader(
              title: 'System Access & Storage',
              dotColor: g.inkMuted,
            ),

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
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      AscentButton.outlined(
                        label: 'View Battery Guide',
                        icon: Icons.battery_saver_rounded,
                        compact: true,
                        expanded: false,
                        onPressed: () => _showGpsBatteryGuide(context),
                      ),
                      AscentButton.outlined(
                        label: 'App Info & Battery',
                        icon: Icons.open_in_new_rounded,
                        compact: true,
                        expanded: false,
                        onPressed: _openSystemAppSettings,
                      ),
                    ],
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

            // ── Collapsible 5: Help & Walkthroughs ───────────────────────────
            _CollapsibleSettingsCard(
              icon: Icons.help_outline_rounded,
              iconTint: g.clay,
              title: 'Help & Walkthroughs',
              subtitle: 'Replay welcome tutorial and guide tour',
              isExpanded: _expandHelpGuides,
              onToggle: () =>
                  setState(() => _expandHelpGuides = !_expandHelpGuides),
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('settings_replay_day_one_tutorial'),
                    contentPadding: EdgeInsets.zero,
                    leading: AppTag(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      nightDecoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.12),
                        borderRadius: AppGeometry.roundedr10,
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        color: g.clay,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Replay Day One Tutorial',
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: g.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Review the initial welcome walkthrough',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: g.inkMuted,
                    ),
                    onTap: () {
                      final name = _nameController.text.trim();
                      DayOneTutorialDialog.show(context, userName: name);
                    },
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
                  fillColor: g.recessed,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s12,
                    vertical: AppSpace.s14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(
                      color: g.controlOutline,
                      width: AscentDimensions.controlOutlineWidth,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(
                      color: g.controlOutline,
                      width: AscentDimensions.controlOutlineWidth,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                    borderSide: BorderSide(
                      color: g.focusRing,
                      width: AscentDimensions.focusRingWidth,
                    ),
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
