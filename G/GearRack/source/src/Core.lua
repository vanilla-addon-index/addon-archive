if not GearRack.enabled then return end

-- GearRack: one equipment owner for sets, trinkets and manual swaps.

local function message(text)
    DEFAULT_CHAT_FRAME:AddMessage("GearRack: "..text, 1, .82, 0)
end

local function baseID(id)
    return tonumber(string.match(tostring(id or ""), "^(%d+)"))
end
GearRack.BaseID = baseID

-- Bag scans run on every BAG_UPDATE. Reuse one location table per kind instead
-- of allocating one per slot; ClassicAPI reads it only during the call.
local bagLocation,equipLocation={},{}
local function bagGUID(bag,slot)
    bagLocation.bagID,bagLocation.slotIndex=bag,slot
    return C_Item.GetItemGUID(bagLocation)
end
local function equippedGUID(slot)
    equipLocation.equipmentSlotIndex=slot
    return C_Item.GetItemGUID(equipLocation)
end
GearRack.BagGUID,GearRack.EquippedGUID = bagGUID,equippedGUID

local EMPTY = {}
local function index(map,key,entry)
    local list=map[key]
    if not list then list={};map[key]=list end
    table.insert(list,entry)
end

-- Bars, sets and event choices are keyed per character.
function GearRack.CharacterKey()
    return UnitName("player").." of "..GetRealmName()
end

-- Rarity borders for item buttons, above common quality only.
local qualityColors = {
    [2]={.05,1,.15}, [3]={0,.7,1}, [4]={.85,.2,1}, [5]={1,.55,0}, [6]={.95,.85,.4},
}
local qualityBackdrops = {}
function GearRack.SetQualityBorder(button,quality,edgeSize)
    local border=button.qualityBorder
    if type(quality)~="number" or quality<=1 then
        if border then border:Hide() end
        return
    end
    if not border then
        local backdrop=qualityBackdrops[edgeSize]
        if not backdrop then
            backdrop={edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,
                edgeSize=edgeSize,insets={left=0,right=0,top=0,bottom=0}}
            qualityBackdrops[edgeSize]=backdrop
        end
        local name=button:GetName()
        border=CreateFrame("Frame",name and name.."QualityBorder",button)
        border:SetPoint("TOPLEFT",button,"TOPLEFT",-2,2)
        border:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",2,-2)
        border:SetBackdrop(backdrop)
        border:EnableMouse(false)
        button.qualityBorder=border
    end
    if border.quality~=quality then
        border.quality=quality
        local c=qualityColors[quality]
        if c then border:SetBackdropBorderColor(c[1],c[2],c[3],1)
        else
            local r,g,b=GetItemQualityColor(quality)
            border:SetBackdropBorderColor(r,g,b,1)
        end
    end
    border:SetFrameLevel(button:GetFrameLevel()+1)
    border:Show()
end

-- One alert for every ready item: sound, screen and chat.
function GearRack.Alert(text)
    PlaySound("GnomeExploration")
    if SHOW_COMBAT_TEXT=="1" then
        CombatText_AddMessage(text,CombatText_StandardScroll,.2,.7,.9)
    else
        UIErrorsFrame:AddMessage(text,.2,.7,.9,1,UIERRORS_HOLD_TIME)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33b2e5"..text)
end

-- Flyout placement against its source, keyed MainDock..MenuDock.
-- x/yoff: menu offset from the source; x/ydir: direction items are added;
-- x/ystart: first item's offset; mx/my: offset from the equipment bar's buttons.
GearRack.DockStats = {
    TOPRIGHTTOPLEFT       = { xoff=-4, yoff=0,  xdir=1,  ydir=-1, xstart=8,   ystart=-8, mx=3,  my=8 },
    BOTTOMRIGHTBOTTOMLEFT = { xoff=-4, yoff=0,  xdir=1,  ydir=1,  xstart=8,   ystart=44, mx=3,  my=-8 },
    TOPLEFTTOPRIGHT       = { xoff=4,  yoff=0,  xdir=-1, ydir=-1, xstart=-44, ystart=-8, mx=-2, my=8 },
    BOTTOMLEFTBOTTOMRIGHT = { xoff=4,  yoff=0,  xdir=-1, ydir=1,  xstart=-44, ystart=44, mx=-2, my=-8 },
    TOPRIGHTBOTTOMRIGHT   = { xoff=0,  yoff=-4, xdir=-1, ydir=1,  xstart=-44, ystart=44, mx=8,  my=3 },
    BOTTOMRIGHTTOPRIGHT   = { xoff=0,  yoff=4,  xdir=-1, ydir=-1, xstart=-44, ystart=-8, mx=8,  my=-3 },
    TOPLEFTBOTTOMLEFT     = { xoff=0,  yoff=-4, xdir=1,  ydir=1,  xstart=8,   ystart=44, mx=-8, my=2 },
    BOTTOMLEFTTOPLEFT     = { xoff=0,  yoff=4,  xdir=1,  ydir=-1, xstart=8,   ystart=-8, mx=-8, my=-2 },
}

