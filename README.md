# Garage Finder

[![Flutter CI](https://github.com/Chariane/garage_finder/actions/workflows/flutter.yml/badge.svg)](https://github.com/Chariane/garage_finder/actions/workflows/flutter.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.38%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)

Application mobile pour rechercher des garages et services de dépannage au Bénin. Supabase fournit les comptes, les fiches et la recherche géographique; SQLite conserve un cache public et les favoris sur l’appareil.

## Fonctionnalités

- Accueil, recherche, détails, favoris, ajout de garage et réglages.
- Recherche publique sans compte avec localisation, rayon, ville, spécialité, budget, disponibilité et tri par proximité/avis/temps de réponse; un compte client est demandé uniquement pour envoyer des demandes et publier des avis.
- Inscription/connexion e-mail, confirmation de compte, réinitialisation du mot de passe et rôles client/garagiste.
- Espace garagiste, création/suppression de fiches et statut de modération.
- Vérification du téléphone du garage par code SMS (Twilio Verify), puis contrôles de cohérence avant modération.
- Modification des fiches, horaires par jour et disponibilité actuelle (disponible, occupé, urgences seulement, indisponible).
- Demande de dépannage avec véhicule, description, téléphone et partage de position facultatif; suivi accepté/en route/terminé avec ETA.
- Avis clients uniques par compte, signalements et boîte de notifications temps réel dans l’application.
- Recherche par GPS, adresse géocodée ou coordonnées, avec rayon réglable; filtres texte, ville, spécialité, SOS et tri.
- Formulaire garage avec coordonnées exactes, services, budget, disponibilité et photo facultative.
- Itinéraire ouvert dans Google Maps; les coordonnées client restent en mémoire et ne sont pas envoyées au serveur hors requête de proximité.
- Appel téléphonique et ouverture d’un brouillon WhatsApp prérempli, sans envoi automatique.
- Demande de dépannage avec rappel des étapes, accès direct à l’appel/WhatsApp pour l’urgence et suivi dans l’espace client.
- Cache SQLite des garages publics vérifiés et favoris; recherches de proximité hors ligne avec filtres locaux et date de dernière synchronisation. Les nouvelles demandes, avis et modifications de fiches nécessitent une connexion.
- Checklist de configuration garagiste : coordonnées, position, fiche et validation.
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
supabase/
  functions/         Fonctions Edge (vérification SMS et présence)
  migrations/        Schéma, politiques RLS et fonctions PostgreSQL
```

`GarageController` dépend de `GarageRepository`. Le dépôt Supabase utilise PostGIS pour le rayon et SQLite comme cache de lecture hors ligne sur mobile et desktop. En cas de coupure, la recherche à proximité se rabat sur le cache, applique les filtres localement et indique sa date de fraîcheur. Un cache vide ne déclenche pas de fausses fiches de démonstration en mode distant. L’aperçu web utilise un cache mémoire. Les nouveaux garages restent invisibles au public jusqu’à leur modération.

## Backend distant

Le backend cible est Supabase : Supabase Auth pour les comptes, PostgreSQL avec PostGIS pour les garages et la recherche par proximité, et Supabase Storage pour les photos. SQLite reste le cache local; le serveur doit être la source de vérité dès que le client Supabase est configuré.

Les sept migrations sont dans `supabase/migrations/`. Elles créent le modèle plateforme, les workflows client/garagiste, l’annulation et l’expiration des demandes, la localisation d’inscription, l’inbox propriétaire, les filtres multi-spécialités, puis le contrôle des garages par téléphone et présence sur place. La migration d’expiration nécessite `pg_cron`, disponible dans Supabase. Les demandes ne conservent une position précise que si le client coche explicitement le partage.

Pour l’activer : crée un projet Supabase, vérifie que PostGIS est installé dans le schéma `extensions` et active `pg_cron`, puis applique les migrations dans l’ordre avec Supabase CLI ou l’éditeur SQL du tableau de bord. Active la confirmation des e-mails et configure les URL Auth. Fournis `SUPABASE_URL` et la clé publique `publishable` au lancement; ne mets jamais une clé `service_role` dans Flutter ni dans Git. La modération exige le claim `app_metadata.role=admin`, attribué uniquement par un environnement de confiance. Un refus documenté renvoie automatiquement la fiche en attente après correction d’un champ substantiel.

### Vérification automatique des garages

Le parcours garagiste demande un code SMS via la fonction Edge `garage-phone-verification`, qui appelle Twilio Verify côté serveur. Le code n’est jamais généré ni validé par l’application Flutter. Le propriétaire doit ensuite fournir un signal GPS depuis le garage. La base calcule elle-même la distance entre ce signal et l’épingle enregistrée; les seuils actuels sont 150 m maximum et une précision déclarée de 50 m maximum. Un signal de présence datant de plus de 24 h est considéré obsolète lors du prochain contrôle.

Les contrôles marquent aussi les numéros réutilisés par un autre propriétaire, les garages au nom similaire à moins de 250 m et l’absence de photo. L’interface de modération présente le résultat et les motifs pour aider au tri. Un statut automatique `passed` signifie uniquement que les signaux configurés ont passé leurs seuils; il ne publie pas la fiche. La validation finale reste humaine.

Pour activer ce flux sur un projet Supabase :

1. Crée un service Twilio Verify et configure son nom affiché comme `Garage Finder`.
2. Dans **Supabase Dashboard > Edge Functions > Secrets**, ajoute `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` et `TWILIO_VERIFY_SERVICE_SID`. Ne partage pas ces valeurs et ne les ajoute jamais à Flutter ou à Git.
3. Avec Supabase CLI, lie le dépôt au projet : `supabase link --project-ref <project-ref>`.
4. Déploie la fonction : `supabase functions deploy garage-phone-verification`.
5. Applique `supabase/migrations/202610090002_garage_phone_verification.sql` via l’éditeur SQL du dashboard, ou avec `supabase db push` si l’historique des migrations CLI est déjà synchronisé avec ce projet.

Cette séquence déploie la fonction avant d’activer dans PostgreSQL l’obligation de vérifier le téléphone. Les demandes de code sont limitées à un envoi par minute et trois par heure, par compte et par numéro. Le numéro doit être au format international E.164 (par exemple `+229...`). Les comptes Twilio d’essai peuvent limiter l’envoi aux numéros destinataires préalablement vérifiés chez Twilio.

Ces contrôles augmentent la confiance mais ne prouvent pas, à eux seuls, l’existence juridique du garage. La détection des positions simulées est une défense côté application, pas une garantie contre un client modifié; une photo peut également être trompeuse. Pour une vérification légale plus forte, un modérateur doit demander et examiner des justificatifs fiables selon les règles applicables localement.

Une fiche est visible dans les résultats publics uniquement après modération. Les changements importants d’une fiche publiée la remettent en attente de validation. Les comptes garagistes ne modifient que leurs fiches; le propriétaire et le statut de modération sont protégés par la base. Les demandes ont des transitions de statut contrôlées côté SQL et génèrent des notifications dans l’app via Supabase Realtime. Les notifications push quand l’application est fermée demandent encore une configuration Firebase/FCM propre à Android et iOS.

Un client ne peut noter un garage qu’après qu’une demande associée est marquée terminée. Chaque compte possède un avis par garage et peut le mettre à jour. Les signalements sont visibles par les modérateurs dont le claim Auth `app_metadata.role` vaut `admin`.

## Prérequis et démarrage

- Flutter 3.38 ou supérieur (Dart 3.10 ou supérieur)
- Android Studio avec SDK Android, ou Xcode sur macOS pour iOS

```bash
git clone https://github.com/Chariane/garage_finder.git
cd garage_finder
flutter pub get
cp config/supabase.example.json config/supabase.json
# Renseigner l’URL Supabase et la clé publishable dans config/supabase.json
bash tool/run.sh chrome
```

Le fichier `config/supabase.json` est ignoré par Git. Pour lancer sur l’appareil Flutter par défaut, utilise `bash tool/run.sh`; pour Linux, `bash tool/run.sh linux`. Le lanceur fournit le fichier avec `--dart-define-from-file`. La clé `publishable` est destinée aux clients; ne mets jamais une clé `service_role` dans Flutter ni dans Git. Sans configuration Supabase, l’application démarre en mode démonstration SQLite.

Pour les inscriptions web locales, `bash tool/run.sh chrome` utilise `http://localhost:46813`. Dans Supabase, ajoute `http://localhost:46813/auth/callback` à Authentication > URL Configuration > Redirect URLs. Les liens expirés affichent une page de récupération et l’écran d’inscription permet de renvoyer le mail. En production, ajoute le domaine de l’app et son chemin `/auth/callback` à la liste d’URL autorisées.

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
