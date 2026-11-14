# Notes de patch

Toutes les modifications de Warband Keeper, version par version.
Ce fichier est généré à partir de `Core/Changelog.lua` (les mêmes notes sont visibles en jeu : `/wk notes`).

## v0.3.1 — 14/11/2026

### Ajouts
- Page « Notes de patch » : toutes les versions avec leurs ajouts, modifications et corrections, plus ce qui est prévu.
- Icône « Notes de patch » dans la barre du haut et commande /wk notes.
- Message dans le chat à la première connexion après une mise à jour.
- Fichier CHANGELOG.md sur GitHub, généré à partir des mêmes notes.

## À venir

_Prévu, pas encore commencé._

- Journal d'activité : courriers envoyés, gains et pertes d'or, progrès de métier.
- Suivi des objets en attente dans la boîte aux lettres de chaque personnage.
- Alerte quand la banque d'un personnage n'a pas été scannée depuis longtemps.
- Tendance des matériaux par personnage, en plus du total du compte.
- Version anglaise de l'interface.

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
