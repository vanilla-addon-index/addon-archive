if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

-- Trinket buttons, carried-item drawer and notifications.
GearRackTrinkets = {}

-- The Trinkets.xml buttons, each looked up once: worn[0|1] and menu[i] hold
-- the button and its icon, cooldown and queue badge.
local worn, menu = {}, {}
local function Worn(which)
	local w = worn[which]
	if not w then
		local name = "GearRackTrinkets_Trinket"..which
		w = { button = _G[name], icon = _G[name.."Icon"], queue = _G[name.."Queue"] }
		worn[which] = w
	end
	return w
end
local function Menu(i)
	local m = menu[i]
	if not m then
		local name = "GearRackTrinkets_Menu"..i
		m = { button = _G[name], icon = _G[name.."Icon"], cooldown = _G[name.."CD"] }
		menu[i] = m
	end
	return m
end

function GearRackTrinkets.LoadDefaults()

	local defaults = {
		KeepOpen = "OFF",			-- whether menu hides after use
		KeepDocked = "ON",			-- whether to keep menu docked at all times
		Locked = "OFF",				-- whether windows can be moved/scaled/rotated
		SetColumns = "OFF",			-- whether number of columns in menu is chosen automatically
		Columns = 2,				-- if SetColumns "ON", number of columns before menu wraps
		ShowHotKeys = "ON",		-- whether hotkeys show on trinkets
		StopOnSwap = "OFF"			-- whether to stop auto queue on all manual swaps
	}

	local displayDefaults = {
		MainDock = "TOPRIGHT",	-- corner of main window docked to
		MenuDock = "TOPLEFT",	-- corner menu window is docked from
		MainOrient = "VERTICAL",	-- direction of main window
		MenuOrient = "VERTICAL",	-- direction of menu window
		XPos = 423,					-- left edge of main window
		YPos = 448,					-- top edge of main window
		MainScale = 1,				-- scaling of main window
		MenuScale = 1,				-- scaling of menu window
		Visible="ON",				-- whether to display the trinkets
	}
	GearRackDB.trinketOptions = type(GearRackDB.trinketOptions)=="table" and GearRackDB.trinketOptions or {}
	GearRackCharDB.trinkets = type(GearRackCharDB.trinkets)=="table" and GearRackCharDB.trinkets or {}
	local options, per = GearRackDB.trinketOptions, GearRackCharDB.trinkets
	for key,value in pairs(defaults) do
		if options[key]==nil or (type(value)=="string" and options[key]~="ON" and options[key]~="OFF") then options[key]=value end
	end
	for key,value in pairs(displayDefaults) do
		if per[key]==nil then per[key]=value end
	end
	local function number(value, default, minimum, maximum)
		value = tonumber(value)
		if not value or value~=value or value==math.huge or value==-math.huge
			or (minimum and value<minimum) or (maximum and value>maximum) then return default end
		return value
	end
	options.Columns = math.floor(number(options.Columns, 4, 1, 30))
	per.MainScale = number(per.MainScale, 1, 0)
	per.MenuScale = number(per.MenuScale, 1, 0)
	if per.MainScale==0 then per.MainScale=1 end
	if per.MenuScale==0 then per.MenuScale=1 end
	per.XPos = number(per.XPos, 400)
	per.YPos = number(per.YPos, 400)
	for _,key in ipairs({"MainOrient","MenuOrient"}) do
		if per[key]~="HORIZONTAL" and per[key]~="VERTICAL" then per[key]=displayDefaults[key] end
	end
	if per.Visible~="ON" and per.Visible~="OFF" then per.Visible=displayDefaults.Visible end
	if not GearRack.DockStats[tostring(per.MainDock or "")..tostring(per.MenuDock or "")] then
		per.MainDock, per.MenuDock = "BOTTOMRIGHT", "BOTTOMLEFT"
	end

end

--[[ Misc Variables ]]--

GearRackTrinkets.MaxTrinkets = 30 -- add more to GearRackTrinkets_MenuFrame if this changes
GearRackTrinkets.BaggedTrinkets = {} -- indexed by number, 1-30 of trinkets in the menu
GearRackTrinkets.NumberOfTrinkets = 0 -- number of trinkets in the menu
GearRackTrinkets.CombatQueue = {} -- [0] or [1] = name of trinket queued for slot 0 or 1
GearRackTrinkets.QueueItemIDs = {} -- runtime identities; names remain display/API input
GearRackTrinkets.Corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }

-- returns offset and direction depending on current docking. ie: GearRackTrinkets.DockInfo("xoff")
function GearRackTrinkets.DockInfo(arg1)
	local stats = GearRack.DockStats[GearRackCharDB.trinkets.MainDock..GearRackCharDB.trinkets.MenuDock]
	return stats and stats[arg1] or 0
end

