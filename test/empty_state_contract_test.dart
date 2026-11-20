import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme, double scale = 1.0}) =>
    MaterialApp(
      theme: theme ?? AscentTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
    'Full empty state shows one primary action and at most three starters',
    (tester) async {
      var actions = 0;
      final tapped = <String>[];
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Your day is wide open',
            subtitle: 'Add one thing you want to get done today.',
            actionLabel: 'Add your first thing',
            onAction: () => actions++,
            starters: [
              for (final s in ['A', 'B', 'C', 'D'])
                EmptyStarter(label: s, onTap: () => tapped.add(s)),
            ],
          ),
        ),
      );

      expect(find.text('Your day is wide open'), findsOneWidget);
      await tester.tap(find.text('Add your first thing'));
      expect(actions, 1);

      expect(find.text('D'), findsNothing, reason: 'starters are capped at 3');
      await tester.tap(find.text('B'));
      expect(tapped, ['B']);
    },
  );

  testWidgets('Inline empty state is a single row with a text action', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      _host(
        EmptyState.inline(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Nothing captured yet',
          actionLabel: 'Add',
          onAction: () => actions++,
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    expect(actions, 1);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'No overflow at 320 px and 2.0x text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await tester.pumpWidget(
          _host(
            EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Your day is wide open',
              subtitle:
                  'Add one thing you want to get done today. You can add a time or reminder whenever you like.',
              actionLabel: 'Add your first thing',
              onAction: () {},
              starters: [
                EmptyStarter(label: 'Drink a glass of water', onTap: () {}),
                EmptyStarter(label: 'Read for 20 minutes', onTap: () {}),
              ],
            ),
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            scale: 2.0,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
