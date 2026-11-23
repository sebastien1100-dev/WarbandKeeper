local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local CreateFrame, GameTooltip, IsShiftKeyDown = _G.CreateFrame, _G.GameTooltip, _G.IsShiftKeyDown
local T = function(s) return WK.T(s) end

-- Page « Donjons » (groupe Exploration) : colonne des donjons à gauche, groupés selon le niveau du perso
-- choisi (pour ton niveau, bientôt, plus haut, déjà dépassés, raids ; groupes repliables, recherche), puis les boss du donjon choisi et leur butin, filtré
-- « Pour <perso> » ou « Tout », avec la liste d'envies (étoile). Détail (maquette A) : en haut et fixes, la carte
-- du donjon (UI/DungeonMap.lua : boss à leur place, tués, prochain, étages) et la liste des boss à côté, puis les
-- onglets « Butin » (boss et monstres du donjon ; clic sur un boss = son butin seul) et « Quêtes » (filtre À faire
-- / Toutes) : seule leur liste défile ; boutons en bas.
-- Onglet « Mes envies » : tous les objets voulus, par perso. Boutons : panneau en jeu, Chercher un groupe
-- (LFG), Guider vers l'entrée.
local D = WK.modules.Dungeons
local GAP, ITEM_H = 10, 22
local LIST_W, ROW_H = 280, 26
-- groupes de la colonne, selon le niveau du perso choisi
-- « Déjà dépassés » en tête (replié, il ne prend qu'une ligne), puis du niveau actuel vers le plus haut
local GROUPS = {
    { "past", "Déjà dépassés" }, { "now", "Pour ton niveau" }, { "soon", "Bientôt" }, { "high", "Plus haut" },
    { "raid", "Raids" },
}
local function groupOf(d, lvl)
    if d.raid then return "raid" end
    if lvl > d.max then return "past" end
    if lvl >= d.min - 2 then return "now" end
    if d.min <= lvl + 8 then return "soon" end
    return "high"
end

local function levelColor(d, lvl)
    if lvl < d.min - 2 then return C.negative end
    if lvl < d.min then return C.warning end
    if lvl > d.max + 2 then return C.dim end
    return C.positive
end

-- Choix du menu des persos (rebâti à chaque rafraîchissement : persos renommés ou supprimés).
local function charOptions()
    local opts = {}
    for key, c in pairs(WK.DB.global.characters) do table.insert(opts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
    table.sort(opts, function(a, b) return a[2] < b[2] end)
    return opts
end

UI:RegisterPage({
    key = "dungeons", order = 8.95, nav = "Donjons",

    Build = function(self, p)
        self.viewKey = WK:CharKey()
        self.tab = "list"
        self.filter = "me"
        self.dtab = "loot"     -- onglet du détail : butin ou quêtes
        self.focus = nil       -- butin d'un seul boss (clic sur sa pastille ou sa ligne), nil = tous
        self.qfilter = "todo"  -- quêtes : à faire ou toutes
        local cur = D:Current()
        self.sel = cur and cur.key or nil

        self.tabSeg = UI:Segmented(p, { { "list", "Donjons" }, { "wish", "Mes envies" } },
            function(v) self.tab = v; self:Refresh() end, 30)
        self.tabSeg:SetPoint("TOPLEFT")
        local charOpts = charOptions()
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self:Refresh() end)
        self.charDd:SetPoint("TOPRIGHT", -38, 0)
        -- roue dentée : réglages des donjons (panneau, alertes, chrono)
        local dc = D:Config()
        local scard = UI:Card(p, T("Réglages des donjons"))
        scard:SetHeight(40 + 10 * 46 + 8)
        local dtog = {}
        local function drow(i, label, desc, field, after)
            local t = UI:Toggle(scard, function() return dc[field] end, function(v) dc[field] = v; if after then after() end; WK:NotifyChanged() end)
            table.insert(dtog, t)
            UI:SettingRow(scard, -40 - (i - 1) * 46, label, desc, t, 80)
        end
        drow(1, "Panneau à côté de la carte", "En donjon sans carte : boss et butin collés à la carte du monde (aussi /wk donjon).", "panel")
        drow(2, "Alerte en entrant", "Entrée dans un donjon qui contient des objets de ta liste d'envies.", "alertEnter")
        drow(3, "Alerte de butin", "Un objet de ta liste d'envies vient de tomber.", "alertDrop")
        drow(4, "Chrono à l'écran", "Temps du passage et écart avec ton record, déplaçable en mode édition.", "timer",
            function() if UI.RefreshDungeonTimer then UI:RefreshDungeonTimer() end end)
        drow(5, "Limite d'instances", "Alerte à 9 sur 10 nouvelles instances dans l'heure (limite du compte), et l'heure de la prochaine place libre.", "capAlert")
        drow(6, "Rappel du Réal de Terremine", "Après la 1re victoire du jour sur un boss qui en donne un : une icône clignote jusqu'au butin de son corps.", "real",
            function() if UI.RefreshRealReminder then UI:RefreshRealReminder() end end)
        local sumSeg = UI:Segmented(scard, { { "off", "Non" }, { "me", "Pour moi" }, { "group", "Au groupe" } }, function(v) dc.summary = v end, 24)
        sumSeg:Select(dc.summary or "me")
        UI:SettingRow(scard, -40 - 6 * 46, "Résumé en sortant", "Expérience, argent, morts et réputation du passage, dans le chat (ou envoyé au groupe).", sumSeg, 230)
        local startSeg = UI:Segmented(scard, { { "pull", "Au premier pack" }, { "enter", "En entrant" } }, function(v) dc.timerStart = v end, 24)
        startSeg:Select(dc.timerStart or "pull")
        UI:SettingRow(scard, -40 - 7 * 46, "Départ du chrono", "Au premier pack : le chrono attend ton premier combat dans le donjon (ou le chrono d'un membre du groupe). En entrant : dès la porte franchie.", startSeg, 250)
        do
            local t = UI:Toggle(scard, function() return dc.worldMap ~= false end, function(v)
                dc.worldMap = v; if UI.RefreshDungeonWorldMap then UI.RefreshDungeonWorldMap() end
            end)
            table.insert(dtog, t)
            UI:SettingRow(scard, -40 - 9 * 46, "Carte du donjon dans le jeu",
                "Dans un donjon qui en a une, la touche M montre la carte du donjon avec ses boss (tués, prochain) et la liste"
                    .. " des boss à droite ; clic droit : la carte de la zone.", t, 80)
        end
        drow(9, "Bilan à l'écran",
            "En sortant du donjon, un bandeau en haut de l'écran pendant 5 s : temps et record, boss,"
                .. " morts, XP et or (position en mode édition ; clic = fermer).", "summaryBanner")
        -- chrono à l'écran : préréglage, largeur, parties visibles (aperçu de quelques secondes à chaque changement)
        local to = UI:DungeonTimerOpts()
        local tcard = UI:Card(scard:GetParent(), T("Chrono à l'écran"))
        local ttog = {}
        local function tchanged() if UI.PreviewDungeonTimer then UI:PreviewDungeonTimer() end end
        local preSeg = UI:Segmented(tcard, { { "full", "Complet" }, { "compact", "Compact" }, { "minimal", "Minimal" }, { "custom", "Personnalisé" } },
            function(v)
                if v ~= "custom" then UI:ApplyDungeonTimerPreset(v) else to.timerPreset = "custom" end
                for _, t in ipairs(ttog) do t:Refresh() end
                tchanged()
            end, 24)
        UI:SettingRow(tcard, -40, "Affichage", "Complet : tout. Compact : boss restants, sans les écarts. Minimal : chrono, record et barre.", preSeg, 330)
        local wSeg
        local wSl = UI:Slider(tcard, 220, 180, 400, 10, function() return to.timerFixed end,
            function(v) to.timerFixed = v; to.timerWidth = "fixed"; wSeg:Select("fixed"); tchanged() end, "%d")
        wSeg = UI:Segmented(tcard, { { "tracker", "Comme le suivi des quêtes" }, { "fixed", "Fixe" } },
            function(v) to.timerWidth = v; tchanged() end, 24)
        UI:SettingRow(tcard, -86, "Largeur", "Comme le suivi des quêtes : même largeur que lui ; place le chrono juste dessous en mode édition.", wSeg, 260)
        UI:SettingRow(tcard, -132, "Largeur fixe", nil, wSl, 240)
        local th = UI:Text(tcard, 10, C.dim); th:SetPoint("TOPLEFT", 16, -176); th:SetText(T("AFFICHER"))
        local PL = {
            { "name", "Nom du donjon" }, { "cap", "Compteur de l'heure" },
            { "rec", "Record à côté du chrono" }, { "left", "Temps restant / dépassement" },
            { "bar", "Frise des boss" }, { "boss", "Liste des boss" },
            { "bt", "Temps de chaque boss" }, { "dl", "Écart avec le record" },
            { "remain", "Masquer les boss tués" }, { "soft", "Fond plus discret" },
        }
        for i, pl in ipairs(PL) do
            local k = pl[1]
            local t = UI:Toggle(tcard, function() return to.timerShow[k] and true or false end, function(v)
                to.timerShow[k] = v or nil
                if k ~= "soft" then to.timerPreset = "custom"; preSeg:Select("custom") end
                tchanged()
            end)
            local col, rowI = (i - 1) % 2, math.floor((i - 1) / 2)
            local y = -196 - rowI * 32
            if col == 0 then t:SetPoint("TOPLEFT", 16, y) else t:SetPoint("TOPLEFT", tcard, "TOP", 8, y) end
            local l = UI:Text(tcard, 12, C.text); l:SetPoint("LEFT", t, "RIGHT", 8, 0); l:SetText(T(pl[2]))
            table.insert(ttog, t)
        end
        tcard:SetHeight(196 + 5 * 32 + 8)
        local function tsync()
            to = UI:DungeonTimerOpts()
            preSeg:Select(to.timerPreset); wSeg:Select(to.timerWidth)
            for _, t in ipairs(ttog) do t:Refresh() end
        end
        tsync()
        -- fenêtre volante des quêtes du donjon (UI/DungeonQuests.lua)
        local qcard = UI:Card(scard:GetParent(), T("Quêtes du donjon"))
        local qtog = {}
        local function qref() if UI.RefreshDungeonQuests then UI:RefreshDungeonQuests() end end
        local winSeg = UI:Segmented(qcard, { { "auto", "Dans le donjon" }, { "off", "Jamais" } },
            function(v) dc.questWin = v; qref() end, 24)
        UI:SettingRow(qcard, -40, "Fenêtre des quêtes",
            "Seulement dans le donjon, avec ses quêtes. Glisser son titre la déplace.",
            winSeg, 300)
        -- opacité : réglage commun à tous les cadres (Options > Apparence > Fenêtre)
        local lookBtn = UI:Button(qcard, T("Apparence"), 110, 24, "secondary")
        lookBtn:SetScript("OnClick", function() UI.OpenLookWindow() end)
        UI:SettingRow(qcard, -90, "Opacité du fond", "Commune à tous les cadres à l'écran, pleine au survol.", lookBtn, 120)
        local function qrow(y, label, desc, field)
            local t = UI:Toggle(qcard, function() return dc[field] and true or false end, function(v) dc[field] = v; qref() end)
            table.insert(qtog, t)
            UI:SettingRow(qcard, y, label, desc, t, 80)
        end
        qrow(-136, "Objectifs des quêtes en cours", "Sous chaque quête de ton journal : ce qu'il reste à faire (Tueur défias 6/10…).", "questWinObjs")
        qrow(-182, "Ligne « Faites »", "Les quêtes déjà faites sur une ligne repliée (clic pour la déplier).", "questWinDone")
        qrow(-228, "Cachée en combat", "Elle revient à la fin du combat.", "questWinCombat")
        qrow(-274, "Cachée quand il ne reste rien", "Plus rien à faire ni à prendre dans ce donjon : la fenêtre disparaît.", "questWinAuto")
        qrow(-320, "Compacte", "Une ligne par quête (objectifs et lieu dans l'infobulle).", "questWinCompact")
        qcard:SetHeight(40 + 7 * 46 + 8)
        local function qsync() winSeg:Select(dc.questWin == "off" and "off" or "auto"); for _, t in ipairs(qtog) do t:Refresh() end end
        qsync()
        scard.gearTab, tcard.gearTab, qcard.gearTab = "main", "timer", "quests"
        self.gp = UI:PageGear(p, { title = "Réglages des donjons", top = 42, columns = 1, id = "dungeons",
            tabs = { { "main", T("Panneau et alertes") }, { "quests", T("Quêtes du donjon") },
                     { "timer", T("Chrono") } },
            cards = function() for _, t in ipairs(dtog) do t:Refresh() end; tsync(); qsync(); return { scard, qcard, tcard } end,
            onToggle = function(open)
                self.tabSeg:SetShown(not open); self.charDd:SetShown(not open); if self.ofLabel then self.ofLabel:SetShown(not open) end
            end }, self)
        self.gp.gear:SetPoint("TOPRIGHT")
        self.charDd:Select(self.viewKey)
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("RIGHT", self.charDd, "LEFT", -8, 0)
        of:SetText(T("Pour"))
        self.ofLabel = of

        -- colonne des donjons (groupes repliables, recherche)
        local lc = UI:Card(p)
        lc:SetWidth(LIST_W)
        lc:SetPoint("TOPLEFT", 0, -42)
        lc:SetPoint("BOTTOMLEFT")
        self.listCard = lc
        self.query = ""
        local search = UI:Input(lc, LIST_W - 20, 30, "Rechercher un donjon...", "search")
        search:SetPoint("TOPLEFT", 10, -10)
        search.onChange = function(t) self.query = string.lower(t or ""); self:Refresh() end
        -- instances cette heure (limite du compte)
        self.capLine = CreateFrame("Frame", nil, lc)
        self.capLine:SetPoint("TOPLEFT", 12, -46); self.capLine:SetPoint("TOPRIGHT", -12, -46); self.capLine:SetHeight(20)
        self.capLine.t = UI:Text(self.capLine, 10, C.muted); self.capLine.t:SetPoint("LEFT")
        self.capLine:EnableMouse(true)
        self.capLine:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("Instances cette heure"), 1, 1, 1)
            GameTooltip:AddLine(string.format(T("Le compte peut entrer dans %d nouvelles instances par heure glissante."), D.CAP), 0.8, 0.8, 0.8, true)
            for _, e in ipairs(D:Entries()) do
                local dd = D:Get(e.key)
                local c = WK.DB.global.characters[e.char]
                GameTooltip:AddDoubleLine(date("%H:%M", e.t) .. "  " .. (dd and D:Name(dd) or "?"), c and WK:CharName(c, e.char) or "", 1, 1, 1, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        self.capLine:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local lsc = UI:Scroll(lc)
        lsc:SetPoint("TOPLEFT", 6, -70)
        lsc:SetPoint("BOTTOMRIGHT", -6, 8)
        self.lsc = lsc
        local ui = WK.DB.global.settings.ui
        ui.dgnClosed = ui.dgnClosed or { past = true }
        self.gheads = UI:Pool(function()
            local h = CreateFrame("Button", nil, lsc.child)
            h:SetHeight(24)
            h.label = UI:Text(h, 10, C.dim); h.label:SetPoint("LEFT", 8, 0)
            h.count = UI:Text(h, 10, C.dim); h.count:SetPoint("RIGHT", -24, 0)
            h.arrow = UI:Icon(h, "chevron", 12, C.dim); h.arrow:SetPoint("RIGHT", -8, 0)
            h:SetScript("OnClick", function(s) ui.dgnClosed[s.key] = not ui.dgnClosed[s.key] or nil; self:Refresh() end)
            return h
        end)
        self.drows = UI:Pool(function()
            local r = CreateFrame("Button", nil, lsc.child)
            r:SetHeight(ROW_H)
            r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 1)
            r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetSize(3, 16); r.bar:SetPoint("LEFT", 0, 0)
            r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK"); r.dot:SetPoint("LEFT", 10, 0)
            r.kills = UI:Text(r, 10, C.dim); r.kills:SetPoint("RIGHT", -8, 0); r.kills:SetJustifyH("RIGHT"); r.kills:SetWidth(36)
            r.lv = UI:Text(r, 10); r.lv:SetPoint("RIGHT", r.kills, "LEFT", -4, 0); r.lv:SetJustifyH("RIGHT"); r.lv:SetWidth(44)
            r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 24, 0); r.name:SetPoint("RIGHT", r.lv, "LEFT", -6, 0)
            r:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
            r:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
            r:SetScript("OnClick", function(s) self.sel = s.key; self:Refresh() end)
            function r:Paint()
                local ar, ag, ab = UI:Accent()
                if self.selected then self.bg:SetColor(ar, ag, ab, 0.14) else self.bg:SetColor(unpack(C.hover)) end
                self.bg:SetShown(self.selected or self.hover)
                self.bar:SetShown(self.selected)
                self.bar:SetColorTexture(ar, ag, ab, 1)
            end
            return r
        end)

        local sc = UI:Scroll(p)
        sc:SetPoint("TOPLEFT", LIST_W + GAP, -42)
        sc:SetPoint("BOTTOMRIGHT")
        self.sc = sc
        local root = sc.child

        -- détail du donjon choisi
        local det = UI:Card(root)
        self.det = det
        det.title = UI:Text(det, 15)
        det.title:SetPoint("TOPLEFT", 14, -12)
        det.sub = UI:Text(det, 11, C.muted)
        det.sub:SetPoint("LEFT", det.title, "RIGHT", 10, 0)
        det.filter = UI:Segmented(det, { { "me", "Pour ce perso" }, { "all", "Tout" } }, function(v) self.filter = v; self:Refresh() end, 24)
        det.filter:SetPoint("TOPRIGHT", -12, -10)
        det.qfilter = UI:Segmented(det, { { "todo", "À faire" }, { "all", "Toutes" } }, function(v) self.qfilter = v; self:Refresh() end, 24)
        det.qfilter:SetPoint("TOPRIGHT", -12, -10)
        -- onglets Butin / Quêtes : libellé, pastille (nombre), soulignement de l'onglet choisi
        det.tabLine = det:CreateTexture(nil, "ARTWORK")
        det.tabLine:SetHeight(1)
        det.tabLine:SetPoint("TOPLEFT", 14, -72)
        det.tabLine:SetPoint("TOPRIGHT", -14, -72)
        det.tabs = {}
        local function tab(key, label)
            local b = CreateFrame("Button", nil, det)
            b:SetHeight(30)
            b.label = UI:Text(b, 13)
            b.label:SetPoint("LEFT", 10, 0)
            b.label:SetText(T(label))
            b.badge = UI:Badge(b, "", C.muted)
            b.badge:SetPoint("LEFT", b.label, "RIGHT", 7, 0)
            b.under = CreateFrame("Frame", nil, b)
            b.under:SetHeight(2)
            b.under:SetPoint("BOTTOMLEFT", 0, -1)
            b.under:SetPoint("BOTTOMRIGHT", 0, -1)
            b.underTex = UI:Rounded(b.under, 1, 0, "OVERLAY", 2)
            -- col : couleur de la pastille (nil = couleur de l'addon) ; keep : la garder même onglet pas choisi
            function b:Paint(sel, count, col, keep)
                self.badge:Set(count or "", (sel or keep) and col or (not sel and C.muted or nil))
                self.badge:SetShown(count ~= nil and count ~= "")
                self:SetWidth(self.label:GetStringWidth() + 20 + (self.badge:IsShown() and self.badge:GetWidth() + 7 or 0))
                -- onglet choisi en blanc, l'autre à la couleur de l'apparence (comme les boutons)
                local r, g, bl = UI:Accent()
                if sel then self.label:SetTextColor(unpack(C.text)) else self.label:SetTextColor(r, g, bl, self.hover and 1 or 0.85) end
                self.under:SetShown(sel)
                self.underTex:SetColor(UI:Accent())
            end
            local function recolor(s)
                if s.under:IsShown() then return end
                local r, g, bl = UI:Accent()
                s.label:SetTextColor(r, g, bl, s.hover and 1 or 0.85)
            end
            b:SetScript("OnEnter", function(s) s.hover = true; recolor(s) end)
            b:SetScript("OnLeave", function(s) s.hover = false; recolor(s) end)
            b:SetScript("OnClick", function() self.dtab = key; self:Refresh() end)
            det.tabs[key] = b
            return b
        end
        tab("loot", "Butin")
        det.live = UI:Badge(det, "Tu es dedans", C.positive)
        det.live:SetPoint("LEFT", det.sub, "RIGHT", 10, 0)
        tab("quests", "Quêtes"):SetPoint("LEFT", det.tabs.loot, "RIGHT", 8, 0)
        det.quests = UI:Text(det, 11, C.muted)
        det.lfg = UI:Button(det, "Chercher un groupe", nil, 26, "secondary", "lfg")
        det.lfg:SetScript("OnClick", function() UI:ShowPage("lfg") end)
        det.go = UI:Button(det, "Guider vers l'entrée", nil, 26, "ghost", "guide")
        det.go:SetScript("OnClick", function() local d = D:Get(self.sel); if d then D:GuideTo(d) end end)
        det.pnl = UI:Button(det, "Panneau en jeu", nil, 26, "ghost")
        det.pnl:SetScript("OnClick", function() local d = D:Get(self.sel); if d then UI:ToggleDungeonPanel(d) end end)
        det.say = UI:Button(det, "Annoncer au groupe", nil, 26, "ghost")
        det.say:SetScript("OnClick", function() local d = D:Get(self.sel); if d then D:Announce(d) end end)
        det.share = UI:Button(det, "Partager le parcours", nil, 26, "ghost")
        det.share:SetScript("OnClick", function()
            local d = D:Get(self.sel)
            if d and not D:Share(d) then WK:Print(T("Partage impossible : pas de groupe, ou pas dans ce donjon.")) end
        end)
        -- haut fixe (maquette A) : en-tête, carte et liste des boss, onglets ; seule la liste de l'onglet défile
        local top = CreateFrame("Frame", nil, p)
        top:SetPoint("TOPLEFT", LIST_W + GAP, -42); top:SetPoint("TOPRIGHT", 0, -42)
        top:SetHeight(100)
        self.top = top
        for _, w in ipairs({ det.live, det.filter, det.qfilter, det.tabs.loot, det.tabs.quests }) do w:SetParent(top) end
        -- titre, sous-titre et trait des onglets refaits dans le haut fixe (textes et traits gardent leur cadre)
        det.title:Hide(); det.sub:Hide(); det.tabLine:Hide()
        det.title = UI:Text(top, 15); det.title:SetPoint("TOPLEFT", 2, -6)
        det.sub = UI:Text(top, 11, C.muted); det.sub:SetPoint("LEFT", det.title, "RIGHT", 10, 0)
        det.live:ClearAllPoints(); det.live:SetPoint("LEFT", det.sub, "RIGHT", 10, 0)
        det.tabLine = top:CreateTexture(nil, "ARTWORK"); det.tabLine:SetHeight(1)
        det.filter:ClearAllPoints(); det.filter:SetPoint("TOPRIGHT", 0, -2)
        det.qfilter:ClearAllPoints(); det.qfilter:SetPoint("TOPRIGHT", 0, -2)
        self.map = UI:DungeonMapView(top)
        self.map.onBoss = function(b) self.dtab = "loot"; self.focus = b.id; self:Refresh() end
        self.map.onHover = function(b)
            for _, r in ipairs(self.brows.items) do if r:IsShown() then r.hl = b and r.boss.id == b.id; r:Paint() end end
        end
        -- liste des boss à côté de la carte : n°, nom, étage, état ; survol = le boss s'allume sur la carte
        -- la liste défile quand elle dépasse la hauteur de la carte (donjons à 20 boss et plus)
        self.bscroll = UI:Scroll(top)
        self.brows = UI:Pool(function()
            local r = CreateFrame("Button", nil, self.bscroll.child)
            r:SetHeight(40)
            r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
            -- pastille comme sur la carte, nom, 2e ligne (niveau, étage, état), butin pour ce perso à droite
            r.pin = CreateFrame("Frame", nil, r); r.pin:SetSize(22, 22); r.pin:SetPoint("LEFT", 8, 0)
            r.ring = UI:Rounded(r.pin, 11, 0, "ARTWORK", 1)
            r.fill = UI:Rounded(r.pin, 9, 2, "ARTWORK", 2)
            r.n = UI:Text(r.pin, 10); r.n:SetPoint("CENTER", 0, 0)
            -- portrait du boss (rond, liseré), grisé une fois tué
            r.face = r:CreateTexture(nil, "ARTWORK", nil, 2)
            r.faceRing = UI:Icon(r, "circle", 34, nil, "ARTWORK")
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 40, -5); r.name:SetPoint("RIGHT", r, "RIGHT", -150, 0)
            r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
            r.sub = UI:Text(r, 10, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", r, "RIGHT", -150, 0); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
            r.icons = {}
            for k = 1, 5 do
                local ic = CreateFrame("Button", nil, r)
                ic:SetSize(24, 24)
                ic:SetPoint("RIGHT", r, "RIGHT", -8 - (k - 1) * 27, 0)
                ic.edge = UI:Rounded(ic, 5, 0, "BACKGROUND", 1)
                ic.tex = ic:CreateTexture(nil, "ARTWORK")
                ic.tex:SetPoint("TOPLEFT", 2, -2); ic.tex:SetPoint("BOTTOMRIGHT", -2, 2)
                ic.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                ic:SetScript("OnEnter", function(s2)
                    UI:TooltipOwner(s2, "ANCHOR_RIGHT")
                    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s2.id)
                    else GameTooltip:SetText((UI:ItemInfo(s2.id))) end
                    local info = D:ItemInfo(s2.id)
                    if info and info.drop then
                        local txt = string.format(T("Chance de drop : %s %%"), tostring(info.drop))
                        GameTooltip:AddLine(txt, 0.8, 0.8, 0.8)
                    end
                    GameTooltip:Show()
                end)
                ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
                ic:SetScript("OnClick", function(s2)
                    if IsShiftKeyDown() then
                        local link = select(6, UI:ItemInfo(s2.id))
                        if link then WK.InsertChatLink(link) end
                    else r:GetScript("OnClick")(r) end
                end)
                r.icons[k] = ic
            end
            function r:Paint()
                local on = self.state == "next" or self.hl or self.focused
                self.bg:SetColor(unpack(self.hl and C.hover or C.surface2)); self.bg:SetShown(on)
            end
            r:SetScript("OnEnter", function(s2) s2.hl = true; s2:Paint(); self.map:Highlight(s2.boss.id) end)
            r:SetScript("OnLeave", function(s2) s2.hl = false; s2:Paint(); self.map:Highlight(nil) end)
            r:SetScript("OnClick", function(s2)
                self.dtab = "loot"
                self.focus = (self.focus ~= s2.boss.id) and s2.boss.id or nil
                self:Refresh()
            end)
            return r
        end)
        -- butin d'un seul boss : bouton pour revenir à tous
        det.allLoot = UI:Button(top, "Tous les boss", nil, 22, "ghost")
        det.allLoot:SetScript("OnClick", function() self.focus = nil; self:Refresh() end)
        -- barre du bas
        local bar = CreateFrame("Frame", nil, p)
        bar:SetPoint("BOTTOMLEFT", LIST_W + GAP, 0); bar:SetPoint("BOTTOMRIGHT")
        bar:SetHeight(34)
        self.actions = bar
        for _, w in ipairs({ det.lfg, det.go, det.pnl, det.say, det.share }) do w:SetParent(bar) end
        det.lfg:ClearAllPoints(); det.lfg:SetPoint("RIGHT", 0, 0)
        det.go:ClearAllPoints(); det.go:SetPoint("RIGHT", det.lfg, "LEFT", -8, 0)
        -- fenêtre des quêtes du donjon choisi (UI/DungeonQuests.lua), avec la tournée de ramassage
        self.bheads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, det)
            h:SetHeight(26)
            h.bg = UI:Rounded(h, 7, 0, "BACKGROUND", 1)
            h.name = UI:Text(h, 12)
            h.name:SetPoint("LEFT", 10, 0)
            h.right = UI:Text(h, 10, C.muted)
            h.right:SetPoint("RIGHT", -10, 0)
            return h
        end)
        self.items = UI:Pool(function() return UI:DungeonLootRow(det) end)
        -- quêtes du donjon : état pour le perso et quête à faire avant
        self.qrows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, det)
            r:SetHeight(24)
            r.dot = UI:Icon(r, "circle", 9, nil, "ARTWORK")
            r.dot:SetPoint("LEFT", 6, 0)
            r.lvl = UI:Text(r, 11, C.muted)
            r.lvl:SetPoint("LEFT", 20, 0)
            r.lvl:SetWidth(24)
            r.lvl:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 52, 0)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            r.state = UI:Text(r, 11)
            r.state:SetJustifyH("RIGHT")
            r.state:SetWordWrap(false)
            r.guide = UI:GuideButton(r, 22, "Guider vers le donneur")
            r.guide:SetPoint("RIGHT", -4, 0)
            r.state:SetPoint("RIGHT", r.guide, "LEFT", -8, 0)
            r.state:SetWidth(300)
            r.name:SetPoint("RIGHT", r.state, "LEFT", -8, 0)
            return r
        end)
        self.none = UI:Text(det, 11, C.muted)

        -- onglet Mes envies
        local wcard = UI:Card(root, T("Mes envies"), " ")
        self.wcard = wcard
        -- une case par donjon (rangées en colonnes) : en-tête cliquable, boss, objets
        self.wheads = UI:Pool(function()
            local h = CreateFrame("Button", nil, wcard)
            h:SetHeight(46)
            h.bg = UI:Rounded(h, 6, 0, "BACKGROUND", 1)
            h.name = UI:Text(h, 13); h.name:SetPoint("TOPLEFT", 12, -7); h.name:SetJustifyH("LEFT")
            h.name:SetWordWrap(false)
            h.sub = UI:Text(h, 10, C.muted); h.sub:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -3)
            h.go = UI:Button(h, "Guider", nil, 22, "ghost", "guide")
            h.go:SetPoint("RIGHT", -8, 0)
            h.open = UI:Button(h, "Voir", nil, 22, "ghost")
            h.open:SetPoint("RIGHT", h.go, "LEFT", -6, 0)
            h.name:SetPoint("RIGHT", h.open, "LEFT", -8, 0)
            local function open(s2)
                self.tab = "list"; self.sel = s2.dk; self.focus = nil; self.dtab = "loot"; self:Refresh()
            end
            h:SetScript("OnClick", open)
            h.open:SetScript("OnClick", function(b2) open(b2:GetParent()) end)
            h.go:SetScript("OnClick", function(b2) local d = D:Get(b2:GetParent().dk); if d then D:GuideTo(d) end end)
            h:SetScript("OnEnter", function(s2) s2.bg:SetColor(unpack(C.hover)) end)
            h:SetScript("OnLeave", function(s2) s2.bg:SetColor(unpack(C.surface2)) end)
            return h
        end)
        self.wboss = UI:Pool(function()
            local t = UI:Text(wcard, 10, C.dim)
            t:SetJustifyH("LEFT"); t:SetWordWrap(false)
            return t
        end)
        self.wrows = UI:Pool(function() return UI:DungeonLootRow(wcard) end)
        self.wempty = UI:Text(wcard, 11, C.muted)
        self.wempty:SetPoint("TOPLEFT", 16, -44)
        self.wempty:SetText(T("Pas encore d'envie : clique sur l'étoile d'un objet dans un donjon."))

        UI:OnResize(sc, function(w) self.width = w; root:SetWidth(math.max(100, w - 12)); self:Refresh() end)
    end,

    -- un changement de taille pendant le dessin relance Refresh : jamais deux dessins mêlés (colonnes en double)
    Refresh = function(self)
        if self.drawing then self.redraw = true return end
        self.drawing = true
        local ok, err = pcall(self.RefreshNow, self)
        self.drawing = false
        if not ok then error(err, 0) end
        if self.redraw then self.redraw = false; return self:Refresh() end
    end,

    RefreshNow = function(self)
        if not self.sc then return end
        -- menu des persos à jour (perso renommé ou supprimé : retour au premier)
        self.charDd:SetOptions(charOptions())
        if self.charDd.selected ~= self.viewKey then
            if WK.DB.global.characters[self.viewKey] then self.charDd:Select(self.viewKey) else self.viewKey = self.charDd.selected end
        end
        local W = math.max(400, ((self.sc and self.sc:GetWidth() or 0) > 0 and self.sc:GetWidth() or self.width or 800) - 12)
        local c = WK.DB.global.characters[self.viewKey] or WK.DB:Me()
        local key = self.viewKey
        local lvl = c.level or 1
        self.tabSeg:Select(self.tab)
        self.gheads:Reset(); self.drows:Reset(); self.bheads:Reset(); self.items:Reset(); self.wrows:Reset(); self.qrows:Reset()
        self.brows:Reset()
        -- entrée dans un donjon : la page se place dessus, onglet Parcours
        local cur = D:Current()
        local curKey = cur and cur.key or nil
        if curKey ~= self.lastCur then
            if curKey then self.sel, self.focus = curKey, nil end
            self.lastCur = curKey
        end
        -- « Mes envies » : sur toute la largeur, sans la colonne des donjons
        local wish = self.tab == "wish"
        self.listCard:SetShown(not wish)
        self.top:SetShown(not wish); self.actions:SetShown(not wish)
        self.sc:ClearAllPoints()
        if wish then
            self.sc:SetPoint("TOPLEFT", 0, -42); self.sc:SetPoint("BOTTOMRIGHT")
        else
            self.sc:SetPoint("TOPLEFT", self.top, "BOTTOMLEFT", 0, -2); self.sc:SetPoint("BOTTOMRIGHT", 0, 40)
        end
        if wish then
            self.det:Hide()
            local wc = self.wcard
            wc:Show()
            wc:ClearAllPoints(); wc:SetPoint("TOPLEFT", 0, 0); wc:SetWidth(W)
            local list = D:Wishes(key)
            self.wheads:Reset(); self.wboss:Reset()
            -- par donjon (ordre de niveau), puis par boss dans l'ordre du donjon
            local groups, order = {}, {}
            for _, e in ipairs(list) do
                local dk = e.dungeon and e.dungeon.key or 0
                if not groups[dk] then groups[dk] = { d = e.dungeon, ids = {} }; order[#order + 1] = dk end
                groups[dk].ids[e.id] = true
            end
            if wc.subtitle then
                wc.subtitle:SetText(string.format(T("%d objet(s) dans %d donjon(s) pour %s"), #list, #order,
                    WK:CharName(c, key)))
            end
            local ncol = math.max(1, math.min(3, math.floor((W - 20) / 440)))
            local WGAP = 14
            local colW = (W - 24 - (ncol - 1) * WGAP) / ncol
            local colY = {}
            for k = 1, ncol do colY[k] = 44 end
            for _, dk in ipairs(order) do
                local g = groups[dk]
                local k = 1
                for j = 2, ncol do if colY[j] < colY[k] then k = j end end
                local x = 12 + (k - 1) * (colW + WGAP)
                local yy = colY[k]
                local h = self.wheads:Get()
                h.dk = dk
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", x, -yy); h:SetWidth(colW)
                h.bg:SetColor(unpack(C.surface2))
                local d = g.d
                h.name:SetText(d and D:Name(d) or T("Autre"))
                if d then
                    local done, n = D:Progress(d, key)
                    local col = levelColor(d, lvl)
                    h.sub:SetText(UI:Hex(col) .. (d.raid and T("raid") or (d.min .. "-" .. d.max)) .. "|r  ·  "
                        .. string.format(T("%d/%d boss"), done, n))
                else
                    h.sub:SetText("")
                end
                h.go:SetShown(d ~= nil and d.entry ~= nil); h.open:SetShown(d ~= nil)
                yy = yy + 46 + 6
                -- boss du donjon qui portent une envie, dans l'ordre du jeu ; le reste à la fin
                local seen = {}
                local blocks = {}
                if d then
                    for _, b in ipairs(D:LootGroups(d)) do
                        local ids = {}
                        for _, id in ipairs(b.loot) do
                            if g.ids[id] and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
                        end
                        if #ids > 0 then blocks[#blocks + 1] = { D:BossName(b), ids } end
                    end
                end
                local rest = {}
                for id in pairs(g.ids) do if not seen[id] then rest[#rest + 1] = id end end
                table.sort(rest)
                if #rest > 0 then blocks[#blocks + 1] = { nil, rest } end
                for _, bl in ipairs(blocks) do
                    if bl[1] then
                        local t = self.wboss:Get()
                        t:ClearAllPoints(); t:SetPoint("TOPLEFT", x + 6, -yy); t:SetWidth(colW - 12)
                        t:SetText(UI:Upper(bl[1]))
                        yy = yy + 16
                    end
                    for _, id in ipairs(bl[2]) do
                        local it = self.wrows:Get()
                        it:ClearAllPoints(); it:SetPoint("TOPLEFT", x, -yy); it:SetWidth(colW)
                        it:Set(id, dk ~= 0 and dk or nil, c, key, true)
                        yy = yy + ITEM_H
                    end
                    yy = yy + 6
                end
                colY[k] = yy + 12
            end
            local bottom = 44
            for k = 1, ncol do bottom = math.max(bottom, colY[k]) end
            self.wempty:SetShown(#list == 0)
            if #list == 0 then bottom = 80 end
            wc:SetHeight(bottom + 6)
            self.sc:SetContentHeight(bottom + 16)
            return
        end
        self.wcard:Hide()
        -- instances cette heure
        do
            local n, free = D:HourCount()
            local col = n >= D.CAP - 1 and C.negative or C.muted
            self.capLine.t:SetText(UI:Hex(col) .. string.format(T("%d / %d instances cette heure"), n, D.CAP) .. "|r"
                .. ((n > 0 and free) and ("  ·  " .. string.format(T("place dans %d min"), math.ceil(free / 60))) or ""))
        end
        -- colonne des donjons, groupés selon le niveau du perso
        local list = D:All()
        if not self.sel then
            for _, d in ipairs(list) do if lvl >= d.min - 2 and lvl <= d.max then self.sel = d.key break end end
            self.sel = self.sel or (list[1] and list[1].key)
        end
        local closed = WK.DB.global.settings.ui.dgnClosed
        local q = self.query or ""
        local byGroup = {}
        for _, d in ipairs(list) do
            if q == "" or string.find(string.lower(D:Name(d)), q, 1, true) then
                local g = groupOf(d, lvl)
                byGroup[g] = byGroup[g] or {}
                table.insert(byGroup[g], d)
            end
        end
        local selGroup
        do local sd = D:Get(self.sel); selGroup = sd and groupOf(sd, lvl) end
        local ly = 2
        for _, gdef in ipairs(GROUPS) do
            local g = byGroup[gdef[1]]
            if g then
                local h = self.gheads:Get()
                h.key = gdef[1]
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -ly); h:SetPoint("TOPRIGHT", 0, -ly)
                local label = gdef[1] == "now" and string.format(T("Pour ton niveau (%d)"), lvl) or T(gdef[2])
                h.label:SetText(UI:Upper(label))
                h.count:SetText(tostring(#g))
                -- groupe replié, sauf pendant une recherche ou s'il contient le donjon choisi
                local isClosed = closed[gdef[1]] and q == "" and gdef[1] ~= selGroup
                h.arrow:SetRotation(isClosed and (math.pi / 2) or 0)
                ly = ly + 24
                if not isClosed then
                    for _, d in ipairs(g) do
                        local r = self.drows:Get()
                        r.key = d.key
                        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -ly); r:SetPoint("TOPRIGHT", 0, -ly)
                        r.selected = d.key == self.sel
                        r:Paint()
                        local col = levelColor(d, lvl)
                        r.dot:SetVertexColor(col[1], col[2], col[3], 1)
                        r.name:SetText(D:Name(d))
                        r.lv:SetText(d.raid and T("raid") or (d.min .. "-" .. d.max))
                        r.lv:SetTextColor(col[1], col[2], col[3])
                        local done, n = D:Progress(d, key)
                        r.kills:SetText(done .. "/" .. n)
                        r.kills:SetTextColor(unpack(n > 0 and done >= n and C.positive or C.dim))
                        ly = ly + ROW_H + 2
                    end
                end
                ly = ly + 6
            end
        end
        self.lsc:SetContentHeight(ly)
        local y = 0
        -- détail
        local d = D:Get(self.sel)
        local det = self.det
        det:SetShown(d ~= nil)
        self.top:SetShown(d ~= nil); self.actions:SetShown(d ~= nil)
        if not d then self.sc:SetContentHeight(y) return end
        if self.focusDungeon ~= d.key then self.focus, self.focusDungeon = nil, d.key end
        self:LayoutTop(d, key, W)
        det:ClearAllPoints(); det:SetPoint("TOPLEFT", 0, -y); det:SetWidth(W)
        det.title:SetText(D:Name(d))
        local done, n = D:Progress(d, key)
        -- le passage en cours est celui du perso connecté : seulement quand la page le montre lui
        local inRun = D:InRun(d) and key == WK:CharKey()
        if inRun then
            local k, m = 0, 0
            for _, b in ipairs(D:Bosses(d)) do
                if not D:Optional(d, b) then m = m + 1; if D.run.killed[b.id] then k = k + 1 end end
            end
            det.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss ce passage"), d.min, d.max, k, m))
        else
            det.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss déjà tués par ce perso"), d.min, d.max, done, n))
        end
        det.live:SetShown(inRun and curKey == d.key)
        det.filter:Select(self.filter)
        det.qfilter:Select(self.qfilter)
        if self.dtab ~= "quests" then self.dtab = "loot" end
        local onLoot = self.dtab == "loot"
        det.filter:SetShown(not (self.dtab == "quests"))
        det.qfilter:SetShown(self.dtab == "quests")
        det.tabLine:SetColorTexture(unpack(C.border))
        -- quêtes du donjon (zone de l'entrée, au niveau du donjon), pour le perso choisi :
        -- faite, en cours, disponible, niveau trop bas, ou quête à faire avant (prérequis)
        local Q = WK.modules.Quests
        local quests = {}
        -- quêtes que ce perso peut prendre (classe, métier, faction) ; si les quêtes de donjon sont
        -- masquées dans la page Quêtes, ce filtre les retirerait toutes : liste sans filtre de perso
        local dq = Q:Config().dungeons and D:Quests(d, c) or D:Quests(d)
        for _, q in ipairs(dq) do
            local okSide = not q.side or (c.faction == "Alliance" and q.side == 1) or (c.faction == "Horde" and q.side == 2) or not c.faction
            if okSide then table.insert(quests, q) end
        end
        local ORDER = { avail = 1, log = 2, locked = 3, high = 4, done = 5, closed = 6 }
        local states = {}
        local todo = 0
        for _, q in ipairs(quests) do
            states[q] = { Q:State(q, c) }
            if states[q][1] ~= "done" then todo = todo + 1 end
        end
        -- nombre d'objets du butin (filtre en cours) pour l'onglet
        local nLoot = 0
        for _, b in ipairs(D:LootGroups(d)) do nLoot = nLoot + #UI:DungeonLoot(b, self.filter, c, key) end
        det.tabs.loot:Paint(onLoot, tostring(nLoot))
        local qBadge = #quests == 0 and T("aucune") or todo == 0 and T("toutes faites")
            or string.format(todo > 1 and T("%d à faire") or T("%d à faire"), todo)
        det.tabs.quests:Paint(self.dtab == "quests", qBadge, todo > 0 and C.warning or C.positive, todo > 0)
        self.questTodo = todo
        det.allLoot:SetShown(onLoot and self.focus ~= nil)
        if not onLoot then
            self.none:Hide()
            return self:RefreshQuests(d, c, quests, states, ORDER, y, W)
        end
        -- boss en deux colonnes (une si la page est étroite)
        local ncol = W >= 760 and 2 or 1
        local colW = (W - 28 - (ncol - 1) * 12) / ncol
        local colY = {}
        for k = 1, ncol do colY[k] = 10 end
        local any = false
        for _, b in ipairs(D:LootGroups(d)) do
            local loot = (not self.focus or b.id == self.focus) and UI:DungeonLoot(b, self.filter, c, key) or {}
            if #loot > 0 then
                any = true
                local k = 1
                for j = 2, ncol do if colY[j] < colY[k] then k = j end end
                local x = 14 + (k - 1) * (colW + 12)
                local h = self.bheads:Get()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", x, -colY[k]); h:SetWidth(colW)
                h.bg:SetColor(unpack(C.surface2))
                h.name:SetText(D:BossName(b))
                local right = b.wing and T(b.wing) or ""
                if (b.level or 0) > 0 then right = (right ~= "" and (right .. "  ·  ") or "") .. string.format(T("niv. %d"), b.level) end
                h.right:SetText(right)
                colY[k] = colY[k] + 28
                for _, id in ipairs(loot) do
                    local it = self.items:Get()
                    it:ClearAllPoints(); it:SetPoint("TOPLEFT", x, -colY[k]); it:SetWidth(colW)
                    it:Set(id, d.key, c, key, self.filter == "me")
                    colY[k] = colY[k] + ITEM_H
                end
                colY[k] = colY[k] + 10
            end
        end
        local bottom = 10
        for k = 1, ncol do bottom = math.max(bottom, colY[k]) end
        self.none:SetShown(not any)
        self.none:ClearAllPoints(); self.none:SetPoint("TOPLEFT", 16, -14)
        self.none:SetText(T("Rien que ce perso puisse porter ici (essaie « Tout »)."))
        if not any then bottom = 40 end
        self:PlaceButtons(d)
        local h = bottom + 8
        det:SetHeight(h)
        self.sc:SetContentHeight(y + h + 10)
    end,

    -- barre du bas : guidage, groupe ; dans le donjon : annoncer, partager ; sans carte : panneau en jeu
    PlaceButtons = function(self, d)
        local det = self.det
        det.quests:SetText("")
        det.go:SetShown(d.entry ~= nil)
        local inRun = D:InRun(d) and self.viewKey == WK:CharKey()
        local prev = d.entry and det.go or det.lfg
        det.pnl:SetShown(UI.DungeonMapData(d) == nil)
        for _, b in ipairs({ det.pnl, det.share, det.say }) do
            local show = (b == det.pnl) and b:IsShown() or (b ~= det.pnl and inRun)
            b:SetShown(show)
            if show then b:ClearAllPoints(); b:SetPoint("RIGHT", prev, "LEFT", -8, 0); prev = b end
        end
    end,

    -- haut fixe : en-tête, carte (taille selon la place) et liste des boss, onglets
    LayoutTop = function(self, d, key, W)
        local det, top = self.det, self.top
        local m = UI.DungeonMapData(d)
        local pageH = (self.top:GetParent():GetHeight() or 600)
        -- la carte grandit avec la fenêtre ; il reste au moins 150 px pour la liste de l'onglet
        local avail = pageH - 42 - 32 - 40 - 40 - 150
        -- largeur de la carte ; sa hauteur suit (carte 3:2 plus basse : un peu plus large pour la même place)
        local ratio = m and UI.DungeonMapHeight(m, nil, 1000) / 1000 or 1
        local S = m and math.floor(math.max(200, math.min(360 / ratio, avail / ratio, W * 0.45))) or 0
        local MH = m and math.floor(S * ratio) or 0
        local y0 = 32
        self.map:ClearAllPoints()
        if m then
            self.map:SetPoint("TOPLEFT", 0, -y0); self.map:SetSize(S, MH)
            self.map:SetDungeon(d, key)
            self.map:Highlight(nil)
        else
            self.map:Hide()
        end
        -- liste des boss
        local x0 = m and (S + 12) or 0
        local nextB = D:Next(d, key)
        local n, y = 0, 0
        local bosses = D:Bosses(d)
        -- lignes de 30 à 46 px : la liste remplit la hauteur de la carte, et défile au-delà
        local RH = math.floor(math.max(30, math.min(46, (m and MH or 46 * #bosses) / math.max(1, #bosses))))
        local listH = RH * #bosses
        -- la liste peut descendre sous la carte (carte en largeur, peu haute) jusqu'à la place réservée
        local viewH = m and math.max(MH, math.min(listH, avail)) or math.min(listH, math.max(120, math.min(320, avail)))
        -- beaucoup de boss : deux colonnes côte à côte (lignes de 24 px au moins) pour que tout tienne
        local ncol, perCol = 1, #bosses
        if listH > viewH + 1 and (W - x0 - 10) / 2 >= 250 then
            ncol, perCol = 2, math.ceil(#bosses / 2)
            RH = math.floor(math.max(24, math.min(46, viewH / perCol)))
            listH = RH * perCol
            if not m then viewH = math.min(listH, math.max(120, avail)) end
        end
        local bs = self.bscroll
        local over = listH > viewH + 1
        bs:ClearAllPoints(); bs:SetPoint("TOPLEFT", x0, -y0)
        bs:SetSize(math.max(100, W - x0), math.max(1, viewH))
        local innerW = math.max(100, W - x0 - (over and 14 or 0))
        bs.child:SetWidth(innerW)
        local CGAP = 10
        local colW = ncol == 2 and (innerW - CGAP) / 2 or innerW
        local c = WK.DB.global.characters[key] or WK.DB:Me()
        local ac = { UI:Accent() }
        for i, b in ipairs(bosses) do
            local opt = D:Optional(d, b)
            if not opt then n = n + 1 end
            local r = self.brows:Get()
            r.boss = b
            -- 2e colonne : on repart du haut
            if ncol == 2 and i == perCol + 1 then y = 0 end
            local cx = (ncol == 2 and i > perCol) and (colW + CGAP) or 0
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", cx, -y); r:SetWidth(colW)
            r.state = UI.DungeonBossState(d, b, key, nextB)
            r.focused = self.focus == b.id
            r:SetHeight(RH - 3)
            r.n:SetText(r.state == "dead" and "x" or (opt and "+" or tostring(n)))
            -- pastille aux couleurs de la carte
            if r.state == "dead" then
                r.ring:SetColor(C.dim[1], C.dim[2], C.dim[3], 1); r.fill:SetColor(0.23, 0.25, 0.28, 1)
                r.n:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            elseif r.state == "next" then
                r.ring:SetColor(1, 1, 1, 1); r.fill:SetColor(ac[1], ac[2], ac[3], 1)
                r.n:SetTextColor(C.onAccent[1], C.onAccent[2], C.onAccent[3])
            else
                r.ring:SetColor(ac[1], ac[2], ac[3], opt and 0.6 or 1); r.fill:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
                r.n:SetTextColor(C.text[1], C.text[2], C.text[3])
            end
            r.name:SetText(D:BossName(b))
            local col = r.state == "dead" and C.muted or C.text
            r.name:SetTextColor(col[1], col[2], col[3])
            -- 2e ligne : niveau, étage, état
            local bits = {}
            if (b.level or 0) > 0 then bits[#bits + 1] = string.format(T("niv. %d"), b.level) end
            local p = m and UI.DungeonBossPin(m, b)
            if p and #m.f > 1 then bits[#bits + 1] = string.format(T("étage %d"), p[1]) end
            if opt then bits[#bits + 1] = T("facultatif") end
            if r.state == "dead" then bits[#bits + 1] = T("tué")
            elseif r.state == "next" then bits[#bits + 1] = UI:Hex(ac) .. T("prochain") .. "|r" end
            r.sub:SetText(table.concat(bits, "  ·  "))
            r.sub:SetShown(RH >= 36)
            -- portrait entre la pastille et le nom
            local FS = math.min(32, RH - 9)
            local hasFace = UI.SetBossPortrait(r.face, d, b, r.state == "dead")
            r.faceRing:SetShown(hasFace)
            local nx = 40
            if hasFace then
                r.face:SetSize(FS, FS); r.face:ClearAllPoints(); r.face:SetPoint("LEFT", 38, 0)
                r.faceRing:SetSize(FS + 2, FS + 2); r.faceRing:ClearAllPoints()
                r.faceRing:SetPoint("CENTER", r.face, "CENTER")
                local rc = r.state == "next" and ac or C.border
                r.faceRing:SetVertexColor(rc[1], rc[2], rc[3], 1)
                r.face:SetDesaturated(r.state == "dead")
                nx = 38 + FS + 10
            end
            r.name:ClearAllPoints()
            if RH >= 36 then r.name:SetPoint("TOPLEFT", nx, -(RH - 3 - 28) / 2) else r.name:SetPoint("LEFT", nx, 0) end
            -- butin pour ce perso (5 au plus ; moins quand la liste est étroite : le nom garde 150 px)
            local loot = UI:DungeonLoot(b, "me", c, key)
            local rowW = colW
            local maxIc = math.max(0, math.min(5, math.floor((rowW - nx - 150 - 8) / 27)))
            local nIc = math.min(#loot, maxIc)
            local nameR = nIc > 0 and -(8 + nIc * 27 + 6) or -8
            r.name:SetPoint("RIGHT", r, "RIGHT", nameR, 0)
            r.sub:SetPoint("RIGHT", r, "RIGHT", nameR, 0)
            for k, ic in ipairs(r.icons) do
                local id = k <= maxIc and loot[k] or nil
                ic:SetShown(id ~= nil)
                if id then
                    ic.id = id
                    local _, icon = UI:ItemInfo(id)
                    ic.tex:SetTexture(icon or 134400)
                    local q = UI.DungeonQuality and UI.DungeonQuality(id) or C.border
                    ic.edge:SetColor(q[1], q[2], q[3], 1)
                    ic.tex:SetDesaturated(r.state == "dead")
                end
            end
            r:Paint()
            y = y + RH
        end
        bs.child:SetHeight(math.max(1, listH))
        -- nouveau donjon : le prochain boss en vue
        if self.bsKey ~= d.key then
            self.bsKey = d.key
            local idx = 0
            for i, b in ipairs(bosses) do if nextB and b.id == nextB.id then idx = i end end
            if idx > perCol then idx = idx - perCol end
            bs:SetVerticalScroll(math.max(0, math.min(listH - viewH, (idx - 2) * RH)))
        elseif bs:GetVerticalScroll() > math.max(0, listH - viewH) then
            bs:SetVerticalScroll(math.max(0, listH - viewH))
        end
        bs:UpdateBar()
        -- sans carte, la liste ne prend que sa place ; avec, la hauteur de la carte
        local blockH = math.max(MH, viewH)
        local ty = y0 + blockH + 8
        det.tabs.loot:ClearAllPoints(); det.tabs.loot:SetPoint("TOPLEFT", 0, -ty)
        det.tabLine:ClearAllPoints()
        det.tabLine:SetPoint("TOPLEFT", 0, -(ty + 30)); det.tabLine:SetPoint("TOPRIGHT", 0, -(ty + 30))
        det.allLoot:ClearAllPoints(); det.allLoot:SetPoint("RIGHT", top, "TOPRIGHT", 0, -(ty + 15))
        top:SetHeight(ty + 32)
    end,

    -- onglet Quêtes du détail : état de chaque quête pour le perso, guidage vers le donneur
    RefreshQuests = function(self, d, c, quests, states, ORDER, y, W)
        local det = self.det
        local Q = WK.modules.Quests
        table.sort(quests, function(a, b)
            local sa, sb = ORDER[states[a][1]] or 9, ORDER[states[b][1]] or 9
            if sa ~= sb then return sa < sb end
            return (a.lvl or 0) < (b.lvl or 0)
        end)
        local STATE = {
            done = { "faite", C.dim }, log = { "dans le journal", C.positive }, avail = { "disponible", C.gold },
            high = { "niveau %d requis", C.negative }, locked = { "après : %s", C.tank },
            closed = { "plus proposée", C.dim },
        }
        local qy, shown = 10, 0
        for _, q in ipairs(quests) do
            local st, pre = states[q][1], states[q][2]
            if self.qfilter == "all" or st ~= "done" then
                shown = shown + 1
                local r = self.qrows:Get()
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, -qy); r:SetPoint("TOPRIGHT", -10, -qy)
                local def = STATE[st] or { st, C.muted }
                r.dot:SetVertexColor(unpack(def[2]))
                r.lvl:SetText(tostring(q.lvl or "?"))
                r.name:SetText(Q:Name(q))
                r.name:SetTextColor(unpack(st == "done" and C.dim or C.text))
                local txt
                if st == "high" then txt = string.format(T(def[1]), q.req or 0)
                elseif st == "locked" then txt = string.format(T(def[1]), pre and Q:Name(Q:Get(pre)) or "?")
                else txt = T(def[1]) end
                r.state:SetText(txt)
                r.state:SetTextColor(unpack(def[2]))
                -- guidage : vers le donneur, ou vers celui de la quête à faire avant
                local target = (st == "locked" and pre and Q:Get(pre)) or q
                r.guide.tooltip = (st == "locked") and "Guider vers le donneur de la quête à faire avant" or "Guider vers le donneur"
                r.guide:SetShown(st ~= "done" and target and target.x ~= nil)
                r.guide:SetScript("OnClick", function() Q:GuideTo(target) end)
                qy = qy + 26
            end
        end
        local msg = ""
        if #quests == 0 then msg = T("Pas de quête de donjon connue pour ce perso.")
        elseif shown == 0 then msg = T("Toutes les quêtes du donjon sont faites par ce perso (« Toutes » pour les revoir).") end
        if msg ~= "" then
            self.none:Show()
            self.none:ClearAllPoints(); self.none:SetPoint("TOPLEFT", 16, -14)
            self.none:SetText(msg)
            qy = 40
        end
        local bottom = qy + 4
        self:PlaceButtons(d)
        local h = bottom + 8
        det:SetHeight(h)
        self.sc:SetContentHeight(y + h + 10)
    end,
})
