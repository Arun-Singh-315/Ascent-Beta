import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../core/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../app/theme/color_tokens.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_logo.dart';

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
  String _versionString = 'v1.0.2';

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

    bool hasValidProfile = false;
    try {
      final profileDao = ref.read(userProfileDaoProvider);
      final profile = await profileDao.getProfile();
      hasValidProfile = canEnterWorkspace(
        profile,
        ref.read(sharedPreferencesProvider),
      );
    } catch (_) {
      hasValidProfile = false;
    }

    if (!hasValidProfile) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('ascent_onboarding_complete', false);
      ref.invalidate(onboardingCompleteProvider);
    }

    final elapsed = DateTime.now().difference(startTime);
    final remainingWait = const Duration(milliseconds: 1400) - elapsed;
    if (remainingWait > Duration.zero) {
      await Future.delayed(remainingWait);
    }

    if (!mounted) return;

    final router = GoRouter.maybeOf(context);
    if (router == null) return;

    if (hasValidProfile) {
      router.go(NotificationService.consumePendingDestination() ?? '/home');
    } else {
      router.go('/onboarding');
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
              // Official Ascent Logo Mark
              const AscentLogo(size: 84),
              const SizedBox(height: 24),

              // Title
              Text(
                'Ascent',
                style: AscentTextStyles.displayLarge
                    .copyWith(color: textPrimary, letterSpacing: -0.5)
                    .merge(AppTypeRoles.typeRole25),
              ),
              const SizedBox(height: 6),

              // Subtitle Tagline
              Text(
                'Personal Clarity, Focus & Rhythm',
                style: AscentTextStyles.bodyMedium
                    .copyWith(color: textMuted)
                    .merge(AppTypeRoles.typeRole26),
              ),
              const SizedBox(height: 14),

              // Subtle version badge
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s10,
                  vertical: AppSpace.s3,
                ),
                nightDecoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  borderRadius: AppGeometry.roundedr20,
                  border: Border.all(
                    color: divider,
                    width: AppBorderScale.w0point8,
                  ),
                ),
                child: Text(
                  'BETA · $_versionString',
                  style: AscentTextStyles.monoCode
                      .copyWith(color: textMuted)
                      .merge(AppTypeRoles.typeRole16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
