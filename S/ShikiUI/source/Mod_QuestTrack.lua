-- ShikiUI QuestTrack : suivi des quetes en cours. Une petite liste deplacable a l'ecran (titre + objectifs de chaque quete du journal, lus par l'API
-- du client, sans aucune donnee), et, avec le module Codex, les objectifs de TOUTES ces quetes epingles sur la carte du monde (rond "o" : objectif
-- d'une quete en cours, "?" : rendu d'une quete terminee). Un clic sur un titre epingle la quete seule (comme /sui codex pin).
-- Les donnees de quetes (ShikiCodexData_Quests) ne sont chargees que carte ouverte ou au clic, jamais au login : la liste, elle, n'en a pas besoin.
-- Titre du journal -> numero de quete : par le titre (anglais ou francais), puis le niveau affiche dans le journal ; titre inconnu : la quete reste
-- dans la liste mais n'a pas d'epingle. Evenements : QUEST_LOG_UPDATE (regroupes, 0,3 s), PLAYER_ENTERING_WORLD. Aucune minuterie permanente.
-- NON VERIFIE EN JEU : GetNumQuestLeaderBoards(i) / GetQuestLogLeaderBoard(j, i) avec l'indice de quete en 2e argument (1.12), zones repliees du
-- journal (leurs quetes ne sont pas listees par le client : elles manquent ici aussi).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local slower, sformat = string.lower, string.format
local floor = math.floor

local M = {}
SUI.QuestTrack = M

M.on = false
M.DELAY = 0.3                -- silence attendu apres le dernier QUEST_LOG_UPDATE
M.MAXQ = 15                  -- plafond dur de quetes affichees
M.MAXOBJ = 8                 -- objectifs affiches par quete
M.PAD = 6
M.ver = 0                    -- change a chaque modification du journal (invalide les caches)
M.list = {}                  -- quetes lues : { i, title, level, complete, objs = { { text, done } }, id = nil | false | numero }
M.rows = {}                  -- lignes du cadre (creees a la demande)
M.sig = nil
M.recs = {}                  -- enregistrements de carte deja construits : [numero .. ":" .. etat]

local function glob(name)
	return getglobal(name)
end

-- ---------------------------------------------------------------- lecture du journal
-- Quetes du journal, dans l'ordre du client (les en-tetes de zone sont sautes). nil si l'API manque.
function M.Read()
	local gn, gt = glob("GetNumQuestLogEntries"), glob("GetQuestLogTitle")
	if not gn or not gt then return nil end
	local ok, n = pcall(gn)
	if not ok or type(n) ~= "number" then return nil end
	local gnb, gb = glob("GetNumQuestLeaderBoards"), glob("GetQuestLogLeaderBoard")
	local out = {}
	local zone = nil
	for i = 1, n do
		local ok2, title, level, _, isHeader, _, isComplete = pcall(gt, i)
		if ok2 and type(title) == "string" and isHeader then zone = title end
		if ok2 and type(title) == "string" and not isHeader then
			local e = { i = i, title = title, level = tonumber(level) or 0, complete = (isComplete == 1), objs = {}, zone = zone }
			if gnb and gb then
				local ok3, no = pcall(gnb, i)
				if ok3 and type(no) == "number" then
					if no > M.MAXOBJ then no = M.MAXOBJ end
					for j = 1, no do
						local ok4, text, _, done = pcall(gb, j, i)
						if ok4 and type(text) == "string" and text ~= "" then
							tinsert(e.objs, { text = text, done = (done == 1 or done == true) })
						end
					end
				end
			end
			tinsert(out, e)
		end
	end
	return out
end

-- Signature de la liste (texte) : repeindre seulement si elle change
function M.Signature(list)
	local s = ""
	for i = 1, getn(list) do
		local e = list[i]
		s = s .. e.title .. "|" .. e.level .. "|" .. (e.complete and "1" or "0")
		for j = 1, getn(e.objs) do s = s .. "|" .. e.objs[j].text .. (e.objs[j].done and "+" or "-") end
		s = s .. "\n"
	end
	return s
end

-- ---------------------------------------------------------------- titre -> numero de quete (donnees du Codex)
local function codex()
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.P then return Cx end
	return nil
end

-- Index titre minuscule -> { numeros } (anglais et francais), construit une fois quand les donnees sont chargees
function M.TitleIndex(Cx)
	if M.tix then return M.tix end
	local P = Cx.P
	local ok = P.LoadQuests()
	if not ok then return nil end
	local qd = P.Q()
	if not qd or not qd.en or not qd.en.t then return nil end
	local idx = {}
	local function add(id, t)
		if type(t) ~= "string" then return end
		local k = slower(t)
		local l = idx[k]
		if not l then
			idx[k] = { id }
		elseif l[getn(l)] ~= id then
			tinsert(l, id)
		end
	end
	for id, t in pairs(qd.en.t) do add(id, t) end
	if qd.fr and qd.fr.t then
		for id, t in pairs(qd.fr.t) do add(id, t) end
	end
	M.tix = idx
	return idx
end

-- Numero de la quete d'une ligne du journal : niveau identique d'abord, sinon le plus petit numero ; false = inconnue ; nil = donnees indisponibles
-- Mots d'un titre (sans accents ni petits mots), tronques a 4 lettres : "nettoyage" ~ "nettoyer", "tannepeau" ~ "tanneur"
function M.TitleWords(t)
	local out = {}
	for w in string.gfind(M.FoldName(t), "[%a%d]+") do
		if string.len(w) >= 4 then tinsert(out, string.sub(w, 1, 4)) end
	end
	return out
end

-- Quete la plus proche par les mots du titre (meme niveau que la ligne du journal, au moins la moitie des mots en commun) ; nil si aucune
function M.FuzzyId(Cx, e)
	local qd = Cx.P.Q()
	if not qd or not qd.en or not qd.en.t then return nil end
	local want = M.TitleWords(e.title)
	local nw = getn(want)
	if nw == 0 then return nil end
	local best, bs = nil, 0
	local function scan(tt)
		if type(tt) ~= "table" then return end
		for id, t in pairs(tt) do
			if type(t) == "string" then
				local lvl = Cx.P.QuestLevels(id)
				if lvl == e.level or (lvl == nil and e.level == nil) then
					local have = M.TitleWords(t)
					local nh = getn(have)
					if nh > 0 then
						local hits = 0
						for i = 1, nw do
							for j = 1, nh do
								if have[j] == want[i] then
									hits = hits + 1
									break
								end
							end
						end
						local sc = hits / (nw > nh and nw or nh)
						if sc >= 0.5 and (sc > bs or (sc == bs and best and id < best)) then best, bs = id, sc end
					end
				end
			end
		end
	end
	scan(qd.fr and qd.fr.t)
	scan(qd.en.t)
	return best
end

function M.Resolve(e)
	if e.id ~= nil then return e.id end
	local Cx = codex()
	if not Cx then return nil end
	local idx = M.TitleIndex(Cx)
	if not idx then return nil end
	local l = idx[slower(e.title)]
	if not l then
		-- titres du serveur francais differents des donnees ("Eagan Tannepeau" / "Eagan le tanneur") : rapprochement par mots
		e.id = M.FuzzyId(Cx, e) or false
		return e.id
	end
	local best, any = nil, nil
	for k = 1, getn(l) do
		local id = l[k]
		if not any or id < any then any = id end
		local lvl = Cx.P.QuestLevels(id)
		if lvl == e.level and (not best or id < best) then best = id end
	end
	e.id = best or any
	return e.id
end

-- ---------------------------------------------------------------- choix des quetes affichees
-- "questtrack.hide" : cles "titre#niveau" des quetes retirees de la liste, separees par "|" (cle hors menu). Tout le reste du journal est affiche.
-- "questtrack.arrowq" : cle de la quete visee par la fleche ("" = la plus proche). M.list reste le journal entier ; M.View() est ce qu'on montre.
M.MAXHIDE = 60
SUI.Config.Register({ ["questtrack.hide"] = "", ["questtrack.arrowq"] = "" })

function M.Key(e)
	local k = string.gsub(e.title, "|", "")
	return k .. "#" .. e.level
end

local function hideSet()
	local s = C.Get("questtrack.hide")
	if type(s) ~= "string" then return "" end
	return s
end

function M.IsShown(e)
	return not string.find("|" .. hideSet() .. "|", "|" .. M.Key(e) .. "|", 1, true)
end

-- Montre / retire une quete de la liste (enregistre ; les plus anciennes retraits sont oublies au-dela de M.MAXHIDE)
function M.SetShown(e, on)
	local key = M.Key(e)
	local arr = {}
	for k in string.gfind(hideSet(), "[^|]+") do
		if k ~= key then tinsert(arr, k) end
	end
	if not on then tinsert(arr, key) end
	while getn(arr) > M.MAXHIDE do table.remove(arr, 1) end
	C.Set("questtrack.hide", table.concat(arr, "|"))
end

function M.SetAllShown(on)
	if on then
		C.Set("questtrack.hide", "")
		return
	end
	local arr = {}
	for i = 1, getn(M.list) do tinsert(arr, M.Key(M.list[i])) end
	while getn(arr) > M.MAXHIDE do table.remove(arr, 1) end
	C.Set("questtrack.hide", table.concat(arr, "|"))
end

local function zoneNow()
	local f = glob("GetRealZoneText") or glob("GetZoneText")
	if not f then return nil end
	local ok, z = pcall(f)
	if ok and type(z) == "string" and z ~= "" then return z end
	return nil
end

