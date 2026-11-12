import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/shared_control_tokens.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/main_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final dark in [false, true]) {
    testWidgets(
      'Every navigation branch keeps its selection style: dark=$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) => MainScaffold(shell: shell),
              branches: [
                for (final path in ['home', 'reminders', 'vault', 'more'])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/$path',
                        builder: (_, _) =>
                            Scaffold(body: Text('$path content')),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp.router(
              routerConfig: router,
              theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final blue = dark
            ? SharedControlColors.actionBlueDark
            : SharedControlColors.actionBlue;
        for (final icon in [
          Icons.home_rounded,
          Icons.notifications_rounded,
          Icons.lock_rounded,
          Icons.widgets_rounded,
        ]) {
          final target = find.byIcon(icon);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.widget<Icon>(target).color, blue);
          final selectedTile = find
              .ancestor(of: target, matching: find.byType(AnimatedContainer))
              .first;
          final decoration =
              tester.widget<AnimatedContainer>(selectedTile).decoration!
                  as BoxDecoration;
          expect(decoration.color, blue.withValues(alpha: dark ? .18 : .09));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
