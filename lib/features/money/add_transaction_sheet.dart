import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/actions/expense_actions.dart';
import '../../core/services/note_draft_binding.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_switch_row.dart';
import 'package:ascent/shared/widgets/ascent_popup_menu.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final FinanceTransaction? transactionToEdit;
  final Future<void> Function(int)? onSaved;

  const AddTransactionSheet({
    super.key,
    this.initialData,
    this.transactionToEdit,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? initialData,
    FinanceTransaction? transactionToEdit,
    Future<void> Function(int)? onSaved,
  }) {
    return showAscentCenteredForm<void>(
      context: context,
      barrierDismissible: false,
      maxWidth: 420,
      builder: (ctx) => Material(
        color: ctx.elevatedSurface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: AddTransactionSheet(
          initialData: initialData,
          transactionToEdit: transactionToEdit,
          onSaved: onSaved,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  int _page = 0;
  String _type = 'expense';
  String _category = 'Food & Groceries';
  String _account = 'UPI';
  DateTime _date = DateTime.now();
  bool _isRecurring = false;
  String? _selectedIntent;

  final List<String> _categories = const [
    'Food & Groceries',
    'Transport',
    'Shopping',
    'Education',
    'Bills & Subscriptions',
    'Health',
    'Entertainment',
    'Savings',
    'Other',
  ];

  final List<String> _accounts = const [
    'UPI',
    'Cash',
    'Bank Account',
    'Credit Card',
  ];

  bool _saving = false;
  String _entryToken = 'expense-entry:${DateTime.now().microsecondsSinceEpoch}';
  String? _submittedArguments;
  final _drafts = <NoteDraftBinding>[];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = tx.amount.truncateToDouble() == tx.amount
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _titleController.text = tx.title;
      _type = tx.type;
      if (_categories.contains(tx.category)) _category = tx.category;
      if (_accounts.contains(tx.account)) _account = tx.account;
      _date = tx.date;
      _isRecurring = tx.isRecurring;
      if (tx.notes != null) _notesController.text = tx.notes!;
    } else if (widget.initialData == null) {
      _drafts.addAll([
        NoteDraftBinding(_amountController, prefs, 'expense_amount'),
        NoteDraftBinding(_titleController, prefs, 'expense_title'),
        NoteDraftBinding(_notesController, prefs, 'expense_notes'),
      ]);
    }
    if (widget.transactionToEdit == null &&
        widget.initialData == null &&
        (_amountController.text.isNotEmpty ||
            _titleController.text.isNotEmpty)) {
      try {
        final metadata =
            jsonDecode(prefs.getString('ascent_expense_entry_draft_v1') ?? '{}')
                as Map<String, dynamic>;
        if (metadata['token'] is String && metadata['arguments'] is String) {
          _entryToken = metadata['token'];
          _submittedArguments = metadata['arguments'];
          final fields =
              jsonDecode(_submittedArguments!) as Map<String, dynamic>;
          _date = DateTime.tryParse(fields['date']?.toString() ?? '') ?? _date;
          if (_categories.contains(fields['category'])) {
            _category = fields['category'];
          }
          if (_accounts.contains(fields['account'])) {
            _account = fields['account'];
          }
          if (fields['type'] == 'income') _type = 'income';
        }
      } catch (_) {}
    }
    if (widget.transactionToEdit == null && widget.initialData != null) {
      final data = widget.initialData!;
      if (data['amount'] != null) {
        _amountController.text = data['amount'].toString();
      }
      if (data['title'] != null) {
        _titleController.text = data['title'].toString();
      }
      if (data['category'] != null && _categories.contains(data['category'])) {
        _category = data['category'].toString();
      }
      if (data['account'] != null && _accounts.contains(data['account'])) {
        _account = data['account'].toString();
      }
    }
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String val) {
    // Quick smart detection from text if amount is empty
    if (_amountController.text.isEmpty) {
      final amountMatch = RegExp(
        r'(?:₹|rs\.?|inr)?\s*([0-9]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ).firstMatch(val);
      if (amountMatch != null) {
        final amt = amountMatch.group(1);
        if (amt != null) {
          _amountController.text = amt;
        }
      }
    }

    final lower = val.toLowerCase();
    if (lower.contains('tea') ||
        lower.contains('coffee') ||
        lower.contains('lunch') ||
        lower.contains('food') ||
        lower.contains('snack')) {
      setState(() => _category = 'Food & Groceries');
    } else if (lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('metro') ||
        lower.contains('petrol') ||
        lower.contains('cab')) {
      setState(() => _category = 'Transport');
    } else if (lower.contains('book') ||
        lower.contains('course') ||
        lower.contains('exam')) {
      setState(() => _category = 'Education');
    } else if (lower.contains('movie') ||
        lower.contains('game') ||
        lower.contains('hotstar')) {
      setState(() => _category = 'Entertainment');
    }
  }

  Future<void> _saveTransaction() async {
    if (_saving) return;
    final amtText = _amountController.text.trim();
    final amount = double.tryParse(amtText);
    if (amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _category
        : _titleController.text.trim();

    if (title.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use a description of 200 characters or fewer.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final noteParts = [
        if (_selectedIntent != null && _selectedIntent!.isNotEmpty) _selectedIntent!,
        if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
      ];
      final combinedNotes = noteParts.isEmpty ? null : noteParts.join(' · ');

      if (widget.transactionToEdit != null) {
        await ref.read(financeDaoProvider).updateTransaction(
          FinanceTransactionTableCompanion(
            id: drift.Value(widget.transactionToEdit!.id),
            title: drift.Value(title),
            amount: drift.Value(amount),
            date: drift.Value(_date),
            type: drift.Value(_type),
            category: drift.Value(_category),
            account: drift.Value(_account),
            notes: drift.Value(combinedNotes),
            isRecurring: drift.Value(_isRecurring),
          ),
        );
        try {
          await widget.onSaved?.call(widget.transactionToEdit!.id);
        } catch (_) {}
        if (mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated ₹${amount.toStringAsFixed(0)} for $title'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      final arguments = jsonEncode({
        'title': title,
        'amount': amount,
        'date': _date.toIso8601String(),
        'type': _type,
        'category': _category,
        'account': _account,
        'notes': combinedNotes,
        'isRecurring': _isRecurring,
      });
      if (_submittedArguments != null && _submittedArguments != arguments) {
        _entryToken = 'expense-entry:${DateTime.now().microsecondsSinceEpoch}';
      }
      final preferences = ref.read(sharedPreferencesProvider);
      if (!await preferences.setString(
        'ascent_expense_entry_draft_v1',
        jsonEncode({'token': _entryToken, 'arguments': arguments}),
      )) {
        throw StateError('Expense draft could not be protected');
      }
      _submittedArguments = arguments;
      final id = await ExpenseActions(ref.read(databaseProvider)).save(
        requestId: _entryToken,
        title: title,
        amount: amount,
        date: _date,
        type: _type,
        category: _category,
        account: _account,
        notes: combinedNotes,
        isRecurring: _isRecurring,
      );
      // The record is now committed. Draft/check-in failures must never report a failed expense.
      try {
        _amountController.clear();
        _titleController.clear();
        _notesController.clear();
        for (final draft in _drafts) {
          await draft.flush();
        }
        await preferences.remove('ascent_expense_entry_draft_v1');
      } catch (_) {
        /* The saved receipt prevents a repeated draft from writing twice. */
      }
      try {
        await widget.onSaved?.call(id);
      } catch (_) {
        /* The transaction itself is already saved. */
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ₹${amount.toStringAsFixed(0)} for $title'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Your expense draft is still here.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration field(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: context.recessedSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  widget.transactionToEdit != null ? 'Edit transaction' : 'Record transaction',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                );
                final close = IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                );
                if (MediaQuery.textScalerOf(context).scale(1) >= 1.45) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(alignment: Alignment.centerRight, child: close),
                      title,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    close,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            AscentSegmentedControl<int>(
              segments: const [
                AscentSegment(value: 0, label: 'Amount & note'),
                AscentSegment(value: 1, label: 'Details'),
              ],
              selected: _page,
              enabled: !_saving,
              accented: true,
              onChanged: (value) {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _page = value);
              },
            ),
            const SizedBox(height: 14),
            if (_page == 0) ...[
              AscentSegmentedControl<String>(
                segments: const [
                  AscentSegment(value: 'expense', label: 'Expense'),
                  AscentSegment(value: 'income', label: 'Income'),
                ],
                selected: _type,
                enabled: !_saving,
                accented: true,
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: field('Amount (₹)', hint: '0.00'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                enabled: !_saving,
                onChanged: _onTitleChanged,
                decoration: field(
                  'Description / Payee',
                  hint: 'What was it for?',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mindful Intent (Optional)',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Essential 🍞',
                  'Mindful Joy ☕',
                  'Investment 📚',
                  'Impulse 🛍️',
                ].map((intent) {
                  final selected = _selectedIntent == intent;
                  return ChoiceChip(
                    label: Text(
                      intent,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.white : context.textPrimary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: context.accentPrimary,
                    backgroundColor: context.recessedSurface,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    onSelected: _saving
                        ? null
                        : (val) {
                            setState(() {
                              _selectedIntent = val ? intent : null;
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                '$_category · $_account · ${DateFormat('MMM d').format(_date)}',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ] else ...[
              AscentSelectField<String>(
                label: 'Category',
                value: _category,
                options: [for (final v in _categories) AscentSelectOption(v, v)],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              AscentSelectField<String>(
                label: 'Account',
                value: _account,
                options: [for (final v in _accounts) AscentSelectOption(v, v)],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _account = value),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat('d MMM yyyy').format(_date)),
                  onPressed: _saving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (mounted && picked != null) {
                            setState(() => _date = picked);
                          }
                        },
                ),
              ),
              const SizedBox(height: 8),
              AscentSwitchRow(
                title: 'Recurring Subscription',
                helper: 'Mark as recurring bill',
                value: _isRecurring,
                onChanged: _saving
                    ? null
                    : (val) => setState(() => _isRecurring = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !_saving,
                decoration: field(
                  'Additional Notes',
                  hint: 'Tags, memo or details',
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                AscentButton.ghost(
                  label: 'Cancel',
                  compact: true,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
                AscentButton.tonal(
                  label: widget.transactionToEdit != null
                      ? 'Update Transaction'
                      : 'Save transaction',
                  compact: true,
                  loading: _saving,
                  onPressed: _saving ? null : _saveTransaction,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
