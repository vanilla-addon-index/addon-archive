-- ShikiUI PallyPower : benedictions de raid pour paladin (module "pallypower"), dans l'esprit de PallyPower (addon 1.12 original :
-- reconnaissance du CONCEPT d'attribution par grille ; aucun code copie, tout reecrit).
-- Ce que fait le module :
--   1. Fenetre de grille : chaque membre du raid = une ligne, 5 benedictions en colonnes (Kings, Wisdom, Might, Salvation, Light).
--      Clic sur une case = attribuer / retirer CETTE benediction A CE joueur ; clic droit = retirer. En-tete : un bouton par
--      benediction (tout le monde / personne) et un bouton par classe presente (jeu par defaut de la classe, clic droit = vider).
--      Les attributions restent propres a ce module : jamais posees automatiquement, memoire dans ShikiUIDB (global).
--   2. Bouton "Benir" / touche (Bindings.xml SHIKIUI_PALLYPOWER, /sui pp cast) : pose a CHAQUE joueur ses benedictions attribuees,
--      UNE par tour (GCD 1,1 s), en sautant ceux qui l'ont deja (UnitBuff, simple OU greater : jamais reposee par-dessus). Greater
--      (option ; 30 min sur ce serveur) ou simple (10 min) selon le reglage pp.greater. Fonctionne EN combat (benedictions d'urgence).
--   3. Jugement (option pp.judge) : none / light / wisdom / crusader, pose sur la cible courante au demarrage du cycle.
-- NON VERIFIE EN JEU : noms des sorts (client ANGLAIS, meme limite assume que Mod_Totems ; un client francais ne trouvera pas les
--   benedictions), les 9 retours de GetRaidRosterInfo (var 6 = nom de classe EN, releve dans RaidTools), CastSpellByName(spell, unit)
--   sans SuperWoW (methode par echange de cible, comme le soin au clic), Bindings.xml charge par le client sans entree de .toc
--   (convention du dossier d'addon). Pas de synchronisation entre paladins (protocole addon : version 2). Benes de combat (Protection,
--   Liberte, Sacrifice) hors grille : elles se lient au clic via le module Soins au clic.
-- Cout declare : "medium" (grille construite UNE fois hors combat ; fenetre fermee = aucune minuterie, aucune lecture).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 valeurs externes par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.PallyPower = M

local getn, tinsert = table.getn, table.insert
local max = math.max
local floor, mmin, mmax = math.floor, math.min, math.max
local sfind, slower, sgsub, strsub = string.find, string.lower, string.gsub, string.sub
local EMPTY = ""

-- Pliage d'accents (UTF-8 FR -> lettres pures) : comparaisons de noms de buffs en plie.
-- Les cles sont les sequences UTF-8 FR en decimales : \195\169 = e accentue, etc.
local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\146"] = "a", ["\195\149"] = "o", ["\195\154"] = "u", ["\195\161"] = "a", ["\195\163"] = "a",
	["\195\165"] = "a", ["\195\166"] = "a", ["\195\173"] = "i", ["\195\176"] = "o", ["\195\178"] = "o",
	["\195\177"] = "n", ["\195\145"] = "n", ["\195\152"] = "o", ["\195\151"] = "o",
}
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "\195[\128-\191]", PLAIN)
	return out
end
local GAMEFR = (getglobal("GetLocale") and getglobal("GetLocale")() == "frFR") and true or false
M.GAMEFR = GAMEFR

M.on = false
M.win = nil
M.roster = {}            -- { { name, unit, file } } dans l'ordre du raid
M.nrost = 0
M.assign = nil           -- name -> { kings = true, ... } (persiste dans ShikiUIDB.global.pallypower.assign)
M.pairs = {}             -- file du cycle en cours : { unit, name, base, who }
M.npairs, M.qi = 0, 0
M.task = nil
M.castn = 0              -- benedictions posees depuis le debut du cycle
M.offset = 0             -- defilement de la grille
M.view = 22              -- lignes visibles
M.buffNames = {}         -- [unite] = { ["blessing of kings"] = true, ... } : noms des buffs lus par tour du cycle
M.tip = nil              -- infobulle cachee pour lire les noms de buffs (creee hors combat, voir EnsureTip)

-- Benedictions attribuables (noms EN du client) ; ordre de pose. [donnees du jeu]
M.BLESS = { "kings", "wisdom", "might", "salvation", "light", "sanctuary" }
M.SPELLS = { kings = "Blessing of Kings", wisdom = "Blessing of Wisdom", might = "Blessing of Might",
	salvation = "Blessing of Salvation", light = "Blessing of Light", sanctuary = "Blessing of Sanctuary" }
-- Jeux par defaut d'une classe (bouton de classe). [donnees du jeu]
M.CLASSDEF = {
	WARRIOR = { kings = true, might = true }, ROGUE = { kings = true, might = true }, HUNTER = { kings = true, might = true },
	MAGE = { kings = true, wisdom = true }, WARLOCK = { kings = true, wisdom = true }, PRIEST = { kings = true, wisdom = true },
	DRUID = { kings = true, wisdom = true }, SHAMAN = { kings = true, wisdom = true }, PALADIN = { kings = true, wisdom = true },
}
M.JUDGES = { none = EMPTY, light = "Judgement of Light", wisdom = "Judgement of Wisdom", crusader = "Judgement of Crusader" }
M.GREATERPFX = "Greater "
-- Noms FR (client frFR depuis OctoWow) : incantations, jugements et lecture d'infobulle selon la langue du jeu.
-- Sequences d'echappement ASCII : \195\169 = e accentue, etc. (comparaisons faites en plie, voir fold plus bas).
M.SPELLS_FR = { kings = "Ben\195\169diction des Rois", wisdom = "Ben\195\169diction de Sagesse", might = "Ben\195\169diction de Puissance",
	salvation = "Ben\195\169diction de Salut", light = "Ben\195\169diction de Lumi\195\168re", sanctuary = "Ben\195\169diction de Sanctuaire" }
M.GREATER_FR = "Ben\195\169diction sup\195\169rieure "
M.SPELLS_GFR = { kings = "Ben\195\169diction sup\195\169rieure des Rois", wisdom = "Ben\195\169diction sup\195\169rieure de Sagesse", might = "Ben\195\169diction sup\195\169rieure de Puissance", salvation = "Ben\195\169diction sup\195\169rieure de Salut", light = "Ben\195\169diction sup\195\169rieure de Lumi\195\168re", sanctuary = "Ben\195\169diction sup\195\169rieure de Sanctuaire" }
M.JUDGES_FR = { light = "Jugement de Lumi\195\168re", wisdom = "Jugement de Sagesse", crusader = "Jugement du crois\195\169" }
M.ROWS = 40
M.MAXCLASS = 10

-- ---------------------------------------------------------------- attributions
local function deepCopy(t)
	local o = {}
	for k, v in pairs(t) do
		if type(v) == "table" then o[k] = deepCopy(v) else o[k] = v end
	end
	return o
end

-- Une grille PAR PERSONNAGE (ShikiUIDB.global.pallypower.assignc[Nom-Royaume]) ; la 1re fois, l'ancienne grille commune est copiee.
function M.LoadAssign()
	local all = C.GetGlobal("pallypower.assignc")
	if type(all) ~= "table" then
		all = {}
		C.SetGlobal("pallypower.assignc", all)
	end
	M.allAssign = all
	local key = C.CharKey() or "?"
	local db = all[key]
	if type(db) ~= "table" then
		local old = C.GetGlobal("pallypower.assign")
		db = type(old) == "table" and deepCopy(old) or {}
		all[key] = db
	end
	M.assignKey = key
	M.assign = db
end

local function asg(name)
	local a = M.assign[name]
	if not a then
		a = {}
		M.assign[name] = a
	end
	return a
end

-- Une benediction est de 10 min si le joueur est marque "10" (toutes ses benedictions) ou si CETTE case l'est (clic droit).
function M.IsSingle(a, b)
	return a and a[b] and (a.single or (a.sg and a.sg[b])) and true or false
end

function M.AnySingle(a)
	if not a then return false end
	if a.single then return true end
	for j = 1, getn(M.BLESS) do
		if M.IsSingle(a, M.BLESS[j]) then return true end
	end
	return false
end

function M.Has(name, b)
	local a = M.assign[name]
	return a and a[b] and true or false
end

local function saveAssign()
	if M.demo then return end      -- demonstration : jamais ecrite dans la base
	if M.allAssign then
		M.allAssign[M.assignKey or "?"] = M.assign
		C.SetGlobal("pallypower.assignc", M.allAssign)
	end
	if M.mini and M.MiniPaint then M.MiniPaint() end
	if M.SyncSoon then M.SyncSoon() end
end

-- ancien indicateur "tout en 10 min" (a.single) : converti en 10 min par case, pour que le clic fasse defiler les etats case par case
local function unsingle(a)
	if not a.single then return end
	a.single = nil
	a.sg = a.sg or {}
	for j = 1, getn(M.BLESS) do
		local k = M.BLESS[j]
		if a[k] then a.sg[k] = true end
	end
end
M.Unsingle = unsingle

function M.Toggle(name, b, want)
	local a = asg(name)
	unsingle(a)
	if want == nil then want = not a[b] end
	if want then a[b] = true else a[b] = nil end
	if a.sg then a.sg[b] = nil end
	saveAssign()
	M.PaintCells()
end

-- Pose une benediction sur un joueur : mode "10" = benediction de 10 min pour cette case seulement, sinon benediction superieure.
function M.Put10(name, b, ten)
	local a = asg(name)
	unsingle(a)
	a[b] = true
	if ten then
		if not a.sg then a.sg = {} end
		a.sg[b] = true
	elseif a.sg then
		a.sg[b] = nil
	end
	saveAssign()
	M.PaintCells()
end

-- Bouton de classe : attr (jeu par defaut) ou vider la classe.
function M.SetClass(file, attr)
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			local a = asg(r.name)
			for j = 1, getn(M.BLESS) do a[M.BLESS[j]] = nil end
			if attr then
				local d = M.CLASSDEF[file]
				if d then
					for k, v in pairs(d) do
						if v then a[k] = true end
					end
				end
			end
		end
	end
	saveAssign()
	M.PaintCells()
end

function M.SetAll(b, want)
	for i = 1, M.nrost do
		local a = asg(M.roster[i].name)
		if want then a[b] = true else a[b] = nil end
	end
	saveAssign()
	M.PaintCells()
end

function M.ClearAll()
	for _, a in pairs(M.assign) do
		for k in pairs(a) do a[k] = nil end
	end
	saveAssign()
	M.PaintCells()
end

-- Classes presentes dans le raid, sans doublon.
M.classes = {}

function M.ScanClasses()
	for k in pairs(M.classes) do M.classes[k] = nil end
	for i = 1, M.nrost do
		local f = M.roster[i].file
		if f and not M.classes[f] then M.classes[f] = true end
	end
end

-- ---------------------------------------------------------------- liste du raid
local function rosterAdd(name, unit, file)
	for i = 1, M.nrost do
		if M.roster[i].name == name then return end
	end
	if M.nrost >= M.ROWS then return end
	M.nrost = M.nrost + 1
	M.roster[M.nrost] = { name = name, unit = unit, file = file or "WARRIOR" }
end

function M.ScanRoster()
	M.nrost = 0
	local nr = 0
	local gnr = getglobal("GetNumRaidMembers")
	if type(gnr) == "function" then nr = gnr() or 0 end
	if nr > 0 then
		local gri = getglobal("GetRaidRosterInfo")
		for i = 1, nr do
			if gri then
				local name, _, _, _, _, file = gri(i)
				if name then rosterAdd(name, "raid" .. i, file) end
			end
		end
	else
		local np = 0
		local gnp = getglobal("GetNumPartyMembers")
		if type(gnp) == "function" then np = gnp() or 0 end
		local _, fe = UnitClass("player")
		rosterAdd(UnitName("player") or EMPTY, "player", fe)
		for i = 1, np do
			local u = "party" .. i
			if UnitExists(u) then
				local _, f2 = UnitClass(u)
				rosterAdd(UnitName(u) or EMPTY, u, f2)
			end
		end
	end
	M.ScanClasses()
	M.offset = 0
	if M.win and M.win:IsShown() then M.Rebuild() end
end

function M.OnRoster()
	if M.on and not M.demo then M.ScanRoster() end
end

-- ---------------------------------------------------------------- benedictions posees ?
-- En 1.12, UnitBuff renvoie une TEXTURE, pas un nom (comme le documente Mod_PowerAuras) : le nom d'un buff se lit
-- par une infobulle cachee (SetUnitBuff + ligne 1), methode eprouvee dans PowerAuras. Les noms d'une unite sont lus
-- UNE fois par tour du cycle (cache par unite, vide a chaque BuildPairs) : au plus 32 lectures d'infobulle par joueur.
local function unitBuffNames(unit)
	local names = M.buffNames[unit]
	if names then return names end
	names = {}
	M.buffNames[unit] = names
	local ub = getglobal("UnitBuff")
	if type(ub) ~= "function" or not M.tip then return names end
	for i = 1, 32 do
		if not ub(unit, i) then break end
		M.tip:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip:SetUnitBuff(unit, i)
		local fs = getglobal("ShikiUI_PPTipTextLeft1")
		local nm = fs and fs:GetText()
		if nm and nm ~= "" then names[fold(nm)] = true end
	end
	return names
