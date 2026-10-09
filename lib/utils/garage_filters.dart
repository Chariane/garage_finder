import '../models/garage.dart';

enum GarageSortMode { distance, rating, response }

class GarageFilters {
  const GarageFilters._();

  static int responseMinutes(Garage garage) {
    return int.tryParse(garage.responseTime.replaceAll(RegExp(r'\D'), '')) ??
        999;
  }

  static ({int? minimum, int? maximum}) priceRange(Garage garage) {
    final matches = RegExp(
      r'(\d+)\s*([kK]?)',
    ).allMatches(garage.priceLevel).toList();
    if (matches.isEmpty) return (minimum: null, maximum: null);
    final amounts = matches.map((match) {
      final amount = int.tryParse(match.group(1)!);
      if (amount == null) return null;
      return match.group(2)!.isNotEmpty ? amount * 1000 : amount;
    }).toList();
    return (
      minimum: amounts.first,
      maximum: amounts.length > 1 ? amounts.last : amounts.first,
    );
  }

  static List<String> cities(List<Garage> garages) {
    final values = garages.map((garage) => garage.city).toSet().toList()
      ..sort();
    return values;
  }

  static List<String> specialties(List<Garage> garages) {
    final values = {
      for (final garage in garages) ...garage.services,
      for (final garage in garages)
        if (garage.specialty.trim().isNotEmpty) garage.specialty,
    }.toList()..sort();
    return values;
  }

  static List<Garage> filterAndSort({
    required List<Garage> garages,
    String query = '',
    String? city,
    String? specialty,
    Set<String>? specialties,
    bool sosOnly = false,
    GarageSortMode sortMode = GarageSortMode.distance,
    int? minimumPriceCfa,
    int? maximumPriceCfa,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final selectedSpecialties =
        specialties ??
        {if (specialty != null && specialty.isNotEmpty) specialty};
    final filtered = garages.where((garage) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          garage.searchableText.contains(normalizedQuery);
      final matchesCity = city == null || city.isEmpty || garage.city == city;
      final matchesSpecialty =
          selectedSpecialties.isEmpty ||
          selectedSpecialties.any(
            (selected) =>
                garage.specialty.toLowerCase() == selected.toLowerCase() ||
                garage.services.any(
                  (service) => service.toLowerCase() == selected.toLowerCase(),
                ),
          );
      final matchesSos =
          !sosOnly ||
          (garage.isOpen && garage.distanceKnown && garage.distanceKm <= 10);
      final price = priceRange(garage);
      final matchesMinimumPrice =
          minimumPriceCfa == null ||
          (price.maximum != null && price.maximum! >= minimumPriceCfa);
      final matchesMaximumPrice =
          maximumPriceCfa == null ||
          (price.minimum != null && price.minimum! <= maximumPriceCfa);
      return matchesQuery &&
          matchesCity &&
          matchesSpecialty &&
          matchesSos &&
          matchesMinimumPrice &&
          matchesMaximumPrice;
    }).toList();

    filtered.sort((a, b) {
      return switch (sortMode) {
        GarageSortMode.rating => b.rating.compareTo(a.rating),
        GarageSortMode.response => responseMinutes(
          a,
        ).compareTo(responseMinutes(b)),
        GarageSortMode.distance =>
          a.distanceKnown == b.distanceKnown
              ? a.distanceKm.compareTo(b.distanceKm)
              : a.distanceKnown
              ? -1
              : 1,
      };
    });
    return filtered;
  }
}
