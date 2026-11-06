ElkBuffBarColors = {
	-- auras (mounts, passives — transparent when untilCancelled)
	[0]		= {r=0.1,g=0.1,b=0.1};
	-- special buffs (world buffs, rare procs)
	[2]		= {r=0.5,g=0.5,b=0.9};
	-- class colors
	[21]	= {r=0.78,g=0.61,b=0.43};	-- Warrior
	[22]	= {r=0.96,g=0.55,b=0.73};	-- Paladin
	[23]	= {r=0.67,g=0.83,b=0.45};	-- Hunter
	[24]	= {r=1,g=0.96,b=0.41};		-- Rogue
	[25]	= {r=1,g=1,b=1};			-- Priest
	[26]	= {r=0,g=0.44,b=0.87};		-- Shaman
	[27]	= {r=0.41,g=0.8,b=0.94};	-- Mage
	[28]	= {r=0.58,g=0.51,b=0.79};	-- Warlock
	[29]	= {r=1,g=0.49,b=0.04};		-- Druid
	-- prot pots
	[50]	= {r=0.3,g=0.3,b=1};
	-- scrolls
	[55]	= {r=0.57,g=1,b=0.25};
	-- ========================================
	-- CONSUMABLES: sorted by duration
	-- RIGHT (lowest cat) = longest duration
	-- LEFT  (highest cat) = shortest duration
	-- ========================================
	-- flasks (2h, persist through death) — rightmost consume
	[60]	= {r=0.2,g=0.4,b=0.6};
	-- zanza (2h)
	[61]	= {r=0.2,g=0.4,b=0.6};
	-- 1h damage elixirs
	[62]	= {r=0.2,g=0.4,b=0.6};
	-- 1h defensive/stat elixirs
	[63]	= {r=0.2,g=0.4,b=0.6};
	-- blasted lands (1h)
	[64]	= {r=0.2,g=0.4,b=0.6};
	-- 1h utility defense (Fortitude)
	[65]	= {r=0.2,g=0.4,b=0.6};
	-- 1h utility mana (Mageblood)
	[66]	= {r=0.2,g=0.4,b=0.6};
	-- 1h misc utility (Gift of Arthas etc.)
	[67]	= {r=0.2,g=0.4,b=0.6};
	-- 30-60min TurtleWoW elixirs (Dreamshard etc.)
	[68]	= {r=0.2,g=0.4,b=0.6};
	-- 20min buffs (Juju, Winterfall etc.)
	[69]	= {r=0.2,g=0.4,b=0.6};
	-- 20min TurtleWoW (Dreamtonic, Concoctions)
	[70]	= {r=0.2,g=0.4,b=0.6};
	-- 15min drinks/alcohol (Rumsey, Medivh's)
	[71]	= {r=0.2,g=0.4,b=0.6};
	-- 15min food (Well Fed etc.)
	[72]	= {r=0.2,g=0.4,b=0.6};
	-- on-use / very short duration (<5min)
	[73]	= {r=0.8,g=0.4,b=1};
	-- trinkets
	[90]	= {r=0.33,g=0.54,b=0.52};
	-- food/drink indicators
	[100]	= {r=0.7,g=0.7,b=0.7};
};

ElkBuffBarData = {
	-- ==========================================
	-- [0] AURAS — untilCancelled, transparent
	-- Only mounts, item auras, passive effects
	-- Class-specific auras → class categories
	-- ==========================================
	[0] = {
		-- item auras
		"Argent Dawn Commission",
		"Ashbringer",
		-- mounts
		"Black Qiraji Resonating Crystal",
		"Blue Qiraji Resonating Crystal",
		"Green Qiraji Resonating Crystal",
		"Red Qiraji Resonating Crystal",
		"Yellow Qiraji Resonating Crystal",
		"Big Battle Bear",
		"Black Battlestrider",
		"Black War Kodo",
		"Black War Ram",
		"Black War Steed Bridle",
		"Deathcharger's Rains",
		"Great Brewfest Kodo",
		"Horn of the Black War Wolf",
		"Horn of the Frostwolf Howler",
		"Red Skeletal Warhorse",
		"Reins of the Swift Frostsaber",
		"Reins of the Swift Spectral Tiger",
		"Reins of the Winterspring Frostsaber",
		"Stormpike Battle Charger",
		"Swift Brewfest Ram",
		"Swift Brown Steed",
		"Swift Palomino",
		"Swift Razzashi Raptor",
		"Swift White Steed",
		"Swift Zulian Tiger",
		"Whistle of the Black War Raptor",
		"Swift Magic Broom",
		"Old Magic Broom",
		"Black Stallion Bridle",
		"Blue Mechanostrider",
		"Blue Skeletal Horse",
		"Brewfest Ram",
		"Brown Horse Bridle",
		"Brown Kodo",
		"Brown Ram",
		"Brown Skeletal Horse",
		"Chestnut Mare Bridle",
		"Gray Kodo",
		"Gray Ram",
		"Green Mechanostrider",
		"Horn of the Brown Wolf",
		"Horn of the Dire Wolf",
		"Horn of the Timber Wolf",
		"Pinto Bridle",
		"Red Mechanostrider",
		"Red Skeletal Horse",
		"Reins of the Spotted Frostsaber",
		"Reins of the Striped Frostsaber",
		"Reins of the Striped Nightsaber",
		"Unpainted Mechanostrider",
		"Whistle of the Emerald Raptor",
		"Whistle of the Turquoise Raptor",
		"Whistle of the Violet Raptor",
		"White Ram",
		"Summon Warhorse",
		"Summon Felsteed",
		"Summon Charger",
		"Dreadsteed",
		"Palomino",
		"White Stallion",
		-- passive class auras that should stay invisible
		"Shadowmeld",
	};
	-- ==========================================
	-- [2] SPECIAL BUFFS — world buffs, rare procs
	-- ==========================================
	[2] = {
		"Sayge's Dark Fortune of Damage",
		"Sayge's Dark Fortune of Resistance",
		"Sayge's Dark Fortune of Armor",
		"Sayge's Dark Fortune of Spirit",
		"Sayge's Dark Fortune of Intelligence",
		"Sayge's Dark Fortune of Stamina",
		"Sayge's Dark Fortune of Strength",
		"Sayge's Dark Fortune of Agility",
		"Rallying Cry of the Dragonslayer",
		"Spirit of Zandalar",
		"Warchief's Blessing",
		"Songflower Serenade",
		"Fengus' Ferocity",
		"Mol'dar's Moxie",
		"Slip'kik's Savvy",
		-- Atiesh proc (legendary staff)
		"Power of the Guardian",
		-- UBRS NPC fire resist buff (TurtleWoW custom)
		"Resist Fire",
	};
	-- ==========================================
	-- [50] PROTECTION POTIONS
	-- ==========================================
	[50] = {
		"Shadow Protection",
		"Fire Protection",
		"Nature Protection",
		"Frost Protection",
		"Arcane Protection",
		"Greater Stoneshield",
		"Juju Chill",
		"Juju Ember",
		"Juju Escape",
		"Holy Protection",
	};
	-- ==========================================
	-- [55] SCROLLS
	-- ==========================================
	[55] = {
		"Stamina",
		"Armor",
		"Agility",
		"Strength",
		"Intellect",
		"Spirit",
	};
	-- ==========================================
	-- CONSUMABLES [60]-[73]
	-- Sorted: RIGHT = long duration, LEFT = short
	-- ==========================================
	-- [60] Flasks (2h, persist through death) — RIGHTMOST consume
	[60] = {
		"Flask of the Titans",
		"Distilled Wisdom",
		"Supreme Power",
		"Chromatic Resistance",
	};
	-- [61] Zanza (2h)
	[61] = {
		"Spirit of Zanza",
		"Sheen of Zanza",
		"Swiftness of Zanza",
	};
	-- [62] 1h Damage Elixirs (offensive)
	[62] = {
		"Frost Power",
		"Fire Power",
		"Greater Frost Power",
		"Greater Arcane Power",
		"Elixir of Greater Nature Power",
		"Greater Firepower",
		"Shadow Power",
		"Greater Arcane Elixir",
		"Arcane Elixir",
	};
	-- [63] 1h Defensive/Stat Elixirs
	[63] = {
		"Elixir of the Mongoose",
		"Elixir of the Sages",
		"Elixir of the Giants",
		"Elixir of Brute Force",
		"Elixir of Demonslaying",
		"Elixir of Greater Agility",
		"Greater Armor",
		"Greater Agility",
		"Greater Intellect",
		"Resistance",
		"Regeneration",
	};
	-- [64] Blasted Lands (1h)
	[64] = {
		"Infallible Mind",
		"Strike of the Scorpok",
		"Rage of Ages",
		"Spirit of the Boar",
		"Spiritual Domination",
	};
	-- [65] 1h Utility Defense (Fortitude)
	[65] = {
		"Health II",
	};
	-- [66] 1h Utility Mana (Mageblood)
	[66] = {
		"Mageblood Potion",
		"Mana Regeneration",
	};
	-- [67] 1h Misc Utility
	[67] = {
		"Gift of Arthas",
	};
	-- [68] 30-60min TurtleWoW Elixirs
	[68] = {
		"Dreamshard Elixir",
		"Concoction of the Emerald Mongoose",
		"Concoction of the Arcane Giant",
	};
	-- [69] 20min Buffs (Juju, Winterfall etc.)
	[69] = {
		"Winterfall Firewater",
		"Juju Might",
		"Juju Guile",
		"Juju Flurry",
		"Juju Power",
	};
	-- [70] 20min TurtleWoW (Dreamtonic, Concoctions)
	[70] = {
		"Dreamtonic",
		"Concoction of the Dreamwater",
	};
	-- [71] 15min Drinks/Alcohol
	[71] = {
		"Rumsey Rum Black Label",
		"Rumsey Dark Rum",
		"Rumsey Rum Light",
		"Gordok Green Grog",
		"Medivh's Merlot",
		"Medivh's Merlot Blue Label",
	};
	-- [72] 15min Food (Well Fed etc.)
	[72] = {
		"Well Fed",
		"Increased Stamina",
		"Increased Agility",
		"Increased Intellect",
		"Increased Healing Bonus",
		"Blessed Sunfruit",
		"Blessed Sunfruit Juice",
		"Brain Food",
		"Health Regeneration",
		"Dragonbreath Chili",
		"Elderberry Pie",
		"Fire-toasted Bun",
		"Midsummer Sausage",
		"Toasted Smorc",
		-- Felwood plant (10min)
		"Windblossom Berries",
	};
	-- [73] On-use / Very Short Duration (<5min)
	[73] = {
		"Free Action",
		"Speed",
		"Noggenfogger Elixir",
		"Mighty Rage",
		"Petrification",
		"Living Free Action",
		"Dreamless Sleep",
		"Crystal Force",
		"Crystal Spire",
		"Crystal Restore",
		"Crystal Ward",
		"Cozy Fire",
		"Restoration",
		"Stoneshield",
		"Lesser Invisibility",
		"Regenerating",
		"Potion of Quickness",
		"Invulnerability",
		"Invisibility",
		-- Raid-specific on-use
		"Lucidity Potion",
		"Purification",
		"Hourglass Sand",
	};
	-- ==========================================
	-- TRINKETS [90]
	-- ==========================================
	[90] = {
		"The Eye of the Dead",
		"Glyph of Deflection",
		"Slayer's Crest",
		"Essence of Sapphiron",
		"The Eye of Diminution",
		"Kiss of the Spider",
		"Loatheb's Reflection",
		"Jom Gabbar",
		"The Burrower's Shell",
		"Persistent Shield",
		"Arcane Shroud",
		"Aegis of Preservation",
		"Arcane Infused",
		"Badge of the Swarmguard",
		"Insight of the Qiraji",
		"Gift of Life",
		"Mind Quickening",
		"Nature Aligned",
		"Mercurial Shield",
		"Metamorphosis Rune",
		"Blinding Light",
		"Blessing of the Black Book",
		"Venomous Totem",
		"Obsidian Insight",
		"Chitinous Spikes",
		"Healing of the Ages",
		"Mar'li's Brain Boost",
		"Pagle's Broken Reel",
		"Brittle Armor",
		"Unstable Power",
		"Restless Strength",
		"Aura of the Blue Dragon",
		"Ephemeral Power",
		"Earthstrike",
		"Grace of Earth",
		"Brilliant Light",
		"Massive Destruction",
		"Rapid Healing",
		"Arcane Potency",
		"Nimble Healing Touch",
		"Energized Shield",
		"The Lion Horn of Stormwind",
		"Damage Absorb",
		"Chromatic Infusion",
		"Heart of the Scale",
		"Force of Will",
		"Ascendance",
		"Ragged John's Neverending Cup",
		"Stout Heart",
		"Prismstone",
		"Orb of Deception",
		"Second Wind",
		"Burst of Knowledge",
		"Aura of Protection",
		"Prayer Beads Blessing",
		"Devilsaur Fury",
		"Primal Instinct",
		"Diamond Flask",
		"Chaos Fire",
		"Sanctified Orb",
		"Speed",
		"Blazing Emblem",
	};
	-- ==========================================
	-- [100] FOOD/DRINK INDICATORS
	-- ==========================================
	[100] = {
		"Drink",
		"Food",
	};
	-- ==========================================
	-- CLASS BUFFS [21]-[29]
	-- Includes auras moved from [0] for visibility
	-- ==========================================
	-- [21] Warrior
	[21] = {
		"Battle Shout",
		"Bloodrage",
		"Shield Block",
		"Retaliation",
		"Shield Wall",
		"Recklessness",
		"Berserker Rage",
		"Last Stand",
		"Sweeping STrikes",
		"Death Wish",
		"Flurry",
		"Bloodthirst",
	};
	-- [22] Paladin (includes auras moved from [0])
	[22] = {
		-- auras (moved from [0] for class color visibility)
		"Retribution Aura",
		"Frost Resistance Aura",
		"Shadow Resistance Aura",
		"Fire Resistance Aura",
		"Devotion Aura",
		"Concentration Aura",
		"Sanctity Aura",
		-- blessings
		"Blessing of Might",
		"Greater Blessing of Might",
		"Blessing of Wisdom",
		"Greater Blessing of Wisdom",
		"Blessing of Kings",
		"Greater Blessing of Kings",
		"Blessing of Salvation",
		"Greater Blessing of Salvation",
		"Blessing of Light",
		"Greater Blessing of Light",
		"Blessing of Sacrifice",
		"Blessing of Freedom",
		"Blessing of Protection",
		"Blessing of Sanctuary",
		"Greater Blessing of Sanctuary",
		-- seals
		"Seal of Command",
		"Seal of Wisdom",
		"Seal of Righteousness",
		"Seal of Light",
		"Seal of Justice",
		"Seal of the Crusader",
		-- misc
		"Divine Intervention",
		"Lay on Hands",
		"Divine Protection",
		"Divine Shield",
		"Righteous Fury",
		"Divine Favor",
		-- TurtleWoW custom
		"Daybreak",
	};
	-- [23] Hunter (includes auras moved from [0])
	[23] = {
		-- auras (moved from [0])
		"Aspect of the Pack",
		"Aspect of the Wild",
		"Trueshot Aura",
		-- abilities
		"Eyes of the Beast",
		"Feign Death",
		"Deterrence",
		"Rapid Fire",
		"Eagle Eye",
		"Aspect of the Beast",
		"Aspect of the Cheetah",
		"Aspect of the Hawk",
		"Aspect of the Monkey",
		"Stalker's Ally",
		"Spirit Bond",
	};
	-- [24] Rogue
	[24] = {
		"Slice and Dice",
		"Adrenaline Rush",
		"Blade Flurry",
		"Evasion",
		"Sprint",
		"Stealth",
		"Vanish",
		"Premeditation",
		"Cold Blood",
	};
	-- [25] Priest
	[25] = {
		"Divine Spirit",
		"Inner Fire",
		"Levitate",
		"Power Word: Fortitude",
		"Power Word: Shield",
		"Prayer of Fortitude",
		"Prayer of Spirit",
		"Abolish Disease",
		"Fear Ward",
		"Renew",
		"Fade",
		"Mind Vision",
		"Prayer of Shadow Protection",
		"Power Infusion",
		"Spirit of Redemption",
		"Inspiration",
		"Shadowform",
		"Inner Focus",
	};
	-- [26] Shaman
	[26] = {
		"Healing Way",
	};
	-- [27] Mage
	[27] = {
		"Arcane Brilliance",
		"Amplify Magic",
		"Arcane Intellect",
		"Arcane Power",
		"Dampen Magic",
		"Evocation",
		"Mage Armor",
		"Mage Shield",
		"Slow Fall",
		"Fire Ward",
		"Frost Armor",
		"Frost Ward",
		"Ice Armor",
		"Combustion",
		"Ice Block",
		"Ice Barrier",
		"Presence of Mind",
	};
	-- [28] Warlock (includes Blood Pact moved from [0])
	[28] = {
		"Blood Pact",
		"Soulstone Resurrection",
		"Demon Armor",
		"Demon Skin",
		"Detect Greater Invisibility",
		"Detect Invisibility",
		"Detect Lesser Invisibility",
		"Health Funnel",
		"Hellfire",
		"Shadow Ward",
		"Unending Breath",
		"Nightfall",
		"Amplify Curse",
		"Soul Link",
		"Burning Wish",
		"Voidstone",
		"Spellstone",
		"Wrathstone",
		"Firestone",
		"Felstone",
		"Fire Shield",
		"Fel Domination",
		"Fel Stamina",
		"Touch of Shadow",
		"Paranoia",
		"Fel Energy",
	};
	-- [29] Druid (includes auras moved from [0])
	[29] = {
		"Leader of the Pack",
		"Moonkin Aura",
		"Gift of the Wild",
		"Mark of the Wild",
		"Thorns",
		"Bear Form",
		"Dire Bear Form",
		"Enrage",
		"Regrowth",
		"Rejuvenation",
		"Nature's Swiftness",
		"Omen of Clarity",
		"Emerald Blessing",
		"Barkskin",
		"Aquatic Form",
		"Cat Form",
	};
};
