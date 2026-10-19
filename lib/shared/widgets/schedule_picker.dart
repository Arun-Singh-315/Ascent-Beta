import 'package:flutter/material.dart';

/// Collect both required fields before callers enable any scheduling option.
/// Cancellation and invalid times leave the caller's previous state untouched.
Future<DateTime?> pickFutureSchedule(
  BuildContext context, {
  required String purpose,
  DateTime? initial,
  ValueChanged<String>? onInvalid,
}) async {
  FocusScope.of(context).unfocus();
  final now = DateTime.now();
  final suggested = initial ?? now.add(const Duration(minutes: 30));
  final today = DateTime(now.year, now.month, now.day);
  final initialDay = DateTime(suggested.year, suggested.month, suggested.day);
  final day = await showDatePicker(
    context: context,
    helpText: '$purpose date',
    initialDate: initialDay.isBefore(today) ? today : initialDay,
    firstDate: today,
    lastDate: initialDay.isAfter(DateTime(now.year + 3, 12, 31))
        ? initialDay
        : DateTime(now.year + 3, 12, 31),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    helpText: '$purpose time',
    initialTime: TimeOfDay.fromDateTime(suggested),
  );
  if (time == null || !context.mounted) return null;
  final value = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  if (!value.isAfter(DateTime.now())) {
    const message =
        'That time has passed. Choose a later time or another date.';
    if (onInvalid != null) {
      onInvalid(message);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    }
    return null;
  }
  return value;
}
