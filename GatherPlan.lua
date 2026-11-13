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
GP.REQ = REQ   -- Farm.lua: can you gather it yourself

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
        -- capitals: fish get away there until 75, so they're a 75-150 spot (validated against
        -- current Forever fishing guides 2026-11-13; starting zones from 25, or 1 with a Shiny Bauble)
        { 1, 75,    { Horde = { 1411, 1412, 1420 }, Alliance = { 1429, 1426, 1438 } }, "any starting zone; below 25 some still get away (a Shiny Bauble stops that)" },
        { 75, 150,  { Horde = { 1454, 1458, 1456, 1413, 1421 }, Alliance = { 1453, 1455, 1457, 1436, 1432, 1439 } } },
        { 150, 225, { Horde = { 1442, 1440, 1424 }, Alliance = { 1437, 1433, 1431, 1440 } } },
        { 225, 300, { Horde = { 1443, 1441, 1445, 1434, 1417 }, Alliance = { 1445, 1417, 1434, 1443, 1441 } } },
    },
}

-- Fishing with a lure: the 205 zones (nothing gets away from 300) work from 225 with Bright
-- Baubles (+75, Old Man Heming in Booty Bay). Validated online against current WoW Forever fishing
-- guides on 2026-11-13 (sources in research_notes/, not shipped); the user: "ferales at the camp
-- for highest fishing". Fish that get away are measured in play (Farm.lua). Feralas first: a camp of your own
-- (Camp Mojache / Feathermoon Stronghold) with a flight master, and the fish 250+ Cooking wants.
local LURE = { name = "Bright Baubles", plus = 75, from = "Old Man Heming, Booty Bay" }
local LURE_ZONES = { 1444, 1446, 1448, 1425, 1449, 1422 }   -- Feralas, Tanaris, Felwood, Hinterlands, Un'Goro, W. Plaguelands
local LURE_LEVEL = 300                                      -- nothing gets away there without a lure
local LURE_SPOT = { [1444] = { Horde = "Camp Mojache", Alliance = "Feathermoon Stronghold" } }
GP.LURE, GP.LURE_ZONES, GP.LURE_LEVEL = LURE, LURE_ZONES, LURE_LEVEL

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

