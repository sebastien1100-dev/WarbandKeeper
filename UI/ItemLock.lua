local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Objets verrouillés (Modules/ItemLock.lua), côté écran :
--   sacs du jeu : cadenas sur la case (rose : à la main ; turquoise : par règle), Alt + clic pour (dé)verrouiller ;
--   chez le marchand : un cache sur la case bloque le clic (objet verrouillé) ou demande confirmation (vente chère) ;
--   infobulle : « Verrouillé… ».
local L = WK.modules.ItemLock

local function inCombat() return InCombatLockdown and InCombatLockdown() end
-- Combinaison exacte (les autres touches relâchées) et bouton de la souris : alt, ctrl, shiftalt, ctrlalt, ctrlshift
-- (clic gauche), mid, altmid, ctrlmid (clic molette, rarement pris par le jeu ou les autres addons dans les sacs)
local COMBOS = {
    alt = { alt = true }, ctrl = { ctrl = true }, shiftalt = { shift = true, alt = true },
    ctrlalt = { ctrl = true, alt = true }, ctrlshift = { ctrl = true, shift = true },
    mid = { btn = "MiddleButton" }, altmid = { alt = true, btn = "MiddleButton" }, ctrlmid = { ctrl = true, btn = "MiddleButton" },
}
local function modDown(button)
    local c = COMBOS[L:Config().key] or COMBOS.altmid
    if button and button ~= (c.btn or "LeftButton") then return false end
    return (IsAltKeyDown() and true or false) == (c.alt or false)
        and (IsControlKeyDown() and true or false) == (c.ctrl or false)
        and (IsShiftKeyDown() and true or false) == (c.shift or false)
end
-- Sac et case d'un bouton : plusieurs façons selon l'interface des sacs (jeu moderne, ancien, autres addons)
local function bagSlot(btn)
    local bag
    if btn.GetBagID then local ok, v = pcall(btn.GetBagID, btn); if ok then bag = v end end
    if bag == nil and btn.GetBag then local ok, v = pcall(btn.GetBag, btn); if ok and type(v) == "number" then bag = v end end
    if bag == nil then bag = btn.bagID or btn.bag end
    if bag == nil and btn:GetParent() and btn:GetParent().GetID then bag = btn:GetParent():GetID() end
    local slot = btn.GetID and btn:GetID()
    if (not slot or slot == 0) and btn.slotID then slot = btn.slotID end
    return bag, slot
end
-- Cases repérées par leur infobulle (sacs dont on ne connaît pas les noms) : faibles, repeintes avec les autres
local known = setmetatable({}, { __mode = "k" })
local function itemAt(bag, slot)
    if not bag or not slot then return nil end
    return (WK.Container.Info(bag, slot))
end

---------------------------------------------------------------------------
-- Confirmation d'une vente chère
---------------------------------------------------------------------------
local dlg
local function sellNow(bag, slot)
    if C_Container and C_Container.UseContainerItem then C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then UseContainerItem(bag, slot) end
