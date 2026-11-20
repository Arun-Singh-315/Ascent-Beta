import 'package:flutter/material.dart';

import 'plan_collection_service.dart';

/// One dated thing in a generated plan, before it is saved.
@immutable
class GeneratedItem {
  const GeneratedItem({
    required this.at,
    required this.title,
    this.notes = '',
    this.minutes,
  });
  final DateTime at;
  final String title;
  final String notes;
  final int? minutes;

  PlanItemDraft toDraft() =>
      PlanItemDraft(title: title, notes: notes, at: at, minutes: minutes);
}

/// A plan Ascent made, ready to review and save.
@immutable
class GeneratedPlan {
  const GeneratedPlan({required this.title, required this.items});
  final String title;
  final List<GeneratedItem> items;
}

// Study -----------------------------------------------------------------------

/// Topic lists for subjects people often plan. Anything else gets a sensible
/// learning arc built from the subject's own name.
const _curricula = <String, List<String>>{
  'dsa': [
    'Arrays and two pointers',
    'Strings and hashing',
    'Sliding window',
    'Linked lists',
    'Stacks and queues',
    'Binary search',
    'Recursion and backtracking',
    'Trees and traversals',
    'Binary search trees',
    'Heaps and priority queues',
    'Graphs: BFS and DFS',
    'Shortest paths',
    'Greedy algorithms',
    'Dynamic programming: 1D',
    'Dynamic programming: 2D',
    'Tries and union-find',
  ],
  'python': [
    'Syntax, variables and types',
    'Conditions and loops',
    'Functions',
    'Lists, tuples and dicts',
    'Strings and files',
    'Modules and packages',
    'Classes and objects',
    'Errors and testing',
    'Comprehensions and generators',
    'Working with APIs',
    'Small project',
  ],
  'web': [
    'HTML structure',
    'CSS layout: flexbox and grid',
    'Responsive design',
    'JavaScript basics',
    'DOM and events',
    'Fetch and async',
    'A component framework',
    'State and routing',
    'Build and deploy',
    'Small project',
  ],
  'sql': [
    'SELECT and filtering',
    'Sorting and aggregates',
    'GROUP BY and HAVING',
    'Joins',
    'Subqueries and CTEs',
    'Window functions',
    'Indexes and query plans',
    'Schema design',
    'Practice set',
  ],
  'system design': [
    'Requirements and estimates',
    'Load balancing and caching',
    'Databases and sharding',
    'Queues and async work',
    'Consistency and availability',
    'Design a URL shortener',
    'Design a chat app',
    'Design a news feed',
    'Mock interview',
  ],
  'physics': [
    'Units and kinematics',
    'Laws of motion',
    'Work, energy and power',
    'Rotation',
    'Gravitation',
    'Thermodynamics',
    'Waves and oscillations',
    'Electrostatics',
    'Current electricity',
    'Magnetism',
    'Optics',
    'Modern physics',
  ],
  'chemistry': [
    'Mole concept',
    'Atomic structure',
    'Chemical bonding',
    'Thermodynamics',
    'Equilibrium',
    'Redox and electrochemistry',
    'Organic basics',
    'Hydrocarbons',
    'Coordination compounds',
    'Biomolecules',
  ],
  'biology': [
    'Cell structure',
    'Biomolecules',
    'Plant physiology',
    'Human digestion and breathing',
    'Circulation and excretion',
    'Neural control',
    'Reproduction',
    'Genetics',
    'Evolution',
    'Ecology',
  ],
  'maths': [
    'Sets and functions',
    'Trigonometry',
    'Quadratics and sequences',
    'Permutations and probability',
    'Coordinate geometry',
    'Limits and continuity',
    'Differentiation',
    'Integration',
    'Vectors and 3D',
    'Matrices',
  ],
  'upsc': [
    'Polity: Constitution basics',
    'Polity: Parliament and courts',
    'Modern history',
    'Geography: physical',
    'Geography: India',
    'Economy basics',
    'Environment',
    'Science and tech',
    'Current affairs review',
    'Answer writing practice',
  ],
};

