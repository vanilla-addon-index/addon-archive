-- TurtleColorPicker - Standalone HSV Color Picker Library
-- Version 1.0.0 | WoW 1.12 / Lua 5.0

TurtleColorPicker = {}
TurtleColorPicker.version = "1.0.0"
TurtleColorPicker._session = nil

-- Pre-create UI namespace (UI.lua populates it)
TurtleColorPicker_UI = {}

-- ============================================================
-- MATH UTILITIES
-- ============================================================

local function Clamp(val, minV, maxV)
    if val < minV then return minV end
    if val > maxV then return maxV end
    return val
end

-- HSV to RGB (all values 0-1, h wraps at 1)
local function HSVtoRGB(h, s, v)
    if s == 0 then return v, v, v end
    if h >= 1 then h = 0 end

    local hSector = h * 6
    local sextant = math.floor(hSector)
    local f = hSector - sextant
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))

    if sextant == 0 then return v, t, p
    elseif sextant == 1 then return q, v, p
    elseif sextant == 2 then return p, v, t
    elseif sextant == 3 then return p, q, v
    elseif sextant == 4 then return t, p, v
    else return v, p, q end
end

-- RGB to HSV (all values 0-1)
local function RGBtoHSV(r, g, b)
    local maxC = math.max(r, g, b)
    local minC = math.min(r, g, b)
    local delta = maxC - minC
    local h, s, vl

    vl = maxC
    if maxC == 0 then
        return 0, 0, 0
    end

    s = delta / maxC
    if delta == 0 then
        return 0, s, vl
    end

    if maxC == r then
        h = (g - b) / delta
        if h < 0 then h = h + 6 end
    elseif maxC == g then
        h = 2 + (b - r) / delta
    else
        h = 4 + (r - g) / delta
    end
    h = h / 6

    return h, s, vl
end

-- RGB (0-1) to Hex string "RRGGBB"
local function RGBtoHex(r, g, b)
    local ri = math.floor(r * 255 + 0.5)
    local gi = math.floor(g * 255 + 0.5)
    local bi = math.floor(b * 255 + 0.5)
    return string.format("%02X%02X%02X", ri, gi, bi)
end

-- Hex string "RRGGBB" to RGB (0-1), returns nil on invalid
local function HexToRGB(hex)
    hex = string.gsub(hex, "^#", "")
    if string.len(hex) ~= 6 then return nil, nil, nil end
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if not r or not g or not b then return nil, nil, nil end
    return r / 255, g / 255, b / 255
end

-- Expose utilities for other addons
TurtleColorPicker.HSVtoRGB = HSVtoRGB
TurtleColorPicker.RGBtoHSV = RGBtoHSV
TurtleColorPicker.RGBtoHex = RGBtoHex
TurtleColorPicker.HexToRGB = HexToRGB
TurtleColorPicker.Clamp = Clamp

-- ============================================================
-- PUBLIC API
-- ============================================================

function TurtleColorPicker:Open(opts)
    opts = opts or {}

    local ir = 1
    local ig = 1
    local ib = 1
    if opts.color then
        ir = opts.color.r or 1
        ig = opts.color.g or 1
        ib = opts.color.b or 1
    end

    local h, s, v = RGBtoHSV(ir, ig, ib)

    self._session = {
        h = h,
        s = s,
        v = v,
        origR = ir,
        origG = ig,
        origB = ib,
        hasHexInput = opts.hasHexInput or false,
        anchorFrame = opts.anchorFrame or nil,
        onChange = opts.onChange,
        onOk = opts.onOk,
        onCancel = opts.onCancel,
        _confirmed = false,
    }

    if not TurtleColorPicker_UI.Show then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[TCP] ERROR: UI.lua failed to load. Check for Lua errors at login.|r")
        return
    end
    TurtleColorPicker_UI:Show(self._session)
end

function TurtleColorPicker:Close()
    if TurtleColorPicker_UI.Hide then
        TurtleColorPicker_UI:Hide()
    end
end

function TurtleColorPicker:_NotifyChange()
    local s = self._session
    if not s then return end
    if s.onChange then
        local r, g, b = HSVtoRGB(s.h, s.s, s.v)
        s.onChange(r, g, b)
    end
end

function TurtleColorPicker:_NotifyOk()
    local s = self._session
    if not s then return end
    s._confirmed = true
    if s.onOk then
        local r, g, b = HSVtoRGB(s.h, s.s, s.v)
        s.onOk(r, g, b)
    end
    self:Close()
end

function TurtleColorPicker:_NotifyCancel()
    local s = self._session
    if not s then return end
    if s._confirmed then return end
    s._confirmed = true
    if s.onCancel then
        s.onCancel()
    end
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

SLASH_TURTLECOLORPICKER1 = "/tcp"
SLASH_TURTLECOLORPICKER2 = "/turtlecolor"
SlashCmdList["TURTLECOLORPICKER"] = function(msg)
    if msg == "test" then
        TurtleColorPicker:Open({
            color = {r = 0.4, g = 0.6, b = 0.85},
            hasHexInput = true,
            onOk = function(r, g, b)
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cff00ff00[TCP]|r OK: #%s", RGBtoHex(r, g, b))
                )
            end,
            onCancel = function()
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TCP]|r Cancelled.")
            end,
        })
    elseif msg == "minimal" then
        TurtleColorPicker:Open({
            color = {r = 0, g = 0.5, b = 1},
            onOk = function(r, g, b)
                DEFAULT_CHAT_FRAME:AddMessage(
                    string.format("|cff00ff00[TCP]|r OK: #%s", RGBtoHex(r, g, b))
                )
            end,
        })
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtleColorPicker]|r v" .. TurtleColorPicker.version)
        DEFAULT_CHAT_FRAME:AddMessage("  /tcp test    -- Full test (with hex input)")
        DEFAULT_CHAT_FRAME:AddMessage("  /tcp minimal -- Minimal test (color only)")
    end
end
