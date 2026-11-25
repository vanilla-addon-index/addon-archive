-- ShikiUI Meter : compteur de degats / soins / surplus / dissipation / interruptions / morts / degats subis (v1.0, module "meter"),
-- pense pour REMPLACER OctoMeter (aucun code copie : tout est reecrit ; OctoMeter n'a servi que de liste de fonctionnalites).
-- Sources relevees dans les addons installes (lecture seule) :
--   Nampower (SOURCE PRINCIPALE quand elle est la) : evenements structures AUTO_ATTACK_SELF / _OTHER (attaquant, cible, degats, hitInfo),
--     SPELL_DAMAGE_EVENT_SELF / _OTHER (cible, lanceur, sortId, degats, attenuation, hitInfo 0 normal 2 critique, ecole),
--     SPELL_HEAL_BY_SELF / _OTHER (cible, soigneur, sortId, montant, critique, periodique), SPELL_DISPEL_BY_SELF / _OTHER (lanceur, cible,
--     sortId DISSIPE), UNIT_DIED (guid), ENVIRONMENTAL_DMG_SELF / _OTHER (guid, type, degats, absorbe, resiste). Sources : OctoMeter\Parser\
--     ParserNampower.lua + ParserMain.lua, ChronicleCompanion\advancedlogging\core.lua (documentation des arguments), NampowerSettings\
--     helper.lua. CVar a activer (comme OctoMeter) : NP_EnableAutoAttackEvents et NP_EnableSpellHealEvents. Les arguments 5 et suivants
--     sont lus par getglobal("argN") : le routeur de ShikiUI ne transmet que les quatre premiers.
--     Nom du sort : SpellInfo(id) (SuperWoW) sinon GetSpellRecField(id, "name") ; type de dissipation GetSpellRecField(id, "dispel")
--     (1 magie, 2 MALEDICTION, 3 maladie, 4 poison : table relevee dans pfUI-old-backup\libs\libdebuff.lua).
--     Familiers et gardiens (totems, "Les Perdus"...) : GetUnitField(guid, "summonedBy" / "createdBy" / "charmedBy") puis fusion dans
--     le proprietaire (idee de OwnerOf / FoldIntoOwner d'OctoMeter), au format "Gardien : Sort".
--   Journal de combat texte (REPLI sans Nampower, ou source = journal) : ShaguDPS (README : pas de licence declaree ; parser-vanilla.lua)
--     pour les NOMS des chaines globales du client (COMBATHITSELFOTHER, SPELLLOGSCHOOLOTHEROTHER...) et le principe "motif Lua construit
--     a partir de la chaine du client". Morts : CHAT_MSG_COMBAT_FRIENDLY_DEATH + UNITDIESOTHER (releves dans BigWigs) et PLAYER_DEAD.
--   SuperWoW UNIT_CASTEVENT (lanceur, cible, type START/CAST/FAIL, sort, duree) : interruptions (un lancement qui ECHOUE avant 90 % de sa
--     duree + un sort d'interruption recent sur la meme cible : heuristique, comme OctoMeter) ; dissipation seulement sans Nampower.
--   DPSMate (GPL v3 : rien copie) : listes de sorts d'interruption / de dissipation, vues degats / dps / soins / hps, historique de combats.
-- Segments : "actuel" (combat en cours, sinon le dernier), "precedent", "boss", "total", et "h1".."h8" (les derniers combats finis). Un
--   segment se ferme quand le journal se tait depuis meter.idle secondes et que le joueur est hors combat.
-- Fenetres : taille par defaut 240 x 192 (10 lignes), poignee de coin pour redimensionner a la souris, largeur / hauteur / lignes /
--   hauteur de ligne / taille de police en reglages ; tout est memorise (reglages meter.* et position dans le Layout : cadres "meter.winN",
--   donc deplacables par le Mover). Clic sur une ligne : detail par sort (coups, critiques, moyenne). Clic sur le titre : choix du segment.
-- Mode Raid : version minimale (une fenetre, 8 lignes, 2 segments, rafraichissement lent).
-- Cout declare : MEDIUM. Evenement Nampower ou chaine du journal : une table de noms et de proprietaires en cache, aucune allocation hors
--   nouveau sort / joueur / mort ; entrees, sorts et segments viennent de reserves creees hors combat. Un seul timer partage ; les lignes
--   de fenetre sont creees une fois (WhenSafe) ; un texte n'est reecrit que s'il change.
-- Aucune sauvegarde des donnees de combat (regle 11 : ShikiUIDB ne garde que la Config) : l'historique est perdu au /reload.
-- NON VERIFIE en jeu : tout le chemin Nampower (ordre / valeur des arguments, CVar, UNIT_DIED pour le joueur, GetUnitField sur un garde),
--   soins effectifs (la vie lue au moment de l'evenement est-elle deja mise a jour ?), UNIT_CASTEVENT, noms de sorts d'interruption en
--   ANGLAIS seulement, roulette / clics sur les lignes, GameTooltip, poignee de redimensionnement (curseur, echelle de l'interface).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Meter = M

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor, mmax, mmin = math.floor, math.max, math.min
local strfind, strsub, strlen, strformat = string.find, string.sub, string.len, string.format
local EMPTY = ""

M.KINDS = { "damage", "heal", "taken", "interrupts", "dispels", "decurse" }
M.VIEWS = { "damage", "dps", "heal", "hps", "overheal", "taken", "interrupts", "dispels", "decurse", "deaths", "threat" }
M.VIEWKIND = { damage = "damage", dps = "damage", heal = "heal", hps = "heal", overheal = "heal", taken = "taken", interrupts = "interrupts",
	dispels = "dispels", decurse = "decurse" }
M.COUNTKIND = { interrupts = true, dispels = true, decurse = true }
M.SEGS = { "current", "previous", "boss", "overall" }
M.SEGCHOICES = { "current", "previous", "boss", "overall", "h1", "h2", "h3", "h4", "h5", "h6", "h7", "h8" }
M.REPORT = { "self", "auto", "say", "party", "raid", "guild" }
M.SOURCES = { "auto", "log" }
M.MAXWIN, M.MAXROWS, M.PREROWS = 4, 30, 15
M.SBW = 4                         -- largeur de la barre de defilement
M.HDR, M.FOOT = 20, 10          -- hauteur de l'en-tete, marge basse (poignee)
M.MINW, M.MAXW, M.MINH, M.MAXH = 120, 500, 60, 700
M.GAP = 5            -- secondes : au-dela, une pause compte pour 1 s de temps actif
M.POOL = 120         -- entrees preparees a l'activation
M.POOLMAX = 400
M.DETLINES = 14      -- lignes du panneau de detail
M.RING = 5           -- derniers coups gardes par joueur (rapport de mort)
M.MAXDEATH = 60
M.DEATHWIN = 10      -- secondes : seuls les coups de cette fenetre sont rapportes dans une mort

-- Sorts (noms ANGLAIS ; non verifie en jeu). Sources : DPSMate (listes), voir l'en-tete.
M.KICKS = { ["Kick"] = true, ["Pummel"] = true, ["Shield Bash"] = true, ["Counterspell"] = true, ["Earth Shock"] = true }
M.DISPELS = { ["Remove Curse"] = true, ["Cleanse"] = true, ["Remove Lesser Curse"] = true, ["Purify"] = true, ["Dispel Magic"] = true,
	["Abolish Poison"] = true, ["Abolish Disease"] = true, ["Devour Magic"] = true, ["Cure Disease"] = true, ["Cure Poison"] = true,
	["Purge"] = true }
M.CURSES = { ["Remove Curse"] = true, ["Remove Lesser Curse"] = true }

-- Evenements Nampower ecoutes (source principale quand Nampower est la).
M.NPEVENTS = { "AUTO_ATTACK_SELF", "AUTO_ATTACK_OTHER", "SPELL_DAMAGE_EVENT_SELF", "SPELL_DAMAGE_EVENT_OTHER", "SPELL_HEAL_BY_SELF",
	"SPELL_HEAL_BY_OTHER", "SPELL_DISPEL_BY_SELF", "SPELL_DISPEL_BY_OTHER", "UNIT_DIED", "ENVIRONMENTAL_DMG_SELF", "ENVIRONMENTAL_DMG_OTHER" }
M.ENVKEYS = { [0] = "msg.meter.env0", "msg.meter.env1", "msg.meter.env2", "msg.meter.env3", "msg.meter.env4", "msg.meter.env5", "msg.meter.env6" }
M.NPCVARS = { "NP_EnableAutoAttackEvents", "NP_EnableSpellHealEvents" }
local ARGN = { "arg1", "arg2", "arg3", "arg4", "arg5", "arg6", "arg7", "arg8", "arg9" }

-- ---------------------------------------------------------------- chaines du journal de combat
-- { chaine globale du client, role de chaque argument du format dans l'ordre du format
--   (s source, a capacite, t cible, v valeur, x ignore), genre, qui est le joueur ("s" source, "t" cible, "st" les deux, "" aucun),
--   groupe d'evenements, libelle (m = coup de melee, r = renvoi) }
M.DEFS = {
	{ "COMBATHITSELFOTHER", "tv", "damage", "s", "hs", "m" },
	{ "COMBATHITCRITSELFOTHER", "tv", "damage", "s", "hs", "m" },
	{ "COMBATHITSCHOOLSELFOTHER", "tvx", "damage", "s", "hs", "m" },
	{ "COMBATHITCRITSCHOOLSELFOTHER", "tvx", "damage", "s", "hs", "m" },
	{ "COMBATHITOTHERSELF", "sv", "damage", "t", "ho", "m" },
	{ "COMBATHITCRITOTHERSELF", "sv", "damage", "t", "ho", "m" },
	{ "COMBATHITSCHOOLOTHERSELF", "svx", "damage", "t", "ho", "m" },
	{ "COMBATHITCRITSCHOOLOTHERSELF", "svx", "damage", "t", "ho", "m" },
	{ "COMBATHITOTHEROTHER", "stv", "damage", "", "hx", "m" },
	{ "COMBATHITCRITOTHEROTHER", "stv", "damage", "", "hx", "m" },
	{ "COMBATHITSCHOOLOTHEROTHER", "stvx", "damage", "", "hx", "m" },
	{ "COMBATHITCRITSCHOOLOTHEROTHER", "stvx", "damage", "", "hx", "m" },
	{ "SPELLLOGSELFOTHER", "atv", "damage", "s", "ss" },
	{ "SPELLLOGCRITSELFOTHER", "atv", "damage", "s", "ss" },
	{ "SPELLLOGSCHOOLSELFOTHER", "atvx", "damage", "s", "ss" },
	{ "SPELLLOGCRITSCHOOLSELFOTHER", "atvx", "damage", "s", "ss" },
	{ "SPELLLOGOTHERSELF", "sav", "damage", "t", "so" },
	{ "SPELLLOGCRITOTHERSELF", "sav", "damage", "t", "so" },
	{ "SPELLLOGSCHOOLOTHERSELF", "savx", "damage", "t", "so" },
	{ "SPELLLOGCRITSCHOOLOTHERSELF", "savx", "damage", "t", "so" },
	{ "SPELLLOGOTHEROTHER", "satv", "damage", "", "sx" },
	{ "SPELLLOGCRITOTHEROTHER", "satv", "damage", "", "sx" },
	{ "SPELLLOGSCHOOLOTHEROTHER", "satvx", "damage", "", "sx" },
	{ "SPELLLOGCRITSCHOOLOTHEROTHER", "satvx", "damage", "", "sx" },
	{ "DAMAGESHIELDSELFOTHER", "vxt", "damage", "s", "ds", "r" },
	{ "DAMAGESHIELDOTHERSELF", "svx", "damage", "t", "dx", "r" },
	{ "DAMAGESHIELDOTHEROTHER", "svxt", "damage", "", "dx", "r" },
	{ "PERIODICAURADAMAGESELFOTHER", "tvxa", "damage", "s", "po" },
	{ "PERIODICAURADAMAGEOTHEROTHER", "tvxsa", "damage", "", "po" },
	{ "PERIODICAURADAMAGEOTHERSELF", "vxsa", "damage", "t", "ps" },
	{ "HEALEDCRITSELFSELF", "av", "heal", "st", "hls" },
	{ "HEALEDSELFSELF", "av", "heal", "st", "hls" },
	{ "HEALEDCRITSELFOTHER", "atv", "heal", "s", "hls" },
	{ "HEALEDSELFOTHER", "atv", "heal", "s", "hls" },
	{ "HEALEDCRITOTHERSELF", "sav", "heal", "t", "hlo" },
	{ "HEALEDOTHERSELF", "sav", "heal", "t", "hlo" },
	{ "HEALEDCRITOTHEROTHER", "satv", "heal", "", "hlo" },
	{ "HEALEDOTHEROTHER", "satv", "heal", "", "hlo" },
	{ "PERIODICAURAHEALSELFOTHER", "tva", "heal", "s", "hpo" },
	{ "PERIODICAURAHEALOTHEROTHER", "tvsa", "heal", "", "hpo" },
	{ "PERIODICAURAHEALOTHERSELF", "vsa", "heal", "t", "hps" },
	{ "PERIODICAURAHEALSELFSELF", "va", "heal", "st", "hps" },
	-- Coups rates du joueur seulement (esquive, parade, resistance...) : alimentent la colonne "rates" du detail (aucun montant).
	{ "MISSEDSELFOTHER", "t", "miss", "s", "ms", "m" },
	{ "VSDODGESELFOTHER", "t", "miss", "s", "ms", "m" },
	{ "VSPARRYSELFOTHER", "t", "miss", "s", "ms", "m" },
	{ "SPELLMISSSELFOTHER", "at", "miss", "s", "sm" },
	{ "SPELLDODGEDSELFOTHER", "at", "miss", "s", "sm" },
	{ "SPELLPARRIEDSELFOTHER", "at", "miss", "s", "sm" },
	{ "SPELLRESISTSELFOTHER", "at", "miss", "s", "sm" },
	{ "SPELLEVADEDSELFOTHER", "at", "miss", "s", "sm" },
}

-- evenement -> groupes de motifs
M.EVENTS = {
	CHAT_MSG_COMBAT_SELF_HITS = { "hs" },
	CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = { "ho" },
	CHAT_MSG_COMBAT_PARTY_HITS = { "hx" },
	CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS = { "hx" },
	CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = { "hx" },
	CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS = { "hx" },
	CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS = { "hx" },
	CHAT_MSG_COMBAT_PET_HITS = { "hx" },
	CHAT_MSG_SPELL_SELF_DAMAGE = { "ss", "sm" },
	CHAT_MSG_COMBAT_SELF_MISSES = { "ms" },
	CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = { "so" },
	CHAT_MSG_SPELL_PARTY_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_PET_DAMAGE = { "sx" },
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = { "ds" },
	CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS = { "dx" },
	CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE = { "po" },
	CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE = { "po" },
	CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE = { "po" },
	CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = { "po" },
	CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = { "ps" },
	CHAT_MSG_SPELL_SELF_BUFF = { "hls" },
	CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF = { "hlo" },
	CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF = { "hlo" },
	CHAT_MSG_SPELL_PARTY_BUFF = { "hlo" },
	CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS = { "hpo" },
	CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS = { "hpo" },
	CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS = { "hpo" },
	CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = { "hps" },
}

-- Evenements des coups rates : en mode Nampower, seuls ceux-la sont lus dans le journal (les degats viennent de Nampower).
M.MISSEVENTS = { CHAT_MSG_SPELL_SELF_DAMAGE = { "sm" }, CHAT_MSG_COMBAT_SELF_MISSES = { "ms" } }

M.on = false
M.cfg = { open = { true, true, true, true }, windows = 1, rows = 10, rowh = 16, width = 240, height = 0, fontsize = 11, spacing = 1, alpha = 0.9, classcolor = true,
	showrank = true, showpct = true, shortnum = true, refresh = 1, idle = 8, minlen = 3, segments = 8, dpsmode = "active", mergepets = true,
	trackall = false, detail = true, overheal = false, interrupts = true, dispels = true, deaths = true, autoreset = false, tooltips = true,
	source = "auto", setcvars = true, pinme = true, scrollbar = true, wheelstep = 1, reportn = 5, reportchan = "self", view = { "damage", "heal", "taken", "interrupts" },
	seg = { "current", "current", "overall", "current" } }

M.recs = {}          -- evenement -> liste de motifs compiles
M.nrecs = 0
M.caps = { 0, 0, 0, 0, 0 }
M.cls, M.owner, M.unit, M.petLabel = {}, {}, {}, {}
M.gname, M.gowner, M.glabel, M.spfb = {}, {}, {}, {}   -- guid -> nom, guid -> proprietaire (ou faux), gardien -> etiquettes, sort -> "#id"
M.ngname = 0
M.ring, M.dieT = {}, {}                                  -- derniers coups subis par joueur, instant de la derniere mort
M.envLbl = {}
M.pool, M.npool = {}, 0
M.spare, M.nspare = {}, 0
M.hist, M.cur, M.overall, M.lastBoss = {}, nil, nil, nil
M.list, M.listn = {}, 0
M.win = {}
M.ver, M.segId = 0, 0
M.lastEvt = 0
M.player = nil
M.np = false         -- vrai : la source de donnees est Nampower (sinon : journal de combat texte)

-- ---------------------------------------------------------------- motifs
-- Transforme une chaine du client ("%s's %s hits %s for %d.") en motif Lua ancre au debut. Retourne motif, ordre des arguments par
-- capture, nombre de captures. Gere les formats positionnels (%1$s) et %%.
function M.Compile(fmt)
	local pat, n, seq = "^", 0, 0
	local order = {}
	local i, len = 1, strlen(fmt)
	while i <= len do
		local ch = strsub(fmt, i, i)
		if ch == "%" then
			local nx = strsub(fmt, i + 1, i + 1)
			local _, e, pos, kind = strfind(fmt, "^(%d)%$([sd])", i + 1)
			local arg = nil
			if pos then
				arg = tonumber(pos)
				i = e + 1
			elseif nx == "s" or nx == "d" then
				seq = seq + 1
				arg = seq
				kind = nx
				i = i + 2
			end
			if arg then
				n = n + 1
				order[n] = arg
				if kind == "d" then pat = pat .. "(%d+)" else pat = pat .. "(.-)" end
			else
				pat = pat .. "%%"
				if nx == "%" then i = i + 2 else i = i + 1 end
			end
		else
			if strfind(ch, "[%^%$%(%)%.%[%]%*%+%-%?]") then pat = pat .. "%" .. ch else pat = pat .. ch end
			i = i + 1
		end
	end
	if strsub(pat, -4) == "(.-)" then pat = strsub(pat, 1, strlen(pat) - 4) .. "(.+)" end
	return pat, order, n
end

-- (Re)construit les motifs a partir des chaines globales du client. Une chaine absente est ignoree et comptee.
function M.BuildPatterns()
	local groups = {}
	local n, missing = 0, 0
	for i = 1, getn(M.DEFS) do
		local d = M.DEFS[i]
		local fmt = getglobal(d[1])
		if type(fmt) == "string" and fmt ~= EMPTY then
			local pat, order, cnt = M.Compile(fmt)
			local roles = {}
			for k = 1, strlen(d[2]) do roles[k] = strsub(d[2], k, k) end
			local who = d[4]
			local rec = { name = d[1], pat = pat, order = order, n = cnt, roles = roles, kind = d[3], selfSrc = strfind(who, "s", 1, true) ~= nil,
				selfTgt = strfind(who, "t", 1, true) ~= nil, label = d[6], crit = strfind(d[1], "CRIT", 1, true) ~= nil }
			if not groups[d[5]] then groups[d[5]] = {} end
			tinsert(groups[d[5]], rec)
			n = n + 1
		else
			missing = missing + 1
		end
	end
	M.recs, M.missRecs = {}, {}
	for ev, gl in pairs(M.MISSEVENTS) do
		local list = {}
		for g = 1, getn(gl) do
			local src = groups[gl[g]]
			if src then
				for k = 1, getn(src) do tinsert(list, src[k]) end
			end
		end
		M.missRecs[ev] = list
	end
	for ev, gl in pairs(M.EVENTS) do
		local list = {}
		for g = 1, getn(gl) do
			local src = groups[gl[g]]
			if src then
				for k = 1, getn(src) do tinsert(list, src[k]) end
			end
		end
		M.recs[ev] = list
	end
	M.nrecs, M.nmissing = n, missing
	-- "X meurt." (UNITDIESOTHER) : motif des morts du journal texte
	local die = getglobal("UNITDIESOTHER")
	if type(die) == "string" and die ~= EMPTY then M.diePat = M.Compile(die) else M.diePat = nil end
	-- Les motifs sont ancres au debut seulement : un suffixe "(12 resisted)" / "(glancing)" apres le point final est sans effet.
	return n
end

-- ---------------------------------------------------------------- reserves (hors combat)
function M.Prime()
	while M.npool < M.POOL do
		M.npool = M.npool + 1
		M.pool[M.npool] = { sp = {}, hn = {}, hc = {}, mx = {}, hm = {} }
	end
	local want = M.cfg.segments + 2
	while M.nspare < want do M.nspare = M.nspare + 1 M.spare[M.nspare] = M.NewShell() end
end

function M.NewShell()
	local k, tot = {}, {}
	for i = 1, getn(M.KINDS) do
		k[M.KINDS[i]] = {}
		tot[M.KINDS[i]] = 0
	end
	return { k = k, tot = tot, deaths = {}, nd = 0, name = nil, boss = false, start = 0, stop = nil, id = 0, dur = 0 }
end

function M.NewEntry(name, cls)
	local e
	if M.npool > 0 then
		e = M.pool[M.npool]
		M.pool[M.npool] = nil
		M.npool = M.npool - 1
	else
		e = { sp = {}, hn = {}, hc = {}, mx = {}, hm = {} }
	end
	e.name, e.cls = name, cls
	e.total, e.eff, e.first, e.last, e.act, e.v, e.pct = 0, 0, 0, 0, 0, 0, 0
	return e
end

function M.FreeEntry(e)
	for k in pairs(e.sp) do e.sp[k] = nil end
	for k in pairs(e.hn) do e.hn[k] = nil end
	for k in pairs(e.hc) do e.hc[k] = nil end
	for k in pairs(e.mx) do e.mx[k] = nil end
	for k in pairs(e.hm) do e.hm[k] = nil end
	if M.npool < M.POOLMAX then
		M.npool = M.npool + 1
		M.pool[M.npool] = e
	end
end

function M.ClearSeg(s)
	for i = 1, getn(M.KINDS) do
		local kind = M.KINDS[i]
		local k = s.k[kind]
		for name, e in pairs(k) do
			M.FreeEntry(e)
			k[name] = nil
		end
		s.tot[kind] = 0
	end
	for i = s.nd, 1, -1 do s.deaths[i] = nil end
	s.nd = 0
	s.name, s.boss, s.stop, s.start, s.dur = nil, false, nil, 0, 0
end

function M.Recycle(s)
	if M.lastBoss == s then M.lastBoss = nil end
	M.ClearSeg(s)
	M.nspare = M.nspare + 1
	M.spare[M.nspare] = s
end

function M.TakeShell()
	if M.nspare > 0 then
		local s = M.spare[M.nspare]
		M.spare[M.nspare] = nil
		M.nspare = M.nspare - 1
		return s
	end
	return M.NewShell()
end

-- ---------------------------------------------------------------- segments
function M.StartSegment(now)
	M.fought = true
	local s = M.TakeShell()
	M.segId = M.segId + 1
	s.id = M.segId
	s.start = now
	s.stop = nil
	M.cur = s
	M.CheckBoss()
	if not s.name and UnitExists("target") and UnitCanAttack("player", "target") then s.name = UnitName("target") end
	M.ver = M.ver + 1
end

function M.EndSegment()
	local s = M.cur
	if not s then return end
	M.cur = nil
	s.stop = M.lastEvt
	local dur = s.stop - s.start
	if dur < M.cfg.minlen and not s.boss then
		M.Recycle(s)
	else
		M.overall.dur = M.overall.dur + dur   -- les micro-fights jetes ne gonflent pas la duree du total
		if not s.name then s.name = strformat(L("msg.meter.fightn"), s.id) end
		tinsert(M.hist, 1, s)
		if s.boss then M.lastBoss = s end
		M.TrimHistory()
	end
	M.ver = M.ver + 1
	M.forcePaint = true
end

function M.TrimHistory()
	while getn(M.hist) > M.cfg.segments do
		local old = tremove(M.hist)
		M.Recycle(old)
	end
end

-- Un boss : niveau -1 (crane) ou classification "worldboss" sur la cible hostile.
function M.CheckBoss()
	local s = M.cur
	if not s or not UnitExists("target") or not UnitCanAttack("player", "target") then return end
	local boss = UnitLevel("target") < 0
	local cl = getglobal("UnitClassification")
	if cl and cl("target") == "worldboss" then boss = true end
	if boss then
		s.boss = true
		s.name = UnitName("target")
	elseif not s.name then
		s.name = UnitName("target")
	end
end

function M.Duration(s)
	if s == M.overall then
		local extra = 0
		if M.cur then extra = M.lastEvt - M.cur.start end
		return s.dur + extra
	end
	return (s.stop or M.lastEvt) - s.start
end

function M.Segment(sel)
	if sel == "overall" then return M.overall end
	if sel == "current" then return M.cur or M.hist[1] end
	if sel == "previous" then
		if M.cur then return M.hist[1] end
		return M.hist[2]
	end
	if sel == "boss" then return M.lastBoss end
	if strsub(sel, 1, 1) == "h" then return M.hist[tonumber(strsub(sel, 2)) or 0] end
	return nil
end

function M.Reset()
	if M.cur then
		M.Recycle(M.cur)
		M.cur = nil
	end
	for i = getn(M.hist), 1, -1 do
		M.Recycle(M.hist[i])
		M.hist[i] = nil
	end
	M.ClearSeg(M.overall)
	M.lastBoss = nil
	M.CloseDetail()
	M.ver = M.ver + 1
	M.forcePaint = true
end

-- ---------------------------------------------------------------- groupe (nom -> classe, proprietaire, unite)
local RAIDU, RAIDP, PARTYU, PARTYP = {}, {}, {}, {}
for i = 1, 40 do RAIDU[i] = "raid" .. i RAIDP[i] = "raidpet" .. i end
for i = 1, 4 do PARTYU[i] = "party" .. i PARTYP[i] = "partypet" .. i end

function M.NewRing()
	return { i = 0, n = 0, s = {}, a = {}, v = {}, t = {} }
end

-- Apprend le guid d'une unite connue (SuperWoW : 2e retour de UnitExists ; Nampower : GetUnitGUID).
function M.Seed(unit, name)
	local _, g = UnitExists(unit)
	if not g then
		local gg = getglobal("GetUnitGUID")
		if gg then g = gg(unit) end
	end
	if type(g) == "string" and M.gname[g] ~= name then
		if not M.gname[g] then M.ngname = M.ngname + 1 end
		M.gname[g] = name
	end
end

function M.AddMember(unit, petUnit)
	local name = UnitName(unit)
	if not name then return end
	local _, cls = UnitClass(unit)
	M.cls[name] = cls or "UNKNOWN"
	M.unit[name] = unit
	M.Seed(unit, name)
	if not M.ring[name] then M.ring[name] = M.NewRing() end
	local pn = petUnit and UnitName(petUnit)
	if pn and pn ~= name then
		M.cls[pn] = "PET"
		M.owner[pn] = name
		M.unit[pn] = petUnit
		M.petLabel[pn] = L("msg.meter.pet") .. pn
		M.Seed(petUnit, pn)
	end
end

function M.ScanRoster()
	M.rosterDirty = false
	for k in pairs(M.cls) do M.cls[k] = nil end
	for k in pairs(M.owner) do M.owner[k] = nil end
	for k in pairs(M.unit) do M.unit[k] = nil end
	for k in pairs(M.petLabel) do M.petLabel[k] = nil end
	M.player = UnitName("player")
	M.AddMember("player", "pet")
	local nr = GetNumRaidMembers()
	if nr > 0 then
		for i = 1, nr do M.AddMember(RAIDU[i], RAIDP[i]) end
	else
		local np = GetNumPartyMembers()
		for i = 1, np do M.AddMember(PARTYU[i], PARTYP[i]) end
	end
	M.members = nr > 0 and nr or (GetNumPartyMembers() + 1)
end

function M.OnRoster()
	local nr = GetNumRaidMembers()
	if M.cfg.autoreset and nr > 0 and (M.lastRaidN or 0) == 0 then M.Reset() end
	M.lastRaidN = nr
	M.rosterDirty = true
end

-- Qui est credite ? Retourne nom, classe, etiquette de capacite imposee (ou nil).
function M.Resolve(name)
	local cls = M.cls[name]
	if cls then
		if cls == "PET" and M.cfg.mergepets then
			return M.owner[name], M.cls[M.owner[name]], M.petLabel[name]
		end
		return name, cls, nil
	end
	if M.cfg.trackall then return name, "OTHER", nil end
	return nil
end

-- ---------------------------------------------------------------- guid -> nom, proprietaire (Nampower)
-- Le nom d'un guid : cache, sinon UnitName(guid) (SuperWoW / Nampower acceptent un guid), sinon le guid lui-meme.
function M.NameOf(g)
	if type(g) ~= "string" then return nil end
	local n = M.gname[g]
	if n then return n end
	if strfind(g, "^0x") then
		n = UnitName(g)
		if n and n ~= EMPTY then
			if M.ngname > 600 then
				for k in pairs(M.gname) do M.gname[k] = nil end
				M.ngname = 0
			end
			M.ngname = M.ngname + 1
			M.gname[g] = n
			return n
		end
	end
	return g
end

-- Proprietaire d'un familier / gardien (totem, gardien d'objet...) : nom ou nil. Rien n'est mis en cache si l'appel echoue ou si le
-- proprietaire n'est pas encore resolu (nouvel essai au prochain evenement). Les joueurs (0x00...) n'ont jamais de proprietaire.
function M.OwnerOf(g)
	if type(g) ~= "string" then return nil end
	local c = M.gowner[g]
	if c ~= nil then
		if c == false then return nil end
		return c
	end
	if not strfind(g, "^0xF1") then
		M.gowner[g] = false
		return nil
	end
	local gf = getglobal("GetUnitField")
	if not gf then return nil end
	local og = nil
	for i = 1, 3 do
		local ok, v = pcall(gf, g, M.OWNERFIELDS[i])
		if not ok then return nil end
		if v and v ~= EMPTY and v ~= 0 and not strfind(v, "^0x0*$") then
			og = v
			break
		end
	end
	if not og then
		M.gowner[g] = false
		return nil
	end
	local name = M.NameOf(og)
	if not name or strfind(name, "^0x") then return nil end
	M.gowner[g] = name
	return name
end
M.OWNERFIELDS = { "summonedBy", "createdBy", "charmedBy" }

-- Etiquette "Gardien : Sort" (une seule chaine par couple, creee a la premiere fois).
function M.GuardLabel(guard, abl)
	local t = M.glabel[guard]
	if not t then
		t = {}
		M.glabel[guard] = t
	end
	local key = abl or EMPTY
	local s = t[key]
	if not s then
		s = guard .. ": " .. key
		t[key] = s
	end
	return s
end

-- Nom d'un sort a partir de son identifiant : SuperWoW SpellInfo, sinon Nampower GetSpellRecField(id, "name"). Faux en cache si inconnu.
function M.SpellName(id)
	local n = M.spname[id]
	if n ~= nil then return n or nil end
	local info = getglobal("SpellInfo")
	local name = nil
	if info then name = info(id) end
	if not name then
		local rec = getglobal("GetSpellRecField")
		if rec then
			local ok, v = pcall(rec, id, "name")
			if ok and type(v) == "string" and v ~= EMPTY then name = v end
		end
	end
	M.spname[id] = name or false
	return name
end

function M.AblName(id)
	local n = M.SpellName(id)
	if n then return n end
	local f = M.spfb[id]
	if not f then
		f = "#" .. tostring(id)
		M.spfb[id] = f
	end
	return f
end

-- ---------------------------------------------------------------- enregistrement des donnees
function M.CreditSeg(seg, kind, name, cls, key, val, eff, now, crit)
	local k = seg.k[kind]
	local e = k[name]
	if not e then
		e = M.NewEntry(name, cls)
		e.first = now
		e.last = now
		k[name] = e
	end
	if seg.start == 0 then seg.start = now end
	e.total = e.total + val
	e.eff = e.eff + eff
	if M.cfg.detail or kind == "interrupts" or kind == "dispels" or kind == "decurse" then
		e.sp[key] = (e.sp[key] or 0) + val
		e.hn[key] = (e.hn[key] or 0) + 1
		if crit then e.hc[key] = (e.hc[key] or 0) + 1 end
		if val > (e.mx[key] or 0) then e.mx[key] = val end
	end
	local gap = now - e.last
	if gap > M.GAP then e.act = e.act + 1 else e.act = e.act + gap end
	e.last = now
	seg.tot[kind] = seg.tot[kind] + val
end

function M.Credit(kind, name, cls, key, val, eff, crit)
	local now = GetTime()
	if not M.cur then M.StartSegment(now) end
	M.lastEvt = now
	M.CreditSeg(M.cur, kind, name, cls, key, val, eff, now, crit)
	M.CreditSeg(M.overall, kind, name, cls, key, val, eff, now, crit)
	M.ver = M.ver + 1
end

-- Garde les derniers coups subis par un membre (anneau de M.RING cases, aucune allocation) : sert au rapport de mort.
function M.Hit(tgt, src, abl, val, now)
	local r = M.ring[tgt]
	if not r then
		r = M.NewRing()
		M.ring[tgt] = r
	end
	local i = r.i + 1
	if i > M.RING then i = 1 end
	r.i = i
	r.n = r.n + 1
	r.s[i], r.a[i], r.v[i], r.t[i] = src, abl, val, now
end

-- Un coup / un soin analyse. src / tgt : noms ; abl : capacite ; val : nombre ; crit : coup critique.
function M.Record(kind, src, abl, tgt, val, crit)
	if not val or val <= 0 or not src or not tgt then return end
	if kind == "damage" then
		if src == tgt then return end
		if M.cls[tgt] and M.cls[src] then return end        -- degats entre membres du groupe (duel, controle mental...) : ignores
		local name, cls, lbl = M.Resolve(src)
		if name then
			M.Credit("damage", name, cls, lbl or abl, val, 0, crit)
			local th = SUI.Threat
			if th and th.Feed then th.Feed("damage", name, tgt, val, abl) end
		end
		local tc = M.cls[tgt]
		if tc and tc ~= "PET" and M.cfg.deaths and not M.cls[src] then M.Hit(tgt, src, abl, val, GetTime()) end
		if M.cfg.detail then
			local tn, tcl = M.Resolve(tgt)
			if tn and not M.cls[src] then M.Credit("taken", tn, tcl, src, val, 0) end
		end
	else
		local name, cls, lbl = M.Resolve(src)
		if not name then return end
		local eff = val
		if M.cfg.overheal then
			local u = M.unit[tgt]
			if u then eff = mmin(val, mmax(UnitHealthMax(u) - UnitHealth(u), 0)) end
		end
		M.Credit("heal", name, cls, lbl or abl, val, eff, crit)
		local th = SUI.Threat
		if th and th.Feed then th.Feed("heal", name, tgt, eff, abl) end
	end
end

function M.Handle(r, c1, c2, c3, c4, c5)
	local caps = M.caps
	caps[1], caps[2], caps[3], caps[4], caps[5] = c1, c2, c3, c4, c5
	local src, tgt, abl, val = nil, nil, nil, nil
	if r.selfSrc then src = M.player end
	if r.selfTgt then tgt = M.player end
	local roles, order = r.roles, r.order
	for i = 1, r.n do
		local role = roles[order[i]]
		if role == "s" then src = caps[i]
		elseif role == "t" then tgt = caps[i]
		elseif role == "a" then abl = caps[i]
		elseif role == "v" then val = tonumber(caps[i]) end
	end
	if r.label == "m" then abl = M.lblMelee elseif r.label == "r" then abl = M.lblReflect end
	if r.kind == "miss" then
		M.RecordMiss(abl)
		return
	end
	M.Record(r.kind, src, abl, tgt, val, r.crit)
end

-- Un coup rate du joueur (esquive, parade, resistance...) : compte dans le detail du sort, sans montant. Seulement pendant un segment.
function M.CreditMiss(seg, name, cls, key)
	local k = seg.k.damage
	local e = k[name]
	if not e then
		e = M.NewEntry(name, cls)
		e.first = GetTime()
		e.last = e.first
		k[name] = e
	end
	e.sp[key] = e.sp[key] or 0
	e.hm[key] = (e.hm[key] or 0) + 1
end

function M.RecordMiss(abl)
	if not M.on or not M.cur or not M.cfg.detail or not abl or not M.player then return end
	local name, cls, lbl = M.Resolve(M.player)
	if not name then return end
	local key = lbl or abl
	M.CreditMiss(M.cur, name, cls, key)
	M.CreditMiss(M.overall, name, cls, key)
	M.ver = M.ver + 1
end

-- Un message du journal de combat (tous les evenements CHAT_MSG_COMBAT_* / CHAT_MSG_SPELL_* utiles).
function M.OnLog(ev, a1)
	if not a1 or not M.on then return end
	local list = M.recs[ev]
	if not list then return end
	for i = 1, getn(list) do
		local r = list[i]
		local s, _, c1, c2, c3, c4, c5 = strfind(a1, r.pat)
		if s then
			M.Handle(r, c1, c2, c3, c4, c5)
			return
		end
	end
end

-- Mode Nampower : le journal texte ne sert qu'aux coups rates (les degats viennent de Nampower).
function M.OnMissLog(ev, a1)
	if not a1 or not M.on then return end
	local list = M.missRecs[ev]
	if not list then return end
	for i = 1, getn(list) do
		local r = list[i]
		local s, _, c1, c2, c3, c4, c5 = strfind(a1, r.pat)
		if s then
			M.Handle(r, c1, c2, c3, c4, c5)
			return
		end
	end
end

-- ---------------------------------------------------------------- morts
-- Une mort de membre du groupe : qui, quand (secondes depuis le debut du segment), de quoi (derniers coups subis).
function M.Death(name)
	if not name or not M.on or not M.cfg.deaths then return end
	local cls = M.cls[name]
	if not cls or cls == "PET" then return end
	local now = GetTime()
	local lt = M.dieT[name]
	if lt and now - lt < 3 then return end
	M.dieT[name] = now
	if not M.cur then M.StartSegment(now) end
	M.lastEvt = now
	if M.overall.start == 0 then M.overall.start = now end
	local d = { name = name, cls = cls, at = now, v = 0, pct = 0, h = {}, nh = 0, total = 0, cause = EMPTY }
	local r = M.ring[name]
	if r and r.n > 0 then
		local n = mmin(r.n, M.RING)
		for k = 1, n do
			local idx = r.i - (k - 1)
			if idx < 1 then idx = idx + M.RING end
			local dt = now - r.t[idx]
			if dt <= M.DEATHWIN then
				d.nh = d.nh + 1
				d.h[d.nh] = { s = r.s[idx], a = r.a[idx], v = r.v[idx], dt = dt }
				d.total = d.total + r.v[idx]
			end
		end
		r.n = 0
	end
	if d.nh > 0 then
		local h = d.h[1]
		d.killer, d.abl, d.amt = h.s, h.a, h.v
		if h.a and h.a ~= h.s then d.cause = h.s .. ": " .. h.a else d.cause = h.s end
	end
	local cs, os = M.cur, M.overall
	if cs.nd < M.MAXDEATH then cs.nd = cs.nd + 1 cs.deaths[cs.nd] = d end
	if os.nd < M.MAXDEATH then os.nd = os.nd + 1 os.deaths[os.nd] = d end
	M.ver = M.ver + 1
end

function M.OnDieLog(ev, a1)
	if not a1 or not M.on or not M.diePat then return end
	local s, _, name = strfind(a1, M.diePat)
	if s then M.Death(name) end
end

function M.OnPlayerDead()
	if M.on then M.Death(M.player) end
end

-- ---------------------------------------------------------------- evenements Nampower
-- Degats d'un guid sur un guid : fusion des gardiens dans leur proprietaire (les familiers du groupe passent par Resolve).
function M.NpDamage(sg, tg, abl, val, crit)
	if not val or val <= 0 then return end
	local src, tgt = M.NameOf(sg), M.NameOf(tg)
	if not src or not tgt then return end
	if M.cfg.mergepets and not M.cls[src] then
		local ow = M.OwnerOf(sg)
		if ow and M.cls[ow] then
			abl = M.GuardLabel(src, abl)
			src = ow
		end
	end
	M.Record("damage", src, abl, tgt, val, crit)
end

function M.OnAuto(ev, a1, a2, a3, a4)
	if not M.on then return end
	local hit = tonumber(a4) or 0
	local crit = (floor(hit / 2) - 2 * floor(hit / 4)) == 1       -- bit 0x2 (suppose pour les coups de melee, comme OctoMeter)
	M.NpDamage(a1, a2, M.lblMelee, tonumber(a3), crit)
end

function M.OnSpellDamage(ev, a1, a2, a3, a4)
	if not M.on then return end
	local hit = tonumber(getglobal(ARGN[6]))
	M.NpDamage(a2, a1, M.AblName(a3), tonumber(a4), hit == 2)
end

function M.OnHeal(ev, a1, a2, a3, a4)
	if not M.on then return end
	local val = tonumber(a4)
	if not val or val <= 0 then return end
	local src, tgt = M.NameOf(a2), M.NameOf(a1)
	local abl = M.AblName(a3)
	if M.cfg.mergepets and not M.cls[src] then
		local ow = M.OwnerOf(a2)
		if ow and M.cls[ow] then
			abl = M.GuardLabel(src, abl)
			src = ow
		end
	end
	M.Record("heal", src, abl, tgt, val, tonumber(getglobal(ARGN[5])) == 1)
end

-- SPELL_DISPEL_BY_*(lanceur, cible, sort DISSIPE) : une maledictions retiree compte aussi dans la vue "maledictions".
function M.OnDispelNP(ev, a1, a2, a3)
	if not M.on or not M.cfg.dispels then return end
	local name, cls = M.Resolve(M.NameOf(a1))
	if not name then return end
	local key = M.AblName(a3)
	M.Credit("dispels", name, cls, key, 1, 0)
	local rec = getglobal("GetSpellRecField")
	if rec then
		local ok, dt = pcall(rec, a3, "dispel")
		if ok and dt == 2 then M.Credit("decurse", name, cls, key, 1, 0) end
	end
end

function M.OnUnitDied(ev, a1)
	if not M.on then return end
	M.Death(M.NameOf(a1))
end

-- ENVIRONMENTAL_DMG_*(guid, type, degats, absorbe, resiste) : type 0 epuisement 1 noyade 2 chute 3 lave 4 vase 5 feu 6 vide.
function M.OnEnv(ev, a1, a2, a3)
	if not M.on then return end
	local val = tonumber(a3)
	local name = M.NameOf(a1)
	local cls = name and M.cls[name]
	if not val or val <= 0 or not cls or cls == "PET" then return end
	local lbl = M.envLbl[tonumber(a2) or -1] or M.envLbl[0]
	if M.cfg.deaths then M.Hit(name, lbl, lbl, val, GetTime()) end
	if M.cfg.detail and M.cur then M.Credit("taken", name, cls, lbl, val, 0) end
end

M.NPFN = { AUTO_ATTACK_SELF = M.OnAuto, AUTO_ATTACK_OTHER = M.OnAuto, SPELL_DAMAGE_EVENT_SELF = M.OnSpellDamage,
	SPELL_DAMAGE_EVENT_OTHER = M.OnSpellDamage, SPELL_HEAL_BY_SELF = M.OnHeal, SPELL_HEAL_BY_OTHER = M.OnHeal,
	SPELL_DISPEL_BY_SELF = M.OnDispelNP, SPELL_DISPEL_BY_OTHER = M.OnDispelNP, UNIT_DIED = M.OnUnitDied,
	ENVIRONMENTAL_DMG_SELF = M.OnEnv, ENVIRONMENTAL_DMG_OTHER = M.OnEnv }

-- Source de donnees : Nampower si elle est la et si le reglage le permet, sinon le journal texte.
function M.WantNP()
	return M.cfg.source ~= "log" and SUI.Api.nampower and true or false
end

-- Active les CVar d'evenements de Nampower (comme OctoMeter) ; une seule fois, avec un message si elles etaient coupees.
function M.EnableCVars()
	if not M.cfg.setcvars then return end
	local gc, sc = getglobal("GetCVar"), getglobal("SetCVar")
	if not gc or not sc then return end
	for i = 1, getn(M.NPCVARS) do
		local cv = M.NPCVARS[i]
		local ok, cur = pcall(gc, cv)
		if ok and tostring(cur) ~= "1" then
			pcall(sc, cv, 1)
			SUI.Print(L("msg.meter.cvar", cv))
		end
	end
end

function M.Attach()
	M.np = M.WantNP()
	if M.np then
		for i = 1, getn(M.NPEVENTS) do SUI.On(M.NPEVENTS[i], M.NPFN[M.NPEVENTS[i]]) end
		for ev in pairs(M.MISSEVENTS) do SUI.On(ev, M.OnMissLog) end
		M.EnableCVars()
	else
		for ev in pairs(M.EVENTS) do SUI.On(ev, M.OnLog) end
		SUI.On("CHAT_MSG_COMBAT_FRIENDLY_DEATH", M.OnDieLog)
	end
	SUI.On("PLAYER_DEAD", M.OnPlayerDead)
end

function M.Detach()
	for i = 1, getn(M.NPEVENTS) do SUI.Off(M.NPEVENTS[i], M.NPFN[M.NPEVENTS[i]]) end
	for ev in pairs(M.EVENTS) do SUI.Off(ev, M.OnLog) end
	for ev in pairs(M.MISSEVENTS) do SUI.Off(ev, M.OnMissLog) end
	SUI.Off("CHAT_MSG_COMBAT_FRIENDLY_DEATH", M.OnDieLog)
	SUI.Off("PLAYER_DEAD", M.OnPlayerDead)
end

-- ---------------------------------------------------------------- interruptions et dispels (SuperWoW : UNIT_CASTEVENT)
M.castUntil, M.castLen, M.failT, M.kickT, M.kickSrc, M.kickAbl, M.spname = {}, {}, {}, {}, {}, {}, {}
M.guidN = 0

function M.TryInterrupt(target, now)
	local kt, ft = M.kickT[target], M.failT[target]
	if not kt or not ft then return end
	if now - kt > 1 or now - ft > 1 then return end
	local src = M.kickSrc[target]
	M.kickT[target], M.failT[target] = nil, nil
	local name, cls = M.Resolve(src)
	if name and M.cfg.interrupts then M.Credit("interrupts", name, cls, M.kickAbl[target], 1, 0) end
end

-- UNIT_CASTEVENT(lanceur, cible, type, sort, duree) : la duree est le 5e argument (global arg5).
function M.OnCastEvent(ev, caster, target, etype, spell)
	if not M.on or not caster then return end
	local now = GetTime()
	if etype == "START" then
		if M.castUntil[caster] == nil then M.guidN = M.guidN + 1 end
		local dur = (tonumber(arg5) or 0) / 1000
		M.castUntil[caster] = now + dur
		M.castLen[caster] = dur
	elseif etype == "FAIL" then
		local until_ = M.castUntil[caster]
		M.castUntil[caster] = nil
		if until_ and M.castLen[caster] > 0 and (until_ - now) > M.castLen[caster] * 0.1 then
			if M.failT[caster] == nil then M.guidN = M.guidN + 1 end
			M.failT[caster] = now
			M.TryInterrupt(caster, now)
		end
	elseif etype == "CAST" then
		M.castUntil[caster] = nil
		local name = M.SpellName(spell)
		if not name then return end
		if M.KICKS[name] and target and target ~= EMPTY then
			local who = UnitName(caster)
			if who and M.cls[who] then
				if M.kickT[target] == nil then M.guidN = M.guidN + 1 end
				M.kickT[target] = now
				M.kickSrc[target] = who
				M.kickAbl[target] = name
				M.TryInterrupt(target, now)
			end
		elseif M.DISPELS[name] and M.cfg.dispels and not M.np then
			local who = UnitName(caster)
			local n, cls = nil, nil
			if who then n, cls = M.Resolve(who) end
			if n then
				M.Credit("dispels", n, cls, name, 1, 0)
				if M.CURSES[name] then M.Credit("decurse", n, cls, name, 1, 0) end
			end
		end
	end
end

function M.CleanGuids()
	if M.guidN < 256 then return end
	for k in pairs(M.castUntil) do M.castUntil[k] = nil end
	for k in pairs(M.castLen) do M.castLen[k] = nil end
	for k in pairs(M.failT) do M.failT[k] = nil end
	for k in pairs(M.kickT) do M.kickT[k] = nil M.kickSrc[k] = nil M.kickAbl[k] = nil end
	-- les caches de proprietaire / etiquettes / sorts-grandissent a chaque guid vu : purges avec le reste
	-- (re-remplis a la demande au prochain passage)
	for k in pairs(M.gowner) do M.gowner[k] = nil end
	for k in pairs(M.glabel) do M.glabel[k] = nil end
	for k in pairs(M.spfb) do M.spfb[k] = nil end
	M.guidN = 0
end

-- ---------------------------------------------------------------- vues
local function byValue(a, b)
	if a.v ~= b.v then return a.v > b.v end
	return a.name < b.name
end

function M.Short(v)
	if v >= 1000000 then return strformat("%.2fM", v / 1000000) end
	if v >= 10000 then return strformat("%.1fk", v / 1000) end
	return strformat("%d", floor(v + 0.5))
end

-- Remplit M.list (trie, decroissant). Retourne nombre, somme, plus grande valeur.
function M.Collect(view, seg)
	local list = M.list
	local n, sum = 0, 0
	if view == "threat" then
		local th = SUI.Threat
		if th and th.GetRows then
			n = th.GetRows(list)
			for i = 1, n do sum = sum + list[i].v end
		end
	elseif view == "deaths" then
		if seg then
			local ds = seg.deaths
			for i = 1, seg.nd do
				local d = ds[i]
				d.v = mmax(d.at - seg.start, 0)
				n = n + 1
				list[n] = d
			end
			sum = n
		end
	elseif seg then
		local kind = M.VIEWKIND[view]
		local k = seg.k[kind]
		local rate = (view == "dps" or view == "hps")
		local fight = (M.cfg.dpsmode == "fight")
		local dur = fight and mmax(M.Duration(seg), 1) or 1
		for _, e in pairs(k) do
			local v = e.total
			if view == "heal" or view == "hps" then v = e.eff end
			if view == "overheal" then v = mmax(e.total - e.eff, 0) end
			if rate then
				if fight then v = v / dur else v = v / mmax(e.act, 1) end
			end
			e.v = v
			sum = sum + v
			n = n + 1
			list[n] = e
		end
		for i = 1, n do list[i].pct = sum > 0 and floor(list[i].v * 100 / sum + 0.5) or 0 end
	end
	for i = getn(list), n + 1, -1 do list[i] = nil end
	if n > 1 then table.sort(list, byValue) end
	M.listn = n
	return n, sum, (n > 0 and list[1].v or 0)
end

-- "m:ss" depuis un nombre de secondes.
function M.Clock(v)
	local s = floor(v + 0.5)
	local m = floor(s / 60)
	return strformat("%d:%02d", m, s - m * 60)
end

function M.ValueText(view, e)
	local v = e.v
	local s
	if view == "deaths" then
		if e.cause and e.cause ~= EMPTY then return M.Clock(v) .. " " .. e.cause end
		return M.Clock(v)
	elseif view == "dps" or view == "hps" then
		s = strformat("%.1f", v)
	elseif view == "interrupts" or view == "dispels" or view == "decurse" then
		s = strformat("%d", floor(v + 0.5))
	elseif M.cfg.shortnum then
		s = M.Short(v)
	else
		s = strformat("%d", floor(v + 0.5))
	end
	if M.cfg.showpct and view ~= "dps" and view ~= "hps" then s = s .. strformat(" %d%%", e.pct or 0) end
	return s
end

-- Lignes de texte d'une vue (rapport, resume). Retourne un tableau de chaines.
function M.Lines(view, sel, n)
	local seg = M.Segment(sel)
	local out = {}
	local count = M.Collect(view, seg)
	local title = L("choice.meter.view." .. view) .. " - " .. M.SegLabel(sel, seg)
	tinsert(out, title)
	for i = 1, mmin(n, count) do
		local e = M.list[i]
		tinsert(out, strformat("%d. %s  %s", i, e.name, M.ValueText(view, e)))
	end
	return out
end

function M.SegLabel(sel, seg)
	if seg and seg.name and sel ~= "overall" then return seg.name end
	return L("choice.meter.seg." .. sel)
end

function M.SendLines(lines, chan)
	if chan == "auto" then
		if GetNumRaidMembers() > 0 then chan = "raid" elseif GetNumPartyMembers() > 0 then chan = "party" else chan = "say" end
	end
	if chan == "self" then
		for i = 1, getn(lines) do SUI.Print(lines[i]) end
		return getn(lines)
	end
	local ch = string.upper(chan)
	for i = 1, getn(lines) do
		local line = lines[i]
		SUI.After(0.25 * (i - 1) + 0.01, function() SendChatMessage(line, ch) end, "meter.report")
	end
	return getn(lines)
end

function M.Report(chan, n, win)
	local cfg = M.cfg
	chan = chan or cfg.reportchan
	n = n or cfg.reportn
	win = win or 1
	return M.SendLines(M.Lines(cfg.view[win], cfg.seg[win], n), chan)
end

-- Resume du segment : un texte par ligne.
function M.Summary(sel)
	local seg = M.Segment(sel or "current")
	if not seg then return { L("msg.meter.nodata") } end
	local out = {}
	tinsert(out, strformat(L("msg.meter.sumhead"), M.SegLabel(sel or "current", seg), floor(M.Duration(seg) + 0.5)))
	for i = 1, getn(M.KINDS) do
		local kind = M.KINDS[i]
		M.Collect(kind, seg)
		local top = M.list[1]
		local line = L("choice.meter.view." .. kind) .. " : " .. M.Short(seg.tot[kind])
		if top then line = line .. strformat(" (%s %s)", top.name, M.Short(top.v)) end
		tinsert(out, line)
	end
	tinsert(out, L("choice.meter.view.deaths") .. " : " .. seg.nd)
	return out
end

-- Export : texte complet (une ligne par joueur et par genre), a copier depuis la fenetre de discussion.
function M.Export(sel)
	local seg = M.Segment(sel or "current")
	if not seg then return { L("msg.meter.nodata") } end
	local out = M.Summary(sel)
	for i = 1, getn(M.KINDS) do
		local kind = M.KINDS[i]
		local n = M.Collect(kind, seg)
		for r = 1, n do
			local e = M.list[r]
			tinsert(out, strformat("%s;%s;%s;%d;%d", kind, e.name, e.cls or "-", floor(e.total), floor(e.eff)))
		end
	end
	for i = 1, seg.nd do
		local d = seg.deaths[i]
		tinsert(out, strformat("deaths;%s;%s;%d;%s", d.name, d.cls or "-", floor(mmax(d.at - seg.start, 0)), d.cause))
	end
	return out
end

-- ---------------------------------------------------------------- police et geometrie
-- Retrouve l'enregistrement de style d'un texte (Theme.lua le garde dans T.items) : la taille de police se change sans toucher au Theme.
function M.Track(fs)
	local n = getn(T.items)
	local it = T.items[n]
	if not it or it.o ~= fs then
		it = nil
		for i = n, 1, -1 do
			if T.items[i].o == fs then it = T.items[i] break end
		end
	end
	fs.suiTk = it
end

-- Police : meter.font (SUI.Look), taille = reglage meter.fontsize. Look repose seul police et taille quand un reglage ou le style change.
function M.SetFont(fs, size)
	local it = fs.suiTk
	if not it then return end
	if fs.suiLookTracked and it.size == size then return end
	it.size = size
	SUI.Look.ApplyText(fs, "meter", size, it.outline)
end

-- Hauteur de ligne et d'en-tete effectives : jamais plus petites que la police (sinon les lignes se chevauchent).
function M.RowH()
	return mmax(M.cfg.rowh, M.cfg.fontsize + 3)
end

function M.Hdr()
	return mmax(M.HDR, M.cfg.fontsize + 8)
end

-- Largeur, hauteur et nombre de lignes d'une fenetre (w.liveW / w.liveH : taille provisoire pendant le glissement de la poignee).
function M.Dims(w)
	local c = M.cfg
	local step = M.RowH() + c.spacing
	local hdr = M.Hdr()
	local width = (w and w.liveW) or c.width
	local height = (w and w.liveH) or (c.height > 0 and c.height) or nil
	local rows
	if height then
		height = mmax(M.MINH, mmin(M.MAXH, height))
		rows = mmax(1, mmin(M.MAXROWS, floor((height - hdr - M.FOOT) / step)))
	else
		rows = mmax(1, mmin(M.MAXROWS, c.rows))
		height = hdr + rows * step + M.FOOT
	end
	return width, height, rows
end

-- ---------------------------------------------------------------- fenetres (construites une fois, hors combat)
function M.RowColor(e)
	if M.cfg.classcolor and e.cls then
		local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.cls]    -- style:ok couleur de classe (donnee du jeu)
		if c then return c.r, c.g, c.b end
	end
	local r, g, b = M.TokenRGB(M.cfg.color)
	if r then return r, g, b end
	return T.Accent()
end

-- Design par jetons du style (aucune couleur en dur) : meter.bg = fond des fenetres (style | panel | bg | inset | none), meter.color =
-- couleur des barres qui ne viennent pas de la classe (style = accent). Valeurs lues dans T.c.* a chaque application (le style peut changer).
M.BGS = { "style", "panel", "bg", "inset", "none" }
M.COLORS = { "style", "good", "warn", "bad", "dim", "text" }
M.nobg = {}

function M.TokenRGB(name)
	local c = (name and name ~= "style") and T.c[name] or nil
	if c then return c[1], c[2], c[3] end
	return nil
end

-- Fond de la fenetre (cadre complet) selon meter.bg ; "none" = meme teinte que le panneau, opacite nulle.
function M.ApplyBack(f, force)
	local tok = M.cfg.bg or "style"
	if f.mbTok == tok and not force then return end     -- redimensionnement a la poignee : pas de nouveau SetBackdrop a chaque pas
	f.mbTok = tok
	if tok == "none" then
		local c = T.c.panel
		local z = M.nobg
		z[1], z[2], z[3], z[4] = c[1], c[2], c[3], 0
		T.Backdrop(f, z, T.c.border)
	elseif tok and tok ~= "style" and T.c[tok] then
		T.Backdrop(f, T.c[tok], T.c.border)
	else
		T.Backdrop(f, T.c.panel, T.c.border)
	end
end

M.tipNames = {}
function M.bySpell(a, b)
	local sp = M.tipEntry.sp
	if sp[a] ~= sp[b] then return sp[a] > sp[b] end
	return a < b
end

-- Remplit M.tipNames avec les sorts de l'entree, du plus fort au plus faible ; retourne leur nombre.
function M.SortedSpells(e)
	local names = M.tipNames
	local n = 0
	for k in pairs(e.sp) do
		n = n + 1
		names[n] = k
	end
	for i = getn(names), n + 1, -1 do names[i] = nil end
	M.tipEntry = e
	table.sort(names, M.bySpell)
	return n
end

local function rowEnter()
	local b = this
	if b.win and M.LevelsStale(b.win) then M.SyncLevels(b.win) end
	if not M.cfg.tooltips or not GameTooltip or not b.entry then return end
	local e = b.entry
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:AddLine(e.name)
	if e.h then
		for i = 1, mmin(8, e.nh) do
			local h = e.h[i]
			GameTooltip:AddLine(strformat("-%.1fs  %s: %s  %s", h.dt, h.s, h.a or EMPTY, M.Short(h.v)))
		end
	elseif e.sp then
		local n = M.SortedSpells(e)
		local names = M.tipNames
		for i = 1, mmin(8, n) do
			GameTooltip:AddLine(names[i] .. "  " .. M.Short(e.sp[names[i]]))
		end
	end
	GameTooltip:Show()
end

-- Infobulle des petits boutons R / X / S / V : sans elle leur role est invisible.
local function tipEnter()
	local r, g, b = T.Accent()
	this:SetBackdropBorderColor(r, g, b, 1)
	local tt = getglobal("GameTooltip")
	if tt and this.tipKey then
		tt:SetOwner(this, "ANCHOR_BOTTOMLEFT")
		tt:SetText(L(this.tipKey))
		tt:Show()
	end
end

local function tipLeave()
	local c = T.c.border
	this:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	local tt = getglobal("GameTooltip")
	if tt then tt:Hide() end
end

local function rowLeave()
	if GameTooltip then GameTooltip:Hide() end
end

-- Decalage de lecture (nombre de joueurs sautes en haut), borne a [0, liste - lignes] ; repeint si change.
function M.ScrollTo(w, off)
	off = floor(off + 0.5)
	local maxoff = mmax(M.listn - (w.nrows or M.cfg.rows), 0)
	if off > maxoff then off = maxoff end
	if off < 0 then off = 0 end
	if off ~= w.off then
		w.off = off
		M.PaintWindow(w)
	end
end

function M.ScrollBy(w, d)
	M.ScrollTo(w, w.off + d)
end

-- Clic sur la barre : saute a la position cliquee (haut = tete du classement, bas = fin de liste).
local function sbClick()
	local b = this
	local w = b.win
	if not w then return end
	local _, cy = GetCursorPosition()
	local es = b:GetEffectiveScale() or 1
	local hh = (b:GetHeight() or 0) * es
	local top = (b:GetTop() or 0) * es
	if hh <= 0 or not cy then return end
	local frac = (top - cy) / hh
	if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
	M.ScrollTo(w, frac * mmax(M.listn - (w.nrows or M.cfg.rows), 0))
end

local function wheel()
	local w = this.win
	if not w then return end
	M.ScrollBy(w, -(arg1 or 0) * M.cfg.wheelstep)
end

local function nextOf(list, cur, step)
	local idx = 1
	for i = 1, getn(list) do if list[i] == cur then idx = i end end
	idx = idx + step
	if idx > getn(list) then idx = 1 elseif idx < 1 then idx = getn(list) end
	return list[idx]
end

-- Bouton V : clic gauche = menu de choix de la vue (liste, vue courante cochee) ; clic droit / molette = defilement (precedente / suivante).
local function onView(b, mb)
	local w = b.win
	if mb == "RightButton" then
		C.Set("meter.view" .. w.i, nextOf(M.VIEWS, M.cfg.view[w.i], -1))
		return
	end
	M.OpenViewMenu(w)
end

local function viewWheel()
	local b = this
	local w = b.win
	if not w then return end
	local step = ((arg1 or 0) > 0) and -1 or 1
	C.Set("meter.view" .. w.i, nextOf(M.VIEWS, M.cfg.view[w.i], step))
end

-- Bouton + : rouvre d'abord la premiere fenetre existante qui est masquee ; sinon en cree une nouvelle.
local function onAdd(b)
	for n = 1, C.Get("meter.windows") do
		if not M.cfg.open[n] then
			C.Set("meter.open" .. n, true)
			SUI.Print(L("msg.meter.opened", n))
			return
		end
	end
	M.NewWindow()
end

-- Bouton - : SUPPRIME la fenetre (la derniere est refusee) apres confirmation (deuxieme clic dans les 3 s).
local function onDel(b)
	local w = b.win
	if C.Get("meter.windows") <= 1 then
		M.DeleteWindow(w.i)
		return
	end
	local now = GetTime()
	if w.cconf and now - w.cconf < 3 then
		w.cconf = nil
		M.DeleteWindow(w.i)
	else
		w.cconf = now
		SUI.Print(L("msg.meter.confirmdel", w.i))
	end
end

local function onSeg(b, mb)
	local w = b.win
	local step = (mb == "RightButton") and -1 or 1
	C.Set("meter.seg" .. w.i, nextOf(M.SEGS, M.cfg.seg[w.i], step))
end

-- Bouton x : MASQUE seulement sa fenetre (etat meter.openN memorise) ; la collecte continue tant qu'une autre fenetre est ouverte et
-- le compteur ne s'endort que lorsque toutes sont masquees. Rouvrir : /sui meter show [n], bouton +, menu. Supprimer : bouton -.
local function onClose(b)
	local w = b.win
	C.Set("meter.open" .. w.i, false)
	if M.AnyOpen() then
		SUI.Print(L("msg.meter.closed1", w.i, w.i))
	else
		SUI.Print(L("msg.meter.closed"))
	end
end

local function onReset(b)
	local w = b.win
	local now = GetTime()
	if w.rconf and now - w.rconf < 3 then
		w.rconf = nil
		M.Reset()
	else
		w.rconf = now
		SUI.Print(L("msg.meter.confirm"))
	end
end

-- Bouton R : clic gauche = envoie le rapport ; clic droit = change le canal (moi seul, auto, dire, groupe, raid, guilde).
local function onReport(b, mb)
	if mb == "RightButton" then
		local nc = nextOf(M.REPORT, M.cfg.reportchan, 1)
		C.Set("meter.reportchan", nc)
		SUI.Print(L("msg.meter.chan", L("choice.meter.reportchan." .. nc)))
		return
	end
	M.Report(nil, nil, b.win.i)
end

-- Clic sur une ligne : detail par sort (gauche), fermeture (droit).
local function rowClick()
	local b = this
	if arg1 == "RightButton" then M.CloseDetail() return end
	if b.entry then M.OpenDetail(b.win, b.entry) end
end

-- Niveaux des controles d une fenetre. Le client 1.12 peut changer le niveau du cadre apres sa construction (cadre releve, lien de
-- position, redimensionnement) : des lignes restees a un niveau perime passent SOUS le cadre de la fenetre, qui capte alors la souris
-- (plus de clic sur le nom d un joueur). On recale donc lignes (+2), barres (+3), boutons (+4) et poignee (+5) sur le niveau reel.
-- Retourne le nombre de cadres recales (diagnostic : /sui meter diag).
function M.SyncLevels(w)
	local f = w.f
	local base = f:GetFrameLevel() or 0
	local n = 0
	for r = 1, getn(w.rows) do
		local b = w.rows[r]
		if b:GetFrameLevel() ~= base + 2 then
			b:SetFrameLevel(base + 2)
			b.bar:SetFrameLevel(base + 3)
			n = n + 1
		end
		b:EnableMouse(true)
	end
	local ctl = w.ctl
	if ctl then
		for i = 1, getn(ctl) do
			if ctl[i]:GetFrameLevel() ~= base + 4 then
				ctl[i]:SetFrameLevel(base + 4)
				n = n + 1
			end
		end
	end
	if w.grip and w.grip:GetFrameLevel() ~= base + 5 then
		w.grip:SetFrameLevel(base + 5)
		n = n + 1
	end
	w.lvl = base
	return n
end

-- Niveaux perimes ? (controle bon marche, sans toucher aux cadres) : cadre, premiere ligne, poignee.
function M.LevelsStale(w)
	local base = w.f:GetFrameLevel() or 0
	if w.lvl ~= base then return true end
	local r1 = w.rows[1]
	if r1 and r1:GetFrameLevel() ~= base + 2 then return true end
	if w.grip and w.grip:GetFrameLevel() ~= base + 5 then return true end
	return false
end

-- Recale les fenetres dont le niveau a derive (le client le change sans evenement : lien de position, cadre releve). Appele a chaque
-- passage de la minuterie et au survol : le survol precede toujours le clic.
function M.CheckLevels()
	for i = 1, M.MAXWIN do
		local w = M.win[i]
		if w and w.f:IsShown() and M.LevelsStale(w) then M.SyncLevels(w) end
	end
end

-- /sui meter diag : par fenetre ouverte, niveau du cadre, nombre de lignes recalees et de lignes captant la souris.
function M.Diag()
	local out = {}
	for i = 1, M.MAXWIN do
		local w = M.win[i]
		if w then
			local fixed = M.SyncLevels(w)
			local mouse = 0
			for r = 1, getn(w.rows) do
				if w.rows[r]:IsMouseEnabled() then mouse = mouse + 1 end
			end
			tinsert(out, L("msg.meter.diag", i, w.f:GetFrameLevel() or 0, fixed, mouse))
		end
	end
	return out
end

-- Ligne sous le curseur (calcul par la position : secours quand le cadre de la fenetre capte le clic a la place d une ligne).
function M.RowAtCursor(w)
	local f = w.f
	local top, left = f:GetTop(), f:GetLeft()
	if not top or not left or not GetCursorPosition then return nil end
	local cx, cy = GetCursorPosition()
	local sc = f:GetEffectiveScale()
	if not sc or sc <= 0 then sc = 1 end
	local x, y = cx / sc - left, top - cy / sc
	local step = M.RowH() + M.cfg.spacing
	if x < 2 or x > f:GetWidth() - 2 or y < M.Hdr() then return nil end
	local idx = floor((y - M.Hdr()) / step) + 1
	if idx < 1 or idx > (w.nrows or 0) then return nil end
	return w.rows[idx]
end

-- Le cadre de la fenetre a recu le clic lui-meme (une ligne est passee dessous) : on retrouve la ligne par la position et on corrige
-- les niveaux pour la suite.
local function winClick()
	local w = this.win
	if not w then return end
	if arg1 == "RightButton" then
		M.CloseDetail()
		return
	end
	M.SyncLevels(w)
	local b = M.RowAtCursor(w)
	if b and b.entry then M.OpenDetail(w, b.entry) end
end

-- Panneaux annexes (detail, menus de segment et de vue) : meme defaut que les fenetres, un panneau qui capte la souris dont les boutons
-- sont restes a un niveau perime ne laisse plus passer aucun clic. La liste des enfants est lue UNE fois (a la construction, hors combat) ;
-- le recalage ne cree rien et se fait a chaque affichage (OnShow) et a chaque ouverture.
function M.WatchPanel(f)
	f.mkids = { f:GetChildren() }
	f:SetScript("OnShow", M.PanelShow)
end

function M.SyncPanel(f)
	if not f or not f.mkids then return 0 end
	local base = f:GetFrameLevel() or 0
	local n = 0
	for i = 1, getn(f.mkids) do
		local k = f.mkids[i]
		if k:GetFrameLevel() <= base then
			k:SetFrameLevel(base + 2)
			n = n + 1
		end
	end
	return n
end

function M.PanelShow()
	M.SyncPanel(this)
end

local function winShow()
	local w = this.win
	if w then M.SyncLevels(w) end
end

-- Survol du cadre de la fenetre (arrive quand une ligne est passee dessous) : on recale avant le clic.
local function winEnter()
	local w = this.win
	if w and M.LevelsStale(w) then M.SyncLevels(w) end
end

local function titleClick()
	local b = this
	M.OpenSegMenu(b.win)
end

function M.BuildRow(w, r)
	local b = CreateFrame("Button", nil, w.f)
	b.win = w
	b.bar = T.Bar(b)
	b.bar:SetPoint("LEFT", b, "LEFT", 0, 0)       -- largeur et hauteur explicites (forme fine : la barre est plus basse que la ligne)
	b.lookOpts = { height = M.RowH() }
	b.name = T.Text(b.bar, M.cfg.fontsize, T.c.text, "LEFT", true)
	M.Track(b.name)
	b.name:SetPoint("LEFT", b.bar, "LEFT", 3, 0)
	b.val = T.Text(b.bar, M.cfg.fontsize, T.c.text, "RIGHT", true)
	M.Track(b.val)
	b.val:SetPoint("RIGHT", b.bar, "RIGHT", -3, 0)
	b:EnableMouseWheel(true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnMouseWheel", wheel)
	b:SetScript("OnEnter", rowEnter)
	b:SetScript("OnLeave", rowLeave)
	b:SetScript("OnClick", rowClick)
	b:Hide()
	return b
end

-- Poignee de coin : on glisse, la fenetre suit la souris (coin haut gauche fixe) ; au relacher, largeur / hauteur / position sont memorisees.
local function gripTick()
	local g = this
	local w = g.win
	local cx, cy = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	if not s or s <= 0 then s = 1 end
	local nw = (cx / s) / w.dsc - w.dl
	local nh = w.dt - (cy / s) / w.dsc
	w.liveW = floor(mmax(M.MINW, mmin(M.MAXW, nw)) + 0.5)
	w.liveH = floor(mmax(M.MINH, mmin(M.MAXH, nh)) + 0.5)
	M.ApplyWindow(w)
end

local function gripDown()
	local g = this
	local w = g.win
	if arg1 ~= "LeftButton" or w.sizing then return end
	local f = w.f
	local l, t = f:GetLeft(), f:GetTop()
	if not l or not t then return end
	w.dl, w.dt, w.dsc = l, t, f:GetScale() or 1
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
	w.sizing = true
	g:SetScript("OnUpdate", gripTick)
end

local function gripUp()
	local g = this
	local w = g.win
	g:SetScript("OnUpdate", nil)
	if not w.sizing then return end
	w.sizing = nil
	M.CommitSize(w)
end

-- Memorise la taille (reglages meter.width / meter.height) et la position (Layout, cle "meter.winN" : relue par le Mover).
function M.CommitSize(w)
	local nw, nh = w.liveW, w.liveH
	w.liveW, w.liveH = nil, nil
	if not nw or not nh then
		SUI.Layout.Apply("meter.win" .. w.i)
		return
	end
	local key = "meter.win" .. w.i
	local _, _, s = C.GetPos(SUI.Layout.ReadKey(key))
	local sc = w.dsc or 1
	C.SetPos(SUI.Layout.WriteKey(key), w.dl * sc, (w.dt - nh) * sc, s or 1)
	C.Set("meter.width", nw)
	C.Set("meter.height", nh)
	SUI.Layout.Apply(key)
	if SUI.Mover and SUI.Mover.Sync then SUI.Mover.Sync() end
end

function M.BuildWindow(i)
	if M.win[i] then return M.win[i] end
	local f = T.Panel(UIParent, 200, 100)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	local w = { f = f, i = i, off = 0, rows = {} }
	f.win = w
	f:SetScript("OnMouseWheel", wheel)
	f:SetScript("OnMouseUp", winClick)
	f:SetScript("OnShow", winShow)
	f:SetScript("OnEnter", winEnter)
	w.title = T.Text(f, M.cfg.fontsize, T.c.text, "LEFT", false)
	M.Track(w.title)
	w.title:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	w.tbtn = CreateFrame("Button", nil, f)
	w.tbtn.win = w
	w.tbtn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	w.tbtn:SetHeight(M.HDR)
	w.tbtn:SetScript("OnClick", titleClick)
	w.bReport = T.Button(f, "R", 16, 14, onReport)
	w.bClose = T.Button(f, "x", 16, 14, onClose)
	w.bReset = T.Button(f, "C", 16, 14, onReset)
	w.bSeg = T.Button(f, "S", 16, 14, onSeg)
	w.bView = T.Button(f, "V", 16, 14, onView)
	w.bDel = T.Button(f, "-", 16, 14, onDel)
	w.bAdd = T.Button(f, "+", 16, 14, onAdd)
	w.bReport.win, w.bReset.win, w.bSeg.win, w.bView.win, w.bDel.win, w.bAdd.win = w, w, w, w, w, w
	w.bClose.win = w
	w.bClose.tipKey = "msg.meter.tip.close"
	w.bReport.tipKey, w.bReset.tipKey, w.bSeg.tipKey, w.bView.tipKey = "msg.meter.tip.report", "msg.meter.tip.reset", "msg.meter.tip.seg",
		"msg.meter.tip.view"
	w.bDel.tipKey, w.bAdd.tipKey = "msg.meter.tip.del", "msg.meter.tip.add"
	w.bView:EnableMouseWheel(true)
	w.bView:SetScript("OnMouseWheel", viewWheel)
	w.ctl = { w.tbtn, w.bClose, w.bReport, w.bReset, w.bSeg, w.bView, w.bDel, w.bAdd }
	for _, bt in ipairs({ w.bClose, w.bReport, w.bReset, w.bSeg, w.bView, w.bDel, w.bAdd }) do
		bt:SetScript("OnEnter", tipEnter)
		bt:SetScript("OnLeave", tipLeave)
	end
	w.bClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	w.bReport:SetPoint("RIGHT", w.bClose, "LEFT", -1, 0)
	w.bReset:SetPoint("RIGHT", w.bReport, "LEFT", -1, 0)
	w.bSeg:SetPoint("RIGHT", w.bReset, "LEFT", -1, 0)
	w.bView:SetPoint("RIGHT", w.bSeg, "LEFT", -1, 0)
	w.bDel:SetPoint("RIGHT", w.bView, "LEFT", -1, 0)
	w.bAdd:SetPoint("RIGHT", w.bDel, "LEFT", -1, 0)
	w.grip = T.Button(f, EMPTY, 10, 10, nil)
	w.grip.win = w
	w.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	w.grip:SetScript("OnMouseDown", gripDown)
	w.grip:SetScript("OnMouseUp", gripUp)
	-- Barre de defilement (a droite des lignes) : piste cliquable + poignee de position ; se cache si tout tient.
	w.sb = CreateFrame("Button", nil, f)
	w.sb.win = w
	w.sb:SetWidth(M.SBW)
	w.sb:RegisterForClicks("LeftButtonUp")
	w.sb:EnableMouseWheel(true)
	w.sb:SetScript("OnMouseWheel", wheel)
	w.sb:SetScript("OnClick", sbClick)
	w.sbTrack = w.sb:CreateTexture(nil, "BACKGROUND")
	w.sbTrack:SetTexture(T.tex.white)
	w.sbTrack:SetAllPoints(w.sb)
	w.sbThumb = w.sb:CreateTexture(nil, "ARTWORK")
	w.sbThumb:SetTexture(T.tex.white)
	w.sbThumb:SetWidth(M.SBW)
	w.sb:Hide()
	tinsert(w.ctl, w.sb)
	for r = 1, M.PREROWS do w.rows[r] = M.BuildRow(w, r) end
	M.win[i] = w
	M.SyncLevels(w)
	SUI.Layout.Register(f, "meter.win" .. i, "BOTTOMRIGHT", -20 - (i - 1) * (mmax(M.cfg.width, 240) + 10), 120)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("meter.win" .. i, f, { label = L("mod.meter.winlabel", i), scale = true })
	end
	f:Hide()
	T.GearButton(f, "meter", { size = 14, point = "TOPRIGHT", x = -122, y = -2, title = L("msg.meter.gear"),
		onCreate = function(g) w.gear = g end })
	M.ApplyWindow(w)
	M.VisAdd(w)
	return w
end

-- Ajoute des lignes si la fenetre en demande plus que celles deja creees (hors combat seulement ; sinon, apres le combat).
function M.GrowRows(w)
	w.growing = false
	local _, _, n = M.Dims(w)
	for r = getn(w.rows) + 1, n do w.rows[r] = M.BuildRow(w, r) end
	M.ApplyWindow(w)
end

function M.ApplyWindow(w)
	local c = M.cfg
	local f = w.f
	local rh, sp = M.RowH(), c.spacing
	local hdr = M.Hdr()
	local width, height, rows = M.Dims(w)
	if getn(w.rows) < rows and not w.growing then
		w.growing = true
		SUI.WhenSafe(function() M.GrowRows(w) end)
	end
	w.nrows = mmin(rows, getn(w.rows))
	f:SetWidth(width)
	f:SetHeight(height)
	M.ApplyBack(f)
	local V = SUI.Visibility
	if V and w.vp and V.byFrame[w.vp] then V.SetBase(w.vp, c.alpha) else f:SetAlpha(c.alpha) end
	w.tbtn:SetWidth(mmax(width - 146, 20))
	w.tbtn:SetHeight(hdr)
	w.title:SetWidth(mmax(width - 146, 20))
	M.SetFont(w.title, c.fontsize)
	local rw = width - 4 - (c.scrollbar and (M.SBW + 2) or 0)     -- la barre de defilement prend la marge de droite
	w.sb:ClearAllPoints()
	w.sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -hdr)
	w.sb:SetHeight(mmax(height - hdr - M.FOOT, 4))
	w.sbk = nil
	for r = 1, getn(w.rows) do
		local b = w.rows[r]
		b:SetWidth(rw)
		b:SetHeight(rh)
		b.bar:SetWidth(rw)
		b.bar:SetHeight(rh)
		b.lookOpts.height = rh
		SUI.Look.ApplyBar(b.bar, "meter", b.lookOpts)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -(hdr + (r - 1) * (rh + sp)))
		M.SetFont(b.name, c.fontsize)
		M.SetFont(b.val, c.fontsize)
		b.lname, b.lval, b.lpct, b.lcol = nil, nil, nil, nil
		b.vis = nil
	end
	w.ttl = nil
	w.hidden = nil
	M.forcePaint = true
	M.SyncLevels(w)
	if w.sizing then M.PaintWindow(w) end
end

function M.PaintWindow(w)
	local c = M.cfg
	local i = w.i
	local view, sel = c.view[i], c.seg[i]
	local seg = M.Segment(sel)
	if w.tview ~= view or w.tsel ~= sel or w.tseg ~= seg or (seg and w.tname ~= seg.name) or w.tloc ~= SUI.locale then
		if w.tview ~= view or w.tsel ~= sel or w.tseg ~= seg then w.off = 0 end     -- autre vue / segment : retour en haut du classement
		w.tview, w.tsel, w.tseg, w.tname, w.tloc = view, sel, seg, seg and seg.name, SUI.locale
		w.title:SetText(L("choice.meter.view." .. view) .. " - " .. M.SegLabel(sel, seg))
	end
	local n, sum, top = M.Collect(view, seg)
	local rows = w.nrows or c.rows
	local maxoff = mmax(n - rows, 0)
	if w.off > maxoff then w.off = maxoff end
	-- Ma ligne reste visible : si je suis hors de la fenetre de lecture, elle prend la premiere (je suis au-dessus) ou la derniere ligne.
	local pin, pinrow = nil, nil
	if c.pinme and rows >= 3 and view ~= "deaths" and M.player and n > rows then
		local list = M.list
		for k = 1, n do
			if list[k].name == M.player then
				if k <= w.off then pin, pinrow = k, 1 elseif k > w.off + rows then pin, pinrow = k, rows end
				break
			end
		end
	end
	for r = 1, getn(w.rows) do
		local b = w.rows[r]
		local e = nil
		if r <= rows then
			if r == pinrow then e = M.list[pin] else e = M.list[w.off + r] end
		end
		if e then
			if not b.vis then b.vis = true b:Show() end
			b.entry = e
			local frac = top > 0 and e.v / top or 0
			if view == "deaths" then frac = 1 end
			b.bar:SetMinMaxValues(0, 1)
			b.bar:SetValue(frac)
			local cr, cg, cb = M.RowColor(e)
			if b.lcol ~= e.cls or M.recolor then
				b.lcol = e.cls
				b.bar:SetStatusBarColor(cr, cg, cb, 1)
			end
			local rank = w.off + r
			if r == pinrow then rank = pin end
			if b.lname ~= e.name or b.lrank ~= rank or b.lpin ~= (r == pinrow) then
				b.lname, b.lrank, b.lpin = e.name, rank, (r == pinrow)
				if c.showrank or r == pinrow then b.name:SetText(strformat("%d. %s", rank, e.name)) else b.name:SetText(e.name) end
			end
			local vt = M.ValueText(view, e)
			if b.lval ~= vt then
				b.lval = vt
				b.val:SetText(vt)
			end
		else
			b.entry = nil
			if b.vis ~= false then
				b.vis = false
				b:Hide()
			end
		end
	end
	M.PaintScroll(w, n, rows)
	w.ver = M.ver
end

-- Barre de defilement : visible seulement si la liste depasse les lignes ; la poignee suit le decalage (ecrite seulement si elle change).
function M.PaintScroll(w, n, rows)
	local sb = w.sb
	local c = M.cfg
	local show = c.scrollbar and n > rows
	if not show then
		if w.sbshown then
			w.sbshown = false
			w.sbk = nil
			sb:Hide()
		end
		return
	end
	local ar, ag, ab = T.Accent()
	local k = n * 1000 + rows * 100000 + w.off
	local acc = ar + ag + ab
	if w.sbshown and w.sbk == k and w.sbacc == acc then return end
	w.sbk, w.sbacc = k, acc
	if not w.sbshown then
		w.sbshown = true
		sb:Show()
	end
	local th = sb:GetHeight() or 0
	local hh = mmax(floor(th * rows / n + 0.5), 8)
	if hh > th then hh = th end
	local maxoff = mmax(n - rows, 1)
	local y = floor((th - hh) * w.off / maxoff + 0.5)
	w.sbThumb:SetHeight(hh)
	w.sbThumb:ClearAllPoints()
	w.sbThumb:SetPoint("TOPRIGHT", sb, "TOPRIGHT", 0, -y)
	w.sbTrack:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 0.5)
	w.sbThumb:SetVertexColor(ar, ag, ab, 0.9)
end

function M.Paint()
	M.forcePaint = false
	for i = 1, M.MAXWIN do
		local w = M.win[i]
		if w and w.f:IsShown() then M.PaintWindow(w) end
	end
	M.recolor = false
	M.paintedVer = M.ver
	M.RefreshDetail()
end

-- Fenetre i ouverte (existante et non masquee) ? Au moins une fenetre ouverte ?
function M.IsOpen(i)
	return (i >= 1 and i <= M.cfg.windows and M.cfg.open[i]) and true or false
end

function M.AnyOpen()
	for i = 1, M.cfg.windows do
		if M.cfg.open[i] then return true end
	end
	return false
end

-- Menace : la vue "threat" d'une fenetre OUVERTE a besoin que le module Menace tourne (Feed + paquets) meme si sa propre fenetre est fermee.
function M.SyncThreat()
	local want = false
	if M.on and M.awake then
		for i = 1, M.cfg.windows do
			if M.cfg.open[i] and M.cfg.view[i] == "threat" then want = true end
		end
	end
	if want == M.threatClient then return end
	M.threatClient = want
	local th = SUI.Threat
	if th and th.SetClient then th.SetClient(want) end
end

-- Anciens reglages : meter.show = false (tout ferme) devient meter.open1..4 = false, par mode ; l'ancienne cle est effacee.
function M.Migrate()
	local Cf = SUI.Config
	local cur = Cf.cur
	if type(cur) ~= "table" or type(cur.v) ~= "table" then return end
	if cur.v["meter.show"] ~= nil then
		local was = cur.v["meter.show"]
		cur.v["meter.show"] = nil
		if was == false then
			for n = 1, M.MAXWIN do Cf.SetIn("normal", "meter.open" .. n, false) end
		end
	end
	if type(cur.mm) == "table" then
		for mode, o in pairs(cur.mm) do
			if type(o) == "table" and o["meter.show"] ~= nil then
				local was = o["meter.show"]
				o["meter.show"] = nil
				if was == false then
					for n = 1, M.MAXWIN do Cf.SetIn(mode, "meter.open" .. n, false) end
				end
			end
		end
	end
end

-- La fenetre i doit-elle exister a l'ecran selon le module (module actif, fenetre ouverte et comptee) ? La regle de visibilite
-- (meter.vis, SUI.Visibility) s'y ajoute : elle fond l'opacite puis cache, sans jamais rouvrir une fenetre fermee.
function M.WinWanted(i)
	local c = M.cfg
	return (M.on and c.open[i] and i <= c.windows) and true or false
end

function M.HideWindow(w)
	if w.f:IsShown() then w.f:Hide() end
	if M.detWin == w then M.CloseDetail() end
	if M.menuWin == w then M.CloseSegMenu() end
	if M.vmenuWin == w then M.CloseViewMenu() end
end

-- Mandataire d'une fenetre aupres du service de visibilite (une simple table, aucune frame) : Show ne montre que ce que le module veut.
local function vpSetAlpha(self, a) self.win.f:SetAlpha(a) end
local function vpGetAlpha(self) return self.win.f:GetAlpha() end
local function vpIsShown(self) return self.win.f:IsShown() end
local function vpShow(self)
	local w = self.win
	if M.WinWanted(w.i) and not w.f:IsShown() then
		w.f:Show()
		M.forcePaint = true
	end
end
local function vpHide(self) M.HideWindow(self.win) end

function M.VisAdd(w)
	local V = SUI.Visibility
	if not V or not M.on then return end
	if not w.vp then
		w.vp = { win = w, SetAlpha = vpSetAlpha, GetAlpha = vpGetAlpha, IsShown = vpIsShown, Show = vpShow, Hide = vpHide }
	end
	if V.byFrame[w.vp] then return end
	V.Add(w.vp, "meter", { mode = "show", module = "meter", alpha = M.cfg.alpha, cat = "meter" })
end

-- Retire les mandataires quand le module est coupe (differe : Remove detache un observateur, jamais pendant une notification de Config).
function M.VisDrop()
	local V = SUI.Visibility
	if M.on or not V then return end
	for i = 1, M.MAXWIN do
		local w = M.win[i]
		if w and w.vp then V.Remove(w.vp) end
	end
end

function M.UpdateVisibility()
	local V = SUI.Visibility
	M.SyncThreat()
	for i = 1, M.MAXWIN do
		local w = M.win[i]
		if w then
			if M.WinWanted(i) then
				if not w.f:IsShown() and (not V or not w.vp or V.Allowed(w.vp)) then
					w.f:Show()
					M.forcePaint = true
				end
			else
				M.HideWindow(w)
			end
		end
	end
end

-- ---------------------------------------------------------------- detail d'un joueur (panneau) et choix du segment
-- Colonnes du detail par sort : total, part, coups, critiques, moyenne, maximum, rates (esquive, parade, resistance : degats du joueur).
M.DETCOLS = { "total", "pct", "hits", "crit", "avg", "max", "miss" }
M.DETX = { 114, 164, 196, 228, 262, 304, 346 }
M.DETW = { 48, 30, 30, 32, 40, 40, 32 }
M.DETTABS = { "damage", "heal", "taken" }
M.DETY0 = 62
M.DETWIDTH = 384

local function onDetReport()
	M.ReportDetail(nil)
end

local function onDetClose()
	M.CloseDetail()
end

local function onDetTab(b)
	M.SetDetailTab(b.kind)
end

local function detUp()
	if arg1 == "RightButton" then M.CloseDetail() end
end

local function detWheel()
	local d = M.det
	if not d or not M.detCnt then return end
	local off = (M.detOff or 0) - (arg1 or 0)
	local maxoff = mmax(M.detCnt - M.DETLINES, 0)
	if off < 0 then off = 0 end
	if off > maxoff then off = maxoff end
	if off ~= M.detOff then
		M.detOff = off
		M.RefreshDetail()
	end
end

local function setCell(l, k, text)
	if l.t[k] ~= text then
		l.t[k] = text
		l.c[k]:SetText(text)
	end
end

function M.BuildDetail()
	if M.det then return M.det end
	local f = T.Panel(UIParent, M.DETWIDTH, M.DETY0 + M.DETLINES * 13 + 20)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", detWheel)
	f:SetScript("OnMouseUp", detUp)
	local d = { f = f, lines = {}, tabs = {}, hdr = {} }
	d.title = T.Text(f, 11, T.c.text, "LEFT", false)
	d.title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
	d.title:SetWidth(280)
	d.sub = T.Text(f, 9, T.c.dim, "LEFT", false)
	d.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -19)
	d.sub:SetWidth(M.DETWIDTH - 12)
	d.bClose = T.Button(f, "X", 16, 14, onDetClose)
	d.bRep = T.Button(f, "R", 16, 14, onDetReport)
	d.bClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	d.bRep:SetPoint("RIGHT", d.bClose, "LEFT", -1, 0)
	d.bClose.tipKey, d.bRep.tipKey = "msg.meter.tip.detclose", "msg.meter.tip.detrep"
	for k = 1, getn(M.DETTABS) do
		local b = T.Button(f, EMPTY, 74, 14, onDetTab)
		b.kind = M.DETTABS[k]
		b.tipKey = "msg.meter.tip.dettab"
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (k - 1) * 76, -31)
		d.tabs[k] = b
	end
	for _, bt in ipairs({ d.bClose, d.bRep, d.tabs[1], d.tabs[2], d.tabs[3] }) do
		bt:SetScript("OnEnter", tipEnter)
		bt:SetScript("OnLeave", tipLeave)
	end
	d.hname = T.Text(f, 9, T.c.dim, "LEFT", false)
	d.hname:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -50)
	for k = 1, getn(M.DETCOLS) do
		local h = T.Text(f, 9, T.c.dim, "RIGHT", false)
		h:SetPoint("TOPLEFT", f, "TOPLEFT", M.DETX[k], -50)
		h:SetWidth(M.DETW[k])
		d.hdr[k] = h
	end
	for i = 1, M.DETLINES do
		local l = { c = {}, t = {} }
		local y = -(M.DETY0 + (i - 1) * 13)
		l.name = T.Text(f, 10, T.c.text, "LEFT", false)
		l.name:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y)
		l.name:SetWidth(106)
		l.val = T.Text(f, 10, T.c.text, "RIGHT", false)
		l.val:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, y)
		l.val:SetWidth(140)
		for k = 1, getn(M.DETCOLS) do
			local fs = T.Text(f, 10, T.c.text, "RIGHT", false)
			fs:SetPoint("TOPLEFT", f, "TOPLEFT", M.DETX[k], y)
			fs:SetWidth(M.DETW[k])
			l.c[k] = fs
		end
		d.lines[i] = l
	end
	d.foot = T.Text(f, 9, T.c.dim, "LEFT", false)
	d.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 4)
	d.foot:SetWidth(M.DETWIDTH - 12)
	M.WatchPanel(f)
	f:Hide()
	M.det = d
	return d
