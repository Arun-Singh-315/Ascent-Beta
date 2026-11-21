/// Offline knowledge that makes adding a medicine quick: common medicines
/// with their usual strength, form, timing and purpose, and a parser for
/// sentences like "Dolo 650 twice a day after food for 5 days".
///
/// Defaults reflect common use only. The add sheet always says to follow
/// the prescription, and every value stays editable.
library;

enum DoseFrequency {
  once('Once a day', ['09:00']),
  twice('Twice a day', ['09:00', '21:00']),
  thrice('3 times a day', ['08:00', '14:00', '20:00']),
  bedtime('At bedtime', ['22:00']),
  morning('Every morning', ['08:00']),
  fourTimes('4 times a day', ['08:00', '12:00', '16:00', '20:00']);

  const DoseFrequency(this.label, this.times);
  final String label;
  final List<String> times;
}

enum FoodTiming {
  after('After food'),
  before('Before food'),
  withFood('With food'),
  empty('Empty stomach'),
  any('Any time');

  const FoodTiming(this.label);
  final String label;
}

class KnownMedicine {
  const KnownMedicine(
    this.name,
    this.strength,
    this.form,
    this.frequency,
    this.food,
    this.purpose, {
    this.aliases = const [],
    this.days = 5,
  });
  final String name;
  final String strength;

  /// tablet, capsule, syrup, drops or injection.
  final String form;
  final DoseFrequency frequency;
  final FoodTiming food;
  final String purpose;
  final List<String> aliases;

  /// Typical course length; 90 for long-term medicines.
  final int days;
}

const _long = 90;

