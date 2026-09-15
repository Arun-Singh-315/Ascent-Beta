import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/database_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  String _versionString = 'BETA';

  @override
  void initState() {
    super.initState();
    _loadVersion();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Spec §1.1: Soft breathing/pulse animation (scale 0.96 <-> 1.0, opacity fade)
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _pulseController.repeat(reverse: true);

    _checkSessionAndNavigate();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _versionString = 'BETA · v${packageInfo.version}';
        });
      }
    } catch (_) {
      // Fallback to default
    }
  }

  Future<void> _checkSessionAndNavigate() async {
    // Spec §1.1: 0.8-1.5s max, no spinner, session check underneath
    final startTime = DateTime.now();

    // Check onboarding completion from SharedPreferences and DB
    final hasCompletedOnboardingPref = ref.read(onboardingCompleteProvider);
    bool hasProfile = false;
    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final profile = await profileDao.getProfile();
      if (profile != null && profile.onboardingComplete) {
        hasProfile = true;
      }
    } catch (_) {
      // Fallback to pref if DB check in-flight
      hasProfile = hasCompletedOnboardingPref;
    }

    final elapsed = DateTime.now().difference(startTime);
    final remainingWait = const Duration(milliseconds: 1100) - elapsed;
    if (remainingWait > Duration.zero) {
      await Future.delayed(remainingWait);
    }

    if (!mounted) return;

    if (hasCompletedOnboardingPref || hasProfile) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgBase,
      body: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo mark: Ascending geometric motif
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: context.bgSurface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: context.accentPrimary.withValues(alpha: 0.15),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: context.divider,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass point / ascending chevron motif
                      Icon(
                        Icons.north_east_rounded,
                        size: 46,
                        color: context.accentPrimary,
                      ),
                      Positioned(
                        bottom: 18,
                        left: 18,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.accentSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // App Name in Plus Jakarta Sans
              Text(
                'Ascent',
                style: AscentTextStyles.displayLarge.copyWith(
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Beta pill badge
              Container(
                decoration: BoxDecoration(
                  color: context.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  _versionString,
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: context.accentPrimaryBright,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tagline in Inter
              Text(
                'Prepare with purpose',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: context.textMuted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
