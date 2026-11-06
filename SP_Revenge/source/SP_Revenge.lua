
local version = "1.0.0"

local defaults = {
	x = 0,
	y = -161,
	w = 200,
	h = 13,
	b = 0,
	a = 1,
	s = 1,
	sound = "off"
}
local settings = {
	x = "Bar X position",
	y = "Bar Y position",
	w = "Bar width",
	h = "Bar height",
	b = "Border height",
	a = "Alpha between 0 and 1",
	s = "Bar scale",
	sound = "Sound 'on' or 'off'"
}

--------------------------------------------------------------------------------

local rev_timeLeft = 0.0
local rev_CDTime = 0.0

--------------------------------------------------------------------------------

StaticPopupDialogs["SP_R_Install"] = {
	text = TEXT("Thank you for installing SP_Revenge " .. version .. "! Use the chat command /rev to change the position of the timer bar."),
	button1 = TEXT(YES),
	timeout = 0,
	hideOnEscape = 1,
};

--------------------------------------------------------------------------------

local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 0.7, 0.9)
end
local function SplitString(s,t)
	local l = {n=0}
	local f = function (s)
		l.n = l.n + 1
		l[l.n] = s
	end
	local p = "%s*(.-)%s*"..t.."%s*"
	s = string.gsub(s,"^%s+","")
	s = string.gsub(s,"%s+$","")
	s = string.gsub(s,p,f)
	l.n = l.n + 1
	l[l.n] = string.gsub(s,"(%s%s*)$","")
	return l
end

--------------------------------------------------------------------------------

local function GetSpellID(name)
	local spellID = 1
	local spellName = nil
	while 1 do
		spellName = GetSpellName(spellID, BOOKTYPE_SPELL)
		if spellName == name then
			return spellID
		end
		if spellName == nil then
			return nil
		end
		spellID = spellID + 1
	end
end
local function UpdateSettings()
	if not SP_R_GS then SP_R_GS = {} end
	for option, value in defaults do
		if SP_R_GS[option] == nil then
			SP_R_GS[option] = value
		end
	end
end
local function UpdateAppearance()
	SP_R_Frame:ClearAllPoints()
	SP_R_Frame:SetPoint("CENTER", "UIParent", "CENTER", SP_R_GS["x"], SP_R_GS["y"])

	local regions = {"SP_R_Frame", "SP_R_FrameShadowTime",
		"SP_R_FrameTime", "SP_R_FrameText"}

	for _,region in ipairs(regions) do
		getglobal(region):SetWidth(SP_R_GS["w"])
	end

	SP_R_Frame:SetHeight(SP_R_GS["h"])
	SP_R_FrameText:SetHeight(SP_R_GS["h"])

	SP_R_FrameTime:SetHeight(SP_R_GS["h"] - SP_R_GS["b"])
	SP_R_FrameShadowTime:SetHeight(SP_R_GS["h"] - SP_R_GS["b"])

	SP_R_FrameText:SetFont("Fonts\\FRIZQT__.TTF", SP_R_GS["h"])
	SP_R_Frame:SetAlpha(SP_R_GS["a"])
	SP_R_Frame:SetScale(SP_R_GS["s"])
end
local function ResetTimer()
	local rev_spellID = GetSpellID("Revenge")
	if rev_spellID == nil then
		return
	end

	local rev_start, rev_dur = GetSpellCooldown(rev_spellID, BOOKTYPE_SPELL)
	if rev_start > 0 then
		rev_CDTime = rev_dur - (GetTime() - rev_start)
	else
		rev_CDTime = 0
	end

	if rev_CDTime < 4 then
		if SP_R_GS["sound"] == "on" or SP_R_GS["sound"] == 1 then
			PlaySoundFile("Sound\\Interface\\PlayerInviteA.wav")
		end
		rev_timeLeft = 4
		SP_R_Frame:Show()
	end
end
local function TestShow()
	ResetTimer()
end
local function SetBarText(msg)
	SP_R_FrameText:SetText(msg)
