local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Affichage des aides des sacs (Modules/BagHelp.lua) :
--   * HUD « bagSpace » : sous le seuil de cases libres, le nombre de cases et, au clic, l'objet gris le moins
--     cher jeté (jamais en combat, jamais un objet verrouillé) ;
--   * bouton « Réassort » sous la fenêtre du marchand : ce qui manque et le prix, acheté sur un clic ;
--   * HUD « wearOffer » : objet arrivé dans les sacs meilleur que celui porté, « L'équiper » / « Pas celui-là » ;
--   * fenêtre de destruction du jeu : « Encore demandé par : quête » pour un objet d'une quête du journal ;
--   * carte de réglages « Sacs, marchand et équipement » (roue de la page Inventaire).
local function BH() return WK.modules.BagHelp end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end

---------------------------------------------------------------------------
-- Barre « sacs, marchand, maître » (HUD bagSpace) : trois cases dans un seul cadre, séparées d'un trait fin.
--   sac : cases libres (clic = jeter le gris le moins cher) ;
--   marchand : distance du plus proche (clic = guidage, clic droit = forgeron pour réparer) ;
--   maître de classe : sorts à apprendre, sinon la distance (clic = guidage).
-- Couleur selon l'urgence : rouge quand c'est pressé (sacs pleins, équipement abîmé), orange bientôt,
-- bleu quand des sorts attendent, sinon discret. Réglages bagHelp : space (barre), low (seuil),
-- vendorTile, trainerTile.
---------------------------------------------------------------------------
local space
local TILE = 46
-- usure la plus basse de l'équipement porté (en %), ou nil
local function minDurability()
    if not GetInventoryItemDurability then return nil end
    local low
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local p = cur / max * 100
            if not low or p < low then low = p end
        end
    end
    return low
end
-- lieux les plus proches, gardés 10 s (la recherche parcourt tous les lieux)
local near = {}
local function nearest(what)
    local G = WK.modules.Guide
    local now = GetTime()
    local n = near[what]
    if not n or now - n.at > 10 then
        local class = what == "trainer" and select(2, UnitClass("player")) or nil
        local ok, t = pcall(G.Nearest, G, G:KindsFor(what), class)
        n = { at = now, t = ok and t or nil }
        near[what] = n
    end
    local t = n.t
    if not t then return nil end
    local p = G:PlayerPos()
    local d = p and t.cont and G:Vector(p, t) or t.distance
    return t, d
end
-- sorts à apprendre maintenant, gardé 10 s (le catalogue des sorts est lourd à relire toutes les 2 s)
local spellsAt, spellsN = 0, 0
local function spellsToLearn()
    if GetTime() - spellsAt > 10 then
        spellsAt = GetTime()
        local CS = WK.modules.ClassSpells
        local ok, cr = pcall(function() return CS and CS:ForChar() end)
        spellsN = ok and cr and #cr.now or 0
    end
    return spellsN
end
local function distText(d)
    if not d then return "" end
    if d >= 1000 then return string.format("%.1f km", d / 1000):gsub("%.", ",") end
    return string.format(T("%d m"), math.floor(d + 0.5))
end

