--[[ ShardCap options window, shown under AddOns in ClassicAPI's AddOn Options
     (Game Menu > AddOn Options, or /shardcap options).

     Uses the later-client panel protocol that ClassicAPI backports
     (InterfaceOptions_AddCategory with okay / cancel / default / refresh).
     Without it this file does nothing and the slash commands still work.

     Changes apply at once. Cancel (and Escape) puts back the settings you had
     when the window was opened; Defaults resets the page that is shown.
     Lua 5.0: no `...` expressions, no select().
]]

if type(InterfaceOptions_AddCategory) ~= "function" or not ShardCapAPI then return end

local API = ShardCapAPI
local DEFAULTS = API.DEFAULTS

local function DB() return API.GetDB() end
local function Changed() API.Schedule(0.3) end

------------------------------------------------------------------------------
-- Snapshot for Cancel (shared by both pages; one restore is enough)
------------------------------------------------------------------------------
local KEYS = { "cap", "notify", "sort", "combat", "reagents" }
local saved

local function CopyBags(t)
	if not t then return nil end
	local c = {}
	for k, v in pairs(t) do c[k] = v end
	return c
end

local function Snapshot()
	local db = DB()
	if saved or not db then return end
	saved = { soulbags = CopyBags(db.soulbags) }
	for _, k in ipairs(KEYS) do saved[k] = db[k] end
end

local function Restore()
	local db = DB()
	if not saved or not db then saved = nil return end
	for _, k in ipairs(KEYS) do db[k] = saved[k] end
	db.soulbags = CopyBags(saved.soulbags)
	saved = nil
	Changed()
end

