-- ShikiUI CharStats : volet de statistiques colle au cote de la fenetre du personnage (onglet "Personnage"), a la maniere de
-- BetterCharacterStats / pfUI : titres de section, lignes libelle / valeur alignees, habillage du theme. Les sections sont celles du
-- builder OctoFan de l'utilisateur (base, melee, melee vs boss, distance, sorts, soins, divers, defenses, defenses vs boss) ; on choisit
-- les sections affichees ET les lignes (bouton "Choisir"), ou un role (preset de classe). Memorise PAR PERSONNAGE
-- (ShikiUIDB.global.charstats[Nom-Royaume]). Moteur de calcul inchange (formules du builder, table Rules).
-- Sources des valeurs (chaque ligne dit la sienne dans son infobulle ; "~" devant une valeur = ESTIME) :
--   1. LU EN JEU (API 1.12) : UnitStat, UnitArmor, UnitAttackPower, UnitDamage, GetCritChance, GetDodgeChance, UnitDefense...
--      optionnels (client etendu, sous pcall) : GetSpellCritChance, GetSpellBonusDamage, GetSpellBonusHealing, GetManaRegen ;
--   2. ESTIME par lecture des infobulles d'equipement / talents (motifs ANGLAIS, non verifies contre un vrai client) ;
--   3. FORMULES du builder pour les lignes "boss" (niveau 63, defense 315).
-- Erreurs : jamais avalees. Chaque groupe de calcul, chaque script et la construction sont proteges ; l'erreur va a SUI.Report
-- (journal persistant SUI.errlog, /sui errors) et reste visible dans /sui stats diag. Un groupe en panne n'empeche pas les autres.
-- Raid : le volet n'est PLUS cache par le mode Raid (cause du "je ne vois rien" : les deux personnages de l'utilisateur sont
-- en mode Raid et le preset Raid mettait charstats.show a faux). Seule la mise a jour en combat est coupee.
-- NON VERIFIE en jeu : ancrage (marges du cadre habille : 10 / 30 / 10 / 72), bouton "Stats" de la fenetre, evenements UNIT_*,
-- SetTalent, motifs anglais, coupure du libelle trop long, molette sur les lignes.
ShikiUI = ShikiUI or {}
-- Lecture d'un pourcentage du jeu SANS erreur : la fonction peut manquer dans ce client (GetCritChance, GetRangedCritChance sont absentes
-- du client observe). Ordre : fonction du jeu, puis BetterCharacterStats s'il est installe (BCS:GetCritChance), sinon 0.
local function chanceN(name, bcsName)
	local f = getglobal(name)
	if type(f) == "function" then
		local ok, v = pcall(f)
		if ok and type(v) == "number" then return v end
	end
	local bcs = getglobal("BCS")
	if bcsName and type(bcs) == "table" and type(bcs[bcsName]) == "function" then
		local ok, v = pcall(bcs[bcsName], bcs)
		if ok and type(v) == "number" then return v end
	end
	return nil
end


local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.CharStats = M

local getn = table.getn
local strfind, strformat, gsub = string.find, string.format, string.gsub
local floor = math.floor

local TICK = 0.5
local ROW_H = 14
local HEAD_H = 26
local FOOT_H = 14
local GAP = 2
local INS_L, INS_T, INS_R, INS_B = 10, 10, 30, 72   -- marges du cadre habille du personnage (haut, bas, cote)
local MAXLINES = 40
local NLINE = 40
local NSEC = 3               -- sections activees par un preset de classe ou de role
local BOSSDEF = 315          -- defense d'un boss niveau 63 (constante du builder)
local BASESKILL = 300        -- competence de base niveau 60 (BASE_SKILL du builder)
local GLANCE = 40            -- chance de coup partiel face a un boss (GLANCE_CHANCE_VS_BOSS du builder)
local BOSSDIFF = 3           -- ecart de niveau du boss (levelDiff des panneaux "vs boss")

M.on = false
M.visOK = true            -- regle de visibilite commune (charstats.vis) : le volet n'est montre que si elle l'autorise
M.active = false
M.dirty = true
M.gearDirty = true
M.talentDirty = true
M.layoutDirty = true
M.S = { stat = { 0, 0, 0, 0, 0 }, res = { 0, 0, 0, 0, 0, 0 }, level = 60, class = "", armor = 0, shield = false, ap = 0, crit = 0,
	hit = 0, skill = 0, oskill = 0, speed = 0, dmin = 0, dmax = 0, omin = 0, omax = 0, hasDmg = false, dual = false, dps = 0,
	rap = 0, rcrit = 0, rskill = 0, rspeed = 0, rmin = 0, rmax = 0, hasRanged = false, sp = 0, heal = 0, scrit = 0, shit = 0,
	mp5 = 0, haste = 0, spen = 0, apen = 0, defense = 0, defBonus = 0, dodge = 0, parry = 0, block = 0, canParry = false,
	canBlock = false, bv = 0, hp = 0, regOut = 0, regIn = 0 }
M.gear = { hit = 0, shit = 0, scrit = 0, sp = 0, heal = 0, mp5 = 0, haste = 0, spen = 0, apen = 0, bv = 0, shield = 0, crit = 0,
	dodge = 0, parry = 0, block = 0 }
M.tal = { hit = 0, shit = 0, casting = 0 }
M.cfg = { show = true, side = "right", width = 290, combat = true, dec = 2 }
M.sel = { role = "auto", sec = {}, off = {} }
M.edit = false
M.scroll = 0

-- ---------------------------------------------------------------- panneaux, presets (recopies du builder)
M.PANELS = { "base", "melee", "meleeBoss", "ranged", "spell", "heal", "misc", "defense", "defenseBoss" }
M.PANELSET = { base = true, melee = true, meleeBoss = true, ranged = true, spell = true, heal = true, misc = true, defense = true, defenseBoss = true }
M.PANELKEY = { base = "msg.charstats.p_base", melee = "msg.charstats.p_melee", meleeBoss = "msg.charstats.p_meleeboss",
	ranged = "msg.charstats.p_ranged", spell = "msg.charstats.p_spell", heal = "msg.charstats.p_heal", misc = "msg.charstats.p_misc",
	defense = "msg.charstats.p_defense", defenseBoss = "msg.charstats.p_defenseboss" }
M.CLASS_PANELS = {
	WARRIOR = { "meleeBoss", "defenseBoss", "base" }, PALADIN = { "meleeBoss", "defenseBoss", "base" },
	ROGUE = { "meleeBoss", "melee", "base" }, HUNTER = { "ranged", "meleeBoss", "base" },
	SHAMAN = { "melee", "spell", "base" }, DRUID = { "spell", "melee", "base" },
	MAGE = { "spell", "misc", "base" }, WARLOCK = { "spell", "misc", "base" }, PRIEST = { "heal", "misc", "base" },
}
M.DEFAULT_PANELS = { "melee", "defense", "base" }
M.ROLES = { "auto", "tank", "melee", "ranged", "caster", "healer" }
M.ROLEKEY = { auto = "msg.charstats.ro_auto", tank = "msg.charstats.ro_tank", melee = "msg.charstats.ro_melee",
	ranged = "msg.charstats.ro_ranged", caster = "msg.charstats.ro_caster", healer = "msg.charstats.ro_healer" }
M.ROLE_PANELS = {
	tank = { "defenseBoss", "meleeBoss", "base" }, melee = { "meleeBoss", "melee", "base" }, ranged = { "ranged", "meleeBoss", "base" },
	caster = { "spell", "misc", "base" }, healer = { "heal", "misc", "base" },
}

-- Constantes par classe (builder : SPELL_CRIT_INT_FORMULA, spiritManaPerSec, CAN_PARRY, CAN_BLOCK)
M.SPELLCRIT = { MAGE = { 3.7, 14.77, 0.65 }, WARLOCK = { 3.18, 11.30, 0.82 }, PRIEST = { 2.97, 10.03, 0.82 },
	DRUID = { 3.33, 12.41, 0.79 }, SHAMAN = { 3.54, 11.51, 0.8 }, PALADIN = { 3.7, 14.77, 0.65 } }
