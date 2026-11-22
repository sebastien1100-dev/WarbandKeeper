local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Rappels à la connexion : un bandeau en haut de l'écran avec les tâches du moment (les mêmes que
-- « À faire » du Résumé, UI.TodoItems), rangées une ligne par perso : son nom à la couleur de sa classe,
-- puis ses pastilles (icône de l'addon + libellé court), qui passent à la ligne si besoin.
-- Survol d'une pastille : le détail ; clic : sa page. Survol du bandeau : le temps s'arrête. Une barre en
-- haut se vide jusqu'à la fermeture : settings.ui.loginPopupTime secondes (5 par défaut, 0 : reste ouvert).
-- Seulement à une vraie connexion (pas après un /reload), s'il y a quelque chose à faire ; désactivable
-- dans Options > Général.
local MAX_CHARS = 6
local W, HEAD_H, ICON, PILL_H, NAME_W, PAD = 580, 40, 28, 32, 112, 16
local popup

-- Icône de l'addon (enveloppe, coffre-fort…) dans une tuile arrondie : cadre et icône à la couleur de
-- l'urgence (rouge, orange), sinon icône à la couleur de l'apparence
local function gameIcon(parent, size)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(size + 2, size + 2)
    box.edge = UI:Rounded(box, 8, 0, "BACKGROUND", 1)
    box.bg = UI:Rounded(box, 7, 1, "BACKGROUND", 2)
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetPoint("CENTER")
    box.icon:SetSize(size * 0.68, size * 0.68)
    function box:Set(tex, col)
        self.icon:SetTexture(tex or (UI.MEDIA .. "bang"))
        self.edge:SetColor(unpack(col or C.border))
        self.bg:SetColor(unpack(C.surface2))
        if col then self.icon:SetVertexColor(unpack(col)) else self.icon:SetVertexColor(UI:Accent()) end
    end
    return box
end

local function openItem(go)
    UI:Create():Show()
    UI:ShowPage("overview")
    if go then go() end
    if popup then popup:Hide() end
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperLoginPopup", UIParent)
    f:SetSize(W, HEAD_H)
    f:SetPoint("TOP", 0, -64) -- remplacé par la position du mode édition
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 14, C.bg, C.border)
    -- barre de temps, en haut
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetHeight(3)
    f.track:SetPoint("TOPLEFT", 14, -1)
    f.track:SetPoint("TOPRIGHT", -14, -1)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetHeight(3)
    f.fill:SetPoint("TOPLEFT", f.track, "TOPLEFT")
    -- en-tête : logo, titre, ouvrir, fermer
    f.logo = UI:Icon(f, "logo", 20)
    f.logo:SetPoint("TOPLEFT", PAD, -(HEAD_H - 20) / 2)
    f.title = UI:Text(f, 13)
    f.title:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 8, -3)
    f.title:SetText(T("À faire sur le compte"))
    f.close = UI:IconButton(f, "close", 24, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -10, -(HEAD_H - 24) / 2)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.open = UI:IconButton(f, "arrow", 24, "Ouvrir Warband Keeper")
    f.open:SetPoint("TOPRIGHT", f.close, "TOPLEFT", -2, 0)
    f.open:SetScript("OnClick", function() UI:ToggleWindow("overview"); f:Hide() end)
    -- lignes des persos : séparateur + nom
    f.charRows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, f)
        r.sep = r:CreateTexture(nil, "ARTWORK")
        r.sep:SetHeight(1)
        r.sep:SetPoint("TOPLEFT"); r.sep:SetPoint("TOPRIGHT")
        r.name = UI:Text(r, 13)
        r.name:SetWidth(NAME_W - 8)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        return r
    end)
    f.pills = UI:Pool(function()
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(PILL_H)
        b.hl = UI:Rounded(b, 8, 0, "BACKGROUND", 0)
        b.ic = gameIcon(b, ICON)
        b.ic:SetPoint("TOPLEFT", 1, -1)
        b.text = UI:Text(b, 13)
        b.text:SetPoint("TOPLEFT", b.ic, "TOPRIGHT", 6, -8)
        b:SetScript("OnClick", function(s) openItem(s.go) end)
        b:SetScript("OnEnter", function(s)
            s.hl:SetColor(unpack(C.hover))
            UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            for i, line in ipairs(s.lines or {}) do
                if i == 1 then GameTooltip:SetText(line, 1, 1, 1, 1, true) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(s) s.hl:SetColor(unpack(C.surface)); GameTooltip:Hide() end)
        return b
    end)
    f.hint = UI:Text(f, 10, C.dim)
    -- temps : s'écoule hors de la souris ; survol = pause ; fondu sur la dernière demi-seconde
    f:SetScript("OnUpdate", function(s, elapsed)
        local over = s:IsMouseOver(6, -6, -6, 6)
        local r1, g1, b1 = UI:Accent()
        if s.total and s.total > 0 then
            if not over then s.remain = s.remain - elapsed end
            if s.remain <= 0 then s.remain = nil; s.total = nil; s:Hide(); s:SetAlpha(1) return end
            local w = s.track:GetWidth() or 0
            s.fill:SetWidth(math.max(0.01, w * s.remain / s.total))
            if over then s.fill:SetColorTexture(C.dim[1], C.dim[2], C.dim[3], 1) else s.fill:SetColorTexture(r1, g1, b1, 1) end
            s:SetAlpha(over and 1 or math.min(1, s.remain / 0.5))
        end
    end)
    f:Hide() -- créé à la connexion (mode édition) : caché jusqu'aux rappels
    return f
end

