-- An addon for Turtle-Wow HC that announces when a guild member dies, levels up, becomes Immortal, or enters the Inferno challenge, and keeps logs of these events.

CliffTells = CreateFrame("frame")
CliffTells.List = CreateFrame("Frame","CTL",UIParent)
CliffTells.Minimap = CreateFrame("Frame","CTM",Minimap)

-- Version from .toc file
CLIFFTELLS_VERSION = GetAddOnMetadata("CliffTells", "Version") -- Grab version from .toc

CliffTells:RegisterEvent("ADDON_LOADED") -- Register event when addon is loaded
CliffTells:RegisterEvent("PLAYER_LOGIN")
CliffTells:RegisterEvent("CHAT_MSG_SYSTEM")
CliffTells:RegisterEvent("GUILD_ROSTER_UPDATE")
CliffTells:RegisterEvent("PLAYER_LEVEL_UP")
CliffTells:RegisterEvent("CHAT_MSG_ADDON")
CliffTells:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLY_DEATH")

-- Colors
local LIGHTRED             				= "|cffff6060"
local LIGHTBLUE          			 	= "|cff00ccff"
local TORQUISEBLUE	 					= "|cff00C78C"
local SPRINGGREEN	  					= "|cff00FF7F"
local GREENYELLOW    					= "|cffADFF2F"
local BLUE                 				= "|cff0000ff"
local PURPLE		    				= "|cffDA70D6"
local GREEN	        					= "|cff00ff00"
local RED             					= "|cffff0000"
local GOLD            					= "|cffffcc00"
local GOLD2								= "|cffFFC125"
local GRAY           	 				= "|cff888888"
local WHITE           					= "|cffffffff"
local SUBWHITE        					= "|cffbbbbbb"
local MAGENTA         					= "|cffff00ff"
local YELLOW          					= "|cffffff00"
local ORANGE		    				= "|cffFF4500"
local CHOCOLATE							= "|cffCD661D"
local CYAN            					= "|cff00ffff"
local IVORY								= "|cff8B8B83"
local LIGHTYELLOW	    				= "|cffFFFFE0"
local SEXGREEN							= "|cff71C671"
local SEXTEAL		    				= "|cff388E8E"
local SEXPINK		    				= "|cffC67171"
local SEXBLUE		    				= "|cff00E5EE"
local SEXHOTPINK	    				= "|cffFF6EB4"

local HUNTER 							= "|cffABD473"
local WARLOCK 							= "|cff9482C9"
local PRIEST 							= "|cffFFFFFF"
local PALADIN 							= "|cffF58CBA"
local MAGE 								= "|cff69CCFF"
local ROGUE 							= "|cffFFF569"
local DRUID 							= "|cffFF7D0A"
local SHAMAN 							= "|cff0070DD"
local WARRIOR 							= "|cffC79C6E"

local COLOREND 							= "|r"

local pingdelay                         = GetTime()
local latestdate                        = "Not Available"
local isEventActive                     = false
local alreadyshown                      = false

CLIFFTELLS_VERSION_MSG = LIGHTBLUE..CLIFFTELLS_VERSION..COLOREND

-- Tables
local CliffTells_Frames 			    = {};
local CliffTells_SyncGuild              = {};
local CliffTells_ChatFrameHooks			= {};

CT_Settings = CT_Settings or {}

CT_List = CT_List or {
    dings = {},
    deaths = {},
    immortals = {},
    infernos = {},
    infernodeaths = {},
    myself = {}
}

-- Welcome guild messages
CliffTells__GreetMessages1 = {
	[1] = "Greetings",
	[2] = "Hello and welcome",
	[3] = "Howdy",
	[4] = "Salutations",
	[5] = "Welcome",
}

CliffTells__GreetMessages2 = {
    [1] = "The guild is stronger with you among us.",
    [2] = "We’re excited to have you join our ranks.",
    [3] = "Ready to embark on epic quests with us?",
    [4] = "Your journey in the Hardcore Leveling Guild begins now.",
    [5] = "Together, we shall conquer the challenges of Azeroth.",
    [6] = "Adventure awaits!",
    [7] = "Your skills will shine bright in our guild.",
    [8] = "Let’s forge unforgettable memories together.",
    [9] = "Join us as we write our own legend!",
    [10] = "Strength in numbers! We’re glad to have you.",
    [11] = "Prepare for challenges and triumphs alike!",
    [12] = "Your adventure begins here, let’s make it epic!",
    [13] = "Together, we’ll tackle every quest that comes our way.",
    [14] = "Your journey is about to get exciting.",
    [15] = "We believe in you and your abilities!",
    [16] = "Step into a world of camaraderie and adventure.",
    [17] = "Your presence adds to our guild's glory.",
    [18] = "Let’s support each other in every quest!",
    [19] = "Let the adventure begin!",
    [20] = "Here’s to new friendships and great battles!",
    [21] = "With you here, our guild is unstoppable.",
    [22] = "Unleash your potential with us by your side.",
    [23] = "Get ready for some epic raids and adventures!",
    [24] = "Every hero needs a guild, thank you for choosing us!",
    [25] = "We’re thrilled to have you join our ranks!",
    [26] = "Your journey is just starting, let’s make it legendary.",
    [27] = "Adventure awaits, and we’re glad you’re here!",
    [28] = "In this guild, every member matters!",
    [29] = "Together, we'll achieve greatness!",
    [30] = "Your epic journey starts now, welcome!"
}

-- Rip Messages
CliffTells__RipMessages = {
	[1] = "You barely started your journey..",
    [2] = "Gone too soon, may your spirit find peace in the afterlife.",
    [3] = "Your adventure has come to an unexpected end. Rest well!",
    [4] = "Farewell, your legend begins and ends here.",
    [5] = "You fought valiantly, the world will remember you.",
    [6] = "You faced the challenges with courage.",
    [7] = "Your journey ends here, but your tale lives on.",
    [8] = "Farewell, brave adventurer, you will be missed!",
    [9] = "Your story was cut short, champion.",
    [10] = "The battles you fought will echo through time.",
    [11] = "You faced the darkness bravely.",
    [12] = "Your journey took an untimely turn. Rest easy, hero.",
    [13] = "Farewell adventurer, you were destined for greatness.",
    [14] = "You met your end, but your spirit will inspire others.",
    [15] = "Your legacy will endure.",
    [16] = "You fought hard but fell too soon.",
    [17] = "Your journey ended. Your bravery will not be forgotten.",
    [18] = "Your name will live on in the tales of old.",
    [19] = "You faced your fate with honor.",
    [20] = "You may have fallen, but your spirit remains unbroken.",
    [21] = "Your courage inspired many.",
    [22] = "Your journey ended. May your soul find peace.",
    [23] = "Farewell, brave adventurer, you fought with valor.",
    [24] = "Gone too soon, your legacy is etched in our hearts.",
    [25] = "Your spirit will guide others onward.",
    [26] = "Your journey was epic, but it ends here.",
    [27] = "You faced the ultimate challenge, hero.",
    [28] = "Your story will echo through time.",
    [29] = "You fell, but your achievements will inspire generations.",
    [30] = "Gone, but your courage will be remembered forever."
}

-- Ding Messages
CliffTells__DingMessages = {
    [1] = "The adventure continues!",
    [2] = "Looks great on you!",
    [3] = "Keep pushing forward!",
    [4] = "Just the beginning of your epic journey!",
    [5] = "You've made it this far! The world awaits!",
    [6] = "This is an impressive milestone!",
    [7] = "Keep it up!",
    [8] = "This is a great accomplishment!",
    [9] = "Let’s celebrate!",
    [10] = "It's a testament to your hard work!",
	[11] = "Keep soaring!",
    [12] = "This is a mark of your dedication!",
    [13] = "Well played, the adventure is just beginning!",
    [14] = "Reaching this level is no small feat!",
    [15] = "Shows your commitment to greatness!",
    [16] = "Onward to new challenges!",
    [17] = "Keep the momentum going!",
    [18] = "This is just another milestone!",
    [19] = "The journey continues!",
    [20] = "Keep shining bright!",
    [21] = "This level suits you perfectly!",
    [22] = "The world is yours!",
    [23] = "A testament to your skill!",
    [24] = "A sign of your perseverance!",
    [25] = "Keep pushing forward!",
    [26] = "The best is yet to come!",
    [27] = "An incredible milestone!",
    [28] = "Keep aiming higher!",
    [29] = "Proof of your hard work!",
    [30] = "Keep exploring new horizons!"
}

CliffTells__Ding50Messages = {
    [1] = "Just 10 levels left to ultimate glory!",
    [2] = "Only 10 more levels to go!",
    [3] = "Just 10 levels stand between you and greatness!",
    [4] = "Only 10 levels left to conquer!",
    [5] = "Just 10 more levels of your epic journey!"
}

CliffTells__ImmortalMessages = {
    [1] = "You've ascended to greatness!",
    [2] = "A legendary achievement! The pinnacle of your journey!",
    [3] = "Your legacy is just beginning!",
    [4] = "You've reached the summit! You shine like no other!",
    [5] = "This is where legends are born!",
    [6] = "Your journey has culminated in immortality! Bravo!",
    [7] = "Unstoppable! You've become a beacon of excellence!",
    [8] = "The highest honor is yours! You inspire us all!",
    [9] = "Your hard work has paid off!",
    [10] = "You've carved your name in the annals of greatness!"
}

