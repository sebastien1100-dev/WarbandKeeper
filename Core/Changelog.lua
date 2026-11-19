local ADDON_NAME, WK = ...

-- Notes de patch : source unique, affichée en jeu (page « Notes de patch »)
-- et convertie en CHANGELOG.md par tools/gen_changelog.py.
-- Pour chaque version : added = ajouts, changed = modifications, fixed = corrections ;
-- restart = true quand il faut redémarrer complètement le jeu (nouveau fichier .lua, texture, .toc
-- modifié) : sinon un /reload suffit. Affiché en jeu, dans CHANGELOG.md et dans les Releases.
-- La plus récente en premier.
WK.Changelog = {
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
WK.Roadmap = {
    "Idées d'Utilities (Naowh) encore en attente : macros intelligentes, jeux de barres d'action, pistages de classe et de race, inspection du groupe.",
    "Rangement, suite : place libre par perso avec ce qui libèrerait le plus de cases, assistant à la banque (dépôts, piles à réunir) et chez le marchand.",
    "Expérience, suite : historique des niveaux (temps passé à chaque niveau, par perso), barre de réputation suivie au même endroit, variante fine de la barre collée sous le micro menu.",
    "Feu de camp, suite : ce qu'il manque pour un camp complet (objets que tes persos présents pourraient poser, feu qui accepte plus d'objets) et lien avec le repos (tente, sac de couchage) dans la section Expérience.",
    "Feu de camp, plus tard : camps des autres joueurs lus dans Happy Camper s'il est installé (lecture seule, source citée), bouton pour annoncer ton camp dans le chat, historique des endroits où tu as campé.",
    "Notes de carte, suite : les partager avec le groupe ou la guilde (ceux qui ont Warband Keeper), au choix note par note.",
    "Recherche globale dans tout l'addon (persos, objets, recettes, quêtes, notes de carte).",
    "Carte, suite des notes : ping partagé avec le groupe (repère éphémère avec annotation), point de rendez-vous du groupe, marqueurs de raid annoncés en donjon.",
    "Bénédictions du paladin (QoL > Classes > Paladin) : tableau du groupe (bénédiction par classe, temps restant, qui en manque), panneau de lancement (un bouton par classe, répartition entre paladins qui ont Warband Keeper) et rappels.",
    "Curseur : réticule au centre de l'écran (combat à la souris), avec couleur hors de portée.",
    "Curseur : le retrouver d'un coup (secouer la souris ou un raccourci : grand anneau qui se resserre sur lui).",
    "Navigation : sur un trajet qui passe par un bateau du même continent, la flèche et l'épingle disent « prends le bateau » au lieu de viser le quai d'arrivée ; masquer aussi le repère du jeu sur la minicarte si le client le permet.",
    "Donjons : les raids de Classic (Cœur du Magma, Zul'Gurub…) si WoW Forever les ouvre.",
    "Quêtes, suite : « À faire maintenant » (quêtes dispo autour de toi), vue d'une chaîne de quêtes, quêtes qui donnent une recette, liens avec LFG et Métiers.",
    "Prix moyen de vente : ce que tu vends vraiment chaque objet (d'après tes ventes HV), comparé au prix relevé par le scan.",
    "Mini-fenêtre « À faire » déplaçable, sans ouvrir la fenêtre principale.",
    "Recherche « Qui peut fabriquer… ? » sur tous les persos.",
    "Annonce de métier : une phrase prête pour la guilde ou le commerce, avec le lien du métier et tes meilleures recettes.",
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
