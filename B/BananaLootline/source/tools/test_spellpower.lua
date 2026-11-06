-- Zauberschaden und Heilung.
--
-- In Vanilla steht auf den meisten Zauberteilen eine einzige Zeile:
-- "Increases damage and healing done by magical spells and effects by up
-- to N." Die gibt beides. Der Importer trug daraus bis 0.22.6 nur
-- SPELLPOWER ein, und damit fehlte 1443 Teilen ihr Heilwert komplett.
--
-- Fuer einen Heiler stand die Rangfolge dadurch auf dem Kopf. Ein Teil
-- mit "22 Schaden und Heilung" bekam 22 Punkte, ein Teil mit "22
-- Heilung" 35 - obwohl das erste dieselbe Heilung gibt und den
-- Zauberschaden obendrein.
--
-- Bei 49 Teilen kommt eine zweite Zeile mit zusaetzlicher Heilung dazu,
-- und die addiert sich. Das sind die Heilersets der ersten Raidstufe:
-- Circlet of Prophecy fuehrt "12 Schaden und Heilung" plus "11 Heilung",
-- also 12 Zauberschaden und 23 Heilung. Vorher stand dort 11.
string.gmatch = nil; select = nil

dofile("Data/ItemData.lua")
local I = BananaLootlineItemData

local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

------------------------------------------------------------------
-- 1. Die Einzelzeile schlaegt auf beide Werte durch
------------------------------------------------------------------

-- Robe of the Magi: "Increases damage and healing ... by up to 22."
local robe = I[1716]
check(robe ~= nil, "Robe of the Magi steht im Bestand")
if robe then
  check(robe.stats.SPELLPOWER == 22,
    "22 Zauberschaden, sind " .. tostring(robe.stats.SPELLPOWER))
  check(robe.stats.HEALPOWER == 22,
    "und 22 Heilung, sind " .. tostring(robe.stats.HEALPOWER))
end

-- Runed Ring, derselbe Fall mit 7
local ring = I[862]
if ring then
  check(ring.stats.HEALPOWER == ring.stats.SPELLPOWER,
    "Runed Ring fuehrt beide Werte gleich")
end

------------------------------------------------------------------
-- 2. Zwei Zeilen addieren sich
------------------------------------------------------------------

local PROPHECY = {
  [16813] = { sp = 12, hp = 23 },   -- Circlet, 12 + 11
  [16811] = { sp = 11, hp = 18 },   -- Boots, 11 + 7
  [16816] = { sp =  9, hp = 16 },   -- Mantle, 9 + 7
}
for id, want in pairs(PROPHECY) do
  local e = I[id]
  check(e ~= nil, "Teil " .. id .. " steht im Bestand")
  if e then
    check(e.stats.SPELLPOWER == want.sp,
      (e.name or id) .. ": " .. want.sp .. " Zauberschaden, sind "
      .. tostring(e.stats.SPELLPOWER))
    check(e.stats.HEALPOWER == want.hp,
      (e.name or id) .. ": " .. want.hp .. " Heilung, sind "
      .. tostring(e.stats.HEALPOWER))
  end
end

------------------------------------------------------------------
-- 3. Reine Heilung bleibt reine Heilung
--
-- "Increases healing done by spells and effects by up to N" gibt keinen
-- Zauberschaden. Wer das gleichsetzt, macht aus jedem Heilerteil ein
-- Schadensteil.
------------------------------------------------------------------

local healOnly, bothSame, wrong = 0, 0, {}
for id, e in pairs(I) do
  local st = e.stats
  if st and st.HEALPOWER then
    if not st.SPELLPOWER then
      healOnly = healOnly + 1
    elseif st.HEALPOWER == st.SPELLPOWER then
      bothSame = bothSame + 1
    end
    -- Heilung darf nie kleiner als der Zauberschaden sein: die
    -- gemeinsame Zeile gibt beides gleich, zusaetzliche Zeilen erhoehen
    -- nur die Heilung.
    if st.SPELLPOWER and st.HEALPOWER < st.SPELLPOWER then
      table.insert(wrong, (e.name or id))
    end
  end
end
check(healOnly > 400,
  "ueber 400 Teile fuehren nur Heilung, sind " .. healOnly)
check(table.getn(wrong) == 0,
  "kein Teil fuehrt weniger Heilung als Zauberschaden, betroffen: "
  .. table.concat(wrong, ", "))

------------------------------------------------------------------
-- 4. Der Umfang, als Zahl im Protokoll
------------------------------------------------------------------

local withHeal = 0
for id, e in pairs(I) do
  if e.stats and e.stats.HEALPOWER then withHeal = withHeal + 1 end
end
check(withHeal > 1900,
  "ueber 1900 Teile fuehren einen Heilwert, sind " .. withHeal)
print("   Teile mit Heilwert: " .. withHeal
      .. " (davon " .. bothSame .. " gleich dem Zauberschaden, "
      .. healOnly .. " ohne Zauberschaden)")

------------------------------------------------------------------
-- 5. Geschaetzte Anforderungsstufen sind als geschaetzt markiert
--
-- 3362 anlegbare Teile fuehren im Export keine Anforderungsstufe. Der
-- Importer schaetzt sie als Itemstufe minus 5, begrenzt auf 1 bis 60.
-- reqest=1 haelt fest, dass die Zahl geschaetzt ist - eine Schaetzung,
-- die wie eine Messung aussieht, kann niemand mehr nachpruefen.
------------------------------------------------------------------

local est, bad = 0, {}
for id, e in pairs(I) do
  if e.reqest then
    est = est + 1
    if not e.reqlevel then table.insert(bad, id) end
    if e.reqlevel and (e.reqlevel < 1 or e.reqlevel > 60) then
      table.insert(bad, id)
    end
  end
end
check(est > 3000, "ueber 3000 geschaetzte Stufen, sind " .. est)
check(table.getn(bad) == 0,
  "jede geschaetzte Stufe liegt zwischen 1 und 60")

-- Jedes anlegbare Teil hat jetzt eine Anforderungsstufe. Darauf baut ein
-- harter Filter auf.
local noReq = 0
for id, e in pairs(I) do
  if e.slot and e.slot > 0 and not e.reqlevel then noReq = noReq + 1 end
end
check(noReq == 0,
  "kein anlegbares Teil ohne Anforderungsstufe, sind " .. noReq)

print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