CliffTells__InfernoDeathMessages = {
    [1] = "Even in defeat, your spirit burns bright! Inferno never fades!",
    [2] = "You faced the flames valiantly! The fire of Inferno lives on!",
    [3] = "A noble end! Your Inferno legacy will inspire others!",
    [4] = "You fought fiercely! Inferno may fall, but the fire remains!",
    [5] = "In the face of challenge, you shone brightly! Inferno lives on!",
    [6] = "Your journey as Inferno was legendary! Rest in the flames!",
    [7] = "Defeated, but never forgotten! The Inferno within you endures!",
    [8] = "You've burned with passion! Even in loss, you are Inferno!",
    [9] = "A fiery end to a blazing journey! Your Inferno legacy continues!",
    [10] = "The flames may have dimmed, but your Inferno spirit is eternal!"
}

local function print(msg)
	if msg then
		DEFAULT_CHAT_FRAME:AddMessage(DRUID.."Cliff"..GREEN.."Tells"..COLOREND.." - "..msg)
	end
end

local function AddMessage(self, message, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
    if CT_Settings["hidefromchat"] then
        CT_Settings["hidefromchat"] = false
      return
    end
  
    if self and CliffTells_ChatFrameHooks[self] and message then
      return CliffTells_ChatFrameHooks[self](self, message, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9);
    end
end

-- UI tooltip
function CliffTells_ShowToolTip(object, message, message1, message2)
	GameTooltip:SetOwner(object, "ANCHOR_CURSOR");
	GameTooltip:SetText(message);
	GameTooltip:AddLine(message1, 255,71,9,2);
	GameTooltip:AddLine(message2, 0.99, 0.99, 0.59,1);
	GameTooltip:Show();
end

function CliffTells_HideToolTip()
	GameTooltip:Hide();
end

function CliffTells:GetClassColorForName(class)
	if class == "Warrior" then return WARRIOR
	elseif class == "Hunter" then return HUNTER
	elseif class == "Mage" then return MAGE
	elseif class == "Rogue" then return ROGUE
	elseif class == "Warlock" then return WARLOCK
	elseif class == "Druid" then return DRUID
	elseif class == "Shaman" then return SHAMAN
	elseif class == "Priest" then return PRIEST
	elseif class == "Paladin" then return PALADIN
	end
end

function CliffTells:ClassPos(class)
	if(class=="Warrior") then return 0, 0.25, 0, 0.25;	end
	if(class=="Mage")    then return 0.25, 0.5, 0,	0.25;	end
	if(class=="Rogue")   then return 0.5,  0.75,    0,	0.25;	end
	if(class=="Druid")   then return 0.75, 1,       0,	0.25;	end
	if(class=="Hunter")  then return 0,    0.25,    0.25,	0.5;	end
	if(class=="Shaman")  then return 0.25, 0.5,     0.25,	0.5;	end
	if(class=="Priest")  then return 0.5,  0.75,    0.25,	0.5;	end
	if(class=="Warlock") then return 0.75, 1,       0.25,	0.5;	end
	if(class=="Paladin") then return 0,    0.25,    0.5,	0.75;	end
	return 0.25, 0.5, 0.5, 0.75	-- Returns empty next one, so blank
end

function CliffTells:GetLevelColor(level)
	local colorlevel = GREEN..level
		if tonumber(level) < 11 then 
			colorlevel = GRAY..level
		elseif tonumber(level) >= 11 and tonumber(level) < 21 then
			colorlevel = WHITE..level
		elseif tonumber(level) >= 21 and tonumber(level) < 31 then
			colorlevel = GREEN..level
		elseif tonumber(level) >= 31 and tonumber(level) < 41 then
			colorlevel = YELLOW..level
		elseif tonumber(level) >= 41 and tonumber(level) < 51 then
			colorlevel = ORANGE..level
		elseif tonumber(level) >= 51 and tonumber(level) < 60 then
			colorlevel = RED..level
		elseif tonumber(level) > 59 then
			colorlevel = PURPLE..level
		end
	return colorlevel
end

function CliffTells:SendLineToChat(text)
	local channel, chatnumber = ChatFrameEditBox.chatType
	if channel == "WHISPER" then
		chatnumber = ChatFrameEditBox.tellTarget
	elseif channel == "CHANNEL" then
		chatnumber = ChatFrameEditBox.channelTarget
	end
	if string.sub(text, 13, 13) == ":" then
		local timestring = string.sub(text, 11, 18);
		local logstring = string.sub(text, 22);
		SendChatMessage(timestring.." - "..logstring, channel, nil, chatnumber)
	else
		local logstring = tostring(text)
		SendChatMessage(logstring, channel, nil, chatnumber)
	end
end

function CliffTells:OnAddonMessage(prefix, message, name)
    if prefix == "CliffTellsPing" then

        local nameExists = false
        for k, v in pairs(CliffTells_SyncGuild) do
            if v == name then
                nameExists = true
                break  -- Exit the loop early since we found the name
            end
        end
        
        if not nameExists then
            table.insert(CliffTells_SyncGuild, name)
        end

        table.sort(CliffTells_SyncGuild, function(a, b)
            return a < b  -- Sorts in ascending order
        end)
        return
    end
end

function CliffTells:RemoveFromSyncTable(name)
    local i = 0
    for _,value in pairs(CliffTells_SyncGuild) do
        i = i + 1
        if value == name then
            table.remove(CliffTells_SyncGuild, i)
        end
    end
end

function CliffTells.Minimap:CreateMinimapIcon()
	local Moving = false
	
	function self:OnMouseUp()
		Moving = false;
	end
	
	function self:OnMouseDown()
		PlaySound("igMainMenuOptionCheckBoxOn")
		Moving = false;
		if (arg1 == "LeftButton") then 
			if CliffTells.List:IsVisible() then 
				CliffTells.List:Hide()
			else
				CliffTells.List:Show()
                CliffTells:MenuHandler()
			end
		else Moving = true;
		end
	end
	
	function self:OnUpdate()
		if Moving == true then
			local xpos,ypos = GetCursorPosition();
			local xmin,ymin = CliffTells.Minimap:GetLeft(), CliffTells.Minimap:GetBottom();
			xpos = xmin-xpos/UIParent:GetScale()+70;
			ypos = ypos/UIParent:GetScale()-ymin-70;
			local CTIconPos = math.deg(math.atan2(ypos,xpos));
			if (CTIconPos < 0) then
				CTIconPos = CTIconPos + 360
			end
			CT_Settings["MinimapX"] = 54 - (78 * cos(CTIconPos));
			CT_Settings["MinimapY"] = (78 * sin(CTIconPos)) - 55;
			
			CliffTells.Minimap:SetPoint(
			"TOPLEFT",
			"Minimap",
			"TOPLEFT",
			CT_Settings["MinimapX"],
			CT_Settings["MinimapY"]);
		end
	end
	
	function self:OnEnter()
		GameTooltip:SetOwner(CliffTells.Minimap, "ANCHOR_LEFT");
		GameTooltip:SetText(DRUID.."Cliff"..GREEN.."Tells "..COLOREND.."v."..CLIFFTELLS_VERSION_MSG);
		GameTooltip:AddDoubleLine("Toggle CliffTells", "Left-Click", 1,1,1,1,1,1);
		GameTooltip:AddDoubleLine("Drag", "Right-Click", 1,1,1,1,1,1);
		GameTooltip:Show()
	end
	
	function self:OnLeave()
		CliffTells_HideToolTip()
	end

	self:SetFrameStrata("LOW")
	self:SetWidth(31)
	self:SetHeight(31)
	self:SetPoint("CENTER", -75, -20)
	
	self.Button = CreateFrame("Button",nil,self)
	--self.Button:SetFrameStrata('HIGH')	
	self.Button:SetPoint("CENTER",0,0)
	self.Button:SetWidth(31)
	self.Button:SetHeight(31)
	self.Button:SetFrameLevel(8)
	self.Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	self.Button:SetScript("OnMouseUp", self.OnMouseUp)
	self.Button:SetScript("OnMouseDown", self.OnMouseDown)
	self.Button:SetScript("OnUpdate", self.OnUpdate)
	self.Button:SetScript("OnEnter", self.OnEnter)
	self.Button:SetScript("OnLeave", self.OnLeave)
	
	local overlay = self:CreateTexture(nil, 'OVERLAY',self)
	overlay:SetWidth(53)
	overlay:SetHeight(53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint('TOPLEFT',0,0)
	
	local icon = self:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-Monster")
	icon:SetTexCoord(0.18, 0.82, 0.18, 0.82)
	icon:SetPoint('CENTER', 0, 0)
	self.icon = icon
	
	if CT_Settings["MinimapX"] and CT_Settings["MinimapY"] then
        CliffTells.Minimap:SetPoint(
            "TOPLEFT",
            "Minimap",
            "TOPLEFT",
            CT_Settings["MinimapX"],
            CT_Settings["MinimapY"]);
	end
	--self:Hide()
end

function CliffTells:CreateCheckbox(name,tab,text, tooltiptext)

	local MyCheckbox = CreateFrame("CheckButton", name, tab, "UICheckButtonTemplate")
	MyCheckbox:SetPoint("CENTER",0,80)
	MyCheckbox:SetWidth(35)
	MyCheckbox:SetHeight(35)
	MyCheckbox:SetFrameStrata("MEDIUM")
    MyCheckbox:SetScript("OnClick", function () 
        if MyCheckbox:GetChecked() == nil then 
            CT_Settings[name] = nil
        elseif MyCheckbox:GetChecked() == 1 then 
            CT_Settings[name] = 1
        end
    end)
    MyCheckbox:SetScript("OnEnter", function()
        CliffTells_ShowToolTip(self, tooltiptext)  -- Show the specific tooltip
    end)

    -- Button hover out effects
    MyCheckbox:SetScript("OnLeave", function()
        CliffTells_HideToolTip()
    end)
    MyCheckbox:SetChecked(CT_Settings[name])
	MyCheckbox.text = MyCheckbox:CreateFontString(nil, "OVERLAY")
	MyCheckbox.text:SetPoint("TOP",0,20)
	MyCheckbox.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
	MyCheckbox.text:SetTextColor(255,255,0, 1)
	MyCheckbox.text:SetShadowOffset(2,-2)
	MyCheckbox.text:SetText(text)
    return MyCheckbox
end

function CliffTells:CreateEditbox(name,tab,text)

	local MyEditbox = CreateFrame("EditBox", name, tab, "InputBoxTemplate")
    MyEditbox:SetFontObject("GameFontHighlight")
    MyEditbox:SetFrameStrata("MEDIUM")
    MyEditbox:SetPoint("BOTTOM",0,-40)
    MyEditbox:SetWidth(140)
    MyEditbox:SetHeight(30)
    MyEditbox:SetAutoFocus(false)
    MyEditbox:SetText("")

    MyEditbox.text = MyEditbox:CreateFontString(nil, "OVERLAY")
    MyEditbox.text:SetPoint("TOP",0,10)
    MyEditbox.text:SetFont("Fonts\\FRIZQT__.TTF", 10)
    MyEditbox.text:SetTextColor(255, 255, 0, 1)
    MyEditbox.text:SetShadowOffset(2,-2)
    MyEditbox.text:SetText(text)
    return MyEditbox
end

function CliffTells.List:Gui()
    CliffTells.List.Drag = { }
    function CliffTells.List.Drag:StartMoving()
        this:StartMoving()
    end

    function CliffTells.List.Drag:StopMovingOrSizing()
        this:StopMovingOrSizing()
    end

    -- Close with esc button
    tinsert(UISpecialFrames, self:GetName())

    local backdrop = {
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    }
    self:SetFrameStrata("BACKGROUND")
    self:SetWidth(340)
    self:SetHeight(425)
    self:SetPoint("CENTER",0,0)
    self:SetMovable(1)
    self:EnableMouse(1)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", CliffTells.List.Drag.StartMoving)
    self:SetScript("OnDragStop", CliffTells.List.Drag.StopMovingOrSizing)

    self.Background = {}
    for _, position in ipairs({"Topleft", "Topright", "Bottomleft", "Bottomright"}) do
        self.Background[position] = CreateFrame("Frame", nil, self)
    end

    for i = 1, 7 do
        self.Background["Tab" .. i .. "buttonbg"] = CreateFrame("Frame", nil, self)
        self.Background["Tab" .. i] = CreateFrame("Frame", nil, self)
        self.Background["Button" .. i] = CreateFrame("Button", nil, self)
    end

    local function CreateTitleText(parent, point, fontSize, text)
        local fontString = parent:CreateFontString(nil, "OVERLAY")
        fontString:SetPoint(unpack(point))
        fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
        fontString:SetTextColor(255, 255, 0, 1)
        fontString:SetShadowOffset(2, -2)
        fontString:SetText(text)
        return fontString
    end
    
    -- Title text
    local HeadText = CreateTitleText(self.Background.Topleft, {"TOPRIGHT", -22, -17}, 15, DRUID.."Cliff"..GREEN.."Tells"..COLOREND.." - List")
    
    -- Version text
    local VersionText = CreateTitleText(self.Background.Topleft, {"TOPRIGHT", 55, -19}, 10, "v."..CLIFFTELLS_VERSION_MSG)
    
    -- Tab text
    local TabText = CreateTitleText(self.Background.Topleft, {"CENTER", HeadText, "CENTER", 0, -35}, 15, "Dings")

    -- a texture 
    self.Icon = self:CreateTexture(nil, 'ARTWORK')
    self.Icon:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-Monster")
    self.Icon:SetWidth(60)
    self.Icon:SetHeight(60)
    self.Icon:SetPoint("TOPLEFT",-2,8)

    -- button close
    self.CloseButton = CreateFrame("Button",CloseButton,self,"UIPanelCloseButton")
    self.CloseButton:SetPoint("TOPRIGHT",4,4)
    self.CloseButton:SetFrameStrata("LOW")
    self.CloseButton:SetWidth(32)
    self.CloseButton:SetHeight(32)
    self.CloseButton:SetText("")
    self.CloseButton:SetScript("OnLoad", function() PlaySound("igMainMenuOptionCheckBoxOn"); CliffTells.List:Hide() end)
    self:Hide()

    local backdropFiles = {
        Topleft = "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft",
        Topright = "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight",
        Bottomleft = "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft",
        Bottomright = "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight",
    }
    
    local framePositions = {
        Topleft = {-10, 13, 256, 256},
        Topright = {246, 13, 128, 256},
        Bottomleft = {-10, -243, 256, 256},
        Bottomright = {246, -243, 128, 256},
    }
    
    for position, backdropFile in pairs(backdropFiles) do
        local frame = self.Background[position]
        local positionData = framePositions[position]
        
        frame:SetFrameStrata("BACKGROUND")
        frame:SetWidth(positionData[3])
        frame:SetHeight(positionData[4])
        frame:SetBackdrop({bgFile = backdropFile})
        frame:SetPoint("TOPLEFT", positionData[1], positionData[2])
    end

    -- Set spacing between tabs and buttons (adjust the distance as needed)
    local backdrop = {bgFile = "Interface\\SPELLBOOK\\SpellBook-SkillLineTab"}
    local spacing = -50  -- Base distance between each tab and button (adjust as needed)

    -- Create tab backgrounds with spacing
    for i = 1, 7 do
        local tab = self.Background["Tab" .. i .. "buttonbg"]
        tab:SetFrameStrata("LOW")
        tab:SetWidth(64)
        tab:SetHeight(64)
        tab:SetBackdrop(backdrop)
        tab:SetPoint("TOPRIGHT", 61, spacing * i)  -- Apply spacing for tabs
    end

    -- Define the CreateTabButton function
    local function CreateTabButton(tab, button, glow, glowHide, tooltipText, buttonSpacing, texture)
        -- Tab frame setup
        tab:SetFrameStrata("LOW")
        tab:SetWidth(315)
        tab:SetHeight(350)
        tab:SetPoint("TOPLEFT", self, "TOPLEFT", 15, -65)

        button:SetBackdrop({bgFile = texture})
        button:SetFrameStrata("MEDIUM")
        button:SetPoint("TOPRIGHT", 31, -12 + buttonSpacing)
        button:SetWidth(30)
        button:SetHeight(30)
        
        button:SetScript("OnClick", function() 
            for i = 1, 7 do
                self.Background["Tab" .. i]:Hide()
            end
            tab:Show()

            for i = 1, 7 do
                self["Glow" .. i]:Hide()
            end
            glow:Show()

            TabText:SetText(tooltipText)
            CliffTells:MenuHandler()

            if tab == self.Background.Tab7 then
                SetupTab7()
                GzHCEditBox:SetText(CT_Settings["HardCoreGzMsg"])
                RIPHCEditBox:SetText(CT_Settings["HardCoreRIPMsg"])

                GzGuildEditBox:SetText(CT_Settings["GuildGzMsg"])
                RIPGuildEditBox:SetText(CT_Settings["GuildRIPMsg"])

                WelcomeGuildEditBox:SetText(CT_Settings["GuildWelcomeMsg"])
            end
        end)

        button:SetScript("OnEnter", function()
            CliffTells_ShowToolTip(button, tooltipText)
            glowHide:Show()
        end)

        button:SetScript("OnLeave", function()
            CliffTells_HideToolTip()
            glowHide:Hide()
        end)

        glow:SetTexture("Interface\\BUTTONS\\ButtonHilight-Square")
        glow:SetWidth(32)
        glow:SetHeight(32)
        glow:SetPoint("CENTER", 0, 0)
        glow:Hide()

        glowHide:SetTexture("Interface\\BUTTONS\\ButtonHilight-Square")
        glowHide:SetWidth(32)
        glowHide:SetHeight(32)
        glowHide:SetPoint("CENTER", 0, 0)
        glowHide:Hide()
    end

    local tooltipTexts = {
        "Dings",
        "Deaths",
        "Immortals",
        "Infernos",
        "Inferno Deaths",
        "Myself",
        "Settings"
    }

    local buttonTextures = {
        "Interface/icons/Spell_Holy_Renew",           -- Button 1
        "Interface/ICONS/Spell_Shadow_ShadowWordPain", -- Button 2
        "Interface/ICONS/Spell_Holy_FlashHeal",      -- Button 3
        "Interface/ICONS/Spell_Holy_AshesToAshes",   -- Button 4
        "Interface/ICONS/Ability_Seal",              -- Button 5
        "Interface/ICONS/Temp",                      -- Button 6
        "Interface/ICONS/Trade_Engineering"          -- Button 7
    }

    for i = 1, 7 do
        self["Glow" .. i] = self.Background["Button" .. i]:CreateTexture(nil, 'ARTWORK')
        self["Glow" .. i .. "1"] = self.Background["Button" .. i]:CreateTexture(nil, 'ARTWORK')

        local buttonSpacing = spacing * i

        CreateTabButton(self.Background["Tab" .. i], self.Background["Button" .. i], self["Glow" .. i], self["Glow" .. i .. "1"], tooltipTexts[i], buttonSpacing, buttonTextures[i])
    end

    -- Create scroll frames
    self.scrollFrames = {}
    local titles = {"Dings", "Deaths", "Immortals", "Inferos", "Inferno Deaths", "Myself"}  -- Titles for the scroll frames
    for i = 1, 6 do
        self.scrollFrame = CreateFrame("ScrollFrame", "MenuScrollFrame" .. i, self.Background["Tab" .. i], "UIPanelScrollFrameTemplate")
        self.scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -62) -- Adjust position
        self.scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 8)
        self.scrollFrame:SetFrameStrata("HIGH")

        self.scrollFrame.child = CreateFrame("Frame", "MyScrollChild" .. i, self.scrollFrame)
        self.scrollFrame.child:SetWidth(190)
        self.scrollFrame .child:SetHeight(300)
        self.scrollFrame:SetScrollChild(self.scrollFrame.child)

        self.scrollFrame.ScrollBar = getglobal("MenuScrollFrame" .. i .. "ScrollBar")
        self.scrollFrame.ScrollBar:ClearAllPoints()
        self.scrollFrame.ScrollBar:SetPoint("TOPLEFT", self.scrollFrame, "TOPRIGHT", 0, -15)
        self.scrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", self.scrollFrame, "BOTTOMRIGHT", -30, 16)
    
        -- Create title text above the scroll frame
        local title = self.scrollFrame:CreateFontString(nil, "OVERLAY")
        title:SetPoint("BOTTOM", self.scrollFrame, "TOP", -9, 8)
        title:SetFont("Fonts\\FRIZQT__.TTF", 14)
        title:SetTextColor(1, 1, 1, 1)

        self.scrollFrames[i] = self.scrollFrame
    end

    function SetupTab7()
        -- Minimap Checkbox
        local Checkbox = CliffTells:CreateCheckbox("CheckboxMinimap",self.Background.Tab7,"Show minimap icon", "Toggle Minimap icon.")
            Checkbox:SetPoint("CENTER",-80, 120)

        local Checkbox = CliffTells:CreateCheckbox("CheckboxDingSound",self.Background.Tab7,"Ding Sound", "Toggle Ding Sound.")
            Checkbox:SetPoint("CENTER",-120, 60)

        local Checkbox = CliffTells:CreateCheckbox("CheckboxDeathSound",self.Background.Tab7,"Death Sound", "Toggle Death Sound.")
            Checkbox:SetPoint("CENTER",-40, 60)

        local Checkbox = CliffTells:CreateCheckbox("CheckboxGuildWelcome",self.Background.Tab7,"Send own Welcome msg\n"..GREEN.."[Guild]", "Toggle custom guild welcome message.")
            Checkbox:SetPoint("CENTER",80, 120)

        local function WelcomeGuildInput()
            if WelcomeGuildEditBox:GetText() == "" then
                WelcomeGuildEditBox:SetText("Welcome <charname> :) <heroic>")
                WelcomeGuildEditBox:ClearFocus()
                CT_Settings["GuildWelcomeMsg"] = WelcomeGuildEditBox:GetText()

                --print for preview
                local welcomemsg = CliffTells__GreetMessages2[math.random(1,getn(CliffTells__GreetMessages2))]
                local welcomecustommsg = string.gsub(CT_Settings["GuildWelcomeMsg"],"<charname>", UnitName("player"))
                welcomecustommsg = string.gsub(welcomecustommsg,"<heroic>", welcomemsg)
                print("Preview message: "..welcomecustommsg)
            else
                WelcomeGuildEditBox:ClearFocus()
                CT_Settings["GuildWelcomeMsg"] = WelcomeGuildEditBox:GetText()

                --print for preview
                local welcomemsg = CliffTells__GreetMessages2[math.random(1,getn(CliffTells__GreetMessages2))]
                local welcomecustommsg = string.gsub(CT_Settings["GuildWelcomeMsg"],"<charname>", UnitName("player"))
                welcomecustommsg = string.gsub(welcomecustommsg,"<heroic>", welcomemsg)
                print("Preview message: "..welcomecustommsg)
            end
        end

        local Editbox = CliffTells:CreateEditbox("WelcomeGuildEditBox",CheckboxGuildWelcome, "Welcome message here")
            Editbox:SetScript("OnEnterPressed", function() WelcomeGuildInput() end)
            Editbox:SetScript("OnEscapePressed", function() WelcomeGuildInput() end)

        -- Guild Gz Checkbox
        local Checkbox = CliffTells:CreateCheckbox("CheckboxGuildGz",self.Background.Tab7,"Send own Gratz msg\n"..GREEN.."[Guild]", "Toggle custom guild gratz message.")
            Checkbox:SetPoint("CENTER",-80, 0)

        local function GzGuildInput()
            if GzGuildEditBox:GetText() == "" then
                GzGuildEditBox:SetText("Congrats on lvl <charlevel>, <charname>!")
                GzGuildEditBox:ClearFocus()
                CT_Settings["GuildGzMsg"] = GzGuildEditBox:GetText()

                --print for preview
                local gzguildmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                local gzguildcustommsg = string.gsub(CT_Settings["GuildGzMsg"],"<charname>", UnitName("player"))
                gzguildcustommsg = string.gsub(gzguildcustommsg,"<charlevel>", UnitLevel("player"))
                gzguildcustommsg = string.gsub(gzguildcustommsg,"<heroic>", gzguildmsg)
                print("Preview message: "..gzguildcustommsg)
            else
                GzGuildEditBox:ClearFocus()
                CT_Settings["GuildGzMsg"] = GzGuildEditBox:GetText()

                --print for preview
                local gzguildmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                local gzguildcustommsg = string.gsub(CT_Settings["GuildGzMsg"],"<charname>", UnitName("player"))
                gzguildcustommsg = string.gsub(gzguildcustommsg,"<charlevel>", UnitLevel("player"))
                gzguildcustommsg = string.gsub(gzguildcustommsg,"<heroic>", gzguildmsg)
                print("Preview message: "..gzguildcustommsg)
            end
        end

        local Editbox = CliffTells:CreateEditbox("GzGuildEditBox",CheckboxGuildGz, "Gratz message here")
            Editbox:SetScript("OnEnterPressed", function() GzGuildInput() end)
            Editbox:SetScript("OnEscapePressed", function() GzGuildInput() end)

        -- Guild RIP Checkbox
        local Checkbox = CliffTells:CreateCheckbox("CheckboxGuildRIP",self.Background.Tab7,"Send own RIP msg\n"..GREEN.."[Guild]", "Toggle custom guild RIP message.")
            Checkbox:SetPoint("CENTER",80, 0)

        local function RIPGuildInput()
            if RIPGuildEditBox:GetText() == "" then
                RIPGuildEditBox:SetText("RIP <charname> (lvl <charlevel>) :( <heroic>")
                RIPGuildEditBox:ClearFocus()
                CT_Settings["GuildRIPMsg"] = RIPGuildEditBox:GetText()

                --print for preview
                local ripguildmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                local ripguildcustommsg = string.gsub(CT_Settings["GuildRIPMsg"],"<charname>", UnitName("player"))
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<charlevel>", UnitLevel("player"))
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<reason>", "Killed by Bob (lvl 15)")
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<location>", "Elwynn Forest")
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<heroic>", ripguildmsg)
                print("Preview message: "..ripguildcustommsg)
            else
                RIPGuildEditBox:ClearFocus()
                CT_Settings["GuildRIPMsg"] = RIPGuildEditBox:GetText()

                --print for preview
                local ripguildmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                local ripguildcustommsg = string.gsub(CT_Settings["GuildRIPMsg"],"<charname>", UnitName("player"))
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<charlevel>", UnitLevel("player"))
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<reason>", "Killed by Bob (lvl 15)")
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<location>", "Elwynn Forest")
                ripguildcustommsg = string.gsub(ripguildcustommsg,"<heroic>", ripguildmsg)
                print("Preview message: "..ripguildcustommsg)
            end
        end

        local Editbox = CliffTells:CreateEditbox("RIPGuildEditBox",CheckboxGuildRIP, "RIP message here")
            Editbox:SetScript("OnEnterPressed", function() RIPGuildInput() end)
            Editbox:SetScript("OnEscapePressed", function() RIPGuildInput() end)

        -- HardCore Gz Checkbox
        local Checkbox = CliffTells:CreateCheckbox("CheckboxHardCoreGz",self.Background.Tab7,"Send Gratz msg\n"..LIGHTYELLOW.."[Hardcore]", "Toggle custom HC gratz message.")
            Checkbox:SetPoint("CENTER",-80, -120)

        local function GzHCInput()
            if GzHCEditBox:GetText() == "" then
                GzHCEditBox:SetText("Gratz")
                GzHCEditBox:ClearFocus()
                CT_Settings["HardCoreGzMsg"] = GzHCEditBox:GetText()

                --print for preview
                local gzhcmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                local gzhccustommsg = string.gsub(CT_Settings["HardCoreGzMsg"],"<charname>", UnitName("player"))
                gzhccustommsg = string.gsub(gzhccustommsg,"<charlevel>", UnitLevel("player"))
                gzhccustommsg = string.gsub(gzhccustommsg,"<heroic>", gzhcmsg)
                print("Preview message: "..gzhccustommsg)
            else
                GzHCEditBox:ClearFocus()
                CT_Settings["HardCoreGzMsg"] = GzHCEditBox:GetText()

                --print for preview
                local gzhcmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                local gzhccustommsg = string.gsub(CT_Settings["HardCoreGzMsg"],"<charname>", UnitName("player"))
                gzhccustommsg = string.gsub(gzhccustommsg,"<charlevel>", UnitLevel("player"))
                gzhccustommsg = string.gsub(gzhccustommsg,"<heroic>", gzhcmsg)
                print("Preview message: "..gzhccustommsg)
            end
        end

        local Editbox = CliffTells:CreateEditbox("GzHCEditBox",CheckboxHardCoreGz, "Gratz message here")
            Editbox:SetScript("OnEnterPressed", function() GzHCInput() end)
            Editbox:SetScript("OnEscapePressed", function() GzHCInput() end)

        -- HardCore RIP Checkbox
        local Checkbox = CliffTells:CreateCheckbox("CheckboxHardCoreRIP",self.Background.Tab7,"Send RIP msg\n"..LIGHTYELLOW.."[Hardcore]", "Toggle custom HC RIP message.")
            Checkbox:SetPoint("CENTER",80, -120)

        local function RIPHCInput()
            if RIPHCEditBox:GetText() == "" then
                RIPHCEditBox:SetText("F :(")
                RIPHCEditBox:ClearFocus()
                CT_Settings["HardCoreRIPMsg"] = RIPHCEditBox:GetText()

                --print for preview
                local riphcmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                local riphccustommsg = string.gsub(CT_Settings["HardCoreRIPMsg"],"<charname>", UnitName("player"))
                riphccustommsg = string.gsub(riphccustommsg,"<charlevel>", UnitLevel("player"))
                riphccustommsg = string.gsub(riphccustommsg,"<reason>", "killed by Bob (level 15)")
                riphccustommsg = string.gsub(riphccustommsg,"<location>", "Elwynn Forest")
                riphccustommsg = string.gsub(riphccustommsg,"<heroic>", riphcmsg)
                print("Preview message: "..riphccustommsg)
            else
                RIPHCEditBox:ClearFocus()
                CT_Settings["HardCoreRIPMsg"] = RIPHCEditBox:GetText()

                --print for preview
                local riphcmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                local riphccustommsg = string.gsub(CT_Settings["HardCoreRIPMsg"],"<charname>", UnitName("player"))
                riphccustommsg = string.gsub(riphccustommsg,"<charlevel>", UnitLevel("player"))
                riphccustommsg = string.gsub(riphccustommsg,"<reason>", "killed by Bob (level 15)")
                riphccustommsg = string.gsub(riphccustommsg,"<location>", "Elwynn Forest")
                riphccustommsg = string.gsub(riphccustommsg,"<heroic>", riphcmsg)
                print("Preview message: "..riphccustommsg)
            end
        end

        local Editbox = CliffTells:CreateEditbox("RIPHCEditBox",CheckboxHardCoreRIP, "RIP message here")
            Editbox:SetScript("OnEnterPressed", function() RIPHCInput() end)
            Editbox:SetScript("OnEscapePressed", function() RIPHCInput() end)
    end
