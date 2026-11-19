local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Couleurs de sens de la palette (UI/Themes.lua), lues à l'affichage : ajouts en vert (positive),
-- modifications en ambre (warning), corrections en rouge doux (negative).

local function notesSeen() return WK.DB.global.settings.notesSeenVersion == WK.version end

-- Texte à la ligne automatique (largeur posée par la mise en page de la carte)
local function wrapped(parent, text, color, size)
    local fs = UI:Text(parent, size or 12, color)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(3)
    fs:SetText(text)
    return fs
end

-- Patch notes : section « Patch notes » des Options (sous Profils), construite à la première ouverture
-- (UI/Pages/Options.lua). UI:ShowPage("notes") ouvre les Options sur cette section.
UI.notesDef = {
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        -- deux onglets : notes de version (sommaire à gauche) et « À venir » rangé par thème
        local nTodo = #(WK.Roadmap or {})
        local views = {}
        local tabSeg = UI:Segmented(p, { { "notes", "Notes de version" }, { "todo", string.format(T("À venir · %d"), nTodo) } },
            function(v) for k, f in pairs(views) do f:SetShown(k == v or (k == "notesBar" and v == "notes")) end end, 30)
        tabSeg:SetPoint("TOPLEFT")
        local function view(key)
            local f = CreateFrame("Frame", nil, p)
            f:SetPoint("TOPLEFT", 0, -44); f:SetPoint("BOTTOMRIGHT")
            views[key] = f
            return f
        end

        -----------------------------------------------------------------
        -- Notes de version : sommaire à gauche (clic : saute à la version), cartes à droite.
        -- Plus de 400 versions : cartes créées par lots de 15 (sinon la page est trop lourde et reste vide).
        -----------------------------------------------------------------
        -- Notes de version : fil groupé par jour. Chaque jour = une carte (le plus récent déplié, les autres
        -- sur une ligne, clic = déplier) ; chaque version = son numéro à gauche et ses notes en entier à droite,
        -- marquées + ~ !. Recherche et filtres en haut (ajouts, modifications, corrections, depuis ta dernière
        -- visite). Seuls les jours dépliés créent leurs lignes (plus de 400 versions).
        -----------------------------------------------------------------
        local nv = view("notes")
        -- recherche et filtres sur leur propre ligne, sous les onglets (à côté, ils sortaient de la fenêtre)
        nv:SetPoint("TOPLEFT", 0, -82)
        local bar = CreateFrame("Frame", nil, p)
        bar:SetPoint("TOPLEFT", 0, -40); bar:SetPoint("TOPRIGHT", 0, -40); bar:SetHeight(30)
        views.notesBar = bar
        local search = UI:Input(bar, 230, 30, "Rechercher dans les notes...", "search")
        search:SetPoint("LEFT")
        local st = { filter = "all", query = "", open = {} }
        -- versions plus récentes que la dernière visite (retenue avant que la page ne la mette à jour)
        local prevSeen = WK.DB.global.settings.notesSeenVersion
        local newCount = 0
        for i, e in ipairs(WK.Changelog) do if e.version == prevSeen then newCount = i - 1 break end end
        local chips = {}
        local render
        local function chip(key, label, icon)
            local b = UI:Button(bar, label, nil, 26, "ghost", icon)
            b:SetScript("OnClick", function()
                st.filter = (st.filter == key and key ~= "all") and "all" or key
                for k, c in pairs(chips) do c:SetStyle(k == st.filter and "secondary" or "ghost") end
                render()
            end)
            chips[key] = b
            return b
        end
        local x = 242
        for _, c in ipairs({ { "all", "Tout" }, { "added", "+ Ajouts" }, { "changed", "Modifications", "refresh" }, { "fixed", "Corrections", "warn" } }) do
            local b = chip(c[1], c[2], c[3]); b:SetPoint("LEFT", x, 0); x = x + b:GetWidth() + 6
        end
        if newCount > 0 then
            local b = chip("new", string.format(T("Depuis ma dernière visite · %d"), newCount)); b:SetPoint("LEFT", x, 0)
        end
        chips.all:SetStyle("secondary")
        search.onChange = function(t) st.query = string.lower(t or ""); render() end

        -- jours
        local DAYS = { "Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi" }
        local MONTHS = { "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre" }
        local function dayName(d)
            local dd, mm, yy = (d or ""):match("(%d+)/(%d+)/(%d+)")
            if not dd then return d or "?" end
            local wd
            if time and date then
                local ok, t = pcall(time, { year = tonumber(yy), month = tonumber(mm), day = tonumber(dd), hour = 12 })
                if ok and t then wd = tonumber(date("%w", t)) end
            end
            local txt = tonumber(dd) .. " " .. T(MONTHS[tonumber(mm)] or mm)
            if wd then txt = T(DAYS[wd + 1]) .. " " .. txt end
            if tonumber(yy) ~= tonumber(date and date("%Y") or yy) then txt = txt .. " " .. yy end
            return txt
        end
        local days = {}
        for i, e in ipairs(WK.Changelog) do
            local last = days[#days]
            if not last or last.date ~= e.date then last = { date = e.date, list = {} }; days[#days + 1] = last end
            last.list[#last.list + 1] = i
        end
        st.open[1] = true

        local scroll = UI:Scroll(nv)
        scroll:SetAllPoints()
        local SEC = { added = { "+", "positive" }, changed = { "refresh", "warning" }, fixed = { "warn", "negative" } }
        -- signe d'une rubrique dans un texte : + en lettre, modification = flèches circulaires, correction =
        -- triangle d'avertissement (petites icônes teintées ; le « ~ » des polices du jeu est disgracieux)
        local function glyph(k, size)
            local col = C[SEC[k][2]]
            if k == "added" then return UI:Hex(col) .. "+" end
            return string.format("|T%s%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t%s", UI.MEDIA, SEC[k][1], size or 11, size or 11,
                math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255), UI:Hex(col))
        end
        local ORDER = { "added", "changed", "fixed" }
        local cardPool = UI:Pool(function()
            local c = UI:Card(scroll.child)
            c.head = CreateFrame("Button", nil, c); c.head:SetPoint("TOPLEFT"); c.head:SetPoint("TOPRIGHT"); c.head:SetHeight(40)
            c.chev = UI:Icon(c.head, "chevron", 12, C.muted, "ARTWORK"); c.chev:SetPoint("LEFT", 14, 0)
            c.title = UI:Text(c.head, 14, C.text); c.title:SetPoint("LEFT", 32, 0)
            c.meta = UI:Text(c.head, 11, C.muted); c.meta:SetPoint("LEFT", c.title, "RIGHT", 10, 0)
            c.head:SetScript("OnClick", function() st.open[c.day] = not st.open[c.day]; render() end)
            return c
        end)
        local verPool = UI:Pool(function()
            local v = UI:Text(scroll.child, 13, C.text)
            return v
        end)
        local subPool = UI:Pool(function() return UI:Text(scroll.child, 10, C.positive) end)
        local linePool = UI:Pool(function()
            local l = CreateFrame("Frame", nil, scroll.child)
            l.tag = CreateFrame("Frame", nil, l); l.tag:SetSize(20, 16); l.tag:SetPoint("TOPLEFT", 0, 0)
            l.tag.bg = UI:Rounded(l.tag, 8, 0, "BACKGROUND", 1)
            l.tag.t = UI:Text(l.tag, 11); l.tag.t:SetPoint("CENTER", 0, 0)
            l.fs = wrapped(l, "", C.text, 12); l.fs:SetPoint("TOPLEFT", 28, -1)
            return l
        end)
        local empty = UI:Text(scroll.child, 12, C.muted)

        local function matches(line, key, idx)
            if st.filter == "new" and idx > newCount then return false end
            if st.filter ~= "all" and st.filter ~= "new" and st.filter ~= key then return false end
            if st.query ~= "" and not string.find(string.lower(line), st.query, 1, true) then return false end
            return true
        end

        render = function()
            local W = math.max(400, (scroll:GetWidth() or UI.PAGE_W) - 12)
            scroll.child:SetWidth(W)
            cardPool:Reset(); verPool:Reset(); subPool:Reset(); linePool:Reset()
            local r1, g1, b1 = UI:Accent()
            local filtering = st.filter ~= "all" or st.query ~= ""
            local y, shownDays, budget = 0, 0, 400
            for di, day in ipairs(days) do
                -- lignes retenues de ce jour : { idx, entry, { { key, texte } } }
                local vers, nLines, cnt = {}, 0, { added = 0, changed = 0, fixed = 0 }
                for _, idx in ipairs(day.list) do
                    local e = WK.Changelog[idx]
                    local ls = {}
                    for _, k in ipairs(ORDER) do
                        for _, line in ipairs(e[k] or {}) do
                            if matches(line, k, idx) then ls[#ls + 1] = { k, line }; cnt[k] = cnt[k] + 1 end
                        end
                    end
                    if #ls > 0 then vers[#vers + 1] = { idx, e, ls }; nLines = nLines + #ls end
                end
                if #vers > 0 then
                    shownDays = shownDays + 1
                    local open = st.open[di] or (filtering and budget > 0)
                    local c = cardPool:Get()
                    c.day = di
                    c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, -y); c:SetPoint("TOPRIGHT", 0, -y)
                    c.title:SetText(dayName(day.date))
                    local restart = false
                    for _, v in ipairs(vers) do if v[2].restart then restart = true end end
                    local parts = { string.format(#vers > 1 and T("%d versions") or T("%d version"), #vers) }
                    for _, k in ipairs(ORDER) do
                        if cnt[k] > 0 then parts[#parts + 1] = glyph(k) .. (k ~= "added" and " " or "") .. cnt[k] .. "|r" end
                    end
                    parts[#parts + 1] = restart and (UI:Hex(C.warning) .. T("redémarrer le jeu") .. "|r") or T("/reload suffit")
                    c.meta:SetText(table.concat(parts, "  ·  "))
                    c.chev:SetRotation(open and 0 or math.pi / 2)
                    local h = 40
                    if open then
                        local textW = W - 16 - 90 - 28 - 16
                        for _, v in ipairs(vers) do
                            local idx, e, ls = v[1], v[2], v[3]
                            local vf = verPool:Get()
                            vf:ClearAllPoints(); vf:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -h)
                            vf:SetText(e.version); vf:SetTextColor(r1, g1, b1)
                            local vy = h
                            if idx == 1 and e.version == WK.version then
                                local sub = subPool:Get(); sub:SetTextColor(unpack(C.positive))
                                sub:ClearAllPoints(); sub:SetPoint("TOPLEFT", vf, "BOTTOMLEFT", 0, -2); sub:SetText(T("installée"))
                            elseif e.restart then
                                local sub = subPool:Get(); sub:SetTextColor(unpack(C.warning))
                                sub:ClearAllPoints(); sub:SetPoint("TOPLEFT", vf, "BOTTOMLEFT", 0, -2); sub:SetText(T("redémarrer"))
                            end
                            for _, ln in ipairs(ls) do
                                budget = budget - 1
                                local l = linePool:Get()
                                local col = C[SEC[ln[1]][2]]
                                l.tag.bg:SetColor(col[1], col[2], col[3], 0.18)
                                l.tag.t:SetText(glyph(ln[1], 10) .. "|r"); l.tag.t:SetTextColor(unpack(col))
                                l.fs:SetWidth(textW); l.fs:SetText(ln[2])
                                local lh = math.max(16, l.fs:GetStringHeight() or 16)
                                l:ClearAllPoints(); l:SetPoint("TOPLEFT", c, "TOPLEFT", 16 + 90, -h); l:SetSize(textW + 28, lh)
                                h = h + lh + 6
                            end
                            h = math.max(h, vy + 34) + 6
                        end
                        h = h + 6
                    end
                    c:SetHeight(h)
                    y = y + h + 10
                end
            end
            empty:SetShown(shownDays == 0)
            empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", 4, -4)
            empty:SetText(T("Aucune note ne correspond."))
            scroll:SetContentHeight(y)
            self.feedHeight, self.feedDays = y, shownDays
        end
        self.feedRender = render
        self.feedState = st
        UI:OnResize(scroll, function() render() end)
        UI:OnAccent(function() if nv:IsVisible() then render() end end)

        -----------------------------------------------------------------
        -- À venir : une colonne par thème (masonry sur 3 colonnes), une carte par idée (titre + phrase)
        -----------------------------------------------------------------
        local tv = view("todo")
        local ts = UI:Scroll(tv)
        ts:SetAllPoints()
        local blocks = {}
        for _, th in ipairs(WK.RoadmapThemes or {}) do
            local list = {}
            for _, it in ipairs(WK.Roadmap or {}) do if it.theme == th.key then list[#list + 1] = it end end
            if #list > 0 then
                local blk = CreateFrame("Frame", nil, ts.child)
                blk.dot = UI:Icon(blk, "circle", 8, nil, "ARTWORK"); blk.dot:SetPoint("TOPLEFT", 2, -4)
                blk.head = UI:Text(blk, 10, C.dim); blk.head:SetPoint("TOPLEFT", 16, -2)
                blk.head:SetText(string.upper(T(th.label)))
                local function tint()
                    local col = th.color == "accent" and { UI:Accent() } or C[th.color] or C.muted
                    blk.dot:SetVertexColor(col[1], col[2], col[3], 1)
                end
                tint(); UI:OnAccent(tint)
                blk.items = {}
                for _, it in ipairs(list) do
                    local box = CreateFrame("Frame", nil, blk)
                    UI:Panel(box, 9, C.surface2, C.border)
                    box.t = UI:Text(box, 12, C.text); box.t:SetPoint("TOPLEFT", 11, -9); box.t:SetJustifyH("LEFT")
                    box.t:SetText(T(it.title))
                    box.d = wrapped(box, T(it.text), C.muted, 11)
                    box.d:SetPoint("TOPLEFT", box.t, "BOTTOMLEFT", 0, -4)
                    table.insert(blk.items, box)
                end
                -- hauteur naturelle de chaque carte à la largeur w (alignées ensuite rangée par rangée)
                function blk.Measure(b, w)
                    b.hs = {}
                    for k, box in ipairs(b.items) do
                        box.t:SetWidth(w - 22); box.d:SetWidth(w - 22)
                        b.hs[k] = 9 + (box.t:GetStringHeight() or 14) + 4 + (box.d:GetStringHeight() or 14) + 10
                    end
                end
                table.insert(blocks, blk)
            end
        end
        -- grille : les thèmes par rangées de 3 (2 si étroit), même haut pour chaque rangée ; dans une rangée,
        -- la k-ième carte a la même hauteur dans toutes les colonnes (les cartes s'alignent d'une colonne à l'autre)
        UI:OnResize(ts, function(w)
            local W = math.max(360, (w or ts:GetWidth() or UI.PAGE_W) - 12)
            local cols = W < 760 and 2 or 3
            local GAP, VG, HEAD = 12, 7, 22
            local cw = math.floor((W - GAP * (cols - 1)) / cols)
            for _, blk in ipairs(blocks) do blk:Measure(cw) end
            local y = 0
            for r0 = 1, #blocks, cols do
                local maxN = 0
                for c = 0, cols - 1 do local blk = blocks[r0 + c]; if blk then maxN = math.max(maxN, #blk.items) end end
                local rowH = {}
                for k = 1, maxN do
                    rowH[k] = 0
                    for c = 0, cols - 1 do
                        local blk = blocks[r0 + c]
                        if blk and blk.hs[k] then rowH[k] = math.max(rowH[k], blk.hs[k]) end
                    end
                end
                local h = HEAD
                for k = 1, maxN do h = h + rowH[k] + VG end
                for c = 0, cols - 1 do
                    local blk = blocks[r0 + c]
                    if blk then
                        blk:ClearAllPoints(); blk:SetPoint("TOPLEFT", c * (cw + GAP), -y); blk:SetSize(cw, h)
                        local by = HEAD
                        for k, box in ipairs(blk.items) do
                            box:ClearAllPoints(); box:SetPoint("TOPLEFT", 0, -by); box:SetSize(cw, rowH[k])
                            by = by + rowH[k] + VG
                        end
                    end
                end
                y = y + h + 14
            end
            ts:SetContentHeight(y)
        end)

        tabSeg:Select("notes")
        views.todo:Hide()
    end,

    Refresh = function()
        WK.DB.global.settings.notesSeenVersion = WK.version
    end,
}
