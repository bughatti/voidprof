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

----------------------------------------------------------------------
-- The other professions (2026-11-03): treasures (items and spots from public
-- treasure guides), Darkmoon Faire quests and spending advice. A treasure
-- without `quest` shows "?" until VoidProf learns its tracking quest the first
-- time you loot it (Knowledge.lua, LearnTreasures). Enchanting's quests are
-- from player reports and follow item order, like Mining's.
----------------------------------------------------------------------
local KP = VoidProf.KPData
local SM, EW = "Silvermoon City", "Eversong Woods"
local function dmf(name, quest, npc, x, y)
    return { name = name, kp = 3, quest = quest,
             where = { name = npc .. " (Darkmoon Faire)", zone = "Darkmoon Island", map = 407, x = x, y = y, portal = DMF_PORTAL } }
end
local function T(name, item, map, zone, x, y, quest)
    return { name = name, item = item, quest = quest, zone = zone, map = map, x = x, y = y }
end
-- A tab's rank by part of its name, ignoring case and punctuation (guides spell
-- the tabs a little differently from the game).
local function R(r, key)
    key = key:lower():gsub("[^%a]", "")
    for name, v in pairs(r) do
        if (name:lower():gsub("[^%a]", "")):find(key, 1, true) then return v end
    end
    return 0
end

KP.Enchanting = {
    skillLine = 2909,
    advice = {
        -- Tabs (in game, 11-03): all four can be unlocked at skill 25. Delegate first:
        -- every disenchant gives more, which pays for leveling (dust is its biggest cost).
        default = function(r)
            local de, ee = r["Disenchanting Delegate"] or 0, r["Elevating Equipment"] or 0
            if de < 30 then
                return ("Disenchanting Delegate root %d/30: better results from every disenchant (dust, shards, Dawn Crystals), the materials you level with. Spend points before disenchanting a big pile."):format(de)
            elseif ee == 0 then
                return "Delegate's sub-spec for what you disenchant most: Crystal Collector (epic gear), Shard Supplier (blue) or Dust Deliverer (green). Then Elevating Equipment when you're close to 100 and want to sell enchants."
            elseif ee < 30 then
                return ("Elevating Equipment root %d/30: better quality permanent enchants, the ones that sell. Then one enchant style (ring enchants sell best)."):format(ee)
            end
            return "Elevating's ring style next, then Spellbound Shatterer (Resourcefulness and Multicraft for every recipe)."
        end,
    },
    dmf = dmf("Putting Trash to Good Use", 29510, "Sayge", 53.3, 75.8),
    treasures = {
        T("Enchanted Amani Mask",     238548, 2536, "Atal'Aman", 49.1, 22.7, 89100),
        T("Enchanted Sunfire Silk",   238549, 2395, EW, 40.20, 61.23, 89101),
        T("Pure Void Crystal",        238550, 2405, "Voidstorm", 35.5, 58.8, 89102),
        T("Everblazing Sunmote",      238551, 2395, EW, 60.8, 53.1, 89103),
        T("Entropic Shard",           238552, 2413, "Harandar", 37.7, 65.3, 89104),
        T("Primal Essence Orb",       238553, 2413, "Harandar", 65.8, 50.2, 89105),
        T("Loa-Blessed Dust",         238554, 2437, "Zul'Aman", 40.4, 51.2, 89106),
        T("Sin'dorei Enchanting Rod", 238555, 2395, EW, 63.4, 32.6, 89107),
    },
}

