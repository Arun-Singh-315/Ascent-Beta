import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/actions/expense_actions.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/app_surfaces.dart';

enum LifeCheckInTab {
  hydration,
  money,
}

/// Unified, interactive Life Check-in Pop-up Dialog
/// Offers quick 1-tap logging for daily Hydration or quick Money transactions
/// with smooth glass aesthetics, curved corners, and zero clutter.
class LifeCheckInPopupDialog extends ConsumerStatefulWidget {
  final LifeCheckInTab initialTab;

  const LifeCheckInPopupDialog({
    super.key,
    this.initialTab = LifeCheckInTab.hydration,
  });

  static Future<void> show(
    BuildContext context, {
    LifeCheckInTab initialTab = LifeCheckInTab.hydration,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppPalette.black.withValues(alpha: 0.65),
      builder: (ctx) => LifeCheckInPopupDialog(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<LifeCheckInPopupDialog> createState() =>
      _LifeCheckInPopupDialogState();
}

class _LifeCheckInPopupDialogState
    extends ConsumerState<LifeCheckInPopupDialog> {
  late LifeCheckInTab _currentTab;

  // Hydration state
  final TextEditingController _waterCustomController = TextEditingController();
  bool _showCustomWaterInput = false;

  // Money state
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _moneyTitleController = TextEditingController();
  String _moneyType = 'expense';
  String _moneyCategory = 'Food & Groceries';
  bool _isSavingMoney = false;

  final List<String> _quickCategories = const [
    'Food & Groceries',
    'Transport',
    'Shopping',
    'Personal',
    'Bills & Utilities',
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  void dispose() {
    _waterCustomController.dispose();
    _amountController.dispose();
    _moneyTitleController.dispose();
    super.dispose();
  }

  Future<void> _logWater(int ml) async {
    if (ml <= 0) return;
    HapticFeedback.heavyImpact();
    await ref.read(waterDaoProvider).addWater(ml);

    if (!mounted) return;
    Navigator.of(context).pop();

    final g = context.glass;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.water_drop_rounded, color: g.clay, size: 20),
            const SizedBox(width: 8),
            Text(
              'Hydrated! Added +$ml mL to your daily log',
              style: AppTypeRoles.typeRole8,
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveMoney() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSavingMoney = true);
    final title = _moneyTitleController.text.trim().isEmpty
        ? _moneyCategory
        : _moneyTitleController.text.trim();

    try {
      final token = 'money-checkin:${DateTime.now().microsecondsSinceEpoch}';
      await ExpenseActions(ref.read(databaseProvider)).save(
        requestId: token,
        title: title,
        amount: amount,
        date: DateTime.now(),
        type: _moneyType,
        category: _moneyCategory,
        account: 'UPI',
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Logged ₹${amount.toStringAsFixed(0)} for $title',
                style: AppTypeRoles.typeRole8,
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingMoney = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save transaction. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isWater = _currentTab == LifeCheckInTab.hydration;

    return AppSurfaceBlur(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s20,
            vertical: AppSpace.s24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Material(
              color: AppPalette.transparent,
              child: AppCard(
                padding: const EdgeInsets.all(AppSpace.s20),
                nightDecoration: BoxDecoration(
                  color: context.bgSurface.withValues(
                    alpha: context.isDark ? 0.90 : 0.98,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: g.line,
                    width: AppBorderScale.w1point2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.black.withValues(
                        alpha: context.isDark ? 0.40 : 0.10,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Row with Emblem & Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isWater
                                  ? [
                                      const Color(0xFF38BDF8),
                                      const Color(0xFF0284C7)
                                    ]
                                  : [
                                      const Color(0xFF34D399),
                                      const Color(0xFF059669)
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isWater
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF059669))
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isWater
                                ? Icons.water_drop_rounded
                                : Icons.account_balance_wallet_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mindful Check-in',
                                style: AscentTextStyles.homeTitle.copyWith(
                                  fontSize: 18,
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWater
                                    ? 'Stay hydrated and refresh your focus.'
                                    : 'Log an expense or income quickly.',
                                style:
                                    AppTypography.plusJakartaSans125Regular65(
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          color: context.textMuted,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Segmented Pill Tab Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CheckInTabButton(
                              label: 'Hydration',
                              icon: Icons.water_drop_rounded,
                              isSelected: isWater,
                              activeColor: const Color(0xFF0284C7),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() =>
                                    _currentTab = LifeCheckInTab.hydration);
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _CheckInTabButton(
                              label: 'Money',
                              icon: Icons.currency_rupee_rounded,
                              isSelected: !isWater,
                              activeColor: const Color(0xFF059669),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() =>
                                    _currentTab = LifeCheckInTab.money);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Active Tab Content
                    if (isWater)
                      _buildHydrationContent(context, g)
                    else
                      _buildMoneyContent(context, g),

                    const SizedBox(height: 14),

                    // Maybe later button
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Maybe later',
                        style: AscentTextStyles.homeSecondary.copyWith(
                          color: context.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHydrationContent(BuildContext context, AscentGlass g) {
    final todayWaterAsync = ref.watch(todayWaterMlStreamProvider);
    final goalAsync = ref.watch(dailyWaterGoalStreamProvider);

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = goalAsync.value ?? 2500;
    final percent = ((currentMl / targetMl) * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress Pill
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s14,
            vertical: AppSpace.s8,
          ),
          nightDecoration: BoxDecoration(
            color: context.bgBase,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.divider.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currentMl / $targetMl mL',
                style: AppTypography.jetBrainsMono13W70066(
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s6,
                  vertical: AppSpace.s2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: context.isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick log buttons grid
        Row(
          children: [
            Expanded(
              child: _QuickWaterButton(
                amountMl: 150,
                label: 'Small Sip',
                icon: Icons.coffee_rounded,
                onTap: () => _logWater(150),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickWaterButton(
                amountMl: 250,
                label: 'Glass',
                icon: Icons.local_drink_rounded,
                onTap: () => _logWater(250),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _QuickWaterButton(
                amountMl: 350,
                label: 'Bottle',
                icon: Icons.emoji_food_beverage_rounded,
                onTap: () => _logWater(350),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickWaterButton(
                amountMl: 500,
                label: 'Sipper',
                icon: Icons.sports_bar_rounded,
                onTap: () => _logWater(500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Custom amount entry
        if (_showCustomWaterInput) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _waterCustomController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter mL (e.g. 300)',
                    hintStyle: TextStyle(color: context.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: context.bgBase,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.divider),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final ml = int.tryParse(_waterCustomController.text.trim());
                  if (ml != null && ml > 0) {
                    _logWater(ml);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showCustomWaterInput = true),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Custom mL', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoneyContent(BuildContext context, AscentGlass g) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type Selector: Expense / Income
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.bgBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTapArea(
                  onTap: () => setState(() => _moneyType = 'expense'),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _moneyType == 'expense'
                          ? const Color(0xFFEF4444)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Expense',
                      style: TextStyle(
                        color: _moneyType == 'expense'
                            ? Colors.white
                            : context.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AppTapArea(
                  onTap: () => setState(() => _moneyType = 'income'),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _moneyType == 'income'
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Income',
                      style: TextStyle(
                        color: _moneyType == 'income'
                            ? Colors.white
                            : context.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Amount Input Field
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.currency_rupee_rounded, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            hintText: 'Amount',
            hintStyle: TextStyle(
              color: context.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: context.bgBase,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.divider),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Optional Title / Note Input
        TextField(
          controller: _moneyTitleController,
          style: TextStyle(color: context.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Description (e.g. Lunch, Taxi, Salary)',
            hintStyle: TextStyle(color: context.textMuted, fontSize: 13),
            filled: true,
            fillColor: context.bgBase,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.divider),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick Category Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickCategories.map((cat) {
            final isSelected = _moneyCategory == cat;
            return AppTapArea(
              onTap: () => setState(() => _moneyCategory = cat),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF059669)
                      : context.bgBase,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : context.divider,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : context.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSavingMoney ? null : _saveMoney,
            icon: _isSavingMoney
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSavingMoney
                  ? 'Saving...'
                  : 'Save ${_moneyType == 'expense' ? 'Expense' : 'Income'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Link to full money manager
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/money');
            },
            child: Text(
              'Open full money manager ›',
              style: TextStyle(
                color: context.isDark
                    ? const Color(0xFF34D399)
                    : const Color(0xFF059669),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckInTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _CheckInTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapArea(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : context.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : context.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickWaterButton extends StatelessWidget {
  final int amountMl;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickWaterButton({
    required this.amountMl,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapArea(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: context.bgBase,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF0284C7)),
            const SizedBox(height: 6),
            Text(
              '+$amountMl mL',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
