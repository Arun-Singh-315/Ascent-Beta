import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import 'promise_reflection_sheet.dart';
import 'promise_session_sheet.dart';

/// Every entry point executes the same operation and reports persistence errors.
class PromiseActions {
  static final Set<int> _busy = {};
  static Future<void> perform(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise,
  ) async {
    if (!_busy.add(promise.id)) return;
    try {
      if (promise.trackingType == PromiseTrackingType.duration) {
        await PromiseSessionSheet.show(context, promise);
        return;
      }
      if (promise.trackingType == PromiseTrackingType.reflection) {
        await PromiseReflectionSheet.show(context, promise);
        return;
      }
      final repo = ref.read(promiseRepositoryProvider);
      if (promise.trackingType == PromiseTrackingType.milestone) {
        final controller = TextEditingController();
        double? amount;
        try {
          amount = await showDialog<double>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add progress'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: promise.unit.isEmpty ? 'Amount' : promise.unit,
                ),
                onSubmitted: (text) {
                  final value = double.tryParse(text);
                  if (value != null && value > 0) Navigator.pop(ctx, value);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final value = double.tryParse(controller.text);
                    if (value != null && value > 0) Navigator.pop(ctx, value);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        } finally {
          controller.dispose();
        }
        if (amount == null) return;
        await repo.recordProgress(
          promiseId: promise.id,
          eventType: PromiseEventType.milestoneAdvance,
          amount: amount,
        );
      } else {
        await repo.markDayDone(promise.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Progress saved.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ArgumentError || error is StateError
                  ? error.toString().replaceFirst(
                      RegExp(r'^(Invalid argument\(s\)|Bad state):\s*'),
                      '',
                    )
                  : 'Could not save progress. Please try again.',
            ),
          ),
        );
      }
    } finally {
      _busy.remove(promise.id);
    }
  }
}
