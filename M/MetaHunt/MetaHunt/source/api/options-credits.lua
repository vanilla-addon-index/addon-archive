local MTH_CREDITS_READY = MTH_OptionsRequire and MTH_OptionsRequire("options-credits", {
	"MTH_GetFrame",
	"MTH_ClearContainer",
})

local MTH_CREDITS_FONT_DELTA = 2

local function MTH_CreditsBumpFont(fs)
	if not fs or not fs.GetFont or not fs.SetFont then return end
	local path, size, flags = fs:GetFont()
	if path and size then
		fs:SetFont(path, size + MTH_CREDITS_FONT_DELTA, flags)
	end
end

local function MTH_CreditsInsertLink(url)
	local link = tostring(url or "")
	if link == "" then return end
	if type(MTH_InsertLinkToChat) == "function" and MTH_InsertLinkToChat(link) then
		if MTH and MTH.Print then
			MTH:Print("Link inserted in chat: " .. link)
		end
		return
	end
	if MTH and MTH.Print then
		MTH:Print("Link: " .. link)
	end
end

local function MTH_CreditsClearFrame(frame)
	if not frame then return end
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if children[i] and children[i].Hide then
			children[i]:Hide()
		end
	end
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		if regions[i] and regions[i].Hide then
			regions[i]:Hide()
		end
	end
end

local function MTH_CreditsCreateLink(parent, label, url, anchorTo, y)
	local button = CreateFrame("Button", nil, parent)
	if not button then return nil end
	button:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, y or -4)
	button:SetHeight(18)
	button:SetWidth(500)
	local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("LEFT", button, "LEFT", 0, 0)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	text:SetTextColor(0.40, 0.75, 1.00)
	MTH_CreditsBumpFont(text)
	button:SetScript("OnClick", function()
		MTH_CreditsInsertLink(url)
	end)
	button:SetScript("OnEnter", function()
		text:SetTextColor(0.60, 0.90, 1.00)
	end)
	button:SetScript("OnLeave", function()
		text:SetTextColor(0.40, 0.75, 1.00)
	end)
	return button
end

local function MTH_CreditsCreateText(parent, anchorTo, text, font, y, r, g, b)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormalSmall")
	if anchorTo == parent then
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y or 0)
	else
		fs:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, y or -8)
	end
	fs:SetWidth(500)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetTextColor(r or 0.93, g or 0.93, b or 0.93)
	fs:SetText(text)
	MTH_CreditsBumpFont(fs)
	return fs
end