end
local function confirm(bag, slot, id, ah, vendor)
    if not dlg then
        dlg = CreateFrame("Frame", "WarbandKeeperSellConfirm", UIParent)
        dlg:SetSize(330, 190)
        dlg:SetPoint("CENTER", 0, 120)
        dlg:SetFrameStrata("DIALOG")
        dlg:EnableMouse(true)
        UI:Panel(dlg, 12, C.bg, C.border)
        if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperSellConfirm") end
        dlg.title = UI:Text(dlg, 14)
        dlg.title:SetPoint("TOPLEFT", 16, -14)
        dlg.title:SetText(T("Vendre au marchand ?"))
        dlg.rows = {}
        for i, lab in ipairs({ "Objet", "Marchand", "Hôtel des ventes (scan)" }) do
            local l = UI:Text(dlg, 12, C.muted)
            l:SetPoint("TOPLEFT", 16, -40 - (i - 1) * 22)
            l:SetText(T(lab))
            local v = UI:Text(dlg, 12)
            v:SetPoint("TOPRIGHT", -16, -40 - (i - 1) * 22)
            v:SetJustifyH("RIGHT")
            dlg.rows[i] = v
        end
        dlg.keep = UI:Button(dlg, "Garder", 92, 28, "secondary")
        dlg.keep:SetPoint("BOTTOMLEFT", 16, 40)
        dlg.keep:SetScript("OnClick", function() dlg:Hide() end)
        dlg.lock = UI:Button(dlg, "Verrouiller", 100, 28, "secondary")
        dlg.lock:SetPoint("LEFT", dlg.keep, "RIGHT", 8, 0)
        dlg.lock:SetScript("OnClick", function() L:Toggle(dlg.id); dlg:Hide() end)
        dlg.sell = UI:Button(dlg, "Vendre", 92, 28, "primary")
        dlg.sell:SetPoint("LEFT", dlg.lock, "RIGHT", 8, 0)
        dlg.sell:SetScript("OnClick", function()
            if dlg.never then L:Never(dlg.id) end
            if itemAt(dlg.bag, dlg.slot) == dlg.id and L:MerchantOpen() then sellNow(dlg.bag, dlg.slot) end
            dlg:Hide()
        end)
        dlg.neverBtn = CreateFrame("Button", nil, dlg)
        dlg.neverBtn:SetSize(260, 18)
        dlg.neverBtn:SetPoint("BOTTOMLEFT", 16, 12)
        dlg.neverText = UI:Text(dlg.neverBtn, 11, C.muted)
        dlg.neverText:SetPoint("LEFT")
        dlg.neverBtn:SetScript("OnClick", function()
            dlg.never = not dlg.never
            dlg.neverText:SetText((dlg.never and "[x] " or "[ ] ") .. T("Ne plus demander pour cet objet"))
        end)
    end
    dlg.bag, dlg.slot, dlg.id, dlg.never = bag, slot, id, false
    local name, _, r, g, b = UI:ItemInfo(id)
    dlg.rows[1]:SetText(name); dlg.rows[1]:SetTextColor(r, g, b)
    dlg.rows[2]:SetText(WK:FormatMoney(vendor))
    dlg.rows[3]:SetText(WK:FormatMoney(ah)); dlg.rows[3]:SetTextColor(unpack(C.gold))
    dlg.neverText:SetText("[ ] " .. T("Ne plus demander pour cet objet"))
    dlg:Show()
end

---------------------------------------------------------------------------
-- Cases des sacs du jeu
---------------------------------------------------------------------------
-- Libellé de la touche choisie pour (dé)verrouiller (réglage key : alt, ctrl ou shiftalt)
local function keyLabel()
    local k = L:Config().key or "altmid"
    for _, o in ipairs(L.KEY_OPTIONS) do if o[1] == k then return T(o[2]) end end
    return T("Alt + clic molette")
end
UI.ItemLockKeyLabel = keyLabel
local function blockMsg(id)
    local msg = string.format(T("Verrouillé : %s n'a pas été vendu (%s pour le déverrouiller)."),
        WK.GetItemInfo(id) or ("#" .. id), keyLabel())
    if UIErrorsFrame then local r, g, b = UI:Accent(); UIErrorsFrame:AddMessage(msg, r, g, b) end
end