end

function M.CloseDetail()
	M.detName, M.detDeath, M.detWin, M.detKind, M.detView, M.detTab, M.detOff, M.detCnt = nil, nil, nil, nil, nil, nil, 0, 0
	if M.det and M.det.f:IsShown() then M.det.f:Hide() end
end

-- Le panneau de detail est-il permis pour cette vue ? (reglage "detail" ; les comptages gardent toujours leurs sorts.)
function M.DetailOK(view)
	if view == "threat" or not view then return false end
	if view == "deaths" then return true end
	return M.cfg.detail or M.COUNTKIND[M.VIEWKIND[view]] == true
end

-- Ouvre le panneau pour une ligne (entree de joueur, ou mort).
function M.OpenDetail(w, e)
	local d = M.det
	if not d and not SUI.InCombat() then d = M.BuildDetail() end
	if not d or not w then return end
	if M.detWin == w and ((e.h and M.detDeath == e) or (not e.h and M.detName == e.name)) and d.f:IsShown() then
		M.CloseDetail()
		return
	end
	local view = M.cfg.view[w.i]
	if not M.DetailOK(view) then
		if view ~= "threat" then SUI.Print(L("msg.meter.detoff")) end
		return
	end
	M.detWin, M.detView, M.detTab, M.detOff = w, view, nil, 0
	if e.h then
		M.detKind, M.detDeath, M.detName = "deaths", e, nil
	else
		M.detKind, M.detName, M.detDeath = M.VIEWKIND[view], e.name, nil
	end
	d.f:ClearAllPoints()
	if (w.f:GetLeft() or 0) > M.DETWIDTH + 40 then
		d.f:SetPoint("TOPRIGHT", w.f, "TOPLEFT", -4, 0)
	else
		d.f:SetPoint("TOPLEFT", w.f, "TOPRIGHT", 4, 0)
	end
	d.f:SetScale(w.f:GetScale() or 1)
	d.f:Show()
	M.SyncPanel(d.f)
	M.RefreshDetail()
