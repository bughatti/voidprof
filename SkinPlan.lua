----------------------------------------------------------------------
-- VoidProf Skinning plan (WoW Forever) -- the Skinning tab's step-by-step guide, like the herb and
-- ore plans: every 25 points, which beast levels give you skill and the best zones for them, with
-- a "Nearest beasts" route (the user, 2026-11-15: "do the skinning guide"; before, the tab only
-- had the next skill cap).
--
-- The skill a beast's level needs (Classic, same table Farm.lua prices leather with): 1 up to
-- level 10, (level - 10) x 10 up to 20, then level x 5. A beast gives skill always (orange) while
-- your skill is under its need + 25, usually (yellow) under + 50, sometimes (green) under + 75.
-- Where they are: VoidGPS.Skin (Skin.lua: CMaNGOS says which mobs skin, VoidDB where they
-- spawn). Without VoidGPS the steps still say which levels to skin.
----------------------------------------------------------------------
VoidProf = VoidProf or {}
local SP = {}
VoidProf.SkinPlan = SP

local function need(lvl)
    if lvl <= 10 then return 1 end
    if lvl <= 20 then return (lvl - 10) * 10 end
    return lvl * 5
end
SP.Need = need

-- the beast levels a step from `s` should skin: whose need is in (s - 25, s], so they're orange
-- when the step starts and still yellow when it ends (1-25: levels 1-10, 150-175: 26-30)
local function levelsFor(s)
    local lo, hi
    for L = 1, 63 do
        local n = need(L)
        if n <= math.max(s, 1) and n > s - 25 then
            lo = lo or L
            hi = L
        end
    end
    if not lo then   -- no level's need lands in the window (never at these steps, but be safe)
        for L = 63, 1, -1 do if need(L) <= s then return L, L end end
        return 1, 1
    end
    return lo, hi
end
SP.LevelsFor = levelsFor

local STEPS = {}
for s = 0, 275, 25 do STEPS[#STEPS + 1] = math.max(1, s) end

local SAFETY_HEX = { yours = "33ff33", contested = "ffb84d", enemy = "ff5050", sanctuary = "33ff33" }
local function mapName(id)
    local i = C_Map.GetMapInfo(id)
    return i and i.name or "?"
end
local function safety(map)
    return VoidProf.GatherPlan and VoidProf.GatherPlan.Safety and VoidProf.GatherPlan:Safety(map) or "contested"
end
local function zoneLabel(map)
    return "|cff" .. (SAFETY_HEX[safety(map)] or "ffffff") .. mapName(map) .. "|r"
end

-- the best zones for these levels: most spawns of beasts in range, your faction's and contested
-- ones before the enemy's. -> { { map, n, mobs = { names } }, ... }
function SP:Zones(lo, hi, max)
    local S = _G.VoidGPS and _G.VoidGPS.Skin
    if not S then return nil end
    local ok, list = pcall(S.For, S, lo, hi)
    if not ok then return nil end
    local byMap = {}
    for _, e in ipairs(list) do
        local z = byMap[e.map]
        if not z then z = { map = e.map, n = 0, mobs = {} }; byMap[e.map] = z end
        z.n = z.n + e.n
        if #z.mobs < 3 then z.mobs[#z.mobs + 1] = e.mob end
    end
    local out = {}
    for _, z in pairs(byMap) do out[#out + 1] = z end
    table.sort(out, function(a, b)
        local ea, eb = safety(a.map) == "enemy", safety(b.map) == "enemy"
        if ea ~= eb then return eb end
        if a.n ~= b.n then return a.n > b.n end
        return a.map < b.map
    end)
    while #out > (max or 3) do table.remove(out) end
    return out
end

-- the nearest skinnable beast of a step outside enemy territory (else the nearest at all)
function SP:Nearest(lo, hi)
    local S = _G.VoidGPS and _G.VoidGPS.Skin
    if not S then return nil end
    local ok, list = pcall(S.For, S, lo, hi)
    if not ok then return nil end
    for _, e in ipairs(list) do if safety(e.map) ~= "enemy" then return e end end
    return list[1]
end

function SP:Wants(profName) return profName == "Skinning" end

function SP:Build(parent, profName, anchor, makeButton)
    if not self:Wants(profName) then return end
    local P = VoidUI.palette
    local head = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(head, 11, "OUTLINE")
    head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -44)
    head:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    head:SetText("Leveling plan")

    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 4)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(480, 10)
    sf:SetScrollChild(child)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
    end)
    local function block()
        local t = child:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(t, 10, "")
        t:SetWidth(470)
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetWordWrap(true)
        t:SetSpacing(3)
        t:SetTextColor(0.85, 0.85, 0.88)
        return t
    end
    local top, bottom = block(), block()
    top:SetPoint("TOPLEFT", 0, 0)
    local btn = makeButton(child, 150, 22, "|cffffd200Nearest beasts|r", function(b)
        if not (_G.VoidGPS and _G.VoidGPS.Skin) then
            VoidProf:Print("Install VoidGPS (free, same author) for routes to beasts you can skin.")
            return
        end
        local e = b._lo and SP:Nearest(b._lo, b._hi)
        if e and _G.VoidGPS.Skin:Go(e) then
            VoidProf:Print(("Heading to |cffffffff%s|r (level %d-%d), %s%s."):format(e.mob, e.minL, e.maxL, mapName(e.map),
                e.yards and (", " .. math.floor(e.yards) .. " yd") or ""))
        else
            VoidProf:Warn("No skinnable beasts known for that.")
        end
    end)
    btn:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText("Nearest beasts", 1, 1, 1)
        GameTooltip:AddLine(("A VoidGPS route to the nearest beasts you can skin for skill now (level %d-%d), outside enemy territory when there are any."):format(b._lo or 0, b._hi or 0), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 24, -6)
    bottom:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -36)
    sf:SetScript("OnSizeChanged", function(_, w)
        if w and w > 0 then
            child:SetWidth(w)
            top:SetWidth(w - 4); bottom:SetWidth(w - 4)
            if parent._skin then SP:Refresh(parent) end
        end
    end)
    parent._skin = { top = top, bottom = bottom, child = child, btn = btn }
