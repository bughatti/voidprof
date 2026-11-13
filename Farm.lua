----------------------------------------------------------------------
-- Farm.lua -- WoW Forever: what getting a crafting material YOURSELF costs, so the leveling plan
-- (Planner.lua) can weigh it against buying it. The user, 2026-11-13: "the calculations should be
-- based on going and getting a recipe from a vendor, buying the mats to complete it, or easy
-- farming for mats, or just plain buying the recipe and mats on the ah".
--
-- Farming costs time, not gold, so it's priced as minutes x what your time is worth
-- (F:GoldPerHour: VoidProfDB.farmGoldHour, else a default by level). Ways, the fastest one wins:
--   * kill: normal mobs that drop it (VoidGPS.Drops, NorgannonDB), at most one level above you;
--     kills per item = 100 / drop chance, seconds per kill by how far below you they are
--   * fish: the waters each Classic fish comes from (FISH below, unverified on Forever) and,
--     better, what you have caught yourself: every fishing loot is logged per zone
--     (VoidProfDB.catches) and a zone with 15+ catches uses your own share of that fish
--   * herb / ore: with Herbalism / Mining high enough for the node (GatherPlan's skill table),
--     where VoidGPS knows the node spawns
--   * skin: leather from beasts of the right level, with Skinning high enough (SKIN below)
--   (cloth, meat, eggs, spider legs... are all "kill": whatever normal mobs drop)
-- F:Cost(itemID) -> { copper, minutes, how, text, map, x, y } of the fastest way, or nil.
----------------------------------------------------------------------
local _, ns = ...
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end
VoidProf = VoidProf or {}
local F = {}
VoidProf.Farm = F

-- What an hour of your time is worth, in copper: your setting, else level^2 / 240 gold
-- (60: 15g, 40: about 6.7g, 30: about 3.8g; roughly what farming earns at that level).
function F:GoldPerHour()
    local g = VoidProfDB and tonumber(VoidProfDB.farmGoldHour)
    if g and g > 0 then return g * 10000, true end
    local lvl = UnitLevel("player") or 60
    return math.max(0.5, lvl * lvl / 240) * 10000, false
end

local function mapName(m)
    local i = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    return i and i.name or "?"
end

local function skillOf(profName)
    local S = VoidProf.SkillCap
    local p = S and S.Professions and S:Professions()[profName]
    return p and p.rank or nil
end

local function safety(map)
    local GP = VoidProf.GatherPlan
    local ok, s = pcall(function() return GP and GP.Safety and GP:Safety(map) end)
    return ok and s or nil
end

----------------------------------------------------------------------
-- Fishing
----------------------------------------------------------------------
-- Classic's waters for the fish recipes use (uiMap ids; skill = about where they start to bite
-- without getting away). Not checked on Forever: your own catches below override it per zone.
-- Seasonal fish (Summer Bass, Winter Squid) are left out; night / day ones say so.
local FISH = {
    [6291]  = { skill = 1,   zones = { 1411, 1412, 1420, 1426, 1429, 1438 } },             -- Raw Brilliant Smallfish
    [6303]  = { skill = 1,   zones = { 1411, 1438, 1439 } },                               -- Raw Slitherskin Mackerel
    [6289]  = { skill = 1,   zones = { 1411, 1412, 1420, 1426, 1429, 1438, 1413, 1421, 1436, 1432 } }, -- Raw Longjaw Mud Snapper
    [6361]  = { skill = 25,  zones = { 1439, 1436, 1413 } },                               -- Raw Rainbow Fin Albacore
    [6317]  = { skill = 25,  zones = { 1432 } },                                           -- Raw Loch Frenzy
    [6308]  = { skill = 75,  zones = { 1437, 1424, 1440, 1442, 1433, 1431 } },             -- Raw Bristle Whisker Catfish
    -- Rockscale Cod: the coasts of the 225 / 300 zones only (not Wetlands / Hillsbrad / Darkshore,
    -- whose coasts give Rainbow Fin Albacore); validated 2026-11-13
    [6362]  = { skill = 150, zones = { 1417, 1447, 1443, 1445, 1444, 1434, 1435, 1446, 1425 } }, -- Raw Rockscale Cod
    [8365]  = { skill = 150, zones = { 1417, 1416, 1443, 1435, 1434, 1445 } },             -- Raw Mithril Head Trout
    [4603]  = { skill = 150, zones = { 1434, 1443, 1446, 1444, 1445, 1447 } },             -- Raw Spotted Yellowtail
    [13758] = { skill = 225, zones = { 1444, 1449, 1448, 1425, 1422 } },                   -- Raw Redgill
    [13754] = { skill = 225, zones = { 1444, 1446, 1447 } },   -- Raw Glossy Mightfish (in STV only off Jaguero Isle: left out)
    [13759] = { skill = 225, zones = { 1444, 1449, 1448, 1425, 1422 }, when = "from 6 PM to noon" },   -- Raw Nightfin Snapper
    [13760] = { skill = 225, zones = { 1444, 1449, 1448, 1425, 1422 }, when = "from 6 AM to midnight" }, -- Raw Sunscale Salmon
    -- Winterspring's waters need skill (with lure) well past 300 before fish stop getting away
    [13889] = { skill = 330, zones = { 1452 } },                                           -- Raw Whitescale Salmon
}
F.FISH = FISH
local CAST_SECS = 18        -- a cast and its loot
local TABLE_SHARE = 0.3     -- share of catches when only the table says the fish is there
local OWN_MIN = 15          -- catches in a zone before your own log is trusted

