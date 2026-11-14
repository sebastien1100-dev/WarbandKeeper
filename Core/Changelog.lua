local ADDON_NAME, WK = ...

-- Notes de patch : source unique, affichée en jeu (page « Notes de patch »)
-- et convertie en CHANGELOG.md par tools/gen_changelog.py.
-- Pour chaque version : added = ajouts, changed = modifications, fixed = corrections.
-- La plus récente en premier.
WK.Changelog = {
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
        version = "0.9.0", date = "14/11/2026",
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
        version = "0.7.0", date = "14/11/2026",
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
        version = "0.6.0", date = "14/11/2026",
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
        version = "0.5.0", date = "14/11/2026",
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
        version = "0.4.0", date = "14/11/2026",
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
    "Guides de montée des autres métiers (Couture, Forge, Alchimie, Enchantement, Ingénierie) d'après les guides WoW Forever.",
    "Conseil de métier : la recette orange ou jaune la moins chère parmi celles que le perso connaît.",
    "Recherche « Qui peut fabriquer… ? » sur tous les persos.",
    "Options par classe : par exemple, pour les chasseurs, le suivi des flèches et balles avec une alerte quand il en reste peu.",
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
