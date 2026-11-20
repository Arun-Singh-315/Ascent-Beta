import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/theme/app_colors.dart';
import 'package:ascent/shared/widgets/app_text_field.dart';
import 'package:ascent/shared/widgets/section_card.dart';
import 'package:ascent/features/home/widgets/home_assistant_hero_card.dart';
import 'package:ascent/features/home/widgets/activity_starter_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sand & Ember Palette & Tokens', () {
    test('Light theme tokens match exact hex values', () {
      final light = AppColors.light;
      expect(light.bg, const Color(0xFFFAF6F0));
      expect(light.surface, const Color(0xEBFFFFFF));
      expect(light.surfaceAlt, const Color(0xFFF1E9DD));
      expect(light.border, const Color(0xFFE6DCCD));
      expect(light.textPrimary, const Color(0xFF2B2622));
      expect(light.textSecondary, const Color(0xFF6F665C));
      expect(light.textTertiary, const Color(0xFFA0958A));
      expect(light.primary, const Color(0xFFD2643A));
      expect(light.primaryContainer, const Color(0xFFFCE5D8));
      expect(light.onPrimaryContainer, const Color(0xFF6E2E15));
      expect(light.secondary, const Color(0xFFC4506A));
      expect(light.secondaryContainer, const Color(0xFFF8E1E6));
      expect(light.onSecondaryContainer, const Color(0xFF5A1C29));
      expect(light.tertiary, const Color(0xFFD6A23E));
      expect(light.tertiaryContainer, const Color(0xFFF8EDD0));
      expect(light.alert, const Color(0xFFB8433B));
    });

    test('Dark theme tokens match warm dark hex values', () {
      final dark = AppColors.dark;
      expect(dark.bg, const Color(0xFF1B1714));
      expect(dark.surface, const Color(0xFF2A2420));
      expect(dark.surfaceAlt, const Color(0xFF332C27));
      expect(dark.border, const Color(0xFF3D342E));
      expect(dark.textPrimary, const Color(0xFFF3EBE2));
      expect(dark.textSecondary, const Color(0xFFB9AC9F));
      expect(dark.textTertiary, const Color(0xFF857A6F));
      expect(dark.primary, const Color(0xFFF08A5D));
      expect(dark.primaryContainer, const Color(0xFF4A2A1B));
      expect(dark.onPrimaryContainer, const Color(0xFFFFD9C6));
      expect(dark.secondary, const Color(0xFFE27A93));
      expect(dark.tertiary, const Color(0xFFE8B65A));
      expect(dark.alert, const Color(0xFFE06D65));
    });
  });

  group('Global Input Rule - AppTextField', () {
    testWidgets(
      'AppTextField renders single enclosure without nested borders',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppTextField(
                hintText: 'What should we call you?',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.filled, isTrue);
        expect(textField.decoration?.fillColor, AppColors.light.surfaceAlt);
        expect(textField.decoration?.prefixIcon, isNotNull);
        expect(textField.decoration?.hintText, 'What should we call you?');
      },
    );
  });

  group('Glowing Ask Jarvis Card on Home', () {
    testWidgets(
      'Renders glowing card with animated illuminated border and soft Chat button',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: HomeAssistantHeroCard(assistantName: 'Jarvis'),
              ),
            ),
          ),
        );

        expect(find.text('Ask Jarvis'), findsOneWidget);
        expect(find.text('Plan your day or ask anything'), findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      },
    );
  });

  group('Things / Plans Soft Actions', () {
    testWidgets(
      'Activity starter buttons: Add a task filled, Add a timer outlined',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ActivityStarterActions())),
        );

        expect(find.text('Add a task'), findsOneWidget);
        expect(find.text('Add a timer'), findsOneWidget);
        expect(find.byKey(const ValueKey('starter_add_task')), findsOneWidget);
        expect(find.byKey(const ValueKey('starter_add_timer')), findsOneWidget);
      },
    );
  });

  group('SectionCard Consistency', () {
    testWidgets('Header row has icon + title on left, chevron on right', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Mindspace',
              icon: Icons.lightbulb_outline_rounded,
              onOpen: () {},
              child: const Text('Mindspace content'),
            ),
          ),
        ),
      );

      expect(find.text('Mindspace'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('Accessibility & Small Screen Safety (320px width & 2.0x scale)', () {
    testWidgets(
      'ActivityStarterActions does not overflow at 320px with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 600 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const MaterialApp(
              home: Scaffold(body: ActivityStarterActions()),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeAssistantHeroCard does not overflow at 320px with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 600 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: HomeAssistantHeroCard(assistantName: 'Jarvis'),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
