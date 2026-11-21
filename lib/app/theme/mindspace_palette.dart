import 'package:flutter/material.dart';

/// Mindspace colours: the soft thought hues and card fills. The board itself
/// uses the plain app canvas. Literals live here, not in feature code (CLAUDE.md §2.1).
abstract final class MindspacePalette {
  /// Thought hues (blue, violet, rose, teal, amber, sage): soft pastels for
  /// light mode, quiet jewel tones for dark. Used for the card tint, mood
  /// glyph and space dot, so each space keeps one colour.
  static const _huesLight = [
    Color(0xFF4F7BC9),
    Color(0xFF8063C4),
    Color(0xFFC0607F),
    Color(0xFF2F8F8A),
    Color(0xFFB7792A),
    Color(0xFF4E8F5C),
  ];
  static const _huesDark = [
    Color(0xFF8EB1EC),
    Color(0xFFB59CF0),
    Color(0xFFEB9AB6),
    Color(0xFF6CCBC3),
    Color(0xFFE2B26A),
    Color(0xFF8DCB98),
  ];
  static int get hueCount => _huesLight.length;
  static Color hue(int index, {required bool dark}) =>
      (dark ? _huesDark : _huesLight)[index % _huesLight.length];

  /// Named hues for moods.
  static Color blue(bool dark) => hue(0, dark: dark);
  static Color violet(bool dark) => hue(1, dark: dark);
  static Color rose(bool dark) => hue(2, dark: dark);
  static Color amber(bool dark) => hue(4, dark: dark);
  static Color sage(bool dark) => hue(5, dark: dark);

  /// Bubble fill: the hue washed softly into the card surface.
  static Color bubbleFill(Color hue, Color surface, {required bool dark}) =>
      Color.alphaBlend(hue.withValues(alpha: dark ? .08 : .06), surface);

  /// Thought card paper fill.
  static const cardPaperLight = Color(0xFFF7F5F0);
  static const cardPaperDark = Color(0xFF16181F);

  /// Soft card shadow in light mode (§3.3: black at a few percent).
  static Color cardShadowLight([double alpha = .04]) =>
      Colors.black.withValues(alpha: alpha);

  /// Home Mind preview: composer and card fills, warm and cool presets.
  static const previewFillWarm = Color(0xFFFFFDFB);
  static const previewFillCool = Color(0xFFFBFDFF);
  static const previewCardCool = Color(0xFFF8FAFD);
  static const previewShadowWarm = Color(0xFF5C4A3E);

  /// Mindspace accent (header arrow, small highlights).
  static const accent = Color(0xFF7C5CB7);

  /// Ink for highlighted to-do lines inside a thought.
  static Color highlightInk(bool dark) =>
      dark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
}