-- Pastilles d'un perso : une par tâche, une seule par groupe (lettres, objets à envoyer…)
local function pillsOf(items)
    local out, byGroup = {}, {}
    for _, it in ipairs(items) do
        local p = it.group and byGroup[it.group]
        if not p then
            p = { gicon = it.gicon, short = it.short, n = 0, color = it.color, go = it.go, lines = {} }
            table.insert(out, p)
            if it.group then byGroup[it.group] = p end
        end
        p.n = p.n + (it.n or 0)
        if it.color == C.negative or (it.color and not p.color) then p.color = it.color end
        table.insert(p.lines, it.text)
    end
    return out
end

-- Tâches rangées par perso : le perso connecté d'abord, puis les autres par urgence (liste déjà triée)
local function byChar(items, meKey)
    local order, of = {}, {}
    for _, it in ipairs(items) do
        local k = it.who or meKey
        if not of[k] then
            of[k] = {}
            if k == meKey then table.insert(order, 1, k) else table.insert(order, k) end
        end
        table.insert(of[k], it)
    end
    return order, of
end
UI.LoginByChar = byChar -- pour les tests

function UI:ShowLoginPopup(force, sample)
    local items = UI.TodoItems and UI.TodoItems() or {}
    if #items == 0 and not force then return end
    popup = popup or build()
    local f = popup
    local _, meKey = WK.DB:Me()
    local chars = WK.DB.global.characters
    f.logo:SetVertexColor(UI:Accent())
    f.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
    f.charRows:Reset()
    f.pills:Reset()
    local order, of = byChar(items, meKey)
    local y = -HEAD_H
    local x0, xMax = PAD + NAME_W, W - PAD
    local function pill(p, x, rowY)
        local b = f.pills:Get()
        b.ic:Set(p.gicon, p.color)
        local label = p.short or (p.n > 0 and tostring(p.n)) or ""
        if p.short and p.n > 1 then label = p.n .. " " .. p.short end
        b.text:SetText(label)
        b.text:SetTextColor(unpack(p.color or C.text))
        b.hl:SetColor(unpack(C.surface))
        b.lines, b.go = p.lines, p.go
        b:SetWidth(ICON + 2 + (label ~= "" and (6 + b.text:GetStringWidth() + 8) or 0))
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", f, "TOPLEFT", x, rowY)
        return b:GetWidth()
    end
    local shown = 0
    for _, k in ipairs(order) do
        if shown >= MAX_CHARS then break end
        shown = shown + 1
        local c = chars[k]
        local r = f.charRows:Get()
        r.sep:SetColorTexture(unpack(C.border))
        r.name:SetWidth(NAME_W - 8)
        r.name:SetText(c and WK:CharName(c, k) or k)
        r.name:SetTextColor(UI:ClassColor(c and c.class))
        -- pastilles, à la ligne quand elles dépassent
        local x, lineY, lines = x0, y - 8, 1
        for _, p in ipairs(pillsOf(of[k])) do
            local w = ICON + 60
            if x > x0 and x + w > xMax then x, lineY, lines = x0, lineY - PILL_H - 6, lines + 1 end
            x = x + pill(p, x, lineY) + 8
        end
        local h = 16 + lines * PILL_H + (lines - 1) * 6
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y); r:SetSize(W - 2 * PAD, h)
        r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 0, -(8 + PILL_H / 2 - 7))
        y = y - h
    end
    if #order == 0 then
        local r = f.charRows:Get()
        r.sep:SetColorTexture(unpack(C.border))
        r.name:SetText(T("Rien à faire : tout est à jour."))
        r.name:SetTextColor(unpack(C.muted))
        r.name:SetWidth(W - 2 * PAD)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y); r:SetSize(W - 2 * PAD, 40)
        r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 0, -13)
        y = y - 40
    end
    -- temps
    local secs = WK.DB.global.settings.ui.loginPopupTime
    if secs == nil then secs = 5 end
    f.total = (secs > 0 and not sample) and secs or nil
    f.remain = f.total
    f.track:SetShown(f.total ~= nil)
    f.fill:SetShown(f.total ~= nil)
    f.fill:SetWidth(1)
    local more = #order - shown
    f.hint:SetText((more > 0 and (string.format(T("+ %d autre(s) dans le Résumé"), more) .. "  ·  ") or "")
        .. (f.total and T("En pause tant que la souris est dessus · Options > Général")
            or T("Désactivable dans Options > Général")))
    f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", PAD, y - 6)
    f:SetHeight(-y + 26)
    f:SetAlpha(1)
    f:Show()
end

-- Placé en mode édition (aperçu sans minuterie) ; « Tester » le joue comme à la connexion
local function register()
    popup = popup or build()
    UI:RegisterHUD("loginPopup", popup, {
        label = T("Bandeau de connexion"), point = "TOP", default = { 0, UIParent:GetHeight() / 2 - 64 },
        enabled = function() return WK.DB.global.settings.ui.loginPopup ~= false end,
        sample = function(on) if on then UI:ShowLoginPopup(true, true) elseif popup then popup:Hide() end end,
        test = function() UI:ShowLoginPopup(true) end,
        testStop = function() if popup then popup:Hide() end end,
    })
end
WK:On("PLAYER_LOGIN", register)

WK:On("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReload)
    if not isInitialLogin or isReload then return end
    if WK.DB.global.settings.ui.loginPopup == false then return end
    -- Laisser le temps aux scans (sacs, courrier connu, métiers) de se faire
    C_Timer.After(5, function() UI:ShowLoginPopup() end)
end)
