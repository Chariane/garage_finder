import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';

class AccountScreen extends StatefulWidget {
  final bool startWithSignup;

  const AccountScreen({super.key, this.startWithSignup = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _garageAddressController = TextEditingController();
  late final _geocoding = Geocoding(locale: const Locale('fr', 'BJ'));
  double? _garageLatitude;
  double? _garageLongitude;
  bool _isGettingGarageLocation = false;
  bool _isFindingGarageAddress = false;
  bool _isCreatingAccount = false;
  bool _isGarageOwner = false;
  bool _isSubmitting = false;
  bool _isResendingConfirmation = false;
  bool _obscurePassword = true;
  String? _message;
  String? _error;
  String? _garageLocationError;

  @override
  void initState() {
    super.initState();
    _isCreatingAccount = widget.startWithSignup;
  }

  String _friendlyError(Object error, AppLocalizations l10n) {
    if (error is AuthException && error.statusCode == '429') {
      return l10n.t('authRateLimited');
    }
    return error.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _garageAddressController.dispose();
    super.dispose();
  }

  Future<void> _useGarageLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isGettingGarageLocation = true;
      _garageLocationError = null;
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
      setState(() {
        _garageLatitude = position.latitude;
        _garageLongitude = position.longitude;
      });
    } catch (error) {
      if (mounted) setState(() => _garageLocationError = error.toString());
    } finally {
      if (mounted) setState(() => _isGettingGarageLocation = false);
    }
  }

  Future<void> _findGarageAddress() async {
    final l10n = AppLocalizations.of(context);
    final address = _garageAddressController.text.trim();
    if (address.isEmpty) {
      setState(() => _garageLocationError = l10n.t('addressRequired'));
      return;
    }
    setState(() {
      _isFindingGarageAddress = true;
      _garageLocationError = null;
    });
    try {
      final locations = await _geocoding.locationFromAddress(
        '$address, Benin',
        locale: const Locale('fr', 'BJ'),
      );
      if (locations.isEmpty) throw StateError(l10n.t('locationNotFound'));
      if (!mounted) return;
      setState(() {
        _garageLatitude = locations.first.latitude;
        _garageLongitude = locations.first.longitude;
      });
    } catch (error) {
      if (mounted) setState(() => _garageLocationError = error.toString());
    } finally {
      if (mounted) setState(() => _isFindingGarageAddress = false);
    }
  }

