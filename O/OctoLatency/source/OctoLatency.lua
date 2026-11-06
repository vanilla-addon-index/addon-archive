--------------------------------------------------------------------------------
-- OctoLatency for Vanilla WoW (1.12.1) - Author: Palladinpala
--------------------------------------------------------------------------------

-- Throttle timer to reduce CPU/performance overhead
local elapsedTimer = 0
local UPDATE_INTERVAL = 2.0 -- update every 2 seconds

local MAX_ERROR_LOG = 20

local function OctoLatency_EnsureDB()
	if (not OctoLatencyDB) then
		OctoLatencyDB = {}
	end
	if (not OctoLatencyDB.errorLog) then
		OctoLatencyDB.errorLog = {}
	end
	return OctoLatencyDB
end

-- Records an error to SavedVariables (visible in-game via /octolat errors,
-- and readable straight out of the WTF SavedVariables file after logout)
-- and pings the chat frame so it isn't silently swallowed.
function OctoLatency_LogError(context, err)
	local db = OctoLatency_EnsureDB()
	local entry = {
		time = date("%Y-%m-%d %H:%M:%S"),
		context = context,
		message = tostring(err),
	}
	table.insert(db.errorLog, entry)
	while (table.getn(db.errorLog) > MAX_ERROR_LOG) do
		table.remove(db.errorLog, 1)
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffff5555OctoLatency error|r in " .. context .. ": " .. tostring(err) .. " (type /octolat errors)")
end

-- Runs func in protected mode so one bad tick can't break the addon,
-- and captures the error for later reporting instead of losing it.
local function OctoLatency_SafeCall(context, func, ...)
	local ok, err = pcall(func, ...)
	if (not ok) then
		OctoLatency_LogError(context, err)
	end
	return ok
end

