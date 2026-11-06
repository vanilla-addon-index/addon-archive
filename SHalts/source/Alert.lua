-------------------------------------------------------------------------------
-- Cooldown alert.
--
-- When a cooldown finishes on ANY stored character (not just the one you are
-- playing), a small window lists it. Everything that is ready at the same time
-- goes in the same window, and anything that finishes while it is open is added
-- to it. Each finished cooldown is announced once.
--
-- It waits while you are in combat or dead, and for a few seconds after logging
-- in. It never takes keyboard focus or blocks the screen, and it can be dragged.
-- Which cooldown was already announced is shared through the sync file, so with
-- several accounts running only one of them pops it up.
-- It can be turned off in the Settings tab.
-------------------------------------------------------------------------------
local S = SHAlts

S.Try("Alert.lua", function()

local CHECK_EVERY = 2      -- seconds between checks
local LOGIN_WAIT = 10      -- let the first scan and sync finish before announcing
local MAX_LINES = 12       -- characters listed before "and N more"

local SAME_WINDOW = 60     -- two end times this close are the same cooldown
local pending = {}         -- id -> { key, name, endsAt, showAt } waiting for a calm moment
local order = {}           -- ids in the order they came in
local shownIds = {}        -- ids currently listed in the window, in order
local shown = {}           -- id -> entry for what the window lists
local loginTime = 0
local popup

S.On("PLAYER_LOGIN", function()
	loginTime = GetTime()
	math.randomseed(math.floor(GetTime() * 1000) + time())
end)

-------------------------------------------------------------------------------
-- Finding finished cooldowns
-------------------------------------------------------------------------------
-- the end time identifies this particular cooldown, so using the item again and
-- waiting it out gives a new announcement. A few seconds of difference in the
-- stored end time (a rescan, another account's copy) is still the same cooldown.
local function SameCooldown(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) <= SAME_WINDOW
end

function S.QueueAlert(key, name, endsAt)
	local db = S.db
	if not db or not db.alert then return end
	if S.CdTracked and not S.CdTracked(name) then return end   -- switched off in the cooldown list
	local id = key .. "|" .. name
	if SameCooldown(db.alerted[id], endsAt) or pending[id] or shown[id] then return end
	-- A random delay of up to 3 seconds keeps two game windows from picking the
	-- same moment; whichever is second sees the first one's note in the sync file.
	pending[id] = { key = key, name = name, endsAt = endsAt, showAt = GetTime() + math.random() * 3 }
	table.insert(order, id)
end

-- every stored character whose cooldown time has passed
function S.AlertScan()
	local now = time()
	for key, c in pairs(S.db.chars) do
		for name, endsAt in pairs(c.cd or {}) do
			if endsAt and endsAt > 0 and endsAt <= now then S.QueueAlert(key, name, endsAt) end
		end
	end
end

local function Calm()
	if UnitAffectingCombat and UnitAffectingCombat("player") then return false end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
	return true
end

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local function Render()
	local p = popup
	-- group by character, keeping the order they became ready
	local keys, names = {}, {}
	for i = 1, table.getn(shownIds) do
		local e = shown[shownIds[i]]
		if S.db.chars[e.key] then
			if not names[e.key] then
				names[e.key] = {}
				table.insert(keys, e.key)
			end
			table.insert(names[e.key], e.name)
		end
	end

	local lines = {}
	local limit = table.getn(keys)
	if limit > MAX_LINES then limit = MAX_LINES end
	for i = 1, limit do
		local key = keys[i]
		table.insert(lines, S.ColoredName(S.db.chars[key]) .. "  |cffaaaaaa-|r  " .. table.concat(names[key], ", "))
	end
	if table.getn(keys) > limit then
		table.insert(lines, "|cffaaaaaaand " .. (table.getn(keys) - limit) .. " more|r")
	end

	p.text:SetText(table.concat(lines, "\n"))
	local h = p.text:GetHeight() or 14
	if h < 14 then h = 14 end
	p:SetHeight(h + 100)

	local n = 0
	for _ in pairs(names) do n = n + 1 end
	if n == 1 then
		p.title:SetText("Cooldown ready")
	else
		p.title:SetText("Cooldowns ready")
	end
end

local function CreatePopup()
	local p = CreateFrame("Frame", "SHAltsAlertPopup", UIParent)
	p:SetWidth(340); p:SetHeight(140)
	p:SetPoint("TOP", UIParent, "TOP", 0, -150)
	p:SetFrameStrata("DIALOG")
	p:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	p:EnableMouse(true)
	p:SetMovable(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", function() this:StartMoving() end)
	p:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	p:Hide()
	table.insert(UISpecialFrames, "SHAltsAlertPopup")   -- Escape closes it

	p.title = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	p.title:SetPoint("TOP", p, "TOP", 0, -18)

	p.text = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	p.text:SetPoint("TOP", p, "TOP", 0, -44)
	p.text:SetWidth(290)
	p.text:SetJustifyH("LEFT")

	local ok = CreateFrame("Button", "SHAltsAlertOK", p, "UIPanelButtonTemplate")
	ok:SetWidth(128); ok:SetHeight(22)
	ok:SetPoint("BOTTOMRIGHT", p, "BOTTOM", -6, 16)
	ok:SetText("OK")
	ok:SetScript("OnClick", function() p:Hide() end)

	local open = CreateFrame("Button", "SHAltsAlertOpen", p, "UIPanelButtonTemplate")
	open:SetWidth(128); open:SetHeight(22)
	open:SetPoint("BOTTOMLEFT", p, "BOTTOM", 6, 16)
	open:SetText("Open SHAlts")
	open:SetScript("OnClick", function()
		S.tab = "cd"
		S.UI.Show()
		S.UIChanged()
		p:Hide()
	end)

	-- closing it in any way is "seen"; the next window only holds new cooldowns
	p:SetScript("OnHide", function()
		shownIds = {}
		shown = {}
	end)

	popup = p
end

-- pending items move into the window, and are recorded as announced
local function Announce()
	local db = S.db
	local added = false
	for i = 1, table.getn(order) do
		local id = order[i]
		local e = pending[id]
		if e and not SameCooldown(db.alerted[id], e.endsAt) and db.chars[e.key] then
			db.alerted[id] = e.endsAt
			shown[id] = e
			table.insert(shownIds, id)
			added = true
		end
	end
	pending = {}
	order = {}
	return added
end

function S.ShowAlert()
	local db = S.db
	if not db then return end
	if not popup then CreatePopup() end

	-- another account may have announced these a moment ago
	if db.sync and S.SyncAvailable() then S.SyncPull() end
	local added = Announce()
	if not added then return end

	-- tell the other accounts right away so they don't announce it too
	if db.sync and S.SyncAvailable() then
		S.Sync()
	else
		S.syncDirty = true
	end

	Render()
	if not popup:IsShown() then
		popup:Show()
		pcall(PlaySound, "igQuestListOpen")
	end
end

-- for the Test alert button in Settings: shows the window with a sample, without recording anything
function S.ShowAlertPreview()
	if not popup then CreatePopup() end
	shown = {}
	shownIds = {}
	local c = S.db.chars[S.CharKey()]
	local key = S.CharKey()
	if not c then return end
	shown[key .. "|Salt Shaker"] = { key = key, name = "Salt Shaker", endsAt = 0 }
	table.insert(shownIds, key .. "|Salt Shaker")
	Render()
	popup:Show()
end

-------------------------------------------------------------------------------
-- Check every few seconds
-------------------------------------------------------------------------------
local function Check()
	S.After(CHECK_EVERY, Check)
	if not S.ready or not S.db or not S.db.alert then return end
	S.AlertScan()
	if table.getn(order) == 0 then return end
	if GetTime() - loginTime < LOGIN_WAIT then return end
	local due = false
	for i = 1, table.getn(order) do
		local e = pending[order[i]]
		if e and GetTime() >= e.showAt then due = true end
	end
	if not due then return end
	if not Calm() then return end
	S.ShowAlert()
end

S.On("PLAYER_LOGIN", function()
	S.After(CHECK_EVERY, Check)
end)

end)
