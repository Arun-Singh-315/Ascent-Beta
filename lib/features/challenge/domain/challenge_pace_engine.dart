import 'dart:math' as math;

enum ChallengePaceStatus { ahead, onTrack, atRisk, failed, complete }

class ChallengeEvidence {
  const ChallengeEvidence({
    required this.day,
    required this.amount,
    this.trust = 1,
  });

  final DateTime day;
  final double amount;
  final double trust;
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.percent,
    required this.chance,
    required this.completedAmount,
    required this.requiredPerDay,
    required this.daysLeft,
    required this.verifiedDays,
    required this.status,
  });

  final int percent;
  final int chance;
  final double completedAmount;
  final double requiredPerDay;
  final int daysLeft;
  final int verifiedDays;
  final ChallengePaceStatus status;
}

/// Deterministic pace calculation. It has no Flutter, Drift, or clock access.
class ChallengePaceEngine {
  const ChallengePaceEngine._();

  static ChallengeProgress calculate({
    required double targetTotal,
    required DateTime startDate,
    required DateTime endDate,
    required DateTime today,
    required List<ChallengeEvidence> evidence,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final localToday = DateTime(today.year, today.month, today.day);
    final totalDays = math.max(1, end.difference(start).inDays + 1).toInt();
    // Pace is measured against completed calendar days. Today remains available
    // for work until midnight, including on the deadline itself.
    final elapsedDays = localToday.isBefore(start)
        ? 0
        : math.min(totalDays, localToday.difference(start).inDays).toInt();
    final daysLeft = localToday.isAfter(end)
        ? 0
        : math.max(1, end.difference(localToday).inDays + 1).toInt();
    final progressEvents = evidence.where(
      (event) => !DateTime(
        event.day.year,
        event.day.month,
        event.day.day,
      ).isAfter(localToday),
    );
    final completedAmount = progressEvents.fold<double>(
      0,
      (sum, event) =>
          sum +
          math.max(0.0, event.amount).toDouble() *
              event.trust.clamp(0.0, 1.0).toDouble(),
    );
    final safeTarget = math.max(0.0, targetTotal);
    final percent = safeTarget == 0
        ? 100
        : ((completedAmount / safeTarget) * 100).round().clamp(0, 100).toInt();
    final remaining = math.max(0.0, safeTarget - completedAmount);
    final requiredPerDay = daysLeft == 0 ? remaining : remaining / daysLeft;
    final recentStart = localToday.subtract(const Duration(days: 6));
    final recentEvents = progressEvents.where((event) {
      final date = DateTime(event.day.year, event.day.month, event.day.day);
      return !date.isBefore(recentStart);
    }).toList();
    final dataDays = recentEvents
        .map(
          (event) => DateTime(event.day.year, event.day.month, event.day.day),
        )
        .toSet()
        .length;
    final planPerDay = safeTarget / totalDays;
    final capacityPerDay = dataDays >= 3
        ? recentEvents.fold<double>(
                0,
                (sum, event) =>
                    sum +
                    math.max(0.0, event.amount).toDouble() *
                        event.trust.clamp(0.0, 1.0).toDouble(),
              ) /
              7
        : planPerDay;
    final chance = remaining <= 0
        ? 100
        : daysLeft == 0
        ? 0
        : (100 /
                  (1 +
                      math.exp(
                        -6 * ((capacityPerDay * daysLeft / remaining) - 0.9),
                      )))
              .round()
              .clamp(1, 99)
              .toInt();
    final planned = safeTarget * elapsedDays / totalDays;
    final verifiedDays = progressEvents
        .where((event) => event.trust >= 1 && event.amount > 0)
        .map(
          (event) => DateTime(event.day.year, event.day.month, event.day.day),
        )
        .toSet()
        .length;

    final status = remaining <= 0
        ? ChallengePaceStatus.complete
        : localToday.isAfter(end)
        ? ChallengePaceStatus.failed
        : completedAmount >= planned * 1.05
        ? ChallengePaceStatus.ahead
        : completedAmount >= planned * 0.9
        ? ChallengePaceStatus.onTrack
        : ChallengePaceStatus.atRisk;

    return ChallengeProgress(
      percent: percent,
      chance: chance,
      completedAmount: completedAmount,
      requiredPerDay: requiredPerDay,
      daysLeft: daysLeft,
      verifiedDays: verifiedDays,
      status: status,
    );
  }
}

DateTime parseChallengeDay(String value) {
  final parts = value.split('-');
  if (parts.length != 3) throw FormatException('Invalid challenge day: $value');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String formatChallengeDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
