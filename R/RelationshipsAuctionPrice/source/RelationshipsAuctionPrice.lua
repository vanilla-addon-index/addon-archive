--[[ RelationshipsAuctionPrice
     Fast AH scanner + tooltip showing prices high->low.
     Slash: /rap scan | /rap fast | /rap stop | /rap clear | /rap show <id> | /rap stats
            /rap name <substr>       -> next scan only matches this name
            /rap class <index|clear> -> next scan filters by class index
            /rap export              -> dumps PriceData.lua-shaped string to SavedVariables
]]--

RelationshipsAuctionPriceDB = RelationshipsAuctionPriceDB or { items = {}, lastScan = 0, realm = nil }

local db
local scanning    = false
local scanPage    = 0
local scanStart   = 0
local scanMode    = "full"
local pendingQuery = false
local queryTime   = 0
local scanSeen    = 0
local scanSaved   = 0
local scanNoLink  = 0
local scanNoBuyout = 0
local scanExpectedTotal = 0
local NUM_PER_PAGE = 50
local THROTTLE    = 0.35
local MAX_WAIT    = 20.0
local MAX_RETRIES = 3
local scanRetries = 0

-- current scan filter (rebuilt on BeginScan)
local filterName     = ""     -- substring; "" = any
local filterClass    = nil    -- class index into {GetAuctionItemClasses()} or nil
local filterSubclass = nil
local filterQuality  = 0      -- 0 = any (poor+)
local filterMinLvl   = nil
local filterMaxLvl   = nil

-- ============ USER CONFIG: AH UI layout ================================
-- The addon lives in its own little panel that attaches just above the
-- Auction House frame. Tweak the panel to move the whole box; tweak the
-- child elements to nudge things inside the box.
--
-- Anchor points: "TOPLEFT","TOP","TOPRIGHT","LEFT","CENTER","RIGHT",
--                "BOTTOMLEFT","BOTTOM","BOTTOMRIGHT"
-- relativeTo   : "AuctionFrame" | "panel" | "scanBtn" | "classDD" | "nameBox"
-- x, y         : pixel offset (positive x = right, positive y = up)
--
-- After editing, /reload in-game.
RAP_UI_CONFIG = {
  panel = {                    -- the little box attached above the AH
    point         = "BOTTOMRIGHT",
    relativeTo    = "AuctionFrame",
    relativePoint = "TOPRIGHT",
    x = 1.5, y = -17,          -- negative y overlaps onto the AH top so the box "connects"
    width = 403.1, height = 68,
    padding = 0.5,
 
    bgColor     = { 0.20, 0.19, 0.16, 90.00 },
    borderColor = { 0.85, 0.85, 0.87, 5.00 },
  },
  scanButton = {
    point         = "RIGHT",
    relativeTo    = "panel",
    relativePoint = "RIGHT",
    x = -13, y = 2,
    width = 70, height = 22,
  },
  classDropdown = {
    point         = "RIGHT",
    relativeTo    = "scanBtn",
    relativePoint = "LEFT",
    x = -7, y = -2,
    width = 120,               -- dropdown menu width
  },
  nameBox = {
    point         = "RIGHT",
    relativeTo    = "classDD",
    relativePoint = "LEFT",
    x = -8, y = 2,
    width = 120, height = 20,
  },
  nameLabel = {                -- "Name filter" caption under the name box, centered
    point         = "TOP",
    relativeTo    = "nameBox",
    relativePoint = "BOTTOM",
    x = -3, y = -5,
    text = "Name filter",
  },
  statusText = {               -- status line under the scan button
    point         = "TOPRIGHT",
    relativeTo    = "scanBtn",
    relativePoint = "BOTTOMRIGHT",
    x = -11, y = -5,
  },
}
-- =======================================================================

-- ============ util =====================================================

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffRAP|r: "..tostring(msg))
end

local function ItemIDFromLink(link)
  if not link then return nil end
  local _,_,id = string.find(link, "item:(%d+)")
  if id then return tonumber(id) end
  return nil
end

local function GetRealmKey()
  local r = GetRealmName() or "Unknown"
  local f = (UnitFactionGroup and UnitFactionGroup("player")) or "N"
  return r.."-"..string.sub(f,1,1)
end

local function EnsureRealm()
  local key = GetRealmKey()
  if db.realm ~= key then
    db.realm = key
    db.items = db.items or {}
  end
  db.items[key] = db.items[key] or {}
  return db.items[key]
end

local function FmtMoney(c)
  if not c or c <= 0 then return "0c" end
  local g = floor(c / 10000)
  local s = floor(mod(c, 10000) / 100)
  local cc = mod(c, 100)
  local out = ""
  if g > 0 then out = out..g.."|cffffd700g|r " end
  if s > 0 or g > 0 then out = out..s.."|cffc7c7cfs|r " end
  out = out..cc.."|cffeda55fc|r"
  return out
