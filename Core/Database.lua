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
        trackedItems = {},         -- [itemID] = true : matériaux suivis dans les stats
        value = {
            source = "auctionator", -- "auctionator" (repli marchand) ou "vendor"
        },
        alerts = {
            enabled = true,
            bankDays = 7,          -- banque non vue depuis N jours
            mailDays = 3,          -- courrier qui expire dans moins de N jours
        },
        ui = {
            lang = "auto",         -- "auto", "frFR" ou "enUS"
            closeInCombat = false, -- ferme la fenêtre principale au début d'un combat
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
