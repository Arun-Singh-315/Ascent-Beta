/// Offline knowledge that makes adding a medicine quick: common medicines,
/// homeopathic and ayurvedic remedies and supplements with their usual
/// strength, form, amount, timing and purpose, and a parser for sentences
/// like "Dolo 650 twice a day after food for 5 days", "Arnica 30C 4 pills
/// thrice daily" or "Vitamin D3 60k once a week".
///
/// Defaults reflect common use only. The add sheet always says to follow
/// the prescription, and every value stays editable.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;

/// The system of medicine. Each has its own forms, usual amount and a
/// one-line tip, so the add sheet only shows what makes sense.
enum MedicineSystem {
  allopathy(
    'Medicine',
    Icons.medication_outlined,
    ['tablet', 'capsule', 'syrup', 'drops', 'injection', 'inhaler', 'cream'],
    FoodTiming.after,
    'Follow your doctor’s prescription.',
  ),
  homeopathy(
    'Homeopathic',
    Icons.grain_rounded,
    ['globules', 'dilution', 'mother tincture', 'biochemic', 'tablet'],
    FoodTiming.apart,
    'Take 15 min away from food. Avoid coffee and mint near a dose.',
  ),
  ayurveda(
    'Ayurvedic',
    Icons.spa_outlined,
    ['tablet', 'churna', 'syrup', 'kadha', 'capsule', 'oil'],
    FoodTiming.after,
    'Usually with warm water after meals, or as your vaidya advises.',
  ),
  supplement(
    'Supplement',
    Icons.eco_outlined,
    ['capsule', 'tablet', 'powder', 'gummy', 'sachet', 'drops'],
    FoodTiming.withFood,
    'Most supplements absorb best with a meal.',
  );

  const MedicineSystem(this.label, this.icon, this.forms, this.food, this.tip);
  final String label;
  final IconData icon;
  final List<String> forms;
  final FoodTiming food;
  final String tip;

  static MedicineSystem from(String? name) => MedicineSystem.values.firstWhere(
    (s) => s.name == name,
    orElse: () => MedicineSystem.allopathy,
  );
}

/// Every form any system allows (for validation).
final allMedicineForms = {for (final s in MedicineSystem.values) ...s.forms};

/// Usual amount per dose for a form, shown as an editable default.
String defaultAmountFor(String form) => switch (form) {
  'globules' => '4 pills',
  'dilution' => '5 drops in water',
  'mother tincture' => '10 drops in water',
  'biochemic' => '4 tablets',
  'churna' || 'powder' => '1 tsp',
  'syrup' || 'kadha' => '10 ml',
  'drops' => '2 drops',
  'inhaler' => '2 puffs',
  'sachet' => '1 sachet',
  'gummy' => '1 gummy',
  'oil' || 'cream' => 'Apply',
  _ => '',
};

enum DoseFrequency {
  once('Once a day', ['09:00']),
  twice('Twice a day', ['09:00', '21:00']),
  thrice('3 times a day', ['08:00', '14:00', '20:00']),
  bedtime('At bedtime', ['22:00']),
  morning('Every morning', ['08:00']),
  fourTimes('4 times a day', ['08:00', '12:00', '16:00', '20:00']),
  weekly('Once a week', ['09:00'], everyDays: 7);

  const DoseFrequency(this.label, this.times, {this.everyDays = 1});
  final String label;
  final List<String> times;

  /// 1 for daily schedules, 7 for weekly.
  final int everyDays;
}