function MTH_SetupCreditsOptions()
	if not MTH_CREDITS_READY then return end

	local container = MTH_GetFrame("MetaHuntOptionsCredits")
	if not container then return end

	local panel = MTH_Layout.Panel(container)
	local title = panel:Title("Credits")

	local scrollFrame = MTH_GetFrame("MetaHuntOptionsCreditsScroll")
	if not scrollFrame then
		scrollFrame = CreateFrame("ScrollFrame", "MetaHuntOptionsCreditsScroll", container, "UIPanelScrollFrameTemplate")
	end
	scrollFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -30, 10)
	scrollFrame:Show()

	local content = MTH_GetFrame("MetaHuntOptionsCreditsContent")
	if not content then
		content = CreateFrame("Frame", "MetaHuntOptionsCreditsContent", scrollFrame)
	end
	content:SetWidth(520)
	content:SetHeight(2600)
	MTH_CreditsClearFrame(content)
	scrollFrame:SetScrollChild(content)

	local cursor = MTH_CreditsCreateText(content, content, "About the code", "GameFontNormal", -2, 1.00, 0.82, 0.00)
	cursor = MTH_CreditsCreateText(content, cursor,
		"This addon is, among others, a compilation of old Vanilla addons that I loved and played with for years. But most of them had become very buggy on Turtle WoW as new content was added to the server.\nI fixed, reworked, enhanced, and melted them within a modern modular framework that I created.\n"
		.. "I want to make clear what work is mine, what is not, and respectfully credit the original authors for the great stuff I've taken from them:",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- MetaHunt animations are powered by the great PizzaSauce library of Pizzahawaii! Thank you man.",
		"GameFontNormalSmall", -10)
	cursor = MTH_CreditsCreateLink(content,
		"https://codeberg.org/Pizzahawaii/",
		"https://codeberg.org/Pizzahawaii/",
		cursor,
		-4)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- zBars, AntiDaze, and AutoStrip were core functionalities of the Vanilla zHunterMod addon. I kept the \"z\" naming of bars/buttons to always remember it. I improved it and added zBar, zAmmo, zCompanions, zMount, zToys, and zCraft.\nAlso, the SmartAmmo feature idea comes from zHunterMod: there was a file with that functionality, but it was a work in progress, totally non-functional and even \"dangerous\" in its current state, and was not active in the addon. Since it was a fucking great idea, I recoded it mostly from scratch and made it work reliably and safely.",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- Feed-o-Matic was entirely the work of Fizzwidget. I made it work for Turtle WoW by melting it into a module that calls the MetaHunt core to get the pet's state and up-to-date data for new pet families and their diet.",
		"GameFontNormalSmall", -10)
	cursor = MTH_CreditsCreateLink(content,
		"https://www.wowinterface.com/downloads/info4160-FizzwidgetFeed-O-Matic.html",
		"https://www.wowinterface.com/downloads/info4160-FizzwidgetFeed-O-Matic.html",
		cursor,
		-4)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- The Tooltips module is based on Hunter Helper, another Vanilla addon by Fizzwidget. I kept the general idea, but there's not much original code left from it in MetaHunt, as I refactored everything so it plugs into MetaHunt-controlled event handlers, can work with Turtle WoW data, and is now usable for things other than Beasts.",
		"GameFontNormalSmall", -10)
	cursor = MTH_CreditsCreateLink(content,
		"https://legacy-wow.com/vanilla-addons/fizzwidget-hunter-helper/",
		"https://legacy-wow.com/vanilla-addons/fizzwidget-hunter-helper/",
		cursor,
		-4)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- Chronometer was an old and very popular Vanilla addon working with ACE2 libraries. It has had countless iterations by various people over the years, and I can't credit them all here. The current version used by MetaHunt is based on this Turtle WoW conversion made by \"wigan91\". I reworked it to be Hunter-focused only: removed the non-Hunter/racial stuff, improved incorrect spell/effect configuration definitions, added missing Hunter spells (not many), and implemented my own bar color scheme that fits Hunter spells better.",
		"GameFontNormalSmall", -10)
	cursor = MTH_CreditsCreateLink(content,
		"https://github.com/wigan91/Chronometer-TWoW",
		"https://github.com/wigan91/Chronometer-TWoW",
		cursor,
		-4)


	cursor = MTH_CreditsCreateText(content, cursor,
		"- ICU was an old Vanilla addon. I used the latest revision below and added many more configuration options to it.",
		"GameFontNormalSmall", -10)
	cursor = MTH_CreditsCreateLink(content,
		"https://github.com/wigan91/ICU-TWoW",
		"https://github.com/wigan91/ICU-TWoW",
		cursor,
		-4)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- The Map/Marker system is from pfQuest by Master Shagu. I mostly left it untouched and only made slight modifications so it can integrate better within MetaHunt and does not conflict with pfQuest.",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- The system allowing item links to be fetched in-game, notably in the Hunter Book Weapon tab, is from Atlas Turtle WoW.",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor, "About data sources", "GameFontNormal", -14, 1.00, 0.82, 0.00)
	cursor = MTH_CreditsCreateText(content, cursor,
		"MetaHunt ships with its own Turtle WoW datastores, limited to Hunter-related information, and most of this data is up to date for Turtle WoW 1.18.1. The beast information comes directly from an extract of the live Turtle WoW database, made for MetaHunt by the Turtle WoW dev lead in March 2026.\n\n"
		.. "Other sources used to build the data include:",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor,
		"- Atlas Turtle WoW for ranged weapon sources\n\n"
		.. "- Turtle WoW Wiki for pet diets (which was incomplete, missing Serpents and Foxes)",
		"GameFontNormalSmall", -10)

	cursor = MTH_CreditsCreateText(content, cursor,
		"",
		"GameFontNormalSmall", -10, 1.00, 0.82, 0.00)

	cursor = MTH_CreditsCreateText(content, cursor,
		"\n" .. "Metasploit <Atlantis>, of Nordaanar, now N'Zoth",
		"GameFontNormalSmall", -10)
end
