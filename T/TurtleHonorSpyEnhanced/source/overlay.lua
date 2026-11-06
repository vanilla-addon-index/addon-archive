-- HonorSpy Overlay: current rank widget

local PAD     = 8
local INNER_W = 194

-- ===== Frame =====
local Frame = CreateFrame("Frame", "HonorSpyOverlayFrame", UIParent)
Frame:SetWidth(210)
Frame:SetHeight(132)
Frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
Frame:SetFrameStrata("HIGH")
Frame:SetFrameLevel(10)
Frame:SetMovable(true)
Frame:EnableMouse(true)
Frame:SetClampedToScreen(true)
Frame:SetBackdrop({
	bgFile   = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
Frame:SetBackdropColor(0, 0, 0, 0.8)
Frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
Frame:RegisterForDrag("LeftButton")
Frame:SetScript("OnDragStart", function() this:StartMoving() end)
Frame:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
	local hs = THSE.GetDB()
	if hs then
		local point, _, relPoint, x, y = this:GetPoint()
		hs.overlayPos = { point = point, relPoint = relPoint, x = x, y = y }
	end
end)
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
Frame:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
Frame:RegisterEvent("UPDATE_FACTION")

-- ===== Close Button =====
local closeBtn = CreateFrame("Button", nil, Frame, "UIPanelCloseButton")
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function()
	Frame:Hide()
	local hs = THSE.GetDB()
	if hs then hs.overlayHidden = true end
end)

-- ===== Top-right Icon Buttons (greyed out, coming soon) =====
local btnEstimator = CreateFrame("Button", nil, Frame)
btnEstimator:SetWidth(13)
btnEstimator:SetHeight(13)
btnEstimator:SetPoint("RIGHT", closeBtn, "LEFT", -1, 0)
local btnEstTex = btnEstimator:CreateTexture(nil, "ARTWORK")
btnEstTex:SetAllPoints(btnEstimator)
btnEstTex:SetTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
btnEstTex:SetVertexColor(0.35, 0.35, 0.35)
btnEstimator:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Rank Calculator", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Coming soon", 0.35, 0.35, 0.35)
	GameTooltip:Show()
end)
btnEstimator:SetScript("OnLeave", function() GameTooltip:Hide() end)

local btnPool = CreateFrame("Button", nil, Frame)
btnPool:SetWidth(16)
btnPool:SetHeight(13)
btnPool:SetPoint("RIGHT", btnEstimator, "LEFT", -3, 0)
local btnPoolFS = btnPool:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
btnPoolFS:SetAllPoints()
btnPoolFS:SetJustifyH("CENTER")
btnPoolFS:SetText("%")
btnPoolFS:SetTextColor(0.35, 0.35, 0.35)
btnPool:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("New Feature", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("Coming soon", 0.35, 0.35, 0.35)
	GameTooltip:Show()
end)
btnPool:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ===== Header bar (version label top-left) =====
local hdrDiv = Frame:CreateTexture(nil, "ARTWORK")
hdrDiv:SetTexture(1, 1, 1, 0.15)
hdrDiv:SetWidth(INNER_W)
hdrDiv:SetHeight(1)
hdrDiv:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -20)

local versionFooter = Frame:CreateFontString(nil, "OVERLAY")
versionFooter:SetFont("Fonts\\FRIZQT__.TTF", 9)
versionFooter:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -6)
versionFooter:SetJustifyH("LEFT")
versionFooter:SetTextColor(0.35, 0.35, 0.35)
versionFooter:SetText("v" .. (GetAddOnMetadata("TurtleHonorSpyEnhanced", "Version") or ""))
Frame.versionFooter = versionFooter

-- ===== Rank Display =====
local rankIcon = Frame:CreateTexture(nil, "ARTWORK")
rankIcon:SetWidth(26)
rankIcon:SetHeight(26)
rankIcon:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -26)

local rankNum = Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rankNum:SetPoint("TOPLEFT", rankIcon, "TOPRIGHT", 5, -1)
rankNum:SetJustifyH("LEFT")
rankNum:SetTextColor(1, 1, 1)

