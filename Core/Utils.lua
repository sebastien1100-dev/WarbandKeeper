local ADDON_NAME, WK = ...

-- Couleur d'accent du thème en hexadécimal (doré avant le chargement des réglages).
function WK:AccentHex()
    local hex = "e0bd72"
    if WK.UI and WK.UI.Accent and WK.DB and WK.DB.global then
        local ok, r, g, b = pcall(WK.UI.Accent, WK.UI)
        if ok and r then hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end
    end
    return hex
end
-- « Warband Keeper » à la couleur d'accent (titres de section dans les infobulles, chat)
function WK:Tag()
    return "|cff" .. WK:AccentHex() .. "Warband Keeper|r"
end
function WK:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(WK:Tag() .. " " .. tostring(msg))
end

-- Clé unique d'un personnage : "Nom-Royaume".
function WK:CharKey(name, realm)
    name = name or UnitName("player")
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

-- Nom affiché d'un personnage : nom saisi pour le courrier, sinon nom complet
-- détecté (« Prénom Nom » sur WoW Forever), sinon nom du jeu, sinon tiré de la clé.
function WK:CharName(c, key)
    if c then
        if c.mailName and c.mailName ~= "" then return c.mailName end
        if c.fullName or c.name then return c.fullName or c.name end
    end
    return key and (string.match(key, "^([^%-]+)") or key) or "?"
end

-- Formatage de l'or : 1234567 -> "123po 45pa 67pc".
function WK:FormatMoney(copper)
    copper = math.floor(copper or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    -- Les parties à zéro sont omises (« 50pa » plutôt que « 0po 50pa 0pc »).
    local parts = {}
    if g > 0 then table.insert(parts, string.format("|cffffd700%d|r%s", g, WK.T("po"))) end
    if s > 0 then table.insert(parts, string.format("|cffc7c7cf%d|r%s", s, WK.T("pa"))) end
    if c > 0 or #parts == 0 then table.insert(parts, string.format("|cffeda55f%d|r%s", c, WK.T("pc"))) end
    local str = table.concat(parts, " ")
    return neg and ("-" .. str) or str
end

-- Formatage d'une durée en secondes : "3j 4h 12m".
function WK:FormatTime(sec)
    sec = math.floor(sec or 0)
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    if d > 0 then return string.format(WK.T("%dj %dh %dm"), d, h, m) end
    return string.format(WK.T("%dh %dm"), h, m)
end

-- Extrait un itemID depuis un nombre ou un lien d'objet.
function WK:ParseItemID(arg)
    if not arg then return nil end
    local id = tonumber(arg) or tonumber(string.match(arg, "item:(%d+)"))
    return id
end

-- API moderne (C_Item) avec repli sur l'ancienne fonction globale.
-- Article du marchand ouvert : nom, icône, prix, taille du lot, quantité dispo (-1 : illimitée).
-- GetMerchantItemInfo n'existe plus sur ce client : C_MerchantFrame.GetItemInfo rend une table.
function WK.MerchantItemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok and type(info) == "table" then
            return info.name, info.texture, info.price, info.stackCount, info.numAvailable
        end
    end
    if GetMerchantItemInfo then return GetMerchantItemInfo(index) end
end

function WK.GetItemInfo(itemID)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(itemID) end
    if GetItemInfo then return GetItemInfo(itemID) end
end

-- Insère un lien d'objet dans la zone de saisie du chat.
function WK.InsertChatLink(link)
    if ChatFrameUtil and ChatFrameUtil.InsertLink then return ChatFrameUtil.InsertLink(link) end
    if ChatEdit_InsertLink then return ChatEdit_InsertLink(link) end
end

-- Ouvre la zone de saisie du chat avec ce texte (ou l'ajoute si elle est déjà ouverte).
function WK.ChatInsert(text)
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if eb and eb.Insert then eb:Insert(text) return true end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text) return true end
    if ChatFrameUtil and ChatFrameUtil.OpenChat then ChatFrameUtil.OpenChat(text) return true end
    return false
end

-- Nom et icône d'un sort (recette de métier), dans la langue du jeu.
function WK.SpellInfo(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(spellID)
        if type(i) == "table" then return i.name, i.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellID)
        return name, icon
    end
end

function WK:ItemName(itemID)
    local name, link = WK.GetItemInfo(itemID)
    return link or name or ("item:" .. itemID)
end

-- Couche de compatibilité conteneurs (API moderne C_Container ou ancienne API).
local C = _G.C_Container
WK.Container = {}

function WK.Container.NumSlots(bag)
    if C and C.GetContainerNumSlots then return C.GetContainerNumSlots(bag) end
    return GetContainerNumSlots(bag)
end

-- Retourne itemID, quantité, verrouillé pour un emplacement.
function WK.Container.Info(bag, slot)
    if C and C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        if info then return info.itemID, info.stackCount, info.isLocked, info.isBound end
        return nil
    end
    local _, count, locked, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
    if not itemID and link then itemID = WK:ParseItemID(link) end
    -- « Lié » : important pour les objets LQE déjà équipés (on ne peut plus les envoyer).
    local bound
    if itemID and C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, b = pcall(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(bag, slot))
        if ok then bound = b end
    end
    return itemID, count, locked, bound
end

function WK.Container.NumFree(bag)
    if C and C.GetContainerNumFreeSlots then return (C.GetContainerNumFreeSlots(bag)) end
    if GetContainerNumFreeSlots then return (GetContainerNumFreeSlots(bag)) end
    return 0
end

function WK.Container.Pickup(bag, slot)
    if C and C.PickupContainerItem then return C.PickupContainerItem(bag, slot) end
    return PickupContainerItem(bag, slot)
end

-- Équiper un objet : C_Item.EquipItemByName sur les clients récents (la globale n'existe plus), sinon l'ancienne
function WK.EquipItem(item, slot)
    local f = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not f then return false end
    return pcall(f, item, slot)
end

-- Recharge d'un sort : début, durée (C_Spell.GetSpellCooldown sur les clients récents, sinon l'ancienne globale).
-- nil si le jeu ne donne rien ou masque la valeur.
function WK.SpellCooldown(spell)
    if not spell then return nil end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
        if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spell)
        if ok then start, duration = s, d end
    end
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return nil end
    if type(start) ~= "number" or type(duration) ~= "number" then return nil end
    return start, duration
