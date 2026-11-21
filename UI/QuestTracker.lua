local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local CreateFrame, GameTooltip, UIParent, C_Timer = CreateFrame, GameTooltip, UIParent, C_Timer

-- Carte de la quête suivie (HUD « questTrack ») : titre, zone et niveau, objectifs avec coche, jauge et
-- compte, « Camp suivant » et « Rendu » ; la croix arrête le suivi. Données : Modules/QuestTrack.lua.
-- Réglage QuestTrack:Config().hud (roue de la page Quêtes).
local W, ROWS = 236, 6
local card

local function Q() return WK.modules.QuestTrack end
-- 41515 » « 41 515 » (espace fine des milliers)
local function thousands(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return (out:gsub("^ ", ""))
end
local function shown() return WK:FeatureOn("quests") and Q():Config().hud end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperQuestTracker", UIParent)
    f:SetSize(W, 120)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.title = UI:Text(f, 13, C.text); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetPoint("RIGHT", -34, 0)
    f.title:SetJustifyH("LEFT"); if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3); f.sub:SetPoint("RIGHT", -14, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.sub:SetJustifyH("LEFT")
    f.close = UI:IconButton(f, "close", 20, "Ne plus suivre cette quête")
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetScript("OnClick", function()
        if f.guide then WK.modules.LevelGuide:Follow(false)
        elseif f.tour then WK.modules.QuestPlan:Stop() else Q():Untrack() end
    end)
    -- tournée : jauge d'avancée sous le titre
    f.prog = UI:Progress(f, 4)
    f.prog:SetPoint("TOPLEFT", 14, -40); f.prog:SetPoint("RIGHT", -14, 0)
    f.prog:Hide()
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", 14, -44 - (i - 1) * 20); r:SetPoint("RIGHT", -14, 0)
        r.box = r:CreateTexture(nil, "ARTWORK"); r.box:SetSize(11, 11); r.box:SetPoint("LEFT", 0, 0)
        r.name = UI:Text(r, 11, C.text); r.name:SetPoint("LEFT", 18, 0); r.name:SetWidth(104); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.count = UI:Text(r, 10, C.muted); r.count:SetPoint("RIGHT", 0, 0); r.count:SetJustifyH("RIGHT")
        r.bar = UI:Progress(r, 5)
        r.bar:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.bar:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r:Hide()
        f.rows[i] = r
    end
    f.next = UI:Button(f, T("Zone suivante"), nil, 22, "secondary")
    f.next:SetScript("OnClick", function()
        if f.guide then local LG = WK.modules.LevelGuide; local s = LG:Steps()[1]; if s then LG:Skip(s.key) end
        elseif f.tour then WK.modules.QuestPlan:Skip() else Q():NextCamp() end
    end)
    f.next.tooltip = "Vise une autre zone d'un objectif pas fini (de la plus proche à la plus lointaine)."
    f.turn = UI:Button(f, T("Rendu"), nil, 22, "secondary")
    f.turn:SetScript("OnClick", function()
        if f.guide then WK.modules.LevelGuide:Run(1)
        elseif f.tour then local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused) else Q():GoTurnIn() end
    end)
    f.turn.tooltip = "Guide vers le personnage qui reprend la quête."
    f.goal = UI:Text(f, 10, C.muted); f.goal:SetJustifyH("LEFT")

    -- Vue « tournée » : liste fine au texte ombré dans un cadre léger (fond transparent, sans bordure) ;
    -- en-tête (zone, avancée, temps, XP) et barre fine, étape en cours (genre, titre, niveau, PNJ, distance et
    -- direction, XP), objectifs, 2 étapes suivantes avec leur distance ; boutons visibles seulement au survol
    local tv = CreateFrame("Frame", nil, f)
    tv:SetAllPoints()
    tv:Hide()
    f.tv = tv
    local function shade(fs) if fs.SetShadowOffset then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end return fs end
    tv.head = shade(UI:Text(tv, 9, C.muted)); tv.head:SetPoint("TOPLEFT", 12, -9)
    tv.head:SetJustifyH("LEFT"); if tv.head.SetWordWrap then tv.head:SetWordWrap(false) end
    tv.headR = shade(UI:Text(tv, 9, C.muted)); tv.headR:SetPoint("TOPRIGHT", -12, -9); tv.headR:SetJustifyH("RIGHT")
    tv.head2 = shade(UI:Text(tv, 11, C.text)); tv.head2:SetPoint("TOPLEFT", tv.head, "BOTTOMLEFT", 0, -2)
    tv.head2:SetJustifyH("LEFT"); if tv.head2.SetWordWrap then tv.head2:SetWordWrap(false) end
    tv.barBg = tv:CreateTexture(nil, "ARTWORK"); tv.barBg:SetHeight(4)
    tv.barBg:SetPoint("TOPLEFT", 12, -40); tv.barBg:SetPoint("TOPRIGHT", -12, -40)
    tv.barBg:SetColorTexture(1, 1, 1, 0.10)
    tv.bar = tv:CreateTexture(nil, "OVERLAY"); tv.bar:SetHeight(4); tv.bar:SetPoint("TOPLEFT", tv.barBg, "TOPLEFT")
    tv.dot = tv:CreateTexture(nil, "ARTWORK"); tv.dot:SetSize(16, 16); tv.dot:SetTexture(UI.MEDIA .. "circle")
    tv.dot:SetPoint("TOPLEFT", 12, -54)
    tv.mark = tv:CreateFontString(nil, "OVERLAY")
    if not (UI.FONT and tv.mark:SetFont(UI.FONT, 11, "")) then tv.mark:SetFont("Fonts\\FRIZQT__.TTF", 11, "") end
    tv.mark:SetPoint("CENTER", tv.dot, "CENTER", 0, 0); tv.mark:SetTextColor(unpack(C.bg))
    tv.markIcon = UI:Icon(tv, "crosshair", 10, nil, "OVERLAY"); tv.markIcon:SetPoint("CENTER", tv.dot, "CENTER")
    tv.markIcon:SetVertexColor(unpack(C.bg))
    tv.title = shade(UI:Text(tv, 14, C.text)); tv.title:SetPoint("TOPLEFT", 34, -54); tv.title:SetPoint("RIGHT", -10, 0)
    tv.title:SetJustifyH("LEFT"); if tv.title.SetWordWrap then tv.title:SetWordWrap(false) end
    -- titre cliquable (UI/Wowhead.lua) : Maj + clic = lien wowhead, clic droit = menu
    local function hitOn(parent, region)
        local h = CreateFrame("Button", nil, parent)
        h:SetAllPoints(region)
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:SetScript("OnClick", function(s, btn) if s.qids then UI:QuestClick(btn, s.qids, { step = s.step }) end end)
        h:SetScript("OnEnter", function(s)
            if not s.qids then return end
            UI:TooltipOwner(s, "ANCHOR_LEFT")
            GameTooltip:SetText(UI:QuestClickHint(), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return h
    end
    tv.titleHit = hitOn(tv, tv.title)
    tv.sub = shade(UI:Text(tv, 11, C.muted)); tv.sub:SetPoint("TOPLEFT", 34, -52); tv.sub:SetPoint("RIGHT", -10, 0)
    tv.sub:SetJustifyH("LEFT"); if tv.sub.SetWordWrap then tv.sub:SetWordWrap(false) end
    -- objectifs en barres qui se remplissent (couleur de la quête quand l'étape en mélange plusieurs)
    tv.objs = {}
    for i = 1, 8 do
        local r = CreateFrame("Frame", nil, tv); r:SetHeight(20)
        r.bg = UI:Rounded(r, 5, 0, "BACKGROUND", 1)
        r.fillF = CreateFrame("Frame", nil, r); r.fillF:SetPoint("TOPLEFT"); r.fillF:SetPoint("BOTTOMLEFT")
        r.fill = UI:Rounded(r.fillF, 5, 0, "BACKGROUND", 2)
        r.edge = r.fillF:CreateTexture(nil, "ARTWORK"); r.edge:SetWidth(2)
        r.edge:SetPoint("TOPRIGHT", 0, -2); r.edge:SetPoint("BOTTOMRIGHT", 0, 2)
        r.dot = r:CreateTexture(nil, "OVERLAY"); r.dot:SetSize(7, 7); r.dot:SetTexture(UI.MEDIA .. "circle"); r.dot:SetPoint("LEFT", 8, 0)
        r.name = shade(UI:Text(r, 11, C.text)); r.name:SetPoint("LEFT", 21, 0); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.count = shade(UI:Text(r, 11, C.text)); r.count:SetPoint("RIGHT", -8, 0); r.count:SetJustifyH("RIGHT")
        r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r:Hide()
        tv.objs[i] = r
    end
    -- boutons Cibler / Objet de l'étape (visuels ; les boutons protégés sont posés dessus, voir plus bas)
    tv.act = CreateFrame("Frame", nil, tv); tv.act:SetHeight(32)
    local function slot(parent)
        local sl = CreateFrame("Frame", nil, parent); sl:SetSize(28, 28)
        sl.bg = UI:Rounded(sl, 7, 0, "BACKGROUND", 1)
        sl.edge = UI:Rounded(sl, 7, 0, "BACKGROUND", 0)
        sl.icon = sl:CreateTexture(nil, "ARTWORK")
        sl.icon:SetPoint("TOPLEFT", 4, -4); sl.icon:SetPoint("BOTTOMRIGHT", -4, 4)
        sl.count = shade(UI:Text(sl, 9, C.text)); sl.count:SetPoint("BOTTOMRIGHT", 0, 1)
        sl.lbl = shade(UI:Text(parent, 11, C.text)); sl.lbl:SetPoint("TOPLEFT", sl, "TOPRIGHT", 6, -1)
        sl.sub = shade(UI:Text(parent, 10, C.muted)); sl.sub:SetPoint("TOPLEFT", sl.lbl, "BOTTOMLEFT", 0, -1)
        if sl.sub.SetWordWrap then sl.sub:SetWordWrap(false) end
        return sl
    end
    tv.actT = slot(tv.act); tv.actT:SetPoint("LEFT", 0, 0)
    tv.actI = slot(tv.act); tv.actI:SetPoint("LEFT", tv.act, "CENTER", 4, 0)
    tv.act:Hide()
    -- légende des quêtes de l'étape (une couleur chacune)
    tv.legend = {}
    for i = 1, 3 do
        local l = CreateFrame("Frame", nil, tv); l:SetSize(10, 14)
        l.dot = l:CreateTexture(nil, "ARTWORK"); l.dot:SetSize(8, 8); l.dot:SetTexture(UI.MEDIA .. "circle"); l.dot:SetPoint("LEFT", 0, 0)
        l.txt = shade(UI:Text(l, 10, C.muted)); l.txt:SetPoint("LEFT", 12, 0)
        if l.txt.SetWordWrap then l.txt:SetWordWrap(false) end
        l:Hide()
        tv.legend[i] = l
    end
    -- en-tête : total d'XP en gros à droite
    tv.xpBig = shade(UI:Text(tv, 15, C.gold)); tv.xpBig:SetPoint("TOPRIGHT", -12, -8); tv.xpBig:SetJustifyH("RIGHT")
    tv.xpSmall = shade(UI:Text(tv, 9, C.dim)); tv.xpSmall:SetPoint("TOPRIGHT", tv.xpBig, "BOTTOMRIGHT", 0, -1); tv.xpSmall:SetJustifyH("RIGHT")
    tv.nexts = {}
    for i = 1, 2 do
        local r = CreateFrame("Frame", nil, tv); r:SetHeight(16)
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(14, 14); r.dot:SetPoint("LEFT", 0, 0); r.dot:SetTexture(UI.MEDIA .. "circle")
        r.num = UI:Text(r, 8, C.bg); r.num:SetPoint("CENTER", r.dot, "CENTER", 0, 0)
        r.txt = shade(UI:Text(r, 11, C.muted)); r.txt:SetPoint("LEFT", 22, 0); r.txt:SetPoint("RIGHT", 0, 0); r.txt:SetJustifyH("LEFT")
        if r.txt.SetWordWrap then r.txt:SetWordWrap(false) end
        r.hit = hitOn(r, r.txt)
        tv.nexts[i] = r
    end
    -- « Sur ton chemin » (Modules/QuestPlan.lua, OnTheWay) : une ligne discrète sous les étapes suivantes ;
    -- clic gauche : ajouter à la tournée, clic droit : ignorer
    tv.way = CreateFrame("Button", nil, tv)
    tv.way:SetHeight(28)
    tv.way:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tv.way.txt = shade(UI:Text(tv.way, 11, C.text)); tv.way.txt:SetPoint("TOPLEFT", 22, 0); tv.way.txt:SetPoint("RIGHT", 0, 0)
    tv.way.txt:SetJustifyH("LEFT"); if tv.way.txt.SetWordWrap then tv.way.txt:SetWordWrap(false) end
    tv.way.sub = shade(UI:Text(tv.way, 10, C.muted)); tv.way.sub:SetPoint("TOPLEFT", 22, -14); tv.way.sub:SetPoint("RIGHT", 0, 0)
    tv.way.sub:SetJustifyH("LEFT"); if tv.way.sub.SetWordWrap then tv.way.sub:SetWordWrap(false) end
    tv.way.dot = tv.way:CreateTexture(nil, "ARTWORK"); tv.way.dot:SetSize(14, 14); tv.way.dot:SetPoint("TOPLEFT", 0, 0)
    tv.way.dot:SetTexture(UI.MEDIA .. "circle")
    tv.way.num = UI:Text(tv.way, 8, C.bg); tv.way.num:SetPoint("CENTER", tv.way.dot, "CENTER", 0, 0); tv.way.num:SetText("+")
    -- même ligne pour « Tout près » (étape prévue plus loin, juste à côté : clic = la faire maintenant)
    tv.way:SetScript("OnClick", function(b, btn)
        local P = WK.modules.QuestPlan
        if not P then return end
        if b.nearStep then
            if btn == "RightButton" then P:SkipNear(b.nearStep) else P:DoNearNow(b.nearStep) end
            return
        end
        if not b.qid then return end
        if btn == "RightButton" then P:IgnoreOnTheWay(b.qid) else P:AddOnTheWay(b.qid) end
    end)
    tv.way:SetScript("OnEnter", function(b)
        UI:TooltipOwner(b, "ANCHOR_LEFT")
        if b.nearStep then
            GameTooltip:SetText(T("Tout près"), 1, 1, 1)
            GameTooltip:AddLine(T("Une étape prévue plus loin dans la tournée est juste à côté : fais-la maintenant."),
                0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(T("Clic gauche : la faire maintenant · clic droit : plus tard"), 0.6, 0.6, 0.6, true)
        else
            GameTooltip:SetText(T("Sur ton chemin"), 1, 1, 1)
            GameTooltip:AddLine(T("Une quête toute proche du trajet vers l'étape en cours, pas encore dans la tournée."), 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(T("Clic gauche : l'ajouter à la tournée · clic droit : ignorer"), 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    tv.way:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tv.way:Hide()
    -- boutons (pause / reprendre, passer, arrêter) : petits, à la place des chiffres de l'en-tête au survol
    tv.close = UI:IconButton(tv, "close", 16, "Arrêter la tournée")
    tv.close:SetPoint("TOPRIGHT", -8, -4)
    -- même carte pour la tournée et pour le guide de montée (f.tvGuide) : les boutons suivent le mode
    tv.close:SetScript("OnClick", function()
        if f.tvGuide then WK.modules.LevelGuide:Follow(false) else WK.modules.QuestPlan:Stop() end
    end)
    tv.skip = UI:IconButton(tv, "chevron", 16, "Passer l'étape")
    if tv.skip.icon.SetRotation then tv.skip.icon:SetRotation(math.pi / 2) end -- chevron vers la droite
    tv.skip:SetPoint("RIGHT", tv.close, "LEFT", -4, 0)
    tv.skip:SetScript("OnClick", function()
        if f.tvGuide then
            local LG = WK.modules.LevelGuide
            local st = LG:Steps()[1]
            if st then LG:Skip(st.key) end
        else WK.modules.QuestPlan:Skip() end
    end)
    tv.pp = UI:IconButton(tv, "pause", 16, "Pause")
    tv.pp:SetPoint("RIGHT", tv.skip, "LEFT", -4, 0)
    -- roue : réglages de la carte (opacité du fond…) dans la roue de la page Quêtes
    tv.gear = UI:IconButton(tv, "gear", 16, "Réglages de la carte (opacité du fond…)")
    tv.gear:SetPoint("RIGHT", tv.pp, "LEFT", -4, 0)
    tv.gear:SetScript("OnClick", function()
        if UI.ToggleWindow and not (UI.frame and UI.frame:IsShown()) then UI:ToggleWindow() end
        UI:ShowPage("quests")
        local def = UI.pages and UI.pages.quests
        if def and def.side then def.settingsOpen = true; def:Layout(); def:Refresh() end
    end)
    tv.pp:SetScript("OnClick", function()
        if f.tvGuide then WK.modules.LevelGuide:Run(1) return end
        local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused)
    end)
    local function hoverButtons(on)
        for _, b in ipairs({ tv.close, tv.skip, tv.pp, tv.gear }) do b:SetShown(on) end
        tv.xpBig:SetShown(not on); tv.xpSmall:SetShown(not on)
    end
    hoverButtons(false)
    tv:SetScript("OnUpdate", function(v, el)
        v.h = (v.h or 0) + el
        if v.h < 0.1 then return end
        v.h = 0
        local over = f:IsMouseOver() and true or false
        if over ~= v.over then v.over = over; hoverButtons(over) end
    end)

    local KIND = { pick = { "gold", "!" }, ["do"] = { nil, nil }, turn = { "positive", "?" }, trainer = { "info", nil }, buy = { "info", "$" },
        -- étapes du guide de montée (Modules/LevelGuide.lua)
        flight = { "gold", nil }, hearth = { "info", nil }, dungeon = { "warning", nil }, item = { "gold", "!" }, zone = { nil, nil }, tour = { nil, nil } }
    local function kindColor(k)
        local e = KIND[k]
        if e and e[1] then return C[e[1]] end
        return { UI:Accent() }
    end
    local CLASSIC = { "title", "sub", "close", "prog", "next", "turn", "goal" }
    local function bgAlpha(a, border)
        if f.bg then f.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], a) end
        if f.border then f.border:SetShown(border) end
    end
    -- d = { kind, title, lvl, sub, paused, objs, idx, count, mins, xp, zone, nexts = { { n, kind, title, dist } } }
    function f:PaintTour(d)
        for _, k in ipairs(CLASSIC) do self[k]:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        local v = self.tv
        v:Show()
        self.tour, self.guide = true, nil
        self.tvGuide = d.guide or nil
        local W2 = 300
        self:SetWidth(W2)
        bgAlpha((Q():Config().tourBg or 50) / 100, false)
        if d.head then v.head:SetText(d.head)
        else
            v.head:SetText(UI:Upper(T("Tournée")) .. (d.zone and (" · " .. UI:Upper(d.zone)) or "")
                .. (d.paused and ("  " .. UI:Hex(C.warning) .. T("EN PAUSE") .. "|r") or ""))
        end
        -- 2e ligne : où tu en es ; à droite, l'XP qui reste en gros (guide : texte de droite donné)
        v.headR:SetText(""); v.headR:Hide()
        if d.headR then
            v.head2:SetText(d.headR)
            v.xpBig:SetText(""); v.xpSmall:SetText("")
        else
            v.head2:SetText(string.format(T("étape %d sur %d"), d.idx, d.count) .. "  " .. UI:Hex(C.muted) .. "· "
                .. string.format(T("env. %d min"), d.mins) .. "|r")
            v.xpBig:SetText((d.xp or 0) > 0 and ("+" .. thousands(d.xp)) or "")
            v.xpSmall:SetText((d.xp or 0) > 0 and T("XP au total") or "")
        end
        local rw = math.max(v.xpBig:GetStringWidth() or 0, v.xpSmall:GetStringWidth() or 0)
        v.head:SetWidth(math.max(40, W2 - 24 - rw - 10))
        v.head2:SetWidth(math.max(40, W2 - 24 - rw - 10))
        -- boutons au survol : guide = arrêter de suivre, passer l'étape, lancer l'étape
        v.close.tooltip = d.guide and "Ne plus suivre le guide de montée" or "Arrêter la tournée"
        v.skip.tooltip = "Passer l'étape"
        local r, g, b = UI:Accent()
        v.bar:SetColorTexture(r, g, b, 1)
        local frac = d.prog or (math.max(0, (d.idx or 1) - 1) / math.max(1, d.count or 1))
        v.bar:SetWidth(math.max(1, (W2 - 24) * math.max(0, math.min(1, frac))))
        local col = kindColor(d.kind)
        v.dot:SetVertexColor(col[1], col[2], col[3], d.paused and 0.45 or 1)
        local letter = KIND[d.kind] and KIND[d.kind][2]
        v.mark:SetText(letter or ""); v.mark:SetShown(letter ~= nil)
        v.markIcon:SetShown(letter == nil)
        v.title:SetText((d.title or "") .. (d.lvl and ("  " .. UI:Hex(C.dim) .. "[" .. d.lvl .. "]|r") or ""))
        v.titleHit.qids = (d.qids and #d.qids > 0) and d.qids or nil
        v.titleHit.step = not d.guide
        v.title:SetTextColor(unpack(d.paused and C.muted or C.text))
        -- titre sur deux lignes au besoin (il était coupé), puis la ligne d'infos dessous
        if v.title.SetWordWrap then v.title:SetWordWrap(true) end
        if v.title.SetMaxLines then v.title:SetMaxLines(2) end
        v.title:SetWidth(W2 - 34 - 10)
        local th = math.max(16, math.min(36, v.title:GetStringHeight() or 16))
        v.sub:ClearAllPoints(); v.sub:SetPoint("TOPLEFT", 34, -54 - th - 2); v.sub:SetPoint("RIGHT", -10, 0)
        v.sub:SetText(d.sub or "")
        v.pp.icon:SetTexture(UI.MEDIA .. ((d.paused or d.guide) and "play" or "pause"))
        v.pp.tooltip = d.guide and "Lancer l'étape" or (d.paused and "Reprendre" or "Pause")
        local y = -54 - th - 2 - ((d.sub and d.sub ~= "") and 18 or 0)
        -- légende : une couleur par quête quand l'étape en regroupe plusieurs
        local lx = 12
        for i, l in ipairs(v.legend) do
            local e = d.legend and d.legend[i]
            if e and #d.legend > 1 and lx < W2 - 40 then
                local c = UI.QuestObjColor and UI.QuestObjColor(i) or { UI:Accent() }
                l.dot:SetVertexColor(c[1], c[2], c[3], 1)
                l.txt:SetText(e)
                local tw = math.min(l.txt:GetStringWidth() or 40, W2 - 24 - lx - 14)
                l.txt:SetWidth(tw)
                l:SetWidth(tw + 14)
                l:ClearAllPoints(); l:SetPoint("TOPLEFT", lx, y - 2)
                l:Show()
                lx = lx + tw + 26
            else
                l:Hide()
            end
        end
        if d.legend and #d.legend > 1 then y = y - 18 end
        -- objectifs : barre qui se remplit, nom à gauche, compte à droite ; fini = vert
        local barW = W2 - 24
        for i, row in ipairs(v.objs) do
            local o = d.objs[i]
            if o then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12, y); row:SetPoint("RIGHT", -12, 0)
                local need = o.need or 0
                -- texte du jeu « Murloc : 0/12 personnages tués » : le nom seul, le compte à part
                local name = tostring(o.name or ""):gsub("%s*:%s*%d+%s*/%s*%d+.*$", "")
                local c = (o.qi and UI.QuestObjColor and UI.QuestObjColor(o.qi)) or { UI:Accent() }
                if o.done then c = C.positive end
                local part = o.done and 1 or (need > 0 and math.min(1, (o.have or 0) / need) or 0)
                row.bg:SetColor(1, 1, 1, 0.06)
                row.fillF:SetWidth(math.max(1, barW * part)); row.fillF:SetShown(part > 0)
                row.fill:SetColor(c[1], c[2], c[3], o.done and 0.32 or 0.36)
                row.edge:SetColorTexture(c[1], c[2], c[3], 1); row.edge:SetShown(part > 0 and part < 1)
                row.dot:SetVertexColor(c[1], c[2], c[3], 1)
                row.name:SetText(name)
                row.name:SetTextColor(unpack(o.done and C.positive or C.text))
                row.count:SetText(need > 0 and string.format("%d/%d", o.have or 0, need) or (o.done and T("fait") or ""))
                row.count:SetTextColor(unpack(o.done and C.positive or C.text))
                row:Show()
                y = y - 23
            else
                row:Hide()
            end
        end
        if #d.objs > 0 then y = y - 4 end
        -- boutons Cibler / Objet (d.act) : visuels ici, boutons protégés posés dessus hors combat
        local a = d.act
        if a and (a.target or a.item) then
            v.act:ClearAllPoints(); v.act:SetPoint("TOPLEFT", 12, y - 2); v.act:SetPoint("RIGHT", -10, 0)
            local ar, ag, ab = UI:Accent()
            local function paintSlot(sl, on, icon, label, sub, count, isItem)
                sl:SetShown(on); sl.lbl:SetShown(on); sl.sub:SetShown(on)
                if not on then return end
                local ec = isItem and C.gold or { ar, ag, ab }
                sl.edge:SetColor(ec[1], ec[2], ec[3], 1)
                sl.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
                sl.bg:ClearAllPoints()
                sl.icon:SetTexture(icon)
                if isItem then sl.icon:SetVertexColor(1, 1, 1, 1) else sl.icon:SetVertexColor(ar, ag, ab, 1) end
                sl.lbl:SetText(label); sl.sub:SetText(sub or "")
                sl.count:SetText(count or "")
            end
            paintSlot(v.actT, a.target ~= nil, UI.MEDIA .. "crosshair", T("Cibler"),
                a.target and a.target.name, nil, false)
            paintSlot(v.actI, a.item ~= nil, a.item and a.item.icon, T("Objet"),
                a.item and a.item.name, a.item and a.item.count, true)
            v.actI:ClearAllPoints()
            if a.target then v.actI:SetPoint("LEFT", v.act, "CENTER", 4, 0) else v.actI:SetPoint("LEFT", 0, 0) end
            local wT = math.floor((W2 - 24) / 2) - 40
            v.actT.sub:SetWidth(wT); v.actI.sub:SetWidth(wT)
            v.act:Show()
            y = y - 36
        else
            v.act:Hide()
        end
        self.actData = a
        if UI.PlaceQuestActions then UI:PlaceQuestActions() end
        -- 2 étapes suivantes
        for i, row in ipairs(v.nexts) do
            local nx = d.nexts[i]
            if nx then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12, y - 2); row:SetPoint("RIGHT", -10, 0)
                local c = kindColor(nx.kind)
                row.dot:SetVertexColor(c[1], c[2], c[3], 1)
                row.num:SetText(tostring(nx.n))
                row.hit.qids = (nx.qids and #nx.qids > 0) and nx.qids or nil
                row.hit.step = false
                row.txt:SetText(nx.title .. (nx.dist and ("  " .. UI:Hex(C.dim) .. "· " .. string.format(T("%d m"), math.floor(nx.dist + 0.5)) .. "|r") or ""))
                row:Show()
                y = y - 18
            else
                row:Hide()
            end
        end
        -- sur ton chemin
        local wy, nr = d.way, d.near
        if nr then
            -- tout près : étape plus loin dans la tournée, faisable ici
            y = y - 4
            v.way:ClearAllPoints(); v.way:SetPoint("TOPLEFT", 12, y - 2); v.way:SetPoint("RIGHT", -10, 0)
            local kc = kindColor(nr.kind)
            v.way.dot:SetVertexColor(kc[1], kc[2], kc[3], 1)
            v.way.num:SetText(tostring(nr.j))
            v.way.qid, v.way.nearStep = nil, nr.step
            v.way.txt:SetText(UI:Hex({ UI:Accent() }) .. T("Tout près :") .. "|r " .. (nr.title or ""))
            v.way.sub:SetText(string.format(T("%d m · clic : la faire maintenant"), math.floor((nr.d or 0) + 0.5)))
            v.way:Show()
            y = y - 30
        elseif wy then
            y = y - 4
            v.way:ClearAllPoints(); v.way:SetPoint("TOPLEFT", 12, y - 2); v.way:SetPoint("RIGHT", -10, 0)
            local gc = C.gold
            v.way.dot:SetVertexColor(gc[1], gc[2], gc[3], 1)
            v.way.num:SetText("+")
            v.way.qid, v.way.nearStep = wy.qid, nil
            v.way.txt:SetText(UI:Hex(C.gold) .. T("Sur ton chemin :") .. "|r " .. (wy.title or "") .. (wy.lvl and ("  " .. UI:Hex(C.dim) .. "[" .. wy.lvl .. "]|r") or ""))
            v.way.sub:SetText(wy.sub or "")
            v.way:Show()
            y = y - 30
        else
            v.way:Hide(); v.way.qid, v.way.nearStep = nil, nil
        end
        self:SetHeight(-y + 8)
    end

    function f:Paint(data)
        self.actData = nil
        if UI.PlaceQuestActions then UI:PlaceQuestActions() end
        if self.tv then
            self.tv:Hide()
            bgAlpha(0.92, true)
            for _, k in ipairs(CLASSIC) do if k ~= "prog" then self[k]:Show() end end
            self:SetWidth(W)
            for _, r in ipairs(self.rows) do r.name:SetWidth(104); r.count:SetTextColor(unpack(C.muted)) end
        end
        self.title:SetText(data.title or "")
        self.sub:SetText(data.sub or "")
        local y = -44
        self.tour = data.tour
        self.guide = data.guide
        self.prog:SetShown(data.prog ~= nil)
        if data.prog then self.prog:SetValue(data.prog); y = -52 end
        self.next:SetLabel(data.b1 or T("Zone suivante")); self.next:SetWidth(self.next.label:GetStringWidth() + 26)
        self.turn:SetLabel(data.b2 or T("Rendu")); self.turn:SetWidth(self.turn.label:GetStringWidth() + 26)
        self.close.tooltip = (data.guide and "Ne plus suivre le guide de montée") or (data.tour and "Arrêter la tournée") or "Ne plus suivre cette quête"
        for i, r in ipairs(self.rows) do
            local o = data.objs[i]
            if o then
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("RIGHT", -14, 0)
                y = y - 20
                if o.done then
                    r.box:SetTexture(UI.MEDIA .. "circle"); r.box:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
                else
                    r.box:SetTexture(UI.MEDIA .. "ring"); r.box:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
                end
                r.name:SetText(o.name)
                r.name:SetTextColor(unpack(o.done and C.muted or C.text))
                local need = o.need or 0
                r.count:SetText(need > 0 and string.format("%d/%d", o.have or 0, need) or (o.done and T("fait") or ""))
                r.bar.color = o.done and C.positive or nil
                r.bar:SetShown(need > 0)
                r.bar:SetValue(need > 0 and (o.have or 0) / need or 0)
                r:Show()
            else
                r:Hide()
            end
        end
        self.goal:ClearAllPoints(); self.goal:SetPoint("TOPLEFT", 14, y - 2); self.goal:SetPoint("RIGHT", -14, 0)
        self.goal:SetText(data.goal or "")
        y = y - ((data.goal and data.goal ~= "") and ((self.goal:GetStringHeight() or 12) + 4) or 2)
        self.next:ClearAllPoints(); self.next:SetPoint("TOPLEFT", 14, y - 4)
        self.turn:ClearAllPoints(); self.turn:SetPoint("LEFT", self.next, "RIGHT", 6, 0)
        self.next:SetEnabled(data.canNext ~= false)
        self:SetHeight(-y + 4 + 22 + 12)
    end

    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 or s.sample then return end
        s.acc = 0
        UI:RefreshQuestTracker()
    end)
    f:Hide()
    UI:RegisterHUD("questTrack", f, {
        label = T("Quête suivie"), default = { 430, 120 },
        enabled = function() return shown() end,
        sample = function(on)
            f.sample = on or nil
            if on and WK.modules.QuestPlan and WK.modules.QuestPlan:Tour() then
                -- tournée en cours : aperçu de la carte de tournée
                f:PaintTour({ kind = "turn", title = T("Rendre : Le viaduc de Thandol"), lvl = 31, sub = "160 m nord-est · +2500 XP",
                    objs = {}, idx = 4, count = 7, mins = 18, xp = 7400, zone = T("Les Paluns"),
                    nexts = { { n = 5, kind = "do", title = T("Les trogg du loch"), dist = 420 }, { n = 6, kind = "pick", title = T("Prendre : Thelsamar"), dist = 900 } },
                    way = { title = T("Œufs de faucon"), lvl = 30, sub = string.format(T("détour env. %d min"), 3) .. " · " .. UI:Hex(C.gold) .. "+1150 XP|r · " .. T("clic : ajouter") } })
                f:Show()
            elseif on then
                f:Paint({ title = T("La chasse aux loups"), sub = T("Sombrivage · niveau 14"), goal = T("Zone à 140 m"),
                    objs = { { name = T("Loup de Sombrivage"), have = 6, need = 10 }, { name = T("Croc de loup"), have = 4, need = 4, done = true } } })
                f:Show()
            else
                UI:RefreshQuestTracker()
            end
        end,
    })
    return f
end

function UI:RefreshQuestTracker()
    if not card then
        if not shown() then return end
        card = build()
    end
    if card.sample then return end
    local q = Q()
    -- tournée de quêtes en cours (Modules/QuestPlan.lua) : la carte suit la tournée
    local P = WK.modules.QuestPlan
    local tour = shown() and P and P:Tour()
    if tour and tour.steps[tour.idx] then
        local s = tour.steps[tour.idx]
        local objs = P:StepObjectives(s)
        local mins = math.max(1, math.floor(P:Remaining() / 60 + 0.5))
        -- distance jusqu'à l'étape
        local G = WK.modules.Guide
        local me, dist = G and G:PlayerPos(), nil
        if me and s.map then
            local t = { map = s.map, x = s.x, y = s.y }
            t.cont, t.wx, t.wy = G.ToWorld(s.map, s.x, s.y)
            dist = G:Vector(me, t)
        end
        local zone = s.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(s.map)
        local Qs = WK.modules.Quests
        -- niveau, XP et PNJ de l'étape (première quête ; XP de toutes)
        local lvl, xp, npc
        for i, qid in ipairs(s.qids or {}) do
            local qq = Qs and Qs:Get(qid)
            if qq then
                xp = (xp or 0) + (qq.xp or 0)
                if i == 1 then
                    lvl = qq.lvl
                    local n = s.kind == "pick" and qq.sid and WK.EverNpcs and WK.EverNpcs[qq.sid]
                    if n then npc = (WK.Lang and WK.Lang() == "frFR" and n[2]) or n[1] end
                end
            end
        end
        local sub = {}
        if s.kind == "buy" and s.vendor then npc = s.vendor end
        if npc then table.insert(sub, npc) end
        if #(s.qids or {}) > 1 and s.kind ~= "do" then table.insert(sub, string.format(T("%d quêtes"), #s.qids)) end
        if dist and not tour.paused then
            local dir = P.Direction and me and me.map == s.map and P:Direction(me, { map = s.map, x = s.x, y = s.y })
            table.insert(sub, UI:Hex({ UI:Accent() }) .. string.format(T("%d m"), math.floor(dist + 0.5))
                .. ((dir and dir ~= "") and (" " .. dir) or "") .. "|r")
        end
        if (xp or 0) > 0 and s.kind ~= "pick" and s.kind ~= "buy" then table.insert(sub, UI:Hex(C.gold) .. "+" .. xp .. " XP|r") end
        -- B : objet à acheter sans marchand connu sur ton continent, signalé sur le rendu
        if s.kind == "turn" and s.buyMissing and #s.buyMissing > 0 then
            local parts = {}
            for _, it in ipairs(s.buyMissing) do
                if (WK.modules.QuestTrack:ItemCount(it.id) or 0) < (it.n or 1) then
                    parts[#parts + 1] = (WK.GetItemInfo(it.id) or ("#" .. it.id)) .. " ×" .. (it.n or 1)
                end
            end
            if #parts > 0 then table.insert(sub, UI:Hex(C.info) .. T("à acheter :") .. " " .. table.concat(parts, ", ") .. "|r") end
        end
        -- XP qui reste à gagner dans la tournée (rendus à venir)
        local left = 0
        for i = tour.idx, #tour.steps do
            local st = tour.steps[i]
            if st.kind == "turn" then
                for _, qid in ipairs(st.qids or {}) do local qq = Qs and Qs:Get(qid); left = left + (qq and qq.xp or 0) end
            end
        end
        local nexts = {}
        for i = 1, 2 do
            local ns = tour.steps[tour.idx + i]
            if ns then
                local nd
                if me and ns.map then
                    local t = { map = ns.map, x = ns.x, y = ns.y }
                    t.cont, t.wx, t.wy = G.ToWorld(ns.map, ns.x, ns.y)
                    nd = G:Vector(me, t)
                end
                table.insert(nexts, { n = tour.idx + i, kind = ns.kind, title = P:StepTitle(ns, true), dist = nd, qids = ns.qids })
            end
        end
        -- boutons Cibler / Objet de l'étape « faire »
        local act = UI.QuestActionData and UI:QuestActionData(s, objs) or nil
        -- étape plus loin toute proche (mode auto : remontée tout de suite), puis quête sur le chemin
        if P.CheckNear then P:CheckNear() end
        local near
        local nh = P.NearStep and P:NearStep()
        if nh then near = { step = nh.step, j = nh.j, kind = nh.step.kind, d = nh.d, title = P:StepTitle(nh.step, true) } end
        local way
        local ow = P.OnTheWay and P:OnTheWay()
        if ow and ow.e then
            way = { qid = ow.e.id, title = ow.e.title, lvl = ow.e.lvl,
                sub = string.format(T("détour env. %d min"), ow.mins or 1) .. ((ow.e.xp or 0) > 0 and (" · " .. UI:Hex(C.gold) .. "+" .. ow.e.xp .. " XP|r") or "")
                    .. " · " .. T("clic : ajouter") }
        end
        local legend
        if s.kind == "do" and s.qids and #s.qids > 1 then
            legend = {}
            for _, qid in ipairs(s.qids) do
                local qq = Qs and Qs:Get(qid)
                table.insert(legend, (q.InLog and q:InLog(qid) and q:Title(qid)) or (qq and Qs:Name(qq)) or ("#" .. qid))
            end
        end
        card:PaintTour({ kind = s.kind, qids = s.qids, title = P:StepTitle(s, not tour.paused), lvl = lvl, sub = table.concat(sub, " · "), paused = tour.paused,
            objs = objs, legend = legend, idx = tour.idx, count = #tour.steps, mins = mins, xp = left,
            zone = zone and zone.name, nexts = nexts, way = way, near = near, act = act })
        card:Show()
        return
    end
    -- guide de montée suivi (Modules/LevelGuide.lua), sans tournée en cours
    local LG = WK.modules.LevelGuide
    if shown() and LG and LG:Following() then
        local steps = LG:Steps()
        local s1 = steps[1]
        local lvl = UnitLevel and UnitLevel("player") or 1
        local cur, max = (UnitXP and UnitXP("player")) or 0, (UnitXPMax and UnitXPMax("player")) or 1
        local qid0 = q:Tracked()
        local objs = {}
        if qid0 then
            for _, o in ipairs(q:Objectives(qid0)) do
                table.insert(objs, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done })
            end
        end
        -- même carte que la tournée : en-tête (niveau, avancée), étape en cours, objectifs, 2 étapes suivantes
        local nexts = {}
        for i = 2, 3 do
            local st = steps[i]
            if st then table.insert(nexts, { n = i, kind = st.kind, title = st.title }) end
        end
        local pct = max > 0 and math.floor(cur / max * 100) or 0
        card:PaintTour({ guide = true, kind = s1 and s1.kind or "zone",
            -- en-tête court (il chevauchait les chiffres de droite) ; pas les objectifs de la quête suivie, sans
            -- rapport avec l'étape (point de vol, maître…)
            head = UI:Upper(string.format(T("Niveau %d"), lvl)),
            headR = string.format("%d %%", pct) .. (max > cur and (" · " .. UI:Hex(C.gold) .. string.format(T("reste %s XP"), BreakUpLargeNumbers and BreakUpLargeNumbers(max - cur) or tostring(max - cur)) .. "|r") or ""),
            prog = max > 0 and cur / max or 0,
            title = s1 and s1.title or T("Rien à faire pour l'instant"), sub = s1 and s1.sub or "",
            objs = {}, nexts = nexts })
        card:Show()
        return
    end
    local qid = shown() and q:Tracked()
    if not qid then card:Hide() return end
    local objs = {}
    for _, o in ipairs(q:Objectives(qid)) do
        table.insert(objs, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done })
    end
    local lvl = q:Level(qid)
    local goal = q:Goal(qid)
    local gtext
    local complete = q:IsComplete(qid)
    if goal then
        local me, G = WK.modules.Guide:PlayerPos(), WK.modules.Guide
        local d
        if me then
            local t = { map = goal.map, x = goal.x, y = goal.y }
            t.cont, t.wx, t.wy = G.ToWorld(goal.map, goal.x, goal.y)
            d = G:Vector(me, t)
        end
        if goal.turnIn then
            gtext = d and string.format(T("Rendu à %d m"), math.floor(d + 0.5)) or T("Rendu dans une autre zone")
        else
            gtext = d and string.format(T("%s · zone à %d m"), goal.name, math.floor(d + 0.5))
                or string.format(T("%s · zone sur une autre carte"), goal.name)
        end
    elseif not complete then
        gtext = T("Pas de zone connue pour ces objectifs.")
    end
    local zone = goal and goal.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(goal.map)
    local sub = {}
    if zone and zone.name then table.insert(sub, zone.name) end
    if lvl then table.insert(sub, string.format(T("niveau %d"), lvl)) end
    if complete then table.insert(sub, UI:Hex(C.positive) .. T("prête à rendre") .. "|r") end
    card:Paint({ title = q:Title(qid), sub = table.concat(sub, " · "), objs = objs, goal = gtext,
        canNext = goal and not goal.turnIn and (goal.count or 0) > 1 })
    card:Show()
end

WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3.5, function() UI:RefreshQuestTracker() end) end)

