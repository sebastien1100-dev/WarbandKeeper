# Client PC : notes de version

Notes du client PC (WarbandKeeper-Client.exe), à part de celles de l'addon. Lues par le client
(Nouveautés > Client) et jointes à chaque Release. Monter `CLIENT_VERSION` dans `wk_client.py` en même temps.

## 1.9.12 — 24/11/2026

### Changements
- Découvertes : plus de clic à faire. Ce que l'addon a appris est envoyé tout seul sur GitHub quand tu quittes le jeu (ou après un /reload), directement dans l'addon, sans demande de fusion à valider. Il arrive chez tout le monde à la version suivante. Le bouton « Envoi auto » le coupe ; « Envoyer » le fait tout de suite. Le jeton n'a besoin que de « Contents : Read and write ».

## 1.9.11 — 24/11/2026

### Nouveautés
- Nouvelle page « Découvertes » : ce que l'addon a appris en jeu (quêtes de WoW Forever, boss, durées et tracés des vols, tram, chemins, feu de camp, prix des maîtres et des marchands, points de récolte) est comparé à ce que l'addon contient déjà. Ce qui est nouveau peut être envoyé en demande de fusion sur GitHub (jeton avec « Contents : Read and write » et « Pull requests : Read and write »). Une fois fusionné, chaque installation neuve le reçoit d'office.
- Plusieurs joueurs : « Exporter mes découvertes » crée un fichier .wkd, sans rien de personnel (ni persos, ni or, ni sacs). Le mainteneur l'importe avec « Importer un fichier… ». Il faut deux joueurs d'accord pour une quête, une chaîne ou un boss. Deux valeurs différentes passent « à vérifier » : un clic sur la ligne pour choisir.

## 1.9.10 — 21/11/2026

### Corrections
- Une connexion coupée pendant un téléchargement ne peut plus abîmer le client ni l'addon : le fichier incomplet est refusé et effacé, un message propose de réessayer.
- Le client ne se fige plus quelques secondes à l'ouverture ou après une déconnexion du jeu : la sauvegarde de l'addon est lue en arrière-plan.
- Une sauvegarde de tes réglages interrompue (disque plein, fichier bloqué) ne laisse plus de fichier incomplet dans la liste et ne fait plus effacer une bonne sauvegarde.

## 1.9.9 — 21/11/2026

### Corrections
- Restauration d'une sauvegarde de réglages : si un fichier est bloqué (jeu ou autre programme) pendant le remplacement, ceux déjà remplacés sont remis comme avant. Tes réglages ne restent plus à moitié restaurés, et le message « rien n'a été changé » dit vrai.
- « Sauvegarder maintenant » : une erreur (disque plein, fichier bloqué) affiche maintenant un message au lieu de ne rien faire.

## 1.9.8 — 21/11/2026

### Corrections
- Copie de secours de la version précédente : faite à part puis mise en place d'un coup ; une copie interrompue n'est plus prise pour une version valable.
- « Revenir à la version précédente » attend la fin d'une installation en cours et tourne en arrière-plan (la fenêtre ne se fige plus).
- Retour en arrière : un fichier bloqué par le jeu ne laisse plus l'addon à moitié remis ; la version en place reprend sa place.
- Un dossier laissé à côté par une installation interrompue est remis en place au lancement suivant.
- Une version précédente incomplète (sans son .toc) n'est plus proposée ni installée.
- Nom de la sauvegarde sûr même avec une version au nom inhabituel.

## 1.9.7 — 21/11/2026

### Corrections
- Installation et retour à la version précédente : la version en place est d'abord renommée à côté, sur le même disque (immédiat, sans risque d'arrêt au milieu) ; si quelque chose échoue, tout reprend sa place. La copie de secours vers le dossier du client n'est faite qu'après la réussite.
- « Réparer » ne garde plus la copie abîmée comme version précédente (elle chassait une vraie ancienne version).
- Après « Revenir à la version précédente », l'installation automatique ne remet plus la version que tu viens de quitter ; elle reprend avec une version plus récente, ou à ta prochaine installation à la main.
- Restauration des réglages : tout est lu avant de remplacer quoi que ce soit ; une sauvegarde abîmée ou un fichier bloqué affiche un message et ne laisse plus des réglages mélangés.
- Un .toc sans numéro de version ne fait plus échouer la mise à jour (nom de dossier « ? » interdit sous Windows).

## 1.9.6 — 21/11/2026