end

-- Onglet : le meme joueur vu en degats, en soins ou en degats subis.
function M.SetDetailTab(kind)
	local d = M.det
	if not d or not d.f:IsShown() or not M.detName or M.COUNTKIND[M.detKind] then return end
	M.detKind = kind
	M.detTab = (kind ~= M.VIEWKIND[M.detView]) and true or nil
	M.detOff = 0
	M.RefreshDetail()
end

-- Ligne d'un detail par sort : une valeur par colonne.
local function fillSpell(l, e, key, kind, total)
	local v = e.sp[key]
	local hn = e.hn[key] or 0
	local hc = e.hc[key] or 0
	local mx = e.mx[key] or 0
	local hm = e.hm[key] or 0
	l.name:SetText(key)
	setCell(l, 1, M.Short(v))
	setCell(l, 2, total > 0 and strformat("%d%%", floor(v * 100 / total + 0.5)) or "-")
	setCell(l, 3, hn > 0 and strformat("%d", hn) or "-")
	setCell(l, 4, (hn > 0 and kind ~= "taken") and strformat("%d%%", floor(hc * 100 / hn + 0.5)) or "-")
	setCell(l, 5, hn > 0 and M.Short(v / hn) or "-")
	setCell(l, 6, mx > 0 and M.Short(mx) or "-")
	setCell(l, 7, (kind == "damage" and hm > 0) and strformat("%d", hm) or "-")
