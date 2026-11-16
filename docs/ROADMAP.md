# Feuille de route IA GAME

## Objectif

Construire une simulation industrielle 3D jouable sous Godot 4, reliée à un moteur de Machine Learning Python. Le jeu doit servir de démonstrateur reproductible : mesures de capteurs, détection de défauts, maintenance, production, rapports et preuves de test.

Le projet est un simulateur pédagogique. Il ne doit pas être présenté comme un jumeau numérique certifié ni comme une simulation physique industrielle validée sans données, équations et essais de référence.

## État actuel

- [x] Projet Godot 4 avec scène d'usine, déplacement et interaction.
- [x] Quatre équipements de démonstration : presse, pompe, compresseur et convoyeur.
- [x] États de fonctionnement, arrêt, panne et maintenance.
- [x] Mesures de température, vibration et pression qui évoluent avec l'état de la machine.
- [x] Panne de démonstration et remise en service par maintenance.
- [x] Transmission des trois mesures au service Python pour diagnostic ML.
- [x] Renderer Compatibility (OpenGL) et configuration initiale adaptée aux GPU anciens.
- [ ] Profil graphique basse consommation validé visuellement sur Intel HD Graphics 4000.
- [x] Validation headless Godot 4.4.1 et tests automatisés de la logique de simulation sur la branche de travail.
- [x] Tests Python et contrôle Ruff dans GitHub Actions.

Les mesures actuelles sont synthétiques. Les personnages et machines visibles sont encore des modèles procéduraux simplifiés. La validation headless ne remplace pas un essai graphique sur le PC cible. Le profil matériel de référence est documenté dans `docs/HARDWARE_PROFILE.md`.

## Phase 1 — Réalisme visuel

Priorité suivante : remplacer progressivement les primitives par des modèles 3D adaptés au jeu.

1. Importer les équipements au format GLB/glTF, avec matériaux PBR.
2. Remplacer le sol, les murs et la toiture par des matériaux béton, métal peint, verre et caoutchouc avec cartes albedo, normal et roughness.
3. Ajouter des détails d'usine : câblage, tuyauteries, vannes, armoires électriques, panneaux de sécurité, éclairage de travail et zones de circulation.
4. Remplacer les personnages stylisés par des humains riggés, avec animations de marche, inspection et maintenance.
5. Configurer collisions, échelle réelle, pivots d'animation et niveaux de détail pour préserver les performances.

Critères de validation : matériaux correctement importés, échelle cohérente, animations fluides, collisions utilisables, licence de chaque ressource enregistrée, performances mesurées sur le PC cible.

## Phase 2 — Simulation industrielle approfondie

1. Définir les paramètres de chaque équipement : régime nominal, charge, vitesse, température, vibration, pression et cadence.
2. Décrire les transitions d'état et les sécurités : marche, arrêt, défaut, maintenance et redémarrage.
3. Relier les mesures aux événements simulés : surcharge, échauffement, désalignement, défaut de pression et usure.
4. Ajouter un journal horodaté des événements et un scénario de jury reproductible.
5. Tester les seuils, les transitions, les interverrouillages et la remise en service.

Les équations et seuils devront être documentés et confrontés à un jeu de données industriel de référence avant toute revendication de fidélité physique.

## Phase 3 — Machine Learning réel

1. Importer un dataset industriel documenté et conserver sa provenance.
2. Vérifier les unités, valeurs manquantes, doublons, valeurs aberrantes et fuites de données.
3. Séparer les données d'entraînement et de test avant toute sélection de modèle.
4. Entraîner, évaluer et comparer plusieurs modèles.
5. Produire un rapport par entraînement : paramètres, version des données, métriques, durée, mémoire et matériel.
6. Relier chaque prédiction au contexte de la machine et à l'événement simulé.

Le dataset synthétique actuel sert seulement à tester le circuit logiciel ; il ne prouve pas la qualité industrielle du modèle.

## Phase 4 — Présentation et livraison

- Interface de supervision lisible : état des machines, capteurs, alertes, production et historique.
- Mode hors ligne après installation des dépendances et du modèle.
- [x] HUD de mesure en jeu : FPS, mémoire statique Godot et durée.
- [x] Enregistrement CSV horodaté par seconde des mesures et des capteurs sélectionnés (touche F6).
- [ ] Mesure CPU et RAM totale du processus via les outils système sur le PC cible.
- [ ] Mesures de latence du diagnostic ML.
- Scénarios de démonstration reproductibles avec historique des essais.
- Export d'un rapport et conservation des preuves de test.
- Validation sur la machine de présentation, pas uniquement dans GitHub Actions.

## Règles de qualité

- Ne pas fusionner dans `main` sans validation explicite.
- Ne pas annoncer une fonction comme terminée sans test.
- Distinguer clairement données synthétiques et données industrielles.
- Enregistrer les licences et les sources de tous les assets.
- Ne jamais inclure de jetons, mots de passe ou données industrielles confidentielles dans Git.
