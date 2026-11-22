local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Mini-fenêtre « À faire » (maquette B) : une barre de pastilles à l'écran, sans ouvrir la fenêtre principale.
-- Mêmes tâches que « À faire » du Résumé et du bandeau de connexion (UI.TodoItems), une pastille par groupe
-- (icône de l'addon + nombre), plus l'objectif le plus proche du perso connecté (Modules/CharGoals.lua).
-- Survol d'une pastille : le détail en dessous ; clic : l'action de la 1re tâche (sa page). Placée en mode
-- édition (HUD « todoBar ») ; réglage settings.ui.todoBar (Options > Rappels à la connexion), vrai par défaut.
local ICON, PILL_H, PAD = 20, 26, 8
local bar

local function cfgOn()
    local s = WK.DB.global.settings.ui
    return s.todoBar ~= false and WK:PageOn("overview")
end

-- Pastilles : une par groupe de tâches ({ gicon, color, n, lines, go }), dans l'ordre d'urgence
local function pills(items)
    local out, by = {}, {}
    for _, it in ipairs(items) do
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
    return out
end
UI.TodoPills = pills -- (tests)

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperTodoBar", UIParent)
    f:SetHeight(PILL_H + 2 * 5)
    f:SetPoint("TOPRIGHT", -260, -200)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:HudBackground(f, "hud", (PILL_H + 10) / 2)
    f.title = UI:Text(f, 12)
    f.title:SetPoint("LEFT", 12, 0)
    f.title:SetText(T("À faire"))
    f.empty = UI:Text(f, 11, C.muted)
    f.empty:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
    f.empty:SetText(T("rien à faire"))
    f.pool = UI:Pool(function()
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(PILL_H)
        b.bg = UI:Rounded(b, PILL_H / 2, 0, "BACKGROUND", 2)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(ICON - 4, ICON - 4)
        b.icon:SetPoint("LEFT", 8, 0)
        b.n = UI:Text(b, 12)
        b.n:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        b:SetScript("OnClick", function(s)
            if s.go then UI:Create():Show(); UI:ShowPage("overview"); s.go() end
        end)
        b:SetScript("OnEnter", function(s)
            local col = s.color or { UI:Accent() }
            s.bg:SetColor(col[1], col[2], col[3], 0.32)
            UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            local tip = GameTooltip
            for i, l in ipairs(s.lines or {}) do
                if i > 10 then tip:AddLine(string.format(T("+ %d autres"), #s.lines - 10), 0.6, 0.6, 0.6) break end
                if i == 1 then tip:SetText(l[1], 1, 1, 1, 1, true) else tip:AddLine(l[1], 0.85, 0.85, 0.85, true) end
                if l[2] then
                    local r, g, bl = UI:ClassColor(l[3])
                    tip:AddLine("   " .. l[2], r, g, bl)
                end
            end
            if s.go then tip:AddLine(" "); tip:AddLine(T("Clic : ouvrir la page"), 0.6, 0.6, 0.6) end
            tip:Show()
        end)
        b:SetScript("OnLeave", function(s)
            local col = s.color or { UI:Accent() }
            s.bg:SetColor(col[1], col[2], col[3], 0.18)
            GameTooltip:Hide()
        end)
        return b
    end)
    -- clic sur le titre : la fenêtre sur le Résumé
    f:SetScript("OnMouseUp", function(s, button)
        if button == "LeftButton" and s.title:IsMouseOver() then UI:Create():Show(); UI:ShowPage("overview") end
    end)
    f.acc = 0
    f:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 5 then return end
        s.acc = 0
        if not s.sample then UI:RefreshTodoBar() end
    end)
    f:Hide()
    return f
end

local function barPaint(f, list)
    f.pool:Reset()
    local x = 12 + f.title:GetStringWidth() + 10
    for _, p in ipairs(list) do
        local b = f.pool:Get()
        b.icon:SetTexture(p.gicon)
        local col = p.color or { UI:Accent() }
        b.icon:SetVertexColor(col[1], col[2], col[3], 1)
        b.bg:SetColor(col[1], col[2], col[3], 0.18)
        b.n:SetText(p.label or tostring(p.n))
        b.n:SetTextColor(unpack(C.text))
        b.color, b.lines, b.go = p.color, p.lines, p.go
        b:SetWidth(8 + ICON - 4 + 5 + b.n:GetStringWidth() + 10)
        b:ClearAllPoints(); b:SetPoint("LEFT", f, "LEFT", x, 0)
        x = x + b:GetWidth() + 6
    end
    f.empty:SetShown(#list == 0)
    if #list == 0 then x = x + f.empty:GetStringWidth() + 4 end
    f:SetWidth(x + PAD)
end

-- objectif le plus proche du perso connecté, en pastille (Modules/CharGoals.lua)
local function goalPill()
    local G = WK.modules.CharGoals
    if not (G and G.Nearest) then return nil end
    local ok, g = pcall(G.Nearest, G, WK:CharKey())
    if not ok or not g then return nil end
    local pct = math.floor((g.pct or 0) * 100 + 0.5)
    return { gicon = UI.MEDIA .. "star", color = C.positive, n = 1, label = pct .. " %",
        lines = { { g.title .. "  ·  " .. pct .. " %" }, { g.eta or "" } },
        go = function() if WK:PageOn("characters") then UI:ShowPage("characters") end end }
end

function UI.RefreshTodoBar(_)
    if not bar then bar = build() end
    if bar.sample then return end
    if not cfgOn() then bar:Hide() return end
    local items = UI.TodoItems and UI.TodoItems() or {}
    local list = pills(items)
    local gp = goalPill()
    if gp then table.insert(list, 1, gp) end
    barPaint(bar, list)
    bar:Show()
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
    UI:RegisterHUD("todoBar", bar, {
        label = T("Mini-fenêtre « À faire »"), point = "TOPRIGHT", default = { -260, -200 },
        enabled = cfgOn,
        sample = function(on)
            bar.sample = on or nil
            if on then barPaint(bar, SAMPLE()); bar:Show() else UI:RefreshTodoBar() end
        end,
    })
    C_Timer.After(6, function() UI:RefreshTodoBar() end)
end)
WK:On("BAG_UPDATE_DELAYED", function() if bar and bar:IsShown() then bar.acc = 4 end end)
