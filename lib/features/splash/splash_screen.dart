import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/database_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  String _versionString = 'v1.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
    _checkSessionAndNavigate();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _versionString = 'v${packageInfo.version}';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkSessionAndNavigate() async {
    final startTime = DateTime.now();

    final hasCompletedOnboardingPref = ref.read(onboardingCompleteProvider);
    bool hasProfile = false;
    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final profile = await profileDao.getProfile();
      if (profile != null && profile.onboardingComplete) {
        hasProfile = true;
      }
    } catch (_) {
      hasProfile = hasCompletedOnboardingPref;
    }

    final isAuth = ref.read(authProvider).isAuthenticated;

    final elapsed = DateTime.now().difference(startTime);
    final remainingWait = const Duration(milliseconds: 1100) - elapsed;
    if (remainingWait > Duration.zero) {
      await Future.delayed(remainingWait);
    }

    if (!mounted) return;

    if (!isAuth) {
      context.go('/login');
    } else if (hasCompletedOnboardingPref || hasProfile) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final accentPrimary = context.accentPrimary;
    final divider = context.divider;

    return Scaffold(
      backgroundColor: context.bgBase,
      body: Center(
        child: AnimatedBuilder(
          animation: _animController,
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
              // Geometric Minimalist Logo Mark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.bgSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: divider, width: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: context.isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : accentPrimary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 42,
                    color: accentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Ascent',
                style: AscentTextStyles.displayLarge.copyWith(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle Tagline
              Text(
                'Job Prep & Search Operating System',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),

              // Subtle version badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: divider, width: 0.8),
                ),
                child: Text(
                  'BETA · $_versionString',
                  style: AscentTextStyles.monoCode.copyWith(
                    fontSize: 11,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
