local _G = _G or getfenv(0)
local HealComm = AceLibrary("HealComm-1.0")
local AceEvent = AceLibrary("AceEvent-2.0")
local roster = AceLibrary("RosterLib-2.0")

local frames = {
	["player"] = PlayerFrameHealthBar,
	["target"] = TargetFrameHealthBar,
	["party1"] = PartyMemberFrame1HealthBar,
	["party2"] = PartyMemberFrame2HealthBar,
	["party3"] = PartyMemberFrame3HealthBar,
	["party4"] = PartyMemberFrame4HealthBar,
}

local function CreateHealCommBar(healthBar)
	if not healthBar or healthBar.incHeal then return end
	local parent = healthBar:GetParent()
	healthBar.incHeal = CreateFrame("StatusBar", parent:GetName().."IncHealBar", healthBar)
	healthBar.incHeal:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	healthBar.incHeal:SetStatusBarColor(0, 1, 0, 0.5)
	healthBar.incHeal:SetAllPoints()
	healthBar.incHeal:SetMinMaxValues(healthBar:GetMinMaxValues())
	healthBar.incHeal:SetValue(healthBar:GetValue())
	healthBar.incHeal:SetFrameLevel(healthBar:GetFrameLevel() - 1)
	healthBar.incHeal:Hide()
end

local function OnHeal(unit, frameID)
	local healthBar = frameID or frames[unit]
	local healed = HealComm:getHeal(UnitName(unit))
	local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
	if not healthBar.incHeal then
		CreateHealCommBar(healthBar)
	end
	if healed > 0 and healthBar:IsShown() then
		health = health + healed
		if health > maxHealth then
			health = maxHealth
		end
		healthBar.incHeal:SetMinMaxValues(healthBar:GetMinMaxValues())
		healthBar.incHeal:SetValue(health)
		healthBar.incHeal:Show()
	else
		healthBar.incHeal:Hide()
	end
end

local function OnEvent(unitname)
	if UnitName("target") == unitname then
		OnHeal("target")
	end
	local unitobj = roster:GetUnitObjectFromName(unitname)
	if not unitobj or not unitobj.unitid then
		return
	end
	if UnitIsUnit("player", unitobj.unitid) then
		OnHeal("player")
	else
		for i=1, 4 do
			if UnitIsUnit("party"..i, unitobj.unitid) then
				OnHeal("party"..i)
			end
		end
	end
	if UnitInRaid("player") then
		local header = GROUP.." "..unitobj.subgroup
		local classheader = UnitClass(unitobj.unitid)
		local frame, unitframe
		for i=1, NUM_RAID_PULLOUT_FRAMES do
			frame = _G["RaidPullout"..i.."Name"]
			if frame:GetText() == header or frame:GetText() == classheader then
				frame = _G["RaidPullout"..i]
				for z=1, frame.numPulloutButtons do
					unitframe = _G[frame:GetName().."Button"..z]
					if unitframe.unit == unitobj.unitid then
						OnHeal(unitobj.unitid, _G[unitframe:GetName().."HealthBar"])
					end
				end
			end
		end
	end
end

local function OnTargetChanged()
	OnHeal("target")
end

local function OnUnitHealth()
	if frames[arg1] then
		OnHeal(arg1)
	end
end

AceEvent:RegisterEvent("HealComm_Healupdate", OnEvent)
AceEvent:RegisterEvent("PLAYER_TARGET_CHANGED", OnTargetChanged)
AceEvent:RegisterEvent("UNIT_HEALTH", OnUnitHealth)

local old_RaidPullout_Update = RaidPullout_Update
function RaidPullout_Update(pullOutFrame)
	old_RaidPullout_Update(pullOutFrame)
	if not pullOutFrame then
		pullOutFrame = this
	end
	local healthBar
	for i=1, pullOutFrame.numPulloutButtons do
		healthBar = _G[pullOutFrame:GetName().."Button"..i.."HealthBar"]
		if not healthBar.incHeal then
			CreateHealCommBar(healthBar)
		end
	end
end
