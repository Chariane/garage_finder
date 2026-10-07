import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';

class ServiceRequestScreen extends StatefulWidget {
  final Garage garage;

  const ServiceRequestScreen({super.key, required this.garage});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  final _issue = TextEditingController();
  bool _shareLocation = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.text =
        context.read<AuthController>().user?.userMetadata?['phone']
            as String? ??
        '';
  }

  @override
  void dispose() {
    _phone.dispose();
    _vehicle.dispose();
    _issue.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final repository = context.read<GarageController>().repository;
    if (!auth.isSignedIn ||
        auth.isGarageOwner ||
        repository is! CustomerWorkflowRepository) {
      setState(() => _error = AppLocalizations.of(context).t('backendMissing'));
      return;
    }
    final workflow = repository as CustomerWorkflowRepository;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      double? latitude;
      double? longitude;
      if (_shareLocation) {
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
            timeLimit: Duration(seconds: 20),
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
      await workflow.createServiceRequest(
        garageId: widget.garage.id,
        phone: _phone.text,
        vehicle: _vehicle.text,
        issue: _issue.text,
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('requestSent'))),
      );
      context.go('/activity');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthController>();
    if (!auth.isConfigured || !auth.isSignedIn || auth.isGarageOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('requestHelp'))),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/account'),
            child: Text(l10n.t('account')),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('requestHelp'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.garage.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.t('contactPhone')),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? l10n.t('phoneRequired')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicle,
              maxLength: 100,
              decoration: InputDecoration(labelText: l10n.t('vehicle')),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? l10n.t('requiredField')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issue,
              maxLength: 1500,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.t('describeBreakdown'),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? l10n.t('requiredField')
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _shareLocation,
              onChanged: (value) =>
                  setState(() => _shareLocation = value ?? false),
              title: Text(l10n.t('shareLocationWithGarage')),
              subtitle: Text(l10n.t('locationPrivacyNotice')),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l10n.t('sendRequest')),
            ),
          ],
        ),
      ),
    );
  }
}
