import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/database/garage_database.dart';
import '../models/garage.dart';
import '../utils/phone_verification.dart';

abstract class GarageRepository {
  Future<List<Garage>> getGarages();
  Future<void> seedIfEmpty(List<Garage> garages);
  Future<void> upsertGarage(Garage garage);
  Future<void> removeGarageFromCache(String id);
  Future<Set<String>> getFavoriteIds();
  Future<void> setFavorite(String garageId, bool isFavorite);
  Future<DateTime?> getCacheUpdatedAt();
  Future<void> setCacheUpdatedAt(DateTime timestamp);
}

abstract interface class RemoteGarageRepository {
  bool get lastReadWasOffline;
}

abstract interface class NearbyGarageRepository {
  Future<List<Garage>> findNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? query,
    String? city,
    String? specialty,
    List<String>? services,
    int? minimumPriceCfa,
    int? maximumPriceCfa,
  });
}

abstract interface class OwnerGarageRepository {
  Future<List<Garage>> getOwnedGarages();
  Future<String> requestGaragePhoneCode(String phone);
  Future<void> verifyGaragePhoneCode({
    required String challengeId,
    required String code,
  });
  Future<void> recordGarageOnSitePresence({
    required String garageId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool locationIsMocked,
  });
  Future<bool> isGaragePhoneVerified({
    required String garageId,
    required String phone,
  });
  Future<void> deleteGarage(String id);
  Future<String> uploadGaragePhoto({
    required String garageId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  });
  Future<void> updateAvailability(String garageId, String status);
  Future<List<Map<String, dynamic>>> getGarageRequests(String garageId);
  Stream<List<Map<String, dynamic>>> watchGarageRequests(String garageId);
  Future<void> updateRequestStatus(
    String requestId,
    String status, {
    int? responseEtaMinutes,
  });
}

abstract interface class CustomerWorkflowRepository {
  Future<void> createServiceRequest({
    required String garageId,
    required String phone,
    required String vehicle,
    required String issue,
    double? latitude,
    double? longitude,
  });
  Future<bool> cancelServiceRequest(String requestId);
  Future<void> submitReview(String garageId, int rating, String comment);
  Future<bool> canReviewGarage(String garageId);
  Future<List<Map<String, dynamic>>> getReviews(String garageId);
  Future<void> reportGarage(
    String garageId,
    String category,
    String description,
  );
  Future<List<Map<String, dynamic>>> getCustomerRequests();
  Stream<List<Map<String, dynamic>>> watchCustomerRequests();
  Future<List<Map<String, dynamic>>> getNotifications();
  Stream<List<Map<String, dynamic>>> watchNotifications();
  Future<void> markNotificationRead(String id);
}

abstract interface class ModerationRepository {
  Future<List<Map<String, dynamic>>> getReports();
  Future<void> updateReportStatus(String reportId, String status);
  Future<List<Map<String, dynamic>>> getGarageReviewQueue();
  Future<void> updateGarageReviewStatus(
    String garageId,
    String status, {
    String note = '',
  });
}

class SqfliteGarageRepository implements GarageRepository {
  final GarageDatabase database;

  const SqfliteGarageRepository(this.database);

  @override
  Future<List<Garage>> getGarages() async {
    final db = await database.instance;
    final rows = await db.query('garages', orderBy: 'distanceKm ASC');
    return rows.map(Garage.fromMap).toList();
  }

  @override
  Future<void> seedIfEmpty(List<Garage> garages) async {
    final db = await database.instance;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM garages'),
    );
    if ((count ?? 0) > 0) return;

