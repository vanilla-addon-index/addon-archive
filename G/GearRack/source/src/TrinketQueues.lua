if not GearRack.enabled then return end

local _, ns = ...
local UI = ns.UI

--[[ GearRackCharDB.queues : auto queue system ]]

GearRackTrinkets.PausedQueue = {} -- 0 or 1 whether queue is paused

-- Persist item templates consistently; instance GUIDs belong to live requests.
local function queue_id(value)
	local id = tonumber(value)
	if not id or id~=id or id<0 or id==math.huge or id~=math.floor(id) then return end
	return id==0 and 0 or tostring(id)
end

local function normalize_order(list,first)
	local order,seen = {},{}
	for i=first or 1,#list do
		local id = queue_id(list[i])
		if id~=nil and not seen[id] then
			seen[id] = true
			table.insert(order,id)
		end
	end
	return order
end

function GearRackTrinkets.QueueInit()
	GearRackCharDB.queues = type(GearRackCharDB.queues)=="table" and GearRackCharDB.queues or {
		Stats = {}, -- indexed by id of trinket, delay, priority and keep
		Sort = {}, -- indexed by number, ids in order of use
		Enabled = {} -- 0 or 1 whether auto queue is on for the slot
	}
	for _, key in ipairs({"Stats", "Sort", "Enabled", "Profiles"}) do
		if type(GearRackCharDB.queues[key])~="table" then GearRackCharDB.queues[key] = {} end
	end
	for which=0,1 do
		local list = GearRackCharDB.queues.Sort[which]
		GearRackCharDB.queues.Sort[which] = type(list)=="table" and normalize_order(list) or {}
		local enabled = GearRackCharDB.queues.Enabled[which]
		GearRackCharDB.queues.Enabled[which] = (enabled==1 or enabled==true) and 1 or nil
	end
	local savedStats,statsByID = GearRackCharDB.queues.Stats,{}
	for id, stats in pairs(savedStats) do
		local key = queue_id(id)
		if key and key~=0 and type(stats)=="table" then
			local delay = tonumber(stats.delay)
			if not delay or delay~=delay or delay<=0 or delay==math.huge then delay = nil end
			stats.delay = delay
			stats.priority = (stats.priority==1 or stats.priority==true) and 1 or nil
			stats.keep = (stats.keep==1 or stats.keep==true) and 1 or nil
			-- Existing string keys win over a duplicate numeric template key.
			-- An entry with nothing set (a box ticked and cleared) is dropped.
			if (stats.delay or stats.priority or stats.keep) and (not statsByID[key] or id==key) then statsByID[key] = stats end
		end
	end
	GearRackCharDB.queues.Stats = statsByID
	local profiles = {}
	for _,profile in ipairs(GearRackCharDB.queues.Profiles) do
		if type(profile)=="table" and type(profile[1])=="string" and profile[1]~="" then
			local order = normalize_order(profile,2)
			table.insert(order,1,profile[1])
			table.insert(profiles,order)
		end
	end
	GearRackCharDB.queues.Profiles = profiles
	GearRackTrinkets_SortPriorityText:SetText("Priority")
	UI.Color(GearRackTrinkets_SortPriorityText,"text")
	GearRackTrinkets_SortKeepEquippedText:SetText("Pause queue")
	UI.Color(GearRackTrinkets_SortKeepEquippedText,"text")
	GearRackTrinkets.ReflectQueueEnabled()
	GearRackTrinkets.ValidateProfile()
end

function GearRackTrinkets.ReflectQueueEnabled()
	for which=0,1 do
		_G["GearRackTrinkets_Trinket"..which.."Check"]:SetChecked(GearRackCharDB.queues.Enabled[which] and not GearRackCharDB.HeldQueues[which] and not GearRackTrinkets.PausedQueue[which])
	end
	GearRackTrinkets.UpdateCombatQueue()
	GearRackEngine.StartTimer("CooldownUpdate",.1,true)
end

function GearRackTrinkets.OpenSort(which)
	GearRackTrinkets.CurrentlySorting = which
	GearRackTrinkets.PopulateSort(which)
	GearRackTrinkets.SortSelected = 0
	GearRackTrinkets_SortScrollScrollBar:SetValue(0)
	GearRackTrinkets.SortValidate()
	GearRackTrinkets.SortScrollFrameUpdate()
end