-- Quetes montrees : le journal sans les retraits ; zoneOnly (liste a l'ecran seulement) : seulement celles de la zone ou tu es, si elle est connue
function M.View(zoneOnly)
	local out = {}
	local zn = zoneOnly and C.Get("questtrack.zoneonly") and zoneNow() or nil
	for i = 1, getn(M.list) do
		local e = M.list[i]
		if M.IsShown(e) and (not zn or e.zone == zn) then tinsert(out, e) end
	end
	return out
end

function M.NumShown()
	local n = 0
	for i = 1, getn(M.list) do
		if M.IsShown(M.list[i]) then n = n + 1 end
	end
	return n
end

-- ---------------------------------------------------------------- enregistrements de carte (fournisseur du Codex)
-- Copie d'un enregistrement du Codex ne gardant que les epingles de type `kind` ("O" objectifs, "E" rendu) ; nil sans epingle
local function filtered(rec, kind)
	local out = { id = rec.id, t = rec.t, n = 0, zones = {} }
	for i = 1, getn(rec.zones) do
		local g = rec.zones[i]
		local ng = { en = g.en, fr = g.fr, map = g.map, zid = g.zid, n = 0, pins = {} }
		for k = 1, getn(g.pins) do
			if g.pins[k].k == kind then
				tinsert(ng.pins, g.pins[k])
				ng.n = ng.n + 1
			end
		end
		if ng.n > 0 then
			out.n = out.n + ng.n
			tinsert(out.zones, ng)
		end
	end
	if out.n == 0 then return nil end
	return out
end

-- ---------------------------------------------------------------- donneurs de quetes ("!" sur la carte)
-- Index { numero de zone -> liste d'entrees { id, lvl, min, races, classes, x, y, ref } } des epingles de DEPART de toutes les quetes, construit par
-- paquets (M.GCHUNK quetes par tour) la premiere fois que la carte est ouverte, puis garde (quelques dizaines de ko par millier de quetes).
M.GCHUNK = 400
M.GCELL = 2.5                -- cote (en % de carte) d'une cellule : les donneurs d'une meme cellule ne font qu'un "!"
M.GTIPMAX = 6                -- quetes listees dans l'infobulle d'un "!"

local function splitSec(s)
	local out, pos = {}, 1
	local a = string.find(s, ";", pos, true)
	while a do
		tinsert(out, string.sub(s, pos, a - 1))
		pos = a + 1
		a = string.find(s, ";", pos, true)
	end
	tinsert(out, string.sub(s, pos))
	return out
end

-- Masques de pfQuest du joueur (race, classe) ; nil si inconnus (aucun filtre)
function M.PlayerBits()
	local ur, uc = glob("UnitRace"), glob("UnitClass")
	local RACE = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
	local CLASS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
	local rb, cb
	if ur then
		local ok, _, en = pcall(ur, "player")
		if ok and type(en) == "string" then rb = RACE[en] end
	end
	if uc then
		local ok, _, tok = pcall(uc, "player")
		if ok and type(tok) == "string" then cb = CLASS[tok] end
	end
	return rb, cb
end

local function hasBit(mask, b)
	local q = floor(mask / b)
	return q - floor(q / 2) * 2 == 1
end

function M.GiverStart()
	if M.gready or M.gbuilding then return end
	local Cx = codex()
	if not Cx then return end
	local P = Cx.P
	if not P.LoadQuests() then return end
	local qd = P.Q()
	if not qd or type(qd.q) ~= "table" then return end
	local ids = {}
	for id in pairs(qd.q) do tinsert(ids, id) end
	M.gids, M.gpos, M.gby, M.gbuilding = ids, 1, {}, true
	M.GiverStep()
end

function M.GiverStep()
	M.gtask = nil
	local Cx = codex()
	if not M.on or not Cx then
		M.gbuilding, M.gids, M.gby = false, nil, nil
		return
	end
	local P = Cx.P
	local qd = P.Q()
	local ids, by = M.gids, M.gby
	local last = M.gpos + M.GCHUNK - 1
	if last > getn(ids) then last = getn(ids) end
	for k = M.gpos, last do
		local id = ids[k]
		local s = qd.q[id]
		if type(s) == "string" and string.find(s, "S", 1, true) then
			local f = splitSec(s)
			local pins = P.QuestPins(id)
			for i = 1, pins and getn(pins) or 0 do
				local p = pins[i]
				if p.kind == "S" then
					local l = by[p.zone]
					if not l then
						l = {}
						by[p.zone] = l
					end
					tinsert(l, { id = id, lvl = tonumber(f[1]) or 0, min = tonumber(f[2]) or 0, races = tonumber(f[3]) or 0, classes = tonumber(f[4]) or 0,
						x = p.x, y = p.y, ref = p.ref })
				end
			end
		end
	end
	M.gpos = last + 1
	if M.gpos > getn(ids) then
		M.gready, M.gbuilding, M.gids = true, false, nil
		if Cx.trackFn == M.Recs and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
	else
		M.gtask = SUI.After(0.02, M.GiverStep, "questtrack.giver")
	end
end

-- Quete du journal portant ce titre ? (inutile de proposer une quete deja prise)
local function inLog(title)
	for i = 1, getn(M.list) do
		if M.list[i].title == title then return true end
	end
	return false
end

-- Titres du journal en minuscules (recalcule quand la liste change)
local function logTitles()
	if M.lts and M.ltsVer == M.ver then return M.lts end
	local t = {}
	for i = 1, getn(M.list) do t[slower(M.list[i].title)] = true end
	M.lts, M.ltsVer = t, M.ver
	return t
end

-- Vrai si la quete `id` du Codex est deja dans le journal, quel que soit la langue du titre (anglais ou francais)
local function inLogId(P, id)
	local lt = logTitles()
	local qd = P.Q()
	if not qd then return false end
	local en = qd.en and qd.en.t and qd.en.t[id]
	local fr = qd.fr and qd.fr.t and qd.fr.t[id]
	if en and lt[slower(en)] then return true end
	if fr and lt[slower(fr)] then return true end
	return false
end

-- Enregistrements des donneurs de la zone affichee (c, z) selon le niveau, la race et la classe du joueur ; nil si aucun
function M.GiverRec(Cx, c, z)
	if not M.gready or not c or not z or z <= 0 then return nil end
	local P = Cx.P
	local ul = glob("UnitLevel")
	local pl = ul and ul("player") or 0
	if type(pl) ~= "number" or pl < 1 then return nil end
	local low = C.Get("questtrack.giverlow")
	local high = C.Get("questtrack.giverhigh")
	if type(high) ~= "number" then high = 0 end
	local rb, cb = M.PlayerBits()
	M.zinfo = nil
	local out = nil
	M.gz = M.gz or {}
	for zid, list in pairs(M.gby) do
		local gz = M.gz[zid]
		if gz == nil then
			local en, fr = P.ZoneBoth(zid)
			if en then
				gz = { id = -1, t = L("msg.questtrack.givers"), cap = Cx.PIN_POOL, n = 0, zones = { { en = en, fr = fr, map = P.ZoneMap(zid), zid = zid, n = 0, pins = {} } } }
			else
				gz = false
			end
			M.gz[zid] = gz
		end
		if gz and Cx.PinHere(gz, c, z) then
			local cells, pins = {}, {}
			local zs = { lo = 0, hi = 0, ok = 0, up = 0 }
			for i = 1, getn(list) do
				local e = list[i]
				if e.lvl and e.lvl > 0 then
					if zs.lo == 0 or e.lvl < zs.lo then zs.lo = e.lvl end
					if e.lvl > zs.hi then zs.hi = e.lvl end
				end
				local grey = e.min ~= 0 and e.min > pl
				local ok = (e.min == 0 or e.min <= pl + high) and (e.lvl == 0 or e.lvl >= pl - low)
				if ok and e.races ~= 0 and rb and not hasBit(e.races, rb) then ok = false end
				if ok and e.classes ~= 0 and cb and not hasBit(e.classes, cb) then ok = false end
				if ok then
					local title = P.QuestTitle(e.id)
					if title and not inLog(title) and not inLogId(P, e.id) then
						local key = floor(e.x / M.GCELL) * 1000 + floor(e.y / M.GCELL)
						local pin = cells[key]
						if not pin then
							local def = P.Quest(e.id)
							local ref = def and def.start and def.start[e.ref]
							pin = { k = "S", x = e.x, y = e.y, nm = ref and P.QName(ref.kind, ref.id) or nil, ek = ref and ref.kind or nil, lines = {}, more = 0, q = {}, grey = grey }
							cells[key] = pin
							tinsert(pins, pin)
						end
						if not grey then pin.grey = false end
						if grey then zs.up = zs.up + 1 else zs.ok = zs.ok + 1 end
						tinsert(pin.q, { id = e.id, lvl = e.lvl, title = title, min = e.min, grey = grey })
					end
				end
			end
			M.zinfo = zs
			if pins[1] then
				for i = 1, getn(pins) do
					local pin = pins[i]
					tsort(pin.q, function(a, b)
						if a.lvl ~= b.lvl then return a.lvl < b.lvl end
						return a.title < b.title
					end)
					for k = 1, getn(pin.q) do
						local qe = pin.q[k]
						if k <= M.GTIPMAX then
							tinsert(pin.lines, (qe.lvl > 0 and ("[" .. qe.lvl .. "] ") or "") .. qe.title .. (qe.grey and (" " .. L("msg.questtrack.needlvl", qe.min)) or ""))
						elseif k == M.GTIPMAX + 1 then
							tinsert(pin.lines, L("msg.questtrack.more", getn(pin.q) - M.GTIPMAX))
						end
					end
					pin.more = nil
				end
				local g = gz.zones[1]
				g.pins, g.n = pins, getn(pins)
				gz.n = g.n
				out = out or {}
				tinsert(out, gz)
			end
		end
	end
	return out
end

-- Ligne d'information au bas de la carte du monde : niveaux des quetes de la zone affichee, a prendre pour toi, plus haut niveau
function M.ZoneLabel()
	local wm = glob("WorldMapFrame")
	if not wm then return end
	local f = M.zlabel
	if not f then
		local btn = glob("WorldMapButton") or wm
		f = T.Text(btn, 12, T.c.text, "LEFT", true)
		f:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 10, 8)
		M.zlabel = f
	end
	local z = M.zinfo
	if not z or not M.on or not C.Get("questtrack.givers") or z.hi == 0 then
		f:SetText("")
		return
	end
	f:SetText(L("msg.questtrack.zinfo", z.lo, z.hi, z.ok, z.up))
end

-- Tranches de niveau des zones et donjons (vue d'un continent), ecrites dans la mer de la carte du monde
M.ZL = {
	{ "Ashenvale", "Orneval", 18, 30, 1 }, { "Azshara", "Azshara", 45, 55, 1 }, { "The Barrens", "Les Tarides", 10, 25, 1 },
	{ "Darkshore", "Sombrevallon", 10, 20, 1 }, { "Desolace", "Desolace", 30, 40, 1 }, { "Durotar", "Durotar", 1, 10, 1 },
	{ "Dustwallow Marsh", "Marecage d'Aprefange", 35, 45, 1 }, { "Felwood", "Gangrebois", 48, 55, 1 }, { "Feralas", "Feralas", 40, 50, 1 },
	{ "Moonglade", "Reflet-de-Lune", 55, 60, 1 }, { "Mulgore", "Mulgore", 1, 10, 1 }, { "Silithus", "Silithus", 55, 60, 1 },
	{ "Stonetalon Mountains", "Les Serres-Rocheuses", 15, 27, 1 }, { "Tanaris", "Tanaris", 40, 50, 1 }, { "Teldrassil", "Teldrassil", 1, 10, 1 },
	{ "Thousand Needles", "Mille pointes", 25, 35, 1 }, { "Un'Goro Crater", "Cratere d'Un'Goro", 48, 55, 1 }, { "Winterspring", "Berceau-de-l'Hiver", 53, 60, 1 },
	{ "Alterac Mountains", "Montagnes d'Alterac", 30, 40, 2 }, { "Arathi Highlands", "Hautes-terres d'Arathi", 30, 40, 2 }, { "Badlands", "Terres ingrates", 35, 45, 2 },
	{ "Blasted Lands", "Terres foudroyees", 45, 55, 2 }, { "Burning Steppes", "Steppes ardentes", 50, 58, 2 }, { "Deadwind Pass", "Defile de Deuillevent", 55, 60, 2 },
	{ "Dun Morogh", "Dun Morogh", 1, 10, 2 }, { "Duskwood", "Bois de la Penombre", 18, 30, 2 }, { "Eastern Plaguelands", "Maleterres de l'est", 53, 60, 2 },
	{ "Elwynn Forest", "Foret d'Elwynn", 1, 10, 2 }, { "Hillsbrad Foothills", "Contreforts d'Hillsbrad", 20, 30, 2 }, { "Loch Modan", "Loch Modan", 10, 20, 2 },
	{ "Redridge Mountains", "Les Carmines", 15, 25, 2 }, { "Searing Gorge", "Gorge des Vents brulants", 43, 50, 2 }, { "Silverpine Forest", "Foret des Pins argentes", 10, 20, 2 },
	{ "Stranglethorn Vale", "Vallee de Strangleronce", 30, 45, 2 }, { "Swamp of Sorrows", "Marais des Chagrins", 35, 45, 2 }, { "The Hinterlands", "Les Hinterlands", 40, 50, 2 },
	{ "Tirisfal Glades", "Clairieres de Tirisfal", 1, 10, 2 }, { "Western Plaguelands", "Maleterres de l'ouest", 51, 58, 2 }, { "Westfall", "Marche de l'Ouest", 10, 20, 2 },
	{ "Wetlands", "Les Paluns", 20, 30, 2 },
}
M.DL = {
	{ "Ragefire Chasm", "Gouffre de Ragefeu", 13, 18, 1 }, { "Wailing Caverns", "Cavernes des lamentations", 15, 25, 1 }, { "Blackfathom Deeps", "Profondeurs de Brassenoire", 24, 32, 1 },
	{ "Razorfen Kraul", "Kraal de Tranchebauge", 29, 38, 1 }, { "Razorfen Downs", "Souilles de Tranchebauge", 37, 46, 1 }, { "Zul'Farrak", "Zul'Farrak", 44, 54, 1 },
	{ "Maraudon", "Maraudon", 46, 55, 1 }, { "Dire Maul", "Hache-tripes", 55, 60, 1 }, { "Onyxia's Lair", "Repaire d'Onyxia", 60, 60, 1 },
	{ "Ahn'Qiraj", "Ahn'Qiraj", 60, 60, 1 },
	{ "The Deadmines", "Les Mortemines", 18, 23, 2 }, { "Shadowfang Keep", "Donjon d'Ombrecroc", 22, 30, 2 }, { "The Stockade", "La Prison", 24, 32, 2 },
	{ "Gnomeregan", "Gnomeregan", 29, 38, 2 }, { "Scarlet Monastery", "Monastere ecarlate", 34, 45, 2 }, { "Uldaman", "Uldaman", 41, 51, 2 },
	{ "Sunken Temple", "Temple d'Atal'Hakkar", 50, 60, 2 }, { "Blackrock Depths", "Profondeurs de Blackrock", 52, 60, 2 }, { "Blackrock Spire", "Pic Blackrock", 55, 60, 2 },
	{ "Stratholme", "Stratholme", 58, 60, 2 }, { "Scholomance", "Scholomance", 58, 60, 2 }, { "Molten Core", "Coeur du Magma", 60, 60, 2 },
	{ "Blackwing Lair", "Repaire de l'Aile noire", 60, 60, 2 }, { "Zul'Gurub", "Zul'Gurub", 60, 60, 2 }, { "Naxxramas", "Naxxramas", 60, 60, 2 },
}

-- Nom de zone sans accents ni majuscules (client francais : le jeu ecrit "Foret d'Elwynn" avec accents)
local FOLD = {
	{ "\195[\160-\165\128-\133]", "a" }, { "\195\167", "c" }, { "\195[\168-\171\136-\139]", "e" },
	{ "\195[\172-\175\140-\143]", "i" }, { "\195[\178-\182\146-\150]", "o" }, { "\195[\185-\188\153-\156]", "u" },
	{ "\226\128[\152\153]", "'" },
}
local function foldName(n)
	n = slower(n or "")
	for i = 1, getn(FOLD) do n = string.gsub(n, FOLD[i][1], FOLD[i][2]) end
	return n
end
M.FoldName = foldName

-- Couleur relative a ton niveau : gris (trop bas), vert, jaune (a ta hauteur), rouge (trop haut)
local function lvColor(lo, hi, pl)
	if hi < pl - 8 then return T.c.dim end
	if lo > pl + 4 then return T.c.warn end
	if lo <= pl and hi >= pl then return T.c.good end
	return T.c.text
end

local function legendCol(f, side)
	local fs = T.Text(f, 12, T.c.text, side, true)
	fs:SetWidth(210)
	fs:SetJustifyH(side)
	return fs
end

function M.LegendEvent()
	if M.Legend() then M.LegendPaint() end
end

function M.Legend()
	local btn = glob("WorldMapButton")
	if not btn then return end
	local f = M.leg
	if not f then
		f = CreateFrame("Frame", nil, btn)
		f:SetAllPoints(btn)
		f:SetFrameLevel(btn:GetFrameLevel() + 2)
		f.zs, f.ds = {}, {}
		for i = 1, 24 do
			local a = legendCol(f, "LEFT")
			a:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(72 + (i - 1) * 14))
			f.zs[i] = a
			local b = legendCol(f, "RIGHT")
			b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -(160 + (i - 1) * 14))
			f.ds[i] = b
		end
		f.bShow = T.Button(f, "", 96, 18, function()
			C.Set("questtrack.legend", not C.Get("questtrack.legend"))
			M.LegendPaint()
		end)
		f.bShow:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
		f.bMine = T.Button(f, "", 110, 18, function()
			C.Set("questtrack.legendmine", not C.Get("questtrack.legendmine"))
			M.LegendPaint()
		end)
		f.bMine:SetPoint("LEFT", f.bShow, "RIGHT", 6, 0)
		f.t = 0
		f:SetScript("OnUpdate", function()
			this.t = this.t + (arg1 or 0)
			if this.t < 0.5 then return end
			this.t = 0
			M.LegendPaint()
		end)
		M.leg = f
	end
	return f
