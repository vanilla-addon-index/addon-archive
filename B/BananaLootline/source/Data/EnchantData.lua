--[[----------------------------------------------------------------------
  BananaLootline - Data/EnchantData.lua

  ERZEUGT von tools/octodb_enchants_build.py aus der
  OctoWoW-Datenbank. Nicht von Hand bearbeiten - der naechste
  Lauf ueberschreibt die Datei.

  Felder:
    n    Name
    st   Werte, gleiche Schluessel wie bei Items
    dmg  flacher Waffenschaden. Wird beim Bewerten mit dem Tempo
         der angelegten Waffe in DPS umgerechnet.
    req  benoetigte Itemstufe
    src  Beruf

  Erzeugt: 2026-09-18 17:10
------------------------------------------------------------------------]]

BananaLootlineEnchantData = {

  BackSlot = {
    { n = "Enchant Cloak - Superior Defense", id = 20015, st = { ARMOR = 70 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Greater Defense", id = 13746, st = { ARMOR = 50 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Defense", id = 13635, st = { ARMOR = 30 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Greater Resistance", id = 20014, st = { RES_ARCANE = 5, RES_FIRE = 5, RES_FROST = 5, RES_NATURE = 5, RES_SHADOW = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Lesser Protection", id = 13421, st = { ARMOR = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Resistance", id = 13794, st = { RES_ARCANE = 3, RES_FIRE = 3, RES_FROST = 3, RES_NATURE = 3, RES_SHADOW = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Greater Fire Resistance", id = 25081, st = { RES_FIRE = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Greater Nature Resistance", id = 25082, st = { RES_NATURE = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Minor Protection", id = 7771, st = { ARMOR = 10 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Lesser Shadow Resistance", id = 13522, st = { RES_SHADOW = 10 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Fire Resistance", id = 13657, st = { RES_FIRE = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Minor Resistance", id = 7454, st = { RES_ARCANE = 1, RES_FIRE = 1, RES_FROST = 1, RES_NATURE = 1, RES_SHADOW = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Lesser Fire Resistance", id = 7861, st = { RES_FIRE = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Lesser Agility", id = 13882, st = { AGI = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Cloak - Minor Agility", id = 13419, st = { AGI = 1 }, src = "Verzauberkunst" },
  },

  ChestSlot = {
    { n = "Enchant Chest - Major Health", id = 20026, st = { HEALTH = 100 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Major Mana", id = 20028, st = { MANA = 100 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Superior Mana", id = 13917, st = { MANA = 65 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Greater Mana", id = 13663, st = { MANA = 50 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Superior Health", id = 13858, st = { HEALTH = 50 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Greater Health", id = 13640, st = { HEALTH = 35 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Mana", id = 13607, st = { MANA = 30 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Health", id = 7857, st = { HEALTH = 25 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Lesser Mana", id = 7776, st = { MANA = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Greater Stats", id = 20025, st = { AGI = 4, INT = 4, SPI = 4, STA = 4, STR = 4 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Lesser Health", id = 7748, st = { HEALTH = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Stats", id = 13941, st = { AGI = 3, INT = 3, SPI = 3, STA = 3, STR = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Lesser Stats", id = 13700, st = { AGI = 2, INT = 2, SPI = 2, STA = 2, STR = 2 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Minor Health", id = 7420, st = { HEALTH = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Minor Mana", id = 7443, st = { MANA = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Chest - Minor Stats", id = 13626, st = { AGI = 1, INT = 1, SPI = 1, STA = 1, STR = 1 }, src = "Verzauberkunst" },
  },

  WristSlot = {
    { n = "Enchant Bracer - Superior Spirit", id = 20009, st = { SPI = 9 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Superior Strength", id = 20010, st = { STR = 9 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Superior Stamina", id = 20011, st = { STA = 9 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Greater Spirit", id = 13846, st = { SPI = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Greater Strength", id = 13939, st = { STR = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Greater Stamina", id = 13945, st = { STA = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Greater Intellect", id = 20008, st = { INT = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Health", id = 7418, st = { HEALTH = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Spirit", id = 13642, st = { SPI = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Stamina", id = 13648, st = { STA = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Strength", id = 13661, st = { STR = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Intellect", id = 13822, st = { INT = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Mana Regeneration", id = 23801, st = { MP5 = 4 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Lesser Spirit", id = 7859, st = { SPI = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Lesser Stamina", id = 13501, st = { STA = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Lesser Strength", id = 13536, st = { STR = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Lesser Intellect", id = 13622, st = { INT = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Deflection", id = 13931, st = { DEFENSE = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Lesser Deflection", id = 13646, st = { DEFENSE = 2 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Deflect", id = 7428, st = { DEFENSE = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Stamina", id = 7457, st = { STA = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Spirit", id = 7766, st = { SPI = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Agility", id = 7779, st = { AGI = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Bracer - Minor Strength", id = 7782, st = { STR = 1 }, src = "Verzauberkunst" },
  },

  HandsSlot = {
    { n = "Enchant Gloves - Shadow Power", id = 25073, st = { SPELLPOWER_SHADOW = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Frost Power", id = 25074, st = { SPELLPOWER_FROST = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Fire Power", id = 25078, st = { SPELLPOWER_FIRE = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Superior Agility", id = 25080, st = { AGI = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Greater Agility", id = 20012, st = { AGI = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Greater Strength", id = 20013, st = { STR = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Agility", id = 13815, st = { AGI = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Gloves - Strength", id = 13887, st = { STR = 5 }, src = "Verzauberkunst" },
  },

  FeetSlot = {
    { n = "Enchant Boots - Greater Stamina", id = 20020, st = { STA = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Greater Agility", id = 20023, st = { AGI = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Stamina", id = 13836, st = { STA = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Agility", id = 13935, st = { AGI = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Spirit", id = 20024, st = { SPI = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Lesser Agility", id = 13637, st = { AGI = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Lesser Stamina", id = 13644, st = { STA = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Lesser Spirit", id = 13687, st = { SPI = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Minor Stamina", id = 7863, st = { STA = 1 }, src = "Verzauberkunst" },
    { n = "Enchant Boots - Minor Agility", id = 7867, st = { AGI = 1 }, src = "Verzauberkunst" },
  },

  MainHandSlot = {
    { n = "Enchant Weapon - Crusader", id = 20034, st = { STR = 100 }, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Superior Impact", id = 20030, dmg = 9, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Agility", id = 27837, st = { AGI = 25 }, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Mighty Intellect", id = 23804, st = { INT = 22 }, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Greater Impact", id = 13937, dmg = 7, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Mighty Spirit", id = 23803, st = { SPI = 20 }, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Lesser Beastslayer", id = 13653, dmg = 6, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Lesser Elemental Slayer", id = 13655, dmg = 6, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Impact", id = 13695, dmg = 5, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Superior Striking", id = 20031, dmg = 5, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Strength", id = 23799, st = { STR = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Agility", id = 23800, st = { AGI = 15 }, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Greater Striking", id = 13943, dmg = 4, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Lesser Impact", id = 13529, dmg = 3, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Striking", id = 13693, dmg = 3, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Major Intellect", id = 20036, st = { INT = 9 }, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Major Spirit", id = 20035, st = { SPI = 9 }, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Minor Beastslayer", id = 7786, dmg = 2, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Minor Impact", id = 7745, dmg = 2, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Lesser Striking", id = 13503, dmg = 2, src = "Verzauberkunst" },
    { n = "Enchant Weapon - Minor Striking", id = 7788, dmg = 1, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Lesser Intellect", id = 7793, st = { INT = 3 }, src = "Verzauberkunst" },
    { n = "Enchant 2H Weapon - Lesser Spirit", id = 13380, st = { SPI = 3 }, src = "Verzauberkunst" },
  },

  SecondaryHandSlot = {
    { n = "Enchant Shield - Lesser Protection", id = 13464, st = { ARMOR = 30 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Superior Spirit", id = 20016, st = { SPI = 9 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Frost Resistance", id = 13933, st = { RES_FROST = 8 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Greater Spirit", id = 13905, st = { SPI = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Greater Stamina", id = 20017, st = { STA = 7 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Spirit", id = 13659, st = { SPI = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Stamina", id = 13817, st = { STA = 5 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Lesser Spirit", id = 13485, st = { SPI = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Lesser Stamina", id = 13631, st = { STA = 3 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Lesser Block", id = 13689, st = { BLOCK = 2 }, src = "Verzauberkunst" },
    { n = "Enchant Shield - Minor Stamina", id = 13378, st = { STA = 1 }, src = "Verzauberkunst" },
  },

  RangedSlot = {
    { n = "Sniper Scope", dmg = 7, req = 40, src = "Ingenieurskunst" },
    { n = "Accurate Scope", dmg = 5, req = 30, src = "Ingenieurskunst" },
    { n = "Standard Scope", dmg = 3, req = 20, src = "Ingenieurskunst" },
    { n = "Crude Scope", dmg = 2, req = 10, src = "Ingenieurskunst" },
  },
}
