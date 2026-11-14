if not GearRack.enabled then return end

-- The equipment engine: set swaps in stages, the combat and death queue,
-- restore data, the timer owner and bank moves. It owns no frames; the bar,
-- flyouts and editors (Equipment.lua) and the requests (Core.lua) call it.
-- The saved sets are those of GearRack.user, the character key set at login.

GearRackEngine = {
	TimerPool = {}, -- runtime timer metadata and cancellable ClassicAPI handles

	SetSwapping = nil, -- name of a set currently being swapped
	SwapList = {}, -- individual item swap details go here
	LockList = {}, -- tables of bags where slots are locked (to be skipped in FindItem and FindSpace)
	CombatQueue = {}, -- table of items to swap in when dropping out of combat/death
	CombatQueueOwner = {} -- request owning each deferred slot (nil for manual queue entries)
}

--[[ Initialization ]]

function GearRackEngine.Initialize()

	for i=0,19 do GearRackEngine.SwapList[i]={} end -- create blank SwapList table
	for i=-2,10 do GearRackEngine.LockList[i]={} end -- create a blank Locked table

	if not GearRackDB.sets then
		GearRackDB.sets = {}
	end

	if not GearRackDB.sets[GearRack.user] then
		GearRackDB.sets[GearRack.user] = { Sets={}, CurrentSet=nil }
	end

	-- note: these timers are added to a pool, they don't affect processing time unless started
	GearRackEngine.CreateTimer("WaitToIterate",GearRackEngine.IterateWait,1) -- itemlock iterate pause
	GearRackEngine.CreateTimer("CooldownUpdate",GearRack.CooldownUpdate,1) -- wakes when a label, alert or queue needs it
	GearRackEngine.CreateTimer("BankTransferCheck",GearRackEngine.ReconcileBankTransfer,.2)
	-- A bank sort or a cold bank sends dozens of bank events in one frame: one rescan.
	GearRackEngine.CreateTimer("BankScan",GearRackEngine.PopulateBank,0)
end

function GearRackEngine.OnEvent(ev)
	if GearRack.worldSuspended then return end
	ev = ev or event

	if ev=="ITEM_LOCK_CHANGED" then
		GearRackEngine.ReconcileBankTransfer()
		GearRackEngine.OnItemLockChanged()
		GearRack.Wake()
	elseif ev=="PLAYER_REGEN_ENABLED" or ev=="PLAYER_UNGHOST" or ev=="PLAYER_ALIVE" then
		if GearRackEngine.IsPlayerReallyDead() then return end
		GearRack.Wake()
		-- Finish the active transaction before consuming deferred work.
		if GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue();return end
		if UnitAffectingCombat("player") then return end
		local items
		for i=0,19 do
			if GearRackEngine.CombatQueue[i] then
				items = items or {} -- vanillaforge-ignore: D2 (only when gear waited for combat to end)
				local owner=GearRackEngine.CombatQueueOwner[i]
				local wanted=owner and owner.items and owner.items[i]
				items[i] = {id=GearRackEngine.CombatQueue[i],name=wanted and wanted.name,guid=wanted and wanted.guid} -- vanillaforge-ignore: D2 (the set the request keeps)
				GearRackEngine.CombatQueue[i] = nil
				GearRackEngine.CombatQueueOwner[i] = nil
			end
			GearRack.ShowQueueBadge(i,false)
		end
		if items then
			GearRackEngine.EquipSet("GearRackEngine-CombatQueue",nil,{items=items,completionOf=GearRackEngine.PendingCombatRequest}) -- vanillaforge-ignore: D2 (once per deferred set)
		end
	end
end

--[[ Item information ]]

-- Returns texture, variant ID, name, equip location, quality and raw base ID.
-- The final value identifies cold container items before their link is available.
function GearRackEngine.GetItemInfo(bag,slot)
	local id,itemLink,itemID,itemSlot,itemTexture,itemName,itemQuality,rawID

	if slot then -- this is a container item
		rawID=C_Container.GetContainerItemID(bag,slot)
		if not rawID then return nil end
		itemLink = GetContainerItemLink(bag,slot)
	else
		itemLink = GetInventoryItemLink("player",bag)
		itemQuality = GetInventoryItemQuality("player",bag)
	end

	if itemLink then
		_,_,id,itemID = string.find(itemLink,"(item:(%d+:%-?%d+:%-?%d+):%-?%d+)")
		local q
		itemName,_,q,_,_,_,_,itemSlot,itemTexture = GetItemInfo(id or itemLink)
		itemQuality = itemQuality or q
	elseif not slot then -- if no link and this is an inventory slot, missing or ammo
		_,itemTexture = GetInventorySlotInfo(GearRackEngine.SlotInfo[bag].slotName) -- get paperdoll texture
		itemID = 0 -- assume empty slot
		-- The ammo slot has no item link. NamPower names the equipped ammo directly;
		-- ammo has no enchant or suffix, so its variant ID is "<id>:0:0".
		local ammoID = bag==0 and GetAmmo()
		if ammoID then
			local q,texture
			itemName,_,q,_,_,_,_,itemSlot,texture = GetItemInfo(ammoID)
			itemID = ammoID..":0:0"
			itemQuality = GetInventoryItemQuality("player",0) or q
			itemTexture = GetInventoryItemTexture("player",0) or texture or itemTexture
		end
	end

	if not itemQuality and slot then
		if rawID then
			local _, _, q = GetItemInfo(rawID)
			itemQuality = q
		end
	end

	return itemTexture, itemID, itemName, itemSlot, itemQuality,rawID
end

-- converts a name to an itemID by searching through inventory, bags and bank for the item
function GearRackEngine.GetItemID(itemName)

	local inv,bag,slot = GearRackEngine.FindItem(nil,itemName)
	local itemID

	if inv then
		_,itemID = GearRackEngine.GetItemInfo(inv)
	elseif bag and slot then
		_,itemID = GearRackEngine.GetItemInfo(bag,slot)
	end

	return itemID
end

-- returns the name and texture of an item by its itemID
function GearRackEngine.GetNameByID(itemID)
	local name,texture
	local _,_,id = string.find(itemID or "","^(%d+):%-?%d+:%-?%d+$")
	name,_,_,_,_,_,_,_,texture = GetItemInfo(id or "")
	if itemID==0 then
		name = "(empty)"
		texture = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
	end
	return name,texture
end

-- The first empty slot of a general-purpose bag (family 0: not a quiver, ammo
-- pouch or other special bag) that no move has claimed. ClassicAPI answers the
-- free slots and the family of the carried bags, and of the bank while it is
-- open (1.19.3); a bag that is not there has no family.
function GearRackEngine.FindSpaceInBag(bag)
	local free,family = C_Container.GetContainerNumFreeSlots(bag)
	if family~=0 or free==0 then return end
	local locks = GearRackEngine.LockList[bag]
	for _,slot in ipairs(C_Container.GetContainerFreeSlots(bag)) do
		if not locks[slot] then return slot end
	end
end

-- pass a value for bank to find a free bank slot
function GearRackEngine.FindSpace(bank)
	local slot
	if bank and GearRackUI.BankIsOpen then -- search bank
		for _,i in ipairs(GearRackUI.BankSlots) do
			slot = GearRackEngine.FindSpaceInBag(i)
			if slot then
				GearRackEngine.LockList[i][slot] = 1
				return i,slot
			end
		end
	else
		for i=4,0,-1 do
			slot = GearRackEngine.FindSpaceInBag(i)
			if slot then
				GearRackEngine.LockList[i][slot] = 1
				return i,slot
			end
		end
	end
end

-- clears locks on all bag slots
function GearRackEngine.ClearLockList(bag,slot)
	if not bag then
		for i=-2,10 do
			for j in pairs(GearRackEngine.LockList[i]) do
				GearRackEngine.LockList[i][j] = nil
			end
		end
	else
		GearRackEngine.LockList[bag][slot] = nil
	end
end

-- returns inv,bag,slot of an itemID, or itemName if itemID doesn't exist
function GearRackEngine.FindItem(itemID,itemName,passive)
    local inv,bag,slot=GearRack.FindLocation(itemID,itemName,passive,true)
    if not inv and not bag and itemName then return GearRack.FindLocation(nil,itemName,passive,true) end
    return inv,bag,slot
end

