-- pandaUI :: modules/itemprice.lua
--
-- Item value at the bottom of bag, bank and quest-reward item tooltips. See
-- "Hover path" below for why each surface needs its own button hook.
--
-- This client has no API that returns a price from an item id. GetItemInfo
-- stops at `texture` and returns nine values with no sellPrice
-- (documentation.json / global:Item:GetItemInfo), and query_compat.py has no
-- record of GetSellValue at all. Every price this client will disclose is
-- situational:
--
--   * GetMerchantItemInfo(i)     buy price, vendor window open
--   * GetBuybackItemInfo(i)      sell price, but no item link to key it by
--   * GetAuctionSellItemInfo()   vendor sell price, auction sell slot only
--   * GameTooltip:SetBagItem     fires OnTooltipAddMoney with the stack sell
--                                price, and only while a merchant is open
--
-- So pandaUI learns prices instead of looking them up: whatever a vendor or a
-- tooltip discloses is written to PandaUIPriceDB and reused everywhere after.
--
-- Learning alone only covers items the player has already carried past a
-- vendor, so core/pricedata.lua supplies a base price for every stock item id
-- as a fallback (Vanilla data extracted from UnrealPfUI, see that file for the
-- provenance and its accuracy limit). A learned price always wins over it, and
-- the table is never written back into PandaUIPriceDB, so one vendor visit
-- permanently corrects anything this server has re-priced.
--
-- The first version identified the hovered item by replacing GameTooltip's
-- item setters, the way UnrealPfUI libs/libtooltip.lua does. That does not
-- work on this client and the replacement is documented under "Hover path".

local U = PandaUI
local IP = U.RegisterModule("itemprice")

local DB_NAME = "PandaUIPriceDB"
local DB_VERSION = 1

local store              -- { version, sell = {[id] = copper}, buy = {[id] = copper} }
local tracked = {}       -- tooltip frame -> { id, count }
local slotHover = {}     -- the bag/bank slot whose price is up: button, bag, slot

-- Diagnostic state for /pui price. A missing price line has a small number of
-- distinct causes -- the hover hook never ran, the link did not resolve, the
-- item has no row, the vendor suppression fired -- and this records which one
-- happened on the last tooltip build rather than leaving it to be guessed at.
local trace = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function LinkID(link)
  if type(link) ~= "string" then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  return tonumber(id)
end

local function Sane(copper)
  copper = tonumber(copper)
  if not copper or copper <= 0 then return nil end
  return math.floor(copper)
end

-- Every price source below is optional on this client, so nothing is called
-- directly: a missing global leaves the tooltip untouched instead of erroring
-- inside a native tooltip build.
local function Call(name, a1, a2)
  local fn = U.G(name)
  if type(fn) ~= "function" then return nil end

  local ok, r1, r2, r3, r4 = pcall(fn, a1, a2)
  if not ok then return nil end
  return r1, r2, r3, r4
end

local function MerchantShown()
  local frame = U.G("MerchantFrame")
  if not frame or not frame.IsShown then return false end

  local ok, shown = pcall(frame.IsShown, frame)
  if ok and shown then return true end
  return false
end

-- ---------------------------------------------------------------------------
-- Store
--
-- Its own SavedVariable rather than a config key: prices are account-wide
-- learned data, not per-profile settings, and core/config.lua validates a
-- small fixed schema. Only numbers are stored, so knowledge.json /
-- config.savedvariables_backslash_corruption cannot bite.
-- ---------------------------------------------------------------------------
local function Prune(list)
  local key, value
  for key, value in pairs(list) do
    if type(key) ~= "number" or not Sane(value) then list[key] = nil end
  end
end

local function LoadStore()
  local db = U.G(DB_NAME)
  if type(db) ~= "table" then
    U.SetG(DB_NAME, { version = DB_VERSION })
    db = U.G(DB_NAME)
    -- Global write ignored: keep the prices for this session rather than
    -- disabling the readout entirely.
    if type(db) ~= "table" then db = { version = DB_VERSION } end
  end

  db.version = DB_VERSION
  if type(db.sell) ~= "table" then db.sell = {} end
  if type(db.buy) ~= "table" then db.buy = {} end

  -- A corrupted or hand-edited saved file must not reach a tooltip.
  Prune(db.sell)
  Prune(db.buy)

  store = db
  return true
end

