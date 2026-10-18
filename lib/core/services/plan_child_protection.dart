/// Structured information explaining why a child entity (task or reminder)
/// is protected from independent hard deletion and which owner-aware actions are allowed.
class PlanChildRestriction {
  const PlanChildRestriction({
    required this.planId,
    required this.planTitle,
    this.occurrenceId,
    required this.targetType, // 'task', 'start_reminder', 'checkin_reminder'
    required this.isRoutine, // true if recurring routine, false if one-time managed plan
    required this.allowedActions, // e.g. ['skip_session', 'open_routine'], ['turn_off_reminder', 'open_routine'], etc.
    this.occurrenceDate,
  });

  final String planId;
  final String planTitle;
  final String? occurrenceId;
  final String targetType;
  final bool isRoutine;
  final List<String> allowedActions;
  final String? occurrenceDate;

  String get summary => 'Part of $planTitle';
}

/// Thrown when an un-scoped direct deletion is attempted on a plan-protected entity.
class PlanChildProtectionException implements Exception {
  const PlanChildProtectionException(this.restriction);
  final PlanChildRestriction restriction;

  @override
  String toString() =>
      'Protected entity: cannot directly delete ${restriction.targetType} belonging to "${restriction.planTitle}". Use owner-aware operations (${restriction.allowedActions.join(', ')}).';
}