function GearRackTrinkets.GetID(bag,slot)
	local id
	if slot then id = C_Container.GetContainerItemID(bag,slot)
	else id = GetInventoryItemID("player",bag) end
	if id and id>0 then return tostring(id) end
end

function GearRackTrinkets.GetNameByID(id)
	if id==0 then
		return "-- stop queue here --","Interface\\Buttons\\UI-GroupLoot-Pass-Up",1
	else
		local name,_,quality,_,_,_,_,_,texture = GetItemInfo(id or "")
		return name or ("Item "..tostring(id)),texture or "Interface\\Icons\\INV_Misc_QuestionMark",quality or 1
	end
end

-- adds id to which sort if it's not already in the list
function GearRackTrinkets.AddToSort(which,id)
	id = queue_id(id)
	if id==nil then return end
	local found
	for i=1,#GearRackCharDB.queues.Sort[which] do
		found = found or GearRackCharDB.queues.Sort[which][i]==id
	end
	if not found then
		table.insert(GearRackCharDB.queues.Sort[which],id)
	end
end

-- populates sorts adding any new trinkets
function GearRackTrinkets.PopulateSort(which)
	GearRackCharDB.queues.Sort[which] = GearRackCharDB.queues.Sort[which] or {}
	GearRackTrinkets.AddToSort(which,GearRackTrinkets.GetID(which+13))
	GearRackTrinkets.AddToSort(which,GearRackTrinkets.GetID((1-which)+13))
    for _,entry in ipairs(GearRack.GetCarriedItems()) do
        if entry.equipLoc=="INVTYPE_TRINKET" then GearRackTrinkets.AddToSort(which,tostring(entry.baseID)) end
    end
	GearRackTrinkets.AddToSort(which,0) -- id 0 is Stop
end

function GearRackTrinkets.SortScrollFrameUpdate()
	local offset = FauxScrollFrame_GetOffset(GearRackTrinkets_SortScroll)
	local list = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting]
	FauxScrollFrame_Update(GearRackTrinkets_SortScroll, list and #list or 0, 9, 24)

	if list then
		local r,g,b,found
		local texture,name,quality
		local item,itemName,itemIcon
		for i=1,9 do
			item = _G["GearRackTrinkets_Sort"..i]
			itemName = _G["GearRackTrinkets_Sort"..i.."Name"]
			itemIcon = _G["GearRackTrinkets_Sort"..i.."Icon"]
			local idx = offset+i
			if idx<=#list then
				name,texture,quality = GearRackTrinkets.GetNameByID(list[idx])
				itemIcon:SetTexture(texture)
				itemName:SetText(name)
				r,g,b = GetItemQualityColor(quality)
				itemName:SetTextColor(r,g,b)
				itemIcon:SetVertexColor(1,1,1)
				item:Show()
				if idx == GearRackTrinkets.SortSelected then
					GearRackTrinkets.LockHighlight(item)
				else
					GearRackTrinkets.UnlockHighlight(item)
				end
			else
				item:Hide()
			end
		end
	end
end

-- The selected row is outlined; its name keeps the item's quality color.
function GearRackTrinkets.LockHighlight(frame)
	ns.SelectRow(frame,true)
end

function GearRackTrinkets.UnlockHighlight(frame)
	ns.SelectRow(frame,false)
end

-- shows tooltip for items in the sort list
function GearRackTrinkets.SortTooltip()
	local idx = FauxScrollFrame_GetOffset(GearRackTrinkets_SortScroll) + this:GetID()
	local id = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting][idx]
	local name,itemLink = GetItemInfo(id or "")
	if itemLink and GearRackDB.settings.ShowTooltips=="ON" then
		GearRackTrinkets.AnchorTooltip()
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	elseif id==0 then
		GearRackTrinkets.OnTooltip("Stop queue here","Trinkets below this line are only put on by hand.")
	elseif id then
		GearRackTrinkets.OnTooltip("Item "..tostring(id),"Item details not loaded yet.")
	end
end

function GearRackTrinkets.SortOnClick()
	GearRackTrinkets_SortDelay:ClearFocus()
	local idx = FauxScrollFrame_GetOffset(GearRackTrinkets_SortScroll) + this:GetID()
	if GearRackTrinkets.SortSelected == idx then
		GearRackTrinkets.SortSelected = 0
	else
		GearRackTrinkets.SortSelected = idx
	end
	GearRackTrinkets.SortScrollFrameUpdate()
	GearRackTrinkets.SortValidate()
end