KP.Alchemy = {
    skillLine = 2906,
    advice = {
        -- Guides (11-03): leveling cheaply = Transmutation Authority (the Wondrous
        -- Synergist cooldown); for gold, one product line, never split.
        default = function(r)
            local tr, am = R(r, "transmutation"), R(r, "alchemical mastery")
            if tr == 0 then
                return "Transmutation Authority first: 5 in the root, then 20 in Synthesis Synergy (Wondrous Synergist, its cooldown drops from about 18 to 9 hours): cheap materials while you level."
            elseif am == 0 then
                return "Metamorphic Mastery next (Multicraft on transmutes), then Alchemical Mastery 10 (skill for every Alchemy recipe) when it opens."
            end
            return "For gold, pick one line and finish it: Fluent in Flasks (Sin'dorei Specialist, then Flask Abundance) or Potion Prowess (a Path, then Prolific Potioneer). Then Alchemical Mastery's Reuse or Recycle (Resourcefulness)."
        end,
    },
    dmf = dmf("A Fizzy Fusion", 29506, "Sylannia", 50.5, 69.5),
    treasures = {
        T("Vial of Eversong Oddities",  238532, 2395, SM, 45.12, 44.77),
        T("Vial of Voidstorm Oddities", 238533, 2444, "Slayer's Rise", 41.8, 40.5),
        T("Vial of Harandar Oddities",  238534, 2413, "Harandar", 34.7, 24.7),
        T("Vial of Zul'Aman Oddities",  238535, 2437, "Zul'Aman", 40.4, 51.0),
        T("Freshly Plucked Peacebloom", 238536, 2395, SM, 49.1, 75.6),
        T("Measured Ladle",             238537, 2536, "Atal'Aman", 49.1, 23.1),
        T("Pristine Potion",            238538, 2395, SM, 47.8, 51.6),
        T("Failed Experiment",          238539, 2405, "Voidstorm", 32.8, 43.3),
    },
}

KP.Blacksmithing = {
    skillLine = 2907,
    advice = {
        default = function(r)
            local ow = R(r, "old ways")
            if ow < 40 then
                return ("The Old Ways root %d/40: crafting stats for every recipe, the best start for leveling and for selling."):format(ow)
            end
            return "Prolific Worker (Multicraft) or Resourceful Smith next. Making gear for orders? Armorsmithing or Weaponsmithing root to 30, then one branch."
        end,
    },
    dmf = dmf("Baby Needs Two Pair of Shoes", 29508, "Yebb Neblegear", 51.0, 82.0),
    treasures = {
        T("Deconstructed Forge Techniques", 238540, 2395, SM, 26.9, 60.3),
        T("Silvermoon Smithing Kit",        238541, 2395, SM, 48.3, 75.7),
        T("Carefully Racked Spear",         238542, 2536, "Atal'Aman", 33.2, 65.8),
        T("Metalworking Cheat Sheet",       238543, 2395, EW, 56.8, 40.7),
        T("Voidstorm Defense Spear",        238544, 2444, "Slayer's Rise", 30.6, 68.9),
        T("Rutaani Floratender's Sword",    238545, 2413, "Harandar", 66.3, 50.8),
        T("Sin'dorei Master's Forgemace",   238546, 2395, SM, 49.3, 61.3),
        T("Silvermoon Blacksmith's Hammer", 238547, 2395, SM, 48.5, 74.8),
    },
}

KP.Engineering = {
    skillLine = 2910,
    advice = {
        default = function(r)
            local rc = R(r, "recycling")
            if rc < 30 then
                return ("Recycling root %d/30: more back from recycling and a big skill bonus to every Engineering recipe, the cheap way to level."):format(rc)
            end
            return "Recycling's Resourcefulness next, then Bits and Bots (30 into Bits for top-quality Soul Sprockets). Making profession tools: Market Mobility."
        end,
    },
    dmf = dmf("Talkin' Tonks", 29511, "Rinling", 49.6, 60.8),
    treasures = {
        T("One Engineer's Junk",            238556, 2395, SM, 51.4, 74.6),
        T("Miniaturized Transport Skiff",   238557, 2444, "Slayer's Rise", 29.0, 39.2),
        T("Manual of Mistakes and Mishaps", 238558, 2395, EW, 39.5, 45.8),
        T("Expeditious Pylon",              238559, 2413, "Harandar", 67.9, 49.8),
        T("Ethereal Stormwrench",           238560, 2444, "Slayer's Rise", 54.0, 51.0),
        T("Offline Helper Bot",             238561, 2536, "Atal'Aman", 65.1, 34.5),
        T("What To Do When Nothing Works",  238562, 2395, SM, 51.2, 57.1),
        T("Handy Wrench",                   238563, 2437, "Zul'Aman", 34.2, 87.9),
    },
}

