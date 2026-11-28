import 'package:ascent/app/theme/home_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final design in [const HomeDesign.day(), const HomeDesign.night()]) {
    test(
      'Home reading and accent roles meet AA at darkness ${design.darkness}',
      () {
        for (final background in [
          design.canvas,
          design.surface,
          design.elevated,
          design.mindTint,
          design.workTint,
          design.wellnessTint,
          design.wellnessEnd,
        ]) {
          expect(
            contrast(design.primaryText, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(design.secondaryText, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(design.wellnessInk, design.wellnessTint),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(design.learningInk, design.learningTint),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(design.action, design.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