end
local function UpdateDisplay()
	if (rev_timeLeft <= 0) then
		SP_R_FrameTime:Hide()
		SP_R_Frame:Hide()
	else
		local w = (math.min(rev_timeLeft, 4 - rev_CDTime) / 4 ) * SP_R_GS["w"]
		local w2 = (rev_timeLeft / 4) * SP_R_GS["w"]
		if w > 0 then
			SP_R_FrameTime:SetWidth(w)
			SP_R_FrameTime:Show()
		else
			SP_R_FrameTime:Hide()
		end
		SP_R_FrameShadowTime:SetWidth(w2)
		SP_R_FrameShadowTime:Show()

		SetBarText(string.sub(rev_timeLeft, 1, 3))

		SP_R_Frame:SetAlpha(SP_R_GS["a"])
	end
end

--------------------------------------------------------------------------------

function SP_R_OnLoad()
	this:RegisterEvent("ADDON_LOADED")
	-- Detect when you block/dodge/parry creature attacks
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
	-- Detect when a creature attack hits (for blocks)
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
	-- Detect when you dodge/parry player attacks
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
	-- Detect when a player attack hits (for blocks)
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
	-- Detect when Revenge is used
	this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
end

function SP_R_OnEvent()
	if (event == "ADDON_LOADED") then
		if (string.lower(arg1) == "sp_revenge") then

			if (SP_R_GS == nil) then
				StaticPopup_Show("SP_R_Install")
			end

			UpdateSettings()
			UpdateAppearance()
			UpdateDisplay()

			print("SP_Revenge " .. version .. " loaded. Options: /rev")
		end

	elseif (event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" or  event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES") then
		if string.find(arg1, "You dodge") or string.find(arg1, "You parry") then
			ResetTimer()
		end
	elseif (event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" or event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS") and string.find(arg1, "blocked") then
		ResetTimer()
	elseif (event == "CHAT_MSG_SPELL_SELF_DAMAGE") then
		-- Detect when Revenge is used to hide the bar
		local a,b,str = string.find(arg1, "Your (.+) hits")
		if not str then a,b,str = string.find(arg1, "Your (.+) crits") end
		if not str then a,b,str = string.find(arg1, "Your (.+) is parried") end
		if not str then a,b,str = string.find(arg1, "Your (.+) was dodged") end
		if not str then a,b,str = string.find(arg1, "Your (.+) was blocked") end
		if not str then a,b,str = string.find(arg1, "Your (.+) missed") end
		if str == "Revenge" then
			rev_timeLeft = 0
			UpdateDisplay()
		end
	end
end

function SP_R_OnUpdate(delta)
	if (rev_timeLeft > 0) then
		rev_timeLeft = rev_timeLeft - delta
		if (rev_timeLeft < 0) then
			rev_timeLeft = 0
		end
	end
	UpdateDisplay()
end

--------------------------------------------------------------------------------

SLASH_SPREVENGE1 = "/rev"
SLASH_SPREVENGE2 = "/revenge"

local function ChatHandler(msg)
	local vars = SplitString(msg, " ")
	for k,v in vars do
		if v == "" then
			v = nil
		end
	end
	local cmd, arg = vars[1], vars[2]
	if cmd == "reset" then
		SP_R_GS = nil
		UpdateSettings()
		UpdateAppearance()
		print("Reset to defaults.")
	elseif settings[cmd] ~= nil then
		if arg ~= nil then
			if arg == "on" then arg = 1 end
			if arg == "off" then arg = 0 end
			local number = tonumber(arg)
			if number then
				SP_R_GS[cmd] = number
				UpdateAppearance()
			else
				print("Error: Invalid argument")
			end
		end
		print(format("%s %s %s (%s)",
			SLASH_SPREVENGE1, cmd, SP_R_GS[cmd], settings[cmd]))
	else
		for k, v in settings do
			print(format("%s %s %s (%s)",
				SLASH_SPREVENGE1, k, SP_R_GS[k], v))
		end
	end
	TestShow()
end

SlashCmdList["SPREVENGE"] = ChatHandler