-- Caches du marchand : tous retenus, pour être retirés à la fermeture du marchand même en combat ou sacs
-- fermés. Ce sont des boutons ordinaires (pas protégés) : les cacher est permis en combat ; on ne les montre
-- jamais en combat. Avant, un marchand fermé en combat laissait le cache sur la case (potion, objet de
-- quête utilisable bloqués jusqu'à la fin du combat).
local blocks = setmetatable({}, { __mode = "k" })
local function hideBlocks()
    for b in pairs(blocks) do if b:IsShown() then b:Hide() end end
end
UI.ItemLockHideBlocks = hideBlocks
WK:On("MERCHANT_CLOSED", hideBlocks)

local function decorate(btn)
    if btn.wkLock then return btn.wkLock end
    if inCombat() then return nil end
    local o = CreateFrame("Frame", nil, btn)
    o:SetAllPoints()
    o:SetFrameLevel(btn:GetFrameLevel() + 3)
    o.badge = o:CreateTexture(nil, "OVERLAY", nil, 6)
    o.badge:SetTexture(UI.MEDIA .. "circle")
    o.badge:SetSize(15, 15)
    o.badge:SetPoint("TOPRIGHT", 3, 3)
    o.ring = o:CreateTexture(nil, "OVERLAY", nil, 5)
    o.ring:SetTexture(UI.MEDIA .. "circle")
    o.ring:SetSize(17, 17)
    o.ring:SetPoint("CENTER", o.badge, "CENTER")
    o.ring:SetVertexColor(0, 0, 0, 0.9)
    o.icon = o:CreateTexture(nil, "OVERLAY", nil, 7)
    o.icon:SetTexture(UI.MEDIA .. "lock")
    o.icon:SetSize(9, 9)
    o.icon:SetPoint("CENTER", o.badge, "CENTER")
    o.icon:SetVertexColor(0.08, 0.06, 0.07, 1)
    -- repère BiS (Modules/BiS.lua) : étoile en bas à gauche
    o.bisRing = o:CreateTexture(nil, "OVERLAY", nil, 5)
    o.bisRing:SetTexture(UI.MEDIA .. "circle")
    o.bisRing:SetSize(17, 17)
    o.bisRing:SetPoint("BOTTOMLEFT", -3, -3)
    o.bisRing:SetVertexColor(0, 0, 0, 0.9)
    o.bisBadge = o:CreateTexture(nil, "OVERLAY", nil, 6)
    o.bisBadge:SetTexture(UI.MEDIA .. "circle")
    o.bisBadge:SetSize(15, 15)
    o.bisBadge:SetPoint("CENTER", o.bisRing, "CENTER")
    o.bisStar = o:CreateTexture(nil, "OVERLAY", nil, 7)
    o.bisStar:SetTexture(UI.MEDIA .. "star")
    o.bisStar:SetSize(10, 10)
    o.bisStar:SetPoint("CENTER", o.bisRing, "CENTER")
    o.bisStar:SetVertexColor(0.08, 0.06, 0.07, 1)
    -- cache chez le marchand : prend le clic à la place de la case
    o.block = CreateFrame("Button", nil, btn)
    o.block:SetAllPoints()
    o.block:SetFrameLevel(btn:GetFrameLevel() + 4)
    o.block:RegisterForClicks("AnyUp")
    o.block:RegisterForDrag("LeftButton")
    o.block:SetScript("OnClick", function(s, button)
        local bag, slot = bagSlot(btn)
        local id = itemAt(bag, slot)
        if not id then return end
        if modDown(button) then L:Toggle(id) return end
        if L:IsLocked(id) then blockMsg(id) return end
        local exp, ah, vendor = L:Expensive(id)
        if exp and button == "RightButton" then confirm(bag, slot, id, ah, vendor) end
    end)
    o.block:SetScript("OnDragStart", function()
        local id = itemAt(bagSlot(btn))
        if not id then return end
        if L:IsLocked(id) then blockMsg(id) return end
        -- vente seulement chère (pas verrouillée) : le dire, pas « Verrouillé »
        local ef = _G.UIErrorsFrame
        if ef then
            local r, g, b = UI:Accent()
            ef:AddMessage(string.format(T("Vente chère : clic droit sur %s pour confirmer la vente."),
                WK.GetItemInfo(id) or ("#" .. id)), r, g, b)
        end
    end)
    o.block:SetScript("OnEnter", function(s)
        local bag, slot = bagSlot(btn)
        WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
        if GameTooltip.SetBagItem then pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot) end
        GameTooltip:Show()
    end)
    o.block:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o.block:Hide()
    blocks[o.block] = true
    -- Alt + clic sur la case (hors marchand) : verrouiller / déverrouiller
    -- (les sacs de WoW Forever ne passent pas toujours par OnClick : GLOBAL_MOUSE_DOWN plus bas fait le même travail ;
    -- OnClick ne sert que de secours, pour un appui que GLOBAL_MOUSE_DOWN n'a pas déjà traité)
    btn:HookScript("OnClick", function(b, button)
        if not modDown(button) or UI.ItemLockPressHandled() then return end
        UI.ItemLockAltClick(b)
    end)
    btn.wkLock = o
    return o
end

-- Appui déjà traité par GLOBAL_MOUSE_DOWN : le OnClick qui suit au relâchement (même après 0,25 s) ne
-- rebascule pas le verrou. Effacé l'image d'après le relâchement (GLOBAL_MOUSE_UP), sinon au bout de 5 s.
local pressAt
function UI.ItemLockPressHandled()
    return pressAt ~= nil and GetTime() - pressAt < 5
end

-- Emplacements d'équipement (fenêtre du personnage du jeu ou d'une autre interface, inspection) : jamais des cases
-- de sac, même s'ils ont un n° (11 et 12 = anneaux, lus avant comme les cases 11 et 12 du sac à dos)
local NOT_BAG = { "character", "paperdoll", "inspect", "equip", "gear", "dressup", "transmog" }
local function inGearFrame(f)
    for _ = 1, 10 do
        if not f then return false end
        local n = f.GetName and f:GetName()
        if type(n) == "string" then
            n = n:lower()
            for _, w in ipairs(NOT_BAG) do if n:find(w, 1, true) then return true end end
        end
        if f == _G.UIParent then return false end
        f = f.GetParent and f:GetParent()
    end
    return false
