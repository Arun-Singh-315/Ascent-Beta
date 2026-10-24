import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/features/vault/models/vault_item_model.dart';
import 'package:ascent/features/vault/services/vault_pattern_extractor.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';

void main() {
  group('Vault Pattern Extractor & Validations Tests', () {
    test('Luhn algorithm accurately validates card numbers', () {
      // Valid standard Visa test card
      expect(VaultPatternExtractor.isValidLuhn('4532015112830366'), isTrue);
      // Valid Mastercard
      expect(VaultPatternExtractor.isValidLuhn('5555555555554444'), isTrue);
      // Invalid card numbers (wrong check digit)
      expect(VaultPatternExtractor.isValidLuhn('4532015112830367'), isFalse);
      expect(VaultPatternExtractor.isValidLuhn('4532015112830369'), isFalse);
      // Too short
      expect(VaultPatternExtractor.isValidLuhn('12345'), isFalse);
    });

    test('Card brand detection detects Visa, Mastercard, RuPay, Amex', () {
      expect(VaultPatternExtractor.detectCardBrand('4532 0151 1283 0366'), 'Visa');
      expect(VaultPatternExtractor.detectCardBrand('5123 4567 8901 2345'), 'Mastercard');
      expect(VaultPatternExtractor.detectCardBrand('3782 822463 10005'), 'American Express');
      expect(VaultPatternExtractor.detectCardBrand('6061 2345 6789 0123'), 'RuPay');
      expect(VaultPatternExtractor.detectCardBrand('6521 2345 6789 0123'), 'RuPay');
      expect(VaultPatternExtractor.detectCardBrand('9999 0000 1111 2222'), 'Card');
    });

    test('Expiry date validator validates MM/YY format and future dates', () {
      expect(VaultPatternExtractor.isValidExpiry('12/35'), isTrue);
      expect(VaultPatternExtractor.isValidExpiry('05/29'), isTrue);
      expect(VaultPatternExtractor.isValidExpiry('13/28'), isFalse); // Invalid month 13
      expect(VaultPatternExtractor.isValidExpiry('00/28'), isFalse); // Invalid month 00
      expect(VaultPatternExtractor.isValidExpiry('12/20'), isFalse); // Past year 2020
      expect(VaultPatternExtractor.isValidExpiry('random'), isFalse);
    });

    test('Indian PAN and Aadhaar pattern validations', () {
      expect(VaultPatternExtractor.isValidPan('ABCDE1234F'), isTrue);
      expect(VaultPatternExtractor.isValidPan('abcde1234f'), isTrue);
      expect(VaultPatternExtractor.isValidPan('12345ABCDE'), isFalse);
      expect(VaultPatternExtractor.isValidPan('ABCDE12345'), isFalse);

      expect(VaultPatternExtractor.isValidAadhaar('2345 6789 0123'), isTrue);
      expect(VaultPatternExtractor.isValidAadhaar('234567890123'), isTrue);
      expect(VaultPatternExtractor.isValidAadhaar('034567890123'), isFalse); // Cannot start with 0 or 1
      expect(VaultPatternExtractor.isValidAadhaar('134567890123'), isFalse);
      expect(VaultPatternExtractor.isValidAadhaar('1234'), isFalse);
    });

    test('Email pattern validation', () {
      expect(VaultPatternExtractor.isValidEmail('user@example.com'), isTrue);
      expect(VaultPatternExtractor.isValidEmail('arun.singh+ascent@company.co.in'), isTrue);
      expect(VaultPatternExtractor.isValidEmail('invalid-email'), isFalse);
      expect(VaultPatternExtractor.isValidEmail('user@'), isFalse);
    });

    test('Smart auto-capture extracts card number and expiry from raw text', () {
      const rawSample = '''
      Payment Card Details
      HDFC BANK Regalia Gold
      4532 0151 1283 0366
      Valid Thru: 08/29
      CVV: 789
      ''';

      final extracted = VaultPatternExtractor.extractPatterns(rawSample);
      expect(extracted.cardNumber, '4532015112830366');
      expect(extracted.cardBrand, 'Visa');
      expect(extracted.expiry, '08/29');
      expect(extracted.cvv, '789');
    });

    test('Smart auto-capture extracts PAN and Aadhaar from ID documents', () {
      const idSample = 'Income Tax Department Permanent Account Number ABCDE1234F ARUN SINGH';
      final extracted = VaultPatternExtractor.extractPatterns(idSample);
      expect(extracted.panNumber, 'ABCDE1234F');

      const aadhaarSample = 'Government of India Unique Identification Authority 3456 7890 1234';
      final aadhaarExtracted = VaultPatternExtractor.extractPatterns(aadhaarSample);
      expect(aadhaarExtracted.aadhaarNumber, '3456 7890 1234');
    });

    test('Password generator generates strong passwords with given lengths', () {
      final p16 = VaultPatternExtractor.generatePassword(length: 16);
      expect(p16.length, 16);
      expect(VaultPatternExtractor.calculatePasswordStrength(p16), greaterThanOrEqualTo(80));

      final p24 = VaultPatternExtractor.generatePassword(length: 24, includeSymbols: true);
      expect(p24.length, 24);
      expect(VaultPatternExtractor.calculatePasswordStrength(p24), greaterThanOrEqualTo(90));
    });
  });

  group('Vault Security Service Encryption & Session Tests', () {
    test('AES-256 encryption & decryption round-trip restores exact payload', () {
      final security = VaultSecurityService.forTesting();
      const payload = '{"cardNumber":"4532015112830366","cvv":"123","pin":"9876"}';
      
      final encrypted = security.encrypt(payload);
      expect(encrypted, isNot(payload));
      expect(encrypted.isNotEmpty, isTrue);

      final decrypted = security.decrypt(encrypted);
      expect(decrypted, payload);
    });

    test('PIN authentication sets unlocked session state', () async {
      final security = VaultSecurityService.forTesting();
      expect(security.isUnlocked, isFalse);

      await security.setMasterPin('1234');
      expect(await security.hasMasterPin(), isTrue);
      security.lock();
      expect(security.isUnlocked, isFalse);

      final wrongAttempt = await security.verifyPin('9999');
      expect(wrongAttempt, isFalse);
      expect(security.isUnlocked, isFalse);

      final correctAttempt = await security.verifyPin('1234');
      expect(correctAttempt, isTrue);
      expect(security.isUnlocked, isTrue);

      security.lock();
      expect(security.isUnlocked, isFalse);
    });
  });
}
