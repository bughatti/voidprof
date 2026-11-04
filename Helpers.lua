----------------------------------------------------------------------
-- VoidProf Helpers
--
-- Profession workflow shortcuts:
--   CastCookingFire()    — drops a Basic Campfire (spell 818)
--   FilletAllFish()      — loops C_TradeSkillUI.CraftRecipe over every
--                          Midnight-tier fish in the player's bags
----------------------------------------------------------------------

VoidProf = VoidProf or {}
VoidProf.Helpers = {}

-- the global GetItemCount is gone without the deprecation fallbacks (12.x)
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local Helpers = VoidProf.Helpers

----------------------------------------------------------------------
-- Cooking Fire — Basic Campfire spell (ID 818, classic spell)
----------------------------------------------------------------------
local COOKING_FIRE_SPELL_ID = 818  -- Basic Campfire

-- Addon code can't cast spells (protected since 12.0): the panel's Cooking tab has a
-- secure "Cast Cooking Fire" button. This only explains where it is.
function Helpers:CastCookingFire()
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell   -- the global is deprecated in 12.x
    if not known(COOKING_FIRE_SPELL_ID) then
        VoidProf:Warn("You don't know Basic Campfire. Train it from the Cooking trainer.")
        return
    end
    VoidProf:Print("Use the |cffffd200Cast Cooking Fire|r button on the panel's Cooking tab.")
    if VoidProf.UI and VoidProf.UI.Toggle then VoidProf.UI:Toggle() end
end

----------------------------------------------------------------------
-- Fillet All Fish — auto-loop Thalassian Filet on every Midnight fish
----------------------------------------------------------------------
-- Midnight-tier fish item IDs.
-- NOTE: This list is hand-curated because the in-game item-class system
-- doesn't tag fish by expansion. As Blizzard adds new fish in 12.0.x
-- patches we update this list. Players can also override via
-- VoidProfDB.extraFishIDs = { <itemID>, ... }.
local MIDNIGHT_FISH_IDS = {
    -- Common Midnight fish (will need to verify against patch data)
    -- The user can add more via /vp addfish <itemID>.
}

-- Match recipe by EXACT name first, then by ordered fallbacks. We require
-- "thalassian" in the name so generic "filet"/"fillet" doesn't match other
-- food recipes that mention filet in their text.
local THALASSIAN_FILET_NAMES = {
    "thalassian filet",   -- exact, single-L (per in-game screenshot)
    "thalassian fillet",  -- spelling variant, double-L
}

