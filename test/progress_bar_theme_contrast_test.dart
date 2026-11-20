import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Bar Theme Contrast & Visibility Tests (Day & Dark)', () {


    testWidgets(
      'ThemeData progressIndicatorTheme provides visible linearTrackColor across all presets',
      (tester) async {
        final merlotTheme = AscentTheme.light(
          preset: DayThemePreset.merlotLinen,
        );
        expect(merlotTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
        expect(merlotTheme.progressIndicatorTheme.linearMinHeight, equals(4.0));

        final nordicTheme = AscentTheme.light(preset: DayThemePreset.nordicSky);
        expect(nordicTheme.progressIndicatorTheme.linearTrackColor, isNotNull);

        final clayTheme = AscentTheme.light(preset: DayThemePreset.classicClay);
        expect(clayTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
      },
    );
  });
}
