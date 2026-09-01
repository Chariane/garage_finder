import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/garage_data.dart';
import '../models/garage.dart';
import '../theme/app_theme.dart';
import '../widgets/garage_image.dart';

class DetailScreen extends StatelessWidget {
  final String garageId;

  const DetailScreen({super.key, required this.garageId});

  @override
  Widget build(BuildContext context) {
    Garage? garage;
    for (final item in garages) {
      if (item.id == garageId) {
        garage = item;
        break;
      }
    }

    if (garage == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Garage introuvable')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => context.go('/list'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Retour à la liste'),
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: Colors.white,
            leading: IconButton.filledTonal(
              tooltip: 'Retour',
              onPressed: () => context.go('/list'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              IconButton.filledTonal(
                tooltip: 'Partager',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Partage de ${garage!.name} simulé'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GarageImage(imagePath: garage.imageUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Pill(
                          icon: Icons.build_rounded,
                          label: garage.specialty,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          garage.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 31,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.phone_rounded,
                          label: 'Appeler',
                          color: AppTheme.success,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Appel à ${garage!.phone} simulé',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.directions_rounded,
                          label: 'Itinéraire',
                          color: theme.colorScheme.primary,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Itinéraire simulé'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _HighlightTile(
                          icon: Icons.star_rounded,
                          label: 'Note',
                          value:
                              '${garage.rating.toStringAsFixed(1)} / 5',
                          detail: '${garage.reviewCount} avis',
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HighlightTile(
                          icon: Icons.near_me_rounded,
                          label: 'Distance',
                          value:
                              '${garage.distanceKm.toStringAsFixed(1)} km',
                          detail: garage.responseTime,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HighlightTile(
                          icon: garage.isOpen
                              ? Icons.schedule_rounded
                              : Icons.lock_clock_rounded,
                          label: 'Statut',
                          value: garage.isOpen ? 'Ouvert' : 'Fermé',
                          detail: garage.priceLevel,
                          color: garage.isOpen
                              ? AppTheme.success
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Aperçu', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    garage.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Informations', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            label: 'Adresse',
                            value: '${garage.city} · ${garage.address}',
                            color: theme.colorScheme.secondary,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.access_time_filled_rounded,
                            label: 'Horaires',
                            value: garage.openingHours,
                            color: garage.isOpen
                                ? AppTheme.success
                                : Colors.redAccent,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Téléphone',
                            value: garage.phone,
                            color: AppTheme.success,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.person_rounded,
                            label: 'Chef de garage',
                            value: garage.chief,
                            color: theme.colorScheme.primary,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: garage.isVerified
                                ? Icons.verified_rounded
                                : Icons.info_rounded,
                            label: 'Confiance',
                            value: garage.isVerified
                                ? 'Garage vérifié'
                                : 'Garage non vérifié',
                            color: garage.isVerified
                                ? theme.colorScheme.primary
                                : AppTheme.accent,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.link_rounded,
                            label: 'Source',
                            value: garage.sourceUrl,
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Services', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: garage.services.map((service) {
                      return _ServicePill(label: service);
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Localisation', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _MapPreview(garage: garage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _HighlightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182033) : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  final String label;

  const _ServicePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF182033) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white70 : theme.colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final Garage garage;

  const _MapPreview({required this.garage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            child: Icon(Icons.map_rounded, color: theme.colorScheme.primary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                garage.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Coordonnées : ${garage.latitude ?? '-'}, ${garage.longitude ?? '-'}',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