-- Whether the item with this GUID is carried or worn.
function GearRackEngine.HasInstance(guid)
	if GearRack.GetCarriedItems() and GearRack.ByGUID[guid] then return true end
	for slot=1,19 do
		if GearRack.EquippedGUID(slot)==guid then return true end
	end
end

-- A set slot's item: its saved copy (GUID) when that is carried or worn, else any
-- copy by item and name. Fills in the item ID when only the name was known.
function GearRackEngine.FindSetItem(setslot)
	local inv,bag,slot
	if setslot.guid then inv,bag,slot=GearRack.FindLocation(setslot.id,setslot.name,nil,true,setslot.guid) end
	if not inv and not bag then inv,bag,slot=GearRackEngine.FindItem(setslot.id,setslot.name) end
	if not setslot.id and setslot.name and (inv or bag or slot) then
		setslot.id = GearRackEngine.GetItemID(setslot.name)
	end
	return inv,bag,slot
end

--[[ Queue maintenance

	To prevent garbage creation in creating/destroying multi-level tables, queue entries are reused and only
	the index to that queue entry is created/destroyed.

	.SwapQueue is where the tables sit, indexed arbitrarily by the first available one returned by GetFreeQueueEntry
	.SwapQueueOrder is a numerically-indexed table of indexes into .SwapQueue in the order the swap should happen
]]

GearRackEngine.SwapQueue = { [1]={ direction = "END" } } -- numerically-indexed queue of swaps to perform
GearRackEngine.SwapQueueOrder = {} -- numerically-indexed queue of numbers in the order they're to be performed

-- Read-only coordination point for addons that must not issue equipment moves
-- while an GearRackUI transaction or deferred combat swap owns the equipment.
function GearRackEngine.IsEquipmentSwapActive()
	return GearRackEngine.BankTransfer~=nil or GearRackEngine.SwapRequest~=nil or GearRackEngine.SetSwapping~=nil or GearRackEngine.SwapIssuing~=nil or #GearRackEngine.SwapQueueOrder>0
		or GearRackEngine.PendingCombatRequest~=nil or next(GearRackEngine.CombatQueue)~=nil or GearRack.HasPending()
end
GearRackEngine.SwapUndo = {} -- implicit weapon-slot changes; never written into saved sets
GearRackEngine.UndoToken = {} -- identifies the successful request whose undo data is retained
GearRackEngine.UndoOwner = {} -- saved definition owning this session's undo history

function GearRackEngine.ForgetSetUndo(setname)
	GearRackEngine.SwapUndo[setname]=nil
	GearRackEngine.UndoToken[setname]=nil
	GearRackEngine.UndoOwner[setname]=nil
end

-- wipes out an entry without creating garbage
function GearRackEngine.ClearQueueEntry(idx)

	GearRackEngine.SwapQueue[idx].direction = nil
	GearRackEngine.SwapQueue[idx].setname = nil
	GearRackEngine.SwapQueue[idx].restoreSetName = nil
	GearRackEngine.SwapQueue[idx].context = nil
	GearRackEngine.SwapQueue[idx].started = nil
	GearRackEngine.SwapQueue[idx].deadline = nil
	GearRackEngine.SwapQueue[idx].lastAttempt = nil
	for i=0,19 do
		GearRackEngine.SwapQueue[idx][i].id = nil
		GearRackEngine.SwapQueue[idx][i].fromBag = nil
		GearRackEngine.SwapQueue[idx][i].fromSlot = nil
		GearRackEngine.SwapQueue[idx][i].guid = nil
	end
end

-- creates a new table and sub-table queue entries, only call when entry didn't exist before
function GearRackEngine.ConstructQueueEntry(idx)
	GearRackEngine.SwapQueue[idx] = {}
	for i=0,19 do
		GearRackEngine.SwapQueue[idx][i] = {}
	end
end

-- get first available index into SwapQueue for use for a set. to avoid garbage creation these are reused
function GearRackEngine.GetFreeQueueEntry()
	local i,found = 1,1

	while found do
		found = GearRackEngine.SwapQueue[i]
		if found and not found.direction then
			return i
		end
		i = i + 1
	end
	i = i - 1 -- backtrack to last available entry

	GearRackEngine.ConstructQueueEntry(i)
	return i
end

-- adds the .SwapQueue idx to the end of the QueueOrder
function GearRackEngine.AddQueueEntry(idx)
	table.insert(GearRackEngine.SwapQueueOrder,idx)
end

-- removes the .SwapQueue idx from QueueOrder and clears the .SwapQueue entry
function GearRackEngine.RemoveQueueEntry(idx)
	for i=1,#GearRackEngine.SwapQueueOrder do
		if GearRackEngine.SwapQueueOrder[i]==idx then
			table.remove(GearRackEngine.SwapQueueOrder,i)
			GearRackEngine.ClearQueueEntry(idx)
			return
		end
	end
end