M.MANAREG = { DRUID = { 5, 15 }, HUNTER = { 5, 15 }, PALADIN = { 5, 15 }, WARLOCK = { 5, 15 }, MAGE = { 4, 12.5 },
	PRIEST = { 4, 12.5 }, SHAMAN = { 5, 17 } }
-- Repli quand le client n'a ni GetCritChance / GetDodgeChance... ni BetterCharacterStats : { base, points d'agilite par 1% } par classe.
-- Valeurs APPROCHEES (niveau 60), lignes affichees avec "~".
M.CRITAGI = { WARRIOR = { 0, 20 }, PALADIN = { 0, 20 }, HUNTER = { 0, 53 }, ROGUE = { 0, 29 }, SHAMAN = { 0, 20 }, DRUID = { 0, 20 },
	MAGE = { 0, 19.44 }, WARLOCK = { 0, 20 }, PRIEST = { 0, 20 } }
M.DODGEAGI = { WARRIOR = { 0.75, 20 }, PALADIN = { 0.7, 20 }, HUNTER = { -0.5, 26.5 }, ROGUE = { -0.3, 14.5 }, SHAMAN = { 1.7, 20 },
	DRUID = { 0.9, 14.7 }, MAGE = { 3.2, 19.4 }, WARLOCK = { 2, 20 }, PRIEST = { 3, 20 } }
M.CANPARRY = { WARRIOR = true, PALADIN = true, ROGUE = true }
M.CANBLOCK = { WARRIOR = true, PALADIN = true, SHAMAN = true }

-- Motifs de texte (client anglais). { motif, seau }
M.PATS = {
	{ "^Equip: Improves your chance to hit by (%d+)%%", "hit" },
	{ "^Equip: Improves your chance to hit with spells by (%d+)%%", "shit" },
	{ "^Equip: Improves your chance to get a critical strike with spells by (%d+)%%", "scrit" },
	{ "^Equip: Increases damage and healing done by magical spells and effects by up to (%d+)", "sp" },
	{ "^Equip: Increases healing done by spells and effects by up to (%d+)", "heal" },
	{ "^Equip: Restores (%d+) mana per 5 sec", "mp5" },
	{ "^Healing %+(%d+) and %d+ mana per 5 sec", "heal" },
	{ "^Healing %+%d+ and (%d+) mana per 5 sec", "mp5" },
	{ "^%+(%d+) mana every 5 sec", "mp5" },
	{ "^Equip: Decreases the magical resistances of your spell targets by (%d+)", "spen" },
	{ "^Equip: Your attacks ignore (%d+) of the target's armor", "apen" },
	{ "^Equip: Increases the block value of your shield by (%d+)", "bv" },
	{ "^(%d+) Block$", "bv" },
	{ "^Equip: .-[Hh]aste.-(%d+)%%", "haste" },
	{ "^Equip: .-casting speed.-(%d+)%%", "haste" },
	{ "^Equip: Improves your chance to get a critical strike by (%d+)%%", "crit" },
	{ "^Equip: Increases your chance to dodge an attack by (%d+)%%", "dodge" },
	{ "^Equip: Increases your chance to parry an attack by (%d+)%%", "parry" },
	{ "^Equip: Increases your chance to block attacks with a shield by (%d+)%%", "block" },
}
M.TALPATS = {
	{ "Increases your chance to hit with melee weapons by (%d+)%%", "hit" },
	{ "Increases your chance to hit with spells by (%d+)%%", "shit" },
	{ "(%d+)%% of your mana regeneration to continue while casting", "casting" },
}

function M.ReadConfig()
	local cfg = M.cfg
	cfg.show = C.Get("charstats.show")
	cfg.side = C.Get("charstats.side")
	cfg.width = C.Get("charstats.width")
	cfg.combat = C.Get("charstats.combat")
	cfg.dec = floor(C.Get("charstats.dec"))
	M.numFmt = "%." .. cfg.dec .. "f"
end

-- ---------------------------------------------------------------- formules du builder (sans dependance au jeu, testables)
local R = {}
M.Rules = R

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
R.Clamp = clamp

-- missChanceVsSkill : echec d'un coup jaune contre la defense 315
function R.MissVsSkill(skill, hit)
	return clamp(5 - (skill - BOSSDEF) * 0.2 - (hit or 0), 0, 60)
end
-- dualWieldMissChance : le builder borne d'abord l'echec a une main puis ajoute 19 (voir le rapport : ecart possible avec le serveur)
function R.DualMiss(skill, hit)
	return clamp(R.MissVsSkill(skill, hit) + 19, 0, 60)
end
function R.BossDodge(skill)
	local v = 5 + (BOSSDEF - skill) * 0.1
	if v < 0 then v = 0 end
	return v
end
-- glanceReduction : % moyen des degats conserves sur un coup partiel
function R.Glance(skill)
	local diff = BOSSDEF - skill
	local extra = skill - BASESKILL
	if extra < 0 then extra = 0 end
	local lo = clamp(1.3 - 0.05 * diff - 0.03 * extra, 0.01, 0.91)
	local hi = clamp(1.2 - 0.03 * diff - 0.01 * extra, 0.2, 0.99)
	return (lo + hi) / 2 * 100
end
-- critAdjustVsBoss
function R.CritAdjust(skill)
	if skill > BOSSDEF then return (skill - BOSSDEF) * 0.04 end
	local s = skill
	if s > BASESKILL then s = BASESKILL end
	return (s - BOSSDEF) * 0.2
end
-- critCapVsBoss
function R.CritCap(skill, hit, dual)
	local miss
	if dual then miss = R.DualMiss(skill, hit) else miss = R.MissVsSkill(skill, hit) end
	return clamp(100 - miss - GLANCE - R.BossDodge(skill), 0, 100)
end
-- avoidanceVsLevelDiff
function R.Avoid(base, levelDiff)
	local v = (base or 0) - (5 * levelDiff) * 0.04
	if v < 0 then v = 0 end
	return v
end
-- totalAvoidance
function R.TotalAvoid(defBonus, dodge, parry, block, levelDiff)
	local total = 5 + (defBonus or 0) * 0.04 + R.Avoid(dodge, levelDiff) + R.Avoid(parry, levelDiff) + R.Avoid(block or 0, levelDiff)
	if total < 0 then total = 0 end
	return total
end
-- shieldBlockValue
function R.BlockValue(str, flat)
	local v = floor((flat or 0) + (str or 0) / 20 - 1)
	if v < 0 then v = 0 end
	return v
end
-- spiritManaPerSec x 5 : mana par 5 s due a l'Esprit
function R.SpiritMana5(class, spi)
	local f = M.MANAREG[class]
	if not f then return 0 end
	return ((spi or 0) / f[1] + f[2]) / 2 * 5
end
-- Repli : critique melee / distance (agilite + base de classe), borne a 0
function R.PhysCrit(class, agi)
	local t = M.CRITAGI[class]
	if not t then return 0 end
	local v = t[1] + (agi or 0) / t[2]
	if v < 0 then v = 0 end
	return v
end
-- Repli : esquive (agilite + base de classe + defense au dessus de 5 x niveau)
function R.DodgeFb(class, agi, defBonus)
	local t = M.DODGEAGI[class]
	if not t then return 0 end
	local v = t[1] + (agi or 0) / t[2] + (defBonus or 0) * 0.04
	if v < 0 then v = 0 end
	return v
end
-- spellCritFromInt
function R.SpellCrit(class, intel, level)
	local sc = M.SPELLCRIT[class]
	if not sc then return 0 end
	return sc[1] + (intel or 0) / (sc[2] + sc[3] * level)
end
-- toucher de base d'un sort selon l'ecart de niveau (cible - lanceur), puis chance de toucher bornee (vs boss : ecart 3 -> 83)
function R.SpellBase(levelDiff)
	local base
	if levelDiff < 3 then base = 96 - levelDiff else base = 94 - (levelDiff - 2) * 11 end
	if base < 33 then base = 33 end
	return base
end
function R.SpellHit(levelDiff, hit)
	return clamp(R.SpellBase(levelDiff) + hit, 1, 99)
end

