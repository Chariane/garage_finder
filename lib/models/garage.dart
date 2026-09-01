class Garage {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String chief;
  final String specialty;
  final String imageUrl;
  final String city;
  final String openingHours;
  final String description;
  final String sourceUrl;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final bool isOpen;
  final bool isVerified;
  final String responseTime;
  final String priceLevel;
  final List<String> services;
  final double? latitude;
  final double? longitude;

  Garage({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.chief,
    required this.specialty,
    required this.imageUrl,
    required this.city,
    required this.openingHours,
    required this.description,
    required this.sourceUrl,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.isOpen,
    required this.isVerified,
    required this.responseTime,
    required this.priceLevel,
    required this.services,
    this.latitude,
    this.longitude,
  });
}
