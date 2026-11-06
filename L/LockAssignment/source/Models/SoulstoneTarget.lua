-- Model: Soulstone target (SS target option). Used for "None" placeholder and raid SS target list.
---@class SoulstoneTarget
---@field Name string
---@field Color string|nil colorStr for class color
---@field Class string|nil display class name

LA = LA or {}
LA.SoulstoneTarget = LA.SoulstoneTarget or {}

---@return SoulstoneTarget
function LA.SoulstoneTarget.none()
	return { Name = "None", Color = nil, Class = nil }
end

---@param name string
---@param colorStr string
---@param displayClass string
---@return SoulstoneTarget
function LA.SoulstoneTarget.create(name, colorStr, displayClass)
	return {
		Name = name,
		Color = colorStr,
		Class = displayClass,
	}
end

-- Backward compatibility: global empty SS target (set after definition so other models can use it)
if not LA.EmptySSTarget then
	LA.EmptySSTarget = LA.SoulstoneTarget.none()
end
