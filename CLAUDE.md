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

## Marchand

`UI/MerchantPanel.lua` : panneau collé à `MerchantFrame` (« Pour monter tes métiers »), composants manquants de chaque guide de métier jusqu'au palier `settings.ui.guideTarget[métier]` (`Recipes:GuidePlan`), filtrés sur ce que vend le marchand ; achat sur clic (`BuyMerchantItem`). Réglage `settings.ui.merchantPanel`.

## Lieux et guidage

`Modules/PlacesDB.lua` est **généré** par `python3 tools/gen_places.py <clone de QuestieDB>` (`git clone --depth 1 https://github.com/Questie/QuestieDB`) : boîtes aux lettres, banquiers, marchands (munitions, composants, poisons…) et maîtres de classe de WoW Forever, avec noms français. Données Questie (GPLv3 selon son équipe) : garder la mention dans l'en-tête du fichier généré et dans Options > À propos. `Modules/Guide.lua` cherche le lieu le plus proche et gère la cible ; `UI/GuideArrow.lua` dessine la flèche, `UI/MapPins.lua` le repère sur la carte, `UI/NavPin.lua` l'épingle à l'écran (accrochée à `C_Navigation.GetFrame()`, le repère du point suivi du jeu, rendu invisible pendant ce temps ; bandeau d'arrivée et arrêt du guidage à moins de 10 m).

## Navigation