-- Sell prices keep the highest unit price seen, because the client reports a
-- durability- and charge-adjusted sell price: hovering a damaged weapon at a
-- vendor quotes less than the repaired item is worth. Buy prices keep the most
-- recent quote instead -- a vendor asking price legitimately varies with the
-- reputation discount, so there is no single true value to converge on.
local function Record(kind, id, copper)
  if not store or not id then return end

  copper = Sane(copper)
  if not copper then return end

  local list = store[kind]
  if kind == "sell" and list[id] and list[id] >= copper then return end
  list[id] = copper
end

-- ---------------------------------------------------------------------------
-- Lookup
--
-- A learned price always wins over core/pricedata.lua: that table is Vanilla
-- data and this server is not Vanilla, so the moment a vendor discloses a real
-- price it replaces the base row for good. Parsed rows are memoised because
-- the packed "sell,buy" string needs a string.find to split, and a tooltip can
-- be rebuilt on every frame while the mouse rests on a slot.
--
-- A zero in either field means unsellable / not stocked, and Sane() turns it
-- into nil, so that half simply gets no line.
-- ---------------------------------------------------------------------------
local baseCache = {}

local function Base(id)
  local row = baseCache[id]
  if row == nil then
    row = false

    local packed = U.priceData and U.priceData[id]
    if type(packed) == "string" then
      local _, _, sell, buy = string.find(packed, "(%d+),(%d+)")
      if sell then row = { sell = Sane(sell), buy = Sane(buy) } end
    end
    baseCache[id] = row
  end

  if not row then return nil end
  return row
end

local function Lookup(kind, id)
  if store and store[kind][id] then return store[kind][id] end

  local row = Base(id)
  if row then return row[kind] end
  return nil
end

-- GetQuestItemLink is documented on this client, but USER_CONFIRMED_INGAME
-- (2026-08-29, /pui price) it returned nil for a visible choice reward whose
-- tooltip had already been populated. GetQuestItemInfo still provides the
-- displayed name, texture and quality. Resolve that tuple only against item
-- ids for which this module can actually show a price: learned sell rows first,
-- then the stock fallback table. UnrealPfUI's GetItemLinkByName uses the same
-- GetItemInfo id scan across a larger fixed range; narrowing it to priced ids
-- avoids doing work for items that would have no sell row anyway.
local questLinkCache = {}

local function FindPricedItemLink(list, name, texture, quality)
  if type(list) ~= "table" then return nil end

  local getItemInfo = U.G("GetItemInfo")
  if type(getItemInfo) ~= "function" then return nil end

  local found
  local ok = pcall(function()
    local id
    for id in pairs(list) do
      if type(id) == "number" then
        local itemName, link, itemQuality, _, _, _, _, _, itemTexture =
          getItemInfo(id)
        if itemName == name and
           (not texture or itemTexture == texture) and
           (not quality or itemQuality == quality) and
           LinkID(link) then
          found = link
          return
        end
      end
    end
  end)

  if ok then return found end
  return nil
end

local function QuestLinkByInfo(name, texture, quality)
  if type(name) ~= "string" or name == "" then return nil end

  local cached = questLinkCache[name]
  if cached and
     (not texture or cached.texture == texture) and
     (not quality or cached.quality == quality) then
    return cached.link
  end

  local link = FindPricedItemLink(store and store.sell, name, texture, quality)
  if not link then
    link = FindPricedItemLink(U.priceData, name, texture, quality)
  end

  if link then
    questLinkCache[name] = {
      link = link,
      texture = texture,
      quality = quality,
    }
  end
  return link
end

-- The measured buyback tuple exposes name and texture but no link or quality,
-- so merchant.lua needs the same bounded identity fallback as quest rewards:
-- learned priced ids first, then the bundled Vanilla price table, with icon
-- matching. Keep the resolver here so its cache is shared and a buyback
-- refresh does not repeat the item-id walk.
function U.PricedItemLinkByInfo(name, texture, quality)
  return QuestLinkByInfo(name, texture, quality)
end