local rankPctText = Frame:CreateFontString(nil, "OVERLAY")
rankPctText:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankPctText:SetPoint("LEFT", rankNum, "RIGHT", 4, 0)
rankPctText:SetJustifyH("LEFT")
rankPctText:SetTextColor(0.87, 0.73, 0.27)

local rankName = Frame:CreateFontString(nil, "OVERLAY")
rankName:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankName:SetPoint("TOPLEFT", rankNum, "BOTTOMLEFT", 0, -1)
rankName:SetJustifyH("LEFT")
rankName:SetTextColor(0.55, 0.55, 0.55)

-- Rank progress two-tone bar (blue = week start, green = this week's gain)
local rankBarBg = Frame:CreateTexture(nil, "ARTWORK")
rankBarBg:SetTexture(0, 0, 0, 0.5)
rankBarBg:SetWidth(INNER_W)
rankBarBg:SetHeight(18)
rankBarBg:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -56)

local rankBarBlue = CreateFrame("StatusBar", nil, Frame)
rankBarBlue:SetWidth(INNER_W)
rankBarBlue:SetHeight(18)
rankBarBlue:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", 0, 0)
rankBarBlue:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rankBarBlue:SetStatusBarColor(0.25, 0.45, 0.9, 0.9)
rankBarBlue:SetMinMaxValues(0, 1)
rankBarBlue:SetFrameLevel(Frame:GetFrameLevel() + 1)

local rankBarGreen = CreateFrame("StatusBar", nil, Frame)
rankBarGreen:SetHeight(18)
rankBarGreen:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", 0, 0)
rankBarGreen:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rankBarGreen:SetStatusBarColor(0.27, 0.87, 0.47, 0.9)
rankBarGreen:SetMinMaxValues(0, 1)
rankBarGreen:SetFrameLevel(Frame:GetFrameLevel() + 2)

-- Text overlay above both rank bars
local rankBarTextFrame = CreateFrame("Frame", nil, Frame)
rankBarTextFrame:SetWidth(INNER_W)
rankBarTextFrame:SetHeight(18)
rankBarTextFrame:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -56)
rankBarTextFrame:SetFrameLevel(Frame:GetFrameLevel() + 3)

local rankBarText = rankBarTextFrame:CreateFontString(nil, "OVERLAY")
rankBarText:SetFont("Fonts\\FRIZQT__.TTF", 9)
rankBarText:SetPoint("CENTER", rankBarTextFrame, "CENTER", 0, 0)
rankBarText:SetJustifyH("CENTER")
rankBarText:SetTextColor(1, 1, 1)

-- Invisible tooltip trigger over the progress bar area
local rankTip = CreateFrame("Frame", nil, Frame)
rankTip:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD,  -56)
rankTip:SetPoint("BOTTOMRIGHT", Frame, "TOPLEFT", 210 - PAD, -86)
rankTip:EnableMouse(true)
rankTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Rank Progress", 1, 0.82, 0)
	GameTooltip:AddLine(" ", 1,1,1)
	local base = rankTip._base
	local gain = rankTip._sGain or "+0.00"
	local cur  = (rankTip._pct or "?") .. "%"
	if base then
		GameTooltip:AddDoubleLine("Day start",  base .. "%",  0.7,0.7,0.7,  0.7,0.7,0.7)
			GameTooltip:AddDoubleLine("+ Today", gain .. "%",  0.45,0.85,0.35,  0.45,0.85,0.35)
			GameTooltip:AddDoubleLine("= Current", cur,  1,0.82,0,  1,0.82,0)
		else
			GameTooltip:AddDoubleLine("+ Today", gain .. "%",  0.45,0.85,0.35,  0.45,0.85,0.35)
		GameTooltip:AddDoubleLine("= Current", cur,  1,0.82,0,  1,0.82,0)
	end
	GameTooltip:AddLine(" ", 1,1,1)
		GameTooltip:AddLine("Your rank progress gained today. Earning honor increases your rank percentage. At 100% you advance to the next rank.", 0.5, 0.5, 0.5, 1)
	GameTooltip:Show()
