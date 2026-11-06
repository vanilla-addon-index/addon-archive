BINDING_HEADER_WOWRADIO = "WowRadio"
BINDING_NAME_WOWRADIO_TOGGLE = "Open Radio Window"
BINDING_NAME_WOWRADIO_PLAYSTOP = "Play / Stop"
BINDING_NAME_WOWRADIO_NEXT = "Next Station"
BINDING_NAME_WOWRADIO_PREV = "Previous Station"
BINDING_NAME_WOWRADIO_RANDOM = "Random Station"

function WowRadioBinding_Toggle()
if WowRadio then WowRadio:ToggleUI() end
end

function WowRadioBinding_PlayStop()
if WowRadio then
if WowRadio:isStopped() then WowRadio:play() else WowRadio:stop() end
end
end

function WowRadioBinding_Next()
if WowRadio then WowRadio:next() end
end

function WowRadioBinding_Prev()
if WowRadio then WowRadio:prev() end
end

function WowRadioBinding_Random()
if WowRadio then WowRadio:rnd() end
end

local L = AceLibrary("AceLocale-2.2"):new("WowRadio")
local version = "0.7i-nowplaying-bottom"
local customUrl = nil
local stopped = false
local stationShortNameCache = {}
local WR_CHAT_PREFIX = "|cffff9900[WoWRadio]|r "

WowRadio = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceDB-2.0")

-----------------------------------------------------------------
-- Slash Commands
-----------------------------------------------------------------

-- Main command now opens/closes the UI.
WowRadio:RegisterChatCommand({ "/wowradio", "/wr" }, {
type = 'execute',
name = "ui",
desc = "",
func = "ToggleUI",
}, "WOWRADIO00")

-- Old help/usage command preserved.
WowRadio:RegisterChatCommand({ "/wrhelp", "/wrusage" }, {
type = 'execute',
name = "usage",
desc = "",
func = "usage",
}, "WOWRADIOHELP")

WowRadio:RegisterChatCommand({"/wrtune"}, {
type = 'text',
name = "tune",
desc = "",
usage = "",
get = false,
set = "setStation",
}, "WOWRADIO01")

WowRadio:RegisterChatCommand({"/wrplay"}, {
type = 'execute',
name = "play",
desc = "",
func = "play",
}, "WOWRADIO02")

WowRadio:RegisterChatCommand({"/wrstop"}, {
type = 'execute',
name = "stop",
desc = "",
func = "stop",
}, "WOWRADIO03")

WowRadio:RegisterChatCommand({"/wrnext"}, {
type = 'execute',
name = "next",
desc = "",
func = "next",
}, "WOWRADIO04")

WowRadio:RegisterChatCommand({"/wrprev"}, {
type = 'execute',
name = "prev",
desc = "",
func = "prev",
}, "WOWRADIO05")

WowRadio:RegisterChatCommand({"/wrrnd"}, {
type = 'execute',
name = "rnd",
desc = "",
func = "rnd",
}, "WOWRADIO06")

WowRadio:RegisterChatCommand({"/wrlist"}, {
type = 'execute',
name = "list",
desc = "",
func = "list",
}, "WOWRADIO07")

WowRadio:RegisterChatCommand({"/wrindex", "/wri"}, {
type = 'execute',
name = "index",
desc = "",
func = "index",
}, "WOWRADIO11")

WowRadio:RegisterChatCommand({"/wrfull"}, {
type = 'execute',
name = "full",
desc = "",
func = "listFull",
}, "WOWRADIO12")

WowRadio:RegisterChatCommand({"/wrfind", "/wrsearch"}, {
type = 'text',
name = "find",
desc = "",
usage = "",
get = false,
set = "findStation",
}, "WOWRADIO13")

WowRadio:RegisterChatCommand({"/wrurl"}, {
type = 'execute',
name = "url",
desc = "",
func = "currentUrl",
}, "WOWRADIO14")

WowRadio:RegisterChatCommand({"/wrinfo"}, {
type = 'execute',
name = "info",
desc = "",
func = "info",
}, "WOWRADIO08")

WowRadio:RegisterChatCommand({"/wrauto"}, {
type = 'execute',
name = "autostart",
desc = "",
func = "toggleAutostart", 
}, "WOWRADIO09")

WowRadio:RegisterChatCommand({"/wrcustom"}, {
type = 'text',
name = "custom",
desc = "",
usage = "",
get = false,
set = "url",
}, "WOWRADIO10")

-- Explicit UI aliases.
WowRadio:RegisterChatCommand({"/wrgui", "/wrui"}, {
type = 'execute',
name = "gui",
desc = "",
func = "ToggleUI",
}, "WOWRADIO15")

-----------------------------------------------------------------
-- Database
-----------------------------------------------------------------

WowRadio:RegisterDB("WowRadioDB","WowRadioDBPC")

WowRadio:RegisterDefaults("account", {
autostart = false,
station = 1,
fadeOnMove = false,
muted = false,
muteVolume = nil,

ui = {
shown = false,
tab = "ALL",
page = 1,
compact = false,
scale = 1.0,
framePoint = "CENTER",
frameRelPoint = "CENTER",
frameX = 0,
frameY = 0,
},

favorites = {},

minimap = {
point = "TOPLEFT",
relPoint = "TOPLEFT",
x = -8,
y = -8,
},
})

-----------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------

function WowRadio:OnEnable()
WowRadio:EnsureUIDefaults()
WowRadio:CreateMinimapButton()
WowRadio:CreateController()

-- Restore custom URL from previous session.
customUrl = self.db.account.customUrl or nil

-- Re-apply muted state (CVar resets on reload).
if WowRadio.db.account.muted then
WowRadio:SafeSetCVar("EnableMusic", "1")
WowRadio:SafeSetCVar("Sound_EnableMusic", "1")
WowRadio:SafeSetCVar("MusicVolume", 0)
WowRadio:SafeSetCVar("Sound_MusicVolume", 0)
end

if WowRadio.db.account.ui.shown == true then
WowRadio:ShowController()
end

if WowRadio:isAutostart() == true then
if customUrl then
WowRadio:ForceMusicPlay(customUrl)
stopped = false
else
WowRadio:play()
end
end

self:Print(L["msg_enabled"])
end

-----------------------------------------------------------------
-- Core Radio Functions
-----------------------------------------------------------------

function WowRadio:ForceMusicPlay(url)
WowRadio:SafeSetCVar("EnableMusic", "0")
WowRadio:SafeSetCVar("EnableMusic", "1")
PlayMusic(url)
end