-- ---------------------------------------------------------------------------
-- Harvest
-- ---------------------------------------------------------------------------
-- Vendor list: the quoted price is per purchase and one purchase can grant a
-- stack (arrows), so it is normalised to a unit price.
local function ScanMerchant()
  local total = tonumber(Call("GetMerchantNumItems")) or 0

  local i
  for i = 1, total do
    local id = LinkID(Call("GetMerchantItemLink", i))
    if id then
      local _, _, price, quantity = Call("GetMerchantItemInfo", i)
      quantity = tonumber(quantity) or 1
      if quantity < 1 then quantity = 1 end

      price = tonumber(price)
      if price and price > 0 then Record("buy", id, price / quantity) end
    end
  end
end

-- OnTooltipAddMoney carries the stack sell price. Which position the amount
-- arrives in depends on this client handler shape (core/init.lua resolves
-- three of them for events and cannot resolve them for scripts), so the first
-- positive number wins and the legacy `arg1` global is the last resort. A
-- wrong shape therefore records nothing instead of recording nonsense.
local function ResolveAmount(a1, a2, a3, a4)
  local value = tonumber(a1)
  if value and value > 0 then return value end
  value = tonumber(a2)
  if value and value > 0 then return value end
  value = tonumber(a3)
  if value and value > 0 then return value end
  value = tonumber(a4)
  if value and value > 0 then return value end

  value = tonumber(U.G("arg1"))
  if value and value > 0 then return value end
  return nil
end

-- ---------------------------------------------------------------------------
-- Tooltip tracking and readout
-- ---------------------------------------------------------------------------
local function Remember(tip, link, count)
  local rec = tracked[tip]
  if not rec then
    rec = {}
    tracked[tip] = rec
  end

  rec.id = LinkID(link)
  rec.count = tonumber(count) or 1
end

-- Focused PandaRuntimeProbe access to the live separate price panel. The
-- references are read-only and avoid searching unnamed tooltip children.
function U.ProbeItemPriceGeometry()
  local panel = trace.panelFrame
  local row = panel and panel.rows and panel.rows[1]
  local readout = row and row.readout
  local shown = false
  if panel and panel.IsShown then
    local ok, value = pcall(panel.IsShown, panel)
    if ok and value then shown = true end
  end
  return {
    active = shown,
    mode = "separate-panel",
    tip = U.G("GameTooltip"),
    panel = panel,
    row = row,
    label = row and row.label,
    readout = readout,
    gold = readout and readout.gold,
    silver = readout and readout.silver,
    copper = readout and readout.copper,
  }
end

local function Append(tip)
  -- One singleton is shared by all price readouts. Clear the previous owner
  -- before resolving this hover so an unknown or suppressed item cannot leave
  -- the last item's panel visible.
  U.HideMoneyRows()

  local rec = tracked[tip]
  if not rec or not rec.id then
    trace.result = "no item id resolved"
    return
  end

  -- While a vendor is open the client adds its own sell-price money frame to
  -- the tooltip. That frame is anchored under whatever the last line was when
  -- it was added, so appending text after it would draw over it -- and it
  -- already says the same thing. UnrealPfUI suppresses its own line the same
  -- way in modules/sellvalue.lua.
  if MerchantShown() then
    trace.result = "suppressed, merchant open"
    return
  end

  local sell = Lookup("sell", rec.id)
  if not sell then
    trace.result = "no sell price known for item " .. rec.id
    return
  end

  local count = rec.count or 1
  if count < 1 then count = 1 end

  -- Always one row: the displayed sell value belongs to the hovered stack.
  -- A single item naturally remains its unit value because count is one.
  local stackSell = sell * count
  local rows = { { label = U.L("COMMON_SELL"), copper = stackSell } }

  -- Every theme uses the separate owned frame because GameTooltip will not
  -- retain an explicit larger height. itempricegeometry.v1 measured Classic's
  -- requested 62.48 height restored to 34.48 for all eight samples, leaving
  -- an inline row over the item name. Sharing the tooltip edge preserves one
  -- visual surface without depending on native relayout.
  -- The match is asked for rather than measured here: a width read during this
  -- hover is still the previous tooltip's, which is what made the price cell
  -- render far wider than the tooltip above it. U.ShowMoneyRows carries the
  -- detail and does the tracking.
  local panel = U.ShowMoneyRows(tip, rows, "TOPLEFT", "BOTTOMLEFT", 0, 0, true)
  local shown, height = false, nil
  if panel then
    local shownOk, shownValue = pcall(panel.IsShown, panel)
    if shownOk then shown = shownValue and true or false end

    local heightOk, heightValue = pcall(panel.GetHeight, panel)
    if heightOk then height = heightValue end
  end

  -- Kept so /pui price can report the width the panel settled on after the
  -- client laid the tooltip out, not the one it opened with.
  trace.panelFrame = panel
  trace.result = "panel shown, " .. table.getn(rows) .. " rows"
  trace.sell = stackSell
  trace.panel = "shown=" .. tostring(shown) .. " height=" .. tostring(height)
