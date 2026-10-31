import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';

const thoughtBoardLayoutKey = 'ascent_thought_board_layout_v1';

/// Two staggered columns, or one wide column.
enum ThoughtBoardLayout { board, stream }

class ThoughtBoardLayoutNotifier extends Notifier<ThoughtBoardLayout> {
  @override
  ThoughtBoardLayout build() {
    try {
      final raw = ref
          .watch(sharedPreferencesProvider)
          .getString(thoughtBoardLayoutKey);
      return ThoughtBoardLayout.values
              .where((layout) => layout.name == raw)
              .firstOrNull ??
          ThoughtBoardLayout.board;
    } catch (_) {
      return ThoughtBoardLayout.board;
    }
  }

  Future<void> set(ThoughtBoardLayout layout) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!await prefs.setString(thoughtBoardLayoutKey, layout.name)) {
      throw StateError('Could not save the wall layout');
    }
    if (ref.mounted) state = layout;
  }
}

final thoughtBoardLayoutProvider =
    NotifierProvider<ThoughtBoardLayoutNotifier, ThoughtBoardLayout>(
      ThoughtBoardLayoutNotifier.new,
    );