-- Add or remove a window from the game's Escape list.
function GearRack.SetEscapable(name,escapable)
    for i,frame in ipairs(UISpecialFrames) do
        if frame==name then
            if not escapable then table.remove(UISpecialFrames,i) end
            return
        end
    end
    if escapable then table.insert(UISpecialFrames,name) end
end

-- Rescale a frame anchored by its top-left corner without moving that corner.
-- Returns the new corner, or nothing for an invalid scale.
function GearRack.ScaleFrame(frame,scale,x,y)
    scale=tonumber(scale)
    if not scale or scale~=scale or scale<=0 or scale==math.huge then return end
    local old=frame:GetScale() or 1
    local left,top=(frame:GetLeft() or x)*old/scale,(frame:GetTop() or y)*old/scale
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",left,top)
    return left,top
end

-- Called at login, after the client has restored both SavedVariables roots.
function GearRack.NormalizeSavedData()
    GearRackDB=type(GearRackDB)=="table" and GearRackDB or {}
    GearRackCharDB=type(GearRackCharDB)=="table" and GearRackCharDB or {}
    if type(GearRackDB.events)~="table" then GearRackDB.eventsInitialized=nil end
    for _,key in ipairs({"bars","settings","events","sets","trinketOptions"}) do
        if type(GearRackDB[key])~="table" then GearRackDB[key]={} end
    end
    for key,value in pairs(GearRackUI.DefaultSettings) do
        if GearRackDB.settings[key]==nil then GearRackDB.settings[key]=value end
    end
    -- Retired: the trinket window uses the shared tooltip, list and alert settings;
    -- GearRack always draws cooldown numbers, rarity borders and full tooltips.
    for _,key in ipairs({"TooltipFollow","ShowTooltips","MenuOnShift","Notify","NotifyThirty","NotifyChatAlso",
        "HideOnLoad","CooldownCount","LargeCooldown","TinyTooltips"}) do
        GearRackDB.trinketOptions[key]=nil
    end
    for _,key in ipairs({"BigCooldown","CooldownNumbers","QualityBorders","TinyTooltip","Minimap"}) do
        GearRackDB.settings[key]=nil
    end
    -- The combat queue lives in memory only; older versions saved it with the sets.
    for _,character in pairs(GearRackDB.sets) do
        if type(character)=="table" and type(character.Sets)=="table" then character.Sets["GearRackEngine-CombatQueue"]=nil end
    end
    -- Ready watches: one table for every used item (trinkets kept theirs apart before).
    local used=GearRackCharDB.ItemsUsed
    if type(used)~="table" then used=type(GearRackCharDB.trinkets)=="table" and GearRackCharDB.trinkets.ItemsUsed end
    GearRackCharDB.ItemsUsed={}
    if type(used)=="table" then
        for itemID,state in pairs(used) do
            if type(itemID)=="number" and (state==30 or state==5) then GearRackCharDB.ItemsUsed[itemID]=state
            elseif type(itemID)=="number" and type(state)=="number" and state>=0 and state<=3 then GearRackCharDB.ItemsUsed[itemID]=0 end
        end
    end
    if type(GearRackCharDB.trinkets)=="table" then GearRackCharDB.trinkets.ItemsUsed=nil end
    if type(GearRackCharDB.KeepManualTrinkets)~="boolean" then GearRackCharDB.KeepManualTrinkets=true end
    if type(GearRackCharDB.HeldQueues)~="table" then GearRackCharDB.HeldQueues={} end
    GearRackDB.schema=1
    GearRackCharDB.schema=1
end

