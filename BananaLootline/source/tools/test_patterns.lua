local lines = {
  enUS = {
    { "Equip: Increases ranged attack power by 24.", "RAP" },
    { "Equip: Increases attack power by 20.", "AP" },
    { "Equip: Improves your chance to hit by 1%.", "HIT" },
    { "Equip: Improves your chance to hit with spells by 1%.", "SPELLHIT" },
    { "Equip: Improves your chance to get a critical strike by 1%.", "CRIT" },
    { "Equip: Improves your chance to get a critical strike with spells by 1%.", "SPELLCRIT" },
    { "Equip: Increases damage and healing done by magical spells and effects by up to 12.", "SPELLPOWER" },
    { "Equip: Increases healing done by spells and effects by up to 22.", "HEALPOWER" },
    { "Equip: Increases damage done by Fire spells and effects by up to 10.", "SPELLPOWER_FIRE" },
    { "Equip: Restores 3 mana per 5 sec.", "MP5" },
    { "Equip: Increased Defense +7.", "DEFENSE" },
    { "Equip: Increases your chance to dodge an attack by 1%.", "DODGE" },
    { "Equip: Increases your chance to parry an attack by 1%.", "PARRY" },
    { "Equip: Increases your chance to block attacks with a shield by 1%.", "BLOCK" },
  },
  deDE = {
    { "Anlegen: Erh\195\182ht die Distanzangriffskraft um 24.", "RAP" },
    { "Anlegen: Erh\195\182ht die Angriffskraft um 20.", "AP" },
    { "Anlegen: Verteidigung +7.", "DEFENSE" },
  },
}
local bad = 0
for loc, list in pairs(lines) do
  BananaLootline = {}
  GetLocale = function() return loc end
  dofile("Locale.lua")
  local P = BananaLootline.PATTERNS
  for _, l in ipairs(list) do
    local first
    for i = 1, table.getn(P) do
      local _, _, v = string.find(l[1], P[i][2])
      if v then first = P[i][1]; break end
    end
    if first ~= l[2] then bad = bad + 1; print("FEHLER:", loc, l[2], "->", tostring(first)) end
  end
end
print(bad == 0 and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