end
local paint
-- Bascule du verrou d'une case (un seul passage par clic, quel que soit le chemin qui l'a vu)
local lastToggle = 0
function UI.ItemLockAltClick(b)
    local now = GetTime()
    if now - lastToggle < 0.25 then return end
    local id = itemAt(bagSlot(b))
    if not id or UI.ItemLockForeignMismatch(b, id) then return end
    lastToggle = now
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    L:Toggle(id)
    paint(b) -- cadenas montré tout de suite, sans attendre le prochain passage du repeint
end

-- Case d'une autre interface : le sac et la case sont devinés (champs, parent) et peuvent désigner un autre
-- objet (bouton « + », case recyclée, marchand maison) ; on ne dessine que si la case montre bien l'icône
-- de cet objet. Avant : cadenas sur des cases vides ou des boutons qui n'étaient pas des cases.
local function iconOf(id)
    local f = _G.C_Item and _G.C_Item.GetItemIconByID
    local ok, v = pcall(f or function() end, id)
    if ok and v then return v end
    if _G.GetItemIcon then ok, v = pcall(_G.GetItemIcon, id); if ok then return v end end
end
local function showsIcon(f, want, depth)
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetTexture and r:IsShown() then
            local ok, t = pcall(r.GetTexture, r)
            if ok and t ~= nil and (t == want or tostring(t):lower() == tostring(want):lower()) then return true end
        end
    end
    if depth > 0 and f.GetChildren then
        for _, ch in ipairs({ f:GetChildren() }) do
            if ch:IsShown() and showsIcon(ch, want, depth - 1) then return true end
        end
    end
    return false
end
local function foreignMismatch(btn, id)
    if not (known[btn] or btn.wkForeign) then return false end
    if not id then return true end
    local want = iconOf(id)
    if not want then return false end
    return not showsIcon(btn, want, 1)
end
UI.ItemLockForeignMismatch = foreignMismatch

