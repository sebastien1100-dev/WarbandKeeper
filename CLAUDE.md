# Warband Keeper : consignes de développement

Addon World of Warcraft (client WoW Forever, `## Interface: 16001`, API moderne : `C_Item`, `C_Container`, `TooltipDataProcessor`…). Toute l'interface et les textes sont en français.

## Notes de patch (obligatoire à chaque modification)

Chaque ajout, modification ou correction doit être noté **dans le même commit** :

1. Dans `Core/Changelog.lua` :
   - nouvelle version : ajouter une entrée **en tête** de `WK.Changelog` (version, date `JJ/MM/AAAA`, listes `added`, `changed`, `fixed`) ;
   - changement non publié : compléter l'entrée de tête.
   - Phrases courtes, en français, du point de vue du joueur (ce qui change pour lui, pas le détail du code). Une correction dit ce qui n'allait pas.
2. Déplacer de `WK.Roadmap` ce qui vient d'être livré ; y ajouter les idées acceptées mais pas encore commencées.
3. Monter la version dans `WarbandKeeper.toc` (`## Version`) **et** `Core/Init.lua` (`WK.version`) ; elles doivent être identiques à la version de tête du changelog.
4. Régénérer `CHANGELOG.md` : `python3 tools/gen_changelog.py`.

## Textures

Les textures de `Media/` sont générées par `python3 tools/gen_media.py` (Pillow). Un nouveau fichier de texture ou un nouveau `.lua` demande de **redémarrer le jeu** (un `/reload` ne suffit pas) : le signaler dans la note de version.

## Thèmes

Les couleurs viennent de `UI/Themes.lua` : un thème donne quelques couleurs de base (`bg`, `line`, `frame`, `glow`, `text`, `muted`, `accent`) et `palette()` dérive le reste. `UI:ApplyTheme()` recopie la palette dans `UI.colors` au chargement : ne jamais réassigner `UI.colors`, et ne pas mettre de couleur en dur dans les pages (utiliser `C.*` ou `UI:Accent()`).

## Pièges connus

- Ne pas mélanger un ancrage haut/bas (`TOPLEFT`…) et un ancrage centré (`LEFT`, `RIGHT`) sur une même région : utiliser `TOPRIGHT` avec le même décalage vertical.
- Fonctions globales absentes sur ce client : passer par `WK.GetItemInfo`, `WK.InsertChatLink`, `WK.Container.*`.
- Dans une page (`UI:RegisterPage`), `self` est la définition de la page : ne pas y créer de champs `title`, `subtitle`, `nav`, `navIcon`, `count`, `key`, `order`, `frame` ou `noHeader`, utilisés par `UI/MainFrame.lua`.