  Future<void> _openGarageLocation() async {
    final latitude = _garageLatitude;
    final longitude = _garageLongitude;
    if (latitude == null || longitude == null) return;
    final mapUri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    if (!await launchUrl(mapUri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(
        () => _garageLocationError = AppLocalizations.of(
          context,
        ).t('launchFailed'),
      );
    }
  }

  Future<void> _submit(AuthController auth) async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_isCreatingAccount &&
        _isGarageOwner &&
        (_garageLatitude == null || _garageLongitude == null)) {
      setState(() => _garageLocationError = l10n.t('garageLocationRequired'));
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
      _message = null;
    });
    try {
      if (_isCreatingAccount) {
        await auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          phone: _phoneController.text,
          garageOwner: _isGarageOwner,
          garageAddress: _isGarageOwner ? _garageAddressController.text : null,
          garageLatitude: _garageLatitude,
          garageLongitude: _garageLongitude,
        );
        if (mounted) {
          setState(
            () => _message = AppLocalizations.of(context).t('checkEmail'),
          );
        }
      } else {
        await auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted) {
          if (auth.isGarageOwner) {
            context.go('/owner');
          } else if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error, l10n));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword(AuthController auth) async {
    final l10n = AppLocalizations.of(context);
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = l10n.t('email'));
      return;
    }
    try {
      await auth.resetPassword(_emailController.text);
      if (mounted) setState(() => _message = l10n.t('resetSent'));
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error, l10n));
    }
  }

  Future<void> _resendConfirmation(AuthController auth) async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _error = l10n.t('invalidEmail');
        _message = null;
      });
      return;
    }
    setState(() {
      _isResendingConfirmation = true;
      _error = null;
      _message = null;
    });
    try {
      await auth.resendSignupConfirmation(email);
      if (mounted) setState(() => _message = l10n.t('confirmationResent'));
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error, l10n));
    } finally {
      if (mounted) setState(() => _isResendingConfirmation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('account'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (!auth.isConfigured)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.t('backendMissing')),
              ),
            )
          else if (auth.isSignedIn)
            _SignedInAccount(auth: auth)
          else
            _buildForm(auth, l10n),
        ],
      ),
    );
  }

  Widget _buildForm(AuthController auth, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.t('signIn'))),
              ButtonSegment(value: true, label: Text(l10n.t('signUp'))),
            ],
            selected: {_isCreatingAccount},
            onSelectionChanged: (values) {
              setState(() {
                _isCreatingAccount = values.first;
                _error = null;
                _message = null;
              });
            },
          ),
          const SizedBox(height: 20),
          if (_isCreatingAccount) ...[
            Text(
              l10n.t('chooseAccountType'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.person_outline),
                  label: Text(l10n.t('customerRole')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(l10n.t('garageOwnerRole')),
                ),
              ],
              selected: {_isGarageOwner},
              onSelectionChanged: (values) => setState(() {
                _isGarageOwner = values.first;
                _error = null;
                _message = null;
              }),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.t(
                _isGarageOwner ? 'garageAccountTitle' : 'customerAccountTitle',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t(
                _isGarageOwner ? 'garageAccountHelp' : 'customerAccountHelp',
              ),
            ),
            if (_isGarageOwner) ...[
              const SizedBox(height: 8),
              Text(l10n.t('garageLocationPrivacy')),
            ],
            const SizedBox(height: 16),
            if (_isGarageOwner) ...[
              TextFormField(
                controller: _garageAddressController,
                textCapitalization: TextCapitalization.words,
                maxLength: 240,
                onChanged: (_) => setState(() {
                  _garageLatitude = null;
                  _garageLongitude = null;
                  _garageLocationError = null;
                }),
                decoration: InputDecoration(
                  labelText: l10n.t('garageAddress'),
                  helperText: l10n.t('garageAddressHint'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? l10n.t('addressRequired')
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isFindingGarageAddress
                      ? null
                      : _findGarageAddress,
                  icon: _isFindingGarageAddress
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore),
                  label: Text(l10n.t('geocodeAddress')),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isGettingGarageLocation ? null : _useGarageLocation,
                icon: _isGettingGarageLocation
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(l10n.t('useMyLocation')),
              ),
              if (_garageLatitude != null && _garageLongitude != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(l10n.t('locationFound')),
                  subtitle: Text(
                    '${_garageLatitude!.toStringAsFixed(6)}, ${_garageLongitude!.toStringAsFixed(6)}',
                  ),
                  trailing: IconButton(
                    tooltip: l10n.t('openMapLocation'),
                    onPressed: _openGarageLocation,
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
              if (_garageLocationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _garageLocationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              decoration: InputDecoration(labelText: l10n.t('displayName')),
              validator: (value) => value == null || value.trim().length < 2
                  ? l10n.t('nameTooShort')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 32,
              decoration: InputDecoration(labelText: l10n.t('contactPhone')),
              validator: (value) => value == null || value.trim().length < 6
                  ? l10n.t('phoneRequired')
                  : null,
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.t('email')),
            validator: (value) =>
                value == null ||
                    !RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value.trim())
                ? l10n.t('email')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: _isCreatingAccount
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l10n.t('password'),
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? l10n.t('showPassword')
                    : l10n.t('hidePassword'),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.length < 8 ? l10n.t('password') : null,
          ),
          if (!_isCreatingAccount)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _resetPassword(auth),
                child: Text(l10n.t('forgotPassword')),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!),
            ),
          FilledButton(
            onPressed: _isSubmitting ? null : () => _submit(auth),
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isCreatingAccount
                        ? l10n.t('createAccount')
                        : l10n.t('signIn'),
                  ),
          ),
          if (_isCreatingAccount) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _isResendingConfirmation || _isSubmitting
                  ? null
                  : () => _resendConfirmation(auth),
              icon: _isResendingConfirmation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_unread_outlined),
              label: Text(l10n.t('resendConfirmation')),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignedInAccount extends StatelessWidget {
  final AuthController auth;

  const _SignedInAccount({required this.auth});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = auth.user?.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(email),
          subtitle: Text(
            auth.isGarageOwner ? l10n.t('garageOwner') : l10n.t('customer'),
          ),
        ),
        if (auth.isGarageOwner)
          FilledButton.icon(
            onPressed: () => context.go('/owner'),
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l10n.t('ownerDashboard')),
          ),
        OutlinedButton.icon(
          onPressed: () => auth.signOut(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.t('signOut')),
        ),
      ],
    );
  }
}