end

function M.LegendPaint()
	local f = M.leg
	if not f then return end
	local c, z = 0, 0
	local gc, gz = glob("GetCurrentMapContinent"), glob("GetCurrentMapZone")
	if gc and gz then c, z = gc(), gz() end
	local cont = M.on and z == 0 and (c == 1 or c == 2)
	-- le cadre reste affiche (sinon plus d'OnUpdate) ; seuls les boutons se cachent
	if not cont then
		f:SetAlpha(0)
		f.bShow:Hide()
		f.bMine:Hide()
		return
	end
	f:SetAlpha(1)
	local on = C.Get("questtrack.legend") and true or false
	local mine = C.Get("questtrack.legendmine") and true or false
	f.bShow:Show()
	T.SetButtonText(f.bShow, L("msg.questtrack.leg.show"))
	T.SetSelected(f.bShow, on)
	if on then
		f.bMine:Show()
		T.SetButtonText(f.bMine, L("msg.questtrack.leg.mine"))
		T.SetSelected(f.bMine, mine)
	else
		f.bMine:Hide()
		for i = 1, 24 do f.zs[i]:SetText("") f.ds[i]:SetText("") end
		return
	end
	local pl = UnitLevel("player") or 1
	local fr = (SUI.locale == "fr") or (SUI.locale == nil and GetLocale and GetLocale() == "frFR")
	local n, m = 0, 0
	local zones = glob("GetMapZones") and { glob("GetMapZones")(c) } or {}
	local have = {}
	for i = 1, getn(zones) do
		-- le client francais de Turtle ajoute parfois le nom anglais : "Les Paluns (Wetlands)"
		local full = foldName(zones[i])
		have[full] = true
		local _, _, base, alt = string.find(full, "^(.-)%s*%((.-)%)%s*$")
		if base then
			have[base] = true
			have[alt] = true
		end
	end
	for i = 1, getn(M.ZL) do
		local e = M.ZL[i]
		if e[5] == c and (have[foldName(e[1])] or have[foldName(e[2])]) and n < 24 and (not mine or (e[3] <= pl + 2 and e[4] >= pl - 2)) then
			n = n + 1
			local col = lvColor(e[3], e[4], pl)
			local fsx = f.zs[n]
			fsx:SetText((fr and e[2] or e[1]) .. "  " .. e[3] .. "-" .. e[4])
			fsx:SetTextColor(col[1], col[2], col[3], 1)
		end
	end
	for i = n + 1, 24 do f.zs[i]:SetText("") end
	for i = 1, getn(M.DL) do
		local e = M.DL[i]
		if e[5] == c and m < 24 and (not mine or (e[3] <= pl + 2 and e[4] >= pl - 2)) then
			m = m + 1
			local col = lvColor(e[3], e[4], pl)
			local fsx = f.ds[m]
			local lv = e[3] == e[4] and tostring(e[3]) or (e[3] .. "-" .. e[4])
			fsx:SetText((fr and e[2] or e[1]) .. "  " .. lv)
			fsx:SetTextColor(col[1], col[2], col[3], 1)
		end
	end
	for i = m + 1, 24 do f.ds[i]:SetText("") end
end

-- Objectif de tes quetes qui vise ce monstre (nom de l'unite survolee) : { title, text } ou nil. Lit seulement le journal deja charge (M.list) :
-- un objectif "Vermine kobold tue : 2/10" vise "Vermine kobold" ; les objectifs deja remplis sont ignores.
M.MARK_TEX = "Interface\\GossipFrame\\AvailableQuestIcon"
M.uoCache, M.uoVer = {}, -1
function M.UnitObjective(name)
	if not M.on or type(name) ~= "string" or name == "" then return nil end
	if M.uoVer ~= M.ver then M.uoCache, M.uoVer = {}, M.ver end
	local c = M.uoCache[name]
	if c ~= nil then return c or nil end
	local r = M.UnitObjectiveScan(name)
	M.uoCache[name] = r or false
	return r
end

-- Repere de quete voulu (plaques et cadre de cible) : module actif et option
function M.MarkWanted()
	return M.on and C.Get("questtrack.mark") and true or false
end

function M.UnitObjectiveScan(name)
	local low = foldName(name)
	for i = 1, getn(M.list) do
		local e = M.list[i]
		if not e.complete then
			for j = 1, getn(e.objs) do
				local o = e.objs[j]
				if not o.done then
					local head = string.gsub(o.text, "%s*:%s*%d+%s*/%s*%d+%s*$", "")
					head = foldName(head)
					if head ~= "" and (string.find(head, "^" .. string.gsub(low, "(%p)", "%%%1") .. "%s") or head == low) then
						return { title = e.title, text = o.text }
					end
				end
			end
		end
	end
	return nil
end

-- Enregistrement de carte d'une quete du journal (objectifs, ou rendu si terminee) ; nil si inconnue / sans epingle. Mis en cache.
function M.EntryRec(Cx, e)
	local id = M.Resolve(e)
	if not id then return nil end
	local kind = e.complete and "E" or "O"
	local key = id .. ":" .. kind
	local rec = M.recs[key]
	if rec == nil then
		local full = Cx.PinBuild(id)
		rec = full and filtered(full, kind) or false
		M.recs[key] = rec
	end
	return rec or nil
end

-- Rendu d'une quete NON terminee : les memes epingles "?" que celles d'une quete finie, mais grisees (comme le "?" gris du jeu au-dessus du PNJ)
function M.GreyEndRec(Cx, e)
	if e.complete then return nil end
	local id = M.Resolve(e)
	if not id then return nil end
	local key = id .. ":G"
	local rec = M.recs[key]
	if rec == nil then
		local full = Cx.PinBuild(id)
		rec = full and filtered(full, "E") or false
		if rec then
			rec.greyEnd = true
			for i = 1, getn(rec.zones) do
				local g = rec.zones[i]
				for k = 1, getn(g.pins) do
					local p = g.pins[k]
					g.pins[k] = { k = p.k, x = p.x, y = p.y, nm = p.nm, ek = p.ek, grey = "end" }
				end
			end
		end
		M.recs[key] = rec
	end
	return rec or nil
end

-- Fournisseur appele par le Codex (carte ouverte seulement) : une liste d'enregistrements resolus pour les quetes du journal
function M.Recs(c, z, ctx)
	local Cx = codex()
	if not Cx or not M.on then return {} end
	local mini = ctx == "mini"
	local wantObj = (ctx == "arrow") or C.Get(mini and "questtrack.mini" or "questtrack.pins") and true or false
	local wantGiv = (ctx ~= "arrow") and C.Get(mini and "questtrack.minigivers" or "questtrack.givers") and true or false
	if not wantObj and not wantGiv then return {} end
	local out = {}
	local view = wantObj and M.View() or {}
	for i = 1, getn(view) do
		local rec = M.EntryRec(Cx, view[i])
		if rec then tinsert(out, rec) end
		if ctx ~= "arrow" then
			local gr = M.GreyEndRec(Cx, view[i])
			if gr then tinsert(out, gr) end
		end
	end
	if wantGiv then
		if M.gready then
			if not c then c, z = Cx.MapCur() end
			local g = M.GiverRec(Cx, c, z)
			for i = 1, g and getn(g) or 0 do tinsert(out, g[i]) end
			if ctx == nil then M.ZoneLabel() end
		else
			M.GiverStart()
		end
	end
	return out
end

-- ---------------------------------------------------------------- minicarte
-- Les memes epingles que la carte du monde (objectifs et rendus de tes quetes, donneurs), posees sur la minicarte autour du joueur.
-- Position : (epingle - joueur) en % de la carte de la zone x taille de la zone en yards (table ci-dessous), puis yards -> pixels d'apres le zoom de la
-- minicarte (rayon en yards selon le zoom, dehors / dedans). Les tailles de zones et les rayons viennent de pfQuest (MIT, db\minimap.lua et map.lua),
-- jamais lus a l'execution : la table est recopiee ici. Une epingle de quete suivie hors de portee reste au bord (repere de direction, plus pale).
-- Une minuterie (M.MINI_EVERY s) n'existe que tant que l'option est active, le Codex est actif ET une epingle peut etre posee.
M.MINI_EVERY = 0.25          -- tour lent (choix des epingles) ; la position est posee a chaque image par M.MiniMove
M.MINI_MAX = 40
M.MINI_SIZE = 15
M.MINI_REFRESH = 3           -- secondes entre deux recompositions de la liste d'epingles (la position, elle, est calculee a chaque tour)
M.mpins = {}

-- Zones (numero de zone des donnees = numero de zone pfQuest) : { largeur, hauteur } en yards
M.YARDS = {
	[0]={35200,23467}, [1]={4925,3283}, [3]={2488,1658}, [4]={3350,2233}, [8]={2294,1529}, [10]={2700,1800}, [11]={4135,2756}, [12]={3471,2315},
	[14]={5288,3525}, [15]={5250,3500}, [16]={5071,3381}, [17]={10133,6756}, [25]={712,469}, [28]={4300,2867}, [33]={6381,4254}, [36]={2800,1867},
	[38]={2758,1840}, [40]={3500,2333}, [41]={2500,1667}, [44]={2171,1448}, [45]={3600,2400}, [46]={2929,1952}, [47]={3850,2567}, [51]={2231,1488},
	[85]={4519,3013}, [130]={4200,2800}, [139]={3871,2581}, [141]={5092,3394}, [148]={6550,4367}, [209]={381,254}, [215]={5138,3425}, [267]={3200,2133},
	[331]={5767,3844}, [357]={6950,4633}, [361]={5750,3833}, [400]={4400,2933}, [405]={4496,2998}, [406]={4883,3256}, [408]={3092,2047},
	[409]={2901,1916}, [440]={6900,4600}, [490]={3700,2467}, [491]={736,491}, [493]={2308,1540}, [616]={3206,2142}, [618]={7100,4733}, [717]={378,252},
	[718]={1170,785}, [719]={1222,806}, [721]={571,379}, [722]={709,473}, [796]={204,135}, [876]={828,541}, [1176]={1383,923}, [1337]={894,596},
	[1377]={3483,2323}, [1477]={695,463}, [1497]={959,640}, [1519]={1738,1158}, [1537]={791,528}, [1581]={450,300}, [1583]={887,591}, [1584]={1407,938},
	[1637]={1403,935}, [1638]={1044,696}, [1657]={1058,706}, [1941]={1348,888}, [1977]={2121,1415}, [2017]={1185,790}, [2040]={1468,976},
	[2041]={1513,1003}, [2057]={320,213}, [2100]={2112,1411}, [2159]={483,322}, [2257]={312,208}, [2366]={1086,727}, [2437]={739,493}, [2557]={1275,850},
	[2597]={4238,2825}, [2677]={499,333}, [2717]={1265,843}, [3277]={1146,765}, [3358]={1756,1171}, [3428]={978,652}, [3429]={2513,1675},
	[3456]={1992,1318}, [3457]={823,549}, [3478]={4139,2946}, [4012]={3159,2108}, [5023]={989,1393}, [5024]={1608,1075}, [5053]={1008,672},
	[5077]={2643,1751}, [5086]={547,392}, [5087]={355,235}, [5097]={1273,854}, [5103]={752,510}, [5121]={3227,2187}, [5130]={1432,977}, [5135]={320,213},
	[5136]={620,413}, [5138]={657,435}, [5144]={309,208}, [5147]={2778,1852}, [5148]={652,440}, [5153]={613,408}, [5163]={703,469}, [5179]={3666,2442},
	[5204]={1272,845}, [5208]={1250,837}, [5225]={3082,2061}, [5536]={2472,1665}, [5557]={2800,1868},
}

-- Diametre visible de la minicarte en yards, selon le zoom 0..5 : [0] dedans, [1] dehors
M.MINIZ = {
	[0] = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
	[1] = { [0] = 466.667, [1] = 400, [2] = 333.333, [3] = 266.667, [4] = 200, [5] = 133.333 },
}

-- 0 si la minicarte est au zoom "dedans" (reglage du client), 1 dehors
function M.Indoor(zoom)
	local gc = glob("GetCVar")
	if not gc then return 1 end
	local inside, outside = tonumber(gc("minimapInsideZoom")), tonumber(gc("minimapZoom"))
	if inside and outside and inside ~= outside and zoom == inside then return 0 end
	return 1
end

function M.MiniFrame(i)
	local p = M.mpins[i]
	if p then return p end
	local mm = glob("Minimap")
	if i > M.MINI_MAX or not mm then return nil end
	p = CreateFrame("Button", nil, mm)
	p:SetWidth(M.MINI_SIZE)
	p:SetHeight(M.MINI_SIZE)
	p:SetFrameLevel(mm:GetFrameLevel() + 6)
	p:EnableMouse(true)
	p.tex = p:CreateTexture(nil, "ARTWORK")
	p.tex:SetAllPoints(p)
	p.hl = p:CreateTexture(nil, "OVERLAY")
	p.hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	p.hl:SetBlendMode("ADD")
	p.hl:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.hl:SetWidth(M.MINI_SIZE * 1.6)
	p.hl:SetHeight(M.MINI_SIZE * 1.6)
	p.hl:Hide()
	p.useGame = true
	p:SetScript("OnEnter", function()
		local Cx = SUI.Codex
		if Cx and Cx.PinEnter then Cx.PinEnter(this) end
	end)
	p:SetScript("OnLeave", function()
		local Cx = SUI.Codex
		if Cx and Cx.PinLeave then Cx.PinLeave(this) end
	end)
	p.mark = T.Text(p, 9, T.c.text, "RIGHT", true)
	p.mark:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 3, -2)
	p.kind = "S"
	p:Hide()
	M.mpins[i] = p
	return p
end

M.mact, M.mn = {}, 0

function M.MiniHideAll()
	M.lpx, M.llist, M.mact, M.mn = nil, nil, {}, 0
	for i = 1, getn(M.mpins) do M.mpins[i]:Hide() end
	if M.mover then M.mover:Hide() end
end

-- Liste plate des epingles a poser pres du joueur : { d, zid, rec, tracked }, recomposee toutes les M.MINI_REFRESH secondes ou si la zone change
function M.MiniList(Cx, c, z, px, py)
	if M.miniList and M.miniC == c and M.miniZ == z and GetTime() < (M.miniNext or 0) then return M.miniList end
	M.miniC, M.miniZ = c, z
	local rz = glob("GetRealZoneText")
	local ul = glob("UnitLevel")
	local key = tostring(rz and rz() or "") .. "|" .. c .. "," .. z .. "|" .. tostring(ul and ul("player") or 0) .. "|" .. M.ver .. "|" .. (C.Get("questtrack.hide") or "")
	local now = GetTime()
	if M.miniKey == key and M.miniList and now < (M.miniNext or 0) then return M.miniList end
	M.miniKey, M.miniNext = key, now + M.MINI_REFRESH
	local out = {}
	local srcs = M.on and M.Recs(c, z, "mini") or {}
	for s = 1, getn(srcs) do
		local rec = srcs[s]
		local g = Cx.PinHere(rec, c, z)
		for k = 1, g and getn(g.pins) or 0 do
			if getn(out) >= M.MINI_MAX then break end
			tinsert(out, { d = g.pins[k], zid = g.zid, rec = rec, tracked = (rec.id or 0) >= 0 })
		end
	end
	-- lieux utiles : les plus proches du joueur d'abord (la minicarte n'en pose que M.MINI_MAX au total)
	local Pl = SUI.Places
	if Pl and Pl.MiniWanted and Pl.MiniWanted() then
		local ps = Pl.Recs(c, z, "mini")
		local near = {}
		for s = 1, getn(ps) do
			local rec = ps[s]
			local g = Cx.PinHere(rec, c, z)
			local sz = g and M.YARDS[g.zid]
			for k = 1, g and getn(g.pins) or 0 do
				local d = g.pins[k]
				local dist = 0
				if sz and px and py then
					local dx, dy = (d.x - px) / 100 * sz[1], (d.y - py) / 100 * sz[2]
					dist = dx * dx + dy * dy
				end
				tinsert(near, { d = d, zid = g.zid, rec = rec, tracked = false, dist = dist })
			end
		end
		tsort(near, function(a, b) return a.dist < b.dist end)
		for k = 1, getn(near) do
			if getn(out) >= M.MINI_MAX then break end
			tinsert(out, near[k])
		end
	end
	M.miniList = out
	return out