/// Common medicines (India-friendly brand and generic names).
const knownMedicines = <KnownMedicine>[
  KnownMedicine(
    'Paracetamol',
    '500 mg',
    'tablet',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Fever and pain',
    aliases: ['crocin', 'calpol', 'pcm'],
  ),
  KnownMedicine(
    'Dolo 650',
    '650 mg',
    'tablet',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Fever and pain',
    aliases: ['dolo'],
  ),
  KnownMedicine(
    'Ibuprofen',
    '400 mg',
    'tablet',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Pain and swelling',
    aliases: ['brufen', 'combiflam'],
  ),
  KnownMedicine(
    'Cetirizine',
    '10 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Allergy',
    aliases: ['okacet', 'cetzine'],
  ),
  KnownMedicine(
    'Levocetirizine',
    '5 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Allergy',
    aliases: ['levocet', 'xyzal'],
  ),
  KnownMedicine(
    'Montelukast',
    '10 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Allergy and asthma',
    aliases: ['montair', 'montek'],
  ),
  KnownMedicine(
    'Azithromycin',
    '500 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.before,
    'Antibiotic',
    aliases: ['azithral', 'azee'],
    days: 3,
  ),
  KnownMedicine(
    'Amoxicillin',
    '500 mg',
    'capsule',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Antibiotic',
    aliases: ['mox', 'novamox'],
  ),
  KnownMedicine(
    'Amoxicillin + Clavulanate',
    '625 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Antibiotic',
    aliases: ['augmentin', 'clavam'],
  ),
  KnownMedicine(
    'Cefixime',
    '200 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Antibiotic',
    aliases: ['taxim-o', 'zifi'],
  ),
  KnownMedicine(
    'Ciprofloxacin',
    '500 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Antibiotic',
    aliases: ['ciplox', 'cifran'],
  ),
  KnownMedicine(
    'Metronidazole',
    '400 mg',
    'tablet',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Infection',
    aliases: ['flagyl', 'metrogyl'],
  ),
  KnownMedicine(
    'Pantoprazole',
    '40 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.empty,
    'Acidity',
    aliases: ['pan 40', 'pan', 'pantocid'],
    days: 14,
  ),
  KnownMedicine(
    'Omeprazole',
    '20 mg',
    'capsule',
    DoseFrequency.morning,
    FoodTiming.empty,
    'Acidity',
    aliases: ['omez'],
    days: 14,
  ),
  KnownMedicine(
    'Rabeprazole',
    '20 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.empty,
    'Acidity',
    aliases: ['razo', 'rablet'],
    days: 14,
  ),
  KnownMedicine(
    'Domperidone',
    '10 mg',
    'tablet',
    DoseFrequency.thrice,
    FoodTiming.before,
    'Nausea and bloating',
    aliases: ['domstal'],
  ),
  KnownMedicine(
    'Ondansetron',
    '4 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.any,
    'Nausea and vomiting',
    aliases: ['emeset', 'ondem'],
    days: 3,
  ),
  KnownMedicine(
    'ORS',
    '1 sachet',
    'syrup',
    DoseFrequency.fourTimes,
    FoodTiming.any,
    'Hydration',
    aliases: ['electral', 'oral rehydration'],
    days: 3,
  ),
  KnownMedicine(
    'Loperamide',
    '2 mg',
    'capsule',
    DoseFrequency.twice,
    FoodTiming.any,
    'Loose motions',
    aliases: ['eldoper', 'imodium'],
    days: 2,
  ),
  KnownMedicine(
    'Cough syrup',
    '10 ml',
    'syrup',
    DoseFrequency.thrice,
    FoodTiming.after,
    'Cough',
    aliases: ['benadryl', 'ascoril', 'grilinctus'],
  ),
  KnownMedicine(
    'Metformin',
    '500 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Blood sugar',
    aliases: ['glycomet', 'glyciphage'],
    days: _long,
  ),
  KnownMedicine(
    'Glimepiride',
    '1 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.before,
    'Blood sugar',
    aliases: ['amaryl'],
    days: _long,
  ),
  KnownMedicine(
    'Insulin',
    '10 units',
    'injection',
    DoseFrequency.twice,
    FoodTiming.before,
    'Blood sugar',
    days: _long,
  ),
  KnownMedicine(
    'Amlodipine',
    '5 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.any,
    'Blood pressure',
    aliases: ['amlong', 'stamlo'],
    days: _long,
  ),
  KnownMedicine(
    'Telmisartan',
    '40 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.any,
    'Blood pressure',
    aliases: ['telma'],
    days: _long,
  ),
  KnownMedicine(
    'Losartan',
    '50 mg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.any,
    'Blood pressure',
    aliases: ['losar'],
    days: _long,
  ),
  KnownMedicine(
    'Atorvastatin',
    '10 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Cholesterol',
    aliases: ['atorva', 'lipitor'],
    days: _long,
  ),
  KnownMedicine(
    'Rosuvastatin',
    '10 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Cholesterol',
    aliases: ['rosuvas', 'crestor'],
    days: _long,
  ),
  KnownMedicine(
    'Aspirin',
    '75 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'Heart protection',
    aliases: ['ecosprin'],
    days: _long,
  ),
  KnownMedicine(
    'Levothyroxine',
    '50 mcg',
    'tablet',
    DoseFrequency.morning,
    FoodTiming.empty,
    'Thyroid',
    aliases: ['thyronorm', 'eltroxin', 'thyroxine'],
    days: _long,
  ),
  KnownMedicine(
    'Vitamin D3',
    '60000 IU',
    'capsule',
    DoseFrequency.once,
    FoodTiming.after,
    'Vitamin D',
    aliases: ['uprise', 'calcirol', 'd3'],
    days: 8,
  ),
  KnownMedicine(
    'Vitamin B12',
    '1500 mcg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'Vitamin B12',
    aliases: ['methylcobalamin', 'mecobalamin', 'b12'],
    days: 30,
  ),
  KnownMedicine(
    'Multivitamin',
    '1 tablet',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'General health',
    aliases: ['becosules', 'supradyn', 'zincovit'],
    days: 30,
  ),
  KnownMedicine(
    'Iron',
    '100 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'Iron and haemoglobin',
    aliases: ['ferrous', 'livogen', 'orofer'],
    days: 30,
  ),
  KnownMedicine(
    'Folic acid',
    '5 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'Folic acid',
    aliases: ['folvite'],
    days: 30,
  ),
  KnownMedicine(
    'Calcium + D3',
    '500 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.after,
    'Bones',
    aliases: ['shelcal', 'calcium'],
    days: 30,
  ),
  KnownMedicine(
    'Omega-3',
    '1000 mg',
    'capsule',
    DoseFrequency.once,
    FoodTiming.after,
    'Heart and joints',
    aliases: ['fish oil'],
    days: 30,
  ),
  KnownMedicine(
    'Probiotic',
    '1 capsule',
    'capsule',
    DoseFrequency.once,
    FoodTiming.after,
    'Gut health',
    aliases: ['vizylac', 'econorm'],
    days: 7,
  ),
  KnownMedicine(
    'Eye drops',
    '1 drop',
    'drops',
    DoseFrequency.thrice,
    FoodTiming.any,
    'Eyes',
    aliases: ['refresh tears', 'moxifloxacin drops'],
  ),
  KnownMedicine(
    'Ear drops',
    '2 drops',
    'drops',
    DoseFrequency.twice,
    FoodTiming.any,
    'Ears',
  ),
  KnownMedicine(
    'Salbutamol inhaler',
    '2 puffs',
    'drops',
    DoseFrequency.twice,
    FoodTiming.any,
    'Breathing',
    aliases: ['asthalin', 'ventolin'],
  ),
];

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Up to [limit] known medicines whose name or alias starts with (or
/// contains) [query], best matches first.
List<KnownMedicine> searchKnownMedicines(String query, {int limit = 5}) {
  final q = _norm(query);
  if (q.length < 2) return const [];
  final starts = <KnownMedicine>[];
  final contains = <KnownMedicine>[];
  for (final m in knownMedicines) {
    final names = [_norm(m.name), ...m.aliases.map(_norm)];
    if (names.any((n) => n.startsWith(q) || q.startsWith(n))) {
      starts.add(m);
    } else if (names.any((n) => n.contains(q))) {
      contains.add(m);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// What the add sheet starts from. Every field is editable.
class MedicineDraft {
  const MedicineDraft({
    required this.name,
    this.strength = '',
    this.form = 'tablet',
    this.frequency = DoseFrequency.twice,
    this.food = FoodTiming.after,
    this.days = 5,
    this.purpose = '',
    this.known,
  });
  final String name;
  final String strength;
  final String form;
  final DoseFrequency frequency;
  final FoodTiming food;
  final int days;
  final String purpose;

  /// The catalog entry the defaults came from, if any.
  final KnownMedicine? known;

  MedicineDraft copyWith({
    String? name,
    String? strength,
    String? form,
    DoseFrequency? frequency,
    FoodTiming? food,
    int? days,
    String? purpose,
  }) => MedicineDraft(
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    frequency: frequency ?? this.frequency,
    food: food ?? this.food,
    days: days ?? this.days,
    purpose: purpose ?? this.purpose,
    known: known,
  );

  /// Dosage text stored with the medicine ("650 mg tablet").
  String get dosage {
    final s = strength.trim();
    return s.isEmpty ? '1 $form' : '$s $form';
  }

  static MedicineDraft fromKnown(KnownMedicine m) => MedicineDraft(
    name: m.name,
    strength: m.strength,
    form: m.form,
    frequency: m.frequency,
    food: m.food,
    days: m.days,
    purpose: m.purpose,
    known: m,
  );
}

/// Reads a sentence such as "Dolo 650 twice a day after food for 5 days"
/// or "Pan 40 before breakfast 14 days". Anything not said keeps the known
/// medicine's default (or a sensible one).
MedicineDraft parseMedicineText(String text) {
  final lower = ' ${_norm(text)} ';

  // Name: the known medicine mentioned, else the words before the first
  // number or schedule word.
  KnownMedicine? known;
  var bestLen = 0;
  for (final m in knownMedicines) {
    for (final n in [m.name, ...m.aliases].map(_norm)) {
      if (n.length > bestLen && lower.contains(' $n ')) {
        known = m;
        bestLen = n.length;
      }
    }
  }
  var draft = known == null
      ? MedicineDraft(name: _guessName(text))
      : MedicineDraft.fromKnown(known);

  final strength = RegExp(
    r'(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g|iu|units?)\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (strength != null) {
    draft = draft.copyWith(
      strength: '${strength.group(1)} ${strength.group(2)!.toLowerCase()}',
    );
  }

  for (final (form, words) in const [
    ('syrup', ['syrup', 'liquid', 'suspension']),
    ('capsule', ['capsule', 'cap']),
    ('drops', ['drop', 'drops', 'inhaler', 'puff', 'puffs']),
    ('injection', ['injection', 'shot', 'insulin']),
    ('tablet', ['tablet', 'tab', 'pill']),
  ]) {
    if (words.any((w) => lower.contains(' $w '))) {
      draft = draft.copyWith(form: form);
      break;
    }
  }

  final DoseFrequency? freq =
      RegExp(r' (bedtime|at night|before sleep|hs) ').hasMatch(lower)
      ? DoseFrequency.bedtime
      : RegExp(r' (four times|4 times|qid|every 6 hours) ').hasMatch(lower)
      ? DoseFrequency.fourTimes
      : RegExp(
          r' (thrice|three times|3 times|tds|tid|every 8 hours) ',
        ).hasMatch(lower)
      ? DoseFrequency.thrice
      : RegExp(
          r' (twice|two times|2 times|bd|bid|every 12 hours|morning and night) ',
        ).hasMatch(lower)
      ? DoseFrequency.twice
      : RegExp(
          r' (every morning|in the morning|before breakfast) ',
        ).hasMatch(lower)
      ? DoseFrequency.morning
      : RegExp(r' (once|daily|od|once a day) ').hasMatch(lower)
      ? DoseFrequency.once
      : null;
  if (freq != null) draft = draft.copyWith(frequency: freq);

  final FoodTiming? food = RegExp(r' (empty stomach) ').hasMatch(lower)
      ? FoodTiming.empty
      : RegExp(
          r' (before food|before meal|before meals|before breakfast) ',
        ).hasMatch(lower)
      ? FoodTiming.before
      : RegExp(r' (with food|with meal|with meals) ').hasMatch(lower)
      ? FoodTiming.withFood
      : RegExp(r' (after food|after meal|after meals) ').hasMatch(lower)
      ? FoodTiming.after
      : null;
  if (food != null) draft = draft.copyWith(food: food);

  final days = RegExp(
    r'(\d{1,3})\s*(day|days|week|weeks|month|months)\b',
  ).firstMatch(lower);
  if (days != null) {
    final n = int.parse(days.group(1)!);
    final unit = days.group(2)!;
    final total = unit.startsWith('week')
        ? n * 7
        : unit.startsWith('month')
        ? n * 30
        : n;
    draft = draft.copyWith(days: total.clamp(1, 366));
  }
  return draft;
}

String _guessName(String text) {
  final stop = RegExp(
    r'\b\d|\b(once|twice|thrice|daily|every|at|after|before|with|for|morning|night|bedtime|tablet|capsule|syrup|drops?)\b',
    caseSensitive: false,
  );
  final m = stop.firstMatch(text);
  final head = (m == null ? text : text.substring(0, m.start)).trim();
  if (head.isEmpty) return text.trim();
  return head[0].toUpperCase() + head.substring(1);
}
