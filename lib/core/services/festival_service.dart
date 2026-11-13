import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a celebrated cultural, national, or seasonal festival.
class FestivalEvent {
  final String id;
  final String name;
  final String greeting;
  final String thought;
  final String riyaWish;
  final int month;
  final int day;
  final int? year; // null for annual recurring on same day
  final String emoji;
  final Color accentColor;

  const FestivalEvent({
    required this.id,
    required this.name,
    required this.greeting,
    required this.thought,
    required this.riyaWish,
    required this.month,
    required this.day,
    this.year,
    this.emoji = '✨',
    this.accentColor = const Color(0xFFF59E0B),
  });

  bool matches(DateTime date) {
    if (year != null && date.year != year) return false;
    return date.month == month && date.day == day;
  }
}

class FestivalService {
  FestivalService._();

  /// Canonical catalog of festivals with specific calendar dates (including 2026 Hindu lunar dates).
  static const List<FestivalEvent> allFestivals = [
    // ── 2026 SPECIFIC LUNAR/CALCULATED FESTIVALS ────────────────────────────
    FestivalEvent(
      id: 'diwali_2026',
      name: 'Diwali',
      greeting: 'Happy Diwali! May the festival of lights bring radiance, peace, and abundance.',
      thought: 'Lighting a lamp within before lighting the world outside. A festival of quiet warmth, self-mastery, and new beginnings. Happy Diwali.',
      riyaWish: 'Happy Diwali! 🪔✨ May your day be filled with warm light, joyful moments, and calm clarity.',
      month: 11,
      day: 8,
      year: 2026,
      emoji: '🪔',
      accentColor: Color(0xFFF59E0B),
    ),
    FestivalEvent(
      id: 'dhanteras_2026',
      name: 'Dhanteras',
      greeting: 'Happy Dhanteras! Wishing you prosperity, well-being, and wisdom.',
      thought: 'True wealth is a composed mind, honest effort, and vibrant health.',
      riyaWish: 'Happy Dhanteras! 🪙 Wishing you abundance in focus, health, and spirit.',
      month: 11,
      day: 6,
      year: 2026,
      emoji: '🪙',
      accentColor: Color(0xFFEAB308),
    ),
    FestivalEvent(
      id: 'bhai_dooj_2026',
      name: 'Bhai Dooj',
      greeting: 'Happy Bhai Dooj! Celebrating the bonds of care, love, and protection.',
      thought: 'Cherishing the quiet bonds that anchor our lives and uplift our spirits.',
      riyaWish: 'Happy Bhai Dooj! 🌸 Wishing warmth and laughter to you and your loved ones.',
      month: 11,
      day: 10,
      year: 2026,
      emoji: '🌸',
      accentColor: Color(0xFFEC4899),
    ),
    FestivalEvent(
      id: 'chhath_puja_2026',
      name: 'Chhath Puja',
      greeting: 'Happy Chhath Puja! Reverence to the Sun for energy, life, and gratitude.',
      thought: 'Rising with unwavering discipline and offering gratitude to the source of life.',
      riyaWish: 'Happy Chhath Puja! 🌅 May the divine sun inspire steadfast discipline in all you do.',
      month: 11,
      day: 15,
      year: 2026,
      emoji: '🌅',
      accentColor: Color(0xFFF97316),
    ),
    FestivalEvent(
      id: 'guru_nanak_jayanti_2026',
      name: 'Guru Nanak Jayanti',
      greeting: 'Happy Gurpurab! May the teachings of truth, kindness, and equality guide your way.',
      thought: 'Truth is the highest virtue, but higher still is truthful living. — Guru Nanak',
      riyaWish: 'Happy Gurpurab! ੴ May peace, selfless service, and inner wisdom surround you.',
      month: 11,
      day: 24,
      year: 2026,
      emoji: 'ੴ',
      accentColor: Color(0xFFF59E0B),
    ),
    FestivalEvent(
      id: 'holi_2026',
      name: 'Holi',
      greeting: 'Happy Holi! May vibrant colors of joy, courage, and optimism fill your life.',
      thought: 'Celebrate renewal: let go of old grudges and welcome vibrant new beginnings.',
      riyaWish: 'Happy Holi! 🎨 Wishing you an energetic, joyful, and colorful day.',
      month: 3,
      day: 4,
      year: 2026,
      emoji: '🎨',
      accentColor: Color(0xFFEC4899),
    ),
    FestivalEvent(
      id: 'eid_ul_fitr_2026',
      name: 'Eid al-Fitr',
      greeting: 'Eid Mubarak! Wishing you and your loved ones peace, harmony, and joy.',
      thought: 'A season of gratitude, patience, and extending kindness to every soul.',
      riyaWish: 'Eid Mubarak! 🌙 Wishing you peace, fulfillment, and gentle blessings.',
      month: 3,
      day: 20,
      year: 2026,
      emoji: '🌙',
      accentColor: Color(0xFF10B981),
    ),
    FestivalEvent(
      id: 'navratri_dussehra_2026',
      name: 'Dussehra',
      greeting: 'Happy Dussehra! Victory of righteousness, clarity, and perseverance.',
      thought: 'Overcoming internal doubts and anchoring in truth. Victory of perseverance.',
      riyaWish: 'Happy Dussehra! 🏹 May triumph and clarity crown all your noble pursuits.',
      month: 10,
      day: 20,
      year: 2026,
      emoji: '🏹',
      accentColor: Color(0xFFEA580C),
    ),

    // ── FIXED ANNUAL CELEBRATIONS ──────────────────────────────────────────
    FestivalEvent(
      id: 'new_year',
      name: 'New Year’s Day',
      greeting: 'Happy New Year! A blank canvas for bold aspirations and continuous ascent.',
      thought: 'Every day is a fresh threshold. Begin deliberately, without haste.',
      riyaWish: 'Happy New Year! 🎆 Here is to a brilliant year of growth, purpose, and mastery.',
      month: 1,
      day: 1,
      emoji: '🎆',
      accentColor: Color(0xFF3B82F6),
    ),
    FestivalEvent(
      id: 'makar_sankranti',
      name: 'Makar Sankranti',
      greeting: 'Happy Makar Sankranti & Pongal! Celebrating harvest, sunshine, and progress.',
      thought: 'Soaring high like a kite in steady wind, guided by a composed inner compass.',
      riyaWish: 'Happy Makar Sankranti! 🪁 May your aspirations soar higher each day.',
      month: 1,
      day: 14,
      emoji: '🪁',
      accentColor: Color(0xFFF59E0B),
    ),
    FestivalEvent(
      id: 'republic_day',
      name: 'Republic Day',
      greeting: 'Happy Republic Day! Honoring the constitution, unity, and shared heritage.',
      thought: 'Duty to oneself and dedication to the collective good walk hand in hand.',
      riyaWish: 'Happy Republic Day! 🇮🇳 Standing proud with courage, integrity, and resolve.',
      month: 1,
      day: 26,
      emoji: '🇮🇳',
      accentColor: Color(0xFFF97316),
    ),
    FestivalEvent(
      id: 'earth_day',
      name: 'Earth Day',
      greeting: 'Happy Earth Day! Nurturing nature with mindful living and gratitude.',
      thought: 'We do not inherit the earth from our ancestors; we borrow it from our children.',
      riyaWish: 'Happy Earth Day! 🌍 Let us walk gently and protect the world we share.',
      month: 4,
      day: 22,
      emoji: '🌍',
      accentColor: Color(0xFF10B981),
    ),
    FestivalEvent(
      id: 'independence_day',
      name: 'Independence Day',
      greeting: 'Happy Independence Day! Cherishing freedom, resilience, and unity.',
      thought: 'True freedom is mastery over self and devotion to the nation’s progress.',
      riyaWish: 'Happy Independence Day! 🇮🇳 Celebrating courage, sovereignty, and vision.',
      month: 8,
      day: 15,
      emoji: '🇮🇳',
      accentColor: Color(0xFFF97316),
    ),
    FestivalEvent(
      id: 'gandhi_jayanti',
      name: 'Gandhi Jayanti',
      greeting: 'Remembering Mahatma Gandhi: Peace, truth, and non-violence.',
      thought: 'Be the change that you wish to see in the world. — Mahatma Gandhi',
      riyaWish: 'Remembering Bapu today 👓. May simplicity and truth guide our actions.',
      month: 10,
      day: 2,
      emoji: '👓',
      accentColor: Color(0xFF78716C),
    ),
    FestivalEvent(
      id: 'christmas',
      name: 'Christmas',
      greeting: 'Merry Christmas! May goodwill, generosity, and peace fill your home.',
      thought: 'The greatest gift is an open heart, compassionate presence, and gratitude.',
      riyaWish: 'Merry Christmas! 🎄✨ Wishing you warmth, peace, and joyous moments.',
      month: 12,
      day: 25,
      emoji: '🎄',
      accentColor: Color(0xFFDC2626),
    ),
    FestivalEvent(
      id: 'new_year_eve',
      name: 'New Year’s Eve',
      greeting: 'Celebrating the close of a remarkable year. Grateful for every lesson.',
      thought: 'Reflecting on milestones and honoring the resilience that carried us through.',
      riyaWish: 'Happy New Year’s Eve! 🥂 Taking a gentle breath to honor your journey.',
      month: 12,
      day: 31,
      emoji: '🥂',
      accentColor: Color(0xFF8B5CF6),
    ),
  ];

  /// Returns festival for the given [date], or null if none is marked.
  static FestivalEvent? getFestivalForDate(DateTime date) {
    for (final festival in allFestivals) {
      if (festival.matches(date)) {
        return festival;
      }
    }
    return null;
  }

  /// Returns festival matching today's local date.
  static FestivalEvent? getTodayFestival([DateTime? now]) {
    final current = now ?? DateTime.now();
    return getFestivalForDate(current);
  }

  /// Returns all festivals in the given month.
  static List<FestivalEvent> getFestivalsForMonth(DateTime month) {
    return allFestivals.where((f) {
      if (f.year != null && f.year != month.year) return false;
      return f.month == month.month;
    }).toList();
  }
}

/// Provider for today's active festival (if any).
final todayFestivalProvider = Provider<FestivalEvent?>((ref) {
  return FestivalService.getTodayFestival();
});

/// Provider for all festivals in a specified month.
final monthFestivalsProvider = Provider.family<List<FestivalEvent>, DateTime>((ref, month) {
  return FestivalService.getFestivalsForMonth(month);
});
