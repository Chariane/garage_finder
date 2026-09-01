import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/garage_data.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/garage_card.dart';
import '../widgets/garage_image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const AppLogo.appBar(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: isDark ? 'Mode clair' : 'Mode sombre',
              icon: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.wb_sunny_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              onPressed: themeProvider.toggleTheme,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _HeroSection()),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _EmergencyBanner(onTap: () => context.go('/list')),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    title: 'Services & Spécialités',
                    subtitle: 'Choisissez la catégorie correspondant à votre besoin',
                  ),
                  const SizedBox(height: 14),
                  _CategoryGrid(onCategorySelected: (_) => context.go('/list')),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.search_rounded,
                      title: 'Trouver un garage',
                      subtitle: 'Recherche par nom ou quartier',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      onTap: () => context.go('/list'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_business_rounded,
                      title: 'Inscrire un garage',
                      subtitle: 'Référencez votre atelier pro',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                      ),
                      onTap: () => context.go('/form'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: _SectionHeader(
                title: 'Ateliers Recommandés',
                subtitle: '${garages.length} ateliers disponibles et vérifiés au Bénin',
                actionLabel: 'Tout voir',
                onAction: () => context.go('/list'),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: SliverList.separated(
              itemCount: garages.take(4).length,
              separatorBuilder: (context, index) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final garage = garages[index];
                return GarageCard(
                  garage: garage,
                  onTap: () => context.go('/detail/${garage.id}'),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: _FeaturesSection(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 480,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const GarageImage(
            imagePath: 'assets/images/garage_hero.png',
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: AppTheme.accent, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Plateforme N°1 Dépannage & Garage au Bénin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const AppLogo.hero(),
                  const SizedBox(height: 14),
                  Text(
                    'Trouvez un garage proche en quelques clics',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Panne subite, panne de batterie ou entretien ? Géolocalisez et contactez un mécanicien pro immédiatement.',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.go('/list'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nom du garage, quartier (ex: Agontikon, Cotonou)...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMetricTile(
                          icon: Icons.build_circle_rounded,
                          value: '${garages.length}+',
                          label: 'Garages Pro',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _HeroMetricTile(
                          icon: Icons.timer_rounded,
                          value: '< 15 min',
                          label: 'Délai moyen',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: _HeroMetricTile(
                          icon: Icons.headset_mic_rounded,
                          value: '24/7',
                          label: 'Assistance',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroMetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EmergencyBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS Panne sur la Route ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trouvez immédiatement les dépannages ouverts autour de vous.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'SOS Panne',
                style: TextStyle(
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final ValueChanged<String> onCategorySelected;

  const _CategoryGrid({required this.onCategorySelected});

  final List<Map<String, dynamic>> _categories = const [
    {
      'title': 'Mécanique Auto',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'title': 'Atelier Moto',
      'icon': Icons.two_wheeler_rounded,
      'color': Color(0xFF059669),
    },
    {
      'title': 'Électricité & Diag',
      'icon': Icons.electric_bolt_rounded,
      'color': Color(0xFFD97706),
    },
    {
      'title': 'Pneumatique',
      'icon': Icons.tire_repair_rounded,
      'color': Color(0xFF7C3AED),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _categories.map((cat) {
        final color = cat['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => onCategorySelected(cat['title']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: color.withValues(alpha: 0.20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat['icon'] as IconData, color: color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat['title'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Pourquoi utiliser Garage Finder ?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FeatureTile(
            icon: Icons.verified_user_rounded,
            title: 'Garages Réels et Vérifiés',
            subtitle: 'Coordonnées directes et adresses exactes au Bénin.',
          ),
          const SizedBox(height: 10),
          _FeatureTile(
            icon: Icons.bolt_rounded,
            title: 'Assistance Rapide SOS',
            subtitle: 'Filtrez d’un clic les ateliers ouverts en cas de panne.',
          ),
          const SizedBox(height: 10),
          _FeatureTile(
            icon: Icons.phone_callback_rounded,
            title: 'Appel Direct',
            subtitle: 'Contactez les maîtres mécaniciens sans frais intermédiaire.',
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}
