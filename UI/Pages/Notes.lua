local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Couleurs de sens de la palette (UI/Themes.lua), lues à l'affichage : ajouts en vert (positive),
-- modifications en ambre (warning), corrections en rouge doux (negative).
local SECTIONS = {
    { "added", "+  AJOUTS", "positive" },
    { "changed", "~  MODIFICATIONS", "warning" },
    { "fixed", "!  CORRECTIONS", "negative" },
}

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

-- Carte d'une version (ou de la feuille de route). Les éléments sont créés une fois ;
-- card:Layout(largeur) les place et renvoie la hauteur (appelé à chaque changement de taille).
local function VersionCard(parent, entry, isCurrent)
    local card = UI:Card(parent, nil, nil, isCurrent)

    local title = UI:Text(card, 16)
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(entry.roadmap and "À venir" or ("v" .. entry.version))
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local after = title
    if entry.date then
        local d = UI:Badge(card, entry.date, C.muted)
        d:SetPoint("LEFT", after, "RIGHT", 10, 0)
        after = d
    end
    if not entry.roadmap then
        local r = entry.restart and UI:Badge(card, T("redémarrer le jeu"), C.warning) or UI:Badge(card, T("/reload suffit"), C.muted)
        r:SetPoint("LEFT", after, "RIGHT", 6, 0)
        after = r
    end
    if isCurrent then
        local cur = UI:Badge(card, "version installée")
        cur:SetPoint("LEFT", after, "RIGHT", 6, 0)
    end
    if entry.roadmap then
        local hint = UI:Text(card, 11, C.muted)
        hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
        hint:SetText("prévu, pas encore commencé")
    end

    -- éléments à placer : { kind = "bullet", dot, fs } / { kind = "head", badge, stripe } / { kind = "end", stripe }
    local parts = {}
    local function bullets(list, color)
        for _, line in ipairs(list) do
            table.insert(parts, { kind = "bullet", dot = UI:Icon(card, "circle", 5, color or C.muted, "ARTWORK"),
                fs = wrapped(card, line, C.text, 12) })
        end
    end
    if entry.roadmap then
        bullets(entry.items, C.dim)
    else
        for _, sec in ipairs(SECTIONS) do
            local list = entry[sec[1]]
            if list and #list > 0 then
                -- liseré de la couleur de la rubrique, sur toute sa hauteur
                local stripe = card:CreateTexture(nil, "ARTWORK")
                local col = C[sec[3]]
                stripe:SetColorTexture(unpack(col))
                table.insert(parts, { kind = "head", badge = UI:Badge(card, sec[2], col), stripe = stripe })
                bullets(list, col)
                table.insert(parts, { kind = "end", stripe = stripe })
            end
        end
    end

    function card:Layout(width)
        local h, top = 48, 0
        local textW = width - 18 - 34 - 18
        for _, e in ipairs(parts) do
            if e.kind == "head" then
                top = h
                e.badge:ClearAllPoints(); e.badge:SetPoint("TOPLEFT", 26, -h)
                h = h + 26
            elseif e.kind == "bullet" then
                e.dot:ClearAllPoints(); e.dot:SetPoint("TOPLEFT", 30, -h - 6)
                e.fs:ClearAllPoints(); e.fs:SetPoint("TOPLEFT", 44, -h); e.fs:SetWidth(textW)
                h = h + (e.fs:GetStringHeight() or 16) + 7
            else
                e.stripe:ClearAllPoints(); e.stripe:SetPoint("TOPLEFT", 16, -top)
                e.stripe:SetSize(3, math.max(1, h - top - 2))
                h = h + 6
            end
        end
        h = h + 10
        self:SetHeight(h)
        return h
    end
    return card
end