end

-- Pseudos en cyrillique : la police de l'addon n'a pas ces lettres (carrés à l'écran), on les écrit en latin
-- (table construite au chargement à partir des points de code : pas de lettre cyrillique dans ce fichier)
local CYR = {}
do
    local up = { "A", "B", "V", "G", "D", "E", "Zh", "Z", "I", "Y", "K", "L", "M", "N", "O", "P", "R", "S", "T", "U", "F",
                 "Kh", "Ts", "Ch", "Sh", "Shch", "", "Y", "", "E", "Yu", "Ya" } -- U+0410 à U+042F
    local function utf8(cp) return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
    for i, l in ipairs(up) do
        CYR[utf8(0x40F + i)] = l           -- majuscule
        CYR[utf8(0x42F + i)] = l:lower()   -- minuscule (U+0430 à U+044F)
    end
    for cp, l in pairs({ [0x401] = "E", [0x451] = "e", [0x406] = "I", [0x456] = "i", [0x407] = "Yi", [0x457] = "yi",
                         [0x404] = "Ye", [0x454] = "ye", [0x490] = "G", [0x491] = "g" }) do CYR[utf8(cp)] = l end
end
function WK.Latin(s)
    if type(s) ~= "string" or not s:find("[\208-\211]") then return s end
    return (s:gsub("[\208-\211][\128-\191]", function(ch) return CYR[ch] or "?" end))
end

