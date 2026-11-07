----------------------------------------------------------------------
-- VendorRecipes.lua — WoW Forever only: recipes vendors sell for YOUR professions
-- that you don't know yet.
--
--   * each crafting tab lists them (skill needed, nearest vendor, price, limited
--     stock); click one for a VoidGPS route to the vendor
--   * entering a zone where a vendor has one you can learn: a small popup says
--     who and what, with a button for the way there (once per zone per session,
--     never in combat; it has its own off switch)
--
-- Which vendor sells what comes from VoidGPS (VoidGPS.Recipes). "You know it" is
-- matched by name against the recipes VoidProf saved from your profession window
-- ("Pattern: Blue Linen Vest" -> "Blue Linen Vest"), so a profession you haven't
-- opened yet is skipped until you do.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end

local _, ns = ...
VoidProf = VoidProf or {}
local VR = {}
VoidProf.VendorRecipes = VR

local SOON = 25   -- also list recipes up to this much skill above yours ("at 60")

local function api() return VoidGPS and VoidGPS.Recipes end

local function zoneName(map)
    local i = map and C_Map.GetMapInfo(map)
    return i and i.name or "?"
end

local function bare(name)
    return (name:gsub("^[%a ]-: ", ""))   -- "Pattern: X" / "Recipe: X" / "Formula: X" -> "X"
end

-- the recipes this character knows, by profession name: { [lower name] = true }, or nil if never synced
local function known(profName)
    local c = VoidProf:ProfCache()[profName]
    if not c or not c.recipes then return nil end
    local out = {}
    for _, r in pairs(c.recipes) do
        if r.name then out[r.name:lower()] = true end
    end
    return out
end

-- { { e, prof, skill, now }, ... } for every profession you have, unknown + learnable now or soon
function VR:ForYou(onlyProf)
    local R = api()
    if not R then return {}, false end
    local profs = VoidProf.SkillCap and VoidProf.SkillCap:Professions() or {}
    local byLine, knows = {}, {}
    for name, p in pairs(profs) do
        if p.line and (not onlyProf or onlyProf == name) then
            byLine[p.line] = p
            knows[p.line] = known(name)
        end
    end
    local out, unsynced = {}, false
    for _, e in ipairs(R:All()) do
        local p = byLine[e.line]
        if p then
            local k = knows[e.line]
            if not k then
                unsynced = true
            elseif not k[bare(e.name):lower()] and (e.skill or 0) <= (p.rank or 0) + SOON then
                out[#out + 1] = { e = e, prof = p.name, skill = p.rank or 0, now = (e.skill or 0) <= (p.rank or 0) }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.now ~= b.now then return a.now end
        if (a.e.skill or 0) ~= (b.e.skill or 0) then return (a.e.skill or 0) < (b.e.skill or 0) end
        return a.e.name < b.e.name
    end)
    return out, unsynced
end

local function go(item)
    local R = api()
    if not R then VoidProf:Print("Install VoidGPS (free, same author) for the way to the vendor."); return end
    local ok, vendor, map, yd = R:Go(item)
    if ok then
        VoidProf:Print(("Heading to |cffffffff%s|r, %s%s."):format(vendor, zoneName(map), yd and (" (" .. math.floor(yd) .. " yd)") or ""))
    end
end

