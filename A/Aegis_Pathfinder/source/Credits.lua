--[[
	Credits.lua -- the in-game credits roll.

	Mirrors CONTRIBUTORS.md. Credit that only exists in a file on GitHub is not
	visible to the people actually using the addon, so it lives here too.

	Keep the two in step: if you add someone to CONTRIBUTORS.md, add them here.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

-- { heading, { line, ... } }. A line is "Name -- what they did"; the name is
-- set in full white. A `prose` section is one paragraph, wrapped to fit.
local CREDITS = {
	{ "Addon lineage", {
		"Tekkub -- TourGuide, the original guide framework",
		"isalcedo -- VanillaGuide, the 1.12 addon structure",
		"NostalgiaGeek -- VanillaGuide-Plus",
		"brues-code (Brues) -- VanillaGuide-Plus, ClassicAPI edition",
		"DonutsDelivery -- VanillaGuide-Plus",
		"brues-code -- ClassicAPI, the client DLL this addon is built on",
		"Torchlite -- Aegis: Pathfinder",
	} },
	{ "Guide content", {
		"Joana (Mancow) -- the optimized leveling routes",
		"mrmr -- optimized quest ordering",
		"RestedXP Guides (Tactics, Zeroji) -- RXP speedrun routes",
		"The Turtle WoW team and the servers continuing it",
		"ryanmr82 and the Hydra guild -- the Moonwhisper Coast quest data",
		"rivi-s -- pfQuest-turtle-HDB, filling its gaps",
		"Arthur-Helias -- InstanceJournal: every dungeon's quests, its entrance, its bosses, and Windhorn Canyon's and Frostmane Hollow's loot",
		"The Kludge Bureau -- pfQuest-turtle's patch 1.18.1 quests",
	} },
	{ "Libraries and data", {
		"The Ace Development Team -- Ace2",
		"shagu -- pfQuest, the herb and ore nodes, Turtle dungeon loot and where the rares spawn",
		"shagu -- pfUI's map reveal data, behind the guide browser's explored maps and the revealed world map (MIT)",
		"The Turtle WoW team and Lionel Schramm -- the dungeon loading screens and maps in the guide browser",
		"Cladhaire, laytya and the TWOW porters -- TomTom-TWOW",
		"Kitymeowmeow -- CraftRoute, the recipe data behind crafting routes and the profession guides' routes",
		"iGreed -- OctoPawn, the item score's tooltip stat patterns and soft caps (MIT)",
		"Vger and HawsJon -- Pawn's Classic Era scales, the reference the item score's stat weights are calibrated toward",
		"lioryx -- Modern Spellbook, whose talent window, plans and build strings the Talent Advisor works with",
		"The CMaNGOS team -- classic-db and mangos-classic: trainers, gathering data, quest rules and what dungeon bosses do",
	} },
	{ "Fonts", {
		"Rajdhani -- (c) 2014 Indian Type Foundry, SIL OFL 1.1",
		"Inter -- (c) 2016 The Inter Project Authors, SIL OFL 1.1",
	} },
	{ "Not affiliated", {
		"A fan project. Not affiliated with or endorsed by Blizzard "
			.. "Entertainment, Zygor Guides LLC, RestedXP, or any server team. "
			.. "The interface follows conventions set by Zygor and RestedXP; "
			.. "no art or code from either is used.",
	}, prose = true },
}

AegisPathfinder.creditsData = CREDITS

--[[ The credits window.

	Opened from the button on the options panel's About page, and built the
	first time it is: the same chrome as every other window, a scrolling body,
	and a section per heading above -- the options panel's own layout, so it
	reads as part of the same product rather than a dump into chat.
]]
local WIDTH, HEIGHT = 396, 460
local CHROME_TOP = 30 + 18
local PAD_X, PAD_TOP, PAD_BOTTOM = 14, 12, 16
local SCROLL_W = 10
local BODY_W = WIDTH - PAD_X * 2 - SCROLL_W - 4
local DASH = " \226\128\148 "     -- an em dash, spaced

-- "Name -- what" becomes the name in white and the rest in the fine print's dim.
local function Styled(line)
	local _, _, who, what = string.find(line, "^(.-) %-%- (.*)$")
	if not who then return line end
	return "|cffffffff" .. who .. "|r" .. DASH .. what
end

function AegisPathfinder:CreateCreditsFrame()
	local f = CreateFrame("Frame", "AegisPathfinderCredits", UIParent)
	self.creditsframe = f
	f:SetFrameStrata("DIALOG")
	f:SetWidth(WIDTH)
	f:SetHeight(HEIGHT)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	Theme:Panel(f, "panel")
	f:Hide()
	Theme:Chrome(f, "Credits", Theme:PositionSaver("creditsframe"))
	table.insert(UISpecialFrames, "AegisPathfinderCredits")

	local scroll = CreateFrame("ScrollFrame", "AegisPathfinderCreditsScroll", f)
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_X, -(CHROME_TOP + PAD_TOP))
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD_X + SCROLL_W), PAD_BOTTOM)
	local body = CreateFrame("Frame", nil, scroll)
	body:SetWidth(BODY_W)
	body:SetHeight(1)
	scroll:SetScrollChild(body)

	local bar = Theme:ScrollBar(f, SCROLL_W)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -(CHROME_TOP + PAD_TOP + SCROLL_W))
	bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, PAD_BOTTOM + SCROLL_W)
	bar.step = 40
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function() scroll:SetVerticalScroll(arg1 or 0) end)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function() bar:Nudge(-(arg1 or 0) * 40) end)

	-- Top to bottom with a running cursor, as the options panel lays out.
	local y = 0
	local function text(line, gap)
		local fs = Theme:FinePrint(body, BODY_W)
		fs:SetText(line)
		fs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		y = y + fs:GetHeight() + (gap or 0)
		return fs
	end

	text("Aegis: Pathfinder is built on a decade of other people's work. "
		.. "Almost everything that makes it function was written by someone else first.", 14)

	f.sections = {}
	for _, section in ipairs(CREDITS) do
		local h = Theme:SectionHeader(body, section[1], BODY_W)
		h:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		y = y + 20 + 7
		table.insert(f.sections, h)
		for _, line in ipairs(section[2]) do
			text(section.prose and line or Styled(line), 4)
		end
		y = y + 12
	end
	text("The full list is in CONTRIBUTORS.md, with the addon.")

	y = y + PAD_BOTTOM
	body:SetHeight(y)
	bar:SetMinMaxValues(0, math.max(0, y - (HEIGHT - CHROME_TOP - PAD_TOP - PAD_BOTTOM)))
	f.scroll, f.body, f.scrollbar = scroll, body, bar

	f:SetScript("OnShow", function()
		bar:SetValue(0)
		if Theme:RestorePosition(this, "creditsframe") then return end
		-- Beside the options panel, on the side away from the guide.
		local opts, guide = AegisPathfinder.optionsframe, AegisPathfinder.objectiveframe
		if not (opts and opts:IsShown()) then return end
		this:ClearAllPoints()
		local ol, gl = opts:GetLeft(), guide and guide:GetLeft()
		if ol and gl and ol > gl then
			this:SetPoint("TOPLEFT", opts, "TOPRIGHT", 8, 0)
		else
			this:SetPoint("TOPRIGHT", opts, "TOPLEFT", -8, 0)
		end
	end)
end

--- Open the credits, or close them if they are open.
function AegisPathfinder:ToggleCredits()
	if not self.creditsframe then self:CreateCreditsFrame() end
	if self.creditsframe:IsShown() then
		self.creditsframe:Hide()
	else
		self.creditsframe:Show()
	end
end