-- Narrow public queries used by companion addons. They never perform swaps.
function GearRack.GetSetsWithItem(link) return GearRackEngine.GetSetsWithItem(link) end
function GearRack.GetQueuedSlotForItem(link) return GearRackTrinkets.GetQueuedSlotForItem(link) end
function GearRack.IsEquipmentSwapActive() return GearRackEngine.IsEquipmentSwapActive() end
-- The client draws the countdown numbers of a Cooldown frame while the
-- player's countdownForCooldowns CVar is 1; GearRack only gives them its style.
function GearRack.StyleCooldownNumbers(cooldown)
    local font=cooldown:GetCountdownFontString()
    font:SetFont("Fonts\\FRIZQT__.TTF",16,"OUTLINE")
    font:SetTextColor(1,.82,0,1)
end

function GearRack.EquipSet(name) return GearRackUI_EquipSet(name) end
function GearRack.LoadSet(name) return GearRackUI_LoadSet(name) end
function GearRack.ToggleSet(name) return GearRackUI_ToggleSet(name) end
function GearRack.IsSetEquipped(name) return GearRackUI_IsSetEquipped(name) end
function GearRack.SetTrinketQueue(which,action,...)
    return GearRackTrinkets.SetQueue(which,action,...)
end

function GearRack.HasPending()
    return next(GearRack.Requests)~=nil
end

-- Inventory discovery is shared by both flyouts, priority lists and request lookup.
-- Only dirty carried bags are reread; bank ownership stays with the bank subsystem.
function GearRack.InvalidateBag(bag)
    if bag==nil then for i=0,4 do GearRack.DirtyBags[i]=true end
    elseif type(bag)=="number" and bag>=0 and bag<=4 then GearRack.DirtyBags[bag]=true
    else return end
    if GearRack.initialized and not GearRackEngine.TimerEnabled("GearInventory") then
        GearRackEngine.StartTimer("GearInventory")
    end
    return true
end

function GearRack.RefreshInventory()
    if GearRack.initialized then GearRackEngine.StopTimer("GearInventory") end
    if GearRack.inventoryReady and not next(GearRack.DirtyBags) then return end
    -- Entry and index tables are reused; callers copy what they keep.
    for bag in pairs(GearRack.DirtyBags) do
        local entries=GearRack.Bags[bag] or {}
        local itemIDs=GearRack.BagItemIDs[bag] or {}
        GearRack.Bags[bag],GearRack.BagItemIDs[bag]=entries,itemIDs
        table.wipe(itemIDs)
        local count=0
        for slot=1,GetContainerNumSlots(bag) do
            local texture,id,name,equipLoc,quality,rawID = GearRackEngine.GetItemInfo(bag,slot)
            local itemID=rawID or baseID(id)
            -- Occupied slots must remain discoverable even before link/static data is cached.
            if itemID then itemIDs[itemID]=true end
            if id then
                count=count+1
                local entry=entries[count]
                if not entry then entry={};entries[count]=entry end
                entry.bag,entry.slot,entry.id,entry.baseID,entry.name=bag,slot,id,baseID(id),name
                entry.texture,entry.equipLoc,entry.quality=texture,equipLoc,quality
                entry.guid=bagGUID(bag,slot)
            end
        end
        for i=#entries,count+1,-1 do entries[i]=nil end
        GearRack.DirtyBags[bag]=nil
    end
    table.wipe(GearRack.Items)
    for _,list in pairs(GearRack.ByID) do table.wipe(list) end
    for _,list in pairs(GearRack.ByName) do table.wipe(list) end
    table.wipe(GearRack.ByGUID)
    for bag=0,4 do
        for _,entry in ipairs(GearRack.Bags[bag] or EMPTY) do
            table.insert(GearRack.Items,entry)
            index(GearRack.ByID,entry.id,entry)
            index(GearRack.ByID,entry.baseID,entry)
            if entry.name then index(GearRack.ByName,entry.name,entry) end
            if entry.guid then GearRack.ByGUID[entry.guid]=entry end
        end
    end
    GearRack.inventoryReady=true
    GearRack.inventoryRevision=(GearRack.inventoryRevision or 0)+1
    if GearRack.initialized then
        if GearRackTrinkets_MenuFrame:IsVisible() then GearRackTrinkets.BuildMenu() end
        GearRack.Wake()
    end
end

