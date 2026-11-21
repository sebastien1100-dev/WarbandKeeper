local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local CreateFrame, UIParent = _G.CreateFrame, _G.UIParent

-- Repères sur les plaques de nom (la carte de quête, la barre « Quête » et les pastilles du suivi du jeu
-- ont été retirées avec la tournée et le guide de montée). Réglage QuestTrack:Config().plateMarks.
local function Q() return WK.modules.QuestTrack end

-- Repères sur les plaques de nom : monstres des objectifs pas finis des quêtes du journal, à la couleur de
-- l'apparence ; plus gros sur la cible.
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
    local col = { UI:Accent() }
    for _, l in ipairs(q:LogQuests()) do
        local qid = l.id
        if not l.complete and not q:IsComplete(qid) then
            for _, o in ipairs(q:Objectives(qid)) do
                if not o.done then
                    for _, id in ipairs(q:ObjectiveNpcs(o)) do if not wanted[id] then wanted[id] = col end end
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

---------------------------------------------------------------------------
-- Menu des quêtes sur le suivi des quêtes (EllesmereUI ou celui du jeu) : Alt + clic sur une quête ouvre notre
-- menu (guider, lien wowhead, groupe, jamais d'automatique). Alt seulement : les clics gauche, droit et Maj
-- restent ceux du suivi. Lignes reconnues par leur forme, sans rien changer au suivi (HookScript seulement) :
-- suivi d'EllesmereUI sur WoW Forever (boutons sans nom, champs `kind` et `id` = n° de quête, ou
-- n° de quête × 100 + objectif) ; suivi du jeu (champ `questID`, `id` d'un bloc). Réglage
-- QuestTrack:Config().trackerMenu (vrai par défaut). /wk suivi : ce qui a été trouvé.
---------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })
local roots = {}
local found = { rows = 0, roots = {} }
local function inLog(id)
    local ql = _G.C_QuestLog
    return id and ql and ql.GetLogIndexForQuestID and ql.GetLogIndexForQuestID(id) ~= nil
end
-- n° de quête d'une ligne du suivi
local function rowQuest(f)
    local id = rawget(f, "questID") or rawget(f, "id")
    if type(id) ~= "number" or id <= 0 then return nil end
    if inLog(id) then return id end
    -- ligne d'objectif d'EllesmereUI : n° de quête × 100 + n° d'objectif
    local q = math.floor(id / 100)
    if q > 0 and inLog(q) then return q end
    return nil
end
local function onRowClick(self)
    if not (_G.IsAltKeyDown and _G.IsAltKeyDown()) then return end
    if Q():Config().trackerMenu == false or not WK:FeatureOn("quests") then return end
    local qid = rowQuest(self)
    if qid and UI.QuestMenu then UI:QuestMenu({ qid }) end
end
local function hookRow(f)
    if hooked[f] or not f.HookScript then return end
    local kind = rawget(f, "kind")
    -- lignes de quête d'EllesmereUI (pas les boutons d'objet protégés) ou blocs du suivi du jeu
    if kind ~= nil and kind ~= "quest" and kind ~= "obj" and kind ~= "objective" then return end
    if f.IsProtected and f:IsProtected() then return end
    if not rowQuest(f) then return end
    hooked[f] = true
    found.rows = found.rows + 1
    local hasClick = f.GetScript and f:GetScript("OnClick")
    if hasClick then f:HookScript("OnClick", onRowClick)
    else f:HookScript("OnMouseUp", onRowClick) end
end
local function walk(f, depth)
    if depth > 8 or not f or not f.GetChildren then return end
    for _, ch in ipairs({ f:GetChildren() }) do
        hookRow(ch)
        walk(ch, depth + 1)
    end
end
-- racine d'un cadre : son ancêtre juste sous UIParent
local function topOf(f)
    local guard = 0
    while f and f.GetParent and f:GetParent() and f:GetParent() ~= UIParent and guard < 20 do
        f = f:GetParent(); guard = guard + 1
    end
    return f
end
local lastDiscover = -10
local function discover()
    for _, n in ipairs({ "EUI_CustomQuestTracker", "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
        local f = _G[n]
        if f and not roots[f] then roots[f] = n end
    end
    -- parcours de tous les cadres : au plus toutes les 10 s
    local now = _G.GetTime and _G.GetTime() or 0
    if now - lastDiscover < 10 and now >= lastDiscover then return end
    lastDiscover = now
    -- suivi d'EllesmereUI sans nom : une ligne « quest » qui porte un n° du journal donne sa racine
    if _G.EnumerateFrames then
        local f, guard = _G.EnumerateFrames(), 0
        while f and guard < 20000 do
            if rawget(f, "kind") == "quest" and rowQuest(f) then
                local top = topOf(f)
                if top and not roots[top] then roots[top] = (top.GetName and top:GetName()) or "EllesmereUI" end
                break
            end
            f = _G.EnumerateFrames(f); guard = guard + 1
        end
    end
end
local function scan()
    if Q():Config().trackerMenu == false or not WK:FeatureOn("quests") then return end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    discover()
    for f in pairs(roots) do walk(f, 0) end
end
UI.ScanQuestTrackers = scan
function UI.QuestTrackerMenuDiag()
    local names = {}
    for _, n in pairs(roots) do names[#names + 1] = n end
    return string.format("%s : %s · %s : %d", WK.T("suivis trouvés"), #names > 0 and table.concat(names, ", ") or "-",
        WK.T("lignes de quête"), found.rows)
end
WK:On("PLAYER_ENTERING_WORLD", function() _G.C_Timer.After(4, scan) end)
WK:On("QUEST_LOG_UPDATE", function() _G.C_Timer.After(0.5, scan) end)
WK:On("QUEST_WATCH_LIST_CHANGED", function() _G.C_Timer.After(0.5, scan) end)
