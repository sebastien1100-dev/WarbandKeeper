local ADDON_NAME, WK = ...

-- Notes de patch : source unique, affichée en jeu (page « Notes de patch »)
-- et convertie en CHANGELOG.md par tools/gen_changelog.py.
-- Pour chaque version : added = ajouts, changed = modifications, fixed = corrections ;
-- restart = true quand il faut redémarrer complètement le jeu (nouveau fichier .lua, texture, .toc
-- modifié) : sinon un /reload suffit. Affiché en jeu, dans CHANGELOG.md et dans les Releases.
-- La plus récente en premier.
WK.Changelog = {
    {
        version = "1.128.95", date = "22/11/2026",
        changed = {
            "Métiers : le bouton « Ouvrir le métier » ferme aussi la fenêtre du métier quand elle est ouverte (il devient « Fermer le métier »).",
        },
    },
    {
        version = "1.128.94", date = "22/11/2026",
        fixed = {
            "Couleur de l'apparence (couleur de classe, accent par perso) : certains boutons et éléments gardaient une autre couleur (blancs ou gris) jusqu'à ce qu'on les survole ; tout est repeint à l'entrée en jeu et à l'ouverture de la fenêtre.",
        },
    },
    {
        version = "1.128.93", date = "22/11/2026",
        added = {
            "Métiers > Guide : bouton « Fabriquer xN » sur chaque étape dont tu connais la recette, avec le nombre de fabrications donné par le guide (ce qu'il reste pour l'étape en cours). Il faut la fenêtre du métier ouverte ; la série s'arrête d'elle-même quand les composants manquent.",
        },
    },
    {
        version = "1.128.92", date = "22/11/2026",
        added = {
            "Carte du monde : en haut à droite, les quêtes de la zone affichée pour ton perso, en étiquettes « 18 / 42 faites », « 5 en cours », « 7 à prendre » ; une seule étiquette verte « tout fait » quand la zone est finie.",
            "Survol des étiquettes : les quêtes à prendre de la zone (jusqu'à 10, par niveau) ; clic : page Quêtes sur cette zone.",
            "Roue de la page Quêtes, carte « Carte du monde » : afficher ou non ces étiquettes et leur opacité (pleine au survol de la souris).",
        },
    },
    {
        version = "1.128.91", date = "22/11/2026",
        fixed = {
            "Statistiques de vol : le texte des petites cartes (par exemple « dont 73 % sur … » dans PERSOS) était coupé par « … » ; il passe à la ligne et la carte s'agrandit.",
        },
    },
    {
        version = "1.128.90", date = "22/11/2026",
        added = {
            "Options > Apparence > Fenêtre : « Opacité des cadres à l'écran », un seul réglage pour toutes les fenêtres et cadres posés sur le jeu (quêtes du donjon, chrono, bilan, barre des sacs, listes du kit et des buffs, vol, statistiques de vol, quais…).",
            "Toutes les fenêtres de l'addon, la fenêtre principale comprise, passent à l'opacité pleine quand la souris est dessus ; les éléments rendus plus transparents en mode édition aussi.",
        },
        changed = {
            "Quêtes du donjon : l'opacité du fond suit le réglage commun (le curseur de la carte « Quêtes du donjon » est remplacé par un renvoi vers l'Apparence).",
        },
    },
    {
        version = "1.128.89", date = "22/11/2026",
        fixed = {
            "Statistiques de vol : les noms du départ et de l'arrivée sur la carte étaient peu lisibles (gris sur la carte claire) et coupés au bord ; ils sont clairs, cernés de noir et restent dans le cadre.",
        },
        changed = {
            "Statistiques de vol : les noms des persos dans les cartes (temps de jeu, plus grosse fortune, le plus campeur) sont à la couleur de leur classe.",
        },
    },
    {
        version = "1.128.88", date = "22/11/2026",
        changed = {
            "Recherche de groupe : le nombre total de groupes trouvés en tête de la liste des donjons ; « Mes demandes » a un vrai bouton « Vider » (avant, une petite corbeille peu visible avec le texte qui passait dessous).",
        },
    },
    {
        version = "1.128.87", date = "22/11/2026",
        changed = {
            "Un seul fond pour toutes les fenêtres et cadres à l'écran : le graphite du thème avec un liseré gris fin. Grandes fenêtres (statistiques de vol) opaques à 96 %, cadres posés sur le jeu (barre de vol, chrono et bilan du donjon, quêtes du donjon, barre des sacs, listes du kit et des buffs, barre d'XP, bandeau des quais) à 92 %. La barre de vol perd son fond gris clair et son contour rose ; la barre des sacs gagne le liseré ; la fenêtre des quêtes du donjon passe de 86 % à 92 % (si tu n'avais pas changé l'opacité).",
        },
    },
    {
        version = "1.128.86", date = "22/11/2026",
        changed = {
            "Recherche de groupe, liste des donjons : rangée en groupes repliables (Pour toi, Bientôt, Trop faciles, Plus tard ; les deux derniers repliés au départ, un clic sur le titre les ouvre). Chaque ligne a un trait et un niveau à la couleur de difficulté du jeu (gris, vert, jaune, orange, rouge), le nombre de groupes dans une pastille à droite ; le donjon choisi est surligné à la couleur de l'apparence.",
        },
    },
    {
        version = "1.128.85", date = "22/11/2026",
        changed = {
            "Kit de camp : la liste ne montre plus la nourriture « Bien nourri » ni la boisson ; seulement le feu, les objets de camp de tes métiers et le sac de couchage. La case « kit » ne signale plus « Bien nourri absent ».",
        },
    },
    {
        version = "1.128.84", date = "22/11/2026",
        changed = {
            "Recherche de groupe, « Mes demandes » : vidées toutes seules quand tu rejoins un groupe, et une petite corbeille en tête de liste pour tout vider à la main (avant, elles restaient 3 heures).",
            "Recherche de groupe : l'onglet « Récents » s'appelle « Joueurs croisés », avec une ligne qui explique les étoiles (3 = à refaire, 1 = en bas des listes et prévenu s'ils rejoignent ton groupe).",
        },
    },
    {
        version = "1.128.83", date = "22/11/2026",
        changed = {
            "Barre de vol : un seul cadre, affiché pendant tout le vol (avant : une petite pilule et un volet qui ne s'ouvrait qu'au survol). Trajet avec les relais, temps restant en gros, barre de progression, heures de départ et d'arrivée sur leur ligne (elles ne passent plus sous les boutons), « Atterrir » et « Statistiques ».",
        },
    },
    {
        version = "1.128.82", date = "22/11/2026",
        added = {
            "Statistiques de vol : six cartes de plus tirées des statistiques du jeu, additionnées sur tes persos : Créatures (tuées, la plus chassée, bestioles), Morts (dont en donjon, noyades, chutes), Richesse (argent gagné, plus grosse fortune, dépensé en voyages), Voyages (trajets aériens, pierre de foyer), Consommables (boissons, denrées, potions) et Campements (le plus campeur). Chaque perso est relu à sa connexion et au décollage : un perso pas encore reconnecté n'est pas compté.",
        },
    },
    {
        version = "1.128.81", date = "22/11/2026",
        added = {
            "/wk statsjeu : liste les statistiques de la fenêtre Statistiques du jeu que WoW Forever remplit vraiment pour ton perso (nom, valeur, catégorie), pour choisir celles à montrer dans les statistiques de vol.",
        },
    },
    {
        version = "1.128.80", date = "22/11/2026",
        fixed = {
            "Fenêtre des quêtes du donjon : la petite saccade en rendant une quête est corrigée (la fenêtre était refaite plusieurs fois de suite pendant la seconde qui suit un rendu ; elle ne l'est plus qu'une fois, et un journal qui n'a pas changé ne la refait plus).",
        },
    },
    {
        version = "1.128.79", date = "22/11/2026",
        added = {
            "Bilan du donjon à l'écran : en sortant, un bandeau en haut de l'écran pendant 5 s avec le nom du donjon, les boss tués, les morts, le temps et l'écart au record, l'XP et l'or gagnés. Un clic le ferme, il se place en mode édition. Réglage « Bilan à l'écran » dans la roue de la page Donjons (le résumé dans le chat reste réglable à part).",
        },
    },
    {
        version = "1.128.78", date = "22/11/2026",
        changed = {
            "Buffs à ne pas oublier : la liste se replie dès que tu cliques sur un sort, et les icônes des sorts déjà en place ne sont plus grisées.",
        },
    },
    {
        version = "1.128.77", date = "22/11/2026",
        changed = {
            "Chrono du donjon : la frise des boss devient une rangée de petites pastilles, une par boss (grise et pleine = tué, cerclée de la couleur de l'apparence = prochain, cerclée sombre = à venir), suivie de « 2 / 3 boss ». Plus lisible quand il y a beaucoup de boss : les pastilles rapetissent pour tenir sur la ligne.",
        },
    },
    {
        version = "1.128.76", date = "22/11/2026",
        changed = {
            "Chrono du donjon : même fond graphite et même liseré que les autres fenêtres à l'écran (avant, presque noir). La barre vide sous le titre devient une frise des boss : un segment par boss, gris quand il est tué, à la couleur de l'apparence pour le prochain (rouge si le record est dépassé), noms en petit dessous quand il y a la place. Option « Frise des boss » dans les réglages du chrono.",
        },
    },
    {
        version = "1.128.75", date = "22/11/2026",
        fixed = {
            "Erreur en boucle « secret string » des repères de quête sur les plaques de nom (QuestTracker.lua:17) : le jeu cache l'identifiant de certains monstres ; l'addon l'ignore maintenant. Même protection partout où l'addon lit l'identifiant d'une unité (PNJ de quête, recettes, persos).",
        },
    },
    {
        version = "1.128.74", date = "22/11/2026",
        fixed = {
            "Erreur en boucle « Auras cannot be accessed when secret » (buffs à ne pas oublier, bouton « Buffer le suivant ») : quand le jeu cache les effets (en combat surtout), l'addon ne les lit plus et garde la dernière lecture.",
        },
    },
    {
        version = "1.128.73", date = "22/11/2026",
        fixed = {
            "Erreurs Lua en boucle corrigées : « secret keys » du bouton « Buffer le suivant » (à chaque changement d'effet) et « secret string » du clic droit sur une pierre de rencontre. Le jeu cache certaines valeurs (identifiants, noms d'effets, infobulles) ; l'addon les ignore maintenant au lieu de s'en servir.",
        },
    },
    {
        version = "1.128.72", date = "22/11/2026",
        fixed = {
            "Buffs à ne pas oublier : un pistage allumé restait encore « éteint » (case rouge) ; il est maintenant reconnu par son nom ou son icône, pas seulement par le n° du sort que WoW Forever ne donne pas toujours.",
        },
        added = {
            "/wk pistage : ce que le jeu dit du pistage de la minicarte (pour comprendre un pistage mal reconnu).",
        },
    },
    {
        version = "1.128.71", date = "22/11/2026",
        fixed = {
            "Buffs à ne pas oublier : un pistage allumé (Découverte de gisements, d'herbes, Détection des morts-vivants…) restait marqué « éteint » et la case restait rouge : l'addon lisait mal la liste des pistages de WoW Forever. La case et la liste se mettent aussi à jour tout de suite après un sort ou un changement de pistage.",
        },
    },
    {
        version = "1.128.70", date = "22/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » du paladin en groupe : il juge la portée comme les lignes du panneau des bénédictions ; avant, quand le jeu ne donnait pas la portée du sort, il se limitait à 28 m et pouvait ne jamais proposer un joueur (le tank et ses Rois, par exemple) que la ligne du panneau bénissait.",
        },
    },
    {
        version = "1.128.69", date = "22/11/2026",
        changed = {
            "Recherche de groupe : les joueurs seuls sont rangés par rôle, en trois colonnes Tank / Soin / DPS avec un en-tête de couleur et leur nombre ; chaque ligne a un trait à la couleur du rôle, le nom à la couleur de classe, le niveau à droite et les autres rôles du joueur en petit (plus haut niveau d'abord). Fenêtre étroite : les rôles passent l'un sous l'autre.",
        },
    },
    {
        version = "1.128.68", date = "22/11/2026",
        added = {
            "Pierre de rencontre : un clic droit dessus ouvre la page LFG de l'addon.",
        },
        fixed = {
            "Barre des sacs : le kit de camp et la liste des buffs ne s'ouvrent plus en même temps l'un sur l'autre ; ouvrir l'un replie l'autre.",
        },
    },
    {
        version = "1.128.67", date = "22/11/2026",
        added = {
            "Barre des sacs : la case des buffs se met en avant quand un buff manque (fond rouge et liseré qui respire), hors combat et hors des villes. Réglage « Mettre en avant un buff absent » dans la carte de la barre.",
        },
        fixed = {
            "Buffs à ne pas oublier : la liste montre l'aura que tu as vraiment (Vindicte, par exemple) au lieu de la première connue ; sans aura, c'est Dévotion qui est proposée. Les sorts appris à un rang plus haut (Dévotion, Robustesse…) sont bien reconnus.",
        },
    },
    {
        version = "1.128.66", date = "22/11/2026",
        fixed = {
            "Recherche de groupe : le message automatique écrivait le nom de la zone en français pour une activité de zone (« Excavations : les Paluns ») ; il est maintenant en anglais (« Excavations: Wetlands »), comme les donjons.",
        },
    },
    {
        version = "1.128.65", date = "22/11/2026",
        changed = {
            "Listes déroulées de la barre des sacs (kit de camp, buffs) : plus de cadre coloré autour des icônes ni autour de la liste des buffs, plus sobre.",
        },
    },
    {
        version = "1.128.64", date = "22/11/2026",
        added = {
            "Barre « Sacs, marchand et maître » : taille, opacité, fond (sans fond, chiffres cernés de noir) et traits entre les cases réglables.",
        },
        changed = {
            "Tous les réglages de la barre « Sacs, marchand et maître » sont réunis dans une seule carte (QoL > Général > Marchand) : apparence, cases (sac, marchand, maître, kit de camp, buffs) et un seul sens pour les listes déroulées du kit et des buffs. Les cartes du kit de camp et des buffs y renvoient par un bouton.",
        },
    },
    {
        version = "1.128.63", date = "22/11/2026", restart = true,
        added = {
            "Buffs à ne pas oublier : une case « buffs » dans la barre « Sacs, marchand et maître » compte les buffs de ta classe, de ta race et les pistages de métier qui manquent là où tu es (monde, donjon, raid) ; un clic déroule la liste (absent, temps restant, ok) et un clic sur une ligne lance le sort, hors combat. Par exemple : une aura et Détection des morts-vivants en donjon pour le paladin, Découverte de gisements en monde ouvert.",
            "QoL > Classes > Général : carte « Buffs à ne pas oublier » (case dans la barre, déroulé vers le bas ou le haut, et pour chaque buff les lieux où il est demandé).",
        },
    },
    {
        version = "1.128.62", date = "22/11/2026",
        changed = {
            "Fenêtre des quêtes du donjon refaite, plus lisible et plus compacte : pastilles « en cours » et « à prendre » en haut, niveau de chaque quête devant son nom, fine barre d'avancée sous chaque quête du journal, quêtes à prendre en doré sous un trait (l'XP est dans l'infobulle du titre).",
            "Kit de camp dans la barre « Sacs, marchand et maître » : une case « kit » (temps restant des avantages du camp, en orange si « Bien nourri » manque) ; un clic déroule la liste du kit avec le nom et l'état de chaque objet (recharge, Bien nourri, prêt), hors combat. Remplace la colonne et les pastilles sous la flamme.",
        },
        added = {
            "QoL > Feu de camp > Kit de camp : « Dans la barre des sacs » (sinon l'ancienne colonne près de la flamme) et « Déroulé du kit » vers le bas ou vers le haut.",
        },
    },
    {
        version = "1.128.61", date = "22/11/2026",
        changed = {
            "Fenêtre des quêtes du donjon : elle ne s'affiche plus que dans le donjon, avec ses quêtes (avant aussi près de l'entrée, en « Toujours » ou ouverte depuis la page Donjons, avec les quêtes d'une autre zone). Réglage : « Dans le donjon » ou « Jamais ».",
            "Fenêtre des quêtes du donjon : plus de bandeau « Tournée » en bas ni de poignée pour la redimensionner ; elle prend la hauteur de son contenu (la molette fait défiler au-delà).",
        },
    },
    {
        version = "1.128.60", date = "21/11/2026",
        fixed = {
            "Hôtel des ventes : la liste « File de fabrication » ne redemande plus un objet que tu viens d'acheter (avant, la ligne revenait tant que le courrier n'était pas pris et l'objet pouvait être racheté).",
            "Hôtel des ventes : un achat fait avec les boutons de la fenêtre du jeu n'est plus compté pour l'objet que l'addon attendait ; « Tout acheter » ne double plus un achat isolé en cours ; quelques erreurs Lua à l'achat corrigées.",
            "Marchand : le « Réassort » ne rachète plus toute la quantité à chaque clic (le nombre déjà en sac n'était pas lu), et la proposition « Amélioration à porter » s'affiche de nouveau.",
            "Objets verrouillés : un objet verrouillé à la main garde son verrou pendant qu'il est en vente à l'hôtel des ventes.",
            "Guidage : le trajet est recalculé si tu ne prends pas ta pierre de foyer ou le vol prévu, ou si tu te poses loin du relais prévu (avant, il restait bloqué sur cette étape).",
            "Points /way : avec l'ordre « au plus près », arriver à un point passe bien au suivant ; une file mise en pause ne repart plus après un /reload ; au-delà de 50 points, c'est le plus ancien qui part ; un point partagé au groupe n'envoie plus de codes de couleur ; les points sont au bon endroit sur la carte d'Azeroth.",
            "Guidage : tes propres repères et les quêtes suivies ne sont plus effacés à la fin d'un guidage, l'épingle ne se colle plus à un autre point que celui de l'addon, et un repère laissé par un /reload en plein guidage est retiré.",
            "Bénédictions : une ligne de la barre ne reste plus bloquée sur un joueur hors de portée ; les joueurs partis du groupe ne sont plus gardés en mémoire.",
            "Donjons : le parcours partagé donne le bon chrono même une fois le donjon fini ; les boss facultatifs ne comptent plus dans « x/y boss » (un donjon fini n'affiche plus 5/6) ; la fenêtre des quêtes du donjon ne relit plus tout le journal toutes les 2 s.",
            "Plans de talents : supprimer un plan pendant qu'on en modifie un autre ne fait plus modifier le mauvais plan.",
            "Profils : changer de profil sans recharger ne fait plus perdre les réglages modifiés juste après.",
            "Les boutons « Recharger » de la fenêtre ouverte pendant un combat fonctionnent une fois le combat fini.",
            "Métiers : un lien de métier d'un autre joueur reposté dans le chat n'est plus enregistré comme le tien ; le panneau de désenchantement fermé en combat n'avale plus les clics.",
            "Quêtes : les repères des plaques de nom ne relisent plus le journal chaque seconde et ne chargent plus les données à la connexion quand le préchargement est coupé ; une quête apprise puis supprimée disparaît partout ; plus de pastille fantôme sur les quêtes absentes de la base.",
            "Divers : feu de camp sans erreur quand le jeu masque une valeur ; noms d'herbes complets dans l'infobulle de la minicarte ; version de WoW de nouveau dans le rapport d'erreurs ; noms en cyrillique lisibles et couleurs du thème dans les infobulles Amis / Guilde ; moins de mémoire gardée par le bouton Buffer et la session de farm.",
        },
    },
    {
        version = "1.128.59", date = "21/11/2026",
        changed = {
            "Fiche, onglet Armes, « À apprendre » : chaque arme a son maître d'armes le plus proche qui l'enseigne (nom, zone, distance) et une pastille « Guider » vers lui. Avant, un seul maître pour toutes les armes, alors que chacun n'enseigne que certaines armes.",
        },
    },
    {
        version = "1.128.58", date = "21/11/2026",
        fixed = {
            "Micro menu, raccourci « Héritages » : une erreur Lua du journal des collections (« GetPageTitleText ») ; le n° d'onglet donné par le jeu n'existe pas sur WoW Forever. L'onglet est maintenant cherché par son nom dans la barre d'onglets du journal.",
        },
    },
    {
        version = "1.128.57", date = "21/11/2026",
        fixed = {
            "Guidage : un vol n'était envisagé que depuis le maître de vol connu le plus proche (par exemple Thelsamar depuis l'est des Paluns), et seulement si les deux relais étaient très près du départ et de l'arrivée ; sinon tu marchais jusqu'à Forgefer. Les 3 relais connus les plus proches du départ et de l'arrivée sont maintenant comparés, et le vol le plus rapide est proposé s'il bat la marche (durée réelle du vol quand tu l'as déjà fait).",
        },
    },
    {
        version = "1.128.56", date = "21/11/2026",
        fixed = {
            "Micro menu : le raccourci « Héritages » ouvrait les Apparences ; il ouvre bien l'onglet des héritages du journal des collections.",
            "Carte du monde, vue du continent ou d'une zone parente : le losange de destination du jeu restait affiché pendant un guidage. Notre épingle y est maintenant posée (à la place du losange), comme sur la carte de la zone.",
        },
    },
    {
        version = "1.128.55", date = "21/11/2026",
        changed = {
            "Ménage dans le code : une vingtaine de fonctions que plus rien n'appelait (restes de la tournée, du guide de montée, des quêtes automatiques et d'anciennes versions des pages) et une quarantaine de variables jamais lues sont retirées. Rien ne change en jeu.",
            "Données à la demande plus légères (env. 150 Ko de moins) : noms des monstres des objectifs, marchands des objets de quête et objets qui démarrent une quête ne sont plus chargés (plus rien ne les lisait).",
        },
    },
    {
        version = "1.128.54", date = "21/11/2026",
        fixed = {
            "Plans de talents : « Importer un code » refusait des codes valables (« code non reconnu ») quand ils étaient collés avec des espaces, un retour à la ligne, des couleurs ou des crochets du chat, ou exportés avant que la classe soit connue. Un code de build (WK1:…) y est aussi accepté et devient un plan.",
        },
        changed = {
            "Alt + clic sur une quête du suivi retiré (et /wk suivi) : les lignes « Guider vers la quête » et « Chercher un groupe » sont dans le menu du clic droit d'EllesmereUI.",
        },
    },
    {
        version = "1.128.53", date = "21/11/2026",
        fixed = {
            "Style Héraldique : les titres des cartes étaient invisibles, recouverts par le bandeau de couleur ; ils sont de nouveau écrits en blanc par-dessus.",
        },
    },
    {
        version = "1.128.52", date = "21/11/2026",
        fixed = {
            "Options > Apparence : choisir un style qui met les jauges en dégradé (Héraldique…) déclenchait une erreur Lua (« SetColorTexture ») ; la 2e couleur du dégradé était incomplète.",
        },
    },
    {
        version = "1.128.51", date = "21/11/2026",
        fixed = {
            "Quêtes, liste d'une zone : une quête de groupe affichait « GROUPE » devant le titre et encore « groupe » sur la 2e ligne ; il n'apparaît plus qu'une fois, devant le titre.",
        },
    },
    {
        version = "1.128.50", date = "21/11/2026",
        changed = {
            "Quêtes, liste d'une zone : NOUVELLE / APPRISE / CORRIGÉE devient une petite pastille arrondie après le titre (avant, un mot en couleur plus gros que le titre de la quête) ; un titre long est coupé avant la pastille.",
        },
    },
    {
        version = "1.128.49", date = "21/11/2026",
        fixed = {
            "Fiche, onglet Armes : toujours « apprise » sans le niveau. Sur WoW Forever, la fenêtre des compétences passe par une autre interface du jeu (C_SkillInfo) que celle que l'addon lisait ; le vrai niveau de chaque arme (65 / 150, 148 / 150…) est maintenant lu. « /wk armes » montre aussi les champs lus.",
        },
    },
    {
        version = "1.128.48", date = "21/11/2026",
        fixed = {
            "Fiche, onglet Armes : le vrai niveau de chaque arme (1 / 150, 65 / 150…) s'affiche au lieu de « apprise » : le jeu écrit « Epées » sans accent et « Masse » au singulier, et ces lignes n'étaient pas reconnues.",
        },
    },
    {
        version = "1.128.47", date = "21/11/2026",
        fixed = {
            "Pastilles sous la flamme du feu de camp : « Bien nourri absent » restait sur une seule ligne ; il passe bien sur deux lignes.",
        },
    },
    {
        version = "1.128.46", date = "21/11/2026",
        fixed = {
            "Icône du feu de camp : le compte à rebours de la minute assise était caché sous le voile qui tourne ; il est maintenant au-dessus, plus gros et cerné de noir.",
        },
        changed = {
            "Pastilles sous la flamme : « Bien nourri absent » sur deux lignes, plus compact.",
        },
    },
    {
        version = "1.128.45", date = "21/11/2026",
        changed = {
            "Feu de camp : l'encart « Feu de camp à proximité » faisait doublon avec l'icône de flamme ; il est coupé, seule la flamme reste (clic pour s'asseoir). Il se remet dans QoL > Feu de camp, « Encart près d'un feu de camp ».",
        },
    },
    {
        version = "1.128.44", date = "21/11/2026",
        fixed = {
            "Fiche, onglet Armes : les armes apprises n'étaient pas reconnues (« comme si rien n'était appris ») : le jeu nomme « Haches », « Épées », « Masses »… les armes à une main, et une rubrique repliée dans la fenêtre des compétences cachait ses lignes. Une arme connue seulement par le grimoire est marquée « apprise ». « /wk armes » dit ce qui a été lu.",
            "Menu Échap avec EllesmereUI : le bouton « Warband Keeper » avait un fond plus foncé que ses voisins ; il prend maintenant la couleur de fond, le liseré et la couleur du texte réglés dans EllesmereUI.",
        },
    },
    {
        version = "1.128.43", date = "21/11/2026",
        fixed = {
            "Vols : un /reload en plein vol faisait perdre le vol en cours (barre, temps restant, statistiques) jusqu'à l'atterrissage ; il est maintenant repris.",
            "Déplacements : quand le calcul du réseau de chemins échouait, il était relancé une deuxième fois tout de suite ; l'itinéraire passe directement en ligne droite.",
            "Infobulles (bénédictions, points sur la carte, flèche) : certaines lignes passaient à la ligne sans raison.",
            "Banque : le nombre d'objets d'une case était lu juste après le dépôt au lieu d'avant, ce qui pouvait fausser la vérification.",
            "Courrier : le bouton « Tout prendre » pouvait rester sur « Récupération... » après la fermeture de la boîte.",
            "Quêtes de donjon : le journal était relu deux fois de suite quand une quête était rendue.",
        },
    },
    {
        version = "1.128.42", date = "21/11/2026",
        fixed = {
            "Mode édition : un élément coupé pendant l'édition (par exemple l'encart du feu de camp) gardait son aperçu et restait bloqué jusqu'au /reload.",
            "Bénédictions : les familiers du groupe passaient dans le suivi des effets et faisaient grossir ses tables ; un message pour PallyPower jeté (file pleine) était cru envoyé et n'était pas renvoyé pendant 15 s.",
            "Bénédictions : un changement du groupe en plein combat refaisait la répartition et les messages tout de suite ; c'est fait à la sortie du combat.",
            "Bouton « Buffer le suivant » : en raid, ce qu'il avait lu des effets était effacé toutes les minutes environ ; seules les lectures de plus de 30 s sont maintenant retirées.",
            "Donjons : l'état du donjon était lu deux fois à chaque changement de vie suivi (cible, boss, plaques).",
        },
    },
    {
        version = "1.128.41", date = "21/11/2026",
        fixed = {
            "Hôtel des ventes : un achat resté sans réponse du jeu bloquait tous les suivants jusqu'à la fermeture. Il est abandonné au bout de 10 s (20 s pour une confirmation) avec un message ; la liste d'achat garde son avancée.",
            "Banque : fermée puis rouverte très vite, deux dépôts partaient en même temps ; l'ancien s'arrête maintenant net.",
            "Courrier : un envoi fait à la main n'était pas compté au destinataire si tu fermais la boîte avant la confirmation du jeu. Il l'est, une fois vérifié que les objets ont bien quitté tes sacs.",
            "Marchand : sa fenêtre fermée juste après l'ouverture n'était vue fermée qu'au bout de 1,5 s (vente des gris, rachat, caches) ; c'est maintenant immédiat une fois la fenêtre affichée.",
        },
    },
    {
        version = "1.128.40", date = "21/11/2026",
        changed = {
            "Bandeau des bateaux au quai : plus d'eau ni de vagues, fond graphite plus clair, frise en pointillés fins (ton quai en bleu, la prochaine escale en vert).",
            "Bandeau des bateaux : il apparaît dès que tu avances sur le ponton (55 m du point d'arrêt du navire, au lieu de 30 m tout au bout), avant l'arrivée du bateau. Réglable dans QoL > Carte et guidage.",
        },
    },
    {
        version = "1.128.39", date = "21/11/2026",
        fixed = {
            "« Chercher un groupe (chat) » déclenchait une erreur « action bloquée » (le jeu interdit aux addons d'écrire dans un canal public). Le message s'ouvre maintenant prêt dans le canal /1 : Entrée pour l'envoyer.",
        },
    },
    {
        version = "1.128.38", date = "21/11/2026",
        changed = {
            "« Chercher un groupe (chat) » envoie le message tout de suite dans le canal /1 (si le jeu le refuse, la boîte de discussion s'ouvre réglée sur /1).",
        },
    },
    {
        version = "1.128.37", date = "21/11/2026",
        changed = {
            "Liens wowhead retirés : plus de fenêtre du lien, de Maj + clic sur une quête, de ligne « Lien wowhead » dans le menu des quêtes ni de carte « Liens wowhead » dans la roue des Quêtes.",
        },
    },
    {
        version = "1.128.36", date = "21/11/2026",
        added = {
            "Suivi des quêtes d'EllesmereUI : « Guider vers la quête » et « Chercher un groupe (chat) » en bas de son menu du clic droit (son « Lien Wowhead » reste le sien). Alt + clic reste pour le suivi du jeu.",
        },
    },
    {
        version = "1.128.35", date = "21/11/2026",
        added = {
            "Options > Fiabilité > Données : la mémoire réellement utilisée, lue dans le jeu (l'addon, et les données à la demande une fois chargées), avec une barre et un bouton « Mesurer ».",
        },
        fixed = {
            "Options > Fiabilité > Données : le préchargement disait encore « si une quête est suivie » ; il se fait si ton journal a des quêtes et que les repères des plaques de nom sont actifs.",
        },
    },
    {
        version = "1.128.34", date = "21/11/2026", restart = true,
        changed = {
            "Quêtes automatiques retirées (prendre et rendre en parlant au PNJ, choix de la récompense, achat sans clic, exceptions) : Polestar s'en charge. Le bouton « Pour tes quêtes » sous la fenêtre du marchand reste, sur clic.",
            "Réglages des quêtes : un seul onglet ; le menu d'une quête n'a plus « Jamais d'automatique ».",
        },
    },
    {
        version = "1.128.33", date = "21/11/2026",
        fixed = {
            "Alt + clic sur une quête du suivi (EllesmereUI ou celui du jeu) : le menu de la quête ne s'ouvrait pas. La quête est maintenant reconnue sous la souris, par son n° ou par son titre ; /wk suivi dit ce qui a été vu au dernier Alt + clic.",
        },
    },
    {
        version = "1.128.32", date = "21/11/2026",
        added = {
            "Suivi des quêtes d'EllesmereUI (ou celui du jeu) : Alt + clic sur une quête ouvre le menu de la quête (guider, lien wowhead, chercher un groupe, jamais d'automatique). Les autres clics restent ceux du suivi. Réglage dans la roue des Quêtes, /wk suivi pour vérifier.",
        },
        changed = {
            "Plus de « quête suivie » dans l'addon (le journal du jeu le fait) : « Guider vers la quête » mène au camp le plus proche ou au rendu ; les repères des plaques de nom valent pour toutes les quêtes du journal.",
            "Menu des quêtes (clic droit) : « Jamais d'automatique » / « Réautoriser l'automatique » remplacent le bouton « Exclure la quête suivie ».",
            "Quêtes : la légende des couleurs est sous la liste des quêtes d'une zone (la carte « Légende » des réglages est retirée).",
            "Apparence allégée : restent Styles, Couleur d'accent, Police, Taille du texte et l'onglet Fenêtre ; les réglages fins (dégradé, teinte, accent par perso, halo, police des titres, contraste, arrondi, style des cartes, fond, animation) sont retirés, les styles s'en chargent.",
            "Infobulles : deux cartes au lieu de cinq (« Objets », « PNJ et apparence »).",
            "Rappels à la connexion : réglés seulement dans QoL > Général > Alertes.",
        },
    },
    {
        version = "1.128.31", date = "21/11/2026", restart = true,
        changed = {
            "Quêtes : l'onglet « Carte des zones » s'appelle « Zones de quêtes ».",
            "Carte du monde et minicarte : les zones de quête (taches de couleur), les repères de rendu et le volet « Quêtes du journal » sont retirés ; les repères de quête du jeu reviennent (ceux que l'addon masquait sont rendus).",
            "Réglages des quêtes : la carte « Zones des objectifs » et les réglages de carte de « Quête suivie » sont retirés.",
        },
        fixed = {
            "Statistiques de vol : la flèche et la partie faite du trajet ne se décalent plus ; elles suivent ta vraie position sur le tracé (avant, la partie faite avançait selon le temps, plus vite que l'appareil au décollage).",
        },
    },
    {
        version = "1.128.30", date = "21/11/2026", restart = true,
        changed = {
            "Quêtes allégées : la page garde seulement « Carte des zones » et « Journal ». « Ma progression » est retirée (montée en niveaux, mon journal, quêtes de ma zone, tournée de quêtes), avec les cases et le bouton « Envoyer dans Ma progression » de la carte des zones.",
            "Retirés aussi : la carte de quête à l'écran, la barre « Quête » (Cibler / Objet) et ses raccourcis, la flèche automatique vers les zones de quête, et les pastilles posées dans le suivi des quêtes du jeu.",
            "Suivre une quête ne lance plus de flèche : ses zones restent sur la carte ; un clic sur une zone, un donneur ou « guider » guide une fois, comme un lieu.",
            "Quêtes automatiques en mode assisté : elles prennent les quêtes de ton niveau (réglage « Niveaux au-dessus du tien » dans les détails).",
            "Repères sur les plaques de nom : pour les monstres de toutes les quêtes du journal (la quête suivie à ses couleurs).",
            "Quêtes d'un donjon : « Tournée » guide de donneur en donneur, sans passer par une tournée de quêtes.",
        },
    },
    {
        version = "1.128.29", date = "21/11/2026",
        fixed = {
            "Points /way : un point posé là où tu es (/way seul, Ctrl + clic à tes pieds) ne disparaît plus tout de suite comme « arrivé » ; il compte une fois que tu t'en es éloigné de 25 m.",
        },
    },
    {
        version = "1.128.28", date = "21/11/2026",
        changed = {
            "Carte de quête à l'écran : trois choix (Tournée, Toujours, Jamais). Par défaut « Tournée » : la carte n'apparaît que pendant une tournée ou le guide de montée, plus pour une quête suivie seule (le journal du jeu le fait déjà).",
            "Arrêter ou vider la tournée lâche aussi la quête suivie : sa carte, ses zones sur la carte du monde et sa flèche disparaissent.",
            "/wk tournee : dit pour chaque quête du journal si elle est dans la tournée, et sinon pourquoi.",
        },
        fixed = {
            "Tournée : une quête prête dont le rendu est dans un hameau ou une grotte de la zone n'était pas comptée dans la tournée.",
            "Tournée d'une autre zone sans rien à faire : la zone choisie restait retenue et les tournées suivantes la visaient encore ; les quêtes de ton journal ne sont plus décochées par ce choix.",
        },
    },
    {
        version = "1.128.27", date = "21/11/2026",
        fixed = {
            "Mort pendant un point /way : le guidage d'avant le /way n'est plus perdu ; il revient une fois en vie.",
            "Guide de montée : une étape que tu as arrêtée n'est plus relancée toute seule tant qu'elle ne change pas.",
            "Tournée de quêtes : les étapes passées restent passées quand le guide relance la tournée ou après le bilan.",
            "Points /way : un guidage arrêté à la main met la file en pause au lieu d'être relancé ; l'arrivée sur un point n'arrête plus le guidage avant le point suivant.",
            "Quêtes automatiques : une quête journalière, hebdomadaire ou répétable n'est plus acceptée seule.",
            "Hôtel des ventes : un équipement est cherché avec la bonne clé d'objet ; la vente rapide prend le prix de l'objet posé (et non d'une autre variante).",
            "Hôtel des ventes : le prix d'un équipement n'est plus faussé par un lot très bas ou très haut ; la page Parcourir ne fausse plus la courbe du jour.",
        },
    },
    {
        version = "1.128.26", date = "21/11/2026",
        fixed = {
            "Statistiques de vol : fermées pendant un vol, elles ne réapparaissent plus à chaque ouverture de la carte jusqu'à l'atterrissage.",
            "Trajet : un réseau des chemins en échec donne une ligne droite pendant 60 s au lieu d'être reconstruit à chaque calcul ; le tracé d'un vol est refait à l'ouverture de la carte des vols et à l'atterrissage.",
            "Guide de montée : « Passer » sur « Tournée en cours » passe l'étape de la tournée (au lieu de cacher la ligne pour la séance) ; les quêtes de n° 100 ou moins sont aussi chronométrées.",
            "Sorts de classe et dialogues : le catalogue n'est plus relu à chaque changement de forme ; le premier dialogue avec un PNJ ne charge plus le dossier de données.",
            "Hôtel des ventes : un équipement est cherché avec la clé de l'exemplaire de tes sacs ; une confirmation d'achat déjà partie n'est plus redemandée au même prix (double achat possible).",
            "Marchand : un achat (réassort, métiers, quêtes) vérifie que la ligne est toujours le bon objet avant d'acheter.",
            "Banque : une case visée n'est libérée qu'une fois le dépôt arrivé.",
            "Bénédictions : un changement d'effet reçu dans la même image que la lecture n'est plus ignoré ; voleur : le rappel de poison marche dès la première connexion.",
            "Invitations et duels : la liste de guilde est demandée à la connexion et toutes les 5 minutes même micro menu coupé (un nouveau membre est reconnu).",
            "Donjons : moins d'appels au jeu sur la vie des membres du raid ; chasseur : plus de relevé de l'équipement à chaque tir en combat.",
            "Feu de camp : un changement pendant le mode édition est rejoué à la sortie, et l'encart a son « Tester » ; module Rares coupé : plus rien n'est noté ; barre de pêche : macro posée seulement si elle change.",
            "/wk perf terminé en combat : les mesures sont retirées à la sortie du combat ; Nettoyer : un ancien minuteur ne désarme plus un armement récent ; quelques textes gris et le message d'erreur suivent l'apparence.",
        },
    },
    {
        version = "1.128.25", date = "21/11/2026",
        fixed = {
            "Vente rapide (fenêtre du jeu) et Mes enchères : un appât isolé n'est plus pris pour le prix le plus bas ; une recherche sans réponse affiche « à vérifier » au lieu de « la plus basse ».",
            "Courrier et banque : une pile qui a fondu depuis le plan garde la quantité prévue (avant, elle partait entière malgré « garder »).",
            "Courrier : une fermeture de la boîte non signalée ne bloque plus les envois suivants ; un objet joint puis retiré n'est plus compté dans la boîte du destinataire.",
            "Page Métiers : le bouton « Ouvrir le métier » est aussi désancré à l'entrée en combat (déplacer ou fermer la fenêtre en combat ne bloque plus) ; son infobulle suit la page affichée.",
            "Bouton Buffer (druide, prêtre, mage) : les effets d'un joueur ne sont relus que quand ils changent, ou toutes les 10 s (avant : tous les effets de tout le raid chaque seconde).",
            "Bénédictions : une nouvelle répartition reçue en combat est appliquée à la sortie du combat (avant, des lignes de la barre restaient figées sur l'ancien sort).",
        },
    },
    {
        version = "1.128.24", date = "21/11/2026",
        fixed = {
            "Points /way : une file interrompue (retour au corps, détour chez un marchand…) reprend d'elle-même ensuite ; avant, plus rien ne la guidait.",
            "Guidage : rien ne reprend tant que tu es fantôme (le retour au corps revient) ; le guidage gardé avant un /way n'est plus écrasé par le retour au corps ; sur la carte du continent, le repère du jeu ne disparaît plus au bout d'une seconde.",
            "Guide de montée : il ne reste plus bloqué après la fin d'une tournée de zone ; seule la visite d'un maître de classe compte pour l'étape « Maître de classe » (plus un maître d'armes ou de familiers) ; il n'est plus recalculé à chaque mise à jour du journal en combat.",
            "Tournée : passer une étape « faire » ne retire plus que ses camps (avant, tous ceux de la quête, et son rendu bloquait) ; les étapes passées sont oubliées à la fin de la tournée.",
            "Chaînes apprises : la chaîne « débloquée par un rendu » est bien apprise chez le PNJ qui reçoit le rendu.",
            "Quêtes automatiques : les journalières et hebdomadaires ne sont plus prises au dialogue non plus, avec un test de fréquence fiable sur tous les clients.",
            "Hôtel des ventes : une recherche ne fait plus d'un appât à 1 pc le cours de l'objet ; seul un scan donne le cours, et la courbe du jour ne garde que le prix sans appâts.",
            "Vente des gris : arrêtée dès que le marchand n'est plus là, même si sa fermeture n'a pas été signalée (un objet gris aurait pu être équipé).",
            "Objets verrouillés : le marchand n'est plus cru fermé à l'instant de son ouverture (rachat et caches restaient coupés).",
            "Paladins : un réglage remis à sa valeur d'avant part bien aux autres ; l'écoute des effets ne concerne plus que le paladin et son groupe.",
        },
    },
    {
        version = "1.128.23", date = "21/11/2026",
        changed = {
            "Plus léger en farm : une carte de récoltes pleine est élaguée par lots, plus à chaque butin ; les tracés des navires ne sont plus reprojetés à chaque redessin de la carte, et la carte n'est plus redessinée deux fois à l'arrêt d'un guidage.",
            "Minicarte : le trajet guidé et les camps de quête coûtent moins (points gardés, textures posées une fois, camps 5 fois par seconde au lieu de 10).",
            "Tournée de quêtes : l'aperçu n'est plus recalculé tous les quelques pas (position à 20 % de la carte près).",
            "Sorts de classe : seuls les sorts dont le nom manque sont relus, au lieu de tout le catalogue à chaque appel.",
            "Bouton Buffer et barre des bénédictions : noms des sorts gardés, effets d'un membre relus seulement quand ils changent (ou toutes les 10 s), macro posée seulement si elle change, rien quand le bouton est coupé.",
            "Prêtre, paladin, druide : la vérification des buffs de groupe toutes les 15 s, qui ne servait plus depuis le retrait des rappels à l'écran, est arrêtée ; plusieurs évènements n'écoutent plus que ton perso (pêche, fiche, sorts).",
            "Objets verrouillés : le nettoyage des verrous lit seulement la présence des objets ; courrier et banque : le nombre d'objets à envoyer ou déposer est gardé tant que les sacs ne changent pas.",
            "Couleurs : plusieurs textes et pastilles suivent maintenant l'apparence (infobulle des donneurs de quêtes, alertes, fiche du perso, bénédictions, rachat).",
        },
    },
    {
        version = "1.128.22", date = "21/11/2026",
        fixed = {
            "Courrier : « Prendre » sur une lettre est refusé si la liste a changé entre-temps (lettre supprimée, liste pas encore repeinte) ; avant, la lettre voisine était prise.",
            "Farm : un sac remplacé pendant la séance ne compte plus comme butin.",
            "Banque : une case remplie par le dépôt précédent est libérée dès l'arrivée de l'objet (moins de piles partielles, banque plus dite pleine trop tôt).",
            "/wk perf : à la fin de la mesure, seules nos propres enveloppes sont retirées ; un script changé pendant la mesure n'est plus écrasé.",
            "Options > Fiabilité, Nettoyer : cocher une autre case après le premier clic désarme le bouton (nouvelle confirmation avec le bon montant).",
            "« Recharger maintenant » demandé pendant un combat fonctionne dès la sortie du combat.",
            "Page Métiers : le bouton « Ouvrir le métier » n'est plus recréé à chaque changement de thème, de police ou de langue.",
        },
    },
    {
        version = "1.128.21", date = "21/11/2026",
        fixed = {
            "Chaînes de quêtes apprises : une quête débloquée n'est plus liée au dernier rendu quand plusieurs quêtes ont été rendues entre-temps.",
            "Quêtes grises (bien sous ton niveau) : plus notées « pas encore proposée » quand le jeu les cache ; elles ne disparaissent plus de la tournée « Compléter la zone ».",
            "Quête suivie : en changeant de zone, la flèche va bien au camp le plus proche au lieu de garder l'ancien.",
            "Barre Quête : après un test du mode édition fini en combat, Cibler et Objet remarchent dès la sortie du combat.",
            "Tournée : un seul recalcul après le rendu d'une quête à suite (il y en avait deux, dont un même en pause) ; guide de montée : une étape « tournée de la zone » passée ne revient plus pour une quête cochée de plus ; temps réels des quêtes notés quel que soit le client.",
            "Quêtes automatiques : chez un PNJ sans dialogue, les journalières et répétables ne sont plus prises.",
            "Feu de camp : l'encart, l'icône et le kit ne disparaissent plus pendant un combat près du feu ; à la sortie du mode édition, le son n'est plus joué deux fois.",
            "Paladins : un même message n'est plus renvoyé au groupe avant 15 s, et l'état des autres n'est demandé qu'à l'arrivée d'un paladin inconnu (moins de messages perdus en raid).",
            "Mode édition : les bandeaux de rare ne s'affichent que si l'alerte est active et pour le style choisi, avec le nom en français ; micro menu coupé : la liste de guilde n'est plus redemandée chaque minute.",
        },
    },
    {
        version = "1.128.20", date = "21/11/2026",
        fixed = {
            "Guidage : à la fin d'une file /way ou d'un retour au corps, le guidage d'avant (marchand, boîte aux lettres…) revient toujours, tout de suite ; avant, la quête suivie passait parfois devant, et après la mort le guidage d'avant était perdu. Rien ne reprend tant que tu es fantôme.",
            "Guidage : un /way posé en fantôme ne te renvoie plus à ton corps une fois la file finie ; une étape de tournée gardée est recalculée au retour au lieu de revenir telle quelle.",
            "Points /way : plus de bandeau « Arrivé » ni de son à chaque point intermédiaire d'une file.",
            "Carte du monde : sur le continent ou une zone parente, le repère de la destination reste visible (avant, ni le nôtre ni celui du jeu).",
            "Trajet : un recalcul raté (écart du chemin, position illisible un instant en ville) garde le bon trajet au lieu de l'effacer ; une cible rendue repart avec tous ses nouveaux essais.",
            "Retour au corps : le bandeau de secours se met à jour même caché ; réseau des chemins : une erreur de construction est notée au journal et n'est plus relancée en boucle.",
            "Statistiques de vol : elles s'affichent par-dessus la carte au lieu de la fermer (fermer une fenêtre du jeu depuis l'addon pouvait causer une action bloquée plus tard).",
        },
    },
    {
        version = "1.128.19", date = "21/11/2026",
        fixed = {
            "Courrier : un envoi fait à la main (notre fenêtre ou celle du jeu) compte maintenant dans la boîte du destinataire et le journal ; un objet verrouillé envoyé à un reroll ne perd plus son verrou.",
            "Hôtel des ventes, « Tout acheter » : un objet sans cours connu (jamais scanné) demande un clic de plus pour un achat d'au moins 100 po ou d'un dixième de ton or.",
            "Objets verrouillés : si la fermeture du marchand n'est pas signalée par le jeu, elle est rattrapée (caches retirés des cases, rachat et nettoyage débloqués).",
            "Rachat automatique : le relevé du rachat est refait un instant après l'ouverture s'il était vide, et rien n'est racheté avant ; un objet vendu à une visite précédente n'est plus pris pour une vente de cette visite.",
            "Mes enchères : un équipement est cherché avec sa clé exacte (niveau d'objet) ; une recherche sans résultat lisible affiche « à vérifier » au lieu de « la plus basse ».",
            "Recherche : après une page en échec, l'index incomplet n'est plus enregistré aux frappes suivantes.",
        },
    },
    {
        version = "1.128.18", date = "21/11/2026",
        changed = {
            "Données mises à jour depuis QuestieDB, Everloot, wago.tools, wowtbc.gg, What's Training et opendata : 1 quête de plus.",
        },
    },
    {
        version = "1.128.17", date = "21/11/2026",
        fixed = {
            "Hôtel des ventes : plusieurs petits lots-appâts à des prix différents ne faussent plus le cours (avant, un seul appât était reconnu) ; le garde-fou de mise en vente regarde aussi la moyenne des 7 derniers jours.",
            "Hôtel des ventes, Vendre : un objet verrouillé (épique, envie, BiS, recette…) demande toujours une confirmation avant la mise en vente, et « suivant » ne passe plus dessus.",
            "Hôtel des ventes, achat de marchandise : changer la quantité (ou cliquer une autre ligne) entre la demande de prix et la confirmation annule l'ancienne demande ; avant, la confirmation achetait l'ancienne quantité. Le bouton indique « Confirmer N pour X ».",
            "Désenchanter le suivant : le bouton est désarmé à l'entrée en combat et réarmé après ; un objet arrivé dans la case pendant le combat ne peut plus être désenchanté, même depuis un panneau fermé.",
            "Vente des gris : chaque case est revérifiée juste avant la vente ; un objet rangé ou trié dans une case pendant la vente n'est plus vendu.",
            "Maître de métier : un double clic rapide n'achète plus une autre recette que celle cliquée (nom vérifié avant l'achat, aussi pour « Apprendre les favoris »).",
            "Tournée de quêtes : une étape passée à la main ne revient plus au recalcul suivant (rendu, changement de zone…), jusqu'à la prochaine tournée.",
            "Guide de montée : l'étape « Maître de classe » disparaît après la visite du maître à ce niveau, même si tous les sorts n'ont pas été achetés ; le guide passe bien à la suite.",
            "Chaînes de quêtes apprises : ouvrir deux fois le détail d'une même quête ne compte plus comme deux confirmations.",
        },
    },
    {
        version = "1.128.16", date = "21/11/2026",
        fixed = {
            "Mise à jour disponible : une version annoncée par un autre joueur avec un numéro absurde (« 1.128.99999 ») est ignorée ; une version annoncée de nouveau n'est plus oubliée au bout de 30 jours puis réannoncée.",
            "Options > Fiabilité, carte Données : un dossier WarbandKeeper_Data seulement désactivé dans la liste des AddOns est dit « désactivé », au lieu de « absent : réinstalle ».",
            "Recherche : une page qui plante à sa construction ne rend plus ses réglages introuvables jusqu'à la version suivante, et ne laisse plus de lignes en double.",
            "Maître de classe : reconnu même quand le filtre de sa fenêtre cache tout ; un double clic rapide dans le panneau n'achète plus un autre sort que celui cliqué.",
            "Halo : quand plusieurs plantes ou filons sont proches, il ne se pose plus sur le premier venu.",
            "Recherche de groupe : une nouvelle recherche lancée juste après une autre n'est plus coupée par la minuterie de la précédente.",
            "Fiche, onglet Armes : un emplacement d'arme vide n'affiche plus l'ancienne arme comme « en main ».",
            "Points /way : un point déjà en tête de file est bien guidé quand on le redemande ; un addon qui ajoute deux fois le même point (API TomTom) reçoit le même identifiant.",
        },
    },
    {
        version = "1.128.15", date = "21/11/2026",
        fixed = {
            "Objets verrouillés : un marchand fermé pendant un combat ne laisse plus son cache sur les cases ; une potion ou un objet de quête verrouillé redevient utilisable tout de suite, sans attendre la fin du combat. Glisser un objet seulement cher dit « Vente chère » au lieu de « Verrouillé ».",
            "Métiers : ouvrir le métier d'un autre joueur (lien dans le chat) n'enregistre plus ses recettes comme les tiennes, aussi sur l'ancienne fenêtre des métiers.",
        },
    },
    {
        version = "1.128.14", date = "21/11/2026",
        changed = {
            "Plus léger en raid avec des paladins : les messages de PallyPower sont regroupés (une seule nouvelle répartition toutes les 0,3 s), et un message inconnu ne relance plus rien.",
            "Feu de camp : n'écoute plus que tes propres effets (plus ceux de tout le raid et des plaques de nom), et les boutons du kit ne sont plus reposés à chaque effet.",
            "Carte des récoltes : une nouvelle récolte s'ajoute aux emplacements déjà regroupés, au lieu de tout regrouper de nouveau (jusqu'à 3000 points).",
            "Courrier et banque : le plan ne recalcule plus les guides de métier de tous tes persos, seulement ceux du perso connecté.",
            "Options > Fiabilité : la taille de la sauvegarde est mesurée une fois toutes les 5 minutes au plus, au lieu de chaque affichage.",
            "Deux minuteries qui ne servaient plus (rappels du chasseur et du feu de camp) sont retirées ; la fenêtre des talents arrête de chercher un bouton introuvable après quelques essais.",
        },
    },
    {
        version = "1.128.13", date = "21/11/2026",
        fixed = {
            "Vente rapide : un prix tapé à la main n'est plus écrasé par le second essai, et le prix n'est plus posé si tu as changé d'objet entre-temps.",
            "Rachat automatique : seul un objet verrouillé vendu pendant cette visite chez le marchand est racheté ; avant, un objet vendu à une visite précédente, ou avant d'être verrouillé, était racheté avec ton or sans clic.",
            "Courrier : une pile qui a grossi depuis le plan (butin, piles fusionnées) n'envoie plus que la quantité prévue ; le reste est gardé, et la boîte du destinataire compte ce qui est vraiment parti.",
            "Banque : le dépôt ne reprend plus une case qu'un dépôt précédent était encore en train de remplir (les deux objets étaient échangés), et le compte des objets déposés est juste.",
            "Sacs : l'ouverture automatique attend qu'aucun sort n'attende sa cible (enchantement, pierre à aiguiser) et que le curseur soit vide.",
            "Téléchargement plus léger : les outils de développement ne sont plus dans le zip.",
        },
    },
    {
        version = "1.128.12", date = "21/11/2026",
        fixed = {
            "Bouton Buffer : un joueur n'est plus écarté 2 minutes quand l'échec vient de toi (sort pas encore prêt, temps de recharge, mana, en mouvement, autre sort en cours) ; le clic suivant le retente. Hors de portée, hors de vue ou buff plus puissant : il est toujours passé.",
            "Chasseur : le bouton d'aspect et la carte du familier coupés dans leurs réglages ne réagissent plus à leurs raccourcis clavier.",
            "Bouton Buffer : pendant l'aperçu et le test du mode édition, un clic ou le raccourci ne lance plus de sort ni ne change de cible (macro vidée, aussi à l'entrée en combat).",
        },
    },
    {
        version = "1.128.11", date = "21/11/2026",
        fixed = {
            "Courrier : « Prendre » sur une lettre ne prend plus aussi les lettres suivantes (une fois la lettre vidée, le jeu la supprime et la suivante prenait sa place).",
            "Farm : un objet retiré de l'équipement et les objets fabriqués ne comptent plus comme butin de la session.",
            "Profils : un profil enregistré avant l'arrivée d'une catégorie de réglages ne remet plus cette catégorie aux valeurs d'origine ; les réglages en place sont gardés.",
            "Démarrage : une erreur dans la base, le profil ou le thème est notée au journal sans empêcher les modules de démarrer.",
        },
    },
    {
        version = "1.128.10", date = "21/11/2026",
        fixed = {
            "Guidage : un trajet qui n'a pas pu être calculé (pendant un chargement, en ville, en instance) est retenté quelques secondes plus tard, et à l'arrivée dans une nouvelle zone ; avant, la flèche restait à vol d'oiseau jusqu'au prochain changement de cible.",
            "Guidage : un trajet calculé pour un continent quitté pendant le calcul (portail, téléport) est refait pour le bon continent.",
            "Réseau des chemins : un continent n'est plus construit deux fois en même temps (calcul du trajet et apprentissage des chemins) ; « /wk nav » ne fige plus l'écran.",
            "Carte du monde : redessinée une fois de moins à chaque nouveau trajet.",
            "Fin d'un point /way ou du retour au corps : le guidage d'avant (marchand, boîte aux lettres…) revient bien, au lieu d'être remplacé par la quête suivie. Tournée de récolte : elle continue après une arrivée même si la quête suivie a repris la main entre-temps.",
            "Retour au corps : plus d'erreur Lua chaque seconde sur les cartes où le jeu ne donne pas de position (instances, champs de bataille).",
        },
    },
    {
        version = "1.128.9", date = "21/11/2026",
        fixed = {
            "Barre Quête, bouton Cibler : le nom du monstre est pris dans la langue du jeu (pas celle choisie pour l'addon) ; avant, le bouton ne ciblait rien si les deux langues différaient. Sur un client ni français ni anglais, le bouton Cibler n'est plus proposé (nom inconnu).",
            "Menu d'une ligne de la tournée : « Passer cette étape » retire l'étape cliquée, et non plus l'étape en cours.",
            "Chaînes de quêtes apprises en jeu : une quête que le PNJ proposait déjà avant le rendu n'est plus prise pour sa suite, et une suite « vue juste après un rendu » ne bloque une quête qu'après deux confirmations.",
            "Une quête apprise en jeu puis supprimée (répétable, nettoyage) ne reste plus affichée dans sa zone jusqu'au /reload.",
        },
    },
    {
        version = "1.128.8", date = "21/11/2026",
        fixed = {
            "HV : une enchère « appât » (un exemplaire à 1 pc, une erreur de frappe) n'est plus prise pour le cours. Le prix proposé dans notre fenêtre de vente l'ignore, et le prix du scan aussi (garde-fous de vente, objets chers, règle « valeur ») ; les alertes de prix voient toujours le plus bas réel.",
            "HV, vente : un prix bien sous le cours du scan est signalé même s'il est égal au prix proposé (avant, il pouvait partir avec la touche Espace).",
            "HV, achat de marchandises (« Tout acheter », Acheter) : si le prix à l'unité dépasse 3 fois le cours connu, un clic de plus est demandé, avec un message.",
            "« Désenchanter le suivant » : le sort est lancé directement sur l'objet ; si le sort échoue (recharge, déplacement), l'objet n'est plus utilisé (un équipement aurait été équipé, donc lié). Une case encore verrouillée par le jeu est refusée.",
            "Mise à jour automatique des données : une mise à jour qui ne touche que le dossier des données à la demande (objectifs, objets BiS, recettes) est maintenant publiée.",
        },
    },
    {
        version = "1.128.7", date = "21/11/2026",
        fixed = {
            "Tournée : en changeant de zone, une quête retirée (« Ignorer cette quête »), écartée ou plus proposée par son donneur n'est plus remise à la fin de la tournée.",
            "Tournée : les étapes de vol, de pierre de foyer, de téléport, d'achat et de maître de classe passent de nouveau seules à la suivante (depuis la 1.128.3, la flèche restait par exemple sur le maître de vol après l'atterrissage).",
            "Marchand : un double clic n'achète plus deux fois, même si le premier achat est déjà arrivé dans les sacs avant que la liste se mette à jour.",
            "Objets de quête à acheter : la liste ne reste plus vide jusqu'au /reload quand elle est lue avant le chargement des données à la demande (bouton d'achat, étapes « acheter »).",
            "Données à la demande : la fenêtre des quêtes du donjon et les pastilles du suivi ne les chargent plus pour rien à la connexion ; et quand elles arrivent (après un combat par exemple), cible du guidage, tournée et objets à acheter sont refaits.",
            "Chasseur : la macro et le bouton « Nourrir » ne gardent plus une nourriture que le familier vient de finir (liste refaite une fois les sacs relus).",
            "Bénédictions : la barre suit tout de suite un changement de répartition, une bénédiction posée et un changement de groupe (elle pouvait montrer l'ancien état jusqu'à une seconde, et le garder tout un combat).",
            "Tournée gardée en mémoire : refaite quand les quêtes cochées changent (niveau, « Quêtes au-dessus de ton niveau »), après un passage de niveau ou un sort appris.",
            "Page Quêtes : les chiffres des zones et du bandeau suivent tout de suite une quête rendue (ils pouvaient garder un rafraîchissement de retard).",
        },
    },
    {
        version = "1.128.6", date = "21/11/2026",
        changed = {
            "Connexion et changement de continent plus fluides : le réseau des chemins du continent (des milliers de points) se construit petit à petit au lieu d'un bloc qui faisait sauter l'image.",
            "Tournée de récolte : elle part des coins regroupés (un point par coin, les 150 plus récoltés) au lieu de tous les relevés ; plus de gel au clic, ni de doublons sautés un par un.",
            "Guidage : le point suivant du trajet n'est plus recalculé environ 50 fois par seconde par l'épingle et la flèche, mais au plus 10 fois.",
            "Sacs ouverts : les cadenas ne sont plus repeints toutes les 0,3 s, seulement quand le contenu change (et toutes les 2 s en secours).",
            "Bandeau des quais : l'animation de la houle tourne à 20 images par seconde au lieu de chaque image.",
        },
    },
    {
        version = "1.128.5", date = "21/11/2026",
        fixed = {
            "Voleur : « Alerte avant la fin des poisons » prévient de nouveau, dans le chat (une fois par poison qui s'achève). Sorts de classe : « Rappel au passage de niveau » écrit les sorts à apprendre dans le chat, une fois par niveau. (Ces deux réglages n'avaient plus d'effet depuis le retrait des rappels à l'écran.)",
            "Rangement : les réglages « Prix proposé » et « Durée des enchères » sont retirés (ils n'étaient jamais utilisés : la vente suit les réglages de la page Vendre de l'HV).",
            "Marchand : après une réparation automatique, la fenêtre ne se ferme plus quand il y a quelque chose à acheter (Réassort, objets de quête, panneau des métiers).",
            "Nettoyage des persos pas connectés depuis 180 jours : la suppression est maintenant complète (or dans les courbes du compte, objets, profil, builds, listes), comme le bouton de la page Persos.",
            "Carte du monde : les pastilles /way gardent une taille raisonnable quand on zoome (même échelle que les autres repères).",
            "Farm : un courrier relevé puis fermé tout de suite (ou une banque, un échange…) n'est plus compté comme butin de farm.",
            "Une page de la fenêtre qui plante à sa construction n'est plus laissée à moitié faite : elle est refaite à la prochaine ouverture (l'erreur est notée au journal de Fiabilité).",
        },
    },
    {
        version = "1.128.4", date = "21/11/2026",
        changed = {
            "Raid plus fluide (paladin) : l'état des bénédictions du groupe n'est plus lu deux fois par seconde (barre des bénédictions et bouton Buffer chacun de leur côté) mais une fois, et les boutons de la barre ne sont plus réécrits chaque seconde quand rien ne change.",
            "Chasseur : la carte du familier ne refait plus la liste de nourriture à chaque changement de la vie du familier (plusieurs fois par seconde en combat) ; la liste est gardée jusqu'au prochain changement de sacs ou de familier.",
        },
    },
    {
        version = "1.128.3", date = "21/11/2026",
        changed = {
            "Quêtes plus fluides : le journal du jeu se met à jour très souvent sans que rien change ; la carte de tournée, les zones sur la carte du monde et la page Quêtes ne se redessinent plus que quand une quête ou un objectif a vraiment bougé.",
            "Tournée : le calcul de l'ordre des étapes (le plus lourd de l'addon) n'est plus refait toutes les 2 secondes, seulement quand les quêtes, leur avancée ou ta position (à quelques centaines de mètres près) changent.",
            "Page Quêtes : la liste des zones, la zone conseillée et les chiffres du bandeau sont calculés en un seul passage au lieu de quatre.",
        },
    },
    {
        version = "1.128.2", date = "21/11/2026",
        fixed = {
            "Quêtes à prendre tout près et objet qui démarre une quête : ces alertes s'écrivent de nouveau dans le chat (depuis le retrait des rappels à l'écran, elles ne s'affichaient plus mais étaient quand même marquées comme dites).",
            "Carte du monde : Ctrl + clic droit (point /way) et Alt + clic (note de carte) posent le point là où tu as cliqué, même quand le clic fait changer de carte (remonter à la carte parente, ouvrir une zone d'un continent).",
            "Points /way : le même point n'est plus ajouté deux fois (lien cliqué deux fois, point partagé reçu aussi en texte, points rechargés par TomTom) ; un message le dit, et « guider maintenant » le remet en tête.",
        },
    },
    {
        version = "1.128.1", date = "21/11/2026",
        fixed = {
            "Langue : les noms des raccourcis clavier (Options du jeu > Raccourcis > AddOns) suivent la langue choisie dans les Options, et changer de langue propose de recharger l'interface pour que les éléments à l'écran suivent aussi.",
            "Mise à jour disponible : une version annoncée par un autre joueur n'est retenue que si elle est crédible (au plus quelques versions d'avance) et pendant 30 jours ; une fausse annonce « 999 » ne laisse plus le bouton « mise à jour » affiché pour toujours (une ancienne est effacée).",
            "Page Persos : banque pas vue depuis longtemps et courrier qui va expirer s'affichent bien en orange (ils étaient en gris).",
            "Démarrage : un module qui plante à la connexion n'empêche plus les autres de démarrer ; et une même erreur n'est écrite qu'une fois par séance dans le chat (toujours notée au journal de Fiabilité).",
        },
    },
    {
        version = "1.128.0", date = "21/11/2026", restart = true,
        changed = {
            "Connexion plus légère : les grosses bases (coins des objectifs de quête, objets des listes BiS, recettes ; env. 1,45 Mo) sont maintenant dans un second dossier, WarbandKeeper_Data, chargé seulement quand une fonction en a besoin (quête suivie, zones de quête, tournée, barre Quête, choix BiS, recettes manquantes, Rangement).",
            "Préchargement en douceur : si une quête est suivie ou une tournée en cours, ces données se chargent toutes seules 20 s après la connexion, hors combat ; rien ne fige en ouvrant la carte. Jamais de chargement en plein combat (attendu jusqu'à la fin du combat).",
            "Options > Fiabilité : carte « Données » (état, heure et raison du chargement, bouton « Charger maintenant », préchargement, message dans le chat).",
            "Installation : le zip contient deux dossiers à copier dans Interface\\AddOns ; le client PC les installe ensemble. « Warband Keeper Data » apparaît dans la liste des addons du jeu et doit rester coché. Redémarrage complet du jeu nécessaire pour cette version.",
        },
    },
    {
        version = "1.127.5", date = "21/11/2026",
        fixed = {
            "Règles d'envoi créées par un guide de métier : le perso qui envoie garde ce que son propre guide demande, au lieu d'envoyer tout son stock (vaut pour les règles créées à partir de cette version).",
            "Profils : changer de profil ne fait plus réapparaître les raccourcis LFG et Mode pêche que tu avais retirés du micro menu.",
            "Mode édition : « Disposition : ce perso » ne vaut plus que pour le perso où tu l'actives ; les autres gardent leurs éléments où ils étaient. En l'activant, la disposition du perso part de celle du compte (rien ne bouge).",
        },
    },
    {
        version = "1.127.4", date = "21/11/2026",
        fixed = {
            "Marchand : un double clic sur « Acheter », « Tout acheter » ou « Réassort » n'achète plus deux fois ce qui manque (l'achat pas encore arrivé dans les sacs est décompté).",
            "Vente rapide dans la fenêtre HV du jeu : le prix n'est plus rempli s'il tombe sous le prix marchand (commission comprise) ou bien sous le cours du scan ; le prix du jeu est gardé et un message le dit.",
            "Objets verrouillés : la règle « liste d'envies » protège aussi les objets de tes listes BiS (tous les persos) : plus vendus, désenchantés ni mis en vente par erreur.",
        },
    },
    {
        version = "1.127.3", date = "21/11/2026",
        fixed = {
            "Quêtes répétables (journalières, hebdomadaires…) : elles ne sont plus notées comme « nouvelles quêtes absentes de la base », ne restent plus proposées pour toujours et ne sont plus prises par l'acceptation automatique. Celles notées par erreur sont retirées.",
            "Tournée : en changeant de zone, les étapes qui restaient ailleurs (donneur, coin d'objectifs ou rendu dans l'autre zone) sont gardées à la fin de la tournée au lieu d'être perdues ; le message le dit.",
            "Métiers : une recette cachée par un en-tête replié ou un filtre de la fenêtre du métier n'est plus effacée de la fiche du perso, et Cuisine, Pêche ou Secourisme ne disparaissent plus quand l'en-tête « Compétences secondaires » est replié.",
        },
    },
    {
        version = "1.127.2", date = "21/11/2026",
        fixed = {
            "Infobulle des PNJ : le bloc des quêtes ne disparaît plus quand le PNJ a une quête fermée pour toi (quête exclusive, niveau max dépassé, réputation) ; cette quête n'y est simplement pas listée.",
            "Guidage : en passant au point /way suivant ou à l'étape suivante de la tournée, il n'y a plus de faux « Arrivé » qui arrêtait le guidage (l'ancien trajet n'est plus utilisé pendant le calcul du nouveau).",
        },
    },
    {
        version = "1.127.1", date = "21/11/2026",
        fixed = {
            "Courrier : si la fenêtre d'envoi contient déjà des objets ou de l'or mis à la main, l'envoi automatique (Rangement, règles) est annulé avec un message, au lieu de les envoyer avec la lettre.",
            "« Désenchanter le suivant » revérifie l'objet juste avant le clic : si la case a changé (tri des sacs, objet déplacé), rien n'est désenchanté et la liste se remet à jour.",
            "Liens /way du chat : l'addon ne remplace plus la fonction du jeu qui gère les clics sur les liens (cela pouvait faire bloquer des actions en combat tapées dans le chat).",
            "Bouton « Buffer autour » : la macro est vidée en entrant en combat et quand il n'y a personne à buffer ; le raccourci clavier ne change ou n'efface plus ta cible en combat.",
            "Fiches en double : deux persos homonymes de deux royaumes différents ne sont plus fusionnés (le royaume doit être le même quand le jeu ne donne pas l'identifiant du perso).",
            "Rachat automatique : seuls les objets verrouillés à la main sont rachetés ; un objet de quête ou un épique vendu exprès n'est plus racheté avec ton or.",
            "Maître de classe : « Tout apprendre » et le panneau ne s'activent plus chez un maître d'armes, de familiers ou de monte, et n'achètent que les sorts de ta classe.",
        },
    },
    {
        version = "1.127.0", date = "21/11/2026",
        changed = {
            "Cibler et Objet passent de la carte de tournée à une petite barre « Quête » à placer où tu veux (mode édition) : bouton Cibler (liseré à ta couleur), bouton Objet (avec son nombre et sa recharge), la touche de chaque bouton dans son coin, puis le nom du monstre et l'objectif (« objectif 1/2 · 3/8 · clic droit : suivant »).",
            "La barre sert aussi hors tournée, pour la quête suivie. Elle se cache quand il n'y a rien à cibler ni à utiliser (hors combat).",
            "Réglage renommé « Barre de quête (Cibler, Objet) » (roue des Quêtes, carte Quête suivie). Les raccourcis clavier déjà réglés restent valables.",
        },
    },
    {
        version = "1.126.3", date = "21/11/2026",
        fixed = {
            "Carte de tournée : plus de message « action bloquée » (Frame:Show) en combat. Les boutons Cibler / Objet ne sont plus accrochés à la carte : ils sont posés par-dessus et suivent la carte quand tu la déplaces (hors combat).",
        },
    },
    {
        version = "1.126.2", date = "21/11/2026",
        fixed = {
            "Carte de tournée : erreur Lua (QuestTracker.lua:382) à l'affichage des boutons Cibler / Objet ; ils s'affichent maintenant.",
        },
    },
    {
        version = "1.126.1", date = "21/11/2026",
        added = {
            "Raccourcis clavier pour les boutons de la carte de tournée (Options du jeu > Raccourcis > AddOns > Warband Keeper) : « Cibler le monstre de la quête » (avec la tête de mort), « Cibler le monstre de l'objectif suivant » et « Utiliser l'objet de la quête ». Ils marchent aussi en combat ; la touche choisie s'affiche dans l'infobulle du bouton Cibler.",
        },
    },
    {
        version = "1.126.0", date = "21/11/2026",
        added = {
            "Carte de tournée : pour une étape à faire, bouton « Cibler » avec le nom du monstre de l'objectif (clic gauche : le premier pas fini, clic droit : le suivant) et bouton « Objet » qui utilise l'objet de la quête, avec son nombre. Ils marchent aussi en combat (en combat, ils gardent le dernier monstre et le dernier objet).",
            "Le bouton Cibler pose la tête de mort sur le monstre ciblé (seul, ou chef et assistants en groupe).",
            "Plaques de nom : petite pastille à la couleur de l'objectif au-dessus des monstres de la quête, plus grosse sur ta cible.",
            "Trois réglages dans la roue des Quêtes, carte Quête suivie : « Boutons Cibler et Objet », « Tête de mort sur le monstre ciblé », « Repère sur les plaques de nom ».",
        },
        changed = {
            "Quêtes de groupe : « GROUPE » en orange devant le nom (tournée, carte de tournée, Quêtes de ma zone, quêtes de donjon) au lieu de « (groupe) » après.",
        },
    },
    {
        version = "1.125.1", date = "21/11/2026",
        added = {
            "Tournée : quand tu passes à côté d'une étape prévue plus loin (donneur ou rendu à moins de 45 m, coin d'objectifs à moins de 70 m) et qu'elle est faisable maintenant, la carte de tournée la propose : « Tout près : … · 20 m · clic : la faire maintenant ». Clic : elle devient l'étape en cours, celle d'avant reprend juste après ; clic droit : plus tard.",
            "Réglage « Étapes toutes proches » (roue des Quêtes, carte Quête suivie) : Proposer, Auto (remontée toute seule, avec un message) ou Non.",
        },
    },
    {
        version = "1.125.0", date = "21/11/2026",
        changed = {
            "Quêtes vérifiées une à une sur wowhead (WoW Forever) : 1 669 quêtes, surtout le nouveau contenu, ont enfin leur nom français (« Death to the Dragonmaw » devient « Mort aux Gueules-de-Dragon »), et 111 noms français anciens prennent celui du jeu actuel (« Un message pour Hurlevent » au lieu de « Stormwind », « Foudrepique » au lieu de « Stormpike »…).",
        },
        fixed = {
            "Quêtes : 10 niveaux corrigés d'après le jeu, et 12 quêtes qui n'existent pas dans le jeu (quêtes de test, d'événements retirés) ne sont plus proposées.",
        },
    },
    {
        version = "1.124.2", date = "21/11/2026",
        added = {
            "Clic droit sur une quête : « Chercher un groupe (chat) » ouvre la discussion avec un message et le lien de la quête (« LFG [quête] (zone), anyone want to group up? ») ; choisis le canal puis Entrée.",
            "Message modifiable dans la roue des Quêtes, onglet Quêtes montrées, carte « Message de groupe » ({quest} lien, {name} nom, {level} niveau, {zone} zone) ; bouton « Par défaut » pour revenir au message anglais.",
        },
    },
    {
        version = "1.124.1", date = "21/11/2026",
        fixed = {
            "Tournée : une quête dont les objectifs sont à plusieurs endroits (« Entrevoir notre avenir ») apparaissait deux fois sous le même nom, et chaque étape montrait tous ses objectifs. Chaque étape dit maintenant ce qu'on y fait (« Entrevoir notre avenir · Cœur d'Adoss, Cœur de Modr »), ne montre que ses objectifs, et passe à la suivante dès qu'ils sont faits.",
        },
    },
    {
        version = "1.124.0", date = "21/11/2026",
        added = {
            "Quêtes : l'addon apprend les chaînes que la base ne connaît pas (fréquent pour le nouveau contenu de WoW Forever). Une quête proposée par un PNJ juste après lui en avoir rendu une, ou une quête « pas encore proposée » qui le devient après un rendu, est notée comme sa suite. Tes autres persos attendent alors la quête d'avant (« après … »), et un message le signale.",
            "/wk chaines : la liste des chaînes apprises (à partager pour les ajouter aux corrections de la base).",
        },
    },
    {
        version = "1.123.5", date = "21/11/2026",
        changed = {
            "Fenêtre des quêtes du donjon : une fois sa hauteur réglée avec la poignée, elle garde cette taille. Seul le contenu défile à la molette, la ligne « plus haut / plus bas » et le bouton Tournée restent en bas.",
        },
    },
    {
        version = "1.123.4", date = "21/11/2026",
        fixed = {
            "Suivi des quêtes : les pastilles de la tournée ne s'affichaient pas, le suivi de WoW Forever ne portant pas les noms de cadre attendus. L'addon le cherche maintenant parmi tous les cadres du jeu (un petit bouton qui porte un n° de quête) ; /wk suivi en dit plus si ça ne marche toujours pas.",
            "Mode édition : le bandeau « Retour au corps » s'appelle maintenant « Retour au corps (secours) » et montre le seul cas où il sert encore (corps sur un autre continent) ; d'habitude, c'est l'épingle tête de mort qui guide.",
        },
    },
    {
        version = "1.123.3", date = "21/11/2026",
        changed = {
            "Fenêtre des quêtes du donjon : elle se déplace en glissant son titre, sans passer par le mode édition. Le coin en bas à droite règle sa hauteur (double-clic : automatique) et la molette fait défiler ce qui ne tient pas (« 3 plus bas · molette »).",
            "Fenêtre des quêtes du donjon : nouvelle option « Compacte », une ligne par quête (objectifs et lieu dans l'infobulle), dans la roue des Donjons, onglet Quêtes du donjon.",
        },
        fixed = {
            "Fenêtre des quêtes du donjon : le nom du donjon était coupé (« Excavations : les p… »). Il s'affiche en entier, sur deux lignes au besoin, avec « Quêtes · env. 3650 XP » dessous.",
        },
    },
    {
        version = "1.123.2", date = "21/11/2026",
        fixed = {
            "Quêtes : l'addon proposait de prendre des quêtes que le PNJ ne donne pas encore (souvent le nouveau contenu de WoW Forever, dont la base ne connaît pas les prérequis, comme « Death to the Dragonmaw » chez Howin Kindfeather). En parlant au PNJ, les quêtes qu'il ne montre pas sont maintenant notées « pas encore proposée par le PNJ » et retirées de la tournée. Elles reviennent d'elles-mêmes au niveau suivant ou dès qu'une autre quête est rendue.",
        },
    },
    {
        version = "1.123.1", date = "21/11/2026", restart = true,
        changed = {
            "Fenêtre du lien wowhead : bouton « Copier » (icône) à côté du lien, qui le sélectionne et dit quoi faire (le jeu ne laisse pas un addon écrire dans le presse-papiers : il reste Ctrl+C). Les boutons « Version anglaise / française » et « Mettre dans le chat » ont maintenant leur icône (globe, bulle).",
        },
    },
    {
        version = "1.123.0", date = "21/11/2026",
        added = {
            "Suivi des quêtes du jeu : les icônes rondes à gauche de chaque quête sont remplacées par les pastilles de la tournée, à la couleur de la prochaine étape qui la concerne (accent à faire, vert à rendre) avec son numéro ; gris hors tournée, « ? » vert si prête à rendre.",
            "Option « Avancement » : un anneau rouge (pas commencée), orange (en cours) ou vert (prête) avec le numéro d'étape. « Icônes du jeu » rend l'affichage d'origine. Roue des Quêtes, onglet Suivi et carte, carte « Suivi des quêtes du jeu ».",
            "Sur la pastille : clic = suivre et guider, Maj + clic = lien wowhead, clic droit = menu de la quête ; au survol, l'étape de la tournée et l'XP. /wk suivi dit ce qui a été trouvé.",
        },
    },
    {
        version = "1.122.0", date = "21/11/2026", restart = true,
        added = {
            "Points /way, comme TomTom : « /way 32.35 48.55 Nom » pose un point et le guide (flèche, épingle, repère et trajet). Zone en anglais ou en français, début du nom accepté (« /way Elwynn 32 48 »), « /way #1429 x y », virgules acceptées ; « /way » seul = ta position ; « /way list », « /way reset », « /way undo ».",
            "File de points : plusieurs /way à la suite se suivent ; arrivé à un point, le suivant est guidé tout seul (« encore 2 » sur l'épingle). Option « Plus proche » qui réordonne la file. Le guidage d'avant (tournée, quête suivie) revient quand la file est finie.",
            "Compatible TomTom : s'il est installé, il garde /way et la nôtre devient /wkway (option pour suivre aussi ses points avec notre épingle et notre trajet). S'il ne l'est pas, les addons qui « envoient vers TomTom » posent leurs points ici.",
            "Chat : « /way … » et « 32.35, 48.55 » écrits par les joueurs deviennent cliquables (clic : guider, Maj + clic : ajouter à la file, clic droit : note de carte).",
            "Carte du monde : points numérotés de la file, petite liste sur le côté, Ctrl + clic droit pour poser un point, clic droit sur un point : guider, renommer, garder en note de carte, partager au groupe, supprimer.",
            "Partage : le point part au groupe en texte /way (lisible par tous) et, pour ceux qui ont Warband Keeper, en lien à cliquer.",
            "Réglages : carte « Points /way » de QoL > Carte et guidage, onglet Guidage.",
        },
    },
    {
        version = "1.121.0", date = "21/11/2026",
        changed = {
            "Réglages rangés en sous-onglets de catégories dans toutes les roues qui n'en avaient pas : Quêtes (Suivi et carte, Quêtes montrées, Quêtes automatiques), Donjons (Panneau et alertes, Quêtes du donjon, Chrono), Courrier (Envoi, Réception, Fenêtre), Hôtel des ventes (Scan et prix, Vente, Alertes de prix), Pêche (Mode pêche, Tenue et confort, Récapitulatif) et Rares (Carte, Alerte). L'onglet choisi est retenu ; la recherche ouvre le bon onglet.",
        },
    },
    {
        version = "1.120.1", date = "21/11/2026",
        fixed = {
            "Zones de chaleur : rien ne s'affichait. Les halos étaient dessinés en mode additif, invisible sur le parchemin clair de la carte et sur la minicarte : ils sont maintenant opaques, plus grands et bien visibles.",
            "Minicarte : dans une sous-zone (village, grotte), les zones de la quête n'apparaissaient pas ; elles sont prises sur la carte de la zone.",
        },
        added = {
            "/wk zones : diagnostic des zones de quête (quête suivie, style, points trouvés sur ta carte, halos dessinés sur la carte et la minicarte).",
        },
    },
    {
        version = "1.120.0", date = "21/11/2026",
        added = {
            "Quêtes : zones de chaleur sur la carte du monde. Chaque apparition des monstres et objets d'un objectif est dessinée en halo doux : plus c'est vif, plus il y en a. Une couleur par objectif de la quête suivie. L'infobulle et le clic sur la zone restent.",
            "Minicarte : les zones de la quête suivie (ou de l'étape en cours de la tournée) autour de toi, en chaleur ou en points. Un objectif fini disparaît.",
            "Roue de la page Quêtes, carte « Zones des objectifs » : dessin sur la carte (Chaleur, Points ou Cercles comme avant), sur la minicarte (Chaleur, Points ou Aucune) et intensité de la chaleur.",
        },
        changed = {
            "Carte de tournée à l'écran refaite : chaque objectif est une barre qui se remplit, à la couleur de sa quête (légende quand l'étape en regroupe plusieurs), fini en vert. En-tête sur deux lignes (zone, puis « étape 1 sur 33 · env. 57 min ») avec le total d'XP en gros à droite, barre d'avancée plus visible, titre plus grand.",
        },
    },
    {
        version = "1.119.0", date = "21/11/2026",
        changed = {
            "Quêtes : les zones des objectifs sont plus précises. Les monstres et objets d'une quête sont regroupés en camps plus serrés (jusqu'à 10 par objectif au lieu de 6, cercles plus petits qui ne grossissent plus pour un monstre isolé) : la flèche, la carte et la tournée visent le vrai coin au lieu du milieu d'une grande zone.",
        },
        added = {
            "Quêtes d'exploration (« trouve la grotte… ») : le lieu exact est sur la carte et la flèche y mène, au lieu d'aller directement au rendu.",
            "Objectifs cachés (objet à utiliser à un endroit précis…) : leur lieu passe en tête de l'objectif concerné, ou s'ajoute en « Lieu de l'objectif caché ».",
        },
    },
    {
        version = "1.118.2", date = "21/11/2026",
        changed = {
            "Retour au corps : un seul repère au lieu de deux. L'épingle à l'écran devient une tête de mort rouge et donne le conseil (« Cours-y » ou « Loin : l'ange gardien est plus rapide »), la distance par le trajet avec le temps de course (« 767 m · env. 1:04 ») et le mal de résurrection de l'ange gardien. Le bandeau du bas n'apparaît plus que si l'épingle ne peut pas guider (corps sur un autre continent, position inconnue, épingle coupée).",
        },
    },
    {
        version = "1.118.1", date = "21/11/2026",
        fixed = {
            "Quêtes : l'addon proposait de prendre la variante d'une quête réservée à une autre race (L'appel de la terre, Dompter la bête…) alors que tu avais déjà la tienne dans ton journal. Ces variantes ne sont plus proposées.",
            "Quêtes : une quête qui ne se prend plus est écartée, avec l'état « plus proposée » : un autre choix exclusif est déjà pris, la suite de la chaîne est déjà prise ou faite, la quête d'introduction mène à une quête déjà prise, niveau maximum dépassé, ou réputation trop basse (perso connecté). Elle ne compte plus dans les totaux des zones.",
            "Quêtes : des suites de chaîne (Dompter la bête après La voie du chasseur, Triage…) étaient proposées sans la quête d'avant ; elles attendent maintenant « après … » comme les autres prérequis, y compris dans la tournée et les quêtes de donjon.",
        },
    },
    {
        version = "1.118.0", date = "21/11/2026",
        added = {
            "Tournée de quêtes plus maline : les objectifs de plusieurs quêtes proches (jusqu'à env. 200 m) sont faits dans la même étape ; sur la carte à l'écran, chaque objectif dit à quelle quête il sert.",
            "Tournée : sur un long trajet entre deux étapes, une étape « Foyer » est ajoutée quand ta pierre est liée près de l'arrivée (et prête), ou « Vol » entre deux maîtres de vol connus, si elle fait gagner au moins 1 min et un quart du temps à pied (« gagne N min »). Elle se coche à l'arrivée, ou si tu es déjà près de l'étape suivante.",
            "Tournée : les quêtes cochées qui coûtent trop de temps pour leur XP (comparé au reste de la tournée), ou sur un autre continent, sont écartées ; un bandeau sous les étapes les nomme avec la raison (« +14 min pour 450 XP »), et « Les remettre » les réintègre.",
            "Tournée : une étape de rendu annonce la suite prise au même moment (« + suite … prise au rendu »).",
        },
    },
    {
        version = "1.117.0", date = "21/11/2026", restart = true,
        added = {
            "Maj + clic sur une quête (tournée à l'écran, liste des étapes, Quêtes de ma zone, liste d'une zone, fenêtre des quêtes du donjon, journal des données) : une petite fenêtre donne son lien wowhead (WoW Forever), déjà sélectionné : Ctrl+C puis colle-le dans ton navigateur. Boutons « Version anglaise / française » et « Mettre dans le chat ».",
            "Clic droit sur une quête aux mêmes endroits : petit menu « Guider vers le donneur », « Suivre cette quête », « Ignorer cette quête » (retirée de la tournée), « Lien wowhead », et « Passer cette étape » dans la tournée. Une étape à plusieurs quêtes propose chaque quête.",
            "Langue du site wowhead (français ou anglais) dans la roue de la page Quêtes, carte « Liens wowhead ».",
        },
        changed = {
            "Micro menu : le raccourci « Bateaux » devient « Destinations » (bateaux, zeppelins et vols) avec une icône de boussole.",
        },
    },
    {
        version = "1.116.1", date = "21/11/2026",
        fixed = {
            "Persos et Résumé : un même perso pouvait apparaître deux fois (le jeu donnait son nom ou son royaume autrement d'une connexion à l'autre). À la connexion, la vieille fiche est fondue dans la fiche du perso connecté (or, quêtes faites, builds, listes, historique…) puis retirée ; un message le signale. Le perso est maintenant aussi reconnu par son identifiant du jeu.",
            "Journal des données : « Afficher 50 de plus » repliait la liste au lieu de l'allonger.",
        },
    },
    {
        version = "1.116.0", date = "21/11/2026",
        added = {
            "Tableau des voyages : onglets Bateaux et Vols (raccourci « Bateaux » du micro menu, /wk bateaux, /wk vols). Vols : points de vol de ta faction sur la carte d'Azeroth, connus en blanc avec leur nom, à apprendre en gris ; trajets du jeu (connus en bleu, pas encore possibles en pointillés gris).",
            "Vols : le point de vol connu le plus proche (ou celui que tu cliques sur la carte) est le départ. En haut de la liste, toutes les destinations possibles depuis lui, avec la durée (apprise, ou estimée) et les relais ; le survol d'une destination trace le trajet sur la carte, le clic guide vers le maître de vol de départ.",
            "Vols : en dessous, les points rangés par continent (jauge des points connus) puis par zone, la plus proche en haut : connus en vert (clic = départ), à apprendre grisés avec la distance (clic = guidage vers le maître de vol). Menu en haut à droite pour voir la carte d'un autre perso.",
        },
    },
    {
        version = "1.115.4", date = "21/11/2026",
        changed = {
            "Tournée et fenêtre des quêtes du donjon : le mot « NOUVELLE » qui allongeait les titres est remplacé par un petit pictogramme coloré après le nom (étincelle turquoise = nouvelle, livre violet = apprise en jeu, flèches orange = corrigée). Les listes de quêtes gardent l'étiquette en toutes lettres.",
        },
    },
    {
        version = "1.115.3", date = "21/11/2026",
        changed = {
            "Journal des données plus lisible : étiquettes pleines NOUVELLE (turquoise) et CORRIGÉE (orange) avec le détail de la correction à côté, chiffres de chaque mise à jour en étiquettes, lignes plus hautes et alternées, quêtes de ta zone en tête puis rangées par zone et par niveau, « Afficher 50 de plus » au bout de la liste.",
            "Pastilles des listes de quêtes (zone, tournée, fenêtre du donjon) : un point plein de la couleur devant le mot, bien plus visible.",
        },
        fixed = {
            "Base de quêtes : 14 quêtes « <NYI> » (jamais ouvertes dans le jeu) apparaissaient dans les listes et le journal ; elles sont retirées.",
        },
    },
    {
        version = "1.115.2", date = "21/11/2026",
        changed = {
            "Données mises à jour depuis QuestieDB et Everloot et tables et wowtbc.gg et Everloot et prix et trajets et zones et opendata : 274 quêtes de plus, 1 objet de butin désormais découverts, guides de métiers revus par wowtbc.gg.",
        },
    },
    {
        version = "1.115.1", date = "21/11/2026",
        added = {
            "Fenêtre des quêtes du donjon pour n'importe quel donjon : bouton dans la page Donjons (bas du détail du donjon choisi) et dans le bandeau des quêtes de l'onglet LFG. Elle reste affichée, même loin du donjon, jusqu'à la croix.",
            "Tournée de ramassage : le bouton « Tournée (n) » de la fenêtre met tous les donneurs (quêtes du donjon et leurs prérequis, dans toutes les zones) dans ta tournée de quêtes, une étape par donneur, du plus proche au plus loin. Changer de zone ne la refait pas ; « Réordonner » refait seulement l'ordre depuis là où tu es. Les quêtes qui attendent un prérequis sont cochées pour plus tard.",
        },
    },
    {
        version = "1.115.0", date = "21/11/2026", restart = true,
        added = {
            "Quêtes : nouvel onglet « Journal » (ce qui arrive dans la base). Chaque mise à jour de la base (QuestieDB et ses corrections WoW Forever) y est datée, avec ses quêtes ajoutées, corrigées (niveau, donneur déplacé, prérequis…) et retirées ; chaque quête apprise en jeu aussi. Chiffres clés en haut, filtres Tout / QuestieDB / Appris en jeu / Ma zone / Mon niveau, clic sur une quête = guidage vers son donneur.",
            "Pastilles NOUVELLE (base mise à jour), APPRISE (notée en jeu) et CORRIGÉE pendant quelques jours après le nom des quêtes : « Quêtes de ma zone », liste des quêtes d'une zone, tournée et fenêtre des quêtes du donjon.",
            "Message à la connexion après une nouvelle base (option) : ce qui change pour toi (quêtes de ta zone à ton niveau), « Voir » ouvre le journal, « Ajouter à la tournée » les coche. Se place en mode édition.",
            "Réglages dans la roue de la page Quêtes, carte « Journal des données » : pastilles, durée (3 à 30 jours), message après une mise à jour.",
            "Le journal commence avec l'arrivée des quêtes WoW Forever du 20/11 (+1 407 quêtes, 44 corrigées).",
        },
    },
    {
        version = "1.114.0", date = "21/11/2026", restart = true,
        added = {
            "Quêtes du donjon : petite fenêtre volante (déplaçable en mode édition), dans le donjon et près de son entrée. Quêtes rangées par état : dans ton journal (objectifs, « prête à rendre »), à prendre (zone et distance du donneur), après prérequis (le prérequis à faire d'abord), faites (ligne repliée). Niveau à la couleur du jeu, XP à gagner en haut, bouton « Prendre (n) ».",
            "Clic sur une quête à prendre (ou un prérequis) : la flèche mène à son donneur ; clic sur une quête du journal : elle devient la quête suivie. La croix cache la fenêtre jusqu'au prochain donjon.",
            "Réglages (roue de la page Donjons, carte « Quêtes du donjon ») : affichage près du donjon / toujours / jamais, opacité du fond, objectifs des quêtes en cours, ligne « Faites », cachée en combat, cachée quand il ne reste rien.",
            "Quêtes apprises en jeu : une quête que la base ne connaît pas (nouvelles quêtes de WoW Forever) est notée quand un PNJ te la montre ou que tu la prends : nom, niveau, donneur et sa position, PNJ du rendu, donjon. Elle apparaît ensuite sur la carte des zones, dans les totaux, la tournée et les quêtes du donjon, pour tous tes persos. Un message dans le chat le signale.",
        },
    },
    {
        version = "1.113.1", date = "20/11/2026",
        added = {
            "Onglet LFG, quêtes du donjon : les prérequis sont pris en compte. Une quête bloquée par une autre compte « après prérequis », et « Prendre les quêtes » ajoute les prérequis à prendre d'abord (toute la chaîne, même dans une autre zone) ; leur liste et la quête qu'ils ouvrent sont dans l'infobulle du bouton.",
            "Les quêtes du donjon qui attendent leur prérequis sont cochées aussi : prises dès qu'elles s'ouvrent (mode Assisté), « Donneur suivant » relance la flèche.",
        },
    },
    {
        version = "1.113.0", date = "20/11/2026",
        added = {
            "Onglet LFG : avec un donjon choisi à gauche, un bandeau donne ses quêtes (à prendre, dans ton journal, plus tard, faites).",
            "Bouton « Prendre les quêtes (n) » : les quêtes à prendre du donjon sont cochées dans tes quêtes (prises toutes seules en mode Assisté) et la flèche mène au donneur le plus proche, puis au suivant après chaque quête acceptée. Leur liste est dans l'infobulle du bouton.",
        },
    },
    {
        version = "1.112.1", date = "20/11/2026",
        fixed = {
            "Rappel du Réal : il n'apparaissait que si le jeu annonçait la fin de la rencontre ; il vient maintenant aussi quand le boss est reconnu à sa mort ou à son butin. Un donjon où tu ramasses un Réal est retenu et donne le rappel les fois suivantes.",
            "Rappel du Réal : il pouvait apparaître juste après avoir fouillé le corps du boss ; il s'arrête maintenant bien au butin.",
            "Résumé de sortie de donjon : il ne venait pas quand tu sortais en fantôme, ni quand le donjon n'était reconnu qu'au premier boss. Il s'écrit maintenant dans le chat (« Bilan du donjon : … »), une fois revenu à la vie si tu es sorti mort.",
        },
    },
    {
        version = "1.112.0", date = "20/11/2026", restart = true,
        changed = {
            "Rappels à l'écran retirés : plus de barre d'icônes, de pile « Rappels », de messages éclair ni de texte rouge. Ce qui compte (envie tombée en donjon, alerte de prix, point de vol à apprendre…) reste écrit dans le chat.",
            "Réglages des rappels retirés avec eux : « Où vont les rappels », rappels du chasseur, du prêtre, du paladin et du druide, alertes du kit de camp, rappel du prochain talent, alerte près d'un donneur de quête.",
            "Barre sacs, marchand et maître : son interrupteur « Afficher la barre » et ses réglages sont maintenant dans QoL > Général > Marchand (ils quittent la roue d'Inventaire).",
        },
    },
    {
        version = "1.111.2", date = "20/11/2026",
        changed = {
            "Quêtes, Ma progression : les interrupteurs « Sans donjons », « Sans métiers » et « Maître de classe » quittent le bloc du guide de montée ; ils sont dans la roue de la page Quêtes (carte « Quête suivie »).",
        },
    },
    {
        version = "1.111.1", date = "20/11/2026",
        added = {
            "Tournée de quêtes : chaque quête est colorée selon son avancement, à l'écran comme dans la liste des étapes. En or : à prendre ; en blanc : prise, rien de fait ; en orange : objectifs entamés ; en vert : prête à rendre.",
        },
    },
    {
        version = "1.111.0", date = "20/11/2026",
        added = {
            "Base de quêtes : les quêtes propres à WoW Forever (et leurs donneurs, monstres et objets) entrent dans la base : 4707 quêtes placées sur les cartes au lieu de 3565, et 5325 quêtes avec leurs objectifs au lieu de 4162.",
        },
        changed = {
            "Base de quêtes : niveaux, races, donneurs, prérequis et zones corrigés pour WoW Forever (corrections de la communauté Questie) ; les quêtes de camping, sans lieu fixe, comptent dans les totaux sans place sur la carte.",
        },
    },
    {
        version = "1.110.4", date = "20/11/2026",
        fixed = {
            "Quêtes, compteur « Quêtes faites » : les quêtes faites absentes de la base de quêtes (propres à WoW Forever) n'étaient pas comptées ; elles le sont maintenant, dans les faites et dans le total.",
            "Base de quêtes : 70 quêtes sans zone connue étaient écartées ; elles comptent maintenant dans les totaux (sans place sur la carte).",
        },
    },
    {
        version = "1.110.3", date = "20/11/2026",
        fixed = {
            "Carte des zones : les quêtes de ton journal propres à WoW Forever (absentes de la base de quêtes, comme « Butin de guerre » ou « Dangers alchimiques ») n'apparaissaient pas dans la liste de leur zone ; elles y sont maintenant (selon la zone où le jeu les range), cochables, avec « position donnée par le jeu ».",
            "Tournée de quêtes : ces quêtes y entrent aussi, à l'endroit que le jeu indique pour elles.",
        },
    },
    {
        version = "1.110.2", date = "20/11/2026",
        fixed = {
            "Tournée de quêtes lancée : la liste des étapes descend jusqu'aux petits boutons (il restait un espace vide au-dessus d'eux).",
        },
    },
    {
        version = "1.110.1", date = "20/11/2026",
        added = {
            "Carte des zones, liste des quêtes de la zone choisie : une case sur chaque quête à prendre ou déjà dans le journal, et en tête « Toutes les quêtes » (même les grises) et « De mon niveau » (de ton niveau moins 3 jusqu'au réglage « au-dessus de ton niveau »).",
            "Pastilles « groupe » et « donjon » : les quêtes de groupe et de donjon n'entrent dans la sélection que si leur pastille est allumée.",
            "En bas : le nombre de quêtes, l'XP et le temps estimé, et « Envoyer dans Ma progression », qui prépare la tournée de ces quêtes (même pour une autre zone que la tienne) et l'ouvre.",
        },
    },
    {
        version = "1.109.1", date = "20/11/2026",
        changed = {
            "Tournée de quêtes : Passer l'étape, Pause / Reprendre, Réordonner et Arrêter deviennent de petits boutons ronds discrets (le nom au survol), sur une seule ligne.",
        },
        added = {
            "Tournée de quêtes : bouton corbeille « Vider la liste » ; il décoche toutes les quêtes de la zone (et arrête la tournée en cours).",
        },
    },
    {
        version = "1.109.0", date = "20/11/2026",
        changed = {
            "Page Quêtes : plus de sous-onglets « Montée en niveaux », « Mon journal » et « Quêtes de ma zone ». « Ma progression » ouvre directement la tournée de quêtes.",
            "Ma progression, en haut : la prochaine étape de la montée en niveaux, avec Passer, Lancer et Suivre le guide, et les réglages Sans donjons, Sans métiers et Maître de classe.",
            "Sous la tournée, avant de la lancer : « Choisir les quêtes » (la liste des quêtes de la zone à cocher prend la place des étapes ; « Voir la tournée » pour revenir) et « Compléter la zone ».",
        },
    },
    {
        version = "1.108.2", date = "20/11/2026",
        changed = {
            "Quêtes de ma zone : plus de cartes « Coin nord », « Coin est »… Les quêtes sont rangées en quatre cartes (À rendre, Dans ton journal, À prendre, Plus tard), de la plus proche à la plus lointaine, avec la distance et la direction sur chaque ligne (« 563 m est »).",
        },
    },
    {
        version = "1.108.1", date = "20/11/2026",
        fixed = {
            "Quêtes de ma zone, « Compléter la zone » : les quêtes bien en dessous de ton niveau (grises) étaient laissées de côté ; elles entrent maintenant aussi dans la tournée, jusqu'à la fin de celle-ci.",
        },
    },
    {
        version = "1.108.0", date = "20/11/2026", restart = true,
        added = {
            "Barre « sacs, marchand et maître » à l'écran (remplace la case « Place dans les sacs ») : trois cases dans un seul cadre. Sac : cases libres, clic pour jeter le gris le moins cher. Marchand : distance du plus proche, clic pour y aller, clic droit pour le forgeron (réparer). Maître de classe : sorts à apprendre (sinon la distance), clic pour y aller.",
            "Couleurs selon l'urgence : sac orange sous le seuil et rouge plein ; marchand rouge quand les sacs sont presque pleins ou l'équipement sous 25 % (orange sous 50 %) ; maître en bleu quand des sorts t'attendent.",
            "Inventaire > roue > Sacs et marchand : cases du marchand et du maître à afficher ou non. Nouveau pictogramme : étal (marchand).",
        },
        changed = {
            "La barre reste à l'écran tout le temps (avant : la case du sac n'apparaissait que sous le seuil de cases libres).",
        },
    },
    {
        version = "1.107.5", date = "20/11/2026",
        changed = {
            "Inventaire, roue des réglages : onglets par catégorie à côté du titre (Verrous auto, Protection, Sacs et marchand, Rangement) au lieu d'une longue liste ; l'onglet choisi est retenu, et la recherche ouvre le bon onglet.",
        },
    },
    {
        version = "1.107.4", date = "20/11/2026",
        changed = {
            "Menu Échap avec EllesmereUI : le bouton « Warband Keeper » colle mieux à ses voisins (fond plus sombre, liseré à peine visible) et son nom est en deux tons comme eux (« Keeper » à la couleur de l'apparence).",
        },
    },
    {
        version = "1.107.3", date = "20/11/2026",
        changed = {
            "Paladin : la barre des bénédictions ne s'affiche plus quand tu es seul, seulement en groupe, en raid ou en donjon. Réglage « Aussi quand je suis seul » (QoL > Classes > Paladin > Bénédictions) pour la garder tout le temps.",
        },
    },
    {
        version = "1.107.2", date = "20/11/2026", restart = true,
        changed = {
            "Rappels : icônes au style de l'addon (« trait clair ») : pictogramme blanc sur disque graphite, liseré de l'état (rouge qui bat, orange, gris). Les buffs à lancer gardent l'icône de leur sort.",
        },
        added = {
            "Deux pictogrammes : fiole (poisons) et patte (familier).",
        },
    },
    {
        version = "1.107.1", date = "20/11/2026",
        fixed = {
            "Montée en niveaux : l'en-tête de la carte ne chevauche plus les chiffres de droite (« NIVEAU 28 » à gauche, « 75 % · reste 10 279 XP » à droite).",
            "Montée en niveaux : les objectifs de la quête suivie ne s'affichent plus sous une étape sans rapport (point de vol, maître…).",
        },
    },
    {
        version = "1.107.0", date = "20/11/2026",
        changed = {
            "Rappels : la grande pile laisse place à une barre d'icônes, une pastille ronde par rappel et rien d'autre. Liseré rouge qui bat = urgent, orange = bientôt, gris = quand tu as le temps ; le temps restant en petit dessous.",
            "Rappels : survol = le détail ; clic = l'action (lancer le buff, guider, ouvrir) ; clic droit = « plus tard » (masqué 30 min).",
        },
        added = {
            "Rappels : messages éclair. Un nouveau rappel important s'affiche 5 s en toutes lettres à côté de la barre, puis il ne reste que son icône.",
            "Mode édition, Rappels : « Affichage » Icônes ou Liste (l'ancienne pile) et « Messages éclair » à couper.",
        },
    },
    {
        version = "1.106.2", date = "20/11/2026",
        changed = {
            "Montée en niveaux : la carte à l'écran prend le design de la carte de tournée (texte ombré sur fond léger, en-tête niveau et avancée, fine barre d'XP, étape en cours avec sa pastille, objectifs, 2 étapes suivantes). Les boutons Arrêter, Passer et Lancer apparaissent au survol.",
        },
    },
    {
        version = "1.106.1", date = "20/11/2026",
        changed = {
            "Retour au corps : le temps de course n'est plus répété sous le titre ; la ligne dit seulement la distance du corps.",
        },
    },
    {
        version = "1.106.0", date = "20/11/2026",
        added = {
            "Quêtes de groupe annoncées : « groupe » dans « Quêtes de ma zone », « (groupe) » après leur nom dans la tournée et la carte de tournée (265 quêtes repérées : un monstre élite à tuer, ou un objet qui ne tombe que sur des élites).",
            "Réglage « Éviter les quêtes de groupe » (Quêtes > roue > Quête suivie) : elles sont décochées d'office et la tournée ne prévoit pas de suite de groupe ; tu peux toujours les cocher à la main.",
        },
        changed = {
            "Quêtes automatiques : « Pas les quêtes de groupe » écarte aussi les quêtes de groupe repérées ainsi, en plus de celles que le jeu conseille à plusieurs.",
        },
    },
    {
        version = "1.105.5", date = "20/11/2026",
        changed = {
            "Tournée de quêtes : une étape à faire affiche seulement le nom de ses quêtes (plus de « Coin nord : … »).",
        },
    },
    {
        version = "1.105.4", date = "20/11/2026",
        fixed = {
            "Guidage : après un détour (marchand pour vider les sacs, boîte aux lettres, maître…), la tournée de quêtes ou la quête suivie reprend le guidage. Avant, il n'y avait plus de guidage pour la suite de la tournée.",
        },
    },
    {
        version = "1.105.3", date = "20/11/2026",
        fixed = {
            "Paladin : un clic sur une ligne du panneau des bénédictions (ou sur l'aura) lance de nouveau la bénédiction sur le bon joueur. Le sort passe maintenant par une macro « /cast », comme le bouton « Buffer le suivant », et ne part qu'une fois, au relâché du clic.",
            "Paladin : quand tout le monde a déjà sa bénédiction, le clic sur une ligne renouvelle celle qui finit le plus tôt (avant : le clic ne faisait rien).",
        },
    },
    {
        version = "1.105.2", date = "20/11/2026",
        changed = {
            "Guidage : le trajet suit davantage les chemins connus et ceux que tu as déjà parcourus, au lieu de couper en ligne droite à travers champs, falaises ou eau (hors chemin trois fois plus coûteux, chemins appris nettement préférés).",
        },
        added = {
            "« /wk nav » dit si l'apprentissage des chemins est actif, ce qu'il a appris depuis la connexion et combien de mètres du trajet en cours passent hors des chemins connus.",
        },
    },
    {
        version = "1.105.1", date = "20/11/2026",
        fixed = {
            "Tournée de quêtes : les étapes passées, et celles d'une quête déjà rendue, disparaissent de la carte du monde et de la carte de l'onglet Tournée (avant : elles restaient affichées, pâlies).",
            "Tournée de quêtes : une étape « Prendre » d'une quête déjà rendue ne bloque plus la tournée.",
        },
    },
    {
        version = "1.105.0", date = "20/11/2026",
        added = {
            "Sacs : option « Ouvrir tout seul certains objets » (Inventaire > roue > Sacs, marchand et équipement). Les palourdes et les objets de ta liste (glissés sur la case) s'ouvrent un par un, hors combat ; ou, au choix, tout ce qui s'ouvre sauf les coffrets fermés à clé. Jamais chez un marchand, à la banque, à la boîte aux lettres, à l'échange ou à l'hôtel des ventes, ni sans case libre. Coupée par défaut.",
        },
    },
    {
        version = "1.104.2", date = "20/11/2026",
        fixed = {
            "Quêtes : « La chute de Dun Modr » n'est plus proposée avant « Une tâche sinistre » (Les Paluns), comme le demande le jeu.",
        },
    },
    {
        version = "1.104.1", date = "20/11/2026",
        added = {
            "Minicarte : notre repère du lieu guidé (étape de la tournée, quête suivie), de la couleur de l'étape avec sa lettre (! prendre, ? rendre, $ acheter), posé au bord de la minicarte quand il est plus loin.",
            "Chez un marchand qui vend un objet demandé par une de tes quêtes, sa boutique s'ouvre d'elle-même quand son dialogue propose plusieurs choix (quêtes, foyer, « Je voudrais acheter »), après ses quêtes à prendre ou à rendre. Pas en mode manuel ni avec Maj enfoncée.",
        },
        changed = {
            "« Masquer les repères de quête du jeu » vaut aussi pour la minicarte : les points d'interrogation et zones d'objectifs du jeu y sont masqués et remis quand le réglage est coupé.",
        },
    },
    {
        version = "1.104.0", date = "20/11/2026",
        added = {
            "Tournée de quêtes : étape « Acheter » pour les quêtes qui demandent un objet vendu (79 quêtes, comme La IIIe flotte). Elle mène chez le marchand de ta faction le plus proche qui le vend, avant le rendu, et se valide dès que l'objet est dans tes sacs. Plusieurs achats chez le même marchand forment une seule étape.",
            "Sans marchand connu sur ton continent, l'objet est signalé sur l'étape de rendu (« à acheter : … »).",
            "Chez le marchand : bouton « Pour tes quêtes » sous sa fenêtre, qui achète la quantité qui manque aux quêtes de ton journal. Achat sans clic en option (Quêtes > roue > Quêtes automatiques > Détails > Acheter), jusqu'à un plafond réglable (1 po par défaut) ; Maj enfoncée garde la main.",
        },
        fixed = {
            "Tournée de quêtes : un objet à acheter n'envoie plus là où il tombe d'un monstre rare.",
        },
    },
    {
        version = "1.103.0", date = "20/11/2026",
        added = {
            "Paladin : en groupe, en raid ou en donjon, le bouton « Buffer le suivant » prend le relais du panneau des bénédictions. Il bénit chaque membre avec la bénédiction que la répartition lui donne (et le Salut), d'abord ceux qui ne l'ont pas, puis ceux dont elle finit le plus tôt. En donjon, il s'affiche même si « En instance » est coupé.",
            "Prêtre, mage, druide : en raid, le bouton « Buffer le suivant » passe aussi sur tous les membres du raid (avant : seulement le groupe de 5).",
        },
    },
    {
        version = "1.102.3", date = "20/11/2026",
        added = {
            "« /wk bateau » note maintenant chaque apparition et disparition du bandeau avec sa raison (quai à N m, à bord, plus de quai…), ainsi que la distance aux quais des trajets appris en jeu.",
        },
    },
    {
        version = "1.102.2", date = "20/11/2026",
        fixed = {
            "Bateaux : le bandeau n'apparaît et ne disparaît plus sans cesse sur le ponton. « À bord » ne s'affiche qu'après 4 s de traversée et 25 m parcourus, l'arrêt après une course à monture ne passe plus pour un départ du navire, et le bandeau du quai reste 8 s quand on s'éloigne un instant.",
        },
    },
    {
        version = "1.102.1", date = "20/11/2026",
        fixed = {
            "Bateaux : le bandeau « À bord » ne s'affiche plus en marchant sur le ponton. Un arrêt juste avant la mesure passait pour un départ du navire (« début … 4 m/s » dans /wk bateau) ; il faut maintenant deux mesures de suite.",
        },
    },
    {
        version = "1.102.0", date = "20/11/2026",
        added = {
            "Tournée de quêtes : les suites sont prévues. La quête qui suit une quête cochée est prise à son rendu et ses objectifs entrent dans la même boucle, au lieu de repartir en arrière ensuite. Elle est marquée « (suite) » tant qu'elle n'est pas prise.",
            "Tournée de quêtes : « Sur ton chemin ». Pendant la tournée, une ligne sous les étapes suivantes propose une quête toute proche du trajet, pas encore dans la tournée, avec le détour et l'XP. Clic gauche pour l'ajouter, clic droit pour l'ignorer.",
            "Onglet Tournée : nombre de retours sur tes pas et de suites prévues sous le titre.",
        },
        changed = {
            "Tournée de quêtes : calcul en boucles. Tout est pris au camp, les zones de quête sont faites dans l'ordre d'un tour, puis tout est rendu en une fois ; un rendu sur le trajet est fait en passant. Une quête dont les objectifs sont dans deux zones a une étape dans chacune (avant : un point au milieu des deux).",
        },
    },
    {
        version = "1.101.14", date = "20/11/2026",
        added = {
            "Quêtes de ma zone : bouton « Compléter la zone ». Il coche toutes les quêtes de la zone où tu es, même celles un peu au-dessus de ton niveau, et lance la tournée depuis ta position.",
            "Carte > Bateaux : curseur « Distance d'apparition du bandeau » (10 à 100 m). « /wk bateau » donne ta distance aux quais proches.",
        },
        fixed = {
            "Bateaux : le bandeau du quai n'apparaît plus qu'au bout du ponton (30 m du point d'arrêt du navire par défaut, au lieu de 60 m).",
        },
    },
    {
        version = "1.101.13", date = "20/11/2026",
        fixed = {
            "Tournée et « Quêtes de ma zone » : les quêtes à porter ou à livrer (sans zone d'objectifs connue) étaient écartées ; elles sont maintenant proposées dès que leur rendu est dans la zone (prendre, puis rendre).",
        },
        added = {
            "Tournée : quand une quête rendue a une suite dans la zone, la tournée est refaite pour l'inclure (« Suite ajoutée à la tournée : … »).",
            "« Quêtes de ma zone » : sous la liste, combien de quêtes de la zone ne sont pas proposées et pourquoi (après une autre quête, trop hautes, trop basses, sans lieu connu).",
        },
    },
    {
        version = "1.101.12", date = "20/11/2026",
        fixed = {
            "Tournée de quêtes : juste après avoir pris une quête, le jeu ne donne pas encore ses objectifs ; la tournée prenait cette liste vide pour « tout est fait », sautait l'étape « faire » et demandait de rendre la quête tout de suite. Une quête du journal pas finie garde maintenant son étape tant que ses objectifs ne sont pas faits.",
        },
    },
    {
        version = "1.101.11", date = "20/11/2026",
        changed = {
            "Carte du monde : zones de quête plus fines. Remplissage léger et contour fin en pointillés (même épaisseur quelle que soit la taille de la zone), sans halo ni gros anneau qui grossissait avec les grandes zones.",
        },
    },
    {
        version = "1.101.10", date = "20/11/2026",
        fixed = {
            "Carte de tournée : le titre de l'étape et les objectifs étaient coupés. Le titre passe sur deux lignes au besoin, et un objectif garde le nom seul suivi du compte (« Murloc Branchie-bleue  0/12 » au lieu de « Murloc Branchie-bleue : 0/12 personnages tué… »), sur deux lignes s'il le faut.",
        },
    },
    {
        version = "1.101.9", date = "20/11/2026",
        fixed = {
            "Bandeau des bateaux : il apparaissait à 200 m du quai, bien avant d'y être. Il faut maintenant être sur le ponton (60 m du point d'arrêt du navire) ; il disparaît à 85 m.",
        },
    },
    {
        version = "1.101.8", date = "20/11/2026",
        changed = {
            "Carte du monde : plus d'étiquette (nom, genre, distance) sous l'épingle du guidage, qu'il mène à une étape de tournée, un marchand, un maître… La carte est moins chargée ; tout est dans l'infobulle au survol de l'épingle, distance comprise.",
        },
    },
    {
        version = "1.101.7", date = "20/11/2026",
        added = {
            "Carte de tournée à l'écran : une petite roue parmi les boutons du survol ouvre directement les réglages de la page Quêtes (dont « Fond de la carte de tournée » pour l'opacité du fond).",
        },
    },
    {
        version = "1.101.6", date = "20/11/2026",
        changed = {
            "Page Quêtes, roue des réglages : sur une fenêtre assez large, les cartes sont rangées en deux colonnes (à gauche quête suivie, quêtes montrées et légende ; à droite les quêtes automatiques et leurs détails) pour tenir dans la fenêtre ; une seule colonne sur une fenêtre étroite.",
        },
    },
    {
        version = "1.101.5", date = "20/11/2026",
        fixed = {
            "Montée en niveaux : l'interrupteur du maître de classe ne pouvait pas se rallumer, et l'étape « Maître de classe » du guide restait affichée une fois coupé. L'option s'appelle maintenant « Maître de classe » et règle les deux (étape du guide et étape de la tournée) ; la tournée en cours est refaite en la changeant.",
            "« Recalculer » ne faisait rien : il relisait des résultats gardés quelques secondes. Il recalcule maintenant tout (zones, étapes, quêtes de la zone), refait la tournée en cours et le dit dans le chat.",
        },
    },
    {
        version = "1.101.4", date = "20/11/2026",
        fixed = {
            "Menu Échap : avec EllesmereUI, le bouton « Warband Keeper » restait rouge (style du jeu). Il prend maintenant le même style que les boutons voisins : fond sombre, fin liseré, même police ; sans habillage, il garde celui du jeu.",
        },
    },
    {
        version = "1.101.3", date = "20/11/2026",
        added = {
            "Roue de la page Quêtes, carte « Quête suivie » : réglage « Fond de la carte de tournée » (opacité de 0 à 100 %, 50 % d'office ; 0 % = texte seul, ombré).",
        },
    },
    {
        version = "1.101.2", date = "20/11/2026",
        changed = {
            "Carte du monde : la barre de filtres (courrier, marchands, maîtres, carte…) est transparente au repos et redevient pleine au survol de la souris (ou menu de détail ouvert), avec un fondu doux.",
        },
    },
    {
        version = "1.101.1", date = "20/11/2026",
        added = {
            "Tournée de quêtes : quand des sorts sont à apprendre, la tournée passe par le maître de classe le plus proche (étape bleue « Maître de classe : N sort(s) à apprendre », placée là où elle rallonge le moins le trajet ; finie après la visite). Option « Maître de classe dans la tournée » sous le guide de la Montée en niveaux (activée d'office).",
        },
        changed = {
            "Carte du monde : les pastilles numérotées de la tournée sont à la taille des autres repères (rares, marchands) ; deux étapes au même endroit partagent une pastille « 2·30 » au lieu de se chevaucher.",
        },
    },
    {
        version = "1.101.0", date = "20/11/2026", restart = true,
        added = {
            "Quêtes automatiques (roue de la page Quêtes) : trois modes d'un clic. Manuel : rien d'automatique. Assisté (par défaut) : prend les quêtes cochées dans « Quêtes de ma zone » ou la tournée, rend les quêtes finies, et te laisse choisir la récompense quand il y en a plusieurs. Automatique : prend et rend tout, et choisit la récompense (l'amélioration pour ton perso, sinon la plus chère).",
            "Les 5 dernières quêtes prises ou rendues sont rappelées sous les modes, et dans le chat (« Prise : … », « Rendue : … · récompense »).",
            "Détails repliés sous un bouton : pas les quêtes trop hautes, pas les quêtes de groupe, sauter le dialogue du PNJ, partager avec le groupe, récompense « Pour moi » ou « Plus chère », pas les quêtes qui coûtent de l'or, Maj enfoncée pour garder la main, et des exceptions (la quête suivie ou le PNJ ciblé, jamais en automatique).",
        },
    },
    {
        version = "1.100.19", date = "20/11/2026",
        changed = {
            "Tournée de quêtes, carte à l'écran plus discrète : texte fin et ombré dans un cadre léger et transparent, sans bordure. En tête « TOURNÉE · ZONE », l'avancée, le temps restant et l'XP qui reste à gagner, avec une barre très fine.",
            "Étape en cours avec plus d'infos : niveau de la quête, PNJ (quand il est connu), nombre de quêtes, distance et direction (« 36 m nord-est »), XP du rendu ; objectifs ligne par ligne ; les 2 étapes suivantes avec leur distance.",
            "Pause, passer l'étape et arrêter n'apparaissent qu'au survol de la carte.",
        },
    },
    {
        version = "1.100.18", date = "20/11/2026",
        changed = {
            "Page Quêtes : l'onglet « Tournée » s'appelle maintenant « Tournée de quêtes ».",
        },
    },
    {
        version = "1.100.17", date = "20/11/2026",
        changed = {
            "Page Quêtes : l'onglet « À prendre » s'appelle maintenant « Quêtes de ma zone » (quêtes de la zone où se trouve ton perso, à prendre ou dans ton journal).",
        },
    },
    {
        version = "1.100.16", date = "20/11/2026",
        fixed = {
            "Tournée de quêtes : lancée depuis une autre zone (une capitale…), elle ne gardait que le rendu d'une quête finie à l'autre bout du continent, et cette tournée d'une étape restait une fois arrivé. Une quête finie n'y entre plus que si on la rend dans la zone, et en arrivant dans une autre zone de quêtes la tournée est refaite avec les quêtes cochées d'ici (message dans le chat).",
        },
    },
    {
        version = "1.100.15", date = "20/11/2026",
        changed = {
            "Page Quêtes : l'onglet « Montée » s'appelle maintenant « Montée en niveaux » (et sa carte « Montée en niveaux · niveau N », aussi sur la carte de quête à l'écran).",
        },
    },
    {
        version = "1.100.14", date = "20/11/2026",
        changed = {
            "Guide de montée : un donjon dont tu as déjà fait toutes les quêtes n'est plus proposé (le suivant à ton niveau l'est) ; l'étape donjon dit combien de quêtes il te reste à y faire.",
        },
    },
    {
        version = "1.100.13", date = "20/11/2026",
        changed = {
            "Carte du monde, liste « Rares » : même allure discrète que le volet des quêtes (plus petite, fond léger, texte fin, 8 rares au plus, croix plus petite). Toujours repliable d'un clic sur le titre, déplaçable, et désactivable (croix ou Rares > roue dentée).",
            "Volet des quêtes de la carte : un peu plus large, « rendre » en vert n'est plus coupé.",
        },
    },
    {
        version = "1.100.12", date = "20/11/2026",
        changed = {
            "Page Quêtes : roue des réglages ouverte, les sous-onglets (Montée, Mon journal, À prendre, Tournée) et la barre « Quêtes de » disparaissent ; les réglages remontent juste sous les grands onglets (un clic sur un grand onglet ferme les réglages).",
        },
    },
    {
        version = "1.100.11", date = "20/11/2026",
        changed = {
            "Carte du monde, volet « Quêtes du journal » : plus petit et plus discret (fond léger, texte fin, 6 quêtes au plus) ; « Toutes / Suivie » devient un simple mot cliquable dans l'en-tête ; clic sur le titre : replier (il garde alors juste le nombre de quêtes).",
        },
        added = {
            "Roue de la page Quêtes, carte « Quête suivie » : interrupteur « Volet des quêtes sur la carte » pour le cacher.",
        },
    },
    {
        version = "1.100.10", date = "20/11/2026",
        fixed = {
            "Carte du monde : le tracé du guidage (et ceux des bateaux, des navires et de la tournée de quêtes) était bien calculé mais caché sous les calques de la carte de WoW Forever ; il est maintenant dessiné au-dessus, juste sous nos pastilles. Il se voyait déjà sur la minicarte.",
        },
    },
    {
        version = "1.100.9", date = "20/11/2026",
        changed = {
            "Quêtes : les « camps » s'appellent maintenant « zones de quête » partout (carte du monde, page Quêtes, carte de quête à l'écran, réglages) : « Zone suivante », « Zones : toutes », « 3 zones · la plus proche à 240 m »…",
        },
    },
    {
        version = "1.100.8", date = "20/11/2026",
        changed = {
            "Carte du monde : les zones de quête (camps) sont bien plus visibles : remplissage plus marqué, anneau plein de couleur avec un contour sombre, halo doux autour, et taille minimale plus grande. Elles remplacent les repères du jeu masqués.",
        },
    },
    {
        version = "1.100.7", date = "20/11/2026",
        changed = {
            "Statistiques en vol, « Le savais-tu ? » : toutes les cartes sur une seule page quand elles tiennent (cartes plus compactes, le chiffre à droite du titre ; une carte à graphique en pleine largeur s'il reste la place). Plus de grande carte à moitié vide ; les pages et les flèches ne reviennent que si tout ne tient pas.",
        },
        fixed = {
            "Statistiques en vol : « Trajet le plus pris » était coupé ; le trajet passe sur sa propre ligne, sous le libellé.",
        },
    },
    {
        version = "1.100.6", date = "20/11/2026",
        fixed = {
            "Carte des vols : l'encart « Guidage : vole jusqu'à … » était calculé mais caché sous la carte des vols ; il passe maintenant au-dessus. La destination est aussi marquée sur la carte par un anneau qui clignote.",
        },
    },
    {
        version = "1.100.5", date = "20/11/2026",
        added = {
            "/wk vol diag : ce que l'addon lit de la carte des vols ouverte (relais, positions, relais connus, guidage, vol prévu) et pourquoi l'encart du guidage s'affiche ou pas.",
        },
        fixed = {
            "Carte des vols « classique » de WoW Forever : la position des relais n'était pas lue, donc les trajets ne prévoyaient jamais de vol et l'encart « vole jusqu'à … » ne pouvait pas choisir de relais. Elle est maintenant lue relais par relais sur la carte du continent.",
        },
    },
    {
        version = "1.100.4", date = "20/11/2026",
        fixed = {
            "Carte des vols : l'encart du guidage n'apparaissait que si le trajet prévoyait déjà un vol. Quand ta destination est loin, il propose maintenant aussi le relais le plus proche de ta destination ; il est posé en bas de la carte des vols (dessous, il sortait de l'écran).",
            "Carte de tournée : le bouton « Passer l'étape » montre une flèche vers la droite (elle pointait vers le bas).",
            "Mode édition : pendant une tournée, l'aperçu de la carte de quête montre la carte de tournée.",
        },
    },
    {
        version = "1.100.3", date = "20/11/2026",
        fixed = {
            "Guidage par les vols : arrivé au maître de vol, rien ne disait où aller. La carte des vols affiche maintenant un encart « Guidage : vole jusqu'à … » avec un bouton « Prendre ce vol », et le chat le rappelle ; si ce maître ne propose pas ce vol, l'encart le dit.",
        },
    },
    {
        version = "1.100.2", date = "20/11/2026",
        changed = {
            "Tournée de quêtes, carte à l'écran refaite : pastille du genre d'étape (! doré pour prendre, cible pour faire, ? vert pour rendre), titre et zone, bandeau « distance · env. N min », objectifs avec jauges (coche verte une fois finis), frise d'une case par étape (vertes faites, à l'accent en cours), temps restant, et les 2 étapes suivantes en dessous.",
            "Tournée : pause / reprise, passer l'étape et arrêter deviennent 3 petits boutons ronds en haut à droite ; en pause, la carte se ternit avec « EN PAUSE ».",
        },
    },
    {
        version = "1.100.1", date = "20/11/2026",
        changed = {
            "Page Quêtes, cartes de « Mon journal » et de la « Tournée » : la zone est dessinée en entier (toutes ses parties, découvertes ou pas), comme une carte explorée, au lieu du fond vide.",
        },
    },
    {
        version = "1.100.0", date = "20/11/2026", restart = true,
        added = {
            "Fiche du perso : nouvel onglet « Armes » (entre Sorts et BiS). À gauche, chaque arme apprise avec sa jauge (vert au maximum, orange un peu en retard, rouge très en retard) et « équipée » sur celle en main ; au survol, le retard et comment le rattraper.",
            "Onglet Armes, à droite : les armes que ta classe peut encore apprendre avec leur prix (les armes d'hast à partir du niveau 20), et le maître d'armes le plus proche qui les enseigne, avec « Guider ». Clic sur une arme : guidage vers un maître qui l'enseigne.",
        },
    },
    {
        version = "1.99.7", date = "20/11/2026",
        changed = {
            "Talents : le prochain talent du plan clignote (voile de la couleur de l'apparence sur son icône) au lieu d'être entouré d'un cercle.",
        },
    },
    {
        version = "1.99.6", date = "20/11/2026",
        fixed = {
            "Talents : le cercle du talent suivant pouvait disparaître (panneau rouvert, fenêtre redessinée) sans revenir ; il est reposé tout seul tant que la fenêtre des talents est ouverte.",
        },
        changed = {
            "/wk plan diag dit aussi pourquoi le cercle n'est pas affiché et la version de l'addon.",
        },
    },
    {
        version = "1.99.5", date = "20/11/2026",
        fixed = {
            "Talents : le bouton « Plan de montée » et le cercle du talent suivant étaient bien posés mais restaient cachés sous le décor de la fenêtre des talents de WoW Forever. Ils passent maintenant au-dessus.",
        },
    },
    {
        version = "1.99.4", date = "20/11/2026",
        added = {
            "Carte du monde : les repères de quête du jeu (points d'exclamation, rendus, zones d'objectif) sont masqués tant que nos camps de quête sont affichés, pour ne garder que les nôtres. Interrupteur « Masquer les repères de quête du jeu » dans la roue de la page Quêtes (carte « Quête suivie »).",
        },
    },
    {
        version = "1.99.3", date = "20/11/2026",
        added = {
            "/wk plan diag : ce que l'addon voit de la fenêtre des talents (fenêtre, onglet, bouton « Plan de montée », talent suivant et son cercle), à copier si quelque chose manque.",
        },
        fixed = {
            "Talents : la fenêtre des talents de WoW Forever n'était pas reconnue comme l'onglet des talents (sa partie talents du jeu reste cachée) : le bouton « Plan de montée » et le cercle autour du talent suivant ne s'affichaient pas. Le titre « Talents » de la fenêtre suffit maintenant.",
            "Talents : le cercle du talent suivant retrouve aussi le bouton par son icône sur les fenêtres dont les boutons n'ont pas de champ d'icône.",
            "Menu Échap : le bouton « Warband Keeper » est bien au-dessus d'EllesmereUI (il se retrouvait dessous) et prend l'habillage d'EllesmereUI comme les autres boutons (il restait rouge).",
        },
    },
    {
        version = "1.99.2", date = "20/11/2026",
        fixed = {
            "Barre d'expérience : sur une barre étroite, le texte de droite (repos, XP à rendre, « niveau en rendant tout ») chevauchait le niveau et l'XP. Il se raccourcit maintenant pour tenir (tout reste dans l'infobulle).",
            "Barre d'expérience : un tout petit repos s'affiche « repos < 1 % » au lieu de « repos 0 % ».",
        },
    },
    {
        version = "1.99.1", date = "20/11/2026",
        fixed = {
            "Carte du monde : le calque « Quêtes » plantait (« attempt to perform arithmetic on local 'y' ») quand une quête prête à rendre avait un lieu de rendu connu ; ses repères ne s'affichaient plus.",
            "Carte du monde : l'infobulle du jeu « Partage de repère cartographique » ne s'affiche plus par-dessus notre repère de guidage (le losange du jeu, masqué, ne répond plus à la souris).",
            "Bateaux : la descente au quai n'était jamais reconnue (la traversée finissait seulement après 8 s immobile) ; le bandeau retrouve aussi la ligne du quai de départ.",
            "Réassort chez le marchand (Inventaire, roue) : glisser un objet sur la case l'ajoute de nouveau à la liste (il était ignoré).",
        },
    },
    {
        version = "1.99.0", date = "20/11/2026", restart = true,
        added = {
            "Sorts de classe : prix de base de chaque sort chez le maître, connus d'avance (données de What's Training, licence MIT). Le prix relevé chez le maître, remise de réputation comprise, passe toujours devant ; un sort sans prix connu est estimé d'après ceux du même niveau, marqué « env. ».",
        },
        changed = {
            "Fiche du perso, onglet Sorts : nouvelle présentation en frise. Une ligne par niveau (disponibles, prochain niveau, puis les suivants), les sorts en vignettes et le coût du niveau au bout. En tête : le total maintenant et jusqu'au 60, l'or du compte et « Guider vers le maître ». Clic droit sur une vignette : écarter ou remettre le sort.",
        },
        fixed = {
            "Sorts de classe : un rang remplacé par le rang suivant (auras du paladin, Imposition des mains…) n'apparaît plus comme « à apprendre ».",
            "Sorts de classe : « Jusqu'au 60 » n'affiche plus « env. 0pc » quand les prix ne sont pas encore connus.",
        },
    },
    {
        version = "1.98.7", date = "20/11/2026",
        fixed = {
            "Talents : le bouton « Plan de montée » restait caché derrière le pied de la fenêtre des talents (barre « Appliquer changements »). Il passe maintenant au premier plan, en bas à droite.",
        },
    },
    {
        version = "1.98.6", date = "20/11/2026",
        fixed = {
            "Repère de rendu de quête : il s'affichait en carré doré au lieu du médaillon rond ; il est maintenant rond, avec un reflet clair en haut.",
        },
        changed = {
            "Cartes de Mon journal et de la Tournée : repères plus petits (camps, étapes numérotées, rendu, ta position) ; repère de rendu un peu plus petit aussi sur la carte du monde.",
        },
    },
    {
        version = "1.98.5", date = "20/11/2026",
        added = {
            "Menu du jeu (Échap) : bouton « Warband Keeper » qui ouvre la fenêtre, placé juste au-dessus d'EllesmereUI (ou d'« Add-ons » sans lui). Interrupteur « Raccourci dans le menu du jeu » dans Options > Général > Fenêtre.",
        },
    },
    {
        version = "1.98.4", date = "20/11/2026",
        fixed = {
            "Page Quêtes : erreur « Font not set » à l'ouverture (le nouveau repère de rendu écrivait son « ? » avant d'avoir sa police, et la police des titres d'une autre addon pouvait ne pas se charger).",
        },
    },
    {
        version = "1.98.3", date = "20/11/2026",
        changed = {
            "À la connexion et après un /reload, chaque page s'ouvre sur son premier onglet (Quêtes : Carte des zones ; Classes : Général ; Options, Statistiques, Métiers, sections de QoL, hôtel des ventes, courrier, pêche…). L'onglet choisi reste retenu pendant la séance.",
        },
    },
    {
        version = "1.98.2", date = "20/11/2026",
        changed = {
            "Repère de rendu de quête redessiné : médaillon doré bombé, liseré clair, « ? » sombre au centre et légère lueur dorée, à la place du gros disque noir. Partout : carte du monde, grande carte de la page Quêtes et détail du rendu.",
        },
    },
    {
        version = "1.98.1", date = "20/11/2026",
        fixed = {
            "Le « ~ » des estimations s'affichait mal avec la police du jeu : remplacé par « env. » partout (étapes de tournée, durées du guide de montée et de la carte de quête, coût des sorts jusqu'au 60, retour au corps, temps restant des enchères, repos, taille de la sauvegarde).",
        },
    },
    {
        version = "1.98.0", date = "20/11/2026",
        changed = {
            "Page Quêtes : deux grands onglets en haut, « Carte des zones » (onglet principal, ouvert par défaut) et « Ma progression » ; dans Ma progression, les sous-onglets Montée, Mon journal, À prendre et Tournée.",
            "Mon journal et Tournée : la carte de la zone passe au premier plan (deux tiers de la largeur, toute la hauteur), liste et détail dans une colonne à gauche. Camps de toutes tes quêtes sur la carte (la quête choisie en avant, étiquettes « objectif · 3/8 »), survol d'une quête = ses camps s'allument, clic sur un camp ou une étape = guidage.",
        },
    },
    {
        version = "1.97.4", date = "20/11/2026",
        changed = {
            "Pastille de l'icône Options toujours rouge (patch notes pas lues ou erreur pas vue), et pastille rouge aussi sur la section concernée des Options (Patch notes ou Fiabilité) ; elle s'éteint une fois lues ou vues.",
        },
    },
    {
        version = "1.97.3", date = "20/11/2026",
        added = {
            "Fenêtre des talents : bouton « Plan de montée » en bas à droite pour ouvrir ou fermer le panneau du plan (plein quand le panneau est ouvert). Il n'apparaît que sur l'onglet des talents et si le perso a un plan.",
        },
    },
    {
        version = "1.97.2", date = "20/11/2026",
        changed = {
            "QoL > Classes : nouvel onglet « Général » avant les 9 classes (icône : les logos des classes en mosaïque), pour les réglages communs à toutes les classes. Les réglages des sorts de classe (rappel, panneau chez le maître, tout apprendre) y sont rangés et quittent la roue de la fiche du perso.",
        },
    },
    {
        version = "1.97.1", date = "20/11/2026",
        changed = {
            "Rien ne change en jeu : cette version livre le client PC 1.8.8 (plus de consigne de redémarrage quand le jeu est fermé pendant la mise à jour).",
        },
    },
    {
        version = "1.97.0", date = "20/11/2026", restart = true,
        added = {
            "Fiche du perso, onglet « Sorts » : sorts de classe à apprendre maintenant, au prochain niveau et plus tard, avec leur prix ; coût jusqu'au 60 et ce que l'or du compte permet de payer ; maître le plus proche. Marche aussi pour les persos pas connectés. Clic droit sur un sort : l'écarter (il n'est plus compté ni proposé).",
            "Chez ton maître de classe : panneau « À apprendre ici » avec les prix et « Tout apprendre » (les moins chers d'abord, sans dépasser ton or, sans les sorts écartés). Les prix vus chez le maître sont retenus pour tous tes persos de la même classe.",
            "Rappel au passage de niveau : « Niveau N : n sort(s) à apprendre (coût) » avec Guider ; ligne dans « À faire » du Résumé pour chaque perso concerné ; le guide de montée affiche le vrai nombre de sorts.",
            "Réglages dans la roue de la fiche, onglet Sorts : rappel, panneau, tout apprendre en ouvrant le maître.",
        },
    },
    {
        version = "1.96.0", date = "20/11/2026", restart = true,
        added = {
            "Guide de montée calculé en direct (de quoi se passer d'un guide écrit d'avance) : nouvel onglet « Montée » en tête de la page Quêtes.",
            "Où monter maintenant : les 3 meilleures zones pour ton niveau, d'où tu es (XP des quêtes faisables, temps de quête et de trajet, niveau atteint, point de vol à apprendre) ; « Y aller » ou « Préparer la tournée ».",
            "Étapes du guide, recalculées à chaque quête rendue, niveau ou zone : objet qui démarre une quête, maître de classe aux niveaux pairs, point de vol de la zone, pierre de foyer à lier, tournée de la zone, donjon à ton niveau, zone suivante. « Suivre ce guide » les enchaîne (la tournée suivante se lance seule) ; Sans donjons, Sans métiers.",
            "Carte de quête à l'écran : quand tu suis le guide, elle montre « Montée · niveau N », la progression du niveau, l'étape en cours et la suivante (Passer, Lancer).",
            "Objet ramassé qui démarre une quête : rappel « clic droit dessus » (206 objets connus).",
            "Le temps réel de chaque quête (prise » rendue) est noté et affine les durées des tournées ; une quête rendue qui a une suite dans le coin l'ajoute à la tournée en cours.",
        },
    },
    {
        version = "1.95.0", date = "20/11/2026", restart = true,
        added = {
            "Page Quêtes, onglet « À prendre » : les quêtes de ton journal et celles que ton perso peut prendre autour de toi, regroupées par coin (quêtes dont les objectifs sont au même endroit), avec XP, niveau en couleur et distance au donneur ; coche celles à faire (les trop dures sont décochées d'office). « Guider vers les donneurs » mène au plus proche.",
            "Onglet « Tournée » : l'ordre le plus court pour les quêtes cochées (prendre, faire les camps, rendre), les objectifs d'un même coin en une seule étape, durée et distance estimées, mini-carte avec les étapes numérotées. Lancer, passer une étape, pause, réordonner depuis là où tu es, arrêter.",
            "Pendant une tournée, la carte de quête à l'écran montre l'étape en cours, ses objectifs, le temps restant et l'étape suivante ; la flèche passe toute seule à l'étape suivante. Bilan dans le chat à la fin (étapes, temps, XP, quêtes rendues).",
            "Carte du monde : étapes de la tournée numérotées (or : prendre, accent : faire, vert : rendre) et reliées.",
            "Alerte quand tu passes près du donneur d'une quête utile pour ton niveau ; réglages dans la roue de la page Quêtes (alerte, quêtes au-dessus de ton niveau).",
        },
    },
    {
        version = "1.94.0", date = "20/11/2026", restart = true,
        added = {
            "Quête suivie : coche une quête dans le journal du jeu (ou clique « Suivre » dans l'addon) ; une carte à l'écran montre ses objectifs avec leurs jauges, « Camp suivant » et « Rendu ». À placer en mode édition.",
            "La flèche guide vers le camp le plus proche d'un objectif pas fini (monstres, objets à ramasser, objets au sol), puis vers le personnage qui reprend la quête quand tout est fait. Elle ne remplace jamais un autre guidage en cours.",
            "Carte du monde : camps des objectifs en pointillés (orange pour un objet à ramasser), étiquette avec l'avancée, « ? » doré où rendre une quête prête ; clic sur un camp = guidage. Volet « Quêtes du journal » en bas à gauche de la carte : clic = suivre, bouton pour voir les camps de toutes les quêtes.",
            "Page Quêtes : nouvel onglet « Mon journal » (quêtes rangées par zone, détail des objectifs avec camps et distance, point de rendu, mini-carte, Suivre / Voir sur la carte) ; nouvelles pastilles Journal, À rendre et Suivie ; réglages du suivi dans la roue.",
        },
    },
    {
        version = "1.93.0", date = "20/11/2026",
        added = {
            "Apparence > Styles : trois habillages qui changent la forme de toute la fenêtre, pas seulement ses couleurs. Héraldique : barre latérale pleine, titres des cartes sur un bandeau coloré, 1re pastille pleine. Encre : cartes sans fond ni bordure avec un trait de couleur à gauche, grands titres, boutons pleins. Cuir et or : fond de cuir, titres centrés soulignés d'un filet doré, cartes à double liseré, jauges dorées.",
        },
        changed = {
            "Les anciens styles de couleurs (Nuit bleue, Forêt, Or ancien, Améthyste, Braise) sont remplacés par ces habillages ; Graphite reste le style d'origine. La couleur, la police et le reste se règlent toujours dans les autres onglets.",
        },
    },
    {
        version = "1.92.2", date = "20/11/2026",
        changed = {
            "Hôtel des ventes : acheter une enchère unique demande deux clics (« Confirmer <prix> »), pour ne plus acheter par erreur.",
            "Courrier : envoyer de l'or demande un 2e clic sur Envoyer, comme dans la fenêtre du jeu.",
            "Marchand : les boutons d'achat et le Réassort ignorent les objets payés en jetons ou en objets.",
            "Options > Apparence et Profils : la disposition s'adapte aux fenêtres étroites (aperçu et partage passent dessous) ; un style prêt n'est plus marqué choisi quand tu en changes un réglage.",
            "Les réglages des bénédictions (barre, Salut) font partie des profils.",
        },
        fixed = {
            "Carte sans brouillard : le calque plantait et ne s'affichait jamais.",
            "Courrier : pendant « Tout prendre », les boutons restaient cliquables et une 2e prise pouvait démarrer par-dessus.",
            "Courrier et banque : l'envoi automatique, le Rangement et le dépôt pouvaient joindre un autre objet si les sacs avaient bougé, ou envoyer une lettre vide.",
            "Hôtel des ventes : un prix qui changeait pendant l'achat d'une marchandise bloquait le bouton Acheter.",
            "Un objet verrouillé puis équipé perdait son verrou.",
            "Bouton de rechargement : en combat, il restait accroché à la fenêtre, qui risquait d'être bloquée ; « Recharger maintenant » ne marchait pas si la 1re demande arrivait en combat.",
            "Micro menu : les raccourcis protégés (rechargement, pierre de foyer) partent au relâchement du clic, même avec l'option « touche enfoncée » du jeu.",
            "Bénédictions : les attributions des autres paladins (et de PallyPower) pour les noms en deux parties arrivaient sur la mauvaise ligne ; un joueur non paladin pouvait créer une fausse ligne ; en combat, une ligne pouvait afficher une autre bénédiction que celle lancée.",
            "Achat automatique chez le marchand : boucle sans fin possible, et coût de la réparation non déduit.",
            "Récolte : les rappels « rang suivant » et « nouvelles ressources » étaient partagés entre tous les persos.",
            "Fiche de personnage : en rouvrant la fenêtre, l'ancien perso choisi restait affiché.",
            "Barre de fabrication : saccades possibles pendant une série.",
            "Médaillons des rares qui restaient sur la carte après les avoir désactivés ; barre de filtres de la carte parfois sous la carte.",
            "Clic sur la barre d'XP : fermait la fenêtre au lieu d'ouvrir QoL > Expérience.",
            "Infobulles du jeu qui gardaient l'ancienne police après un changement de police ou de style ; halo teinté qui ne suivait pas l'accent.",
            "Patch notes : filtres qui dépassaient de la fenêtre ; « Que faire maintenant » qui n'affichait pas le nom du perso.",
            "Bouton du familier du chasseur absent du mode édition ; quelques couleurs qui ne suivaient pas le thème ; distances en mètres en anglais.",
        },
    },
    {
        version = "1.92.1", date = "20/11/2026",
        changed = {
            "Apparence > Styles : chaque style prêt change maintenant toute la fenêtre (fond nettement teinté, fond texturé, polices, arrondi, cartes et halo à la couleur du style), plus seulement la couleur.",
            "Les vignettes des styles sont de petites fenêtres qui montrent le rendu : fond, carte, police des titres et halo.",
        },
    },
    {
        version = "1.92.0", date = "20/11/2026",
        added = {
            "Options > Apparence en onglets (Styles, Couleurs, Texte, Formes, Fenêtre) qui tiennent dans la fenêtre sans défiler, l'aperçu en direct toujours à droite.",
            "Styles prêts : Graphite rose, Nuit bleue, Forêt, Or ancien, Améthyste, Braise (couleur, teinte, arrondi, cartes et police des titres en un clic).",
            "Couleurs : accent par perso (chaque perso garde sa couleur), dégradé d'accent sur les jauges, intensité du halo de la fenêtre.",
            "Texte : police des titres à part, contraste des textes secondaires (doux, normal, fort).",
            "Formes : fond de fenêtre texturé (grain, pierre, parchemin), fondu à l'ouverture (ou aucune animation).",
            "Fenêtre : barre latérale à gauche, à droite ou en icônes seules ; opacité des infobulles.",
            "Partager mon style / Coller un style (code WKS1:…) et « Apparence d'origine » (Maj + clic) en bas de la carte.",
        },
    },
    {
        version = "1.91.1", date = "20/11/2026",
        fixed = {
            "Fiche du perso, roue des réglages ouverte : les onglets Fiche / Talents / BiS de la fiche apparaissaient en double au-dessus de ceux des réglages. Ils sont masqués tant que la roue est ouverte ; seuls les onglets des réglages restent, à leur place.",
        },
    },
    {
        version = "1.91.0", date = "20/11/2026",
        added = {
            "Options > Apparence refaite : réglages groupés (Couleurs, Texte, Formes, Fenêtre) avec un aperçu en direct à droite (titre, pastille, carte avec jauge, boutons, interrupteur) qui suit chaque changement.",
            "Nouveaux réglages : 3 couleurs d'accent en plus (rose, rouge, argent) et ta couleur à toi en code #RRGGBB ; teinte du fond (froid, neutre, chaud) ; 2 polices en plus (Morpheus, Skurri) ; taille du texte (85 à 125 %) ; arrondi au curseur (de carré à très rond) ; style des cartes (plat, liseré, halo).",
        },
    },
    {
        version = "1.90.5", date = "20/11/2026",
        changed = {
            "Point sur l'icône des Options (en haut à droite) : son infobulle dit maintenant ce qu'il signale (des nouveautés pas encore lues, ou en rouge une erreur de l'addon pas encore vue), et un clic mène droit aux Patch notes ou à Fiabilité. Il s'éteint une fois lu.",
        },
    },
    {
        version = "1.90.4", date = "20/11/2026",
        changed = {
            "Options > Profils plus aéré : marges plus larges, chaque profil sur deux lignes (nom, puis « utilisé par… »), et dans Partager le code sur deux lignes, une case plus haute pour coller un code et un trait entre Exporter et Importer.",
        },
        added = {
            "Profils : bouton « Supprimer » (Maj + clic) sur chaque profil sauf « Défaut », y compris celui de ce perso, qui repasse alors sur « Défaut » (rechargement proposé).",
        },
    },
    {
        version = "1.90.3", date = "20/11/2026",
        fixed = {
            "Icône « Recharger l'interface » de l'en-tête : toujours sans effet. Le bouton qui lance /reload est maintenant posé une strate au-dessus de la fenêtre de l'addon, pour que rien de la fenêtre ne le recouvre.",
        },
        added = {
            "/wk rechargement : diagnostic des boutons de rechargement (affichés, devant ou non, souris dessus, dernier clic reçu).",
        },
    },
    {
        version = "1.90.2", date = "20/11/2026",
        changed = {
            "Options > Profils refait : une carte en deux colonnes. À gauche « Mes profils » : chaque profil sur sa ligne avec les persos qui l'utilisent et ses actions (Utiliser, Exporter, Copier, Supprimer en Maj + clic), le tien encadré avec la pastille « ce perso », Créer en haut et Réinitialiser en bas.",
            "À droite « Partager » : le code du profil choisi (« Exporter » sur une ligne, le tien d'office) prêt à copier, et une case pour coller un code avec un aperçu immédiat (« Code valide : « Raid », 12 groupes de réglages » ou la raison du refus) avant d'importer.",
        },
    },
    {
        version = "1.90.1", date = "20/11/2026",
        fixed = {
            "Icône « Recharger l'interface » de l'en-tête (et bouton « Recharger » des modules) : le clic ne faisait plus rien dès que la fenêtre de l'addon passait au premier plan ; le bouton qui lance /reload restait caché dessous. Il est remonté au survol et part au relâchement du clic.",
        },
    },
    {
        version = "1.90.0", date = "20/11/2026",
        added = {
            "Options > Profils : carte « Partager un profil ». « Exporter » affiche le code du profil choisi (à copier avec Ctrl+C) ; « Importer » : colle un code (Ctrl+V), avec un nom si tu veux, et il devient un nouveau profil (« (2) » ajouté si le nom existe déjà). Rien ne change avant que tu le choisisses pour ton perso.",
            "Seuls les réglages passent dans le code (jamais tes données : persos, prix, journaux) ; un code abîmé ou qui n'est pas un code de profil est refusé avec la raison.",
        },
    },
    {
        version = "1.89.2", date = "20/11/2026",
        changed = {
            "Options > Général > Infobulles : les réglages sont rangés en cartes par thème au lieu d'une seule longue liste : Apparence des infobulles, Objets : prix (HV, pile, désenchantement), Objets : métiers (montée, fabriquer ou vendre), Objets : butin (butin observé), PNJ (quêtes du donneur, rares).",
        },
    },
    {
        version = "1.89.1", date = "20/11/2026",
        fixed = {
            "Changer de profil (Options > Profils) déclenchait l'erreur « a tenté d'appeler la fonction protégée Reload() » : le jeu interdit à un addon de recharger l'interface de lui-même. Une petite fenêtre propose maintenant « Recharger maintenant » (ou « Plus tard ») ; copier ou remettre à zéro un profil font de même.",
            "Même cause corrigée sur le raccourci « Recharger l'interface » du micro menu, l'icône de rechargement de l'en-tête et le bouton « Recharger » de la carte Modules : ils lancent /reload par un bouton du jeu (indisponibles en combat).",
        },
    },
    {
        version = "1.89.0", date = "20/11/2026",
        added = {
            "Fiche du perso : en haut à droite, des pastilles comme dans l'en-tête de l'addon à la place du « niv. moyen » seul. Par défaut niveau d'objet (mis en avant), armure et durabilité ; dans la roue, carte « En-tête : pastilles », choisis jusqu'à 5 chiffres parmi niveau d'objet, armure, durabilité, sacs libres, Force, Agilité, Endurance, Intelligence, Esprit, puissance d'attaque, critique, toucher, puissance des sorts, soins, critique des sorts, esquive, parade, blocage et or (dans l'ordre des clics).",
        },
        changed = {
            "Roue de la fiche : réglages rangés en onglets Fiche / Talents / BiS ; elle s'ouvre sur l'onglet affiché.",
        },
    },
    {
        version = "1.88.2", date = "20/11/2026",
        added = {
            "Barre d'expérience : réglage « Place du texte » (QoL > Expérience) pour mettre le niveau, le repos et l'XP à rendre au-dessus ou en dessous de la barre.",
        },
    },
    {
        version = "1.88.1", date = "20/11/2026",
        fixed = {
            "Plan de montée : le panneau (et un cercle mal placé) s'ouvraient aussi sur le Grimoire, qui partage la même fenêtre que les Talents. Ils n'apparaissent plus que sur l'onglet des talents, et suivent le passage d'un onglet à l'autre sans rouvrir la fenêtre.",
        },
    },
    {
        version = "1.88.0", date = "20/11/2026",
        added = {
            "Fiche du perso : petite roue en haut à droite avec les réglages des trois onglets, une carte chacun. Fiche : niveau d'objet sur les icônes, point bleu des objets enchantés, stats utiles en couleur. Talents : panneau collé à la fenêtre des talents du jeu, cercle autour du prochain talent, rappel du prochain talent (nouveau). BiS : ligne « Liste BiS de… » dans les infobulles (nouveau).",
        },
        changed = {
            "Les deux interrupteurs qui étaient sous les plans de montée (onglet Talents) sont dans cette roue.",
        },
    },
    {
        version = "1.87.7", date = "20/11/2026",
        fixed = {
            "Les fenêtres collées à une fenêtre du jeu prennent son niveau : plan de montée (fenêtre des talents), panneau du marchand et bouton Réassort, panneau de l'HV, Rangement au courrier, valeur des sacs, désenchantement, enchantements à l'échange, colonne du maître de métier, barre de fabrication collée au métier, panneau du donjon sur la carte. Avant, elles passaient au-dessus de tout, même de la fenêtre de l'addon ouverte par-dessus.",
            "Le cercle du prochain talent suit aussi le niveau de la fenêtre des talents.",
        },
    },
    {
        version = "1.87.6", date = "20/11/2026",
        added = {
            "Plans de montée : réglage « Cercle autour du prochain talent dans la fenêtre du jeu », à côté de « Panneau collé à la fenêtre des talents du jeu » (fiche du perso > Talents, carte Plans de montée).",
        },
        fixed = {
            "Plans de montée : le cercle qui montre le prochain talent à prendre n'apparaissait pas dans la fenêtre des talents de WoW Forever ; le talent est maintenant retrouvé parmi ses boutons (par son nœud, sinon son icône), aussi quand la fenêtre met un instant à s'afficher.",
        },
    },
    {
        version = "1.87.5", date = "20/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : il restait bloqué sur un joueur qui avait déjà le buff d'un autre lanceur (Puissance d'un autre paladin, souvent plus forte) dès que ce buff approchait de sa fin ; le jeu refusait le sort et le bouton ne passait pas au suivant.",
            "Maintenant, le buff d'un autre joueur n'est jamais remplacé (seul le tien est rafraîchi avant la fin), et si le jeu refuse le sort juste après ton clic (sort plus puissant déjà actif, hors de vue…), ce joueur est passé pendant 2 min et le bouton va au suivant.",
        },
    },
    {
        version = "1.87.4", date = "20/11/2026",
        changed = {
            "Carte des bateaux : les zeppelins sont en orange (tracés et pastilles de la liste), bien distincts des bateaux en bleu et de la carte dorée.",
        },
    },
    {
        version = "1.87.3", date = "20/11/2026",
        fixed = {
            "Carte des bateaux : les tracés se voyaient mal sur la carte du jeu, surtout les zeppelins ; traits plus épais et plus clairs avec un contour sombre, zeppelins en longs tirets or vif, lignes estompées moins pâles.",
        },
    },
    {
        version = "1.87.2", date = "20/11/2026",
        changed = {
            "Carte des bateaux : le fond est la carte d'Azeroth du jeu, dans ses couleurs d'origine (sans la flèche ni les repères), à la place des continents assombris ; fenêtre un peu plus large pour qu'elle tienne en entier. Noms des quais contourés, lisibles sur la carte.",
        },
        fixed = {
            "Carte des bateaux : une ligne aller-retour (Auberdine - Hurlevent) était tracée deux fois en deux arcs ; une seule courbe par trajet. Les noms près des bords (Bastion de Plumelune) ne sont plus coupés.",
        },
    },
    {
        version = "1.87.1", date = "20/11/2026",
        added = {
            "Barre d'expérience : option « Texte au survol » (QoL > Expérience) ; le niveau, le repos et l'XP à rendre n'apparaissent qu'en passant la souris sur la barre.",
        },
    },
    {
        version = "1.87.0", date = "20/11/2026",
        added = {
            "Bateaux et zeppelins (raccourci du micro menu, /wk bateaux) : la fenêtre s'élargit avec une carte à gauche. Kalimdor et les Royaumes de l'Est (cartes du jeu assombries) et chaque ligne en courbe douce, bateau en trait plein, zeppelin en pointillés ; ton quai en bleu.",
            "Ta liste par port reste à droite, inchangée. Clic sur un quai de la carte ou sur un encart : ce port remonte en haut, encadré, et ses lignes brillent sur la carte ; survol d'une destination : sa ligne s'allume ; clic : guidage vers son ponton.",
        },
    },
    {
        version = "1.86.3", date = "20/11/2026",
        fixed = {
            "Barre d'expérience « Sans fond » : les libellés étaient peu lisibles sur un décor clair ; ils passent en police contourée, un peu plus grande, avec les gris éclaircis.",
        },
    },
    {
        version = "1.86.2", date = "20/11/2026",
        added = {
            "Barre d'expérience : option « Sans fond » (QoL > Expérience) qui retire le cadre sombre autour de la barre ; les libellés sont alors ombrés pour rester lisibles.",
        },
    },
    {
        version = "1.86.1", date = "20/11/2026",
        changed = {
            "Micro menu sans animation : les raccourcis apparaissent d'un coup au survol de l'heure et disparaissent de même, sans glissement ni effet loupe ; l'infobulle de chaque raccourci suffit. Plus léger : la barre n'est redessinée que quand elle s'ouvre ou se ferme. Le réglage « Effet loupe » est retiré.",
        },
    },
    {
        version = "1.86.0", date = "20/11/2026",
        added = {
            "Micro menu : raccourci « Recharger l'interface » (comme /reload), à droite par défaut ; tu peux le déplacer ou le masquer comme les autres raccourcis.",
        },
    },
    {
        version = "1.85.1", date = "20/11/2026",
        fixed = {
            "Bandeau des bateaux : l'eau ondule maintenant de façon fluide (dessinée à chaque image, sans arrondi au pixel, vagues plus fines et un peu plus lentes) au lieu d'être saccadée.",
        },
    },
    {
        version = "1.85.0", date = "20/11/2026",
        changed = {
            "Bandeau des bateaux, version marine : en haut (graphite comme l'addon) « Bateau pour » et la destination en gros, le navire et « Ce ponton · vers … » à droite ; en bas une bande de mer bleue dont les vagues ondulent, avec la frise du trajet (ton ponton en bleu, la prochaine escale en vert) et un petit bateau qui tangue au ponton.",
            "À bord, le bateau avance sur la frise au fil de la traversée (« traversée 45 % »), d'après sa position sur le tracé de la ligne, avec un trait qui montre le chemin parcouru et un sillage. Pour les zeppelins la bande devient un ciel, pour le tram des profondeurs une bande graphite.",
        },
    },
    {
        version = "1.84.3", date = "20/11/2026",
        changed = {
            "Bandeau au quai : ton ponton est marqué en bleu sur la frise (au lieu de la couleur d'accent), la prochaine escale reste en vert.",
        },
    },
    {
        version = "1.84.2", date = "20/11/2026",
        fixed = {
            "Bandeau au quai : la frise des escales part toujours de ton ponton (à gauche) vers la prochaine escale (à droite). Avant, elle suivait l'ordre de la ligne et pouvait laisser croire que tu arrivais au lieu de partir ; le sous-titre dit maintenant « Ce ponton · vers Auberdine ».",
        },
    },
    {
        version = "1.84.1", date = "20/11/2026",
        changed = {
            "Résumé, « Évolution de l'or » : les montants sont écrits à gauche du graphique (graduations rondes en po, pa sous 1 po, avec une décimale quand l'écart est faible) et les repères sont en pointillés, pour voir d'un coup d'œil de combien l'or a bougé.",
        },
    },
    {
        version = "1.84.0", date = "20/11/2026",
        added = {
            "Statistiques : trois onglets en haut de la page. « Courbes » (comme avant), « Journal de l'or » (chaque gain ou perte : quand, quel perso, pourquoi, combien ; sur 24 h, 7 ou 30 jours, tous les persos ou celui-ci, avec le total gagné, dépensé et le solde) et « Dépenses » (répartition en barres des dépenses par cause, des gains par cause, et ce que chaque perso a gagné ou perdu, avec les pourcentages).",
        },
    },
    {
        version = "1.83.0", date = "20/11/2026",
        added = {
            "Journal de l'or : chaque gain ou perte d'or est noté avec sa cause (réparations, vols, achats ou ventes chez le marchand, Hôtel des ventes, courrier, maître, quêtes, butin, échange), sur 35 jours. Le client PC s'en sert pour sa carte « Dernières 24 h » (client 1.8.6) : l'or de tous tes persos depuis 24 h et ce qui a le plus pesé.",
        },
    },
    {
        version = "1.82.1", date = "19/11/2026",
        changed = {
            "Tableau des bateaux (raccourci « Bateaux » du micro menu, /wk bateaux) : rangé par port. Chaque port avec ses pontons et leurs destinations (navire, « neutre » pour les lignes des deux factions), le port le plus proche de toi en haut, encadré à ta couleur, avec la distance et la zone. Clic sur une destination : guidage vers son ponton.",
        },
    },
    {
        version = "1.82.0", date = "19/11/2026",
        changed = {
            "Bateaux et zeppelins : plus aucun horaire. Le bandeau dit seulement où va le navire : au quai, le nom du navire de ton ponton et la frise de toutes les escales de sa ligne (ton quai à ta couleur, la prochaine escale en vert), les pontons voisins en dessous ; à bord, la frise avec la prochaine escale ; dans le tram des profondeurs, ses deux stations.",
            "Tableau des bateaux : chaque ligne avec son navire, le quai le plus proche de toi et ses destinations (clic : guidage vers ce quai).",
            "Carte : les tracés des lignes restent (plus marqués pour celles déjà prises) ; l'infobulle d'un quai donne le navire et sa destination.",
            "Guidage : « Prends le bateau pour Auberdine », sans heure.",
            "Retirés : comptes à rebours (bandeau, carte, tableau, infobulles, guidage), « exact » / « estimé », alertes « il arrive / il part », navires qui avancent sur la carte et la minicarte, partage des horaires (chat, guilde, groupe), boutons du tram ; les horaires déjà notés sont effacés. Réglages en moins : alertes et son au quai, partage.",
        },
    },
    {
        version = "1.81.2", date = "19/11/2026",
        fixed = {
            "Bandeau « À bord » qui restait affiché une fois à terre : la traversée ne se terminait qu'en descendant près du point d'amarrage ou en restant immobile 8 s. Elle se termine maintenant aussi quand le navire ne te porte plus depuis 15 s, quand ta position n'est plus lisible depuis 15 s (certaines villes), après un téléport ou une pierre de foyer, et au plus tard après 20 min ; le bandeau disparaît aussi une minute après l'arrivée prévue.",
            "Bandeau du quai encore affiché loin du ponton : il apparaît maintenant à 200 m du point d'amarrage (avant 250 m), disparaît au-delà de 260 m (avant 400 m) et 5 s plus tard (avant 8 s).",
        },
    },
    {
        version = "1.81.1", date = "19/11/2026",
        fixed = {
            "Bandeau à bord : le temps restant sautait d'une seconde à l'autre (l'arrivée était recalculée à chaque relevé de position). Une fois la ligne reconnue, l'arrivée est fixée : départ + durée exacte du trajet.",
            "À bord, monté au quai : l'heure de départ retenue est celle où le navire est parti avec toi, et non plus une estimation tirée de sa vitesse (moins précise) ; monté en route, c'est l'horaire déjà calé de la ligne s'il existe.",
            "Un départ estimé d'après les positions à bord n'est plus envoyé à la guilde et au groupe comme un vrai départ (il pouvait décaler leurs horaires).",
        },
        changed = {
            "/wk bateau : à bord, la ligne reconnue dit d'où vient l'heure de départ (quai, horaire, positions).",
        },
    },
    {
        version = "1.81.0", date = "19/11/2026",
        fixed = {
            "Bateau Menethil » Austrivage » Auberdine (Le Bravoure) : la durée de son tour était inconnue, l'addon la devinait d'après tes départs et ses horaires sautaient d'une fois à l'autre. Elle est maintenant connue (486 s, mesurée par NauticusClassicResurrected 1.5.4 sur 7 tours).",
        },
        changed = {
            "Horaires des bateaux et zeppelins : l'heure d'arrivée et de départ à chaque quai et le temps d'escale viennent maintenant des trajets enregistrés seconde par seconde par NauticusClassicResurrected (12 lignes, celles de WoW Forever comprises) ; avant, ils étaient estimés d'après la longueur des trajets, avec plusieurs dizaines de secondes d'erreur aux quais que tu n'avais pas vus. Le navire sur la carte suit aussi ce minutage.",
        },
    },
    {
        version = "1.80.3", date = "19/11/2026",
        changed = {
            "Bouton « Buffer le suivant » : le cadre rose autour du nom du joueur visé est remplacé par l'icône de la bénédiction qui va partir, dans un rond à ta couleur au-dessus de sa plaque de nom, avec une pointe vers lui ; un halo bat doucement quand le sort est prêt. Taille réglable (QoL > Classes > ta classe > Buffer autour).",
        },
    },
    {
        version = "1.80.2", date = "19/11/2026",
        fixed = {
            "Bateaux, à bord : un zeppelin de l'autre faction pouvait être « reconnu » à la place de ton bateau quand leurs trajets passent l'un près de l'autre. Seules les lignes de ta faction comptent maintenant.",
            "Horaires des bateaux qui changeaient d'une fois à l'autre sur une ligne prise souvent : les départs vus restaient utilisés 4 jours, alors que chaque redémarrage du serveur remet les navires à zéro. Seuls les départs de moins de 6 h comptent ; au-delà, l'attente moyenne est affichée au lieu d'une heure fausse.",
            "Le tour des lignes mesurées (« Classic ») n'est plus recalculé d'après nos départs : mélangés à des départs d'avant un redémarrage, ils donnaient un tour faux et des heures qui dérivaient.",
            "Un départ reçu d'un autre joueur ne passe plus devant le tien de moins d'une heure (un départ faux partagé décalait tout).",
            "Remise à zéro de l'horaire (serveur redémarré) : décidée seulement d'après ton dernier départ vu au même quai ; avant, l'heure estimée d'un autre quai la déclenchait pour rien.",
            "Un départ calé à bord ne déclenche plus de remise à zéro et laisse la place à un départ vraiment vu partir.",
        },
        changed = {
            "/wk bateau : pour chaque ligne, les départs de moins de 6 h (dont ceux vus par toi) et les derniers avec leur source (vu partir, calé à bord, annoncé, reçu).",
        },
    },
    {
        version = "1.80.1", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : rien ne partait sur un joueur pris sur sa plaque de nom (WoW Forever ignore ces cibles dans /cast, sans message). Le bouton cible maintenant ce joueur par son nom, lance la bénédiction, puis remet ta cible d'avant (ou aucune). Sur toi, ta cible, ta focalisation ou ton groupe, rien ne change.",
        },
    },
    {
        version = "1.80.0", date = "19/11/2026", restart = true,
        added = {
            "Carte sans brouillard : les zones que ton perso n'a pas encore découvertes sont dessinées quand même sur la carte du monde, un peu plus sombres pour voir ce qui reste à explorer (QoL > Carte et guidage > Lieux, carte « Filtres et affichage »).",
            "Retour au corps : quand tu es mort, un bandeau donne la distance et le temps pour courir jusqu'au corps, ce que coûte l'ange gardien à ton niveau, et conseille le plus rapide ; la flèche et l'épingle guident vers le corps, puis ton guidage d'avant revient une fois en vie (QoL > Carte et guidage > Guidage).",
            "Place dans les sacs : quand il ne reste plus que quelques cases libres (seuil réglable), un bouton à l'écran les compte ; un clic jette l'objet gris le moins cher (jamais un objet verrouillé, jamais en combat).",
            "Réassort chez le marchand : choisis combien de boissons, de nourriture et d'autres objets garder sur chaque perso ; un bouton sous la fenêtre du marchand achète ce qui manque (le meilleur pour ton niveau) sur un clic, avec le prix total.",
            "Amélioration à porter : un objet qui arrive dans tes sacs (butin, récompense, achat) et vaut mieux que celui que tu portes, d'après les caractéristiques de ta classe, est proposé avec « L'équiper » ou « Pas celui-là ». Rien n'est équipé tout seul.",
            "Fenêtre de destruction du jeu : elle dit quand l'objet est encore demandé par une quête de ton journal.",
            "Réglages de la place, du réassort et de l'amélioration : roue de la page Inventaire, carte « Sacs, marchand et équipement ».",
        },
        changed = {
            "Objets de quête protégés par défaut : la règle « Objets de quête » des verrous compte aussi les objets que demande une quête de ton journal (cadenas dans les sacs, vente bloquée, rachat automatique s'il est vendu quand même), jusqu'à ce que la quête soit rendue.",
        },
    },
    {
        version = "1.79.1", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : sous la souris, le clic agit maintenant au relâché, une seule fois, quel que soit le réglage « lancer à l'appui » du jeu ; au clavier, il suit toujours ce réglage.",
        },
        changed = {
            "/wk buff : après un clic, dit ce que le jeu a répondu dans les 2 secondes (sort envoyé, réussi, raté, message d'erreur, action bloquée) et la valeur du réglage « lancer à l'appui » : de quoi trouver pourquoi le sort ne part pas.",
        },
    },
    {
        version = "1.79.0", date = "19/11/2026",
        added = {
            "Bateaux et zeppelins : l'heure se cale pendant la traversée. À bord, ta position est suivie sur le tracé de la ligne ; au bout d'une trentaine de secondes, l'addon sait quelle ligne tu as prise, quand le navire a quitté le quai et quand il arrivera, même si tu es monté au dernier moment ou si le départ n'a pas été vu.",
            "Bandeau à bord : la destination et le temps restant viennent de ce calage (vraie heure d'arrivée) ; sans calage, la durée affichée est marquée « estimé ».",
            "Attente moyenne : quand l'heure d'une ligne n'est pas encore calée, le bandeau du quai, le tableau des bateaux, les infobulles, le guidage et le message du chat donnent l'attente moyenne (« ~2:38 », la moitié du tour) au lieu de rien.",
            "Tram des profondeurs : bandeau dans le tram avec la prochaine rame (une rame quitte chaque station toutes les 1:12, trajet d'environ 59 s, tirés des fichiers du jeu), l'heure se calant au premier départ vu : repéré à bord quand le jeu donne ta position, ou avec le bouton « Une rame part ». Partagé avec la guilde et le groupe comme les bateaux ; valable 6 h.",
            "/wk bateau : ligne reconnue à bord (étape, arrivée, nombre de positions) et état du tram.",
        },
    },
    {
        version = "1.78.2", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : cliquer dessus ne lançait rien. Il lance maintenant le sort par une macro « /cast » sur le joueur choisi, et ne vise plus le joueur survolé (il n'est plus survolé quand la souris arrive sur le bouton). /wk buff montre la macro posée et le dernier clic.",
        },
    },
    {
        version = "1.78.1", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : les plaques de nom étaient bien à l'écran mais leurs joueurs n'étaient pas lus (le champ utilisé n'existe pas sur WoW Forever). Les joueurs des plaques sont maintenant lus par leur unité (nameplate1 à 40) ; /wk buff dit combien d'unités et de joueurs il en tire.",
        },
    },
    {
        version = "1.78.0", date = "19/11/2026",
        fixed = {
            "Traversées en bateau : marcher sur le pont arrêtait la traversée en pleine mer, et le départ n'était alors pas noté. Elle ne s'arrête plus qu'en descendant au quai, quand le navire est à quai depuis 8 s, ou en prenant un vol ; l'heure d'arrivée retenue est celle où le navire s'est arrêté.",
            "Horaires des bateaux et zeppelins : la durée de chaque étape n'était qu'estimée (le tour partagé selon la longueur du trajet). Chaque traversée faite la mesure maintenant, et l'horaire des autres quais de la ligne en profite.",
            "Temps à quai : il était supposé de 60 s partout (« à quai », « il arrive dans », calage par l'annonce du maître de quai). Il est mesuré quand on voit le navire arriver puis repartir.",
            "Le tour des lignes « exact » (mesuré sur WoW Classic) est maintenant affiné aussi d'après les départs vus, au cas où WoW Forever tourne un peu différemment.",
            "Après un redémarrage du serveur, un départ vu à plus de 45 s de l'horaire prévu efface les anciens départs (ils faussaient tout) ; un départ vu partir remplace l'estimation tirée de l'annonce d'arrivée.",
            "« exact » n'est plus affiché à tort : il faut un départ vu à ce quai depuis moins de 3 h (ou des trajets mesurés) avec un tour sûr ; sinon « estimé ».",
        },
        added = {
            "/wk bateau : pour chaque ligne déjà calée, nombre de départs vus, âge du dernier, tour utilisé (Classic, affiné, approché), étapes et temps à quai mesurés.",
        },
    },
    {
        version = "1.77.15", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : il trouve maintenant le réglage des plaques de nom amies sous son nom sur ton client (l'ancien nom n'existe pas sur WoW Forever). Et ta cible, le joueur survolé à la souris et ta focalisation sont aussi proposés : le bouton marche même sans plaques de nom.",
            "/wk buff : dit quel réglage des plaques amies a été trouvé et sa valeur, ou qu'il est introuvable (Maj+V pour les montrer).",
        },
    },
    {
        version = "1.77.14", date = "19/11/2026",
        fixed = {
            "Bouton « Buffer le suivant » : il ne voyait aucun joueur autour de toi hors de ton groupe. Les plaques de nom amies n'étaient jamais allumées, car l'ancienne façon de changer un réglage du jeu n'existe plus sur WoW Forever. L'addon passe maintenant par la nouvelle (C_CVar).",
            "Même correction pour les autres réglages du jeu lus ou changés par l'addon : minicarte tournante (pastilles, tracés, HUD de récolte), butin automatique, durée des ventes à l'HV, profilage du processeur.",
        },
    },
    {
        version = "1.77.13", date = "19/11/2026",
        added = {
            "/wk buff : dit pourquoi le bouton « Buffer le suivant » est caché (réglage, monture, instance, combat, plaques de nom amies) et, joueur par joueur autour de toi, pourquoi il est écarté (JcJ, déjà buffé, hors de portée, en combat…) ou s'il est bon.",
        },
    },
    {
        version = "1.77.12", date = "19/11/2026",
        fixed = {
            "Bandeau du quai, bateau Auberdine » Menethil : il affichait « Bateau pour Austrivage », sans heure, à cause d'un trajet appris en jeu qui double la ligne du jeu. Un quai appris à moins de 400 m d'un arrêt d'une ligne du jeu est maintenant ignoré par le bandeau : la ligne du jeu s'affiche, avec sa vraie destination et ses horaires.",
        },
    },
    {
        version = "1.77.11", date = "19/11/2026",
        fixed = {
            "Bandeau du quai, port à plusieurs pontons (Auberdine) : il montrait le bateau du ponton d'à côté (Port de Hurlevent) au lieu de celui où tu attends, et cachait une ligne dont l'heure n'est pas encore connue. Le ponton le plus proche passe maintenant en tête, et les autres destinations sont listées, avec « ? » quand leur heure n'est pas connue.",
        },
    },
    {
        version = "1.77.10", date = "19/11/2026",
        fixed = {
            "Bandeau du quai, Auberdine » Menethil : rien ne s'affichait, ni au quai ni à bord. Il apparaît maintenant à 250 m du point d'arrêt du navire (400 m pour disparaître), et à bord il retrouve la ligne d'après l'endroit où la traversée a commencé, même s'il n'avait pas été vu au quai.",
            "/wk bateau : liste les quais les plus proches avec leur distance et la distance d'apparition du bandeau.",
        },
    },
    {
        version = "1.77.9", date = "19/11/2026",
        fixed = {
            "Bandeau du quai : il disparaissait quand on attendait sur le ponton (la distance était mesurée jusqu'au point d'arrêt du navire, souvent au bout du ponton). Il apparaît maintenant à 150 m, reste jusqu'à 300 m, puis encore 8 s.",
        },
        changed = {
            "Bandeau du quai : il reste affiché à bord, pendant toute la traversée : destination, temps restant estimé, heure d'arrivée et une barre d'avancement.",
        },
    },
    {
        version = "1.77.8", date = "19/11/2026",
        fixed = {
            "Carte d'Azeroth, calque Navires : les traversées d'un continent à l'autre partaient en zigzag vers des côtes sans quai (le « saut » de continent du jeu). Chaque traversée est maintenant un arc net d'un quai à l'autre, tracé une seule fois pour l'aller et le retour.",
        },
    },
    {
        version = "1.77.7", date = "19/11/2026",
        fixed = {
            "Carte, calque Navires : on voyait les deux quais d'une ligne mais pas le trajet entre eux tant que tu ne l'avais pas pris une fois. Toutes les lignes sont maintenant tracées (plus pâles si tu ne les as jamais prises).",
            "Carte d'Azeroth (les deux continents) : les trajets des bateaux et zeppelins y sont tracés, traversée d'un continent à l'autre comprise (les positions passent par la carte du continent).",
        },
    },
    {
        version = "1.77.6", date = "19/11/2026",
        fixed = {
            "Bandeau du quai : la pastille « estimé » passait sous le temps quand le nom du quai était long. Elle est maintenant juste à gauche du temps, le titre s'arrête avant elle, et le grand temps n'a plus « env. » (la pastille le dit déjà).",
        },
    },
    {
        version = "1.77.5", date = "19/11/2026",
        changed = {
            "/wk carte : la ligne « trajet » dit aussi vers quoi tu es guidé, où en est le calcul du chemin (complet, jusqu'au quai, aucun bateau trouvé) et si le tracé est activé, pour trouver pourquoi un trajet ne s'affiche pas.",
        },
    },
    {
        version = "1.77.4", date = "19/11/2026",
        changed = {
            "Métiers > roue dentée : les réglages sont rangés en onglets par catégorie (Ce métier, Fenêtres du jeu, Fabrication, Récolte) au lieu d'une longue page ; l'onglet choisi est retenu, et la recherche de la barre latérale ouvre le bon onglet.",
        },
    },
    {
        version = "1.77.3", date = "19/11/2026",
        fixed = {
            "Barre de fabrication : elle n'apparaissait pas en mode édition (ni pour la placer, ni avec « Tester ») tant qu'aucune série n'avait été lancée. Elle existe maintenant dès la connexion.",
            "Guidage vers un autre continent : sur la carte d'Azeroth, le trajet passe maintenant toujours par la carte du continent pour être placé (le jeu y convertissait mal les positions). /wk carte dit en plus combien de points du trajet sont placés et si les deux quais le sont.",
        },
    },
    {
        version = "1.77.2", date = "19/11/2026",
        changed = {
            "Courrier > Envoyer : les noms proposés pour « À » s'affichent dans une liste sous le champ (jusqu'à 10) au lieu d'une ligne à côté qui manquait de place : tes persos d'abord, à la couleur de leur classe et marqués « mon perso », puis tes destinataires récents.",
            "Courrier : dans la barre latérale, les destinataires récents qui sont tes persos sont à la couleur de leur classe.",
        },
    },
    {
        version = "1.77.1", date = "19/11/2026",
        fixed = {
            "Guidage vers un autre continent, carte d'Azeroth (les deux continents à l'écran) : le départ et l'arrivée s'affichaient mais pas le trajet. Le chemin jusqu'au quai est maintenant tracé sur cette carte aussi, et la traversée en bateau ou en zeppelin est dessinée d'un quai à l'autre.",
        },
    },
    {
        version = "1.77.0", date = "19/11/2026",
        added = {
            "Barre de fabrication : quand tu fabriques plusieurs objets d'affilée (« Créer tout » ou une quantité), une barre montre l'avancée sur la durée TOTALE de la série : icône, « 7 / 20 », une marque par fabrication, temps restant, durée d'une fabrication, heure de fin, niveau du métier avec les points gagnés depuis le début, recette suivante de ta file, et un bouton Arrêter. Elle disparaît à la fin (son en option).",
            "Réglages dans Métiers > roue dentée, carte « Barre de fabrication » : l'afficher, où (à l'écran, placée en mode édition, ou collée sous la fenêtre du métier), à partir de combien de fabrications (2, 3, 5, 10), recette suivante, heure de fin et compétence, son à la fin. « Tester » du mode édition la fait tourner.",
        },
    },
    {
        version = "1.76.13", date = "19/11/2026",
        fixed = {
            "Bénédictions : « Aure » corrigé en « Aura » (en-tête de colonne, « Aucune aura » dans la barre) ; l'en-tête de la colonne est plus grand et en clair, aussi lisible que les icônes de classe.",
        },
    },
    {
        version = "1.76.12", date = "19/11/2026",
        changed = {
            "Les réglages du vol (Barre de vol, Statistiques en vol à la place de la carte, Ouvrir les statistiques au décollage) passent d'Interface > Général > Confort à Aventure > Carte et guidage, onglet Vols, dans une carte « Pendant le vol ».",
        },
    },
    {
        version = "1.76.11", date = "19/11/2026",
        fixed = {
            "« Ouvrir les statistiques au décollage » ne marchait pas quand « Statistiques en vol à la place de la carte » était décoché. Les deux réglages sont maintenant indépendants : les statistiques s'ouvrent au décollage, et M ouvre quand même la carte.",
        },
    },
    {
        version = "1.76.10", date = "19/11/2026",
        changed = {
            "Statistiques en vol : les boutons pour passer d'une histoire à l'autre sont des boutons ronds avec un chevron bien visible (les « ‹ › » étaient minuscules) ; au survol, ils rappellent que la molette marche aussi.",
        },
    },
    {
        version = "1.76.9", date = "19/11/2026", restart = true,
        changed = {
            "Statistiques en vol : le griffon sur le trajet est remplacé par une flèche blanche bordée de noir, tournée dans le sens du vol (ton cap), sur un halo de la couleur de l'apparence ; on voit d'un coup d'œil où tu es et où tu vas.",
        },
    },
    {
        version = "1.76.8", date = "19/11/2026",
        changed = {
            "Statistiques en vol : le bouton « Carte » est retiré ; la fenêtre ne montre que les statistiques. Pour la carte en vol, décoche « Statistiques en vol à la place de la carte » (Interface > Général > Confort).",
        },
    },
    {
        version = "1.76.7", date = "19/11/2026",
        changed = {
            "Bénédictions > Répartition : une bénédiction ou une aure pas apprise garde son icône en couleur ; seuls le cadre orange et le « ! » la signalent.",
        },
    },
    {
        version = "1.76.6", date = "19/11/2026",
        fixed = {
            "Inventaire, roue dentée : un bandeau plus sombre restait derrière le titre « Réglages de l'inventaire » (le volet cachait le halo du haut de la fenêtre). Le volet est maintenant transparent ; ce qui est dessous est masqué tant qu'il est ouvert.",
        },
    },
    {
        version = "1.76.5", date = "19/11/2026",
        changed = {
            "Bénédictions > Répartition : une bénédiction ou une aure pas encore apprise se voit bien mieux : icône grise mais nette (plus à moitié effacée), cadre orange autour et « ! » plus gros sur une pastille sombre.",
        },
    },
    {
        version = "1.76.4", date = "19/11/2026",
        fixed = {
            "Micro menu : le clic droit sur l'heure ne faisait rien sans le dire quand « Clic droit sur l'heure : libérer la mémoire » n'était pas coché (il est coupé d'office) ou en combat. Il le dit maintenant dans le chat ; coché, il libère la mémoire, indique combien et ce qu'occupent les addons ensuite.",
        },
    },
    {
        version = "1.76.3", date = "19/11/2026",
        fixed = {
            "Hôtel des ventes > Prix : pas d'infobulle au survol des objets de la liste (Ça bouge, Mes sacs, Mes ventes, Surveillés) ; elle s'affiche maintenant, avec nos lignes habituelles.",
        },
    },
    {
        version = "1.76.2", date = "19/11/2026",
        changed = {
            "Guidage sur la minicarte : le chemin est maintenant un trait continu, comme sur la carte du monde, au lieu d'une suite de points ; il s'arrête net au bord de la minicarte (trait plus fin et plus pâle pour les étapes en vol).",
        },
    },
    {
        version = "1.76.1", date = "19/11/2026",
        changed = {
            "Quêtes et Rares, carte du continent : elle est cadrée sur les terres (les zones du continent remplissent le cadre) au lieu de montrer tout le continent avec la mer autour ; les bulles sont plus espacées.",
        },
    },
    {
        version = "1.76.0", date = "19/11/2026",
        changed = {
            "Pages Quêtes et Rares refaites : un bandeau de chiffres en haut (quêtes faites ou rares tués du perso avec une barre, quêtes à rendre avec leur XP et un clic pour guider, quêtes pour ton niveau, zone conseillée ; rares de ta zone, morts récentes, rares pas tués qui donnent une recette pour tes métiers).",
            "La carte du continent du jeu en fond, avec une bulle par zone : sa taille et sa couleur disent l'avancement, ta zone est en pointillés, la zone choisie cerclée ; survol pour le détail, clic pour voir la zone ; onglets Royaumes de l'Est / Kalimdor.",
            "À droite, la liste des zones (niveaux en couleur selon ton perso, barre d'avancement, ce qu'il reste) et, dessous, les quêtes ou les rares de la zone choisie, comme avant.",
        },
    },
    {
        version = "1.75.1", date = "19/11/2026",
        fixed = {
            "Carte et guidage > Bateaux : « Ouvrir le tableau des bateaux » semblait ne rien faire ; le tableau s'ouvrait derrière la fenêtre de l'addon. Il s'ouvre maintenant devant.",
        },
    },
    {
        version = "1.75.0", date = "19/11/2026",
        changed = {
            "Statistiques en vol, plus vivantes : le trajet est dessiné sur la carte du continent du jeu (assombrie), la partie déjà faite en trait plein, le reste en pâle, et un griffon avance à ta position ; une barre de progression sous le titre, « arrivée dans » à gauche et la durée du trajet à droite.",
            "Les trois chiffres des vols ont leur icône de couleur (vols, temps en l'air, trajet le plus pris).",
            "« Le savais-tu ? » : chaque catégorie a son icône et sa couleur (or pour l'argent, rouge pour les donjons, bleu pour la pêche, orange pour les quêtes…), avec un liseré et une légère teinte ; la grande carte « Persos » montre une barre du temps de jeu par perso avec sa légende.",
        },
    },
    {
        version = "1.74.0", date = "19/11/2026",
        changed = {
            "Infobulle des objets, plus courte : une seule ligne par perso, avec en icônes ce qu'il a dans ses sacs, sa banque (et son courrier s'il y en a), puis l'icône de son métier et ce qu'il lui reste à utiliser pour le monter (son niveau entre parenthèses). Le total du compte est à droite de « Warband Keeper » ; les lignes « Montée des métiers » et « sur le compte » ne restent que pour les recettes, les outils et les métiers que personne ne monte.",
        },
    },
    {
        version = "1.73.4", date = "19/11/2026",
        fixed = {
            "Marchand : le panneau « Pour monter tes métiers » passait sous les fenêtres d'autres addons ouvertes à côté ; il est maintenant toujours au-dessus. Même chose pour le panneau collé à la fenêtre de l'HV du jeu.",
        },
    },
    {
        version = "1.73.3", date = "19/11/2026",
        improved = {
            "Addon plus léger à chaque image : les réglages de confort ne sont plus revérifiés en entier plusieurs fois par image par le micro menu, l'anneau du curseur et les pastilles de la mini-carte.",
            "Micro menu : la barre ne se replace plus toutes les demi-secondes quand rien ne bouge ; icônes, pastilles et compteurs sont rafraîchis une fois par seconde, et seulement quand la barre est dépliée.",
            "Anneau du curseur : il ne se replace que quand la souris bouge.",
            "Mini-carte : la position du perso n'est lue qu'une fois par image, même si plusieurs calques (tracé, nœuds, lieux, notes) en ont besoin. Moins de mémoire consommée en continu.",
        },
    },
    {
        version = "1.73.2", date = "19/11/2026",
        fixed = {
            "/wk perf : erreur au lancement (« attempt to call a nil value ») quand un autre addon (le compteur de dégâts du jeu, par exemple) donne à ses cadres un nom qui n'est pas un texte.",
            "Options > Fiabilité : les erreurs de l'addon n'étaient pas notées quand un addon d'erreurs (BugSack, BugGrabber) prenait la main après nous. Le journal se replace maintenant devant lui et écoute aussi BugGrabber directement.",
        },
    },
    {
        version = "1.73.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.8.5 (le compte à rebours de la prochaine vérification avance).",
        },
    },
    {
        version = "1.73.0", date = "19/11/2026",
        added = {
            "/wk perf [secondes] : mesure ce que l'addon coûte pendant que tu joues (60 s par défaut) : temps passé par évènement, dans ses fonctions les plus appelées et ses mises à jour régulières, et mémoire prise pendant la mesure ; les plus coûteux s'affichent dans le chat.",
        },
        changed = {
            "Moins de mémoire : l'historique des prix de l'HV est rangé en une ligne compacte par objet (environ 3 fois plus léger ; ta sauvegarde est convertie toute seule) ; la base des objets de la liste BiS n'est décodée qu'à la première ouverture de la liste (0,4 Mo au lieu de 1,2 Mo) ; la base des quêtes n'est plus copiée en mémoire pour être indexée.",
            "Recherche de la barre latérale : l'index des réglages est retenu d'une session à l'autre ; les pages ne sont plus toutes construites à chaque recherche (seulement une fois par version de l'addon), seule celle qu'on ouvre l'est.",
            "Plus fluide en groupe et en raid : la vie des unités n'est plus écoutée que pour le familier et la cible, et pour les boss seulement en donjon ou en raid.",
            "Connexion plus légère : le compactage de l'historique ne passe plus deux fois mais une seule, quelques secondes après l'arrivée en jeu ; le journal des ventes HV oublie tout seul ce qui a plus de 180 jours.",
        },
    },
    {
        version = "1.72.2", date = "19/11/2026",
        changed = {
            "Micro menu : les deux petites barres FPS et latence sous l'heure sont retirées, avec leur réglage ; ces chiffres sont dans le panneau au survol de l'heure.",
        },
    },
    {
        version = "1.72.1", date = "19/11/2026",
        fixed = {
            "Boîte aux lettres : notre fenêtre restait affichée quand on s'éloignait de la boîte ou qu'on cliquait sur la croix. Elle se ferme maintenant avec la boîte aux lettres du jeu, quelle que soit la façon (s'éloigner, croix, Échap).",
        },
    },
    {
        version = "1.72.0", date = "19/11/2026",
        added = {
            "Micro menu, survol de l'heure : un panneau « Performances » avec FPS, latence et mémoire des addons, puis les addons les plus gourmands avec une barre chacun (en orange au-dessus du seuil), la hausse depuis la connexion et le nombre d'addons chargés. La mémoire est relue à chaque survol, pas en continu.",
            "Réglages dans Interface > Micro menu, carte « Survol de l'heure » : afficher ou non, style (barres ou texte simple), nombre d'addons (5, 8, 12, tous), tri (mémoire, processeur si le profilage du jeu est actif, nom), FPS et latence, hausse depuis la connexion, seuil d'alerte (20, 50, 100 Mo), clic droit sur l'heure pour libérer la mémoire (coupé d'office).",
        },
    },
    {
        version = "1.71.6", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.8.4 (un seul bouton pour vérifier et mettre à jour).",
        },
    },
    {
        version = "1.71.5", date = "19/11/2026",
        fixed = {
            "Quêtes à rendre : « Guider » (Résumé > Que faire maintenant, Expérience) pouvait envoyer vers une quête que tu venais de rendre, le jeu la gardant un instant dans le journal. Une quête rendue est maintenant écartée tout de suite, et si tu étais guidé vers elle, le guidage passe à la prochaine quête à rendre (ou s'arrête s'il n'y en a plus).",
        },
    },
    {
        version = "1.71.4", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.8.3 (la pastille des mises à jour ne disparaît plus au survol).",
        },
    },
    {
        version = "1.71.3", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.8.2 (barres de défilement aux couleurs du client).",
        },
    },
    {
        version = "1.71.2", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.8.1 (pastille sur « Mises à jour » quand une nouvelle version est disponible).",
        },
    },
    {
        version = "1.71.1", date = "19/11/2026",
        changed = {
            "Barre de vol : le bouton « Carte » devient « Statistiques » et ouvre (ou ferme) les statistiques du compte en vol.",
        },
    },
    {
        version = "1.71.0", date = "19/11/2026",
        changed = {
            "Client PC : le résumé écrit à la déconnexion garde la courbe de l'or sur 90 jours et compte les listes d'achat en objets qui manquent avec leur coût estimé à l'HV (au lieu des unités). Va avec le client PC 1.8.0 et son tableau de bord refait.",
        },
    },
    {
        version = "1.70.5", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.7.5 (plus de barre de défilement sur le tableau de bord).",
        },
    },
    {
        version = "1.70.4", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.7.4 (page Mises à jour allégée).",
        },
    },
    {
        version = "1.70.3", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.7.3 (fenêtre plus grande par défaut).",
        },
    },
    {
        version = "1.70.2", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.7.2 (réglages en onglets, notifications rangées dedans).",
        },
    },
    {
        version = "1.70.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans le jeu : cette version livre le client PC 1.7.1 (page « Mises à jour » remaniée).",
        },
    },
    {
        version = "1.70.0", date = "19/11/2026", restart = true,
        added = {
            "Statistiques du compte en vol : pendant un vol, la touche de la carte (M) ouvre une fenêtre à la place de la carte. À gauche le vol (trajet dessiné avec ta position, arrivée dans…, vols et temps en l'air des 30 derniers jours, trajet le plus pris) ; à droite « Le savais-tu ? », des chiffres du compte qui défilent toutes les 8 s (ventes HV de la semaine, or sur 30 jours, temps de jeu, record de donjon, pêche, quêtes, rares, plus belle vente…), molette ou flèches pour passer. Le bouton « Carte » ouvre quand même la carte ; la fenêtre se ferme à l'atterrissage.",
            "Réglages dans Interface > Général > Confort : « Statistiques en vol à la place de la carte » (oui par défaut) et « Ouvrir les statistiques au décollage ».",
        },
    },
    {
        version = "1.69.2", date = "19/11/2026",
        fixed = {
            "Feu de camp : l'encart à l'écran était trop petit et coupait son texte (« Avantages du camp dans 5… »). Il est plus large, le texte passe à la ligne au lieu d'être coupé, et pendant la minute assise le décompte s'affiche en grand à droite avec une barre plus épaisse.",
        },
    },
    {
        version = "1.69.1", date = "19/11/2026",
        changed = {
            "Donjons, chrono : il part maintenant au premier pack (ton premier combat dans le donjon), plus en franchissant la porte ; en attendant il reste à 0 avec « au premier pack ». Un boss tué ou le chrono partagé par un membre du groupe le lancent aussi. Réglage « Départ du chrono » (au premier pack / en entrant) dans Donjons > roue dentée.",
        },
    },
    {
        version = "1.69.0", date = "19/11/2026", restart = true,
        added = {
            "Client PC : l'addon écrit à chaque déconnexion (et /reload) un petit résumé pour le tableau de bord et les notifications Windows du client 1.7 : or du compte sur 30 jours, dernière séance, enchères vues à l'HV et leur expiration, recharges de métier, listes d'achat, Rangement, courrier non pris, repos.",
        },
        fixed = {
            "Bouton « Buffer le suivant » : en groupe, une erreur se répétait (« Raid<n>/Party<n> unit tokens are not allowed ») quand le joueur à bénir était un membre du groupe. Sa plaque de nom est maintenant retrouvée autrement, sans erreur.",
        },
    },
    {
        version = "1.68.0", date = "19/11/2026", restart = true,
        added = {
            "Boîte aux lettres refaite : notre fenêtre à la place de celle du jeu, comme l'hôtel des ventes. Barre latérale Reçus · Envoyer · Rangement · Règles d'envoi · Historique avec leurs pastilles, et les destinataires récents (clic = lettre prête).",
            "Courrier > Reçus : chaque lettre avec son contenu, son montant et son expiration (en rouge sous 3 jours) ; « Tout prendre », « Or seulement », « Ventes HV », un bouton « Prendre » par lettre, recherche.",
            "Courrier > Envoyer : destinataire avec suggestions (tes persos et les récents), 12 pièces jointes (clic droit dans les sacs), or ou contre-remboursement, port affiché.",
            "Courrier > Règles d'envoi et Historique : les règles avec « Envoyer maintenant », et les envois et ventes HV des derniers jours. « Fenêtre du jeu » revient à l'ancienne pour une visite ; réglage dans Courrier > roue dentée > Fenêtre.",
        },
    },
    {
        version = "1.67.0", date = "19/11/2026",
        added = {
            "Résumé : « Que faire maintenant ? » en tête de page. La meilleure idée en grand avec son action (Voir, Guider…), les deux suivantes en petit, les autres citées en une ligne. Les idées viennent de ce que l'addon sait déjà (courrier qui expire, recharges prêtes, quêtes terminées à rendre avec l'XP, envois du Rangement, enchères sous-cotées, gris à vendre, repos plein…), classées par urgence ; chacune dit ce qu'elle rapporte.",
        },
    },
    {
        version = "1.66.0", date = "19/11/2026", restart = true,
        added = {
            "Options > Fiabilité, journal d'erreurs : chaque erreur de Warband Keeper est notée (message, fichier, version, nombre de fois). Un point rouge sur l'icône Options signale une erreur pas encore vue ; « Copier le rapport » ouvre le texte déjà sélectionné, à coller tel quel.",
            "Options > Fiabilité, nettoyage : la taille de la sauvegarde et, case par case, ce que chaque purge libère (prix de l'HV pas vus depuis 30 jours, journal des ventes de plus de 90 jours, carnet de pêche réduit aux 500 dernières prises ; chemins appris et persos absents depuis 180 jours, décochés d'office). Un seul bouton « Nettoyer », confirmé par un second clic.",
        },
    },
    {
        version = "1.65.4", date = "19/11/2026",
        changed = {
            "Paladin > Bénédictions : la répartition du groupe est couchée pour tenir dans la fenêtre. Une ligne par paladin (bande rose Warband Keeper ou grise PallyPower à gauche, ta ligne bordée de rose), une colonne par classe (icône en haut, nom au survol) puis l'aure. La carte grandit avec le nombre de paladins, sans place perdue.",
        },
    },
    {
        version = "1.65.3", date = "19/11/2026",
        changed = {
            "Paladin > Bénédictions : la répartition du groupe est rangée en un panneau par paladin. Chaque colonne a sa bande de couleur en haut (rose Warband Keeper, gris PallyPower), le nom et l'addon centrés sans chevauchement, puis ses bénédictions centrées sous l'en-tête ; ta colonne est bordée de rose.",
        },
    },
    {
        version = "1.65.2", date = "19/11/2026",
        added = {
            "Paladin > Bénédictions : bouton « Tester » sur la répartition du groupe. Hors groupe, il ajoute deux paladins simulés (Aerin sous Warband Keeper en automatique, Brann sous PallyPower qui donne Rois partout) pour voir comment les bénédictions se partagent ; tu peux cliquer leurs cases. Rien n'est envoyé, et le test s'arrête au clic sur « Arrêter le test » ou en rejoignant un groupe.",
        },
    },
    {
        version = "1.65.1", date = "19/11/2026",
        changed = {
            "Paladin > Bénédictions : le tableau de répartition est plus visuel. Chaque ligne commence par l'icône de la classe (son nom au survol) et chaque case ne montre plus que l'icône de la bénédiction, deux fois plus grande ; une bénédiction pas encore apprise est grisée avec un « ! », une case vide montre un cercle pointillé. Le nom de la bénédiction s'affiche au survol.",
        },
    },
    {
        version = "1.65.0", date = "19/11/2026",
        changed = {
            "Paladin > Bénédictions : la répartition automatique suit maintenant les priorités de WoW Forever. Puissance puis Rois pour les guerriers, voleurs et chasseurs ; Rois puis Sagesse pour les mages et démonistes ; Sagesse puis Rois pour les prêtres, chamans, paladins et druides. Le Sanctuaire (supprimé) et le Salut ne sont plus choisis d'office.",
        },
        added = {
            "Paladin > Bénédictions : un tank (guerrier ou druide marqué tank dans le groupe) reçoit Rois plutôt que Puissance quand aucun autre paladin ne la donne déjà ; sa ligne s'affiche à part dans la barre (« · tank »).",
            "Paladin > Bénédictions : Salut collectif. Le Salut se cumule avec la bénédiction de classe : une ligne « Salut » à part dans la barre pour les guerriers, voleurs, chasseurs, mages et démonistes, jamais les tanks. Se coupe dans les réglages des bénédictions.",
        },
    },
    {
        version = "1.64.4", date = "19/11/2026",
        fixed = {
            "Paladin > Bénédictions : cliquer une case du tableau ne changeait rien quand l'addon ne voyait qu'une bénédiction apprise (le jeu remplace parfois le rang 1 par un rang supérieur). Le clic fait maintenant défiler toutes les bénédictions puis « aucune » ; une bénédiction pas encore apprise est marquée « pas apprise ». Les bénédictions connues sont aussi mieux reconnues (par leur nom).",
        },
    },
    {
        version = "1.64.3", date = "19/11/2026",
        changed = {
            "Paladin > Bénédictions : le tableau de répartition se lit comme un planning. Les classes en lignes (grisées si elles ne sont pas dans le groupe), l'aure en dernière ligne, les paladins du groupe en colonnes (toi d'abord, pastille Warband Keeper ou PallyPower) ; chaque case montre l'icône et le nom de la bénédiction.",
        },
        fixed = {
            "Paladin > Bénédictions : le message « Seul pour l'instant » chevauchait ta ligne, et des lignes vides prenaient la moitié de la carte ; le message est maintenant un bandeau à part.",
        },
    },
    {
        version = "1.64.2", date = "19/11/2026",
        fixed = {
            "Inventaire, roue dentée ouverte : la bande vide au-dessus des réglages porte maintenant leur titre (« Réglages de l'inventaire »).",
        },
    },
    {
        version = "1.64.1", date = "19/11/2026",
        fixed = {
            "Carte du monde : sous l'épingle du guidage, le nom de la destination pouvait être coupé ; le cadre prend maintenant la largeur de sa ligne la plus longue.",
        },
    },
    {
        version = "1.64.0", date = "19/11/2026", restart = true,
        added = {
            "Paladin : barre des bénédictions à l'écran (à placer en mode édition). En tête ton aure (clic pour la lancer) et ton sceau ; une ligne par classe du groupe (et par exception) avec ta bénédiction, le temps restant le plus court et le nombre de joueurs sans. Clic : bénit le prochain joueur de la ligne qui en a besoin ; survol : chaque joueur et son temps ; clic droit : la répartition.",
            "Paladin : répartition des bénédictions entre paladins (QoL > Classes > Paladin, onglet « Bénédictions »). Une ligne par paladin du groupe, une colonne par classe et l'aure ; automatique (chacun prend une bénédiction que les autres n'ont pas) ou à la main ; exceptions par joueur (« Cible actuelle ») ; le chef du groupe peut changer les lignes, les autres seulement si tu le permets.",
            "Compatible avec PallyPower : les paladins qui l'utilisent apparaissent dans le tableau (pastille « PallyPower »), leurs choix arrivent chez toi et les tiens partent chez eux. Plus besoin de PallyPower pour toi.",
            "Le bouton « Buffer le suivant » du paladin suit cette répartition.",
            "Nouveaux fichiers : redémarrer le jeu.",
        },
    },
    {
        version = "1.63.1", date = "19/11/2026",
        added = {
            "Patch notes > À venir : chaque idée a une pastille de priorité (Haute, Moyenne, Basse). Vue « Par priorité » (trois colonnes Haute / Moyenne / Basse, le thème en pastille sur chaque carte) ou « Par thème » (cartes triées par priorité).",
        },
    },
    {
        version = "1.63.0", date = "19/11/2026",
        fixed = {
            "Hôtel des ventes : après avoir rangé tes sacs, « Mettre en vente » pouvait poster l'objet qui occupait maintenant la case (au prix de l'autre). L'objet est retrouvé par son numéro, sinon rien n'est posté.",
            "Hôtel des ventes : poster plusieurs exemplaires d'un objet (pas une marchandise) les mettait chacun à N fois le prix ; acheter une pile pouvait être refusé (prix arrondi).",
            "Hôtel des ventes : le prix proposé et le garde-fou reprenaient les prix d'une visite précédente ; ils attendent maintenant la recherche de la visite en cours.",
            "Hôtel des ventes : « moyenne 7 j », « Bonne affaire » et la jauge comptaient tout l'historique gardé (30 jours) au lieu de 7 jours ; « Tes ventes » montrait les plus anciennes au lieu des plus récentes.",
            "Hôtel des ventes : un achat isolé (Parcourir, Vendre) affichait « Liste d'achat terminée » ; changer de liste gardait l'achat en cours de l'ancienne ; la page ralentissait le jeu pendant un scan ; les touches de vente pouvaient être avalées en combat.",
            "Hôtel des ventes : « Reposter » ne faisait rien quand l'objet annulé revenait par le courrier ; la page Vendre s'ouvre maintenant dessus dès qu'il arrive dans tes sacs (dans les 15 min).",
            "Hôtel des ventes : textes de la page Vendre (nom, total, dépôt…) qui pouvaient être coupés (ancrages).",
            "Bateaux : couper « Apprendre les chemins » arrêtait aussi la détection des traversées (plus de tracés ni d'horaires appris en bateau).",
            "Bateaux : les départs reçus d'autres joueurs étaient rediffusés à la connexion (une erreur se propageait dans la guilde) ; seuls tes propres départs sont renvoyés.",
            "Bateaux : sur la ligne Menethil » Austrivage » Auberdine, un quai pouvait annoncer la mauvaise destination (et le guidage proposer le mauvais bateau).",
            "Carte : la liste des rares sur le côté de la carte pouvait clignoter sous la souris ; l'intérieur des pastilles disparaissait sur les petites icônes ; l'ancienne taille des pastilles s'appliquait encore sans réglage ; carte redessinée chaque seconde avec le module coupé ; étiquettes (départs, notes, « mort », repère) trop grosses en zoomant ; navires de l'autre faction absents de la minicarte malgré le réglage.",
            "Guidage : sans l'épingle à l'écran, l'arrivée n'arrêtait jamais le guidage.",
            "Donjons : la réinitialisation d'une instance n'était jamais reconnue (passage repris à tort, compteur d'instances faux) et la réputation gagnée manquait au résumé de sortie.",
            "Donjons : une fois le record battu, le chrono, les écarts et l'annonce se comparaient au passage en cours (« -0:00 ») ; ils comparent maintenant à l'ancien record.",
            "Donjons : le partage du parcours n'accepte plus que le groupe (pas un chuchotement d'addon) et ne crée plus de doublons dans l'historique ; un passage n'est plus repris le lendemain après une déconnexion dedans.",
            "Chrono de donjon : nom du donjon et ligne du record qui pouvaient être coupés.",
            "Métiers : fermer le panneau Désenchantement ou Échange en combat déclenchait une erreur ; le journal des désenchantements pouvait noter le butin d'un cadavre après un sort raté ; « Tout acheter » chez le marchand enchaînait des achats au-delà de ton or ou du stock.",
            "Talents : le plan « Montée enregistrée » pouvait être vidé à la connexion ; aucun relevé des talents si l'ancienne interface ne rendait aucun arbre.",
            "Bouton « Buffer le suivant » et kit de camp : construits en combat après un /reload (actions bloquées) ; plaques de nom amies jamais rendues sur un perso d'une autre classe ; icônes et kit d'exemple utilisables pour de vrai pendant « Tester ».",
            "Pile « Rappels » : une icône de buff pouvait viser l'ancien membre du groupe ; changer « Où vont les rappels » laissait les rappels déjà affichés ; décocher « Prévenir d'un niveau à rendre » ne retirait pas le rappel.",
            "Feu de camp : encart et icône cachés après le mode édition ou « Tester » ; leurs aperçus apparaissaient avec le module coupé.",
            "Couper un module (Curseur, Donjons, Expérience, Feu de camp, Classes…) cache maintenant tout de suite ses éléments à l'écran.",
            "Patch notes : marquées « lues » dès qu'on ouvrait le Courrier ou la recherche ; recherche et filtres qui sortaient de la fenêtre (maintenant sous les onglets).",
            "Options > À propos : la phrase passait sous les boutons et la dernière source dépassait de la carte.",
            "Profils : le chrono de donjon, les objets verrouillés et les interrupteurs du courrier et de la banque n'étaient pas dans les profils ; changer de profil faisait revenir le point des patch notes.",
            "Résumé : erreur au clic sur la pastille du courrier quand le module Courrier est coupé ; recherche d'un objet qui n'affichait rien si l'Inventaire était sur « Verrouillés » ; /wk notes ne refermait pas la fenêtre ; pastilles de l'en-tête masquées trop tôt.",
        },
    },
    {
        version = "1.62.6", date = "19/11/2026",
        changed = {
            "Patch notes > À venir : nouvelles idées (mise en valeur des nœuds à l'approche, couches de serveur, horaires des autres addons de bateaux, carte, quêtes automatiques, sacs pleins et camelote, infobulles, aides de combat, groupe, chat, mini-jeux en vol).",
        },
    },
    {
        version = "1.62.5", date = "19/11/2026",
        changed = {
            "Patch notes > À venir : nouvelles idées pour les quêtes (camps d'objectifs, guidage de la quête suivie) et la navigation (trajets qui suivent le terrain, chemins appris partagés).",
        },
    },
    {
        version = "1.62.4", date = "19/11/2026",
        changed = {
            "Patch notes > À venir : nouvelles idées autour des maîtres de classe (sorts à apprendre par perso, panneau chez le maître, rappel au passage de niveau, gain d'un rang, grimoires de démons, compétences d'armes).",
        },
    },
    {
        version = "1.62.3", date = "19/11/2026",
        changed = {
            "Patch notes : maintenant dans les Options, section « Patch notes » sous Profils. L'icône en haut à droite de la fenêtre est retirée ; le point qui signale des notes pas encore lues passe sur l'icône des Options. /wk notes et « Voir les patch notes » ouvrent directement cette section.",
        },
    },
    {
        version = "1.62.2", date = "19/11/2026", restart = true,
        changed = {
            "Patch notes : les corrections sont marquées d'un petit triangle d'avertissement rouge au lieu du « ! », dans les compteurs des jours, devant chaque note et sur le filtre « Corrections ». Nouvelle texture : redémarrer le jeu.",
        },
    },
    {
        version = "1.62.1", date = "19/11/2026",
        changed = {
            "Patch notes : les modifications sont marquées d'une petite icône de flèches circulaires (ambre) au lieu du « ~ », dans les compteurs des jours, devant chaque note et sur le filtre « Modifications ».",
        },
    },
    {
        version = "1.62.0", date = "19/11/2026",
        changed = {
            "Options > À propos plus lisible : en-tête avec le logo, la version et les boutons « Commandes du chat » et « Voir les patch notes », trois tuiles (ouvrir, commandes, à faire une fois), puis un tableau des sources des données (ce qui en vient, la source, la licence en pastille ; la mention complète au survol d'une ligne).",
        },
    },
    {
        version = "1.61.1", date = "19/11/2026",
        changed = {
            "Profils : ils sont maintenant dans les Options, section « Profils » sous Apparence. L'icône des profils en haut à droite de la fenêtre est retirée.",
        },
    },
    {
        version = "1.61.0", date = "19/11/2026",
        changed = {
            "Patch notes : plus de sommaire à gauche, les notes prennent toute la largeur. Elles sont groupées par jour : une carte par jour (le plus récent ouvert, les autres sur une ligne avec leur nombre de versions et leurs + ~ !, clic pour ouvrir), et dedans chaque version avec son numéro à gauche et toutes ses notes à droite, marquées + (ajout), ~ (modification) ou ! (correction).",
        },
        added = {
            "Patch notes : recherche dans les notes, filtres Ajouts / Modifications / Corrections, et « Depuis ma dernière visite » (les versions sorties depuis la dernière fois que tu as ouvert la page).",
        },
    },
    {
        version = "1.60.2", date = "19/11/2026",
        changed = {
            "Patch notes, sommaire des versions plus lisible : dans sa propre carte, versions groupées sous leur date, numéro plus gros, contenu en couleur à droite (+ ajouts, ~ modifications, ! corrections), point vert sur la version installée, version choisie à la couleur d'accent avec un trait à gauche, survol, et « + N plus anciennes » en bouton.",
        },
    },
    {
        version = "1.60.1", date = "19/11/2026",
        changed = {
            "Patch notes > À venir : les thèmes sont rangés en grille (trois par rangée, alignés en haut) et les cartes d'une même rangée ont la même hauteur d'une colonne à l'autre, au lieu d'être posées en quinconce.",
        },
    },
    {
        version = "1.60.0", date = "19/11/2026",
        changed = {
            "Patch notes en deux onglets. « Notes de version » : un sommaire des versions à gauche (clic : la page saute à la version), les notes à droite, chargées par 15 (« + N plus anciennes »). « À venir » : ce qui est prévu, rangé par thème sur trois colonnes (Interface, Carte et voyage, Inventaire et économie, Métiers, Personnages, Classes et combat, Donjons et quêtes), une carte par idée avec un titre court et une phrase.",
        },
    },
    {
        version = "1.59.3", date = "19/11/2026",
        fixed = {
            "Patch notes : la page pouvait rester vide. Avec plus de 400 versions, elle construisait tout d'un coup ; elle montre maintenant « À venir » et les 15 dernières versions, et le bouton « Versions plus anciennes » en ajoute 15 de plus à chaque clic.",
        },
    },
    {
        version = "1.59.2", date = "19/11/2026",
        fixed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.6.3 (faux persos sur l'accueil après une mise à jour, colonne des noms écrasée).",
        },
    },
    {
        version = "1.59.1", date = "19/11/2026",
        added = {
            "Carte du monde : réglage « Taille des icônes sur la carte » (de 50 % à 200 %) pour toutes les icônes (lieux, quais, navires, rares, notes, filons, repère). À 100 %, la taille ne change pas. Il remplace « Taille des pastilles » dans les réglages de la carte, onglet Lieux, carte « Filtres et affichage ».",
        },
    },
    {
        version = "1.59.0", date = "19/11/2026",
        changed = {
            "Chrono de donjon plus lisible : fond sombre plein aux coins arrondis (il ne s'efface plus à droite, là où sont les temps). Le gros chrono passe à droite du nom du donjon, le record et le compteur de l'heure tiennent sur une ligne avec le temps restant, les colonnes « Temps » et « Écart » ont un titre, et seuls les 2 derniers boss tués restent affichés (« + 3 boss tués plus tôt » pour les autres). « Fond plus discret » rend le fond un peu transparent.",
        },
    },
    {
        version = "1.58.2", date = "19/11/2026",
        changed = {
            "Carte du monde : icônes des rares environ 30 % plus petites, comme les autres icônes de la carte.",
        },
    },
    {
        version = "1.58.1", date = "19/11/2026",
        changed = {
            "Carte du monde : le trajet d'un bateau ou d'un zeppelin n'est dessiné qu'une fois que tu l'as pris (à partir de ta prochaine traversée sur chaque ligne). Plus de trait droit au départ des quais.",
            "Carte du monde : icônes encore plus petites (quais, lieux, navires, notes, filons, repère).",
        },
    },
    {
        version = "1.58.0", date = "19/11/2026",
        added = {
            "Chrono de donjon : nouvelle carte « Chrono à l'écran » dans la roue dentée de la page Donjons. Trois préréglages (Complet, Compact avec seulement les boss restants, Minimal avec le chrono, le record et la barre), une largeur comme le suivi des quêtes ou fixe (180 à 400), et une case pour chaque partie : nom du donjon, compteur de l'heure, record, temps restant, barre, boss, temps et écarts des boss, boss tués masqués, fond plus discret. Chaque changement montre le chrono quelques secondes.",
        },
        changed = {
            "Chrono de donjon : plus de liseré coloré sur le côté gauche.",
        },
    },
    {
        version = "1.57.0", date = "19/11/2026",
        changed = {
            "Chrono de donjon à l'écran : nouvelle allure, comme les clés mythiques. Bandeau sombre qui s'efface vers la droite, aussi large que le suivi des quêtes, nom du donjon et compteur d'instances en haut, gros chrono avec le record à côté (rouge une fois le record dépassé), temps restant avant le record, barre du temps face au record, et les boss avec une pastille (verte une fois tué, à la couleur d'accent pour celui en cours).",
        },
    },
    {
        version = "1.56.11", date = "19/11/2026",
        fixed = {
            "Inventaire, réglages (roue dentée) : le haut du cadre du Rangement dépassait au-dessus des réglages (deux cadres superposés) ; le volet des réglages couvre maintenant tout le contenu.",
        },
    },
    {
        version = "1.56.10", date = "19/11/2026",
        changed = {
            "Inventaire > Rangement : le titre (« Rangement par perso », le nombre d'objets et la note sur les envois) passe au-dessus du cadre ; plus rien ne chevauche la roue dentée.",
        },
    },
    {
        version = "1.56.9", date = "19/11/2026",
        changed = {
            "Notes de patch, « À venir » : la boîte aux lettres refaite entièrement, notre propre fenêtre comme pour l'hôtel des ventes.",
        },
    },
    {
        version = "1.56.8", date = "19/11/2026",
        fixed = {
            "Inventaire : la roue dentée des réglages était cachée en haut à droite par la vue Rangement ; elle passe devant, et le texte du Rangement lui laisse la place.",
            "Rangement : « env. » au lieu du « ~ » qui s'affichait mal devant les prix de l'HV, et « + 1 autre » au singulier.",
            "Rangement : chaque colonne a la hauteur de ses objets (avant : toutes aussi hautes que la plus remplie, avec beaucoup de vide).",
        },
    },
    {
        version = "1.56.7", date = "19/11/2026",
        changed = {
            "Mode édition : le titre de chaque élément est centré au-dessus de son cadre (avant : collé à gauche).",
        },
    },
    {
        version = "1.56.6", date = "19/11/2026",
        changed = {
            "Métiers > Réglages : dans le menu « Ce métier », le nom du perso est à la couleur de sa classe.",
        },
    },
    {
        version = "1.56.5", date = "19/11/2026",
        changed = {
            "Donjons : le groupe « Déjà dépassés » passe en tête de la colonne des donjons, avant « Pour ton niveau ».",
        },
    },
    {
        version = "1.56.4", date = "19/11/2026",
        changed = {
            "Rappel du Réal : l'icône de la pièce dans son cadre doré est remplacée par notre sac dans un rond teinté à la couleur d'accent, comme les boutons de l'addon.",
        },
    },
    {
        version = "1.56.3", date = "19/11/2026",
        fixed = {
            "Boîte aux lettres : le panneau Rangement pouvait rester à l'écran après la fermeture du courrier ; il se ferme maintenant avec la boîte aux lettres, quelle que soit la façon de la fermer.",
        },
    },
    {
        version = "1.56.2", date = "19/11/2026",
        changed = {
            "Mode édition, « Tester » : le chrono de donjon défile et un boss tombe au bout de 4 s ; les départs du bandeau des quais approchent seconde après seconde ; le bouton « Buffer le suivant » voit le nombre de joueurs à buffer descendre ; le rappel du Réal s'affiche avec le nom d'un boss.",
        },
    },
    {
        version = "1.56.1", date = "19/11/2026",
        fixed = {
            "HV, Parcourir : la catégorie « Jeton WoW » est retirée (le jeton n'existe pas sur WoW Forever).",
        },
    },
    {
        version = "1.56.0", date = "19/11/2026",
        added = {
            "HV, Scan et réglages : à gauche le scan (« Scanner maintenant », barre, quand le prochain scan complet est possible, objets connus, relevés du jour, alertes déclenchées, durée du dernier scan) et la liste des derniers scans.",
            "HV, Scan et réglages : à droite trois cartes. Vente (vente au clavier, garde-fou, marge sous le plus bas, durée par défaut), Fenêtre (notre fenêtre, page d'ouverture : la dernière, Parcourir ou Vendre, scan complet à l'ouverture), Données (prix relevés et « Repartir de zéro » en deux clics, historique gardé 14, 30 ou 90 jours, valeur des sacs et du courrier). Ce sont les mêmes réglages que la page Hôtel des ventes de l'addon.",
        },
        changed = {
            "HV : l'historique des prix est gardé 30 jours (14 avant) : la courbe sur 30 jours se remplit enfin.",
            "HV, Scan et réglages : l'ancien panneau (scan, alertes, listes, ventes) n'y est plus posé ; tout est dans les pages de la fenêtre.",
        },
    },
    {
        version = "1.55.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.6.2 (liste des persos de l'accueil alignée en colonnes).",
        },
    },
    {
        version = "1.55.0", date = "19/11/2026",
        added = {
            "HV, Parcourir : filtre de qualité (toutes, inhabituel +, rare +, épique +), un clic pour passer au suivant.",
            "HV, Parcourir : chaque résultat a une petite courbe des 7 derniers jours (verte en baisse, rouge en hausse) et une étiquette : « affaire » (sous 80 % de la moyenne), « liste » (dans une liste d'achat) ou « à toi : N ».",
            "HV, Parcourir : l'objet choisi a trois onglets : Enchères (avec le cumul), Courbe (14 jours, quantité en vente en barres) et Infos (ce que tu en as, moyenne, marchand, tes ventes de la semaine, alerte, dernier relevé).",
            "HV, Parcourir : quantité en pastilles (1, une pile, cinq piles, max) et « + Liste » pour mettre la quantité voulue dans ta liste d'achat.",
        },
        changed = {
            "HV, Parcourir : catégories avec une icône, la sous-catégorie choisie marquée d'un chevron. Le bouton « Surveiller » montre l'alerte posée.",
        },
    },
    {
        version = "1.54.2", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.6.1 (l'accueil tient dans la fenêtre sans l'agrandir).",
        },
    },
    {
        version = "1.54.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.6.0 (plus de barre de titre blanche de Windows : boutons réduire, agrandir et fermer sur le fond sombre).",
        },
    },
    {
        version = "1.54.0", date = "19/11/2026",
        added = {
            "HV, Prix : la fiche d'un objet. Courbe sur 7, 14 ou 30 jours avec le plus bas de chaque jour, la moyenne, ton prix moyen de vente (pointillés verts) et la quantité en vente (barres) ; six chiffres : aujourd'hui, moyenne, min / max, en vente, tes ventes de la semaine, prix du marchand.",
            "HV, Prix : liste à gauche avec la recherche et Ça bouge / Mes sacs / Mes ventes / Surveillés ; sous la fiche, combien tu en as (sacs, banque, compte), « Vendre les miens », « Surveiller » (le bouton montre l'alerte posée) et « Chercher ».",
        },
        changed = {
            "HV, en-tête : le type de serveur seul (PVE, PVP, RP…) au lieu du nom complet, et le nombre d'objets scannés à côté de l'heure du scan.",
        },
    },
    {
        version = "1.53.1", date = "19/11/2026",
        changed = {
            "Mode édition : grilles de 4 et 8 en plus de 16, 32 et 64 (bouton « Grille », un clic pour passer à la suivante). Sur les grilles fines, un trait sur quatre est plus marqué ; la grille choisie est retenue.",
        },
    },
    {
        version = "1.53.0", date = "19/11/2026",
        added = {
            "HV, À acheter : un résumé à droite : combien à l'HV, chez le marchand, chez tes persos, ce qui est introuvable, ton or, « Chercher les prix » et « Tout acheter à l'HV » avec sa progression.",
            "HV, À acheter : pour chaque objet, l'action qui va : « Acheter N » à l'HV ; « au marchand » quand un marchand le vend moins cher (objets vus chez les marchands, avec le nom au survol) ; « Liora en a 12 » quand un autre perso en a assez ; « introuvable » quand personne n'en vend. « Tout acheter » passe ces objets-là.",
            "HV, À acheter : « Prix surveillés » est une liste comme les autres (seuil, plus bas, « ça y est », Chercher ; clic droit pour ne plus surveiller).",
        },
        changed = {
            "HV, À acheter : listes à gauche avec leur nombre en pastille (la file de fabrication en tête), colonnes Pour, Il manque, Plus bas, En vente et Total ; « Ajouter un objet » en bas des listes.",
        },
    },
    {
        version = "1.52.1", date = "19/11/2026",
        fixed = {
            "Infobulles de l'addon (par exemple tes sacs dans la page Vendre de l'HV) : la comparaison du jeu (« Équipé », l'arme que tu portes) s'ouvrait à côté, au style du jeu. Elle reste fermée ; Maj enfoncée la montre, à notre style.",
        },
    },
    {
        version = "1.52.0", date = "19/11/2026",
        added = {
            "HV, Mes enchères : un clic sur une enchère la déplie : la file des vendeurs autour de ta place (prix et quantités), combien sont moins chers que toi et ton prix moyen de vente de la semaine.",
            "HV, Mes enchères : « Reposter » (sur l'enchère dépliée, ou « Reposter la suivante sous-cotée » en haut) annule l'enchère, puis la page Vendre s'ouvre sur l'objet revenu, au prix du moins cher moins l'écart : un clic sur « Mettre en vente » la remet.",
            "HV, Mes enchères : à droite, le bilan du jour (vendu, acheté, expirées, en vente) et, pour chaque objet, combien sont vendus et combien ont expiré sur 7 jours.",
            "Les enchères expirées sont notées quand tu prends l'objet dans le courrier (pour le bilan et « Tes objets »).",
        },
        changed = {
            "HV, Mes enchères : filtres Toutes / Sous-cotées / Bientôt finies en haut, avec leur nombre ; temps restant en orange sous 2 h. Un clic sur une enchère ne l'annule plus directement (bouton « Annuler » dans le détail).",
        },
        fixed = {
            "HV, Vendre : la pastille « Cachés » sortait du cadre des sacs.",
        },
    },
    {
        version = "1.51.2", date = "19/11/2026",
        changed = {
            "Infobulles : toutes les infobulles du jeu (objets dans les sacs, PNJ, sorts, liens du chat, comparaisons d'objets) prennent le style de l'addon : fond et bordure des cartes, police de l'interface. Avant, seules celles des fenêtres de l'addon l'avaient.",
            "Options > Général > Infobulles : « Police fine pour les infobulles du jeu » devient « Infobulles du jeu au style de l'addon » (coupé : le style du jeu, comme avant).",
        },
    },
    {
        version = "1.51.1", date = "19/11/2026",
        changed = {
            "HV, page Vendre : tes sacs en liste à gauche (icône, nom, quantité, valeur à l'HV), avec un filtre, les pastilles Tout / Favoris / Rangement / Cachés et la valeur totale ; molette pour défiler. Un objet caché se repropose d'un clic dans « Cachés ».",
            "HV, page Vendre : une jauge montre où tombe ton prix (de bon marché à cher) face au moins cher des autres et à la moyenne de la semaine, et la ligne du dépôt dit ce que tu touches après la commission.",
            "HV, page Vendre : la courbe des prix de l'objet sur 14 jours en bas de la colonne des enchères.",
        },
    },
    {
        version = "1.51.0", date = "19/11/2026", restart = true,
        added = {
            "Druide, prêtre, mage, paladin : bouton « Buffer le suivant ». Il vise le joueur ami le plus proche qui n'a pas ton buff (toi, ton groupe, puis les joueurs autour), avec l'icône du buff et le nombre de joueurs à buffer ; le joueur visé est entouré sur sa plaque de nom. Un clic ou une touche (Raccourcis > Warband Keeper) lance le buff, puis passe au suivant.",
            "Paladin : la bénédiction suit la classe du joueur (Puissance pour guerrier, voleur et chasseur, Sagesse pour les autres), ou Rois d'abord si tu la connais.",
            "Jamais en combat, ni sur un joueur en combat ou JcJ quand tu ne l'es pas. Caché en instance et sur une monture (réglables). Réglages : QoL > Classes, onglet « Buffer autour ». Le bouton se place en mode édition.",
        },
        changed = {
            "Rappel du Réal : bandeau compact comme la pile « Rappels » (fond sombre, liseré à la couleur d'accent qui respire, icône carrée, croix pour le cacher).",
        },
    },
    {
        version = "1.50.1", date = "19/11/2026",
        added = {
            "Pile d'alertes : les rappels de buffs montrent les icônes des sorts que tu connais (bénédictions, auras, Robustesse, Marque du fauve) ; un clic sur une icône lance le sort (hors combat).",
            "Pile d'alertes : posée en bas de l'écran, elle se déplie vers le haut (titre en bas). Ça se règle tout seul en la glissant par son titre, ou dans le mode édition (« Empiler vers »).",
            "Mode édition, « Tester » : la pile montre un rappel de chaque groupe (avec icônes de buff et bouton), et le temps du poison défile.",
        },
        fixed = {
            "Rappel du Réal : erreur Lua à chaque image depuis la 1.49.1 (le liseré qui pulse).",
        },
    },
    {
        version = "1.50.0", date = "19/11/2026",
        added = {
            "Hôtel des ventes : notre propre fenêtre remplace celle du jeu chez l'encanteur, avec une barre latérale comme la fenêtre de l'addon : Parcourir, Vendre, Mes enchères, À acheter, Prix, Scan et réglages, avec des pastilles (objets à vendre, enchères sous-cotées en rouge, objets à acheter). En haut : le scan des prix avec sa barre, ton or, « Fenêtre du jeu » pour revenir à l'HV de base le reste de la visite, et fermer.",
            "Parcourir : recherche par nom et par catégorie, filtres « Utilisable par moi », niveau et « Bonne affaire » (plus bas sous 80 % de la moyenne de la semaine). Résultats triables (clic sur un titre) qui défilent à la molette, avec l'écart avec la semaine et une étoile pour ce qui est dans une liste d'achat ou chez tes persos.",
            "Parcourir, l'objet choisi : sa courbe de 14 jours, ses enchères avec le cumul, les lignes qu'il faut pour ta quantité surlignées, le prix moyen et le total, puis « Acheter N » (prix demandé puis confirmation). Un objet unique s'achète sur sa ligne. « Surveiller » pose une alerte de prix.",
            "Recherches enregistrées (étoile) et les six dernières dans la barre de gauche : un clic les relance, clic droit pour enregistrer ou retirer.",
            "Mes enchères : filtre par nom, Toutes / Sous-cotées / Bientôt finies, et le bilan du jour (vendu, acheté, en vente, dernières ventes).",
            "À acheter : la « File de fabrication » arrive toute seule en tête : ce qui manque à la file des métiers de tous tes persos, avec pour qui.",
        },
        changed = {
            "Les onglets ajoutés sous la fenêtre de l'HV du jeu disparaissent : Vente, Achat, Annulation, Prix et Scan sont des pages de la nouvelle fenêtre, en plus grand.",
            "Hôtel des ventes (page de l'addon) : réglage « Fenêtre Warband Keeper » pour garder la fenêtre du jeu et l'ancien panneau à côté.",
        },
    },
    {
        version = "1.49.1", date = "19/11/2026",
        changed = {
            "Rappel du Réal de Terremine : encart aux couleurs de l'addon (fond sombre, liseré doré qui pulse, petite icône) au lieu de la grosse pièce qui clignote ; il dit « Ramasse le loot », avec le nom de l'objet et du boss en dessous.",
        },
    },
    {
        version = "1.49.0", date = "19/11/2026",
        added = {
            "Pile d'alertes : un cadre « Rappels » avec le nombre en pastille. Les rappels y sont rangés par thème (urgent, ton perso, voyage, métiers et HV), une ligne chacun. Clic sur le titre : replié en une ligne ; option « Replier en combat » dans le mode édition.",
            "Les rappels de QoL y arrivent maintenant : buffs de classe, poisons (temps restant), familier, guidage, maître de classe, points de vol, recharges et rangs de métier, pistage, limite d'instances, envies de donjon, prix à l'HV. Ils restent tant que c'est à faire et partent seuls une fois réglés.",
            "Boutons d'action dans la pile, hors combat : « Lancer » (Robustesse, Marque du fauve), « Poser » (poison des sacs), « Nourrir » (familier), « Guider » (lieu, maître, point de vol). Clic droit sur une info : la retirer.",
            "QoL > Général > Alertes : carte « Où vont les rappels » : pour chaque genre, pile, texte rouge du jeu, les deux ou rien, et un son en plus.",
        },
    },
    {
        version = "1.48.3", date = "19/11/2026",
        changed = {
            "Notes de patch : la liste « À venir » est remise à jour (« Qui peut fabriquer… ? » retiré, déjà dans Métiers > Recettes ; la pile d'alertes dit ce qu'il reste à y brancher).",
        },
    },
    {
        version = "1.48.2", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.5.2 (messages longs passés à la ligne au lieu d'être coupés).",
        },
    },
    {
        version = "1.48.1", date = "19/11/2026",
        changed = {
            "Données mises à jour depuis QuestieDB et Everloot et tables et wowtbc.gg et Everloot et opendata : 3 objets de butin de plus, 3 objets de butin désormais découverts, guides de métiers revus par wowtbc.gg.",
        },
    },
    {
        version = "1.48.0", date = "19/11/2026",
        added = {
            "Persos et Résumé : les alertes de chaque perso s'affichent en petites icônes à côté de son nom : sac (sacs), coffre (banque), marteau (réparation), étincelle (composants, munitions), étoile (familier). Rond rouge si c'est plein ou urgent, orange si c'est presque ; au survol, le détail.",
        },
    },
    {
        version = "1.47.4", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.5.1 (liste de tes persos corrigée sur l'accueil).",
        },
    },
    {
        version = "1.47.3", date = "19/11/2026",
        changed = {
            "Options > Général : réglages rangés en onglets (Langue, Infobulles, Fenêtre) au lieu d'une longue page ; l'onglet choisi est retenu et la recherche ouvre le bon.",
        },
    },
    {
        version = "1.47.2", date = "19/11/2026",
        changed = {
            "Menu de gauche : les icônes d'alerte (coffre, sac, marteau) ne s'affichent plus à côté de « Général » ; le détail reste au survol.",
        },
    },
    {
        version = "1.47.1", date = "19/11/2026",
        fixed = {
            "Persos > Expérience : un bout de la première ligne de perso dépassait au-dessus du volet, et la bande du haut restait vide ; elle affiche maintenant le titre « Expérience de tes persos » et le volet commence juste dessous.",
        },
    },
    {
        version = "1.47.0", date = "19/11/2026",
        added = {
            "Hôtel des ventes : l'onglet redevient « Achat ». Il garde tes listes d'achat à gauche, et une recherche au-dessus permet d'acheter n'importe quel objet de tes scans : quantité au choix, bouton Acheter (ou Chercher pour un objet qui n'est pas en lot) et « + » pour l'ajouter à la liste d'achat.",
        },
    },
    {
        version = "1.46.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.5.0 (accueil avec tes persos, ta sauvegarde, la prochaine vérification et le lancement du jeu).",
        },
    },
    {
        version = "1.46.0", date = "19/11/2026",
        changed = {
            "Boutons en icône (roues dentées, Expérience, fermer, partager…) bien plus visibles : un rond teinté à la couleur d'accent, avec un liseré, toujours affiché ; plus foncé au survol, plein quand la roue est ouverte.",
        },
    },
    {
        version = "1.45.1", date = "19/11/2026",
        changed = {
            "Rien ne change dans l'addon : cette version sert à livrer le client PC 1.4.5 (fenêtre plus petite).",
        },
    },
    {
        version = "1.45.0", date = "19/11/2026",
        added = {
            "Métiers : conseil pour monter. Dans la fiche d'un métier, un bandeau donne la recette orange (un point sûr), sinon jaune, la moins chère au prix du jour parmi celles que le perso connaît, avec son coût, ses composants, combien tu peux en faire et un bouton pour l'ajouter à la file.",
            "Métiers > Niveaux : chaque tuile affiche aussi ce conseil (recette et coût).",
        },
        changed = {
            "QoL > Carte et guidage > Lieux : « Sur les cartes » devient une grille de puces sur trois colonnes, avec deux petits boutons par lieu (carte du monde, minicarte) au lieu d'une ligne et deux interrupteurs.",
        },
    },
    {
        version = "1.44.1", date = "19/11/2026",
        changed = {
            "Menu de gauche : les nombres sont des pastilles à la couleur d'accent, comme dans l'échelle du LFG (aussi sur les titres de groupe repliés).",
            "Feu de camp : réglages rangés en onglets (Rappels, Objets par métier, Repos, Comment ça marche).",
        },
    },
    {
        version = "1.44.0", date = "19/11/2026", restart = true,
        added = {
            "Donjons : limite d'instances du compte (10 par heure glissante) : compteur dans la colonne des donjons (survol : l'heure et le perso de chaque entrée), dans le chrono, et alerte à 9 sur 10 avec l'heure de la prochaine place libre. Une réinitialisation annoncée par le jeu ouvre une nouvelle copie.",
            "Donjons : résumé en sortant d'un donjon (expérience, argent, morts, réputation, durée), pour toi ou envoyé au groupe.",
            "Donjons : rappel du Réal de Terremine terni : après la 1re victoire du jour sur un boss de BRD, du Pic Rochenoire, d'Hache-Tripes, de Scholomance ou de Stratholme, une icône clignote jusqu'au butin de son corps (déplaçable en mode édition).",
            "Guidage : la Pierre de foyer (ou le Retour astral), les téléports du mage et Reflet-de-Lune sont proposés quand ils font gagner beaucoup de temps et sont prêts. Le lieu de la pierre est noté chez l'aubergiste, l'arrivée des téléports à leur premier usage.",
            "Hôtel des ventes : sous les sacs du jeu, ce que valent tes sacs à l'HV (et chez le marchand) ; au survol, les objets qui valent le plus. Au survol d'un courrier, la valeur à l'HV de ses pièces jointes.",
            "Métiers : onglet « Fabriquer ou vendre » : les composants de ton compte qu'une recette d'un de tes persos valorise mieux que la vente brute, avec le gain et un bouton pour les mettre dans la file. Une ligne « Mieux fabriqué » dans l'infobulle des composants (Options > Infobulles).",
            "Récolte : les zones conseillées affichent ce qu'elles rapportent par heure, mesuré sur tes sessions de farm, et sont classées par valeur. Bouton « Tournée » : boucle guidée par les coins déjà récoltés de la zone, le guidage passe au suivant à ton arrivée.",
        },
    },
    {
        version = "1.43.0", date = "19/11/2026",
        changed = {
            "Menu de gauche rangé par thème : Mes persos (Persos, Inventaire, Classes, Expérience), Argent (Stats, Courrier, Hôtel des ventes, Journal), Artisanat (Métiers, Pêche, Feu de camp), Farm (Session de farm, Filtre de loot), Aventure (Quêtes, Rares, Donjons, LFG, Carte et guidage), Interface (Général, Halo, Curseur, Micro menu). Le groupe « Réglages QoL » disparaît ; la carte Modules suit le même rangement.",
            "LFG : dans l'échelle des donjons, le nombre de groupes est une pastille à droite, toujours visible même quand le nom est coupé.",
        },
    },
    {
        version = "1.42.1", date = "19/11/2026",
        changed = {
            "En-tête : le bouton « Scan » est retiré ; le perso est relu tout seul (connexion, sacs, or, métiers).",
            "Hôtel des ventes : l'onglet « Achat » s'appelle maintenant « Liste d'achat ».",
        },
    },
    {
        version = "1.42.0", date = "19/11/2026", restart = true,
        added = {
            "Trésorerie > Hôtel des ventes : nouvelle page qui regroupe tous les réglages de l'HV (source des prix, panneau et scan, prix relevés, vente, alertes de prix), avec ses pastilles (prix connus, listes d'achat, alertes).",
        },
        changed = {
            "Réglages rangés : chaque réglage n'a plus qu'une seule place, à côté de la fonction (roue dentée en haut à droite des pages).",
            "Courrier : « Règles d'envoi » devient « Courrier » ; sa roue dentée regroupe envoi, réception et dépôt en banque (avant dans Options).",
            "Inventaire : roue dentée pour les règles des objets verrouillés, la protection et le perso HV ; les vues Verrouillés et Rangement ne montrent plus que les listes.",
            "Rares, Quêtes, Donjons : même roue dentée partout. Les réglages des quêtes ne prennent plus une colonne à droite ; Donjons gagne des réglages (panneau, alertes d'envies, chrono).",
            "Métiers : la roue reprend la récolte d'Options (coins de récolte, filons récoltés, HUD de récolte), à côté des aides de récolte.",
            "QoL > Carte devient « Carte et guidage » : l'onglet Guidage regroupe la flèche, l'épingle, le trajet et les chemins appris (le guidage n'est plus dans Général).",
            "QoL > Général : l'onglet Alertes regroupe l'état des persos, les alertes de banque et de courrier et les rappels à la connexion (avant en partie dans Options).",
            "Options > Infobulles : toutes les lignes que l'addon ajoute aux infobulles au même endroit (montée des métiers, désenchantement, prix HV et de la pile, quêtes du donneur, rares, butin observé). Elles ne sont plus répétées ailleurs.",
            "Persos : un bouton Expérience (en haut à droite) montre le rythme de la session et le repos de tous tes persos ; QoL > Expérience ne garde que les réglages de la barre.",
            "Options ne garde que le global : Général (langue, infobulles, bouton minimap, combat), Apparence, À propos. Les renvois en double sont retirés.",
        },
    },
    {
        version = "1.41.1", date = "19/11/2026",
        changed = {
            "LFG : le donjon choisi dans l'échelle est mis en valeur (fond et liseré à la couleur d'accent, nom en couleur), et les autres lignes s'éclairent au survol.",
        },
    },
    {
        version = "1.41.0", date = "19/11/2026",
        changed = {
            "Pêche : les réglages du mode pêche quittent QoL pour la page Artisanat > Pêche. Une roue dentée à droite les ouvre en cartes sur deux colonnes (mode pêche, une seule touche, tenue et appâts, confort, récapitulatif) ; un second clic revient à l'onglet d'avant.",
            "Pêche : nouvel onglet « Carnet » à côté de « Collection », avec le carnet de pêche et les dernières prises.",
            "Le clic droit sur le bouton de pêche de la minicarte ouvre ces réglages, et la recherche de la barre latérale y mène.",
            "Quêtes : la colonne des réglages à droite descend pour s'aligner sur les tuiles des zones.",
        },
    },
    {
        version = "1.40.1", date = "19/11/2026",
        fixed = {
            "Métiers : le palier visé proposait « 300 » et « Max », qui reviennent au même. Il reste 75, 150, 225 et Max, dans le guide, les réglages des métiers et le panneau du marchand (un ancien choix « 300 » devient Max).",
        },
    },
    {
        version = "1.40.0", date = "19/11/2026",
        changed = {
            "Donjons : la grille de tuiles est remplacée par une colonne à gauche, une ligne par donjon (niveaux en couleur, boss tués). Les donjons sont groupés selon le niveau du perso : pour ton niveau, bientôt, plus haut, déjà dépassés, raids. Clic sur un groupe pour le replier (retenu), recherche en haut.",
            "Donjons : le détail (Parcours, Butin, Quêtes) prend toute la hauteur à droite. « Mes envies » garde toute la largeur.",
        },
    },
    {
        version = "1.39.1", date = "19/11/2026",
        fixed = {
            "Métiers : la roue dentée ouvrait une page vide ; les réglages des métiers s'affichent de nouveau.",
        },
    },
    {
        version = "1.39.0", date = "19/11/2026",
        changed = {
            "QoL > Carte : les réglages sont rangés en onglets (Lieux, Mes notes, Guidage, Bateaux, Vols) au lieu d'une longue page.",
            "QoL > Général : onglets Marchand, État des persos, Guidage, Groupe et confort.",
            "QoL > Classes : chaque classe range ses réglages en onglets sous les tuiles des persos (Composants, Munitions, Familier, Poisons, Distance, Aspects, Rappels… selon la classe).",
            "L'onglet choisi est retenu par section, et la recherche ouvre directement l'onglet du réglage trouvé.",
        },
    },
    {
        version = "1.38.1", date = "19/11/2026",
        changed = {
            "Métiers : la roue dentée des réglages est maintenant dans le bandeau du haut, à droite de Niveaux, Recettes et File de fabrication (plus dans la fiche d'un métier). Un second clic revient à l'onglet d'avant.",
            "Réglages des métiers : la carte « Ce métier » a un menu pour choisir le métier et le perso réglés (texte du lien, palier visé, recevoir les composants).",
        },
    },
    {
        version = "1.38.0", date = "19/11/2026",
        changed = {
            "Métiers : une roue dentée à droite des onglets Recettes, Guide et Manquantes ouvre l'onglet « Réglages », qui regroupe tous les réglages des métiers en cartes : ce métier (texte du lien, palier visé, recevoir les composants), infobulles, fenêtres du jeu (marchand, sacs, échange, maître), file et recharges, récolte, désenchantements notés.",
            "Le texte ajouté au lien du métier se règle maintenant dans cet onglet (l'ancienne petite fenêtre de l'en-tête est retirée).",
            "QoL et Options ne répètent plus ces réglages : un bouton « Réglages des métiers » y mène directement.",
        },
    },
    {
        version = "1.37.0", date = "18/11/2026", restart = true,
        added = {
            "Désenchanter ou vendre : pour un enchanteur, une fenêtre à côté des sacs liste les objets à désenchanter, avec ce qu'ils donnent en moyenne, leur valeur et le prix à l'HV ou chez le marchand, puis un conseil. Un bouton « Désenchanter le suivant » les enchaîne (un clic par objet). Aussi avec /wk de.",
            "Désenchanter : l'infobulle des objets donne ce que le désenchantement rapporte en moyenne. Les chiffres s'affinent avec tes propres désenchantements.",
            "Échange : une fenêtre à côté de l'échange propose tes enchantements pour l'objet posé dans « Ne sera pas échangé », dit s'il te manque des composants, lance l'enchantement et peut annoncer ce que tu sais faire dans le chat.",
            "Métiers : la liste de courses devient la « File de fabrication ». Chaque recette dit qui la fabrique, si tout est là ou ce qui manque (et chez quel perso), avec un bouton « Fabriquer » quand la fenêtre du métier est ouverte. Elle se décompte toute seule.",
            "Métiers : carte « Recharges » (transmutations, étoffe lunaire…) pour tous tes persos, avec un message quand une recharge est terminée.",
            "File de fabrication à l'écran : fenêtre du métier ouverte, la prochaine recette de ta file et un bouton pour la fabriquer (déplaçable dans le mode édition).",
            "Guide de métier : le coût de chaque étape, et ce que tes persos ont déjà sous le total à acheter.",
            "Maître de métier : une colonne à côté de sa fenêtre liste les recettes à apprendre ici : tes favoris, celles utiles pour le guide, celles déjà connues d'un autre perso. Un bouton apprend tous les favoris. Clic droit sur une recette (ici ou dans les recettes à apprendre) : favori.",
            "Inventaire > Avant de partir : potions, élixir, nourriture, boisson et bandages conseillés pour ton perso, ce que tu as dans tes sacs et ailleurs, où en trouver, avec des seuils réglables (Donjon, Raid, JcJ) et un rappel possible dans « À faire ».",
            "QoL > Carte : carte « Aides de métiers » pour couper chacune de ces aides.",
        },
    },
    {
        version = "1.36.0", date = "18/11/2026",
        added = {
            "Métiers : un métier au plafond de son rang (75, 150, 225) le signale une fois : « va voir un maître pour apprendre le rang suivant (Expert…) ».",
            "Récolte : une montée d'Herboristerie ou de Minage qui débloque de nouvelles herbes ou de nouveaux filons les nomme.",
            "Récolte : rappel quand tu connais Herboristerie ou Minage mais que le pistage est éteint (en changeant de zone, hors ville et donjon).",
            "Minicarte : au survol d'une herbe ou d'un filon, la compétence requise et la tienne, aux couleurs du jeu (rouge trop bas, orange, jaune, vert, gris).",
            "QoL > Carte : carte « Métiers et récolte » pour couper chacune de ces aides.",
        },
    },
    {
        version = "1.35.0", date = "18/11/2026",
        fixed = {
            "Hôtel des ventes, Vente : les durées étaient fausses (12, 24 et 48 h) ; ce sont celles du jeu sur WoW Forever (2, 8 et 24 h), avec leurs libellés lus dans le jeu et la durée du jeu par défaut.",
        },
        added = {
            "Vente, garde-fou : un prix qui rapporte moins que le marchand, ou bien sous le cours (un zéro oublié), demande confirmation (« Vendre quand même » / « Corriger »). Se coupe dans l'onglet Scan.",
            "Vente : « ton prix arrive 1er sur 6 » ; un clic sur une enchère de la liste prend son prix ; « Acheter » sur celles des autres, « Annuler » sur les tiennes.",
            "Vente : quantité en pastilles (1, une pile, tout), retenue pour chaque genre d'objet ; favoris (clic droit, en tête de liste) et objets à ne plus proposer (Maj + clic droit) ; un clic droit sur un objet des sacs du jeu l'amène dans Vente.",
            "Vente au clavier, en option (onglet Scan) : Espace met en vente, S passe, Haut / Bas changent de palier de prix.",
            "Nouvel onglet « Prix » : la courbe du plus bas de chaque jour sur 14 jours (survol = prix et quantité en vente), la moyenne, les objets qui ont le plus bougé sur 7 jours, la recherche dans tes scans, « Surveiller » (alerte de prix) et « Vendre ». La courbe se remplit aussi à chaque recherche d'un objet.",
        },
    },
    {
        version = "1.34.4", date = "18/11/2026",
        changed = {
            "Bateaux : plus aucun bouton à cliquer. Les boutons « Il part » / « Il arrive » du bandeau au quai sont retirés : l'heure de chaque navire se cale toute seule, quand tu le prends, à l'annonce du maître de quai près de toi, ou par le partage avec ta guilde et ton groupe.",
        },
    },
    {
        version = "1.34.3", date = "18/11/2026",
        changed = {
            "Hôtel des ventes : nos onglets (Achat, Vente, Annulation, Scan) ont maintenant l'allure de ceux du jeu (texte, trait de séparation, souligné à la couleur d'accent quand choisi, même police et même hauteur), collés à droite des siens sur un fond de barre d'onglets, au lieu de gros boutons roses posés par-dessus le reste.",
        },
    },
    {
        version = "1.34.2", date = "18/11/2026",
        added = {
            "Bateaux : l'annonce du maître de quai (« … vient d'arriver ») est repérée quand tu es près du quai et cale l'heure de la ligne toute seule, sans prendre le bateau ni cliquer.",
        },
        changed = {
            "Tableau des bateaux : tant qu'une ligne n'a pas d'heure, il dit « heure inconnue » et explique en bas comment la caler (un seul départ vu suffit), au lieu d'un texte coupé.",
        },
    },
    {
        version = "1.34.1", date = "18/11/2026",
        fixed = {
            "Hôtel des ventes : nos onglets passaient sous des éléments de la fenêtre du jeu (texte « 10% », titre d'onglet par-dessus) ; ils sont maintenant au-dessus de tout.",
            "Hôtel des ventes : l'onglet du jeu restait affiché comme choisi quand un des nôtres était ouvert.",
            "Onglet Scan : plus de doublons (les petits onglets « Listes d'achat » et « Ventes » du panneau et sa croix sont retirés, le bouton « Scanner » du haut aussi : Achat et Annulation sont des onglets à part).",
            "Les messages des listes d'achat renvoient vers l'onglet « Achat » au lieu de l'ancien panneau.",
        },
    },
    {
        version = "1.34.0", date = "18/11/2026", restart = true,
        added = {
            "Hôtel des ventes façon Auctionator : quatre onglets en bas de la fenêtre de l'HV, à côté de ceux du jeu (Achat, Vente, Annulation, Scan) ; un onglet du jeu les referme.",
            "Vente : tes sacs avec seulement ce qui se vend (liés, verrouillés à la main et objets de quête cachés ; « HV » = prix connu, étoile = à vendre d'après le Rangement), prix proposé tout seul (plus bas des autres moins l'écart, ou ton prix si tu es déjà le moins cher, sinon le prix du scan), quantité, durée, dépôt, « Mettre en vente » puis l'objet suivant ; à droite les enchères en cours (la plus basse et la tienne surlignées), tes derniers prix et tes ventes.",
            "Achat : tes listes d'achat, « Tout chercher » (plus bas et quantité en vente par objet), « Acheter N » puis « Confirmer » par objet, ou « Tout acheter » à la suite ; un objet qui n'est pas une marchandise ouvre la recherche du jeu.",
            "Annulation : tes enchères avec leur état (sous-cotée en rouge, plus bas en vert), temps restant, « Vérifier les prix » et « Annuler la suivante » (un clic par enchère).",
            "Scan : le panneau d'avant (scan, alertes de prix, listes, ventes) est maintenant dans cet onglet, plus collé à côté de la fenêtre.",
        },
    },
    {
        version = "1.33.0", date = "18/11/2026", restart = true,
        added = {
            "Bateaux et zeppelins tirés des fichiers du jeu : les 12 lignes de WoW Forever sont connues dès l'installation (Hurlevent – Auberdine, Austrivage, Plumelune, Île de Zephras, Port de Poudrefuse…), avec leurs quais, leur trajet et la durée exacte de leur tour (mesurée par Nauticus). Un seul départ vu (traversée, « Il part » / « Il arrive », ou partagé par la guilde ou le groupe) suffit à caler l'heure.",
            "Carte du monde : le trajet de chaque ligne et le navire là où il est, qui avance chaque seconde ; survol = où il va et quand, clic = tableau des bateaux. Minicarte : le navire quand il est proche.",
            "Bandeau au quai : les 3 prochains départs avec l'heure d'arrivée de l'autre côté, « exact » ou « estimé », et des alertes (le bateau arrive au quai dans 30 s, il part dans 15 s), avec son au choix.",
            "Tableau des bateaux et zeppelins : chaque ligne avec son navire, son tour, où il en est et le prochain départ du quai le plus proche ; clic = guidage vers le quai, bouton « partager » = le prochain départ écrit dans le chat. Ouvert par le nouveau raccourci « Bateaux » du micro menu, /wk bateaux, ou le bouton de QoL > Carte.",
            "QoL > Carte : nouvelle carte « Bateaux et zeppelins » (bandeau, alertes, son, navires sur la carte, partage).",
        },
        changed = {
            "Les bateaux appris en jeu qui sont des lignes du jeu (comme Hurlevent – Auberdine) sont remplacés par la ligne du jeu.",
        },
    },
    {
        version = "1.32.0", date = "18/11/2026",
        added = {
            "Horaires des bateaux partagés avec ton groupe et ta guilde (ceux qui ont Warband Keeper) : chaque départ appris ou signalé (« Il part », « Il arrive ») leur est envoyé, et tu reçois les leurs ; à la connexion, les départs récents sont échangés. Les horaires sont donc vite justes sans prendre chaque bateau plusieurs fois.",
            "QoL > Carte, Navigation : réglage « Partager les horaires des bateaux » ; /wk bateau compte les horaires reçus.",
        },
    },
    {
        version = "1.31.8", date = "18/11/2026",
        fixed = {
            "Horaires des bateaux : le « ~ » devant les temps s'affichait mal avec la police du jeu ; il est remplacé par « env. » (« dans env. 1:20 »).",
            "Bateaux : le quai d'arrivée pouvait prendre le nom du continent (« Bateau pour Kalimdor ») quand le jeu donne la carte du continent à bord ; c'est maintenant la zone sous le perso. Ces trajets mal nommés sont oubliés une fois.",
        },
    },
    {
        version = "1.31.7", date = "18/11/2026",
        fixed = {
            "Bateaux vers un autre continent : la traversée se terminait à l'écran de chargement, en pleine mer (quai nommé « Royaumes de l'Est », durée du trajet trop courte, horaires faux). Elle se termine maintenant quand le bateau s'arrête au vrai quai. Les trajets et horaires appris avant sont oubliés une fois : reprends le bateau pour les réapprendre.",
            "Horaires : plus de compte à rebours tant qu'un seul départ est connu (il était deviné et souvent faux) ; « en cours d'apprentissage » à la place.",
        },
        added = {
            "Bandeau au quai : boutons « Il part » et « Il arrive » pour signaler le bateau que tu vois partir ou arriver, sans le prendre ; chaque signalement précise les horaires.",
        },
    },
    {
        version = "1.31.6", date = "18/11/2026",
        fixed = {
            "Carte : un bateau appris en le prenant avait deux traits au départ du quai (son vrai trajet et un trait droit vers la destination) ; seul le vrai trajet reste.",
        },
    },
    {
        version = "1.31.5", date = "18/11/2026",
        changed = {
            "Bandeau au quai : il apparaît dès le ponton (à 120 m du quai au lieu de 60) et reste affiché tant que tu attends dessus (jusqu'à 200 m), au lieu de disparaître en avançant vers le bateau.",
        },
    },
    {
        version = "1.31.4", date = "18/11/2026",
        fixed = {
            "Carte du monde : erreur Lua en boucle sous l'épingle du guidage (étiquette sur trois lignes) depuis la 1.31.3.",
        },
    },
    {
        version = "1.31.3", date = "18/11/2026",
        changed = {
            "Carte du monde, guidage : le trajet à pied est un trait fin et plein à la couleur d'accent, cerné de sombre, au lieu de gros points.",
            "Carte du monde : sous l'épingle du guidage, la destination sur trois lignes (nom, ce que c'est comme « Maître des gryphons », distance).",
        },
    },
    {
        version = "1.31.2", date = "18/11/2026",
        fixed = {
            "Bateaux : une traversée n'était pas repérée quand le jeu considérait le perso en mouvement sur le pont ; elle l'est maintenant aussi quand la position avance bien plus vite que le perso ne peut courir.",
        },
        added = {
            "/wk bateau : la détection des bateaux est-elle active, es-tu en traversée, et le journal des derniers trajets (début, fin, ou pourquoi un trajet n'a pas été retenu).",
        },
    },
    {
        version = "1.31.1", date = "18/11/2026",
        fixed = {
            "Infobulles d'objets de l'addon (butin des donjons, listes…) : la comparaison avec l'objet équipé ne s'ouvre plus à côté, par-dessus ; Maj enfoncée la montre quand même.",
        },
    },
    {
        version = "1.31.0", date = "18/11/2026", restart = true,
        added = {
            "Horaires des bateaux et zeppelins, appris en les prenant : chaque traversée note l'heure du départ et la durée du trajet ; le tour se déduit des départs vus (« ~ » tant qu'il est encore estimé, il se précise à chaque traversée).",
            "Carte du monde : sous chaque quai déjà pris, le prochain départ (« dans 3:10 », vert « à quai · 0:42 » quand le bateau est là) ; au survol, départ, suivant, durée du trajet et du tour, pour chaque destination.",
            "Au quai : à moins de 60 m, un bandeau donne le prochain départ avec une barre qui se vide, « À quai : monte, il part dans… », et les autres destinations du quai. À placer en mode édition ; réglage dans QoL > Carte, Navigation.",
            "Navigation : vers un quai, la flèche dit « départ dans X » et « tu arrives à temps » ou « le suivant dans X » ; au quai, « à quai, départ dans X ».",
        },
    },
    {
        version = "1.30.0", date = "18/11/2026", restart = true,
        added = {
            "Donjons > Parcours : chrono du passage en tête de l'onglet, avec le record du donjon (temps, perso, date), ton avance ou ton retard au dernier boss, la moyenne de tes passages complets et une barre d'avancée (trait or : où en était le record au même moment).",
            "Donjons > Parcours : sous chaque boss tué, son temps depuis l'entrée et l'écart avec le record (vert en avance, rouge en retard) ; les boss suivants montrent le temps du record.",
            "Donjons : « Annoncer au groupe » écrit l'avancée dans le canal du groupe (boss, chrono, record, prochain boss) ; « Partager le parcours » envoie boss tués et chrono aux membres qui ont Warband Keeper.",
            "Donjons : historique des loots, « Tombé dans ce donjon » (objet, boss, quand, qui l'a gagné) sous la frise, et « Vu tomber X fois » dans l'infobulle des objets. Tout commence avec cette version.",
            "Chrono de donjon à l'écran, en option (interrupteur « Chrono à l'écran » de l'onglet Parcours) : temps de chaque boss et écart avec le record, à placer en mode édition.",
        },
    },
    {
        version = "1.29.2", date = "18/11/2026",
        changed = {
            "Objets verrouillés, règle « Recettes » : une recette qu'un de tes persos a déjà apprise n'est plus verrouillée ; tu peux la vendre. Seules restent verrouillées celles qu'aucun de tes persos ne connaît encore.",
        },
    },
    {
        version = "1.29.1", date = "18/11/2026",
        changed = {
            "Inventaire : colonne de gauche plus sobre. Deux groupes, « Outils » et « Persos », une ligne par entrée et le chiffre dans une pastille à droite (à la couleur d'accent pour l'entrée choisie, en or quand il y a quelque chose à faire : à ranger, à regrouper, oubliés). Le détail (« 13 objets dispersés »…) est dans l'infobulle.",
        },
    },
    {
        version = "1.29.0", date = "18/11/2026",
        changed = {
            "Inventaire > Rangement : plus lisible. En haut, trois chiffres (à envoyer à tes persos, pour l'HV avec la valeur, au marchand) ; dessous, une colonne par destination (ton perso à sa couleur de classe avec ses métiers, le perso HV en or, le marchand). Chaque objet a sa raison et qui le détient en petit dessous (« de Lapine ») ; au-delà de 6 objets, « + N autres » déplie la colonne.",
        },
    },
    {
        version = "1.28.7", date = "18/11/2026",
        changed = {
            "QoL > Feu de camp, objets par métier : quand le palier vient d'un autre de tes persos, tout passe à sa couleur de classe (effet, surlignage, compétence, pastille) ; la couleur d'accent reste pour ce qui est à toi.",
        },
    },
    {
        version = "1.28.6", date = "18/11/2026",
        changed = {
            "QoL > Feu de camp, objets par métier : le nom du perso qui a le palier est écrit à sa couleur de classe, contour compris.",
        },
    },
    {
        version = "1.28.5", date = "18/11/2026",
        changed = {
            "QoL > Feu de camp, « Comment ça marche » : les 4 étapes en tuiles bien visibles (gros numéro à la couleur d'accent, titre court, texte en clair) au lieu de petites lignes grises ; les effets de camp rencontrés sont plus gros, leur type à la couleur d'accent.",
        },
    },
    {
        version = "1.28.4", date = "18/11/2026",
        fixed = {
            "QoL > Feu de camp, objets par métier : « à toi » seulement si le perso connecté a le palier. Sinon la pastille donne le nom de ton perso qui l'a (ex. ton chasseur pour le Dépeçage), avec un contour à la couleur d'accent.",
        },
    },
    {
        version = "1.28.3", date = "18/11/2026",
        fixed = {
            "Kit de camp : le temps restant sur les icônes (« 59m ») était assombri par le voile de recharge. Il passe au-dessus, plus gros et cerné de noir ; le nombre d'objets aussi.",
        },
    },
    {
        version = "1.28.2", date = "18/11/2026",
        changed = {
            "QoL > Expérience, « Tous tes persos » : une carte par perso (3 par ligne) au lieu du tableau. Icône de classe, nom, « vu il y a… », niveau en grand, barre XP comme celle du jeu avec le repos en bleu juste devant, puis l'XP restante, le repos en % d'un niveau (pastille « plein » à 150 %) et dans combien de temps il sera plein, en auberge ou dehors.",
        },
    },
    {
        version = "1.28.1", date = "18/11/2026",
        added = {
            "Halo, Atelier > Donneurs de quêtes : option « Seulement les quêtes de ton journal ». Seuls brillent les PNJ où rendre une quête de ton journal ou liés à une quête en cours, pas ceux qui proposent une nouvelle quête (ni les monstres à tuer).",
        },
    },
    {
        version = "1.28.0", date = "18/11/2026",
        changed = {
            "LFG : l'infobulle d'un groupe montre ses buffs en icônes de sorts : une rangée pour le groupe, une rangée « + » pour ce que tu ajouterais, une rangée éteinte pour ce qui manque, et « Camp : N de tes objets annulés ». Maj enfoncée : la liste avec les noms (s'actualise sans bouger la souris).",
        },
        fixed = {
            "LFG : les pseudos en cyrillique (joueurs russes) s'affichaient en carrés ; ils sont écrits en lettres latines (Morog au lieu de carrés) dans les cartes, l'infobulle, les récents et les demandes.",
        },
    },
    {
        version = "1.27.4", date = "18/11/2026",
        changed = {
            "QoL > Feu de camp, objets par métier : plus de gris pâle. Tous les noms sont lisibles, les compétences sont en or ; le palier atteint est surligné avec une pastille « à toi », les autres disent où en est ton meilleur perso (« Forge 132/140 »), la compétence requise (« 300 requis ») ou « aucun perso ». Feux de camp pas encore atteints : nom lisible, « Cuisine 140 requis » en or.",
        },
    },
    {
        version = "1.27.3", date = "18/11/2026",
        changed = {
            "Carte : la patrouille d'un rare est une ligne fine continue, avec un liseré sombre pour rester visible, au lieu de gros points ; celle du rare survolé est un peu plus épaisse et passe au-dessus.",
        },
    },
    {
        version = "1.27.2", date = "18/11/2026",
        changed = {
            "Carte du monde : quand on zoome, les icônes (lieux, rares, filons, notes, quais, repère) et les tracés (patrouilles des rares, trajets, bateaux) gardent à peu près leur taille à l'écran au lieu de grossir avec la carte ; plus de pâté illisible en zoom.",
        },
    },
    {
        version = "1.27.1", date = "18/11/2026",
        changed = {
            "Fiche d'un autre perso : le bouton « Mon perso » est à droite de l'en-tête, à côté du niveau moyen, au lieu d'être collé au nom.",
            "Objets verrouillés : la touche ne se choisit plus que dans Inventaire > Objets verrouillés (retirée des Options, en double).",
        },
        fixed = {
            "Inventaire > Objets verrouillés : l'infobulle d'une icône répétait le verrou et les persos qui ont l'objet ; il ne reste que l'action (clic droit pour déverrouiller).",
        },
    },
    {
        version = "1.27.0", date = "18/11/2026", restart = true,
        added = {
            "Rangement intelligent (Inventaire > Rangement) : chaque composant va au perso qui s'en sert, d'après ses métiers : composants de ses guides de montée jusqu'au palier visé, composants de ses recettes connues, recettes de son métier qu'il ne connaît pas encore. La liste est rangée par perso, avec la raison (« guide : 40 jusqu'à 125 », « recette à apprendre »…).",
            "Perso HV : choisis le perso qui vend à l'HV ; ce dont personne n'a besoin part chez lui si le lot vaut au moins le seuil (50 pa par défaut) au prix du scan, sinon il est proposé au marchand. Réglages : prix proposé, durée, réserve à garder.",
            "Boîte aux lettres : un panneau « Rangement » liste ce que ce perso doit envoyer (vers le perso qui s'en sert, ou vers le perso HV), coché par défaut ; « Envoyer » fait les courriers. Tes règles d'envoi passent toujours avant, et rien de verrouillé n'est proposé.",
        },
    },
    {
        version = "1.26.1", date = "18/11/2026",
        changed = {
            "Objets verrouillés : la touche se choisit aussi dans Options > Général (carte « Objets verrouillés »). Par défaut : Alt + clic molette, rarement prise par les autres addons ; si tu avais gardé l'ancien défaut (Alt + clic), il passe à Alt + clic molette.",
        },
    },
    {
        version = "1.26.0", date = "18/11/2026",
        changed = {
            "Objets verrouillés (Inventaire) : une icône par objet au lieu d'une ligne, rangées par raison (À la main, Objets de quête, Recettes avec le détail par métier, autres règles), avec la quantité sur le compte. Survol : raison et persos qui l'ont ; clic droit : déverrouiller.",
        },
        added = {
            "Objets verrouillés : un verrou posé à la main s'enlève tout seul quand l'objet n'est plus nulle part sur le compte (recette apprise, objet vendu, utilisé pour un craft, donné). Jamais pendant qu'un marchand est ouvert ni tant que l'objet est dans le rachat, pour que le rachat automatique marche toujours.",
        },
    },
    {
        version = "1.25.3", date = "18/11/2026",
        added = {
            "Objets verrouillés : nouvelles touches au clic molette (Clic molette, Alt + clic molette, Ctrl + clic molette), pour ne pas gêner les addons qui prennent les combinaisons au clic gauche (Polstar et Ctrl + Alt + clic).",
        },
        changed = {
            "Étoile BiS sur les cases des sacs : en bas à gauche de la case.",
            "Halo : portée de 15 m au plus ; le mode pêche la monte à 60 m seulement le temps de pêcher.",
        },
        fixed = {
            "Liste BiS, menu « … » : erreur Lua à chaque clic quand le menu était ouvert (fonction absente sur ce client).",
            "Halo : après la pêche, la portée restait à 60 m au lieu de revenir à la tienne.",
            "Objets verrouillés : la recherche de la case sous la souris utilisait la même fonction absente.",
        },
    },
    {
        version = "1.25.2", date = "18/11/2026",
        fixed = {
            "Carte : à Auberdine (et ailleurs), des quais apparaissaient en double. C'étaient des trajets en bateau appris avant la 1.24.5 qui doublaient les trajets connus (Menethil, Rut'theran) : ils sont retirés. Deux quais au même endroit ne font plus qu'une pastille, avec toutes leurs destinations au survol.",
        },
    },
    {
        version = "1.25.1", date = "18/11/2026", restart = true,
        changed = {
            "Carte et minicarte : les maîtres de vol ont un petit griffon (et le filtre « Maîtres de vol » aussi).",
        },
    },
    {
        version = "1.25.0", date = "18/11/2026", restart = true,
        changed = {
            "Carte et minicarte : les quais montrent un petit bateau ou un petit zeppelin au lieu d'une flèche ; les zeppelins (pastille et trait) sont orange pour les distinguer des bateaux. L'icône du filtre « Bateaux et zeppelins » est aussi un bateau.",
        },
    },
    {
        version = "1.24.5", date = "18/11/2026",
        fixed = {
            "Carte : un même quai pouvait annoncer deux destinations (par exemple Cabestan « vers Vallée de Strangleronce » et « vers Les Tarides »). Le second était un faux trajet en bateau appris (un autre déplacement sans bouger pris pour un bateau). Un trajet n'est plus appris que s'il change de continent, ou de région sur au moins 500 m, et s'il n'est pas déjà connu ; les faux trajets déjà appris sont retirés.",
        },
    },
    {
        version = "1.24.4", date = "18/11/2026",
        changed = {
            "Carte du monde : les étiquettes « vers … » des bateaux et zeppelins ne sont plus posées sur la carte ; la destination s'affiche au survol du quai (infobulle).",
        },
    },
    {
        version = "1.24.3", date = "18/11/2026",
        changed = {
            "QoL > Expérience : la ligne « Position » (bouton « Placer la barre ») est retirée ; la barre se place toujours avec le mode édition.",
        },
    },
    {
        version = "1.24.2", date = "18/11/2026",
        changed = {
            "QoL > Expérience : la carte « Repos » est retirée (le repos de chaque perso reste dans « Tous tes persos » et sur la barre d'expérience).",
        },
    },
    {
        version = "1.24.1", date = "18/11/2026",
        changed = {
            "QoL > Expérience : le tableau « Tous tes persos » est en tête de l'onglet, avant la barre, le repos et le rythme.",
        },
    },
    {
        version = "1.24.0", date = "18/11/2026",
        added = {
            "LFG : l'infobulle d'un groupe liste ses buffs, d'après la classe et le niveau de chaque membre : « Dans le groupe », « Avec toi en plus » (ce que ton perso ajouterait) et « Manquants ». Les buffs de talent sont marqués « si talent » (le jeu ne dit pas les talents des autres). En bas, les buffs qui annulent un objet de camp (Robustesse et Secourisme, Intelligence des arcanes et Herboristerie…).",
        },
    },
    {
        version = "1.23.1", date = "18/11/2026",
        changed = {
            "Apparence : un seul thème, Graphite (gris sobre, couleur de ta classe en accent), pour tous les persos. Le choix des thèmes et le thème personnalisé sont retirés des Options ; couleurs, police et taille restent réglables.",
        },
    },
    {
        version = "1.23.0", date = "18/11/2026", restart = true,
        added = {
            "Curseur : traînée scintillante derrière la souris (QoL > Curseur > Traînée). Trois styles : Étincelles (petites étoiles qui scintillent), Comète (ruban lumineux qui s'affine) et Poussière d'étoiles (paillettes qui tombent). Couleur d'accent, de classe, or, arc-en-ciel ou blanc ; longueur, densité, et option « pas en combat ». Rien quand la souris ne bouge pas, aucun clic bloqué ; le bouton « Tester » du mode édition la fait tourner en cercle.",
        },
    },
    {
        version = "1.22.5", date = "18/11/2026",
        changed = {
            "QoL > Feu de camp : la carte « Objets de camp par métier » est en tête de l'onglet, avant les réglages.",
        },
    },
    {
        version = "1.22.4", date = "18/11/2026",
        added = {
            "Objets verrouillés : deux nouvelles touches au choix, Ctrl + Alt + clic et Ctrl + Maj + clic, pour ne pas gêner les autres addons qui utilisent Alt + clic (Inventaire > Objets verrouillés > Touche pour verrouiller). Chaque combinaison est exacte : Alt + clic ne réagit plus si Ctrl ou Maj est aussi enfoncé.",
        },
    },
    {
        version = "1.22.3", date = "18/11/2026",
        added = {
            "Traduction anglaise complète : plus de 1 100 textes ajoutés (réglages, pages, cartes, infobulles, alertes). Seules les sorties de diagnostic des commandes /wk restent en français.",
        },
    },
    {
        version = "1.22.2", date = "18/11/2026",
        fixed = {
            "Sacs EUI : cadenas et étoiles BiS n'apparaissaient qu'au survol. Les cadres de sac d'EUI se faisaient passer pour des cases et arrêtaient la recherche ; seules les vraies cases (boutons) sont prises, jusqu'au fond du sac.",
            "/wk sacs : indique pour chaque sac le nombre de cases trouvées, et marque d'une * les cadres qui se présentent comme une case.",
        },
    },
    {
        version = "1.22.1", date = "18/11/2026",
        fixed = {
            "Objets verrouillés et étoile BiS : le cadenas n'apparaissait pas après un Alt + clic (le verrou était bien posé, mais les cases n'étaient jamais redessinées).",
            "Sacs de l'interface EUI de WoW Forever (liste qui défile) : les cases sont retrouvées directement dans le sac, et Alt + clic vise la case réellement sous la souris (les cases recyclées changent d'objet en défilant).",
        },
    },
    {
        version = "1.22.0", date = "18/11/2026",
        changed = {
            "Carte du monde : un seul affichage des récoltes, le calque « Filons et plantes » (filtré par tes métiers et ta compétence). L'ancienne carte des coins de récolte, qui se superposait, est retirée.",
            "Halo : portée de désignation réglable jusqu'à 60 m ; le mode pêche la met toujours à 60 m (Halo ne la réduit plus pendant la pêche).",
            "Plans de talents : l'import d'un code n'applique plus la règle des 5 points par rangée (elle ne correspondait pas toujours aux arbres de WoW Forever).",
            "QoL > Micro menu : le réglage s'appelle « Afficher le micro menu » (il affiche toute la barre, pas seulement l'horloge).",
            "Couleurs : une soixantaine de couleurs fixes suivent maintenant le thème (repos en bleu, verrous par règle en turquoise, mode plan en violet…).",
            "Boutons de suppression (surplus, prix, chemins appris, alertes, coins de récolte) au style « danger ».",
            "Panneaux du plan de talents et du donjon : fermés à la croix, ils ne se rouvrent plus tout seuls (commande ou bouton pour les rouvrir).",
            "Mode édition : la barre de pêche se place sans avoir pêché ; aperçus pour l'horloge et le bouton d'aspect ; les éléments coupés n'y apparaissent plus en boîte vide.",
        },
        fixed = {
            "Objets verrouillés : un Alt + clic tenu un peu longtemps verrouillait puis déverrouillait l'objet ; le cadenas apparaît aussitôt. L'infobulle donne la bonne touche (Alt, Ctrl ou Maj + Alt). /wk sacs détaille les cases sous la souris.",
            "Vols : un atterrissage anticipé avec le bouton du jeu n'est plus appris comme durée complète ; positions des relais relues à chaque maître de vol.",
            "Récolte : les nouveaux nœuds s'affichent même au-delà de 3 000 récoltes ; le thorium n'est plus rouge entre 245 et 274 ; plus d'enregistrement avec le module coupé.",
            "Halo : la ligne « Herboristerie N » apparaît sur toutes les plantes ; réglages du jeu laissés tranquilles avec le module coupé ; moins de calculs en ville.",
            "Passage de niveau : le guidage vers le maître de classe ne remplace plus un guidage en cours.",
            "Talents : les points pas encore validés ne vont plus dans « Montée enregistrée » ; points libres justes avec plusieurs arbres.",
            "Première connexion d'un chasseur ou d'un chaman : rappels et relevés lancés même avant que la classe soit enregistrée.",
            "Liste BiS : « Équiper » annonce le vrai nombre d'objets équipés.",
            "Achats automatiques chez le marchand : budget tenu achat par achat (plus d'achats refusés faute d'or).",
            "Oublier un perso efface aussi ses builds, plans, listes BiS, armes, envies, règles et historique.",
            "Le /played automatique de la connexion est caché sans remplacer de fonction du jeu.",
            "HV, ventes : la recherche suivante attend la réponse du serveur ; un prix n'est plus écrit dans une fenêtre de vente qui a changé d'objet.",
            "Objets verrouillés : la règle « recettes » marche aussi sur un client anglais ; le dépôt en banque respecte les verrous à la main.",
            "Modules coupés : courrier automatique, session de farm et détection des boss s'arrêtent vraiment.",
            "/wk cherche sans texte affiche l'aide au lieu de tout le compte.",
            "Anneau du curseur, micro menu, familier, HUD de récolte : réglage changé en combat appliqué à la sortie ; HUD de récolte rouvert après le combat ; carte du familier effacée qui ne prend plus de clic au hasard.",
            "Kit de camp : s'affiche près d'un feu même quand l'encart et l'icône du feu sont coupés.",
            "Alertes : une alerte qui change seulement de couleur ou de priorité est mise à jour ; montants d'or négatifs bien arrondis.",
            "Bouton d'aspect du chasseur : l'icône montre l'aspect que lancera le prochain clic.",
            "Après un changement de thème, la recherche trouve de nouveau tous les réglages, et les éléments à l'écran suivent l'accent.",
            "HV : quatre boutons du panneau retrouvent leur effet de survol ; anneau du plan de talents éteint à la fermeture ; note de carte supprimée qui n'est plus recréée.",
            "Pages : tuiles de Farm et colonne du filtre de butin qui ne se chevauchent plus en petite fenêtre ; anciens groupes LFG effacés en changeant de catégorie, échec de recherche affiché, groupe reconnu après /reload ; filtre « Manquantes » remis à zéro ; menus « Pour » à jour (perso renommé ou oublié) ; quêtes de donjon filtrées pour le perso affiché ; persos oubliés retirés des listes de QoL ; bouton « Recharger » qui ne recouvre plus les modules repliés.",
            "Recherche : les réglages du filtre de butin, de la mini-fenêtre de farm et du LFG sont trouvables.",
        },
    },
    {
        version = "1.21.1", date = "18/11/2026",
        fixed = {
            "Listes d'achat de l'HV : la quantité était comptée deux fois (ce qui manquait, moins encore ce que tu avais) ; rien n'était acheté et la ligne disparaissait alors qu'il en manquait. La liste retient maintenant la quantité à avoir sur le compte ; les listes déjà faites sont converties.",
            "Objets verrouillés par règle : une envie ajoutée, un scan de l'HV ou un nouveau métier sont pris en compte tout de suite (avant : après /reload seulement).",
            "Profils : un profil enregistré avec une ancienne version pouvait effacer un réglage ajouté depuis (risque d'erreur après une mise à jour).",
            "Profils : les alertes de prix de l'HV, les morts récentes de rares et les armes enregistrées du guerrier ne changent plus avec le profil (ce sont des données).",
            "Dépôt en banque : sans banque de bataillon utilisable, les règles « bataillon » déposent dans la banque du perso au lieu d'annoncer « banque pleine ».",
            "Journal de l'HV : deux ventes identiques arrivées à quelques secondes d'écart ne comptent plus pour une seule.",
            "Filtre de butin : un objet qui demande une confirmation (lié quand ramassé) n'est plus annoncé « sacs pleins » et la fenêtre ne se ferme plus pendant la confirmation.",
            "Moins de saccades en farm : la fortune totale n'est plus recalculée à chaque relevé des sacs (une fois par minute au plus).",
            "Dépeçage : le niveau maximum des monstres était faux (à 300, niveau 40 au lieu de 60) ; couleurs des cuirs et zones conseillées corrigées.",
            "Donjons : le passage en cours (boss tués) est gardé si tu sors et reviens dans l'heure (wipe, cimetière dehors, /reload).",
            "Donjons : l'alerte « envie tombée » ne sonne plus qu'une fois par objet, et seulement en instance (plus pour un achat chez un marchand).",
            "Vols : durée estimée et barre de vol plus justes sur un trajet pas encore appris (vitesse et longueur mesurées de la même façon).",
            "Chaman : la recharge de Réincarnation est de nouveau lue.",
            "Voleur : l'achat automatique de poisons prend le rang le plus élevé du marchand.",
            "Fiche perso : en passant à un autre perso, le mode plan, le build déplié, la fenêtre de choix BiS et les confirmations ouvertes se ferment (un clic pouvait modifier ou supprimer le plan ou le build de l'autre perso).",
            "Fiche perso : le niveau moyen de l'équipement était gonflé (17 emplacements divisés par 16).",
            "Fiche perso : moins de rafraîchissements quand le jeu charge beaucoup d'objets d'un coup.",
            "Anneau du curseur « en combat seulement » : il ne s'affichait jamais.",
            "Micro menu déplié : il ne se recalcule plus à chaque image (moins de charge avec « toujours déplié »).",
            "Carte du familier : en mode édition elle s'affiche même sans familier, et elle ne garde plus les valeurs d'exemple après.",
            "LFG : « Mes demandes » et « Récents » défilent au lieu de passer sous « MON MESSAGE » ; les champs du message et des niveaux retrouvent leur bordure et leur texte d'aide.",
            "Stats : au survol de la courbe « Richesse totale », le montant s'affiche en or.",
            "Donjons : le passage en cours n'apparaît plus quand la page montre un autre perso.",
            "Profils : « Copier dans mon profil » et « Supprimer » agissent sur le profil affiché dans le menu, sans devoir le rouvrir.",
            "Options et Patch notes : les vignettes de thème, la carte « À propos » et les notes s'adaptent à la largeur de la fenêtre (plus de débordement en petite taille).",
        },
    },
    {
        version = "1.21.0", date = "18/11/2026",
        fixed = {
            "Persos et fiche : erreur Lua avec un royaume dont le nom contient « rp » (royaume JdR) ; la page Persos et l'en-tête de la fiche plantaient.",
            "Résumé, « À faire » : un clic sur une ligne de courrier ou de métier faisait une erreur quand le module était coupé. Ces lignes ne s'affichent plus quand leur module est coupé.",
            "Guerrier : les boutons « Deux mains » et « Arme et bouclier » faisaient une erreur et n'équipaient rien.",
            "Chasseur : les munitions achetées automatiquement sont maintenant équipées quand elles sont meilleures.",
            "Chasseur : les rappels Grondement (en groupe en donjon ou en raid) et Pistage des humanoïdes (en champ de bataille) ne se déclenchaient jamais : l'addon ne voyait pas le type d'instance.",
            "Filtre de butin : les règles qui dépendent du type de zone (donjon, raid, champ de bataille) ne s'appliquaient pas.",
            "Liste BiS : glisser un objet sur une case ne faisait rien ; « Partager » disait toujours « Liste vide ».",
            "Guidage : les étapes de vol suivent maintenant le vrai trajet déjà fait au lieu d'une ligne droite.",
            "QoL, carte Munitions du chasseur : la phrase « si tu tires à l'arc… », prévue pour les autres classes, ne s'affiche plus.",
        },
    },
    {
        version = "1.20.9", date = "18/11/2026",
        fixed = {
            "Objets verrouillés : Alt + clic ne faisait rien dans le sac de WoW Forever. Le clic est maintenant capté où qu'il passe.",
            "Cadenas et étoile BiS : il suffit de survoler un objet pour que toutes les cases du même sac soient reconnues (avant, chaque case devait être survolée).",
        },
    },
    {
        version = "1.20.8", date = "18/11/2026",
        fixed = {
            "Objets verrouillés et repère BiS : sur certains sacs, l'addon ne trouvait pas les cases ; ni cadenas, ni étoile, et Alt + clic ne faisait rien. Une case est maintenant aussi reconnue dès que tu la survoles (infobulle de l'objet).",
        },
        added = {
            "/wk sacs : diagnostic des sacs (sacs ouverts, cases trouvées, case sous la souris), à envoyer si le cadenas n'apparaît toujours pas.",
        },
    },
    {
        version = "1.20.7", date = "18/11/2026",
        fixed = {
            "Liste BiS, menu « ... » : il restait ouvert après un clic sur Dupliquer, Renommer, Code, Importer, Supprimer ou Vider. Il se ferme maintenant après chaque choix, et aussi quand tu cliques en dehors.",
        },
    },
    {
        version = "1.20.6", date = "18/11/2026",
        added = {
            "Sacs : une étoile en haut à gauche de la case repère les objets de tes listes BiS (sacs du jeu et page Inventaire). Étoile dorée : liste du perso connecté ; étoile grise : liste d'un autre de tes persos (l'infobulle dit lequel).",
        },
    },
    {
        version = "1.20.5", date = "18/11/2026",
        added = {
            "Kit de camp : timers sur les icônes, comme les barres d'action du jeu (voile qui tourne, temps restant au centre). Feu et sac de couchage : leur recharge ; objets de camp : la recharge commune d'1 h ; nourriture : le « Bien nourri » qu'il te reste, en vert. Les recharges sont en jaune.",
        },
    },
    {
        version = "1.20.4", date = "18/11/2026",
        added = {
            "Mode édition : la barre d'outils (Grille, Aimant, Disposition, Tester, Terminer) se déplace en la glissant par son fond ; sa place est gardée. Double-clic sur la barre pour la remettre en bas de l'écran.",
        },
    },
    {
        version = "1.20.3", date = "18/11/2026",
        changed = {
            "Panneau « Plan de montée » : le mot « appris » reste en vert vif sur les étapes faites ; seul le reste de la ligne est grisé.",
        },
    },
    {
        version = "1.20.2", date = "18/11/2026",
        fixed = {
            "Fiche d'un autre perso : les barres (Stats, Métiers), le niveau moyen, les talents et la progression BiS prenaient la couleur d'accent du perso connecté (avec le thème Graphite, la couleur de sa classe : un chasseur vu depuis le paladin s'affichait en rose). Ils prennent maintenant la couleur de classe du perso affiché ; les boutons gardent l'accent.",
        },
    },
    {
        version = "1.20.1", date = "18/11/2026",
        changed = {
            "BiS, fenêtre de choix : filtres rangés par ligne avec leur nom (Source, Qualité, Niveau, Armure), chaque ligne en bloc de boutons collés, l'option active pleine ; recherche plus large ; une croix ronde ferme la fenêtre.",
        },
    },
    {
        version = "1.20.0", date = "18/11/2026",
        changed = {
            "BiS, nouvelle mise en page : tes listes en onglets en haut (avec « obtenus / total » et « + Nouvelle »), mannequin centré comme la fenêtre de perso du jeu, 8 emplacements de chaque côté (Chemise et Tabard ajoutés), noms tournés vers le personnage, aperçu 3D plus grand au centre avec la bascule « La liste / Mon équipement », armes en dessous.",
            "BiS : « Équiper ce que j'ai » reste en bouton ; Partager, Copier d'un perso et un menu « … » (Dupliquer, Renommer, Code, Importer, Vider, Supprimer) passent en petites icônes à droite des onglets. Un emplacement vide n'affiche plus que son nom en gris.",
        },
    },
    {
        version = "1.19.10", date = "18/11/2026",
        fixed = {
            "Panneau « Plan de montée » : sans plan, le texte d'aide débordait du bouton et du panneau ; il s'affiche maintenant sur plusieurs lignes dans le panneau. Un nom de plan trop long est coupé dans son bouton.",
        },
    },
    {
        version = "1.19.9", date = "18/11/2026",
        fixed = {
            "Talents : pour certaines classes (le chasseur par exemple), un talent isolé à droite créait un 4e arbre « Arbre 4 », et les arbres perdaient leurs noms et leurs icônes. Les talents sont maintenant toujours rangés en trois arbres (un bloc isolé rejoint l'arbre voisin), avec les noms et icônes de spécialisation de la classe.",
            "Talents : une icône de spécialisation d'un autre perso pouvait rester affichée par-dessus le nom de l'arbre.",
        },
    },
    {
        version = "1.19.8", date = "18/11/2026",
        changed = {
            "Fiche du perso : la durabilité se colore selon l'usure, vert à 100 %, jaune vers 50 %, rouge à 0 %.",
        },
    },
    {
        version = "1.19.7", date = "18/11/2026",
        fixed = {
            "Fiche du perso : après avoir regardé un autre perso, la fiche (Fiche, Talents, BiS) pouvait rester sur lui ; elle revient maintenant au perso connecté à la connexion et quand la fenêtre se ferme.",
        },
        added = {
            "Fiche d'un autre perso : bouton « Mon perso » à côté du nom pour revenir au perso connecté.",
        },
    },
    {
        version = "1.19.6", date = "18/11/2026",
        changed = {
            "Plans de montée : supprimer un plan du perso connecté ferme le panneau « Plan de montée » et la fenêtre des talents du jeu à laquelle il est collé (hors combat).",
        },
    },
    {
        version = "1.19.5", date = "18/11/2026",
        fixed = {
            "Plans de montée : « Ouvrir le panneau » (et /wk plan) ouvrait le panneau derrière la fenêtre de l'addon, invisible ; il s'ouvre maintenant au premier plan, collé à droite de la fenêtre.",
        },
    },
    {
        version = "1.19.4", date = "18/11/2026",
        changed = {
            "Plans de montée : le bouton « Depuis le build ouvert » est retiré.",
        },
    },
    {
        version = "1.19.3", date = "18/11/2026",
        changed = {
            "Talents : les talents de rangées accessibles (5 points par rangée au-dessus, dans le même arbre) sont en couleur avec un liseré à ta couleur ; ceux des rangées pas encore ouvertes restent grisés. Aussi dans l'aperçu des builds et en mode plan.",
            "Mode plan : un talent d'une rangée pas encore ouverte est refusé, avec le nombre de points qu'il manque dans l'arbre.",
        },
    },
    {
        version = "1.19.2", date = "18/11/2026",
        changed = {
            "Panneau « Plan de montée » : toutes les étapes du plan dans une liste qui défile ; celles déjà apprises sont grisées et marquées « appris », l'étape en cours est surlignée. L'encart du haut n'apparaît plus que s'il reste un talent à prendre (plus de point d'interrogation quand le plan est terminé).",
        },
    },
    {
        version = "1.19.1", date = "18/11/2026",
        fixed = {
            "Barre d'expérience : la partie repos paraissait grise (bleu trop transparent sur le fond sombre) ; elle est maintenant d'un bleu franc.",
        },
    },
    {
        version = "1.19.0", date = "18/11/2026",
        added = {
            "BiS : plusieurs listes par perso (JcE, tank, montée, JcJ…). Colonne « Mes listes BiS » avec la progression de chacune ; clic sur une liste pour la charger. + Nouvelle, Dupliquer, Renommer, Code (partage), Importer, Supprimer ; « Copier d'un perso » reprend la liste affichée d'un autre perso comme nouvelle liste. L'ancienne liste devient « Ma liste BiS ».",
            "BiS : aperçu 3D au centre du mannequin, habillé avec les objets de la liste (glisser pour tourner) ; « Comparer avec mon équipement » bascule l'aperçu sur ce que tu portes.",
            "BiS : « Équiper ce que j'ai » met sur le perso connecté, hors combat, les objets de la liste déjà dans ses sacs.",
            "BiS : pastille d'état sur chaque objet (vert porté, jaune dans les sacs ou la banque, gris à obtenir) ; l'infobulle d'un objet dit dans quelle liste et pour quel perso il est prévu.",
        },
        changed = {
            "BiS : mannequin au format de la fenêtre de perso du jeu (700 de large au plus), à droite des listes.",
        },
    },
    {
        version = "1.18.1", date = "18/11/2026",
        fixed = {
            "Fiche du perso, équipement : le survol d'un objet porté ouvrait aussi l'infobulle de comparaison « Équipé » du jeu (le même objet en double) ; elle n'apparaît plus.",
        },
    },
    {
        version = "1.18.0", date = "18/11/2026", restart = true,
        added = {
            "Plans de montée de niveau (onglet Talents, sous les builds) : l'ordre des points de talent, un par niveau à partir du 10. « Nouveau plan » puis clic sur les talents dans l'ordre (mode plan : chaque talent affiche ses niveaux, « 10-14 » ; clic droit retire le dernier point), « Depuis le build ouvert » (ordre proposé rangée par rangée, à retoucher), code de partage et import, renommer, supprimer, « Suivre » pour choisir le plan actif. Un plan « Montée enregistrée » se remplit tout seul quand tu prends tes talents.",
            "Panneau « Plan de montée » collé à droite de la fenêtre des talents du jeu, ouvert et fermé avec elle : étape du niveau en cours (talent, rang, points libres) avec « Placer ce point », puis la liste des étapes (faites, en cours, à venir). Le talent à prendre est entouré dans la fenêtre du jeu quand elle le permet. /wk plan ou « Ouvrir le panneau » l'ouvrent seul ; réglage dans la carte des plans.",
            "Rappel à chaque niveau gagné : « Prochain talent : … » tant qu'il te reste un point libre.",
            "/wk talents dit aussi quelle fenêtre des talents le jeu utilise et si l'addon peut y placer des points.",
        },
    },
    {
        version = "1.17.1", date = "18/11/2026",
        added = {
            "Fiche du perso : aperçu 3D du perso au centre de l'équipement, comme la fenêtre de perso du jeu (glisser pour le tourner, molette pour zoomer). Pour un autre perso, l'aperçu prend sa race et son équipement si le jeu le permet ; sinon, le portrait de classe reste.",
            "Onglet Talents : l'icône de chaque spécialisation devant le nom de l'arbre (aussi dans l'aperçu des builds).",
        },
        changed = {
            "Fiche du perso : la carte Équipement garde des proportions proches de la fenêtre de perso du jeu (680 de large au plus) ; la place en plus va aux Stats et aux Métiers.",
        },
    },
    {
        version = "1.17.0", date = "18/11/2026", restart = true,
        added = {
            "Liste BiS en mannequin : les emplacements disposés comme dans la Fiche (à gauche, à droite, armes au centre sous le portrait), chacun avec l'objet choisi en couleur de qualité, son emplacement, sa source et son état (porté, dans les sacs, à la banque, à obtenir). En haut : progression « obtenus », Copier depuis un autre perso, Partager (liens dans le chat), Vider.",
            "Clic sur un emplacement : fenêtre de choix avec tous les objets du jeu de cet emplacement que ta classe peut porter (plus de 5 000 objets verts et plus, noms en français), recherche par nom, filtres de source (donjons, raids, artisanat, quêtes, autres), de qualité, de niveau et de type d'armure. Chaque ligne donne le niveau requis, où l'obtenir et les caractéristiques ; clic pour choisir. Clic droit sur un emplacement : retirer. Glisser-déposer et Maj+clic marchent toujours.",
        },
    },
    {
        version = "1.16.0", date = "18/11/2026",
        added = {
            "Fiche du perso, onglet Talents : « Mes builds » sous les arbres. « Enregistrer le build actuel » garde tes talents sous un nom (répartition, niveau) ; plusieurs builds par perso. Chaque ligne dit l'écart avec tes talents actuels (actif, points à placer, points à retirer).",
            "Clic sur un build : il se déplie et montre ses arbres en aperçu, liseré violet sur ce qu'il faudrait ajouter, rouge sur ce qu'il faudrait retirer. Re-clic pour replier.",
            "Boutons d'un build : Appliquer (perso connecté, hors combat : place tes points libres dans l'ordre du build ; s'il faut en retirer, l'addon te dit de réinitialiser chez ton maître de classe), Code (à copier pour le partager), Renommer, Supprimer. « Importer un code » reprend le build d'un autre joueur de la même classe.",
        },
    },
    {
        version = "1.15.0", date = "18/11/2026",
        changed = {
            "Fiche du perso, onglet BiS : plus de suggestions automatiques par niveau ; l'onglet est maintenant uniquement ta propre liste BiS (un objet par emplacement, à remplir par Maj+clic, glisser-déposer ou n°), avec la source de chaque objet et son état (porté, dans les sacs, à la banque, à obtenir). Le bouton « Remplir avec le meilleur trouvable » est retiré.",
        },
    },
    {
        version = "1.14.1", date = "17/11/2026",
        changed = {
            "Barre d'expérience au style du micro menu : cadre sombre arrondi au liseré fin, textes dans le cadre (niveau à ta couleur, repos en bleu, quêtes à rendre en jaune), piste arrondie avec un léger reflet, et un trait jaune lumineux là où tu arriverais en rendant tes quêtes. Largeur, épaisseur et version compacte inchangées.",
        },
    },
    {
        version = "1.14.0", date = "17/11/2026",
        changed = {
            "Inventaire : les objets sont rangés comme dans des sacs du jeu, un sac par catégorie (Munitions, Métaux et pierres, Viande et poisson, Étoffes et cuir, Herbes, Enchantement, Autres composants, Consommables, Équipement, Recettes, Objets de quête, Divers), en deux ou trois colonnes selon la largeur. Chaque objet est une case avec son icône, son nombre et un liseré de sa qualité ; chaque sac donne son nombre d'objets et sa valeur. Survol : où se trouve l'objet (perso ou sacs, banque, courrier) et sa valeur ; Maj+clic : lien. Les filtres (perso, Tout / Sacs / Banque / Courrier) et la recherche restent.",
        },
        fixed = {
            "Inventaire : le « ~ » devant les valeurs s'affichait comme un petit accent avec la police du jeu ; remplacé par « env. ».",
        },
    },
    {
        version = "1.13.2", date = "17/11/2026",
        changed = {
            "Fiche du perso, onglet Talents : les icônes des talents prennent toute la place disponible (largeur des arbres et hauteur de la fenêtre), jusqu'à presque deux fois plus grandes, avec des écarts proportionnés.",
        },
    },
    {
        version = "1.13.1", date = "17/11/2026",
        changed = {
            "Fiche du perso, onglet Talents : chaque talent affiche son rang (« 2/5 », « 0/3 ») dans une petite pastille lisible au coin de l'icône, de la couleur du talent (vert pris, doré au maximum, gris pas pris).",
        },
    },
    {
        version = "1.13.0", date = "17/11/2026",
        added = {
            "Fiche du perso, onglet BiS : dernier choix « Ma liste BiS », une liste à remplir toi-même (par exemple pour le niveau 60), un objet par emplacement. Pour en ajouter un : Maj+clic sur l'objet avec le champ actif, glisser-déposer sur la ligne, ou son n°. Chaque objet dit où il tombe (donjon, boss, %) ou « hors donjon », et son état : porté, dans les sacs, à la banque ou à obtenir. Boutons « Remplir avec le meilleur trouvable » (niveau 60, emplacements vides) et « Vider ».",
            "Infobulle d'un objet : « Liste BiS de … » quand il est dans la liste d'un de tes persos.",
        },
    },
    {
        version = "1.12.2", date = "17/11/2026",
        fixed = {
            "Fiche du perso, onglet Talents : WoW Forever utilise le nouveau système de talents du jeu, que l'addon ne lisait pas ; les talents sont maintenant lus dans ce système (configuration active, chaque talent à sa place, rang, points à dépenser). Survol d'un talent : sa description, pour tous tes persos.",
        },
        changed = {
            "/wk talents décrit aussi la configuration de talents du jeu (arbres, nœuds, premier talent).",
        },
    },
    {
        version = "1.12.1", date = "17/11/2026",
        fixed = {
            "Fiche du perso, onglet Talents : les talents du perso connecté restaient « pas encore relevés », le jeu ne les donnant pas encore à l'entrée dans le monde. Ils sont maintenant relevés aussi quand le jeu les annonce, et à l'ouverture de l'onglet.",
        },
        added = {
            "/wk talents : relève les talents et dit ce que le jeu répond, pour trouver la cause s'ils ne s'affichent toujours pas.",
        },
    },
    {
        version = "1.12.0", date = "17/11/2026", restart = true,
        added = {
            "Fiche du perso : trois onglets sous le nom, « Fiche » (la page d'avant), « Talents » et « BiS ».",
            "Talents : les trois arbres côte à côte, chaque talent à sa place avec son icône et son rang (vert : pris, doré : au maximum, grisé : pas pris), les points de chaque arbre, la répartition et les points à dépenser. Survol : le talent (description complète pour le perso connecté). Chaque perso doit se connecter une fois pour relever ses talents.",
            "BiS : pour chaque emplacement, ce que tu portes, le meilleur objet trouvable en donjon (hors raids) que ta classe peut porter, où il tombe (donjon, boss, % de drop) et le gain estimé selon ce qui compte pour ta classe. Choix du niveau visé (actuel, 30, 40, 50, 60), bouton Envie (liste d'envies), clic sur l'objet : guidage vers le donjon.",
        },
        changed = {
            "Fiche du perso : le bouton de retour « Persos » passe à gauche, avant l'icône de classe.",
        },
        fixed = {
            "Fiche du perso : les trois chiffres sous le portrait (armure, durabilité, sacs) s'empilaient les uns sur les autres à la première ouverture.",
        },
    },
    {
        version = "1.11.6", date = "17/11/2026",
        changed = {
            "Micro menu : le nombre de membres de guilde et d'amis en ligne est sur une gélule vert menthe pastel, chiffre vert sombre, centrée sous l'icône et posée au-dessus des icônes voisines.",
            "Micro menu, infobulle des Amis : tous ceux qui jouent à WoW sont en haut de la liste (amis du jeu et amis Battle.net en jeu, avec leur perso et le prénom du compte en bleu) ; ceux qui sont sur une autre appli ou un autre jeu suivent, sous « Battle.net · hors de WoW ».",
        },
        fixed = {
            "Micro menu : la Guilde n'affichait pas son nombre de membres en ligne quand le jeu ne le donnait pas directement ; il est maintenant compté dans la liste de guilde.",
        },
    },
    {
        version = "1.11.2", date = "17/11/2026",
        changed = {
            "QoL > Feu de camp, allégé : la carte « En ce moment » et les lignes « Position » (Placer l'encart, Placer le kit) sont retirées. Tout se place avec le bouton Éditer en haut de la fenêtre, et l'état du camp reste visible sur l'icône de flamme, ses pastilles et l'encart.",
        },
    },
    {
        version = "1.11.1", date = "17/11/2026",
        changed = {
            "QoL > Feu de camp : « Objets de camp par métier » devient une grille de tuiles, une par métier : icône, effet à ton niveau en couleur d'accent (en rouge si un de tes buffs l'annule), le buff avec lequel il ne se cumule pas, puis les trois objets (20, 140, 300). Les paliers déjà atteints par un de tes persos sont en clair, les autres grisés. Les trois feux de Cuisine ont aussi leurs tuiles.",
        },
    },
    {
        version = "1.11.0", date = "17/11/2026", restart = true,
        added = {
            "Kit de camp : une colonne de boutons près de la flamme, avec ton feu (le plus grand kit que tu as), tes objets de camp (meilleur palier en sac), ton sac de couchage, ta nourriture « Bien nourri » et ta boisson. Clic : utiliser l'objet (hors combat) ; un voile décompte la recharge d'1 h ; liseré jaune sur la nourriture quand tu n'es pas « Bien nourri ». Il apparaît près d'un feu (ou toujours) et se place en mode édition.",
            "Pastilles sous l'icône de flamme : avantages du camp restants, recharge des objets de camp, « Bien nourri » (restant ou absent).",
            "Rappels : objet de camp de nouveau disponible, avantages du camp bientôt finis (même loin du camp) et pas de « Bien nourri » au camp alors que tu as de quoi manger. Chacun se coupe dans QoL > Feu de camp, carte « Kit de camp et rappels ».",
            "Infobulle des objets de camp : l'effet pour toi à ton niveau (par exemple « +11 Force pour toi (niveau 26) ») et les paliers suivants, le buff de classe qui l'annule (en rouge si tu l'as déjà), ce qui le remplace à 140 et 300, et la recharge restante. Les kits de feu disent combien d'objets ils acceptent.",
        },
        changed = {
            "Objets de camp : données reprises du jeu (opendata, licence CC BY 4.0, citée dans À propos). Corrigé : le Rouet et le Métier à tisser pour la Couture, le Festin de Cookie et le Four en fer pour la Cuisine, le feu de compagnon à 140 et le feu d'expert à 220. Les noms s'affichent dans la langue du jeu dès qu'il les connaît.",
            "QoL > Feu de camp : le tableau montre les trois objets de chaque métier et leur effet à ton niveau, avec le buff qui l'annule.",
        },
    },
    {
        version = "1.10.3", date = "17/11/2026",
        changed = {
            "QoL > Expérience : la carte « Quêtes terminées à rendre » est retirée. L'XP en attente reste sur la barre (partie jaune et infobulle), et l'alerte « rends tes quêtes, elles te font passer un niveau » reste active.",
        },
    },
    {
        version = "1.10.2", date = "17/11/2026",
        added = {
            "Barre d'expérience : largeur (jusqu'à 1 600 px) et épaisseur réglables dans QoL > Expérience.",
        },
        changed = {
            "QoL > Expérience : la carte « Quêtes terminées à rendre » prend la hauteur de ses quêtes (plus de grand vide), jusqu'à 12 quêtes.",
            "« Tous tes persos » devient un vrai tableau : perso en couleur de classe, niveau, barre et % d'XP, barre et % de repos estimé avec l'étiquette « plein », et quand il a été vu (« il y a 3 j · auberge »).",
        },
    },
    {
        version = "1.10.1", date = "17/11/2026",
        changed = {
            "Liste « À venir » complétée avec les idées pas encore traitées : suite de l'expérience, du feu de camp et des notes de carte, recettes déjà apprises pour les verrous, recherche globale.",
        },
        fixed = {
            "Barre d'expérience : « monstres restants » s'affiche « env. 52 » au lieu d'un « ~ » mal rendu par la police du jeu.",
        },
    },
    {
        version = "1.10.0", date = "17/11/2026", restart = true,
        added = {
            "Barre d'expérience à l'écran : ton XP (couleur d'accent), ton repos (bleu) et l'XP des quêtes terminées à rendre (jaune, un trait montre où tu arriverais en les rendant). Libellés au-dessus (niveau, XP, %, repos, à rendre) ; survol : le détail, le rythme et le temps jusqu'au niveau suivant ; clic : la section Expérience. Version compacte possible, cachée au niveau maximum, se place en mode édition.",
            "QoL > Expérience : la section est prête. Quêtes terminées à rendre (XP de chacune, bouton Guider vers le PNJ, « Guider vers la plus proche »), Repos (niveau, en auberge ou non, temps jusqu'au plein), Rythme de la session (XP par heure, temps jusqu'au niveau, monstres restants, part des monstres, quêtes et découverte, remise à zéro) et Tous tes persos (niveau, XP, repos estimé depuis leur déconnexion).",
            "Alertes : « rends tes quêtes, elles te font passer un niveau » (à l'écran et dans À faire) et « repos plein » pour un perso qui gaspille son temps d'auberge ; chacune se coupe dans la section.",
        },
    },
    {
        version = "1.9.2", date = "17/11/2026",
        added = {
            "Réglages QoL : nouvelle section « Expérience » (barre, repos, quêtes à rendre), en préparation ; elle a son interrupteur dans la carte Modules.",
        },
    },
    {
        version = "1.9.1", date = "17/11/2026",
        changed = {
            "Micro menu : les barres FPS et latence passent sous le cadre de l'heure (sur sa largeur), un peu plus épaisses ; l'heure est de nouveau bien centrée dans son cadre.",
        },
        added = {
            "Micro menu : survol d'une barre = sa valeur (FPS ; latence domicile et monde, en ms) et ce que veut dire sa couleur.",
        },
    },
    {
        version = "1.9.0", date = "17/11/2026",
        added = {
            "Feu de camp : une icône de flamme apparaît quand tu t'approches d'un camp (elle pulse pour attirer l'oeil). Clic : ton perso s'assoit ; un cercle décompte alors la minute, avec les secondes au centre. Une fois les avantages obtenus, elle passe au vert puis s'efface ; relevé trop tôt, elle passe à l'orange.",
            "L'icône s'active ou se coupe dans QoL > Feu de camp (« Icône près d'un feu de camp »), indépendamment de l'encart, et se place en mode édition.",
        },
    },
    {
        version = "1.8.0", date = "17/11/2026",
        added = {
            "Feu de camp : carte « Ce que tes persos peuvent apporter » : pour chaque perso, l'objet de camp que ses métiers permettent de poser (selon la compétence : 20, 140 ou 300 avec un plan), et son effet. Les cuisiniers y voient le feu de camp qu'ils peuvent poser.",
            "Feu de camp : tableau « Objets de camp par métier » (Meule à aiguiser, Bougie d'encens, Magnétite, Bocal à poisson…) avec leur effet et le buff de classe avec lequel ils ne se cumulent pas, et les trois feux de Cuisine (3, 5 ou 10 objets en plus).",
            "Feu de camp : carte « Repos et Sac de couchage douillet » (Tente de campement, bonus d'expérience du sac) avec un bouton pour être guidé au début de la quête du sac (dès le niveau 14, selon ta faction).",
        },
        changed = {
            "Feu de camp : « Comment ça marche » précise qu'on peut aussi s'allonger, s'agenouiller, dormir ou fabriquer à côté, la durée d'un camp (~15 min) et les temps de recharge (5 min pour un feu, 1 h commune pour les objets de métier). Données de la bêta, à confirmer en jeu.",
        },
    },
    {
        version = "1.7.0", date = "17/11/2026", restart = true,
        added = {
            "Réglages QoL : nouvelle section « Feu de camp » (icône de flamme), avec tout ce qui concerne les camps : « En ce moment » en direct (flamme à proximité, compte à rebours assis, avantages actifs, leur effet et leur durée) avec un bouton « S'asseoir », le rappel à l'écran et ses réglages, « Comment ça marche » et la liste des effets de camp déjà rencontrés.",
            "Feu de camp : nouveaux réglages : un son quand l'encart propose de s'asseoir, et la durée d'affichage des avantages obtenus (0 : l'encart reste jusqu'à ce que tu le fermes). Bouton « Placer l'encart » (mode édition).",
            "Carte Modules : « Feu de camp » a son interrupteur dans Réglages QoL.",
        },
        changed = {
            "Les réglages des feux de camp quittent QoL > Général pour leur propre section.",
        },
    },
    {
        version = "1.6.0", date = "17/11/2026", restart = true,
        added = {
            "Feux de camp : près d'un camp (effet de flamme, comme « Flammes pourpres »), un encart propose « Assieds-toi 1 min pour obtenir les avantages du camp (2 h) » avec un bouton « S'asseoir ». Assis, une barre compte la minute de « Feu de camp accueillant ».",
            "Feux de camp : une fois les avantages obtenus, l'encart les montre (par exemple « Bocal à poisson : augmentation de toutes les caractéristiques de 8 % ») avec leur durée, puis s'efface. Relevé trop tôt : le rappel revient. Avantages qui s'épuisent : il propose de les renouveler (seuil réglable).",
            "Réglages dans QoL > Général (carte « Feux de camp ») ; l'encart se place en mode édition. Les effets de flamme sont reconnus à leur nom ou à leur description, et l'addon retient ceux qu'il rencontre.",
        },
    },
    {
        version = "1.5.1", date = "17/11/2026",
        added = {
            "Micro menu, survol de « Amis » : les amis en ligne, une ligne chacun (niveau, point de faction, nom en couleur de classe, zone ; « absent » ou « occupé »), puis tes amis Battle.net avec le prénom du compte. 15 lignes au plus.",
            "Micro menu, survol de « Guilde » : le nom de la guilde et le nombre de connectés, les membres en ligne rangés par rang (niveau, nom en couleur de classe, zone), et le message du jour.",
        },
    },
    {
        version = "1.5.0", date = "17/11/2026", restart = true,
        added = {
            "Objets verrouillés : Alt + clic sur un objet dans les sacs le verrouille (ou le déverrouille) ; un petit cadenas apparaît sur sa case (couleur de l'apparence) et son infobulle le dit. Un objet verrouillé n'est jamais vendu.",
            "Chez le marchand, le clic sur un objet verrouillé ne fait rien (message à l'écran). S'il est vendu quand même (glissé sur le marchand, autre addon), il est racheté aussitôt. La vente automatique des objets gris et l'envoi par courrier (verrou à la main) le respectent.",
            "Verrous automatiques par règles (cadenas turquoise) : objets épiques et plus, liste d'envies, recettes d'un métier de tes persos, objets de quête, valeur HV au-dessus d'un seuil.",
            "Vente chère : avant de vendre un objet non verrouillé qui vaut bien plus à l'HV qu'au marchand, une fenêtre propose Garder, Verrouiller ou Vendre (avec « Ne plus demander pour cet objet »).",
            "Inventaire > Objets verrouillés : tous les verrous du compte (à la main ou par règle, avec les persos qui les ont), déverrouillage, les règles et les réglages (touche, rachat, confirmation et son écart de prix).",
        },
    },
    {
        version = "1.4.2", date = "17/11/2026",
        fixed = {
            "Bandeau de connexion : depuis la 1.4.0, un bandeau vide (logo et croix seulement) restait affiché en haut de l'écran. Il est de nouveau caché jusqu'aux rappels.",
        },
    },
    {
        version = "1.4.1", date = "17/11/2026",
        fixed = {
            "Bandeau de connexion : les icônes sans urgence (enveloppe…) étaient grises et peu visibles ; elles sont à la couleur de l'apparence, un peu plus grandes.",
            "Bandeau de connexion : au survol d'une ligne, le fond recouvrait son icône et son texte ; il passe maintenant dessous.",
        },
    },
    {
        version = "1.4.0", date = "17/11/2026", restart = true,
        changed = {
            "Bandeau de connexion : il se place en mode édition (glisser, taille, opacité) comme les autres éléments à l'écran ; « Tester » le joue comme à la connexion.",
            "Bandeau de connexion : les icônes du jeu laissent place à celles de Warband Keeper, dans des tuiles arrondies à la couleur de l'apparence (rouge ou orange si urgent) : enveloppe pour le courrier, enveloppe et flèche pour les objets à envoyer, coffre-fort pour la banque, sac, horloge, livre, marteau…",
        },
    },
    {
        version = "1.3.8", date = "17/11/2026",
        fixed = {
            "Notes de carte : dans la fenêtre de modification, les boutons Supprimer et Annuler se chevauchaient.",
        },
    },
    {
        version = "1.3.7", date = "17/11/2026",
        changed = {
            "Fiche de personnage : les cartes sont alignées en deux rangées, Équipement et Stats à la même hauteur, puis Réputations et Métiers à la même hauteur.",
        },
        fixed = {
            "Micro menu : le raccourci Héritages ouvrait l'onglet des montures. Il ouvre maintenant le journal des collections sur l'onglet Héritages, quel que soit son numéro sur ce client.",
        },
    },
    {
        version = "1.3.6", date = "17/11/2026",
        fixed = {
            "Carte du monde : les pastilles (lieux, rares, filons, notes, repère du guidage) restaient sous les calques de la carte de WoW Forever, qui montent plus haut que prévu. Elles se placent maintenant au-dessus du plus haut calque du jeu, calculé à chaque ouverture de la carte.",
        },
        changed = {
            "Carte : réparateurs affichés par défaut sur la carte et la minicarte, et maître de ta classe sur la minicarte (réglable dans QoL > Carte).",
        },
    },
    {
        version = "1.3.5", date = "17/11/2026",
        fixed = {
            "Carte du monde : les pastilles (lieux, rares, filons, notes) étaient dessinées puis masquées juste après sur certaines cartes. Tant que la carte est ouverte, Warband Keeper vérifie chaque seconde qu'elles sont bien là et les redessine sinon.",
        },
        changed = {
            "/wk carte : journal des derniers redessins et masquages de la carte (ouverture, changement de carte, guidage, récolte, réparation).",
        },
    },
    {
        version = "1.3.4", date = "17/11/2026",
        changed = {
            "/wk carte : le diagnostic décrit aussi la première pastille de lieu (affichée ou non, transparence, taille, position, texture), pour trouver pourquoi les pastilles restent invisibles sur certaines cartes.",
        },
    },
    {
        version = "1.3.3", date = "17/11/2026",
        fixed = {
            "Carte du monde : les pastilles de Warband Keeper (boîtes aux lettres, maîtres de vol, rares, filons, notes) étaient dessinées puis cachées sous des éléments de la carte de WoW Forever ; seule l'épingle du guidage restait visible. Elles passent maintenant bien au-dessus.",
        },
    },
    {
        version = "1.3.2", date = "17/11/2026",
        changed = {
            "/wk carte : le diagnostic de la carte du monde dit aussi ce qui a été dessiné (carte, taille, module Carte actif, nombre de lieux) et l'état de chaque calque (Lieux, Rares, Notes…), pour trouver pourquoi des pastilles n'apparaissent pas.",
        },
    },
    {
        version = "1.3.1", date = "17/11/2026",
        changed = {
            "Alerte de rare : plus de bouton « Cibler », seulement la flèche de guidage (plus grande, à droite du bandeau ; elle pose aussi la tête de mort). Sans bouton protégé, le bandeau s'affiche et se ferme normalement en combat.",
        },
    },
    {
        version = "1.3.0", date = "17/11/2026",
        added = {
            "Rares : un rare mort apparaît sur la carte pendant 3 h (médaillon rouge, tête de mort, « mort · 12 min » dessous), qu'il ait été tué par toi ou que tu aies vu son cadavre (cible morte tuée par un autre). L'infobulle dit « Tué par toi » ou « Vu mort », et la liste à côté de la carte l'indique aussi. Au-delà, il redevient comme avant (pâle s'il a déjà été tué par ce perso).",
        },
    },
    {
        version = "1.2.2", date = "17/11/2026",
        fixed = {
            "Alerte de rare : erreur « fonction protégée WarbandKeeperRareAlert:Hide() » quand le bandeau se fermait (ou entrait dans le mode édition) en plein combat. Le bandeau porte le bouton Cibler, que le jeu interdit de cacher en combat : il devient transparent et se ferme vraiment à la sortie du combat. Un rare repéré en combat s'affiche dans l'alerte compacte quand le bandeau n'est pas déjà ouvert.",
        },
    },
    {
        version = "1.2.1", date = "17/11/2026",
        changed = {
            "Fiche de personnage : plus d'onglets, tout est sur une seule page qui défile. À gauche l'équipement (poupée, armure, durabilité, sacs) puis les réputations (les 6 plus avancées, « Tout voir » pour toutes avec leurs groupes) ; à droite les stats (caractéristiques, combat, résistances) puis les métiers. Sous le nom : faction et type de serveur.",
        },
    },
    {
        version = "1.2.0", date = "17/11/2026",
        added = {
            "Mode édition de l'interface : bouton « Tester ». Les cadres d'édition s'effacent et chaque élément se joue comme en jeu pendant 10 s : alerte de rare avec son son, récapitulatif de pêche avec sa barre de temps, bandeau de connexion (survol, liste), pile d'alertes, barres… Une barre en bas compte le temps, « Arrêter » revient tout de suite au mode édition.",
        },
    },
    {
        version = "1.1.1", date = "17/11/2026",
        changed = {
            "En-tête : les boutons Éditer et Scan d'abord, puis toutes les icônes ensemble à droite (Patch notes, Profils, Options, recharger, fermer).",
        },
    },
    {
        version = "1.1.0", date = "17/11/2026", restart = true,
        added = {
            "Notes de carte perso : Alt + clic sur la carte du monde pose une note à cet endroit (icône, couleur, titre, texte libre). Elle reste, se voit sur la carte et, au choix, sur la minicarte, et tous tes persos la voient ; rien n'est envoyé à personne.",
            "Notes : survol = titre, texte et coordonnées ; clic = modifier ou supprimer ; Maj + clic = guidage jusqu'à la note. Nom affiché au survol, ou toujours (note par note ou pour toutes).",
            "Réglages QoL > Carte, « Mes notes de carte » : toutes tes notes par zone, recherche, Guider, suppression (Maj + clic), et les réglages (Alt, Ctrl ou Maj + Alt + clic pour poser, taille des pastilles).",
        },
    },
    {
        version = "1.0.1", date = "17/11/2026",
        fixed = {
            "Mode pêche : la canne à pêche ne s'équipait pas. Elle est maintenant prise dans les sacs et équipée directement (comme un glisser vers la main droite) ; si le jeu refuse encore, un message le dit au lieu de rien faire. Une canne posée ailleurs qu'en main droite (emplacement d'outil de métier) compte aussi comme équipée.",
        },
    },
    {
        version = "1.0.0", date = "17/11/2026", restart = true,
        added = {
            "Micro menu : nouveaux raccourcis Guilde (avec le nombre de membres en ligne sur l'icône), Collections du compte et Héritages ; « Amis » affiche le nombre d'amis en ligne (jeu et Battle.net). Ils arrivent dans « Masqués » : glisse-les dans la barre.",
            "Micro menu, réglages : les raccourcis sont tout en haut, et se rangent par glisser-déposer (lâchés à gauche ou à droite de l'heure, ou sur « Masqués » pour les cacher). Les clics marchent toujours.",
            "Pêche : le son du flotteur se règle par niveau (Léger, Fort, Maximum : voix coupées, volume général au maximum, son gardé quand le jeu est en arrière-plan).",
            "Pêche : le récapitulatif de session reste 10 s par défaut avec une barre qui se vide (pause sous la souris), et sa durée se règle (0 : reste ouvert).",
        },
        changed = {
            "Fiche de personnage : elle s'ouvre maintenant dans la fenêtre de Warband Keeper (bouton « Persos » pour revenir), au clic sur un perso dans Persos ou dans le tableau du Résumé, avec ses pastilles en haut.",
            "Persos et Résumé : chaque ligne de perso est cliquable en entier et se colore à la couleur de l'apparence au survol. Sous le nom : la faction et le type de serveur (JcE, JcJ, JdR) au lieu du nom complet du royaume.",
            "En-tête : Patch notes, Profils et Options passent en icônes à gauche d'Éditer (un point signale des notes pas lues) ; le scan du perso devient un bouton « Scan ».",
            "Barre latérale, Réglages QoL : au lieu d'un chiffre, une petite icône par alerte (coffre-fort rouge = banque pleine, sac = sacs pleins, marteau = réparer…), le détail au survol.",
            "Carte Modules : elle reprend toute la barre latérale, groupe par groupe (Persos et Inventaire, Général, Carte, Hôtel des ventes et Classes dans Réglages QoL…) : couper un module retire son entrée de la barre.",
            "Carte : les trajets en vol et en bateau sont de fines lignes continues bordées de sombre, bien visibles sur tous les fonds (la marche reste en pointillés).",
            "Pêche : la carte « Mode pêche » perd sa phrase d'en-tête.",
        },
        fixed = {
            "Donjons, Parcours : les icônes du butin chevauchaient le bouton « Tout le butin ».",
        },
    },
    {
        version = "0.99.0", date = "17/11/2026", restart = true,
        added = {
            "Fiche de personnage : clic sur un perso dans Persos. En haut, sa classe, son niveau et le niveau moyen de son équipement. Onglet Équipement : les emplacements autour de son portrait, cadre à la couleur de qualité, niveau d'objet, point bleu = enchanté, infobulle du jeu (Maj + clic : lien dans le chat), puis armure, durabilité et place dans les sacs, et sa spécialisation (arbre de talents le plus rempli).",
            "Fiche, onglet Stats : les 5 caractéristiques avec une barre en couleur pour celles qui comptent pour sa classe, les stats de combat utiles (puissance d'attaque, critique, toucher, sorts, soins, esquive, parade, blocage) et les résistances. Onglets Métiers et Réputations (avec le rang et la progression).",
            "Ces données sont relevées à chaque connexion du perso et à chaque changement d'équipement : connecte une fois chaque perso avec cette version pour remplir sa fiche.",
        },
    },
    {
        version = "0.98.1", date = "17/11/2026",
        changed = {
            "Rappels à la connexion : la fenêtre devient un bandeau en haut de l'écran. Ton perso, puis une pastille par tâche avec l'icône du jeu qui va avec (lettre cachetée pour le courrier, caisse pour les objets à envoyer, coffre pour la banque, montre pour une recharge prête, livre pour un métier au plafond, enclume pour réparer…) et son chiffre. Les lettres de tous les persos ne font qu'une pastille ; son infobulle détaille.",
            "Rappels : une barre en haut du bandeau se vide jusqu'à la fermeture. Survol : le bandeau se déplie en liste (clic sur une ligne ou une pastille = la page qui va avec) et le temps s'arrête. Flèche pour ouvrir Warband Keeper, croix pour fermer ; il se déplace en le faisant glisser. Aperçu dans Options > Général.",
        },
    },
    {
        version = "0.98.0", date = "17/11/2026", restart = true,
        added = {
            "En-tête : un bouton « Mise à jour x.y.z » apparaît à gauche d'Éditer quand une version plus récente de Warband Keeper existe. Son infobulle dit d'où vient l'info et comment l'installer.",
            "Deux façons de le savoir : le client PC (1.4.2 ou plus) écrit la dernière version publiée dans l'addon à chaque vérification (vu au lancement du jeu ou après un /reload) ; et les joueurs de ta guilde ou de ton groupe qui ont l'addon s'échangent leur numéro de version (jamais en instance ni en combat). Un message dans le chat te prévient la première fois.",
        },
    },
    {
        version = "0.97.1", date = "17/11/2026",
        fixed = {
            "Résumé, carte Modules dépliée : elle débordait sous la fenêtre (les modules de QoL sortaient en bas) et coupait les noms (« Règles d'en… »). Dépliée, elle prend maintenant toute la page le temps de gérer les modules (À faire et la courbe reviennent en repliant), sur 3 colonnes assez larges pour les noms (2 à 4 selon la largeur de la fenêtre).",
        },
    },
    {
        version = "0.97.0", date = "17/11/2026",
        added = {
            "Donjons : nouvel onglet « Parcours », ouvert tout seul quand tu entres dans un donjon. En haut, la carte du prochain boss : son butin en icônes (étoile = tes envies, pâle = déjà sur le compte ; clic = envie, Maj + clic = lien), tes envies sur ce boss, qui d'autre les veut, et les quêtes du donjon à faire. En dessous, la frise de tous les boss dans l'ordre du jeu, rangée par aile (compteur par aile), avec l'heure de chaque kill et le prochain boss surligné.",
            "Parcours : clic sur un boss de la frise pour le voir dans la carte du haut (re-clic : retour au prochain). « Passer » saute un boss pour ce passage (« Reprendre » pour annuler). Rares et boss facultatifs en pointillés, jamais « prochain ». Hors du donjon, la frise sert d'aperçu : coches pâles pour les boss déjà tués par ce perso.",
        },
        changed = {
            "Donjons : les boss sont rangés dans l'ordre du jeu (ordre des rencontres des fichiers du jeu, aile par aile), aussi dans le panneau en jeu.",
        },
    },
    {
        version = "0.96.2", date = "17/11/2026", restart = true,
        changed = {
            "Résumé, carte Modules repliée : bandeau un peu plus haut, icônes plus grandes et plus espacées.",
            "Modules : Distance (chasseur) prend une flèche, et Micro menu une nouvelle icône de menu (elle est aussi dans la page QoL). Il n'y a plus deux icônes identiques.",
        },
        fixed = {
            "Résumé, carte Modules dépliée : un groupe de plus de 4 modules (Aventure) passe à la ligne au lieu de déborder de la fenêtre.",
        },
    },
    {
        version = "0.96.1", date = "17/11/2026",
        fixed = {
            "Loot en groupe : un objet tiré aux dés (ou attribué par le maître du butin) n'est plus compté comme « laissé au sol » quand tu perds le lancer. Le filtre ne touche plus à ces objets : le jeu les donne au gagnant. En maître du butin, la fenêtre reste ouverte tant qu'il reste des objets à attribuer.",
        },
    },
    {
        version = "0.96.0", date = "17/11/2026",
        changed = {
            "Donjons : les vrais noms français, tirés des tables du jeu, pour tout le nouveau contenu : La salle des Thanes, Excavations : les Paluns, La cité Submergée, Bastion Krol'dok, Prison d'Alcaz, Repaire des Noiregueules, La terrasse du Façonneur.",
            "Donjons : 265 boss sur 297 ont maintenant leur nom français officiel (Faldrim Courbenclume, Capitaine Lèveffroi, Flétrigueule…), contre 215 avant.",
            "Donjons : les cinq donjons pas encore ouverts sont reconnus dès l'entrée (leur n° d'instance vient du jeu), et 214 boss sont repérés par la fin de rencontre (177 avant).",
            "Ces données suivent chaque nouvelle version du jeu : elles sont relues chaque jour avec le reste.",
        },
    },
    {
        version = "0.95.2", date = "17/11/2026",
        changed = {
            "Carte du monde : patrouilles des rares bien plus visibles (points plus gros et serrés, contour noir comme le trajet du guidage). Au survol, la patrouille et les autres points d'apparition passent par-dessus les médaillons : une patrouille courte n'est plus cachée sous l'étoile.",
            "Infobulle d'un rare : dit s'il patrouille (pointillés sur la carte), s'il ne bouge que de quelques mètres, ou s'il reste toujours à son point d'apparition (c'est le cas de la plupart : 237 rares sur 327).",
        },
    },
    {
        version = "0.95.1", date = "17/11/2026",
        fixed = {
            "Carte du monde : le médaillon d'un rare disparaissait (ou clignotait) dès qu'on passait la souris dessus. Il reste affiché, avec son infobulle et sa patrouille.",
        },
    },
    {
        version = "0.95.0", date = "17/11/2026",
        changed = {
            "Barre latérale réorganisée : Résumé tout en haut, à part (jamais replié), puis six groupes avec une petite icône de ta couleur : Bataillon (Persos, Inventaire), Trésorerie (Stats, Règles d'envoi), Artisanat (Métiers, Pêche), Butin (Session de farm, Filtre de loot, Journal), Aventure (Quêtes, Rares, Donjons, LFG) et Réglages QoL.",
            "La carte « Modules » du Résumé suit les mêmes groupes. Les groupes que tu avais repliés sont à replier de nouveau (ils ont changé de nom).",
        },
    },
    {
        version = "0.94.1", date = "17/11/2026",
        changed = {
            "Barre latérale : le groupe « Confort » devient « QoL », et ses entrées sont directement les sections de QoL (Général, Halo, Micro menu, Pêche, Carte, Hôtel des ventes, Curseur, Classes), sans étage intermédiaire. Le groupe se replie comme les autres, avec le total de ses alertes ; en menu réduit, les sections restent là en icônes.",
        },
    },
    {
        version = "0.94.0", date = "17/11/2026",
        added = {
            "Barre latérale : clic sur un titre de groupe (COMPTE, ÉCONOMIE, FARM…) pour le replier ou le déplier, comme un casier. Replié, il affiche le total des pastilles de ses pages pour ne rien rater. Le choix est retenu ; la page affichée reste toujours visible, même dans un groupe replié.",
            "QoL : ses sections (Général, Halo, Micro menu, Pêche, Carte, Hôtel des ventes, Curseur, Classes) sont maintenant dans la barre latérale, sous « QoL » : un clic sur QoL les déplie (un autre clic les replie), avec leurs pastilles d'alertes. La page QoL prend toute la largeur.",
        },
    },
    {
        version = "0.93.0", date = "17/11/2026",
        added = {
            "Métiers : Maj + clic sur une tuile de métier met le lien du métier dans le chat (le même que le bouton « Link tchat », avec ton texte s'il est activé).",
            "Métiers : Maj + clic sur une recette (liste des recettes, détail d'un métier, liste de courses) met son lien dans le chat : l'objet fabriqué, comme dans la fenêtre de métier du jeu, ou la recette elle-même pour un enchantement. L'infobulle le rappelle.",
            "Pour les enchantements, rouvre une fois la fenêtre du métier avec chaque perso : l'addon y note ce qu'il faut pour le lien.",
        },
    },
    {
        version = "0.92.2", date = "17/11/2026",
        changed = {
            "Tous les boutons sont à la couleur de ton apparence, même sans la souris dessus : boutons discrets (Panneau en jeu, Guider vers l'entrée…), boutons à icône (actualiser, fermer…), onglets et choix pas sélectionnés. Seuls les boutons de suppression restent gris, puis rouges au survol.",
        },
    },
    {
        version = "0.92.1", date = "17/11/2026",
        changed = {
            "Donjons : le détail d'un donjon a deux onglets, « Butin » (avec le nombre d'objets) et « Quêtes » (avec le nombre de quêtes à faire, en orange tant qu'il en reste). L'onglet Quêtes a son filtre « À faire / Toutes » et un bouton de guidage vers le donneur sur chaque quête pas encore faite.",
            "Donjons : en « Pour ce perso », l'étiquette « pour toi » n'apparaît plus sur chaque objet (tout y est pour toi) ; elle reste en « Tout » pour repérer ce que le perso peut porter. Pareil dans le panneau en jeu.",
        },
    },
    {
        version = "0.92.0", date = "17/11/2026", restart = true,
        added = {
            "Butin observé : dans l'infobulle d'un objet, les monstres qui le lâchent et à quelle fréquence, d'après les butins relevés par les joueurs de WoW Forever (Everloot : 688 objets pour l'instant, et ça grossit chaque jour). Réglable dans Options > Infobulles.",
            "Donjons : quand wowtbc.gg ne donne pas de taux de drop, le taux observé par les joueurs s'affiche, avec le nombre de butins relevés (72 objets de boss pour l'instant).",
            "Vols : les vrais trajets des griffons (fichiers du jeu, 138 trajets) sont dessinés même pour un vol jamais fait, y compris avec des relais. La durée estimée d'un vol pas encore fait suit ce vrai trajet : bien plus juste.",
            "Ces données sont mises à jour chaque jour avec le reste.",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.91.0", date = "17/11/2026",
        added = {
            "Donjons : les boss tués sont aussi repérés par la fin de rencontre que signale le jeu (177 boss), même sans les avoir en cible ni fouiller leur corps. Et sur un client français, le jeu donne le vrai nom français du boss : il est retenu et affiché (utile pour le nouveau contenu, que QuestieDB ne traduit pas encore).",
        },
        changed = {
            "Options > À propos : source des numéros de rencontre (catalogue d'Everloot, tiré des fichiers du jeu).",
        },
    },
    {
        version = "0.90.3", date = "17/11/2026",
        changed = {
            "Données (quêtes, rares, lieux, donjons, guides…) : vérifiées chaque jour au lieu de chaque lundi, le temps que le jeu se stabilise. Fréquence et publication automatique réglables depuis le client PC (Réglages > Données).",
            "Notes de version : celles de l'addon et celles du client PC sont désormais séparées (le client a les siennes).",
        },
    },
    {
        version = "0.90.2", date = "17/11/2026",
        added = {
            "Chaque version dit maintenant s'il faut redémarrer complètement le jeu ou si un /reload suffit : pastille dans les notes de version en jeu, et ligne en tête des notes sur GitHub.",
        },
    },
    {
        version = "0.90.1", date = "17/11/2026",
        changed = {
            "Pas de changement dans l'addon (client PC 1.1 : voir ses notes).",
        },
    },
    {
        version = "0.90.0", date = "17/11/2026",
        added = {
            "Chaque nouvelle version est désormais publiée automatiquement sur GitHub (page Releases), avec ses notes. Un client PC (Windows) l'installe et la met à jour : il a ses propres notes de version.",
        },
    },
    {
        version = "0.89.1", date = "17/11/2026",
        changed = {
            "Guides de montée des métiers mis à jour depuis wowtbc.gg (paliers et étapes revus par le site, par exemple Alchimie : Compagnon jusqu'à 130).",
            "Données mises à jour d'un coup (lieux, chemins, rares, quêtes, donjons, guides, recettes) : désormais vérifiées chaque semaine, et proposées à la publication quand QuestieDB ou wowtbc.gg ont du nouveau.",
        },
        fixed = {
            "Donjons : les objets pas encore découverts sur WoW Forever (surtout le butin des raids) manquaient dans les listes ; ils y sont, marqués « non découvert ».",
        },
    },
    {
        version = "0.89.0", date = "17/11/2026",
        added = {
            "Donjons : nouvelles tables de butin, celles de WoW Forever (wowtbc.gg) au lieu des tables de Classic. 31 donjons et raids au lieu de 19, avec les nouveaux : Hall of Thanes, Ruines de Lordaeron, Cité de Dalaran, Excavation Site, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace, et les raids Repaire d'Onyxia, Barrow Deeps et Hyjal Summit.",
            "Butin de chaque boss avec les objets propres à WoW Forever, et en fin de liste le butin des monstres du donjon. Infobulle : chance de drop quand elle est connue ; « non découvert » pour un objet pas encore vu tomber sur le serveur.",
            "Monastère Écarlate, Hache-Tripes et Pic Rochenoire : toutes les ailes dans une seule tuile, chaque boss avec le nom de son aile (Cimetière, Bibliothèque… ; Est, Nord, Ouest ; Bas, Haut).",
            "Boss du nouveau contenu : Warband Keeper les reconnaît en jeu la première fois (par leur butin sur le corps, ou par leur nom sur un client anglais), puis note leur mort comme les autres. Même chose pour un nouveau donjon : reconnu à la première visite, et son nom français repris du jeu.",
        },
        changed = {
            "Options > À propos : wowtbc.gg cité pour les tables de butin et les guides de métiers.",
        },
    },
    {
        version = "0.88.2", date = "16/11/2026",
        fixed = {
            "Au démarrage (et en entrant ou sortant d'un donjon), le jeu bloquait une action de Warband Keeper (« fonction protégée UnregisterEvent ») : le module Donjons lisait le journal de combat, désormais réservé au jeu. Les boss tués sont maintenant repérés autrement : mort de ta cible, du focus, d'un boss ou d'une plaque de nom, et butin ramassé sur son corps.",
        },
    },
    {
        version = "0.88.1", date = "16/11/2026",
        fixed = {
            "Marchand : une erreur Lua à l'ouverture de n'importe quel marchand (panneau « Pour monter tes métiers »). Le même souci empêchait le rachat automatique des composants de classe et des munitions : corrigé aussi.",
        },
    },
    {
        version = "0.88.0", date = "16/11/2026", restart = true,
        added = {
            "Voyages : la durée du vol s'affiche dans l'infobulle de chaque destination, sur la carte du maître de vol. Durée exacte si tu as déjà fait ce vol, sinon une estimation (« environ… (estimée) »).",
            "Voyages : rappel des points de vol à apprendre. En arrivant dans une zone dont le maître de vol n'est pas encore appris (ta faction), un message le dit, une fois par zone et par session. /wk vol guide vers le plus proche. Nouvelle carte « Points de vol à apprendre » dans QoL > Carte : ceux du continent, du plus proche au plus loin, avec un bouton Guider, et le rappel à couper. Il faut avoir ouvert une fois la carte d'un maître de vol avec le perso pour que ses vols connus soient notés.",
            "Nouvelle section « Curseur » dans QoL : anneau de ta couleur autour de la souris (taille, opacité, en combat seulement ou toujours). Il se remplit pendant le temps de recharge global et tes incantations, passe au rouge quand ta cible est hors de portée, s'estompe quand la souris ne bouge pas et se cache quand tu tournes la caméra.",
            "Curseur : « Garder le curseur dans la fenêtre en combat » : le curseur ne sort plus de la fenêtre du jeu pendant un combat (pratique avec deux écrans) ; ton réglage revient à la sortie du combat. Coupé par défaut.",
            "Feuille de route : horaires des bateaux et zeppelins, partage des horaires, réticule au centre de l'écran, et retrouver le curseur.",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.87.1", date = "16/11/2026",
        added = {
            "Donjons : section « Quêtes du donjon » sous les boss, pour le perso choisi. Chaque quête avec son niveau et son état : disponible, dans le journal, niveau requis, faite, ou « après : <quête> » quand une quête doit être faite avant (prérequis). Les quêtes à faire passent en premier. L'icône de guidage mène au donneur, ou, s'il y a un prérequis, au donneur de la quête à faire avant.",
            "Feuille de route mise à jour : bénédictions du paladin, et deux améliorations de la navigation (bateau sur le même continent, repère du jeu sur la minicarte).",
        },
    },
    {
        version = "0.87.0", date = "16/11/2026", restart = true,
        added = {
            "Donjons : nouvelle page « Donjons » (groupe Exploration). Les 19 donjons de WoW Forever en tuiles par niveau (couleur selon le niveau du perso choisi, barre des boss déjà tués), puis les boss du donjon choisi et leur butin propre (armes, armures, recettes), en couleur de qualité. « Pour ce perso » ne garde que ce qu'il peut porter (classe, type d'armure selon le niveau, armes, recettes de ses métiers) ; étiquettes « pour toi » et « sur le compte ».",
            "Liste d'envies : une étoile sur chaque objet ; onglet « Mes envies » (par perso, avec le donjon et le boss). En entrant dans un donjon qui contient tes envies, un rappel le dit ; quand un objet voulu tombe dans le groupe, une alerte et un son.",
            "En donjon : panneau à droite de la carte du monde, avec les boss dans l'ordre (ceux tués pendant ce passage marqués « tué »), le butin du boss suivant déplié, filtres Pour moi / Tout / Envies. Aussi seul avec /wk donjon, ou « Panneau en jeu » dans la page.",
            "Dans la page : nombre de quêtes de donjon de la zone de l'entrée, « Chercher un groupe » (onglet LFG) et « Guider vers l'entrée ». Les boss tués sont notés par perso.",
            "Données des donjons tirées de QuestieDB (boss et butin) ; la rareté vient du jeu, les taux de drop ne sont pas connus.",
            "Nouveaux fichiers : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.86.3", date = "16/11/2026",
        changed = {
            "Carte du monde, liste des rares : bien plus compacte (une ligne par rare : étoile, nom, niveau ; le butin est dans l'infobulle). Clic sur l'en-tête : la replier ou la déplier ; glisser l'en-tête : la déplacer (position gardée) ; clic droit : la remettre en place ; croix : ne plus l'afficher (réactivable dans Rares > Carte et infobulle).",
        },
        added = {
            "Rares > Carte et infobulle : « Patrouilles des rares sur la carte » affiche en permanence le trajet de chaque rare qui se déplace, en pointillés de sa couleur (sinon seulement au survol de son médaillon). Coupé par défaut.",
        },
    },
    {
        version = "0.86.2", date = "16/11/2026",
        fixed = {
            "Options > Général : la carte « Bouton minimap » chevauchait la carte « Infobulles ».",
        },
    },
    {
        version = "0.86.1", date = "16/11/2026",
        fixed = {
            "Carte du monde : les médaillons des rares (et les autres pastilles de l'addon) pouvaient ne plus s'afficher depuis la 0.79.1. Le masquage du losange du jeu plantait dès qu'un point était suivi, et arrêtait tout le dessin de la carte.",
            "Carte du monde : chaque calque (lieux, filons, rares, bateaux, trajet, repère) est maintenant dessiné à part. Une erreur dans l'un n'empêche plus les autres de s'afficher, et elle est signalée une fois dans le chat. /wk carte donne le détail et le nombre de rares sur la carte ouverte.",
        },
    },
    {
        version = "0.86.0", date = "16/11/2026", restart = true,
        added = {
            "HUD de récolte : la minicarte du jeu s'affiche en grand et transparente au centre de l'écran, dézoomée au maximum et tournée avec ton perso. Les points jaunes du pistage (filons, plantes) se voient ainsi de bien plus loin, avec nos pastilles et le trajet. Les clics passent au travers. /wk hud, ou une touche dans les raccourcis du jeu (Warband Keeper > HUD de récolte). Taille, opacité et « fermer en combat » dans Options > Récolte. La minicarte retrouve sa place, sa taille et son zoom à la fermeture.",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
        changed = {
            "Filons et plantes sur la minicarte et la carte du monde : ce sont maintenant les nœuds que tes persos ont réellement récoltés (tout le compte), au lieu des points de QuestieDB, qui ne correspondaient pas aux nœuds de WoW Forever. La carte se remplit à mesure que tu récoltes.",
        },
    },
    {
        version = "0.85.0", date = "16/11/2026", restart = true,
        changed = {
            "Collection de pêche : elle a sa propre page « Pêche » dans le groupe Farm de la barre latérale (album et atlas en pleine largeur), avec en en-tête les espèces trouvées, le nombre de prises et leur valeur. Elle quitte QoL > Pêche, qui garde le mode pêche, le carnet et les réglages.",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.84.1", date = "16/11/2026",
        changed = {
            "Halo : la carte « Forme par filon et par plante » est retirée ; chaque filon et chaque plante reprend la forme de sa catégorie (atelier).",
        },
    },
    {
        version = "0.84.0", date = "16/11/2026", restart = true,
        added = {
            "Marchand : panneau « Pour monter tes métiers » collé à la fenêtre du marchand. Pour chaque métier du perso qui a un guide, les composants qui manquent jusqu'au palier choisi (75, 150, 225, 300 ou Max, le même que dans Métiers > guide, modifiable directement dans le panneau) et que ce marchand vend : quantité qui manque, prix, bouton « Acheter » et « Tout acheter ». Les recettes à apprendre vendues ici y sont aussi. Le nombre de composants à trouver ailleurs est indiqué en bas.",
            "Le panneau n'apparaît que chez un marchand qui vend quelque chose d'utile. Réglage dans QoL > Général > Marchand.",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.83.2", date = "16/11/2026",
        changed = {
            "Halo : le halo prend toujours la couleur choisie dans l'atelier, y compris pour les filons, les plantes et les créatures à dépecer. La difficulté (orange, jaune, vert, gris, rouge) ne colore plus que le texte sous l'objet ; le réglage s'appelle désormais « Texte selon la difficulté ». La rangée Couleur n'est plus grisée.",
        },
    },
    {
        version = "0.83.1", date = "16/11/2026",
        fixed = {
            "Halo, atelier : pour les filons, les plantes et le dépeçage, la couleur choisie ne correspondait pas à l'aperçu quand « Couleur selon la difficulté » est active (c'est la difficulté qui colore). La rangée Couleur est maintenant grisée et indique « remplacée par la difficulté » ; la couleur choisie reprend dès que tu coupes ce réglage.",
        },
    },
    {
        version = "0.83.0", date = "16/11/2026",
        added = {
            "Halo : nouvelle carte « Forme par filon et par plante » sous l'atelier (QoL > Halo). Chaque filon (cuivre, étain, argent, fer, or, mithril, vrai-argent, sombrefer, thorium…) et chaque plante peut avoir sa propre forme parmi les six existantes (halo, colonne, halo et colonne, onde, étincelles, viseur). « Catégorie » garde la forme choisie dans l'atelier ; « Tout comme la catégorie » remet la liste à zéro.",
        },
    },
    {
        version = "0.82.1", date = "16/11/2026",
        changed = {
            "Fenêtre de rappels à la connexion : elle se ferme seule au bout de 5 secondes (fondu à la fin), sauf tant que la souris est dessus. Durée réglable dans Options > Général > Rappels à la connexion, de 0 (reste ouverte) à 60 s.",
        },
    },
    {
        version = "0.82.0", date = "16/11/2026", restart = true,
        added = {
            "Vols : le chemin réellement suivi par le griffon est noté à chaque vol. En vol, la carte du monde et la minicarte montrent ce chemin depuis ta position jusqu'à l'arrivée (au premier vol sur un trajet : le chemin déjà parcouru), puis la suite du trajet guidé. Les trajets planifiés dessinent aussi ce vrai chemin de vol au lieu d'une ligne droite.",
            "Bateaux appris : quand un bateau ou un zeppelin te porte (tu avances sans bouger), le départ et l'arrivée deviennent deux quais connus, avec le chemin suivi. Ils apparaissent sur la carte comme les autres trajets (« vers Hurlevent »…), leur tracé est dessiné, et la navigation s'en sert (même continent compris). Un message le signale la première fois.",
            "Nouvelle texture : redémarrer le jeu (un /reload ne suffit pas).",
        },
        changed = {
            "Barre de filtres de la carte : la poignée pour la déplacer devient une croix à quatre flèches, qui prend ta couleur au survol.",
            "« Oublier les chemins appris » oublie aussi les bateaux appris.",
        },
    },
    {
        version = "0.81.0", date = "16/11/2026", restart = true,
        added = {
            "Hôtel des ventes, onglet « Ventes » du panneau : tes enchères en cours (prix à l'unité, quantité). « Vérifier les prix » cherche le plus bas prix actuel de chaque objet (un toutes les 1,2 s) et marque chaque enchère : au plus bas, seul en vente, ou sous-cotée avec le prix du concurrent. Une enchère sous-cotée a un bouton « Annuler » (l'objet revient par courrier, le dépôt est perdu).",
            "Vente rapide : quand tu poses un objet dans la fenêtre de vente du jeu, son prix est rempli au plus bas des autres vendeurs moins 1 pc (sinon au prix du scan moins 1 pc). Réglable dans QoL > Hôtel des ventes (marche ou arrêt, marge de 1 à 100 pc).",
            "Alertes de prix : /wk alerte [objet] 75pa (Maj+clic sur l'objet, prix max à l'unité en po, pa ou pc). Après chaque scan, les objets en vente à ce prix ou moins sont signalés dans le chat, à l'écran et dans l'onglet Scan du panneau, avec « Chercher ». Liste et suppression dans QoL > Hôtel des ventes ; /wk alerte seul les liste.",
            "Prix exacts (po, pa, pc) dans le panneau, les alertes et les messages de vente.",
            "/wk hv dit aussi ce que ce client permet côté vente (mes enchères, recherche, annuler, vente rapide).",
            "Nouveau fichier : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.80.3", date = "16/11/2026",
        changed = {
            "Guidage : la flèche de guidage est coupée (une fois, pour tout le monde) : l'épingle à l'écran, qui se cale au bord quand le lieu est hors champ, et le trajet en pointillés la remplacent. Elle reste disponible dans QoL > Général > Guidage (« Flèche à l'écran ») et vise alors le point suivant du trajet.",
            "Mode édition : un élément coupé dans ses réglages (comme la flèche) n'y apparaît plus.",
        },
    },
    {
        version = "0.80.2", date = "16/11/2026",
        changed = {
            "Trajet en pointillés : points plus gros et plus espacés, chacun avec un contour sombre, pour rester lisibles sur tous les fonds de la carte du monde et de la minicarte.",
        },
    },
    {
        version = "0.80.1", date = "16/11/2026",
        changed = {
            "Épingle à l'écran : étiquette plus compacte, sur trois lignes centrées (nom, rôle, distance de ta couleur) au lieu d'une longue ligne.",
        },
        fixed = {
            "Épingle à l'écran : quand le lieu était derrière toi ou hors champ, elle disparaissait (et ne revenait qu'au guidage suivant). Elle se cale maintenant au bord de l'écran, dans la direction du lieu, avec une petite flèche et la distance.",
        },
    },
    {
        version = "0.80.0", date = "16/11/2026", restart = true,
        added = {
            "Alerte « Rare en vue » : le bouton Guider devient l'icône ronde de guidage (comme dans les listes Rares et Quêtes). Un clic guide vers le rare et pose le marqueur tête de mort du jeu au-dessus de lui (aussi en cliquant sur l'alerte compacte).",
            "Rare guidé : l'épingle à l'écran et sur la carte du monde montre une tête de mort.",
            "Rares > Carte et infobulle : réglage « Tête de mort sur le rare guidé » (activé par défaut ; en raid, il faut être chef ou assistant pour marquer).",
            "Nouvelle texture : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.79.1", date = "16/11/2026",
        changed = {
            "Carte du monde : le lieu guidé est marqué par une épingle de ta couleur avec l'icône de ce que tu suis, et dessous le nom et la distance restante (mise à jour chaque seconde), comme l'épingle à l'écran. Le losange jaune du jeu est masqué sur la carte pendant le guidage. Clic droit sur l'épingle : arrêter.",
        },
    },
    {
        version = "0.79.0", date = "16/11/2026", restart = true,
        added = {
            "Guidage : épingle à l'écran au-dessus du lieu guidé, de ta couleur, avec l'icône de ce que tu suis (boîte aux lettres, banque, réparation, quête, rare, pêche…) et dessous le nom et la distance restante par le trajet. Quand le lieu est hors champ, elle se cale au bord de l'écran, plus discrète. Elle remplace le repère d'origine du jeu.",
            "Arrivée : à moins de 10 m, un bandeau « Arrivé : … · le guidage s'arrête » s'affiche (avec un son si tu veux) et le guidage s'arrête.",
            "QoL > Général > Guidage : réglages « Épingle à l'écran » et « Son à l'arrivée ».",
            "Nouveaux fichiers (code et texture) : redémarrer le jeu (un /reload ne suffit pas).",
        },
        fixed = {
            "Métiers : une lecture vide des compétences (données du jeu pas encore prêtes) ne peut plus effacer les métiers connus du perso.",
        },
    },
    {
        version = "0.78.2", date = "16/11/2026",
        fixed = {
            "Récapitulatif de pêche : les points de compétence gagnés pouvaient manquer (« +0 ») si le jeu n'avait pas encore mis à jour la compétence. Elle est maintenant relue à chaque message « Votre compétence en Pêche augmente » et à la fermeture du mode pêche.",
        },
    },
    {
        version = "0.78.1", date = "16/11/2026",
        fixed = {
            "Micro menu : l'heure paraissait décalée vers la droite quand elle commence par un 1 (le chiffre 1 laisse un vide à sa gauche). Elle est maintenant centrée sur ses chiffres, et les barres FPS et latence vont du premier au dernier chiffre.",
        },
    },
    {
        version = "0.78.0", date = "16/11/2026", restart = true,
        added = {
            "Navigation Warband Keeper : chaque guidage (quêtes, rares, lieux, métiers, alertes, pêche) trace un trajet en pointillés de ta couleur, de toi jusqu'au lieu, sur la carte du monde et sur la minicarte. La flèche vise le point suivant du trajet et donne la distance restante par le chemin.",
            "Le trajet suit les chemins connus : chemins de base tirés des patrouilles des PNJ (QuestieDB : routes, ponts, cols) et chemins appris. Hors des chemins, il coupe tout droit (terrain inconnu).",
            "Apprentissage : les chemins que tes persos parcourent à pied ou à monture (hors vol, instances et fantôme) sont notés, seulement là où rien n'était connu. Les trajets s'affinent au fil de tes déplacements, sur tout le compte.",
            "Vols : un maître de vol que ton perso connaît (noté à l'ouverture de la carte des vols) entre dans le trajet s'il fait gagner du temps (marche, vol, marche). Autre continent : le trajet mène au bateau ou au zeppelin qui y va, puis repart à l'arrivée.",
            "Si tu t'écartes du trajet plus de 4 secondes, il est recalculé depuis ta position.",
            "QoL > Carte : carte « Navigation » (trajet sur la carte du monde, sur la minicarte, apprentissage, kilomètres appris, bouton pour oublier les chemins appris). /wk nav donne aussi l'état de la navigation.",
            "Options > Infobulles : « Police fine pour les infobulles du jeu » (objets, PNJ, sorts), activée par défaut.",
            "Nouveaux fichiers : redémarrer le jeu (un /reload ne suffit pas).",
        },
        changed = {
            "« Warband Keeper » dans les infobulles (objets, quêtes, rares) et dans le chat prend la couleur d'accent de l'apparence au lieu du bleu.",
            "Le relais vers ShortestPathForever est retiré (avec son réglage) : le guidage ne dépend plus d'aucun autre addon.",
        },
    },
    {
        version = "0.77.0", date = "16/11/2026", restart = true,
        added = {
            "QoL > Pêche : nouvelle carte « Collection » sous le carnet, avec deux onglets.",
            "Album : une tuile par espèce (poissons, coffres, curiosités), rangée par palier de compétence ; en couleur si un de tes persos l'a déjà pêchée (avec le nombre), en gris sinon. Filtres Tout, Poissons, Coffres, Curiosités, Manquants. Un point de ta couleur marque les espèces pêchées pour la première fois cette semaine.",
            "Fiche de l'espèce (clic sur une tuile) : prises du compte, prix HV, zones où elle a mordu (en %) puis zones conseillées, première prise (perso et date), bouton « Meilleur coin » pour y être guidé et bouton « Lien ».",
            "Par zone : l'atlas des eaux, une ligne par zone avec la compétence conseillée (verte, jaune ou rouge selon ta compétence), ses espèces (en gris si pas encore pêchées ici), ta progression et ton rythme, et un bouton pour être guidé vers ton dernier coin de pêche de la zone.",
            "La liste de référence des espèces et des zones est indicative : toute prise imprévue rejoint la collection et l'atlas d'elle-même. Le dernier coin de pêche de chaque zone est noté à partir de maintenant.",
            "Nouveaux fichiers : redémarrer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.76.2", date = "16/11/2026",
        changed = {
            "/wk nav : pendant un trajet confié à ShortestPathForever, le diagnostic dit que le repère, la flèche et le tracé sont gérés par lui, au lieu d'afficher « aucun » et une distance à 0.",
        },
    },
    {
        version = "0.76.1", date = "16/11/2026",
        changed = {
            "Guidage vers le plus proche (réparation, marchand, boîte aux lettres, banque, maître de classe, munitions, composants, alertes de sacs pleins) : avec ShortestPathForever, le lieu choisi est celui qu'on atteint le plus vite en vrai, parmi les 6 plus proches à vol d'oiseau (une rivière ou une falaise ne piègent plus le choix), et le trajet passe par lui.",
            "Les messages du guidage donnent alors le temps de trajet (« à 3 min de trajet ») au lieu de la distance à vol d'oiseau.",
        },
    },
    {
        version = "0.76.0", date = "16/11/2026",
        added = {
            "Guidage : si l'addon ShortestPathForever est installé, « Guider » (quêtes, rares, lieux de la carte, métiers, alertes) lui confie le trajet. Le chemin en pointillé suit le terrain (routes, murs, ponts) et enchaîne marche, vols et bateaux, avec sa propre flèche (celle de Warband Keeper se cache alors).",
            "QoL > Carte : carte « Trajet du guidage » pour activer ou couper ce relais (activé par défaut), avec l'état de ShortestPathForever (installé ou non). Sans lui, le guidage reste celui de Warband Keeper.",
            "/wk nav dit aussi si ShortestPathForever est installé, utilisé, et si un trajet est en cours.",
        },
    },
    {
        version = "0.75.4", date = "16/11/2026",
        fixed = {
            "Rappels de buffs (paladin, prêtre, druide) : une erreur « Auras cannot be accessed when secret » pouvait apparaître quand le jeu masque les auras. Une aura illisible est maintenant ignorée, sans erreur ni rappel à tort.",
        },
    },
    {
        version = "0.75.3", date = "16/11/2026",
        changed = {
            "Infobulles de l'addon : texte plus fin, dans la police de l'interface choisie dans Options > Apparence, sans contour (13 pour le titre, 12 pour le reste). Les infobulles du jeu (objets, PNJ) ne changent pas.",
        },
    },
    {
        version = "0.75.2", date = "16/11/2026",
        changed = {
            "Rares et Quêtes : le bouton « Guider » des listes devient une icône, la flèche de guidage dans un petit rond de ta couleur de classe, qui se remplit au survol (infobulle : où elle te guide). Les lignes gagnent de la place pour le nom.",
        },
    },
    {
        version = "0.75.1", date = "16/11/2026",
        changed = {
            "Boutons : tous les boutons de l'addon prennent la couleur d'accent (la couleur de classe en Graphite). Les boutons secondaires (« Link tchat », « Niveaux », « Envoyer à ce perso »…) ont un fond teinté et un texte de cette couleur ; les boutons discrets et les boutons-icônes s'y colorent au survol ; les boutons principaux restent pleins.",
        },
    },
    {
        version = "0.75.0", date = "16/11/2026",
        changed = {
            "Résumé : « À faire » prend la moitié gauche (la courbe de l'or la moitié droite) et se range en trois groupes, Urgent (rouge), Bientôt (orange) et À noter, avec un compteur en pastille à côté du titre.",
            "Résumé : chaque tâche est écrite plus grand, sur deux lignes (l'action, puis le détail comme « expire dans 2 j »), avec son icône dans une case de couleur ; au survol, un bouton « Ouvrir » y mène.",
        },
        fixed = {
            "Barre latérale : la dernière entrée (QoL) était coupée un peu trop tôt au-dessus de Patch notes.",
        },
    },
    {
        version = "0.74.1", date = "16/11/2026",
        added = {
            "Stats : chaque objet suivi a une corbeille, y compris ceux ajoutés automatiquement par une règle d'envoi. Retirer un objet des statistiques ne touche pas à sa règle d'envoi ; le rajouter à la main le fait revenir.",
        },
        changed = {
            "Barre latérale : « Loot » s'appelle maintenant « Filtre de loot » et « Courrier » « Règles d'envoi » (aussi dans la carte Modules).",
            "Barre latérale : quand la fenêtre est basse, la liste des pages s'arrête au-dessus de Patch notes, Profils et Options et défile à la molette, au lieu de passer par-dessus.",
        },
        fixed = {
            "Stats : les catégories de règles d'envoi (Cuirs, Métaux…) ne se glissent plus dans la liste des objets suivis.",
            "Barre latérale : le titre d'un groupe dont tous les modules sont coupés réapparaissait en repliant ou dépliant la barre.",
        },
    },
    {
        version = "0.74.0", date = "16/11/2026",
        added = {
            "Pêche : chaque prise est notée toute seule (objets, zone, heure, perso), même hors du mode pêche.",
            "Pêche : compteur de session dans la barre du mode pêche (prises, rythme par heure, valeur).",
            "Pêche : récapitulatif à la fermeture du mode pêche : zone et durée, prises, rythme, valeur, prises au fil de la session, ce qui a le plus mordu, nouvelles espèces et points de compétence gagnés. Il disparaît seul (clic pour le fermer) et se place en mode édition.",
            "Pêche : carnet dans QoL > Pêche : prises, temps de pêche, rythme, valeur et espèces du compte ; les zones par nombre de prises avec ce qu'elles donnent le plus et le rythme ; les dernières prises avec « nouveau » pour une première prise sur le compte.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.73.5", date = "16/11/2026",
        changed = {
            "Résumé : icônes de la carte Modules repliée plus grandes et mieux espacées.",
        },
    },
    {
        version = "0.73.4", date = "16/11/2026",
        added = {
            "Commande /wk nav : dit ce que ce client permet pour un repère de navigation à l'écran (marqueur de point de passage) : fonctions du jeu présentes, point suivi, distance, place du repère du jeu à l'écran. À lancer pendant un guidage.",
        },
    },
    {
        version = "0.73.3", date = "16/11/2026",
        fixed = {
            "Aide (/wk aide) : la ligne du guidage affichait « boite|banqueeparer » ; le jeu prenait « |r » pour un code de couleur. Les barres s'affichent maintenant telles quelles.",
        },
        added = {
            "Aide : la commande /wk micro (diagnostic des raccourcis du micro menu) apparaît dans la liste.",
        },
    },
    {
        version = "0.73.2", date = "16/11/2026",
        changed = {
            "Listes d'achat : un seul clic par objet. Après chaque achat, le prix de l'objet suivant est demandé tout seul et le bouton affiche directement « Confirmer… ». (Acheter toute la liste d'un seul clic est impossible : le jeu exige un clic du joueur pour chaque achat.)",
            "Listes d'achat : un objet introuvable en quantité suffisante est passé, et l'achat continue avec le suivant ; à la fin, un récapitulatif dit combien d'achats et pour quel montant.",
        },
    },
    {
        version = "0.73.1", date = "16/11/2026",
        added = {
            "Guide de métier : boutons 75, 150, 225, 300 et Max dans la carte des matériaux. Les matériaux, le coût et la liste d'achat s'arrêtent au palier choisi (« Matériaux jusqu'à 150 »). Le choix est retenu par métier ; un palier déjà atteint passe au suivant.",
            "Métiers : les paliers 75, 150, 225 et 300 sont écrits sous la barre des rangs, à la couleur d'accent quand ils sont atteints.",
        },
    },
    {
        version = "0.73.0", date = "16/11/2026",
        added = {
            "Listes d'achat : bouton « Acheter » qui parcourt la liste au prix le plus bas. Le jeu exige un clic par achat : 1er clic, le prix de tout ce qui manque pour l'objet suivant ; 2e clic, « Confirmer 30 Barre de fer : 7 po 83 » ; puis on passe à l'objet suivant. La croix annule l'achat en attente.",
            "Listes d'achat : un objet acheté est retiré de la liste ; le bouton « - » retire aussi ce qui est déjà sur le compte.",
            "Listes d'achat : garde-fou « (cher !) » quand le prix demandé dépasse 2,5 fois le prix relevé par le scan.",
            "Un équipement ou une recette (pas une marchandise) n'est pas acheté d'office : la recherche s'ouvre dans la fenêtre de l'HV pour choisir l'enchère.",
        },
    },
    {
        version = "0.72.1", date = "16/11/2026",
        changed = {
            "Carte : la barre de filtres de la carte du monde se déplace. Glisse-la par sa poignée (à gauche) ; sa place est gardée. Clic droit sur la poignée pour la remettre en haut de la carte.",
        },
    },
    {
        version = "0.72.0", date = "16/11/2026",
        added = {
            "Hôtel des ventes : listes d'achat de l'addon. Le panneau à côté de l'HV a deux onglets, « Scan » et « Listes d'achat ». Pour chaque objet d'une liste : ce que tu as sur le compte sur ce qu'il faut (« 12 / 30 »), le prix relevé, et « Chercher » qui lance la recherche dans la fenêtre de l'HV (l'achat se fait avec ses boutons). En bas, ce qu'il reste à acheter ; la corbeille supprime la liste (deux clics).",
            "Métiers : « Liste d'achat » (guide de montée) et « Créer la liste d'achat » (composants manquants) préparent une liste d'achat de l'addon, au lieu d'une liste Auctionator.",
        },
        changed = {
            "Auctionator n'est plus utilisé du tout : tous les prix HV viennent du scan de l'addon (valeur des stocks, butin de farm, rentabilité des recettes, guides, infobulles). Options > Prix : la source s'appelle maintenant « Hôtel des ventes ».",
            "Les listes d'achat et l'onglet choisi du panneau ne font pas partie des profils (ce sont des données du compte).",
        },
    },
    {
        version = "0.71.2", date = "16/11/2026",
        changed = {
            "Hôtel des ventes : panneau plus lisible. Le nombre de prix s'écrit avec une espace (« 6 541 »), le dernier scan et le prochain scan complet sont sur deux lignes (« Scan complet possible maintenant » en vert, sinon « Prochain scan complet dans 15 min »), et le bouton passe en discret tant que le scan complet n'est pas possible.",
        },
        fixed = {
            "Hôtel des ventes : le « ~ » s'affichait mal dans la police du jeu et la ligne d'état touchait le bord du panneau.",
        },
    },
    {
        version = "0.71.1", date = "16/11/2026",
        changed = {
            "Hôtel des ventes : WoW Forever utilise le système d'HV récent (scan complet en une requête). Le scan respecte maintenant son délai : un scan complet toutes les 15 minutes environ ; avant, le bouton dit dans combien de minutes ce sera possible.",
            "Hôtel des ventes : /wk hv scan force pour tenter un scan sans attendre le délai.",
        },
        fixed = {
            "Hôtel des ventes : si le serveur n'envoie pas l'HV (scan demandé trop tôt), le scan s'arrête au bout de 90 secondes avec un message, au lieu d'attendre sans fin.",
        },
    },
    {
        version = "0.71.0", date = "16/11/2026",
        added = {
            "Carte : nouveau module QoL > Carte pour afficher les lieux utiles sur la carte du monde et la minicarte, rangés en familles de couleur : Services (boîtes aux lettres, hôtel des ventes, banque, auberges), Marchands (composants, munitions, poisons, fournitures, pêche, réparation), Maîtres (classe, métiers, écuries, familiers et démons), Voyage (maîtres de vol, bateaux et zeppelins), Divers (maîtres de guerre).",
            "Carte : barre de filtres en haut de la carte du monde. Clic sur une famille pour l'afficher ou la masquer, clic droit pour choisir le détail, roue dentée pour les réglages.",
            "Carte : les bateaux et zeppelins sont tracés en pointillés depuis leur quai vers leur destination, avec son nom (« vers Theramore »).",
            "Carte : au survol d'une pastille, le nom et le rôle du PNJ ; un clic lance le guidage jusqu'à lui.",
            "Carte : filtres « seulement ma faction », « seulement ma classe » (maître de classe, munitions, poisons, écuries) et « seulement mes métiers » (maîtres des métiers appris), taille des pastilles, et réglage séparé pour la minicarte.",
            "Lieux : hôtels des ventes, auberges, maîtres de vol, maîtres de métier, maîtres de guerre et maîtres des familiers ajoutés aux données (QuestieDB).",
            "Modules : « Carte » peut se couper dans la carte Modules du Résumé.",
        },
        changed = {
            "Les quais des bateaux de l'Alliance (Menethil, Theramore, Auberdine, Rut'theran) sont placés à la main : dis-moi s'il y en a un qui tombe à côté.",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.70.1", date = "16/11/2026",
        changed = {
            "Halo : l'atelier est maintenant en haut de QoL > Halo, au-dessus des réglages généraux.",
        },
    },
    {
        version = "0.70.0", date = "16/11/2026",
        added = {
            "Halo : atelier dans QoL > Halo. Les catégories en pastilles (clic : on la règle), un aperçu en direct à gauche, et à droite ses réglages : halo oui ou non, effet propre ou « comme les autres », couleur en nuancier (ou au choix avec +).",
            "Halo : trois nouveaux effets, Onde (cercles qui s'élargissent), Étincelles (petites étoiles qui scintillent autour de l'objet) et Viseur (anneau en pointillés qui tourne). Au choix pour toutes les catégories, ou une par une.",
            "Halo : couleur selon la difficulté pour les filons, les plantes et les créatures à dépecer : orange, jaune, vert ou gris comme dans les métiers, rouge si la compétence manque.",
            "Halo : ligne d'info sous l'objet, avec son nom et la compétence demandée (« Filon de fer · Minage 125 »).",
            "Halo : deux nouvelles catégories, les donneurs de quêtes qui ont une quête pour ce perso (d'après la page Quêtes) et les cadavres qui ont encore du butin.",
            "/wk halo dit aussi la compétence demandée et l'effet utilisé.",
        },
        changed = {
            "Halo : la liste « Objets et couleurs » est remplacée par l'atelier ; l'effet global se choisit dans une liste.",
            "Nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.69.1", date = "16/11/2026",
        changed = {
            "Barre de vol : nouveau look « ruban ». Une pilule fine avec la destination et sa zone, une barre de progression (un trait par relais) et le temps restant ; plus d'arc ni de griffon.",
            "Barre de vol : au survol, un volet s'ouvre dessous avec le trajet complet (départ > relais > arrivée, les relais passés en gris), l'heure de départ et d'arrivée, « Atterrir à … » et Carte. Il se referme quand la souris s'en va.",
        },
    },
    {
        version = "0.69.0", date = "16/11/2026",
        added = {
            "Modules : carte « Modules » en bas du Résumé. Repliée, une ligne d'icônes (rose : actif, gris : coupé) ; « Gérer » la déplie à la place du tableau des persos, avec une tuile par module rangée par groupe (son chiffre du moment et un interrupteur). Un clic sur une tuile ouvre la page du module.",
            "Modules : 15 modules à couper ou remettre : Stats, Métiers, Courrier, Hôtel des ventes, Session de farm, Loot, Journal, LFG, Quêtes, Rares, Récolte, Halo, Micro menu, Pêche, Distance.",
            "Modules : un module coupé quitte la barre latérale (et son groupe s'il est vide), la recherche et QoL ; ses infobulles et ce qu'il affiche à l'écran disparaissent et ses actions s'arrêtent (filtre de loot, détection et alerte des rares, scan auto de l'HV, halo, mode pêche…). Les relevés discrets (or, courrier, journal, quêtes faites) continuent, pour que rien ne manque quand on le remet.",
            "Modules : pour Halo, Micro menu, Pêche et Distance, un bouton « Recharger » apparaît pour terminer le changement proprement.",
            "Modules : les modules actifs font partie des profils (chaque profil peut avoir les siens).",
        },
        changed = {
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.68.1", date = "16/11/2026",
        added = {
            "En-tête : nouveau bouton pour recharger l'interface (/reload), à gauche de la croix ; il ne fait rien en combat.",
        },
        changed = {
            "En-tête : le bouton « Éditer l'interface » s'appelle maintenant « Éditer ».",
            "Nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.68.0", date = "16/11/2026",
        added = {
            "Hôtel des ventes : scan de l'HV sans Auctionator. Scan complet en une fois quand le jeu l'autorise (environ toutes les 15 minutes), sinon page par page ; le jeu ne se fige pas pendant la lecture.",
            "Hôtel des ventes : petit panneau à droite de la fenêtre de l'HV avec le nombre de prix connus, la date du dernier scan, la progression et le bouton « Scanner l'HV » (ou « Arrêter »).",
            "Hôtel des ventes : dans l'infobulle des objets, prix le plus bas à l'unité, moyenne sur 14 jours, prix de la pile, quantité en vente et date du relevé.",
            "Hôtel des ventes : réglages dans QoL > Hôtel des ventes (panneau, scan complet à l'ouverture, infobulle, prix de la pile, effacer les prix).",
            "Commande /wk hv : diagnostic de l'hôtel des ventes sur ce client ; /wk hv scan et /wk hv stop.",
        },
        changed = {
            "Prix HV : les prix de notre scan passent avant ceux d'Auctionator pour la valeur des stocks, le butin de farm, la rentabilité des recettes et les infobulles. Auctionator reste utilisé pour les objets que notre scan n'a pas encore vus.",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.67.2", date = "16/11/2026",
        changed = {
            "Micro menu : les 14 lignes « Masqué / Gauche / Droite » sont remplacées par la barre telle qu'elle est à l'écran. Clic sur une icône : gauche, puis droite, puis masquée ; clic sur une icône masquée : elle revient à gauche.",
            "Micro menu : on peut enfin choisir l'ordre des raccourcis (Maj + clic gauche ou droit pour décaler d'un cran) ; clic droit pour masquer.",
            "Quêtes : nouvelles couleurs pour les états, rouge pour « trop haute » et bleu pour « après une autre quête » (page, légende et infobulle du donneur).",
        },
    },
    {
        version = "0.67.1", date = "16/11/2026",
        changed = {
            "Rares : la page a deux onglets, « Collection » (tuiles et rares de la zone) et « Carte et infobulle » (réglages de la carte, de l'infobulle et de l'alerte, avec l'aperçu en taille réelle).",
            "Rares et Quêtes : les tuiles des zones s'étirent sur toute la largeur de la page.",
            "Recherche : un réglage des rares trouvé ouvre directement l'onglet « Carte et infobulle ».",
        },
    },
    {
        version = "0.67.0", date = "16/11/2026",
        added = {
            "Quêtes : nouvelle page « Quêtes » (groupe Exploration), sur le modèle de la page Rares : une tuile par zone avec la progression du perso, ta zone en premier puis la zone conseillée pour monter.",
            "Quêtes : liste des quêtes de la zone choisie, triées par niveau, avec leur état (disponible, dans le journal, faite, trop haute, après une autre quête), l'XP, le métier ou le donjon concerné, et « Guider » vers le donneur.",
            "Quêtes : « Quêtes de » pour voir la progression d'un autre perso, et filtre Toutes / À faire / Faites. Au survol d'une quête : qui l'a déjà faite et la suite de la chaîne.",
            "Quêtes : réglages à droite de la page (quêtes de donjon, trop hautes, de métier, de classe) et infobulle d'un PNJ avec ses quêtes pas encore faites par ce perso.",
            "Quêtes : en tête de page, les quêtes faites, la meilleure zone pour monter (la plus d'XP de quêtes à ton niveau) et le nombre de quêtes disponibles.",
        },
        changed = {
            "Quêtes faites et journal de quêtes enregistrés pour chaque perso à la connexion et à chaque quête prise ou rendue : connecte chaque perso une fois pour voir sa progression.",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
        fixed = {
            "Options > À propos : la mention des données QuestieDB couvre aussi les quêtes, et s'affiche maintenant en anglais sur un client anglais.",
            "Rares : la tuile de ta zone restait entourée quand on choisissait une autre zone ; seule la zone choisie est maintenant entourée (« ta zone » reste écrit sur la tienne).",
        },
    },
    {
        version = "0.66.0", date = "16/11/2026",
        changed = {
            "Rares : la page ne garde que la vue « Collection » (tuiles des zones, rares de la zone choisie en dessous) ; la vue « Zones » est retirée.",
            "Rares : les réglages des rares (carte, infobulle, alerte, son, style avec aperçu en direct, « Montrer à l'écran ») sont maintenant dans une colonne à droite de la page Rares, et quittent QoL.",
            "Commandes de la page Rares (« Collection de », « Masquer les tués ») regroupées en haut à gauche.",
        },
    },
    {
        version = "0.65.0", date = "16/11/2026",
        added = {
            "Rares : nouvelle page « Rares » (groupe Exploration de la barre latérale), la collection des rares perso par perso, avec en tête les rares tués, ta zone et les rares restants à ton niveau.",
            "Rares : vue « Zones », avec ta zone en grand et sa progression, les zones par continent avec leur compte, et les rares de la zone choisie (niveau à la couleur de difficulté, butin utile pour tes métiers, tué ou pas, Guider).",
            "Rares : vue « Collection », une tuile par zone avec un anneau de progression (vert quand la zone est terminée), ta zone en premier ; un clic affiche ses rares en dessous.",
            "Rares : « Collection de » pour regarder la collection d'un autre de tes persos, et « Masquer les tués » dans la liste.",
            "Rares : réglage « Masquer les rares tués sur la carte ».",
            "Rares : alerte au choix en bandeau ou compacte (une ligne, clic pour guider), avec un aperçu en direct dans QoL > Rares et trois états à essayer (pas tué, déjà tué, élite).",
        },
        changed = {
            "Barre latérale : les titres de groupe se resserrent davantage quand la place manque, pour que les entrées ne se chevauchent jamais.",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.64.1", date = "16/11/2026",
        changed = {
            "Profils : ils ont maintenant leur propre page dans la barre latérale, entre Patch notes et Options (ils étaient dans Options), avec leurs pastilles en tête : profil actuel, nombre de profils, persos sur ce profil.",
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.64.0", date = "16/11/2026",
        added = {
            "Recherche en haut de la barre latérale : pages, sections, réglages, persos et objets du compte, en direct dès deux lettres. Un clic ouvre la bonne page et la bonne section, fait défiler jusqu'au réglage et le met en évidence. Entrée prend le premier résultat, Échap efface.",
            "Profils de réglages (Options > Profils) : crée des profils à partir de tes réglages actuels, choisis-en un par perso, copie les réglages d'un profil dans un autre, ou remets un profil aux réglages d'origine. Changer de profil recharge l'interface.",
            "Un profil contient l'apparence, QoL, le halo, les rares et la récolte ; les données du compte (persos, sacs, journal, courrier, notes de joueurs, rares tués) n'en font jamais partie.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.63.0", date = "15/11/2026",
        added = {
            "Rares : les 327 monstres rares de WoW Forever (données QuestieDB), avec noms français, apparitions, patrouilles et butin notable.",
            "Rares : un médaillon par rare sur la carte du monde (mauve, doré pour un rare élite, grisé si ce perso l'a tué). Au survol, ses autres points d'apparition et sa patrouille en pointillés ; un clic lance le guidage.",
            "Rares : liste « Rares de la zone » sur le côté de la carte du monde, avec le nombre restant à tuer ; clic sur une ligne pour être guidé.",
            "Rares : alerte « Rare en vue » en haut de l'écran quand un rare entre dans ton champ de vision, avec son portrait, son niveau, son butin notable et s'il a déjà été tué. Boutons Cibler (hors combat) et Guider, son au choix. Se place en mode édition.",
            "Rares : dans l'infobulle d'un rare, son butin notable (recettes, avec tes persos qui ont le métier) et lesquels de tes persos l'ont déjà tué.",
            "QoL : nouvelle section « Rares » pour régler tout ça, avec une alerte de test.",
        },
        changed = {
            "Les rares tués sont comptés à partir de cette version (le jeu ne garde pas d'historique).",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.62.2", date = "15/11/2026",
        changed = {
            "Patch notes : la liste « À venir » reprend tout ce qui est prévu (rares, quêtes, suite de la pêche, Warband UI).",
        },
    },
    {
        version = "0.62.1", date = "15/11/2026",
        changed = {
            "LFG : nouvelle couronne du chef de groupe, plus ronde, penchée et posée de travers sur le haut de son logo, avec une petite ombre.",
            "Texture modifiée : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.62.0", date = "15/11/2026",
        changed = {
            "LFG : sur les cartes de groupe, chaque place prise montre le logo de la classe du joueur, avec un petit trait à la couleur de son rôle dessous (bleu tank, vert soin, rouge dégâts). Le chef de groupe porte une couronne sur son logo.",
            "LFG : l'infobulle d'une carte liste chaque membre (nom, classe, niveau, rôle) ; le chef est marqué d'une étoile.",
            "Nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.61.2", date = "15/11/2026",
        fixed = {
            "Halo : il s'allumait sur les chaises, bancs et autres sièges. Le mobilier est maintenant écarté.",
        },
        changed = {
            "Halo : la catégorie « Autres objets » est décochée par défaut (elle éclairait trop de choses). Tu peux la recocher dans QoL > Halo.",
        },
    },
    {
        version = "0.61.1", date = "15/11/2026",
        fixed = {
            "LFG : avec la fenêtre à sa taille minimale, le texte sous « Actualiser » passait sur « Je cherche ». Le bandeau se resserre maintenant (rôles plus courts, classe sous le nom masquée) et l'état de la recherche passe dans l'infobulle d'Actualiser.",
            "LFG : le message d'accueil (« Choisis un donjon… ») était coupé ; il passe maintenant à la ligne.",
        },
    },
    {
        version = "0.61.0", date = "15/11/2026",
        added = {
            "LFG : bouton « Affiner » (entonnoir, à côté d'Actualiser). Classes et niveau des joueurs seuls, style de jeu des annonces, et langues : par défaut le jeu ne cherche que dans ta langue, tu peux ajouter l'anglais et les autres. Un point signale qu'un filtre est actif.",
            "LFG : notes des joueurs, de 1 à 3 étoiles. Onglet « Récents » à droite : les joueurs avec qui tu as fait un groupe, à noter d'un clic. Clic droit sur une carte de groupe pour noter son chef.",
            "LFG : un liseré à gauche des cartes montre ta note (rouge 1 étoile, gris 2, vert 3). Les joueurs notés 1 étoile passent en bas des listes, et le chat te prévient s'ils rejoignent ton groupe.",
            "LFG : le style de jeu de l'annonce (apprentissage, décontracté, compétitif, carry) s'affiche sur la carte quand le chef n'a pas laissé de message.",
        },
        changed = {
            "LFG : « Mes demandes » est gardé après un /reload ou une déconnexion (pendant 3 heures).",
            "Nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.60.0", date = "15/11/2026",
        added = {
            "Infobulles : nouvelle partie « Montée des métiers ». Pour un composant, les métiers qui s'en servent dans les guides de montée et, pour chacun de tes persos qui a ce métier, combien il en faut encore à son niveau (« Alchimie · Lapine (40) : encore 36 »), avec ce que le compte en a déjà.",
            "Infobulles : pour une recette ou un outil utile à la montée, le métier et les niveaux concernés.",
            "Options > Général : réglage pour afficher ou non cette partie de l'infobulle.",
        },
    },
    {
        version = "0.59.3", date = "15/11/2026",
        changed = {
            "LFG : dans les messages envoyés, le nom du donjon est maintenant en anglais (« The Stockade » au lieu de « Prison de Stormwind »). Tous les donjons et raids de WoW Forever sont reconnus, ailes du Monastère écarlate et de Hache-tripes comprises ; un nom inconnu reste tel quel.",
        },
    },
    {
        version = "0.59.2", date = "15/11/2026",
        changed = {
            "LFG : les messages envoyés aux autres joueurs sont maintenant en anglais, la langue commune d'un serveur européen (« Hi! Hunter 23, dps, available for … »). L'ancien message par défaut est remplacé ; un message que tu avais modifié est gardé.",
            "LFG : mots-clés du message en anglais (%class%, %level%, %role%, %dungeon%) ; les mots-clés français marchent toujours.",
        },
    },
    {
        version = "0.59.1", date = "15/11/2026",
        fixed = {
            "Halo : en donjon et en combat, le jeu masque le nom de l'objet désigné, et l'addon affichait des erreurs dans le chat (« attempt to perform string conversion on a secret string value »). Le halo reste maintenant simplement éteint dans ce cas.",
            "Barre de vol : la durée estimée d'un trajet pas encore fait était fausse. Elle était calculée sur la carte des vols, dont l'échelle change d'un continent à l'autre. Elle est maintenant calculée en mètres, puis corrigée en vol d'après la distance réellement parcourue.",
        },
    },
    {
        version = "0.59.0", date = "15/11/2026",
        added = {
            "Nouvel onglet LFG (groupe « Groupe » de la barre latérale) : la recherche de groupe du jeu, présentée à partir de ton perso.",
            "LFG : tu choisis tes rôles (tank, soin, dégâts) et ce que tu cherches (un groupe ou des joueurs), puis « Actualiser ».",
            "LFG : à gauche, les donjons classés par niveau, avec un trait à ton niveau et le nombre de groupes de chacun. Un clic limite la recherche à ce donjon.",
            "LFG : les groupes en cartes, avec leurs cinq places (tank, soin, trois dégâts). « Une place pour toi » montre d'abord les groupes qui cherchent ton rôle, et la place que tu prendrais.",
            "LFG : « Demander » envoie au chef un message rédigé d'après ton perso, ton rôle et le donjon (modifiable). « Inviter » pour les joueurs seuls.",
            "LFG : « Mes demandes » suit chaque demande (réponse reçue, en attente, groupe retiré).",
            "Micro menu : raccourci « LFG », avec un point vert quand un chef t'a répondu.",
        },
        changed = {
            "Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.58.3", date = "15/11/2026",
        fixed = {
            "Micro menu : le raccourci « Menu du jeu » provoquait l'erreur « WarbandKeeper a tenté d'appeler la fonction protégée SpellStopCasting() ». Il passait par la fonction de la touche Échap, qui interrompt aussi le sort en cours. Il ouvre maintenant la fenêtre du menu sans passer par elle.",
        },
    },
    {
        version = "0.58.2", date = "15/11/2026",
        changed = {
            "Pêche : le bouton de minicarte disparaît quand le raccourci « Mode pêche » est présent dans le micro menu (il faisait doublon). Il revient si tu masques le raccourci.",
        },
    },
    {
        version = "0.58.1", date = "15/11/2026",
        fixed = {
            "Micro menu : le raccourci « Menu du jeu » n'ouvrait rien. Il essaie le bouton du jeu, puis ouvre le menu directement si rien ne s'est passé.",
        },
        added = {
            "/wk micro : indique par quel chemin chaque raccourci du micro menu ouvre sa fenêtre.",
        },
    },
    {
        version = "0.58.0", date = "15/11/2026",
        changed = {
            "Micro menu : les icônes sont refaites dans le style de l'addon (formes pleines, traits épais), comme celles de la barre latérale. Cinq sont nouvelles : personnage, grimoire, talents, carte et quêtes.",
            "Nouvelles textures : relancer le jeu (un /reload ne suffit pas).",
        },
        added = {
            "Micro menu : raccourci « Mode pêche », avec son icône. Un point vert indique que le mode est ouvert. Il apparaît à droite ; il se déplace ou se masque dans QoL > Micro menu.",
        },
    },
    {
        version = "0.57.0", date = "15/11/2026",
        added = {
            "Récolte : les emplacements connus des filons et des plantes s'affichent sur la minicarte et sur la carte du monde (près de 24 000 emplacements, dans toute la zone). Ce sont des emplacements possibles, pas des nœuds présents en direct.",
            "Récolte : l'anneau de chaque icône dit la difficulté pour ta compétence (rouge trop dur, orange, jaune, vert, gris).",
            "Récolte : réglages dans Options > Récolte (minicarte, carte du monde, seulement mes métiers, seulement ce que je peux récolter, taille des icônes).",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.56.2", date = "15/11/2026",
        fixed = {
            "Micro menu : les raccourcis Personnage, Grimoire, Talents, Carte, Quêtes, Social et Menu ouvraient la fenêtre du jeu depuis l'addon, ce qui provoquait ensuite l'erreur « WarbandKeeper a tenté d'appeler la fonction protégée StatusBar:Show() » en combat. Ils cliquent maintenant le bouton du jeu par un chemin protégé.",
        },
    },
    {
        version = "0.56.1", date = "15/11/2026",
        changed = {
            "Halo : le réglage « Portée » s'arrête de nouveau à 15 m. Le jeu ne désigne pas un objet plus loin, quelle que soit la valeur demandée : monter au-delà ne changeait rien.",
            "Pêche : le flotteur est cherché plus loin (jusqu'à 60 m) pendant le mode pêche, pour que la touche puisse le ferrer.",
        },
    },
    {
        version = "0.56.0", date = "15/11/2026",
        added = {
            "Pêche : nouvel onglet dans QoL, avec un « mode pêche » qu'on ouvre et qu'on ferme (bouton, /wk peche, bouton de minicarte, ou tout seul quand une canne est équipée).",
            "Pêche : tenue de pêche. La meilleure canne des sacs et les pièces qui donnent de la Pêche sont équipées ; l'équipement habituel revient à la fermeture.",
            "Pêche : appâts. Le meilleur appât utilisable (ou celui que tu choisis) est posé sur la canne, et reposé quand il expire.",
            "Pêche : une seule touche pour tout (molette vers le bas par défaut). Chaque appui équipe la tenue, pose l'appât, lance la ligne, puis ferre le flotteur. Hors du mode pêche, la touche garde son rôle.",
            "Pêche : barre à l'écran (bouton Pêcher, tenue, appât avec temps restant), à placer en mode édition.",
            "Pêche : icône « acheter une canne » quand il n'y en a ni équipée ni dans les sacs ; un clic guide vers les fournitures de pêche les plus proches.",
            "Pêche : butin rapide, qui ramasse la prise dès que le butin est prêt.",
            "Pêche : son du flotteur mis en avant (musique et ambiance coupées le temps de pêcher, puis rétablies).",
            "Pêche : avertissements à l'écran (pas de canne, plus d'appât, sacs pleins).",
            "Pêche : bouton de minicarte, sur les persos qui ont la Pêche.",
            "Guidage : les marchands de fournitures de pêche sont connus.",
        },
        changed = {
            "Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.55.1", date = "15/11/2026",
        changed = {
            "Halo : la colonne de lumière est presque deux fois plus haute par défaut, et plus lumineuse quand l'objet est encore loin.",
            "Halo : la portée se règle maintenant jusqu'à 60 m (30 m avant), pour voir l'objet de plus loin.",
        },
        added = {
            "Halo : réglage « Hauteur de la colonne ».",
        },
    },
    {
        version = "0.55.0", date = "15/11/2026",
        added = {
            "Halo : nouvelle catégorie « Créatures à dépecer » (brun clair). Le cadavre que le jeu désigne brille s'il est dépeçable et si le perso a le Dépeçage.",
        },
    },
    {
        version = "0.54.0", date = "15/11/2026",
        changed = {
            "Indicateur de distance : l'anneau est remplacé par une règle compacte. Quatre zones en couleur (corps à corps, zone morte, tir, trop loin), un curseur blanc à la distance de la cible, et au-dessus la zone avec la fourchette estimée (« À portée · 22-25 m »).",
            "Indicateur de distance : sans cible, la règle reste affichée en estompé (ou masquée, selon l'option).",
        },
        added = {
            "Indicateur de distance : réglage « Largeur » pour l'aligner sur une barre de vie, et options « Texte au-dessus » et « Fond sombre ».",
        },
    },
    {
        version = "0.53.0", date = "15/11/2026",
        added = {
            "Halo : choix de l'effet (QoL > Halo > Effet) : halo, colonne de lumière au-dessus de l'objet, ou les deux. La colonne prend la couleur de la catégorie et s'avive à portée.",
        },
        changed = {
            "Nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.52.0", date = "15/11/2026",
        added = {
            "Indicateur de distance : la vraie fourchette de distance de la cible s'affiche (par exemple « 20-25 m ») à la place du « 8-35 m » fixe, grâce à la bibliothèque LibRangeCheck-3.0.",
            "Indicateur de distance : état « ? » quand le jeu ne donne pas la distance, au lieu d'afficher « trop loin » à tort.",
        },
        changed = {
            "Indicateur de distance : la zone morte (plus au corps à corps, pas encore à portée de tir) est calculée d'après la distance estimée, entre 5 et 8 m.",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.51.3", date = "15/11/2026",
        fixed = {
            "Halo : beaucoup d'objets de quête n'étaient pas reconnus, donc pas éclairés. L'objet est maintenant reconnu par son nom dans les objectifs de tes quêtes, et par le curseur que le jeu lui donne (pioche, fleur, quête, main).",
        },
        added = {
            "Halo : catégorie « Autres objets » (blanc), pour tout objet utilisable qui n'est ni plante, ni filon, ni quête, ni coffre. Elle se décoche dans les réglages.",
            "/wk halo affiche le curseur que le jeu donne à l'objet.",
        },
    },
    {
        version = "0.51.2", date = "15/11/2026",
        fixed = {
            "Halo : l'addon demandait au jeu si l'objet désigné « existe », or le jeu répond non pour un objet du décor (plante, filon, objet de quête). Il demande maintenant si c'est un objet : le halo ne restait éteint que pour cette raison.",
            "Halo : la plaque d'un objet du décor est aussi retrouvée parmi les plaques affichées.",
        },
        changed = {
            "/wk halo affiche les réponses brutes du jeu sur l'objet désigné.",
        },
    },
    {
        version = "0.51.1", date = "15/11/2026",
        fixed = {
            "Halo : le jeu ne désignait un objet qu'à portée de main (quelques mètres), donc le halo ne s'allumait pas à l'approche. L'addon règle maintenant le jeu pour désigner l'objet jusqu'à la portée choisie, et pour afficher sa plaque aussi loin.",
        },
        changed = {
            "/wk halo affiche aussi ces nouveaux réglages du jeu.",
        },
    },
    {
        version = "0.51.0", date = "15/11/2026",
        added = {
            "Micro menu : option « Raccourcis toujours affichés » (sinon ils se déplient au survol).",
            "Micro menu : option « Horloge toujours affichée » (sinon elle apparaît au survol de son emplacement).",
            "Halo : commande /wk halo, qui dit pourquoi l'objet désigné brille ou non (activé, réglages du jeu, catégorie reconnue, plaque trouvée).",
        },
        fixed = {
            "Halo : il ne s'allumait presque jamais, car la plaque de l'objet arrive un instant après sa désignation et l'addon ne revérifiait pas. Il réessaie maintenant, et retrouve la plaque même si le jeu ne la donne pas directement.",
            "Halo : les objets de quête sont aussi reconnus d'après leur infobulle (titre ou objectif de quête), quand le jeu ne les signale pas lui-même.",
        },
    },
    {
        version = "0.50.1", date = "15/11/2026",
        fixed = {
            "Micro menu : l'heure et les barres FPS / latence paraissaient décentrées. Les deux barres vont maintenant d'un bord du texte à l'autre, leur partie vide reste visible, et le gras n'est plus décalé d'un côté.",
        },
    },
    {
        version = "0.50.0", date = "15/11/2026",
        added = {
            "Micro menu : l'heure peut s'afficher en gras.",
            "Micro menu : taille de l'heure réglable à part (0 = suit la taille des raccourcis).",
            "Micro menu : police de l'heure au choix (police de l'interface, Friz Quadrata, Arial Narrow, Morpheus, Skurri), indépendante du reste de l'addon.",
        },
        changed = {
            "Mode édition : le panneau (grille, aimant, disposition, Terminer) est maintenant en bas de l'écran.",
            "Micro menu : le fond de l'heure s'adapte à la taille du texte, et les raccourcis restent centrés en hauteur.",
        },
    },
    {
        version = "0.49.0", date = "15/11/2026",
        changed = {
            "QoL : les 9 classes sont rangées dans un seul onglet « Classes » de la colonne. Elles se choisissent dans une barre d'onglets en haut de la page (icône, nom, nombre d'alertes ; classes non jouées en grisé).",
            "QoL : l'onglet « Classes » rouvre la dernière classe consultée, sinon celle du perso joué.",
        },
    },
    {
        version = "0.48.1", date = "15/11/2026",
        changed = {
            "Micro menu : plus de fond derrière les raccourcis de gauche et de droite. Seule l'heure garde le sien, les icônes restent sur leurs tuiles.",
        },
    },
    {
        version = "0.48.0", date = "15/11/2026",
        changed = {
            "Indicateur de distance : sans cible, un anneau beige en pointillés avec un viseur au centre remplace le texte « sans cible », qui était coupé.",
            "Flèche de guidage plus compacte, sur deux lignes : le nom, puis le rôle (maître des écuries, banquier…) et la distance dans une pastille à la couleur du thème.",
            "Nouvelles textures : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.47.0", date = "15/11/2026",
        changed = {
            "Micro menu : le fond est séparé en trois (raccourcis de gauche, heure, raccourcis de droite). Les côtés glissent depuis l'heure au survol.",
            "Micro menu : avec l'effet loupe, le fond de chaque côté grandit avec les icônes au lieu de les laisser déborder.",
            "Micro menu : FPS et latence sont maintenant deux petites barres sous l'heure, remplies selon la valeur (vert, orange, rouge).",
        },
        added = {
            "Micro menu : réglage « Taille » (raccourcis et heure), dans Qualité de vie > Micro menu.",
        },
    },
    {
        version = "0.46.0", date = "15/11/2026",
        changed = {
            "Micro menu : nouvelles icônes dessinées au trait fin, à la couleur du thème, sur des tuiles sombres arrondies. Les douze raccourcis ont maintenant le même style.",
            "Nouvelles textures : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.45.2", date = "15/11/2026",
        fixed = {
            "Indicateur de distance : sans cible, l'anneau gris et transparent était presque invisible. Il est maintenant beige sur un fond sombre, avec « sans cible » au centre.",
        },
        added = {
            "Indicateur de distance : option « Masquer sans cible ».",
        },
    },
    {
        version = "0.45.1", date = "15/11/2026",
        changed = {
            "Cadre du familier plus compact : la barre de vie prend toute la largeur, et une seule ligne en dessous réunit les boutons (à gauche), l'humeur (au milieu) et la nourriture avec son nombre (à droite).",
        },
        fixed = {
            "Cadre du familier : le chiffre de vie était illisible sur la barre verte. Il a maintenant un contour noir et la barre est un peu plus sombre.",
        },
    },
    {
        version = "0.45.0", date = "15/11/2026",
        changed = {
            "QoL : nouvelle entrée « Micro menu » sous Halo, avec les réglages de l'horloge et des raccourcis (heure locale ou serveur, format, effet loupe, FPS et latence, place de chaque raccourci). Dans le mode édition, l'élément s'appelle aussi « Micro menu ».",
        },
        fixed = {
            "Les réglages de l'horloge et des raccourcis avaient disparu de QoL > Général depuis la 0.43.1 (retirés par erreur avec la carte « Disposition à l'écran »). Ils sont de retour, dans « Micro menu ».",
        },
    },
    {
        version = "0.44.3", date = "15/11/2026",
        changed = {
            "QoL > Chasseur > Familier : le bouton « Macro Nourrir » est retiré (le cadre du familier et son raccourci clavier font mieux) ; il reste le bouton « Maître des écuries », à la couleur du thème.",
        },
    },
    {
        version = "0.44.2", date = "15/11/2026",
        changed = {
            "Mode édition : la fenêtre de Warband Keeper se rouvre à la sortie si elle était ouverte au moment d'entrer.",
        },
    },
    {
        version = "0.44.1", date = "15/11/2026",
        changed = {
            "« Éditer l'interface » devient un bouton à droite de l'en-tête, sur toutes les pages, à la couleur d'accent du thème (au lieu d'une pastille de la page QoL).",
        },
    },
    {
        version = "0.44.0", date = "15/11/2026",
        added = {
            "Chasseur : indicateur de distance, un anneau coloré selon la cible : vert à portée de tir, orange au corps à corps, jaune dans la zone morte (5 à 8 m, option), rouge trop loin, gris sans cible. Fourchette de distance estimée au centre.",
            "Réglages dans QoL > Chasseur > Indicateur de distance (seulement en combat, zone morte, distance au centre) ; position et taille en mode édition.",
        },
        changed = {
            "Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.43.2", date = "15/11/2026",
        fixed = {
            "Cadre du familier : la vie ne s'affichait pas sur WoW Forever (le jeu la donne parfois sous forme masquée, que l'addon ne peut pas lire). La barre et le chiffre sont maintenant affichés par le jeu lui-même, même dans ce cas.",
        },
        changed = {
            "Cadre du familier : les boutons Nourrir et Soigner deviennent des icônes (Nourrir le familier, Guérison du familier, et Ressusciter quand il est mort), avec leur nom au survol. Sous la nourriture, seulement le nombre en sac.",
        },
    },
    {
        version = "0.43.1", date = "15/11/2026",
        changed = {
            "La « carte du familier » s'appelle maintenant « cadre du familier ».",
            "Mode édition : pastille « Éditer l'interface » dans l'en-tête de la page QoL (et /wk edit) ; l'option « disposition propre à chaque perso » est dans la barre du mode édition. La carte « Disposition à l'écran » quitte QoL > Général.",
            "Chasseur : quand HunterSuite est chargé, une note le signale dans la fiche Chasseur, avec une option pour garder quand même le cadre et le bouton du familier, le bouton d'aspect et les rappels de Warband Keeper (sinon masqués pour ne pas faire doublon).",
        },
    },
    {
        version = "0.43.0", date = "15/11/2026",
        added = {
            "Horloge en haut de l'écran : l'heure et deux points de couleur pour les FPS et la latence. Au survol, les raccourcis glissent de chaque côté avec un effet loupe façon dock, et se replient quand la souris s'en va. Clic sur l'heure : calendrier ; infobulle : date, heure du serveur, durée de la session, FPS et latence.",
            "Raccourcis au choix, à gauche ou à droite : Warband Keeper, courrier (point doré s'il y a du courrier), pierre de foyer, personnage, grimoire, talents, carte, journal de quêtes, social, métier principal, session de farm (point vert si elle tourne), menu du jeu.",
            "Réglages dans QoL > Général > Horloge et raccourcis : heure locale ou du serveur, 24 h ou 12 h, effet loupe (curseur), FPS et latence, et la place de chaque raccourci. Position et taille en mode édition.",
        },
        changed = {
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.42.0", date = "15/11/2026",
        changed = {
            "Barre de vol redessinée en « arc de vol » : le trajet en arc pointillé comme un vol vu de côté, le griffon qui glisse le long de l'arc (partie parcourue en couleur du thème), les relais en balises plantées sur l'arc avec leur nom.",
            "Médaillon à droite avec le temps restant et l'heure d'arrivée ; le bouton dit directement « Atterrir à … » avec le nom du prochain relais.",
        },
    },
    {
        version = "0.41.2", date = "15/11/2026",
        added = {
            "Barre de vol : les étapes du trajet (relais intermédiaires) sont placées sur la piste avec leur nom, à la bonne distance ; celles déjà passées prennent la couleur du thème. « Atterrir » indique le relais où tu te poseras.",
        },
    },
    {
        version = "0.41.1", date = "15/11/2026",
        changed = {
            "Carte du familier : quand le familier est mort, la carte reste affichée et « Soigner » devient « Ressusciter » (bouton, clic droit sur la carte et raccourci clavier). La barre et l'humeur indiquent « Mort ».",
        },
    },
    {
        version = "0.41.0", date = "15/11/2026",
        added = {
            "Chasseur : bouton d'aspect avec l'icône de l'aspect actif (et en petit, le prochain). Clic : aspect suivant de ta liste ; clic droit : aspect principal. Marche en combat.",
            "Réglages dans QoL > Chasseur > Bouton d'aspect : aspects à alterner et aspect principal. Position et taille en mode édition.",
            "Raccourcis clavier (Options du jeu > Raccourcis > AddOns > Warband Keeper) : aspect suivant, aspect principal, nourrir le familier, soigner le familier.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.40.0", date = "15/11/2026",
        added = {
            "Chasseur : carte du familier, affichée tant qu'un familier est là : nom et niveau, barre de vie, humeur (segments et texte), nourriture prévue (icône, nombre en sac et nom), boutons Nourrir et Soigner. Clic sur la carte : nourrir ; clic droit : Guérison du familier. Marche en combat.",
            "Réglages de la carte (QoL > Chasseur) : largeur, hauteur de la barre, chiffres (aucun, valeur, valeur / max, pourcentage), couleur (humeur, vie ou thème), humeur, nourriture, boutons, nom, quand l'afficher (toujours, hors combat, si besoin avec un seuil de vie), opacité hors combat. Position et taille en mode édition.",
        },
        changed = {
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.39.1", date = "15/11/2026",
        fixed = {
            "Loot : avec les sacs pleins, les objets que le filtre voulait ramasser restaient au sol sans être comptés (la liste des objets laissés restait vide). Ils sont maintenant ajoutés à la liste, marqués « sacs pleins », et la fenêtre de butin se ferme comme d'habitude.",
        },
    },
    {
        version = "0.39.0", date = "15/11/2026",
        added = {
            "Barre de vol : au départ d'un vol, « Départ › Arrivée », temps restant en grand, piste avec un griffon qui avance, et boutons « Atterrir » (se poser au prochain relais, si le jeu le permet), « Carte » et fermer.",
            "Durée des vols apprise au premier vol complet de chaque trajet, partagée entre tes persos ; avant ça, estimée d'après la distance (ou temps écoulé au tout premier vol).",
            "Réglage dans QoL > Général > Confort ; la barre se place et se redimensionne en mode édition.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.38.1", date = "15/11/2026",
        added = {
            "Chasseur : bouton « Maître des écuries » dans QoL > Chasseur > Familier, qui guide vers le maître des écuries le plus proche (aussi avec /wk guide ecurie). Les maîtres des écuries de WoW Forever sont ajoutés à la base des lieux.",
        },
    },
    {
        version = "0.38.0", date = "15/11/2026",
        added = {
            "Mode édition plein écran (QoL > Général > Disposition à l'écran, ou /wk edit) : grille, chaque élément encadré avec son nom et des exemples. Glisser pour déplacer (aimanté à la grille, Maj pour placer librement), tirer le coin pour la taille, flèches du clavier pour ajuster au pixel (Maj : 10), Échap ou « Terminer » pour quitter.",
            "Un clic sur un élément ouvre ses réglages : taille, opacité, réinitialisation ; pour la pile d'alertes, sens d'empilement (vers le bas ou le haut) et icônes affichées ou non. « Tout réinitialiser » (Maj + clic) remet tout en place.",
            "Disposition commune au compte, ou propre à chaque perso (option).",
            "Éléments concernés : pile d'alertes, bouton du familier, flèche de guidage. Leurs anciennes positions sont reprises.",
        },
        changed = {
            "Le mode édition se ferme tout seul au début d'un combat (le jeu interdit de déplacer le bouton du familier en combat).",
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.37.0", date = "15/11/2026",
        changed = {
            "QoL, fiches de classe : nouvelles tuiles des persos, une par ligne. Liseré et portrait à la couleur de classe, nom avec « classe · niveau », puis jusqu'à trois colonnes avec icône, valeur en grand, libellé et petite jauge ; une valeur passe en orange ou en rouge sous son seuil d'alerte.",
            "Chiffres de chaque classe : munitions, minutes de tir et humeur du familier (chasseur) ; poisons et crochetage (voleur) ; fragments d'âme, pierre de soins et pierre d'âme (démoniste) ; totems, ankhs et réincarnation (chaman) ; composants utiles au niveau du perso (mage, prêtre, paladin, druide) ; munitions et état de l'équipement (guerrier).",
        },
        fixed = {
            "Le « ~ » des estimations (« ~34 min de tir », « dans ~5 j ») s'affichait comme un petit accent en hauteur avec la police du jeu : remplacé par « env. ».",
        },
    },
    {
        version = "0.36.1", date = "15/11/2026",
        added = {
            "Munitions : l'alerte donne aussi les minutes de tir restantes (« munitions basses (120, ~2 min de tir) »), dans « À faire », la fenêtre de connexion et le guidage.",
            "Munitions : nouveau seuil d'alerte en minutes de tir (QoL > fiche de classe > Munitions), en plus ou à la place du seuil en nombre.",
        },
    },
    {
        version = "0.36.0", date = "15/11/2026",
        added = {
            "Munitions : les minutes de tir restantes (d'après ta vitesse de tir) s'affichent à côté du nombre de munitions dans les tuiles de la fiche de classe.",
            "Pile d'alertes : petites vignettes empilées (icône, texte, liseré de couleur) dans un cadre que l'on déplace en le glissant. Elle reste affichée tant que le problème n'est pas réglé.",
            "Chasseur : rappels dans la pile d'alertes, chacun désactivable dans QoL > Chasseur > Rappels : aucun aspect actif (hors combat), Guépard ou Meute en combat (hébétement), Grondement activé en donjon ou désactivé en solo, pistage des humanoïdes en champ de bataille (désactivé au départ).",
            "Chasseur : gros bouton rond qui pulse quand le familier est absent ou mort, même en combat. Clic : appeler, ou ressusciter s'il est mort ; clic droit : ressusciter ; Maj + glisser pour le déplacer. Désactivable dans QoL > Chasseur > Familier.",
            "Si l'addon HunterSuite est chargé, ces rappels et ce bouton se mettent en retrait pour ne pas faire doublon.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.35.0", date = "15/11/2026",
        changed = {
            "Chasseur : la nourriture que le familier accepte est demandée directement au jeu (plus besoin de le nourrir une première fois à la main), avec son régime (viande, poisson…). La macro « Nourrir » est juste tout de suite.",
            "Munitions : l'achat automatique prend la meilleure munition vendue pour ton arme (flèches pour arc et arbalète, balles pour fusil) et utilisable à ton niveau, et l'équipe si elle est meilleure que celle en place.",
        },
        fixed = {
            "Chasseur : l'humeur du familier n'était jamais lue sur WoW Forever (la fonction du jeu a changé de place), donc l'alerte « n'est plus heureux » ne se déclenchait pas.",
        },
    },
    {
        version = "0.34.1", date = "15/11/2026",
        changed = {
            "QoL > Général > Guidage : les boutons « le plus proche » prennent la couleur d'accent du thème, et le bouton « Arrêter » est retiré (la croix ou le clic droit sur la flèche arrêtent le guidage, comme /wk guide stop).",
        },
    },
    {
        version = "0.34.0", date = "15/11/2026",
        changed = {
            "La « lueur de récolte » s'appelle maintenant « Halo » et passe dans QoL : nouvelle entrée « Halo » sous Général (avec son état, activé ou non), mêmes réglages qu'avant (portée, taille, intensité, quand ne pas l'afficher, objets et couleurs).",
            "Options > Récolte ne garde que les coins de récolte sur la carte du monde.",
        },
    },
    {
        version = "0.33.0", date = "15/11/2026",
        changed = {
            "Patch notes : trois couleurs distinctes et fixes (vert sauge pour les ajouts, ambre pour les modifications, vieux rose pour les corrections), avec un symbole dans le badge (+, ~, !) et un liseré de couleur à gauche de chaque rubrique.",
            "Historique (or, richesse, matériaux suivis) : au-delà de 30 jours, un seul point par jour est gardé. Les courbes ne changent pas, mais les données ne grossissent plus sans fin (connexion et déconnexion plus rapides à la longue).",
            "Options > Récolte : la lueur précise qu'il faut l'éteindre avant de désinstaller l'addon (les réglages du jeu qu'elle modifie sont rendus à l'arrêt).",
        },
        fixed = {
            "Barre latérale : avec une fenêtre basse, le groupe « Confort » (QoL) passait sous « Patch notes » et « Options ». L'espacement se resserre maintenant quand la place manque.",
            "QoL : la colonne des classes se resserre aussi dans une fenêtre basse, pour garder une marge sous la dernière classe.",
            "Courrier : après un envoi raté, le message d'erreur d'un échec précédent pouvait réapparaître dans le diagnostic.",
            "Fiche métier d'un autre perso : « Recettes lues le… » chevauchait le libellé « Artisan » de la barre des rangs ; il est maintenant sur la ligne des boutons.",
        },
    },
    {
        version = "0.32.5", date = "15/11/2026",
        changed = {
            "Métiers : le bouton « Link tchat » et le réglage de son texte sont retirés sur Herboristerie, Dépeçage et Pêche, qui n'ont pas de lien de métier.",
        },
    },
    {
        version = "0.32.4", date = "15/11/2026",
        changed = {
            "Métiers : le bouton « Lier dans le chat » s'appelle maintenant « Link tchat ».",
        },
        fixed = {
            "Link tchat sur Herboristerie, Dépeçage ou Pêche : l'addon essayait d'ouvrir une fenêtre de métier qui n'existe pas, puis affichait « Le jeu n'a pas donné le lien ». Ces métiers n'ont pas de lien : le nom et le niveau sont envoyés tout de suite, sans message.",
        },
    },
    {
        version = "0.32.3", date = "15/11/2026",
        fixed = {
            "Messages du chat : « Warband Keeper » s'affichait toujours en bleu. Il prend maintenant la couleur d'accent du thème choisi.",
        },
    },
    {
        version = "0.32.2", date = "15/11/2026",
        changed = {
            "Chat épuré : plus de message « chargé » à chaque connexion (seulement à la première installation), plus de liste d'alertes à la connexion quand la fenêtre de rappels est active (sinon une seule ligne).",
            "Courrier : un seul bilan à la fin de l'envoi automatique (« Courrier envoyé : 24 à Lapine, 12 à Brumefer ») au lieu d'une ligne par lettre.",
            "Marchand : réparation, objets gris vendus et achats automatiques regroupés sur une seule ligne.",
            "Montants plus courts : les parties à zéro ne sont plus écrites (« 50pa » au lieu de « 0po 50pa 0pc »).",
            "Les rappels (familier, poisons, buffs, guidage, maître de classe) ne s'affichent plus qu'au milieu de l'écran, plus dans le chat. Invitations acceptées et duels refusés se font sans message. Les boutons de guidage n'écrivent plus rien quand la flèche est affichée.",
        },
    },
    {
        version = "0.32.1", date = "15/11/2026",
        changed = {
            "Métiers > Lier dans le chat : si le lien n'est pas encore enregistré, l'addon ouvre la fenêtre du métier une fois pour le lire, la referme et colle le lien (perso connecté). Pour un autre perso, le message explique qu'il faut le connecter et ouvrir son métier une fois. L'infobulle du bouton le précise aussi.",
        },
    },
    {
        version = "0.32.0", date = "15/11/2026",
        added = {
            "QoL > Général > Marchand : la fenêtre du marchand se ferme toute seule après une réparation automatique (une fois les objets gris vendus et les achats faits). Maj enfoncée en parlant au marchand : elle reste ouverte. Désactivable.",
        },
    },
    {
        version = "0.31.1", date = "15/11/2026",
        fixed = {
            "Erreur au chargement « Attempt to register unknown event CRAFT_SHOW » : un évènement absent de ce client faisait échouer le chargement d'une partie de l'addon. Les évènements inconnus du client sont maintenant ignorés sans erreur.",
        },
    },
    {
        version = "0.31.0", date = "15/11/2026",
        added = {
            "Guidage vers le lieu utile le plus proche : boîte aux lettres, banque, réparation, marchand, munitions, composants de classe et maître de classe. Une flèche à l'écran (déplaçable, clic droit pour arrêter) indique la direction et la distance, et un repère s'affiche sur la carte du monde.",
            "Les alertes de QoL guident d'elles-mêmes : sacs presque pleins (boîte aux lettres, banque ou marchand le plus proche), équipement à réparer, composants ou munitions bas (marchand qui les vend). Hors combat et hors donjon, une fois toutes les 10 minutes par sujet.",
            "Maître de classe : à chaque niveau pair (nouveaux sorts), guidage vers le maître de ta classe le plus proche.",
            "QoL > Général > Guidage : réglages, boutons « le plus proche » et commande /wk guide (boite, banque, reparer, marchand, maitre, munitions, stop).",
            "Les lieux viennent de la base de données de Questie pour WoW Forever (QuestieDB, licence GPLv3), avec les noms français des PNJ : rien à apprendre, tout est connu dès le départ. Les marchands saisonniers (fêtes, foire) sont écartés.",
        },
        changed = {
            "Nouveaux fichiers et nouvelle texture : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.30.1", date = "15/11/2026",
        fixed = {
            "Métiers > Lier dans le chat : le lien de la fenêtre du métier n'était jamais retenu sur ce client (seul le nom et le niveau partaient). L'addon essaie maintenant toutes les façons de l'obtenir à l'ouverture du métier, et retient aussi un lien de métier que tu mets toi-même dans le chat depuis la fenêtre du jeu.",
        },
        added = {
            "Commande /wk lien : ce que le jeu a répondu à la dernière ouverture d'un métier, et les liens gardés pour le perso (pour comprendre un lien qui ne vient pas).",
        },
    },
    {
        version = "0.30.0", date = "15/11/2026",
        added = {
            "Nouvel onglet QoL (qualité de vie), dans un nouveau groupe « Confort » du menu : une colonne avec Général et les 9 classes (grisées quand aucun perso ne les joue), le nombre d'alertes à côté de chacune.",
            "QoL > Général : réparation automatique chez le marchand (plafond possible, or de guilde d'abord en option) et vente automatique des objets gris avec le total dans le chat.",
            "QoL > Général : durabilité de l'équipement et places libres dans les sacs et la banque de chaque perso (banque relevée à chaque visite), avec une alerte sous un seuil choisi (dans « À faire » et la fenêtre de connexion).",
            "QoL > Général : accepter les invitations de groupe des amis et de la guilde, refuser les duels (sauf amis et guilde en option), libérer l'esprit en champ de bataille, confirmer le butin lié quand on est seul, descendre de monture ou se lever quand une action l'exige, passer les cinématiques.",
            "Fiches de classe : tes persos de la classe en tête (stock de leurs composants), puis les composants de la classe avec un seuil d'alerte et un achat automatique chez le marchand jusqu'à la quantité voulue.",
            "Munitions (chasseur, guerrier, voleur) : alerte quand il en reste peu et achat automatique du même type de munitions.",
            "Chasseur : alerte quand le familier n'est plus heureux, nourriture qu'il accepte (apprise quand tu le nourris) et macro « Nourrir » qui choisit la nourriture toute seule.",
            "Voleur : alerte avant la fin des poisons sur les armes, coffres à crocheter dans les sacs de tes persos avec la compétence demandée, or volé à la tire.",
            "Démoniste : nombre maximum de fragments d'âme et bouton pour supprimer ceux en trop (Maj + clic). Mage : annonce de portail prête pour le chat. Guerrier : deux équipements d'armes (deux mains, arme et bouclier) à enregistrer et équiper en un clic. Chaman : totems en sac et temps de recharge de la Réincarnation.",
            "Rappels à l'écran hors combat : Robustesse du groupe (prêtre), aura et bénédiction (paladin), Marque du fauve (druide).",
            "Pastilles de l'en-tête QoL : composants bas, persos à réparer, sacs pleins et classes jouées.",
        },
        changed = {
            "Nouveaux fichiers et nouvelle icône : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.29.1", date = "14/11/2026",
        fixed = {
            "Filtre de loot : la fenêtre de butin pouvait rester ouverte, vide ou avec des objets voulus, quand le jeu donnait son contenu un peu tard. Le filtre attend maintenant le contenu, ferme une fenêtre vide et réessaie de ramasser les objets voulus.",
        },
        added = {
            "Message dans le chat quand des objets voulus n'ont pas pu être ramassés (sacs pleins).",
        },
    },
    {
        version = "0.29.0", date = "14/11/2026",
        added = {
            "Inventaire > À regrouper : les composants, consommables, gemmes et recettes présents chez plusieurs persos, avec le perso conseillé (celui qui en a le plus, ou celui d'une règle d'envoi existante) et un bouton « Regrouper » qui crée la règle d'envoi.",
            "Inventaire > Oubliés en banque : les objets de valeur qui dorment dans une banque (perso ou bataillon) depuis 7, 14 ou 30 jours, avec leur valeur et le total à revendre.",
        },
        changed = {
            "La date depuis laquelle chaque objet dort en banque est suivie à partir de cette version : ouvre tes banques une fois pour démarrer le suivi.",
        },
    },
    {
        version = "0.28.0", date = "14/11/2026",
        added = {
            "Coins de récolte : chaque plante, minerai ou cuir ramassé note l'endroit (tous les persos). Sur la carte du monde, une pastille par coin, de la couleur de la ressource et plus grosse là où tu récoltes souvent ; son survol détaille ce que tu y as récolté.",
            "Options > Récolte : enregistrer les récoltes, les afficher sur la carte du monde, et Maj + clic pour tout effacer.",
            "Farm en direct : or à l'heure, objets à l'heure et valeur du butin à l'heure sur les tuiles ; « Total / heure » comparé au record des 7 derniers jours (au survol : la zone du record). Le meilleur spot de la semaine est dans les pastilles et dans la mini-fenêtre.",
            "Fenêtre de rappels à la connexion d'un perso : les tâches du moment (comme « À faire » du Résumé), cliquables. Désactivable, avec un aperçu, dans Options > Général.",
        },
        changed = {
            "Options : la section « Lueur » devient « Récolte » (lueur et coins de récolte).",
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.27.0", date = "14/11/2026",
        added = {
            "Lueur de récolte : plantes, filons, objets de quête, coffres et flotteur de pêche brillent à ton approche (soft targeting du jeu). Halo qui respire, plus vif avec un anneau quand l'objet est à portée.",
            "Options > Lueur : activation (éteinte par défaut), portée, taille, intensité, couleur et activation par type d'objet, et masquage en combat, en instance ou sans le métier de récolte.",
            "Les réglages du jeu modifiés pour la lueur sont rendus à l'arrêt. Si l'addon Lueur est installé, cette lueur reste éteinte pour ne pas se disputer avec lui.",
        },
        changed = {
            "Nouveaux fichiers et textures : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.26.0", date = "14/11/2026",
        added = {
            "Fiche métier (tous les métiers) : bouton « Lier dans le chat » qui colle le lien de la fenêtre du métier du jeu, cliquable par les autres joueurs. Le lien est enregistré à chaque ouverture du métier, on peut donc le coller depuis n'importe quel perso.",
            "Texte personnalisé par métier (roue dentée à côté du bouton) : ajouté après le lien quand l'interrupteur « Ajouter ce texte au lien » est activé, avec un aperçu.",
        },
    },
    {
        version = "0.25.0", date = "14/11/2026",
        added = {
            "Fiche métier > « Manquantes » : les recettes que le perso ne connaît pas (toutes les recettes de WoW Forever, d'après wowtbc.gg), avec le niveau requis, où les obtenir (maître, vendeur et sa zone, ou à trouver) et leur prix à l'HV. Filtre « Apprenables » (les plus utiles d'abord) ou « Toutes ».",
            "Métiers > Recettes : bouton « Rentables maintenant » qui ne garde que les recettes rentables faisables avec les composants du compte, triées par gain total possible.",
            "Temps de recharge des fabrications (transmutations, étoffe lunaire…) : enregistrés à l'ouverture du métier, affichés sur la recette, et « de nouveau disponible » dans « À faire » du Résumé.",
            "Hôtel des ventes : les ventes et achats sont lus sur les factures du courrier quand tu en prends l'or ou l'objet. Ils apparaissent dans le Journal (filtre « HV ») et la pastille « Bilan HV 7 j » des Stats donne ventes, achats et meilleures ventes.",
        },
        changed = {
            "Nouveaux fichiers : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.24.1", date = "14/11/2026",
        added = {
            "Guides : pour chaque recette à acheter, sa disponibilité à l'hôtel des ventes d'après Auctionator (« HV : 1 po 50 pa (vu il y a 2 j) » ou « pas vu à l'HV »), sur la ligne de l'étape, au survol et dans les matériaux.",
        },
    },
    {
        version = "0.24.0", date = "14/11/2026",
        added = {
            "Guides de montée de WoW Forever pour l'Alchimie, la Forge, l'Enchantement, l'Ingénierie et la Couture : tous les métiers d'artisanat ont maintenant leur guide.",
            "Guides : les outils nécessaires (bâtonnets runiques, clé Arclight, marteau de forgeron…) apparaissent au survol des étapes ; un outil à acheter, comme le marteau de forgeron, est ajouté aux matériaux.",
        },
        changed = {
            "Les enchantements, qui ne fabriquent pas d'objet, s'affichent avec le nom de la recette du jeu ; une recette d'enchantement déjà apprise est reconnue.",
        },
    },
    {
        version = "0.23.4", date = "14/11/2026",
        changed = {
            "Infobulles de l'addon : mêmes couleurs que les cadres du thème choisi (fond et bordure), quel que soit le thème.",
        },
    },
    {
        version = "0.23.3", date = "14/11/2026",
        changed = {
            "Bouton fermer (fenêtre et liste des objets laissés au sol) : la croix prend la couleur d'accent du thème, sans infobulle.",
        },
    },
    {
        version = "0.23.2", date = "14/11/2026",
        changed = {
            "Guides de montée : les étapes qui demandent une recette l'indiquent clairement (« Recette à acheter chez … » avec le vendeur et sa zone quand elle est connue, ou « Recette connue » si le perso l'a déjà).",
            "Survol d'une étape : la recette et la liste complète de ses vendeurs avec leur zone.",
        },
        fixed = {
            "Matériaux du guide : l'infobulle d'une recette renvoyait au guide, qui n'en disait rien. Elle donne maintenant l'étape concernée et les vendeurs.",
        },
    },
    {
        version = "0.23.1", date = "14/11/2026",
        changed = {
            "Infobulles de l'addon : fond très sombre, bordure fine et claire, coins arrondis, sans liseré de couleur.",
        },
    },
    {
        version = "0.23.0", date = "14/11/2026",
        changed = {
            "Métiers > Niveaux : chaque métier d'un perso devient une tuile cliquable avec son icône, son niveau, une mini-barre des rangs (1-300) et ce qu'il y a à faire ensuite : étape du guide en cours, ressource et zone conseillées pour la récolte, ou « Plafond atteint : va voir le maître » (tuile encadrée en orange).",
            "Les cartes des persos prennent toute la largeur ; les tuiles s'adaptent à la taille de la fenêtre.",
        },
    },
    {
        version = "0.22.2", date = "14/11/2026",
        changed = {
            "Fiche d'un métier : les onglets « Niveaux / Recettes / Liste de courses » sont masqués (ils reviennent sur la liste des métiers) et la fiche remonte à leur place.",
        },
    },
    {
        version = "0.22.1", date = "14/11/2026",
        changed = {
            "Fiche métier (tous les métiers) : nouvel en-tête avec une barre des rangs de 1 à 300, découpée en Apprenti, Compagnon, Expert et Artisan, le rang en cours en clair et un repère à ton niveau.",
            "Fiche métier : la flèche de retour devient un bouton « Niveaux » plus visible.",
        },
    },
    {
        version = "0.22.0", date = "14/11/2026",
        changed = {
            "Métiers de récolte : « Où aller à ton niveau » devient des tuiles de zones, avec le niveau des monstres de chaque zone et les ressources utiles qu'on y trouve (pastille orange ou jaune). Ta zone actuelle passe en premier, encadrée avec « tu y es ».",
            "Toutes les infobulles de l'addon prennent son style : fond et bordure du thème, coins arrondis, liseré de la couleur d'accent. Les infobulles du jeu et des autres addons ne changent pas.",
        },
    },
    {
        version = "0.21.1", date = "14/11/2026",
        changed = {
            "Guides de montée : les objets que le guide fabrique lui-même (peaux traitées, bandages…) n'apparaissent plus dans les matériaux. Les cuirs fabriqués seulement pour monter restent comptés, moins ce que le guide en produit.",
            "Matériaux du guide : le prix de ce qui manque sur chaque ligne (« ok » quand tu as tout), le prix unitaire au survol, et le total à acheter en bas.",
            "Les recettes à acheter chez un vendeur font partie des matériaux, sauf celles que le perso connaît déjà.",
        },
    },
    {
        version = "0.21.0", date = "14/11/2026",
        added = {
            "Résumé : carte « À faire » à gauche de la courbe, avec les actions utiles du moment, les plus urgentes d'abord : courrier à récupérer (en rouge s'il expire bientôt), butin automatique du jeu qui bloque le filtre, métier au plafond de son rang à faire monter chez le maître, objets à envoyer ou à déposer, banque pas vue, session de farm en pause, composants manquants de la liste de courses.",
            "Chaque ligne de « À faire » est cliquable et mène à la bonne page.",
        },
    },
    {
        version = "0.20.1", date = "14/11/2026",
        changed = {
            "Résumé : le bloc « Or du compte » et ses tuiles (persos, temps de jeu, règles, à envoyer) est retiré, il faisait doublon avec les pastilles du haut. La courbe d'évolution de l'or prend toute la largeur.",
            "Persos : la pastille « Temps de jeu total » (tous les persos) passe en premier.",
            "Persos : survoler la pastille « Alertes » liste chaque alerte (perso et raison) ; un clic ouvre Options > Alertes.",
        },
        fixed = {
            "Métiers : les pastilles comptaient plusieurs fois un métier ou une recette connus par plusieurs persos.",
        },
    },
    {
        version = "0.20.0", date = "14/11/2026",
        added = {
            "Guides de montée de WoW Forever pour le Travail du cuir, le Secourisme et la Cuisine (d'après wowtbc.gg) : dans la fiche du métier, onglet « Guide de montée ».",
            "Le guide met en avant l'étape en cours selon le niveau du perso (avec les fabrications qui restent), grise les étapes faites, et indique les maîtres de chaque rang pour la faction du perso, ainsi que les recettes à acheter et leurs vendeurs.",
            "Matériaux jusqu'au max : ce qu'il faut, ce que le compte possède déjà, ce qui manque et son coût. Bouton « Liste Auctionator » pour les manquants, et « Envoyer à ce perso » pour créer les règles d'envoi des composants.",
        },
        changed = {
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.19.0", date = "14/11/2026",
        added = {
            "Métiers de récolte (Minage, Herboristerie, Dépeçage) : la fiche du métier liste chaque ressource avec son niveau requis et les zones où la trouver, au lieu des recettes.",
            "Les ressources orange et jaunes pour le niveau du perso sont mises en valeur, et une carte « Où aller à ton niveau » donne les zones conseillées (ta zone actuelle en vert).",
            "Dépeçage : niveau des monstres par type de cuir, et niveau maximal des monstres que le perso peut dépecer.",
        },
        changed = {
            "Nouveau fichier : relancer le jeu (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.18.0", date = "14/11/2026",
        changed = {
            "En haut des pages, le titre et la phrase d'explication sont remplacés par des pastilles avec les chiffres clés de la page (or, richesse, courrier en attente, session de farm, objets et valeur des stocks, règles, objets à envoyer…).",
            "Certaines pastilles sont cliquables et mènent à la bonne page : courrier en attente, liste de courses, source des prix, valeur laissée au sol…",
        },
    },
    {
        version = "0.17.1", date = "14/11/2026",
        changed = {
            "La fenêtre s'ouvre toujours sur le Résumé (un raccourci vers une page précise, comme le clic droit sur le bouton minimap, ouvre toujours cette page).",
        },
    },
    {
        version = "0.17.0", date = "14/11/2026",
        added = {
            "Loot : bouton « Voir la liste » qui affiche tous les objets laissés au sol, avec la quantité, le nombre de fois, la dernière fois, le prix à l'unité et la valeur totale.",
            "Liste des objets laissés au sol : tri par valeur, quantité ou récents, total en haut, bouton + pour toujours ramasser un objet, et Maj + clic sur « Vider la liste » pour repartir de zéro.",
        },
        changed = {
            "Les objets laissés au sol sont maintenant cumulés depuis la dernière remise à zéro (avant, seuls les 40 derniers étaient gardés).",
        },
    },
    {
        version = "0.16.2", date = "14/11/2026",
        changed = {
            "Loot : « Activation auto » devient « Se charge tout seul », avec une phrase qui explique le choix (« Jamais (bouton Charger) », zone, donjon, raid, JcJ, session de farm).",
        },
        fixed = {
            "Loot : le choix « Zone » proposait la zone où tu étais à l'ouverture de la fenêtre au lieu de ta zone actuelle.",
        },
    },
    {
        version = "0.16.1", date = "14/11/2026",
        changed = {
            "Loot : le filtre s'active dans un bandeau en haut de la page, qui montre son état et le profil chargé (au lieu d'un petit interrupteur en bas de la colonne).",
            "Courrier : la ligne « Mes persos » est remplacée par un petit bouton liste à côté du destinataire, qui propose tes persos avec leur nom complet. Le champ reste libre pour un autre joueur.",
        },
    },
    {
        version = "0.16.0", date = "14/11/2026",
        added = {
            "Options > Courrier : tous les réglages du courrier et de la banque au même endroit (envoi automatique, fermeture de la boîte aux lettres, tri des sacs, prise automatique, dépôt automatique).",
            "Page Courrier : bouton « Réglages » qui mène à Options > Courrier, et état de l'automatisme de l'onglet (activé / désactivé).",
        },
        changed = {
            "Options : Thèmes et Apparence ne forment plus qu'une section « Apparence ».",
            "La page Courrier ne garde que les règles et les boîtes aux lettres : plus de place pour la liste.",
        },
    },
    {
        version = "0.15.1", date = "14/11/2026",
        fixed = {
            "L'infobulle de la pierre de foyer listait inutilement tous les persos qui l'ont dans leurs sacs.",
        },
    },
    {
        version = "0.15.0", date = "14/11/2026",
        added = {
            "Résumé : une enveloppe à côté du nom des persos qui ont du courrier en attente. Elle passe au rouge quand le courrier expire bientôt (seuil réglé dans Options > Alertes).",
            "Survol de l'enveloppe : nombre de lettres, objets, or et jours avant expiration.",
        },
    },
    {
        version = "0.14.0", date = "14/11/2026",
        added = {
            "Les sacs sont triés automatiquement après l'envoi du courrier (et la prise automatique) et après le dépôt en banque, avec le tri du jeu.",
            "Option « Trier les sacs ensuite » dans Courrier > Envoi et dans Courrier > Dépôt banque (activée par défaut).",
        },
        changed = {
            "Le tri n'a lieu que si quelque chose a été envoyé ou déposé ; la boîte aux lettres se ferme juste après le tri.",
        },
    },
    {
        version = "0.13.0", date = "14/11/2026",
        added = {
            "Courrier : la boîte aux lettres se ferme toute seule après l'envoi automatique (après la prise automatique si elle est activée). Option dans Courrier > Envoi.",
            "Règles d'envoi et de dépôt en banque par perso : « Envoyé par » / « Déposé par » permet de choisir un perso, ou tous les persos.",
            "La liste des règles indique pour qui vaut chaque règle (« par Brumefer » ou « tous les persos »).",
        },
        changed = {
            "Une règle propre à un perso passe avant la règle « tous les persos » pour le même objet ou la même catégorie. Les règles existantes valent pour tous les persos.",
        },
    },
    {
        version = "0.12.0", date = "14/11/2026",
        added = {
            "Courrier : nouvelles catégories « Objets LQE (vert et +) », « (bleu et +) » et « (épiques) » pour envoyer automatiquement les objets liés quand équipés à un perso (enchanteur, vendeur à l'HV...). Elles marchent aussi pour le dépôt en banque.",
        },
        changed = {
            "Un objet LQE déjà équipé (donc lié) n'est jamais envoyé. Si plusieurs règles LQE existent, la plus exigeante l'emporte : un épique va à la règle « épiques ».",
        },
    },
    {
        version = "0.11.0", date = "14/11/2026",
        added = {
            "Portraits à côté du nom des persos (Résumé, Persos, Inventaire, Métiers, Courrier) : le vrai portrait pour le perso connecté, l'icône de race et de sexe pour les autres.",
            "Options > Apparence : « Portraits des persos » pour revenir aux icônes de classe.",
        },
        changed = {
            "Le sexe de chaque perso est enregistré à la connexion : connecte chaque perso une fois pour avoir la bonne icône.",
        },
    },
    {
        version = "0.10.1", date = "14/11/2026",
        added = {
            "Métiers > Niveaux : le nombre de recettes connues est affiché à côté de chaque métier, par exemple « Cuisine (4 recettes) ».",
            "Options > Général > Combat : « Fermer la fenêtre en combat ». La fenêtre se ferme au début d'un combat ; la mini-fenêtre de la session de farm reste affichée.",
        },
        fixed = {
            "Le bouton « Ouvrir le métier » pouvait empêcher de fermer la fenêtre pendant un combat.",
            "Options : certaines descriptions étaient coupées (par exemple « Auto : celle du j... »).",
        },
    },
    {
        version = "0.10.0", date = "14/11/2026",
        added = {
            "Métiers : clic sur un métier dans l'onglet Niveaux pour ouvrir sa fiche : niveau, recettes connues du perso avec leur couleur (orange, jaune, vert, gris), composants possédés sur tout le compte, coût et bénéfice.",
            "Fiche métier : filtres « Font monter » (recettes orange, jaunes et vertes) et « Possibles » (composants déjà sur le compte), recherche, et bouton + vers la liste de courses.",
            "Fiche métier : bouton « Ouvrir le métier » pour le perso connecté. Pour les autres persos, la date à laquelle leurs recettes ont été lues.",
        },
        changed = {
            "Les couleurs des recettes sont enregistrées à l'ouverture de chaque métier : ouvre-le une fois sur chaque perso pour les voir.",
        },
    },
    {
        version = "0.9.5", date = "14/11/2026",
        changed = {
            "Le nom complet des persos (« Prénom Nom ») est affiché dans tout l'addon : résumé, persos, inventaire, métiers, stats, farm, journal, alertes, infobulles et messages du chat.",
            "Persos : clic droit sur un perso pour corriger son nom complet (comme dans Courrier). Un nom trop long est coupé proprement au lieu de déborder sur les colonnes.",
        },
    },
    {
        version = "0.9.4", date = "14/11/2026",
        fixed = {
            "La barre de défilement ne réagissait pas à la souris : un clic sur la barre amène la liste à cet endroit, et le curseur se fait glisser.",
        },
    },
    {
        version = "0.9.3", date = "14/11/2026",
        added = {
            "Noms en deux parties (« Prénom Nom ») : l'envoi automatique utilise le nom complet de tes persos.",
            "Clic droit sur un perso dans Courrier > Nouvelle règle pour corriger son nom complet si le jeu ne le donne pas.",
            "Commande /wk nom : affiche le nom utilisé pour le courrier.",
        },
        changed = {
            "Une règle écrite avec le prénom seul est envoyée au nom complet du perso du compte, s'il n'y a pas d'ambiguïté.",
            "En cas d'échec d'un envoi, le chat indique le destinataire utilisé et la raison donnée par le jeu.",
        },
        fixed = {
            "/wk envoi ajoute ne gardait que le dernier mot d'un nom en deux parties.",
        },
    },
    {
        version = "0.9.2", date = "14/11/2026",
        added = {
            "Prix : nouvelle source « Les deux ». L'Inventaire affiche le prix HV et le prix marchand côte à côte, et l'infobulle des objets donne les deux prix à l'unité. Les calculs (stocks, richesse, butin, rentabilité, filtre de loot) prennent le meilleur des deux : ce que tu tirerais vraiment de l'objet.",
        },
        changed = {
            "Options > Prix : la description indique ce que fait la source choisie.",
        },
    },
    {
        version = "0.9.1", date = "14/11/2026",
        changed = {
            "Redimensionnement fluide : les pages suivent la souris en direct pendant qu'on agrandit ou réduit la fenêtre (cartes, colonnes des tableaux, tuiles, catégories du loot), et les graphiques sont redessinés au fur et à mesure. Plus besoin de relâcher la souris.",
            "Replier ou déplier le menu redimensionne aussi les pages en direct.",
            "« Notes de patch » devient « Patch notes ».",
            "Patch notes : la section « À venir » est toujours en haut, au-dessus des versions. Pareil dans CHANGELOG.md sur GitHub.",
        },
        fixed = {
            "Sur une grande fenêtre, la ligne d'objectif des Stats s'arrêtait avant le bord du graphique.",
        },
    },
    {
        version = "0.9.0", date = "14/11/2026", restart = true,
        added = {
            "Filtres de loot : profils de ramassage par situation (Tout ramasser, Farm, Donjon, Raid, Or et quêtes seulement…), à créer, dupliquer, renommer et charger d'un clic. Les objets refusés restent sur le corps.",
            "Chaque profil fixe une qualité minimale, une valeur minimale (au prix Auctionator ou marchand), des catégories toujours ramassées et des listes « toujours » et « jamais » (Maj + clic). L'or, les monnaies et les objets de quête sont toujours ramassés, tout comme, si tu le souhaites, les objets de tes règles d'envoi et de dépôt.",
            "Activation automatique d'un profil selon la zone, le type d'instance (donjon, raid, JcJ) ou une session de farm, avec un message dans le chat quand le profil change. Le profil actif apparaît dans la mini-fenêtre de farm.",
            "Liste des derniers objets laissés au sol : un clic en ajoute un à la liste « toujours ». Maj maintenue en ouvrant un butin désactive le filtre pour ce butin. Un bouton désactive le butin automatique du jeu, qui empêche le filtre de choisir.",
            "Fenêtre redimensionnable avec la poignée en bas à droite : les pages se redessinent à la nouvelle taille (tableaux, listes et graphiques s'étirent), et la taille est mémorisée.",
        },
        changed = {
            "Nouvelle disposition : barre latérale groupée (Compte, Économie, Farm, puis Notes de patch et Options), repliable en icônes avec « Réduire le menu ». Le titre de la page et les boutons Scanner et Fermer passent dans l'en-tête du contenu.",
            "Les colonnes des tableaux du Résumé et des Persos suivent la largeur de la fenêtre.",
            "Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.",
        },
    },
    {
        version = "0.8.2", date = "14/11/2026",
        changed = {
            "Ordre des sections des Options : Général, Prix, Alertes, Thèmes, Apparence, À propos. Général s'ouvre par défaut.",
        },
    },
    {
        version = "0.8.1", date = "14/11/2026",
        changed = {
            "Options rangées en sections verticales à gauche : Thème, Apparence, Général (langue, bouton minimap, position de la fenêtre), Prix, Alertes et À propos. La dernière section ouverte est mémorisée.",
            "Les vignettes de thèmes passent sur deux rangées pour rester lisibles.",
            "À propos : bouton pour ouvrir les notes de patch.",
        },
    },
    {
        version = "0.8.0", date = "14/11/2026",
        added = {
            "Rentabilité des fabrications : pour chaque recette, coût des composants, prix de vente de l'objet fabriqué et bénéfice, au prix d'Auctionator (sinon prix marchand). Tri des recettes par nom, bénéfice ou nombre de fabrications possibles ; le détail est dans l'infobulle.",
            "Meilleurs spots de farm : la page Farm classe les zones par or/heure (or ramassé + valeur du butin au prix actuel), avec le nombre de sessions, le temps passé et le meilleur perso. Clique sur un spot pour voir tout le butin récolté dans cette zone.",
            "Thème personnalisé : un 8e thème dont tu choisis les 7 couleurs (fond, bordures, cadre, halo, textes, accent) avec le sélecteur de couleur du jeu, en partant si tu veux du thème actuel.",
        },
        changed = {
            "Le thème, la police, l'arrondi, l'opacité et la langue s'appliquent tout de suite, sans recharger l'interface : la fenêtre, le bouton minimap et la mini-fenêtre de farm sont redessinés.",
            "La carte Historique de la page Farm a deux vues : Sessions et Meilleurs spots.",
        },
    },
    {
        version = "0.7.0", date = "14/11/2026", restart = true,
        added = {
            "Valeur du compte : les stocks (sacs, banques, courrier, bataillon) sont estimés au prix d'Auctionator, ou au prix marchand si Auctionator n'est pas installé ou n'a pas de prix. Le Résumé affiche la valeur des stocks sous l'or du compte.",
            "Nouvelle série « Richesse totale » (or + stocks) dans les Stats, avec son historique.",
            "Inventaire : valeur estimée de chaque ligne et du contenu de l'onglet.",
            "Objectifs : sur l'or, la richesse totale ou un matériau, depuis la page Stats. Ligne pointillée sur le graphique, pourcentage atteint et date estimée au rythme des 7 derniers jours. Les objectifs apparaissent aussi en bandeau sur le Résumé.",
            "Métiers > Recettes : les recettes connues de chaque perso (enregistrées à l'ouverture de la fenêtre de métier), qui peut les fabriquer et combien de fois avec le stock du compte. L'infobulle détaille les composants possédés.",
            "Métiers > Liste de courses : fabrications prévues (+ / -), composants nécessaires, possédés et manquants, coût des manquants. Bouton « Créer la liste Auctionator » pour acheter les composants manquants dans Auctionator.",
            "Options : choix de la source des prix (Auctionator ou marchand).",
        },
        changed = {
            "La session de farm estime la valeur du butin au prix d'Auctionator quand il est disponible.",
            "Les en-têtes en majuscules gardent leurs accents (POSSÉDÉ, COÛT…).",
            "Les flèches du Journal utilisent « » », un symbole que la police du jeu sait afficher.",
            "Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.",
        },
    },
    {
        version = "0.6.1", date = "14/11/2026",
        added = {
            "Inventaire : onglets par personnage dans une colonne à gauche (icône et couleur de classe, nombre d'objets), plus « Tout le compte » et « Banque de bataillon ».",
            "Sur l'onglet d'un personnage, chaque objet indique où il se trouve (sacs, banque, courrier), et l'en-tête résume sacs occupés, dernière visite à la banque et lettres en attente.",
        },
        changed = {
            "L'Inventaire retient le dernier onglet ouvert. La recherche et les filtres Sacs / Banque / Courrier s'appliquent à l'onglet choisi.",
        },
    },
    {
        version = "0.6.0", date = "14/11/2026", restart = true,
        added = {
            "Thèmes : 7 thèmes au choix dans les Options, avec un aperçu de chacun. Coffre-fort (bois et or), Givre (bleu nuit et cyan), Graphite (gris neutre), Héraldique (aux couleurs de ta classe), Faction (bleu et or pour l'Alliance, rouge et fer pour la Horde), Gangrefeu (vert gangrené) et Néant (violet).",
            "Couleur d'accent : en plus des couleurs fixes, « Thème » suit l'accent du thème choisi et « Classe » prend la couleur de classe du perso connecté.",
            "Réglages d'apparence : police (Friz Quadrata ou Arial Narrow), arrondi (fort, moyen ou carré) et opacité du fond de la fenêtre.",
        },
        changed = {
            "Les Options commencent par la carte Thème. Un bouton « Recharger pour appliquer » apparaît quand un réglage demande de recharger l'interface (thème, police, arrondi, opacité, langue).",
            "Les thèmes Héraldique et Faction s'adaptent au perso connecté.",
            "Changer de thème remet l'accent sur celui du thème.",
            "Nouveau fichier : redémarrer complètement le jeu après la mise à jour.",
        },
    },
    {
        version = "0.5.0", date = "14/11/2026", restart = true,
        added = {
            "Règles par catégorie : étoffes, cuirs, métaux et pierres, herbes, éléments, enchantement, gemmes… Une seule règle suffit pour envoyer tout un type de composant. Une règle sur un objet précis reste prioritaire.",
            "Seuil « Garder » : une règle peut garder une quantité dans les sacs (ex. garder 20 potions) et n'envoie ou ne dépose que le surplus, en partageant une pile si besoin.",
            "Page Farm : session de farm avec chrono, pause, or ramassé, nombre d'objets, valeur marchande du butin et or par heure. Le butin est listé avec sa quantité par heure, et chaque session terminée est gardée dans un historique consultable (zone, durée, or/h).",
            "Mini-fenêtre déplaçable pendant une session : chrono, or par heure, nombre d'objets, boutons pause et fin. Commande /wk farm pour démarrer ou terminer.",
            "« Tout prendre » : un bouton dans la boîte de réception du jeu récupère l'or et les objets de toutes les lettres, sauf les contre-remboursements, et s'arrête quand les sacs sont pleins. Option pour le faire automatiquement après les envois. Commande /wk prendre.",
            "Dépôt automatique en banque : à l'ouverture de la banque, les objets ou catégories choisis sont rangés dans la banque du perso ou de bataillon, en complétant les piles existantes.",
            "Onglet Réception : les boîtes aux lettres de tous les persos (lettres, objets, or, expiration).",
            "Journal : dépôts en banque et sessions de farm terminées.",
        },
        changed = {
            "La page Courrier devient « Courrier et banque », avec trois onglets : Envoi, Dépôt banque et Réception.",
            "Nouvelle règle : choix Objet ou Catégorie dans une liste déroulante, et champ « Garder ».",
            "Le butin ne compte pas pendant le courrier, la banque, un marchand, un échange ou l'hôtel des ventes.",
            "Les sommes de moins d'1 po s'affichent en pièces d'argent au lieu de « 0 po ».",
            "Barre du haut plus compacte pour faire de la place à l'onglet Farm ; la loupe est retirée (la recherche reste dans l'Inventaire).",
            "Les anciennes règles d'envoi sont converties automatiquement.",
            "Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour.",
        },
        fixed = {
            "Une session de farm interrompue par un crash ou une déconnexion garde le temps écoulé jusqu'à la dernière activité.",
        },
    },
    {
        version = "0.4.0", date = "14/11/2026", restart = true,
        added = {
            "Page Journal : courriers envoyés, or gagné ou dépensé, progrès de métier et niveaux, regroupés par jour, avec des filtres Tout / Or / Courrier / Métiers. Les variations d'or et les progrès d'un même métier sont regroupés par heure.",
            "Boîte aux lettres : son contenu est lu à l'ouverture (objets, or, nombre de lettres, date d'expiration). Les objets envoyés par l'envoi automatique à un autre perso du compte sont comptés tout de suite dans sa boîte.",
            "Les objets du courrier comptent dans les totaux, les infobulles et les stats. Nouveau filtre « Courrier » dans l'Inventaire.",
            "Alertes : banque d'un perso (niveau 10+) jamais ouverte ou pas vue depuis 7 jours, courrier qui expire dans moins de 3 jours. Rappel dans le chat à la connexion et colonnes en orange. Seuils réglables dans les Options.",
            "Page Persos : nouvelles colonnes Banque (dernière visite) et Courrier (lettres en attente et jours avant expiration).",
            "Stats : vue « Par perso » pour les matériaux, avec une courbe par personnage en couleur de classe et une légende.",
            "Version anglaise de l'interface et des messages du chat. Choix de la langue dans les Options : Auto (celle du jeu), Français ou English.",
        },
        changed = {
            "Options : la page défile et regroupe Apparence, Langue, Bouton minimap, Alertes et À propos.",
            "Les commandes du chat existent aussi en anglais (/wk help, gold, chars, find, prof, mail add / del).",
            "Nouveaux fichiers : redémarrer complètement le jeu après la mise à jour (un /reload ne suffit pas).",
        },
    },
    {
        version = "0.3.1", date = "14/11/2026",
        added = {
            "Page « Notes de patch » : toutes les versions avec leurs ajouts, modifications et corrections, plus ce qui est prévu.",
            "Icône « Notes de patch » dans la barre du haut et commande /wk notes.",
            "Message dans le chat à la première connexion après une mise à jour.",
            "Fichier CHANGELOG.md sur GitHub, généré à partir des mêmes notes.",
        },
    },
    {
        version = "0.3.0", date = "14/11/2026",
        added = {
            "Page Résumé : or du compte en grand, variation sur 7 jours et 4 chiffres clés (personnages, temps de jeu, règles de courrier, objets à envoyer).",
            "Courbe d'évolution de l'or sur 7 j, 30 j, 90 j ou 1 an, avec repère au survol (date et montant).",
            "Tableau des personnages avec le gain ou la perte sur 7 jours et une mini-courbe de tendance.",
            "Boutons ronds dans la barre du haut : rechercher un objet, scanner le personnage, fermer.",
        },
        changed = {
            "Nouveau design « Registre » aux couleurs « Coffre-fort » : bois sombre, parchemin et or, double bordure dorée et halo chaud.",
            "Navigation en pilules dans la barre du haut : la barre latérale disparaît.",
            "Titre « Warband Keeper » dans la police médiévale du jeu, liserés dorés sur les cartes.",
            "Page Stats : une courbe remplace les barres, et l'échelle s'adapte aux valeurs pour rendre les variations visibles.",
            "Couleur d'accent par défaut : or. Nouveau choix : cuivre.",
        },
        fixed = {
            "Les sous-titres des pages s'affichaient au milieu de la page au lieu d'à côté du titre.",
            "Positionnement corrigé dans l'inventaire, les séries des stats, les tuiles et les descriptions des réglages.",
            "Le bouton « Recentrer la fenêtre » chevauchait l'interrupteur du bouton minimap dans les Options.",
        },
    },
    {
        version = "0.2.4", date = "14/11/2026",
        changed = {
            "Nouveau logo : l'étendard de bataillon (drapeau avec un W), sur le bouton minimap et dans la fenêtre.",
        },
    },
    {
        version = "0.2.3", date = "14/11/2026",
        changed = {
            "Les quantités par personnage ne s'ajoutent plus aux infobulles de comparaison d'équipement (plus de doublons).",
            "Noms des personnages en couleur de classe dans l'infobulle des objets, sans le royaume.",
        },
        fixed = {
            "Erreur au survol d'un objet (« attempt to call a nil value » dans Inventory.lua) : l'objet est maintenant identifié avec l'API d'infobulles moderne.",
        },
    },
    {
        version = "0.2.2", date = "14/11/2026",
        fixed = {
            "Carte « Ce personnage » : le nom complet Nom-Royaume sortait de la carte. Le nom s'affiche seul et le royaume passe sur sa propre ligne.",
            "Page Personnages : un royaume au nom long pouvait chevaucher la colonne Niveau.",
        },
    },
    {
        version = "0.2.1", date = "14/11/2026",
        added = {
            "Banque de bataillon : lue à l'ouverture de la banque, visible dans l'inventaire (« Bataillon »), les infobulles et les totaux.",
            "Banque du personnage à onglets prise en charge.",
            "Le sac de composants est compté avec les sacs.",
        },
        changed = {
            "Métiers lus avec l'API moderne du jeu.",
        },
        fixed = {
            "Erreur sur la page Inventaire (« attempt to call a nil value » dans Theme.lua) : GetItemInfo n'existe plus sur ce client, remplacé par C_Item.GetItemInfo.",
            "Insertion des liens d'objets (Maj + clic) compatible avec le nouveau chat.",
        },
    },
    {
        version = "0.2.0", date = "14/11/2026",
        added = {
            "Fenêtre principale aux coins arrondis, avec les pages Vue d'ensemble, Personnages, Inventaire, Métiers, Statistiques, Courrier automatique et Options.",
            "Bouton minimap rond et déplaçable : clic gauche pour ouvrir, clic droit pour les options.",
            "Ouverture depuis le menu des addons du jeu.",
            "Couleur d'accent au choix et échelle de la fenêtre réglable.",
            "Recherche d'objets dans tous les sacs et banques, avec filtre Tout / Sacs / Banque.",
            "Suivi de n'importe quel matériau dans les statistiques (Maj + clic sur l'objet).",
            "Ajout des règles de courrier depuis la fenêtre, avec choix rapide du destinataire.",
        },
        changed = {
            "/wk ouvre la fenêtre. /wk aide affiche les commandes du chat.",
        },
        fixed = {
            "Conflit de nom entre l'interrupteur et l'ouverture de la fenêtre (trouvé avant la publication).",
        },
    },
    {
        version = "0.1.0", date = "14/11/2026",
        added = {
            "Enregistrement de chaque personnage : or, niveau, classe, temps de jeu.",
            "Contenu des sacs et de la banque de tous les personnages, avec les quantités dans l'infobulle des objets.",
            "Métiers et niveaux de compétence.",
            "Historique de l'or et des matériaux suivis pour les statistiques.",
            "Envoi automatique à l'ouverture de la boîte aux lettres : chaque objet assigné part vers son personnage, 12 pièces jointes par courrier.",
            "Commandes du chat : /wk or, persos, cherche, metiers, stats, envoi.",
        },
    },
}

-- Ce qui est prévu (pas encore commencé). Retiré d'ici quand c'est livré.
-- Onglet « À venir » des Patch notes, par priorité ou par thème (WK.RoadmapThemes) : un titre court et une phrase.
WK.RoadmapThemes = {
    { key = "ui", label = "Interface", color = "accent" },
    { key = "map", label = "Carte et voyage", color = "positive" },
    { key = "eco", label = "Inventaire et économie", color = "gold" },
    { key = "prof", label = "Métiers", color = "warning" },
    { key = "char", label = "Personnages", color = "info" },
    { key = "class", label = "Classes et combat", color = "negative" },
    { key = "dung", label = "Donjons et quêtes", color = "muted" },
    { key = "rel", label = "Fiabilité", color = "rule" },
    { key = "client", label = "Client PC", color = "plan" },
    { key = "guild", label = "Guilde et partage", color = "mint" },
}
-- Priorité d'une idée (pastille de l'onglet « À venir », tri) : 1 haute, 2 moyenne, 3 basse
WK.RoadmapPrio = {
    { label = "Haute", color = "negative" },
    { label = "Moyenne", color = "warning" },
    { label = "Basse", color = "muted" },
}
WK.Roadmap = {
    { prio = 3, theme = "class", title = "Salut choisi par classe", text = "Cocher dans le tableau des bénédictions quelles classes reçoivent le Salut, et revoir les priorités une fois Puissance et Salut collectif vérifiés en jeu." },
    { prio = 2, theme = "ui", title = "Recherche globale", text = "Dans tout l'addon : persos, objets, recettes, quêtes et notes de carte." },
    { prio = 2, theme = "ui", title = "Mini-fenêtre « À faire »", text = "Déplaçable, sans ouvrir la fenêtre principale." },
    { prio = 3, theme = "ui", title = "Idées d'Utilities en attente", text = "Macros intelligentes, jeux de barres d'action, pistages de classe et de race, inspection du groupe." },
    { prio = 3, theme = "map", title = "Notes de carte partagées", text = "Avec le groupe ou la guilde (ceux qui ont Warband Keeper), au choix note par note." },
    { prio = 3, theme = "map", title = "Ping de groupe", text = "Repère éphémère avec annotation, point de rendez-vous du groupe, marqueurs de raid annoncés en donjon." },
    { prio = 3, theme = "map", title = "Trajets qui suivent le terrain", text = "Grille de marche tirée des fichiers du jeu (chargée seulement au guidage) pour contourner falaises et lacs au lieu de couper tout droit." },
    { prio = 2, theme = "map", title = "Chemins appris partagés", text = "Les tronçons appris en jouant, mis en commun entre les persos du compte, puis avec la guilde." },
    { prio = 2, theme = "map", title = "« Prends le bateau »", text = "Sur un trajet qui passe par un bateau, la flèche et l'épingle le disent au lieu de viser le quai d'arrivée." },
    { prio = 2, theme = "eco", title = "Rangement, suite", text = "Place libre par perso et ce qui en libèrerait le plus, assistant à la banque (dépôts, piles à réunir) et chez le marchand." },
    { prio = 2, theme = "eco", title = "Monnaies du jeu", text = "Un panneau des monnaies (insignes, jetons, marques…) par perso et pour tout le compte, avec ce qu'elles permettent d'acheter." },
    { prio = 2, theme = "eco", title = "Prix moyen de vente", text = "Ce que tu vends vraiment chaque objet (d'après tes ventes HV), comparé au prix relevé par le scan." },
    { prio = 2, theme = "prof", title = "Qui peut fabriquer… ?", text = "Recherche d'une recette sur tous les persos." },
    { prio = 3, theme = "prof", title = "Annonce de métier", text = "Une phrase prête pour la guilde ou le commerce, avec le lien du métier et tes meilleures recettes." },
    { prio = 3, theme = "char", title = "Expérience, suite", text = "Temps passé à chaque niveau par perso, barre de réputation au même endroit, barre fine sous le micro menu." },
    { prio = 3, theme = "char", title = "Feu de camp, suite", text = "Ce qu'il manque pour un camp complet, et le lien avec le repos (tente, sac de couchage)." },
    { prio = 3, theme = "char", title = "Feu de camp, plus tard", text = "Camps des autres joueurs lus dans Happy Camper s'il est installé, annonce de ton camp, endroits où tu as campé." },
    { prio = 3, theme = "class", title = "Réticule au centre", text = "Pour le combat à la souris, d'une autre couleur hors de portée." },
    { prio = 3, theme = "class", title = "Gain d'un rang", text = "Dans l'infobulle d'un sort : ce que le rang suivant ajoute (dégâts, soins…)." },
    { prio = 3, theme = "class", title = "Grimoires de démons", text = "Démoniste : rangs connus par chaque démon, marques chez le vendeur (appris, apprenable, plus tard)." },
    { prio = 3, theme = "class", title = "Curseur retrouvé", text = "Secouer la souris ou un raccourci : un grand anneau se resserre sur lui." },
    { prio = 3, theme = "dung", title = "Raids de Classic", text = "Cœur du Magma, Zul'Gurub… si WoW Forever les ouvre." },
    { prio = 2, theme = "prof", title = "Mise en valeur à l'approche", text = "Herbes, filons, objets de quête, coffres, bouchon et corps à piller s'allument quand tu approches ; couleur selon ta chance de monter, grisé si compétence trop basse." },
    { prio = 2, theme = "map", title = "Couches de serveur", text = "La couche où tu es (lue sur les PNJ), les couches vues dans la zone, demande de changement sur le canal « layer » et invitation acceptée toute seule." },
    { prio = 3, theme = "map", title = "Carte, suite", text = "Niveau et pêche de la zone au survol, flèches de sortie, zones de quête teintées, carte en fenêtre agrandissable." },
    { prio = 3, theme = "dung", title = "Quêtes, petits plus", text = "Récompenses signalées même en manuel (amélioration, prix de vente), « Tout prendre » sur un PNJ, quêtes d'un objet dans son infobulle, niveau dans les liens du chat, progression annoncée au groupe." },
    { prio = 1, theme = "eco", title = "Camelote", text = "Camelote marquée à la main ou par règles, vendue au marchand avec les objets gris." },
    { prio = 3, theme = "ui", title = "Infobulles, suite", text = "Crochetage requis d'un coffret, contenu des caisses, objet d'un ordre d'artisan, efficacité en mana des sorts (meilleur rang), capacités et armure d'un monstre, familier qu'il donne au chasseur." },
    { prio = 3, theme = "class", title = "Aides de combat", text = "Chrono et alerte de combat, barre d'incantation du focus (interruption prête), mana des soigneurs, familier absent ou passif, rappel du camouflage, recharge au curseur, réglage de la file des sorts." },
    { prio = 3, theme = "char", title = "Groupe", text = "Historique des joueurs croisés avec tes notes, boutons d'invitation, butin libre quand tu mènes, merci pour un buff, XP des membres du groupe." },
    { prio = 3, theme = "ui", title = "Chat et confort", text = "Filtre du spam en Commerce, zone et niveau de qui parle, /copy et numéros dans les infobulles, fenêtre des réglages cachés du jeu, masquer le fouillis." },
    { prio = 3, theme = "ui", title = "Mini-jeux en vol", text = "Quiz, mot du jour et jeu de visée pendant les vols." },
    { prio = 2, theme = "dung", title = "Quêtes, suite", text = "« À faire maintenant » autour de toi, chaînes de quêtes, quêtes qui donnent une recette, liens avec LFG et Métiers." },
    { prio = 2, theme = "rel", title = "Diagnostic /wk diag", text = "Vérifie que les fonctions du jeu utilisées existent sur WoW Forever, ce qui est actif ou coupé, et la taille des sauvegardes." },
    { prio = 2, theme = "rel", title = "Notes de version allégées en jeu", text = "Seuls les derniers jours chargés en jeu ; tout l'historique reste dans le client et le CHANGELOG." },
    { prio = 3, theme = "client", title = "Sauvegardes synchronisées", text = "Réglages et données partagés entre deux PC par un dossier cloud (OneDrive, Dropbox), avec un historique pour revenir en arrière." },
    { prio = 2, theme = "char", title = "Objectifs par perso", text = "Or, niveau, palier de métier, liste BiS complète : progression et estimation (« niveau 40 dans env. 6 h au rythme actuel »)." },
    { prio = 3, theme = "char", title = "Comparer deux persos", text = "Équipement, stats et métiers côte à côte." },
    { prio = 3, theme = "char", title = "Carte de la Warband", text = "Résumé de tes persos (niveaux, métiers, or) prêt à coller dans le chat de guilde ou sur Discord." },
    { prio = 2, theme = "guild", title = "Prix HV partagés en guilde", text = "Les prix relevés par les membres qui ont l'addon : des prix à jour sans scanner soi-même." },
    { prio = 3, theme = "guild", title = "Rares signalés à la guilde", text = "Un rare mort, et sur quelle couche, prévient les membres qui ont l'addon." },
    { prio = 3, theme = "guild", title = "« Qui peut fabriquer… ? » en guilde", text = "La recherche de recette étendue aux membres de la guilde qui ont l'addon." },
    { prio = 3, theme = "ui", title = "Taille du texte", text = "Taille de police globale de la fenêtre, en plus de l'échelle." },
    { prio = 3, theme = "ui", title = "Mode daltonien", text = "Couleurs de sens (vert, rouge, ambre) remplacées par des teintes distinctes, avec des formes en plus." },
    { prio = 3, theme = "ui", title = "Raccourcis vers les pages", text = "Une touche pour ouvrir directement l'HV, le Rangement, les Donjons…" },
}


-- Message au premier lancement d'une nouvelle version.
WK:On("PLAYER_LOGIN", function()
    local s = WK.DB.global.settings
    if s.lastSeenVersion ~= WK.version then
        if s.lastSeenVersion then
            WK:Print(string.format(WK.L.UPDATED, WK.version))
        end
        s.lastSeenVersion = WK.version
    end
end)