----------------------------------------------------------------------
-- Is a zone safe for you? (PvP realms; the user, 2026-11-09: "no zones tell me where to fish
-- that's safe on a pvp server"). Classic's faction territories; every other open zone is
-- contested. What the game says when you're in a zone (C_PvP.GetZonePVPInfo) is saved per
-- zone in VoidProfDB.zonePvP and wins over the table.
----------------------------------------------------------------------
local TERRITORY = {
    [1411] = "Horde", [1412] = "Horde", [1413] = "Horde", [1420] = "Horde", [1421] = "Horde",
    [1454] = "Horde", [1456] = "Horde", [1458] = "Horde",
    [1429] = "Alliance", [1426] = "Alliance", [1438] = "Alliance", [1439] = "Alliance",
    [1436] = "Alliance", [1432] = "Alliance", [1453] = "Alliance", [1455] = "Alliance", [1457] = "Alliance",
}
local SAFETY_TEXT = {
    yours = "|cff33ff33your territory|r", enemy = "|cffff5555enemy territory|r",
    contested = "|cffffb84dcontested|r", sanctuary = "|cff33ff33sanctuary|r",
}
local SAFETY_HEX = { yours = "ffffff", sanctuary = "ffffff", contested = "ffb84d", enemy = "ff5555" }

local function readable(v)
    if canaccessvalue then return canaccessvalue(v) end
    return not (issecretvalue and issecretvalue(v))
end

local function zoneOf(map)
    local info = map and C_Map.GetMapInfo(map)
    local hops = 0
    while info and info.mapType and info.mapType > Enum.UIMapType.Zone and (info.parentMapID or 0) > 0 and hops < 5 do
        info = C_Map.GetMapInfo(info.parentMapID)
        hops = hops + 1
    end
    return info and info.mapType == Enum.UIMapType.Zone and info.mapID or nil
end

-- "yours" | "enemy" | "contested" | "sanctuary"
function GP:Safety(map)
    local mine = UnitFactionGroup("player") or "Horde"
    local learned = VoidProfDB and VoidProfDB.zonePvP and VoidProfDB.zonePvP[map]
    local v = learned or TERRITORY[map] or "contested"
    if v == mine then return "yours" end
    if v == "Horde" or v == "Alliance" then return "enemy" end
    return v
end

-- what the game says about the zone you're in, saved for later (absolute faction names)
local function learnZone()
    if IsInInstance() or not (C_PvP and C_PvP.GetZonePVPInfo) then return end
    local map = zoneOf(C_Map.GetBestMapForUnit("player"))
    local pvpType = C_PvP.GetZonePVPInfo()
    if not (map and pvpType and readable(pvpType)) then return end
    local mine = UnitFactionGroup("player") or "Horde"
    local other = mine == "Horde" and "Alliance" or "Horde"
    local v = (pvpType == "friendly" and mine) or (pvpType == "hostile" and other)
        or (pvpType == "contested" and "contested") or (pvpType == "sanctuary" and "sanctuary") or nil
    if not v then return end
    VoidProfDB = VoidProfDB or {}
    VoidProfDB.zonePvP = VoidProfDB.zonePvP or {}
    VoidProfDB.zonePvP[map] = v
end

local function zoneLabel(id)
    return "|cff" .. (SAFETY_HEX[GP:Safety(id)] or "ffffff") .. mapName(id) .. "|r"
end

-- Fishing: the zones where nothing gets away at this skill (every step started), split into
-- your own territory and the rest
local function fishZonesFor(skill)
    local fac = UnitFactionGroup("player") or "Horde"
    local safe, risky, seen = {}, {}, {}
    for _, s in ipairs(PLANS[FISH]) do
        if s[1] <= skill then
            for _, id in ipairs(s[3][fac] or s[3].Horde) do
                if not seen[id] then
                    seen[id] = true
                    local sf = GP:Safety(id)
                    local t = (sf == "yours" or sf == "sanctuary") and safe or risky
                    t[#t + 1] = id
                end
            end
        end
    end
    return safe, risky
end

-- the fishing step a zone belongs to: nothing gets away there from this skill on
local function fishLevelOf(map)
    local fac = UnitFactionGroup("player") or "Horde"
    for _, s in ipairs(PLANS[FISH]) do
        for _, id in ipairs(s[3][fac] or s[3].Horde) do
            if id == map then return s[1] end
        end
    end
    for _, id in ipairs(LURE_ZONES) do
        if id == map then return LURE_LEVEL end
    end
end

-- "Feralas (Camp Mojache) · Tanaris · ...": the lure zones, Feralas first
local function lureZonesText()
    local fac = UnitFactionGroup("player") or "Horde"
    local z = {}
    for _, id in ipairs(LURE_ZONES) do
        local spot = LURE_SPOT[id] and LURE_SPOT[id][fac]
        z[#z + 1] = mapName(id) .. (spot and (" (" .. spot .. ")") or "")
    end
    return table.concat(z, " · ")
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
        for _, id in ipairs(s[3][fac] or s[3].Horde) do z[#z + 1] = zoneLabel(id) end
        parts[#parts + 1] = table.concat(z, " · ") .. (s[4] and ("|cff888888, " .. s[4] .. "|r") or "")
        return head .. "  " .. parts[1]   -- where to fish now: the headline block at the top (GP:Refresh)
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

-- For VoidAsk (the question box): Herbalism / Mining nodes that give skill at this skill, best
-- color first, and one node's color at a skill ("orange" / "yellow" / "green" / "grey" / "locked")
function GP:Useful(profName, skill)
    local line = LINE_OF[profName]
    if not line or line == FISH then return {} end
    return useful(line, skill, stepOf(PLANS[line], skill))
end
function GP:Color(name, skill) return color(REQ[name] or 1, skill) end

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
        -- the answer first, in its own block (the user, 2026-11-09: the tab "looks the same", the
        -- safe zones were buried under a paragraph at the bottom)
        local safe, risky = fishZonesFor(skill)
        local a, b = {}, {}
        for _, id in ipairs(safe) do a[#a + 1] = mapName(id) end
        for _, id in ipairs(risky) do b[#b + 1] = zoneLabel(id) end
        lines[#lines + 1] = ("|cff00c7ffWhere to fish at %d|r"):format(skill)
        if #a > 0 then lines[#lines + 1] = "|cff33ff33Safe, nothing gets away:|r " .. table.concat(a, " · ") end
        if #b > 0 then lines[#lines + 1] = "|cffffb84dContested, nothing gets away:|r " .. table.concat(b, " · ") end
        -- 225+: the best fish with a lure on (WoW Forever's fishing guide sends 225-300 here)
        if skill + LURE.plus >= LURE_LEVEL and skill < LURE_LEVEL then
            lines[#lines + 1] = ("|cff33ff33With %s (+%d, %s) nothing gets away:|r %s"):format(
                LURE.name, LURE.plus, LURE.from, lureZonesText())
        elseif skill >= LURE_LEVEL then
            lines[#lines + 1] = "|cff33ff33Also nothing gets away, no lure needed:|r " .. lureZonesText()
        end
        local nxt = plan[cur + 1] or (skill < plan[cur][1] and plan[cur]) or nil
        if nxt and nxt[1] > skill then
            local fac = UnitFactionGroup("player") or "Horde"
            local z = {}
            for _, id in ipairs(nxt[3][fac] or nxt[3].Horde) do z[#z + 1] = zoneLabel(id) end
            lines[#lines + 1] = ("|cffaaaaaaBetter fish, but some get away until %d:|r %s"):format(nxt[1], table.concat(z, " · "))
        end
        lines[#lines + 1] = "|cff888888Every catch gives skill at the same rate wherever none get away, so the safe zones level you just as fast. A lure adds skill and lets you move up early.|r"
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

----------------------------------------------------------------------
-- Arriving in a zone (the user, 2026-11-09: "no zones tell me where I will most likely get
-- the best skill up ... these types of info need to be available for all of them"): one chat
-- line, once per zone per session, with the zone's safety and, for the gathering skills you
-- have, whether fish get away here and which herbs / ores here still give you skill.
-- Off: the Void hub's quick box ("Prof: Zone tips"), per character.
----------------------------------------------------------------------
local KIND = {}
for _, line in ipairs({ HERB, MINE }) do
    for _, s in ipairs(PLANS[line]) do
        for _, n in ipairs(s[3]) do KIND[n] = line end
    end
end

local function tipsOn() return not (VoidProfCharDB and VoidProfCharDB.zoneTips == false) end

function GP:ZoneLine(map)
    local profs = VoidProf.SkillCap and VoidProf.SkillCap:Professions() or {}
    local parts = {}
    local fish = profs.Fishing
    if fish then
        local lvl = fishLevelOf(map)
        if lvl and fish.rank >= lvl then
            parts[#parts + 1] = ("Fishing %d: nothing gets away here"):format(fish.rank)
        elseif lvl and lvl == LURE_LEVEL and fish.rank + LURE.plus >= lvl then
            parts[#parts + 1] = ("Fishing %d: nothing gets away here with %s on (+%d)"):format(fish.rank, LURE.name, LURE.plus)
        elseif lvl then
            parts[#parts + 1] = ("Fishing %d: |cffffb84dsome fish get away here until %d|r"):format(fish.rank, lvl)
        end
        -- what you measured here at this skill (Farm.lua logs catches and getaways) beats the table
        local b = math.floor(fish.rank / 5) * 5
        local away = VoidProfDB and VoidProfDB.fishAway and VoidProfDB.fishAway[map] and VoidProfDB.fishAway[map][b] or 0
        local c = VoidProfDB and VoidProfDB.catches and VoidProfDB.catches[map]
        local got = c and c.at and c.at[b] or 0
        if got + away >= 10 then
            parts[#parts + 1] = ("measured at your skill: %d of %d got away"):format(away, got + away)
        end
    end
    local N = nodes()
    for _, pl in ipairs({ { "Herbalism", HERB }, { "Mining", MINE } }) do
        local p = profs[pl[1]]
        if p and N then
            local here = {}
            for name, line in pairs(KIND) do
                local c = line == pl[2] and color(REQ[name] or 1, p.rank)
                if c == "orange" or c == "yellow" or c == "green" then
                    for _, z in ipairs(N:Zones({ name })) do
                        if z.map == map then
                            here[#here + 1] = { name = name, c = c, req = REQ[name] or 1 }
                            break
                        end
                    end
                end
            end
            if #here > 0 then
                table.sort(here, function(a, b) return a.req > b.req end)
                local t = {}
                for i = 1, math.min(4, #here) do t[i] = paint(here[i].c, here[i].name) end
                parts[#parts + 1] = ("%s %d: %s"):format(pl[1], p.rank, table.concat(t, ", "))
            end
        end
    end
    -- Skinning: a beast needs level x 5 skill (level 21+), (level - 10) x 10 below that; the
    -- zone's top level says what the best beasts here are worth to you
    local sk = profs.Skinning
    if sk and C_Map.GetMapLevels then
        local lo, hi = C_Map.GetMapLevels(map)
        if hi and hi > 0 then
            local function need(lvl) return lvl <= 10 and 1 or (lvl <= 20 and (lvl - 10) * 10 or lvl * 5) end
            local c = color(need(hi), sk.rank)
            local word = (c == "locked" and ("most beasts here are too high (level %d needs %d)"):format(hi, need(hi)))
                or (c == "grey" and "beasts here give no skill")
                or ("level %d-%d beasts here: %s"):format(lo or hi, hi, paint(c, c))
            parts[#parts + 1] = ("Skinning %d: %s"):format(sk.rank, word)
        end
    end
    if #parts == 0 then return nil end
    return ("|cff00c7ffVoidProf|r %s (%s): %s"):format(mapName(map), SAFETY_TEXT[GP:Safety(map)] or "?",
        table.concat(parts, " · "))
end

local told = {}
local zf = CreateFrame("Frame")
zf:RegisterEvent("PLAYER_ENTERING_WORLD")
zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zf:SetScript("OnEvent", function()
    -- the map and PvP info settle a moment after the event
    C_Timer.After(2, function()
        learnZone()
        if not tipsOn() or IsInInstance() then return end
        local map = zoneOf(C_Map.GetBestMapForUnit("player"))
        if not map or told[map] then return end
        told[map] = true
        local line = GP:ZoneLine(map)
        if line then print(line) end
    end)
end)

VoidHubToggles = VoidHubToggles or {}
table.insert(VoidHubToggles, {
    id = "VoidProf.zoneTips", group = "Prof", label = "Zone tips",
    tip = "Entering a zone: one chat line with its safety (your territory or contested), whether fish get away there at your skill, and the herbs and ore there that still give you skill.",
    get = tipsOn,
    set = function(on)
        VoidProfCharDB = VoidProfCharDB or {}
        -- (not "x and false or nil": that is always nil, so tips could never be turned off; Sol review)
        if on then VoidProfCharDB.zoneTips = nil else VoidProfCharDB.zoneTips = false end
    end,
})

----------------------------------------------------------------------
-- Herb and ore tooltips in the world: does it still give you skill? (orange always, yellow
-- usually, green sometimes, grey never; "needs 230" when you can't gather it yet)
----------------------------------------------------------------------
local WORD = { orange = "always gives skill", yellow = "usually gives skill", green = "sometimes gives skill",
    grey = "no skill for you" }
local PROF_OF = { [HERB] = "Herbalism", [MINE] = "Mining" }

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType
    and Enum.TooltipDataType.Object then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, function(tt, data)
        if tt ~= GameTooltip or type(data) ~= "table" or not data.lines or not data.lines[1] then return end
        local name = data.lines[1].leftText
        if not (name and readable(name)) then return end
        local line = KIND[name]
        if not line then return end
        local p = VoidProf.SkillCap and VoidProf.SkillCap:Professions()[PROF_OF[line]]
        if not p then return end
        local req = REQ[name] or 1
        local c = color(req, p.rank)
        -- only what matters to you (the user, 2026-11-09: "too much data can be overwhelming"):
        -- a grey node gets no line at all
        if c == "grey" then return end
        if c == "locked" then
            tt:AddLine(("|cff00c7ffVoidProf:|r %s"):format(paint("locked", ("needs %s %d (you: %d)"):format(PROF_OF[line], req, p.rank))))
        else
            tt:AddLine(("|cff00c7ffVoidProf:|r %s"):format(paint(c, WORD[c] .. (" (%s %d)"):format(PROF_OF[line], p.rank))))
        end
        tt:Show()
    end)
end
