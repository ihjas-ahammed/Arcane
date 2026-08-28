import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/utils/helpers.dart';

void main() {
  group('formatCompactXp tests', () {
    test('values <= 9999 remain exact integer strings', () {
      expect(formatCompactXp(0), '0');
      expect(formatCompactXp(1), '1');
      expect(formatCompactXp(50), '50');
      expect(formatCompactXp(999), '999');
      expect(formatCompactXp(9999), '9999');
    });

    test('values between 10000 and 999999 format as K with optional decimals', () {
      expect(formatCompactXp(10000), '10K');
      expect(formatCompactXp(10100), '10.1K');
      expect(formatCompactXp(11000), '11K');
      expect(formatCompactXp(11200), '11.2K');
      expect(formatCompactXp(15400), '15.4K');
      expect(formatCompactXp(99999), '100K');
      expect(formatCompactXp(100000), '100K');
      expect(formatCompactXp(150500), '150.5K');
    });

    test('values >= 1,000,000 format as M', () {
      expect(formatCompactXp(1000000), '1M');
      expect(formatCompactXp(1100000), '1.1M');
      expect(formatCompactXp(1200000), '1.2M');
      expect(formatCompactXp(2500000), '2.5M');
    });

    test('values >= 1,000,000,000 format as B', () {
      expect(formatCompactXp(1000000000), '1B');
      expect(formatCompactXp(1200000000), '1.2B');
    });

    test('handles negative values correctly', () {
      expect(formatCompactXp(-50), '-50');
      expect(formatCompactXp(-10500), '-10.5K');
      expect(formatCompactXp(-1200000), '-1.2M');
    });
  });
}