-- Broad inventory notifications include instance-state changes. Compare identity
-- before invalidating carried locations; equal item IDs can be different copies.
local equippedSlotIDs,equippedGUIDs={},{}
function GearRack.RefreshEquippedItemIDs()
    local changed=not GearRack.equippedRead
    GearRack.equippedRead=true
    table.wipe(GearRack.EquippedItemIDs)
    table.wipe(GearRack.BagContainerIDs)
    for slot=1,23 do
        local itemID=GetInventoryItemID("player",slot)
        if equippedSlotIDs[slot]~=itemID then changed=true end
        equippedSlotIDs[slot]=itemID
        if slot<=19 then
            local guid=equippedGUID(slot)
            if equippedGUIDs[slot]~=guid then changed=true end
            equippedGUIDs[slot]=guid
            if itemID and itemID>0 then GearRack.EquippedItemIDs[itemID]=true end
        else GearRack.BagContainerIDs[slot-19]=itemID end
    end
    return changed
end

-- Global cache notifications also cover inspected/vendor/database items.
-- Refresh only owned locations; successful cold-item fills retain their raw ID.
function GearRack.ItemDataReceived(itemID,success)
    itemID=tonumber(itemID)
    if not success or not itemID then return end
    local changed
    for bag=0,4 do
        if (GearRack.BagItemIDs[bag] and GearRack.BagItemIDs[bag][itemID])
            or GearRack.BagContainerIDs[bag]==itemID then
            GearRack.InvalidateBag(bag)
            changed=true
        end
    end
    local bank=GearRackUI.BankIsOpen and GearRackUI.BankItemIDs[itemID]
    return changed or GearRack.EquippedItemIDs[itemID] or bank,bank
end

function GearRack.GetCarriedItems()
    if not GearRack.inventoryReady or next(GearRack.DirtyBags) then GearRack.RefreshInventory() end
    return GearRack.Items
end

local function matches(entry,id,name)
    return (id and (entry.id==id or entry.baseID==id)) or (not id and entry.name==name)
end

-- Lookup scratch: one GUID match, and the equipped-slot result callers copy.
local byGUID,worn={},{}
function GearRack.FindLocation(id,name,passive,includeInventory,guid)
    GearRack.GetCarriedItems()
    local list
    if guid then byGUID[1]=GearRack.ByGUID[guid];list=byGUID
    else list=id and GearRack.ByID[id] or GearRack.ByName[name] end
    for _,entry in ipairs(list or EMPTY) do
        if (passive or not GearRackEngine.LockList[entry.bag][entry.slot]) and matches(entry,id,name) then
            local _,liveID=GearRackEngine.GetItemInfo(entry.bag,entry.slot)
            if liveID==entry.id and (not guid or bagGUID(entry.bag,entry.slot)==guid) then
                return nil,entry.bag,entry.slot,entry
            end
            GearRack.InvalidateBag(entry.bag)
        end
    end
    if includeInventory then
        for slot=0,19 do
            if passive or not GearRackEngine.LockList[-2][slot] then
                local texture,liveID,liveName,equipLoc,quality=GearRackEngine.GetItemInfo(slot)
                worn.id,worn.baseID,worn.name,worn.texture=liveID,baseID(liveID),liveName,texture
                worn.equipLoc,worn.quality,worn.inv=equipLoc,quality,slot
                worn.guid=slot>0 and equippedGUID(slot) or nil
                if matches(worn,id,name) and (not guid or worn.guid==guid) then return slot,nil,nil,worn end
            end
        end
    end
end

-- Ready notices feed the alert (Notify when ready) and any enabled
-- GEARRACK_NOTIFY event; either one is enough to watch used items.
function GearRack.WantsReadyNotice()
    return GearRackDB.settings.Notify=="ON" or GearRackUI.Register.GEARRACK_NOTIFY~=nil
end

-- A used item is ready (soon: 30 seconds left). Notify at 30 replaces the
-- ready message; both go through the equipment notifier and its event.
function GearRack.ItemReady(name,soon)
    if GearRack.WantsReadyNotice() and soon==(GearRackDB.settings.NotifyThirty=="ON") then
        GearRackUI_Notify(name)
    end
end

-- Ready alerts for used items: one watch per item ID, wherever the item moves.
-- A watch gives the item three seconds to start its cooldown, then looks again
-- when 30 seconds are left and when it is ready, not every second.
-- GearRackCharDB.ItemsUsed[itemID]: 0 while it waits for the cooldown, 30 with
-- both looks ahead, 5 with only the ready look left. It survives a reload.
local watches={} -- [itemID] = {inv=, bag=, slot=, since=}

