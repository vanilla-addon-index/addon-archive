-- Bagshui Inventory Prototype: Actions
-- Moving, equipping, making stuff happen.

Bagshui:AddComponent(function()
  local Inventory = Bagshui.prototypes.Inventory

  --- Clear all stock change indicators.
  function Inventory:ResetStockState()
    for _, container in pairs(self.inventory) do
      for _, item in pairs(container) do
        item.bagshuiDate = 0
        item.bagshuiStockState = BS_ITEM_STOCK_STATE.NO_CHANGE
      end
    end
    -- Update the window, cascade to docked inventory, and force cache update.
    -- (Inventory:UpdateCache() is where hasChanges is updated).
    self:ForceUpdateWindow(true, true)
  end

  --- Return `true` if an item is protected from sale by the current settings.
  ---@param item table Bagshui inventory cache entry.
  ---@return string? protectionType Localized reason the item was protected ("Soulbound", "Quality", etc.), if any.
  function Inventory:GetItemSellProtectionReason(item)
    -- Protection is completely disabled.
    if not self.settings.sellProtectionEnabled then
      return
    end

    -- Active Quest.
    if self.settings.sellProtectionActiveQuest and Bagshui.activeQuestItems[item.name] then
      return L.ItemPropFriendly_activeQuest
    end

    -- Soulbound.
    if self.settings.sellProtectionSoulbound and BsRules:Match("Soulbound()", item) then
      return L.ItemPropFriendly_soulbound
    end

    -- Equipped Gear.
    if self.settings.sellProtectionEquipped and BsCharacter.equippedHistory[item.itemString] then
      return L.EquippedGear
    end

    -- Quality at or above threshold.
    if (item.quality or 1) >= self.settings.sellProtectionQualityThreshold then
      return L.Quality
    end
  end

  --- Reset the pending sale of an item so it's no longer highlighted.
  ---@param itemButton table? If provided, call OnEnter for this item button to update the tooltip.
  ---@param noUpdate boolean? Don't call `Inventory:UpdateItemSlotColors()`.
  function Inventory:ClearItemPendingSale(itemButton, noUpdate)
    if self.itemPendingSale then
      self.itemPendingSale = nil
      self.highlightItemsInContainerId = nil
      self.highlightItemsContainerSlot = nil
      if itemButton then
        self:ItemButton_OnEnter(itemButton)
      end
      if not noUpdate then
        self:UpdateItemSlotColors()
      end
    end
  end

  --- Sort and organize inventory while the window is open.
  --- Used from toolbars, menus, and key bindings.
  function Inventory:Resort()
    self.forceResort = true
    -- Do NOT use QueueUpdate() here.
    self:Update(true)
  end

  --- Initiate the restacking process.
  --- This doesn't do the actual work; it just sets up a queue of restack operations,
  --- which is necessary because there needs to be a slight delay between each operation.
  --- That process is handled by ProcessMoveQueue().
  ---@param skipSpecialtyMoves boolean? Only consolidate stacks (used after the specialty bag moves are done).
  function Inventory:Restack(skipSpecialtyMoves)
    -- Ensure inventory cache is up to date.
    self.cacheUpdateNeeded = true
    self:UpdateCache()

    -- First move items into matching specialty bags (herbs into an herb bag, shards into a soul bag...),
    -- then come back here to consolidate stacks.
    if not skipSpecialtyMoves then
      self:ClearMoveQueue()
      if self:FindSpecialtyBagMoves(true) > 0 then
        if not self.restack_afterSpecialtyMoves then
          self.restack_afterSpecialtyMoves = function()
            Bagshui:QueueClassCallback(self, self.Restack, 0.2, nil, true)
          end
        end
        self:MoveItems(self.restack_afterSpecialtyMoves)
        return
      end
    end

    -- This function can be called when a docked inventory has partial stacks
    -- but this one doesn't. The case where this one has partials and the docked
    -- one may or may not is handled once Inventory:ProcessMoveQueue() is done.
    if not self.multiplePartialStacks then
      if self.dockedInventory then
        self.dockedInventory:Restack()
      end
      return
    end

    -- Prepare the helper function for sorting partial stacks.
    if not self._PartialStackSortHelper then
      self._PartialStackSortHelper = function(itmA, itmB)
        return itmA.count > itmB.count
      end
    end

    -- Reset restack queues.
    self:ClearMoveQueue()

    -- Reset restack retry count (used by ProcessMoveQueue() to decide when to give up if items are locked).
    self.moveRetryCount = 0

    -- Find all the partial stacks.
    -- This will build out a table:
    -- ```
    -- {
    --   [itemId1] = {
    --     itemCacheReference1,
    --     itemCacheReference2,
    --     itemCacheReference3,
    --   }
    --   [itemId2] = {
    --     itemCacheReference4,
    --     itemCacheReference5,
    --   }
    -- }
    -- ```
    local allPartialStacks = {}
    for _, bagContents in pairs(self.inventory) do
      for _, item in ipairs(bagContents) do
        if (self.partialStacks[item.id] or 0) > 1 and item.count < item.maxStackCount then
          if allPartialStacks[item.id] == nil then
            allPartialStacks[item.id] = {}
          end
          table.insert(allPartialStacks[item.id], item)
        end
      end
    end

    -- Sort partial stack lists for each item from largest to smallest.
    for _, partialStacks in pairs(allPartialStacks) do
      table.sort(partialStacks, self._PartialStackSortHelper)
    end

    local target, source, oldTargetCount, sourceLoopStart

    -- Process each item's set of partial stacks in turn to create the restack queue.
    for _, partialStacks in pairs(allPartialStacks) do
      --self:PrintDebug("Restacking item ID " .. _)

      -- Sources are obtained starting from the end of the list since it's
      -- sorted largest to smallest and we're trying to move stacks with the
      -- lowest counts onto those with the highest counts.
      sourceLoopStart = table.getn(partialStacks)

      -- Likewise, targets are obtained from the beginning of the list.
      for targetIndex = 1, table.getn(partialStacks) - 1 do
        target = partialStacks[targetIndex]
        --self:PrintDebug("> starting target count: " .. target.count .. " (of max " .. target.maxStackCount .. " )")

        if target.count < target.maxStackCount then
          -- Work backwards through the list of partial stacks, potentially
          -- up to the next-to-first (which is the initial target, so we
          -- know we can never use it as a source).
          for sourceIndex = sourceLoopStart, 2, -1 do
            source = partialStacks[sourceIndex]
            --self:PrintDebug(">> source count: " .. source.count)

            if source ~= target and source.count > 0 and target.count < target.maxStackCount and target.count > 0 then
              -- Calculate the changes.
              oldTargetCount = target.count
              target.count = math.min(target.count + source.count, target.maxStackCount)
              source.count = source.count - (target.count - oldTargetCount)

              -- Queue move of source stacks onto target (with the exact amount, for instant moves).
              self:QueueMove(source, target, target.count - oldTargetCount)
              --self:PrintDebug(string.format(">>> queued %s:%s (%s) to %s:%s (%s)", source.bagNum, source.slotNum, source.count, target.bagNum, target.slotNum, target.count))
              --self:PrintDebug(">> NEW source count: " .. source.count)
              --self:PrintDebug(">> NEW target count: " .. target.count)

              -- We're done with this source and can move on to the next one.
              if source.count == 0 then
                sourceLoopStart = sourceLoopStart - 1
              end

              -- Stop the inner loop if current target is maxed out.
              if target.count == target.maxStackCount then
                --self:PrintDebug(">> target maxed; breaking inner loop")
                break
              end
            end
          end
        end
      end
    end
    --self:PrintDebug(table.getn(self.queuedMoveSources) .. " moves queued")

    -- Reusable function for restacking docked Inventory class.
    if self.dockedInventory and not self.restack_callback then
      self.restack_callback = function()
        self.dockedInventory:Restack()
      end
    end

    -- Make the actual moves.
    self:MoveItems(self.restack_callback)
  end

  function Inventory:ClearMoveQueue()
    BsUtil.TableClear(self.queuedMoveSources)
    BsUtil.TableClear(self.queuedMoveTargets)
    BsUtil.TableClear(self.queuedMoveCounts)
  end

  ---@param source table Inventory cache entry to move from.
  ---@param target table Inventory cache entry to move to.
  ---@param count number? How many to move (whole stack when omitted).
  function Inventory:QueueMove(source, target, count)
    table.insert(self.queuedMoveSources, source)
    table.insert(self.queuedMoveTargets, target)
    table.insert(self.queuedMoveCounts, count or 0)
  end

  --- Perform queued item move operations.
  ---
  --- 🚦 Before calling, the `Inventory.queuedMoveSources/Targets` arrays must be
  --- filled with the corresponding items that should be moved. (There aren't any
  --- functions to do this; just use `table.insert()`).
  ---
  --- `Inventory:Restack()` is a good example of how to do this.
  ---@param onComplete function? Will receive one boolean parameter indicating the success or failure of the move operations.
  ---@param onProgress function? Will receive one number parameter indicating the current item in the list of moves that just completed.
  ---@param resortAfterEachMove boolean? Organize the inventory after every action.
  function Inventory:MoveItems(onComplete, onProgress, resortAfterEachMove)
    -- Tracks the overall success of all operations in this session and is passed to `moveQueue_onComplete`.
    self.moveQueue_success = true
    -- Invoked when the move queue is empty and passed the success/failure status.
    self.moveQueue_onComplete = onComplete
    -- Used to calculate the current step for `moveQueue_onProgress()` since
    self.moveQueue_totalItems = table.getn(self.queuedMoveSources)
    -- Invoked after each move and passed the number of the move.
    self.moveQueue_onProgress = onProgress
    -- Organize inventory after every move.
    self.moveQueue_resort = resortAfterEachMove
    -- Reset tracking.
    self.moveQueue_LastSource = nil
    if self:CanBatchMoves() then
      self:StartMoveQueueBatched()
    else
      self:ProcessMoveQueue()
    end
  end

  --- Can the queued moves be done with ClassicAPI's C_Container.MoveItem() (no cursor, all at once)?
  --- Equipping a bag (a numeric target) still needs the cursor.
  ---@return boolean
  function Inventory:CanBatchMoves()
    if type(_G.C_Container) ~= "table" or type(_G.C_Container.MoveItem) ~= "function" then
      return false
    end
    for _, target in ipairs(self.queuedMoveTargets) do
      if type(target) ~= "table" then
        return false
      end
    end
    return true
  end

  --- Copy the queued moves into the batch lists and start the first round.
  function Inventory:StartMoveQueueBatched()
    self.moveBatch_sources = self.moveBatch_sources or {}
    self.moveBatch_targets = self.moveBatch_targets or {}
    self.moveBatch_counts = self.moveBatch_counts or {}
    self.moveBatch_usedSlots = self.moveBatch_usedSlots or {}
    BsUtil.TableClear(self.moveBatch_sources)
    BsUtil.TableClear(self.moveBatch_targets)
    BsUtil.TableClear(self.moveBatch_counts)

    -- Amounts are only valid when they line up with the queue (FillBag() doesn't set any).
    local haveCounts = table.getn(self.queuedMoveCounts) == table.getn(self.queuedMoveSources)
    for i = 1, table.getn(self.queuedMoveSources) do
      table.insert(self.moveBatch_sources, self.queuedMoveSources[i])
      table.insert(self.moveBatch_targets, self.queuedMoveTargets[i])
      table.insert(self.moveBatch_counts, haveCounts and self.queuedMoveCounts[i] or 0)
    end
    self:ClearMoveQueue()

    self.moveBatch_retries = 0
    self.moveBatch_waiting = false
    self.moveBatch_done = 0
    self:ProcessMoveQueueBatched()
  end

  --- # 🛑 Do not call directly; use `Inventory:MoveItems()` 🛑.
  --- Instant item mover using ClassicAPI's C_Container.MoveItem() (same approach as pfUI's bag sort).
  --- Each round sends every move whose slots aren't already part of this round and aren't locked,
  --- then waits for BAG_UPDATE_DELAYED (server confirmation) before the next round. A stack that
  --- is split onto several targets, or a locked slot, simply waits for a later round.
  function Inventory:ProcessMoveQueueBatched()
    self.moveBatch_waiting = false

    local sources = self.moveBatch_sources
    local targets = self.moveBatch_targets
    local counts = self.moveBatch_counts

    -- Are we done?
    if table.getn(sources) <= 0 then
      self:QueueUpdate(0.1)
      if type(self.moveQueue_onComplete) == "function" then
        self.moveQueue_onComplete(self.moveQueue_success)
      end
      return
    end

    -- Set resorting for this inventory and any supplemental storage.
    if self.moveQueue_resort then
      self.forceResort = true
      if type(self.bagSwappingSupplementalStorage) == "table" then
        for _, inventoryClassName in ipairs(self.bagSwappingSupplementalStorage) do
          if Bagshui.components[inventoryClassName] and Bagshui.components[inventoryClassName].online then
            Bagshui.components[inventoryClassName].forceResort = true
          end
        end
      end
    end

    local usedSlots = self.moveBatch_usedSlots
    BsUtil.TableClear(usedSlots)
    local fired = 0
    local i = 1

    while i <= table.getn(sources) do
      local source = sources[i]
      local target = targets[i]
      local sourceKey = source.bagNum .. ":" .. source.slotNum
      local targetKey = target.bagNum .. ":" .. target.slotNum
      local handled = false

      if not usedSlots[sourceKey] and not usedSlots[targetKey] then
        local _, sourceCount, sourceLocked = _G.GetContainerItemInfo(source.bagNum, source.slotNum)
        local _, _, targetLocked = _G.GetContainerItemInfo(target.bagNum, target.slotNum)

        if not sourceLocked and not targetLocked then
          -- Is there anything in the source slot? Check the link, not the count: items with
          -- charges (Wizard Oil, wands...) report their count as minus the number of charges.
          local sourceHasItem = _G.GetContainerItemLink(source.bagNum, source.slotNum) ~= nil
          if not sourceCount or sourceCount < 1 then
            sourceCount = 1
          end
          if sourceHasItem then
            -- Amount to move: the queued amount, but never more than is actually there.
            local count = counts[i]
            if not count or count <= 0 or count > sourceCount then
              count = sourceCount
            end

            -- Try to make stock states and dates make sense (same rules as ProcessMoveQueue()).
            local oldSourceStockState = source.bagshuiStockState
            local oldTargetStockState = target.bagshuiStockState
            if
              oldSourceStockState
              and oldSourceStockState ~= BS_ITEM_STOCK_STATE.NO_CHANGE
              and (
                oldSourceStockState ~= BS_ITEM_STOCK_STATE.DOWN
                or not oldTargetStockState
                or oldTargetStockState == BS_ITEM_STOCK_STATE.NO_CHANGE
              )
            then
              target.bagshuiStockState = oldSourceStockState
            end
            target.bagshuiDate = math.max(source.bagshuiDate or 0, target.bagshuiDate or 0)

            _G.C_Container.MoveItem(source.bagNum, source.slotNum, target.bagNum, target.slotNum, count)
            fired = fired + 1
          end
          -- Done with this move (an empty source means there's nothing left to move).
          usedSlots[sourceKey] = true
          usedSlots[targetKey] = true
          handled = true
        end
      end

      if handled then
        table.remove(sources, i)
        table.remove(targets, i)
        table.remove(counts, i)
        self.moveBatch_done = self.moveBatch_done + 1
        if type(self.moveQueue_onProgress) == "function" then
          self.moveQueue_onProgress(self.moveBatch_done)
        end
      else
        i = i + 1
      end
    end

    if fired > 0 then
      self.moveBatch_retries = 0
      -- Wait for the server to confirm (BAG_UPDATE_DELAYED, see Inventory:OnEvent()),
      -- with a fallback in case that event never arrives.
      self.moveBatch_waiting = true
      Bagshui:QueueClassCallback(self, self.ProcessMoveQueueBatched, 1.0)
      return
    end

    if table.getn(sources) <= 0 then
      -- Everything left was already empty; finish up.
      Bagshui:QueueClassCallback(self, self.ProcessMoveQueueBatched, 0.05)
      return
    end

    -- Nothing could be moved this round (slots still locked). Retry a few times, then give up.
    self.moveBatch_retries = self.moveBatch_retries + 1
    if self.moveBatch_retries > 5 then
      for j = 1, table.getn(sources) do
        Bagshui:ShowAndLogErrorMessage(string.format(L.Error_RestackFailed, sources[j].name or "?"))
      end
      self.moveQueue_success = false
      BsUtil.TableClear(sources)
      BsUtil.TableClear(targets)
      BsUtil.TableClear(counts)
    end
    Bagshui:QueueClassCallback(self, self.ProcessMoveQueueBatched, 0.5)
  end

  --- # 🛑 Do not call directly; use `Inventory:MoveItems()` 🛑.
  --- Recursive item mover with delayed retry on fail.
  --- Utilizes the class properties that are set by `Inventory:MoveItems()`.
  function Inventory:ProcessMoveQueue()
    --self:PrintDebug("Starting ProcessMoveQueue()")

    -- Are we done?
    if table.getn(self.queuedMoveSources) <= 0 then
      --self:PrintDebug("Nothing left to do")
      self:QueueUpdate(0.1)
      -- Trigger callback.
      if type(self.moveQueue_onComplete) == "function" then
        self.moveQueue_onComplete(self.moveQueue_success)
      end
      return
    end

    --self:PrintDebug("starting move # " .. table.getn(self.queuedMoveSources))

    -- Defaults.
    local queueDelay = 0.15
    local thisMoveSucceeded = false

    -- Get info about the current operation.
    local source = self.queuedMoveSources[1]
    local target = self.queuedMoveTargets[1]

    -- Reset retry count.
    if source ~= self.moveQueue_LastSource then
      self.moveRetryCount = 0
    end

    -- Make sure neither item is locked
    -- ClassicAPI's C_Container returns nil for empty slots, otherwise a table with `isLocked`.
    local sourceInfo = _G.C_Container.GetContainerItemInfo(source.bagNum, source.slotNum)
    local targetInfo = _G.C_Container.GetContainerItemInfo(target.bagNum, target.slotNum)
    local sourceLocked = sourceInfo and sourceInfo.isLocked
    local targetLocked = targetInfo and targetInfo.isLocked

    -- Only attempt the move if everything is unlocked
    if not sourceLocked and not targetLocked then
      -- Record stock states so we can revise them.
      local oldSourceStockState = source.bagshuiStockState
      local oldSourceDate = source.bagshuiDate or 0
      local oldTargetStockState = target.bagshuiStockState
      local oldTargetDate = target.bagshuiDate or 0

      -- Set resorting for this inventory and any supplemental storage.
      if self.moveQueue_resort then
        self.forceResort = self.forceResort or self.moveQueue_resort
        if
          type(self.bagSwappingSupplementalStorage) == "table"
          and table.getn(self.bagSwappingSupplementalStorage) > 0
        then
          for _, inventoryClassName in ipairs(self.bagSwappingSupplementalStorage) do
            if Bagshui.components[inventoryClassName] and Bagshui.components[inventoryClassName].online then
              Bagshui.components[inventoryClassName].forceResort = Bagshui.components[inventoryClassName].forceResort
                or self.moveQueue_resort
            end
          end
        end
      end

      -- Do the actual move.
      self:MoveItem(source, target)

      if not _G.CursorHasItem() then
        -- Try to make stock states and dates make sense.
        -- Always copy source stock state over target if the source was new/increased,
        -- but only copy a decreased stock state if the target didn't have a state.
        if
          oldSourceStockState
          and oldSourceStockState ~= BS_ITEM_STOCK_STATE.NO_CHANGE
          and (
            oldSourceStockState ~= BS_ITEM_STOCK_STATE.DOWN
            or (
              oldSourceStockState == BS_ITEM_STOCK_STATE.DOWN
              and (not oldTargetStockState or oldTargetStockState == BS_ITEM_STOCK_STATE.NO_CHANGE)
            )
          )
        then
          target.bagshuiStockState = oldSourceStockState
        end
        target.bagshuiDate = math.max(oldSourceDate, oldTargetDate)

        -- These can come out of the queue now.
        thisMoveSucceeded = true

        -- Reset retry count.
        self.moveRetryCount = 0
      end
    end

    -- Move attempt failed.
    if not thisMoveSucceeded then
      -- Show error message and retry if we haven't reached the limit.
      local baseError = string.format(L.Error_RestackFailed, source.name)

      if (self.moveRetryCount or 0) < 5 then
        -- Longer delay until retry if either item was locked.
        queueDelay = 0.5

        if self.moveRetryCount > 1 then
          Bagshui:ShowErrorMessage(string.format(L.Error_Suffix_Retrying, baseError), self.inventoryType, 1.0, 0.578, 0)
          queueDelay = 1.0
        end

        self.moveRetryCount = self.moveRetryCount + 1
      else
        -- Once we've tried several times, give up on this operation and move to the next one.
        Bagshui:ShowAndLogErrorMessage(baseError)
        self.moveQueue_success = false
        self.moveRetryCount = 0
        thisMoveSucceeded = true
      end
    end

    -- Once we're done with this set, take them out of the queue.
    if thisMoveSucceeded then
      table.remove(self.queuedMoveSources, 1)
      table.remove(self.queuedMoveTargets, 1)
      -- Update progress.
      if type(self.moveQueue_onProgress) == "function" then
        self.moveQueue_onProgress(self.moveQueue_totalItems - table.getn(self.queuedMoveSources))
      end
    end

    -- Queue either the next restack operation or retry the current one.
    -- The check at the beginning of this function will stop things when we're done.
    --self:PrintDebug("Remaining: " .. table.getn(self.queuedMoveSources))
    Bagshui:QueueClassCallback(self, self.ProcessMoveQueue, queueDelay, nil)
  end

  --- Move an item from one place to another, ensuring no modifier keys get in the way.
  ---@param source table Inventory cache entry.
  ---@param target table|number Inventory cache entry *or* bag number, if equipping a bag.
  ---@param onComplete function? Called once the operation is complete with a boolean parameter indicating whether the cursor still has an item.
  function Inventory:MoveItem(source, target, onComplete)
    local doCallback = true

    -- Empty the cursor just in case, since we're technically picking up and putting down items.
    _G.ClearCursor()

    -- Intentionally calling the game's `PickupContainerItem()` instead of `Bagshui:PickupItem()`
    -- because it's immediately picked up and put down, and we don't need (or want) to invoke
    -- `ContainerFrameItemButton_OnClick()` either. As an extra safety measure, force all
    -- modifier keys to return false for the duration of the move since some addons
    -- hook `PickupContainerItem()` and change its behavior when a modifier is pressed.

    local oldIsAltKeyDown = _G.IsAltKeyDown
    local oldIsControlKeyDown = _G.IsControlKeyDown
    local oldIsShiftKeyDown = _G.IsShiftKeyDown
    _G.IsAltKeyDown = BsUtil.ReturnFalse
    _G.IsControlKeyDown = BsUtil.ReturnFalse
    _G.IsShiftKeyDown = BsUtil.ReturnFalse
    _G.PickupContainerItem(source.bagNum, source.slotNum)
    if type(target) == "table" then
      _G.PickupContainerItem(target.bagNum, target.slotNum)
    elseif type(target) == "number" then
      -- This is a bag being put into a bag slot.
      local inventorySlot = _G.ContainerIDToInventoryID(target)
      if target > 4 then
        -- Bank bag slot: the game's own bank bag buttons use PutItemInBag(); EquipCursorItem()
        -- doesn't place bags there.
        _G.PutItemInBag(inventorySlot)
      else
        _G.EquipCursorItem(inventorySlot)
        -- Fallback in case equipping didn't take the bag off the cursor.
        -- (PutItemInBag() does nothing when the cursor is empty.)
        if _G.CursorHasItem() then
          _G.PutItemInBag(inventorySlot)
        end
      end
      -- Might be BOE, so pass callback responsibilities over.
      -- (Could check for BOE but there's really no reason to do so when
      -- WaitForStaticPopupClose() will just invoke the callback immediately
      -- if the BOE dialog doesn't open.)
      BsUtil.WaitForStaticPopupClose(
        "EQUIP_BIND",
        300, -- Five minute wait.
        function(waitSuccess)
          if type(onComplete) == "function" then
            if waitSuccess == false then
              onComplete(false)
            else
              onComplete((not _G.CursorHasItem()))
            end
          end
        end
      )
      -- Callback is handled by WaitForStaticPopupClose().
      doCallback = false
    end
    _G.IsAltKeyDown = oldIsAltKeyDown
    _G.IsControlKeyDown = oldIsControlKeyDown
    _G.IsShiftKeyDown = oldIsShiftKeyDown

    if doCallback and type(onComplete) == "function" then
      onComplete((not _G.CursorHasItem()))
    end
  end

  -- When the bag being swapped in is inside the bag it's replacing, we need
  -- to know where it gets moved to so we can actually equip it.
  local swapBag_sourceItemTracker = {}

  --- Vanilla doesn't allow non-empty bags to be swapped, and manually emptying and
  --- refilling is a pain. Let's make that better.
  --- ### Note about profession bags and swapping.
  --- There doesn't seem to be a way to ask whether an item can go in a container
  --- other than calling `PutItemInBag()` and seeing whether it errors. For this
  --- reason, profession bags are being excluded as valid temporary storage during
  --- bag swapping. (Profession bags themselves can still be swapped.)
  ---@param sourceItem table New bag (entry from inventory cache).
  ---@param bagNum number Bag slot to swap.
  ---@param phase number? Used internally by the swapping process to trigger each phase (empty / swap / fill).
  function Inventory:SwapBag(sourceItem, bagNum, phase, force)
    if type(sourceItem) ~= "table" or sourceItem.emptySlot == 1 or not BsItemInfo:IsContainer(sourceItem) then
      -- If this is the initial call and the item isn't a bag, error out.
      -- After that, jump straight to refilling the original bag.
      if (phase or 1) == 1 then
        Bagshui:ShowErrorMessage(_G.BAG_NOT_EQUIPPABLE, nil, nil, nil, nil, nil, nil, false, true)
        return
      else
        phase = 3
      end
    end

    if (phase or 1) == 1 then
      -- PHASE 1: Empty the old bag.

      -- Total steps is:
      --   Number of items in the bag being emptied
      -- + 1 (Equip the new bag)
      -- + Number of items to put back in the new bag
      self.swapBag_totalSteps = self.containers[bagNum].slotsFilled * 2 + 1
      -- Phase 2 waits for the emptied bag to be confirmed (see below).
      self.swapBag_emptyWaits = 0
      -- Consumed by `Inventory:UpdateSwapBagProgress()`.
      self.swapBag_currentStep = 0

      -- In case the bag was inside the bag we're swapping, we'll need to know its
      -- new location so we can actually equip it.
      swapBag_sourceItemTracker[1] = sourceItem

      self:EmptyBag(
        bagNum,
        swapBag_sourceItemTracker,
        -- Completion callback.
        function(success)
          if success == false or type(success) == "string" then
            Bagshui:ShowErrorMessage(type(success) == "string" and success or L.Error_BagSwap_EmptyOldFailed)
            self:UpdateSwapBagProgress(bagNum)
            -- Try to put things back.
            self:SwapBag(sourceItem, bagNum, 3)
            return
          end

          -- Need a slight delay here so the cache has time to catch up.
          Bagshui:QueueClassCallback(self, self.SwapBag, 0.15, nil, swapBag_sourceItemTracker[1], bagNum, 2)
        end,
        -- Progress callback.
        function()
          self:UpdateSwapBagProgress(bagNum)
        end
      )
    elseif phase == 2 then
      -- PHASE 2: Equip the new bag.

      -- The old bag has to be empty on the server before the new one can go in. Instant moves
      -- (especially out of the bank) can take a moment to be confirmed, so wait up to ~3 seconds.
      if not self:ContainerIsEmpty(bagNum) and (self.swapBag_emptyWaits or 0) < 12 then
        self.swapBag_emptyWaits = (self.swapBag_emptyWaits or 0) + 1
        Bagshui:QueueClassCallback(self, self.SwapBag, 0.25, nil, sourceItem, bagNum, 2)
        return
      end
      self.swapBag_emptyWaits = 0

      self:EquipBag(
        sourceItem,
        bagNum,
        -- Completion callback.
        function(success)
          if success == false or type(success) == "string" then
            Bagshui:ShowErrorMessage(type(success) == "string" and success or L.Error_BagSwap_EquipNewFailed)
          end
          self:UpdateSwapBagProgress(bagNum)
          -- Always put things back even if the equip attempt failed.
          self:SwapBag(sourceItem, bagNum, 3)
        end
      )
    elseif phase == 3 then
      -- PHASE 3: Fill the new bag.

      Bagshui:QueueClassCallback(
        self,
        self.FillBag,
        0.15,
        nil,
        bagNum,
        self.tempMoveTargets,
        -- Completion callback.
        function()
          BsUtil.TableClear(self.tempMoveTargets)
          self:UpdateSwapBagProgress(bagNum, true)
          self.forceResort = true
          -- Need to use QueueUpdate() here to ensure forceResort is consumed properly
          -- with the other window changes that are going to be happening at the same time.
          self:QueueUpdate()
        end,
        -- Progress callback.
        function()
          self:UpdateSwapBagProgress(bagNum)
        end
      )
    end
  end

  --- Does the game report the container as having no items in it?
  ---@param bagNum number Container to check.
  ---@return boolean
  function Inventory:ContainerIsEmpty(bagNum)
    for slotNum = 1, (_G.GetContainerNumSlots(bagNum) or 0) do
      if _G.GetContainerItemLink(bagNum, slotNum) then
        return false
      end
    end
    return true
  end

  --- Increment the progress indicator to show how far along the bag swap is.
  --- Always call with `done = true` at the end of the swap to ensure the progress indicator is hidden.
  ---@param bagNum number Bag slot being swapped.
  ---@param done boolean? Swap is complete.
  function Inventory:UpdateSwapBagProgress(bagNum, done)
    if done then
      self.temporarilyShowBagBar = false
      self.ui.buttons.bagSlots[self.myContainerIds[bagNum]].bagshuiData.progressPercent = 100
    else
      -- We're using the bag bar and cooldown to display progress.
      if not self.temporarilyShowBagBar then
        self.temporarilyShowBagBar = true
        self:UpdateWindow()
      end
      self.swapBag_currentStep = self.swapBag_currentStep + 1
      self.ui.buttons.bagSlots[self.myContainerIds[bagNum]].bagshuiData.progressPercent = self.swapBag_currentStep
        / self.swapBag_totalSteps
        * 100
    end
  end

  -- Used to determine whether there are enough free slots to empty a bag.
  -- (Reusable table for `Inventory:EmptyBag()`.)
  local emptyBag_potentialAvailableSlots = {}

  -- Items from the bag being emptied that go to specialty bags: { [item] = target slot }.
  -- (Reusable tables for `Inventory:EmptyBag()` and `Inventory:GetAdditionalSlotsNeededToSwapBag()`.)
  local emptyBag_specialtyAssignments = {}
  local slotsNeeded_specialtyAssignments = {}
  local assignSpecialty_items = {}
  local assignSpecialty_usedSlots = {}

  --- Do the two bag family bitmasks share a bit? (No bitwise operators in Lua 5.0.)
  ---@param a number
  ---@param b number
  ---@return boolean
  local function FamiliesOverlap(a, b)
    local bitValue = 1
    while bitValue <= a and bitValue <= b do
      if math.mod(math.floor(a / bitValue), 2) == 1 and math.mod(math.floor(b / bitValue), 2) == 1 then
        return true
      end
      bitValue = bitValue * 2
    end
    return false
  end

  --- ClassicAPI's C_Item.GetItemFamily() tells which specialty bags an item or a bag belongs to.
  ---@return boolean
  local function SpecialtyBagsSupported()
    return type(_G.C_Item) == "table" and type(_G.C_Item.GetItemFamily) == "function"
  end

  --- Bag family bitmask of the bag in a container slot (0 = general-purpose or no bag).
  --- Specialty bags: quiver, ammo pouch, soul, herb, enchanting, engineering, and Turtle's
  --- meat/fish/leather/mining bags.
  ---@param containerId number
  ---@return number
  function Inventory:GetBagFamily(containerId)
    if not SpecialtyBagsSupported() or containerId <= 0 then
      return 0
    end
    local bagLink = _G.GetInventoryItemLink("player", _G.ContainerIDToInventoryID(containerId))
    return bagLink and _G.C_Item.GetItemFamily(bagLink) or 0
  end

  --- Bag family bitmask of an item (0 = goes in general-purpose bags only).
  ---@param itemLinkOrId string|number?
  ---@return number
  local function GetItemFamilyOf(itemLinkOrId)
    if not itemLinkOrId or not SpecialtyBagsSupported() then
      return 0
    end
    return _G.C_Item.GetItemFamily(itemLinkOrId) or 0
  end

  -- Reusable tables for `Inventory:FindSpecialtyBagMoves()`.
  local specialtyMoves_freeSlots = {}
  local specialtyMoves_freeFamilies = {}

  --- Find items in this inventory's general-purpose bags that fit a free slot in one of its
  --- specialty bags (herbs and an herb bag, soul shards and a soul bag...).
  ---@param queueMoves boolean? Also queue the moves for `Inventory:MoveItems()`.
  ---@return integer moves How many items could be moved.
  function Inventory:FindSpecialtyBagMoves(queueMoves)
    if not SpecialtyBagsSupported() or not self.online then
      return 0
    end

    -- Free slots in specialty bags.
    BsUtil.TableClear(specialtyMoves_freeSlots)
    BsUtil.TableClear(specialtyMoves_freeFamilies)
    for _, containerId in ipairs(self.containerIds) do
      local bagFamily = self:GetBagFamily(containerId)
      if bagFamily > 0 and self.inventory[containerId] then
        for slotNum = 1, (_G.GetContainerNumSlots(containerId) or 0) do
          if self.inventory[containerId][slotNum] and not _G.GetContainerItemLink(containerId, slotNum) then
            table.insert(specialtyMoves_freeSlots, self.inventory[containerId][slotNum])
            table.insert(specialtyMoves_freeFamilies, bagFamily)
          end
        end
      end
    end
    local freeCount = table.getn(specialtyMoves_freeSlots)
    if freeCount == 0 then
      return 0
    end

    -- Items in general-purpose bags that fit one of them.
    local moves = 0
    for _, containerId in ipairs(self.containerIds) do
      if self:GetBagFamily(containerId) == 0 and self.inventory[containerId] then
        for slotNum = 1, (_G.GetContainerNumSlots(containerId) or 0) do
          local item = self.inventory[containerId][slotNum]
          local itemLink = _G.GetContainerItemLink(containerId, slotNum)
          -- Bags report the family of what they hold, but can't go in a specialty bag.
          if item and itemLink and not BsItemInfo:IsContainer(item) then
            local itemFamily = GetItemFamilyOf(itemLink)
            if itemFamily > 0 then
              for i = 1, freeCount do
                if specialtyMoves_freeSlots[i] and FamiliesOverlap(itemFamily, specialtyMoves_freeFamilies[i]) then
                  if queueMoves then
                    self:QueueMove(item, specialtyMoves_freeSlots[i])
                  end
                  specialtyMoves_freeSlots[i] = false
                  moves = moves + 1
                  break
                end
              end
            end
          end
        end
      end
    end

    BsUtil.TableClear(specialtyMoves_freeSlots)
    BsUtil.TableClear(specialtyMoves_freeFamilies)
    return moves
  end

  --- Choose free specialty-bag slots for the items in `bagNum` that fit them, so those items don't
  --- need general-purpose space during a bag swap. Own specialty bags are used first; those of
  --- supplemental storage (bank/bags) only when general-purpose space here runs short.
  ---@param bagNum number Container being emptied.
  ---@param assignments table Filled with `{ [item] = target slot }`.
  ---@return integer remaining Items that still need a general-purpose slot.
  function Inventory:AssignSpecialtySlots(bagNum, assignments)
    BsUtil.TableClear(assignments)
    BsUtil.TableClear(assignSpecialty_items)
    BsUtil.TableClear(assignSpecialty_usedSlots)

    -- Items that have to come out, with their family.
    for _, item in ipairs(self.inventory[bagNum] or {}) do
      if item.emptySlot ~= 1 then
        table.insert(assignSpecialty_items, item)
      end
    end
    local remaining = table.getn(assignSpecialty_items)
    if remaining == 0 or not SpecialtyBagsSupported() then
      return remaining
    end

    local function assignFrom(inventoryClass)
      for _, containerId in ipairs(inventoryClass.containerIds) do
        if remaining <= 0 then
          return
        end
        local bagFamily = (containerId ~= bagNum) and inventoryClass:GetBagFamily(containerId) or 0
        if bagFamily > 0 and inventoryClass.inventory[containerId] then
          for slotNum = 1, (_G.GetContainerNumSlots(containerId) or 0) do
            local slot = inventoryClass.inventory[containerId][slotNum]
            if slot and not assignSpecialty_usedSlots[slot] and not _G.GetContainerItemLink(containerId, slotNum) then
              -- First item that hasn't been placed yet and fits this bag.
              for _, item in ipairs(assignSpecialty_items) do
                if
                  not assignments[item]
                  -- Bags report the family of what they hold, but can't go in a specialty bag.
                  and not BsItemInfo:IsContainer(item)
                  and FamiliesOverlap(GetItemFamilyOf(item.itemLink or item.id), bagFamily)
                then
                  assignments[item] = slot
                  assignSpecialty_usedSlots[slot] = true
                  remaining = remaining - 1
                  break
                end
              end
            end
          end
        end
      end
    end

    assignFrom(self)

    if remaining > self:GetAdjustedEmptySlotCount(bagNum) and type(self.bagSwappingSupplementalStorage) == "table" then
      for _, inventoryClassName in ipairs(self.bagSwappingSupplementalStorage) do
        local supplemental = Bagshui.components[inventoryClassName]
        if supplemental and supplemental.online then
          assignFrom(supplemental)
        end
      end
    end

    return remaining
  end

  --- Remove all items from a bag.
  --- Automatically backs up the new locations to `Inventory.tempMoveTargets`.
  ---@param bagNum number Container to empty.
  ---@param itemsToTrack table? Array of cache items to find the future position of if they move.
  ---@param onComplete function? Completion callback (will be called from `Inventory:MoveItems()`).
  ---@param onProgress function? Per-move callback (will be called from `Inventory:MoveItems()`).
  function Inventory:EmptyBag(bagNum, itemsToTrack, onComplete, onProgress)
    if not self.containers[bagNum] then
      return
    end

    -- We're going to make things simpler by just working with the list of all empty
    -- slots and skipping the ones that belong to the bag being emptied in the
    -- loop where we fill `queuedMoveSources/Targets`.
    BsUtil.TableCopyFlat(self.emptyGenericContainerSlots, emptyBag_potentialAvailableSlots)

    -- Items that fit a specialty bag (herbs, soul shards, arrows...) go to one first.
    local itemsNeedingGeneralSlots = self:AssignSpecialtySlots(bagNum, emptyBag_specialtyAssignments)

    -- Find out how much free space there is, excluding the bag being emptied.
    local availableEmptySlotCount = self:GetAdjustedEmptySlotCount(bagNum)

    -- Extra space is needed. See if we can find any.
    if itemsNeedingGeneralSlots > availableEmptySlotCount then
      availableEmptySlotCount = availableEmptySlotCount
        + self:GetSupplementalEmptySlotCount(emptyBag_potentialAvailableSlots)
    end

    -- Before going any further, make sure there's enough space.
    -- This is a variable instead of being in the `if` just below because it
    -- needs to be updated if we run out of slots in `emptyBag_potentialAvailableSlots`.
    local readyToEmpty = itemsNeedingGeneralSlots <= availableEmptySlotCount

    if readyToEmpty then
      -- Reset queues used by `Inventory:ProcessMoveQueue()`
      self:ClearMoveQueue()

      -- We'll need to iterate through `emptyGenericContainerSlots` to find the
      -- next one that doesn't belong to this bag.
      local nextTargetSlotIndex = 0
      local nextTargetSlot

      -- Find a corresponding empty slot for every item in this bag.
      for _, item in ipairs(self.inventory[bagNum]) do
        if item.emptySlot ~= 1 then
          local targetSlot = emptyBag_specialtyAssignments[item]
          if not targetSlot then
            repeat
              nextTargetSlotIndex = nextTargetSlotIndex + 1
              nextTargetSlot = emptyBag_potentialAvailableSlots[nextTargetSlotIndex]
            until not nextTargetSlot or nextTargetSlot.bagNum ~= bagNum
            targetSlot = nextTargetSlot
          end
          if not targetSlot then
            -- This hopefully shouldn't be hit but just in case.
            readyToEmpty = false
            break
          end
          -- Update tracking.
          if type(itemsToTrack) == "table" then
            for i = 1, table.getn(itemsToTrack) do
              if itemsToTrack[i] == item then
                itemsToTrack[i] = targetSlot
              end
            end
          end
          -- Instructions for MoveItems().
          self:QueueMove(item, targetSlot)
        end
      end
    end

    -- Are we good to go?
    if readyToEmpty then
      -- Make items available for refilling.
      BsUtil.TableCopyFlat(self.queuedMoveTargets, self.tempMoveTargets)

      -- Move! Those! Items!
      self:MoveItems(onComplete, onProgress, true)

      -- No need to hold onto these.
      BsUtil.TableClear(emptyBag_potentialAvailableSlots)
      BsUtil.TableClear(emptyBag_specialtyAssignments)
    else
      -- Failure state.
      self:ClearMoveQueue()

      local errorMessage = (self:GetBagSlotSwappableText(bagNum, true) or L.Error_BagSwap_EmptyOldInsufficientSpace)

      if type(onComplete) == "function" then
        onComplete(errorMessage)
      else
        Bagshui:ShowErrorMessage(errorMessage)
      end
    end
  end

  --- Move the given list of items into a different bag.
  ---@param bagNum number Bag into which the items should be placed.
  ---@param items table[] Array of inventory cache entries.
  ---@param onComplete function? Completion callback (will be called from `Inventory:MoveItems()`).
  ---@param onProgress function? Per-move callback (will be called from `Inventory:MoveItems()`).
  function Inventory:FillBag(bagNum, items, onComplete, onProgress)
    if not self.inventory[bagNum] then
      return
    end

    BsUtil.TableCopyFlat(items, self.queuedMoveSources)
    BsUtil.TableCopyFlat(self.inventory[bagNum], self.queuedMoveTargets)

    -- The new bag is a specialty bag: only bring back the items that fit it.
    local newBagFamily = self:GetBagFamily(bagNum)
    if newBagFamily > 0 then
      for i = table.getn(self.queuedMoveSources), 1, -1 do
        local source = self.queuedMoveSources[i]
        if not FamiliesOverlap(GetItemFamilyOf(_G.GetContainerItemLink(source.bagNum, source.slotNum)), newBagFamily) then
          table.remove(self.queuedMoveSources, i)
        end
      end
    end
    -- Whole stacks (no per-move amounts).
    BsUtil.TableClear(self.queuedMoveCounts)

    -- Prune source table if there aren't enough slots in the destination.
    if table.getn(self.queuedMoveSources) > table.getn(self.queuedMoveTargets) then
      for i = table.getn(self.queuedMoveSources), table.getn(self.queuedMoveTargets) + 1, -1 do
        table.remove(self.queuedMoveSources, i)
      end
    end

    self:MoveItems(onComplete, onProgress, true)
  end

  --- Equip a bag.
  ---@param item table Inventory cache entry of the bag to be equipped.
  ---@param bagNum number Bag slot into which the bag will be placed.
  ---@param onComplete function? Success/failure callback.
  function Inventory:EquipBag(item, bagNum, onComplete)
    self:MoveItem(item, bagNum, onComplete)
  end

  --- Find the count of free bag slots, less those belonging to `excludeBagNum` and
  --- any profession bags.
  ---@param excludeBagNum number? Bag to omit.
  ---@return integer emptySlots
  function Inventory:GetAdjustedEmptySlotCount(excludeBagNum)
    local availableEmptySlotCount = 0
    for containerNum, container in pairs(self.containers) do
      if
        containerNum ~= excludeBagNum
        and container.numSlots > 0
        and container.slotsFilled < container.numSlots
        -- Generic bags only (no profession bags). It's too hard to know what
        -- is allowed in a container without trying it, so we're just going
        -- to ignore profession bags as swap targets.
        and container.genericType == BsGameInfo.itemSubclasses["Container"]["Bag"]
      then
        availableEmptySlotCount = availableEmptySlotCount + (container.numSlots - container.slotsFilled)
      end
    end
    return availableEmptySlotCount
  end

  -- Reusable table for `Inventory:GetSupplementalEmptySlotCount()`.
  local getSupplementalEmptySlotCount_inventoriesChecked = {}

  --- Determine how many slots are available in other inventories to help with bag swapping.
  ---@param availableSlotTable table? Array to which additional slots should be added.
  ---@return integer availableEmptySlotCount
  ---@return table<string,true> inventoriesChecked Other inventory classes that were checked for available slots.
  function Inventory:GetSupplementalEmptySlotCount(availableSlotTable)
    local availableEmptySlotCount = 0
    BsUtil.TableClear(getSupplementalEmptySlotCount_inventoriesChecked)
    if
      -- Other inventory classes that can be used during swapping are configured in this property.
      type(self.bagSwappingSupplementalStorage) == "table" and table.getn(self.bagSwappingSupplementalStorage) > 0
    then
      for _, inventoryClassName in ipairs(self.bagSwappingSupplementalStorage) do
        local supplemental = Bagshui.components[inventoryClassName]
        if supplemental and supplemental.online then
          if table.getn(supplemental.emptyGenericContainerSlots) > 0 then
            availableEmptySlotCount = availableEmptySlotCount + table.getn(supplemental.emptyGenericContainerSlots)
            if availableSlotTable then
              for _, slot in ipairs(supplemental.emptyGenericContainerSlots) do
                table.insert(emptyBag_potentialAvailableSlots, slot)
              end
            end
          end
          getSupplementalEmptySlotCount_inventoriesChecked[inventoryClassName] = true
        end
      end
    end
    return availableEmptySlotCount, getSupplementalEmptySlotCount_inventoriesChecked
  end

  --- Calculate how many more slots are required before a swap of the specified bag can be performed.
  ---@param bagNum number Container to check.
  ---@return integer slotsNeeded
  ---@return table<string, true>? inventoriesChecked Second return value from `Inventory:GetSupplementalEmptySlotCount()`.
  function Inventory:GetAdditionalSlotsNeededToSwapBag(bagNum)
    -- Items that fit a free specialty-bag slot don't need general-purpose space.
    local filledSlots = self:AssignSpecialtySlots(bagNum, slotsNeeded_specialtyAssignments)
    BsUtil.TableClear(slotsNeeded_specialtyAssignments)

    if filledSlots == 0 then
      return 0
    end

    local availableEmptySlots = self:GetAdjustedEmptySlotCount(bagNum)

    if availableEmptySlots >= filledSlots then
      return 0
    end

    local supplementalEmptySlots, inventoriesChecked = self:GetSupplementalEmptySlotCount()

    if availableEmptySlots + supplementalEmptySlots >= filledSlots then
      return 0, inventoriesChecked
    end

    return (filledSlots - availableEmptySlots - supplementalEmptySlots), inventoriesChecked
  end

  --- Error-triggered bag swapping (as opposed to native bag swapping via a Bagshui
  --- bag slot button's OnClick). This allows Bagshui to perform bag swaps even
  --- if the equip action is invoked via the main action bar or any other method.
  ---
  --- Methodology based on Swapper by Gabriele Cimolino
  --- https://github.com/cubenicke/Swapper
  ---@param wowApiFunctionName any
  ---@param event any
  ---@param message any
  function Inventory:UIErrorsFrame_OnEvent(wowApiFunctionName, event, message)
    if event == "UI_ERROR_MESSAGE" and message == _G.TEXT(_G.ERR_DESTROY_NONEMPTY_BAG) then
      local newBag, bagSlot

      -- Find the bag that needs to be equipped.
      for _, bagContents in pairs(self.inventory) do
        for __, item in ipairs(bagContents) do
          if item.locked == 1 then
            newBag = item
          end
        end
      end

      -- Find the slot into which it should be put.
      for _, containerId in ipairs(self.containerIds) do
        if _G.IsInventoryItemLocked(_G.ContainerIDToInventoryID(containerId)) then
          bagSlot = containerId
        end
      end

      -- Suppress the error and do the swap.
      if newBag and bagSlot then
        self:SwapBag(newBag, bagSlot)
        -- Can't just return here or it seems to break things, so
        -- we'll blank the message instead.
        message = ""
      end
    end
    self.hooks:OriginalHook(wowApiFunctionName, event, message)
  end
end)