function paint(btn)
    -- emplacement d'équipement pris pour une case de sac (avant cette correction) : décor retiré, plus suivi ;
    -- case d'une autre interface qui ne montre pas l'objet deviné : décor retiré (repris s'il revient)
    local gear = inGearFrame(btn)
    if gear or foreignMismatch(btn, btn.GetID and itemAt(bagSlot(btn))) then
        if gear then known[btn] = nil end
        local o0 = btn.wkLock
        if o0 then
            for _, k in ipairs({ "badge", "ring", "icon", "bisRing", "bisBadge", "bisStar" }) do
                if o0[k] then o0[k]:Hide() end
            end
            if o0.block and not inCombat() then o0.block:Hide() end
        end
        return
    end
    local o = decorate(btn)
    if not o then return end
    local id = itemAt(bagSlot(btn))
    local why = id and L:Reason(id)
    local r1, g1, b1 = UI:Accent()
    o.badge:SetShown(why ~= nil); o.ring:SetShown(why ~= nil); o.icon:SetShown(why ~= nil)
    if why then
        if why == "manual" then o.badge:SetVertexColor(r1, g1, b1, 1) else o.badge:SetVertexColor(C.rule[1], C.rule[2], C.rule[3], 1) end
    end
    local B = WK.modules.BiS
    local mark = id and B and WK:FeatureOn("characters") and B:Mark(id)
    o.bisRing:SetShown(mark and true or false); o.bisBadge:SetShown(mark and true or false); o.bisStar:SetShown(mark and true or false)
    if mark == "mine" then o.bisBadge:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
    elseif mark then o.bisBadge:SetVertexColor(C.silver[1], C.silver[2], C.silver[3], 1) end
    local guard = L:MerchantOpen() and id ~= nil and (why ~= nil or L:Expensive(id))
    if not inCombat() then
        o.block:SetShown(guard and true or false)
    elseif not guard and o.block:IsShown() then
        o.block:Hide() -- en combat : jamais montré, mais retiré s'il n'a plus lieu d'être
    end
end

-- Sacs d'une autre interface (EUI de WoW Forever : EUI_MainBagFrame, cases dans une liste qui défile et dont
-- les cadres sont recyclés) : on retient le cadre racine du sac et on y cherche les cases à chaque passage.
local roots = setmetatable({}, { __mode = "k" })
local ROOT_NAMES = { "EUI_MainBagFrame", "EUI_BankFrame", "EUI_BagFrame" }
-- une case est un bouton (les cadres de sac d'EUI ont aussi GetBagID : ce ne sont pas des cases)
local BUTTON_TYPES = { Button = true, ItemButton = true, CheckButton = true }
local function isBagButton(f)
    if not (f and f.GetBagID and f.GetID) or (f.IsForbidden and f:IsForbidden()) then return false end
    if inGearFrame(f) then return false end
    local t = f.GetObjectType and f:GetObjectType()
    if t and not BUTTON_TYPES[t] then return false end
    local bag, slot = bagSlot(f)
    return type(bag) == "number" and type(slot) == "number" and slot >= 1 and bag >= -3 and bag <= 12
end
-- La case de sac qui contient ce cadre (le cadre lui-même, ou un parent proche)
local function findBagButton(f)
    for _ = 1, 4 do
        if not f then return nil end
        if isBagButton(f) then return f end
        f = f.GetParent and f:GetParent()
    end
end
local function rootOf(b)
    local f, last = b, b
    for _ = 1, 12 do
        local p = f.GetParent and f:GetParent()
        if not p or p == UIParent then break end
        last, f = p, p
        if p.GetName and p:GetName() then return p end -- premier cadre nommé : le sac
    end
    return last
end
local function walk(f, fn, depth)
    if depth > 8 or not f.GetChildren then return end
    for _, ch in ipairs({ f:GetChildren() }) do
        if ch:IsVisible() then
            if isBagButton(ch) then ch.wkForeign = true; fn(ch) end
            walk(ch, fn, depth + 1) -- on descend toujours : une case peut être plus bas qu'un cadre de sac
        end
    end
end

local function eachButton(fn)
    local function frameItems(f)
        if not (f and f:IsShown()) then return end
        if f.EnumerateValidItems then
            for _, b in f:EnumerateValidItems() do fn(b) end
        elseif f.GetName and f:GetName() then
            for j = 1, 40 do
                local b = _G[f:GetName() .. "Item" .. j]
                if b and b:IsShown() then fn(b) end
            end
        end
    end
    -- chaque case une seule fois, quel que soit le chemin qui l'a trouvée
    local outer = fn
    local seen = {}
    local function each(b) if not seen[b] then seen[b] = true; outer(b) end end
    fn = each
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do frameItems(_G["ContainerFrame" .. i]) end
    frameItems(_G.ContainerFrameCombinedBags)
    for b in pairs(known) do if b:IsVisible() then each(b) end end
    for _, n in ipairs(ROOT_NAMES) do local r = _G[n]; if r and r.GetChildren then roots[r] = true end end
    for r in pairs(roots) do if r:IsVisible() then walk(r, each, 0) end end
    fn = outer
end
local function anyBagOpen()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do local f = _G["ContainerFrame" .. i]; if f and f:IsShown() then return true end end
    if _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsShown() then return true end
    for b in pairs(known) do if b:IsVisible() then return true end end
    for _, n in ipairs(ROOT_NAMES) do local r = _G[n]; if r and r.IsVisible and r:IsVisible() then return true end end
    for r in pairs(roots) do if r:IsVisible() then return true end end
    return false
end
-- Une case de sac survolée (infobulle d'objet) : on la retient et on la décore tout de suite
local function learnButton(owner, id)
    owner = findBagButton(owner) or owner
    if owner and isBagButton(owner) then local r = rootOf(owner); if r then roots[r] = true end end
    if not owner or known[owner] or not owner.GetID or not WK:FeatureOn("inventory") then return end
    if owner.IsForbidden and owner:IsForbidden() then return end
    if inGearFrame(owner) then return end
    local bag, slot = bagSlot(owner)
    if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 or bag < -3 or bag > 12 then return end
    if itemAt(bag, slot) ~= id then return end
    known[owner] = true
    paint(owner)
    -- les cases voisines (même parent, même genre de cadre) sont des cases de sac elles aussi
    local parent = owner:GetParent()
    if parent and parent.GetChildren then
        local kind = owner.GetObjectType and owner:GetObjectType()
        for _, ch in ipairs({ parent:GetChildren() }) do
            if ch ~= owner and not known[ch] and ch.GetID and (ch.GetObjectType and ch:GetObjectType()) == kind
                and not (ch.IsForbidden and ch:IsForbidden()) then
                local b2, s2 = bagSlot(ch)
                if type(b2) == "number" and type(s2) == "number" and s2 >= 1 and b2 >= -3 and b2 <= 12 then
                    known[ch] = true
                    paint(ch)
                end
            end
        end
    end
end
UI.ItemLockLearn = learnButton

-- cases de notre inventaire (UI/Bags.lua) : même cadenas, même étoile BiS, même cache chez le marchand
function UI.ItemLockPaint(btn) if WK:FeatureOn("inventory") then paint(btn) end end

function UI:RefreshItemLocks()
    if not WK:FeatureOn("inventory") then return end
    eachButton(paint)
end

-- Sacs ouverts : repeints quand quelque chose change (contenu, verrou du jeu, objet arrivé en cache, sac
-- ouvert), et toutes les 2 s en secours ; avant, toutes les cases étaient repeintes toutes les 0,3 s
local driver = CreateFrame("Frame")
driver.acc = 0
local repaintSoon = false
local function soonRepaint()
    if repaintSoon then return end
    repaintSoon = true
    _G.C_Timer.After(0.1, function()
        repaintSoon = false
        if anyBagOpen() then UI:RefreshItemLocks() end
    end)
end
driver:SetScript("OnUpdate", function(s, el)
    s.acc = s.acc + el
    if s.acc < 2 then return end
    s.acc = 0
    if anyBagOpen() then UI:RefreshItemLocks() end
end)
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "GET_ITEM_INFO_RECEIVED", "BAG_OPEN",
    "BAG_CONTAINER_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED", "INVENTORY_SEARCH_UPDATE" }) do
    WK:On(ev, soonRepaint)
