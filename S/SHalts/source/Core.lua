-------------------------------------------------------------------------------
-- SHAlts core: namespace, saved variables, helpers, events, timers, slash
-- Written for the 1.12 client (Lua 5.0): no # operator, no string.match,
-- no select/varargs, no % operator.
-------------------------------------------------------------------------------
SHAlts = SHAlts or {}
local S = SHAlts

S.MEDIA = "Interface\\AddOns\\SHAlts\\Textures\\"
S.TAG = "|cff66ccffSHAlts|r: "

function S.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(S.TAG .. tostring(msg))
end

-- Runs a chunk of setup code. If it errors, the message is shown in chat at
-- login (1.12 hides Lua errors by default), so a broken part never fails silently.
function S.Try(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		S.loadErrors = S.loadErrors or {}
		table.insert(S.loadErrors, label .. ": " .. tostring(err))
	end
	return ok
end

-------------------------------------------------------------------------------
-- Events, timers and the update tick all run off one hidden frame
-------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local handlers = {}
local timers = {}

-- several files may listen to the same event; handlers run in load order
function S.On(ev, fn)
	if not handlers[ev] then
		handlers[ev] = {}
		driver:RegisterEvent(ev)
	end
	table.insert(handlers[ev], fn)
end

function S.After(delay, fn)
	table.insert(timers, { t = GetTime() + delay, fn = fn })
end

local function RunTimers()
	local now = GetTime()
	local i = 1
	while i <= table.getn(timers) do
		local tm = timers[i]
		if now >= tm.t then
			table.remove(timers, i)
			tm.fn()
		else
			i = i + 1
		end
	end
end

driver:SetScript("OnEvent", function()
	local list = handlers[event]
	if list then
		for i = 1, table.getn(list) do list[i](arg1) end
	end
end)

driver:SetScript("OnUpdate", function()
	if table.getn(timers) > 0 then RunTimers() end
	if S.OnTick then S.OnTick(arg1 or 0) end
end)

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------
local DEFAULTS = {
	scale = 1,
	alpha = .9,
	minimapPos = 225,
	minimapHidden = false,
	sort = "name",
	alert = true,
	sync = true,
	resetAlerts = true,    -- sound and flash when a reset slot frees up or the cap is hit
	resetAnnounce = true,  -- tell the party or raid about resets when you lead
	usedSeconds = 0,       -- time SHAlts has been in use, for the one-time star ask
	starAsked = false,
}

S.On("ADDON_LOADED", function(name)
	-- the folder may be named SHalts or SHAlts (or end in -main from a zip), so ignore case
	if not name or not string.find(string.lower(name), "^shalts") then return end
	if type(SHAltsDB) ~= "table" then SHAltsDB = {} end
	local db = SHAltsDB
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	if type(db.chars) ~= "table" then db.chars = {} end
	if type(db.items) ~= "table" then db.items = {} end
	if type(db.deleted) ~= "table" then db.deleted = {} end   -- key -> time it was removed
	if type(db.alerted) ~= "table" then db.alerted = {} end   -- "key|cooldown" -> end time already announced
	if type(db.cdOff) ~= "table" then db.cdOff = {} end       -- cooldown name -> true when switched off
	S.db = db
end)

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
function S.CharKey()
	return UnitName("player") .. "-" .. GetRealmName()
end

local function Commas(n)
	local s = tostring(n)
	local k
	repeat
		s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

function S.FormatMoney(copper)
	copper = math.floor(copper or 0)
	local g = math.floor(copper / 10000)
	local s = math.floor(math.mod(copper, 10000) / 100)
	local c = math.mod(copper, 100)
	return "|cffffd700" .. Commas(g) .. "g|r |cffc0c0c0" .. s .. "s|r |cffeda55f" .. c .. "c|r"
end

function S.FormatDuration(sec)
	sec = math.floor(sec or 0)
	if sec <= 0 then return "Ready" end
	local d = math.floor(sec / 86400)
	local h = math.floor(math.mod(sec, 86400) / 3600)
	local m = math.floor(math.mod(sec, 3600) / 60)
	if d > 0 then return d .. "d " .. h .. "h" end
	if h > 0 then return h .. "h " .. m .. "m" end
	if m > 0 then return m .. "m" end
	return sec .. "s"
end

function S.ClassHex(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not c then return "|cffffffff" end
	return string.format("|cff%02x%02x%02x",
		math.floor(c.r * 255 + .5), math.floor(c.g * 255 + .5), math.floor(c.b * 255 + .5))
end

function S.ClassName(class)
	if not class then return "" end
	return string.upper(string.sub(class, 1, 1)) .. string.lower(string.sub(class, 2))
end

-- "|cffRRGGBBName|r" in the character's class color
function S.ColoredName(c)
	return S.ClassHex(c.class) .. (c.name or "?") .. "|r"
end

function S.UIChanged()
	if S.UI and S.UI.Refresh then S.UI.Refresh() end
end

-- our own data changed: redraw, and let the sync write it out soon
S.syncDirty = false
function S.DataChanged()
	S.syncDirty = true
	S.UIChanged()
end

-- "ffRRGGBB" for an item quality number (0 poor ... 5 legendary), like the color in an item link
local QUALITY_FALLBACK = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
function S.QualityColor(q)
	q = tonumber(q) or 1
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c and c.r then
		return string.format("ff%02x%02x%02x", math.floor(c.r * 255 + .5), math.floor(c.g * 255 + .5), math.floor(c.b * 255 + .5))
	end
	return QUALITY_FALLBACK[q] or "ffffffff"
end

-- Forget a stored character by name. Returns how many were removed, or nil and
-- the reason. The removal is remembered so the shared sync file doesn't bring
-- the character back; playing that character again does.
function S.DeleteChar(name)
	local want = string.lower(name or "")
	want = string.gsub(want, "^%s+", "")
	want = string.gsub(want, "%s+$", "")
	if want == "" then return nil, "Type a character name first." end
	local mine = S.CharKey()
	local removed, isMe = 0, false
	for key, c in pairs(S.db.chars) do
		if string.lower(c.name or "") == want then
			if key == mine then
				isMe = true
			else
				S.db.chars[key] = nil
				S.db.deleted[key] = time()
				removed = removed + 1
			end
		end
	end
	if removed > 0 then
		if S.selected and not S.db.chars[S.selected] then S.selected = nil end
		S.DataChanged()
		return removed
	end
	if isMe then return nil, "You can't remove the character you are playing." end
	return nil, "No stored character with that name."
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
local function Help()
	S.Print("commands (/shalts or /sha):")
	S.Print("  (nothing)        open or close the window")
	S.Print("  find <text>      search items and recipes on all alts")
	S.Print("  cd               list cooldowns in chat")
	S.Print("Everything else is in the Settings tab of the window.")
end

S.On("PLAYER_LOGIN", function()
	if S.loadErrors then
		S.After(2, function()
			for i = 1, table.getn(S.loadErrors) do
				S.Print("|cffff5555load error|r " .. S.loadErrors[i])
			end
		end)
	end
end)

local function Run(msg)
	if not S.db then return end
	local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	rest = rest or ""

	if cmd == "" or cmd == "show" or cmd == "toggle" then
		S.UI.Toggle()
	elseif cmd == "find" or cmd == "search" then
		S.UI.Search(rest)
	elseif cmd == "cd" or cmd == "cooldowns" then
		local rows = S.CooldownReport()
		if table.getn(rows) == 0 then
			S.Print("no cooldowns recorded yet")
		else
			for i = 1, table.getn(rows) do S.Print(rows[i]) end
		end
	elseif cmd == "resetdebug" then
		S.ToggleResetDebug()
	elseif cmd == "star" then
		S.ShowStarPopup(false)
	elseif cmd == "debug" then
		local used, need = S.HoursUsed()
		S.Print(string.format("used %.1f of %d hours, star ask %s", used, need, S.db.starAsked and "already done" or "pending"))
		S.Print("window " .. ((S.UI and S.UI.Toggle) and "built" or "NOT built")
			.. ", sync " .. (S.SyncAvailable and S.SyncAvailable() and "available" or "unavailable"))
		if S.loadErrors then
			for i = 1, table.getn(S.loadErrors) do S.Print("|cffff5555" .. S.loadErrors[i] .. "|r") end
		else
			S.Print("no load errors")
		end
	else
		Help()
	end
end

-- errors from a command show up in chat instead of vanishing
SLASH_SHALTS1 = "/shalts"
SLASH_SHALTS2 = "/sha"
SlashCmdList["SHALTS"] = function(msg)
	local ok, err = pcall(Run, msg)
	if not ok then S.Print("|cffff5555error|r " .. tostring(err)) end
end
