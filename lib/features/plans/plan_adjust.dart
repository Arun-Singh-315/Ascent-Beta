import '../../core/services/plan_collection_service.dart';

/// The next time a repeating step happens after [now], keeping its time of
/// day (and skipping weekends for weekday steps).
DateTime nextStart(PlanItemView item, DateTime now) {
  final at = item.at ?? now;
  if (at.isAfter(now)) return at;
  var day = DateTime(now.year, now.month, now.day);
  for (var i = 0; i < 8; i++) {
    final t = DateTime(day.year, day.month, day.day, at.hour, at.minute);
    final ok = item.recurrence != 'weekdays' || t.weekday <= DateTime.friday;
    if (ok && t.isAfter(now)) return t;
    day = day.add(const Duration(days: 1));
  }
  return day;
}

PlanItemDraft _draft(
  PlanItemView item,
  DateTime now, {
  String? recurrence,
  DateTime? endDate,
  int? minutes,
  bool keepMinutes = true,
}) {
  final start = nextStart(item, now);
  var end = endDate ?? item.endDate ?? start;
  final cap = DateTime(
    start.year,
    start.month,
    start.day,
  ).add(const Duration(days: 89));
  if (end.isAfter(cap)) end = cap;
  final startDay = DateTime(start.year, start.month, start.day);
  if (end.isBefore(startDay)) end = startDay;
  return PlanItemDraft(
    title: item.title,
    notes: item.notes,
    at: start,
    alert: item.alert,
    recurrence: recurrence ?? item.recurrence,
    endDate: end,
    minutes: keepMinutes ? (minutes ?? item.minutes) : minutes,
  );
}

/// A plan change ready to apply, plus what Undo needs.
class PlanAdjustment {
  const PlanAdjustment(this.drafts, this.undo, this.items);
  final List<PlanItemDraft> drafts;
  final List<PlanItemDraft> undo;
  final List<PlanItemView> items;
  bool get isEmpty => items.isEmpty;
}

/// Lighter: daily steps become weekdays, timed steps about a quarter
/// shorter (never under 10 minutes). Steps already light are left alone.
PlanAdjustment lighter(List<PlanItemView> all, DateTime now) {
  final items = <PlanItemView>[];
  final drafts = <PlanItemDraft>[];
  final undo = <PlanItemDraft>[];
  for (final i in all.where((i) => i.recurring && i.definitionId != null)) {
    final shorter = i.minutes == null || i.minutes! <= 10
        ? i.minutes
        : ((i.minutes! * .75 / 5).round() * 5).clamp(10, i.minutes!);
    final rule = i.recurrence == 'daily' ? 'weekdays' : i.recurrence;
    if (rule == i.recurrence && shorter == i.minutes) continue;
    items.add(i);
    drafts.add(_draft(i, now, recurrence: rule, minutes: shorter));
    undo.add(_draft(i, now));
  }
  return PlanAdjustment(drafts, undo, items);
}

/// Extend: every repeating step runs [days] more days (within 90 days).
PlanAdjustment extend(List<PlanItemView> all, DateTime now, {int days = 7}) {
  final items = <PlanItemView>[];
  final drafts = <PlanItemDraft>[];
  final undo = <PlanItemDraft>[];
  for (final i in all.where(
    (i) => i.recurring && i.definitionId != null && i.endDate != null,
  )) {
    final longer = i.endDate!.add(Duration(days: days));
    final d = _draft(i, now, endDate: longer);
    if (!d.endDate!.isAfter(i.endDate!)) continue;
    items.add(i);
    drafts.add(d);
    undo.add(_draft(i, now));
  }
  return PlanAdjustment(drafts, undo, items);
}

/// Applies [a], then returns a function that undoes it (re-reading the
/// items, since each update replaces the item's schedule).
Future<Future<void> Function()> applyAdjustment(
  PlanCollectionService service,
  String collectionId,
  PlanAdjustment a,
) async {
  await service.updateItems(a.items, a.drafts);
  final ids = [for (final i in a.items) i.id];
  return () async {
    final fresh = await service.watchItems(collectionId).first;
    final byId = {for (final i in fresh) i.id: i};
    final current = [for (final id in ids) byId[id]!];
    await service.updateItems(current, a.undo);
  };
}
