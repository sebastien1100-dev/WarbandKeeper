# Warband Keeper : consignes de développement

Addon World of Warcraft (client WoW Forever, `## Interface: 16001`, API moderne : `C_Item`, `C_Container`, `TooltipDataProcessor`…). Toute l'interface et les textes sont en français.

## Notes de patch (obligatoire à chaque modification)

Chaque ajout, modification ou correction doit être noté **dans le même commit** :

1. Dans `Core/Changelog.lua` :
   - nouvelle version : ajouter une entrée **en tête** de `WK.Changelog` (version, date `JJ/MM/AAAA`, listes `added`, `changed`, `fixed`) ;
   - changement non publié : compléter l'entrée de tête.
   - `restart = true` dans l'entrée quand il faut redémarrer complètement le jeu (nouveau `.lua`, nouvelle texture, `.toc` modifié) ; sinon rien (un /reload suffit). Affiché en jeu (pastille), dans `CHANGELOG.md` et dans les Releases (le workflow corrige la mention s'il voit de nouveaux fichiers) ; le client le recalcule à l'installation.
   - Phrases courtes, en français, du point de vue du joueur (ce qui change pour lui, pas le détail du code). Une correction dit ce qui n'allait pas.
2. Déplacer de `WK.Roadmap` ce qui vient d'être livré ; y ajouter les idées acceptées mais pas encore commencées.
3. Monter la version dans `WarbandKeeper.toc` (`## Version`) **et** `Core/Init.lua` (`WK.version`) ; elles doivent être identiques à la version de tête du changelog.
4. Régénérer `CHANGELOG.md` : `python3 tools/gen_changelog.py`.

## Textures

Les textures de `Media/` sont générées par `python3 tools/gen_media.py` (Pillow). Un nouveau fichier de texture ou un nouveau `.lua` demande de **redémarrer le jeu** (un `/reload` ne suffit pas) : le signaler dans la note de version.

## Thèmes

Les couleurs viennent de `UI/Themes.lua` : un thème donne quelques couleurs de base (`bg`, `line`, `frame`, `glow`, `text`, `muted`, `accent`) et `palette()` dérive le reste. `UI:ApplyTheme()` recopie la palette dans `UI.colors` au chargement : ne jamais réassigner `UI.colors`, et ne pas mettre de couleur en dur dans les pages (utiliser `C.*` ou `UI:Accent()`). **Tout bouton est à la couleur de l'apparence (`UI:Accent()`), même au repos** : styles `UI:Button` (primary, secondary, ghost), `UI:IconButton`, onglets ; pas de libellé de bouton en `C.muted`. Seule exception : les boutons de suppression (`danger`).

## Disposition et taille

La fenêtre est redimensionnable en direct et les pages ne sont **jamais reconstruites** pour une nouvelle taille (WoW ne détruit pas les cadres). Une page doit donc être élastique :
- ancrer les cartes aux bords (`TOPLEFT` + `TOPRIGHT`, `BOTTOMRIGHT`…) plutôt que leur donner une largeur fixe ;
- ce qui se calcule (colonnes, tuiles, retours à la ligne) se fait dans `UI:OnResize(frame, function(w, h) ... end)` ;
- un graphique se redessine avec `UI:RefreshSoon()` depuis `OnResize`.
`UI.PAGE_W` / `UI.PAGE_H` suivent la taille en direct. La largeur minimale de contenu est de 840 px : toute page doit tenir dans cette largeur.

## Pièges connus

- Journal de combat (`COMBAT_LOG_EVENT_UNFILTERED`) : réservé au jeu, s'y inscrire ou s'en désinscrire déclenche ADDON_ACTION_FORBIDDEN. Ne jamais l'utiliser.
- `GetMerchantItemInfo` est absent : passer par `WK.MerchantItemInfo(index)`.

