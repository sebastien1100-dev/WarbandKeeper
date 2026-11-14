# Patch notes

Toutes les modifications de Warband Keeper, version par version.
Ce fichier est généré à partir de `Core/Changelog.lua` (les mêmes notes sont visibles en jeu : `/wk notes`).

## À venir

_Prévu, pas encore commencé._

- Guide de montée de chaque métier jusqu'au niveau max, d'après les guides à jour de WoW Forever : étape en cours selon le niveau du perso, matériaux totaux, ce qui manque sur le compte et son coût, liste Auctionator et envoi des matériaux au perso.
- Guide des métiers de récolte (Minage, Herboristerie, Dépeçage) : zones à farmer par tranche de niveau, en lien avec la Session de farm.
- Conseil de métier : la recette orange ou jaune la moins chère parmi celles que le perso connaît.
- Rappel du maître de métier quand un perso arrive au plafond de son rang (75, 150, 225).
- Recherche « Qui peut fabriquer… ? » sur tous les persos.
- Options par classe : par exemple, pour les chasseurs, le suivi des flèches et balles avec une alerte quand il en reste peu.

## v0.10.1 — 14/11/2026

### Ajouts
- Métiers > Niveaux : le nombre de recettes connues est affiché à côté de chaque métier, par exemple « Cuisine (4 recettes) ».
- Options > Général > Combat : « Fermer la fenêtre en combat ». La fenêtre se ferme au début d'un combat ; la mini-fenêtre de la session de farm reste affichée.

### Corrections
- Le bouton « Ouvrir le métier » pouvait empêcher de fermer la fenêtre pendant un combat.
- Options : certaines descriptions étaient coupées (par exemple « Auto : celle du j... »).

## v0.10.0 — 14/11/2026

### Ajouts
- Métiers : clic sur un métier dans l'onglet Niveaux pour ouvrir sa fiche : niveau, recettes connues du perso avec leur couleur (orange, jaune, vert, gris), composants possédés sur tout le compte, coût et bénéfice.
- Fiche métier : filtres « Font monter » (recettes orange, jaunes et vertes) et « Possibles » (composants déjà sur le compte), recherche, et bouton + vers la liste de courses.
- Fiche métier : bouton « Ouvrir le métier » pour le perso connecté. Pour les autres persos, la date à laquelle leurs recettes ont été lues.

### Modifications
- Les couleurs des recettes sont enregistrées à l'ouverture de chaque métier : ouvre-le une fois sur chaque perso pour les voir.

## v0.9.5 — 14/11/2026

### Modifications
- Le nom complet des persos (« Prénom Nom ») est affiché dans tout l'addon : résumé, persos, inventaire, métiers, stats, farm, journal, alertes, infobulles et messages du chat.
- Persos : clic droit sur un perso pour corriger son nom complet (comme dans Courrier). Un nom trop long est coupé proprement au lieu de déborder sur les colonnes.

## v0.9.4 — 14/11/2026

### Corrections
- La barre de défilement ne réagissait pas à la souris : un clic sur la barre amène la liste à cet endroit, et le curseur se fait glisser.

## v0.9.3 — 14/11/2026

### Ajouts
- Noms en deux parties (« Prénom Nom ») : l'envoi automatique utilise le nom complet de tes persos.
- Clic droit sur un perso dans Courrier > Nouvelle règle pour corriger son nom complet si le jeu ne le donne pas.
- Commande /wk nom : affiche le nom utilisé pour le courrier.

### Modifications
- Une règle écrite avec le prénom seul est envoyée au nom complet du perso du compte, s'il n'y a pas d'ambiguïté.
- En cas d'échec d'un envoi, le chat indique le destinataire utilisé et la raison donnée par le jeu.

### Corrections
- /wk envoi ajoute ne gardait que le dernier mot d'un nom en deux parties.

## v0.9.2 — 14/11/2026

### Ajouts
- Prix : nouvelle source « Les deux ». L'Inventaire affiche le prix HV et le prix marchand côte à côte, et l'infobulle des objets donne les deux prix à l'unité. Les calculs (stocks, richesse, butin, rentabilité, filtre de loot) prennent le meilleur des deux : ce que tu tirerais vraiment de l'objet.