end

-- ============ storage ==================================================

local function StorePriceIn(store, itemID, buyout, count, seller)
  if not store or not itemID or not buyout or buyout <= 0 or not count or count <= 0 then return false end
  store[itemID] = store[itemID] or { scans = {} }
  local unit = floor(buyout / count)
  table.insert(store[itemID].scans, { u = unit, q = count, s = seller or "?" })
  return true
end

local function StorePrice(itemID, buyout, count, seller)
  return StorePriceIn(EnsureRealm(), itemID, buyout, count, seller)
end

-- Filtered scans replace only the touched items. Full scans are written to a
-- temporary buffer first, then swapped in only when the scan completes cleanly.
-- This prevents a failed full scan from wiping good saved data into empty shells.
local scanTouched -- set of itemIDs seen this scan when filtered
local scanFull
local scanBuffer
local scanResume -- true when the current run is resuming a prior scan

local function BeginScanStorage()
  scanTouched = {}
  scanFull = (filterName == "" and not filterClass and filterQuality == 0
              and not filterMinLvl and not filterMaxLvl)
  if scanResume then
    -- resuming: append directly to the saved store. No wholesale wipe,
    -- no per-item wipe. Duplicated rows on the boundary page are possible
    -- but harmless (same market snapshot).
    scanFull = false
    scanTouched = nil
    scanBuffer = nil
  elseif scanFull then
    scanBuffer = {}
  else
    scanBuffer = nil
  end
end

local function StorePriceFiltered(itemID, buyout, count, seller)
  if not itemID then return false end
  if scanFull and scanBuffer then
    return StorePriceIn(scanBuffer, itemID, buyout, count, seller)
  end
  local store = EnsureRealm()
  if scanTouched and not scanTouched[itemID] then
    -- first time this scan sees this id under a filter -> wipe its old rows
    if store[itemID] then store[itemID].scans = {} end
    scanTouched[itemID] = true
  end
  return StorePrice(itemID, buyout, count, seller)
end

local function CountRowsInStore(store)
  local itemCount = 0
  local listingCount = 0
  if not store then return 0, 0 end
  for id, entry in pairs(store) do
    local n = 0
    if entry.scans then n = table.getn(entry.scans) end
    if n > 0 then
      itemCount = itemCount + 1
      listingCount = listingCount + n
    end
  end
  return itemCount, listingCount
end

local function FinalizeScan(success)
  local key = GetRealmKey()
  local store
  if scanFull and scanBuffer then
    if success then
      -- clean full scan: buffer replaces prior data wholesale
      db.items[key] = scanBuffer
      store = scanBuffer
    else
      -- partial/failed full scan: merge what we DID scan into existing
      -- store so nothing that was captured this run is lost. Items we
      -- didn't reach keep their previous prices.
      store = db.items[key] or {}
      db.items[key] = store
      for id, entry in pairs(scanBuffer) do
        if entry.scans and table.getn(entry.scans) > 0 then
          store[id] = entry
        end
      end
    end
  else
    store = EnsureRealm()
  end
  for id, entry in pairs(store) do
    if entry.scans and table.getn(entry.scans) > 0 then
      table.sort(entry.scans, function(a,b) return a.u > b.u end)
      entry.updated = time()
    end
  end
  if success then
    db.lastScan = time()
    db.resume = nil -- clean finish clears any resume checkpoint
  end
  local itemCount, listingCount = CountRowsInStore(store)
  scanTouched = nil
  scanBuffer = nil
  scanFull = nil
  scanResume = nil
  return itemCount, listingCount
end

-- Save a resume checkpoint. Called after every successfully-read page so
-- the next `/rap continue` picks up right where we stopped.
local function SaveResumeCheckpoint()
  if not db then return end
  db.resume = {
    page          = scanPage + 1, -- next page to fetch
    mode          = scanMode,
    filterName    = filterName,
    filterClass   = filterClass,
    filterSubclass = filterSubclass,
    filterQuality = filterQuality,
    filterMinLvl  = filterMinLvl,
    filterMaxLvl  = filterMaxLvl,
    expectedTotal = scanExpectedTotal,
    savedAt       = time(),
  }
end

-- ============ shared data (PriceData.lua) ==============================

local function GetSharedRows(itemID)
  if not RAP_SHARED_DATA then return nil end
  local realm = RAP_SHARED_DATA[GetRealmKey()]
  if not realm or not realm.items then return nil end
  return realm.items[itemID], realm.updated
end

