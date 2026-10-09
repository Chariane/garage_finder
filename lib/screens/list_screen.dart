import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../utils/garage_filters.dart';
import '../utils/garage_specialties.dart';
import '../widgets/garage_card.dart';
import '../widgets/offline_data_banner.dart';
import '../widgets/location_search_dialog.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editBudget(
    GarageController controller,
    AppLocalizations l10n,
  ) async {
    final minimum = TextEditingController(
      text: controller.minimumPriceCfa?.toString() ?? '',
    );
    final maximum = TextEditingController(
      text: controller.maximumPriceCfa?.toString() ?? '',
    );
    final result = await showDialog<({int? minimum, int? maximum})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('budget')),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minimum,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.t('priceMin')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: maximum,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.t('priceMax')),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (minimum: null, maximum: null)),
            child: Text(l10n.t('clearSearch')),
          ),
          FilledButton(
            onPressed: () {
              final min = int.tryParse(minimum.text.trim());
              final max = int.tryParse(maximum.text.trim());
              if (min != null && max != null && min > max) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.t('invalidPriceRange'))),
                );
                return;
              }
              Navigator.pop(context, (minimum: min, maximum: max));
            },
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    minimum.dispose();
    maximum.dispose();
    if (result == null || !mounted) return;
    controller.setPriceRange(
      minimumCfa: result.minimum,
      maximumCfa: result.maximum,
    );
    if (controller.hasSearchLocation) {
      await controller.searchNearby(
        latitude: controller.userLatitude!,
        longitude: controller.userLongitude!,
        radiusMeters: controller.searchRadiusMeters,
      );
    }
  }

  Future<void> _editSpecialties(
    GarageController controller,
    AppLocalizations l10n,
  ) async {
    final selected = Set<String>.of(controller.selectedSpecialties);
    final available = {
      ...GarageSpecialties.values,
      ...controller.specialties,
    }.toList()..sort();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('specialtiesFilterTitle'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selected.length} ${l10n.t('specialtiesSelected')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final specialty in available)
                            FilterChip(
                              label: Text(
                                GarageSpecialties.label(specialty, l10n),
                              ),
                              selected: selected.contains(specialty),
                              onSelected: (value) => setSheetState(() {
                                if (value) {
                                  selected.add(specialty);
                                } else {
                                  selected.remove(specialty);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(selected.clear),
                        child: Text(l10n.t('clearSpecialties')),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: Text(l10n.t('applyFilters')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    controller.setSpecialties(result);
    if (controller.hasSearchLocation) {
      await controller.searchNearby(
        latitude: controller.userLatitude!,
        longitude: controller.userLongitude!,
        radiusMeters: controller.searchRadiusMeters,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GarageController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final garages = controller.filteredGarages;

    Future<void> chooseSearchLocation() async {
      final selection = await showDialog<LocationSelection>(
        context: context,
        builder: (_) => const LocationSearchDialog(),
      );
      if (selection == null || !context.mounted) return;
      await controller.searchNearby(
        latitude: selection.latitude,
        longitude: selection.longitude,
        radiusMeters: controller.searchRadiusMeters,
      );
    }

    Future<void> updateRadius(int? radius) async {
      if (radius == null) return;
      if (!controller.hasSearchLocation) {
        controller.setSearchRadius(radius);
        return;
      }
      await controller.searchNearby(
        latitude: controller.userLatitude!,
        longitude: controller.userLongitude!,
        radiusMeters: radius,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('garages'))),
      body: Column(
        children: [
          if (controller.isShowingOfflineData)
            OfflineDataBanner(lastUpdated: controller.cacheUpdatedAt),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: controller.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.t('searchHint'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.t('clearSearch'),
                            onPressed: () {
                              _searchController.clear();
                              controller.setQuery('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: chooseSearchLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(
                          controller.hasSearchLocation
                              ? l10n.t('locationFound')
                              : l10n.t('findNearby'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: l10n.t('searchRadius'),
                      child: DropdownButton<int>(
                        value: controller.searchRadiusMeters,
                        items: [
                          for (final radius in [5000, 10000, 25000, 50000])
                            DropdownMenuItem(
                              value: radius,
                              child: Text('${radius ~/ 1000} km'),
                            ),
                        ],
                        onChanged: updateRadius,
                      ),
                    ),
                    if (controller.hasSearchLocation)
                      IconButton(
                        tooltip: l10n.t('clearSearch'),
                        onPressed: controller.clearSearchLocation,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editBudget(controller, l10n),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.t('budget')),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: controller.city,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.t('allCities'),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              l10n.t('allCities'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final city in controller.cities)
                            DropdownMenuItem<String?>(
                              value: city,
                              child: Text(
                                city,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: controller.setCity,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editSpecialties(controller, l10n),
                        icon: const Icon(Icons.tune),
                        label: Text(
                          controller.selectedSpecialties.isEmpty
                              ? l10n.t('allSpecialties')
                              : '${controller.selectedSpecialties.length} ${l10n.t('specialtiesSelected')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final sortButton = SegmentedButton<GarageSortMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: GarageSortMode.distance,
                          icon: const Icon(Icons.near_me),
                          label: Text(l10n.t('near')),
                        ),
                        ButtonSegment(
                          value: GarageSortMode.rating,
                          icon: const Icon(Icons.star),
                          label: Text(l10n.t('rating')),
                        ),
                        ButtonSegment(
                          value: GarageSortMode.response,
                          icon: const Icon(Icons.bolt),
                          label: Text(l10n.t('fast')),
                        ),
                      ],
                      selected: {controller.sortMode},
                      onSelectionChanged: (selection) =>
                          controller.setSortMode(selection.first),
                    );
                    final emergencyFilter = FilterChip(
                      avatar: const Icon(Icons.flash_on, size: 18),
                      label: Text(l10n.t('emergency')),
                      selected: controller.sosOnly,
                      onSelected: controller.setSosOnly,
                    );

                    if (constraints.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          emergencyFilter,
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: sortButton),
                        ],
                      );
                    }
                    return Row(
                      children: [emergencyFilter, const Spacer(), sortButton],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${garages.length} ${garages.length == 1 ? l10n.t('result') : l10n.t('results')}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : garages.isEmpty
                ? Center(child: Text(l10n.t('noGarage')))
                : ListView.builder(
                    itemCount: garages.length,
                    itemBuilder: (context, index) {
                      final garage = garages[index];
                      return RepaintBoundary(
                        child: GarageCard(
                          garage: garage,
                          onTap: () => context.go('/detail/${garage.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
