import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/color_tokens.dart';
import '../../shared/widgets/app_surfaces.dart';
import 'app_lock_provider.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final lockState = ref.read(appLockProvider);
      if (lockState.isEnabled && !lockState.isLocked) {
        ref.read(appLockProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);

    if (lockState.isEnabled && lockState.isLocked) {
      return const AppLockScreen();
    }

    return widget.child;
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredPin = '';
  bool _isError = false;
  bool _isVerifying = false;

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4 || _isVerifying) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isVerifying) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _verify() async {
    setState(() => _isVerifying = true);
    final ok = await ref.read(appLockProvider.notifier).verifyPin(_enteredPin);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _enteredPin = '';
        _isVerifying = false;
      });
    }
  }

  Future<void> _triggerBiometrics() async {
    HapticFeedback.selectionClick();
    final ok = await ref.read(appLockProvider.notifier).authenticateBiometrics();
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockState = ref.watch(appLockProvider);

    return Scaffold(
      key: const ValueKey('app_lock_screen'),
      backgroundColor: isDark ? const Color(0xFF090E17) : const Color(0xFFF3F7FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Glowing Security Badge
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: g.clay.withValues(alpha: isDark ? 0.20 : 0.12),
                      border: Border.all(
                        color: g.clay.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: g.clay.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 38,
                        color: g.clay,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ascent Locked',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: g.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isError
                        ? 'Incorrect PIN. Try again.'
                        : 'Enter your 4-digit PIN to access your workspace',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isError ? g.coral : g.inkMuted,
                      fontWeight: _isError ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // PIN Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_isError ? g.coral : g.clay)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isError
                                ? g.coral
                                : (isFilled ? g.clay : g.line),
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Keypad
                  _buildKeypad(g, isDark, lockState.biometricsEnabled),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(AscentGlass g, bool isDark, bool biometricsEnabled) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKeypadRow(['1', '2', '3'], g, isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], g, isDark),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], g, isDark),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (biometricsEnabled)
              _buildSpecialKey(
                key: const ValueKey('keypad_biometrics'),
                icon: Icons.fingerprint_rounded,
                onTap: _triggerBiometrics,
                g: g,
                isDark: isDark,
              )
            else
              const SizedBox(width: 68, height: 68),
            _buildKeypadButton('0', g, isDark),
            _buildSpecialKey(
              key: const ValueKey('keypad_backspace'),
              icon: Icons.backspace_outlined,
              onTap: _onBackspace,
              g: g,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, AscentGlass g, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, g, isDark)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, AscentGlass g, bool isDark) {
    return InkWell(
      key: ValueKey('keypad_$digit'),
      onTap: () => _onDigit(digit),
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          border: Border.all(
            color: g.line.withValues(alpha: isDark ? 0.25 : 0.4),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: g.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    required AscentGlass g,
    required bool isDark,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        width: 68,
        height: 68,
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: g.inkSecondary,
          ),
        ),
      ),
    );
  }
}
