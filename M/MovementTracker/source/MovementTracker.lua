local GetPlayerMapPosition = GetPlayerMapPosition
local GetTime = GetTime
local UnitBuff = UnitBuff
local UnitOnTaxi = UnitOnTaxi
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local SetMapToCurrentZone = SetMapToCurrentZone
local CreateFrame = CreateFrame
local floor = math.floor
local sqrt = math.sqrt
local format = string.format
local strfind = string.find
local tinsert = table.insert
local UIParent = UIParent

local CONFIG = {
    frame_width = 290,
    frame_height = 165,
    update_interval = 0.1,
    ui_interval = 0.5,      
    min_speed = 0.1,
    max_speed = 30,
    color_text_norm = "|cffffffff",
    color_text_dist = "|cff69ccf0",
    color_label_dim = "|cffaaaaaa",
    icon_foot = "Interface\\AddOns\\MovementTracker\\boot.tga",
    icon_mount = "Interface\\AddOns\\MovementTracker\\horseshoe.tga"
}

MovementTracker = {};
local m = MovementTracker

if not MovementTracker_DB then MovementTracker_DB = {} end
if not MovementTracker_DB.totalTime then MovementTracker_DB.totalTime = 0; end
if not MovementTracker_DB.totalDistance then MovementTracker_DB.totalDistance = 0; end
if not MovementTracker_DB.totalMountedTime then MovementTracker_DB.totalMountedTime = 0; end
if not MovementTracker_DB.totalMountedDistance then MovementTracker_DB.totalMountedDistance = 0; end
if not MovementTracker_DB.framePosition then MovementTracker_DB.framePosition = { "CENTER", "CENTER", 0, 0 }; end

m.sessionTime = 0;
m.sessionDistance = 0;
m.sessionMountedTime = 0;
m.sessionMountedDistance = 0;

m.isMounted = false
m.zone_width = 0
m.zone_height = 0

m.prev_x = nil
m.prev_y = nil
m.prev_time = nil
m.ui_timer = 0

local api = getfenv(0);

local function SkinBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    });
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9);
    frame:SetBackdropBorderColor(0, 0, 0, 1);
end

local function CreateModernButton(name, parent, text, width, height)
    local btn = CreateFrame("Button", name, parent);
    btn:SetWidth(width);
    btn:SetHeight(height);
    
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    });
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1);
    btn:SetBackdropBorderColor(0, 0, 0, 1);

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(GameFontHighlightSmall)
    fs:SetPoint("CENTER", 0, 0)
    btn:SetFontString(fs)
    btn:SetText(text);

    btn:SetScript("OnEnter", function() 
        this:SetBackdropColor(0.3, 0.3, 0.3, 1);
        this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1);
    end);
    btn:SetScript("OnLeave", function() 
        this:SetBackdropColor(0.2, 0.2, 0.2, 1);
        this:SetBackdropBorderColor(0, 0, 0, 1);
    end);
    
    return btn;
end

function MovementTracker:UpdateZoneData()
    SetMapToCurrentZone()
    if ZONE_SIZES and ZONE_SIZES.get_current_zone_size then
        self.zone_width, self.zone_height = ZONE_SIZES:get_current_zone_size()
    else
        self.zone_width, self.zone_height = 0, 0
    end
end

function MovementTracker:UpdatePlayerState()
    local buff_index = 1
    self.isMounted = false

    while true do
        local texture = UnitBuff("player", buff_index)
        if not texture then return end

        self.tooltip:ClearLines()
        self.tooltip:SetUnitBuff("player", buff_index)

        local textLeft2 = api["MovementTrackerTooltipTextLeft2"]:GetText()
        if textLeft2 and (strfind(textLeft2, "Riding") or strfind(textLeft2, "Slow and steady...")) then
            self.isMounted = true
        end
        buff_index = buff_index + 1
    end
end