end

-- Pose par image (OnUpdate de la minicarte) : seulement la position, calculee d'apres celle du joueur ; rien ne bouge quand le joueur est immobile.
function M.MiniMove()
	local n = M.mn
	if n == 0 then return end
	local mm, gp = glob("Minimap"), glob("GetPlayerMapPosition")
	if not mm or not gp then return end
	-- halo qui pulse autour des "?" (rendre une quete)
	local pa = 0.35 + 0.35 * math.sin(GetTime() * 4)
	for i = 1, n do
		local q = M.mact[i].p
		if q.kind == "E" and not (q.data and q.data.grey) then
			q.hl:SetAlpha(pa)
			q.hl:Show()
		end
	end
	local px, py = gp("player")
	if not px or (px == 0 and py == 0) then return end
	local zoom = mm:GetZoom() or 0
	if px == M.lpx and py == M.lpy and zoom == M.lzoom then return end
	M.lpx, M.lpy, M.lzoom = px, py, zoom
	local diam = M.MINIZ[M.mindoor or 1][zoom] or 400
	local size = mm:GetWidth()
	local ppy = size / diam
	local half = size / 2 - 5
	local square, edge = M.msquare, M.medge
	local act = M.mact
	for i = 1, n do
		local e = act[i]
		local p = e.p
		local sx = (e.x - px * e.w) * ppy
		local sy = -(e.y - py * e.h) * ppy
		local far
		if square then
			far = (sx > half) or (sx < -half) or (sy > half) or (sy < -half)
		else
			far = (sx * sx + sy * sy) > half * half
		end
		local show = true
		if far then
			if e.tracked and (edge or (p.kind == "E" and not (p.data and p.data.grey))) then
				local k
				if square then
					local ax, ay = sx < 0 and -sx or sx, sy < 0 and -sy or sy
					k = half / (ax > ay and ax or ay)
				else
					k = half / math.sqrt(sx * sx + sy * sy)
				end
				sx, sy = sx * k, sy * k
				p:SetAlpha(0.55)
			else
				show = false
			end
		else
			p:SetAlpha(1)
		end
		if show then
			p:ClearAllPoints()
			p:SetPoint("CENTER", mm, "CENTER", sx, sy)
			p:Show()
		else
			p:Hide()
		end
	end
