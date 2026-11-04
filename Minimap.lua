----------------------------------------------------------------------
-- VoidProf Minimap Icon
--
-- Mirrors VoidFisher's exact minimap-button pattern: standalone (no lib),
-- draggable around the minimap edge, position saved per-character in
-- VoidProfCharDB.minimapAngle (degrees).
----------------------------------------------------------------------

VoidProf = VoidProf or {}

local minimapBtn

local function MinimapUpdatePosition(btn)
    VoidProfCharDB = VoidProfCharDB or {}
    local angle = VoidProfCharDB.minimapAngle or 195
    local rad = math.rad(angle)
    -- Scale radius to actual minimap size so the button sits just OUTSIDE
    -- the circular edge regardless of the user's minimap size/scale.
    local radius = (Minimap:GetWidth() / 2) + 6
    local x = radius * math.cos(rad)
    local y = radius * math.sin(rad)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapBtn then return minimapBtn end
    if not Minimap then return nil end

    local btn = CreateFrame("Button", "VoidProfMinimapBtn", Minimap)
    btn:SetSize(28, 28)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    -- Trade_Alchemy: classic profession icon, guaranteed to exist
    icon:SetTexture("Interface\\Icons\\Trade_Alchemy")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn._icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn._border = border

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local cache = VoidProf:ProfCache()
            for prof, data in pairs(cache) do
                VoidProf:Print(string.format("%s: %d recipes, skill %d/%d",
                    prof, data.learnedCount or 0, data.skillRank or 0, data.skillMaxRank or 0))
            end
        else
            if VoidProf.UI and VoidProf.UI.Toggle then VoidProf.UI:Toggle() end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00c7ffVoidProf|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open panel", 1, 1, 1)
        GameTooltip:AddLine("Right-click: dump cache to chat", 1, 1, 1)
        GameTooltip:AddLine("Drag: reposition around minimap", 0.7, 0.7, 0.7)
        local h = VoidProf.Helpers
        if h and h._currentJob then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("|cff00ff00Filleting %d/%d|r",
                h._currentJob.completed or 0, h._currentJob.targetCount or 0), 1, 1, 0)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Drag around the minimap edge
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self) self._dragging = true end)
    btn:SetScript("OnDragStop",  function(self) self._dragging = false end)
    btn:SetScript("OnUpdate", function(self)
        if self._dragging then
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local px, py = GetCursorPosition()
            px = px / scale; py = py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            VoidProfCharDB = VoidProfCharDB or {}
            VoidProfCharDB.minimapAngle = angle
            MinimapUpdatePosition(self)
        end
    end)

    MinimapUpdatePosition(btn)
    minimapBtn = btn
    return btn
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateMinimapButton()
end)

VoidProf.MinimapButton = {
    Show = function() if minimapBtn then minimapBtn:Show() end end,
    Hide = function() if minimapBtn then minimapBtn:Hide() end end,
    Toggle = function() if minimapBtn then if minimapBtn:IsShown() then minimapBtn:Hide() else minimapBtn:Show() end end end,
}
