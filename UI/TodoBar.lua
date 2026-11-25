local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Mini-fenêtre « À faire » (maquette B) : une barre de pastilles à l'écran, sans ouvrir la fenêtre principale.
-- Mêmes tâches que « À faire » du Résumé et du bandeau de connexion (UI.TodoItems), une pastille par groupe
-- (icône de l'addon + nombre), plus l'objectif le plus proche du perso connecté (Modules/CharGoals.lua).
-- Survol d'une pastille : le détail du côté des rangées (dessous ou dessus) ; clic : l'action de la 1re
-- tâche (sa page). Placée en mode
-- édition (HUD « todoBar ») ; réglages : carte « Mini-fenêtre « À faire » » (QoL > Général > Alertes) :
-- settings.ui.todoBar (affichée, vrai par défaut) et settings.ui.todo (Cfg ci-dessous : genres, perso, titre,
-- libellés, taille, largeur fixe, sens d'empilement, fond, nombre de pastilles, cachée quand vide).
local PAD = 8
local bar

-- Genres de pastilles (champ « kind » des tâches de UI.TodoItems ; « goal » = objectif le plus proche)
UI.TODO_KINDS = {
    { "goal", "Objectif le plus proche" }, { "letters", "Courrier à récupérer" }, { "cap", "Métier au plafond" },
    { "cd", "Recharges de métier prêtes" }, { "spells", "Sorts à apprendre" }, { "levelup", "Quêtes à rendre" },
    { "rest", "Repos plein" }, { "send", "Objets à envoyer" }, { "deposit", "Objets à déposer" },
    { "bankold", "Banque pas vue" }, { "bankfull", "Banque pleine" }, { "bags", "Sacs pleins" },
    { "durability", "Réparation" }, { "reagent", "Composants de classe" }, { "ammo", "Munitions" },
    { "pet", "Familier" }, { "poison", "Poisons" }, { "autoloot", "Butin automatique du jeu" },
    { "ahscan", "Scan de l'HV" }, { "shop", "Liste de courses" }, { "farm", "Farm en pause" }, { "other", "Autres" },
}
local KNOWN = {}
for _, k in ipairs(UI.TODO_KINDS) do KNOWN[k[1]] = true end
local SIZES = { s = 20, m = 26, l = 32 }

-- width = largeur fixe (px) ; grow = down (rangées ajoutées dessous, infobulle dessous) / up (dessus)
local DEFAULTS = { scope = "all", labels = false, hideEmpty = false, size = "m", width = 360, grow = "down",
    bg = true, max = 0, hoverFull = true, tips = true, click = true, hideCombat = false }
UI.TODO_W_MIN, UI.TODO_W_MAX = 120, 800
function UI.TodoConfig()
    local s = WK.DB.global.settings.ui
    s.todo = s.todo or {}
    local c = s.todo
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.off = c.off or {}
    return c
end
local function cfgOn()
    local s = WK.DB.global.settings.ui
    return s.todoBar ~= false and WK:PageOn("overview")
end
local function kindOf(it)
    local k = it.kind
    return (k and KNOWN[k]) and k or "other"
end

-- Pastilles : une par groupe de tâches ({ gicon, color, n, lines, go }), dans l'ordre d'urgence
local function pills(items, cfg)
    local out, by = {}, {}
    local me = WK:CharKey()
    for _, it in ipairs(items) do
        local kind = kindOf(it)
        local skip = cfg and (cfg.off[kind] or (cfg.scope == "me" and it.who and it.who ~= me))
        if skip then it = nil end
        if it then
        local key = it.group or it.gicon or it.icon or it.text
        local p = by[key]
        if not p then
            p = { gicon = it.gicon or (UI.MEDIA .. (it.icon or "bang")), color = it.color, n = 0, lines = {},
                go = it.go, short = it.short }
            by[key] = p
            out[#out + 1] = p
        end
        p.n = p.n + math.max(1, it.n or 1)
        if it.color == C.negative or (it.color and not p.color) then p.color = it.color end
        local who = it.who and WK.DB.global.characters[it.who]
        p.lines[#p.lines + 1] = { it.text, who and WK:CharName(who, it.who), who and who.class }
        end
    end
    return out
end
UI.TodoPills = pills -- (tests)

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperTodoBar", UIParent)
    f:SetHeight(36)
    f:SetPoint("TOPRIGHT", -260, -200)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:HudBackground(f, "hud", 12)
    -- plus de titre « À faire » (retiré à la demande du joueur)
    f.empty = UI:Text(f, 11, C.muted)
    f.empty:SetText(T("rien à faire"))
    f.pool = UI:Pool(function()
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(26)
        -- liseré (sans fond de barre seulement) sous le fond de la pastille, lui 1 px plus petit
        b.edge = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
        b.bg = UI:Rounded(b, 10, 1, "BACKGROUND", 2)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 8, 0)
        b.n = UI:Text(b, 12)
        b.n:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b:SetScript("OnClick", function(s)
            if s.go and UI.TodoConfig().click then UI:Create():Show(); UI:ShowPage("overview"); s.go() end
        end)
        b:SetScript("OnEnter", function(s)
            local col = s.color or { UI:Accent() }
            local hv = s.hoverCol or { col[1], col[2], col[3], 0.32 }
            s.bg:SetColor(hv[1], hv[2], hv[3], hv[4])
            if not UI.TodoConfig().tips then return end
            UI:TooltipOwner(s, UI.TodoConfig().grow == "up" and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
            local tip = GameTooltip
            for i, l in ipairs(s.lines or {}) do
                if i > 10 then tip:AddLine(string.format(T("+ %d autres"), #s.lines - 10), 0.6, 0.6, 0.6) break end
                if i == 1 then tip:SetText(l[1], 1, 1, 1, 1, true) else tip:AddLine(l[1], 0.85, 0.85, 0.85, true) end
                if l[2] then
                    local r, g, bl = UI:ClassColor(l[3])
                    tip:AddLine("   " .. l[2], r, g, bl)
                end
            end
            if s.go and UI.TodoConfig().click then
                tip:AddLine(" "); tip:AddLine(T("Clic : ouvrir la page"), 0.6, 0.6, 0.6)
            end
            tip:Show()
        end)
        b:SetScript("OnLeave", function(s)
            local col = s.color or { UI:Accent() }
            local bc = s.baseCol or { col[1], col[2], col[3], 0.18 }
            s.bg:SetColor(bc[1], bc[2], bc[3], bc[4])
            GameTooltip:Hide()
        end)
        return b
    end)
    -- rafraîchie toutes les 5 s par une minuterie à part (la barre cachée quand vide doit pouvoir revenir)
    f:Hide()
    return f
end

-- Largeur fixe (réglage) ; les pastilles passent à la ligne. Rangées empilées dessous (grow = down, cadre
-- placé par son haut) ou dessus (up, placé par son bas : la 1re rangée, la plus urgente, reste en bas).
local function barPaint(f, list)
    local cfg = UI.TodoConfig()
    local h = SIZES[cfg.size] or 26
    local fs = h >= 32 and 14 or (h <= 20 and 10 or 12)
    local W = math.max(UI.TODO_W_MIN, math.min(UI.TODO_W_MAX, cfg.width or 360))
    local up = cfg.grow == "up"
    f.pool:Reset()
    f.empty:ClearAllPoints()
    -- fond : graphite (réglage) ou rien
    if f.bg then f.bg:SetShown(cfg.bg and true or false) end
    if f.border then f.border:SetShown(cfg.bg and true or false) end
    if f.edge then f.edge:SetShown(cfg.bg and true or false) end
    local max = (cfg.max or 0) > 0 and cfg.max or #list
    local inner = W - 2 * PAD
    -- 1) largeurs naturelles, 2) rangées, 3) chaque rangée remplit toute la largeur (place en trop partagée
    -- entre ses pastilles, contenu centré)
    local items = {}
    local shown = 0
    for _, p in ipairs(list) do
        if shown >= max then break end
        shown = shown + 1
        local b = f.pool:Get()
        b:SetHeight(h)
        b.icon:SetSize(h - 10, h - 10)
        b.icon:SetTexture(p.gicon)
        local col = p.color or { UI:Accent() }
        b.icon:SetVertexColor(col[1], col[2], col[3], 1)
        -- sans fond de barre : pastille opaque (graphite teinté de sa couleur) + liseré de sa couleur, pour
        -- rester lisible sur n'importe quel décor ; avec fond : teinte légère comme avant
        if cfg.bg then
            b.baseCol, b.hoverCol = { col[1], col[2], col[3], 0.18 }, { col[1], col[2], col[3], 0.32 }
            b.edge:Hide()
        else
            local d = C.bg
            local function mix(k, a) return { d[1] + (col[1] - d[1]) * k, d[2] + (col[2] - d[2]) * k,
                d[3] + (col[3] - d[3]) * k, a } end
            b.baseCol, b.hoverCol = mix(0.22, 0.94), mix(0.4, 0.97)
            b.edge:SetColor(col[1], col[2], col[3], 0.85)
            b.edge:Show()
        end
        b.bg:SetColor(b.baseCol[1], b.baseCol[2], b.baseCol[3], b.baseCol[4])
        local txt = p.label or tostring(p.n)
        if cfg.labels and p.short and not p.label then txt = p.n .. " " .. p.short end
        b.n:SetFont(UI.FONT, fs, "")
        b.n:SetText(txt)
        b.n:SetTextColor(unpack(C.text))
        b.color, b.lines, b.go = p.color, p.lines, p.go
        items[#items + 1] = { r = b, w = math.min(inner, 8 + (h - 10) + 5 + b.n:GetStringWidth() + 10), pill = true }
    end
    f.empty:SetShown(shown == 0)
    if shown == 0 then
        f.empty:SetHeight(h)
        items[1] = { r = f.empty, w = f.empty:GetStringWidth() }
    end
    local rows, cur, used = {}, {}, 0
    for _, it in ipairs(items) do
        if #cur > 0 and used + 6 + it.w > inner then rows[#rows + 1] = cur; cur, used = {}, 0 end
        used = used + (#cur > 0 and 6 or 0) + it.w
        cur[#cur + 1] = it
    end
    if #cur > 0 then rows[#rows + 1] = cur end
    for ri, rw in ipairs(rows) do
        local sum = 0
        for _, it in ipairs(rw) do sum = sum + it.w end
        local extra = rw[1].pill and math.max(0, inner - sum - 6 * (#rw - 1)) / #rw or 0
        local x, y = 0, PAD + (ri - 1) * (h + 4)
        for _, it in ipairs(rw) do
            local w = it.w + extra
            local r = it.r
            if it.pill then
                r:SetWidth(w)
                r.icon:ClearAllPoints()
                r.icon:SetPoint("LEFT", r, "LEFT", 8 + extra / 2, 0)
            end
            r:ClearAllPoints()
            if up then r:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + x, y)
            else r:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + x, -y) end
            x = x + w + 6
        end
    end
    local row = math.max(1, #rows)
    f:SetSize(W, 2 * PAD + row * h + (row - 1) * 4)
    return shown
end

-- objectif le plus proche du perso connecté, en pastille (Modules/CharGoals.lua)
local function goalPill()
    local G = WK.modules.CharGoals
    if not (G and G.Nearest) then return nil end
    local ok, g = pcall(G.Nearest, G, WK:CharKey())
    if not ok or not g then return nil end
    local pct = math.floor((g.pct or 0) * 100 + 0.5)
    return { gicon = UI.MEDIA .. "star", color = C.positive, n = 1, label = pct .. " %", short = T("objectif"),
        lines = { { g.title .. "  ·  " .. pct .. " %" }, { g.eta or "" } },
        go = function() if WK:PageOn("characters") then UI:ShowPage("characters") end end }
end

function UI.RefreshTodoBar(_)
    if not bar then bar = build() end
    if bar.sample then return end
    if not cfgOn() then bar:Hide() return end
    local cfg = UI.TodoConfig()
    local items = UI.TodoItems and UI.TodoItems() or {}
    local list = pills(items, cfg)
    local gp = not cfg.off.goal and goalPill()
    if gp then table.insert(list, 1, gp) end
    local shown = barPaint(bar, list)
    -- pleine au survol (registre commun du mode édition) : réglage de la barre
    bar.hudNoHoverFull = not cfg.hoverFull or nil
    local fight = cfg.hideCombat and InCombatLockdown and InCombatLockdown()
    bar:SetShown(not (cfg.hideEmpty and shown == 0) and not fight)
end

local SAMPLE = function()
    local G = UI.MEDIA
    return {
        { gicon = G .. "star", color = C.positive, n = 1, label = "72 %", lines = { { T("Niveau 40") } } },
        { gicon = G .. "bang", color = C.negative, n = 1, lines = { { T("Butin automatique du jeu activé") } } },
        { gicon = G .. "mail", n = 2, lines = { { T("2 lettres à récupérer") } } },
        { gicon = G .. "book", color = C.warning, n = 1, lines = { { T("Métier au plafond") } } },
    }
end

WK:On("PLAYER_LOGIN", function()
    bar = bar or build()
    -- placée par son haut (rangées dessous) ou son bas (rangées dessus) : l'autre bord bouge avec les rangées
    local tc = UI.TodoConfig()
    if not tc.anchorV2 then
        -- ancienne place notée pour le coin haut droit : recalée sur le milieu du haut (largeur fixe)
        tc.anchorV2 = true
        local e = UI:HUDEntry("todoBar")
        if e.x then e.x = e.x - (tc.width or 360) * (e.scale or 1) / 2 end
    end
    UI:RegisterHUD("todoBar", bar, {
        label = T("Mini-fenêtre « À faire »"), default = { -440, -200 },
        dynamicPoint = function() return UI.TodoConfig().grow == "up" and "BOTTOM" or "TOP" end,
        enabled = cfgOn,
        sample = function(on)
            bar.sample = on or nil
            if on then barPaint(bar, SAMPLE()); bar:Show() else UI:RefreshTodoBar() end
        end,
    })
    C_Timer.After(6, function() UI:RefreshTodoBar() end)
    if C_Timer.NewTicker then
        C_Timer.NewTicker(5, function() if bar and not bar.sample and not bar.soon then UI:RefreshTodoBar() end end)
    end
end)
WK:On("BAG_UPDATE_DELAYED", function()
    if bar and not bar.soon then
        bar.soon = true
        C_Timer.After(1, function() bar.soon = nil; UI:RefreshTodoBar() end)
    end
end)
-- cacher en combat (réglage) : à l'entrée et à la sortie du combat
WK:On("PLAYER_REGEN_DISABLED", function()
    if bar and not bar.sample and UI.TodoConfig().hideCombat then bar:Hide() end
end)
WK:On("PLAYER_REGEN_ENABLED", function() if bar then UI:RefreshTodoBar() end end)
