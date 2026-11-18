local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Kit de camp (Modules/Camp.lua) :
--   colonne de boutons protégés (HUD « campKit ») : feu, objets de camp de tes métiers (meilleur palier en sac),
--   sac de couchage, nourriture « Bien nourri » et boisson ; clic = utiliser l'objet (hors combat), voile de recharge ;
--   montrée près d'un feu (ou toujours) ; seulement ce qui est dans les sacs. Rien ne change en combat.
--   pastilles sous l'icône de flamme : avantages restants, recharge des objets, « Bien nourri » ;
--   infobulle des objets de camp : effet à ton niveau, paliers, buff qui l'annule, recharge.
local M = WK.modules.Camp
local MAXB, BS, GAP = 14, 36, 5
local kit, chips
local pending = false

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return (f and f(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function short(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec >= 3600 then return string.format("%dh", math.floor(sec / 3600)) end
    if sec >= 60 then return string.format("%dm", math.floor(sec / 60)) end
    return tostring(sec)
end

---------------------------------------------------------------------------
-- Colonne de boutons
---------------------------------------------------------------------------
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperCampKit", UIParent)
    f:SetSize(BS + 12, BS + 12)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.9 }, C.border)
    f.buttons = {}
    for i = 1, MAXB do
        local b = CreateFrame("Button", "WarbandKeeperCampKit" .. i, f, "SecureActionButtonTemplate")
        b:SetSize(BS, BS)
        b:SetPoint("TOP", f, "TOP", 0, -6 - (i - 1) * (BS + GAP))
        if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
        b:SetAttribute("type", "item")
        b.edge = b:CreateTexture(nil, "BACKGROUND")
        b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        b.cd:SetAllPoints(b.icon)
        if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
        -- textes au-dessus du voile de recharge (sinon il les assombrit), gros et cernés de noir
        b.over = CreateFrame("Frame", nil, b)
        b.over:SetAllPoints(b)
        b.over:SetFrameLevel(b.cd:GetFrameLevel() + 2)
        b.cdText = UI:Text(b.over, 13, C.text, "OVERLAY")
        b.cdText:SetFont(UI.FONT, 13, "OUTLINE")
        b.cdText:SetPoint("CENTER", 0, 1)
        b.cdText:SetShadowOffset(1, -1)
        b.cdText:SetShadowColor(0, 0, 0, 1)
        b.n = UI:Text(b.over, 10, C.text, "OVERLAY")
        b.n:SetFont(UI.FONT, 10, "OUTLINE")
        b.n:SetPoint("BOTTOMRIGHT", -1, 2)
        b.n:SetShadowOffset(1, -1)
        b:SetScript("OnEnter", function(s)
            if not s.id then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText((WK.GetItemInfo(s.id)) or "") end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(inCombat() and T("En combat : utilisable après le combat") or T("Clic : utiliser"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        f.buttons[i] = b
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 0.5 then return end
        s.acc = 0
        -- timers sur les icônes (voile qui tourne + temps au centre) : jaune = recharge, vert = « Bien nourri » actif
        local rem, start, dur = M:Cooldown()
        local fed = M.auras and M.auras.fed
        local fedLeft = fed and M.Remaining(fed)
        for _, b in ipairs(s.buttons) do
            if b:IsShown() then
                local left, st, du, col
                if b.kind == "object" then
                    if rem and rem > 0 and start then left, st, du = rem, start, dur end
                elseif b.kind == "fire" or b.kind == "bag" then
                    left, st, du = M:ItemCooldown(b.id)
                elseif b.kind == "fed" and fedLeft and fedLeft > 0 then
                    local total = (type(fed.duration) == "number" and fed.duration > 0) and fed.duration or fedLeft
                    left, st, du, col = fedLeft, GetTime() + fedLeft - total, total, C.positive
                end
                if left and st and du then
                    b.cd:SetCooldown(st, du)
                    if b.cd.SetReverse then b.cd:SetReverse(col ~= nil) end
                    b.cdText:SetText(short(left))
                    local tc = col or C.gold
                    b.cdText:SetTextColor(tc[1], tc[2], tc[3])
                else
                    b.cd:Clear(); b.cdText:SetText("")
                end
            end
        end
    end)
    f:Hide()
    UI:RegisterHUD("campKit", f, {
        label = T("Kit de camp"), protected = true, default = { -170, -120 },
        enabled = function() return M:Config().kit end,
        sample = function(on)
            f.sample = on or nil
            if inCombat() then return end
            if on then
                local demo = { { id = M.FIRES[1][1], kind = "fire", count = 2 }, { id = 279944, kind = "object", count = 1 },
                    { id = 279967, kind = "object", count = 1 }, { id = M.SLEEPING_BAG, kind = "bag", count = 1 } }
                f:Fill(demo); f:Show()
            else
                UI:RefreshCampKit()
            end
        end,
    })

    -- Remplit la colonne (hors combat : attributs protégés)
    function f:Fill(list)
        local r1, g1, b1 = UI:Accent()
        local fedMissing = not (M.auras and M.auras.fed)
        local n = math.min(#list, MAXB)
        for i, b in ipairs(self.buttons) do
            local e = list[i]
            if e and i <= n then
                b.id, b.kind = e.id, e.kind
                b:SetAttribute("item", "item:" .. e.id)
                b.icon:SetTexture(itemIcon(e.id))
                b.n:SetText((e.count or 0) > 1 and e.count or "")
                local glow = e.kind == "fed" and fedMissing
                local col = glow and C.gold or { r1, g1, b1 }
                b.edge:SetVertexColor(col[1], col[2], col[3], glow and 1 or 0.8)
                b.cd:Clear(); b.cdText:SetText("")
                b:Show()
            else
                b.id = nil
                b:Hide()
            end
        end
        self:SetHeight(12 + n * BS + math.max(0, n - 1) * GAP)
    end
    return f
end

function UI:RefreshCampKit()
    if not kit then kit = build() end
    if kit.sample then return end
    if inCombat() then pending = true return end
    pending = false
    local cfg = M:Config()
    local list = (cfg.kit and WK:FeatureOn("campfire")) and M:Kit() or {}
    -- près d'un feu : l'état de Camp:Update n'est calculé que si l'encart ou l'icône est actif ;
    -- les auras, elles, sont toujours relevées (flamme du camp ou assis près du feu)
    local a = M.auras
    local near = (M.state and M.state ~= "none") or (a and (a.flame or a.sit)) and true or false
    if #list == 0 or not (cfg.kitAlways or near) then kit:Hide() return end
    kit:Fill(list)
    kit:Show()
end

WK:On("PLAYER_REGEN_ENABLED", function() if pending then UI:RefreshCampKit() end end)
WK:On("BAG_UPDATE_DELAYED", function() C_Timer.After(0.3, function() UI:RefreshCampKit(); if UI.RefreshCampChips then UI:RefreshCampChips() end end) end)

---------------------------------------------------------------------------
-- Pastilles sous l'icône de flamme
---------------------------------------------------------------------------
local function chip(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(18)
    UI:Panel(c, 9, { C.bg[1], C.bg[2], C.bg[3], 0.9 }, C.border)
    c.dot = c:CreateTexture(nil, "ARTWORK")
    c.dot:SetTexture(UI.MEDIA .. "circle")
    c.dot:SetSize(7, 7)
    c.dot:SetPoint("LEFT", 7, 0)
    c.t = UI:Text(c, 10, C.text)
    c.t:SetPoint("LEFT", 18, 0)
    function c:Set(text, col)
        self.t:SetText(text)
        self.dot:SetVertexColor(col[1], col[2], col[3], 1)
        self:SetWidth(self.t:GetStringWidth() + 26)
    end
    return c
end
local function buildChips()
    local icon = _G.WarbandKeeperCampIcon
    if not icon then return nil end
    local f = CreateFrame("Frame", nil, icon)
    f:SetSize(10, 10)
    f:SetPoint("TOP", icon, "BOTTOM", 0, -20)
    f.items = {}
    for i = 1, 3 do
        f.items[i] = chip(f)
        f.items[i]:SetPoint("TOP", f, "TOP", 0, -(i - 1) * 21)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        UI:RefreshCampChips()
    end)
    return f
end
function UI:RefreshCampChips()
    if not chips then chips = buildChips() end
    if not chips then return end
    local cfg = M:Config()
    if not cfg.chips then chips:Hide() return end
    chips:Show()
    local a = M.auras or {}
    local rows = {}
    local left = M.Remaining(a.perk)
    if left and left > 0 then table.insert(rows, { string.format(T("Avantages du camp · %s"), UI:AgoShort(left, true)), C.positive }) end
    local rem = M:Cooldown()
    if rem and rem > 0 then table.insert(rows, { string.format(T("Objet de camp · prêt dans %s"), UI:AgoShort(rem, true)), C.warning }) end
    local fed = M.Remaining(a.fed)
    if a.fed then
        table.insert(rows, { fed and fed > 0 and string.format(T("Bien nourri · %s"), UI:AgoShort(fed, true)) or T("Bien nourri"), C.positive })
    elseif a.flame then
        table.insert(rows, { T("Bien nourri absent"), C.negative })
    end
    for i, c in ipairs(chips.items) do
        local r = rows[i]
        if r then c:Set(r[1], r[2]); c:Show() else c:Hide() end
    end
end

---------------------------------------------------------------------------
-- Infobulle des objets de camp
---------------------------------------------------------------------------
local function onTooltip(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    if not WK:FeatureOn("campfire") then return end
    local id = data and data.id
    if not id and tt.GetItem then local _, link = tt:GetItem(); id = link and WK:ParseItemID(link) end
    if not id then return end
    local r1, g1, b1 = UI:Accent()
    local level = (UnitLevel and UnitLevel("player")) or 1
    local hit = M.byItem[id]
    if hit then
        local o, tier = hit.o, hit.tier
        local eff = M:Effect(o, tier, level)
        if o.steps or o.enchant then
            tt:AddLine(string.format(T("Camp : %s pour toi (niveau %d)"), eff, level), r1, g1, b1, true)
            local nxt = M:NextSteps(o, level)
            if nxt then tt:AddLine(nxt, 0.62, 0.64, 0.67, true) end
        elseif eff then
            tt:AddLine(string.format(T("Camp : %s"), eff), r1, g1, b1, true)
        end
        if o.exclLabel then
            local has = M:Cancelled(o)
            if has then tt:AddLine(string.format(T("Tu as %s : sans effet pour toi (les autres en profitent)"), has), C.negative[1], C.negative[2], C.negative[3], true)
            else tt:AddLine(string.format(T("Ne se cumule pas avec %s"), T(o.exclLabel)), C.negative[1], C.negative[2], C.negative[3], true) end
        end
        if tier == 1 and o.ids[2] then
            tt:AddLine(string.format(T("Remplacé par %s (140) et %s (300), avec le même effet"), M:Name(o, 2), M:Name(o, 3)), 0.62, 0.64, 0.67, true)
        elseif tier > 1 and o.ids[1] then
            tt:AddLine(string.format(T("Remplace %s et garde son effet"), M:Name(o, 1)), 0.62, 0.64, 0.67, true)
        end
    elseif M.fireByItem[id] then
        local fr = M.FIRES[M.fireByItem[id]]
        tt:AddLine(string.format(T("Camp : feu qui accepte %d objets de camp · Cuisine %d"), fr[4], fr[3]), r1, g1, b1, true)
        return tt:Show()
    else
        return
    end
    local rem = M:Cooldown()
    if rem and rem > 0 then tt:AddLine(string.format(T("Prêt dans %s (recharge commune des objets de camp)"), UI:AgoShort(rem, true)), C.gold[1], C.gold[2], C.gold[3])
    else tt:AddLine(T("Recharge commune des objets de camp : 1 h"), 0.62, 0.64, 0.67) end
    tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) pcall(onTooltip, tt, data) end)
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(1, function() UI:RefreshCampKit(); UI:RefreshCampChips() end)
end)
