----------------------------------------------------------------------
-- VoidProf Knowledge — profession Knowledge Point (KP) advisor
--
-- Per profession tab: unspent KP, the spec tree's progress, what to put
-- the next points into, and a checklist of where KP comes from (weekly
-- and one-time), read from hidden tracking quests. Data lives in
-- KnowledgeData.lua (VoidProf.KPData).
--
-- The KP currency hangs off the expansion's own skill line ("Midnight
-- Herbalism"), which the game only reports while that profession's window
-- is open (C_ProfSpecs.GetDefaultSpecSkillLine). It's remembered per
-- character so the panel works with the window closed.
----------------------------------------------------------------------

local _, ns = ...   -- ns.Route: this addon's own waypoint router (Route.lua)
VoidProf = VoidProf or {}
VoidProf.Knowledge = {}
local K = VoidProf.Knowledge

local function charDB()
    VoidProfCharDB = VoidProfCharDB or {}
    VoidProfCharDB.specSkillLine = VoidProfCharDB.specSkillLine or {}
    return VoidProfCharDB
end

local function data(profName)
    return VoidProf.KPData and VoidProf.KPData[profName]
end

-- The expansion skill line for a profession: remembered from the profession
-- window, else the one in KnowledgeData.
function K:SkillLine(profName)
    return charDB().specSkillLine[profName] or (data(profName) and data(profName).skillLine)
end

local function rememberSkillLine()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_ProfSpecs) then return end
    local base = C_TradeSkillUI.GetBaseProfessionInfo()
    local line = C_ProfSpecs.GetDefaultSpecSkillLine and C_ProfSpecs.GetDefaultSpecSkillLine()
    if base and base.professionName and line and line > 0 then
        charDB().specSkillLine[base.professionName] = line
    end
end

