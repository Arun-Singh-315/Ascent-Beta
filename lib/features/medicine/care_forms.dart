import 'dart:io';
import 'care_design.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/care_repository.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';

final careRepositoryProvider = Provider(
  (ref) => CareRepository(ref.watch(databaseProvider)),
);
final carePlansProvider = StreamProvider(
  (ref) => ref.watch(careRepositoryProvider).watchPlans(),
);
final careRecordsProvider = StreamProvider.family<List<CareRecord>, int>(
  (ref, id) => ref.watch(careRepositoryProvider).watchRecords(id),
);

Future<void> showCareForm(
  BuildContext context, {
  CarePlan? plan,
  int? recordPlanId,
  CareRecord? record,
}) => showAscentCenteredForm<void>(
  context: context,
  maxWidth: 460,
  barrierDismissible: false,
  builder: (_) =>
      CareForm(plan: plan, recordPlanId: recordPlanId, record: record),
);

class CareForm extends ConsumerStatefulWidget {
  const CareForm({super.key, this.plan, this.recordPlanId, this.record});
  final CarePlan? plan;
  final CareRecord? record;
  final int? recordPlanId;
  @override
  ConsumerState<CareForm> createState() => _CareFormState();
}

class _CareFormState extends ConsumerState<CareForm> {
  late final _title = TextEditingController(
    text: widget.record?.title ?? widget.plan?.title,
  );
  late final _person = TextEditingController(text: widget.plan?.person);
  late final _clinician = TextEditingController(text: widget.plan?.clinician);
  late final _notes = TextEditingController(
    text: widget.record?.notes ?? widget.plan?.notes,
  );
  late DateTime? _date = widget.recordPlanId == null
      ? widget.plan?.nextVisit
      : widget.record?.recordedAt ?? DateTime.now();
  PlatformFile? _file;
  bool _saving = false;
  String? _error;
  bool get _record => widget.recordPlanId != null;

  @override
  void dispose() {
    for (final c in [_title, _person, _clinician, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 20, 12, 31),
    );
    if (mounted && picked != null) setState(() => _date = picked);
  }

  Future<void> _attach() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (!mounted || result.isEmpty) return;
      final file = result.single;
      if (file.path == null || await file.length() > 20 * 1024 * 1024) {
        setState(() => _error = 'Choose a PDF or image up to 20 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _file = file;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open files. Please try again.');
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(
        () => _error = 'Give this ${_record ? 'record' : 'care plan'} a name.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(careRepositoryProvider);
      if (_record) {
        await repo.addRecord(
          id: widget.record?.id,
          planId: widget.recordPlanId!,
          title: _title.text,
          notes: _notes.text,
          recordedAt: _date!,
          attachment: _file == null ? null : File(_file!.path!),
          fileName: _file?.name,
          documents: _file == null
              ? null
              : await getApplicationDocumentsDirectory(),
        );
      } else {
        await repo.savePlan(
          id: widget.plan?.id,
          title: _title.text,
          person: _person.text,
          clinician: _clinician.text,
          notes: _notes.text,
          nextVisit: _date,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Your details are still here.';
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    int lines = 1,
    int limit = 200,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextField(
      controller: c,
      enabled: !_saving,
      maxLines: lines,
      maxLength: limit,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: context.glass.ink.withValues(alpha: .035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _record
                        ? (widget.record == null
                              ? 'Add a care record'
                              : 'Edit care record')
                        : widget.plan == null
                        ? 'Create a care plan'
                        : 'Edit care plan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              _record
                  ? 'A report, visit or small update worth keeping.'
                  : 'One place for a health concern, its medicines and its story.',
              style: TextStyle(color: context.glass.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            CareEyebrow(
              _record ? 'A moment in your care story' : 'Make it personal',
            ),
            _field(
              _record ? 'Record title' : 'Care plan name',
              _title,
              _record
                  ? 'e.g. November blood test'
                  : 'e.g. Thyroid care or Recovery after surgery',
            ),
            if (!_record) ...[
              _field(
                'Who is this for? (optional)',
                _person,
                'My care, Mum, or a name',
              ),
              _field(
                'Doctor / clinic (optional)',
                _clinician,
                'Who is looking after this concern?',
              ),
            ],
            _field(
              _record ? 'Notes (optional)' : 'Care notes (optional)',
              _notes,
              _record
                  ? 'What changed? What did your clinician say?'
                  : 'What matters to you? Questions for your next visit.',
              lines: 3,
              limit: 10000,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_record ? 'Record date' : 'Next visit (optional)'),
              subtitle: Text(
                _date == null
                    ? 'Choose a date'
                    : DateFormat.yMMMd().format(_date!),
              ),
              onTap: _saving ? null : _pickDate,
              trailing: !_record && _date != null
                  ? IconButton(
                      tooltip: 'Clear next visit',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _date = null),
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
            if (_record) ...[
              if (widget.record?.fileName != null && _file == null)
                Text(
                  'Saved report: ${widget.record!.fileName}',
                  style: TextStyle(color: context.glass.inkMuted),
                ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _attach,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_file?.name ?? 'Attach report · PDF or image'),
              ),
              if (_file != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _file = null),
                  child: const Text('Remove attachment'),
                ),
              Text(
                'A copy is kept with your app data. PDF, JPG or PNG · up to 20 MB.',
                style: TextStyle(
                  color: context.glass.inkMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.glass.errorInk),
                ),
              ),
            const SizedBox(height: 20),
            AscentButton.primary(
              label: _record ? 'Save record' : 'Save care plan',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
