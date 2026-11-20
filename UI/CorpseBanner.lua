local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Retour au corps : mort (fantôme), un bandeau dit à quelle distance est le corps et combien de temps il faut
-- pour y courir, ce que coûte l'ange gardien (mal de résurrection, usure de l'équipement), conseille l'un ou
-- l'autre et guide vers le corps (flèche, épingle, trajet du Guide). Le guidage d'avant revient une fois en
-- vie. Corps : C_DeathInfo.GetCorpseMapPosition, sinon l'endroit de la mort (noté à PLAYER_DEAD).
-- Réglage Guide:Config().corpse (QoL > Carte et guidage, onglet Guidage). HUD « corpseBanner ».
local W = 340
local banner
local deathAt          -- { cont, wx, wy, map, x, y } : où le perso est mort
local prevTarget       -- guidage en cours avant la mort, rendu après
local FAR = 180        -- s : au-delà, l'ange gardien est conseillé

local function G() return WK.modules.Guide end
local function cfgOn() return G():Config().corpse ~= false and WK:FeatureOn("maplayers") end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- position du corps : { map, x, y (0..1), cont, wx, wy } ou nil
local function corpsePos()
    local p = G():PlayerPos()
    if C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
        local maps = {}
        if p and p.map then
            maps[1] = p.map
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(p.map)
            if info and info.parentMapID then maps[2] = info.parentMapID end
        end
        if deathAt and deathAt.map then table.insert(maps, deathAt.map) end
        for _, m in ipairs(maps) do
            local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, m)
            if ok and pos then
                local x, y = pos.x, pos.y
                if pos.GetXY then x, y = pos:GetXY() end
                if x and (x ~= 0 or y ~= 0) then
                    local c, wx, wy = G().ToWorld(m, x, y)
                    if c then return { map = m, x = x, y = y, cont = c, wx = wx, wy = wy } end
                end
            end
        end
    end
    return deathAt
end

-- ce que coûte l'ange gardien selon le niveau (mal de résurrection à partir du niveau 11)
local function healerCost()
    local lvl = UnitLevel and UnitLevel("player") or 60
    if lvl <= 10 then return T("Ange gardien : pas de mal de résurrection à ton niveau, -25 % d'usure de l'équipement.") end
    local mins = lvl >= 20 and 10 or (lvl - 10)
    return string.format(T("Ange gardien : mal de résurrection %d min (caractéristiques -75 %%) et -25 %% d'usure de l'équipement."), mins)
end

-- état : { d (m), secs, cont = même continent ?, advice = "corpse" | "healer" }
function UI:CorpseState()
    local p, c = G():PlayerPos(), corpsePos()
    if not (p and c) then return nil end
    if p.cont ~= c.cont then return { far = true, advice = "healer", corpse = c } end
    local d = dist(p.wx, p.wy, c.wx, c.wy)
    local speed = math.max(7, (GetUnitSpeed and GetUnitSpeed("player")) or 0)
    local secs = d / speed
    return { d = d, secs = secs, advice = secs > FAR and "healer" or "corpse", corpse = c }
end

local started -- guidage vers le corps déjà lancé pour cette mort (pas relancé s'il a été arrêté)
local function startGuide(c)
    local g = G()
    if started or (g.target and g.target.kind == "corpse") then return end
    started = true
    prevTarget = g.target
    local t = { map = c.map, x = c.x, y = c.y, cont = c.cont, wx = c.wx, wy = c.wy,
                e = { (c.x or 0) * 100, (c.y or 0) * 100, 0, nil, nil, T("Ton corps"), T("Ton corps"), T("Retour au corps") } }
    g:Start(t, "Retour au corps", "corpse")
end
local function stopGuide()
    local g = G()
    if not (prevTarget or (g.target and g.target.kind == "corpse")) then return end
    -- guidage du corps encore en cours (ou arrivé et arrêté) : le guidage d'avant revient
    if g.target and g.target.kind == "corpse" then g:Stop() end
    if prevTarget and not g.target then g:Start(prevTarget, prevTarget.reason, prevTarget.kind) end
    prevTarget = nil
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperCorpseBanner", UIParent)
    f:SetSize(W, 64)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.icon = UI:Icon(f, "skull", 22, nil, "ARTWORK"); f.icon:SetPoint("TOPLEFT", 14, -14)
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 46, -12); f.title:SetPoint("RIGHT", -80, 0)
    f.time = UI:Text(f, 18); f.time:SetPoint("TOPRIGHT", -14, -10); f.time:SetJustifyH("RIGHT")
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("TOPLEFT", 46, -32); f.sub:SetPoint("RIGHT", -14, 0)
    f.sub:SetJustifyH("LEFT")
    f.cost = UI:Text(f, 10, C.dim); f.cost:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -4); f.cost:SetPoint("RIGHT", -14, 0)
    f.cost:SetJustifyH("LEFT")
    function f:Paint(st)
        local Clock = WK.modules.BoatTimes.Clock
        self.icon:SetVertexColor(C.negative[1], C.negative[2], C.negative[3], 1)
        if not st then
            self.title:SetText(T("Retour au corps"))
            self.time:SetText("")
            self.sub:SetText(T("Position du corps inconnue pour l'instant."))
        elseif st.far then
            self.title:SetText(T("Corps sur un autre continent"))
            self.time:SetText("")
            self.sub:SetText(T("Conseil : l'ange gardien, le corps est trop loin."))
        else
            local corpse = st.advice == "corpse"
            self.title:SetText(corpse and T("Retour au corps : cours-y") or T("Corps loin : l'ange gardien est plus rapide"))
            local col = corpse and C.positive or C.gold
            self.time:SetText(T("env.") .. " " .. Clock(st.secs)); self.time:SetTextColor(col[1], col[2], col[3])
            self.sub:SetText(string.format(T("Corps à %d m, environ %s en courant."), math.floor(st.d + 0.5), Clock(st.secs)))
        end
        self.cost:SetText(healerCost())
        self:SetHeight(32 + (self.sub:GetStringHeight() or 12) + 4 + (self.cost:GetStringHeight() or 12) + 12)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 or s.sample then return end
        s.acc = 0
        UI:RefreshCorpse()
    end)
    f:Hide()
    UI:RegisterHUD("corpseBanner", f, {
        label = T("Retour au corps"), default = { 0, 160 },
        enabled = function() return cfgOn() end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint({ d = 420, secs = 48, advice = "corpse" }); f:Show() else UI:RefreshCorpse() end
        end,
    })
    return f
end

function UI:RefreshCorpse()
    if not banner then banner = build() end
    if banner.sample then return end
    local ghost = UnitIsGhost and UnitIsGhost("player")
    if not (ghost and cfgOn()) then
        banner:Hide()
        if not ghost then stopGuide() end
        return
    end
    local st = UI:CorpseState()
    banner:Paint(st)
    banner:Show()
    if st and st.corpse and not st.far and st.advice == "corpse" then startGuide(st.corpse) end
end

WK:On("PLAYER_DEAD", function()
    local p = G():PlayerPos()
    started = nil
    if p then deathAt = { map = p.map, x = p.x, y = p.y, cont = p.cont, wx = p.wx, wy = p.wy } end
end)
-- libéré (fantôme au cimetière) : bandeau ; ressuscité : guidage d'avant rendu
WK:On("PLAYER_ALIVE", function() C_Timer.After(1, function() UI:RefreshCorpse() end) end)
WK:On("PLAYER_UNGHOST", function() deathAt, started = nil, nil; UI:RefreshCorpse() end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, function() UI:RefreshCorpse() end) end)
