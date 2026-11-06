--[[----------------------------------------------------------------------
  BananaLootline - ItemDB.lua

  Zugriff auf die importierten Itemdaten. Die Daten selbst stehen in
  Data/ItemData.lua und werden VOR dieser Datei geladen.

  Wichtig: diese Datei niemals mit dem Importergebnis ueberschreiben.
  Das Importziel ist Data/ItemData.lua.

  Der Import liefert genau die Felder, die der 1.12-Client nicht hat:
  Itemlevel (GetItemInfo gibt nur die benoetigte Stufe), Klassen- und
  Rassenmaske, Slot und Qualitaet.

  Format:
    BananaLootlineItemData[itemID] = {
      name = "...", ilvl = 66, quality = 4, slot = 1, reqlevel = 60,
      itemclass = 4, subclass = 1, classmask = 128, racemask = -1,
      stats = { STA = 14, INT = 10 },
    }
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline

-- Fallback, falls Data/ItemData.lua fehlt oder nicht geladen wurde.
BananaLootlineItemData = BananaLootlineItemData or {}

BLL.ItemDB = {}
local ItemDB = BLL.ItemDB

-- Zaehlt die geladenen Eintraege neu. Wird beim Laden und noch einmal
-- beim Betreten der Welt aufgerufen, damit die Ladereihenfolge der
-- Dateien keine Rolle spielt.
function ItemDB:Refresh()
  self.data  = BananaLootlineItemData or {}
  self.count = 0
  for _ in pairs(self.data) do
    self.count = self.count + 1
  end
  self.loaded = (self.count > 0)
  return self.count
end

ItemDB:Refresh()

function ItemDB:Get(itemID)
  if not itemID then return nil end
  return self.data[itemID]
end

-- Symbolpfad eines Gegenstands.
--
-- GetItemInfo liefert die Textur nur fuer Gegenstaende, die der Client
-- schon einmal gesehen hat. Alles andere stand im Fenster als
-- Fragezeichen - und das betrifft gerade die Teile, die man noch nicht
-- hat, also genau die, um die es in einem Ausruestungsplaner geht.
--
-- Der Import fuehrt den Namen der Textur ohne Pfad. Der Pfad ist immer
-- derselbe; der Client sucht ihn ohne Ruecksicht auf Gross- und
-- Kleinschreibung.
local ICON_PATH = "Interface\\Icons\\"

function ItemDB:IconPath(itemID)
  local e = self:Get(itemID)
  if not e or not e.icon then return nil end
  return ICON_PATH .. e.icon
end

function ItemDB:GetLevel(itemID)
  local e = self:Get(itemID)
  return e and e.ilvl or nil
end

-- Alle Items eines Slots, optional nach maximalem Itemlevel gefiltert.
-- Grundlage fuer die spaetere Upgrade-Suche.
function ItemDB:GetBySlot(slotType, maxIlvl)
  local out = {}
  for id, e in pairs(self.data) do
    if e.slot == slotType and (not maxIlvl or (e.ilvl or 0) <= maxIlvl) then
      table.insert(out, id)
    end
  end
  return out
end

-- Klassenbitmasken des 1.12-Servers
ItemDB.CLASS_BITS = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 4,  ROGUE  = 8,
  PRIEST  = 16,             SHAMAN = 64, MAGE   = 128,
  WARLOCK = 256,            DRUID  = 1024,
}

-- Prueft eine Klassenmaske direkt. 0 und -1 bedeuten "keine Beschraenkung".
-- Lua 5.0 hat keine Bitoperatoren, deshalb der Modulo-Trick.
function ItemDB:MaskAllows(mask, class)
  if not mask or mask == 0 or mask == -1 then return true end
  local bit = self.CLASS_BITS[class or ""]
  if not bit then return true end
  return math.mod(math.floor(mask / bit), 2) == 1
end

function ItemDB:UsableByClass(itemID, class)
  local e = self:Get(itemID)
  if not e or not e.classmask or e.classmask == 0 then
    return true   -- keine Beschraenkung
  end
  return self:MaskAllows(e.classmask, class)
end
