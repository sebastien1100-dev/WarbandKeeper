# Client PC : notes de version

Notes du client PC (WarbandKeeper-Client.exe), à part de celles de l'addon. Lues par le client
(Nouveautés > Client) et jointes à chaque Release. Monter `CLIENT_VERSION` dans `wk_client.py` en même temps.

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
