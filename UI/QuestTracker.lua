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
-- menu (guider, lien wowhead, groupe, jamais d'automatique). Rien n'est accroché aux cadres du suivi (leur forme
-- change d'un addon à l'autre) : au relâchement d'un clic gauche avec Alt, le cadre sous la souris et ses parents
-- sont lus ; la quête est reconnue par un n° du journal porté par le cadre (questID, id, n° × 100 + objectif…)
-- ou par le titre affiché (texte d'une quête du journal). Les autres clics restent ceux du suivi.
-- Réglage QuestTrack:Config().trackerMenu (vrai par défaut). /wk suivi : ce qui a été vu au dernier Alt + clic.
---------------------------------------------------------------------------
local last = { at = nil, frames = {}, quest = nil, how = nil }
local function inLog(id)
    local ql = _G.C_QuestLog
    return type(id) == "number" and id > 0 and ql and ql.GetLogIndexForQuestID and ql.GetLogIndexForQuestID(id) ~= nil
end
local function numQuest(v)
    if type(v) ~= "number" or v <= 0 or v ~= math.floor(v) then return nil end
    if inLog(v) then return v end
    local q = math.floor(v / 100) -- ligne d'objectif : n° de quête × 100 + objectif
    if q > 0 and inLog(q) then return q end
    return nil
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
local function textsOf(f)
    local out = {}
    if f.GetText then
        local ok, t = pcall(f.GetText, f)
        if ok then out[#out + 1] = t end
    end
    for _, k in ipairs({ "text", "Text", "title", "Title", "label", "HeaderText", "name" }) do
        local fs = rawget(f, k)
        if type(fs) == "table" and fs.GetText then
            local ok, t = pcall(fs.GetText, fs)
            if ok then out[#out + 1] = t end
        end
    end
    if f.GetRegions then
        for _, r in ipairs({ f:GetRegions() }) do
            if r.GetText then local ok, t = pcall(r.GetText, r); if ok then out[#out + 1] = t end end
        end
    end
    return out
end
-- quête d'un cadre : champs connus, puis tout champ numérique, puis titre affiché
local KEYS = { "questID", "questId", "questid", "id", "quest", "key", "logIndex" }
local function questOf(f, titles)
    for _, k in ipairs(KEYS) do
        local q = numQuest(rawget(f, k))
        if q then return q, "champ " .. k end
    end
    if f.GetQuestID then
        local ok, v = pcall(f.GetQuestID, f)
        local q = ok and numQuest(v)
        if q then return q, "GetQuestID" end
    end
    local n = 0
    for k, v in pairs(f) do
        n = n + 1
        if n > 60 then break end
        if type(k) == "string" then local q = numQuest(v); if q then return q, "champ " .. k end end
    end
    for _, t in ipairs(textsOf(f)) do
        local c = clean(t)
        if c and titles[c] then return titles[c], "titre" end
    end
    return nil
end
local function underMouse()
    local list = {}
    if _G.GetMouseFoci then
        local ok, foci = pcall(_G.GetMouseFoci)
        if ok and type(foci) == "table" then for _, f in ipairs(foci) do list[#list + 1] = f end end
    end
    if #list == 0 and _G.GetMouseFocus then
        local ok, f = pcall(_G.GetMouseFocus)
        if ok and f then list[1] = f end
    end
    return list
end
local function frameName(f)
    local n = f.GetName and f:GetName()
    return n or ((f.GetObjectType and f:GetObjectType() or "?") .. " sans nom")
end
local function onAltClick()
    if Q():Config().trackerMenu == false or not WK:FeatureOn("quests") then return end
    local titles = logTitles()
    last.at, last.frames, last.quest, last.how = _G.time and _G.time() or 0, {}, nil, nil
    for _, f in ipairs(underMouse()) do
        local g, depth = f, 0
        while g and g ~= UIParent and depth < 8 do
            local nm = frameName(g)
            if #last.frames < 6 then last.frames[#last.frames + 1] = nm end
            if nm:find("^WarbandKeeper") then return end -- nos propres fenêtres : leur clic suffit
            local q, how = questOf(g, titles)
            if q then
                last.quest, last.how = q, how
                if UI.QuestMenu then UI:QuestMenu({ q }) end
                return
            end
            g = g.GetParent and g:GetParent() or nil
            depth = depth + 1
        end
    end
end
UI.QuestTrackerAltClick = onAltClick
-- relâchement d'un clic gauche avec Alt (surveillé seulement quand Alt est enfoncé)
do
    local watch = CreateFrame("Frame")
    local wasDown = false
    watch:SetScript("OnUpdate", function()
        if not (_G.IsAltKeyDown and _G.IsAltKeyDown()) then wasDown = false return end
        local down = _G.IsMouseButtonDown and _G.IsMouseButtonDown("LeftButton") or false
        if wasDown and not down then pcall(onAltClick) end
        wasDown = down
    end)
end
function UI.QuestTrackerMenuDiag()
    if not last.at then
        return WK.T("Aucun Alt + clic vu pour l'instant : Alt + clic sur une quête du suivi, puis /wk suivi.")
    end
    return string.format("%s : %s · %s : %s", WK.T("sous la souris"), table.concat(last.frames, " > "),
        WK.T("quête"), last.quest and (last.quest .. " (" .. (last.how or "?") .. ")") or WK.T("non trouvée"))
end