### Modifications
- Options > Prix : la description indique ce que fait la source choisie.

## v0.9.1 — 14/11/2026

### Modifications
- Redimensionnement fluide : les pages suivent la souris en direct pendant qu'on agrandit ou réduit la fenêtre (cartes, colonnes des tableaux, tuiles, catégories du loot), et les graphiques sont redessinés au fur et à mesure. Plus besoin de relâcher la souris.
- Replier ou déplier le menu redimensionne aussi les pages en direct.
- « Notes de patch » devient « Patch notes ».
- Patch notes : la section « À venir » est toujours en haut, au-dessus des versions. Pareil dans CHANGELOG.md sur GitHub.

### Corrections
- Sur une grande fenêtre, la ligne d'objectif des Stats s'arrêtait avant le bord du graphique.

## v0.9.0 — 14/11/2026

### Ajouts
- Filtres de loot : profils de ramassage par situation (Tout ramasser, Farm, Donjon, Raid, Or et quêtes seulement…), à créer, dupliquer, renommer et charger d'un clic. Les objets refusés restent sur le corps.
- Chaque profil fixe une qualité minimale, une valeur minimale (au prix Auctionator ou marchand), des catégories toujours ramassées et des listes « toujours » et « jamais » (Maj + clic). L'or, les monnaies et les objets de quête sont toujours ramassés, tout comme, si tu le souhaites, les objets de tes règles d'envoi et de dépôt.
- Activation automatique d'un profil selon la zone, le type d'instance (donjon, raid, JcJ) ou une session de farm, avec un message dans le chat quand le profil change. Le profil actif apparaît dans la mini-fenêtre de farm.
- Liste des derniers objets laissés au sol : un clic en ajoute un à la liste « toujours ». Maj maintenue en ouvrant un butin désactive le filtre pour ce butin. Un bouton désactive le butin automatique du jeu, qui empêche le filtre de choisir.
- Fenêtre redimensionnable avec la poignée en bas à droite : les pages se redessinent à la nouvelle taille (tableaux, listes et graphiques s'étirent), et la taille est mémorisée.

### Modifications
- Nouvelle disposition : barre latérale groupée (Compte, Économie, Farm, puis Notes de patch et Options), repliable en icônes avec « Réduire le menu ». Le titre de la page et les boutons Scanner et Fermer passent dans l'en-tête du contenu.
- Les colonnes des tableaux du Résumé et des Persos suivent la largeur de la fenêtre.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

## v0.8.2 — 14/11/2026

### Modifications
- Ordre des sections des Options : Général, Prix, Alertes, Thèmes, Apparence, À propos. Général s'ouvre par défaut.

## v0.8.1 — 14/11/2026

### Modifications
- Options rangées en sections verticales à gauche : Thème, Apparence, Général (langue, bouton minimap, position de la fenêtre), Prix, Alertes et À propos. La dernière section ouverte est mémorisée.
- Les vignettes de thèmes passent sur deux rangées pour rester lisibles.
- À propos : bouton pour ouvrir les notes de patch.

## v0.8.0 — 14/11/2026

### Ajouts
- Rentabilité des fabrications : pour chaque recette, coût des composants, prix de vente de l'objet fabriqué et bénéfice, au prix d'Auctionator (sinon prix marchand). Tri des recettes par nom, bénéfice ou nombre de fabrications possibles ; le détail est dans l'infobulle.
- Meilleurs spots de farm : la page Farm classe les zones par or/heure (or ramassé + valeur du butin au prix actuel), avec le nombre de sessions, le temps passé et le meilleur perso. Clique sur un spot pour voir tout le butin récolté dans cette zone.
- Thème personnalisé : un 8e thème dont tu choisis les 7 couleurs (fond, bordures, cadre, halo, textes, accent) avec le sélecteur de couleur du jeu, en partant si tu veux du thème actuel.

### Modifications
- Le thème, la police, l'arrondi, l'opacité et la langue s'appliquent tout de suite, sans recharger l'interface : la fenêtre, le bouton minimap et la mini-fenêtre de farm sont redessinés.
- La carte Historique de la page Farm a deux vues : Sessions et Meilleurs spots.

## v0.7.0 — 14/11/2026

### Ajouts
- Valeur du compte : les stocks (sacs, banques, courrier, bataillon) sont estimés au prix d'Auctionator, ou au prix marchand si Auctionator n'est pas installé ou n'a pas de prix. Le Résumé affiche la valeur des stocks sous l'or du compte.
- Nouvelle série « Richesse totale » (or + stocks) dans les Stats, avec son historique.
- Inventaire : valeur estimée de chaque ligne et du contenu de l'onglet.
- Objectifs : sur l'or, la richesse totale ou un matériau, depuis la page Stats. Ligne pointillée sur le graphique, pourcentage atteint et date estimée au rythme des 7 derniers jours. Les objectifs apparaissent aussi en bandeau sur le Résumé.
- Métiers > Recettes : les recettes connues de chaque perso (enregistrées à l'ouverture de la fenêtre de métier), qui peut les fabriquer et combien de fois avec le stock du compte. L'infobulle détaille les composants possédés.
- Métiers > Liste de courses : fabrications prévues (+ / -), composants nécessaires, possédés et manquants, coût des manquants. Bouton « Créer la liste Auctionator » pour acheter les composants manquants dans Auctionator.
- Options : choix de la source des prix (Auctionator ou marchand).

### Modifications
- La session de farm estime la valeur du butin au prix d'Auctionator quand il est disponible.
- Les en-têtes en majuscules gardent leurs accents (POSSÉDÉ, COÛT…).
- Les flèches du Journal utilisent « » », un symbole que la police du jeu sait afficher.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

## v0.6.1 — 14/11/2026

### Ajouts
- Inventaire : onglets par personnage dans une colonne à gauche (icône et couleur de classe, nombre d'objets), plus « Tout le compte » et « Banque de bataillon ».
- Sur l'onglet d'un personnage, chaque objet indique où il se trouve (sacs, banque, courrier), et l'en-tête résume sacs occupés, dernière visite à la banque et lettres en attente.

### Modifications
- L'Inventaire retient le dernier onglet ouvert. La recherche et les filtres Sacs / Banque / Courrier s'appliquent à l'onglet choisi.

## v0.6.0 — 14/11/2026

### Ajouts
- Thèmes : 7 thèmes au choix dans les Options, avec un aperçu de chacun. Coffre-fort (bois et or), Givre (bleu nuit et cyan), Graphite (gris neutre), Héraldique (aux couleurs de ta classe), Faction (bleu et or pour l'Alliance, rouge et fer pour la Horde), Gangrefeu (vert gangrené) et Néant (violet).
- Couleur d'accent : en plus des couleurs fixes, « Thème » suit l'accent du thème choisi et « Classe » prend la couleur de classe du perso connecté.
- Réglages d'apparence : police (Friz Quadrata ou Arial Narrow), arrondi (fort, moyen ou carré) et opacité du fond de la fenêtre.

### Modifications
- Les Options commencent par la carte Thème. Un bouton « Recharger pour appliquer » apparaît quand un réglage demande de recharger l'interface (thème, police, arrondi, opacité, langue).
- Les thèmes Héraldique et Faction s'adaptent au perso connecté.
- Changer de thème remet l'accent sur celui du thème.
- Nouveau fichier : redémarrer complètement le jeu après la mise à jour.

## v0.5.0 — 14/11/2026

### Ajouts
- Règles par catégorie : étoffes, cuirs, métaux et pierres, herbes, éléments, enchantement, gemmes… Une seule règle suffit pour envoyer tout un type de composant. Une règle sur un objet précis reste prioritaire.
- Seuil « Garder » : une règle peut garder une quantité dans les sacs (ex. garder 20 potions) et n'envoie ou ne dépose que le surplus, en partageant une pile si besoin.
- Page Farm : session de farm avec chrono, pause, or ramassé, nombre d'objets, valeur marchande du butin et or par heure. Le butin est listé avec sa quantité par heure, et chaque session terminée est gardée dans un historique consultable (zone, durée, or/h).
- Mini-fenêtre déplaçable pendant une session : chrono, or par heure, nombre d'objets, boutons pause et fin. Commande /wk farm pour démarrer ou terminer.
- « Tout prendre » : un bouton dans la boîte de réception du jeu récupère l'or et les objets de toutes les lettres, sauf les contre-remboursements, et s'arrête quand les sacs sont pleins. Option pour le faire automatiquement après les envois. Commande /wk prendre.
- Dépôt automatique en banque : à l'ouverture de la banque, les objets ou catégories choisis sont rangés dans la banque du perso ou de bataillon, en complétant les piles existantes.
- Onglet Réception : les boîtes aux lettres de tous les persos (lettres, objets, or, expiration).
- Journal : dépôts en banque et sessions de farm terminées.

### Modifications
- La page Courrier devient « Courrier et banque », avec trois onglets : Envoi, Dépôt banque et Réception.
- Nouvelle règle : choix Objet ou Catégorie dans une liste déroulante, et champ « Garder ».
- Le butin ne compte pas pendant le courrier, la banque, un marchand, un échange ou l'hôtel des ventes.
- Les sommes de moins d'1 po s'affichent en pièces d'argent au lieu de « 0 po ».
- Barre du haut plus compacte pour faire de la place à l'onglet Farm ; la loupe est retirée (la recherche reste dans l'Inventaire).
- Les anciennes règles d'envoi sont converties automatiquement.
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.

### Corrections
- Une session de farm interrompue par un crash ou une déconnexion garde le temps écoulé jusqu'à la dernière activité.

## v0.4.0 — 14/11/2026

### Ajouts
- Page Journal : courriers envoyés, or gagné ou dépensé, progrès de métier et niveaux, regroupés par jour, avec des filtres Tout / Or / Courrier / Métiers. Les variations d'or et les progrès d'un même métier sont regroupés par heure.
- Boîte aux lettres : son contenu est lu à l'ouverture (objets, or, nombre de lettres, date d'expiration). Les objets envoyés par l'envoi automatique à un autre perso du compte sont comptés tout de suite dans sa boîte.
- Les objets du courrier comptent dans les totaux, les infobulles et les stats. Nouveau filtre « Courrier » dans l'Inventaire.
- Alertes : banque d'un perso (niveau 10+) jamais ouverte ou pas vue depuis 7 jours, courrier qui expire dans moins de 3 jours. Rappel dans le chat à la connexion et colonnes en orange. Seuils réglables dans les Options.
- Page Persos : nouvelles colonnes Banque (dernière visite) et Courrier (lettres en attente et jours avant expiration).
- Stats : vue « Par perso » pour les matériaux, avec une courbe par personnage en couleur de classe et une légende.
- Version anglaise de l'interface et des messages du chat. Choix de la langue dans les Options : Auto (celle du jeu), Français ou English.

### Modifications
- Options : la page défile et regroupe Apparence, Langue, Bouton minimap, Alertes et À propos.
- Les commandes du chat existent aussi en anglais (/wk help, gold, chars, find, prof, mail add / del).
- Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour (un /reload ne suffit pas).

## v0.3.1 — 14/11/2026

### Ajouts
- Page « Notes de patch » : toutes les versions avec leurs ajouts, modifications et corrections, plus ce qui est prévu.
- Icône « Notes de patch » dans la barre du haut et commande /wk notes.
- Message dans le chat à la première connexion après une mise à jour.
- Fichier CHANGELOG.md sur GitHub, généré à partir des mêmes notes.

## v0.3.0 — 14/11/2026

### Ajouts
- Page Résumé : or du compte en grand, variation sur 7 jours et 4 chiffres clés (personnages, temps de jeu, règles de courrier, objets à envoyer).
- Courbe d'évolution de l'or sur 7 j, 30 j, 90 j ou 1 an, avec repère au survol (date et montant).
- Tableau des personnages avec le gain ou la perte sur 7 jours et une mini-courbe de tendance.
- Boutons ronds dans la barre du haut : rechercher un objet, scanner le personnage, fermer.

### Modifications
- Nouveau design « Registre » aux couleurs « Coffre-fort » : bois sombre, parchemin et or, double bordure dorée et halo chaud.
- Navigation en pilules dans la barre du haut : la barre latérale disparaît.
- Titre « Warband Keeper » dans la police médiévale du jeu, liserés dorés sur les cartes.
- Page Stats : une courbe remplace les barres, et l'échelle s'adapte aux valeurs pour rendre les variations visibles.
- Couleur d'accent par défaut : or. Nouveau choix : cuivre.

### Corrections
- Les sous-titres des pages s'affichaient au milieu de la page au lieu d'à côté du titre.
- Positionnement corrigé dans l'inventaire, les séries des stats, les tuiles et les descriptions des réglages.
- Le bouton « Recentrer la fenêtre » chevauchait l'interrupteur du bouton minimap dans les Options.

## v0.2.4 — 14/11/2026

### Modifications
- Nouveau logo : l'étendard de bataillon (drapeau avec un W), sur le bouton minimap et dans la fenêtre.

## v0.2.3 — 14/11/2026

### Modifications
- Les quantités par personnage ne s'ajoutent plus aux infobulles de comparaison d'équipement (plus de doublons).
- Noms des personnages en couleur de classe dans l'infobulle des objets, sans le royaume.

### Corrections
- Erreur au survol d'un objet (« attempt to call a nil value » dans Inventory.lua) : l'objet est maintenant identifié avec l'API d'infobulles moderne.

## v0.2.2 — 14/11/2026

### Corrections
- Carte « Ce personnage » : le nom complet Nom-Royaume sortait de la carte. Le nom s'affiche seul et le royaume passe sur sa propre ligne.
- Page Personnages : un royaume au nom long pouvait chevaucher la colonne Niveau.

## v0.2.1 — 14/11/2026

### Ajouts
- Banque de bataillon : lue à l'ouverture de la banque, visible dans l'inventaire (« Bataillon »), les infobulles et les totaux.
- Banque du personnage à onglets prise en charge.
- Le sac de composants est compté avec les sacs.

### Modifications
- Métiers lus avec l'API moderne du jeu.

### Corrections
- Erreur sur la page Inventaire (« attempt to call a nil value » dans Theme.lua) : GetItemInfo n'existe plus sur ce client, remplacé par C_Item.GetItemInfo.
- Insertion des liens d'objets (Maj + clic) compatible avec le nouveau chat.

## v0.2.0 — 14/11/2026

### Ajouts
- Fenêtre principale aux coins arrondis, avec les pages Vue d'ensemble, Personnages, Inventaire, Métiers, Statistiques, Courrier automatique et Options.
- Bouton minimap rond et déplaçable : clic gauche pour ouvrir, clic droit pour les options.
- Ouverture depuis le menu des addons du jeu.
- Couleur d'accent au choix et échelle de la fenêtre réglable.
- Recherche d'objets dans tous les sacs et banques, avec filtre Tout / Sacs / Banque.
- Suivi de n'importe quel matériau dans les statistiques (Maj + clic sur l'objet).
- Ajout des règles de courrier depuis la fenêtre, avec choix rapide du destinataire.

### Modifications
- /wk ouvre la fenêtre. /wk aide affiche les commandes du chat.

### Corrections
- Conflit de nom entre l'interrupteur et l'ouverture de la fenêtre (trouvé avant la publication).

## v0.1.0 — 14/11/2026

### Ajouts
- Enregistrement de chaque personnage : or, niveau, classe, temps de jeu.
- Contenu des sacs et de la banque de tous les personnages, avec les quantités dans l'infobulle des objets.
- Métiers et niveaux de compétence.
- Historique de l'or et des matériaux suivis pour les statistiques.
- Envoi automatique à l'ouverture de la boîte aux lettres : chaque objet assigné part vers son personnage, 12 pièces jointes par courrier.
- Commandes du chat : /wk or, persos, cherche, metiers, stats, envoi.
