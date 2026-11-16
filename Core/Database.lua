local ADDON_NAME, WK = ...

WK.DB = {}
local DB = WK.DB

local SCHEMA_VERSION = 1

local defaults = {
    schema = SCHEMA_VERSION,
    characters = {},   -- [charKey] = { class, level, race, faction, money, played, lastSeen, bags, bank, professions }
    history = {        -- séries temporelles pour les statistiques
        gold = {},     -- [charKey] = { {t=timestamp, v=copper}, ... }
        items = {},    -- [itemID] = { {t=timestamp, v=total compte}, ... }
        value = {},    -- richesse totale (or + stocks) : { {t, v}, ... }
        charItems = {},-- [charKey] = { [itemID] = { {t, v}, ... } } : tendance par personnage
    },
    journal = {},      -- journal d'activité (le plus récent en premier)
    goals = {},        -- [série] = { target = n } ; série = "gold", "value" ou itemID
    shopping = {},     -- liste de courses : [nom de recette] = nombre de fabrications
    mail = {
        enabled = true,
        closeAfter = true, -- ferme la boîte aux lettres après l'envoi automatique
        sortAfter = true,  -- trie les sacs après l'envoi automatique
        -- Clé : itemID (ou catégorie), suivi de « @Perso-Royaume » pour une règle d'un seul perso.
        rules = {},    -- [itemID] = { to = "Nom", keep = n }
        cats = {},     -- [clé de catégorie] = { to = "Nom", keep = n }
        autoTake = false, -- « Tout prendre » automatiquement à l'ouverture (après les envois)
    },
    auction = { log = {} },   -- ventes et achats à l'HV (Modules/Auction.lua)
    -- Coins de récolte (Modules/GatherMap.lua) : points par carte, et leur affichage sur la carte du monde
    gatherSpots = {},
    gatherMap = { record = true, showMap = true },
    -- Lueur de récolte (Modules/Glow.lua) : désactivée tant que le joueur ne l'allume pas
    glow = { enabled = false, range = 15, size = 110, intensity = 100, offsetY = -45,
             hideInCombat = false, hideInInstance = false, onlyTrained = true, cats = {}, colors = {} },
    -- Qualité de vie (Modules/QoL.lua) : réglages complétés par QoL:Config()
    qol = { general = {}, classes = {}, petFoods = {} },
    bank = {
        enabled = true,
        sortAfter = true,  -- trie les sacs après le dépôt automatique
        items = {},    -- [itemID] = { target = "bank"|"warband", keep = n }
        cats = {},
    },
    loot = {
        enabled = true,
        closeAfter = true, -- ferme la fenêtre de butin quand des objets sont laissés
        active = 1,        -- profil chargé à la main (index)
        profiles = {},     -- créés au premier lancement (Modules/Loot.lua)
        recent = {},       -- derniers objets laissés au sol
    },
    farm = {
        history = {},  -- sessions terminées (la plus récente en premier)
        mini = true,   -- mini-fenêtre pendant une session
    },
    settings = {
        historyIntervalSec = 3600, -- 1 point max par heure et par série
        profLink = {},             -- [métier] = { text = "texte ajouté au lien", on = true/false }
        trackedItems = {},         -- [itemID] = true : matériaux suivis dans les stats
        value = {
            source = "auctionator", -- "auctionator" : prix HV du scan (repli marchand), "vendor" ou "both"
        },
        alerts = {
            enabled = true,
            bankDays = 7,          -- banque non vue depuis N jours
            mailDays = 3,          -- courrier qui expire dans moins de N jours
        },
        ui = {
            lang = "auto",         -- "auto", "frFR" ou "enUS"
            closeInCombat = false, -- ferme la fenêtre principale au début d'un combat
            loginPopup = true,     -- fenêtre de rappels à la connexion (UI/LoginPopup.lua)
            portraits = true,      -- portrait à côté du nom des persos (sinon icône de classe)
            theme = "vault",       -- clé de UI.themes
            font = "friz",         -- clé de UI.fonts
            rounding = 1,          -- 1 = arrondi fort, 0.6 = moyen, 0.25 = presque carré
            opacity = 1,           -- opacité du fond de la fenêtre
            accent = "theme",      -- "theme", "class" ou index dans WK.UI.accents
            scale = 1,
            lastPage = "overview",
            minimap = { hide = false, angle = 215 },
        },
    },
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function DB:Init()
    WarbandKeeperDB = WarbandKeeperDB or {}
    WarbandKeeperCharDB = WarbandKeeperCharDB or {}
    copyDefaults(defaults, WarbandKeeperDB)
    self.global = WarbandKeeperDB
    self.char = WarbandKeeperCharDB
end

-- Données du personnage courant (créées à la volée).
function DB:Me()
    local key = WK:CharKey()
    local c = self.global.characters[key]
    if not c then
        c = { bags = {}, bank = {}, professions = {} }
        self.global.characters[key] = c
    end
    return c, key
end

-- Ajoute un point à une série si l'intervalle minimal est écoulé (sinon met à jour le dernier).
function DB:PushHistory(series, value)
    local now = time()
    local last = series[#series]
    if last and (now - last.t) < self.global.settings.historyIntervalSec then
        last.v = value
    else
        table.insert(series, { t = now, v = value })
    end
end

-- Allège l'historique : au-delà de `days` jours (30 par défaut), un seul point par jour (le dernier).
-- Les courbes restent identiques à l'échelle du mois et de l'année, sans grossir sans fin.
local function compactSeries(series, cutoff)
    if type(series) ~= "table" or #series < 2 then return 0 end
    local out, removed = {}, 0
    local lastDay
    for _, p in ipairs(series) do
        if p.t >= cutoff then
            table.insert(out, p)
            lastDay = nil
        else
            local day = math.floor(p.t / 86400)
            if day == lastDay then
                out[#out] = p -- remplace : on garde le dernier point du jour
                removed = removed + 1
            else
                table.insert(out, p)
                lastDay = day
            end
        end
    end
    if removed > 0 then
        wipe(series)
        for i, p in ipairs(out) do series[i] = p end
    end
    return removed
end
DB.CompactSeries = compactSeries

function DB:CompactHistory(days)
    local cutoff = time() - (days or 30) * 86400
    local h = self.global.history
    local removed = 0
    for _, series in pairs(h.gold or {}) do removed = removed + compactSeries(series, cutoff) end
    for _, series in pairs(h.items or {}) do removed = removed + compactSeries(series, cutoff) end
    for _, perChar in pairs(h.charItems or {}) do
        for _, series in pairs(perChar) do removed = removed + compactSeries(series, cutoff) end
    end
    removed = removed + compactSeries(h.value, cutoff)
    return removed
end
