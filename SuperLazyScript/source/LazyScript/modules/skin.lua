-- Skin & theme applier
-- ---

lazyScript = lazyScript or {}
-- Skin is a "doer" function, vs theme is a describing func.
lazyScript.skin = lazyScript.skin or {}

local _G = getfenv(0)
local unpack = unpack

-- Current theme lookup
-- ---

-- Get theme
---@return table
local function getUITheme()
    local theme = lazyScript.theme.themes[lazyScript.theme.active]
    if not theme then error("Unknown active theme") end
    return theme.ui
end

-- Primitives
-- ---

-- Skin frame border
local function skinBorder(frame, colorSet)
    if not frame or not frame.SetBackdropBorderColor or not colorSet then return end
    frame:SetBackdropBorderColor(unpack(colorSet))
end

-- Skin background
local function skinBackground(frame, colorSet)
    if not frame or not frame.SetBackdropColor or not colorSet then return end
    local backdrop = frame:GetBackdrop()
    if not backdrop then return end
    -- build new table
    frame:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = backdrop.edgeFile,
        tile = backdrop.tile,
        tileSize = backdrop.tileSize,
        edgeSize = backdrop.edgeSize,
        insets = backdrop.insets,
    })
    frame:SetBackdropColor(unpack(colorSet))
end

-- Skin texture regions
local function skinRegions(frame, colorSet)
    if not frame or not frame.GetRegions or not colorSet then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region.SetVertexColor then
            region:SetVertexColor(unpack(colorSet))
        end
    end
end

lazyScript.skin.border = skinBorder
lazyScript.skin.background = skinBackground
lazyScript.skin.regions = skinRegions

-- Gets __current theme__ and applies to:
-- -- Background
-- -- Border
-- -- Texture regions

local function applyTheme(frame)
    if not frame then return end
    local UI = getUITheme()
    skinBackground(frame, UI.bg)
    skinBorder(frame, UI.border)
    skinRegions(frame, UI.element)
end

lazyScript.skin.apply = applyTheme

--------------------------------------------------------------------
-- Frame Registry
-- ---

local registry = {}

function lazyScript.skin.register(entry)
    table.insert(registry, entry)
end

-- Grabs tabs of frame
local function applyTabs (entry)
    local base = entry.frame
    if not base or not base.GetName then return end
    local name = base:GetName()
    for i = 1, entry.tabs do
        applyTheme(_G[name .. "Tab" .. i])
    end
end

function lazyScript.skin.refresh()
    for _, entry in ipairs(registry) do
        if type(entry) == "function" then
            entry(getUITheme())
        elseif type(entry) == "table" and entry.frame then
            applyTheme(entry.frame)
            if entry.tabs then applyTabs(entry) end
        else
            applyTheme(entry)
        end
    end
end

-- lazyScript frame registration
-- ---
lazyScript.skin.register(_G.LazyScriptFormEditFrame)
lazyScript.skin.register(_G.LazyScriptFormScrollFrame)
lazyScript.skin.register(_G.LazyScriptFormEditFrameFormName)

lazyScript.skin.register({ frame = _G.LazyScriptFormHelp, tabs = 5})
lazyScript.skin.register({ frame = _G.LazyScriptAboutFrame, tabs = 2})

lazyScript.skin.register(function(UI)
    local minion = _G.LazyScriptMinionFrame
    if minion and minion.SetBackdropColor then
        minion:SetBackdropColor(unpack(UI.minion))
    end
end)

-- Insert Deathstimator shiet

-- Minion Styling
-- ---
local minion = _G.LazyScriptMinionFrame
if minion then
    minion:SetWidth(120)
    minion:SetHeight(40)
    minion:SetBackdrop({
        bgFile = "Interface\\Addons\\LazyScript\\img\\dot.tga",
        tile = false,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
end

-- Disable minion tooltip
lazyScript.minion.OnEnter = function() end
lazyScript.minion.OnLeave = function() end

-- Auto Follow pfUI theme
-- ---


-- Run
-- ---
lazyScript.skin.refresh()