end

-- ---------------------------------------------------------------------------
-- Hover path
--
-- USER_CONFIRMED_INGAME (2026-08-26, /pui price): replacing a method on
-- GameTooltip does not hold on this client. pandaUI installed a wrapper for
-- all ten item setters and at hover time none of them was the live method, and
-- not one had ever run -- "hooks: 0 live, 10 replaced, 0 never installed" with
-- "last tooltip: none seen". A later hook by someone else would have kept our
-- wrapper in the chain and it would still have run, so the assignment itself
-- is what does not persist. UnrealPfUI libs/libtooltip.lua is built entirely
-- on that assignment: a reminder that WORKING_SOURCE is not evidence that
-- something works here.
--
-- The item is therefore identified from the button being hovered rather than
-- from the tooltip. core/itemslot.lua already post-hooks OnEnter on every bag
-- and bank slot it creates -- a script hook through U.PostHookScript, the
-- mechanism this addon uses everywhere and which demonstrably works -- and it
-- knows the container and slot. It calls in here once the stock template has
-- populated and shown GameTooltip.
--
-- Consequence, stated rather than left to be discovered: the price panel
-- appears on the surfaces pandaUI owns a hover hook for. Bag/bank slots,
-- quest rewards and loot rows have one. Merchant rows and chat links do not
-- yet, and each needs its own button hook rather than one central tooltip
-- hook.
-- ---------------------------------------------------------------------------
function U.ShowItemPrice(bag, slot, button)
  U.HideMoneyRows()

  local tooltip = U.G("GameTooltip")
  if not tooltip then return end

  -- From here until the slot is left, U.RefreshItemPrice owns the price's
  -- lifetime rather than GameTooltip's OnHide (see that function).
  slotHover.button, slotHover.bag, slotHover.slot = button, bag, slot

  local link = Call("GetContainerItemLink", bag, slot)
  local _, count = Call("GetContainerItemInfo", bag, slot)
  Remember(tooltip, link, count)

  trace.source = "bag " .. tostring(bag) .. " slot " .. tostring(slot)
  trace.lookup = "container link"
  trace.link = link
  trace.id = LinkID(link)
  trace.count = count
  trace.sell = nil
  trace.panel = nil
  trace.result = "hover ran, Append did not finish"

  local ok, err = pcall(Append, tooltip)
  if not ok then
    trace.result = "error: " .. tostring(err)
    U.Debug("itemprice hover: " .. tostring(err))
  end
end

-- The shared path for every native row that names its own item without being
-- a container slot: quest rewards on the quest-giver frame, quest rewards in
-- the quest log, and loot rows. Each of those reads a different API family for
-- the link and for the displayed (name, texture, quality, count) tuple, so
-- only the getters differ per surface and everything from the lookup down is
-- shared here. Every one of them calls in after the stock OnEnter has
-- populated GameTooltip, mirroring the proven bag/button hover path above.
--
-- The caller's link getter is allowed to fail: GetQuestItemLink is documented
-- on this client and still returned nil for a visible reward
-- (USER_CONFIRMED_INGAME, see QuestLinkByInfo), so a link carrying no item id
-- falls back to resolving the displayed tuple against the ids this module can
-- actually price. A surface whose texture string may not match GetItemInfo's
-- passes `texture` as nil to keep it out of that comparison.
local function HoverItemPrice(source, link, name, texture, quality, count)
  local tooltip = U.G("GameTooltip")
  if not tooltip then return nil end

  local lookup = "native link"
  if not LinkID(link) then
    link = QuestLinkByInfo(name, texture, quality)
    lookup = "priced-item name fallback"
  end
  Remember(tooltip, link, count)

  trace.source = source
  trace.lookup = lookup
  trace.link = link
  trace.id = LinkID(link)
  trace.count = count
  trace.sell = nil
  trace.panel = nil
  trace.result = "hover ran, Append did not finish"

  local ok, err = pcall(Append, tooltip)
  if not ok then
    trace.result = "error: " .. tostring(err)
    U.Debug("itemprice hover (" .. tostring(source) .. "): " .. tostring(err))
  end

  -- The calling module also hands this resolved link to core/itemslot.lua's
  -- shared comparison renderer. Returning it keeps price and compare on the
  -- same guarded identity path, including the confirmed nil-link fallback.
  return link