-- hide the docking markers
function GearRackTrinkets.ClearDocking()
	for i=1,4 do
		_G["GearRackTrinkets_MainDock_"..GearRackTrinkets.Corners[i]]:Hide()
		_G["GearRackTrinkets_MenuDock_"..GearRackTrinkets.Corners[i]]:Hide()
	end
end

-- returns true if the two values are close to each other
function GearRackTrinkets.Near(arg1,arg2)
	return (math.max(arg1,arg2)-math.min(arg1,arg2))<15
end

-- moves the MenuFrame to the dock position against MainFrame
function GearRackTrinkets.DockWindows()
	GearRackTrinkets.ClearDocking()
	if GearRackDB.trinketOptions.KeepDocked=="ON" then
		GearRackTrinkets_MenuFrame:ClearAllPoints()
		if GearRackDB.trinketOptions.Locked=="OFF" then
			GearRackTrinkets_MenuFrame:SetPoint(GearRackCharDB.trinkets.MenuDock,"GearRackTrinkets_MainFrame",GearRackCharDB.trinkets.MainDock,GearRackTrinkets.DockInfo("xoff"),GearRackTrinkets.DockInfo("yoff"))
		else
			GearRackTrinkets_MenuFrame:SetPoint(GearRackCharDB.trinkets.MenuDock,"GearRackTrinkets_MainFrame",GearRackCharDB.trinkets.MainDock,GearRackTrinkets.DockInfo("xoff")*3,GearRackTrinkets.DockInfo("yoff")*3)
		end
	end
	if GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.BuildMenu()
	end
end

-- displays windows vertically or horizontally
function GearRackTrinkets.OrientWindows()
	if GearRackCharDB.trinkets.MainOrient=="HORIZONTAL" then
		GearRackTrinkets_MainFrame:SetWidth(92)
		GearRackTrinkets_MainFrame:SetHeight(52)
	else
		GearRackTrinkets_MainFrame:SetWidth(52)
		GearRackTrinkets_MainFrame:SetHeight(92)
	end
end

