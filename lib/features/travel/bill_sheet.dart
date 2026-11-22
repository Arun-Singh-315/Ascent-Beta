import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'travel_ui.dart';

/// Adds a bill: how much, what for, who paid, who shares it. Only the
/// amount is needed; you paid and everyone shares by default.
Future<void> showBillSheet(
  BuildContext context, {
  String? tripId,
  String? visitId,
  String title = '',
}) => showAscentSheet<void>(
  context: context,
  builder: (_) => BillSheet(tripId: tripId, visitId: visitId, title: title),
);

class BillSheet extends ConsumerStatefulWidget {
  const BillSheet({super.key, this.tripId, this.visitId, this.title = ''});
  final String? tripId, visitId;
  final String title;

  @override
  ConsumerState<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<BillSheet> {
  final _amount = TextEditingController();
  late final TextEditingController _title;
  String? _paidBy;
  Set<String>? _shared;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  double? get _value =>
      double.tryParse(_amount.text.replaceAll(RegExp(r'[₹,\s]'), ''));

  Future<void> _save(TripView? trip) async {
    final amount = _value;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter how much it was, e.g. 1200.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final travel = ref.read(travelServiceProvider);
    try {
      final id = await travel.addBill(
        tripId: widget.tripId,
        visitId: widget.visitId,
        title: _title.text.trim().isEmpty ? 'Bill' : _title.text,
        amount: amount,
        paidBy: _paidBy ?? trip?.me?.id,
        sharedWith: _shared?.toList(),
      );
      HapticFeedback.lightImpact();
      if (widget.visitId != null) await travel.settleVisit(widget.visitId!);
      if (!mounted) return;
      final root = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      if (root.mounted) {
        AscentSnackBar.undo(
          root,
          message: 'Bill added: ${rupees(amount)}',
          onUndo: () => travel.deleteBill(id),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final trip = widget.tripId == null
        ? null
        : ref.watch(tripProvider(widget.tripId!)).value;
    final people = trip?.people ?? const [];
    final shared = _shared ?? people.map((p) => p.id).toSet();
    final payer = _paidBy ?? trip?.me?.id;
    final each = _value == null || shared.isEmpty
        ? null
        : splitEqually(_value!, shared.length).first;
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'Add bill',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              AscentButton.ghost(
                key: const ValueKey('bill_save'),
                label: 'Save',
                loading: _saving,
                onPressed: () => _save(trip),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('bill_amount'),
            controller: _amount,
            autofocus: true,
            hintText: '₹ e.g. 1200',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: AscentTextStyles.tabular(
              AscentTextStyles.pageTitle,
            ).copyWith(color: g.ink),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            key: const ValueKey('bill_title'),
            controller: _title,
            hintText: 'What for, e.g. Dinner',
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _error!,
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
          if (people.length > 1) ...[
            const SizedBox(height: AppSpace.s20),
            Text(
              'Paid by',
              style: AscentTextStyles.caption.copyWith(color: g.ink),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final p in people)
                  AppChip(
                    key: ValueKey('bill_payer_${p.name}'),
                    label: p.name,
                    isSelected: payer == p.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _paidBy = p.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              'Split with',
              style: AscentTextStyles.caption.copyWith(color: g.ink),
            ),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final p in people)
                  AppChip(
                    key: ValueKey('bill_share_${p.name}'),
                    label: p.name,
                    icon: shared.contains(p.id) ? Icons.check_rounded : null,
                    isSelected: shared.contains(p.id),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final next = {...shared};
                      if (!next.remove(p.id)) next.add(p.id);
                      setState(() => _shared = next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              each == null
                  ? 'Split equally between the people selected.'
                  : '${rupees(each)} each, split ${shared.length} ways.',
              style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
