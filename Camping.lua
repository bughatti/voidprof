----------------------------------------------------------------------
-- VoidProf Camping (WoW Forever) -- each profession's camp items, tier by tier: the skill each one
-- needs, what it takes, whether you have it, and where to get it. The user, 2026-11-15: "camping
-- isnt a profession but would be a nice to have, i have had to google level 2 options for the
-- camping piece of each profession", then the Camping tab: "the campfire ... always in the middle
-- and show an actual fire ... positions around the fire for all the other level 1 things a person
-- can get, if they dont have it, it would be the icon of the item in grey ... under it level 2 and
-- 3 that are clickable and show the data they need to get them".
--
-- Data: the "Camping" recipes of Blizzard's Forever recipe list (ForeverRecipes.lua: name, made item,
-- learn skill, recipe item, materials). The first level is the trainer's; the next ones are recipe
-- items, and the level-2 ones are dungeon boss drops: VoidDungeon:DropsOf(item) says which boss
-- (its loot data, VoidDB). Click a boss drop: a waypoint to the dungeon's entrance.
----------------------------------------------------------------------
local _, ns = ...
VoidProf = VoidProf or {}
local C = {}
VoidProf.Camping = C

local LINE = { Alchemy = 171, Blacksmithing = 164, Cooking = 185, Enchanting = 333, Engineering = 202,
    ["First Aid"] = 129, Leatherworking = 165, Tailoring = 197, Herbalism = 182, Mining = 186, Skinning = 393, Fishing = 356 }
local GOLD, GREEN = "|cffffd200", "|cff55ff55"
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

-- an item's name; one the game hasn't loaded yet is asked for and counted, so the tooltip can draw
-- itself again once it's there (seen in game 2026-11-15: "1x item 3372", "item 273085 drops from")
local missingNames = 0
local function itemName(id)
    local n = C_Item.GetItemNameByID(id)
    if not n then
        missingNames = missingNames + 1
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    return n or "…"
end
local function preload(id) if id and id > 0 and not C_Item.GetItemNameByID(id) then pcall(C_Item.RequestLoadItemDataByID, id) end end

-- a recipe's skill from the leveling data (the trainer's camp item has no learn skill in the API)
local function minSkill(profName, name)
    local P = VoidProf.Planner
    local e = P and P:Find(profName)
    for _, r in ipairs(e and e.data and e.data.recipes or {}) do
        if r[2] == name then return r.min end
    end
end

-- The camp items of a profession, lowest skill first:
-- { { name, made, learn (skill), book (recipe item, 0 = trainer), mats = { {id, n}, ... } }, ... }
function C:Items(profName)
    local line = LINE[profName]
    local out, seen = {}, {}
    if not line then return out end
    for _, r in ipairs(ns.ForeverRecipes or {}) do
        if r[1] == line and r[6] == "Camping" and not seen[r[2]] then
            seen[r[2]] = true
            local e = { name = r[2], made = r[3], learn = r[4] or 0, book = r[5] or 0, mats = {} }
            for i = 7, #r - 1, 2 do e.mats[#e.mats + 1] = { r[i], r[i + 1] } end
            if e.learn == 0 then e.learn = minSkill(profName, e.name) or 0 end
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b) if a.learn ~= b.learn then return a.learn < b.learn end return a.name < b.name end)
    return out
end

local function known(profName, name)
    local cache = VoidProf.ProfCache and VoidProf:ProfCache()
    local c = cache and cache[profName]
    if not (c and c.recipes) then return nil end   -- never synced: don't claim either way
    for _, r in pairs(c.recipes) do
        if type(r) == "table" and r.name == name then return true end
    end
    return false
end