-- your catches: VoidProfDB.catches[uiMap] = { n = fishing loots, items = { [itemID] = loots with it } }
local function zoneMap()
    local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    for _ = 1, 4 do   -- up to the zone (a cave or a town is a child map)
        local i = m and C_Map.GetMapInfo(m)
        if not i or i.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3) then break end
        m = i.parentMapID
    end
    return m
end
local logger = CreateFrame("Frame")
logger:RegisterEvent("LOOT_OPENED")
logger:RegisterEvent("UI_ERROR_MESSAGE")
logger:SetScript("OnEvent", function(_, event, _, msg)
    -- "Your fish got away!": counted per zone and per 5 points of Fishing skill, so where fish get
    -- away at which skill is measured in play, not taken from a table (2026-11-13)
    if event == "UI_ERROR_MESSAGE" then
        if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) or msg ~= (ERR_FISH_ESCAPED or "Your fish got away!") then return end
        local map, skill = zoneMap(), skillOf("Fishing")
        if not (map and skill) then return end
        VoidProfDB = VoidProfDB or {}
        VoidProfDB.fishAway = VoidProfDB.fishAway or {}
        local z = VoidProfDB.fishAway[map] or {}
        VoidProfDB.fishAway[map] = z
        local b = math.floor(skill / 5) * 5
        z[b] = (z[b] or 0) + 1
        return
    end
    if not (IsFishingLoot and IsFishingLoot()) then return end
    local map = zoneMap()
    if not map then return end
    VoidProfDB = VoidProfDB or {}
    VoidProfDB.catches = VoidProfDB.catches or {}
    local z = VoidProfDB.catches[map] or { n = 0, items = {} }
    VoidProfDB.catches[map] = z
    z.n = z.n + 1
    -- the lowest Fishing skill any of your characters caught here with: the log is account-wide,
    -- so a low alt mustn't be sent where only your main's skill lands these fish (Sol review)
    local skill = skillOf("Fishing")
    if skill then
        z.skill = math.min(z.skill or skill, skill)
        z.at = z.at or {}   -- catches per 5 points of skill (against fishAway: how many got away)
        local b = math.floor(skill / 5) * 5
        z.at[b] = (z.at[b] or 0) + 1
    end
    for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
        local link = GetLootSlotLink and GetLootSlotLink(i)
        local id = type(link) == "string" and not (issecretvalue and issecretvalue(link)) and tonumber(link:match("item:(%d+)"))
        if id then z.items[id] = (z.items[id] or 0) + 1 end
    end
end)

-- minutes per fish of `id` and where: the zone with the best share (yours once logged)
local function fishCost(id, skill)
    local t = FISH[id]
    local best, bestMap, own
    local catches = VoidProfDB and VoidProfDB.catches or {}
    for map, z in pairs(catches) do
        if (z.n or 0) >= OWN_MIN and (z.items[id] or 0) > 0
            and skill >= math.max(z.skill or 0, t and t.skill or 0) then
            -- per cast, fish that got away included (they cost a cast too: Sol review)
            local away = 0
            for _, n in pairs(VoidProfDB and VoidProfDB.fishAway and VoidProfDB.fishAway[map] or {}) do away = away + n end
            local share = z.items[id] / (z.n + away)
            if not best or share > best then best, bestMap, own = share, map, true end
        end
    end
    if not best and t and skill >= t.skill then
        -- the table's zones, your own territory first (safe fishing on a PvP server)
        local order = { yours = 1, sanctuary = 1, contested = 2, enemy = 3 }
        local pick, rank
        for _, m in ipairs(t.zones) do
            local z = catches[m]
            -- a zone you fished a lot without it isn't a place for it
            if not (z and (z.n or 0) >= OWN_MIN and (z.items[id] or 0) == 0) then
                local r = order[safety(m) or "contested"] or 2
                if not rank or r < rank then pick, rank = m, r end
            end
        end
        if pick then best, bestMap = TABLE_SHARE, pick end
    end
    if not best then return nil end
    local minutes = CAST_SECS / 60 / best
    return minutes, bestMap, ("fish them in %s%s (%s)"):format(mapName(bestMap), t and t.when and (" " .. t.when) or "",
        own and ("%d%% of your catches there"):format(math.floor(best * 100 + 0.5)) or "about 1 in 3 catches")
end

