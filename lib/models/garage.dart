class Garage {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String chief;
  final String specialty;
  final String imageUrl;
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
    this.latitude,
    this.longitude,
  });
}