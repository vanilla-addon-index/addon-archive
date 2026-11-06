-- shapes.lua - Minimap shape masks for SexyMap OctoWoW Edition
-- Provides CApplyShape() which clips the minimap to a given shape
--
-- Uses Minimap:SetMaskTexture() to clip the minimap to a given shape.
-- The "Square" shape uses the WoW built-in WHITE8X8 texture which removes
-- the circular mask entirely, showing a true square minimap.
-- For other shapes, addon-local BLP mask textures are used.

local _G = getfenv(0)

-- Shape texture paths
-- For addon-local BLP files, do NOT include .blp extension - WoW's SetMaskTexture
-- auto-appends it (same as SetTexture). For built-in WoW textures, use full paths.
local shapeTextures = {
	["Round"]            = "Interface\\AddOns\\SexyMap\\shapes\\circle",
	["Square"]           = "Interface\\BUTTONS\\WHITE8X8",
	["Diamond"]          = "Interface\\AddOns\\SexyMap\\shapes\\diamond",
	["Hexagon"]          = "Interface\\AddOns\\SexyMap\\shapes\\hexagon",
	["Octagon"]          = "Interface\\AddOns\\SexyMap\\shapes\\octagon",
	["Heart"]            = "Interface\\AddOns\\SexyMap\\shapes\\heart",
	["Snowflake"]        = "Interface\\AddOns\\SexyMap\\shapes\\snowflake",
	["LL Corner Rounded"] = "Interface\\AddOns\\SexyMap\\shapes\\topright",
	["LR Corner Rounded"] = "Interface\\AddOns\\SexyMap\\shapes\\topleft",
	["UL Corner Rounded"] = "Interface\\AddOns\\SexyMap\\shapes\\bottomright",
	["UR Corner Rounded"] = "Interface\\AddOns\\SexyMap\\shapes\\bottomleft",
	["Large Circle"]     = "Interface\\AddOns\\SexyMap\\shapes\\largecircle",
	["Route66"]          = "Interface\\AddOns\\SexyMap\\shapes\\route66",
	["Deathsky"]         = "Interface\\AddOns\\SexyMap\\shapes\\deathsky_mask",
	["VFX Border"]       = "Interface\\AddOns\\SexyMap\\shapes\\t_vfx_border",
	["Left"]             = "Interface\\AddOns\\SexyMap\\shapes\\left",
	["Bottom"]           = "Interface\\AddOns\\SexyMap\\shapes\\bottom",
	["Right"]            = "Interface\\AddOns\\SexyMap\\shapes\\right",
	["Top"]              = "Interface\\AddOns\\SexyMap\\shapes\\top",
}

-- Shape names for the options UI (must match keys in shapeTextures)
shapeNames = {
	"Round", "Square", "Diamond", "Hexagon", "Octagon", "Heart", "Snowflake",
	"LL Corner Rounded", "LR Corner Rounded", "UL Corner Rounded", "UR Corner Rounded",
	"Large Circle", "Route66", "Deathsky", "VFX Border",
}

-- The default round minimap mask
local DEFAULT_MASK = "Interface\\AddOns\\SexyMap\\shapes\\circle"

function CApplyShape(shapeName)
	if not shapeName then return end

	local texPath = shapeTextures[shapeName]

	if not texPath then
		-- Unknown shape: apply default round mask
		Minimap:SetMaskTexture(DEFAULT_MASK)
		return
	end

	-- Apply the mask texture. pcall protects against invalid texture paths.
	local ok, err = pcall(function()
		Minimap:SetMaskTexture(texPath)
	end)
	if not ok then
		-- Fallback to default round mask if the texture failed to load
		Minimap:SetMaskTexture(DEFAULT_MASK)
	end
end