local function GetMergedRows(itemID)
  local out = {}
  local sharedRows, sharedUpdated = GetSharedRows(itemID)
  if sharedRows then
    for i=1, table.getn(sharedRows) do
      local r = sharedRows[i]
      table.insert(out, { u = r.u, q = r.q, src = "shared" })
    end
  end
  local store = db.items[GetRealmKey()]
  local localUpdated
  if store and store[itemID] and store[itemID].scans then
    localUpdated = store[itemID].updated
    for i=1, table.getn(store[itemID].scans) do
      local r = store[itemID].scans[i]
      table.insert(out, { u = r.u, q = r.q, src = "local" })
    end
  end
  if table.getn(out) == 0 then return nil end
  table.sort(out, function(a,b) return a.u > b.u end)
  return out, localUpdated, sharedUpdated
end

-- ============ tooltip ==================================================

local function TooltipAlreadyHasRAP(tt)
  local n = tt:NumLines()
  if not n or n <= 0 then return false end
  local name = tt:GetName()
  for i=1, n do
    local fs = getglobal(name.."TextLeft"..i)
    local txt = fs and fs:GetText()
    if txt and string.find(txt, "AH Prices", 1, true) then
      return true
    end
  end
  return false
end

local function AddTooltipLines(tt, itemID)
  if TooltipAlreadyHasRAP(tt) then return end
  local rows, localUpdated, sharedUpdated = GetMergedRows(itemID)
  if not rows then return end

  tt:AddLine(" ")
  tt:AddLine("|cff66ccffAH Prices|r")

  -- Collect unique prices (rows are already sorted high -> low)
  local unique = {}
  local seen = {}
  for i=1, table.getn(rows) do
    local r = rows[i]
    if not seen[r.u] then
      seen[r.u] = true
      table.insert(unique, r)
    end
  end

  local n = table.getn(unique)
  local picks = {}
  if n == 1 then
    picks = { { label = "Price",  row = unique[1] } }
  elseif n == 2 then
    picks = {
      { label = "High", row = unique[1] },
      { label = "Low",  row = unique[2] },
    }
  elseif n >= 3 then
    local midIdx = floor((n + 1) / 2)
    picks = {
      { label = "High", row = unique[1] },
      { label = "Mid",  row = unique[midIdx] },
      { label = "Low",  row = unique[n] },
    }
  end

  for i=1, table.getn(picks) do
    local p = picks[i]
    local r = p.row
    local tag = (r.src == "shared") and " |cff888888(shared)|r" or ""
    tt:AddDoubleLine(
      "  "..p.label..tag,
      FmtMoney(r.u).." ea",
      0.8,0.9,1, 1,1,1
    )
  end
  if localUpdated then
    local mins = floor((time() - localUpdated) / 60)
    tt:AddLine("  local scan "..mins.."m ago", 0.6,0.6,0.6)
  end
  if sharedUpdated then
    local hrs = floor((time() - sharedUpdated) / 3600)
    tt:AddLine("  shared data "..hrs.."h old", 0.5,0.5,0.5)
  end
  tt:Show()
end

local function HookTip(tt)
  local orig_SetHyperlink = tt.SetHyperlink
  tt.SetHyperlink = function(self, link)
    orig_SetHyperlink(self, link)
    local id = ItemIDFromLink(link)
    if id then AddTooltipLines(self, id) end
  end
end

local function InstallTooltipHooks()
  HookTip(GameTooltip)
  if ItemRefTooltip then HookTip(ItemRefTooltip) end

  local orig_ContainerFrameItemButton_OnEnter = ContainerFrameItemButton_OnEnter
  ContainerFrameItemButton_OnEnter = function()
    orig_ContainerFrameItemButton_OnEnter()
    local bag = this:GetParent():GetID()
    local slot = this:GetID()
    local link = GetContainerItemLink(bag, slot)
    local id = ItemIDFromLink(link)
    if id then AddTooltipLines(GameTooltip, id) end
  end

  local orig_PaperDollItemSlotButton_OnEnter = PaperDollItemSlotButton_OnEnter
  if orig_PaperDollItemSlotButton_OnEnter then
    PaperDollItemSlotButton_OnEnter = function()
      orig_PaperDollItemSlotButton_OnEnter()
      local link = GetInventoryItemLink("player", this:GetID())
      local id = ItemIDFromLink(link)
      if id then AddTooltipLines(GameTooltip, id) end
    end
  end

  if MerchantItemButton_OnEnter then
    local orig_MerchantItemButton_OnEnter = MerchantItemButton_OnEnter
    MerchantItemButton_OnEnter = function()
      orig_MerchantItemButton_OnEnter()
      local link = GetMerchantItemLink(this:GetID())
      local id = ItemIDFromLink(link)
      if id then AddTooltipLines(GameTooltip, id) end
    end
  end
end

-- ============ scanner ==================================================

local scanner = CreateFrame("Frame")
scanner:Hide()

local function StartQuery(page)
  scanPage    = page
  pendingQuery = true
  queryTime   = GetTime()
  -- name, minLvl, maxLvl, invType, class, subclass, page, isUsable, qualityIndex
  QueryAuctionItems(
    filterName or "",
    filterMinLvl, filterMaxLvl,
    nil,
    filterClass, filterSubclass,
    page, 0, filterQuality or 0
  )
