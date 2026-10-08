import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';

class AuthCallbackScreen extends StatelessWidget {
  final Uri uri;

  const AuthCallbackScreen({super.key, required this.uri});

  Map<String, String> get _parameters {
    final parameters = <String, String>{...uri.queryParameters};
    try {
      parameters.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      // Ignore malformed fragments and show the generic callback state.
    }
    return parameters;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthController>();
    final parameters = _parameters;
    final errorCode = parameters['error_code'] ?? parameters['error'];
    final expired = errorCode == 'otp_expired';
    final confirmed = auth.isSignedIn && errorCode == null;
    final title = confirmed
        ? l10n.t('emailConfirmedTitle')
        : expired
        ? l10n.t('emailLinkExpiredTitle')
        : l10n.t('emailLinkFailedTitle');
    final description = confirmed
        ? l10n.t('emailConfirmedBody')
        : expired
        ? l10n.t('emailLinkExpiredBody')
        : l10n.t('emailLinkFailedBody');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('appTitle'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  confirmed
                      ? Icons.mark_email_read_outlined
                      : expired
                      ? Icons.timer_off_outlined
                      : Icons.mark_email_unread_outlined,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (confirmed) {
                      context.go(auth.isGarageOwner ? '/owner' : '/');
                    } else {
                      context.go('/account?mode=signup');
                    }
                  },
                  icon: Icon(
                    confirmed ? Icons.arrow_forward : Icons.manage_accounts,
                  ),
                  label: Text(
                    confirmed ? l10n.t('continueToApp') : l10n.t('account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