-- this sorts the queue, moving all NEWSETs to the end
function GearRackEngine.SortQueue()

	if #GearRackEngine.SwapQueueOrder>1 then
		local found,temp = 1
		local queue = GearRackEngine.SwapQueueOrder
		-- simple shell sort (this is a small, 5-6 max typically) table of indexes that must remain in order otherwise
		while found do
			found = nil
			for i=1,(#queue-1) do
				if GearRackEngine.SwapQueue[queue[i]].direction=="NEWSET" and GearRackEngine.SwapQueue[queue[i+1]].direction~="NEWSET" then
					temp = queue[i]
					queue[i] = queue[i+1]
					queue[i+1] = temp
					found = 1
				end
			end
		end
	end
end

--[[ Set Maintenance

	Sets are tables in GearRackDB.sets[GearRack.user].Sets[setname] structured as:
	{ hide=1/nil, icon="Interface\\Icons\\etc", ["0"]={id=string,name=string,old=string} }
	id = itemID for the item to wear in the set, 0 for (empty) (can be nil)
	name = name of the item to wear in the set, (empty) for empty
	old = itemID for the item worn in this slot prior to this set equipped, usually nil
]]

function GearRackEngine.ClearSwapListEntry(idx)
	GearRackEngine.SwapList[idx].needsSwap = nil
	GearRackEngine.SwapList[idx].sourceInv = nil
	GearRackEngine.SwapList[idx].sourceBag = nil
	GearRackEngine.SwapList[idx].sourceSlot = nil
	GearRackEngine.SwapList[idx].direction = nil
	GearRackEngine.SwapList[idx].desiredName = nil
	GearRackEngine.SwapList[idx].needsEmptied = nil
end

-- returns the currently worn set, or last set worn
function GearRackEngine.CurrentSet()
	return GearRackDB.sets[GearRack.user].CurrentSet
end

--[[ EquipSet
	This function takes a setname and then equips the set, saving what it's replacing within the set.
]]

-- Unlike IsSetEquipped, completion checks actual equipment, not the combat queue.
function GearRackEngine.SlotMatches(slot,wanted)
    local _,id,name=GearRackEngine.GetItemInfo(slot)
    return (not wanted.id or id==wanted.id) and (wanted.id or name==wanted.name)
        and (not wanted.guid or GearRack.EquippedGUID(slot)==wanted.guid)
end

function GearRackEngine.SwapMatches(items)
	for i=0,19 do
		local wanted = items[i]
		if wanted and (wanted.id or wanted.name) then
			local _,id,name = GearRackEngine.GetItemInfo(i)
			if (wanted.id and id~=wanted.id) or (not wanted.id and name~=wanted.name)
                or (wanted.guid and GearRack.EquippedGUID(i)~=wanted.guid) then
				return false
			end
		end
	end
	return true
end

local function capture_saved_definition(name)
	local definition=GearRackDB.sets[GearRack.user].Sets[name]
	if not definition then return end
	local items={showhelm=definition.showhelm,showcloak=definition.showcloak}
	for i=0,19 do
		local item=definition[i]
		if item then items[i]={id=item.id,name=item.name,guid=item.guid} end
	end
	return {definition=definition,items=items}
end

local function owns_saved_definition(name,owner)
	local definition=GearRackDB.sets[GearRack.user].Sets[name]
	if not owner or definition~=owner.definition or definition.showhelm~=owner.items.showhelm
		or definition.showcloak~=owner.items.showcloak then return end
	for i=0,19 do
		local item,wanted=definition[i],owner.items[i]
		if (item and not wanted) or (wanted and not item)
			or (item and (item.id~=wanted.id or item.name~=wanted.name or item.guid~=wanted.guid)) then return end
	end
	return true
end

function GearRackEngine.CompleteSwapRequest(request)
	if not request.cancelled and not request.superseded and not request.missing and GearRackEngine.SwapMatches(request.items) then
		local saved = GearRackDB.sets[GearRack.user].Sets[request.setname]
		local ownsDefinition=owns_saved_definition(request.setname,request.definitionOwner)
		if request.undo and saved and ownsDefinition and not request.undoOf and request.setname~="GearRackEngine-CombatQueue" then
			for i=0,19 do
				if request.undo[i] and saved[i] then saved[i].old,saved[i].oldguid = request.undo[i],request.undoGUIDs[i] end
			end
			saved.oldsetname = request.previousSetName
			GearRackEngine.SwapUndo[request.setname] = request.implicitUndo
			GearRackEngine.UndoToken[request.setname] = request.undoToken
			GearRackEngine.UndoOwner[request.setname] = request.definitionOwner
		end
		if request.undoOf and GearRackEngine.UndoToken[request.undoOf]==request.sourceUndoToken then
			local old = GearRackDB.sets[GearRack.user].Sets[request.undoOf]
			if old and owns_saved_definition(request.undoOf,request.undoMetadataOwner) then
				for i=0,19 do if old[i] then old[i].old,old[i].oldguid = nil,nil end end
				old.oldsetname = nil
			end
			GearRackEngine.ForgetSetUndo(request.undoOf)
		end
		local name = request.restoreSetName or request.setname
		local nameOwner=request.restoreSetName and request.restoreDefinitionOwner or request.definitionOwner
		if name and owns_saved_definition(name,nameOwner)
			and (not request.restoreSetName or GearRackEngine.SwapMatches(nameOwner.items))
			and not string.find(name,"^GearRackEngine-") and not string.find(name,"^GearRackUI") then
			GearRackDB.sets[GearRack.user].CurrentSet = name
		end
		if request.completionOf and GearRackEngine.PendingCombatRequest==request.completionOf then
			GearRackEngine.CompleteSwapRequest(request.completionOf)
			GearRackEngine.PendingCombatRequest = nil
		end
		return true
	end
end

-- Cancel only slots still owned by this request; manual queue entries survive.
function GearRackEngine.CancelDeferredRequest(request)
	if not request then return end
	request.cancelled = true
	for i=0,19 do
		if GearRackEngine.CombatQueueOwner[i]==request then
			GearRackEngine.CombatQueue[i] = nil
			GearRackEngine.CombatQueueOwner[i] = nil
			GearRack.ShowQueueBadge(i,false)
		end
	end
	if GearRackEngine.PendingCombatRequest==request then GearRackEngine.PendingCombatRequest = nil end
end

-- A manual item choice replaces one deferred slot, not the entire set's work.
-- Remaining pieces can equip, but a superseded set must not claim completion.
function GearRackEngine.OverrideDeferredSlot(slot)
    local owner=GearRackEngine.CombatQueueOwner[slot]
    if owner then
        owner.superseded=true
        if GearRackEngine.PendingCombatRequest==owner then GearRackEngine.PendingCombatRequest=nil end
    end
    GearRackEngine.CombatQueue[slot]=nil
    GearRackEngine.CombatQueueOwner[slot]=nil
end

function GearRackEngine.EquipSet(setname,restoreSetName,context)

	local bag,slot,id,swap,idx,inv,sourceEquipSlot,destEquipSlot
	local saved = GearRackDB.sets[GearRack.user].Sets[setname]
	local definition = context and context.items or saved
	local set = {}
	local hasINVTOBAG, hasINVTOINV, hasBAGTOINV
	local missing = "GearRack could not find: "
	local invStart,invEnd = 1,19 -- changes to 16,18 if in combat

	if not definition then
		DEFAULT_CHAT_FRAME:AddMessage("GearRack: Set \""..setname.."\" doesn't exist.")
		return
	end

	-- A saved copy that is no longer carried or worn gives way to any copy of the item.
	for i=0,19 do
		local item = definition[i]
		if item then
			local guid = item.guid
			if guid and not GearRackEngine.HasInstance(guid) then guid = nil end
			set[i] = { id=item.id, name=item.name, guid=guid }
		end
	end
	set.showhelm,set.showcloak = definition.showhelm,definition.showcloak
	-- Accept a set once, when requested. A later item click must survive even
	-- if this set waits behind another transaction before it begins.
	context = context or {items=set}
	if not context.intent and not context.accepted and not string.find(setname,"^GearRackEngine-CombatQueue") then
		context.accepted=true
		context.definitionOwner=capture_saved_definition(setname)
		if context.undoOf then context.undoMetadataOwner=capture_saved_definition(context.undoOf) end
		if restoreSetName then context.restoreDefinitionOwner=capture_saved_definition(restoreSetName) end
		for slot in pairs(set) do
			if type(slot)=="number" then
				GearRack.Requests[slot]=nil
				if GearRack.initialized then GearRack.KeepManualTrinket(slot) end
			end
		end
		if GearRack.initialized then GearRack.UpdateQueuePresentation() end
	end
	-- A repeated click is still a new explicit choice for the set's slots.
	-- Reuse an unchanged active owner only when no later set must run first.
	local active=GearRackEngine.SwapRequest
	if GearRackEngine.SetSwapping==setname and active and not active.superseded and not active.cancelled and not active.missing
		and active.restoreSetName==restoreSetName and owns_saved_definition(setname,active.definitionOwner) then
		local waitingSet
		for _,queuedIndex in ipairs(GearRackEngine.SwapQueueOrder) do
			if GearRackEngine.SwapQueue[queuedIndex].direction=="NEWSET" then waitingSet=true;break end
		end
		if not waitingSet then GearRackEngine.OnItemLockChanged();return end
	end
	if GearRackEngine.SwapRequest or GearRackEngine.BankTransfer then
		-- come back later, an EquipSet is in progress
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "NEWSET"
		GearRackEngine.SwapQueue[idx].setname = setname
		GearRackEngine.SwapQueue[idx].restoreSetName = restoreSetName
		GearRackEngine.SwapQueue[idx].context = context or {items=set}
		return
	end

	GearRackEngine.ClearLockList()
	-- Temporary weapon requirements belong to this request, not to the saved set.
	local implicit = {}
	local mainType
	if set[16] and set[16].id~=0 and (set[16].id or set[16].name) then
		inv,bag,slot = GearRackEngine.FindSetItem(set[16])
		if inv or bag then _,_,_,mainType = GearRackEngine.GetItemInfo(inv or bag,slot) end
	end
	if mainType=="INVTYPE_2HWEAPON" then
		implicit[17] = not set[17] or set[17].id~=0
		set[17] = { id=0 }
	elseif set[17] and set[17].id~=0 and (set[17].id or set[17].name) and not (set[16] and (set[16].id or set[16].name)) then
		local _,_,_,wornType = GearRackEngine.GetItemInfo(16)
		if wornType=="INVTYPE_2HWEAPON" then
			implicit[16] = true
			set[16] = { id=0 }
		end
	end
	local request = { setname=setname, restoreSetName=restoreSetName, items=set, deferred={} }
	if context then
		request.undoOf,request.sourceUndoToken = context.undoOf,context.sourceUndoToken
		request.completionOf = context.completionOf
		request.intent,request.persistent = context.intent,context.persistent
		request.definitionOwner=context.definitionOwner
		request.undoMetadataOwner=context.undoMetadataOwner
		request.restoreDefinitionOwner=context.restoreDefinitionOwner
	end
	local _,_,_,wornMainType = GearRackEngine.GetItemInfo(16)
	request.offhandAfterMain = wornMainType=="INVTYPE_2HWEAPON" and set[16] and set[16].id~=0 and set[17] and set[17].id~=0
	local deferredOwner=GearRackEngine.PendingCombatRequest
	if deferredOwner and deferredOwner.setname==setname and not deferredOwner.superseded and not deferredOwner.cancelled
		and owns_saved_definition(setname,deferredOwner.definitionOwner) and GearRackEngine.IsSetEquipped(setname) then
		return -- repeated requests must not toggle off already-deferred equipment
	end
	if setname~="GearRackEngine-CombatQueue" and not request.intent then
		GearRackEngine.CancelDeferredRequest(GearRackEngine.PendingCombatRequest)
	end
	if not GearRackEngine.AnyLocked() and not CursorHasItem() and GearRackEngine.CompleteSwapRequest(request) then
		GearRackEngine.StartTimer("InvUpdate")
		return
	end
	GearRackEngine.SwapRequest = request
	GearRackEngine.SetSwapping = setname
	request.undo,request.undoGUIDs,request.implicitUndo,request.undoToken = {},{},{},{}
	request.previousSetName = GearRackDB.sets[GearRack.user].CurrentSet

	-- pre-scan for items that don't need to move
	for i=0,19 do
		_,id = GearRackEngine.GetItemInfo(i)

		if set[i] and (set[i].id or set[i].name) then
			GearRackEngine.FindSetItem(set[i])
			if saved and saved[i] and not saved[i].id and not implicit[i]
				and not request.undoOf and setname~="GearRackEngine-CombatQueue"
				and owns_saved_definition(setname,request.definitionOwner) then
				saved[i].id=set[i].id
				request.definitionOwner.items[i].id=set[i].id
			end
			if GearRackEngine.SlotMatches(i,set[i]) then
				GearRackEngine.LockList[-2][i] = 1
			else
				if implicit[i] then
					request.implicitUndo[i] = id
				else
					request.undo[i] = id
					request.undoGUIDs[i] = i>0 and GearRack.EquippedGUID(i) or nil
				end
			end
		end
		GearRackEngine.ClearSwapListEntry(i)
	end

	if UnitAffectingCombat("player") then -- player is in combat
		for i=1,19 do
			if set[i] and set[i].id and not GearRackEngine.SlotInfo[i].swappable then
				GearRackEngine.AddToCombatQueue(i,set[i].id,request)
				request.deferred[i] = true
			end
		end
		invStart,invEnd = 16,18 -- restrict swap to weapons only
	elseif GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead() then -- wait for world entry or resurrection
		for i=0,19 do
			if set[i] and set[i].id then
				GearRackEngine.AddToCombatQueue(i,set[i].id,request)
				request.deferred[i] = true
			end
		end
		GearRackEngine.PendingCombatRequest = request
		GearRackEngine.SwapRequest = nil
		GearRackEngine.SetSwapping = nil
		GearRackEngine.ClearLockList()
		return
	end

	-- determine what needs swapped and populate GearRackEngine.SwapList
	-- skipping ammo slot the black sheep of inventory slots
	for i=invStart,invEnd do
		if set[i] and set[i].id then
			_,id = GearRackEngine.GetItemInfo(i)
			if not GearRackEngine.SlotMatches(i,set[i]) then
				swap = GearRackEngine.SwapList[i]
				swap.needsSwap = 1
				swap.desiredName = GearRackEngine.GetNameByID(set[i].id)
				if set[i].id==0 then -- empty slot
					swap.direction="INVTOBAG"
					swap.needsEmptied = 1
					hasINVTOBAG = 1
				else
					inv,bag,slot = GearRackEngine.FindSetItem(set[i])
					if inv then -- found it in another inventory slot
						_,set[i].id = GearRackEngine.GetItemInfo(inv)
						GearRackEngine.LockList[-2][inv] = 1
						_,_,_,sourceEquipSlot = GearRackEngine.GetItemInfo(inv)
						_,_,_,destEquipSlot = GearRackEngine.GetItemInfo(i)
						swap.direction="INVTOINV" -- if the item can exist in both slots
						swap.sourceInv = inv
						hasINVTOINV = 1
						if destEquipSlot and sourceEquipSlot and not (GearRackEngine.SlotInfo[i][sourceEquipSlot] and GearRackEngine.SlotInfo[inv][destEquipSlot]) then
							swap.needsEmptied = 1
							hasINVTOBAG = 1
						end
					elseif bag and slot then -- found it in a bag slot
						_,set[i].id = GearRackEngine.GetItemInfo(bag,slot)
						GearRackEngine.LockList[bag][slot] = 1
						swap.direction="BAGTOINV"
						swap.sourceBag = bag
						swap.sourceSlot = slot
						hasBAGTOINV = 1
					else -- couldn't find it
						missing = missing..tostring(swap.desiredName)..", "
						request.missing = true
						swap.needsSwap = nil
					end
				end
			end
		elseif set[i] and set[i].name then -- item has no id yet, not seen since conversion
			missing = missing..tostring(set[i].name)..", "
			request.missing = true
		end
	end

	if missing~="GearRack could not find: " then
		DEFAULT_CHAT_FRAME:AddMessage(string.gsub(missing,", $",""))
	end

	-- at this stage, GearRackEngine.SwapList[0]-[19] is populated

	-- INVTOBAG and .needsEmptied swaps first
	if hasINVTOBAG then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "INVTOBAG"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].needsEmptied then
				GearRackEngine.SwapQueue[idx][i].id = 0
			end
		end
	end

	-- INVTOINV swaps next
	if hasINVTOINV then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "INVTOINV"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].direction=="INVTOINV" and not (i==17 and request.offhandAfterMain) then
				GearRackEngine.SwapQueue[idx][i].id = set[i].id
				GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
				GearRackEngine.SwapQueue[idx][i].fromSlot = GearRackEngine.SwapList[i].sourceInv
			end
		end
	end

	-- BAGTOINV swaps last (90% of swaps this is only bit that queues)
	if hasBAGTOINV then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = "BAGTOINV"
		GearRackEngine.SwapQueue[idx].setname = setname
		for i=0,19 do
			if GearRackEngine.SwapList[i].direction=="BAGTOINV" and not (i==17 and request.offhandAfterMain) then
				GearRackEngine.SwapQueue[idx][i].id = set[i].id
				GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
				GearRackEngine.SwapQueue[idx][i].fromBag = GearRackEngine.SwapList[i].sourceBag
				GearRackEngine.SwapQueue[idx][i].fromSlot = GearRackEngine.SwapList[i].sourceSlot
			end
		end
	end

	-- Observe the replacement main hand before attempting an offhand equip.
	if request.offhandAfterMain and GearRackEngine.SwapList[17].direction then
		idx = GearRackEngine.GetFreeQueueEntry()
		GearRackEngine.AddQueueEntry(idx)
		GearRackEngine.SwapQueue[idx].direction = GearRackEngine.SwapList[17].direction
		GearRackEngine.SwapQueue[idx].setname = setname
		GearRackEngine.SwapQueue[idx][17].id = set[17].id
		GearRackEngine.SwapQueue[idx][17].guid = set[17].guid
		GearRackEngine.SwapQueue[idx][17].fromBag = GearRackEngine.SwapList[17].sourceBag
		GearRackEngine.SwapQueue[idx][17].fromSlot = GearRackEngine.SwapList[17].sourceSlot or GearRackEngine.SwapList[17].sourceInv
	end

	-- Ammo participates in completion even when it is the only requested change.
	bag,slot = nil,nil
	if set[0] and (set[0].id or set[0].name) then
		_,id = GearRackEngine.GetItemInfo(0)
		if id~=set[0].id then
			if set[0].id~=0 then
				_,bag,slot = GearRackEngine.FindSetItem(set[0])
				if bag then _,set[0].id = GearRackEngine.GetItemInfo(bag,slot) end
			end
			if set[0].id==0 or bag then
				idx = GearRackEngine.GetFreeQueueEntry()
				GearRackEngine.AddQueueEntry(idx)
				GearRackEngine.SwapQueue[idx].direction = set[0].id==0 and "INVTOBAG" or "BAGTOINV"
				GearRackEngine.SwapQueue[idx].setname = setname
				GearRackEngine.SwapQueue[idx][0].id = set[0].id
				GearRackEngine.SwapQueue[idx][0].guid = set[0].guid
				GearRackEngine.SwapQueue[idx][0].fromBag = bag
				GearRackEngine.SwapQueue[idx][0].fromSlot = slot
			else
				request.missing = true
			end
		end
	end

	-- Final verification also covers unchanged slots and missing items.
	idx = GearRackEngine.GetFreeQueueEntry()
	GearRackEngine.AddQueueEntry(idx)
	GearRackEngine.SwapQueue[idx].direction = "VERIFY"
	GearRackEngine.SwapQueue[idx].setname = setname
	for i=0,19 do
		if set[i] and not request.deferred[i] then
			GearRackEngine.SwapQueue[idx][i].id = set[i].id
			GearRackEngine.SwapQueue[idx][i].guid = set[i].guid
		end
	end

	if set.showhelm then
		ShowHelm(set.showhelm)
	end
	if set.showcloak then
		ShowCloak(set.showcloak)
	end

	-- Both views reflect deferred set choices through the same presentation.
	if GearRack.initialized then GearRack.UpdateQueuePresentation() end
	-- at last, perform the swaps by iterating over the queue
	GearRackEngine.IterateSwapQueue()

