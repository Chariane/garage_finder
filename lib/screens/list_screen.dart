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
        _filteredGarages = _allGarages.where((garage) {
          final lowerQuery = query.toLowerCase();
          return garage.name.toLowerCase().contains(lowerQuery) ||
              garage.address.toLowerCase().contains(lowerQuery) ||
              garage.specialty.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garages disponibles'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Rechercher par nom, ville ou spécialité...',
              onChanged: _filterGarages,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredGarages.length} garage(s) trouvé(s)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
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
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun garage trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Essayez un autre mot-clé',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredGarages.length,
                    itemBuilder: (context, index) {
                      final garage = _filteredGarages[index];
                      return GarageCard(
                        garage: garage,
                        onTap: () {
                          context.go('/detail/${garage.id}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}