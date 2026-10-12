import 'package:ascent/features/backup/workspace_backup_screen.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/note_draft_binding.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'quick start survives restart without invented profile or pipeline records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
      );
      expect(
        await container.read(onboardingProvider.notifier).startWithoutSetup(),
        isTrue,
      );
      expect(prefs.getBool('ascent_quick_start_v1'), isTrue);
      expect(await db.userProfileDao.getProfile(), isNull);
      expect(await db.applicationDao.watchAllApplications().first, isEmpty);
      container.dispose();
      await db.close();
    },
  );
  test(
    'note drafts persist Unicode, restore on reopening and clear only after a saved note',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = TextEditingController();
      final binding = NoteDraftBinding(controller, prefs, 'home');
      controller.text = 'A thought\nTea ☕';
      await binding.flush();
      binding.dispose();
      controller.dispose();
      final reopened = TextEditingController();
      final second = NoteDraftBinding(reopened, prefs, 'home');
      expect(reopened.text, 'A thought\nTea ☕');
      reopened.clear();
      await second.flush();
      expect(prefs.getString('ascent_note_draft_home'), '');
      second.dispose();
      reopened.dispose();
    },
  );
  testWidgets('Quick Start reaches daily tools with no profile values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingShell(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Daily tools ready')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AscentTheme.light(),
        ),
      ),
    );
    await tester.tap(find.text('Start now'));
    await tester.pumpAndSettle();
    expect(find.text('Daily tools ready'), findsOneWidget);
    expect(canEnterWorkspace(null, prefs), isTrue);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  testWidgets(
    'onboarding and backup remain scrollable at 2x text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ]) {
        GoogleFonts.plusJakartaSans(fontWeight: weight);
      }
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final dark in [false, true]) {
        for (final child in [
          const OnboardingShell(),
          const WorkspaceBackupScreen(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: child,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