end

function M.EnsureMover()
	if M.mover then return M.mover end
	local mm = glob("Minimap")
	if not mm then return nil end
	local f = CreateFrame("Frame", nil, mm)
	f:SetScript("OnUpdate", function() M.MiniMove() end)
	M.mover = f
	return f
end

-- Tour lent (M.MINI_EVERY) : choisit les epingles et leur icone ; la position, elle, est posee a chaque image par M.MiniMove
function M.MiniTick()
	local Cx = codex()
	local mm = glob("Minimap")
	local gp = glob("GetPlayerMapPosition")
	local wm = glob("WorldMapFrame")
	if not Cx or not mm or not gp or not mm:IsShown() or (wm and wm:IsShown()) then
		M.MiniHideAll()
		return
	end
	local now = GetTime()
	if now >= (M.mapNext or 0) then
		M.mapNext = now + 1
		M.SyncMap()
	end
	local px, py = gp("player")
	local c, z = Cx.MapCur()
	if not px or not c or not z or z <= 0 or (px == 0 and py == 0) then
		M.MiniHideAll()
		return
	end
	local list = M.MiniList(Cx, c, z, px * 100, py * 100)
	M.mindoor = M.Indoor(mm:GetZoom() or 0)
	M.msquare = C.Get("minimap.shape") == "square"
	M.medge = C.Get("questtrack.miniedge") and true or false
	if list ~= M.llist then
		M.llist = list
		local act, n = {}, 0
		for i = 1, getn(list) do
			local e = list[i]
			local sz = e.zid and M.YARDS[e.zid]
			if sz then
				local p = M.MiniFrame(n + 1)
				if not p then break end
				local vk = Cx.PinVisual(e.d)
				p.kind = vk
				p.rec, p.data = e.rec, e.d
				Cx.PaintIcon(p, e.d, vk)
				-- rendre une quete : "?" plus grand, au-dessus des autres epingles et qui pulse (voir M.MiniMove)
				local sz2 = (vk == "E" and not e.d.grey) and (M.MINI_SIZE * 1.5) or M.MINI_SIZE
				p:SetWidth(sz2)
				p:SetHeight(sz2)
				p.hl:SetWidth(sz2 * 1.7)
				p.hl:SetHeight(sz2 * 1.7)
				p:SetFrameLevel(mm:GetFrameLevel() + ((vk == "E") and ((e.d.grey and 7) or 9) or 6))
				if vk == "E" and not e.d.grey then
					p.hl:SetVertexColor(1, 0.85, 0.2)
				else
					p.hl:Hide()
				end
				local ent = Cx.PinEntries(e.rec, e.d)
				local mk = Cx.PinMark(vk, ent and getn(ent) or 0)
				if p.markText ~= mk then
					p.markText = mk
					p.mark:SetText(mk)
				end
				n = n + 1
				act[n] = { p = p, x = e.d.x / 100 * sz[1], y = e.d.y / 100 * sz[2], w = sz[1], h = sz[2], tracked = e.tracked }
			end
		end
		M.mact, M.mn = act, n
		for i = n + 1, getn(M.mpins) do M.mpins[i]:Hide() end
		M.lpx = nil
	end
	local mv = M.EnsureMover()
	if mv and not mv:IsShown() then mv:Show() end
end

-- Minuterie de la minicarte : seulement si l'option est active, le Codex aussi, et le module actif
function M.MiniSync()
	local Pl = SUI.Places
	local want = codex() ~= nil and ((M.on and (C.Get("questtrack.mini") or C.Get("questtrack.minigivers"))) or (Pl and Pl.MiniWanted and Pl.MiniWanted())) and true or false
	if want and not M.miniTask then
		M.miniTask = SUI.Every(M.MINI_EVERY, M.MiniTick, "questtrack.mini")
	elseif not want and M.miniTask then
		SUI.Cancel(M.miniTask)
		M.miniTask = nil
		M.miniKey, M.miniList = nil, nil
		M.MiniHideAll()
	end
end

-- Branche / debranche le fournisseur selon l'etat du module, du Codex et de l'option (a rappeler a chaque changement)
function M.Sync()
	local Cx = SUI.Codex
	if not Cx or not Cx.PinTrack then return end
	local want = M.on and Cx.on and (C.Get("questtrack.pins") or C.Get("questtrack.givers")) and true or false
	if want and Cx.trackFn ~= M.Recs then
		Cx.PinTrack(M.Recs)
	elseif not want and Cx.trackFn == M.Recs then
		Cx.PinTrack(nil)
	end
	M.ApplySize(Cx)
	M.MiniSync()
end

-- Taille des epingles de la carte (option) : applique aux epingles deja creees
function M.ApplySize(Cx)
	local s = C.Get("questtrack.pinsize")
	if type(s) ~= "number" or s == Cx.PIN_SIZE then return end
	Cx.PIN_SIZE = s
	for i = 1, getn(Cx.pins) do
		Cx.pins[i]:SetWidth(s)
		Cx.pins[i]:SetHeight(s)
		if Cx.pins[i].hl then
			Cx.pins[i].hl:SetWidth(s * 1.6)
			Cx.pins[i].hl:SetHeight(s * 1.6)
		end
	end
end

-- Titre affiche : celui des donnees du Codex (francais quand l'interface l'est) si la quete est reconnue, sinon celui du client
function M.Title(e)
	-- le titre du client (serveur Turtle francais : peut differer des donnees du Codex)
	return e.title
end

-- Reconnait toutes les quetes de la liste (charge les donnees du Codex une fois, quelques secondes apres la lecture) puis repeint
function M.ResolveAll()
	M.resTask = nil
	if not M.on or not codex() then return end
	for i = 1, getn(M.list) do M.Resolve(M.list[i]) end
	M.Paint()
end

-- Glisser pour deplacer la liste (option) : sans quitter le jeu ni ouvrir le mode deplacement
function M.DragOn()
	return C.Get("questtrack.drag") and true or false
end

