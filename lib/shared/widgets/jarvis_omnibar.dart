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

/// Universal Omnibar for interacting with JARVIS from anywhere
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

    // 1. Check if it's a quick water command
    final water = engine.tryParseWater(query);
    if (water != null) {
      final ml = water['amountMl'] as int;
      await ref.read(waterDaoProvider).addWater(ml);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JARVIS: Logged +$ml mL water! 💧'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 2. Check if it's a quick expense command
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
            content: Text('JARVIS: Saved expense ₹${amt.toStringAsFixed(0)} for $title! 💳'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 3. For tasks, general planning, or deep queries -> Route to AI Assistant
    context.push('/ai-assistant');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0096C7).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0096C7).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.send,
        onSubmitted: _handleSubmitted,
        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: 'Talk to JARVIS... "spent ₹40 chai", "300ml water", "plan day"',
          hintStyle: AscentTextStyles.bodySmall.copyWith(
            color: context.textMuted.withValues(alpha: 0.75),
            fontSize: 12.5,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF00B4D8), size: 18),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: Color(0xFF00B4D8)),
            onPressed: () => _handleSubmitted(_controller.text),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
