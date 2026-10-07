import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../widgets/garage_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GarageController>();
    final favorites = controller.favorites;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('favorites'))),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_border, size: 44),
                  const SizedBox(height: 12),
                  Text(l10n.t('emptyFavorites')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/list'),
                    child: Text(l10n.t('garages')),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final garage = favorites[index];
                return RepaintBoundary(
                  child: GarageCard(
                    garage: garage,
                    onTap: () => context.go('/detail/${garage.id}'),
                  ),
                );
              },
            ),
    );
  }
}
