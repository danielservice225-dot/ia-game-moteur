# Profil matériel cible — IA GAME

## Machine de référence

- Ordinateur : HP EliteBook 8570p
- GPU : Intel HD Graphics 4000 intégrée
- Mémoire vive : 16 Go
- Processeur : Intel Core i7 de 3e génération (modèle exact à confirmer)
- Moteur : Godot 4
- Renderer : Compatibility (OpenGL)

## Réglages de départ

- Fenêtre de référence : 1280 × 720.
- MSAA 3D : 2×.
- Occlusion ambiante écran (SSAO) : désactivée.
- Glow : désactivé.
- Ombres dynamiques de la lumière directionnelle : désactivées.
- Modèles, textures et éclairages à optimiser avant d'augmenter les détails.

Ces réglages sont un profil prudent de départ, pas une mesure de performance garantie. La compatibilité du projet en mode headless ne prouve pas que le rendu graphique est fluide sur le portable.

## Protocole de validation sur le PC

1. Ouvrir le projet avec une version stable de Godot 4 prenant en charge le renderer Compatibility.
2. Lancer la scène principale pendant au moins cinq minutes.
3. Parcourir l'usine et approcher successivement les quatre équipements.
4. Déclencher une panne, effectuer la maintenance et vérifier l'affichage des capteurs.
5. Relever les FPS, la mémoire utilisée et les éventuels défauts graphiques.
6. Répéter avec une scène chargée et une scène au repos.
7. N'activer les effets graphiques qu'un par un, en conservant les mesures avant/après.

## Critères d'acceptation

- Aucun plantage pendant l'essai.
- Déplacement et interactions utilisables.
- Les quatre machines restent visibles et interactives.
- Les mesures et alertes restent lisibles.
- Objectif de travail : viser 30 FPS, sans présenter cet objectif comme atteint avant mesure.

## Limites connues

- Les performances dépendent aussi du CPU, du pilote graphique, de la résolution et de la température du portable.
- Les 16 Go de RAM ne compensent pas les limites du GPU intégré.
- Les assets 3D détaillés devront être testés individuellement et disposer d'une version allégée si nécessaire.