enum FoodTiming {
  after('After food'),
  before('Before food'),
  withFood('With food'),
  empty('Empty stomach'),
  apart('Away from food'),
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
    this.system = MedicineSystem.allopathy,
    this.amount = '',
  });
  final String name;
  final String strength;

  /// One of [MedicineSystem.forms] for its system.
  final String form;
  final DoseFrequency frequency;
  final FoodTiming food;
  final String purpose;
  final List<String> aliases;

  /// Typical course length; 90 for long-term medicines.
  final int days;
  final MedicineSystem system;

  /// Usual amount per dose ("4 pills"), or empty to use the form default.
  final String amount;
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
    DoseFrequency.weekly,
    FoodTiming.withFood,
    'Vitamin D',
    aliases: ['uprise', 'calcirol', 'd3', '60k'],
    days: 56,
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    system: MedicineSystem.supplement,
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
    '',
    'inhaler',
    DoseFrequency.twice,
    FoodTiming.any,
    'Breathing',
    aliases: ['asthalin', 'ventolin'],
    amount: '2 puffs',
  ),
  // ── Supplements ───────────────────────────────────────────────────────────
  KnownMedicine(
    'Zinc',
    '50 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.withFood,
    'Immunity',
    days: 30,
    system: MedicineSystem.supplement,
  ),
  KnownMedicine(
    'Magnesium',
    '250 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.any,
    'Sleep and muscles',
    aliases: ['magnesium glycinate'],
    days: _long,
    system: MedicineSystem.supplement,
  ),
  KnownMedicine(
    'Vitamin C',
    '500 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.withFood,
    'Immunity',
    aliases: ['limcee', 'celin'],
    days: 30,
    system: MedicineSystem.supplement,
  ),
  KnownMedicine(
    'Biotin',
    '10 mg',
    'tablet',
    DoseFrequency.once,
    FoodTiming.withFood,
    'Hair and nails',
    days: 90,
    system: MedicineSystem.supplement,
  ),
  KnownMedicine(
    'Whey protein',
    '30 g',
    'powder',
    DoseFrequency.once,
    FoodTiming.any,
    'Protein',
    aliases: ['protein', 'whey'],
    days: _long,
    system: MedicineSystem.supplement,
    amount: '1 scoop',
  ),
  KnownMedicine(
    'Creatine',
    '5 g',
    'powder',
    DoseFrequency.once,
    FoodTiming.any,
    'Strength',
    days: _long,
    system: MedicineSystem.supplement,
    amount: '1 scoop',
  ),
  KnownMedicine(
    'Electrolytes',
    '',
    'sachet',
    DoseFrequency.once,
    FoodTiming.any,
    'Hydration',
    aliases: ['ors', 'electral'],
    days: 3,
    system: MedicineSystem.supplement,
  ),

  // ── Homeopathic ───────────────────────────────────────────────────────────
  KnownMedicine(
    'Arnica Montana',
    '30C',
    'globules',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Bruises and soreness',
    aliases: ['arnica'],
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Nux Vomica',
    '30C',
    'globules',
    DoseFrequency.bedtime,
    FoodTiming.apart,
    'Acidity and indigestion',
    aliases: ['nux'],
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Belladonna',
    '30C',
    'globules',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Fever and throbbing pain',
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Arsenicum Album',
    '30C',
    'globules',
    DoseFrequency.twice,
    FoodTiming.apart,
    'Cold and loose motions',
    aliases: ['arsenic album', 'ars alb'],
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Rhus Tox',
    '30C',
    'globules',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Joint and muscle stiffness',
    aliases: ['rhus toxicodendron'],
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Bryonia',
    '30C',
    'globules',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Dry cough',
    aliases: ['bryonia alba'],
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Pulsatilla',
    '30C',
    'globules',
    DoseFrequency.twice,
    FoodTiming.apart,
    'Cold and congestion',
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Calcarea Phos',
    '6X',
    'biochemic',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Bones and teeth',
    aliases: ['calc phos'],
    days: 30,
    system: MedicineSystem.homeopathy,
  ),
  KnownMedicine(
    'Ferrum Phos',
    '6X',
    'biochemic',
    DoseFrequency.thrice,
    FoodTiming.apart,
    'Early fever and weakness',
    aliases: ['ferrum phosphoricum'],
    system: MedicineSystem.homeopathy,
  ),

  // ── Ayurvedic ─────────────────────────────────────────────────────────────
  KnownMedicine(
    'Ashwagandha',
    '500 mg',
    'tablet',
    DoseFrequency.bedtime,
    FoodTiming.after,
    'Stress and sleep',
    days: _long,
    system: MedicineSystem.ayurveda,
  ),
  KnownMedicine(
    'Triphala churna',
    '',
    'churna',
    DoseFrequency.bedtime,
    FoodTiming.after,
    'Digestion',
    aliases: ['triphala'],
    days: 30,
    system: MedicineSystem.ayurveda,
  ),
  KnownMedicine(
    'Chyawanprash',
    '',
    'churna',
    DoseFrequency.morning,
    FoodTiming.any,
    'Immunity',
    aliases: ['chyavanprash'],
    days: _long,
    system: MedicineSystem.ayurveda,
    amount: '1 tsp with warm milk',
  ),
  KnownMedicine(
    'Giloy',
    '500 mg',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Immunity and fever',
    aliases: ['guduchi', 'giloy ghanvati'],
    days: 30,
    system: MedicineSystem.ayurveda,
  ),
  KnownMedicine(
    'Liv.52',
    '',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Liver',
    aliases: ['liv 52', 'liv52'],
    days: 30,
    system: MedicineSystem.ayurveda,
    amount: '2 tablets',
  ),
  KnownMedicine(
    'Septilin',
    '',
    'tablet',
    DoseFrequency.twice,
    FoodTiming.after,
    'Immunity',
    days: 14,
    system: MedicineSystem.ayurveda,
    amount: '2 tablets',
  ),
  KnownMedicine(
    'Tulsi drops',
    '',
    'drops',
    DoseFrequency.twice,
    FoodTiming.any,
    'Cold and cough',
    aliases: ['tulsi'],
    days: 7,
    system: MedicineSystem.ayurveda,
    amount: '2 drops in water',
  ),
  KnownMedicine(
    'Kadha',
    '',
    'kadha',
    DoseFrequency.twice,
    FoodTiming.any,
    'Cold and immunity',
    days: 7,
    system: MedicineSystem.ayurveda,
    amount: '1 cup',
  ),
];

