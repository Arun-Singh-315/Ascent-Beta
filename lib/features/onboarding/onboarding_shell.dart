import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/ascent_tokens.dart';
import '../../app/theme/calm_blue_palette.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/features/feature_registry.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/local_day_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../home/widgets/home_unlock_next_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_icon.dart';
import '../../shared/widgets/ascent_logo.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_small_button.dart';
import '../home/v7/home_region.dart';

/// First run: three calm, skippable screens (CLAUDE.md §1.2).
///
/// 1. Welcome — what Ascent is, in one line.
/// 2. You — optional name with a live greeting, and Auto/Light/Dark.
/// 3. Your first two — pick the features to start with (see
///    [featureSpecs]); the rest unlock later from Home and You.
///
/// Skip works on every screen and goes straight in with Plan and Thoughts.
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
  final Set<AscentFeature> _picked = {...defaultStarterFeatures};

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

  Future<void> _finish({bool skipped = false}) async {
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
      await ref
          .read(unlockedFeaturesProvider.notifier)
          .set(skipped || _picked.isEmpty ? defaultStarterFeatures : _picked);
      await prefs.setString(
        featuresStartedKey,
        ref.read(localDayProvider).toIso8601String(),
      );
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
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      key: const ValueKey('onboarding'),
      backgroundColor: t.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // The same quiet page as Home: canvas deepening very slightly.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.canvas, t.recessed],
                ),
              ),
            ),
          ),
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
                      AscentSmallButton.ghost(
                        key: const ValueKey('onboarding_skip'),
                        label: 'Skip',
                        onPressed: _finishing
                            ? null
                            : () => _finish(skipped: true),
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
                      _YouPage(controller: _name, active: _page == 1),
                      _PickPage(
                        active: _page == 2,
                        picked: _picked,
                        onToggle: (f) => setState(() {
                          HapticFeedback.selectionClick();
                          _picked.contains(f)
                              ? _picked.remove(f)
                              : _picked.add(f);
                        }),
                      ),
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
                  child: AscentSmallButton.filled(
                    key: const ValueKey('onboarding_next'),
                    label: switch (_page) {
                      0 => 'Get started',
                      1 =>
                        _name.text.trim().isEmpty
                            ? 'Continue'
                            : 'Nice to meet you',
                      _ =>
                        _picked.isEmpty
                            ? 'Pick at least one'
                            : 'Start with ${_picked.length == 1
                                  ? 'one'
                                  : _picked.length == 2
                                  ? 'these two'
                                  : 'these ${_picked.length}'}',
                    },
                    expanded: true,
                    onPressed: _finishing || (_page == 2 && _picked.isEmpty)
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

/// A feature's glyph and colour, matching Home.
(AscentGlyph?, Color) _look(AscentTokens t, AscentFeature f) => switch (f) {
  AscentFeature.things => (AscentGlyph.things, t.action),
  AscentFeature.mind => (AscentGlyph.mind, t.think),
  AscentFeature.care => (AscentGlyph.life, t.care),
  AscentFeature.money => (AscentGlyph.money, t.money),
  AscentFeature.focus => (AscentGlyph.focus, t.focus),
  _ => (null, t.action),
};

class _Title extends StatelessWidget {
  const _Title(this.text, {this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: AscentTextStyles.greeting.copyWith(color: context.tokens.action),
  );
}

class _Lede extends StatelessWidget {
  const _Lede(this.text, {this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: AscentTextStyles.row.copyWith(
      color: context.tokens.labelSecondary,
      height: 1.45,
    ),
  );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pillars = [
      (AscentGlyph.home, t.action, 'Today', 'Your day at a glance'),
      (AscentGlyph.things, t.action, 'Plan', 'To-dos, routines and plans'),
      (AscentGlyph.mind, t.think, 'Think', 'Thoughts, safely kept'),
      (AscentGlyph.life, t.care, 'Live', 'Water, medicine and money'),
    ];
    return _PageBody(
      children: [
        _Reveal(
          active: active,
          index: 0,
          child: const Center(child: AscentLogo(size: 68)),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 1,
          child: const _Title('Your day,\ncalmly in one place.', center: true),
        ),
        const SizedBox(height: AppSpace.s12),
        _Reveal(
          active: active,
          index: 2,
          child: const _Lede(
            'Plan, think and take care of yourself. It works offline and '
            'stays yours.',
            center: true,
          ),
        ),
        const SizedBox(height: AppSpace.s28),
        _Reveal(
          active: active,
          index: 3,
          child: HomeRegion(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, p) in pillars.indexed)
                  _ListRow(
                    first: i == 0,
                    glyph: p.$1,
                    color: p.$2,
                    title: p.$3,
                    subtitle: p.$4,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _YouPage extends ConsumerWidget {
  const _YouPage({required this.controller, required this.active});
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
    final t = context.tokens;
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
          child: const _Title('What should we\ncall you?'),
        ),
        const SizedBox(height: AppSpace.s8),
        _Reveal(
          active: active,
          index: 1,
          child: const _Lede('Optional. Only used to greet you.'),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 2,
          child: AppTextField(
            key: const ValueKey('onboarding_name'),
            controller: controller,
            hintText: 'e.g. Arun',
            fillColor: t.region,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        // A live preview of Home's navy panel greeting you.
        _Reveal(
          active: active,
          index: 3,
          child: _GreetingPreview(
            text: name.isEmpty
                ? '${_greeting(DateTime.now())}.'
                : '${_greeting(DateTime.now())}, $name.',
            assistant: assistant,
          ),
        ),
        const SizedBox(height: AppSpace.s28),
        _Reveal(
          active: active,
          index: 4,
          child: Text(
            'LIGHT OR DARK',
            style: AscentTextStyles.eyebrow.copyWith(color: t.labelTertiary),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        _Reveal(
          active: active,
          index: 5,
          child: AscentSegmentedControl<ThemeMode>(
            key: const ValueKey('onboarding_mode'),
            slim: true,
            selected: ref.watch(themeModeProvider),
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
      ],
    );
  }
}

/// The greeting as Home will show it, on the same navy panel.
class _GreetingPreview extends StatelessWidget {
  const _GreetingPreview({required this.text, required this.assistant});
  final String text, assistant;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  CalmBluePalette.darkSummaryTop,
                  CalmBluePalette.darkSummaryBottom,
                ]
              : const [
                  CalmBluePalette.summaryTop,
                  CalmBluePalette.summaryBottom,
                ],
        ),
        border: dark ? Border.all(color: CalmBluePalette.summaryEdge) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: AscentTextStyles.nowTitle.copyWith(
                color: CalmBluePalette.summaryInk,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: CalmBluePalette.summaryDivider),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: AscentIcon(
                  AscentGlyph.riya,
                  size: 14,
                  color: CalmBluePalette.ringFocus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$assistant will greet you by name too.',
                  style: AscentTextStyles.meta.copyWith(
                    color: CalmBluePalette.summarySoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickPage extends StatelessWidget {
  const _PickPage({
    required this.active,
    required this.picked,
    required this.onToggle,
  });
  final bool active;
  final Set<AscentFeature> picked;
  final ValueChanged<AscentFeature> onToggle;

  @override
  Widget build(BuildContext context) {
    final starters = featureSpecs.where((s) => s.starter).toList();
    return _PageBody(
      children: [
        _Reveal(
          active: active,
          index: 0,
          child: const _Title('Pick your\nfirst two.'),
        ),
        const SizedBox(height: AppSpace.s8),
        _Reveal(
          active: active,
          index: 1,
          child: const _Lede('Start small. More unlock as you go.'),
        ),
        const SizedBox(height: AppSpace.s24),
        _Reveal(
          active: active,
          index: 2,
          child: HomeRegion(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (i, s) in starters.indexed)
                  _PickRow(
                    first: i == 0,
                    spec: s,
                    selected: picked.contains(s.id),
                    onTap: () => onToggle(s.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row inside a soft section: tinted glyph tile, title and a quiet line.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.first,
    required this.glyph,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final bool first;
  final AscentGlyph? glyph;
  final Color color;
  final String title, subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: t.lineFaint)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AscentIcon(
                glyph ?? AscentGlyph.you,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.label.copyWith(color: t.label),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AscentTextStyles.meta.copyWith(
                        color: t.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.first,
    required this.spec,
    required this.selected,
    required this.onTap,
  });
  final bool first;
  final FeatureSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (glyph, color) = _look(t, spec.id);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.pick}. ${spec.pitch}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('onboarding_pick_${spec.id.name}'),
        onTap: onTap,
        child: _ListRow(
          first: first,
          glyph: glyph,
          color: color,
          title: spec.pick,
          subtitle: spec.pitch,
          trailing: AnimatedContainer(
            duration: Duration(milliseconds: reduce ? 0 : 200),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? t.actionFill : Colors.transparent,
              border: Border.all(
                color: selected ? t.actionFill : t.labelTertiary,
                width: 2,
              ),
            ),
            child: selected
                ? AscentIcon(AscentGlyph.check, size: 12, color: t.onAction)
                : null,
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(AppSpace.s24),
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

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
              ),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: AppSpace.s4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? t.actionFill : t.separator,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}
