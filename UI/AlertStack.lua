local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Pile d'alertes : un cadre « Rappels » (nombre en pastille, repliable d'un clic sur le titre), rappels
-- rangés par thème (urgent, ton perso, voyage et métiers), une ligne par rappel avec un bouton d'action.
-- Une alerte reste affichée tant que sa condition est vraie (ou jusqu'à `ttl` secondes).
--   UI:SetAlert(key, shown, { text, color = {r,g,b}, prio = 1, icon = texture, group = "urgent"|"perso"|"world",
--                              right = "3 min", ttl = secondes, dismiss = true,
--                              action = { label = "Guider", onClick = fn }                 -- bouton simple
--                                    ou { label = "Lancer", attrs = { type = "spell", spell = "…", unit = "…" } },
--                              icons = { { icon = texture, tip = "…", attrs = { … } } } })    -- petites icônes à cliquer (buffs)
-- Pile en bas de l'écran (« Empiler vers le haut », choisi aussi tout seul en la glissant) : le titre passe en bas
-- et la pile se déplie vers le haut.
-- Les boutons d'attributs sont protégés : posés hors combat seulement, retirés juste avant un combat.
-- Glisser le titre déplace la pile (position gardée).
local W, HEAD, SECH, LINE, PAD = 290, 26, 16, 22, 6
local GROUPS = {
    { "urgent", "URGENT" },
    { "perso", "TON PERSO" },
    { "world", "VOYAGE, MÉTIERS ET HV" },
}
local anchor, head, rows, secs, acts = nil, nil, {}, {}, {}
local active = {} -- [key] = data (+ since, until)

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function entry() return UI:HUDEntry("alerts") end
local function folded()
    local e = entry()
    return e.collapsed or (e.combatFold and UnitAffectingCombat and UnitAffectingCombat("player")) or false
end

local layout
local function build()
    anchor = CreateFrame("Frame", "WarbandKeeperAlertStack", UIParent)
    anchor:SetSize(W, HEAD)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    UI:Panel(anchor, 10, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)

    -- titre : « Rappels », pastille du nombre, chevron ; clic = replier, glisser = déplacer
    head = CreateFrame("Button", nil, anchor)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD)
    head:RegisterForDrag("LeftButton")
    head.title = UI:Text(head, 12, C.text)
    head.title:SetPoint("LEFT", 10, 0)
    head.title:SetText(T("Rappels"))
    head.pill = CreateFrame("Frame", nil, head)
    head.pill:SetSize(20, 14)
    head.pill:SetPoint("LEFT", head.title, "RIGHT", 6, 0)
    head.pill.bg = UI:Rounded(head.pill, 7, 0, "BACKGROUND", 1)
    head.pill.text = UI:Text(head.pill, 10, C.onAccent)
    head.pill.text:SetPoint("CENTER", 0, 0)
    head.chev = UI:Icon(head, "chevron", 11)
    head.chev:SetPoint("RIGHT", -10, 0)
    head.line = head:CreateTexture(nil, "ARTWORK")
    head.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    head.line:SetPoint("BOTTOMLEFT", 6, 0); head.line:SetPoint("BOTTOMRIGHT", -6, 0)
    head.line:SetHeight(1)
    head:SetScript("OnClick", function()
        local e = entry()
        e.collapsed = not e.collapsed
        layout()
    end)
    head:SetScript("OnDragStart", function() if not UI.editing then anchor:StartMoving() end end)
    head:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        -- posée dans la moitié basse de l'écran : elle se déplie vers le haut (et inversement)
        local top, bottom = anchor:GetTop(), anchor:GetBottom()
        if top and bottom then entry().growUp = (top + bottom) / 2 < UIParent:GetHeight() / 2 end
        UI:HUDCapture("alerts")
        layout()
    end)
    head:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Rappels Warband Keeper"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic : replier ou déplier. Glisser : déplacer la pile."), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(T("Où va chaque rappel : QoL > Général > Alertes."), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    head:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UI:RegisterHUD("alerts", anchor, {
        label = T("Pile d'alertes"),
        default = { 0, UIParent:GetHeight() / 2 - 250 },
        dynamicPoint = function(e) return e.growUp and "BOTTOM" or "TOP" end,
        legacy = function()
            local pos = WK.DB.global.settings.ui.alertStack -- position des versions précédentes
            if not pos then return false end
            anchor:ClearAllPoints()
            anchor:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
            return true
        end,
        options = {
            { type = "seg", label = "Empiler vers", items = { { false, "le bas" }, { true, "le haut" } },
              get = function(e) return e.growUp and true or false end,
              set = function(e, v)
                  if (e.growUp and true or false) == v then return end
                  local h = (anchor:GetHeight() or 30) * (e.scale or 1)
                  e.y = v and (e.y - h) or (e.y + h) -- le haut (ou le bas) de la pile reste en place
                  e.growUp = v
              end },
            { type = "toggle", label = "Icônes", get = function(e) return e.icons ~= false end, set = function(e, v) e.icons = v end },
            { type = "toggle", label = "Replier en combat", get = function(e) return e.combatFold and true or false end, set = function(e, v) e.combatFold = v end },
        },
        sample = function(on) UI:AlertDemo(on) end,
        -- « Tester » : les mêmes rappels, et le temps du poison qui défile
        test = function()
            UI:AlertDemo(true)
            local left = 180
            anchor.testTicker = C_Timer.NewTicker and C_Timer.NewTicker(1, function()
                left = math.max(0, left - 1)
                UI:SetAlert("demo.2", true, { text = T("Exemple : poison de l'arme principale"), group = "perso",
                    right = string.format("%d:%02d", math.floor(left / 60), left % 60), rightColor = C.warning })
            end)
        end,
        testStop = function()
            if anchor.testTicker then anchor.testTicker:Cancel(); anchor.testTicker = nil end
            UI:AlertDemo(false)
        end,
        onApply = function() if layout then layout() end end,
    })
end

local function getSec(i)
    local s = secs[i]
    if s then return s end
    s = UI:Text(anchor, 9, C.dim)
    secs[i] = s
    return s
end

local function getRow(i)
    local it = rows[i]
    if it then return it end
    it = CreateFrame("Button", nil, anchor)
    it:SetHeight(LINE)
    it:RegisterForClicks("RightButtonUp")
    it.dot = UI:Icon(it, "circle", 7)
    it.dot:SetPoint("LEFT", 8, 0)
    it.icon = UI:RoundIcon(it, 16)
    it.icon:SetPoint("LEFT", 4, 0)
    it.text = UI:Text(it, 11, C.text)
    it.text:SetWordWrap(false)
    it.text:SetJustifyH("LEFT")
    it.right = UI:Text(it, 10, C.muted)
    it.right:SetJustifyH("RIGHT")
    it.btn = UI:Button(it, "", nil, 18, "primary")
    it.btn:SetPoint("RIGHT", -6, 0)
    it.btn:SetScript("OnClick", function(b) if b.fn then pcall(b.fn) end end)
    it:SetScript("OnClick", function(s)
        local a = s.key and active[s.key]
        if a and a.dismiss then UI:SetAlert(s.key, false) end
    end)
    it:SetScript("OnEnter", function(s)
        local a = s.key and active[s.key]
        if not a then return end
        WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(a.text or "", 1, 1, 1, 1, true)
        if a.tip then GameTooltip:AddLine(a.tip, 0.7, 0.7, 0.7, true) end
        if a.dismiss then GameTooltip:AddLine(T("Clic droit : retirer ce rappel"), 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end)
    it:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = it
    return it
end

-- Bouton protégé (sort, objet, macro) : enfant d'UIParent, jamais touché en combat.
local function getAct(i)
    local b = acts[i]
    if b then return b end
    b = CreateFrame("Button", "WarbandKeeperAlertAction" .. i, UIParent, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetFrameStrata("MEDIUM")
    b:SetHeight(18)
    b.bg = UI:Rounded(b, 9, 0, "BACKGROUND", 1)
    b.label = UI:Text(b, 12, C.onAccent)
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(s) if s.tip then WK.UI:TooltipOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(s.tip, 1, 1, 1, 1, true); GameTooltip:Show() end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    acts[i] = b
    return b
end
-- Petite icône protégée (un buff à lancer) : même règle, jamais touchée en combat.
local icons = {}
local function getIconBtn(i)
    local b = icons[i]
    if b then return b end
    b = CreateFrame("Button", "WarbandKeeperAlertIcon" .. i, UIParent, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
    b:SetFrameStrata("MEDIUM")
    b:SetSize(18, 18)
    b.edge = b:CreateTexture(nil, "BACKGROUND"); b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.2)
    b:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(s.tip or "", 1, 1, 1)
        GameTooltip:AddLine(T("Clic : lancer"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    icons[i] = b
    return b
end
local function hideActs()
    for _, b in ipairs(acts) do b:Hide(); b:ClearAllPoints() end
    for _, b in ipairs(icons) do b:Hide(); b:ClearAllPoints() end
end

local function sorted()
    local now = GetTime and GetTime() or 0
    local list = {}
    for key, a in pairs(active) do
        if a["until"] and now > a["until"] then active[key] = nil
        else table.insert(list, { key = key, a = a }) end
    end
    table.sort(list, function(x, y)
        if (x.a.prio or 5) ~= (y.a.prio or 5) then return (x.a.prio or 5) < (y.a.prio or 5) end
        return x.key < y.key
    end)
    return list
end

local function groupOf(a)
    if a.group then return a.group end
    return (a.prio or 5) <= 1 and "urgent" or "perso"
end

layout = function()
    if not anchor then return end
    local list = sorted()
    local e = entry()
    local showIcons = e.icons ~= false
    local up = e.growUp and true or false
    local fold = folded()
    local combat = inCombat()
    local r, g, b = UI:Accent()
    head.pill.bg:SetColor(r, g, b, 1)
    head.pill.text:SetText(#list)
    head.pill:SetWidth(math.max(18, head.pill.text:GetStringWidth() + 10))
    head.chev:SetVertexColor(r, g, b, 0.9)
    -- chevron : vers la droite replié ; ouvert, vers le bas (ou le haut quand la pile se déplie vers le haut)
    if head.chev.SetRotation then head.chev:SetRotation(fold and math.pi / 2 or (up and math.pi or 0)) end
    head:ClearAllPoints(); head.line:ClearAllPoints()
    if up then
        head:SetPoint("BOTTOMLEFT"); head:SetPoint("BOTTOMRIGHT")
        head.line:SetPoint("TOPLEFT", 6, 0); head.line:SetPoint("TOPRIGHT", -6, 0)
    else
        head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
        head.line:SetPoint("BOTTOMLEFT", 6, 0); head.line:SetPoint("BOTTOMRIGHT", -6, 0)
    end
    head.line:SetShown(not fold and #list > 0)

    if not combat then hideActs() end
    local y, ri, si, ai, ii = up and 4 or (HEAD + 2), 0, 0, 0, 0
    if not fold then
        for _, gdef in ipairs(GROUPS) do
            local first = true
            for _, it in ipairs(list) do
                local a = it.a
                if groupOf(a) == gdef[1] then
                    if first then
                        first = false
                        si = si + 1
                        local s = getSec(si)
                        s:ClearAllPoints(); s:SetPoint("TOPLEFT", 10, -(y + 3))
                        s:SetText(T(gdef[2])); s:Show()
                        y = y + SECH
                    end
                    ri = ri + 1
                    local row = getRow(ri)
                    row.key = it.key
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                    local col = a.color or C.warning
                    local hasIcon = showIcons and a.icon ~= nil
                    row.icon:SetShown(hasIcon)
                    if hasIcon then row.icon:SetTexture(a.icon) end
                    row.dot:SetShown(not hasIcon)
                    row.dot:SetVertexColor(col[1], col[2], col[3], 1)
                    -- bouton : simple (fonction) ou protégé (hors combat seulement)
                    local act = a.action
                    local bw = 0
                    row.btn:Hide()
                    if act and act.onClick then
                        row.btn:SetLabel(act.label or "")
                        row.btn:SetWidth(row.btn.label:GetStringWidth() + 18)
                        row.btn:SetStyle(act.ghost and "secondary" or "primary")
                        row.btn.fn = act.onClick
                        row.btn:Show()
                        bw = row.btn:GetWidth() + 6
                    elseif a.icons and not combat then
                        -- une icône par buff applicable, de droite à gauche
                        local x = -6
                        for k = #a.icons, 1, -1 do
                            local ic = a.icons[k]
                            ii = ii + 1
                            local ib = getIconBtn(ii)
                            for _, an in ipairs({ "type", "spell", "unit", "macrotext", "item" }) do ib:SetAttribute(an, nil) end
                            for an, av in pairs(ic.attrs or {}) do ib:SetAttribute(an, av) end
                            ib.icon:SetTexture(ic.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                            ib.edge:SetColorTexture(r, g, b, 0.9)
                            ib.tip = ic.tip
                            ib:SetFrameLevel(row:GetFrameLevel() + 5)
                            ib:SetPoint("RIGHT", row, "RIGHT", x, 0)
                            ib:Show()
                            x = x - 22
                        end
                        bw = -x - 2
                    elseif act and act.attrs and not combat then
                        ai = ai + 1
                        local sb = getAct(ai)
                        -- bouton réutilisé : les attributs d'un rappel précédent (unité visée…) sont effacés
                        for _, an in ipairs({ "type", "spell", "unit", "macrotext", "item" }) do sb:SetAttribute(an, nil) end
                        for k, v in pairs(act.attrs) do sb:SetAttribute(k, v) end
                        sb.label:SetText(act.label or "")
                        sb:SetWidth(sb.label:GetStringWidth() + 18)
                        sb.bg:SetColor(r, g, b, 1)
                        sb.tip = act.tip
                        sb:SetFrameLevel(row:GetFrameLevel() + 5)
                        sb:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                        sb:Show()
                        bw = sb:GetWidth() + 6
                    end
                    row.right:ClearAllPoints()
                    row.right:SetPoint("RIGHT", -(6 + bw), 0)
                    row.right:SetText(a.right or "")
                    row.right:SetTextColor(unpack(a.rightColor or C.muted))
                    row.text:ClearAllPoints()
                    row.text:SetPoint("LEFT", hasIcon and 24 or 20, 0)
                    row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
                    row.text:SetText(a.text or "")
                    row:Show()
                    y = y + LINE
                end
            end
        end
    end
    for i = ri + 1, #rows do rows[i]:Hide() end
    for i = si + 1, #secs do secs[i]:Hide() end
    anchor:SetSize(W, fold and HEAD or (y + (up and (HEAD + 2) or (PAD - 2))))
    -- pile vide : cachée (le mode édition la montre avec ses exemples)
    anchor:SetShown(#list > 0 or UI.editing)
end

-- Même couleur (composantes comparées : l'appelant peut fournir une nouvelle table à chaque fois)
local function sameColor(a, b)
    if a == b then return true end
    if not a or not b then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end
local function sameAction(a, b)
    if a == b then return true end
    if not a or not b then return false end
    if a.label ~= b.label or a.onClick ~= b.onClick then return false end
    local x, y = a.attrs, b.attrs
    if x == y then return true end
    if not x or not y then return false end
    for k, v in pairs(x) do if y[k] ~= v then return false end end
    for k, v in pairs(y) do if x[k] ~= v then return false end end
    return true
end

-- mêmes icônes de buff (texture et attributs : le sort et l'unité visés peuvent changer d'un relevé à l'autre)
local function sameIcons(a, b)
    a, b = a or {}, b or {}
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i].icon ~= b[i].icon then return false end
        local x, y = a[i].attrs or {}, b[i].attrs or {}
        for k, v in pairs(x) do if y[k] ~= v then return false end end
        for k, v in pairs(y) do if x[k] ~= v then return false end end
    end
    return true
end

function UI:SetAlert(key, shown, data)
    local cur = active[key]
    if shown then
        local now = GetTime and GetTime() or 0
        local untilT = data.ttl and (now + data.ttl) or nil
        if cur and cur.text == data.text and cur.icon == data.icon and cur.prio == data.prio and cur.right == data.right
            and sameIcons(cur.icons, data.icons) and cur.tip == data.tip and sameColor(cur.rightColor, data.rightColor)
            and cur.dismiss == data.dismiss
            and cur.group == data.group and sameColor(cur.color, data.color) and sameAction(cur.action, data.action) then
            cur["until"] = untilT
            return
        end
        data["until"] = untilT
        active[key] = data
    else
        if not cur then return end
        active[key] = nil
    end
    if not anchor then build() end
    layout()
end

function UI:ActiveAlerts() return active end

-- Exemples (mode édition et « Tester ») : un rappel de chaque groupe, avec bouton et icônes de buff
function UI:AlertDemo(on)
    local function sp(id) return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or (GetSpellTexture and GetSpellTexture(id)) end
    UI:SetAlert("demo.1", on, { text = T("Exemple : limite d'instances 9/10"), color = C.negative, prio = 1, group = "urgent", right = "12 min" })
    UI:SetAlert("demo.2", on, { text = T("Exemple : poison de l'arme principale"), group = "perso", right = "3:00", rightColor = C.warning })
    UI:SetAlert("demo.4", on, { text = T("Exemple : pas de bénédiction sur toi"), group = "perso",
        icons = { { icon = sp(19740), tip = WK.SpellInfo(19740) }, { icon = sp(19742), tip = WK.SpellInfo(19742) }, { icon = sp(20217), tip = WK.SpellInfo(20217) } } })
    UI:SetAlert("demo.3", on, { text = T("Exemple : point de vol à apprendre"), color = C.info, group = "world",
        action = { label = T("Guider"), onClick = function() end } })
end

-- La pile existe dès la connexion (vide), pour pouvoir la placer en mode édition.
WK:On("PLAYER_LOGIN", function()
    if not anchor then build(); layout() end
    -- rappels à durée : retirés à l'heure dite
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function()
            local now = GetTime and GetTime() or 0
            for _, a in pairs(active) do
                if a["until"] and now > a["until"] then layout(); return end
            end
        end)
    end
end)
-- juste avant le combat (encore permis) : boutons protégés retirés ; repli en combat ; retour après
WK:On("PLAYER_REGEN_DISABLED", function()
    hideActs()
    if anchor then C_Timer.After(0, layout) end
end)
WK:On("PLAYER_REGEN_ENABLED", function() if anchor then layout() end end)
