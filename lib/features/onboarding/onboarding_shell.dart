import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/brand_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_logo.dart';
import '../../shared/widgets/ascent_segmented_control.dart';

/// First run: three calm, skippable screens (CLAUDE.md §1.2).
///
/// 1. Welcome — what Ascent is, in one line, with the five pillars.
/// 2. Your name — optional; a live preview of the Home greeting.
/// 3. Your look — light/dark and a colour theme, applied live.
///
/// Skip works on every screen and goes straight in with defaults.
class OnboardingShell extends ConsumerStatefulWidget {
  const OnboardingShell({super.key});

  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int page) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static String _titleCase(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    HapticFeedback.lightImpact();
    final name = _titleCase(_name.text);
    try {
      if (name.isNotEmpty) {
        final db = ref.read(databaseProvider);
        final existing = await db.userProfileDao.getProfile();
        await db.userProfileDao.upsertProfile(
          UserProfileTableCompanion(
            id: drift.Value(existing?.id ?? 1),
            name: drift.Value(
              name.length > 100 ? name.substring(0, 100) : name,
            ),
            onboardingComplete: const drift.Value(true),
            lastOpenedAt: drift.Value(DateTime.now()),
          ),
        );
      }
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('ascent_quick_start_v1', true);
      await prefs.setBool('ascent_first_moment_pending_v1', true);
      await markOnboardingComplete(ref);
      if (!mounted) return;
      context.go(NotificationService.consumePendingDestination() ?? '/home');
    } catch (_) {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: const ValueKey('onboarding'),
      backgroundColor: g.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s20,
                    AppSpace.s8,
                    AppSpace.s8,
                    0,
                  ),
                  child: Row(
                    children: [
                      _Dots(count: 3, index: _page),
                      const Spacer(),
                      AscentButton.ghost(
                        key: const ValueKey('onboarding_skip'),
                        label: 'Skip',
                        compact: true,
                        onPressed: _finishing ? null : _finish,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      _WelcomePage(active: _page == 0),
                      _NamePage(controller: _name, active: _page == 1),
                      _LookPage(active: _page == 2),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.s20,
                    AppSpace.s8,
                    AppSpace.s20,
                    AppSpace.s16 + (bottom > 0 ? 0 : AppSpace.s8),
                  ),
                  child: AscentButton.primary(
                    key: const ValueKey('onboarding_next'),
                    label: switch (_page) {
                      0 => 'Get started',
                      1 =>
                        _name.text.trim().isEmpty
                            ? 'Continue'
                            : 'Nice to meet you',
                      _ => 'Enter Ascent',
                    },
                    expanded: true,
                    loading: _finishing,
                    onPressed: _finishing
                        ? null
                        : () => _page < 2 ? _go(_page + 1) : _finish(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pages -----------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.active});
  final bool active;

  static const _pillars = [
    (Icons.wb_sunny_outlined, 'Today', 'Your day at a glance'),
    (Icons.checklist_rounded, 'Plan', 'To-dos, routines and plans'),
    (Icons.bubble_chart_outlined, 'Think', 'Thoughts, safely kept'),
    (Icons.favorite_border_rounded, 'Live', 'Water, medicine, breaks'),
    (Icons.trending_up_rounded, 'Grow', 'Learning and momentum'),
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return _PageBody(
      children: [
        _Reveal(
          active: active,
          index: 0,
          child: const Center(child: AscentLogo(size: 76)),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 1,
          child: Text(
            'Your day,\ncalmly in one place.',
            textAlign: TextAlign.center,
            style: AscentTextStyles.interfaceDisplay.copyWith(
              color: g.ink,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        _Reveal(
          active: active,
          index: 2,
          child: Text(
            'Plan, think, take care of yourself and grow. It all works offline and stays yours.',
            textAlign: TextAlign.center,
            style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
          ),
        ),
        const SizedBox(height: AppSpace.s32),
        for (var i = 0; i < _pillars.length; i++)
          _Reveal(
            active: active,
            index: 3 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s12),
              child: _PillarRow(
                icon: _pillars[i].$1,
                title: _pillars[i].$2,
                subtitle: _pillars[i].$3,
              ),
            ),
          ),
      ],
    );
  }
}

class _NamePage extends ConsumerWidget {
  const _NamePage({required this.controller, required this.active});
  final TextEditingController controller;
  final bool active;

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final assistant = ref.watch(assistantNameProvider);
    final typed = controller.text.trim();
    final name = typed.isEmpty
        ? ''
        : '${typed[0].toUpperCase()}${typed.substring(1)}';
    return _PageBody(
      children: [
        _Reveal(
          active: active,
          index: 0,
          child: Text(
            'What should we\ncall you?',
            style: AscentTextStyles.interfaceDisplay.copyWith(
              color: g.ink,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        _Reveal(
          active: active,
          index: 1,
          child: Text(
            'Optional. Only used to greet you.',
            style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 2,
          child: AppTextField(
            key: const ValueKey('onboarding_name'),
            controller: controller,
            hintText: 'e.g. Arun',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 3,
          child: _GlassCard(
            child: Row(
              children: [
                Icon(Icons.wb_twilight_rounded, color: g.amber),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      name.isEmpty
                          ? '${_greeting(DateTime.now())}.'
                          : '${_greeting(DateTime.now())}, $name.',
                      key: ValueKey(name),
                      style: AscentTextStyles.homeHeadline.copyWith(
                        color: g.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        _Reveal(
          active: active,
          index: 4,
          child: Text(
            '$assistant, your assistant, will greet you by name too.',
            style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _LookPage extends ConsumerWidget {
  const _LookPage({required this.active});
  final bool active;

  static const _presets = [
    (DayThemePreset.merlotLinen, 'Merlot linen', BrandPalette.merlotSwatch),
    (DayThemePreset.classicClay, 'Classic clay', BrandPalette.claySwatch),
    (DayThemePreset.nordicSky, 'Nordic sky', BrandPalette.skySwatch),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final mode = ref.watch(themeModeProvider);
    final preset = ref.watch(dayThemePresetProvider);
    return _PageBody(
      children: [
        _Reveal(
          active: active,
          index: 0,
          child: Text(
            'Make it\nfeel like yours.',
            style: AscentTextStyles.interfaceDisplay.copyWith(
              color: g.ink,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        _Reveal(
          active: active,
          index: 1,
          child: Text(
            'You can change this any time in Settings.',
            style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 2,
          child: AscentSegmentedControl<ThemeMode>(
            key: const ValueKey('onboarding_mode'),
            selected: mode,
            onChanged: (m) {
              HapticFeedback.selectionClick();
              ref.read(themeModeProvider.notifier).setThemeMode(m);
            },
            segments: const [
              AscentSegment(value: ThemeMode.system, label: 'Auto'),
              AscentSegment(value: ThemeMode.light, label: 'Light'),
              AscentSegment(value: ThemeMode.dark, label: 'Dark'),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        for (var i = 0; i < _presets.length; i++)
          _Reveal(
            active: active,
            index: 3 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s12),
              child: _PresetCard(
                key: ValueKey('onboarding_preset_${_presets[i].$1.name}'),
                label: _presets[i].$2,
                colors: _presets[i].$3,
                selected: preset == _presets[i].$1,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(dayThemePresetProvider.notifier)
                      .setPreset(_presets[i].$1);
                },
              ),
            ),
          ),
      ],
    );
  }
}

// Pieces ----------------------------------------------------------------------

class _PageBody extends StatelessWidget {
  const _PageBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s24,
        AppSpace.s24,
        AppSpace.s24,
        AppSpace.s24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: box.maxHeight - AppSpace.s24 * 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// Fades and rises each element in, 60 ms apart, when its page is shown.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.active,
    required this.index,
    required this.child,
  });
  final bool active;
  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _started = false;

  void _maybeStart() {
    if (_started || !widget.active) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future<void>.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant _Reveal old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: g.actionInk.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: g.actionInk, size: 22),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AscentTextStyles.homeHeadline.copyWith(color: g.ink),
                ),
                Text(
                  subtitle,
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    super.key,
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            color: g.surface.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? g.actionInk : g.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Text(
                  label,
                  style: AscentTextStyles.body.copyWith(color: g.ink),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.check_circle_rounded, color: g.actionInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: g.surface.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.line),
      ),
      child: child,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: AppSpace.s4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? g.actionInk : g.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slow, soft colour fields in the assistant gradient. One 18 s loop that
/// stops under reduce motion (CLAUDE.md §3.5).
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();
  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (MediaQuery.disableAnimationsOf(context) || inTest) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.glass.isDark;
    final a = dark ? .22 : .16;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          Widget blob(Color c, Alignment base, double r, double phase) => Align(
            alignment: Alignment(
              base.x + .25 * math.sin(t + phase),
              base.y + .2 * math.cos(t + phase),
            ),
            child: FractionallySizedBox(
              widthFactor: r,
              heightFactor: r * .7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      c.withValues(alpha: a),
                      c.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              blob(
                BrandPalette.assistantIndigo,
                const Alignment(-.9, -.8),
                1.3,
                0,
              ),
              blob(
                BrandPalette.assistantViolet,
                const Alignment(.9, -.3),
                1.1,
                2,
              ),
              blob(
                BrandPalette.assistantPink,
                const Alignment(-.2, .9),
                1.2,
                4,
              ),
            ],
          );
        },
      ),
    );
  }
}