end

-- Vrai si l'unite porte deja cette benediction (simple OU greater : on ne repose jamais par-dessus).
function M.HasBuff(unit, base)
	local names = unitBuffNames(unit)
	-- identifiant de la benediction (kings...) retrouve depuis son nom EN : les tables FR sont indexees par identifiant
	local id
	for j = 1, getn(M.BLESS) do
		if M.SPELLS[M.BLESS[j]] == base then id = M.BLESS[j] break end
	end
	local want, gw = fold(base), fold(M.GREATERPFX .. base)
	local fwant, fgw
	if id and M.SPELLS_FR[id] then
		fwant = fold(M.SPELLS_FR[id])
		fgw = fold(M.SPELLS_GFR[id] or (M.GREATER_FR .. M.SPELLS_FR[id]))
	end
	for n in pairs(names) do
		if n == want or n == gw or n == fwant or n == fgw then return true end
	end
	return false
end

-- ---------------------------------------------------------------- cycle de benediction
-- Nom reel du sort selon la langue du jeu (frFR chez OctoWow : "Ben959diction sup959rieure des Rois"), sinon EN.
function M.SpellName(b, single)
	local gr = C.Get("pallypower.greater") and not single
	if GAMEFR and M.SPELLS_FR[b] then
		if gr then return M.SPELLS_GFR[b] or (M.GREATER_FR .. M.SPELLS_FR[b]) end
		return M.SPELLS_FR[b]
	end
	local base = M.SPELLS[b]
	if gr then return M.GREATERPFX .. base end
	return base
end

-- Niveaux d'apprentissage des rangs (1.12) : le client refuse un rang trop haut sur une cible de bas niveau ("niveau trop bas").
-- Benediction superieure (30 min) : posee sur TOUS les niveaux par defaut (verifie par le joueur en jeu) ; l'option pallypower.greaterlvl permet de repasser en 10 min sous un niveau donne.
M.RANKLVL = { might = { 4, 12, 22, 32, 42, 52, 60 }, wisdom = { 14, 24, 34, 44, 54, 60 }, kings = { 20 }, salvation = { 26 },
	light = { 40, 50, 60 }, sanctuary = { 30, 40, 50, 60 } }
M.GREATERLVL = 0

-- Rang a lancer sur une unite : nil = rang maximum (pas de suffixe) ; n = rang n (au minimum 1 : sur une cible plus basse que le rang 1, on tente le rang 1 et le serveur tranche).
function M.RankFor(b, unit)
	local tbl = M.RANKLVL[b]
	local ul = getglobal("UnitLevel")
	local lv = tbl and type(ul) == "function" and ul(unit)
	if type(lv) ~= "number" or lv <= 0 then return nil end
	local r = 1
	for i = 1, getn(tbl) do
		if tbl[i] <= lv then r = i end
	end
	if r >= getn(tbl) then return nil end
	return r
end

-- Vrai si la cible est trop basse pour une benediction superieure (la pose devient une benediction simple de 10 min).
function M.LowLevel(unit)
	local ul = getglobal("UnitLevel")
	local lv = type(ul) == "function" and ul(unit)
	return type(lv) == "number" and lv > 0 and lv < (C.Get("pallypower.greaterlvl") or M.GREATERLVL)
end

-- Nom complet du sort pour une unite : single = 10 min ; rang adapte au niveau.
-- Renvoie aussi le booleen "simple" reellement utilise.
function M.CastName(b, single, unit)
	if not single and M.LowLevel(unit) then single = true end
	local rk = M.RankFor(b, unit)
	local nm = M.SpellName(b, single)
	if single and rk then nm = nm .. "(" .. (GAMEFR and "Rang " or "Rank ") .. rk .. ")" end
	return nm, single
end

-- Joueur atteignable pour une benediction : present, connecte, visible, a 30 yd (UnitXP / SuperWoW, sinon bande de 28 yd) et en vue (UnitXP).
function M.Reachable(unit)
	if unit == "player" then return true end
	if not UnitExists(unit) then return false end
	local ic = getglobal("UnitIsConnected")
	if type(ic) == "function" and not ic(unit) then return false end
	local vis = getglobal("UnitIsVisible")
	if type(vis) == "function" and not vis(unit) then return false end
	local api = SUI.Api
	if api and type(api.Distance) == "function" then
		local d, src = api.Distance(unit)
		if src == "band" and d == nil then return false end
		if type(d) == "number" and d > 30 then return false end
	end
	if api and type(api.InSight) == "function" then
		if api.InSight(unit) == false then return false end
	end
	return true
end

-- Symboles des rois en sac (Benediction superieure) : nil si les sacs ne sont pas lisibles.
M.SYMBOL_ID = 21177
function M.SymbolCount()
	local gn, gl, gi = getglobal("GetContainerNumSlots"), getglobal("GetContainerItemLink"), getglobal("GetContainerItemInfo")
	if type(gn) ~= "function" or type(gl) ~= "function" then return nil end
	local n = 0
	for bag = 0, 4 do
		for slot = 1, (gn(bag) or 0) do
			local link = gl(bag, slot)
			if link and sfind(link, "item:" .. M.SYMBOL_ID .. ":", 1, true) then
				local cnt = 1
				if type(gi) == "function" then
					local _, c = gi(bag, slot)
					if type(c) == "number" and c > 0 then cnt = c end
				end
				n = n + cnt
			end
		end
	end
	return n
end

-- Vrai si on sait qu'il n'y a plus aucun Symbole : les benedictions deviennent des benedictions simples (10 min).
function M.NoSymbols()
	local n = M.SymbolCount()
	return n ~= nil and n <= 0
end

