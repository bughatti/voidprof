----------------------------------------------------------------------
-- GatherPlan.lua — WoW Forever only: a step-by-step plan for Herbalism, Mining
-- and Fishing, under the "Next skill cap" block of their tabs.
--
-- Each step: the skill range, what to pick / mine / smelt in it (colored the way
-- the game colors it for your skill now), and where. Zones and the "Nearest
-- spot" route come from VoidGPS (its herb and ore spots, from NorgannonDB) when
-- it's installed; VoidProf itself ships only the skill tables below.
--
-- Skill needed per node / smelt and the gathering colors (orange below +25,
-- yellow below +50, green below +100, then grey) are Classic's. Fishing: every
-- catch can give skill wherever you fish, so the plan sends you to the highest
-- zones where no fish get away at your skill (Classic zone values).
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end

local _, ns = ...
VoidProf = VoidProf or {}
local GP = {}
VoidProf.GatherPlan = GP

local HERB, MINE, FISH = 182, 186, 356

local REQ = {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Earthroot"] = 15, ["Mageroyal"] = 50, ["Briarthorn"] = 70,
    ["Stranglekelp"] = 85, ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115, ["Grave Moss"] = 120,
    ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160, ["Goldthorn"] = 170,
    ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195, ["Firebloom"] = 205, ["Purple Lotus"] = 210,
    ["Arthas' Tears"] = 220, ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270, ["Mountain Silversage"] = 280,
    ["Plaguebloom"] = 285, ["Icecap"] = 290, ["Black Lotus"] = 300,
    ["Copper Vein"] = 1, ["Tin Vein"] = 65, ["Incendicite Mineral Vein"] = 65, ["Silver Vein"] = 75,
    ["Lesser Bloodstone Deposit"] = 75, ["Iron Deposit"] = 125, ["Gold Vein"] = 155, ["Mithril Deposit"] = 175,
    ["Truesilver Deposit"] = 230, ["Dark Iron Deposit"] = 230, ["Small Thorium Vein"] = 245, ["Rich Thorium Vein"] = 275,
}

-- smelting: recipe name -> { skill to learn it, bar }
local SMELT = {
    ["Smelt Copper"] = { 1, "Copper Bar" }, ["Smelt Tin"] = { 65, "Tin Bar" }, ["Smelt Bronze"] = { 65, "Bronze Bar" },
    ["Smelt Silver"] = { 75, "Silver Bar" }, ["Smelt Iron"] = { 125, "Iron Bar" }, ["Smelt Gold"] = { 155, "Gold Bar" },
    ["Smelt Steel"] = { 165, "Steel Bar" }, ["Smelt Mithril"] = { 175, "Mithril Bar" },
    ["Smelt Truesilver"] = { 230, "Truesilver Bar" }, ["Smelt Thorium"] = { 250, "Thorium Bar" },
}

local PLANS = {
    [HERB] = {
        { 1, 50,    { "Peacebloom", "Silverleaf", "Earthroot" } },
        { 50, 70,   { "Mageroyal", "Earthroot" } },
        { 70, 100,  { "Briarthorn", "Mageroyal", "Stranglekelp" } },
        { 100, 125, { "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Briarthorn" } },
        { 125, 160, { "Kingsblood", "Liferoot", "Wild Steelbloom" } },
        { 160, 185, { "Fadeleaf", "Goldthorn", "Liferoot" } },
        { 185, 205, { "Khadgar's Whisker", "Goldthorn", "Wintersbite" } },
        { 205, 230, { "Firebloom", "Purple Lotus", "Arthas' Tears" } },
        { 230, 250, { "Sungrass", "Blindweed", "Ghost Mushroom" } },
        { 250, 270, { "Gromsblood", "Golden Sansam", "Sungrass" } },
        { 270, 300, { "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Icecap" } },
    },
    [MINE] = {
        { 1, 65,    { "Copper Vein" }, { "Smelt Copper" } },
        { 65, 125,  { "Tin Vein", "Silver Vein", "Incendicite Mineral Vein", "Lesser Bloodstone Deposit" }, { "Smelt Tin", "Smelt Bronze", "Smelt Silver" } },
        { 125, 175, { "Iron Deposit", "Gold Vein" }, { "Smelt Iron", "Smelt Gold", "Smelt Steel" } },
        { 175, 245, { "Mithril Deposit", "Truesilver Deposit", "Dark Iron Deposit" }, { "Smelt Mithril", "Smelt Truesilver" } },
        { 245, 300, { "Small Thorium Vein", "Rich Thorium Vein" }, { "Smelt Thorium" } },
    },
    -- fishing: zones (UI maps) where no fish get away from the step's first skill
    [FISH] = {
        { 1, 75,    { Horde = { 1411, 1454, 1412, 1420 }, Alliance = { 1429, 1426, 1438, 1453 } }, "any starting zone or capital; below 25 some still get away" },
        { 75, 150,  { Horde = { 1413, 1421 }, Alliance = { 1436, 1432, 1439 } } },
        { 150, 225, { Horde = { 1442, 1440, 1424 }, Alliance = { 1437, 1433, 1431, 1440 } } },
        { 225, 300, { Horde = { 1443, 1441, 1445, 1434, 1417 }, Alliance = { 1445, 1417, 1434, 1443, 1441 } } },
    },
}

