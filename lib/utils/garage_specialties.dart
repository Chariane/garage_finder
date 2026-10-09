import '../core/localization/app_localizations.dart';

class GarageSpecialties {
  const GarageSpecialties._();

  static const Map<String, String> labelKeys = {
    'auto': 'specialtyAuto',
    'moto': 'specialtyMoto',
    'utilitaires': 'specialtyUtilityVehicles',
    'poids_lourds': 'specialtyHeavyVehicles',
    'depannage': 'specialtyRoadside',
    'electricite': 'specialtyElectrical',
    'diagnostic': 'specialtyDiagnostics',
    'pneumatiques': 'specialtyTires',
    'carrosserie': 'specialtyBodywork',
    'freinage': 'specialtyBrakes',
    'moteur': 'specialtyEngine',
    'climatisation': 'specialtyAirConditioning',
    'entretien': 'specialtyMaintenance',
    'batterie': 'specialtyBattery',
    'vitrage': 'specialtyGlass',
    'autre': 'specialtyOther',
  };

  static List<String> get values => labelKeys.keys.toList(growable: false);

  static String label(String value, AppLocalizations l10n) {
    final key = labelKeys[value];
    return key == null ? value : l10n.t(key);
  }

  static String? idForLegacyValue(String value) {
    final normalized = value.trim().toLowerCase();
    for (final entry in labelKeys.entries) {
      if (normalized == entry.key || normalized == _frenchLabels[entry.key]) {
        return entry.key;
      }
    }
    return switch (normalized) {
      'automobile' || 'mécanique automobile' => 'auto',
      'motorcycle' || 'motorbike' || 'scooter' => 'moto',
      'dépannage et remorquage' || 'remorquage' => 'depannage',
      'électricité et électronique' || 'électronique' => 'electricite',
      'pneus' || 'pneu' => 'pneumatiques',
      'carrosserie et peinture' || 'peinture' => 'carrosserie',
      'freins' || 'suspension' => 'freinage',
      'moteur et transmission' || 'transmission' => 'moteur',
      'vidange et entretien' || 'maintenance' => 'entretien',
      'batterie et démarrage' || 'démarrage' => 'batterie',
      'pare-brise' || 'vitres' => 'vitrage',
      _ => null,
    };
  }

  static const Map<String, String> _frenchLabels = {
    'auto': 'auto',
    'moto': 'moto / scooter',
    'utilitaires': 'véhicules utilitaires',
    'poids_lourds': 'poids lourds / bus',
    'depannage': 'dépannage / remorquage',
    'electricite': 'électricité / électronique',
    'diagnostic': 'diagnostic',
    'pneumatiques': 'pneumatiques',
    'carrosserie': 'carrosserie / peinture',
    'freinage': 'freinage / suspension',
    'moteur': 'moteur / transmission',
    'climatisation': 'climatisation',
    'entretien': 'vidange / entretien',
    'batterie': 'batterie / démarrage',
    'vitrage': 'vitrage',
    'autre': 'autre',
  };
}