end

function U.ShowQuestItemPrice(itemType, index)
  U.HideMoneyRows()

  if itemType ~= "choice" and itemType ~= "reward" then return end
  index = tonumber(index)
  if not index or index < 1 then return end

  local link = Call("GetQuestItemLink", itemType, index)
  local name, texture, count, quality =
    Call("GetQuestItemInfo", itemType, index)
  return HoverItemPrice("quest " .. itemType .. " " .. tostring(index),
                        link, name, texture, quality, count)
end

-- The quest log's own reward buttons carry the same "choice"/"reward" identity
-- -- that is what the native QuestLogItem OnEnter already feeds to
-- GameTooltip:SetQuestLogItem -- but the log reads through a separate API
-- family: GetQuestLogItemLink(type, index) for the link, and one info getter
-- per list rather than a single type-taking one. All three are
-- OFFICIAL_CLIENT_DOCUMENTATION / DOCUMENTED_NOT_RUNTIME_VERIFIED on this
-- client, so Call() keeps each of them non-fatal, and a nil link still falls
-- back to the confirmed priced-item name scan the quest frame relies on.
function U.ShowQuestLogItemPrice(itemType, index)
  U.HideMoneyRows()

  if itemType ~= "choice" and itemType ~= "reward" then return end
  index = tonumber(index)
  if not index or index < 1 then return end

  local link = Call("GetQuestLogItemLink", itemType, index)
  local name, texture, count, quality
  if itemType == "choice" then
    name, texture, count, quality = Call("GetQuestLogChoiceInfo", index)
  else
    name, texture, count, quality = Call("GetQuestLogRewardInfo", index)
  end
  return HoverItemPrice("questlog " .. itemType .. " " .. tostring(index),
                        link, name, texture, quality, count)
end

-- Loot rows. LootButton1..4 are page positions rather than loot slots, so
-- modules/loot.lua resolves the real 1-based slot and passes it here after the
-- native OnEnter has populated GameTooltip.
--
-- GetLootSlotInfo is the one getter on this path with runtime evidence:
-- behavior.json / lootbutton records it returning exactly four values,
-- (texture, name, quantity, quality), for a live loot row -- a different order
-- and one value shorter than the quest getters, which is why the tuple is
-- unpacked here rather than shared. GetNumLootItems, GetLootSlotLink and
-- LootSlotIsCoin are OFFICIAL_CLIENT_DOCUMENTATION only, so Call() keeps each
-- of them non-fatal.
--
-- The texture is deliberately not handed to the name fallback: the recorded
-- loot texture strings use forward slashes ("Interface/Icons/INV_Misc_Bone_08")
-- and nothing establishes that GetItemInfo reports the same form here, so
-- comparing them could reject the correct item. Name and quality still have to
-- agree.
function U.ShowLootItemPrice(slot)
  U.HideMoneyRows()

  slot = tonumber(slot)
  if not slot or slot < 1 then return nil end

  -- The coin row has no item behind it, and asking for a price for "120
  -- Copper" would only send the name fallback scanning the whole priced-item
  -- table for something that cannot be there.
  if Call("LootSlotIsCoin", slot) then return nil end

  local link = Call("GetLootSlotLink", slot)
  local _, name, count, quality = Call("GetLootSlotInfo", slot)
  return HoverItemPrice("loot slot " .. tostring(slot),
                        link, name, nil, quality, count)
end

