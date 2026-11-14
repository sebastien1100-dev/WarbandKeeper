local ADDON_NAME, WK = ...

-- English. keys = chat messages, text = interface (key = French text).
WK.Locales.enUS.keys = {
    LOADED          = "loaded. Type |cffffd100/wk|r to open the window, |cffffd100/wk help|r for commands.",
    UPDATED         = "updated to |cffe0bd72v%s|r. Type |cffffd100/wk notes|r to see what's new.",
    HELP_TITLE      = "Commands:",
    HELP_OPEN       = "/wk               - Open / close the window (/wk help: this help)",
    HELP_NOTES      = "/wk notes         - Patch notes",
    HELP_GOLD       = "/wk gold          - Gold of every character",
    HELP_CHARS      = "/wk chars         - Character list (level, played time)",
    HELP_FIND       = "/wk find <name>   - Where an item is (bags / bank / mail)",
    HELP_PROF       = "/wk prof          - Professions of every character",
    HELP_STATS      = "/wk stats [days]  - Gold history (default: 7 days)",
    HELP_MAIL_ADD   = "/wk mail add <itemID|link> <Char> - Assign an item to a character",
    HELP_MAIL_DEL   = "/wk mail del <itemID|link>        - Remove a rule",
    HELP_MAIL_LIST  = "/wk mail list                     - List the rules",
    HELP_MAIL_TOG   = "/wk mail on|off                   - Turn auto-send on/off",
    TOTAL           = "Total",
    NOT_FOUND       = "No item found for",
    BAGS            = "bags",
    BANK            = "bank",
    MAILBOX         = "mail",
    WARBANK         = "Warband bank",
    MAIL_SENDING    = "Sending %d item(s) to %s...",
    MAIL_DONE       = "Auto-send finished.",
    MAIL_RULE_ADD   = "Rule added: %s -> %s",
    MAIL_RULE_DEL   = "Rule removed: %s",
    MAIL_NO_RULES   = "No send rules.",
    MAIL_ON         = "Auto-send enabled.",
    MAIL_OFF        = "Auto-send disabled.",
    MAIL_SKIP_SELF  = "skipped (this character)",
    MAIL_ERROR      = "Send error, queue cleared.",
    STATS_NO_DATA   = "Not enough data yet.",
}

