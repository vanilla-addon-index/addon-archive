-- ShikiUI GroupFx : MOTEUR (sans cadre) des effets de boss et de l'aggro pour les cadres groupe / raid (Mod_Group, Mod_Raid).
-- Ce module ne dessine rien : il expose une API stable que les cadres lisent et se redessine via un callback.
--   SUI.GroupFx.Effects(unit)  -> liste, n : effets de boss presents sur 'unit' (Living Bomb, Burning Adrenaline, maledictions...).
--        liste REUTILISEE (ne pas la garder, ne pas l'ecrire) ; n = nombre valide ; chaque element :
--        { key, texture, name, left, kind, color (nom de jeton), prio, boss } ; left = secondes restantes (0 = inconnu).
--   SUI.GroupFx.Aggro(unit)    -> etat, role, source : etat 'none' | 'tank' | 'offrole' (aggro sur un non-tank = alerte),
--        role 'tank' | 'heal' | 'dps' | 'caster', source 'target' (cible du boss) | 'threat' (TWThreat) | 'both'.
--   SUI.GroupFx.OnChange(fn)   -> fn(unit, what) appele quand l'etat d'une unite change (what = 'fx' ou 'aggro') : les cadres
--        redessinent ce cadre-la, sans OnUpdate maison. SUI.GroupFx.OffChange(fn) le retire.
--   SUI.GroupFx.Want(nom)      -> bool : reglages d'affichage pour les cadres ('icon', 'tint', 'timer', 'aggroframe', 'aggroicon', 'aggrotank').
--   SUI.GroupFx.Color(rec)     -> r, g, b d'un effet (jeton du style, suit le changement de style). SUI.GroupFx.Sample(i) -> effet fictif (apercu).
-- Donnees : M.BOSSFX (cle -> { names = {EN, FR...}, tex = icone de reference, boss, color, prio, sound, kind, dur }) + noms ajoutes par
-- l'utilisateur (/sui groupfx add [buff] <nom>) ; M.AddEffect(cle, def) pour en ajouter par code.
-- Lecture des effets : UnitDebuff / UnitBuff pour la texture, infobulle cachee (SetUnitDebuff / SetUnitBuff) pour le NOM, seulement
-- quand la texture d'une ligne change ; duree : GetPlayerBuffTimeLeft sur soi, sinon duree des donnees depuis l'apparition.
-- Aggro : cible du boss (UnitIsUnit(boss.."target", unite)) et / ou menace TWThreat (SUI.Threat.holder) ; role : liste de tanks,
-- roles de Mod_Group, buffs de tank (Fureur vertueuse, forme d'ours), puis classe.
-- NON VERIFIE EN JEU : tout (noms FR, icones de reference, UNIT_AURA sur raidN, GetPlayerBuff(i, "HARMFUL"), sons). Defaut coupe.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local slower, sfind, ssub, sgsub, slen = string.lower, string.find, string.sub, string.gsub, string.len

local M = {}
SUI.GroupFx = M

M.on = false
M.EMPTY = {}
M.MAXFX = 4               -- effets gardes par unite (au plus)
M.MAXMOB = 8              -- ennemis distincts etudies par tour d'aggro
M.GAP = 1.5               -- secondes entre deux sons
M.FULLSCAN = 4            -- secondes entre deux relectures completes (filet de securite si un UNIT_AURA a ete manque)
M.cfg = { fxon = true, icon = true, tint = true, timer = true, maxper = 2, sound = "auto", soundwho = "self", msg = "screen",
	mode = "target", filter = "boss", aggroframe = true, aggroicon = true, aggrotank = false, asound = "raid", asoundwho = "self",
	amsg = "screen", amsgwho = "self", rheal = true, rcaster = true, rdps = true, guess = true, tick = 0.5 }

-- ---------------------------------------------------------------- sons (liste de sons du jeu ; "auto" = celui de l'effet)
M.SOUNDLIST = { "none", "auto", "raid", "alarm", "ping", "tell", "level", "quest" }
M.SOUNDFILE = { raid = "Sound\\Interface\\RaidWarning.wav", alarm = "Sound\\Interface\\AlarmClockWarning3.wav" }
M.SOUNDNAME = { ping = "MapPing", tell = "TellMessage", level = "LEVELUP", quest = "QUESTADDED" }

-- ---------------------------------------------------------------- donnees : effets de boss
-- names : noms EN puis FR (compares sans casse ni accents) ; tex : icone de reference (la vraie texture est lue sur l'unite) ;
-- kind : "debuff" (defaut) | "buff" ; dur : duree connue (secondes) pour le minuteur sur les autres joueurs ; color : jeton T.c.* ;
-- prio : plus grand = affiche d'abord ; sound : son choisi quand fx.sound = "auto".
M.BOSSFX = {
	livingbomb = { names = { "Living Bomb", "Bombe vivante" }, tex = "Spell_Fire_SelfDestruct", boss = "Baron Geddon", color = "bad", prio = 10, sound = "alarm", dur = 8 },
	burningadrenaline = { names = { "Burning Adrenaline", "Adrenaline brulante" }, tex = "Spell_Shadow_ShadowWordDominate", boss = "Vaelastrasz", color = "bad", prio = 10, sound = "alarm", dur = 20 },
	panic = { names = { "Panic", "Panique" }, tex = "Spell_Shadow_PsychicScream", boss = "Magmadar", color = "warn", prio = 6, sound = "raid", dur = 8 },
	luciferoncurse = { names = { "Lucifron's Curse", "Malediction de Lucifron" }, tex = "Spell_Shadow_BlackPlague", boss = "Lucifron", color = "warn", prio = 7, sound = "tell", dur = 300 },
	impendingdoom = { names = { "Impending Doom", "Mort imminente" }, tex = "Spell_Shadow_NightOfTheDead", boss = "Lucifron", color = "warn", prio = 6, sound = "tell", dur = 10 },
	gehennascurse = { names = { "Gehennas' Curse", "Malediction de Gehennas" }, tex = "Spell_Shadow_GatherShadows", boss = "Gehennas", color = "warn", prio = 7, sound = "tell", dur = 300 },
	rainoffire = { names = { "Rain of Fire", "Pluie de feu" }, tex = "Spell_Shadow_RainOfFire", boss = "Gehennas", color = "warn", prio = 5, sound = "ping", dur = 6 },
	magmashackles = { names = { "Magma Shackles", "Entraves de magma" }, tex = "Spell_Fire_Fireball", boss = "Garr", color = "warn", prio = 5, sound = "ping", dur = 10 },
	magmasplash = { names = { "Magma Splash", "Eclaboussure de magma" }, tex = "Spell_Fire_Immolation", boss = "Golemagg", color = "warn", prio = 6, sound = "ping", dur = 20 },
	handofragnaros = { names = { "Hand of Ragnaros", "Main de Ragnaros" }, tex = "Spell_Fire_Fireball02", boss = "Sulfuron", color = "warn", prio = 4, sound = "ping", dur = 6 },
	elementalfire = { names = { "Elemental Fire", "Feu elementaire" }, tex = "Spell_Fire_Fire", boss = "Ragnaros", color = "bad", prio = 8, sound = "alarm", dur = 8 },
	wrathofragnaros = { names = { "Wrath of Ragnaros", "Colere de Ragnaros" }, tex = "Spell_Fire_Volcano", boss = "Ragnaros", color = "warn", prio = 4, sound = "ping", dur = 4 },
	conflagration = { names = { "Conflagration" }, tex = "Spell_Fire_Incinerate", boss = "Razorgore", color = "bad", prio = 8, sound = "alarm", dur = 10 },
	broodbronze = { names = { "Brood Affliction: Bronze", "Affliction de la couvee : bronze" }, tex = "INV_Misc_Head_Dragon_Bronze", boss = "Chromaggus", color = "bad", prio = 9, sound = "alarm", dur = 600 },
	broodaffliction = { names = { "Brood Affliction: Blue", "Brood Affliction: Red", "Brood Affliction: Black", "Brood Affliction: Green",
		"Affliction de la couvee : bleu", "Affliction de la couvee : rouge", "Affliction de la couvee : noir", "Affliction de la couvee : vert" },
		tex = "INV_Misc_Head_Dragon_01", boss = "Chromaggus", color = "warn", prio = 7, sound = "tell", dur = 600 },
	timelapse = { names = { "Time Lapse", "Distorsion temporelle" }, tex = "Spell_Arcane_PortalOrgrimmar", boss = "Chromaggus", color = "bad", prio = 9, sound = "alarm", dur = 6 },
	shadowofebonroc = { names = { "Shadow of Ebonroc", "Ombre d'Ebonroc" }, tex = "Spell_Shadow_GatherShadows", boss = "Ebonroc", color = "warn", prio = 8, sound = "tell", dur = 8 },
	brood_mortalstrike = { names = { "Mortal Strike", "Frappe mortelle" }, tex = "Ability_Warrior_SavageBlow", boss = "Broodlord", color = "warn", prio = 6, sound = "ping", dur = 5 },
	veilofshadow = { names = { "Veil of Shadow", "Voile d'ombre" }, tex = "Spell_Shadow_GatherShadows", boss = "Nefarian", color = "bad", prio = 8, sound = "alarm", dur = 6 },
	shadowcommand = { names = { "Shadow Command", "Commandement de l'ombre" }, tex = "Spell_Shadow_Charm", boss = "Nefarian", color = "bad", prio = 9, sound = "alarm", dur = 8 },
	noxiouspoison = { names = { "Noxious Poison", "Poison nocif" }, tex = "Ability_Creature_Poison_05", boss = "Huhuran", color = "good", prio = 8, sound = "tell", dur = 15 },
	acidspit = { names = { "Acid Spit", "Crachat d'acide" }, tex = "Spell_Nature_Acid_01", boss = "Huhuran", color = "warn", prio = 5, sound = "ping", dur = 30 },
	poisonvolley = { names = { "Poison Bolt Volley", "Salve de traits de poison" }, tex = "Spell_Nature_CorrosiveBreath", boss = "Viscidus", color = "good", prio = 7, sound = "tell", dur = 10 },
	digestiveacid = { names = { "Digestive Acid", "Acide digestif" }, tex = "Spell_Nature_Acid_01", boss = "C'Thun", color = "bad", prio = 8, sound = "alarm", dur = 20 },
	mortalwound = { names = { "Mortal Wound", "Blessure mortelle" }, tex = "Ability_CriticalStrike", boss = "Fankriss", color = "warn", prio = 7, sound = "tell", dur = 15 },
	truefulfillment = { names = { "True Fulfillment", "Accomplissement veritable" }, tex = "Spell_Shadow_Charm", boss = "Skeram", color = "bad", prio = 10, sound = "alarm", dur = 20 },
}
-- Ordre stable (pairs n'en a pas) : sert aux options, a l'index et aux commandes.
M.ORDER = { "livingbomb", "burningadrenaline", "panic", "luciferoncurse", "impendingdoom", "gehennascurse", "rainoffire", "magmashackles",
	"magmasplash", "handofragnaros", "elementalfire", "wrathofragnaros", "conflagration", "broodbronze", "broodaffliction", "timelapse",
	"shadowofebonroc", "brood_mortalstrike", "veilofshadow", "shadowcommand", "noxiouspoison", "acidspit", "poisonvolley", "digestiveacid",
	"mortalwound", "truefulfillment" }

-- Ajoute (ou remplace) un effet par code : M.AddEffect("cle", { names = { "Nom" }, ... }). Le nom de cle est libre ([a-z0-9_]).
function M.AddEffect(key, def)
	if type(key) ~= "string" or type(def) ~= "table" or not def.names then return false end
	if not M.BOSSFX[key] then tinsert(M.ORDER, key) end
	M.BOSSFX[key] = def
	M.Reindex()
	return true
end

-- ---------------------------------------------------------------- etat reutilise (rien n'est cree en combat)
M.UNITS = { "player" }
for i = 1, 4 do M.UNITS[i + 1] = "party" .. i end
for i = 1, 40 do M.UNITS[i + 5] = "raid" .. i end
M.BT, M.TT = {}, {}                     -- jeton -> jeton.."target" / jeton.."targettarget"
for i = 1, getn(M.UNITS) do
	local u = M.UNITS[i]
	M.BT[u] = u .. "target"
	M.TT[u .. "target"] = u .. "targettarget"
end
M.TT["target"] = "targettarget"
M.MOBS = { "target" }                    -- ennemis candidats : ta cible puis la cible de chaque membre actif
M.act, M.nact = {}, 0                   -- membres actifs (groupe ou raid), remplis par M.Roster
M.ST = {}                               -- jeton -> { dtex, dname, dn, btex, bname, bn } : derniere lecture des auras
M.FXL, M.FXN, M.POOL = {}, {}, {}       -- jeton -> liste publique, nombre, enregistrements reutilisables
M.AG = {}                               -- jeton -> { state, role, src, mob, fT, fH, roleFor, roleUntil, alertAt }
M.callbacks = {}
M.byName, M.byTex = {}, {}
M.entries = {}                          -- entrees actives : { key, def, names (pliees), custom }
M.custom = {}                           -- entrees ajoutees par l'utilisateur (reconstruites depuis groupfx.custom)
M.off = {}                              -- cle -> true : effet masque par reglage
M.tankset = {}                          -- noms (plies) de tanks declares
M.seen = {}
M.sc = { e = {}, tex = {}, nm = {}, slot = {}, until0 = {}, isnew = {}, n = 0 }   -- brouillon d'un tour de lecture
M.lastSound, M.lastFull, M.hasBuffFx = -100, 0, false

local function newState()
	return { dtex = {}, dname = {}, dn = 0, btex = {}, bname = {}, bn = 0 }
end

function M.Prime()
	for i = 1, getn(M.UNITS) do
		local u = M.UNITS[i]
		if not M.ST[u] then
			M.ST[u] = newState()
			M.FXL[u], M.FXN[u] = {}, 0
			local pool = {}
			for j = 1, M.MAXFX do
				pool[j] = { key = "", texture = "", name = "", left = 0, kind = "debuff", color = "bad", prio = 0, boss = "", untilT = 0, entry = false }
			end
			M.POOL[u] = pool
			M.AG[u] = { state = "none", role = false, role2 = false, src = false, mob = "", fT = false, fH = false, roleFor = "", roleUntil = 0, alertAt = -100 }
		end
	end
end

-- ---------------------------------------------------------------- textes : pliage (minuscules sans accents)
local ACC = { { "\195\169", "e" }, { "\195\168", "e" }, { "\195\170", "e" }, { "\195\171", "e" }, { "\195\160", "a" }, { "\195\162", "a" },
	{ "\195\180", "o" }, { "\195\174", "i" }, { "\195\175", "i" }, { "\195\187", "u" }, { "\195\185", "u" }, { "\195\167", "c" },
	{ "\195\137", "e" }, { "\195\136", "e" }, { "\195\128", "a" }, { "\226\128\153", "'" } }

function M.Fold(s)
	if type(s) ~= "string" then return "" end
	s = slower(s)
	for i = 1, getn(ACC) do s = sgsub(s, ACC[i][1], ACC[i][2]) end
	return s
end

local function trim(s)
	s = sgsub(s, "^%s+", "")
	s = sgsub(s, "%s+$", "")
	return s
end

-- Decoupe 's' sur 'sep' (un caractere) dans 'out' (liste videe d'abord) ; retourne le nombre d'elements non vides.
function M.Split(s, sep, out)
	for i = getn(out), 1, -1 do out[i] = nil end
	local n, pos = 0, 1
	s = s or ""
	while pos <= slen(s) + 1 do
		local a = sfind(s, sep, pos, true)
		local piece
		if a then piece = ssub(s, pos, a - 1) pos = a + 1 else piece = ssub(s, pos) pos = slen(s) + 2 end
		piece = trim(piece)
		if piece ~= "" then n = n + 1 out[n] = piece end
	end
	return n
end

-- ---------------------------------------------------------------- index des noms (reconstruit quand les donnees ou les reglages changent)
function M.Reindex()
	for k in pairs(M.byName) do M.byName[k] = nil end
	for k in pairs(M.byTex) do M.byTex[k] = nil end
	for i = getn(M.entries), 1, -1 do M.entries[i] = nil end
	M.hasBuffFx = false
	local function add(key, def, custom)
		if M.off[key] then return end
		local ent = { key = key, def = def, custom = custom }
		tinsert(M.entries, ent)
		if def.kind == "buff" then M.hasBuffFx = true end
		for j = 1, getn(def.names) do M.byName[M.Fold(def.names[j])] = ent end
		if def.tex and not custom then M.byTex[slower("interface\\icons\\" .. def.tex)] = ent end
	end
	for i = 1, getn(M.ORDER) do
		local k = M.ORDER[i]
		if M.BOSSFX[k] then add(k, M.BOSSFX[k], false) end
	end
	for i = 1, getn(M.custom) do add(M.custom[i].key, M.custom[i], true) end
end

-- Lit "groupfx.custom" : "Nom;+Nom d'un buff;Autre" -> M.custom (entrees { key, names, kind, color, prio, dur }).
function M.ParseCustom()
	local parts, n = {}, 0
	n = M.Split(C.Get("groupfx.custom") or "", ";", parts)
	for i = getn(M.custom), 1, -1 do M.custom[i] = nil end
	for i = 1, n do
		local p, kind = parts[i], "debuff"
		if ssub(p, 1, 1) == "+" then kind = "buff" p = trim(ssub(p, 2)) end
		if p ~= "" then
			M.custom[getn(M.custom) + 1] = { key = "c" .. i, names = { p }, kind = kind, color = "warn", prio = 5, sound = "ping", dur = 0, boss = "", tex = nil }
		end
	end
end

-- ---------------------------------------------------------------- lecture des reglages
function M.ReadConfig()
	local c = M.cfg
	c.fxon = C.Get("groupfx.fx.on") ~= false
	c.icon = C.Get("groupfx.fx.icon") ~= false
	c.tint = C.Get("groupfx.fx.tint") ~= false
	c.timer = C.Get("groupfx.fx.timer") ~= false
	c.maxper = C.Get("groupfx.fx.max") or 2
	if c.maxper > M.MAXFX then c.maxper = M.MAXFX end
	c.sound = C.Get("groupfx.fx.sound") or "auto"
	c.soundwho = C.Get("groupfx.fx.soundwho") or "self"
	c.msg = C.Get("groupfx.fx.msgself") or "screen"
	c.mode = C.Get("groupfx.aggromode") or "target"
	c.filter = C.Get("groupfx.aggrofilter") or "boss"
	c.aggroframe = C.Get("groupfx.aggro.frame") ~= false
	c.aggroicon = C.Get("groupfx.aggro.icon") ~= false
	c.aggrotank = C.Get("groupfx.aggro.tank") == true
	c.asound = C.Get("groupfx.aggro.sound") or "raid"
	c.asoundwho = C.Get("groupfx.aggro.soundwho") or "self"
	c.amsg = C.Get("groupfx.aggro.msg") or "screen"
	c.amsgwho = C.Get("groupfx.aggro.msgwho") or "self"
	c.rheal = C.Get("groupfx.aggro.heal") ~= false
	c.rcaster = C.Get("groupfx.aggro.caster") ~= false
	c.rdps = C.Get("groupfx.aggro.dps") ~= false
	c.guess = C.Get("groupfx.roleguess") ~= false
	c.tick = C.Get("groupfx.tick") or 0.5
	for i = 1, getn(M.ORDER) do
		local k = M.ORDER[i]
		M.off[k] = C.Get("groupfx.off." .. k) == true or nil
	end
	local tl, n = {}, 0
	for k in pairs(M.tankset) do M.tankset[k] = nil end
	n = M.Split(C.Get("groupfx.tanks") or "", ",", tl)
	for i = 1, n do M.tankset[M.Fold(tl[i])] = true end
	M.ParseCustom()
	M.Reindex()
end

function M.Want(what)
	local c = M.cfg
	if not M.on then return false end
	if what == "icon" then return c.fxon and c.icon end
	if what == "tint" then return c.fxon and c.tint end
	if what == "timer" then return c.fxon and c.timer end
	if what == "aggroframe" then return c.mode ~= "off" and c.aggroframe end
	if what == "aggroicon" then return c.mode ~= "off" and c.aggroicon end
	if what == "aggrotank" then return c.mode ~= "off" and c.aggrotank end
	return false
end

function M.Color(rec)
	local tok = rec and rec.color or "bad"
	if tok == "accent" then return T.Accent() end
	local col = T.c[tok] or T.c.bad
	return col[1], col[2], col[3]
end

-- Effet fictif pour un apercu de menu (i = 1..n ; aucune allocation : renvoie les memes tables).
M.samples = {}
function M.Sample(i)
	local k = M.ORDER[i or 1]
	local def = k and M.BOSSFX[k]
	if not def then return nil end
	local s = M.samples[k]
	if not s then
		s = { key = k, texture = "Interface\\Icons\\" .. (def.tex or "INV_Misc_QuestionMark"), name = def.names[1], left = def.dur and def.dur > 0 and def.dur or 0,
			kind = def.kind or "debuff", color = def.color or "bad", prio = def.prio or 0, boss = def.boss or "" }
		M.samples[k] = s
	end
	return s
end

-- ---------------------------------------------------------------- callbacks
function M.OnChange(fn)
	if type(fn) ~= "function" then return false end
	for i = 1, getn(M.callbacks) do
		if M.callbacks[i] == fn then return false end
	end
	tinsert(M.callbacks, fn)
	return true
end

function M.OffChange(fn)
	for i = getn(M.callbacks), 1, -1 do
		if M.callbacks[i] == fn then table.remove(M.callbacks, i) return true end
	end
	return false
end

function M.Notify(unit, what)
	for i = 1, getn(M.callbacks) do
		local ok, err = pcall(M.callbacks[i], unit, what)
		if not ok then SUI.Report("groupfx", err) end
	end
end

-- ---------------------------------------------------------------- identite
function M.IsSelf(u)
	if u == "player" then return true end
	if UnitIsUnit and UnitIsUnit(u, "player") then return true end
	return false
end

-- ---------------------------------------------------------------- sons et messages
function M.Play(name, entrySound)
	if name == "none" or not name then return end
	if name == "auto" then name = entrySound or "raid" end
	local now = GetTime()
	if now - M.lastSound < M.GAP then return end
	M.lastSound = now
	local file = M.SOUNDFILE[name]
	if file then
		local pf = getglobal("PlaySoundFile")
		if pf then pf(file) end
	elseif M.SOUNDNAME[name] then
		local p = getglobal("PlaySound")
		if p then p(M.SOUNDNAME[name]) end
	end
end

function M.Say(mode, text, tok)
	if mode == "none" or not text then return end
	if mode == "chat" or mode == "both" then SUI.Print(text) end
	if mode == "screen" or mode == "both" then
		local f = getglobal("UIErrorsFrame")
		if f and f.AddMessage then
			local col = T.c[tok or "bad"] or T.c.bad
			f:AddMessage(text, col[1], col[2], col[3], 1, 2)
		end
	end
end

-- ---------------------------------------------------------------- effets : lecture d'une unite
local tipFrame

local function ensureTip()
	if tipFrame then return tipFrame end
	local ex = getglobal("ShikiUI_GFXTip")
	if ex then tipFrame = ex return tipFrame end
	if SUI.InCombat() then return nil end
	local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_GFXTip", UIParent, "GameTooltipTemplate")
	if ok and t then
		t:SetOwner(UIParent, "ANCHOR_NONE")
		tipFrame = t
	end
	return tipFrame
end

-- Nom plie du buff / debuff 'i' de 'u' ("" si l'infobulle est indisponible).
local function readName(u, i, buff)
	local tip = tipFrame or ensureTip()
	if not tip then return "" end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	if buff then tip:SetUnitBuff(u, i) else tip:SetUnitDebuff(u, i) end
	local fs = getglobal("ShikiUI_GFXTipTextLeft1")
	local t = fs and fs:GetText()
	if not t then return "" end
	return M.Fold(t)
end

local function lookup(name, tex)
	local e
	if name and name ~= "" then e = M.byName[name]
	elseif tex then e = M.byTex[slower(tex)] end
	return e
end

-- Ajoute un effet au brouillon, trie par priorite (au plus maxper gardes).
local function putFx(ent, tex, name, slot)
	local sc = M.sc
	local k = sc.n
	local cap = M.cfg.maxper
	for j = 1, k do
		if sc.e[j] == ent then return end
	end
	local p = ent.def.prio or 0
	local at = k + 1
	for j = 1, k do
		if p > (sc.e[j].def.prio or 0) then at = j break end
	end
	if at > cap then return end
	if k >= cap then k = cap - 1 end
	for j = k, at, -1 do
		sc.e[j + 1], sc.tex[j + 1], sc.nm[j + 1], sc.slot[j + 1] = sc.e[j], sc.tex[j], sc.nm[j], sc.slot[j]
	end
	sc.e[at], sc.tex[at], sc.nm[at], sc.slot[at] = ent, tex, name, slot
	sc.n = k + 1
end

-- Remplit le brouillon avec les effets trouves dans les lignes lues.
local function collect(st, sc)
	sc.n = 0
	for i = 1, st.dn do
		local e = lookup(st.dname[i], st.dtex[i])
		if e and e.def.kind ~= "buff" then putFx(e, st.dtex[i], st.dname[i], i) end
	end
	if M.hasBuffFx then
		for i = 1, st.bn do
			local e = lookup(st.bname[i], st.btex[i])
			if e and e.def.kind == "buff" then putFx(e, st.btex[i], st.bname[i], -i) end
		end
	end
end

-- Compare le brouillon a la liste publique ; ecrit seulement si ca change. alert : jouer son / message pour les nouveaux.
function M.Rematch(u, alert)
	local st, sc = M.ST[u], M.sc
	if not st then return end
	local now = GetTime()
	collect(st, sc)
	local list, pool, n = M.FXL[u], M.POOL[u], M.FXN[u]
	local same = (sc.n == n)
	if same then
		for i = 1, n do
			if list[i].entry ~= sc.e[i] or list[i].texture ~= sc.tex[i] then same = false break end
		end
	end
	if same then return end
	-- fin de vie connue des effets deja presents (a conserver), avant de reecrire les enregistrements
	for i = 1, sc.n do
		sc.isnew[i], sc.until0[i] = true, 0
		for j = 1, n do
			if list[j].entry == sc.e[i] then sc.isnew[i], sc.until0[i] = false, list[j].untilT break end
		end
	end
	for i = n, 1, -1 do list[i] = nil end
	local me = M.IsSelf(u)
	local gpbt = getglobal("GetPlayerBuffTimeLeft")
	local gpb = getglobal("GetPlayerBuff")
	for i = 1, sc.n do
		local r, ent = pool[i], sc.e[i]
		local def = ent.def
		r.key, r.texture, r.name, r.kind = ent.key, sc.tex[i], def.names[1], def.kind or "debuff"
		r.color, r.prio, r.boss, r.entry = def.color or "bad", def.prio or 0, def.boss or "", ent
		local ut = sc.until0[i]
		if sc.isnew[i] then
			ut = (def.dur and def.dur > 0) and (now + def.dur) or 0
			if me and gpb and gpbt and sc.slot[i] > 0 then
				local idx = gpb(sc.slot[i] - 1, "HARMFUL")
				if idx and idx >= 0 then
					local tl = gpbt(idx)
					if tl and tl > 0 then ut = now + tl end
				end
			end
		end
		r.untilT = ut
		r.left = ut > 0 and (ut - now) or 0
		list[i] = r
	end
	M.FXN[u] = sc.n
	M.Notify(u, "fx")
	if alert then
		for i = 1, sc.n do
			if sc.isnew[i] then M.FxAlert(u, list[i], sc.e[i].def, me) end
		end
	end
end

function M.FxAlert(u, rec, def, me)
	local c = M.cfg
	if c.sound ~= "none" and (me or c.soundwho == "all") then M.Play(c.sound, def.sound) end
	if me and c.msg ~= "none" then M.Say(c.msg, L("msg.groupfx.fxself", rec.name), rec.color) end
end

-- Relit les auras de 'u' ; les infobulles ne servent que pour les lignes dont la texture a change.
function M.Scan(u, alert)
	local st = M.ST[u]
	if not st or not M.on then return end
	local changed = false
	local n = 0
	for i = 1, 16 do
		local t = UnitDebuff(u, i)
		if not t then break end
		n = i
		if t ~= st.dtex[i] then
			st.dtex[i] = t
			st.dname[i] = readName(u, i, false)
			changed = true
		end
	end
	if n ~= st.dn then
		for j = n + 1, st.dn do st.dtex[j], st.dname[j] = nil, nil end
		st.dn = n
		changed = true
	end
	if M.hasBuffFx then
		n = 0
		for i = 1, 32 do
			local t = UnitBuff(u, i)
			if not t then break end
			n = i
			if t ~= st.btex[i] then
				st.btex[i] = t
				st.bname[i] = readName(u, i, true)
				changed = true
			end
		end
		if n ~= st.bn then
			for j = n + 1, st.bn do st.btex[j], st.bname[j] = nil, nil end
			st.bn = n
			changed = true
		end
	end
	if changed or M.forceMatch then M.Rematch(u, alert) end
end

function M.Effects(unit)
	local l = M.FXL[unit]
	if not l or not M.on or not M.cfg.fxon then return M.EMPTY, 0 end
	local n = M.FXN[unit]
	if n > 0 then
		local now = GetTime()
		for i = 1, n do
			local r = l[i]
			if r.untilT > 0 then
				local x = r.untilT - now
				r.left = x > 0 and x or 0
			end
		end
	end
	return l, n
end

-- ---------------------------------------------------------------- roles
local TANKTEX = { "defensivestance", "sealoffury", "bearform", "racial_bear", "ability_racial_bearform" }
local GUESS = { WARRIOR = "tank", PRIEST = "heal", MAGE = "caster", WARLOCK = "caster", PALADIN = "heal", DRUID = "heal", SHAMAN = "heal",
	HUNTER = "dps", ROGUE = "dps" }

local function groupRole(name)
	local g = SUI.Group and SUI.Group.party
	local r = g and g.roles and g.roles[name]
	if r then return r end
	local rg = SUI.Raid and SUI.Raid.g
	return rg and rg.roles and rg.roles[name] or nil
end

local function hasTankBuff(u)
	for i = 1, 32 do
		local t = UnitBuff(u, i)
		if not t then return false end
		local lt = slower(t)
		for j = 1, getn(TANKTEX) do
			if sfind(lt, TANKTEX[j], 1, true) then return true end
		end
	end
	return false
end

-- Role de 'u' : liste de tanks > role manuel de Mod_Group > buffs de tank > classe (si roleguess). Garde 5 s en memoire.
function M.RoleOf(u, a, now)
	local name = UnitName(u) or ""
	if a.roleFor == name and now < a.roleUntil then return a.role end
	local _, cls = UnitClass(u)
	local role
	if M.tankset[M.Fold(name)] then
		role = "tank"
	else
		local gr = groupRole(name)
		if gr == "T" then role = "tank"
		elseif gr == "H" then role = "heal"
		elseif gr == "D" then role = (cls == "MAGE" or cls == "WARLOCK") and "caster" or "dps" end
	end
	if not role then
		if M.cfg.guess then
			if hasTankBuff(u) then
				role = "tank"
			else
				role = GUESS[cls] or "dps"
			end
		else
			role = "dps"
		end
	end
	a.role, a.roleFor, a.roleUntil = role, name, now + 5
	return role
end

local function roleAlerts(role)
	local c = M.cfg
	if role == "heal" then return c.rheal end
	if role == "caster" then return c.rcaster end
	return c.rdps
end

-- ---------------------------------------------------------------- aggro
local function bossOk(m, filter)
	if filter == "any" then return true end
	local cl = UnitClassification and UnitClassification(m) or "normal"
	if filter == "elite" then return cl ~= "normal" and cl ~= "rare" end
	return cl == "worldboss" or UnitLevel(m) == -1
end

local function considerMob(m)
	if not UnitExists(m) or not UnitCanAttack("player", m) or UnitIsDeadOrGhost(m) then return end
	if not bossOk(m, M.cfg.filter) then return end
	local name = UnitName(m) or ""
	local seen = M.seen
	for i = 1, M.nseen do
		if seen[i] == name then return end
	end
	if M.nseen >= M.MAXMOB then return end
	M.nseen = M.nseen + 1
	seen[M.nseen] = name
	local mt = M.TT[m]
	if not mt or not UnitExists(mt) then return end
	for i = 1, M.nact do
		local u = M.act[i]
		if UnitIsUnit(mt, u) then
			local a = M.AG[u]
			a.fT, a.mob = true, name
			return
		end
	end
end

local function scanThreat()
	local mod = SUI.modules and SUI.modules.threat
	local th = SUI.Threat
	if not mod or not mod.enabled or not th then return end
	local h = th.holder
	local hn = h and h.name
	if not hn or hn == "" then return end
	local mob = UnitName("target") or ""
	for i = 1, M.nact do
		local u = M.act[i]
		if UnitName(u) == hn then
			local a = M.AG[u]
			a.fH = true
			if a.mob == "" then a.mob = mob end
			return
		end
	end
end

function M.AggroAlert(u, a, now)
	local c = M.cfg
	local me = M.IsSelf(u)
	if c.asound ~= "none" and (me or c.asoundwho == "all") then M.Play(c.asound, "raid") end
	if c.amsg ~= "none" and (me or c.amsgwho == "all") and now - a.alertAt >= 3 then
		a.alertAt = now
		if me then
			M.Say(c.amsg, L("msg.groupfx.aggroself", a.mob), "bad")
		else
			M.Say(c.amsg, L("msg.groupfx.aggroother", UnitName(u) or u, a.mob), "bad")
		end
	end
end

-- Un tour d'aggro (en combat seulement) : marque qui est vise, puis fixe etat / role / source et previent des changements.
function M.AggroTick()
	local c = M.cfg
	local now = GetTime()
	for i = 1, M.nact do
		local a = M.AG[M.act[i]]
		a.fT, a.fH, a.mob = false, false, ""
	end
	if c.mode == "target" or c.mode == "both" then
		M.nseen = 0
		for i = 1, getn(M.MOBS) do considerMob(M.MOBS[i]) end
	end
	if c.mode == "threat" or c.mode == "both" then scanThreat() end
	for i = 1, M.nact do
		local u = M.act[i]
		local a = M.AG[u]
		local st, role, src = "none", false, false
		if a.fT or a.fH then
			role = M.RoleOf(u, a, now)
			if role == "tank" then st = "tank"
			elseif roleAlerts(role) then st = "offrole"
			else role = false end
			if st ~= "none" then src = (a.fT and a.fH) and "both" or (a.fT and "target" or "threat") end
		end
		if st ~= a.state or role ~= a.role2 or src ~= a.src then
			local old = a.state
			a.state, a.role2, a.src = st, role, src
			M.Notify(u, "aggro")
			if st == "offrole" and old ~= "offrole" then M.AggroAlert(u, a, now) end
		end
	end
	M.hasAgg = true
end

-- Hors combat (ou mode coupe) : plus d'aggro nulle part ; une seule notification par unite concernee.
function M.ClearAggro()
	M.hasAgg = false
	for i = 1, getn(M.UNITS) do
		local a = M.AG[M.UNITS[i]]
		if a and (a.state ~= "none") then
			a.state, a.role2, a.src, a.fT, a.fH, a.mob = "none", false, false, false, false, ""
			M.Notify(M.UNITS[i], "aggro")
		end
	end
end

function M.Aggro(unit)
	local a = M.AG[unit]
	if not a or not M.on or a.state == "none" then return "none", nil, nil end
	return a.state, a.role2 or nil, a.src or nil
end

-- ---------------------------------------------------------------- liste des membres actifs
function M.Roster()
	local nr = GetNumRaidMembers()
	local n = 0
	if nr > 0 then
		for i = 1, nr do n = n + 1 M.act[n] = "raid" .. i end
	else
		n = 1
		M.act[1] = "player"
		for i = 1, GetNumPartyMembers() do n = n + 1 M.act[n] = "party" .. i end
	end
	for i = getn(M.act), n + 1, -1 do M.act[i] = nil end
	M.nact = n
	-- jetons des ennemis candidats : ta cible puis la cible de chaque membre actif (jetons deja prets : aucune creation)
	for i = getn(M.MOBS), 2, -1 do M.MOBS[i] = nil end
	for i = 1, n do M.MOBS[i + 1] = M.BT[M.act[i]] end
end

function M.FullScan(alert)
	M.lastFull = GetTime()
	for i = 1, M.nact do M.Scan(M.act[i], alert) end
end

-- Efface les effets d'unites qui ne sont plus dans le groupe (changement de composition).
function M.PruneInactive()
	for i = 1, getn(M.UNITS) do
		local u = M.UNITS[i]
		local active = false
		for j = 1, M.nact do
			if M.act[j] == u then active = true break end
		end
		if not active then
			local st = M.ST[u]
			if st and (st.dn > 0 or st.bn > 0 or M.FXN[u] > 0) then
				for k = st.dn, 1, -1 do st.dtex[k], st.dname[k] = nil, nil end
				for k = st.bn, 1, -1 do st.btex[k], st.bname[k] = nil, nil end
				st.dn, st.bn = 0, 0
				for k = M.FXN[u], 1, -1 do M.FXL[u][k] = nil end
				M.FXN[u] = 0
				M.Notify(u, "fx")
			end
			local a = M.AG[u]
			if a and a.state ~= "none" then
				a.state, a.role2, a.src, a.fT, a.fH = "none", false, false, false, false
				M.Notify(u, "aggro")
			end
		end
	end
end

-- ---------------------------------------------------------------- evenements et minuterie
function M.OnAura(ev, unit)
	if not M.cfg.fxon or not unit then return end
	if M.ST[unit] then
		for i = 1, M.nact do
			if M.act[i] == unit then M.Scan(unit, true) return end
		end
	end
end

function M.OnRoster()
	M.Roster()
	M.PruneInactive()
	M.forceMatch = true
	if M.cfg.fxon then M.FullScan(false) end
	M.forceMatch = false
end

function M.Tick()
	if not M.on then return end
	local now = GetTime()
	if M.cfg.fxon and now - M.lastFull >= M.FULLSCAN then M.FullScan(true) end
	if M.cfg.mode ~= "off" and SUI.InCombat() then
		M.AggroTick()
	elseif M.hasAgg then
		M.ClearAggro()
	end
end

function M.OnCombat(ev)
	if ev == "PLAYER_REGEN_ENABLED" then
		if M.hasAgg then M.ClearAggro() end
	else
		M.Tick()
	end
end

function M.ApplyOptions()
	M.ReadConfig()
	if M.on then
		if M.task then SUI.Cancel(M.task) end
		M.task = SUI.Every(M.cfg.tick, M.Tick, "groupfx.tick", true)
		M.forceMatch = true
		if M.cfg.fxon then M.FullScan(false) else M.ClearFx() end
		M.forceMatch = false
		if M.cfg.mode == "off" and M.hasAgg then M.ClearAggro() end
	end
end

function M.ClearFx()
	for i = 1, getn(M.UNITS) do
		local u = M.UNITS[i]
		local st = M.ST[u]
		if st then
			for k = st.dn, 1, -1 do st.dtex[k], st.dname[k] = nil, nil end
			for k = st.bn, 1, -1 do st.btex[k], st.bname[k] = nil, nil end
			st.dn, st.bn = 0, 0
			if M.FXN[u] > 0 then
				for k = M.FXN[u], 1, -1 do M.FXL[u][k] = nil end
				M.FXN[u] = 0
				M.Notify(u, "fx")
			end
		end
	end
end

function M.OnKey(key, value)
	M.ApplyOptions()
end

function M.Enable()
	M.Prime()
	M.on = true
	SUI.WhenSafe(ensureTip)
	M.ReadConfig()
	M.Roster()
	SUI.On("UNIT_AURA", M.OnAura)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombat)
	if not M.watching then
		M.watching = true
		C.Watch("groupfx.", M.OnKey)
	end
	M.ApplyOptions()
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Off("UNIT_AURA", M.OnAura)
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombat)
	M.ClearFx()
	M.ClearAggro()
end

-- ---------------------------------------------------------------- commande /sui groupfx
function M.AddCustom(name, buff)
	name = trim(name or "")
	if name == "" then return false end
	local cur = C.Get("groupfx.custom") or ""
	local parts = {}
	local n = M.Split(cur, ";", parts)
	local want = (buff and "+" or "") .. name
	for i = 1, n do
		if M.Fold(parts[i]) == M.Fold(want) then return false end
	end
	if cur ~= "" then cur = cur .. ";" end
	C.Set("groupfx.custom", cur .. want)
	return true
end

function M.RemoveCustom(name)
	local parts = {}
	local n = M.Split(C.Get("groupfx.custom") or "", ";", parts)
	local out, found = "", false
	local f = M.Fold(trim(name or ""))
	for i = 1, n do
		local p = parts[i]
		local bare = ssub(p, 1, 1) == "+" and trim(ssub(p, 2)) or p
		if M.Fold(bare) == f then found = true
		else out = (out == "" and "" or (out .. ";")) .. p end
	end
	if found then C.Set("groupfx.custom", out) end
	return found
end

local function cmdStatus()
	SUI.Print(L("msg.groupfx.status", M.on and "on" or "off", M.cfg.mode, getn(M.entries), M.nact))
	for i = 1, M.nact do
		local u = M.act[i]
		local l, n = M.Effects(u)
		local st, role, src = M.Aggro(u)
		if n > 0 or st ~= "none" then
			local s = (UnitName(u) or u) .. " : " .. st
			if role then s = s .. " (" .. role .. "/" .. tostring(src) .. ")" end
			for j = 1, n do s = s .. " [" .. l[j].name .. "]" end
			SUI.Print(s)
		end
	end
end

SUI.RegisterCommand("groupfx", function(rest)
	rest = trim(rest or "")
	local _, _, sub, arg = sfind(rest, "^(%S+)%s*(.*)$")
	sub = sub and slower(sub) or ""
	if not C.Get("modules.groupfx") and sub ~= "" then C.Set("modules.groupfx", true) end
	if sub == "add" then
		local buff = false
		local _, _, w, r2 = sfind(arg, "^(%S+)%s+(.*)$")
		if w and (slower(w) == "buff" or slower(w) == "debuff") then
			buff = slower(w) == "buff"
			arg = r2
		end
		if arg == "" then SUI.Print(L("msg.groupfx.usage")) return end
		if M.AddCustom(arg, buff) then SUI.Print(L("msg.groupfx.added", arg)) else SUI.Print(L("msg.groupfx.exists", arg)) end
	elseif sub == "remove" or sub == "del" then
		if M.RemoveCustom(arg) then SUI.Print(L("msg.groupfx.removed", arg)) else SUI.Print(L("msg.groupfx.unknown", arg)) end
	elseif sub == "list" then
		local n = 0
		for i = 1, getn(M.entries) do
			local e = M.entries[i]
			n = n + 1
			SUI.Print(e.def.names[1] .. ((e.def.boss and e.def.boss ~= "") and (" - " .. e.def.boss) or "") .. (e.custom and " *" or ""))
		end
		SUI.Print(L("msg.groupfx.count", n))
	elseif sub == "status" then
		cmdStatus()
	else
		SUI.Print(L("msg.groupfx.usage"))
	end
end, "help.groupfx")

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("groupfx", 76)

local function opt(key, typ, order, def, extra)
	local o = { key = "groupfx." .. key, type = typ, cat = "groupfx", label = "opt.groupfx." .. key, tip = "tip.groupfx." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local MSG = { "none", "chat", "screen", "both" }
local WHO = { "self", "all" }

local options = {
	opt("fx.on", "bool", 10, true, { simple = true }),
	opt("fx.icon", "bool", 20, true, { simple = true }),
	opt("fx.tint", "bool", 30, true),
	opt("fx.timer", "bool", 40, true),
	opt("fx.max", "number", 50, 2, { min = 1, max = 4, step = 1 }),
	opt("fx.sound", "choice", 60, "auto", { choices = M.SOUNDLIST }),
	opt("fx.soundwho", "choice", 70, "self", { choices = WHO }),
	opt("fx.msgself", "choice", 80, "screen", { choices = MSG }),
	opt("aggromode", "choice", 110, "target", { choices = { "off", "target", "threat", "both" }, simple = true }),
	opt("aggrofilter", "choice", 120, "boss", { choices = { "boss", "elite", "any" } }),
	opt("aggro.frame", "bool", 130, true, { simple = true }),
	opt("aggro.icon", "bool", 140, true),
	opt("aggro.tank", "bool", 150, false),
	opt("aggro.sound", "choice", 160, "raid", { choices = M.SOUNDLIST }),
	opt("aggro.soundwho", "choice", 170, "self", { choices = WHO }),
	opt("aggro.msg", "choice", 180, "screen", { choices = MSG }),
	opt("aggro.msgwho", "choice", 190, "self", { choices = WHO }),
	opt("aggro.heal", "bool", 200, true),
	opt("aggro.caster", "bool", 210, true),
	opt("aggro.dps", "bool", 220, true),
	opt("roleguess", "bool", 230, true),
	opt("tanks", "string", 240, ""),
	opt("custom", "string", 250, ""),
	opt("tick", "number", 260, 0.5, { min = 0.2, max = 2, step = 0.1 }),
}
for i = 1, getn(M.ORDER) do
	local k = M.ORDER[i]
	tinsert(options, { key = "groupfx.off." .. k, type = "bool", cat = "groupfx", label = "opt.groupfx.off." .. k, tip = "tip.groupfx.off", default = false, order = 300 + i })
end

SUI.RegisterModule("groupfx", {
	default = false,
	cost = "light",
	options = options,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- libelles des interrupteurs par effet (ecrits ici : ils suivent la liste de donnees)
for i = 1, getn(M.ORDER) do
	local k = M.ORDER[i]
	local d = M.BOSSFX[k]
	local en = d.names[1]
	local nfr = d.names[2] or d.names[1]
	local boss = (d.boss and d.boss ~= "") and (" (" .. d.boss .. ")") or ""
	SUI.locales.fr["opt.groupfx.off." .. k] = "Masquer : " .. nfr .. boss
	SUI.locales.en["opt.groupfx.off." .. k] = "Hide: " .. en .. boss
end