function WowRadio:setStation(arg)
local station = tonumber(arg)

if station == nil then
wr_msg("invalid argument")
return
end

WowRadio:play(station)
end

function WowRadio:getStation()
return tonumber(self.db.account.station)
end

function WowRadio:toggleAutostart()
self.db.account.autostart = not self.db.account.autostart

if self.db.account.autostart == true then
wr_msg(WR_CHAT_PREFIX.."Autostart enabled.")
else
wr_msg(WR_CHAT_PREFIX.."Autostart disabled.")
end

WowRadio:RefreshAutoButton()
end

function WowRadio:isAutostart()
return self.db.account.autostart
end

function WowRadio:info()
if customUrl == nil then
wr_alert("["..WowRadio:getStation().."] "..stationMsg[WowRadio:getStation()])
else
wr_alert("[custom] "..customUrl)
end
end

function WowRadio:play(station)
if station == nil then
station = WowRadio:getStation()
elseif station > table.getn(stationUrl) then
station = 1
elseif station < 1 then
station = table.getn(stationUrl)
end

wr_alert(WR_CHAT_PREFIX.."Tuning in to "..WowRadio:getStationShortName(station).."...")
WowRadio:ForceMusicPlay(stationUrl[station])

self.db.account.station = station
self.db.account.customUrl = nil
stopped = false
customUrl = nil

WowRadio:RefreshNowPlaying()
end

function WowRadio:stop()
StopMusic()
stopped = true
wr_alert(WR_CHAT_PREFIX.."Radio off.")
WowRadio:RefreshNowPlaying()
end

function WowRadio:next()
local station = WowRadio:getStation() + 1
WowRadio:play(station)
end

function WowRadio:prev()
local station = WowRadio:getStation() - 1
WowRadio:play(station)
end

function WowRadio:rnd()
WowRadio:play(math.random(table.getn(stationUrl)))
end

function WowRadio:url(url)
if url == nil or url == "" then
wr_msg("Usage: /wrcustom URL")
return
end

wr_alert(WR_CHAT_PREFIX.."Tuning in to custom stream...")
customUrl = url
self.db.account.customUrl = url
WowRadio:ForceMusicPlay(url)
stopped = false

WowRadio:RefreshNowPlaying()
end

function WowRadio:usage()
wr_msg("|cff7FFF7FWowRadio "..version.." "..L["usage"]..":|r")
wr_msg("|cffFFFF00/wr - |r|cffFFFFFFopen/close the radio controller|r")
wr_msg("|cffFFFF00/wrhelp - |r|cffFFFFFFshow this help text|r")
wr_msg("|cffFFFF00/wrtune # - |r|cffFFFFFF"..L["wrtune"].."|r")
wr_msg("|cffFFFF00/wrplay - |r|cffFFFFFF"..L["wrplay"].."|r")
wr_msg("|cffFFFF00/wrstop - |r|cffFFFFFF"..L["wrstop"].."|r")
wr_msg("|cffFFFF00/wrnext - |r|cffFFFFFF"..L["wrnext"].."|r")
wr_msg("|cffFFFF00/wrprev - |r|cffFFFFFF"..L["wrprev"].."|r")
wr_msg("|cffFFFF00/wrrnd - |r|cffFFFFFF"..L["wrrnd"].."|r")
wr_msg("|cffFFFF00/wrlist - |r|cffFFFFFFcompact station index, 3 per row|r")
wr_msg("|cffFFFF00/wrindex or /wri - |r|cffFFFFFFcompact station index, 3 per row|r")
wr_msg("|cffFFFF00/wrfull - |r|cffFFFFFFfull station list, one per row|r")
wr_msg("|cffFFFF00/wrfind text - |r|cffFFFFFFsearch stations by name, description, or URL|r")
wr_msg("|cffFFFF00/wrurl - |r|cffFFFFFFshow the current station URL|r")
wr_msg("|cffFFFF00/wrinfo - |r|cffFFFFFF"..L["wrinfo"].."|r")
wr_msg("|cffFFFF00/wrauto - |r|cffFFFFFF"..L["wrauto"].."|r")
wr_msg("|cffFFFF00/wrcustom URL - |r|cffFFFFFF"..L["wrcustom"].."|r")
end

-----------------------------------------------------------------
-- Existing List/Search Helpers
-----------------------------------------------------------------

function WowRadio:list()
WowRadio:index()
end

function WowRadio:index()
local perRow = 3
local colWidth = 36
local line = ""
local total = table.getn(stationUrl)

wr_msg("|cff7FFF7FWowRadio stations ("..total..") - use /wrtune #|r")

for index = 1, total do
local entry = "["..index.."] "..WowRadio:getStationShortName(index)
line = line..wr_pad(entry, colWidth)

if math.mod(index, perRow) == 0 then
wr_msg(line)
line = ""
end
end

if line ~= "" then
wr_msg(line)
end
end

function WowRadio:listFull()
for index,value in ipairs(stationMsg) do 
wr_msg("["..index.."] "..value) 
end
end

function WowRadio:findStation(arg)
local query = string.lower(arg or "")
local found = 0

if query == "" then
wr_msg("Usage: /wrfind text")
return
end

wr_msg("|cff7FFF7FWowRadio search: "..arg.."|r")

for index = 1, table.getn(stationUrl) do
local name = WowRadio:getStationShortName(index)
local msg = stationMsg[index] or ""
local url = stationUrl[index] or ""
local haystack = string.lower(name.." "..msg.." "..url)

if string.find(haystack, query, 1, true) then
found = found + 1
wr_msg("["..index.."] "..name)
end
end

if found == 0 then
wr_msg("No stations found.")
end
end

function WowRadio:currentUrl()
if customUrl == nil then
local station = WowRadio:getStation()
wr_msg("["..station.."] "..WowRadio:getStationShortName(station))
wr_msg(stationUrl[station])
else
wr_msg("[custom] "..customUrl)
end
end

function WowRadio:getStationShortName(index)
local cached = stationShortNameCache[index]
if cached ~= nil then
return cached
end

local msg = stationMsg[index] or ""
local pos = string.find(msg, " %- ")
local shortName = msg

if pos then
shortName = string.sub(msg, 1, pos - 1)
end

stationShortNameCache[index] = shortName
return shortName
end

-----------------------------------------------------------------
-- Generic Helpers
-----------------------------------------------------------------

function wr_alert(txt)
wr_msg(txt)
end

function wr_msg(txt)
DEFAULT_CHAT_FRAME:AddMessage(txt)
end

