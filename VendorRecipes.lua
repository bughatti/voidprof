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

-- recipes learned since the profession window last synced (2026-11-07: two recipes bought
-- and learned stayed in the popup, because the cache only refreshes when that window opens).
-- By lower-case name, per character; the next sync covers them.
local function learnedSince()
    VoidProfCharDB = VoidProfCharDB or {}
    VoidProfCharDB.learnedSince = VoidProfCharDB.learnedSince or {}
    return VoidProfCharDB.learnedSince
end

-- the recipes this character knows, by profession name: { [lower name] = true }, or nil if never synced
local function known(profName)
    local c = VoidProf:ProfCache()[profName]
    if not c or not c.recipes then return nil end
    local out = {}
    for _, r in pairs(c.recipes) do
        if r.name then out[r.name:lower()] = true end
    end
    for name, t in pairs(learnedSince()) do
        if t > (c.lastSync or 0) then out[name] = true end
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
    local costs = VoidGPS and VoidGPS.Costs   -- VoidGPS 0.3.2+: which offers cost Merchant's Favor
    local out, unsynced = {}, false
    for _, e in ipairs(R:All()) do
        local p = byLine[e.line]
        if p then
            local k = knows[e.line]
            if not k then
                unsynced = true
            elseif not k[bare(e.name):lower()] and (e.skill or 0) <= (p.rank or 0) + SOON then
                -- favor = no vendor sells it for plain gold (Merchant's Favor + reputation, or a
                -- currency); v = the vendor to show and route to: the nearest gold one first
                local v
                for _, x in ipairs(e.vendors) do if not x.cost then v = x; break end end
                out[#out + 1] = { e = e, prof = p.name, skill = p.rank or 0, now = (e.skill or 0) <= (p.rank or 0),
                    favor = (costs and not e.gold) and true or false, v = v or e.vendors[1] }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.favor ~= b.favor then return not a.favor end   -- gold recipes first, Favor ones in their own section
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