    await db.transaction((txn) async {
      for (final garage in garages) {
        await txn.insert(
          'garages',
          garage.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> upsertGarage(Garage garage) async {
    final db = await database.instance;
    await db.insert(
      'garages',
      garage.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeGarageFromCache(String id) async {
    final db = await database.instance;
    await db.delete('garages', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    final db = await database.instance;
    final rows = await db.query('favorite_garages');
    return rows.map((row) => row['garageId']! as String).toSet();
  }

  @override
  Future<void> setFavorite(String garageId, bool isFavorite) async {
    final db = await database.instance;
    if (isFavorite) {
      await db.insert('favorite_garages', {
        'garageId': garageId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'favorite_garages',
        where: 'garageId = ?',
        whereArgs: [garageId],
      );
    }
  }

  @override
  Future<DateTime?> getCacheUpdatedAt() async {
    final db = await database.instance;
    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['garage_cache_updated_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value']! as String)?.toLocal();
  }

  @override
  Future<void> setCacheUpdatedAt(DateTime timestamp) async {
    final db = await database.instance;
    await db.insert('app_metadata', {
      'key': 'garage_cache_updated_at',
      'value': timestamp.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class InMemoryGarageRepository implements GarageRepository {
  final List<Garage> _garages;
  final Set<String> _favoriteIds;
  DateTime? _cacheUpdatedAt;

  InMemoryGarageRepository({
    List<Garage> garages = const [],
    Set<String> favoriteIds = const {},
  }) : _garages = List.of(garages),
       _favoriteIds = Set.of(favoriteIds);

  @override
  Future<List<Garage>> getGarages() async => List.unmodifiable(_garages);

  @override
  Future<void> seedIfEmpty(List<Garage> garages) async {
    if (_garages.isEmpty) _garages.addAll(garages);
  }

  @override
  Future<void> upsertGarage(Garage garage) async {
    final index = _garages.indexWhere((item) => item.id == garage.id);
    if (index == -1) {
      _garages.insert(0, garage);
    } else {
      _garages[index] = garage;
    }
  }

  @override
  Future<void> removeGarageFromCache(String id) async {
    _garages.removeWhere((garage) => garage.id == id);
  }

  @override
  Future<Set<String>> getFavoriteIds() async => Set.unmodifiable(_favoriteIds);

  @override
  Future<void> setFavorite(String garageId, bool isFavorite) async {
    if (isFavorite) {
      _favoriteIds.add(garageId);
    } else {
      _favoriteIds.remove(garageId);
    }
  }

  @override
  Future<DateTime?> getCacheUpdatedAt() async => _cacheUpdatedAt;

  @override
  Future<void> setCacheUpdatedAt(DateTime timestamp) async {
    _cacheUpdatedAt = timestamp;
  }
}

class SupabaseGarageRepository
    implements
        GarageRepository,
        NearbyGarageRepository,
        OwnerGarageRepository,
        CustomerWorkflowRepository,
        ModerationRepository,
        RemoteGarageRepository {
  final SupabaseClient client;
  final GarageRepository local;
  List<Garage>? _initialRemoteGarages;
  @override
  bool lastReadWasOffline = false;

  SupabaseGarageRepository({required this.client, required this.local});

  @override
  Future<void> seedIfEmpty(List<Garage> garages) async {
    try {
      _initialRemoteGarages = await _fetchGarages(owned: false);
      await _cache(_initialRemoteGarages!, replacePublicSnapshot: true);
      lastReadWasOffline = false;
    } catch (_) {
      lastReadWasOffline = true;
    }
  }

  @override
  Future<List<Garage>> getGarages() async {
    final initial = _initialRemoteGarages;
    _initialRemoteGarages = null;
    if (initial != null) return initial;
    try {
      final garages = await _fetchGarages(owned: false);
      await _cache(garages, replacePublicSnapshot: true);
      lastReadWasOffline = false;
      return garages;
    } catch (_) {
      lastReadWasOffline = true;
      return local.getGarages();
    }
  }

  Future<List<Garage>> _fetchGarages({required bool owned}) async {
    final rows =
        await client.rpc('list_garages', params: {'p_owned': owned})
            as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Garage.fromSupabaseMap)
        .toList(growable: false);
  }

  @override
  Future<List<Garage>> getOwnedGarages() async {
    if (client.auth.currentUser == null) {
      throw StateError('Connexion requise pour gérer un garage.');
    }
    final garages = await _fetchGarages(owned: true);
    await _cache(
      garages.where((garage) => garage.reviewStatus == 'approved').toList(),
    );
    return garages;
  }

  @override
  Future<String> requestGaragePhoneCode(String phone) async {
    final payload = await _invokeGaragePhoneVerification({
      'action': 'send_code',
      'phone': phone,
    });
    final challengeId = payload['challengeId'];
    if (challengeId is! String || challengeId.isEmpty) {
      throw StateError('verification_unavailable');
    }
    return challengeId;
  }

  @override
  Future<void> verifyGaragePhoneCode({
    required String challengeId,
    required String code,
  }) async {
    final payload = await _invokeGaragePhoneVerification({
      'action': 'verify_code',
      'challengeId': challengeId,
      'code': code,
    });
    if (payload['verified'] != true) {
      throw StateError('invalid_phone_code');
    }
  }

  @override
  Future<void> recordGarageOnSitePresence({
    required String garageId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool locationIsMocked,
  }) async {
    final payload = await _invokeGaragePhoneVerification({
      'action': 'record_presence',
      'garageId': garageId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'locationIsMocked': locationIsMocked,
    });
    if (payload['verified'] != true) {
      throw StateError('on_site_presence_failed');
    }
  }

  @override
  Future<bool> isGaragePhoneVerified({
    required String garageId,
    required String phone,
  }) async {
    final row = await client
        .from('garages')
        .select('phone,phone_verified_at')
        .eq('id', garageId)
        .maybeSingle();
    return row != null &&
        row['phone_verified_at'] != null &&
        normalizePhoneForVerification(row['phone'] as String? ?? '') ==
            normalizePhoneForVerification(phone);
  }

  Future<Map<String, dynamic>> _invokeGaragePhoneVerification(
    Map<String, Object?> body,
  ) async {
    try {
      final response = await client.functions.invoke(
        'garage-phone-verification',
        body: body,
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw StateError('verification_unavailable');
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      throw StateError(code?.toString() ?? 'verification_unavailable');
    }
  }

  @override
  Future<void> upsertGarage(Garage garage) async {
    final owner = client.auth.currentUser;
    if (owner == null) throw StateError('Connexion requise.');
    if (!_isUuid(garage.id)) throw ArgumentError('Garage id must be a UUID.');
    await client.from('garages').upsert({
      ...garage.toSupabaseMap(ownerId: owner.id),
      'id': garage.id,
    }, onConflict: 'id');
    if (garage.reviewStatus == 'approved') await local.upsertGarage(garage);
  }

  @override
  Future<void> removeGarageFromCache(String id) =>
      local.removeGarageFromCache(id);

  @override
  Future<DateTime?> getCacheUpdatedAt() => local.getCacheUpdatedAt();

  @override
  Future<void> setCacheUpdatedAt(DateTime timestamp) =>
      local.setCacheUpdatedAt(timestamp);

  @override
  Future<void> deleteGarage(String id) async {
    await client.from('garages').delete().eq('id', id);
    await local.removeGarageFromCache(id);
  }

  @override
  Future<void> updateAvailability(String garageId, String status) async {
    if (!{
      'available',
      'busy',
      'emergency_only',
      'unavailable',
    }.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await client
        .from('garages')
        .update({'availability_status': status})
        .eq('id', garageId);
  }

  @override
  Future<List<Map<String, dynamic>>> getGarageRequests(String garageId) async {
    final rows = await client.rpc(
      'owner_garage_requests',
      params: {'p_garage_id': garageId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchGarageRequests(String garageId) =>
      client
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('garage_id', garageId)
          .order('created_at', ascending: false)
          .asyncMap((_) => getGarageRequests(garageId));

  @override
  Future<List<Map<String, dynamic>>> getCustomerRequests() async {
    final rows = await client
        .from('service_requests')
        .select('*, garages(name, phone, address, city)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCustomerRequests() {
    final user = client.auth.currentUser;
    if (user == null) return const Stream.empty();
    return client
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    String status, {
    int? responseEtaMinutes,
  }) async {
    if (!{'accepted', 'en_route', 'completed', 'declined'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await client
        .from('service_requests')
        .update({'status': status, 'response_eta_minutes': responseEtaMinutes})
        .eq('id', requestId);
  }

  @override
  Future<bool> cancelServiceRequest(String requestId) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Connexion requise.');
    final row = await client
        .from('service_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .eq('customer_id', user.id)
        .eq('status', 'pending')
        .select('id')
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> createServiceRequest({
    required String garageId,
    required String phone,
    required String vehicle,
    required String issue,
    double? latitude,
    double? longitude,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Connexion requise.');
    await client.from('service_requests').insert({
      'garage_id': garageId,
      'customer_id': user.id,
      'customer_phone': phone.trim(),
      'vehicle': vehicle.trim(),
      'issue_description': issue.trim(),
      'customer_latitude': latitude,
      'customer_longitude': longitude,
    });
  }

  @override
  Future<void> submitReview(String garageId, int rating, String comment) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Connexion requise.');
    if (rating < 1 || rating > 5) throw ArgumentError.value(rating, 'rating');
    await client.from('garage_reviews').upsert({
      'garage_id': garageId,
      'customer_id': user.id,
      'rating': rating,
      'comment': comment.trim(),
    }, onConflict: 'garage_id,customer_id');
  }

  @override
  Future<bool> canReviewGarage(String garageId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final row = await client
        .from('service_requests')
        .select('id')
        .eq('garage_id', garageId)
        .eq('customer_id', user.id)
        .eq('status', 'completed')
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<List<Map<String, dynamic>>> getReviews(String garageId) async {
    final rows = await client
        .from('garage_reviews')
        .select('rating, comment, created_at')
        .eq('garage_id', garageId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> reportGarage(
    String garageId,
    String category,
    String description,
  ) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Connexion requise.');
    if (!{
      'phone',
      'address',
      'closed',
      'behavior',
      'other',
    }.contains(category)) {
      throw ArgumentError.value(category, 'category');
    }
    await client.from('garage_reports').insert({
      'garage_id': garageId,
      'reporter_id': user.id,
      'category': category,
      'description': description.trim(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final rows = await client
        .from('user_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final user = client.auth.currentUser;
    if (user == null) return const Stream.empty();
    return client
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await client
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<List<Map<String, dynamic>>> getReports() async {
    final rows = await client
        .from('garage_reports')
        .select('*, garages(name, city)')
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    if (!{'reviewing', 'resolved', 'dismissed'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await client
        .from('garage_reports')
        .update({'status': status})
        .eq('id', reportId);
  }

  @override
  Future<List<Map<String, dynamic>>> getGarageReviewQueue() async {
    final rows = await client
        .from('garages')
        .select(
          'id,name,address,city,phone,specialty,services,description,opening_hours,price_min_cfa,price_max_cfa,photo_urls,is_open,availability_status,availability_updated_at,response_time_minutes,review_status,moderation_note,phone_verified_at,on_site_verified_at,automated_review_status,automated_review_reasons',
        )
        .inFilter('review_status', ['pending', 'rejected'])
        .order('created_at', ascending: true)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> updateGarageReviewStatus(
    String garageId,
    String status, {
    String note = '',
  }) async {
    if (!{'approved', 'rejected'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    final normalizedNote = note.trim();
    if (status == 'rejected' &&
        (normalizedNote.length < 10 || normalizedNote.length > 500)) {
      throw ArgumentError(
        'Le motif de refus doit contenir 10 à 500 caractères.',
      );
    }
    await client
        .from('garages')
        .update({
          'review_status': status,
          'moderation_note': status == 'rejected' ? normalizedNote : '',
        })
        .eq('id', garageId);
  }

  @override
  Future<String> uploadGaragePhoto({
    required String garageId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final owner = client.auth.currentUser;
    if (owner == null) throw StateError('Connexion requise.');
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '${owner.id}/$garageId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await client.storage
        .from('garage-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return client.storage.from('garage-photos').getPublicUrl(path);
  }

  @override
  Future<Set<String>> getFavoriteIds() => local.getFavoriteIds();

  @override
  Future<void> setFavorite(String garageId, bool isFavorite) =>
      local.setFavorite(garageId, isFavorite);

  @override
  Future<List<Garage>> findNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? query,
    String? city,
    String? specialty,
    List<String>? services,
    int? minimumPriceCfa,
    int? maximumPriceCfa,
  }) async {
    final serviceFilters = {...?services, ?_nonEmpty(specialty)};
    try {
      final rows =
          await client.rpc(
                'nearby_garages',
                params: {
                  'p_latitude': latitude,
                  'p_longitude': longitude,
                  'p_radius_meters': radiusMeters,
                  'p_query': _nonEmpty(query),
                  'p_city': _nonEmpty(city),
                  'p_specialty': null,
                  'p_services': serviceFilters.isEmpty
                      ? null
                      : serviceFilters.toList(growable: false),
                  'p_min_price_cfa': minimumPriceCfa,
                  'p_max_price_cfa': maximumPriceCfa,
                },
              )
              as List<dynamic>;
      final garages = rows
          .whereType<Map<String, dynamic>>()
          .map(Garage.fromSupabaseMap)
          .toList(growable: false);
      await _cache(garages, replacePublicSnapshot: true);
      lastReadWasOffline = false;
      return garages;
    } catch (_) {
      lastReadWasOffline = true;
      final cached = await local.getGarages();
      return cached
          .where(
            (garage) => garage.latitude != null && garage.longitude != null,
          )
          .map((garage) {
            final lat = garage.latitude;
            final lon = garage.longitude;
            final meters = Geolocator.distanceBetween(
              latitude,
              longitude,
              lat!,
              lon!,
            );
            return garage.copyWith(
              distanceKm: meters / 1000,
              distanceKnown: true,
            );
          })
          .where((garage) => garage.distanceKm * 1000 <= radiusMeters)
          .toList(growable: false);
    }
  }

  Future<void> _cache(
    List<Garage> garages, {
    bool replacePublicSnapshot = false,
  }) async {
    if (replacePublicSnapshot) {
      final current = await local.getGarages();
      final publicIds = garages.map((garage) => garage.id).toSet();
      for (final garage in current) {
        if (!publicIds.contains(garage.id)) {
          await local.removeGarageFromCache(garage.id);
        }
      }
    }
    for (final garage in garages) {
      if (garage.reviewStatus == 'approved') {
        await local.upsertGarage(garage);
      }
    }
    if (replacePublicSnapshot) {
      await local.setCacheUpdatedAt(DateTime.now());
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