/// Up to [limit] well-known entries for [system], for one-tap starters.
List<KnownMedicine> popularFor(MedicineSystem system, {int limit = 6}) =>
    knownMedicines.where((m) => m.system == system).take(limit).toList();

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
    this.system = MedicineSystem.allopathy,
    this.amount = '',
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
  final MedicineSystem system;

  /// Amount per dose ("4 pills", "1 tsp"); empty means one unit of [form].
  final String amount;

  int get everyDays => frequency.everyDays;

  MedicineDraft copyWith({
    String? name,
    String? strength,
    String? form,
    DoseFrequency? frequency,
    FoodTiming? food,
    int? days,
    String? purpose,
    MedicineSystem? system,
    String? amount,
  }) => MedicineDraft(
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    frequency: frequency ?? this.frequency,
    food: food ?? this.food,
    days: days ?? this.days,
    purpose: purpose ?? this.purpose,
    known: known,
    system: system ?? this.system,
    amount: amount ?? this.amount,
  );

  /// Switches system, moving form, food and amount to that system's
  /// defaults when the current ones do not belong to it.
  MedicineDraft withSystem(MedicineSystem next) {
    final keepForm = next.forms.contains(form);
    final nextForm = keepForm ? form : next.forms.first;
    return copyWith(
      system: next,
      form: nextForm,
      food: next.food,
      amount: keepForm ? amount : defaultAmountFor(nextForm),
    );
  }

  /// Dosage text stored with the medicine: "650 mg tablet",
  /// "30C globules · 4 pills", "Churna · 1 tsp".
  String get dosage {
    final s = strength.trim();
    final a = amount.trim();
    final base = s.isEmpty
        ? (a.isEmpty
              ? '1 $form'
              : '${form[0].toUpperCase()}${form.substring(1)}')
        : '$s $form';
    return a.isEmpty ? base : '$base · $a';
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
    system: m.system,
    amount: m.amount.isEmpty ? defaultAmountFor(m.form) : m.amount,
  );
}