-- Construit la liste (unite, sort) de tout ce qui manque, dans l'ordre de la liste puis des benedictions.
-- Mes classes sans aucune benediction cote ShikiUI mais attribuees dans l'addon d'origine : on les reprend (jamais d'ecrasement).
function M.PullFromPallyPower()
	local me = UnitName("player")
	if not me then return end
	local seen, changed = {}, false
	for i = 1, M.nrost do
		local file = M.roster[i].file
		if file and not seen[file] then
			seen[file] = true
			local any = false
			for k = 1, M.nrost do
				local r = M.roster[k]
				local a = M.assign[r.name]
				if r.file == file and a then
					for j = 1, getn(M.BLESS) do if a[M.BLESS[j]] then any = true end end
				end
			end
			if not any then
				local b = M.OrigBless(me, file)
				if b and M.Knows(b) then
					for k = 1, M.nrost do
						local r = M.roster[k]
						if r.file == file then
							local a = asg(r.name)
							a[b] = true
							changed = true
						end
					end
				end
			end
		end
	end
	if changed then saveAssign() end
end

function M.BuildPairs()
	M.PullFromPallyPower()
	M.npairs, M.qi, M.castn = 0, 0, 0
	M.skipped = 0
	M.buffNames = {}   -- les noms de buffs sont relus a chaque tour du cycle
	M.noSym = M.NoSymbols()
	if M.noSym then SUI.Print(L("msg.pallypower.nosymbol")) end
	M.ScanKnown()      -- une benediction absente du livre de sorts (talent non appris) est ignoree au lieu d'echouer en silence
	-- deux passes : d'abord les benedictions de classe (30 min), ensuite les benedictions simples (10 min).
	-- Une benediction de classe touche TOUTE la classe : posee apres, elle ecraserait la benediction simple d'un autre joueur de la classe
	-- (ex. Sagesse de classe sur le druide soigneur ecraserait Puissance 10 min sur le druide feral).
	for pass = 1, 2 do
		for i = 1, M.nrost do
			local r = M.roster[i]
			local a = M.assign[r.name]
			if a then
				for j = 1, getn(M.BLESS) do
					local b = M.BLESS[j]
					if a[b] then
						-- cible de bas niveau : benediction simple, au rang que son niveau permet (seconde passe)
						local nm, single = M.CastName(b, M.IsSingle(a, b) or M.noSym, r.unit)
						if nm and M.Knows(b) and (pass == 2) == single and not M.HasBuff(r.unit, M.SPELLS[b]) then
							M.npairs = M.npairs + 1
							M.pairs[M.npairs] = { unit = r.unit, name = nm, base = M.SPELLS[b], frb = GAMEFR and M.SPELLS_FR[b] or nil, who = r.name, tries = 0 }
						end
					end
				end
			end
		end
	end
end

local function castOn(unit, name)
	-- SuperWoW : lancement direct sur l'unite ; sinon methode par echange de cible (comme le soin au clic).
	if SUI.Api.superwow then
		CastSpellByName(name, unit)
		return
	end
	local had = UnitExists("target")
	TargetUnit(unit)
	CastSpellByName(name)
	if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end      -- cible refusee : pas de sort "en attente" au curseur
	if had then TargetLastTarget() else ClearTarget() end                          -- (TargetUnit attend un jeton d'unite, pas un nom)
end

-- Un tour du cycle : pose UNE benediction (GCD), planifie le tour suivant ; arret propre quand tout est pose.
function M.CastStep()
	if not M.on or not M.task then return end
	if UnitIsDead("player") then return end      -- mort : le cycle attend (file gardee)
	-- une incantation en cours (soin, ...) serait interrompue par la benediction : le tour est repousse
	if M.busyUntil and GetTime() < M.busyUntil then return end
	-- verification du dernier lancement (buffs relus a neuf) : le serveur ou le temps de recharge global a pu le refuser
	local lp = M.lastp
	if lp then
		M.buffNames[lp.unit] = nil
		if UnitExists(lp.unit) and not UnitIsDead(lp.unit) and not M.HasBuff(lp.unit, lp.base) and lp.tries < 2 then
			lp.checks = (lp.checks or 0) + 1
			if lp.checks < 2 then return end             -- laisser le temps au serveur (latence) : pas de 2e Symbole gaspille
			lp.checks = 0
			lp.tries = lp.tries + 1
			castOn(lp.unit, lp.name)
			return
		end
		M.lastp = nil
	end
	while M.qi < M.npairs do
		M.qi = M.qi + 1
		local p = M.pairs[M.qi]
		-- le jeton "raidN" peut designer un autre joueur si le raid a change depuis la construction de la file
		if p and UnitExists(p.unit) and not UnitIsDead(p.unit) and (not p.who or UnitName(p.unit) == p.who) then
			-- buffs relus a neuf : une benediction superieure posee plus haut couvre peut-etre deja toute la classe, ou un autre paladin est passe
			M.buffNames[p.unit] = nil
			if M.HasBuff(p.unit, p.base) then
				-- deja couvert
			elseif not M.Reachable(p.unit) then
				M.skipped = (M.skipped or 0) + 1      -- hors de portee / de vue : ignore pour ce cycle
			else
				castOn(p.unit, p.name)
				p.tries = 1
				M.lastp = p
				M.castn = M.castn + 1
				M.PaintStatus()
				return
			end
		end
	end
	local sk = M.skipped or 0
	M.Stop()
	M.PaintStatus()
	if M.castn > 0 then SUI.Print(L("msg.pallypower.done", M.castn)) end
	if sk > 0 then SUI.Print(L("msg.pallypower.range", sk)) end
end

function M.CastAll()
	if not M.on then SUI.Print(L("msg.pallypower.off")) return end
	if M.npairs > 0 and M.qi < M.npairs then SUI.Print(L("msg.pallypower.busy")) return end
	if M.task then SUI.Cancel(M.task) M.task = nil end
	-- le jugement part avant tout, meme si plus personne ne manque (c'est un geste a part)
	local jid = C.Get("pallypower.judge") or "none"
	local j = (GAMEFR and M.JUDGES_FR[jid]) or M.JUDGES[jid] or EMPTY
	if j ~= EMPTY and UnitExists("target") and UnitCanAttack("player", "target") then CastSpellByName(j) end
	M.BuildPairs()
	if M.npairs == 0 then
		SUI.Print(L("msg.pallypower.allset"))
		M.PaintStatus()
		return
	end
	M.qi = 0
	M.task = SUI.Every(1.7, M.CastStep, "pp.cast", true)
	M.CastStep()
	M.PaintStatus()
end

function M.Stop()
	if M.task then SUI.Cancel(M.task) M.task = nil end
	M.npairs, M.qi, M.lastp = 0, 0, nil
end

-- ---------------------------------------------------------------- fenetre (grille)
-- Clic gauche : fait defiler vide -> superieure (30 min) -> 10 min -> vide. Clic droit : pose la benediction de 10 min sur CETTE case
-- (ou la convertit en 10 min) ; un second clic droit la retire.
local function cellClick()
	local b = this
	if not (b.who and b.bless) then return end
	local a = M.assign[b.who]
	if a then unsingle(a) end
	if not (a and a[b.bless]) then
		M.Put10(b.who, b.bless, false)      -- vide -> benediction superieure (30 min)
	elseif (a.sg and a.sg[b.bless]) or a.single then
		M.Toggle(b.who, b.bless, false)     -- 10 min -> vide
	else
		M.Put10(b.who, b.bless, true)       -- 30 min -> 10 min : le clic gauche fait defiler vide / 30 min / 10 min
	end
end

local function cellRClick()
	local b = this
	if not (b.who and b.bless) then return end
	local a = M.assign[b.who]
	if a then unsingle(a) end
	if a and a[b.bless] and ((a.sg and a.sg[b.bless]) or a.single) then
		M.Toggle(b.who, b.bless, false)
	else
		M.Put10(b.who, b.bless, true)
	end
end

local function mkBtn(parent, label, w, h, fn, rfn)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(h)
	T.Backdrop(b, T.c.bg, T.c.border)
	b.txt = T.Text(b, 10, T.c.text, "CENTER", true)
	b.txt:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.txt:SetText(label or EMPTY)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function()
		if arg1 == "RightButton" and rfn then rfn() else fn() end
	end)
	return b
end

local function tip(b, key)
	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:AddLine(L(key), 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end



-- Dimensions de la fenetre classique : 6 colonnes de bene (74 px + 6 d ecart) + colonne de noms, hauteur
-- selon le nombre de LIGNES affichees (fini la moitie d ecran vide avec 4 joueurs).
local COLW, COLGAP = 74, 6
-- Colonne des cases : x = 136 (T, 10, nom a gauche) ; la fenetre detaillee epouse EXACTEMENT les 6 colonnes (le pas est de 80)
local GRIDX = 136
function M.WinW()
	return GRIDX + (getn(M.BLESS) - 1) * (COLW + COLGAP) + COLW + 12
end
function M.WinH()
	local rows = 0
	for i = 1, M.ROWS do
		local r = M.list and M.list[i]
		if r and r.name then rows = rows + 1 end
	end
	if rows < 1 then rows = 1 end
	return 30 + 18 + 6 + rows * (14 + 4) + 16 + 4 * 24 + 10
end
function M.Build()
	if M.win then return end
	local f = CreateFrame("Frame", "ShikiUI_PallyPowerWin", UIParent)
	f:SetWidth(M.WinW())
	f:SetHeight(M.WinH())
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.win = f
	f.title = T.Text(f, 13, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.title:SetText(L("mod.pallypower.title"))
	f.status = T.Text(f, 11, T.c.dim, "LEFT")
	f.status:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
	f.close = mkBtn(f, "x", 18, 18, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	-- rangee 1 : un bouton par benediction (tout le monde / clic droit : personne)
	f.allB = {}
	for j = 1, getn(M.BLESS) do
		local b = M.BLESS[j]
		local btn = mkBtn(f, L("mod.pallypower.bless." .. b), 74, 18,
			function() M.SetAll(b, not M.AllHave(b)) end,
			function() M.SetAll(b, false) end)
		btn:SetPoint("TOPLEFT", f, "TOPLEFT", GRIDX + (j - 1) * (COLW + COLGAP), -30)     -- pile au-dessus de la colonne de cases
		f.allB[b] = btn
	end
	-- rangee 2 : boutons de classes presentes (jeu par defaut / clic droit = vider)
	f.classB = {}
	for i = 1, M.MAXCLASS do
		local b = mkBtn(f, EMPTY, 46, 18, function()
			if this.file then M.SetClass(this.file, true) end
		end, function()
			if this.file then M.SetClass(this.file, false) end
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 50, -52)
		b:Hide()
		f.classB[i] = b
	end
	-- grille : NOM + une case par benediction, M.ROWS lignes preparees, M.view visibles (molette)
	f.rows = {}
	for i = 1, M.ROWS do
		local row = CreateFrame("Frame", nil, f)
		row:SetHeight(14)
		row:SetWidth(M.WinW() - 16)
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints(row)
		row.bg:SetTexture(1, 1, 1, (i / 2 == floor(i / 2)) and 0.05 or 0.02)
		row.name = T.Text(row, 10, T.c.text, "LEFT", true)
		row.name:SetPoint("LEFT", row, "LEFT", 40, 0)
		row.name:SetWidth(84)
		row.bT = mkBtn(row, "T", 16, 13, function()
			local r = this:GetParent()
			if r._n then M.ToggleFlag(r._n, "tank") end
		end)
		row.bT:SetPoint("LEFT", row, "LEFT", 2, 0)
		tip(row.bT, "msg.pallypower.tip.rowtank")
		row.bS = mkBtn(row, "10", 18, 13, function()
			local r = this:GetParent()
			if r._n then M.ToggleFlag(r._n, "single") end
		end)
		row.bS:SetPoint("LEFT", row, "LEFT", 20, 0)
		tip(row.bS, "msg.pallypower.tip.rowsingle")
		row.cells = {}
		for j = 1, getn(M.BLESS) do
			local b = M.BLESS[j]
			local cell = CreateFrame("Button", nil, row)
			cell:SetWidth(74)
			cell:SetHeight(13)
			cell.bless = b
			T.Backdrop(cell, T.c.bg, T.c.border)
			cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			cell:SetScript("OnClick", function()
				if arg1 == "RightButton" then cellRClick() else cellClick() end
			end)
			cell:SetPoint("LEFT", row, "LEFT", GRIDX - 8 + (j - 1) * (COLW + COLGAP), 0)   -- aligne sur les boutons de colonne
			tip(cell, "msg.pallypower.tip.cell")
			row.cells[b] = cell
		end
		if i == 1 then
			row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -74)
		else
			row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, -2)
		end
		row:Hide()
		f.rows[i] = row
	end
	-- pied : defauts, vider, BENIR
	f.bDef = mkBtn(f, L("msg.pallypower.b.def"), 80, 20, function()
		for i = 1, M.nrost do
			local r = M.roster[i]
			local d = M.CLASSDEF[r.file]
			local a = asg(r.name)
			for k in pairs(a) do a[k] = nil end
			if d then
				for k, v in pairs(d) do
					if v then a[k] = true end
				end
			end
		end
		saveAssign()
		M.PaintCells()
	end)
	f.bDef:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.bClear = mkBtn(f, L("msg.pallypower.b.clear"), 80, 20, function() M.ClearAll() end)
	f.bClear:SetPoint("LEFT", f.bDef, "RIGHT", 6, 0)
	f.bCast = mkBtn(f, L("msg.pallypower.cast"), 110, 20, function() M.CastAll() end)
	f.bCast:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
	f.bAuto = mkBtn(f, L("msg.pallypower.b.auto"), 80, 20, function() M.AutoAssign() end)
	tip(f.bAuto, "msg.pallypower.tip.auto")
	f.bTank = mkBtn(f, L("msg.pallypower.b.tank"), 80, 20, function() M.TargetFlag("tank") end)
	tip(f.bTank, "msg.pallypower.tip.tank")
	f.bOne = mkBtn(f, L("msg.pallypower.b.single"), 80, 20, function() M.TargetFlag("single") end)
	tip(f.bOne, "msg.pallypower.tip.single")
	f.bRep = mkBtn(f, L("msg.pallypower.b.report"), 80, 20, function() M.Report() end)
	tip(f.bRep, "msg.pallypower.tip.report")
	f.bWis = mkBtn(f, L("msg.pallypower.b.whisper"), 80, 20, function() M.WhisperAll() end)
	tip(f.bWis, "msg.pallypower.tip.whisper")
	M.BuildMatrix(f)
	f.bView = mkBtn(f, EMPTY, 96, 20, function() C.Set("pallypower.compact", not M.Compact()) end)
	f.bView:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
	f.bTeam = mkBtn(f, L("msg.pallypower.b.team"), 62, 18, function() M.TeamToggle() end)
	f.bTeam:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -4)
	T.GearButton(f, "pallypower", { size = 14, point = "TOPRIGHT", x = -26, y = -4, title = L("msg.pallypower.gear") })
	f:SetScript("OnMouseWheel", function()
		if arg1 > 0 then M.Scroll(-3) else M.Scroll(3) end
	end)
	SUI.Layout.Register(f, "pp.win", "CENTER", 240, 0)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("pp.win", f, { label = L("mod.pallypower.title"), scale = false })
	end
	M.DragWire(f, "pp.win")
	T.OnAccent(function()
		if M.win and M.win:IsShown() then M.PaintCells() end
	end)
end

-- ---------------------------------------------------------------- vue compacte : une icone par benediction et par classe
-- (dans l'esprit de la grille d'icones de l'addon PallyPower : colonnes = classes presentes, lignes = benedictions)
M.BICON = { kings = "Spell_Magic_MageArmor", wisdom = "Spell_Holy_SealOfWisdom", might = "Spell_Holy_FistOfJustice",
	salvation = "Spell_Holy_SealOfSalvation", light = "Spell_Holy_PrayerOfHealing02", sanctuary = "Spell_Holy_GreaterBlessingofSanctuary" }
M.CORDER = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "DRUID", "SHAMAN", "PALADIN" }
M.CCOORD = { WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.5, 0, 0.25 }, ROGUE = { 0.5, 0.75, 0, 0.25 }, DRUID = { 0.75, 1, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.5, 0.25, 0.5 }, PRIEST = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 } }
local CELL, GAP = 34, 4

function M.Compact()
	return C.Get("pallypower.compact") ~= false
end

-- (nombre de joueurs de la classe, nombre qui portent cette attribution)
function M.ClassState(file, b)
	local n, have = 0, 0
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			n = n + 1
			if M.Has(r.name, b) then have = have + 1 end
		end
	end
	return n, have
end

function M.SetClassBless(file, b, want)
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			local a = asg(r.name)
			if want then a[b] = true else a[b] = nil end
		end
	end
	saveAssign()
	M.PaintCells()
end

local function iconBtn(parent, tex)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(CELL)
	b:SetHeight(CELL)
	T.Backdrop(b, T.c.bg, T.c.border)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	if tex then b.icon:SetTexture(tex) end
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return b
end

function M.BuildMatrix(f)
	local mx = CreateFrame("Frame", nil, f)
	mx:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	mx:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	f.mx = mx
	mx.cols = {}
	for i = 1, M.MAXCLASS do
		local c = iconBtn(mx, "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		c.icon:SetTexCoord(0, 0.25, 0, 0.25)
		c.count = T.Text(c, 10, T.c.text, "CENTER", true)
		c.count:SetPoint("BOTTOM", c, "BOTTOM", 0, 2)
		c:SetScript("OnClick", function()
			if this.file then M.SetClass(this.file, arg1 ~= "RightButton") end
		end)
		c:Hide()
		mx.cols[i] = c
	end
	mx.rows = {}
	for j = 1, getn(M.BLESS) do
		local b = M.BLESS[j]
		local row = { cells = {} }
		row.head = iconBtn(mx, "Interface\\Icons\\" .. M.BICON[b])
		row.head.bless = b
		row.head:SetScript("OnClick", function()
			if arg1 == "RightButton" then M.SetAll(this.bless, false) else M.SetAll(this.bless, not M.AllHave(this.bless)) end
		end)
		row.label = T.Text(mx, 11, T.c.text, "LEFT")
		row.label:SetText(L("mod.pallypower.bless." .. b))
		for i = 1, M.MAXCLASS do
			local cell = iconBtn(mx, "Interface\\Icons\\" .. M.BICON[b])
			cell.bless = b
			cell:SetScript("OnClick", function()
				local c = this
				if not c.file then return end
				local n, have = M.ClassState(c.file, c.bless)
				if arg1 == "RightButton" then M.SetClassBless(c.file, c.bless, false) else M.SetClassBless(c.file, c.bless, have < n) end
			end)
			cell:Hide()
			row.cells[i] = cell
		end
		mx.rows[j] = row
	end
	mx:Hide()
end

-- Place et peint la grille compacte : classes presentes en colonnes, une icone par benediction.
function M.PaintMatrix()
	local f = M.win
	if not f or not f.mx then return end
	local mx = f.mx
	local ar, ag, ab = T.Accent()
	local bc = T.c.border
	local x0 = 10 + 96
	local n = 0
	local idx
	for idx = 1, getn(M.CORDER) do
		local file = M.CORDER[idx]
		if M.classes[file] then
			n = n + 1
			local x = x0 + (n - 1) * (CELL + GAP)
			local c = mx.cols[n]
			c.file = file
			local tc = M.CCOORD[file]
			if tc then c.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", f, "TOPLEFT", x, -34)
			local cnt = 0
			for i = 1, M.nrost do if M.roster[i].file == file then cnt = cnt + 1 end end
			c.count:SetText(cnt)
			c:Show()
			local j
			for j = 1, getn(M.BLESS) do
				local cell = mx.rows[j].cells[n]
				cell.file = file
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(34 + CELL + 10 + (j - 1) * (CELL + GAP)))
				local nm, have = M.ClassState(file, M.BLESS[j])
				if nm > 0 and have == nm then
					cell.icon:SetVertexColor(1, 1, 1, 1)  -- style:ok
					cell:SetBackdropBorderColor(ar, ag, ab, 1)
				elseif have > 0 then
					cell.icon:SetVertexColor(0.8, 0.8, 0.8, 0.7)  -- style:ok
					cell:SetBackdropBorderColor(ar, ag, ab, 0.5)
				else
					cell.icon:SetVertexColor(0.35, 0.35, 0.35, 0.45)  -- style:ok
					cell:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
				end
				cell:Show()
			end
		end
	end
	local i2
	for i2 = n + 1, M.MAXCLASS do
		mx.cols[i2].file = nil
		mx.cols[i2]:Hide()
		local j2
		for j2 = 1, getn(M.BLESS) do
			mx.rows[j2].cells[i2].file = nil
			mx.rows[j2].cells[i2]:Hide()
		end
	end
	local j3
	for j3 = 1, getn(M.BLESS) do
		local row = mx.rows[j3]
		local y = -(34 + CELL + 10 + (j3 - 1) * (CELL + GAP))
		row.head:ClearAllPoints()
		row.head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
		row.label:ClearAllPoints()
		row.label:SetPoint("LEFT", row.head, "RIGHT", 6, 0)
		if M.AllHave(M.BLESS[j3]) then
			row.head.icon:SetVertexColor(1, 1, 1, 1)  -- style:ok
			row.head:SetBackdropBorderColor(ar, ag, ab, 1)
		else
			row.head.icon:SetVertexColor(0.8, 0.8, 0.8, 0.8)  -- style:ok
			row.head:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
		end
	end
