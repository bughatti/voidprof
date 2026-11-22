----------------------------------------------------------------------
-- Drops.lua — WoW Forever only: crafting orders and mage scrolls, explained when they drop.
--
-- The user, 2026-11-21: "in my bag i have writs to turn stuff in and also scrolls, i want to find a
-- better way to show more data on those drops when they happen" (picked: a card when it drops AND
-- the same lines on the tooltip).
--   * Craftsman's Writ: X   a daily crafting order: deliver X for a Coin Pouch + your faction's trade
--                           reputation. Card/tooltip: the item asked for, its profession and whether
--                           you know the recipe, buy vs materials (VoidAH prices), the pay, done today.
--   * Sealed <Tier>'s Writ  an envelope: opens into a random order of that tier.
--   * Scroll: UPDOG ...     mage only (the Comprehension skill). Not a mage: what it fetches.
-- Data: ForeverWrits.lua (tools/cmd/forever-writs) + ForeverRecipes.lua. Tooltip: at most 3 lines.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end

local _, ns = ...
VoidProf = VoidProf or {}
local D = {}
VoidProf.Drops = D

local TAG = "|cff00c7ffVoidProf|r "
local DIM, GOOD, BAD, GOLD = "|cffaaaaaa", "|cff33ff33", "|cffff6060", "|cffffd200"
local SHOW_FOR = 12        -- seconds the card stays before it fades (hovering holds it)
local PROF = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
               [185] = "Cooking", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting" }

local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end

local function readable(v)
    if canaccessvalue then return canaccessvalue(v) end
    return not (issecretvalue and issecretvalue(v))
end

local function itemName(id)
    if not id or id == 0 then return nil end
    local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not n and C_Item and C_Item.GetItemInfo then n = C_Item.GetItemInfo(id) end
    if not n and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return n
end

local function money(c)
    if not c or c <= 0 then return nil end
    c = math.floor(c + 0.5)
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    if g > 0 then return ("%dg %02ds"):format(g, s) end
    if s > 0 then return k > 0 and ("%ds %dc"):format(s, k) or ("%ds"):format(s) end
    return ("%dc"):format(k)
end

-- VoidAH's price (the Auction House, else a merchant's), or nil
local function price(id)
    if not (id and id > 0 and VoidAH_Price) then return nil end
    local ok, p, src = pcall(VoidAH_Price, id)
    if ok and type(p) == "number" and p > 0 then return p, src end
    return nil
end

-- crafted item -> its recipe row { prof, name, crafted, learn, recipeItem, category, reagent, n, ... }
local byCrafted
local function recipeFor(item)
    if not byCrafted then
        byCrafted = {}
        for _, r in ipairs(ns.ForeverRecipes or {}) do
            if r[3] and r[3] ~= 0 and not byCrafted[r[3]] then byCrafted[r[3]] = r end
        end
    end
    return byCrafted[item]
end

-- materials cost from VoidAH prices; nil if any material has no price
local function matsCost(r)
    if not r then return nil end
    local total = 0
    for k = 7, #r, 2 do
        local p = price(r[k])
        if not p then return nil end
        total = total + p * (r[k + 1] or 1)
    end
    return total > 0 and total or nil
end

