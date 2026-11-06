--[[----------------------------------------------------------------------
  BananaLootline - EnchantDB.lua

  Bewertet Verzauberungen mit denselben Gewichten wie Items und liefert
  pro Slot die sinnvollsten.

  Zwei Besonderheiten gegenueber Items:

  1. Zielfernrohre geben FLACHEN Schaden, keinen DPS-Wert. Was das
     wert ist, haengt vom Tempo der angelegten Waffe ab: +7 Schaden
     auf einer Waffe mit Tempo 2,0 sind 3,5 DPS, auf Tempo 3,5 nur 2.
     Deshalb wird mit dem tatsaechlichen Tempo umgerechnet.

  2. Manche Verzauberungen sind Procs, etwa Crusader. Die lassen sich
     nicht sauber in feste Werte umrechnen; der hinterlegte Wert ist
     eine grobe Naeherung und als solche gekennzeichnet.
------------------------------------------------------------------------]]

BananaLootline = BananaLootline or {}
local BLL = BananaLootline

BananaLootlineEnchantData = BananaLootlineEnchantData or {}

BLL.EnchantDB = {}
local EnchantDB = BLL.EnchantDB

function EnchantDB:Refresh()
  self.data = BananaLootlineEnchantData or {}
  self.count = 0
  for _, list in pairs(self.data) do
    self.count = self.count + table.getn(list)
  end
  self.loaded = (self.count > 0)
  return self.count
end

EnchantDB:Refresh()

------------------------------------------------------------------
-- Tempo der angelegten Waffe, fuer die Umrechnung von Zielfernrohren
------------------------------------------------------------------

function EnchantDB:WeaponSpeed(slotKey)
  local item = BLL.Gear.equipped[slotKey]
  if item and item.stats and item.stats.WEAPON_SPEED then
    return item.stats.WEAPON_SPEED
  end
  return 2.8   -- Mittelwert, wenn nichts angelegt ist
end

------------------------------------------------------------------
-- Was passt ueberhaupt zu diesem Charakter?
--
-- Die Gewichtung allein reicht nicht. Sie sortiert zwar aus, was
-- wertlos ist - ein Jaeger bekommt keine Intelligenzverzauberung, weil
-- sie 0 Punkte bringt. Sie merkt aber nicht, dass eine
-- Schildverzauberung fuer einen Schurken sinnlos ist, weil er nie
-- einen Schild traegt, oder dass eine Zweihandverzauberung nicht auf
-- die angelegte Einhandwaffe passt.
------------------------------------------------------------------

local SHIELD_CLASSES = {
  WARRIOR = 1, PALADIN = 1, SHAMAN = 1,
}

function EnchantDB:FitsCharacter(slotKey, name)
  local class = BLL.player and BLL.player.class
  name = name or ""

  -- Schilde: nur fuer Klassen, die welche fuehren duerfen
  if slotKey == "SecondaryHandSlot" and string.find(name, "Shield") then
    if not SHIELD_CLASSES[class or ""] then return false end
  end

  -- Ein- und Zweihandverzauberungen muessen zur angelegten Waffe passen
  if slotKey == "MainHandSlot" then
    local weapon = BLL.Gear.equipped["MainHandSlot"]
    local twoHanded = nil
    if weapon and weapon.id and BLL.ItemDB and BLL.ItemDB.loaded then
      local e = BLL.ItemDB:Get(weapon.id)
      if e and e.slot then
        twoHanded = (e.slot == 17)
      end
    end

    local isTwoHandEnchant = string.find(name, "2H Weapon")
      or string.find(name, "[Tt]wo%-Handed")

    if twoHanded ~= nil then
      if isTwoHandEnchant and not twoHanded then return false end
      if not isTwoHandEnchant and twoHanded
         and string.find(name, "Enchant Weapon") then
        -- Einhandverzauberungen gelten in Vanilla auch fuer
        -- Zweihaender, deshalb hier KEIN Ausschluss - nur der
        -- umgekehrte Fall ist ein Fehler.
      end
    end
  end

  return true
end

------------------------------------------------------------------
-- Empfehlungen fuer einen Slot
------------------------------------------------------------------

function EnchantDB:GetForSlot(slotKey, maxResults)
  if not self.loaded then return nil end
  local list = self.data[slotKey]
  if not list then return nil end

  maxResults = maxResults or 3
  local isWeapon = (slotKey == "MainHandSlot" or slotKey == "SecondaryHandSlot"
                    or slotKey == "RangedSlot")
  local speed = self:WeaponSpeed(slotKey)
  local level = (BLL.player and BLL.player.level) or 60

  local out = {}
  for i = 1, table.getn(list) do
    local e = list[i]
    if self:FitsCharacter(slotKey, e.n) then
    local stats = {}
    if e.st then
      for k, v in pairs(e.st) do stats[k] = v end
    end

    -- Flacher Schaden in DPS umrechnen
    if e.dmg then
      stats.WEAPON_DPS = (stats.WEAPON_DPS or 0) + (e.dmg / speed)
    end

    local score = BLL.Weights:Score(stats, isWeapon)
    if score > 0 then
      table.insert(out, {
        id      = e.id,
        name    = e.n,
        stats   = stats,
        rawDmg  = e.dmg,
        src     = e.src,
        req     = e.req,
        note    = e.note,
        -- Kennzeichnen statt ausblenden: eine Verzauberung, fuer die
        -- das Item noch zu niedrig ist, bleibt ein sinnvolles Ziel.
        locked  = (e.req and e.req > level) or nil,
        score   = score,
      })
    end
    end
  end

  table.sort(out, function(a, b) return a.score > b.score end)

  local trimmed = {}
  for i = 1, math.min(maxResults, table.getn(out)) do
    table.insert(trimmed, out[i])
  end
  return trimmed
end

------------------------------------------------------------------
-- Alle Slots auf einmal, fuer die Uebersicht
------------------------------------------------------------------

function EnchantDB:GetAll(maxPerSlot)
  if not self.loaded then return nil end

  local out = {}
  for i = 1, table.getn(BLL.Gear.SLOTS) do
    local slot = BLL.Gear.SLOTS[i]
    local recs = self:GetForSlot(slot.key, maxPerSlot or 3)
    if recs and table.getn(recs) > 0 then
      table.insert(out, {
        slotKey  = slot.key,
        slotName = BLL.Gear:SlotLabel(slot),
        -- Ein leerer Slot kann nicht verzaubert werden. Der Hinweis
        -- gehoert trotzdem in die Liste, sonst wundert man sich,
        -- warum der Slot fehlt.
        empty    = (BLL.Gear.equipped[slot.key] == nil) or nil,
        items    = recs,
      })
    end
  end
  return out
end