-- what an offer costs besides gold, and whether you can pay it: text, can (true / false / nil = unknown)
local function costText(v)
    -- v.cost = paid with Favor / a currency; v.rep alone = a gold offer that needs reputation
    local c = v and (v.cost or (v.rep and { rep = v.rep }))
    if not c then return "", true end
    local C = VoidGPS and VoidGPS.Costs
    local have, myRank, _
    if C then have, _, myRank = C:Standing() end   -- (`C and C:Standing()` keeps only the first value)
    local can = true
    local bits = {}
    if c.favor then
        if type(c.favor) == "number" then
            bits[#bits + 1] = c.favor .. " Favor"
            if have and have < c.favor then can = false elseif not have then can = nil end
        else
            bits[#bits + 1] = "Favor"
            can = nil   -- the amount shows once you open that vendor
        end
    end
    if c.rep then
        bits[#bits + 1] = c.rep
        local need = C and C:RepRank(c.rep)
        if need and myRank and myRank < need then can = false elseif can and not myRank then can = nil end
    end
    if c.other then bits[#bits + 1] = c.other end
    local col = can == false and "|cffff5050" or "|cffff9f40"
    return col .. table.concat(bits, ", ") .. "|r", can
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
        if not d or d.header then return end
        tt:AddLine(" ")
        tt:AddLine("Sold by:", 0, 0.78, 1)
        for k, v in ipairs(d.e.vendors) do
            if k > 5 then break end
            local ct = costText(v)
            tt:AddDoubleLine(v.name .. (v.limited and " |cffffd200(limited)|r" or "") .. (ct ~= "" and (" " .. ct) or ""),
                zoneName(v.map) .. (v.yards and (" · " .. math.floor(v.yards) .. " yd") or ""), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        if d.favor then
            tt:AddLine("Bought with Merchant's Favor (Azeroth Commerce Authority), not gold.", 1, 0.62, 0.25, true)
            tt:AddLine("Click: the way to " .. (d.v and d.v.name or "the vendor"), 0.5, 0.8, 0.5)
        else
            tt:AddLine("Click: the way to the nearest one that takes gold", 0.5, 0.8, 0.5)
        end
    end)
end

function VR:Wants(profName)
    local p = VoidProf.SkillCap and VoidProf.SkillCap:Professions()[profName]
    return p and CRAFT[p.line] or false
end

local built = setmetatable({}, { __mode = "k" })   -- profession tabs with this block, to refresh on a learn

function VR:Build(parent, profName, anchor, makeButton)
    built[parent] = true
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
            if not self._d or self._d.header then return end
            hl:Show()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self._d.e.item)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() hl:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            local d = self._d
            if not d or d.header then return end
            if d.favor then
                -- no gold vendor: the Favor vendor this row names
                local R = api()
                if R and d.v and R:GoVendor(d.v, d.e.name) then
                    VoidProf:Print(("Heading to |cffffffff%s|r, %s (Merchant's Favor)."):format(d.v.name, zoneName(d.v.map)))
                end
            else
                go(d.e.item)
            end
        end)
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
        if d and d.header then
            -- the Merchant's Favor section: your Favor and Azeroth Commerce Authority standing
            local C = VoidGPS and VoidGPS.Costs
            local have, label
            if C then have, label = C:Standing() end
            local P = VoidUI.palette
            row._left:SetText(("|cff%02x%02x%02xMerchant's Favor recipes|r"):format(P.accent[1] * 255, P.accent[2] * 255, P.accent[3] * 255))
            row._right:SetText(("|cff888888you: %s Favor · ACA %s|r"):format(have and tostring(have) or "?", label or "not met"))
            row:Show()
        elseif d then
            local e, vend = d.e, d.v
            row._left:SetText((d.now and "|cffffffff" or "|cff888888") .. e.name .. "|r"
                .. (d.now and "" or (" |cff888888at " .. e.skill .. "|r")))
            local tail
            if d.favor then
                tail = "  " .. costText(vend)
            else
                -- a gold offer can still need reputation (a quartermaster's): say which
                tail = (e.limited and " |cffffd200limited|r" or "") .. (vend and vend.rep and (" |cffff9f40" .. vend.rep .. "|r") or "")
                    .. "  " .. priceText(e.buy)
            end
            row._right:SetText((vend and (vend.name .. " · " .. zoneName(vend.map)) or "?") .. tail)
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
    -- a header row before the first Merchant's Favor recipe (they sort last)
    local rows, now, soon, favor = {}, 0, 0, 0
    for _, d in ipairs(data) do
        if d.favor then
            if favor == 0 then rows[#rows + 1] = { header = true } end
            favor = favor + 1
        elseif d.now then now = now + 1 else soon = soon + 1 end
        rows[#rows + 1] = d
    end
    v.data, v.offset = rows, 0
    if unsynced then
        v.note:SetText("Open your " .. v.prof .. " window once so VoidProf knows which recipes you have.")
    elseif #data == 0 then
        v.note:SetText("No vendor recipe you don't know at your skill. More open up as you level.")
    else
        v.note:SetText(("%d you can learn now, %d soon (for gold)%s. Nearest vendor shown; click for the way. Mouse wheel scrolls."):format(
            now, soon, favor > 0 and (", " .. favor .. " for Merchant's Favor further down") or ""))
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

local function check(update)
    if not popupsOn() or not api() then return end
    if InCombatLockdown() then pendingZone = true; return end
    local zone = C_Map.GetBestMapForUnit("player")
    -- a popup from the zone you just left goes away
    if popup and popup:IsShown() and popup._zone ~= zone then popup:Hide() end
    if not zone then return end
    -- update = you learned a recipe: redo the popup that's up (never pop a new one)
    if update then
        if not (popup and popup:IsShown()) then return end
        shownFor[zone] = nil
        popup:Hide()
    end
    if shownFor[zone] then return end
    local here = {}   -- vendor name -> { recipes }
    local order = {}
    for _, d in ipairs((VR:ForYou())) do
        if d.now and not d.favor then
            for _, v in ipairs(d.e.vendors) do
                if v.map == zone and not v.cost then   -- gold offers only (not Merchant's Favor)
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

-- a recipe learned: note it, then redo the popup and any open recipe list
local learnPending
local function learned(name)
    if type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then return end
    learnedSince()[bare(name):lower()] = time()
    if learnPending then return end
    learnPending = true
    C_Timer.After(0.5, function()   -- learning two in a row: one redo
        learnPending = nil
        check(true)
        for parent in pairs(built) do
            if parent:IsShown() and parent._vr then VR:Refresh(parent) end
        end
    end)
end

-- "You have learned how to create a new item: %s." (the game's own string)
local LEARN_PAT = "^" .. (ERR_LEARN_RECIPE_S or "You have learned how to create a new item: %s.")
    :gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"

local ev = CreateFrame("Frame")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "NEW_RECIPE_LEARNED")
ev:RegisterEvent("CHAT_MSG_SYSTEM")   -- the same learn, in case the event doesn't fire for a learned item
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "NEW_RECIPE_LEARNED" then
        local info = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(arg1)
        learned((info and info.name) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(arg1)))
        return
    elseif event == "CHAT_MSG_SYSTEM" then
        if type(arg1) == "string" and not (issecretvalue and issecretvalue(arg1)) then
            local what = arg1:match(LEARN_PAT)
            if what then learned((what:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1"))) end
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingZone then pendingZone = nil; C_Timer.After(1, check) end
    else
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 8 or 2, check)
    end
end)
