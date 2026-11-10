----------------------------------------------------------------------
-- VoidProf UI — main panel with per-profession tabs
--
-- Tabs are auto-built from the player's active professions detected via
-- GetProfessions(). Each tab can show profession-specific helpers,
-- status, and recipes. A trailing "Cache" tab always exists for global
-- profession-cache management.
----------------------------------------------------------------------

-- Borders are one screen pixel (tools/cmd/pixelfix, 2026-11-09). WoW snaps each border
-- piece to the pixel grid, and a thin line on a fractional position can snap to 0 px: a side
-- of a box vanishes. VoidPX() asks for one real pixel, and the hook below (installed once, by
-- the first Void addon loaded) turns snapping off on the edges of flat WHITE8X8 borders, like
-- Blizzard's NineSliceUtil.DisableSharpening, so a 1 px line always covers a pixel.
local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end
if not _G.__VoidBorderHook and hooksecurefunc and NineSliceUtil and NineSliceUtil.ApplyLayout then
    _G.__VoidBorderHook = true
    local EDGES = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
                    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    hooksecurefunc(NineSliceUtil, "ApplyLayout", function(c)
        local i = type(c) == "table" and c.backdropInfo
        local e = i and i.edgeFile
        if type(e) ~= "string" or not e:lower():find("white8x8", 1, true) or (tonumber(i.edgeSize) or 0) > 3 then return end
        for _, k in ipairs(EDGES) do
            local t = c[k]
            if t and t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
        end
    end)
end
VoidProf = VoidProf or {}
VoidProf.UI = {}

local UI = VoidProf.UI
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount   -- global gone without fallbacks (12.x)

----------------------------------------------------------------------
-- Per-profession definition: helpers + extra state
-- Add a new profession by adding an entry here.
----------------------------------------------------------------------
local PROFESSION_DEFS = {
    Cooking = {
        helpers = {
            -- A secure spell button: casting from plain addon code (C_Spell.CastSpell)
            -- is blocked since 12.0, so the old action never placed a fire.
            -- WoW Forever: uses your best Campfire Kit (you then click where to put it); else the
            -- best campfire spell you know. Checked again each time the panel opens.
            { label = "|cffffd200Cast Cooking Fire|r",
              spell = function() return VoidProf.Helpers:CookingFireAction() end,
              hint = "Uses your best Campfire Kit: click the ground to place it" },
            { label = "|cffffd200Fillet All Fish|r", retailOnly = true,   -- Midnight fish
              action = function() VoidProf.Helpers:FilletAllFish() end,
              hint = "Cooking window must be open. Loops every fish type." },
        },
    },
    Alchemy = {
        helpers = {
            -- Stub — will be wired up as we add Helpers:RecycleAllPotions / RecycleAllFlasks
            { label = "|cff888888Recycle Potions (coming soon)|r",
              action = function() VoidProf:Print("Recycle Potions helper not implemented yet.") end,
              hint = "Will convert old potions → Stabilized Derivate" },
            { label = "|cff888888Recycle Flasks (coming soon)|r",
              action = function() VoidProf:Print("Recycle Flasks helper not implemented yet.") end,
              hint = "Will convert old flasks → Stabilized Derivate" },
        },
    },
    Jewelcrafting = {
        helpers = {
            { label = "|cff888888Prospect All Ore (coming soon)|r",
              action = function() VoidProf:Print("Prospect helper not implemented yet.") end,
              hint = "Will break stacks of ore into gems" },
        },
    },
    Blacksmithing  = { helpers = {} },
    Tailoring      = { helpers = {} },
    Leatherworking = { helpers = {} },
    Engineering    = { helpers = {} },
    Inscription    = { helpers = {} },
    Enchanting     = { helpers = {} },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
-- spellID: a secure button that casts that spell on click (needs to be built out of
-- combat; in combat it falls back to a plain button that says so). spellID may be a
-- function: it's asked again every time the panel opens (UI:Toggle, out of combat).
local spellButtons = {}     -- secure button -> its spell function

-- What a secure button does: "item:<id>" uses that item (WoW Forever's Campfire Kit, which
-- then asks where to place it), a number casts that spell, nil does nothing. Out of combat only.
local function applyAction(btn, v)
    if type(v) == "string" and v:find("^item:") then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", v)
        btn:SetAttribute("spell", nil)
    elseif v then
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", v)
        btn:SetAttribute("item", nil)
    else
        btn:SetAttribute("type", nil)
    end
    btn._action = v
end

local function MakeButton(parent, w, h, label, onClick, spellID)
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    local secure = spellID and not InCombatLockdown()
    local btn = CreateFrame("Button", nil, parent,
        secure and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate")
    if secure then
        if type(spellID) == "function" then
            spellButtons[btn] = spellID
            applyAction(btn, spellID())
        else
            applyAction(btn, spellID)
        end
        -- nothing to use (no kit, no spell): say so (PostClick, the secure click stays intact)
        -- (both press and release are registered: say it once, on release; Sol review)
        btn:SetScript("PostClick", function(self, _, down)
            if not down and not self._action then VoidProf:Warn("Nothing to use: no Campfire Kit in your bags.") end
        end)
        btn:RegisterForClicks("AnyUp", "AnyDown")
    elseif spellID then
        onClick = function() VoidProf:Warn("Leave combat and reopen the panel to use this button.") end
    end
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = VoidPX(),
    })
    btn:SetBackdropColor(0.10, 0.12, 0.15, 1)
    btn:SetBackdropBorderColor(aR, aG, aB, 0.6)
    local text = btn:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(text, 11, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label)
    btn._text = text
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.22, 0.28, 1)
        self:SetBackdropBorderColor(aR, aG, aB, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.10, 0.12, 0.15, 1)
        self:SetBackdropBorderColor(aR, aG, aB, 0.6)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