function GearRack.WatchUse(itemID,inv)
    if not itemID or not GearRack.WantsReadyNotice() then return end
    local watch=watches[itemID] or {}
    watches[itemID]=watch
    watch.inv,watch.bag,watch.slot,watch.since=inv,nil,nil,GetTime()
    GearRackCharDB.ItemsUsed[itemID]=0
    GearRackEngine.StartTimer("CooldownUpdate",1,true)
end

local function watched_cooldown(itemID,watch)
    local current=(watch.inv and GetInventoryItemID("player",watch.inv))
        or (watch.bag and C_Container.GetContainerItemID(watch.bag,watch.slot))
    if current~=itemID then watch.inv,watch.bag,watch.slot=GearRack.FindLocation(itemID,nil,true,true) end
    if watch.inv then return GearRack.GetInventoryCooldown(watch.inv) end
    if watch.bag then return GetContainerItemCooldown(watch.bag,watch.slot) end
end

local function item_name(itemID)
    return GetItemInfo(itemID) or ("Item "..itemID)
end

-- Gives the alerts that are due; returns the seconds until the next look, or nil.
function GearRack.UpdateReadyWatch()
    local used,now,wake=GearRackCharDB.ItemsUsed,GetTime()
    for itemID,state in pairs(used) do
        local watch=watches[itemID]
        if not watch then watch={since=now};watches[itemID]=watch end -- after a reload
        local start,duration=watched_cooldown(itemID,watch)
        local left=start and start>0 and duration-(now-start) or 0
        local look
        if not start then
            state=nil -- no longer carried
        elseif state==0 then
            if left>5 then
                state=left>29 and 30 or 5
                if state==5 then GearRack.ItemReady(item_name(itemID),true) end
            elseif now-watch.since<3 then look=1
            else state=nil end -- no cooldown started
        end
        if state==30 then
            if left<30 then GearRack.ItemReady(item_name(itemID),true);state=5
            else look=left-30 end
        end
        if state==5 then
            if left<=0 then GearRack.ItemReady(item_name(itemID),false);state=nil
            else look=left end
        end
        used[itemID]=state
        if not state then watches[itemID]=nil end
        if look and (not wake or look<wake) then wake=look end
    end
    return wake
end

function GearRack.GetInventoryCooldown(slot)
    local cache=GearRack.CooldownRead
    if not cache then return GetInventoryItemCooldown("player",slot) end
    local cd=cache[slot]
    if not cd then cd={};cache[slot]=cd end
    if cd.generation~=GearRack.cooldownGeneration then
        cd[1],cd[2],cd[3]=GetInventoryItemCooldown("player",slot)
        cd.generation=GearRack.cooldownGeneration
    end
    return cd[1],cd[2],cd[3]
end

-- The enchant labels, ready watches and trinket queues each say when they next
-- need a look; the timer wakes for the soonest and sleeps while none does.
local cooldownCache,wake={},nil
local function soonest(seconds)
    if seconds and (not wake or seconds<wake) then wake=seconds end
end
local function update_cooldown_views()
    soonest(GearRackUI_CooldownUpdate_OnUpdate())
    soonest(GearRack.UpdateReadyWatch())
    soonest(GearRackTrinkets.CooldownUpdate())
end

function GearRack.CooldownUpdate()
    GearRack.cooldownGeneration=(GearRack.cooldownGeneration or 0)+1
    GearRack.CooldownRead=cooldownCache
    wake=nil
    -- An error goes to the error handler with its stack; the cache closes either way.
    xpcall(update_cooldown_views,geterrorhandler())
    GearRack.CooldownRead=nil
    -- Just past the moment, so a label or an alert has crossed its line.
    if wake then GearRackEngine.StartTimer("CooldownUpdate",math.max(wake+.05,.1)) end
end

function GearRack.KeepManualTrinket(slot)
    if slot~=13 and slot~=14 then return end
    if GearRackCharDB.KeepManualTrinkets then
        GearRackCharDB.HeldQueues[slot-13]=true
        GearRackTrinkets.ReflectQueueEnabled()
    end
end

function GearRack.CancelAutomaticTrinket(which)
    local slot=13+which
    if GearRack.Requests[slot] and GearRack.Requests[slot].automatic then
        GearRack.Requests[slot]=nil
        GearRack.UpdateQueuePresentation()
        GearRack.Wake()
    end
end

function GearRack.ResumeTrinketQueue(which)
    GearRackCharDB.HeldQueues[which]=nil
end