end)
rankTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

local footRankLeft = Frame:CreateFontString(nil, "OVERLAY")
footRankLeft:SetFont("Fonts\\FRIZQT__.TTF", 9)
footRankLeft:SetJustifyH("LEFT")
footRankLeft:SetTextColor(0.5, 0.5, 0.5)
footRankLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -78)
footRankLeft:SetText("Rank Progress")

local footRankRight = Frame:CreateFontString(nil, "OVERLAY")
footRankRight:SetFont("Fonts\\FRIZQT__.TTF", 9)
footRankRight:SetJustifyH("RIGHT")
footRankRight:SetTextColor(0.27, 0.87, 0.47)
footRankRight:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -78)
footRankRight:SetText("")

local footRankTip = CreateFrame("Button", nil, Frame)
footRankTip:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD,  -75)
footRankTip:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -88)
footRankTip:EnableMouse(true)
footRankTip:SetFrameLevel(Frame:GetFrameLevel() + 5)
footRankTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Today's Rank Progress", 1, 0.82, 0)
	GameTooltip:AddLine(" ", 1,1,1)
	local base = rankTip._base
	local gain = rankTip._sGain or "+0.00"
	local cur  = (rankTip._pct or "?") .. "%"
	if base then
		GameTooltip:AddDoubleLine("Day start",  base .. "%", 0.6,0.6,0.6, 0.6,0.6,0.6)
		GameTooltip:AddDoubleLine("+ Today",    gain .. "%", 0.6,0.6,0.6, 0.45,0.85,0.35)
		GameTooltip:AddDoubleLine("= Current",  cur,         0.6,0.6,0.6, 1,0.82,0)
	else
		GameTooltip:AddDoubleLine("+ Today",    gain .. "%", 0.6,0.6,0.6, 0.45,0.85,0.35)
		GameTooltip:AddDoubleLine("= Current",  cur,         0.6,0.6,0.6, 1,0.82,0)
	end
	GameTooltip:AddLine(" ", 1,1,1)
	GameTooltip:AddLine("Your rank progress gained today.",     0.5,0.5,0.5)
	GameTooltip:AddLine("Earning honor increases your rank %.", 0.5,0.5,0.5)
	GameTooltip:AddLine("At 100% you advance to the next rank.", 0.5,0.5,0.5)
	GameTooltip:Show()
end)
footRankTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ===== Daily BG row =====
local footDailyLeft = Frame:CreateFontString(nil, "OVERLAY")
footDailyLeft:SetFont("Fonts\\FRIZQT__.TTF", 9)
footDailyLeft:SetJustifyH("LEFT")
footDailyLeft:SetTextColor(0.5, 0.5, 0.5)
footDailyLeft:SetPoint("TOPLEFT", Frame, "TOPLEFT", PAD, -88)
footDailyLeft:SetText("Daily Battleground")

local dailyBGIcon = Frame:CreateTexture(nil, "ARTWORK")
dailyBGIcon:SetWidth(11)
dailyBGIcon:SetHeight(11)

local dailyBGText = Frame:CreateFontString(nil, "OVERLAY")
dailyBGText:SetFont("Fonts\\FRIZQT__.TTF", 9)
dailyBGText:SetJustifyH("RIGHT")
dailyBGText:SetTextColor(0.87, 0.73, 0.27)
dailyBGText:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -88)

dailyBGIcon:SetPoint("RIGHT", dailyBGText, "LEFT", -3, 0)

