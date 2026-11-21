import 'package:flutter/material.dart';

/// Brand colours used outside the role tokens: the assistant gradient
/// (CLAUDE.md §3.1) and the swatches that preview each day theme.
abstract final class BrandPalette {
  static const assistantIndigo = Color(0xFF5E5CE6);
  static const assistantViolet = Color(0xFFBF5AF2);
  static const assistantPink = Color(0xFFFF6482);

  static const merlotSwatch = [Color(0xFF7A2E3B), Color(0xFFF4EDE4)];
  static const claySwatch = [Color(0xFFA4523A), Color(0xFFF7F1EA)];
  static const skySwatch = [Color(0xFF2F6FED), Color(0xFFEFF4FB)];
}
