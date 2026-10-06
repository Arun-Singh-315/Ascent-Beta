import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/ai/ai_service.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';

/// Universal Omnibar for interacting with Riya from anywhere on the home screen.
/// Handles quick water and expense commands inline; routes everything else to
/// the full Riya chat screen.
class JarvisOmnibar extends ConsumerStatefulWidget {
  const JarvisOmnibar({super.key});

  @override
  ConsumerState<JarvisOmnibar> createState() => _JarvisOmnibarState();
}

class _JarvisOmnibarState extends ConsumerState<JarvisOmnibar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _controller.clear();
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();

    final engine = ref.read(aiEngineProvider) as LocalDeterministicAiEngine;
    final name = ref.read(assistantNameProvider);

    // 1. Quick water command — execute immediately without opening chat
    final water = engine.tryParseWater(query);
    if (water != null) {
      final ml = water['amountMl'] as int;
      await ref.read(waterDaoProvider).addWater(ml);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name: Logged +$ml mL water! 💧'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 2. Quick expense command — execute immediately without opening chat
    final expense = engine.tryParseExpense(query);
    if (expense != null) {
      final amt = (expense['amount'] as num).toDouble();
      final title = expense['title'] as String;
      final cat = expense['category'] as String;
      await ref.read(financeDaoProvider).insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: title,
          amount: amt,
          category: drift.Value(cat),
          account: const drift.Value('UPI'),
          date: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name: Saved expense ₹${amt.toStringAsFixed(0)} for $title! 💳'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 3. All other queries → full Riya chat screen
    if (mounted) {
      context.push('/ai-assistant');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(assistantNameProvider);
    final accentColor = const Color(0xFF4A90E2);

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.send,
        onSubmitted: _handleSubmitted,
        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Ask $name... "spent ₹40", "300ml water", "plan my day"',
          hintStyle: AscentTextStyles.bodySmall.copyWith(
            color: context.textMuted.withValues(alpha: 0.7),
            fontSize: 12.5,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 17),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: IconButton(
            icon: Icon(Icons.arrow_upward_rounded, size: 17, color: accentColor),
            onPressed: () => _handleSubmitted(_controller.text),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
