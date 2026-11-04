-- VoidSpy hook: enable with /vspy enable VoidProf  (no-op if VoidSpy missing/disabled)
local function dbg(fmt, ...) if VoidSpy and VoidSpy.Log then VoidSpy:Log("VoidProf", fmt, ...) end end

----------------------------------------------------------------------
-- VoidProf Core
--
-- Init, slash command, recipe cache hook (TRADE_SKILL_LIST_UPDATE).
-- Cache is per character (VoidProf:ProfCache()) and also written to
-- VoidUIAuctionDB.profCache for backward compat with VoidAH's existing
-- Professions tab.
----------------------------------------------------------------------

VoidProf = VoidProf or {}

-- This character's recipe cache, by profession name. Per character: an
-- account-wide one let two characters with the same profession overwrite
-- each other's skill and recipes (Astra, 2026-11-03).
function VoidProf:ProfCache()
    VoidProfCharDB = VoidProfCharDB or {}
    VoidProfCharDB.profCache = VoidProfCharDB.profCache or {}
    return VoidProfCharDB.profCache
end

----------------------------------------------------------------------
-- Recipe cache: snapshot every learned recipe + reagents
----------------------------------------------------------------------
function VoidProf:CaptureTradeSkillSnapshot()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then return end
    -- a linked, guild or NPC profession is someone else's: never save it as yours
    local T = C_TradeSkillUI
    if (T.IsTradeSkillLinked and T.IsTradeSkillLinked()) or (T.IsTradeSkillGuild and T.IsTradeSkillGuild())
        or (T.IsTradeSkillGuildMember and T.IsTradeSkillGuildMember()) or (T.IsNPCCrafting and T.IsNPCCrafting()) then
        return
    end

    local prof = C_TradeSkillUI.GetBaseProfessionInfo()
    if not prof or not prof.professionName then return end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if not recipeIDs or #recipeIDs == 0 then return end

    local cache = {
        professionID = prof.professionID,
        skillLine    = prof.skillLine,
        lastSync     = time(),
        -- from the profession info itself (GetTradeSkillLineInfoByID is gone: Astra, 2026-11-03)
        skillRank    = prof.skillLevel or 0,
        skillMaxRank = prof.maxSkillLevel or 0,
        recipes      = {},
        learnedCount = 0,
    }

    -- Skill per expansion line (Midnight Enchanting 22/100 ...), which the
    -- planner (Planner.lua) starts from: the base numbers above can belong to
    -- another line. Without it the plan started at 1 after a /reload (2026-11-03).
    cache.tiers = {}
    local okKids, kids = pcall(C_TradeSkillUI.GetChildProfessionInfos)
    for _, k in ipairs(okKids and kids or {}) do
        if k.professionID and (k.maxSkillLevel or 0) > 0 then
            cache.tiers[k.professionID] = { skill = k.skillLevel or 0, max = k.maxSkillLevel }
        end
    end

    for _, rID in ipairs(recipeIDs) do
        local rInfo = C_TradeSkillUI.GetRecipeInfo(rID)
        if rInfo and rInfo.learned then
            local reagents = {}
            -- Track modifying reagent slots separately (used for fish/herb selection)
            local modifyingSlots = {}
            local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, rID, false)
            if ok and schematic and schematic.reagentSlotSchematics then
                for slotIdx, slot in ipairs(schematic.reagentSlotSchematics) do
                    if slot.reagents and slot.reagents[1] and slot.reagents[1].itemID then
                        local entry = {
                            itemID       = slot.reagents[1].itemID,
                            qty          = slot.quantityRequired or 1,
                            slotIndex    = slot.dataSlotIndex or slotIdx,
                            reagentType  = slot.reagentType,
                            allOptions   = {},
                        }
                        for _, r in ipairs(slot.reagents) do
                            if r.itemID then entry.allOptions[#entry.allOptions + 1] = r.itemID end
                        end
                        reagents[#reagents + 1] = entry
                        if #entry.allOptions > 1 then
                            modifyingSlots[#modifyingSlots + 1] = entry
                        end
                    end
                end
            end
            cache.recipes[rID] = {
                id              = rID,
                name            = rInfo.name,
                spellID         = rInfo.recipeID,  -- recipe ID == spell ID for crafts in 12.0
                difficulty      = rInfo.relativeDifficulty,
                categoryID      = rInfo.categoryID,
                reagents        = reagents,
                modifyingSlots  = modifyingSlots,
            }
            cache.learnedCount = cache.learnedCount + 1
        end
    end

    VoidProf:ProfCache()[prof.professionName] = cache

    -- Also write to VoidUIAuctionDB so VoidAH's Professions tab keeps working
    if VoidUIAuctionDB then
        VoidUIAuctionDB.profCache = VoidUIAuctionDB.profCache or {}
        VoidUIAuctionDB.profCache[prof.professionName] = cache
    end

    -- Notify subscribers (UI re-render hooks)
    if VoidProf._onCacheUpdate then
        for _, fn in ipairs(VoidProf._onCacheUpdate) do
            local ok2, err = pcall(fn, prof.professionName, cache)
            if not ok2 then VoidProf:Warn("Cache update hook error: " .. tostring(err)) end
        end
    end
end

VoidProf._onCacheUpdate = {}
function VoidProf:OnCacheUpdate(fn)
    table.insert(VoidProf._onCacheUpdate, fn)
end

local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
cacheFrame:RegisterEvent("PLAYER_LOGIN")
cacheFrame:SetScript("OnEvent", function(_, event)
    if event == "TRADE_SKILL_LIST_UPDATE" then
        VoidProf:CaptureTradeSkillSnapshot()
    end
end)

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_VOIDPROF1 = "/vp"
SLASH_VOIDPROF2 = "/voidprof"
SlashCmdList["VOIDPROF"] = function(msg)
    dbg("slash: %s", tostring(msg))
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or msg == "show" or msg == "toggle" then
        if VoidProf.UI and VoidProf.UI.Toggle then VoidProf.UI:Toggle() end
    elseif msg == "fire" or msg == "campfire" or msg == "cooking" then
        if VoidProf.Helpers and VoidProf.Helpers.CastCookingFire then
            VoidProf.Helpers:CastCookingFire()
        end
    elseif msg == "fillet" or msg == "fish" then
        if VoidProf.Helpers and VoidProf.Helpers.FilletAllFish then
            VoidProf.Helpers:FilletAllFish()
        end
    elseif msg == "sync" or msg == "refresh" then
        VoidProf:CaptureTradeSkillSnapshot()
        VoidProf:Print("Recipe cache refreshed.")
    elseif msg == "dump" then
        local cache = VoidProf:ProfCache()
        for prof, data in pairs(cache) do
            VoidProf:Print(string.format("%s: %d recipes, skill %d/%d",
                prof, data.learnedCount or 0, data.skillRank or 0, data.skillMaxRank or 0))
        end
    elseif msg:match("^recipes ") then
        local prof = msg:gsub("^recipes ", ""):gsub("^%l", string.upper)
        VoidProf:DumpRecipes(prof)
    else
        VoidProf:Print("Commands:")
        VoidProf:Print("  |cffffd200/vp|r — open panel")
        VoidProf:Print("  |cffffd200/vp fire|r — cast Basic Campfire")
        VoidProf:Print("  |cffffd200/vp fillet|r — fillet all Midnight fish in bags")
        VoidProf:Print("  |cffffd200/vp sync|r — refresh recipe cache")
        VoidProf:Print("  |cffffd200/vp dump|r — show cached profession summary")
    end
end

----------------------------------------------------------------------
-- Init at PLAYER_LOGIN
----------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    VoidProfDB = VoidProfDB or {}
    VoidProfCharDB = VoidProfCharDB or {}
    -- (no login chat line: the minimap button opens the panel)
end)
