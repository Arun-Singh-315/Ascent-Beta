import 'dart:math';

class ExtractedCardData {
  final String? cardNumber;
  final String? cardBrand;
  final String? expiry;
  final String? cvv;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? email;

  const ExtractedCardData({
    this.cardNumber,
    this.cardBrand,
    this.expiry,
    this.cvv,
    this.panNumber,
    this.aadhaarNumber,
    this.email,
  });
}

class VaultPatternExtractor {
  /// Luhn algorithm check digit validation for credit and debit cards.
  static bool isValidLuhn(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 13 || sanitized.length > 19) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = sanitized.length - 1; i >= 0; i--) {
      int digit = int.parse(sanitized[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return (sum % 10 == 0);
  }

  /// Detects card network brand based on IIN / BIN prefixes.
  static String detectCardBrand(String number) {
    final sanitized = number.replaceAll(RegExp(r'\D'), '');
    if (sanitized.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(sanitized)) return 'Mastercard';
    if (RegExp(r'^(34|37)').hasMatch(sanitized)) return 'American Express';
    if (RegExp(r'^(60|65|81|82|508)').hasMatch(sanitized)) return 'RuPay';
    if (RegExp(r'^(6011|65|64[4-9]|622)').hasMatch(sanitized)) return 'Discover';
    return 'Card';
  }

  /// Expiry date format check (MM/YY or MM/YYYY) ensuring valid month & non-expired year.
  static bool isValidExpiry(String expiry) {
    final trimmed = expiry.trim();
    final match = RegExp(r'^(0[1-9]|1[0-2])[\/\-]([0-9]{2}|[0-9]{4})$').firstMatch(trimmed);
    if (match == null) return false;

    final month = int.tryParse(match.group(1)!) ?? 0;
    var year = int.tryParse(match.group(2)!) ?? 0;
    if (year < 100) year += 2000;

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    return true;
  }

  /// Permanent Account Number (PAN) format validation: ABCDE1234F.
  static bool isValidPan(String pan) {
    return RegExp(r'^[A-Za-z]{5}[0-9]{4}[A-Za-z]$').hasMatch(pan.trim());
  }

  /// Indian Aadhaar number format: 12 digits, cannot start with 0 or 1.
  static bool isValidAadhaar(String aadhaar) {
    final sanitized = aadhaar.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^[2-9]{1}[0-9]{11}$').hasMatch(sanitized);
  }

  /// Standard email address format.
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(email.trim());
  }

  /// Formats raw card digits with grouped spacing (e.g. 4532 0151 1283 0366).
  static String formatCardNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Smart pattern recognition from scanned OCR text or pasted raw details.
  static ExtractedCardData extractPatterns(String text) {
    String? foundCard;
    String? foundBrand;
    String? foundExpiry;
    String? foundCvv;
    String? foundPan;
    String? foundAadhaar;
    String? foundEmail;

    // 1. Search for card number (13-19 digits, possibly hyphen/space separated)
    final cardMatches = RegExp(r'\b(?:\d[ -]*?){13,19}\b').allMatches(text);
    for (final m in cardMatches) {
      final candidate = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (isValidLuhn(candidate)) {
        foundCard = candidate;
        foundBrand = detectCardBrand(candidate);
        break;
      }
    }

    // 2. Search for expiry date MM/YY
    final expiryMatch = RegExp(r'\b(0[1-9]|1[0-2])[\/\-]([0-9]{2}|[0-9]{4})\b').firstMatch(text);
    if (expiryMatch != null) {
      foundExpiry = expiryMatch.group(0);
    }

    // 3. Search for CVV (3 or 4 digits near CVV keyword or isolated 3 digits)
    final cvvKeywordMatch = RegExp(r'(?:cvv|cvc|security code)[\s:]*([0-9]{3,4})', caseSensitive: false).firstMatch(text);
    if (cvvKeywordMatch != null) {
      foundCvv = cvvKeywordMatch.group(1);
    }

    // 4. PAN Card detection
    final panMatch = RegExp(r'\b[A-Za-z]{5}[0-9]{4}[A-Za-z]\b').firstMatch(text);
    if (panMatch != null) {
      foundPan = panMatch.group(0)!.toUpperCase();
    }

    // 5. Aadhaar detection (4 4 4 digits)
    final aadhaarMatch = RegExp(r'\b[2-9]{1}[0-9]{3}\s?[0-9]{4}\s?[0-9]{4}\b').firstMatch(text);
    if (aadhaarMatch != null) {
      final raw = aadhaarMatch.group(0)!.replaceAll(' ', '');
      if (raw.length == 12) {
        foundAadhaar = '${raw.substring(0, 4)} ${raw.substring(4, 8)} ${raw.substring(8, 12)}';
      }
    }

    // 6. Email detection
    final emailMatch = RegExp(r'\b[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+\b').firstMatch(text);
    if (emailMatch != null) {
      foundEmail = emailMatch.group(0);
    }

    return ExtractedCardData(
      cardNumber: foundCard,
      cardBrand: foundBrand,
      expiry: foundExpiry,
      cvv: foundCvv,
      panNumber: foundPan,
      aadhaarNumber: foundAadhaar,
      email: foundEmail,
    );
  }

  /// Generates a cryptographically strong random password.
  static String generatePassword({int length = 16, bool includeSymbols = true}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    final chars = StringBuffer()..write(letters)..write(numbers);
    if (includeSymbols) chars.write(symbols);

    final charList = chars.toString();
    final random = Random.secure();
    return List.generate(length, (_) => charList[random.nextInt(charList.length)]).join();
  }

  /// Calculates password strength score (0 to 100).
  static int calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 20;
    if (password.length >= 16) score += 10;
    if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) score += 20;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 15;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score += 15;
    return score.clamp(0, 100);
  }
}