end

-- A real death pauses the active native owner, including its bounded deadline.
-- Record the pause on PLAYER_DEAD and also guard direct lock/inventory calls;
-- resurrection resumes the same request without counting time spent dead.
function GearRackEngine.ReconcileDeathPause()
	local request=GearRackEngine.SwapRequest
	if not request then return end
	if GearRackEngine.IsPlayerReallyDead() then
		request.deathPausedAt=request.deathPausedAt or GetTime()
		if GearRackEngine.TimerEnabled("WaitToIterate") then GearRackEngine.StopTimer("WaitToIterate") end
		return true
	elseif request.deathPausedAt then
		local elapsed=math.max(0,GetTime()-request.deathPausedAt)
		for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
			local queue=GearRackEngine.SwapQueue[idx]
			if queue.deadline then queue.deadline=queue.deadline+elapsed end
		end
		request.deathPausedAt=nil
	end
end

-- Reconcile once a second while a stage is active, including missed lock events.
function GearRackEngine.IterateWait()
	GearRackEngine.IterateSwapQueue()
end

-- A queued slot names an item, not a permanent bag/equipment position. Check
-- its planned source first, then follow that exact variant/GUID if it moved.
local function resolve_swap_source(wanted,direction)
	local inv,bag,slot
	if direction=="INVTOINV" then inv=wanted.fromSlot
	else bag,slot=wanted.fromBag,wanted.fromSlot end
	local location=inv and {equipmentSlotIndex=inv} or {bagID=bag,slotIndex=slot}
	local _,id=GearRackEngine.GetItemInfo(inv or bag,slot)
	if id~=wanted.id or (wanted.guid and C_Item.GetItemGUID(location)~=wanted.guid) then
		inv,bag,slot=GearRackEngine.FindSetItem(wanted)
		if not inv and not bag then return end
		location=inv and {equipmentSlotIndex=inv} or {bagID=bag,slotIndex=slot}
		_,id=GearRackEngine.GetItemInfo(inv or bag,slot)
	end
	if id~=wanted.id or (wanted.guid and C_Item.GetItemGUID(location)~=wanted.guid) then return end
	if inv then GearRackEngine.LockList[-2][inv]=1
	else GearRackEngine.LockList[bag][slot]=1 end
	return location,inv,bag,slot
