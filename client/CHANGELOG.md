# Client PC : notes de version

Notes du client PC (WarbandKeeper-Client.exe), à part de celles de l'addon. Lues par le client
(Nouveautés > Client) et jointes à chaque Release. Monter `CLIENT_VERSION` dans `wk_client.py` en même temps.

## 1.6.0 — 19/11/2026

### Changements
- Plus de barre de titre blanche de Windows : les boutons réduire, agrandir et fermer sont posés en haut à droite, sur le fond sombre du client. On déplace la fenêtre en la tenant par le haut ou par la colonne de gauche ; double-clic en haut pour l'agrandir ; poignée en bas à droite pour la redimensionner. Le client garde son bouton dans la barre des tâches.

## 1.5.2 — 19/11/2026

### Corrections
- Les messages en bas de la fenêtre (par exemple l'erreur de droits du jeton GitHub) étaient coupés de chaque côté : ils passent maintenant à la ligne et restent affichés plus longtemps quand ils sont longs.

## 1.5.1 — 19/11/2026

### Corrections
- Accueil : la liste de tes persos était fausse (noms comme « Précision », aucun niveau, aucun or) : le client lisait une autre table « characters » des réglages (celle d'un profil). Il lit maintenant la bonne.

## 1.5.0 — 19/11/2026

### Ajouts
- Accueil : sous le bandeau, la liste de tes persos (classe en couleur, niveau, or, dernière connexion) et l'or total, lus dans les réglages de l'addon, sans ouvrir le jeu.
- Accueil : à droite, la dernière sauvegarde de tes réglages (avec « Sauvegarder maintenant »), l'heure de la prochaine vérification, et les boutons « Lancer WoW Forever » et « Dossier AddOns ».

### Corrections
- Le bouton « Vérifier maintenant » affichait un carré devant son texte : le symbole est retiré.

## 1.4.5 — 19/11/2026

### Modifications
- Fenêtre du client plus petite à l'ouverture (780 × 480 au lieu de 940 × 640) ; elle peut être réduite jusqu'à 680 × 420.

## 1.4.4 — 19/11/2026

### Modifications
- Accueil : le gros bouton est vert (« À jour ») quand l'addon est à jour, rouge (« Mettre à jour ») quand une nouvelle version est disponible.
- Le bouton « Vérifier maintenant » est plus visible.
- Les nouveautés ne sont plus affichées sur l'accueil : elles restent dans la page Nouveautés.

## 1.4.3 — 17/11/2026

### Corrections
- Quand une nouvelle version de l'addon sortait, la mise à jour du client disparaissait pendant quelques minutes (le temps que GitHub construise le client pour la nouvelle version) : le client ne regardait que la toute dernière version publiée. Il cherche maintenant le client le plus récent dans toutes les versions publiées, et ses notes aussi.

## 1.4.2 — 17/11/2026

### Ajouts
- À chaque vérification, le client indique à l'addon la dernière version publiée : en jeu, l'en-tête de Warband Keeper affiche « Mise à jour x.y.z » quand ta version est dépassée (visible au lancement du jeu ou après un /reload). Nécessite l'addon 0.98.0 ou plus.

## 1.4.1 — 17/11/2026

### Corrections
- Après la mise à jour du client par lui-même, le nouveau client ne démarrait pas (« Failed to load Python DLL … python312.dll ») : il cherchait ses fichiers dans le dossier temporaire de l'ancien. Il démarre maintenant normalement. (Pour passer de la 1.4.0 à la 1.4.1, l'erreur peut encore apparaître une dernière fois : relance alors le client à la main.)

## 1.4.0 — 17/11/2026

### Ajouts
- Le client te prévient quand une nouvelle version de l'addon sort : son bouton clignote dans la barre des tâches, le titre de la fenêtre l'indique et un message s'affiche (une fois par version).
- Option « Lancer le client avec Windows, réduit » (Réglages > Mises à jour) : il vérifie en arrière-plan sans que tu y penses.

### Modifications
- La vérification se fait désormais toutes les heures par défaut (réglage passé de « Au démarrage » à « Toutes les heures » ; tu peux le changer dans Réglages > Mises à jour).

## 1.3.1 — 17/11/2026

### Corrections
- Le dossier de la bêta de WoW Forever (`_forever_beta_`) était présenté comme WoW Forever : il est maintenant nommé « WoW Forever (bêta) », et l'installation normale passe avant lui (choisie d'office si c'est la seule).

## 1.3.0 — 17/11/2026

### Ajouts
- Nouveautés en deux volets : « Addon » et « Client », chacun avec ses propres notes de version.
- Réglages > Mises à jour : chercher les nouvelles versions au démarrage, toutes les heures ou toutes les 6 heures pendant que le client est ouvert, ou seulement à la demande ; installer automatiquement les mises à jour de l'addon.
- Réglages > Données : fréquence de la mise à jour des données sur GitHub (quotidienne, hebdomadaire, manuelle), publication automatique ou non, et bouton « Lancer maintenant ». Il faut un jeton qui a aussi le droit d'écrire (voir le mode d'emploi).
- Le bandeau « Client disponible » montre ce qui change dans la nouvelle version du client.

## 1.2.0 — 17/11/2026

### Ajouts
- Après une mise à jour, le client dit s'il faut redémarrer complètement le jeu ou si un /reload suffit, calculé sur ce qui a vraiment changé (nouveaux fichiers ou .toc modifié), même si tu sautes plusieurs versions.

### Modifications
- Warband Keeper est fait pour WoW Forever seulement : le client ne propose plus que ses installations, et demande confirmation pour un autre dossier.

## 1.1.0 — 17/11/2026

### Ajouts
- Installation de l'addon la première fois : le client trouve WoW tout seul (registre de Windows, réglages de Battle.net, tous les disques) et reconnaît WoW Forever ; s'il y a plusieurs installations, l'Accueil les liste avec « Installer ici ».

### Modifications
- Nouvelles couleurs : bleu électrique (logo compris).

## 1.0.0 — 17/11/2026

### Ajouts
- Premier client PC : version installée et dernière version, mise à jour en un clic avec les nouveautés, sauvegarde des réglages de l'addon avant chaque mise à jour (restaurables), version précédente gardée pour y revenir, mise à jour du client lui-même.