-- turns move buttons on/off, moves the list to keep selected in view and keeps the sorting slot button highlighted
function GearRackTrinkets.SortValidate()
	local selected = GearRackTrinkets.SortSelected
	local list = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting]
	GearRackTrinkets_MoveTop:Enable()
	GearRackTrinkets_MoveUp:Enable()
	GearRackTrinkets_MoveDown:Enable()
	GearRackTrinkets_MoveBottom:Enable()
	if selected==0 or #list<2 then -- none selected, disable all
		GearRackTrinkets_MoveTop:Disable()
		GearRackTrinkets_MoveUp:Disable()
		GearRackTrinkets_MoveDown:Disable()
		GearRackTrinkets_MoveBottom:Disable()
	elseif selected==1 then -- top selected, disable up
		GearRackTrinkets_MoveUp:Disable()
		GearRackTrinkets_MoveTop:Disable()
		GearRackTrinkets_MoveDown:Enable()
	elseif selected == #list then -- bottom selected, disable down
		GearRackTrinkets_MoveDown:Disable()
		GearRackTrinkets_MoveBottom:Disable()
	end
	local idx = FauxScrollFrame_GetOffset(GearRackTrinkets_SortScroll)
	if selected>0 and list[selected] and list[selected]~=0 then
		GearRackTrinkets_SortDelay:Show()
		GearRackTrinkets_SortPriority:Show()
		GearRackTrinkets_SortKeepEquipped:Show()
		GearRackTrinkets_Delete:Enable()
	else
		GearRackTrinkets_SortDelay:Hide()
		GearRackTrinkets_SortPriority:Hide()
		GearRackTrinkets_SortKeepEquipped:Hide()
		GearRackTrinkets_Delete:Disable()
	end
	local stats = GearRackCharDB.queues.Stats[list[GearRackTrinkets.SortSelected]]
	GearRackTrinkets_SortDelay:SetText(stats and (stats.delay or "0") or "0")
	GearRackTrinkets_SortPriority:SetChecked(stats and stats.priority)
	GearRackTrinkets_SortKeepEquipped:SetChecked(stats and stats.keep)

	if not IsShiftKeyDown() and selected>0 then -- keep selected visible on list, moving thumb as needed, unless shift is down
		local parent = GearRackTrinkets_SortScrollScrollBar
		local offset
		if selected <= idx then
			offset = (selected==1) and 0 or (parent:GetValue() - (parent:GetHeight() / 2))
			parent:SetValue(offset)
			PlaySound("UChatScrollButton")
		elseif selected >= (idx+9) then
			offset = (selected==#list) and GearRackTrinkets_SortScroll:GetVerticalScrollRange() or (parent:GetValue() + (parent:GetHeight() / 2))
			parent:SetValue(offset)
			PlaySound("UChatScrollButton");
		end
	end
end

-- movement buttons
function GearRackTrinkets.SortMove()
	GearRackTrinkets_SortDelay:ClearFocus()
	local dir = ((this==GearRackTrinkets_MoveUp) and -1) or ((this==GearRackTrinkets_MoveTop) and "top") or ((this==GearRackTrinkets_MoveDown) and 1) or ((this==GearRackTrinkets_MoveBottom) and "bottom")
	local list = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting]
	local idx1 = GearRackTrinkets.SortSelected -- FauxScrollFrame_GetOffset(GearRackUI_Config_SortScroll) +
	if dir then
		local idx2 = ((dir=="top") and 1) or ((dir=="bottom") and #list) or idx1+dir
		local temp = list[idx1]
		if tonumber(dir) then
			list[idx1] = list[idx2]
			list[idx2] = temp
		elseif dir=="top" then
			table.remove(list,idx1)
			table.insert(list,1,temp)
		elseif dir=="bottom" then
			table.remove(list,idx1)
			table.insert(list,temp)
		end
		GearRackTrinkets.SortSelected = idx2
	elseif this==GearRackTrinkets_Profiles then
		GearRackTrinkets.SortSelected = 0
		GearRackTrinkets.ShowProfiles(GearRackTrinkets_SortListFrame:IsVisible())
	elseif this==GearRackTrinkets_Delete then
		table.remove(list,idx1)
		GearRackTrinkets.SortSelected = 0
	end
	GearRackTrinkets.SortValidate()
	GearRackTrinkets.SortScrollFrameUpdate()
end

function GearRackTrinkets.SortDelay_OnTextChanged()
	local delay = tonumber(GearRackTrinkets_SortDelay:GetText()) or 0
	local sort = GearRackCharDB.queues.Sort
	local list = sort and sort[GearRackTrinkets.CurrentlySorting]
	local id = list and list[GearRackTrinkets.SortSelected]
	-- SetText also fires this callback while clearing the editor's selection.
	if not id or id==0 then return end
	if delay~=delay or delay<0 or delay==math.huge then delay = 0 end
	GearRackCharDB.queues.Stats[id] = GearRackCharDB.queues.Stats[id] or {}
	GearRackCharDB.queues.Stats[id].delay = delay~=0 and delay or nil
end

function GearRackTrinkets.SortPriority_OnClick()
	local check = this:GetChecked()
	local id = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting][GearRackTrinkets.SortSelected]
	GearRackCharDB.queues.Stats[id] = GearRackCharDB.queues.Stats[id] or {}
	GearRackCharDB.queues.Stats[id].priority = check