function wr_pad(txt, width)
local len = string.len(txt)

if len > width then
return string.sub(txt, 1, width - 1).."~"
end

return txt..string.rep(" ", width - len)
end

function wr_trim(txt, width)
if txt == nil then
return ""
end

if string.len(txt) > width then
return string.sub(txt, 1, width - 3).."..."
end

return txt
end

function WowRadio:getStationSize()
return table.getn(stationUrl)
end

function WowRadio:getStationNames()
return stationMsg
end

function WowRadio:getCustomUrl()
return customUrl
end

function WowRadio:isStopped()
return stopped
end

-----------------------------------------------------------------
-- WowRadio GUI Layer
-- Vanilla / 1.12.x compatible controller UI
-----------------------------------------------------------------

local WR_LINES_PER_PAGE = 8
local WR_FRAME_WIDTH = 560
local WR_FRAME_HEIGHT = 430
local WR_BACKDROP_TEXTURE_LEFT = "Interface\\AddOns\\WowRadio-Vanilla\\bg_left"
local WR_BACKDROP_TEXTURE_RIGHT = "Interface\\AddOns\\WowRadio-Vanilla\\bg_right"

local WR_MINI_WIDTH = 370
local WR_MINI_HEIGHT = 90
local WR_MICRO_SCROLL_CHARS = 30
local WR_MICRO_SCROLL_INTERVAL = 0.24
local WR_MICRO_SCROLL_PAUSE = 10.0

local WR_TABS = {
{ key = "ALL", label = "All", width = 45 },
{ key = "FAV", label = "Fav", width = 45 },
{ key = "GAME", label = "Game", width = 55 },
{ key = "TALK", label = "Talk", width = 55 },
{ key = "ROCK", label = "Rock", width = 55 },
{ key = "ELECTRONIC", label = "Electronic", width = 75 },
{ key = "JAZZ", label = "Jazz", width = 55 },
{ key = "VARIETY", label = "Various", width = 70 },
}

function WowRadio:EnsureUIDefaults()
if self.db.account.ui == nil then
self.db.account.ui = {}
end

if self.db.account.ui.shown == nil then
self.db.account.ui.shown = false
end

if self.db.account.ui.tab == nil then
self.db.account.ui.tab = "ALL"
end

-- Old saved states from prior versions should not point at removed panels.
if self.db.account.ui.tab == "CUSTOM" or self.db.account.ui.tab == "TEST" then
self.db.account.ui.tab = "ALL"
end

if self.db.account.ui.page == nil then
self.db.account.ui.page = 1
end

if self.db.account.ui.compact == nil then
self.db.account.ui.compact = false
end

if self.db.account.muted == nil then
self.db.account.muted = false
end

if self.db.account.favorites == nil then
self.db.account.favorites = {}
end

if self.db.account.minimap == nil then
self.db.account.minimap = {}
end

if self.db.account.minimap.point == nil then
self.db.account.minimap.point = "TOPLEFT"
end

if self.db.account.minimap.relPoint == nil then
self.db.account.minimap.relPoint = "TOPLEFT"
end

if self.db.account.minimap.x == nil then
self.db.account.minimap.x = -8
end

if self.db.account.minimap.y == nil then
self.db.account.minimap.y = -8
end

if self.db.account.volume == nil then
self.db.account.volume = WowRadio:ReadCurrentMusicVolume()
end

if self.db.account.fadeOnMove == nil then
self.db.account.fadeOnMove = false
end
end

function WowRadio:ShowCustomUrlDialog()
if not WowRadioUrlDialog then return end
WowRadioUrlDialog:ClearAllPoints()
WowRadioUrlDialog:SetPoint("CENTER", UIParent, "CENTER")
WowRadioUrlEditBox:SetText(customUrl or "")
WowRadioUrlDialog:Show()
WowRadioUrlEditBox:SetFocus()
end

function WowRadio:ToggleFadeOnMove()
self.db.account.fadeOnMove = not self.db.account.fadeOnMove

if WowRadioFrame and not self.db.account.fadeOnMove then
WowRadioFrame:SetAlpha(1)
end

WowRadio:RefreshFadeButton()
end

function WowRadio:SafeGetCVar(name)
if not GetCVar then
return nil
end

local ok, value = pcall(GetCVar, name)

if ok then
return value
end

return nil
end

function WowRadio:SafeSetCVar(name, value)
if not SetCVar then
return false
end

local ok = pcall(SetCVar, name, tostring(value))
return ok
end

function WowRadio:ReadCurrentMusicVolume()
local v = nil

-- Vanilla/1.12 commonly uses MusicVolume. Later clients use Sound_MusicVolume.
-- GetCVar can hard-error on unknown names in 1.12, so every lookup is wrapped.
v = tonumber(WowRadio:SafeGetCVar("MusicVolume"))

if v == nil then
v = tonumber(WowRadio:SafeGetCVar("Sound_MusicVolume"))
end

if v == nil then
v = tonumber(WowRadio:SafeGetCVar("SoundVolume"))
end

if v == nil then
v = 1
end

if v < 0 then
v = 0
elseif v > 1 then
v = 1
end

return v
end

function WowRadio:GetVolume()
local v = tonumber(self.db.account.volume)

if v == nil then
v = WowRadio:ReadCurrentMusicVolume()
end

if v < 0 then
v = 0
elseif v > 1 then
v = 1
end

return v
end

function WowRadio:ApplyVolume(value, quiet)
local v = tonumber(value)

if v == nil then
v = 1
end

if v < 0 then
v = 0
elseif v > 1 then
v = 1
end

self.db.account.volume = v

-- Vanilla/1.12 commonly uses EnableMusic + MusicVolume.
-- Later clients may use Sound_EnableMusic + Sound_MusicVolume.
WowRadio:SafeSetCVar("EnableMusic", "1")
WowRadio:SafeSetCVar("Sound_EnableMusic", "1")
WowRadio:SafeSetCVar("MusicVolume", v)
WowRadio:SafeSetCVar("Sound_MusicVolume", v)

if WowRadioFrame and WowRadioFrame.volumeValueText then
WowRadioFrame.volumeValueText:SetText(math.floor((v * 100) + 0.5).."%")
end

if quiet ~= true then
wr_msg(WR_CHAT_PREFIX.."Volume set to "..math.floor((v * 100) + 0.5).."%.")
end
end

function WowRadio:ToggleUI()
if WowRadioFrame and WowRadioFrame:IsVisible() then
WowRadio:HideController()
else
WowRadio:ShowController()
end
end

