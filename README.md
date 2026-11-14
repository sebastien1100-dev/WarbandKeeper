# Warband Keeper

Addon World of Warcraft (WoW Forever, `## Interface: 16001`) pour gérer l'ensemble de son compte :

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

Ouvre la fenêtre avec `/wk` ou le **bouton minimap** (clic gauche : ouvrir, clic droit : options, glisser : déplacer).

| Page | Contenu |
|---|---|
| Vue d'ensemble | Or du compte, nombre de persos, temps de jeu, évolution sur 7 jours, répartition de l'or, état de l'envoi auto |
| Personnages | Niveau, or, temps de jeu, dernière connexion (Maj + clic sur la corbeille pour oublier un perso) |
| Inventaire | Recherche dans tous les sacs et banques, filtre Tout / Sacs / Banque |
| Métiers | Barres de progression par personnage |
| Statistiques | Graphique de l'or ou d'un matériau suivi sur 7 j / 30 j / 90 j / 1 an |
| Courrier automatique | Ajout de règles (Maj + clic sur un objet), choix rapide du destinataire |
| Options | Couleur d'accent, échelle de la fenêtre, bouton minimap |

## Commandes

| Commande | Effet |
|---|---|
| `/wk` | Ouvre / ferme la fenêtre |
| `/wk aide` | Aide des commandes |
| `/wk options` | Ouvre les options |
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
UI/MainFrame.lua        Fenêtre principale et navigation
UI/Pages/*.lua          Une page par onglet
UI/MinimapButton.lua    Bouton minimap
Media/*.tga             Textures (cercle pour les arrondis, icônes)
tools/gen_media.py      Régénère les textures (python3 + Pillow)
```

## Feuille de route

- [x] Fenêtre principale (onglets Personnages / Inventaire / Métiers / Stats)
- [x] Graphiques d'évolution de l'or et des matériaux
- [x] Bouton minimap
- [ ] Suivi des matériaux dans la boîte aux lettres
- [ ] Locale anglaise (enUS)

## Licence

MIT
