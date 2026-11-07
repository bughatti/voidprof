----------------------------------------------------------------------
-- SkillCap.lua — WoW Forever only: what lifts each profession's skill cap.
--
-- Classic skills stop at 75 / 150 / 225 until you learn the next rank. For
-- Cooking, Fishing and First Aid the 150 and 225 steps are a book from one
-- vendor and a quest from one NPC, far from any trainer, so the panel says
-- which, where, whether you're ready, and pins it (Route.lua). Other
-- professions: the trainer rank and its skill/level rule.
--
-- Facts checked 2026-11-07 against Blizzard's static-forever-us item/quest data
-- (book prices and requirements, quest IDs) and NPC spots in NorgannonDB.
-- Map IDs are Forever's UI maps; coordinates 0-100.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end

local _, ns = ...
VoidProf = VoidProf or {}
local S = {}
VoidProf.SkillCap = S

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local ORG = { map = 1454, zone = "Orgrimmar" }
local SW  = { map = 1453, zone = "Stormwind City" }
local function at(base, x, y, name) return { map = base.map, zone = base.zone, x = x, y = y, name = name } end

-- [skillLine][current cap] = the step that raises it
local STEPS = {
    [185] = {   -- Cooking
        [75]  = { train = "Journeyman Cooking", minSkill = 50, trainerWord = "cooking trainer",
                  where = { Horde = at(ORG, 57.4, 53.96, "Zamja"), Alliance = at(SW, 78.17, 53.1, "Stephen Ryback") } },
        [150] = { item = 16072, itemName = "Expert Cookbook", cost = "1g", minSkill = 125,
                  where = { Horde    = { map = 1443, x = 26.17, y = 69.65, name = "Wulan", zone = "Shadowprey Village, Desolace" },
                            Alliance = { map = 1440, x = 49.48, y = 67.09, name = "Shandrina", zone = "Ashenvale" } } },
        [225] = { questName = "Clamlette Surprise", minSkill = 225, minLevel = 35,
                  note = "Your cooking trainer in the capital sends you there.",
                  where = { any = { map = 1446, x = 52.63, y = 28.11, name = "Dirge Quikcleave", zone = "Gadgetzan, Tanaris" } } },
    },
    [356] = {   -- Fishing
        [75]  = { train = "Journeyman Fishing", minSkill = 50, trainerWord = "fishing trainer",
                  where = { Horde = at(ORG, 69.8, 29.21, "Lumak"), Alliance = at(SW, 54.99, 69.65, "Arnold Leland") } },
        [150] = { item = 16083, itemName = "Expert Fishing - The Bass and You", cost = "1g", minSkill = 125, minLevel = 20,
                  note = "From Kalimdor, the boat at Ratchet (The Barrens) goes straight to Booty Bay.",
                  where = { any = { map = 1434, x = 27.42, y = 77.16, name = "Old Man Heming", zone = "Booty Bay, Stranglethorn Vale" } } },
        [225] = { questName = "Nat Pagle, Angler Extreme", minSkill = 225, minLevel = 35,
                  where = { any = { map = 1445, x = 58.61, y = 60.06, name = "Nat Pagle", zone = "Dustwallow Marsh" } } },
    },
    [129] = {   -- First Aid
        [75]  = { train = "Journeyman First Aid", minSkill = 50, trainerWord = "first aid trainer",
                  where = { Horde = at(ORG, 34.18, 84.58, "Arnok"), Alliance = at(SW, 53, 44.68, "Shaina Fuller") } },
        [150] = { item = 16084, itemName = "Expert First Aid - Under Wraps", cost = "1g", minSkill = 125,
                  where = { Horde    = { map = 1445, x = 36.49, y = 30.36, name = "Balai Lok'Wein", zone = "Brackenwall Village, Dustwallow Marsh" },
                            Alliance = { map = 1417, x = 26.97, y = 58.83, name = "Deneb Walker", zone = "Stromgarde, Arathi Highlands" } } },
        [225] = { questName = "Triage", minSkill = 225, minLevel = 35,
                  where = { Horde    = { map = 1417, x = 73.41, y = 36.89, name = "Doctor Gregory Victor", zone = "Hammerfall, Arathi Highlands" },
                            Alliance = { map = 1445, x = 67.76, y = 48.97, name = "Doctor Gustaf VanHowzen", zone = "Theramore, Dustwallow Marsh" } } },
    },
}