local function GetActiveProfessionNames()
    local names = {}
    if not GetProfessions then return names end
    -- GetProfessions returns up to 5 sparse positional values:
    --   prof1, prof2, archaeology(removed in 12.0), fishing, cooking (+ First Aid on WoW Forever)
    -- ipairs stops at the first nil, so index each explicitly (one call, not five).
    local raw = { GetProfessions() }
    for i = 1, 8 do
        local idx = raw[i]
        if idx then
            local name = GetProfessionInfo(idx)
            if name then names[#names + 1] = name end
        end
    end
    return names
end

----------------------------------------------------------------------
-- Tab strip
----------------------------------------------------------------------
local panel
local tabButtons = {}
local tabContents = {}
local activeTab = nil

local function ShowTab(name)
    if UI.CombatBlocked and UI.CombatBlocked() then return end   -- see UI:Toggle
    activeTab = name
    for tabName, content in pairs(tabContents) do
        if tabName == name then
            content:Show()
        else
            content:Hide()
        end
    end
    for tabName, btn in pairs(tabButtons) do
        local P = VoidUI.palette
        local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
        if tabName == name then
            btn:SetBackdropColor(aR * 0.4, aG * 0.4, aB * 0.4, 1)
            btn:SetBackdropBorderColor(aR, aG, aB, 1)
            btn._text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.06, 0.06, 0.08, 1)
            btn:SetBackdropBorderColor(aR, aG, aB, 0.3)
            btn._text:SetTextColor(0.75, 0.75, 0.78)
        end
    end
    if name == "Cache" then UI:RefreshCache() end
    UI:RefreshFilletStatus()
    if tabContents[name] and tabContents[name]._knowledge then VoidProf.KnowledgeUI:Refresh(name) end
    if tabContents[name] and tabContents[name]._cap then VoidProf.SkillCap:Refresh(tabContents[name]) end
end

local function MakeTabButton(parent, label, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(96, 24)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = VoidPX(),
    })
    local txt = btn:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(txt, 11, "OUTLINE")
    txt:SetPoint("CENTER")
    txt:SetText(label)
    btn._text = txt
    btn:SetScript("OnClick", onClick)
    return btn
end

----------------------------------------------------------------------
-- Per-profession tab content builder
----------------------------------------------------------------------
local FOREVER = (select(4, GetBuildInfo()) or 0) < 100000   -- WoW Forever (Classic world)