String? _curriculumKey(String subject) {
  final s = subject.toLowerCase();
  if (RegExp(r'\b(dsa|data structure|algorithm|leetcode)').hasMatch(s)) {
    return 'dsa';
  }
  if (s.contains('python')) return 'python';
  if (RegExp(r'\b(web|html|css|javascript|js|react|frontend)\b').hasMatch(s)) {
    return 'web';
  }
  if (RegExp(r'\b(sql|database|mysql|postgres)').hasMatch(s)) return 'sql';
  if (s.contains('system design')) return 'system design';
  if (s.contains('physics')) return 'physics';
  if (s.contains('chem')) return 'chemistry';
  if (RegExp(r'\b(bio|biology|neet)\b').hasMatch(s)) return 'biology';
  if (RegExp(r'\b(math|maths|mathematics|jee)\b').hasMatch(s)) return 'maths';
  if (s.contains('upsc') || s.contains('civil services')) return 'upsc';
  return null;
}

List<String> _topicsFor(String subject) {
  final key = _curriculumKey(subject);
  if (key != null) return _curricula[key]!;
  final name = subject.trim().isEmpty ? 'the subject' : subject.trim();
  return [
    'Get an overview of $name',
    '$name: core ideas',
    '$name: key terms and rules',
    '$name: worked examples',
    '$name: practice set',
    '$name: harder problems',
    '$name: small project',
  ];
}

DateTime _at(DateTime day, TimeOfDay t) =>
    DateTime(day.year, day.month, day.day, t.hour, t.minute);

/// A study plan for [subject] over [days] days, at [time] for [minutes].
///
/// One new topic a day; every fourth day revises the last three; the last
/// day is a mock test. Starts today if [time] is still ahead, else tomorrow.
GeneratedPlan generateStudyPlan({
  required String subject,
  required int days,
  required int minutes,
  required TimeOfDay time,
  required DateTime now,
}) {
  final topics = _topicsFor(subject);
  var day = DateTime(now.year, now.month, now.day);
  if (!_at(day, time).isAfter(now)) day = day.add(const Duration(days: 1));
  final items = <GeneratedItem>[];
  final recent = <String>[];
  var next = 0;
  for (var i = 0; i < days; i++) {
    final date = day.add(Duration(days: i));
    final isLast = i == days - 1 && days >= 3;
    final isReview = !isLast && (i + 1) % 4 == 0 && recent.isNotEmpty;
    final String title;
    final String notes;
    if (isLast) {
      title = 'Mock test and review';
      notes = 'Timed practice across everything so far, then fix weak spots.';
    } else if (isReview) {
      title = 'Revise: ${recent.join(', ')}';
      notes = 'Redo one problem from each topic without notes.';
      recent.clear();
    } else {
      final topic = topics[next % topics.length];
      next++;
      recent.add(topic);
      title = topic;
      notes = 'Learn the idea, then 2–3 practice problems.';
    }
    items.add(
      GeneratedItem(
        at: _at(date, time),
        title: title,
        notes: notes,
        minutes: minutes,
      ),
    );
  }
  final name = subject.trim().isEmpty ? 'Study' : subject.trim();
  return GeneratedPlan(title: '$name in $days days', items: items);
}

// Meals -----------------------------------------------------------------------

enum MealGoal {
  balanced('Balanced'),
  protein('High protein'),
  veg('Vegetarian'),
  light('Weight loss');

  const MealGoal(this.label);
  final String label;
}

const _breakfast = <MealGoal, List<String>>{
  MealGoal.balanced: [
    'Poha with peanuts',
    'Vegetable upma',
    'Idli with sambar',
    'Oats with fruit',
    'Besan chilla',
    'Paratha with curd',
    'Dosa with chutney',
  ],
  MealGoal.protein: [
    'Egg bhurji with toast',
    'Paneer paratha with curd',
    'Moong dal chilla',
    'Greek yogurt with nuts',
    'Omelette with veggies',
    'Sprouts salad',
    'Peanut butter oats',
  ],
  MealGoal.veg: [
    'Poha with peanuts',
    'Idli with sambar',
    'Besan chilla',
    'Vegetable upma',
    'Oats with fruit',
    'Paneer sandwich',
    'Ragi dosa',
  ],
  MealGoal.light: [
    'Oats with berries',
    'Moong dal chilla',
    'Vegetable poha',
    'Sprouts salad',
    'Idli with sambar',
    'Fruit bowl with curd',
    'Vegetable dalia',
  ],
};

