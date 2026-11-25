-- ShikiUI BossMods : alarmes de raid (module "bossmods"), moteur maison inspire des PRINCIPES de BigWigs (aucun code copie) :
-- des barres de compte a rebours et des annonces quand un evenement de boss arrive.
-- DEUX MODES (reglage bossmods.mode : auto / bigwigs / own) : si BigWigs est installe, le PONT (M.BW, en bas de fichier) le laisse
-- chronometrer et annoncer et se contente de l'habiller (barres CandyBar, messages), de rendre ses ancres deplacables (Mover) et de
-- prendre son pull ; le moteur ci-dessous est alors COUPE. Sans BigWigs (ou mode own), le moteur ci-dessous sert de secours.
--
-- Fonctionnement :
--   1. la cible du joueur (ou la souris) est reconnue comme un boss connu : nom plie (accents FR ignores) ;
--   2. l'entree en combat avec ce boss fixe t0 ; chaque evenement du boss est RELATIF au combat
--      (t = premier declenchement en secondes, every = repetition) ;
--   3. "lead" secondes avant l'evenement : la barre s'allume ("Nom - 10s") et l'annonce part (canal au choix) ;
--   4. a 0 la barre part : l'effet arrive, la barre disparait ; les repetitions replanifient tout seuls.
-- Donnees vanilla d'abord (MC, Onyxia, BWL, ZG, AQ20, AQ40, Naxxramas, boss monde) : valeurs publies des guides,
-- NON VERIFIEES EN JEU (variations de serveurs possibles). La table M.BOSSES est publique et documentee pour ajouter
-- des boss / instances custom OctoWow (cle = nom du boss plie, valeurs identite EN acceptees pour les mobs non traduits).
-- Cout declare : "medium" (balayage 0,25 s tant qu'un boss connu est vise ou la fenetre ouverte ; sinon 0).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.BossMods = M
local B = {}              -- pont BigWigs (voir plus bas, "PONT BIGWIGS")
M.BW = B

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, mmin, mmax = math.floor, math.min, math.max
local sfind, slower, sgsub, strsub = string.find, string.lower, string.gsub, string.sub
local EMPTY = ""

M.on = false
M.win = nil
M.task = nil
M.cur = nil            -- cle pliee du boss courant, ou nil
M.curLabel = EMPTY
M.combatAt = nil       -- instant d'entree en combat avec ce boss
M.armed = {}           -- barres en cours : { name, endsAt, dur, ev, phase, pull }
M.narmed = 0
M.flash = nil          -- frame de flash d'ecran (creee hors combat)
M.flashUntil = nil
M.pullIgnore = nil     -- ignore les pulls recus juste apres avoir lance le notre
M.next = {}             -- [evenement] = moment du prochain declenchement
M.warns = {}            -- [evenement] = instant de l'annonce lead (antidoublon)

M.BARH = 15
M.GAP = 2
M.MAXBARS = 8

-- ---------------------------------------------------------------- donnees vanilla
-- Chaque boss : label (affichage) + ev = liste d'evenements :
--   t     : premier declenchement relatif a l'entree en combat (secondes)
--   every : repetition (toutes les N secondes)
--   dur   : duree de l'effet (longueur de barre apres le lancement)
--   warn  : annonce RAID au moment de la mise en place
--   react : evenement SANS horloge (t = 600 etait un emplacement fantome) : jamais arme tout seul, seulement par M.React(boss, nom)
-- Valeurs = guides vanilla publies, NON VERIFIEES EN JEU (voir entete).
M.BOSSES = {
	["antnormi"] = {
		label = "Antnormi",
		ev = {
			{ t = 20, every = 20, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Feared!", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Shadow Shock CD", dur = 3, warn = true },
		},
	},
	["anubisath defender"] = {
		label = "Anubisath Defender",
		ev = {
			{ t = 600, every = 600, react = true, name = "Fire & Arcane Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, react = true, name = "Shadow & Frost Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
			{ t = 40, every = 40, name = "Plagued", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", warn = true },
			{ t = 600, every = 600, react = true, name = "Thunder Clap", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, react = true, name = "Shadow Storm", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, react = true, name = "Meteor", dur = 3, icon = "Interface\\Icons\\Spell_Fire_Fireball02", warn = true },
			{ t = 6, every = 6, name = "Exploding!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["anubisath guardian"] = {
		label = "Anubisath Guardian",
		ev = {
			{ t = 600, every = 600, react = true, name = "Fire & Arcane Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, react = true, name = "Shadow & Frost Reflect", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
			{ t = 40, every = 40, name = "Plagued", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges", warn = true },
			{ t = 600, every = 600, react = true, name = "Thunder Clap CD", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, react = true, name = "Shadow Storm CD", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, react = true, name = "Meteor CD", dur = 3, icon = "Interface\\Icons\\Spell_Fire_Fireball02", warn = true },
			{ t = 6, every = 6, name = "Exploding!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["anubisath sentinel"] = {
		label = "Anubisath Sentinel",
		ev = {
			{ t = 600, every = 600, react = true, name = "has Knockback", dur = 3, icon = "Interface\\Icons\\Inv_Gauntlets_05", warn = true },
			{ t = 600, every = 600, react = true, name = "has Mana Burn", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Manaburn", warn = true },
			{ t = 600, every = 600, react = true, name = "has Mending", dur = 3, icon = "Interface\\Icons\\spell_nature_resistnature", warn = true },
			{ t = 600, every = 600, react = true, name = "has Mortal Strike", dur = 3, icon = "Interface\\Icons\\ability_warrior_savageblow", warn = true },
			{ t = 600, every = 600, react = true, name = "has Shadow Storm", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 600, every = 600, react = true, name = "has Thorns", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Thorns", warn = true },
			{ t = 600, every = 600, react = true, name = "has Thunderclap", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
			{ t = 600, every = 600, react = true, name = "reflect Fire & Arcane", dur = 3, icon = "Interface\\Icons\\spell_arcane_portaldarnassus", warn = true },
			{ t = 600, every = 600, react = true, name = "reflect Shadow & Frost", dur = 3, icon = "Interface\\Icons\\spell_arcane_portalundercity", warn = true },
		},
	},
	["atiesh"] = {
		label = "Atiesh",
		ev = {
			{ t = 2, every = 2, name = "Unholy Aura", dur = 3, icon = "Interface\\Icons\\spell_shadow_unholystrength", warn = true },
		},
	},
	["ayamiss the hunter"] = {
		label = "Ayamiss",
		ev = {
			{ t = 25, every = 25, name = "Stinger Spray", dur = 3 },
		},
	},
	-- ===== AQ40 =====
	["the prophet skeram"] = {
		label = "Skeram",
		ev = {
			{ t = 25, every = 25, name = "Earth Shock", dur = 3 },
		},
	},
	["azuregos"] = {
		label = "Azuregos",
		ev = {
			{ t = 24, every = 24, name = "Chill CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Arcane Vacuum CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Arcane Vacuum Ready...", dur = 3, warn = true },
		},
	},
	["baron geddon"] = {
		label = "Baron Geddon",
		ev = {
			{ t = 8, every = 8, name = "Bomb!", dur = 3, icon = "Interface\\Icons\\inv_enchant_essenceastralsmall", warn = true },
		},
	},
	["battleguard sartura"] = {
		label = "Sartura",
		ev = {
			{ t = 45, every = 45, name = "Whirlwind", dur = 5, warn = true },
		},
	},
	["bloodlord mandokir"] = {
		label = "Bloodlord Mandokir",
		ev = {
			{ t = 12, every = 12, name = "Threatening Gaze CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Gaze!", dur = 3, warn = true },
			{ t = 18, every = 18, name = "Whirlwind CD", dur = 3, warn = true },
		},
	},
	-- (dedup 2026-11-20 : doublon retire, la definition suivante fait foi)
	["broodlord lashlayer"] = {
		label = "Broodlord Lashlayer",
		ev = {
			{ t = 20, every = 20, name = "Mortal Strike CD", dur = 3, warn = true },
		},
	},
	["broodlord lushwing"] = {
		label = "Broodlord",
		ev = {
			{ t = 30, every = 30, name = "Blast Wave", dur = 3 },
		},
	},
	["buru the gorger"] = {
		label = "Buru the Gorger",
		ev = {
			{ t = 10, every = 10, name = "Dismember", dur = 3, icon = "Interface\\Icons\\ability_backstab", warn = true },
		},
	},
	["c'thun"] = {
		label = "C'Thun",
		ev = {
			{ t = 45, every = 45, name = "Eye Beam", dur = 3, warn = true },
			{ t = 40, every = 40, name = "Dark Glare", dur = 3, warn = true },
		},
	},
	-- ===== NAXX =====
	["anub'rekhan"] = {
		label = "Anub'Rekhan",
		ev = {
			{ t = 20, every = 20, name = "Locust Swarm", dur = 12, warn = true },
		},
	},
	["chieftain partath"] = {
		label = "Chieftain Partath",
		ev = {
			{ t = 15, every = 15, name = "Immune", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", warn = true },
		},
	},
	["chromaggus"] = {
		label = "Chromaggus",
		ev = {
			{ t = 12, every = 12, name = "Breath", dur = 3, warn = true },
		},
	},
	["chronar"] = {
		label = "Chronar",
		ev = {
			{ t = 10, every = 10, name = "Spell Reflect", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
			{ t = 5, every = 5, name = "Mortal Strike", dur = 3, icon = "Interface\\Icons\\ability_warrior_savageblow", warn = true },
		},
	},
	["core hound"] = {
		label = "Core Hound",
		ev = {
			{ t = 10, every = 10, name = "Respawn", dur = 3, icon = "Interface\\Icons\\spell_holy_resurrection", warn = true },
			{ t = 11, every = 11, name = "Despawn", dur = 3, icon = "Interface\\Icons\\inv_misc_pocketwatch_01", warn = true },
		},
	},
	["cthun"] = {
		label = "C'Thun",
		ev = {
			{ t = 8, every = 8, name = "Start of Random Beams!", dur = 3, warn = true },
			{ t = 39, every = 39, name = "Dark Glare!", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Small Claw Spawn", dur = 3, icon = "Interface\\Icons\\spell_nature_thorns", warn = true },
		},
	},
	["dark reaver of karazhan"] = {
		label = "Dark Reaver of Karazhan",
		ev = {
			{ t = 22, every = 22, name = "4 Forlorn Spirit", dur = 3, icon = "Interface\\Icons\\spell_shadow_burningspirit", warn = true },
			{ t = 10, every = 10, name = "Lurking Shadow", dur = 3, icon = "Interface\\Icons\\ability_creature_poison_05", warn = true },
			{ t = 6, every = 6, name = "Unbalancing", dur = 3, icon = "Interface\\Icons\\ability_warrior_decisivestrike", warn = true },
			{ t = 20, every = 20, name = "Pierce Armor", dur = 3, icon = "Interface\\Icons\\spell_shadow_vampiricaura", warn = true },
		},
	},
	["dark rider champion"] = {
		label = "Dark Rider Champion",
		ev = {
			{ t = 5.5, every = 5.5, name = "Reaver Storm CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "Reaver Storm Cast", dur = 3, warn = true },
		},
	},
	["deathknight cavalier"] = {
		label = "Deathknight Cavalier",
		ev = {
			{ t = 3, every = 3, name = "Death Coil", dur = 3, icon = "Interface\\Icons\\spell_shadow_deathcoil", warn = true },
		},
	},
	["doctor weavil"] = {
		label = "Doctor Weavil",
		ev = {
			{ t = 10, every = 10, name = "Mind Shatter CD", dur = 3, warn = true },
			{ t = 6, every = 6, name = "Mind Shatter Soon...", dur = 3, warn = true },
		},
	},
	["drifting avatar of sand"] = {
		label = "Drifting Avatar of Sand",
		ev = {
			{ t = 5, every = 5, name = "Blinded", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindsteal", warn = true },
		},
	},
	["ebonroc"] = {
		label = "Ebonroc",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Shadow of Ebonroc CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Shadow of Ebonroc", dur = 3, warn = true },
		},
	},
	["echo of medivh"] = {
		label = "Echo of Medivh",
		ev = {
			{ t = 12, every = 12, name = "Corruption of Medivh", dur = 3, icon = "Interface\\Icons\\INV_Misc_ShadowEgg", warn = true },
		},
	},
	["emperor vek'lor"] = {
		label = "Vek'lor",
		ev = {
			{ t = 30, every = 30, name = "Explode Bug", dur = 3 },
		},
	},
	["epidamu"] = {
		label = "Epidamu",
		ev = {
			{ t = 5, every = 5, name = "Drain Mana", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
			{ t = 15, every = 15, name = "Temporal Conflux", dur = 3, icon = "Interface\\Icons\\spell_holy_borrowedtime", warn = true },
		},
	},
	["erennius"] = {
		label = "Erennius",
		ev = {
			{ t = 6, every = 6, name = "Wail Casting", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 3, every = 3, name = "Wail Afflicted", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 26, every = 26, name = "Wail of Erennius CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
		},
	},
	["fankriss the unyielding"] = {
		label = "Fankriss the Unyielding",
		ev = {
			{ t = 8, every = 8, name = "Entangled", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Web", warn = true },
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
		},
	},
	["firemaw"] = {
		label = "Firemaw",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
		},
	},
	["flame imp"] = {
		label = "Flame Imp",
		ev = {
			{ t = 420, every = 420, name = "Respawn", dur = 3, icon = "Interface\\Icons\\inv_misc_pocketwatch_01", warn = true },
		},
	},
	["flamegor"] = {
		label = "Flamegor",
		ev = {
			{ t = 29, every = 29, name = "Wing Buffet CD", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Shadow Flame CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Frenzy CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Frenzy!", dur = 3, warn = true },
		},
	},
	["gahzranka"] = {
		label = "Gahz'ranka",
		ev = {
			{ t = 2, every = 2, name = "FrostBreath Dmg+ManaBurn", dur = 3, warn = true },
			{ t = 7, every = 7, name = "Frost Breath CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "knockUP - Aggro Drop", dur = 3, warn = true },
			{ t = 19, every = 19, name = "knockUP AggroDrop CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "knockBACK - CD", dur = 3, icon = "Interface\\Icons\\ability_devour", warn = true },
		},
	},
	["garr"] = {
		label = "Garr",
		ev = {
			{ t = 20, every = 20, name = "Antimagic Pulse", dur = 3, icon = "Interface\\Icons\\spell_holy_dispelmagic", warn = true },
		},
	},
	["gehennas"] = {
		label = "Gehennas",
		ev = {
			{ t = 12, every = 30, name = "Gehennas' Curse", dur = 3 },
			{ t = 10, every = 10, name = "Shadow Bolt", dur = 3 },
		},
	},
	["general drakkisath"] = {
		label = "General Drakkisath",
		ev = {
			{ t = 10, every = 10, name = "Conflag", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
		},
	},
	-- (dedup 2026-11-20 : doublon retire, la definition suivante fait foi)
	["gluth"] = {
		label = "Gluth",
		ev = {
			{ t = 105, every = 105, name = "Decimate", dur = 3, icon = "Interface\\Icons\\INV_Shield_01", warn = true },
			{ t = 330, every = 330, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
		},
	},
	["golemagg the incinerator"] = {
		label = "Golemagg the Incinerator",
		ev = {
			{ t = 3, every = 3, name = "Earthquake", dur = 3, icon = "Interface\\Icons\\spell_nature_earthquake", warn = true },
		},
	},
	["gothik the harvester"] = {
		label = "Gothik the Harvester",
		ev = {
			{ t = 20, every = 20, name = "Trainee - ", dur = 3, icon = "Interface\\Icons\\Ability_Seal", warn = true },
			{ t = 30, every = 30, name = "Rider - ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_DeathPact", warn = true },
		},
	},
	["grand widow faerlina"] = {
		label = "Grand Widow Faerlina",
		ev = {
			{ t = 30, every = 30, name = "Boss Silenced", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Silence", warn = true },
			{ t = 8, every = 8, name = "Raid member Silenced", dur = 3, warn = true },
		},
	},
	["grilek"] = {
		label = "Gri'lek",
		ev = {
			{ t = 10, every = 10, name = "Avatar CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "Avatar!", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Gri'lek Stunned", dur = 3, icon = "Interface\\Icons\\spell_frost_stun", warn = true },
			{ t = 18, every = 18, name = "Ground Tremor CD", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Ground Tremor Stun", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Rooted", dur = 3, icon = "Interface\\Icons\\spell_nature_stranglevines", warn = true },
			{ t = 20, every = 20, name = "Sweeping Strikes!", dur = 3, icon = "Interface\\Icons\\ability_rogue_slicedice", warn = true },
		},
	},
	["grizikil"] = {
		label = "Grizikil",
		ev = {
			{ t = 9, every = 9, name = "Flamewave", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
		},
	},
	["grobbulus"] = {
		label = "Grobbulus",
		ev = {
			{ t = 12, every = 12, name = "Poison Cloud", dur = 3, warn = true },
		},
	},
	["gurubashi berserker"] = {
		label = "Gurubashi Berserker",
		ev = {
			{ t = 25, every = 25, name = "Fear CD", dur = 3, icon = "Interface\\Icons\\Ability_GolemThunderClap", warn = true },
			{ t = 10, every = 10, name = "KnockAway CD", dur = 3, icon = "Interface\\Icons\\INV_Gauntlets_05", warn = true },
			{ t = 15, every = 15, name = "Thunderclap CD", dur = 3, icon = "Interface\\Icons\\Ability_ThunderClap", warn = true },
		},
	},
	["hakkar"] = {
		label = "Hakkar",
		ev = {
			{ t = 11, every = 11, name = "MC CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Blood Siphon!", dur = 3, warn = true },
			{ t = 600, every = 600, react = true, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["hazzarah"] = {
		label = "Hazza'rah",
		ev = {
			{ t = 24, every = 24, name = "Adds Spawn", dur = 3, icon = "Interface\\Icons\\spell_magic_lesserinvisibilty", warn = true },
			{ t = 18, every = 18, name = "Sleep CD", dur = 3, warn = true },
			{ t = 6, every = 6, name = "Sleeping!", dur = 3, warn = true },
			{ t = 60, every = 60, name = "AoE Mana Burn CD", dur = 3, icon = "Interface\\Icons\\spell_shadow_manaburn", warn = true },
		},
	},
	["heigan the unclean"] = {
		label = "Heigan",
		ev = {
			{ t = 15, every = 15, name = "Eruption", dur = 3 },
		},
	},
	["high priest thekal"] = {
		label = "High Priest Thekal",
		ev = {
			{ t = 6, every = 6, name = "Silenced", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Silence", warn = true },
			{ t = 6, every = 6, name = "Disarmed", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_Disarm", warn = true },
			{ t = 10, every = 10, name = "Blinded", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindsteal", warn = true },
			{ t = 4, every = 4, name = "Gouged", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
			{ t = 5, every = 5, name = "Mortal Cleave", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_SavageBlow", warn = true },
			{ t = 30, every = 30, name = "Bloodlust", dur = 3, icon = "Interface\\Icons\\Spell_Nature_BloodLust", warn = true },
			{ t = 10, every = 10, name = "Resurrect", dur = 3, icon = "Interface\\Icons\\spell_holy_resurrection", warn = true },
		},
	},
	["high priest venoxis"] = {
		label = "High Priest Venoxis",
		ev = {
			{ t = 15, every = 15, name = "Renew", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Renew", warn = true },
			{ t = 8, every = 8, name = "Holy Fire", dur = 3, warn = true },
		},
	},
	["high priestess arlokk"] = {
		label = "High Priestess Arlokk",
		ev = {
			{ t = 120, every = 120, name = "Marked", dur = 3, icon = "Interface\\Icons\\Ability_Hunter_Snipershot", warn = true },
			{ t = 16, every = 16, name = "Whirlwind CD", dur = 3, icon = "Interface\\Icons\\Ability_Whirlwind", warn = true },
			{ t = 2, every = 2, name = "Ravage Stun", dur = 3, icon = "Interface\\Icons\\spell_frost_stun", warn = true },
			{ t = 4, every = 4, name = "Gouged", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
			{ t = 18, every = 18, name = "Shadow Word: Pain", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowwordpain", warn = true },
		},
	},
	["high priestess jeklik"] = {
		label = "High Priestess Jeklik",
		ev = {
			{ t = 4, every = 4, name = "Heal - Interrupt!", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Heal CD", dur = 3, warn = true },
			{ t = 25, every = 25, name = "Mind Flay - Interrupt!", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_SiphonMana", warn = true },
			{ t = 10, every = 10, name = "Silence CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "People Silenced", dur = 3, warn = true },
		},
	},
	["incindis"] = {
		label = "Incindis",
		ev = {
			{ t = 5.5, every = 5.5, name = "Fire Nova!", dur = 3, icon = "Interface\\Icons\\spell_fire_selfdestruct", warn = true },
		},
	},
	["instructor razuvious"] = {
		label = "Instructor Razuvious",
		ev = {
			{ t = 25, every = 25, name = "Disrupting Shout", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_WarCry", warn = true },
			{ t = 30, every = 30, name = "Unbalancing Strike", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike", warn = true },
		},
	},
	["jindo the hexxer"] = {
		label = "Jindo",
		ev = {
			{ t = 25, every = 25, name = "Hex", dur = 3, warn = true },
		},
	},
	-- ===== AQ20 =====
	["general rajaxx"] = {
		label = "General Rajaxx",
		ev = {
			{ t = 30, every = 30, name = "Wave", dur = 5, warn = true },
		},
	},
	["karrsh the sentinel"] = {
		label = "Karrsh the Sentinel",
		ev = {
			{ t = 12, every = 12, name = "Furious Roar", dur = 3, icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar", warn = true },
		},
	},
	["kazzak"] = {
		label = "Kazzak",
		ev = {
			{ t = 30, every = 30, name = "Shadow Bolt Volley", dur = 3 },
		},
	},
	["keeper gnarlmoon"] = {
		label = "Keeper Gnarlmoon",
		ev = {
			{ t = 5, every = 5, name = "Lunar Shift Casting!", dur = 3, warn = true },
			{ t = 60, every = 60, name = "Owls Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["kel'thuzad"] = {
		label = "Kel'Thuzad",
		ev = {
			{ t = 20, every = 20, name = "Shadow Fissure", dur = 3 },
			{ t = 30, every = 30, name = "Frost Blast", dur = 3, warn = true },
		},
	},
	["king"] = {
		label = "King",
		ev = {
			{ t = 5, every = 5, name = "King's Fury - Hide!", dur = 3, icon = "Interface\\Icons\\Spell_Holy_HolyNova", warn = true },
			{ t = 11, every = 11, name = "Shield Bash", dur = 3, icon = "Interface\\Icons\\Ability_Warrior_ShieldBash", warn = true },
		},
	},
	["kurinnaxx"] = {
		label = "Kurinnaxx",
		ev = {
			{ t = 15, every = 15, name = "Wounds", dur = 3, icon = "Interface\\Icons\\ability_criticalstrike", warn = true },
			{ t = 20, every = 20, name = "Sand Trap", dur = 3, icon = "Interface\\Icons\\inv_misc_dust_02", warn = true },
		},
	},
	["lethon"] = {
		label = "Lethon",
		ev = {
			{ t = 20, every = 20, name = "Shadow Bolt Whirl", dur = 3 },
		},
	},
	["loatheb"] = {
		label = "Loatheb",
		ev = {
			{ t = 60, every = 60, name = "Your Corrupted Mind", dur = 3, icon = "Interface\\Icons\\spell_shadow_auraofdarkness", warn = true },
		},
	},
	["lord blackwald ii"] = {
		label = "Lord Blackwald II",
		ev = {
			{ t = 5.5, every = 5.5, name = "Reaver Storm CD", dur = 3, warn = true },
			{ t = 1.5, every = 1.5, name = "Reaver Storm Cast", dur = 3, warn = true },
			{ t = 15, every = 15, name = "Boon on ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ChillTouch", warn = true },
			{ t = 10, every = 10, name = "Empowered", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Haunting", warn = true },
			{ t = 45, every = 45, name = "Summons add", dur = 3, icon = "Interface\\Icons\\inv_misc_bone_orcskull_01", warn = true },
		},
	},
	["lord kazzak"] = {
		label = "Lord Kazzak",
		ev = {
			{ t = 180, every = 180, name = "Berserk", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 10, every = 10, name = "Mark of Kazzak CD", dur = 3, warn = true },
			{ t = 60, every = 60, name = "Mark of Kazzak", dur = 3, warn = true },
			{ t = 14, every = 14, name = "Twisted Reflection CD", dur = 3, warn = true },
			{ t = 45, every = 45, name = "Twisted Reflect", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Void Bolt CD", dur = 3, warn = true },
			{ t = 4, every = 4, name = "Void Bolt!", dur = 3, warn = true },
		},
	},
	["lucifron"] = {
		label = "Lucifron",
		ev = {
			{ t = 8, every = 8, name = "MC CD", dur = 3, warn = true },
			{ t = 15, every = 15, name = "MC ", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", warn = true },
		},
	},
	["mad servant"] = {
		label = "Mad Servant",
		ev = {
			{ t = 11, every = 11, name = "Void Spawn - Portal ", dur = 3, icon = "Interface\\Icons\\spell_shadow_sealofkings", warn = true },
		},
	},
	["maexxna"] = {
		label = "Maexxna",
		ev = {
			{ t = 20, every = 20, name = "Cocoon CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Spiderlings", dur = 3, icon = "Interface\\Icons\\INV_Misc_MonsterSpiderCarapace_01", warn = true },
		},
	},
	["magmadar"] = {
		label = "Magmadar",
		ev = {
			{ t = 30, every = 30, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Fear Soon...", dur = 3, warn = true },
		},
	},
	["majordomo executus"] = {
		label = "Majordomo Executus",
		ev = {
			{ t = 20, every = 20, name = "Reflection CD", dur = 3, warn = true },
		},
	},
	["mandokir"] = {
		label = "Mandokir",
		ev = {
			{ t = 60, every = 60, name = "Frightening Shout", dur = 3, warn = true },
		},
	},
	["mar'li"] = {
		label = "Mar'li",
		ev = {
			{ t = 20, every = 20, name = "Enrage", dur = 3 },
		},
	},
	["moam"] = {
		label = "Moam",
		ev = {
			{ t = 90, every = 90, name = "Mana Burn", dur = 3, warn = true },
		},
	},
	["moroes"] = {
		label = "Moroes",
		ev = {
			{ t = 10, every = 10, name = "Players Smoke Bombed", dur = 3, icon = "Interface\\Icons\\Ability_Vanish", warn = true },
			{ t = 5, every = 5, name = "Spell Reflect!", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
			{ t = 4, every = 4, name = "Kicked", dur = 3, icon = "Interface\\Icons\\Ability_Kick", warn = true },
			{ t = 10, every = 10, name = "Dusted", dur = 3, icon = "Interface\\Icons\\Ability_Hibernation", warn = true },
		},
	},
	["mossheart"] = {
		label = "Mossheart",
		ev = {
			{ t = 180, every = 180, name = "Moss", dur = 3, icon = "Interface\\Icons\\spell_nature_magicimmunity", warn = true },
			{ t = 25, every = 25, name = "Entangling Roots CD", dur = 3, icon = "Interface\\Icons\\spell_nature_stranglevines", warn = true },
			{ t = 12, every = 12, name = "Rejuvenation", dur = 3, icon = "Interface\\Icons\\spell_nature_rejuvenation", warn = true },
		},
	},
	["nefarian"] = {
		label = "Nefarian",
		ev = {
			{ t = 12.4, every = 12.4, name = "AoE Shadow Flame", dur = 3, warn = true },
		},
	},
	["nerubian overseer"] = {
		label = "Nerubian Overseer",
		ev = {
			{ t = 10, every = 10, name = "Shadow Shock", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadowbolt", warn = true },
			{ t = 30, every = 30, name = "Venom Spit", dur = 3, icon = "Interface\\Icons\\spell_nature_corrosivebreath", warn = true },
			{ t = 30, every = 30, name = "Corrosive Poison", dur = 3, icon = "Interface\\Icons\\Corrosive Acid Spit", warn = true },
			{ t = 30, every = 30, name = "Necrotic Poison", dur = 3, icon = "Interface\\Icons\\ability_creature_poison_03", warn = true },
			{ t = 10, every = 10, name = "Web Spray", dur = 3, icon = "Interface\\Icons\\inv_egg_04", warn = true },
		},
	},
	["noth the plaguebringer"] = {
		label = "Noth",
		ev = {
			{ t = 25, every = 25, name = "Curse of the Plaguebringer", dur = 3, warn = true },
			{ t = 90, every = 90, name = "Blink", dur = 3 },
		},
	},
	["onyxia"] = {
		label = "Onyxia",
		ev = {
			{ t = 30, every = 30, name = "Deep Breath", dur = 3, warn = true },
		},
	},
	["ossirian the unscarred"] = {
		label = "Ossirian",
		ev = {
			{ t = 20, every = 20, name = "Tornado", dur = 3 },
		},
	},
	["ostarius"] = {
		label = "Ostarius",
		ev = {
			{ t = 10, every = 10, name = "Conflag", dur = 3, icon = "Interface\\Icons\\spell_fire_incinerate", warn = true },
			{ t = 12, every = 12, name = "Stomped", dur = 3, icon = "Interface\\Icons\\ability_warstomp", warn = true },
		},
	},
	["ouro"] = {
		label = "Ouro",
		ev = {
			{ t = 20, every = 20, name = "Sand Blast", dur = 3, warn = true },
		},
	},
	["patchwerk"] = {
		label = "Patchwerk",
		ev = {
			{ t = 420, every = 420, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["princess huhuran"] = {
		label = "Huhuran",
		ev = {
			{ t = 30, every = 30, name = "Wyvern Sting", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Frenzy", dur = 3 },
		},
	},
	["pyroguard emberseer"] = {
		label = "Pyroguard Emberseer",
		ev = {
			{ t = 6, every = 6, name = "Fire Nova", dur = 3, icon = "Interface\\Icons\\spell_fire_sealoffire", warn = true },
		},
	},
	["qiraji brainwasher"] = {
		label = "Qiraji Brainwasher",
		ev = {
			{ t = 8, every = 8, name = "Mind Flay", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
		},
	},
	["qiraji mindslayer"] = {
		label = "Qiraji Mindslayer",
		ev = {
			{ t = 8, every = 8, name = "Mind Flay", dur = 3, icon = "Interface\\Icons\\spell_shadow_siphonmana", warn = true },
			{ t = 8, every = 8, name = "Mana Burn & Disorient", dur = 3, icon = "Interface\\Icons\\spell_shadow_manaburn", warn = true },
		},
	},
	["ragnaros"] = {
		label = "Ragnaros",
		ev = {
			{ t = 90, every = 90, name = "Emerge", dur = 3, warn = true },
			{ t = 25, every = 25, name = "Knockback CD", dur = 3, warn = true },
			{ t = 8, every = 8, name = "Knockback Soon...", dur = 3, warn = true },
		},
	},
	["razorgore the untamed"] = {
		label = "Razorgore the Untamed",
		ev = {
			{ t = 10, every = 10, name = "Slowed", dur = 3, icon = "Interface\\Icons\\spell_nature_slow", warn = true },
			{ t = 90, every = 90, name = "Orb Control", dur = 3, icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03", warn = true },
			{ t = 60, every = 60, name = "Mind Exhaustion", dur = 3, icon = "Interface\\Icons\\spell_shadow_teleport", warn = true },
		},
	},
	["renataki"] = {
		label = "Renataki",
		ev = {
			{ t = 28, every = 28, name = "Vanish", dur = 3, icon = "Interface\\Icons\\ability_vanish", warn = true },
			{ t = 20, every = 20, name = "Return", dur = 3, icon = "Interface\\Icons\\ability_rogue_ambush", warn = true },
			{ t = 9, every = 9, name = "Gouge CD", dur = 3, icon = "Interface\\Icons\\ability_gouge", warn = true },
		},
	},
	["rotmaw"] = {
		label = "Rotmaw",
		ev = {
			{ t = 240, every = 240, name = "Contagion", dur = 3, icon = "Interface\\Icons\\spell_shadow_callofbone", warn = true },
			{ t = 15, every = 15, name = "Consumed", dur = 3, icon = "Interface\\Icons\\spell_nature_drowsy", warn = true },
		},
	},
	["sanctum dragonkin"] = {
		label = "Sanctum Dragonkin",
		ev = {
			{ t = 5, every = 5, name = "Dragonkin Spell Reflect", dur = 3, icon = "Interface\\Icons\\Spell_Arcane_Blink", warn = true },
		},
	},
	["sanctum dreamer"] = {
		label = "Sanctum Dreamer",
		ev = {
			{ t = 10, every = 10, name = "People Sleeping", dur = 3, icon = "Interface\\Icons\\Spell_Nature_Sleep", warn = true },
		},
	},
	["sanctum supressor"] = {
		label = "Sanctum Supressor",
		ev = {
			{ t = 12, every = 12, name = "Supression", dur = 3, icon = "Interface\\Icons\\Spell_Nature_MagicImmunity", warn = true },
		},
	},
	["sanctum wyrm"] = {
		label = "Sanctum Wyrm",
		ev = {
			{ t = 15, every = 15, name = "Poison Bolt Volley", dur = 3, icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", warn = true },
		},
	},
	["sanctum wyrmkin"] = {
		label = "Sanctum Wyrmkin",
		ev = {
			{ t = 30, every = 30, name = "Venom", dur = 3, icon = "Interface\\Icons\\Ability_Creature_Poison_03", warn = true },
		},
	},
	["sanv tasdal"] = {
		label = "Sanv Tas'dal",
		ev = {
			{ t = 6, every = 6, name = "Overflowing Hatred", dur = 3, warn = true },
		},
	},
	["sapphiron"] = {
		label = "Sapphiron",
		ev = {
			{ t = 7, every = 7, name = "Frost Breath Exploding!", dur = 3, icon = "Interface\\Icons\\spell_frost_frostward", warn = true },
			{ t = 24, every = 24, name = "Life Drain", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02", warn = true },
		},
	},
	["shazzrah"] = {
		label = "Shazzrah",
		ev = {
			{ t = 16, every = 16, name = "Counterspell CD", dur = 3, warn = true },
			{ t = 3, every = 3, name = "Counterspell Soon...", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Shazzrah's Curse CD", dur = 3, warn = true },
		},
	},
	["solakar flamewreath"] = {
		label = "Solakar Flamewreath",
		ev = {
			{ t = 40, every = 40, name = "Solakar spawns", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Stun!", dur = 3, icon = "Interface\\Icons\\ability_bullrush", warn = true },
		},
	},
	["solnius"] = {
		label = "Solnius",
		ev = {
			{ t = 600, every = 600, react = true, name = "Solnius is Immune", dur = 3, icon = "Interface\\Icons\\Inv_Misc_Pocketwatch_01", warn = true },
			{ t = 45, every = 45, name = "Solnius is Sleeping", dur = 3, icon = "Interface\\Icons\\Inv_Misc_Pocketwatch_01", warn = true },
			{ t = 6, every = 6, name = "Wail Casting", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 3, every = 3, name = "Wail Afflicted", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
			{ t = 26, every = 26, name = "Wail of Erennius CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_ShadeTruesight", warn = true },
		},
	},
	["sulfuron harbinger"] = {
		label = "Sulfuron Harbinger",
		ev = {
			{ t = 10, every = 10, name = "Hand of Ragnaros CD", dur = 3, warn = true },
			{ t = 2, every = 2, name = "Hand of Ragnaros Stun", dur = 3, warn = true },
		},
	},
	["taerar"] = {
		label = "Taerar",
		ev = {
			{ t = 20, every = 20, name = "Bane of Awakening", dur = 3 },
		},
	},
	["thaddius"] = {
		label = "Thaddius",
		ev = {
			{ t = 10, every = 10, name = "Power Surge", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
			{ t = 20.5, every = 20.5, name = "Magnetic Pull", dur = 3, icon = "Interface\\Icons\\spell_nature_groundingtotem", warn = true },
			{ t = 300, every = 300, name = "Enrage", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy", warn = true },
		},
	},
	["the beast"] = {
		label = "The Beast",
		ev = {
			{ t = 10, every = 10, name = "Fear CD", dur = 3, warn = true },
			{ t = 5, every = 5, name = "Fear Duration", dur = 3, warn = true },
		},
	},
	["the bug family"] = {
		label = "The Bug Family",
		ev = {
			{ t = 20, every = 20, name = "Panic CD", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_DeathScream", warn = true },
			{ t = 2, every = 2, name = "Great Heal", dur = 3, icon = "Interface\\Icons\\Spell_Holy_Heal", warn = true },
		},
	},
	["the four horsemen"] = {
		label = "Four Horsemen",
		ev = {
			{ t = 12, every = 12, name = "Mark", dur = 3, warn = true },
		},
	},
	-- ===== MONDE =====
	["emeriss"] = {
		label = "Emeriss",
		ev = {
			{ t = 15, every = 15, name = "Volatile Infection", dur = 3 },
		},
	},
	["time-lord epochronos"] = {
		label = "Time-Lord Epochronos",
		ev = {
			{ t = 2, every = 2, name = "Sand Breath Cast", dur = 3, warn = true },
			{ t = 13, every = 13, name = "Sand Breath CD", dur = 3, warn = true },
			{ t = 30, every = 30, name = "Banish", dur = 3, icon = "Interface\\Icons\\spell_shadow_cripple", warn = true },
			{ t = 30, every = 30, name = "Devouring Plague", dur = 3, icon = "Interface\\Icons\\spell_shadow_shadetruesight", warn = true },
			{ t = 3, every = 3, name = "Death Coil", dur = 3, icon = "Interface\\Icons\\spell_shadow_deathcoil", warn = true },
		},
	},
	["twilight corrupter"] = {
		label = "Twilight Corrupter",
		ev = {
			{ t = 8, every = 8, name = "MC CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Soul Corruption CD", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Soul Corruption Soon...", dur = 3, warn = true },
			{ t = 600, every = 600, react = true, name = "AP Buff", dur = 3, icon = "Interface\\Icons\\spell_nature_strength", warn = true },
		},
	},
	["twin golems"] = {
		label = "Twin Golems",
		ev = {
			{ t = 15, every = 15, name = "X Bulwark", dur = 3, icon = "Interface\\Icons\\ability_mage_moltenarmor", warn = true },
		},
	},
	["ursol"] = {
		label = "Ursol",
		ev = {
			{ t = 30, every = 30, name = "RP - Immune", dur = 3, icon = "Interface\\Icons\\Spell_Shadow_Cripple", warn = true },
			{ t = 92, every = 92, name = "Add Phase", dur = 3, icon = "Interface\\Icons\\Spell_Holy_PowerInfusion", warn = true },
			{ t = 5, every = 5, name = "Roar of Terror", dur = 3, icon = "Interface\\Icons\\Ability_Druid_ChallangingRoar", warn = true },
		},
	},
	["vaelastrasz"] = {
		label = "Vaelastrasz",
		ev = {
			{ t = 15, every = 15, name = "Fire Burning", dur = 3, warn = true },
		},
	},
	["vaelastrasz the corrupt"] = {
		label = "Vaelastrasz the Corrupt",
		ev = {
			{ t = 15, every = 15, name = "Burning Adrenaline CD", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Burning!", dur = 3, icon = "Interface\\Icons\\spell_shadow_mindbomb", warn = true },
		},
	},
	["viscidus"] = {
		label = "Viscidus",
		ev = {
			{ t = 15, every = 15, name = "Poison Bolt Volley", dur = 3 },
		},
	},
	["warchief rend blackhand"] = {
		label = "Warchief Rend Blackhand",
		ev = {
			{ t = 36.5, every = 36.5, name = "Gyth", dur = 3, warn = true },
		},
	},
	["ysondre"] = {
		label = "Ysondre",
		ev = {
			{ t = 20, every = 20, name = "Lightning Wave", dur = 3 },
		},
	},

	-- ===== OCTOWOW / TURTLE (donnees extraites de BigWigs TW installe) =====
	["brood queen araxxna"] = {
		label = "Brood Queen Araxxna",
		ev = {
			{ t = 8, every = 8, name = "Brood Venom Volley", dur = 3, warn = true },
			{ t = 10, every = 10, name = "Leeching Bite", dur = 3, warn = true },
			{ t = 20, every = 20, name = "Skitterweb Egg Hatch", dur = 3, warn = true },
		},
	},
}

M.bossByKey = {}

local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\146"] = "a", ["\195\149"] = "o", ["\195\154"] = "u", ["\195\177"] = "n",
}
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "\195[\128-\191]", function(seq) return PLAIN[seq] or seq end)
	return out
end
M.fold = fold

local function indexBosses()
	local k
	for k in pairs(M.bossByKey) do M.bossByKey[k] = nil end
	local b
	for b in pairs(M.BOSSES) do M.bossByKey[fold(b)] = M.BOSSES[b] end
end
indexBosses()

-- ---------------------------------------------------------------- detection du boss
-- Unite visee = cible du joueur, sinon souris.
local function targetUnit()
	if UnitExists("target") and UnitCanAttack("player", "target") then return "target" end
	if UnitExists("mouseover") and UnitCanAttack("player", "mouseover") then return "mouseover" end
	return nil
end

function M.Detect()
	local unit = targetUnit()
	local nm = unit and UnitName(unit) or nil
	local key = nil
	if nm and nm ~= EMPTY and not UnitIsPlayer(unit) then
		key = fold(nm)
		if not M.BOSSES[key] then
			-- tolerance client FR : "Le Recousu" -> "recousu"
			local cut = sfind(key, "^l[ae] ")
			if cut then
				local alt = strsub(key, cut + 3)
				if M.BOSSES[alt] then key = alt end
			end
		end
	end
	if key and M.BOSSES[key] then
		if M.cur ~= key then
			M.cur = key
			M.curLabel = M.BOSSES[key].label or nm
			-- l'horloge est celle du COMBAT : changer de cible en combat ne la remet pas a zero
			if not SUI.InCombat() then M.combatAt = nil end
			M.armed = {}
			M.narmed = 0
			M.next = {}
			M.warns = {}
		end
	else
		if M.cur then
			M.cur = nil
			M.curLabel = EMPTY
			if not SUI.InCombat() then M.combatAt = nil end
			-- les barres de PULL survivent : elles ne dependent pas du boss vise
			local keep, n = {}, 0
			local k
			for k = 1, M.narmed do
				if M.armed[k].pull then
					n = n + 1
					keep[n] = M.armed[k]
				end
			end
			M.armed = keep
			M.narmed = n
			M.next = {}
			M.warns = {}
		end
	end
end

-- ---------------------------------------------------------------- annonce
function M.ShowMsg(main, sub)
	local mf = M.msg
	if not mf or not C.Get("bossmods.showmsg") then return end
	mf.txt1:SetText(main or EMPTY)
	mf.txt2:SetText(sub or EMPTY)
	mf:Show()
	M.msgHideAt = GetTime() + 4
	if not M.msgTask then
		M.msgTask = SUI.Every(0.25, M.MsgTick, "bossmods.msg", true)
	end
end

function M.MsgTick()
	local mf = M.msg
	if not mf then M.MsgStop() return end
	if M.msgHideAt and GetTime() >= M.msgHideAt then M.MsgStop() end
end

function M.MsgStop()
	if M.msgTask then
		SUI.Cancel(M.msgTask)
		M.msgTask = nil
	end
	if M.msg then M.msg:Hide() end
end

-- UNE SEULE personne annonce au raid : le chef tout de suite, un assistant apres un delai propre a son nom (annule si un autre a deja
-- annonce, message addon "ann:<nom>"), tous les autres chez eux. Hors raid, au groupe : seul le chef du groupe parle.
M.annSeen = {}          -- [nom d'evenement] = instant de la derniere annonce vue d'un autre joueur

function M.AnnDelay()
	local nm = UnitName("player") or EMPTY
	local sum, i = 0, 1
	while i <= string.len(nm) do
		sum = sum + string.byte(nm, i)
		i = i + 1
	end
	return 0.6 + SUI.Mod(sum, 8) * 0.2
end

function M.AnnClaim(key)
	if type(SendAddonMessage) == "function" then
		pcall(SendAddonMessage, M.PREFIX, "ann:" .. key, "RAID")
	end
end

function M.RaidSay(text, key)
	if not M.CanLead() then return false end
	if IsRaidLeader() then
		SendChatMessage(text, "RAID_WARNING")
		M.AnnClaim(key)
		return true
	end
	SUI.After(M.AnnDelay(), function()
		if not M.on then return end
		local seen = M.annSeen[key]
		if seen and GetTime() - seen < 5 then return end
		SendChatMessage(text, "RAID_WARNING")
		M.AnnClaim(key)
	end, "bossmods.ann")
	return true
end

function M.Announce(name, secs)
	local chan = C.Get("bossmods.channel") or "self"
	local text = L("msg.bossmods.soon", name, secs)
	if C.Get("bossmods.showmsg") and M.msg then M.ShowMsg(name, text) end
	local said = false
	if chan == "raid" and GetNumRaidMembers() > 0 then
		said = M.RaidSay(text, name)
	elseif chan == "party" and GetNumPartyMembers() > 0 then
		if GetNumRaidMembers() > 0 or M.CanLead() then
			SendChatMessage(text, "PARTY")
			said = true
		end
	end
	if not said then SUI.Print(text) end
	if C.Get("bossmods.sound") then
		PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
	end
end

-- ---------------------------------------------------------------- cycle
local function inCombat()
	return UnitAffectingCombat("player") and true or false
end

function M.Tick()
	if not M.on then return end
	if M.testing then
		if M.win and M.win:IsShown() then M.Paint() end
		return
	end
	local nowP = GetTime()
	local p = M.armed[1]
	if p and p.pull then M.PullTick(nowP) end
	if M.eff == "bridge" then return end       -- BigWigs chronometre : notre moteur de boss ne tourne pas (seul le pull local reste)
	M.Detect()
	local d = M.cur and M.BOSSES[M.cur]
	if not d then return end
	local now = GetTime()
	if not M.combatAt and inCombat() then
		M.combatAt = now
	end
	if not M.combatAt then return end
	local lead = C.Get("bossmods.lead") or 10
	-- armement / planification des evenements relatifs, deux phases comme BigWigs :
	--   "lead"   : barre de compte a rebours vers l'evenement (fenetre lead), annonce au depart
	--   "active" : barre de l'effet en cours (dur secondes) une fois l'evenement arrive
	local i, ev
	for i = 1, getn(d.ev) do
		ev = d.ev[i]
		-- react : pas d'horloge (jamais arme tout seul) ; NextOf rattrape aussi une horloge deja ecoulee (changement de boss en combat)
		local nxt = (not ev.react) and M.NextOf(ev, now) or nil
		local leadOn = C.Get("bossmods.incoming") ~= false
		local activeOn = C.Get("bossmods.active") ~= false
		if nxt then
			-- phase lead
			if leadOn and not M.armedHas(ev.name, "lead") and now >= nxt - lead and now < nxt and not M.warns[ev] then
				M.warns[ev] = now
				tinsert(M.armed, { name = ev.name, icon = ev.icon, endsAt = nxt, ev = ev, phase = "lead" })
				M.narmed = M.narmed + 1
				M.Announce(ev.name, floor(nxt - now + 0.5))
				if M.win and M.win:IsShown() then M.Paint() end
			end
			-- l'evenement est arrive : barre active (si duree) puis repetition planifiee
			if now >= nxt then
				local k
				for k = M.narmed, 1, -1 do
					if M.armed[k].ev == ev and M.armed[k].phase == "lead" then
						tremove(M.armed, k)
						M.narmed = M.narmed - 1
					end
				end
				M.next[ev] = nxt + (ev.every or 3600)
				M.warns[ev] = nil
				local dur = ev.dur or 0
				if activeOn and dur > 0 then
					tinsert(M.armed, { name = ev.name, icon = ev.icon, endsAt = now + dur, ev = ev, phase = "active" })
					M.narmed = M.narmed + 1
				end
				if M.win and M.win:IsShown() then M.Paint() end
			end
		end
	end
	-- purge des barres arrivees a expiration (le pull est purge par PullTick, pas ici)
	local i
	for i = M.narmed, 1, -1 do
		if now >= M.armed[i].endsAt then
			tremove(M.armed, i)
			M.narmed = M.narmed - 1
		end
	end
	if M.win and M.win:IsShown() then M.Paint() end
end

-- Prochain declenchement d'un evenement. Horloge deja ecoulee (boss pris en cours de combat) : on saute au prochain passage a venir,
-- sans rejouer le passe ; un evenement unique deja passe ne reviendra pas (nil).
function M.NextOf(ev, now)
	local nxt = M.next[ev]
	if nxt then return nxt end
	nxt = M.combatAt + (ev.t or 0)
	if now > nxt + 3 then
		local every = ev.every
		if not every or every <= 0 then return nil end
		nxt = nxt + every * math.ceil((now - nxt) / every)
	end
	return nxt
end

-- Evenement "react" du boss courant : arme sa barre d'effet (aucune horloge, aucune annonce au canal).
function M.React(name)
	local d = M.cur and M.BOSSES[M.cur]
	if not M.on or M.eff == "bridge" or not d then return false end
	local i
	for i = 1, getn(d.ev) do
		local ev = d.ev[i]
		if ev.react and ev.name == name then
			tinsert(M.armed, { name = ev.name, icon = ev.icon, endsAt = GetTime() + (ev.dur or 3), ev = ev, phase = "active" })
			M.narmed = M.narmed + 1
			if ev.warn then M.ShowMsg(ev.name, L("mod.bossmods.title")) end
			if M.win and M.win:IsShown() then M.Paint() end
			return true
		end
	end
	return false
end

-- La barre est-elle deja armee pour ce nom ? (antidoublon pendant le lead)
function M.armedHas(name, phase)
	local i
	for i = 1, M.narmed do
		if M.armed[i].name == name and (not phase or M.armed[i].phase == phase) then return true end
	end
	return false
end

-- ---------------------------------------------------------------- fenetre et barres
function M.Build()
	if M.win then return end
	local wbar = C.Get("bossmods.width") or 220
	local f = CreateFrame("Frame", "ShikiUI_BossModsWin", UIParent)
	f:SetWidth(wbar)
	f:SetHeight(M.BARH * M.MAXBARS + 26)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.win = f
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	f.title:SetText(L("mod.bossmods.title"))
	f.status = T.Text(f, 10, T.c.dim, "RIGHT")
	f.status:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
	f.close = T.Button(f, "x", 16, 14, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -22)
	local i
	for i = 1, M.MAXBARS do
		local row = CreateFrame("Frame", nil, f)
		row:SetWidth(204)
		row:SetHeight(M.BARH)
		row:Hide()
		row.bar = T.Bar(row)
		row.bar:SetAllPoints(row)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(15)
		row.icon:SetHeight(15)
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:Hide()
		row.name = T.Text(row, 10, T.c.text, "LEFT", true)
		row.name:SetPoint("LEFT", row, "LEFT", 19, 0)
		row.name:SetWidth(140)
		row.time = T.Text(row, 10, T.c.text, "RIGHT", true)
		row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
		row.time:SetWidth(44)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24 - (i - 1) * (M.BARH + M.GAP))
		M["row" .. i] = row
	end
	SUI.Layout.Register(f, "bossmods.win", "BOTTOMRIGHT", -20, 260)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("bossmods.win", f, { label = L("mod.bossmods.title"), scale = false })
	end
	-- ancre des annonces a l'ecran : un cadre separe, deplacable independamment (comme les ancres BigWigs)
	local mf = CreateFrame("Frame", "ShikiUI_BossModsMsg", UIParent)
	mf:SetWidth(260)
	mf:SetHeight(54)
	T.Backdrop(mf, T.c.panel, T.c.border)
	mf:SetFrameStrata("HIGH")
	mf:EnableMouse(true)
	mf:SetClampedToScreen(true)
	mf:Hide()
	M.msg = mf
	mf.txt1 = T.Text(mf, 13, T.c.warn, "CENTER", true)
	mf.txt1:SetPoint("TOP", mf, "TOP", 0, -8)
	mf.txt1:SetWidth(250)
	mf.txt2 = T.Text(mf, 11, T.c.text, "CENTER", true)
	mf.txt2:SetPoint("BOTTOM", mf, "BOTTOM", 0, 8)
	mf.txt2:SetWidth(250)
	SUI.Layout.Register(mf, "bossmods.msg", "CENTER", 0, 180)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("bossmods.msg", mf, { label = L("mod.bossmods.msgtitle"), scale = false })
	end
	T.OnAccent(function()
		if M.win and M.win:IsShown() then M.Paint() end
	end)
end

function M.Open()
	if not M.on then return end
	if M.eff == "bridge" then
		-- BigWigs affiche les barres : notre fenetre n'a rien a montrer, on ouvre ses options
		B.OpenOptions()
		return
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.win:Show()
		M.EnsureTask()
		M.Paint()
	end)
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.ToggleWin()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

function M.ApplySize()
	if not M.win then return end
	local wbar = C.Get("bossmods.width") or 220
	local rows = C.Get("bossmods.rows") or 6
	local i
	for i = 1, M.MAXBARS do
		local row = M["row" .. i]
		row:SetWidth(wbar - 16)
		if i <= rows then row:SetPoint("TOPLEFT", M.win, "TOPLEFT", 8, -24 - (i - 1) * (M.BARH + M.GAP)) end
	end
	M.win:SetWidth(wbar)
	M.win:SetHeight(M.BARH * M.MAXBARS + 26)
end

function M.EnsureTask()
	if not M.task then
		M.task = SUI.Every(0.25, M.Tick, "bossmods.tick", true)
	end
end

-- ---------------------------------------------------------------- peinture
-- Barres triees du plus proche au plus lointain ; purge des evenements arrives a expiration.
function M.Paint()
	local f = M.win
	if not f or not f:IsShown() then return end
	local now = GetTime()
	local i
	for i = M.narmed, 1, -1 do
		if now >= M.armed[i].endsAt then
			tremove(M.armed, i)
			M.narmed = M.narmed - 1
		end
	end
	-- tri par temps restant croissant
	local order = {}
	for i = 1, M.narmed do order[i] = i end
	local swapped = true
	while swapped do
		swapped = false
		for i = 2, M.narmed do
			if M.armed[order[i]].endsAt < M.armed[order[i - 1]].endsAt then
				local tmp = order[i - 1]
				order[i - 1] = order[i]
				order[i] = tmp
				swapped = true
			end
		end
	end
	local rows = C.Get("bossmods.rows") or 6
	local shown = 0
	for i = 1, M.narmed do
		if shown < M.MAXBARS and shown < rows then
			local e = M.armed[order[i]]
			shown = shown + 1
			local row = M["row" .. shown]
			row:Show()
			row.name:SetText(e.name)
			-- icone du sort (option) : texture du jeu ou point d'interrogation
			if C.Get("bossmods.icons") ~= false and e.icon then
				row.icon:SetTexture(e.icon)
				row.icon:Show()
			else
				row.icon:Hide()
			end
			local left = mmax(0, e.endsAt - now)
			row.time:SetText(string.format("%.0f", left))
			local span, cr, cg, cb
			if e.phase == "active" then
				span = mmax(1, e.ev.dur or 3)
				cr, cg, cb = T.c.bad[1], T.c.bad[2], T.c.bad[3]
			elseif e.ev.warn then
				span = mmax(1, C.Get("bossmods.lead") or 10)
				cr, cg, cb = T.Accent()
			else
				span = mmax(1, C.Get("bossmods.lead") or 10)
				cr, cg, cb = T.c.text[1], T.c.text[2], T.c.text[3]
			end
			row.bar:SetStatusBarColor(cr, cg, cb, 0.8)
			row.bar:SetValue(mmin(1, left / span))
		end
	end
	local j
	for j = shown + 1, M.MAXBARS do
		M["row" .. j]:Hide()
	end
end

-- ---------------------------------------------------------------- flash d'ecran
function M.DoFlash()
	if M.flashUntil and GetTime() < M.flashUntil then return end
	if not M.flash then
		local f = CreateFrame("Frame", "ShikiUI_BossModsFlash", UIParent)
		f:SetFrameStrata("FULLSCREEN")
		f:SetAllPoints(f)
		f:EnableMouse(false)
		f.tex = f:CreateTexture(nil, "BACKGROUND")
		f.tex:SetTexture(T.tex.white)
		f.tex:SetAllPoints(f)
		M.flash = f
	end
	M.flashUntil = GetTime() + 0.6
	M.flash:Show()
	M.flash.tex:SetVertexColor(T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.18)
	if not M.flashTask then
		M.flashTask = SUI.Every(0.1, function()
			local f2 = M.flash
			if not f2 or not M.flashUntil then M.FlashStop() return end
			local left = M.flashUntil - GetTime()
			if left <= 0 then M.FlashStop() return end
			f2.tex:SetAlpha((SUI.Mod(left, 0.2) < 0.1) and 0.18 or 0.05)
		end, "bossmods.flash", true)
	end
end

function M.FlashStop()
	if M.flashTask then
		SUI.Cancel(M.flashTask)
		M.flashTask = nil
	end
	if M.flash then M.flash:Hide() end
	M.flashUntil = nil
end

-- ---------------------------------------------------------------- pull timer synchronise
M.PREFIX = "ShikiUIBW"

-- /sui pull [secs] : lance le compte a rebours d'engage, diffuse au raid via le canal addon.
-- Reserves au chef / assistant en raid (comme BigWigs), libre hors raid.
function M.Pull(secs)
	if not M.on then return end
	secs = tonumber(secs) or 10
	if secs < 3 then secs = 3 end
	if secs > 60 then secs = 60 end
	-- pont BigWigs : son pull (barre, annonces, synchro) remplace le notre ; sinon (BigWigs inactif, hors raid) on garde le notre
	if M.eff == "bridge" and B.PullBW(secs) then return end
	if GetNumRaidMembers() > 0 and not M.CanLead() then
		SUI.Print(L("msg.bossmods.nolead"))
		return
	end
	M.PullStart(secs, UnitName("player"))
	local chan = "RAID"
	if GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 then chan = "PARTY" end
	if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
		SendChatMessage(L("msg.bossmods.pullchat", secs), chan)
		if C.Get("bossmods.pull") and type(SendAddonMessage) == "function" then
			SendAddonMessage(M.PREFIX, "pull:" .. secs .. ":" .. tostring(UnitName("player")), "RAID")
		end
	end
end

function M.CanLead()
	if GetNumRaidMembers() > 0 then
		local off = getglobal("IsRaidOfficer")
		return IsRaidLeader() or (off and off()) or false
	end
	if GetNumPartyMembers() > 0 then return IsPartyLeader() or false end
	return true
end

-- Demarre la barre de pull localement (lanceur ou reception).
function M.PullStart(secs, from)
	M.testing = false
	M.cur = "pull"
	M.curLabel = from and (L("mod.bossmods.title") .. " (" .. from .. ")") or L("mod.bossmods.title")
	local now = GetTime()
	-- purge des barres de boss : le pull les remplace
	M.armed = {}
	M.narmed = 0
	M.combatAt = nil
	M.pullAnnounced = {}
	tinsert(M.armed, { name = "PULL", endsAt = now + secs, ev = { dur = secs, t = secs }, phase = "lead", pull = true })
	M.narmed = 1
	if M.win and M.win:IsShown() then M.Paint() end
	if not M.pullAnnounced then
		M.pullAnnounced = {}
	end
	M.EnsureTask()
	-- pont BigWigs, pull local (hors raid) : BigWigs ne montre rien, notre fenetre porte la barre le temps du decompte
	if M.eff == "bridge" then
		SUI.WhenSafe(function()
			if not M.on or M.eff ~= "bridge" or M.narmed == 0 then return end
			M.Build()
			M.win:Show()
			M.ApplySize()
			M.Paint()
		end)
	end
end

-- Decompte (5..1 puis GO) et expiration du pull. PullTick gere tout lui-meme : le pull survit au changement
-- de cible et Tick retourne tot sans boss vise, donc la purge generale ne verrait jamais la barre expiree.
function M.PullTick(now)
	local e = M.armed[1]
	if not e or not e.pull then return end
	if now >= e.endsAt then
		if not e.goDone then
			e.goDone = true
			if C.Get("bossmods.pull") then
				local chan = (GetNumRaidMembers() > 0) and "RAID_WARNING" or nil
				if chan then SendChatMessage(L("msg.bossmods.pullgo"), chan) else SUI.Print(L("msg.bossmods.pullgo")) end
				if C.Get("bossmods.sound") then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
			end
		end
		tremove(M.armed, 1)
		M.narmed = M.narmed - 1
		if M.win and M.win:IsShown() then M.Paint() end
		-- pont BigWigs : la minuterie et la fenetre n'existaient que pour ce pull local, on les rend
		if M.eff == "bridge" and M.narmed == 0 then
			if M.task then
				SUI.Cancel(M.task)
				M.task = nil
			end
			M.Close()
		end
		return
	end
	local left = e.endsAt - now
	local chan = (GetNumRaidMembers() > 0) and "RAID_WARNING" or nil
	local n
	for n = 1, 5 do
		if left <= n and not M.pullAnnounced[n] then
			M.pullAnnounced[n] = true
			if C.Get("bossmods.pull") then
				if chan then SendChatMessage(L("msg.bossmods.pullin", n), chan) else SUI.Print(L("msg.bossmods.pullin", n)) end
			end
		end
	end
end

-- Reception du canal addon : pull d'un autre officier.
function M.OnAddonComm(ev, a1, a2, a3, a4)
	if not M.on or type(a2) ~= "string" or a1 ~= M.PREFIX then return end
	local _, _, seen = sfind(a2, "^ann:(.+)$")
	if seen then
		M.annSeen[seen] = GetTime()
		return
	end
	local _, _, secs, who = sfind(a2, "^pull:(%d+):(.+)$")
	if not who or who == UnitName("player") then return end
	if M.pullIgnore and GetTime() < M.pullIgnore then return end
	M.PullStart(tonumber(secs) or 10, who)
end

-- Fin de combat : les barres de boss disparaissent (les pulls continuent).
function M.OnCombatEnd()
	if M.combatAt then
		M.combatAt = nil
		local i
		for i = M.narmed, 1, -1 do
			if not M.armed[i].pull then
				tremove(M.armed, i)
				M.narmed = M.narmed - 1
			end
		end
		if M.win and M.win:IsShown() then M.Paint() end
	end
end

-- ---------------------------------------------------------------- cycle de vie
-- DEUX moteurs, UN SEUL actif a la fois (M.eff) :
--   "own"    : le moteur de chronos ci-dessus (secours : BigWigs absent, ou reglage bossmods.mode = own) ;
--   "bridge" : BigWigs est la ; c'est LUI qui chronometre et annonce, ShikiUI l'habille et l'integre (pont B, plus bas). Le moteur de
--              secours est alors COUPE : ni barre en double, ni RAID_WARNING en double, ni minuterie, ni evenement ;
--   "none"   : reglage bossmods.mode = bigwigs sans BigWigs : rien ne tourne (l'etat est signale dans le menu).
M.eff = nil

function M.Effective()
	local mode = C.Get("bossmods.mode") or "auto"
	if mode == "own" then return "own" end
	if B.Present() then return "bridge" end
	if mode == "bigwigs" then return "none" end
	return "own"
end

function M.OwnStart()
	if M.ownOn then return end
	M.ownOn = true
	SUI.On("CHAT_MSG_ADDON", M.OnAddonComm)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombatStart)
	M.EnsureTask()
end

function M.OwnStop()
	M.ownOn = false
	M.testing = false
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	SUI.Off("CHAT_MSG_ADDON", M.OnAddonComm)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombatStart)
	M.FlashStop()
	M.MsgStop()
	M.armed = {}
	M.narmed = 0
	M.cur = nil
	M.curLabel = EMPTY
	M.combatAt = nil
	M.next = {}
	M.warns = {}
	M.Close()
end

-- Choisit le moteur (a l'activation, apres ADDON_LOADED / PLAYER_ENTERING_WORLD, au changement du reglage) et bascule proprement.
function M.Apply()
	if not M.on then return end
	local eff = M.Effective()
	if eff == M.eff then return end
	M.eff = eff
	if eff == "bridge" then
		M.OwnStop()
		B.Start()
	elseif eff == "own" then
		B.Stop()
		M.OwnStart()
	else
		B.Stop()
		M.OwnStop()
	end
end

-- Detection tardive : un BigWigs charge apres nous.
function M.OnAddon(ev, name)
	if name == "BigWigs" then
		M.Apply()
		M.Listen()
	end
end

-- Tous les addons sont charges a ce stade : dernier tour de detection, puis plus rien a attendre.
function M.OnWorld()
	M.Apply()
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnWorld)
end

-- Entree en combat : l'horloge des evenements est celle du COMBAT (pas celle de la cible).
function M.OnCombatStart()
	if not M.combatAt then M.combatAt = GetTime() end
end

function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("bossmods.", M.OnKey)
	end
	M.eff = nil
	M.Apply()
	M.Listen()
end

-- Attente d'un BigWigs charge apres nous (ordre alphabetique des addons, ou chargement a la demande) : seulement hors mode own, tant
-- que le pont n'est pas en place. Rappelee au changement de mode (own -> auto doit reprendre l'attente).
function M.Listen()
	if not M.on then return end
	if (C.Get("bossmods.mode") or "auto") ~= "own" and M.eff ~= "bridge" then
		SUI.On("ADDON_LOADED", M.OnAddon)
		SUI.On("PLAYER_ENTERING_WORLD", M.OnWorld)
	else
		SUI.Off("ADDON_LOADED", M.OnAddon)
		SUI.Off("PLAYER_ENTERING_WORLD", M.OnWorld)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("ADDON_LOADED", M.OnAddon)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnWorld)
	B.Stop()
	M.OwnStop()
	M.eff = nil
end

function M.OnKey(key)
	if key == nil or key == "bossmods.mode" then
		M.Apply()
		M.Listen()
	end
	if not M.on then return end
	if key ~= nil and not sfind(key, "^bossmods%.") then return end
	if M.eff == "bridge" then
		B.OnKey(key)
	elseif M.eff == "own" then
		if key == "bossmods.width" or key == "bossmods.rows" or key == nil then M.ApplySize() end
		if M.win and M.win:IsShown() then M.Paint() end
	end
end

-- ================================================================ PONT BIGWIGS
-- BigWigs (2.0.0 Turtle, Ace2 + CandyBar-2.2) fait deja le travail : chronos par boss, annonces, pull. Le pont ne le remplace pas, il
-- l'HABILLE et l'INTEGRE, sans jamais modifier un seul fichier de BigWigs : uniquement des enveloppes manuelles non destructives (on
-- appelle d'abord la fonction d'origine, puis la notre, sous pcall ; une enveloppe qu'un autre addon a recouverte devient transparente),
-- des lectures de tables publiques (AceLibrary("CandyBar-2.2").var.handlers : une table par barre, avec son cadre) et le Mover de ShikiUI.
-- NOMS DE BIGWIGS UTILISES (releves dans l'installation, jamais copies) :
--   globales BigWigs, BigWigsBars (frames.anchor / frames.emphasizeAnchor, StartCandyBar, SetupFrames, ResetAnchor, RestorePosition),
--   BigWigsMessages (frames.anchor, msgframe, ResetAnchor, RestorePosition), BigWigsPulltimer (BigWigs_PullCommand), BigWigsOptions
--   (OpenMenu) ; evenement Ace "BigWigs_Test" (BigWigsBars:TriggerEvent) ; bibliotheque CandyBar : handlers[nom] = { frame, time, endtime,
--   starttime, running, paused, gradient, color, width, height, texture, fontsize }, cadre = { statusbar, statusbarbg, icon, text,
--   timertext, spark } ; framepool (cadres liberes).
-- HABILLAGE d'une barre : texture et police du style (bossmods.bartex / .font / .fontsize), fond et lisere (T.c.inset / T.c.border),
--   icone rognee, etincelle facultative, hauteur / largeur facultatives, couleur : BigWigs / accent / accent puis alerte (T.Accent,
--   T.c.warn, T.c.bad). Applique a CHAQUE demarrage de barre (CandyBar reinitialise tout) par l'enveloppe de StartCandyBar, et filet de
--   securite : un balayage toutes les 0,5 s. Couper l'habillage (ou le pont) RESTAURE ce qui avait ete change (taille, texture, couleur,
--   degrade, polices, icone, etincelle).
-- ANCRES : BigWigsBarAnchor, BigWigsEmphasizedBarAnchor et BigWigsMessageAnchor sont enregistrees au Mover (poignees nommees, "Montrer tout",
--   remise a zero) ; le glisser de BigWigs est coupe pour qu'il n'y ait QU'UNE source de position ; son bouton de remise a zero declenche
--   la remise a zero du Mover.
-- COUT : nul si BigWigs est absent ou si le mode est "own" (B.Start n'est jamais appele : aucune enveloppe, aucune minuterie).
-- NON VERIFIE EN JEU : tout. Notamment que StartCandyBar est un champ propre du module (sinon l'enveloppe le cree), le rendu des liseres
--   (textures du cadre de barre sous ses sous-cadres), GetNormalTexture sur l'icone, MessageFrame:SetFont, RegisterForDrag() sans argument.
B.on = false
B.hooks = {}            -- enveloppes posees : { obj, field, orig, fn, own, live }
B.anchors = {}          -- [cle du Mover] = cadre BigWigs enregistre
B.gen = 1               -- generation de style : toute repeinture l'incremente (les barres se re-habillent)
B.task = nil
B.lib = nil             -- bibliotheque CandyBar
B.late = false          -- des liseres n'ont pu etre crees (combat) : a refaire hors combat
B.msgStyled = false
B.styled = 0            -- compteur de diagnostic : barres habillees
B.defs = {
	{ key = "bossmods.bwbars", mod = "BigWigsBars", pick = "anchor", label = "mod.bossmods.bw.anchor.bars", point = "TOP", x = 0, y = -120 },
	{ key = "bossmods.bwemph", mod = "BigWigsBars", pick = "emphasizeAnchor", label = "mod.bossmods.bw.anchor.emph", point = "TOP", x = 0, y = -260 },
	{ key = "bossmods.bwmsg", mod = "BigWigsMessages", pick = "anchor", label = "mod.bossmods.bw.anchor.msg", point = "CENTER", x = 0, y = 100 },
	-- grosse icone d'avertissement (plugin WarningSign : BigWigs_ShowWarningSign, 113 modules de boss l'utilisent) : sa position
	-- par defaut est en pixels absolus (800, 645), souvent hors de vue : on impose le centre (fixed) ; plugin absent = ignore (optional)
	{ key = "bossmods.bwsign", mod = "BigWigsWarningSign", pick = "anchor", label = "mod.bossmods.bw.anchor.sign", point = "CENTER", x = 0, y = 100, fixed = true, optional = true },
}
B.FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"   -- texture du jeu, de repli si celle de BigWigs est absente
B.signHooked = false
B.signSeen = 0         -- compteur de diagnostic : signes remis a l'ecran

local function gt(name)
	local v = getglobal(name)
	if type(v) == "table" then return v end
	return nil
end

function B.Opt(k)
	return C.Get("bossmods.bw." .. k)
end

-- ---------------------------------------------------------------- detection
function B.Present()
	if gt("BigWigs") then return true end
	local f = getglobal("IsAddOnLoaded")
	if type(f) == "function" then
		local ok, r = pcall(f, "BigWigs")
		return (ok and r) and true or false
	end
	return false
end

-- La bibliotheque CandyBar de BigWigs (ou nil).
function B.Lib()
	local al = getglobal("AceLibrary")
	if al == nil then return nil end
	local ok, lib = pcall(al, "CandyBar-2.2")
	if ok and type(lib) == "table" and type(lib.var) == "table" and type(lib.var.handlers) == "table" then return lib end
	return nil
end

-- Version, modules de boss charges / actifs, zone (lecture seule, sous pcall : l'API de BigWigs peut changer).
function B.Info()
	local bw = gt("BigWigs")
	local ver, nmods, nact = "?", 0, 0
	if bw then
		if type(bw.version) == "string" then
			local v = sgsub(bw.version, "|c%x%x%x%x%x%x%x%x", EMPTY)
			v = sgsub(v, "|r", EMPTY)
			ver = v
		end
		if type(bw.IterateModules) == "function" then
			pcall(function()
				local name, mod
				for name, mod in bw:IterateModules() do
					if type(mod) == "table" and type(mod.IsBossModule) == "function" and mod:IsBossModule() then
						nmods = nmods + 1
						if type(bw.IsModuleActive) == "function" and bw:IsModuleActive(mod) then nact = nact + 1 end
					end
				end
			end)
		end
	end
	local zone = EMPTY
	local zf = getglobal("GetRealZoneText")
	if type(zf) == "function" then
		local ok, z = pcall(zf)
		if ok and type(z) == "string" then zone = z end
	end
	return ver, nmods, nact, zone
end

-- ---------------------------------------------------------------- enveloppes non destructives
-- post(a, b, c, d, resultat) est appelee APRES la fonction d'origine (sous pcall). Retourne vrai si l'enveloppe est en place.
function B.Wrap(obj, field, post)
	if type(obj) ~= "table" or type(post) ~= "function" then return false end
	local orig = obj[field]
	if type(orig) ~= "function" then return false end
	local i
	for i = 1, getn(B.hooks) do
		local h = B.hooks[i]
		if h.obj == obj and h.field == field and h.live and obj[field] == h.fn then return true end
	end
	local rec = { obj = obj, field = field, orig = orig, own = (rawget(obj, field) ~= nil), live = true }
	rec.fn = function(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10)
		local r1, r2, r3 = orig(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10)
		if rec.live and B.on then
			local ok, err = pcall(post, p1, p2, p3, p4, r1)
			if not ok then SUI.Report("bossmods bw " .. field, err) end
		end
		return r1, r2, r3
	end
	obj[field] = rec.fn
	tinsert(B.hooks, rec)
	return true
end

-- Retire nos enveloppes. Si un autre addon est passe par-dessus, la notre reste dans la chaine mais ne fait plus rien.
function B.UnhookAll()
	B.signHooked = false
	local i
	for i = getn(B.hooks), 1, -1 do
		local rec = B.hooks[i]
		rec.live = false
		if rec.obj[rec.field] == rec.fn then
			if rec.own then rec.obj[rec.field] = rec.orig else rec.obj[rec.field] = nil end
		end
		tremove(B.hooks, i)
	end
end

function B.HookAll()
	local bars, msgs = gt("BigWigsBars"), gt("BigWigsMessages")
	B.Wrap(bars, "StartCandyBar", B.PostStart)
	B.Wrap(bars, "SetupFrames", B.PostSetup)
	B.Wrap(bars, "ResetAnchor", B.PostReset)
	B.Wrap(bars, "RestorePosition", B.PostRestore)
	B.Wrap(msgs, "ResetAnchor", B.PostReset)
	B.Wrap(msgs, "RestorePosition", B.PostRestore)
end

-- Plugin WarningSign : enveloppes posees des qu'il existe (il peut se charger apres le pont).
function B.HookSign()
	if B.signHooked then return end
	local m = gt("BigWigsWarningSign")
	if not m then return end
	local a = B.Wrap(m, "BigWigs_ShowWarningSign", B.SignCheck)
	local b = B.Wrap(m, "ResetPosition", B.PostReset)
	if a and b then B.signHooked = true end
end

-- Le signe est-il visible ? Au premier plan (option) et dans l'ecran ; sinon l'ancre revient au centre.
function B.SignCheck()
	local m = gt("BigWigsWarningSign")
	local fr = m and m.frames
	local sg = type(fr) == "table" and fr.sign or nil
	if type(sg) ~= "table" or type(sg.IsShown) ~= "function" or not sg:IsShown() then return end
	if B.Opt("signtop") ~= false and sg:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then pcall(sg.SetFrameStrata, sg, "FULLSCREEN_DIALOG") end
	local l, r, t, b = sg:GetLeft(), sg:GetRight(), sg:GetTop(), sg:GetBottom()
	if not l or not r or not t or not b then return end
	local k = sg:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	if r * k > 0 and l * k < W and t * k > 0 and b * k < H then return end
	B.signSeen = B.signSeen + 1
	if B.anchors["bossmods.bwsign"] and SUI.Mover and SUI.Mover.Reset then
		SUI.Mover.Reset("bossmods.bwsign")
	elseif type(fr.anchor) == "table" then
		fr.anchor:ClearAllPoints()
		fr.anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	end
end

function B.PostStart(self, name)
	if type(name) == "string" then B.StyleName(name) end
end

function B.PostSetup()
	B.allAttached = false
	B.AttachAll()
end

-- Bouton "Reset position" de BigWigs : remise a zero du Mover pour les ancres de ce module.
function B.PostReset(self, which)
	-- BigWigs appelle aussi ResetAnchor("normal" / "emphasize") DE L'INTERIEUR de SetupFrames quand il n'a pas de position
	-- enregistree (toujours le cas, le glisser etant coupe) : ce n'est pas le bouton, la position du Mover doit survivre.
	if which == "normal" or which == "emphasize" then return end
	local i
	for i = 1, getn(B.defs) do
		local def = B.defs[i]
		if B.anchors[def.key] and gt(def.mod) == self and SUI.Mover and SUI.Mover.Reset then SUI.Mover.Reset(def.key) end
	end
end

-- BigWigs repose sa position (a la creation, au chargement) : la position de ShikiUI reprend la main.
function B.PostRestore(self)
	local i
	for i = 1, getn(B.defs) do
		local def = B.defs[i]
		if B.anchors[def.key] and gt(def.mod) == self then SUI.Layout.Apply(def.key) end
	end
end

-- ---------------------------------------------------------------- ancres (Mover)
function B.AnchorOf(def)
	local m = gt(def.mod)
	if not m or type(m.frames) ~= "table" then return nil end
	local f = m.frames[def.pick]
	if type(f) == "table" and type(f.GetPoint) == "function" and type(f.SetPoint) == "function" then return f end
	return nil
end

-- Position actuelle de BigWigs, reprise comme position par defaut (premiere fois) : point, x, y relatifs a UIParent.
function B.DefaultPoint(f, def)
	if def.fixed then return def.point, def.x, def.y end
	local ok, p, rel, rp, x, y = pcall(f.GetPoint, f, 1)
	if ok and p and type(x) == "number" and type(y) == "number" and (rel == nil or rel == UIParent) then
		if rp == nil or rp == p then return p, x, y end
		if p == "TOPLEFT" and rp == "BOTTOMLEFT" then return p, x, y - (UIParent:GetHeight() or 0) end
	end
	return def.point, def.x, def.y
end

function B.Attach(def)
	local f = B.AnchorOf(def)
	if not f then return false end
	if B.anchors[def.key] == f then return true end
	if B.anchors[def.key] then B.Forget(def) end
	if not SUI.Mover or not SUI.Mover.Register then return false end
	local p, x, y = B.DefaultPoint(f, def)
	local ok = SUI.Mover.Register(def.key, f, { label = def.label, point = p, x = x, y = y, scale = false, always = true })
	if ok then
		B.anchors[def.key] = f
		pcall(f.RegisterForDrag, f)       -- sans argument : plus de glisser BigWigs (une seule source de position : le Mover)
	end
	return ok
end

-- Le plugin WarningSign ne cree ses cadres qu'au premier signe : on les fait creer (hors combat) pour que l'ancre soit deplacable
-- des le depart. Sous pcall : l'API de BigWigs peut changer.
function B.EnsureSign()
	local m = gt("BigWigsWarningSign")
	if not m then return end
	if type(m.frames) == "table" and m.frames.anchor then return end
	if type(m.db) ~= "table" or type(m.SetupFrames) ~= "function" or SUI.InCombat() then return end
	pcall(m.SetupFrames, m)
end

function B.AttachAll()
	local want = B.Opt("anchors") ~= false
	local all = true
	local i
	for i = 1, getn(B.defs) do
		local def = B.defs[i]
		if def.optional and not gt(def.mod) then
			-- plugin absent : rien a accrocher, et pas de reessai a chaque balayage
		elseif want then
			if def.optional then B.EnsureSign() end
			if not B.Attach(def) then all = false end
		elseif B.anchors[def.key] then
			B.Forget(def)
		end
	end
	-- tout est accroche (ou l'option est coupee) : le balayage n'y revient plus tant que BigWigs ne recree pas ses cadres (PostSetup)
	B.allAttached = all
end

-- Rend l'ancre a BigWigs (glisser, position, echelle). Le Mover n'a pas de "desenregistrement" : on retire ses entrees publiques.
function B.Forget(def)
	local f = B.anchors[def.key]
	if not f then return end
	B.anchors[def.key] = nil
	local Mv, Ly = SUI.Mover, SUI.Layout
	if Mv and type(Mv.items) == "table" then
		local rec = Mv.items[def.key]
		if rec and rec.handle then pcall(rec.handle.Hide, rec.handle) end
		Mv.items[def.key] = nil
		if type(Mv.order) == "table" then
			local k
			for k = getn(Mv.order), 1, -1 do
				if Mv.order[k] == def.key then tremove(Mv.order, k) end
			end
		end
	end
	if Ly and type(Ly.items) == "table" then Ly.items[def.key] = nil end
	f.layoutKey = nil
	pcall(f.RegisterForDrag, f, "LeftButton")
	pcall(f.SetScale, f, 1)
	local m = gt(def.mod)
	if m and type(m.RestorePosition) == "function" then pcall(m.RestorePosition, m) end
end

-- ---------------------------------------------------------------- habillage des barres
function B.SetFont(fs, path, size, flags)
	if type(fs) ~= "table" or type(fs.SetFont) ~= "function" then return end
	local ok, r = pcall(fs.SetFont, fs, path, size, flags)
	if not ok or r == false then pcall(fs.SetFont, fs, T.FONTS.arial, size, flags) end
end

-- Epaisseur du lisere selon le style (0 = aucun).
function B.EdgePx()
	local e = T.edge
	if not e or not e.file then return 0 end
	if e.size >= 2 and e.size <= 3 then return 2 end
	return 1
end

function B.HideDeco(f)
	local d = type(f) == "table" and f.suiDeco or nil
	if d then
		d.bar:Hide()
		d.icon:Hide()
	end
end

-- Lisere du corps de la barre et de l'icone : de simples textures posees SOUS les sous-cadres de la barre (aucun cadre cree).
function B.Deco(f, hasIcon)
	local d = f.suiDeco
	if not d then
		if SUI.InCombat() then
			B.late = true
			return
		end
		d = {}
		d.bar = f:CreateTexture(nil, "BACKGROUND")
		d.bar:SetTexture(T.tex.white)
		d.icon = f:CreateTexture(nil, "BACKGROUND")
		d.icon:SetTexture(T.tex.white)
		d.px = -1
		f.suiDeco = d
	end
	local px = B.EdgePx()
	if px <= 0 then
		d.bar:Hide()
		d.icon:Hide()
		return
	end
	if d.px ~= px then
		d.px = px
		d.bar:ClearAllPoints()
		d.bar:SetPoint("TOPLEFT", f.statusbar, "TOPLEFT", -px, px)
		d.bar:SetPoint("BOTTOMRIGHT", f.statusbar, "BOTTOMRIGHT", px, -px)
		d.icon:ClearAllPoints()
		d.icon:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -px, px)
		d.icon:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", px, -px)
	end
	local c = T.c.border
	d.bar:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	d.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	d.bar:Show()
	if hasIcon == false then d.icon:Hide() else d.icon:Show() end   -- pas d'icone : pas de cadre vide a cote de la barre
end

-- Couleur "accent" ou "alerte" d'une barre (modes accent / urgent).
function B.Tint(h, f, mode)
	local r, g, b = T.Accent()
	if mode == "urgent" and not h.paused and h.running then
		local left = (h.endtime or 0) - GetTime()
		if left <= 5 then
			r, g, b = T.c.bad[1], T.c.bad[2], T.c.bad[3]
		elseif left <= 10 then
			r, g, b = T.c.warn[1], T.c.warn[2], T.c.warn[3]
		end
	end
	f.statusbar:SetStatusBarColor(r, g, b, 0.95)
end

-- Icone d'une barre : CandyBar la pose par SetNormalTexture au demarrage ; si elle manque (texture non lue, cadre recycle sans icone),
-- on la repose depuis le chemin memorise (h.icon), puis texture de repli. Retourne vrai si la barre a une icone a entourer.
function B.FixIcon(f, h)
	local ic = f.icon
	local want = h.icon
	if type(ic) ~= "table" or type(want) ~= "string" or want == EMPTY then return false end
	if type(ic.IsShown) == "function" and not ic:IsShown() then pcall(ic.Show, ic) end
	if type(ic.GetNormalTexture) ~= "function" or type(ic.SetNormalTexture) ~= "function" then return true end
	local function cur()
		local nt = ic:GetNormalTexture()
		if type(nt) == "table" and type(nt.GetTexture) == "function" then
			local tx = nt:GetTexture()
			if type(tx) == "string" and tx ~= EMPTY then return tx end
		end
		return nil
	end
	if not cur() then
		pcall(ic.SetNormalTexture, ic, want)
		if not cur() then
			pcall(ic.SetNormalTexture, ic, B.FALLBACK_ICON)
			B.iconFallback = (B.iconFallback or 0) + 1
		end
	end
	return true
end

-- Habille UNE barre. Memorise ce qu'il faut pour la restaurer (h.suiOrig).
function B.StyleBar(name, h)
	local f = h.frame
	local lib = B.lib
	if not lib or type(f) ~= "table" or type(f.statusbar) ~= "table" or type(f.statusbarbg) ~= "table" or type(f.text) ~= "table" or type(f.timertext) ~= "table" then return end
	local df = lib.var.defaults or {}
	local o = h.suiOrig
	if not o then
		o = { w = h.width, ht = h.height, grad = h.gradient, tex = h.texture, fs = h.fontsize }
		if type(f.text.GetFont) == "function" then
			local okf, p1, p2, p3 = pcall(f.text.GetFont, f.text)
			if okf and type(p1) == "string" and type(p2) == "number" then o.tf, o.tfs, o.tff = p1, p2, p3 end
		end
		h.suiOrig = o
	end
	-- taille (0 = celle de BigWigs)
	local cw, ch = B.Opt("width"), B.Opt("height")
	local nw = (type(cw) == "number" and cw > 0) and mmax(cw, 80) or o.w
	local nh = (type(ch) == "number" and ch > 0) and mmax(ch, 8) or o.ht
	if nh ~= h.height then
		pcall(lib.SetHeight, lib, name, nh or df.height or 22)
		h.height = nh
	end
	if nw ~= h.width then
		pcall(lib.SetWidth, lib, name, nw or df.width or 200)
		h.width = nw
	end
	-- texture, fond
	local tex = T.BarTexture("bossmods")
	f.statusbar:SetStatusBarTexture(tex)
	f.statusbarbg:SetStatusBarTexture(tex)
	h.texture = tex
	local ic = T.c.inset
	f.statusbarbg:SetStatusBarColor(ic[1], ic[2], ic[3], (ic[4] or 1) * (T.alpha or 1))
	-- couleur
	local mode = B.Opt("color") or "keep"
	if mode == "accent" or mode == "urgent" then
		h.gradient = nil
		B.Tint(h, f, mode)
	else
		if o.grad ~= nil then h.gradient = o.grad end
		local c = h.color or df.color
		if not h.gradient and type(c) == "table" then f.statusbar:SetStatusBarColor(c[1], c[2], c[3], c[4]) end
	end
	-- polices
	local path, px = T.Font("bossmods")
	local size = px or o.fs or df.fontsize or 11
	local eh = h.height or df.height or 22
	if size > eh - 3 then size = mmax(7, eh - 3) end
	local flags = T.outline or EMPTY
	B.SetFont(f.text, path, size, flags)
	B.SetFont(f.timertext, path, size, flags)
	local hasIcon = B.FixIcon(f, h)
	if type(f.icon) == "table" then
		if type(f.icon.text) == "table" then B.SetFont(f.icon.text, path, size * 1.5, "OUTLINE") end
		if type(f.icon.GetNormalTexture) == "function" then
			local nt = f.icon:GetNormalTexture()
			if nt then nt:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
		end
	end
	if type(f.spark) == "table" then
		if B.Opt("spark") then f.spark:Show() else f.spark:Hide() end
	end
	B.Deco(f, hasIcon)
	h.suiStamp = h.starttime or 0
	h.suiGen = B.gen
	B.styled = B.styled + 1
end

-- Rend a une barre ce que BigWigs / CandyBar lui avait donne.
function B.Unstyle(name, h)
	local o = h.suiOrig
	local f = h.frame
	h.suiOrig, h.suiStamp, h.suiGen = nil, nil, nil
	if not o or type(f) ~= "table" or not B.lib then return end
	local lib = B.lib
	local df = lib.var.defaults or {}
	if h.height ~= o.ht then
		pcall(lib.SetHeight, lib, name, o.ht or df.height or 22)
		h.height = o.ht
	end
	if h.width ~= o.w then
		pcall(lib.SetWidth, lib, name, o.w or df.width or 200)
		h.width = o.w
	end
	if type(f.statusbar) == "table" and type(f.statusbarbg) == "table" then
		local tex = o.tex or df.texture
		if type(tex) == "string" then
			f.statusbar:SetStatusBarTexture(tex)
			f.statusbarbg:SetStatusBarTexture(tex)
		end
		h.texture = o.tex
		h.gradient = o.grad
		local c = h.color or df.color
		if not h.gradient and type(c) == "table" then f.statusbar:SetStatusBarColor(c[1], c[2], c[3], c[4]) end
		local bc = h.bgcolor or df.bgcolor
		if type(bc) == "table" then f.statusbarbg:SetStatusBarColor(bc[1], bc[2], bc[3], bc[4]) end
	end
	local path, size, flags = o.tf, o.tfs, o.tff
	if not path then
		local gf = getglobal("GameFontHighlight")
		if gf ~= nil and type(gf.GetFont) == "function" then
			local ok, p, s2, f2 = pcall(gf.GetFont, gf)
			if ok and type(p) == "string" then path, size, flags = p, s2, f2 end
		end
	end
	path = path or T.font
	size = size or o.fs or df.fontsize or 11
	if type(f.text) == "table" then B.SetFont(f.text, path, size, flags or EMPTY) end
	if type(f.timertext) == "table" then B.SetFont(f.timertext, path, size, flags or EMPTY) end
	if type(f.icon) == "table" then
		if type(f.icon.text) == "table" then B.SetFont(f.icon.text, path, size * 1.5, "OUTLINE") end
		if type(f.icon.GetNormalTexture) == "function" then
			local nt = f.icon:GetNormalTexture()
			if nt then nt:SetTexCoord(0, 1, 0, 1) end
		end
	end
	if type(f.spark) == "table" then f.spark:Show() end
	B.HideDeco(f)
end

function B.StyleName(name)
	local lib = B.lib
	local h = lib and lib.var.handlers[name]
	if type(h) == "table" then B.StyleOne(name, h) end
end

function B.StyleOne(name, h)
	if B.Opt("skin") == false then
		if h.suiOrig then B.Unstyle(name, h) end
		return
	end
	if h.suiStamp ~= (h.starttime or 0) or h.suiGen ~= B.gen or not h.suiOrig then
		B.StyleBar(name, h)
	else
		-- BigWigs recolore ses barres en route (emphase) : accent / urgence se reposent a chaque balayage
		local mode = B.Opt("color") or "keep"
		if (mode == "urgent" or mode == "accent") and type(h.frame) == "table" and h.frame.statusbar then
			h.gradient = nil
			B.Tint(h, h.frame, mode)
		end
	end
end

function B.UnstyleAll()
	local lib = B.lib
	if not lib then return end
	local name, h
	for name, h in pairs(lib.var.handlers) do
		if type(h) == "table" and h.suiOrig then B.Unstyle(name, h) end
	end
	local pool = lib.var.framepool
	if type(pool) == "table" then
		local i
		for i = 1, getn(pool) do B.HideDeco(pool[i]) end
	end
end

-- ---------------------------------------------------------------- messages
function B.StyleMsg()
	local m = gt("BigWigsMessages")
	local mf = m and m.msgframe
	if type(mf) ~= "table" or type(mf.SetFont) ~= "function" then return end
	if B.Opt("msgskin") ~= false then
		local path, px = T.Font("bossmods")
		local size = B.Opt("msgsize")
		if type(size) ~= "number" or size <= 0 then size = px or floor(20 * (T.fontScale or 1) + 0.5) end
		if not B.msgStyled and type(mf.GetFont) == "function" then
			local okf, p1, p2, p3 = pcall(mf.GetFont, mf)
			if okf and type(p1) == "string" and type(p2) == "number" then B.msgOrig = { p1, p2, p3 } end
		end
		B.SetFont(mf, path, size, "OUTLINE")
		B.msgStyled = true
	elseif B.msgStyled then
		B.RestoreMsg()
	end
end

function B.RestoreMsg()
	if not B.msgStyled then return end
	B.msgStyled = false
	local m = gt("BigWigsMessages")
	local mf = m and m.msgframe
	if type(mf) ~= "table" then return end
	local o = B.msgOrig
	B.msgOrig = nil
	if o then
		B.SetFont(mf, o[1], o[2], o[3] or EMPTY)
		return
	end
	local fo = getglobal("GameFontNormalLarge")
	if fo ~= nil and type(mf.SetFontObject) == "function" then pcall(mf.SetFontObject, mf, fo) end
end

-- ---------------------------------------------------------------- balayage et cycle de vie du pont
-- Filet de securite (0,5 s) : ancres creees plus tard (BigWigs ne cree ses barres qu'en groupe), barres qui ont perdu leur habillage,
-- lisere a refaire hors combat, couleur d'alerte qui suit le temps restant.
function B.Sweep()
	if not B.on then return end
	-- le plugin WarningSign peut se charger apres le pont : on l'accroche des qu'il apparait
	if not B.signHooked then
		B.HookSign()
		if B.signHooked then B.allAttached = false end
	end
	if not B.allAttached then B.AttachAll() end
	B.SignCheck()
	-- le cadre de messages de BigWigs n'est cree qu'a son premier message : habillage des qu'il existe
	if not B.msgStyled and B.Opt("msgskin") ~= false then B.StyleMsg() end
	if not B.lib then B.lib = B.Lib() end
	local lib = B.lib
	if not lib then return end
	if B.late and not SUI.InCombat() then
		B.late = false
		B.gen = B.gen + 1
	end
	local name, h
	for name, h in pairs(lib.var.handlers) do
		if type(h) == "table" and type(h.frame) == "table" then
			local ok, err = pcall(B.StyleOne, name, h)
			if not ok then SUI.Report("bossmods bw barre", err) end
		end
	end
end

function B.Restyle()
	if not B.on then return end
	B.allAttached = false
	B.gen = B.gen + 1
	B.StyleMsg()
	B.Sweep()
end

function B.OnKey(key)
	if not B.on then return end
	if key == nil or sfind(key, "^bossmods%.bw%.") or sfind(key, "^bossmods%.bartex$") or sfind(key, "^bossmods%.font") then
		if B.Opt("skin") == false then B.UnstyleAll() end
		B.Restyle()
	end
end

function B.Start()
	if B.on then return end
	B.on = true
	B.allAttached = false
	B.lib = B.Lib()
	B.HookAll()
	if not B.accentHooked then
		B.accentHooked = true
		T.OnAccent(B.Restyle)
	end
	B.StyleMsg()
	B.Sweep()
	B.task = SUI.Every(0.5, B.Sweep, "bossmods.bw", true)
end

function B.Stop()
	if not B.on then return end
	B.on = false
	if B.task then
		SUI.Cancel(B.task)
		B.task = nil
	end
	B.UnhookAll()
	B.UnstyleAll()
	B.RestoreMsg()
	local i
	for i = 1, getn(B.defs) do B.Forget(B.defs[i]) end
	B.lib = nil
end

-- ---------------------------------------------------------------- integration : options, test, pull
function B.OpenOptions(anchor)
	local o = gt("BigWigsOptions")
	if o and type(o.OpenMenu) == "function" then
		local ok = pcall(o.OpenMenu, o, anchor or UIParent)
		if ok then return true end
	end
	local open = getglobal("ChatFrame_OpenChat")
	if type(open) == "function" and pcall(open, "/bw ") then return true end
	SUI.Print(L("msg.bossmods.bw.noapi"))
	return false
end

-- Montre 3 s la grosse icone d'avertissement (comme un boss) : permet de verifier qu'on la voit et ou elle est.
function B.TestSign()
	local m = gt("BigWigsWarningSign")
	if not m or type(m.BigWigs_ShowWarningSign) ~= "function" then return false end
	return pcall(m.BigWigs_ShowWarningSign, m, "Interface\\Icons\\Spell_Fire_Fireball02", 3, true, "TEST") and true or false
end

function B.Test()
	local m = gt("BigWigsBars") or gt("BigWigs")
	B.TestSign()
	if m and type(m.TriggerEvent) == "function" and pcall(m.TriggerEvent, m, "BigWigs_Test") then return true end
	SUI.Print(L("msg.bossmods.bw.noapi"))
	return false
end

-- Pull de BigWigs : en raid, par le chef ou un assistant (comme BigWigs). Retourne vrai si BigWigs s'en est charge ; faux : notre pull local.
function B.PullBW(secs)
	if GetNumRaidMembers() == 0 then return false end
	local pt, bw = gt("BigWigsPulltimer"), gt("BigWigs")
	if not pt or type(pt.BigWigs_PullCommand) ~= "function" then return false end
	if bw and type(bw.IsActive) == "function" then
		local ok, act = pcall(bw.IsActive, bw)
		if ok and not act then return false end
	end
	if not M.CanLead() then
		SUI.Print(L("msg.bossmods.nolead"))
		return true
	end
	local ok, err = pcall(pt.BigWigs_PullCommand, pt, secs)
	if not ok then
		SUI.Report("bossmods bw pull", err)
		return false
	end
	return true
end

function B.StatusText()
	if M.eff == "bridge" then
		local ver, nmods, nact, zone = B.Info()
		return L("mod.bossmods.bw.status", ver, nmods, nact, zone), T.c.good
	elseif M.eff == "none" then
		return L("mod.bossmods.bw.none"), T.c.warn
	end
	if (C.Get("bossmods.mode") or "auto") == "own" then return L("mod.bossmods.bw.own"), T.c.dim end
	return L("mod.bossmods.bw.absent"), T.c.dim
end

-- ---------------------------------------------------------------- page du menu (etat de BigWigs + boutons)
function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "bossmods" and Mn.GridBtn then
			local txt, col = B.StatusText()
			Mn.Section(L("mod.bossmods.bw.sec"), "")
			Mn.Para(txt, 34, col)
			if M.eff == "bridge" then
				Mn.GridBtn(L("mod.bossmods.bw.open"), 3, 208, 24, function() B.OpenOptions() end, false)
				Mn.GridBtn(L("mod.bossmods.bw.test"), 3, 208, 24, function() B.Test() end, false)
			end
		end
		orig()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("bossmods", 70)

local function opt(key, typ, order, def, extra)
	local o = { key = "bossmods." .. key, type = typ, cat = "bossmods", label = "opt.bossmods." .. key, tip = "tip.bossmods." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

local function chanText(o, v) return L("choice.bossmods.channel." .. v) end
local function modeText(o, v) return L("choice.bossmods.mode." .. v) end
local function colorText(o, v) return L("choice.bossmods.bw.color." .. v) end

local OPTIONS = {
	opt("mode", "choice", 5, "auto", { choices = { "auto", "bigwigs", "own" }, choiceText = modeText }),
	opt("lead", "number", 10, 10, { min = 0, max = 30, step = 1 }),
	opt("channel", "choice", 20, "self", { choices = { "self", "raid", "party" }, choiceText = chanText }),
	opt("sound", "bool", 30, true),
	opt("width", "number", 40, 220, { min = 120, max = 400, step = 10 }),
	opt("rows", "number", 50, 6, { min = 1, max = 8, step = 1 }),
	opt("showmsg", "bool", 60, true),
	opt("icons", "bool", 70, true),
	opt("incoming", "bool", 80, true),
	opt("active", "bool", 90, true),
	opt("pull", "bool", 100, true),
	opt("flash", "bool", 110, false),
	opt("bw.skin", "bool", 200, true),
	opt("bw.color", "choice", 210, "keep", { choices = { "keep", "accent", "urgent" }, choiceText = colorText }),
	opt("bw.width", "number", 220, 0, { min = 0, max = 400, step = 10 }),
	opt("bw.height", "number", 230, 0, { min = 0, max = 40, step = 1 }),
	opt("bw.spark", "bool", 240, true),
	opt("bw.anchors", "bool", 250, true),
	opt("bw.signtop", "bool", 255, true),
	opt("bw.msgskin", "bool", 260, true),
	opt("bw.msgsize", "number", 270, 0, { min = 0, max = 40, step = 1 }),
}
if SUI.Look then
	local lo = SUI.Look.Options("bossmods", { bar = true, font = true, cat = "bossmods", order = 820 })
	local i
	for i = 1, getn(lo) do tinsert(OPTIONS, lo[i]) end
end

SUI.RegisterModule("bossmods", {
	default = true,
	cost = "medium",
	options = OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Les integrations connues (menu, /sui status) listent BigWigs quand le pont tourne.
if SUI.Api and SUI.Api.Integrations and not M.apiWrapped then
	M.apiWrapped = true
	local origInt = SUI.Api.Integrations
	SUI.Api.Integrations = function()
		local t = origInt()
		if M.on and M.eff == "bridge" then tinsert(t, "BigWigs") end
		return t
	end
end

M.HookMenu()

-- ---------------------------------------------------------------- apercu du menu (barres habillees, sans toucher aux vraies barres)
local PVN = 3
local function pvBuild(parent, w, h)
	local P = SUI.Preview
	local root = CreateFrame("Frame", nil, parent)
	local st = { rows = {} }
	root.st = st
	local i
	for i = 1, PVN do
		local r = CreateFrame("Frame", nil, root)
		r.edge, r.bg, r.fill, r.spark = P.NewTex(r, "BACKGROUND"), P.NewTex(r, "BACKGROUND"), P.NewTex(r, "ARTWORK"), P.NewTex(r, "OVERLAY")
		r.nm = T.Text(r, 10, T.c.text, "LEFT", true)
		r.tm = T.Text(r, 10, T.c.text, "RIGHT", true)
		r.zone = P.Zone(root, "bar" .. i)
		st.rows[i] = r
	end
	st.cap = T.Text(root, 9, T.c.dim, "LEFT", true)
	st.zmsg = P.Zone(root, "msg")
	st.msg = T.Text(root, 14, T.c.text, "CENTER", true)
	return root
end

local PVF = { 0.78, 0.5, 0.22 }
local function pvUpdate(root, w, h)
	local P = SUI.Preview
	local st = root.st
	local bw = C.Get("bossmods.bw.width")
	if type(bw) ~= "number" or bw <= 0 then bw = 200 end
	local bh = C.Get("bossmods.bw.height")
	if type(bh) ~= "number" or bh <= 0 then bh = 16 end
	local sc = (w - 16) / mmax(bw, 120)
	if sc > 1.4 then sc = 1.4 end
	if sc < 0.3 then sc = 0.3 end
	local rw, rh = floor(bw * sc + 0.5), floor(bh * sc + 0.5)
	if rh < 8 then rh = 8 end
	local mode = C.Get("bossmods.bw.color") or "keep"
	local spark = C.Get("bossmods.bw.spark") ~= false
	local fsz = mmin(rh - 3, 11)
	local y = 6
	local i
	for i = 1, PVN do
		local r = st.rows[i]
		P.Place(r, root, 8, y, rw, rh)
		P.Fill(r.edge, T.c.border, 1)
		P.Box(r.edge, r, 0, 0, rw, rh)
		P.Fill(r.bg, T.c.inset, 1)
		P.Box(r.bg, r, 1, 1, rw - 2, rh - 2)
		local cr, cg, cb
		if mode == "keep" then
			cr, cg, cb = T.c.warn[1], T.c.warn[2], T.c.warn[3]
			if i == 3 then cr, cg, cb = T.c.bad[1], T.c.bad[2], T.c.bad[3] end
			if i == 1 then cr, cg, cb = T.c.good[1], T.c.good[2], T.c.good[3] end
		elseif mode == "urgent" and i >= 2 then
			local tok = (i == 3) and T.c.bad or T.c.warn
			cr, cg, cb = tok[1], tok[2], tok[3]
		else
			cr, cg, cb = T.Accent()
		end
		r.fill:SetVertexColor(cr, cg, cb, 0.95)
		P.Box(r.fill, r, 1, 1, (rw - 2) * PVF[i], rh - 2)
		if spark then
			P.Fill(r.spark, T.c.text, 0.9)
			P.Box(r.spark, r, 1 + (rw - 2) * PVF[i] - 1, 0, 3, rh)
		else
			r.spark:Hide()
		end
		P.Font(r.nm, fsz)
		r.nm:SetText(L("mod.bossmods.bw.pv." .. i))
		r.nm:ClearAllPoints()
		r.nm:SetPoint("LEFT", r, "LEFT", 4, 0)
		r.nm:SetWidth(rw * 0.65)
		r.nm:Show()
		P.Font(r.tm, fsz)
		r.tm:SetText(tostring(floor(30 * PVF[i])))
		r.tm:ClearAllPoints()
		r.tm:SetPoint("RIGHT", r, "RIGHT", -4, 0)
		r.tm:SetWidth(30)
		r.tm:Show()
		P.PlaceZone(r.zone, root, 8, y, rw, rh)
		y = y + rh + 4
	end
	P.Font(st.cap, 9)
	st.cap:SetText(L("mod.bossmods.bw.pvcap"))
	st.cap:ClearAllPoints()
	st.cap:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -(y + 2))
	st.cap:Show()
	y = y + 22
	local size = C.Get("bossmods.bw.msgsize")
	if type(size) ~= "number" or size <= 0 then size = 20 end
	P.Font(st.msg, mmin(size, 22))
	st.msg:SetText(C.Get("bossmods.bw.msgskin") ~= false and L("mod.bossmods.bw.pvmsg") or EMPTY)
	st.msg:ClearAllPoints()
	st.msg:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -y)
	st.msg:SetWidth(w - 16)
	st.msg:Show()
	P.PlaceZone(st.zmsg, root, 8, y, w - 16, 24)
end

local PVK = { bar1 = "bossmods.bw.skin", bar2 = "bossmods.bw.color", bar3 = "bossmods.bw.height", msg = "bossmods.bw.msgskin" }
if SUI.Preview and SUI.Preview.Register then
	SUI.Preview.Register("bossmods", { watch = { "bossmods." }, build = pvBuild, update = pvUpdate, click = function(zone) return PVK[zone] end })
end

-- ---------------------------------------------------------------- mode test
-- Mode test : barres et annonces FICTIVES pour placer l'interface sans etre en raid. Avec BigWigs : son propre test.
function M.Test()
	if M.eff == "bridge" then
		B.Test()
		return
	end
	M.testing = not M.testing
	if not M.testing then
		M.armed = {}
		M.narmed = 0
		M.cur = nil
		M.curLabel = EMPTY
		M.MsgStop()
		if M.win then M.Paint() end
		SUI.Print(L("msg.bossmods.testoff"))
		return
	end
	SUI.WhenSafe(function()
		if not M.testing then return end
		M.Build()
		M.win:Show()
		M.ApplySize()
		M.cur = "test"
		M.curLabel = "TEST"
		M.armed = {}
		M.narmed = 0
		local now = GetTime()
		local samples = {
			{ name = L("mod.bossmods.sample.1"), endsAt = 20, dur = 8, warn = true },
			{ name = L("mod.bossmods.sample.2"), endsAt = 14, dur = 6, warn = true },
			{ name = L("mod.bossmods.sample.3"), endsAt = 9, dur = 9, warn = true },
			{ name = L("mod.bossmods.sample.4"), endsAt = 5, dur = 5, warn = true },
		}
		local i
		for i = 1, getn(samples) do
			local e = samples[i]
			tinsert(M.armed, { name = e.name, endsAt = now + e.endsAt, dur = e.dur, ev = { dur = e.endsAt }, test = true })
			M.narmed = M.narmed + 1
			if e.warn then M.ShowMsg(e.name, L("mod.bossmods.title")) end
		end
		if C.Get("bossmods.sound") then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
		M.Paint()
		SUI.Print(L("msg.bossmods.teston"))
	end)
end

-- ---------------------------------------------------------------- commandes
-- /sui bossmods [open|close|test|bw|status|pull N] : la fenetre d'alarmes de raid (ou le pont BigWigs).
SUI.RegisterCommand("bossmods", function(rest)
	if not M.on then
		C.Set("modules.bossmods", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	elseif rest == "test" then
		M.Test()
	elseif rest == "bwtest" then
		B.Test()
	elseif rest == "bw" then
		B.OpenOptions()
	elseif rest == "status" then
		local txt = B.StatusText()
		SUI.Print(txt)
	elseif sfind(rest, "pull", 1, true) then
		local secs = tonumber(strsub(rest, 6)) or 10
		M.Pull(secs)
	else
		M.ToggleWin()
	end
end, "help.bossmods")

-- /sui pull [secondes] : compte a rebours d'engagement (celui de BigWigs s'il est la, sinon le notre).
SUI.RegisterCommand("pull", function(rest)
	if not M.on then
		C.Set("modules.bossmods", true)
	end
	M.Pull(tonumber(rest or EMPTY) or 10)
end, "help.bossmods.pull")
