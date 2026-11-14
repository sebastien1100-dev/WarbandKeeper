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
        charItems = {},-- [charKey] = { [itemID] = { {t, v}, ... } } : tendance par personnage
    },
    journal = {},      -- journal d'activité (le plus récent en premier)
    mail = {
        enabled = true,
        rules = {},    -- [itemID] = "NomDestinataire"
    },
    settings = {
        historyIntervalSec = 3600, -- 1 point max par heure et par série
        trackedItems = {},         -- [itemID] = true : matériaux suivis dans les stats
        alerts = {
            enabled = true,
            bankDays = 7,          -- banque non vue depuis N jours
            mailDays = 3,          -- courrier qui expire dans moins de N jours
        },
        ui = {
            lang = "auto",         -- "auto", "frFR" ou "enUS"
            accent = 1,            -- index dans WK.UI.accents
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