-- ---------------------------------------------------------------- cadre
function M.Row(i)
	local r = M.rows[i]
	if r then return r end
	local f = M.frame
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(14)
	b:EnableMouse(true)
	b.txt = T.Text(b, 11, T.c.warn, "LEFT")
	b.txt:SetPoint("LEFT", b, "LEFT", 0, 0)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function() M.OnTitle(this, arg1) end)
	if SUI.Mover and SUI.Mover.QuickDrag then
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", function()
			if f.quickDragStart then f.quickDragStart() end
		end)
		b:SetScript("OnDragStop", function()
			if f.quickDragStop then f.quickDragStop() end
		end)
	end
	b:SetScript("OnEnter", function() M.OnTip(this) end)
	b:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	r = { btn = b, objs = {} }
	-- mini bouton : la fleche de direction suit CETTE quete (re-clic : retour a la plus proche)
	local ab = CreateFrame("Button", nil, f)
	ab:SetWidth(13)
	ab:SetHeight(13)
	ab:SetPoint("RIGHT", b, "RIGHT", 0, 0)
	ab:SetFrameLevel(b:GetFrameLevel() + 2)
	ab.tex = ab:CreateTexture(nil, "ARTWORK")
	ab.tex:SetAllPoints(ab)
	ab.tex:SetTexture(M.ARROW_TEX)
	ab:SetScript("OnClick", function()
		if this.entry then M.SetArrowTarget(this.entry) end
	end)
	ab:SetScript("OnEnter", function()
		if GameTooltip then
			GameTooltip:SetOwner(this, "ANCHOR_LEFT")
			GameTooltip:SetText(L("msg.questtrack.arrowbtn"))
			GameTooltip:Show()
		end
	end)
	ab:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	r.ab = ab
	for j = 1, M.MAXOBJ do
		local fs = T.Text(f, 10, T.c.text, "LEFT")
		r.objs[j] = fs
	end
	M.rows[i] = r
	return r
end

function M.Build()
	if M.frame then return M.frame end
	local f = CreateFrame("Frame", "ShikiUI_QuestTrack", UIParent)
	f:SetWidth(C.Get("questtrack.width"))
	f:SetHeight(40)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	M.frame = f
	f.head = T.Text(f, 11, T.c.dim, "LEFT")
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD, -M.PAD - 1)
	f.pick = T.Button(f, L("msg.questtrack.pick.btn"), 58, 15, function() M.OpenLog(nil) end)
	f.pick:SetPoint("TOPRIGHT", f, "TOPRIGHT", -M.PAD, -M.PAD + 1)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("questtrack", f, { label = "mod.questtrack.mover", point = "TOPRIGHT", x = -110, y = -200 })
		SUI.Mover.QuickDrag(f, "questtrack", M.DragOn)
	end
	return f
end

local function lineHeight(fs, min)
	local h = fs:GetHeight()
	if type(h) ~= "number" or h < min then return min end
	return h
end

-- Peint la liste : une ligne de titre puis les objectifs de chaque quete ; cadre cache sans quete
function M.Paint()
	local f = M.frame
	if not f then return end
	local total = getn(M.list)
	if total == 0 or not C.Get("questtrack.show") then
		f:Hide()
		return
	end
	local view = M.View(true)
	local n = getn(view)
	local max = C.Get("questtrack.max")
	if n > max then n = max end
	if n > M.MAXQ then n = M.MAXQ end
	local w = C.Get("questtrack.width")
	f:SetWidth(w)
	f.head:SetText(L("msg.questtrack.head", getn(M.View()), total))
	f.head:SetWidth(w - 2 * M.PAD - 62)
	T.SetButtonText(f.pick, L("msg.questtrack.pick.btn"))
	local y = M.PAD + 18
	for i = 1, n do
		local e = view[i]
		local r = M.Row(i)
		local b = r.btn
		b.entry = e
		b:SetWidth(w - 2 * M.PAD)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD, -y)
		local col = e.complete and T.c.good or T.c.warn
		b.txt:SetTextColor(col[1], col[2], col[3], col[4] or 1)
		b.txt:SetWidth(w - 2 * M.PAD - 16)
		r.ab.entry = e
		local on = C.Get("questtrack.arrowq") == M.Key(e)
		r.ab.tex:SetVertexColor(on and 1 or 0.7, on and 0.85 or 0.7, on and 0.2 or 0.7, on and 1 or 0.8)
		r.ab:Show()
		b.txt:SetText((e.level > 0 and ("[" .. e.level .. "] ") or "") .. M.Title(e))
		b:Show()
		y = y + 15
		for j = 1, M.MAXOBJ do
			local fs = r.objs[j]
			local o = e.objs[j]
			if o then
				local c = o.done and T.c.dim or T.c.text
				fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
				fs:SetWidth(w - 2 * M.PAD - 8)
				fs:ClearAllPoints()
				fs:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD + 8, -y)
				fs:SetText(o.text)
				fs:Show()
				y = y + lineHeight(fs, 12)
			else
				fs:Hide()
			end
		end
		y = y + 3
	end
	for i = n + 1, getn(M.rows) do
		M.rows[i].btn:Hide()
		M.rows[i].ab:Hide()
		for j = 1, M.MAXOBJ do M.rows[i].objs[j]:Hide() end
	end
	f:SetHeight(y + M.PAD)
	f:Show()
end

-- Vrai quand toutes les quetes de la liste ont deja un numero (ou un constat d'inconnue)
function M.listResolved(list)
	for i = 1, getn(list) do
		if list[i].id == nil then return false end
	end
	return true
end

-- ---------------------------------------------------------------- lecture et repeinture
function M.Scan()
	M.task = nil
	if not M.on then return end
	local list = M.Read()
	if not list then return end
	local sig = M.Signature(list)
	if sig == M.sig then return end
	M.sig = sig
	M.ver = M.ver + 1
	if SUI.Units and SUI.Units.MarkAll then SUI.Units.MarkAll() end
	-- numeros deja resolus : repris par titre + niveau (la lecture repart de zero a chaque changement)
	local old = M.list
	M.list = list
	for i = 1, getn(list) do
		for k = 1, getn(old) do
			if old[k].title == list[i].title and old[k].level == list[i].level and old[k].id ~= nil then
				list[i].id = old[k].id
				break
			end
		end
	end
	M.Build()
	M.Paint()
	M.LogPaint()
	if codex() and not M.resTask and not M.listResolved(list) then M.resTask = SUI.After(2, M.ResolveAll, "questtrack.res") end
	local Cx = SUI.Codex
	if Cx and Cx.trackFn == M.Recs and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
end

function M.Queue()
	if not M.on or M.task then return end
	M.task = SUI.After(M.DELAY, M.Scan, "questtrack.scan")
end

-- ---------------------------------------------------------------- souris
-- Maj+clic : "[titre]" dans la ligne de saisie du chat ; Ctrl+clic : la quete s'ouvre dans le journal du jeu
function M.ChatLink(e)
	local eb = glob("ChatFrameEditBox")
	if eb and eb.IsVisible and eb:IsVisible() and eb.Insert then eb:Insert("[" .. e.title .. "]") end
end


function M.OnTitle(b, button)
	local e = b.entry
	if not e then return end
	local shift, ctrl = glob("IsShiftKeyDown"), glob("IsControlKeyDown")
	if shift and shift() then
		M.ChatLink(e)
		return
	end
	if ctrl and ctrl() then
		M.OpenLog(e)
		return
	end
	if button == "RightButton" then
		M.SetShown(e, false)
		SUI.Print(L("msg.questtrack.hidden", M.Title(e)))
		return
	end
	M.PinEntry(e)
end

-- Epingle la quete seule sur la carte du monde
function M.PinEntry(e)
	local Cx = SUI.Codex
	if not (Cx and Cx.on) then
		SUI.Print(L("msg.questtrack.nocodex"))
		return
	end
	local id = M.Resolve(e)
	if not id then
		SUI.Print(L("msg.questtrack.unknown", e.title))
		return
	end
	Cx.PinQuest(id)
end

function M.OnTip(b)
	local e = b.entry
	if not e or not GameTooltip then return end
	local d = T.c.dim
	GameTooltip:SetOwner(b, "ANCHOR_LEFT")
	GameTooltip:SetText(e.title)
	GameTooltip:AddLine(L(e.complete and "msg.questtrack.tip.done" or "msg.questtrack.tip.todo"), d[1], d[2], d[3])
	GameTooltip:AddLine(L("msg.questtrack.tip.click"), d[1], d[2], d[3])
	GameTooltip:AddLine(L("msg.questtrack.tip.hide"), d[1], d[2], d[3])
	GameTooltip:AddLine(L("msg.questtrack.tip.log"), d[1], d[2], d[3])
	if C.Get("questtrack.drag") then GameTooltip:AddLine(L("msg.questtrack.tip.drag"), d[1], d[2], d[3]) end
	GameTooltip:Show()
end

-- ---------------------------------------------------------------- fleche de direction
-- Une petite fleche deplacable pointe vers l'objectif de quete le plus proche dans la zone ou tu te trouves (ou vers la quete epinglee, si elle a
-- un point ici) et indique la distance en yards. Angle = relevement de la cible sur la carte (nord en haut) + orientation du joueur
-- (GetPlayerFacing : radians, sens inverse des aiguilles depuis le nord). Zone sans objectif, carte du monde ouverte sur une autre zone, ou
-- instance (position 0, 0) : la fleche se cache. Une image sur deux : seulement l'angle ; la cible est rechoisie chaque seconde.
M.ARROW_TEX = "Interface\\AddOns\\ShikiUI\\Media\\arrow.tga"
M.ARROW_PICK = 1             -- secondes entre deux choix de cible
M.ARROW_EVERY = 0.05         -- secondes entre deux mises a jour de l'angle
M.ARROW_NEAR = 20            -- yards : "arrive"
M.ARROW_SIZE = 44
M.ARROW_ICON_AT = 45         -- yards : sous cette distance la fleche laisse la place a l'icone du type d'objectif
M.ICONS = {
	S = "Interface\\GossipFrame\\AvailableQuestIcon",   -- prendre la quete
	E = "Interface\\GossipFrame\\ActiveQuestIcon",      -- rendre la quete
	u = "Interface\\Icons\\INV_Sword_04",               -- tuer / combattre
	o = "Interface\\Icons\\INV_Misc_Gear_01",           -- utiliser / ramasser un objet du decor
	i = "Interface\\Icons\\INV_Misc_Bag_08",            -- ramasser un objet
	r = "Interface\\Icons\\INV_Misc_Bag_08",
	O = "Interface\\Icons\\INV_Misc_Map_01",            -- autre objectif (explorer, parler ...)
}

-- Icone du type d'objectif d'un point (k = S / E / O, ek = u / o / i / r)
function M.ArrowIcon(k, ek)
	if k == "S" or k == "E" then return M.ICONS[k] end
	return M.ICONS[ek] or M.ICONS.O
end