-- ---------------------------------------------------------------- lecture des infobulles (equipement, talents)
function M.BuildTip()
	if M.tip then return end
	M.tipName = "ShikiUI_StatsTip"
	local tip = CreateFrame("GameTooltip", M.tipName, nil, "GameTooltipTemplate")
	M.tip = tip
	M.lineNames = {}
	M.rightNames = {}
	for i = 1, MAXLINES do
		M.lineNames[i] = M.tipName .. "TextLeft" .. i
		M.rightNames[i] = M.tipName .. "TextRight" .. i
	end
end

local function zero(t)
	for k, v in pairs(t) do
		if type(v) == "table" then zero(v) else t[k] = 0 end
	end
end

-- Additionne dans 'bucket' ce que disent les lignes de l'infobulle courante. stopAtNext : s'arrete a "Next rank" (talents).
function M.ReadLines(bucket, pats, stopAtNext)
	local tip = M.tip
	local n = tip:NumLines()
	if n > MAXLINES then n = MAXLINES end
	for i = 1, n do
		local fs = getglobal(M.lineNames[i])
		local text = fs and fs:GetText()
		if text then
			if stopAtNext and strfind(text, "^Next rank") then return end
			for k = 1, getn(pats) do
				local p = pats[k]
				local _, _, v = strfind(text, p[1])
				if v then bucket[p[2]] = bucket[p[2]] + tonumber(v) end
			end
		end
	end
end

-- Vrai si une ligne de DROITE de l'infobulle courante vaut 'word' (le type d'objet "Shield" y est affiche).
function M.RightHas(word)
	local n = M.tip:NumLines()
	if n > MAXLINES then n = MAXLINES end
	for i = 1, n do
		local fs = getglobal(M.rightNames[i])
		local text = fs and fs:GetText()
		if text == word then return true end
	end
	return false
end

function M.ScanGear()
	M.gearDirty = false
	M.BuildTip()
	zero(M.gear)
	for slot = 1, 19 do
		M.tip:SetOwner(UIParent, "ANCHOR_NONE")
		if M.tip:SetInventoryItem("player", slot) then
			M.ReadLines(M.gear, M.PATS, false)
			if slot == 17 and M.RightHas("Shield") then M.gear.shield = 1 end
		end
	end
end

function M.ScanTalents()
	M.talentDirty = false
	M.BuildTip()
	zero(M.tal)
	for tab = 1, GetNumTalentTabs() do
		for i = 1, GetNumTalents(tab) do
			local _, _, _, _, rank = GetTalentInfo(tab, i)
			if rank and rank > 0 then
				M.tip:SetOwner(UIParent, "ANCHOR_NONE")
				M.tip:SetTalent(tab, i)
				M.ReadLines(M.tal, M.TALPATS, true)
			end
		end
	end
end

-- ---------------------------------------------------------------- calcul des valeurs
-- Appel d'une fonction OPTIONNELLE (client etendu) : nil si absente ou en erreur.
local function optcall(name, a)
	local f = getglobal(name)
	if not f then return nil end
	local ok, v1, v2 = pcall(f, a)
	if ok then return v1, v2 end
	return nil
end

-- Execute un groupe de calcul : l'erreur est rapportee (SUI.Report) et les autres groupes continuent.
function M.Safe(name, fn)
	local ok, err = pcall(fn)
	if not ok then M.Fail(name, err) end
	return ok
end

function M.Fail(where, err)
	local msg = tostring(where) .. " : " .. tostring(err)
	M.lastErr = msg
	if M.failKey ~= msg then
		M.failKey = msg
		SUI.Report("charstats " .. tostring(where), err)
	end
end

function M.CalcBase()
	local S, g = M.S, M.gear
	local lvl = UnitLevel("player")
	local _, class = UnitClass("player")
	S.level, S.class = lvl, class
	for i = 1, 5 do
		local _, eff = UnitStat("player", i)
		S.stat[i] = eff
	end
	local _, armor = UnitArmor("player")
	S.armor = armor
	S.shield = g.shield > 0
end

function M.CalcMelee()
	local S, g, tl = M.S, M.gear, M.tal
	local base, pos, neg = UnitAttackPower("player")
	S.ap = base + pos + neg
	local cc = chanceN("GetCritChance", "GetCritChance")
	if cc then
		S.crit, S.critRead = cc, true
	else
		S.crit, S.critRead = R.PhysCrit(S.class, S.stat[2]) + g.crit, false
	end
	S.hit = g.hit + tl.hit
	local mainBase, mainMod, offBase, offMod = UnitAttackBothHands("player")
	S.skill = mainBase + mainMod
	S.oskill = (offBase or 0) + (offMod or 0)
	local speed, offSpeed = UnitAttackSpeed("player")
	S.speed, S.offSpeed = speed, offSpeed
	local dmin, dmax, omin, omax = UnitDamage("player")
	S.dmin, S.dmax, S.omin, S.omax = dmin, dmax, omin or 0, omax or 0
	S.hasDmg = (speed and speed > 0) and true or false
	S.dual = (offSpeed and not S.shield) and true or false
	local dps = 0
	if S.hasDmg then
		dps = (dmin + dmax) / 2 / speed
		if S.dual and offSpeed > 0 then dps = dps + (S.omin + S.omax) / 2 / offSpeed end
	end
	S.dps = dps
end

function M.CalcRanged()
	local S = M.S
	local rbase, rpos, rneg = UnitRangedAttackPower("player")
	S.rap = rbase + rpos + rneg
	local rc = chanceN("GetRangedCritChance", "GetRangedCritChance")
	if rc then
		S.rcrit, S.rcritRead = rc, true
	else
		S.rcrit, S.rcritRead = R.PhysCrit(S.class, S.stat[2]) + M.gear.crit, false
	end
	local rsb, rsm = UnitRangedAttack("player")
	S.rskill = (rsb or 0) + (rsm or 0)
	local rspeed, rmin, rmax = UnitRangedDamage("player")
	S.rspeed, S.rmin, S.rmax = rspeed, rmin or 0, rmax or 0
	S.hasRanged = (rspeed and rspeed > 0) and true or false
end

function M.CalcSpell()
	local S, g, tl = M.S, M.gear, M.tal
	local lvl, class = S.level, S.class
	local spread = true
	local best
	for s = 2, 7 do
		local v = optcall("GetSpellBonusDamage", s)
		if type(v) ~= "number" then spread = false break end
		if not best or v < best then best = v end
	end
	if spread and best then S.sp, S.spRead = best, true else S.sp, S.spRead = g.sp, false end
	local hv = optcall("GetSpellBonusHealing")
	if type(hv) == "number" then S.heal, S.healRead = hv, true else S.heal, S.healRead = g.heal + g.sp, false end
	local sc = optcall("GetSpellCritChance")
	if type(sc) == "number" then
		S.scrit, S.scritRead = sc, true
	else
		S.scrit, S.scritRead = R.SpellCrit(class, S.stat[4], lvl) + g.scrit, false
	end
	S.shit = g.shit + tl.shit
	S.mp5 = g.mp5
	S.haste = g.haste
	S.spen, S.apen = g.spen, g.apen
end

function M.CalcDefense()
	local S, g = M.S, M.gear
	local lvl, class = S.level, S.class
	local dbase, dmod = UnitDefense("player")
	S.defense = dbase + dmod
	S.defBonus = S.defense - lvl * 5
	S.canParry = M.CANPARRY[class] and true or false
	S.canBlock = (M.CANBLOCK[class] and S.shield) and true or false
	local dd, pp, bb = chanceN("GetDodgeChance"), chanceN("GetParryChance"), chanceN("GetBlockChance")
	if dd then S.dodge, S.dodgeRead = dd, true else S.dodge, S.dodgeRead = R.DodgeFb(class, S.stat[2], S.defBonus) + g.dodge, false end
	if pp then
		S.parry, S.parryRead = pp, true
	else
		S.parry, S.parryRead = (S.canParry and (5 + S.defBonus * 0.04) or 0) + g.parry, false
	end
	if bb then
		S.block, S.blockRead = bb, true
	else
		S.block, S.blockRead = (S.canBlock and (5 + S.defBonus * 0.04) or 0) + g.block, false
	end
	S.bv = R.BlockValue(S.stat[1], g.bv)
	for i = 1, 6 do
		local _, total = UnitResistance("player", i)
		S.res[i] = total
	end
