import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/controllers/garage_controller.dart';
import 'package:garage_finder/data/garage_data.dart';
import 'package:garage_finder/repositories/garage_repository.dart';
import 'package:garage_finder/utils/garage_filters.dart';

void main() {
  late InMemoryGarageRepository repository;
  late GarageController controller;

  setUp(() async {
    repository = InMemoryGarageRepository();
    controller = GarageController(repository: repository);
    await controller.load();
  });

  test('load seeds the repository once and exposes garages', () async {
    expect(controller.garages, isNotEmpty);
    expect(controller.isLoading, isFalse);
    expect((await repository.getGarages()).length, garages.length);
  });

  test('cache freshness timestamp is persisted by the repository', () async {
    final timestamp = DateTime.utc(2026, 10, 8, 9, 30);
    await repository.setCacheUpdatedAt(timestamp);
    expect(await repository.getCacheUpdatedAt(), timestamp);
  });

  test('filter setters update filtered results', () {
    final city = controller.garages.first.city;
    controller.setCity(city);
    expect(
      controller.filteredGarages.every((garage) => garage.city == city),
      isTrue,
    );
  });

  test('budget filter state updates the visible garage results', () {
    controller.setPriceRange(minimumCfa: 10000, maximumCfa: 50000);
    expect(controller.minimumPriceCfa, 10000);
    expect(controller.maximumPriceCfa, 50000);
    expect(controller.filteredGarages, isNotEmpty);
  });

  test('clearFilters resets search and sorting state', () {
    controller.setQuery('unknown');
    controller.setSosOnly(true);
    controller.setSortMode(GarageSortMode.rating);
    controller.clearFilters();
    expect(controller.query, isEmpty);
    expect(controller.sosOnly, isFalse);
    expect(controller.sortMode, GarageSortMode.distance);
    expect(controller.filteredGarages, isNotEmpty);
  });

  test(
    'favorite changes persist through repository and notify listeners',
    () async {
      var notifications = 0;
      controller.addListener(() => notifications++);
      final id = controller.garages.first.id;
      await controller.toggleFavorite(id);
      expect(controller.isFavorite(id), isTrue);
      expect(await repository.getFavoriteIds(), contains(id));
      expect(notifications, 1);
    },
  );

  test('findById returns null for unknown identifiers', () {
    expect(controller.findById('not-present'), isNull);
  });

  test(
    'nearby search computes distances from the supplied exact point',
    () async {
      final origin = controller.garages.first;
      await controller.searchNearby(
        latitude: origin.latitude!,
        longitude: origin.longitude!,
        radiusMeters: 5000,
      );

      expect(controller.hasSearchLocation, isTrue);
      expect(controller.searchRadiusMeters, 5000);
      expect(controller.garages, isNotEmpty);
      expect(
        controller.garages.every((garage) => garage.distanceKnown),
        isTrue,
      );
      expect(controller.garages.first.distanceKm, 0);
    },
  );
}