end

-- Remplit le panneau depuis les donnees vivantes ; le ferme si la ligne a disparu (remise a zero, autre vue, autre segment).
function M.RefreshDetail()
	local d = M.det
	if not d or not d.f:IsShown() then return end
	local w = M.detWin
	if not w or M.cfg.view[w.i] ~= M.detView then M.CloseDetail() return end
	local seg = M.Segment(M.cfg.seg[w.i])
	local e, kind = nil, M.detKind
	if kind == "deaths" then
		if seg then
			for i = 1, seg.nd do
				if seg.deaths[i] == M.detDeath then e = M.detDeath end
			end
		end
	elseif seg then
		e = seg.k[kind][M.detName]
	end
	if not e and not M.detTab then M.CloseDetail() return end
	local isDeath = (kind == "deaths")
	local isCount = M.COUNTKIND[kind] and true or false
	local tabbed = (not isDeath and not isCount)
	-- onglets et en-tetes (textes relus si la langue change)
	if d.loc ~= SUI.locale then
		d.loc = SUI.locale
		for k = 1, getn(d.tabs) do T.SetButtonText(d.tabs[k], L("choice.meter.view." .. M.DETTABS[k])) end
		d.hname:SetText(L("msg.meter.col.spell"))
		for k = 1, getn(M.DETCOLS) do d.hdr[k]:SetText(L("msg.meter.col." .. M.DETCOLS[k])) end
	end
	for k = 1, getn(d.tabs) do
		local b = d.tabs[k]
		if tabbed then
			if not b:IsShown() then b:Show() end
			T.SetSelected(b, b.kind == kind)
		elseif b:IsShown() then
			b:Hide()
		end
	end
	if d.wide ~= tabbed then
		d.wide = tabbed
		for k = 1, getn(M.DETCOLS) do
			if tabbed then d.hdr[k]:Show() else d.hdr[k]:Hide() end
		end
		if tabbed then d.hname:Show() else d.hname:Hide() end
		for i = 1, M.DETLINES do
			d.lines[i].name:SetWidth(tabbed and 106 or 220)
		end
	end
	local name = e and e.name or M.detName
	local label = M.detView
	if M.detTab then label = kind end
	d.title:SetText(name .. " - " .. L("choice.meter.view." .. label))
	local n = 0
	local cnt = 0
	if not e then
		d.sub:SetText(L("msg.meter.detnone"))
	elseif isDeath then
		d.sub:SetText(strformat(L("msg.meter.detdeath"), M.Clock(mmax(e.at - (seg and seg.start or e.at), 0)), M.Short(e.total or 0)))
		cnt = e.nh
		for i = 1, mmin(M.DETLINES, e.nh) do
			local h = e.h[i]
			local l = d.lines[i]
			l.name:SetText(strformat("-%.1fs  %s", h.dt, h.s))
			l.val:SetText((h.a and h.a ~= h.s and (h.a .. "  ") or EMPTY) .. M.Short(h.v))
			n = i
		end
	else
		local total = e.total
		if isCount then
			d.sub:SetText(strformat(L("msg.meter.detcount"), floor(total)))
		else
			local s = strformat(L("msg.meter.dettotal"), M.Short(total), M.Short(e.eff or total))
			if e.act and e.act > 0 and total > 0 then
				s = s .. "  -  " .. strformat(L("msg.meter.detrate"), M.Short(total / e.act), M.Clock(e.act))
			end
			d.sub:SetText(s)
		end
		cnt = M.SortedSpells(e)
		local names = M.tipNames
		local off = M.detOff or 0
		if off > mmax(cnt - M.DETLINES, 0) then off = mmax(cnt - M.DETLINES, 0) end
		M.detOff = off
		for i = 1, mmin(M.DETLINES, cnt - off) do
			local key = names[off + i]
			local l = d.lines[i]
			if isCount then
				l.name:SetText(key)
				l.val:SetText(strformat("%d", floor(e.sp[key] + 0.5)))
			else
				fillSpell(l, e, key, kind, total)
			end
			n = i
		end
	end
	M.detCnt = cnt
	for i = 1, M.DETLINES do
		local l = d.lines[i]
		if i > n then
			l.name:SetText(EMPTY)
			l.val:SetText(EMPTY)
			for k = 1, getn(M.DETCOLS) do setCell(l, k, EMPTY) end
		elseif tabbed then
			l.val:SetText(EMPTY)
		else
			for k = 1, getn(M.DETCOLS) do setCell(l, k, EMPTY) end
		end
	end
	d.foot:SetText(strformat(L("msg.meter.dethint"), cnt))
	M.detN = n
