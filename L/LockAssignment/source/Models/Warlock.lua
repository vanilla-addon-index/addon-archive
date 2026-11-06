-- Model: Warlock identity (name, raid index, addon version). No assignment fields.
---@class Warlock
---@field Name string
---@field RaidIndex number|nil
---@field AddonVersion number

LA = LA or {}
LA.Warlock = LA.Warlock or {}

---@param name string
---@param raidIndex number|nil
---@return Warlock
function LA.Warlock.create(name, raidIndex)
	local addonVersion = (name == UnitName("player")) and (LA.Version or 0) or 0
	return {
		Name = name,
		RaidIndex = raidIndex,
		AddonVersion = addonVersion,
	}
end