-- "1g 20s", "45s", "80c"
local function priceText(c)
    if not c or c <= 0 then return "" end
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "|cffffd700g|r" end
    if s > 0 then out[#out + 1] = s .. "|cffc7c7cfs|r" end
    if cp > 0 and g == 0 then out[#out + 1] = cp .. "|cffeda55fc|r" end
    return table.concat(out, " ")
end

local function popupsOn()
    VoidProfCharDB = VoidProfCharDB or {}
    return VoidProfCharDB.recipePopup ~= false
end

----------------------------------------------------------------------
-- Panel block (SkillCap:Build adds it to the crafting tabs)
----------------------------------------------------------------------
local CRAFT = { [171] = true, [164] = true, [185] = true, [333] = true, [202] = true, [129] = true, [165] = true, [197] = true }
local ROWS, ROW_H = 14, 20   -- rows built; as many as fit the tab are shown

local function visible(v)
    local h = v.list:GetHeight() or 0
    return math.max(1, math.min(ROWS, math.floor(h / ROW_H)))
end

-- "Sold by" in a row's item tooltip, from the tooltip hook: a recipe's tooltip is
-- built again when the item it teaches loads, which wiped lines added once.
if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
        if tt ~= GameTooltip then return end
        local owner = tt:GetOwner()
        local d = owner and owner._vpRecipeRow and owner._d
        if not d then return end
        tt:AddLine(" ")
        tt:AddLine("Sold by:", 0, 0.78, 1)
        for k, v in ipairs(d.e.vendors) do
            if k > 5 then break end
            tt:AddDoubleLine(v.name .. (v.limited and " |cffffd200(limited)|r" or ""),
                zoneName(v.map) .. (v.yards and (" · " .. math.floor(v.yards) .. " yd") or ""), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        tt:AddLine("Click: the way to the nearest one", 0.5, 0.8, 0.5)
    end)
end

function VR:Wants(profName)
    local p = VoidProf.SkillCap and VoidProf.SkillCap:Professions()[profName]
    return p and CRAFT[p.line] or false
end

function VR:Build(parent, profName, anchor, makeButton)
    local P = VoidUI.palette
    local head = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(head, 11, "OUTLINE")
    head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -44)
    head:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    head:SetText("Recipes from vendors")

    local toggle = makeButton(parent, 120, 20, "", function(b)
        VoidProfCharDB = VoidProfCharDB or {}
        VoidProfCharDB.recipePopup = not popupsOn()
        VR:Refresh(parent)
    end)
    toggle:SetPoint("LEFT", head, "RIGHT", 12, 0)
    toggle:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText("Zone popups", 1, 1, 1)
        GameTooltip:AddLine("When you enter a zone where a vendor sells a recipe you can learn and don't know, a small window tells you who and what.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local note = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(note, 10, "")
    note:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    note:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetTextColor(0.67, 0.67, 0.7)

    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -4)
    list:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 4)
    list:EnableMouseWheel(true)
    list:SetScript("OnSizeChanged", function() if parent._vr then VR:Paint(parent) end end)
    local rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT")
        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints()
        hl:SetColorTexture(P.accent[1], P.accent[2], P.accent[3], 0.15)
        hl:Hide()
        local left = row:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(left, 10, "")
        left:SetPoint("LEFT", 2, 0)
        left:SetWidth(250)
        left:SetJustifyH("LEFT")
        left:SetWordWrap(false)
        local right = row:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(right, 10, "")
        right:SetPoint("LEFT", left, "RIGHT", 6, 0)
        right:SetPoint("RIGHT", -2, 0)
        right:SetJustifyH("RIGHT")
        right:SetWordWrap(false)
        right:SetTextColor(0.7, 0.7, 0.75)
        row._left, row._right = left, right
        row._vpRecipeRow = true   -- the tooltip hook adds "Sold by"
        row:SetScript("OnEnter", function(self)
            hl:Show()
            if not self._d then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self._d.e.item)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self) if self._d then go(self._d.e.item) end end)
        rows[i] = row
    end
    parent._vr = { prof = profName, note = note, rows = rows, list = list, toggle = toggle, offset = 0, data = {} }
    list:SetScript("OnMouseWheel", function(_, delta)
        local v = parent._vr
        v.offset = math.max(0, math.min(math.max(0, #v.data - visible(v)), v.offset - delta * 2))
        VR:Paint(parent)
    end)
end

function VR:Paint(parent)
    local v = parent._vr
    local n = visible(v)
    v.offset = math.max(0, math.min(v.offset, #v.data - n))
    for i, row in ipairs(v.rows) do
        local d = i <= n and v.data[v.offset + i] or nil
        row._d = d
        if d then
            local e, vend = d.e, d.e.vendors[1]
            row._left:SetText((d.now and "|cffffffff" or "|cff888888") .. e.name .. "|r"
                .. (d.now and "" or (" |cff888888at " .. e.skill .. "|r")))
            row._right:SetText((vend and (vend.name .. " · " .. zoneName(vend.map)) or "?")
                .. (e.limited and " |cffffd200limited|r" or "") .. "  " .. priceText(e.buy))
            row:Show()
        else
            row:Hide()
        end
    end
end

function VR:Refresh(parent)
    local v = parent and parent._vr
    if not v then return end
    v.toggle._text:SetText(popupsOn() and "|cff00ff00Popups: on|r" or "|cff888888Popups: off|r")
    if not api() then
        v.data = {}
        v.note:SetText("Install |cff00c7ffVoidGPS|r (free, same author): it knows which vendor sells which recipe.")
        self:Paint(parent)
        return
    end
    local data, unsynced = self:ForYou(v.prof)
    v.data, v.offset = data, 0
    if unsynced then
        v.note:SetText("Open your " .. v.prof .. " window once so VoidProf knows which recipes you have.")
    elseif #data == 0 then
        v.note:SetText("No vendor recipe you don't know at your skill. More open up as you level.")
    else
        local n = 0
        for _, d in ipairs(data) do if d.now then n = n + 1 end end
        v.note:SetText(("%d you can learn now, %d soon. Nearest vendor shown; click for the way. Mouse wheel scrolls."):format(n, #data - n))
    end
    self:Paint(parent)
end

----------------------------------------------------------------------
-- Zone popup
----------------------------------------------------------------------
local popup
local shownFor = {}     -- zone map -> true (this session)
local pendingZone

local function buildPopup()
    local P = VoidUI.palette
    local f = CreateFrame("Frame", "VoidProfRecipePopup", UIParent, "BackdropTemplate")
    f:SetSize(380, 80)
    f:SetPoint("TOP", UIParent, "TOP", 0, -170)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
    f:SetBackdropBorderColor(P.accent[1], P.accent[2], P.accent[3], 0.8)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    local title = f:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    f._title = title

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(x, 13, "")
    x:SetPoint("CENTER")
    x:SetText("|cffcc4444x|r")
    close:SetScript("OnClick", function() f:Hide() end)

    local body = f:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(body, 10, "")
    body:SetPoint("TOPLEFT", 10, -26)
    body:SetPoint("RIGHT", -10, 0)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetSpacing(2)
    body:SetTextColor(0.88, 0.88, 0.9)
    f._body = body

    local function btn(text, w, onClick)
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetSize(w, 20)
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropColor(0.1, 0.12, 0.15, 1)
        b:SetBackdropBorderColor(P.accent[1], P.accent[2], P.accent[3], 0.5)
        local t = b:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(t, 10, "")
        t:SetPoint("CENTER")
        t:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    f._go = btn("|cffffd200Show the way|r", 120, function()
        -- to the vendor the popup names (not the item's nearest vendor, which near a
        -- zone edge can be someone else)
        local R = api()
        if R and f._vendor and R.GoVendor and R:GoVendor(f._vendor, f._recipe) then
            VoidProf:Print(("Heading to |cffffffff%s|r, %s."):format(f._vendor.name, zoneName(f._vendor.map)))
        elseif f._item then
            go(f._item)
        end
        f:Hide()
    end)
    f._go:SetPoint("BOTTOMLEFT", 10, 8)
    f._off = btn("|cff888888Don't show these|r", 120, function()
        VoidProfCharDB = VoidProfCharDB or {}
        VoidProfCharDB.recipePopup = false
        VoidProf:Print("Recipe popups off. Turn them back on in a profession tab (Popups button).")
        f:Hide()
    end)
    f._off:SetPoint("BOTTOMRIGHT", -10, 8)
    f:Hide()
    return f
end

local function check()
    if not popupsOn() or not api() then return end
    if InCombatLockdown() then pendingZone = true; return end
    local zone = C_Map.GetBestMapForUnit("player")
    -- a popup from the zone you just left goes away
    if popup and popup:IsShown() and popup._zone ~= zone then popup:Hide() end
    if not zone or shownFor[zone] then return end
    local here = {}   -- vendor name -> { recipes }
    local order = {}
    for _, d in ipairs((VR:ForYou())) do
        if d.now then
            for _, v in ipairs(d.e.vendors) do
                if v.map == zone then
                    if not here[v.name] then here[v.name] = { v = v, list = {} }; order[#order + 1] = v.name end
                    table.insert(here[v.name].list, d)
                end
            end
        end
    end
    -- (only a zone that got a popup is done for the session: one checked while your
    -- recipes weren't synced yet, or below the skill, is checked again next time)
    if #order == 0 then return end
    shownFor[zone] = true
    popup = popup or buildPopup()
    local lines, first, firstV, firstName = {}, nil, nil, nil
    for i, name in ipairs(order) do
        if i > 3 then lines[#lines + 1] = ("|cff888888... and %d more vendors (VoidProf, your profession tabs)|r"):format(#order - 3); break end
        local h = here[name]
        local items = {}
        for k, d in ipairs(h.list) do
            if k > 4 then items[#items + 1] = ("+%d more"):format(#h.list - 4); break end
            items[#items + 1] = d.e.name .. (d.e.limited and " |cffffd200(limited)|r" or "")
        end
        if not first then first, firstV, firstName = h.list[1].e.item, h.v, h.list[1].e.name end
        lines[#lines + 1] = ("|cffffd200%s|r: %s"):format(name, table.concat(items, ", "))
    end
    popup._title:SetText("Recipes you can learn here, " .. zoneName(zone))
    popup._body:SetText(table.concat(lines, "\n"))
    popup._item, popup._vendor, popup._recipe, popup._zone = first, firstV, firstName, zone
    popup:SetHeight(26 + (popup._body:GetStringHeight() or 30) + 40)
    popup:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingZone then pendingZone = nil; C_Timer.After(1, check) end
    else
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 8 or 2, check)
    end
end)
