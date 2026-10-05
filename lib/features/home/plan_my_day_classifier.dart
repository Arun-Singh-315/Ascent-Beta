class ParsedTaskItem {
  final String category;
  final int? estimatedMinutes;

  const ParsedTaskItem({
    required this.category,
    this.estimatedMinutes,
  });
}

class PlanMyDayClassifier {
  static ParsedTaskItem parse(String text) {
    final lower = text.toLowerCase();
    int? estimatedMinutes;

    // Parse duration like '45m', '2h', '1.5h'
    final mMatch = RegExp(r'(\d+)\s*m').firstMatch(lower);
    if (mMatch != null) {
      estimatedMinutes = int.tryParse(mMatch.group(1)!);
    } else {
      final hMatch = RegExp(r'([\d.]+)\s*h').firstMatch(lower);
      if (hMatch != null) {
        final hours = double.tryParse(hMatch.group(1)!);
        if (hours != null) {
          estimatedMinutes = (hours * 60).round();
        }
      }
    }

    String category = 'General';
    if (lower.contains('leetcode') ||
        lower.contains('dp') ||
        lower.contains('binary search') ||
        lower.contains('graph') ||
        lower.contains('neetcode') ||
        lower.contains('dsa')) {
      category = 'DSA';
    } else if (lower.contains('recruiter') ||
        lower.contains('apply') ||
        lower.contains('stripe') ||
        lower.contains('figma') ||
        lower.contains('interview') ||
        lower.contains('pipeline')) {
      category = 'Pipeline';
    } else if (lower.contains('walk') ||
        lower.contains('break') ||
        lower.contains('coffee') ||
        lower.contains('lunch')) {
      category = 'Break';
    } else if (lower.contains('read') ||
        lower.contains('designing') ||
        lower.contains('course') ||
        lower.contains('study') ||
        lower.contains('system design')) {
      category = 'Study';
    }

    return ParsedTaskItem(
      category: category,
      estimatedMinutes: estimatedMinutes,
    );
  }
}
