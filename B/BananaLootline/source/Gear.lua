--[[----------------------------------------------------------------------
  BananaLootline - Gear.lua

  Scannt angelegte Ausruestung und Taschen. Das ist der Punkt, an dem das
  Addon der Webseite ueberlegen ist: im Browser muss man 19 Slots von Hand
  eintragen, ingame lesen wir sie einfach aus.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline
BLL.Gear = {}
local Gear = BLL.Gear

------------------------------------------------------------------
-- Slotdefinition
------------------------------------------------------------------

Gear.SLOTS = {
  { key = "HeadSlot",          labelDE = "Kopf",       labelEN = "Head"        },
  { key = "NeckSlot",          labelDE = "Hals",       labelEN = "Neck"        },
  { key = "ShoulderSlot",      labelDE = "Schulter",   labelEN = "Shoulder"    },
  { key = "BackSlot",          labelDE = "Ruecken",    labelEN = "Back"        },
  { key = "ChestSlot",         labelDE = "Brust",      labelEN = "Chest"       },
  { key = "WristSlot",         labelDE = "Handgelenk", labelEN = "Wrist"       },
  { key = "HandsSlot",         labelDE = "Haende",     labelEN = "Hands"       },
  { key = "WaistSlot",         labelDE = "Guertel",    labelEN = "Waist"       },
  { key = "LegsSlot",          labelDE = "Beine",      labelEN = "Legs"        },
  { key = "FeetSlot",          labelDE = "Fuesse",     labelEN = "Feet"        },
  { key = "Finger0Slot",       labelDE = "Ring 1",     labelEN = "Ring 1"      },
  { key = "Finger1Slot",       labelDE = "Ring 2",     labelEN = "Ring 2"      },
  { key = "Trinket0Slot",      labelDE = "Schmuck 1",  labelEN = "Trinket 1"   },
  { key = "Trinket1Slot",      labelDE = "Schmuck 2",  labelEN = "Trinket 2"   },
  { key = "MainHandSlot",      labelDE = "Waffenhand", labelEN = "Main Hand"   },
  { key = "SecondaryHandSlot", labelDE = "Schildhand", labelEN = "Off Hand"    },
  { key = "RangedSlot",        labelDE = "Distanz",    labelEN = "Ranged"      },
}

-- Tragen keine Werte und fliessen NICHT in Scan oder Bewertung ein.
-- Sie stehen nur im Fenster, damit die Puppe dem Charakterfenster
-- entspricht und beide Spalten gleich lang sind.
Gear.DISPLAY_ONLY_SLOTS = {
  { key = "ShirtSlot",  labelDE = "Hemd",        labelEN = "Shirt"  },
  { key = "TabardSlot", labelDE = "Wappenrock",  labelEN = "Tabard" },
}

for i = 1, table.getn(Gear.DISPLAY_ONLY_SLOTS) do
  local s2 = Gear.DISPLAY_ONLY_SLOTS[i]
  s2.id = GetInventorySlotInfo(s2.key)
end

function Gear:SlotLabel(slot)
  return (BLL.locale == "deDE") and slot.labelDE or slot.labelEN
end

-- Slot-IDs einmalig aufloesen
local slotIDs = {}
for i = 1, table.getn(Gear.SLOTS) do
  local id = GetInventorySlotInfo(Gear.SLOTS[i].key)
  slotIDs[Gear.SLOTS[i].key] = id
  Gear.SLOTS[i].id = id
end

------------------------------------------------------------------
-- Signatur der angelegten Ausruestung
--
-- Billiger Vergleich, ob sich ueberhaupt etwas geaendert hat:
-- nur die Itemlinks aneinanderhaengen, kein Tooltip, kein Parsen.
-- UNIT_INVENTORY_CHANGED feuert in Vanilla auch bei Haltbarkeitsverlust,
-- Munition, Taschenaenderungen und Beute - im Kampf also im Sekundentakt.
-- Ohne diesen Vergleich liefe jedes Mal ein voller Scan ueber 17 Slots.
------------------------------------------------------------------

function Gear:Signature()
  local parts = {}
  for i = 1, table.getn(self.SLOTS) do
    local link = GetInventoryItemLink("player", self.SLOTS[i].id)
    table.insert(parts, link or "-")
  end
  return table.concat(parts, "|")
end

function Gear:HasChanged()
  local sig = self:Signature()
  if sig == self.lastSignature then
    return false
  end
  self.lastSignature = sig
  return true
end

------------------------------------------------------------------
-- Angelegte Ausruestung scannen
------------------------------------------------------------------

Gear.equipped = {}     -- [slotKey] = { id, link, name, quality, stats }
Gear.totals   = {}     -- summierte Stats ueber alle Slots

function Gear:ScanEquipped()
  self.equipped = {}
  self.totals   = {}

  for i = 1, table.getn(self.SLOTS) do
    local slot = self.SLOTS[i]
    local link = GetInventoryItemLink("player", slot.id)

    if link then
      local info  = BLL.Scanner:GetItemInfoSafe(link)
      local stats, meta = BLL.Scanner:GetStats(link)

      self.equipped[slot.key] = {
        id      = info and info.id,
        link    = link,
        name    = info and info.name,
        quality = info and info.quality,
        ilvl    = info and info.ilvl,
        stats   = stats or {},
        -- Effektzeilen ohne auslesbaren Wert. Der Slotvergleich braucht
        -- das, um nicht gegen eine Null zu rechnen, hinter der in
        -- Wahrheit ein Proc-Effekt steckt.
        unscored = meta and meta.unscored or nil,
      }

      for k, v in pairs(stats or {}) do
        -- Waffenwerte nicht aufsummieren, das waere sinnlos
        if k ~= "WEAPON_MIN" and k ~= "WEAPON_MAX"
           and k ~= "WEAPON_SPEED" and k ~= "WEAPON_DPS" then
          self.totals[k] = (self.totals[k] or 0) + v
        end
      end
    else
      self.equipped[slot.key] = nil
    end
  end

  -- Fuer den spaeteren Sync mit der Webseite / Desktop Companion
  BananaLootlineChar = BananaLootlineChar or {}
  BananaLootlineChar.gear = self:Serialize()
  BananaLootlineChar.scanned = time()

  BLL:Debug("Ausruestung gescannt (Aenderung erkannt)")
  return self.equipped
end

------------------------------------------------------------------
-- Taschen scannen (Kandidaten, die man schon besitzt)
------------------------------------------------------------------

function Gear:ScanBags()
  local found = {}

  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag)
    for slot = 1, (slots or 0) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local info = BLL.Scanner:GetItemInfoSafe(link)
        -- Nur ausruestbare Items interessieren uns
        if info and info.equipLoc and info.equipLoc ~= "" then
          table.insert(found, {
            id       = info.id,
            link     = link,
            name     = info.name,
            quality  = info.quality,
            equipLoc = info.equipLoc,
            bag      = bag,
            slot     = slot,
            stats    = BLL.Scanner:GetStats(link) or {},
          })
        end
      end
    end
  end

  self.bagItems = found
  return found
end

------------------------------------------------------------------
-- Serialisierung fuer SavedVariables
--
-- Bewusst schlank gehalten: nur IDs und Slots. Alles andere kann der
-- Empfaenger (Webseite / Desktop Companion) aus der ID rekonstruieren.
------------------------------------------------------------------

function Gear:Serialize()
  local out = {
    class   = BLL.player and BLL.player.class,
    race    = BLL.player and BLL.player.race,
    level   = BLL.player and BLL.player.level,
    name    = BLL.player and BLL.player.name,
    realm   = GetCVar and GetCVar("realmName") or nil,
    slots   = {},
  }

  for i = 1, table.getn(self.SLOTS) do
    local slot = self.SLOTS[i]
    local item = self.equipped[slot.key]
    if item and item.id then
      out.slots[slot.key] = item.id
    end
  end

  return out
end

------------------------------------------------------------------
-- Debugausgabe
------------------------------------------------------------------

function Gear:DumpEquipped()
  for i = 1, table.getn(self.SLOTS) do
    local slot = self.SLOTS[i]
    local item = self.equipped[slot.key]
    local line = "  |cffaaaaaa" .. self:SlotLabel(slot) .. ":|r "

    if item then
      -- Stats in fester Reihenfolge ausgeben statt in pairs()-Zufallsreihenfolge,
      -- damit sich zwei Scans vergleichen lassen.
      local s = ""
      for j = 1, table.getn(BLL.STATS) do
        local k = BLL.STATS[j]
        local v = item.stats[k]
        if v then
          -- Vorzeichen sauber setzen: sonst steht da "SPI+-3"
          local sign = (v < 0) and "" or "+"
          s = s .. k .. sign .. v .. " "
        end
      end
      if s == "" then s = "|cffff6666keine Stats erkannt|r " end

      line = line .. (item.link or item.name or "?")
        .. " |cff555555#" .. tostring(item.id or "?") .. "|r"
        .. "  |cff666666" .. s .. "|r"
    else
      line = line .. "|cff666666" .. BLL.L["EMPTY"] .. "|r"
    end

    DEFAULT_CHAT_FRAME:AddMessage(line)
  end

  local t = ""
  for j = 1, table.getn(BLL.STATS) do
    local k = BLL.STATS[j]
    local v = self.totals[k]
    if v and v ~= 0 then
      t = t .. k .. "=" .. v .. "  "
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff" .. BLL.L["STATS_HEADER"] .. ":|r " .. t)
end