------------------------------------------------------------------------------
-- Widgets (same templates ClassicAPI's own panel uses)
------------------------------------------------------------------------------
local numControls = 0
local function NextName()
	numControls = numControls + 1
	return "ShardCapOptionsControl" .. numControls
end

local function RefreshControls(page)
	if not DB() then return end
	page.updating = true
	for _, control in ipairs(page.controls) do control:Update() end
	if page.OnRefresh then page.OnRefresh() end
	page.updating = nil
end

local function NewPage(name, parent, title, subtitle)
	local page = CreateFrame("Frame")
	page.name = name
	page.parent = parent
	page.controls = {}

	local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
	heading:SetText(title)
	page.y = -40
	if subtitle then
		local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
		text:SetPoint("RIGHT", page, "RIGHT", -32, 0)
		text:SetJustifyH("LEFT")
		text:SetText(subtitle)
		page.y = -64
	end

	page.refresh = function() Snapshot(); RefreshControls(page) end
	page.okay = function() saved = nil end
	page.cancel = function() Restore() end
	return page
end

local function AddHeader(page, text)
	local header = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT", page, "TOPLEFT", 16, page.y - 8)
	header:SetText(text)
	page.y = page.y - 28
end

local function AddText(page, height)
	local fs = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", page, "TOPLEFT", 20, page.y)
	fs:SetPoint("RIGHT", page, "RIGHT", -16, 0)
	fs:SetJustifyH("LEFT")
	page.y = page.y - (height or 16)
	return fs
end

-- get() / set(value); enabledIf() greys the box out while it returns false.
local function AddCheckbox(page, label, tooltip, get, set, enabledIf, x)
	local check = CreateFrame("CheckButton", NextName(), page, "OptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", page, "TOPLEFT", x or 16, page.y)
	local text = getglobal(check:GetName() .. "Text")
	text:SetText(label)
	check.tooltipText = tooltip
	check:SetScript("OnClick", function()
		set(this:GetChecked() and true or false)
		RefreshControls(page)
	end)
	check.Update = function(self)
		self:SetChecked(get())
		if not enabledIf or enabledIf() then
			self:Enable()
			text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		else
			self:Disable()
			text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
		end
	end
	table.insert(page.controls, check)
	if not x then page.y = page.y - 30 end
	return check, text
end

------------------------------------------------------------------------------
-- Page 1: ShardCap
------------------------------------------------------------------------------
local main = NewPage("ShardCap", nil, "ShardCap " .. API.VERSION,
	"Keeps your Soul Shards at a cap when you leave combat.")

AddHeader(main, "Carrying")
local statusShards = AddText(main)
local statusReagents = AddText(main)
local statusBags = AddText(main, 22)

-- Cap: slider for quick changes (0-100), box for an exact value (0-200)
AddHeader(main, "Shard cap")
local MAX_SLIDER, MAX_CAP = 100, 200
local slider = CreateFrame("Slider", NextName(), main, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", main, "TOPLEFT", 24, main.y - 14)
slider:SetWidth(220)
slider:SetMinMaxValues(0, MAX_SLIDER)
slider:SetValueStep(1)
slider.tooltipText = "Shards to keep. Anything above this is deleted when you leave combat."
getglobal(slider:GetName() .. "Text"):SetText("Shards to keep")
getglobal(slider:GetName() .. "Low"):SetText("0")
getglobal(slider:GetName() .. "High"):SetText(MAX_SLIDER)

local box = CreateFrame("EditBox", NextName(), main, "InputBoxTemplate")
box:SetWidth(40)
box:SetHeight(20)
box:SetPoint("LEFT", slider, "RIGHT", 18, 0)
box:SetAutoFocus(false)
box:SetNumeric(true)
box:SetMaxLetters(3)
local boxFocus, boxCancel = false, false

local function SetCap(v)
	local db = DB()
	if not db or v == db.cap then return end
	db.cap = v
	Changed()
end

slider:SetScript("OnValueChanged", function()
	local v = math.floor(this:GetValue() + 0.5)
	if main.updating then return end
	box:SetText(v)
	SetCap(v)
	if main.OnRefresh then main.OnRefresh() end
end)

local function ApplyBox()
	local v = tonumber(box:GetText())
	if v and v >= 0 and v <= MAX_CAP then
		SetCap(math.floor(v))
	else
		API.Print("The cap must be a whole number from 0 to " .. MAX_CAP .. ".")
	end
	RefreshControls(main)
end
box:SetScript("OnEditFocusGained", function() boxFocus = true end)
box:SetScript("OnEditFocusLost", function()
	boxFocus = false
	if boxCancel then boxCancel = false; RefreshControls(main) else ApplyBox() end
end)
box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
box:SetScript("OnEscapePressed", function() boxCancel = true; this:ClearFocus() end)

slider.Update = function(self)
	local cap = DB().cap
	if cap > MAX_SLIDER then self:SetValue(MAX_SLIDER) else self:SetValue(cap) end
	if not boxFocus then box:SetText(cap) end
end
table.insert(main.controls, slider)
main.y = main.y - 50

local hint = AddText(main, 20)
hint:SetText("|cffaaaaaaType a value up to " .. MAX_CAP .. " in the box for caps above " .. MAX_SLIDER .. ".|r")

AddHeader(main, "Options")
AddCheckbox(main, "Chat notifications",
	"Print a line in chat whenever ShardCap deletes or moves something.",
	function() return DB().notify end, function(v) DB().notify = v end)
AddCheckbox(main, "Trim during combat",
	"Also delete shards above the cap while you are in combat. Off: wait until combat ends.",
	function() return DB().combat end, function(v) DB().combat = v; Changed() end)

local trim = CreateFrame("Button", NextName(), main, "UIPanelButtonTemplate")
trim:SetWidth(120)
trim:SetHeight(22)
trim:SetPoint("TOPLEFT", main, "TOPLEFT", 20, main.y - 8)
trim:SetText("Trim now")
trim:SetScript("OnClick", function() API.Schedule(0, true) end)
trim:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText("Delete shards above the cap right now, even in combat.", nil, nil, nil, nil, 1)
end)
trim:SetScript("OnLeave", function() GameTooltip:Hide() end)

main.OnRefresh = function()
	local shards, reagents, bags = API.StatusLines()
	statusShards:SetText(shards)
	statusReagents:SetText(reagents)
	statusBags:SetText(bags)
end

main.default = function()
	local db = DB()
	db.cap, db.notify, db.combat = DEFAULTS.cap, DEFAULTS.notify, DEFAULTS.combat
	Changed()
	RefreshControls(main)
end

------------------------------------------------------------------------------
-- Page 2: Soul Bag
------------------------------------------------------------------------------
local bagPage = NewPage("Soul Bag", main.name, "Soul Bag",
	"What goes in your soul bag, and which bags count as one.")

AddHeader(bagPage, "Sorting")
AddCheckbox(bagPage, "Move shards into the soul bag",
	"Move shards from your normal bags into free soul bag slots, and merge partial stacks.",
	function() return DB().sort end, function(v) DB().sort = v; Changed() end)
AddCheckbox(bagPage, "Also move Demonic Figurines and Infernal Stones",
	"Only uses soul bag slots that are not needed to hold your shard cap. "
	.. "Skipped on servers where shards don't stack.",
	function() return DB().reagents end, function(v) DB().reagents = v; Changed() end)

AddHeader(bagPage, "Soul bags")
local function IsAuto() return DB().soulbags == nil end
AddCheckbox(bagPage, "Detect soul bags automatically",
	"Recognizes soul bags by item type. Turn this off to choose the bags yourself.",
	IsAuto,
	function(v)
		local db = DB()
		if v then
			db.soulbags = nil
		else
			db.soulbags = {}
			for b = 1, 4 do if API.AutoIsSoulBag(b) then db.soulbags[b] = true end end
		end
		Changed()
	end)

local function BagName(bag)
	local link = GetInventoryItemLink("player", ContainerIDToInventoryID(bag))
	if not link then return nil end
	local _, _, name = string.find(link, "%[(.-)%]")
	return name
end

for bag = 1, 4 do
	local b = bag
	local check, label = AddCheckbox(bagPage, "Bag " .. b,
		"Treat this bag as a soul bag. Only available when automatic detection is off.",
		function() return API.IsSoulBag(b) end,
		function(v)
			local db = DB()
			if not db.soulbags then db.soulbags = {} end
			if v then db.soulbags[b] = true else db.soulbags[b] = nil end
			Changed()
		end,
		function() return not IsAuto() and BagName(b) ~= nil end,
		36)
	local update = check.Update
	check.Update = function(self)
		label:SetText("Bag " .. b .. ": " .. (BagName(b) or "|cff808080empty slot|r"))
		update(self)
	end
	bagPage.y = bagPage.y - 26
end

bagPage.default = function()
	local db = DB()
	db.sort, db.reagents, db.soulbags = DEFAULTS.sort, DEFAULTS.reagents, nil
	Changed()
	RefreshControls(bagPage)
end

------------------------------------------------------------------------------
-- Live refresh while a page is shown (bags change as you loot)
------------------------------------------------------------------------------
local function LiveRefresh(page)
	local elapsed = 0
	page:SetScript("OnUpdate", function()
		elapsed = elapsed + arg1
		if elapsed < 0.5 then return end
		elapsed = 0
		if not boxFocus then RefreshControls(this) end
	end)
end
LiveRefresh(main)
LiveRefresh(bagPage)

InterfaceOptions_AddCategory(main)
InterfaceOptions_AddCategory(bagPage)

API.OpenOptions = function()
	InterfaceOptionsFrame_OpenToCategory(main)
end