-- Every other profession: the trainer rank (skill 50 / 125 / 200). Level rules differ
-- per profession on Forever (gathering has none), so none are claimed here: the
-- trainer's window shows them.
local RANKS = {
    [75]  = { rank = "Journeyman", minSkill = 50 },
    [150] = { rank = "Expert",     minSkill = 125 },
    [225] = { rank = "Artisan",    minSkill = 200 },
}

-- The player's professions: { name, rank, max, line } by name.
function S:Professions()
    local out = {}
    if not (GetProfessions and GetProfessionInfo) then return out end
    local raw = { GetProfessions() }
    for i = 1, 6 do
        local idx = raw[i]
        if idx then
            local name, _, rank, max, _, _, line = GetProfessionInfo(idx)
            if name then out[name] = { name = name, rank = rank or 0, max = max or 0, line = line } end
        end
    end
    return out
end

-- The step that raises this profession's cap, or nil (top rank).
function S:Step(p)
    if not p or not p.max then return nil end
    local s = STEPS[p.line] and STEPS[p.line][p.max]
    if s then return s end
    local r = RANKS[p.max]
    if not r then return nil end
    return { train = r.rank .. " " .. p.name, minSkill = r.minSkill, minLevel = r.minLevel,
             trainerWord = p.name:lower() .. " trainer", generic = r.rank == "Artisan" }
end

function S:Where(step)
    local w = step and step.where
    if not w then return nil end
    return w.any or w[UnitFactionGroup("player") or ""]
end