`Modules/RoadsDB.lua` est **généré** par `python3 tools/gen_roads.py <clone de QuestieDB>` : trajets de patrouille des PNJ (chemins praticables), simplifiés (données Questie, GPLv3 : garder la mention). `Modules/Nav.lua` : graphe des chemins par continent (coordonnées monde de `Guide.ToWorld` : x nord, y ouest, en mètres du jeu), chemins de base + chemins appris (`WK.DB.global.nav.trails`, hors profils : tronçons nouveaux seulement, simplifiés), A* étalé sur plusieurs images (hors chemins : coût `OFF` fois la distance), vols connus du perso (`characters[perso].taxi`, notés à `TAXIMAP_OPENED`), quai vers un autre continent (`MapLayers.TRANSPORTS`), suivi (`Nav:Waypoint()` pour la flèche, recalcul quand on s'écarte). `Guide:Start` lance `Nav:Plan`, `Guide:Stop` `Nav:Clear`. `UI/NavRoute.lua` dessine les pointillés (carte du monde via `UI/MapPins.lua`, minicarte). Vols : chemin réel noté pendant chaque vol (`Flight:Path(départ, arrivée)`, `WK.DB.global.flights.paths`), dessiné en vol et dans les étapes de vol. Bateaux appris (`Nav:Boats()`, `nav.boats` : position qui avance sans que le perso bouge, hors taxi) : quais ajoutés à `MapLayers:AllTransports()`, chemin dessiné par `UI:DrawBoatPaths`, saut quai à quai dans le graphe. Réglages dans `Guide:Config()` (`route`, `routeMini`, `learn`), carte « Navigation » de QoL > Carte. ShortestPathForever a été étudié puis retiré : ne rien reprendre de son code ni de ses données.

## Bibliothèques

`Libs/` contient du code tiers, à ne pas modifier : LibStub (domaine public) et LibRangeCheck-3.0 (licence MIT, github.com/WeakAuras/LibRangeCheck-3.0), qui donne la fourchette de distance de la cible à `UI/RangeRing.lua`. Garder le fichier `LICENSE` de la bibliothèque et la mention dans Options > À propos.

## Pêche

`Modules/Fishing.lua` gère le « mode pêche » (tenue, appâts, sons, touche unique, butin rapide, avertissements) ; `UI/FishingBar.lua` la barre à l'écran et le bouton de minicarte ; les réglages sont dans `QoL:Config().fishing` et la page dans la section « fishing » de `UI/Pages/QoL.lua`. Le lancer et la pose d'appât passent par le bouton protégé `WarbandKeeperFishButton` (macro préparée juste avant le clic, hors combat). La touche unique est une liaison temporaire (`SetOverrideBinding`), posée seulement en mode pêche : elle clique le bouton, ou ferre avec `INTERACTTARGET` quand le flotteur est désigné. Tout ce que le mode change (équipement, sons, réglages de désignation) est sauvegardé et rendu à la fermeture.

Carnet de pêche : `Modules/FishingLog.lua` note chaque butin de pêche (`Record`, appelé par le butin rapide de `Modules/Fishing.lua` avant de ramasser) dans `WK.DB.global.fishLog` (hors profils), et tient la session du mode pêche ; `UI/FishingRecap.lua` affiche le récapitulatif à la fermeture ; le carnet est dans la section « fishing » de QoL. Collection : `Modules/FishDB.lua` (référence écrite à la main, numéros d'objets vérifiés : espèces par catégorie et palier, zones avec compétence conseillée), `FishingLog:Collection()`, `:Atlas()`, `:SpeciesZones()`, `:GuideZone()` (dernier coin de pêche noté par zone, `zones[carte].pos`) ; `UI/FishingCollection.lua` dessine la carte (onglets Album et Par zone, hauteur variable), affichée dans la page « Pêche » du groupe Farm (`UI/Pages/FishCollection.lua`, clé `fishing`, module « fishing »).

## Emplacements de récolte

`Modules/NodesDB.lua` est **généré** par `python3 tools/gen_nodes.py <clone de QuestieDB>` : points d'apparition connus des filons et des plantes (données Questie, GPLv3 : garder la mention en tête du fichier et dans Options > À propos). `Modules/Nodes.lua` filtre selon les métiers et la compétence du perso ; `UI/NodePins.lua` dessine les icônes sur la minicarte (autour du joueur, sans capter la souris) et sur la carte du monde (appelé par `UI/MapPins.lua`). Ce sont des emplacements possibles, pas des nœuds en direct : lire les points de pistage du jeu a été étudié et écarté (technique fragile).

## Onglet LFG

`Modules/LFG.lua` pilote la recherche de groupe du jeu (`C_LFGList`, lu à chaque appel) : recherche sur un clic, lecture des résultats (toute valeur passe par `readable`, une valeur masquée ne cache jamais un groupe), place libre pour les rôles du perso (`FitRole`), message modèle et suivi des demandes (`M.requests`, réponses lues dans les chuchotements). `UI/Pages/LFG.lua` est la page : bandeau du perso, échelle des donjons, cartes de groupes, mes demandes. LFG Forever (GPLv3) a servi d'inspiration : son code n'est pas repris. Les couleurs de rôle sont `C.tank`, `C.heal`, `C.dps`.

## Rares

`Modules/RaresDB.lua` est **généré** par `python3 tools/gen_rares.py <clone de QuestieDB>` : PNJ de rang rare ou rare élite, apparitions et patrouilles par carte, nom français, butin notable (recettes, objets que peu de monstres donnent). `Modules/Rares.lua` : accès aux données, détection (plaque de nom ou cible dont le jeu dit « rare »), rares tués (`WK.DB.global.rares.kills`, notés au butin ou à la mort de la cible), guidage. `UI/RarePins.lua` : médaillons sur la carte du monde (appelé par `UI/MapPins.lua`), liste sur le côté de la carte, infobulle d'unité. `UI/RareAlert.lua` : bandeau « Rare en vue » (bouton Cibler protégé, hors combat). Page `UI/Pages/Rares.lua` : onglet « Collection » (tuiles des zones, rares de la zone choisie, par perso) et onglet « Carte et infobulle » (réglages, alerte avec aperçu ; `ShowSection("settings")` pour la recherche).

## Quêtes

`Modules/QuestsDB.lua` est **généré** par `python3 tools/gen_quests.py <clone de QuestieDB>` (il lui faut aussi `l10n/Classic/lookupQuests/frFR.lua` pour les noms français) : quêtes par zone (donjon : zone de l'entrée), niveau, faction, classes, métier, prérequis, donneur et XP ; quêtes répétables exclues. Données Questie (GPLv3) : garder la mention. `Modules/Quests.lua` : état d'une quête pour un perso (`ForChar`, `State`), zones, meilleure zone, guidage, infobulle du donneur ; quêtes faites et journal dans `characters[perso].quests`. `UI/Pages/Quests.lua` : même disposition que la page Rares (tuiles, liste, colonne de réglages).

## Modules

`Core/Features.lua` : liste des modules qu'on peut couper (`WK.FEATURES` : clé, nom, icône, groupe, page ou section de QoL, `reload` s'il affiche quelque chose à l'écran), `WK:FeatureOn(clé)`, `WK:PageOn(page)`, `WK:SetFeature(clé, actif)`. Réglage : `WK.DB.global.modulesOff` (dans les profils). Un nouveau module doit y être ajouté et vérifier `WK:FeatureOn` à ses points d'entrée (infobulle, dessin, détection, éléments à l'écran) ; sa page et sa section de QoL sont masquées automatiquement. Carte « Modules » : bas de `UI/Pages/Overview.lua`.

## Carte (lieux utiles)

`Modules/MapLayers.lua` : couches de lieux (`LAYERS` : bit de `PlacesDB`, famille, icône, filtres de classe ou de métier), familles de couleur, trajets des bateaux et zeppelins (`TRANSPORTS`, quais de l'Alliance relevés à la main), réglages `WK.DB.global.mapLayers` (map et mini par couche). `UI/MapLayers.lua` : pastilles et tracés sur la carte du monde (appelé par `UI/MapPins.lua`), barre de filtres posée sur la carte, pastilles de la minicarte. Les nouveaux genres de lieux (HV, auberge, vol, maître de métier avec le métier dans le champ classe, maître de guerre, familiers) viennent de `tools/gen_places.py`.

## Hôtel des ventes

`Modules/AHScan.lua` : scan de l'HV (complet avec `getAll` quand `CanSendAuctionQuery` le permet, sinon page par page ; `C_AuctionHouse.ReplicateItems` si le client l'a), lecture par morceaux à chaque image, prix par royaume et faction dans `WK.DB.global.ah.realms` (exclus des profils), infobulle (appelée par `Modules/Inventory.lua`), `/wk hv`. Listes d'achat : `WK.DB.global.ah.lists` (`SaveList`, `GetList`, `DeleteList`, `SearchItem` qui remplit la recherche de la fenêtre de l'HV du jeu) ; les métiers les créent via `Recipes:ExportToList` / `GuideToList`. `UI/AuctionPanel.lua` : panneau collé à la fenêtre de l'HV (onglets Scan et Listes d'achat). `Modules/Value.lua` ne prend que nos prix (plus d'Auctionator). `Modules/AHSell.lua` : côté vente (mes enchères via `QueryOwnedAuctions`, vérification du plus bas une recherche toutes les 1,2 s, `Cancel` sur clic, vente rapide accrochée à `SetItem` des fenêtres de vente du jeu, alertes de prix `ah.alerts` vérifiées après chaque scan, `/wk alerte`) ; onglet « Ventes » du panneau. Prix exacts : `UI:ExactMoney`. Ne pas confondre avec `Modules/Auction.lua` (journal des ventes et achats lus sur les factures du courrier).

## Recherche et profils

`UI/Search.lua` : la recherche de la barre latérale. Chaque `UI:SettingRow` s'inscrit dans `UI.settingIndex` ; à la première recherche, les pages pas encore ouvertes sont construites (cachées) pour être indexées. Un nouveau réglage est donc trouvable s'il passe par `UI:SettingRow`. `Modules/Profiles.lua` : profils de réglages (page `UI/Pages/Profiles.lua`, en bas de la barre latérale), appliqués par `Core/Init.lua` juste après `WK.DB:Init()` (avant tout le reste). La liste `KEYS` dit ce qu'un profil contient (clés de `WK.DB.global`, sous-clés de données exclues) : un nouveau réglage rangé ailleurs doit y être ajouté, une nouvelle donnée de compte rangée dans ces clés doit y être exclue.
