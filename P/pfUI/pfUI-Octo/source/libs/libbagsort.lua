-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

--[[ libbagsort ]]--
-- Sorts the bags or the bank (octo, 25 Oct 2026; a friend of the user: brues'
-- ClassicAPI pfUI had "instant bag sorting").
--
--  libbagsort:Sort("bags" | "bank")
--    ClassicAPI: C_Container.SortBags / SortBankBags - the client moves every
--    item itself (no cursor, a few frames). Without ClassicAPI: stacks are
--    topped up, then items are put in order one move at a time with the
--    cursor, each waiting for the item locks of the last one.
--    Order (as ClassicAPI's): hearthstone, weapons and armour by slot,
--    everything else by type / subtype / name with fuller stacks first, grey
--    items at the end. Special bags (soul, quiver, herb...) are left as they
--    are by the plain sort. "bank" only while the bank is open.
--
--  libbagsort:IsSorting()      true while a plain sort is still moving things
--  libbagsort.onDone           function() called when a sort has finished

-- return instantly when another libbagsort is already active
if pfUI.api.libbagsort then return end

local libbagsort = CreateFrame("Frame", "pfLibBagSort", UIParent)
libbagsort:Hide()
pfUI.api.libbagsort = libbagsort

local BAGS = { 0, 1, 2, 3, 4 }
local BANK = { -1, 5, 6, 7, 8, 9, 10 }
local HEARTHSTONE = 6948

-- gear in slot order (the order ClassicAPI's sort uses)
local SLOT_ORDER = {
  "INVTYPE_2HWEAPON", "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE",
  "INVTYPE_RANGEDRIGHT", "INVTYPE_WEAPONOFFHAND", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_AMMO",
  "INVTYPE_QUIVER", "INVTYPE_RELIC", "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST",
  "INVTYPE_ROBE", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
  "INVTYPE_NECK", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_BODY", "INVTYPE_TABARD", "INVTYPE_BAG",
}
local SLOT_RANK = {}
for i, token in ipairs(SLOT_ORDER) do SLOT_RANK[token] = i end

local function HasClassicAPI()
  return C_UnitAuras and C_Container and C_Container.SortBags and true or nil
end
libbagsort.HasClassicAPI = HasClassicAPI

local function BankOpen()
  return BankFrame and BankFrame:IsShown()
end

local function IdOf(link)
  local _, _, id = string.find(link or "", "item:(%d+)")
  return tonumber(id)
end

-- the plain sort's order key for the item in bag / slot (nil = empty)
local function Key(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  if not link then return end
  local id = IdOf(link)
  local _, count = GetContainerItemInfo(bag, slot)
  local name, _, quality, _, itype, isub, _, equip = _G.GetItemInfo(id or 0)
  name = name or link
  quality = quality or 1
  local group
  if id == HEARTHSTONE then group = "0"
  elseif quality == 0 then group = "9"
  elseif equip and SLOT_RANK[equip] and equip ~= "INVTYPE_BAG" then
    group = "1" .. string.format("%02d", SLOT_RANK[equip])
  else group = "5" .. (itype or "") end
  local full = string.format("%06d", 999999 - (count or 1))
  return group .. "|" .. (isub or "") .. "|" .. (9 - quality) .. "|" .. name .. "|" .. (id or 0) .. "|" .. full, id, count or 1
end
libbagsort.Key = Key

-- the plain sort only uses normal bags: special bags keep their own things
local function Slots(list)
  local slots = {}
  for _, bag in ipairs(list) do
    local family = bag > 0 and GetBagFamily and GetBagFamily(bag) or "BAG"
    if family == "BAG" or family == nil and bag <= 0 then
      for slot = 1, (GetContainerNumSlots(bag) or 0) do
        table.insert(slots, { bag = bag, slot = slot })
      end
    end
  end
  return slots
end

local function Locked(bag, slot)
  local _, _, locked = GetContainerItemInfo(bag, slot)
  return locked
end

local function AnyLocked(slots)
  for _, s in ipairs(slots) do
    if Locked(s.bag, s.slot) then return true end
  end
end

local function MaxStack(id)
  local _, _, _, _, _, _, stack = _G.GetItemInfo(id or 0)
  return tonumber(stack) or 1
end

-- one move towards a sorted bag; true = something moved, nil = all sorted
local function Step(slots)
  -- 1. top up partial stacks of the same item (smaller one onto the bigger)
  local partial = {}
  for _, s in ipairs(slots) do
    local link = GetContainerItemLink(s.bag, s.slot)
    local id = IdOf(link)
    if id then
      local _, count = GetContainerItemInfo(s.bag, s.slot)
      local max = MaxStack(id)
      count = count or 1
      if max > 1 and count < max then
        local other = partial[link]
        local cur = { bag = s.bag, slot = s.slot, count = count }
        if other then
          local small, big = other, cur
          if other.count > count then small, big = cur, other end
          local move = math.min(small.count, max - big.count)
          if move > 0 then
            if move < small.count then
              SplitContainerItem(small.bag, small.slot, move)
            else
              PickupContainerItem(small.bag, small.slot)
            end
            PickupContainerItem(big.bag, big.slot)
            return true
          end
        else
          partial[link] = cur
        end
      end
    end
  end

  -- 2. the item that belongs in the first wrong place: swapped into it
  local items = {}
  for i, s in ipairs(slots) do
    local key, id = Key(s.bag, s.slot)
    if key then table.insert(items, { key = key, id = id, at = i }) end
  end
  table.sort(items, function(a, b) return a.key < b.key end)
  -- greys fill from the end
  local first, last = {}, {}
  for _, it in ipairs(items) do
    if string.sub(it.key, 1, 1) == "9" then table.insert(last, 1, it) else table.insert(first, it) end
  end
  local want = {}
  for i, it in ipairs(first) do want[i] = it end
  local n = table.getn(slots)
  for i, it in ipairs(last) do want[n - i + 1] = it end

  for i = 1, n do
    local it = want[i]
    local _, hereId = Key(slots[i].bag, slots[i].slot)
    -- (no item wanted here: whatever is here moves when its own place comes)
    if it and hereId ~= it.id then
      local from = slots[it.at]
      PickupContainerItem(from.bag, from.slot)
      PickupContainerItem(slots[i].bag, slots[i].slot)
      -- (the same item but not stackable together: put the held one back)
      if CursorHasItem and CursorHasItem() then PickupContainerItem(from.bag, from.slot) end
      return true
    end
  end
end
libbagsort.Step = Step

local function Done()
  libbagsort.run = nil
  libbagsort:Hide()
  if libbagsort.onDone then pcall(libbagsort.onDone) end
end

libbagsort:SetScript("OnUpdate", function()
  local run = this.run
  if not run then this:Hide() return end
  if (this.tick or 0) > GetTime() then return end
  this.tick = GetTime() + .05
  if GetTime() > run.till then Done() return end
  if CursorHasItem and CursorHasItem() then return end
  if AnyLocked(run.slots) then return end
  run.moves = run.moves + 1
  if run.moves > 500 or not Step(run.slots) then Done() end
end)

-- ClassicAPI's sort: done when the bags stop changing (BAG_UPDATE_DELAYED quiet)
libbagsort:SetScript("OnEvent", function()
  this.quietAt = GetTime() + .5
end)
local quiet = CreateFrame("Frame")
quiet:Hide()
quiet:SetScript("OnUpdate", function()
  if (libbagsort.quietAt or 0) > GetTime() then return end
  this:Hide()
  libbagsort:UnregisterAllEvents()
  if libbagsort.onDone then pcall(libbagsort.onDone) end
end)

function libbagsort:Sort(which)
  local bank = which == "bank"
  if bank and not BankOpen() then return end
  if HasClassicAPI() then
    local fn = bank and C_Container.SortBankBags or C_Container.SortBags
    if fn and pcall(fn) then
      self.quietAt = GetTime() + 1
      self:RegisterEvent("BAG_UPDATE")
      quiet:Show()
      return true
    end
  end
  if self.run then return end
  ClearCursor()
  self.run = { slots = Slots(bank and BANK or BAGS), moves = 0, till = GetTime() + 30 }
  self.tick = 0
  self:Show()
  return true
end

function libbagsort:IsSorting()
  return self.run ~= nil or quiet:IsShown()
end

-- a sort button on pfUI's bag and bank windows (unless a sort addon took it)
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function()
  this:UnregisterAllEvents()
  if not pfUI.thirdparty or not pfUI.thirdparty.RegisterBagSort or pfUI.thirdparty.bagsort then return end
  local function Tip(text)
    return function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(text)
      GameTooltip:AddLine(HasClassicAPI() and T["Instant (ClassicAPI)"] or T["One item at a time"], 1, 1, 1)
      GameTooltip:Show()
    end
  end
  pfUI.thirdparty.RegisterBagSort("pfUI",
    function() libbagsort:Sort("bags") end, Tip(T["Sort Bags"]),
    function() libbagsort:Sort("bank") end, Tip(T["Sort Bank"]))
end)