function MovementTracker:OnUpdate(elapsed)
    if not self.runSession then return end

    local x, y = GetPlayerMapPosition("player")
    local now = GetTime()

    if self.prev_x and self.prev_y and self.prev_time then
        local dt = now - self.prev_time
        
        if dt > CONFIG.update_interval then
            local width, height = self.zone_width, self.zone_height
            if width and height and width > 0 and height > 0 and x and y and (x ~= 0 or y ~= 0) then
                local dx = (x - self.prev_x) * width
                local dy = (y - self.prev_y) * height
                local dist = sqrt(dx * dx + dy * dy)
                local speed = dist / dt

                if speed > CONFIG.min_speed and speed < CONFIG.max_speed and not UnitOnTaxi("player") and not UnitIsDeadOrGhost("player") then
                    if self.isMounted then
                        MovementTracker_DB.totalMountedTime = MovementTracker_DB.totalMountedTime + dt
                        MovementTracker_DB.totalMountedDistance = MovementTracker_DB.totalMountedDistance + dist
                        self.sessionMountedTime = self.sessionMountedTime + dt
                        self.sessionMountedDistance = self.sessionMountedDistance + dist
                    else
                        MovementTracker_DB.totalTime = MovementTracker_DB.totalTime + dt
                        MovementTracker_DB.totalDistance = MovementTracker_DB.totalDistance + dist
                        self.sessionTime = self.sessionTime + dt
                        self.sessionDistance = self.sessionDistance + dist
                    end
                end
            end
            self.prev_x, self.prev_y, self.prev_time = x, y, now
            
            self.ui_timer = self.ui_timer + dt
            if self.ui_timer >= CONFIG.ui_interval then
                self:UpdateDisplay()
                self.ui_timer = 0
            end
        end
    else
        self.prev_x, self.prev_y, self.prev_time = x, y, now
    end
end

