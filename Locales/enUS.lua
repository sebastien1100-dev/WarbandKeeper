local ADDON_NAME, WK = ...

-- English. keys = chat messages, text = interface (key = French text).
WK.Locales.enUS.keys = {
    LOADED          = "loaded. Type |cffffd100/wk|r to open the window, |cffffd100/wk help|r for commands.",
    UPDATED         = "updated to |cffe0bd72v%s|r. Type |cffffd100/wk notes|r to see what's new.",
    HELP_TITLE      = "Commands:",
    HELP_OPEN       = "/wk               - Open / close the window (/wk help: this help)",
    HELP_NOTES      = "/wk notes         - Patch notes",
    HELP_FARM       = "/wk farm          - Start / stop a farming session",
    HELP_TAKE       = "/wk take          - Take all mail (mailbox open)",
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


    -- Farm
    ["Farm"] = "Farm", ["Session de farm"] = "Farming session",
    ["Chrono, or ramassé, butin et or par heure. Les échanges, achats et le courrier ne comptent pas."] =
        "Timer, gold looted, loot and gold per hour. Trades, purchases and mail don't count.",
    ["Démarrer"] = "Start", ["Pause"] = "Pause", ["Terminer"] = "Stop", ["Reprendre"] = "Resume",
    ["Or ramassé"] = "Gold looted", ["Or / heure"] = "Gold / hour", ["Objets"] = "Items", ["objets"] = "items",
    ["Valeur marchande"] = "Vendor value", ["Mini-fenêtre pendant la session"] = "Mini window during the session",
    ["Valeur marchande : prix de vente aux PNJ du butin."] = "Vendor value: what the loot sells for to NPCs.",
    ["Butin de la session"] = "Session loot", ["Butin du %s"] = "Loot of %s", ["Sessions précédentes"] = "Previous sessions",
    ["Aucune session terminée."] = "No finished session.", ["En pause"] = "Paused", ["En cours"] = "Running",
    ["Aucune session"] = "No session", ["Lance une session avant de partir farmer."] = "Start a session before you go farming.",
    ["%d / h"] = "%d / h", ["/h"] = "/h", ["Rien ramassé pour l'instant."] = "Nothing looted yet.",
    ["Démarre une session pour suivre ton butin."] = "Start a session to track your loot.",
    ["Terminer la session"] = "Stop the session", ["Pause / reprendre"] = "Pause / resume", ["Ouvrir la page Farm"] = "Open the Farm page",
    ["Session de farm démarrée."] = "Farming session started.",
    ["Session terminée : %s, %s, %d objet(s)."] = "Session finished: %s, %s, %d item(s).",
    ["%s : session à %s, %s, %d objet(s)"] = "%s: session in %s, %s, %d item(s)", ["session de farm · %s"] = "farming session · %s",

    -- Courrier et banque
    ["Courrier et banque"] = "Mail and bank",
    ["Envoi du farm à tes persos, dépôt en banque et récupération du courrier."] = "Send your farm to your chars, bank deposits and mail collection.",
    ["Envoi"] = "Send", ["Dépôt banque"] = "Bank deposit", ["Réception"] = "Receive",
    ["Banque du perso"] = "Character bank", ["Banque de bataillon"] = "Warband bank", ["banque de bataillon"] = "warband bank", ["banque"] = "bank",
    ["Dépôt automatique"] = "Auto-deposit",
    ["À l'ouverture de la banque, les objets assignés sont rangés dans la banque du perso ou de bataillon."] =
        "When you open the bank, assigned items are stored in the character or warband bank.",
    ["Objet"] = "Item", ["Catégorie"] = "Category", ["catégorie"] = "category", ["Garder"] = "Keep", ["garder"] = "keep",
    ["garder %d"] = "keep %d", ["Quantité à garder dans les sacs"] = "Amount to keep in bags",
    ["Indique un objet (Maj + clic)."] = "Enter an item (Shift + click).",
    ["Tout prendre automatiquement"] = "Take all automatically",
    ["À l'ouverture de la boîte aux lettres, après les envois : récupère l'or et les objets (sauf contre-remboursement), et s'arrête si les sacs sont pleins."] =
        "When you open the mailbox, after sending: takes gold and items (except COD), and stops when bags are full.",
    ["Un bouton « Tout prendre » est aussi ajouté dans la boîte de réception du jeu."] = "A \"Take all\" button is also added to the game's inbox.",
    ["Boîtes aux lettres du compte"] = "Account mailboxes", ["%d objet(s)"] = "%d item(s)", ["expire dans %d j"] = "expires in %d d",
    ["Tout prendre"] = "Take all", ["Récupéré : "] = "Collected: ", ["Récupération..."] = "Collecting...",
    ["Sacs pleins : récupération arrêtée."] = "Bags full: collection stopped.",
    ["Récupère l'or et les objets de toutes les lettres (sauf contre-remboursement)."] = "Takes gold and items from every letter (except COD).",
    ["Déposé : "] = "Deposited: ", ["Banque de bataillon pleine : dépôt incomplet."] = "Warband bank full: deposit incomplete.",
    ["Banque pleine : dépôt incomplet."] = "Bank full: deposit incomplete.", ["dépôt en banque"] = "bank deposit",

    -- Catégories
    ["Tous les composants d'artisanat"] = "All trade goods", ["Étoffes"] = "Cloth", ["Cuirs"] = "Leather",
    ["Métaux et pierres"] = "Metal & stone", ["Viandes et cuisine"] = "Meat & cooking", ["Herbes"] = "Herbs",
    ["Éléments"] = "Elemental", ["Enchantement"] = "Enchanting", ["Joaillerie"] = "Jewelcrafting",
    ["Pièces d'ingénierie"] = "Engineering parts", ["Gemmes"] = "Gems", ["Consommables"] = "Consumables", ["Recettes"] = "Recipes",

    -- Thèmes
    ["Thème"] = "Theme", ["Coffre-fort"] = "Vault", ["Givre"] = "Frost", ["Graphite"] = "Graphite",
    ["Héraldique"] = "Heraldry", ["Faction"] = "Faction", ["Gangrefeu"] = "Fel", ["Néant"] = "Void",
    ["Bois sombre, parchemin et or."] = "Dark wood, parchment and gold.",
    ["Bleu nuit et cyan, net et lumineux."] = "Midnight blue and cyan, crisp and bright.",
    ["Gris neutre, sobre, couleur de ta classe en accent."] = "Neutral grey, understated, your class colour as accent.",
    ["Fenêtre aux couleurs de la classe du perso connecté."] = "Window in the colours of the logged-in character's class.",
    ["Alliance : bleu et or. Horde : rouge et fer."] = "Alliance: blue and gold. Horde: red and iron.",
    ["Noir profond et vert gangrené."] = "Deep black and fel green.",
    ["Violet et ombre, façon magie du Vide."] = "Purple and shadow, Void-magic style.",
    ["Thème, apparence, langue, bouton minimap et alertes."] = "Theme, appearance, language, minimap button and alerts.",
    ["Recharger pour appliquer"] = "Reload to apply",
    ["Accent du thème"] = "Theme accent", ["Couleur de classe"] = "Class colour", ["Couleur fixe"] = "Fixed colour",
    ["T : celle du thème. C : couleur de classe du perso connecté. Changement immédiat."] =
        "T: the theme's. C: class colour of the logged-in character. Applies instantly.",
    ["Police"] = "Font", ["Police du texte de l'interface (rechargement)."] = "Interface text font (reload).",
    ["Arrondi"] = "Rounding", ["Fort"] = "Strong", ["Moyen"] = "Medium", ["Carré"] = "Square",
    ["Arrondi des fenêtres, cartes et boutons (rechargement)."] = "Rounding of windows, cards and buttons (reload).",
    ["Opacité du fond"] = "Background opacity", ["Transparence du fond de la fenêtre (rechargement)."] = "Window background transparency (reload).",
    ["Auto : celle du jeu (rechargement)."] = "Auto: the game's language (reload).",

    -- Inventaire par personnage
    ["Sacs, banques et courrier, par personnage ou pour tout le compte. Maj + clic sur une ligne pour lier l'objet."] =
        "Bags, banks and mail, per character or for the whole account. Shift + click a row to link the item.",
    ["Tout le compte"] = "Whole account", ["sacs %d / %d"] = "bags %d / %d",
    ["Aucun objet ne correspond à la recherche."] = "No item matches the search.", ["Rien ici pour l'instant."] = "Nothing here yet.",

    -- Valeur, objectifs, recettes
    ["Richesse totale"] = "Total wealth", ["+ %s de stocks (%s)"] = "+ %s in stock (%s)",
    ["prix Auctionator"] = "Auctionator prices", ["prix marchand"] = "vendor prices",
    ["Objectif"] = "Goal", ["Définir"] = "Set", ["Modifier"] = "Change", ["Retirer l'objectif"] = "Remove the goal",
    ["objectif %s · %d %%"] = "goal %s · %d %%", ["atteint !"] = "reached!", ["dans ~%d j"] = "in ~%d d",
    ["Prix des objets"] = "Item prices", ["Source des prix"] = "Price source", ["Marchand"] = "Vendor",
    ["Auctionator détecté : valeur des stocks, du butin et des listes de courses au prix de l'hôtel des ventes (prix marchand si l'objet n'a pas de prix)."] =
        "Auctionator detected: stock, loot and shopping list values use auction house prices (vendor price when an item has none).",
    ["Auctionator non détecté : les prix de vente aux marchands sont utilisés."] = "Auctionator not detected: vendor sell prices are used.",
    ["Valeur du butin"] = "Loot value",
    ["Valeur du butin : prix Auctionator, sinon prix de vente aux marchands."] = "Loot value: Auctionator price, otherwise vendor price.",
    ["Niveaux, recettes connues par perso et liste de courses des composants."] = "Skill levels, known recipes per character and a reagent shopping list.",
    ["Niveaux"] = "Levels", ["Recettes"] = "Recipes", ["Liste de courses"] = "Shopping list", ["%d recettes"] = "%d recipes",
    ["Rechercher une recette ou un objet..."] = "Search a recipe or an item...",
    ["Ajouter à la liste de courses"] = "Add to the shopping list", ["x%d possibles"] = "x%d craftable",
    ["composants manquants"] = "missing reagents",
    ["Ouvre la fenêtre de chaque métier une fois pour enregistrer ses recettes."] = "Open each profession window once to record its recipes.",
    ["Aucune recette ne correspond à la recherche."] = "No recipe matches the search.",
    ["Fabrications prévues"] = "Planned crafts", ["Ajoute des recettes depuis l'onglet Recettes (bouton +)."] = "Add recipes from the Recipes tab (+ button).",
    ["Vider la liste"] = "Clear the list", ["Une fabrication de plus"] = "One more craft", ["Une fabrication de moins"] = "One less craft",
    ["Composants"] = "Reagents", ["Besoin"] = "Need", ["Possédé"] = "Owned", ["Manquant"] = "Missing", ["Coût"] = "Cost",
    ["Rien à fabriquer pour l'instant."] = "Nothing to craft yet.", ["Créer la liste Auctionator"] = "Create Auctionator list",
    ["Crée une liste de courses « Warband Keeper » dans Auctionator avec les composants manquants."] =
        "Creates a \"Warband Keeper\" shopping list in Auctionator with the missing reagents.",
    ["Coût des composants manquants : %s"] = "Cost of missing reagents: %s",
    ["Auctionator n'est pas disponible."] = "Auctionator is not available.",
    ["%d objet(s) pas encore chargés par le jeu : réessaie dans un instant."] = "%d item(s) not loaded by the game yet: try again in a moment.",
    ["Rien à acheter : tu as déjà tous les composants."] = "Nothing to buy: you already have every reagent.",
    ["Liste « Warband Keeper » créée dans Auctionator (%d objet(s))."] = "\"Warband Keeper\" list created in Auctionator (%d item(s)).",
    ["Auctionator a refusé la liste : "] = "Auctionator rejected the list: ",

    -- Chat
    ["Évolution sur %d jours : %s"] = "Change over %d days: %s",
}
