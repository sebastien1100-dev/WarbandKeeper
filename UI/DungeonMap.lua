local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip

-- Carte d'un donjon (maquettes A et C) : image du jeu par étage (Modules/DungeonMapsDB.lua, images dans
-- WarbandKeeper_Data\Maps), une pastille par boss à sa place (n° dans l'ordre du jeu ; coche = tué, rose avec
-- halo = prochain, petite et pâle = facultatif), « E » = entrée, boutons d'étage en haut à gauche.
-- UI:DungeonMapView(parent) : page Donjons (sous l'en-tête) et carte du monde remplacée dans le donjon
-- (bas du fichier : _G.WorldMapFrame, réglage Dungeons:Config().worldMap).
local D = WK.modules.Dungeons
local PATH = "Interface\\AddOns\\WarbandKeeper_Data\\Maps\\"
local PIN = 22

-- Données de carte d'un donjon (nil sans carte)
function UI.DungeonMapData(d)
    return d and WK.DungeonMaps and WK.DungeonMaps[d.key] or nil
end

-- Position d'un boss : par son n° de PNJ, ou par son n° de rencontre (boss du nouveau contenu sans n°)
function UI.DungeonBossPin(m, b)
    if not (m and b) then return nil end
    local p = m.p[b.id]
    if not p and b.encounter and m.x and m.x[b.encounter] then p = m.p[m.x[b.encounter]] end
    return p
end

-- Portrait d'un boss (n° de modèle du Dungeon Journal de Naowh Forever) dans une texture, rond ; faux sans portrait
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
function UI.SetBossPortrait(tex, d, b)
    local npc = b and type(b.id) == "number" and b.id > 0 and b.id or nil
    local m = UI.DungeonMapData(d)
    if not npc and b and b.encounter and m and m.x then npc = m.x[b.encounter] end
    local model = npc and WK.DungeonBossModels and WK.DungeonBossModels[npc]
    local fn = _G.SetPortraitTextureFromCreatureDisplayID
    if model and fn and pcall(fn, tex, model) then
        if not tex.wkMasked and tex.SetMask then pcall(tex.SetMask, tex, MASK); tex.wkMasked = true end
        tex:Show()
        return true
    end
    tex:Hide()
    return false
end

-- État d'un boss pour la carte : « dead », « next », « todo » (+ facultatif)
function UI.DungeonBossState(d, b, key, nextB)
    local inRun = D:InRun(d) and key == WK:CharKey()
    local dead = inRun and (D.run.killed[b.id] or D.run.skipped[b.id]) or (not inRun and D:KilledEver(d, b.id, key))
    if dead then return "dead" end
    if nextB and nextB.id == b.id then return "next" end
    return "todo"
end

local function pinPaint(p)
    local st, opt, hl = p.state, p.optional, p.hl
    local r, g, b = UI:Accent()
    p.haloF:SetShown(st == "next" or hl)
    p.halo:SetColor(r, g, b, hl and 0.55 or 0.35)
    if st == "dead" then
        p.ring:SetColor(C.dim[1], C.dim[2], C.dim[3], 1)
        p.fill:SetColor(0.23, 0.25, 0.28, 1)
        p.num:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    elseif st == "next" then
        p.ring:SetColor(1, 1, 1, 1)
        p.fill:SetColor(r, g, b, 1)
        p.num:SetTextColor(C.onAccent[1], C.onAccent[2], C.onAccent[3])
    else
        p.ring:SetColor(r, g, b, opt and 0.6 or 1)
        p.fill:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
        p.num:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    p:SetAlpha(opt and st ~= "next" and 0.8 or 1)
end

function UI.DungeonMapView(_, parent)
    local v = CreateFrame("Frame", nil, parent)
    v.floor = 1
    UI:Panel(v, 8, C.surface, C.border)
    v.tex = v:CreateTexture(nil, "ARTWORK")
    v.tex:SetPoint("TOPLEFT", 1, -1); v.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    v.layer = CreateFrame("Frame", nil, v)
    v.layer:SetAllPoints()
    v.layer:SetFrameLevel(v:GetFrameLevel() + 3)
    -- entrée
    v.entry = CreateFrame("Frame", nil, v.layer)
    v.entry:SetSize(18, 18)
    v.entry.bg = UI:Rounded(v.entry, 4, 0, "ARTWORK", 1)
    v.entry.t = UI:Text(v.entry, 10); v.entry.t:SetPoint("CENTER", 0, 0); v.entry.t:SetText("E")
    v.entry:EnableMouse(true)
    v.entry:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(T("Entrée du donjon"), 1, 1, 1); GameTooltip:Show()
    end)
    v.entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- étages
    v.floorBar = CreateFrame("Frame", nil, v.layer)
    v.floorBar:SetPoint("TOPLEFT", 8, -8)
    v.floorBar:SetHeight(24)
    UI:Panel(v.floorBar, 12, C.bg, C.border)
    v.floorBtns = UI:Pool(function()
        local b = CreateFrame("Button", nil, v.floorBar)
        b:SetHeight(20)
        b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
        b.t = UI:Text(b, 11); b.t:SetPoint("CENTER", 0, 0)
        b:SetScript("OnClick", function(s) v.floor = s.n; v:Refresh() end)
        return b
    end)
    -- pastilles des boss
    v.pins = UI:Pool(function()
        local p = CreateFrame("Button", nil, v.layer)
        p:SetSize(PIN, PIN)
        -- halo (prochain, boss survolé) sous la pastille
        p.haloF = CreateFrame("Frame", nil, p)
        p.haloF:SetPoint("TOPLEFT", -5, 5); p.haloF:SetPoint("BOTTOMRIGHT", 5, -5)
        p.halo = UI:Rounded(p.haloF, PIN / 2 + 5, 0, "BACKGROUND", 1)
        p.core = CreateFrame("Frame", nil, p)
        p.core:SetAllPoints()
        p.core:SetFrameLevel(p.haloF:GetFrameLevel() + 2)
        p.ring = UI:Rounded(p.core, PIN / 2, 0, "ARTWORK", 1)
        p.fill = UI:Rounded(p.core, PIN / 2 - 2, 2, "ARTWORK", 2)
        p.num = UI:Text(p.core, 11); p.num:SetPoint("CENTER", 0, 0)
        p:SetScript("OnEnter", function(s)
            if v.onHover then v.onHover(s.boss) end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(D:BossName(s.boss), 1, 1, 1)
            local bits = {}
            if (s.boss.level or 0) > 0 then bits[#bits + 1] = string.format(T("niveau %d"), s.boss.level) end
            local stTxt = { dead = T("tué"), next = T("prochain") }
            if stTxt[s.state] then bits[#bits + 1] = stTxt[s.state] end
            if s.optional then bits[#bits + 1] = T("facultatif") end
            if #bits > 0 then GameTooltip:AddLine(table.concat(bits, " · "), 0.7, 0.7, 0.7) end
            local c = WK.DB.global.characters[v.key or ""] or WK.DB:Me()
            local loot = UI.DungeonLoot and UI:DungeonLoot(s.boss, "me", c, v.key) or {}
            for i = 1, math.min(4, #loot) do
                local name = UI:ItemInfo(loot[i])
                local q = UI.DungeonQuality and UI.DungeonQuality(loot[i]) or C.text
                GameTooltip:AddLine(name or ("#" .. loot[i]), q[1], q[2], q[3])
            end
            if #loot > 4 then GameTooltip:AddLine(string.format(T("et %d autre(s)"), #loot - 4), 0.6, 0.6, 0.6) end
            if v.onBoss then GameTooltip:AddLine(T("Clic : son butin"), 0.5, 0.5, 0.5) end
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() if v.onHover then v.onHover(nil) end GameTooltip:Hide() end)
        p:SetScript("OnClick", function(s) if v.onBoss then v.onBoss(s.boss) end end)
        return p
    end)

    -- d : donjon ; key : perso montré (passage en cours si c'est le perso connecté)
    function v:SetDungeon(d, key)
        local changed = self.d ~= d
        self.d, self.key = d, key
        self.map = UI.DungeonMapData(d)
        if changed then
            -- étage du prochain boss
            self.floor = 1
            local nb = d and D:Next(d, key)
            local p = nb and UI.DungeonBossPin(self.map, nb)
            if p then self.floor = p[1] end
        end
        self:Refresh()
    end
    -- boss mis en avant (survol d'une ligne de la liste) : passe à son étage
    function v:Highlight(id)
        self.hlId = id
        local p
        if id and self.d then
            for _, b in ipairs(D:Bosses(self.d)) do if b.id == id then p = UI.DungeonBossPin(self.map, b) end end
        end
        if p and p[1] ~= self.floor then self.floor = p[1]; return self:Refresh() end
        for _, pin in ipairs(self.pins.items) do
            if pin:IsShown() then pin.hl = pin.boss and pin.boss.id == id; pinPaint(pin) end
        end
    end
    function v:Refresh()
        self.pins:Reset(); self.floorBtns:Reset()
        local m, d = self.map, self.d
        self:SetShown(m ~= nil)
        if not m then return end
        local floors = #m.f
        if self.floor > floors then self.floor = 1 end
        self.tex:SetTexture(PATH .. m.f[self.floor])
        local S = self:GetWidth() or 300
        if S <= 0 then S = 300 end
        -- boutons d'étage (« 1 », « 2 »… ; caché s'il n'y en a qu'un)
        self.floorBar:SetShown(floors > 1)
        local x = 2
        local r, g, b = UI:Accent()
        for i = 1, floors do
            local fb = self.floorBtns:Get()
            fb.n = i
            fb.t:SetText(floors <= 3 and string.format(T("Étage %d"), i) or tostring(i))
            fb:SetWidth((fb.t:GetStringWidth() or 10) + 16)
            fb:ClearAllPoints(); fb:SetPoint("LEFT", x, 0); x = x + fb:GetWidth() + 2
            local sel = i == self.floor
            fb.bg:SetColor(r, g, b, 1); fb.bg:SetShown(sel)
            local tc = sel and C.onAccent or { r, g, b }
            fb.t:SetTextColor(tc[1], tc[2], tc[3])
        end
        self.floorBar:SetWidth(x + 2)
        -- entrée
        local e = m.e
        self.entry:SetShown(e ~= nil and e[1] == self.floor)
        if e then
            self.entry.bg:SetColor(C.gold[1], C.gold[2], C.gold[3], 1)
            self.entry.t:SetTextColor(C.bg[1], C.bg[2], C.bg[3])
            self.entry:ClearAllPoints(); self.entry:SetPoint("CENTER", self, "TOPLEFT", e[2] * S, -e[3] * S)
        end
        -- boss : n° pour ceux qui comptent, « + » pour les facultatifs ; deux boss au même endroit : décalés
        local nextB = D:Next(d, self.key)
        local n, spots = 0, {}
        for _, bo in ipairs(D:Bosses(d)) do
            local opt = D:Optional(d, bo)
            if not opt then n = n + 1 end
            local p = UI.DungeonBossPin(m, bo)
            if p and p[1] == self.floor then
                local pin = self.pins:Get()
                pin.boss, pin.optional = bo, opt
                pin.state = UI.DungeonBossState(d, bo, self.key, nextB)
                pin.hl = self.hlId == bo.id
                pin.num:SetText(pin.state == "dead" and "x" or (opt and "+" or tostring(n)))
                local sk = string.format("%.2f:%.2f", p[2], p[3])
                local dup = spots[sk] or 0
                spots[sk] = dup + 1
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", self, "TOPLEFT", p[2] * S + dup * 14, -p[3] * S - dup * 4)
                pin:SetSize(opt and PIN - 4 or PIN, opt and PIN - 4 or PIN)
                pinPaint(pin)
            end
        end
    end
    UI:OnResize(v, function() if v:IsVisible() then v:Refresh() end end)
    return v
end

---------------------------------------------------------------------------
-- Carte du monde dans le donjon (maquette C) : notre carte à la place de celle du jeu, liste des boss et
-- chrono à droite ; clic droit = carte de la zone (le jeu reprend la main jusqu'à la prochaine ouverture).
---------------------------------------------------------------------------
local over
local function buildOverlay()
    local host = _G.WorldMapFrame.ScrollContainer or _G.WorldMapFrame
    local f = CreateFrame("Frame", "WarbandKeeperDungeonWorldMap", host)
    f:SetAllPoints(host)
    f:SetFrameLevel((host.GetFrameLevel and host:GetFrameLevel() or 1) + 200)
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(); f.bg:SetColorTexture(0, 0, 0, 1)
    f.map = UI:DungeonMapView(f)
    -- colonne de droite : donjon, chrono, boss
    f.side = CreateFrame("Frame", nil, f)
    f.side:SetPoint("TOPRIGHT"); f.side:SetPoint("BOTTOMRIGHT"); f.side:SetWidth(250)
    f.side.bg = f.side:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.side.bg:SetAllPoints(); f.side.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.97)
    f.title = UI:Text(f.side, 13); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetPoint("TOPRIGHT", -12, -12)
    f.title:SetJustifyH("LEFT")
    f.sub = UI:Text(f.side, 11, C.muted); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, f.side)
        r:SetHeight(24)
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 2)
        r.face = r:CreateTexture(nil, "ARTWORK", nil, 2); r.face:SetSize(20, 20); r.face:SetPoint("LEFT", 26, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 52, 0); r.name:SetPoint("RIGHT", -60, 0)
        r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.n = UI:Text(r, 10); r.n:SetPoint("LEFT", 8, 0)
        r.right = UI:Text(r, 10, C.dim); r.right:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnEnter", function(s2) f.map:Highlight(s2.boss and s2.boss.id) end)
        r:SetScript("OnLeave", function() f.map:Highlight(nil) end)
        return r
    end)
    f.hint = UI:Text(f.side, 10, C.dim); f.hint:SetPoint("BOTTOMLEFT", 12, 12); f.hint:SetPoint("BOTTOMRIGHT", -12, 12)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetText(T("Clic droit sur la carte : la carte de la zone."))
    f:SetScript("OnMouseUp", function(s, button)
        if button ~= "RightButton" then return end
        s.userHidden = true; s:Hide()
        local d = s.d
        local wm = _G.WorldMapFrame
        if d and d.entry and wm.SetMapID then pcall(wm.SetMapID, wm, d.entry[1]) end
    end)
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        if s.d and D:InRun(s.d) then s.sub:SetText(s:SubText()) end
    end)
    function f:SubText()
        local d = self.d
        local k, m = 0, 0
        for _, b in ipairs(D:Bosses(d)) do
            if not D:Optional(d, b) then m = m + 1; if D:InRun(d) and D.run.killed[b.id] then k = k + 1 end end
        end
        local txt = string.format(T("%d / %d boss"), k, m)
        if D:InRun(d) then txt = txt .. "  ·  " .. D.Clock(D:Elapsed()) end
        local rec = D:Record(d)
        if rec and rec.dur then txt = txt .. "  ·  " .. string.format(T("record %s"), D.Clock(rec.dur)) end
        return txt
    end
    function f:Fill()
        local d = self.d
        local key = WK:CharKey()
        local H = self:GetHeight() or 500
        local Wd = (self:GetWidth() or 800) - 250
        local S = math.max(200, math.min(H - 16, Wd - 16))
        self.map:ClearAllPoints()
        self.map:SetPoint("CENTER", self, "LEFT", Wd / 2, 0)
        self.map:SetSize(S, S)
        self.map:SetDungeon(d, key)
        self.map:Refresh()
        self.title:SetText(D:Name(d))
        self.sub:SetText(self:SubText())
        self.rows:Reset()
        local nextB = D:Next(d, key)
        local y, n = 56, 0
        local r1, g1, b1 = UI:Accent()
        for _, b in ipairs(D:Bosses(d)) do
            local opt = D:Optional(d, b)
            if not opt then n = n + 1 end
            local st = UI.DungeonBossState(d, b, key, nextB)
            local r = self.rows:Get()
            r.boss = b
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -y); r:SetPoint("TOPRIGHT", -6, -y)
            r.n:SetText(opt and "+" or tostring(n))
            r.name:SetText(D:BossName(b))
            if UI.SetBossPortrait(r.face, d, b) then r.face:SetDesaturated(st == "dead") end
            r.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1); r.bg:SetShown(st == "next")
            local col = st == "dead" and C.muted or C.text
            r.name:SetTextColor(col[1], col[2], col[3])
            local nc = st == "next" and { r1, g1, b1 } or col
            r.n:SetTextColor(nc[1], nc[2], nc[3])
            r.right:SetText(st == "dead" and T("tué") or (st == "next" and T("prochain") or ""))
            local rc = st == "next" and { r1, g1, b1 } or C.dim
            r.right:SetTextColor(rc[1], rc[2], rc[3])
            y = y + 25
        end
    end
    return f
end

-- La carte du monde s'ouvre (ou change de carte) : notre carte si on est dans un donjon qui en a une
local function onMap()
    if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then if over then over:Hide() end return end
    local d = D:Current()
    local on = d and UI.DungeonMapData(d) and D:Config().worldMap ~= false and WK:FeatureOn("dungeons")
    if not on then if over then over:Hide() end return end
    if over and over.userHidden then return end
    over = over or buildOverlay()
    over.d = d
    over:Show()
    over:Fill()
end
UI.DungeonWorldMapCheck = onMap -- (tests)
UI.RefreshDungeonWorldMap = function() if over and over:IsShown() then over:Fill() end end

local hooked
local function hook()
    if hooked or not _G.WorldMapFrame then return end
    hooked = true
    _G.WorldMapFrame:HookScript("OnShow", function() if over then over.userHidden = nil end onMap() end)
    _G.WorldMapFrame:HookScript("OnHide", function() if over then over:Hide(); over.userHidden = nil end end)
end
WK:On("PLAYER_LOGIN", hook)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hook() end end)
WK:On("ZONE_CHANGED_NEW_AREA", function() if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then onMap() end end)
