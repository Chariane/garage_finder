import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/utils/google_maps_link.dart';

void main() {
  test('parses a standard Google Maps pin URL', () {
    final coordinates = GoogleMapsLink.parse(
      'https://www.google.com/maps/place/Garage/@6.3703,2.3912,17z',
    );

    expect(coordinates, (latitude: 6.3703, longitude: 2.3912));
  });

  test('parses coordinates from a directions destination parameter', () {
    final coordinates = GoogleMapsLink.parse(
      'https://www.google.com/maps/dir/?api=1&destination=6.37%2C2.39',
    );

    expect(coordinates, (latitude: 6.37, longitude: 2.39));
  });

  test('parses coordinates embedded in Google Maps data fragments', () {
    final coordinates = GoogleMapsLink.parse(
      'https://www.google.com/maps/place/Garage/data=!3d6.37!4d2.39',
    );

    expect(coordinates, (latitude: 6.37, longitude: 2.39));
  });

  test('rejects short links without exposed coordinates', () {
    expect(GoogleMapsLink.parse('https://maps.app.goo.gl/AbCdEf123'), isNull);
  });

  test('rejects invalid coordinates and non-Google hosts', () {
    expect(
      GoogleMapsLink.parse('https://www.google.com/maps/@91,2,15z'),
      isNull,
    );
    expect(
      GoogleMapsLink.parse('https://example.com/maps/@6.37,2.39,15z'),
      isNull,
    );
  });
}