-- scan inventory and build MenuFrame
function GearRackTrinkets.BuildMenu()

	if not IsShiftKeyDown() and GearRackDB.settings.MenuShift=="ON" then
		return
	end

	local idx = 1
	for _,entry in ipairs(GearRack.GetCarriedItems()) do
		if entry.equipLoc=="INVTYPE_TRINKET" and idx<=GearRackTrinkets.MaxTrinkets then
			local trinket = GearRackTrinkets.BaggedTrinkets[idx] or {}
			GearRackTrinkets.BaggedTrinkets[idx] = trinket
			trinket.bag,trinket.slot,trinket.name,trinket.texture = entry.bag,entry.slot,entry.name,entry.texture
			trinket.quality,trinket.id,trinket.guid = entry.quality,entry.baseID,entry.guid
			idx=idx+1
		end
	end
	GearRackTrinkets.NumberOfTrinkets = math.min(idx-1,GearRackTrinkets.MaxTrinkets)

	if GearRackTrinkets.NumberOfTrinkets<1 then
		-- user has no bagged trinkets :(
		GearRackTrinkets_MenuFrame:Hide()
	else
		-- display trinkets outward from docking point
		local col,row,xpos,ypos = 0,0,GearRackTrinkets.DockInfo("xstart"),GearRackTrinkets.DockInfo("ystart")
		local max_cols = 1

		if GearRackTrinkets.NumberOfTrinkets>24 then
			max_cols = 5
		elseif GearRackTrinkets.NumberOfTrinkets>18 then
			max_cols = 4
		elseif GearRackTrinkets.NumberOfTrinkets>12 then
			max_cols = 3
		elseif GearRackTrinkets.NumberOfTrinkets>4 then
			max_cols = 2
		end
		if GearRackDB.trinketOptions.SetColumns=="ON" and GearRackDB.trinketOptions.Columns then
			max_cols = GearRackDB.trinketOptions.Columns
		end

		for i=1,GearRackTrinkets.NumberOfTrinkets do
			local item = Menu(i).button
			Menu(i).icon:SetTexture(GearRackTrinkets.BaggedTrinkets[i].texture)
			GearRack.SetQualityBorder(item, GearRackTrinkets.BaggedTrinkets[i].quality, 12)
			item:SetPoint("TOPLEFT","GearRackTrinkets_MenuFrame",GearRackCharDB.trinkets.MenuDock,xpos,ypos)

			if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
				xpos = xpos + GearRackTrinkets.DockInfo("xdir")*40
				col = col + 1
				if col==max_cols then
					xpos = GearRackTrinkets.DockInfo("xstart")
					col = 0
					ypos = ypos + GearRackTrinkets.DockInfo("ydir")*40
					row = row + 1
				end
				item:Show()
			else
				ypos = ypos + GearRackTrinkets.DockInfo("ydir")*40
				col = col + 1
				if col==max_cols then
					ypos = GearRackTrinkets.DockInfo("ystart")
					col = 0
					xpos = xpos + GearRackTrinkets.DockInfo("xdir")*40
					row = row + 1
				end
				item:Show()
			end
		end
		for i=(GearRackTrinkets.NumberOfTrinkets+1),GearRackTrinkets.MaxTrinkets do
			Menu(i).button:Hide()
		end
		if col==0 then
			row = row-1
		end

		if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
			GearRackTrinkets_MenuFrame:SetWidth(12+(max_cols*40))
			GearRackTrinkets_MenuFrame:SetHeight(12+((row+1)*40))
		else
			GearRackTrinkets_MenuFrame:SetWidth(12+((row+1)*40))
			GearRackTrinkets_MenuFrame:SetHeight(12+(max_cols*40))
		end
		GearRackTrinkets.UpdateMenuCooldowns()
		GearRackTrinkets_MenuFrame:Show()
		GearRackTrinkets.StartTimer("MenuMouseover")
	end

end

function GearRackTrinkets.Initialize()

	if GearRackCharDB.trinkets.XPos and GearRackCharDB.trinkets.YPos then
		GearRackTrinkets_MainFrame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",GearRackCharDB.trinkets.XPos,GearRackCharDB.trinkets.YPos)
	end
	if GearRackCharDB.trinkets.MainScale then
		GearRackTrinkets_MainFrame:SetScale(GearRackCharDB.trinkets.MainScale)
	end
	if GearRackCharDB.trinkets.MenuScale then
		GearRackTrinkets_MenuFrame:SetScale(GearRackCharDB.trinkets.MenuScale)
	end

	GearRackTrinkets.CreateTimer("UpdateWornTrinkets",GearRackTrinkets.UpdateWornTrinkets,.75)
	GearRackTrinkets.CreateTimer("DockingMenu",GearRackTrinkets.DockingMenu,.2,1)
	GearRackTrinkets.CreateTimer("MenuMouseover",GearRackTrinkets.MenuMouseover,.25,1)
	GearRackTrinkets.CreateTimer("Scaling",GearRackTrinkets.Scaling,.1,1)
	GearRackTrinkets.CreateTimer("TooltipUpdate",GearRackTrinkets.TooltipUpdate,1,1)
	GearRackTrinkets.CreateTimer("CooldownUpdate",GearRackTrinkets.CooldownUpdate,1,1)

	GearRackTrinkets.InitOptions()

	GearRackTrinkets.UpdateWornTrinkets()
	GearRackTrinkets.DockWindows()
	GearRackTrinkets.OrientWindows()
	GearRackTrinkets.StartTimer("CooldownUpdate")

	if GearRackCharDB.trinkets.Visible=="ON" and (GetInventoryItemLink("player",13) or GetInventoryItemLink("player",14)) then
		GearRackTrinkets_MainFrame:Show()
	end
end

-- IDs select queue items; name-only macro inputs require an exact name.
function GearRackTrinkets.FindItem(name,includeInventory,itemID)
    return GearRack.FindLocation(tonumber(itemID),name,true,includeInventory)
end

--[[ Frame Scripts ]]--

function GearRackTrinkets.UpdateWornTrinkets()
	for which=0,1 do
		local slot = 13+which
		local button, icon = Worn(which).button, Worn(which).icon
		icon:SetTexture((GearRackEngine.GetItemInfo(slot)))
		icon:SetDesaturated(nil)
		button:SetChecked(0)
		GearRack.SetQualityBorder(button, GetInventoryItemQuality("player", slot), 12)
	end
	GearRackTrinkets.UpdateWornCooldowns()
	if GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.BuildMenu()
	end
	local owner=GearRackTrinkets.TooltipOwner
	if GearRackTrinkets.TooltipType=="INVENTORY" and owner and owner:IsVisible()
		and GameTooltip:GetOwner()==owner and MouseIsOver(owner) then
		GearRackTrinkets.TooltipUpdate()
	end
end

function GearRackTrinkets.SlashHandler(msg)

	msg = msg or ""
	local _,_,command,which,profile = string.find(msg,"^%s*(%S+)%s+(%S+)%s+(.+)$")

	if string.lower(command or "")=="load" and profile then
		profile = string.gsub(profile,"%s+$","")
		which = string.lower(which)
		if which=="top" or which=="0" then
			which = 0
		elseif which=="bottom" or which=="1" then
			which = 1
		end
		if type(which)=="number" then
			GearRackTrinkets.SetQueue(which,"SORT",profile)
			return
		end
	end

	msg = string.lower(msg)

	if not msg or msg=="" then
		GearRackTrinkets.ToggleFrame(GearRackTrinkets_MainFrame)
	elseif string.find(msg,"^opt") or string.find(msg,"^config") then
		GearRackTrinkets.ToggleFrame(GearRackTrinkets_OptFrame)
	elseif msg=="lock" then
		GearRackDB.trinketOptions.Locked="ON"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif msg=="unlock" then
		GearRackDB.trinketOptions.Locked="OFF"
		GearRackTrinkets.DockWindows()
		GearRackTrinkets.ReflectLock()
	elseif msg=="reset" then
		GearRackTrinkets.ResetSettings()
	elseif string.find(msg,"scale") then
		local _,_,menuscale = string.find(msg,"scale menu (.+)")
		if tonumber(menuscale) then
			GearRackTrinkets.FrameToScale = GearRackTrinkets_MenuFrame
			GearRackTrinkets.ScaleFrame(menuscale)
		end
		local _,_,mainscale = string.find(msg,"scale main (.+)")
		if tonumber(mainscale) then
			GearRackTrinkets.FrameToScale = GearRackTrinkets_MainFrame
			GearRackTrinkets.ScaleFrame(mainscale)
		end
		if not tonumber(menuscale) and not tonumber(mainscale) then
			DEFAULT_CHAT_FRAME:AddMessage("GearRack: /gr trinkets scale main 0.85 (or menu 0.85). Dragging a window's corner also scales it.")
		end
		GearRackTrinkets.FrameToScale = nil
		GearRackCharDB.trinkets.MainScale = GearRackTrinkets_MainFrame:GetScale()
		GearRackCharDB.trinkets.MenuScale = GearRackTrinkets_MenuFrame:GetScale()
	elseif string.find(msg,"load") then
		DEFAULT_CHAT_FRAME:AddMessage("GearRack: /gr trinkets load top|bottom <profile>")
	else
		DEFAULT_CHAT_FRAME:AddMessage("GearRack trinkets: /gr trinkets [opt | lock | unlock | reset | scale main|menu <n> | load top|bottom <profile>]")
	end
end

function GearRackTrinkets.ResetSettings()
	StaticPopupDialogs["GEARRACKTRINKETSRESET"] = {
		text = "Reset trinket settings, positions, priority lists and profiles, then reload the UI?",
		button1 = "Yes", button2 = "No", showAlert=1, timeout = 0, whileDead = 1,
		OnAccept = function()
            GearRackDB.trinketOptions=nil;GearRackCharDB.trinkets=nil;GearRackCharDB.queues=nil
            table.wipe(GearRackCharDB.HeldQueues)
            ReloadUI()
        end,
	}
	StaticPopup_Show("GEARRACKTRINKETSRESET")
end

--[[ Window Movement ]]--

function GearRackTrinkets.MainFrame_OnMouseUp()
	if arg1=="LeftButton" then
		this:StopMovingOrSizing()
		GearRackCharDB.trinkets.XPos = GearRackTrinkets_MainFrame:GetLeft()
		GearRackCharDB.trinkets.YPos = GearRackTrinkets_MainFrame:GetTop()
	elseif GearRackDB.trinketOptions.Locked=="OFF" then
		if GearRackCharDB.trinkets.MainOrient=="VERTICAL" then
			GearRackCharDB.trinkets.MainOrient = "HORIZONTAL"
		else
			GearRackCharDB.trinkets.MainOrient = "VERTICAL"
		end
		GearRackTrinkets.OrientWindows()
	end

end

function GearRackTrinkets.MainFrame_OnMouseDown(arg1)
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		this:StartMoving()
	end
end

--[[ Timers (Native C++ C_Timer Architecture) ]]

-- Timer names are scoped to the trinket view in the single GearRackEngine timer owner.

local function timerName(name)
    return name=="CooldownUpdate" and name or ("Trinkets:"..name)
end
function GearRackTrinkets.CreateTimer(name,func,delay,rep)
    if name~="CooldownUpdate" then GearRackEngine.CreateTimer(timerName(name),func,delay,rep) end
end
function GearRackTrinkets.IsTimerActive(name) return GearRackEngine.TimerEnabled(timerName(name)) end
function GearRackTrinkets.StartTimer(name,delay) GearRackEngine.StartTimer(timerName(name),delay) end
function GearRackTrinkets.StopTimer(name) GearRackEngine.StopTimer(timerName(name)) end

--[[ OnClicks ]]

function GearRackTrinkets.MainTrinket_OnClick()
	if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
		this:SetChecked(0)
		ChatFrameEditBox:Insert(GetInventoryItemLink("player",this:GetID()))
	elseif IsAltKeyDown() then
		local which = this:GetID()-13
		local held = GearRackCharDB.HeldQueues[which] or GearRackTrinkets.PausedQueue[which]
		GearRack.ResumeTrinketQueue(which)
		GearRackTrinkets.PausedQueue[which]=nil
		this:SetChecked(0)
		if GearRackCharDB.queues.Enabled[which] and not held then
			GearRack.CancelAutomaticTrinket(which)
			GearRackCharDB.queues.Enabled[which] = nil
		else
			GearRackCharDB.queues.Enabled[which] = 1
		end
		GearRackTrinkets.ReflectQueueEnabled()
		GearRackTrinkets.UpdateCombatQueue()
	elseif arg1=="RightButton" then
		this:SetChecked(0)
		GearRack.OpenTrinketPriorities(this:GetID())
	else
		UseInventoryItem(this:GetID())
	end
end

function GearRackTrinkets.MenuTrinket_OnClick()
	this:SetChecked(0)
	if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
		ChatFrameEditBox:Insert(GetContainerItemLink(GearRackTrinkets.BaggedTrinkets[this:GetID()].bag,GearRackTrinkets.BaggedTrinkets[this:GetID()].slot))
	else
		local slot = (arg1=="LeftButton") and 13 or 14
		local chosen=GearRackTrinkets.BaggedTrinkets[this:GetID()]
		local _,liveID=GearRackEngine.GetItemInfo(chosen.bag,chosen.slot)
		if GearRack.BagGUID(chosen.bag,chosen.slot)~=chosen.guid then GearRack.InvalidateBag(chosen.bag);return end
		local _,_,canCooldown = GetContainerItemCooldown(chosen.bag,chosen.slot)
		if canCooldown==0 or GearRackDB.trinketOptions.StopOnSwap=="ON" then -- a trinket without a use stops the queue
			GearRackCharDB.queues.Enabled[slot-13]=nil
			GearRackTrinkets.ReflectQueueEnabled()
		end
		GearRack.RequestItem(slot,{id=liveID,name=chosen.name,texture=chosen.texture,guid=chosen.guid},nil,true)
		if not IsShiftKeyDown() and GearRackDB.trinketOptions.KeepOpen=="OFF" then
			GearRackTrinkets_MenuFrame:Hide()
		end
	end
end

--[[ Docking ]]

function GearRackTrinkets.MenuFrame_OnMouseDown()
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		GearRackTrinkets_MenuFrame:StartMoving()

		if GearRackDB.trinketOptions.KeepDocked=="ON" then
			GearRackTrinkets.StartTimer("DockingMenu")
		end
	end
end

function GearRackTrinkets.MenuFrame_OnMouseUp()
	if arg1=="LeftButton" then
		GearRackTrinkets.StopTimer("DockingMenu")
		GearRackTrinkets_MenuFrame:StopMovingOrSizing()
		if GearRackDB.trinketOptions.KeepDocked=="ON" then
			GearRackTrinkets.DockWindows()
		end
	elseif GearRackDB.trinketOptions.Locked=="OFF" then
		if GearRackCharDB.trinkets.MenuOrient=="VERTICAL" then
			GearRackCharDB.trinkets.MenuOrient="HORIZONTAL"
		else
			GearRackCharDB.trinkets.MenuOrient="VERTICAL"
		end
		GearRackTrinkets.BuildMenu()
	end
end

function GearRackTrinkets.DockingMenu()

	local main = GearRackTrinkets_MainFrame
	local menu = GearRackTrinkets_MenuFrame
	local mainscale = GearRackTrinkets_MainFrame:GetScale()
	local menuscale = GearRackTrinkets_MenuFrame:GetScale()
	local near = GearRackTrinkets.Near

	if near(main:GetRight()*mainscale,menu:GetLeft()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPRIGHT"
			GearRackCharDB.trinkets.MenuDock = "TOPLEFT"
		elseif near(main:GetBottom()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMRIGHT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMLEFT"
		end
	elseif near(main:GetLeft()*mainscale,menu:GetRight()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPLEFT"
			GearRackCharDB.trinkets.MenuDock = "TOPRIGHT"
		elseif near(main:GetBottom()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMLEFT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMRIGHT"
		end
	elseif near(main:GetRight()*mainscale,menu:GetRight()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPRIGHT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMRIGHT"
		elseif near(main:GetBottom()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMRIGHT"
			GearRackCharDB.trinkets.MenuDock = "TOPRIGHT"
		end
	elseif near(main:GetLeft()*mainscale,menu:GetLeft()*menuscale) then
		if near(main:GetTop()*mainscale,menu:GetBottom()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "TOPLEFT"
			GearRackCharDB.trinkets.MenuDock = "BOTTOMLEFT"
		elseif near(main:GetBottom()*mainscale,menu:GetTop()*menuscale) then
			GearRackCharDB.trinkets.MainDock = "BOTTOMLEFT"
			GearRackCharDB.trinkets.MenuDock = "TOPLEFT"
		end
	end
	GearRackTrinkets.ClearDocking()
	_G["GearRackTrinkets_MainDock_"..GearRackCharDB.trinkets.MainDock]:Show()
	_G["GearRackTrinkets_MenuDock_"..GearRackCharDB.trinkets.MenuDock]:Show()
end

function GearRackTrinkets.MenuMouseover()
	if not GearRackTrinkets_MenuFrame:IsVisible() then
		GearRackTrinkets.StopTimer("MenuMouseover")
	elseif (not MouseIsOver(GearRackTrinkets_MainFrame)) and (not MouseIsOver(GearRackTrinkets_MenuFrame)) and not IsShiftKeyDown() and (GearRackDB.trinketOptions.KeepOpen=="OFF") and not GearRackTrinkets.IsTimerActive("Scaling") then
		GearRackTrinkets.StopTimer("MenuMouseover")
		GearRackTrinkets_MenuFrame:Hide()
	end
end

--[[ Scaling ]]

function GearRackTrinkets.StartScaling()
	if arg1=="LeftButton" and GearRackDB.trinketOptions.Locked=="OFF" then
		GearRackTrinkets.StopScalingFrame(GearRackTrinkets.FrameToScale)
		this:LockHighlight()
		GearRackTrinkets.ScalingButton = this
		GearRackTrinkets.FrameToScale = this:GetParent()
		GearRackTrinkets.ScalingWidth = this:GetParent():GetWidth()
		GearRackTrinkets.StartTimer("Scaling")
	end
end

function GearRackTrinkets.StopScaling()
	if arg1=="LeftButton" and GearRackTrinkets.ScalingButton==this then
		GearRackTrinkets.StopScalingFrame(this:GetParent())
	end
end

function GearRackTrinkets.StopScalingFrame(frame)
	if not frame or GearRackTrinkets.FrameToScale~=frame then return end
	GearRackTrinkets.StopTimer("Scaling")
	if GearRackTrinkets.ScalingButton then GearRackTrinkets.ScalingButton:UnlockHighlight() end
	GearRackTrinkets.ScalingButton = nil
	GearRackTrinkets.FrameToScale = nil
	if frame==GearRackTrinkets_MainFrame then
		GearRackCharDB.trinkets.MainScale = frame:GetScale()
	else
		GearRackCharDB.trinkets.MenuScale = frame:GetScale()
	end
end

function GearRackTrinkets.ScaleFrame(scale)
	local frame = GearRackTrinkets.FrameToScale
	if frame==GearRackTrinkets_MainFrame then
		local x,y = GearRack.ScaleFrame(frame,scale,GearRackCharDB.trinkets.XPos,GearRackCharDB.trinkets.YPos)
		if x then GearRackCharDB.trinkets.XPos, GearRackCharDB.trinkets.YPos = x, y end
	elseif GearRackDB.trinketOptions.KeepDocked=="OFF" then
		GearRack.ScaleFrame(frame,scale)
	else
		-- A docked menu keeps its anchor to the trinket buttons.
		scale = tonumber(scale)
		if scale and scale>0 and scale~=math.huge then frame:SetScale(scale) end
	end
end

function GearRackTrinkets.Scaling()
	local frame = GearRackTrinkets.FrameToScale
	if not frame or not frame:IsVisible() then
		GearRackTrinkets.StopTimer("Scaling")
		GearRackTrinkets.StopScalingFrame(frame)
		return
	end
	local oldscale = frame:GetEffectiveScale()
	local framex, framey, cursorx, cursory = frame:GetLeft()*oldscale, frame:GetTop()*oldscale, GetCursorPosition()
	if (cursorx-framex)>32 then
		local newscale = (cursorx-framex)/GearRackTrinkets.ScalingWidth
		GearRackTrinkets.ScaleFrame(newscale)
	end
end

--[[ Cooldowns ]]

-- Every global cooldown asks again; redraw a spiral only when its cooldown changed.
local function set_worn_cooldown(frame,start,duration,enable)
	if frame.gearRackStart==start and frame.gearRackDuration==duration and frame.gearRackEnable==enable then return end
	frame.gearRackStart,frame.gearRackDuration,frame.gearRackEnable = start,duration,enable
	CooldownFrame_SetTimer(frame,start,duration,enable)
end

function GearRackTrinkets.UpdateWornCooldowns()
	set_worn_cooldown(GearRackTrinkets_Trinket0CD,GearRack.GetInventoryCooldown(13))
	set_worn_cooldown(GearRackTrinkets_Trinket1CD,GearRack.GetInventoryCooldown(14))
end

function GearRackTrinkets.UpdateMenuCooldowns()
	local start,duration,enable
	for i=1,GearRackTrinkets.NumberOfTrinkets do
		start,duration,enable = GetContainerItemCooldown(GearRackTrinkets.BaggedTrinkets[i].bag,GearRackTrinkets.BaggedTrinkets[i].slot)
		CooldownFrame_SetTimer(Menu(i).cooldown,start,duration,enable)
	end
end

--[[ Item use ]]

function GearRackTrinkets.ReflectTrinketUse(slot)
	Worn(slot-13).button:SetChecked(1)
	GearRackTrinkets.StartTimer("UpdateWornTrinkets")
end

--[[ Tooltips ]]

function GearRackTrinkets.WornTrinketTooltip()
	local id = this:GetID()
	if GearRackTrinkets.IsTimerActive("Scaling") or GearRackDB.settings.ShowTooltips=="OFF" then
		return
	end
	GearRackTrinkets.TooltipOwner = this
	GearRackTrinkets.TooltipType = "INVENTORY"
	GearRackTrinkets.TooltipSlot = id
	GearRackTrinkets.TooltipBag = GearRackTrinkets.CombatQueue[id-13]
	GearRackTrinkets.AnchorTooltip(this)
	GearRackTrinkets.StartTimer("TooltipUpdate",0)
end

function GearRackTrinkets.MenuTrinketTooltip()
	local id = this:GetID()
	if GearRackTrinkets.IsTimerActive("Scaling") or GearRackDB.settings.ShowTooltips=="OFF" then
		return
	end
	GearRackTrinkets.TooltipOwner = this
	GearRackTrinkets.TooltipType = "BAG"
	GearRackTrinkets.TooltipBag = GearRackTrinkets.BaggedTrinkets[id].bag
	GearRackTrinkets.TooltipSlot = GearRackTrinkets.BaggedTrinkets[id].slot
	GearRackTrinkets.AnchorTooltip(this)
	GearRackTrinkets.StartTimer("TooltipUpdate",0)
end

function GearRackTrinkets.ClearTooltip()
	local owner=GearRackTrinkets.TooltipOwner
	if owner and GameTooltip:GetOwner()==owner then GameTooltip:Hide() end
	GearRackTrinkets.StopTimer("TooltipUpdate")
	GearRackTrinkets.TooltipType = nil
	GearRackTrinkets.TooltipOwner = nil
	GearRackTrinkets.TooltipBag = nil
	GearRackTrinkets.TooltipSlot = nil
end

local function clear_view_tooltip(frame)
	local owner=GearRackTrinkets.TooltipOwner
	while owner do
		if owner==frame then GearRackTrinkets.ClearTooltip();return end
		owner=owner:GetParent()
	end
end

function GearRackTrinkets.AnchorTooltip(owner)
	owner = owner or this
	if GearRackDB.settings.TooltipFollow=="ON" then
		if owner.GetLeft and owner:GetLeft() and owner:GetLeft()<400 then
			GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
		else
			GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
		end
	else
		GameTooltip_SetDefaultAnchor(GameTooltip,owner)
	end
end

-- updates the tooltip created in the functions above
function GearRackTrinkets.TooltipUpdate()
	if GearRackTrinkets.TooltipType then
		local owner=GearRackTrinkets.TooltipOwner
		if not owner or not owner:IsVisible() or GameTooltip:GetOwner()~=owner then
			GearRackTrinkets.ClearTooltip()
			return
		end
		local cooldown
		GearRackTrinkets.AnchorTooltip(GearRackTrinkets.TooltipOwner)
		if GearRackTrinkets.TooltipType=="BAG" then
			GameTooltip:SetBagItem(GearRackTrinkets.TooltipBag,GearRackTrinkets.TooltipSlot)
			cooldown = GetContainerItemCooldown(GearRackTrinkets.TooltipBag,GearRackTrinkets.TooltipSlot)
		else
			GameTooltip:SetInventoryItem("player",GearRackTrinkets.TooltipSlot)
			cooldown = GearRack.GetInventoryCooldown(GearRackTrinkets.TooltipSlot)
		end
		if GearRackTrinkets.TooltipType=="INVENTORY" and GearRackTrinkets.TooltipBag then
			GameTooltip:AddLine("Queued: "..GearRackTrinkets.TooltipBag)
		end
		if GearRackTrinkets.TooltipType=="INVENTORY" then
			GameTooltip:AddLine("Right-click: trinkets",UI.heading[1],UI.heading[2],UI.heading[3])
		end
		GameTooltip:Show()
		if cooldown==0 then
			-- Keep the owned source for event-driven item changes, without polling.
			GearRackTrinkets.StopTimer("TooltipUpdate")
		elseif not GearRackTrinkets.IsTimerActive("TooltipUpdate") then
			GearRackTrinkets.StartTimer("TooltipUpdate")
		end
	end

end

-- normal tooltip for options
function GearRackTrinkets.OnTooltip(line1,line2)
	if GearRackDB.settings.ShowTooltips=="ON" then
		GearRackTrinkets.AnchorTooltip()
		if line1 then
			GameTooltip:AddLine(line1)
			GameTooltip:AddLine(line2,.8,.8,.8,1)
			GameTooltip:Show()
		else
			local name = this:GetName() or ""
			for i=1,#GearRackTrinkets.CheckOptInfo do
				if name=="GearRackTrinkets_Opt"..GearRackTrinkets.CheckOptInfo[i][1] then
					GearRackTrinkets.OnTooltip(GearRackTrinkets.CheckOptInfo[i][3],GearRackTrinkets.CheckOptInfo[i][4])
				end
			end
			for i=1,#GearRackTrinkets.TooltipInfo do
				if GearRackTrinkets.TooltipInfo[i][1]==name and GearRackTrinkets.TooltipInfo[i][2] then
					GearRackTrinkets.OnTooltip(GearRackTrinkets.TooltipInfo[i][2],GearRackTrinkets.TooltipInfo[i][3])
				end
			end
		end
	end
end

--[[ Combat Queue ]]

-- Optional read-only integration for tooltip addons. The queue stays owned here.
function GearRackTrinkets.GetQueuedSlotForItem(link)
	local _, _, id = string.find(link or "", "item:(%d+)")
	id = tonumber(id)
	if not id then return end
	for which=0,1 do
		if (GearRackTrinkets.CombatQueue[which] and GearRackTrinkets.QueueItemIDs[which]==id)
            or GearRack.BaseID(GearRackEngine.CombatQueue[13+which])==id then return 13+which end
	end
end

function GearRackTrinkets.ReflectQueueState(which,state)
	local icon = Worn(which).queue
	local delayed,paused = state=="delay",state=="pause"
	if icon.gearRackDelayed~=delayed then
		icon.gearRackDelayed = delayed
		icon:SetDesaturated(delayed)
	end
	if icon.gearRackPaused~=paused then
		icon.gearRackPaused = paused
		icon:SetVertexColor(1,paused and .5 or 1,paused and .5 or 1)
	end
end

function GearRackTrinkets.UpdateCombatQueue()
	local bag,slot
	for which=0,1 do
		local trinket = GearRackTrinkets.CombatQueue[which]
		local icon = Worn(which).queue
		icon:Hide()
		local held = not trinket and GearRackCharDB.queues.Enabled[which]
			and (GearRackCharDB.HeldQueues[which] or GearRackTrinkets.PausedQueue[which])
		GearRackTrinkets.ReflectQueueState(which,held and "pause" or nil)
		if trinket then
			_,bag,slot = GearRackTrinkets.FindItem(trinket,nil,GearRackTrinkets.QueueItemIDs[which])
			if bag then
				icon:SetTexture(GetContainerItemInfo(bag,slot))
				icon:Show()
			end
		elseif GearRackCharDB.queues.Enabled[which] then
			icon:SetTexture("Interface\\AddOns\\GearRack\\media\\Trinket-Queue")
			icon:Show()
		end
	end
end

--[[ Queue clock ]]--

-- A running queue looks for a better trinket once a second; a paused or held
-- one waits until it is resumed.
function GearRackTrinkets.CooldownUpdate()
	GearRackTrinkets.PeriodicQueueCheck()
	for which=0,1 do
		if GearRackCharDB.queues.Enabled[which] and not GearRackCharDB.HeldQueues[which]
			and not GearRackTrinkets.PausedQueue[which] then return 1 end
	end
end

function GearRackTrinkets.OnShow()
	GearRackCharDB.trinkets.Visible = "ON"
	if GearRackDB.trinketOptions.KeepOpen=="ON" then
		GearRackTrinkets.BuildMenu()
	end
end

function GearRackTrinkets.OnHide()
	-- Ancestor hides deliver OnHide without clearing this frame's shown bit.
	if not GearRackTrinkets_MainFrame:IsShown() then GearRackCharDB.trinkets.Visible = "OFF" end
	GearRackTrinkets_MainFrame:StopMovingOrSizing()
	GearRackTrinkets.StopScalingFrame(GearRackTrinkets_MainFrame)
	clear_view_tooltip(GearRackTrinkets_MainFrame)
	GearRackTrinkets_MenuFrame:Hide()
end

function GearRackTrinkets.MenuFrame_OnHide()
	GearRackTrinkets.StopTimer("MenuMouseover")
	GearRackTrinkets.StopTimer("DockingMenu")
	GearRackTrinkets_MenuFrame:StopMovingOrSizing()
	GearRackTrinkets.StopScalingFrame(GearRackTrinkets_MenuFrame)
	GearRackTrinkets.ClearDocking()
	clear_view_tooltip(GearRackTrinkets_MenuFrame)
end

--[[ Key bindings ]]

function GearRackTrinkets.ReflectKeyBindings()
	local show=GearRackDB.trinketOptions.ShowHotKeys=="ON"
	for which=0,1 do
		local label=_G["GearRackTrinkets_Trinket"..which.."HotKey"]
		local command=which==0 and "GEARRACK_USE_TOP_TRINKET_ITEM" or "GEARRACK_USE_BOTTOM_TRINKET_ITEM"
		local key=show and GetBindingKey(command)
		label:SetText(key and GetBindingText(key,"KEY_",1) or "")
		label:SetTextColor(1,0.95,0.8)
		if key then label:Show() else label:Hide() end
	end
end
