import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';

enum BoardBackdrop { sky, paper, dusk, plain }

final boardBackdropProvider =
    NotifierProvider<BoardBackdropNotifier, BoardBackdrop>(
      BoardBackdropNotifier.new,
    );

class BoardBackdropNotifier extends Notifier<BoardBackdrop> {
  @override
  BoardBackdrop build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString('thought_board_backdrop_v1');
    return BoardBackdrop.values.where((v) => v.name == raw).firstOrNull ??
        BoardBackdrop.sky;
  }

  Future<void> set(BoardBackdrop value) async {
    if (!await ref
        .read(sharedPreferencesProvider)
        .setString('thought_board_backdrop_v1', value.name)) {
      throw StateError('Could not save background');
    }
    if (ref.mounted) state = value;
  }
}

class BoardBackground extends ConsumerWidget {
  const BoardBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(boardBackdropProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = switch (value) {
      BoardBackdrop.sky =>
        dark
            ? [const Color(0xFF10141D), const Color(0xFF151B26)]
            : [
                const Color(0xFFFCFDFF),
                const Color(0xFFF1F6FD),
                const Color(0xFFE4EEFA),
              ],
      BoardBackdrop.plain =>
        dark
            ? [context.glass.bg, context.glass.bg]
            : [const Color(0xFFFAFBFC), const Color(0xFFF0F4F8)],
      BoardBackdrop.paper =>
        dark
            ? [const Color(0xFF242321), const Color(0xFF191A1C)]
            : [const Color(0xFFF5F2EC), const Color(0xFFECE9E3)],
      BoardBackdrop.dusk =>
        dark
            ? [const Color(0xFF222938), const Color(0xFF171A24)]
            : [const Color(0xFFE9EEF4), const Color(0xFFE9E5EE)],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: value == BoardBackdrop.paper ? _PaperDots(dark) : null,
        child: child,
      ),
    );
  }
}

class _PaperDots extends CustomPainter {
  _PaperDots(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: .045);
    for (double y = 14; y < size.height; y += 24) {
      for (double x = 14; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PaperDots oldDelegate) => oldDelegate.dark != dark;
}

class BoardBackgroundSheet extends ConsumerWidget {
  const BoardBackgroundSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Make it yours',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('A quiet backdrop for your thoughts and spaces.'),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(
                height: 130,
                width: double.infinity,
                child: BoardBackground(
                  child: Center(
                    child: Text(
                      'Room to think',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AscentSegmentedControl<BoardBackdrop>(
              segments: const [
                AscentSegment(value: BoardBackdrop.sky, label: 'Sky'),
                AscentSegment(value: BoardBackdrop.paper, label: 'Paper'),
                AscentSegment(value: BoardBackdrop.dusk, label: 'Dusk'),
                AscentSegment(value: BoardBackdrop.plain, label: 'Plain'),
              ],
              selected: ref.watch(boardBackdropProvider),
              onChanged: (value) async {
                try {
                  await ref.read(boardBackdropProvider.notifier).set(value);
                } catch (_) {
                  if (context.mounted) {
                    AscentSnackBar.error(
                      context,
                      message: 'Could not save background.',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