function WowRadio:ShowController()
if not WowRadioFrame then
WowRadio:CreateController()
end

WowRadioFrame:Show()
if WowRadioFrame.moveWatcher then WowRadioFrame.moveWatcher:Show() end
self.db.account.ui.shown = true
WowRadio:RefreshUI()
end

function WowRadio:HideController()
if WowRadioFrame then
if WowRadioFrame.moveWatcher then WowRadioFrame.moveWatcher:Hide() end
WowRadioFrame:Hide()
end

self.db.account.ui.shown = false
end

function WowRadio:CreateMinimapButton()
if WowRadioMinimapButton then
return
end

local button = CreateFrame("Button", "WowRadioMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(4)
button:EnableMouse(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_13")
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(53)
border:SetHeight(53)
border:SetPoint("TOPLEFT", button, "TOPLEFT")

local mm = self.db.account.minimap
button:ClearAllPoints()
button:SetPoint(mm.point, Minimap, mm.relPoint, mm.x, mm.y)

button:SetScript("OnClick", function()
if arg1 == "RightButton" then
if WowRadio:isStopped() then
WowRadio:play()
else
WowRadio:stop()
end
else
WowRadio:ToggleUI()
end
end)

local minimapDragging = false
local minimapDragX = mm.x or 0
local minimapDragY = mm.y or 0

local function UpdateMinimapButtonDrag()
local cursorX, cursorY = GetCursorPosition()
local scale = UIParent:GetScale()

if Minimap.GetEffectiveScale then
scale = Minimap:GetEffectiveScale()
end

if not scale or scale == 0 then
return
end

cursorX = cursorX / scale
cursorY = cursorY / scale

local centerX, centerY = Minimap:GetCenter()
if not centerX or not centerY then
return
end

minimapDragX = cursorX - centerX
minimapDragY = cursorY - centerY

button:ClearAllPoints()
button:SetPoint("CENTER", Minimap, "CENTER", minimapDragX, minimapDragY)
end

button:SetScript("OnDragStart", function()
if IsShiftKeyDown() then
minimapDragging = true
UpdateMinimapButtonDrag()
end
end)

button:SetScript("OnDragStop", function()
if not minimapDragging then
return
end

UpdateMinimapButtonDrag()
minimapDragging = false

WowRadio.db.account.minimap.point = "CENTER"
WowRadio.db.account.minimap.relPoint = "CENTER"
WowRadio.db.account.minimap.x = minimapDragX
WowRadio.db.account.minimap.y = minimapDragY
end)

button:SetScript("OnUpdate", function()
if minimapDragging then
UpdateMinimapButtonDrag()
end
end)

button:SetScript("OnEnter", function()
GameTooltip:SetOwner(this, "ANCHOR_LEFT")
GameTooltip:SetText("|cff7FFF7FWowRadio|r")
GameTooltip:AddLine("Left-click: open controller", 1, 1, 1)
GameTooltip:AddLine("Right-click: stop / resume", 1, 1, 1)
GameTooltip:AddLine("Shift-drag: reposition", 1, 1, 1)
GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
GameTooltip:Hide()
end)
end

function WowRadio:CreateController()
if WowRadioFrame then
return
end

local f = CreateFrame("Frame", "WowRadioFrame", UIParent)
f:SetWidth(WR_FRAME_WIDTH)
f:SetHeight(WR_FRAME_HEIGHT)
local savedScale = WowRadio.db.account.ui.scale or 1.0
f:SetScale(savedScale)
local uiPos = WowRadio.db.account.ui
f:SetPoint(uiPos.framePoint or "CENTER", UIParent, uiPos.frameRelPoint or "CENTER", uiPos.frameX or 0, uiPos.frameY or 0)
f:SetFrameStrata("DIALOG")
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetBackdrop({
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
tile = true,
tileSize = 16,
edgeSize = 16,
insets = { left = 5, right = 5, top = 5, bottom = 5 }
})

local bgLeft = f:CreateTexture(nil, "BACKGROUND")
bgLeft:SetTexture(WR_BACKDROP_TEXTURE_LEFT)
bgLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
bgLeft:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, 5)
bgLeft:SetTexCoord(0, 1, 0, 1)
f.bgTextureLeft = bgLeft

local bgRight = f:CreateTexture(nil, "BACKGROUND")
bgRight:SetTexture(WR_BACKDROP_TEXTURE_RIGHT)
bgRight:SetPoint("TOPLEFT", f, "TOP", 0, -5)
bgRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
bgRight:SetTexCoord(0, 1, 0, 1)
f.bgTextureRight = bgRight

f:Hide()

f:SetScript("OnDragStart", function()
this:StartMoving()
end)

f:SetScript("OnDragStop", function()
this:StopMovingOrSizing()
local pt, _, rpt, x, y = this:GetPoint(1)
WowRadio.db.account.ui.framePoint = pt
WowRadio.db.account.ui.frameRelPoint = rpt
WowRadio.db.account.ui.frameX = x
WowRadio.db.account.ui.frameY = y
end)

local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
if close.SetFrameLevel then
close:SetFrameLevel(f:GetFrameLevel() + 20)
end
close:SetWidth(22)
close:SetHeight(18)
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
close:SetText("x")
close:SetScript("OnClick", function()
WowRadio:HideController()
end)
f.closeButton = close

local minimizeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
if minimizeBtn.SetFrameLevel then
minimizeBtn:SetFrameLevel(f:GetFrameLevel() + 20)
end
minimizeBtn:SetWidth(22)
minimizeBtn:SetHeight(18)
minimizeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
minimizeBtn:SetText("_")
minimizeBtn:SetScript("OnClick", function()
WowRadio:ToggleMiniPlayer()
end)
f.minimizeButton = minimizeBtn

local fadeBtn = WowRadio:CreateWRButton(f, "Fade", 8, -6, 46, 18, function()
WowRadio:ToggleFadeOnMove()
end)
if fadeBtn.SetFrameLevel then
fadeBtn:SetFrameLevel(f:GetFrameLevel() + 20)
end
f.fadeButton = fadeBtn

local muteBtn = WowRadio:CreateWRButton(f, "Mute", 0, 0, 46, 18, function()
WowRadio:ToggleMute()
end)
if muteBtn.SetFrameLevel then
muteBtn:SetFrameLevel(f:GetFrameLevel() + 20)
end
f.muteButton = muteBtn

local sizer = CreateFrame("Button", nil, f)
sizer:SetWidth(16)
sizer:SetHeight(16)
sizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
if sizer.SetFrameLevel then
sizer:SetFrameLevel(f:GetFrameLevel() + 20)
end
sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
local sizerDragging = false
local sizerStartX, sizerStartScale

sizer:SetScript("OnMouseDown", function()
sizerDragging = true
sizerStartX = GetCursorPosition()
sizerStartScale = WowRadioFrame:GetScale()
end)

sizer:SetScript("OnMouseUp", function()
sizerDragging = false
WowRadio.db.account.ui.scale = WowRadioFrame:GetScale()
end)

sizer:SetScript("OnUpdate", function()
if not sizerDragging then return end
local cx = GetCursorPosition()
local newScale = sizerStartScale + (cx - sizerStartX) * 0.002
if newScale < 0.5 then newScale = 0.5 end
if newScale > 2.0 then newScale = 2.0 end
WowRadioFrame:SetScale(newScale)
end)
f.sizer = sizer

local wasMoving = false
local lastMX, lastMY = 0, 0
local moveCheckTimer = 0
local moveWatcher = CreateFrame("Frame", nil, UIParent)
moveWatcher:SetScript("OnUpdate", function()
moveCheckTimer = moveCheckTimer + arg1
if moveCheckTimer < 0.1 then return end
moveCheckTimer = 0

if not WowRadioFrame or not WowRadioFrame:IsVisible() then return end
if not WowRadio.db.account.fadeOnMove then
if wasMoving then
WowRadioFrame:SetAlpha(1)
wasMoving = false
end
return
end
local ok, mx, my = pcall(GetPlayerMapPosition, "player")
if not ok or not mx or not my or (mx == 0 and my == 0) then return end
local moving = (mx ~= lastMX or my ~= lastMY)
lastMX, lastMY = mx, my
if moving and not wasMoving then
WowRadioFrame:SetAlpha(0.25)
wasMoving = true
elseif not moving and wasMoving then
WowRadioFrame:SetAlpha(1)
wasMoving = false
end
end)
f.moveWatcher = moveWatcher

local nowBack = f:CreateTexture(nil, "ARTWORK")
nowBack:SetTexture(0, 0, 0, 0.82)
nowBack:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -364)
nowBack:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -20, -386)
f.nowBack = nowBack

local nowStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nowStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -369)
nowStatus:SetWidth(72)
nowStatus:SetJustifyH("LEFT")
nowStatus:SetText("|cffffffffStopped:|r")
f.nowStatusText = nowStatus

local nowStation = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
nowStation:SetPoint("LEFT", nowStatus, "RIGHT", 4, 0)
nowStation:SetWidth(320)
nowStation:SetJustifyH("LEFT")
nowStation:SetText("|cff00ff00[1] Everlook Broadcasting Co.|r")
f.nowStationText = nowStation

f.nowText = nowStation

f.prevButton = WowRadio:CreateWRButton(f, "<<", 205, -100, 46, 20, function()
WowRadio:prev()
end)

f.playButton = WowRadio:CreateWRButton(f, ">", 254, -100, 46, 20, function()
WowRadio:play()
end)

f.stopButton = WowRadio:CreateWRButton(f, "[ ]", 303, -100, 46, 20, function()
WowRadio:stop()
end)

f.nextButton = WowRadio:CreateWRButton(f, ">>", 352, -100, 46, 20, function()
WowRadio:next()
end)

f.randomButton = WowRadio:CreateWRButton(f, "?", 401, -100, 54, 20, function()
WowRadio:rnd()
end)

f.autoButton = WowRadio:CreateWRButton(f, "Auto", 458, -100, 82, 20, function()
WowRadio:toggleAutostart()
end)

local volumeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
volumeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -105)
volumeLabel:SetText("Vol")
f.volumeLabel = volumeLabel

local volume = CreateFrame("Slider", "WowRadioVolumeSlider", f, "OptionsSliderTemplate")
if volume.SetFrameLevel then
volume:SetFrameLevel(f:GetFrameLevel() + 10)
end
volume:SetWidth(108)
volume:SetHeight(14)
volume:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -102)
volume:SetMinMaxValues(0, 1)
volume:SetValueStep(0.05)

local low = getglobal("WowRadioVolumeSliderLow")
local high = getglobal("WowRadioVolumeSliderHigh")
local text = getglobal("WowRadioVolumeSliderText")

if low then low:SetText("") end
if high then high:SetText("") end
if text then text:SetText("") end

local volumeValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
volumeValue:SetPoint("TOPLEFT", f, "TOPLEFT", 158, -105)
volumeValue:SetWidth(40)
volumeValue:SetJustifyH("LEFT")
f.volumeValueText = volumeValue

volume:SetScript("OnValueChanged", function()
WowRadio:ApplyVolume(this:GetValue(), true)
end)

volume:SetScript("OnMouseUp", function()
wr_msg(WR_CHAT_PREFIX.."Volume set to "..math.floor((WowRadio:GetVolume() * 100) + 0.5).."%.")
end)

volume:SetValue(WowRadio:GetVolume())
f.volumeSlider = volume

f.tabButtons = {}

local tabX = 20
local tabY = -130
for _, tabInfo in ipairs(WR_TABS) do
local tabKey = tabInfo.key
local tabButton = WowRadio:CreateWRButton(f, tabInfo.label, tabX, tabY, tabInfo.width, 20, function()
WowRadio:SetUITab(tabKey)
end)

f.tabButtons[tabInfo.key] = tabButton
tabX = tabX + tabInfo.width + 5
end

f.rows = {}

for i = 1, WR_LINES_PER_PAGE do
local y = -158 - ((i - 1) * 25)

local star = WowRadio:CreateWRButton(f, "+", 20, y, 24, 20, function()
if this.stationIndex then
WowRadio:ToggleFavorite(this.stationIndex)
end
end)

local row = WowRadio:CreateWRButton(f, "", 48, y, 485, 20, function()
if this.stationIndex then
WowRadio:play(this.stationIndex)
end
end)

f.rows[i] = {
star = star,
row = row,
}
end

f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.pageText:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -399)
f.pageText:SetWidth(330)
f.pageText:SetJustifyH("LEFT")
f.pageText:SetText("Page 1")

f.customButton = WowRadio:CreateWRButton(f, "Custom", 355, -391, 88, 22, function()
WowRadio:ShowCustomUrlDialog()
end)

f.pagePrev = WowRadio:CreateWRButton(f, "<", 449, -391, 44, 22, function()
WowRadio:PageBack()
end)

f.pageNext = WowRadio:CreateWRButton(f, ">", 496, -391, 44, 22, function()
WowRadio:PageForward()
end)

