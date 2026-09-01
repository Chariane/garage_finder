import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/garage_data.dart';
import '../models/garage.dart';
import '../theme/app_theme.dart';
import '../widgets/garage_card.dart';
import '../widgets/search_bar.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Garage> _allGarages = garages;
  List<Garage> _filteredGarages = [];
  String _selectedCity = 'Tout le Bénin';
  String _selectedSpecialty = 'Tous';
  String _sortMode = 'distance';
  bool _sosMode = false;

  @override
  void initState() {
    super.initState();
    _filteredGarages = List.of(_allGarages)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _specialties {
    final values =
        _allGarages.map((garage) => garage.specialty).toSet().toList()..sort();
    return ['Tous', ...values];
  }

  List<String> get _cities {
    final values = _allGarages.map((garage) => garage.city).toSet().toList()
      ..sort();
    return ['Tout le Bénin', ...values];
  }

  int _responseMinutes(Garage garage) {
    return int.tryParse(garage.responseTime.replaceAll(RegExp(r'\D'), '')) ??
        999;
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredGarages = _allGarages.where((garage) {
        final matchesQuery =
            query.isEmpty ||
            garage.name.toLowerCase().contains(query) ||
            garage.city.toLowerCase().contains(query) ||
            garage.address.toLowerCase().contains(query) ||
            garage.specialty.toLowerCase().contains(query) ||
            garage.chief.toLowerCase().contains(query) ||
            garage.description.toLowerCase().contains(query) ||
            garage.services.any(
              (service) => service.toLowerCase().contains(query),
            );
        final matchesSpecialty =
            _selectedSpecialty == 'Tous' ||
            garage.specialty == _selectedSpecialty;
        final matchesCity =
            _selectedCity == 'Tout le Bénin' || garage.city == _selectedCity;
        final matchesSos = !_sosMode || (garage.isOpen && garage.distanceKm <= 10.0);

        return matchesQuery && matchesSpecialty && matchesCity && matchesSos;
      }).toList();

      _filteredGarages.sort((a, b) {
        return switch (_sortMode) {
          'rating' => b.rating.compareTo(a.rating),
          'response' => _responseMinutes(a).compareTo(_responseMinutes(b)),
          _ => a.distanceKm.compareTo(b.distanceKm),
        };
      });
    });
  }

  void _filterGarages(String query) => _applyFilters();

  void _clearSearch() {
    _searchController.clear();
    _applyFilters();
  }

  void _selectSpecialty(String specialty) {
    _selectedSpecialty = specialty;
    _applyFilters();
  }

  void _selectCity(String city) {
    _selectedCity = city;
    _applyFilters();
  }

  void _selectSortMode(String sortMode) {
    _sortMode = sortMode;
    _applyFilters();
  }

  void _toggleSosMode() {
    setState(() {
      _sosMode = !_sosMode;
      if (_sosMode) {
        _sortMode = 'response';
      }
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garages & Dépannage'),
        actions: [
          IconButton(
            tooltip: 'Accueil',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_sosMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.redAccent.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '🚨 Mode Dépannage d’Urgence Actif',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Garages ouverts et proches pour une intervention rapide',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleSosMode,
                    child: const Text('Désactiver'),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomSearchBar(
                        controller: _searchController,
                        hintText: 'Nom, ville, mécanique, dépannage...',
                        onChanged: _filterGarages,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _sosMode,
                      selectedColor: Colors.redAccent.withValues(alpha: 0.2),
                      side: _sosMode ? const BorderSide(color: Colors.redAccent) : null,
                      avatar: Icon(
                        Icons.flash_on_rounded,
                        size: 16,
                        color: _sosMode ? Colors.redAccent : theme.colorScheme.primary,
                      ),
                      label: Text(
                        'Panne ⚡',
                        style: TextStyle(
                          color: _sosMode ? Colors.redAccent : theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSelected: (_) => _toggleSosMode(),
                    ),
                    if (_searchController.text.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearSearch,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cities.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final city = _cities[index];
                      final isSelected = city == _selectedCity;

                      return FilterChip(
                        selected: isSelected,
                        label: Text(city, style: const TextStyle(fontSize: 12)),
                        avatar: Icon(
                          city == 'Tout le Bénin'
                              ? Icons.public_rounded
                              : Icons.location_city_rounded,
                          size: 16,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodyMedium?.color,
                        ),
                        onSelected: (_) => _selectCity(city),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _specialties.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final specialty = _specialties[index];
                      final isSelected = specialty == _selectedSpecialty;

                      return FilterChip(
                        selected: isSelected,
                        label: Text(specialty, style: const TextStyle(fontSize: 12)),
                        avatar: Icon(
                          specialty == 'Tous'
                              ? Icons.apps_rounded
                              : Icons.build_rounded,
                          size: 16,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodyMedium?.color,
                        ),
                        onSelected: (_) => _selectSpecialty(specialty),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'distance',
                      icon: Icon(Icons.near_me_rounded, size: 16),
                      label: Text('Proche', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'rating',
                      icon: Icon(Icons.star_rounded, size: 16),
                      label: Text('Note', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: 'response',
                      icon: Icon(Icons.flash_on_rounded, size: 16),
                      label: Text('Rapide', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {_sortMode},
                  onSelectionChanged: (selection) {
                    _selectSortMode(selection.first);
                  },
                  showSelectedIcon: false,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _filteredGarages.isEmpty
                        ? Colors.redAccent
                        : AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredGarages.length} garage(s) trouvé(s)',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredGarages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun garage trouvé',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Essayez d’élargir vos filtres ou de désactiver la recherche d’urgence.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (isTablet) {
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 520,
                            mainAxisExtent: 118,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _filteredGarages.length,
                          itemBuilder: (context, index) {
                            final garage = _filteredGarages[index];
                            return FadeInAnimation(
                              delay: index * 40,
                              child: GarageCard(
                                garage: garage,
                                onTap: () => context.go('/detail/${garage.id}'),
                              ),
                            );
                          },
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
                          itemCount: _filteredGarages.length,
                          itemBuilder: (context, index) {
                            final garage = _filteredGarages[index];
                            return FadeInAnimation(
                              delay: index * 40,
                              child: GarageCard(
                                garage: garage,
                                onTap: () => context.go('/detail/${garage.id}'),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FadeInAnimation extends StatelessWidget {
  final Widget child;
  final int delay;

  const FadeInAnimation({super.key, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
