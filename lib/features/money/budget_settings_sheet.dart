import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';

class BudgetSettingsSheet extends ConsumerStatefulWidget {
  final FinanceBudget? currentBudget;

  const BudgetSettingsSheet({super.key, this.currentBudget});

  static Future<void> show(BuildContext context, {FinanceBudget? currentBudget}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BudgetSettingsSheet(currentBudget: currentBudget),
    );
  }

  @override
  ConsumerState<BudgetSettingsSheet> createState() => _BudgetSettingsSheetState();
}

class _BudgetSettingsSheetState extends ConsumerState<BudgetSettingsSheet> {
  final _monthlyController = TextEditingController();
  final _dailyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.currentBudget != null) {
      _monthlyController.text = widget.currentBudget!.monthlyLimit.toStringAsFixed(0);
      if (widget.currentBudget!.dailyLimit != null) {
        _dailyController.text = widget.currentBudget!.dailyLimit!.toStringAsFixed(0);
      }
    } else {
      _monthlyController.text = '15000';
      _dailyController.text = '500';
    }
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _dailyController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final monthly = double.tryParse(_monthlyController.text.trim());
    if (monthly == null || monthly <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid monthly budget')),
      );
      return;
    }

    final daily = double.tryParse(_dailyController.text.trim());

    await ref.read(financeDaoProvider).setOverallBudget(monthly, dailyLimit: daily);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget updated to ₹${monthly.toStringAsFixed(0)}/month'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
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
                'Spending Budget Limits',
                style: AscentTextStyles.displaySmall.copyWith(
                  color: context.textPrimary,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Keep your daily life expenses on track with sensible limits.',
            style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _monthlyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Overall Monthly Budget',
              prefixText: '₹ ',
              filled: true,
              fillColor: context.bgBase,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.divider),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _dailyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Daily Spending Target (Optional)',
              prefixText: '₹ ',
              filled: true,
              fillColor: context.bgBase,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.divider),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: AscentButton.outlined(
                  label: 'Cancel',
                  compact: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AscentButton.primary(
                  label: 'Save Limits',
                  compact: true,
                  onPressed: _saveBudget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