end
if _G.hooksecurefunc then
    for _, fn in ipairs({ "ToggleBackpack", "ToggleBag", "OpenAllBags", "ToggleAllBags", "OpenBackpack" }) do
        if _G[fn] then _G.hooksecurefunc(fn, soonRepaint) end
    end
end
WK:On("PLAYER_REGEN_ENABLED", function() UI:RefreshItemLocks() end)
-- Clic n'importe où : Alt + clic gauche sur une case de sac connue
pcall(driver.RegisterEvent, driver, "GLOBAL_MOUSE_DOWN")
pcall(driver.RegisterEvent, driver, "GLOBAL_MOUSE_UP")
driver:SetScript("OnEvent", function(_, ev, button)
    if ev == "GLOBAL_MOUSE_UP" then
        -- le OnClick de la case passe au relâchement : on attend l'image suivante pour effacer
        if pressAt then C_Timer.After(0, function() pressAt = nil end) end
        return
    end
    if ev ~= "GLOBAL_MOUSE_DOWN" or not modDown(button) or not WK:FeatureOn("inventory") then return end
    if L:MerchantOpen() then return end -- chez le marchand, le cache de la case s'en occupe
    -- d'abord la case réellement sous la souris (les cases recyclées d'une liste qui défile changent d'objet)
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = (foci and foci[1]) or (GetMouseFocus and GetMouseFocus())
    local hit = findBagButton(focus)
    if hit then local r = rootOf(hit); if r then roots[r] = true end end
    if not hit then eachButton(function(b) if not hit and b:IsVisible() and b:IsMouseOver() then hit = b end end) end
    if hit then
        pressAt = GetTime()
        UI.ItemLockAltClick(hit)
    end
end)