local dailyBGTip = CreateFrame("Frame", nil, Frame)
dailyBGTip:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD,  -86)
dailyBGTip:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -86)
dailyBGTip:SetHeight(14)
dailyBGTip:EnableMouse(true)
dailyBGTip:SetFrameLevel(Frame:GetFrameLevel() + 5)
local _BG_COLORS = {
	["Warsong Gulch"]  = { 1.0, 0.5, 0.5 },    -- red
	["Arathi Basin"]   = { 1.0, 1.0, 0.5 },     -- yellow
	["Blood Ring"]     = { 1.0, 0.82, 0.3 },    -- gold
	["Thorn Gorge"]    = { 0.5, 1.0, 0.5 },     -- green
	["Alterac Valley"] = { 0.5, 0.7, 1.0 },     -- blue
}
dailyBGTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Daily Battleground", 1, 0.82, 0)
	local now = time()
	local today = THSE.GetDailyBG(now)
	if today then
		local c = _BG_COLORS[today] or { 1, 1, 1 }
		GameTooltip:AddLine("Daily Battleground yield extra honor and reputation and rotate throughout the week in a specific order.", 0.7, 0.7, 0.7, 1)
		GameTooltip:AddLine(" ", 1, 1, 1)
		GameTooltip:AddDoubleLine("Today", today, 1, 0.82, 0, c[1], c[2], c[3])
		for d = 1, 6 do
			local future = THSE.GetDailyBG(now + d * 86400)
			if future then
				local dayName = date("%A", now + d * 86400)
				local fc = _BG_COLORS[future] or { 0.7, 0.7, 0.7 }
				GameTooltip:AddDoubleLine(dayName, future, 0.5, 0.5, 0.5, fc[1], fc[2], fc[3])
			end
		end
	end
	GameTooltip:Show()
end)
dailyBGTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateDailyBG()
	local bg = THSE.GetDailyBG(time())
	if bg then
		dailyBGIcon:SetTexture(THSE.BG_MARK_ICON[bg] or "Interface\\Icons\\INV_Misc_QuestionMark")
		dailyBGText:SetText(bg)
		dailyBGIcon:Show()
		dailyBGText:Show()
		footDailyLeft:Show()
	else
		dailyBGIcon:Hide()
		dailyBGText:Hide()
		footDailyLeft:Hide()
	end
end

-- ===== Bottom action buttons =====
local btnDiv = Frame:CreateTexture(nil, "ARTWORK")
btnDiv:SetTexture(1, 1, 1, 0.12)
btnDiv:SetHeight(1)
btnDiv:SetPoint("TOPLEFT",  Frame, "TOPLEFT",  PAD, -102)
btnDiv:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -102)

local BTN_H  = 20
local BTN_Y  = -105
local BTN_W  = INNER_W

local function MakeActionBtn(label, leftOffset, onClick, tipTitle, tipText)
	local btn = CreateFrame("Button", nil, Frame)
	btn:SetWidth(BTN_W)
	btn:SetHeight(BTN_H)
	btn:SetPoint("TOPLEFT", Frame, "TOPLEFT", leftOffset, BTN_Y)
	btn:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
		insets   = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	btn:SetBackdropColor(0.10, 0.10, 0.10, 0.85)
	btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Buttons\\WHITE8X8")
	hl:SetAllPoints(btn)
	hl:SetBlendMode("ADD")
	hl:SetVertexColor(1, 0.82, 0, 0.08)

	local fs = btn:CreateFontString(nil, "OVERLAY")
	fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
	fs:SetJustifyH("CENTER")
	fs:SetTextColor(0.80, 0.65, 0.10)
	fs:SetText(label)

	btn:SetScript("OnEnter", function()
		btn:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
		fs:SetTextColor(1.0, 0.85, 0.20)
		if tipTitle then
			GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
			GameTooltip:ClearLines()
			GameTooltip:AddLine(tipTitle, 1, 0.82, 0)
			if tipText then
				GameTooltip:AddLine(tipText, 0.6, 0.6, 0.6)
			end
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function()
		btn:SetBackdropBorderColor(0.45, 0.45, 0.45, 1.0)
		fs:SetTextColor(0.80, 0.65, 0.10)
		GameTooltip:Hide()
	end)
	if onClick then btn:SetScript("OnClick", onClick) end
	return btn
end

local historyBtn = MakeActionBtn("History", PAD, function() THSE:HistoryOpen() end, "Honor History", "View a full log of your honor sources,\nbattleground results and rank progression.")

