local ADDON_NAME, WK = ...

-- Notes de patch : source unique, affichée en jeu (page « Notes de patch »)
-- et convertie en CHANGELOG.md par tools/gen_changelog.py.
-- Pour chaque version : added = ajouts, changed = modifications, fixed = corrections.
-- La plus récente en premier.
WK.Changelog = {
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
