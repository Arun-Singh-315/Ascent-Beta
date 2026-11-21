import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/thought_wall/utils/thought_checklist_helper.dart';
import 'package:ascent/shared/utils/smart_list_input_formatter.dart';
import 'package:ascent/shared/widgets/note_list_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('SmartListInputFormatter Unit Tests', () {
    const formatter = SmartListInputFormatter();

    test('auto-converts "-> " at start of line into bullet "• "', () {
      // User types "-> "
      const oldValue = TextEditingValue(
        text: '->',
        selection: TextSelection.collapsed(offset: 2),
      );
      const newValue = TextEditingValue(
        text: '-> ',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '• ');
      expect(result.selection.baseOffset, 2);
    });

    test('auto-converts "--> " at start of line into bullet "• "', () {
      const oldValue = TextEditingValue(
        text: '-->',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '--> ',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '• ');
      expect(result.selection.baseOffset, 2);
    });

    test(
      'pressing Enter after bullet line automatically continues with bullet',
      () {
        // User has "• Wake up early" and presses Enter
        const oldValue = TextEditingValue(
          text: '• Wake up early',
          selection: TextSelection.collapsed(offset: 15),
        );
        const newValue = TextEditingValue(
          text: '• Wake up early\n',
          selection: TextSelection.collapsed(offset: 16),
        );

        final result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '• Wake up early\n• ');
        expect(result.selection.baseOffset, '• Wake up early\n• '.length);
      },
    );

    test(
      'pressing Enter after numbered item automatically increments number',
      () {
        // User has "1. Morning walk" and presses Enter
        const oldValue = TextEditingValue(
          text: '1. Morning walk',
          selection: TextSelection.collapsed(offset: 15),
        );
        const newValue = TextEditingValue(
          text: '1. Morning walk\n',
          selection: TextSelection.collapsed(offset: 16),
        );

        final result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '1. Morning walk\n2. ');
        expect(result.selection.baseOffset, '1. Morning walk\n2. '.length);
      },
    );

    test('pressing Enter on empty bullet exits list mode cleanly', () {
      // User has "• Wake up\n• " and presses Enter on the empty bullet
      const oldValue = TextEditingValue(
        text: '• Wake up\n• ',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '• Wake up\n• \n',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '• Wake up\n');
      expect(result.selection.baseOffset, '• Wake up\n'.length);
    });

    test('pressing Enter on empty numbered line exits list mode cleanly', () {
      // User has "1. Wake up\n2. " and presses Enter on empty "2. "
      const oldValue = TextEditingValue(
        text: '1. Wake up\n2. ',
        selection: TextSelection.collapsed(offset: 14),
      );
      const newValue = TextEditingValue(
        text: '1. Wake up\n2. \n',
        selection: TextSelection.collapsed(offset: 15),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1. Wake up\n');
      expect(result.selection.baseOffset, '1. Wake up\n'.length);
    });
  });

  group('NoteListButton Compact Spacing Tests', () {
    test(
      'insertNextItem uses single newline without double blank line gap',
      () {
        final controller = TextEditingController(text: 'Wake up');
        NoteListButton.insertNextItem(controller);
        expect(controller.text, 'Wake up\n• ');
        expect(controller.text.contains('\n\n'), isFalse);
        controller.dispose();
      },
    );

    test(
      'insertNextItem when already ending with newline does not add extra newline',
      () {
        final controller = TextEditingController(text: 'Wake up\n');
        NoteListButton.insertNextItem(controller);
        expect(controller.text, 'Wake up\n• ');
        controller.dispose();
      },
    );
  });

  group('PlanItemDraft Parser with "->" Tests', () {
    test(
      'parseList cleans leading "->" and "-->" without leaving arrows in task titles',
      () {
        const raw = '''
-> Wake up
-> Drink lemon tea
--> Morning walk
• Revise notes
1. Gym session
''';
        final titles = PlanItemDraft.parseList(raw);
        expect(titles.length, 5);
        expect(titles[0], 'Wake up');
        expect(titles[1], 'Drink lemon tea');
        expect(titles[2], 'Morning walk');
        expect(titles[3], 'Revise notes');
        expect(titles[4], 'Gym session');
      },
    );
  });

  group('ThoughtChecklistHelper with "->" Tests', () {
    test('parses "->" and "-->" items as interactive checklist items', () {
      const text = '''
My Schedule:
-> Wake up
-> Drink lemon tea
• Morning walk
''';
      final items = ThoughtChecklistHelper.parseItems(text);
      expect(items.length, 3);
      expect(items[0].text, 'Wake up');
      expect(items[1].text, 'Drink lemon tea');
      expect(items[2].text, 'Morning walk');
    });

    test('toggling "->" item converts to checkbox correctly', () {
      const text = '-> Wake up\n-> Gym';
      final toggled = ThoughtChecklistHelper.toggleItemDone(text, 0);
      expect(toggled.contains('☑ Wake up'), isTrue);
    });
  });

  group('ThoughtExcerpt Bullet & Spacing Formatting Tests', () {
  });
}
