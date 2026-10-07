# Garage Finder

[![Flutter CI](https://github.com/Chariane/garage_finder/actions/workflows/flutter.yml/badge.svg)](https://github.com/Chariane/garage_finder/actions/workflows/flutter.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)

Application mobile pour rechercher des garages et services de dépannage au Bénin. Supabase fournit les comptes, les fiches et la recherche géographique; SQLite conserve un cache public et les favoris sur l’appareil.

## Fonctionnalités

- Accueil, recherche, détails, favoris, ajout de garage et réglages.
- Inscription/connexion e-mail, confirmation de compte, réinitialisation du mot de passe et rôles client/garagiste.
- Espace garagiste, création/suppression de fiches et statut de modération.
- Modification des fiches, horaires par jour et disponibilité actuelle (disponible, occupé, urgences seulement, indisponible).
- Demande de dépannage avec véhicule, description, téléphone et partage de position facultatif; suivi accepté/en route/terminé avec ETA.
- Avis clients uniques par compte, signalements et boîte de notifications temps réel dans l’application.
- Recherche par GPS, adresse géocodée ou coordonnées, avec rayon réglable; filtres texte, ville, spécialité, SOS et tri.
- Formulaire garage avec coordonnées exactes, services, budget, disponibilité et photo facultative.
- Itinéraire ouvert dans Google Maps; les coordonnées client restent en mémoire et ne sont pas envoyées au serveur hors requête de proximité.
- Cache SQLite des fiches publiques et favoris; création/modification de fiches et téléversement de photos nécessitent une connexion.
- Interface française et anglaise, thème clair/sombre.
- Images chargées à la demande dans les listes et décodées à une taille adaptée aux vignettes.
- Contrôles accessibles avec libellés sémantiques et cibles tactiles Material.

## Captures d’écran

Captures à ajouter dans `screenshots/` après exécution sur appareil ou émulateur : accueil, recherche, détail et réglages. Les visuels de `assets/images/` sont des images de l’application, pas des captures d’écran de l’interface.

## Architecture

```text
lib/
  controllers/       État applicatif et orchestration
  core/database/     Initialisation et schéma SQLite
  core/localization/ Catalogue FR/EN
  data/              Données initiales des garages
  models/            Modèle immutable Garage et mapping SQLite
  repositories/      Dépôts SQLite, Supabase et mémoire
  screens/           Écrans et navigation
  utils/             Filtrage et tri métier
  widgets/            Composants partagés, images optimisées
```

`GarageController` dépend de `GarageRepository`. Le dépôt Supabase utilise PostGIS pour le rayon et SQLite comme cache de lecture hors ligne. Les nouveaux garages restent invisibles au public jusqu’à leur modération.

## Backend distant

Le backend cible est Supabase : Supabase Auth pour les comptes, PostgreSQL avec PostGIS pour les garages et la recherche par proximité, et Supabase Storage pour les photos. SQLite reste le cache local; le serveur doit être la source de vérité dès que le client Supabase est configuré.

Les migrations sont dans `supabase/migrations/`. Exécute-les dans l’ordre : la première crée profils, garages, avis, RLS, photos et `nearby_garages`; la seconde ajoute les demandes de dépannage, transitions de statut, ETA, disponibilité, notifications temps réel et signalements; la troisième ajoute l’annulation par le client et l’expiration automatique des demandes sans réponse après 30 minutes. Elle nécessite l’extension `pg_cron`, disponible dans Supabase et à activer si le projet ne l’a pas déjà activée. Les demandes limitent les positions précises aux cas où le client coche explicitement le partage; ces coordonnées sont conservées avec sa demande.

Pour l’activer : crée un projet Supabase, vérifie que PostGIS est installé dans le schéma `extensions` et active `pg_cron`, puis applique les migrations avec Supabase CLI ou l’éditeur SQL du tableau de bord. Active la confirmation des e-mails et configure les URL Auth. Fournis `SUPABASE_URL` et la clé publique `publishable` au lancement; ne mets jamais une clé `service_role` dans Flutter ni dans Git. La modération permet de valider/refuser les garages et de traiter les signalements; elle exige un claim `app_metadata.role=admin`, attribué uniquement par un environnement de confiance (jamais par le client mobile). Un refus documenté renvoie automatiquement la fiche en attente après correction d’un champ substantiel. Les clés et le déploiement restent propres à l’environnement.

Une fiche est visible dans les résultats publics uniquement après modération. Les changements importants d’une fiche publiée la remettent en attente de validation. Les comptes garagistes ne modifient que leurs fiches; le propriétaire et le statut de modération sont protégés par la base. Les demandes ont des transitions de statut contrôlées côté SQL et génèrent des notifications dans l’app via Supabase Realtime. Les notifications push quand l’application est fermée demandent encore une configuration Firebase/FCM propre à Android et iOS.

Un client ne peut noter un garage qu’après qu’une demande associée est marquée terminée. Chaque compte possède un avis par garage et peut le mettre à jour. Les signalements sont visibles par les modérateurs dont le claim Auth `app_metadata.role` vaut `admin`.

## Prérequis et démarrage

- Flutter 3.38 ou supérieur (Dart 3.10 ou supérieur)
- Android Studio avec SDK Android, ou Xcode sur macOS pour iOS

```bash
git clone https://github.com/Chariane/garage_finder.git
cd garage_finder
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Sans ces deux paramètres, l’application démarre en mode démonstration SQLite. N’ajoute pas les valeurs réelles dans les scripts partagés ou le dépôt.

La base `garage_finder.db` est créée au premier démarrage. Si elle est vide, elle est initialisée avec les données de démonstration.

## Vérifications

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart -d <appareil>
```

La suite couvre le modèle, les filtres, le contrôleur, le dépôt SQLite, les widgets et deux parcours utilisateur. La CI exécute analyse, tests, parcours Android et construit un APK de démonstration.

## Build de démonstration

```bash
flutter build apk --debug
```

L’APK est produit dans `build/app/outputs/flutter-apk/app-debug.apk`. La CI publie également cet APK comme artefact téléchargeable pour chaque exécution réussie sur `main` ou lors d’une pull request.

## Limites connues

Les jeux de données initiaux restent des exemples. Les workflows Supabase nécessitent le déploiement des migrations et un compte administrateur configuré. Les notifications sont temps réel dans l’app, sans push arrière-plan FCM. La gestion en ligne requiert une connexion; aucune file de synchronisation des créations hors ligne n’est implémentée. Les horaires sont affichés mais l’ouverture n’est pas calculée automatiquement selon le fuseau horaire. Les préférences de thème et de langue restent conservées pendant la session.

## Versions

Voir [CHANGELOG.md](CHANGELOG.md).
