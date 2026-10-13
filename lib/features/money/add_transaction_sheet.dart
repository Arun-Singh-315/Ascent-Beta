import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/actions/expense_actions.dart';
import '../../core/services/note_draft_binding.dart';
import '../../shared/widgets/ascent_button.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final Future<void> Function(int)? onSaved;

  const AddTransactionSheet({super.key, this.initialData, this.onSaved});

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? initialData,
    Future<void> Function(int)? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) =>
          AddTransactionSheet(initialData: initialData, onSaved: onSaved),
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

  String _type = 'expense';
  String _category = 'Food & Groceries';
  String _account = 'UPI';
  DateTime _date = DateTime.now();

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
    if (widget.initialData == null) {
      _drafts.addAll([
        NoteDraftBinding(_amountController, prefs, 'expense_amount'),
        NoteDraftBinding(_titleController, prefs, 'expense_title'),
        NoteDraftBinding(_notesController, prefs, 'expense_notes'),
      ]);
    }
    if (widget.initialData == null &&
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
    if (widget.initialData != null) {
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
      final arguments = jsonEncode({
        'title': title,
        'amount': amount,
        'date': _date.toIso8601String(),
        'type': _type,
        'category': _category,
        'account': _account,
        'notes': _notesController.text.trim(),
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
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Transaction',
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: context.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Expense / Income Pill Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.bgBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _saving
                            ? null
                            : () => setState(() => _type = 'expense'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _type == 'expense'
                                ? context.accentSecondary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Expense',
                            style: TextStyle(
                              color: _type == 'expense'
                                  ? Colors.white
                                  : context.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _saving
                            ? null
                            : () => setState(() => _type = 'income'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _type == 'income'
                                ? context.accentPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Income',
                            style: TextStyle(
                              color: _type == 'income'
                                  ? Colors.white
                                  : context.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextField(
                enabled: !_saving,
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AscentTextStyles.displaySmall.copyWith(
                  color: context.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                autofocus: widget.initialData == null,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: AscentTextStyles.displaySmall.copyWith(
                    color: _type == 'expense'
                        ? context.accentSecondary
                        : context.accentPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: '0.00',
                  labelText: 'Amount',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Description / Title
              TextField(
                enabled: !_saving,
                controller: _titleController,
                onChanged: _onTitleChanged,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Description / Payee',
                  hintText: 'e.g. Swiggy lunch, Metro recharge, Books',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Category Chips
              Text(
                'Category',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) {
                  final isSelected = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: isSelected,
                    selectedColor: context.accentPrimary,
                    backgroundColor: context.bgBase,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : context.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? context.accentPrimary
                            : context.divider,
                      ),
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _category = c);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Account & Date Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _account,
                      dropdownColor: context.bgSurface,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Account',
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                      items: _accounts
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (val) => setState(() => _account = val ?? _account),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: context.divider),
                      ),
                      icon: Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: context.textPrimary,
                      ),
                      label: Text(
                        DateFormat('MMM d').format(_date),
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      label: 'Save Transaction',
                      compact: true,
                      onPressed: _saving ? null : _saveTransaction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
