local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Rangement (Modules/Stash.lua), à la boîte aux lettres : panneau collé au courrier qui liste ce que ce perso
-- doit envoyer (au perso qui s'en sert, ou au perso HV), coché par défaut ; « Envoyer » passe par le moteur
-- d'envoi du courrier (Mail:SendWith). Réglage : Stash:Config().mailPanel.
local W, ROW_H = 300, 24
local panel
local unchecked = {} -- [objet] = true : décoché pour cette ouverture de la boîte

local function S() return WK.modules.Stash end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperStashMail", UIParent)
    f:SetSize(W, 220)
    f:EnableMouse(true)
    f:SetFrameStrata("HIGH")
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "send", 16, nil, "ARTWORK")
    f.logo:SetPoint("TOPLEFT", 14, -12)
    f.title = UI:Text(f, 12)
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
    f.title:SetText(T("Rangement"))
    f.close = UI:IconButton(f, "close", 16)
    f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 6, -36)
    f.scroll:SetPoint("BOTTOMRIGHT", -6, 48)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Button", nil, f.scroll.child)
        r:SetHeight(ROW_H)
        r.box = r:CreateTexture(nil, "ARTWORK")
        r.box:SetTexture(UI.MEDIA .. "circle"); r.box:SetSize(12, 12); r.box:SetPoint("LEFT", 8, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 26, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 50, 0); r.name:SetPoint("RIGHT", -60, 0); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.tag = UI:Text(r, 10, C.gold); r.tag:SetPoint("RIGHT", -8, 0)
        r:RegisterForClicks("AnyUp")
        r:SetScript("OnClick", function(s, btn)
            if not s.e then return end
            if btn == "RightButton" then if UI.StashItemMenu then UI:StashItemMenu(s.e.id, s) end return end
            unchecked[s.e.id] = not unchecked[s.e.id] or nil
            f:Refresh()
        end)
        r:SetScript("OnEnter", function(s)
            if not s.e then return end
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.e.id) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(s.e.why or "", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(T("Clic : cocher ou décocher"), 0.6, 0.6, 0.6)
            _G.GameTooltip:AddLine(T("Clic droit : exception pour cet objet"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    f.empty = UI:Text(f, 11, C.muted)
    f.empty:SetPoint("TOPLEFT", 16, -44); f.empty:SetPoint("TOPRIGHT", -16, -44); f.empty:SetJustifyH("LEFT")
    f.empty:SetText(T("Rien à envoyer depuis ce perso."))
    f.info = UI:Text(f, 10, C.muted)
    f.info:SetPoint("BOTTOMLEFT", 14, 18)
    f.send = UI:Button(f, "Envoyer", 110, 28, "primary")
    f.send:SetPoint("BOTTOMRIGHT", -10, 10)
    -- envoi des objets cochés, vers un seul perso (dest) ou vers tous
    function f.SendTo(_, dest)
        local Ml = WK.modules.Mail
        if Ml:IsSending() then return end
        -- règles d'envoi générées : chaque objet coché vers son perso, le reste de la pile gardé
        local me = WK.DB.global.characters[WK:CharKey()]
        local bags = me and me.bags or {}
        local chars = WK.DB.global.characters
        local store = { items = {}, cats = {} }
        local n = 0
        for _, e in ipairs(f.list or {}) do
            if not unchecked[e.id] and chars[e.to] and not store.items[e.id] and (not dest or e.to == dest) then
                store.items[e.id] = { to = Ml:MailName(chars[e.to]), keep = math.max(0, (bags[e.id] or 0) - e.count) }
                n = n + 1
            end
        end
        if n == 0 then return end
        if not Ml:SendWith(store) then WK:Print(T("Rien à envoyer : objets liés, verrouillés ou plus dans les sacs.")) end
        C_Timer.After(1, function() S():Invalidate(); if f:IsShown() then f:Refresh() end end)
    end
    f.send:SetScript("OnClick", function() f:SendTo(nil) end)
    -- en-têtes par destinataire : nom, nombre, « Envoyer à … » (maquette D)
    f.heads = UI:Pool(function()
        local h = _G.CreateFrame("Frame", nil, f.scroll.child)
        h:SetHeight(30)
        h.n = UI:Text(h, 12); h.n:SetPoint("LEFT", 8, 0)
        h.go = UI:Button(h, "Envoyer", nil, 22, "secondary")
        h.go:SetPoint("RIGHT", -6, 0)
        h.go:SetScript("OnClick", function(b) f:SendTo(b.dest) end)
        return h
    end)

    function f:Refresh()
        self.rows:Reset(); self.heads:Reset()
        local list = S():MyShipments()
        self.list = list
        local chars = WK.DB.global.characters
        table.sort(list, function(a, b)
            if a.to ~= b.to then return a.to < b.to end
            return (WK.GetItemInfo(a.id) or "") < (WK.GetItemInfo(b.id) or "")
        end)
        local y, checked, dests = 0, 0, {}
        local r1, g1, b1 = UI:Accent()
        local perDest = {}
        for _, e in ipairs(list) do perDest[e.to] = (perDest[e.to] or 0) + (unchecked[e.id] and 0 or 1) end
        local lastTo
        for _, e in ipairs(list) do
            if e.to ~= lastTo then
                lastTo = e.to
                local h = self.heads:Get()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetPoint("TOPRIGHT", 0, -y)
                local hc = chars[e.to]
                h.n:SetText("» " .. (hc and WK:CharName(hc, e.to) or "?"))
                if hc then h.n:SetTextColor(UI:ClassColor(hc.class)) end
                h.go.dest = e.to
                h.go:SetLabel(string.format(T("Envoyer (%d)"), perDest[e.to] or 0))
                h.go:SetEnabled((perDest[e.to] or 0) > 0)
                h:Show()
                y = y + 30
            end
            local r = self.rows:Get()
            r.e = e
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            local on = not unchecked[e.id]
            r.box:SetVertexColor(r1, g1, b1, on and 1 or 0.25)
            local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
            r.icon:SetTexture(icon); r.icon:SetDesaturated(not on)
            r.name:SetText(string.format("%s x%d", name or "?", e.count))
            r.name:SetTextColor(on and qr or C.dim[1], on and qg or C.dim[2], on and qb or C.dim[3])
            local ex = e.exc and UI.STASH_EXC_TAG and UI.STASH_EXC_TAG[e.exc]
            if e.ah then r.tag:SetText(T("HV")); r.tag:SetTextColor(unpack(C.gold))
            elseif ex then
                r.tag:SetText(T(ex[1]))
                local col = ex[2] == "accent" and { UI:Accent() } or C[ex[2]]
                r.tag:SetTextColor(col[1], col[2], col[3])
            else r.tag:SetText(T("métier")); r.tag:SetTextColor(unpack(C.positive)) end
            if on then checked = checked + 1; dests[e.to] = true end
            y = y + ROW_H
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#list == 0)
        local nd = 0
        for _ in pairs(dests) do nd = nd + 1 end
        self.info:SetText(#list > 0 and string.format(T("%d objet(s) vers %d perso(s)"), checked, nd) or "")
        self.send:SetLabel(string.format(T("Tout envoyer (%d)"), checked))
        self.send:SetEnabled(checked > 0)
        self:SetHeight(math.min(420, 36 + math.max(y, 40) + 56))
    end
    f:Hide()
    return f
end

-- le même panneau, posé dans la page Rangement de notre fenêtre de courrier (UI/MailWindow.lua)
function UI:StashMailPanel()
    panel = panel or build()
    return panel
end

local function show()
    -- notre fenêtre de courrier ouverte : le panneau est dans sa page Rangement
    if UI.MailWindowShown and UI:MailWindowShown() then return end
    local cfg = S():Config()
    if not (cfg.mailPanel and WK:FeatureOn("inventory") and MailFrame and MailFrame:IsShown()) then return end
    panel = panel or build()
    -- la boîte aux lettres se ferme (quelle que soit la façon) : le panneau aussi
    if not panel.hooked and MailFrame.HookScript then
        panel.hooked = true
        MailFrame:HookScript("OnHide", function() if panel then panel:Hide() end end)
    end
    wipe(unchecked)
    S():Invalidate()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 8, 0)
    UI:MatchHost(panel, MailFrame)
    panel:Refresh()
    -- rien à envoyer : pas de panneau
    if #(panel.list or {}) == 0 then panel:Hide() return end
    panel:Show()
end

WK:On("MAIL_SHOW", function() C_Timer.After(1.2, show) end)
WK:On("MAIL_CLOSED", function() if panel and not (UI.MailWindowShown and UI:MailWindowShown()) then panel:Hide() end end)
WK:On("BAG_UPDATE_DELAYED", function()
    if panel and panel:IsShown() then C_Timer.After(0.5, function() S():Invalidate(); if panel:IsShown() then panel:Refresh() end end) end
end)
