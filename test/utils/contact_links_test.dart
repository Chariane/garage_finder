import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/utils/contact_links.dart';

void main() {
  test('normalizes a local Benin mobile number to international format', () {
    expect(normalizeWhatsAppNumber('01 97 00 00 00'), '2290197000000');
    expect(normalizeWhatsAppNumber('97 00 00 00'), '22997000000');
  });

  test('preserves a valid international number', () {
    expect(normalizeWhatsAppNumber('+229 01 97 00 00 00'), '2290197000000');
  });

  test('creates a WhatsApp URI with an encoded draft message', () {
    final uri = whatsappUri('97 00 00 00', message: 'Bonjour Garage Finder');

    expect(uri?.host, 'wa.me');
    expect(uri?.path, '/22997000000');
    expect(uri?.queryParameters['text'], 'Bonjour Garage Finder');
  });

  test('rejects phone numbers that cannot be safely contacted', () {
    expect(whatsappUri('12'), isNull);
    expect(whatsappUri(''), isNull);
  });
}
