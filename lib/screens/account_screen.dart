import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isGarageOwner = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
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
        if (mounted) context.go(auth.isGarageOwner ? '/owner' : '/');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
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
      if (mounted) setState(() => _error = error.toString());
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
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.t('displayName')),
              validator: (value) => value == null || value.trim().length < 2
                  ? l10n.t('nameTooShort')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.t('contactPhone')),
              validator: (value) => value == null || value.trim().length < 6
                  ? l10n.t('phoneRequired')
                  : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _isGarageOwner ? l10n.t('garageOwner') : l10n.t('customer'),
              ),
              value: _isGarageOwner,
              onChanged: (value) => setState(() => _isGarageOwner = value),
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
