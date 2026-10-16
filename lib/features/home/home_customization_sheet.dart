import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/home_layout_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';

Future<void> showHomeCustomization(BuildContext context) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppPalette.transparent,
      builder: (_) => const HomeCustomizationSheet(),
    );

class HomeCustomizationSheet extends ConsumerStatefulWidget {
  const HomeCustomizationSheet({super.key});
  @override
  ConsumerState<HomeCustomizationSheet> createState() =>
      _HomeCustomizationSheetState();
}

class _HomeCustomizationSheetState
    extends ConsumerState<HomeCustomizationSheet> {
  late HomeLayout _draft = ref
      .read(homeLayoutProvider)
      .copyWith(
        visible: {...ref.read(homeLayoutProvider).visible}
          ..removeWhere(
            (id) => id == 'streak' && !ref.read(homeStreakVisibleProvider),
          ),
      );
  @override
  void initState() {
    super.initState();
    _draft = _draft.copyWith(
      order: ['mind', ..._draft.order.where((id) => id != 'mind')],
    );
  }

  bool _saving = false;
  String? _error;
  void _toggle(String id) {
    final visible = {..._draft.visible};
    if (!visible.remove(id)) visible.add(id);
    setState(() => _draft = _draft.copyWith(visible: visible));
  }

  void _move(int index, int delta) {
    final order = [..._draft.order];
    final item = order.removeAt(index);
    order.insert(index + delta, item);
    setState(() => _draft = _draft.copyWith(order: order));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return PopScope(
      canPop: !_saving,
      child: AppCard(
        height: MediaQuery.sizeOf(context).height * .9,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s16,
        ),
        nightDecoration: BoxDecoration(
          color: g.bg,
          borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr24),
          border: Border.all(color: g.edge),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Home',
                style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose what appears. Hiding a card keeps its records, alerts and timers intact.',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Preview order',
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _draft.order
                          .where(_draft.visible.contains)
                          .map(
                            (id) =>
                                AppTag.label(label: Text(homeSections[id]!)),
                          )
                          .toList(),
                    ),
                    if (_draft.visible.isEmpty)
                      const Text('Hidden tools remain available from More.'),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _draft.order.length; i++)
                      AppCard(
                        key: ValueKey('home_editor_${_draft.order[i]}'),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s6,
                        ),
                        nightDecoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: g.line)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _draft.visible.contains(
                                    _draft.order[i],
                                  ),
                                  onChanged: _saving
                                      ? null
                                      : (_) => _toggle(_draft.order[i]),
                                ),
                                Expanded(
                                  child: Text(
                                    homeSections[_draft.order[i]]!,
                                    style: AscentTextStyles.bodyMedium.copyWith(
                                      color: g.ink,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip:
                                      'Move ${homeSections[_draft.order[i]]} up',
                                  onPressed: _saving || i <= 1
                                      ? null
                                      : () => _move(i, -1),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  tooltip:
                                      'Move ${homeSections[_draft.order[i]]} down',
                                  onPressed:
                                      _saving ||
                                          i == 0 ||
                                          i == _draft.order.length - 1
                                      ? null
                                      : () => _move(i, 1),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                              ],
                            ),
                            if (_draft.order[i] == 'mind')
                              const Padding(
                                padding: EdgeInsets.only(left: AppSpace.s14),
                                child: Text(
                                  'Shown below your name. Opens with your most recent thought.',
                                ),
                              ),
                            if (_draft.order[i] == 'today')
                              SwitchListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: AppSpace.s14,
                                ),
                                title: const Text('Compact preview'),
                                value: _draft.compact.contains(_draft.order[i]),
                                onChanged: _saving
                                    ? null
                                    : (compact) {
                                        final ids = {..._draft.compact};
                                        compact
                                            ? ids.add(_draft.order[i])
                                            : ids.remove(_draft.order[i]);
                                        setState(
                                          () => _draft = _draft.copyWith(
                                            compact: ids,
                                          ),
                                        );
                                      },
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Life & Health tools',
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: g.ink,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: homeTools.entries
                          .map(
                            (tool) => AppPill.filter(
                              label: Text(tool.value),
                              selected: _draft.tools.contains(tool.key),
                              onSelected: _saving
                                  ? null
                                  : (selected) {
                                      final tools = {..._draft.tools};
                                      selected
                                          ? tools.add(tool.key)
                                          : tools.remove(tool.key);
                                      setState(
                                        () => _draft = _draft.copyWith(
                                          tools: tools,
                                        ),
                                      );
                                    },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Quick shortcuts · up to four',
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: g.ink,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: homeShortcutRoutes.entries
                          .map(
                            (tool) => AppPill.filter(
                              label: Text(tool.value),
                              selected: _draft.shortcuts.contains(tool.key),
                              onSelected:
                                  _saving ||
                                      (!_draft.shortcuts.contains(tool.key) &&
                                          _draft.shortcuts.length >= 4)
                                  ? null
                                  : (selected) {
                                      final ids = [..._draft.shortcuts];
                                      selected
                                          ? ids.add(tool.key)
                                          : ids.remove(tool.key);
                                      setState(
                                        () => _draft = _draft.copyWith(
                                          shortcuts: ids,
                                        ),
                                      );
                                    },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              final reset = await AscentDialog.confirm(
                                context: context,
                                title: 'Restore default Home?',
                                content:
                                    'Only the layout changes. Your records and preferences stay intact.',
                              );
                              if (mounted && reset == true) {
                                setState(() => _draft = HomeLayout.defaults());
                              }
                            },
                      child: const Text('Restore default layout'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: AscentTextStyles.bodySmall.copyWith(color: g.coral),
                ),
              const SizedBox(height: 10),
              AscentButton.primary(
                label: _saving ? 'Saving…' : 'Save changes',
                expanded: true,
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() {
                          _saving = true;
                          _error = null;
                        });
                        try {
                          await ref
                              .read(homeLayoutProvider.notifier)
                              .save(_draft);
                          if (!context.mounted) return;
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Home layout saved.')),
                          );
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _saving = false;
                              _error =
                                  'Could not save. Your current Home is unchanged.';
                            });
                          }
                        }
                      },
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