-- How to get one: { text, go = { name, map, x, y (0..1) } or nil, drops = VoidDungeon's list }
function C:Source(profName, e)
    if e.book == 0 then
        return { text = ("from your %s trainer"):format(profName:lower()) }
    end
    local book = itemName(e.book)
    -- bags first; one in the bank says so (Codex: counting the bank told you "in your bags")
    if (GetItemCount(e.book) or 0) > 0 then
        return { text = GREEN .. book .. " is in your bags: use it|r" }
    elseif (GetItemCount(e.book, true) or 0) > 0 then
        return { text = GREEN .. book .. " is in your bank|r" }
    end
    local VD = _G.VoidDungeon
    if not (VD and VD.DropsOf) then
        return { text = ("%s drops from a boss: install VoidDungeon to see which"):format(book) }
    end
    local ok, drops = pcall(VD.DropsOf, VD, e.book)
    local d = ok and drops and drops[1]
    if not d then return { text = ("where %s drops isn't known yet"):format(book) } end
    local more = #drops > 1 and (" or %d more"):format(#drops - 1) or ""
    local at = d.at and d.at[1]
    return { text = ("%s drops from %s%s|r (%s, %s)%s"):format(book, GOLD, d.boss, d.dungeon, d.lv or "?", more),
        go = at and { name = d.dungeon .. " entrance", map = at[1], x = at[2], y = at[3] } or nil, drops = drops }
end

-- this profession has camp items (WoW Forever)
function C:Has(profName) return #self:Items(profName) > 0 end

----------------------------------------------------------------------
-- The Camping tab: the campfire burning in the middle with its levels under it, every profession's
-- camp item around it (its icon when you have it: you know the recipe or carry the item; grey when
-- you don't), with its level 2 and 3 under it. Hover anything for what it takes and where it comes
-- from; click a boss drop for the way to the dungeon.
----------------------------------------------------------------------
local RING = { "First Aid", "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Fishing",
    "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring", "Cooking" }
C.RING = RING

local function tierOf(e) return (e.learn >= 300 and 3) or (e.learn >= 140 and 2) or 1 end
C.TierOf = tierOf

-- the game itself: do you know any spell with this camp recipe's name (CampSpells.lua)? Right after
-- learning one, before the profession window was opened again (the user learned Fishing Rack, the
-- tab stayed grey: the recipe list is only read when that window opens)
local function knowsSpell(name)
    for _, id in ipairs(ns.CampSpells and ns.CampSpells[name] or {}) do
        -- C_SpellBook.IsSpellKnown: IsPlayerSpell is only a wrapper in Blizzard's deprecated layer,
        -- gone when loadDeprecationFallbacks is off (Codex release review)
        local known = (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
            or (IsPlayerSpell and IsPlayerSpell(id))
        if known then return true end
    end
    return false
end

local function has(profName, e)
    if known(profName, e.name) or knowsSpell(e.name) then return true end
    return (e.made and e.made > 0 and (GetItemCount(e.made, true) or 0) > 0) and true or false
end
C.HasItem = has

local function go(t)
    if not (t and t.map) then return end
    if VoidProf.Knowledge and VoidProf.Knowledge.Waypoint then
        VoidProf.Knowledge:Waypoint({ map = t.map, x = t.x * 100, y = t.y * 100, name = t.name })
    end
end

local function icon(e)
    local id = e.made and e.made > 0 and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.made)
    return id or 134400   -- the question mark
end

-- the tooltip of one camp item
local function tip(self, tries)
    local e, prof = self.e, self.prof
    if not e then return end
    missingNames = 0
    local mine = VoidProf.SkillCap and VoidProf.SkillCap:Professions()[prof]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("%s  |cffaaaaaa(level %d)|r"):format(e.name, self.level or tierOf(e)), 1, 1, 1)
    GameTooltip:AddLine(("%s%s"):format(prof, e.learn > 0 and (" " .. e.learn) or ""), 1, 0.82, 0)
    if has(prof, e) then
        GameTooltip:AddLine("You have it.", 0.3, 1, 0.3)
    elseif not mine then
        GameTooltip:AddLine(("Made by %s: you don't have it (another player's camp can)."):format(prof), 1, 0.6, 0.4, true)
    elseif e.learn > (mine.rank or 0) then
        GameTooltip:AddLine(("Needs %s %d (you have %d)."):format(prof, e.learn, mine.rank or 0), 1, 0.5, 0.5)
    end
    local mats = {}
    for _, m in ipairs(e.mats) do mats[#mats + 1] = m[2] .. "x " .. itemName(m[1]) end
    if #mats > 0 then GameTooltip:AddLine("Takes: " .. table.concat(mats, ", "), 0.85, 0.85, 0.9, true) end
    local src = C:Source(prof, e)
    GameTooltip:AddLine(src.text, 0.85, 0.85, 0.9, true)
    for i, d in ipairs(src.drops or {}) do
        if i > 1 and i <= 4 then
            GameTooltip:AddLine(("also %s, %s (%s)"):format(d.boss, d.dungeon, d.lv or "?"), 0.7, 0.7, 0.75)
        end
    end
    if src.go then GameTooltip:AddLine("Click: waypoint to the dungeon entrance", 0.6, 0.8, 1) end
    GameTooltip:Show()
    -- names still loading: draw it again in a moment, while the mouse is still on it (a few tries)
    tries = tonumber(tries) or 0
    if missingNames > 0 and tries < 5 then
        C_Timer.After(0.25, function()
            if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then tip(self, tries + 1) end
        end)
    end
end

local function onClick(self)
    if not self.e then return end
    local src = C:Source(self.prof, self.e)
    if src.go then go(src.go) end
end

-- an item button: round icon, grey when you don't have it
local function iconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    t:AddMaskTexture(mask)
    b.tex = t
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    hl:SetVertexColor(1, 1, 1, 0.25)
    b:SetScript("OnEnter", tip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", onClick)
    return b
end

local function paint(b, prof, e, level)
    b.e, b.prof, b.level = e, prof, level
    if not e then b:Hide(); return end
    b.tex:SetTexture(icon(e))
    local got = has(prof, e)
    b.tex:SetDesaturated(not got)
    local v = got and 1 or 0.5
    b.tex:SetVertexColor(v, v, v)
    b:Show()
end

-- the moving fire: Blizzard's flame flipbook when this client has it, else a flickering flame icon;
-- a warm glow breathing under it either way
local function makeFire(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(90, 120)
    local glow = f:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Cooldown\\star4")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.55, 0.15, 0.9)
    glow:SetSize(150, 150)
    glow:SetPoint("BOTTOM", 0, -40)
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0.5); a:SetToAlpha(1); a:SetDuration(0.7); a:SetSmoothing("IN_OUT")
    ag:Play()
    local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Fyrakk_Flame_FX")
    -- two flames, the inner one hotter and a little faster, so it doesn't loop as one shape. The
    -- atlas is a purple shadowflame (seen in game 2026-11-15): drained of color and tinted fire orange.
    local function flame(w, h, r, g, b, secs, y)
        local t = f:CreateTexture(nil, "ARTWORK")
        local fg = t:CreateAnimationGroup()
        if hasAtlas then
            t:SetAtlas("Fyrakk_Flame_FX")
            t:SetDesaturated(true)
            t:SetSize(w, h)
            fg:SetLooping("REPEAT")
            local fb = fg:CreateAnimation("FlipBook")
            fb:SetFlipBookRows(8); fb:SetFlipBookColumns(6); fb:SetFlipBookFrames(44); fb:SetDuration(secs)
        else
            t:SetTexture(135808)   -- spell_fire_fire
            t:SetSize(w * 0.8, w * 0.8)
            fg:SetLooping("BOUNCE")
            local s = fg:CreateAnimation("Scale")
            s:SetScaleFrom(0.92, 0.9); s:SetScaleTo(1.06, 1.12); s:SetDuration(secs / 3); s:SetOrigin("BOTTOM", 0, 0)
        end
        t:SetBlendMode("ADD")
        t:SetVertexColor(r, g, b)
        t:SetPoint("BOTTOM", 0, y)
        fg:Play()
        return t
    end
    flame(84, 138, 1, 0.45, 0.08, 1.33, -14)
    flame(54, 90, 1, 0.8, 0.35, 1.05, -10)
    -- embers: little sparks rising off the fire and fading, each on its own timing
    for i = 1, 7 do
        local e = f:CreateTexture(nil, "OVERLAY")
        e:SetTexture("Interface\\Cooldown\\star4")
        e:SetBlendMode("ADD")
        e:SetVertexColor(1, 0.6 + (i % 3) * 0.1, 0.2)
        e:SetSize(7, 7)
        e:SetPoint("BOTTOM", (i - 4) * 6, 20)
        e:SetAlpha(0)
        local eg = e:CreateAnimationGroup()
        eg:SetLooping("REPEAT")
        local up = eg:CreateAnimation("Translation")
        up:SetOffset(((i % 2 == 0) and 1 or -1) * (6 + i * 2), 70 + i * 7)
        up:SetDuration(1.6 + (i % 4) * 0.35)
        up:SetStartDelay(i * 0.27)
        local fadeIn = eg:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.25); fadeIn:SetStartDelay(i * 0.27)
        local fadeOut = eg:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(1.2 + (i % 4) * 0.3); fadeOut:SetStartDelay(i * 0.27 + 0.4)
        eg:Play()
    end
    f.flipbook = hasAtlas and true or false
    return f
end

local tab   -- the built tab

-- one slot around the fire: a profession's first camp item, its name, its level 2 and 3 under it
local function makeSlot(canvas, x, y)
    local s = CreateFrame("Frame", nil, canvas)
    s:SetSize(86, 62)
    s:SetPoint("CENTER", canvas, "TOPLEFT", x, y)
    local b = iconButton(s, 30)
    b:SetPoint("TOP", 0, 0)
    local name = s:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(name, 9, "")
    name:SetPoint("TOP", b, "BOTTOM", 0, -2)
    name:SetWidth(86)
    name:SetWordWrap(false)
    local t2, t3 = iconButton(s, 16), iconButton(s, 16)
    t2:SetPoint("TOPRIGHT", name, "BOTTOM", -2, -2)
    t3:SetPoint("TOPLEFT", name, "BOTTOM", 2, -2)
    return { frame = s, main = b, name = name, t2 = t2, t3 = t3 }
end

function C:BuildTab(parent)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas:SetAllPoints()
    local cx, cy = 270, -186   -- the campfire, in the middle of the 540 x 394 tab
    local base = iconButton(canvas, 44)
    base:SetPoint("CENTER", canvas, "TOPLEFT", cx, cy)
    -- the flames burn on the campfire's icon (it shows through at the bottom), above it in the frame
    -- order but not catching the mouse, so the icon still shows its tooltip
    local fire = makeFire(canvas)
    fire:SetPoint("BOTTOM", base, "CENTER", 0, -6)
    fire:SetFrameLevel(base:GetFrameLevel() + 3)
    local label = canvas:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(label, 10, "OUTLINE")
    label:SetPoint("TOP", base, "BOTTOM", 0, -3)
    local l2, l3 = iconButton(canvas, 22), iconButton(canvas, 22)
    l2:SetPoint("TOPRIGHT", label, "BOTTOM", -3, -3)
    l3:SetPoint("TOPLEFT", label, "BOTTOM", 3, -3)
    local slots = {}
    for i, prof in ipairs(RING) do
        local ang = (i - 1) / #RING * 2 * math.pi - math.pi / 2   -- from the top, clockwise
        -- (y grows upward from TOPLEFT: minus, so the first one is at the top and they go clockwise)
        slots[prof] = makeSlot(canvas, cx + 218 * math.cos(ang), (cy + 5) - 145 * math.sin(ang))
    end
    local hint = canvas:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(hint, 9, "")
    hint:SetPoint("BOTTOM", canvas, "BOTTOM", 0, 2)
    hint:SetTextColor(0.55, 0.55, 0.6)
    hint:SetText("Grey: you don't have it yet. Under each: its level 2 and 3. Hover for what it takes; click a boss drop for the way.")
    tab = { canvas = canvas, fire = fire, base = base, label = label, l2 = l2, l3 = l3, slots = slots }
    parent._camping = tab
end

function C:RefreshTab()
    if not tab then return end
    -- ask the game for every name the tooltips will show, so they're there by the time you hover
    if not tab.preloaded then
        tab.preloaded = true
        for prof in pairs(LINE) do
            for _, e in ipairs(self:Items(prof)) do
                preload(e.made); preload(e.book)
                for _, m in ipairs(e.mats) do preload(m[1]) end
            end
        end
    end
    -- the campfire: Cooking's Basic / Journeyman / Expert Campfire
    local fires, other = {}, {}
    for _, e in ipairs(self:Items("Cooking")) do
        if e.name:find("Campfire", 1, true) then fires[#fires + 1] = e else other[#other + 1] = e end
    end
    paint(tab.base, "Cooking", fires[1], 1)
    paint(tab.l2, "Cooking", fires[2], 2)
    paint(tab.l3, "Cooking", fires[3], 3)
    local lit = fires[1] and has("Cooking", fires[1])
    tab.label:SetText(("|cff%s%s|r  |cffaaaaaalevel 1|r"):format(lit and "ffd200" or "9a9aa6", fires[1] and fires[1].name or "Campfire"))
    for prof, s in pairs(tab.slots) do
        local items = prof == "Cooking" and other or self:Items(prof)
        local byTier = {}
        for _, e in ipairs(items) do
            local t = tierOf(e)
            byTier[t] = byTier[t] or e
        end
        -- the big icon: its level 1 (Cooking has none besides the campfires: its lowest)
        local first = byTier[1] or items[1]
        local firstLevel = first and tierOf(first) or 1
        paint(s.main, prof, first, firstLevel)
        paint(s.t2, prof, firstLevel < 2 and byTier[2] or nil, 2)
        paint(s.t3, prof, firstLevel < 3 and byTier[3] or nil, 3)
        local got = first and has(prof, first)
        s.name:SetText(("|cff%s%s|r"):format(got and "ffffff" or "8a8a94", first and first.name or prof))
    end
end

-- the Camping button in a profession tab: the Camping tab
function C:Toggle()
    if VoidProf.UI and VoidProf.UI.ShowTab then VoidProf.UI:ShowTab("Camping") end
end

-- A camp recipe learned (a recipe item used, a trainer): into VoidProf's recipe list for its
-- profession and the tab redrawn, so it lights up at once. Both events, when this client has them.
local learnFrame = CreateFrame("Frame")
for _, ev in ipairs({ "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_SKILL_LINE" }) do pcall(learnFrame.RegisterEvent, learnFrame, ev) end
learnFrame:SetScript("OnEvent", function(_, _, id)
    local name = type(id) == "number" and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not (name and ns.CampSpells and ns.CampSpells[name]) then return end
    for prof in pairs(LINE) do
        for _, e in ipairs(C:Items(prof)) do
            if e.name == name then
                local cache = VoidProf.ProfCache and VoidProf:ProfCache()
                local c = cache and cache[prof]
                if c and c.recipes and not c.recipes[id] then c.recipes[id] = { id = id, name = name } end
            end
        end
    end
    if tab and tab.canvas:IsVisible() then C:RefreshTab() end
end)
