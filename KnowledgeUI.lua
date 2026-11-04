----------------------------------------------------------------------
-- VoidProf Knowledge UI — the "Knowledge" section of a profession tab
-- (scrolls with the mouse wheel; treasure rows set a waypoint on click).
----------------------------------------------------------------------

VoidProf = VoidProf or {}
local K = VoidProf.Knowledge
local KUI = {}
VoidProf.KnowledgeUI = KUI

local ROW = 14
local GREEN, GREY, GOLD, DIM = "|cff55ff55", "|cff777777", "|cffffd200", "|cff9a9aa6"
local STATE = { [0] = GREY .. "locked|r", [1] = GREEN .. "unlocked|r", [2] = GOLD .. "can unlock|r" }

local sections = {}   -- profName -> section frame

local function text(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(fs, size or 10, "")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(r or 0.85, g or 0.85, b or 0.9)
    return fs
end

local function check(isDone)
    if isDone == nil then return DIM .. "?|r" end
    return isDone and (GREEN .. "done|r") or (GOLD .. "to do|r")
end

-- Build the section once; Refresh fills it.
function KUI:Build(parent, profName, topY)
    local P = VoidUI.palette
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetPoint("TOPLEFT", 0, topY)
    scroll:SetPoint("BOTTOMRIGHT", -6, 4)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(520, 10)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
    end)
    scroll:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w) end)

    local head = text(child, 11, P.accent[1], P.accent[2], P.accent[3])
    VoidUI:SetFont(head, 11, "OUTLINE")
    head:SetPoint("TOPLEFT", 14, 0)
    head:SetText("Knowledge")

    child.summary = text(child, 10)
    child.summary:SetPoint("TOPLEFT", 14, -18)
    child.summary:SetPoint("RIGHT", child, "RIGHT", -14, 0)
    child.summary:SetWordWrap(true)

    child.rows = {}
    scroll.child, scroll.profName = child, profName
    sections[profName] = scroll
    return scroll
end

