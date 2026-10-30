import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/shared_control_tokens.dart';
import 'app_lock_provider.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _obscured = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final state = ref.read(appLockProvider);
    // Notification shade and biometric windows cause inactive without leaving
    // the app. Cover private content, but lock only on actual backgrounding.
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      if (state.isEnabled && !state.isAuthenticating) {
        ref.read(appLockProvider.notifier).lock();
      }
    }
    final obscured = state.isEnabled && lifecycle != AppLifecycleState.resumed;
    if (mounted && _obscured != obscured) setState(() => _obscured = obscured);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockProvider);
    final locked = state.isEnabled && state.isLocked;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the router and home state alive across authentication.
        Offstage(
          offstage: locked || _obscured,
          child: TickerMode(
            enabled: !locked && !_obscured,
            child: widget.child,
          ),
        ),
        if (locked)
          Positioned.fill(
            // The gate is above the router's Overlay in MaterialApp.builder.
            // Give lock controls their own overlay for tooltips and gestures.
            child: Overlay.wrap(child: const AppLockScreen()),
          )
        else if (_obscured)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: SharedControlColors.actionBlue,
                  size: 32,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});
  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  void _digit(String value) {
    if (_busy ||
        _pin.length == 4 ||
        ref.read(appLockProvider).isAuthenticating) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _pin += value;
    });
    if (_pin.length == 4) _verify();
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await ref.read(appLockProvider.notifier).verifyPin(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) {
        _error = true;
        _pin = '';
      }
    });
    if (!ok) HapticFeedback.heavyImpact();
  }

  Future<void> _biometric() async {
    if (_busy || ref.read(appLockProvider).isAuthenticating) return;
    setState(() => _busy = true);
    await ref.read(appLockProvider.notifier).authenticateBiometrics();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? SharedControlColors.labelDark
        : SharedControlColors.labelLight;
    final secondary = dark ? const Color(0xFFAEAEB2) : const Color(0xFF636366);
    final accent = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final lock = ref.watch(appLockProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('app_lock_screen'),
        backgroundColor: dark
            ? const Color(0xFF101012)
            : SharedControlColors.neutralFillLight,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 34,
                            color: accent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ascent Locked',
                            style: TextStyle(
                              color: ink,
                              fontSize: 27,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.7,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error
                                ? 'Incorrect PIN. Try again.'
                                : 'Enter your 4-digit passcode',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _error
                                  ? SharedControlColors.dueRed
                                  : secondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Semantics(
                            label: '${_pin.length} of 4 digits entered',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                4,
                                (i) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                  ),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < _pin.length
                                        ? accent
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: i < _pin.length
                                          ? accent
                                          : secondary.withValues(alpha: .45),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 34),
                          for (final row in [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                          ]) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                for (final digit in row) _key(digit, ink, dark),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: lock.biometricsEnabled
                                    ? IconButton(
                                        key: const ValueKey(
                                          'keypad_biometrics',
                                        ),
                                        tooltip: 'Use biometrics',
                                        onPressed: _busy ? null : _biometric,
                                        icon: Icon(
                                          Icons.fingerprint_rounded,
                                          color: accent,
                                          size: 28,
                                        ),
                                      )
                                    : null,
                              ),
                              _key('0', ink, dark),
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: IconButton(
                                  key: const ValueKey('keypad_backspace'),
                                  tooltip: 'Delete digit',
                                  onPressed: _busy || _pin.isEmpty
                                      ? null
                                      : () => setState(() {
                                          _pin = _pin.substring(
                                            0,
                                            _pin.length - 1,
                                          );
                                          _error = false;
                                        }),
                                  icon: Icon(
                                    Icons.backspace_outlined,
                                    color: secondary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_busy)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                'Unlocking…',
                                style: TextStyle(
                                  color: secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(String digit, Color ink, bool dark) => Material(
    color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
    shape: const CircleBorder(),
    child: InkWell(
      key: ValueKey('keypad_$digit'),
      customBorder: const CircleBorder(),
      onTap: _busy ? null : () => _digit(digit),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              color: ink,
              fontSize: 32,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  );
}