end

-- Rapport du detail ouvert : titre puis les premieres lignes.
function M.ReportDetail(chan)
	local d = M.det
	if not d or not d.f:IsShown() then return 0 end
	chan = chan or M.cfg.reportchan
	local out = { d.title:GetText() }
	for i = 1, mmin(M.cfg.reportn, M.detN or 0) do
		local l = d.lines[i]
		local v = l.val:GetText()
		if not v or v == EMPTY then
			-- detail par sort : total, part, coups, critiques
			v = (l.t[1] or EMPTY) .. "  " .. (l.t[2] or EMPTY) .. "  x" .. (l.t[3] or EMPTY) .. "  " .. (l.t[4] or EMPTY) .. "c"
		end
		out[i + 1] = l.name:GetText() .. "  " .. v
	end
	return M.SendLines(out, chan)
end

local function onSegPick(b)
	local w = M.menuWin
	if w and b.sel then C.Set("meter.seg" .. w.i, b.sel) end
	M.CloseSegMenu()
end

function M.BuildSegMenu()
	if M.menu then return M.menu end
	local f = T.Panel(UIParent, 190, 20)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	local m = { f = f, btn = {} }
	for i = 1, 11 do
		local b = T.Button(f, EMPTY, 180, 14, onSegPick)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -(5 + (i - 1) * 15))
		b:Hide()
		m.btn[i] = b
	end
	M.WatchPanel(f)
	f:Hide()
	M.menu = m
	return m
