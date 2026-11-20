import 'package:flutter/material.dart';

/// Mindspace surface colours: the board backdrops and the soft paper fill of
/// thought cards. Literals live here, not in feature code (CLAUDE.md §2.1).
abstract final class MindspacePalette {
  // Board backdrops, as [top-left, bottom-right] gradient stops.
  static const skyLight = [Color(0xFFE8EEF5), Color(0xFFDFE7F0)];
  static const skyDark = [Color(0xFF10141D), Color(0xFF151B26)];
  static const plainLight = [Color(0xFFEFECE6), Color(0xFFE5E1D8)];
  static const paperLight = [Color(0xFFEFECE6), Color(0xFFE6E2D9)];
  static const paperDark = [Color(0xFF161920), Color(0xFF0F1218)];
  static const duskLight = [Color(0xFFE8E5DF), Color(0xFFDDD8CE)];
  static const duskDark = [Color(0xFF1E222B), Color(0xFF171A21)];

  /// Dot grid on the paper backdrop.
  static Color paperDots(bool dark) =>
      (dark ? Colors.white : Colors.black).withValues(alpha: .045);

  /// Thought card paper fill.
  static const cardPaperLight = Color(0xFFF7F5F0);
  static const cardPaperDark = Color(0xFF16181F);

  /// Soft card shadow in light mode (§3.3: black at a few percent).
  static Color cardShadowLight([double alpha = .04]) =>
      Colors.black.withValues(alpha: alpha);
}
