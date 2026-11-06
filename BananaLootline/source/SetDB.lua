--[[----------------------------------------------------------------------
  BananaLootline - SetDB.lua

  Zugriff auf die Setdaten. Die Daten selbst stehen in Data/SetData.lua
  und werden VOR dieser Datei geladen.

  Warum Sets ueberhaupt zaehlen: in Vanilla entscheidet der Setbonus
  haeufig ueber die Wahl. Ein fuer sich schwaecheres Teil ist die bessere
  Wahl, wenn es den Vierer-Bonus vervollstaendigt. Ein reiner
  Wertevergleich liegt in solchen Faellen systematisch falsch.

  Format der Daten:
    BananaLootlineSetData[setID] = {
      name = "...",
      items = { itemID, itemID, ... },
      bonuses = { { p = 4, stats = { AP = 40 }, t = "..." }, ... },
    }

  p ist die Teileschwelle. Boni ohne stats sind nicht bezifferbar
  (etwa Procs ohne bekannte Ausloesewahrscheinlichkeit) - die werden
  angezeigt, aber nicht bewertet. Raten waere schlechter als schweigen.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline

BananaLootlineSetData = BananaLootlineSetData or {}

BLL.SetDB = {}
local SetDB = BLL.SetDB

function SetDB:Refresh()
  self.data = BananaLootlineSetData or {}
  self.count = 0
  self.itemToSet = {}

  for setID, set in pairs(self.data) do
    self.count = self.count + 1
    if set.items then
      for i = 1, table.getn(set.items) do
        self.itemToSet[set.items[i]] = setID
      end
    end
  end

  self.loaded = (self.count > 0)
  return self.count
end

SetDB:Refresh()

------------------------------------------------------------------
-- Abfragen
------------------------------------------------------------------

function SetDB:GetSetOf(itemID)
  if not itemID then return nil end
  local setID = self.itemToSet[itemID]
  if not setID then return nil end
  return setID, self.data[setID]
end

-- Wie viele Teile eines Sets traegt der Charakter gerade?
-- ignoreSlot: dieser Slot wird ausgelassen - noetig, weil beim Vergleich
-- das dort angelegte Teil ja ersetzt wuerde.
function SetDB:CountEquipped(setID, ignoreSlot)
  local set = self.data[setID]
  if not set then return 0 end

  local worn = 0
  for i = 1, table.getn(BLL.Gear.SLOTS) do
    local slot = BLL.Gear.SLOTS[i]
    if slot.key ~= ignoreSlot then
      local item = BLL.Gear.equipped[slot.key]
      if item and item.id and self.itemToSet[item.id] == setID then
        worn = worn + 1
      end
    end
  end
  return worn
end

------------------------------------------------------------------
-- Wertzuwachs durch Setboni
--
-- Liefert die Werte, die HINZUKOMMEN, wenn man von "worn" Teilen auf
-- "worn + 1" geht. Nur neu erreichte Schwellen zaehlen - ein bereits
-- aktiver Zweier-Bonus ist kein Argument fuer ein weiteres Teil.
------------------------------------------------------------------

function SetDB:BonusGain(setID, worn)
  local set = self.data[setID]
  if not set or not set.bonuses then return nil, nil end

  local gained = {}
  local texts = {}
  local any = false

  for i = 1, table.getn(set.bonuses) do
    local b = set.bonuses[i]
    if b.p and b.p > worn and b.p <= (worn + 1) then
      table.insert(texts, b.t or "")
      if b.stats then
        for k, v in pairs(b.stats) do
          gained[k] = (gained[k] or 0) + v
          any = true
        end
      end
    end
  end

  if table.getn(texts) == 0 then return nil, nil end
  return (any and gained or nil), texts
end

-- Alles zusammen: was bringt dieses Item ueber seine eigenen Werte
-- hinaus, wenn man es in diesem Slot anlegt?
function SetDB:EvaluateCandidate(itemID, slotKey)
  if not self.loaded then return nil end

  local setID, set = self:GetSetOf(itemID)
  if not setID then return nil end

  local worn = self:CountEquipped(setID, slotKey)
  local gained, texts = self:BonusGain(setID, worn)
  if not texts then return nil end

  return {
    setID   = setID,
    setName = set.name,
    worn    = worn,
    pieces  = worn + 1,
    stats   = gained,
    texts   = texts,
  }
end
