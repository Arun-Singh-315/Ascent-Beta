import 'package:flutter/material.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../today/add_activity_sheet.dart';
import '../../thought_wall/drop_thought_sheet.dart';
import '../../promises/widgets/promise_chat_composer.dart';
import '../../money/add_transaction_sheet.dart';

/// Home always retains a capture entry, independently of visible sections.
Future<void> showHomeCaptureActions(BuildContext context) async {
  final action = await showAscentActionMenu<String>(
    context: context,
    title: 'Add',
    actions: const [
      AscentAction('activity', 'Activity', Icons.add_task_rounded),
      AscentAction('thought', 'Thought', Icons.edit_note_rounded),
      AscentAction('commitment', 'Commitment', Icons.commit_rounded),
      AscentAction('expense', 'Expense', Icons.account_balance_wallet_outlined),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'activity':
      await AddActivitySheet.show(context);
    case 'thought':
      await DropThoughtSheet.show(context);
    case 'commitment':
      await PromiseChatComposer.show(context);
    case 'expense':
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AddTransactionSheet(),
      );
  }
}
