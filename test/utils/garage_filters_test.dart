import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/data/garage_data.dart';
import 'package:garage_finder/utils/garage_filters.dart';

void main() {
  test('search matches names case-insensitively', () {
    final target = garages.first;
    expect(
      GarageFilters.filterAndSort(
        garages: garages,
        query: target.name.toUpperCase(),
      ),
      contains(target),
    );
  });

  test('city filter excludes other cities', () {
    final target = garages.first.city;
    expect(
      GarageFilters.filterAndSort(
        garages: garages,
        city: target,
      ).every((g) => g.city == target),
      isTrue,
    );
  });

  test('specialty filter excludes other specialties', () {
    final target = garages.first.specialty;
    expect(
      GarageFilters.filterAndSort(
        garages: garages,
        specialty: target,
      ).every((g) => g.specialty == target),
      isTrue,
    );
  });

  test('budget filter matches overlapping garage price ranges', () {
    final result = GarageFilters.filterAndSort(
      garages: garages,
      minimumPriceCfa: 10000,
      maximumPriceCfa: 80000,
    );
    expect(result, isNotEmpty);
    expect(
      result.every((garage) {
        final range = GarageFilters.priceRange(garage);
        return range.minimum != null &&
            range.maximum != null &&
            range.maximum! >= 10000 &&
            range.minimum! <= 80000;
      }),
      isTrue,
    );
  });

  test('SOS filter includes only open garages within ten kilometers', () {
    final result = GarageFilters.filterAndSort(garages: garages, sosOnly: true);
    expect(result.every((g) => g.isOpen && g.distanceKm <= 10), isTrue);
  });

  test('distance sort orders nearest first', () {
    final result = GarageFilters.filterAndSort(garages: garages);
    expect(
      result.first.distanceKm,
      garages.map((g) => g.distanceKm).reduce((a, b) => a < b ? a : b),
    );
  });

  test('unknown distance is sorted after known distances', () {
    final unknown = garages.first.copyWith(
      id: 'unknown-distance',
      distanceKm: 0,
      distanceKnown: false,
    );
    final result = GarageFilters.filterAndSort(
      garages: [unknown, garages.first],
    );
    expect(result.first.distanceKnown, isTrue);
    expect(result.last.distanceKnown, isFalse);
  });

  test('rating sort orders highest first', () {
    final result = GarageFilters.filterAndSort(
      garages: garages,
      sortMode: GarageSortMode.rating,
    );
    expect(
      result.first.rating,
      garages.map((g) => g.rating).reduce((a, b) => a > b ? a : b),
    );
  });

  test('response parser extracts minutes and handles missing digits', () {
    expect(GarageFilters.responseMinutes(garages.first), greaterThan(0));
    expect(
      GarageFilters.responseMinutes(
        garages.first.copyWith(responseTime: 'à confirmer'),
      ),
      999,
    );
  });

  test('city and specialty lists contain unique sorted values', () {
    expect(
      GarageFilters.cities(garages),
      orderedEquals(GarageFilters.cities(garages).toSet().toList()..sort()),
    );
    expect(
      GarageFilters.specialties(garages),
      orderedEquals(
        GarageFilters.specialties(garages).toSet().toList()..sort(),
      ),
    );
  });
}