-- A slot's queued-item badges, on its bar button and its character-sheet slot.
local queueBadges={}
function GearRack.ShowQueueBadge(slot,shown,texture)
    local badges=queueBadges[slot]
    if not badges then
        badges={_G["GearRackUIInv"..slot.."Queue"],_G[GearRackUI.Indexes[slot].paperdoll_slot.."Queue"]}
        queueBadges[slot]=badges
    end
    for i=1,2 do
        local badge=badges[i]
        if shown then badge:SetTexture(texture);badge:Show() else badge:Hide() end
    end
end

function GearRack.UpdateQueuePresentation()
    for slot=0,19 do
        local request=GearRack.Requests[slot]
        if request then
            GearRack.ShowQueueBadge(slot,true,request.texture)
        elseif not GearRackEngine.CombatQueue[slot] then
            GearRack.ShowQueueBadge(slot,false)
        end
        if slot==13 or slot==14 then
            local which=slot-13
            local deferred=GearRackEngine.CombatQueue[slot]
            GearRackTrinkets.CombatQueue[which]=request and request.name or (deferred and GearRackEngine.GetNameByID(deferred))
            GearRackTrinkets.QueueItemIDs[which]=request and request.baseID or baseID(deferred)
        end
    end
    GearRackTrinkets.UpdateCombatQueue()
end

function GearRack.RequestItem(slot,item,automatic,toggle)
    automatic=automatic and true or nil
    if not GearRackEngine.SlotInfo[slot] or type(item)~="table" or item.id==nil then return end
    local numericID=baseID(item.id)
    local _,_,_,_,_,_,_,equipLoc=GetItemInfo(numericID or "")
    if item.id~=0 and (not numericID or not C_PlayerInfo.CanUseItem(numericID)
        or (equipLoc and not GearRackEngine.SlotInfo[slot][equipLoc])
        or (slot==17 and equipLoc=="INVTYPE_WEAPON" and not CanDualWield())) then
        message("That item cannot be equipped in this slot.")
        return
    end
    local previous=GearRack.Requests[slot]
    if previous and previous.id==item.id and previous.guid==item.guid and previous.automatic==automatic then
        if toggle and not automatic then
            GearRack.Requests[slot]=nil
            GearRack.UpdateQueuePresentation()
            GearRack.Wake()
        end
        return
    end
    local _,worn=GearRackEngine.GetItemInfo(slot)
    local active=GearRackEngine.SwapRequest and GearRackEngine.SwapRequest.items[slot]
    for _,idx in ipairs(GearRackEngine.SwapQueueOrder) do
        local queued=GearRackEngine.SwapQueue[idx]
        if queued.direction=="NEWSET" and queued.context.items[slot] then active=true;break end
    end
    active=active or GearRackEngine.CombatQueue[slot]
    if not active and worn==item.id and (not item.guid or equippedGUID(slot)==item.guid) then
        GearRack.Requests[slot]=nil
    else
        GearRack.sequence=(GearRack.sequence or 0)+1
        local name,texture=GearRackEngine.GetNameByID(item.id)
        GearRack.Requests[slot]={slot=slot,id=item.id,baseID=baseID(item.id),guid=item.guid,
            name=item.name or name,texture=item.texture or texture,
            automatic=automatic,sequence=GearRack.sequence,equipLoc=equipLoc}
    end
    if not automatic and slot==16 and equipLoc=="INVTYPE_2HWEAPON" then GearRack.Requests[17]=nil end
    if not automatic and slot==17 and item.id~=0 then
        local main=GearRack.Requests[16]
        if main and main.equipLoc=="INVTYPE_2HWEAPON" then GearRack.Requests[16]=nil end
    end
    if item.guid then
        for other,request in pairs(GearRack.Requests) do
            if other~=slot and request.guid==item.guid then GearRack.Requests[other]=nil end
        end
    end
    if not automatic then
        GearRackEngine.OverrideDeferredSlot(slot)
        GearRack.KeepManualTrinket(slot)
    end
    GearRack.UpdateQueuePresentation()
    GearRack.Pump()
end

function GearRack.QueueItem(item,slot)
    slot=tonumber(slot)
    if not slot or not GearRackEngine.SlotInfo[slot] then return end
    local id=type(item)=="number" and item or baseID(string.match(tostring(item),"item:(%d+)"))
    local inv,bag,bagSlot,entry=GearRack.FindLocation(id,id and nil or item,true,true)
    if entry then GearRack.RequestItem(slot,entry) else message("That item is not carried.") end
end