end

-- Bascule entre la vue compacte (par classe) et la vue detaillee (par joueur).
function M.ApplyView()
	local f = M.win
	if not f then return end
	if C.Get("pallypower.team") then
		M.TeamApply()
		return
	end
	if M.twin then M.twin:Hide() end
	f.bTeam.txt:SetText(L("msg.pallypower.b.team"))
	local compact = M.Compact()
	if compact then
		local n = 0
		for _ in pairs(M.classes) do n = n + 1 end
		if n < 4 then n = 4 end
		local W = 10 + 96 + n * (CELL + GAP) + 10
		f:SetWidth(W)
		f:SetHeight(34 + CELL + 10 + getn(M.BLESS) * (CELL + GAP) + 4 + 4 * 24 + 6)
		local w3 = floor((W - 28) / 3)
		local w2 = floor((W - 24) / 2)
		M.Put(f.bRep, 10, 80, w2)
		M.Put(f.bWis, 14 + w2, 80, w2)
		M.Put(f.bTank, 10, 56, w2)
		M.Put(f.bOne, 14 + w2, 56, w2)
		M.Put(f.bAuto, 10, 32, w3)
		M.Put(f.bDef, 14 + w3, 32, w3)
		M.Put(f.bClear, 18 + 2 * w3, 32, w3)
		M.Put(f.bView, 10, 8, w2)
		M.Put(f.bCast, 14 + w2, 8, w2)
		f.mx:Show()
		for _, b in pairs(f.allB) do b:Hide() end
		for i = 1, M.MAXCLASS do f.classB[i]:Hide() end
		for i = 1, M.ROWS do f.rows[i]:Hide() end
		f.bView.txt:SetText(L("msg.pallypower.viewdetail"))
	else
		f:SetWidth(M.WinW())
		f:SetHeight(520)
		M.Put(f.bDef, 10, 8, 80)
		M.Put(f.bClear, 94, 8, 80)
		M.Put(f.bAuto, 178, 8, 80)
		M.Put(f.bView, M.WinW() - 10 - 110 - 6 - 96, 8, 96)
		M.Put(f.bCast, M.WinW() - 10 - 110, 8, 110)
		f.bTank:Hide()
		f.bOne:Hide()
		M.Put(f.bRep, 10, 36, 100)
		M.Put(f.bWis, 114, 36, 100)
		f.mx:Hide()
		for _, b in pairs(f.allB) do b:Show() end
		f.bView.txt:SetText(L("msg.pallypower.viewclass"))
		M.PaintRows()
	end
end

-- Tout le monde dans la liste porte-t-il cette attribution ? (bouton d'en-tete : tout / personne)
function M.AllHave(b)
	if M.nrost == 0 then return false end
	for i = 1, M.nrost do
		if not M.Has(M.roster[i].name, b) then return false end
	end
	return true
end

function M.Scroll(d)
	if not M.win then return end
	local maxoff = mmax(0, M.nrost - M.view)
	M.offset = mmax(0, mmin(maxoff, M.offset + d))
	M.PaintRows()
end

-- Peint les lignes visibles (noms, couleurs de classe) et rattache les cases a leur joueur.
function M.PaintRows()
	local f = M.win
	if not f then return end
	if M.Compact() or C.Get("pallypower.team") then return end
	-- hauteur ADAPTEE : la fenetre epouse le nombre de joueurs affiches (fini la moitie d ecran vide)
	local vis = 0
	for i2 = M.offset + 1, M.offset + M.view do
		if M.roster[i2] then vis = vis + 1 end
	end
	local want = 30 + 18 + 6 + max(vis, 1) * (14 + 4) + 16 + 4 * 24 + 10
	if f:GetHeight() ~= want then f:SetHeight(want) end
	for i = 1, M.ROWS do
		local row = f.rows[i]
		local r = M.roster[i]
		if r and i > M.offset and i <= M.offset + M.view then
			row.name:SetText(r.name)
			local cc = RAID_CLASS_COLORS[r.file]
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			row._n = r.name
			local fa = M.assign[r.name]
			M.PaintFlag(row.bT, fa and fa.tank)
			M.PaintFlag(row.bS, fa and fa.single)
			row:Show()
			for j = 1, getn(M.BLESS) do
				row.cells[M.BLESS[j]].who = r.name
			end
		else
			row._n = nil
			row:Hide()
		end
	end
end

-- Peint l'ETAT des cases (attribuee = bordure accent) sans reconstruire.
function M.PaintCells()
	local f = M.win
	if not f or not f:IsShown() then return end
	if M.Compact() then
		M.PaintMatrix()
		M.PaintStatus()
		return
	end
	local ar, ag, ab = T.Accent()
	local bc = T.c.border
	for i = 1, M.ROWS do
		local row = f.rows[i]
		if row:IsShown() and row._n then
			for j = 1, getn(M.BLESS) do
				local cell = row.cells[M.BLESS[j]]
				if not cell.ico then
					cell.ico = cell:CreateTexture(nil, "ARTWORK")
					cell.ico:SetWidth(11)
					cell.ico:SetHeight(11)
					cell.ico:SetPoint("LEFT", cell, "LEFT", 3, 0)
					cell.ico:SetTexCoord(0.07, 0.93, 0.07, 0.93)
					cell.ico:SetTexture("Interface\\Icons\\" .. M.BICON[cell.bless])
				end
				if cell.who and M.Has(cell.who, cell.bless) then
					cell:SetBackdropBorderColor(ar, ag, ab, 1)
					cell:SetBackdropColor(ar, ag, ab, 0.22)          -- case attribuee : fond teinte + icone de la benediction
					cell.ico:Show()
				else
					cell:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
					local bg = T.c.bg
					cell:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
					cell.ico:Hide()
				end
				if not cell.ten then
					cell.ten = T.Text(cell, 10, T.c.text, "CENTER")
					cell.ten:SetPoint("CENTER", cell, "CENTER", 6, 0)
				end
				local aa = cell.who and M.assign[cell.who]
				cell.ten:SetText((aa and M.IsSingle(aa, cell.bless)) and "10 min" or EMPTY)
			end
		end
	end
	M.PaintClasses()
	M.PaintStatus()
end

-- Peint les boutons de classes presentes.
function M.PaintClasses()
	local f = M.win
	if not f then return end
	if M.Compact() or C.Get("pallypower.team") then return end
	local n = 0
	for file in pairs(M.classes) do
		n = n + 1
		local b = f.classB[n]
		if b then
			b.txt:SetText(file)
			b.file = file
			b:Show()
		end
	end
	for i = n + 1, M.MAXCLASS do
		f.classB[i].file = nil
		f.classB[i]:Hide()
	end
end

function M.PaintStatus()
	local f = M.win
	if not f then return end
	if M.npairs > 0 and M.qi < M.npairs then
		f.status:SetText(L("msg.pallypower.progress", M.qi, M.npairs))
	elseif M.nrost > 0 then
		f.status:SetText(L("msg.pallypower.count", M.nrost))
	else
		f.status:SetText(EMPTY)
	end
end

-- Reconstruit la grille (roster change) : lignes, classes, cases.
function M.Rebuild()
	M.Build()
	M.ApplyView()
	M.PaintRows()
	M.PaintCells()
end

function M.Open()
	if not M.on then return end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		if not M.demo then M.ScanRoster() end      -- en demonstration le groupe simule est conserve
		M.win:Show()
		M.Rebuild()
	end)
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.ToggleWin()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

-- ---------------------------------------------------------------- attribution automatique, tanks, benedictions de 10 min
-- Drapeaux par joueur (dans M.assign[nom]) : tank = recoit Rois + Puissance + Lumiere (jamais Salut) ; single = benedictions
-- SIMPLES (10 min) posees a ce joueur au lieu des benedictions superieures (utile pour un tank, un hybride, un joueur precis).
M.TANKSET = { "kings", "might", "light", "sanctuary" }   -- (2026-11-19) Sanctuary : la bene tank ajoutee aux tanks
M.HYBRID = { PALADIN = true, SHAMAN = true, DRUID = true }

-- Sorts connus du paladin (livre de sorts) : on n'attribue jamais une benediction qu'il ne possede pas.
function M.ScanKnown()
	local gsn = getglobal("GetSpellName")
	local known = {}
	local any = false
	if type(gsn) == "function" then
		for i = 1, 300 do
			local nm = gsn(i, "spell")
			if not nm then break end
			any = true
			known[fold(nm)] = true
		end
	end
	M.known = any and known or nil
end

function M.Knows(b)
	if not M.known then return true end
	local nm = (GAMEFR and M.SPELLS_FR[b]) or M.SPELLS[b]
	return M.known[fold(nm)] and true or false
end

function M.SetFlag(name, flag, want)
	local a = asg(name)
	if want == nil then want = not a[flag] end
	if want then a[flag] = true else a[flag] = nil end
	saveAssign()
	M.PaintCells()
	M.PaintRows()
	return want
end

-- Jeu de benedictions conseille pour un joueur de la liste (selon sa classe, sa jauge de ressource et le drapeau tank).
function M.AutoSet(r)
	local a = M.assign and M.assign[r.name]
	local file = r.file
	local set
	local melee = false
	if a and a.tank then
		set = M.TANKSET
		melee = true
	elseif file == "WARRIOR" or file == "ROGUE" then
		set = { "kings", "might" }
		melee = true
	elseif file == "HUNTER" then
		set = { "kings", "might", "wisdom" }
		melee = true
	elseif file == "MAGE" or file == "WARLOCK" or file == "PRIEST" then
		set = { "kings", "wisdom" }
	else
		-- druide / chaman / paladin : rage ou energie = au corps a corps (puissance), mana = soutien (sagesse)
		local pt = 0
		local upt = getglobal("UnitPowerType")
		if type(upt) == "function" then pt = upt(r.unit) or 0 end
		if pt == 1 or pt == 3 then
			set = { "kings", "might" }
			melee = true
		else
			set = { "kings", "wisdom" }
		end
	end
	local out = {}
	for i = 1, getn(set) do
		if M.Knows(set[i]) then tinsert(out, set[i]) end
	end
	if C.Get("pallypower.autosalv") and not (a and a.tank) and M.Knows("salvation") then tinsert(out, "salvation") end
	return out
end

function M.AutoOne(r)
	local a = asg(r.name)
	for j = 1, getn(M.BLESS) do a[M.BLESS[j]] = nil end
	a.sg = nil
	-- LOGIQUE SIMPLE : ce qui fait partie du jeu par defaut de la classe (CLASSDEF) = benediction superieure de 30 min (une pose couvre toute
	-- la classe) ; ce qui s'en ecarte (tank, corps a corps d'une classe de soutien...) = 10 min sur CE joueur seulement, case marquee "10 min".
	local def = M.CLASSDEF[r.file] or {}
	local set = M.AutoSet(r)
	for i = 1, getn(set) do
		local b = set[i]
		if not M.PeerCovers(r.file, b) then
			a[b] = true
			if not def[b] then
				if not a.sg then a.sg = {} end
				a.sg[b] = true
			end
		end
	end
	-- PRIORITE PALATANK sur la Salut (2026-11-19) : un paladin avec le drapeau tank recoit la Salut
	-- (il s'en sert pour son swap OctoManaSwap) EN PLUS de son set tank (Sanctuary incluse depuis le TANKSET).
	-- Les autres tanks gardent Sanctuary sans Salut (la Salut sur un vrai tank = perte de menace).
	if r.file == "PALADIN" and a.tank and C.Get("pallypower.autosalv") and M.Knows("salvation") then
		a.salvation = true
		if not a.sg then a.sg = {} end
		a.sg.salvation = true
	end
	if C.Get("pallypower.autosingle") and (a.tank or M.HYBRID[r.file]) then a.single = true end
end

function M.AutoAssign()
	if M.nrost == 0 then M.ScanRoster() end
	for i = 1, M.nrost do M.AutoOne(M.roster[i]) end
	saveAssign()
	M.PaintCells()
	M.PaintRows()
	SUI.Print(L("msg.pallypower.autodone", M.nrost))
end

function M.ToggleFlag(n, flag)
	if M.nrost == 0 then M.ScanRoster() end
	local rr
	for i = 1, M.nrost do
		if M.roster[i].name == n then rr = M.roster[i] end
	end
	if not rr then
		SUI.Print(L("msg.pallypower.notinraid", n))
		return nil
	end
	local want = M.SetFlag(n, flag)
	if flag == "tank" and want then
		M.AutoOne(rr)
		saveAssign()
		M.PaintCells()
		M.PaintRows()
	end
	SUI.Print(L(want and ("msg.pallypower.flag." .. flag .. ".on") or ("msg.pallypower.flag." .. flag .. ".off"), n))
	return want
end

-- Joueur cible (le "focus" du 1.12) : bascule tank / 10 min sur lui, s il fait partie du groupe.
function M.TargetFlag(flag)
	local n = UnitName("target")
	if not n or not UnitExists("target") then
		SUI.Print(L("msg.pallypower.notarget"))
		return
	end
	M.ToggleFlag(n, flag)
end

function M.Put(b, x, y, w)
	b:ClearAllPoints()
	b:SetWidth(w)
	b:SetPoint("BOTTOMLEFT", M.win, "BOTTOMLEFT", x, y)
	b:Show()
end

function M.PaintFlag(b, on)
	local ar, ag, ab = T.Accent()
	local bc = T.c.border
	if on then
		b:SetBackdropBorderColor(ar, ag, ab, 1)
	else
		b:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
	end
end

-- Deplacement a la souris : glisser sur le fond (les boutons gardent leur clic). Meme enregistrement que le mode "Deplacer".
local function dragWire(f, key)
	local function stop()
		local fr = M.dragf
		if not fr then return end
		M.dragf = nil
		fr:StopMovingOrSizing()
		local l, b = fr:GetLeft(), fr:GetBottom()
		if not (l and b) then return end
		local sc = fr:GetScale() or 1
		local rec = SUI.Mover and SUI.Mover.items and SUI.Mover.items[key]
		if rec and SUI.Mover.Commit then
			SUI.Mover.Commit(rec, l * sc, b * sc)
		elseif SUI.Layout then
			local _, _, s = C.GetPos(SUI.Layout.ReadKey(key))
			C.SetPos(SUI.Layout.WriteKey(key), l * sc, b * sc, s)
			SUI.Layout.Apply(key)
		end
	end
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function()
		if arg1 ~= "LeftButton" or SUI.InCombat() then return end
		this:StartMoving()
		M.dragf = this
	end)
	f:SetScript("OnMouseUp", stop)
	f:SetScript("OnHide", stop)
