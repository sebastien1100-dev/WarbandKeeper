local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

---------------------------------------------------------------------------
-- Journal des données (Modules/DataLog.lua) : onglet « Journal » de la page Quêtes (UI:BuildDataJournal),
-- message après une nouvelle base (HUD « dataToast »), carte de réglages de la roue (UI:BuildDataLogCard).
---------------------------------------------------------------------------
local function DL() return WK.modules.DataLog end
local function Q() return WK.modules.Quests end

local function levelColor(lvl)
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, lvl or 0)
        if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    return 0.85, 0.85, 0.85
end
local function zoneName(map)
    local R = WK.modules.Rares
    return map and map > 0 and R and R.ZoneName and R:ZoneName(map) or ""
end
local function dayLabel(t)
    local today = date("%d/%m/%Y")
    local d = date("%d/%m/%Y", t)
    if d == today then return UI:Upper(T("Aujourd'hui")) .. " · " .. date("%d/%m", t) end
    if d == date("%d/%m/%Y", time() - 86400) then return UI:Upper(T("Hier")) .. " · " .. date("%d/%m", t) end
    return d
end

---------------------------------------------------------------------------
-- Onglet « Journal »
---------------------------------------------------------------------------
local FILTERS = { { "all", "Tout" }, { "db", "QuestieDB" }, { "learn", "Appris en jeu" }, { "zone", "Ma zone" }, { "level", "Mon niveau" } }
local MAX_LINES = 12

