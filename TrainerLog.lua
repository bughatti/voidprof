----------------------------------------------------------------------
-- VoidProf Trainer log -- which recipes a trainer teaches, learned when you open its window.
-- Classic recipes come with a trainer list (VoidGPS.Trainers, CMaNGOS), but WoW Forever's own
-- recipes (First Aid Kit, Simple Poultice, Mana Well, Faction Banner...) aren't in any data, so the
-- guide could only say "a trainer" (the user, 2026-11-15: "i cant click on it to find out who or
-- where it is"). VoidProfDB.trainers[npcID] = { name, map, x, y (0..1, where you stood), t,
-- teaches = { ["Recipe name"] = skill needed } }. The window hides what you already know, so each
-- visit adds to what earlier ones saw.
----------------------------------------------------------------------
VoidProf = VoidProf or {}
local TL = {}
VoidProf.TrainerLog = TL

local function npcID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then return nil end
    return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function record()
    if not (IsTradeskillTrainer and IsTradeskillTrainer()) then return end
    local npc = npcID("npc")
    if not npc then return end
    local teaches, costs, n = {}, {}, 0
    for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
        local name, _, kind = GetTrainerServiceInfo(i)
        if type(name) == "string" and name ~= "" and kind ~= "header" then
            local _, rank = GetTrainerServiceSkillReq(i)
            teaches[name] = tonumber(rank) or 0
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i)
            costs[name] = tonumber(cost) or 0
            n = n + 1
        end
    end
    if n == 0 then return end
    VoidProfDB = VoidProfDB or {}
    VoidProfDB.trainers = VoidProfDB.trainers or {}
    local rec = VoidProfDB.trainers[npc] or { teaches = {} }
    rec.costs = rec.costs or {}
    for k, v in pairs(teaches) do rec.teaches[k], rec.costs[k] = v, costs[k] end
    -- the log is account-wide: whose side the trainer is on (Codex: an alt of the other faction's
    -- visits must not send this character to a trainer it can't use)
    -- every side that used it: a neutral trainer (Booty Bay) serves both (Codex re-review)
    local fac = UnitFactionGroup("player")
    if fac then rec.facs = rec.facs or {}; rec.facs[fac] = true end
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local nm = UnitName("npc")
    rec.name = (type(nm) == "string" and not (issecretvalue and issecretvalue(nm))) and nm or rec.name
    if pos then rec.map, rec.x, rec.y = map, pos.x, pos.y end
    rec.t = time()
    VoidProfDB.trainers[npc] = rec
end
TL.Record = record

-- trainers of your faction you've seen teach this recipe: { { name, map, x, y, req, cost }, ... },
-- newest visit first
function TL:For(recipeName)
    local out = {}
    local mine = UnitFactionGroup("player")
    for _, rec in pairs(VoidProfDB and VoidProfDB.trainers or {}) do
        local req = rec.teaches and rec.teaches[recipeName]
        if req and rec.map and rec.x and (not rec.facs or rec.facs[mine]) then
            out[#out + 1] = { name = rec.name or "Trainer", title = "", map = rec.map, x = rec.x, y = rec.y, req = req,
                cost = rec.costs and rec.costs[recipeName] or nil, t = rec.t or 0 }
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

local f = CreateFrame("Frame")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
f:SetScript("OnEvent", function()
    -- the list fills in a moment after the window opens
    C_Timer.After(0.2, function() pcall(record) end)
end)
