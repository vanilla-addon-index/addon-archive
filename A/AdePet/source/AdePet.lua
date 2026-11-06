-- AdePet.lua
-- Hunter-only addon for the 1.12 client.
-- Shows:  Pet_Name: Loyalty_Level (Loyalty_Name)
-- and, under it, "Pet is hungry" when the pet's happiness drops below Happy (yellow/red).
-- Window hides itself at max loyalty (Level 6).
--
-- Commands:
--   /hungry X        set hunger check interval to X seconds (default 15)
--   /adepet lock | unlock | reset      (alias: /ap)

AdePetDB = AdePetDB or {}

local LOYALTY_INTERVAL = 1.0
local DEFAULT_HUNGRY_INTERVAL = 15
local MAX_LOYALTY = 6

local LOYALTY_NAMES = {
	[1] = "Rebellious",
	[2] = "Unruly",
	[3] = "Submissive",
	[4] = "Dependable",
	[5] = "Faithful",
	[6] = "Best Friend",
}

local isHunter = false
local isHungry = false
local hungerLevel = 3 -- 1 = unhappy (red), 2 = content (yellow), 3 = happy (green)

local frame = CreateFrame("Frame", "AdePetFrame", UIParent)
frame:SetWidth(150)
frame:SetHeight(28)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0, 0, 0, 0.7)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("TOP", frame, "TOP", 0, -8)
text:SetJustifyH("CENTER")

local hungryText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hungryText:SetPoint("TOP", text, "BOTTOM", 0, -3)
hungryText:SetJustifyH("CENTER")
hungryText:Hide()

frame:SetScript("OnDragStart", function()
	if not AdePetDB.locked then
		this:StartMoving()
	end
end)

frame:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local point, _, relPoint, x, y = this:GetPoint()
	AdePetDB.point = point
	AdePetDB.relPoint = relPoint
	AdePetDB.x = x
	AdePetDB.y = y
end)

local function GetHungryInterval()
	return AdePetDB.hungryInterval or DEFAULT_HUNGRY_INTERVAL
end

-- Fit the window to the visible text lines.
local function ResizeToText()
	local w = text:GetStringWidth()
	local h1 = text:GetHeight()
	if not h1 or h1 < 1 then h1 = 12 end
	local height = 8 + h1 + 8

	if hungryText:IsShown() then
		local w2 = hungryText:GetStringWidth()
		if w2 > w then w = w2 end
		local h2 = hungryText:GetHeight()
		if not h2 or h2 < 1 then h2 = 10 end
		height = height + h2 + 3
	end

	w = w + 24
	if w < 90 then w = 90 end
	frame:SetWidth(w)
	frame:SetHeight(height)
end

-- While the player is flagged AFK, the addon makes no pet queries at all.
-- On some servers (seen on OctoWoW) pet API calls count as player activity,
-- which clears the AFK flag and makes it flicker on/off while standing still.
-- Checks simply resume on the first tick after the AFK flag is gone.
local chatAFK = false -- fallback if the client has no UnitIsAFK
local function IsPlayerAFK()
	if UnitIsAFK then
		return UnitIsAFK("player") and true or false
	end
	return chatAFK
end

-- Reads the pet's happiness. 1 = unhappy, 2 = content, 3 = happy.
-- Anything below "happy" is treated as hungry.
local function UpdateHunger()
	if not isHunter or not UnitExists("pet") then
		isHungry = false
		return
	end
	local happiness = GetPetHappiness()
	if type(happiness) ~= "number" then
		happiness = tonumber(happiness)
	end
	if happiness and happiness < 3 then
		isHungry = true
		hungerLevel = happiness
	else
		isHungry = false
	end
end

-- Extract numeric loyalty level. Standard API returns a number; some servers
-- (e.g. OctoWoW) return text like "(Loyalty Level 1) Rebellious".
local function ParseLoyalty(raw)
	if type(raw) == "number" then
		return raw
	elseif type(raw) == "string" then
		local _, _, digits = string.find(raw, "(%d+)")
		if digits then
			return tonumber(digits)
		end
		-- fallback: match by rank name
		local lower = string.lower(raw)
		for level, name in pairs(LOYALTY_NAMES) do
			if string.find(lower, string.lower(name), 1, true) then
				return level
			end
		end
	end
	return nil
