import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../../shared/widgets/app_surfaces.dart';
import '../../../shared/widgets/ascent_button.dart';

Future<void> showHomeShortcutEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _ShortcutEditor(),
    );

class _ShortcutEditor extends ConsumerStatefulWidget {
  const _ShortcutEditor();
  @override
  ConsumerState<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends ConsumerState<_ShortcutEditor> {
  late final List<String> _ids = [...ref.read(homeLayoutProvider).shortcuts];
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(homeLayoutProvider.notifier)
          .save(ref.read(homeLayoutProvider).copyWith(shortcuts: [..._ids]));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your shortcuts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose up to four. Tap a selected shortcut to remove it.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in homeShortcutRoutes.entries)
                  AppPill.filter(
                    label: Text(entry.value),
                    selected: _ids.contains(entry.key),
                    onSelected: _saving
                        ? null
                        : (selected) {
                            if (selected && _ids.length >= 4) {
                              setState(
                                () => _error =
                                    'Remove a shortcut before adding another.',
                              );
                              return;
                            }
                            setState(() {
                              _error = null;
                              selected
                                  ? _ids.add(entry.key)
                                  : _ids.remove(entry.key);
                            });
                          },
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.glass.destructiveFg),
                ),
              ),
            const SizedBox(height: 20),
            AscentButton.primary(
              label: 'Save shortcuts',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            AscentButton.outlined(
              label: 'Cancel',
              onPressed: _saving ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