-- What to do, as wrapped panel text, and whether the button can pin it.
function S:Describe(p)
    local step = self:Step(p)
    if not step then
        return ("Skill %d / %d. This is the top rank."):format(p.rank, p.max)
    end
    local level = UnitLevel("player") or 0
    local where = self:Where(step)
    local lines = {}
    local capped = p.rank >= p.max
    lines[#lines + 1] = capped
        and ("|cffff8800Capped at %d.|r To go past %d:"):format(p.max, p.max)
        or ("Skill %d / %d. To go past %d:"):format(p.rank, p.max, p.max)

    if step.item then
        lines[#lines + 1] = ("Buy |cffffffff%s|r (%s) from |cffffd200%s|r, %s, then right-click it to learn."):format(
            step.itemName, step.cost, where and where.name or "?", where and where.zone or "?")
    elseif step.questName then
        lines[#lines + 1] = ("Do the quest |cffffffff%s|r from |cffffd200%s|r, %s."):format(
            step.questName, where and where.name or "?", where and where.zone or "?")
    elseif where then
        lines[#lines + 1] = ("Train |cffffffff%s|r at any %s (closest in your capital: |cffffd200%s|r, %s)."):format(
            step.train, step.trainerWord, where.name, where.zone)
    else
        lines[#lines + 1] = ("Train |cffffffff%s|r at %s."):format(step.train,
            step.generic and ("an Artisan " .. step.trainerWord) or ("any " .. step.trainerWord))
    end
    if step.note then lines[#lines + 1] = "|cff888888" .. step.note .. "|r" end

    -- Ready?
    local need = {}
    if p.rank < (step.minSkill or 0) then need[#need + 1] = ("%s %d (you have %d)"):format(p.name, step.minSkill, p.rank) end
    if level < (step.minLevel or 0) then need[#need + 1] = ("level %d (you are %d)"):format(step.minLevel, level) end
    local inBags = step.item and (GetItemCount(step.item) or 0) > 0
    if #need > 0 then
        lines[#lines + 1] = "|cffff5050Needs " .. table.concat(need, " and ") .. ".|r"
            .. (inBags and " |cff888888(You already have the book.)|r" or "")
    elseif inBags then
        lines[#lines + 1] = "|cff00ff00It's in your bags: right-click it to learn.|r"
    else
        lines[#lines + 1] = "|cff00ff00You can do this now.|r"
    end
    return table.concat(lines, "\n"), where
end

function S:Go(where)
    if not (where and ns.Route) then return end
    local ok, why = ns.Route:Go({ map = where.map, x = where.x / 100, y = where.y / 100,
                                  name = where.name, zone = where.zone },
        { say = function(msg)
            VoidProf:Print(msg)
            UIErrorsFrame:AddMessage("VoidProf: " .. msg, 0.3, 1, 0.3)
        end })
    if not ok then VoidProf:Warn("Can't set a waypoint there (" .. tostring(why) .. ").") end
end

----------------------------------------------------------------------
-- Panel block (built by UI.lua inside each profession tab)
----------------------------------------------------------------------
function S:Build(parent, profName, topY, makeButton)
    local P = VoidUI.palette
    local head = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(head, 11, "OUTLINE")
    head:SetPoint("TOPLEFT", 14, topY)
    head:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    head:SetText("Next skill cap")

    local text = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(text, 11, "")
    text:SetPoint("TOPLEFT", 14, topY - 20)
    text:SetPoint("RIGHT", -14, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetSpacing(3)
    text:SetTextColor(0.85, 0.85, 0.88)

    local btn = makeButton(parent, 160, 26, "|cffffd200Show the way|r", function(b)
        S:Go(b._where)
    end)
    btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)

    parent._cap = { prof = profName, text = text, btn = btn }
    -- Herbalism / Mining / Fishing: the step-by-step plan under it (GatherPlan.lua)
    if VoidProf.GatherPlan and VoidProf.GatherPlan:Wants(profName) then
        VoidProf.GatherPlan:Build(parent, profName, text, makeButton)
    elseif VoidProf.VendorRecipes and VoidProf.VendorRecipes:Wants(profName) then
        -- crafting professions: recipes vendors sell that you don't know (VendorRecipes.lua)
        VoidProf.VendorRecipes:Build(parent, profName, text, makeButton)
    end
end

function S:Refresh(parent)
    local c = parent and parent._cap
    if not c then return end
    if VoidProf.GatherPlan then VoidProf.GatherPlan:Refresh(parent) end   -- (it clears itself too)
    if VoidProf.VendorRecipes then VoidProf.VendorRecipes:Refresh(parent) end
    local p = self:Professions()[c.prof]
    if not p then c.text:SetText(""); c.btn:Hide(); return end
    local desc, where = self:Describe(p)
    c.text:SetText(desc)
    c.btn._where = where
    c.btn:SetShown(where ~= nil)
end

----------------------------------------------------------------------
-- One chat line when a profession hits its cap (once per character and cap)
----------------------------------------------------------------------
local function notice()
    VoidProfCharDB = VoidProfCharDB or {}
    VoidProfCharDB.capNoted = VoidProfCharDB.capNoted or {}
    local noted = VoidProfCharDB.capNoted
    for _, p in pairs(S:Professions()) do
        local step = S:Step(p)
        local key = tostring(p.line or p.name) .. ":" .. p.max
        if step and p.max > 0 and p.rank >= p.max and not noted[key] then
            noted[key] = true
            local where = S:Where(step)
            local what = step.itemName or step.questName or step.train
            VoidProf:Print(("%s is capped at %d. Next: |cffffffff%s|r%s. Open VoidProf from the minimap button for the way there."):format(
                p.name, p.max, what, where and (" (" .. where.name .. ", " .. where.zone .. ")") or ""))
        end
    end
    if VoidProf.UI and VoidProf.UI.RefreshCaps then VoidProf.UI:RefreshCaps() end
end

local pending
local function later()
    if pending then return end
    pending = true
    C_Timer.After(2, function() pending = nil; notice() end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then C_Timer.After(6, later) else later() end
end)