KP.Inscription = {
    skillLine = 2913,
    advice = {
        -- Both guides: Calm Hands first, cheap (10) and the treatise bonus.
        default = function(r)
            local ch, pp = R(r, "calm hands"), R(r, "perfected products")
            if ch < 10 then
                return ("Calm Hands root %d/10: cheap, and your weekly Treatise gives 2 knowledge instead of 1. Then Keen Eye (Resourcefulness: less ink and pigment) or Dextrous Diligence (Multicraft)."):format(ch)
            elseif pp == 0 then
                return "Keen Eye and Dextrous Diligence next, then Perfected Products for top-quality pigments and inks (Perfect Milling first)."
            elseif pp < 30 then
                return ("Perfected Products root %d/30, then Processing: Perfect Milling, Perfect Inks."):format(pp)
            end
            return "Perfected Products' Parchment side (missives, contracts, vantus runes) or Darkmoon Curiosity (cards and trinkets) for gold. Blueprints if you make your own staves and tools."
        end,
    },
    dmf = dmf("Writing the Future", 29515, "Sayge", 53.3, 75.8),
    treasures = {
        T("Void-Touched Quill",           238572, 2444, "Slayer's Rise", 60.7, 84.1),
        T("Leather-Bound Techniques",     238573, 2437, "Zul'Aman", 40.5, 49.4),
        T("Spare Ink",                    238574, 2395, SM, 48.3, 75.6),
        T("Intrepid Explorer's Marker",   238575, 2413, "Harandar", 52.4, 52.6),
        T("Leftover Sanguithorn Pigment", 238576, 2413, "Harandar", 52.7, 50.0),
        T("Half-Baked Techniques",        238577, 2395, EW, 39.3, 45.4),
        T("Songwriter's Pen",             238578, 2395, SM, 47.7, 50.3),
        T("Songwriter's Quill",           238579, 2395, EW, 40.4, 61.3),
    },
}

KP.Jewelcrafting = {
    skillLine = 2914,
    advice = {
        default = function(r)
            local tt, gg = R(r, "thoughtful throughput"), R(r, "glamorous gems")
            if tt < 10 then
                return ("Thoughtful Throughput root %d/10 (crafting stats for every recipe), then Skilled Savings (Resourcefulness, the cheap way to level) or Outrageous Output (Multicraft, for selling)."):format(tt)
            elseif gg == 0 then
                return "Finish Skilled Savings or Outrageous Output, then Glamorous Gems (root 30 opens all four colors; 25 in a color opens its gems) or Alluring Accessories for rings and necklaces."
            end
            return "Your gem color's nodes next, most-sold gem first. Lots of ore? Proficient Processor's Prospecting Pro."
        end,
    },
    dmf = dmf("Keeping the Faire Sparkling", 29516, "Chronos", 55.0, 70.6),
    treasures = {
        T("Sin'dorei Masterwork Chisel",   238580, 2395, SM, 50.6, 56.5),
        T("Speculative Voidstorm Crystal", 238581, 2444, "Slayer's Rise", 30.6, 69.0),
        T("Dual-Function Magnifiers",      238582, 2395, SM, 28.61, 46.47),
        T("Poorly Rounded Vial",           238583, 2395, EW, 56.7, 40.9),
        T("Shattered Glass",               238584, 2444, "Slayer's Rise", 62.9, 53.5),
        T("Vintage Soul Gem",              238585, 2395, SM, 55.5, 48.0),
        T("Ethereal Gem Pliers",           238586, 2444, "Slayer's Rise", 54.2, 51.2),
        T("Sin'dorei Gem Faceters",        238587, 2395, EW, 39.7, 38.8),
    },
}

