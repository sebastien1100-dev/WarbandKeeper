local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local CreateFrame, UIParent = _G.CreateFrame, _G.UIParent

-- Repères sur les plaques de nom (la carte de quête, la barre « Quête » et les pastilles du suivi du jeu
-- ont été retirées avec la tournée et le guide de montée). Réglage QuestTrack:Config().plateMarks.
local function Q() return WK.modules.QuestTrack end

-- Repères sur les plaques de nom : monstres des objectifs pas finis des quêtes du journal (couleur de
-- l'objectif pour la quête suivie, accent pour les autres) ; plus gros sur la cible.
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
    local tracked = q:Tracked()
    -- quête suivie d'abord (ses couleurs passent devant), puis les autres quêtes du journal
    local ids = {}
    if tracked then ids[1] = tracked end
    for _, l in ipairs(q:LogQuests()) do if l.id ~= tracked and not l.complete then ids[#ids + 1] = l.id end end
    for _, qid in ipairs(ids) do
        if not q:IsComplete(qid) then
            for i, o in ipairs(q:Objectives(qid)) do
                if not o.done then
                    local col = (qid == tracked and UI.QuestObjColor) and UI.QuestObjColor(i) or { UI:Accent() }
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
