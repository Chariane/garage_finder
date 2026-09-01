import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  final Widget child;

  const MainNavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location == '/') return 0;
    if (location.startsWith('/list')) return 1;
    if (location.startsWith('/form')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/list');
        break;
      case 2:
        context.go('/form');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Accueil',
                  isSelected: currentIndex == 0,
                  onTap: () => _onItemTapped(0, context),
                ),
                _NavItem(
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  label: 'Garages',
                  isSelected: currentIndex == 1,
                  onTap: () => _onItemTapped(1, context),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  activeIcon: Icons.manage_search_rounded,
                  label: 'Recherche',
                  isSelected: false,
                  onTap: () => context.go('/list'),
                ),
                _NavItem(
                  icon: Icons.add_circle_outline_rounded,
                  activeIcon: Icons.add_circle_rounded,
                  label: 'Ajouter',
                  isSelected: currentIndex == 2,
                  onTap: () => _onItemTapped(2, context),
                ),
                _NavItem(
                  icon: Icons.warning_amber_rounded,
                  activeIcon: Icons.report_problem_rounded,
                  label: 'SOS Panne',
                  color: Colors.redAccent,
                  isSelected: false,
                  onTap: () => context.go('/list'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.colorScheme.primary;
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 24,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
