import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';
import '../utils/contact_links.dart';

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

  Future<void> _openContact(Uri uri, AppLocalizations l10n) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('launchFailed'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.t('launchFailed'))));
      }
    }
  }

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
      final needsAccount = auth.isConfigured && !auth.isSignedIn;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('requestHelp'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  needsAccount
                      ? l10n.t('customerAccountRequired')
                      : l10n.t('backendMissing'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (needsAccount)
                  FilledButton.icon(
                    onPressed: () => context.push('/account'),
                    icon: const Icon(Icons.login),
                    label: Text(l10n.t('account')),
                  ),
              ],
            ),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.garage.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.garage.address}, ${widget.garage.city}'),
                    const SizedBox(height: 8),
                    Text(l10n.t('requestWorkflowInfo')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openContact(
                            Uri(
                              scheme: 'tel',
                              path: widget.garage.phone.replaceAll(
                                RegExp(r'[^0-9+]'),
                                '',
                              ),
                            ),
                            l10n,
                          ),
                          icon: const Icon(Icons.call_outlined),
                          label: Text(l10n.t('call')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            final uri = whatsappUri(
                              widget.garage.phone,
                              message:
                                  'Bonjour, je vous contacte via Garage Finder au sujet de ${widget.garage.name}. Êtes-vous disponible ?',
                            );
                            if (uri != null) {
                              _openContact(uri, l10n);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.t('invalidPhone'))),
                              );
                            }
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: Text(l10n.t('contactWhatsApp')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
              label: Text(
                _sending ? l10n.t('sendingRequest') : l10n.t('sendRequest'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