---------------------------------------------------------------------------
-- Infobulle
---------------------------------------------------------------------------
local function onTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local id = data and data.id
    if not id and tt.GetItem then local _, link = tt:GetItem(); id = link and WK:ParseItemID(link) end
    if id and tt == GameTooltip and tt.GetOwner and not inCombat() then learnButton(tt:GetOwner(), id) end
    local why = id and L:Reason(id)
    if not why then return end
    if why == "manual" then
        local r, g, b = UI:Accent()
        tt:AddLine(T("Verrouillé : ne sera pas vendu") .. " (" .. keyLabel() .. ")", r, g, b)
    else
        tt:AddLine(string.format(T("Verrouillé par règle : %s"), why), C.rule[1], C.rule[2], C.rule[3])
    end
    tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(onTooltip, tt, data) end)
end

---------------------------------------------------------------------------
-- /wk sacs : ce que l'addon voit des sacs (si le cadenas ou l'étoile n'apparaissent pas)
---------------------------------------------------------------------------
function UI:BagDiag()
    local out = {}
    local frames = {}
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then table.insert(frames, "ContainerFrame" .. i) end
    end
    if _G.ContainerFrameCombinedBags and _G.ContainerFrameCombinedBags:IsShown() then table.insert(frames, "ContainerFrameCombinedBags") end
    table.insert(out, "Sacs du jeu ouverts : " .. (#frames > 0 and table.concat(frames, ", ") or "aucun"))
    local n, withItem, deco = 0, 0, 0
    eachButton(function(b)
        n = n + 1
        local bag, slot = bagSlot(b)
        if itemAt(bag, slot) then withItem = withItem + 1 end
        if b.wkLock then deco = deco + 1 end
    end)
    local k = 0
    for _ in pairs(known) do k = k + 1 end
    table.insert(out, string.format("Cases trouvées : %d (%d avec un objet, %d décorées ; %d repérées au survol)", n, withItem, deco, k))
    for r in pairs(roots) do
        local c = 0
        if r:IsVisible() then walk(r, function() c = c + 1 end, 0) end
        table.insert(out, string.format("Sac %s : %s, %d cases trouvées dedans", (r.GetName and r:GetName()) or "?", r:IsVisible() and "visible" or "caché", c))
    end
    table.insert(out, "(* = cadre avec GetBagID)")
    table.insert(out, "Module Inventaire : " .. (WK:FeatureOn("inventory") and "actif" or "coupé") .. " ; touche : " .. tostring(L:Config().key))
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    local f = foci and foci[1]
    if f then
        local chain = {}
        local p = f
        for _ = 1, 5 do
            if not p then break end
            table.insert(chain, ((p.GetName and p:GetName()) or ("<" .. (p.GetObjectType and p:GetObjectType() or "?") .. ">"))
                .. (p.GetBagID and "*" or ""))
            p = p.GetParent and p:GetParent()
        end
        local bag, slot = bagSlot(f)
        table.insert(out, "Sous la souris : " .. table.concat(chain, " < ") .. string.format(" (sac %s, case %s, GetBagID %s)", tostring(bag), tostring(slot), f.GetBagID and "oui" or "non"))
    else
        table.insert(out, "Sous la souris : rien (tape la commande en survolant un objet du sac, par une macro)")
    end
    -- toutes les cases connues sous la souris : laquelle porte le cadenas, et est-il visible ?
    local function nm(b) return (b.GetName and b:GetName()) or ("<" .. (b.GetObjectType and b:GetObjectType() or "?") .. ">") end
    eachButton(function(b)
        if b:IsVisible() and b:IsMouseOver() then
            local bag, slot = bagSlot(b)
            local id = itemAt(bag, slot)
            local o = b.wkLock
            local w, h = b:GetSize()
            table.insert(out, string.format("Case %s (parent %s) : sac %s case %s, objet %s, verrou %s, cadenas %s, alpha %.2f, taille %dx%d, niveau %d / cadenas %s",
                nm(b), b:GetParent() and nm(b:GetParent()) or "?", tostring(bag), tostring(slot), tostring(id),
                tostring(id and L:Reason(id)), o and (o.badge:IsShown() and (o.badge:IsVisible() and "visible" or "montré mais caché") or "masqué") or "aucun",
                b.GetEffectiveAlpha and b:GetEffectiveAlpha() or -1, w or 0, h or 0, b:GetFrameLevel(), o and tostring(o:GetFrameLevel()) or "-"))
        end
    end)
    return out
end