function GearRack.Wake()
    if GearRack.initialized and not GearRack.worldSuspended and not GearRack.pumping
        and not GearRackEngine.IsPlayerReallyDead() then
        if GearRackEngine.SwapRequest then
            GearRackEngine.StartTimer("WaitToIterate",.05,true)
        elseif GearRack.HasPending() then
            GearRackEngine.StartTimer("GearRequests",.05,true)
        end
    end
end

-- Manual clicks outrank automatic trinket proposals. Latest choice wins per slot.
-- One existing GearRackEngine transaction executes all requests; no second equip processor.
function GearRack.Pump()
    if GearRack.pumping or not GearRack.initialized or GearRack.worldSuspended then return end
    GearRack.pumping=true
    GearRackEngine.StopTimer("GearRequests")
    if GearRackEngine.BankTransfer then GearRack.pumping=nil;return end
    if GearRackEngine.SwapRequest then GearRackEngine.IterateSwapQueue() end
    if GearRackEngine.SwapRequest or #GearRackEngine.SwapQueueOrder>0 or GearRackEngine.SwapIssuing then
        GearRack.pumping=nil
        return
    end
    if GearRackEngine.IsPlayerReallyDead() then GearRack.pumping=nil;return end
    local selected
    local inCombat=UnitAffectingCombat("player")
    for slot,request in pairs(GearRack.Requests) do
        if (not inCombat or GearRackEngine.SlotInfo[slot].swappable)
            and request.waitForSpace~=GearRack.inventoryRevision then
            if not selected or (selected.automatic and not request.automatic)
                or (selected.automatic==request.automatic and request.sequence<selected.sequence) then selected=request end
        end
    end
    if selected then
        -- Known cast/GCD blocks need neither item discovery nor lock scans.
        -- Native cast-end/cooldown events wake this timer early when interrupted.
        local delay=GearRack.GetEquipDelay(GearRackEngine.SlotInfo[selected.slot].swappable)
        if delay>0 then
            GearRackEngine.StartTimer("GearRequests",delay)
            GearRack.pumping=nil
            return
        end
        if GetCursorInfo() or SpellIsTargeting() or GearRackEngine.AnyLocked() then
            GearRackEngine.StartTimer("GearRequests",.2)
            GearRack.pumping=nil
            return
        end
        if selected.automatic then
            local valid,changed=GearRackTrinkets.ValidateAutomaticRequest(selected)
            if not valid then
                GearRack.pumping=nil
                if changed then GearRack.Wake() end
                return
            end
        end
        local inv,bag=GearRack.FindLocation(selected.id,selected.name,true,true,selected.guid)
        if selected.id~=0 and not inv and not bag then
            if not next(GearRack.DirtyBags) then
                GearRack.Requests[selected.slot]=nil
                message("The queued item is no longer carried.")
                GearRack.UpdateQueuePresentation()
            end
        else
            GearRackEngine.EquipSet("GearRackEngine-Choice-"..selected.slot,nil,
                {items={[selected.slot]={id=selected.id,name=selected.name,guid=selected.guid}},intent=selected,persistent=true})
        end
        if not GearRackEngine.SwapRequest and GearRack.Requests[selected.slot]==selected
            and GearRackEngine.SlotMatches(selected.slot,selected) then
            GearRack.Requests[selected.slot]=nil
            GearRack.UpdateQueuePresentation()
        end
    end
    GearRack.pumping=nil
    if GearRack.HasPending() and not GearRackEngine.SwapRequest and selected then GearRackEngine.StartTimer("GearRequests",.2) end
end

function GearRack.TransactionFinished(request,reason)
    if request and request.intent and GearRack.Requests[request.intent.slot]==request.intent then
        if reason or GearRackEngine.SwapMatches(request.items) then GearRack.Requests[request.intent.slot]=nil end
    end
    if GearRack.initialized then
        GearRack.UpdateQueuePresentation()
        GearRack.Wake()
    end
end

