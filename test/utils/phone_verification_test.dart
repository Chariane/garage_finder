import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/utils/phone_verification.dart';

void main() {
  test('normalizes formatting around an international phone number', () {
    expect(
      normalizePhoneForVerification('+229 01 23-45 (67) 89'),
      '+2290123456789',
    );
  });

  test('requires an explicit international country code', () {
    expect(normalizePhoneForVerification('0123456789'), isNull);
    expect(normalizePhoneForVerification('+2290123456789'), '+2290123456789');
  });

  test('rejects phone numbers outside E.164 length and prefix rules', () {
    expect(normalizePhoneForVerification('+01234567'), isNull);
    expect(normalizePhoneForVerification('+123'), isNull);
    expect(normalizePhoneForVerification('+1234567890123456'), isNull);
  });
}