local urlDialog = CreateFrame("Frame", "WowRadioUrlDialog", UIParent)
urlDialog:SetWidth(430)
urlDialog:SetHeight(95)
urlDialog:SetFrameStrata("FULLSCREEN_DIALOG")
urlDialog:SetPoint("CENTER", UIParent, "CENTER")
urlDialog:SetMovable(true)
urlDialog:EnableMouse(true)
urlDialog:RegisterForDrag("LeftButton")
urlDialog:SetScript("OnDragStart", function() this:StartMoving() end)
urlDialog:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
urlDialog:SetBackdrop({
bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
tile = true, tileSize = 32, edgeSize = 32,
insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
urlDialog:Hide()

local urlLabel = urlDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
urlLabel:SetPoint("TOPLEFT", urlDialog, "TOPLEFT", 16, -14)
urlLabel:SetText("Custom Stream URL:")

local urlEditBox = CreateFrame("EditBox", "WowRadioUrlEditBox", urlDialog, "InputBoxTemplate")
urlEditBox:SetWidth(390)
urlEditBox:SetHeight(20)
urlEditBox:SetPoint("TOPLEFT", urlDialog, "TOPLEFT", 16, -34)
urlEditBox:SetMaxLetters(250)
urlEditBox:SetAutoFocus(false)
urlEditBox:SetScript("OnEscapePressed", function()
urlDialog:Hide()
end)
urlEditBox:SetScript("OnEnterPressed", function()
local text = this:GetText()
if text and text ~= "" then WowRadio:url(text) end
urlDialog:Hide()
end)

local urlPlay = CreateFrame("Button", nil, urlDialog, "UIPanelButtonTemplate")
urlPlay:SetWidth(80)
urlPlay:SetHeight(22)
urlPlay:SetText("Play")
urlPlay:SetPoint("BOTTOMRIGHT", urlDialog, "BOTTOMRIGHT", -16, 10)
urlPlay:SetScript("OnClick", function()
local text = WowRadioUrlEditBox:GetText()
if text and text ~= "" then WowRadio:url(text) end
urlDialog:Hide()
end)

local urlCancel = CreateFrame("Button", nil, urlDialog, "UIPanelButtonTemplate")
urlCancel:SetWidth(80)
urlCancel:SetHeight(22)
urlCancel:SetText("Cancel")
urlCancel:SetPoint("RIGHT", urlPlay, "LEFT", -5, 0)
urlCancel:SetScript("OnClick", function()
urlDialog:Hide()
end)

f.urlDialog = urlDialog
f.urlEditBox = urlEditBox

WowRadio:ApplyVolume(WowRadio:GetVolume(), true)
WowRadio:ApplyUIMode()
end

function WowRadio:CreateWRButton(parent, text, x, y, width, height, onclick)
local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")

if parent and parent.GetFrameLevel and b.SetFrameLevel then
b:SetFrameLevel(parent:GetFrameLevel() + 10)
end

b:SetWidth(width)
b:SetHeight(height)
b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
b:SetText(text)
b:SetScript("OnClick", onclick)
return b
end

function WowRadio:UpdateTabButtons()
if not WowRadioFrame or not WowRadioFrame.tabButtons then
return
end

local currentTab = self.db.account.ui.tab or "ALL"
if WowRadioFrame.activeTabKey == currentTab then
return
end

for _, tabInfo in ipairs(WR_TABS) do
local b = WowRadioFrame.tabButtons[tabInfo.key]

if b then
if currentTab == tabInfo.key then
b:SetText("|cff7FFF7F"..tabInfo.label.."|r")
else
b:SetText(tabInfo.label)
end
end
end
WowRadioFrame.activeTabKey = currentTab
end

function WowRadio:SetUITab(tab)
self.db.account.ui.tab = tab
self.db.account.ui.page = 1
WowRadio:RefreshStationPanel(true)
end

function WowRadio:PageBack()
local page = tonumber(self.db.account.ui.page) or 1
page = page - 1

if page < 1 then
page = 1
end

self.db.account.ui.page = page
WowRadio:RefreshStationPanel(false)
end

function WowRadio:PageForward()
local page = tonumber(self.db.account.ui.page) or 1
self.db.account.ui.page = page + 1
WowRadio:RefreshStationPanel(false)
end

function WowRadio:IsFavorite(index)
if self.db.account.favorites == nil then
self.db.account.favorites = {}
end

return self.db.account.favorites[tostring(index)] == true
end

function WowRadio:ToggleFavorite(index)
if self.db.account.favorites == nil then
self.db.account.favorites = {}
end

local key = tostring(index)
if self.db.account.favorites[key] then
self.db.account.favorites[key] = nil
else
self.db.account.favorites[key] = true
end

WowRadio:RefreshStationPanel(false)
end

function WowRadio:GetStationCategory(index)
if stationCategory and stationCategory[index] then
return stationCategory[index]
end

return "VARIETY"
end

function WowRadio:GetVisibleStations()
local visible = {}
local tab = self.db.account.ui.tab or "ALL"

if tab == "CUSTOM" or tab == "TEST" then
tab = "ALL"
self.db.account.ui.tab = "ALL"
end

for i = 1, table.getn(stationUrl) do
local include = true

if tab == "FAV" and not WowRadio:IsFavorite(i) then
include = false
elseif tab ~= "ALL" and tab ~= "FAV" then
if WowRadio:GetStationCategory(i) ~= tab then
include = false
end
end

if include then
table.insert(visible, i)
end
end

return visible
end

function WowRadio:RefreshNowPlaying()
if not WowRadioFrame or not WowRadioFrame:IsVisible() then
return
end

local f = WowRadioFrame
local state = "Playing"
if stopped == true then
state = "Stopped"
end

if f.nowStatusText then
f.nowStatusText:SetText("|cffffffff"..state..":|r")
end

if f.nowStationText then
if customUrl == nil then
local station = WowRadio:getStation()
f.nowStationText:SetText("|cff00ff00["..station.."] "..wr_trim(WowRadio:getStationShortName(station), 40).."|r")
else
f.nowStationText:SetText("|cff00ff00[custom] "..wr_trim(customUrl, 40).."|r")
end
elseif f.nowText then
if customUrl == nil then
local station = WowRadio:getStation()
f.nowText:SetText("|cffffffff"..state..":|r |cff00ff00["..station.."] "..WowRadio:getStationShortName(station).."|r")
else
f.nowText:SetText("|cffffffff"..state..":|r |cff00ff00[custom] "..wr_trim(customUrl, 80).."|r")
end
end
end

function WowRadio:RefreshAutoButton()
if not WowRadioFrame or not WowRadioFrame:IsVisible() or not WowRadioFrame.autoButton then
return
end

if self.db.account.autostart == true then
WowRadioFrame.autoButton:SetText("Auto: On")
else
WowRadioFrame.autoButton:SetText("Auto: Off")
end
end

function WowRadio:RefreshFadeButton()
if not WowRadioFrame or not WowRadioFrame:IsVisible() or not WowRadioFrame.fadeButton then
return
end

if self.db.account.fadeOnMove then
WowRadioFrame.fadeButton:SetText("|cff7FFF7FFader|r")
else
WowRadioFrame.fadeButton:SetText("Fade")
end
end

function WowRadio:RefreshMuteButton()
if not WowRadioFrame or not WowRadioFrame:IsVisible() or not WowRadioFrame.muteButton then
return
end

if self.db.account.muted then
WowRadioFrame.muteButton:SetText("|cffFF5555Mute|r")
else
WowRadioFrame.muteButton:SetText("Mute")
end
end

function WowRadio:RefreshVolumeControl()
if not WowRadioFrame or not WowRadioFrame:IsVisible() or not WowRadioFrame.volumeSlider then
return
end

local v = WowRadio:GetVolume()
if WowRadioFrame.volumeSlider:GetValue() ~= v then
WowRadioFrame.volumeSlider:SetValue(v)
end
end

function WowRadio:RefreshStationPanel(updateTabs)
if not WowRadioFrame or not WowRadioFrame:IsVisible() then
return
end

if self.db.account.ui.compact == true then
return
end

if updateTabs ~= false then
WowRadio:UpdateTabButtons()
end
WowRadio:ShowStationPanel()
end

function WowRadio:RefreshUI()
if not WowRadioFrame or not WowRadioFrame:IsVisible() then
return
end

local tab = self.db.account.ui.tab or "ALL"
if tab == "CUSTOM" or tab == "TEST" then
self.db.account.ui.tab = "ALL"
WowRadioFrame.activeTabKey = nil
end

WowRadio:RefreshNowPlaying()
WowRadio:RefreshAutoButton()
WowRadio:RefreshFadeButton()
WowRadio:RefreshMuteButton()
WowRadio:RefreshVolumeControl()
WowRadio:RefreshStationPanel(true)
end

function WowRadio:ShowStationPanel()
local f = WowRadioFrame

if self.db.account.ui.compact == true then
for i = 1, WR_LINES_PER_PAGE do
f.rows[i].star:Hide()
f.rows[i].row:Hide()
end
f.pageText:Hide()
f.pagePrev:Hide()
f.pageNext:Hide()
return
end

f.pageText:Show()
f.pagePrev:Show()
f.pageNext:Show()

local visible = WowRadio:GetVisibleStations()
local total = table.getn(visible)
local page = tonumber(self.db.account.ui.page) or 1
local maxPage = math.ceil(total / WR_LINES_PER_PAGE)

if maxPage < 1 then
maxPage = 1
end

if page > maxPage then
page = maxPage
end

if page < 1 then
page = 1
end

self.db.account.ui.page = page

local startIndex = ((page - 1) * WR_LINES_PER_PAGE) + 1

for rowIndex = 1, WR_LINES_PER_PAGE do
local stationListIndex = startIndex + rowIndex - 1
local stationIndex = visible[stationListIndex]
local row = f.rows[rowIndex]

if stationIndex then
local name = "["..stationIndex.."] "..WowRadio:getStationShortName(stationIndex)

row.star:Show()
row.row:Show()

row.star.stationIndex = stationIndex
row.row.stationIndex = stationIndex

if WowRadio:IsFavorite(stationIndex) then
row.star:SetText("-")
else
row.star:SetText("+")
end

row.row:SetText(wr_trim(name, 70))
else
row.star:Hide()
row.row:Hide()

row.star.stationIndex = nil
row.row.stationIndex = nil
end
end

f.pageText:SetText("Page "..page.." / "..maxPage.." Stations: "..total)
end

function WowRadio:ToggleMiniPlayer()
self.db.account.ui.compact = not self.db.account.ui.compact
WowRadio:ApplyUIMode()
WowRadio:RefreshUI()
end

function WowRadio:ToggleMute()
self.db.account.muted = not self.db.account.muted
if self.db.account.muted then
WowRadio:SafeSetCVar("EnableMusic", "1")
WowRadio:SafeSetCVar("Sound_EnableMusic", "1")
WowRadio:SafeSetCVar("MusicVolume", 0)
WowRadio:SafeSetCVar("Sound_MusicVolume", 0)
wr_msg(WR_CHAT_PREFIX.."Muted.")
else
WowRadio:ApplyVolume(WowRadio:GetVolume(), true)
wr_msg(WR_CHAT_PREFIX.."Unmuted.")
end
WowRadio:RefreshMuteButton()
end

function WowRadio:ApplyUIMode()
if not WowRadioFrame then return end
local f = WowRadioFrame
local compact = self.db.account.ui.compact == true

if compact then
f:SetWidth(WR_MINI_WIDTH)
f:SetHeight(WR_MINI_HEIGHT)

f.bgTextureLeft:ClearAllPoints()
f.bgTextureLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
f.bgTextureLeft:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, 5)

f.bgTextureRight:ClearAllPoints()
f.bgTextureRight:SetPoint("TOPLEFT", f, "TOP", 0, -5)
f.bgTextureRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)

