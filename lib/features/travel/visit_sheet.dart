import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/travel/here_locator.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'bill_sheet.dart';
import 'travel_ui.dart';

/// One tap of "I'm here": read the location once, save the visit, and show
/// what was filled in, ready for a bill, photos or a note.
Future<void> showHereSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showAscentSheet<void>(
    context: context,
    builder: (_) => const VisitSheet(),
  );
}

/// Adds a place by name, without reading the location.
Future<void> showAddPlaceSheet(BuildContext context, {String? tripId}) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => VisitSheet(manual: true, tripId: tripId),
    );

/// Opens a saved visit.
Future<void> showVisitSheet(BuildContext context, String visitId) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => VisitSheet(visitId: visitId),
    );

/// Picks photos and attaches them to [visitId].
Future<void> addVisitPhotos(
  BuildContext context,
  WidgetRef ref,
  String visitId,
) async {
  try {
    final paths = await pickVisitPhotos();
    if (paths.isEmpty) return;
    await ref.read(travelServiceProvider).addPhotos(visitId, paths);
    if (context.mounted) {
      AscentSnackBar.success(
        context,
        message: paths.length == 1
            ? '1 photo added'
            : '${paths.length} photos added',
      );
    }
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: "Couldn't open your photos. Check photo access in Settings.",
      );
    }
  }
}

class VisitSheet extends ConsumerStatefulWidget {
  /// With no [visitId], the sheet locates you and creates the visit.
  const VisitSheet({super.key, this.visitId, this.manual = false, this.tripId});
  final String? visitId;

  /// Type the place instead of locating.
  final bool manual;

  /// Trip for a typed place (defaults to the live trip).
  final String? tripId;

  @override
  ConsumerState<VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends ConsumerState<VisitSheet> {
  String? _id;
  bool _locating = false;
  HereProblem? _problem;
  List<PlaceGuess> _guesses = const [];
  final _manual = TextEditingController();
  final _note = TextEditingController();
  bool _editingNote = false;

  @override
  void initState() {
    super.initState();
    _id = widget.visitId;
    if (_id == null && !widget.manual) {
      _locating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final here = await ref.read(hereLocatorProvider).locate();
    if (!mounted) return;
    if (!here.found) {
      setState(() {
        _locating = false;
        _problem = here.problem;
      });
      return;
    }
    final travel = ref.read(travelServiceProvider);
    final best = here.guesses.firstOrNull;
    final id = await travel.addVisit(
      name: best?.name ?? 'Place near you',
      area: best?.area,
      fix: here.fix,
      kind: best?.kind,
      weather: here.weather,
      named: best != null,
    );
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _id = id;
      _guesses = here.guesses;
      _locating = false;
    });
  }

  Future<void> _saveManual() async {
    final name = _manual.text.trim();
    if (name.isEmpty) return;
    final id = await ref
        .read(travelServiceProvider)
        .addVisit(
          name: name,
          tripId: widget.tripId == null
              ? const Value.absent()
              : Value(widget.tripId),
        );
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() {
        _id = id;
        _problem = null;
      });
    }
  }

  Future<void> _delete(VisitRow v) async {
    final travel = ref.read(travelServiceProvider);
    final at = await travel.deleteVisit(v.id);
    if (!mounted) return;
    final root = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    if (root.mounted) {
      AscentSnackBar.undo(
        root,
        message: 'Visit deleted',
        onUndo: () => travel.restoreVisit(v.id, at),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    Widget body;
    if (_locating) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s40),
        child: Column(
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: AppSpace.s16),
            Text(
              'Finding where you are…',
              style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
            ),
          ],
        ),
      );
    } else if (_id == null) {
      body = _Manual(
        problem: _problem,
        controller: _manual,
        onSave: _saveManual,
      );
    } else {
      final visit = ref.watch(visitProvider(_id!)).value;
      body = visit == null
          ? const SizedBox(height: 160)
          : _Detail(
              visit: visit,
              guesses: _guesses,
              note: _note,
              editingNote: _editingNote,
              onEditNote: () => setState(() {
                _note.text = visit.note ?? '';
                _editingNote = true;
              }),
              onSaveNote: () async {
                await ref
                    .read(travelServiceProvider)
                    .editVisit(visit.id, note: Value(_note.text.trim()));
                if (mounted) setState(() => _editingNote = false);
              },
              onDelete: () => _delete(visit),
            );
    }
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        0,
        AppSpace.s20,
        AppSpace.s24,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: body,
      ),
    );
  }
}