end

function GearRackEngine.ShutdownQueue(reason)
	local finished=GearRackEngine.SwapRequest
	local waitingSets={}
	for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
		if GearRackEngine.SwapQueue[idx].direction=="NEWSET" then
			local queued=GearRackEngine.SwapQueue[idx]
			table.insert(waitingSets,{direction="NEWSET",setname=queued.setname,
				restoreSetName=queued.restoreSetName,context=queued.context})
		end
	end
	if reason then DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..reason) end
	if GearRackEngine.SwapRequest then
		GearRackEngine.CancelDeferredRequest(GearRackEngine.SwapRequest.completionOf)
		GearRackEngine.CancelDeferredRequest(GearRackEngine.SwapRequest)
	end
	GearRackEngine.SwapRequest = nil
	GearRackEngine.SwapIssuing = nil
	GearRackEngineFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.SetSwapping = nil
	GearRackEngine.StopTimer("WaitToIterate")
	while #GearRackEngine.SwapQueueOrder>0 do
		GearRackEngine.RemoveQueueEntry(GearRackEngine.SwapQueueOrder[#GearRackEngine.SwapQueueOrder])
	end
	GearRackEngine.ClearLockList()
	for i=0,19 do GearRackEngine.ClearSwapListEntry(i) end
	GearRack.TransactionFinished(finished,reason)
	if GearRackTrinkets and GearRackTrinkets.UpdateWornTrinkets then GearRackTrinkets.UpdateWornTrinkets() end
	for _,queued in ipairs(waitingSets) do
		local idx=GearRackEngine.GetFreeQueueEntry()
		local entry=GearRackEngine.SwapQueue[idx]
		entry.direction,entry.setname="NEWSET",queued.setname
		entry.restoreSetName,entry.context=queued.restoreSetName,queued.context
		GearRackEngine.AddQueueEntry(idx)
	end
	if #waitingSets>0 then GearRackEngine.IterateSwapQueue() end
end

-- this function grabs the next swap QueueEntry and performs the swap
-- swaps only happen one direction at a time: INVTOBAG->INVTOINV->BAGTOINV
-- complex swaps can require running this a few times
function GearRackEngine.IterateSwapQueue()
	if GearRackEngine.SwapIssuing or GearRackEngine.BankTransfer or GearRack.worldSuspended then return end
	if GearRackEngine.ReconcileDeathPause() then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.cancelled then
		GearRackEngine.ShutdownQueue()
		return
	end
	if #GearRackEngine.SwapQueueOrder<1 then
		GearRackEngine.ShutdownQueue()
		if next(GearRackEngine.CombatQueue) and not GearRackEngine.IsPlayerReallyDead() and not UnitAffectingCombat("player") then
			GearRackEngine.OnEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end

	GearRackEngine.SortQueue()
	local idx = GearRackEngine.SwapQueueOrder[1]
	local queue = GearRackEngine.SwapQueue[idx]
	if queue.direction=="NEWSET" then
		local setname,restoreSetName,context = queue.setname,queue.restoreSetName,queue.context
		GearRackEngine.RemoveQueueEntry(idx)
		GearRackEngine.EquipSet(setname,restoreSetName,context)
		-- An already-equipped or deleted set need not produce any stages.
		if not GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue() end
		return
	end

	-- Combat may begin after a saved set was planned but before a stage starts.
	-- Defer its armor through the existing owner instead of submitting a native
	-- move that combat restrictions will reject. Already-issued stages must
	-- retain their native reconciliation/timeout ownership.
	local request=GearRackEngine.SwapRequest
	if request and not request.persistent and not queue.started and UnitAffectingCombat("player") then
		for slot=0,19 do
			local wanted=request.items[slot]
			if wanted and wanted.id and not request.deferred[slot] and not GearRackEngine.SlotInfo[slot].swappable
				and not GearRackEngine.SlotMatches(slot,wanted) then
				GearRackEngine.AddToCombatQueue(slot,wanted.id,request)
				request.deferred[slot]=true
				for _,pendingIdx in ipairs(GearRackEngine.SwapQueueOrder) do
					local pending=GearRackEngine.SwapQueue[pendingIdx]
					if pending.direction~="NEWSET" then pending[slot].id=nil;pending[slot].guid=nil end
				end
			end
		end
	end

	local persistent=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent
	queue.deadline = queue.deadline or (GetTime()+10)
	if queue.started then
		GearRackEngine.OnItemLockChanged()
		return
	end
	if not persistent and GetTime()>=queue.deadline then
		GearRackEngine.ShutdownQueue("Swap timed out before it could start.")
		return
	end
	GearRackEngine.StartTimer("WaitToIterate",persistent and .2 or 1)
    local intent=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.intent
    if intent and GearRack.Requests[intent.slot]~=intent then GearRackEngine.ShutdownQueue();return end
	if GearRackEngine.IsPlayerReallyDead() then
        if persistent then GearRackEngine.StopTimer("WaitToIterate") end
        return
    end
	-- Stages with armor wait for casts and the global cooldown; weapon-only
	-- stages go at once (see GearRack.GetEquipDelay). Ordinary set requests
	-- still expire at their stage deadline.
	local weaponsOnly=true
	for slot=0,19 do
		if queue[slot].id and not GearRackEngine.SlotInfo[slot].swappable then weaponsOnly=false;break end
	end
	local delay=GearRack.GetEquipDelay(weaponsOnly)
	if delay>0 then
		if not persistent then delay=math.min(delay,queue.deadline-GetTime()) end
		GearRackEngine.StartTimer("WaitToIterate",delay)
		return
	end
	if SpellIsTargeting() or GetCursorInfo() or GearRackEngine.AnyLocked() then return end
    if persistent and UnitAffectingCombat("player") then
        for slot=0,19 do
            if queue[slot].id and not GearRackEngine.SlotInfo[slot].swappable then GearRackEngine.ShutdownQueue();return end
        end
    end

	GearRackEngineFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.SetSwapping = queue.setname
	queue.started = true
	queue.lastAttempt=GetTime()
	GearRackEngine.SwapIssuing = true -- lock events can arrive inside an equip or pickup call
	GearRackEngine.ClearLockList()
	local moved = {}
	for i=0,19 do
		local wanted = queue[i]
		local _,worn = GearRackEngine.GetItemInfo(i)
		if wanted.id and not GearRackEngine.SlotMatches(i,wanted) and not moved[i] and queue.direction~="VERIFY" then
			if SpellIsTargeting() or GetCursorInfo() then
				GearRackEngine.ShutdownQueue("A cursor action interrupted the swap.")
				return
			end
			local bag,slot,id,usedCursor
			if queue.direction=="INVTOBAG" then
				usedCursor = true
				bag,slot = GearRackEngine.FindSpace()
				if not bag then
                    if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.intent then
                        GearRackEngine.SwapRequest.intent.waitForSpace=GearRack.inventoryRevision
                    end
					GearRackEngine.NoMoreRoom()
					GearRackEngine.ShutdownQueue()
					return
				end
				PickupInventoryItem(i)
				PickupContainerItem(bag,slot)
			elseif queue.direction=="INVTOINV" or queue.direction=="BAGTOINV" then
				local location,sourceInv
				location,sourceInv,bag,slot=resolve_swap_source(wanted,queue.direction)
				if not location then
					GearRackEngine.ShutdownQueue("A requested item is no longer available.")
					return
				end
				if i==17 then
					local _,_,_,mainType = GearRackEngine.GetItemInfo(16)
					if mainType=="INVTYPE_2HWEAPON" then
						GearRackEngine.ShutdownQueue("The main-hand prerequisite did not complete.")
						return
					end
				end
				if i==0 or sourceInv==0 then -- ammo is outside ClassicAPI's destination range 1..19
					usedCursor = true
					if sourceInv then PickupInventoryItem(sourceInv)
					else PickupContainerItem(bag,slot) end
					PickupInventoryItem(i)
				else
					C_Item.EquipItemByName(location,i)
				end
				if sourceInv and queue[sourceInv].fromSlot==i then moved[sourceInv]=true end
			end
			if usedCursor and CursorHasItem() then
				ClearCursor() -- return only an item left by our own pickup pair
				GearRackEngine.ShutdownQueue("An item move could not complete.")
				return
			end
		end
	end
	GearRackEngine.SwapIssuing = nil
	GearRackEngine.OnItemLockChanged()
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent then GearRackEngine.StartTimer("WaitToIterate",.2) end
end

--[[ Locks ]]--

-- returns true if anything is locked
function GearRackEngine.AnyLocked()
	for i=0,19 do
		if IsInventoryItemLocked(i) then return true end
	end
	-- Only occupied slots can be locked: read the cached ones, and every slot
	-- of a bag that changed since the cache was built.
	for bag=0,4 do
		if GearRack.DirtyBags[bag] or not GearRack.Bags[bag] then
			for slot=1,GetContainerNumSlots(bag) do
				local _,_,locked = GetContainerItemInfo(bag,slot)
				if locked then return true end
			end
		else
			for _,entry in ipairs(GearRack.Bags[bag]) do
				local _,_,locked = GetContainerItemInfo(bag,entry.slot)
				if locked then return true end
			end
		end
	end
end

-- Wait before re-issuing a swap the server may not have answered yet. A repeat
-- sent before the first answer lands swaps the items back. 0.3 s on a normal
-- connection; twice the latency plus a margin when that is longer, capped at 3 s.
-- GetNetStats' third value is the latency in ms (the client's MainMenuBar.xml).
function GearRackEngine.RetryGap()
	local _,_,latency = GetNetStats()
	local gap = 2*(latency or 0)/1000 + .1
	return gap < .3 and .3 or (gap > 3 and 3 or gap)
end

-- when an iteration begins, on each ITEM_LOCK_CHANGED check if the swaps are done
-- if so, remove the current queue entry and go to the next one
-- this is where swaps end
function GearRackEngine.OnItemLockChanged()
	if GearRackEngine.SwapIssuing or GearRack.worldSuspended then return end
	if GearRackEngine.ReconcileDeathPause() then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.cancelled then
		GearRackEngine.ShutdownQueue()
		return
	end
	local idx = GearRackEngine.SwapQueueOrder[1]
	if not idx then return end
	local queue = GearRackEngine.SwapQueue[idx]
	if not queue.started then return end
	if GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent and GearRackEngine.IsPlayerReallyDead() then
		GearRackEngine.StopTimer("WaitToIterate")
		return
	end

	local locked=GearRackEngine.AnyLocked()
	if not CursorHasItem() and not locked and GearRackEngine.SwapMatches(queue) then
		if queue.direction=="VERIFY" then
			local request = GearRackEngine.SwapRequest
			if request.missing then
				GearRackEngine.ShutdownQueue("The requested set is incomplete.")
				return
			end
			if not GearRackEngine.CompleteSwapRequest(request) then
				if next(request.deferred) then
					if not request.superseded then GearRackEngine.PendingCombatRequest = request end
				elseif not request.superseded then
					GearRackEngine.ShutdownQueue("The requested set is incomplete.")
					return
				end
			end
			GearRack.TransactionFinished(request)
			GearRackEngine.SwapRequest = nil
			GearRackEngine.SetSwapping = nil
			GearRack.WarnUnpoisoned(request)
		end
		GearRackEngine.RemoveQueueEntry(idx)
		GearRackEngine.StopTimer("WaitToIterate")
		GearRackEngine.IterateSwapQueue()
	elseif GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.persistent then
        local intent=GearRackEngine.SwapRequest.intent
        if intent and GearRack.Requests[intent.slot]~=intent then
            if GetTime()-(queue.lastAttempt or 0)>=1 and not locked then GearRackEngine.ShutdownQueue()
            else GearRackEngine.StartTimer("WaitToIterate",.2) end
        elseif UnitAffectingCombat("player") and not GearRackEngine.SlotInfo[intent.slot].swappable
            and GetTime()-(queue.lastAttempt or 0)>=2 and not locked then
            GearRackEngine.ShutdownQueue()
        elseif GearRack.GetEquipDelay(GearRackEngine.SlotInfo[intent.slot].swappable)>0 then
            queue.started=nil
            GearRackEngine.StartTimer("WaitToIterate",GearRack.GetEquipDelay())
        elseif not locked and GetTime()-(queue.lastAttempt or 0)>=GearRackEngine.RetryGap() then
            queue.started=nil
            GearRackEngine.IterateSwapQueue()
        else GearRackEngine.StartTimer("WaitToIterate",.2) end
	elseif GetTime()>=queue.deadline then
		GearRackEngine.ShutdownQueue("Swap timed out before the requested equipment was observed.")
	elseif not locked and not CursorHasItem() and GetTime()-(queue.lastAttempt or 0)>=GearRackEngine.RetryGap() then
		-- In combat the client can refuse one weapon of a pair. Like single
		-- choices, a set re-issues only the slots that do not match yet, every
		-- 0.3 seconds, until the stage's deadline.
		queue.started=nil
		GearRackEngine.IterateSwapQueue()
	else
		GearRackEngine.StartTimer("WaitToIterate",.25)
	end
end

--[[ Combat/Death Queue Processing ]]

function GearRackEngine.IsPlayerReallyDead()
	local dead = UnitIsDeadOrGhost("player")
	if dead and UnitIsFeignDeath("player") then return nil end
	return dead
end

-- adds an item 'id' to 'slot' queue for post-combat/death swap
function GearRackEngine.AddToCombatQueue(slot,id,owner)
	local _,wornId = GearRackEngine.GetItemInfo(slot)
	local wanted=owner and owner.items and owner.items[slot]
	local alreadyWorn=id==wornId and (not wanted or not wanted.guid
		or GearRack.EquippedGUID(slot)==wanted.guid)
	local toggleOff = not owner and GearRackEngine.CombatQueue[slot]==id
	if not owner then GearRackEngine.CancelDeferredRequest(GearRackEngine.CombatQueueOwner[slot]) end
	if toggleOff or alreadyWorn then
		GearRackEngine.CombatQueue[slot] = nil
		GearRackEngine.CombatQueueOwner[slot] = nil
		GearRack.ShowQueueBadge(slot,false)
	elseif id then
		GearRackEngine.CombatQueue[slot] = id
		GearRackEngine.CombatQueueOwner[slot] = owner
		local _,texture = GearRackEngine.GetNameByID(id)
		GearRack.ShowQueueBadge(slot,true,texture)
	end
end

--[[ EquipSet wrappers ]]--

-- returns true if the entire set is currently worn
function GearRackEngine.IsSetEquipped(setname)

	local set,missing,id = GearRackDB.sets[GearRack.user].Sets[setname or ""]

	if set then
		for i=0,19 do
			if set[i] then
				-- if item queued, check queued item instead of GetItemInfo
				if GearRackEngine.CombatQueue[i] then
					id = GearRackEngine.CombatQueue[i]
				else
					_,id = GearRackEngine.GetItemInfo(i)
				end
				if set[i].id ~= id then
					missing = 1
				elseif set[i].guid and not GearRackEngine.CombatQueue[i] and GearRack.EquippedGUID(i)~=set[i].guid
					and GearRackEngine.HasInstance(set[i].guid) then
					missing = 1
				end
			end
		end
	end
	return set and not missing
end

-- equips a set if it's worn, unequips it if not
function GearRackEngine.ToggleSet(setname)

	if GearRackDB.sets[GearRack.user].Sets[setname or ""] then
		if GearRackEngine.IsSetEquipped(setname) then
			GearRackEngine.UnequipSet(setname)
		else
			GearRackEngine.EquipSet(setname)
		end
	end
end

-- This function creates a set of all the items replaced by setname, and then does does an .EquipSet()
function GearRackEngine.UnequipSet(setname)
	local old = GearRackDB.sets[GearRack.user].Sets[setname]
	if not old then return end
	local source = GearRackEngine.SwapRequest
	if not source or source.setname~=setname then source = GearRackEngine.PendingCombatRequest end
	if source and source.setname~=setname then source = nil end
	local historyOwner=GearRackEngine.UndoOwner[setname]
	if not source and historyOwner and not owns_saved_definition(setname,historyOwner) then
		if old==historyOwner.definition then
			for i=0,19 do if old[i] then old[i].old,old[i].oldguid=nil,nil end end
			old.oldsetname=nil
		end
		GearRackEngine.ForgetSetUndo(setname)
		return
	end
	local items = {}
	local implicit = source and source.implicitUndo or GearRackEngine.SwapUndo[setname]
	for i=0,19 do
		local id,guid
		if source then id,guid = source.undo[i],source.undoGUIDs[i]
		elseif old[i] then id,guid = old[i].old,old[i].oldguid end
		if implicit and implicit[i] then id,guid = implicit[i],nil end
		if id then items[i] = { id=id, guid=guid } end
	end
	local restoreSetName = old.oldsetname
	local token = GearRackEngine.UndoToken[setname]
	if source then restoreSetName,token = source.previousSetName,source.undoToken end
	-- Keep undo data available until this exact restore request succeeds.
	GearRackEngine.EquipSet("GearRackEngine-Unequip-"..setname,restoreSetName,
		{items=items,undoOf=setname,sourceUndoToken=token})
end

--[[ Timer maintenance
	ClassicAPI owns delayed callbacks. OnUpdate is reserved for cursor-following
	render work (IconDragging), whose zero period means once each rendered frame.
	Each timer has one callback for life; a repeating timer runs on one ticker,
	so neither a start nor a tick builds a closure. A cancelled handle never fires.
]]

local function fire_timer(clock)
	if not clock.enabled then return end
	if clock.rep then
		-- A first wait of another length runs on a one-shot; the period then ticks.
		if not clock.ticking then
			clock.ticking = true
			clock.handle = C_Timer.NewTicker(clock.limit,clock.fire)
		end
		clock.deadline = GetTime()+clock.limit
	else
		clock.handle, clock.deadline, clock.enabled = nil, nil, nil
	end
	-- An error goes to the error handler with its stack, and the timer stops,
	-- so a broken repeating callback reports once.
	local generation = clock.generation
	if not xpcall(clock.func,geterrorhandler()) and clock.generation==generation then
		GearRackEngine.StopTimer(clock.name)
	end
end

function GearRackEngine.CreateTimer(name,func,limit,rep)
	local clock = {name=name,func=func,limit=limit,rep=rep,generation=0}
	clock.fire = function() fire_timer(clock) end
	GearRackEngine.TimerPool[name] = clock
end

function GearRackEngine.StartTimer(name,delay,keepEarlier)
	local clock = GearRackEngine.TimerPool[name]
	delay = delay or clock.limit
	local deadline=GetTime()+delay
	if keepEarlier and clock.enabled and clock.handle and clock.deadline and clock.deadline<=deadline then return end
	GearRackEngine.StopTimer(name)
	clock.enabled = 1
	if clock.limit==0 and clock.rep then
		GearRackEngineFrame:Show()
		return
	end
	clock.deadline = deadline
	if clock.rep and delay==clock.limit then
		clock.ticking = true
		clock.handle = C_Timer.NewTicker(delay,clock.fire)
	else
		clock.handle = C_Timer.NewTimer(delay,clock.fire)
	end
end

function GearRackEngine.StopTimer(name)
	local clock = GearRackEngine.TimerPool[name]
	if not clock then return end
	clock.generation = clock.generation+1
	if clock.handle then clock.handle:Cancel(); clock.handle = nil end
	clock.deadline, clock.enabled, clock.ticking = nil, nil, nil
	GearRackEngine.ClearStoppedTimers()
end

function GearRackEngine.ClearStoppedTimers()
	for name,clock in pairs(GearRackEngine.TimerPool) do
		if clock.enabled and clock.limit==0 and clock.rep then return end
	end
	GearRackEngineFrame:Hide()
end

function GearRackEngine.TimerEnabled(name)
	return GearRackEngine.TimerPool[name] and GearRackEngine.TimerPool[name].enabled
end

function GearRackEngine.OnUpdate()
	for name,clock in pairs(GearRackEngine.TimerPool) do
		if clock.enabled and clock.limit==0 and clock.rep then clock.func() end
	end
end

--[[ Bank support ]]

function GearRackEngine.PopulateBank()
	if not GearRackUI.BankIsOpen then return end
	GearRackEngine.UnpopulateBank()
	local itemID,equipLoc,rawID
	for i=1,#GearRackUI.BankSlots do
		local bag=GearRackUI.BankSlots[i]
		local count=GetContainerNumSlots(bag)
		if bag>=5 and count>0 then
			local bagID=GetInventoryItemID("player",BankButtonIDToInvSlotID(bag,1))
			if bagID then GearRackUI.BankItemIDs[bagID]=true end
		end
		for j=1,count do
			_,itemID,_,equipLoc,_,rawID = GearRackEngine.GetItemInfo(bag,j)
			local baseID=rawID or GearRack.BaseID(itemID)
			if baseID then GearRackUI.BankItemIDs[baseID]=true end
			if itemID then
				if equipLoc and equipLoc~="" then
					GearRackUI.BankedItems[itemID] = 1
				end
			end
		end
	end
end

function GearRackEngine.UnpopulateBank()
	table.wipe(GearRackUI.BankedItems)
	table.wipe(GearRackUI.BankItemIDs)
end

function GearRackEngine.BankOpened()
	GearRackUI.BankIsOpen = 1
	GearRackEngine.PopulateBank()
end

function GearRackEngine.BankClosed()
	GearRackUI.BankIsOpen = nil
	GearRackEngine.StopTimer("BankScan")
	GearRackEngine.CancelBankTransfer()
	GearRackUI_MenuFrame:Hide()
	GearRackEngine.UnpopulateBank()
end

function GearRackEngine.SetHasBanked(setname)
	if not setname or not GearRackDB.sets[GearRack.user].Sets[setname] then return end
	local item
	for i=0,19 do
		item = GearRackDB.sets[GearRack.user].Sets[setname][i]
		if item and item.name and GearRackUI.BankedItems[item.id] then
			return 1
		end
	end
end

-- Returns comma-separated list of sets containing the specified item (by link, ID, or name)
function GearRackEngine.GetSetsWithItem(itemIdentifier)
	if not GearRack.user or not GearRackDB.sets or not GearRackDB.sets[GearRack.user] or not GearRackDB.sets[GearRack.user].Sets then return nil end
	if not itemIdentifier then return nil end

	local targetID, targetName
	if type(itemIdentifier) == "number" then
		targetID = tostring(itemIdentifier)
	elseif type(itemIdentifier) == "string" then
		local _, _, linkID = string.find(itemIdentifier, "item:(%d+)")
		if linkID then
			targetID = linkID
		elseif string.find(itemIdentifier, "^%d+$") then
			targetID = itemIdentifier
		else
			targetName = itemIdentifier
		end
	end

	local matchingSets
	for setName, setData in pairs(GearRackDB.sets[GearRack.user].Sets) do
		if not string.find(setName, "^GearRackUI") and not string.find(setName, "^GearRackEngine-") then
			for slot = 0, 19 do
				local slotData = setData[slot]
				if slotData and slotData.id and slotData.id ~= 0 then
					local matched = false
					if targetID then
						local _, _, slotBaseID = string.find(tostring(slotData.id), "(%d+)")
						if slotBaseID == targetID or tostring(slotData.id) == targetID then
							matched = true
						end
					elseif targetName and slotData.name and slotData.name == targetName then
						matched = true
					end

					if matched then
						matchingSets = matchingSets and (matchingSets .. ", " .. setName) or setName
						break
					end
				end
			end
		end
	end
	return matchingSets
end

function GearRackEngine.FindBankedItem(itemID,itemGUID)
	for _,i in ipairs(GearRackUI.BankSlots) do
		for j=1,GetContainerNumSlots(i) do
			local _, currentID = GearRackEngine.GetItemInfo(i,j)
			if itemID and currentID == itemID and not GearRackEngine.LockList[i][j]
				and (not itemGUID or GearRack.BagGUID(i,j)==itemGUID) then
				return i,j
			end
		end
	end
end

local function bank_item_identity(location)
	local _,id=GearRackEngine.GetItemInfo(location.equipmentSlotIndex or location.bagID,location.slotIndex)
	return id~=0 and id or nil,C_Item.GetItemGUID(location)
end

local function bank_location_locked(location)
	return C_Item.IsLocked(location)
end

-- A native bank send is asynchronous. Own its reservations until the exact
-- destination and emptied source are observed, or a bounded uncertain failure.
function GearRackEngine.BeginBankTransfer()
	if not GearRackUI.BankIsOpen or GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead()
		or GearRackEngine.IsEquipmentSwapActive() or SpellIsTargeting() or GetCursorInfo() then return end
	GearRackEngine.ClearLockList()
	GearRackEngine.BankTransfer={moves={},deadline=GetTime()+5,issuing=true}
	GearRackEngineFrame:RegisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.StartTimer("BankTransferCheck")
	return true
end

function GearRackEngine.CancelBankTransfer(reason)
	local transfer=GearRackEngine.BankTransfer
	if not transfer then return end
	GearRackEngine.BankTransfer=nil
	GearRackEngine.StopTimer("BankTransferCheck")
	GearRackEngineFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
	GearRackEngine.ClearLockList()
	for _,move in ipairs(transfer.moves) do
		for _,location in ipairs({move.source,move.destination}) do
			if location.bagID and location.bagID>=0 and location.bagID<=4 then GearRack.InvalidateBag(location.bagID) end
		end
	end
	if reason then DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..reason) end
	GearRack.Wake()
	if #GearRackEngine.SwapQueueOrder>0 then GearRackEngine.IterateSwapQueue() end
