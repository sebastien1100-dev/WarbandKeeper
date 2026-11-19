local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Recherche en haut de la barre latérale : pages, sections, réglages, persos et objets du compte.
-- Les réglages sont connus parce que chaque ligne de réglage (UI:SettingRow) s'inscrit dans
-- UI.settingIndex ; à la première recherche, les pages pas encore ouvertes sont construites (cachées)
-- pour que leurs réglages soient trouvables. Un clic ouvre la page, la section, fait défiler jusqu'au
-- réglage et le met en évidence un instant.
UI.settingIndex = UI.settingIndex or {}
local MAX = 10

-- Texte comparable : minuscules, sans accents
local ACC = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["î"] = "i", ["ï"] = "i",
              ["ô"] = "o", ["ö"] = "o", ["û"] = "u", ["ù"] = "u", ["ü"] = "u", ["ç"] = "c", ["œ"] = "oe",
              ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["À"] = "a", ["Ç"] = "c", ["Œ"] = "oe" }
local function norm(s)
    s = string.lower(tostring(s or ""))
    for k, v in pairs(ACC) do s = s:gsub(k, v) end
    return s
end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- Toutes les pages construites (une seule fois), cachées, pour indexer leurs réglages
local built = false
local function buildAll()
    if built then return end
    built = true
    for key, def in pairs(UI.pages) do
        if not def.frame and UI.pageHost then
            local ok = pcall(function()
                def.frame = CreateFrame("Frame", nil, UI.pageHost)
                def.frame:SetAllPoints()
                UI:InAccentScope("window", def.Build, def, def.frame)
            end)
            if def.frame then def.frame:SetShown(key == UI.current) end
            if not ok then def.frame = nil end
        end
    end
end

-- Après UI:Rebuild : les pages sont refaites et seront de nouveau indexées ; les lignes de
-- l'ancienne fenêtre (root) sont oubliées, les autres (mode édition…) restent.
function UI:ResetSearchIndex(root)
    built = false
    if not root then return end
    local keep = {}
    for _, e in ipairs(self.settingIndex) do
        local f, inOld = e.row, false
        while f do if f == root then inOld = true break end f = f:GetParent() end
        if not inOld then table.insert(keep, e) end
    end
    wipe(self.settingIndex)
    for i, e in ipairs(keep) do self.settingIndex[i] = e end
end

local function pageLabel(def)
    return WK.T(def.nav or def.title or def.key)
end

-- Page et section qui contiennent un cadre
local function locate(frame)
    for key, def in pairs(UI.pages) do
        if def.frame then
            local f, inPage = frame, false
            while f do if f == def.frame then inPage = true break end f = f:GetParent() end
            if inPage then
                local sec
                for k, s in pairs(def.sections or {}) do
                    local g = frame
                    while g do if g == s.scroll then sec = k break end g = g:GetParent() end
                    if sec then break end
                end
                return key, sec
            end
        end
    end
end

-- Index retenu dans la sauvegarde (WK.DB.global.searchIndex, hors profils) : une fois toutes les pages
-- construites pour une version de l'addon et une langue, les recherches suivantes (et aux sessions
-- suivantes) n'ont plus besoin de construire les pages : seule celle qu'on ouvre l'est.
local function stored()
    local si = WK.DB.global.searchIndex
    if si and si.v == WK.version and si.lang == WK.Lang() and type(si.list) == "table" then return si end
end
local function snapshot()
    local list = {}
    for _, e in ipairs(UI.settingIndex) do
        local pk, sk = locate(e.row)
        if pk and e.label then table.insert(list, { l = e.label, d = e.desc, p = pk, s = sk }) end
    end
    local secs = {}
    for key, def in pairs(UI.pages) do
        for sk, b in pairs(def.navButtons or def.sectionButtons or {}) do
            local l = b.label and b.label:GetText()
            if l then table.insert(secs, { l = plain(l), p = key, s = sk }) end
        end
    end
    WK.DB.global.searchIndex = { v = WK.version, lang = WK.Lang(), list = list, secs = secs }
end
UI.SearchSnapshot = snapshot
-- ligne d'un réglage d'après l'index retenu : la page est construite, puis la ligne retrouvée par son libellé
local function findRow(pk, label)
    UI:EnsurePage(pk)
    for _, e in ipairs(UI.settingIndex) do
        if e.label == label and locate(e.row) == pk then return e.row end
    end
end