end

function CliffTells:Update(force)
    if CT_Settings["CheckboxMinimap"] == nil then
        CliffTells.Minimap:Hide()
    elseif CT_Settings["CheckboxMinimap"] == 1 then
        CliffTells.Minimap:Show()
	end
end

CliffTells:SetScript("OnUpdate", CliffTells.Update)

function CliffTells:MenuHandler()
    for _, frame in pairs(CliffTells_Frames) do
        if frame:IsVisible() then
            frame:Hide()
        end
    end

    local function handleCategory(category, frameIndex)
        local frame = CliffTells.List.scrollFrames[frameIndex].child
        local numItems = 0

        for _, item in ipairs(CT_List[category]) do
			local uniqueName = category .. "_" .. item.name .. "_" .. tostring(numItems)

            local reason
            if category == "deaths" then
                reason = item.reason
            elseif category == "infernodeaths" then
                reason = item.reason
            end

            if item.class == nil then
                item.class = UnitClass("player")
            end

            CliffTells_Frames[uniqueName] = CliffTells_Frames[uniqueName] or 
                CliffTells:CreateScrollMenuButton(category, item.name, item.class, item.level, item.time, reason, item.location)
                
            local itemFrame = CliffTells_Frames[uniqueName]
            itemFrame:SetParent(frame)
            numItems = numItems + 1
            itemFrame:SetPoint("TOPLEFT", 0, -(numItems * 22) + 20)
            itemFrame.highlight:SetDesaturated(1)
            itemFrame:Show()
        end

        frame:SetHeight(numItems * 22)
    end

    local categories = {"dings", "deaths", "immortals", "infernos", "infernodeaths", "myself"}

    for index = 1, 6 do  -- Adjust the upper limit to the length of the categories
        local category = categories[index]
        if CT_List[category] then  -- Check if the category exists
            local entries = CT_List[category]

            if entries[1] then  -- Check if the first entry exists (indicating the category is not empty)
                handleCategory(category, index)

                local function parseDate(dateStr)
                    -- Match the format "dd.mm.yyyy hh:mm:ss"
                    local _,_,day =  strfind(dateStr,"(%d%d)%.%d%d%.%d%d%d%d %d%d:%d%d:%d%d")
                    local _,_,month =  strfind(dateStr,"%d%d%.(%d%d)%.%d%d%d%d %d%d:%d%d:%d%d")
                    local _,_,year =  strfind(dateStr,"%d%d%.%d%d%.(%d%d%d%d) %d%d:%d%d:%d%d")
                    local _,_,hour =  strfind(dateStr,"%d%d%.%d%d%.%d%d%d%d (%d%d):%d%d:%d%d")
                    local _,_,min =  strfind(dateStr,"%d%d%.%d%d%.%d%d%d%d %d%d:(%d%d):%d%d")
                    local _,_,sec =  strfind(dateStr,"%d%d%.%d%d%.%d%d%d%d %d%d:%d%d:(%d%d)")
                    return {
                        day = tonumber(day),
                        month = tonumber(month),
                        year = tonumber(year),
                        hour = tonumber(hour),
                        min = tonumber(min),
                        sec = tonumber(sec)
                    }
                end

                local function compareDates(a, b)
                    -- Compare years
                    if a.year ~= b.year then
                        return a.year > b.year
                    end
                    -- Compare months
                    if a.month ~= b.month then
                        return a.month > b.month
                    end
                    -- Compare days
                    if a.day ~= b.day then
                        return a.day > b.day
                    end
                    -- Compare hours
                    if a.hour ~= b.hour then
                        return a.hour > b.hour
                    end
                    -- Compare minutes
                    if a.min ~= b.min then
                        return a.min > b.min
                    end
                    -- Compare seconds
                    if a.sec ~= b.sec then
                        return a.sec > b.sec
                    end
                end
            
                table.sort(entries, function(a, b)
                    return compareDates(parseDate(a.time), parseDate(b.time))
                end)

                while entries[61] do
                    table.remove(entries, 61)
                end
            end
        end
    end