KP.Leatherworking = {
    skillLine = 2915,
    advice = {
        default = function(r)
            local ll, ff = R(r, "learned leatherworker"), R(r, "flawless fortes")
            if ll < 10 then
                return ("Learned Leatherworker root %d/10, then Waning Waste (saves materials while you level)."):format(ll)
            elseif ff == 0 then
                return "Flawless Fortes next: root 10, then Commanding Commodities and Crucial Consumables (armor kits sell steadily). Making gear for orders instead? Lasting Leather or Safeguarding Scales root to 30."
            end
            return "Crucial Consumables, then Mastering Multicraft (Learned Leatherworker) for more kits per craft."
        end,
    },
    dmf = dmf("Eyes on the Prizes", 29517, "Chronos", 55.0, 70.6),
    treasures = {
        T("Amani Leatherworker's Tool",     238588, 2437, "Zul'Aman", 33.1, 78.9),
        T("Ethereal Leatherworking Knife",  238589, 2405, "Voidstorm", 34.8, 56.9),
        T("Prestigiously Racked Hide",      238590, 2437, "Zul'Aman", 30.8, 84.1),
        T("Bundle of Tanner's Trinkets",    238591, 2536, "Atal'Aman", 45.2, 45.3),
        T("Patterns: Beyond the Void",      238592, 2444, "Slayer's Rise", 53.8, 51.6),
        T("Haranir Leatherworking Mallet",  238593, 2413, "Harandar", 51.8, 51.3),
        T("Haranir Leatherworking Knife",   238594, 2413, "Harandar", 36.1, 25.2),
        T("Artisan's Considered Order",     238595, 2395, SM, 44.8, 56.2),
    },
}

KP.Tailoring = {
    skillLine = 2918,
    advice = {
        default = function(r)
            local nn = R(r, "nimble needlework")
            if nn < 20 then
                return ("Nimble Needlework root %d/20: both daily bolt cooldowns and rare cloth drops from mobs. Then 15 into Arcanoweaving or Sunfire Silk Weaving."):format(nn)
            end
            return "Your bolt side's Expertise (20 halves the bolt cooldown), then Fiber Arts: Creative Efficiency (Multicraft), Textile Utilization (Resourcefulness). Farming cloth? Fabric Specialist."
        end,
    },
    dmf = dmf("Banners, Banners Everywhere!", 29520, "Selina Dourman", 55.6, 55.0),
    treasures = {
        T("A Child's Stuffy",                    238612, 2413, "Harandar", 70.5, 50.8),
        T("A Really Nice Curtain",               238613, 2395, SM, 35.8, 61.2),
        T("Sin'dorei Outfitter's Ruler",         238614, 2395, EW, 46.3, 34.8),
        T("Wooden Weaving Sword",                238615, 2413, "Harandar", 69.8, 51.0),
        T("Book of Sin'dorei Stitches",          238616, 2444, "Slayer's Rise", 61.9, 83.7),
        T("Satin Throw Pillow",                  238617, 2444, "Slayer's Rise", 61.4, 85.0),
        T("Particularly Enchanting Tablecloth",  238618, 2395, SM, 31.7, 68.2),
        T("Artisan's Cover Comb",                238619, 2437, "Zul'Aman", 40.4, 49.4),
    },
}

KP.Skinning = {
    advice = {
        default = function(r, skill)
            local tt = R(r, "thorough tanning")
            if tt < 10 then
                return ("Thorough Tanning root %d/10 (more hide and scales, Sharpen Your Knife), then Lasting Leather or Superb Scales to 40: whichever sells more on your AH."):format(tt)
            elseif tt < 40 then
                return ("Your Lasting Leather or Superb Scales node to 40, then the Thorough Tanning root (%d/40) for a third knife charge."):format(tt)
            end
            return "Gainful Gathering next (Trophy Taker or Careful Carving), or Talented Tracker for Majestic materials from lures."
        end,
    },
    dmf = dmf("Tan My Hide", 29519, "Chronos", 55.0, 70.6),
    treasures = {
        T("Lightbloom-Afflicted Hide", 238628, 2413, "Harandar", 76.0, 51.0),
        -- shows only once a character of yours has finished the Zul'Aman campaign
        T("Cadre Skinning Knife",      238629, 2536, "Atal'Aman", 45.0, 44.7),
        T("Primal Hide",               238630, 2413, "Harandar", 69.5, 49.2),
        T("Voidstorm Leather Sample",  238631, 2444, "Slayer's Rise", 45.5, 42.4),
        T("Amani Tanning Oil",         238632, 2437, "Zul'Aman", 40.4, 36.0),
        T("Sin'dorei Tanning Oil",     238633, 2395, SM, 43.2, 55.7),
        T("Amani Skinning Knife",      238634, 2437, "Zul'Aman", 33.1, 79.0),
        T("Thalassian Skinning Knife", 238635, 2395, EW, 48.5, 76.2),
    },
}
