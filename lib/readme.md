Garage Finder 🚗🔧
C'est quoi ?

Une petite app Flutter pour trouver des garages (motos, autos, poids lourds) près de chez toi.
Tu peux aussi ajouter ton propre garage.
Ce qu'elle fait

    Accueil : une présentation rapide avec deux gros boutons.

    Liste : tous les garages, avec une barre de recherche (par nom, ville ou spécialité).

    Détail : les infos complètes d'un garage (adresse, téléphone, chef, etc.) + boutons pour appeler ou voir l'itinéraire.

    Ajout : un formulaire pour enregistrer un nouveau garage (avec validation des champs).

    Thème clair/sombre : tu switches en un clic.

Comment lancer le projet
bash

git clone https://github.com/ton-compte/garage_finder.git
cd garage_finder
flutter pub get
flutter run

Structure rapide
text

lib/
├── main.dart          # Point d'entrée
├── app.dart           # Routes GoRouter
├── models/            # Modèle Garage
├── data/              # Données fictives
├── screens/           # Les 4 écrans
├── widgets/           # Widgets réutilisables
├── providers/         # Gestion du thème
└── theme/             # Thèmes personnalisés

Captures d'écran

À ajouter dans un dossier screenshots/ :

    Accueil

    Liste

    Détail

    Formulaire

    Mode sombre

Ce qui est validé (exigences du projet)

    ✅ 4 écrans

    ✅ Navigation GoRouter

    ✅ Liste avec recherche

    ✅ Détail avec paramètre

    ✅ Formulaire avec validation (5 champs)

    ✅ Thème clair/sombre

    ✅ 3 widgets réutilisables

    ✅ Responsive (mobile/tablette)

    ✅ Données séparées de l'UI

Auteur

[Nadège TOVIHOUANDE] – [https://github.com/Chariane/]