end

function GearRackEngine.ReconcileBankTransfer()
	local transfer=GearRackEngine.BankTransfer
	if not transfer then return end
	if not GearRackUI.BankIsOpen or GearRack.worldSuspended or GearRackEngine.IsPlayerReallyDead() then
		GearRackEngine.CancelBankTransfer()
		return
	end
	if GetTime()>=transfer.deadline then
		GearRackEngine.CancelBankTransfer("Bank transfer could not be confirmed. Check your bags before trying again.")
		return
	end
	if not transfer.issuing then
		local pending=false
		for _,move in ipairs(transfer.moves) do
			local destID,destGUID=bank_item_identity(move.destination)
			if C_Item.DoesItemExist(move.source) or destID~=move.id or (move.guid and destGUID~=move.guid)
				or bank_location_locked(move.source) or bank_location_locked(move.destination) then pending=true;break end
		end
		if not pending then GearRackEngine.CancelBankTransfer();return end
	end
	GearRackEngine.StartTimer("BankTransferCheck",.2)
end

function GearRackEngine.SendBankItem(source,destination,expectedID,expectedGUID)
	local transfer=GearRackEngine.BankTransfer
	if not transfer or not transfer.issuing or not GearRackUI.BankIsOpen
		or GearRack.worldSuspended or SpellIsTargeting() or GetCursorInfo() then return end
	local id,guid=bank_item_identity(source)
	if not id or id~=expectedID or (expectedGUID and guid~=expectedGUID) or C_Item.DoesItemExist(destination)
		or bank_location_locked(source) or bank_location_locked(destination) then return end
	local accepted
	if source.equipmentSlotIndex then
		GearRackEngine.LockList[-2][source.equipmentSlotIndex]=1
		PickupInventoryItem(source.equipmentSlotIndex)
		PickupContainerItem(destination.bagID,destination.slotIndex)
		if CursorHasItem() then ClearCursor();return end
		accepted=true
	else
		GearRackEngine.LockList[source.bagID][source.slotIndex]=1
		accepted=C_Container.SwapItems(source.bagID,source.slotIndex,destination.bagID,destination.slotIndex)
	end
	if accepted then table.insert(transfer.moves,{source=source,destination=destination,id=id,guid=guid}) end
	return accepted
