import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/vault/widgets/cred_card_visual.dart';

Widget _buildCardTestApp({
  required Widget child,
  double width = 360,
  double height = 800,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: AscentTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: textScaler,
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CRED-Style Luxury Card Visual Tests', () {
    test('CredCardTheme resolves accurately from bank/card names', () {
      expect(CredCardTheme.resolve('HDFC Infinia Metal'), equals(CredCardSkin.obsidian));
      expect(CredCardTheme.resolve('ICICI Sapphiro'), equals(CredCardSkin.sapphire));
      expect(CredCardTheme.resolve('Axis Magnus'), equals(CredCardSkin.burgundy));
      expect(CredCardTheme.resolve('SBI Aurum'), equals(CredCardSkin.aurum));
      expect(CredCardTheme.resolve('American Express Emerald'), equals(CredCardSkin.emerald));
      expect(CredCardTheme.resolve('OneCard Metal'), equals(CredCardSkin.titanium));
      expect(CredCardTheme.resolve('Unknown Generic Bank'), equals(CredCardSkin.obsidian));
    });

    testWidgets('CredCardVisual renders luxury card with EMV chip, details and brand badge', (tester) async {
      await tester.pumpWidget(
        _buildCardTestApp(
          child: const CredCardVisual(
            bankName: 'HDFC Bank',
            cardTier: 'Regalia Gold',
            cardholderName: 'ARUN VISEN',
            cardNumber: '4111424242424242',
            expiryDate: '12/28',
            cardBrand: 'Visa',
            skin: CredCardSkin.obsidian,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('Regalia Gold'), findsOneWidget);
      expect(find.text('ARUN VISEN'), findsOneWidget);
      expect(find.text('EXP: 12/28'), findsOneWidget);
      expect(find.text('•••• •••• •••• 4242'), findsOneWidget);

      // Verify EMV Chip exists
      expect(find.byType(EmvChipWidget), findsOneWidget);
    });

    testWidgets('CredCardVisual toggles card number reveal and mask', (tester) async {
      await tester.pumpWidget(
        _buildCardTestApp(
          child: const CredCardVisual(
            bankName: 'Axis Bank',
            cardTier: 'Magnus',
            cardholderName: 'ARUN VISEN',
            cardNumber: '5242424242424242',
            expiryDate: '09/29',
            cardBrand: 'Mastercard',
            skin: CredCardSkin.burgundy,
            showActions: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('•••• •••• •••• 4242'), findsOneWidget);

      // Tap reveal eye button
      final eyeFinder = find.byIcon(Icons.visibility_outlined);
      expect(eyeFinder, findsOneWidget);
      await tester.tap(eyeFinder);
      await tester.pumpAndSettle();

      // Now revealed with spaced 4-digit formatting
      expect(find.text('5242 4242 4242 4242'), findsOneWidget);
    });

    testWidgets('CredCardVisual is immune to overflow at 320px with 2.0x text scale (Rule 13)', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          _buildCardTestApp(
            width: 320,
            height: 600,
            textScaler: const TextScaler.linear(2.0),
            child: const CredCardVisual(
              bankName: 'Standard Chartered Bank Emirates World Elite',
              cardTier: 'Super Premium Platinum',
              cardholderName: 'PROF. ARUN SINGH VISEN LONGNAME',
              cardNumber: '4111424242424242',
              expiryDate: '12/30',
              cardBrand: 'Visa',
              skin: CredCardSkin.sapphire,
              showActions: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'RenderFlex overflow in CredCardVisual: $overflowErrors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });
}