end

function M.CloseSegMenu()
	M.menuWin = nil
	if M.menu and M.menu.f:IsShown() then M.menu.f:Hide() end
end

-- Menu des segments d'une fenetre : actuel, total, boss, puis les derniers combats finis.
function M.OpenSegMenu(w)
	local m = M.menu
	if not m or not w then return end
	if M.menuWin == w and m.f:IsShown() then M.CloseSegMenu() return end
	M.CloseViewMenu()
	M.menuWin = w
	local n = 0
	local function add(sel, text)
		n = n + 1
		local b = m.btn[n]
		b.sel = sel
		T.SetButtonText(b, text)
		b:Show()
	end
	add("current", L("choice.meter.seg.current"))
	add("overall", L("choice.meter.seg.overall"))
	if M.lastBoss then add("boss", L("choice.meter.seg.boss") .. " : " .. (M.lastBoss.name or EMPTY)) end
	for i = 1, mmin(getn(M.hist), 8) do
		local s = M.hist[i]
		add("h" .. i, strformat("%d. %s  %s", i, s.name or EMPTY, M.Clock(M.Duration(s))))
	end
	for i = n + 1, 11 do m.btn[i]:Hide() end
	m.f:SetHeight(10 + n * 15)
	m.f:ClearAllPoints()
	if (w.f:GetBottom() or 0) < 260 then
		m.f:SetPoint("BOTTOMLEFT", w.f, "TOPLEFT", 0, 2)
	else
		m.f:SetPoint("TOPLEFT", w.f, "BOTTOMLEFT", 0, -2)
	end
	m.f:SetScale(w.f:GetScale() or 1)
	m.f:Show()
	M.SyncPanel(m.f)