end

function M.CalcMisc()
	local S, g, tl = M.S, M.gear, M.tal
	local class = S.class
	-- vie, mana (le mana d'un druide en forme animale est la derniere valeur lue sous forme humanoide)
	S.hp = UnitHealthMax("player")
	if UnitPowerType("player") == 0 then
		local mm = UnitManaMax("player")
		if mm and mm > 0 then M.lastMana = mm else M.lastMana = nil end
	end
	S.mana = M.lastMana
	-- regeneration de mana par 5 s
	local sp5 = R.SpiritMana5(class, S.stat[5])
	local casting = clamp(tl.casting, 0, 100)
	S.regOut, S.regIn, S.regRead = sp5 + g.mp5, sp5 * casting / 100 + g.mp5, false
	local rb, rc = optcall("GetManaRegen")
	if type(rb) == "number" and type(rc) == "number" then
		S.regOut, S.regIn, S.regRead = rb * 5, rc * 5, true
	end
end

function M.Compute()
	if M.gearDirty then M.Safe("gear", M.ScanGear) end
	if M.talentDirty then M.Safe("talents", M.ScanTalents) end
	M.Safe("base", M.CalcBase)
	M.Safe("melee", M.CalcMelee)
	M.Safe("ranged", M.CalcRanged)
	M.Safe("spell", M.CalcSpell)
	M.Safe("defense", M.CalcDefense)
	M.Safe("misc", M.CalcMisc)
	M.dirty = false
end

-- ---------------------------------------------------------------- mise en forme
local function trimz(s)
	if strfind(s, ".", 1, true) then
		s = gsub(s, "0+$", "")
		s = gsub(s, "%.$", "")
	end
	if s == "-0" then s = "0" end
	return s
end
local function pct(v) return trimz(strformat(M.numFmt, v)) .. "%" end
local function int(v) return strformat("%d", floor(v + 0.5)) end
local function rng(a, b) return int(a) .. " - " .. int(b) end
local function rngc(a, b) return int(a) .. "-" .. int(b) end

-- Une ligne : l = cle du libelle, v = valeur (texte), api = fonction du jeu lue, tip = explication de l'estimation ou du calcul,
-- est = true (toujours estime) | nom d'un drapeau de M.S qui vaut vrai quand la valeur est LUE.
local ROWS = {}
M.ROWS = ROWS
local function row(key, l, v, api, tip, est)
	ROWS[key] = { l = l, v = v, api = api, tip = tip, est = est }
end

row("str", "msg.charstats.r_str", function(S) return int(S.stat[1]) end, "UnitStat")
row("agi", "msg.charstats.r_agi", function(S) return int(S.stat[2]) end, "UnitStat")
row("sta", "msg.charstats.r_sta", function(S) return int(S.stat[3]) end, "UnitStat")
row("int", "msg.charstats.r_int", function(S) return int(S.stat[4]) end, "UnitStat")
row("spi", "msg.charstats.r_spi", function(S) return int(S.stat[5]) end, "UnitStat")
row("armor", "msg.charstats.r_armor", function(S) return int(S.armor) end, "UnitArmor")
-- melee
local function skillText(S)
	if S.dual then return int(S.skill) .. " | " .. int(S.oskill) end
	return int(S.skill)
end
local function dmgText(S)
	if not S.hasDmg then return "-" end
	if S.dual then return rngc(S.dmin, S.dmax) .. " | " .. rngc(S.omin, S.omax) end
	return rng(S.dmin, S.dmax)
end
local function spdText(S)
	if not S.hasDmg then return "-" end
	if S.dual then return strformat("%.2f | %.2f", S.speed, S.offSpeed) end
	return strformat("%.2f", S.speed)
end
row("skill", "msg.charstats.r_skill", skillText, "UnitAttackBothHands")
row("skillb", "msg.charstats.r_skill", function(S) return int(S.skill) end, "UnitAttackBothHands")
row("dmg", "msg.charstats.r_dmg", dmgText, "UnitDamage")
row("dmg2", "msg.charstats.r_dmg2", dmgText, "UnitDamage")
row("spd", "msg.charstats.r_spd", spdText, "UnitAttackSpeed")
row("spd2", "msg.charstats.r_spd2", spdText, "UnitAttackSpeed")
row("dps", "msg.charstats.r_dps", function(S) return int(S.dps) end, nil, "msg.charstats.t_dps")
row("ap", "msg.charstats.r_ap", function(S) return int(S.ap) end, "UnitAttackPower")
row("hit", "msg.charstats.r_hit", function(S) return pct(S.hit) end, nil, "msg.charstats.t_hit", true)
row("crit", "msg.charstats.r_crit", function(S) return pct(S.crit) end, "GetCritChance", "msg.charstats.t_chancefb", "critRead")
-- melee vs boss niveau 63
row("miss", "msg.charstats.r_miss", function(S)
	if S.dual then return pct(R.DualMiss(S.skill, S.hit)) end
	return pct(R.MissVsSkill(S.skill, S.hit))
end, nil, "msg.charstats.t_hitdep", true)
row("missS", "msg.charstats.r_missS", function(S) return pct(R.MissVsSkill(S.skill, S.hit)) end, nil, "msg.charstats.t_hitdep", true)
row("needS", "msg.charstats.r_needS", function(S) return pct(R.MissVsSkill(S.skill, 0)) end, nil, "msg.charstats.t_boss")
row("needW", "msg.charstats.r_needW", function(S) return pct(clamp(R.MissVsSkill(S.skill, 0) + 19, 0, 60)) end, nil, "msg.charstats.t_boss")
row("bdodge", "msg.charstats.r_bdodge", function(S) return pct(R.BossDodge(S.skill)) end, nil, "msg.charstats.t_boss")
row("glance", "msg.charstats.r_glance", function(S) return pct(R.Glance(S.skill)) end, nil, "msg.charstats.t_boss")
row("critcap", "msg.charstats.r_critcap", function(S) return pct(R.CritCap(S.skill, S.hit, S.dual)) end, nil, "msg.charstats.t_hitdep", true)
row("criteff", "msg.charstats.r_criteff", function(S)
	local cap = R.CritCap(S.skill, S.hit, S.dual)
	return pct(clamp(S.crit + R.CritAdjust(S.skill), 0, cap))
end, nil, "msg.charstats.t_hitdep", true)
-- distance
row("rskill", "msg.charstats.r_skill", function(S) return int(S.rskill) end, "UnitRangedAttack")
row("rdmg", "msg.charstats.r_dmg", function(S) return rng(S.rmin, S.rmax) end, "UnitRangedDamage")
row("rspd", "msg.charstats.r_spd", function(S) return strformat("%.2f", S.rspeed) end, "UnitRangedDamage")
row("rap", "msg.charstats.r_ap", function(S) return int(S.rap) end, "UnitRangedAttackPower")
row("rhit", "msg.charstats.r_hit", function(S) return pct(S.hit) end, nil, "msg.charstats.t_hit", true)
row("rcrit", "msg.charstats.r_crit", function(S) return pct(S.rcrit) end, "GetRangedCritChance", "msg.charstats.t_chancefb", "rcritRead")
row("norange", "msg.charstats.r_norange", function(S) return "" end)
-- sorts et soins
row("sp", "msg.charstats.r_sp", function(S) return int(S.sp) end, "GetSpellBonusDamage", "msg.charstats.t_gear", "spRead")
row("shit", "msg.charstats.r_hit", function(S) return pct(S.shit) end, nil, "msg.charstats.t_hit", true)
row("sbhit", "msg.charstats.r_sbhit", function(S) return pct(R.SpellHit(BOSSDIFF, S.shit)) end, nil, "msg.charstats.t_hitdep", true)
row("sneed", "msg.charstats.r_sneed", function(S)
	local v = 99 - R.SpellBase(BOSSDIFF) - S.shit
	if v < 0 then v = 0 end
	return pct(v)
end, nil, "msg.charstats.t_hitdep", true)
row("scrit", "msg.charstats.r_crit", function(S) return pct(S.scrit) end, "GetSpellCritChance", "msg.charstats.t_scrit", "scritRead")
row("healb", "msg.charstats.r_healb", function(S) return int(S.heal) end, "GetSpellBonusHealing", "msg.charstats.t_gear", "healRead")
row("hpow", "msg.charstats.r_hpow", function(S) return int(S.heal) end, "GetSpellBonusHealing", "msg.charstats.t_gear", "healRead")
row("hcrit", "msg.charstats.r_hcrit", function(S) return pct(S.scrit) end, "GetSpellCritChance", "msg.charstats.t_scrit", "scritRead")
row("mp5", "msg.charstats.r_mp5", function(S) return int(S.mp5) end, nil, "msg.charstats.t_gear", true)
row("haste", "msg.charstats.r_haste", function(S) return pct(S.haste) end, nil, "msg.charstats.t_gear", true)
-- divers
row("hp", "msg.charstats.r_hp", function(S) return int(S.hp) end, "UnitHealthMax")
row("manamax", "msg.charstats.r_manamax", function(S) return S.mana and int(S.mana) or "-" end, "UnitManaMax")
row("regout", "msg.charstats.r_regout", function(S) return int(S.regOut) end, "GetManaRegen", "msg.charstats.t_regen", "regRead")
row("regin", "msg.charstats.r_regin", function(S) return int(S.regIn) end, "GetManaRegen", "msg.charstats.t_regen", "regRead")
row("res", "msg.charstats.r_res", function(S)
	local r = S.res
	return int(r[2]) .. " / " .. int(r[3]) .. " / " .. int(r[4]) .. " / " .. int(r[5]) .. " / " .. int(r[6])
end, "UnitResistance")
row("spen", "msg.charstats.r_spen", function(S) return int(S.spen) end, nil, "msg.charstats.t_gear", true)
row("apen", "msg.charstats.r_apen", function(S) return int(S.apen) end, nil, "msg.charstats.t_gear", true)
-- defense (niveau egal) et defense contre un boss (ecart de 3 niveaux)
row("defense", "msg.charstats.r_defense", function(S) return int(S.defense) end, "UnitDefense")
row("dodge", "msg.charstats.r_dodge", function(S) return pct(S.dodge) end, "GetDodgeChance", "msg.charstats.t_chancefb", "dodgeRead")
row("parry", "msg.charstats.r_parry", function(S) return S.canParry and pct(S.parry) or "-" end, "GetParryChance", "msg.charstats.t_chancefb", "parryRead")
row("block", "msg.charstats.r_block", function(S) return S.canBlock and pct(S.block) or "-" end, "GetBlockChance", "msg.charstats.t_chancefb", "blockRead")
row("total", "msg.charstats.r_total", function(S)
	return pct(R.TotalAvoid(S.defBonus, S.dodge, S.canParry and S.parry or 0, S.canBlock and S.block or 0, 0))
end, nil, "msg.charstats.t_total")
row("dodgeb", "msg.charstats.r_dodge", function(S) return pct(R.Avoid(S.dodge, BOSSDIFF)) end, nil, "msg.charstats.t_avoid")
row("parryb", "msg.charstats.r_parry", function(S) return S.canParry and pct(R.Avoid(S.parry, BOSSDIFF)) or "-" end, nil, "msg.charstats.t_avoid")
row("blockb", "msg.charstats.r_block", function(S) return S.canBlock and pct(R.Avoid(S.block, BOSSDIFF)) or "-" end, nil, "msg.charstats.t_avoid")
row("totalb", "msg.charstats.r_total", function(S)
	return pct(R.TotalAvoid(S.defBonus, S.dodge, S.canParry and S.parry or 0, S.canBlock and S.block or 0, BOSSDIFF))
end, nil, "msg.charstats.t_total")
row("bval", "msg.charstats.r_bval", function(S) return int(S.bv) end, nil, "msg.charstats.t_bval", true)

-- Contenu de chaque panneau (ordre du builder) : remplit 'o' (reutilise) et rend le nombre de lignes.
local function put(o, n, k)
	n = n + 1
	o[n] = k
	return n
end
local PR = {}
M.PANEL_ROWS = PR
PR.base = function(S, o)
	o[1], o[2], o[3], o[4], o[5], o[6] = "str", "agi", "sta", "int", "spi", "armor"
	return 6
end
PR.melee = function(S, o)
	local n = put(o, 0, "skill")
	n = put(o, n, S.dual and "dmg2" or "dmg")
	n = put(o, n, S.dual and "spd2" or "spd")
	if S.hasDmg then n = put(o, n, "dps") end
	n = put(o, n, "ap")
	n = put(o, n, "hit")
	return put(o, n, "crit")
end
PR.meleeBoss = function(S, o)
	local n = put(o, 0, "skillb")
	n = put(o, n, "miss")
	if S.dual then n = put(o, n, "missS") end
	n = put(o, n, "needS")
	if S.dual then n = put(o, n, "needW") end
	n = put(o, n, "bdodge")
	n = put(o, n, "glance")
	n = put(o, n, "critcap")
	return put(o, n, "criteff")
end
PR.ranged = function(S, o)
	if not S.hasRanged then return put(o, 0, "norange") end
	o[1], o[2], o[3], o[4], o[5], o[6] = "rskill", "rdmg", "rspd", "rap", "rhit", "rcrit"
	return 6
end
PR.spell = function(S, o)
	o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8] = "sp", "shit", "sbhit", "sneed", "scrit", "healb", "mp5", "haste"
	return 8
