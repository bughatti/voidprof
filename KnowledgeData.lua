----------------------------------------------------------------------
-- VoidProf Knowledge data (Midnight, 12.1). Items, trainer quests, Darkmoon Faire
-- quests, currencies and skill lines checked against public game data (2026-11-01).
-- The hidden tracking quests (treasures, weekly drops, treatise, first gathers)
-- have no public page; they come from public profession data and are confirmed in game
-- as each flag flips. See Knowledge.lua for how each field is read.
--
-- VoidProf.KPData[profName] = {
--   skillLine = <expansion skill line>, currency = <knowledge currency>,
--   advice    = { default = "...", DRUID = "..." },
--   weekly    = { kp = 3, quests = { ... } },            -- trainer quests (one rotates in)
--   drops     = { { name, item, kp, quests = {...} } },  -- weekly gathering drops
--   catchUp   = { name, item },                          -- uncapped catch-up drop
--   treatise  = { item, kp, quest },
--   dmf       = { name, kp, quest },
--   firstGather = { ranges = { {first, last}, ... }, quests = {...}, total = n },
--   books     = { { item, quest, kp, name, where = {name,zone,map,x,y} | vendor = "text",
--                   req = { faction, renown, skill, cost = { [currencyID] = n } } } },  -- one-time vendor books
--   treasures = { { name, item, quest, zone, map = uiMapID, x, y } },  -- 3 KP each
-- }
----------------------------------------------------------------------
VoidProf = VoidProf or {}

-- Darkmoon Island takes no waypoints; the click falls back to this faction's portal
-- (the faire runs for a week from the first Sunday of each month).
local DMF_PORTAL = {
    -- Each faction has two ways in; the closest one to you is used (Knowledge.lua). From
    -- another continent Route.lua sends you through the portal to Orgrimmar/Stormwind first.
    Horde    = { { name = "Darkmoon Faire Mystic Mage", zone = "Orgrimmar",     map = 85, x = 48.0, y = 62.0 },
                 { name = "Darkmoon Faire portal",      zone = "Mulgore",       map = 7,  x = 36.0, y = 35.5 } },
    Alliance = { { name = "Darkmoon Faire Mystic Mage", zone = "Stormwind City", map = 84, x = 62.0, y = 73.0 },
                 { name = "Darkmoon Faire portal",      zone = "Elwynn Forest", map = 37, x = 41.8, y = 69.6 } },
}