end

local function ReadCurrentPage()
  local batch, total = GetNumAuctionItems("list")
  if not batch or batch == 0 then return 0, total or 0 end
  for i=1, batch do
    local name, _, count, _, _, _, minBid, minInc, buyout, bidAmount, highBidder, owner =
      GetAuctionItemInfo("list", i)
    scanSeen = scanSeen + 1
    local link = GetAuctionItemLink("list", i)
    local id = ItemIDFromLink(link)
    if not id then
      scanNoLink = scanNoLink + 1
    elseif not buyout or buyout <= 0 then
      scanNoBuyout = scanNoBuyout + 1
    elseif StorePriceFiltered(id, buyout, count or 1, owner) then
      scanSaved = scanSaved + 1
    end
  end
  return batch, total or 0
end

local function StopScan(reason)
  scanning     = false
  pendingQuery = false
  scanner:Hide()
  local ok = (reason == "ok")
  -- We no longer discard a full scan's captured rows just because it
  -- didn't finish cleanly. On a clean finish we swap the buffer in
  -- wholesale; on a partial/failed finish FinalizeScan merges what we DID
  -- capture into the existing saved store, so nothing is lost.
  local itemCount, listingCount = FinalizeScan(ok)
  local elapsed = GetTime() - scanStart
  Print(string.format("scan done (%s) in %.1fs.", reason or "ok", elapsed))
  Print("saved "..listingCount.." listings across "..itemCount.." item IDs. Seen "..scanSeen.." rows; skipped "..scanNoBuyout.." no-buyout, "..scanNoLink.." no-link.")
  if not ok then Print("partial scan: captured rows were merged into your saved data.") end
end

scanner:SetScript("OnUpdate", function()
  if not scanning then return end
  local now = GetTime()
  if pendingQuery then
    if now - queryTime > MAX_WAIT then
      scanRetries = scanRetries + 1
      if scanRetries > MAX_RETRIES then
        Print("page "..scanPage.." timed out after "..MAX_RETRIES.." retries, stopping.")
        StopScan("timeout"); return
      end
      Print("page "..scanPage.." slow, retry "..scanRetries.."/"..MAX_RETRIES.."...")
      pendingQuery = false
      queryTime = now
      if CanSendAuctionQuery() then StartQuery(scanPage) end
      return
    end
    return
  end
  local wait = (scanMode == "fast") and 0.15 or THROTTLE
  if now - queryTime < wait then return end
  if CanSendAuctionQuery() then
    scanRetries = 0
    StartQuery(scanPage + 1)
  end
end)

scanner:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
scanner:SetScript("OnEvent", function()
  if not scanning or not pendingQuery then return end
  pendingQuery = false
  scanRetries = 0
  queryTime = GetTime()
  local batch, total = ReadCurrentPage()
  if total and total > scanExpectedTotal then scanExpectedTotal = total end
  local pagesTotal = ceil(total / NUM_PER_PAGE)
  if scanPage == 0 or (scanResume and scanPage == (db.resume and db.resume.page or scanPage)) then
    Print("scanning "..total.." auctions across "..pagesTotal.." pages...")
  end
  -- Checkpoint after every successfully-read page so /rap continue can
  -- resume from here if the session dies, times out, or is aborted.
  SaveResumeCheckpoint()
  -- Only stop when we've reached the last page currently reported by the
  -- server. Do NOT stop on a short batch alone -- the AH sometimes returns
  -- a short page mid-scan when listings shift; we'd rather query the next
  -- page (which may now exist because new auctions were posted) than bail
  -- out early. If the AH truly ran out of pages, pagesTotal will reflect
  -- that on the next tick and we'll stop then.
  if scanPage >= pagesTotal - 1 then
    if batch < NUM_PER_PAGE then
      StopScan("ok")
    else
      -- last known page was full -- there may be more now, keep going.
    end
  end
end)

