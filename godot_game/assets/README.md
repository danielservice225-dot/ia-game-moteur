# Ressources 3D — règles d'import

## Organisation

- `models/machines/` : presses, pompes, compresseurs, convoyeurs.
- `models/environment/` : bâtiment, rayonnages, palettes, tuyauteries.
- `models/characters/` : opérateurs et techniciens riggés.
- `textures/` : textures PBR béton, métal, caoutchouc et peinture.
- `licenses/` : fichiers de licence et provenance des ressources.

## Format et intégration

Privilégier GLB/glTF pour Godot 4. Garder les textures PBR nécessaires (base color/albedo, normal, roughness, metallic et ambient occlusion lorsque disponibles). Vérifier l'échelle en mètres, l'orientation, le pivot, les collisions et les animations dans Godot avant de remplacer les modèles procéduraux.

Chaque ressource ajoutée au dépôt doit avoir une fiche indiquant : nom, URL source, auteur, licence, date de vérification, modifications éventuelles et fichiers intégrés.

## Sources candidates à examiner

- Presse hydraulique CC0, GLB avec textures PBR 2K : https://grab3d.com/models/tools/hydraulic-press/
- Machine CNC CC0, GLB avec textures PBR 2K : https://grab3d.com/models/tools/cnc-machine/
- Ventilateur industriel CC0, GLB : https://grab3d.com/models/electronics/industrial-fan/
- Textures béton PBR : https://polyhaven.com/a/concrete
- Grande installation industrielle fictive CC0 (modèle détaillé, à optimiser avant usage temps réel) : https://github.com/StefanJohnsen/FalconGasProcessingPlant

Ces sources sont des pistes, pas des ressources déjà intégrées. Les modèles Grab3D cités sont annoncés comme stylisés et game-ready ; ils constituent des éléments de départ, pas une garantie de photoréalisme. Contrôler les licences et les fichiers téléchargés avant leur inclusion définitive.
