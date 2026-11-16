# IA GAME — Architecture cible V2

## Décision produit

IA GAME devient une application de supervision industrielle interactive. Le déplacement à la première personne n'est plus le parcours principal. L'utilisateur doit pouvoir sélectionner une machine directement, comprendre son état et lancer une action depuis une interface visuelle.

## Application 1 — Simulation Godot

### Interaction attendue

- Caméra fixe de supervision, avec possibilité de recentrer la vue sur une machine.
- Sélection des équipements par clic dans la scène 3D ou par carte/icône.
- Aucun déplacement clavier obligatoire.
- Panneau de détail pour l'équipement sélectionné : code, état, capteurs, diagnostic, risque, dernière intervention.
- Actions explicites : diagnostiquer, injecter une panne de scénario, arrêter, redémarrer et effectuer une maintenance.
- Indicateurs visuels cohérents : fonctionnement, avertissement, panne, maintenance et indisponibilité IA.
- Les raccourcis clavier deviennent facultatifs et ne doivent pas être nécessaires au parcours normal.
- L'interface doit conserver une zone 3D lisible, une barre d'état et un panneau latéral compact.

### Règles de simulation

- Les pannes injectées sont des scénarios de simulation identifiés, pas des événements industriels réels.
- Une action de maintenance doit modifier l'état simulé et être historisée.
- Une prédiction IA ne doit jamais être confondue avec une panne observée.
- Les valeurs de capteurs synthétiques doivent être marquées comme simulées.
- Une panne doit être traçable : équipement, scénario, horodatage, capteurs avant/après, résultat de prédiction et action opérateur.

## Application 2 — IA GAME AI Lab

L'application `ai_lab/` est indépendante du processus Godot. Elle utilise le SDK DataRobot pour importer les datasets, créer/réutiliser un Use Case, entraîner avec AutoML, comparer les modèles et exporter un manifeste.

Aucun modèle scikit-learn local ne doit être présenté comme un modèle DataRobot. Aucun jeton DataRobot ne doit être inclus dans Git, les exports ou les journaux.

## Contrat entre DataRobot et le jeu

Le modèle sélectionné doit être déployé dans DataRobot avant d'être utilisé par la simulation. Le manifeste doit au minimum identifier :

- fournisseur DataRobot ;
- Use Case, dataset et projet ;
- modèle retenu et cible ;
- version du contrat ;
- Deployment ID ;
- noms, types et unités des variables d'entrée ;
- métrique et score de validation ;
- date d'entraînement et version du modèle.

Le jeu ne doit appeler que le déploiement déclaré et validé. Si le déploiement, le réseau ou le schéma est indisponible, l'interface doit afficher « IA indisponible » et ne pas inventer de résultat.

## Exigences de validation compétition

1. Importer un dataset industriel documenté et conserver sa provenance.
2. Séparer strictement les données d'entraînement et de test ; éviter les fuites de cible.
3. Comparer plusieurs modèles avec des métriques adaptées au déséquilibre des pannes.
4. Justifier le choix du modèle et conserver le rapport DataRobot.
5. Vérifier la compatibilité des variables d'entrée avec les capteurs réellement simulés.
6. Prouver le parcours DataRobot → service de prédiction → Godot avec un test automatisé.
7. Mesurer sur la machine cible les FPS, le temps de réponse, le CPU et la mémoire.
8. Conserver l'historique des scénarios, des prédictions et des rapports.
9. Vérifier le mode hors ligne uniquement si une méthode d'export/inférence locale autorisée et reproductible est définie ; sinon annoncer clairement la dépendance réseau DataRobot.
10. Ne déclarer aucune fonctionnalité terminée sans preuve de test.

## État de réalisation

Cette architecture est la cible approuvée du projet. L'application AI Lab est amorcée, mais son exécution dépend des identifiants DataRobot. Le nouveau parcours de supervision Godot et le connecteur de prédiction DataRobot restent à implémenter et tester.
