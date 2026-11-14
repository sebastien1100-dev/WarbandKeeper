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

## Commandes

| Commande | Effet |
|---|---|
| `/wk` | Aide |
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
```

## Feuille de route

- [ ] Fenêtre principale (onglets Personnages / Inventaire / Métiers / Stats)
- [ ] Graphiques d'évolution de l'or et des matériaux
- [ ] Bouton minimap
- [ ] Suivi des matériaux dans la boîte aux lettres
- [ ] Locale anglaise (enUS)

## Licence

MIT