local function BeginScan(mode, doResume)
  if scanning then Print("already scanning."); return end
  if not AuctionFrame or not AuctionFrame:IsVisible() then
    Print("open the auction house first."); return
  end

  local resume = doResume and db.resume or nil
  if doResume and not resume then
    Print("no scan to continue. Start one with /rap scan.")
    return
  end

  if resume then
    -- restore filters from the checkpoint
    filterName     = resume.filterName or ""
    filterClass    = resume.filterClass
    filterSubclass = resume.filterSubclass
    filterQuality  = resume.filterQuality or 0
    filterMinLvl   = resume.filterMinLvl
    filterMaxLvl   = resume.filterMaxLvl
    scanMode  = resume.mode or "full"
    scanPage  = (resume.page or 0) - 1
    scanExpectedTotal = resume.expectedTotal or 0
    scanResume = true
  else
    scanMode  = mode or "full"
    scanPage  = -1
    scanExpectedTotal = 0
    scanResume = nil
  end

  scanning  = true
  scanStart = GetTime()
  queryTime = 0
  pendingQuery = false
  scanRetries = 0
  scanSeen = 0
  scanSaved = 0
  scanNoLink = 0
  scanNoBuyout = 0
  BeginScanStorage()
  local desc = "all items"
  if filterName ~= "" then desc = "name~'"..filterName.."'" end
  if filterClass then
    local classes = { GetAuctionItemClasses() }
    desc = desc..", class="..(classes[filterClass] or ("#"..filterClass))
  end
  if resume then
    Print("continuing scan ("..scanMode..") from page "..(resume.page or 0).." - "..desc..".")
  else
    Print("scan started ("..scanMode..") - "..desc..". Don't touch AH tabs.")
  end
  scanner:Show()
end

-- ============ export ===================================================
--
-- Two export paths:
--
--   1) /rap export
--        Populates the SavedVariable RAP_SHARED_DATA_EXPORT with a real
--        Lua table (NOT a string). After you /reload, the file
--        WTF/Account/<You>/SavedVariables/RelationshipsAuctionPrice.lua
--        will contain a block that looks exactly like PriceData.lua wants:
--
--            RAP_SHARED_DATA_EXPORT = {
--                ["Realm-F"] = { updated = 12345, items = { [774]={{u=98,q=1},...}, ... } },
--            }
--
--        Open that file, copy the whole `RAP_SHARED_DATA_EXPORT = { ... }`
--        block, paste it into AddOns/RelationshipsAuctionPrice/PriceData.lua,
--        and rename the variable to RAP_SHARED_DATA (or just change the
--        leading identifier). That IS your new PriceData.lua.
--
--   2) /rap exportstring
--        Old behaviour -- builds a compact single-string form under
--        RelationshipsAuctionPriceDB.export for people who want to paste
--        by hand. Kept for compatibility.
--
-- Note: you CANNOT copy the raw SavedVariables file (RelationshipsAuctionPriceDB)
-- into PriceData.lua. That table has a different shape (scans = {{q,s,u},...})
-- and a different global name; PriceData.lua reads RAP_SHARED_DATA with
-- items = { [id] = { {u,q}, ... } }.

local function BuildSharedTable()
  local key = GetRealmKey()
  local store = db.items[key] or {}
  local items = {}
  local count = 0
  for id, entry in pairs(store) do
    if entry.scans and table.getn(entry.scans) > 0 then
      local rows = {}
      for i=1, table.getn(entry.scans) do
        local r = entry.scans[i]
        table.insert(rows, { u = r.u, q = r.q })
      end
      items[id] = rows
      count = count + 1
    end
  end
  local out = {}
  out[key] = { updated = db.lastScan or time(), items = items }
  return out, key, count
end

local function ExportToSavedVariables()
  local tbl, key, count = BuildSharedTable()
  -- This global is registered in the .toc as a SavedVariable, so after
  -- /reload it will be serialised into the WTF SavedVariables file as a
  -- real Lua table -- ready to copy into PriceData.lua.
  RAP_SHARED_DATA_EXPORT = tbl
  db.exportedAt = time()
  Print("exported "..count.." items for "..key..".")
  Print("Now type /reload, then open:")
  Print("  WTF/Account/<You>/SavedVariables/RelationshipsAuctionPrice.lua")
  Print("Copy the whole RAP_SHARED_DATA_EXPORT = { ... } block into")
  Print("  AddOns/RelationshipsAuctionPrice/PriceData.lua")
  Print("and rename the variable to RAP_SHARED_DATA.")
end

-- Compact single-string form (legacy). Handy if you'd rather paste a string.
local function BuildExportString()
  local tbl, key = BuildSharedTable()
  local realm = tbl[key]
  local lines = {}
  table.insert(lines, "RAP_SHARED_DATA = {")
  table.insert(lines, "  [\""..key.."\"] = {")
  table.insert(lines, "    updated = "..(realm.updated or 0)..",")
  table.insert(lines, "    items = {")
  for id, rows in pairs(realm.items) do
    local parts = {}
    for i=1, table.getn(rows) do
      table.insert(parts, "{u="..rows[i].u..",q="..rows[i].q.."}")
    end
    table.insert(lines, "      ["..id.."]={"..table.concat(parts, ",").."},")
  end
  table.insert(lines, "    },")
  table.insert(lines, "  },")
  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

local function ExportStringToSavedVariables()
  db.export = BuildExportString()
  db.exportedAt = time()
  Print("string export written to RelationshipsAuctionPriceDB.export.")
  Print("/reload, then copy that string into PriceData.lua.")
end

-- ============ AH UI: scan button + name box + class dropdown ===========

local ahPanel, ahBtn, ahBtnStatus, ahNameBox, ahClassDD

