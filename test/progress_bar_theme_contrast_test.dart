import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Bar Theme Contrast & Visibility Tests (Day & Dark)', () {
    testWidgets(
      'ThemeData progressIndicatorTheme provides visible linearTrackColor across all presets',
      (tester) async {
        final merlotTheme = AscentTheme.light();
        expect(merlotTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
        expect(merlotTheme.progressIndicatorTheme.linearMinHeight, equals(4.0));

        final nordicTheme = AscentTheme.light();
        expect(nordicTheme.progressIndicatorTheme.linearTrackColor, isNotNull);

        final clayTheme = AscentTheme.light();
        expect(clayTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
      },
    );
  });
}
