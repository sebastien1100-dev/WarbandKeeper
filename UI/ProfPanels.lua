local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Fenêtres des aides de métiers (Modules/ProfHelp.lua) :
--   désenchanter ou vendre (collée aux sacs, /wk de), enchantements à l'échange (collée à la fenêtre
--   d'échange), recettes à apprendre (collée au maître de métier), HUD de la file de fabrication
--   (fenêtre du métier ouverte), et la carte « Avant de partir » d'Inventaire (UI:BuildPrepPane).
local function PH() return WK.modules.ProfHelp end
local function cfg() return PH():Config() end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
-- Panneaux qui contiennent un bouton protégé : on ne peut pas les cacher en combat ; ils deviennent
-- invisibles et sont cachés pour de bon à la sortie du combat
local hideLater = {}
local function safeHide(f)
    if not inCombat() then f:Hide() return end
    f:SetAlpha(0)
    hideLater[f] = true
end
WK:On("PLAYER_REGEN_ENABLED", function()
    for f in pairs(hideLater) do f:Hide(); f:SetAlpha(1) end
    wipe(hideLater)
end)
local ROW = 30

-- Panneau de base : titre, fermer, liste défilante, pied pour les boutons.
local function panel(name, title, icon, w, h)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(w, h)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, icon, 16, nil, "ARTWORK"); f.logo:SetPoint("TOPLEFT", 14, -12)
    f.logo:SetVertexColor(UI:Accent())
    f.title = UI:Text(f, 12); f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0); f.title:SetText(title)
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 16, -32); f.sub:SetPoint("RIGHT", -16, 0)
    f.close = UI:IconButton(f, "close", 16); f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f.closed = true; safeHide(f) end)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 6, -50)
    f.scroll:SetPoint("BOTTOMRIGHT", -6, 74)
    f.note = UI:Text(f, 10, C.muted); f.note:SetPoint("BOTTOMLEFT", 16, 12); f.note:SetPoint("RIGHT", -16, 0)
    f.note:SetJustifyH("LEFT")
    if f.note.SetWordWrap then f.note:SetWordWrap(true) end
    f:Hide()
    return f
end