local function CurrentFilterLabel()
  if filterName ~= "" and filterClass then
    local classes = { GetAuctionItemClasses() }
    return "'"..filterName.."' / "..(classes[filterClass] or "?")
  elseif filterName ~= "" then
    return "'"..filterName.."'"
  elseif filterClass then
    local classes = { GetAuctionItemClasses() }
    return classes[filterClass] or "class"
  end
  return "All items"
end

local function UpdateAHButton()
  if not ahBtn then return end
  if scanning then ahBtn:SetText("Stop") else ahBtn:SetText("Scan") end
  if ahBtnStatus then
    if scanning then
      local pagesTotal
      local _, total = GetNumAuctionItems("list")
      if total and total > 0 then pagesTotal = ceil(total / NUM_PER_PAGE) end
      if pagesTotal then
        ahBtnStatus:SetText("page "..(scanPage + 1).."/"..pagesTotal.."  ("..scanMode..")")
      else
        ahBtnStatus:SetText("starting... ("..scanMode..")")
      end
    else
      if db.lastScan and db.lastScan > 0 then
        local mins = floor((time() - db.lastScan) / 60)
      end
    end
  end
end

-- Dropdown initializer
local function InitClassDropdown()
  local info
  local classes = { GetAuctionItemClasses() }

  -- "All items"
  info = {}
  info.text = "All items"
  info.value = 0
  info.checked = (filterClass == nil)
  info.func = function()
    filterClass = nil
    filterSubclass = nil
    UIDropDownMenu_SetSelectedValue(ahClassDD, 0)
    UIDropDownMenu_SetText("All items", ahClassDD)
    UpdateAHButton()
  end
  UIDropDownMenu_AddButton(info)

  -- one entry per class
  for i=1, table.getn(classes) do
    local idx = i
    local nm  = classes[i]
    info = {}
    info.text = nm
    info.value = idx
    info.checked = (filterClass == idx)
    info.func = function()
      filterClass = idx
      filterSubclass = nil
      UIDropDownMenu_SetSelectedValue(ahClassDD, idx)
      UIDropDownMenu_SetText(nm, ahClassDD)
      UpdateAHButton()
    end
    UIDropDownMenu_AddButton(info)
  end
end

-- Resolve a relativeTo name from config into an actual frame reference.
local function RAPResolveRelative(name)
  if name == "AuctionFrame" then return AuctionFrame end
  if name == "panel"        then return ahPanel or AuctionFrame end
  if name == "scanBtn"      then return ahBtn end
  if name == "classDD"      then return ahClassDD end
  if name == "nameBox"      then return ahNameBox end
  return ahPanel or AuctionFrame
end

local function RAPApplyPoint(frame, cfg)
  if not frame or not cfg then return end
  frame:ClearAllPoints()
  frame:SetPoint(
    cfg.point or "CENTER",
    RAPResolveRelative(cfg.relativeTo),
    cfg.relativePoint or cfg.point or "CENTER",
    cfg.x or 0, cfg.y or 0
  )
end

