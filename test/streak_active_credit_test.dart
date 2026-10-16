import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent Learning and Study Focus credit each real second once',
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
      final notifier = container.read(studyStreakProvider.notifier);
      final base = container.read(studyStreakProvider).todaySeconds;
      final at = DateTime.now();
      notifier.creditActiveSecond(at);
      notifier.creditActiveSecond(at);
      expect(container.read(studyStreakProvider).todaySeconds, base + 1);
      notifier.creditActiveSecond(at.add(const Duration(seconds: 1)));
      expect(container.read(studyStreakProvider).todaySeconds, base + 2);
      container.dispose();
      await db.close();
    },
  );
}