end

function CliffTells:CreateScrollMenuButton(type, name, class, level, time, reason, location)
    local childIndices = {
        dings = 1,
        deaths = 2,
        immortals = 3,
        infernos = 4,
        infernodeaths = 5,
        myself = 6
    }

    local childIndex = childIndices[type]
    local child = CliffTells.List.scrollFrames[childIndex].child
    local date = string.sub(time, 1, 10)
    local classcolor = CliffTells:GetClassColorForName(class)
    local levelcolor = CliffTells:GetLevelColor(level)
    
    local backdrop = {
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        tile = "false", tileSize = "16", edgeSize = "4",
        insets = { left = "2", right = "2", top = "2", bottom = "2" }
    }

    local frame = CreateFrame("Button", name, child)
    frame:SetWidth(303)
    frame:SetHeight(20)
    frame:SetBackdrop(backdrop)

    local function createText(position, text)
        local textFrame = frame:CreateFontString(nil, "OVERLAY")
        textFrame:SetPoint(position, 0, 0)
        textFrame:SetFont("Fonts\\FRIZQT__.TTF", 12)
        textFrame:SetTextColor(1, 1, 1, 1)
        textFrame:SetShadowOffset(2, -2)
        textFrame:SetText(text)
        return textFrame
    end

    frame.textLeft = createText("LEFT", classcolor..name)
    frame.textLeft:SetPoint("LEFT", frame, "LEFT", 8, 0) -- 8 pixels to the right
    frame.textMiddle = createText("CENTER", "Level "..levelcolor)
    frame.textMiddle:SetPoint("CENTER", frame, "CENTER", 8, 0) -- 8 pixels to the right
    frame.textRight = createText("RIGHT", YELLOW..date)
    frame.textRight:SetPoint("RIGHT", frame, "RIGHT", -8, 0) -- 8 pixels to the right

    frame.highlight = frame:CreateTexture(nil, 'OVERLAY')
    frame.highlight:SetTexture("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")
    frame.highlight:SetPoint('CENTER', 0, 0)
    frame.highlight:SetWidth(frame:GetWidth())
    frame.highlight:SetHeight(frame:GetHeight() + 4)
    frame.highlight:SetAlpha(1)

    local coloredMessage = ""
    local clickMessage = ""
    if type == "dings" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nReached level "..levelcolor..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND.."\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") dinged level "..level..". Location: "..location..". Date: "..time

    elseif type == "deaths" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nDied at level "..levelcolor..COLOREND..".\nReason: "..RED..reason..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND..".\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") died at level "..level..". Reason: "..reason..". Location: "..location .. ". Date: "..time

    elseif type == "immortals" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nBecame "..PURPLE.."Immortal"..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND.."\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") became Immortal. Location: "..location..". Date: "..time

    elseif type == "infernos" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nStarted the "..PURPLE.."Inferno challenge"..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND.."\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") started the Inferno challenge. Location: "..location..". Date: "..time

    elseif type == "infernodeaths" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nDied as an "..PURPLE.."Inferno"..COLOREND..".\nReason: "..RED..reason..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND..".\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") died as an Inferno. Reason: " .. reason .. ". Location: " .. location .. ". Date: "..time

    elseif type == "myself" then
        coloredMessage = classcolor..name..COLOREND.." ("..classcolor..class..COLOREND..")\nReached level "..levelcolor..COLOREND..".\nLocation: "..LIGHTYELLOW..location..COLOREND.."\nDate: "..LIGHTYELLOW..time..COLOREND
        clickMessage = name .. " ("..class..") reached level " .. level .. ". Location: "..location..". Date: "..time
    end

    frame:SetScript("OnEnter", function()
        frame.highlight:SetAlpha(0.5)
        PlaySound("GLUESCROLLBUTTONMOUSEOVER")
        CliffTells_ShowToolTip(self, coloredMessage, "Click to write in chat.", "Shift-Click to send in chat.")
    end)

    frame:SetScript("OnLeave", function() 
        frame.highlight:SetAlpha(1)
        CliffTells_HideToolTip()
    end)

    frame:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            CliffTells:SendLineToChat("CliffTells: "..clickMessage)
        else
            ChatFrameEditBox:SetText("CliffTells: "..clickMessage)
        end
    end)

    return frame
