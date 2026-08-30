import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/garage_data.dart';
import '../models/garage.dart';
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

  @override
  void initState() {
    super.initState();
    _filteredGarages = _allGarages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterGarages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGarages = _allGarages;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredGarages = _allGarages.where((g) {
          return g.name.toLowerCase().contains(lowerQuery) ||
              g.address.toLowerCase().contains(lowerQuery) ||
              g.specialty.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterGarages('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garages disponibles'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: CustomSearchBar(
                    controller: _searchController,
                    hintText: 'Rechercher...',
                    onChanged: _filterGarages,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredGarages.length} garage(s) trouvé(s)',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredGarages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucun garage trouvé'),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (isTablet) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredGarages.length,
                          itemBuilder: (context, index) {
                            final garage = _filteredGarages[index];
                            return FadeInAnimation(
                              delay: index * 50,
                              child: GarageCard(
                                garage: garage,
                                onTap: () =>
                                    context.go('/detail/${garage.id}'),
                              ),
                            );
                          },
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredGarages.length,
                          itemBuilder: (context, index) {
                            final garage = _filteredGarages[index];
                            return FadeInAnimation(
                              delay: index * 50,
                              child: GarageCard(
                                garage: garage,
                                onTap: () =>
                                    context.go('/detail/${garage.id}'),
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

// Widget d'animation réutilisable
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