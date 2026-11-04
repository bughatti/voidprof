----------------------------------------------------------------------
-- VoidProf Level UI -- "Leveling from what you have", under a profession
-- tab's Knowledge section: VoidProf.Planner's plan for that profession.
-- What you can craft right now from what your characters hold, what to mill
-- and craft first, what comes from which character, and what's left to buy
-- (VoidAH's Professions tab at the Auction House has Buy buttons for those).
----------------------------------------------------------------------

VoidProf = VoidProf or {}
local LUI = {}
VoidProf.LevelUI = LUI

local GOLD, DIM, GREEN, ORANGE, RED = "|cffffd200", "|cff9a9aa6", "|cff55ff55", "|cffff8040", "|cffff6060"
local CACHE_SECS = 10
local SHOW_MAX = 8    -- rows per list before "…and N more"

local plans = {}      -- profName -> { t, plan }

-- Work every plan out again next time (the panel was opened: bags may have changed).
function LUI:Invalidate() plans = {} end

-- The plan for a profession, rebuilt at most every CACHE_SECS (a tab refresh
-- can come several times in a row). nil = not a crafting profession.
function LUI:Plan(profName, force)
    local P = VoidProf.Planner
    local e = P and P:Find(profName)
    if not e then return nil end
    local c = plans[profName]
    if not force and c and GetTime() - c.t < CACHE_SECS then return c.plan end
    local ok, plan = pcall(P.Build, P, e)
    if not ok then
        VoidProf:Warn("Leveling plan error: " .. tostring(plan))
        return nil
    end
    plans[profName] = { t = GetTime(), plan = plan }
    return plan
end

local function list(lines, title, rows, more)
    if #rows == 0 then return end
    lines[#lines + 1] = " "
    lines[#lines + 1] = GOLD .. title .. "|r"
    for i, r in ipairs(rows) do
        if i > SHOW_MAX then
            lines[#lines + 1] = DIM .. ("  …and %d more%s|r"):format(#rows - SHOW_MAX, more or "")
            break
        end
        lines[#lines + 1] = r
    end
end

-- Draws the section into the Knowledge scroll child from `y` down; returns
-- the new y. Professions without a plan (gathering, fishing) draw nothing.
function LUI:Render(child, profName, y)
    local plan = self:Plan(profName)
    if not plan then
        if child.levelHead then child.levelHead:Hide(); child.levelText:Hide() end
        return y
    end
    if not child.levelHead then
        local P = VoidUI.palette
        local head = child:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(head, 11, "OUTLINE")
        head:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
        head:SetText("Leveling from what you have")
        local fs = child:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(fs, 10, "")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetSpacing(1)
        fs:SetTextColor(0.85, 0.85, 0.9)
        child.levelHead, child.levelText = head, fs
    end
    local head, fs = child.levelHead, child.levelText

    local lines = {}
    if plan.openWindow then lines[#lines + 1] = plan.openWindow end
    lines[#lines + 1] = plan.summary or ""
    if plan.deNote then lines[#lines + 1] = plan.deNote end

    local now = {}
    for _, c in ipairs(plan.craftNow or {}) do
        local color = c.chance >= 1 and (ORANGE .. "orange|r") or (DIM .. ("yellow, %d%% a point"):format(math.floor(c.chance * 100 + 0.5)) .. "|r")
        now[#now + 1] = ("  %s%dx|r %s  %s%s"):format(GREEN, c.crafts, c.name, color,
            c.vendor and (DIM .. "  + from a vendor: " .. c.vendor .. "|r") or "")
    end
    if #now > 0 then
        -- each count is on its own: two inks share the same pigments
        list(lines, "Craft now from what you have |r" .. DIM .. "(each line on its own; they can share materials)", now)
    elseif (plan.start or 100) < 100 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = DIM .. "Nothing to craft for skill from what you have yet.|r"
    end

    local made = {}
    for _, m in ipairs(plan.made or {}) do made[#made + 1] = m end
    list(lines, "Make first (cheaper than buying)", made)
    list(lines, "From your characters", plan.fromOwn or {})

    local buy = {}
    for _, m in ipairs(plan.mats or {}) do
        buy[#buy + 1] = ("  %dx %s  %s%s|r"):format(m[1], m[2], DIM, m[4] or "")
    end
    list(lines, "Still to buy", buy)
    if #buy > 0 then
        lines[#lines + 1] = DIM .. (VoidAH_Price and "VoidAH's Professions tab at the Auction House has Buy buttons for these."
            or "Prices are the game's listed ones; VoidAH adds your Auction House prices and Buy buttons.") .. "|r"
    end

    local path = {}
    for _, st in ipairs(plan.steps or {}) do
        path[#path + 1] = ("  %s%d-%d|r  %dx %s%s"):format(DIM, st.startSkill, st.endSkill, st.count, st.recipe,
            st.known == false and ("  " .. RED .. "NOT LEARNED|r") or "")
    end
    list(lines, "Path", path)
    if plan.allChars == false then
        lines[#lines + 1] = DIM .. "Counting this character and the warband bank. With VoidGather your other characters count too.|r"
    end

    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", 14, y - 10)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 14, y - 28)
    fs:SetPoint("RIGHT", child, "RIGHT", -14, 0)
    fs:SetText(table.concat(lines, "\n"))
    head:Show(); fs:Show()
    return y - 28 - fs:GetStringHeight() - 10
end

-- A recipe sync (profession window opened) changes the plan right away.
if VoidProf.OnCacheUpdate then
    VoidProf:OnCacheUpdate(function(profName)
        if profName then plans[profName] = nil end
        if VoidProf.KnowledgeUI and profName then VoidProf.KnowledgeUI:Refresh(profName) end
    end)
end