-- A clickable row (treasures) or a plain one.
local function row(child, i)
    local r = child.rows[i]
    if not r then
        r = CreateFrame("Button", nil, child)
        r:SetHeight(ROW)
        -- hover highlight, so the clickable rows (waypoints) look clickable
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(VoidUI.palette.accent[1], VoidUI.palette.accent[2], VoidUI.palette.accent[3], 0.15)
        r.fs = text(r, 10)
        r.fs:SetPoint("LEFT")
        r.fs:SetPoint("RIGHT")
        r:SetScript("OnClick", function(self) if self.target then K:Waypoint(self.target) end end)
        r:SetScript("OnEnter", function(self)
            if not self.target then return end
            local t = self.target
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(t.name, 1, 1, 1)
            if t.zone then GameTooltip:AddLine(("%s %.1f, %.1f"):format(t.zone, t.x or 0, t.y or 0), 0.75, 0.75, 0.8) end
            if t.req then GameTooltip:AddLine(t.req, 1, 0.82, 0, true) end
            GameTooltip:AddLine("Click: waypoint + arrow", 0.6, 0.8, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        child.rows[i] = r
    end
    r:ClearAllPoints()
    r:Show()
    return r
end

function KUI:Refresh(profName)
    local scroll = sections[profName]
    if not scroll then return end
    local child = scroll.child

    -- Summary: unspent points, tree progress, advice.
    local lines = {}
    local unspent, cname = K:Unspent(profName)
    if unspent then
        lines[#lines + 1] = (unspent > 0 and GOLD or GREEN) .. unspent .. "|r unspent " .. (cname or "knowledge")
            .. (unspent > 0 and DIM .. "  (spend them in the profession window's Specializations tab)|r" or "")
    else
        lines[#lines + 1] = DIM .. "Open the " .. profName .. " window once so VoidProf can read your knowledge points.|r"
    end
    local tree = K:Tree(profName)
    if tree and #tree > 0 then
        local parts = {}
        for _, t in ipairs(tree) do
            parts[#parts + 1] = ("%s %s%d/%d|r (%s)"):format(t.name, GOLD, t.rank, t.max, STATE[t.state] or "?")
        end
        lines[#lines + 1] = table.concat(parts, DIM .. "  ·  |r")
    end
    local advice = K:Advice(profName)
    if advice then lines[#lines + 1] = GOLD .. "Next:|r " .. advice end
    child.summary:SetText(table.concat(lines, "\n"))

    local y = -18 - child.summary:GetStringHeight() - 10
    local i = 0
    local function add(str, target, indent)
        i = i + 1
        local r = row(child, i)
        r:SetPoint("TOPLEFT", 14 + (indent or 0), y)
        r:SetPoint("RIGHT", child, "RIGHT", -14, 0)
        r.fs:SetText(str)
        r.target = target
        r:EnableMouse(target ~= nil)
        y = y - ROW
    end

    local weekly = K:Weekly(profName)
    if #weekly > 0 then
        add(GOLD .. "Every week|r")
        for _, w in ipairs(weekly) do
            add(("%s  %s%s|r  %s+%d KP|r%s"):format(check(w.done), "|cffe0e0e8", w.label, DIM, w.kp or 0,
                w.progress and (DIM .. "  " .. w.progress .. "|r") or ""), w.where, 8)
        end
        local catch = K:CatchUp(profName)
        if catch then add(DIM .. "Then " .. catch .. " can drop as catch-up (no weekly cap).|r", nil, 8) end
        y = y - 6
    end
    local dmf = K:Darkmoon(profName)
    if dmf then
        add(GOLD .. "Every month|r")
        add(("%s  Darkmoon Faire: %s  %s+%d KP|r"):format(check(dmf.done), dmf.name or "quest", DIM, dmf.kp or 0),
            (not dmf.done) and dmf.where or nil, 8)
        y = y - 6
    end
    local found, total = K:FirstGathers(profName)
    local books = K:Books(profName)
    if found or #books > 0 then
        add(GOLD .. "One-time|r")
        if found then
            add(("%s  First gather of each node type  %s%d / %d found, +1 KP each|r"):format(
                check(total and found >= total), DIM, found, total or found), nil, 8)
        end
        for _, b in ipairs(books) do
            -- can you buy it yet? (so you don't fly out for nothing)
            local status = b.done and "" or (b.canBuy and ("  " .. GREEN .. "can buy now|r")
                or ("  |cffff6060need " .. (b.missing or "?") .. "|r"))
            add(("%s  %s  %s+%d KP (vendor book%s)|r%s"):format(check(b.done), b.name, DIM, b.kp or 0,
                b.vendor and (": " .. b.vendor) or "", status), (not b.done) and b.where or nil, 8)
        end
        y = y - 6
    end
    local treasures = K:Treasures(profName)
    if #treasures > 0 then
        local left = 0
        for _, t in ipairs(treasures) do if not t.done then left = left + 1 end end
        add(GOLD .. "One-time treasures|r" .. DIM .. ("  %d of %d left · click one for a waypoint|r"):format(left, #treasures))
        for _, t in ipairs(treasures) do
            add(("%s  %s  %s%s %.0f, %.0f|r"):format(check(t.done), t.name, DIM, t.zone or "", t.x or 0, t.y or 0),
                (not t.done) and t or nil, 8)
        end
    end
    if #weekly == 0 and #treasures == 0 and not dmf then
        add(DIM .. "No knowledge checklist for " .. profName .. " yet.|r")
    end
    -- then the leveling plan from what you have (LevelUI.lua)
    if VoidProf.LevelUI then y = VoidProf.LevelUI:Render(child, profName, y) end

    for j = i + 1, #child.rows do child.rows[j]:Hide() end
    child:SetHeight(-y + 10)
end

-- Only the tab you can see: each one works out a leveling plan, and bag events
-- come in bursts while you craft. A tab is refreshed again when you switch to it.
function KUI:RefreshAll()
    for profName, scroll in pairs(sections) do
        if scroll:IsVisible() then self:Refresh(profName) end
    end
end

K:OnChange(function() KUI:RefreshAll() end)