-- your rank in that profession (nil = you don't have it) and whether you know the recipe
-- (nil = VoidProf hasn't seen your profession window yet)
local function you(profName, recipeName)
    local P = VoidProf.SkillCap and VoidProf.SkillCap:Professions() or {}
    local p = profName and P[profName]
    if not p then return nil end
    local c = VoidProf.ProfCache and VoidProf:ProfCache()[profName]
    if not (c and c.recipes) then return p.rank, nil end
    for _, rc in pairs(c.recipes) do
        if rc.name == recipeName then return p.rank, true end
    end
    return p.rank, false
end

local function doneToday(q)
    local f = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    return f and q and f(q) or false
end

local function inLog(q)
    local f = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
    return f and q and f(q) ~= nil or false
end

----------------------------------------------------------------------
-- What to say about one item: { title, lines } or nil
----------------------------------------------------------------------
function D:Info(itemID, tooltip)   -- tooltip: VoidAH's own line already prices the item itself
    local W = ns.Writs and ns.Writs[itemID]
    if W then
        local q, crafted, line, rep = W[1], W[2], W[3], W[4]
        local writName = itemName(itemID)
        local want = itemName(crafted) or (writName and writName:gsub("^Craftsman's Writ: ", "")) or "the item"
        local r = recipeFor(crafted)
        local profName = PROF[line] or (r and PROF[r[1]])
        local lines = {}
        -- 1. what it asks for, and you
        local who = ""
        if profName then
            local rank, knows = you(profName, r and r[2] or want)
            if knows then who = " · " .. GOOD .. "you know it|r"
            elseif knows == false then
                who = " · " .. DIM .. ((r and r[4] > 0) and ("recipe not known (learn at %d)"):format(r[4]) or "recipe not known") .. "|r"
            elseif rank then who = " · " .. DIM .. "open " .. profName .. " once|r"
            end
        end
        lines[1] = ("Wants |cffffffff%s|r%s%s"):format(want, profName and (" (" .. profName .. ")") or "", who)
        -- 2. buy it vs make it
        local buy, mats = price(crafted), matsCost(r)
        if buy or mats then
            local t = {}
            if buy then t[#t + 1] = "buy " .. money(buy) end
            if mats then t[#t + 1] = "materials " .. money(mats) end
            lines[#lines + 1] = table.concat(t, " · ")
        end
        -- 3. the pay, and today
        local pay = ("Pays a Coin Pouch%s · daily"):format(rep > 0 and (" + " .. rep .. " trade rep") or "")
        if doneToday(q) then pay = pay .. " · " .. BAD .. "done today|r"
        elseif inLog(q) then pay = pay .. " · " .. GOLD .. "in your quest log|r" end
        local sells = not (tooltip and VoidAH_Price) and price(itemID)
        if sells then pay = pay .. " · the writ sells for " .. money(sells) end
        lines[#lines + 1] = pay
        return { kind = "writ", lines = lines }
    end
    local tier = ns.SealedWrits and ns.SealedWrits[itemID]
    if tier then
        -- the order inside is random until it's opened (the user, 2026-11-21: "i dont think you can read it before its
        -- opened"), so the one real choice now: open it, or sell it sealed (Sealed Expert's Writ: ~22s, 521 listed)
        local lines = { ("Open it: a random %s crafting order (pays a Coin Pouch + trade rep)"):format(tier) }
        local p, src = price(itemID)
        if p and src == "ah" then lines[2] = "Or sell it sealed: " .. money(p) .. " on the Auction House" end
        return { kind = "sealed", lines = lines }
    end
    local need = ns.MageScrolls and ns.MageScrolls[itemID]
    if need then
        local _, class = UnitClass("player")
        if class == "MAGE" then
            return { kind = "scroll", lines = { ("Read it with Comprehension %d"):format(need) } }
        end
        local p, src = price(itemID)
        local v = p and (src == "ah" and ("Auction House " .. money(p)) or ("vendor " .. money(p)))
        if not v and C_Item and C_Item.GetItemInfo then
            local sell = select(11, C_Item.GetItemInfo(itemID))
            if type(sell) == "number" and sell > 0 then v = "vendor " .. money(sell) end
        end
        return { kind = "scroll", lines = { ("Mage only (Comprehension %d)%s"):format(need, v and (" · " .. v) or " · sell it or mail it to a mage") } }
    end
    return nil
end

----------------------------------------------------------------------
-- Tooltip: the same lines (max 3)
----------------------------------------------------------------------
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if (tt ~= GameTooltip and tt ~= ItemRefTooltip) or type(data) ~= "table" then return end
        local id = data.id
        if not (id and readable(id)) then return end
        local ok, info = pcall(D.Info, D, id, true)
        if not (ok and info) then return end
        -- a mage scroll or a sealed envelope: the game's own lines (Classes: Mage, Requires Comprehension, "Use: Tear
        -- open...") and VoidAH's price already say it all (seen in game 11-21); only the drop card tells those
        if info.kind ~= "writ" then return end
        for i = 1, math.min(3, #info.lines) do tt:AddLine(TAG .. info.lines[i], 0.88, 0.88, 0.9, true) end
        tt:Show()
    end)
end

----------------------------------------------------------------------
-- The drop card
----------------------------------------------------------------------
local card

local function pixelBox(f)
    local px = VoidPX() * 1.01
    local function tex(layer)
        local t = f:CreateTexture(nil, layer, nil, -8)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(true) end
        return t
    end
    local bg = tex("BACKGROUND")
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", px, -px)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -px, px)
    bg:SetVertexColor(0.05, 0.05, 0.07, 0.96)
    local P = VoidUI and VoidUI.palette
    local a = P and P.accent or { 0, 0.78, 1 }
    local function edge(p1, p2, x1, y1, x2, y2)
        local t = tex("BORDER")
        t:SetPoint("TOPLEFT", f, p1, x1, y1); t:SetPoint("BOTTOMRIGHT", f, p2, x2, y2)
        t:SetVertexColor(a[1], a[2], a[3], 0.8)
    end
    edge("TOPLEFT", "TOPRIGHT", 0, 0, 0, -px)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", 0, px, 0, 0)
    edge("TOPLEFT", "BOTTOMLEFT", 0, -px, px, px)
    edge("TOPRIGHT", "BOTTOMRIGHT", -px, -px, 0, px)
end

local function font(fs, size, flags)
    if VoidUI and VoidUI.SetFont then VoidUI:SetFont(fs, size, flags or "") else fs:SetFontObject(GameFontHighlightSmall) end
end

local function build()
    local f = CreateFrame("Frame", "VoidProfDropCard", UIParent)
    f:SetSize(340, 60)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -380, 320)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    pixelBox(f)
    ns.Move(f, { db = function() return VoidProfDB end, key = "dropCard" })   -- drag + kept after a restart (VoidMove.lua)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 8, -8)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon
    local hit = CreateFrame("Frame", nil, f)
    hit:SetAllPoints(icon)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        if not f.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(f.itemID)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY")
    font(title, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    title:SetPoint("RIGHT", -24, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    f.title = title

    local body = f:CreateFontString(nil, "OVERLAY")
    font(body, 10)
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    body:SetPoint("RIGHT", -10, 0)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetSpacing(2)
    body:SetTextColor(0.88, 0.88, 0.9)
    f.body = body

    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY")
    font(x, 13)
    x:SetPoint("CENTER")
    x:SetText("|cffcc4444x|r")
    close:SetScript("OnClick", function() f:Hide() end)

    -- stays while the mouse is on it; fades SHOW_FOR seconds after it showed / the mouse left
    local left = 0
    f:SetScript("OnUpdate", function(self, el)
        if self:IsMouseOver() then left = SHOW_FOR; self:SetAlpha(1); return end
        left = left - el
        if left <= 0 then self:Hide()
        elseif left < 1.5 then self:SetAlpha(left / 1.5) end
    end)
    f:SetScript("OnShow", function(self) left = SHOW_FOR; self:SetAlpha(1) end)
    f.Restart = function() left = SHOW_FOR; f:SetAlpha(1) end
    f:Hide()
    return f
end

local lastShown, lastShownAt = nil, 0   -- the last card shown, so the bag check below doesn't repeat it
-- item ids whose names hadn't loaded when the card was painted: repaint once each arrives
local waitFor = {}

-- refresh = repaint the card already showing (a name arrived): the fade timer keeps running
local function paint(itemID, link, refresh)
    local info = D:Info(itemID)
    if not info then return false end
    card = card or build()
    card.itemID, card.link = itemID, link
    wipe(waitFor)
    if not itemName(itemID) then waitFor[itemID] = true end
    local W = ns.Writs and ns.Writs[itemID]
    if W and W[2] ~= 0 and not itemName(W[2]) then waitFor[W[2]] = true end
    local tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    card.icon:SetTexture(tex or 134400)
    card.title:SetText(link or itemName(itemID) or "")
    card.body:SetText(table.concat(info.lines, "\n"))
    card:SetHeight(math.max(44, 8 + 15 + 4 + card.body:GetStringHeight() + 10))
    if refresh then return true end
    lastShown, lastShownAt = itemID, GetTime and GetTime() or 0
    if card:IsShown() then card.Restart() else card:Show() end
    return true
end

function D:Show(itemID, link)   -- also for testing: /run VoidProf.Drops:Show(264105)
    return paint(itemID, link)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event, msg, ...)
    if event == "GET_ITEM_INFO_RECEIVED" then
        local id, success = msg, ...
        if not (id and readable(id) and waitFor[id]) then return end
        waitFor[id] = nil
        if success and card and card:IsShown() then paint(card.itemID, card.link, true) end
        return
    end
    if VoidProfDB and VoidProfDB.dropCard == false then return end
    if not (type(msg) == "string" and readable(msg)) then return end
    local guid = select(11, ...)
    if guid and readable(guid) and guid ~= UnitGUID("player") then return end
    local link = msg:match("|c.-|Hitem:.-|h|r")
    local id = tonumber(msg:match("|Hitem:(%d+)") or "")
    if not id then return end
    if (ns.Writs and ns.Writs[id]) or (ns.SealedWrits and ns.SealedWrits[id]) or (ns.MageScrolls and ns.MageScrolls[id]) then
        paint(id, link)
    end
end)

-- Backstop for step 2 (the user, 2026-11-21: "the writs drops as blue then you click to show the quest"):
-- the blue Sealed X's Writ drops, you open it, it turns into the Craftsman's Writ. If opening it leaves no loot
-- line in chat, the bags still show it: an envelope gone and a writ come in the same update = the order card.
-- Both have to change together, so moving a writ out of the bank doesn't count.
local function count()
    local sealed, writs = 0, {}
    local last = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    for bag = 0, last do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local i = C.GetContainerItemInfo(bag, slot)
            local id = i and i.itemID
            if id and readable(id) then
                if ns.SealedWrits and ns.SealedWrits[id] then sealed = sealed + (i.stackCount or 1)
                elseif ns.Writs and ns.Writs[id] then writs[id] = { n = (writs[id] and writs[id].n or 0) + (i.stackCount or 1), link = i.hyperlink } end
            end
        end
    end
    return sealed, writs
end
local had
local bags = CreateFrame("Frame")
bags:RegisterEvent("PLAYER_ENTERING_WORLD")
bags:RegisterEvent("BAG_UPDATE_DELAYED")
bags:SetScript("OnEvent", function(_, event)
    local sealed, writs = count()
    if not sealed then return end
    local before = had
    had = { sealed = sealed, writs = writs }
    if event ~= "BAG_UPDATE_DELAYED" or not before or sealed >= before.sealed then return end
    if VoidProfDB and VoidProfDB.dropCard == false then return end
    for id, w in pairs(writs) do
        local was = before.writs[id] and before.writs[id].n or 0
        if w.n > was and not (lastShown == id and GetTime() - lastShownAt < 5) then
            paint(id, w.link)
            return
        end
    end
end)