end
M.DragWire = dragWire

-- ---------------------------------------------------------------- demonstration (/sui pp demo) : raid simule, vos attributions ne sont pas touchees
M.DEMOCLASS = { "WARRIOR", "WARRIOR", "ROGUE", "ROGUE", "HUNTER", "HUNTER", "MAGE", "MAGE", "MAGE", "MAGE", "WARLOCK", "WARLOCK", "WARLOCK",
	"PRIEST", "PRIEST", "PRIEST", "PRIEST", "DRUID", "DRUID", "DRUID", "SHAMAN", "SHAMAN", "SHAMAN" }

function M.Demo(on)
	if on == false then
		if not M.demo then return end
		M.demo = false
		M.assign = M.realAssign or M.assign
		M.realAssign = nil
		M.ScanRoster()
		M.PaintCells()
		SUI.Print(L("msg.pallypower.demo.off"))
		return
	end
	if not M.on then return end
	if not M.demo then M.realAssign = M.assign end
	M.demo = true
	M.assign = {}
	M.nrost = 0
	local n = 0
	for i = 1, 5 do
		n = n + 1
		M.roster[n] = { name = "Paladin" .. i, unit = "raid" .. n, file = "PALADIN" }
	end
	for i = 1, getn(M.DEMOCLASS) do
		n = n + 1
		M.roster[n] = { name = "Joueur" .. i, unit = "raid" .. n, file = M.DEMOCLASS[i] }
	end
	M.nrost = n
	M.ScanClasses()
	M.offset = 0
	asg("Joueur1").tank = true
	asg("Paladin3").tank = true
	M.AutoAssign()
	M.Build()
	M.win:Show()
	M.Rebuild()
	SUI.Print(L("msg.pallypower.demo.on", n))
end

-- ---------------------------------------------------------------- rapport : dire aux joueurs qui recoit quoi
local function className(file)
	local t = getglobal("LOCALIZED_CLASS_NAMES_MALE")
	return (t and t[file]) or file
end

-- Lignes du rapport : une par benediction, avec les classes completes puis les joueurs isoles ; derniere ligne : les 10 minutes.
function M.ReportLines()
	local lines = {}
	for j = 1, getn(M.BLESS) do
		local b = M.BLESS[j]
		local full, solo = {}, {}
		for _, file in ipairs(M.CORDER) do
			local n, have = M.ClassState(file, b)
			if n > 0 and have == n then
				tinsert(full, className(file))
			elseif have > 0 then
				for i = 1, M.nrost do
					local r = M.roster[i]
					if r.file == file and M.Has(r.name, b) then tinsert(solo, r.name) end
				end
			end
		end
		if getn(full) + getn(solo) > 0 then
			local who = table.concat(full, ", ")
			if getn(solo) > 0 then who = who .. (who ~= EMPTY and " + " or EMPTY) .. table.concat(solo, ", ") end
			tinsert(lines, L("msg.pallypower.bless." .. b) .. " : " .. who)
		end
	end
	local sg = {}
	for i = 1, M.nrost do
		local a = M.assign[M.roster[i].name]
		if M.AnySingle(a) then tinsert(sg, M.roster[i].name) end
	end
	if getn(sg) > 0 then tinsert(lines, L("msg.pallypower.rep.single") .. " : " .. table.concat(sg, ", ")) end
	return lines
end

-- Envoie le rapport au chat du raid (sinon du groupe) ; hors groupe il s'affiche chez toi seulement.
function M.Report()
	local lines = M.ReportLines()
	if getn(lines) == 0 then
		SUI.Print(L("msg.pallypower.rep.none"))
		return 0
	end
	local ch
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then ch = "RAID" elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then ch = "PARTY" end
	local head = L("msg.pallypower.rep.head")
	if ch then SendChatMessage(head, ch) else SUI.Print(head) end
	for i = 1, getn(lines) do
		local t = lines[i]
		if string.len(t) > 250 then t = strsub(t, 1, 247) .. "..." end
		if ch then SendChatMessage(t, ch) else SUI.Print(t) end
	end
	return getn(lines)
end

-- Texte prive d'un joueur : ses benedictions (et "10 min" si besoin), nil s'il n'en a aucune.
function M.WhisperText(name)
	local a = M.assign[name]
	if not a then return nil end
	local t = {}
	for j = 1, getn(M.BLESS) do
		if a[M.BLESS[j]] then tinsert(t, L("msg.pallypower.bless." .. M.BLESS[j])) end
	end
	if getn(t) == 0 then return nil end
	local s = L("msg.pallypower.whisper", table.concat(t, ", "))
	if M.AnySingle(a) then s = s .. " " .. L("msg.pallypower.whisper.single") end
	return s
end

-- Un message prive par joueur, espaces (anti-flood) : 1 toutes les 0,6 s.
function M.WhisperAll()
	if M.wtask then SUI.Cancel(M.wtask) M.wtask = nil end
	M.wq = {}
	local me = UnitName("player")
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.name ~= me then
			local t = M.WhisperText(r.name)
			if t then tinsert(M.wq, { r.name, t }) end
		end
	end
	M.wi = 0
	if getn(M.wq) == 0 then
		SUI.Print(L("msg.pallypower.rep.none"))
		return 0
	end
	SUI.Print(L("msg.pallypower.rep.wsent", getn(M.wq)))
	M.wtask = SUI.Every(0.6, function()
		M.wi = M.wi + 1
		local e = M.wq[M.wi]
		if not e then
			SUI.Cancel(M.wtask)
			M.wtask = nil
			return
		end
		SendChatMessage(e[2], "WHISPER", nil, e[1])
	end, "pp.whisper")
	return getn(M.wq)
end

-- ---------------------------------------------------------------- synchro entre paladins (meme canal que PallyPowerTW : prefixe PLPWR)
M.SYNC_PREFIX = "PLPWR"
M.SYNC_CLS = { WARRIOR = 0, ROGUE = 1, PRIEST = 2, DRUID = 3, PALADIN = 4, HUNTER = 5, MAGE = 6, WARLOCK = 7, SHAMAN = 8 }
M.SYNC_BID = { wisdom = 0, might = 1, salvation = 2, light = 3, kings = 4, sanctuary = 5 }
M.peers = {}

local function syncChan()
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then return "RAID" end
	if GetNumPartyMembers and GetNumPartyMembers() > 0 then return "PARTY" end
	return nil
end

local function syncSend(msg)
	local ch = syncChan()
	local sam = getglobal("SendAddonMessage")
	if not ch or type(sam) ~= "function" then return false end
	sam(M.SYNC_PREFIX, msg, ch, UnitName("player"))
	return true
end

-- Texte "SELF" : rangs des benedictions connues puis, par classe (0-9), la benediction que JE donne ("n" = aucune).
function M.SyncSelfText()
	local s = "SELF "
	local order = { "wisdom", "might", "salvation", "light", "kings", "sanctuary" }      -- ids PLPWR 0 a 5
	for i = 1, 6 do
		s = s .. (M.Knows(order[i]) and "10" or "nn")
	end
	s = s .. "@"
	for id = 0, 9 do
		local ch = "n"
		for file, cid in pairs(M.SYNC_CLS) do
			if cid == id then
				for j = 1, getn(M.BLESS) do
					local n, have = M.ClassState(file, M.BLESS[j])
					if n > 0 and have == n then ch = tostring(M.SYNC_BID[M.BLESS[j]]) break end
				end
			end
		end
		s = s .. ch
	end
	return s
end