local HEX = { orange = "ff8040", yellow = "ffff00", green = "40c040", grey = "808080", locked = "5a5a5a" }
local DIFF = { [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey" }   -- Enum.TradeskillRelativeDifficulty

local function color(req, skill)
    if skill < req then return "locked" end
    if skill < req + 25 then return "orange" end
    if skill < req + 50 then return "yellow" end
    if skill < req + 100 then return "green" end
    return "grey"
end

local function paint(c, text) return "|cff" .. HEX[c] .. text .. "|r" end

local function nodes() return VoidGPS and VoidGPS.Nodes end

local function mapName(id)
    local i = C_Map.GetMapInfo(id)
    return i and i.name or "?"
end

local function myContinent()
    local m = C_Map.GetBestMapForUnit("player")
    local info = m and MapUtil.GetMapParentInfo(m, Enum.UIMapType.Continent, true)
    return info and info.mapID
end

-- the recipes this character knows for the profession, from VoidProf's cache:
-- name -> difficulty color (or nil when the window hasn't been opened yet)
local function recipes(profName)
    local c = VoidProf:ProfCache()[profName]
    local out = {}
    for _, r in pairs(c and c.recipes or {}) do
        if r.name then out[r.name] = DIFF[r.difficulty] or "?" end
    end
    return out, c ~= nil
end

local function stepOf(plan, skill)
    for i, s in ipairs(plan) do
        if skill < s[2] then return i end
    end
    return #plan
end

-- "The Barrens (120) · Stonetalon Mountains (64); elsewhere: Hillsbrad Foothills (70)"
local function zonesText(names)
    local N = nodes()
    if not N then return nil end
    local list = N:Zones(names)
    if #list == 0 then return nil end
    local here, there = {}, {}
    local mine = myContinent()
    for _, z in ipairs(list) do
        local t = z.cont == mine and here or there
        if #t < 3 then t[#t + 1] = ("%s |cff888888(%d)|r"):format(z.name, z.n) end
    end
    local s = table.concat(here, " · ")
    if #there > 0 then
        s = s .. (#here > 0 and "  |cff888888elsewhere:|r " or "") .. table.concat(there, " · ", 1, math.min(#there, 2))
    end
    return s
end

local function lineFor(line, s, skill, profName, i, cur)
    local range = ("%d–%d"):format(s[1], s[2])
    local head = i == cur and ("|cff00c7ff> " .. range .. "|r") or (i < cur and ("|cff666666" .. range .. "|r") or range)
    local parts = {}
    if line == FISH then
        local fac = UnitFactionGroup("player") or "Horde"
        local z = {}
        for _, id in ipairs(s[3][fac] or s[3].Horde) do z[#z + 1] = mapName(id) end
        parts[#parts + 1] = table.concat(z, " · ") .. (s[4] and ("|cff888888, " .. s[4] .. "|r") or "")
        return head .. "  " .. parts[1]
    end
    local names = {}
    for _, n in ipairs(s[3]) do
        local c = color(REQ[n] or 1, skill)
        names[#names + 1] = c == "locked" and paint("locked", n .. " at " .. REQ[n]) or paint(c, n)
    end
    local out = head .. "  " .. table.concat(names, ", ")
    if s[4] then
        local known = recipes(profName)
        local sm = {}
        for _, r in ipairs(s[4]) do
            local d = SMELT[r]
            local c = known[r]
            if c and c ~= "?" then sm[#sm + 1] = paint(c, d[2])
            elseif skill < d[1] then sm[#sm + 1] = paint("locked", d[2] .. " at " .. d[1])
            else sm[#sm + 1] = d[2] .. (c and "" or " |cff888888(learn at a mining trainer)|r") end
        end
        out = out .. "\n      |cffaaaaaaSmelt:|r " .. table.concat(sm, ", ")
    end
    if i >= cur then
        local z = zonesText(s[3])
        if z then out = out .. "\n      |cffaaaaaaWhere:|r " .. z end
    end
    return out
end

-- what the Nearest button heads for: this step's nodes that give skill now, best color first
local function useful(line, skill, cur)
    local plan = PLANS[line]
    local out = {}
    for _, want in ipairs({ "orange", "yellow", "green" }) do
        for i = cur, math.max(1, cur - 1), -1 do
            for _, n in ipairs(plan[i][3]) do
                if color(REQ[n] or 1, skill) == want then out[#out + 1] = n end
            end
        end
        if #out > 0 then return out end
    end
    return out
end

----------------------------------------------------------------------
-- Panel block (SkillCap:Build adds it for the three gathering professions)
----------------------------------------------------------------------
local LINE_OF = { Herbalism = HERB, Mining = MINE, Fishing = FISH }

function GP:Wants(profName) return LINE_OF[profName] ~= nil end

function GP:Build(parent, profName, anchor, makeButton)
    local line = LINE_OF[profName]
    if not line then return end
    local P = VoidUI.palette
    local head = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(head, 11, "OUTLINE")
    head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -44)
    head:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    head:SetText("Leveling plan")

    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 4)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(480, 10)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
    end)
    -- one anchor per block and an explicit width (a RIGHT anchor would also pin its height)
    local function block()
        local t = child:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(t, 10, "")
        t:SetWidth(470)
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetWordWrap(true)
        t:SetSpacing(3)
        t:SetTextColor(0.85, 0.85, 0.88)
        return t
    end
    local top, bottom = block(), block()   -- steps up to yours, then the button, then the rest
    top:SetPoint("TOPLEFT", 0, 0)
    sf:SetScript("OnSizeChanged", function(_, w)
        if w and w > 0 then
            child:SetWidth(w)
            top:SetWidth(w - 4); bottom:SetWidth(w - 4)
            if parent._plan then GP:Refresh(parent) end   -- heights change with the width
        end
    end)

    local btn
    if line ~= FISH then
        btn = makeButton(child, 150, 22, "|cffffd200Nearest spot|r", function(b)
            local N = nodes()
            if not N then
                VoidProf:Print("Install VoidGPS (free, same author) for routes to the nearest herb and ore.")
                return
            end
            if not b._names or #b._names == 0 then
                VoidProf:Print("Nothing in this step gives you skill yet.")
                return
            end
            local ok, name, map, yd = N:Go(b._names)
            if ok then
                VoidProf:Print(("Heading to the nearest |cffffffff%s|r%s, %s."):format(name,
                    yd and (" (" .. math.floor(yd) .. " yd)") or "", mapName(map)))
            else
                VoidProf:Warn("No spots known for that.")
            end
        end)
        btn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText("Nearest spot", 1, 1, 1)
            GameTooltip:AddLine("A VoidGPS route to the nearest place one of these can spawn: "
                .. table.concat(b._names or {}, ", ") .. ". Picked already? Press again: it skips the spots it just sent you to.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    if btn then
        btn:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 24, -6)
        bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -36)
    else
        bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -3)
    end
    parent._plan = { line = line, prof = profName, top = top, bottom = bottom, child = child, sf = sf, btn = btn }
end

function GP:Refresh(parent)
    local p = parent and parent._plan
    if not p then return end
    local prof = VoidProf.SkillCap and VoidProf.SkillCap:Professions()[p.prof]
    if not prof then
        p.top:SetText(""); p.bottom:SetText("")
        if p.btn then p.btn:Hide() end
        return
    end
    local skill = prof.rank or 0
    local plan = PLANS[p.line]
    local cur = stepOf(plan, skill)
    local lines = {}

    if p.line == FISH then
        lines[#lines + 1] = "|cffaaaaaaEvery catch can give skill wherever you fish, so fish where none get away: the zones of your step. Higher zones have better fish but lose some until you reach their step. A lure (fishing supplies vendor) adds skill and lets you move up early.|r"
    else
        lines[#lines + 1] = ("|cffaaaaaaColors for your skill (%d): %s always gives skill, %s usually, %s sometimes, %s never.|r"):format(
            skill, paint("orange", "orange"), paint("yellow", "yellow"), paint("green", "green"), paint("grey", "grey"))
    end
    -- crafts that aren't smelting (Forever's Camping crafts): do any give skill now?
    local known, seen = recipes(p.prof)
    local crafts = {}
    for name, c in pairs(known) do
        if not SMELT[name] then crafts[#crafts + 1] = (c ~= "?" and paint(c, name)) or name end
    end
    table.sort(crafts)
    if #crafts > 0 then
        lines[#lines + 1] = "|cffaaaaaaYour crafts (colored for skill):|r " .. table.concat(crafts, ", ")
    elseif not seen and p.line ~= FISH then
        lines[#lines + 1] = "|cff888888Open the profession once so VoidProf can see your crafts' colors.|r"
    end
    if not nodes() and p.line ~= FISH then
        lines[#lines + 1] = "|cff888888Install VoidGPS for the best zones and a route to the nearest spot.|r"
    end
    lines[#lines + 1] = " "

    local rest = {}
    for i, s in ipairs(plan) do
        local t = lineFor(p.line, s, skill, p.prof, i, cur)
        if i <= cur then lines[#lines + 1] = t else rest[#rest + 1] = t end
    end
    p.top:SetText(table.concat(lines, "\n"))
    p.bottom:SetText(table.concat(rest, "\n"))
    if p.btn then
        p.btn._names = useful(p.line, skill, cur)
        p.btn:Show()
    end
    local h = (p.top:GetStringHeight() or 0) + (p.btn and 36 or 3) + (p.bottom:GetStringHeight() or 0)
    p.child:SetHeight(h + 8)
end