end

local function UpdateDisplay()
	if not isHunter then
		frame:Hide()
		return
	end

	if not UnitExists("pet") then
		text:SetText("No Pet")
		hungryText:Hide()
		ResizeToText()
		frame:Show()
		return
	end

	local petName = UnitName("pet") or "Pet"
	local loyaltyLevel = ParseLoyalty(GetPetLoyalty())

	-- At max loyalty the window is only shown while the pet is hungry.
	if loyaltyLevel and loyaltyLevel >= MAX_LOYALTY and not isHungry then
		frame:Hide()
		return
	end

	if loyaltyLevel then
		local loyaltyName = LOYALTY_NAMES[loyaltyLevel] or "Unknown"
		text:SetText(petName .. ": " .. loyaltyLevel .. " (" .. loyaltyName .. ")")
	else
		text:SetText(petName)
	end

	if isHungry then
		hungryText:SetText("Pet is hungry")
		if hungerLevel == 1 then
			hungryText:SetTextColor(1, 0.2, 0.2)
		else
			hungryText:SetTextColor(1, 0.9, 0.1)
		end
		hungryText:Show()
	else
		hungryText:Hide()
	end

	ResizeToText()
	frame:Show()
end

local function CheckHunger()
	UpdateHunger()
	UpdateDisplay()
end

