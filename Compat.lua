----------------------------------------------------------------------
-- VoidProf Compat Layer
--
-- Provides VoidUI-compatible namespace so cross-addon helpers (palette,
-- backdrop, font) match the rest of the Void* family.
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

-- Mirror VoidUI palette if not already set by VoidUI/VoidAH/etc.
VoidUI = VoidUI or {}
if not VoidUI.palette then
    VoidUI.palette = {
        accent     = { 0x00 / 255, 0xC7 / 255, 0xFF / 255 },
        accentHex  = "00c7ff",
        text       = { 0xEB / 255, 0xEB / 255, 0xF2 / 255 },
        textDim    = { 0x8C / 255, 0x8C / 255, 0x9E / 255 },
        bg         = { 0.05, 0.05, 0.07, 0.95 },
        border     = { 0x00 / 255, 0xC7 / 255, 0xFF / 255, 0.7 },
    }
end
if not VoidUI.media then
    VoidUI.media = {
        font    = "Fonts\\FRIZQT__.TTF",
        texture = "Interface\\Buttons\\WHITE8X8",
    }
end
if not VoidUI.SetFont then
    function VoidUI:SetFont(fontString, size, flags)
        fontString:SetFont(self.media.font, size or 11, flags or "")
    end
end
if not VoidUI.CreateBackdrop then
    function VoidUI:CreateBackdrop(frame, r, g, b, a, br, bg, bb, ba)
        if not frame.SetBackdrop then
            Mixin(frame, BackdropTemplateMixin)
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
        frame:SetBackdrop({
            bgFile   = self.media.texture,
            edgeFile = self.media.texture,
            edgeSize = VoidPX(),
        })
        frame:SetBackdropColor(r or 0.05, g or 0.05, b or 0.07, a or 0.95)
        frame:SetBackdropBorderColor(br or 0, bg or 0.78, bb or 1, ba or 0.7)
    end
end

function VoidProf:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidProf]|r " .. tostring(msg))
end

function VoidProf:Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidProf]|r |cffff5050" .. tostring(msg) .. "|r")
end
