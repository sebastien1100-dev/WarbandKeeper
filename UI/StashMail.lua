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
        r:SetScript("OnClick", function(s)
            if not s.e then return end
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
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    f.empty = UI:Text(f, 11, C.muted)
    f.empty:SetPoint("TOPLEFT", 16, -44); f.empty:SetPoint("RIGHT", -16, 0); f.empty:SetJustifyH("LEFT")
    f.empty:SetText(T("Rien à envoyer depuis ce perso."))
    f.info = UI:Text(f, 10, C.muted)
    f.info:SetPoint("BOTTOMLEFT", 14, 18)
    f.send = UI:Button(f, "Envoyer", 110, 28, "primary")
    f.send:SetPoint("BOTTOMRIGHT", -10, 10)
    f.send:SetScript("OnClick", function()
        local Ml = WK.modules.Mail
        if Ml:IsSending() then return end
        -- règles d'envoi générées : chaque objet coché vers son perso, le reste de la pile gardé
        local me = WK.DB.global.characters[WK:CharKey()]
        local bags = me and me.bags or {}
        local chars = WK.DB.global.characters
        local store = { items = {}, cats = {} }
        local n = 0
        for _, e in ipairs(f.list or {}) do
            if not unchecked[e.id] and chars[e.to] and not store.items[e.id] then
                store.items[e.id] = { to = Ml:MailName(chars[e.to]), keep = math.max(0, (bags[e.id] or 0) - e.count) }
                n = n + 1
            end
        end
        if n == 0 then return end
        if not Ml:SendWith(store) then WK:Print(T("Rien à envoyer : objets liés, verrouillés ou plus dans les sacs.")) end
        C_Timer.After(1, function() S():Invalidate(); if f:IsShown() then f:Refresh() end end)
    end)

    function f:Refresh()
        self.rows:Reset()
        local list = S():MyShipments()
        self.list = list
        local chars = WK.DB.global.characters
        table.sort(list, function(a, b)
            if a.to ~= b.to then return a.to < b.to end
            return (WK.GetItemInfo(a.id) or "") < (WK.GetItemInfo(b.id) or "")
        end)
        local y, checked, dests = 0, 0, {}
        local r1, g1, b1 = UI:Accent()
        for _, e in ipairs(list) do
            local r = self.rows:Get()
            r.e = e
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            local on = not unchecked[e.id]
            r.box:SetVertexColor(r1, g1, b1, on and 1 or 0.25)
            local name, icon, qr, qg, qb = UI:ItemInfo(e.id)
            r.icon:SetTexture(icon); r.icon:SetDesaturated(not on)
            local c = chars[e.to]
            r.name:SetText(string.format("%s x%d » %s", name or "?", e.count, c and WK:CharName(c, e.to) or "?"))
            r.name:SetTextColor(on and qr or C.dim[1], on and qg or C.dim[2], on and qb or C.dim[3])
            r.tag:SetText(e.ah and T("HV") or T("métier"))
            r.tag:SetTextColor(unpack(e.ah and C.gold or C.positive))
            if on then checked = checked + 1; dests[e.to] = true end
            y = y + ROW_H
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#list == 0)
        local nd = 0
        for _ in pairs(dests) do nd = nd + 1 end
        self.info:SetText(#list > 0 and string.format(T("%d objet(s) vers %d perso(s)"), checked, nd) or "")
        self.send:SetLabel(string.format(T("Envoyer (%d)"), checked))
        self.send:SetEnabled(checked > 0)
        self:SetHeight(math.min(420, 36 + math.max(y, 40) + 56))
    end
    f:Hide()
    return f
end

local function show()
    local cfg = S():Config()
    if not (cfg.mailPanel and WK:FeatureOn("inventory") and MailFrame and MailFrame:IsShown()) then return end
    panel = panel or build()
    wipe(unchecked)
    S():Invalidate()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 8, 0)
    panel:Refresh()
    -- rien à envoyer : pas de panneau
    if #(panel.list or {}) == 0 then panel:Hide() return end
    panel:Show()
end

WK:On("MAIL_SHOW", function() C_Timer.After(1.2, show) end)
WK:On("MAIL_CLOSED", function() if panel then panel:Hide() end end)
WK:On("BAG_UPDATE_DELAYED", function()
    if panel and panel:IsShown() then C_Timer.After(0.5, function() S():Invalidate(); if panel:IsShown() then panel:Refresh() end end) end
end)
