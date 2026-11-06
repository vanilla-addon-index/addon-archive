-- TalentBuilds.lua
--
-- GENERATED FILE -- do not edit by hand.
-- Generator: Tools/build/talent_builds.py, which checks every build against
-- Turtle WoW's trees (Tools/data/turtle_talent_trees.json, saved by /apg talents).
--
-- Each build's order is talent, rank, talent, rank, ...: each talent taken up
-- to that rank, a point a level from 10, 51 in all. The Talent Advisor checks
-- them against the tree the game has before it follows one.

AegisPathfinder.TalentBuilds = {
	DRUID = {
		levelling = { spec = "Feral Combat", split = "11/35/5", order = {
			"Ferocity", 5, "Thick Hide", 3, "Open Wounds", 2, "Sharpened Claws", 3, "Feral Swiftness", 2,
			"Predatory Strikes", 3, "Primal Fury", 2, "Improved Shred", 2, "Berserk", 1, "Blood Frenzy", 2,
			"Heart of the Wild", 5, "Leader of the Pack", 1, "Nature's Grasp", 1,
			"Improved Nature's Grasp", 4, "Natural Weapons", 3, "Natural Shapeshifter", 2,
			"Omen of Clarity", 1, "Open Wounds", 3, "Carnage", 2, "Feral Charge", 1, "Furor", 5,
		} },
		alts = {
			{ name = "Bear", spec = "Feral Combat", split = "11/40/0", order = {
				"Ferocity", 5, "Thick Hide", 3, "Feral Instinct", 2, "Sharpened Claws", 3, "Primal Fury", 2,
				"Predatory Strikes", 3, "Feral Charge", 1, "Feral Swiftness", 2, "Feral Instinct", 3,
				"Ancient Brutality", 2, "Berserk", 1, "Heart of the Wild", 5, "Leader of the Pack", 1,
				"Carnage", 2, "Blood Frenzy", 2, "Feral Aggression", 5, "Nature's Grasp", 1,
				"Improved Nature's Grasp", 4, "Natural Weapons", 3, "Natural Shapeshifter", 2,
				"Omen of Clarity", 1,
			} },
		},
		specs = {
			{ spec = "Balance", split = "35/0/16", order = {
				"Improved Wrath", 5, "Guidance of the Dream", 2, "Improved Moonfire", 2, "Natural Weapons", 3,
				"Moonfury", 3, "Omen of Clarity", 1, "Nature's Reach", 2, "Vengeance", 5, "Moonglow", 3,
				"Moonkin Form", 1, "Nature's Grace", 1, "Improved Starfire", 3, "Balance of All Things", 3,
				"Eclipse", 1, "Improved Mark of the Wild", 5, "Subtlety", 5, "Genesis", 3, "Reflection", 3,
			} },
			{ spec = "Feral Combat", split = "11/35/5", order = {
				"Ferocity", 5, "Feral Instinct", 3, "Thick Hide", 3, "Open Wounds", 2, "Feral Swiftness", 2,
				"Feral Charge", 1, "Sharpened Claws", 3, "Primal Fury", 2, "Predatory Strikes", 3,
				"Blood Frenzy", 2, "Improved Shred", 2, "Berserk", 1, "Heart of the Wild", 5,
				"Leader of the Pack", 1, "Nature's Grasp", 1, "Improved Nature's Grasp", 4, "Natural Weapons", 3,
				"Natural Shapeshifter", 2, "Omen of Clarity", 1, "Furor", 5,
			} },
			{ spec = "Restoration", split = "11/0/40", order = {
				"Improved Mark of the Wild", 5, "Improved Healing Touch", 5, "Nature's Focus", 1, "Swiftmend", 1,
				"Genesis", 3, "Reflection", 3, "Gift of Nature", 5, "Tranquil Spirit", 5, "Aessina's Bloom", 2,
				"Nature's Swiftness", 1, "Preservation", 3, "Improved Regrowth", 5, "Tree of Life Form", 1,
				"Nature's Grasp", 1, "Improved Nature's Grasp", 4, "Natural Weapons", 3,
				"Natural Shapeshifter", 2, "Omen of Clarity", 1,
			} },
		},
	},
	HUNTER = {
		levelling = { spec = "Beast Mastery", split = "38/13/0", order = {
			"Swift Aspects", 5, "Thick Hide", 3, "Endurance Training", 2, "Unleashed Fury", 5, "Ferocity", 5,
			"Scent of Blood", 3, "Bestial Wrath", 1, "Intimidation", 1, "Spirit Bond", 2, "Frenzy", 3,
			"Kill Command", 1, "Frenzy", 5, "Endurance Training", 5, "Bestial Discipline", 2,
			"Efficiency", 5, "Lethal Shots", 5, "Aimed Shot", 1, "Hawk Eye", 2,
		} },
		specs = {
			{ spec = "Beast Mastery", split = "35/16/0", order = {
				"Swift Aspects", 5, "Endurance Training", 5, "Unleashed Fury", 5, "Ferocity", 5,
				"Scent of Blood", 3, "Intimidation", 1, "Bestial Wrath", 1, "Bestial Precision", 2,
				"Spirit Bond", 2, "Frenzy", 5, "Kill Command", 1, "Efficiency", 5, "Lethal Shots", 5,
				"Hawk Eye", 2, "Aimed Shot", 1, "Swiftshot", 3,
			} },
			{ spec = "Marksmanship", split = "15/36/0", order = {
				"Efficiency", 5, "Lethal Shots", 5, "Hawk Eye", 1, "Aimed Shot", 1, "Swiftshot", 3,
				"Endless Quiver", 2, "Mortal Shots", 5, "Experimental Ammunition", 1, "Piercing Shots", 2,
				"Barrage", 3, "Improved Marksmanship", 2, "Ranged Weapon Specialization", 5, "Lock and Load", 1,
				"Swift Aspects", 5, "Endurance Training", 2, "Thick Hide", 3, "Unleashed Fury", 5,
			} },
			{ spec = "Survival", split = "16/0/35", order = {
				"Improved Slaying", 3, "Swift Reflexes", 2, "Savage Strikes", 2, "Improved Wing Clip", 3,
				"Survivalist", 5, "Carve", 1, "Deterrence", 1, "Surefooted", 3, "Killer Instinct", 3,
				"Trap Mastery", 3, "Lacerate", 1, "Vicious Strikes", 2, "Lightning Reflexes", 5,
				"Untamed Trapper", 1, "Swift Aspects", 5, "Endurance Training", 2, "Improved Primal Aspects", 3,
				"Coordinated Assault", 1, "Unleashed Fury", 5,
			} },
		},
	},
	MAGE = {
		levelling = { spec = "Frost", split = "10/0/41", order = {
			"Improved Frostbolt", 5, "Piercing Ice", 3, "Permafrost", 2, "Ice Shards", 5,
			"Frost Channeling", 3, "Improved Frost Nova", 2, "Ice Block", 1, "Shatter", 5, "Cold Snap", 1,
			"Elemental Precision", 3, "Ice Barrier", 1, "Arcane Subtlety", 2, "Magic Absorption", 3,
			"Arcane Concentration", 5, "Permafrost", 3, "Improved Blizzard", 3, "Winter's Chill", 5,
			"Frostbite", 1,
		} },
		specs = {
			{ spec = "Arcane", split = "41/0/10", order = {
				"Arcane Subtlety", 2, "Magic Absorption", 1, "Improved Arcane Missiles", 5, "Arcane Focus", 5,
				"Arcane Concentration", 5, "Arcane Impact", 3, "Arcane Rupture", 1, "Temporal Convergence", 3,
				"Arcane Meditation", 3, "Arcane Instability", 3, "Presence of Mind", 1, "Accelerated Arcana", 1,
				"Arcane Potency", 2, "Resonance Cascade", 5, "Arcane Power", 1, "Improved Frostbolt", 5,
				"Improved Frost Nova", 2, "Permafrost", 3,
			} },
			{ spec = "Fire", split = "10/41/0", order = {
				"Improved Fireball", 5, "Ignite", 5, "Flame Throwing", 2, "Improved Fire Blast", 3,
				"Incinerate", 2, "Improved Flamestrike", 3, "Pyroblast", 1, "Burning Soul", 2,
				"Fire Vulnerability", 3, "Master of Elements", 3, "Blast Wave", 1, "Critical Mass", 3,
				"Hot Streak", 2, "Fire Power", 5, "Combustion", 1, "Arcane Subtlety", 2, "Magic Absorption", 3,
				"Arcane Concentration", 5,
			} },
			{ spec = "Frost", split = "10/0/41", order = {
				"Improved Frostbolt", 5, "Elemental Precision", 3, "Piercing Ice", 3, "Frostbite", 3,
				"Ice Shards", 5, "Cold Snap", 1, "Improved Blizzard", 3, "Arctic Reach", 2,
				"Frost Channeling", 3, "Ice Block", 1, "Icicles", 1, "Improved Cone of Cold", 3,
				"Winter's Chill", 5, "Flash Freeze", 2, "Ice Barrier", 1, "Arcane Subtlety", 2,
				"Magic Absorption", 3, "Arcane Concentration", 5,
			} },
		},
	},
	PALADIN = {
		levelling = { spec = "Retribution", split = "5/11/35", order = {
			"Benediction", 5, "Improved Judgement", 2, "Improved Seal of the Crusader", 3, "Conviction", 5,
			"Two-Handed Weapon Specialization", 3, "Pursuit of Justice", 2, "Seal of Command", 1,
			"Vengeance", 5, "Vengeful Strikes", 5, "Divine Strength", 5, "Vindication", 3, "Repentance", 1,
			"Improved Devotion Aura", 5, "Precision", 3, "Toughness", 3,
		} },
		alts = {
			{ name = "Protection", spec = "Protection", split = "10/41/0", order = {
				"Redoubt", 5, "Precision", 3, "Toughness", 2, "Blessing of Sanctuary", 1,
				"Shield Specialization", 3, "Toughness", 5, "Improved Hammer of Justice", 3, "Holy Shield", 1,
				"Reckoning", 5, "Righteous Strikes", 5, "Bulwark of the Righteous", 1,
				"Improved Righteous Fury", 3, "Righteous Defense", 3, "Anticipation", 3, "Divine Strength", 5,
				"Divine Intellect", 5,
			} },
		},
		specs = {
			{ spec = "Holy", split = "35/5/11", order = {
				"Divine Intellect", 5, "Holy Judgement", 3, "Spiritual Focus", 2, "Healing Light", 3,
				"Improved Lay on Hands", 2, "Improved Concentration Aura", 3, "Illumination", 5, "Ironclad", 2,
				"Holy Shock", 1, "Divine Favor", 5, "Holy Power", 3, "Daybreak", 1, "Improved Blessings", 5,
				"Benediction", 5, "Blessing of Kings", 1, "Improved Devotion Aura", 5,
			} },
			{ spec = "Protection", split = "0/36/15", order = {
				"Improved Devotion Aura", 1, "Redoubt", 5, "Precision", 3, "Toughness", 5,
				"Improved Righteous Fury", 3, "Blessing of Sanctuary", 1, "Shield Specialization", 3,
				"Anticipation", 3, "Improved Hand of Reckoning", 2, "Righteous Defense", 3, "Holy Shield", 1,
				"Righteous Strikes", 5, "Bulwark of the Righteous", 1, "Benediction", 5, "Improved Judgement", 2,
				"Deflection", 5, "Improved Retribution Aura", 2, "Blessing of Kings", 1,
			} },
			{ spec = "Retribution", split = "9/8/34", order = {
				"Benediction", 5, "Improved Judgement", 2, "Improved Seal of the Crusader", 3, "Conviction", 5,
				"Blessing of Kings", 1, "Two-Handed Weapon Specialization", 3, "Vindication", 3, "Vengeance", 5,
				"Seal of Command", 1, "Vengeful Strikes", 5, "Repentance", 1, "Divine Strength", 5,
				"Divine Intellect", 4, "Improved Devotion Aura", 5, "Precision", 3,
			} },
		},
	},
	PRIEST = {
		levelling = { spec = "Shadow", split = "12/0/39", order = {
			"Wand Specialization", 2, "Spirit Tap", 5, "Improved Shadow Word: Pain", 2,
			"Improved Mind Blast", 5, "Mind Flay", 1, "Shadow Focus", 2, "Shadow Weaving", 5,
			"Vampiric Embrace", 1, "Shadow Reach", 2, "Shadow Focus", 4, "Darkness", 5, "Shadowform", 1,
			"Vampiric Touch", 2, "Blackout", 5, "Shadow Focus", 5, "Mental Agility", 5,
			"Unbreakable Will", 3, "Meditation", 2,
		} },
		specs = {
			{ spec = "Discipline", split = "33/18/0", order = {
				"Piercing Light", 3, "Mental Agility", 5, "Improved Power Word: Fortitude", 2, "Inner Focus", 1,
				"Improved Power Word: Shield", 3, "Meditation", 3, "Searing Light", 3, "Purifying Flames", 2,
				"Mental Strength", 3, "Enlighten", 1, "Resurgent Shield", 1, "Force of Will", 5, "Chastise", 1,
				"Divinity", 5, "Divine Fury", 5, "Spell Warding", 3, "Holy Reach", 2, "Spiritual Guidance", 3,
			} },
			{ spec = "Holy", split = "16/35/0", order = {
				"Improved Renew", 3, "Divinity", 5, "Divine Fury", 5, "Inspiration", 3, "Empowered Recovery", 2,
				"Improved Healing", 3, "Spiritual Guidance", 5, "Book of Prayer", 2, "Spirit of Redemption", 1,
				"Spiritual Healing", 5, "Ascendance", 1, "Mental Agility", 5, "Silent Resolve", 3,
				"Improved Power Word: Fortitude", 2, "Inner Focus", 1, "Improved Power Word: Shield", 2,
				"Meditation", 3,
			} },
			{ spec = "Shadow", split = "14/0/37", order = {
				"Spirit Tap", 5, "Improved Mind Blast", 5, "Shadow Affinity", 3, "Improved Shadow Word: Pain", 2,
				"Shadow Focus", 5, "Mind Flay", 1, "Shadow Reach", 2, "Shadow Weaving", 5, "Vampiric Embrace", 1,
				"Vampiric Touch", 2, "Darkness", 5, "Shadowform", 1, "Mental Agility", 5, "Silent Resolve", 3,
				"Improved Power Word: Fortitude", 2, "Inner Focus", 1, "Meditation", 3,
			} },
		},
	},
	ROGUE = {
		levelling = { spec = "Combat", split = "20/31/0", order = {
			"Lightning Reflexes", 5, "Precision", 5, "Deflection", 5, "Dual Wield Specialization", 5,
			"Surprise Attack", 1, "Weapon Expertise", 2, "Hack and Slash", 2, "Blade Rush", 2,
			"Aggression", 3, "Adrenaline Rush", 1, "Malice", 5, "Ruthlessness", 3, "Murder", 2,
			"Relentless Strikes", 1, "Lethality", 5, "Improved Blade Tactics", 3, "Improved Eviscerate", 1,
		} },
		specs = {
			{ spec = "Assassination", split = "33/18/0", order = {
				"Malice", 5, "Ruthlessness", 3, "Murder", 2, "Improved Blade Tactics", 3,
				"Relentless Strikes", 1, "Lethality", 5, "Vile Poisons", 3, "Improved Poisons", 3, "Envenom", 1,
				"Cold Blood", 1, "Seal Fate", 5, "Noxious Assault", 1, "Opportunity", 5, "Deflection", 2,
				"Improved Backstab", 3, "Precision", 5, "Dual Wield Specialization", 3,
			} },
			{ spec = "Combat", split = "19/32/0", order = {
				"Lightning Reflexes", 5, "Deflection", 5, "Precision", 5, "Riposte", 1,
				"Dual Wield Specialization", 5, "Surprise Attack", 1, "Hack and Slash", 2, "Weapon Expertise", 2,
				"Blade Rush", 2, "Aggression", 3, "Adrenaline Rush", 1, "Malice", 5, "Ruthlessness", 3,
				"Murder", 2, "Improved Blade Tactics", 3, "Relentless Strikes", 1, "Lethality", 5,
			} },
			{ spec = "Subtlety", split = "16/0/35", order = {
				"Camouflage", 5, "Improved Ambush", 3, "Elusiveness", 2, "Serrated Blades", 3, "Initiative", 3,
				"Hemorrhage", 1, "Cloaked in Shadows", 2, "Blackjack", 2, "Dirty Deeds", 2, "Preparation", 1,
				"Shadow of Death", 1, "Bloody Mess", 2, "Honor Among Thieves", 2, "Tricks of the Trade", 5,
				"Mark for Death", 1, "Improved Eviscerate", 2, "Malice", 5, "Ruthlessness", 3, "Murder", 2,
				"Improved Blade Tactics", 3, "Relentless Strikes", 1,
			} },
		},
	},
	SHAMAN = {
		levelling = { spec = "Enhancement", split = "19/32/0", order = {
			"Ancestral Knowledge", 5, "Thundering Strikes", 5, "Ancestral Guardian", 3,
			"Improved Ghost Wolf", 2, "Flurry", 5, "Stormstrike", 1, "Elemental Weapons", 3,
			"Enhancing Totems", 2, "Element's Grace", 5, "Bloodlust", 1, "Convection", 5, "Concussion", 5,
			"Elemental Devastation", 3, "Elemental Focus", 1, "Reverberation", 3, "Call of Flame", 2,
		} },
		specs = {
			{ spec = "Elemental", split = "34/0/17", order = {
				"Convection", 5, "Concussion", 5, "Elemental Devastation", 3, "Elemental Focus", 1,
				"Reverberation", 3, "Call of Thunder", 5, "Call of Flame", 3, "Elemental Mastery", 1,
				"Elemental Fury", 2, "Lightning Mastery", 5, "Earthquake", 1, "Tidal Focus", 5,
				"Tidal Mastery", 5, "Healing Focus", 1, "Totemic Mastery", 1, "Nature's Grace", 3,
				"Improved Water Shield", 2,
			} },
			{ spec = "Enhancement", split = "17/34/0", order = {
				"Ancestral Knowledge", 5, "Thundering Strikes", 5, "Stable Shields", 3, "Calming Winds", 3,
				"Lightning Strike", 1, "Flurry", 5, "Enhancing Totems", 2, "Elemental Weapons", 3,
				"Stormstrike", 1, "Element's Grace", 5, "Bloodlust", 1, "Convection", 5, "Concussion", 5,
				"Elemental Devastation", 3, "Elemental Focus", 1, "Reverberation", 3,
			} },
			{ spec = "Restoration", split = "0/10/41", order = {
				"Improved Healing Wave", 5, "Tidal Focus", 5, "Ancestral Healing", 3, "Tidal Mastery", 5,
				"Healing Way", 3, "Totemic Mastery", 1, "Restorative Totems", 5, "Improved Water Shield", 3,
				"Tidal Surge", 2, "Ancestral Swiftness", 1, "Undertow", 2, "Improved Chain Heal", 5,
				"Spirit Link", 1, "Ancestral Knowledge", 5, "Stable Shields", 3, "Improved Ghost Wolf", 2,
			} },
		},
	},
	WARLOCK = {
		levelling = { spec = "Affliction", split = "31/20/0", order = {
			"Improved Corruption", 5, "Improved Life Tap", 2, "Improved Drains", 2, "Suppression", 1,
			"Improved Curse of Agony", 3, "Fel Concentration", 2, "Nightfall", 2, "Grim Reach", 2,
			"Suppression", 2, "Siphon Life", 1, "Rapid Deterioration", 2, "Suppression", 4,
			"Shadow Mastery", 5, "Dark Harvest", 1, "Demonic Embrace", 5, "Demonic Aegis", 3,
			"Fel Intellect", 2, "Fel Domination", 1, "Fel Stamina", 4, "Master Summoner", 2,
			"Unholy Power", 3,
		} },
		specs = {
			{ spec = "Affliction", split = "32/0/19", order = {
				"Suppression", 5, "Improved Corruption", 5, "Improved Life Tap", 2, "Improved Drains", 2,
				"Improved Curse of Agony", 3, "Nightfall", 2, "Soul Siphon", 3, "Siphon Life", 1,
				"Malediction", 1, "Rapid Deterioration", 2, "Shadow Mastery", 5, "Dark Harvest", 1,
				"Cataclysm", 5, "Bane", 5, "Intensity", 2, "Devastation", 5, "Destructive Reach", 2,
			} },
			{ spec = "Demonology", split = "0/35/16", order = {
				"Demonic Embrace", 5, "Demonic Aegis", 3, "Fel Intellect", 3, "Fel Domination", 1,
				"Fel Stamina", 5, "Master Summoner", 2, "Unholy Power", 3, "Power Overwhelming", 1,
				"Demonic Precision", 3, "Master Demonologist", 5, "Unleashed Potential", 3, "Soul Link", 1,
				"Shadow Vulnerability", 1, "Cataclysm", 5, "Bane", 5, "Devastation", 5,
			} },
			{ spec = "Destruction", split = "0/12/39", order = {
				"Shadow Vulnerability", 5, "Cataclysm", 5, "Bane", 5, "Intensity", 2, "Shadowburn", 1,
				"Devastation", 5, "Pyroclasm", 2, "Destructive Reach", 2, "Improved Immolate", 5, "Ruin", 1,
				"Emberstorm", 5, "Conflagrate", 1, "Demonic Embrace", 5, "Soul Entrapment", 3,
				"Demonic Aegis", 2, "Fel Domination", 1, "Demonic Sacrifice", 1,
			} },
		},
	},
	WARRIOR = {
		levelling = { spec = "Arms", split = "31/20/0", order = {
			"Improved Heroic Strike", 3, "Improved Rend", 2, "Improved Charge", 2, "Tactical Mastery", 3,
			"Deep Wounds", 3, "Improved Overpower", 2, "Two-Handed Weapon Specialization", 3, "Impale", 2,
			"Sweeping Strikes", 1, "Master Strike", 1, "Master of Arms", 5, "Tactical Mastery", 5,
			"Deflection", 1, "Mortal Strike", 1, "Cruelty", 5, "Unbridled Wrath", 5, "Improved Shouts", 5,
			"Enrage", 5,
		} },
		alts = {
			{ name = "Protection", spec = "Protection", split = "16/0/35", order = {
				"Shield Specialization", 5, "Toughness", 5, "Improved Revenge", 3, "Improved Bloodrage", 2,
				"Last Stand", 1, "Defiance", 4, "Shield Slam", 1, "One-Handed Weapon Specialization", 5,
				"Improved Shield Slam", 2, "Reprisal", 2, "Concussion Blow", 1, "Defiance", 5,
				"Defensive Tactics", 3, "Improved Heroic Strike", 3, "Tactical Mastery", 5, "Improved Rend", 2,
				"Deep Wounds", 3, "Improved Charge", 2, "Deflection", 1,
			} },
		},
		specs = {
			{ spec = "Arms", split = "31/20/0", order = {
				"Improved Heroic Strike", 3, "Tactical Mastery", 5, "Improved Rend", 2, "Improved Charge", 2,
				"Deflection", 1, "Master Strike", 1, "Improved Overpower", 2, "Deep Wounds", 3,
				"Two-Handed Weapon Specialization", 3, "Impale", 2, "Master of Arms", 5, "Sweeping Strikes", 1,
				"Mortal Strike", 1, "Cruelty", 5, "Unbridled Wrath", 5, "Improved Shouts", 5, "Enrage", 5,
			} },
			{ spec = "Fury", split = "17/34/0", order = {
				"Cruelty", 5, "Dual Wield Specialization", 5, "Unbridled Wrath", 5, "Improved Shouts", 5,
				"Enrage", 5, "Death Wish", 1, "Improved Execute", 2, "Flurry", 5, "Bloodthirst", 1,
				"Improved Heroic Strike", 3, "Tactical Mastery", 5, "Improved Rend", 2, "Improved Overpower", 2,
				"Deep Wounds", 3, "Impale", 2,
			} },
			{ spec = "Protection", split = "15/0/36", order = {
				"Improved Bloodrage", 2, "Shield Specialization", 5, "Anticipation", 3, "Toughness", 5,
				"Last Stand", 1, "Improved Taunt", 1, "Improved Revenge", 3, "Defiance", 5,
				"One-Handed Weapon Specialization", 5, "Shield Slam", 1, "Reprisal", 2,
				"Improved Shield Slam", 2, "Concussion Blow", 1, "Improved Heroic Strike", 3,
				"Tactical Mastery", 5, "Improved Rend", 2, "Deflection", 5,
			} },
		},
	},
}
