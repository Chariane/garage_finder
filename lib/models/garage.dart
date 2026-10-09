import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
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
  final bool distanceKnown;
  final bool isOpen;
  final String availabilityStatus;
  final DateTime? availabilityUpdatedAt;
  final bool isVerified;
  final String reviewStatus;
  final String moderationNote;
  final DateTime? phoneVerifiedAt;
  final DateTime? onSiteVerifiedAt;
  final String automatedReviewStatus;
  final List<String> automatedReviewReasons;
  final String responseTime;
  final String priceLevel;
  final List<String> services;
  final double? latitude;
  final double? longitude;

  const Garage({
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
    this.distanceKnown = true,
    required this.isOpen,
    this.availabilityStatus = 'available',
    this.availabilityUpdatedAt,
    required this.isVerified,
    this.reviewStatus = 'approved',
    this.moderationNote = '',
    this.phoneVerifiedAt,
    this.onSiteVerifiedAt,
    this.automatedReviewStatus = 'not_checked',
    this.automatedReviewReasons = const [],
    required this.responseTime,
    required this.priceLevel,
    required this.services,
    this.latitude,
    this.longitude,
  });

  factory Garage.fromMap(Map<String, Object?> map) {
    final rawServices = map['services'];
    final services = rawServices is String
        ? (jsonDecode(rawServices) as List<dynamic>).cast<String>()
        : (rawServices as List<dynamic>? ?? const <dynamic>[]).cast<String>();

    return Garage(
      id: map['id']! as String,
      name: map['name']! as String,
      address: map['address']! as String,
      phone: map['phone']! as String,
      chief: map['chief']! as String,
      specialty: map['specialty']! as String,
      imageUrl: map['imageUrl']! as String,
      city: map['city']! as String,
      openingHours: map['openingHours']! as String,
      description: map['description']! as String,
      sourceUrl: map['sourceUrl']! as String,
      rating: (map['rating']! as num).toDouble(),
      reviewCount: map['reviewCount']! as int,
      distanceKm: (map['distanceKm']! as num).toDouble(),
      distanceKnown: map['distanceKnown'] == null
          ? true
          : _asBool(map['distanceKnown']),
      isOpen: _asBool(map['isOpen']),
      availabilityStatus: map['availabilityStatus'] as String? ?? 'available',
      availabilityUpdatedAt: map['availabilityUpdatedAt'] is String
          ? DateTime.tryParse(map['availabilityUpdatedAt']! as String)
          : null,
      isVerified: _asBool(map['isVerified']),
      reviewStatus:
          map['reviewStatus'] as String? ??
          (_asBool(map['isVerified']) ? 'approved' : 'pending'),
      moderationNote: map['moderationNote'] as String? ?? '',
      phoneVerifiedAt: map['phoneVerifiedAt'] is String
          ? DateTime.tryParse(map['phoneVerifiedAt']! as String)
          : null,
      onSiteVerifiedAt: map['onSiteVerifiedAt'] is String
          ? DateTime.tryParse(map['onSiteVerifiedAt']! as String)
          : null,
      automatedReviewStatus:
          map['automatedReviewStatus'] as String? ?? 'not_checked',
      automatedReviewReasons:
          (map['automatedReviewReasons'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      responseTime: map['responseTime']! as String,
      priceLevel: map['priceLevel']! as String,
      services: services,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  factory Garage.fromSupabaseMap(Map<String, dynamic> map) {
    final photoUrls = (map['photo_urls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final openingHours = map['opening_hours'];
    final distanceMeters = map['distance_meters'];
    final minPrice = map['price_min_cfa'];
    final maxPrice = map['price_max_cfa'];
    return Garage(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      chief: map['chief'] as String? ?? '',
      specialty: map['specialty'] as String? ?? '',
      imageUrl: photoUrls.isEmpty
          ? 'assets/images/garage_service.png'
          : photoUrls.first,
      city: map['city'] as String? ?? '',
      openingHours: openingHours is String
          ? openingHours
          : jsonEncode(openingHours ?? const <String, dynamic>{}),
      description: map['description'] as String? ?? '',
      sourceUrl: 'Garage Finder',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      distanceKm: distanceMeters is num
          ? distanceMeters.toDouble() / 1000
          : (map['distance_km'] as num?)?.toDouble() ?? 0,
      distanceKnown: distanceMeters is num || map['distance_km'] is num,
      isOpen: _asBool(map['is_open']),
      availabilityStatus: map['availability_status'] as String? ?? 'available',
      availabilityUpdatedAt: map['availability_updated_at'] is String
          ? DateTime.tryParse(map['availability_updated_at']! as String)
          : null,
      isVerified:
          map['is_verified'] == true || map['review_status'] == 'approved',
      reviewStatus: map['review_status'] as String? ?? 'approved',
      moderationNote: map['moderation_note'] as String? ?? '',
      phoneVerifiedAt: map['phone_verified_at'] is String
          ? DateTime.tryParse(map['phone_verified_at']! as String)
          : null,
      onSiteVerifiedAt: map['on_site_verified_at'] is String
          ? DateTime.tryParse(map['on_site_verified_at']! as String)
          : null,
      automatedReviewStatus:
          map['automated_review_status'] as String? ?? 'not_checked',
      automatedReviewReasons:
          (map['automated_review_reasons'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      responseTime: map['response_time_minutes'] is num
          ? '${(map['response_time_minutes'] as num).toInt()} min'
          : map['response_time'] as String? ?? '',
      priceLevel: _formatPrice(minPrice, maxPrice),
      services: (map['services'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toSupabaseMap({required String ownerId}) => {
    'owner_id': ownerId,
    'name': name.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'phone': phone.trim(),
    'specialty': specialty.trim(),
    'services': services,
    'description': description.trim(),
    'opening_hours': _parseOpeningHours(openingHours),
    'response_time_minutes': _extractResponseMinutes(responseTime),
    'price_min_cfa': _extractPriceMinimum(priceLevel),
    'price_max_cfa': _extractPriceMaximum(priceLevel),
    'photo_urls': imageUrl.startsWith('http') ? [imageUrl] : <String>[],
    'location': 'POINT(${longitude ?? 0} ${latitude ?? 0})',
    'is_open': isOpen,
    'availability_status': availabilityStatus,
  };

  static bool _asBool(Object? value) =>
      value == true || value == 1 || value == '1';

  static String _formatPrice(Object? minimum, Object? maximum) {
    if (minimum == null && maximum == null) return '';
    if (minimum == null) return '≤ ${_formatCfa(maximum)} FCFA';
    if (maximum == null) return '≥ ${_formatCfa(minimum)} FCFA';
    return '${_formatCfa(minimum)}–${_formatCfa(maximum)} FCFA';
  }

  static String _formatCfa(Object? value) => (value as num).toInt().toString();

  static int? _extractPriceMinimum(String value) {
    final range = RegExp(r'^\s*(\d*)\s*[-–]\s*(\d*)').firstMatch(value);
    if (range != null) {
      final amount = range.group(1);
      return amount == null || amount.isEmpty ? null : int.tryParse(amount);
    }
    final matches = RegExp(r'\d+').allMatches(value).toList();
    return matches.isEmpty ? null : int.tryParse(matches.first.group(0)!);
  }

  static int? _extractPriceMaximum(String value) {
    final range = RegExp(r'^\s*(\d*)\s*[-–]\s*(\d*)').firstMatch(value);
    if (range != null) {
      final amount = range.group(2);
      return amount == null || amount.isEmpty ? null : int.tryParse(amount);
    }
    final matches = RegExp(r'\d+').allMatches(value).toList();
    return matches.length < 2 ? null : int.tryParse(matches[1].group(0)!);
  }

  static int? priceMinimum(String value) => _extractPriceMinimum(value);
  static int? priceMaximum(String value) => _extractPriceMaximum(value);

  static int? _extractResponseMinutes(String value) {
    final minutes = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    return minutes != null && minutes <= 1440 ? minutes : null;
  }

  static Map<String, dynamic> _parseOpeningHours(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'chief': chief,
      'specialty': specialty,
      'imageUrl': imageUrl,
      'city': city,
      'openingHours': openingHours,
      'description': description,
      'sourceUrl': sourceUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'distanceKm': distanceKm,
      'distanceKnown': distanceKnown ? 1 : 0,
      'isOpen': isOpen ? 1 : 0,
      'availabilityStatus': availabilityStatus,
      'availabilityUpdatedAt': availabilityUpdatedAt?.toIso8601String(),
      'isVerified': isVerified ? 1 : 0,
      'reviewStatus': reviewStatus,
      'responseTime': responseTime,
      'priceLevel': priceLevel,
      'services': jsonEncode(services),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Garage copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? chief,
    String? specialty,
    String? imageUrl,
    String? city,
    String? openingHours,
    String? description,
    String? sourceUrl,
    double? rating,
    int? reviewCount,
    double? distanceKm,
    bool? distanceKnown,
    bool? isOpen,
    String? availabilityStatus,
    DateTime? availabilityUpdatedAt,
    bool? isVerified,
    String? reviewStatus,
    String? moderationNote,
    DateTime? phoneVerifiedAt,
    DateTime? onSiteVerifiedAt,
    String? automatedReviewStatus,
    List<String>? automatedReviewReasons,
    String? responseTime,
    String? priceLevel,
    List<String>? services,
    double? latitude,
    double? longitude,
  }) {
    return Garage(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      chief: chief ?? this.chief,
      specialty: specialty ?? this.specialty,
      imageUrl: imageUrl ?? this.imageUrl,
      city: city ?? this.city,
      openingHours: openingHours ?? this.openingHours,
      description: description ?? this.description,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceKnown: distanceKnown ?? this.distanceKnown,
      isOpen: isOpen ?? this.isOpen,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      availabilityUpdatedAt:
          availabilityUpdatedAt ?? this.availabilityUpdatedAt,
      isVerified: isVerified ?? this.isVerified,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      moderationNote: moderationNote ?? this.moderationNote,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      onSiteVerifiedAt: onSiteVerifiedAt ?? this.onSiteVerifiedAt,
      automatedReviewStatus:
          automatedReviewStatus ?? this.automatedReviewStatus,
      automatedReviewReasons:
          automatedReviewReasons ?? this.automatedReviewReasons,
      responseTime: responseTime ?? this.responseTime,
      priceLevel: priceLevel ?? this.priceLevel,
      services: services ?? this.services,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get searchableText => [
    name,
    address,
    phone,
    chief,
    specialty,
    city,
    description,
    ...services,
  ].join(' ').toLowerCase();

  @override
  bool operator ==(Object other) {
    return other is Garage &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.phone == phone &&
        other.chief == chief &&
        other.specialty == specialty &&
        other.imageUrl == imageUrl &&
        other.city == city &&
        other.openingHours == openingHours &&
        other.description == description &&
        other.sourceUrl == sourceUrl &&
        other.rating == rating &&
        other.reviewCount == reviewCount &&
        other.distanceKm == distanceKm &&
        other.distanceKnown == distanceKnown &&
        other.isOpen == isOpen &&
        other.availabilityStatus == availabilityStatus &&
        other.availabilityUpdatedAt == availabilityUpdatedAt &&
        other.isVerified == isVerified &&
        other.reviewStatus == reviewStatus &&
        other.moderationNote == moderationNote &&
        other.phoneVerifiedAt == phoneVerifiedAt &&
        other.onSiteVerifiedAt == onSiteVerifiedAt &&
        other.automatedReviewStatus == automatedReviewStatus &&
        listEquals(other.automatedReviewReasons, automatedReviewReasons) &&
        other.responseTime == responseTime &&
        other.priceLevel == priceLevel &&
        listEquals(other.services, services) &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    address,
    phone,
    chief,
    specialty,
    imageUrl,
    city,
    openingHours,
    description,
    sourceUrl,
    rating,
    reviewCount,
    distanceKm,
    distanceKnown,
    isOpen,
    availabilityStatus,
    availabilityUpdatedAt,
    isVerified,
    reviewStatus,
    moderationNote,
    phoneVerifiedAt,
    onSiteVerifiedAt,
    automatedReviewStatus,
    Object.hashAll(automatedReviewReasons),
    responseTime,
    priceLevel,
    Object.hashAll(services),
    latitude,
    longitude,
  ]);
}
