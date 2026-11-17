local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Récapitulatif d'une session de pêche (Modules/FishingLog.lua), affiché à la fermeture du mode pêche :
-- zone et durée, prises, rythme, valeur, prises par tranche de 2 minutes, ce qui a le plus mordu,
-- nouveautés et points de compétence gagnés. Disparaît seul après 20 s (clic : tout de suite).
-- Placé en mode édition. Le compteur en direct est dans la barre du mode pêche (UI/FishingBar.lua).
local L = WK.modules.FishingLog
local card
local W, BARS = 320, 15

local function itemIcon(id)
    local f = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    return f and f(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function dur(sec)
    sec = math.floor(sec or 0)
    if sec < 3600 then return string.format(T("%d min"), math.max(1, math.floor(sec / 60))) end
    return string.format("%d h %02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end

local function build()
    local f = CreateFrame("Button", "WarbandKeeperFishingRecap", UIParent)
    f:SetSize(W, 254)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f.edge = UI:Rounded(f, 14, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 13, 1, "BACKGROUND", 1)
    f.title = UI:Text(f, 13)
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.title:SetText(T("Session de pêche terminée"))
    f.where = UI:Text(f, 10, C.muted)
    f.where:SetPoint("TOPRIGHT", -16, -16)
    f.where:SetJustifyH("RIGHT")
    -- trois chiffres
    f.kp = {}
    local kw = (W - 32 - 16) / 3
    for i = 1, 3 do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(kw, 46)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * (kw + 8), -40)
        b.bg = UI:Rounded(b, 9, 0, "BACKGROUND", 2)
        b.v = UI:Text(b, 15)
        b.v:SetPoint("TOP", 0, -7)
        b.l = UI:Text(b, 10, C.muted)
        b.l:SetPoint("BOTTOM", 0, 7)
        f.kp[i] = b
    end
    -- prises au fil de la session
    f.bars = {}
    local bw = (W - 32 - (BARS - 1) * 3) / BARS
    for i = 1, BARS do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 16 + (i - 1) * (bw + 3), -132)
        t:SetWidth(bw)
        f.bars[i] = t
    end
    -- ce qui a le plus mordu
    f.rows = {}
    for i = 1, 3 do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(W - 32, 22)
        r:SetPoint("TOPLEFT", 16, -140 - (i - 1) * 24)
        r.icon = UI:RoundIcon(r, 20)
        r.icon:SetPoint("LEFT")
        r.name = UI:Text(r, 11)
        r.name:SetPoint("LEFT", 28, 0)
        r.name:SetPoint("RIGHT", -70, 0)
        r.name:SetJustifyH("LEFT")
        r.n = UI:Text(r, 11, C.muted)
        r.n:SetPoint("RIGHT")
        f.rows[i] = r
    end
    f.foot = UI:Text(f, 11)
    f.foot:SetPoint("BOTTOMLEFT", 16, 14)
    f.foot:SetPoint("RIGHT", -16, 0)
    f.foot:SetJustifyH("LEFT")
    -- barre de temps en bas : se vide jusqu'à la fermeture, en pause sous la souris (grise)
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetHeight(3)
    f.track:SetPoint("BOTTOMLEFT", 14, 1); f.track:SetPoint("BOTTOMRIGHT", -14, 1)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetHeight(3)
    f.fill:SetPoint("BOTTOMLEFT", f.track, "BOTTOMLEFT")
    f:SetScript("OnClick", function(s) s:Hide() end)
    f:SetScript("OnUpdate", function(s, elapsed)
        if s.sample or not s.total then
            s.track:SetShown(false); s.fill:SetShown(false)
            return
        end
        s.track:SetShown(true); s.fill:SetShown(true)
        local over = s:IsMouseOver()
        if not over then s.remain = s.remain - elapsed end
        if s.remain <= 0 then s.total = nil; s:Hide(); s:SetAlpha(1) return end
        s.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
        local r, g, b = UI:Accent()
        if over then s.fill:SetColorTexture(C.dim[1], C.dim[2], C.dim[3], 1) else s.fill:SetColorTexture(r, g, b, 1) end
        s.fill:SetWidth(math.max(0.01, (s.track:GetWidth() or 0) * s.remain / s.total))
        s:SetAlpha(over and 1 or math.min(1, s.remain / 0.5))
    end)

    function f:Fill(sv)
        local r, g, b = UI:Accent()
        self.edge:SetColor(r, g, b, 1)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.where:SetText(L:ZoneName(sv.zone) .. "  ·  " .. dur(sv.duration))
        local rate = L.Rate(sv.catches, sv.duration)
        local vals = { { tostring(sv.catches), T("prises") }, { rate and (rate .. "/h") or "-", T("rythme") }, { UI:GoldText(sv.value or 0), T("valeur") } }
        for i, k in ipairs(self.kp) do
            k.bg:SetColor(unpack(C.surface2))
            k.v:SetText(vals[i][1]); k.l:SetText(vals[i][2])
        end
        local maxB, n = 1, math.max(1, #sv.buckets)
        for i = 1, n do maxB = math.max(maxB, sv.buckets[i] or 0) end
        local first = math.max(1, n - BARS + 1)
        for i, t in ipairs(self.bars) do
            local v = sv.buckets[first + i - 1]
            t:SetHeight(math.max(2, 34 * (v or 0) / maxB))
            t:SetColorTexture(r, g, b, v and 0.8 or 0.15)
        end
        local top = {}
        for id, q in pairs(sv.items) do table.insert(top, { id, q }) end
        table.sort(top, function(a, b2) return a[2] > b2[2] end)
        for i, row in ipairs(self.rows) do
            local e = top[i]
            row:SetShown(e ~= nil)
            if e then
                row.icon:SetTexture(itemIcon(e[1]))
                row.name:SetText(WK.GetItemInfo(e[1]) or ("#" .. e[1]))
                row.n:SetText(e[2] .. (sv.new[e[1]] and ("  |cff" .. string.format("%02x%02x%02x", r * 255, g * 255, b * 255) .. T("nouveau") .. "|r") or ""))
            end
        end
        local gain = (sv.skill1 and sv.skill0) and (sv.skill1 - sv.skill0) or 0
        if gain > 0 then
            self.foot:SetText(string.format(T("+%d points de compétence (%d > %d)"), gain, sv.skill0, sv.skill1))
            self.foot:SetTextColor(unpack(C.positive))
        else
            local nNew = 0
            for _ in pairs(sv.new) do nNew = nNew + 1 end
            self.foot:SetText(nNew > 0 and string.format(T("%d nouvelle(s) espèce(s) pour le compte"), nNew) or T("Clic pour fermer"))
            self.foot:SetTextColor(unpack(nNew > 0 and C.positive or C.dim))
        end
    end

    f:Hide()
    UI:RegisterHUD("fishRecap", f, {
        label = T("Récapitulatif de pêche"),
        default = { 0, 120 },
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Fill({ catches = 42, duration = 29 * 60, value = 34000, zone = nil, buckets = { 3, 4, 2, 5, 3, 4, 3, 2, 4, 3, 5, 4 },
                         items = { [6362] = 28, [7910] = 6, [6359] = 1 }, new = { [6359] = true }, skill0 = 225, skill1 = 237 })
                f:Show()
            else
                f:Hide()
            end
        end,
    })
    return f
end

function UI:ShowFishingRecap(sv)
    if not WK.modules.Fishing:Config().recap then return end
    card = card or build()
    card.sample = nil
    card:Fill(sv)
    local secs = WK.modules.Fishing:Config().recapTime
    if secs == nil then secs = 10 end
    card.total = secs > 0 and secs or nil
    card.remain = card.total
    card:SetAlpha(1)
    card:Show()
end

-- compteur de la barre du mode pêche à chaque prise
L.OnCatch = function() if UI.RefreshFishingBar then UI:RefreshFishingBar() end end
WK:On("PLAYER_LOGIN", function() card = card or build() end)
