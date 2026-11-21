import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/widgets/home_plans_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });


  testWidgets(
    'HomePlansPreview displays unified glass empty state when plans are empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            planCollectionsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePlansPreview()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Recurring Plans Yet'), findsOneWidget);
      expect(
        find.text(
          'Design routines, weekly rhythms, and habits that organize your days automatically.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create a plan'), findsOneWidget);
    },
  );


}