local honorLabel = Frame:CreateFontString(nil, "OVERLAY")
honorLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
honorLabel:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -28)
honorLabel:SetJustifyH("RIGHT")
honorLabel:SetTextColor(0.87, 0.73, 0.27)
honorLabel:SetText("Honor")

local honorLine = Frame:CreateFontString(nil, "OVERLAY")
honorLine:SetFont("Fonts\\FRIZQT__.TTF", 9)
honorLine:SetPoint("TOPRIGHT", honorLabel, "BOTTOMRIGHT", 0, -2)
honorLine:SetJustifyH("RIGHT")

local honorIconFrame = CreateFrame("Frame", nil, Frame)
honorIconFrame:SetWidth(12)
honorIconFrame:SetHeight(12)
honorIconFrame:SetFrameLevel(Frame:GetFrameLevel() + 5)
honorIconFrame:SetPoint("RIGHT", honorLabel, "LEFT", -2, 0)

local honorIcon = honorIconFrame:CreateTexture(nil, "OVERLAY")
honorIcon:SetAllPoints(honorIconFrame)
honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
honorIcon:SetAlpha(0.90)

-- Tooltip trigger over honor display
local honorTip = CreateFrame("Frame", nil, Frame)
honorTip:SetPoint("TOPRIGHT", Frame, "TOPRIGHT", -PAD, -26)
honorTip:SetPoint("BOTTOMLEFT", Frame, "TOPRIGHT", -80, -52)
honorTip:EnableMouse(true)
honorTip:SetFrameLevel(Frame:GetFrameLevel() + 6)
honorTip._honor = 0
honorTip._today = 0

honorTip:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Weekly Honor", 1, 0.82, 0)
	GameTooltip:AddLine(" ", 1,1,1)
	local h = honorTip._honor or 0
	local hFmt = h >= 1000
		and string.format("%d,%03d", math.floor(h/1000), h - math.floor(h/1000)*1000)
		or tostring(h)
	local HONOR_CAP = 20000
	local capPct = math.floor(h * 100 / HONOR_CAP)
	local capFmt = HONOR_CAP >= 1000
		and string.format("%d,%03d", math.floor(HONOR_CAP/1000), HONOR_CAP - math.floor(HONOR_CAP/1000)*1000)
		or tostring(HONOR_CAP)
	GameTooltip:AddDoubleLine("Honor earned", hFmt, 0.6,0.6,0.6, 1,1,1)
	GameTooltip:AddDoubleLine("Weekly cap", capFmt, 0.6,0.6,0.6, 1,1,1)
	GameTooltip:AddDoubleLine("Cap progress", capPct .. "%", 0.6,0.6,0.6, 1,1,1)
	local td = honorTip._today or 0
	if td > 0 then
		local tdFmt = td >= 1000
			and string.format("%d,%03d", math.floor(td/1000), td - math.floor(td/1000)*1000)
			or tostring(td)
		GameTooltip:AddLine(" ", 1,1,1)
		GameTooltip:AddDoubleLine("Today", "+" .. tdFmt, 0.6,0.6,0.6, 0.87,0.73,0.27)
	end
	GameTooltip:AddLine(" ", 1,1,1)
	GameTooltip:AddLine("Honor resets every Wednesday at midnight UTC.", 0.5,0.5,0.5)
	GameTooltip:AddLine("You can earn up to " .. capFmt .. " honor per week.", 0.5,0.5,0.5)
	GameTooltip:Show()
end)
honorTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ===== Update Logic =====
-- Wednesday 00:00 UTC weekly reset. Jan 7, 1970 = first Wednesday epoch.
local FIRST_WED_UTC = 518400
local WEEK_SECS     = 604800

local function GetLastWedResetUTC()
	local now = time()
	local weeksSince = math.floor((now - FIRST_WED_UTC) / WEEK_SECS)
	return FIRST_WED_UTC + weeksSince * WEEK_SECS
end

