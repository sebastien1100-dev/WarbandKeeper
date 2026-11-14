local ADDON_NAME, WK = ...

function WK:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffWarband Keeper|r " .. tostring(msg))
end

-- Clé unique d'un personnage : "Nom-Royaume".
function WK:CharKey(name, realm)
    name = name or UnitName("player")
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

-- Formatage de l'or : 1234567 -> "123po 45pa 67pc".
function WK:FormatMoney(copper)
    copper = math.floor(copper or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local str = string.format("|cffffd700%d|r%s |cffc7c7cf%d|r%s |cffeda55f%d|r%s",
        g, WK.T("po"), s, WK.T("pa"), c, WK.T("pc"))
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
function WK.GetItemInfo(itemID)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(itemID) end
    if GetItemInfo then return GetItemInfo(itemID) end
end

-- Insère un lien d'objet dans la zone de saisie du chat.
function WK.InsertChatLink(link)
    if ChatFrameUtil and ChatFrameUtil.InsertLink then return ChatFrameUtil.InsertLink(link) end
    if ChatEdit_InsertLink then return ChatEdit_InsertLink(link) end
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
    return itemID, count, locked, nil
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
