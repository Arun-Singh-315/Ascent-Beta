import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';

Future<bool> moveThoughtsToCategory(
  BuildContext context,
  WidgetRef ref,
  List<Thought> selected,
) async {
  var category = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, sheetRef, _) {
        final categories =
            sheetRef.watch(thoughtCategoriesStreamProvider).value ??
            ThoughtDao.builtInCategories;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Move to category')),
                for (final entry in categories.entries)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(entry.value),
                    onTap: () => Navigator.pop(context, entry.key),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('Create category'),
                  onTap: () => Navigator.pop(context, '__create__'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (category == null || !context.mounted) return false;
  String? createdName;
  if (category == '__create__') {
    createdName = await showDialog<String>(
      context: context,
      builder: (_) => const CreateThoughtCategoryDialog(move: true),
    );
    if (createdName == null || !context.mounted) return false;
  }
  final db = ref.read(databaseProvider);
  try {
    if (createdName != null) {
      category = await db.thoughtDao.createCategoryAndMove(
        createdName,
        selected.map((t) => t.id),
      );
    } else {
      await db.thoughtDao.moveToCategory(selected.map((t) => t.id), category);
    }
    if (!context.mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        content: Text(
          '${selected.length} moved to ${(ref.read(thoughtCategoriesStreamProvider).value ?? ThoughtDao.builtInCategories)[category] ?? createdName}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await db.transaction(() async {
              for (final thought in selected) {
                final current = await db.thoughtDao.getThoughtById(thought.id);
                if (current?.category == category) {
                  await db.thoughtDao.moveToCategory([
                    thought.id,
                  ], thought.category);
                }
              }
            });
          },
        ),
      ),
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not move notes. Try again.')),
      );
    }
    return false;
  }
}

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
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create category'),
    scrollable: true,
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 50,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Category name',
          hintText: 'e.g. Learning',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a category name.'
            : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.move ? 'Create and move' : 'Create'),
      ),
    ],
  );
}
