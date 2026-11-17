import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_dialog.dart';

Future<bool> moveThoughtsToCategory(
  BuildContext context,
  WidgetRef ref,
  List<Thought> selected,
) async {
  var category = await showAscentCenteredForm<String>(
    context: context,
    maxWidth: 380,
    builder: (dialogContext) => Material(
      color: dialogContext.glass.elevated,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: dialogContext.glass.line, width: 1.0),
        ),
        child: Consumer(
          builder: (context, sheetRef, _) {
            final categories =
                sheetRef.watch(thoughtCategoriesStreamProvider).value ??
                ThoughtDao.builtInCategories;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Move to category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: dialogContext.glass.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(
                          Icons.close_rounded,
                          color: dialogContext.glass.inkMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final entry in categories.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(dialogContext, entry.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 20,
                                  color: dialogContext.glass.clay,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: dialogContext.glass.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 16),
                  Material(
                    color: dialogContext.glass.clay.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(dialogContext, '__create__'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.create_new_folder_outlined,
                              size: 20,
                              color: dialogContext.glass.clay,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Create category',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: dialogContext.glass.clay,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
