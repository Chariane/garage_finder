import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';

class MainNavigationShell extends StatelessWidget {
  final Widget child;

  const MainNavigationShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthController>();
    final location = GoRouterState.of(context).uri.path;
    final isOwnerWorkspace =
        auth.isSignedIn &&
        auth.isGarageOwner &&
        (location.startsWith('/owner') ||
            location.startsWith('/activity') ||
            location.startsWith('/garage/') ||
            location.startsWith('/settings'));
    final l10n = AppLocalizations.of(context);

    final items = isOwnerWorkspace
        ? [
            _NavConfig(
              '/owner',
              Icons.storefront_outlined,
              Icons.storefront_rounded,
              l10n.t('ownerDashboard'),
            ),
            _NavConfig(
              '/activity',
              Icons.notifications_outlined,
              Icons.notifications_rounded,
              l10n.t('notifications'),
            ),
            _NavConfig(
              '/',
              Icons.travel_explore_outlined,
              Icons.travel_explore_rounded,
              l10n.t('explore'),
            ),
            _NavConfig(
              '/settings',
              Icons.settings_outlined,
              Icons.settings_rounded,
              l10n.t('settings'),
            ),
          ]
        : [
            _NavConfig(
              '/',
              Icons.home_outlined,
              Icons.home_rounded,
              l10n.t('home'),
            ),
            _NavConfig(
              '/list',
              Icons.storefront_outlined,
              Icons.storefront_rounded,
              l10n.t('garages'),
            ),
            _NavConfig(
              '/favorites',
              Icons.favorite_border_rounded,
              Icons.favorite_rounded,
              l10n.t('favorites'),
            ),
            _NavConfig(
              '/settings',
              Icons.settings_outlined,
              Icons.settings_rounded,
              l10n.t('settings'),
            ),
          ];
    final currentIndex = _selectedIndex(location, isOwnerWorkspace);

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => context.go(items[index].route),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final item in items)
                NavigationDestination(
                  icon: Icon(item.icon, semanticLabel: item.label),
                  selectedIcon: Icon(
                    item.activeIcon,
                    semanticLabel: item.label,
                  ),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _selectedIndex(String location, bool isOwnerWorkspace) {
    if (isOwnerWorkspace) {
      if (location.startsWith('/activity')) return 1;
      if (location == '/' ||
          location.startsWith('/list') ||
          location.startsWith('/detail') ||
          location.startsWith('/favorites')) {
        return 2;
      }
      if (location.startsWith('/settings')) return 3;
      return 0;
    }
    if (location.startsWith('/list') || location.startsWith('/detail')) {
      return 1;
    }
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }
}

class _NavConfig {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavConfig(this.route, this.icon, this.activeIcon, this.label);
}
