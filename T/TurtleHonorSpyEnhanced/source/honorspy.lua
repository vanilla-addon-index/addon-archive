-- TurtleHonorSpyEnhanced: core addon setup
-- Slash commands are in commands.lua; minimap button is in minimap.lua.

THSE = {
	addonUsers   = {},
	versionDebug = false,
}

function THSE.GetDB()
	return HonorSpy and HonorSpy.db and HonorSpy.db.realm and HonorSpy.db.realm.hs
end

-- ===== Shared BG data (used by overlay + honorhistory) =====
THSE.BG_MARK_ICON = {
	["Warsong Gulch"] = "Interface\\Icons\\INV_Misc_Rune_07",
	["Arathi Basin"]  = "Interface\\Icons\\INV_Jewelry_Amulet_07",
	["Alterac Valley"]= "Interface\\Icons\\INV_Jewelry_Necklace_21",
	["Thorn Gorge"]   = "Interface\\Icons\\INV_Jewelry_Talisman_04",
	["Blood Ring"]    = "Interface\\Icons\\INV_Jewelry_Talisman_05",
}

THSE.ZONE_ABBR = {
	["Warsong Gulch"] = "WSG",
	["Arathi Basin"]  = "AB",
	["Alterac Valley"]= "AV",
	["Thorn Gorge"]   = "Thorn",
	["Blood Ring"]    = "Blood",
}

-- Daily BG rotation (5-day cycle). Anchor: 2026-03-22 = index 0 (WSG).
local _DAILY_BG_CYCLE = {
	[0] = "Warsong Gulch",
	[1] = "Arathi Basin",
	[2] = "Blood Ring",
	[3] = "Thorn Gorge",
	[4] = "Alterac Valley",
}
local _DAILY_BG_ANCHOR = 20534  -- floor(time({2026,3,22,0,0,0}) / 86400) in UTC days

function THSE.GetDailyBG(timestamp)
	local utcDay = math.floor(timestamp / 86400)
	local diff = utcDay - _DAILY_BG_ANCHOR
	local idx = math.mod(diff, 5)
	if idx < 0 then idx = idx + 5 end
	return _DAILY_BG_CYCLE[idx]
end

HonorSpy = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0")

HonorSpy:RegisterDB("HonorSpyDB")
HonorSpy:RegisterDefaults('realm', {
	hs = {
		overlayPos          = nil,
		overlayHidden       = false,
		minimapAngle        = 200,
		minimapHidden       = false,
		addonUsers          = {},
		weeklyStartProgress = nil,
		weeklyResetStamp    = 0,
		weekApiHonor        = {},
		sessionStartHonor   = 0,
		honorHistory        = {},
		histCollapsed       = {},
		histCompactMode     = 0,
		histHideZero        = false,
		histDayCollapsed    = {},
		histWeekCollapsed   = {},
	}
})

function HonorSpy:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function HonorSpy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	-- Minimap button creation is handled by minimap.lua
end