/// Reads a sentence such as "Dolo 650 twice a day after food for 5 days",
/// "Pan 40 before breakfast 14 days" or "Arnica 30C 4 pills thrice daily".
/// Anything not said keeps the known medicine's default (or a sensible one).
/// [hint] is the system the person picked, used when the text names none.
MedicineDraft parseMedicineText(String text, {MedicineSystem? hint}) {
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

  // System words, when the medicine is not a known one.
  if (known == null) {
    final MedicineSystem? system =
        RegExp(
              r' (homeo|homeopathic|homoeopathic|globules|dilution|mother tincture|biochemic) ',
            ).hasMatch(lower) ||
            RegExp(r' \d{1,4} ?(c|ch|m) ').hasMatch(lower)
        ? MedicineSystem.homeopathy
        : RegExp(
            r' (ayurvedic|ayurveda|churna|kadha|vati|arishta|asava|ghanvati|bhasma) ',
          ).hasMatch(lower)
        ? MedicineSystem.ayurveda
        : RegExp(
            r' (vitamin|supplement|omega|protein|zinc|magnesium|biotin|collagen|gummy|gummies) ',
          ).hasMatch(lower)
        ? MedicineSystem.supplement
        : null;
    final chosen = system ?? hint;
    if (chosen != null && chosen != draft.system) {
      draft = draft.withSystem(chosen);
    }
  }

  // Homeopathic potency: 6X, 30C, 200CH, 1M, Q (mother tincture).
  final potency = RegExp(
    r'\b(\d{1,4})\s?(c|ch|x|m)\b(?!\s*(?:a day|daily|per day|times))|\b(q)\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (potency != null && draft.system == MedicineSystem.homeopathy) {
    draft = draft.copyWith(
      strength: potency.group(3) != null
          ? 'Q'
          : '${potency.group(1)}${potency.group(2)!.toUpperCase()}',
    );
  }

  // Amount per dose: "4 pills", "5 drops", "1 tsp", "2 tablets", "1 scoop".
  final amount = RegExp(
    r'\b(\d{1,2}|half|one|two)\s*(pills?|globules?|drops?|tsp|teaspoons?|tbsp|scoops?|tablets?|tabs?|capsules?|puffs?|sachets?|gumm(?:y|ies)|ml)\b(?!\s*(?:a|per|each)?\s*day)',
    caseSensitive: false,
  ).firstMatch(text);
  if (amount != null &&
      !(amount.group(2)!.toLowerCase() == 'ml' && draft.form != 'syrup')) {
    draft = draft.copyWith(amount: amount.group(0)!.toLowerCase());
  }

  final strength = RegExp(
    r'(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g|iu|units?)\b',
    caseSensitive: false,
  ).firstMatch(text);
  if (strength != null) {
    draft = draft.copyWith(
      strength: '${strength.group(1)} ${strength.group(2)!.toLowerCase()}',
    );
  }

  // Forms, most specific first. A form only applies when it belongs to the
  // medicine's system ("pills" are globules in homeopathy, tablets else).
  for (final (form, words) in const [
    ('mother tincture', ['mother tincture']),
    ('globules', ['globules', 'globule', 'pills', 'pill']),
    ('dilution', ['dilution', 'drops', 'drop']),
    ('biochemic', ['biochemic']),
    ('churna', ['churna']),
    ('kadha', ['kadha', 'decoction']),
    ('powder', ['powder', 'scoop', 'scoops']),
    ('gummy', ['gummy', 'gummies']),
    ('sachet', ['sachet', 'sachets']),
    ('inhaler', ['inhaler', 'puff', 'puffs']),
    ('cream', ['cream', 'ointment', 'gel']),
    ('oil', ['oil']),
    ('syrup', ['syrup', 'liquid', 'suspension']),
    ('capsule', ['capsule', 'capsules', 'cap']),
    ('drops', ['drop', 'drops']),
    ('injection', ['injection', 'shot', 'insulin']),
    ('tablet', ['tablet', 'tablets', 'tab', 'pill', 'pills']),
  ]) {
    if (!draft.system.forms.contains(form)) continue;
    if (words.any((w) => lower.contains(' $w '))) {
      draft = draft.copyWith(form: form);
      break;
    }
  }

  final DoseFrequency? freq =
      RegExp(
        r' (weekly|once a week|every week|once weekly|per week) ',
      ).hasMatch(lower)
      ? DoseFrequency.weekly
      : RegExp(r' (bedtime|at night|before sleep|hs) ').hasMatch(lower)
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

  final FoodTiming? food =
      RegExp(r' (away from food|apart from food) ').hasMatch(lower)
      ? FoodTiming.apart
      : RegExp(r' (empty stomach) ').hasMatch(lower)
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
