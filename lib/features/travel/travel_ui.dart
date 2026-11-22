import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/brand_palette.dart';
import '../../app/theme/glass_theme.dart';

/// Travel's tint: the calm action blue (Plan pillar).
Color travelTint(BuildContext context) =>
    BrandPalette.pillarTint('travel', dark: context.glass.isDark);

/// "₹1,250" (no paise when whole), "–" for nothing.
String rupees(double? v) {
  if (v == null || v == 0) return '–';
  final whole = (v - v.roundToDouble()).abs() < 0.005;
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(v);
}

IconData visitIcon(String? kind) => switch (kind) {
  'food' => Icons.restaurant_outlined,
  'nature' => Icons.beach_access_outlined,
  'stay' => Icons.hotel_outlined,
  'sight' => Icons.account_balance_outlined,
  'shop' => Icons.shopping_bag_outlined,
  'transit' => Icons.directions_transit_outlined,
  _ => Icons.place_outlined,
};

/// A 30 px tinted tile with the visit's icon (CLAUDE.md §3.3).
class VisitTile extends StatelessWidget {
  const VisitTile({super.key, this.kind, this.size = 30});
  final String? kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = travelTint(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
      ),
      child: Icon(visitIcon(kind), size: size * .58, color: tint),
    );
  }
}