-- Unspent knowledge points (nil when the game hasn't told us the skill line yet).
function K:Unspent(profName)
    local line = self:SkillLine(profName)
    if not (line and C_ProfSpecs and C_ProfSpecs.GetCurrencyInfoForSkillLine) then return nil end
    local ok, info = pcall(C_ProfSpecs.GetCurrencyInfoForSkillLine, line)
    if ok and info then return info.numAvailable, info.currencyName end
    return nil
end

-- Spec tree summary: { {name=, state=, rank=, max=}, ... } for each top-level tab.
function K:Tree(profName)
    local line = self:SkillLine(profName)
    if not (line and C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine) then return nil end
    local configID = C_ProfSpecs.GetConfigIDForSkillLine and C_ProfSpecs.GetConfigIDForSkillLine(line)
    if not configID or configID == 0 then return nil end
    local out = {}
    for _, tabID in ipairs(C_ProfSpecs.GetSpecTabIDsForSkillLine(line) or {}) do
        local tab = C_ProfSpecs.GetTabInfo(tabID)
        local state = C_ProfSpecs.GetStateForTab(tabID, configID)
        local root = C_ProfSpecs.GetRootPathForTab(tabID)
        local rank, max = 0, 0
        if root and C_Traits and C_Traits.GetNodeInfo then
            local node = C_Traits.GetNodeInfo(configID, root)
            if node then
                rank, max = node.currentRank or node.activeRank or 0, node.maxRanks or 0
                -- the path's first rank is its unlock, which the game's own window
                -- leaves out (ProfessionsSpecPathMixin:GetRanks): "0/31" was "0/30"
                local unlock = 0
                local entry = C_ProfSpecs.GetUnlockEntryForPath and C_ProfSpecs.GetUnlockEntryForPath(root)
                local einfo = entry and C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entry)
                if einfo and einfo.maxRanks then unlock = einfo.maxRanks end
                if rank > 0 then rank = math.max(0, rank - unlock) end
                max = math.max(0, max - unlock)
            end
        end
        out[#out + 1] = { name = tab and tab.name or ("Tab " .. tabID), state = state, rank = rank, max = max }
    end
    return out
end

local function done(questID)
    return questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end
K.Done = done

-- Weekly sources: { {label=, kp=, done=bool or nil (unknown)} }
function K:Weekly(profName)
    local d = data(profName)
    if not d then return {} end
    local out = {}
    -- Trainer quest: one of several rotates; done if any of them is.
    if d.weekly and #d.weekly.quests > 0 then
        local any = false
        for _, q in ipairs(d.weekly.quests) do if done(q) then any = true break end end
        out[#out + 1] = { label = "Trainer quest" .. (d.weekly.npc and (" (" .. d.weekly.npc .. ")") or ""),
                          kp = d.weekly.kp, done = any, where = d.weekly.where }
    end
    for _, drop in ipairs(d.drops or {}) do
        local n, have = #(drop.quests or {}), 0
        for _, q in ipairs(drop.quests or {}) do if done(q) then have = have + 1 end end
        out[#out + 1] = { label = drop.name, kp = drop.kp, done = n > 0 and have == n, progress = n > 1 and (have .. "/" .. n) or nil }
    end
    if d.treatise then
        out[#out + 1] = { label = d.treatise.name, kp = d.treatise.kp, done = done(d.treatise.quest) }
    end
    return out
end

-- One-time treasures: { {name=, zone=, map=, x=, y=, kp=, done=} }
function K:Treasures(profName)
    local d = data(profName)
    local out = {}
    for _, t in ipairs((d and d.treasures) or {}) do
        -- no tracking quest known yet: nil = "?", not "to do"
        local isDone
        local q = t.quest or K.LearnedTreasure(t.item)
        if q then isDone = done(q) end
        out[#out + 1] = { name = t.name, zone = t.zone, map = t.map, x = t.x, y = t.y,
                          kp = t.kp or 3, done = isDone }
    end
    return out
end

function K:Darkmoon(profName)
    local d = data(profName)
    if not (d and d.dmf) then return nil end
    return { name = d.dmf.name, kp = d.dmf.kp, done = done(d.dmf.quest), where = d.dmf.where }
end

-- First gather of each node type: 1 KP each. Returns found, total.
function K:FirstGathers(profName)
    local fg = data(profName) and data(profName).firstGather
    if not fg then return nil end
    local found = 0
    for _, r in ipairs(fg.ranges or {}) do
        for q = r[1], r[2] do if done(q) then found = found + 1 end end
    end
    for _, q in ipairs(fg.quests or {}) do if done(q) then found = found + 1 end end
    return math.min(found, fg.total or found), fg.total
end

-- "Renown 6 with Hara'ti · skill 25 · 75 Herbalist's Moxie, 750 Voidlight Marl", with the
-- faction and currency names from the game.
function K.FormatReq(req)
    if not req then return nil end
    local parts = {}
    if req.faction and req.renown then
        local f = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(req.faction)
        parts[#parts + 1] = ("Renown %d with %s"):format(req.renown, (f and f.name) or "the faction")
    end
    if req.skill then parts[#parts + 1] = ("skill %d"):format(req.skill) end
    if req.cost then
        local c = {}
        for id, n in pairs(req.cost) do
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
            c[#c + 1] = ("%d %s"):format(n, (info and info.name) or ("currency " .. id))
        end
        table.sort(c)
        parts[#parts + 1] = table.concat(c, ", ")
    end
    return table.concat(parts, " · ")
end

-- Can you buy it right now? Returns true, or false + what's missing
-- ("Renown 3/6 with Hara'ti · 40/75 Herbalist's Moxie"). Skill is the profession's.
function K.CheckReq(req, profName)
    if not req then return true end
    local miss = {}
    if req.faction and req.renown then
        local f = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(req.faction)
        local have = (f and f.isUnlocked and f.renownLevel) or 0
        if have < req.renown then
            miss[#miss + 1] = ("Renown %d/%d with %s"):format(have, req.renown, (f and f.name) or "the faction")
        end
    end
    if req.skill then
        -- the current expansion's skill (the books are Midnight's): from the profession
        -- window's save; the base profession's rank can be another expansion's (Astra)
        local d = VoidProf.KPData and VoidProf.KPData[profName]
        local cache = VoidProf.ProfCache and VoidProf:ProfCache()[profName]
        local tier = d and cache and cache.tiers and cache.tiers[d.skillLine]
        local have = tier and tier.skill
        if not have then
            -- not saved yet: the base rank may be another expansion's, so don't guess
            miss[#miss + 1] = ("skill ?/%d (open the %s window once)"):format(req.skill, profName)
        elseif have < req.skill then
            miss[#miss + 1] = ("skill %d/%d"):format(have, req.skill)
        end
    end
    for id, n in pairs(req.cost or {}) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        local have = (info and info.quantity) or 0
        if have < n then miss[#miss + 1] = ("%d/%d %s"):format(have, n, (info and info.name) or ("currency " .. id)) end
    end
    if #miss == 0 then return true end
    return false, table.concat(miss, " · ")
end

-- One-time knowledge books (10 KP): { {name=, kp=, done=} }; names load async.
function K:Books(profName)
    local d = data(profName)
    local out = {}
    for _, b in ipairs((d and d.books) or {}) do
        local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(b.item)
        if not name and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(b.item) end
        local req = K.FormatReq(b.req)
        local canBuy, missing = K.CheckReq(b.req, profName)
        -- the waypoint target carries the book + requirement into the row tooltip
        local where = b.where and setmetatable({ name = b.where.name .. " sells " .. (name or b.name or "it"),
            req = canBuy and ("You can buy it now. Costs: " .. (req or "?")) or ("Not yet. Missing: " .. missing) },
            { __index = b.where })
        out[#out + 1] = { name = name or b.name or ("Knowledge book " .. b.item), kp = b.kp, done = done(b.quest),
                          where = where, vendor = b.vendor, req = req, canBuy = canBuy, missing = missing }
    end
    return out
end

-- Weekly catch-up drop (no cap, no tracking quest): just its name.
function K:CatchUp(profName)
    local d = data(profName)
    return d and d.catchUp and d.catchUp.name
end

-- What to spend points on next. An advice entry is a string, or a function given the
-- tree as { [tabName] = rank } that returns a string (so it can follow your progress).
-- Your skill in this expansion's line of a profession, or nil. The line's own
-- info answers once a profession window has loaded it; the Professions book's
-- call works any time but may report an older expansion's line, so it's only
-- used when it names this one ("Midnight Mining").
function K:Skill(profName)
    local line = self:SkillLine(profName)
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
    if line and fn then
        local ok, info = pcall(fn, line)
        if ok and info and (info.maxSkillLevel or 0) > 0 then return info.skillLevel or 0 end
    end
    for _, idx in pairs({ GetProfessions() }) do
        local name, _, rank, _, _, _, _, _, _, _, lineName = GetProfessionInfo(idx)
        if name == profName and lineName and lineName:find("^Midnight") then return rank or 0 end
    end
end

function K:Advice(profName)
    local d = data(profName)
    if not (d and d.advice) then return nil end
    local _, class = UnitClass("player")
    local a = d.advice[class] or d.advice.default
    local skill = self:Skill(profName)
    if type(a) == "function" then
        local ranks = {}
        for _, t in ipairs(self:Tree(profName) or {}) do ranks[t.name] = t.rank end
        a = a(ranks, skill)
    end
    -- the game won't take knowledge points before skill 25 (every tab shows locked)
    if a and skill and skill < 25 then
        a = ("At skill 25 (you're %d; points keep until then): "):format(skill) .. a
    end
    return a
end

-- Pins go through this addon's Route.lua: across continents it points at the
-- portal first and moves to the next leg after each zone change, and the pin
-- clears itself on arrival. Data uses 0-100 coordinates; Route uses 0-1.
-- Of several ways in (0-100 coords), the closest to the player: same continent first,
-- then straight-line distance.
local function closest(list)
    local pm = C_Map.GetBestMapForUnit("player")
    local ppos = pm and C_Map.GetPlayerMapPosition(pm, "player")
    local pc, pw
    if ppos then pc, pw = C_Map.GetWorldPosFromMapPos(pm, ppos) end
    local best, bestD
    for _, w in ipairs(list) do
        local c, wp = C_Map.GetWorldPosFromMapPos(w.map, CreateVector2D(w.x / 100, w.y / 100))
        local d = math.huge
        if pc and c == pc and pw and wp then
            local dx, dy = pw.x - wp.x, pw.y - wp.y
            d = dx * dx + dy * dy
        end
        if not bestD or d < bestD then best, bestD = w, d end
    end
    return best
end

local function toRoute(t)
    if not t then return nil end
    local ways = t.portal and t.portal[UnitFactionGroup("player") or ""]
    local portal = ways and (ways.map and ways or closest(ways))
    return { map = t.map, x = t.x / 100, y = t.y / 100, name = t.name, zone = t.zone,
             fallback = portal and toRoute(portal) }   -- e.g. Darkmoon Island takes no pins
end
function K:Waypoint(t)
    if not (t and t.map and t.x and t.y) then return end
    -- also on screen (UIErrorsFrame): the chat line lands on the General tab, which may not be showing
    local ok, why = ns.Route:Go(toRoute(t), { say = function(msg)
        VoidProf:Print(msg)
        UIErrorsFrame:AddMessage("VoidProf: " .. msg, 0.3, 1, 0.3)
    end })
    if not ok then VoidProf:Warn("Can't set a waypoint there (" .. tostring(why) .. ").") end
end

-- Subscribers redraw when something that changes the numbers happens.
K._listeners = {}
function K:OnChange(fn) self._listeners[#self._listeners + 1] = fn end
local function notify() for _, fn in ipairs(K._listeners) do pcall(fn) end end

----------------------------------------------------------------------
-- Treasure tracking quests we don't have yet are learned as you play: when
-- you loot a knowledge treasure, the hidden quest that flipped in the
-- treasures' range is that treasure's. Saved account-wide
-- (VoidProfDB.treasureQuest[item] = quest), so one loot teaches every character.
----------------------------------------------------------------------
local T_LO, T_HI = 89000, 89400   -- every Midnight treasure quest found so far is in here
local snap                       -- flagged quests in the range, as of the last look
local waiting = {}               -- treasure items looted whose quest isn't known yet

local function learnedTable()
    VoidProfDB = VoidProfDB or {}
    VoidProfDB.treasureQuest = VoidProfDB.treasureQuest or {}
    return VoidProfDB.treasureQuest
end
function K.LearnedTreasure(item)
    return item and learnedTable()[item]
end

local function flaggedInRange()
    local s = {}
    for q = T_LO, T_HI do if done(q) then s[q] = true end end
    return s
end

-- item -> profession, for treasures without a known quest; and every quest already taken
local function unknownTreasures()
    local items, taken = {}, {}
    for prof, d in pairs(VoidProf.KPData or {}) do
        for _, t in ipairs(d.treasures or {}) do
            local q = t.quest or learnedTable()[t.item]
            if q then taken[q] = true elseif t.item then items[t.item] = prof end
        end
    end
    return items, taken
end

local function learnStep()
    local now = flaggedInRange()
    if snap and next(waiting) then
        local _, taken = unknownTreasures()
        local new = {}
        for q in pairs(now) do if not snap[q] and not taken[q] then new[#new + 1] = q end end
        local item, n = nil, 0
        for it in pairs(waiting) do item, n = it, n + 1 end
        -- only when it's unambiguous: one treasure waiting, one new flag
        if #new == 1 and n == 1 then
            learnedTable()[item] = new[1]
            waiting[item] = nil
        end
    end
    snap = now
end

local lf = CreateFrame("Frame")
lf:RegisterEvent("PLAYER_LOGIN")
lf:RegisterEvent("CHAT_MSG_LOOT")
lf:SetScript("OnEvent", function(_, event, msg, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(5, function() snap = flaggedInRange() end)
        return
    end
    local guid = select(11, ...)
    if guid and guid ~= UnitGUID("player") then return end
    local item = tonumber(type(msg) == "string" and msg:match("|Hitem:(%d+)") or "")
    if not item then return end
    local items = unknownTreasures()
    if not items[item] then return end
    waiting[item] = true
    -- the flag can trail the loot message
    C_Timer.After(2, learnStep)
end)

local f = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "QUEST_TURNED_IN", "LOOT_CLOSED",
                     "SKILL_LINE_SPECS_RANKS_CHANGED", "SKILL_LINE_SPECS_UNLOCKED", "CURRENCY_DISPLAY_UPDATE",
                     "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "SKILL_LINES_CHANGED",
                     "BAG_UPDATE_DELAYED",   -- crafted / used materials: the leveling plan changes
                     "GET_ITEM_INFO_RECEIVED" }) do   -- book names arrive async
    f:RegisterEvent(e)
end
-- What changes the leveling plan: your skill and what you hold. Crafting with
-- the panel open left the plan as it was (the user, 2026-11-04).
local PLAN_EVENTS = { BAG_UPDATE_DELAYED = true, TRADE_SKILL_LIST_UPDATE = true, SKILL_LINES_CHANGED = true }
local pending, replan
f:SetScript("OnEvent", function(_, event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then rememberSkillLine() end
    if PLAN_EVENTS[event] then replan = true end
    -- quest flags update a moment after the loot/turn-in: debounce
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = nil
        if replan and VoidProf.LevelUI and VoidProf.LevelUI.Invalidate then VoidProf.LevelUI:Invalidate() end
        replan = nil
        notify()
    end)
end)