-- Résultats : { kind, label, sub, run }
local function search(q)
    q = norm(q)
    local out = {}
    if #q < 2 then return out end
    local function add(kind, label, sub, run)
        if #out < 40 then table.insert(out, { kind = kind, label = label, sub = sub, run = run }) end
    end
    -- pages
    for key, def in pairs(UI.pages) do
        local l = pageLabel(def)
        if key ~= "charsheet" and WK:PageOn(key) and norm(l):find(q, 1, true) then add(T("Page"), l, nil, function() UI:ShowPage(key) end) end
    end
    local si = not built and stored()
    if si then
        -- sections et réglages d'après l'index retenu (pages pas construites)
        for _, e in ipairs(si.secs or {}) do
            if WK:PageOn(e.p) and norm(e.l):find(q, 1, true) then
                add(T("Section"), e.l, pageLabel(UI.pages[e.p] or { key = e.p }), function()
                    local def = UI:EnsurePage(e.p)
                    UI:ShowPage(e.p)
                    if def and def.ShowSection then def:ShowSection(e.s) end
                end)
            end
        end
        for _, e in ipairs(si.list) do
            local l, d = e.l or "", e.d or ""
            local pk, sk = e.p, e.s
            local off = not WK:PageOn(pk) or (pk == "qol" and sk and WK.FEATURE_BY_QOL[sk] and not WK:FeatureOn(WK.FEATURE_BY_QOL[sk]))
            if not off and UI.pages[pk] and (norm(WK.T(l)):find(q, 1, true) or norm(WK.T(d)):find(q, 1, true)) then
                local where = pageLabel(UI.pages[pk])
                for _, sc in ipairs(si.secs or {}) do if sc.p == pk and sc.s == sk then where = where .. " · " .. sc.l break end end
                add(T("Réglage"), plain(WK.T(l)), where, function()
                    local row = findRow(pk, l)
                    if row then UI:GoToSetting(row, pk, sk) else UI:ShowPage(pk) end
                end)
            end
        end
    end
    -- sections (colonnes de QoL et d'Options)
    for key, def in pairs(UI.pages) do
        if si then break end
        for sk, b in pairs(def.navButtons or def.sectionButtons or {}) do
            local l = b.label and b.label:GetText()
            if l and norm(l):find(q, 1, true) then
                add(T("Section"), plain(l), pageLabel(def), function()
                    UI:ShowPage(key)
                    if def.ShowSection then def:ShowSection(sk) end
                end)
            end
        end
    end
    -- réglages
    for _, e in ipairs(si and {} or UI.settingIndex) do
        local l, d = e.label or "", e.desc or ""
        if norm(WK.T(l)):find(q, 1, true) or norm(WK.T(d)):find(q, 1, true) then
            local pk, sk = locate(e.row)
            -- module coupé : ni sa page, ni sa section de QoL
            if pk and (not WK:PageOn(pk) or (pk == "qol" and sk and WK.FEATURE_BY_QOL[sk] and not WK:FeatureOn(WK.FEATURE_BY_QOL[sk]))) then pk = nil end
            if pk then
                local def = UI.pages[pk]
                local where = pageLabel(def)
                if sk and def.navButtons and def.navButtons[sk] then where = where .. " · " .. plain(def.navButtons[sk].label:GetText())
                elseif sk and def.sectionButtons and def.sectionButtons[sk] then where = where .. " · " .. plain(def.sectionButtons[sk].label:GetText()) end
                add(T("Réglage"), plain(WK.T(l)), where, function() UI:GoToSetting(e.row, pk, sk) end)
            end
        end
    end
    -- persos
    for key, c in pairs(WK.DB.global.characters) do
        local n = WK:CharName(c, key)
        if norm(n):find(q, 1, true) then
            add(T("Perso"), n, T(WK.modules.QoL.CLASS_LABEL[c.class or ""] or "") .. (c.level and (" " .. c.level) or ""),
                function() UI:ShowPage("characters") end)
        end
    end
    -- objets du compte
    local seen = {}
    for _, c in pairs(WK.DB.global.characters) do
        for _, where in ipairs({ "bags", "bank" }) do
            for id in pairs(c[where] or {}) do
                if not seen[id] then
                    seen[id] = true
                    local name = WK.GetItemInfo(id)
                    if name and norm(name):find(q, 1, true) then
                        local total = WK.modules.Inventory:AccountCount(id)
                        add(T("Objet"), name, string.format(T("%d sur le compte"), total), function()
                            UI:ShowPage("inventory")
                            local inv = UI.pages.inventory
                            -- vue « tous les persos » : sur Verrouillés, Rangement… la recherche ne montrerait rien
                            if inv and inv.char ~= "all" then
                                inv.char = "all"
                                WK.DB.global.settings.ui.invChar = "all"
                                if inv.Refresh then pcall(inv.Refresh, inv) end
                            end
                            if inv and inv.search then inv.search:SetText(name) end
                        end)
                    end
                end
            end
        end
    end
    return out
end

-- Ouvre la page et la section d'un réglage, fait défiler jusqu'à lui et le met en évidence.
function UI:GoToSetting(row, pk, sk)
    UI:ShowPage(pk)
    local def = UI.pages[pk]
    if sk and def.ShowSection then def:ShowSection(sk) end
    local sec = sk and def.sections and def.sections[sk]
    -- section en onglets (QoL) : ouvrir l'onglet qui contient le réglage
    if def.RevealSetting then def:RevealSetting(row) end
    if sec and sec.tabOf then
        local i = sec.tabOf(row)
        if i then sec.showTab(i) end
    end
    C_Timer.After(0.05, function()
        if sec and sec.scroll and row:GetTop() and sec.scroll.child:GetTop() then
            local off = sec.scroll.child:GetTop() - row:GetTop() - 20
            local max = sec.scroll.MaxScroll and sec.scroll:MaxScroll() or off
            sec.scroll:SetVerticalScroll(math.max(0, math.min(max, off)))
            if sec.scroll.UpdateBar then sec.scroll:UpdateBar() end
        end
        if not row.flash then
            row.flash = row:CreateTexture(nil, "BACKGROUND")
            row.flash:SetPoint("TOPLEFT", -8, 4)
            row.flash:SetPoint("BOTTOMRIGHT", 8, -4)
        end
        local r, g, b = UI:Accent()
        row.flash:SetColorTexture(r, g, b, 0.22)
        row.flash:Show()
        C_Timer.After(1.6, function() row.flash:Hide() end)
    end)
end

---------------------------------------------------------------------------
-- Champ et liste de résultats
---------------------------------------------------------------------------
function UI:BuildSideSearch(side)
    local box = UI:Input(side, 10, 28, "Rechercher", "search")
    box:SetPoint("TOPLEFT", 10, -60)
    box:SetPoint("TOPRIGHT", -10, -60)
    self.sideSearch = box
    local list = CreateFrame("Frame", nil, side)
    list:SetFrameStrata("DIALOG")
    list:SetWidth(340)
    list:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    UI:Panel(list, 10, { C.bg[1], C.bg[2], C.bg[3], 0.98 }, C.border)
    list:Hide()
    local rows, results = {}, {}
    local function row(i)
        local r = rows[i]
        if not r then
            r = CreateFrame("Button", nil, list)
            r:SetHeight(34)
            r.hl = UI:Rounded(r, 6, 0, "BACKGROUND", 2)
            r.hl:Hide()
            r.kind = UI:Text(r, 9, C.dim)
            r.kind:SetPoint("TOPRIGHT", -10, -6)
            r.label = UI:Text(r, 12)
            r.label:SetPoint("TOPLEFT", 10, -4)
            r.label:SetPoint("RIGHT", -70, 0)
            r.label:SetJustifyH("LEFT")
            r.sub = UI:Text(r, 10, C.muted)
            r.sub:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
            r.sub:SetPoint("RIGHT", -10, 0)
            r.sub:SetJustifyH("LEFT")
            r:SetScript("OnEnter", function(s) s.hl:SetColor(unpack(C.hover)); s.hl:Show() end)
            r:SetScript("OnLeave", function(s) s.hl:Hide() end)
            r:SetScript("OnClick", function(s)
                list:Hide()
                box.edit:ClearFocus()
                if s.res then s.res.run() end
            end)
            rows[i] = r
        end
        return r
    end
    local empty = UI:Text(list, 11, C.muted)
    empty:SetPoint("TOPLEFT", 12, -12)
    empty:SetText(T("Aucun résultat"))
    local function show(text)
        if not text or #text < 2 then list:Hide() return end
        -- toutes les pages ne sont construites que s'il n'y a pas encore d'index pour cette version
        if not stored() then buildAll(); pcall(snapshot) end
        results = search(text)
        for _, r in ipairs(rows) do r:Hide() end
        local y = -6
        for i, res in ipairs(results) do
            if i > MAX then break end
            local r = row(i)
            r.res = res
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:SetPoint("TOPRIGHT", -4, y)
            local UP = { ["Réglage"] = "RÉGLAGE", ["Setting"] = "SETTING" }
            r.kind:SetText(UP[res.kind] or string.upper(res.kind))
            r.label:SetText(res.label)
            r.sub:SetText(res.sub or "")
            r:SetHeight(res.sub and 34 or 24)
            r.label:ClearAllPoints(); r.label:SetPoint("TOPLEFT", 10, res.sub and -4 or -6); r.label:SetPoint("RIGHT", -70, 0)
            r:Show()
            y = y - (res.sub and 34 or 24)
        end
        empty:SetShown(#results == 0)
        if #results > MAX then
            empty:Show()
            empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", 12, y - 4)
            empty:SetText(string.format(T("+ %d autres : précise ta recherche"), #results - MAX))
            y = y - 22
        else
            empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", 12, -12)
            empty:SetText(T("Aucun résultat"))
            if #results == 0 then y = -34 end
        end
        list:SetHeight(-y + 6)
        list:Show()
    end
    box.onChange = function(text) show(text) end
    box.onEnter = function()
        local first = results[1]
        list:Hide()
        if first then first.run() end
    end
    box.edit:HookScript("OnEscapePressed", function() box:SetText(""); list:Hide() end)
    box.edit:HookScript("OnEditFocusGained", function() show(box:GetText()) end)
    -- la liste se ferme quand la souris quitte la barre et la liste après un clic ailleurs
    list:SetScript("OnUpdate", function(s)
        if not box.edit:HasFocus() and not s:IsMouseOver() and not box:IsMouseOver() then s:Hide() end
    end)
    return box
end