end

function GearRackEngine.EndBankTransfer()
	if GearRackEngine.BankTransfer then
		GearRackEngine.BankTransfer.issuing=nil
		GearRackEngine.ReconcileBankTransfer()
	end
end

function GearRackEngine.PullSetFromBank(setname)
	local set = GearRackDB.sets[GearRack.user].Sets[setname]
	if not set or not GearRackEngine.BeginBankTransfer() then return end
	local bag,slot,freeBag,freeSlot
	for i=0,19 do
		if not GearRackUI.BankIsOpen or SpellIsTargeting() or GetCursorInfo() then break end
		if set[i] then
			if GearRackUI.BankedItems[set[i].id] then
				bag,slot = GearRackEngine.FindBankedItem(set[i].id,set[i].guid)
				if not bag and set[i].guid then bag,slot = GearRackEngine.FindBankedItem(set[i].id) end
				if bag then
					freeBag,freeSlot = GearRackEngine.FindSpace()
					if freeBag then
						if not GearRackEngine.SendBankItem({bagID=bag,slotIndex=slot},
							{bagID=freeBag,slotIndex=freeSlot},set[i].id,GearRack.BagGUID(bag,slot)) then break end
					else
						GearRackEngine.NoMoreRoom()
						break
					end
				end
			end
		end
	end
	GearRackEngine.EndBankTransfer()