function MovementTracker:CreateFrame()
    self.frame = CreateFrame("Frame", "MovementTrackerFrame", UIParent);
    self.frame:SetWidth(CONFIG.frame_width);
    self.frame:SetHeight(CONFIG.frame_height);
    self.frame:SetClampedToScreen(true);
    
    SkinBackdrop(self.frame)

    self.tooltip = CreateFrame("GameTooltip", "MovementTrackerTooltip", UIParent, "GameTooltipTemplate");
    self.tooltip:SetOwner(WorldFrame, "ANCHOR_NONE");

    if ( not MovementTracker_DB.framePosition or table.getn(MovementTracker_DB.framePosition) ~= 4 or type(MovementTracker_DB.framePosition[1]) ~= "string" ) then
        MovementTracker_DB.framePosition = { "CENTER", "CENTER", 0, 0 };
    end
    self.frame:SetPoint(
        MovementTracker_DB.framePosition[1], UIParent, MovementTracker_DB.framePosition[2],
        MovementTracker_DB.framePosition[3], MovementTracker_DB.framePosition[4]
    );

    self.frame:SetMovable(true);
    self.frame:EnableMouse(true);
    self.frame:RegisterForDrag("LeftButton");
    self.frame:SetScript("OnDragStart", function() if (arg1 == "LeftButton") then this:StartMoving(); end end);
    self.frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing();
        local point, _, relativePoint, xOfs, yOfs = this:GetPoint();
        MovementTracker_DB.framePosition = { point, relativePoint, xOfs, yOfs };
    end);

    local titleBg = self.frame:CreateTexture(nil, "BACKGROUND")
    titleBg:SetTexture(0, 0, 0, 0.5)
    titleBg:SetPoint("TOPLEFT", 1, -1)
    titleBg:SetPoint("TOPRIGHT", -1, -1)
    titleBg:SetHeight(20)

    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    self.frame.title:SetPoint("TOP", 0, -5);
    self.frame.title:SetText("Movement Tracker");

    self.frame.closeButton = CreateFrame("Button", nil, self.frame);
    self.frame.closeButton:SetWidth(16);
    self.frame.closeButton:SetHeight(16);
    self.frame.closeButton:SetPoint("TOPRIGHT", -4, -3);
    
    local closeFs = self.frame.closeButton:CreateFontString(nil, "OVERLAY")
    closeFs:SetFontObject(GameFontNormal)
    closeFs:SetPoint("CENTER", 0, 0)
    self.frame.closeButton:SetFontString(closeFs)
    self.frame.closeButton:SetText("X");
    self.frame.closeButton:SetScript("OnClick", function() MovementTracker.frame:Hide(); end);

    local function createStatBlock(parent, labelText, xOffset, yOffset, iconPath)
        local icon = parent:CreateTexture(nil, "OVERLAY");
        icon:SetTexture(iconPath);
        icon:SetWidth(20);
        icon:SetHeight(20);
        icon:SetPoint("TOPLEFT", xOffset, yOffset);

        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
        header:SetPoint("LEFT", icon, "RIGHT", 6, 0);
        header:SetText(labelText);
        
        local sessionLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        sessionLbl:SetText(CONFIG.color_label_dim .. "Session:|r");
        sessionLbl:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6);
        
        local sessionVal = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        sessionVal:SetPoint("LEFT", sessionLbl, "RIGHT", 4, 0);
        
        local totalLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        totalLbl:SetText(CONFIG.color_label_dim .. "Total:|r");
        totalLbl:SetPoint("TOPLEFT", sessionLbl, "BOTTOMLEFT", 0, -2);
        
        local totalVal = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
        totalVal:SetPoint("LEFT", totalLbl, "RIGHT", 16, 0);

        return sessionVal, totalVal
    end

    self.runSession, self.runTotal = createStatBlock(self.frame, "On Foot", 20, -30, CONFIG.icon_foot);
    self.mountSession, self.mountTotal = createStatBlock(self.frame, "Mounted", 150, -30, CONFIG.icon_mount);

    local line = self.frame:CreateTexture(nil, "ARTWORK");
    line:SetTexture(1, 1, 1, 0.2);
    line:SetHeight(1);
    line:SetPoint("TOPLEFT", 10, -95);
    line:SetPoint("TOPRIGHT", -10, -95);

    self.grandTotalLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    self.grandTotalLabel:SetPoint("TOP", 0, -105);
    self.grandTotalLabel:SetText("Total Traveled");

    self.grandTotalValue = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    self.grandTotalValue:SetPoint("TOP", self.grandTotalLabel, "BOTTOM", 0, -2);

    local resetSessionBtn = CreateModernButton("MTResetSession", self.frame, "Reset Session", 100, 20);
    resetSessionBtn:SetPoint("BOTTOMLEFT", 10, 8);
    resetSessionBtn:SetScript("OnClick", function() 
        StaticPopup_Show("MOVEMENTTRACKER_CONFIRM_RESET_SESSION");
    end);

    local resetAllBtn = CreateModernButton("MTResetAll", self.frame, "Reset All", 100, 20);
    resetAllBtn:SetPoint("BOTTOMRIGHT", -10, 8);
    resetAllBtn:SetScript("OnClick", function() 
        StaticPopup_Show("MOVEMENTTRACKER_CONFIRM_RESET_ALL");
    end);

    self.frame:Hide();
end

function MovementTracker:FormatTime(seconds)
    if not seconds or seconds < 0 then return "0s"; end
    seconds = floor(seconds);
    local m = floor(seconds / 60);
    local h = floor(m / 60);

    seconds = seconds - (floor(seconds / 60) * 60);
    m = m - (floor(m / 60) * 60);

    local color = CONFIG.color_text_norm; 
    if h > 0 then return format("%s%dh %dm|r", color, h, m)
    elseif m > 0 then return format("%s%dm %ds|r", color, m, seconds)
    else return format("%s%ds|r", color, seconds) end
end

function MovementTracker:FormatDistance(meters)
    if not meters then return "0 m"; end
    
    local color = CONFIG.color_text_dist; 
    if meters >= 1000 then
        return format("%s%.2f km|r", color, meters / 1000);
    else
        return format("%s%d m|r", color, floor(meters));
    end
end

