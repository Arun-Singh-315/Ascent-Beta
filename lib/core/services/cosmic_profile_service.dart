import 'package:flutter/material.dart';

/// The classical four elements governing cosmic and temperament archetypes.
enum CosmicElement {
  fire('Fire', '🔥', 'High momentum, courageous action, and bold initiative'),
  earth('Earth', '🌱', 'Grounded stability, patient compounding, and deep focus'),
  air('Air', '💨', 'Intellectual agility, clear perspective, and creative synergy'),
  water('Water', '💧', 'Intuitive depth, emotional resilience, and quiet mastery');

  final String label;
  final String icon;
  final String energyDescription;

  const CosmicElement(this.label, this.icon, this.energyDescription);
}

/// Rich profile for a Western Zodiac sign and corresponding Vedic Rashi.
class ZodiacSignInfo {
  final String name;
  final String symbol;
  final String vedicRashi;
  final String vedicHindi;
  final CosmicElement element;
  final String archetype;
  final String traits;
  final String definingEssence;
  final List<String> dailySparks;

  const ZodiacSignInfo({
    required this.name,
    required this.symbol,
    required this.vedicRashi,
    required this.vedicHindi,
    required this.element,
    required this.archetype,
    required this.traits,
    required this.definingEssence,
    required this.dailySparks,
  });

  String get shortLabel => '$symbol $name · $vedicRashi';
  String get fullTitle => '$symbol $name · $vedicRashi ($vedicHindi)';
}

/// Day-of-the-week living atmospheric mood and subtle cosmic ruler.
/// Makes the app gently dynamic and living every single day without
/// jarring the user's primary theme.
class DailyLivingMood {
  final int weekday; // 1 = Mon ... 7 = Sun
  final String planetaryRuler;
  final String rulingTitle;
  final String themeVibe;
  final String shortMotto;
  final Color livingTint;

  const DailyLivingMood({
    required this.weekday,
    required this.planetaryRuler,
    required this.rulingTitle,
    required this.themeVibe,
    required this.shortMotto,
    required this.livingTint,
  });
}

/// Encapsulates today's personalized horoscope spark, zodiac alignment,
/// and living daily ambiance for the user.
class DailyCosmicInsight {
  final ZodiacSignInfo sign;
  final String quote;
  final DailyLivingMood livingMood;
  final bool isBirthday;
  final int? age;

  const DailyCosmicInsight({
    required this.sign,
    required this.quote,
    required this.livingMood,
    required this.isBirthday,
    this.age,
  });

  String get elementTag => '${sign.element.icon} ${sign.element.label}';
}

/// Service that computes zodiac signs, Vedic Rashis, day-to-day living atmospheres,
/// and personalized boosting quotes.
class CosmicProfileService {
  const CosmicProfileService();

