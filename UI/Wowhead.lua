local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

---------------------------------------------------------------------------
-- Menu des quêtes : clic droit sur une quête (listes de la page Quêtes, fenêtre des quêtes du donjon, journal
-- des données) : guider, chercher un groupe. (Liens wowhead retirés à la demande du joueur.)
---------------------------------------------------------------------------
-- étiquette « GROUPE » (orange) devant le nom d'une quête de groupe (monstre élite, WK.QuestIsGroup) ; vide sinon
function UI.GroupTag(qid)
    if not (qid and WK.QuestIsGroup and WK.QuestIsGroup(qid)) then return "" end
    return UI:Hex(C.warning) .. T("GROUPE") .. "|r  "
end


---------------------------------------------------------------------------
-- Chercher un groupe : message envoyé dans le canal 1 (Général) avec le lien de la quête. Modèle modifiable
-- (settings.ui.questLfgText, carte « Message de groupe » de la roue des Quêtes), en anglais par défaut ;
-- {quest} = lien, {name} = nom, {level} = niveau, {zone} = zone.
---------------------------------------------------------------------------
UI.QUEST_LFG_DEFAULT = "LFG {quest} ({zone}), anyone want to group up?"
function UI.QuestLfgTemplate(_)
    local t = WK.DB.global.settings.ui.questLfgText
    return (t and t ~= "") and t or UI.QUEST_LFG_DEFAULT
end
-- lien de quête du jeu (journal) sinon fabriqué
function UI.QuestLink(_, qid)
    local Qm, QT = WK.modules.Quests, WK.modules.QuestTrack
    local link
    if _G.C_QuestLog and _G.C_QuestLog.GetQuestLink then
        local ok, l = pcall(_G.C_QuestLog.GetQuestLink, qid)
        if ok and type(l) == "string" and l ~= "" then link = l end
    end
    if not link and _G.GetQuestLink and _G.C_QuestLog and _G.C_QuestLog.GetLogIndexForQuestID then
        local idx = _G.C_QuestLog.GetLogIndexForQuestID(qid)
        if idx then local ok, l = pcall(_G.GetQuestLink, idx); if ok and type(l) == "string" then link = l end end
    end
    local q = Qm and Qm:Get(qid)
    local name = (QT and QT.InLog and QT:InLog(qid) and QT:Title(qid)) or (q and Qm:Name(q)) or ("#" .. qid)
    local lvl = (QT and QT.Level and QT:Level(qid)) or (q and q.lvl) or 0
    link = link or string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", qid, lvl, name)
    return link, name, lvl, q
end
function UI.QuestGroupMessage(_, qid)
    local link, name, lvl, q = UI:QuestLink(qid)
    local zone = ""
    if q and q.map and _G.C_Map and _G.C_Map.GetMapInfo then
        local info = _G.C_Map.GetMapInfo(q.map)
        zone = info and info.name or ""
    end
    local text = UI:QuestLfgTemplate()
    text = text:gsub("{quest}", function() return link end):gsub("{name}", function() return name end)
        :gsub("{level}", function() return tostring(lvl or "") end):gsub("{zone}", function() return zone end)
    -- zone inconnue : « () » vide retiré, pas d'espace avant une virgule
    text = text:gsub("%s*%(%s*%)", ""):gsub("%s+([,%.!%?])", "%1"):gsub("%s%s+", " ")
    -- envoyé dans le canal 1 (Général) ; le clic du menu est un vrai clic, le jeu l'accepte. Refusé (ancien
    -- client, pas de canal 1) : la boîte de discussion s'ouvre déjà réglée sur /1, Entrée pour envoyer
    local send = _G.SendChatMessage or (_G.C_ChatInfo and _G.C_ChatInfo.SendChatMessage)
    local sent = send and pcall(send, text, "CHANNEL", nil, 1)
    if not sent then
        if _G.ChatFrame_OpenChat then
            _G.ChatFrame_OpenChat(text)
            local eb = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()
            if eb and eb.SetAttribute then
                eb:SetAttribute("chatType", "CHANNEL"); eb:SetAttribute("channelTarget", 1)
                if _G.ChatEdit_UpdateHeader then pcall(_G.ChatEdit_UpdateHeader, eb) end
            end
        elseif _G.ChatEdit_InsertLink then _G.ChatEdit_InsertLink(text) end
    end
    return text, sent
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

-- qids : une ou plusieurs quêtes
function UI:QuestMenu(qids)
    local Qm, QT = WK.modules.Quests, WK.modules.QuestTrack
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
        if QT and QT.InLog and QT:InLog(id) and QT.GuideQuest then add(T("Guider vers la quête") .. suffix, function() QT:GuideQuest(id) end) end
        add(T("Chercher un groupe (chat)") .. suffix, function() UI:QuestGroupMessage(id) end)
    end
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

-- à appeler au début d'un OnClick de ligne de quête : rend vrai si le clic est pris (clic droit)
function UI:QuestClick(btn, qids)
    if type(qids) ~= "table" then qids = { qids } end
    if #qids == 0 then return false end
    if btn == "RightButton" then UI:QuestMenu(qids) return true end
    return false
end
-- ligne d'aide pour les infobulles de quête
function UI:QuestClickHint()
    return T("Clic droit : menu de la quête")
end
