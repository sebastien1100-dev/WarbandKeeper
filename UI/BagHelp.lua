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
-- taille des icônes (réglage barSize) : côté de la case, icône, texte
local TILE_SIZES = { s = { 38, 18, 10 }, m = { 46, 22, 11 }, l = { 56, 28, 12 } }
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
    -- recherche refaite seulement après un vrai déplacement (plus de 150 m ou autre carte), 10 s au plus tôt :
    -- elle parcourt tous les lieux du jeu (jusqu'à 6 ms) ; immobile ou en ville, le résultat ne change pas
    local p0 = G:PlayerPos()
    local moved = not n or not n.pos or not p0 or p0.map ~= n.pos.map
        or (G:Vector(p0, n.pos) or 1e9) > 150
    if not n or (now - n.at > 10 and moved) or now - n.at > 120 then
        local class = what == "trainer" and select(2, UnitClass("player")) or nil
        local ok, t = pcall(G.Nearest, G, G:KindsFor(what), class)
        n = { at = now, t = ok and t or nil, pos = p0 and { map = p0.map, x = p0.x, y = p0.y, cont = p0.cont,
            wx = p0.wx, wy = p0.wy } or nil }
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
    function b:Resize(side, ic)
        self:SetSize(side, side)
        self.icon:SetSize(ic, ic)
        self.icon:ClearAllPoints(); self.icon:SetPoint("CENTER", 0, math.floor(side / 11 + 0.5))
    end
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
    f.edge = UI:Rounded(f, 10, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 9, 1, "BACKGROUND", 1)
    -- fond commun (opacité des Options, pleine au survol) ; réglage « sans fond » : rien du tout
    UI:HudRegister(f).hudCustom = true
    function f:OnHudPaint()
        if self.noBg then
            self.bg:SetColor(0, 0, 0, 0); self.edge:SetColor(0, 0, 0, 0)
        else UI:HudPaint(self) end
    end
    f.seps = {}
    for i = 1, 6 do
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
    -- bouton « replier » en tête de barre (maquette B) : clic gauche = replier ou déplier (réglage barFold) ;
    -- replié, une pastille rouge respire dans son coin tant qu'une case est en alerte
    f.fold = newTile(f, "menu")
    f.fold:RegisterForClicks("LeftButtonUp")
    f.fold.n:Hide()
    f.fold.dot = f.fold:CreateTexture(nil, "OVERLAY")
    f.fold.dot:SetTexture(UI.MEDIA .. "circle")
    f.fold.dot:SetSize(9, 9); f.fold.dot:SetPoint("TOPRIGHT", -4, -7)
    f.fold.dot:Hide()
    f.fold.pulse = _G.CreateFrame("Frame", nil, f.fold)
    f.fold.pulse:Hide()
    f.fold.pulse:SetScript("OnUpdate", function(_, el)
        local d = f.fold
        d.ph = ((d.ph or 0) + el) % 1.6
        local k = 0.5 - 0.5 * math.cos(d.ph / 1.6 * 2 * math.pi)
        local c = C.negative
        d.dot:SetVertexColor(c[1], c[2], c[3], 0.35 + 0.65 * k)
        local z = 8 + 3 * k
        d.dot:SetSize(z, z)
    end)
    -- cases en alerte (qui clignotent) : aujourd'hui la case des buffs
    function f:Alerts()
        local n = 0
        for _, t in ipairs({ self.bag, self.vendor, self.trainer, self.kit, self.buffs }) do
            if t.alertOn and t.wkWanted then n = n + 1 end
        end
        return n
    end
    function f:PaintFold()
        local b = self.fold
        local folded = BH():Config().barFolded and true or false
        local r, g, bl = UI:Accent()
        b.icon:SetVertexColor(r, g, bl, 1)
        local alert = folded and self:Alerts() > 0
        b.dot:SetShown(alert); b.pulse:SetShown(alert)
    end
    f.fold:SetScript("OnEnter", function(s)
        local folded = BH():Config().barFolded
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Sacs, marchand et maître"), 1, 1, 1)
        local n = f:Alerts()
        if folded and n > 0 then
            _G.GameTooltip:AddLine(string.format(T("%d case(s) en alerte"), n), UI.RGB(C.negative))
        end
        _G.GameTooltip:AddLine(folded and T("Clic : déplier la barre") or T("Clic : replier la barre"), 0.6, 0.6, 0.6)
        _G.GameTooltip:Show()
    end)
    f.fold:SetScript("OnClick", function(s)
        local cfg = BH():Config()
        cfg.barFolded = not cfg.barFolded or nil
        UI:RefreshBagSpace()
        if UI.RefreshCampKit and not inCombat() then pcall(UI.RefreshCampKit, UI) end
        if UI.RefreshSelfBuffs and not inCombat() then pcall(UI.RefreshSelfBuffs) end
        if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
    end)
    -- mise en page : cases visibles côte à côte, trait entre deux cases
    function f:Arrange(showV, showT, showK, showB)
        local cfg = BH():Config()
        local sz = TILE_SIZES[cfg.barSize or "m"] or TILE_SIZES.m
        TILE = sz[1]
        self:SetHeight(TILE)
        local FW = math.floor(TILE * 0.62 + 0.5)
        self.fold:Resize(TILE, sz[2] - 4); self.fold:SetWidth(FW)
        for _, t in ipairs({ self.bag, self.vendor, self.trainer, self.kit, self.buffs }) do t:Resize(TILE, sz[2]) end
        self.bag.wkWanted = true
        self.vendor.wkWanted, self.trainer.wkWanted = showV and true, showT and true
        self.kit.wkWanted, self.buffs.wkWanted = showK and true, showB and true
        local useFold = cfg.barFold ~= false
        local folded = useFold and cfg.barFolded
        local tiles = {}
        if useFold then tiles[1] = self.fold end
        self.fold:SetShown(useFold)
        self.bag:SetShown(not folded)
        if folded then showV, showT, showK, showB = false, false, false, false
        else tiles[#tiles + 1] = self.bag end
        if showV then tiles[#tiles + 1] = self.vendor end
        if showT then tiles[#tiles + 1] = self.trainer end
        if showK then tiles[#tiles + 1] = self.kit end
        if showB then tiles[#tiles + 1] = self.buffs end
        self.buffs:SetShown(showB and true or false)
        self.vendor:SetShown(showV and true or false)
        self.trainer:SetShown(showT and true or false)
        self.kit:SetShown(showK and true or false)
        local x = 0
        for _, t in ipairs(tiles) do
            t:ClearAllPoints(); t:SetPoint("LEFT", x, 0)
            x = x + t:GetWidth() + 1
        end
        local bg, seps = cfg.barBg ~= false, cfg.barSeps ~= false
        for i, s in ipairs(self.seps) do
            s:ClearAllPoints()
            if tiles[i + 1] and seps then
                s:SetPoint("TOPLEFT", tiles[i], "TOPRIGHT", 0, -9); s:SetPoint("BOTTOMLEFT", tiles[i], "BOTTOMRIGHT", 0, 9)
                s:Show()
            else s:Hide() end
        end
        self:SetWidth(math.max(1, x - 1))
        -- sans fond (réglage barBg) : chiffres cernés de noir pour rester lisibles sur le jeu
        self.noBg = not bg
        self:OnHudPaint()
        local fkey = (bg and "b" or "o") .. sz[3]
        if self.fontKey ~= fkey then
            self.fontKey = fkey
            for _, t in ipairs({ self.bag, self.vendor, self.trainer, self.kit, self.buffs }) do
                t.n:SetFont(UI.FONT, math.floor(sz[3] * (UI.textScale or 1) + 0.5), bg and "" or "OUTLINE")
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
        self:PaintFold()
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
    space:PaintFold()
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
local WEAR_SECS = 10 -- la proposition se ferme d'elle-même au bout de 10 s (pause au survol)
local function buildWear()
    local f = CreateFrame("Frame", "WarbandKeeperWearOffer", UIParent)
    f:SetSize(320, 78)
    f:SetFrameStrata("MEDIUM")
    UI:HudBackground(f, "hud", 12)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(34, 34); f.icon:SetPoint("TOPLEFT", 12, -12)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = UI:Text(f, 10, C.muted); f.title:SetPoint("TOPLEFT", 56, -12); f.title:SetText(UI:Upper(T("Mieux que ce que tu portes")))
    -- fermer : la fenêtre se retire sans rien refuser ; elle revient au prochain objet meilleur
    f.close = UI:IconButton(f, "close", 16, "Fermer (revient au prochain objet meilleur)")
    f.close:SetPoint("TOPRIGHT", -8, -8)
    local function dismiss()
        local M = BH()
        if M and M.queue then for i = #M.queue, 1, -1 do M.queue[i] = nil end end
        f:Hide()
    end
    f.close:SetScript("OnClick", dismiss)
    -- fermeture d'elle-même au bout de WEAR_SECS (comme la croix), barre qui se vide en bas ; pause au survol
    f.timer = f:CreateTexture(nil, "OVERLAY"); f.timer:SetHeight(2)
    f.timer:SetPoint("BOTTOMLEFT", 10, 3)
    f:SetScript("OnUpdate", function(s2, el)
        if s2.sample or not s2.left then return end
        if not s2:IsMouseOver() then s2.left = s2.left - el end
        local r, g, b = UI:Accent()
        s2.timer:SetColorTexture(r, g, b, 0.8)
        s2.timer:SetWidth(math.max(0.01, (s2:GetWidth() - 20) * math.max(0, s2.left) / WEAR_SECS))
        if s2.left <= 0 then s2.left = nil; dismiss() end
    end)
    f.name = UI:Text(f, 12); f.name:SetPoint("TOPLEFT", 56, -26); f.name:SetPoint("TOPRIGHT", -30, -26)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 56, -42); f.sub:SetPoint("TOPRIGHT", -12, -42)
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
    -- nouvel objet proposé : le compte à rebours repart
    if wear.q ~= q or not wear:IsShown() then wear.left = WEAR_SECS end
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
    -- notre inventaire (UI/Bags.lua) : remplace les sacs du jeu ; changement pris en compte au /reload
    local bc = UI.Bags and UI.Bags.Config()
    if bc then
        row("Notre inventaire",
            "Sacs rangés par catégories (nouveaux, équipement, tes composants, pour d'autres persos, quête, camelote…) "
            .. "à la place des sacs du jeu. Coupe celui d'un autre addon de sacs.",
            UI:Toggle(card, function() return bc.enabled end, function(v)
                bc.enabled = v
                if UI.AskReload then UI:AskReload(T("Inventaire changé : recharger l'interface pour l'appliquer.")) end
            end), 80)
        row("Fiche de l'objet survolé",
            "À droite des sacs : prix, qui en a besoin sur le compte, verrouiller, désenchanter, chercher à l'HV.",
            UI:Toggle(card, function() return bc.fiche end, function(v)
                bc.fiche = v
                if UI.AskReload then UI:AskReload(T("Inventaire changé : recharger l'interface pour l'appliquer.")) end
            end), 80)
        row("Notre banque",
            "À la banque, la même fenêtre que nos sacs (catégories, filtres, fiche) à la place de celle du jeu.",
            UI:Toggle(card, function() return bc.bankWin ~= false end, function(v)
                bc.bankWin = v
                if UI.AskReload then UI:AskReload(T("Inventaire changé : recharger l'interface pour l'appliquer.")) end
            end), 80)
        -- camelote (Modules/QoL.lua : IsJunk) : vendue avec les gris
        local qg = WK.modules.QoL:General()
        row("Camelote : vert impossible à porter",
            "L'équipement vert que ce perso ne peut pas porter part avec « Vendre la camelote »"
                .. " (jamais un objet verrouillé).",
            UI:Toggle(card, function() return qg.junkUnusable end,
                function(v) qg.junkUnusable = v; WK:NotifyChanged() end), 80)
        row("Camelote : équipement blanc",
            "L'équipement de qualité commune (blanc) part avec « Vendre la camelote »."
                .. " Marquer un objet à la main : bouton de la fiche.",
            UI:Toggle(card, function() return qg.junkWhite end,
                function(v) qg.junkWhite = v; WK:NotifyChanged() end), 80)
        row("Infobulle allégée dans nos sacs",
            "Les infos de l'addon (persos, prix, métiers, ventes) ne sont que dans la fiche ;"
                .. " l'infobulle du jeu reste courte.",
            UI:Toggle(card, function() return bc.lightTip ~= false end, function(v) bc.lightTip = v end), 80)
    end
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
        r:SetPoint("TOPLEFT", 16, y - (i - 1) * 26); r:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, y - (i - 1) * 26)
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
        r:SetPoint("TOPLEFT", 16, y - (i - 1) * 24); r:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, y - (i - 1) * 24)
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

---------------------------------------------------------------------------
-- Alerte munitions (maquette C) : icône de tes munitions (50 px) dans un anneau qui se vide avec elles.
-- Sous le seuil : anneau orange qui respire ; sous un quart : rouge ; à zéro : toute l'icône flashe en rouge.
-- Réglages (carte « Munitions » de la classe) : cc.ammo.hud (affichée, défaut oui), cc.ammo.hudAlways
-- (toujours visible, sinon seulement sous le seuil). Place, taille et opacité : mode édition (pleine au survol).
-- Clic : guidage vers le marchand le plus proche. Reste visible en combat (c'est là qu'on manque de flèches).
---------------------------------------------------------------------------
local ammo
local AMMO_SIZE = 50
local CreateFrame, UIParent, GameTooltip, GetTime = _G.CreateFrame, _G.UIParent, _G.GameTooltip, _G.GetTime
local UnitClass, C_Timer, C_Item = _G.UnitClass, _G.C_Timer, _G.C_Item
local function ammoCfg()
    local Q = WK.modules.QoL
    local cls = select(2, UnitClass("player"))
    if not (Q and Q.AMMO and Q.AMMO[cls or ""]) then return nil end
    local cc = Q:Config().classes[cls]
    return cc and cc.ammo
end
-- état : nil (rien à montrer), ou { n, frac (0..1 de l'anneau), level = ok / low / red / empty }
local function ammoState()
    local a = ammoCfg()
    local c = WK.DB:Me()
    if not (a and a.hud ~= false and c and c.ammo and c.ammo.id and WK:FeatureOn("classes")) then return nil end
    local n = c.ammo.n or 0
    local mins = c.ammo.speed and (n * c.ammo.speed / 60) or nil
    local min, minM = a.min or 0, a.minMinutes or 0
    local ratio -- part restante du seuil (le plus bas des deux seuils)
    if min > 0 then ratio = n / min end
    if minM > 0 and mins then local r = mins / minM; if not ratio or r < ratio then ratio = r end end
    local level = "ok"
    if n == 0 then level = "empty"
    elseif ratio and ratio < 0.25 then level = "red"
    elseif ratio and ratio < 1 then level = "low" end
    if level == "ok" and not a.hudAlways then return nil end
    local full = (min > 0 and min) or (a.buy and a.buy > 0 and a.buy) or n
    local frac = math.max(0, math.min(1, full > 0 and n / full or 0))
    return { id = c.ammo.id, n = n, mins = mins, frac = frac, level = level }
end
local function buildAmmo()
    local f = CreateFrame("Button", "WarbandKeeperAmmoAlert", UIParent)
    f:SetSize(AMMO_SIZE + 24, AMMO_SIZE + 36)
    f:SetFrameStrata("MEDIUM")
    f:RegisterForClicks("LeftButtonUp")
    -- anneau : fond sombre + balayage (part restante), comme l'anneau du curseur
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetSize(AMMO_SIZE + 12, AMMO_SIZE + 12); f.track:SetPoint("TOP", 0, 0)
    f.track:SetTexture(UI.MEDIA .. "ring")
    f.track:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.9)
    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.track)
    f.cd:EnableMouse(false)
    if f.cd.SetSwipeTexture then f.cd:SetSwipeTexture(UI.MEDIA .. "ring") end
    if f.cd.SetDrawEdge then f.cd:SetDrawEdge(false) end
    if f.cd.SetDrawBling then f.cd:SetDrawBling(false) end
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
    if f.cd.SetUseCircularEdge then f.cd:SetUseCircularEdge(true) end
    -- sens normal : la partie colorée = la part restante (à l'envers, rien ne s'affichait au-dessus du seuil)
    if f.cd.SetReverse then f.cd:SetReverse(false) end
    -- disque de fond sous l'icône (50 px, pas tout le cadre) et icône découpée en rond
    f.flash = f:CreateTexture(nil, "BACKGROUND", nil, -1)
    f.flash:SetSize(AMMO_SIZE, AMMO_SIZE); f.flash:SetPoint("CENTER", f.track, "CENTER")
    f.flash:SetTexture(UI.MEDIA .. "circle")
    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 3)
    f.icon:SetSize(AMMO_SIZE - 6, AMMO_SIZE - 6); f.icon:SetPoint("CENTER", f.track, "CENTER")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if f.CreateMaskTexture and f.icon.AddMaskTexture then
        local m = f:CreateMaskTexture()
        m:SetTexture(UI.MEDIA .. "circle", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.icon)
        f.icon:AddMaskTexture(m)
    end
    f.red = f:CreateTexture(nil, "ARTWORK", nil, 4) -- voile rouge sur l'icône (flash à zéro)
    f.red:SetAllPoints(f.icon)
    f.red:SetTexture(UI.MEDIA .. "circle")
    f.red:SetVertexColor(C.negative[1], C.negative[2], C.negative[3], 0)
    -- nombre bien lisible : 16 px avec contour, sur une pastille sombre bordée de la couleur de l'état
    f.countBox = CreateFrame("Frame", nil, f)
    f.countBox:SetPoint("TOP", f.track, "BOTTOM", 0, 2)
    f.countBox:SetSize(40, 20)
    f.countEdge = UI:Rounded(f.countBox, 10, 0, "BACKGROUND", 1)
    f.countBg = UI:Rounded(f.countBox, 9, 1, "BACKGROUND", 2)
    f.count = UI:Text(f.countBox, 16); f.count:SetPoint("CENTER", 0, 0)
    do
        local font, size = f.count:GetFont()
        if font then f.count:SetFont(font, size, "OUTLINE") end
    end
    f:SetScript("OnEnter", function(s)
        local st = s.st
        if not st then return end
        UI:TooltipOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText((WK.GetItemInfo(st.id)) or T("Munitions"), 1, 1, 1)
        GameTooltip:AddLine(string.format(T("%d dans les sacs"), st.n), 0.9, 0.9, 0.9)
        if st.mins then
            GameTooltip:AddLine(string.format(T("env. %d min de tir"), math.floor(st.mins)), 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(T("Clic : guider vers le marchand le plus proche"), 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function()
        local G = WK.modules.Guide
        if G and G.GoTo then pcall(G.GoTo, G, "ammo") end
    end)
    function f:Paint(st)
        self.st = st
        -- icône du jeu pour le genre de munitions : balle (sous-classe 3 des projectiles) ou flèche (2, par défaut)
        local sub
        if C_Item and C_Item.GetItemInfoInstant then sub = select(7, C_Item.GetItemInfoInstant(st.id)) end
        local bullet = sub == 3
        self.icon:SetTexture("Interface\\Icons\\INV_Ammo_" .. (bullet and "Bullet_02" or "Arrow_02"))
        local col = (st.level == "ok" and { UI:Accent() }) or (st.level == "low" and C.warning) or C.negative
        self.cd:SetSwipeColor(col[1], col[2], col[3], 1)
        -- balayage figé à la part restante : un « temps de recharge » arrêté
        if self.cd.SetCooldown then
            self.cd:SetCooldown(GetTime() - (1 - st.frac) * 100, 100)
            if self.cd.Pause then self.cd:Pause() end
        end
        self.count:SetText(tostring(st.n))
        -- texte clair sur la pastille ; la couleur de l'état passe par le bord (orange, rouge) et le texte
        local tc = st.level == "ok" and C.text or col
        self.count:SetTextColor(tc[1], tc[2], tc[3])
        self.countBox:SetWidth(math.max(34, (self.count:GetStringWidth() or 20) + 16))
        self.countEdge:SetColor(col[1], col[2], col[3], 1)
        self.countBg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
        self.flash:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
        -- vitesse de la pulsation : lente (orange), moyenne (rouge), rapide (vide) ; aucune quand tout va bien
        self.period = (st.level == "low" and 1.4) or (st.level == "red" and 0.8) or (st.level == "empty" and 0.5) or nil
    end
    -- pulsation : anneau qui respire, voile rouge sur l'icône à zéro
    local t = 0
    f:SetScript("OnUpdate", function(s, el)
        t = t + el
        local p = s.period
        if not p then s.cd:SetAlpha(1); s.red:SetVertexColor(C.negative[1], C.negative[2], C.negative[3], 0) return end
        local k = 0.5 + 0.5 * math.sin(t * 2 * math.pi / p)
        s.cd:SetAlpha(0.45 + 0.55 * k)
        local empty = s.st and s.st.level == "empty"
        s.red:SetVertexColor(C.negative[1], C.negative[2], C.negative[3], empty and (0.65 * k) or 0)
    end)
    f:Hide()
    UI:RegisterHUD("ammoAlert", f, {
        label = T("Alerte munitions"), default = { 0, -120 },
        enabled = function() local a = ammoCfg(); return a ~= nil and a.hud ~= false end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint({ id = 2512, n = 312, mins = 3, frac = 0.78, level = "low" }); f:Show()
            else UI:RefreshAmmoAlert() end
        end,
        test = function()
            f.sample = true
            f:Paint({ id = 2512, n = 0, frac = 0, level = "empty" }); f:Show()
        end,
        testStop = function() f.sample = nil; UI:RefreshAmmoAlert() end,
    })
    return f
end
function UI.RefreshAmmoAlert(_)
    if not ammoCfg() then if ammo then ammo:Hide() end return end
    ammo = ammo or buildAmmo()
    if ammo.sample then return end
    local st = ammoState()
    if not st then ammo:Hide() return end
    ammo:Paint(st)
    ammo:Show()
end
-- relu toutes les secondes (tirs, achats, flèches ramassées) : lecture légère des chiffres déjà relevés
if C_Timer.NewTicker then C_Timer.NewTicker(1, function() UI:RefreshAmmoAlert() end) end
