import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../widgets/garage_card.dart';
import '../widgets/garage_image.dart';
import '../widgets/offline_data_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GarageController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final featured = controller.garages.take(4).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('appTitle')),
        actions: [
          IconButton(
            tooltip: l10n.t('theme'),
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => context.read<ThemeProvider>().setThemeMode(
              theme.brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (controller.isShowingOfflineData)
            SliverToBoxAdapter(
              child: OfflineDataBanner(lastUpdated: controller.cacheUpdatedAt),
            ),
          SliverToBoxAdapter(
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                const SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: GarageImage(
                    imagePath: 'assets/images/garage_hero.png',
                    semanticLabel: 'Garage automobile',
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.t('findGarage'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('findGarageSubtitle'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => context.go('/list'),
                        icon: const Icon(Icons.search),
                        label: Text(l10n.t('findGarage')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.t('recommended'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/list'),
                    child: Text(l10n.t('garages')),
                  ),
                ],
              ),
            ),
          ),
          if (controller.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.errorMessage != null)
            SliverFillRemaining(
              child: Center(child: Text(controller.errorMessage!)),
            )
          else if (featured.isEmpty)
            SliverFillRemaining(child: Center(child: Text(l10n.t('noGarage'))))
          else
            SliverList.builder(
              itemCount: featured.length,
              itemBuilder: (context, index) {
                final garage = featured[index];
                return RepaintBoundary(
                  child: GarageCard(
                    garage: garage,
                    onTap: () => context.go('/detail/${garage.id}'),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }
}