function UI.BuildDataJournal(_, parent)
    local f = CreateFrame("Frame", nil, parent)
    f.filter = "all"
    f.open = {}
    -- chiffres clés
    f.kpis = {}
    for i = 1, 4 do
        local k = CreateFrame("Frame", nil, f)
        k:SetHeight(52)
        k.bg = UI:Rounded(k, 10, 0, "BACKGROUND", 1); k.bg:SetColor(unpack(C.surface2))
        k.v = UI:Text(k, 17); k.v:SetPoint("TOPLEFT", 12, -9)
        k.l = UI:Text(k, 10, C.muted); k.l:SetPoint("TOPLEFT", 12, -33)
        f.kpis[i] = k
    end
    f.seg = UI:Segmented(f, FILTERS, function(v) f.filter = v; f:Refresh() end, 26)
    f.seg:Select("all")
    f.scroll = UI:Scroll(f)
    local child = f.scroll.child
    f.empty = UI:Text(child, 12, C.muted); f.empty:SetPoint("TOPLEFT", 4, -6)
    f.days, f.evs, f.lines = {}, {}, {}
    local function day(i)
        local d = f.days[i]
        if not d then d = UI:Text(child, 10, C.dim); f.days[i] = d end
        return d
    end
    local function ev(i)
        local e = f.evs[i]
        if not e then
            e = CreateFrame("Button", nil, child)
            e.bg = UI:Rounded(e, 9, 0, "BACKGROUND", 1)
            e.src = CreateFrame("Frame", nil, e); e.src:SetSize(28, 28); e.src:SetPoint("TOPLEFT", 10, -9)
            e.srcBg = UI:Rounded(e.src, 14, 0, "BACKGROUND", 2)
            e.srcTx = UI:Text(e.src, 11); e.srcTx:SetPoint("CENTER")
            e.title = UI:Text(e, 13); e.title:SetPoint("TOPLEFT", 48, -9); e.title:SetPoint("RIGHT", -80, 0)
            e.right = UI:Text(e, 10, C.muted); e.right:SetPoint("TOPRIGHT", -12, -10); e.right:SetJustifyH("RIGHT")
            e.sub = UI:Text(e, 11, C.muted); e.sub:SetPoint("TOPLEFT", 48, -28); e.sub:SetPoint("RIGHT", -12, 0)
            if e.sub.SetWordWrap then e.sub:SetWordWrap(true) end
            e:SetScript("OnClick", function(s) if s.onClick then s.onClick() end end)
            f.evs[i] = e
        end
        return e
    end
    local function qline(i)
        local l = f.lines[i]
        if not l then
            l = CreateFrame("Button", nil, child); l:SetHeight(18)
            l.lv = UI:Text(l, 11); l.lv:SetPoint("LEFT", 0, 0); l.lv:SetWidth(24); l.lv:SetJustifyH("RIGHT")
            l.name = UI:Text(l, 11); l.name:SetPoint("LEFT", 32, 0); l.name:SetPoint("RIGHT", -170, 0)
            l.zone = UI:Text(l, 10, C.muted); l.zone:SetPoint("RIGHT", 0, 0); l.zone:SetWidth(160); l.zone:SetJustifyH("RIGHT")
            l.hl = l:CreateTexture(nil, "HIGHLIGHT"); l.hl:SetAllPoints(); l.hl:SetColorTexture(1, 1, 1, 0.04)
            l:SetScript("OnClick", function(s) if s.q then Q():GuideTo(s.q) end end)
            l:SetScript("OnEnter", function(s)
                if not s.q then return end
                UI:TooltipOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(Q():Name(s.q), 1, 1, 1)
                if s.q.x then GameTooltip:AddLine(T("Clic : guider vers le donneur"), 0.6, 0.6, 0.6) end
                GameTooltip:Show()
            end)
            l:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.lines[i] = l
        end
        return l
    end

    -- quêtes d'une mise à jour, filtrées (zone / niveau)
    local function pass(q)
        if not q then return f.filter ~= "zone" and f.filter ~= "level" end
        if f.filter == "zone" then return q.map == Q():PlayerZone() end
        if f.filter == "level" then
            local lvl = UnitLevel and UnitLevel("player") or 1
            return math.abs((q.lvl or 0) - lvl) <= 5
        end
        return true
    end

    function f:Layout(w, h)
        local kw = math.floor((w - 3 * 10) / 4)
        for i, k in ipairs(self.kpis) do
            k:ClearAllPoints(); k:SetPoint("TOPLEFT", (i - 1) * (kw + 10), 0); k:SetWidth(kw)
        end
        self.seg:ClearAllPoints(); self.seg:SetPoint("TOPLEFT", 0, -64)
        self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT", 0, -100); self.scroll:SetPoint("BOTTOMRIGHT")
        self.w = w
    end

    function f:Refresh()
        local dl = DL()
        local Qm = Q()
        if not (dl and Qm) then return end
        local W = math.max(400, (self.w or 700) - 14)
        -- chiffres clés
        local total, n30, learned = 0, 0, Qm:LearnedCount()
        for _, list in pairs(WK.QuestsDB or {}) do total = total + #list end
        local cut = time() - 30 * 86400
        for _, e in ipairs(WK.DataLog or {}) do if (e.t or 0) >= cut then n30 = n30 + #(e.add or {}) end end
        local last = dl:Latest()
        local kv = {
            { tostring(total), T("quêtes dans la base"), C.text },
            { "+" .. n30, T("ajoutées en 30 jours"), C.rule },
            { tostring(learned), T("apprises en jeu"), C.plan },
            { last and date("%d/%m · %H:%M", last.t) or "-", T("dernière mise à jour de la base"), C.text },
        }
        for i, k in ipairs(self.kpis) do
            k.v:SetText(kv[i][1]); k.v:SetTextColor(unpack(kv[i][3])); k.l:SetText(kv[i][2])
        end
        -- fil
        local y, nd, ne, nl = 0, 0, 0, 0
        local lastDay
        local A = { UI:Accent() }
        for _, it in ipairs(dl:Entries()) do
            local show = (self.filter == "all") or (self.filter == "db" and it.kind == "db") or (self.filter == "learn" and it.kind == "learn")
                or self.filter == "zone" or self.filter == "level"
            local quests = {}
            if show and it.kind == "db" then
                for _, id in ipairs(it.e.add or {}) do
                    local q = Qm:Get(id)
                    if pass(q) then table.insert(quests, { q = q, id = id, kind = "new" }) end
                end
                for _, c in ipairs(it.e.chg or {}) do
                    local q = Qm:Get(c[1])
                    if pass(q) then table.insert(quests, { q = q, id = c[1], kind = "chg", codes = c[2] }) end
                end
                if (self.filter == "zone" or self.filter == "level") and #quests == 0 then show = false end
            elseif show and it.kind == "learn" then
                local q = Qm:Get(it.id)
                if (self.filter == "zone" or self.filter == "level") and not pass(q) then show = false end
            end
            if show then
                local dk = date("%d/%m/%Y", it.t)
                if dk ~= lastDay then
                    lastDay = dk
                    nd = nd + 1
                    local d = day(nd)
                    d:ClearAllPoints(); d:SetPoint("TOPLEFT", 2, -(y + 6)); d:SetText(dayLabel(it.t)); d:Show()
                    y = y + 22
                end
                ne = ne + 1
                local e = ev(ne)
                e:ClearAllPoints(); e:SetPoint("TOPLEFT", 0, -y); e:SetWidth(W)
                e.bg:SetColor(unpack(C.surface2))
                local h = 46
                if it.kind == "db" then
                    local x = it.e
                    e.srcBg:SetColor(C.rule[1], C.rule[2], C.rule[3], 0.16); e.srcTx:SetText("Q"); e.srcTx:SetTextColor(unpack(C.rule))
                    e.title:SetText(string.format(T("Mise à jour de la base · %s"), x.src or "QuestieDB"))
                    e.right:SetText(date("%H:%M", it.t))
                    local parts = {}
                    if #(x.add or {}) > 0 then table.insert(parts, UI:Hex(C.positive) .. string.format(T("+%d quêtes"), #x.add) .. "|r") end
                    if #(x.chg or {}) > 0 then table.insert(parts, UI:Hex(C.warning) .. string.format(T("%d corrigées"), #x.chg) .. "|r") end
                    if #(x.rem or {}) > 0 then table.insert(parts, UI:Hex(C.negative) .. string.format(T("%d retirées"), #x.rem) .. "|r") end
                    if (self.filter == "zone" or self.filter == "level") then table.insert(parts, string.format(T("%d pour toi"), #quests)) end
                    local opened = self.open[it.t]
                    table.insert(parts, UI:Hex(A) .. (opened and T("replier") or T("voir les quêtes")) .. "|r")
                    e.sub:SetText(table.concat(parts, "   "))
                    e.onClick = function() self.open[it.t] = not self.open[it.t]; self:Refresh() end
                    if opened then
                        local ly = 50
                        for k, qq in ipairs(quests) do
                            if k > MAX_LINES then break end
                            nl = nl + 1
                            local l = qline(nl)
                            l:ClearAllPoints(); l:SetPoint("TOPLEFT", e, "TOPLEFT", 48, -ly); l:SetPoint("RIGHT", e, "RIGHT", -12, 0)
                            local q = qq.q
                            l.q = q
                            l.lv:SetText(q and tostring(q.lvl or "") or ""); l.lv:SetTextColor(levelColor(q and q.lvl))
                            local nm = q and Qm:Name(q) or ("#" .. qq.id)
                            if qq.kind == "new" then nm = nm .. "  " .. UI:Hex(C.rule) .. T("NOUVELLE") .. "|r"
                            else nm = nm .. "  " .. UI:Hex(C.warning) .. dl:Describe(qq.codes) .. "|r" end
                            l.name:SetText(nm)
                            l.zone:SetText(q and zoneName(q.map) or "")
                            l:Show()
                            ly = ly + 18
                        end
                        if #quests > MAX_LINES then
                            nl = nl + 1
                            local l = qline(nl)
                            l:ClearAllPoints(); l:SetPoint("TOPLEFT", e, "TOPLEFT", 48, -ly); l:SetPoint("RIGHT", e, "RIGHT", -12, 0)
                            l.q = nil; l.lv:SetText(""); l.zone:SetText("")
                            l.name:SetText(UI:Hex(C.muted) .. string.format(T("+ %d autres (filtre « Ma zone » ou « Mon niveau » pour trier)"), #quests - MAX_LINES) .. "|r")
                            l:Show()
                            ly = ly + 18
                        end
                        h = ly + 8
                    end
                else
                    local x = it.e
                    local q = Qm:Get(it.id)
                    e.srcBg:SetColor(C.plan[1], C.plan[2], C.plan[3], 0.16); e.srcTx:SetText("J"); e.srcTx:SetTextColor(unpack(C.plan))
                    e.title:SetText(string.format(T("Quête apprise : %s"), x.n or ("#" .. it.id)))
                    e.right:SetText(date("%H:%M", it.t))
                    local parts = {}
                    if x.l then table.insert(parts, string.format(T("niveau %d"), x.l)) end
                    if x.k == "d" then table.insert(parts, T("quête de donjon")) end
                    local g = x.g or {}
                    if g.map and g.x then table.insert(parts, string.format(T("donneur : %s (%.1f %.1f)"), zoneName(g.map), g.x * 100, g.y * 100))
                    elseif g.npc then table.insert(parts, T("donneur noté")) end
                    if x.t then table.insert(parts, T("rendu noté")) end
                    e.sub:SetText(table.concat(parts, " · "))
                    e.onClick = q and q.x and function() Qm:GuideTo(q) end or nil
                end
                e:SetHeight(h)
                e:Show()
                y = y + h + 6
            end
        end
        for i = nd + 1, #self.days do self.days[i]:Hide() end
        for i = ne + 1, #self.evs do self.evs[i]:Hide() end
        for i = nl + 1, #self.lines do self.lines[i]:Hide() end
        self.empty:SetShown(ne == 0)
        self.empty:SetText(T("Rien dans le journal pour ce filtre."))
        child:SetSize(W, math.max(y, 30))
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
    end
    return f
end

---------------------------------------------------------------------------
-- Message après une nouvelle base (option)
---------------------------------------------------------------------------
local toast
local function openJournal()
    UI:ShowPage("quests")
    local p = UI.pages and UI.pages.quests
    if p and p.ShowTab then p:ShowTab("journal") end
end
local function buildToast()
    local f = CreateFrame("Frame", "WarbandKeeperDataToast", UIParent)
    f:SetSize(340, 86)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 11, { C.bg[1], C.bg[2], C.bg[3], 0.93 }, C.border)
    f.src = CreateFrame("Frame", nil, f); f.src:SetSize(30, 30); f.src:SetPoint("TOPLEFT", 12, -12)
    f.srcBg = UI:Rounded(f.src, 15, 0, "BACKGROUND", 2); f.srcBg:SetColor(C.rule[1], C.rule[2], C.rule[3], 0.16)
    f.srcTx = UI:Text(f.src, 12, C.rule); f.srcTx:SetPoint("CENTER"); f.srcTx:SetText("Q")
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 52, -12); f.title:SetText(T("Base de quêtes mise à jour"))
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("TOPLEFT", 52, -31); f.sub:SetPoint("RIGHT", -12, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(true) end
    f.close = UI:IconButton(f, "close", 16, "Fermer"); f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.see = UI:Button(f, T("Voir"), 70, 22, "secondary"); f.see:SetPoint("BOTTOMLEFT", 52, 10)
    f.see:SetScript("OnClick", function() f:Hide(); openJournal() end)
    f.add = UI:Button(f, T("Ajouter à la tournée"), 150, 22, "secondary"); f.add:SetPoint("LEFT", f.see, "RIGHT", 8, 0)
    f.add:SetScript("OnClick", function()
        local P = WK.modules.QuestPlan
        for _, q in ipairs(f.here or {}) do if P then P:SetPicked(q.id, true) end end
        WK:Print(string.format(T("%d nouvelle(s) quête(s) de ta zone cochée(s) pour la tournée."), #(f.here or {})))
        f:Hide()
    end)
    function f:Paint(added, chg, here, zone)
        self.here = here
        local parts = { string.format(T("+%d quêtes"), added) }
        if #here > 0 then table.insert(parts, string.format(T("dont %s à ton niveau"), UI:Hex(C.text) .. string.format(T("%d dans %s"), #here, zoneName(zone)) .. "|r")) end
        if chg > 0 then table.insert(parts, string.format(T("%d corrigées"), chg)) end
        self.sub:SetText(table.concat(parts, " · "))
        self.add:SetShown(#here > 0)
    end
    f:SetScript("OnUpdate", function(s, el)
        if s.sample then return end
        s.left = (s.left or 0) - el
        if s.left <= 0 and not s:IsMouseOver() then s:Hide() end
    end)
    f:Hide()
    UI:RegisterHUD("dataToast", f, { label = T("Base de quêtes mise à jour"), default = { 0, 220 },
        enabled = function() return DL() and DL():Config().toast end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(12, 9, { {}, {}, {} }, Q() and Q():PlayerZone()); f:Show() else f:Hide() end
        end,
        test = function() f.sample = nil; f.left = 12; f:Paint(12, 9, {}, nil); f:Show() end,
        testStop = function() f:Hide() end })
    return f
end
-- à la connexion : une fois par nouvelle base
function UI:CheckDataToast(force)
    local dl = DL()
    if not dl then return end
    local cfg = dl:Config()
    local e = dl:Latest()
    if not e then return end
    if not force and (cfg.seen or 0) >= (e.t or 0) then return end
    cfg.seen = e.t
    if not cfg.toast and not force then return end
    toast = toast or buildToast()
    local here, _, zone = dl:ForMe(e)
    toast:Paint(#(e.add or {}), #(e.chg or {}), here, zone)
    toast.left = 12
    toast:Show()
end
WK:On("PLAYER_LOGIN", function() C_Timer.After(8, function() pcall(UI.CheckDataToast, UI) end) end)

---------------------------------------------------------------------------
-- Réglages (roue de la page Quêtes)
---------------------------------------------------------------------------
function UI:BuildDataLogCard(card, toggles)
    local cfg = DL():Config()
    local function tg(field, after)
        local t = UI:Toggle(card, function() return cfg[field] and true or false end, function(v)
            cfg[field] = v; DL():Invalidate(); if after then after(v) end; WK:NotifyChanged()
        end)
        table.insert(toggles, t)
        return t
    end
    UI:SettingRow(card, -40, "Pastilles « Nouvelle »", "Dans « Quêtes de ma zone », la liste des zones, la tournée et la fenêtre du donjon : NOUVELLE (base mise à jour), APPRISE (notée en jeu), CORRIGÉE.", tg("badges"), 80)
    local seg = UI:Segmented(card, { { 3, "3 j" }, { 7, "7 j" }, { 14, "14 j" }, { 30, "30 j" } },
        function(v) cfg.days = v; DL():Invalidate(); WK:NotifyChanged() end, 24)
    seg:Select(cfg.days or 7)
    UI:SettingRow(card, -88, "Durée des pastilles", "Après ce temps, la quête redevient normale (elle reste dans le journal).", seg, 220)
    UI:SettingRow(card, -136, "Message après une mise à jour", "À la connexion, une fois par nouvelle base : ce qui change pour toi (quêtes de ta zone à ton niveau), avec « Voir » et « Ajouter à la tournée ».", tg("toast"), 80)
    local b = UI:Button(card, T("Ouvrir le journal"), 160, 26, "secondary", "notes")
    b:SetPoint("TOPLEFT", 16, -188)
    b:SetScript("OnClick", openJournal)
    return function() seg:Select(cfg.days or 7) end
end