### Corrections
- Sauvegardes des réglages : les réglages de chaque perso (positions des éléments à l'écran, recherche de groupe, tenue de pêche…) sont aussi sauvegardés et restaurés, plus seulement ceux du compte.
- « Réparer » ne s'affiche plus quand la version installée est plus récente que la dernière publiée (il aurait installé une version plus ancienne).
- Réglages du client écrits sans risque : un arrêt brutal pendant l'écriture ne fait plus perdre le jeton et le dossier ; un fichier de réglages abîmé ne bloque plus le démarrage.

## 1.9.5 — 21/11/2026

### Corrections
- Installation d'une mise à jour : si elle échoue au milieu (fichier bloqué par le jeu, disque plein, dossier du client sur un autre disque), tout est remis comme avant, au lieu de laisser l'addon à moitié effacé ou sans son dossier de données.
- Les anciennes versions gardées ne sont élaguées qu'après une installation réussie, et jamais celle qu'on vient de remplacer : « Revenir à la version précédente » la retrouve toujours.

## 1.9.4 — 21/11/2026

### Corrections
- Les anciennes versions gardées (2 au plus) sont aussi élaguées quand le dossier WarbandKeeper_Data manquait ; avant, elles s'accumulaient.
- Un changement du fichier .toc du dossier de données (fichier retiré ou renommé) demande bien de redémarrer le jeu, au lieu de dire qu'un /reload suffit.

## 1.9.3 — 21/11/2026

### Corrections
- « Remettre la version précédente » : si le retour en arrière échoue au milieu (fichier bloqué par le jeu, disque plein…), tout est remis comme avant, au lieu de laisser l'addon à moitié restauré ou absent. Une ancienne sauvegarde du même nom n'est plus effacée avant d'être sûr que le retour a marché.

## 1.9.2 — 21/11/2026

### Corrections
- Addon installé par un ancien client (1.9.0 ou avant) sans le dossier WarbandKeeper_Data : le client le voit et propose « Réparer » (réinstalle la même version avec ses deux dossiers), au lieu d'afficher « À jour ».

## 1.9.1 — 21/11/2026

### Modifications
- L'addon arrive maintenant en deux dossiers : WarbandKeeper et WarbandKeeper_Data (grosses bases chargées à la demande). Le client installe les deux ensemble, les range avec la sauvegarde de la version d'avant, les remet en cas de retour arrière, et demande un redémarrage du jeu quand le dossier des données est nouveau.

## 1.9.0 — 21/11/2026

### Ajouts
- Réglages > Données : nouvelle carte « Ajouts récents », les dernières mises à jour de la base de quêtes (QuestieDB et ses corrections WoW Forever) avec leurs étiquettes +N quêtes, N corrigées, N retirées. Un clic sur une ligne montre ses quêtes (niveau, nom).
- Tableau de bord : ligne « Nouvelles données » dans « À surveiller » quand la base a été mise à jour depuis la version installée (avec le total des quêtes ajoutées et corrigées).
- Notification Windows « données mises à jour » quand une nouvelle mise à jour de la base est publiée (Réglages > Notifications, case « Nouvelles données » ; heures calmes respectées).

### Modifications
- « Dernière vérification » des données à l'heure de ton PC (au lieu de l'heure UTC).

## 1.8.8 — 20/11/2026

### Modifications
- Mise à jour de l'addon jeu fermé : plus de consigne « redémarre le jeu » ou « un /reload suffit », inutile puisque la nouvelle version se charge au lancement. La consigne ne s'affiche que si le jeu tourne pendant l'installation (et tant qu'il tourne).

## 1.8.7 — 20/11/2026

### Corrections
- Tableau de bord : la carte affichait encore « Dernière séance » quand la sauvegarde ne contenait pas encore le journal de l'or. Elle montre maintenant toujours « Dernières 24 h » : avec le détail par cause quand le journal est là, sinon l'écart de l'or du compte entre hier et aujourd'hui.

## 1.8.6 — 20/11/2026

### Modifications
- Tableau de bord : « Dernière séance » devient « Dernières 24 h » : l'or gagné ou perdu sur tous tes persos depuis 24 h, et ce qui a le plus pesé (réparations, vols, achats chez le marchand, Hôtel des ventes, quêtes…), d'après le journal de l'or de l'addon 1.83.0. Avec un addon plus ancien, la carte reste « Dernière séance ».

## 1.8.5 — 19/11/2026

### Corrections
- Mises à jour : « Prochaine vérification » restait figée (« dans 60 min ») ; le compte à rebours avance maintenant tout seul, avec l'heure prévue (« dans 42 min (à 18:30) »).

## 1.8.4 — 19/11/2026

### Modifications
- Mises à jour : un seul bouton. « Mettre à jour » quand une nouvelle version attend, « Vérifier maintenant » quand tout est à jour, « Vérification… » pendant la recherche.

## 1.8.3 — 19/11/2026

### Corrections
- La pastille du nombre de mises à jour disparaissait au survol de « Mises à jour » dans la barre latérale ; elle reste maintenant affichée.

## 1.8.2 — 19/11/2026

### Modifications
- Barres de défilement aux couleurs du client (Nouveautés, Sauvegardes…) : rail sombre et curseur fin arrondi, bleu au survol, à la place de la barre blanche de Windows ; cachées quand tout se voit.

## 1.8.1 — 19/11/2026

### Ajouts
- Barre latérale : une pastille rouge sur « Mises à jour » quand une nouvelle version de l'addon est disponible (le nombre de versions à installer), ou « client » quand seul le client a une nouvelle version.

## 1.8.0 — 19/11/2026

