local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local CreateFrame, UIParent = _G.CreateFrame, _G.UIParent

-- Repères sur les plaques de nom (la carte de quête, la barre « Quête » et les pastilles du suivi du jeu
-- ont été retirées avec la tournée et le guide de montée). Réglage QuestTrack:Config().plateMarks.
local function Q() return WK.modules.QuestTrack end

-- Repères sur les plaques de nom : monstres des objectifs pas finis des quêtes du journal, à la couleur de
-- l'apparence ; plus gros sur la cible.
local marks = {}
local function plateNpc(unit)
    local guid = WK.GUID(unit)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return kind == "Creature" and tonumber(id) or nil
end
-- avant, la liste était refaite chaque seconde (tout le journal relu) et forçait le chargement des données à
-- la demande dès la connexion ; elle n'est maintenant refaite qu'après un QUEST_LOG_UPDATE qui change
-- l'empreinte du journal (QuestTrack.LogSignature) ou l'arrivée des données
local wanted, wantedSig, wantedDirty = {}, nil, true
WK:On("QUEST_LOG_UPDATE", function() wantedDirty = true end)
WK:OnDataLoaded(function() wantedDirty = true; wantedSig = nil end)
local function wantedNpcs()
    if not wantedDirty then return wanted end
    wantedDirty = false
    local q = Q()
    local sig = q.LogSignature and q.LogSignature()
    if sig and sig == wantedSig then return wanted end
    wantedSig = sig
    _G.wipe(wanted)
    -- préchargement coupé et données pas là : seulement ce qui est déjà chargé (rien n'est chargé pour ça)
    local cfg = WK.DataConfig and WK.DataConfig() or {}
    local textOnly = not WK.dataLoaded and cfg.preload == false
    for _, l in ipairs(q:LogQuests()) do
        local qid = l.id
        if not l.complete and not q:IsComplete(qid) then
            for _, o in ipairs(q:Objectives(qid, textOnly)) do
                if not o.done then
                    for _, id in ipairs(q:ObjectiveNpcs(o)) do wanted[id] = true end
                end
            end
        end
    end
    return wanted
end
local function updateMarks()
    for _, m in ipairs(marks) do m:Hide() end
    local c = Q():Config()
    if c.plateMarks == false or not WK:FeatureOn("quests") then return end
    if not (_G.C_NamePlate and _G.C_NamePlate.GetNamePlates) then return end
    -- aucune plaque de nom : rien à faire (ni journal relu, ni données chargées)
    local ok, plates = pcall(_G.C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" or not next(plates) then return end
    local w = wantedNpcs()
    if not next(w) then return end
    local col = { UI:Accent() }
    local n = 0
    for _, p in ipairs(plates) do
        local unit = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
        local id = unit and plateNpc(unit)
        if id and w[id] and not (_G.UnitIsDead and _G.UnitIsDead(unit)) then
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

---------------------------------------------------------------------------
-- Aides du menu du clic droit d'EllesmereUI (plus bas). L'Alt + clic sur le suivi a été retiré à la demande du
-- joueur : nos lignes sont dans le menu du clic droit d'EllesmereUI, ce qui suffit.
---------------------------------------------------------------------------
local function inLog(id)
    local ql = _G.C_QuestLog
    return type(id) == "number" and id > 0 and ql and ql.GetLogIndexForQuestID and ql.GetLogIndexForQuestID(id) ~= nil
end
-- titres du journal (en minuscules, sans codes de couleur) » n° de quête
local function logTitles()
    local out = {}
    for _, l in ipairs(Q():LogQuests()) do
        if l.title then out[l.title:lower()] = l.id end
    end
    return out
end
local function clean(t)
    if type(t) ~= "string" then return nil end
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*%[[^%]]*%]%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return t:lower()
end

---------------------------------------------------------------------------
-- Menu du clic droit du suivi d'EllesmereUI : nos lignes ajoutées à la fin (guider, chercher un groupe). Son
-- menu est fait par la fonction publique EllesmereUI.ShowContextMenu(owner,
-- items, opts) (items = { { text, noLoc, onClick, isDisabled }, "---" }) : elle est enrobée une fois, le menu
-- d'une quête reconnu par sa ligne (owner.kind = "quest", owner.id = n° du journal) ou par son titre en tête.
-- Rien d'autre ne change (ses lignes et leur ordre restent). Réglage QuestTrack:Config().trackerMenu.
---------------------------------------------------------------------------
local function menuQuest(owner, items)
    if type(owner) == "table" then
        local id = rawget(owner, "id")
        if rawget(owner, "kind") == "quest" and inLog(id) then return id end
    end
    local first = type(items) == "table" and items[1]
    local title = type(first) == "table" and clean(first.text)
    if title then return logTitles()[title] end
    return nil
end
local function ourItems(qid)
    local QT = Q()
    local out = { "---" }
    out[#out + 1] = { text = T("Guider vers la quête"), noLoc = true, onClick = function() QT:GuideQuest(qid) end }
    out[#out + 1] = { text = T("Chercher un groupe (chat)"), noLoc = true,
        onClick = function() if UI.QuestGroupMessage then UI:QuestGroupMessage(qid) end end }
    return out
end
local function wrapEllesmere()
    local E = _G.EllesmereUI
    if type(E) ~= "table" or type(E.ShowContextMenu) ~= "function" or E.wkMenuWrapped then return end
    local orig = E.ShowContextMenu
    E.wkMenuWrapped = true
    E.ShowContextMenu = function(owner, items, opts, ...)
        local ok, qid = pcall(menuQuest, owner, items)
        if ok and qid and type(items) == "table" and Q():Config().trackerMenu ~= false and WK:FeatureOn("quests") then
            local add = ourItems(qid)
            local copy = {}
            for i, e in ipairs(items) do copy[i] = e end
            for _, e in ipairs(add) do copy[#copy + 1] = e end
            items = copy
        end
        return orig(owner, items, opts, ...)
    end
end
UI.WrapEllesmereMenu = wrapEllesmere
WK:On("PLAYER_LOGIN", wrapEllesmere)
WK:On("ADDON_LOADED", function(name)
    if type(name) == "string" and name:find("^EllesmereUI") then wrapEllesmere() end
end)
