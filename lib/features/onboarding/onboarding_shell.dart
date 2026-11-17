import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/cosmic_profile_service.dart';
import '../../shared/widgets/app_text_field.dart';

// ---------------------------------------------------------------------------
// Onboarding State Model & Provider
// ---------------------------------------------------------------------------

class OnboardingDraftState {
  /// Step index in the 6-screen journey:
  /// 0: 1 · Welcome ("Let's begin")
  /// 1: 2 · What you get ("1 of 4")
  /// 2: 3 · Your name ("2 of 4")
  /// 3: 4 · Birthday ("3 of 4")
  /// 4: 5 · Your climb ("4 of 4")
  /// 5: 6 · Ready ("Enter Ascent")
  final int stepIndex;
  final String name;
  final String targetRole;
  final List<String> targetCompanies;
  final String companionName;
  final DayThemePreset themePreset;
  final String focusArea;
  final DateTime? interviewDate;
  final DateTime? dateOfBirth;
  final bool isJustPreparing;
  final int weeklyHours;
  final bool isSubmitting;

  const OnboardingDraftState({
    this.stepIndex = 0,
    this.name = '',
    this.targetRole = 'Focus and flow',
    this.targetCompanies = const [],
    this.companionName = 'Riya',
    this.themePreset = DayThemePreset.merlotLinen,
    this.focusArea = 'Focus and flow',
    this.interviewDate,
    this.dateOfBirth,
    this.isJustPreparing = true,
    this.weeklyHours = 12,
    this.isSubmitting = false,
  });