end

function GearRackTrinkets.SortKeepEquipped_OnClick()
	local check = this:GetChecked()
	local id = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting][GearRackTrinkets.SortSelected]
	GearRackCharDB.queues.Stats[id] = GearRackCharDB.queues.Stats[id] or {}
	GearRackCharDB.queues.Stats[id].keep = check
end

function GearRackTrinkets.TabCheck_OnClick()
	GearRack.ResumeTrinketQueue(3-this:GetID())
	GearRackTrinkets.PausedQueue[3-this:GetID()]=nil
	GearRackCharDB.queues.Enabled[3-this:GetID()] = this:GetChecked() and 1 or nil
	if not this:GetChecked() then GearRack.CancelAutomaticTrinket(3-this:GetID()) end
	GearRackTrinkets.ReflectQueueEnabled()
	GearRackTrinkets.UpdateCombatQueue()
end

--[[ Auto queue processing ]]

function GearRackTrinkets.TrinketNearReady(bag,slot)
	local start,duration
	if slot then
		start,duration = GetContainerItemCooldown(bag,slot)
	else
		start,duration = GearRack.GetInventoryCooldown(bag)
	end
	if start==0 or duration-(GetTime()-start)<=30 then
		return 1
	end
end

-- this function quickly checks if conditions are right for a possible ProcessAutoQueue
function GearRackTrinkets.PeriodicQueueCheck()
	for i=0,1 do
		if GearRackCharDB.queues.Enabled[i] then
			GearRackTrinkets.ProcessAutoQueue(i)
		end
	end
end

local function automatic_owner_busy()
	return GearRack.worldSuspended or GearRackEngine.BankTransfer
		or GearRackEngine.SwapRequest or GearRackEngine.SetSwapping or GearRackEngine.SwapIssuing
		or #GearRackEngine.SwapQueueOrder>0 or GearRackEngine.PendingCombatRequest
		or next(GearRackEngine.CombatQueue)
end

local function reserved_for_other_slot(entry,slot)
	for other,request in pairs(GearRack.Requests) do
		if other~=slot and entry.guid and request.guid==entry.guid then return true end
	end
end

local NONE = {}
local function ready_carried_trinket(id,slot)
	for _,entry in ipairs(GearRack.ByID[tonumber(id)] or NONE) do
		if entry.equipLoc=="INVTYPE_TRINKET" and not reserved_for_other_slot(entry,slot)
			and C_PlayerInfo.CanUseItem(entry.baseID) then
			if entry.guid and GearRack.BagGUID(entry.bag,entry.slot)==entry.guid then
				if GearRackTrinkets.TrinketNearReady(entry.bag,entry.slot) then return entry end
			else
				GearRack.InvalidateBag(entry.bag)
			end
		end
	end
end