end

-- Menu des vues d'une fenetre : une vue par ligne, la vue courante cochee.
local function onViewPick(b)
	local w = M.vmenuWin
	if w and b.sel then C.Set("meter.view" .. w.i, b.sel) end
	M.CloseViewMenu()
end

function M.BuildViewMenu()
	if M.vmenu then return M.vmenu end
	local f = T.Panel(UIParent, 190, 20)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	local m = { f = f, btn = {} }
	for i = 1, getn(M.VIEWS) do
		local b = T.Button(f, EMPTY, 180, 14, onViewPick)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -(5 + (i - 1) * 15))
		b:Hide()
		m.btn[i] = b
	end
	M.WatchPanel(f)
	f:Hide()
	M.vmenu = m
	return m
end

function M.CloseViewMenu()
	M.vmenuWin = nil
	if M.vmenu and M.vmenu.f:IsShown() then M.vmenu.f:Hide() end
end

function M.OpenViewMenu(w)
	local m = M.vmenu
	if not m or not w then return end
	if M.vmenuWin == w and m.f:IsShown() then M.CloseViewMenu() return end
	M.CloseSegMenu()
	M.vmenuWin = w
	local cur = M.cfg.view[w.i]
	local n = getn(M.VIEWS)
	for i = 1, n do
		local v = M.VIEWS[i]
		local b = m.btn[i]
		b.sel = v
		T.SetButtonText(b, ((v == cur) and "[x] " or "[ ] ") .. L("choice.meter.view." .. v))
		T.SetSelected(b, v == cur)
		b:Show()
	end
	m.f:SetHeight(10 + n * 15)
	m.f:ClearAllPoints()
	if (w.f:GetBottom() or 0) < 260 then
		m.f:SetPoint("BOTTOMLEFT", w.f, "TOPLEFT", 0, 2)
	else
		m.f:SetPoint("TOPLEFT", w.f, "BOTTOMLEFT", 0, -2)
	end
	m.f:SetScale(w.f:GetScale() or 1)
	m.f:Show()
	M.SyncPanel(m.f)
end

-- ---------------------------------------------------------------- creation / suppression de fenetres
-- Recopie la position enregistree de la fenetre src vers dst, pour tous les modes (ou l'efface si src n'en a pas).
function M.MovePos(src, dst)
	local Cf = SUI.Config
	local sk, dk = "meter.win" .. src, "meter.win" .. dst
	local sufs = { EMPTY }
	local order = Cf.modeOrder or {}
	for i = 1, getn(order) do
		if order[i] ~= "normal" then sufs[getn(sufs) + 1] = "|" .. order[i] end
	end
	for i = 1, getn(sufs) do
		local l, b, s = Cf.GetPos(sk .. sufs[i])
		if l then Cf.SetPos(dk .. sufs[i], l, b, s) else Cf.ClearPos(dk .. sufs[i]) end
	end
end

-- Ajoute une fenetre (vue differente des autres si possible). Borne : M.MAXWIN.
function M.NewWindow()
	local n = floor(C.Get("meter.windows"))
	if n >= M.MAXWIN then
		SUI.Print(L("msg.meter.maxwin", M.MAXWIN))
		return false
	end
	n = n + 1
	local pick = "damage"
	for k = 1, getn(M.VIEWS) do
		local used = false
		for j = 1, n - 1 do
			if C.Get("meter.view" .. j) == M.VIEWS[k] then used = true end
		end
		if not used then pick = M.VIEWS[k] break end
	end
	SUI.Config.ClearPosAll("meter.win" .. n)
	C.Set("meter.view" .. n, pick)
	C.Set("meter.seg" .. n, "current")
	C.Set("meter.open" .. n, true)
	C.Set("meter.windows", n)
	SUI.Config.Notify("pos", nil)
	SUI.Print(L("msg.meter.newwin", n))
	return true
end

-- Supprime la fenetre i : les suivantes prennent sa place (vue, segment, position).
function M.DeleteWindow(i)
	local n = floor(C.Get("meter.windows"))
	if n <= 1 then
		SUI.Print(L("msg.meter.lastwin"))
		return false
	end
	if type(i) ~= "number" or i < 1 or i > n then return false end
	for j = i, n - 1 do
		M.MovePos(j + 1, j)
		C.Set("meter.view" .. j, C.Get("meter.view" .. (j + 1)))
		C.Set("meter.seg" .. j, C.Get("meter.seg" .. (j + 1)))
		C.Set("meter.open" .. j, C.Get("meter.open" .. (j + 1)))
	end
	C.Set("meter.open" .. n, true)
	SUI.Config.ClearPosAll("meter.win" .. n)
	C.Set("meter.windows", n - 1)
	M.CloseDetail()
	M.CloseViewMenu()
	M.CloseSegMenu()
	SUI.Config.Notify("pos", nil)
	for j = i, n do
		if SUI.Layout.items["meter.win" .. j] then SUI.Layout.Apply("meter.win" .. j) end
	end
	SUI.Print(L("msg.meter.delwin", i))
	return true
end

-- ---------------------------------------------------------------- minuterie et reglages
function M.Tick()
	if not M.on then return end
	local now = GetTime()
	if M.rosterDirty then M.ScanRoster() end
	if M.cur and now - M.lastEvt >= M.cfg.idle and not UnitAffectingCombat("player") then M.EndSegment() end
	M.CleanGuids()
	M.UpdateVisibility()
	M.CheckLevels()
	if M.forcePaint or M.ver ~= M.paintedVer then M.Paint() end
end

function M.ReadConfig()
	local c = M.cfg
	for i = 1, M.MAXWIN do c.open[i] = C.Get("meter.open" .. i) end
	c.windows = C.Get("meter.windows")
	c.rows = C.Get("meter.rows")
	c.rowh = C.Get("meter.rowh")
	c.width = C.Get("meter.width")
	c.height = C.Get("meter.height")
	c.fontsize = C.Get("meter.fontsize")
	c.spacing = C.Get("meter.spacing")
	c.alpha = C.Get("meter.alpha")
	c.classcolor = C.Get("meter.classcolor")
	c.bg = C.Get("meter.bg")
	c.color = C.Get("meter.color")
	c.showrank = C.Get("meter.showrank")
	c.showpct = C.Get("meter.showpct")
	c.pinme = C.Get("meter.pinme")
	c.scrollbar = C.Get("meter.scrollbar")
	c.wheelstep = C.Get("meter.wheelstep")
	c.shortnum = C.Get("meter.shortnum")
	c.refresh = C.Get("meter.refresh")
	c.idle = C.Get("meter.idle")
	c.minlen = C.Get("meter.minlen")
	c.segments = C.Get("meter.segments")
	c.dpsmode = C.Get("meter.dpsmode")
	c.mergepets = C.Get("meter.mergepets")
	c.trackall = C.Get("meter.trackall")
	c.detail = C.Get("meter.detail")
	c.overheal = C.Get("meter.overheal")
	c.interrupts = C.Get("meter.interrupts")
	c.dispels = C.Get("meter.dispels")
	c.deaths = C.Get("meter.deaths")
	c.autoreset = C.Get("meter.autoreset")
	c.tooltips = C.Get("meter.tooltips")
	c.source = C.Get("meter.source")
	c.setcvars = C.Get("meter.setcvars")
	c.reportn = C.Get("meter.reportn")
	c.reportchan = C.Get("meter.reportchan")
	for i = 1, M.MAXWIN do
		c.view[i] = C.Get("meter.view" .. i)
		c.seg[i] = C.Get("meter.seg" .. i)
	end
end

function M.ApplyAll()
	for i = 1, M.MAXWIN do
		if M.win[i] then M.ApplyWindow(M.win[i]) end
	end
	M.UpdateVisibility()
	M.forcePaint = true
end

function M.EnsureWindows()
	if not M.on then return end
	for i = 1, M.cfg.windows do M.BuildWindow(i) end
	for i = 1, M.MAXWIN do
		if M.win[i] then M.VisAdd(M.win[i]) end
	end
	M.BuildDetail()
	M.BuildSegMenu()
	M.BuildViewMenu()
	M.ApplyAll()
	M.Paint()
end

