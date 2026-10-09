import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';
import '../utils/garage_specialties.dart';
import '../utils/google_maps_link.dart';
import '../utils/phone_verification.dart';

class GarageOwnerFormScreen extends StatefulWidget {
  final Garage? initialGarage;

  const GarageOwnerFormScreen({super.key, this.initialGarage});

  @override
  State<GarageOwnerFormScreen> createState() => _GarageOwnerFormScreenState();
}

class _GarageOwnerFormScreenState extends State<GarageOwnerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _phoneCode = TextEditingController();
  final _otherSpecialty = TextEditingController();
  final _services = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _mapLink = TextEditingController();
  final _minimumPrice = TextEditingController();
  final _maximumPrice = TextEditingController();
  final _responseMinutes = TextEditingController();
  Geocoding? _geocoding;
  final Map<String, bool> _dayOpen = {
    'mon': true,
    'tue': true,
    'wed': true,
    'thu': true,
    'fri': true,
    'sat': true,
    'sun': false,
  };
  final Map<String, TimeOfDay> _dayStart = {};
  final Map<String, TimeOfDay> _dayEnd = {};
  final Set<String> _selectedSpecialties = {};
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _isOpen = false;
  bool _isSaving = false;
  bool _isFindingAddress = false;
  bool _isPickingPhoto = false;
  bool _isSendingPhoneCode = false;
  bool _isVerifyingPhoneCode = false;
  bool _isVerifyingPresence = false;
  String? _locationError;
  String? _specialtyError;
  String? _photoError;
  String? _phoneChallengeId;
  String? _verifiedPhone;
  String? _phoneVerificationMessage;
  String? _phoneVerificationError;
  String? _onSitePresenceError;
  Position? _onSitePosition;
  double? _accuracyMeters;

  Geocoding? get _platformGeocoding {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    return _geocoding ??= Geocoding(locale: const Locale('fr', 'BJ'));
  }

  @override
  void initState() {
    super.initState();
    final accountLocation = context.read<AuthController>().user?.userMetadata;
    _address.text = accountLocation?['garage_address']?.toString() ?? '';
    _latitude.text = accountLocation?['garage_latitude']?.toString() ?? '';
    _longitude.text = accountLocation?['garage_longitude']?.toString() ?? '';
    final garage = widget.initialGarage;
    if (garage == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingPhoneVerification(garage);
    });
    _name.text = garage.name;
    _address.text = garage.address;
    _city.text = garage.city;
    _phone.text = garage.phone;
    for (final value in [garage.specialty, ...garage.services]) {
      final category = GarageSpecialties.idForLegacyValue(value);
      if (category != null) _selectedSpecialties.add(category);
    }
    final legacySpecialty =
        GarageSpecialties.idForLegacyValue(garage.specialty) == null;
    if (legacySpecialty) {
      _selectedSpecialties.add('autre');
      _otherSpecialty.text = garage.specialty;
    }
    final customServices = garage.services
        .where((service) => GarageSpecialties.idForLegacyValue(service) == null)
        .toList();
    customServices.remove(garage.specialty);
    if (_selectedSpecialties.contains('autre') &&
        _otherSpecialty.text.isEmpty &&
        customServices.isNotEmpty) {
      _otherSpecialty.text = customServices.removeAt(0);
    }
    _services.text = [...customServices].join(', ');
    _description.text = garage.description;
    _latitude.text = garage.latitude?.toString() ?? '';
    _longitude.text = garage.longitude?.toString() ?? '';
    _minimumPrice.text =
        Garage.priceMinimum(garage.priceLevel)?.toString() ?? '';
    _maximumPrice.text =
        Garage.priceMaximum(garage.priceLevel)?.toString() ?? '';
    _responseMinutes.text = garage.responseTime.replaceAll(RegExp(r'\D'), '');
    _isOpen = garage.isOpen;
    _availabilityStatus = garage.availabilityStatus;
    try {
      final hours = jsonDecode(garage.openingHours) as Map<String, dynamic>;
      const fullDay = {
        'mon': 'monday',
        'tue': 'tuesday',
        'wed': 'wednesday',
        'thu': 'thursday',
        'fri': 'friday',
        'sat': 'saturday',
        'sun': 'sunday',
      };
      for (final day in _dayOpen.keys) {
        final entry = hours[day] ?? hours[fullDay[day]];
        if (entry is Map<String, dynamic>) {
          _dayOpen[day] = entry['closed'] != true;
          _dayStart[day] = _parseTime(entry['open'] as String? ?? '08:00');
          _dayEnd[day] = _parseTime(entry['close'] as String? ?? '18:00');
        } else if (entry is List && entry.length >= 2) {
          _dayOpen[day] = true;
          _dayStart[day] = _parseTime(entry[0] as String);
          _dayEnd[day] = _parseTime(entry[1] as String);
        }
      }
    } on FormatException {
      // Keep the standard weekly schedule for older records.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _phoneCode.dispose();
    _otherSpecialty.dispose();
    _services.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _mapLink.dispose();
    _minimumPrice.dispose();
    _maximumPrice.dispose();
    _responseMinutes.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPhoneVerification(Garage garage) async {
    final repository = context.read<GarageController>().repository;
    if (repository is! OwnerGarageRepository) return;
    final ownerRepository = repository as OwnerGarageRepository;
    try {
      final verified = await ownerRepository.isGaragePhoneVerified(
        garageId: garage.id,
        phone: garage.phone,
      );
      if (!mounted || !verified) return;
      setState(() {
        _verifiedPhone = normalizePhoneForVerification(garage.phone);
        _phoneVerificationMessage = AppLocalizations.of(
          context,
        ).t('phoneVerified');
      });
    } catch (_) {
      // An unavailable status check must never imply that the number is verified.
    }
  }

  void _onPhoneChanged(String value) {
    final normalizedPhone = normalizePhoneForVerification(value);
    if (normalizedPhone == _verifiedPhone && _phoneChallengeId == null) return;
    setState(() {
      if (normalizedPhone != _verifiedPhone) _verifiedPhone = null;
      _phoneChallengeId = null;
      _phoneCode.clear();
      _phoneVerificationMessage = null;
      _phoneVerificationError = null;
    });
  }

  Future<void> _sendPhoneCode() async {
    final l10n = AppLocalizations.of(context);
    final phone = normalizePhoneForVerification(_phone.text);
    if (phone == null) {
      setState(() => _phoneVerificationError = l10n.t('phoneMustBeE164'));
      return;
    }
    final repository = context.read<GarageController>().repository;
    if (repository is! OwnerGarageRepository) {
      setState(
        () => _phoneVerificationError = l10n.t('phoneVerificationUnavailable'),
      );
      return;
    }
    final ownerRepository = repository as OwnerGarageRepository;
    setState(() {
      _isSendingPhoneCode = true;
      _phoneVerificationError = null;
      _phoneVerificationMessage = null;
    });
    try {
      final challengeId = await ownerRepository.requestGaragePhoneCode(phone);
      if (!mounted) return;
      setState(() {
        _phone.text = phone;
        _phoneChallengeId = challengeId;
        _phoneVerificationMessage = l10n.t('phoneCodeSent');
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _phoneVerificationError = _phoneErrorMessage(error, l10n),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingPhoneCode = false);
    }
  }

  Future<void> _verifyPhoneCode() async {
    final l10n = AppLocalizations.of(context);
    final challengeId = _phoneChallengeId;
    final phone = normalizePhoneForVerification(_phone.text);
    if (challengeId == null || phone == null) return;
    final repository = context.read<GarageController>().repository;
    if (repository is! OwnerGarageRepository) return;
    final ownerRepository = repository as OwnerGarageRepository;
    setState(() {
      _isVerifyingPhoneCode = true;
      _phoneVerificationError = null;
    });
    try {
      await ownerRepository.verifyGaragePhoneCode(
        challengeId: challengeId,
        code: _phoneCode.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _phone.text = phone;
        _verifiedPhone = phone;
        _phoneChallengeId = null;
        _phoneCode.clear();
        _phoneVerificationMessage = l10n.t('phoneVerified');
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _phoneVerificationError = _phoneErrorMessage(error, l10n),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingPhoneCode = false);
    }
  }

  Future<void> _verifyOnSitePresence() async {
    final l10n = AppLocalizations.of(context);
    final targetLatitude = double.tryParse(_latitude.text.trim());
    final targetLongitude = double.tryParse(_longitude.text.trim());
    if (targetLatitude == null || targetLongitude == null) {
      setState(() => _onSitePresenceError = l10n.t('locationNotFound'));
      return;
    }
    setState(() {
      _isVerifyingPresence = true;
      _onSitePresenceError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('location_unavailable');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('location_permission_denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (position.isMocked) throw StateError('on_site_presence_mocked');
      final distance = Geolocator.distanceBetween(
        targetLatitude,
        targetLongitude,
        position.latitude,
        position.longitude,
      );
      if (position.accuracy > 50 || distance > 150) {
        throw StateError('on_site_presence_failed');
      }
      if (!mounted) return;
      setState(() {
        _onSitePosition = position;
        _onSitePresenceError = null;
      });
    } catch (error) {
      if (mounted) {
        final code = error.toString().replaceFirst('Bad state: ', '');
        setState(
          () => _onSitePresenceError = switch (code) {
            'on_site_presence_mocked' => l10n.t('onSitePresenceMocked'),
            'location_permission_denied' => l10n.t('locationPermissionDenied'),
            'on_site_presence_failed' => l10n.t('onSitePresenceFailed'),
            _ => l10n.t('locationUnavailable'),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingPresence = false);
    }
  }

  String _phoneErrorMessage(Object error, AppLocalizations l10n) {
    final code = error.toString().replaceFirst('Bad state: ', '');
    return switch (code) {
      'phone_must_be_e164' => l10n.t('phoneMustBeE164'),
      'wait_before_resending' => l10n.t('phoneCodeWait'),
      'hourly_limit_reached' => l10n.t('phoneCodeRateLimit'),
      'sms_delivery_failed' => l10n.t('phoneSmsUnavailable'),
      'invalid_code' ||
      'invalid_code_or_challenge' => l10n.t('phoneCodeInvalid'),
      'challenge_expired' => l10n.t('phoneCodeExpired'),
      'on_site_presence_failed' => l10n.t('onSitePresenceFailed'),
      _ => l10n.t('phoneVerificationUnavailable'),
    };
  }

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _locationError = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(l10n.t('locationUnavailable'));
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(l10n.t('locationPermissionDenied'));
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
        _accuracyMeters = position.accuracy;
        _onSitePosition = null;
      });
      final geocoding = _platformGeocoding;
      if (_address.text.trim().isEmpty && geocoding != null) {
        final marks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          locale: const Locale('fr', 'BJ'),
        );
        if (marks.isNotEmpty && mounted) {
          final mark = marks.first;
          _address.text = [mark.street, mark.subLocality, mark.locality]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .toSet()
              .join(', ');
          _city.text = mark.locality ?? _city.text;
        }
      }
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    }
  }

  Future<void> _findAddress() async {
    final l10n = AppLocalizations.of(context);
    final query = [
      _address.text.trim(),
      _city.text.trim(),
      'Benin',
    ].where((part) => part.isNotEmpty).join(', ');
    if (_address.text.trim().isEmpty) {
      setState(() => _locationError = l10n.t('addressRequired'));
      return;
    }
    final geocoding = _platformGeocoding;
    if (geocoding == null) {
      setState(() => _locationError = l10n.t('addressLookupUnavailable'));
      return;
    }
    setState(() {
      _isFindingAddress = true;
      _locationError = null;
    });
    try {
      final locations = await geocoding.locationFromAddress(
        query,
        locale: const Locale('fr', 'BJ'),
      );
      if (locations.isEmpty) throw StateError(l10n.t('locationNotFound'));
      if (!mounted) return;
      setState(() {
        _latitude.text = locations.first.latitude.toStringAsFixed(6);
        _longitude.text = locations.first.longitude.toStringAsFixed(6);
        _accuracyMeters = null;
        _onSitePosition = null;
      });
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    } finally {
      if (mounted) setState(() => _isFindingAddress = false);
    }
  }

  void _importMapLink() {
    final l10n = AppLocalizations.of(context);
    final coordinates = GoogleMapsLink.parse(_mapLink.text);
    if (coordinates == null) {
      setState(() => _locationError = l10n.t('invalidMapLink'));
      return;
    }
    setState(() {
      _latitude.text = coordinates.latitude.toStringAsFixed(6);
      _longitude.text = coordinates.longitude.toStringAsFixed(6);
      _accuracyMeters = null;
      _locationError = null;
      _onSitePosition = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.t('mapLinkLoaded'))));
  }

  void _toggleSpecialty(String value, bool selected) {
    setState(() {
      if (selected) {
        _selectedSpecialties.add(value);
      } else {
        _selectedSpecialties.remove(value);
      }
      _specialtyError = null;
    });
  }

  void _onGarageCoordinateChanged(String _) {
    if (_onSitePosition == null) return;
    setState(() => _onSitePosition = null);
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoError = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (image == null || !mounted) return;
      final extension = image.name.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        setState(
          () => _photoError = AppLocalizations.of(
            context,
          ).t('photoFormatInvalid'),
        );
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(
          () => _photoError = AppLocalizations.of(context).t('photoTooLarge'),
        );
        return;
      }
      setState(() {
        _photo = image;
        _photoBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError = AppLocalizations.of(context).t('photoPickFailed'),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final selectedSpecialties = GarageSpecialties.values
        .where(_selectedSpecialties.contains)
        .toList(growable: false);
    if (selectedSpecialties.isEmpty) {
      setState(() => _specialtyError = l10n.t('specialtyRequired'));
      return;
    }
    final otherSpecialty = _otherSpecialty.text.trim();
    if (_selectedSpecialties.contains('autre') && otherSpecialty.length < 2) {
      setState(() => _specialtyError = l10n.t('otherSpecialtyHint'));
      return;
    }
    final primarySpecialty = selectedSpecialties.firstWhere(
      (specialty) => specialty != 'autre',
      orElse: () => otherSpecialty,
    );
    if (primarySpecialty.length < 2 || primarySpecialty.length > 80) {
      setState(() => _specialtyError = l10n.t('specialtyRequired'));
      return;
    }
    final auth = context.read<AuthController>();
    final garageController = context.read<GarageController>();
    final repository = garageController.repository;
    if (!auth.isConfigured || !auth.isGarageOwner || !auth.isSignedIn) {
      setState(() => _locationError = l10n.t('accountRequired'));
      return;
    }
    if (repository is! OwnerGarageRepository) {
      setState(() => _locationError = l10n.t('backendMissing'));
      return;
    }
    final ownerRepository = repository as OwnerGarageRepository;
    final normalizedPhone = normalizePhoneForVerification(_phone.text);
    if (normalizedPhone == null || normalizedPhone != _verifiedPhone) {
      setState(
        () => _phoneVerificationError = l10n.t('phoneVerificationRequired'),
      );
      return;
    }
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() => _locationError = l10n.t('locationNotFound'));
      return;
    }
    setState(() {
      _isSaving = true;
      _locationError = null;
    });
    final existing = widget.initialGarage;
    final id = existing?.id ?? _newUuid();
    final services = _services.text
        .split(',')
        .map((service) => service.trim())
        .where((service) => service.isNotEmpty)
        .toSet();
    services.addAll(selectedSpecialties);
    if (otherSpecialty.isNotEmpty) services.add(otherSpecialty);
    final minimum = int.tryParse(_minimumPrice.text.trim());
    final maximum = int.tryParse(_maximumPrice.text.trim());
    final garage = Garage(
      id: id,
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: normalizedPhone,
      chief: auth.user?.userMetadata?['display_name'] as String? ?? '',
      specialty: primarySpecialty,
      imageUrl: existing?.imageUrl ?? '',
      city: _city.text.trim(),
      openingHours: jsonEncode(_openingHoursJson()),
      description: _description.text.trim(),
      sourceUrl: 'Garage Finder',
      rating: existing?.rating ?? 0,
      reviewCount: existing?.reviewCount ?? 0,
      distanceKm: 0,
      distanceKnown: false,
      isOpen: _isOpen,
      isVerified: existing?.isVerified ?? false,
      reviewStatus: existing?.reviewStatus ?? 'pending',
      availabilityStatus: _availabilityStatus,
      responseTime: _responseMinutes.text.trim().isEmpty
          ? ''
          : '${_responseMinutes.text.trim()} min',
      priceLevel: '${minimum ?? ''}-${maximum ?? ''}',
      services: services.toList(growable: false),
      latitude: latitude,
      longitude: longitude,
    );
    try {
      await repository.upsertGarage(garage);
      await garageController.load();
      String? photoNotice;
      String? presenceNotice;
      final photo = _photo;
      if (photo != null) {
        try {
          final bytes = await photo.readAsBytes();
          final photoUrl = await ownerRepository.uploadGaragePhoto(
            garageId: id,
            bytes: bytes,
            filename: photo.name,
            contentType: _contentType(photo.name),
          );
          await garageController.addGarage(garage.copyWith(imageUrl: photoUrl));
          await garageController.load();
        } catch (_) {
          photoNotice = l10n.t('photoUploadFailed');
        }
      }
      final position = _onSitePosition;
      if (position != null) {
        try {
          await ownerRepository.recordGarageOnSitePresence(
            garageId: id,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            locationIsMocked: position.isMocked,
          );
        } catch (_) {
          presenceNotice = l10n.t('onSitePresenceMissing');
        }
      }
      await garageController.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              '${l10n.t(existing == null ? 'pendingReview' : 'garageSaved')}.',
              ?photoNotice,
              ?presenceNotice,
            ].join(' '),
          ),
        ),
      );
      context.go('/owner');
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _availabilityStatus = 'available';

  Map<String, Object?> _openingHoursJson() => {
    for (final day in _dayOpen.keys)
      day: {
        'closed': !_dayOpen[day]!,
        'open': _formatTime(
          _dayStart[day] ?? const TimeOfDay(hour: 8, minute: 0),
        ),
        'close': _formatTime(
          _dayEnd[day] ?? const TimeOfDay(hour: 18, minute: 0),
        ),
      },
  };

  Future<void> _selectTime(String day, bool isStart) async {
    final current =
        (isStart ? _dayStart[day] : _dayEnd[day]) ??
        TimeOfDay(hour: isStart ? 8 : 18, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (selected == null || !mounted) return;
    setState(() => (isStart ? _dayStart : _dayEnd)[day] = selected);
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthController>();
    if (!auth.isConfigured || !auth.isSignedIn || !auth.isGarageOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('addMyGarage'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.t('accountRequired'), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/account'),
                  child: Text(l10n.t('account')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t(widget.initialGarage == null ? 'addMyGarage' : 'editGarage'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _textField(_name, l10n.t('garageName'), required: true),
            _textField(_address, l10n.t('fullAddress'), required: true),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isFindingAddress ? null : _findAddress,
                icon: _isFindingAddress
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore),
                label: Text(l10n.t('geocodeAddress')),
              ),
            ),
            _textField(_city, l10n.t('city'), required: true),
            _textField(
              _phone,
              l10n.t('contactPhone'),
              required: true,
              keyboardType: TextInputType.phone,
              onChanged: _onPhoneChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('phoneVerificationTitle'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t('phoneVerificationHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (_verifiedPhone != null)
                    Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: l10n.t('phoneVerified'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.t('phoneVerified'))),
                      ],
                    )
                  else if (_phoneChallengeId == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isSendingPhoneCode ? null : _sendPhoneCode,
                        icon: _isSendingPhoneCode
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sms_outlined),
                        label: Text(l10n.t('sendPhoneCode')),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneCode,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            decoration: InputDecoration(
                              labelText: l10n.t('phoneCodeLabel'),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _isVerifyingPhoneCode
                              ? null
                              : _verifyPhoneCode,
                          child: _isVerifyingPhoneCode
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.t('verifyPhoneCode')),
                        ),
                      ],
                    ),
                  if (_phoneChallengeId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _isSendingPhoneCode ? null : _sendPhoneCode,
                        child: Text(l10n.t('resendPhoneCode')),
                      ),
                    ),
                  if (_phoneVerificationMessage case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (_phoneVerificationError case final message?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              l10n.t('specialtyLabel'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('specialtyHelper'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                const spacing = 8.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 0,
                  children: [
                    for (final specialty in GarageSpecialties.values)
                      SizedBox(
                        width: itemWidth,
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selectedSpecialties.contains(specialty),
                          title: Text(
                            GarageSpecialties.label(specialty, l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (selected) =>
                              _toggleSpecialty(specialty, selected ?? false),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_selectedSpecialties.contains('autre'))
              _textField(
                _otherSpecialty,
                l10n.t('otherSpecialtyHint'),
                required: true,
                maxLength: 80,
              ),
            if (_specialtyError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _specialtyError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _textField(_services, l10n.t('servicesHint')),
            DropdownButtonFormField<String>(
              initialValue: _availabilityStatus,
              decoration: InputDecoration(labelText: l10n.t('availability')),
              items: [
                for (final status in [
                  'available',
                  'busy',
                  'emergency_only',
                  'unavailable',
                ])
                  DropdownMenuItem(
                    value: status,
                    child: Text(l10n.t('availability_$status')),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _availabilityStatus = value ?? 'available'),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('weeklyHours'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final day in _dayOpen.keys)
              Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(l10n.t('day_$day')),
                      value: _dayOpen[day],
                      onChanged: (value) =>
                          setState(() => _dayOpen[day] = value ?? false),
                    ),
                  ),
                  if (_dayOpen[day]!) ...[
                    TextButton(
                      onPressed: () => _selectTime(day, true),
                      child: Text(
                        _formatTime(
                          _dayStart[day] ?? const TimeOfDay(hour: 8, minute: 0),
                        ),
                      ),
                    ),
                    Text('-'),
                    TextButton(
                      onPressed: () => _selectTime(day, false),
                      child: Text(
                        _formatTime(
                          _dayEnd[day] ?? const TimeOfDay(hour: 18, minute: 0),
                        ),
                      ),
                    ),
                  ] else
                    Text(l10n.t('closedStatus')),
                ],
              ),
            _textField(
              _responseMinutes,
              l10n.t('responseTimeMinutes'),
              keyboardType: TextInputType.number,
            ),
            _textField(
              _description,
              l10n.t('formIntro'),
              maxLines: 3,
              maxLength: 2000,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _useCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: Text(l10n.t('useMyLocation')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mapLink,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.t('googleMapsLink'),
                helperText: l10n.t('googleMapsLinkHint'),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _importMapLink,
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.t('useMapLink')),
              ),
            ),
            if (_accuracyMeters != null)
              Text('Précision GPS : ±${_accuracyMeters!.round()} m'),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _latitude,
                    l10n.t('latitude'),
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: _onGarageCoordinateChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    _longitude,
                    l10n.t('longitude'),
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    onChanged: _onGarageCoordinateChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('onSitePresenceTitle'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('onSitePresenceHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isVerifyingPresence ? null : _verifyOnSitePresence,
              icon: _isVerifyingPresence
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _onSitePosition == null
                          ? Icons.location_searching
                          : Icons.verified_outlined,
                    ),
              label: Text(
                l10n.t(
                  _onSitePosition == null
                      ? 'verifyOnSitePresence'
                      : 'onSitePresenceVerified',
                ),
              ),
            ),
            Text(
              l10n.t('automatedReviewCaveat'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_onSitePresenceError case final message?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _minimumPrice,
                    l10n.t('priceMin'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    _maximumPrice,
                    l10n.t('priceMax'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('openNow')),
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value),
            ),
            OutlinedButton.icon(
              onPressed: _isPickingPhoto ? null : _pickPhoto,
              icon: _isPickingPhoto
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(
                l10n.t(_photo == null ? 'photoOptional' : 'changeGaragePhoto'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.t('autoPhotoRequired'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_photoBytes case final bytes?) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.t('garagePhotoPreview'),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _photo?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.t('removeGaragePhoto'),
                    onPressed: () => setState(() {
                      _photo = null;
                      _photoBytes = null;
                      _photoError = null;
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
            if (_photoError != null)
              Text(
                _photoError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _locationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l10n.t('saveForReview')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? '$label requis' : null
          : null,
    ),
  );

  static String _contentType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
