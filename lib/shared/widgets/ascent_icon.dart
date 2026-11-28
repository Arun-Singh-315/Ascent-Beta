import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/ascent_tokens.dart';

/// Ascent's own duotone icon set (Home v7): rounded 1.6 pt lines with a soft
/// tinted fill inside. Drawn on a 24 × 24 grid.
enum AscentGlyph {
  home,
  things,
  riya,
  mind,
  you,
  water,
  medicine,
  focus,
  money,
  promise,
  walk,
  life,
  chevron,
  plus,
  mic,
  send,
  check,
  moon,
  sun,
}

const _paths = <AscentGlyph, String>{
  AscentGlyph.home:
      '<path d="M4.5 10.3 12 4l7.5 6.3V19a1 1 0 0 1-1 1h-4v-5.5h-5V20h-4a1 1 0 0 1-1-1z" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>',
  AscentGlyph.things:
      '<rect x="4" y="4" width="16" height="16" rx="5" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6"/><path d="m8.5 12.2 2.4 2.3 4.6-5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.riya:
      '<path d="M12 3.5c.6 3.9 2.6 5.9 6.5 6.5-3.9.6-5.9 2.6-6.5 6.5-.6-3.9-2.6-5.9-6.5-6.5 3.9-.6 5.9-2.6 6.5-6.5z" fill="currentColor"/><circle cx="18.5" cy="17.5" r="1.6" fill="currentColor"/>',
  AscentGlyph.mind:
      '<path d="M5 6.5A2.5 2.5 0 0 1 7.5 4h9A2.5 2.5 0 0 1 19 6.5v7a2.5 2.5 0 0 1-2.5 2.5H11l-4 3.5V16A2 2 0 0 1 5 14z" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M8.5 9h7M8.5 12h4.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  AscentGlyph.you:
      '<circle cx="12" cy="8.5" r="3.8" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6"/><path d="M5 20c.8-3.6 3.6-5.3 7-5.3s6.2 1.7 7 5.3" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  AscentGlyph.water:
      '<path d="M12 3.5s5.5 6 5.5 10.2a5.5 5.5 0 0 1-11 0C6.5 9.5 12 3.5 12 3.5z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M9.3 14.2a2.8 2.8 0 0 0 2.6 2.6" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  AscentGlyph.medicine:
      '<rect x="3.5" y="8.5" width="17" height="7" rx="3.5" transform="rotate(-40 12 12)" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.6"/><path d="m9.6 9.2 4.8 5.6" stroke="currentColor" stroke-width="1.6"/>',
  AscentGlyph.focus:
      '<circle cx="12" cy="13" r="7.5" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6"/><path d="M12 9.5V13l2.3 1.6M10 3.5h4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  AscentGlyph.money:
      '<rect x="3.5" y="6.5" width="17" height="12" rx="3" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6"/><path d="M3.5 10h17" stroke="currentColor" stroke-width="1.6"/><circle cx="16.5" cy="14.3" r="1.3" fill="currentColor"/>',
  AscentGlyph.promise:
      '<path d="M12 3.8 14 6l3-.2.4 3 2.4 1.9-1.4 2.7.7 3-2.9.9-1.3 2.7-2.9-1.1-2.9 1.1-1.3-2.7-2.9-.9.7-3L4.2 10.7l2.4-1.9.4-3 3 .2z" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="m9.3 12.2 1.9 1.9 3.6-3.8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.walk:
      '<path d="M8.5 15.5c-1.6 0-2.5-1.8-2.5-4.2S7 6.5 8.7 6.5s2.3 2.3 2.1 4.6c-.2 2.5-.8 4.4-2.3 4.4zM15.5 19.5c-1.5 0-2.3-1.9-2.1-4.4.2-2.3.8-4.6 2.4-4.6S18 12.8 18 15.2s-.9 4.3-2.5 4.3z" fill="currentColor" fill-opacity=".16" stroke="currentColor" stroke-width="1.5"/>',
  AscentGlyph.life:
      '<path d="M12 19.5s-7-4.3-7-9.6A3.9 3.9 0 0 1 12 7.6a3.9 3.9 0 0 1 7 2.3c0 5.3-7 9.6-7 9.6z" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M7.5 12.5h2.3l1.2-2 1.8 4 1.2-2h2.5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.chevron:
      '<path d="m9 6 6 6-6 6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.plus:
      '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  AscentGlyph.mic:
      '<rect x="9" y="3" width="6" height="11" rx="3" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.7"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  AscentGlyph.send:
      '<path d="M5 12h13M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.check:
      '<path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
  AscentGlyph.moon:
      '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
  AscentGlyph.sun:
      '<circle cx="12" cy="12" r="4" fill="currentColor" fill-opacity=".14" stroke="currentColor" stroke-width="1.7"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
};

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// One icon from Ascent's set, tinted with [color] (defaults to the
/// surrounding [IconTheme] colour). Give icon-only controls a [semanticLabel].
class AscentIcon extends StatelessWidget {
  const AscentIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final AscentGlyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  /// The SVG source for [glyph] in [color] (exposed for tests).
  static String svgFor(AscentGlyph glyph, Color color) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '${_paths[glyph]!.replaceAll('currentColor', _hex(color))}</svg>';

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? context.tokens.label;
    final picture = SvgPicture.string(
      svgFor(glyph, c),
      width: size,
      height: size,
      excludeFromSemantics: semanticLabel == null,
      semanticsLabel: semanticLabel,
    );
    // Duotone fills use opacity, so the colour's own alpha applies on top.
    return c.a < 1 ? Opacity(opacity: c.a, child: picture) : picture;
  }
}