-- Feeding detection: while eating, the pet carries the "Feed Pet Effect" buff
-- (about 20 sec). We detect it by buff name in a hidden tooltip, with the
-- feeding icon as a secondary check. When the buff disappears, re-check hunger
-- immediately.
local scanTooltip = CreateFrame("GameTooltip", "AdePetScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local wasFeeding = false
local hungerElapsed = 0

local function PetIsFeeding()
	if not UnitExists("pet") then
		return false
	end
	for i = 1, 16 do
		local texture = UnitBuff("pet", i)
		if not texture then
			break
		end
		if string.find(texture, "BeastTraining", 1, true) then
			return true
		end
		scanTooltip:ClearLines()
		scanTooltip:SetUnitBuff("pet", i)
		local line = getglobal("AdePetScanTooltipTextLeft1")
		local name = line and line:GetText()
		if name and string.find(string.lower(name), "feed pet", 1, true) then
			return true
		end
	end
	return false
end

local function CheckFeeding()
	local feeding = PetIsFeeding()
	if wasFeeding and not feeding then
		-- Feeding just ended: check hunger now, regardless of the timer.
		hungerElapsed = 0
		CheckHunger()
	end
	wasFeeding = feeding
end

-- Timer and event handling live on a separate, always-active frame. A hidden
-- frame never receives OnUpdate, so running the timer on the (hideable) window
-- would stop all hunger checks at max loyalty, exactly when the window is hidden.
local driver = CreateFrame("Frame", "AdePetDriver")

local loyaltyElapsed = 0
driver:SetScript("OnUpdate", function()
	if not isHunter then
		return
	end
	loyaltyElapsed = loyaltyElapsed + arg1
	hungerElapsed = hungerElapsed + arg1

	-- Work at most once per second.
	if loyaltyElapsed < LOYALTY_INTERVAL then
		return
	end
	loyaltyElapsed = 0

	-- AFK: touch nothing. hungerElapsed keeps growing, so the first tick after
	-- the AFK flag is gone runs a full hunger check right away.
	if IsPlayerAFK() then
		return
	end

	if hungerElapsed >= GetHungryInterval() then
		hungerElapsed = 0
		CheckFeeding()
		CheckHunger()
	else
		CheckFeeding()
		UpdateDisplay()
	end
end)

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("UNIT_PET")
driver:RegisterEvent("UNIT_AURA")
driver:RegisterEvent("PLAYER_REGEN_ENABLED") -- left combat
driver:RegisterEvent("CHAT_MSG_SYSTEM")      -- only used for the AFK fallback

driver:SetScript("OnEvent", function()
	if event == "CHAT_MSG_SYSTEM" then
		if arg1 then
			if string.find(arg1, "now AFK", 1, true) then
				chatAFK = true
			elseif string.find(arg1, "no longer AFK", 1, true) then
				chatAFK = false
			end
		end
		return
	end

	if event == "UNIT_AURA" then
		if isHunter and arg1 == "pet" and not IsPlayerAFK() then
			CheckFeeding()
		end
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		local _, englishClass = UnitClass("player")
		isHunter = (englishClass == "HUNTER")

		if not isHunter then
			frame:Hide()
			return
		end

		if AdePetDB.point then
			frame:ClearAllPoints()
			frame:SetPoint(AdePetDB.point, UIParent, AdePetDB.relPoint, AdePetDB.x, AdePetDB.y)
		end
	end

	if not isHunter then
		return
	end

	if event == "UNIT_PET" and arg1 ~= "player" then
		return
	end

	-- While AFK, don't query the pet: just make sure the next non-AFK tick
	-- runs a hunger check.
	if IsPlayerAFK() then
		hungerElapsed = GetHungryInterval()
		return
	end

	-- Entering world, pet change, or leaving combat: check hunger right away.
	hungerElapsed = 0
	CheckHunger()
end)

SLASH_ADEPETHUNGRY1 = "/hungry"
SlashCmdList["ADEPETHUNGRY"] = function(msg)
	if not isHunter then
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: this addon only works for Hunters.")
		return
	end
	local seconds = tonumber(msg)
	if not seconds or seconds < 1 then
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: hunger check every " .. GetHungryInterval() .. "s. Usage: /hungry X (X = seconds, minimum 1)")
		return
	end
	AdePetDB.hungryInterval = seconds
	hungerElapsed = 0
	DEFAULT_CHAT_FRAME:AddMessage("AdePet: hunger check interval set to " .. seconds .. "s.")
end

SLASH_ADEPET1 = "/adepet"
SLASH_ADEPET2 = "/ap"
SlashCmdList["ADEPET"] = function(msg)
	msg = string.lower(msg or "")
	if not isHunter then
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: this addon only works for Hunters.")
		return
	end
	if msg == "lock" then
		AdePetDB.locked = true
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: window locked.")
	elseif msg == "unlock" then
		AdePetDB.locked = false
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: window unlocked (drag to move).")
	elseif msg == "reset" then
		AdePetDB.point = nil
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
		DEFAULT_CHAT_FRAME:AddMessage("AdePet: position reset.")
	elseif msg == "debug" then
		-- Prints the raw values the client returns, for troubleshooting.
		local happiness, damage, rate = GetPetHappiness()
		DEFAULT_CHAT_FRAME:AddMessage("AdePet debug: GetPetHappiness = " .. tostring(happiness) .. " (" .. type(happiness) .. "), " .. tostring(damage) .. ", " .. tostring(rate))
		local loyalty = GetPetLoyalty()
		DEFAULT_CHAT_FRAME:AddMessage("AdePet debug: GetPetLoyalty = " .. tostring(loyalty) .. " (" .. type(loyalty) .. "), parsed level = " .. tostring(ParseLoyalty(loyalty)))
		DEFAULT_CHAT_FRAME:AddMessage("AdePet debug: hungry = " .. tostring(isHungry) .. ", feeding = " .. tostring(PetIsFeeding()) .. ", interval = " .. GetHungryInterval() .. "s, window shown = " .. tostring(frame:IsShown()) .. ", AFK = " .. tostring(IsPlayerAFK()) .. " (UnitIsAFK " .. (UnitIsAFK and "available" or "missing") .. ")")
	else
		DEFAULT_CHAT_FRAME:AddMessage("AdePet commands: /adepet lock, unlock, reset, debug | /hungry X")
	end
end
