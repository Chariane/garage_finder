import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/localization/app_localizations.dart';

@immutable
class LocationSelection {
  final double latitude;
  final double longitude;

  const LocationSelection(this.latitude, this.longitude);
}

class LocationSearchDialog extends StatefulWidget {
  const LocationSearchDialog({super.key});

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _geocoding = Geocoding(locale: const Locale('fr', 'BJ'));
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
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
      Navigator.of(
        context,
      ).pop(LocationSelection(position.latitude, position.longitude));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _geocode() async {
    final l10n = AppLocalizations.of(context);
    if (_address.text.trim().isEmpty) {
      setState(() => _error = l10n.t('addressRequired'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = [
        _address.text.trim(),
        _city.text.trim(),
        'Benin',
      ].where((part) => part.isNotEmpty).join(', ');
      final results = await _geocoding.locationFromAddress(
        query,
        locale: const Locale('fr', 'BJ'),
      );
      if (results.isEmpty) throw StateError(l10n.t('locationNotFound'));
      if (!mounted) return;
      _latitude.text = results.first.latitude.toStringAsFixed(6);
      _longitude.text = results.first.longitude.toStringAsFixed(6);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      setState(() => _error = l10n.t('locationNotFound'));
      return;
    }
    Navigator.of(context).pop(LocationSelection(latitude, longitude));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.t('findNearby')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : _useGps,
              icon: const Icon(Icons.my_location),
              label: Text(l10n.t('useMyLocation')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.t('fullAddress')),
            ),
            TextField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.t('city')),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _geocode,
                icon: const Icon(Icons.travel_explore),
                label: Text(l10n.t('geocodeAddress')),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.t('latitude')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.t('longitude')),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.t('findNearby'))),
      ],
    );
  }
}