-- atan2 (math.atan2 en Lua 5.0 du client ; math.atan a deux arguments ailleurs)
function M.Atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	return math.atan(y, x)
end

-- Coordonnees de texture du coin (x, y) (droite, haut ; centre = 0) apres une rotation de a radians dans le sens inverse des aiguilles
local function arrowUV(x, y, c, s)
	return 0.5 + (x * c + y * s), 0.5 - (y * c - x * s)
end

function M.ArrowSetAngle(tex, a)
	local c, s = math.cos(a), math.sin(a)
	local ulx, uly = arrowUV(-0.5, 0.5, c, s)
	local llx, lly = arrowUV(-0.5, -0.5, c, s)
	local urx, ury = arrowUV(0.5, 0.5, c, s)
	local lrx, lry = arrowUV(0.5, -0.5, c, s)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- La carte interne doit montrer la zone ou tu te trouves (sinon ni la position ni la zone courante ne servent) ; carte du monde ouverte : intacte
function M.SyncMap()
	local wm = glob("WorldMapFrame")
	if wm and wm:IsShown() then return end
	local f = glob("SetMapToCurrentZone")
	if f then f() end
end

-- Cible : { x, y (0..1 sur la carte de la zone), w, h (yards), title } ou nil
function M.ArrowPick()
	M.SyncMap()
	local Cx = codex()
	local gp = glob("GetPlayerMapPosition")
	if not Cx or not gp then return nil end
	local px, py = gp("player")
	local c, z = Cx.MapCur()
	if not px or (px == 0 and py == 0) or not c or not z or z <= 0 then return nil end
	if M.atest and GetTime() < M.atest.till then return M.atest end
	-- priorite : quete choisie pour la fleche (si elle a un point ici) > quete epinglee > objectif le plus proche des quetes affichees
	local srcs = nil
	local aq = C.Get("questtrack.arrowq")
	if type(aq) == "string" and aq ~= "" then
		for i = 1, getn(M.list) do
			if M.Key(M.list[i]) == aq then
				local r = M.EntryRec(Cx, M.list[i])
				if r and Cx.PinHere(r, c, z) then srcs = { r } end
				break
			end
		end
	end
	if not srcs then
		srcs = M.Recs(c, z, "arrow")
		local pinned = Cx.pin
		if pinned and type(pinned.zones) == "table" and Cx.PinHere(pinned, c, z) then
			srcs = { pinned }
			-- quete deja dans le journal : la fleche vise ses objectifs / son rendu, jamais le point de depart ("!" trompeur)
			for i = 1, getn(M.list) do
				if M.list[i].id == pinned.id then
					local r = M.EntryRec(Cx, M.list[i])
					if r and Cx.PinHere(r, c, z) then srcs = { r } end
					break
				end
			end
		end
	end
	local best, bd = nil, nil
	for s = 1, getn(srcs) do
		local rec = srcs[s]
		local g = Cx.PinHere(rec, c, z)
		local sz = g and (M.YARDS[g.zid] or { 4000, 2667 })
		for k = 1, g and getn(g.pins) or 0 do
			local d = g.pins[k]
			local dx, dy = (d.x / 100 - px) * sz[1], (d.y / 100 - py) * sz[2]
			local d2 = dx * dx + dy * dy
			if not bd or d2 < bd then
				bd = d2
				best = { x = d.x / 100, y = d.y / 100, w = sz[1], h = sz[2], title = rec.t, k = d.k, ek = d.ek }
			end
		end
	end
	return best
end

-- Image : angle et distance
function M.ArrowUpdate()
	local f = M.arrow
	if not f then return end
	local now = GetTime()
	if now >= (M.apick or 0) then
		M.apick = now + M.ARROW_PICK
		M.atgt = M.ArrowPick()
	end
	local t = M.atgt
	local gp, gf = glob("GetPlayerMapPosition"), glob("GetPlayerFacing")
	local px, py, face
	if t and gp and gf then
		px, py = gp("player")
		face = gf()
	end
	if not t or not px or (px == 0 and py == 0) or type(face) ~= "number" then
		f.tex:Hide()
		f.txt:SetText("")
		f.sub:SetText("")
		return
	end
	local dx, dy = (t.x - px) * t.w, (t.y - py) * t.h
	local dist = math.sqrt(dx * dx + dy * dy)
	local near = dist < M.ARROW_NEAR
	if t.k and dist < M.ARROW_ICON_AT then
		-- tout pres : l'icone du type d'objectif (epee = combattre ...) remplace la fleche
		local ic = M.ArrowIcon(t.k, t.ek)
		if f.mode ~= ic then
			f.mode = ic
			f.tex:SetTexture(ic)
			f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		f.tex:SetVertexColor(1, 1, 1, 1)
	else
		if f.mode then
			f.mode = nil
			f.tex:SetTexture(M.ARROW_TEX)
		end
		M.ArrowSetAngle(f.tex, -(M.Atan2(dx, -dy) + face))
		local col = near and T.c.good or { T.Accent() }
		f.tex:SetVertexColor(col[1], col[2], col[3], 1)
	end
	f.tex:Show()
	f.txt:SetText(near and L("msg.questtrack.arrow.here") or L("msg.questtrack.arrow.dist", floor(dist + 0.5)))
	if f.subFor ~= t.title then
		f.subFor = t.title
		f.sub:SetText(t.title or "")
	end
end

function M.ArrowBuild()
	if M.arrow then return M.arrow end
	local f = CreateFrame("Frame", "ShikiUI_QuestArrow", UIParent)
	f:SetWidth(M.ARROW_SIZE + 60)
	f:SetHeight(M.ARROW_SIZE + 30)
	f:SetFrameStrata("MEDIUM")
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetTexture(M.ARROW_TEX)
	f.tex:SetWidth(M.ARROW_SIZE)
	f.tex:SetHeight(M.ARROW_SIZE)
	f.tex:SetPoint("TOP", f, "TOP", 0, 0)
	f.txt = T.Text(f, 12, T.c.text, "CENTER", true)
	f.txt:SetPoint("TOP", f.tex, "BOTTOM", 0, -2)
	f.sub = T.Text(f, 10, T.c.text, "CENTER", true)
	f.sub:SetPoint("TOP", f.txt, "BOTTOM", 0, -1)
	f.sub:SetWidth(M.ARROW_SIZE + 56)
	f.sub:SetHeight(12)
	f.elapsed = 0
	f:SetScript("OnUpdate", function()
		this.elapsed = this.elapsed + arg1
		if this.elapsed < M.ARROW_EVERY then return end
		this.elapsed = 0
		M.ArrowUpdate()
	end)
	SUI.Mover.Register("questtrack.arrow", f, { label = "mod.questtrack.arrow.mover", point = "TOP", x = 0, y = -150 })
	M.arrow = f
	return f
end

-- Montre / cache la fleche selon l'option, le module et le Codex (sans lui, pas de coordonnees de quetes)
function M.ArrowSync()
	local want = M.on and C.Get("questtrack.arrow") and codex() ~= nil and true or false
	if want then
		local f = M.ArrowBuild()
		f:Show()
	elseif M.arrow then
		M.arrow:Hide()
		M.atgt, M.apick = nil, nil
	end
end

-- ---------------------------------------------------------------- dans le journal de quetes du jeu (aucune fenetre en plus)
-- Tout se passe DANS la fenetre du journal : un petit carre devant chaque quete de la liste (clic = afficher / retirer de la liste de suivi),
-- et, sous le titre de la fenetre, une rangee de boutons pour la quete choisie (liste, epingle, fleche) et pour toute la liste.
-- QuestLog_Update est enveloppee a la main (pas de hooksecurefunc en 1.12) pour suivre la selection et le defilement.
M.LOGROWS = 40               -- lignes de la liste du journal parcourues (QuestLogTitle1 ...)

-- La fleche vise cette quete (ou revient a "la plus proche" si c'etait deja elle)
function M.SetArrowTarget(e)
	local k = M.Key(e)
	if C.Get("questtrack.arrowq") == k then
		C.Set("questtrack.arrowq", "")
		return
	end
	C.Set("questtrack.arrowq", k)
	if not C.Get("questtrack.arrow") then C.Set("questtrack.arrow", true) end
end

-- Quete du journal d'indice `sel` (indice du client), si la liste lue est a jour
function M.EntryAt(sel)
	local gt = glob("GetQuestLogTitle")
	if not gt or type(sel) ~= "number" then return nil end
	for i = 1, getn(M.list) do
		local e = M.list[i]
		if e.i == sel then
			local ok, t = pcall(gt, sel)
			if ok and t == e.title then return e end
			return nil
		end
	end
	return nil
end

-- Quete selectionnee dans le journal du jeu
function M.LogEntry()
	local gs = glob("GetQuestLogSelection")
	if not gs then return nil end
	local ok, sel = pcall(gs)
	if not ok then return nil end
	return M.EntryAt(sel)
end

-- Ouvre le journal du jeu (sur une quete si e est donnee) ; deja ouvert : le ferme quand e est nil
function M.OpenLog(e)
	local f = glob("QuestLogFrame")
	local show, hide = glob("ShowUIPanel"), glob("HideUIPanel")
	if not f or not show then return end
	if e then
		local sel = glob("SelectQuestLogEntry")
		if sel then pcall(sel, e.i) end
	end
	if f:IsVisible() then
		if e then
			local upd = glob("QuestLog_Update")
			if upd then upd() end
		elseif hide then
			hide(f)
		end
	else
		show(f)
	end
end

-- Carre de suivi d'une ligne de la liste du journal (cree a la demande)
local function logMark(row)
	local m = row.suiMark
	if m then return m end
	m = CreateFrame("Button", nil, row)
	m:SetWidth(12)
	m:SetHeight(12)
	m:SetPoint("LEFT", row, "LEFT", 14, 0)
	m.tex = m:CreateTexture(nil, "OVERLAY")
	m.tex:SetTexture(T.tex.white)
	m.tex:SetPoint("TOPLEFT", m, "TOPLEFT", 2, -2)
	m.tex:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -2, 2)
	m:SetScript("OnClick", function()
		if this.e then M.SetShown(this.e, not M.IsShown(this.e)) end
	end)
	m:SetScript("OnEnter", function()
		if not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(L("msg.questtrack.log.marktip"))
		GameTooltip:Show()
	end)
	m:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	row.suiMark = m
	return m
end

-- Barre de boutons sous la barre de titre du journal (parent : QuestLogFrame)
local function stripButton(f, w, fn)
	local b = T.Button(f, "", w, 20, fn)
	b:SetFrameLevel((f:GetFrameLevel() or 0) + 6)
	return b