UI:RegisterPage({
    key = "notes", order = 9, navIcon = "notes",
    title = "Patch notes",
    subtitle = "Tout ce qui a été ajouté, modifié et corrigé, version par version.",
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        -- deux onglets : notes de version (sommaire à gauche) et « À venir » rangé par thème
        local nTodo = #(WK.Roadmap or {})
        local views = {}
        local tabSeg = UI:Segmented(p, { { "notes", "Notes de version" }, { "todo", string.format(T("À venir · %d"), nTodo) } },
            function(v) for k, f in pairs(views) do f:SetShown(k == v) end end, 30)
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
        local nv = view("notes")
        local IDX_W = 196
        -- sommaire dans sa propre carte : versions groupées par date, contenu en pastilles (+ ~ !)
        local idxCard = UI:Card(nv)
        idxCard:SetPoint("TOPLEFT"); idxCard:SetPoint("BOTTOMLEFT"); idxCard:SetWidth(IDX_W)
        local idx = UI:Scroll(idxCard)
        idx:SetPoint("TOPLEFT", 6, -8); idx:SetPoint("BOTTOMRIGHT", -2, 8)
        local scroll = UI:Scroll(nv)
        scroll:SetPoint("TOPLEFT", IDX_W + 12, 0); scroll:SetPoint("BOTTOMRIGHT")
        local cards, rows, made = {}, {}, 0
        local PAGE = 15
        local more = UI:Button(scroll.child, "Versions plus anciennes", 240, 30, "secondary")
        local idxMoreB = UI:Button(idx.child, "+ plus anciennes", IDX_W - 24, 26, "ghost")
        local heads = {}   -- titres de date : { fs, before = n° de la 1re ligne de ce jour }
        local sel = 1
        local layout
        local function paintRows()
            local r1, g1, b1 = UI:Accent()
            for i, r in ipairs(rows) do
                local on = i == sel
                r.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], on and 1 or (r.hover and 0.55 or 0))
                r.bar:SetColorTexture(r1, g1, b1, 1); r.bar:SetShown(on)
                if on then r.v:SetTextColor(r1, g1, b1) else r.v:SetTextColor(unpack(r.hover and C.text or C.muted)) end
            end
        end
        UI:OnAccent(paintRows)
        local function counts(entry)
            local parts = {}
            for _, sec in ipairs(SECTIONS) do
                local n = entry[sec[1]] and #entry[sec[1]] or 0
                if n > 0 then parts[#parts + 1] = UI:Hex(C[sec[3]]) .. sec[2]:sub(1, 1) .. n .. "|r" end
            end
            return table.concat(parts, " ")
        end
        local function addBatch()
            local last = math.min(#WK.Changelog, made + PAGE)
            for i = made + 1, last do
                local entry = WK.Changelog[i]
                local ok, card = pcall(VersionCard, scroll.child, entry, i == 1 and entry.version == WK.version)
                if ok and card then
                    table.insert(cards, card)
                    local n = #rows + 1
                    local prev = WK.Changelog[i - 1]
                    if i == 1 or not prev or prev.date ~= entry.date then
                        local h = UI:Text(idx.child, 10, C.dim)
                        h:SetText(entry.date or "")
                        heads[#heads + 1] = { fs = h, before = n }
                    end
                    local r = CreateFrame("Button", nil, idx.child)
                    r:SetHeight(26)
                    r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
                    r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT", 0, -5); r.bar:SetPoint("BOTTOMLEFT", 0, 5); r.bar:SetWidth(3)
                    r.v = UI:Text(r, 13, C.muted); r.v:SetPoint("LEFT", 12, 0); r.v:SetText("v" .. entry.version)
                    r.d = UI:Text(r, 10, C.muted); r.d:SetPoint("RIGHT", -8, 0); r.d:SetText(counts(entry))
                    if i == 1 and entry.version == WK.version then
                        r.cur = UI:Icon(r, "circle", 6, C.positive, "ARTWORK"); r.cur:SetPoint("LEFT", r.v, "RIGHT", 5, 0)
                    end
                    r:SetScript("OnEnter", function() r.hover = true; paintRows() end)
                    r:SetScript("OnLeave", function() r.hover = false; paintRows() end)
                    r:SetScript("OnClick", function()
                        sel = n; paintRows()
                        scroll:SetVerticalScroll(math.min(scroll:MaxScroll(), card.y or 0)); scroll:UpdateBar()
                    end)
                    rows[n] = r
                end
            end
            made = last
            more:SetShown(made < #WK.Changelog)
            more:SetLabel(string.format(T("Versions plus anciennes (%d)"), #WK.Changelog - made))
            idxMoreB:SetShown(made < #WK.Changelog)
            idxMoreB:SetLabel(string.format(T("+ %d plus anciennes"), #WK.Changelog - made))
            paintRows()
        end
        layout = function(w)
            local width = math.max(360, (w or scroll:GetWidth() or UI.PAGE_W) - 12)
            local y = 0
            for _, c in ipairs(cards) do
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", 0, -y)
                c:SetPoint("TOPRIGHT", 0, -y)
                c.y = y
                y = y + c:Layout(width) + 12
            end
            if more:IsShown() then
                more:ClearAllPoints(); more:SetPoint("TOP", scroll.child, "TOP", 0, -y)
                y = y + 42
            end
            scroll:SetContentHeight(y)
            local iy = 0
            idx.child:SetWidth(IDX_W - 8)
            local hi = 1
            for n, r in ipairs(rows) do
                local h = heads[hi]
                if h and h.before == n then
                    h.fs:ClearAllPoints(); h.fs:SetPoint("TOPLEFT", 12, -(iy + (n > 1 and 8 or 2)))
                    iy = iy + (n > 1 and 24 or 18)
                    hi = hi + 1
                end
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -iy); r:SetPoint("TOPRIGHT", -10, -iy)
                iy = iy + 28
            end
            if idxMoreB:IsShown() then
                idxMoreB:ClearAllPoints(); idxMoreB:SetPoint("TOPLEFT", 6, -(iy + 6))
                iy = iy + 38
            end
            idx:SetContentHeight(iy)
        end
        local function loadMore() addBatch(); layout() end
        more:SetScript("OnClick", loadMore)
        idxMoreB:SetScript("OnClick", loadMore)
        addBatch()
        UI:OnResize(scroll, layout)

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
})
