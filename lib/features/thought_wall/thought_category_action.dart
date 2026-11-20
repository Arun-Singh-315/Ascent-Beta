import 'package:flutter/material.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';

/// Asks for a new space's name. Returns the trimmed name, or null when
/// cancelled. [move] changes the confirm label to "Create and move".
Future<String?> showCreateSpaceDialog(
  BuildContext context, {
  bool move = false,
}) => showAscentFrostedDialog<String>(
  context: context,
  builder: (_) => CreateThoughtCategoryDialog(move: move),
);

class CreateThoughtCategoryDialog extends StatefulWidget {
  const CreateThoughtCategoryDialog({super.key, this.move = false});
  final bool move;
  @override
  State<CreateThoughtCategoryDialog> createState() =>
      _CreateThoughtCategoryDialogState();
}

class _CreateThoughtCategoryDialogState
    extends State<CreateThoughtCategoryDialog> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  static String? _validate(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter a name for the space.';
    if (name.length > 50) return 'Use 50 characters or fewer.';
    return null;
  }

  @override
  Widget build(BuildContext context) => AscentDialog(
    title: 'New space',
    icon: Icons.create_new_folder_outlined,
    contentWidget: Form(
      key: _form,
      child: AppTextField(
        key: const ValueKey('new_space_name'),
        controller: _name,
        autofocus: true,
        hintText: 'e.g. Movies',
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        validator: _validate,
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AscentDimensions.spaceSm,
        runSpacing: AscentDimensions.spaceSm,
        children: [
          AscentButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AscentButton.tonal(
            key: const ValueKey('new_space_create'),
            label: widget.move ? 'Create and move' : 'Create',
            compact: true,
            onPressed: _submit,
          ),
        ],
      ),
    ],
  );
}
