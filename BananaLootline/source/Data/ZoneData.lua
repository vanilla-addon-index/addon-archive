--[[----------------------------------------------------------------------
  BananaLootline - Data/ZoneData.lua

  Stammdaten der Instanzen: Kategorie, Stufenbereich, Mindeststufe und
  Kuerzel. Schluessel ist der normalisierte Zonenname - klein, ohne
  Leer- und Sonderzeichen, damit "Zul'Farrak" und "ZulFarrak" denselben
  Eintrag treffen.

  Die Kategorie leitet sich aus der Gruppengroesse ab: 5 Spieler heisst
  Dungeon, mehr heisst Raid. Das ist verlaesslicher als eine von Hand
  gepflegte Liste - in meiner waren zwei Eintraege falsch (Timbermaw Hold
  und Blackrock Spire sind Raids, keine Dungeons).

  Inhalt sind Sachangaben zum Spiel: Instanznamen, Stufenbereiche,
  Gruppengroessen. Abgeglichen mit der Atlas-Instanzuebersicht fuer
  TurtleWoW. Weder Code noch Inhalte aus Atlas wurden uebernommen - das
  Addon steht unter GPL, was BananaLootline daran gebunden haette.

  Erzeugt: 2026-09-17
  Eintraege: 50
------------------------------------------------------------------------]]

BananaLootlineZoneData = {
["alteracvalley"]={c="SCHLACHTFELD",lvl="51-60",min=51,acr="AV"},
["arathibasin"]={c="SCHLACHTFELD",lvl="20-60",min=20,acr="AB"},
["azuregos"]={c="WELTBOSS"},
["blackfathomdeeps"]={c="DUNGEON",lvl="24-32",min=19,acr="BFD"},
["blackmorass"]={c="DUNGEON",lvl="60-60",min=58,acr="BM"},
["blackrockdepths"]={c="DUNGEON",lvl="52-60",min=42,acr="BRD"},
["blackwinglair"]={c="RAID",lvl="60+",min=60,acr="BWL"},
["clackora"]={c="WELTBOSS"},
["darkreaverofkarazhan"]={c="WELTBOSS"},
["diremaul"]={c="DUNGEON",lvl="57-60",min=50,acr="DMW"},
["dragonmawretreat"]={c="DUNGEON",lvl="25-35",min=25,acr="DMR"},
["emeralddragons"]={c="WELTBOSS"},
["emeraldsanctum"]={c="RAID",lvl="58-60",min=58,acr="ES"},
["frostmanehollow"]={c="DUNGEON",lvl="13-20",min=13,acr="FMH"},
["gilneascity"]={c="DUNGEON",lvl="43-49",min=43,acr="GC"},
["gnomeregan"]={c="DUNGEON",lvl="29-38",min=19,acr="Gnome"},
["hateforgequarry"]={c="DUNGEON",lvl="52-60",min=48,acr="HFQ"},
["karazhancrypt"]={c="DUNGEON",lvl="58-60",min=58,acr="Kara Crypt"},
["lordkazzak"]={c="WELTBOSS"},
["lowerblackrockspire"]={c="RAID",lvl="55-60",min=55,acr="LBRS"},
["lowerkarazhanhalls"]={c="RAID",lvl="58-60",min=58,acr="LKH"},
["maraudon"]={c="DUNGEON",lvl="46-55",min=35,acr="Mara"},
["moltencore"]={c="RAID",lvl="60+",min=60,acr="MC"},
["moo"]={c="WELTBOSS"},
["naxxramas"]={c="RAID",lvl="60+",min=60,acr="Naxx"},
["nerubianoverseer"]={c="WELTBOSS"},
["onyxiaslair"]={c="RAID",lvl="60+",min=60,acr="Ony"},
["ragefirechasm"]={c="DUNGEON",lvl="13-18",min=8,acr="RFC"},
["razorfendowns"]={c="DUNGEON",lvl="37-46",min=25,acr="RFD"},
["razorfenkraul"]={c="DUNGEON",lvl="29-38",min=19,acr="RFK"},
["ruinsofahnqiraj"]={c="RAID",lvl="60+",min=60,acr="AQ20"},
["scarletmonastery"]={c="DUNGEON",lvl="26-36",min=25,acr="SM GY"},
["scholomance"]={c="DUNGEON",lvl="58-60",min=45,acr="Scholo"},
["shadowfangkeep"]={c="DUNGEON",lvl="22-30",min=14,acr="SFK"},
["stormwindvault"]={c="DUNGEON",lvl="60-60",min=58,acr="SWV"},
["stormwroughtruins"]={c="DUNGEON",lvl="32-44",min=25,acr="SWR"},
["stratholme"]={c="DUNGEON",lvl="58-60",min=45,acr="Strat"},
["sunkentemple"]={c="DUNGEON",lvl="50-60",min=35,acr="ST"},
["templeofahnqiraj"]={c="RAID",lvl="60+",min=60,acr="AQ40"},
["thecrescentgrove"]={c="DUNGEON",lvl="32-38",min=32,acr="CG"},
["thedeadmines"]={c="DUNGEON",lvl="17-24",min=10,acr="DM"},
["thestockade"]={c="DUNGEON",lvl="24-31",min=15,acr="Stocks"},
["timbermawhold"]={c="RAID",lvl="60+",min=60,acr="TMH"},
["uldaman"]={c="DUNGEON",lvl="41-51",min=30,acr="Ulda"},
["upperblackrockspire"]={c="RAID",lvl="55-60",min=55,acr="UBRS"},
["wailingcaverns"]={c="DUNGEON",lvl="17-24",min=10,acr="WC"},
["warsonggulch"]={c="SCHLACHTFELD",lvl="10-60",min=10,acr="WSG"},
["windhorncanyon"]={c="DUNGEON",lvl="25-33",min=25,acr="WHC"},
["zulfarrak"]={c="DUNGEON",lvl="44-54",min=30,acr="ZF"},
["zulgurub"]={c="RAID",lvl="60+",min=60,acr="ZG"},
}
