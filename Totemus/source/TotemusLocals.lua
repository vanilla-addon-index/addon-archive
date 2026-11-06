BINDING_HEADER_TOTEMUS = "TOTEMUS"
-- This statement will load any translation that is present or default to English.
if( not ace:LoadTranslation("TOTEMUS") ) then

	TOTEMUS_MSG_COLOR		= "|cffcceebb";
	Totemus_MSG_COLOR		= "|cffcceebb";
	TOTEMUS_DISPLAY_OPTION	= "[|cfff5f530%s|cff0099CC]";

	TOTEMUS_CONST = {

		Title   		= "TOTEMUS",
		Version 		= "0.7",
		Desc    		= "TOTEMUS hack job",
		Timerheader		= "Shaman Timers",
		UpdateInterval		= 0.2,
	
		ChatCmd		= {"/totem", "/totemus"},
		
		ChatOpt 		= {
			{	
				option	= "reset",
				desc	= "Reset the window positions.",
				method	= "chatReset",
			},
			{
				option  = "feldom",
				desc	= "Set the Fel Domination modifier: ctrl alt shift none",
				method  = "chatFelDom",
			},
			{
				option  = "closeonclick",
				desc    = "Toggle closing the pet menu on clicking a button",
				method  = "chatCloseClick",
			},
			{
				option  = "soulstonesound",
				desc    = "Toggle playing of soulstone expired sound",
				method  = "chatSoulstoneSound",
			},
			{
				option  = "shadowtrancesound",
				desc    = "Toggle playing of nightfall proc sound",
				method  = "chatShadowTranceSound",
			},
			{
				option	= "texture",
				desc	= "Choose a different shardcount texture: default blue orange rose turquoise violet x",
				method	= "chatTexture",
			},
			{
				option 	= "lock",
				desc	= "Toggle locking of the frames",
				method  = "chatLock",
			},
			{
				option  = "timers",
				desc    = "Toggle to turn on/off the timers",
				method  = "chatTimers",
			},

		},
		
		Chat            	= {
			FelDomModifier  = "Fel Domination Modifier is now: ",
			FelDomValid	= "Valid Modifiers are: ctrl alt shift none",
			CloseOnClick    = "Close On Click is now: ",
			ShadowTranceSound = "Playing of Shadowtrance sound is now: ",
			SoulstoneSound = "Playing of Soulstone expired sound is now: ",
			Texture = "Texture is now: ",
			TextureValid = "Valid textures are: default blue orange rose turquoise violet x",
			Lock = "Frame lock is now: ",
			Timers = "Timers are now: ",
		},
		
		Message			= {
			TooFarAway 	= "They are too far away.",
			Busy		= "They are busy.",
			PreSummon	= "Going to summon %s, please click the portal.",
			PreSoulstone	= "Placing my soulstone on %s.",
			Soulstone	= "%s has been soulstoned.",
			SoulstoneAborted = "Soustone Aborted! It's not placed.",
			FailedSummon	= "Summoning %s failed!",
		},
		

		Pattern = {
			Hearthstone = "Hearthstone",
			Corrupted = "Corrupted",
			Healthstone = "Healthstone",
			Shaman = "Shaman",
			Rank = "Rank (.+)",
			Resisted = "^Your [%a%s%p]+ was resisted by [%a%s%p]+%.",
			Immune = "^Your [%a%s%p]+ failed%. [%a%s%p]+ is immune%.$",
		},

		State = {
			Reset = 0,
			Cast = 1,
			Start = 2,
			Stop = 3,
			NewMonsterNewSpell = 4,
			NewSpell = 5,
			Update = 6,
			Failed = 7
			
		},

		Spell = {	
			--Earth Totems
			
			--["Earthbind Totem"] = "EBT",
			-- Water Totems
			--["Disease Cleansing Totem"] = "DCT",
			--["Poison Cleansing Totem"] = "PCT",
			--Air Totems
			["Grounding Totem"] = "GRDT",
			["Windfury Totem"] = "WFT",
			["Sentry Totem"] = "SENT",
			["Tranquil Air Totem"] = "TRAC",
			["Hearthstone"] = "HEARTHSTONE",
			["Astral Recall"] = "ASTRAL",
		},

		RankedSpell = {
			-- Earth Totems
			["Stoneclaw Totem Rank 1"] = { "SCT", 1,1 },
			["Stoneclaw Totem Rank 2"] = { "SCT", 2,1 },
			["Stoneclaw Totem Rank 3"] = { "SCT", 3,1 },
			["Stoneclaw Totem Rank 4"] = { "SCT", 4,1 },
			["Stoneclaw Totem Rank 5"] = { "SCT", 5,1 },
			["Stoneclaw Totem Rank 6"] = { "SCT", 6,1 },
			["Stoneskin Totem Rank 1"] = { "SST", 1,1 },
			["Stoneskin Totem Rank 2"] = { "SST", 2,1 },
			["Stoneskin Totem Rank 3"] = { "SST", 3,1 },
			["Stoneskin Totem Rank 4"] = { "SST", 4,1 },
			["Stoneskin Totem Rank 5"] = { "SST", 5,1 },
			["Stoneskin Totem Rank 6"] = { "SST", 6,1 },
			["Strength of Earth Totem Rank 1"] = { "SOET", 1,1 },
			["Strength of Earth Totem Rank 2"] = { "SOET", 2,1 },
			["Strength of Earth Totem Rank 3"] = { "SOET", 3,1 },
			["Strength of Earth Totem Rank 4"] = { "SOET", 4,1 },
			["Strength of Earth Totem Rank 5"] = { "SOET", 5,1 },
			["Tremor Totem"] = {"TRET", 1,1},
			["Earthbind Totem"] = {"EBT", 1,1},
			-- Water Totems
			--["Elemental Protection Totem Rank 1"] = {"EPT", 1},
			["Fire Resistance Totem Rank 1"] = {"FRT", 1,4},
			["Fire Resistance Totem Rank 2"] = {"FRT", 2,4},
			["Healing Stream Totem Rank 1"] = {"HST", 1,4},
			["Healing Stream Totem Rank 2"] = {"HST", 2,4},
			["Healing Stream Totem Rank 3"] = {"HST", 3,4},
			["Healing Stream Totem Rank 4"] = {"HST", 4,4},
			["Healing Stream Totem Rank 5"] = {"HST", 5,4},
			["Mana Spring Totem Rank 1"] = {"MST", 1,4},
			["Mana Spring Totem Rank 2"] = {"MST", 1,4},
			["Mana Spring Totem Rank 3"] = {"MST", 1,4},
			["Mana Spring Totem Rank 4"] = {"MST", 1,4},
			["Mana Tide Totem Rank 1"] = {"MTT", 1,4},
			["Mana Tide Totem Rank 2"] = {"MTT", 2,4},
			["Mana Tide Totem Rank 3"] = {"MTT", 3,4},
			["Disease Cleansing Totem"] = {"DCT", 1,4},	
			["Poison Cleansing Totem"] = {"PCT", 1,4},			
			-- Air Totems
			["Grace of Air Totem Rank 1"] = {"GOAT", 1, 3},
			["Grace of Air Totem Rank 2"] = {"GOAT", 2, 3},
			["Grace of Air Totem Rank 3"] = {"GOAT", 3, 3},
			["Nature Resistance Totem Rank 1"] = {"NRT", 1, 3},
			["Nature Resistance Totem Rank 2"] = {"NRT", 2, 3},
			["Nature Resistance Totem Rank 3"] = {"NRT", 3, 3},
			--["Windfury Totem Rank 1"] = {"WFT", 1},
			--["Windfury Totem Rank 2"] = {"WFT", 2},
			--["Windfury Totem Rank 3"] = {"WFT", 3},
			["Windwall Totem Rank 1"] = {"WWT", 1, 3},
			["Windwall Totem Rank 2"] = {"WWT", 2, 3},
			["Windwall Totem Rank 3"] = {"WWT", 3, 3},
			-- Fire Totems
			["Fire Nova Totem Rank 1"] = {"FNT", 1, 2},
			["Fire Nova Totem Rank 2"] = {"FNT", 2, 2},
			["Fire Nova Totem Rank 3"] = {"FNT", 3, 2},
			["Fire Nova Totem Rank 4"] = {"FNT", 4, 2},
			["Fire Nova Totem Rank 5"] = {"FNT", 5, 2},
			["Flametongue Totem Rank 1"] = {"FTT", 1, 2},
			["Flametongue Totem Rank 2"] = {"FTT", 2, 2},
			["Flametongue Totem Rank 3"] = {"FTT", 3, 2},
			["Flametongue Totem Rank 4"] = {"FTT", 4, 2},
			["Frost Resistance Totem Rank 1"] = {"FROT", 1, 2},
			["Frost Resistance Totem Rank 2"] = {"FROT", 2, 2},
			["Frost Resistance Totem Rank 3"] = {"FROT", 3, 2},
			["Magma Totem Rank 1"] = {"MAGT", 1, 2},
			["Magma Totem Rank 2"] = {"MAGT", 2, 2},
			["Magma Totem Rank 3"] = {"MAGT", 3, 2},
			["Searing Totem Rank 1"] = {"SEAT", 1, 2},
			["Searing Totem Rank 2"] = {"SEAT", 2, 2},
			["Searing Totem Rank 3"] = {"SEAT", 3, 2},
			["Searing Totem Rank 4"] = {"SEAT", 4, 2},
			["Searing Totem Rank 5"] = {"SEAT", 5, 2},
			["Searing Totem Rank 6"] = {"SEAT", 6, 2},
			--weapon buffs
			["Rockbiter Weapon Rank 1"] = {"RBW", 1,6},
			["Rockbiter Weapon Rank 2"] = {"RBW", 2,6},
			["Rockbiter Weapon Rank 3"] = {"RBW", 3,6},
			["Rockbiter Weapon Rank 4"] = {"RBW", 4,6},
			["Rockbiter Weapon Rank 5"] = {"RBW", 5,6},
			["Rockbiter Weapon Rank 6"] = {"RBW", 6,6},
			["Rockbiter Weapon Rank 7"] = {"RBW", 7,6},
			["Flametongue Weapon Rank 1"] = {"FTW", 1,6},
			["Flametongue Weapon Rank 2"] = {"FTW", 2,6},
			["Flametongue Weapon Rank 3"] = {"FTW", 3,6},
			["Flametongue Weapon Rank 4"] = {"FTW", 4,6},
			["Flametongue Weapon Rank 5"] = {"FTW", 5,6},
			["Frostbrand Weapon Rank 1"] = {"FRBW", 1,6},
			["Frostbrand Weapon Rank 2"] = {"FRBW", 2,6},
			["Frostbrand Weapon Rank 3"] = {"FRBW", 3,6},
			["Frostbrand Weapon Rank 4"] = {"FRBW", 4,6},
			["Windfury Weapon Rank 1"] = {"WFW", 1,6},
			["Windfury Weapon Rank 2"] = {"WFW", 2,6},
			["Windfury Weapon Rank 3"] = {"WFW", 3,6},
			-- Shields
			["Lightning Shield Rank 1"] = {"LS", 1,5},
			["Lightning Shield Rank 2"] = {"LS", 2,5},
			["Lightning Shield Rank 3"] = {"LS", 3,5},
			["Lightning Shield Rank 4"] = {"LS", 4,5},
			["Lightning Shield Rank 5"] = {"LS", 5,5},
			["Lightning Shield Rank 6"] = {"LS", 6,5},
			["Lightning Shield Rank 7"] = {"LS", 7,5},
			["Water Shield Rank 1"] = {"WS", 1,5},
			["Water Shield Rank 2"] = {"WS", 2,5},
			["Water Shield Rank 3"] = {"WS", 3,5},
			["Earth Shield Rank 1"] = {"ES", 1,5},
		},
		TimedSpell = {
			--weapon buffs
			["Rockbiter Weapon"] = { 3600, 3600, 3600, 3600, 3600, 3600, 3600 },
			["Flametongue Weapon"] = { 3600, 3600, 3600, 3600, 3600 },
			["Frostbrand Weapon"] = { 3600, 3600, 3600, 3600 },
			["Windfury Weapon"] = { 3600, 3600, 3600 },
			--Earth Totems			
			["Stoneclaw Totem"] = { 15, 15, 15, 15, 15, 15 },
			["Stoneskin Totem"] = { 120, 120, 120, 120, 120, 120 },
			["Strength of Earth Totem"] = { 120, 120, 120, 120, 120, 120 },
			["Fire Resistance Totem"] = { 120, 120, 120, 120, 120, 120 },
			["Healing Stream Totem"] = { 60, 60, 60, 60, 60, 60 },
			["Mana Spring Totem"] = { 60, 60, 60, 60, 60, 60 },
			["Mana Tide Totem"] = { 12, 12, 12 },
			-- Air Totems
			["Grace of Air Totem"] = { 60, 60, 60, 60, 60, 60 },
			["Nature Resistance Totem"] = { 120, 120, 120 },
			["Windwall Totem"] = { 120, 120, 120 },
			["Disease Cleansing Totem"] = { 120, 120, 120, 120, 120},
			-- Fire Totems
			["Fire Nova Totem"] = { 5, 5, 5, 5, 5},
			["Flametongue Totem"] = { 120, 120, 120, 120 },
			["Frost Resistance Totem"] = { 120, 120, 120 },
			["Magma Totem"] = { 20, 20, 20, 20 },
			["Searing Totem"] = { 45, 45, 45, 45, 45, 45 },
			["Earthbind Totem"] = { 45 },
			-- Water Totems
			["Disease Cleansing Totem"] = { 120 },
			["Poison Cleansing Totem"] = { 120 },
			--Air Totems
			["Grounding Totem"] = { 45 },
			["Sentry Totem"] = { 300 },
			["Windfury Totem"] = { 120 },
			["Tranquil Air Totem"] = { 120 },
			["Tremor Totem"] = { 120 },
			-- Shields
			["Lightning Shield"] = { 600, 600, 600, 600, 600, 600, 600 },
			["Water Shield"] = { 600, 600, 600, 600, 600, 600, 600 },
			["Earth Shield"] = { 600 },
		},
	}

	ace:RegisterGlobals({
		version	= 1.01,
	
		ACEG_TEXT_NOW_SET_TO = "now set to",
		ACEG_TEXT_DEFAULT	 = "default",
	
		ACEG_DISPLAY_OPTION  = "[|cfff5f530%s|r]",
	
		ACEG_MAP_ONOFF		 = {[0]="|cffff5050Off|r",[1]="|cff00ff00On|r"},
		ACEG_MAP_ENABLED	 = {[0]="|cffff5050Disabled|r",[1]="|cff00ff00Enabled|r"},
	})
end