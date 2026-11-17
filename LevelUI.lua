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

-- Go to where a recipe is learned: go = { kind = "trainer" / "vendor", name, map, x, y (0..1), ... }.
-- VoidGPS routes across continents; without it, VoidProf's own waypoint.
function LUI:Go(go)
    if not (go and go.map and go.x and go.y) then return false end
    local G = _G.VoidGPS
    if go.kind == "trainer" and G and G.Trainers then return G.Trainers:Go(go) end
    if go.kind == "vendor" and G and G.Recipes then
        return G.Recipes:GoVendor(go, go.item and C_Item.GetItemNameByID(go.item) or nil)
    end
    if VoidProf.Knowledge and VoidProf.Knowledge.Waypoint then
        VoidProf.Knowledge:Waypoint({ map = go.map, x = go.x * 100, y = go.y * 100, name = go.name })
        return true
    end
    return false
end

local function money(c)
    if not c or c <= 0 then return "" end
    local g, s = math.floor(c / 10000), math.floor(c / 100) % 100
    return g > 0 and (g .. "g" .. (s > 0 and (" " .. s .. "s") or "")) or (s .. "s")
end

-- the tooltip of a line to learn: every trainer that teaches it (nearest first), or its vendor
local function tip(self)
    local t = self.target
    if not t then return end
    local st, go = t.step, t.go
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(st and ("Learn " .. st.recipe) or (go and go.name) or "?", 1, 1, 1)
    local trainers = st and st.trainers
    if trainers and #trainers > 0 then
        GameTooltip:AddLine("Taught by:", 1, 0.82, 0)
        for i, tr in ipairs(trainers) do
            if i > 5 then GameTooltip:AddLine(("…and %d more"):format(#trainers - 5), 0.6, 0.6, 0.6); break end
            local info = C_Map.GetMapInfo(tr.map)
            local extra = {}
            if tr.req and tr.req > 0 then extra[#extra + 1] = "skill " .. tr.req end
            if tr.cost and tr.cost > 0 then extra[#extra + 1] = money(tr.cost) end
            GameTooltip:AddLine(("%s, %s %.0f, %.0f%s"):format(tr.name, info and info.name or "?", tr.x * 100, tr.y * 100,
                #extra > 0 and ("  (" .. table.concat(extra, ", ") .. ")") or ""), 0.85, 0.85, 0.9)
        end
    elseif go and go.kind == "vendor" then
        local info = C_Map.GetMapInfo(go.map)
        GameTooltip:AddLine(("Sold by %s, %s %.0f, %.0f"):format(go.name, info and info.name or "?", go.x * 100, go.y * 100), 0.85, 0.85, 0.9)
    elseif st then
        GameTooltip:AddLine(st.source or "Where to learn it isn't known.", 0.85, 0.85, 0.9, true)
    end
    if go then
        GameTooltip:AddLine("Click: waypoint + arrow", 0.6, 0.8, 1)
    elseif not _G.VoidGPS then
        GameTooltip:AddLine("Install VoidGPS to see who teaches it and get a waypoint.", 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function newRow(child)
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(12)
    -- hover highlight on the lines you can click (learn steps)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(VoidUI.palette.accent[1], VoidUI.palette.accent[2], VoidUI.palette.accent[3], 0.15)
    local fs = r:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(fs, 10, "")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetTextColor(0.85, 0.85, 0.9)
    fs:SetPoint("TOPLEFT")   -- width set on each draw: a wrapped line must be measured at its real width
    r.fs = fs
    r:SetScript("OnClick", function(self) if self.target and self.target.go then LUI:Go(self.target.go) end end)
    r:SetScript("OnEnter", tip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- Draws the section into the Knowledge scroll child from `y` down; returns
-- the new y. Professions without a plan (gathering, fishing) draw nothing.
function LUI:Render(child, profName, y)
    local plan = self:Plan(profName)
    if not plan then
        if child.levelHead then child.levelHead:Hide(); child.levelText:Hide() end
        for _, r in ipairs(child.levelRows or {}) do r:Hide() end
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

    -- The steps first, numbered, in the order you do them, every one of them (the user at the
    -- trainer, 2026-11-09: "doesnt list the instructions in order"; the path used to come last).
    local skill = plan.skillLevel or plan.start or 0
    local steps = plan.steps or {}
    if #steps > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = GOLD .. "Step by step|r"
        for i, st in ipairs(steps) do
            local done, now = skill >= st.endSkill, skill >= st.startSkill and skill < st.endSkill
            local learn = st.known == false and ("  " .. RED .. "learn it first: " .. (st.source or "trainer") .. "|r") or ""
            local row = ("%d. %d-%d: craft %d %s%s"):format(i, st.startSkill, st.endSkill, st.count, st.recipe, learn)
            local text = done and (DIM .. "  " .. row .. "  (done)|r")
                or now and (GREEN .. "> " .. row .. "|r")
                or ("  " .. row)
            -- a recipe to learn: click = waypoint to its trainer / vendor (the user, 2026-11-15: "i cant
            -- click on it to find out who or where it is")
            lines[#lines + 1] = (not done and st.known == false) and { text = text, go = st.go, step = st } or text
            -- what the step takes and where it's sold, one line per vendor (click: the way there)
            -- (the user, 2026-11-17, Poisons: "where to get [them] from ... walk through each leveling piece")
            if not done and st.need and #st.need > 0 then
                local parts, byVendor, order, ah = {}, {}, {}, {}
                for _, m in ipairs(st.need) do
                    local n = math.ceil(m.n - 1e-6)
                    local made = n - (m.have or 0) - (m.buy or 0)   -- the rest comes from an earlier step / milling
                    local note = {}
                    if (m.have or 0) > 0 then note[#note + 1] = m.have .. " from your bags" end
                    if made > 0 then note[#note + 1] = (note[1] and made .. " " or "") .. "made in an earlier step" end
                    parts[#parts + 1] = ("%d %s%s"):format(n, m.name or "?", #note > 0 and (" (" .. table.concat(note, ", ") .. ")") or "")
                    -- what the plan buys in this step (made / milled materials and your bags never are)
                    if (m.buy or 0) > 0 then
                        local v = m.vendor
                        if v and v.name and v.map and v.x then
                            local k = v.name .. "@" .. v.map
                            if not byVendor[k] then byVendor[k] = { v = v, items = {}, item = m.id }; order[#order + 1] = k end
                            byVendor[k].items[#byVendor[k].items + 1] = m.name or "?"
                        else
                            ah[#ah + 1] = m.name or "?"
                        end
                    end
                end
                lines[#lines + 1] = DIM .. "      takes " .. table.concat(parts, ", ") .. "|r"
                for _, k in ipairs(order) do
                    local b = byVendor[k]
                    lines[#lines + 1] = { text = ("      %sbuy at %s%s:|r %s%s|r"):format(DIM, b.v.name, b.v.zone and (", " .. b.v.zone) or "",
                            DIM, table.concat(b.items, ", ")),
                        go = { kind = "vendor", name = b.v.name, map = b.v.map, x = b.v.x, y = b.v.y, item = b.item } }
                end
                -- only VoidGPS knows the vendors: without it, say nothing rather than "no vendor" (Sol review)
                if #ah > 0 and _G.VoidGPS and _G.VoidGPS.Goods then
                    lines[#lines + 1] = DIM .. "      no vendor sells " .. table.concat(ah, ", ") .. ": the Auction House or farm it|r"
                end
            end
        end
    end

    -- recipes the path buys (WoW Forever: a vendor or the AH sells them; Planner.lua LearnHow)
    local learn = {}
    for _, l in ipairs(plan.learn or {}) do
        local text = ("  %s at %d: %s%s|r"):format(l.recipe, l.at, DIM, l.text)
        local v = l.vendor
        learn[#learn + 1] = (v and v.map) and { text = text, go = { kind = "vendor", name = v.name, map = v.map, x = v.x, y = v.y, item = l.item } } or text
    end
    if #learn > 0 then
        list(lines, "Recipes to buy|r" .. DIM .. " (cheaper leveling than what you know; vendor ones: click them under Recipes from vendors for the way)", learn)
    end

    -- materials cheaper to farm than to buy (WoW Forever: Farm.lua)
    local farm = {}
    for _, r in ipairs(plan.farm or {}) do
        farm[#farm + 1] = ("  %dx %s  %s%s, about %d min|r"):format(r.n, r.name, DIM, r.text, math.ceil(r.minutes))
    end
    list(lines, "Farm yourself|r" .. DIM .. " (quicker for what it's worth than buying)", farm)

    local now = {}
    for _, c in ipairs(plan.craftNow or {}) do
        local color = c.chance >= 1 and (ORANGE .. "orange|r") or (DIM .. ("yellow, %d%% a point"):format(math.floor(c.chance * 100 + 0.5)) .. "|r")
        -- a vendor reagent makes it endless: no "512x"
        now[#now + 1] = ("  %s%s|r %s  %s%s"):format(GREEN, c.unlimited and "any number of" or (c.crafts .. "x"), c.name, color,
            c.vendor and (DIM .. (c.unlimited and "  + its vendor reagents" or ("  + from a vendor: " .. c.vendor)) .. "|r") or "")
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
        -- a vendor reagent names its nearest vendor and is a click away (the user, 2026-11-17, the
        -- Poisons tab: "kind of bare"; Deathweed and the vials come from a poison vendor)
        local v = m[5]
        local text = ("  %dx %s  %s%s%s|r"):format(m[1], m[2], DIM, m[4] or "",
            v and v.name and ("  at " .. v.name .. (v.zone and (", " .. v.zone) or "")) or "")
        buy[#buy + 1] = (v and v.map and v.x) and { text = text, go = { kind = "vendor", name = v.name, map = v.map, x = v.x, y = v.y, item = m[3] } } or text
    end
    list(lines, "Still to buy|r" .. DIM .. (#buy > 0 and " (a line with a vendor: click it for the way)" or ""), buy)
    if #buy > 0 then
        lines[#lines + 1] = DIM .. (VoidAH_Price and "VoidAH's Professions tab at the Auction House has Buy buttons for these."
            or "Prices are the game's listed ones; VoidAH adds your Auction House prices and Buy buttons.") .. "|r"
    end

    if plan.allChars == false then
        lines[#lines + 1] = DIM .. "Counting this character and the warband bank. With VoidGather your other characters count too.|r"
    end

    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", 14, y - 10)
    head:Show()
    fs:Hide()   -- one row per line now: a line can be clicked (fs kept for frames made before)
    local rows = child.levelRows or {}
    child.levelRows = rows
    local yy = y - 28
    local width = math.max(200, (child:GetWidth() or 0) - 28)
    for i, ln in ipairs(lines) do
        local r = rows[i] or newRow(child)
        rows[i] = r
        local t = type(ln) == "table" and ln or nil
        r.target = t
        r:EnableMouse(t ~= nil)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 14, yy)
        r:SetPoint("RIGHT", child, "RIGHT", -14, 0)
        -- the width first, then the text: measured before the row had a width, a wrapped line counted as
        -- one and the next row was drawn over its second line (seen in game 2026-11-15)
        r.fs:SetWidth(width)
        r.fs:SetText(t and t.text or ln)
        -- a long line wraps: the row grows to its text so the next one starts below it
        -- by lines x the font's drawn line height: GetStringHeight says 10 a line for this size-10 font but
        -- the game draws about 13, so the second line of a step ran into the next one (seen 2026-11-15)
        local _, size = r.fs:GetFont()
        local lineH = math.ceil((size or 10) * 1.3)
        local h = math.max(lineH, (r.fs:GetNumLines() or 1) * lineH, math.ceil(r.fs:GetStringHeight() or 0) + 1)
        r:SetHeight(h)
        r:Show()
        yy = yy - h
    end
    for j = #lines + 1, #rows do rows[j]:Hide() end
    return yy - 10
end

-- A recipe sync (profession window opened) changes the plan right away.
if VoidProf.OnCacheUpdate then
    VoidProf:OnCacheUpdate(function(profName)
        if profName then plans[profName] = nil end
        if VoidProf.KnowledgeUI and profName then VoidProf.KnowledgeUI:Refresh(profName) end
        if VoidProf.UI and VoidProf.UI.RefreshCaps then VoidProf.UI:RefreshCaps() end   -- Forever tabs
    end)
end
