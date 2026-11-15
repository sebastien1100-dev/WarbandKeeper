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

## Disposition et taille

La fenêtre est redimensionnable en direct et les pages ne sont **jamais reconstruites** pour une nouvelle taille (WoW ne détruit pas les cadres). Une page doit donc être élastique :
- ancrer les cartes aux bords (`TOPLEFT` + `TOPRIGHT`, `BOTTOMRIGHT`…) plutôt que leur donner une largeur fixe ;
- ce qui se calcule (colonnes, tuiles, retours à la ligne) se fait dans `UI:OnResize(frame, function(w, h) ... end)` ;
- un graphique se redessine avec `UI:RefreshSoon()` depuis `OnResize`.
`UI.PAGE_W` / `UI.PAGE_H` suivent la taille en direct. La largeur minimale de contenu est de 840 px : toute page doit tenir dans cette largeur.

## Pièges connus

- Ne pas mélanger un ancrage haut/bas (`TOPLEFT`…) et un ancrage centré (`LEFT`, `RIGHT`) sur une même région : utiliser `TOPRIGHT` avec le même décalage vertical.
- Fonctions globales absentes sur ce client : passer par `WK.GetItemInfo`, `WK.InsertChatLink`, `WK.Container.*`.
- Dans une page (`UI:RegisterPage`), `self` est la définition de la page : ne pas y créer de champs `title`, `subtitle`, `nav`, `navIcon`, `count`, `key`, `order`, `frame` ou `noHeader`, utilisés par `UI/MainFrame.lua`.
- Les polices du jeu ne couvrent que le jeu de caractères Windows-1252 : pas de « → », « ≈ », « ✓ »… dans les textes affichés (utiliser « » », « ~ », « · », « • »).
- Noms de personnages en deux parties sur WoW Forever (« Prénom Nom », avec un espace) : le courrier exige le nom complet. Ne jamais découper un nom sur les espaces ; pour un destinataire, passer par `WK.modules.Mail:Recipient()` / `:Resolve()` / `:IsMe()`.

## En-tête des pages

Plus de titre ni de phrase en haut des pages : l'en-tête affiche des pastilles de chiffres clés, définies par page dans `UI.CHIPS` (`UI/MainFrame.lua`). Chaque fonction renvoie `{ label, valeur, couleur?, page?, tip?, after? }` ; `page` rend la pastille cliquable. Une nouvelle page doit avoir ses pastilles.

## Guides de montée des métiers

`Modules/Guides.lua` est **généré** par `python3 tools/gen_guides.py` depuis `tools/guides/*.json` (extraits des guides WoW Forever de wowtbc.gg). Pour ajouter ou mettre à jour un métier : télécharger `https://wowtbc.gg/page-data/warcraftforever/professions/<métier>/page-data.json` puis `python3 tools/gen_guides.py --import <fichier>`. Une remarque de maître nouvelle doit être traduite dans `NOTES` du générateur (et en anglais dans `Locales/enUS.lua`).
- Infobulles : toujours `WK.UI:TooltipOwner(owner, anchor)` au lieu de `GameTooltip:SetOwner` ; elle habille l'infobulle aux couleurs de l'addon (le cadre du jeu revient à la fermeture).

## Qualité de vie (QoL)

`Modules/QoL.lua` porte les données (composants par classe dans `M.REAGENTS`, coffres, villes de portail), les réglages (`WK.DB.global.qol`, complétés par `QoL:Config()`), les alertes (`QoL:Alerts()`, reprises par « À faire » et les pastilles) et les automatisations. `UI/Pages/QoL.lua` est la page (colonne Général + 9 classes). Les actions que le jeu protège (supprimer un objet, nourrir le familier, changer d'armes) passent par un clic du joueur ou une macro, jamais en combat.

## Lieux et guidage

`Modules/PlacesDB.lua` est **généré** par `python3 tools/gen_places.py <clone de QuestieDB>` (`git clone --depth 1 https://github.com/Questie/QuestieDB`) : boîtes aux lettres, banquiers, marchands (munitions, composants, poisons…) et maîtres de classe de WoW Forever, avec noms français. Données Questie (GPLv3 selon son équipe) : garder la mention dans l'en-tête du fichier généré et dans Options > À propos. `Modules/Guide.lua` cherche le lieu le plus proche et gère la cible ; `UI/GuideArrow.lua` dessine la flèche, `UI/MapPins.lua` le repère sur la carte.

## Bibliothèques

`Libs/` contient du code tiers, à ne pas modifier : LibStub (domaine public) et LibRangeCheck-3.0 (licence MIT, github.com/WeakAuras/LibRangeCheck-3.0), qui donne la fourchette de distance de la cible à `UI/RangeRing.lua`. Garder le fichier `LICENSE` de la bibliothèque et la mention dans Options > À propos.
