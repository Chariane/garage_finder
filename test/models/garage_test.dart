import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/data/garage_data.dart';
import 'package:garage_finder/models/garage.dart';

void main() {
  final garage = garages.first;

  test('map round trip preserves garage data', () {
    expect(Garage.fromMap(garage.toMap()), garage);
  });

  test('SQLite map encodes booleans as integers and services as JSON', () {
    final map = garage.toMap();
    expect(map['isOpen'], isA<int>());
    expect(map['services'], isA<String>());
  });

  test('copyWith changes requested values and keeps other values', () {
    final updated = garage.copyWith(name: 'Atelier Test');
    expect(updated.name, 'Atelier Test');
    expect(updated.city, garage.city);
  });

  test('searchable text includes service names and is normalized', () {
    expect(
      garage.searchableText,
      contains(garage.services.first.toLowerCase()),
    );
    expect(garage.searchableText, garage.searchableText.toLowerCase());
  });

  test(
    'Supabase mapping preserves moderation, coordinates, and exact distance',
    () {
      final mapped = Garage.fromSupabaseMap({
        'id': 'garage-id',
        'name': 'Atelier Centre',
        'address': 'Rue 12',
        'city': 'Cotonou',
        'phone': '+229 01 00 00 00',
        'specialty': 'Mécanique',
        'services': ['Diagnostic', 'Freins'],
        'description': 'Atelier auto',
        'opening_hours': {
          'monday': ['08:00', '18:00'],
        },
        'price_min_cfa': 10000,
        'price_max_cfa': 50000,
        'photo_urls': ['https://example.com/garage.webp'],
        'is_open': true,
        'availability_status': 'emergency_only',
        'availability_updated_at': '2026-10-07T10:00:00Z',
        'latitude': 6.37,
        'longitude': 2.39,
        'distance_meters': 1250,
        'response_time_minutes': 24,
        'is_verified': false,
        'review_status': 'pending',
        'moderation_note': 'Adresse incomplète',
      });

      expect(mapped.distanceKm, 1.25);
      expect(mapped.distanceKnown, isTrue);
      expect(mapped.reviewStatus, 'pending');
      expect(mapped.moderationNote, 'Adresse incomplète');
      expect(mapped.isVerified, isFalse);
      expect(mapped.latitude, 6.37);
      expect(mapped.priceLevel, '10000–50000 FCFA');
      expect(mapped.responseTime, '24 min');
      expect(mapped.availabilityStatus, 'emergency_only');
      expect(mapped.availabilityUpdatedAt, DateTime.utc(2026, 10, 7, 10));
    },
  );

  test(
    'Supabase write encodes a real PostGIS point and optional price range',
    () {
      final mapped = garage
          .copyWith(
            priceLevel: '10000-50000',
            responseTime: '24 min',
            availabilityStatus: 'busy',
            latitude: 6.37,
            longitude: 2.39,
          )
          .toSupabaseMap(ownerId: 'owner-id');

      expect(mapped['location'], 'POINT(2.39 6.37)');
      expect(mapped['price_min_cfa'], 10000);
      expect(mapped['price_max_cfa'], 50000);
      expect(mapped['response_time_minutes'], 24);
      expect(mapped['availability_status'], 'busy');
      expect(mapped['owner_id'], 'owner-id');
      expect(mapped.containsKey('review_status'), isFalse);
    },
  );
}
