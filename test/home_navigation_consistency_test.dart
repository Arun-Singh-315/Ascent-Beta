import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
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
                for (final path in ['home', 'things', 'ai-assistant', 'thought-wall', 'you'])
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
        final context = tester.element(find.byType(MainScaffold));
        final active = context.glass.actionInk;
        final inactive = context.glass.inkMuted;
        const ids = ['home', 'things', 'assistant', 'mind', 'you'];
        for (final id in ids) {
          await tester.tap(find.byKey(ValueKey('tab_$id')));
          await tester.pumpAndSettle();
          for (final other in ids) {
            final icon = tester.widget<Icon>(
              find.descendant(
                of: find.byKey(ValueKey('tab_$other')),
                matching: find.byType(Icon),
              ),
            );
            expect(icon.color, other == id ? active : inactive, reason: other);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
