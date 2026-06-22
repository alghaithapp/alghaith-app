import 'package:flutter_test/flutter_test.dart';
import 'package:alghaith_app/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.toWesternDigits', () {
    test('converts Arabic numerals to western', () {
      expect(PhoneUtils.toWesternDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Persian numerals to western', () {
      expect(PhoneUtils.toWesternDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('leaves western digits unchanged', () {
      expect(PhoneUtils.toWesternDigits('07701234567'), '07701234567');
    });

    test('handles mixed content with non-digit characters', () {
      expect(PhoneUtils.toWesternDigits('+964 ٧٧٠ ١٢٣ ٤٥٦٧'),
          '+964 770 123 4567');
    });

    test('empty string returns empty', () {
      expect(PhoneUtils.toWesternDigits(''), '');
    });
  });

  group('PhoneUtils.digitsOnly', () {
    test('extracts only digits', () {
      expect(PhoneUtils.digitsOnly('+964 (077) 123-4567'), '9640771234567');
    });

    test('returns empty for no digits', () {
      expect(PhoneUtils.digitsOnly('abc'), '');
    });

    test('handles Arabic numerals', () {
      expect(PhoneUtils.digitsOnly('٠٧٧٠١٢٣٤٥٦٧'), '07701234567');
    });

    test('handles Persian numerals', () {
      expect(PhoneUtils.digitsOnly('۰۷۷۰۱۲۳۴۵۶۷'), '07701234567');
    });
  });

  group('PhoneUtils.normalize', () {
    test('normalizes 0770 format to +964', () {
      expect(PhoneUtils.normalize('07701234567'), '+9647701234567');
    });

    test('normalizes 964 format', () {
      expect(PhoneUtils.normalize('9647701234567'), '+9647701234567');
    });

    test('normalizes +964 format unchanged', () {
      expect(PhoneUtils.normalize('+9647701234567'), '+9647701234567');
    });

    test('normalizes 10-digit format starting with 7', () {
      expect(PhoneUtils.normalize('7701234567'), '+9647701234567');
    });

    test('returns empty string for empty input', () {
      expect(PhoneUtils.normalize(''), '');
    });

    test('handles whitespace around number', () {
      expect(PhoneUtils.normalize('  07701234567  '), '+9647701234567');
    });

    test('handles Arabic numeral input', () {
      expect(PhoneUtils.normalize('٠٧٧٠١٢٣٤٥٦٧'), '+9647701234567');
    });

    test('preserves original if starts with + but not 964', () {
      expect(PhoneUtils.normalize('+15551234567'), '+15551234567');
    });

    test('prepends + when no prefix', () {
      final result = PhoneUtils.normalize('12345');
      expect(result, startsWith('+'));
    });
  });

  group('PhoneUtils.variants', () {
    test('generates all 4 variants for a full number', () {
      final result = PhoneUtils.variants('07701234567');
      expect(result, [
        '+9647701234567',
        '9647701234567',
        '07701234567',
        '7701234567',
      ]);
    });

    test('handles +964 input', () {
      final result = PhoneUtils.variants('+9647701234567');
      expect(result, [
        '+9647701234567',
        '9647701234567',
        '07701234567',
        '7701234567',
      ]);
    });

    test('returns trimmed input for short numbers', () {
      final result = PhoneUtils.variants('123');
      expect(result, ['123']);
    });

    test('returns empty list for empty input', () {
      final result = PhoneUtils.variants('');
      expect(result, []);
    });

    test('returns trimmed input for whitespace', () {
      final result = PhoneUtils.variants('   ');
      expect(result, []);
    });

    test('strips country code to get core 10 digits', () {
      final result = PhoneUtils.variants('+9647701111111');
      expect(result, [
        '+9647701111111',
        '9647701111111',
        '07701111111',
        '7701111111',
      ]);
    });
  });

  group('PhoneUtils.isValidIraqiMobile', () {
    test('validates +9647xxxxxxxx', () {
      expect(PhoneUtils.isValidIraqiMobile('+9647701234567'), isTrue);
    });

    test('validates 0770 format', () {
      expect(PhoneUtils.isValidIraqiMobile('07701234567'), isTrue);
    });

    test('rejects landline +9641xxxxxxxx', () {
      expect(PhoneUtils.isValidIraqiMobile('+96411234567'), isFalse);
    });

    test('rejects too short numbers', () {
      expect(PhoneUtils.isValidIraqiMobile('0770'), isFalse);
    });

    test('rejects empty string', () {
      expect(PhoneUtils.isValidIraqiMobile(''), isFalse);
    });

    test('rejects non-numeric characters', () {
      expect(PhoneUtils.isValidIraqiMobile('+9647abcdefgh'), isFalse);
    });

    test('validates with Arabic numerals', () {
      expect(PhoneUtils.isValidIraqiMobile('٠٧٧٠١٢٣٤٥٦٧'), isTrue);
    });
  });
}