end

local function stepLine(i, s, skill, cur)
    local e = STEPS[i + 1] or 300
    local lo, hi = levelsFor(s)
    local mark = (i == cur) and "|cff00c7ff> " or ((skill >= e) and "|cff777777" or "")
    local line = ("%s%d-%d: skin level %d-%d beasts|r"):format(mark, s, e, lo, hi)
    local zones = SP:Zones(lo, hi, 3)
    if zones and #zones > 0 then
        local t = {}
        for _, z in ipairs(zones) do t[#t + 1] = ("%s (%s)"):format(zoneLabel(z.map), table.concat(z.mobs, ", ")) end
        line = line .. "\n    |cffaaaaaaWhere:|r " .. table.concat(t, " · ")
    end
    return line
end

function SP:Refresh(parent)
    local p = parent and parent._skin
    if not p then return end
    local prof = VoidProf.SkillCap and VoidProf.SkillCap:Professions().Skinning
    if not prof then p.top:SetText(""); p.bottom:SetText(""); p.btn:Hide(); return end
    local skill = prof.rank or 0
    local cur = 1
    for i, s in ipairs(STEPS) do if skill >= s then cur = i end end
    local lo, hi = levelsFor(STEPS[cur])
    local lines = {
        ("|cffaaaaaaSkinning %d: beasts up to level %d can be skinned. Orange always gives skill, then yellow, green, grey (never).|r"):format(skill,
            (function() local m = 1; for L = 1, 63 do if need(L) <= skill then m = L end end return m end)()),
    }
    local me = UnitLevel("player") or 1
    if lo > me + 2 then
        lines[#lines + 1] = ("|cffffb84dYou're level %d: level %d-%d beasts may be too strong. Lower ones still give skill, just less often.|r"):format(me, lo, hi)
    end
    if not (_G.VoidGPS and _G.VoidGPS.Skin) then
        lines[#lines + 1] = "|cff888888Install VoidGPS for the best zones and a route to the nearest beasts.|r"
    end
    lines[#lines + 1] = " "
    local rest = {}
    for i, s in ipairs(STEPS) do
        local t = stepLine(i, s, skill, cur)
        if i <= cur then lines[#lines + 1] = t else rest[#rest + 1] = t end
    end
    p.top:SetText(table.concat(lines, "\n"))
    p.bottom:SetText(table.concat(rest, "\n"))
    p.btn._lo, p.btn._hi = lo, hi
    p.btn:Show()
    local h = (p.top:GetStringHeight() or 0) + 36 + (p.bottom:GetStringHeight() or 0)
    p.child:SetHeight(h * 1.3 + 8)   -- this font draws ~1.3x what GetStringHeight says
end