function OctoLatency_OnLoad(self)
	-- Tooltip on hover
	self:SetScript("OnEnter", function()
		OctoLatency_SafeCall("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_TOP")
			GameTooltip:AddLine("OctoLatency", 0, 1, 1)
			local db = OctoLatency_EnsureDB()
			local bandwidth, latency, homeLatency, worldLatency = GetNetStats()
			bandwidth = bandwidth or 0
			homeLatency = homeLatency or 0
			worldLatency = worldLatency or 0
			GameTooltip:AddLine("Home Latency: " .. homeLatency .. " ms", 1, 1, 1)
			if (db.showWorldLatency) then
				GameTooltip:AddLine("World Latency: " .. worldLatency .. " ms", 1, 1, 1)
			else
				-- Many private-server cores never populate this (always 0), so
				-- it's hidden behind an opt-in setting (/octolat worldlatency)
				-- instead of showing a permanently-wrong "0 ms".
				GameTooltip:AddLine("World Latency: N/A", 1, 1, 1)
			end
			GameTooltip:AddLine("FPS: " .. string.format("%.0f", GetFramerate() or 0), 1, 1, 1)
			GameTooltip:AddLine("Bandwidth: " .. string.format("%.2f", bandwidth) .. " KB/s", 1, 1, 1)
			GameTooltip:AddLine("Left-click and drag to move.", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
	end)

	self:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function OctoLatency_UpdateText()
	local db = OctoLatency_EnsureDB()

	-- GetNetStats returns: bandwidth, latency, homeLatency, worldLatency
	local _, _, homeLatency, worldLatency = GetNetStats()

	-- World latency defaults to off since many private-server cores never
	-- populate it (always 0); enable it with /octolat worldlatency if your
	-- server does report it.
	local latency = homeLatency or 0
	if (db.showWorldLatency and worldLatency and worldLatency > 0) then
		latency = worldLatency
	end

	-- Color thresholds: Green < 150ms, Yellow 150-350ms, Red > 350ms
	local colorHex
	if (latency < 150) then
		colorHex = "|cff00ff00" -- Green
	elseif (latency <= 350) then
		colorHex = "|cffffff00" -- Yellow
	else
		colorHex = "|cffff0000" -- Red
	end

	local fps = GetFramerate() or 0
	local fpsColorHex
	if (fps >= 30) then
		fpsColorHex = "|cff00ff00" -- Green
	elseif (fps >= 15) then
		fpsColorHex = "|cffffff00" -- Yellow
	else
		fpsColorHex = "|cffff0000" -- Red
	end

	OctoLatencyText:SetText(colorHex .. latency .. " ms|r " .. fpsColorHex .. string.format("%.0f", fps) .. " fps|r")
end

function OctoLatency_OnUpdate(elapsed)
	-- OnMouseUp only fires while the cursor is still over the frame at
	-- release, which a quick flick of this small frame easily misses,
	-- leaving it stuck following the cursor forever. Poll the actual
	-- button state every frame so it lets go regardless of where the
	-- mouse ends up.
	if (this.isMoving and not IsMouseButtonDown("LeftButton")) then
		OctoLatency_StopMoving(this)
	end

	elapsedTimer = elapsedTimer + elapsed
	if (elapsedTimer < UPDATE_INTERVAL) then
		return
	end
	elapsedTimer = 0

	OctoLatency_SafeCall("OnUpdate", OctoLatency_UpdateText)
end

function OctoLatency_StopMoving(self)
	if (self.isMoving) then
		self:StopMovingOrSizing()
		self.isMoving = false
		OctoLatency_SavePosition()
	end
end

function OctoLatency_SavePosition()
	if (not OctoLatencyDB) then
		OctoLatencyDB = {}
	end
	local point, relativeTo, relativePoint, xOfs, yOfs = OctoLatencyFrame:GetPoint()
	OctoLatencyDB.point = point
	OctoLatencyDB.relativePoint = relativePoint
	OctoLatencyDB.xOfs = xOfs
	OctoLatencyDB.yOfs = yOfs
end

--------------------------------------------------------------------------------
-- Copy Errors window: vanilla WoW chat text can't be selected or copied, so
-- this shows the log in a multi-line EditBox that's auto-highlighted for Ctrl+C.
--------------------------------------------------------------------------------
local copyFrame, copyEditBox

local function OctoLatency_BuildErrorText()
	local db = OctoLatency_EnsureDB()
	if (table.getn(db.errorLog) == 0) then
		return "No errors logged."
	end
	local lines = {}
	for i, entry in ipairs(db.errorLog) do
		table.insert(lines, "[" .. entry.time .. "] " .. entry.context .. ": " .. entry.message)
	end
	return table.concat(lines, "\n")
end

local function OctoLatency_CreateCopyFrame()
	local f = CreateFrame("Frame", "OctoLatencyCopyFrame", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetWidth(420)
	f:SetHeight(260)
	f:SetPoint("CENTER")
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:Hide()

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", f, "TOP", 0, -16)
	title:SetText("OctoLatency Errors (Ctrl+C to copy, Esc to close)")

	local scroll = CreateFrame("ScrollFrame", "OctoLatencyCopyScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 44)

	local editBox = CreateFrame("EditBox", "OctoLatencyCopyEditBox", scroll)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(360)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
	scroll:SetScrollChild(editBox)
	copyEditBox = editBox

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function() f:Hide() end)

	copyFrame = f
end

function OctoLatency_ShowCopyErrors()
	if (not copyFrame) then
		OctoLatency_CreateCopyFrame()
	end
	copyEditBox:SetText(OctoLatency_BuildErrorText())
	copyFrame:Show()
	copyEditBox:SetFocus()
	copyEditBox:HighlightText()
end

-- Load saved position if available on PLAYER_LOGIN
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function()
	OctoLatency_SafeCall("PLAYER_LOGIN", function()
		if (OctoLatencyDB and OctoLatencyDB.point) then
			OctoLatencyFrame:ClearAllPoints()
			OctoLatencyFrame:SetPoint(OctoLatencyDB.point, UIParent, OctoLatencyDB.relativePoint, OctoLatencyDB.xOfs, OctoLatencyDB.yOfs)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Slash command: /octolat errors | copyerrors | clearerrors
--------------------------------------------------------------------------------
SLASH_OCTOLATENCY1 = "/octolat"
SlashCmdList["OCTOLATENCY"] = function(msg)
	local db = OctoLatency_EnsureDB()
	msg = string.lower(msg or "")

	if (msg == "errors") then
		if (table.getn(db.errorLog) == 0) then
			DEFAULT_CHAT_FRAME:AddMessage("OctoLatency: no errors logged.")
			return
		end
		DEFAULT_CHAT_FRAME:AddMessage("OctoLatency: last " .. table.getn(db.errorLog) .. " error(s):")
		for i, entry in ipairs(db.errorLog) do
			DEFAULT_CHAT_FRAME:AddMessage("[" .. entry.time .. "] " .. entry.context .. ": " .. entry.message)
		end
	elseif (msg == "copyerrors") then
		OctoLatency_ShowCopyErrors()
	elseif (msg == "clearerrors") then
		db.errorLog = {}
		DEFAULT_CHAT_FRAME:AddMessage("OctoLatency: error log cleared.")
	elseif (msg == "worldlatency") then
		db.showWorldLatency = not db.showWorldLatency
		DEFAULT_CHAT_FRAME:AddMessage("OctoLatency: world latency display " .. (db.showWorldLatency and "enabled" or "disabled") .. ".")
	else
		DEFAULT_CHAT_FRAME:AddMessage("OctoLatency commands: /octolat errors, /octolat copyerrors, /octolat clearerrors, /octolat worldlatency")
	end
end
