import 'package:ascent/features/vault/services/vault_pattern_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated passwords are always strong', () {
    for (var i = 0; i < 500; i++) {
      final p = VaultPatternExtractor.generatePassword(length: 16);
      expect(p.length, 16);
      expect(
        VaultPatternExtractor.calculatePasswordStrength(p),
        greaterThanOrEqualTo(80),
      );
      final q = VaultPatternExtractor.generatePassword(length: 24);
      expect(
        VaultPatternExtractor.calculatePasswordStrength(q),
        greaterThanOrEqualTo(90),
      );
    }
  });
}
