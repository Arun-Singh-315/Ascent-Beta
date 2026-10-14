import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../shared/widgets/ascent_button.dart';
import 'thought_actions.dart';

Future<bool> showThoughtMerge(
  BuildContext context,
  AppDatabase db,
  List<Thought> thoughts,
) async {
  if (thoughts.length < 2) return false;
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppPalette.transparent,
        builder: (_) => _ThoughtMergeSheet(db: db, thoughts: thoughts),
      ) ??
      false;
}

class _ThoughtMergeSheet extends StatefulWidget {
  const _ThoughtMergeSheet({required this.db, required this.thoughts});
  final AppDatabase db;
  final List<Thought> thoughts;
  @override
  State<_ThoughtMergeSheet> createState() => _ThoughtMergeSheetState();
}

class _ThoughtMergeSheetState extends State<_ThoughtMergeSheet> {
  late final sources = [...widget.thoughts];
  late final controller = TextEditingController(
    text: sources.map((n) => n.content).join('\n\n'),
  );
  bool archive = false, pin = false, saving = false, previewEdited = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return StatefulBuilder(
      builder: (sheetContext, update) {
        final g = sheetContext.glass;
        return PopScope(
          canPop: !saving,
          child: AppCard(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .9,
            ),
            nightDecoration: BoxDecoration(
              color: g.bg,
              borderRadius: const BorderRadius.vertical(
                top: AppGeometry.radiusr24,
              ),
              border: Border.all(color: g.edge),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpace.s24,
              AppSpace.s20,
              AppSpace.s24,
              AppSpace.s24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merge thoughts',
                      style: AscentTextStyles.displaySmall.copyWith(
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Creates one new note. Existing Todos and reminders stay linked to their original notes.',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < sources.length; i++)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i + 1}. ${sources[i].content}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: g.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Move note ${i + 1} up',
                            onPressed: saving || i == 0
                                ? null
                                : () => update(() {
                                    final source = sources.removeAt(i);
                                    sources.insert(i - 1, source);
                                    if (!previewEdited) {
                                      controller.text = sources
                                          .map((n) => n.content)
                                          .join('\n\n');
                                    }
                                  }),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            tooltip: 'Move note ${i + 1} down',
                            onPressed: saving || i == sources.length - 1
                                ? null
                                : () => update(() {
                                    final source = sources.removeAt(i);
                                    sources.insert(i + 1, source);
                                    if (!previewEdited) {
                                      controller.text = sources
                                          .map((n) => n.content)
                                          .join('\n\n');
                                    }
                                  }),
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
                      ),
                    TextField(
                      controller: controller,
                      onChanged: (_) => previewEdited = true,
                      enabled: !saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Merged note preview',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Archive originals'),
                      subtitle: const Text(
                        'Their linked actions remain intact',
                      ),
                      value: archive,
                      onChanged: saving
                          ? null
                          : (value) => update(() => archive = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pin merged note'),
                      value: pin,
                      onChanged: saving
                          ? null
                          : (value) => update(() => pin = value ?? false),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: g.coral,
                        ),
                      ),
                    const SizedBox(height: 12),
                    AscentButton.primary(
                      label: saving ? 'Saving…' : 'Save merged note',
                      expanded: true,
                      onPressed: saving
                          ? null
                          : () async {
                              update(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                final merged = await ThoughtActions(widget.db)
                                    .merge(
                                      sources,
                                      content: controller.text,
                                      archiveSources: archive,
                                      pin: pin,
                                    );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext, true);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Merged note saved. Original links preserved.',
                                    ),
                                    duration: const Duration(seconds: 8),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        final undone = await ThoughtActions(
                                          widget.db,
                                        ).undoMerge(merged.id);
                                        if (!undone && messenger.mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'This merge changed since saving. Your newer work was kept.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              } catch (failure) {
                                if (sheetContext.mounted) {
                                  update(() {
                                    saving = false;
                                    error = failure is StateError
                                        ? failure.message.toString()
                                        : 'Could not merge. Review the text and try again.';
                                  });
                                }
                              }
                            },
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