-- Bouton protégé (sort, macro) avec l'apparence d'un bouton du thème : l'habit ne prend pas la souris.
-- Boutons protégés des panneaux : désarmés juste avant le combat (dernier moment permis). En combat, on ne
-- peut plus reposer la case visée : un objet arrivé dans la case libérée (un épique ramassé) aurait été
-- désenchanté, y compris depuis un panneau fermé devenu seulement invisible. Réarmés par Refresh après.
local secureButtons = {}
WK:On("PLAYER_REGEN_DISABLED", function()
    for _, b in ipairs(secureButtons) do b:SetAttribute("type", nil); b.itemID = nil end
end)
WK:On("PLAYER_REGEN_ENABLED", function()
    _G.C_Timer.After(0.2, function()
        if inCombat() then return end
        for _, b in ipairs(secureButtons) do
            local f = b:GetParent()
            if f and f:IsShown() and f.Refresh then pcall(f.Refresh, f) end
        end
    end)
end)
local function secureButton(parent, label, w, style)
    local s = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    secureButtons[#secureButtons + 1] = s
    s:SetSize(w, 28)
    if s.RegisterForClicks then s:RegisterForClicks("AnyUp", "AnyDown") end
    s.look = UI:Button(s, label, w, 28, style or "primary")
    s.look:SetAllPoints()
    s.look:EnableMouse(false)
    s:SetScript("OnEnter", function() s.look.hover = true; s.look:Refresh() end)
    s:SetScript("OnLeave", function() s.look.hover = false; s.look:Refresh() end)
    return s
end

local function rowBase(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ROW)
    if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r.bg = UI:Rounded(r, 8, 0, "BACKGROUND", 1)
    r.bg:SetColor(unpack(C.hover)); r.bg:Hide()
    r.icon = UI:RoundIcon(r, 20); r.icon:SetPoint("LEFT", 8, 0)
    r.name = UI:Text(r, 11); r.name:SetPoint("TOPLEFT", 34, -3)
    r.sub = UI:Text(r, 9, C.muted); r.sub:SetPoint("TOPLEFT", 34, -16)
    r.right = UI:Text(r, 11); r.right:SetPoint("RIGHT", -8, 0); r.right:SetJustifyH("RIGHT")
    r.pill = UI:Badge(r, ""); r.pill:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
    r.name:SetPoint("RIGHT", r.pill, "LEFT", -6, 0); r.sub:SetPoint("RIGHT", r.pill, "LEFT", -6, 0)
    r:SetScript("OnLeave", function(s) if not s.sel then s.bg:Hide() end; GameTooltip:Hide() end)
    return r
end

local function place(pool, scroll)
    local y = 0
    for _, r in ipairs(pool.items or {}) do
        if r:IsShown() then
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            y = y + ROW + 2
        end
    end
    scroll:SetContentHeight(y)
end

---------------------------------------------------------------------------
-- Désenchanter ou vendre
---------------------------------------------------------------------------
local de
local ADVICE = { de = { "Désenchanter", "positive" }, ah = { "Vendre à l'HV", "accent" }, vendor = { "Vendre", "muted" } }
local function buildDE()
    local f = panel("WarbandKeeperDEPanel", T("Désenchanter ou vendre ?"), "spark", 360, 380)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.rows = UI:Pool(function()
        local r = rowBase(f.scroll.child)
        r:SetScript("OnEnter", function(s)
            s.bg:Show()
            if not s.e then return end
            UI:TooltipOwner(s, "ANCHOR_LEFT")
            if s.e.link then GameTooltip:SetHyperlink(s.e.link) else GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:Show()
        end)
        return r
    end)
    f.go = secureButton(f, T("Désenchanter le suivant"), 200)
    f.go:SetPoint("BOTTOMLEFT", 14, 40)
    -- la case visée a pu changer depuis le dernier rafraîchissement (tri, objet déplacé) : on revérifie
    -- l'objet juste avant le clic, sinon la macro est vidée et rien n'est désenchanté
    f.go:SetScript("PreClick", function(s)
        local id, _, locked = nil, nil, nil
        if s.bag then id, _, locked = WK.Container.Info(s.bag, s.slot) end
        local IL = WK.modules.ItemLock
        -- case verrouillée par le jeu (objet en cours d'utilisation, double clic) : refusée aussi
        local ok = id and id == s.itemID and not locked and not (IL and IL.Reason and IL:Reason(id, s.bag, s.slot))
        if not ok then
            if not inCombat() then s:SetAttribute("type", nil) end
            if f.Refresh then _G.C_Timer.After(0.1, function() f:Refresh() end) end
            return
        end
        PH():ExpectDE(s.itemID)
    end)
    f.total = UI:Text(f, 11); f.total:SetPoint("LEFT", f.go, "RIGHT", 10, 0)
    f.note:SetText(T("Un clic par objet (le jeu l'exige). Les objets verrouillés sont laissés de côté."))

    function f:Refresh()
        local list = PH():DEBagItems()
        local rank = PH():EnchantRank() or 0
        f.sub:SetText(string.format(T("Enchantement %d · %d objet(s)"), rank, #list))
        f.rows:Reset()
        local nextOne, total = nil, 0
        for _, e in ipairs(list) do
            local r = f.rows:Get(); r.e = e
            local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
            r.icon:SetTexture(icon)
            r.name:SetText(name or "?"); r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
            local first = e.a.list[1]
            local gives = first and string.format("%s %s", string.format(first[2] >= 1 and "%.1f" or "%.2f", first[2]):gsub("%.?0+$", ""):gsub("%.", ","), (UI:ItemInfo(first[1])) or "?") or ""
            if e.high then
                r.sub:SetText(UI:Hex(C.negative) .. string.format(T("trop haut (%d)"), e.a.skill) .. "|r")
                r.pill:Set(T("Vendre"), C.muted)
            else
                r.sub:SetText(gives .. "  ·  " .. string.format(T("HV %s · marchand %s"), e.a.ah and WK:FormatMoney(e.a.ah) or "-", WK:FormatMoney(e.a.vendor)))
                local adv = ADVICE[e.a.advice]
                r.pill:Set(T(adv[1]), adv[2] == "accent" and nil or C[adv[2]])
                if e.a.advice == "de" then
                    total = total + e.a.value
                    nextOne = nextOne or e
                end
            end
            r.right:SetText(UI:GoldText(math.floor(e.a.value)))
            r:Show()
        end
        place(f.rows, f.scroll)
        f.total:SetText(total > 0 and (T("attendu : ") .. UI:GoldText(math.floor(total))) or "")
        if not inCombat() then
            local spell = WK.SpellInfo(PH().DE_SPELL)
            if nextOne and spell then
                -- sort lancé sur la case par le bouton protégé du jeu (target-bag / target-slot) : l'objet n'est
                -- visé que si le sort attend une cible ; avant, la macro « /cast » puis « /use » utilisait l'objet
                -- quand le sort échouait (recharge, déplacement) : un équipement aurait été équipé, donc lié
                f.go:SetAttribute("macrotext", nil)
                f.go:SetAttribute("type", "spell")
                f.go:SetAttribute("spell", spell)
                f.go:SetAttribute("target-bag", nextOne.bag)
                f.go:SetAttribute("target-slot", nextOne.slot)
                f.go.itemID, f.go.bag, f.go.slot = nextOne.id, nextOne.bag, nextOne.slot
                f.go:Show()
            else
                f.go:SetAttribute("type", nil)
                f.go:SetAttribute("spell", nil)
                f.go.itemID = nil
                f.go:Hide()
            end
        end
    end
    return f
end

local function bagFrame()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return ContainerFrameCombinedBags end
    if ContainerFrame1 and ContainerFrame1:IsShown() then return ContainerFrame1 end
end

function UI:ToggleDEPanel(show, anchor)
    if inCombat() then return end
    if not de then de = buildDE() end
    if show == false or (show == nil and de:IsShown()) then de:Hide() return end
    de.closed = nil
    de:ClearAllPoints()
    if anchor then de:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0); UI:MatchHost(de, anchor)
    else de:SetPoint("CENTER", -200, 60); de:SetFrameStrata("HIGH") end
    hideLater[de] = nil; de:SetAlpha(1)
    de:Refresh(); de:Show()
end

-- Collée aux sacs : enchanteur avec au moins un objet à désenchanter.
local function autoDE()
    if inCombat() or not cfg().dePanel or not PH():EnchantRank() then return end
    local bf = bagFrame()
    if not bf then if de and de.auto then de:Hide(); de.auto = nil end return end
    if de and (de.closed or (de:IsShown() and not de.auto)) then return end
    for _, e in ipairs(PH():DEBagItems()) do
        if e.a.advice == "de" and not e.high then
            UI:ToggleDEPanel(true, bf); de.auto = true
            return
        end
    end
end
local deTimer
local function soonDE()
    if deTimer then return end
    deTimer = true
    C_Timer.After(0.3, function()
        deTimer = nil
        if de and de:IsShown() and not inCombat() then de:Refresh() end
        autoDE()
    end)
end
WK:On("BAG_UPDATE_DELAYED", soonDE)
WK:On("PLAYER_REGEN_ENABLED", soonDE)
WK:On("PLAYER_LOGIN", function()
    for _, n in ipairs({ "ContainerFrameCombinedBags", "ContainerFrame1" }) do
        local bf = _G[n]
        if bf and bf.HookScript then
            bf:HookScript("OnShow", function() if de then de.closed = nil end; soonDE() end)
            bf:HookScript("OnHide", function() C_Timer.After(0, function() if de and de.auto and not bagFrame() and not inCombat() then de:Hide(); de.auto = nil end end) end)
        end
    end
end)

---------------------------------------------------------------------------
-- Enchantements à l'échange
---------------------------------------------------------------------------
local trade
local function buildTrade()
    local f = panel("WarbandKeeperTradeEnchants", T("Enchanter son objet"), "spark", 330, 330)
    f.rows = UI:Pool(function()
        local r = rowBase(f.scroll.child)
        r:SetScript("OnEnter", function(s)
            s.bg:Show()
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e.name, 1, 1, 1)
            for _, rg in ipairs(s.e.reagents or {}) do
                local have = (WK.DB:Me().bags or {})[rg[1]] or 0
                local ok = have >= rg[2]
                GameTooltip:AddDoubleLine((UI:ItemInfo(rg[1])) or "?", have .. " / " .. rg[2], 0.85, 0.85, 0.85, ok and 0.6 or 1, ok and 0.9 or 0.4, ok and 0.5 or 0.4)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("Clic : choisir · clic droit : favori"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnClick", function(s, btn)
            if btn == "RightButton" then PH():ToggleFav(s.e.name); f:Refresh() return end
            if inCombat() then return end
            f.pick = s.e.name
            f:Refresh()
        end)
        return r
    end)
    f.cast = secureButton(f, T("Lancer l'enchantement"), 170)
    f.cast:SetPoint("BOTTOMLEFT", 14, 40)
    f.ad = UI:Button(f, T("Annoncer"), nil, 28, "secondary")
    f.ad:SetPoint("LEFT", f.cast, "RIGHT", 8, 0)
    f.ad:SetScript("OnClick", function() local t = PH():EnchantAd(); if t then WK.ChatInsert(t) end end)
    f.ad.tooltip = "Écrit la liste de tes enchantements (favoris d'abord) dans la ligne de chat."
    f.note:SetText(T("L'objet va dans « Ne sera pas échangé » ; après le sort, clique dessus."))

    function f:Refresh()
        local link = GetTradeTargetItemLink and GetTradeTargetItemLink(7)
        local loc
        if link then loc = select(9, WK.GetItemInfo(link)) end
        local list = PH():Enchants(link and loc or nil)
        f.sub:SetText(link and string.format(T("pour %s"), link) or T("pose l'objet dans « Ne sera pas échangé »"))
        f.rows:Reset()
        local found = false
        for _, e in ipairs(list) do
            local r = f.rows:Get(); r.e = e
            r.icon:SetTexture(e.icon or "Interface\\Icons\\Trade_Engraving")
            r.name:SetText((e.fav and (UI:Hex(C.gold) .. "*|r ") or "") .. e.name); r.name:SetTextColor(unpack(C.text))
            r.sub:SetText("")
            r.right:SetText(e.have and (UI:Hex(C.positive) .. T("oui") .. "|r") or (UI:Hex(C.negative) .. string.format(T("manque %d"), e.missing) .. "|r"))
            r.pill:Set("", nil); r.pill:Hide()
            r.sel = (f.pick == e.name)
            r.bg:SetShown(r.sel)
            if r.sel then found = true end
            r:Show()
        end
        if not found then f.pick = nil end
        place(f.rows, f.scroll)
        if not inCombat() then
            if f.pick then
                f.cast:SetAttribute("type", "spell"); f.cast:SetAttribute("spell", f.pick)
            else
                f.cast:SetAttribute("type", nil)
            end
            f.cast:SetAlpha(f.pick and 1 or 0.4)
        end
        f.ad:SetShown(#PH():Enchants(nil) > 0)
    end
    return f
end

local function tradeWanted() return cfg().trade and PH():EnchantRank() ~= nil and TradeFrame ~= nil end
WK:On("TRADE_SHOW", function()
    if not tradeWanted() or inCombat() then return end
    if #PH():Enchants(nil) == 0 then return end
    if not trade then trade = buildTrade() end
    trade.pick = nil
    trade:ClearAllPoints(); trade:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 6, 0)
    UI:MatchHost(trade, TradeFrame)
    hideLater[trade] = nil; trade:SetAlpha(1)
    trade:Refresh(); trade:Show()
end)
WK:On("TRADE_TARGET_ITEM_CHANGED", function() if trade and trade:IsShown() and not inCombat() then trade:Refresh() end end)
WK:On("TRADE_CLOSED", function() if trade then safeHide(trade) end end)

---------------------------------------------------------------------------
-- Maître de métier
---------------------------------------------------------------------------
local trainer
local function buildTrainer()
    local f = panel("WarbandKeeperTrainerHelp", T("À apprendre ici"), "star", 330, 340)
    f.rows = UI:Pool(function()
        local r = rowBase(f.scroll.child)
        r:SetScript("OnEnter", function(s)
            s.bg:Show()
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e.name, 1, 1, 1)
            GameTooltip:AddLine(T("Clic : apprendre · clic droit : favori"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnClick", function(s, btn)
            if btn == "RightButton" then PH():ToggleFav(s.e.name); f:Refresh() return end
            -- un seul achat par ligne jusqu'au rafraîchissement (TRAINER_UPDATE refait les lignes)
            if s.bought == s.e or (GetMoney and GetMoney() or 0) < s.e.cost then return end
            if PH():BuyService(s.e.index, s.e.name) then s.bought = s.e end
        end)
        return r
    end)
    f.learn = UI:Button(f, T("Apprendre les favoris"), nil, 28, "primary")
    f.learn:SetPoint("BOTTOMLEFT", 14, 40)
    f.learn:SetScript("OnClick", function()
        local n = PH():LearnFavs()
        if n > 0 then WK:Print(string.format(T("%d recette(s) apprise(s)."), n)) end
    end)
    f.note:SetText(T("Étoile : clic droit sur une recette, ici ou dans Métiers > Recettes à apprendre."))

    function f:Refresh()
        local list = PH():TrainerList()
        local favs, favCost, useful = 0, 0, 0
        f.rows:Reset()
        for _, e in ipairs(list) do
            local r = f.rows:Get(); r.e = e
            r.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
            r.name:SetText((e.fav and (UI:Hex(C.gold) .. "*|r ") or "") .. e.name); r.name:SetTextColor(unpack(C.text))
            r.sub:SetText("")
            if e.guideTo then r.pill:Set(string.format(T("monte jusqu'à %d"), e.guideTo), C.positive); useful = useful + 1
            elseif e.knownBy then
                local c = WK.DB.global.characters[e.knownBy]
                r.pill:Set(string.format(T("déjà connu de %s"), c and WK:CharName(c, e.knownBy) or "?"), C.muted)
            else r.pill:Set("", nil); r.pill:Hide() end
            if e.guideTo or e.knownBy then r.pill:Show() end
            r.right:SetText(UI:GoldText(e.cost))
            if e.fav then favs = favs + 1; favCost = favCost + e.cost end
            r:Show()
        end
        place(f.rows, f.scroll)
        f.sub:SetText(string.format(T("%d favori(s), %d utile(s) pour le guide"), favs, useful))
        f.learn:SetLabel(favs > 0 and (T("Apprendre les favoris") .. " (" .. WK:FormatMoney(favCost) .. ")") or T("Apprendre les favoris"))
        f.learn:SetWidth(f.learn.label:GetStringWidth() + 32)
        f.learn:SetShown(favs > 0)
        f:SetShown(#list > 0)
    end
    return f
end
local function trainerFrame() return ClassTrainerFrame end
local function trainerRefresh()
    if not cfg().trainer then return end
    if IsTradeskillTrainer and not IsTradeskillTrainer() then if trainer then trainer:Hide() end return end
    local tf = trainerFrame()
    if not tf then return end
    if not trainer then trainer = buildTrainer() end
    trainer:ClearAllPoints(); trainer:SetPoint("TOPLEFT", tf, "TOPRIGHT", 6, 0)
    UI:MatchHost(trainer, tf)
    trainer:Refresh()
end
WK:On("TRAINER_SHOW", function() C_Timer.After(0.1, trainerRefresh) end)
WK:On("TRAINER_UPDATE", function() if trainer and trainer:IsShown() then trainerRefresh() end end)
WK:On("TRAINER_CLOSED", function() if trainer then trainer:Hide() end end)

---------------------------------------------------------------------------
-- HUD de la file de fabrication (fenêtre du métier ouverte)
---------------------------------------------------------------------------
local hud
local hudPick = 1
local function hudEntries()
    local prof = PH():OpenProfession()
    local out = {}
    for _, e in ipairs(PH():Queue()) do
        if e.mine and e.rec and (not prof or e.rec.prof == prof) then table.insert(out, e) end
    end
    return out
end
local function buildHUD()
    local f = CreateFrame("Frame", "WarbandKeeperCraftHUD", UIParent)
    f:SetSize(240, 74)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 10, C.surface, C.border)
    f.title = UI:Text(f, 10, C.muted); f.title:SetPoint("TOPLEFT", 12, -8); f.title:SetText(T("File de fabrication"))
    f.name = UI:Text(f, 12); f.name:SetPoint("TOPLEFT", 12, -22); f.name:SetPoint("RIGHT", -60, 0)
    f.count = UI:Text(f, 12); f.count:SetPoint("TOPRIGHT", -12, -22); f.count:SetJustifyH("RIGHT")
    f.bar = UI:Progress(f, 5); f.bar:SetPoint("TOPLEFT", 12, -40); f.bar:SetPoint("RIGHT", -12, 0)
    f.make = UI:Button(f, T("Fabriquer"), nil, 22, "primary"); f.make:SetPoint("BOTTOMLEFT", 10, 6)
    f.skip = UI:Button(f, T("Suivant"), nil, 22, "ghost"); f.skip:SetPoint("LEFT", f.make, "RIGHT", 6, 0)
    f.make:SetScript("OnClick", function()
        local e = f.e
        if e then PH():Craft(e.key, math.max(1, math.min(e.qty, e.can or e.qty))) end
    end)
    f.skip:SetScript("OnClick", function() hudPick = hudPick + 1; UI:RefreshCraftHUD() end)
    UI:RegisterHUD("craftQueue", f, { label = T("File de fabrication"), default = { 0, -180 },
        enabled = function() return cfg().queueHud end,
        sample = function()
            f.name:SetText(T("Potion de soins supérieure")); f.count:SetText("4 / 20"); f.bar:SetValue(0.2)
        end })
    f:Hide()
    return f
end
local profOpen = false
function UI:RefreshCraftHUD()
    if not hud then hud = buildHUD() end
    if UI.editing then return end
    local list = (profOpen and cfg().queueHud) and hudEntries() or {}
    if #list == 0 then hud:Hide() return end
    if hudPick > #list then hudPick = 1 end
    local e = list[hudPick]
    hud.e = e
    local done = PH().session[e.key] or 0
    hud.name:SetText(e.rec.name)
    hud.count:SetText(done .. " / " .. (done + e.qty))
    hud.bar:SetValue(done / math.max(1, done + e.qty))
    local can = e.can or 0
    hud.make:SetLabel(can > 0 and string.format(T("Fabriquer %d"), math.min(e.qty, can)) or T("Composants manquants"))
    hud.make:SetWidth(hud.make.label:GetStringWidth() + 28)
    hud.make:SetEnabled(can > 0)
    hud.skip:SetShown(#list > 1)
    hud:Show()
end
WK:On("TRADE_SKILL_SHOW", function() profOpen = true; C_Timer.After(0.5, function() UI:RefreshCraftHUD() end) end)
WK:On("TRADE_SKILL_CLOSE", function() profOpen = false; if hud then hud:Hide() end end)
WK:On("BAG_UPDATE_DELAYED", function() if profOpen and hud then UI:RefreshCraftHUD() end end)
WK:On("PLAYER_LOGIN", function() if not hud then hud = buildHUD() end end)

---------------------------------------------------------------------------
-- Carte « Avant de partir » (Inventaire)
---------------------------------------------------------------------------
function UI:BuildPrepPane(parent)
    local pane = UI:Scroll(parent)
    local card = UI:Card(pane.child, T("Avant de partir"), " ")
    card:SetPoint("TOPLEFT"); card:SetPoint("TOPRIGHT")
    local seg = UI:Segmented(card, { { "dungeon", "Donjon" }, { "raid", "Raid" }, { "pvp", "JcJ" } }, function(k)
        cfg().prepMode = k; pane:Refresh()
    end, 26)
    seg:SetPoint("TOPRIGHT", -14, -10)
    local cols = { { "BUT", 16 }, { "CONSOMMABLE", 110 }, { "SACS", -380 }, { "AILLEURS", -300 }, { "OÙ L'AVOIR", -150 }, { "SEUIL", -16 } }
    for _, cdef in ipairs(cols) do
        local h = UI:Text(card, 9, C.dim); h:SetText(T(cdef[1]))
        if cdef[2] > 0 then h:SetPoint("TOPLEFT", cdef[2], -46) else h:SetPoint("TOPRIGHT", cdef[2], -46); h:SetJustifyH("RIGHT") end
    end
    local rows = {}
    local function row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, card)
        r:SetHeight(30)
        r.label = UI:Text(r, 11, C.muted); r.label:SetPoint("LEFT", 16, 0)
        r.icon = UI:RoundIcon(r, 18); r.icon:SetPoint("LEFT", 110, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 134, 0); r.name:SetPoint("RIGHT", -400, 0)
        r.bags = UI:Text(r, 12); r.bags:SetPoint("RIGHT", -380, 0); r.bags:SetJustifyH("RIGHT")
        r.else_ = UI:Text(r, 10, C.muted); r.else_:SetPoint("RIGHT", -300, 0); r.else_:SetJustifyH("RIGHT")
        r.how = UI:Text(r, 10, C.muted); r.how:SetPoint("RIGHT", -150, 0); r.how:SetJustifyH("RIGHT")
        r.min = UI:NumberInput(r, 56, 24, "0"); r.min:SetPoint("RIGHT", -16, 0)
        r.min.edit:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
        r.min.edit:SetScript("OnEditFocusLost", function()
            if r.cat then cfg().prepMin[r.cat] = math.max(0, math.min(999, r.min:GetNumber())); pane:Refresh() end
        end)
        r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetHeight(1); r.line:SetPoint("TOPLEFT", 12, 0); r.line:SetPoint("TOPRIGHT", -12, 0)
        r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
        rows[i] = r
        return r
    end
    local alert = UI:SettingRow(card, 0, "Rappel dans « À faire »", "Une ligne quand un consommable du perso connecté passe sous son seuil.",
        UI:Toggle(card, function() return cfg().prepAlert end, function(v) cfg().prepAlert = v; WK:NotifyChanged() end), 80)
    local note = UI:Text(card, 10, C.muted); note:SetJustifyH("LEFT")
    if note.SetWordWrap then note:SetWordWrap(true) end
    note:SetText(T("Le meilleur objet de chaque sorte pour ton niveau ; rouge : sous le seuil. Seuils x2 en raid ; en JcJ, pas d'élixir et moitié de nourriture."))

    function pane:Refresh()
        local W = math.max(500, (pane:GetWidth() or 700) - 14)
        pane.child:SetWidth(W)
        local ck = WK:CharKey()
        local c = WK.DB.global.characters[ck] or {}
        seg:Select(cfg().prepMode)
        card.subtitle:SetText(string.format(T("pour %s, niveau %d"), WK:CharName(c, ck), c.level or 0))
        local list = PH():Prep(ck)
        local y = 62
        for i, e in ipairs(list) do
            local r = row(i)
            r.cat = e.cat
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            r.label:SetText(T(e.label))
            local name, icon = UI:ItemInfo(e.best)
            r.icon:SetTexture(icon); r.name:SetText(name or "?")
            r.bags:SetText(tostring(e.bags)); r.bags:SetTextColor(unpack(e.low and C.negative or C.positive))
            local bits = {}
            for _, o in ipairs(e.elsewhere) do
                local oc = WK.DB.global.characters[o[1]]
                if #bits < 2 then table.insert(bits, o[2] .. " " .. (o.bank and T("banque") or (oc and WK:CharName(oc, o[1]) or "?"))) end
            end
            r.else_:SetText(#bits > 0 and table.concat(bits, ", ") or "-")
            if e.howKind == "craft" then
                local who = e.how[1]
                local oc = WK.DB.global.characters[who]
                r.how:SetText(who == ck and T("tu sais le fabriquer") or string.format(T("%s sait le fabriquer"), oc and WK:CharName(oc, who) or "?"))
            elseif e.howKind == "ah" then r.how:SetText(T("HV ") .. UI:GoldText(e.how))
            elseif e.howKind == "vendor" then r.how:SetText(T("marchand ") .. UI:GoldText(e.how))
            else r.how:SetText("") end
            if not r.min.edit:HasFocus() then r.min.edit:SetText(tostring(e.min)) end
            r:Show()
            y = y + 32
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        alert:ClearAllPoints(); alert:SetPoint("TOPLEFT", 16, -(y + 8)); alert:SetPoint("TOPRIGHT", -16, -(y + 8))
        y = y + 8 + 46
        note:ClearAllPoints(); note:SetPoint("TOPLEFT", 16, -y); note:SetWidth(W - 32)
        y = y + 34
        card:SetHeight(y)
        pane:SetContentHeight(y + 10)
    end
    return pane
end

---------------------------------------------------------------------------
-- Barre de fabrication : temps TOTAL d'une série (« Créer tout » ou une quantité), comme une barre
-- d'incantation. Série repérée en accrochant C_TradeSkillUI.CraftRecipe / DoTradeSkill (quantité),
-- fabrications comptées sur UNIT_SPELLCAST_SUCCEEDED du joueur (le sort de la 1re incantation qui suit).
-- Durée par fabrication : celle de l'incantation, puis la moyenne mesurée entre deux fabrications.
-- Réglages cfg().craftBar* (carte « Barre de fabrication » de la roue de Métiers) ; HUD « craftBar ».
---------------------------------------------------------------------------
local cbar, batch
local TICKS = 40
local function mmss(sec)
    sec = math.max(0, math.floor((sec or 0) + 0.5))
    if sec >= 3600 then return string.format("%d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60) end
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
local function profRank(prof)
    local c = WK.DB.global.characters[WK:CharKey()]
    local p = prof and c and c.professions and c.professions[prof]
    return p and p.rank
end
-- temps restant et durée d'une fabrication
local function remaining(b)
    local now = GetTime()
    local per = b.per or ((b.castDur or 3) + 0.35)
    local left = b.n - b.done
    local cur = 0
    if b.casting and b.castEnd then cur = math.max(0, b.castEnd - now); left = left - 1 end
    return cur + math.max(0, left) * per, per
end
local function tradeFrame()
    for _, n in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
        local f = _G[n]
        if f and f:IsShown() then return f end
    end
end

local function buildBar()
    local f = CreateFrame("Frame", "WarbandKeeperCraftBar", UIParent)
    f:SetSize(460, 64)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 10, C.surface, C.border)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(36, 36); f.icon:SetPoint("LEFT", 12, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.stop = UI:Button(f, T("Arrêter"), nil, 22, "secondary")
    f.stop:SetPoint("RIGHT", -10, 0)
    f.name = UI:Text(f, 13); f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 2)
    f.count = UI:Text(f, 11, C.muted); f.count:SetPoint("LEFT", f.name, "RIGHT", 8, 0)
    f.left = UI:Text(f, 13); f.left:SetPoint("TOPRIGHT", f.stop, "TOPLEFT", -10, 8); f.left:SetJustifyH("RIGHT")
    f.bar = UI:Progress(f, 10)
    f.bar:SetPoint("LEFT", f.icon, "RIGHT", 10, 0); f.bar:SetPoint("RIGHT", f.stop, "LEFT", -10, 0)
    f.ticks = {}
    for i = 1, TICKS do
        local t = f.bar:CreateTexture(nil, "OVERLAY"); t:SetWidth(1); t:SetColorTexture(0, 0, 0, 0.45)
        t:SetPoint("TOP"); t:SetPoint("BOTTOM"); t:Hide()
        f.ticks[i] = t
    end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 10, -3)
    f.skill = UI:Text(f, 10, C.muted); f.skill:SetPoint("BOTTOMRIGHT", f.stop, "BOTTOMLEFT", -10, -9); f.skill:SetJustifyH("RIGHT")
    f.stop:SetScript("OnClick", function()
        if C_TradeSkillUI and C_TradeSkillUI.StopRecipeRepeat then pcall(C_TradeSkillUI.StopRecipeRepeat)
        elseif StopTradeSkillRepeat then pcall(StopTradeSkillRepeat) end
        UI:EndCraftBar(true)
    end)
    -- repères : une marque par fabrication (si la série n'est pas trop longue)
    function f:Ticks(n)
        local w = self.bar:GetWidth() or 0
        for i, t in ipairs(self.ticks) do
            if n > 1 and n <= TICKS + 1 and i < n and w > 0 then
                t:ClearAllPoints(); t:SetPoint("TOP", self.bar, "TOPLEFT", w * i / n, 0); t:SetPoint("BOTTOM", self.bar, "BOTTOMLEFT", w * i / n, 0)
                t:Show()
            else t:Hide() end
        end
    end
    function f:Fill(name, icon, done, n, left, per, sub2, skill)
        self.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.name:SetText(name or "?")
        self.count:SetText(done .. " / " .. n)
        self.left:SetText(string.format(T("reste %s"), mmss(left)))
        self:Ticks(n)
        self.sub:SetText(sub2 or "")
        self.skill:SetText(skill or "")
        self.stop:SetShown((C_TradeSkillUI and C_TradeSkillUI.StopRecipeRepeat or StopTradeSkillRepeat) ~= nil)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 0.1 or not batch then return end
        s.acc = 0
        UI:RefreshCraftBar()
    end)
    UI:RegisterHUD("craftBar", f, { label = T("Barre de fabrication"), default = { 0, -120 },
        enabled = function() return cfg().craftBar and cfg().craftBarWhere ~= "trade" end,
        sample = function(on)
            if not on then return end
            f:Fill(T("Bandage en lin épais"), "Interface\\Icons\\INV_Misc_Bandage_17", 7, 20, 39, 3,
                T("3 s par fabrication") .. " · " .. string.format(T("fin vers %s"), date("%H:%M", time() + 39)), T("Secourisme 128 (+3)"))
            f.bar:SetValue(0.35)
        end,
        test = function() UI:TestCraftBar() end,
        testStop = function() UI:EndCraftBar(true) end })
    f:Hide()
    return f
end

function UI:RefreshCraftBar()
    if not cbar then cbar = buildBar() end
    if UI.editing then return end
    local b = batch
    if not (b and cfg().craftBar) then cbar:Hide() return end
    local now = GetTime()
    -- plus rien depuis longtemps (série coupée sans évènement d'interruption) : fin
    local left, per = remaining(b)
    if not b.casting and now - (b.last or b.t0) > per * 2 + 4 then UI:EndCraftBar(true) return end
    local elapsed = now - b.t0
    local frac = (elapsed + left) > 0 and elapsed / (elapsed + left) or 0
    if b.done >= b.n then frac = 1 end
    local parts = { string.format(T("%s par fabrication"), per >= 10 and mmss(per) or string.format(T("%.1f s"), per)) }
    if cfg().craftBarEnd then table.insert(parts, string.format(T("fin vers %s"), date("%H:%M", time() + left))) end
    -- la suite de la file de fabrication (autre recette) : « ensuite »
    -- (file relue toutes les 2 s seulement : Queue() parcourt les recettes de tout le compte, et la barre
    -- est rafraîchie 10 fois par seconde)
    if cfg().craftBarQueue then
        if not b.nextAt or now - b.nextAt > 2 then
            b.nextAt, b.nextText = now, nil
            for _, e in ipairs(PH():Queue()) do
                if e.mine and e.rec and e.rec.name ~= b.name and (e.qty or 0) > 0 then
                    b.nextText = string.format(T("ensuite : %s x%d"), e.rec.name, e.qty); break
                end
            end
        end
        if b.nextText then table.insert(parts, b.nextText) end
    end
    local skill
    if cfg().craftBarEnd and b.prof then
        local r = profRank(b.prof)
        if r then skill = T(b.prof) .. " " .. r .. ((b.rank0 and r > b.rank0) and (" " .. UI:Hex(C.positive) .. "(+" .. (r - b.rank0) .. ")|r") or "") end
    end
    cbar:Fill(b.name, b.icon, b.done, b.n, left, per, table.concat(parts, " · "), skill)
    cbar.bar:SetValue(frac)
    -- place : sous la fenêtre de métier (réglage), sinon celle du mode édition
    local tf = cfg().craftBarWhere == "trade" and tradeFrame()
    if tf then
        cbar:ClearAllPoints(); cbar:SetPoint("TOP", tf, "BOTTOM", 0, -6); cbar.docked = true
        UI:MatchHost(cbar, tf)
    elseif cbar.docked then
        cbar.docked = nil; cbar:SetFrameStrata("MEDIUM"); UI:HUDApply("craftBar")
    end
    cbar:Show()
end

function UI:EndCraftBar(stopped)
    local b = batch
    batch = nil
    if b and not stopped and cfg().craftBarSound and PlaySound then pcall(PlaySound, 8960) end -- prêt
    if cbar then
        if b and not stopped and cbar:IsShown() then
            cbar.bar:SetValue(1); cbar.left:SetText(T("terminé"))
            C_Timer.After(1.5, function() if not batch and cbar then cbar:Hide() end end)
        else cbar:Hide() end
    end
end

-- démo du mode édition (« Tester ») : une série de 10 fabrications de 1,5 s
function UI:TestCraftBar()
    batch = { name = T("Bandage en lin épais"), icon = "Interface\\Icons\\INV_Misc_Bandage_17", n = 10, done = 0, t0 = GetTime(),
              castDur = 1.5, per = 1.5, test = true, last = GetTime() }
    local function step()
        if not (batch and batch.test) then return end
        batch.done = batch.done + 1; batch.last = GetTime()
        if batch.done >= batch.n then UI:EndCraftBar(false) else C_Timer.After(1.5, step) end
    end
    C_Timer.After(1.5, step)
    UI:RefreshCraftBar()
end

-- créée dès la connexion : elle doit exister pour le mode édition (placer, Tester) avant toute série
WK:On("PLAYER_LOGIN", function() if not cbar then cbar = buildBar() end end)

local function startBatch(name, icon, n, spell)
    n = tonumber(n) or 1
    if not cfg().craftBar or n < (cfg().craftBarMin or 3) then return end
    local prof = PH():OpenProfession()
    batch = { name = name, icon = icon, n = n, done = 0, spell = spell, t0 = GetTime(), prof = prof, rank0 = profRank(prof) }
    batch.last = batch.t0
    UI:RefreshCraftBar()
end
if hooksecurefunc then
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID, num)
            local name, icon
            local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if ok and type(info) == "table" then name, icon = info.name, info.icon end
            if not name then name, icon = WK.SpellInfo(recipeID) end
            startBatch(name, icon, num, recipeID)
        end)
    end
    if DoTradeSkill then
        hooksecurefunc("DoTradeSkill", function(index, num)
            local name = GetTradeSkillInfo and GetTradeSkillInfo(index)
            local icon = GetTradeSkillIcon and GetTradeSkillIcon(index)
            startBatch(name, icon, num)
        end)
    end
end
-- la 1re incantation après le lancement fixe le sort de la série (le n° de recette peut différer du sort)
local function isMine(spellID)
    local b = batch
    if not b or b.test then return false end
    if not b.locked then return true end
    return spellID == b.spell
end
WK:OnUnit("UNIT_SPELLCAST_START", "player", function(_, _, spellID)
    if not isMine(spellID) then return end
    local b = batch
    if not b.locked then b.locked, b.spell = true, spellID end
    local _, _, _, s, e = UnitCastingInfo("player")
    if s and e then b.castDur = (e - s) / 1000; b.castEnd = e / 1000; b.casting = true end
end)
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, spellID)
    local b = batch
    if not (b and not b.test and b.locked and spellID == b.spell) then return end
    local now = GetTime()
    b.done = b.done + 1
    b.casting = false
    b.first = b.first or now
    if b.done >= 2 then b.per = (now - b.first) / (b.done - 1) end
    b.last = now
    if b.done >= b.n then UI:EndCraftBar(false) end
end)
WK:OnUnit("UNIT_SPELLCAST_STOP", "player", function(_, _, spellID)
    if batch and batch.locked and spellID == batch.spell then batch.casting = false; batch.last = GetTime() end
end)
WK:OnUnit("UNIT_SPELLCAST_INTERRUPTED", "player", function(_, _, spellID)
    if batch and batch.locked and spellID == batch.spell then UI:EndCraftBar(true) end
end)