-- Envoie mes attributions aux autres paladins (utile seulement si je suis paladin et qu'il y a un groupe).
function M.SyncSend()
	if M.demo or C.Get("pallypower.sync") == false then return false end
	local _, cls = UnitClass("player")
	if cls ~= "PALADIN" then return false end
	return syncSend(M.SyncSelfText())
end

-- Envoi differe (regroupe plusieurs clics en un seul message).
function M.SyncSoon()
	if M.demo or C.Get("pallypower.sync") == false then return end
	if M.stask then SUI.Cancel(M.stask) end
	M.stask = SUI.After(1.2, function() M.stask = nil M.SyncSend() end, "pp.sync")
end

-- Un AUTRE paladin donne-t-il deja cette benediction a cette classe ? (option de repartition, vrai par defaut)
function M.PeerCovers(file, b)
	if C.Get("pallypower.autosplit") == false then return false end
	local cid, bid = M.SYNC_CLS[file], M.SYNC_BID[b]
	if not cid or not bid then return false end
	for name, p in pairs(M.peers) do
		if p[cid] == bid then return true end
	end
	return false
end

local function classNameById(id)
	for file, cid in pairs(M.SYNC_CLS) do
		if cid == id then return className(file) end
	end
	return "?"
end

local function blessNameById(bid)
	for b, id in pairs(M.SYNC_BID) do
		if id == bid then return L("msg.pallypower.bless." .. b) end
	end
	return "?"
end

-- "Rois : Mage, Pretre ; Sagesse : Druide" pour un paladin pair.
function M.PeerText(name)
	local p = M.peers[name]
	if not p then return nil end
	local by = {}
	for id = 0, 9 do
		local bid = p[id]
		if bid and bid >= 0 then
			if not by[bid] then by[bid] = {} end
			tinsert(by[bid], classNameById(id))
		end
	end
	local parts = {}
	for bid = 0, 5 do
		if by[bid] then tinsert(parts, blessNameById(bid) .. " : " .. table.concat(by[bid], ", ")) end
	end
	if getn(parts) == 0 then return nil end
	return table.concat(parts, " ; ")
end

-- Liste lisible de ce que font les autres paladins (une ligne par paladin).
function M.PeerLines()
	local out = {}
	for name in pairs(M.peers) do
		local t = M.PeerText(name)
		tinsert(out, name .. " -> " .. (t or L("msg.pallypower.sync.none")))
	end
	table.sort(out)
	return out
end

function M.OnAddon(ev, a1, a2, a3, a4)
	if not M.on or type(a2) ~= "string" or C.Get("pallypower.sync") == false then return end
	if a1 == M.SHK_PREFIX then M.TeamOnShk(a2, a4) return end
	if a1 ~= M.SYNC_PREFIX then return end
	local sender = a4
	if not sender or sender == UnitName("player") then return end
	if a2 == "REQ" then
		M.SyncSoon()
		return
	end
	local before = M.PeerText(sender)
	local changed = false
	if strsub(a2, 1, 5) == "SELF " then
		local _, _, rest = string.find(a2, "^SELF [%w]*@?([%w]*)")
		local p = {}
		for id = 0, 9 do
			local ch = strsub(rest or "", id + 1, id + 1)
			p[id] = tonumber(ch) or -1
		end
		M.peers[sender] = p
		local _, _, kn = string.find(a2, "^SELF (%w*)@")
		if kn then
			local k = {}
			for i = 0, 5 do
				local pr = strsub(kn, i * 2 + 1, i * 2 + 2)
				if pr ~= "" and pr ~= "nn" then k[i] = true end
			end
			M.peerKnown[sender] = k
		end
		changed = true
	elseif strsub(a2, 1, 7) == "ASSIGN " then
		local _, _, name, class, skill = string.find(a2, "^ASSIGN (%S+) (%S+) (%S+)")
		if name == sender and class and skill then
			local p = M.peers[sender] or {}
			p[tonumber(class) or 0] = tonumber(skill) or -1
			M.peers[sender] = p
			changed = true
		elseif name == UnitName("player") and class and skill then
			M.TeamOnAssign(sender, tonumber(class), tonumber(skill))
		end
	elseif a2 == "CLEAR" then
		if M.peers[sender] then M.peers[sender] = nil changed = true end
	end
	if changed then
		local now = M.PeerText(sender)
		if now ~= before and C.Get("pallypower.syncmsg") ~= false then
			SUI.Print(L("msg.pallypower.sync.changed", sender, now or L("msg.pallypower.sync.none")))
		end
		if M.win and M.win:IsShown() and M.PaintCells then M.PaintCells() end
		if M.twin and M.twin:IsShown() then M.TeamPaint() end
	end
end

function M.SyncReq()
	syncSend("REQ")
end

-- ---------------------------------------------------------------- vue "Paladins" : ce que donnent les autres paladins, reglage a distance, repartition auto
-- Lignes = paladins (toi + ceux qui ont envoye leur SELF), colonnes = classes presentes, case = benediction donnee a la classe.
-- Clic : change la benediction (parmi celles que CE paladin connait) ; clic droit : 10 min / 30 min. Pour un AUTRE paladin, l'ordre part
-- en message ASSIGN (protocole PLPWR) : il l'applique s'il accepte les ordres du chef (option pallypower.remote). Le reglage 10 min
-- n'a pas de message dans PLPWR : message ShikiUI "SHKPP S10" (compris seulement par les paladins qui ont ShikiUI).
M.SHK_PREFIX = "SHKPP"
M.peerKnown = {}      -- [nom] = { [id benediction PLPWR] = true } (lu dans leur SELF)
M.peerSingle = {}     -- [nom] = { [id classe] = true } : 10 min demande a ce paladin pour cette classe

local function fileOfCid(cid)
	for f, id in pairs(M.SYNC_CLS) do
		if id == cid then return f end
	end
	return nil
end

local function bessOfBid(bid)
	for b, id in pairs(M.SYNC_BID) do
		if id == bid then return b end
	end
	return nil
end

local function shkSend(msg)
	local ch = syncChan()
	local sam = getglobal("SendAddonMessage")
	if not ch or type(sam) ~= "function" then return false end
	sam(M.SHK_PREFIX, msg, ch, UnitName("player"))
	return true
end

-- Benediction que JE donne a une classe (premiere complete) et son mode.
function M.MyClassBless(file)
	for j = 1, getn(M.BLESS) do
		local n, have = M.ClassState(file, M.BLESS[j])
		if n > 0 and have == n then return M.BLESS[j] end
	end
	return nil
end

function M.MyClassSingle(file, b)
	if not b then return false end
	local any = false
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			any = true
			if not M.IsSingle(M.assign[r.name], b) then return false end
		end
	end
	return any
end

-- Si l'addon PallyPower d'origine est charge en meme temps, il garde sa propre table (PallyPower_Assignments) et sa grille restait vide
-- pour moi apres "Auto equipe" : on y recopie ma benediction de classe (identifiants 0-5, -1 = aucune ; classes 0-8 = SYNC_CLS).
function M.MirrorToPallyPower(file, b)
	local pa = getglobal("PallyPower_Assignments")
	local me = UnitName("player")
	local cid = M.SYNC_CLS and M.SYNC_CLS[file]
	if type(pa) ~= "table" or not me or cid == nil then return end
	if type(pa[me]) ~= "table" then return end
	pa[me][cid] = b and M.SYNC_BID[b] or -1
	local up = getglobal("PallyPower_UpdateUI")
	if type(up) == "function" then pcall(up) end
end

-- Je donne EXACTEMENT cette benediction (ou aucune) a toute la classe ; single = 10 min.
function M.ApplyClassAssign(file, b, single)
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			local a = asg(r.name)
			unsingle(a)
			for j = 1, getn(M.BLESS) do a[M.BLESS[j]] = nil end
			a.sg = nil
			if b then
				a[b] = true
				if single then a.sg = {} a.sg[b] = true end
			end
		end
	end
	saveAssign()
	M.MirrorToPallyPower(file, b)
	M.PaintCells()
	M.PaintRows()
end

-- Qui a le droit de regler mes benedictions : le chef / assistants du raid, le chef du groupe.
function M.CanRemote(sender)
	if C.Get("pallypower.remote") == false then return false end
	local nr = GetNumRaidMembers and GetNumRaidMembers() or 0
	if nr > 0 then
		for i = 1, nr do
			local n, rank = GetRaidRosterInfo(i)
			if n == sender then return (rank or 0) >= 1 end
		end
		return false
	end
	local np = GetNumPartyMembers and GetNumPartyMembers() or 0
	for i = 1, np do
		if UnitName("party" .. i) == sender then
			return UnitIsPartyLeader and UnitIsPartyLeader("party" .. i) and true or false
		end
	end
	return false
end

function M.TeamOnAssign(sender, cid, bid)
	if not cid or not bid or not M.CanRemote(sender) then return end
	local file = fileOfCid(cid)
	if not file then return end
	local b = (bid >= 0) and bessOfBid(bid) or nil
	if b and not M.Knows(b) then return end
	M.ApplyClassAssign(file, b, false)
	SUI.Print(L("msg.pallypower.team.recv", sender, className(file), b and L("msg.pallypower.bless." .. b) or L("msg.pallypower.team.tip.none")))
end

function M.TeamOnShk(msg, sender)
	if not sender or sender == UnitName("player") then return end
	local _, _, name, cid, flag = string.find(msg, "^S10 (%S+) (%d+) (%d)")
	if not name or name ~= UnitName("player") or not M.CanRemote(sender) then return end
	local file = fileOfCid(tonumber(cid))
	local b = file and M.MyClassBless(file)
	if b then M.ApplyClassAssign(file, b, flag == "1") end
end

function M.TeamPaladins()
	local out = {}
	local _, cls = UnitClass("player")
	if cls == "PALADIN" then tinsert(out, (UnitName("player"))) end
	local names = {}
	for n in pairs(M.peers) do tinsert(names, n) end
	table.sort(names)
	for i = 1, getn(names) do tinsert(out, names[i]) end
	return out
end

function M.TeamKnows(name, b)
	if name == UnitName("player") then return M.Knows(b) end
	local k = M.peerKnown[name]
	if not k then return true end
	return k[M.SYNC_BID[b]] and true or false
end

-- Benediction de classe d'un paladin telle que l'addon PallyPower d'origine la connait (il recoit les messages de tout le monde) :
-- nil = pas de table pour lui ; false = aucune ; sinon l'identifiant (wisdom, might...).
function M.OrigBless(name, file)
	local pa = getglobal("PallyPower_Assignments")
	local cid = M.SYNC_CLS[file]
	if type(pa) ~= "table" or type(pa[name]) ~= "table" or cid == nil then return nil end
	local v = pa[name][cid]
	if type(v) ~= "number" then return nil end
	if v < 0 then return false end
	return bessOfBid(v) or false
end

function M.TeamGet(name, file)
	if name == UnitName("player") then
		local mine = M.MyClassBless(file)
		if mine then return mine end
		return M.OrigBless(name, file) or nil       -- classe incomplete chez moi : on montre ce que l'addon d'origine a retenu
	end
	local o = M.OrigBless(name, file)
	if o ~= nil then return o or nil end            -- l'addon d'origine fait foi quand il est la : plus de ligne qui diverge
	local p = M.peers[name]
	local cid = M.SYNC_CLS[file]
	local bid = p and cid and p[cid]
	if bid and bid >= 0 then return bessOfBid(bid) end
	return nil
end

function M.TeamSingle(name, file)
	if name == UnitName("player") then return M.MyClassSingle(file, M.MyClassBless(file)) end
	local ps = M.peerSingle[name]
	local cid = M.SYNC_CLS[file]
	return (ps and cid and ps[cid]) and true or false
end

function M.TeamSet(name, file, b, single)
	if name == UnitName("player") then
		M.ApplyClassAssign(file, b, single)
		return
	end
	local cid = M.SYNC_CLS[file]
	if not cid then return end
	local bid = b and M.SYNC_BID[b] or -1
	syncSend("ASSIGN " .. name .. " " .. cid .. " " .. bid)
	shkSend("S10 " .. name .. " " .. cid .. " " .. ((b and single) and 1 or 0))
	local p = M.peers[name] or {}
	p[cid] = bid
	M.peers[name] = p
	local ps = M.peerSingle[name] or {}
	ps[cid] = (b and single) and true or nil
	M.peerSingle[name] = ps
end

function M.TeamCycle(name, file)
	local opts = {}
	for j = 1, getn(M.BLESS) do
		if M.TeamKnows(name, M.BLESS[j]) then tinsert(opts, M.BLESS[j]) end
	end
	local cur = M.TeamGet(name, file)
	local idx = 0
	for i = 1, getn(opts) do
		if opts[i] == cur then idx = i end
	end
	local nxt = opts[idx + 1]
	M.TeamSet(name, file, nxt, M.TeamSingle(name, file))
end

function M.TeamToggle10(name, file)
	local cur = M.TeamGet(name, file)
	if not cur then return end
	M.TeamSet(name, file, cur, not M.TeamSingle(name, file))
end

M.TEAMWANT = { "kings", "wisdom", "might" }

-- Repartition automatique : pour chaque classe presente, chaque benediction voulue (jeu par defaut) va au paladin qui la connait
-- et qui en donne le moins ; un paladin donne UNE benediction par classe (limite du protocole). Seul, on retombe sur l'auto simple.
function M.TeamAuto()
	if M.nrost == 0 then M.ScanRoster() end
	local pal = M.TeamPaladins()
	if getn(pal) < 2 then
		M.AutoAssign()
		return
	end
	local load = {}
	for i = 1, getn(pal) do load[pal[i]] = 0 end
	local plan = {}
	local stick = {}      -- benediction (Puissance et Sagesse comptent pour une) -> paladin qui la donne deja : chaque paladin garde la sienne sur toutes les classes
	for idx = 1, getn(M.CORDER) do
		local file = M.CORDER[idx]
		if M.classes[file] then
			local def = M.CLASSDEF[file] or {}
			local want = {}
			for k = 1, getn(M.TEAMWANT) do
				if def[M.TEAMWANT[k]] then tinsert(want, M.TEAMWANT[k]) end
			end
			if C.Get("pallypower.autosalv") then tinsert(want, "salvation") end
			-- plus de paladins que de benedictions : les suivants donnent Lumiere puis Salut (comme l'attribution de l'addon PallyPower d'origine)
			local function hasW(w) for q = 1, getn(want) do if want[q] == w then return true end end return false end
			if getn(pal) > getn(want) and not hasW("light") then tinsert(want, "light") end
			if getn(pal) > getn(want) and not hasW("salvation") then tinsert(want, "salvation") end
			-- les benedictions que peu de paladins connaissent sont placees d'abord
			local cap = {}
			for k = 1, getn(want) do
				cap[want[k]] = 0
				for i = 1, getn(pal) do
					if M.TeamKnows(pal[i], want[k]) then cap[want[k]] = cap[want[k]] + 1 end
				end
			end
			for k = 2, getn(want) do
				local v, j = want[k], k - 1
				while j >= 1 and cap[want[j]] > cap[v] do
					want[j + 1] = want[j]
					j = j - 1
				end
				want[j + 1] = v
			end
			local used = {}
			plan[file] = {}
			for k = 1, getn(want) do
				local best
				local sk = (want[k] == "might" or want[k] == "wisdom") and "mw" or want[k]
				local pv = stick[sk]
				if pv and not used[pv] and M.TeamKnows(pv, want[k]) then best = pv end
				if not best then
					for i = 1, getn(pal) do
						local p = pal[i]
						if not used[p] and M.TeamKnows(p, want[k]) and (not best or load[p] < load[best]) then best = p end
					end
				end
				if best then
					used[best] = true
					load[best] = load[best] + 1
					plan[file][best] = want[k]
					stick[sk] = best
				end
			end
		end
	end
	local step = 0
	for idx = 1, getn(M.CORDER) do
		local file = M.CORDER[idx]
		if plan[file] then
			for i = 1, getn(pal) do
				local p = pal[i]
				local b = plan[file][p]
				if p == UnitName("player") then
					M.TeamSet(p, file, b, false)
				else
					step = step + 1
					SUI.After(0.25 * step, function() M.TeamSet(p, file, b, false) M.TeamPaint() end, "pp.teamauto")
				end
			end
		end
	end
	SUI.Print(L("msg.pallypower.team.autodone", getn(pal)))
	M.TeamPaint()
end

-- ---- fenetre
local TC, TG = 32, 4

function M.TeamBuild()
	if M.twin then return end
	M.Build()
	-- 3e vue de la fenetre principale : un cadre enfant qui la recouvre (pas de fenetre separee)
	local f = CreateFrame("Frame", "ShikiUI_PallyTeam", M.win)
	f:SetAllPoints(M.win)
	f:Hide()
	M.twin = f
	f.hint = T.Text(f, 10, T.c.dim, "LEFT")
	f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -26)
	f.hint:SetText(L("msg.pallypower.team.hint"))
	f.empty = T.Text(f, 11, T.c.dim, "LEFT")
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -50)
	f.empty:SetWidth(300)
	f.empty:SetText(L("msg.pallypower.team.none"))
	f.hc = {}
	for i = 1, M.MAXCLASS do
		local h = T.Text(f, 8, T.c.dim, "CENTER")
		h:SetWidth(TC + TG)
		h:Hide()
		f.hc[i] = h
	end
	f.rows = {}
	for r = 1, 8 do
		local row = { cells = {} }
		row.name = T.Text(f, 11, T.c.text, "LEFT", true)
		row.name:SetWidth(100)
		row.name:Hide()
		for i = 1, M.MAXCLASS do
			local c = CreateFrame("Button", nil, f)
			c:SetWidth(TC)
			c:SetHeight(TC)
			T.Backdrop(c, T.c.bg, T.c.border)
			c.icon = c:CreateTexture(nil, "ARTWORK")
			c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
			c.icon:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
			c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			c.ten = T.Text(c, 10, T.c.text, "RIGHT", true)
			c.ten:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
			c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			c:SetScript("OnClick", function()
				if not (this.pal and this.file) then return end
				if arg1 == "RightButton" then M.TeamToggle10(this.pal, this.file) else M.TeamCycle(this.pal, this.file) end
				M.TeamPaint()
			end)
			c:SetScript("OnEnter", function()
				if not (this.pal and this.file) then return end
				GameTooltip:SetOwner(this, "ANCHOR_TOP")
				local b = M.TeamGet(this.pal, this.file)
				GameTooltip:AddLine(this.pal .. " - " .. className(this.file), 1, 1, 1, 1)
				if b then
					GameTooltip:AddLine(L("msg.pallypower.bless." .. b) .. " : " .. L(M.TeamSingle(this.pal, this.file) and "msg.pallypower.team.tip.10" or "msg.pallypower.team.tip.30"), 1, 1, 1, 1)
				else
					GameTooltip:AddLine(L("msg.pallypower.team.tip.none"), 0.7, 0.7, 0.7, 1)
				end
				if this.pal ~= UnitName("player") then GameTooltip:AddLine(L("msg.pallypower.team.tip.remote"), 0.7, 0.7, 0.7, 1) end
				GameTooltip:Show()
			end)
			c:SetScript("OnLeave", function() GameTooltip:Hide() end)
			c:Hide()
			row.cells[i] = c
		end
		f.rows[r] = row
	end
	f.bAuto = mkBtn(f, L("msg.pallypower.team.auto"), 110, 20, function() M.TeamAuto() end)
	f.bAuto:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.bRef = mkBtn(f, L("msg.pallypower.team.refresh"), 90, 20, function() M.SyncReq() M.SyncSend() M.TeamPaint() end)
	f.bRef:SetPoint("LEFT", f.bAuto, "RIGHT", 6, 0)