local function BuildProfessionContent(parent, profName)
    local def = PROFESSION_DEFS[profName] or { helpers = {} }
    if FOREVER then
        -- Forever: no Midnight helpers, no knowledge trees; the skill cap block instead
        local keep = {}
        for _, h in ipairs(def.helpers) do if not h.retailOnly then keep[#keep + 1] = h end end
        def = { helpers = keep }
    end
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]

    -- Header: profession name + skill level
    local title = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetTextColor(aR, aG, aB)
    title:SetText(profName)
    parent._title = title

    local subtitle = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(subtitle, 10, "")
    subtitle:SetPoint("TOPLEFT", 14, -28)
    subtitle:SetTextColor(0.78, 0.78, 0.82)
    parent._subtitle = subtitle

    -- Helpers section
    if #def.helpers > 0 then
        local sect = parent:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(sect, 11, "OUTLINE")
        sect:SetPoint("TOPLEFT", 14, -56)
        sect:SetTextColor(aR, aG, aB)
        sect:SetText("Helpers")

        for i, h in ipairs(def.helpers) do
            local btn = MakeButton(parent, 220, 26, h.label, h.action, h.spell)
            btn:SetPoint("TOPLEFT", 14, -76 - (i - 1) * 32)
            local hint = parent:CreateFontString(nil, "OVERLAY")
            VoidUI:SetFont(hint, 9, "")
            hint:SetPoint("LEFT", btn, "RIGHT", 8, 0)
            hint:SetTextColor(0.55, 0.55, 0.60)
            hint:SetText(h.hint or "")
        end

        -- Cancel button (only meaningful for Cooking right now since fillet
        -- is the one bulk-loop helper, but harmless on others).
        if profName == "Cooking" and not FOREVER then
            local cancelBtn = MakeButton(parent, 80, 26, "|cffff5555Cancel|r", function()
                if VoidProf.Helpers and VoidProf.Helpers.CancelFillet then
                    VoidProf.Helpers:CancelFillet()
                end
            end)
            cancelBtn:SetPoint("TOPLEFT", 14, -76 - #def.helpers * 32)
            local cancelHint = parent:CreateFontString(nil, "OVERLAY")
            VoidUI:SetFont(cancelHint, 9, "")
            cancelHint:SetPoint("LEFT", cancelBtn, "RIGHT", 8, 0)
            cancelHint:SetTextColor(0.55, 0.55, 0.60)
            cancelHint:SetText("Stops the current fillet queue.")
        end
    end

    -- Live fillet status (Cooking tab gets the live progress display)
    if FOREVER then
        if VoidProf.SkillCap then
            local topY = (#def.helpers > 0) and (-76 - #def.helpers * 32 - 12) or -56
            VoidProf.SkillCap:Build(parent, profName, topY, MakeButton)
        end
        return
    end

    if profName == "Cooking" then
        local statusHeader = parent:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(statusHeader, 11, "OUTLINE")
        statusHeader:SetPoint("TOPLEFT", 14, -200)
        statusHeader:SetTextColor(aR, aG, aB)
        statusHeader:SetText("Fillet Status")

        local filletStatus = parent:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(filletStatus, 10, "")
        filletStatus:SetPoint("TOPLEFT", 14, -220)
        filletStatus:SetPoint("RIGHT", -14, 0)
        filletStatus:SetJustifyH("LEFT")
        filletStatus:SetWordWrap(true)
        filletStatus:SetTextColor(0.78, 0.78, 0.82)
        parent._filletStatus = filletStatus
    end

    -- Knowledge advisor (KnowledgeUI.lua) for professions with a specialization tree,
    -- under the helpers. Cooking and Fishing have no tree.
    if profName ~= "Cooking" and profName ~= "Fishing" and VoidProf.KnowledgeUI then
        local topY = (#def.helpers > 0) and (-76 - #def.helpers * 32 - 12) or -56
        VoidProf.KnowledgeUI:Build(parent, profName, topY)
        parent._knowledge = true
    end
end

local function BuildCacheContent(parent)
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]

    local title = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetTextColor(aR, aG, aB)
    title:SetText("Recipe Cache")

    local subtitle = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(subtitle, 10, "")
    subtitle:SetPoint("TOPLEFT", 14, -28)
    subtitle:SetTextColor(0.78, 0.78, 0.82)
    subtitle:SetText("Cache updates automatically when you open a profession window.")

    local syncBtn = MakeButton(parent, 220, 28, "Sync Now (Re-snapshot)", function()
        VoidProf:CaptureTradeSkillSnapshot()
        UI:RefreshCache()
    end)
    syncBtn:SetPoint("TOPLEFT", 14, -56)

    local cacheText = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(cacheText, 10, "")
    cacheText:SetPoint("TOPLEFT", 14, -94)
    cacheText:SetPoint("RIGHT", -14, 0)
    cacheText:SetJustifyH("LEFT")
    cacheText:SetWordWrap(true)
    cacheText:SetTextColor(0.78, 0.78, 0.82)
    parent._cacheText = cacheText
end

----------------------------------------------------------------------
-- Panel construction
----------------------------------------------------------------------
local function BuildPanel()
    if panel then return panel end

    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    local PANEL_W, PANEL_H = 540, 480

    panel = CreateFrame("Frame", "VoidProf_Panel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    VoidUI:CreateBackdrop(panel, 0.08, 0.08, 0.10, 0.97)
    panel:SetBackdropBorderColor(aR, aG, aB, 0.4)
    panel:Hide()
    tinsert(UISpecialFrames, "VoidProf_Panel")

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() if not UI.CombatBlocked() then panel:StartMoving() end end)
    titleBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.06, 0.06, 0.08, 1)
    local titleAccent = titleBar:CreateTexture(nil, "BORDER")
    titleAccent:SetPoint("BOTTOMLEFT")
    titleAccent:SetPoint("BOTTOMRIGHT")
    titleAccent:SetHeight(1)
    titleAccent:SetColorTexture(aR, aG, aB, 0.6)
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 13, "OUTLINE")
    title:SetTextColor(aR, aG, aB)
    title:SetPoint("LEFT", 12, 0)
    title:SetText("VoidProf")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", -6, 0)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(closeText, 14, "OUTLINE")
    closeText:SetPoint("CENTER")
    closeText:SetText("|cffff5555×|r")
    closeBtn:SetScript("OnClick", function() if not UI.CombatBlocked() then panel:Hide() end end)
    closeBtn:SetScript("OnEnter", function() closeText:SetText("|cffff8888×|r") end)
    closeBtn:SetScript("OnLeave", function() closeText:SetText("|cffff5555×|r") end)

    -- Tab strip
    local tabStrip = CreateFrame("Frame", nil, panel)
    tabStrip:SetPoint("TOPLEFT", 0, -32)
    tabStrip:SetPoint("TOPRIGHT", 0, -32)
    tabStrip:SetHeight(28)

    -- Build tabs: one per active profession + "Cache" trailing tab
    local profs = GetActiveProfessionNames()
    local tabsList = {}
    for _, name in ipairs(profs) do tabsList[#tabsList + 1] = name end
    tabsList[#tabsList + 1] = "Cache"

    -- Tabs share the panel's width: 96 px each when they fit, narrower with many
    -- professions (six tabs ran "Cache" past the right edge, 2026-11-05)
    local x = 8
    local avail = (panel:GetWidth() or 540) - 16
    local tabW = math.min(96, math.floor((avail - 2 * (#tabsList - 1)) / #tabsList))
    for _, tabName in ipairs(tabsList) do
        local btn = MakeTabButton(tabStrip, tabName, function() ShowTab(tabName) end)
        btn:SetWidth(tabW)
        btn:SetPoint("TOPLEFT", x, -2)
        tabButtons[tabName] = btn
        x = x + btn:GetWidth() + 2

        local content = CreateFrame("Frame", nil, panel)
        content:SetPoint("TOPLEFT", 0, -64)
        content:SetPoint("BOTTOMRIGHT", 0, 22)   -- room for the version note at the bottom
        content:Hide()
        if tabName == "Cache" then
            BuildCacheContent(content)
        else
            BuildProfessionContent(content, tabName)
        end
        tabContents[tabName] = content
    end

    -- Footer note
    local note = panel:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(note, 8, "")
    note:SetPoint("BOTTOMLEFT", 14, 8)
    note:SetTextColor(0.42, 0.42, 0.48)
    note:SetText("v" .. (C_AddOns.GetAddOnMetadata("VoidProf", "Version") or "?") .. " — also on the minimap button")

    -- Default to first profession tab if available, else Cache
    if #profs > 0 then ShowTab(profs[1]) else ShowTab("Cache") end

    return panel
end

----------------------------------------------------------------------
-- Refresh helpers
----------------------------------------------------------------------
function UI:RefreshCache()
    local content = tabContents["Cache"]
    if not content or not content._cacheText then return end
    local cache = VoidProf:ProfCache()
    local lines = {}
    local count = 0
    for prof, data in pairs(cache) do
        count = count + 1
        local mins = data.lastSync and math.max(0, math.floor((time() - data.lastSync) / 60)) or 0
        lines[#lines + 1] = string.format(
            "  |cffffd200%s|r — %d recipes, skill %d/%d  |cff888888(synced %dm ago)|r",
            prof, data.learnedCount or 0, data.skillRank or 0, data.skillMaxRank or 0, mins)
    end
    if count == 0 then
        content._cacheText:SetText("|cffff8800No professions cached yet.|r\nOpen any profession window to seed the cache.")
    else
        content._cacheText:SetText(table.concat(lines, "\n"))
    end
end

function UI:RefreshFilletStatus()
    local cooking = tabContents["Cooking"]
    if not cooking or not cooking._filletStatus then return end
    local h = VoidProf.Helpers
    if not h then return end

    local lines = {}
    local job = h._currentJob
    local queue = h._filletQueue or {}

    if job then
        local fishLink = (C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(job.fish.itemID)))
            or ("item:" .. job.fish.itemID)
        local progress = (job.completed or 0) .. " / " .. (job.targetCount or 0)
        local remainingInBag = GetItemCount(job.fish.itemID, false) or 0
        lines[#lines + 1] = string.format(
            "|cff00ff00▶ Filleting:|r %s  |cffffd200%s|r  |cff888888(%d in bags)|r",
            fishLink, progress, remainingInBag)
    end
    if #queue > 0 then
        lines[#lines + 1] = string.format("|cff888888Queue: %d more fish type(s)|r", #queue)
        for i, q in ipairs(queue) do
            if i > 4 then
                lines[#lines + 1] = "|cff666666  …and " .. (#queue - 4) .. " more|r"
                break
            end
            local link = (C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(q.fish.itemID)))
                or ("item:" .. q.fish.itemID)
            lines[#lines + 1] = string.format("|cff666666  %dx %s|r", q.fish.count or 0, link)
        end
    end
    if #lines == 0 then
        cooking._filletStatus:SetText("|cff666666(idle — no fillet job running)|r")
    else
        cooking._filletStatus:SetText(table.concat(lines, "\n"))
    end
end

-- Update the per-profession header (skill level) when a tab is shown or cache updates
function UI:RefreshProfessionHeader(profName)
    local content = tabContents[profName]
    if not content or not content._subtitle then return end
    -- Skill straight from the game (works for gathering professions, which have no
    -- recipe cache); the recipe count only for professions that craft.
    local rank, max
    for _, idx in pairs({ GetProfessions() }) do
        local name, _, r, m = GetProfessionInfo(idx)
        if name == profName then rank, max = r, m end
    end
    local cache = VoidProf:ProfCache()[profName]
    local line = rank and string.format("Skill: %d / %d", rank, max or 0) or ""
    if cache and (cache.learnedCount or 0) > 0 then
        local mins = cache.lastSync and math.max(0, math.floor((time() - cache.lastSync) / 60)) or 0
        line = line .. string.format("   |cff888888|   Recipes: %d   |   Synced %dm ago|r", cache.learnedCount, mins)
    end
    content._subtitle:SetText(line)
end

-- The Cooking tab's Cast Cooking Fire is a secure button: built in combat it
-- could only be a plain one, and while it exists the panel can't be shown,
-- hidden, moved or have its tabs switched in combat (Astra, 2026-11-03).
local function CombatBlocked()
    if InCombatLockdown() then
        VoidProf:Warn("Leave combat first.")
        return true
    end
end
UI.CombatBlocked = CombatBlocked

-- Forever: skill cap blocks follow skill-ups, level-ups and a book landing in your bags.
function UI:RefreshCaps()
    if not (panel and panel:IsShown() and VoidProf.SkillCap) then return end
    for prof, content in pairs(tabContents) do
        if content._cap then
            VoidProf.SkillCap:Refresh(content)
            UI:RefreshProfessionHeader(prof)
        end
    end
end

function UI:Toggle()
    if CombatBlocked() then return end
    BuildPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        UI:RefreshCache()
        for prof in pairs(tabContents) do
            if prof ~= "Cache" then UI:RefreshProfessionHeader(prof) end
        end
        UI:RefreshFilletStatus()
        -- bags, banks and prices change while it's closed: the plan is worked out again
        if VoidProf.LevelUI and VoidProf.LevelUI.Invalidate then VoidProf.LevelUI:Invalidate() end
        if activeTab and tabContents[activeTab] and tabContents[activeTab]._knowledge then
            VoidProf.KnowledgeUI:Refresh(activeTab)
        end
        -- spell buttons pick their spell again (a campfire tier learned since); out of combat here
        for b, fn in pairs(spellButtons) do applyAction(b, fn()) end
        panel:Show()
        UI:RefreshCaps()
    end
end

-- Auto-refresh on cache update (live tab content stays current)
if VoidProf.OnCacheUpdate then
    VoidProf:OnCacheUpdate(function(profName)
        if not panel or not panel:IsShown() then return end
        UI:RefreshCache()
        if profName then UI:RefreshProfessionHeader(profName) end
    end)
end