local function newTile(parent, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(TILE, TILE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = UI:Icon(b, glyph, 22, nil, "ARTWORK"); b.icon:SetPoint("CENTER", 0, 4)
    b.n = UI:Text(b, 11); b.n:SetPoint("BOTTOM", 0, 4)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetPoint("TOPLEFT", 3, -3); b.hl:SetPoint("BOTTOMRIGHT", -3, 3)
    b.hl:SetColorTexture(1, 1, 1, 0.06)
    function b:Paint(col, txt)
        self.icon:SetVertexColor(col[1], col[2], col[3], 1)
        self.n:SetText(txt or ""); self.n:SetTextColor(col[1], col[2], col[3])
    end
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function buildSpace()
    local f = CreateFrame("Frame", "WarbandKeeperBagSpace", UIParent)
    f:SetSize(TILE, TILE)
    f:SetFrameStrata("MEDIUM")
    f.bg = UI:Rounded(f, 11, 0, "BACKGROUND", 1)
    f.seps = {}
    for i = 1, 4 do
        local s = f:CreateTexture(nil, "ARTWORK"); s:SetWidth(1)
        s:SetColorTexture(1, 1, 1, 0.08)
        f.seps[i] = s
    end
    -- sac
    f.bag = newTile(f, "bag")
    f.bag:SetScript("OnEnter", function(s)
        local free, total = BH():FreeSlots()
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(string.format(T("%d case(s) libre(s) sur %d"), free, total), 1, 1, 1)
        local g = BH():CheapestGrey()
        if g then
            local _, link = WK.GetItemInfo(g.id)
            GameTooltip:AddLine(string.format(T("Clic : jeter %s (%s)"), link or "?", WK:FormatMoney(g.price)), 0.85, 0.85, 0.85, true)
        else
            GameTooltip:AddLine(T("Aucun objet gris à jeter."), 0.6, 0.6, 0.6)
        end
        _G.GameTooltip:Show()
    end)
    f.bag:SetScript("OnClick", function(s, btn)
        if btn ~= "LeftButton" then return end
        if BH():DeleteCheapest() then C_Timer.After(0.3, function() UI:RefreshBagSpace(); if s:IsMouseOver() then s:GetScript("OnEnter")(s) end end) end
    end)
    -- marchand
    f.vendor = newTile(f, "shop")
    f.vendor:SetScript("OnEnter", function(s)
        local t, d = nearest("vendor")
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Marchand le plus proche"), 1, 1, 1)
        if t then GameTooltip:AddLine(WK.modules.Guide:PlaceName(t) .. " · " .. distText(d), 0.85, 0.85, 0.85, true) end
        local dur = minDurability()
        if dur and dur < 100 then GameTooltip:AddLine(string.format(T("Équipement à %d %%"), math.floor(dur + 0.5)), 0.85, 0.85, 0.85) end
        GameTooltip:AddLine(T("Clic : guider · clic droit : forgeron (réparer)"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f.vendor:SetScript("OnClick", function(_, btn)
        WK.modules.Guide:GoTo(btn == "RightButton" and "repair" or "vendor")
    end)
    -- maître de classe
    f.trainer = newTile(f, "book")
    f.trainer:SetScript("OnEnter", function(s)
        local t, d = nearest("trainer")
        local CS = WK.modules.ClassSpells
        local cr = CS and CS:ForChar()
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Maître de classe le plus proche"), 1, 1, 1)
        if t then GameTooltip:AddLine(WK.modules.Guide:PlaceName(t) .. " · " .. distText(d), 0.85, 0.85, 0.85, true) end
        local n = cr and #cr.now or 0
        GameTooltip:AddLine(n > 0 and string.format(T("%d sort(s) à apprendre"), n) or T("Rien à apprendre pour l'instant"), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(T("Clic : guider"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f.trainer:SetScript("OnClick", function() WK.modules.Guide:GoTo("trainer") end)
    -- kit de camp (réglage kitInBar du feu de camp) : clic = dérouler la liste du kit sous ou au-dessus (kitDir)
    f.kit = newTile(f, "fire")
    f.kit:SetScript("OnEnter", function(s)
        local Cp = WK.modules.Camp
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Kit de camp"), 1, 1, 1)
        local perk = Cp.auras and Cp.Remaining(Cp.auras.perk)
        if perk and perk > 0 then
            _G.GameTooltip:AddLine(string.format(T("Avantages du camp · %s"), UI:AgoShort(perk, true)),
                UI.RGB(C.positive))
        end
        local open = UI.CampKitOpen and UI:CampKitOpen()
        _G.GameTooltip:AddLine(open and T("Clic : replier le kit") or T("Clic : dérouler le kit"), 0.6, 0.6, 0.6)
        _G.GameTooltip:Show()
    end)
    f.kit:SetScript("OnClick", function(s)
        if UI.ToggleCampKit then UI:ToggleCampKit() end
        if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
    end)
    -- buffs à ne pas oublier (Modules/SelfBuffs.lua) : nombre de buffs absents ; clic = dérouler la liste (dir)
    f.buffs = newTile(f, "spark")
    -- alerte A (réglage buffAlert) : fond rouge léger + liseré qui respire tant qu'un buff manque (hors combat,
    -- hors ville) ; rien ne bouge quand tout est en place
    do
        local t = f.buffs
        t.glow = UI:Rounded(t, 10, 0, "BACKGROUND", 2)
        t.fill = UI:Rounded(t, 8, 2, "BACKGROUND", 3)
        t.glow:Hide(); t.fill:Hide()
        t.pulse = _G.CreateFrame("Frame", nil, t)
        t.pulse:Hide()
        t.pulse:SetScript("OnUpdate", function(_, el)
            t.ph = ((t.ph or 0) + el) % 1.6
            local a = 0.15 + 0.4 * (0.5 - 0.5 * math.cos(t.ph / 1.6 * 2 * math.pi))
            local c = C.negative
            t.glow:SetColor(c[1], c[2], c[3], a)
        end)
        function t:Alert(on)
            if (self.alertOn or false) == on then return end
            self.alertOn = on
            local c = C.negative
            self.fill:SetColor(c[1], c[2], c[3], 0.16)
            self.glow:SetShown(on); self.fill:SetShown(on); self.pulse:SetShown(on)
        end
    end
    f.buffs:SetScript("OnEnter", function(s)
        local SB = WK.modules.SelfBuffs
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Buffs à ne pas oublier"), 1, 1, 1)
        for _, r in ipairs((SB:Status())) do
            if r.state ~= "ok" then
                local col = r.state == "missing" and C.negative or C.gold
                _G.GameTooltip:AddLine(r.name or "?", UI.RGB(col))
            end
        end
        local miss, soon = SB:Counts()
        if miss + soon == 0 then _G.GameTooltip:AddLine(T("Tout est en place."), UI.RGB(C.positive)) end
        local open = UI.SelfBuffsOpen and UI.SelfBuffsOpen()
        _G.GameTooltip:AddLine(open and T("Clic : replier la liste") or T("Clic : dérouler la liste"), 0.6, 0.6, 0.6)
        _G.GameTooltip:Show()
    end)
    f.buffs:SetScript("OnClick", function(s)
        if UI.ToggleSelfBuffs then UI.ToggleSelfBuffs() end
        if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
    end)
    -- mise en page : cases visibles côte à côte, trait entre deux cases
    function f:Arrange(showV, showT, showK, showB)
        local tiles = { self.bag }
        if showV then tiles[#tiles + 1] = self.vendor end
        if showT then tiles[#tiles + 1] = self.trainer end
        if showK then tiles[#tiles + 1] = self.kit end
        if showB then tiles[#tiles + 1] = self.buffs end
        self.buffs:SetShown(showB and true or false)
        self.vendor:SetShown(showV and true or false)
        self.trainer:SetShown(showT and true or false)
        self.kit:SetShown(showK and true or false)
        for i, t in ipairs(tiles) do
            t:ClearAllPoints(); t:SetPoint("LEFT", (i - 1) * (TILE + 1), 0)
        end
        local cfg = BH():Config()
        local bg, seps = cfg.barBg ~= false, cfg.barSeps ~= false
        for i, s in ipairs(self.seps) do
            s:ClearAllPoints()
            if tiles[i + 1] and seps then
                s:SetPoint("TOPLEFT", tiles[i], "TOPRIGHT", 0, -9); s:SetPoint("BOTTOMLEFT", tiles[i], "BOTTOMRIGHT", 0, 9)
                s:Show()
            else s:Hide() end
        end
        self:SetWidth(#tiles * TILE + (#tiles - 1))
        -- sans fond (réglage barBg) : chiffres cernés de noir pour rester lisibles sur le jeu
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], bg and 0.92 or 0)
        if self.outlined ~= nil and self.outlined ~= not bg or (self.outlined == nil and not bg) then
            self.outlined = not bg
            for _, t in ipairs({ self.bag, self.vendor, self.trainer, self.kit, self.buffs }) do
                t.n:SetFont(UI.FONT, math.floor(11 * (UI.textScale or 1) + 0.5), bg and "" or "OUTLINE")
                t.n:SetShadowOffset(bg and 0 or 1, bg and 0 or -1)
                t.n:SetShadowColor(0, 0, 0, bg and 0 or 1)
            end
        end
    end
    -- exemple du mode édition
    function f:Paint(free)
        self:Arrange(true, true, true, true)
        self.bag:Paint(free <= 0 and C.negative or C.warning, tostring(free))
        self.vendor:Paint(C.negative, "85 m")
        self.trainer:Paint(C.info, "3")
        self.kit:Paint(C.positive, "1h 52")
        self.buffs:Paint(C.negative, "2")
        self.buffs:Alert(true)
    end
    f:Hide()
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 2 then return end
        s.acc = 0
        if not s.sample then UI:RefreshBagSpace() end
    end)
    UI:RegisterHUD("bagSpace", f, {
        label = T("Sacs, marchand et maître"), default = { 300, -200 },
        enabled = function() return BH():Config().space end,
        sample = function(on) f.sample = on or nil; if on then f:Paint(2); f:Show() else UI:RefreshBagSpace() end end,
    })
    return f
end
UI.CampKitTile = function() return space and space.kit end
UI.SelfBuffTile = function() return space and space.buffs end
function UI:RefreshBagSpace()
    space = space or buildSpace()
    if space.sample then return end
    local cfg = BH():Config()
    if not cfg.space or not WK:FeatureOn("inventory") then space:Hide() return end
    local free = BH():FreeSlots()
    local low = cfg.low or 3
    local showV, showT = cfg.vendorTile ~= false, cfg.trainerTile ~= false
    local showK = UI.CampKitInBar and UI.CampKitInBar() and UI.campKitAvail and WK:FeatureOn("campfire") or false
    local SB = WK.modules.SelfBuffs
    local miss, soon, total = 0, 0, 0
    if SB and SB:Config().bar and WK:FeatureOn("classes") then miss, soon, total = SB:Counts() end
    local showB = total > 0
    local w0 = space:GetWidth()
    space:Arrange(showV, showT, showK, showB)
    if showB then
        local fight0 = _G.InCombatLockdown and _G.InCombatLockdown()
        local resting = _G.IsResting and _G.IsResting()
        space.buffs:Alert(miss > 0 and cfg.buffAlert ~= false and not fight0 and not resting or false)
        if miss > 0 then space.buffs:Paint(C.negative, tostring(miss))
        elseif soon > 0 then space.buffs:Paint(C.gold, tostring(soon))
        else space.buffs:Paint(C.positive, T("ok")) end
    end
    if showK then
        -- temps restant des avantages du camp (vert), sinon « kit » ; rouge si « Bien nourri » manque
        local Cp = WK.modules.Camp
        local perk = Cp.auras and Cp.Remaining(Cp.auras.perk)
        local txt = (perk and perk > 0) and UI:AgoShort(perk, true) or T("kit")
        local col = (perk and perk > 0) and C.positive or { UI:Accent() }
        space.kit:Paint(col, txt)
    end
    -- liste du kit ouverte : replacée si la barre a changé de largeur (hors combat)
    local fight = _G.InCombatLockdown and _G.InCombatLockdown()
    if UI.CampKitOpen and UI:CampKitOpen() and space:GetWidth() ~= w0 and not fight then
        UI:RefreshCampKit()
    end
    -- liste des buffs ouverte : remplie de nouveau (un lieu ou un sort a pu changer) ou repliée sans case
    if UI.SelfBuffsOpen and UI.SelfBuffsOpen() and not fight then UI:RefreshSelfBuffs() end
    -- sac : rouge plein, orange sous le seuil, sinon discret
    space.bag:Paint(free <= 0 and C.negative or (free <= low and C.warning) or C.muted, tostring(free))
    if showV then
        local _, d = nearest("vendor")
        local dur = minDurability()
        -- pressé : sacs sous le seuil ou équipement sous 25 % ; bientôt : sous 50 %
        local col = ((free <= low) or (dur and dur < 25)) and C.negative or ((dur and dur < 50) and C.warning) or { UI:Accent() }
        space.vendor:Paint(col, distText(d))
    end
    if showT then
        local n = spellsToLearn()
        if n > 0 then space.trainer:Paint(C.info, tostring(n))
        else
            local _, d = nearest("trainer")
            space.trainer:Paint(C.muted, distText(d))
        end
    end
    space:Show()
end

---------------------------------------------------------------------------
-- Réassort chez le marchand
---------------------------------------------------------------------------
local rsBtn
local qbBtn -- bouton des objets de quête (plus bas)
local function plan()
    local stock = UI.MerchantStock and UI.MerchantStock() or {}
    return BH():RestockPlan(stock)
end
local function buildRestock()
    local b = UI:Button(UIParent, T("Réassort"), nil, 26, "primary")
    b:SetFrameStrata("DIALOG")
    b:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Réassort"), 1, 1, 1)
        for _, p in ipairs(s.plan or {}) do
            local _, link = WK.GetItemInfo(p.id)
            GameTooltip:AddDoubleLine((link or ("#" .. p.id)) .. " x" .. p.need,
                WK:FormatMoney(math.ceil(p.stock.price / math.max(1, p.stock.batch) * p.need)), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine(T("Quantités : roue de la page Inventaire."), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        local n = 0
        for _, p in ipairs(s.plan or {}) do n = n + (UI.MerchantBuy(p.stock, p.need) or 0) end
        if n > 0 then WK:Print(string.format(T("Réassort : %d objet(s) acheté(s)."), n)) end
        C_Timer.After(1, function() UI:RefreshRestock() end)
    end)
    b:Hide()
    return b
end
-- quelque chose à acheter chez ce marchand (réassort, objets de quête, panneau des métiers) : la fenêtre ne se
-- ferme pas toute seule après une réparation (Modules/QoL.lua)
function UI.MerchantHasOffers()
    return (rsBtn and rsBtn:IsShown()) or (qbBtn and qbBtn:IsShown())
        or (UI.MerchantPanelShown and UI.MerchantPanelShown()) or false
end
function UI:RefreshRestock()
    rsBtn = rsBtn or buildRestock()
    local cfg = BH():Config()
    if not (cfg.restock and MerchantFrame and MerchantFrame:IsShown() and WK:FeatureOn("inventory")) then rsBtn:Hide() return end
    local p = plan()
    rsBtn.plan = p
    if #p == 0 then rsBtn:Hide() return end
    rsBtn:SetLabel(string.format(T("Réassort : %d objet(s), %s"), #p, UI:PlainMoney(BH():PlanCost(p))))
    rsBtn:SetWidth(rsBtn.label:GetStringWidth() + 32)
    rsBtn:ClearAllPoints()
    rsBtn:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 4, -4)
    UI:MatchHost(rsBtn, MerchantFrame)
    rsBtn:Show()
end

---------------------------------------------------------------------------
-- Objets de quête vendus ici (Modules/QuestTrack.lua : BuyMissing) : bouton sous la fenêtre du marchand ;
-- jamais plus que ce qui manque
---------------------------------------------------------------------------
local function questPlan()
    local QT = WK.modules.QuestTrack
    local stock = UI.MerchantStock and UI.MerchantStock() or {}
    local out, byId = {}, {}
    if not (QT and QT.BuyMissing) then return out end
    for _, l in ipairs(QT:LogQuests()) do
        for _, it in ipairs(QT:BuyMissing(l.id)) do
            local st = stock[it.id]
            if st then
                local e = byId[it.id]
                if e then e.need = math.max(e.need, it.n); e.quests[#e.quests + 1] = l.title
                else
                    e = { id = it.id, need = it.n, stock = st, quests = { l.title } }
                    byId[it.id] = e
                    table.insert(out, e)
                end
            end
        end
    end
    return out
end
UI.QuestBuyPlan = questPlan
local function buyAll(p)
    local n = 0
    for _, e in ipairs(p or {}) do n = n + (UI.MerchantBuy(e.stock, e.need) or 0) end
    if n > 0 then
        local names = {}
        for _, e in ipairs(p) do names[#names + 1] = (select(2, WK.GetItemInfo(e.id)) or ("#" .. e.id)) .. " x" .. e.need end
        WK:Print(string.format(T("Objets de quête achetés : %s"), table.concat(names, ", ")))
    end
    return n
end
local function buildQuestBuy()
    local b = UI:Button(UIParent, T("Pour tes quêtes"), nil, 26, "primary")
    b:SetFrameStrata("DIALOG")
    b:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Objets demandés par tes quêtes"), 1, 1, 1)
        for _, e in ipairs(s.plan or {}) do
            local _, link = WK.GetItemInfo(e.id)
            GameTooltip:AddDoubleLine((link or ("#" .. e.id)) .. " x" .. e.need,
                WK:FormatMoney(math.ceil(e.stock.price / math.max(1, e.stock.batch) * e.need)), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddLine("   " .. table.concat(e.quests, ", "), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        buyAll(s.plan)
        C_Timer.After(1, function() UI:RefreshQuestBuy() end)
    end)
    b:Hide()
    return b
end
local function planCost(p)
    local total = 0
    for _, e in ipairs(p) do total = total + math.ceil(e.stock.price / math.max(1, e.stock.batch) * e.need) end
    return total
end
function UI:RefreshQuestBuy()
    qbBtn = qbBtn or buildQuestBuy()
    if not (MerchantFrame and MerchantFrame:IsShown() and WK:FeatureOn("quests")) then qbBtn:Hide() return end
    local p = questPlan()
    qbBtn.plan = p
    if #p == 0 then qbBtn:Hide() return end
    local cost = planCost(p)
    qbBtn:SetLabel(string.format(T("Pour tes quêtes : %d objet(s), %s"), #p, UI:PlainMoney(cost)))
    qbBtn:SetWidth(qbBtn.label:GetStringWidth() + 32)
    qbBtn:ClearAllPoints()
    -- sous la fenêtre du marchand, à côté du bouton « Réassort » s'il est là
    if rsBtn and rsBtn:IsShown() then qbBtn:SetPoint("LEFT", rsBtn, "RIGHT", 6, 0)
    else qbBtn:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 4, -4) end
    UI:MatchHost(qbBtn, MerchantFrame)
    qbBtn:Show()
end
WK:On("MERCHANT_SHOW", function()
    C_Timer.After(0.3, function()
        UI:RefreshRestock()
        UI:RefreshQuestBuy()
    end)
end)
WK:On("MERCHANT_CLOSED", function() if qbBtn then qbBtn:Hide() end end)

WK:On("MERCHANT_CLOSED", function() if rsBtn then rsBtn:Hide() end end)
WK:On("MERCHANT_UPDATE", function() if rsBtn and rsBtn:IsShown() then C_Timer.After(0.3, function() UI:RefreshRestock() end) end end)

---------------------------------------------------------------------------
-- Amélioration à porter
---------------------------------------------------------------------------
local wear
local function buildWear()
    local f = CreateFrame("Frame", "WarbandKeeperWearOffer", UIParent)
    f:SetSize(320, 78)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(34, 34); f.icon:SetPoint("TOPLEFT", 12, -12)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = UI:Text(f, 10, C.muted); f.title:SetPoint("TOPLEFT", 56, -12); f.title:SetText(UI:Upper(T("Mieux que ce que tu portes")))
    f.name = UI:Text(f, 12); f.name:SetPoint("TOPLEFT", 56, -26); f.name:SetPoint("RIGHT", -12, 0)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 56, -42); f.sub:SetPoint("RIGHT", -12, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.yes = UI:Button(f, T("L'équiper"), nil, 22, "primary")
    f.yes:SetPoint("BOTTOMRIGHT", -12, 10)
    f.no = UI:Button(f, T("Pas celui-là"), nil, 22, "ghost")
    f.no:SetPoint("RIGHT", f.yes, "LEFT", -6, 0)
    f.yes:SetScript("OnClick", function() BH():Wear(f.q); C_Timer.After(0.5, function() UI:RefreshWearOffer() end) end)
    f.no:SetScript("OnClick", function() BH():Skip(f.q); UI:RefreshWearOffer() end)
    local hover = CreateFrame("Frame", nil, f)
    hover:SetPoint("TOPLEFT", f.icon); hover:SetPoint("BOTTOMRIGHT", f.sub, "BOTTOMRIGHT")
    hover:SetScript("OnEnter", function(s)
        if not (f.q and f.q.link) then return end
        UI:TooltipOwner(s, "ANCHOR_TOP"); GameTooltip:SetHyperlink(f.q.link); GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Paint(q)
        self.q = q
        local _, _, _, _, _, _, _, _, _, icon = WK.GetItemInfo(q.link)
        self.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(q.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.name:SetText(q.link or "?")
        local oldName = q.old and q.old:match("%[(.-)%]")
        self.sub:SetText(string.format(T("+%d points (caractéristiques de ta classe)"), math.floor((q.gain or 0) + 0.5))
            .. "  ·  " .. (oldName and string.format(T("à la place de %s"), oldName) or T("emplacement vide")))
    end
    f:Hide()
    UI:RegisterHUD("wearOffer", f, {
        label = T("Amélioration à porter"), default = { 0, -180 },
        enabled = function() return BH():Config().wear end,
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Paint({ id = 2575, link = "|cff1eff00|Hitem:2575::::::::|h[Exemple d'objet]|h|r", gain = 6, old = "[Ancien objet]" })
                f:Show()
            else UI:RefreshWearOffer() end
        end,
    })
    return f
end
function UI:RefreshWearOffer()
    wear = wear or buildWear()
    if wear.sample then return end
    local q = BH():Config().wear and WK:FeatureOn("inventory") and not inCombat() and BH():Offer()
    if not q then wear:Hide() return end
    wear:Paint(q)
    wear:Show()
end
WK:On("PLAYER_REGEN_DISABLED", function() if wear and not wear.sample then wear:Hide() end end)

---------------------------------------------------------------------------
-- Fenêtre de destruction : objet demandé par une quête du journal
---------------------------------------------------------------------------
local DELETE = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local function onPopup(which)
    if not DELETE[which] or not GetCursorInfo then return end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    local q = WK.modules.ItemLock and WK.modules.ItemLock:QuestFor(id)
    if not q then return end
    local frame = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    local text = frame and (frame.text or frame.Text)
    if not (text and text.GetText) then return end
    local cur = text:GetText() or ""
    if cur:find(q, 1, true) then return end
    text:SetText(cur .. "\n\n" .. UI:Hex(C.warning) .. string.format(T("Encore demandé par : %s"), q) .. "|r")
    if StaticPopup_Resize then pcall(StaticPopup_Resize, frame, which) end
end
UI.QuestDeleteLine = onPopup
if hooksecurefunc and StaticPopup_Show then hooksecurefunc("StaticPopup_Show", onPopup) end

---------------------------------------------------------------------------
-- Réglages : carte de la roue de la page Inventaire
---------------------------------------------------------------------------
function UI:BuildBagHelpCard(root)
    local cfg = BH():Config()
    local rs = BH():Restock()
    local card = UI:Card(root, T("Sacs, marchand et équipement"))
    local y = -40
    local function row(label, desc, ctrl, w) UI:SettingRow(card, y, label, desc, ctrl, w); y = y - 46 end
    -- barre à l'écran (sacs, marchand, maître) : réglages dans QoL > Général > Marchand
    row("Amélioration à porter", "Un objet qui arrive dans les sacs et vaut mieux que celui porté est proposé (jamais équipé tout seul).",
        UI:Toggle(card, function() return cfg.wear end, function(v) cfg.wear = v; UI:RefreshWearOffer() end), 80)
    row("Réassort chez le marchand", "Un bouton sous la fenêtre du marchand complète ce qui manque, sur un clic (munitions et composants de classe : QoL > Classes).",
        UI:Toggle(card, function() return cfg.restock end, function(v) cfg.restock = v; UI:RefreshRestock() end), 80)
    row("Boissons (ce perso)", "Le meilleur que vend le marchand pour ton niveau.",
        UI:Slider(card, 220, 0, 100, 5, function() return rs.drink or 0 end, function(v) rs.drink = v end, "%d"), 240)
    row("Nourriture (ce perso)", nil, UI:Slider(card, 220, 0, 100, 5, function() return rs.food or 0 end, function(v) rs.food = v end, "%d"), 240)
    -- objets choisis : glisser un objet sur la case ; quantité réglée par - / + ; croix pour retirer
    local drop = CreateFrame("Button", nil, card)
    drop:SetSize(34, 34)
    drop.bg = UI:Rounded(drop, 8, 0, "BACKGROUND", 1); drop.bg:SetColor(unpack(C.surface2))
    drop.plus = UI:Icon(drop, "plus", 14, nil, "ARTWORK"); drop.plus:SetPoint("CENTER")
    drop:SetPoint("TOPLEFT", 16, y - 4)
    local dl = UI:Text(card, 12); dl:SetPoint("LEFT", drop, "RIGHT", 10, 6); dl:SetText(T("Autres objets à garder en stock"))
    local dd = UI:Text(card, 10, C.muted); dd:SetPoint("LEFT", drop, "RIGHT", 10, -8); dd:SetText(T("Glisse un objet des sacs sur la case (composants, flacons…)."))
    y = y - 46
    local rows = {}
    local MAXR = 6
    local function refreshItems()
        local ids = {}
        for id in pairs(rs.items) do ids[#ids + 1] = id end
        table.sort(ids)
        for i = 1, MAXR do
            local r = rows[i]
            local id = ids[i]
            r:SetShown(id ~= nil)
            if id then
                r.id = id
                local name = WK.GetItemInfo(id)
                r.name:SetText(name or ("#" .. id))
                r.qty:SetText(tostring(rs.items[id]))
            end
        end
    end
    local function add()
        local kind, id
        if GetCursorInfo then kind, id = GetCursorInfo() end
        if kind ~= "item" or not id then return end
        ClearCursor()
        local n = 0
        for _ in pairs(rs.items) do n = n + 1 end
        if not rs.items[id] and n >= MAXR then return end
        rs.items[id] = rs.items[id] or (select(8, WK.GetItemInfo(id)) or 20)
        refreshItems()
    end
    drop:SetScript("OnReceiveDrag", add)
    drop:SetScript("OnClick", add)
    for i = 1, MAXR do
        local r = CreateFrame("Frame", nil, card)
        r:SetHeight(24)
        r:SetPoint("TOPLEFT", 16, y - (i - 1) * 26); r:SetPoint("RIGHT", card, "RIGHT", -16, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 4, 0); r.name:SetPoint("RIGHT", -150, 0)
        r.del = UI:IconButton(r, "close", 20, T("Retirer"), true); r.del:SetPoint("RIGHT", 0, 0)
        r.plus = UI:IconButton(r, "plus", 20, "+5"); r.plus:SetPoint("RIGHT", r.del, "LEFT", -12, 0)
        r.qty = UI:Text(r, 11); r.qty:SetWidth(44); r.qty:SetJustifyH("CENTER"); r.qty:SetPoint("RIGHT", r.plus, "LEFT", -4, 0)
        r.minus = UI:IconButton(r, "minus", 20, "-5"); r.minus:SetPoint("RIGHT", r.qty, "LEFT", -4, 0)
        r.plus:SetScript("OnClick", function() rs.items[r.id] = (rs.items[r.id] or 0) + 5; refreshItems() end)
        r.minus:SetScript("OnClick", function() rs.items[r.id] = math.max(1, (rs.items[r.id] or 0) - 5); refreshItems() end)
        r.del:SetScript("OnClick", function() rs.items[r.id] = nil; refreshItems() end)
        rows[i] = r
    end
    y = y - MAXR * 26
    refreshItems()
    -- ouvrir tout seul (Modules/BagHelp.lua : OpenNext) : palourdes et objets choisis, ou tout ce qui s'ouvre
    y = y - 10
    row("Ouvrir tout seul certains objets", "Palourdes et objets de la liste, un par un, hors combat ; jamais chez un marchand, à la banque, à la boîte aux lettres ni à l'échange, ni sans case libre.",
        UI:Toggle(card, function() return cfg.autoOpen end, function(v) cfg.autoOpen = v; if v then BH():OpenNext() end end), 80)
    local seg = UI:Segmented(card, { { "list", "La liste" }, { "all", "Tout ce qui s'ouvre" } }, function(v) cfg.openMode = v end, 24)
    row("Quoi ouvrir", "« Tout ce qui s'ouvre » : sacs, coffrets et palourdes, sauf les coffrets fermés à clé.", seg, seg:GetWidth())
    seg:Select(cfg.openMode or "list")
    local odrop = CreateFrame("Button", nil, card)
    odrop:SetSize(34, 34)
    odrop.bg = UI:Rounded(odrop, 8, 0, "BACKGROUND", 1); odrop.bg:SetColor(unpack(C.surface2))
    odrop.plus = UI:Icon(odrop, "plus", 14, nil, "ARTWORK"); odrop.plus:SetPoint("CENTER")
    odrop:SetPoint("TOPLEFT", 16, y - 4)
    local ol = UI:Text(card, 12); ol:SetPoint("LEFT", odrop, "RIGHT", 10, 6); ol:SetText(T("Objets à ouvrir"))
    local od = UI:Text(card, 10, C.muted); od:SetPoint("LEFT", odrop, "RIGHT", 10, -8); od:SetText(T("Glisse un objet des sacs sur la case pour l'ajouter."))
    y = y - 46
    local OMAX = 8
    local orows = {}
    local function refreshOpen()
        local list = BH():OpenList()
        local ids = {}
        for id in pairs(list) do ids[#ids + 1] = id end
        table.sort(ids)
        for i = 1, OMAX do
            local r = orows[i]
            local id = ids[i]
            r:SetShown(id ~= nil)
            if id then
                r.id = id
                r.name:SetText(WK.GetItemInfo(id) or ("#" .. id))
            end
        end
    end
    local function oadd()
        local kind, id
        if GetCursorInfo then kind, id = GetCursorInfo() end
        if kind ~= "item" or not id then return end
        ClearCursor()
        local list = BH():OpenList()
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        if not list[id] and n >= OMAX then return end
        list[id] = true
        refreshOpen()
    end
    odrop:SetScript("OnReceiveDrag", oadd)
    odrop:SetScript("OnClick", oadd)
    for i = 1, OMAX do
        local r = CreateFrame("Frame", nil, card)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 16, y - (i - 1) * 24); r:SetPoint("RIGHT", card, "RIGHT", -16, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 4, 0); r.name:SetPoint("RIGHT", -30, 0)
        r.del = UI:IconButton(r, "close", 20, T("Retirer"), true); r.del:SetPoint("RIGHT", 0, 0)
        r.del:SetScript("OnClick", function() BH():OpenList()[r.id] = nil; refreshOpen() end)
        orows[i] = r
    end
    y = y - OMAX * 24
    refreshOpen()
    card:HookScript("OnShow", refreshOpen)
    card:SetHeight(-y + 10)
    card:HookScript("OnShow", refreshItems)
    return card
end
