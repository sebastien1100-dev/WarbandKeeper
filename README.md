# Warband Keeper

Addon World of Warcraft (WoW Forever)

Pour gérer l'ensemble de son compte :

- **Or** de chaque personnage et total du compte
- **Sacs et banques** de tous les personnages (avec quantités dans l'info-bulle des objets)
- **Métiers** et niveaux de compétence
- **Temps de jeu** par personnage et total
- **Statistiques** : évolution de l'or et des matériaux suivis dans le temps
- **Envoi automatique du farm** : à l'ouverture de la boîte aux lettres, les objets assignés sont envoyés au bon personnage

## Installation

Copier le dossier `WarbandKeeper` dans :

```
World of Warcraft/_<version>_/Interface/AddOns/
```

Puis se connecter avec **chaque personnage** au moins une fois (et ouvrir sa banque) pour qu'il soit enregistré.

> Après une mise à jour qui ajoute des fichiers (textures, nouveaux .lua), **redémarre complètement le jeu** : un simple `/reload` ne charge pas les nouveaux fichiers.

## Interface

Ouvre la fenêtre avec `/wk` ou le **bouton minimap** (clic gauche : ouvrir, clic droit : options, glisser : déplacer). Les pages sont rangées dans une barre latérale (repliable en icônes), et la fenêtre se redimensionne avec la poignée en bas à droite.

| Page | Contenu |
|---|---|
| Résumé | Or du compte, évolution sur 7 j à 1 an (courbe), chiffres clés, tableau des persos avec tendance sur 7 jours |
| Persos | Niveau, or, temps de jeu, dernière visite à la banque, courrier en attente, dernière connexion |
| Inventaire | Recherche dans les sacs, banques et boîtes aux lettres, filtre Tout / Sacs / Banque / Courrier |
| Métiers | Niveaux par perso, recettes connues avec rentabilité (coût, vente, bénéfice), liste de courses avec export vers Auctionator |
| Stats | Courbes de l'or, de la richesse totale (or + stocks) ou d'un matériau, objectifs avec date estimée |
| Farm | Session de farm : chrono, or ramassé, butin, or par heure, historique, classement des meilleurs spots, mini-fenêtre |
| Loot | Profils de filtres de ramassage par situation (qualité, valeur, catégories, listes, activation automatique) |
| Journal | Courriers envoyés, dépôts, or gagné ou dépensé, sessions de farm, progrès de métier, niveaux |
| Courrier et banque | Envoi automatique et dépôt en banque par objet ou par catégorie, avec seuil « garder » ; « Tout prendre » dans la boîte aux lettres |
| Options | 8 thèmes dont un personnalisable, appliqués en direct, couleur d'accent (dont couleur de classe), police, arrondi, opacité, échelle, langue (FR / EN), bouton minimap, alertes |

## Commandes

| Commande | Effet |
|---|---|
| `/wk` | Ouvre / ferme la fenêtre |
| `/wk aide` | Aide des commandes |
| `/wk options` | Ouvre les options |
| `/wk notes` | Notes de patch |
| `/wk farm` | Démarre / termine une session de farm |
| `/wk prendre` | Prend tout le courrier (boîte aux lettres ouverte) |
| `/wk or` | Or de tous les personnages |
| `/wk persos` | Niveau, classe, temps de jeu |
| `/wk cherche <nom>` | Où se trouve un objet (sacs / banque) |
| `/wk metiers` | Métiers de tous les personnages |
| `/wk stats [jours]` | Évolution de l'or du compte (7 jours par défaut) |
| `/wk envoi ajoute <itemID\|lien> <Perso>` | Assigne un objet à un personnage |
| `/wk envoi retire <itemID\|lien>` | Retire la règle |
| `/wk envoi liste` | Liste des règles |
| `/wk envoi on\|off` | Active / désactive l'envoi automatique |

Astuce : pour `ajoute`, tape `/wk envoi ajoute ` puis fais **Maj + clic** sur l'objet dans ton sac pour insérer son lien.

## Notes de patch

Toutes les modifications sont listées dans [CHANGELOG.md](CHANGELOG.md), et en jeu avec `/wk notes` ou l'icône parchemin de la barre du haut.

## Structure

```
WarbandKeeper.toc
Locales/frFR.lua        Chaînes de texte
Core/Init.lua           Événements et modules
Core/Utils.lua          Formatage, compatibilité API conteneurs
Core/Database.lua       SavedVariables (WarbandKeeperDB)
Core/Commands.lua       Commandes /wk
Modules/Characters.lua  Or, niveau, temps de jeu
Modules/Inventory.lua   Sacs, banque, info-bulles, recherche
Modules/Professions.lua Métiers
Modules/Statistics.lua  Historique or / matériaux
Modules/Mail.lua        Envoi automatique
UI/Theme.lua            Couleurs, formes arrondies, helpers
UI/Widgets.lua          Boutons, interrupteurs, champs, listes, curseurs
UI/MainFrame.lua        Fenêtre principale, barre du haut et navigation
UI/Pages/*.lua          Une page par onglet
UI/MinimapButton.lua    Bouton minimap
Media/*.tga             Textures (cercle pour les arrondis, icônes)
tools/gen_media.py      Régénère les textures (python3 + Pillow)
```

## Feuille de route

Voir la section « À venir » de [CHANGELOG.md](CHANGELOG.md).

## Licence

© 2026 sebastien1100-dev, **tous droits réservés**. Usage personnel libre ; republication, version
modifiée publiée ou reprise du nom « Warband Keeper » interdites sans accord écrit (voir
[LICENSE](LICENSE)). Les données et bibliothèques de tiers (QuestieDB, Everloot, opendata,
What's Training, Libs…) restent sous leur propre licence : voir
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