f.volumeLabel:Hide()
f.volumeSlider:ClearAllPoints()
f.volumeSlider:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -38)
f.volumeSlider:SetWidth(88)
f.volumeSlider:Show()

f.volumeValueText:ClearAllPoints()
f.volumeValueText:SetPoint("TOPLEFT", f, "TOPLEFT", 100, -43)
f.volumeValueText:SetWidth(34)
f.volumeValueText:Show()

f.muteButton:ClearAllPoints()
f.muteButton:SetPoint("TOPLEFT", f, "TOPLEFT", 135, -38)
f.muteButton:SetWidth(38)
f.muteButton:SetHeight(20)
f.muteButton:Show()

f.prevButton:ClearAllPoints()
f.prevButton:SetPoint("TOPLEFT", f, "TOPLEFT", 193, -38)
f.prevButton:SetWidth(42)
f.prevButton:SetHeight(20)
f.prevButton:Show()

f.playButton:ClearAllPoints()
f.playButton:SetPoint("TOPLEFT", f, "TOPLEFT", 237, -38)
f.playButton:SetWidth(42)
f.playButton:SetHeight(20)
f.playButton:Show()

f.stopButton:ClearAllPoints()
f.stopButton:SetPoint("TOPLEFT", f, "TOPLEFT", 281, -38)
f.stopButton:SetWidth(42)
f.stopButton:SetHeight(20)
f.stopButton:Show()