local sessionStartProgress = nil  -- kept for tooltip compat (unused)
local sessionStartRank     = nil
local weeklyStartProgress  = nil
local sessionStartHonor    = nil
local dayStartProgress     = nil  -- rank progress at start of today (persisted in DB)

local function UpdateOverlay()
	local pvpRank = UnitPVPRank("player") or 0
	if pvpRank > 0 then
		local rankNameStr, rankTex = GetPVPRankInfo(pvpRank)
		rankTex = rankTex or pvpRank
		rankIcon:SetTexture(
			string.format("Interface\\PvPRankBadges\\PvPRank%02d", rankTex))
		rankIcon:Show()
		rankName:SetText(rankNameStr or ("Rank " .. rankTex))
		rankNum:SetText("Rank " .. rankTex)
		rankNum:Show()
	else
		rankIcon:Hide()
		rankName:SetText("|cff888888No PvP Rank|r")
		rankNum:Hide()
	end

	local progress = GetPVPRankProgress() or 0
	local pct = string.format("%.2f", progress * 100)
	local hs = THSE.GetDB()

	-- If progress dropped below baseline (weekly decay applied after login), reset baselines
	if progress > 0.0001 and dayStartProgress and progress < dayStartProgress - 0.001 then
		dayStartProgress = progress
		if hs then hs.dayStartProgress = progress end
	end
	if progress > 0.0001 and weeklyStartProgress and progress < weeklyStartProgress - 0.001 then
		weeklyStartProgress = progress
		if hs then hs.weeklyStartProgress = progress end
	end

	-- Today's gain % for the progress bar
	local sGain = 0
	local sGainStr = "+0.00"
	local sStart = dayStartProgress or 0
	if dayStartProgress ~= nil then
		sGain = progress - dayStartProgress
		if sGain < 0 then sGain = 0 end
		sGainStr = string.format("+%.2f", sGain * 100)
	end

	-- Rank progress two-tone bar: blue = session start, green = this session's gain
	rankBarBlue:SetValue(sStart)
	local bluePixels = sStart * INNER_W
	local greenWidth = math.max(1, INNER_W - bluePixels)
	rankBarGreen:SetWidth(greenWidth)
	rankBarGreen:ClearAllPoints()
	rankBarGreen:SetPoint("TOPLEFT", rankBarBg, "TOPLEFT", bluePixels, 0)
	rankBarGreen:SetMinMaxValues(0, greenWidth)
	rankBarGreen:SetValue(sGain * INNER_W)

	local pctStr = string.format("%.2f", progress * 100)
	local sGainBar = string.format("+%d", sGain * 100)
	rankBarText:SetText(pctStr .. "%")
	rankTip._pct    = pctStr
	rankTip._sGain  = sGainStr
	rankTip._base   = dayStartProgress and string.format("%.2f", dayStartProgress * 100) or nil

	-- Weekly honor
	local weekHonor = 0
	if GetPVPThisWeekStats then
		local _, honor = GetPVPThisWeekStats()
		weekHonor = honor or 0
	end
	-- Continuously snapshot current week's API honor so it's in DB before reset
	if weekHonor > 0 and hs then
		if not hs.weekApiHonor then hs.weekApiHonor = {} end
		local curResetKey = tostring(GetLastWedResetUTC())
		if not hs.weekApiHonor[curResetKey] or weekHonor > hs.weekApiHonor[curResetKey] then
			hs.weekApiHonor[curResetKey] = weekHonor
		end
	end
	local HONOR_CAP = 20000
	local capPct = math.floor(weekHonor * 100 / HONOR_CAP)
	local honorFmt = weekHonor >= 1000
		and string.format("%d,%03d", math.floor(weekHonor/1000), weekHonor - math.floor(weekHonor/1000)*1000)
		or tostring(weekHonor)
	honorLine:SetText("|cff888888(" .. capPct .. "%)|r " .. honorFmt)
	honorTip._honor = weekHonor
	-- Today's honor from honorHistory
	local todayTotal = 0
	local hhs = THSE.GetDB()
	if hhs and hhs.honorHistory then
		local todayKey = date("%a %d %b", time())
		for _, e in ipairs(hhs.honorHistory) do
			if e.type ~= "bgresult" and date("%a %d %b", e.t) == todayKey then
				todayTotal = todayTotal + (e.amount or 0)
			end
		end
	end
	honorTip._today = todayTotal
	-- Update faction icon
	local faction, _ = UnitFactionGroup("player")
	if faction == "Horde" then
		honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
		honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	else
		honorIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
		honorIcon:SetTexCoord(0.09, 0.63, 0.05, 0.63)
	end

	footRankRight:SetText(sGainStr .. "%")

	UpdateDailyBG()