-- Pending automatic proposals are tentative. A physical transaction owns the
-- equipment, but a combat/cast wait must not freeze either slot's priorities.
function GearRackTrinkets.GetAutomaticChoice(which)
	if which~=0 and which~=1 then return nil,"blocked" end
	if automatic_owner_busy() then return nil,"blocked" end
	local slot=13+which
	local pending=GearRack.Requests[slot]
	if pending and not pending.automatic or IsInventoryItemLocked(slot) then return nil,"blocked" end
	if not GearRackCharDB.queues.Enabled[which] then return end
	if GearRackCharDB.HeldQueues[which] or GearRackTrinkets.PausedQueue[which] then return nil,"pause" end
	local id=GetInventoryItemID("player",slot)
	id=id and tostring(id) or nil
	local start,duration,enable=GearRack.GetInventoryCooldown(slot)
	local elapsed=GetTime()-start
	local remaining=duration-elapsed
	local stats=GearRackCharDB.queues.Stats[id]
	if stats then
		if stats.keep and (enable~=1 or start==0 or remaining<31) then return nil,"pause" end
		if stats.delay and start>0 and remaining>30 and elapsed<stats.delay then return nil,"delay" end
	end
	local ready=start==0 or remaining<=30
	local list=GearRackCharDB.queues.Sort[which]
	local rank
	for i=1,#list do
		if list[i]==0 or ready and tostring(list[i])==id then rank=i;break end
	end
	if not rank then return end
	GearRack.GetCarriedItems()
	for i=1,rank do
		local candidate=list[i]
		if candidate==0 then break end
		local candidateStats=GearRackCharDB.queues.Stats[candidate]
		local alreadyWorn=tostring(candidate)==id and (ready or enable==0)
		if not alreadyWorn and (not id or not ready or enable==0 or candidateStats and candidateStats.priority) then
			local entry=ready_carried_trinket(candidate,slot)
			if entry then return entry end
		end
	end
end

local function reflect_automatic_state(which,state)
	GearRackTrinkets.ReflectQueueState(which,state)
end

function GearRackTrinkets.ProcessAutoQueue(which)
	local entry,state=GearRackTrinkets.GetAutomaticChoice(which)
	if state=="blocked" then return end
	if entry then GearRack.RequestItem(13+which,entry,true)
	else GearRack.CancelAutomaticTrinket(which) end
	reflect_automatic_state(which,state)
end

-- The shared pump calls this after waits end, before issuing a native equip.
function GearRackTrinkets.ValidateAutomaticRequest(request)
	local which=request.slot-13
	local entry,state=GearRackTrinkets.GetAutomaticChoice(which)
	if state=="blocked" then return false,false end
	if entry and entry.id==request.id and entry.guid==request.guid then return true end
	if entry then GearRack.RequestItem(request.slot,entry,true)
	else GearRack.CancelAutomaticTrinket(which) end
	reflect_automatic_state(which,state)
	return false,true
end

--[[ GearRackTrinkets.SetQueue and GearRackTrinkets.GetQueue ]]

-- These functions are for macros and mods to configure sort queues.