-- The stock container button's OnUpdate calls ContainerFrameItemButton_OnEnter
-- every frame while it owns GameTooltip (octo-framexml ContainerFrame.lua), so
-- the tooltip is SetOwner'd -- firing its OnHide -- and re-populated every
-- frame of a hover without the button's OnEnter script running again. Taking
-- the price down from OnHide therefore left it on screen for a single frame,
-- and the favourite note, still hung under the hidden panel, left an empty gap
-- where it had been (user report 2026-10-17, same cycle as
-- bags.favorite_hint_tooltip_cycle).
--
-- core/itemslot.lua post-hooks each slot's OnUpdate into this, which runs after
-- the stock re-population. The separate price panel hangs off GameTooltip and
-- follows it, so it only has to be left alone while ownership remains valid.
function U.RefreshItemPrice(button)
  if not button or slotHover.button ~= button then return end

  local tooltip = U.G("GameTooltip")
  if not tooltip then return end

  local ownedOk, owned = pcall(tooltip.IsOwned, tooltip, button)
  local shownOk, shown = pcall(tooltip.IsShown, tooltip)
  if not ownedOk or not owned or not shownOk or not shown then
    U.HideItemPrice()
  end
end

function U.HideItemPrice()
  slotHover.button = nil
  U.HideMoneyRows()
end

-- ---------------------------------------------------------------------------
-- Diagnostic
--
-- /pui price, printed straight to chat. Hover an item, run it, and the last
-- line names which stage stopped: the setter never ran (no hook), no item id
-- (link getter), no price (missing row), suppressed (vendor open), or added.
-- ---------------------------------------------------------------------------
local function CountKeys(list)
  local total, key = 0, nil
  if type(list) ~= "table" then return 0 end
  for key in pairs(list) do total = total + 1 end
  return total
end

function U.PriceDebugDump()
  U.Print("item price:")

  local data = U.priceData
  U.Print("  base table: " .. (type(data) == "table" and
          (CountKeys(data) .. " items, id 25 = " .. tostring(data[25])) or
          "MISSING (core/pricedata.lua did not load)"))

  if store then
    U.Print("  learned: " .. CountKeys(store.sell) .. " sell, " ..
            CountKeys(store.buy) .. " buy")
  else
    U.Print("  learned: store not loaded")
  end

  U.Print("  merchant open: " .. tostring(MerchantShown()))

  if not trace.source then
    U.Print("  last hover: none seen -- no supported item button called in")
    return
  end

  U.Print("  last hover: " .. tostring(trace.source) ..
          " lookup=" .. tostring(trace.lookup) ..
          " link=" .. tostring(trace.link) ..
          " id=" .. tostring(trace.id) ..
          " count=" .. tostring(trace.count))
  U.Print("  result: " .. tostring(trace.result) ..
          " (sell=" .. tostring(trace.sell) .. ")")

  if trace.panel then U.Print("  panel: " .. tostring(trace.panel)) end

  -- Width is read live rather than from the trace: the panel follows the
  -- tooltip for as long as it is shown, so the settled numbers only exist on
  -- the frame itself.
  local frame = trace.panelFrame
  if frame then
    U.Print("  width: content=" .. tostring(frame.contentWidth) ..
            " anchor=" .. tostring(frame.anchorWidth) ..
            " applied=" .. tostring(frame.appliedWidth))
  end
end

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
function IP:OnEnable()
  -- Never fails closed: a rejected global write leaves a session-only store,
  -- and the readout still has core/pricedata.lua to fall back on.
  LoadStore()

  local tooltip = U.G("GameTooltip")

  -- The tracked item belongs to one hover. Clearing it when the tooltip hides
  -- keeps a stale id from being credited with the next vendor money line.
  -- During a slot hover OnHide fires every frame; U.RefreshItemPrice decides
  -- then, and the slot's OnLeave clears the hover.
  if tooltip then
    U.PostHookScript(tooltip, "OnHide", function()
      if slotHover.button then return end
      U.HideItemPrice()

      local rec = tracked[tooltip]
      if rec then
        rec.id = nil
        rec.count = nil
      end
    end)
  end

  -- The stack sell price handed to the tooltip at a vendor is the only true
  -- sell value this client volunteers for an arbitrary bag item, so it is
  -- captured wherever it appears.
  if tooltip then
    U.PostHookScript(tooltip, "OnTooltipAddMoney", function(a1, a2, a3, a4)
      local rec = tracked[tooltip]
      if not rec or not rec.id then return end

      local amount = ResolveAmount(a1, a2, a3, a4)
      if not amount then return end

      local count = rec.count or 1
      if count < 1 then count = 1 end
      Record("sell", rec.id, amount / count)
    end)
  end

  U.RegisterEvent("MERCHANT_SHOW", ScanMerchant)
  U.RegisterEvent("MERCHANT_UPDATE", ScanMerchant)
end
