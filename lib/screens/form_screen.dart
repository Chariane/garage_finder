import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../theme/app_theme.dart';
import '../widgets/garage_image.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _chiefController = TextEditingController();
  final _specialtyController = TextEditingController();
  String _imageUrl = 'assets/images/garage_service.png';
  bool _isSubmitting = false;

  final List<Map<String, String>> _imagePresets = [
    {'label': 'presetService', 'path': 'assets/images/garage_form_banner.png'},
    {'label': 'presetCar', 'path': 'assets/images/garage_auto.png'},
    {'label': 'presetMotorcycle', 'path': 'assets/images/garage_moto.png'},
    {
      'label': 'presetEmergency',
      'path': 'assets/images/garage_breakdown_sos.png',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _chiefController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  void _addGarage() async {
    final l10n = AppLocalizations.of(context);
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final newGarage = Garage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        chief: _chiefController.text,
        specialty: _specialtyController.text,
        imageUrl: _imageUrl,
        city: 'Cotonou',
        openingHours: 'Lun-Sam · Horaires variables',
        description:
            'Garage professionnel avec service rapide et assistance en cas de panne.',
        sourceUrl: 'Ajout local',
        rating: 0,
        reviewCount: 0,
        distanceKm: 0,
        distanceKnown: false,
        isOpen: false,
        isVerified: false,
        reviewStatus: 'pending',
        responseTime: '',
        priceLevel: '',
        services: [_specialtyController.text, 'Diagnostic', 'Dépannage'],
      );
      final controller = context.read<GarageController>();
      await controller.addGarage(newGarage);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(l10n.text('garageAdded', {'name': newGarage.name})),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      );
      context.go('/list');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('registerGarage')), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0B1020), const Color(0xFF121826)]
                : [const Color(0xFFF6F8FC), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GarageImage(
                              imagePath: _imageUrl,
                              width: double.infinity,
                              height: 140,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.60),
                                    Colors.black.withValues(alpha: 0.20),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_business_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    l10n.t('formHeader'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('formIntro'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _nameController,
                              label: l10n.t('garageName'),
                              icon: Icons.business_rounded,
                              validator: (v) => v!.isEmpty
                                  ? l10n.t('nameRequired')
                                  : v.length < 3
                                  ? l10n.t('nameTooShort')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _addressController,
                              label: l10n.t('fullAddress'),
                              icon: Icons.location_on_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? l10n.t('addressRequired') : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _phoneController,
                              label: l10n.t('contactPhone'),
                              icon: Icons.phone_rounded,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v!.isEmpty) return l10n.t('phoneRequired');
                                final digits = v.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 8) {
                                  return l10n.t('invalidPhone');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _chiefController,
                              label: l10n.t('managerName'),
                              icon: Icons.person_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? l10n.t('nameRequired') : null,
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _specialtyController,
                              label: l10n.t('specialtyLabel'),
                              icon: Icons.build_rounded,
                              validator: (v) => v!.isEmpty
                                  ? l10n.t('specialtyRequired')
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              l10n.t('imageTitle'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 70,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imagePresets.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final preset = _imagePresets[index];
                                  final isSelected =
                                      _imageUrl == preset['path'];

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _imageUrl = preset['path']!;
                                      });
                                    },
                                    child: Container(
                                      width: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            GarageImage(
                                              imagePath: preset['path']!,
                                              width: 100,
                                              height: 70,
                                            ),
                                            Container(
                                              color: Colors.black.withValues(
                                                alpha: 0.45,
                                              ),
                                              alignment: Alignment.center,
                                              padding: const EdgeInsets.all(4),
                                              child: Text(
                                                l10n.t(preset['label']!),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Icon(
                                                  Icons.check_circle_rounded,
                                                  color:
                                                      theme.colorScheme.primary,
                                                  size: 18,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _addGarage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            l10n.t('saveGarage'),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => context.go('/'),
                                child: Text(
                                  l10n.t('cancel'),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : AppTheme.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : AppTheme.muted,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF182033) : const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