-- GearRackTrinkets.SetQueue(0 or 1,"ON" or "OFF" or "PAUSE" or "RESUME" or "SORT"[,"sort list")
-- some examples:
-- GearRackTrinkets.SetQueue(1,"PAUSE") -- if queue is going, pause it
-- GearRackTrinkets.SetQueue(1,"RESUME") -- if queue is paused, resume it
-- GearRackTrinkets.SetQueue(1,"SORT","Trinket A","Trinket B") -- set sort by exact names
-- GearRackTrinkets.SetQueue(1,"SORT","PvP") -- or load a profile by name
-- (a "stop the queue" is assumed at the end of the list)
function GearRackTrinkets.SetQueue(which,...)
	local errorstub = "|cFFBBBBBBGearRack:|cFFFFFFFF "
	which=tonumber(which)
	if which~=0 and which~=1 then
		DEFAULT_CHAT_FRAME:AddMessage(errorstub.."First parameter must be 0 for top trinket or 1 for bottom.")
		return
	end
	local action,count = ...,select("#",...)
	if action == nil then
		DEFAULT_CHAT_FRAME:AddMessage(errorstub.."Second parameter is either ON, OFF, PAUSE, RESUME or the beginning of a list of trinkets in a sort order.")
		return
	end
	if GearRackTrinkets_OptFrame:IsVisible() then
		GearRackTrinkets_OptFrame:Hide() -- close option frame if it's up. the mess otherwise would be scary
	end
	if action=="ON" then
			GearRack.ResumeTrinketQueue(which)
		GearRackCharDB.queues.Enabled[which]=1
		GearRackTrinkets.PausedQueue[which]=nil
	elseif action=="OFF" then
		GearRack.CancelAutomaticTrinket(which)
		GearRackCharDB.queues.Enabled[which]=nil
		GearRackTrinkets.PausedQueue[which]=nil
	elseif action=="PAUSE" then
		GearRack.CancelAutomaticTrinket(which)
		GearRackTrinkets.PausedQueue[which]=1
	elseif action=="RESUME" then
			GearRack.ResumeTrinketQueue(which)
		GearRackTrinkets.PausedQueue[which]=nil
	elseif action=="SORT" and count > 1 then
		local order,inv,bag,slot = {}
		local profile = GearRackTrinkets.GetProfileID((select(2,...)))
		if profile then
			order = normalize_order(GearRackCharDB.queues.Profiles[profile],2)
		else
			for i=2,count do
				local name = select(i,...)
				inv,bag,slot = GearRackTrinkets.FindItem(name,1) -- include inventory
				if inv then
					table.insert(order,GearRackTrinkets.GetID(inv))
				elseif bag then
					table.insert(order,GearRackTrinkets.GetID(bag,slot))
				else
					DEFAULT_CHAT_FRAME:AddMessage(errorstub.."Trinket or profile \""..tostring(name).."\" not found.")
				end
			end
			-- A misspelled profile or unavailable list must not erase the old order.
			if #order==0 then return end
			table.insert(order,0)
		end
		local list = GearRackCharDB.queues.Sort[which]
		table.wipe(list)
		for _,id in ipairs(normalize_order(order)) do table.insert(list,id) end
	else
		DEFAULT_CHAT_FRAME:AddMessage(errorstub.." Expected ON, OFF, PAUSE, RESUME or SORT+list")
	end

	GearRackTrinkets.ReflectQueueEnabled()
	GearRackTrinkets.UpdateCombatQueue()

end

-- returns 1 or nil if queue is enabled, and a table containing an ordered list of the trinkets
function GearRackTrinkets.GetQueue(which)
	which=tonumber(which)
	if which~=0 and which~=1 then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFBBBBBBGearRackTrinkets.GetQueue:|cFFFFFFFF Parameter must be 0 for top trinket or 1 for bottom.")
		return
	end
	local trinketList,name = {}
	for i=1,#GearRackCharDB.queues.Sort[which] do
		name = GearRackTrinkets.GetNameByID(GearRackCharDB.queues.Sort[which][i])
		table.insert(trinketList,name)
	end
	return GearRackCharDB.queues.Enabled[which],trinketList
end

--[[ Profiles ]]

-- shows profile if show non-nil. GearRackTrinkets_ProfilesFrame has an OnHide that calls this with nil
function GearRackTrinkets.ShowProfiles(show)
	local normalTexture = GearRackTrinkets_Profiles:GetNormalTexture()
	local pushedTexture = GearRackTrinkets_Profiles:GetPushedTexture()
	if show then
		GearRackTrinkets_SortListFrame:Hide()
		GearRackTrinkets_ProfilesFrame:Show()
		normalTexture:SetTexCoord(.875,1,.25,.375)
		pushedTexture:SetTexCoord(.75,.875,.25,.375)
		GearRack.SetEscapable("GearRackTrinkets_ProfilesFrame",true)
		GearRack.SetEscapable("GearRackTrinkets_OptFrame",false)
	else
		GearRackTrinkets_SortListFrame:Show()
		GearRackTrinkets_ProfilesFrame:Hide()
		pushedTexture:SetTexCoord(.875,1,.25,.375)
		normalTexture:SetTexCoord(.75,.875,.25,.375)
		GearRack.SetEscapable("GearRackTrinkets_ProfilesFrame",false)
		GearRack.SetEscapable("GearRackTrinkets_OptFrame",true)
	end
end

function GearRackTrinkets.ProfilesFrame_OnHide()
	PlaySound("GAMEGENERICBUTTONPRESS")
	GearRackTrinkets.ResetProfileSelected()
	GearRackTrinkets.ShowProfiles(nil)
end

function GearRackTrinkets.ResetProfileSelected()
	GearRackTrinkets.ProfileSelected = nil
	GearRackTrinkets_ProfileName:SetText("")
	GearRackTrinkets.ProfileScrollFrameUpdate()
	GearRackTrinkets.ValidateProfile()
end

function GearRackTrinkets.ProfileScrollFrameUpdate()
	local offset = FauxScrollFrame_GetOffset(GearRackTrinkets_ProfileScroll)
	local list = GearRackCharDB.queues.Profiles
	FauxScrollFrame_Update(GearRackTrinkets_ProfileScroll, #list, 7, 20)

	local item
	for i=1,7 do
		local idx = offset+i
		item = _G["GearRackTrinkets_Profile"..i]
		if idx<=#list then
			_G["GearRackTrinkets_Profile"..i.."Name"]:SetText(list[idx][1])
			item:Show()
			ns.SelectRow(item,GearRackTrinkets.ProfileSelected==idx)
		else
			item:Hide()
		end
	end

	if #list==0 then
		GearRackTrinkets_Profile1Name:SetText("No profiles saved yet.")
		GearRackTrinkets_Profile1:Show()
		ns.SelectRow(GearRackTrinkets_Profile1,false)
	end

end

function GearRackTrinkets.ProfileList_OnClick()
	if #GearRackCharDB.queues.Profiles>0 then
		local idx = this:GetID() + FauxScrollFrame_GetOffset(GearRackTrinkets_ProfileScroll)
		if GearRackTrinkets.ProfileSelected == idx then
			GearRackTrinkets.ProfileSelected = nil
			GearRackTrinkets_ProfileName:SetText("")
		else
			GearRackTrinkets.ProfileSelected = idx
			GearRackTrinkets_ProfileName:SetText(GearRackCharDB.queues.Profiles[idx][1])
		end
		GearRackTrinkets.ProfileScrollFrameUpdate()
		GearRackTrinkets.ValidateProfile()
	end
end

function GearRackTrinkets.GetProfileID(name)
	for i=1,#GearRackCharDB.queues.Profiles do
		if GearRackCharDB.queues.Profiles[i][1]==name then
			return i
		end
	end
end

function GearRackTrinkets.ValidateProfile()
	local name = GearRackTrinkets_ProfileName:GetText() or ""
	local saved = GearRackTrinkets.GetProfileID(name) and true or false
	UI.SetEnabled(GearRackTrinkets_ProfilesDelete,saved)
	UI.SetEnabled(GearRackTrinkets_ProfilesLoad,saved)
	UI.SetEnabled(GearRackTrinkets_ProfilesSave,#name>0)
end

function GearRackTrinkets.ProfileName_OnTextChanged()
	GearRackTrinkets.ProfileSelected = GearRackTrinkets.GetProfileID(GearRackTrinkets_ProfileName:GetText())
	GearRackTrinkets.ProfileScrollFrameUpdate()
	GearRackTrinkets.ValidateProfile()
end

function GearRackTrinkets.ProfilesButton_OnClick()
	local idx = GearRackTrinkets.ProfileSelected
	local name = GearRackTrinkets_ProfileName:GetText() or ""

	if this==GearRackTrinkets_ProfilesDelete then
		if idx and GearRackCharDB.queues.Profiles[idx] then
			table.remove(GearRackCharDB.queues.Profiles,idx)
		end
		GearRackTrinkets.ResetProfileSelected()
	elseif this==GearRackTrinkets_ProfilesSave then
		if idx and GearRackCharDB.queues.Profiles[idx] then
			table.remove(GearRackCharDB.queues.Profiles,idx)
		end
		table.insert(GearRackCharDB.queues.Profiles,1,{name})
		local list = GearRackCharDB.queues.Sort[GearRackTrinkets.CurrentlySorting]
		local save = GearRackCharDB.queues.Profiles[1]
		for i=1,#list do
			table.insert(save,list[i])
			if list[i]==0 then
				break
			end
		end
		GearRackTrinkets_ProfilesFrame:Hide()
	elseif this==GearRackTrinkets_ProfilesLoad then
		GearRackTrinkets.LoadProfile(GearRackTrinkets.CurrentlySorting,idx)
	elseif this==GearRackTrinkets_ProfilesCancel then
		GearRackTrinkets_ProfilesFrame:Hide()
	end
end

function GearRackTrinkets.ProfileList_OnDoubleClick()
	if #GearRackCharDB.queues.Profiles>0 then
		local idx = this:GetID() + FauxScrollFrame_GetOffset(GearRackTrinkets_ProfileScroll)
		if GearRackCharDB.queues.Profiles[idx] then
			GearRackTrinkets.LoadProfile(GearRackTrinkets.CurrentlySorting,idx)
		end
	end
end

function GearRackTrinkets.LoadProfile(which,idx)
	local list = GearRackCharDB.queues.Sort[which]
	local load = GearRackCharDB.queues.Profiles[idx]
	table.wipe(list)
	for i=2,#load do
		table.insert(list,load[i])
	end
	GearRackTrinkets_ProfilesFrame:Hide()
	GearRackTrinkets.OpenSort(which)
end