WK.Locales.enUS.text = {
    -- Général
    ["po"] = "g", ["pa"] = "s", ["pc"] = "c",
    ["%dj %dh %dm"] = "%dd %dh %dm", ["%dh %dm"] = "%dh %dm",
    ["à l'instant"] = "just now", ["il y a %d h"] = "%d h ago", ["il y a %d j"] = "%d d ago",
    ["maintenant"] = "now", ["jamais"] = "never", ["vide"] = "empty", ["ici"] = "here",
    ["connecté"] = "online", ["Objet #"] = "Item #", ["%d j"] = "%d d",
    ["Registre du compte"] = "Account ledger", ["Fermer"] = "Close",
    ["Scanner ce personnage (sacs, or, métiers)"] = "Scan this character (bags, gold, professions)",
    ["Chercher un objet"] = "Find an item",
    ["Or du compte"] = "Account gold",
    ["|cffffffffClic gauche|r : ouvrir / fermer"] = "|cffffffffLeft-click|r: open / close",
    ["|cffffffffClic droit|r : options"] = "|cffffffffRight-click|r: options",
    ["|cffffffffGlisser|r : déplacer le bouton"] = "|cffffffffDrag|r: move the button",
    ["7 j"] = "7 d", ["30 j"] = "30 d", ["90 j"] = "90 d", ["1 an"] = "1 yr",

    -- Navigation et titres
    ["Résumé"] = "Summary", ["Persos"] = "Chars", ["Inventaire"] = "Inventory", ["Métiers"] = "Professions",
    ["Stats"] = "Stats", ["Journal"] = "Log", ["Courrier"] = "Mail", ["Options"] = "Options",
    ["Personnages"] = "Characters", ["Statistiques"] = "Statistics", ["Courrier automatique"] = "Auto mail",
    ["Notes de patch"] = "Patch notes",

    -- Résumé
    ["OR DU COMPTE"] = "ACCOUNT GOLD", ["Temps de jeu"] = "Played time", ["Règles courrier"] = "Mail rules",
    ["À envoyer"] = "To send", ["Évolution de l'or"] = "Gold history", ["sur 7 jours"] = "over 7 days",
    ["L'historique se remplit au fil de tes sessions."] = "History fills up as you play.",
    ["Personnage"] = "Character", ["Niv."] = "Lvl", ["Or"] = "Gold", ["7 jours"] = "7 days",
    ["Tendance"] = "Trend", ["Sacs"] = "Bags", ["Vu"] = "Seen",

    -- Personnages
    ["Tous tes personnages enregistrés. Maj + clic sur la corbeille pour en oublier un."] =
        "All your recorded characters. Shift + click the bin to forget one.",
    ["Niveau"] = "Level", ["Banque"] = "Bank", ["Maj + clic : oublier ce personnage"] = "Shift + click: forget this character",
    ["%d lettres"] = "%d letters", ["%d lettre"] = "%d letter",

    -- Inventaire
    ["Sacs et banques de tous tes personnages. Maj + clic sur une ligne pour lier l'objet."] =
        "Bags and banks of all your characters. Shift + click a row to link the item.",
    ["Rechercher un objet..."] = "Search for an item...", ["Tout"] = "All", ["Bataillon"] = "Warband",
    ["%d objets (affichage limité à %d, affine ta recherche)"] = "%d items (showing %d, refine your search)",
    ["%d objets"] = "%d items", ["%d objet"] = "%d item",

    -- Métiers
    ["Niveaux de compétence de chaque personnage."] = "Skill levels of every character.",
    ["Aucun métier enregistré"] = "No profession recorded",

    -- Stats
    ["Évolution de l'or du compte et des matériaux suivis."] = "Account gold and tracked materials over time.",
    ["Séries"] = "Series", ["Maj+clic objet / ID"] = "Shift+click item / ID",
    ["Suivre cet objet dans les statistiques"] = "Track this item in statistics", ["Ne plus suivre"] = "Stop tracking",
    ["Compte"] = "Account", ["Par perso"] = "Per char", ["règle d'envoi"] = "mail rule",
    ["Pas encore assez de données : reviens après quelques sessions de jeu."] = "Not enough data yet: come back after a few play sessions.",

    -- Journal
    ["Ce qui s'est passé sur ton compte : or, courriers envoyés, métiers et niveaux."] =
        "What happened on your account: gold, mail sent, professions and levels.",
    ["Rien pour l'instant : joue un peu, tout s'inscrira ici."] = "Nothing yet: play a bit and everything will show up here.",
    ["or gagné"] = "gold earned", ["or dépensé"] = "gold spent", ["%d courriers envoyés"] = "%d letters sent",
    ["%d courrier envoyé"] = "%d letter sent", ["progrès de métier"] = "profession progress",
    ["%s atteint le niveau %d"] = "%s reached level %d", ["niveau"] = "level",
    ["Aujourd'hui"] = "Today", ["Hier"] = "Yesterday", ["%d événements"] = "%d events", ["%d événement"] = "%d event",

    -- Courrier
    ["Assigne tes matériaux de farm à un personnage : ils partent tout seuls à la boîte aux lettres."] =
        "Assign your farmed materials to a character: they are sent automatically at the mailbox.",
    ["Envoi automatique"] = "Auto-send",
    ["À l'ouverture de la boîte aux lettres, les objets assignés quittent les sacs vers leur destinataire (12 par courrier)."] =
        "When you open a mailbox, assigned items leave your bags for their recipient (12 per letter).",
    ["Nouvelle règle"] = "New rule", ["Maj + clic sur un objet, ou son ID"] = "Shift + click an item, or its ID",
    ["Destinataire"] = "Recipient", ["Ajouter"] = "Add",
    ["Indique un objet (Maj + clic) et un destinataire."] = "Enter an item (Shift + click) and a recipient.",
    ["Mes persos :"] = "My chars:", ["Règles"] = "Rules", ["Aucune règle pour l'instant."] = "No rules yet.",
    ["Supprimer la règle"] = "Delete rule", ["c'est ce personnage"] = "this character",
    ["x%d dans les sacs"] = "x%d in bags",

    -- Alertes
    ["banque jamais ouverte"] = "bank never opened", ["banque vue il y a %d j"] = "bank seen %d d ago",
    ["courrier expire aujourd'hui"] = "mail expires today", ["courrier expire dans %d j"] = "mail expires in %d d",
    ["%d alerte(s) :"] = "%d alert(s):",

    -- Notes de patch
    ["AJOUTS"] = "ADDED", ["MODIFICATIONS"] = "CHANGED", ["CORRECTIONS"] = "FIXED", ["À venir"] = "Coming next",
    ["version installée"] = "installed version", ["prévu, pas encore commencé"] = "planned, not started yet",
    ["Tout ce qui a été ajouté, modifié et corrigé, version par version."] =
        "Everything added, changed and fixed, version by version (notes in French).",

    -- Options
    ["Apparence, langue, bouton minimap et alertes."] = "Appearance, language, minimap button and alerts.",
    ["Apparence"] = "Appearance", ["Couleur d'accent"] = "Accent colour",
    ["Boutons, interrupteurs, barres et graphiques."] = "Buttons, toggles, bars and charts.",
    ["Échelle de la fenêtre"] = "Window scale", ["Appliquée au relâchement du curseur."] = "Applied when you release the slider.",
    ["Auto"] = "Auto", ["Recharger"] = "Reload", ["Langue"] = "Language",
    ["Auto : celle du jeu. Le changement demande de recharger l'interface."] = "Auto: the game's language. Changing it requires a UI reload.",
    ["Bouton minimap"] = "Minimap button", ["Afficher le bouton"] = "Show the button",
    ["Clic gauche : ouvrir. Clic droit : options. Glisser pour le déplacer."] = "Left-click: open. Right-click: options. Drag to move it.",
    ["Recentrer"] = "Recenter", ["Position de la fenêtre"] = "Window position",
    ["Alertes"] = "Alerts", ["Activer les alertes"] = "Enable alerts",
    ["Rappel dans le chat à la connexion, et colonnes en orange dans la page Persos."] =
        "Chat reminder at login, and orange columns on the Chars page.",
    ["Banque pas vue depuis"] = "Bank not seen for",
    ["Alerte quand la banque d'un perso (niveau 10+) n'a pas été ouverte depuis ce nombre de jours."] =
        "Alert when a character's bank (level 10+) hasn't been opened for this many days.",
    ["Courrier qui expire"] = "Expiring mail",
    ["Alerte quand un courrier expire dans moins de ce nombre de jours."] = "Alert when mail expires in less than this many days.",
    ["À propos"] = "About",
    ["Commandes : |cffffffff/wk|r ouvre cette fenêtre, |cffffffff/wk aide|r liste les commandes du chat."] =
        "Commands: |cffffffff/wk|r opens this window, |cffffffff/wk help|r lists the chat commands.",
    ["Connecte-toi une fois sur chaque personnage et ouvre sa banque pour qu'il soit enregistré."] =
        "Log in once on each character and open their bank so they get recorded.",

    -- Chat
    ["Évolution sur %d jours : %s"] = "Change over %d days: %s",
}
