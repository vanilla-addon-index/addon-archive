-- Speical thanks to Shadowd and Kergoth for the sample code to find nameplates.
-- Speical thanks to Roartindon for updated nameplate code

local childframes = 0
local TimeElapsed = 0;
SCT.UnitPlates = {};

----------------------
--See if its a valied nameplate health bar
local function FindHealthBar()
    for i=1,select( '#', arg) do
        local healthBar = select( i, arg );
        if( healthBar and not healthBar.SCTHooked and healthBar.GetFrameType and healthBar:GetFrameType() == "StatusBar" and not healthBar:GetName() and healthBar:IsVisible() ) then 
            return healthBar; 
        end 
    end 
end 

----------------------
--Check frame to see if a nameplate we can use
local function CheckFrame(object)
	local name = select( 5, object:GetParent():GetRegions() ):GetText();
	if (not SCT.UnitPlates[name]) and (object:IsVisible()) then
		SCT.UnitPlates[name] = object;
	end
end
 
----------------------
--Find any on hooked health bars.
local function UpdateFrames()
    for i=1, select( '#', arg ) do
        local healthBar = FindHealthBar( select( i, arg):GetChildren() );
        if( healthBar ) then 
          SCT:HookScript(healthBar, "OnHide");
          SCT:HookScript(healthBar, "OnShow");
          SCT:HookScript(healthBar, "OnValueChanged");
					healthBar.SCTHooked = true;
					CheckFrame(healthBar);
        end 
    end 
end

----------------------
--Create frame to trigger health bars
function SCT:CreateUnitUpdate()
	self:ScheduleRepeatingEvent("SCTUnitOnUpdate", self.UnitOnUpdate, 0.25, self)
end

----------------------
--Look for new health bars .25 seconds
function SCT:UnitOnUpdate( elapsed ) 
  if childframes ~= WorldFrame:GetNumChildren() then
		childframes = WorldFrame:GetNumChildren()
		UpdateFrames( WorldFrame:GetChildren() );
	end
end 

----------------------
--When a health bar is shown, get the name and run any hooks
function SCT:OnShow(object)
	CheckFrame(object)
	self.hooks[object].OnShow(object);
end

----------------------
--When a health bar value changes, get the name and run any hooks
--This catches more bars when they are coming in and and out of view, etc...
function SCT:OnValueChanged(object, value)
	CheckFrame(object);
	self.hooks[object].OnValueChanged(object, value);
end

----------------------
--When a new health bar is hidden, remove the name and run any hooks
function SCT:OnHide(object)
	local name = select( 5, object:GetParent():GetRegions() ):GetText();
	SCT.UnitPlates[name] = nil;
	self.hooks[object].OnHide(object);
end

----------------------
--Get namplate if there is one
function SCT:GetNameplate(target)
	local parent
	if self.UnitPlates[target] then
		parent = self.UnitPlates[target];
	end
	return parent;
end

----------------------
--Start Nameplate tracking
function SCT:EnableNameplate()
	self:CreateUnitUpdate();
	ShowFriendNameplates();
	FRIENDNAMEPLATES_ON = true;
end

----------------------
--Start Nameplate tracking
function SCT:DisableNameplate()
	HideFriendNameplates();
	FRIENDNAMEPLATES_ON = false;
end