const _lunch = <MealGoal, List<String>>{
  MealGoal.balanced: [
    'Dal, rice and sabzi',
    'Rajma chawal with salad',
    'Roti, chana and raita',
    'Veg pulao with curd',
    'Chicken curry with roti',
    'Sambar rice and poriyal',
    'Khichdi with papad',
  ],
  MealGoal.protein: [
    'Chicken breast, rice and salad',
    'Paneer bhurji with roti',
    'Rajma with brown rice',
    'Fish curry with rice',
    'Egg curry with roti',
    'Chole with quinoa',
    'Soya chunks pulao',
  ],
  MealGoal.veg: [
    'Dal, rice and sabzi',
    'Rajma chawal',
    'Paneer butter masala with roti',
    'Chole with jeera rice',
    'Veg biryani with raita',
    'Sambar rice',
    'Kadhi chawal',
  ],
  MealGoal.light: [
    'Grilled paneer salad',
    'Dal and two rotis',
    'Vegetable soup and roti',
    'Quinoa khichdi',
    'Chicken salad bowl',
    'Moong dal with sabzi',
    'Curd rice with cucumber',
  ],
};

const _dinner = <MealGoal, List<String>>{
  MealGoal.balanced: [
    'Roti with mixed veg',
    'Vegetable khichdi',
    'Dosa with sambar',
    'Dal tadka with roti',
    'Grilled chicken with veggies',
    'Paneer tikka with salad',
    'Vegetable soup and toast',
  ],
  MealGoal.protein: [
    'Grilled chicken with veggies',
    'Paneer tikka with salad',
    'Egg curry with roti',
    'Tofu stir-fry',
    'Dal with paneer cubes',
    'Fish tikka with salad',
    'Chickpea salad bowl',
  ],
  MealGoal.veg: [
    'Roti with mixed veg',
    'Palak paneer with roti',
    'Vegetable khichdi',
    'Dal makhani with roti',
    'Masala dosa',
    'Tofu stir-fry',
    'Vegetable soup and toast',
  ],
  MealGoal.light: [
    'Clear vegetable soup',
    'Grilled fish with salad',
    'Moong dal khichdi',
    'Paneer and veggie stir-fry',
    'Tomato soup and salad',
    'Lauki sabzi with roti',
    'Sprouts chaat',
  ],
};

/// A meal plan of [days] days for [goal]: breakfast 8:30, lunch 13:30,
/// dinner 20:00, dishes rotating so none repeats within a week. Meals whose
/// time has passed today start tomorrow.
GeneratedPlan generateMealPlan({
  required MealGoal goal,
  required int days,
  required DateTime now,
}) {
  final slots = [
    ('Breakfast', const TimeOfDay(hour: 8, minute: 30), _breakfast[goal]!),
    ('Lunch', const TimeOfDay(hour: 13, minute: 30), _lunch[goal]!),
    ('Dinner', const TimeOfDay(hour: 20, minute: 0), _dinner[goal]!),
  ];
  final start = DateTime(now.year, now.month, now.day);
  final items = <GeneratedItem>[];
  for (var i = 0; i < days; i++) {
    final date = start.add(Duration(days: i));
    for (final (slot, time, dishes) in slots) {
      final at = _at(date, time);
      if (!at.isAfter(now)) continue;
      items.add(
        GeneratedItem(
          at: at,
          title: '$slot · ${dishes[i % dishes.length]}',
          notes: '${goal.label} plan',
        ),
      );
    }
  }
  return GeneratedPlan(
    title: '${goal.label} meals for $days days',
    items: items,
  );
}