class _Manual extends StatelessWidget {
  const _Manual({
    required this.problem,
    required this.controller,
    required this.onSave,
  });
  final HereProblem? problem;
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final why = switch (problem) {
      null => 'Add a place you went, or one you plan to visit.',
      HereProblem.permissionDenied =>
        "Location is off for Ascent, so type where you are. You can allow it later in Settings.",
      HereProblem.locationOff =>
        'Your phone’s location is switched off. Type where you are instead.',
      _ => "Couldn't get a location fix. Type where you are instead.",
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          problem == null ? 'Add a place' : 'Where are you?',
          style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          why,
          style: AscentTextStyles.supportingText.copyWith(
            color: g.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        AppTextField(
          key: const ValueKey('visit_manual_name'),
          controller: controller,
          autofocus: true,
          hintText: 'e.g. Baga beach',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSave(),
        ),
        const SizedBox(height: AppSpace.s16),
        AscentButton.primary(
          key: const ValueKey('visit_manual_save'),
          label: 'Save visit',
          expanded: true,
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.visit,
    required this.guesses,
    required this.note,
    required this.editingNote,
    required this.onEditNote,
    required this.onSaveNote,
    required this.onDelete,
  });
  final VisitRow visit;
  final List<PlaceGuess> guesses;
  final TextEditingController note;
  final bool editingNote;
  final VoidCallback onEditNote, onSaveNote, onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final travel = ref.read(travelServiceProvider);
    final trip = visit.tripId == null
        ? null
        : ref.watch(tripProvider(visit.tripId!)).value;
    final photos = ref.watch(visitPhotosProvider(visit.id)).value ?? const [];
    final bills = ref.watch(visitBillsProvider(visit.id)).value ?? const [];
    final others = guesses.where((x) => x.name != visit.name).toList();
    final when = humanWhen(visit.at);
    final facts = [
      when.isEmpty ? when : when[0].toUpperCase() + when.substring(1),
      if (visit.weather != null) visit.weather!,
      if (trip != null) '${trip.trip.name} trip',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            VisitTile(kind: visit.kind, size: 44),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.name,
                    key: const ValueKey('visit_name'),
                    style: AscentTextStyles.pageTitle.copyWith(color: g.ink),
                  ),
                  if (visit.area != null)
                    Text(
                      visit.area!,
                      style: AscentTextStyles.supportingText.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [for (final f in facts) AppChip(label: f, height: 32)],
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s16),
          Text(
            'Not the right place?',
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final o in others)
                AppChip(
                  key: ValueKey('visit_guess_${o.name}'),
                  label: o.name,
                  icon: visitIcon(o.kind),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    travel.editVisit(
                      visit.id,
                      name: o.name,
                      area: Value(o.area),
                      kind: Value(o.kind),
                    );
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s20),
        Row(
          children: [
            Expanded(
              child: _Action(
                key: const ValueKey('visit_add_bill'),
                icon: Icons.receipt_long_outlined,
                label: bills.isEmpty
                    ? 'Bill'
                    : rupees(bills.fold<double>(0, (s, b) => s + b.amount)),
                done: bills.isNotEmpty,
                onTap: () => showBillSheet(
                  context,
                  tripId: visit.tripId,
                  visitId: visit.id,
                  title: visit.name,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: _Action(
                key: const ValueKey('visit_add_photos'),
                icon: Icons.photo_camera_outlined,
                label: photos.isEmpty
                    ? 'Photos'
                    : '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                done: photos.isNotEmpty,
                onTap: () => addVisitPhotos(context, ref, visit.id),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: _Action(
                key: const ValueKey('visit_add_note'),
                icon: Icons.edit_note_rounded,
                label: 'Note',
                done: (visit.note ?? '').isNotEmpty,
                onTap: onEditNote,
              ),
            ),
          ],
        ),
        if (editingNote) ...[
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('visit_note'),
            controller: note,
            autofocus: true,
            hintText: 'e.g. Best prawn curry, sit by the window',
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AscentButton.ghost(
              key: const ValueKey('visit_note_save'),
              label: 'Save note',
              compact: true,
              onPressed: onSaveNote,
            ),
          ),
        ] else if ((visit.note ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Text(
            visit.note!,
            style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
          ),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s16),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(photos[i].path),
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  cacheWidth: 264,
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    color: g.recessed,
                    child: Icon(Icons.image_outlined, color: g.inkMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        Align(
          alignment: Alignment.centerLeft,
          child: AscentButton.destructive(
            key: const ValueKey('visit_delete'),
            label: 'Delete visit',
            compact: true,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

/// A square action under a visit: Bill, Photos, Note.
class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.done = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final color = done ? g.successInk : g.actionInk;
    return Material(
      color: g.recessed,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(done ? Icons.check_circle_rounded : icon, color: color),
                const SizedBox(height: AppSpace.s4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.caption.copyWith(color: g.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