  OnboardingDraftState copyWith({
    int? stepIndex,
    String? name,
    String? targetRole,
    List<String>? targetCompanies,
    String? companionName,
    DayThemePreset? themePreset,
    String? focusArea,
    DateTime? interviewDate,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    bool? isJustPreparing,
    int? weeklyHours,
    bool? isSubmitting,
  }) {
    return OnboardingDraftState(
      stepIndex: stepIndex ?? this.stepIndex,
      name: name ?? this.name,
      targetRole: targetRole ?? this.targetRole,
      targetCompanies: targetCompanies ?? this.targetCompanies,
      companionName: companionName ?? this.companionName,
      themePreset: themePreset ?? this.themePreset,
      focusArea: focusArea ?? this.focusArea,
      interviewDate: interviewDate ?? this.interviewDate,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      isJustPreparing: isJustPreparing ?? this.isJustPreparing,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingDraftState> {
  @override
  OnboardingDraftState build() {
    final currentTheme = ref.read(dayThemePresetProvider);
    final currentAssistant = ref.read(assistantNameProvider);
    return OnboardingDraftState(
      companionName: currentAssistant.isNotEmpty ? currentAssistant : 'Riya',
      themePreset: currentTheme,
      focusArea: 'Focus and flow',
      dateOfBirth: DateTime(2000, 6, 18),
    );
  }

  void setStep(int index) => state = state.copyWith(stepIndex: index);

  void updateNameRole(String name, String role) =>
      state = state.copyWith(name: name, targetRole: role);

  void setDateOfBirth(DateTime? dob) {
    if (dob == null) {
      state = state.copyWith(clearDateOfBirth: true);
    } else {
      state = state.copyWith(dateOfBirth: dob);
    }
  }

  void setCompanion(String companion) {
    state = state.copyWith(companionName: companion);
    ref.read(assistantNameProvider.notifier).setName(companion);
  }

  void setThemePreset(DayThemePreset preset) {
    state = state.copyWith(themePreset: preset);
    ref.read(dayThemePresetProvider.notifier).setPreset(preset);
  }

  void setFocusArea(String focus) {
    state = state.copyWith(focusArea: focus, targetRole: focus);
  }

  void toggleCompany(String company) {
    final list = List<String>.from(state.targetCompanies);
    if (list.contains(company)) {
      list.remove(company);
    } else {
      list.add(company);
    }
    state = state.copyWith(targetCompanies: list);
  }

  void addCustomCompany(String company) {
    final trimmed = company.trim();
    if (trimmed.isEmpty) return;
    final list = List<String>.from(state.targetCompanies);
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      state = state.copyWith(targetCompanies: list);
    }
  }

  Future<bool> startWithoutSetup() async => false;

  Future<bool> submitAndSeedPlan(
    BuildContext context,
    WidgetRef widgetRef,
  ) async {
    if (state.isSubmitting ||
        state.name.trim().runes.length < 2 ||
        state.dateOfBirth == null ||
        state.dateOfBirth!.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return false;
    }
    state = state.copyWith(isSubmitting: true);
    try {
      final db = ref.read(databaseProvider);
      final cleanName = state.name.trim();
      final cleanRole = state.targetRole.trim().isNotEmpty
          ? state.targetRole.trim()
          : (state.focusArea.isNotEmpty ? state.focusArea : 'Focus and flow');

      await db.transaction(() async {
        final existingProfile = await db.userProfileDao.getProfile();
        await db.userProfileDao.upsertProfile(
          UserProfileTableCompanion(
            id: drift.Value(existingProfile?.id ?? 1),
            name: drift.Value(cleanName),
            targetRole: drift.Value(cleanRole),
            targetCompanies: drift.Value(jsonEncode(state.targetCompanies)),
            interviewDate: drift.Value(state.interviewDate),
            dateOfBirth: drift.Value(state.dateOfBirth),
            weeklyHoursAvailable: drift.Value(state.weeklyHours),
            onboardingComplete: const drift.Value(true),
            lastOpenedAt: drift.Value(DateTime.now()),
          ),
        );
      });

      await ref
          .read(assistantNameProvider.notifier)
          .setName(state.companionName);
      await ref
          .read(dayThemePresetProvider.notifier)
          .setPreset(state.themePreset);

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('ascent_quick_start_v1', true);
      await prefs.setBool('ascent_first_moment_pending_v1', true);
      await markOnboardingComplete(widgetRef);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingDraftState>(
      OnboardingNotifier.new,
    );

// ---------------------------------------------------------------------------
// Design Palette & Dimensions
// ---------------------------------------------------------------------------

const _brandBlue = Color(0xFF2F6FED);
const _brandBlueAction = Color(0xFF1D4FD7);
const _accentAmber = Color(0xFFFFB547);
const _accentEmerald = Color(0xFF0A8F63);
const _accentRose = Color(0xFFD13F83);

/// Ascent Onboarding Experience — 6 Calm, Distinct Boards
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({super.key});

  @override
  Widget build(BuildContext context) => const _OnboardingNavigator();
}

class _OnboardingNavigator extends ConsumerStatefulWidget {
  const _OnboardingNavigator();

  @override
  ConsumerState<_OnboardingNavigator> createState() =>
      _OnboardingNavigatorState();
}

class _OnboardingNavigatorState extends ConsumerState<_OnboardingNavigator> {
  final _nameController = TextEditingController();
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _showNameError = false;
  bool _showDobError = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingProvider);
    if (draft.name.isNotEmpty) {
      _nameController.text = draft.name;
    }
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _handleBack() {
    final state = ref.read(onboardingProvider);
    if (state.isSubmitting) return;
    HapticFeedback.lightImpact();
    if (state.stepIndex > 0) {
      ref.read(onboardingProvider.notifier).setStep(state.stepIndex - 1);
      _resetScroll();
    }
  }

  String _titleCase(String text) {
    if (text.trim().isEmpty) return '';
    return text.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return '';
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  Future<void> _handleNext() async {
    final notifier = ref.read(onboardingProvider.notifier);
    final state = ref.read(onboardingProvider);
    if (state.isSubmitting) return;

    HapticFeedback.lightImpact();

    switch (state.stepIndex) {
      case 0:
        // Welcome -> What you get
        notifier.setStep(1);
        _resetScroll();
        break;
      case 1:
        // What you get -> Your name
        notifier.setStep(2);
        _resetScroll();
        break;
      case 2:
        // Your name -> Birthday
        final name = _nameController.text.trim();
        if (name.runes.length < 2) {
          setState(() => _showNameError = true);
          return;
        }
        setState(() => _showNameError = false);
        final titleCasedName = _titleCase(name);
        _nameController.text = titleCasedName;
        notifier.updateNameRole(titleCasedName, state.focusArea);
        notifier.setStep(3);
        _resetScroll();
        break;
      case 3:
        // Birthday -> Primary focus
        if (state.dateOfBirth == null) {
          setState(() => _showDobError = true);
          return;
        }
        setState(() => _showDobError = false);
        notifier.setStep(4);
        _resetScroll();
        break;
      case 4:
        // Primary focus -> Ready
        notifier.setStep(5);
        _resetScroll();
        break;
      case 5:
        // Ready -> Finish & Enter Ascent
        final cleanName = _titleCase(
          _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : state.name.trim(),
        );
        notifier.updateNameRole(cleanName, state.focusArea);
        final saved = await notifier.submitAndSeedPlan(context, ref);
        if (!mounted) return;
        if (saved) {
          context.go(
            NotificationService.consumePendingDestination() ?? '/home',
          );
        } else {
          setState(
            () => _error =
                'Could not complete setup. Your inputs were preserved, please try again.',
          );
        }
        break;
    }
  }

  Future<void> _pickBirthdayDialog() async {
    FocusScope.of(context).unfocus();
    final now = DateUtils.dateOnly(DateTime.now());
    final state = ref.read(onboardingProvider);
    final value = await showDatePicker(
      context: context,
      helpText: 'Select your birth date',
      initialDate:
          state.dateOfBirth ?? DateTime(now.year - 24, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (value != null && mounted) {
      ref.read(onboardingProvider.notifier).setDateOfBirth(value);
      setState(() {
        _showDobError = false;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(onboardingProvider);
    final step = state.stepIndex;

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF090D16) : const Color(0xFFF3F8FF),
        body: Stack(
          children: [
            // ── Background Ambient Glowing Orbs ──
            Positioned(
              top: -130,
              right: -120,
              child: IgnorePointer(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(isDark ? 0x2EFEB878 : 0x66FFBE78),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -160,
              child: IgnorePointer(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(isDark ? 0x247DB4FF : 0x617DB4FF),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -100,
              child: IgnorePointer(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(isDark ? 0x226EE7B7 : 0x4D6EE7B7),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65],
                    ),
                  ),
                ),
              ),
            ),

            // ── Screen Content SafeArea ──
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: AnimatedSwitcher(
                      duration: Duration(
                        milliseconds:
                            MediaQuery.disableAnimationsOf(context) ? 0 : 280,
                      ),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.04, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ));
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide,
                            child: child,
                          ),
                        );
                      },
                      child: _buildCurrentScreen(context, state, isDark),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    switch (state.stepIndex) {
      case 0:
        return _buildScreen1Welcome(context, state, isDark);
      case 1:
        return _buildScreen2WhatYouGet(context, state, isDark);
      case 2:
        return _buildScreen3YourName(context, state, isDark);
      case 3:
        return _buildScreen4Birthday(context, state, isDark);
      case 4:
        return _buildScreen5YourClimb(context, state, isDark);
      case 5:
      default:
        return _buildScreen6Ready(context, state, isDark);
    }
  }

  // ===========================================================================
  // SCREEN 1: Welcome
  // ===========================================================================
  Widget _buildScreen1Welcome(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;

    return Column(
      key: const ValueKey('onboarding_screen_welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildBrandHeader(isDark, g),
        const SizedBox(height: 28),

        // Visual Ascending Bars
        Center(child: _AscendingBarsVisual(isDark: isDark, isReady: false)),

        const SizedBox(height: 36),

        // Sanctuary Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x33FFFFFF)
                : Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.20)
                  : const Color(0x383B82F6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: _brandBlue,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Your personal sanctuary',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? const Color(0xFF93C5FD) : _brandBlueAction,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Climb a little,\nevery day.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 38,
            height: 1.08,
            letterSpacing: -0.03,
            fontWeight: FontWeight.w800,
            color: g.ink,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Plans, focus, routines and a gentle companion, all in one calm place.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            height: 1.5,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
          ),
        ),

        const SizedBox(height: 32),

        Center(
          child: _OnboardingActionButton(
            key: const ValueKey('onboarding_next'),
            label: 'Let’s begin',
            isDark: isDark,
            onPressed: _handleNext,
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            'Private, local and crafted for your peace of mind.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? const Color(0xFF718096) : const Color(0xFF5A6785),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 2: What You Get (1 of 4)
  // ===========================================================================
  Widget _buildScreen2WhatYouGet(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;

    return Column(
      key: const ValueKey('onboarding_screen_what_you_get'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildStepHeader(
          stepText: '1 of 4',
          isDark: isDark,
          onBack: _handleBack,
        ),
        const SizedBox(height: 28),

        Text(
          'Everything for your day, in one calm place.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            height: 1.15,
            letterSpacing: -0.025,
            fontWeight: FontWeight.w800,
            color: g.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Four quiet helpers that work together.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.5,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
          ),
        ),

        const SizedBox(height: 24),

        // 2x2 Feature Grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFeatureTile(
              context,
              icon: Icons.wb_sunny_rounded,
              iconColor: const Color(0xFFC97A00),
              iconBgColor: const Color(0x38FFB547),
              title: 'Daily rhythm',
              description: 'Dayboard, activities and focus timers.',
              isDark: isDark,
            ),
            _buildFeatureTile(
              context,
              icon: Icons.auto_stories_rounded,
              iconColor: _brandBlue,
              iconBgColor: const Color(0x3860A5FA),
              title: 'Study and meals',
              description: 'Syllabus milestones and healthy routines.',
              isDark: isDark,
            ),
            _buildFeatureTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: _accentEmerald,
              iconBgColor: const Color(0x3834D399),
              title: 'Riya, your companion',
              description: 'A gentle AI that keeps you on track.',
              isDark: isDark,
            ),
            _buildFeatureTile(
              context,
              icon: Icons.shield_outlined,
              iconColor: _accentRose,
              iconBgColor: const Color(0x33F472B6),
              title: 'Care and wealth',
              description: 'Medicine reminders and mindful spend limits.',
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: 36),

        Center(
          child: _OnboardingActionButton(
            key: const ValueKey('onboarding_next'),
            label: 'Continue',
            isDark: isDark,
            onPressed: _handleNext,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 3: Your Name (2 of 4)
  // ===========================================================================
  Widget _buildScreen3YourName(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;
    final nameTrimmed = _nameController.text.trim();
    final isNameValid = nameTrimmed.runes.length >= 2;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('onboarding_screen_name'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildStepHeader(
            stepText: '2 of 4',
            isDark: isDark,
            onBack: _handleBack,
          ),
          const SizedBox(height: 28),

          Text(
            'MAKE ASCENT YOURS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.10,
              color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'First, what should we call you?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              height: 1.12,
              letterSpacing: -0.028,
              fontWeight: FontWeight.w800,
              color: g.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ascent will greet you by name, every day.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.5,
              color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'YOUR NAME',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
              color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF5A6785),
            ),
          ),
          const SizedBox(height: 10),

          // Single-enclosure Input via AppTextField
          AppTextField(
            key: const ValueKey('onboarding_name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleNext(),
            onChanged: (_) => setState(() {}),
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            hintText: 'What should we call you?',
            suffixIcon: isNameValid
                ? Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.secondary,
                  )
                : (nameTrimmed.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        onPressed: () => _nameController.clear(),
                      )
                    : null),
          ),

          const SizedBox(height: 10),
          Text(
            _showNameError
                ? 'Required. At least 2 characters.'
                : 'Required. At least 2 characters.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: _showNameError ? FontWeight.w600 : FontWeight.w500,
              color: _showNameError
                  ? Colors.redAccent
                  : (isDark
                      ? const Color(0xFF718096)
                      : const Color(0xFF5A6785)),
            ),
          ),

          const SizedBox(height: 26),

          // Live Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0x2EFFFFFF)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0x120F1B3D),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A5C4A3E),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.10,
                    color: isDark
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF5A6785),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_timeGreeting()}, ${nameTrimmed.isNotEmpty ? _titleCase(nameTrimmed) : 'Arun'}.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here is what today looks like.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF51607F),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          Center(
            child: _OnboardingActionButton(
              key: const ValueKey('onboarding_next'),
              label: 'Continue',
              isDark: isDark,
              onPressed: _handleNext,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCREEN 4: Birthday (3 of 4)
  // ===========================================================================
  Widget _buildScreen4Birthday(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;
    final dob = state.dateOfBirth ?? DateTime(2000, 6, 18);
    final zodiac = const CosmicProfileService().getZodiac(dob);

    return Column(
      key: const ValueKey('onboarding_screen_birthday'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildStepHeader(
          stepText: '3 of 4',
          isDark: isDark,
          onBack: _handleBack,
        ),
        const SizedBox(height: 28),

        Text(
          'MAKE ASCENT YOURS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'When is your birthday?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            height: 1.12,
            letterSpacing: -0.028,
            fontWeight: FontWeight.w800,
            color: g.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We will remember it, and shape your cosmic header around it.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.5,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
          ),
        ),

        const SizedBox(height: 24),

        // Column Labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'DAY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                    color: isDark
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF5A6785),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'MONTH',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                    color: isDark
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF5A6785),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'YEAR',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                    color: isDark
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF5A6785),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Interactive Glass Drum Picker
        Semantics(
          button: true,
          label: 'Date of birth picker',
          child: KeyedSubtree(
            key: const ValueKey('onboarding_dob_picker'),
            child: InkWell(
              key: const ValueKey('onboarding_dob'),
              onTap: _pickBirthdayDialog,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 240,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0x2EFFFFFF)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _showDobError
                        ? Colors.redAccent
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0x120F1B3D)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.20)
                          : const Color(0x143B82F6),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Selection highlight bar
                    Positioned(
                      left: 10,
                      right: 10,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0x3860A5FA),
                              Color(0x2934D399),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0x613B82F6),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // 3 Interactive Roller Wheels
                    Row(
                      children: [
                        // Day wheel (1..31)
                        Expanded(
                          child: _WheelDrumPicker(
                            itemCount: 31,
                            initialItem: dob.day - 1,
                            itemBuilder: (context, index) {
                              final dayVal = index + 1;
                              final isSelected = dayVal == dob.day;
                              return Center(
                                child: Text(
                                  dayVal.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSelected ? 22 : 18,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? g.ink
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.35)
                                            : const Color(0x660F1B3D)),
                                  ),
                                ),
                              );
                            },
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              final newDay = index + 1;
                              final maxDays = DateUtils.getDaysInMonth(
                                  dob.year, dob.month);
                              final clampedDay = newDay.clamp(1, maxDays);
                              ref
                                  .read(onboardingProvider.notifier)
                                  .setDateOfBirth(DateTime(
                                      dob.year, dob.month, clampedDay));
                            },
                          ),
                        ),

                        // Month wheel (Jan..Dec)
                        Expanded(
                          child: _WheelDrumPicker(
                            itemCount: 12,
                            initialItem: dob.month - 1,
                            itemBuilder: (context, index) {
                              const monthNames = [
                                'January',
                                'February',
                                'March',
                                'April',
                                'May',
                                'June',
                                'July',
                                'August',
                                'September',
                                'October',
                                'November',
                                'December',
                              ];
                              final isSelected = (index + 1) == dob.month;
                              return Center(
                                child: Text(
                                  monthNames[index],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSelected ? 20 : 17,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? g.ink
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.35)
                                            : const Color(0x660F1B3D)),
                                  ),
                                ),
                              );
                            },
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              final newMonth = index + 1;
                              final maxDays =
                                  DateUtils.getDaysInMonth(dob.year, newMonth);
                              final clampedDay = dob.day.clamp(1, maxDays);
                              ref
                                  .read(onboardingProvider.notifier)
                                  .setDateOfBirth(DateTime(
                                      dob.year, newMonth, clampedDay));
                            },
                          ),
                        ),

                        // Year wheel (1930..current year)
                        Expanded(
                          child: _WheelDrumPicker(
                            itemCount: DateTime.now().year - 1930 + 1,
                            initialItem: (dob.year - 1930)
                                .clamp(0, DateTime.now().year - 1930),
                            itemBuilder: (context, index) {
                              final yearVal = 1930 + index;
                              final isSelected = yearVal == dob.year;
                              return Center(
                                child: Text(
                                  yearVal.toString(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isSelected ? 22 : 18,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? g.ink
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.35)
                                            : const Color(0x660F1B3D)),
                                  ),
                                ),
                              );
                            },
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              final newYear = 1930 + index;
                              final maxDays =
                                  DateUtils.getDaysInMonth(newYear, dob.month);
                              final clampedDay = dob.day.clamp(1, maxDays);
                              ref
                                  .read(onboardingProvider.notifier)
                                  .setDateOfBirth(DateTime(
                                      newYear, dob.month, clampedDay));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Astrological / Cosmic Profile Preview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x382A2014)
                : const Color(0xD9FFF8EB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x73FFB547),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x42FFB547),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    zodiac.symbol,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${zodiac.vedicRashi} · ${zodiac.name}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zodiac.archetype,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFFFD599)
                            : const Color(0xFF6A5326),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text(
          'Required. Stays private on this device.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark ? const Color(0xFF718096) : const Color(0xFF5A6785),
          ),
        ),

        const SizedBox(height: 36),

        Center(
          child: _OnboardingActionButton(
            key: const ValueKey('onboarding_next'),
            label: 'Continue',
            isDark: isDark,
            onPressed: _handleNext,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 5: Your Climb (4 of 4)
  // ===========================================================================
  Widget _buildScreen5YourClimb(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;

    return Column(
      key: const ValueKey('onboarding_screen_your_climb'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildStepHeader(
          stepText: '4 of 4',
          isDark: isDark,
          onBack: _handleBack,
        ),
        const SizedBox(height: 28),

        Text(
          'MAKE ASCENT YOURS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.10,
            color: isDark ? const Color(0xFF93C5FD) : _brandBlue,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'What do you want most right now?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            height: 1.12,
            letterSpacing: -0.028,
            fontWeight: FontWeight.w800,
            color: g.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pick your primary focus. Ascent shapes Home around it.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.5,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
          ),
        ),

        const SizedBox(height: 24),

        // 2x2 Focus Cards Grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFocusTile(
              context,
              title: 'Inner peace',
              icon: Icons.air_rounded,
              iconColor: _accentEmerald,
              iconBgColor: const Color(0x3834D399),
              isSelected: state.focusArea.toLowerCase().contains('inner'),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(onboardingProvider.notifier)
                    .setFocusArea('Inner peace');
              },
            ),
            _buildFocusTile(
              context,
              title: 'Focus and flow',
              icon: Icons.adjust_rounded,
              iconColor: _brandBlue,
              iconBgColor: const Color(0x3860A5FA),
              isSelected: state.focusArea.toLowerCase().contains('focus'),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(onboardingProvider.notifier)
                    .setFocusArea('Focus and flow');
              },
            ),
            _buildFocusTile(
              context,
              title: 'Study and growth',
              icon: Icons.school_rounded,
              iconColor: _brandBlue,
              iconBgColor: const Color(0x3860A5FA),
              isSelected: state.focusArea.toLowerCase().contains('study'),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(onboardingProvider.notifier)
                    .setFocusArea('Study and growth');
              },
            ),
            _buildFocusTile(
              context,
              title: 'Daily vitality',
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFC97A00),
              iconBgColor: const Color(0x38FFB547),
              isSelected: state.focusArea.toLowerCase().contains('vitality'),
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(onboardingProvider.notifier)
                    .setFocusArea('Daily vitality');
              },
            ),
          ],
        ),

        const SizedBox(height: 18),
        Center(
          child: Text(
            'You can change this anytime in Settings.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? const Color(0xFF718096) : const Color(0xFF5A6785),
            ),
          ),
        ),

        const SizedBox(height: 36),

        Center(
          child: _OnboardingActionButton(
            key: const ValueKey('onboarding_next'),
            label: 'Continue',
            isDark: isDark,
            onPressed: _handleNext,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 6: Ready
  // ===========================================================================
  Widget _buildScreen6Ready(
    BuildContext context,
    OnboardingDraftState state,
    bool isDark,
  ) {
    final g = context.glass;
    final name = state.name.trim().isNotEmpty
        ? state.name.trim()
        : (_nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Arun');

    return Column(
      key: const ValueKey('onboarding_screen_ready'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildBrandHeader(isDark, g),
        const SizedBox(height: 28),

        // Visual Ascending Bars - Ready peak
        Center(child: _AscendingBarsVisual(isDark: isDark, isReady: true)),

        const SizedBox(height: 36),

        Text(
          'You are all set, $name.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            height: 1.08,
            letterSpacing: -0.03,
            fontWeight: FontWeight.w800,
            color: g.ink,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Your Home is ready, shaped around ${state.focusArea.toLowerCase()}.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            height: 1.5,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent,
            ),
          ),
        ],

        const SizedBox(height: 36),

        Center(
          child: _OnboardingActionButton(
            key: const ValueKey('onboarding_next'),
            label: 'Enter Ascent',
            isDark: isDark,
            loading: state.isSubmitting,
            onPressed: state.isSubmitting ? null : _handleNext,
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            'Everything stays on your device.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark ? const Color(0xFF718096) : const Color(0xFF5A6785),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // Shared Visual Components
  // ===========================================================================

  Widget _buildBrandHeader(bool isDark, AscentGlass g) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x33FFFFFF)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0x140F1B3D),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 26,
              color: _brandBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Ascent',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.01,
                color: g.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader({
    required String stepText,
    required bool isDark,
    required VoidCallback onBack,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          key: const ValueKey('onboarding_back'),
          borderRadius: BorderRadius.circular(20),
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0x33FFFFFF)
                  : Colors.white.withValues(alpha: 0.80),
              border: Border.all(
                color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0x1A0F1B3D),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: _brandBlue,
              ),
            ),
          ),
        ),
        Text(
          stepText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04,
            color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF5A6785),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required bool isDark,
  }) {
    final g = context.glass;
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Container(
        width: width < 140 ? constraints.maxWidth : width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0x2EFFFFFF)
              : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0x120F1B3D),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.20)
                  : const Color(0x143B82F6),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: g.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFFA0AEC0) : const Color(0xFF51607F),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFocusTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final g = context.glass;

    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width < 140 ? constraints.maxWidth : width,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0x382F6FED)
                    : const Color(0x3860A5FA))
                : (isDark
                    ? const Color(0x2EFFFFFF)
                    : Colors.white.withValues(alpha: 0.72)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? _brandBlue
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0x120F1B3D)),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _brandBlue.withValues(alpha: 0.18)
                    : (isDark
                        ? Colors.black.withValues(alpha: 0.20)
                        : const Color(0x143B82F6)),
                blurRadius: isSelected ? 30 : 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Icon(icon, size: 22, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: g.ink,
                      ),
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _brandBlue.withValues(alpha: 0.20),
                      border: Border.all(
                        color: _brandBlue,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: _brandBlueAction,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 5 Ascending Bars Visual Component (Screens 1 and 6)
// ---------------------------------------------------------------------------

class _AscendingBarsVisual extends StatelessWidget {
  final bool isDark;
  final bool isReady;

  const _AscendingBarsVisual({
    required this.isDark,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
          // Bar 1
          _buildBar(
            width: 46,
            height: isReady ? 60 : 64,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x667DB4FF),
                Color(0x247DB4FF),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Bar 2
          _buildBar(
            width: 46,
            height: isReady ? 96 : 104,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x8A7DB4FF),
                Color(0x337DB4FF),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Bar 3
          _buildBar(
            width: 46,
            height: isReady ? 134 : 148,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xAD7DB4FF),
                Color(0x427DB4FF),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Bar 4
          _buildBar(
            width: 46,
            height: isReady ? 174 : 196,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC6EE7B7),
                Color(0x527DB4FF),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Bar 5 with Peak Sun Dot
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Sun Dot
              Container(
                width: isReady ? 18 : 16,
                height: isReady ? 18 : 16,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentAmber,
                  boxShadow: [
                    BoxShadow(
                      color: _accentAmber.withValues(alpha: 0.35),
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: _accentAmber.withValues(alpha: 0.70),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
              _buildBar(
                width: 46,
                height: isReady ? 216 : 248,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8EC0FF),
                    Color(0xFF4E8DF6),
                  ],
                ),
                isPeak: true,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBar({
    required double width,
    required double height,
    required Gradient gradient,
    bool isPeak = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
        border: Border.all(
          color: isPeak
              ? Colors.white.withValues(alpha: 0.80)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0x383B82F6)),
          width: 1,
        ),
        boxShadow: isPeak
            ? [
                BoxShadow(
                  color: _brandBlue.withValues(alpha: 0.34),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interactive Wheel Drum Picker (Screen 4)
// ---------------------------------------------------------------------------

class _WheelDrumPicker extends StatelessWidget {
  final int itemCount;
  final int initialItem;
  final Widget Function(BuildContext, int) itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  const _WheelDrumPicker({
    required this.itemCount,
    required this.initialItem,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      itemExtent: 48,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      controller: FixedExtentScrollController(initialItem: initialItem),
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: itemBuilder,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding Gradient Action Button
// ---------------------------------------------------------------------------

class _OnboardingActionButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool loading;
  final VoidCallback? onPressed;

  const _OnboardingActionButton({
    super.key,
    required this.label,
    required this.isDark,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minWidth: 232, maxWidth: 360),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x4D60A5FA),
                Color(0x3834D399),
              ],
            ),
            border: Border.all(
              color: const Color(0x6B3B82F6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x293B82F6),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_brandBlueAction),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _brandBlueAction,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _brandBlueAction,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