end

local timer = CreateFrame("Frame")
local startTime = nil
function CTDelayFunction(delay, func, tab, charname, charlvl, deathreason, location)
    if not startTime then
        startTime = GetTime()
        timer:SetScript("OnUpdate", function()
            if (GetTime() - startTime > delay) then
                func(tab, charname, charlvl, deathreason, location, latestdate)
                isEventActive = false
                startTime = nil  -- Reset startTime so it can be reused
                timer:SetScript("OnUpdate", nil)
            end
        end)
    end
end

function CliffTells:Fetchsysmsg(msg)
	msg = string.gsub(msg,"|cff(.)(.)(.)(.)(.)(.)", "")
	msg = string.gsub(msg,COLOREND, "")

	-- A tragedy has occurred. Hardcore character Tester (level 15) has fallen to Kurzen Commando (level 34) in Kurzen's Compound. May this sacrifice not be forgotten.
	-- A tragedy has occurred. Hardcore character Tester (level 15) died of natural causes in Kurzen's Compound. May this sacrifice not be forgotten.
    -- A tragedy has occurred. Hardcore character Tester (level 15) has burned to death in Kurzen's Compound. May this sacrifice not be forgotten.
    -- A tragedy has occurred. Hardcore character Tester (level 15) has drowned in Kurzen's Compound. May this sacrifice not be forgotten.
    if string.find(msg,"A tragedy has occurred. Hardcore character") then
        isEventActive = true
        SendChatMessage(".server info","GUILD")

        local _,_,charname = string.find(msg,"Hardcore character (%a+) %(level")
        local _, _, charlvl = string.find(msg, "level (%d+)%)")
        
        local enemyname
        local deathreason
        local location
        
        if string.find(msg, "has fallen to") then
            _, _,enemyname = string.find(msg, "fallen to (.+) in")
            deathreason = "Fallen to "..enemyname
        elseif string.find(msg, "has fallen in PvP") then
            _, _,enemyname = string.find(msg, "fallen in PvP to (.+) in")
            _,_,location = string.find(msg, "%) in (.+)%. May")
            deathreason = "Fallen in PvP to "..enemyname
        elseif string.find(msg, "died of natural causes") then 
            deathreason = "Natural causes"
        elseif string.find(msg, "has burned to death") then
            deathreason = "Burned to death"
        elseif string.find(msg, "has drowned") then
            deathreason = "Drowned"
        else
            deathreason = "Unknown"
        end

        if not location then
            -- This will capture the location for deaths that are not PvP
            _,_,location = string.find(msg, " in (.+)%. May")
        end

        if charname ~= UnitName("player") then
            if CT_Settings["CheckboxHardCoreRIP"] == 1 then
                local ripmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                local custommsg = string.gsub(CT_Settings["HardCoreRIPMsg"],"<charname>", charname)
                custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                custommsg = string.gsub(custommsg,"<reason>", deathreason)
                custommsg = string.gsub(custommsg,"<location>", location)
                custommsg = string.gsub(custommsg,"<heroic>", ripmsg)
                SendChatMessage(custommsg,"Hardcore")
            end
        end
        CTDelayFunction(1, GatheredInfo, "deaths", charname, charlvl, deathreason, location)
		return

	-- Tester has reached level 20 in Hardcore mode! As they ascend towards immortality, their glory grows! However, so too does the danger they face.
    elseif string.find(msg,"has reached level ") then
        isEventActive = true
        SendChatMessage(".server info","GUILD")

		local _,_,charname = string.find(msg,"(%a+) has reached level")
		local _,_,charlvl = string.find(msg,"level (%d+)")

        if charname ~= UnitName("player") then
            if CT_Settings["CheckboxHardCoreGz"] == 1 then
                local dingmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                local custommsg = string.gsub(CT_Settings["HardCoreGzMsg"],"<charname>", charname)
                custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                custommsg = string.gsub(custommsg,"<heroic>", dingmsg)
                SendChatMessage(custommsg,"Hardcore")
            end
        end

        CTDelayFunction(1, GatheredInfo, "dings", charname, charlvl, "", "")
		return 

	-- Tester has transcended death and reached level 60 on Hardcore mode without dying once! Tester shall henceforth be known as the Immortal!
    elseif string.find(msg,"has transcended death and reached level 60") then
        isEventActive = true
        SendChatMessage(".server info","GUILD")

		local _,_,charname = string.find(msg,"(%a+) has transcended death")
		local _,_,charlvl = string.find(msg,"level (%d+)")

        CTDelayFunction(1, GatheredInfo, "immortals", charname, charlvl, "", "")
		return

	-- Tester has laughed in the face of death in the Hardcore challenge. Tester has begun the Inferno Challenge!
    elseif string.find(msg,"has begun the Inferno Challenge") then
        isEventActive = true
        SendChatMessage(".server info","GUILD")
        
		local _,_,charname = string.find(msg,"(%a+) has laughed in the face of death")
        local charlvl = "60"
        
        CTDelayFunction(1, GatheredInfo, "infernos", charname, charlvl, "", "")
		return

	-- A tragedy has occured. Inferno character Tester (level 60) has fallen to Crimson Templar (level 60) in Twilight Post. They laughed in the face of death, but have learnt that death always has the last laugh.
	-- A tragedy has occurred. Inferno character Tester (level 60) died of natural causes in Kurzen's Compound. They laughed in the face of death, but have learnt that death always has the last laugh.
    -- A tragedy has occurred. Inferno character Tester (level 60) has burned to death in Kurzen's Compound. They laughed in the face of death, but have learnt that death always has the last laugh.
    -- A tragedy has occurred. Inferno character Tester (level 60) has drowned in Kurzen's Compound. They laughed in the face of death, but have learnt that death always has the last laugh.
    elseif string.find(msg,"but have learnt that death always has the last laugh") then
        isEventActive = true
        SendChatMessage(".server info","GUILD")

		local _,_,charname = string.find(msg,"Hardcore character (%a+)")
        local charlvl = "60"
        
        local enemyname
        local deathreason
        local location
        
        if string.find(msg, "has fallen to") then
            _, _,enemyname = string.find(msg, "fallen to (.+) in")
            deathreason = "Fallen to "..enemyname
        elseif string.find(msg, "has fallen in PvP") then
            _, _,enemyname = string.find(msg, "fallen in PvP to (.+) in")
            _,_,location = string.find(msg, "%) in (.+)%. May")
            deathreason = "Fallen in PvP to "..enemyname
        elseif string.find(msg, "died of natural causes") then 
            deathreason = "Natural causes"
        elseif string.find(msg, "has burned to death") then
            deathreason = "Burned to death"
        elseif string.find(msg, "has drowned") then
            deathreason = "Drowned"
        else
            deathreason = "Unknown"
        end

        if not location then
            -- This will capture the location for deaths that are not PvP
            _,_,location = string.find(msg, " in (.+)%. They")
        end

        if charname ~= UnitName("player") then
            if CT_Settings["CheckboxHardCoreRIP"] == 1 then
                local ripmsg = CliffTells__InfernoDeathMessages[math.random(1,getn(CliffTells__InfernoDeathMessages))]
                local custommsg = string.gsub(CT_Settings["HardCoreRIPMsg"],"<charname>", charname)
                custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                custommsg = string.gsub(custommsg,"<reason>", deathreason)
                custommsg = string.gsub(custommsg,"<location>", location)
                custommsg = string.gsub(custommsg,"<heroic>", ripmsg)
                SendChatMessage(custommsg,"Hardcore")
            end
        end

        CTDelayFunction(1, GatheredInfo, "infernodeaths", charname, charlvl, deathreason, location)
		return

	-- welcome msg when someone joins the guild
    elseif string.find(msg,"has joined the guild") then
		local _,_,charname = string.find(msg,"(%a+) has joined the guild")

        CliffTells:RemoveFromSyncTable(charname)
        CTDelayFunction(1, GatheredInfo, "joinguild", charname, "", "", "")
		return

    elseif string.find(msg,"has gone offline") then
        local _,_,charname = string.find(msg,"(%a+) has gone offline")

        CliffTells:RemoveFromSyncTable(charname)
		return

    elseif string.find(msg,"has come online") then
        CliffTells:PingGuildies()
		return

    elseif string.find(msg,"has left the guild") then
        local _,_,charname = string.find(msg,"(%a+) has left the guild")
        
        CliffTells:RemoveFromSyncTable(charname)
		return

    elseif string.find(msg,"has been kicked out of the guild") then
        local _,_,charname = string.find(msg,"(%a+) has been kicked out of the guild")

        CliffTells:RemoveFromSyncTable(charname)
		return
    end
