local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Rappels à la connexion : un bandeau en haut de l'écran, une pastille par tâche du moment (les mêmes
-- que « À faire » du Résumé, UI.TodoItems), avec l'icône du jeu qui va avec (lettre, coffre, montre…).
-- Survol : il se déplie en liste (chaque ligne ouvre sa page) et le temps s'arrête. Une barre en haut se
-- vide jusqu'à la fermeture : settings.ui.loginPopupTime secondes (5 par défaut, 0 : reste ouvert).
-- Seulement à une vraie connexion (pas après un /reload), s'il y a quelque chose à faire ; désactivable
-- dans Options > Général.
local MAX_ROWS, MAX_PILLS = 8, 7
local HEAD_H, ROW_H, ICON = 54, 40, 30
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
    box.icon:SetSize(size * 0.62, size * 0.62)
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
    f:SetSize(420, HEAD_H)
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
    -- ligne du haut : logo, nom du perso, pastilles, ouvrir, fermer
    f.logo = UI:Icon(f, "logo", 22)
    f.logo:SetPoint("LEFT", f, "TOPLEFT", 16, -HEAD_H / 2)
    f.name = UI:Text(f, 13)
    f.name:SetPoint("LEFT", f.logo, "RIGHT", 9, 0)
    f.sep = f:CreateTexture(nil, "ARTWORK")
    f.sep:SetSize(1, 26)
    f.close = UI:IconButton(f, "close", 24, nil, "accent")
    f.close:SetPoint("RIGHT", f, "TOPRIGHT", -10, -HEAD_H / 2)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.open = UI:IconButton(f, "arrow", 24, "Ouvrir Warband Keeper")
    f.open:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
    f.open:SetScript("OnClick", function() UI:ToggleWindow("overview"); f:Hide() end)
    f.pills = UI:Pool(function()
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(36)
        b.ic = gameIcon(b, ICON)
        b.ic:SetPoint("LEFT", 0, 0)
        b.text = UI:Text(b, 14)
        b.text:SetPoint("LEFT", b.ic, "RIGHT", 6, 0)
        b:SetScript("OnClick", function(s) openItem(s.go) end)
        b:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            for i, line in ipairs(s.lines or {}) do
                if i == 1 then GameTooltip:SetText(line, 1, 1, 1, 1, true) else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end)
    f.more = UI:Text(f, 12, C.muted)
    -- liste dépliée (au survol)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("TOPLEFT", 14, -HEAD_H)
    f.line:SetPoint("TOPRIGHT", -14, -HEAD_H)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(ROW_H)
        r.hl = CreateFrame("Frame", nil, r)
        r.hl:SetAllPoints()
        UI:Rounded(r.hl, 8, 0, "BACKGROUND", 2):SetColor(unpack(C.hover))
        r.hl:Hide()
        r.ic = gameIcon(r, 28)
        r.ic:SetPoint("LEFT", 8, 0)
        r.text = UI:Text(r, 12)
        r.text:SetPoint("LEFT", 48, 0)
        r.text:SetPoint("RIGHT", -28, 0)
        r.text:SetJustifyH("LEFT")
        r.go2 = UI:Icon(r, "chevron", 12, nil, "ARTWORK")
        r.go2:SetPoint("RIGHT", -10, 0)
        r.go2:SetRotation(math.pi / 2)
        r:SetScript("OnEnter", function(s) s.hl:Show() end)
        r:SetScript("OnLeave", function(s) s.hl:Hide() end)
        r:SetScript("OnClick", function(s) openItem(s.go) end)
        return r
    end)
    f.hint = UI:Text(f, 10, C.dim)
    f.hint:SetText(T("Désactivable dans Options > Général"))
    -- temps : s'écoule hors de la souris ; survol = liste dépliée et pause ; fondu sur la dernière demi-seconde
    f:SetScript("OnUpdate", function(s, elapsed)
        local over = s:IsMouseOver(6, -6, -6, 6)
        if over then s.outFor = 0 else s.outFor = (s.outFor or 0) + elapsed end
        local want = over or (s.expanded and s.outFor < 0.35)
        if want ~= s.expanded then s.expanded = want; s:Layout() end
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
    f:SetScript("OnHide", function(s) s.expanded = false end)

    -- Place les lignes et la taille selon l'état (replié : une ligne ; déplié : la liste)
    function f:Layout()
        local n = 0
        for i, r in ipairs(self.rowList or {}) do r:SetShown(self.expanded); n = i end
        self.line:SetShown(self.expanded and n > 0)
        self.hint:SetShown(self.expanded)
        local h = HEAD_H
        if self.expanded then
            h = HEAD_H + 6 + n * ROW_H + (self.extra and 18 or 0) + 26
            self.hint:ClearAllPoints(); self.hint:SetPoint("BOTTOMLEFT", 16, 10)
            self.hint:SetText(self.extra or (self.total and T("En pause tant que la souris est dessus · Options > Général") or T("Désactivable dans Options > Général")))
        end
        self:SetHeight(h)
    end
    return f
end

-- Pastilles : une par tâche, une seule par groupe (lettres de tous les persos, objets à envoyer…)
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

function UI:ShowLoginPopup(force, sample)
    local items = UI.TodoItems and UI.TodoItems() or {}
    if #items == 0 and not force then return end
    popup = popup or build()
    local f = popup
    local me, meKey = WK.DB:Me()
    local r1, g1, b1 = UI:Accent()
    f.logo:SetVertexColor(r1, g1, b1)
    f.name:SetText(WK:CharName(me, meKey))
    f.name:SetTextColor(UI:ClassColor(me and me.class))
    f.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
    f.sep:SetColorTexture(unpack(C.border))
    f.line:SetColorTexture(unpack(C.border))
    -- pastilles
    f.pills:Reset()
    local x = 16 + 22 + 9 + f.name:GetStringWidth() + 12
    f.sep:ClearAllPoints(); f.sep:SetPoint("LEFT", f, "TOPLEFT", x, -HEAD_H / 2)
    x = x + 13
    local pills = pillsOf(items)
    if #pills == 0 then
        local b = f.pills:Get()
        b.ic:Set(UI.MEDIA .. "notes", nil)
        b.text:SetText(T("Rien à faire : tout est à jour."))
        b.text:SetTextColor(unpack(C.muted))
        b.lines, b.go = nil, nil
        b:SetWidth(ICON + 8 + b.text:GetStringWidth())
        b:ClearAllPoints(); b:SetPoint("LEFT", f, "TOPLEFT", x, -HEAD_H / 2)
        x = x + b:GetWidth() + 14
    end
    for i, p in ipairs(pills) do
        if i > MAX_PILLS then break end
        local b = f.pills:Get()
        b.ic:Set(p.gicon, p.color or C.border)
        local label = p.short or (p.n > 0 and tostring(p.n)) or ""
        if p.short and p.n > 1 then label = p.n .. " " .. p.short end
        b.text:SetText(label)
        b.text:SetTextColor(unpack(p.color or C.text))
        b.lines, b.go = p.lines, p.go
        b:SetWidth(ICON + 2 + (label ~= "" and (6 + b.text:GetStringWidth()) or 0))
        b:ClearAllPoints(); b:SetPoint("LEFT", f, "TOPLEFT", x, -HEAD_H / 2)
        x = x + b:GetWidth() + 14
    end
    f.more:SetShown(#pills > MAX_PILLS)
    if #pills > MAX_PILLS then
        f.more:SetText("+" .. (#pills - MAX_PILLS))
        f.more:ClearAllPoints(); f.more:SetPoint("LEFT", f, "TOPLEFT", x, -HEAD_H / 2)
        x = x + f.more:GetStringWidth() + 14
    end
    f:SetWidth(math.max(420, x + 62))
    -- liste dépliée
    f.rows:Reset()
    f.rowList = {}
    local y = -(HEAD_H + 6)
    for i, it in ipairs(items) do
        if i > MAX_ROWS then break end
        local r = f.rows:Get()
        r.go = it.go
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 8, y); r:SetPoint("TOPRIGHT", -8, y)
        r.ic:Set(it.gicon, it.color or C.border)
        r.text:SetText(it.text)
        r.text:SetTextColor(unpack(it.color or C.text))
        r.go2:SetVertexColor(r1, g1, b1)
        table.insert(f.rowList, r)
        y = y - ROW_H
    end
    f.extra = #items > MAX_ROWS and string.format(T("+ %d autre(s) dans le Résumé"), #items - MAX_ROWS) or nil
    -- temps
    local secs = WK.DB.global.settings.ui.loginPopupTime
    if secs == nil then secs = 5 end
    f.total = (secs > 0 and not sample) and secs or nil
    f.remain = f.total
    f.track:SetShown(f.total ~= nil)
    f.fill:SetShown(f.total ~= nil)
    f.fill:SetWidth(1)
    f.expanded = false
    f:Layout()
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
