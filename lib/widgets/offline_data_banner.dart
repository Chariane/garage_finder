import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';

class OfflineDataBanner extends StatelessWidget {
  final DateTime? lastUpdated;

  const OfflineDataBanner({super.key, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = lastUpdated;
    final detail = date == null
        ? l10n.t('offlineCacheUnknown')
        : '${l10n.t('offlineCacheUpdated')} ${MaterialLocalizations.of(context).formatMediumDate(date)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('offlineMode'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