end

function CliffTells:FetchTime(msg)
    msg = string.gsub(msg,"|cff(.)(.)(.)(.)(.)(.)", "")
	msg = string.gsub(msg,COLOREND, "")

    if isEventActive then
        if string.find(msg,"Server Time:") then
            local _,_,time = string.find(msg,"Server Time: (.+)")
            local timeanddate = string.sub(time,6)

            latestdate = timeanddate

            CT_Settings["hidefromchat"] = true
        end
        if string.find(msg,"Players online:") then
            CT_Settings["hidefromchat"] = true
        end
        if string.find(msg,"Server uptime:") then
            CT_Settings["hidefromchat"] = true
        end
    else
        CT_Settings["hidefromchat"] = false
    end
end

function GatheredInfo(tab, charname, charlvl, deathreason, location, date)
    --print("tab = "..tab.." - name = "..charname.." - level = "..charlvl.." - deathreason = "..deathreason.." - location = "..location.." - date = "..date)
    local charclass = "Druid"

    local numGuildMembers = GetNumGuildMembers();
    for i=1, numGuildMembers, 1 do
        name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i);
        if ( online ) then
            if name == charname then
                charclass = class
                if name ~= UnitName("player") then
                    for k, v in pairs(CliffTells_SyncGuild) do
                        if k == 1 and v == UnitName("player") then
                            -- DEATHS
                            if tab == "deaths" then
                                if CT_Settings["CheckboxGuildRIP"] == 1 then
                                    local ripmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                                    local custommsg = string.gsub(CT_Settings["GuildRIPMsg"],"<charname>", charname)
                                    custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                                    custommsg = string.gsub(custommsg,"<reason>", deathreason)
                                    custommsg = string.gsub(custommsg,"<location>", location)
                                    custommsg = string.gsub(custommsg,"<heroic>", ripmsg)
                                    SendChatMessage(custommsg,"GUILD")
                                else
                                    if tonumber(charlvl) < 55 then 
                                        local ripmsg = CliffTells__RipMessages[math.random(1,getn(CliffTells__RipMessages))]
                                        SendChatMessage("RIP "..charname.." (lvl "..charlvl.."). "..ripmsg,"GUILD")
                                    elseif tonumber(charlvl) > 54 then
                                        SendChatMessage("RIP "..charname.." (lvl "..charlvl..") :( Just a heartbeat away from glory. Your journey inspired many, and your legend will live on!","GUILD")
                                    else
                                        SendChatMessage("RIP "..charname.." (lvl "..charlvl..") :(","GUILD")
                                    end
                                end
                    
                            -- DINGS
                            elseif tab == "dings" then
                                if CT_Settings["CheckboxGuildGz"] == 1 then
                                    local dingmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                                    local ding50msg = CliffTells__Ding50Messages[math.random(1,getn(CliffTells__Ding50Messages))]
                                    local custommsg = string.gsub(CT_Settings["GuildGzMsg"],"<charname>", charname)
                                    custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                                    if charlvl == "50" then
                                        custommsg = string.gsub(custommsg, "<heroic>", ding50msg)
                                    else
                                        custommsg = string.gsub(custommsg, "<heroic>", dingmsg)
                                    end
                                    SendChatMessage(custommsg,"GUILD")
                                else
                                    if charlvl == "50" then
                                        local ding50msg = CliffTells__Ding50Messages[math.random(1,getn(CliffTells__Ding50Messages))]
                                        SendChatMessage("Gratz on lvl "..charlvl..", "..charname.."! "..ding50msg,"GUILD")
                                    else
                                        local dingmsg = CliffTells__DingMessages[math.random(1,getn(CliffTells__DingMessages))]
                                        SendChatMessage("Gratz on lvl "..charlvl..", "..charname.."! "..dingmsg,"GUILD")
                                    end
                                end
                    
                            -- IMMORTALS
                            elseif tab == "immortals" then
                                if CT_Settings["CheckboxGuildGz"] == 1 then
                                    local dingmsg = CliffTells__ImmortalMessages[math.random(1,getn(CliffTells__ImmortalMessages))]
                                    local custommsg = string.gsub(CT_Settings["GuildGzMsg"],"<charname>", charname)
                                    custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                                    custommsg = string.gsub(custommsg,"<heroic>", dingmsg)
                                    SendChatMessage(custommsg,"GUILD")
                                else
                                    local dingmsg = CliffTells__ImmortalMessages[math.random(1,getn(CliffTells__ImmortalMessages))]
                                    SendChatMessage("WOW! Gratz on Immortal, "..charname.."!! "..dingmsg,"GUILD")
                                end
                    
                            -- INFERNOS
                            elseif tab == "infernos" then
                                SendChatMessage("Good luck on Inferno Challenge, "..charname.." :)","GUILD")
                    
                            -- INFERNODEATHS
                            elseif tab == "infernodeaths" then  
                                if CT_Settings["CheckboxGuildRIP"] == 1 then
                                    local ripmsg = CliffTells__InfernoDeathMessages[math.random(1,getn(CliffTells__InfernoDeathMessages))]
                                    local custommsg = string.gsub(CT_Settings["GuildRIPMsg"],"<charname>", charname)
                                    custommsg = string.gsub(custommsg,"<charlevel>", charlvl)
                                    custommsg = string.gsub(custommsg,"<reason>", deathreason)
                                    custommsg = string.gsub(custommsg,"<location>", location)
                                    custommsg = string.gsub(custommsg,"<heroic>", ripmsg)
                                    SendChatMessage(custommsg,"GUILD")
                                else
                                    local ripmsg = CliffTells__InfernoDeathMessages[math.random(1,getn(CliffTells__InfernoDeathMessages))]
                                    SendChatMessage("OMG RIP Inferno "..charname.." :( "..ripmsg,"GUILD")
                                end
                            end
                        end
                    end
                end
                -- DEATHS
                if tab == "deaths" then
                    
                    local deathentry = {
                        time = date,
                        name = charname,
                        class = charclass,
                        level = charlvl,
                        reason = deathreason,
                        location = location
                    }
                    table.insert(CT_List.deaths, deathentry)

                    CliffTells:Toast(tab, charname, charclass, charlvl, deathreason, location)

                -- DINGS
                elseif tab == "dings" then

                    local dingentry = {
                    time = date,
                    name = charname,
                    class = charclass,
                    level = charlvl,
                    location = zone
                    }
                    table.insert(CT_List.dings, dingentry)

                    CliffTells:Toast(tab, charname, charclass, charlvl, "", zone)

                    if charname == UnitName("player") then
                        --SendChatMessage("Pewpew, level "..charlvl.."!","GUILD")
                        table.insert(CT_List.myself, dingentry)
                    end

                -- IMMORTALS
                elseif tab == "immortals" then      
                    
                    local immortalentry = {
                    time = date,
                    name = charname,
                    class = charclass,
                    level = charlvl,
                    location = zone
                    }
                    table.insert(CT_List.immortals, immortalentry)

                    CliffTells:Toast(tab, charname, charclass, charlvl, "", zone)

                    if charname == UnitName("player") then
                        --SendChatMessage("Pewpew, level "..charlvl.." - Immortal!","GUILD")
                        table.insert(CT_List.myself, immortalentry)
                    end

                -- INFERNOS
                elseif tab == "infernos" then

                    local infernoentry = {
                    time = date,
                    name = charname,
                    class = charclass,
                    level = charlvl,
                    location = zone
                    }
                    table.insert(CT_List.infernos, infernoentry)

                    CliffTells:Toast(tab, charname, charclass, charlvl, "", zone)

                    if charname == UnitName("player") then
                        --SendChatMessage("Pewpew, level "..charlvl.." - Inferno!","GUILD")
                        table.insert(CT_List.myself, infernoentry)
                    end

                -- INFERNODEATHS
                elseif tab == "infernodeaths" then

                    local infernodeathentry = {
                    time = date,
                    name = charname,
                    class = charclass,
                    level = charlvl,
                    reason = deathreason,
                    location = location
                    }
                    table.insert(CT_List.infernodeaths, infernodeathentry)

                    CliffTells:Toast(tab, charname, charclass, charlvl, deathreason, location)
                end
            end
        end
    end
  
    if charname ~= UnitName("player") then
        for k, v in pairs(CliffTells_SyncGuild) do
            if k == 1 and v == UnitName("player") then
                -- JOINGUILD
                if tab == "joinguild" then
                    if CT_Settings["CheckboxGuildWelcome"] == 1 then
                        local Greet1 = CliffTells__GreetMessages1[math.random(1,getn(CliffTells__GreetMessages1))]
                        local Greet2 = CliffTells__GreetMessages2[math.random(1,getn(CliffTells__GreetMessages2))]
                        local custommsg = string.gsub(CT_Settings["GuildWelcomeMsg"],"<charname>", charname)
                        custommsg = string.gsub(custommsg,"<heroic>", Greet2)
                        SendChatMessage(custommsg,"GUILD")
                    else
                        local Greet1 = CliffTells__GreetMessages1[math.random(1,getn(CliffTells__GreetMessages1))]
                        local Greet2 = CliffTells__GreetMessages2[math.random(1,getn(CliffTells__GreetMessages2))]
                        SendChatMessage(Greet1.." "..charname.."! "..Greet2,"GUILD")
                    end
                end
            end
        end
    end

    -- DINGS
    if tab == "myself" then

        local myselfsentry = {
        time = date,
        name = charname,
        class = UnitClass("player"),
        level = charlvl,
        location = GetZoneText()
        }
        table.insert(CT_List.myself, myselfsentry)

        CliffTells:Toast("dings", charname, UnitClass("player"), charlvl, "", GetZoneText())
        --SendChatMessage("Pewpew, level "..charlvl.."!","GUILD")
    end

    if charname == UnitName("player") and UnitIsDeadOrGhost("player") == nil then
        CliffTells:PingGuildies()
    end
    CliffTells:MenuHandler()