end

function M.LogBuild()
	if M.logp then return M.logp end
	local qf = glob("QuestLogFrame")
	if not qf then return nil end
	local f = CreateFrame("Frame", "ShikiUI_QuestLogBar", qf)
	f:SetWidth(470)
	f:SetHeight(22)
	f:SetPoint("TOPLEFT", qf, "TOPLEFT", M.LOGX, M.LOGY)
	f.bTrack = stripButton(f, 112, function()
		if f.cur then M.SetShown(f.cur, not M.IsShown(f.cur)) end
	end)
	f.bTrack:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.bPin = stripButton(f, 66, function()
		if f.cur then M.PinEntry(f.cur) end
	end)
	f.bPin:SetPoint("LEFT", f.bTrack, "RIGHT", 4, 0)
	f.bArrow = stripButton(f, 66, function()
		if f.cur then M.SetArrowTarget(f.cur) end
	end)
	f.bArrow:SetPoint("LEFT", f.bPin, "RIGHT", 4, 0)
	f.bAll = stripButton(f, 40, function() M.SetAllShown(true) end)
	f.bAll:SetPoint("LEFT", f.bArrow, "RIGHT", 10, 0)
	f.bNone = stripButton(f, 40, function() M.SetAllShown(false) end)
	f.bNone:SetPoint("LEFT", f.bAll, "RIGHT", 4, 0)
	f:SetScript("OnShow", function() M.LogPaint() end)
	M.logp = f
	return f
end
M.LOGX = 214
M.LOGY = -42

function M.LogPaint()
	local f = M.logp
	if not f then return end
	local e = M.LogEntry()
	f.cur = e
	T.SetButtonText(f.bAll, L("msg.questtrack.log.all"))
	T.SetButtonText(f.bNone, L("msg.questtrack.log.none"))
	T.SetButtonText(f.bPin, L("msg.questtrack.log.pin"))
	if e then
		local on = M.IsShown(e)
		T.SetButtonText(f.bTrack, L(on and "msg.questtrack.log.untrack" or "msg.questtrack.log.track"))
		T.SetButtonText(f.bArrow, L(C.Get("questtrack.arrowq") == M.Key(e) and "msg.questtrack.log.arrowoff" or "msg.questtrack.log.arrow"))
		f.bTrack:Show()
		f.bPin:Show()
		f.bArrow:Show()
	else
		f.bTrack:Hide()
		f.bPin:Hide()
		f.bArrow:Hide()
	end
	-- carres devant les quetes de la liste du journal
	for i = 1, M.LOGROWS do
		local row = glob("QuestLogTitle" .. i)
		if not row then break end
		local id = row.GetID and row:GetID() or nil
		local qe = (row:IsVisible() and id) and M.EntryAt(id) or nil
		if qe then
			local m = logMark(row)
			m.e = qe
			local on = M.IsShown(qe)
			local c = on and T.c.good or T.c.dim
			m.tex:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.45)
			m:Show()
		elseif row.suiMark then
			row.suiMark.e = nil
			row.suiMark:Hide()
		end
	end
end

function M.LogHook()
	if M.logHooked then return end
	local orig = glob("QuestLog_Update")
	if type(orig) ~= "function" then return end
	M.logHooked = true
	local function wrapped(a, b)
		orig(a, b)
		if M.on and M.logp then pcall(M.LogPaint) end
	end
	setglobal("QuestLog_Update", wrapped)
end

function M.LogSync()
	local want = M.on and C.Get("questtrack.logpanel") and glob("QuestLogFrame") ~= nil
	if want then
		local f = M.LogBuild()
		if f then
			f:Show()
			M.LogHook()
			M.LogPaint()
		end
	elseif M.logp then
		M.logp:Hide()
		for i = 1, M.LOGROWS do
			local row = glob("QuestLogTitle" .. i)
			if not row then break end
			if row.suiMark then row.suiMark:Hide() end
		end
	end
end

-- Changement de zone : la liste "zone actuelle seulement" se recompose
function M.OnZone()
	if M.on and M.frame and C.Get("questtrack.zoneonly") then M.Paint() end
end

-- ---------------------------------------------------------------- cycle de vie, commande
-- Bouton "Quetes" autour de la minicarte (glissable) : affiche / masque le suivi de quetes
function M.RingButton()
	local want = M.on and C.Get("questtrack.btn") and true or false
	local b = M.rbtn
	if not b and want then
		local mm = getglobal("Minimap")
		if not mm or SUI.InCombat() then return end
		b = T.Button(mm, L("msg.questtrack.btn"), 50, 22, function() C.Set("questtrack.show", not C.Get("questtrack.show")) end)
		b.suiOwn = true
		b:SetFrameStrata("HIGH")
		b:SetFrameLevel((mm:GetFrameLevel() or 0) + 12)
		b:SetScript("OnEnter", M.RingEnter)
		b:SetScript("OnLeave", M.RingLeave)
		SUI.MiniRing.Drag(b, "questtrack.angle", 270)
		M.rbtn = b
	end
	if b then
		if want then
			if not b.ringDrag then SUI.MiniRing.Place(b, "questtrack.angle", 270) end
			b:Show()
		else
			b:Hide()
		end
	end
end

function M.RingEnter()
	local r, g, bl = T.Accent()
	this:SetBackdropBorderColor(r, g, bl, 1)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine(L("cat.questtrack"))
	GameTooltip:AddLine(L("msg.questtrack.btn.tip"), T.c.dim[1], T.c.dim[2], T.c.dim[3])
	GameTooltip:Show()
end

function M.RingLeave()
	this:SetBackdropBorderColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	GameTooltip:Hide()
end

function M.OnKey(key, value)
	if key == "questtrack.btn" or key == "questtrack.angle" then M.RingButton() end
	if key == "questtrack.arrow" then M.ArrowSync() end
	if not M.on then return end
	M.Sync()
	if M.frame then M.Paint() end
	if key == "questtrack.logpanel" then M.LogSync() end
	if key == "questtrack.arrowq" then M.apick = 0 end
	if key == "questtrack.hide" or key == "questtrack.arrowq" then
		M.LogPaint()
	end
	if key == "questtrack.pins" or key == "questtrack.givers" or key == "questtrack.giverlow" or key == "questtrack.giverhigh" or key == "questtrack.hide" then
		local Cx = SUI.Codex
		if Cx and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
	end
end

function M.Enable()
	M.on = true
	SUI.On("QUEST_LOG_UPDATE", M.Queue)
	SUI.On("PLAYER_ENTERING_WORLD", M.Queue)
	SUI.On("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.On("WORLD_MAP_UPDATE", M.LegendEvent)
	if not M.watching then
		M.watching = true
		C.Watch("questtrack.", M.OnKey)
	end
	M.Sync()
	M.Queue()
	M.RingButton()
	M.ArrowSync()
	M.LogSync()
	M.Legend()
	M.LegendPaint()
end

function M.Disable()
	M.on = false
	M.ArrowSync()
	M.RingButton()
	M.LogSync()
	SUI.Off("QUEST_LOG_UPDATE", M.Queue)
	SUI.Off("PLAYER_ENTERING_WORLD", M.Queue)
	SUI.Off("ZONE_CHANGED_NEW_AREA", M.OnZone)
	SUI.Off("WORLD_MAP_UPDATE", M.LegendEvent)
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	M.Sync()
	M.MiniSync()
	if M.frame then M.frame:Hide() end
	if M.resTask then
		SUI.Cancel(M.resTask)
		M.resTask = nil
	end
	if M.gtask then
		SUI.Cancel(M.gtask)
		M.gtask = nil
	end
	M.list, M.sig, M.tix, M.recs = {}, nil, nil, {}
	M.gready, M.gbuilding, M.gids, M.gby, M.gz = false, false, nil, nil, nil
end

-- /sui quests arrow : cible d'essai pendant 30 s (a 100 yards au nord-est de toi), pour voir la fleche sans quete dans la zone
function M.ArrowTest()
	local gp = glob("GetPlayerMapPosition")
	local px, py = 0, 0
	if gp then px, py = gp("player") end
	if not px or (px == 0 and py == 0) then
		SUI.Print(L("msg.questtrack.arrow.nopos"))
		return
	end
	M.atest = { x = px + 100 / 4000, y = py - 100 / 2667, w = 4000, h = 2667, title = L("msg.questtrack.arrow.test"), till = GetTime() + 30 }
	M.apick = 0
	M.ArrowSync()
end

function M.Command(rest)
	local arg = slower(rest or "")
	if arg == "arrow" then
		M.ArrowTest()
		return
	end
	if arg == "pick" then
		M.OpenLog(nil)
		return
	end
	if arg == "show" or arg == "hide" then
		C.Set("questtrack.show", arg == "show")
	end
	SUI.Print(L("msg.questtrack.status", getn(M.list), C.Get("questtrack.show") and "1" or "0"))
end

local function opt(key, typ, order, def, extra)
	local o = { key = "questtrack." .. key, type = typ, cat = "questtrack", label = "opt.questtrack." .. key, tip = "tip.questtrack." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterCategory("questtrack", 80)

SUI.RegisterModule("questtrack", {
	default = true,
	cost = "light",
	options = {
		opt("show", "bool", 10, true, { simple = true }),
		opt("drag", "bool", 12, true, { simple = true }),
		opt("pins", "bool", 20, true, { simple = true }),
		opt("givers", "bool", 25, true, { simple = true }),
		opt("mini", "bool", 22, true, { simple = true }),
		opt("minigivers", "bool", 22.5, true, { simple = true }),
		opt("miniedge", "bool", 23, true),
		opt("btn", "bool", 21, true),
		opt("arrow", "bool", 21.2, true, { simple = true }),
		opt("logpanel", "bool", 11, true, { simple = true }),
		opt("zoneonly", "bool", 11.5, false),
		opt("angle", "number", 21.5, 270, { min = 0, max = 355, step = 5 }),
		opt("pinsize", "number", 24, 16, { min = 12, max = 32, step = 1 }),
		opt("giverlow", "number", 26, 6, { min = 0, max = 20, step = 1 }),
		opt("mark", "bool", 26.7, true, { simple = true }),
		opt("legend", "bool", 26.8, true),
		opt("legendmine", "bool", 26.9, true),
		opt("giverhigh", "number", 26.5, 3, { min = 0, max = 10, step = 1 }),
		opt("max", "number", 30, 8, { min = 3, max = 15, step = 1 }),
		opt("width", "number", 40, 230, { min = 160, max = 400, step = 10 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("quests", function(rest) M.Command(rest or "") end, "help.questtrack")