end

function GearRackEngine.PushSetToBank(setname)
	local set = GearRackDB.sets[GearRack.user].Sets[setname]
	if not set or not GearRackEngine.BeginBankTransfer() then return end
	local inv,bag,slot,freeBag,freeSlot
	for i=0,19 do
		if not GearRackUI.BankIsOpen or SpellIsTargeting() or GetCursorInfo() then break end
		if set[i] and set[i].id ~= 0 then
			freeBag,freeSlot = GearRackEngine.FindSpace(1)
			if freeBag then
				inv,bag,slot = GearRackEngine.FindSetItem(set[i])
				local _, currentID
				if inv then _, currentID = GearRackEngine.GetItemInfo(inv)
				elseif bag then _, currentID = GearRackEngine.GetItemInfo(bag,slot) end
				if set[i].id and currentID ~= set[i].id then break end
				if inv then
					if not GearRackEngine.SendBankItem({equipmentSlotIndex=inv},
						{bagID=freeBag,slotIndex=freeSlot},set[i].id,GearRack.EquippedGUID(inv)) then break end
				elseif bag then
					if not GearRackEngine.SendBankItem({bagID=bag,slotIndex=slot},
						{bagID=freeBag,slotIndex=freeSlot},set[i].id,GearRack.BagGUID(bag,slot)) then break end
				end
			else
				GearRackEngine.NoMoreRoom()
				break
			end
		end
	end
	GearRackEngine.EndBankTransfer()
end

function GearRackEngine.NoMoreRoom()
	DEFAULT_CHAT_FRAME:AddMessage("GearRack: Not enough room to complete the swap.")
end
