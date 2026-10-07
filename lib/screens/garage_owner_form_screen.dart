import 'dart:convert';
import 'dart:math';

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
  final _specialty = TextEditingController();
  final _services = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _minimumPrice = TextEditingController();
  final _maximumPrice = TextEditingController();
  final _responseMinutes = TextEditingController();
  final _geocoding = Geocoding(locale: const Locale('fr', 'BJ'));
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
  XFile? _photo;
  bool _isOpen = false;
  bool _isSaving = false;
  bool _isFindingAddress = false;
  String? _locationError;
  String? _photoError;
  double? _accuracyMeters;

  @override
  void initState() {
    super.initState();
    final garage = widget.initialGarage;
    if (garage == null) return;
    _name.text = garage.name;
    _address.text = garage.address;
    _city.text = garage.city;
    _phone.text = garage.phone;
    _specialty.text = garage.specialty;
    _services.text = garage.services.join(', ');
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
    _specialty.dispose();
    _services.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _minimumPrice.dispose();
    _maximumPrice.dispose();
    _responseMinutes.dispose();
    super.dispose();
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
      });
      if (_address.text.trim().isEmpty) {
        final marks = await _geocoding.placemarkFromCoordinates(
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
    setState(() {
      _isFindingAddress = true;
      _locationError = null;
    });
    try {
      final locations = await _geocoding.locationFromAddress(
        query,
        locale: const Locale('fr', 'BJ'),
      );
      if (locations.isEmpty) throw StateError(l10n.t('locationNotFound'));
      if (!mounted) return;
      setState(() {
        _latitude.text = locations.first.latitude.toStringAsFixed(6);
        _longitude.text = locations.first.longitude.toStringAsFixed(6);
        _accuracyMeters = null;
      });
    } catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    } finally {
      if (mounted) setState(() => _isFindingAddress = false);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (image == null || !mounted) return;
    final extension = image.name.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      setState(() => _photoError = 'Format accepté : JPG, PNG ou WebP.');
      return;
    }
    if (await image.length() > 5 * 1024 * 1024) {
      setState(() => _photoError = 'La photo doit faire 5 Mo maximum.');
      return;
    }
    setState(() {
      _photo = image;
      _photoError = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final garageController = context.read<GarageController>();
    final repository = garageController.repository;
    if (!auth.isConfigured || !auth.isGarageOwner || !auth.isSignedIn) {
      setState(
        () =>
            _locationError = AppLocalizations.of(context).t('accountRequired'),
      );
      return;
    }
    if (repository is! OwnerGarageRepository) {
      setState(
        () => _locationError = AppLocalizations.of(context).t('backendMissing'),
      );
      return;
    }
    final ownerRepository = repository as OwnerGarageRepository;
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(
        () =>
            _locationError = AppLocalizations.of(context).t('locationNotFound'),
      );
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
        .toSet()
        .toList();
    if (!services.contains(_specialty.text.trim())) {
      services.insert(0, _specialty.text.trim());
    }
    final minimum = int.tryParse(_minimumPrice.text.trim());
    final maximum = int.tryParse(_maximumPrice.text.trim());
    final garage = Garage(
      id: id,
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      chief: auth.user?.userMetadata?['display_name'] as String? ?? '',
      specialty: _specialty.text.trim(),
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
      services: services,
      latitude: latitude,
      longitude: longitude,
    );
    try {
      await repository.upsertGarage(garage);
      await garageController.load();
      var photoNotice = '';
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
          photoNotice = ' La fiche est enregistrée sans la photo.';
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t(existing == null ? 'pendingReview' : 'garageSaved')}.$photoNotice',
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
            ),
            _textField(_specialty, l10n.t('specialtyLabel'), required: true),
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
                  ),
                ),
              ],
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
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(l10n.t('photoOptional')),
            ),
            if (_photo != null) Text(_photo!.name),
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
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