end

function CliffTells:PingGuildies()
    if (pingdelay == nil or GetTime()-pingdelay > 1) then 
        pingdelay = GetTime()
        SendAddonMessage("CliffTellsPing", "pingping", "GUILD")
    end
end

function CliffTells:Default()

    local defaultMessages = {
        GuildWelcomeMsg = "Welcome <charname> :) <heroic>",
        GuildGzMsg = "Congrats on lvl <charlevel>, <charname>!",
        GuildRIPMsg = "RIP <charname> (lvl <charlevel>) :( <heroic>",
        HardCoreGzMsg = "Gratz",
        HardCoreRIPMsg = "F :(",
    }
    
    for key, default in pairs(defaultMessages) do
        if CT_Settings[key] == nil then
            CT_Settings[key] = default
        end
    end

    if CT_Settings["MinimapX"] == nil then
		CT_Settings["MinimapX"] = 1
	end

    if CT_Settings["MinimapY"] == nil then
		CT_Settings["MinimapY"] = 1
	end
end

-- Toasty Time
local CliffTellsToast = CreateFrame("Frame", "CliffTellsToast", UIParent)
CliffTellsToast:SetWidth(400)
CliffTellsToast:SetHeight(75)
CliffTellsToast:SetPoint("TOP", 0, -150)
CliffTellsToast:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
CliffTellsToast:SetBackdropColor(0, 0, 0, 0.8)

