import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/garage_data.dart' as seed_data;
import '../models/garage.dart';
import '../repositories/garage_repository.dart';
import '../utils/garage_filters.dart';

class GarageController extends ChangeNotifier {
  final GarageRepository repository;
  final List<Garage> seedGarages;

  GarageController({required this.repository, List<Garage>? seedGarages})
    : seedGarages = seedGarages ?? seed_data.garages;

  final List<Garage> _garages = [];
  final Set<String> _favoriteIds = {};
  double? _userLatitude;
  double? _userLongitude;
  int _searchRadiusMeters = 10000;
  int? _minimumPriceCfa;
  int? _maximumPriceCfa;

  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';
  String? _city;
  String? _specialty;
  bool _sosOnly = false;
  GarageSortMode _sortMode = GarageSortMode.distance;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Garage> get garages => List.unmodifiable(_garages);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  String get query => _query;
  String? get city => _city;
  String? get specialty => _specialty;
  bool get sosOnly => _sosOnly;
  GarageSortMode get sortMode => _sortMode;
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  int get searchRadiusMeters => _searchRadiusMeters;
  int? get minimumPriceCfa => _minimumPriceCfa;
  int? get maximumPriceCfa => _maximumPriceCfa;
  bool get hasSearchLocation => _userLatitude != null && _userLongitude != null;

  List<String> get cities => GarageFilters.cities(_garages);
  List<String> get specialties => GarageFilters.specialties(_garages);

  List<Garage> get filteredGarages => GarageFilters.filterAndSort(
    garages: _garages,
    query: _query,
    city: _city,
    specialty: _specialty,
    sosOnly: _sosOnly,
    sortMode: _sortMode,
    minimumPriceCfa: _minimumPriceCfa,
    maximumPriceCfa: _maximumPriceCfa,
  );

  List<Garage> get favorites =>
      _garages.where((garage) => _favoriteIds.contains(garage.id)).toList();

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await repository.seedIfEmpty(seedGarages);
      _garages
        ..clear()
        ..addAll(await repository.getGarages());
      _favoriteIds
        ..clear()
        ..addAll(await repository.getFavoriteIds());
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _userLatitude = latitude;
    _userLongitude = longitude;
    _searchRadiusMeters = radiusMeters;
    notifyListeners();
    try {
      final List<Garage> results;
      final source = repository;
      if (source is NearbyGarageRepository) {
        results = await (source as NearbyGarageRepository).findNearby(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          query: _query,
          city: _city,
          specialty: _specialty,
          minimumPriceCfa: _minimumPriceCfa,
          maximumPriceCfa: _maximumPriceCfa,
        );
      } else {
        final allGarages = await repository.getGarages();
        results = allGarages
            .where(
              (garage) => garage.latitude != null && garage.longitude != null,
            )
            .map((garage) {
              final meters = Geolocator.distanceBetween(
                latitude,
                longitude,
                garage.latitude!,
                garage.longitude!,
              );
              return garage.copyWith(
                distanceKm: meters / 1000,
                distanceKnown: true,
              );
            })
            .where((garage) => garage.distanceKm * 1000 <= radiusMeters)
            .toList(growable: false);
      }
      _garages
        ..clear()
        ..addAll(results);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSearchLocation() async {
    _userLatitude = null;
    _userLongitude = null;
    await load();
  }

  Garage? findById(String id) {
    for (final garage in _garages) {
      if (garage.id == id) return garage;
    }
    return null;
  }

  Future<void> refreshGarage(String id) async {
    final latest = (await repository.getGarages()).where(
      (item) => item.id == id,
    );
    if (latest.isEmpty) return;
    final previous = findById(id);
    final updated = latest.first.copyWith(
      distanceKm: previous?.distanceKm,
      distanceKnown: previous?.distanceKnown,
    );
    final index = _garages.indexWhere((item) => item.id == id);
    if (index >= 0) _garages[index] = updated;
    notifyListeners();
  }

  bool isFavorite(String garageId) => _favoriteIds.contains(garageId);

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setCity(String? value) {
    _city = value;
    notifyListeners();
  }

  void setSpecialty(String? value) {
    _specialty = value;
    notifyListeners();
  }

  void setSortMode(GarageSortMode value) {
    _sortMode = value;
    notifyListeners();
  }

  void setSearchRadius(int value) {
    _searchRadiusMeters = value.clamp(5000, 100000).toInt();
    notifyListeners();
  }

  void setPriceRange({int? minimumCfa, int? maximumCfa}) {
    _minimumPriceCfa = minimumCfa;
    _maximumPriceCfa = maximumCfa;
    notifyListeners();
  }

  void setSosOnly(bool value) {
    _sosOnly = value;
    if (value) _sortMode = GarageSortMode.response;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _city = null;
    _specialty = null;
    _sosOnly = false;
    _minimumPriceCfa = null;
    _maximumPriceCfa = null;
    _sortMode = GarageSortMode.distance;
    notifyListeners();
  }

  Future<void> addGarage(Garage garage) async {
    await repository.upsertGarage(garage);
    _garages.removeWhere((item) => item.id == garage.id);
    _garages.insert(0, garage);
    notifyListeners();
  }

  Future<void> toggleFavorite(String garageId) async {
    final nextValue = !_favoriteIds.contains(garageId);
    await repository.setFavorite(garageId, nextValue);
    if (nextValue) {
      _favoriteIds.add(garageId);
    } else {
      _favoriteIds.remove(garageId);
    }
    notifyListeners();
  }
}
