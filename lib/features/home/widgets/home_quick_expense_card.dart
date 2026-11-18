import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/home_design.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../money/add_transaction_sheet.dart';
import 'home_outline_surface.dart';

/// One-tap expense entry that also answers "how am I doing today?" at a glance.
///
/// Shows today's spend and, when a monthly budget exists, what is left of
/// today's safe pace. Without a budget it stays a calm, single-line prompt.
class HomeQuickExpenseCard extends ConsumerStatefulWidget {
  const HomeQuickExpenseCard({super.key});

  @override
  ConsumerState<HomeQuickExpenseCard> createState() =>
      _HomeQuickExpenseCardState();
}

class _HomeQuickExpenseCardState extends ConsumerState<HomeQuickExpenseCard> {
  bool _pressed = false;

  static final _inr = NumberFormat.decimalPattern('en_IN');
  static String _money(double v) => '₹${_inr.format(v.round())}';

  void _open() {
    HapticFeedback.selectionClick();
    AddTransactionSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final today = ref.watch(todaySpendingStreamProvider).value ?? 0;
    final monthSpend = ref.watch(currentMonthSpendingStreamProvider).value ?? 0;
    final budget = ref.watch(overallBudgetStreamProvider).value;

    // Same pace rule as the Money screen: what is left this month, spread
    // evenly over the days that remain (today included).
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (daysInMonth - now.day + 1).clamp(1, 31);
    final hasBudget = budget != null && budget.monthlyLimit > 0;
    final safeDaily = hasBudget
        ? ((budget.monthlyLimit - monthSpend).clamp(0, double.infinity) /
              daysLeft)
        : 0.0;
    final onPace = !hasBudget || today <= safeDaily;

    final String headline = today > 0 ? _money(today) : 'Log an expense';
    final String support;
    if (!hasBudget) {
      support = today > 0 ? 'Spent today' : 'Takes five seconds';
    } else if (onPace) {
      support = '${_money(safeDaily - today)} left today';
    } else {
      support = '${_money(today - safeDaily)} over today’s pace';
    }

    return Semantics(
      button: true,
      label: '$headline. $support. Add expense',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _open,
          child: AnimatedScale(
            scale: _pressed && !reduceMotion ? 0.97 : 1,
            duration: Duration(milliseconds: reduceMotion ? 0 : 120),
            curve: Curves.easeOutCubic,
            child: HomeOutlineSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: ShapeDecoration(
                      color: design.learningTint,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 22,
                      color: design.learningInk,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AscentTextStyles.interfaceTitle.copyWith(
                            color: design.primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          support,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HomeType.supporting.copyWith(
                            color: onPace
                                ? design.secondaryText
                                : design.learningInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: design.groupedFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: design.separator),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: design.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