end
PR.heal = function(S, o)
	local n = put(o, 0, "hpow")
	n = put(o, n, "hcrit")
	n = put(o, n, "manamax")
	n = put(o, n, "regout")
	n = put(o, n, "regin")
	return put(o, n, "haste")
end
PR.misc = function(S, o)
	local n = put(o, 0, "hp")
	n = put(o, n, "manamax")
	if S.mana then
		n = put(o, n, "regout")
		n = put(o, n, "regin")
	end
	n = put(o, n, "res")
	if S.spen > 0 then n = put(o, n, "spen") end
	if S.apen > 0 then n = put(o, n, "apen") end
	return n
end
PR.defense = function(S, o)
	o[1], o[2], o[3], o[4], o[5], o[6] = "armor", "defense", "dodge", "parry", "block", "total"
	if S.canBlock then return put(o, 6, "bval") end
	return 6
end
PR.defenseBoss = function(S, o)
	o[1], o[2], o[3], o[4], o[5], o[6] = "armor", "defense", "dodgeb", "parryb", "blockb", "totalb"
	if S.canBlock then return put(o, 6, "bval") end
	return 6
end

function M.Label(key)
	return L(ROWS[key].l)
end

function M.IsEst(spec)
	local e = spec.est
	if e == true then return true end
	if not e then return false end
	return not M.S[e]
end

-- Texte d'une ligne ("~" devant = estime).
function M.Value(key)
	local spec = ROWS[key]
	local v = spec.v(M.S)
	if v ~= "" and M.IsEst(spec) then return "~" .. v end
	return v
end

-- ---------------------------------------------------------------- selection (sections, lignes masquees, role) par personnage
function M.Preset(role)
	local rp = M.ROLE_PANELS[role]
	if rp then return rp end
	local _, class = UnitClass("player")
	return M.CLASS_PANELS[class] or M.DEFAULT_PANELS
end

local function validRole(r)
	return type(r) == "string" and (r == "auto" or M.ROLE_PANELS[r] ~= nil)
end

-- Remplace les sections activees par la liste (noms de panneaux).
function M.SetSections(list)
	local sec = {}
	for i = 1, getn(list) do
		if M.PANELSET[list[i]] then sec[list[i]] = true end
	end
	M.sel.sec = sec
end

