import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  group('HomeShortcutPanel Legend Border Tests', () {
    testWidgets('Renders name on top border line without nested card-over-card', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(
            shortcuts: ['today', 'learning', 'thought-wall', 'vault'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enclosure has panel key
      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);

      // Section title is embedded directly on the border line
      expect(find.byKey(const ValueKey('shortcut_legend_title')), findsOneWidget);
      expect(find.text('QUICK ACTIONS'), findsOneWidget);

      // Contains shortcut items
      expect(find.byKey(const ValueKey('shortcut_today')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortcut_learning')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortcut_thought-wall')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortcut_vault')), findsOneWidget);
    });
  });
}