----------------------------------------------------------------------
-- Herbs and ore
----------------------------------------------------------------------
local ORE = { ["Copper Ore"] = { "Copper Vein", "Poor Copper Vein" }, ["Tin Ore"] = { "Tin Vein" }, ["Silver Ore"] = { "Silver Vein" },
    ["Iron Ore"] = { "Iron Deposit" }, ["Gold Ore"] = { "Gold Vein" }, ["Mithril Ore"] = { "Mithril Deposit" },
    ["Truesilver Ore"] = { "Truesilver Deposit" }, ["Thorium Ore"] = { "Small Thorium Vein", "Rich Thorium Vein" },
    ["Dark Iron Ore"] = { "Dark Iron Deposit" } }
local NODE_MIN = { herb = 0.5, ore = 0.7 }   -- minutes per herb / ore with walking between nodes

local function gatherCost(name)
    local nodes, kind = ORE[name], "ore"
    if not nodes then nodes, kind = { name }, "herb" end
    local GP = VoidProf.GatherPlan
    local req = GP and GP.REQ and GP.REQ[nodes[1]]
    local N = _G.VoidGPS and _G.VoidGPS.Nodes
    if not (req and N and N.Has and N:Has(nodes[1])) then return nil end
    local skill = skillOf(kind == "ore" and "Mining" or "Herbalism")
    if not skill or skill < req then return nil end
    local ok, zones = pcall(N.Zones, N, nodes)
    local z = ok and zones and zones[1]
    return NODE_MIN[kind], z and z.map, ("%s %s%s"):format(kind == "ore" and "mine" or "pick",
        nodes[1], z and (" in " .. (z.name or mapName(z.map))) or "")
end

----------------------------------------------------------------------
-- Mobs
----------------------------------------------------------------------
local function killSecs(gap)   -- your level minus the mob's
    if gap >= 10 then return 12 end
    if gap >= 5 then return 20 end
    return 30
end

-- Skinning: which beast levels give each leather (Classic; checked 2026-11-13 against the newest
-- WoW Forever skinning table, whose 10-level bands list each leather main-first: it matches), the skill a level needs
-- (1 to 10: 1, to 20: (level - 10) x 10, then level x 5), about 1.3 leather a skin.
local SKIN = { [2934] = { 1, 12 }, [2318] = { 10, 24 }, [2319] = { 20, 34 }, [4234] = { 30, 44 },
    [4304] = { 40, 54 }, [8170] = { 48, 60 } }
F.SKIN = SKIN
local function skinNeed(lvl)
    if lvl <= 10 then return 1 end
    if lvl <= 20 then return (lvl - 10) * 10 end
    return lvl * 5
end
local function skinCost(id)
    local band = SKIN[id]
    local skill = band and skillOf("Skinning")
    if not skill then return nil end
    local me = UnitLevel("player") or 1
    -- the lowest beast level in the band you can skin: the quickest kills (Sol review: the highest
    -- one was priced 75% slower for Rugged Leather at 60)
    -- (skill needed only grows with level: the band's lowest level is the one to check)
    local top = math.min(band[2], me + 1)
    if band[1] > top or skinNeed(band[1]) > skill then return nil end
    local hi = band[1]   -- the highest level of the band you can still skin, for the text
    for L = band[1], top do if skinNeed(L) <= skill then hi = L end end
    return (killSecs(me - band[1]) + 12) / 60 / 1.3, nil, ("skin level %d-%d beasts"):format(band[1], hi)
end

local function mobCost(id)
    local D = _G.VoidGPS and _G.VoidGPS.Drops
    local list = D and D.Get and D:Get(id)
    if not list then return nil end
    local lvl = UnitLevel("player") or 1
    local best, pick
    for _, m in ipairs(list) do
        local maxL, chance = m[4], m[5]
        if maxL <= lvl + 1 and chance > 0 then
            local minutes = (100 / chance) * (killSecs(lvl - maxL) + 8) / 60   -- + finding and looting
            -- few of them on the map: you wait for respawns (3 Dark Iron Shadowcasters beat a camp of
            -- dozens for Silk Cloth on drop chance alone)
            minutes = minutes * math.max(1, 12 / math.max(1, m[8] or 12))
            if not best or minutes < best then best, pick = minutes, m end
        end
    end
    if not pick then return nil end
    return best, pick[2], ("kill %s in %s (level %d-%d, %s%% drop)"):format(pick[1], mapName(pick[2]), pick[3], pick[4],
        tostring(pick[5])), pick[6], pick[7]
end

----------------------------------------------------------------------
-- The fastest way
----------------------------------------------------------------------
function F:Cost(id, name)
    local best
    local function try(how, minutes, map, text, x, y)
        if minutes and (not best or minutes < best.minutes) then
            best = { how = how, minutes = minutes, map = map, text = text, x = x, y = y }
        end
    end
    local fishing = skillOf("Fishing")
    if fishing then try("fish", fishCost(id, fishing)) end
    name = name or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
    if name then try("gather", gatherCost(name)) end
    try("kill", mobCost(id))
    try("skin", skinCost(id))
    if not best then return nil end
    local s = best.map and safety(best.map)
    if s == "enemy" or s == "contested" then
        best.text = best.text .. (s == "enemy" and ", enemy territory" or ", contested")
    end
    best.copper = best.minutes * self:GoldPerHour() / 60
    return best
end