function M.LoadSel()
	local g = C.GetGlobal("charstats")
	local rec = type(g) == "table" and g[C.CharKey()] or nil
	if type(rec) ~= "table" then rec = nil end
	local sel = M.sel
	sel.role = (rec and validRole(rec.role)) and rec.role or "auto"
	sel.off = {}
	if rec and type(rec.sec) == "table" then
		local sec = {}
		for i = 1, getn(M.PANELS) do
			local p = M.PANELS[i]
			if rec.sec[p] == true then sec[p] = true end
		end
		sel.sec = sec
	elseif rec and type(rec.p1) == "string" then
		-- ancien format : trois panneaux p1..p3
		M.SetSections({ rec.p1, type(rec.p2) == "string" and rec.p2 or "", type(rec.p3) == "string" and rec.p3 or "" })
	else
		M.SetSections(M.Preset(sel.role))
	end
	if rec and type(rec.off) == "table" then
		for k, v in pairs(rec.off) do
			if v == true and type(k) == "string" then
				local _, _, p, key = strfind(k, "^(%a+)%.(%a[%w]*)$")
				if p and M.PANELSET[p] and ROWS[key] then sel.off[k] = true end
			end
		end
	end
end

function M.SaveSel()
	local g = C.GetGlobal("charstats")
	if type(g) ~= "table" then
		g = {}
		C.SetGlobal("charstats", g)
	end
	local key = C.CharKey()
	if not g[key] then
		local n = 0
		for _ in pairs(g) do n = n + 1 end
		if n >= 64 then return end
	end
	local sel = M.sel
	local sec, off = {}, {}
	for k, v in pairs(sel.sec) do if v then sec[k] = true end end
	for k, v in pairs(sel.off) do if v then off[k] = true end end
	g[key] = { role = sel.role, sec = sec, off = off }
end

function M.Touch()
	M.layoutDirty = true
	M.dirty = true
	M.Refresh()
end

function M.ToggleSection(name)
	if not M.PANELSET[name] then return false end
	if M.sel.sec[name] then M.sel.sec[name] = nil else M.sel.sec[name] = true end
	M.SaveSel()
	M.Touch()
	return true
end

function M.ToggleRow(p, key)
	if not (M.PANELSET[p] and ROWS[key]) then return false end
	local id = p .. "." .. key
	if M.sel.off[id] then M.sel.off[id] = nil else M.sel.off[id] = true end
	M.SaveSel()
	M.Touch()
	return true
end

function M.SetRole(role)
	if not validRole(role) then return false end
	M.sel.role = role
	M.SetSections(M.Preset(role))
	M.sel.off = {}
	M.SaveSel()
	M.Touch()
	return true
end

function M.SetEdit(on)
	M.edit = on and true or false
	M.scroll = 0
	M.Touch()
end

local function step(list, cur, mouse)
	local at = 1
	for i = 1, getn(list) do
		if list[i] == cur then at = i end
	end
	if mouse == "RightButton" then at = at - 1 else at = at + 1 end
	if at < 1 then at = getn(list) end
	if at > getn(list) then at = 1 end
	return list[at]
end

function M.OnRoleClick(btn, mouse)
	M.SetRole(step(M.ROLES, M.sel.role, mouse))
end

function M.OnEditClick()
	M.SetEdit(not M.edit)
end

function M.OnToggle()
	C.Set("charstats.show", not C.Get("charstats.show"))
end

-- Un clic sur une ligne n'a d'effet qu'en mode "Choisir" : titre = section, ligne = afficher / masquer.
function M.LineClick(ln)
	if not M.edit or not ln or not ln.kind then return end
	if ln.kind == "H" then M.ToggleSection(ln.p) else M.ToggleRow(ln.p, ln.key) end
end

-- Appel protege d'un script : l'erreur va au journal (SUI.Report) au lieu d'etre avalee.
function M.Call(name, fn, a, b)
	local ok, err = pcall(fn, a, b)
	if not ok then M.Fail(name, err) end
end

-- ---------------------------------------------------------------- affichage : liste a plat { titre | ligne }, fenetre de lignes defilante
M.ek, M.ep, M.ekey, M.tmp = {}, {}, {}, {}
M.ne = 0
M.nv = 0
M.lines = {}

function M.BuildEntries()
	local ek, ep, ekey, tmp = M.ek, M.ep, M.ekey, M.tmp
	local sel, S = M.sel, M.S
	local n = 0
	for i = 1, getn(M.PANELS) do
		local p = M.PANELS[i]
		local on = sel.sec[p]
		if on or M.edit then
			n = n + 1
			ek[n], ep[n], ekey[n] = "H", p, false
			if on then
				local ok, cnt = pcall(PR[p], S, tmp)
				if ok then
					for j = 1, cnt do
						local k = tmp[j]
						if M.edit or not sel.off[p .. "." .. k] then
							n = n + 1
							ek[n], ep[n], ekey[n] = "R", p, k
						end
					end
				else
					M.Fail("panel " .. p, cnt)
				end
			end
		end
	end
	M.ne = n
end

-- Nombre de lignes qui tiennent a la hauteur du cadre du personnage.
function M.MaxVisible()
	local h = M.cf and M.cf:GetHeight()
	if type(h) ~= "number" or h < 200 then h = 512 end
	local m = floor((h - INS_T - INS_B - HEAD_H - FOOT_H - 6) / ROW_H)
	if m < 8 then m = 8 end
	if m > NLINE then m = NLINE end
	return m
end

local function safeValue(key)
	local ok, v = pcall(M.Value, key)
	if ok then return v end
	M.Fail("value " .. tostring(key), v)
	return "?"
end

function M.Layout()
	local p, cfg, c = M.panel, M.cfg, T.c
	local n, maxv = M.ne, M.MaxVisible()
	local top = n - maxv
	if top < 0 then top = 0 end
	if M.scroll > top then M.scroll = top end
	if M.scroll < 0 then M.scroll = 0 end
	local sc = M.scroll
	local nv = n - sc
	if nv > maxv then nv = maxv end
	local foot = ""
	if M.edit then
		foot = L("msg.charstats.hint")
	elseif n > maxv then
		foot = L("msg.charstats.scroll", sc + 1, sc + nv, n)
	end
	M.foot:SetText(foot)
	p:SetWidth(cfg.width)
	p:SetHeight(HEAD_H + nv * ROW_H + ((foot ~= "") and FOOT_H or 0) + 8)
	T.SetButtonText(M.roBtn, L("msg.charstats.role", L(M.ROLEKEY[M.sel.role])))
	M.roBtn:SetWidth(cfg.width - 12 - 84)
	T.SetButtonText(M.edBtn, M.edit and L("msg.charstats.done") or L("msg.charstats.choose"))
	T.SetSelected(M.edBtn, M.edit)
	local ar, ag, ab = T.Accent()
	for i = 1, nv do
		local ln = M.lines[i]
		local idx = sc + i
		local kind, pn, key = M.ek[idx], M.ep[idx], M.ekey[idx]
		ln.kind, ln.p, ln.key = kind, pn, key
		if kind == "H" then
			ln.label:SetText(L(M.PANELKEY[pn]))
			ln.value:SetText(M.edit and (M.sel.sec[pn] and "[x]" or "[ ]") or "")
			ln.label:SetTextColor(ar, ag, ab, 1)
			ln.value:SetTextColor(ar, ag, ab, 1)
			ln.bg:SetVertexColor(c.inset[1], c.inset[2], c.inset[3], 1)
		else
			ln.label:SetText(M.Label(key))
			if M.edit then
				local hid = M.sel.off[pn .. "." .. key]
				ln.value:SetText(hid and "[ ]" or "[x]")
				local lc = hid and c.dim or c.text
				local vc = hid and c.dim or c.good
				ln.label:SetTextColor(lc[1], lc[2], lc[3], 1)
				ln.value:SetTextColor(vc[1], vc[2], vc[3], 1)
			else
				ln.value:SetText(safeValue(key))
				ln.label:SetTextColor(c.dim[1], c.dim[2], c.dim[3], 1)
				ln.value:SetTextColor(c.text[1], c.text[2], c.text[3], 1)
			end
			ln.bg:SetVertexColor(c.inset[1], c.inset[2], c.inset[3], 0)
		end
		ln:Show()
	end
	for i = nv + 1, NLINE do
		local ln = M.lines[i]
		ln.kind, ln.key = nil, nil
		ln:Hide()
	end
	M.nv = nv
	M.layoutDirty = false
end