end
local pendingRefresh = 0

Frame:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		local curProgress = GetPVPRankProgress() or 0
		local curRank     = UnitPVPRank("player") or 0
		sessionStartRank  = curRank
		local curHonor    = 0
		if GetPVPThisWeekStats then
			local _, h = GetPVPThisWeekStats()
			curHonor = h or 0
		end
		sessionStartHonor = curHonor
		local hs = THSE.GetDB()
		if hs then
			-- Day-start progress: persist per calendar day so /reload keeps the baseline
			local todayKey = date("%Y-%m-%d", time())
			if hs.dayProgressDate ~= todayKey then
				hs.dayProgressDate  = todayKey
				hs.dayStartProgress = curProgress
			end
			dayStartProgress = hs.dayStartProgress or curProgress
			local lastReset = GetLastWedResetUTC()
			-- Back-fill last week's honor from API (safety net for continuous snapshot)
			if not hs.weekApiHonor then hs.weekApiHonor = {} end
			local prevResetKey = tostring(lastReset - 604800)
			if not hs.weekApiHonor[prevResetKey] then
				if GetPVPLastWeekStats then
					local _, _, lwHonor = GetPVPLastWeekStats()
					if lwHonor and lwHonor > 0 then
						hs.weekApiHonor[prevResetKey] = lwHonor
					end
				end
			end
			if not hs.weeklyResetStamp or hs.weeklyResetStamp < lastReset then
				hs.weeklyStartProgress = curProgress
				hs.weeklyResetStamp    = lastReset
				hs.sessionStartHonor   = curHonor
			end
			if not hs.sessionStartHonor then
				hs.sessionStartHonor = curHonor
			end
			weeklyStartProgress = hs.weeklyStartProgress or curProgress
			Frame:SetHeight(132)
			local pos = hs.overlayPos
			if pos then
				Frame:ClearAllPoints()
				Frame:SetPoint(
					pos.point    or "CENTER",
					UIParent,
					pos.relPoint or "CENTER",
					pos.x or 0,
					pos.y or 200)
			end
			if hs.overlayHidden then Frame:Hide() else Frame:Show() end
		else
			dayStartProgress = curProgress
			Frame:Show()
		end
		UpdateOverlay()
	elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" or event == "PLAYER_PVP_RANK_CHANGED"
		or event == "UPDATE_FACTION" then
		pendingRefresh = 1.5
	end
end)

-- ===== Update Loop =====
local elapsed_total = 0
Frame:SetScript("OnUpdate", function()
	local dt = arg1
	if pendingRefresh > 0 then
		pendingRefresh = pendingRefresh - dt
		if pendingRefresh <= 0 then
			pendingRefresh = 0
			UpdateOverlay()
			elapsed_total = 0
		end
	end
	elapsed_total = elapsed_total + dt
	if elapsed_total >= 5 then
		elapsed_total = 0
		UpdateOverlay()
	end
end)

-- ===== Public API =====
function THSE:OverlayToggle()
	local hs = THSE.GetDB()
	if Frame:IsVisible() then
		Frame:Hide()
		if hs then hs.overlayHidden = true end
	else
		Frame:Show()
		if hs then hs.overlayHidden = false end
		UpdateOverlay()
	end
end

function THSE:OverlayRefresh()
	if Frame:IsVisible() then UpdateOverlay() end
end