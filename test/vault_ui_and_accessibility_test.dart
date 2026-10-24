import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/vault/models/vault_item_model.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/widgets/vault_home_preview.dart';
import 'package:ascent/features/vault/widgets/vault_lock_view.dart';
import 'package:ascent/features/vault/widgets/vault_item_card.dart';
import 'package:ascent/features/vault/vault_screen.dart';

Widget _buildTestApp({
  required Widget child,
  double width = 360,
  double height = 800,
  TextScaler textScaler = TextScaler.noScaling,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...overrides.cast(),
    ],
    child: MaterialApp(
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
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ascent_vault_master_pin_hash_v1': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'ascent_vault_master_pin_salt_v1': 'testsalt12345678',
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('Vault UI & Accessibility Tests', () {
    testWidgets('VaultHomePreview complies with Rule 18 heading styling', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            vaultItemCountProvider.overrideWith((ref) => 3),
          ],
          child: const VaultHomePreview(),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.text('Vault');
      expect(titleFinder, findsOneWidget);

      final Text titleWidget = tester.widget(titleFinder);
      expect(titleWidget.style?.fontSize, equals(20));
      expect(titleWidget.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets('VaultHomePreview is immune to overflow at 320px with 2.0x text scale (Rule 13)', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          _buildTestApp(
            width: 320,
            height: 600,
            textScaler: const TextScaler.linear(2.0),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              vaultItemCountProvider.overrideWith((ref) => 12),
            ],
            child: const SingleChildScrollView(
              child: VaultHomePreview(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Vault'), findsOneWidget);
        expect(find.text('Encrypted & Locked'), findsOneWidget);

        final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'Found RenderFlex overflow at 320px 2.0x scale: $overflowErrors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('VaultLockView renders keypad and accepts PIN input', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const VaultLockView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Ascent Vault is Locked'), findsOneWidget);
      expect(find.text('Enter your Master PIN or use Biometrics'), findsOneWidget);

      // Verify keypad digits 0-9
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Tap 1, 2, 3
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();

      // Tap backspace
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // Enter remaining to reach 4 digits
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('VaultLockView 320px width at 2.0x scale has zero overflow (Rule 13)', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          _buildTestApp(
            width: 320,
            height: 700,
            textScaler: const TextScaler.linear(2.0),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: const SingleChildScrollView(
              child: VaultLockView(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: 'RenderFlex overflow in VaultLockView: $overflowErrors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('VaultItemCard displays virtual card and ID styling', (tester) async {
      final cardItem = VaultItem(
        id: 1,
        title: 'HDFC Regalia Gold',
        subtitle: 'Visa · **** 4242',
        category: VaultCategory.card,
        fields: {
          'cardholderName': 'ARUN VISEN',
          'cardNumber': '4111424242424242',
          'expiry': '12/28',
          'cardBrand': 'Visa',
        },
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: VaultItemCard(
            item: cardItem,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HDFC Regalia Gold'), findsOneWidget);
      expect(find.text('ARUN VISEN'), findsOneWidget);
      expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
      expect(find.text('EXP: 12/28'), findsOneWidget);

      // Tap reveal eye icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now revealed with spaced 4-digit formatting
      expect(find.text('4111 4242 4242 4242'), findsOneWidget);
    });

    testWidgets('VaultScreen displays locked view when session is locked', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            vaultSessionUnlockedProvider.overrideWith(
              VaultSessionUnlockedNotifier.new,
            ),
          ],
          child: const VaultScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ascent Vault'), findsOneWidget);
      expect(find.byType(VaultLockView), findsOneWidget);
    });
  });
}