VoidProf.KPData = {
    Herbalism = {
        skillLine = 2912, currency = 3154,
        advice = {
            -- Community guides (2026-11-01): non-Druids Botany 40 = gather while
            -- mounted; then the Bountiful Harvests root to 40 (+1 min and max herbs per
            -- node AND skill for every herb); then each herb's 20-point Finesse bonus,
            -- most expensive herb first; then the Botany root (Finesse), 5 points into one
            -- Overloading sub-spec (Lightfused / Voidbound double motes); Mulching late.
            default = function(r, skill)
                local botany, bounty = r["Botany"] or 0, r["Bountiful Harvests"] or 0
                if botany < 40 then
                    return ("Botany %d/40: at 40 you gather while mounted."):format(botany)
                elseif bounty == 0 and skill and skill < 50 then
                    -- the second tree opens at skill 50 (user, 2026-11-01)
                    return ("Bountiful Harvests is next (more herbs from every node, plus skill), but it opens at Herbalism 50 (you're %d). Keep your points until then: they don't expire. VoidGather's Go button finds the fastest skill-ups."):format(skill)
                elseif bounty < 40 then
                    return ("Bountiful Harvests root %d/40: +1 herb per node and skill for every herb (more rank-2). No sub-nodes until it's 40."):format(bounty)
                end
                return "Bountiful Harvests' herb nodes next: 20 points each (Finesse = extra herbs from that herb), most expensive herb first -- hover your herbs to compare. Then the Botany root, then 5 points into Overloading's Lightfused or Voidbound."
            end,
            DRUID = "Bountiful Harvests root to 40 first (you already gather in Travel Form), then its herb nodes, most expensive herb first.",
        },
        weekly = { kp = 3, quests = { 93700, 93701, 93702, 93703, 93704 }, npc = "Botanist Nathera",
                   where = { name = "Botanist Nathera (Herbalism trainer)", zone = "Silvermoon City", map = 2393, x = 48.2, y = 51.6 } },
        drops = {
            { name = "Thalassian Phoenix Plume", item = 238465, kp = 1, quests = { 81425, 81426, 81427, 81428, 81429 } },
            { name = "Thalassian Phoenix Tail",  item = 238466, kp = 4, quests = { 81430 } },
        },
        catchUp = { name = "Thalassian Phoenix Ember", item = 238467 },
        treatise = { name = "Thalassian Treatise on Herbalism", item = 245761, kp = 1, quest = 95130 },
        dmf = { name = "Herbs for Healing", kp = 3, quest = 29514,
                where = { name = "Chronos (Darkmoon Faire)", zone = "Darkmoon Island", map = 407, x = 55.0, y = 70.6,
                         portal = DMF_PORTAL } },
        firstGather = { ranges = { { 87729, 87758 } }, quests = { 97229, 97230, 97231, 97232, 97233 }, total = 35 },
        books = {
            { item = 258410, quest = 93411, kp = 10, name = "Traditions of the Haranir: Herbalism",
              where = { name = "Naynar", zone = "Harandar (The Den)", map = 2413, x = 51.0, y = 50.8 },
              req = { faction = 2704, renown = 6, cost = { [3260] = 75, [3316] = 750 } } },
            { item = 250443, quest = 92174, kp = 10, name = "Echo of Abundance: Herbalism",
              vendor = "Chel the Chip, Zul'Aman",   -- no confirmed spot yet
              req = { cost = { [3377] = 1600, [3260] = 75 } } },
            { item = 274513, quest = 96514, kp = 10, name = "Demystifyin': Herbalism",
              where = { name = "Jan'sari the Watchful", zone = "The Coiled Isle", map = 2512, x = 58.77, y = 45.94 },
              req = { faction = 2772, renown = 6, skill = 25, cost = { [3260] = 75, [3316] = 750 } } },
        },
        treasures = {
            { name = "Simple Leaf Pruners",          item = 238470, quest = 89160, zone = "Silvermoon City", map = 2393, x = 49.01, y = 75.92 },
            { name = "A Spade",                      item = 238472, quest = 89158, zone = "Eversong Woods",  map = 2395, x = 64.24, y = 30.46 },
            { name = "Sweeping Harvester's Scythe",  item = 238469, quest = 89161, zone = "Zul'Aman",        map = 2437, x = 41.91, y = 45.92 },
            { name = "Peculiar Lotus",               item = 238474, quest = 89156, zone = "Voidstorm",       map = 2405, x = 34.68, y = 56.96 },
            { name = "Planting Shovel",              item = 238475, quest = 89155, zone = "Harandar",        map = 2413, x = 51.13, y = 55.70 },
            { name = "Bloomed Bud",                  item = 238468, quest = 89162, zone = "Harandar",        map = 2413, x = 38.32, y = 67.06 },
            { name = "Lightbloom Root",              item = 238471, quest = 89159, zone = "Harandar",        map = 2413, x = 36.65, y = 25.07 },
            { name = "Harvester's Sickle",           item = 238473, quest = 89157, zone = "Harandar",        map = 2413, x = 76.12, y = 51.05 },
        },
    },
    Mining = {
        skillLine = 2916, currency = 3158,
        advice = {
            -- Community guides (2026-11-01): Meticulous Mining 40 =
            -- mine while mounted; then the Plentiful Ores root to 50 (skill for every ore =
            -- more rank-2 ore), then its ore nodes spread evenly (max one first only if it
            -- sells far higher; a maxed ore node also raises Dazzling Thorium drops); then
            -- 5 points into one Over-LODED sub-spec (Lightfused / Voidbound double motes).
            default = function(r, skill)
                local met, plen = r["Meticulous Mining"] or 0, r["Plentiful Ores"] or 0
                if met < 40 then
                    return ("Meticulous Mining %d/40: at 40 you mine while mounted."):format(met)
                elseif plen == 0 and skill and skill < 50 then
                    -- the second tree opens at skill 50 (user, 2026-11-01)
                    return ("Plentiful Ores is next (skill for every ore = more rank-2 ore), but it opens at Mining 50 (you're %d). Keep your points until then: they don't expire. VoidGather's Go button finds the fastest skill-ups."):format(skill)
                elseif plen < 50 then
                    return ("Plentiful Ores root %d/50: skill for every Midnight ore, so more rank-2 ore (worth about 5x rank 1). No sub-nodes until it's 50."):format(plen)
                end
                return "Plentiful Ores' ore nodes next (Refulgent Copper, Umbral Tin, Brilliant Silver): spread evenly unless one ore sells far higher. Then 5 points into Over-LODED's Lightfused or Voidbound."
            end,
        },
        weekly = { kp = 3, quests = { 93705, 93706, 93707, 93708, 93709 }, npc = "Belil",
                   where = { name = "Belil (Mining trainer)", zone = "Silvermoon City", map = 2393, x = 42.6, y = 52.8 } },
        drops = {
            { name = "Igneous Rock Specimen", item = 237496, kp = 1, quests = { 88673, 88674, 88675, 88676, 88677 } },
            { name = "Septarian Nodule",      item = 237506, kp = 3, quests = { 88678 } },
        },
        catchUp = { name = "Cloudy Quartz", item = 237507 },
        treatise = { name = "Thalassian Treatise on Mining", item = 245762, kp = 1, quest = 95135 },
        dmf = { name = "Rearm, Reuse, Recycle", kp = 3, quest = 29518,
                where = { name = "Rinling (Darkmoon Faire)", zone = "Darkmoon Island", map = 407, x = 49.6, y = 60.8,
                         portal = DMF_PORTAL } },
        -- 24 node types; the IDs in the range aren't all used (unused ones never flip).
        firstGather = { ranges = { { 88463, 88491 } }, quests = { 97226, 97227, 97228 }, total = 24 },
        books = {
            { item = 250924, quest = 92372, kp = 10, name = "Whisper of the Loa: Mining",
              where = { name = "Magovu", zone = "Zul'Aman (Amani'Zar Village)", map = 2437, x = 45.94, y = 65.91 },
              req = { faction = 2696, renown = 6, cost = { [3264] = 75, [3316] = 750 } } },
            { item = 250444, quest = 92187, kp = 10, name = "Echo of Abundance: Mining",
              vendor = "Chel the Chip, Zul'Aman",   -- no confirmed spot yet
              req = { cost = { [3377] = 1600, [3264] = 75 } } },
            { item = 274509, quest = 96518, kp = 10, name = "Demystifyin': Mining",
              where = { name = "Jan'sari the Watchful", zone = "The Coiled Isle", map = 2512, x = 58.77, y = 45.94 },
              req = { faction = 2772, renown = 6, skill = 25, cost = { [3264] = 75, [3316] = 750 } } },
        },
        treasures = {
            { name = "Solid Ore Punchers",          item = 238599, quest = 89147, zone = "Eversong Woods", map = 2395, x = 37.98, y = 45.37 },
            { name = "Spelunker's Lucky Charm",     item = 238597, quest = 89145, zone = "Zul'Aman",       map = 2437, x = 41.99, y = 46.52 },
            { name = "Amani Expert's Chisel",       item = 238601, quest = 89149, zone = "Atal'Aman",      map = 2536, x = 33.32, y = 65.93 },
            { name = "Spare Expedition Torch",      item = 238603, quest = 89151, zone = "Harandar",       map = 2413, x = 38.84, y = 65.88 },
            -- Moved in 12.0.1 (player reports, Mar 17 2026, confirmed by looters): Slayer's
            -- Rise map 2444. The same numbers on the Voidstorm map (2405) were empty in game.
            { name = "Star Metal Deposit",          item = 238602, quest = 89150, zone = "Slayer's Rise",  map = 2444, x = 34.23, y = 76.05 },
            { name = "Miner's Guide to Voidstorm",  item = 238596, quest = 89144, zone = "Slayer's Rise",  map = 2444, x = 30.48, y = 69.07 },
            { name = "Glimmering Void Pearl",       item = 238600, quest = 89148, zone = "Slayer's Rise",  map = 2444, x = 28.74, y = 38.57 },
            { name = "Lost Voidstorm Satchel",      item = 238598, quest = 89146, zone = "Slayer's Rise",  map = 2444, x = 54.24, y = 51.57 },
        },
    },
}
