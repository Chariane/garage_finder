import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';

class MainNavigationShell extends StatelessWidget {
  final Widget child;

  const MainNavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/') return 0;
    if (location.startsWith('/list') || location.startsWith('/detail')) {
      return 1;
    }
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/form')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/list');
      case 2:
        context.go('/favorites');
      case 3:
        context.go('/form');
      case 4:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = _calculateSelectedIndex(context);
    final l10n = AppLocalizations.of(context);

    final items = [
      _NavConfig(Icons.home_outlined, Icons.home_rounded, l10n.t('home')),
      _NavConfig(
        Icons.storefront_outlined,
        Icons.storefront_rounded,
        l10n.t('garages'),
      ),
      _NavConfig(
        Icons.favorite_border_rounded,
        Icons.favorite_rounded,
        l10n.t('favorites'),
      ),
      _NavConfig(
        Icons.add_circle_outline_rounded,
        Icons.add_circle_rounded,
        l10n.t('add'),
      ),
      _NavConfig(
        Icons.settings_outlined,
        Icons.settings_rounded,
        l10n.t('settings'),
      ),
    ];

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
            onDestinationSelected: (index) => _onItemTapped(index, context),
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
}

class _NavConfig {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavConfig(this.icon, this.activeIcon, this.label);
}