function MovementTracker:UpdateDisplay()
    if not self.frame or not self.frame:IsVisible() then return; end
    if not self.runSession then return end 

    self.runSession:SetText(self:FormatTime(self.sessionTime) .. "  [" .. self:FormatDistance(self.sessionDistance) .. "]");
    self.runTotal:SetText(self:FormatTime(MovementTracker_DB.totalTime) .. "  [" .. self:FormatDistance(MovementTracker_DB.totalDistance) .. "]");

    self.mountSession:SetText(self:FormatTime(self.sessionMountedTime) .. "  [" .. self:FormatDistance(self.sessionMountedDistance) .. "]");
    self.mountTotal:SetText(self:FormatTime(MovementTracker_DB.totalMountedTime) .. "  [" .. self:FormatDistance(MovementTracker_DB.totalMountedDistance) .. "]");

    local grandTotalTime = MovementTracker_DB.totalTime + MovementTracker_DB.totalMountedTime;
    local grandTotalDist = MovementTracker_DB.totalDistance + MovementTracker_DB.totalMountedDistance;
    self.grandTotalValue:SetText(self:FormatTime(grandTotalTime) .. "  [" .. self:FormatDistance(grandTotalDist) .. "]");
end

function MovementTracker:ResetSessionStats()
    self.sessionTime = 0; self.sessionDistance = 0;
    self.sessionMountedTime = 0; self.sessionMountedDistance = 0;
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080Movement|rTracker: Session stats reset.");
    self:UpdateDisplay();
end

function MovementTracker:ResetAllStats()
    MovementTracker_DB.totalTime = 0; MovementTracker_DB.totalDistance = 0;
    MovementTracker_DB.totalMountedTime = 0; MovementTracker_DB.totalMountedDistance = 0;
    self:ResetSessionStats();
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080Movement|rTracker: All stats reset.");
end

function MovementTracker:Initialize()
    tinsert(UISpecialFrames, "MovementTrackerFrame");
    
    StaticPopupDialogs["MOVEMENTTRACKER_CONFIRM_RESET_SESSION"] = {
        text = "Are you sure you want to reset session stats?",
        button1 = TEXT(YES),
        button2 = TEXT(NO),
        OnAccept = function()
            MovementTracker:ResetSessionStats()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    };

    StaticPopupDialogs["MOVEMENTTRACKER_CONFIRM_RESET_ALL"] = {
        text = "Are you sure you want to reset ALL stats?\nThis will clear Session AND Total history.",
        button1 = TEXT(YES),
        button2 = TEXT(NO),
        OnAccept = function()
            MovementTracker:ResetAllStats()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        showAlert = 1,
    };
    
    SlashCmdList["MOVEMENTTRACKER"] = function(msg)
        if msg == "reset" then
            StaticPopup_Show("MOVEMENTTRACKER_CONFIRM_RESET_SESSION");
        else
            if MovementTracker.frame:IsShown() then MovementTracker.frame:Hide(); else MovementTracker.frame:Show(); end
        end
    end
    SLASH_MOVEMENTTRACKER1 = "/movementtracker";
    SLASH_MOVEMENTTRACKER2 = "/mt";
    
    self:UpdateZoneData()
    self:UpdatePlayerState()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080Movement|rTracker: loaded. Type /mt to toggle.");
end

function MovementTracker:OnEvent(event)
    if event == "ADDON_LOADED" and arg1 == "MovementTracker" then
        self:CreateFrame(); self:Initialize();
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UpdateZoneData(); self:UpdatePlayerState();
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED" then
        self:UpdateZoneData();
    elseif event == "PLAYER_AURAS_CHANGED" then
        self:UpdatePlayerState();
    end
end

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS");
eventFrame:RegisterEvent("ZONE_CHANGED");
eventFrame:RegisterEvent("PLAYER_AURAS_CHANGED");

eventFrame:SetScript("OnEvent", function() MovementTracker:OnEvent(event) end);
eventFrame:SetScript("OnUpdate", function() MovementTracker:OnUpdate(arg1) end);