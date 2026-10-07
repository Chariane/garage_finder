import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/garage_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/garage_image.dart';

Future<void> _launchExternal(
  BuildContext context,
  Uri uri,
  String failureMessage,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  } catch (_) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }
}

class DetailScreen extends StatelessWidget {
  final String garageId;

  const DetailScreen({super.key, required this.garageId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GarageController>();
    final garage = controller.findById(garageId);
    final l10n = AppLocalizations.of(context);

    if (garage == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('notFound'))),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => context.go('/list'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.t('backToList')),
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
              tooltip: l10n.t('back'),
              onPressed: () => context.go('/list'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            actions: [
              IconButton.filledTonal(
                tooltip: controller.isFavorite(garageId)
                    ? l10n.t('favoriteOn')
                    : l10n.t('favoriteOff'),
                icon: Icon(
                  controller.isFavorite(garageId)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () => controller.toggleFavorite(garageId),
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
                          label: l10n.t('call'),
                          color: AppTheme.success,
                          onPressed: () => _launchExternal(
                            context,
                            Uri(
                              scheme: 'tel',
                              path: garage.phone.replaceAll(
                                RegExp(r'[^0-9+]'),
                                '',
                              ),
                            ),
                            l10n.t('launchFailed'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.directions_rounded,
                          label: l10n.t('route'),
                          color: theme.colorScheme.primary,
                          onPressed: () => _launchExternal(
                            context,
                            Uri.https('www.google.com', '/maps/dir/', {
                              'api': '1',
                              'destination':
                                  garage.latitude != null &&
                                      garage.longitude != null
                                  ? '${garage.latitude},${garage.longitude}'
                                  : '${garage.address}, ${garage.city}',
                            }),
                            l10n.t('launchFailed'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (garage.reviewStatus == 'approved')
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              garage.availabilityStatus == 'unavailable' ||
                                  garage.availabilityStatus == 'busy'
                              ? null
                              : () =>
                                    context.push('/request/new', extra: garage),
                          icon: const Icon(Icons.car_repair),
                          label: Text(l10n.t('requestHelp')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _writeReview(context, garage),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: Text(l10n.t('writeReview')),
                        ),
                        IconButton(
                          tooltip: l10n.t('reportGarage'),
                          onPressed: () => _reportGarage(context, garage),
                          icon: const Icon(Icons.flag_outlined),
                        ),
                      ],
                    ),
                  if (garage.reviewStatus == 'approved') ...[
                    const SizedBox(height: 8),
                    Text(l10n.t('availability_${garage.availabilityStatus}')),
                    if (garage.availabilityUpdatedAt != null)
                      Text(
                        '${l10n.t('availabilityUpdated')} ${MaterialLocalizations.of(context).formatShortDate(garage.availabilityUpdatedAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _HighlightTile(
                          icon: Icons.star_rounded,
                          label: l10n.t('rating'),
                          value: '${garage.rating.toStringAsFixed(1)} / 5',
                          detail: '${garage.reviewCount} avis',
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HighlightTile(
                          icon: Icons.near_me_rounded,
                          label: l10n.t('distance'),
                          value: garage.distanceKnown
                              ? '${garage.distanceKm.toStringAsFixed(1)} km'
                              : l10n.t('distanceUnavailable'),
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
                          label: l10n.t('status'),
                          value: garage.isOpen
                              ? l10n.t('openStatus')
                              : l10n.t('closedStatus'),
                          detail: garage.priceLevel,
                          color: garage.isOpen
                              ? AppTheme.success
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.t('overview'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    garage.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.t('information'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.location_on_rounded,
                            label: l10n.t('address'),
                            value: '${garage.city} · ${garage.address}',
                            color: theme.colorScheme.secondary,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.access_time_filled_rounded,
                            label: l10n.t('hours'),
                            value: _openingHoursLabel(
                              garage.openingHours,
                              l10n,
                            ),
                            color: garage.isOpen
                                ? AppTheme.success
                                : Colors.redAccent,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: l10n.t('phone'),
                            value: garage.phone,
                            color: AppTheme.success,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.person_rounded,
                            label: l10n.t('manager'),
                            value: garage.chief,
                            color: theme.colorScheme.primary,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: garage.isVerified
                                ? Icons.verified_rounded
                                : Icons.info_rounded,
                            label: l10n.t('trust'),
                            value: garage.isVerified
                                ? l10n.t('verified')
                                : l10n.t('unverified'),
                            color: garage.isVerified
                                ? theme.colorScheme.primary
                                : AppTheme.accent,
                          ),
                          const Divider(height: 24),
                          _InfoRow(
                            icon: Icons.link_rounded,
                            label: l10n.t('source'),
                            value: garage.sourceUrl,
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.t('services'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: garage.services.map((service) {
                      return _ServicePill(label: service);
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.t('reviews'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (context.read<GarageController>().repository
                      is CustomerWorkflowRepository)
                    _ReviewsSection(
                      garageId: garage.id,
                      repository:
                          context.read<GarageController>().repository
                              as CustomerWorkflowRepository,
                    ),
                  const SizedBox(height: 20),
                  Text(l10n.t('location'), style: theme.textTheme.titleLarge),
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

  String _openingHoursLabel(String value, AppLocalizations l10n) {
    try {
      final schedule = jsonDecode(value) as Map<String, dynamic>;
      if (schedule.isEmpty) return l10n.t('hoursNotSet');
      return schedule.entries
          .map((entry) {
            const dayKeys = {
              'monday': 'mon',
              'tuesday': 'tue',
              'wednesday': 'wed',
              'thursday': 'thu',
              'friday': 'fri',
              'saturday': 'sat',
              'sunday': 'sun',
            };
            final day = l10n.t('day_${dayKeys[entry.key] ?? entry.key}');
            final data = entry.value;
            if (data is List && data.length >= 2) {
              return '$day: ${data[0]}–${data[1]}';
            }
            if (data is! Map<String, dynamic>) return '$day: $data';
            if (data['closed'] == true) {
              return '$day: ${l10n.t('closedStatus')}';
            }
            return '$day: ${data['open'] ?? '--:--'}–${data['close'] ?? '--:--'}';
          })
          .join('\n');
    } on FormatException {
      return value;
    } on TypeError {
      return value;
    }
  }

  Future<void> _writeReview(BuildContext context, Garage garage) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final repository = context.read<GarageController>().repository;
    final controller = context.read<GarageController>();
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn ||
        auth.isGarageOwner ||
        repository is! CustomerWorkflowRepository) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('customerSignInRequired'))));
      return;
    }
    final workflow = repository as CustomerWorkflowRepository;
    try {
      if (!await workflow.canReviewGarage(garage.id)) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.t('reviewAfterService'))),
          );
        }
        return;
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (!context.mounted) return;
    var rating = 5;
    final comment = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.t('writeReview')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var value = 1; value <= 5; value++)
                    IconButton(
                      tooltip: '$value / 5',
                      onPressed: () => setDialogState(() => rating = value),
                      icon: Icon(
                        value <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                maxLength: 1200,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: l10n.t('reviewComment')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.t('sendReview')),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      try {
        await workflow.submitReview(garage.id, rating, comment.text);
        await controller.refreshGarage(garage.id);
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.t('reviewSaved'))),
          );
        }
      } catch (error) {
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    comment.dispose();
  }

  Future<void> _reportGarage(BuildContext context, Garage garage) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final repository = context.read<GarageController>().repository;
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn ||
        auth.isGarageOwner ||
        repository is! CustomerWorkflowRepository) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('customerSignInRequired'))));
      return;
    }
    String category = 'phone';
    final description = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.t('reportGarage')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [
                  for (final key in [
                    'phone',
                    'address',
                    'closed',
                    'behavior',
                    'other',
                  ])
                    DropdownMenuItem(
                      value: key,
                      child: Text(l10n.t('report_$key')),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => category = value ?? 'other'),
              ),
              TextField(
                controller: description,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.t('reportDetails')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.t('sendReport')),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) {
      try {
        await (repository as CustomerWorkflowRepository).reportGarage(
          garage.id,
          category,
          description.text,
        );
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.t('reportSent'))));
        }
      } catch (error) {
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    description.dispose();
  }
}

class _ReviewsSection extends StatelessWidget {
  final String garageId;
  final CustomerWorkflowRepository repository;

  const _ReviewsSection({required this.garageId, required this.repository});

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: repository.getReviews(garageId),
        builder: (context, snapshot) {
          final l10n = AppLocalizations.of(context);
          if (snapshot.hasError) return Text(snapshot.error.toString());
          if (!snapshot.hasData) return const LinearProgressIndicator();
          if (snapshot.data!.isEmpty) return Text(l10n.t('noReviews'));
          return Column(
            children: [
              for (final review in snapshot.data!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Row(
                    children: [
                      for (
                        var i = 0;
                        i < (review['rating'] as num).toInt();
                        i++
                      )
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
                  ),
                  subtitle: Text(
                    (review['comment'] as String?)?.trim().isNotEmpty == true
                        ? review['comment'] as String
                        : l10n.t('ratingOnly'),
                  ),
                  trailing: Text(
                    DateTime.tryParse(
                          review['created_at'] as String? ?? '',
                        )?.toLocal().toString().split(' ').first ??
                        '',
                  ),
                ),
            ],
          );
        },
      );
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
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