f.nextButton:ClearAllPoints()
f.nextButton:SetPoint("TOPLEFT", f, "TOPLEFT", 325, -38)
f.nextButton:SetWidth(42)
f.nextButton:SetHeight(20)
f.nextButton:Show()

f.nowBack:ClearAllPoints()
f.nowBack:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -62)
f.nowBack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 10)

f.nowStatusText:ClearAllPoints()
f.nowStatusText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -66)
f.nowStatusText:SetWidth(58)

f.nowStationText:ClearAllPoints()
f.nowStationText:SetPoint("LEFT", f.nowStatusText, "RIGHT", 4, 0)
f.nowStationText:SetWidth(270)

f.randomButton:Hide()
f.autoButton:Hide()
f.customButton:Hide()
f.pageText:Hide()
f.pagePrev:Hide()
f.pageNext:Hide()
if f.sizer then f.sizer:Hide() end

for _, tabInfo in ipairs(WR_TABS) do
local b = f.tabButtons[tabInfo.key]
if b then b:Hide() end
end

for i = 1, WR_LINES_PER_PAGE do
f.rows[i].star:Hide()
f.rows[i].row:Hide()
end
else
f:SetWidth(WR_FRAME_WIDTH)
f:SetHeight(WR_FRAME_HEIGHT)

f.bgTextureLeft:ClearAllPoints()
f.bgTextureLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
f.bgTextureLeft:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, 5)

f.bgTextureRight:ClearAllPoints()
f.bgTextureRight:SetPoint("TOPLEFT", f, "TOP", 0, -5)
f.bgTextureRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)

f.muteButton:ClearAllPoints()
f.muteButton:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80)
f.muteButton:SetWidth(46)
f.muteButton:SetHeight(18)
f.muteButton:Show()

f.volumeLabel:ClearAllPoints()
f.volumeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -105)
f.volumeLabel:Show()

f.volumeSlider:ClearAllPoints()
f.volumeSlider:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -102)
f.volumeSlider:SetWidth(108)
f.volumeSlider:Show()

f.volumeValueText:ClearAllPoints()
f.volumeValueText:SetPoint("TOPLEFT", f, "TOPLEFT", 158, -105)
f.volumeValueText:SetWidth(40)
f.volumeValueText:Show()

f.prevButton:ClearAllPoints()
f.prevButton:SetPoint("TOPLEFT", f, "TOPLEFT", 205, -100)
f.prevButton:SetWidth(46)
f.prevButton:SetHeight(20)
f.prevButton:Show()

f.playButton:ClearAllPoints()
f.playButton:SetPoint("TOPLEFT", f, "TOPLEFT", 254, -100)
f.playButton:SetWidth(46)
f.playButton:SetHeight(20)
f.playButton:Show()

f.stopButton:ClearAllPoints()
f.stopButton:SetPoint("TOPLEFT", f, "TOPLEFT", 303, -100)
f.stopButton:SetWidth(46)
f.stopButton:SetHeight(20)
f.stopButton:Show()

f.nextButton:ClearAllPoints()
f.nextButton:SetPoint("TOPLEFT", f, "TOPLEFT", 352, -100)
f.nextButton:SetWidth(46)
f.nextButton:SetHeight(20)
f.nextButton:Show()

f.randomButton:ClearAllPoints()
f.randomButton:SetPoint("TOPLEFT", f, "TOPLEFT", 401, -100)
f.randomButton:SetWidth(54)
f.randomButton:SetHeight(20)
f.randomButton:Show()

f.autoButton:ClearAllPoints()
f.autoButton:SetPoint("TOPLEFT", f, "TOPLEFT", 458, -100)
f.autoButton:SetWidth(82)
f.autoButton:SetHeight(20)
f.autoButton:Show()

f.nowBack:ClearAllPoints()
f.nowBack:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -364)
f.nowBack:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -20, -386)

f.nowStatusText:ClearAllPoints()
f.nowStatusText:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -369)
f.nowStatusText:SetWidth(72)

f.nowStationText:ClearAllPoints()
f.nowStationText:SetPoint("LEFT", f.nowStatusText, "RIGHT", 4, 0)
f.nowStationText:SetWidth(320)

f.customButton:ClearAllPoints()
f.customButton:SetPoint("TOPLEFT", f, "TOPLEFT", 355, -391)
f.customButton:SetWidth(88)
f.customButton:SetHeight(22)
f.customButton:Show()

f.pagePrev:ClearAllPoints()
f.pagePrev:SetPoint("TOPLEFT", f, "TOPLEFT", 449, -391)
f.pagePrev:SetWidth(44)
f.pagePrev:SetHeight(22)
f.pagePrev:Show()

f.pageNext:ClearAllPoints()
f.pageNext:SetPoint("TOPLEFT", f, "TOPLEFT", 496, -391)
f.pageNext:SetWidth(44)
f.pageNext:SetHeight(22)
f.pageNext:Show()

f.pageText:ClearAllPoints()
f.pageText:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -399)
f.pageText:SetWidth(330)
f.pageText:Show()

if f.sizer then f.sizer:Show() end

local tabX = 20
local tabY = -130
for _, tabInfo in ipairs(WR_TABS) do
local b = f.tabButtons[tabInfo.key]
if b then
b:ClearAllPoints()
b:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, tabY)
b:SetWidth(tabInfo.width)
b:SetHeight(20)
b:Show()
end
tabX = tabX + tabInfo.width + 5
end

for i = 1, WR_LINES_PER_PAGE do
local row = f.rows[i]
local y = -158 - ((i - 1) * 25)
row.star:ClearAllPoints()
row.star:SetPoint("TOPLEFT", f, "TOPLEFT", 20, y)
row.star:SetWidth(24)
row.star:SetHeight(20)
row.row:ClearAllPoints()
row.row:SetPoint("TOPLEFT", f, "TOPLEFT", 48, y)
row.row:SetWidth(485)
row.row:SetHeight(20)
end
end

f.fadeButton:ClearAllPoints()
f.fadeButton:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
f.fadeButton:SetWidth(46)
f.fadeButton:SetHeight(18)
end