- Ne pas mélanger un ancrage haut/bas (`TOPLEFT`…) et un ancrage centré (`LEFT`, `RIGHT`) sur une même région : utiliser `TOPRIGHT` avec le même décalage vertical.
- Fonctions globales absentes sur ce client : passer par `WK.GetItemInfo`, `WK.InsertChatLink`, `WK.Container.*`.
- Dans une page (`UI:RegisterPage`), `self` est la définition de la page : ne pas y créer de champs `title`, `subtitle`, `nav`, `navIcon`, `count`, `key`, `order`, `frame` ou `noHeader`, utilisés par `UI/MainFrame.lua`.
- Les polices du jeu ne couvrent que le jeu de caractères Windows-1252 : pas de « → », « ≈ », « ✓ »… dans les textes affichés (utiliser « » », « ~ », « · », « • »).
- Noms de personnages en deux parties sur WoW Forever (« Prénom Nom », avec un espace) : le courrier exige le nom complet. Ne jamais découper un nom sur les espaces ; pour un destinataire, passer par `WK.modules.Mail:Recipient()` / `:Resolve()` / `:IsMe()`.

## Barre latérale

`UI/MainFrame.lua` : Résumé (`HOME_PAGE`) à part en haut, puis un trait ; groupes (`GROUPS` : titre, pages, icône ; Bataillon, Trésorerie, Artisanat, Butin, Aventure, Réglages QoL) repliables par un clic sur leur titre (`GroupHead`, `settings.ui.navClosed[groupe]`, total des pastilles quand replié ; la page affichée reste visible) ; le groupe « Réglages QoL » a pour entrées les sections de la page QoL (`SubItem`, une par `UI.QOL_SECTIONS`, pas d'entrée « QoL » elle-même ; total de leurs alertes quand replié). Menu réduit en icônes : tout visible (sections comprises), sans titres. Les groupes de `Core/Features.lua` (carte Modules) sont les mêmes, chacun d'un seul tenant dans la liste.

## En-tête des pages

Plus de titre ni de phrase en haut des pages : l'en-tête affiche des pastilles de chiffres clés, définies par page dans `UI.CHIPS` (`UI/MainFrame.lua`). Chaque fonction renvoie `{ label, valeur, couleur?, page?, tip?, after? }` ; `page` rend la pastille cliquable. Une nouvelle page doit avoir ses pastilles.

## Mise à jour des données

`python3 tools/update_data.py` (lupa requis) : met à jour QuestieDB (clone dans `tools/.cache/QuestieDB`, ignoré par git, ou `--questie <clone>`), télécharge les guides (ceux de `tools/guides`) et les tables de butin de wowtbc.gg, relance tous les générateurs (lieux, chemins, rares, quêtes, donjons, guides, recettes), charge chaque fichier généré et compare les chiffres : un fichier qui ne se charge plus ou un chiffre qui chute de plus de 20 % remet tout comme avant (code 2). Résumé Markdown avec `--summary`. Options `--sans-questie`, `--sans-wowtbc`. `.github/workflows/update-data.yml` tourne chaque jour et suit `tools/update_schedule.json` (`frequence` : quotidienne / hebdomadaire (lundi) / manuelle ; `publier`), modifiable depuis le client PC (Réglages > Données). `publier: false` : PR `data-update/<date>` (l'ancienne PR ouverte est fermée), à intégrer puis publier comme une version. `publier: true` : `tools/publish_data.py` monte la version d'un cran, écrit l'entrée « Données mises à jour… » du changelog à partir des chiffres (`--json` de update_data.py), pousse sur main et lance `release.yml`. Un nouveau générateur doit y être ajouté (étape et chiffres dans `metrics()`).

## Publication et client PC

Chaque push sur main qui change `## Version` lance `.github/workflows/release.yml` : Release `vX.Y.Z` avec `WarbandKeeper-X.Y.Z.zip` (git archive ; `.gitattributes` exclut `.github`, `client`) et les notes de la version tirées de `CHANGELOG.md`, puis l'exe du client construit sur Windows (PyInstaller) et joint à la Release. `client/wk_client.py` (Tkinter, thème Graphite avec accent bleu électrique, pas de rose ; pages déclarées par `@page`) : détection de WoW (`find_installs` : registre, Battle.net.config, disques ; WoW Forever reconnu par le dossier, `.flavor.info` ou des addons en interface 16xxx ; **seules les installations WoW Forever sont proposées** (`find_forever`), un autre dossier demande confirmation ; choix si plusieurs), redémarrage ou /reload calculé à l'installation (`install_zip` : nouveaux fichiers ou .toc modifié), lit les Releases (jeton fine-grained en lecture seule tant que le dépôt est privé), installe le zip dans Interface\AddOns (sauvegarde des SavedVariables avant, version précédente gardée dans `%APPDATA%\WarbandKeeper Client`), se met à jour lui-même (asset `WarbandKeeper-Client-<CLIENT_VERSION>.exe`). Monter `CLIENT_VERSION` à chaque changement du client et noter le changement dans **`client/CHANGELOG.md`** (notes du client, à part : jamais dans `Core/Changelog.lua`, qui ne parle que de l'addon) ; la Release ajoute « ## Client PC x.y.z » à ses notes et joint `WarbandKeeper-Client-notes.md`. Réglages du client : Mises à jour (`checkEvery`, toutes les heures par défaut ; nouvelle version signalée par `flash_taskbar`, le titre et un message ; `autoInstall` ; `startup` = clé Run de Windows, lancé avec `--minimized`), Données (planning GitHub, jeton en écriture). Logo : `client/make_assets.py`. Mode d'emploi : `client/README.md`.

## Données Everloot

`Modules/EverlootDB.lua` est **généré** par `tools/gen_everloot.py` (`--fetch` télécharge le dernier export de https://data.everloot.app/open-data/latest.json dans `tools/.cache/everloot-data`, puis `python3 tools/gen_everloot.py <clone de QuestieDB>`). `WK.EverDrops[objet]` : taux de drop observés par les joueurs (sources PNJ, 3 butins au moins ; **CC BY-SA 4.0**, garder la mention « Data from Everloot (https://everloot.app), CC BY-SA 4.0 » dans l'en-tête et dans Options > À propos), `WK.EverNpcs` (noms, français de QuestieDB), `WK.FlightGame` (maîtres et trajets de vol des fichiers du jeu, coordonnées monde comme `Guide.ToWorld`). Utilisé par l'infobulle (« Butin observé », `settings.ui.tooltipDrops`), `Dungeons:ItemInfo` (taux observé si wowtbc n'en a pas) et `Flight:Path` (trajet du jeu quand le vol n'a pas été fait : relais retrouvé par position dans `characters[perso].taxi`, Dijkstra sur les trajets directs) ; `Flight:RouteTime` estime sur la longueur de ce trajet. Mis à jour par `update_data.py` (chiffres « Objets avec taux de drop observé », « Trajets de vol »). wago.tools (tables du client WoW Forever, en français) est une source possible pour les noms français des donjons et des boss : pas encore branchée.

## Guides de montée des métiers

`Modules/Guides.lua` est **généré** par `python3 tools/gen_guides.py` depuis `tools/guides/*.json` (extraits des guides WoW Forever de wowtbc.gg). Pour ajouter ou mettre à jour un métier : télécharger `https://wowtbc.gg/page-data/warcraftforever/professions/<métier>/page-data.json` puis `python3 tools/gen_guides.py --import <fichier>`. Une remarque de maître nouvelle doit être traduite dans `NOTES` du générateur (et en anglais dans `Locales/enUS.lua`).
- Infobulles : toujours `WK.UI:TooltipOwner(owner, anchor)` au lieu de `GameTooltip:SetOwner` ; elle habille l'infobulle aux couleurs de l'addon (le cadre du jeu revient à la fermeture).

## Qualité de vie (QoL)

`Modules/QoL.lua` porte les données (composants par classe dans `M.REAGENTS`, coffres, villes de portail), les réglages (`WK.DB.global.qol`, complétés par `QoL:Config()`), les alertes (`QoL:Alerts()`, reprises par « À faire » et les pastilles) et les automatisations. `UI/Pages/QoL.lua` est la page (sections Général… Classes, choisies dans la barre latérale sous « QoL » : `UI.QOL_SECTIONS`, `UI:QoLSectionCount`, `UI:QoLCurrentSection` ; la colonne interne est masquée). Les actions que le jeu protège (supprimer un objet, nourrir le familier, changer d'armes) passent par un clic du joueur ou une macro, jamais en combat.

## Marchand

`UI/MerchantPanel.lua` : panneau collé à `MerchantFrame` (« Pour monter tes métiers »), composants manquants de chaque guide de métier jusqu'au palier `settings.ui.guideTarget[métier]` (`Recipes:GuidePlan`), filtrés sur ce que vend le marchand ; achat sur clic (`BuyMerchantItem`). Réglage `settings.ui.merchantPanel`.

## Lieux et guidage

`Modules/PlacesDB.lua` est **généré** par `python3 tools/gen_places.py <clone de QuestieDB>` (`git clone --depth 1 https://github.com/Questie/QuestieDB`) : boîtes aux lettres, banquiers, marchands (munitions, composants, poisons…) et maîtres de classe de WoW Forever, avec noms français. Données Questie (GPLv3 selon son équipe) : garder la mention dans l'en-tête du fichier généré et dans Options > À propos. `Modules/Guide.lua` cherche le lieu le plus proche et gère la cible ; `UI/GuideArrow.lua` dessine la flèche, `UI/MapPins.lua` le repère sur la carte, `UI/NavPin.lua` l'épingle à l'écran (accrochée à `C_Navigation.GetFrame()`, le repère du point suivi du jeu, rendu invisible pendant ce temps ; bandeau d'arrivée et arrêt du guidage à moins de 10 m).

## Navigation

`Modules/RoadsDB.lua` est **généré** par `python3 tools/gen_roads.py <clone de QuestieDB>` : trajets de patrouille des PNJ (chemins praticables), simplifiés (données Questie, GPLv3 : garder la mention). `Modules/Nav.lua` : graphe des chemins par continent (coordonnées monde de `Guide.ToWorld` : x nord, y ouest, en mètres du jeu), chemins de base + chemins appris (`WK.DB.global.nav.trails`, hors profils : tronçons nouveaux seulement, simplifiés), A* étalé sur plusieurs images (hors chemins : coût `OFF` fois la distance), vols connus du perso (`characters[perso].taxi`, notés à `TAXIMAP_OPENED`), quai vers un autre continent (`MapLayers.TRANSPORTS`), suivi (`Nav:Waypoint()` pour la flèche, recalcul quand on s'écarte). `Guide:Start` lance `Nav:Plan`, `Guide:Stop` `Nav:Clear`. `UI/NavRoute.lua` dessine les pointillés (carte du monde via `UI/MapPins.lua`, minicarte). Vols : chemin réel noté pendant chaque vol (`Flight:Path(départ, arrivée)`, `WK.DB.global.flights.paths`), dessiné en vol et dans les étapes de vol. Bateaux appris (`Nav:Boats()`, `nav.boats` : position qui avance sans que le perso bouge, hors taxi) : quais ajoutés à `MapLayers:AllTransports()`, chemin dessiné par `UI:DrawBoatPaths`, saut quai à quai dans le graphe. Réglages dans `Guide:Config()` (`route`, `routeMini`, `learn`), carte « Navigation » de QoL > Carte. ShortestPathForever a été étudié puis retiré : ne rien reprendre de son code ni de ses données.

## Voyages et curseur

`Modules/Flight.lua` : barre de vol, durées apprises (`flights.routes`), durée dans l'infobulle des destinations de la carte des vols (`RouteTime`, accroché à `TaxiNodeOnButtonEnter` et `FlightMap_FlightPointPinMixin`), points de vol à apprendre (`MissingFlightPoints` : maîtres de vol de `PlacesDB` de la faction, sans relais connu à moins de 120 m dans `characters[perso].taxi`), rappel une fois par zone et par session (`fpRemind`), `/wk vol`, carte « Points de vol à apprendre » de QoL > Carte. `UI/CursorRing.lua` : section « Curseur » de QoL (`QoL:Config().cursor`, module `cursor`) : anneau autour de la souris (balayage temps global / incantation, rouge hors de portée via LibRangeCheck), et réglage `ClipCursor` du jeu mis à « 1 » en combat (valeur d'avant gardée dans `WK.DB.global.cursorClip.saved`, rendue en sortie de combat et à la connexion).

## Bibliothèques

`Libs/` contient du code tiers, à ne pas modifier : LibStub (domaine public) et LibRangeCheck-3.0 (licence MIT, github.com/WeakAuras/LibRangeCheck-3.0), qui donne la fourchette de distance de la cible à `UI/RangeRing.lua`. Garder le fichier `LICENSE` de la bibliothèque et la mention dans Options > À propos.

## Pêche

`Modules/Fishing.lua` gère le « mode pêche » (tenue, appâts, sons, touche unique, butin rapide, avertissements) ; `UI/FishingBar.lua` la barre à l'écran et le bouton de minicarte ; les réglages sont dans `QoL:Config().fishing` et la page dans la section « fishing » de `UI/Pages/QoL.lua`. Le lancer et la pose d'appât passent par le bouton protégé `WarbandKeeperFishButton` (macro préparée juste avant le clic, hors combat). La touche unique est une liaison temporaire (`SetOverrideBinding`), posée seulement en mode pêche : elle clique le bouton, ou ferre avec `INTERACTTARGET` quand le flotteur est désigné. Tout ce que le mode change (équipement, sons, réglages de désignation) est sauvegardé et rendu à la fermeture.

Carnet de pêche : `Modules/FishingLog.lua` note chaque butin de pêche (`Record`, appelé par le butin rapide de `Modules/Fishing.lua` avant de ramasser) dans `WK.DB.global.fishLog` (hors profils), et tient la session du mode pêche ; `UI/FishingRecap.lua` affiche le récapitulatif à la fermeture ; le carnet est dans la section « fishing » de QoL. Collection : `Modules/FishDB.lua` (référence écrite à la main, numéros d'objets vérifiés : espèces par catégorie et palier, zones avec compétence conseillée), `FishingLog:Collection()`, `:Atlas()`, `:SpeciesZones()`, `:GuideZone()` (dernier coin de pêche noté par zone, `zones[carte].pos`) ; `UI/FishingCollection.lua` dessine la carte (onglets Album et Par zone, hauteur variable), affichée dans la page « Pêche » du groupe Farm (`UI/Pages/FishCollection.lua`, clé `fishing`, module « fishing »).

## Emplacements de récolte

`Modules/Nodes.lua` : filons et plantes **déjà récoltés** par tes persos (`WK.DB.global.gatherSpots`, notés par `Modules/GatherMap.lua` à chaque récolte), regroupés par nœud, filtrés selon les métiers et la compétence du perso ; `UI/NodePins.lua` dessine les icônes sur la minicarte (autour du joueur, sans capter la souris) et sur la carte du monde (appelé par `UI/MapPins.lua`). Les points d'apparition de QuestieDB (ancien `NodesDB.lua`) ne correspondaient pas aux nœuds de WoW Forever : retirés. Les points de pistage du jeu ne sont lisibles par aucun addon : le **HUD de récolte** (`UI/GatherHUD.lua`) déplace la minicarte du jeu au centre de l'écran, agrandie, transparente, dézoomée et tournée avec le perso (tout est rendu à la fermeture ; `/wk hud`, raccourci `WARBANDKEEPER_HUD` dans `Bindings.xml`, réglages `settings.ui.gatherHUD` dans Options).

## Onglet LFG

`Modules/LFG.lua` pilote la recherche de groupe du jeu (`C_LFGList`, lu à chaque appel) : recherche sur un clic, lecture des résultats (toute valeur passe par `readable`, une valeur masquée ne cache jamais un groupe), place libre pour les rôles du perso (`FitRole`), message modèle et suivi des demandes (`M.requests`, réponses lues dans les chuchotements). `UI/Pages/LFG.lua` est la page : bandeau du perso, échelle des donjons, cartes de groupes, mes demandes. LFG Forever (GPLv3) a servi d'inspiration : son code n'est pas repris. Les couleurs de rôle sont `C.tank`, `C.heal`, `C.dps`.

## Rares

`Modules/RaresDB.lua` est **généré** par `python3 tools/gen_rares.py <clone de QuestieDB>` : PNJ de rang rare ou rare élite, apparitions et patrouilles par carte, nom français, butin notable (recettes, objets que peu de monstres donnent). `Modules/Rares.lua` : accès aux données, détection (plaque de nom ou cible dont le jeu dit « rare »), rares tués (`WK.DB.global.rares.kills`, notés au butin ou à la mort de la cible), guidage. `UI/RarePins.lua` : médaillons sur la carte du monde (appelé par `UI/MapPins.lua`), liste sur le côté de la carte, infobulle d'unité. `UI/RareAlert.lua` : bandeau « Rare en vue » (bouton Cibler protégé, hors combat). Page `UI/Pages/Rares.lua` : onglet « Collection » (tuiles des zones, rares de la zone choisie, par perso) et onglet « Carte et infobulle » (réglages, alerte avec aperçu ; `ShowSection("settings")` pour la recherche).

## Quêtes

`Modules/QuestsDB.lua` est **généré** par `python3 tools/gen_quests.py <clone de QuestieDB>` (il lui faut aussi `l10n/Classic/lookupQuests/frFR.lua` pour les noms français) : quêtes par zone (donjon : zone de l'entrée), niveau, faction, classes, métier, prérequis, donneur et XP ; quêtes répétables exclues. Données Questie (GPLv3) : garder la mention. `Modules/Quests.lua` : état d'une quête pour un perso (`ForChar`, `State`), zones, meilleure zone, guidage, infobulle du donneur ; quêtes faites et journal dans `characters[perso].quests`. `UI/Pages/Quests.lua` : même disposition que la page Rares (tuiles, liste, colonne de réglages).

## Donjons

`Modules/DungeonsDB.lua` est **généré** par `tools/gen_dungeons.py` en deux temps : `--import <dossier>` (page-data.json des tables de butin WoW Forever de wowtbc.gg, `https://wowtbc.gg/page-data/warcraftforever/loot-tables/dungeons/<donjon>/page-data.json` et `.../raids/<raid>/...`) écrit `tools/dungeons/wowtbc.json` ; puis `python3 tools/gen_dungeons.py <clone de QuestieDB>`. Liste `DUNGEONS` du générateur : page wowtbc » clé (zone QuestieDB, ou zone proche / 99000x pour le nouveau contenu ; stable, elle range kills et envies), n° d'instance (ou nil), nom français, aile, raid ; les ailes d'une même instance sont fusionnées. Butin et monstres du donjon (`trash`) : wowtbc.gg ; `WK.DungeonItems[objet]` = qualité, niveau d'objet, niveau requis, % de drop, non découvert. N° et niveau des boss (rapprochés par nom anglais), noms français, entrées, recettes en plus : QuestieDB (GPLv3, garder la mention ; wowtbc.gg cité dans Options > À propos). N° de rencontre des boss (7e champ, `ENCOUNTER_END` réussi = boss tué ; nom donné par le jeu retenu comme nom français dans `dungeons.bossNames`) : `--import-encounters <client-encounters.json>` » `tools/dungeons/encounters.json`, catalogue des fichiers du jeu d'Everloot (github.com/Everloot/everloot, récupéré par update_data.py en clone partiel). Les données observées d'Everloot (export CC BY-SA 4.0, data.everloot.app) et d'opendata (wowlayerup-forever, CC BY 4.0) sont des sources possibles pour les taux de drop ; DungeonQuestAtlas est « tous droits réservés » : rien à reprendre. Boss sans n° (id 0) : appris en jeu (`LearnBoss`, `dungeons.bossIds`) par le nom ou par un objet de leur table trouvé sur le corps ; instance inconnue reconnue par son nom ou ses boss (`dungeons.inst`), nom affiché repris du jeu (`dungeons.names`). `Modules/Dungeons.lua` : donjon en cours (`GetInstanceInfo`, n° d'instance), boss tués (pas de journal de combat : s'inscrire à `COMBAT_LOG_EVENT_UNFILTERED` est interdit aux addons sur ce client ; mort d'une unité visible lue sur `UNIT_HEALTH` : cible, focus, boss1-5, plaques de nom, et source du butin `GetLootSourceInfo` ; seulement en donjon ; passage en cours `M.run`, et au moins une fois par perso `dungeons.kills`), `Usable` (classe, armure selon le niveau, armes, recettes selon les métiers), liste d'envies par perso (`dungeons.wish`), alertes (entrée dans un donjon qui contient des envies, envie tombée lue dans `CHAT_MSG_LOOT`), guidage vers l'entrée. `Bosses(d)` : boss comptés ; `LootGroups(d)` : boss puis monstres du donjon, pour l'affichage. `UI/DungeonPanel.lua` : panneau collé à la carte en donjon (et `/wk donjon`), `UI:DungeonLootRow` (ligne d'objet : « non découvert », % de drop). `UI/Pages/Dungeons.lua` : page (tuiles ; détail en deux onglets `dtab` « Butin » (filtre `filter` me/all) et « Quêtes » (`RefreshQuests`, filtre `qfilter` todo/all) ; `PlaceButtons` pour le bas de carte ; Mes envies). `DungeonLootRow:Set(..., hideMine)` masque « pour toi » quand la liste est déjà filtrée pour le perso.

## Modules

`Core/Features.lua` : liste des modules qu'on peut couper (`WK.FEATURES` : clé, nom, icône, groupe, page ou section de QoL, `reload` s'il affiche quelque chose à l'écran), `WK:FeatureOn(clé)`, `WK:PageOn(page)`, `WK:SetFeature(clé, actif)`. Réglage : `WK.DB.global.modulesOff` (dans les profils). Un nouveau module doit y être ajouté et vérifier `WK:FeatureOn` à ses points d'entrée (infobulle, dessin, détection, éléments à l'écran) ; sa page et sa section de QoL sont masquées automatiquement. Carte « Modules » : bas de `UI/Pages/Overview.lua`.

## Carte (lieux utiles)

`Modules/MapLayers.lua` : couches de lieux (`LAYERS` : bit de `PlacesDB`, famille, icône, filtres de classe ou de métier), familles de couleur, trajets des bateaux et zeppelins (`TRANSPORTS`, quais de l'Alliance relevés à la main), réglages `WK.DB.global.mapLayers` (map et mini par couche). `UI/MapLayers.lua` : pastilles et tracés sur la carte du monde (appelé par `UI/MapPins.lua`), barre de filtres posée sur la carte, pastilles de la minicarte. Les nouveaux genres de lieux (HV, auberge, vol, maître de métier avec le métier dans le champ classe, maître de guerre, familiers) viennent de `tools/gen_places.py`.

## Hôtel des ventes

`Modules/AHScan.lua` : scan de l'HV (complet avec `getAll` quand `CanSendAuctionQuery` le permet, sinon page par page ; `C_AuctionHouse.ReplicateItems` si le client l'a), lecture par morceaux à chaque image, prix par royaume et faction dans `WK.DB.global.ah.realms` (exclus des profils), infobulle (appelée par `Modules/Inventory.lua`), `/wk hv`. Listes d'achat : `WK.DB.global.ah.lists` (`SaveList`, `GetList`, `DeleteList`, `SearchItem` qui remplit la recherche de la fenêtre de l'HV du jeu) ; les métiers les créent via `Recipes:ExportToList` / `GuideToList`. `UI/AuctionPanel.lua` : panneau collé à la fenêtre de l'HV (onglets Scan et Listes d'achat). `Modules/Value.lua` ne prend que nos prix (plus d'Auctionator). `Modules/AHSell.lua` : côté vente (mes enchères via `QueryOwnedAuctions`, vérification du plus bas une recherche toutes les 1,2 s, `Cancel` sur clic, vente rapide accrochée à `SetItem` des fenêtres de vente du jeu, alertes de prix `ah.alerts` vérifiées après chaque scan, `/wk alerte`) ; onglet « Ventes » du panneau. Prix exacts : `UI:ExactMoney`. Ne pas confondre avec `Modules/Auction.lua` (journal des ventes et achats lus sur les factures du courrier).

## Recherche et profils

`UI/Search.lua` : la recherche de la barre latérale. Chaque `UI:SettingRow` s'inscrit dans `UI.settingIndex` ; à la première recherche, les pages pas encore ouvertes sont construites (cachées) pour être indexées. Un nouveau réglage est donc trouvable s'il passe par `UI:SettingRow`. `Modules/Profiles.lua` : profils de réglages (page `UI/Pages/Profiles.lua`, en bas de la barre latérale), appliqués par `Core/Init.lua` juste après `WK.DB:Init()` (avant tout le reste). La liste `KEYS` dit ce qu'un profil contient (clés de `WK.DB.global`, sous-clés de données exclues) : un nouveau réglage rangé ailleurs doit y être ajouté, une nouvelle donnée de compte rangée dans ces clés doit y être exclue.
