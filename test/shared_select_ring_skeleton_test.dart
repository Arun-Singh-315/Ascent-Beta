import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/ascent_popup_menu.dart';
import 'package:ascent/shared/widgets/ascent_progress_ring.dart';
import 'package:ascent/shared/widgets/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: dark ? AscentTheme.dark() : AscentTheme.light(),
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

void main() {
  group('AscentSelectField', () {
    testWidgets('shows the current label and reports a picked value', (
      t,
    ) async {
      int? picked = 1;
      await t.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, set) => AscentSelectField<int?>(
              label: 'Care plan',
              value: picked,
              options: const [
                AscentSelectOption<int?>(null, 'No care plan'),
                AscentSelectOption<int?>(1, 'Recovery care'),
                AscentSelectOption<int?>(2, 'Daily care'),
              ],
              onChanged: (v) => set(() => picked = v),
            ),
          ),
        ),
      );
      expect(find.text('Recovery care'), findsOneWidget);
      expect(find.text('Care plan'), findsOneWidget);

      await t.tap(find.byType(AscentSelectField<int?>));
      await t.pumpAndSettle();
      await t.tap(find.text('No care plan').last);
      await t.pumpAndSettle();
      // A null option is a real choice, not a cancel.
      expect(picked, isNull);
      expect(find.text('No care plan'), findsOneWidget);
    });

    testWidgets('disabled field does not open', (t) async {
      await t.pumpWidget(
        _app(
          const AscentSelectField<String>(
            label: 'Activity',
            value: 'all',
            options: [
              AscentSelectOption('all', 'All activities'),
              AscentSelectOption('water', 'Water'),
            ],
            onChanged: null,
          ),
        ),
      );
      await t.tap(find.byType(AscentSelectField<String>));
      await t.pumpAndSettle();
      expect(find.text('Water'), findsNothing);
    });

    testWidgets('100 options, dark, text scale 2 do not overflow', (t) async {
      await t.pumpWidget(
        _app(
          AscentSelectField<int>(
            label: 'Show after',
            value: 99,
            options: [
              for (var i = 0; i < 100; i++)
                AscentSelectOption(i, 'A rather long option label $i'),
            ],
            onChanged: (_) {},
          ),
          dark: true,
          scale: 2,
        ),
      );
      expect(t.takeException(), isNull);
      await t.tap(find.byType(AscentSelectField<int>));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('AscentProgressRing clamps and labels its value', (t) async {
    for (final dark in [false, true]) {
      await t.pumpWidget(
        _app(
          const SizedBox.square(
            dimension: 44,
            child: AscentProgressRing(value: 1.7, semanticsLabel: 'Doses'),
          ),
          dark: dark,
        ),
      );
      expect(t.takeException(), isNull);
      expect(
        t.getSemantics(find.byType(AscentProgressRing)),
        matchesSemantics(label: 'Doses', value: '100%'),
      );
    }
  });

  testWidgets('ListSkeleton renders the requested rows', (t) async {
    await t.pumpWidget(_app(const ListSkeleton(rows: 4)));
    expect(find.byType(SkeletonShimmer), findsNWidgets(4));
    // A short loading area clips the skeleton instead of overflowing.
    await t.pumpWidget(
      _app(
        const Column(children: [SizedBox(height: 80, child: ListSkeleton())]),
        scale: 2,
      ),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
