import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final auth = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.t('language')),
            trailing: DropdownButton<Locale>(
              value: theme.locale,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: Locale('fr'), child: Text('Français')),
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
              ],
              onChanged: (locale) {
                if (locale != null) theme.setLocale(locale);
              },
            ),
          ),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: Text(l10n.t('theme')),
            subtitle: Text(isDark ? l10n.t('darkMode') : l10n.t('lightMode')),
            value: isDark,
            onChanged: (dark) =>
                theme.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.t('account')),
            subtitle: Text(
              auth.isSignedIn ? auth.user?.email ?? '' : l10n.t('signIn'),
            ),
            onTap: () => context.go('/account'),
          ),
          if (auth.isSignedIn)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.t('activity')),
              onTap: () => context.go('/activity'),
            ),
          if (auth.isGarageOwner)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(l10n.t('ownerDashboard')),
              onTap: () => context.go('/owner'),
            ),
          if (auth.user?.appMetadata['role'] == 'admin')
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.t('moderation')),
              onTap: () => context.go('/moderation'),
            ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Garage Finder'),
            subtitle: Text(l10n.t('version')),
          ),
        ],
      ),
    );
  }
}
