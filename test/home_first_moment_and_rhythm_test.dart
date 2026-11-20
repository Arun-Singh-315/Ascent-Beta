import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_first_moment.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ascent_first_moment_pending_v1': true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomeTheme.from(
            dark ? AscentTheme.dark() : AscentTheme.light(),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
  }

  for (final thought in [false, true]) {
    testWidgets(
      'First ${thought ? 'thought' : 'task'} captures exactly one real record',
      (tester) async {
        await tester.pumpWidget(app(const HomeFirstMoment()));
        await settle(tester);
        expect(container.read(firstMomentPendingProvider), isTrue);
        expect(
          await tester.runAsync(() => db.select(db.taskTable).get()),
          isEmpty,
        );
        expect(
          await tester.runAsync(() => db.thoughtDao.watchAllThoughts().first),
          isEmpty,
        );
        if (thought) {
          await tester.tap(find.text('Thought'));
          await tester.pump();
        }
        await tester.enterText(
          find.byKey(const ValueKey('first_moment_input')),
          'Make room for a walk',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('first_moment_send')));
        await settle(tester);
        expect(container.read(firstMomentPendingProvider), isFalse);
        final tasks = await tester.runAsync(
          () => db.select(db.taskTable).get(),
        );
        final notes = await tester.runAsync(
          () => db.thoughtDao.watchAllThoughts().first,
        );
        expect(tasks!.length, thought ? 0 : 1);
        expect(notes!.length, thought ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Explore first saves no sample records', (tester) async {
    await tester.pumpWidget(app(const HomeFirstMoment()));
    await settle(tester);
    await tester.tap(find.text('Explore first'));
    await settle(tester);
    expect(container.read(firstMomentPendingProvider), isFalse);
    expect(await tester.runAsync(() => db.select(db.taskTable).get()), isEmpty);
    expect(
      await tester.runAsync(() => db.thoughtDao.watchAllThoughts().first),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
