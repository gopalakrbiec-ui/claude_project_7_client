import 'package:flutter_test/flutter_test.dart';
import 'package:life_event_editor/screens/login/phone_entry_screen.dart';

void main() {
  group('normaliseIndianPhone', () {
    // Valid 10-digit numbers starting with 6–9
    test('accepts 10-digit number starting with 9', () {
      expect(normaliseIndianPhone('9876543210'), '+919876543210');
    });
    test('accepts 10-digit number starting with 6', () {
      expect(normaliseIndianPhone('6012345678'), '+916012345678');
    });
    test('accepts 10-digit number starting with 7', () {
      expect(normaliseIndianPhone('7123456789'), '+917123456789');
    });
    test('accepts 10-digit number starting with 8', () {
      expect(normaliseIndianPhone('8234567890'), '+918234567890');
    });

    // With spaces / dashes (raw input from paste)
    test('strips spaces and dashes', () {
      expect(normaliseIndianPhone('98765 43210'), '+919876543210');
      expect(normaliseIndianPhone('98765-43210'), '+919876543210');
    });

    // Already-prefixed inputs
    test('accepts 12-digit number with 91 prefix', () {
      expect(normaliseIndianPhone('919876543210'), '+919876543210');
    });
    test('accepts +91 prefix', () {
      expect(normaliseIndianPhone('+919876543210'), '+919876543210');
    });

    // Invalid inputs
    test('rejects 10-digit number starting with 5 (landline-ish)', () {
      expect(normaliseIndianPhone('5123456789'), isNull);
    });
    test('rejects too-short number', () {
      expect(normaliseIndianPhone('98765'), isNull);
    });
    test('rejects too-long number', () {
      expect(normaliseIndianPhone('98765432100'), isNull);
    });
    test('rejects empty string', () {
      expect(normaliseIndianPhone(''), isNull);
    });
    test('rejects all zeros', () {
      expect(normaliseIndianPhone('0000000000'), isNull);
    });
    test('rejects non-numeric input', () {
      expect(normaliseIndianPhone('abcdefghij'), isNull);
    });
  });
}