---------------------------------------------------------------------------
-- Pastilles de la tournée dans le suivi des quêtes du jeu : l'icône ronde du jeu (bouton POI à gauche de
-- chaque quête) est rendue invisible et notre pastille est posée à sa place, à chaque mise à jour du suivi.
-- QuestTrack:Config().trackPins : "step" (n° et couleur de la prochaine étape de la tournée : accent faire,
-- vert rendre ; gris hors tournée, « ? » vert si prête), "progress" (anneau de la couleur d'avancement :
-- rouge pas commencée, orange en cours, vert prête, n° d'étape dedans), "off" (icônes du jeu).
-- Les icônes sont reconnues par leur forme (bouton d'au plus 40 px qui porte un n° de quête : questID,
-- GetQuestID, ou poiButton d'un bloc) dans les cadres de suivi connus ; /wk suivi dit ce qui a été trouvé.
---------------------------------------------------------------------------
local ROOTS = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame", "QuestObjectiveTracker",
    "ObjectiveTrackerBlocksFrame" }
local overlays = setmetatable({}, { __mode = "k" })
local hiddenBtn = setmetatable({}, { __mode = "k" })
local found = { roots = {}, buttons = 0 }
local function pinMode() return Q():Config().trackPins or "step" end

local function questOf(btn)
    local id = rawget(btn, "questID") or rawget(btn, "questId")
    if not id and btn.GetQuestID then local ok, v = pcall(btn.GetQuestID, btn); if ok then id = v end end
    if type(id) == "number" and id > 0 then return id end
    return nil
end
-- boutons POI des cadres de suivi (parcours limité en profondeur)
local function collect(f, out, depth)
    if depth > 7 or not f or not f.GetChildren then return end
    local pb = rawget(f, "poiButton")
    if type(pb) == "table" and pb.IsShown then
        local fid = rawget(f, "id")
        local id = questOf(pb) or (type(fid) == "number" and fid) or nil
        if id then out[pb] = id end
    end
    for _, ch in ipairs({ f:GetChildren() }) do
        if not ch.wkPin then
            local id = questOf(ch)
            local w = ch.GetWidth and ch:GetWidth() or 0
            if id and w > 0 and w <= 40 then out[ch] = out[ch] or id end
            collect(ch, out, depth + 1)
        end
    end
end

-- étape de la tournée qui concerne la quête : n°, genre (do / turn / pick)
local function stepOf(qid)
    local P = WK.modules.QuestPlan
    local t = P and P:Tour()
    if not t then return nil end
    for i = t.idx or 1, #t.steps do
        local s = t.steps[i]
        for _, q in ipairs(s.qids or {}) do
            if q == qid and (s.kind == "do" or s.kind == "turn" or s.kind == "pick") then return i, s.kind end
        end
    end
    return nil
end

local function overlayFor(btn)
    local o = overlays[btn]
    if o then return o end
    local parent = btn:GetParent() or UIParent
    o = CreateFrame("Button", nil, parent)
    o.wkPin = true
    o:SetSize(20, 20)
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o.edge = o:CreateTexture(nil, "ARTWORK", nil, 0); o.edge:SetTexture(UI.MEDIA .. "circle"); o.edge:SetAllPoints()
    o.fill = o:CreateTexture(nil, "ARTWORK", nil, 1); o.fill:SetTexture(UI.MEDIA .. "circle")
    o.fill:SetPoint("TOPLEFT", 2, -2); o.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    o.ring = o:CreateTexture(nil, "ARTWORK", nil, 2); o.ring:SetTexture(UI.MEDIA .. "ring")
    o.ring:SetPoint("TOPLEFT", 1, -1); o.ring:SetPoint("BOTTOMRIGHT", -1, 1)
    o.num = o:CreateFontString(nil, "OVERLAY")
    if not (UI.FONT and o.num:SetFont(UI.FONT, 10, "")) then o.num:SetFont("Fonts\\FRIZQT__.TTF", 10, "") end
    o.num:SetPoint("CENTER", 0, 0)
    o:SetScript("OnClick", function(s, b)
        if not s.qid then return end
        if UI:QuestClick(b, { s.qid }) then return end
        Q():Track(s.qid)
    end)
    o:SetScript("OnEnter", function(s)
        if not s.qid then return end
        UI:TooltipOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(Q():Title(s.qid), 1, 1, 1)
        local i, kind = stepOf(s.qid)
        if i then
            local what = kind == "turn" and T("rendre") or (kind == "pick" and T("prendre") or T("faire"))
            local tc = C.text
            GameTooltip:AddLine(string.format(T("Étape %d de la tournée · %s"), i, what), tc[1], tc[2], tc[3])
        else
            GameTooltip:AddLine(T("Pas dans la tournée"), C.muted[1], C.muted[2], C.muted[3])
        end
        local qq = WK.modules.Quests and WK.modules.Quests:Get(s.qid)
        local gc = C.gold
        if qq and (qq.xp or 0) > 0 then GameTooltip:AddLine(string.format("+%d XP", qq.xp), gc[1], gc[2], gc[3]) end
        GameTooltip:AddLine(T("Clic : suivre et guider · ") .. UI:QuestClickHint(), C.dim[1], C.dim[2], C.dim[3], true)
        GameTooltip:Show()
    end)
    o:SetScript("OnLeave", function() GameTooltip:Hide() end)
    overlays[btn] = o
    return o
end

local function paintOverlay(o, qid, mode)
    o.qid = qid
    local i, kind = stepOf(qid)
    local complete = Q():IsComplete(qid)
    local bg = C.bg
    o.edge:SetVertexColor(bg[1], bg[2], bg[3], 1)
    local label = i and tostring(i) or (complete and "?" or "-")
    if mode == "progress" then
        local P = WK.modules.QuestPlan
        local st = P and P:QuestProgress(qid) or "started"
        local col = (st == "ready" and C.positive) or (st == "partial" and C.warning) or C.negative
        if not i and not complete then col = C.dim end
        o.fill:SetVertexColor(bg[1], bg[2], bg[3], 0.9)
        o.ring:SetVertexColor(col[1], col[2], col[3], 1); o.ring:Show()
        o.num:SetTextColor(col[1], col[2], col[3], 1)
    else
        local col
        if i then col = (kind == "turn" and C.positive) or (kind == "pick" and C.gold) or { UI:Accent() }
        elseif complete then col = C.positive
        else col = C.dim end
        o.fill:SetVertexColor(col[1], col[2], col[3], 1)
        o.ring:Hide()
        o.num:SetTextColor(bg[1], bg[2], bg[3], 1)
    end
    o.num:SetText(label)
end

local function restoreAll()
    for btn, a in pairs(hiddenBtn) do btn:SetAlpha(a or 1); hiddenBtn[btn] = nil end
    for _, o in pairs(overlays) do o:Hide() end
end

-- Découverte : le suivi de WoW Forever n'a pas forcément les noms de cadre du jeu d'origine. Quand les cadres
-- connus ne donnent rien, tous les cadres sont parcourus (EnumerateFrames, au plus toutes les 5 s) : un petit
-- bouton qui porte un n° de quête, visible, donne son cadre de plus haut niveau (sous UIParent), ajouté aux racines.
local extraRoots = {}
local lastDiscover, failedScans = 0, 0
local scanStats = { any = 0, small = 0, sample = {} }
local function topOf(f)
    local guard = 0
    while f and f.GetParent and f:GetParent() and f:GetParent() ~= UIParent and guard < 12 do
        f = f:GetParent(); guard = guard + 1
    end
    return f
end
local function discover()
    local now = _G.GetTime and _G.GetTime() or 0
    -- toutes les 5 s au début, puis toutes les minutes si rien n'est trouvé (journal vide, autre suivi)
    if now - lastDiscover < ((failedScans or 0) >= 6 and 60 or 5) or not _G.EnumerateFrames then return end
    lastDiscover = now
    scanStats.any, scanStats.small = 0, 0
    _G.wipe(scanStats.sample)
    local cur = _G.EnumerateFrames()
    local guard = 0
    local function check(fr)
        if fr.IsForbidden and fr:IsForbidden() then return end
        if not fr.wkPin and not fr.wk then
            local f = fr
            local id = questOf(f)
            if id then
                scanStats.any = scanStats.any + 1
                local w = f.GetWidth and f:GetWidth() or 0
                if w > 0 and w <= 40 and f:IsVisible() then
                    scanStats.small = scanStats.small + 1
                    local top = topOf(f)
                    if top and not extraRoots[top] then extraRoots[top] = true end
                end
                if #scanStats.sample < 4 then
                    local p = f.GetParent and f:GetParent()
                    table.insert(scanStats.sample, string.format("%s (%d px, %s)", (f.GetName and f:GetName()) or "?",
                        math.floor(w), p and p.GetName and p:GetName() or "?"))
                end
            end
        end
    end
    while cur and guard < 20000 do
        guard = guard + 1
        pcall(check, cur) -- cadre interdit ou méthode qui proteste : ignoré
        cur = _G.EnumerateFrames(cur)
    end
    failedScans = scanStats.small > 0 and 0 or (failedScans or 0) + 1
end

function UI.RefreshTrackerPins()
    local mode = pinMode()
    if mode == "off" or not WK:FeatureOn("quests") then restoreAll() return end
    local btns = {}
    _G.wipe(found.roots)
    for _, name in ipairs(ROOTS) do
        local f = _G[name]
        if f and f.GetChildren then table.insert(found.roots, name); collect(f, btns, 0) end
    end
    if not next(btns) then discover() end
    for root in pairs(extraRoots) do
        table.insert(found.roots, (root.GetName and root:GetName()) or "?")
        collect(root, btns, 0)
    end
    local n = 0
    local seen = {}
    for btn, qid in pairs(btns) do
        if btn:IsShown() then
            n = n + 1
            local o = overlayFor(btn)
            if o:GetParent() ~= btn:GetParent() then o:SetParent(btn:GetParent()) end
            local size = math.max(16, math.min(24, btn:GetWidth() or 20))
            o:SetSize(size, size)
            o:ClearAllPoints(); o:SetPoint("CENTER", btn, "CENTER", 0, 0)
            o:SetFrameLevel((btn:GetFrameLevel() or 1) + 3)
            paintOverlay(o, qid, mode)
            o:Show()
            if hiddenBtn[btn] == nil then hiddenBtn[btn] = btn:GetAlpha() end
            btn:SetAlpha(0)
            seen[o] = true
        end
    end
    for btn, o in pairs(overlays) do
        if not seen[o] then
            o:Hide()
            if hiddenBtn[btn] ~= nil and not btn:IsShown() then
                btn:SetAlpha(hiddenBtn[btn] or 1); hiddenBtn[btn] = nil
            end
        end
    end
    found.buttons = n
end
function UI.TrackerPinsDiag()
    UI:RefreshTrackerPins()
    lastDiscover = 0
    if found.buttons == 0 then discover() end
    return string.format(T("cadres de suivi : %s · icônes remplacées : %d · mode : %s"),
        #found.roots > 0 and table.concat(found.roots, ", ") or T("aucun"), found.buttons, pinMode())
        .. "\n  " .. string.format(T("cadres avec un n° de quête : %d (petits et visibles : %d) · %s"),
        scanStats.any, scanStats.small, #scanStats.sample > 0 and table.concat(scanStats.sample, " ; ") or "-")
end

-- mises à jour : après celles du suivi du jeu (fonctions connues) et toutes les 0,5 s quand il est visible
do
    local pending
    local function soon()
        if pending then return end
        pending = true
        C_Timer.After(0, function() pending = nil; pcall(UI.RefreshTrackerPins, UI) end)
    end
    UI.TrackerPinsSoon = soon
    local hookedFns = {}
    local function hookAll()
        for _, fn in ipairs({ "ObjectiveTracker_Update", "QuestWatch_Update", "WatchFrame_Update",
                              "QuestObjectiveTracker_Update" }) do
            if not hookedFns[fn] and type(_G[fn]) == "function" then
                hookedFns[fn] = true; hooksecurefunc(fn, soon)
            end
        end
    end
    local ticker = CreateFrame("Frame")
    ticker.acc = 0
    ticker:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.5 then return end
        s.acc = 0
        if pinMode() == "off" then return end
        for _, name in ipairs(ROOTS) do
            local f = _G[name]
            if f and f.IsVisible and f:IsVisible() then pcall(UI.RefreshTrackerPins, UI) return end
        end
    end)
    WK:On("PLAYER_LOGIN", function() hookAll(); C_Timer.After(2, soon) end)
    WK:On("ADDON_LOADED", function() hookAll() end)
    WK:On("QUEST_LOG_UPDATE", soon)
end

---------------------------------------------------------------------------
-- Boutons Cibler / Objet de l'étape en cours (carte de tournée) et repères sur les plaques de nom.
-- Cibler : bouton protégé « macro » (/targetexact <monstre>) ; clic gauche = 1er objectif pas fini, clic droit =
-- objectif suivant. Objet : bouton protégé « item » (objet de quête utilisable du journal, s'il est dans
-- les sacs).
-- Les boutons sont enfants d'UIParent, posés sur les cases de la carte et préparés hors combat seulement (en
-- combat ils gardent le dernier monstre et le dernier objet ; mis à jour à PLAYER_REGEN_ENABLED).
-- Réglages QuestTrack:Config().actButtons (boutons) et plateMarks (repères des plaques de nom).
---------------------------------------------------------------------------
local actT, actI, actPending
local function actOn() local c = Q():Config(); return c.actButtons ~= false end
-- { target = { name, name2 }, item = { id, icon, count, name } } pour une étape « faire »
function UI.QuestActionData(_, s, objs)
    if not (s and s.kind == "do" and actOn()) then return nil end
    local q = Q()
    local names = {}
    for _, o in ipairs(objs or {}) do
        if not o.done then
            for _, id in ipairs(q:ObjectiveNpcs(o)) do
                local n = q:NpcName(id)
                if n then names[#names + 1] = n; break end
            end
        end
    end
    local out = {}
    if #names > 0 then out.target = { name = names[1], name2 = names[2] or names[1] } end
    local special = _G.GetQuestLogSpecialItemInfo
    if special and _G.C_QuestLog and _G.C_QuestLog.GetLogIndexForQuestID then
        for _, qid in ipairs(s.qids or {}) do
            local idx = _G.C_QuestLog.GetLogIndexForQuestID(qid)
            if idx then
                local ok, link, icon, charges = pcall(special, idx)
                local id = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
                if id then
                    local count = (_G.GetItemCount and _G.GetItemCount(id)) or 0
                    local nm = link:match("%[(.-)%]")
                    local cnt = (count and count > 1) and tostring(count)
                        or ((charges or 0) > 1 and tostring(charges) or nil)
                    out.item = { id = id, icon = icon, name = nm, count = cnt }
                    break
                end
            end
        end
    end
    if not (out.target or out.item) then return nil end
    return out
end
local function makeAct(name, kind)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:SetSize(28, 28)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetAttribute("type", kind)
    b:SetFrameStrata("MEDIUM")
    b:Hide()
    b:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        if kind == "macro" then
            GameTooltip:SetText(T("Cibler le monstre de la quête"), 1, 1, 1)
            if s.n1 then GameTooltip:AddLine(T("Clic gauche :") .. " " .. s.n1, 0.9, 0.9, 0.9) end
            if s.n2 and s.n2 ~= s.n1 then GameTooltip:AddLine(T("Clic droit :") .. " " .. s.n2, 0.9, 0.9, 0.9) end
            if Q():Config().targetSkull ~= false then
                GameTooltip:AddLine(T("Pose la tête de mort sur le monstre."), 0.6, 0.6, 0.6)
            end
        elseif s.itemID and GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(s.itemID)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if kind == "macro" then
        -- tête de mort sur le monstre ciblé (SetRaidTarget n'est pas protégé ; en groupe il faut être chef
        -- ou assistant)
        b:SetScript("PostClick", function(_, _, down)
            if down == false or Q():Config().targetSkull == false then return end
            local set, get = _G.SetRaidTarget, _G.GetRaidTargetIndex
            if set and _G.UnitExists and _G.UnitExists("target") and not (_G.UnitIsDead and _G.UnitIsDead("target"))
                and not (_G.UnitIsFriend and _G.UnitIsFriend("player", "target"))
                and (not get or get("target") ~= 8) then
                pcall(set, "target", 8)
            end
        end)
    end
    return b
end
-- pose les boutons protégés sur les cases de la carte (hors combat)
function UI.PlaceQuestActions()
    if _G.InCombatLockdown and _G.InCombatLockdown() then actPending = true return end
    actPending = nil
    if not card then return end
    if not card.actHooked and card.HookScript then
        card.actHooked = true
        card:HookScript("OnHide", function() UI:PlaceQuestActions() end)
    end
    actT = actT or makeAct("WarbandKeeperQuestTarget", "macro")
    actI = actI or makeAct("WarbandKeeperQuestItem", "item")
    local v = card.tv
    local a = card.actData
    local show = card:IsShown() and v and v:IsShown() and v.act:IsShown() and a
    if show and a.target then
        actT.n1, actT.n2 = a.target.name, a.target.name2
        actT:SetAttribute("type", "macro")
        actT:SetAttribute("macrotext", "/targetexact " .. a.target.name)
        actT:SetAttribute("type2", "macro")
        actT:SetAttribute("macrotext2", "/targetexact " .. (a.target.name2 or a.target.name))
        actT:ClearAllPoints(); actT:SetAllPoints(v.actT)
        actT:SetFrameLevel((card:GetFrameLevel() or 1) + 20)
        actT:Show()
    else
        actT:Hide()
    end
    if show and a.item then
        actI.itemID = a.item.id
        actI:SetAttribute("type", "item")
        actI:SetAttribute("item", "item:" .. a.item.id)
        actI:ClearAllPoints(); actI:SetAllPoints(v.actI)
        actI:SetFrameLevel((card:GetFrameLevel() or 1) + 20)
        actI:Show()
    else
        actI:Hide()
    end
end
WK:On("PLAYER_REGEN_ENABLED", function() if actPending then UI:PlaceQuestActions() end end)


-- Repères sur les plaques de nom : monstres des objectifs pas finis de l'étape (ou de la quête suivie), à la
-- couleur de l'objectif ; plus gros sur la cible.
local marks = {}
local function plateNpc(unit)
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return kind == "Creature" and tonumber(id) or nil
end
local wanted, wantedAt = {}, 0
local function wantedNpcs()
    local now = _G.GetTime and _G.GetTime() or 0
    if now - wantedAt < 1 then return wanted end
    wantedAt = now
    _G.wipe(wanted)
    local q = Q()
    local P = WK.modules.QuestPlan
    local t = P and P:Active() and P:Tour()
    local s = t and t.steps[t.idx]
    local list = {}
    if s and s.kind == "do" then
        for _, o in ipairs(P:StepObjectives(s)) do list[#list + 1] = o end
    else
        local qid = q:Tracked()
        if qid and not q:IsComplete(qid) then for _, o in ipairs(q:Objectives(qid)) do list[#list + 1] = o end end
    end
    for i, o in ipairs(list) do
        if not o.done then
            local col = UI.QuestObjColor and UI.QuestObjColor(o.qi or i) or { UI:Accent() }
            for _, id in ipairs(q:ObjectiveNpcs(o)) do if not wanted[id] then wanted[id] = col end end
        end
    end
    return wanted
end
local function updateMarks()
    for _, m in ipairs(marks) do m:Hide() end
    local c = Q():Config()
    if c.plateMarks == false or not WK:FeatureOn("quests") then return end
    if not (_G.C_NamePlate and _G.C_NamePlate.GetNamePlates) then return end
    local w = wantedNpcs()
    if not next(w) then return end
    local n = 0
    local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
    if not ok then return end
    for _, p in ipairs(plates or {}) do
        local unit = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
        local id = unit and plateNpc(unit)
        local col = id and w[id]
        if col and not (_G.UnitIsDead and _G.UnitIsDead(unit)) then
            n = n + 1
            local m = marks[n]
            if not m then
                m = CreateFrame("Frame", nil, UIParent)
                m:SetSize(14, 14); m:SetFrameStrata("LOW")
                m.edge = m:CreateTexture(nil, "ARTWORK", nil, 0)
                m.edge:SetTexture(UI.MEDIA .. "circle"); m.edge:SetAllPoints()
                m.dot = m:CreateTexture(nil, "ARTWORK", nil, 1); m.dot:SetTexture(UI.MEDIA .. "circle")
                m.dot:SetPoint("TOPLEFT", 2, -2); m.dot:SetPoint("BOTTOMRIGHT", -2, 2)
                m.glyph = m:CreateTexture(nil, "OVERLAY"); m.glyph:SetTexture(UI.MEDIA .. "bang")
                m.glyph:SetSize(8, 8); m.glyph:SetPoint("CENTER")
                marks[n] = m
            end
            local target = _G.UnitIsUnit and _G.UnitIsUnit(unit, "target")
            local sz = target and 18 or 14
            m:SetSize(sz, sz)
            m.edge:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
            m.dot:SetVertexColor(col[1], col[2], col[3], 1)
            m.glyph:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
            m:ClearAllPoints()
            local okp = pcall(m.SetPoint, m, "BOTTOM", p, "TOP", 0, 2)
            if okp then m:Show() else m:Hide() end
        end
    end
end
UI.UpdateQuestPlateMarks = updateMarks
do
    local tick = CreateFrame("Frame")
    tick.acc = 0
    tick:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.25 then return end
        s.acc = 0
        updateMarks()
    end)
end
