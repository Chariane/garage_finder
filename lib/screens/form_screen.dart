import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/garage.dart';
import '../data/garage_data.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _chiefController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();

  String _imageUrl = 'https://picsum.photos/seed/default/400/300';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _chiefController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  void _addGarage() {
    if (_formKey.currentState!.validate()) {
      final newGarage = Garage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        chief: _chiefController.text,
        specialty: _specialtyController.text,
        imageUrl: _imageUrl,
      );

      garages.add(newGarage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Garage "${newGarage.name}" ajouté avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter mon garage'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du garage *',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du garage';
                  }
                  if (value.length < 3) {
                    return 'Le nom doit contenir au moins 3 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer l\'adresse';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le numéro de téléphone';
                  }
                  final phoneDigits = value.replaceAll(RegExp(r'\D'), '');
                  if (phoneDigits.length < 10) {
                    return 'Numéro invalide (10 chiffres minimum)';
                  }
                  return null;
                },
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _chiefController,
                decoration: const InputDecoration(
                  labelText: 'Nom du chef de garage *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du chef';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _specialtyController,
                decoration: const InputDecoration(
                  labelText: 'Spécialité * (ex: Motos, Autos, Poids lourds)',
                  prefixIcon: Icon(Icons.build),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer la spécialité';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: _imageUrl,
                decoration: const InputDecoration(
                  labelText: 'URL de l\'image (optionnel)',
                  prefixIcon: Icon(Icons.image),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    _imageUrl = value;
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    _imageUrl = 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSubmitButton(context),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  context.go('/');
                },
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return SizedBox(
      width: isTablet ? 400 : double.infinity,
      child: ElevatedButton(
        onPressed: _addGarage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Ajouter le garage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}