local CliffTellsToastMessage = CliffTellsToast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CliffTellsToastMessage:SetPoint("CENTER", 0, 0)
CliffTellsToastMessage:SetFont("Fonts\\FRIZQT__.TTF", 15)
CliffTellsToastMessage:SetText("")
CliffTellsToast:Hide()

local toasttime = 4
local toastTimer = CreateFrame("Frame", nil, CliffTellsToast)
toastTimer:Hide()  -- Initially hide the timer
toastTimer:SetScript("OnUpdate", function()
	if GetTime() >= this.time then
		this.time = nil
		CliffTells:hideToast()
	end
end)

function CliffTells:showToast(message)
    CliffTellsToast:Show()
    CliffTellsToastMessage:SetText(message)
    toastTimer.time = GetTime() + toasttime
    toastTimer:Show()
end


function CliffTells:hideToast()
    CliffTellsToast:Hide()
    CliffTellsToastMessage:SetText("")
end


function CliffTells:Toast(tab, charname, charclass, charlvl, deathreason, location)

    if CliffTellsToast:IsVisible() then
        return
    end

    -- Remove any existing textures from the toast
    if CliffTellsToast.classLeftIcon then
        CliffTellsToast.classLeftIcon:Hide()
        CliffTellsToast.classLeftIcon = nil
    end
    if CliffTellsToast.classRightIcon then
        CliffTellsToast.classRightIcon:Hide()
        CliffTellsToast.classRightIcon = nil
    end
    if CliffTellsToast.typeIcon then
        CliffTellsToast.typeIcon:Hide()
        CliffTellsToast.typeIcon = nil
    end

    -- Add the Class Icon Texture to the Toast
    local r, l, t, b = CliffTells:ClassPos(charclass)

    local classLeftIcon = CliffTellsToast:CreateTexture(nil, 'ARTWORK')
    classLeftIcon:SetTexture("Interface\\AddOns\\CliffTells\\media\\fabledrealmLeft")
    classLeftIcon:SetTexCoord(r, l, t, b)
    classLeftIcon:SetWidth(95)
    classLeftIcon:SetHeight(95)
    CliffTellsToast.classLeftIcon = classLeftIcon

    if charclass == "Warrior" then
        classLeftIcon:SetPoint("LEFT", -40, 10)
    else
        classLeftIcon:SetPoint("LEFT", -35, 0)
    end
    
    if tab == "dings" or tab == "immortals" or tab == "infernos" or tab == "myself" then

        if CT_Settings["CheckboxDingSound"] == 1 then
            if tab == "infernos" then
                PlaySoundFile("Interface\\AddOns\\CliffTells\\media\\TrollMaleCheer03.ogg", "SFX")
            else
                PlaySoundFile("Interface\\AddOns\\CliffTells\\media\\VO_ZG2_MANDOKIR_LEVELUP_EVENT_01.ogg", "SFX")
            end
        end

        local classRightIcon = CliffTellsToast:CreateTexture(nil, 'ARTWORK')
        classRightIcon:SetTexture("Interface\\AddOns\\CliffTells\\media\\fabledrealmRight")
        classRightIcon:SetTexCoord(r, l, t, b)
        classRightIcon:SetWidth(95)
        classRightIcon:SetHeight(95)
        CliffTellsToast.classRightIcon = classRightIcon

        if charclass == "Warrior" then
            classRightIcon:SetPoint("RIGHT", 40, 10)
        else
            classRightIcon:SetPoint("RIGHT", 35, 0)
        end

        if tab == "immortals" then
            self:showToast(CliffTells:GetClassColorForName(charclass)..charname..COLOREND.." reached level "..CliffTells:GetLevelColor(charlvl)..COLOREND.."\n"..DRUID.."Is now known as \n"..PURPLE.."Immortal"..COLOREND)
        elseif tab == "infernos" then
            self:showToast(CliffTells:GetClassColorForName(charclass)..charname..COLOREND.." - Level "..CliffTells:GetLevelColor(charlvl)..COLOREND.."\n"..DRUID.."Has started \n"..PURPLE.."The Inferno Challenge"..COLOREND)
        else
            self:showToast(CliffTells:GetClassColorForName(charclass)..charname..COLOREND.." reached level "..CliffTells:GetLevelColor(charlvl)..COLOREND.."\n"..YELLOW..location)
        end

    elseif tab == "deaths" or tab == "infernodeaths" then

        if CT_Settings["CheckboxDeathSound"] == 1 then
            PlaySoundFile("Interface\\AddOns\\CliffTells\\media\\TwilightMasterKelrisSlay01.ogg", "SFX")
        end

        local typeIcon = CliffTellsToast:CreateTexture(nil, 'ARTWORK')
        typeIcon:SetTexture("Interface\\AddOns\\CliffTells\\media\\GrimReaper")
        typeIcon:SetWidth(128)
        typeIcon:SetHeight(128) 
        typeIcon:SetPoint("RIGHT", 55, -3)
        CliffTellsToast.typeIcon = typeIcon

        local scalingFactor = 5
        if string.len(deathreason) < 45 then
            scalingFactor = 2
        elseif string.len(deathreason) >= 45 and string.len(deathreason) < 60 then
            scalingFactor = 3
        end

        local additionalWidth = string.len(deathreason) * scalingFactor
        CliffTellsToast:SetWidth(400 + additionalWidth)

        if tab == "infernodeaths" then
            self:showToast(PURPLE.."Inferno "..COLOREND..CliffTells:GetClassColorForName(charclass)..charname..COLOREND.." - Level "..CliffTells:GetLevelColor(charlvl)..COLOREND.."\n"..DRUID..deathreason..COLOREND.."\n"..YELLOW..location)
        else
            self:showToast(CliffTells:GetClassColorForName(charclass)..charname..COLOREND.." - Level "..CliffTells:GetLevelColor(charlvl)..COLOREND.."\n"..DRUID..deathreason..COLOREND.."\n"..YELLOW..location)
        end
    end
end

-- onEvent function
function CliffTells:OnEvent()
	if event == "ADDON_LOADED" and arg1 == "CliffTells" then
		print("Loaded!")
		print("Version: "..CLIFFTELLS_VERSION_MSG)
        CliffTells:Default()
		CliffTells.List:Gui()
        CliffTells.Minimap:CreateMinimapIcon()

        table.insert(CliffTells_SyncGuild, 1, UnitName("player"))

        SendChatMessage(".hcm 1", "GUILD")

        for index = 1, 7, 1 do
            if(index ~= 2) then
              local frame = getglobal("ChatFrame"..index);
              CliffTells_ChatFrameHooks[frame] = frame.AddMessage;
              frame.AddMessage = AddMessage;
            end
        end

    elseif event == "PLAYER_LOGIN" then
        if GetCVar("guildMemberNotify")  == "0" then
            SetCVar("guildMemberNotify", "1")
        end
        SendAddonMessage("CliffTellsPing", "pingping", "GUILD")
        
    elseif event == "CHAT_MSG_SYSTEM" then
		CliffTells:Fetchsysmsg(arg1)
        CliffTells:FetchTime(arg1)

    elseif event == "GUILD_ROSTER_UPDATE" then
        CliffTells:PingGuildies()

    elseif event == "PLAYER_LEVEL_UP" then
        isEventActive = true
        SendChatMessage(".server info","GUILD")
        CTDelayFunction(1, GatheredInfo, "myself", UnitName("player"), arg1, "", GetZoneText())

    elseif event == "CHAT_MSG_ADDON" and string.find(arg1, "CliffTells") then
        CliffTells:OnAddonMessage(arg1,arg2,arg4)

    elseif event == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" then
        if arg1 == "You die." then
            CliffTells:RemoveFromSyncTable(UnitName("player"))
        end
    end
end

CliffTells:SetScript("OnEvent", CliffTells.OnEvent) -- the OnEvent script

-- slash commands
function CliffTells.slash(arg1)
	if arg1 == nil or arg1 == "" then
        print("Version: "..CLIFFTELLS_VERSION_MSG)
		print("'/ct "..LIGHTBLUE.."list"..COLOREND.."' - Open the window to explore options and view guildie logs.")
        print("'/ct "..GREEN.."c"..COLOREND.."' - View your connected guildmates.")
	elseif arg1 == "list" then
        CliffTells.List:Show()
        CliffTells:MenuHandler()
    elseif arg1 == "c" then
        print(LIGHTBLUE.."Connected"..COLOREND..":")
        local first = true
        
        for k,v in pairs(CliffTells_SyncGuild) do
            if first then
                print(v .. " ("..GOLD.."announcer"..COLOREND..")")
                first = false
            else
                print(v)
            end
        end
    else
        print("Unknown command. Use '/ct' for help.")
    end
end

SlashCmdList["CLIFFTELLS_SLASH"] = CliffTells.slash
SLASH_CLIFFTELLS_SLASH1 = "/ct"