function GearRack.UIEvent(ev,unit,spellID,castType)
    if not GearRack.initialized then return end
    if ev=="BAG_UPDATE" then
        local carried=GearRack.InvalidateBag(unit)
        local bank=GearRackUI.BankIsOpen and type(unit)=="number" and (unit==-1 or (unit>=5 and unit<=10))
        return carried or bank,bank
    elseif ev=="GET_ITEM_INFO_RECEIVED" then return GearRack.ItemDataReceived(unit,spellID)
    elseif ev=="UNIT_INVENTORY_CHANGED" and unit=="player" then
        -- Also fires for durability, charges and ammo counts. Views redraw only
        -- when a worn item really changed; swaps still check completion.
        local changed=GearRack.RefreshEquippedItemIDs()
        if changed then
            GearRack.InvalidateBag()
            GearRackTrinkets.UpdateWornTrinkets()
        end
        if GearRackEngine.SwapRequest then GearRackEngine.OnItemLockChanged() end
        GearRack.Wake()
        return changed
    elseif ev=="ACTIONBAR_UPDATE_COOLDOWN" then GearRackTrinkets.UpdateWornCooldowns();GearRack.Wake()
    elseif ev=="UPDATE_BINDINGS" then
        GearRackTrinkets.ReflectKeyBindings()
    elseif ev=="SPELLCAST_STOP" or ev=="SPELLCAST_INTERRUPTED" or ev=="SPELLCAST_FAILED" or ev=="SPELLCAST_CHANNEL_STOP" then
        GearRack.Wake()
    elseif ev=="PLAYER_ENTERING_WORLD" then
        GearRack.worldSuspended=nil
        GearRack.RefreshEquippedItemIDs()
        GearRack.InvalidateBag()
        GearRackUI_EnableAllEvents()
        if GearRackEngine.SwapRequest or #GearRackEngine.SwapQueueOrder>0 then GearRackEngine.IterateSwapQueue() end
        if next(GearRackEngine.CombatQueue) then GearRackEngine.OnEvent("PLAYER_REGEN_ENABLED") end
        GearRack.Wake()
    elseif ev=="PLAYER_DEAD" then
        GearRackEngine.CancelBankTransfer()
        GearRackEngine.ReconcileDeathPause()
        GearRack.CloseMenus()
        GearRackEngine.StopTimer("GearRequests");GearRackEngine.StopTimer("WaitToIterate")
    elseif ev=="PLAYER_REGEN_DISABLED" then GearRack.Wake()
    elseif ev=="PLAYER_LEAVING_WORLD" then
        GearRack.worldSuspended=true
        GearRackEngine.CancelBankTransfer()
        GearRack.CloseMenus()
        GearRackUI_DisableAllEvents()
        GearRackEngine.StopTimer("GearRequests");GearRackEngine.StopTimer("WaitToIterate")
    elseif ev=="SPELL_CAST_EVENT" and unit==1 and (castType==0 or castType==3 or castType==4) then
        GearRack.lastGCDSpell=spellID
        GearRack.Wake()
    end
end

-- Measured in play: casts (mounting, herbs) do not stop a weapon swap, and out
-- of combat weapons swap at once. Weapons and ammo therefore never wait; a swap
-- the client refuses in combat is retried instead. Armor keeps the cast and
-- global-cooldown wait, which has not been measured.
function GearRack.GetEquipDelay(weaponsOnly)
    if weaponsOnly then return 0 end
    local delay=0
    local cast=GetCastInfo()
    if cast then delay=math.max(cast.castRemainingMs or 0,cast.gcdRemainingMs or 0)/1000 end
    if GearRack.lastGCDSpell then
        local cd=GetSpellIdCooldown(GearRack.lastGCDSpell)
        if cd then delay=math.max(delay,(cd.gcdCategoryRemainingMs or 0)/1000) end
    end
    return delay>0 and (delay+.02) or 0
end

function GearRack.Initialize()
    if GearRack.initialized then return end
    GearRack.NormalizeSavedData()
    GearRackUIFrame:RegisterEvent("SPELL_CAST_EVENT")
    GearRackTrinkets.LoadDefaults()
    GearRackTrinkets.Initialize()
    GearRackEngine.CreateTimer("GearInventory",GearRack.RefreshInventory,.05)
    GearRackEngine.CreateTimer("GearRequests",GearRack.Pump,.2)
    GearRack.initialized=true
    GearRack.RefreshEquippedItemIDs()
    GearRack.InvalidateBag()
    GearRack.RefreshInventory()
    GearRack.CreateSettings()
    GearRackEngine.StartTimer("CooldownUpdate",.05)
    GearRackUIFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    GearRackUIFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    GearRackUIFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    GearRackUIFrame:RegisterEvent("PLAYER_DEAD")
    GearRackUIFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    for _,ev in ipairs({"SPELLCAST_STOP","SPELLCAST_INTERRUPTED","SPELLCAST_FAILED","SPELLCAST_CHANNEL_STOP"}) do
        GearRackUIFrame:RegisterEvent(ev)
    end
end