### Modifications
- Tableau de bord refait : quatre chiffres clés en haut (or du compte, dernière séance, enchères en vente, courrier à prendre), la courbe de l'or à gauche (7, 30 ou 90 jours, plus haut, ventes HV de la séance, nombre de persos) et « À surveiller » à droite, une seule liste triée par urgence (enchères qui expirent, courrier, Rangement, recharges, repos plein, listes d'achat, file de fabrication).
- Fenêtre fixe de 1000 × 600 (réduite sur un petit écran) : tout se voit sans défiler ; plus de bouton agrandir ni de poignée de redimensionnement.

### Corrections
- « 1 envois » : les pluriels sont justes.
- Listes d'achat : « 6219 manquent / 6251 » comptait des unités ; c'est maintenant le nombre d'objets qui manquent et leur coût estimé à l'HV (addon 1.71 ou plus récent).

## 1.7.5 — 19/11/2026

### Modifications
- Tableau de bord : plus de barre de défilement blanche à droite (la molette fait défiler si besoin). Ailleurs, la barre n'apparaît que quand le contenu dépasse.

## 1.7.4 — 19/11/2026

### Modifications
- Mises à jour : la carte « À installer » est retirée (les notes de version restent dans la page Nouveautés).

## 1.7.3 — 19/11/2026

### Modifications
- Le client s'ouvre plus grand (1100 × 760, réduit sur un petit écran) : le Tableau de bord et les Réglages se voient en entier sans agrandir la fenêtre.

## 1.7.2 — 19/11/2026

### Modifications
- Réglages en onglets, un par catégorie : Dossier, GitHub, Mises à jour, Notifications, Données (le dernier ouvert est retenu). Les notifications Windows y sont rangées : la page « Notifications » de la barre latérale disparaît.
- Les liens vers les réglages ouvrent le bon onglet (prochaine vérification, jeton GitHub, dossier).

## 1.7.1 — 19/11/2026

### Modifications
- « Accueil » devient « Mises à jour » et ne parle plus que de l'addon : la version et le bouton « Mettre à jour » en haut, trois tuiles (dernière sauvegarde, prochaine vérification, dossier de l'addon), puis les nouveautés à installer (ou celles de la dernière version).
- La liste « Tes persos » et le bouton « Lancer WoW Forever » sont retirés (les persos sont dans le Tableau de bord).
- Barre latérale dans l'ordre : Tableau de bord, Mises à jour, Nouveautés, Sauvegardes, Notifications, Réglages.

## 1.7.0 — 19/11/2026

### Ajouts
- Tableau de bord (nouvelle page, ouverte au démarrage) : or du compte avec sa courbe sur 30 jours, dernière séance (gain, ventes HV), enchères en vente et celles qui expirent, recharges de métier, listes d'achat et file de fabrication, Rangement et courrier non pris. Tiré du résumé que l'addon (1.69 ou plus récent) écrit à chaque déconnexion ou /reload : rien n'est demandé au jeu.
- Notifications Windows (nouvelle page) : enchères qui expirent dans les 24 h, recharges de métier prêtes, repos plein, courrier bientôt renvoyé ; chacune une seule fois, heures calmes de 23 h à 8 h, bouton « Tester une notification ». Le client doit tourner (réduit ou lancé avec Windows).

## 1.6.4 — 19/11/2026

### Corrections
- Mise à jour du client : sur un compte Windows au nom accentué (ou un exe rangé sans droit d'écriture), le remplacement de l'exe pouvait tourner en boucle sans fin et le client ne redémarrait jamais. Le chemin est maintenant lu correctement, et après une minute d'essais l'ancien client est relancé.
- Une erreur pendant une tâche de fond (vérification, téléchargement) pouvait bloquer toutes les suivantes jusqu'à la fermeture du client.
- Installation interrompue (disque plein, fichier verrouillé par l'antivirus) : l'addon restait à moitié installé alors que le message disait « rien n'a été changé ». L'ancienne version est maintenant remise.

## 1.6.3 — 19/11/2026

### Corrections
- Accueil : de faux persos pouvaient apparaître (nom coupé, niveau « ? », 0 pa, « jamais »), surtout après une mise à jour de l'addon. Les listes imbriquées des réglages (sacs, journaux…) étaient mal lues ; elles le sont maintenant, et seules les vraies fiches de perso sont gardées.
- Accueil : la colonne des noms ne se fait plus écraser quand la fenêtre est étroite (titre « PERSO » coupé).

## 1.6.2 — 19/11/2026

### Changements
- Accueil : la liste de tes persos est un vrai tableau aligné (nom, niveau, or, dernière connexion en colonnes, avec leurs titres). Avant, niveau et or se décalaient selon la longueur du nom.

## 1.6.1 — 19/11/2026

### Corrections
- Accueil : le bouton « Dossier AddOns » était coupé en bas de la fenêtre. Sauvegarde et prochaine vérification sont réunies dans une seule carte, et les marges du haut sont réduites : tout tient dans la fenêtre sans l'agrandir.

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