function M.Refresh()
	if not M.panel or not M.panel:IsVisible() then return end
	local ok, err = pcall(M.Compute)
	if not ok then M.Fail("compute", err) return end
	local ok2, err2 = pcall(M.BuildEntries)
	if not ok2 then M.Fail("entries", err2) return end
	local ok3, err3 = pcall(M.Layout)
	if not ok3 then M.Fail("layout", err3) end
end

function M.Scroll(delta)
	if not M.panel or not M.panel:IsVisible() then return end
	M.scroll = M.scroll + delta
	M.Call("scroll", M.Layout)
end

function M.OnWheel(d)
	if type(d) ~= "number" then return end
	M.Scroll(-d * 3)
end

-- Infobulle d'une ligne : ce qu'elle mesure, d'ou vient la valeur, et "~" = estime.
function M.RowEnter()
	local r = this
	local key = r and r.key
	local gt = getglobal("GameTooltip")
	if not key or not gt then return end
	local spec = ROWS[key]
	local c, d, w = T.c.text, T.c.dim, T.c.warn
	gt:SetOwner(r, "ANCHOR_RIGHT")
	gt:SetText(M.Label(key), c[1], c[2], c[3])
	if M.IsEst(spec) then
		if spec.tip then gt:AddLine(L(spec.tip), d[1], d[2], d[3], 1) end
		gt:AddLine(L("msg.charstats.t_est"), w[1], w[2], w[3], 1)
	elseif spec.api then
		gt:AddLine(L("msg.charstats.t_read", spec.api), d[1], d[2], d[3], 1)
	elseif spec.tip then
		gt:AddLine(L(spec.tip), d[1], d[2], d[3], 1)
	end
	gt:Show()
end

function M.RowLeave()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

-- Ancrage du volet colle au cote de la fenetre du personnage (marges du cadre habille) et du bouton "Stats".
function M.Place()
	local p, cf = M.panel, M.cf
	p:ClearAllPoints()
	if M.cfg.side == "left" then
		p:SetPoint("TOPRIGHT", cf, "TOPLEFT", INS_L - GAP, -INS_T)
	else
		p:SetPoint("TOPLEFT", cf, "TOPRIGHT", GAP - INS_R, -INS_T)
	end
	M.btn:ClearAllPoints()
	M.btn:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -64, -14)
end

function M.ApplyOptions()
	if not M.built then return end
	local wish = (M.on and M.cfg.show) and true or false
	local shown = (wish and M.visOK) and true or false
	M.layoutDirty = true
	M.Place()
	T.SetButtonText(M.btn, L("msg.charstats.btn"))
	if M.on then M.btn:Show() else M.btn:Hide() end
	if M.gearBtn then
		if M.on then M.gearBtn:Show() else M.gearBtn:Hide() end
	end
	T.SetSelected(M.btn, wish)
	if shown then M.panel:Show() else M.panel:Hide() end
	M.dirty = true
	M.Refresh()
end

-- ---------------------------------------------------------------- construction (une seule fois, hors combat)
function M.Build()
	if M.built then return end
	local cf = getglobal("CharacterFrame")
	if not cf then return end                    -- pas d'interface Blizzard (hors jeu) : le module reste inactif
	local par = getglobal("PaperDollFrame") or cf    -- visible seulement sur l'onglet Personnage
	M.cf, M.par = cf, par
	M.ReadConfig()
	local p = CreateFrame("Frame", "ShikiUI_CharStats", par)
	p:SetWidth(M.cfg.width)
	p:SetHeight(60)
	local lv = par:GetFrameLevel()
	if type(lv) == "number" then p:SetFrameLevel(lv + 2) end
	T.Backdrop(p, T.c.bg, T.c.border)
	p:EnableMouse(true)
	p:EnableMouseWheel(true)
	p:SetScript("OnMouseWheel", function() M.Call("wheel", M.OnWheel, arg1) end)
	p:SetScript("OnShow", function() M.Call("show", M.OnShow) end)
	M.panel = p
	M.edBtn = T.Button(p, "", 80, 18, function(b, m) M.Call("edit", M.OnEditClick) end)
	M.edBtn:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, -4)
	M.roBtn = T.Button(p, "", 100, 18, function(b, m) M.Call("role", M.OnRoleClick, b, m) end)
	M.roBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -4)
	M.foot = T.Text(p, 10, T.c.dim, "LEFT")
	M.foot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 5)
	for i = 1, NLINE do
		local ln = CreateFrame("Button", nil, p)
		local y = -(HEAD_H + (i - 1) * ROW_H)
		ln:SetHeight(ROW_H)
		ln:SetPoint("TOPLEFT", p, "TOPLEFT", 6, y)
		ln:SetPoint("TOPRIGHT", p, "TOPRIGHT", -6, y)
		ln:EnableMouse(true)
		ln:EnableMouseWheel(true)
		ln:RegisterForClicks("LeftButtonUp")
		ln.bg = ln:CreateTexture(nil, "BACKGROUND")
		ln.bg:SetAllPoints(ln)
		ln.bg:SetTexture(T.tex.white)
		ln.value = T.Text(ln, 11, T.c.text, "RIGHT")
		ln.value:SetPoint("RIGHT", ln, "RIGHT", -4, 0)
		ln.label = T.Text(ln, 11, T.c.dim, "LEFT")
		ln.label:SetPoint("LEFT", ln, "LEFT", 4, 0)
		ln.label:SetPoint("RIGHT", ln.value, "LEFT", -6, 0)
		ln.label:SetHeight(ROW_H)
		ln:SetScript("OnEnter", function() M.Call("enter", M.RowEnter) end)
		ln:SetScript("OnLeave", function() M.Call("leave", M.RowLeave) end)
		ln:SetScript("OnClick", function() M.Call("click", M.LineClick, this) end)
		ln:SetScript("OnMouseWheel", function() M.Call("wheel", M.OnWheel, arg1) end)
		ln:Hide()
		M.lines[i] = ln
	end
	local btn = T.Button(par, "", 46, 16, function(b, m) M.Call("toggle", M.OnToggle) end)
	if type(lv) == "number" then btn:SetFrameLevel(lv + 6) end
	M.btn = btn
	-- engrenage : ouvre les reglages du module, a gauche du bouton "Stats" (parent = cadre du jeu, niveau recale a chaque ouverture)
	T.GearButton(par, "charstats", { size = 16, point = "TOPRIGHT", x = -114, y = -15, title = L("msg.charstats.gear"),
		onCreate = function(g)
			M.gearBtn = g
			g:ClearAllPoints()
			g:SetPoint("RIGHT", btn, "LEFT", -4, 0)
			if not M.on then g:Hide() end
		end })
	M.BuildTip()
	M.built = true
	M.LoadSel()
	T.OnAccent(function() M.layoutDirty = true M.dirty = true end)
	if not M.watching then
		M.watching = true
		C.Watch("charstats.", M.OnKey)
	end
	if M.on then M.Activate() end
	M.ApplyOptions()
	M.AttachVisibility()
end

-- Visibilite commune (charstats.vis / .fade) : le volet fond (opacite) ; refuse par la regle, il est cache aussi (il capte la souris).
function M.AttachVisibility()
	if not (SUI.Visibility and M.built) then return end
	SUI.Visibility.Add(M.panel, "charstats", { mode = "alpha", module = "charstats", alpha = 1, cat = "charstats",
		onChange = function(visible)
			M.visOK = visible and true or false
			if M.built then M.ApplyOptions() end
		end })
end

function M.DetachVisibility()
	if not (SUI.Visibility and M.panel) then return end
	M.visOK = true
	-- differe : la coupure arrive depuis un observateur de Config (Remove peut en detacher un pendant sa boucle) ; rallume entre-temps : rien
	SUI.After(0, function()
		if M.on then return end
		SUI.Visibility.Remove(M.panel)
	end, "charstats.visoff")
end

-- Construction protegee : une erreur de construction va au journal et reste lisible dans /sui stats diag.
function M.TryBuild()
	local ok, err = pcall(M.Build)
	if not ok then
		M.built = false
		M.buildErr = tostring(err)
		M.Fail("build", err)
	end
end

function M.OnShow()
	M.dirty = true
	M.Refresh()
end