end

function M.TeamPaint()
	local f = M.twin
	if not f or not f:IsShown() then return end
	local pal = M.TeamPaladins()
	local cls = {}
	for i = 1, getn(M.CORDER) do
		if M.classes[M.CORDER[i]] then tinsert(cls, M.CORDER[i]) end
	end
	local ncls = mmax(getn(cls), 4)
	local np = mmin(getn(pal), 8)
	local x0 = 10 + 104
	local W = mmax(380, x0 + ncls * (TC + TG) + 10)
	M.win:SetWidth(W)
	M.win:SetHeight(74 + mmax(np, 1) * (TC + TG) + 36)
	M.Put(M.win.bCast, W - 10 - 110, 8, 110)
	if np == 0 then f.empty:Show() else f.empty:Hide() end
	for i = 1, M.MAXCLASS do
		local h = f.hc[i]
		local file = cls[i]
		if file and np > 0 then
			h:SetText(className(file))
			h:ClearAllPoints()
			h:SetPoint("TOP", f, "TOPLEFT", x0 + (i - 1) * (TC + TG) + TC / 2, -48)
			h:Show()
		else
			h:Hide()
		end
	end
	for r = 1, 8 do
		local row = f.rows[r]
		local name = pal[r]
		if name and r <= np then
			local y = -(42 + TC - 4 + 4 + (r - 1) * (TC + TG))
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y - 9)
			row.name:SetText(name == UnitName("player") and L("msg.pallypower.team.me", name) or name)
			row.name:Show()
			for i = 1, M.MAXCLASS do
				local c = row.cells[i]
				local file = cls[i]
				if file then
					c.pal, c.file = name, file
					c:ClearAllPoints()
					c:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + (i - 1) * (TC + TG), y)
					local b = M.TeamGet(name, file)
					if b then
						c.icon:SetTexture("Interface\\Icons\\" .. M.BICON[b])
						c.icon:Show()
					else
						c.icon:Hide()
					end
					c.ten:SetText((b and M.TeamSingle(name, file)) and "10" or EMPTY)
					c:Show()
				else
					c.pal, c.file = nil, nil
					c:Hide()
				end
			end
		else
			row.name:Hide()
			for i = 1, M.MAXCLASS do
				row.cells[i].pal = nil
				row.cells[i]:Hide()
			end
		end
	end
end

-- Passe la fenetre en vue "Paladins" (appele par ApplyView).
function M.TeamApply()
	local f = M.win
	M.TeamBuild()
	f.mx:Hide()
	for _, b in pairs(f.allB) do b:Hide() end
	for i = 1, M.MAXCLASS do f.classB[i]:Hide() end
	for i = 1, M.ROWS do f.rows[i]:Hide() end
	f.bDef:Hide()
	f.bClear:Hide()
	f.bAuto:Hide()
	f.bTank:Hide()
	f.bOne:Hide()
	f.bRep:Hide()
	f.bWis:Hide()
	f.bView:Hide()
	f.bTeam.txt:SetText(L("msg.pallypower.team.back"))
	local first = not M.twin:IsShown()
	M.twin:Show()
	if first then
		M.SyncReq()
		M.SyncSend()
	end
	M.TeamPaint()
end

function M.TeamOpen()
	if not M.on then return end
	C.Set("pallypower.team", true)
	M.Open()
end

function M.TeamToggle()
	C.Set("pallypower.team", not C.Get("pallypower.team"))
	if not (M.win and M.win:IsShown()) then M.Open() end
end

