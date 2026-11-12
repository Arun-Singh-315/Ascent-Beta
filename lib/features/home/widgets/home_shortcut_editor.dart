import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/home_layout_provider.dart';
import 'home_shortcut_icon.dart';
import 'home_theme.dart';
import 'home_shortcuts.dart';
import '../home_customization_sheet.dart';
import '../../../shared/widgets/ascent_button.dart';

Future<void> showHomeShortcutEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: HomeTheme.from(
        Theme.of(context),
      ).colorScheme.surfaceContainer,
      builder: (_) => Theme(
        data: HomeTheme.from(Theme.of(context)),
        child: Material(
          key: const ValueKey('home_shortcut_editor_surface'),
          color: HomeTheme.from(Theme.of(context)).colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: _ShortcutEditor(host: context),
        ),
      ),
    );

class _ShortcutEditor extends ConsumerStatefulWidget {
  const _ShortcutEditor({required this.host});
  final BuildContext host;
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
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = MediaQuery.textScalerOf(context).scale(14) > 21
                    ? 2
                    : 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (final entry in homeShortcutRoutes.entries)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 8) /
                            columns,
                        child: Semantics(
                          selected: _ids.contains(entry.key),
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _saving
                                ? null
                                : () {
                                    final selected = !_ids.contains(entry.key);
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  HomeShortcutIcon(
                                    icon: kRegisteredShortcuts[entry.key]!.icon,
                                    selected: _ids.contains(entry.key),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    entry.value,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () {
                      final host = widget.host;
                      Navigator.pop(context);
                      showHomeCustomization(host);
                    },
              icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
              label: const Text('Customize Home sections'),
            ),
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
