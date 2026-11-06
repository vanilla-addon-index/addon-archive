SLASH_STRATEGOSBGS1 = "/strbg"
SLASH_STRATEGOSBGS2 = "/sbg"
SLASH_STRATEGOSBGS3 = "/strategosbattleground"

local S, SB
if StrategosCore == nil then 
    StrategosCore = {}
end
S = StrategosCore

if StrategosBattleground == nil then 
    StrategosBattleground = {}
end
SB = StrategosBattleground

setmetatable(S, {__index = getfenv() })
setfenv(1, S)

setmetatable(SB, {__index = getfenv() })
setfenv(1, SB)

local SettingsWindow
local function UIInit()
    SettingsWindow = EFrame.Window()
    SettingsWindow.visible = false
    SettingsWindow.title = tr("SETTINGS_TITLE", "client")
    SettingsWindow.centralItem = EFrame.ColumnLayout(SettingsWindow)
    SettingsWindow.centralItem.spacing = 2
    
    local server = EFrame.Label(SettingsWindow.centralItem)
    server.text = tr("SETTINGS_SERVER_LANGUAGE", "client")
    
    SettingsWindow.serverLocales = SettingsWindow.style.ComboBox(SettingsWindow.centralItem)
    local serverLocales = {}
    for k in pairs(StrategosBattleground_ServerLocalizations) do
        tinsert(serverLocales, k)
        if StrategosBGProfile.serverLocalization == k then
            SettingsWindow.serverLocales.currentIndex = getn(serverLocales)
        end
    end
    SettingsWindow.serverLocales.model = serverLocales
    SettingsWindow.serverLocales:connect("activated", function(a) StrategosBGProfile.serverLocalization = serverLocales[a] if currentBattleground then currentBattleground:initLocale() end end)
        
    local general = EFrame.Label(SettingsWindow.centralItem)
    general.text = tr("SETTINGS_GENERAL_SECTION", "client")
    -- Auto Join
    local AutoJoinRow = EFrame.RowLayout(SettingsWindow.centralItem)
    AutoJoinRow.spacing = 2
    local AutoJoinCheck = EFrame.CheckButton(AutoJoinRow)
    AutoJoinCheck.text = tr("SETTINGS_AUTO_JOIN", "client")
    AutoJoinCheck.checked = StrategosBGSettings.autoJoin
    function AutoJoinCheck:onCheckedChanged(checked) StrategosBGSettings.autoJoin = checked end
    local AutoJoinGroupCheck = EFrame.CheckButton(AutoJoinRow)
    AutoJoinGroupCheck.enabled = AutoJoinCheck._checked
    AutoJoinGroupCheck.text = tr("SETTINGS_AUTO_JOIN_GROUP", "client")
    AutoJoinGroupCheck.checked = StrategosBGSettings.autoJoinAsGroup
    function AutoJoinGroupCheck:onCheckedChanged(checked) StrategosBGSettings.autoJoinAsGroup = checked end
    
    
    local wsg = EFrame.Label(SettingsWindow.centralItem)
    wsg.text = tr("SETTINGS_WSG_SECTION", "client")
    -- Carriers Side
    local WSGFlagSideRow = EFrame.RowLayout(SettingsWindow.centralItem)
    WSGFlagSideRow.spacing = 2
    local WSGFlagSideL = EFrame.Label(WSGFlagSideRow)
    WSGFlagSideL.text = tr("SETTINGS_WSG_CARRIERS_SIDE", "client")
    local WSGFlagSideBL = EFrame.RadioButton(WSGFlagSideRow)
    WSGFlagSideBL.checkable = true
    WSGFlagSideBL.text = tr("SETTINGS_WSG_CARRIERS_SIDE_LEFT", "client")
    WSGFlagSideBL.checked = StrategosWSGSettings.carriersToLeft
    local WSGFlagSideBR = EFrame.RadioButton(WSGFlagSideRow)
    WSGFlagSideBR.checkable = true
    WSGFlagSideBR.text = tr("SETTINGS_WSG_CARRIERS_SIDE_RIGHT", "client")
    WSGFlagSideBR.checked = not StrategosWSGSettings.carriersToLeft
    WSGFlagSideRow.autoExclusiveGroup:connect("currentChanged", function(c) StrategosWSGSettings.carriersToLeft = c == WSGFlagSideBL StrategosBattlegroundUIController.refreshWSGCarriersAnchorings() end)
    -- Carriers Style
    local WSGCarriersStyle = EFrame.RowLayout(SettingsWindow.centralItem)
    WSGCarriersStyle.spacing = 2
    local WSGCarriersStyleL = EFrame.Label(WSGCarriersStyle)
    WSGCarriersStyleL.text =  tr("SETTINGS_WSG_CARRIERS_HEALTH_STYLE", "client")
    local WSGCarriersStyleBC = EFrame.RadioButton(WSGCarriersStyle)
    WSGCarriersStyleBC.text = tr("SETTINGS_WSG_CARRIERS_HEALTH_STYLE_COLOR", "client")
    WSGCarriersStyleBC.checkable = true
    WSGCarriersStyleBC.checked = not StrategosWSGSettings.carriersBars
    local WSGCarriersStyleBB = EFrame.RadioButton(WSGCarriersStyle)
    WSGCarriersStyleBB.text = tr("SETTINGS_WSG_CARRIERS_HEALTH_STYLE_BAR", "client")
    WSGCarriersStyleBB.checkable = true
    WSGCarriersStyleBB.checked = StrategosWSGSettings.carriersBars
    WSGCarriersStyle.autoExclusiveGroup:connect("currentChanged", function(c) StrategosWSGSettings.carriersBars = c == WSGCarriersStyleBB end)
    -- Low Health Warnings
    local WSGWarn = EFrame.RowLayout(SettingsWindow.centralItem)
    WSGWarn.spacing = 2
    local WSGWarnL = EFrame.Label(WSGWarn)
    WSGWarnL.text = tr("SETTINGS_WSG_CARRIERS_HEALTH_WARNS", "client")
    local WSGWarnB = EFrame.CheckButton(WSGWarn)
    WSGWarnB.text = EFrame.bind(function() return WSGWarnB.checked and  tr("SETTINGS_WSG_CARRIERS_HEALTH_WARNS_ENABLED", "client") or  tr("SETTINGS_WSG_CARRIERS_HEALTH_WARNS_DISABLED", "client") end)
    WSGWarnB.checkable = true
    WSGWarnB.checked = StrategosWSGSettings.warnings
    WSGWarnB:connect("checkedChanged", function(c) StrategosWSGSettings.warnings = WSGWarnB.checked end)
    local WSGWarnA = EFrame.CheckButton(WSGWarn)
    WSGWarnA.text = tr("SETTINGS_WSG_CARRIERS_HEALTH_WARNS_NO_LINK", "client")
    WSGWarnA.checkable = true
    WSGWarnA.checked = not StrategosWSGSettings.warningsNoLink
    WSGWarnA:connect("checkedChanged", function(c) StrategosWSGSettings.warningsNoLink = not WSGWarnA.checked end)
    WSGWarnA.enabled = WSGWarnB._checked
    
    SettingsWindow.onVisibleChanged = function(self) if not self.visible then self:deleteLater() SettingsWindow = nil end end
    
end

local function chatcmd()
    if not SettingsWindow then
        UIInit()
    end
    SettingsWindow.visible = not SettingsWindow.visible
end

SlashCmdList["STRATEGOSBGS"] = chatcmd