local function CreateAHUI()
  if ahBtn or not AuctionFrame then return end
  local C = RAP_UI_CONFIG or {}

  -- Container panel: its own little box anchored just above the AH frame
  local cPanel = C.panel or {}
  ahPanel = CreateFrame("Frame", "RAPPanel", AuctionFrame)
  ahPanel:SetWidth(cPanel.width or 380)
  ahPanel:SetHeight(cPanel.height or 64)
  RAPApplyPoint(ahPanel, cPanel)
  ahPanel:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  local bg = cPanel.bgColor     or { 0.09, 0.07, 0.05, 0.95 }
  local bd = cPanel.borderColor or { 0.55, 0.42, 0.22, 1 }
  ahPanel:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
  ahPanel:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
  ahPanel:SetFrameStrata("MEDIUM")   -- AH is DIALOG strata; keep panel below it
  ahPanel:SetToplevel(false)

  -- Draggable panel (only while AH is open)
  ahPanel:SetMovable(true)
  ahPanel:EnableMouse(true)
  ahPanel:RegisterForDrag("LeftButton")
  ahPanel:SetClampedToScreen(true)
  ahPanel:SetScript("OnDragStart", function()
    if AuctionFrame and AuctionFrame:IsVisible() then
      this:StartMoving()
      this.isMoving = true
    end
  end)
  ahPanel:SetScript("OnDragStop", function()
    if this.isMoving then
      this:StopMovingOrSizing()
      this.isMoving = false
      local point, _, relPoint, x, y = this:GetPoint()
      RelationshipsAuctionPriceDB.panelPos = {
        point = point, relPoint = relPoint, x = x, y = y,
      }
    end
  end)

  -- Restore saved position (if any), otherwise keep the AH-anchored default
  local savedPos = RelationshipsAuctionPriceDB and RelationshipsAuctionPriceDB.panelPos
  if savedPos and savedPos.point then
    ahPanel:ClearAllPoints()
    ahPanel:SetPoint(savedPos.point, UIParent, savedPos.relPoint, savedPos.x, savedPos.y)
  end

  -- Scan button
  local cBtn = C.scanButton or {}
  ahBtn = CreateFrame("Button", "RAPScanButton", ahPanel, "UIPanelButtonTemplate")
  ahBtn:SetWidth(cBtn.width or 70); ahBtn:SetHeight(cBtn.height or 22)
  RAPApplyPoint(ahBtn, cBtn)
  ahBtn:SetText("Scan")
  ahBtn:SetScript("OnClick", function()
    if scanning then
      StopScan("aborted")
    else
      if IsControlKeyDown() then
        BeginScan(nil, true)  -- continue prior scan
      elseif IsShiftKeyDown() then
        BeginScan("fast")
      else
        BeginScan("full")
      end
    end
    UpdateAHButton()
  end)
  ahBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("Relationships Auction Price")
    GameTooltip:AddLine("Click: scan with current filter", 1,1,1)
    GameTooltip:AddLine("Shift-click: fast scan", 1,1,1)
    GameTooltip:AddLine("Ctrl-click: continue previous scan", 1,1,1)
    GameTooltip:AddLine("Filter: "..CurrentFilterLabel(), 0.7,0.9,1)
    if db and db.resume then
      GameTooltip:AddLine("Resume available: page "..(db.resume.page or 0).." ("..(db.resume.mode or "full")..")", 0.6,1,0.6)
    end
    GameTooltip:AddLine("Empty filter = scan everything.", 0.7,0.7,0.7)
    GameTooltip:Show()
  end)
  ahBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Class dropdown (to the left of scan by default)
  local cDD = C.classDropdown or {}
  ahClassDD = CreateFrame("Frame", "RAPClassDropDown", ahPanel, "UIDropDownMenuTemplate")
  RAPApplyPoint(ahClassDD, cDD)
  UIDropDownMenu_SetWidth(cDD.width or 120, ahClassDD)
  UIDropDownMenu_Initialize(ahClassDD, InitClassDropdown)
  UIDropDownMenu_SetSelectedValue(ahClassDD, 0)
  UIDropDownMenu_SetText("All items", ahClassDD)
  -- Center the dropdown's selected-text label within the dropdown box.
  local ddText = _G and _G["RAPClassDropDownText"] or getglobal("RAPClassDropDownText")
  if ddText then
    ddText:ClearAllPoints()
    ddText:SetPoint("CENTER", ahClassDD, "CENTER", 0, 2)
    ddText:SetJustifyH("CENTER")
  end

  -- Name filter EditBox (to the left of dropdown by default)
  local cName = C.nameBox or {}
  ahNameBox = CreateFrame("EditBox", "RAPNameFilter", ahPanel, "InputBoxTemplate")
  ahNameBox:SetAutoFocus(false)
  ahNameBox:SetJustifyH("CENTER")
  ahNameBox:SetWidth(cName.width or 120); ahNameBox:SetHeight(cName.height or 20)
  RAPApplyPoint(ahNameBox, cName)
  ahNameBox:SetScript("OnTextChanged", function()
    filterName = this:GetText() or ""
    UpdateAHButton()
  end)
  ahNameBox:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    if not scanning then BeginScan("full"); UpdateAHButton() end
  end)
  ahNameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

  -- Placeholder overlay ("Name Filter") shown while box is empty and unfocused.
  local ph = ahNameBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ph:SetPoint("CENTER", ahNameBox, "CENTER", -3, 0)
  ph:SetJustifyH("CENTER")
  ph:SetText("Name Filter")
  ph:SetTextColor(0.6, 0.6, 0.6)
  ahNameBox.placeholder = ph
  local function RAPUpdateNamePlaceholder()
    local txt = ahNameBox:GetText() or ""
    if txt == "" and not ahNameBox.hasFocus then
      ph:Show()
    else
      ph:Hide()
    end
  end
  ahNameBox:SetScript("OnEditFocusGained", function()
    this.hasFocus = true; RAPUpdateNamePlaceholder()
  end)
  ahNameBox:SetScript("OnEditFocusLost", function()
    this.hasFocus = false; RAPUpdateNamePlaceholder()
  end)
  local prevOnTextChanged = ahNameBox:GetScript("OnTextChanged")
  ahNameBox:SetScript("OnTextChanged", function()
    if prevOnTextChanged then prevOnTextChanged() end
    RAPUpdateNamePlaceholder()
  end)
  RAPUpdateNamePlaceholder()

  -- Status text under the row
  local cSt = C.statusText or {}
  ahBtnStatus = ahBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  RAPApplyPoint(ahBtnStatus, cSt)
  ahBtnStatus:SetTextColor(0.8, 0.8, 0.8)

  -- Show/hide the panel with the auction house
  ahPanel:SetScript("OnShow", function() end)