-- Ancien reglage meter.hideooc (cacher hors combat) : migre vers meter.vis = "combat" (SUI.Visibility) et reste synchronise avec lui
-- (la case "Cacher hors combat" est un raccourci de Visibilite = combat seulement ; l'assistant de premier lancement l'ecrit encore).
function M.SyncVis(key)
	local vis, old = C.Get("meter.vis"), C.Get("meter.hideooc")
	if key == "meter.hideooc" then
		if old and vis == "always" then C.Set("meter.vis", "combat")
		elseif not old and vis == "combat" then C.Set("meter.vis", "always") end
		return
	end
	if key == nil and old and vis == "always" then
		vis = "combat"
		C.Set("meter.vis", vis)
	end
	if old ~= (vis == "combat") then C.Set("meter.hideooc", vis == "combat") end
end

function M.OnKey(key, value)
	if key == nil then M.Migrate() end
	if key == nil or key == "meter.vis" or key == "meter.hideooc" then M.SyncVis(key) end
	local oldw = M.cfg.windows
	M.ReadConfig()
	-- Ajouter des fenetres (reglage "Fenetres") les montre : une fenetre qui apparait n'est jamais creee masquee.
	if key == "meter.windows" and M.cfg.windows > oldw then
		for i = floor(oldw) + 1, floor(M.cfg.windows) do
			if not M.cfg.open[i] then C.Set("meter.open" .. i, true) end
		end
	end
	-- Changer le nombre de lignes rend la main au nombre de lignes (la hauteur fixe de la poignee est abandonnee).
	if key == "meter.rows" and M.cfg.height > 0 then
		C.Set("meter.height", 0)
	end
	if key == nil or key == "meter.color" or key == "meter.classcolor" then M.recolor = true end
	if not M.on then return end
	if not M.AnyOpen() then
		M.Sleep()
		M.UpdateVisibility()
		return
	end
	if not M.awake then
		M.Wake()
	elseif key == nil or key == "meter.source" then
		M.Detach()
		M.Attach()
	elseif key == "meter.setcvars" and M.np then
		M.EnableCVars()
	end
	M.TrimHistory()
	M.Prime()
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(M.cfg.refresh, M.Tick, "meter.tick", true)
	local need = false
	for i = 1, M.cfg.windows do
		if not M.win[i] then need = true end
	end
	if M.det and M.det.f:IsShown() and not M.DetailOK(M.detView) then M.CloseDetail() end
	if need then
		SUI.WhenSafe(M.EnsureWindows)
	else
		M.ApplyAll()
		M.Paint()    -- effet immediat (sans attendre la minuterie)
	end
end

function M.OnLocale()
	M.lblMelee = L("msg.meter.melee")
	M.lblReflect = L("msg.meter.reflect")
	for i = 0, 6 do M.envLbl[i] = L(M.ENVKEYS[i]) end
	M.rosterDirty = true
	M.forcePaint = true
end

function M.OnTarget()
	if M.cur then M.CheckBoss() end
end

function M.OnAccent()
	M.recolor = true
	M.forcePaint = true
	for i = 1, M.MAXWIN do
		if M.win[i] then M.ApplyBack(M.win[i].f, true) end     -- le repeint du style remet le fond du panneau : on repose le choix de l'utilisateur
	end
end

-- ---------------------------------------------------------------- cycle de vie
-- Eveil / sommeil : tout ce qui consomme du CPU (evenements, ecoute du combat, minuterie) n'existe que si AU MOINS UNE fenetre est ouverte (meter.openN).
function M.Wake()
	if M.awake then return end
	M.awake = true
	M.ScanRoster()
	M.lastRaidN = GetNumRaidMembers()
	M.Attach()
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("UNIT_PET", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	if SUI.Api.superwow then SUI.On("UNIT_CASTEVENT", M.OnCastEvent) end
	M.task = SUI.Every(M.cfg.refresh, M.Tick, "meter.tick", true)
end

-- Fin de combat : remise a zero automatique si meter.autoreset est coche (et un combat a eu lieu).
function M.OnCombatEnd()
	if not M.cfg.autoreset or not M.fought then return end
	M.fought = nil
	M.Reset()
end

function M.Sleep()
	if not M.awake then return end
	M.awake = false
	M.Detach()
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombatEnd)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("UNIT_PET", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTarget)
	SUI.Off("UNIT_CASTEVENT", M.OnCastEvent)
	SUI.Cancel(M.task)
	M.task = nil
	M.EndSegment()
	M.SyncThreat()
end

function M.Enable()
	M.Migrate()
	M.SyncVis(nil)
	M.on = true
	M.ReadConfig()
	if not M.overall then
		M.overall = M.NewShell()
	end
	M.BuildPatterns()
	M.OnLocale()
	M.Prime()
	if not M.watching then
		M.watching = true
		C.Watch("meter.", M.OnKey)
		C.Watch("ui.locale", M.OnLocale)
		T.OnAccent(M.OnAccent)
	end
	if M.AnyOpen() then M.Wake() end
	if not M.warned then
		M.warned = true
		local isl = getglobal("IsAddOnLoaded")
		if isl then
			local others = { "DPSMate", "ShaguDPS", "OctoMeter" }
			for i = 1, getn(others) do
				if isl(others[i]) then SUI.Print(L("msg.meter.other", others[i])) end
			end
		end
	end
	SUI.WhenSafe(M.EnsureWindows)
end

function M.Disable()
	M.on = false
	M.Sleep()
	M.SyncThreat()
	M.CloseDetail()
	M.CloseSegMenu()
	M.CloseViewMenu()
	for i = 1, M.MAXWIN do
		if M.win[i] then M.win[i].f:Hide() end
	end
	if SUI.Visibility then SUI.After(0.05, M.VisDrop, "meter.visdrop") end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("meter", 37)

-- Page de reglages : Essentiel (simple) = fenetre et vue ; Tout = + affichage, donnees, fenetres 2 et 3, rapport.
local function opt(key, typ, order, def, extra)
	local o = { key = "meter." .. key, type = typ, cat = "meter", label = "opt.meter." .. key, tip = "tip.meter." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function viewText(o, v) return L("choice.meter.view." .. v) end
local function segText(o, v) return L("choice.meter.seg." .. v) end
local function srcText(o, v) return L("choice.meter.source." .. v) end
local function bgText(o, v) return L("choice.meter.bg." .. v) end
local function colText(o, v) return L("choice.meter.color." .. v) end

local SW, SD, SDA, SX, SR = "mod.meter.sec.window", "mod.meter.sec.display", "mod.meter.sec.data", "mod.meter.sec.extra", "mod.meter.sec.report"
local SLK = "mod.meter.sec.look"

-- Options communes du socle : visibilite (meter.vis / .fade), texture de barre, forme et police (meter.bartex / .shape / .font ;
-- la taille de police reste meter.fontsize, deja existante).
local function addCommon(list)
	local d = SUI.Visibility.Options("meter", { cat = "meter", order = 800, simple = true })
	for i = 1, getn(d) do
		d[i].section = SLK
		tinsert(list, d[i])
	end
	d = SUI.Look.Options("meter", { bar = true, shape = true, font = true, cat = "meter", order = 820 })
	for i = 1, getn(d) do
		if d[i].key ~= "meter.fontsize" then
			d[i].section = SLK
			tinsert(list, d[i])
		end
	end
	tinsert(list, opt("bg", "choice", 830, "style", { choices = M.BGS, choiceText = bgText, section = SLK }))
	tinsert(list, opt("color", "choice", 831, "style", { choices = M.COLORS, choiceText = colText, section = SLK }))
	return list
end

SUI.RegisterModule("meter", {
	default = false,
	cost = "medium",
	options = addCommon({
		opt("open1", "bool", 5, true, { simple = true, section = SW }),
		opt("windows", "number", 10, 1, { min = 1, max = M.MAXWIN, step = 1, simple = true, section = SW }),
		opt("view1", "choice", 20, "damage", { choices = M.VIEWS, choiceText = viewText, simple = true, section = SW }),
		opt("seg1", "choice", 30, "current", { choices = M.SEGCHOICES, choiceText = segText, simple = true, section = SW }),
		opt("width", "number", 40, 240, { min = M.MINW, max = M.MAXW, step = 10, simple = true, section = SW }),
		opt("height", "number", 50, 0, { min = 0, max = M.MAXH, step = 10, simple = true, section = SW }),
		opt("rows", "number", 60, 10, { min = 3, max = M.MAXROWS, step = 1, simple = true, section = SW }),
		opt("fontsize", "number", 70, 11, { min = 8, max = 18, step = 1, simple = true, section = SW }),
		opt("rowh", "number", 80, 16, { min = 10, max = 30, step = 1, section = SW }),
		opt("spacing", "number", 90, 1, { min = 0, max = 4, step = 1, section = SW }),
		opt("alpha", "number", 100, 0.9, { min = 0.3, max = 1, step = 0.1, section = SW }),
		opt("hideooc", "bool", 110, false, { section = SW }),
		opt("classcolor", "bool", 120, true, { simple = true, section = SD }),
		opt("showrank", "bool", 130, true, { section = SD }),
		opt("showpct", "bool", 140, true, { section = SD }),
		opt("pinme", "bool", 142, true, { simple = true, section = SD }),
		opt("scrollbar", "bool", 144, true, { section = SD }),
		opt("wheelstep", "number", 146, 1, { min = 1, max = 10, step = 1, section = SD }),
		opt("shortnum", "bool", 150, true, { section = SD }),
		opt("tooltips", "bool", 160, true, { section = SD }),
		opt("source", "choice", 170, "auto", { choices = M.SOURCES, choiceText = srcText, section = SDA }),
		opt("setcvars", "bool", 180, true, { section = SDA }),
		opt("mergepets", "bool", 190, true, { section = SDA }),
		opt("detail", "bool", 200, true, { section = SDA }),
		opt("overheal", "bool", 210, false, { section = SDA }),
		opt("interrupts", "bool", 220, true, { section = SDA }),
		opt("dispels", "bool", 230, true, { section = SDA }),
		opt("deaths", "bool", 240, true, { section = SDA }),
		opt("trackall", "bool", 250, false, { section = SDA }),
		opt("dpsmode", "choice", 260, "active", { choices = { "active", "fight" }, section = SDA }),
		opt("segments", "number", 270, 8, { min = 1, max = 20, step = 1, section = SDA }),
		opt("idle", "number", 280, 8, { min = 3, max = 30, step = 1, section = SDA }),
		opt("minlen", "number", 290, 3, { min = 0, max = 30, step = 1, section = SDA }),
		opt("refresh", "number", 300, 1, { min = 0.25, max = 3, step = 0.25, section = SDA }),
		opt("autoreset", "bool", 310, false, { section = SDA }),
		opt("open2", "bool", 318, true, { section = SX }),
		opt("view2", "choice", 320, "heal", { choices = M.VIEWS, choiceText = viewText, section = SX }),
		opt("seg2", "choice", 330, "current", { choices = M.SEGCHOICES, choiceText = segText, section = SX }),
		opt("open3", "bool", 338, true, { section = SX }),
		opt("view3", "choice", 340, "taken", { choices = M.VIEWS, choiceText = viewText, section = SX }),
		opt("seg3", "choice", 350, "overall", { choices = M.SEGCHOICES, choiceText = segText, section = SX }),
		opt("open4", "bool", 351, true, { section = SX }),
		opt("view4", "choice", 352, "interrupts", { choices = M.VIEWS, choiceText = viewText, section = SX }),
		opt("seg4", "choice", 354, "current", { choices = M.SEGCHOICES, choiceText = segText, section = SX }),
		opt("reportn", "number", 360, 5, { min = 3, max = 10, step = 1, section = SR }),
		opt("reportchan", "choice", 370, "self", { choices = M.REPORT, simple = true, section = SR }),
	}),
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Pas d'equivalent pfUI a remplacer : le module "thirdparty" de pfUI ne fait que HABILLER DPSMate / ShaguDPS / TWThreat (peau et
-- accrochage au panneau). Meter n'est donc pas inscrit dans Migrate.MAP (jamais retenu par pfUI). Les compteurs externes qui tournent
-- en meme temps font le travail en double : un message le signale a l'activation.
-- Mode Raid : version minimale.
SUI.Config.AddPreset("raid", "*", { ["meter.windows"] = 1, ["meter.rows"] = 8, ["meter.height"] = 0, ["meter.refresh"] = 2,
	["meter.segments"] = 2, ["meter.tooltips"] = false, ["meter.trackall"] = false })

-- /sui meter show|hide|toggle [n] : rouvre ou masque la fenetre n (toutes sans n). "show" active le module si besoin.
function M.SetShown(want, n)
	if n and (n < 1 or n > M.MAXWIN or n ~= floor(n)) then
		SUI.Print(L("msg.meter.badwin", M.MAXWIN))
		return
	end
	if want and n and n > C.Get("meter.windows") then
		SUI.Print(L("msg.meter.nowin", n))
		return
	end
	if want and not M.on then C.Set("modules.meter", true) end
	if want and C.Get("meter.vis") ~= "always" then C.Set("meter.vis", "always") end
	if n then
		C.Set("meter.open" .. n, want)
		SUI.Print(L(want and "msg.meter.shown1" or "msg.meter.hidden1", n))
		return
	end
	for k = 1, C.Get("meter.windows") do C.Set("meter.open" .. k, want) end
	SUI.Print(L(want and "msg.meter.shown" or "msg.meter.hidden"))
end

SUI.RegisterCommand("meter", function(rest)
	local word, arg = rest or EMPTY, nil
	local sp = strfind(word, " ", 1, true)
	if sp then arg = strsub(word, sp + 1) word = strsub(word, 1, sp - 1) end
	if word == "reset" then
		M.Reset()
		SUI.Print(L("msg.meter.reset"))
	elseif word == "report" then
		local chan, n = arg, nil
		if arg then
			local sp2 = strfind(arg, " ", 1, true)
			if sp2 then chan = strsub(arg, 1, sp2 - 1) n = tonumber(strsub(arg, sp2 + 1)) end
		end
		local ok = false
		for i = 1, getn(M.REPORT) do if M.REPORT[i] == chan then ok = true end end
		if chan and not ok then SUI.Print(L("msg.meter.badchan", chan)) return end
		if n then n = mmax(1, mmin(10, floor(n))) end
		M.Report(chan, n, 1)
	elseif word == "summary" then
		local lines = M.Summary(arg ~= EMPTY and arg or nil)
		for i = 1, getn(lines) do SUI.Print(lines[i]) end
	elseif word == "export" then
		local lines = M.Export(arg ~= EMPTY and arg or nil)
		for i = 1, getn(lines) do SUI.Print(lines[i]) end
	elseif word == "deaths" then
		local lines = M.Lines("deaths", (arg and arg ~= EMPTY) and arg or "current", 10)
		for i = 1, getn(lines) do SUI.Print(lines[i]) end
	elseif word == "show" then
		M.SetShown(true, tonumber(arg))
	elseif word == "hide" then
		M.SetShown(false, tonumber(arg))
	elseif word == "toggle" then
		local k = tonumber(arg)
		if k then
			M.SetShown(not (M.on and M.IsOpen(k)), k)
		else
			M.SetShown(not (M.on and M.AnyOpen()))
		end
	elseif word == "diag" then
		local lines = M.Diag()
		for i = 1, getn(lines) do SUI.Print(lines[i]) end
	elseif word == "new" then
		M.NewWindow()
	elseif word == "del" or word == "delete" then
		local k = tonumber(arg)
		if not k then k = C.Get("meter.windows") end
		M.DeleteWindow(floor(k))
	else
		SUI.Print(L("msg.meter.status", M.nrecs, M.nmissing, getn(M.hist), M.cfg.windows))
		SUI.Print(L(SUI.Api.superwow and "msg.meter.sw" or "msg.meter.nosw"))
		SUI.Print(L(M.np and "msg.meter.srcnp" or "msg.meter.srclog"))
	end
end, "help.meter")

-- /sui meters [show|hide|toggle] : masque ou rouvre d un coup les compteurs (degats/soins ET menace) ; aussi accessible par un raccourci
function M.ToggleAll(want)
	local T = SUI.Threat
	local anyOn = (M.on and M.AnyOpen()) or (T and T.on and C.Get("threat.show"))
	if want == nil then want = not anyOn end
	M.SetShown(want)
	if T and T.SetShown then T.SetShown(want) end
end
SUI.RegisterCommand("meters", function(rest)
	if rest == "show" then M.ToggleAll(true) elseif rest == "hide" then M.ToggleAll(false) else M.ToggleAll() end
end, "help.meter.all")
setglobal("BINDING_NAME_SHIKIUI_METERS", L("msg.meter.bind"))