-- ---------------------------------------------------------------- mini-panneau (facon "Pally Buffs" de l'addon d'origine)
-- Une icone par benediction attribuee : le chiffre = nombre de joueurs visibles qui la manquent, bordure rouge (aucun),
-- jaune (partiel), verte (complet). Clic = pose cette benediction au joueur suivant qui la manque ; clic droit = grille ;
-- bouton "Benir" / touche SHIKIUI_PALLYPOWER_NEXT = prochaine benediction manquante (une par appui, GCD respecte).
-- Lecture par TEXTURE (UnitBuff, pas d'infobulle) : quelques lectures par joueur toutes les 2 s, sans cout notable.
M.TEXPAT = { kings = { "spell_magic_magearmor", "spell_magic_greaterblessingofkings" }, wisdom = { "sealofwisdom", "greaterblessingofwisdom" },
	might = { "fistofjustice", "spell_holy_greaterblessingofkings" }, salvation = { "sealofsalvation", "greaterblessingofsalvation" },
	light = { "prayerofhealing02", "greaterblessingoflight" } }
M.miniState = {}
M.MINIGAP = 4

function M.HasTex(unit, b)
	local pats = M.TEXPAT[b]
	local ub = getglobal("UnitBuff")
	if type(ub) ~= "function" then return false end
	if pats then
		for i = 1, 32 do
			local tex = ub(unit, i)
			if not tex then break end
			tex = slower(tex)
			for j = 1, getn(pats) do
				if sfind(tex, pats[j], 1, true) then return true end
			end
		end
		return false
	end
	-- pas de motif d'icone (Sanctuaire...) : lecture du NOM du buff (comme le cycle), au plus toutes les 6 s par joueur
	local now = GetTime()
	M.nameAt = M.nameAt or {}
	if (M.nameAt[unit] or 0) + 6 < now then
		M.nameAt[unit] = now
		M.buffNames[unit] = nil
	end
	return M.HasBuff(unit, M.SPELLS[b])
end

-- Etat par benediction : n = joueurs attribues, miss = noms qui la manquent, units = unites correspondantes.
function M.MiniScan()
	local st = {}
	M.miniState = st
	local vis = getglobal("UnitIsVisible")
	for i = 1, M.nrost do
		local r = M.roster[i]
		local a = M.assign and M.assign[r.name]
		if a then
			for j = 1, getn(M.BLESS) do
				local b = M.BLESS[j]
				if a[b] then
					local s = st[b]
					if not s then
						s = { n = 0, miss = {}, units = {}, singles = {} }
						st[b] = s
					end
					s.n = s.n + 1
					local ok = UnitExists(r.unit) and not UnitIsDeadOrGhost(r.unit)
					if ok and type(vis) == "function" and not vis(r.unit) then ok = false end
					if ok and not M.HasTex(r.unit, b) then
						tinsert(s.miss, r.name)
						tinsert(s.units, r.unit)
						tinsert(s.singles, M.IsSingle(a, b))
					end
				end
			end
		end
	end
	return st
end

-- Pose UNE benediction manquante (celle demandee, sinon la premiere dans l'ordre Rois, Sagesse...). Renvoie vrai si lancee.
-- Bene SUPERIEURE (30 min) forcee sur la premiere unite manquante : la superieure s'applique a toute
-- la classe a portee (comportement serveur), donc un seul lancement couvre tous les membres presents.
function M.CastGreater(b)
	if not M.on then return false end
	if UnitIsDeadOrGhost("player") then return false end
	if M.nrost == 0 then M.ScanRoster() end
	local st = M.MiniScan()
	local s = st[b]
	if not s or getn(s.units) == 0 then SUI.Print(L("msg.pallypower.allset")) return false end
	local ri
	for k = 1, getn(s.units) do
		if M.Reachable(s.units[k]) then ri = k break end
	end
	if not ri then SUI.Print(L("msg.pallypower.norange")) return false end
	-- nom SUPERIEUR force (independant de l'option pallypower.greater) : EN ou FR selon le client
	local nm
	if GAMEFR and M.SPELLS_FR[b] then
		nm = M.SPELLS_GFR[b] or (M.GREATER_FR .. M.SPELLS_FR[b])
	else
		nm = M.GREATERPFX .. M.SPELLS[b]
	end
	if M.LowLevel(s.units[ri]) or M.NoSymbols() then nm = M.CastName(b, true, s.units[ri]) end     -- cible trop basse ou plus de Symbole : benediction simple au bon rang
	if not nm then SUI.Print(L("msg.pallypower.lowlevel", s.miss[ri])) return false end
	castOn(s.units[ri], nm)
	M.lastCast = s.miss[ri]
	if M.mini then M.MiniPaint() end
	return true
end

function M.CastNext(b)
	if not M.on then return false end
	if UnitIsDeadOrGhost("player") then return false end
	if M.nrost == 0 then M.ScanRoster() end
	local st = M.MiniScan()
	-- d'abord les benedictions de classe, puis les simples (10 min) : sinon la benediction de classe ecraserait la simple d'un autre joueur de la classe
	for pass = 1, 2 do
		local single = (pass == 2)
		for j = 1, getn(M.BLESS) do
			local bb = M.BLESS[j]
			if b == nil or b == bb then
				local s = st[bb]
				if s then
					for k = 1, getn(s.units) do
						local nm, eff = M.CastName(bb, (s.singles[k] or M.NoSymbols()) and true or false, s.units[k])
						if nm and eff == single and M.Reachable(s.units[k]) then
							castOn(s.units[k], nm)
							M.lastCast = s.miss[k]
							if M.mini then M.MiniPaint() end
							return true
						end
					end
				end
			end
		end
	end
	SUI.Print(L("msg.pallypower.allset"))
	return false
end

M.MC = 28          -- cote d'une icone du mini-panneau

function M.BuildMini()
	if M.mini then return M.mini end
	local f = CreateFrame("Frame", "ShikiUI_PPMini", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetWidth(40)
	f:SetHeight(M.MC + 8)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.btn = {}
	for j = 1, getn(M.BLESS) do
		local b = iconBtn(f, "Interface\\Icons\\" .. M.BICON[M.BLESS[j]])
		b:SetWidth(M.MC)
		b:SetHeight(M.MC)
		b.bless = M.BLESS[j]
		b.cnt = T.Text(b, 12, T.c.text, "RIGHT", true)
		b.cnt:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
		b:SetScript("OnClick", function()
			if arg1 == "RightButton" then return end   -- (menu ouvre par le petit bouton o)
			M.CastGreater(this.bless)
		end)
		b:SetScript("OnEnter", function()
			local s = M.miniState[this.bless]
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(L("msg.pallypower.bless." .. this.bless))
			if s and s.miss[1] then
				for k = 1, mmin(getn(s.miss), 10) do GameTooltip:AddLine(s.miss[k], 1, 0.6, 0.6) end
				if getn(s.miss) > 10 then GameTooltip:AddLine("...", 0.7, 0.7, 0.7) end
			else
				GameTooltip:AddLine(L("msg.pallypower.mini.ok"), 0.5, 1, 0.5)
			end
			GameTooltip:AddLine(L("msg.pallypower.mini.hint"), 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.btn[j] = b
	end
	-- dernier bouton : "benir le suivant" (affiche le total qui manque)
	local g = iconBtn(f, nil)
	g:SetWidth(M.MC)
	g:SetHeight(M.MC)
	g.txt = T.Text(g, 13, T.c.text, "CENTER", true)
	g.txt:SetPoint("CENTER", g, "CENTER", -2, -3)     -- decale : le petit o occupe le coin haut droit
	g:SetScript("OnClick", function()
		if arg1 == "RightButton" then return end
		M.CastNext()
	end)
	g:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(L("msg.pallypower.bind.next"))
		GameTooltip:AddLine(L("msg.pallypower.mini.hint"), 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	g:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.go = g
	-- petit bouton o : pose sur le coin de la case du nombre (ouvre la grille) ; un clic ailleurs sur la case = benir le suivant
	local oBtn = iconBtn(g, "InterfaceIconsSpell_Magic_PolymorphPorc")
	oBtn:SetWidth(12)
	oBtn:SetHeight(12)
	oBtn:SetPoint("TOPRIGHT", g, "TOPRIGHT", -1, -1)
	oBtn:SetFrameLevel(g:GetFrameLevel() + 3)
	oBtn.txt = T.Text(oBtn, 10, T.c.text, "CENTER", true)
	oBtn.txt:SetPoint("CENTER", oBtn, "CENTER", 0, 0)
	oBtn.txt:SetText("o")
	oBtn:SetScript("OnClick", function() M.Open() end)
	oBtn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(L("msg.pallypower.open"))
		GameTooltip:Show()
	end)
	f.oBtn = oBtn

	SUI.Layout.Register(f, "pallypower.mini", "LEFT", 8, 120)
	M.DragWire(f, "pallypower.mini")
	M.mini = f
	return f
end

-- Disposition du mini-panneau : "row" (une ligne), "col" (une colonne) ou "grid" (2 colonnes).
function M.MiniCols(mode, n)
	local cols = n
	if mode == "col" then cols = 1 elseif mode == "grid" then cols = 2 end
	if cols > n then cols = n end
	if cols < 1 then cols = 1 end
	return cols
end

function M.MiniPaint()
	local f = M.mini
	if not f then return end
	local st = M.MiniScan()
	local total = 0
	local tc = T.c
	local mc, gap = M.MC, 3
	local list, shown = {}, 0
	for j = 1, getn(M.BLESS) do
		local b = f.btn[j]
		local s = st[M.BLESS[j]]
		if s and s.n > 0 then
			shown = shown + 1
			list[shown] = b
			local nm = getn(s.miss)
			total = total + nm
			local col = tc.good
			if nm >= s.n then col = tc.bad elseif nm > 0 then col = tc.warn end
			b:SetBackdropBorderColor(col[1], col[2], col[3], 1)
			b.cnt:SetText(nm > 0 and nm or EMPTY)
			b:Show()
		else
			b:Hide()
		end
	end
	if shown == 0 then
		f:Hide()
		return
	end
	list[shown + 1] = f.go                       -- dernier : le bouton "suivant" (porte le petit o)
	local n = shown + 1
	local cols = M.MiniCols(C.Get("pallypower.minilayout"), n)
	local rows = math.floor((n + cols - 1) / cols)
	for i = 1, n do
		local c = SUI.Mod(i - 1, cols)
		local r = math.floor((i - 1) / cols)
		list[i]:ClearAllPoints()
		list[i]:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + c * (mc + gap), -4 - r * (mc + gap))
	end
	f.oBtn:Show()
	f.go.txt:SetText(total > 0 and total or EMPTY)
	local col = (total > 0) and tc.warn or tc.good
	f.go:SetBackdropBorderColor(col[1], col[2], col[3], 1)
	f:SetWidth(8 + cols * mc + (cols - 1) * gap)
	f:SetHeight(8 + rows * mc + (rows - 1) * gap)
	f:Show()
end

function M.MiniTick()
	if not M.on then return end
	if not C.Get("pallypower.mini") then
		if M.mini then M.mini:Hide() end
		return
	end
	if not M.mini then
		if SUI.InCombat() then return end
		M.BuildMini()
	end
	M.MiniPaint()
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key)
	if key == nil or sfind(key or EMPTY, "^pallypower%.") then
		if (key == "pallypower.compact" or key == "pallypower.team") and M.win then
			M.ApplyView()
			M.PaintCells()
		end
		if M.win and M.win:IsShown() then M.PaintStatus() end
		if key == "pallypower.mini" then M.MiniTick() end
		if key == "pallypower.minilayout" and M.mini then M.MiniPaint() end
	end
end

-- L'infobulle cachee qui lit les noms de buffs (methode PowerAuras) : creee une seule fois, hors combat.
function M.EnsureTip()
	if M.tip then return end
	local existing = getglobal("ShikiUI_PPTip")
	if existing then M.tip = existing return end
	local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_PPTip", UIParent, "GameTooltipTemplate")
	if ok and t then
		t:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip = t
	end
end

-- /sui pp debug : pour chaque benediction attribuee, ce que le module voit (portee, icone, nom du buff, textures).
function M.Debug()
	if M.nrost == 0 then M.ScanRoster() end
	M.buffNames = {}
	local n = 0
	local ub = getglobal("UnitBuff")
	for i = 1, M.nrost do
		local r = M.roster[i]
		local a = M.assign and M.assign[r.name]
		if a then
			local d, src = nil, nil
			if SUI.Api and SUI.Api.Distance then d, src = SUI.Api.Distance(r.unit) end
			local texs = EMPTY
			if type(ub) == "function" then
				for k = 1, 32 do
					local t = ub(r.unit, k)
					if not t then break end
					texs = texs .. sgsub(t, "^.*\\", EMPTY) .. " "
				end
			end
			for j = 1, getn(M.BLESS) do
				local b = M.BLESS[j]
				if a[b] then
					n = n + 1
					SUI.Print("PP " .. r.name .. " (" .. r.unit .. ") " .. b .. " : portee=" .. tostring(M.Reachable(r.unit)) .. " d=" .. tostring(d) .. "/" .. tostring(src) .. " tex=" .. tostring(M.HasTex(r.unit, b)) .. " nom=" .. tostring(M.HasBuff(r.unit, M.SPELLS[b])) .. " sort=" .. tostring((M.CastName(b, M.IsSingle(a, b), r.unit))))
				end
			end
			SUI.Print("PP buffs de " .. r.name .. " : " .. texs)
		end
	end
	SUI.Print("PP symboles=" .. tostring(M.SymbolCount()) .. " connus=" .. tostring(M.known and "oui" or "non") .. " occupe=" .. tostring(M.busyUntil ~= nil) .. " lignes=" .. n)
end

-- Mes incantations : le cycle attend la fin d'un soin en cours au lieu de l'interrompre.
function M.OnCastEv(ev, a1, a2)
	if ev == "SPELLCAST_START" or ev == "SPELLCAST_CHANNEL_START" then
		-- 1.12 : SPELLCAST_START (nom, duree ms) ; SPELLCAST_CHANNEL_START (duree ms, nom)
		local ms = tonumber(ev == "SPELLCAST_START" and a2 or a1)
		M.busyUntil = (ms and ms > 0) and (GetTime() + ms / 1000) or nil
	else
		M.busyUntil = nil
	end
end
M.CAST_EV = { "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED", "SPELLCAST_CHANNEL_START", "SPELLCAST_CHANNEL_STOP" }

function M.Enable()
	M.on = true
	for i = 1, getn(M.CAST_EV) do SUI.On(M.CAST_EV[i], M.OnCastEv) end
	M.LoadAssign()
	SUI.WhenSafe(M.EnsureTip)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.On("SPELLS_CHANGED", M.ScanKnown)
	SUI.On("CHAT_MSG_ADDON", M.OnAddon)
	SUI.WhenSafe(M.ScanKnown)
	if not M.watching then
		M.watching = true
		C.Watch("pallypower.", M.OnKey)
	end
	local _, cls = UnitClass("player")
	if cls ~= "PALADIN" and not M.warned then
		M.warned = true
		SUI.Print(L("msg.pallypower.nopaladin"))
	end
	M.ScanRoster()
	if not M.miniTask then M.miniTask = SUI.Every(2, M.MiniTick, "pp.mini") end
	SUI.WhenSafe(M.MiniTick)
	M.rtask = SUI.After(3, function() M.rtask = nil if M.on then M.SyncReq() M.SyncSoon() end end, "pp.syncreq")
end

function M.Disable()
	if M.demo then M.Demo(false) end
	if M.wtask then SUI.Cancel(M.wtask) M.wtask = nil end
	M.on = false
	for i = 1, getn(M.CAST_EV) do SUI.Off(M.CAST_EV[i], M.OnCastEv) end
	M.busyUntil = nil
	M.Stop()
	if M.miniTask then SUI.Cancel(M.miniTask) M.miniTask = nil end
	if M.mini then M.mini:Hide() end
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.Off("SPELLS_CHANGED", M.ScanKnown)
	SUI.Off("CHAT_MSG_ADDON", M.OnAddon)
	if M.stask then SUI.Cancel(M.stask) M.stask = nil end
	if M.rtask then SUI.Cancel(M.rtask) M.rtask = nil end
	M.Close()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("pallypower", 68)
SUI.RegisterAction("pallypower", "mod.menu.act.pallyteam", function() M.TeamOpen() end, 130)

local function opt(key, typ, order, def, extra)
	local o = { key = "pallypower." .. key, type = typ, cat = "pallypower", label = "opt.pallypower." .. key, tip = "tip.pallypower." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

local function judgeText(o, v) return L("choice.pallypower.judge." .. v) end
local function miniText(o, v) return L("choice.pallypower.minilayout." .. v) end

SUI.RegisterModule("pallypower", {
	default = false,
	cost = "medium",
	options = {
		opt("greater", "bool", 10, true, { simple = true }),
		opt("greaterlvl", "number", 10.5, M.GREATERLVL, { min = 0, max = 60, step = 1 }),
		opt("compact", "bool", 15, true, { simple = true }),
		opt("mini", "bool", 16, true, { simple = true }),
		opt("minilayout", "choice", 16.5, "row", { choices = { "row", "col", "grid" }, choiceText = miniText, simple = true }),
		opt("autosingle", "bool", 17, false, { simple = true }),
		opt("autosalv", "bool", 18, false),
		opt("sync", "bool", 19, true),
		opt("remote", "bool", 19.2, true),
		opt("team", "bool", 15.5, false),
		opt("syncmsg", "bool", 19.5, true),
		opt("autosplit", "bool", 19.7, true),
		opt("judge", "choice", 20, "none", { choices = { "none", "light", "wisdom", "crusader" }, choiceText = judgeText, simple = true }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- /sui pp focus : 5 s pour poser la souris sur un bouton, puis dit quel cadre RECOIT la souris et l'etat du mini-panneau / de la fenetre
-- (diagnostic "je n'arrive pas a cliquer" : un cadre transparent par-dessus apparait ici avec son nom).
local function probeFrame(f)
	local nm = (f.GetName and f:GetName()) or "?"
	local me = "?"
	if f.IsMouseEnabled then me = f:IsMouseEnabled() and "mouse" or "nomouse" end
	return nm .. "[" .. tostring(f:GetFrameStrata()) .. "/" .. tostring(f:GetFrameLevel()) .. " " .. me .. "]"
end

function M.FocusProbe()
	SUI.Print(L("msg.pallypower.focus.wait"))
	SUI.After(5, function()
		local gf = getglobal("GetMouseFocus")
		local f = type(gf) == "function" and gf() or nil
		local s = EMPTY
		local n = 0
		while f and n < 8 do
			s = s .. probeFrame(f) .. " < "
			f = f.GetParent and f:GetParent() or nil
			n = n + 1
		end
		SUI.Print("FOCUS " .. (s ~= EMPTY and s or "none"))
		local mm = M.mini
		if mm then
			local l, b = mm:GetLeft(), mm:GetBottom()
			SUI.Print("MINI " .. probeFrame(mm) .. " shown=" .. tostring(mm:IsShown()) .. " x=" .. tostring(l and math.floor(l)) .. " y="
				.. tostring(b and math.floor(b)) .. " w=" .. tostring(math.floor(mm:GetWidth())) .. " h=" .. tostring(math.floor(mm:GetHeight()))
				.. " scale=" .. tostring(mm:GetEffectiveScale()))
		else
			SUI.Print("MINI none")
		end
		if M.win then
			SUI.Print("WIN " .. probeFrame(M.win) .. " shown=" .. tostring(M.win:IsShown()))
		else
			SUI.Print("WIN none")
		end
	end, "pp.focus")
end

-- Le module reste actif en mode Raid : les benedictions d'urgence se posent EN combat.
SUI.RegisterCommand("pp", function(rest)
	if not M.on then
		C.Set("modules.pallypower", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	elseif rest == "cast" then
		M.CastAll()
	elseif rest == "next" then
		M.CastNext()
	elseif rest == "sync" then
		M.SyncReq()
		M.SyncSend()
		local pl = M.PeerLines()
		if getn(pl) == 0 then SUI.Print(L("msg.pallypower.sync.nopeer")) end
		for i = 1, getn(pl) do SUI.Print(pl[i]) end
	elseif rest == "report" then
		M.Report()
	elseif rest == "debug" then
		M.Debug()
	elseif rest == "focus" then
		M.FocusProbe()
	elseif rest == "whisper" then
		M.WhisperAll()
	elseif rest == "demo" then
		M.Demo()
	elseif rest == "demooff" then
		M.Demo(false)
	elseif rest == "auto" then
		M.AutoAssign()
	elseif rest == "team" then
		M.TeamToggle()
	elseif rest == "tank" or rest == "single" then
		M.TargetFlag(rest)
	elseif rest == "clear" then
		M.ClearAll()
		SUI.Print(L("msg.pallypower.cleared"))
	else
		M.ToggleWin()
	end
end, "help.pallypower")

setglobal("BINDING_NAME_SHIKIUI_PALLYPOWER_NEXT", L("msg.pallypower.bind.next"))
setglobal("BINDING_NAME_SHIKIUI_PALLYPOWER", L("msg.pallypower.bind.all"))