end

local btnTicker = CreateFrame("Frame")
btnTicker.acc = 0
btnTicker:SetScript("OnUpdate", function()
  btnTicker.acc = btnTicker.acc + arg1
  if btnTicker.acc < 0.25 then return end
  btnTicker.acc = 0
  if ahBtn and ahBtn:IsVisible() then UpdateAHButton() end
end)

-- ============ slash ====================================================

SLASH_RAP1 = "/rap"
SLASH_RAP2 = "/relprice"
SlashCmdList["RAP"] = function(msg)
  msg = msg or ""
  local low = string.lower(msg)
  if low == "" or low == "scan" then
    BeginScan("full")
  elseif low == "fast" then
    BeginScan("fast")
  elseif low == "continue" or low == "resume" then
    BeginScan(nil, true)
  elseif low == "continue clear" or low == "resume clear" then
    db.resume = nil
    Print("resume checkpoint cleared.")
  elseif low == "stop" then
    if scanning then StopScan("aborted") else Print("not scanning.") end
  elseif low == "clear" then
    db.items[GetRealmKey()] = {}
    Print("cleared prices for "..GetRealmKey())
  elseif low == "export" then
    ExportToSavedVariables()
  elseif low == "exportstring" then
    ExportStringToSavedVariables()
  elseif string.sub(low,1,5) == "name " then
    filterName = string.sub(msg, 6)
    if ahNameBox then ahNameBox:SetText(filterName) end
    Print("name filter set to '"..filterName.."'"); UpdateAHButton()
  elseif low == "name" or low == "name clear" then
    filterName = ""
    if ahNameBox then ahNameBox:SetText("") end
    Print("name filter cleared."); UpdateAHButton()
  elseif string.sub(low,1,6) == "class " then
    local arg = string.sub(low, 7)
    if arg == "clear" or arg == "" then
      filterClass = nil; filterSubclass = nil
      Print("class filter cleared.")
    else
      filterClass = tonumber(arg)
      local classes = { GetAuctionItemClasses() }
      Print("class filter -> "..(classes[filterClass] or ("#"..tostring(filterClass))))
    end
    UpdateAHButton()
  elseif low == "stats" then
    local localItems, localListings = CountRowsInStore(EnsureRealm())
    local sharedItems = 0
    local sharedListings = 0
    local shared = RAP_SHARED_DATA and RAP_SHARED_DATA[GetRealmKey()] and RAP_SHARED_DATA[GetRealmKey()].items
    if shared then
      for id, rows in pairs(shared) do
        sharedItems = sharedItems + 1
        sharedListings = sharedListings + table.getn(rows)
      end
    end
    Print("local: "..localListings.." listings across "..localItems.." item IDs.")
    Print("shared: "..sharedListings.." listings across "..sharedItems.." item IDs.")
  elseif string.sub(low,1,4) == "show" then
    local q = string.sub(low, 6)
    local store = EnsureRealm()
    local hits = 0
    for id, entry in pairs(store) do
      if entry.scans and table.getn(entry.scans) > 0 then
        if q == "" or string.find(tostring(id), q, 1, true) then
          Print(id..": "..table.getn(entry.scans).." listings, low "..FmtMoney(entry.scans[table.getn(entry.scans)].u))
          hits = hits + 1
          if hits >= 15 then break end
        end
      end
    end
    if hits == 0 then Print("no data. /rap scan at the AH first.") end
  else
    Print("commands: /rap scan | fast | continue | stop | clear | stats | show <id> | export")
    Print("          /rap name <text> | /rap name clear")
    Print("          /rap class <index> | /rap class clear")
    Print("          /rap continue clear   (drops the saved resume checkpoint)")
  end
end

-- ============ init =====================================================

local init = CreateFrame("Frame")
init:RegisterEvent("VARIABLES_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("AUCTION_HOUSE_SHOW")
init:SetScript("OnEvent", function()
  if event == "AUCTION_HOUSE_SHOW" then
    CreateAHUI()
    UpdateAHButton()
    return
  end
  db = RelationshipsAuctionPriceDB
  db.items = db.items or {}
  EnsureRealm()
  InstallTooltipHooks()
  local sharedCount = 0
  if RAP_SHARED_DATA and RAP_SHARED_DATA[GetRealmKey()] and RAP_SHARED_DATA[GetRealmKey()].items then
    for _ in pairs(RAP_SHARED_DATA[GetRealmKey()].items) do sharedCount = sharedCount + 1 end
  end
  Print("loaded. /rap scan at the AH. Shared items for this realm: "..sharedCount)
  if db.resume then
    Print("resume available: page "..(db.resume.page or 0).." ("..(db.resume.mode or "full").."). /rap continue at the AH.")
  end
end)