-- ---------------------------------------------------------------- evenements, minuterie
function M.MarkDirty(ev, unit)
	if unit and unit ~= "player" and type(unit) == "string" then return end
	M.dirty = true
end

function M.MarkGear(ev, unit)
	if unit and unit ~= "player" then return end
	M.gearDirty = true
	M.dirty = true
end

function M.MarkTalents()
	M.talentDirty = true
	M.dirty = true
end

function M.Tick()
	if not M.dirty or not M.panel or not M.panel:IsVisible() then return end
	if not M.cfg.combat and SUI.InCombat() then return end
	M.Refresh()
end

function M.OnKey(key, value)
	M.ReadConfig()
	M.ApplyOptions()
end

M.EVENTS = { "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_DEFENSES", "UNIT_ATTACK", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
	"UNIT_ATTACK_SPEED", "UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_AURAS_CHANGED", "UNIT_LEVEL",
	"UNIT_MAXMANA", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER", "SKILL_LINES_CHANGED", "UPDATE_SHAPESHIFT_FORM" }

function M.Activate()
	if M.active or not M.built then return end
	M.active = true
	for i = 1, getn(M.EVENTS) do SUI.On(M.EVENTS[i], M.MarkDirty) end
	SUI.On("UNIT_INVENTORY_CHANGED", M.MarkGear)
	SUI.On("CHARACTER_POINTS_CHANGED", M.MarkTalents)
	SUI.On("SPELLS_CHANGED", M.MarkTalents)
	SUI.On("PLAYER_LEVEL_UP", M.MarkTalents)
	M.task = SUI.Every(TICK, M.Tick, "charstats.tick", true)
	M.gearDirty, M.talentDirty, M.dirty = true, true, true
end

function M.Deactivate()
	if not M.active then return end
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	for i = 1, getn(M.EVENTS) do SUI.Off(M.EVENTS[i], M.MarkDirty) end
	SUI.Off("UNIT_INVENTORY_CHANGED", M.MarkGear)
	SUI.Off("CHARACTER_POINTS_CHANGED", M.MarkTalents)
	SUI.Off("SPELLS_CHANGED", M.MarkTalents)
	SUI.Off("PLAYER_LEVEL_UP", M.MarkTalents)
end

function M.Enable()
	M.on = true
	M.ReadConfig()
	SUI.WhenSafe(M.TryBuild)
	M.Activate()
	M.ApplyOptions()
	M.AttachVisibility()       -- idempotent : repose le volet apres une coupure
end

function M.Disable()
	M.on = false
	M.Deactivate()
	M.DetachVisibility()
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- diagnostic (/sui stats diag)
local function yn(b)
	return b and L("msg.charstats.d_yes") or L("msg.charstats.d_no")
end

local function pos(f)
	local pt, rel, rp, x, y = f:GetPoint(1)
	if not pt then return "-" end
	return tostring(pt) .. "/" .. tostring(rp) .. " " .. int(tonumber(x) or 0) .. "," .. int(tonumber(y) or 0)
end

function M.Diag()
	local out = {}
	local mod = SUI.modules.charstats
	local held = SUI.Migrate and SUI.Migrate.Held and SUI.Migrate.Held("charstats")
	out[1] = L("msg.charstats.d_module", yn(mod and mod.enabled), yn(C.Get("modules.charstats")), tostring(C.mode), yn(held))
	local cf = getglobal("CharacterFrame")
	out[2] = L("msg.charstats.d_frame", yn(cf), yn(M.built), M.par and tostring(M.par:GetName()) or "-")
	if M.built then
		local p = M.panel
		out[3] = L("msg.charstats.d_panel", yn(p:IsShown()), yn(p:IsVisible()), int(p:GetWidth() or 0) .. "x" .. int(p:GetHeight() or 0))
		out[4] = L("msg.charstats.d_pos", pos(p), yn(M.btn:IsShown()), yn(C.Get("charstats.show")))
		out[5] = L("msg.charstats.d_rows", M.ne, M.nv, yn(M.edit))
	end
	out[getn(out) + 1] = L("msg.charstats.d_err", M.buildErr or M.lastErr or L("msg.charstats.d_none"))
	return out
end

function M.PrintDiag()
	local o = M.Diag()
	for i = 1, getn(o) do SUI.Print(o[i]) end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("charstats", 43)

local function opt(key, typ, order, def, extra)
	local o = { key = "charstats." .. key, type = typ, cat = "charstats", label = "opt.charstats." .. key, tip = "tip.charstats." .. key,
		default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local CS_OPTIONS = {
		opt("show", "bool", 10, true, { simple = true }),
		opt("side", "choice", 20, "right", { choices = { "right", "left" } }),
		opt("width", "number", 25, 290, { min = 240, max = 360, step = 10 }),
		opt("dec", "number", 35, 2, { min = 0, max = 2, step = 1 }),
		opt("combat", "bool", 40, true),
}
-- Option commune du socle : visibilite conditionnelle (charstats.vis / .fade).
if SUI.Visibility then
	local vo = SUI.Visibility.Options("charstats", { cat = "charstats", order = 800 })
	for i = 1, getn(vo) do table.insert(CS_OPTIONS, vo[i]) end
end

SUI.RegisterModule("charstats", {
	default = true,
	cost = "medium",
	options = CS_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Mode Raid : seule la mise a jour pendant les combats est coupee. Le volet RESTE affiche (le cacher en Raid faisait croire a un
-- module qui ne marche pas : il ne coute rien tant que la fenetre du personnage est fermee).
SUI.Config.AddPreset("raid", "*", { ["charstats.combat"] = false })

local function trimWord(s)
	return gsub(gsub(s, "^%s+", ""), "%s+$", "")
end

local function cmdStats(rest)
	rest = trimWord(rest or "")
	local _, _, w1, w2 = strfind(rest, "^(%a+)%s*(.*)$")
	if w1 == "diag" then
		M.PrintDiag()
	elseif w1 == "on" then
		C.Set("modules.charstats", true)
		C.Set("charstats.show", true)
		SUI.Print(L("msg.charstats.turned_on"))
		M.PrintDiag()
	elseif w1 == "list" then
		if not M.built then SUI.Print(L("msg.charstats.notready")) return end
		M.dirty = true
		local ok = pcall(M.Compute)
		if not ok then SUI.Print(L("msg.charstats.notready")) return end
		local e = M.edit
		M.edit = false
		M.BuildEntries()
		M.edit = e
		for i = 1, M.ne do
			if M.ek[i] == "H" then
				SUI.Print(L(M.PANELKEY[M.ep[i]]))
			else
				local k = M.ekey[i]
				SUI.Print("  " .. M.Label(k) .. " : " .. M.Value(k))
			end
		end
	elseif w1 == "scan" then
		M.gearDirty, M.talentDirty, M.dirty = true, true, true
		SUI.Print(L("msg.charstats.rescan"))
	elseif w1 == "role" then
		if M.built and M.SetRole(w2) then SUI.Print(L("msg.charstats.role", L(M.ROLEKEY[w2]))) else SUI.Print(L("msg.charstats.badarg")) end
	elseif w1 == "section" then
		if M.built and M.ToggleSection(w2) then SUI.Print(L(M.PANELKEY[w2]) .. " : " .. yn(M.sel.sec[w2])) else SUI.Print(L("msg.charstats.badarg")) end
	elseif w1 == "reset" then
		if M.built then M.SetRole("auto") SUI.Print(L("msg.charstats.role", L(M.ROLEKEY.auto))) else SUI.Print(L("msg.charstats.notready")) end
	else
		local mod = SUI.modules.charstats
		if not (mod and mod.enabled and M.built) then
			SUI.Print(L("msg.charstats.notready"))
			M.PrintDiag()
			SUI.Print(L("msg.charstats.hint_on"))
			return
		end
		C.Set("charstats.show", not C.Get("charstats.show"))
		SUI.Print(L(C.Get("charstats.show") and "msg.charstats.state_on" or "msg.charstats.state_off"))
		if not (M.par and M.par:IsVisible()) then SUI.Print(L("msg.charstats.open_char")) end
	end
end

SUI.RegisterCommand("stats", cmdStats, "help.charstats")
SUI.RegisterCommand("charstats", cmdStats)
