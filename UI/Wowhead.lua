local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

---------------------------------------------------------------------------
-- Liens wowhead (partie WoW Forever du site) : un addon ne peut pas ouvrir le navigateur, une petite fenêtre
-- donne le lien déjà sélectionné (Ctrl+C). Maj + clic sur une quête (tournée, listes de la page Quêtes, fenêtre
-- des quêtes du donjon, journal des données) l'ouvre ; clic droit : petit menu (guider, suivre, passer l'étape,
-- ignorer, lien wowhead). Langue du site : settings.ui.wowheadLang (« fr » / « en »), roue de la page Quêtes.
---------------------------------------------------------------------------
local KIND_LABEL = { quest = "Quête", npc = "PNJ", item = "Objet", object = "Objet du décor" }

function UI:WowheadLang()
    local ui = WK.DB.global.settings.ui
    if ui.wowheadLang == "fr" or ui.wowheadLang == "en" then return ui.wowheadLang end
    return WK.Lang and WK.Lang() == "frFR" and "fr" or "en"
end
function UI:WowheadURL(kind, id, lang)
    lang = lang or UI:WowheadLang()
    return "https://www.wowhead.com/forever/" .. (lang == "fr" and "fr/" or "") .. kind .. "=" .. tostring(id)
end

local pop
local function buildPop()
    local f = CreateFrame("Frame", "WarbandKeeperWowhead", UIParent)
    f:SetSize(420, 132)
    f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 10, C.surface, C.border)
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetPoint("RIGHT", -36, 0)
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 14, -30)
    f.close = UI:IconButton(f, "close", 16, "Fermer"); f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetScript("OnClick", function() f:Hide() end)
    local eb = CreateFrame("EditBox", nil, f)
    eb:SetPoint("TOPLEFT", 14, -48); eb:SetPoint("TOPRIGHT", -46, -48); eb:SetHeight(24)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal or GameFontHighlight)
    eb:SetTextInsets(8, 8, 0, 0)
    eb.bg = UI:Rounded(eb, 6, 0, "BACKGROUND", 1); eb.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
    -- lecture seule : le texte revient au lien si on tape dedans
    eb:SetScript("OnTextChanged", function(s, user) if user and f.url then s:SetText(f.url); s:HighlightText() end end)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnEnterPressed", function() f:Hide() end)
    eb:SetScript("OnMouseUp", function(s) s:HighlightText() end)
    eb:SetScript("OnEditFocusGained", function(s) s:HighlightText() end)
    f.eb = eb
    -- copier : le jeu ne laisse pas un addon écrire dans le presse-papiers ; le lien est sélectionné et il
    -- ne reste que Ctrl+C (copie directe si le client l'autorise un jour : CopyToClipboard)
    f.copy = UI:IconButton(f, "copy", 26, "Copier le lien")
    f.copy:SetPoint("LEFT", eb, "RIGHT", 6, 0)
    f.copy:SetScript("OnClick", function()
        local done = false
        local copyFn = _G.CopyToClipboard
        if type(copyFn) == "function" then done = pcall(copyFn, f.url or "") end
        eb:SetFocus(); eb:HighlightText()
        local r, g, b = UI:Accent()
        f.hint:SetTextColor(r, g, b)
        f.hint:SetText(done and T("Lien copié : colle-le dans ton navigateur")
            or T("Lien sélectionné : Ctrl+C, puis colle-le dans ton navigateur"))
        _G.C_Timer.After(3, function()
            f.hint:SetTextColor(unpack(C.muted))
            f.hint:SetText(T("Ctrl+C pour copier, puis colle-le dans ton navigateur · Échap pour fermer"))
        end)
    end)
    f.hint = UI:Text(f, 10, C.muted); f.hint:SetPoint("TOPLEFT", 14, -78)
    f.hint:SetText(T("Ctrl+C pour copier, puis colle-le dans ton navigateur · Échap pour fermer"))
    f.lang = UI:Button(f, "", 160, 24, "ghost", "globe"); f.lang:SetPoint("BOTTOMLEFT", 12, 10)
    f.lang:SetScript("OnClick", function() f.curLang = f.curLang == "fr" and "en" or "fr"; f:Fill() end)
    f.chat = UI:Button(f, T("Mettre dans le chat"), 170, 24, "ghost", "chat")
    f.chat:SetPoint("LEFT", f.lang, "RIGHT", 8, 0)
    f.chat:SetScript("OnClick", function()
        local text = (f.name and (f.name .. " : ") or "") .. (f.url or "")
        f:Hide()
        if ChatFrame_OpenChat then ChatFrame_OpenChat(text)
        elseif ChatEdit_InsertLink then ChatEdit_InsertLink(text) end
    end)
    function f:Fill()
        self.url = UI:WowheadURL(self.kind, self.id, self.curLang)
        self.title:SetText(self.name or ("#" .. tostring(self.id)))
        self.sub:SetText(string.format(T("%s n° %s · wowhead (WoW Forever)"), T(KIND_LABEL[self.kind] or self.kind), tostring(self.id)))
        self.lang:SetLabel(self.curLang == "fr" and T("Version anglaise") or T("Version française"))
        self.eb:SetText(self.url)
        self.eb:SetFocus()
        self.eb:HighlightText()
    end
    f:SetScript("OnHide", function(s) s.eb:ClearFocus() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperWowhead") end
    f:Hide()
    return f
end

-- fenêtre du lien : kind = quest / npc / item / object
function UI:ShowWowhead(kind, id, name)
    if not id then return end
    pop = pop or buildPop()
    pop.kind, pop.id, pop.name, pop.curLang = kind, id, name, UI:WowheadLang()
    -- près de la souris, sans sortir de l'écran
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    pop:ClearAllPoints()
    pop:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 12, y / s - 12)
    pop:Show(); pop:Raise()
    pop:Fill()
end

---------------------------------------------------------------------------
-- Menu du clic droit sur une quête
---------------------------------------------------------------------------
local menu, blocker
local function buildMenu()
    blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent); blocker:SetFrameStrata("DIALOG"); blocker:SetFrameLevel(1)
    blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() menu:Hide() end)
    blocker:Hide()
    local f = CreateFrame("Frame", "WarbandKeeperQuestMenu", UIParent)
    f:SetFrameStrata("DIALOG"); f:SetFrameLevel(50); f:SetClampedToScreen(true)
    UI:Panel(f, 8, C.surface, C.border)
    f.items = {}
    f:SetScript("OnHide", function() blocker:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperQuestMenu") end
    f:Hide()
    return f
end
local function item(i)
    local b = menu.items[i]
    if not b then
        b = CreateFrame("Button", nil, menu); b:SetHeight(24)
        b.hl = UI:Rounded(b, 5, 0, "BACKGROUND", 2); b.hl:Hide()
        b.t = UI:Text(b, 12); b.t:SetPoint("LEFT", 10, 0); b.t:SetPoint("RIGHT", -70, 0)
        if b.t.SetWordWrap then b.t:SetWordWrap(false) end
        b.k = UI:Text(b, 10, C.dim); b.k:SetPoint("RIGHT", -10, 0); b.k:SetJustifyH("RIGHT")
        b:SetScript("OnEnter", function(s)
            local r, g, bl = UI:Accent()
            s.hl:SetColor(r, g, bl, 0.14); s.hl:Show(); s.t:SetTextColor(r, g, bl)
        end)
        b:SetScript("OnLeave", function(s) s.hl:Hide(); s.t:SetTextColor(unpack(C.text)) end)
        b:SetScript("OnClick", function(s) menu:Hide(); if s.fn then s.fn() end end)
        menu.items[i] = b
    end
    return b
end

-- qids : une ou plusieurs quêtes (étape de la tournée) ; opts.step = ligne d'une étape de la tournée
function UI:QuestMenu(qids, opts)
    opts = opts or {}
    local Qm, QT, P = WK.modules.Quests, WK.modules.QuestTrack, WK.modules.QuestPlan
    if not (Qm and qids and #qids > 0) then return end
    menu = menu or buildMenu()
    local entries = {}
    local function add(text, fn, key) table.insert(entries, { text, fn, key }) end
    local function nameOf(id)
        local q = Qm:Get(id)
        return (QT and QT.InLog and QT:InLog(id) and QT:Title(id)) or (q and Qm:Name(q)) or ("#" .. id)
    end
    local multi = #qids > 1
    for _, id in ipairs(qids) do
        local q = Qm:Get(id)
        local nm = nameOf(id)
        local suffix = multi and (" : " .. nm) or ""
        if q and q.x and not (QT and QT.InLog and QT:InLog(id)) then add(T("Guider vers le donneur") .. suffix, function() Qm:GuideTo(q) end) end
        if QT and QT.InLog and QT:InLog(id) and QT.Track then add(T("Suivre cette quête") .. suffix, function() QT:Track(id) end) end
        if P and P.SetPicked then
            add(T("Ignorer cette quête") .. suffix, function()
                P:SetPicked(id, false)
                if P:Tour() then P:Reorder() end
                WK:Print(string.format(T("Quête ignorée pour la tournée : %s"), nm))
            end)
        end
        add(T("Lien wowhead") .. suffix, function() UI:ShowWowhead("quest", id, nm) end, multi and "" or T("Maj + clic"))
    end
    if opts.step and P and P:Tour() then add(T("Passer cette étape"), function() P:Skip() end) end
    local w = 250
    for i, e in ipairs(entries) do
        local b = item(i)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 24); b:SetPoint("TOPRIGHT", -5, -5 - (i - 1) * 24)
        b.t:SetText(e[1]); b.t:SetTextColor(unpack(C.text)); b.k:SetText(e[3] or ""); b.fn = e[2]
        b:Show()
        w = math.max(w, (b.t:GetStringWidth() or 0) + 90)
    end
    for i = #entries + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(math.min(w, 420), 10 + #entries * 24)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 2, y / s - 2)
    blocker:Show(); menu:Show(); menu:Raise()
end

-- à appeler au début d'un OnClick de ligne de quête : rend vrai si le clic est pris (Maj + clic, clic droit)
function UI:QuestClick(btn, qids, opts)
    if type(qids) ~= "table" then qids = { qids } end
    if #qids == 0 then return false end
    if btn == "RightButton" then UI:QuestMenu(qids, opts) return true end
    if btn == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
        local id = qids[1]
        local Qm, QT = WK.modules.Quests, WK.modules.QuestTrack
        local q = Qm and Qm:Get(id)
        local nm = (QT and QT.InLog and QT:InLog(id) and QT:Title(id)) or (q and Qm:Name(q)) or nil
        UI:ShowWowhead("quest", id, nm)
        return true
    end
    return false
end
-- ligne d'aide pour les infobulles de quête
function UI:QuestClickHint()
    return T("Maj + clic : lien wowhead · clic droit : menu")
end
