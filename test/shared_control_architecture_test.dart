import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Screens use shared switches and segmented controls', () {
    final rawSwitch = RegExp(
      r'\b(?:Switch(?:\.adaptive)?|CupertinoSwitch)\s*\(',
    );
    final rawSegments = RegExp(
      r'\b(?:SegmentedButton|CupertinoSlidingSegmentedControl|CupertinoSegmentedControl)(?:<[^>]+>)?\s*\(',
    );
    final violations = <String>[];
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if ((!file.path.endsWith('ascent_switch.dart') &&
              rawSwitch.hasMatch(source)) ||
          rawSegments.hasMatch(source)) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use AscentSwitch/AscentSwitchRow and AscentSegmentedControl.',
    );
  });
}
