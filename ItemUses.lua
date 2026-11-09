----------------------------------------------------------------------
-- ItemUses.lua — WoW Forever only: what is this item for, for YOU.
--
-- Hover a reagent (a fish, meat, herb, ore, cloth, leather...) and its tooltip says which of
-- YOUR recipes use it, colored for your skill, and which recipe you could buy soon. The user,
-- 2026-11-09: "too much data can be overwhelming, the tooltip only needs to apply to that
-- player's professions and what makes sense, ... if I am 220 cooking, I don't need to see a
-- level 10 recipe". So:
--   - only professions you have;
--   - recipes you know only while they still give skill (orange / yellow / green, the color the
--     game showed the last time you opened that profession);
--   - a recipe you don't know only if a vendor sells it (VoidGPS) and you can learn it now or
--     within 25 skill: "learn at 225: X, Vendor (Zone)";
--   - at most 3 lines; nothing that fits = nothing added.
-- Recipes and reagents: ForeverRecipes.lua (Blizzard's own data, tools/cmd/forever-recipes).
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end

local _, ns = ...
VoidProf = VoidProf or {}
local U = {}
VoidProf.ItemUses = U

local SOON = 25            -- "coming up": learnable within this much skill
local STALE = 50           -- an unknown recipe learned more than this below your skill is outgrown
local MAX_NAMES = 3        -- recipe names per profession line
local MAX_LINES = 3
local HEX = { [0] = "ff8040", [1] = "ffff00", [2] = "40c040" }   -- orange, yellow, green (grey: not shown)

local function readable(v)
    if canaccessvalue then return canaccessvalue(v) end
    return not (issecretvalue and issecretvalue(v))
end

-- reagent item -> { recipe row, ... }; row = { prof, name, crafted, learn, recipeItem, category, reagent, n, ... }
local byReagent
local function index()
    if byReagent then return byReagent end
    byReagent = {}
    for _, r in ipairs(ns.ForeverRecipes or {}) do
        for k = 7, #r, 2 do
            local t = byReagent[r[k]]
            if not t then t = {}; byReagent[r[k]] = t end
            t[#t + 1] = r
        end
    end
    return byReagent
end

-- your professions by skill line: { name, rank }
local function myProfs()
    local out = {}
    local P = VoidProf.SkillCap and VoidProf.SkillCap:Professions() or {}
    for name, p in pairs(P) do
        if p.line then out[p.line] = { name = name, rank = p.rank or 0 } end
    end
    return out
end

-- recipe name -> the difficulty the game gave it (0 orange .. 3 grey), from VoidProf's sync
local function known(profName)
    local c = VoidProf.ProfCache and VoidProf:ProfCache()[profName]
    local out = {}
    for _, r in pairs(c and c.recipes or {}) do
        if r.name then out[r.name] = r.difficulty end
    end
    return out
end

local function zoneName(map)
    local i = map and C_Map.GetMapInfo(map)
    return i and i.name or nil
end

-- the lines for one item, or nil
function U:Lines(itemID)
    local rows = index()[itemID]
    if not rows then return nil end
    local profs = myProfs()
    local R = VoidGPS and VoidGPS.Recipes
    local make, soon, knownBy = {}, {}, {}
    for _, r in ipairs(rows) do
        local p = profs[r[1]]
        if p then
            knownBy[r[1]] = knownBy[r[1]] or known(p.name)
            local d = knownBy[r[1]][r[2]]
            if d ~= nil then
                if HEX[d] then
                    make[p.name] = make[p.name] or {}
                    table.insert(make[p.name], { name = r[2], d = d })
                end
            -- a recipe you don't know: only while it would still give you skill (learned no more than
            -- STALE below your skill) and you can learn it now or within SOON (Sol review: a skill-10
            -- recipe at Cooking 220 showed as "learn now")
            elseif r[5] ~= 0 and r[4] > 0 and r[4] <= p.rank + SOON and r[4] > p.rank - STALE and R then
                local e = R:Get(r[5])
                local v = e and e.vendors and e.vendors[1]
                if v then soon[#soon + 1] = { prof = p.name, name = r[2], learn = r[4], now = r[4] <= p.rank, v = v } end
            end
        end
    end
    local lines = {}
    local profNames = {}
    for name in pairs(make) do profNames[#profNames + 1] = name end
    table.sort(profNames)
    for _, prof in ipairs(profNames) do
        local list = make[prof]
        table.sort(list, function(a, b)
            if a.d ~= b.d then return a.d < b.d end
            return a.name < b.name
        end)
        local t = {}
        for i = 1, math.min(MAX_NAMES, #list) do t[i] = "|cff" .. HEX[list[i].d] .. list[i].name .. "|r" end
        local more = #list > MAX_NAMES and (" |cff888888+%d|r"):format(#list - MAX_NAMES) or ""
        lines[#lines + 1] = ("|cff00c7ffVoidProf|r %s: %s%s"):format(prof, table.concat(t, ", "), more)
    end
    -- learnable now first (the highest, most skill, first), then coming up (the nearest first)
    table.sort(soon, function(a, b)
        if a.now ~= b.now then return a.now end
        if a.now then return a.learn > b.learn end
        return a.learn < b.learn
    end)
    for _, s in ipairs(soon) do
        if #lines >= MAX_LINES then break end
        local where = zoneName(s.v.map)
        local head = s.now and ("|cff33ff33learn now (%d):|r"):format(s.learn) or ("|cffaaaaaalearn at %d:|r"):format(s.learn)
        lines[#lines + 1] = ("|cff00c7ffVoidProf|r %s %s, %s%s"):format(head, s.name, s.v.name or "vendor",
            where and (" (" .. where .. ")") or "")
    end
    if #lines == 0 then return nil end
    while #lines > MAX_LINES do table.remove(lines) end
    return lines
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if (tt ~= GameTooltip and tt ~= ItemRefTooltip) or type(data) ~= "table" then return end
        local id = data.id
        if not (id and readable(id)) then return end
        local ok, lines = pcall(U.Lines, U, id)
        if not (ok and lines) then return end
        for _, l in ipairs(lines) do tt:AddLine(l) end
        tt:Show()
    end)
end
