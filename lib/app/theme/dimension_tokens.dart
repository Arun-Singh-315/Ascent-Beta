import 'package:flutter/material.dart';

/// Centralized dimension tokens for the Ascent design system.
///
/// Ensures consistent spacing, corner radii, and component dimensions across
/// all screens, dialogs, bottom sheets, and cards.
class AscentDimensions {
  AscentDimensions._();

  // ── Spacing Scale ──────────────────────────────────────────────────────────
  /// 2 px — Sub-spacing
  static const double spaceXxs = 2.0;

  /// 4 px — Micro spacing between icon and text, tag padding.
  static const double spaceXs = 4.0;

  /// 8 px — Compact spacing, chip gaps, icon button margins.
  static const double spaceSm = 8.0;

  /// 12 px — Medium spacing, inner card element gaps.
  static const double spaceMd = 12.0;

  /// 16 px — Standard padding for cards, lists, screen horizontal padding.
  static const double spaceLg = 16.0;

  /// 20 px — Generous padding for dialogs and modal interiors.
  static const double spaceXl = 20.0;

  /// 24 px — Major section separation, bottom sheet content padding.
  static const double spaceXxl = 24.0;

  /// 32 px — Dashboard level separation.
  static const double spaceSection = 32.0;

  // ── Corner Radii ───────────────────────────────────────────────────────────
  /// 4 px — Sub-pixel badges.
  static const double radiusXs = 4.0;

  /// 8 px — Micro chips, sub-cards, tags.
  static const double radiusSm = 8.0;

  /// 12 px — Buttons, inputs, small cards.
  static const double radiusMd = 12.0;

  /// 16 px — Standard surface cards (`AscentCard`), list items.
  static const double radiusLg = 16.0;

  /// 20 px — Dialogs (`AscentDialog`), elevated containers.
  static const double radiusXl = 20.0;

  /// 24 px — Modal bottom sheets and `GlassSurface`.
  static const double radiusXxl = 24.0;

  /// 999 px — Pills, circular action buttons, search bars.
  static const double radiusFull = 999.0;

  // ── Component Dimensions ───────────────────────────────────────────────────
  /// 36 px — Compact button height.
  static const double buttonHeightCompact = 36.0;

  /// 44 px — Standard button height (recommended touch target).
  static const double buttonHeightStandard = 44.0;

  /// 52 px — Hero / primary CTA button height.
  static const double buttonHeightLarge = 52.0;

  /// 46 px — Standard single-line text input height.
  static const double inputHeight = 46.0;

  /// 56 px — Bottom navigation bar height.
  static const double bottomNavHeight = 56.0;

  /// 48 dp — Minimum accessible tap target dimension.
  static const double minTouchTarget = 48.0;
}

/// Convenience aliases for spacing tokens.
class AscentSpacing {
  AscentSpacing._();

  static const double xxs = AscentDimensions.spaceXxs;
  static const double xs = AscentDimensions.spaceXs;
  static const double sm = AscentDimensions.spaceSm;
  static const double md = AscentDimensions.spaceMd;
  static const double lg = AscentDimensions.spaceLg;
  static const double xl = AscentDimensions.spaceXl;
  static const double xxl = AscentDimensions.spaceXxl;
  static const double section = AscentDimensions.spaceSection;
}

/// Convenience extensions on [Radius] and [BorderRadius].
class AscentRadii {
  AscentRadii._();

  static const double xsVal = AscentDimensions.radiusXs;
  static const double smVal = AscentDimensions.radiusSm;
  static const double mdVal = AscentDimensions.radiusMd;
  static const double lgVal = AscentDimensions.radiusLg;
  static const double xlVal = AscentDimensions.radiusXl;
  static const double xxlVal = AscentDimensions.radiusXxl;
  static const double fullVal = AscentDimensions.radiusFull;

  static const Radius xs = Radius.circular(AscentDimensions.radiusXs);
  static const Radius sm = Radius.circular(AscentDimensions.radiusSm);
  static const Radius md = Radius.circular(AscentDimensions.radiusMd);
  static const Radius lg = Radius.circular(AscentDimensions.radiusLg);
  static const Radius xl = Radius.circular(AscentDimensions.radiusXl);
  static const Radius xxl = Radius.circular(AscentDimensions.radiusXxl);
  static const Radius full = Radius.circular(AscentDimensions.radiusFull);

  static const BorderRadius borderSm = BorderRadius.all(sm);
  static const BorderRadius borderMd = BorderRadius.all(md);
  static const BorderRadius borderLg = BorderRadius.all(lg);
  static const BorderRadius borderXl = BorderRadius.all(xl);
  static const BorderRadius borderXxl = BorderRadius.all(xxl);
  static const BorderRadius borderFull = BorderRadius.all(full);
  static const BorderRadius sheetTop = BorderRadius.vertical(top: xxl);
}