local function FindRecipeByName(profName, candidateNames)
    local cache = VoidProf:ProfCache()[profName]
    if not cache then return nil end
    -- Pass 1: exact name match (case-insensitive)
    for _, recipe in pairs(cache.recipes) do
        local lname = (recipe.name or ""):lower()
        for _, n in ipairs(candidateNames) do
            if lname == n then
                VoidProf:Print(string.format("Matched recipe: '%s' (id=%s, options=%d)",
                    recipe.name,
                    tostring(recipe.spellID or recipe.id),
                    recipe.modifyingSlots and recipe.modifyingSlots[1] and #recipe.modifyingSlots[1].allOptions or 0))
                return recipe
            end
        end
    end
    -- Pass 2: substring (only after exact fails)
    for _, recipe in pairs(cache.recipes) do
        local lname = (recipe.name or ""):lower()
        for _, n in ipairs(candidateNames) do
            if lname:find(n, 1, true) then
                VoidProf:Print(string.format("Substring matched: '%s' (id=%s, options=%d)",
                    recipe.name,
                    tostring(recipe.spellID or recipe.id),
                    recipe.modifyingSlots and recipe.modifyingSlots[1] and #recipe.modifyingSlots[1].allOptions or 0))
                return recipe
            end
        end
    end
    return nil
end

-- Public diagnostic: list all cached recipes for a profession (shows in chat)
function VoidProf:DumpRecipes(profName)
    local cache = VoidProf:ProfCache()[profName]
    if not cache then
        VoidProf:Warn("No cache for " .. tostring(profName) .. ". Open the profession window first.")
        return
    end
    VoidProf:Print(string.format("--- %s recipes (%d) ---", profName, cache.learnedCount or 0))
    local names = {}
    for _, r in pairs(cache.recipes) do
        names[#names + 1] = r.name or ("recipe " .. tostring(r.id))
    end
    table.sort(names)
    for _, n in ipairs(names) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. n)
    end
end

-- For salvage-type recipes (Thalassian Filet, Disenchant, Mill, Prospect),
-- the accepted item list comes from C_TradeSkillUI.GetSalvagableItemIDs.
-- For normal recipes the list is in the modifying-reagent slot.
local function GetAcceptedItemsForRecipe(recipe)
    -- Salvage path
    if C_TradeSkillUI and C_TradeSkillUI.GetSalvagableItemIDs then
        local ok, ids = pcall(C_TradeSkillUI.GetSalvagableItemIDs, recipe.spellID or recipe.id)
        if ok and ids and #ids > 0 then
            return ids, "salvage"
        end
    end
    -- Modifying-slot path (regular crafts)
    if recipe.modifyingSlots and recipe.modifyingSlots[1] then
        return recipe.modifyingSlots[1].allOptions, "craft"
    end
    return {}, nil
end

-- Find first bag,slot containing itemID. Iterates all bags including the
-- reagent bag (slot 5 in modern WoW), where fish typically live.
-- Returns ItemLocation usable for CraftSalvage.
local function FindBagItemLocation(itemID)
    -- Backpack (0), main bags (1-4), reagent bag (5)
    local maxBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    for bag = 0, maxBag do
        local slots = C_Container and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return ItemLocation:CreateFromBagAndSlot(bag, slot), info.stackCount or 1
            end
        end
    end
    return nil, 0
end

local function ScanForAcceptedItems(recipe)
    local accepted, mode = GetAcceptedItemsForRecipe(recipe)
    local found = {}
    for _, itemID in ipairs(accepted) do
        local count = GetItemCount(itemID, false)
        if count and count > 0 then
            found[#found + 1] = { itemID = itemID, count = count }
        end
    end
    return found, mode
end

-- Pending fillet queue + processor (handles both salvage and craft modes).
-- Event-driven: each batch waits for all UNIT_SPELLCAST_SUCCEEDED events to
-- fire (or stack to deplete) before moving to the next fish type.
Helpers._filletQueue = {}
Helpers._filletActive = false
Helpers._currentJob = nil

-- Forward declaration — CompleteCurrentJob references ProcessFilletQueue
local ProcessFilletQueue

local function CompleteCurrentJob()
    if Helpers._safetyTimer then
        Helpers._safetyTimer:Cancel()
        Helpers._safetyTimer = nil
    end
    if Helpers._watchdogTimer then
        Helpers._watchdogTimer:Cancel()
        Helpers._watchdogTimer = nil
    end
    if Helpers._idleTimer then
        Helpers._idleTimer:Cancel()
        Helpers._idleTimer = nil
    end
    if Helpers._pollTimer then
        Helpers._pollTimer:Cancel()
        Helpers._pollTimer = nil
    end
    Helpers._currentJob = nil
    Helpers._filletActive = false

    -- DO NOT call StopRecasting / SetIsRecipeRepeating / SpellStopCasting
    -- here. Those are protected functions — calling them from addon code
    -- between batches taints the secure trade skill state, which makes
    -- subsequent CraftSalvage calls silently fail ("Interface action failed
    -- because of an AddOn"). The natural batch end (cast queue completes
    -- on its own or stack depletes) doesn't need cleanup. The user's manual
    -- Cancel button still calls the cleanup — taint there is acceptable
    -- because it only happens when the user explicitly cancels.

    -- SAFE MODE: stop after each batch. Auto-loop with CloseTradeSkill +
    -- OpenTradeSkill caused a disenchant accident — too dangerous. Print a
    -- message asking the user to manually click Fillet again to continue.
    local remaining = #(Helpers._filletQueue or {})
    if remaining > 0 then
        VoidProf:Print(string.format("|cffffd200Batch done. %d more fish type(s) queued.|r |cff00ff00Click Fillet All Fish again to continue.|r", remaining))
    end
    if VoidProf.UI and VoidProf.UI.RefreshFilletStatus then
        VoidProf.UI:RefreshFilletStatus()
    end
end

-- Public: cancel the fillet queue. Honest limitation — Blizzard restricts
-- addon-side interruption of the auto-recast queue as anti-bot protection.
-- Movement is the only fully reliable cancel mechanism. We do everything
-- we CAN from addon code:
--   1. Clear our own queue immediately (no more jobs will start)
--   2. Call C_TradeSkillUI.StopRecasting (helps in some cases)
--   3. Close the trade skill UI (often cancels the in-flight cast)
--   4. SpellStopCasting + brief spam loop
--   5. Tell the user to jump for full cancel.
function Helpers:CancelFillet()
    if Helpers._safetyTimer then
        Helpers._safetyTimer:Cancel()
        Helpers._safetyTimer = nil
    end
    Helpers._filletQueue = {}
    Helpers._currentJob = nil
    Helpers._filletActive = false

    -- 1. Recast queue API (effective when called from secure context, partial otherwise)
    if C_TradeSkillUI then
        if C_TradeSkillUI.StopRecasting then pcall(C_TradeSkillUI.StopRecasting) end
        if C_TradeSkillUI.SetIsRecipeRepeating then pcall(C_TradeSkillUI.SetIsRecipeRepeating, false) end
        -- 2. Closing the trade skill UI also cancels recasts in many cases
        if C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill) end
    end
    if HideUIPanel and _G.ProfessionsFrame and _G.ProfessionsFrame:IsShown() then
        pcall(HideUIPanel, _G.ProfessionsFrame)
    end

    -- 3. The cast already running can't be stopped from here: SpellStopCasting
    -- is protected (addon code calling it is blocked; Astra, 2026-11-03).
    VoidProf:Print("Fillet queue stopped. Move or press Escape to stop the cast in progress.")

    if VoidProf.UI and VoidProf.UI.RefreshFilletStatus then
        VoidProf.UI:RefreshFilletStatus()
    end
end

ProcessFilletQueue = function()
    if Helpers._filletActive then return end
    if #Helpers._filletQueue == 0 then
        -- Don't claim "done" while the player is still mid-cast — Blizzard's
        -- recast queue can have pending casts that fire after our addon's
        -- counter hit target. Wait for cast bar to actually clear.
        local castingName = UnitCastingInfo and UnitCastingInfo("player")
        local repeating = false
        if C_TradeSkillUI and C_TradeSkillUI.IsRecipeRepeating then
            local ok, r = pcall(C_TradeSkillUI.IsRecipeRepeating)
            if ok then repeating = r and true or false end
        end
        if castingName or repeating then
            -- Still casting / queue still active — re-check shortly
            Helpers._waitingForFinalCast = (Helpers._waitingForFinalCast or 0) + 1
            if Helpers._waitingForFinalCast < 60 then  -- max 60s wait
                C_Timer.After(1, ProcessFilletQueue)
                return
            end
        end
        Helpers._waitingForFinalCast = 0
        VoidProf:Print("|cff00ff00Fillet queue empty — done.|r")
        if VoidProf.UI and VoidProf.UI.RefreshFilletStatus then
            VoidProf.UI:RefreshFilletStatus()
        end
        return
    end
    Helpers._waitingForFinalCast = 0
    Helpers._filletActive = true

    local job = table.remove(Helpers._filletQueue, 1)
    local recipe = job.recipe
    local fish = job.fish
    local mode = job.mode
    local link = (C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(fish.itemID))) or ("item:" .. fish.itemID)

    job.completed = 0
    job.targetCount = fish.count
    Helpers._currentJob = job

    local ok, err
    if mode == "salvage" then
        local itemLocation, stackCount = FindBagItemLocation(fish.itemID)
        if not itemLocation then
            VoidProf:Warn("Could not locate " .. (link or fish.itemID) .. " in bags.")
            CompleteCurrentJob()
            return
        end
        local casts = math.min(fish.count, stackCount)
        job.targetCount = casts
        local repeatingState = "?"
        if C_TradeSkillUI and C_TradeSkillUI.IsRecipeRepeating then
            local rok, r = pcall(C_TradeSkillUI.IsRecipeRepeating)
            if rok then repeatingState = tostring(r) end
        end
        ok, err = pcall(C_TradeSkillUI.CraftSalvage,
            recipe.spellID or recipe.id, casts, itemLocation)
        VoidProf:Print(string.format("Filleting %dx %s... (CraftSalvage ok=%s, repeating=%s)",
            casts, link, tostring(ok), repeatingState))
    else
        -- CraftingReagentInfo = { reagent = { itemID }, dataSlotIndex, quantity per
        -- craft }, and the count is crafts, not fish (Astra, 2026-11-03)
        local craftingReagents, per = {}, 1
        if recipe.modifyingSlots and recipe.modifyingSlots[1] then
            per = math.max(1, recipe.modifyingSlots[1].qty or 1)
            craftingReagents[1] = {
                reagent       = { itemID = fish.itemID },
                quantity      = per,
                dataSlotIndex = recipe.modifyingSlots[1].slotIndex,
            }
        end
        local crafts = math.floor(fish.count / per)
        if crafts < 1 then
            CompleteCurrentJob()
            return
        end
        ok, err = pcall(C_TradeSkillUI.CraftRecipe, recipe.spellID or recipe.id, crafts, craftingReagents)
        if ok then
            VoidProf:Print(string.format("Crafting %dx %s...", crafts, link))
        end
    end

    if not ok then
        VoidProf:Warn(string.format("Failed for %s: %s", link, tostring(err)))
        CompleteCurrentJob()
        return
    end

    -- COMPLETION DETECTION: poll the actual cast bar instead of counting
    -- events. The addon's "is casting" state must follow what the user can
    -- visibly see — UnitCastingInfo("player") is the truth.
    --
    --   * Initial 6s grace for casts to start (some batches stall briefly)
    --   * After grace: poll every 0.5s
    --   * Each iteration where UnitCastingInfo == our spell → reset empty counter
    --   * Each iteration where cast bar is empty → empty counter +1
    --   * 6 consecutive empty polls (3s) = batch done
    --
    -- Hard upper limit: cast count × 2 + 30 seconds (math safety).
    local jobSpellID = recipe.spellID or recipe.id
    local hardLimit = (job.targetCount * 2) + 30
    local elapsed = 0
    local emptyTicks = 0
    local hadCast = false
    local function PollCastBar()
        if Helpers._currentJob ~= job then return end
        elapsed = elapsed + 0.5

        local castName, _, _, _, _, _, _, _, castSpellID = UnitCastingInfo("player")
        if castName and (castSpellID == jobSpellID or not jobSpellID) then
            hadCast = true
            emptyTicks = 0
        else
            -- Cast bar empty (for our spell). Only count after grace period
            -- so the initial cast-start delay doesn't false-trigger.
            if elapsed > 6 or hadCast then
                emptyTicks = emptyTicks + 1
            end
        end

        if hadCast and emptyTicks >= 6 then
            -- 3 seconds of empty cast bar after we saw at least one cast = done
            CompleteCurrentJob()
            return
        end
        if elapsed >= hardLimit then
            VoidProf:Print(string.format("|cffff8800Batch hard-timeout (%.0fs) — moving on.|r", hardLimit))
            CompleteCurrentJob()
            return
        end
        if not hadCast and elapsed >= 8 then
            -- Never saw a cast in 8s — Blizzard silently rejected. Skip.
            VoidProf:Print(string.format("|cffff8800No cast started for %s — skipping.|r", link))
            CompleteCurrentJob()
            return
        end
        Helpers._pollTimer = C_Timer.NewTimer(0.5, PollCastBar)
    end
    Helpers._pollTimer = C_Timer.NewTimer(0.5, PollCastBar)
end

-- Event watcher: count successful casts + detect cast start (watchdog flag)
local castWatcher = CreateFrame("Frame")
castWatcher:RegisterEvent("UNIT_SPELLCAST_START")
castWatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castWatcher:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
castWatcher:RegisterEvent("UNIT_SPELLCAST_FAILED")
castWatcher:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
castWatcher:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if unit ~= "player" then return end
    local job = Helpers._currentJob
    if not job then return end
    local jobSpellID = job.recipe.spellID or job.recipe.id
    if spellID ~= jobSpellID then return end

    -- Cast started — clear watchdog
    if event == "UNIT_SPELLCAST_START" then
        job.castStartedFlag = true
        if Helpers._watchdogTimer then
            Helpers._watchdogTimer:Cancel()
            Helpers._watchdogTimer = nil
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Just update progress display. Completion is now driven by
        -- PollCastBar in ProcessFilletQueue (cast-bar-empty-for-3s = done).
        job.completed = (job.completed or 0) + 1
        if VoidProf.UI and VoidProf.UI.RefreshFilletStatus then
            VoidProf.UI:RefreshFilletStatus()
        end
    else
        -- Interrupted/failed — give it a moment, then move on
        -- only if it is still this job: a cancel or restart may have started another
        C_Timer.After(0.5, function() if Helpers._currentJob == job then CompleteCurrentJob() end end)
    end
end)

function Helpers:FilletAllFish()
    -- Sanity checks
    if not C_TradeSkillUI then
        VoidProf:Warn("C_TradeSkillUI not available.")
        return
    end
    -- Need cooking trade skill open OR cached — try to find recipe
    local recipe = FindRecipeByName("Cooking", THALASSIAN_FILET_NAMES)
    if not recipe then
        VoidProf:Warn("Thalassian Filet not in cache. Open your Cooking profession window once, then try again.")
        return
    end
    -- Detect mode (salvage vs craft) and get accepted item list.
    local accepted, mode = ScanForAcceptedItems(recipe)
    if not mode then
        VoidProf:Warn("Recipe has no salvage list and no modifying reagent slot. Try opening Cooking and running /vp sync first.")
        return
    end
    if #accepted == 0 then
        local total = 0
        local _, list = pcall(C_TradeSkillUI.GetSalvagableItemIDs, recipe.spellID or recipe.id)
        if type(list) == "table" then total = #list end
        VoidProf:Warn(string.format(
            "No matching fish in bags. Thalassian Filet (mode=%s) accepts %d types but you have none of them.",
            mode, total))
        return
    end

    Helpers._filletQueue = {}
    local totalFish = 0
    for _, f in ipairs(accepted) do
        Helpers._filletQueue[#Helpers._filletQueue + 1] = {
            recipe = recipe, fish = f, mode = mode,
        }
        totalFish = totalFish + (f.count or 0)
    end

    VoidProf:Print(string.format("Queued %d fish types (%d total) for filleting via %s API.",
        #accepted, totalFish, mode))
    ProcessFilletQueue()
end