  static const List<ZodiacSignInfo> signs = [
    ZodiacSignInfo(
      name: 'Aries',
      symbol: '♈',
      vedicRashi: 'Mesha',
      vedicHindi: 'मेष',
      element: CosmicElement.fire,
      archetype: 'The Trailblazer',
      traits: 'Courageous · Pioneering · High Momentum',
      definingEssence: 'Born to pioneer unpaved paths with fearless momentum.',
      dailySparks: [
        'Your natural fire thrives on momentum today. Attack your highest-friction task before midday.',
        'Action is your antidote to overthinking. Take the bold first step, the rhythm will follow.',
        'Channel your fiery ambition into laser precision. One focused hour beats a scattered day.',
        'Pioneer a new way through today’s hurdle. Your instincts are sharper than you realize.',
        'Lead yourself with boldness today. Great accomplishments start with quiet courage.',
        'Fuel your day with purposeful urgency. Turn restless energy into tangible output.',
        'Today calls for clear decisiveness. Trust your gut and move swiftly.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Taurus',
      symbol: '♉',
      vedicRashi: 'Vrishabha',
      vedicHindi: 'वृषभ',
      element: CosmicElement.earth,
      archetype: 'The Anchor',
      traits: 'Grounded · Resilient · Master Builder',
      definingEssence: 'Grounded in patient mastery, building enduring foundations.',
      dailySparks: [
        'Quiet patience is your superpower today. Lay one solid brick, and trust compounding.',
        'Stay rooted in your craft. Distractions fade when your foundation is unbreakable.',
        'Consistency beats intensity every single time. Keep your steady, beautiful stride.',
        'Savor the satisfaction of finishing what you started. Quality over rushing.',
        'Your calm composure stabilizes everything around you today. Breathe and execute.',
        'Build with intention today. The results you want are already taking shape.',
        'A grounded morning yields an unstoppable afternoon. Trust your rhythm.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Gemini',
      symbol: '♊',
      vedicRashi: 'Mithuna',
      vedicHindi: 'मिथुन',
      element: CosmicElement.air,
      archetype: 'The Catalyst',
      traits: 'Agile · Curious · Master Communicator',
      definingEssence: 'Curious intellect connecting ideas into brilliant breakthroughs.',
      dailySparks: [
        'Your mind is exceptionally nimble today. Capture your breakthrough ideas immediately.',
        'Curiosity is your compass today. Connect two distinct ideas into one game-changing insight.',
        'Fast thinking needs disciplined focus. Pick your single primary mission and conquer it.',
        'Your words hold extraordinary clarity today. Articulate your vision with confidence.',
        'Synthesize the noise into a simple, elegant plan. Mental agility is your gift.',
        'Learn something refreshing today; let small curiosities ignite big momentum.',
        'Stay versatile yet committed. You have the adaptability to handle anything today.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Cancer',
      symbol: '♋',
      vedicRashi: 'Karka',
      vedicHindi: 'कर्क',
      element: CosmicElement.water,
      archetype: 'The Guardian',
      traits: 'Intuitive · Deep · Protective Force',
      definingEssence: 'Intuitive depth and fierce devotion to what truly matters.',
      dailySparks: [
        'Your intuitive radar is exceptionally accurate today. Listen to the quiet signal.',
        'Protect your mental sanctuary fiercely today. Say no to anything draining your energy.',
        'Deep feeling fuels deep dedication. Pour your genuine care into what you build.',
        'Inner peace produces outer strength. Ground yourself in quiet gratitude this morning.',
        'Your resilience runs deep like the ocean. Move through challenges with calm grace.',
        'Create a warm, focused pocket of time for your top priority today.',
        'Trust your emotional intelligence today—it reveals what pure logic misses.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Leo',
      symbol: '♌',
      vedicRashi: 'Simha',
      vedicHindi: 'सिंह',
      element: CosmicElement.fire,
      archetype: 'The Luminary',
      traits: 'Radiant · Generous · Natural Leader',
      definingEssence: 'Radiant courage leading with warmth and noble vision.',
      dailySparks: [
        'Show up with full radiance today. Your confidence naturally elevates the entire room.',
        'Take pride in the standard of your craft. When you shine, you give others permission to shine.',
        'Lead by vibrant example today. Bring warmth, courage, and big energy to your work.',
        'You were made to conquer uphill battles. Step into the arena with an open heart.',
        'Your enthusiasm is infectious today. Turn ambition into an inspiring reality.',
        'Never shrink your vision to fit small rooms. Stand tall in your aspirations.',
        'A generous spirit multiplies your energy. Give your best effort with joy.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Virgo',
      symbol: '♍',
      vedicRashi: 'Kanya',
      vedicHindi: 'कन्या',
      element: CosmicElement.earth,
      archetype: 'The Craftsman',
      traits: 'Precise · Discerning · System Optimizer',
      definingEssence: 'Quiet craftsmanship turning subtle details into pure excellence.',
      dailySparks: [
        'Excellence lives in the subtle nuances. Perfect one clean detail today.',
        'Turn chaos into clean order. Your systematic approach is a breath of fresh air.',
        'Remember that done is better than perfect. Apply your genius, then ship with pride.',
        'Small daily adjustments create miraculous long-term transformations.',
        'Your clarity cuts through clutter effortlessly today. Simplify your task list.',
        'Bring mindful mastery to your work. Craftsmanship is quiet devotion.',
        'Trust your analytical instinct today; you see the hidden path to efficiency.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Libra',
      symbol: '♎',
      vedicRashi: 'Tula',
      vedicHindi: 'तुला',
      element: CosmicElement.air,
      archetype: 'The Harmonizer',
      traits: 'Balanced · Aesthetic · Diplomatic',
      definingEssence: 'Graceful harmony balancing truth, intellect, and beauty.',
      dailySparks: [
        'Balance is not stillness; it is graceful motion. Find equilibrium in your day.',
        'Bring elegance and calm structure to today’s challenges. Grace wins over force.',
        'Clarity comes when you pause and weigh what truly matters. Choose your focus with intention.',
        'Create harmony in your workspace today. A peaceful environment supercharges your mind.',
        'Your sense of fairness and perspective resolves tension with ease today.',
        'Walk the middle path between deep effort and restful ease. Harmony is power.',
        'Make beautiful decisions today—balance work rigor with quiet inner peace.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Scorpio',
      symbol: '♏',
      vedicRashi: 'Vrishchika',
      vedicHindi: 'वृश्चिक',
      element: CosmicElement.water,
      archetype: 'The Alchemist',
      traits: 'Fierce · Transformative · Deep Focus',
      definingEssence: 'Unshakable focus transforming every challenge into power.',
      dailySparks: [
        'Your capacity for unbroken concentration is unmatched. Lock in and immerse deeply.',
        'Transform friction into pure fuel today. Nothing stops a determined, focused mind.',
        'Keep your biggest moves quiet until the results speak for themselves.',
        'You have the power to reinvent yourself today. Shed hesitation and step forward.',
        'Depth beats surface chatter. Go deep on the one project that truly moves the needle.',
        'Your resilience is forged in fire and depth. Conquer the hardest task first.',
        'Trust your piercing insight today. Cut directly to the root of the problem.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Sagittarius',
      symbol: '♐',
      vedicRashi: 'Dhanu',
      vedicHindi: 'धनु',
      element: CosmicElement.fire,
      archetype: 'The Seeker',
      traits: 'Visionary · Optimistic · Truth Hunter',
      definingEssence: 'Boundless seeker aiming high and illuminating the horizon.',
      dailySparks: [
        'Keep your eyes on the distant horizon while keeping your feet moving today.',
        'Your boundless optimism is an unstoppable catalyst. Aim high and release the arrow.',
        'See every obstacle as a masterclass in growth. Adventure lives in solving challenges.',
        'Expand your perspective today. One fresh insight can rewrite your entire roadmap.',
        'Freedom comes from self-mastery. Align your daily discipline with your grandest dreams.',
        'Bring your playful curiosity to hard work. Passion turns effort into adventure.',
        'Trust the journey. Your optimism will light the way through unfamiliar territory.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Capricorn',
      symbol: '♑',
      vedicRashi: 'Makara',
      vedicHindi: 'मकर',
      element: CosmicElement.earth,
      archetype: 'The Architect',
      traits: 'Disciplined · Strategic · Mountain Climber',
      definingEssence: 'Steadfast architect climbing each peak with quiet resilience.',
      dailySparks: [
        'The summit belongs to those who keep climbing when the air gets thin. One more step.',
        'Your quiet discipline is carving an empire of results. Respect your long-term plan.',
        'Build structures that outlast the storm. Master the fundamentals today.',
        'Patience and relentless work ethic make you inevitable. Keep climbing steadily.',
        'Turn high standards into calm execution. You are built for enduring mastery.',
        'Focus on the summit, but honor each foothold today. Solid progress compounds.',
        'Your maturity and focus command respect today. Lead your day with poise.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Aquarius',
      symbol: '♒',
      vedicRashi: 'Kumbha',
      vedicHindi: 'कुंभ',
      element: CosmicElement.air,
      archetype: 'The Visionary',
      traits: 'Innovative · Unconventional · Humanist',
      definingEssence: 'Original visionary thinking ahead of the curve.',
      dailySparks: [
        'Think outside conventional boundaries today. The future belongs to original thinkers.',
        'Your unique perspective is your competitive edge. Trust your unorthodox solution.',
        'Work for the vision only you can see right now. The world will catch up soon.',
        'Bring fresh innovation to a stale routine. Small clever tweaks create huge breakthroughs.',
        'Stay independent in your thought, collaborative in your impact. Lead from the future.',
        'Question the standard playbook today. There is a faster, cleaner path waiting.',
        'Your intellectual freedom is boundless. Channel it into a meaningful breakthrough.',
      ],
    ),
    ZodiacSignInfo(
      name: 'Pisces',
      symbol: '♓',
      vedicRashi: 'Meena',
      vedicHindi: 'मीन',
      element: CosmicElement.water,
      archetype: 'The Mystic',
      traits: 'Empathetic · Imaginative · Transcendent',
      definingEssence: 'Soulful imagination flowing past boundaries like water.',
      dailySparks: [
        'Your creative imagination is boundless today. Channel your visions into tangible form.',
        'Quiet your mind to hear your deepest truths. Still waters reflect the highest stars.',
        'Let empathy guide your interactions, but keep your energetic boundaries strong.',
        'Blend intuition with daily craftsmanship. When soul meets structure, magic happens.',
        'Your gentle persistence moves mountains. Flow around obstacles like water.',
        'Trust the timing of your growth. Dream boldly and take one faithful action today.',
        'Bring artistic grace and soulful care to whatever you touch today.',
      ],
    ),
  ];

  static const List<DailyLivingMood> livingMoods = [
    DailyLivingMood(
      weekday: 1, // Monday
      planetaryRuler: 'Moon · Chandra',
      rulingTitle: 'Moonlit Clarity',
      themeVibe: 'Reflective & Intuitive',
      shortMotto: 'Begin with gentle clarity and calm intentions.',
      livingTint: Color(0xFF7FA1C3),
    ),
    DailyLivingMood(
      weekday: 2, // Tuesday
      planetaryRuler: 'Mars · Mangala',
      rulingTitle: 'Mars Momentum',
      themeVibe: 'Fierce Energy & Breakthroughs',
      shortMotto: 'Channel courage. Attack the hardest friction first.',
      livingTint: Color(0xFFE06D53),
    ),
    DailyLivingMood(
      weekday: 3, // Wednesday
      planetaryRuler: 'Mercury · Budha',
      rulingTitle: 'Mercury Intellect',
      themeVibe: 'Sharp Focus & Synthesis',
      shortMotto: 'Rapid learning, swift communication, clean logic.',
      livingTint: Color(0xFF4E9F76),
    ),
    DailyLivingMood(
      weekday: 4, // Thursday
      planetaryRuler: 'Jupiter · Guru',
      rulingTitle: 'Jupiter Expansion',
      themeVibe: 'Vision, Wisdom & Growth',
      shortMotto: 'Think bigger. Expand your horizons and trust your compounding.',
      livingTint: Color(0xFFD49B35),
    ),
    DailyLivingMood(
      weekday: 5, // Friday
      planetaryRuler: 'Venus · Shukra',
      rulingTitle: 'Venus Harmony',
      themeVibe: 'Grace, Flow & Creativity',
      shortMotto: 'Craft elegance into your work and celebrate beauty.',
      livingTint: Color(0xFFC46886),
    ),
    DailyLivingMood(
      weekday: 6, // Saturday
      planetaryRuler: 'Saturn · Shani',
      rulingTitle: 'Saturn Mastery',
      themeVibe: 'Discipline & Enduring Craft',
      shortMotto: 'Honor your fundamentals. Build what stands the test of time.',
      livingTint: Color(0xFF6B7B9E),
    ),
    DailyLivingMood(
      weekday: 7, // Sunday
      planetaryRuler: 'Sun · Surya',
      rulingTitle: 'Solar Vitality',
      themeVibe: 'Radiance, Recharge & Purpose',
      shortMotto: 'Bask in your accomplishments and renew your inner fire.',
      livingTint: Color(0xFFD9822B),
    ),
  ];

  /// Computes Western Zodiac Sign from date of birth.
  ZodiacSignInfo getZodiac(DateTime dob) {
    final m = dob.month;
    final d = dob.day;

    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return signs[0]; // Aries
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return signs[1]; // Taurus
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return signs[2]; // Gemini
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return signs[3]; // Cancer
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return signs[4]; // Leo
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return signs[5]; // Virgo
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return signs[6]; // Libra
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return signs[7]; // Scorpio
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return signs[8]; // Sagittarius
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return signs[9]; // Capricorn
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return signs[10]; // Aquarius
    return signs[11]; // Pisces
  }

  /// Checks if [today] is the user's birthday.
  bool isBirthdayToday(DateTime dob, [DateTime? today]) {
    final now = today ?? DateTime.now();
    return dob.month == now.month && dob.day == now.day;
  }

  /// Computes the user's age if birthday has occurred this year.
  int computeAge(DateTime dob, [DateTime? today]) {
    final now = today ?? DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Retrieves today's living planetary mood based on current weekday.
  DailyLivingMood getDayLivingMood([DateTime? date]) {
    final d = date ?? DateTime.now();
    final index = (d.weekday - 1).clamp(0, 6);
    return livingMoods[index];
  }

  /// Generates a personalized daily horoscope spark and living daily insight.
  DailyCosmicInsight getDailyInsight({
    required DateTime dob,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final sign = getZodiac(dob);
    final mood = getDayLivingMood(now);
    final isBday = isBirthdayToday(dob, now);
    final age = isBday ? computeAge(dob, now) : null;

    if (isBday) {
      return DailyCosmicInsight(
        sign: sign,
        quote:
            '🎉 Happy Birthday! A radiant new solar cycle begins for you today. '
            'Stand tall in your $age years of wisdom and celebrate your journey!',
        livingMood: mood,
        isBirthday: true,
        age: age,
      );
    }

    // Deterministic daily rotation: changes smoothly each calendar day
    final dayOfYear = int.parse('${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}');
    final sparkIndex = (dayOfYear + sign.name.hashCode) % sign.dailySparks.length;
    final quote = sign.dailySparks[sparkIndex.abs()];

    return DailyCosmicInsight(
      sign: sign,
      quote: quote,
      livingMood: mood,
      isBirthday: false,
      age: null,
    );
  }
}
