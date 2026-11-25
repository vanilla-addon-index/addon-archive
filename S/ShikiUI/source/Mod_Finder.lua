-- ShikiUI Finder : le "Chercheur de groupe" (module "finder", commande /sui lfg). Notre propre moteur de recherche de groupe, sans aucun addon tiers.
-- Il ECOUTE les canaux publics (CHAT_MSG_CHANNEL : Monde, LookingForGroup, General, Commerce...; aussi CHAT_MSG_YELL / CHAT_MSG_SAY) et
-- ANALYSE chaque annonce pour en faire une carte propre : type (LFM = cherche des membres, LFG = cherche un groupe ; les ventes, boosts et
-- recrutements de guilde sont exclus), instance reconnue (table de donjons / raids vanilla + Turtle WoW, noms FR / EN et abreviations),
-- roles recherches (tank / soin / DPS et leur nombre), places restantes, niveau, GS, regle de butin (SR, HR, MS>OS, GDKP...), prix.
-- La fenetre (bouton minimap, bouton dans la fenetre Social, /sui lfg) montre une liste filtrable (type, instance, role, niveau, texte),
-- triee par fraicheur, qui expire seule (15 min par defaut). Auteur cliquable : chuchoter (Maj+clic : reponse rapide), inviter (si on peut),
-- ignorer. "Mes alertes" : son + message quand une annonce correspond (ex. Strat vivante + tank). "Poster mon annonce" : compose le
-- message a partir de l'instance et des roles, l'envoie sur le canal choisi en respectant un delai anti-spam ; JAMAIS d'envoi sans clic.
-- ANALYSE LEGERE : une chaine = minuscules + un gsub de classe simple ("[^a-z0-9]") + decoupe en mots par string.find a plat + consultations de
-- tables de hachage ; les expressions de plusieurs mots (noms d'instances) sont cherchees par string.find a plat. Jamais de string.match
-- ni de motif a '%'. Tables de travail reutilisees : aucune table creee par annonce.
-- ECOUTE MINIMALE : tant que la fenetre est fermee ET qu'aucune alerte n'est active (et que le reglage "Ecoute" est sur "auto"), AUCUN
-- evenement n'est ecoute et aucune minuterie ne tourne. Reglage "toujours" : la liste est deja pleine a l'ouverture.
-- TAMPON : 200 annonces au plus (anneau), alloue hors combat une seule fois ; une annonce du meme auteur / meme instance / meme type
-- rafraichit la carte existante (anti-doublon, compteur de repetitions) ; option "regrouper par auteur" : une carte par auteur.
-- CONTRAINTE CLIENT : le client 1.12 change le niveau des cadres apres leur construction (voir Menu.SyncLevel) : tous les controles de
-- la fenetre et des fenetres annexes sont ENFANTS du bon cadre et recales par M.SyncLevels (survol, affichage, minuterie, /sui lfg diag).
-- SOURCES (noms d'API relevees dans les addons installes, non executees ici) : CHAT_MSG_CHANNEL (arg1 texte, arg2 auteur, arg4 "N. canal"),
--  CHAT_MSG_YELL / CHAT_MSG_SAY, SendChatMessage(texte, "CHANNEL", nil, numero), GetChannelList, InviteByName, ChatFrame_SendTell,
--  IsPartyLeader / IsRaidLeader / IsRaidOfficer / GetNumPartyMembers / GetNumRaidMembers, PlaySound, UnitName / UnitLevel / UnitClass.
-- NON VERIFIE EN JEU : tout. Notamment le format de arg4 des messages de canal, GetChannelList, les niveaux des controles, l'emplacement
--  du bouton dans FriendsFrame, les noms et niveaux des donjons Turtle WoW (approximatifs), les noms de sons.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local sfind, ssub, slower, sformat, sbyte, sgsub, slen, srep = string.find, string.sub, string.lower, string.format, string.byte,
	string.gsub, string.len, string.rep
local floor = math.floor

local M = {}
SUI.Finder = M

local MAXRING = 200
local MAXALERTS = 8
local MAXIGN = 80
local WIN_W = 592
local NROWS_MAX = 12
local LISTROWS = 12
local SPACES = srep(" ", 64)

M.on = false
M.ring = {}
M.ringReady = false
M.cap = MAXRING
M.head = 0
M.seq = 0
M.view = {}
M.nview = 0
M.alerts = {}
M.nalerts = 0
M.ign = {}
M.nign = 0
M.reg = {}
M.listening = false
M.hits = 0
M.off = 0
M.dirty = false
M.epoch = 1
M.stat = { seen = 0, kept = 0, sale = 0, guild = 0, noise = 0, dup = 0, ign = 0, alerts = 0 }
M.f = { kind = "all", inst = 0, tank = false, heal = false, dps = false, mine = false, q = "" }
M.ps = { kind = "lfm", inst = 0, tank = 1, heal = 1, dps = 2, lv = "", loot = "", note = "", ch = 1 }
M.pch = {}
M.npch = 0
M.lastPostT = -1000
M.lastPostText = ""
M.lastRender = 0
M.tpls = { "", "", "", "" }
M.uAlias = {}
M.chanOK = {}
M.me = ""

-- ================================================================ donnees : instances
-- { cle, nom FR, nom EN, abrege, genre (d donjon / r raid / o autre), niveau min, niveau max, taille, alias separes par | }
-- Les alias s'ecrivent en minuscules sans accents ni apostrophes (le texte est normalise de la meme facon : "Zul'Farrak" -> "zul farrak").
-- Niveaux et noms des donjons Turtle WoW : approximatifs (voir "limites" du rapport).
local INST = {
	{ "rfc", "Gouffre de Ragefeu", "Ragefire Chasm", "RFC", "d", 13, 18, 5, "rfc|ragefire|ragefeu" },
	{ "wc", "Cavernes des Lamentations", "Wailing Caverns", "WC", "d", 17, 24, 5, "wc|lamentations|wailing" },
	{ "dm", "Mortemines", "The Deadmines", "DM", "d", 17, 26, 5, "dm|deadmines|mortemines|dead mines|defias|van cleef|vancleef" },
	{ "sfk", "Donjon d'Ombrecroc", "Shadowfang Keep", "SFK", "d", 22, 30, 5, "sfk|shadowfang|ombrecroc" },
	{ "stock", "La Prison", "The Stockade", "Stocks", "d", 22, 30, 5, "stocks|stockade|stockades|prison|prison de hurlevent" },
	{ "bfd", "Profondeurs de Brassenoire", "Blackfathom Deeps", "BFD", "d", 24, 32, 5, "bfd|blackfathom|brassenoire" },
	{ "gm", "Mines de Glittermurk", "Glittermurk Mines", "GMM", "d", 20, 28, 5, "gmm|glittermurk" },
	{ "gnomer", "Gnomeregan", "Gnomeregan", "Gnomer", "d", 29, 38, 5, "gnomer|gnomeregan" },
	{ "cg", "Bosquet du Croissant", "Crescent Grove", "CG", "d", 32, 38, 5, "cg|crescent|crescent grove|bosquet du croissant" },
	{ "rfk", "Kraal de Tranchebauge", "Razorfen Kraul", "RFK", "d", 30, 40, 5, "rfk|kraul|kraal" },
	{ "smgy", "Monastere Ecarlate - Cimetiere", "Scarlet Monastery - Graveyard", "SM GY", "d", 28, 38, 5,
		"smgy|sm gy|sm graveyard|sm cimetiere|scarlet graveyard|monastere cimetiere" },
	{ "smlib", "Monastere Ecarlate - Bibliotheque", "Scarlet Monastery - Library", "SM Lib", "d", 29, 39, 5,
		"smlib|sm lib|sm library|sm bibliotheque|sm biblio|scarlet library" },
	{ "smarm", "Monastere Ecarlate - Armurerie", "Scarlet Monastery - Armory", "SM Arm", "d", 32, 42, 5,
		"smarm|sm arm|sm armory|sm armurerie|scarlet armory" },
	{ "smcath", "Monastere Ecarlate - Cathedrale", "Scarlet Monastery - Cathedral", "SM Cath", "d", 35, 45, 5,
		"smcath|sm cath|sm cathedral|sm cathedrale|scarlet cathedral" },
	{ "sm", "Monastere Ecarlate", "Scarlet Monastery", "SM", "d", 34, 45, 5, "sm|scarlet|monastere|scarlet monastery|monastere ecarlate" },
	{ "rfd", "Souilles de Tranchebauge", "Razorfen Downs", "RFD", "d", 37, 46, 5, "rfd|souilles" },
	{ "uld", "Uldaman", "Uldaman", "ULD", "d", 41, 51, 5, "uld|ulda|uldaman" },
	{ "zf", "Zul'Farrak", "Zul'Farrak", "ZF", "d", 44, 54, 5, "zf|zulfarrak|zul farrak" },
	{ "mara", "Maraudon", "Maraudon", "Mara", "d", 46, 55, 5, "mara|maraudon|maraud" },
	{ "hfq", "Carriere de Forgehaine", "Hateforge Quarry", "HFQ", "d", 50, 56, 5, "hfq|hateforge|hateforge quarry" },
	{ "gil", "Gilneas", "Gilneas City", "Gilneas", "d", 50, 56, 5, "gilneas|gilneas city" },
	{ "st", "Temple d'Atal'Hakkar", "Sunken Temple", "ST", "d", 50, 60, 5,
		"st|atal hakkar|atalhakkar|temple englouti|sunken temple|sunken|englouti" },
	{ "brd", "Profondeurs de Blackrock", "Blackrock Depths", "BRD", "d", 52, 60, 5, "brd|blackrock depths|profondeurs de blackrock" },
	{ "lbrs", "Pic Blackrock inferieur", "Lower Blackrock Spire", "LBRS", "d", 55, 60, 5,
		"lbrs|lrbs|lower brs|lower blackrock spire|pic blackrock inferieur" },
	{ "ubrs", "Pic Blackrock superieur", "Upper Blackrock Spire", "UBRS", "d", 58, 60, 10,
		"ubrs|urbs|upper brs|upper blackrock spire|pic blackrock superieur" },
	{ "brs", "Pic Blackrock", "Blackrock Spire", "BRS", "d", 55, 60, 5, "brs|blackrock spire|pic blackrock|pic de blackrock" },
	{ "dme", "Hache-Tripes Est", "Dire Maul East", "DME", "d", 56, 60, 5,
		"dme|dm east|dm e|dm est|dire maul east|dire maul e|dire maul est|hache tripes est" },
	{ "dmw", "Hache-Tripes Ouest", "Dire Maul West", "DMW", "d", 57, 60, 5,
		"dmw|dm west|dm w|dm ouest|dire maul west|dire maul w|dire maul ouest|hache tripes ouest" },
	{ "dmn", "Hache-Tripes Nord", "Dire Maul North", "DMN", "d", 57, 60, 5,
		"dmn|dm north|dm n|dm nord|dire maul north|dire maul n|dire maul nord|hache tripes nord|tribute|tribut|dm tribute|dire maul tribute" },
	{ "dire", "Hache-Tripes", "Dire Maul", "Dire Maul", "d", 56, 60, 5, "dire|dire maul|hache tripes|haches tripes" },
	{ "stratl", "Stratholme (vivante)", "Stratholme Live", "Strat Live", "d", 58, 60, 5,
		"stratlive|stratlv|strat live|strat living|strat alive|strat vivante|strat vivant|stratholme live|stratholme living|stratholme vivante|stratholme vivant" },
	{ "stratud", "Stratholme (morte)", "Stratholme UD", "Strat UD", "d", 58, 60, 5,
		"stratud|strat ud|strat undead|strat dead|strat morte|strat mort|strat baron|stratholme ud|stratholme undead|stratholme morte|baron|baron rivendare" },
	{ "strat", "Stratholme", "Stratholme", "Strat", "d", 58, 60, 5, "strat|stratholme" },
	{ "scholo", "Scholomance", "Scholomance", "Scholo", "d", 58, 60, 5, "scholo|scholomance|sholo" },
	{ "dmr", "Retraite des Dragonmaw", "Dragonmaw Retreat", "DMR", "d", 56, 60, 5, "dmr|dragonmaw|dragonmaw retreat" },
	{ "sv", "Caveau de Hurlevent", "Stormwind Vault", "SV", "d", 60, 60, 5, "sv|stormwind vault|caveau de hurlevent|caveau|vault" },
	{ "kc", "Crypte de Karazhan", "Karazhan Crypt", "KC", "d", 60, 60, 5, "kc|crypt|crypte|karazhan crypt|crypte de karazhan" },
	{ "lkh", "Salles basses de Karazhan", "Lower Karazhan Halls", "Kara10", "r", 60, 60, 10,
		"lkh|lower karazhan halls|lower karazhan|lower kara|salles basses de karazhan|kara10|kara 10|kz10|kz 10|karazhan10|karazhan 10|karazhan 10 man|karazhan 10man" },
	{ "bm", "Marais Noir", "Black Morass", "BM", "d", 60, 60, 5, "bm|black morass|morass|marais noir" },
	{ "ony", "Onyxia", "Onyxia's Lair", "Ony", "r", 60, 60, 40, "ony|onyxia|onyxia s lair|onyxia lair|repaire d onyxia" },
	{ "mc", "Coeur du Magma", "Molten Core", "MC", "r", 60, 60, 40, "mc|molten core|coeur du magma" },
	{ "zg", "Zul'Gurub", "Zul'Gurub", "ZG", "r", 60, 60, 20, "zg|zulgurub|zul gurub" },
	{ "aq20", "Ruines d'Ahn'Qiraj", "Ruins of Ahn'Qiraj", "AQ20", "r", 60, 60, 20,
		"aq20|aq 20|ruins of ahn qiraj|ruines d ahn qiraj|ruines ahn qiraj|ruins|ruines|ossirian" },
	{ "bwl", "Repaire de l'Aile noire", "Blackwing Lair", "BWL", "r", 60, 60, 40, "bwl|blackwing lair|blackwing|repaire de l aile noire|aile noire" },
	{ "aq40", "Temple d'Ahn'Qiraj", "Temple of Ahn'Qiraj", "AQ40", "r", 60, 60, 40,
		"aq40|aq 40|temple of ahn qiraj|temple d ahn qiraj|ahn qiraj|aq" },
	{ "naxx", "Naxxramas", "Naxxramas", "Naxx", "r", 60, 60, 40, "naxx|naxxramas|nax" },
	{ "es", "Sanctuaire d'Emeraude", "Emerald Sanctum", "ES", "r", 60, 60, 40, "emerald sanctum|sanctuaire d emeraude" },
	{ "ukh", "Karazhan (hauts)", "Upper Karazhan Halls", "Kara40", "r", 60, 60, 40,
		"ukh|kara40|kara 40|karazhan|kara|upper karazhan halls|upper karazhan|upper kara|hauts de karazhan|tour de karazhan|tower of karazhan" },
	{ "wb", "Boss mondial", "World Boss", "World Boss", "r", 60, 60, 40,
		"world boss|boss mondial|azuregos|kazzak|lethon|emeriss|taerar|ysondre|dragons du cauchemar|emerald dragons" },
	{ "quest", "Quete", "Quest", "Quest", "o", 1, 60, 5, "quest|quests|quete|quetes" },
}
M.INST = INST
local NI = getn(INST)
local IXKEY = {}
for i = 1, NI do IXKEY[INST[i][1]] = i end
M.IXKEY = IXKEY
-- Instances generiques : une alerte ou un filtre sur "Stratholme" couvre aussi ses variantes.
local PARENT = {}
local function setParent(parent, kids)
	for i = 1, getn(kids) do PARENT[IXKEY[kids[i]]] = IXKEY[parent] end
end
setParent("strat", { "stratl", "stratud" })
setParent("sm", { "smgy", "smlib", "smarm", "smcath" })
setParent("dire", { "dme", "dmw", "dmn" })
setParent("brs", { "lbrs", "ubrs" })
local function instIs(r, ix)
	local a, b = r.i1, r.i2
	if a == ix or b == ix then return true end
	if (a and PARENT[a] == ix) or (b and PARENT[b] == ix) then return true end
	return false
end
local IX_DM, IX_STRAT, IX_STRATL, IX_STRATUD = IXKEY.dm, IXKEY.strat, IXKEY.stratl, IXKEY.stratud
local IX_SM, IX_SMGY, IX_SMLIB, IX_SMARM, IX_SMCATH = IXKEY.sm, IXKEY.smgy, IXKEY.smlib, IXKEY.smarm, IXKEY.smcath
local IX_AQ40, IX_AQ20, IX_DIRE, IX_QUEST = IXKEY.aq40, IXKEY.aq20, IXKEY.dire, IXKEY.quest

-- ================================================================ donnees : vocabulaire
local V = { role = {}, lfm = {}, lfn = {}, lfg = {}, cue = {}, need = {}, sale = {}, guild = {}, grp = {}, dispo = {}, loot = {},
	tag = {}, lvlw = {}, gsw = {}, price = {}, flag = {}, more = {}, lastw = {}, spot = {}, instw = {}, multi = {}, nmulti = 0,
	lfgphr = {}, lfmphr = {} }
M.V = V

local function fill(tbl, words, value)
	local pos = 1
	while pos <= slen(words) do
		local e = sfind(words, " ", pos, true)
		if not e then e = slen(words) + 1 end
		if e > pos then tbl[ssub(words, pos, e - 1)] = value end
		pos = e + 1
	end
end

fill(V.role, "tank tanks tk offtank maintank tanque", "tank")
fill(V.role, "heal heals healer healers healeur healeurs healz soigneur soigneurs soins soin hot", "heal")
fill(V.role, "dps dd ddps mdps rdps dmg degats damage dpser dpsers cac caster casters melee range ranged mage mages rogue rogues voleur voleurs hunter hunters chasseur chasseurs warlock warlocks demoniste demonistes", "dps")
fill(V.lfm, "lfm lfmore", true)
V.lfn.lf1m, V.lfn.lf2m, V.lfn.lf3m, V.lfn.lf4m, V.lfn.lf5m = 1, 2, 3, 4, 5
fill(V.lfg, "lfg lfgroup", true)
fill(V.cue, "lf looking cherche chercher cherchons recherche recherchons recrute recrutons wanted", true)
fill(V.need, "need needs needed besoin manque missing", true)
fill(V.sale, "wts wtb wtt selling buying vends vend vente achete achat acheter boost boosting boosts carry carries", true)
fill(V.guild, "guild guilde recruiting recrutement guildes", true)
fill(V.grp, "group groupe party team equipe grp", true)
fill(V.dispo, "dispo dispos available disponible", true)
fill(V.loot, "sr softres softreserve hr hardres hardreserve", "sr")
V.loot.hr, V.loot.hardres, V.loot.hardreserve = "hr", "hr", "hr"
fill(V.loot, "gdkp", "gdkp")
fill(V.loot, "dkp", "dkp")
fill(V.loot, "ffa freeforall", "ffa")
fill(V.loot, "nbg needbeforegreed", "nbg")
fill(V.loot, "msos", "msos")
fill(V.tag, "flask flasks consumes consumable consumables conso consos consommables pots", "flask")
fill(V.tag, "res resist resists resistance resistances", "res")
fill(V.tag, "exp expe experienced experimente experimentes expert", "exp")
fill(V.tag, "discord ts teamspeak mumble vocal voc", "voc")
fill(V.lvlw, "lvl lv level niv niveau lvls levels", true)
fill(V.gsw, "gs gearscore", true)
fill(V.price, "g gold golds po pa", true)
fill(V.more, "more encore", true)
fill(V.lastw, "last dernier derniere", true)
fill(V.spot, "spot place slot spots places slots", true)
fill(V.flag, "live living alive vivante vivant vivantes", "live")
fill(V.flag, "ud undead dead mort morte morts", "ud")
fill(V.flag, "gy graveyard cimetiere", "gy")
fill(V.flag, "lib library bibliotheque biblio", "lib")
fill(V.flag, "arm armory armurerie", "arm")
fill(V.flag, "cath cathedral cathedrale cathe", "cath")
V.lfgphr = { " looking for group ", " lf group ", " lf a group ", " lf party ", " lf team ", " cherche groupe ", " cherche un groupe ",
	" cherche une groupe ", " recherche groupe ", " recherche un groupe ", " need group ", " need a group ", " besoin d un groupe ",
	" cherche party ", " cherche team ", " cherche equipe " }
V.lfmphr = { " looking for more ", " lf more ", " lf all ", " need all " }
V.nlfgphr, V.nlfmphr = getn(V.lfgphr), getn(V.lfmphr)

-- ---------------------------------------------------------------- normalisation du texte
local function fold(s)
	if sfind(s, "\195", 1, true) then
		s = sgsub(s, "\195[\160-\165\128-\133]", "a")
		s = sgsub(s, "\195[\167\135]", "c")
		s = sgsub(s, "\195[\168-\171\136-\139]", "e")
		s = sgsub(s, "\195[\172-\175\140-\143]", "i")
		s = sgsub(s, "\195[\178-\182\146-\150]", "o")
		s = sgsub(s, "\195[\185-\188\153-\156]", "u")
	end
	return s
end

-- Retourne le texte normalise (minuscules, sans accents, seulement a-z 0-9 et des espaces simples, entoure d'un espace) et les minuscules brutes.
-- Les mots-cles LFM / LFG colles au reste (ex. "LFMKara10") sont separes : sans cela, le token colle ne matche ni le mot-cle ni l'instance.
local function normalize(msg)
	local low = slower(msg)
	local s = fold(low)
	s = sgsub(s, "[^a-z0-9]", " ")
	s = " " .. s .. " "
	s = sgsub(s, "  +", " ")
	s = sgsub(s, " lfm([a-z])", " lfm %1")
	s = sgsub(s, " lfg([a-z])", " lfg %1")
	return s, low
end
M.Normalize = normalize

local function addAlias(a, ix)
	if a == "" then return end
	if sfind(a, " ", 1, true) then
		local n = V.nmulti + 1
		V.nmulti = n
		V.multi[n] = { " " .. a .. " ", ix }
	else
		V.instw[a] = ix
	end
end

local function buildInst()
	V.instw = {}
	V.multi = {}
	V.nmulti = 0
	for ix = 1, NI do
		local row = INST[ix]
		local list = row[9]
		local pos = 1
		while pos <= slen(list) do
			local e = sfind(list, "|", pos, true)
			if not e then e = slen(list) + 1 end
			if e > pos then addAlias(ssub(list, pos, e - 1), ix) end
			pos = e + 1
		end
		local fr = (normalize(row[2]))
		local en = (normalize(row[3]))
		addAlias(ssub(fr, 2, slen(fr) - 1), ix)
		addAlias(ssub(en, 2, slen(en) - 1), ix)
	end
	table.sort(V.multi, function(a, b) return slen(a[1]) > slen(b[1]) end)
end
buildInst()

-- Alias propres au joueur (reglage finder.alias "mot=cle;mot=cle") : un seul mot par alias.
function M.LoadAlias()
	for k, _ in pairs(M.uAlias) do M.uAlias[k] = nil end
	local s = C.Get("finder.alias") or ""
	local pos = 1
	while pos <= slen(s) do
		local e = sfind(s, ";", pos, true)
		if not e then e = slen(s) + 1 end
		local item = ssub(s, pos, e - 1)
		local eq = sfind(item, "=", 1, true)
		if eq then
			local w, k = ssub(item, 1, eq - 1), ssub(item, eq + 1)
			if w ~= "" and IXKEY[k] then M.uAlias[w] = IXKEY[k] end
		end
		pos = e + 1
	end
end

-- ================================================================ analyse d'une annonce
local WORDS = {}
local FL = { live = false, ud = false, gy = false, lib = false, arm = false, cath = false, w20 = false, aq = false, dm = false }
local P = { tank = 0, heal = 0, dps = 0, places = 0, gs = 0, price = 0 }
M.P = P

local function resetP()
	P.kind, P.i1, P.i2, P.lv, P.loot = nil, nil, nil, nil, nil
	P.tank, P.heal, P.dps, P.places, P.gs, P.price = 0, 0, 0, 0, 0, 0
	P.flask, P.res, P.exp, P.voc = false, false, false, false
	for k, _ in pairs(FL) do FL[k] = false end
end

local function addInst(ix)
	if ix == P.i1 or ix == P.i2 then return end
	if not P.i1 then P.i1 = ix elseif not P.i2 then P.i2 = ix end
end

local LOOTRANK = { gdkp = 7, hr = 6, sr = 5, msos = 4, dkp = 3, ffa = 2, nbg = 1 }
local function setLoot(code)
	if not P.loot or LOOTRANK[code] > LOOTRANK[P.loot] then P.loot = code end
end

local function setLv(n)
	if n >= 5 and n <= 60 and not P.lv then P.lv = n end
end

-- Expressions de plusieurs mots : trouvees a plat puis effacees du texte (les mots isoles ne comptent pas deux fois).
local function scanMulti(norm)
	local multi = V.multi
	for k = 1, V.nmulti do
		local m = multi[k]
		local s, e = sfind(norm, m[1], 1, true)
		if s then
			addInst(m[2])
			norm = ssub(norm, 1, s) .. ssub(SPACES, 1, e - s - 1) .. ssub(norm, e)
		end
	end
	return norm
end

local function splitWords(norm)
	local n, pos, len = 0, 1, slen(norm)
	while pos <= len and n < 64 do
		local e = sfind(norm, " ", pos, true)
		if not e then break end
		if e > pos then
			n = n + 1
			WORDS[n] = ssub(norm, pos, e - 1)
		end
		pos = e + 1
	end
	return n
end

-- Niveau "NN+" et "NN-NN" lus dans le texte brut (le '+' et le '-' sont effaces de la version normalisee).
local function scanSymbols(low)
	local pos = 1
	local guard = 0
	while guard < 6 do
		guard = guard + 1
		local p = sfind(low, "+", pos, true)
		if not p then break end
		if p >= 3 then
			local n = tonumber(ssub(low, p - 2, p - 1))
			if n and n >= 10 and n <= 60 and sbyte(low, p - 2) ~= 32 and sbyte(low, p - 2) ~= 47 then setLv(n) end
		end
		pos = p + 1
	end
	pos, guard = 1, 0
	while guard < 6 do
		guard = guard + 1
		local p = sfind(low, "-", pos, true)
		if not p then break end
		if p >= 3 then
			local a, b = tonumber(ssub(low, p - 2, p - 1)), tonumber(ssub(low, p + 1, p + 2))
			if a and b and a >= 10 and a <= 60 and b >= a and b <= 60 and sbyte(low, p - 2) ~= 32 then setLv(a) end
		end
		pos = p + 1
	end
	-- "3/5", "12/40" : joueurs presents / taille du groupe
	pos, guard = 1, 0
	while guard < 4 do
		guard = guard + 1
		local p = sfind(low, "/", pos, true)
		if not p then break end
		if p >= 2 then
			local size = tonumber(ssub(low, p + 1, p + 2))
			if not size or size < 10 then size = tonumber(ssub(low, p + 1, p + 1)) end
			local have = tonumber(ssub(low, p - 2, p - 1))
			local c0 = sbyte(low, p - 2)
			if not have or have < 0 or have > 40 or (c0 and (c0 < 48 or c0 > 57)) then have = tonumber(ssub(low, p - 1, p - 1)) end
			if size and have and (size == 5 or size == 10 or size == 20 or size == 25 or size == 40) and have >= 1 and have < size then
				if P.places == 0 then P.places = size - have end
				break
			end
		end
		pos = p + 1
	end
end

-- Analyse une annonce. Retourne "lfm" / "lfg" (resultat dans M.P) ou nil + raison ("sale", "guild", "noise", "none").
function M.Parse(msg)
	resetP()
	local norm, low = normalize(msg)
	local xlfm, xlfg, phrG, phrM = false, false, false, false
	local sale, guild, grp, dispo = false, false, false, false
	if sfind(low, "|hitem", 1, true) then sale = true end
	local pk = V.lfgphr
	for k = 1, V.nlfgphr do
		if sfind(norm, pk[k], 1, true) then phrG = true break end
	end
	pk = V.lfmphr
	for k = 1, V.nlfmphr do
		if sfind(norm, pk[k], 1, true) then phrM = true break end
	end
	norm = scanMulti(norm)
	local nw = splitWords(norm)
	local lastNum, lastNumI = 0, -9
	local cueI, needI, lvlI, gsI, plNeed, lastI = -9, -9, -9, -9, 0, -9
	local roleSeen, roleCue, roleNeed = false, false, false
	local lvlCand = nil
	local uA = M.uAlias
	for i = 1, nw do
		local w = WORDS[i]
		local c1 = sbyte(w, 1)
		local num, rest = nil, w
		if c1 >= 48 and c1 <= 57 then
			local j, n = 1, slen(w)
			while j <= n do
				local cj = sbyte(w, j)
				if cj < 48 or cj > 57 then break end
				j = j + 1
			end
			if j <= 7 then
				num = tonumber(ssub(w, 1, j - 1))
				rest = ssub(w, j)
			else
				rest = ""
			end
		end
		if num and rest == "" then
			lastNum, lastNumI = num, i
			if i - needI == 1 then plNeed = num end
			if num == 20 then FL.w20 = true end
			if i - lvlI == 1 then setLv(num) end
			if i - gsI == 1 then P.gs = num end
			if num >= 10 and num <= 60 and not lvlCand and i - needI ~= 1 then lvlCand = num end
		elseif rest ~= "" then
			if num then
				lastNum, lastNumI = num, i - 1
				if V.price[rest] then P.price = num end
				if V.gsw[rest] then P.gs = num end
				if V.lvlw[rest] then setLv(num) end
			end
			-- mot terminant par des chiffres : lvl55, gs1200
			local cl = sbyte(rest, slen(rest))
			if not num and cl >= 48 and cl <= 57 and slen(rest) > 2 then
				local j = slen(rest)
				while j > 1 and sbyte(rest, j - 1) >= 48 and sbyte(rest, j - 1) <= 57 do j = j - 1 end
				local pre, nn = ssub(rest, 1, j - 1), tonumber(ssub(rest, j))
				if nn then
					if V.lvlw[pre] then setLv(nn) elseif V.gsw[pre] then P.gs = nn end
				end
			end
			local ix = V.instw[rest] or uA[rest]
			if ix and not num then
				addInst(ix)
				if rest == "dm" then FL.dm = true elseif rest == "aq" then FL.aq = true end
			end
			local r = V.role[rest]
			if r then
				local cnt = 1
				local pre = (lastNumI == i - 1) or (num ~= nil)
				if pre and lastNum >= 1 and lastNum <= 9 then cnt = lastNum end
				if cnt > P[r] then P[r] = cnt end
				if pre and plNeed == lastNum then plNeed = 0 end
				if pre and lvlCand == lastNum then lvlCand = nil end
				roleSeen = true
				if i - cueI <= 4 then roleCue = true end
				if i - needI <= 4 then roleNeed = true end
			end
			if not num then
				if V.lfm[rest] then xlfm = true end
				local ln = V.lfn[rest]
				if ln then
					xlfm = true
					if P.places == 0 then P.places = ln end
				end
				if V.lfg[rest] then xlfg = true end
				if V.cue[rest] then cueI = i end
				if V.need[rest] then needI = i end
				if V.sale[rest] then sale = true end
				if V.guild[rest] then guild = true end
				if V.grp[rest] then grp = true end
				if V.dispo[rest] then dispo = true end
				local lo = V.loot[rest]
				if lo then setLoot(lo) end
				if rest == "os" and WORDS[i - 1] == "ms" then setLoot("msos") end
				local tg = V.tag[rest]
				if tg == "flask" then P.flask = true elseif tg == "res" then P.res = true elseif tg == "exp" then P.exp = true
				elseif tg == "voc" then P.voc = true end
				if V.lvlw[rest] then lvlI = i end
				if V.gsw[rest] then gsI = i end
				if V.price[rest] and lastNumI == i - 1 and lastNum >= 1 then
					P.price = lastNum
					if lvlCand == lastNum then lvlCand = nil end
				end
				if V.more[rest] and lastNumI == i - 1 and plNeed == 0 and lastNum >= 1 and lastNum <= 39 then plNeed = lastNum end
				if V.lastw[rest] then lastI = i end
				if V.spot[rest] and i - lastI <= 2 and plNeed == 0 then plNeed = 1 end
			end
			local fg = V.flag[rest]
			if fg then FL[fg] = true end
		end
	end
	scanSymbols(low)
	-- variantes d'une instance generique
	for slot = 1, 2 do
		local key = (slot == 1) and "i1" or "i2"
		local ix = P[key]
		if ix == IX_STRAT then
			if FL.live and FL.ud then
				P[key] = IX_STRATL
				addInst(IX_STRATUD)
			elseif FL.live then P[key] = IX_STRATL
			elseif FL.ud then P[key] = IX_STRATUD end
		elseif ix == IX_SM then
			if FL.gy then P[key] = IX_SMGY
			elseif FL.lib then P[key] = IX_SMLIB
			elseif FL.arm then P[key] = IX_SMARM
			elseif FL.cath then P[key] = IX_SMCATH end
		elseif ix == IX_AQ40 and FL.aq and FL.w20 then
			P[key] = IX_AQ20
		elseif ix == IX_DM and FL.dm and P.lv and P.lv >= 56 then
			P[key] = IX_DIRE
		end
	end
	if P.i1 == nil and (sfind(norm, " quest", 1, true) or sfind(norm, " quete", 1, true)) then P.i1 = IX_QUEST end
	-- type
	if sale and not (xlfm or xlfg or phrG or phrM) then return nil, "sale" end
	if guild and not (xlfm or xlfg or phrG or phrM) then return nil, "guild" end
	local hasInst = P.i1 ~= nil
	local kind = nil
	if xlfm then kind = "lfm"
	elseif xlfg or phrG then kind = "lfg"
	elseif phrM then kind = "lfm"
	elseif roleCue or roleNeed or (plNeed > 0 and hasInst) then kind = "lfm"
	elseif (cueI > 0 and (grp or hasInst)) or (dispo and (roleSeen or hasInst)) then kind = "lfg"
	end
	if not kind then return nil, "none" end
	if P.places == 0 and plNeed > 0 then P.places = plNeed end
	if kind == "lfm" and P.places == 0 then
		local sum = P.tank + P.heal + P.dps
		if sum >= 1 and sum <= 39 then P.places = sum end
	end
	if kind == "lfg" and not P.lv and lvlCand then P.lv = lvlCand end
	if not (hasInst or roleSeen or P.places > 0) then return nil, "noise" end
	P.kind = kind
	return kind
end

-- ================================================================ reglages derives : ignores, alertes
local function split(s, sep, out)
	local n, pos = 0, 1
	local len = slen(s)
	while pos <= len + 1 do
		local e = sfind(s, sep, pos, true)
		if not e then e = len + 1 end
		n = n + 1
		out[n] = ssub(s, pos, e - 1)
		pos = e + 1
	end
	return n
end

local function clean(s)
	s = sgsub(s or "", "[,;~|=:]", " ")
	return s
end

local TMP = {}
local TMP2 = {}

function M.LoadIgnores()
	for k, _ in pairs(M.ign) do M.ign[k] = nil end
	M.nign = 0
	local s = C.Get("finder.ignored") or ""
	if s == "" then return end
	local n = split(s, ";", TMP)
	for i = 1, n do
		local nm = TMP[i]
		if nm ~= "" and not M.ign[slower(nm)] then
			M.ign[slower(nm)] = nm
			M.nign = M.nign + 1
		end
	end
end

function M.IgnoreString()
	local out = ""
	for _, nm in pairs(M.ign) do
		out = (out == "") and nm or (out .. ";" .. nm)
	end
	return out
end

function M.Ignore(name)
	if type(name) ~= "string" or name == "" then return false end
	local lo = slower(name)
	if M.ign[lo] then return false end
	if M.nign >= MAXIGN then
		SUI.Print(L("msg.finder.ign.full", MAXIGN))
		return false
	end
	M.ign[lo] = name
	M.nign = M.nign + 1
	C.SetBase("finder.ignored", M.IgnoreString())
	M.Changed()
	return true
end

function M.Unignore(name)
	local lo = slower(name or "")
	if not M.ign[lo] then return false end
	M.ign[lo] = nil
	M.nign = M.nign - 1
	C.SetBase("finder.ignored", M.IgnoreString())
	M.Changed()
	return true
end

-- Alerte : { on, ix (index d'instance, 0 = toutes, -1 = tous les donjons, -2 = tous les raids), role ("*", tank, heal, dps), kind ("*", lfm, lfg), text }
-- Serialisation : "on,cle,role,genre,texte" separees par ';' (cle : '*' toutes, '*d' donjons, '*r' raids, ou cle d'instance).
local function ixOfKey(k)
	if k == "*" then return 0 end
	if k == "*d" then return -1 end
	if k == "*r" then return -2 end
	return IXKEY[k]
end

local function keyOfIx(ix)
	if ix == 0 then return "*" end
	if ix == -1 then return "*d" end
	if ix == -2 then return "*r" end
	return INST[ix] and INST[ix][1] or "*"
end
M.KeyOfIx = keyOfIx

function M.LoadAlerts()
	local old = M.alerts
	local keep = {}
	for i = 1, M.nalerts do keep[i] = old[i] end
	M.nalerts = 0
	local s = C.Get("finder.alerts") or ""
	if s == "" then return end
	local n = split(s, ";", TMP)
	for i = 1, n do
		if M.nalerts < MAXALERTS and TMP[i] ~= "" then
			local fields = split(TMP[i], ",", TMP2)
			if fields >= 4 then
				local ix = ixOfKey(TMP2[2])
				local role, kind = TMP2[3], TMP2[4]
				if ix and (role == "*" or role == "tank" or role == "heal" or role == "dps") and (kind == "*" or kind == "lfm" or kind == "lfg") then
					local a = keep[M.nalerts + 1]
					if not a then a = {} end
					a.on = (TMP2[1] == "1")
					a.ix, a.role, a.kind = ix, role, kind
					a.text = slower(TMP2[5] or "")
					a.last = a.last or -1000
					M.nalerts = M.nalerts + 1
					M.alerts[M.nalerts] = a
				end
			end
		end
	end
	for i = M.nalerts + 1, getn(M.alerts) do M.alerts[i] = nil end
end

function M.AlertString()
	local out = ""
	for i = 1, M.nalerts do
		local a = M.alerts[i]
		local item = (a.on and "1" or "0") .. "," .. keyOfIx(a.ix) .. "," .. a.role .. "," .. a.kind .. "," .. clean(a.text)
		out = (out == "") and item or (out .. ";" .. item)
	end
	return out
end

function M.SaveAlerts()
	C.SetBase("finder.alerts", M.AlertString())
end

function M.AlertSame(a, ix, role, kind, text)
	return a.ix == ix and a.role == role and a.kind == kind and a.text == text
end

-- Cree une alerte (retourne true, ou false + cle de raison).
function M.AddAlert(ix, role, kind, text)
	text = slower(clean(text))
	if ix == 0 and role == "*" and kind == "*" and text == "" then return false, "empty" end
	for i = 1, M.nalerts do
		if M.AlertSame(M.alerts[i], ix, role, kind, text) then return false, "dup" end
	end
	if M.nalerts >= MAXALERTS then return false, "full" end
	local a = { on = true, ix = ix, role = role, kind = kind, text = text, last = -1000 }
	M.nalerts = M.nalerts + 1
	M.alerts[M.nalerts] = a
	M.SaveAlerts()
	M.Sync()
	M.UpdateFooter()
	return true
end

function M.RemoveAlert(n)
	if n < 1 or n > M.nalerts then return false end
	tremove(M.alerts, n)
	M.nalerts = M.nalerts - 1
	M.SaveAlerts()
	M.Sync()
	M.UpdateFooter()
	return true
end

function M.ToggleAlert(n)
	local a = M.alerts[n]
	if not a or n > M.nalerts then return false end
	a.on = not a.on
	M.SaveAlerts()
	M.Sync()
	M.UpdateFooter()
	return a.on
end

-- ================================================================ noms et textes
function M.InstName(ix)
	local row = INST[ix or 0]
	if not row then return L("msg.finder.inst.none") end
	if SUI.locale == "fr" then return row[2] end
	return row[3]
end

function M.InstShort(ix)
	local row = INST[ix or 0]
	return row and row[4] or "?"
end

function M.FilterInstName(ix)
	if ix == 0 then return L("msg.finder.inst.all") end
	if ix == -1 then return L("msg.finder.inst.dungeons") end
	if ix == -2 then return L("msg.finder.inst.raids") end
	return M.InstName(ix)
end

local function ageText(sec)
	if sec < 0 then sec = 0 end
	if sec < 60 then return L("msg.finder.age.s", floor(sec)) end
	return L("msg.finder.age.m", floor(sec / 60))
end
M.AgeText = ageText

function M.RolesText(r)
	local out = ""
	local names = { "tank", "heal", "dps" }
	for i = 1, 3 do
		local role = names[i]
		local n = r[role]
		if n > 0 then
			local piece = L("msg.finder.role." .. role)
			if r.kind == "lfm" then piece = piece .. " x" .. n end
			out = (out == "") and piece or (out .. "  " .. piece)
		end
	end
	return out
end

function M.InfoText(r)
	local out = M.RolesText(r)
	local function add(s) out = (out == "") and s or (out .. "  -  " .. s) end
	if r.kind == "lfm" and r.places > 0 then add(L("msg.finder.places", r.places)) end
	if r.lv then add(L(r.kind == "lfm" and "msg.finder.lv.min" or "msg.finder.lv.is", r.lv)) end
	if r.gs > 0 then add(L("msg.finder.tag.gs", r.gs)) end
	if r.loot then add(L("choice.finder.loot." .. r.loot)) end
	if r.price > 0 then add(L("msg.finder.price", r.price)) end
	if r.res then add(L("msg.finder.tag.res")) end
	if r.flask then add(L("msg.finder.tag.flask")) end
	if r.exp then add(L("msg.finder.tag.exp")) end
	if r.voc then add(L("msg.finder.tag.voc")) end
	return out
end

local function chanShort(chan)
	if type(chan) ~= "string" then return "" end
	local d = sfind(chan, ". ", 1, true)
	if d and d <= 3 then chan = ssub(chan, d + 2) end
	if slen(chan) > 14 then chan = ssub(chan, 1, 14) end
	return chan
end
M.ChanShort = chanShort

-- ================================================================ anneau d'annonces
function M.AllocRing()
	if M.ringReady then return end
	for i = 1, MAXRING do
		if not M.ring[i] then M.ring[i] = { used = false, a = "", al = "", txt = "", low = "", kind = "lfm", tank = 0, heal = 0, dps = 0,
			places = 0, gs = 0, price = 0, n = 1, t = 0, t0 = 0, chan = "", id = 0 } end
	end
	M.ringReady = true
end

function M.SetCap()
	local cap = C.Get("finder.maxads") or MAXRING
	if cap > MAXRING then cap = MAXRING end
	if cap < 20 then cap = 20 end
	if cap ~= M.cap then
		for i = cap + 1, MAXRING do
			local r = M.ring[i]
			if r then r.used = false end
		end
		M.cap = cap
		if M.head > cap then M.head = 0 end
	end
end

function M.Expiry()
	return (C.Get("finder.expire") or 15) * 60
end

local function fillRec(r, text, author, chan, now)
	r.a = author
	r.al = slower(author)
	r.txt = text
	r.low = slower(text)
	r.kind = P.kind
	r.i1, r.i2 = P.i1, P.i2
	r.tank, r.heal, r.dps, r.places = P.tank, P.heal, P.dps, P.places
	r.lv, r.gs, r.loot, r.price = P.lv, P.gs, P.loot, P.price
	r.flask, r.res, r.exp, r.voc = P.flask, P.res, P.exp, P.voc
	r.chan = chan
	r.t = now
end

function M.NextSlot()
	local h = M.head + 1
	if h > M.cap then h = 1 end
	M.head = h
	return M.ring[h]
end

function M.ChanAllowed(chan)
	if type(chan) ~= "string" then return true end
	local ok = M.chanOK[chan]
	if ok ~= nil then return ok end
	local lo = slower(chan)
	ok = true
	if sfind(lo, "guildrecruit", 1, true) or sfind(lo, "defense", 1, true) or sfind(lo, "recrutement", 1, true) then ok = false end
	local skip = C.Get("finder.chanskip") or ""
	if ok and skip ~= "" then
		local n = split(skip, ";", TMP)
		for i = 1, n do
			if TMP[i] ~= "" and sfind(lo, slower(TMP[i]), 1, true) then ok = false end
		end
	end
	M.chanOK[chan] = ok
	return ok
end

-- Traite une annonce. src : "c" canal, "y" cri, "s" dire. Retourne l'enregistrement ou nil.
function M.Ingest(text, author, chan, src)
	if not M.ringReady then return nil end
	local st = M.stat
	st.seen = st.seen + 1
	if type(text) ~= "string" or type(author) ~= "string" or author == "" then return nil end
	local len = slen(text)
	if len < 5 or len > 255 then return nil end
	if author == M.me then return nil end
	if M.nign > 0 and M.ign[slower(author)] then
		st.ign = st.ign + 1
		return nil
	end
	local now = GetTime()
	local exp = M.Expiry()
	local ring, cap = M.ring, M.cap
	for i = 1, cap do
		local r = ring[i]
		if r.used and r.a == author and r.txt == text then
			st.dup = st.dup + 1
			local stale = (now - r.t) > exp
			r.t = now
			r.n = r.n + 1
			if stale then
				r.t0 = now
				r.n = 1
				M.CheckAlerts(r)
			end
			M.dirty = true
			return r
		end
	end
	local kind, why = M.Parse(text)
	if not kind then
		if why == "sale" then st.sale = st.sale + 1 elseif why == "guild" then st.guild = st.guild + 1
		elseif why == "noise" then st.noise = st.noise + 1 end
		return nil
	end
	local rec = nil
	for i = 1, cap do
		local r = ring[i]
		if r.used and r.a == author and r.kind == kind and r.i1 == P.i1 and r.i2 == P.i2 then
			rec = r
			break
		end
	end
	local isNew = false
	if rec then
		local stale = (now - rec.t) > exp
		local n = rec.n + 1
		fillRec(rec, text, author, chan, now)
		rec.n = n
		st.dup = st.dup + 1
		if stale then
			rec.t0, rec.n = now, 1
			isNew = true
		end
	else
		rec = M.NextSlot()
		M.seq = M.seq + 1
		fillRec(rec, text, author, chan, now)
		rec.used = true
		rec.id = M.seq
		rec.n = 1
		rec.t0 = now
		rec.src = src
		isNew = true
	end
	st.kept = st.kept + 1
	M.dirty = true
	if isNew then M.CheckAlerts(rec) end
	return rec
end

function M.Purge(now)
	local exp = M.Expiry()
	local removed = 0
	for i = 1, MAXRING do
		local r = M.ring[i]
		if r and r.used and (now - r.t) > exp then
			r.used = false
			removed = removed + 1
		end
	end
	if removed > 0 then M.dirty = true end
	return removed
end

function M.Clear()
	local n = 0
	for i = 1, MAXRING do
		local r = M.ring[i]
		if r and r.used then
			r.used = false
			n = n + 1
		end
	end
	M.dirty = true
	return n
end

function M.Count()
	local n = 0
	local now = GetTime()
	local exp = M.Expiry()
	for i = 1, M.cap do
		local r = M.ring[i]
		if r and r.used and (now - r.t) <= exp and not M.ign[r.al] then n = n + 1 end
	end
	return n
end

-- ================================================================ alertes
function M.AlertMatch(a, r)
	if a.kind ~= "*" and r.kind ~= a.kind then return false end
	if a.role ~= "*" and r[a.role] <= 0 then return false end
	local ix = a.ix
	if ix ~= 0 then
		local g1 = r.i1 and INST[r.i1]
		local g2 = r.i2 and INST[r.i2]
		if ix > 0 then
			if not instIs(r, ix) then return false end
		else
			local want = (ix == -1) and "d" or "r"
			if not ((g1 and g1[5] == want) or (g2 and g2[5] == want)) then return false end
		end
	end
	if a.text ~= "" and not sfind(r.low, a.text, 1, true) and not sfind(r.al, a.text, 1, true) then return false end
	return true
end

function M.CheckAlerts(r)
	for i = 1, M.nalerts do
		local a = M.alerts[i]
		if a.on and M.AlertMatch(a, r) then
			local now = GetTime()
			if now - a.last >= 8 then
				a.last = now
				M.Fire(a, r)
				return true
			end
		end
	end
	return false
end

local SOUNDS = { tell = "TellMessage", raid = "RaidWarning", quest = "QUESTADDED" }

function M.PlayAlert()
	local s = SOUNDS[C.Get("finder.sound") or "tell"]
	if not s then return end
	local f = getglobal("PlaySound")
	if type(f) == "function" then pcall(f, s) end
end

function M.Fire(a, r)
	M.stat.alerts = M.stat.alerts + 1
	M.hits = M.hits + 1
	M.PlayAlert()
	if C.Get("finder.alertprint") then
		local link = "|Hplayer:" .. r.a .. "|h[" .. r.a .. "]|h"
		local what = M.InstName(r.i1)
		local info = M.RolesText(r)
		SUI.Print(L("msg.finder.alert", L("msg.finder.kind." .. r.kind), what, link, info))
	end
	M.UpdateAccess()
	M.dirty = true
end

function M.AlertText(a)
	local parts = M.FilterInstName(a.ix)
	if a.role ~= "*" then parts = parts .. " / " .. L("msg.finder.role." .. a.role) end
	if a.kind ~= "*" then parts = parts .. " / " .. L("msg.finder.kind." .. a.kind) end
	if a.text ~= "" then parts = parts .. " / \"" .. a.text .. "\"" end
	return parts
end

-- ================================================================ ecoute
local function gf(name)
	local f = getglobal(name)
	if type(f) == "function" then return f end
	return nil
end

local EVENTS = { { "CHAT_MSG_CHANNEL", "finder.src.channel", "c" }, { "CHAT_MSG_YELL", "finder.src.yell", "y" },
	{ "CHAT_MSG_SAY", "finder.src.say", "s" } }

function M.OnChat(ev, a1, a2, a3, a4)
	if not M.listening then return end
	if ev == "CHAT_MSG_CHANNEL" then
		if not M.ChanAllowed(a4) then return end
		M.Ingest(a1, a2, chanShort(a4), "c")
	elseif ev == "CHAT_MSG_YELL" then
		M.Ingest(a1, a2, L("msg.finder.src.yell"), "y")
	else
		M.Ingest(a1, a2, L("msg.finder.src.say"), "s")
	end
end

function M.WantListen()
	if not M.on then return false end
	if M.win and M.win:IsShown() then return true end
	if C.Get("finder.listen") == "always" then return true end
	for i = 1, M.nalerts do
		if M.alerts[i].on then return true end
	end
	return false
end

function M.UIOpen()
	return (M.win and M.win:IsShown()) or (M.postwin and M.postwin:IsShown())
end

-- Met l'ecoute et la minuterie en accord avec la situation (fenetre, alertes, reglage).
function M.Sync()
	local want = M.WantListen()
	if want and not M.ringReady then SUI.WhenSafe(M.AllocRing) end
	M.listening = want
	for i = 1, getn(EVENTS) do
		local e = EVENTS[i]
		local need = want and C.Get(e[2]) and true or false
		if need and not M.reg[e[1]] then
			SUI.On(e[1], M.OnChat)
			M.reg[e[1]] = true
		elseif not need and M.reg[e[1]] then
			SUI.Off(e[1], M.OnChat)
			M.reg[e[1]] = false
		end
	end
	local tick = M.on and M.UIOpen() and true or false
	if tick and not M.task then
		M.task = SUI.Every(1, M.Tick, "finder.tick", true)
	elseif not tick and M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
end

function M.Tick()
	local now = GetTime()
	M.tickN = (M.tickN or 0) + 1
	if M.postwin and M.postwin:IsShown() then M.PostCool() end
	if M.win and M.win:IsShown() then
		if M.LevelsStale(M.win) then M.SyncLevels(M.win) end
		if M.postwin and M.postwin:IsShown() and M.LevelsStale(M.postwin) then M.SyncLevels(M.postwin) end
		if M.tickN >= 10 then
			M.tickN = 0
			M.Purge(now)
		end
		if M.dirty or now - M.lastRender >= 5 then M.Render() end
	end
end

-- ================================================================ vue : filtre, tri, regroupement
local AUTH = {}

function M.FitsMe(r)
	local me = UnitLevel("player") or 60
	local g = r.i1 and INST[r.i1]
	if g then
		if g[5] == "r" then
			if me < 58 then return false end
		elseif g[5] == "d" then
			if me < g[6] - 2 or me > g[7] + 6 then return false end
		end
	end
	if r.lv then
		if r.kind == "lfm" then
			if r.lv > me then return false end
		else
			if r.lv < me - 6 or r.lv > me + 6 then return false end
		end
	end
	return true
end

function M.Matches(r)
	local f = M.f
	if f.kind ~= "all" and r.kind ~= f.kind then return false end
	if f.inst ~= 0 then
		if f.inst > 0 then
			if not instIs(r, f.inst) then return false end
		else
			local want = (f.inst == -1) and "d" or "r"
			local g1 = r.i1 and INST[r.i1]
			local g2 = r.i2 and INST[r.i2]
			if not ((g1 and g1[5] == want) or (g2 and g2[5] == want)) then return false end
		end
	end
	if f.tank or f.heal or f.dps then
		if not ((f.tank and r.tank > 0) or (f.heal and r.heal > 0) or (f.dps and r.dps > 0)) then return false end
	end
	if f.mine and not M.FitsMe(r) then return false end
	if f.q ~= "" then
		local hit = sfind(r.low, f.q, 1, true) or sfind(r.al, f.q, 1, true)
		if not hit then
			for k = 1, 2 do
				local ix = (k == 1) and r.i1 or r.i2
				local g = ix and INST[ix]
				if g and (sfind(slower(g[2]), f.q, 1, true) or sfind(slower(g[3]), f.q, 1, true) or sfind(slower(g[4]), f.q, 1, true)) then hit = true end
			end
		end
		if not hit then return false end
	end
	return true
end

local function lowOf(r)
	local g = r.i1 and INST[r.i1]
	if g then return g[6] * 100 + r.i1 end
	return 9900
end

local function cmpNew(a, b)
	if a.t ~= b.t then return a.t > b.t end
	return a.id > b.id
end

local function cmpLevel(a, b)
	local la, lb = lowOf(a), lowOf(b)
	if la ~= lb then return la < lb end
	return cmpNew(a, b)
end

local function cmpPlaces(a, b)
	if a.places ~= b.places then return a.places > b.places end
	return cmpNew(a, b)
end

-- Remplit M.view (annonces affichees). Retourne le nombre d'annonces vivantes (avant filtres), et le nombre masque par les filtres.
function M.BuildView()
	local now = GetTime()
	local exp = M.Expiry()
	local view, n = M.view, 0
	local alive = 0
	local group = C.Get("finder.group")
	if group then
		for k, _ in pairs(AUTH) do AUTH[k] = nil end
	end
	for i = 1, M.cap do
		local r = M.ring[i]
		if r and r.used and (now - r.t) <= exp and not M.ign[r.al] then
			alive = alive + 1
			if M.Matches(r) then
				if group then
					local best = AUTH[r.al]
					if not best then
						AUTH[r.al] = r
						r.more = 0
					else
						best.more = best.more + 1
						if r.t > best.t then
							r.more = best.more
							AUTH[r.al] = r
						end
					end
				else
					n = n + 1
					view[n] = r
					r.more = 0
				end
			end
		end
	end
	if group then
		for _, r in pairs(AUTH) do
			n = n + 1
			view[n] = r
		end
	end
	for i = n + 1, M.nview do view[i] = nil end
	M.nview = n
	local sort = C.Get("finder.sort") or "new"
	local cmp = cmpNew
	if sort == "level" then cmp = cmpLevel elseif sort == "places" then cmp = cmpPlaces end
	if n > 1 then table.sort(view, cmp) end
	return alive
end

-- Nombre d'annonces vivantes par instance (pour le selecteur) : tableau reutilise.
local COUNTS = {}
function M.CountByInst()
	for i = 1, NI do COUNTS[i] = 0 end
	local now = GetTime()
	local exp = M.Expiry()
	for i = 1, M.cap do
		local r = M.ring[i]
		if r and r.used and (now - r.t) <= exp and not M.ign[r.al] then
			if r.i1 then
				COUNTS[r.i1] = COUNTS[r.i1] + 1
				if PARENT[r.i1] then COUNTS[PARENT[r.i1]] = COUNTS[PARENT[r.i1]] + 1 end
			end
			if r.i2 then
				COUNTS[r.i2] = COUNTS[r.i2] + 1
				if PARENT[r.i2] then COUNTS[PARENT[r.i2]] = COUNTS[PARENT[r.i2]] + 1 end
			end
		end
	end
	return COUNTS
end

-- ================================================================ actions sur une annonce
function M.CanInvite()
	local gr, gp = gf("GetNumRaidMembers"), gf("GetNumPartyMembers")
	local nr = gr and gr() or 0
	local np = gp and gp() or 0
	if nr and nr > 0 then
		local a, b = gf("IsRaidLeader"), gf("IsRaidOfficer")
		return ((a and a()) or (b and b())) and true or false
	end
	if np and np > 0 then
		local pl = gf("IsPartyLeader")
		return (pl and pl()) and true or false
	end
	return true
end

function M.Invite(rec)
	if not rec or not rec.a then return false end
	if not M.CanInvite() then
		SUI.Print(L("msg.finder.invite.noright"))
		return false
	end
	local f = gf("InviteByName")
	if not f then return false end
	f(rec.a)
	SUI.Print(L("msg.finder.invited", rec.a))
	return true
end

local function subst(text, key, val)
	local s, e = sfind(text, key, 1, true)
	while s do
		text = ssub(text, 1, s - 1) .. val .. ssub(text, e + 1)
		s, e = sfind(text, key, s + slen(val), true)
	end
	return text
end

function M.QuickText(rec)
	local t = C.Get("finder.quick") or ""
	if t == "" then t = L("msg.finder.quick.default") end
	local cn = gf("UnitClass")
	local class = cn and cn("player") or "?"
	t = subst(t, "{inst}", M.InstShort(rec.i1))
	t = subst(t, "{class}", class or "?")
	t = subst(t, "{lvl}", sformat("%d", UnitLevel("player") or 0))
	t = subst(t, "{name}", rec.a)
	if slen(t) > 255 then t = ssub(t, 1, 255) end
	return t
end

function M.Whisper(rec, quick)
	if not rec or not rec.a then return false end
	if quick then
		SendChatMessage(M.QuickText(rec), "WHISPER", nil, rec.a)
		SUI.Print(L("msg.finder.quick.sent", rec.a))
		return true
	end
	local msg = SUI.Messages
	if msg and msg.on and msg.OpenByName then
		if pcall(msg.OpenByName, rec.a, true) then return true end
	end
	local f = gf("ChatFrame_SendTell")
	if f then
		f(rec.a)
		return true
	end
	return false
end

-- ================================================================ aides d'interface
local function put(fs, s)
	if fs.cur ~= s then
		fs.cur = s
		fs:SetText(s)
	end
end

local function track(owner, fr, off)
	local k = owner.kids
	k[getn(k) + 1] = fr
	fr.loff = off
	return fr
end

function M.SyncLevels(owner)
	local base = owner:GetFrameLevel() or 0
	local n = 0
	local k = owner.kids
	for i = 1, getn(k) do
		local fr = k[i]
		local want = base + fr.loff
		if fr:GetFrameLevel() ~= want then
			fr:SetFrameLevel(want)
			n = n + 1
		end
	end
	owner.baseLvl = base
	return n
end

function M.LevelsStale(owner)
	local base = owner:GetFrameLevel() or 0
	if owner.baseLvl ~= base then return true end
	local k = owner.kids
	local nk = getn(k)
	if nk > 0 then
		if k[1]:GetFrameLevel() ~= base + k[1].loff then return true end
		if k[nk]:GetFrameLevel() ~= base + k[nk].loff then return true end
	end
	return false
end

function M.Tip(owner, title, l1, l2, l3)
	if not GameTooltip then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, T.c.text[1], T.c.text[2], T.c.text[3])
	local d = T.c.dim
	if l1 and l1 ~= "" then GameTooltip:AddLine(l1, d[1], d[2], d[3], 1) end
	if l2 and l2 ~= "" then GameTooltip:AddLine(l2, d[1], d[2], d[3], 1) end
	if l3 and l3 ~= "" then GameTooltip:AddLine(l3, d[1], d[2], d[3], 1) end
	GameTooltip:Show()
end

function M.TipHide()
	if GameTooltip then GameTooltip:Hide() end
end

local function btnEnter()
	local b = this
	if not b.disabled then
		local r, g, bl = T.Accent()
		b:SetBackdropBorderColor(r, g, bl, 1)
	end
	if b.tipT then
		local d = b.tipD
		if b.tipFn then d = b.tipFn(b) end
		M.Tip(b, L(b.tipT), d and L(d) or nil, b.tipE and L(b.tipE) or nil)
	end
end

local function btnLeave()
	local b = this
	if b.selected then
		local r, g, bl = T.Accent()
		b:SetBackdropBorderColor(r, g, bl, 1)
	else
		local c = T.c.border
		b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	end
	M.TipHide()
end

-- Bouton du theme avec infobulle (cles de traduction titre / detail / extra).
local function mkBtn(owner, parent, label, w, h, onclick, tipT, tipD, tipE, off)
	local b = T.Button(parent, label, w, h, onclick)
	b.tipT, b.tipD, b.tipE = tipT, tipD, tipE
	b:SetScript("OnEnter", btnEnter)
	b:SetScript("OnLeave", btnLeave)
	if owner then track(owner, b, off or 4) end
	return b
end

local function setDisabled(b, off)
	b.disabled = off and true or false
	if b.label then
		local c = off and T.c.dim or T.c.text
		b.label:SetTextColor(c[1], c[2], c[3], 1)
	end
end

local function kindColor(kind)
	local sch = C.Get("finder.colors") or "kind"
	if sch == "accent" then return T.Accent() end
	if sch == "mono" then
		local c = T.c.text
		return c[1], c[2], c[3]
	end
	local c = (kind == "lfg") and T.c.warn or T.c.good
	return c[1], c[2], c[3]
end

-- ================================================================ fenetre liste generique (selecteur, alertes, ignores)
function M.NewList(name, title, w, nrows)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetWidth(w)
	f:SetHeight(32 + nrows * 20 + 30)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:Hide()
	f.kids = {}
	f.nrows = nrows
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
	f.title:SetWidth(w - 40)
	f.title:SetText(title)
	f.close = mkBtn(f, f, "x", 18, 18, function() f:Hide() end, "mod.finder.btn.close", nil, nil, 4)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	f.empty = T.Text(f, 11, T.c.dim, "LEFT")
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
	f.empty:SetWidth(w - 20)
	f.items = {}
	for k = 1, 80 do f.items[k] = { txt = "", col = nil, pick = nil, del = nil, tipT = nil } end
	f.n = 0
	f.off = 0
	f.rows = {}
	for k = 1, nrows do
		local b = mkBtn(f, f, "", w - 40, 18, M.ListPick, nil, nil, nil, 4)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28 - (k - 1) * 20)
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
		b.label:SetWidth(w - 54)
		b.label:SetJustifyH("LEFT")
		b.idx = k
		b.lw = f
		local d = mkBtn(f, f, "x", 18, 18, M.ListDel, "mod.finder.list.del", nil, nil, 4)
		d:SetPoint("LEFT", b, "RIGHT", 2, 0)
		d.idx = k
		d.lw = f
		b.dbtn = d
		f.rows[k] = b
	end
	f.up = mkBtn(f, f, "^", 18, 14, function() M.ListScroll(f, -3) end, "mod.finder.list.up", nil, nil, 4)
	f.up:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 6)
	f.down = mkBtn(f, f, "v", 18, 14, function() M.ListScroll(f, 3) end, "mod.finder.list.down", nil, nil, 4)
	f.down:SetPoint("LEFT", f.up, "RIGHT", 2, 0)
	f.foot = T.Text(f, 10, T.c.dim, "LEFT")
	f.foot:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	f.foot:SetWidth(w - 80)
	f:SetScript("OnMouseWheel", function()
		local fr = this
		M.ListScroll(fr, arg1 > 0 and -3 or 3)
	end)
	f:SetScript("OnShow", function() M.SyncLevels(this) end)
	return f
end

function M.ListPick()
	local b = this
	local lw, idx = b.lw, b.idx
	local it = lw.items[lw.off + idx]
	if lw.off + idx > lw.n or not it or not it.pick then return end
	it.pick(it)
end

function M.ListDel()
	local b = this
	local lw, idx = b.lw, b.idx
	local it = lw.items[lw.off + idx]
	if lw.off + idx > lw.n or not it or not it.del then return end
	it.del(it)
end

function M.ListScroll(lw, d)
	local maxoff = lw.n - lw.nrows
	if maxoff < 0 then maxoff = 0 end
	local o = lw.off + d
	if o < 0 then o = 0 end
	if o > maxoff then o = maxoff end
	if o ~= lw.off then
		lw.off = o
		M.ListPaint(lw)
	end
end

function M.ListPaint(lw)
	for k = 1, lw.nrows do
		local b = lw.rows[k]
		local it = lw.items[lw.off + k]
		if lw.off + k <= lw.n and it then
			b:Show()
			put(b.label, it.txt)
			local c = it.col or T.c.text
			b.label:SetTextColor(c[1], c[2], c[3], 1)
			T.SetSelected(b, it.sel)
			if it.del then b.dbtn:Show() else b.dbtn:Hide() end
		else
			b:Hide()
			b.dbtn:Hide()
		end
	end
	if lw.n == 0 then lw.empty:Show() else lw.empty:Hide() end
end

-- Remplit l'element k (1..80) : pick(it) au clic, del(it) pour la croix (nil : pas de croix).
function M.ListSet(lw, k, txt, col, sel, pick, del, data)
	local it = lw.items[k]
	it.txt, it.col, it.sel, it.pick, it.del, it.data = txt, col, sel, pick, del, data
	if k > lw.n then lw.n = k end
end

function M.ListBegin(lw)
	lw.n = 0
	lw.off = 0
end

-- ================================================================ fenetre principale
local function rowClick(b, button)
	local rec = b.rec
	if not rec then return end
	if button == "RightButton" then
		if rec.kind == "lfg" then M.Invite(rec) else M.Whisper(rec, false) end
		return
	end
	local sh = gf("IsShiftKeyDown")
	M.Whisper(rec, sh and sh() and true or false)
end

local function rowEnter()
	local b = this
	local win = M.win
	if win and M.LevelsStale(win) then M.SyncLevels(win) end
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
	local rec = b.rec
	if rec and GameTooltip then
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip:SetText(M.InstName(rec.i1), T.c.text[1], T.c.text[2], T.c.text[3])
		local d = T.c.dim
		GameTooltip:AddLine(L("msg.finder.tip.by", rec.a, chanShort(rec.chan)), d[1], d[2], d[3], 1)
		GameTooltip:AddLine(rec.txt, T.c.text[1], T.c.text[2], T.c.text[3], 1)
		if rec.n > 1 then GameTooltip:AddLine(L("msg.finder.tip.repeat", rec.n), d[1], d[2], d[3], 1) end
		if rec.more and rec.more > 0 then GameTooltip:AddLine(L("msg.finder.tip.more", rec.more), d[1], d[2], d[3], 1) end
		GameTooltip:AddLine(L("msg.finder.tip.row"), d[1], d[2], d[3], 1)
		GameTooltip:Show()
	end
end

local function rowLeave()
	local c = T.c.border
	this:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
	M.TipHide()
end

local function rowWheel()
	M.Scroll(arg1 > 0 and -1 or 1)
end

local function actWhisper(b)
	local sh = gf("IsShiftKeyDown")
	M.Whisper(b:GetParent().rec, sh and sh() and true or false)
end

local function actInvite(b)
	M.Invite(b:GetParent().rec)
end

local function actIgnore(b)
	local rec = b:GetParent().rec
	if rec then M.Ignore(rec.a) end
end

function M.BuildRow(i)
	local f = M.win
	local r = mkBtn(f, f, "", WIN_W - 36, 50, rowClick, nil, nil, nil, 2)
	r:SetScript("OnEnter", rowEnter)
	r:SetScript("OnLeave", rowLeave)
	r:EnableMouseWheel(true)
	r:SetScript("OnMouseWheel", rowWheel)
	r.idx = i
	r.label:Hide()
	r.stripe = r:CreateTexture(nil, "ARTWORK")
	r.stripe:SetTexture(T.tex.white)
	r.badge = T.Text(r, 11, T.c.text, "LEFT")
	r.inst = T.Text(r, 12, T.c.text, "LEFT")
	r.age = T.Text(r, 10, T.c.dim, "RIGHT")
	r.info = T.Text(r, 10, T.c.dim, "LEFT")
	r.auth = T.Text(r, 11, T.c.text, "LEFT")
	r.snip = T.Text(r, 10, T.c.dim, "LEFT")
	r.bW = mkBtn(f, r, L("mod.finder.act.whisper"), 60, 14, actWhisper, "mod.finder.act.whisper.t", "mod.finder.act.whisper.d", "mod.finder.act.whisper.e", 5)
	r.bI = mkBtn(f, r, L("mod.finder.act.invite"), 60, 14, actInvite, "mod.finder.act.invite.t", "mod.finder.act.invite.d", "mod.finder.act.invite.e", 5)
	r.bX = mkBtn(f, r, L("mod.finder.act.ignore"), 60, 14, actIgnore, "mod.finder.act.ignore.t", "mod.finder.act.ignore.d", nil, 5)
	r.bW.label:SetWidth(56)
	r.bI.label:SetWidth(56)
	r.bX.label:SetWidth(56)
	M.rows[i] = r
	return r
end

-- Place les elements d'une carte selon l'aspect choisi (cartes sur 3 lignes ou liste compacte sur 1 ligne).
function M.LayoutRow(r, compact)
	local rh = compact and 24 or 50
	r:SetHeight(rh)
	r.stripe:ClearAllPoints()
	r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
	r.stripe:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 1, 1)
	r.stripe:SetWidth(3)
	r.badge:ClearAllPoints()
	r.inst:ClearAllPoints()
	r.age:ClearAllPoints()
	r.info:ClearAllPoints()
	r.auth:ClearAllPoints()
	r.snip:ClearAllPoints()
	r.bW:ClearAllPoints()
	r.bI:ClearAllPoints()
	r.bX:ClearAllPoints()
	r.badge:SetWidth(30)
	if compact then
		r.badge:SetPoint("LEFT", r, "LEFT", 8, 0)
		r.inst:SetPoint("LEFT", r, "LEFT", 40, 0)
		r.inst:SetWidth(130)
		r.info:SetPoint("LEFT", r, "LEFT", 174, 0)
		r.info:SetWidth(170)
		r.auth:SetPoint("LEFT", r, "LEFT", 348, 0)
		r.auth:SetWidth(84)
		r.age:SetPoint("RIGHT", r, "RIGHT", -86, 0)
		r.age:SetWidth(46)
		r.snip:Hide()
		r.bW:SetWidth(24)
		r.bI:SetWidth(24)
		r.bX:SetWidth(24)
		r.bW:SetHeight(16)
		r.bI:SetHeight(16)
		r.bX:SetHeight(16)
		r.bX:SetPoint("RIGHT", r, "RIGHT", -3, 0)
		r.bI:SetPoint("RIGHT", r.bX, "LEFT", -2, 0)
		r.bW:SetPoint("RIGHT", r.bI, "LEFT", -2, 0)
		r.age:SetPoint("RIGHT", r.bW, "LEFT", -4, 0)
	else
		r.badge:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -6)
		r.inst:SetPoint("TOPLEFT", r, "TOPLEFT", 44, -5)
		r.inst:SetWidth(300)
		r.age:SetPoint("TOPRIGHT", r, "TOPRIGHT", -72, -6)
		r.age:SetWidth(60)
		r.info:SetPoint("TOPLEFT", r, "TOPLEFT", 44, -21)
		r.info:SetWidth(WIN_W - 36 - 44 - 76)
		r.info:SetHeight(12)
		r.auth:SetPoint("TOPLEFT", r, "TOPLEFT", 44, -35)
		r.auth:SetWidth(96)
		r.snip:SetPoint("TOPLEFT", r, "TOPLEFT", 144, -36)
		r.snip:SetWidth(WIN_W - 36 - 144 - 76)
		r.snip:SetHeight(12)
		r.snip:Show()
		r.bW:SetWidth(60)
		r.bI:SetWidth(60)
		r.bX:SetWidth(60)
		r.bW:SetHeight(14)
		r.bI:SetHeight(14)
		r.bX:SetHeight(14)
		r.bW:SetPoint("TOPRIGHT", r, "TOPRIGHT", -4, -4)
		r.bI:SetPoint("TOPRIGHT", r, "TOPRIGHT", -4, -20)
		r.bX:SetPoint("TOPRIGHT", r, "TOPRIGHT", -4, -35)
	end
	r.compact = compact
end

function M.RowH()
	return (C.Get("finder.look") == "compact") and 25 or 52
end

function M.NRows()
	local n = C.Get("finder.rows") or 7
	if n < 3 then n = 3 end
	if n > NROWS_MAX then n = NROWS_MAX end
	return n
end

-- Taille de la fenetre et position des rangees selon les reglages (aspect, nombre de lignes, echelle).
function M.ApplyLook()
	local f = M.win
	if not f then return end
	local compact = (C.Get("finder.look") == "compact")
	local rh = M.RowH()
	local nr = M.NRows()
	if compact then nr = nr * 2 end
	if nr > NROWS_MAX then nr = NROWS_MAX end
	if compact and nr < 8 then nr = 8 end
	M.shownRows = nr
	for i = 1, NROWS_MAX do
		local r = M.rows[i]
		if r then
			M.LayoutRow(r, compact)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -86 - (i - 1) * rh)
			if i > nr then r:Hide() end
		end
	end
	f:SetHeight(86 + nr * rh + 4 + 18 + 30)
	f.empty:ClearAllPoints()
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -100)
	f.foot:ClearAllPoints()
	f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -86 - nr * rh - 6)
	f.bPost:ClearAllPoints()
	f.bPost:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	local sc = C.Get("finder.scale") or 1
	f:SetScale(sc)
	if M.postwin then M.postwin:SetScale(sc) end
	if M.lw1 then M.lw1:SetScale(sc) end
	if M.lw2 then M.lw2:SetScale(sc) end
	if M.lw3 then M.lw3:SetScale(sc) end
	if M.helpwin then M.helpwin:SetScale(sc) end
	M.dirty = true
end

function M.Scroll(d)
	M.off = M.off + d
	M.ClampOff()
	M.Render()
end

function M.ClampOff()
	local maxoff = M.nview - (M.shownRows or 7)
	if maxoff < 0 then maxoff = 0 end
	if M.off > maxoff then M.off = maxoff end
	if M.off < 0 then M.off = 0 end
end

function M.Changed()
	M.off = 0
	M.dirty = true
	if M.win and M.win:IsShown() then M.Render() end
end

function M.SetKind(k)
	M.f.kind = k
	M.Changed()
end

function M.SetRole(role)
	M.f[role] = not M.f[role]
	M.Changed()
end

function M.SetMine()
	M.f.mine = not M.f.mine
	M.Changed()
end

function M.SetInst(ix)
	M.f.inst = ix
	M.Changed()
end

function M.ResetFilters()
	local f = M.f
	f.kind, f.inst, f.tank, f.heal, f.dps, f.mine, f.q = "all", 0, false, false, false, false, ""
	if M.win and M.win.search then
		M.settingText = true
		M.win.search:SetText("")
		M.settingText = false
	end
	M.Changed()
end

function M.FilterActive()
	local f = M.f
	return f.kind ~= "all" or f.inst ~= 0 or f.tank or f.heal or f.dps or f.mine or f.q ~= ""
end

local SORTS = { "new", "level", "places" }
function M.CycleSort()
	local cur = C.Get("finder.sort") or "new"
	local nxt = SORTS[1]
	for i = 1, getn(SORTS) do
		if SORTS[i] == cur then nxt = SORTS[SUI.Mod(i, getn(SORTS)) + 1] end
	end
	C.Set("finder.sort", nxt)
	M.Changed()
end

function M.BindRow(r, rec, now)
	r.rec = rec
	local kr, kg, kb = kindColor(rec.kind)
	r.stripe:SetVertexColor(kr, kg, kb, 1)
	if C.Get("finder.stripe") then r.stripe:Show() else r.stripe:Hide() end
	put(r.badge, L("msg.finder.kind." .. rec.kind .. ".badge"))
	r.badge:SetTextColor(kr, kg, kb, 1)
	local ir, ig, ib = T.c.text[1], T.c.text[2], T.c.text[3]
	local g = rec.i1 and INST[rec.i1]
	if g and g[5] == "r" then ir, ig, ib = T.Accent() end
	local nm = M.InstName(rec.i1)
	if rec.i2 then nm = nm .. " + " .. M.InstShort(rec.i2) end
	put(r.inst, nm)
	r.inst:SetTextColor(ir, ig, ib, 1)
	local age = now - rec.t
	local at = ageText(age)
	if rec.n > 1 then at = at .. " x" .. rec.n end
	put(r.age, at)
	local fade = C.Get("finder.fade") and age > M.Expiry() * 0.6
	local ac = fade and T.c.warn or T.c.dim
	r.age:SetTextColor(ac[1], ac[2], ac[3], 1)
	put(r.info, M.InfoText(rec))
	local dim = T.c.dim
	r.info:SetTextColor(dim[1], dim[2], dim[3], 1)
	local who = rec.a
	if rec.more and rec.more > 0 then who = who .. " (+" .. rec.more .. ")" end
	put(r.auth, who)
	local acr, acg, acb = T.Accent()
	r.auth:SetTextColor(acr, acg, acb, 1)
	local sn = chanShort(rec.chan) .. ": " .. rec.txt
	if slen(sn) > 54 then sn = ssub(sn, 1, 51) .. "..." end
	put(r.snip, sn)
	r.snip:SetTextColor(dim[1], dim[2], dim[3], 1)
	local can = M.CanInvite()
	if rec.kind == "lfg" then
		r.bI:Show()
		setDisabled(r.bI, not can)
	else
		r.bI:Hide()
	end
	r:Show()
end

function M.Render()
	local f = M.win
	if not f or not f:IsShown() then return end
	M.dirty = false
	local now = GetTime()
	M.lastRender = now
	if M.LevelsStale(f) then M.SyncLevels(f) end
	local alive = M.BuildView()
	M.ClampOff()
	local nr = M.shownRows or 7
	for i = 1, NROWS_MAX do
		local r = M.rows[i]
		if r then
			local rec = M.view[M.off + i]
			if i <= nr and rec then
				M.BindRow(r, rec, now)
			else
				r.rec = nil
				r:Hide()
			end
		end
	end
	-- messages d'etat
	if M.nview == 0 then
		f.empty:Show()
		if alive == 0 then
			put(f.empty, L(M.listening and "msg.finder.empty" or "msg.finder.paused"))
			f.bReset:Hide()
		else
			put(f.empty, L("msg.finder.nomatch", alive))
			f.bReset:Show()
		end
	else
		f.empty:Hide()
		f.bReset:Hide()
	end
	local first = (M.nview == 0) and 0 or (M.off + 1)
	local last = M.off + nr
	if last > M.nview then last = M.nview end
	local foot = L("msg.finder.status", first, last, M.nview, alive)
	local excl = M.stat.sale + M.stat.guild
	if excl > 0 then foot = foot .. "  |  " .. L("msg.finder.status.ex", excl) end
	put(f.foot, foot)
	-- boutons de l'entete
	put(f.count, L("msg.finder.count", alive))
	T.SetSelected(f.tabs.all, M.f.kind == "all")
	T.SetSelected(f.tabs.lfm, M.f.kind == "lfm")
	T.SetSelected(f.tabs.lfg, M.f.kind == "lfg")
	T.SetSelected(f.bInst, M.f.inst ~= 0)
	T.SetButtonText(f.bInst, M.FilterInstName(M.f.inst))
	T.SetSelected(f.bTank, M.f.tank)
	T.SetSelected(f.bHeal, M.f.heal)
	T.SetSelected(f.bDps, M.f.dps)
	T.SetSelected(f.bMine, M.f.mine)
	T.SetButtonText(f.bSort, L("msg.finder.sort." .. (C.Get("finder.sort") or "new")))
	if M.FilterActive() then f.bClear:Show() else f.bClear:Hide() end
	f.up:Show()
	f.down:Show()
	M.UpdateFooter()
end

function M.UpdateFooter()
	local f = M.win
	if not f then return end
	T.SetButtonText(f.bAlerts, L("mod.finder.btn.alerts", M.nalerts))
	T.SetButtonText(f.bIgn, L("mod.finder.btn.ignores", M.nign))
	T.SetSelected(f.bAlerts, M.nalerts > 0)
end

-- ---------------------------------------------------------------- selecteur d'instance
function M.PickerFill(mode)
	local lw = M.lw1
	M.ListBegin(lw)
	lw.mode = mode
	local counts = M.CountByInst()
	local k = 0
	local function add(label, ix, col)
		k = k + 1
		if k <= 80 then
			local cur = (mode == "post") and M.ps.inst or M.f.inst
			M.ListSet(lw, k, label, col, ix == cur, M.PickerPick, nil, ix)
		end
	end
	if mode ~= "post" then
		add(L("msg.finder.inst.all"), 0, T.c.text)
		add(L("msg.finder.inst.dungeons"), -1, T.c.text)
		add(L("msg.finder.inst.raids"), -2, T.c.text)
	end
	-- d'abord les instances qui ont des annonces (plus nombreuses en tete), puis les autres
	local order = M.pickOrder
	local n = 0
	for ix = 1, NI do
		if counts[ix] > 0 then
			n = n + 1
			order[n] = ix
		end
	end
	for a = 2, n do
		local v = order[a]
		local b = a - 1
		while b >= 1 and counts[order[b]] < counts[v] do
			order[b + 1] = order[b]
			b = b - 1
		end
		order[b + 1] = v
	end
	for a = 1, n do
		local ix = order[a]
		add(sformat("%s  (%d)", M.InstName(ix), counts[ix]), ix, T.c.good)
	end
	for ix = 1, NI do
		if counts[ix] == 0 then add(M.InstName(ix), ix, T.c.dim) end
	end
	lw.foot:SetText("")
	lw.empty:SetText("")
	M.ListPaint(lw)
end

function M.PickerPick(it)
	local lw = M.lw1
	if lw.mode == "post" then
		M.ps.inst = it.data
		M.PostRecompose()
	else
		M.SetInst(it.data)
	end
	lw:Hide()
end

function M.OpenPicker(mode, anchor)
	if not M.lw1 then
		M.lw1 = M.NewList("ShikiUI_FinderPicker", L("mod.finder.picker.title"), 300, 12)
		M.pickOrder = {}
		M.lw1:SetScale(C.Get("finder.scale") or 1)
	end
	local lw = M.lw1
	if lw:IsShown() and lw.mode == mode then
		lw:Hide()
		return
	end
	lw:ClearAllPoints()
	lw:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	M.PickerFill(mode)
	lw:Show()
	M.SyncLevels(lw)
end

-- ---------------------------------------------------------------- alertes (liste)
function M.AlertsFill()
	local lw = M.lw2
	M.ListBegin(lw)
	for i = 1, M.nalerts do
		local a = M.alerts[i]
		local mark = a.on and L("msg.finder.alert.on") or L("msg.finder.alert.off")
		M.ListSet(lw, i, mark .. "  " .. M.AlertText(a), a.on and T.c.text or T.c.dim, false, M.AlertToggleClick, M.AlertDelClick, i)
	end
	lw.empty:SetText(L("msg.finder.alerts.empty"))
	lw.foot:SetText(L("msg.finder.alerts.foot", M.nalerts, MAXALERTS))
	M.ListPaint(lw)
end

function M.AlertToggleClick(it)
	M.ToggleAlert(it.data)
	M.AlertsFill()
end

function M.AlertDelClick(it)
	M.RemoveAlert(it.data)
	M.AlertsFill()
end

function M.OpenAlerts()
	if not M.lw2 then
		M.lw2 = M.NewList("ShikiUI_FinderAlerts", L("mod.finder.alerts.title"), 380, 8)
		M.lw2:SetScale(C.Get("finder.scale") or 1)
		-- bouton "creer une alerte avec les filtres actuels"
		local b = mkBtn(M.lw2, M.lw2, L("mod.finder.alerts.add"), 200, 18, function() M.AlertFromFilters() end,
			"mod.finder.alerts.add.t", "mod.finder.alerts.add.d", "mod.finder.alerts.add.e", 4)
		b:SetPoint("BOTTOMLEFT", M.lw2, "BOTTOMLEFT", 8, 26)
		M.lw2:SetHeight(32 + 8 * 20 + 54)
		M.lw2.foot:ClearAllPoints()
		M.lw2.foot:SetPoint("BOTTOMLEFT", M.lw2, "BOTTOMLEFT", 8, 8)
		M.lw2.up:ClearAllPoints()
		M.lw2.up:SetPoint("BOTTOMRIGHT", M.lw2, "BOTTOMRIGHT", -26, 28)
	end
	local lw = M.lw2
	if lw:IsShown() then
		lw:Hide()
		return
	end
	M.HidePopups(lw)
	lw:ClearAllPoints()
	if M.win and M.win:IsShown() then
		lw:SetPoint("TOPLEFT", M.win, "TOPRIGHT", 4, 0)
	else
		lw:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	M.AlertsFill()
	lw:Show()
	M.SyncLevels(lw)
end

-- Cree une alerte avec les filtres de la fenetre : instance, role (un seul), type, texte.
function M.AlertFromFilters()
	local f = M.f
	local role = "*"
	local n = (f.tank and 1 or 0) + (f.heal and 1 or 0) + (f.dps and 1 or 0)
	if n == 1 then role = f.tank and "tank" or (f.heal and "heal" or "dps") end
	local kind = f.kind == "all" and "*" or f.kind
	local ok, why = M.AddAlert(f.inst, role, kind, f.q)
	if not ok then
		SUI.Print(L("msg.finder.alert.fail." .. why))
		return false
	end
	SUI.Print(L("msg.finder.alert.added", M.AlertText(M.alerts[M.nalerts])))
	if M.lw2 and M.lw2:IsShown() then M.AlertsFill() end
	return true
end

-- ---------------------------------------------------------------- ignores (liste)
function M.IgnoresFill()
	local lw = M.lw3
	M.ListBegin(lw)
	local names = M.names
	local n = 0
	for _, nm in pairs(M.ign) do
		n = n + 1
		names[n] = nm
	end
	table.sort(names, function(a, b) return slower(a) < slower(b) end)
	for i = 1, n do
		M.ListSet(lw, i, names[i], T.c.text, false, nil, M.IgnoreDelClick, names[i])
	end
	for i = n + 1, getn(names) do names[i] = nil end
	lw.empty:SetText(L("msg.finder.ignores.empty"))
	lw.foot:SetText(L("msg.finder.ignores.foot", M.nign, MAXIGN))
	M.ListPaint(lw)
end

function M.IgnoreDelClick(it)
	M.Unignore(it.data)
	M.IgnoresFill()
end

function M.OpenIgnores()
	if not M.lw3 then
		M.lw3 = M.NewList("ShikiUI_FinderIgnores", L("mod.finder.ignores.title"), 300, 8)
		M.lw3:SetScale(C.Get("finder.scale") or 1)
		M.names = {}
	end
	local lw = M.lw3
	if lw:IsShown() then
		lw:Hide()
		return
	end
	M.HidePopups(lw)
	lw:ClearAllPoints()
	if M.win and M.win:IsShown() then
		lw:SetPoint("TOPLEFT", M.win, "TOPRIGHT", 4, 0)
	else
		lw:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	M.IgnoresFill()
	lw:Show()
	M.SyncLevels(lw)
end

-- ---------------------------------------------------------------- aide
function M.ToggleHelp()
	if not M.helpwin then
		local h = CreateFrame("Frame", "ShikiUI_FinderHelp", UIParent)
		h:SetWidth(380)
		h:SetHeight(300)
		T.Backdrop(h, T.c.panel, T.c.border)
		h:SetFrameStrata("DIALOG")
		h:EnableMouse(true)
		h:SetClampedToScreen(true)
		h:Hide()
		h.kids = {}
		h.title = T.Text(h, 12, T.c.text, "LEFT")
		h.title:SetPoint("TOPLEFT", h, "TOPLEFT", 8, -8)
		h.title:SetText(L("mod.finder.help.title"))
		h.close = mkBtn(h, h, "x", 18, 18, function() h:Hide() end, "mod.finder.btn.close", nil, nil, 4)
		h.close:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -4)
		h.body = T.Text(h, 11, T.c.dim, "LEFT")
		h.body:SetPoint("TOPLEFT", h, "TOPLEFT", 10, -30)
		h.body:SetWidth(360)
		h:SetScript("OnShow", function() M.SyncLevels(this) end)
		M.helpwin = h
		h:SetScale(C.Get("finder.scale") or 1)
	end
	local h = M.helpwin
	if h:IsShown() then
		h:Hide()
		return
	end
	h.body:SetText(L("mod.finder.help.body"))
	M.HidePopups(h)
	h:ClearAllPoints()
	if M.win and M.win:IsShown() then
		h:SetPoint("TOPLEFT", M.win, "TOPRIGHT", 4, 0)
	else
		h:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	h:Show()
	M.SyncLevels(h)
end

-- ---------------------------------------------------------------- construction de la fenetre
local function onSearch()
	if M.settingText then return end
	local e = this
	local q = slower(e:GetText() or "")
	if e.hint then
		if q == "" then e.hint:Show() else e.hint:Hide() end
	end
	if M.f.q ~= q then
		M.f.q = q
		M.Changed()
	end
end

function M.BuildWindow()
	if M.win then return M.win end
	local f = CreateFrame("Frame", "ShikiUI_FinderWin", UIParent)
	f:SetWidth(WIN_W)
	f:SetHeight(440)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:Hide()
	f.kids = {}
	M.win = f
	M.rows = {}
	f.title = T.Text(f, 13, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.title:SetText(L("mod.finder.title"))
	f.count = T.Text(f, 10, T.c.dim, "LEFT")
	f.count:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
	f.close = mkBtn(f, f, "x", 18, 18, function() M.Close() end, "mod.finder.btn.close", "mod.finder.btn.close.d", nil, 4)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	f.bHelp = mkBtn(f, f, "?", 18, 18, function() M.ToggleHelp() end, "mod.finder.btn.help", "mod.finder.btn.help.d", nil, 4)
	f.bHelp:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
	f.bSort = mkBtn(f, f, "", 120, 18, function() M.CycleSort() end, "mod.finder.btn.sort", "mod.finder.btn.sort.d", nil, 4)
	f.bSort:SetPoint("RIGHT", f.bHelp, "LEFT", -6, 0)
	-- ligne 1 : type
	f.tabs = {}
	local kinds = { "all", "lfm", "lfg" }
	for i = 1, 3 do
		local k = kinds[i]
		local b = mkBtn(f, f, L("mod.finder.tab." .. k), 120, 20, function(btn) M.SetKind(btn.kind) end,
			"mod.finder.tab." .. k .. ".t", "mod.finder.tab." .. k .. ".d", nil, 4)
		b.kind = k
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * 124, -30)
		f.tabs[k] = b
	end
	-- ligne 2 : instance, roles, niveau, recherche
	f.bInst = mkBtn(f, f, "", 170, 20, function(btn) M.OpenPicker("filter", btn) end, "mod.finder.btn.inst", "mod.finder.btn.inst.d", nil, 4)
	f.bInst:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -56)
	f.bTank = mkBtn(f, f, L("msg.finder.role.tank"), 44, 20, function() M.SetRole("tank") end, "mod.finder.btn.tank", "mod.finder.btn.role.d", nil, 4)
	f.bTank:SetPoint("LEFT", f.bInst, "RIGHT", 6, 0)
	f.bHeal = mkBtn(f, f, L("msg.finder.role.heal"), 44, 20, function() M.SetRole("heal") end, "mod.finder.btn.heal", "mod.finder.btn.role.d", nil, 4)
	f.bHeal:SetPoint("LEFT", f.bTank, "RIGHT", 2, 0)
	f.bDps = mkBtn(f, f, L("msg.finder.role.dps"), 44, 20, function() M.SetRole("dps") end, "mod.finder.btn.dps", "mod.finder.btn.role.d", nil, 4)
	f.bDps:SetPoint("LEFT", f.bHeal, "RIGHT", 2, 0)
	f.bMine = mkBtn(f, f, L("mod.finder.btn.mine"), 96, 20, function() M.SetMine() end, "mod.finder.btn.mine.t", "mod.finder.btn.mine.d", nil, 4)
	f.bMine:SetPoint("LEFT", f.bDps, "RIGHT", 6, 0)
	local e = T.Edit(f, 120, 20)
	e:SetPoint("LEFT", f.bMine, "RIGHT", 6, 0)
	e:SetMaxLetters(40)
	e:SetScript("OnTextChanged", onSearch)
	e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	e.hint = T.Text(e, 10, T.c.dim, "LEFT")
	e.hint:SetPoint("LEFT", e, "LEFT", 6, 0)
	e.hint:SetText(L("mod.finder.search.hint"))
	e:SetScript("OnEnter", function()
		M.Tip(this, L("mod.finder.search.t"), L("mod.finder.search.d"))
	end)
	e:SetScript("OnLeave", function() M.TipHide() end)
	track(f, e, 4)
	f.search = e
	f.bClear = mkBtn(f, f, "x", 20, 20, function() M.ResetFilters() end, "mod.finder.btn.clear", "mod.finder.btn.clear.d", nil, 4)
	f.bClear:SetPoint("LEFT", e, "RIGHT", 4, 0)
	-- liste : defilement
	f.up = mkBtn(f, f, "^", 18, 18, function() M.Scroll(-3) end, "mod.finder.list.up", nil, nil, 4)
	f.up:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -86)
	f.down = mkBtn(f, f, "v", 18, 18, function() M.Scroll(3) end, "mod.finder.list.down", nil, nil, 4)
	f.down:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -106)
	for i = 1, NROWS_MAX do M.BuildRow(i) end
	f.empty = T.Text(f, 11, T.c.dim, "LEFT")
	f.empty:SetWidth(WIN_W - 60)
	f.bReset = mkBtn(f, f, L("mod.finder.btn.resetf"), 150, 20, function() M.ResetFilters() end, "mod.finder.btn.clear", "mod.finder.btn.clear.d", nil, 4)
	f.bReset:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -150)
	f.bReset:Hide()
	f.foot = T.Text(f, 10, T.c.dim, "LEFT")
	f.foot:SetWidth(WIN_W - 20)
	-- pied : actions
	f.bPost = mkBtn(f, f, L("mod.finder.btn.post"), 170, 22, function() M.TogglePost() end, "mod.finder.btn.post.t", "mod.finder.btn.post.d", "mod.finder.btn.post.e", 4)
	f.bAlerts = mkBtn(f, f, "", 130, 22, function() M.OpenAlerts() end, "mod.finder.btn.alerts.t", "mod.finder.btn.alerts.d", "mod.finder.btn.alerts.e", 4)
	f.bAlerts:SetPoint("LEFT", f.bPost, "RIGHT", 6, 0)
	f.bIgn = mkBtn(f, f, "", 130, 22, function() M.OpenIgnores() end, "mod.finder.btn.ignores.t", "mod.finder.btn.ignores.d", nil, 4)
	f.bIgn:SetPoint("LEFT", f.bAlerts, "RIGHT", 6, 0)
	f.bMore = mkBtn(f, f, L("mod.finder.btn.clearbuf"), 120, 22, function() M.ClearBuffer() end, "mod.finder.btn.clearbuf.t", "mod.finder.btn.clearbuf.d", nil, 4)
	f.bMore:SetPoint("LEFT", f.bIgn, "RIGHT", 6, 0)
	f:SetScript("OnMouseWheel", function() M.Scroll(arg1 > 0 and -1 or 1) end)
	f:SetScript("OnEnter", function()
		if M.LevelsStale(this) then M.SyncLevels(this) end
	end)
	f:SetScript("OnShow", function()
		M.SyncLevels(this)
		M.hits = 0
		M.UpdateAccess()
		M.Sync()
		M.dirty = true
		M.Render()
	end)
	f:SetScript("OnHide", function()
		if M.lw1 then M.lw1:Hide() end
		if M.lw2 then M.lw2:Hide() end
		if M.lw3 then M.lw3:Hide() end
		if M.helpwin then M.helpwin:Hide() end
		if M.postwin then M.postwin:Hide() end
		M.Sync()
	end)
	-- engrenage : ouvre les reglages du module, a gauche du bouton de tri (cree APRES l'OnShow de la fenetre : son niveau est recale a l'ouverture)
	T.GearButton(f, "finder", { size = 18, point = "TOPRIGHT", x = -170, y = -4, title = L("mod.finder.gear"),
		onCreate = function(g)
			g:ClearAllPoints()
			g:SetPoint("RIGHT", f.bSort, "LEFT", -6, 0)
		end })
	M.ApplyLook()
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("finder.win", f, { label = L("mod.finder.mover"), point = "CENTER", x = 0, y = 20, scale = false })
	else
		SUI.Layout.Register(f, "finder.win", "CENTER", 0, 20)
	end
	tinsert(UISpecialFrames, "ShikiUI_FinderWin")
	-- Glisser la fenetre a la souris (zone vide ou barre de titre) sans deverrouiller le Mover : la position est memorisee via le Mover.
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() M.DragStart(this) end)
	f:SetScript("OnDragStop", function() M.DragStop(this) end)
	return f
end

function M.DragStart(f)
	if not f or f.suiDrag then return end
	f.suiDrag = true
	f:StartMoving()
end

function M.DragStop(f)
	if not f or not f.suiDrag then return end
	f.suiDrag = nil
	f:StopMovingOrSizing()
	local rec = SUI.Mover and SUI.Mover.items and SUI.Mover.items["finder.win"]
	local l, b = f:GetLeft(), f:GetBottom()
	if rec and type(l) == "number" and type(b) == "number" then
		local sc = f:GetScale() or 1
		SUI.Mover.Commit(rec, l * sc, b * sc)
	end
end

function M.ClearBuffer()
	local n = M.Clear()
	SUI.Print(L("msg.finder.cleared", n))
	M.Changed()
end

function M.Open(mode)
	if not M.on then
		SUI.Print(L("msg.finder.off"))
		return false
	end
	mode = mode or "toggle"
	if not M.win then
		if SUI.InCombat() then
			SUI.Print(L("msg.finder.combat"))
			SUI.WhenSafe(function()
				M.BuildWindow()
				if M.on then M.win:Show() end
			end)
			return false
		end
		M.BuildWindow()
	end
	local shown = M.win:IsShown()
	if mode == "close" or (mode == "toggle" and shown) then
		if shown then M.win:Hide() end
	elseif not shown then
		M.win:Show()
	end
	return true
end

function M.Close()
	if M.win then M.win:Hide() end
end

-- ================================================================ composition et envoi d'une annonce
local function Lx(lang, key, a, b, c, d)
	local tbl = SUI.locales[lang] or SUI.locales.fr
	local s = tbl[key] or SUI.locales.fr[key] or key
	if a ~= nil then return sformat(s, a, b, c, d) end
	return s
end

function M.PostLang()
	local l = C.Get("finder.postlang") or "auto"
	if l == "auto" then l = SUI.locale end
	if l ~= "fr" and l ~= "en" then l = "en" end
	return l
end

local ROLES3 = { "tank", "heal", "dps" }

-- Compose le texte (ps : kind, inst, tank, heal, dps, lv, loot, note) ; style : classic | short | full ; lang : fr | en.
function M.Compose(ps, style, lang)
	local g = INST[ps.inst or 0]
	local lfm = (ps.kind ~= "lfg")
	local head = lfm and "LFM" or "LFG"
	local lvn = tonumber(ps.lv)
	if lvn and (lvn < 1 or lvn > 60) then lvn = nil end
	local note = sgsub(ps.note or "", "|", "")
	local loot = ""
	if ps.loot and ps.loot ~= "" then loot = Lx(lang, "choice.finder.loot." .. ps.loot) end
	local out
	if style == "short" then
		out = head
		if g then out = out .. " " .. g[4] end
		local rs = ""
		for i = 1, 3 do
			local r = ROLES3[i]
			local n = ps[r] or 0
			if n > 0 then
				local ch = Lx(lang, "msg.finder.c." .. r .. ".ch")
				rs = rs .. " " .. ((lfm and n > 0) and (n .. ch) or ch)
			end
		end
		out = out .. rs
		if lvn then out = out .. " " .. (lfm and (lvn .. "+") or lvn) end
		if loot ~= "" then out = out .. " " .. loot end
		if note ~= "" then out = out .. " " .. note end
	elseif style == "full" then
		out = Lx(lang, lfm and "msg.finder.c.lfm.full" or "msg.finder.c.lfg.full")
		if g then
			out = out .. " " .. (lang == "fr" and g[2] or g[3])
			if g[6] ~= g[7] then out = out .. " (" .. g[6] .. "-" .. g[7] .. ")" end
		end
		local list = ""
		for i = 1, 3 do
			local r = ROLES3[i]
			local n = ps[r] or 0
			if n > 0 then
				local w = Lx(lang, "msg.finder.c." .. r .. ".full")
				local piece = lfm and (n .. " " .. w) or w
				list = (list == "") and piece or (list .. ", " .. piece)
			end
		end
		if list ~= "" then
			out = out .. " : " .. Lx(lang, lfm and "msg.finder.c.need" or "msg.finder.c.iam") .. " " .. list .. "."
		else
			out = out .. "."
		end
		local extra = ""
		if lvn then extra = Lx(lang, lfm and "msg.finder.c.lvl.min" or "msg.finder.c.lvl.is", lvn) end
		if loot ~= "" then extra = (extra == "") and loot or (extra .. ", " .. loot) end
		if extra ~= "" then out = out .. " " .. extra .. "." end
		if note ~= "" then out = out .. " " .. note .. "." end
		out = out .. " " .. Lx(lang, "msg.finder.c.join")
	else
		local parts = head
		if g then parts = parts .. " " .. g[4] end
		local list = ""
		for i = 1, 3 do
			local r = ROLES3[i]
			local n = ps[r] or 0
			if n > 0 then
				local w = Lx(lang, "msg.finder.c." .. r)
				local piece = lfm and (n .. " " .. w) or w
				list = (list == "") and piece or (list .. " " .. piece)
			end
		end
		if list ~= "" then
			parts = parts .. " - " .. (lfm and (Lx(lang, "msg.finder.c.need") .. " ") or "") .. list
		end
		if lvn then parts = parts .. " - " .. Lx(lang, lfm and "msg.finder.c.lvl.min" or "msg.finder.c.lvl.is", lvn) end
		if loot ~= "" then parts = parts .. " - " .. loot end
		if note ~= "" then parts = parts .. " - " .. note end
		out = parts .. " - " .. Lx(lang, "msg.finder.c.tail")
	end
	if slen(out) > 255 and style ~= "short" then out = M.Compose(ps, "short", lang) end
	if slen(out) > 255 then out = ssub(out, 1, 255) end
	return out
end

-- Canaux disponibles pour poster : canaux rejoints (GetChannelList) puis Dire / Cri.
function M.PostChannels()
	local n = 0
	local gl = gf("GetChannelList")
	local pch = M.pch
	if gl then
		local t = { gl() }
		local i = 1
		while t[i] do
			local id, name = t[i], t[i + 1]
			if type(id) == "number" and type(name) == "string" and n < 12 then
				n = n + 1
				local e = pch[n]
				if not e then e = {} pch[n] = e end
				e.label, e.kind, e.id = id .. ". " .. name, "CHANNEL", id
				e.name = slower(name)
			end
			i = i + 2
		end
	end
	n = n + 1
	local e = pch[n]
	if not e then e = {} pch[n] = e end
	e.label, e.kind, e.id, e.name = L("msg.finder.src.say"), "SAY", nil, "say"
	n = n + 1
	e = pch[n]
	if not e then e = {} pch[n] = e end
	e.label, e.kind, e.id, e.name = L("msg.finder.src.yell"), "YELL", nil, "yell"
	M.npch = n
	-- canal par defaut : Monde / recherche de groupe
	local best = nil
	for i = 1, n do
		local nm = pch[i].name
		if sfind(nm, "world", 1, true) or sfind(nm, "monde", 1, true) then best = best or i end
	end
	if not best then
		for i = 1, n do
			local nm = pch[i].name
			if sfind(nm, "lookingforgroup", 1, true) or sfind(nm, "lfg", 1, true) then best = i break end
		end
	end
	if M.ps.ch > n or M.ps.ch < 1 or not M.chSet then
		M.ps.ch = best or 1
		M.chSet = true
	end
	return n
end

function M.PostText()
	return M.Compose(M.ps, C.Get("finder.poststyle") or "classic", M.PostLang())
end

function M.PostRecompose()
	local p = M.postwin
	if not p then return end
	M.settingText = true
	p.preview:SetText(M.PostText())
	M.settingText = false
	M.postEdited = false
	M.PostPaint()
end

function M.PostStep(role, d)
	local v = (M.ps[role] or 0) + d
	local mx = (M.ps.kind == "lfg") and 1 or 9
	if v < 0 then v = 0 end
	if v > mx then v = mx end
	M.ps[role] = v
	M.PostRecompose()
end

function M.PostSetKind(k)
	M.ps.kind = k
	if k == "lfg" then
		for i = 1, 3 do
			if M.ps[ROLES3[i]] > 1 then M.ps[ROLES3[i]] = 1 end
		end
		if M.ps.tank + M.ps.heal + M.ps.dps == 0 then M.ps.dps = 1 end
	elseif M.ps.tank + M.ps.heal + M.ps.dps <= 1 then
		M.ps.tank, M.ps.heal, M.ps.dps = 1, 1, 2
	end
	M.PostRecompose()
end

local LOOTS = { "", "msos", "sr", "hr", "gdkp", "dkp", "ffa", "nbg" }
function M.PostCycleLoot()
	local cur = M.ps.loot
	local nxt = LOOTS[1]
	for i = 1, getn(LOOTS) do
		if LOOTS[i] == cur then nxt = LOOTS[SUI.Mod(i, getn(LOOTS)) + 1] end
	end
	M.ps.loot = nxt
	M.PostRecompose()
end

function M.PostCycleChan()
	M.PostChannels()
	M.ps.ch = SUI.Mod(M.ps.ch, M.npch) + 1
	M.PostPaint()
end

local STYLES = { "classic", "short", "full" }
function M.PostCycleStyle()
	local cur = C.Get("finder.poststyle") or "classic"
	local nxt = STYLES[1]
	for i = 1, getn(STYLES) do
		if STYLES[i] == cur then nxt = STYLES[SUI.Mod(i, getn(STYLES)) + 1] end
	end
	C.Set("finder.poststyle", nxt)
	M.PostRecompose()
end

-- Modeles enregistres : "genre,cle,tank,heal,dps,niveau,butin,note" (4 emplacements, separes par ';' dans finder.tpls).
function M.LoadTpls()
	local n = split(C.Get("finder.tpls") or "", ";", TMP)
	for i = 1, 4 do M.tpls[i] = (i <= n) and TMP[i] or "" end
end

function M.TplString()
	return M.tpls[1] .. ";" .. M.tpls[2] .. ";" .. M.tpls[3] .. ";" .. M.tpls[4]
end

function M.TplEncode(ps)
	local g = INST[ps.inst or 0]
	return ps.kind .. "," .. (g and g[1] or "-") .. "," .. ps.tank .. "," .. ps.heal .. "," .. ps.dps .. "," .. clean(ps.lv) .. "," ..
		(ps.loot ~= "" and ps.loot or "-") .. "," .. clean(ps.note)
end

function M.TplSave(slot)
	M.tpls[slot] = M.TplEncode(M.ps)
	C.SetBase("finder.tpls", M.TplString())
	SUI.Print(L("msg.finder.tpl.saved", slot))
	M.PostPaint()
end

function M.TplLoad(slot)
	local s = M.tpls[slot]
	if not s or s == "" then return false end
	local n = split(s, ",", TMP2)
	if n < 7 then return false end
	local ps = M.ps
	ps.kind = (TMP2[1] == "lfg") and "lfg" or "lfm"
	ps.inst = IXKEY[TMP2[2]] or 0
	ps.tank, ps.heal, ps.dps = tonumber(TMP2[3]) or 0, tonumber(TMP2[4]) or 0, tonumber(TMP2[5]) or 0
	ps.lv = TMP2[6] or ""
	ps.loot = (TMP2[7] ~= "-") and TMP2[7] or ""
	ps.note = TMP2[8] or ""
	if M.postwin then
		M.settingText = true
		M.postwin.lvEdit:SetText(ps.lv)
		M.postwin.noteEdit:SetText(ps.note)
		M.settingText = false
	end
	M.PostRecompose()
	return true
end

local function tplClick(b, button)
	if button == "RightButton" then M.TplSave(b.slot) else M.TplLoad(b.slot) end
end

function M.TplTip(b)
	local s = M.tpls[b.slot]
	if not s or s == "" then return "mod.finder.tpl.empty" end
	return "mod.finder.tpl.used"
end

-- Secondes restantes avant de pouvoir reposter.
function M.PostWait()
	local cd = C.Get("finder.postcool") or 60
	local rem = cd - (GetTime() - M.lastPostT)
	if rem < 0 then rem = 0 end
	return rem
end

function M.PostCool()
	local p = M.postwin
	if not p then return end
	local rem = M.PostWait()
	local txt
	if rem > 0 then txt = L("mod.finder.post.sendwait", floor(rem) + 1) else txt = L("mod.finder.post.send") end
	if p.bSend.curtxt ~= txt then
		p.bSend.curtxt = txt
		T.SetButtonText(p.bSend, txt)
	end
	setDisabled(p.bSend, rem > 0)
end

function M.PostPaint()
	local p = M.postwin
	if not p then return end
	local ps = M.ps
	T.SetSelected(p.kLfm, ps.kind ~= "lfg")
	T.SetSelected(p.kLfg, ps.kind == "lfg")
	T.SetButtonText(p.bInst, M.InstName(ps.inst ~= 0 and ps.inst or nil))
	if ps.inst == 0 then T.SetButtonText(p.bInst, L("mod.finder.post.pickinst")) end
	for i = 1, 3 do
		local r = ROLES3[i]
		p.vals[i]:SetText(ps[r] .. "")
	end
	T.SetButtonText(p.bLoot, ps.loot == "" and L("mod.finder.post.noloot") or L("choice.finder.loot." .. ps.loot))
	M.PostChannels()
	local ch = M.pch[M.ps.ch]
	T.SetButtonText(p.bChan, ch and ch.label or "?")
	T.SetButtonText(p.bStyle, L("choice.finder.poststyle." .. (C.Get("finder.poststyle") or "classic")))
	for i = 1, 4 do
		local s = M.tpls[i]
		T.SetSelected(p.tpl[i], s ~= nil and s ~= "")
	end
	M.PostCool()
	local len = slen(p.preview:GetText() or "")
	put(p.lenText, L("msg.finder.post.len", len))
end

function M.PostSend()
	local p = M.postwin
	if not p then return false end
	local txt = p.preview:GetText() or ""
	if txt == "" then
		SUI.Print(L("msg.finder.post.empty"))
		return false
	end
	local rem = M.PostWait()
	if rem > 0 then
		SUI.Print(L("msg.finder.post.cool", floor(rem) + 1))
		return false
	end
	local now = GetTime()
	if txt == M.lastPostText and now - M.lastPostT < 180 then
		SUI.Print(L("msg.finder.post.dup"))
		return false
	end
	M.PostChannels()
	local ch = M.pch[M.ps.ch]
	if not ch then return false end
	if slen(txt) > 255 then txt = ssub(txt, 1, 255) end
	if ch.kind == "CHANNEL" then
		SendChatMessage(txt, "CHANNEL", nil, ch.id)
	else
		SendChatMessage(txt, ch.kind)
	end
	M.lastPostT = now
	M.lastPostText = txt
	M.stat.posted = (M.stat.posted or 0) + 1
	SUI.Print(L("msg.finder.post.sent", ch.label))
	M.PostCool()
	return true
end

-- ---------------------------------------------------------------- fenetre "Poster mon annonce"
local function stepClick(b)
	M.PostStep(b.role, b.delta)
end

local function lvChanged()
	if M.settingText then return end
	local e = this
	M.ps.lv = e:GetText() or ""
	M.PostRecompose()
end

local function noteChanged()
	if M.settingText then return end
	local e = this
	M.ps.note = e:GetText() or ""
	if e.hint then
		if M.ps.note == "" then e.hint:Show() else e.hint:Hide() end
	end
	M.PostRecompose()
end

function M.HidePopups(keep)
	local list = { M.lw2, M.lw3, M.helpwin, M.postwin }
	for i = 1, 4 do
		local w = list[i]
		if w and w ~= keep and w:IsShown() then w:Hide() end
	end
end

function M.BuildPost()
	if M.postwin then return M.postwin end
	local p = CreateFrame("Frame", "ShikiUI_FinderPost", UIParent)
	p:SetWidth(432)
	p:SetHeight(296)
	T.Backdrop(p, T.c.panel, T.c.border)
	p:SetFrameStrata("DIALOG")
	p:EnableMouse(true)
	p:SetClampedToScreen(true)
	p:Hide()
	p.kids = {}
	M.postwin = p
	p.title = T.Text(p, 12, T.c.text, "LEFT")
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -8)
	p.title:SetText(L("mod.finder.post.title"))
	p.close = mkBtn(p, p, "x", 18, 18, function() p:Hide() end, "mod.finder.btn.close", nil, nil, 4)
	p.close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
	p.kLfm = mkBtn(p, p, L("mod.finder.post.k.lfm"), 205, 20, function() M.PostSetKind("lfm") end, "mod.finder.post.k.lfm.t", "mod.finder.post.k.lfm.d", nil, 4)
	p.kLfm:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -30)
	p.kLfg = mkBtn(p, p, L("mod.finder.post.k.lfg"), 205, 20, function() M.PostSetKind("lfg") end, "mod.finder.post.k.lfg.t", "mod.finder.post.k.lfg.d", nil, 4)
	p.kLfg:SetPoint("LEFT", p.kLfm, "RIGHT", 6, 0)
	p.bInst = mkBtn(p, p, "", 250, 20, function(btn) M.OpenPicker("post", btn) end, "mod.finder.post.inst.t", "mod.finder.post.inst.d", nil, 4)
	p.bInst:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -56)
	p.lvLabel = T.Text(p, 11, T.c.dim, "LEFT")
	p.lvLabel:SetPoint("LEFT", p.bInst, "RIGHT", 10, 0)
	p.lvLabel:SetText(L("mod.finder.post.lv"))
	p.lvEdit = T.Edit(p, 44, 20)
	p.lvEdit:SetPoint("LEFT", p.lvLabel, "RIGHT", 6, 0)
	p.lvEdit:SetMaxLetters(2)
	p.lvEdit:SetScript("OnTextChanged", lvChanged)
	p.lvEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	p.lvEdit:SetScript("OnEnter", function() M.Tip(this, L("mod.finder.post.lv.t"), L("mod.finder.post.lv.d")) end)
	p.lvEdit:SetScript("OnLeave", function() M.TipHide() end)
	track(p, p.lvEdit, 4)
	p.vals = {}
	for i = 1, 3 do
		local role = ROLES3[i]
		local x = 8 + (i - 1) * 142
		local lab = T.Text(p, 11, T.c.text, "LEFT")
		lab:SetPoint("TOPLEFT", p, "TOPLEFT", x, -88)
		lab:SetText(L("msg.finder.role." .. role))
		lab:SetWidth(44)
		local m = mkBtn(p, p, "-", 20, 20, stepClick, "mod.finder.post.step.t", "mod.finder.post.step.d", nil, 4)
		m:SetPoint("TOPLEFT", p, "TOPLEFT", x + 46, -84)
		m.role, m.delta = role, -1
		local v = T.Text(p, 12, T.c.text, "CENTER")
		v:SetPoint("LEFT", m, "RIGHT", 0, 0)
		v:SetWidth(24)
		local pl = mkBtn(p, p, "+", 20, 20, stepClick, "mod.finder.post.step.t", "mod.finder.post.step.d", nil, 4)
		pl:SetPoint("LEFT", m, "RIGHT", 24, 0)
		pl.role, pl.delta = role, 1
		p.vals[i] = v
	end
	p.bLoot = mkBtn(p, p, "", 120, 20, function() M.PostCycleLoot() end, "mod.finder.post.loot.t", "mod.finder.post.loot.d", nil, 4)
	p.bLoot:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -114)
	p.bChan = mkBtn(p, p, "", 190, 20, function() M.PostCycleChan() end, "mod.finder.post.chan.t", "mod.finder.post.chan.d", nil, 4)
	p.bChan:SetPoint("LEFT", p.bLoot, "RIGHT", 6, 0)
	p.bStyle = mkBtn(p, p, "", 90, 20, function() M.PostCycleStyle() end, "mod.finder.post.style.t", "mod.finder.post.style.d", nil, 4)
	p.bStyle:SetPoint("LEFT", p.bChan, "RIGHT", 6, 0)
	p.noteEdit = T.Edit(p, 414, 20)
	p.noteEdit:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -142)
	p.noteEdit:SetMaxLetters(80)
	p.noteEdit:SetScript("OnTextChanged", noteChanged)
	p.noteEdit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	p.noteEdit.hint = T.Text(p.noteEdit, 10, T.c.dim, "LEFT")
	p.noteEdit.hint:SetPoint("LEFT", p.noteEdit, "LEFT", 6, 0)
	p.noteEdit.hint:SetText(L("mod.finder.post.note.hint"))
	p.noteEdit:SetScript("OnEnter", function() M.Tip(this, L("mod.finder.post.note.t"), L("mod.finder.post.note.d")) end)
	p.noteEdit:SetScript("OnLeave", function() M.TipHide() end)
	track(p, p.noteEdit, 4)
	p.tplLabel = T.Text(p, 11, T.c.dim, "LEFT")
	p.tplLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -172)
	p.tplLabel:SetText(L("mod.finder.post.tpl"))
	p.tpl = {}
	for i = 1, 4 do
		local b = mkBtn(p, p, i .. "", 28, 20, tplClick, "mod.finder.tpl.t", nil, "mod.finder.tpl.e", 4)
		b.tipFn = M.TplTip
		b.slot = i
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 80 + (i - 1) * 32, -168)
		p.tpl[i] = b
	end
	p.preview = T.Text(p, 11, T.c.text, "LEFT")
	p.preview:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -200)
	p.preview:SetWidth(410)
	p.preview:SetHeight(44)
	p.lenText = T.Text(p, 10, T.c.dim, "LEFT")
	p.lenText:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -246)
	p.bSend = mkBtn(p, p, "", 190, 22, function() M.PostSend() end, "mod.finder.post.send.t", "mod.finder.post.send.d", "mod.finder.post.send.e", 4)
	p.bSend:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 8, 8)
	p.bCancel = mkBtn(p, p, L("mod.finder.post.cancel"), 90, 22, function() p:Hide() end, "mod.finder.btn.close", nil, nil, 4)
	p.bCancel:SetPoint("LEFT", p.bSend, "RIGHT", 6, 0)
	p:SetScript("OnEnter", function()
		if M.LevelsStale(this) then M.SyncLevels(this) end
	end)
	p:SetScript("OnShow", function()
		M.SyncLevels(this)
		M.PostChannels()
		M.settingText = true
		p.lvEdit:SetText(M.ps.lv)
		p.noteEdit:SetText(M.ps.note)
		M.settingText = false
		if M.ps.note == "" then p.noteEdit.hint:Show() else p.noteEdit.hint:Hide() end
		M.PostRecompose()
		M.Sync()
	end)
	p:SetScript("OnHide", function()
		if M.lw1 and M.lw1.mode == "post" then M.lw1:Hide() end
		M.Sync()
	end)
	p:SetScale(C.Get("finder.scale") or 1)
	return p
end

function M.TogglePost()
	if not M.on then return false end
	if not M.postwin then
		if SUI.InCombat() then
			SUI.Print(L("msg.finder.combat"))
			return false
		end
		M.BuildPost()
	end
	local p = M.postwin
	if p:IsShown() then
		p:Hide()
		return true
	end
	M.HidePopups(p)
	p:ClearAllPoints()
	if M.win and M.win:IsShown() then
		p:SetPoint("TOPLEFT", M.win, "TOPRIGHT", 4, 0)
	else
		p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	p:Show()
	return true
end

-- ================================================================ boutons d'acces (minimap, fenetre Social)
local function accessClick(b, button)
	if button == "RightButton" then
		if M.win and not M.win:IsShown() then M.Open("open") end
		M.OpenAlerts()
	else
		M.Open("toggle")
	end
end

local function accessEnter()
	local b = this
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
	M.Tip(b, L("mod.finder.title"), L("msg.finder.access.tip", M.Count(), M.nalerts), L("msg.finder.access.hint"))
end

function M.MakeAccess(parent, w)
	local b = T.Button(parent, L("mod.finder.btn.short"), w, 18, accessClick)
	b:SetFrameStrata("HIGH")
	b:SetScript("OnEnter", accessEnter)
	b:SetScript("OnLeave", btnLeave)
	return b
end

function M.BuildAccess()
	if not M.on then return end
	local mm = getglobal("Minimap")
	if mm and not M.mbtn then
		M.mbtn = M.MakeAccess(mm, 40)
		M.mbtn.suiOwn = true
		M.mbtn:SetHeight(22)
		M.mbtn:SetFrameStrata("HIGH")
		M.mbtn:SetFrameLevel((mm:GetFrameLevel() or 0) + 12)   -- au-dessus des cadres de Mod_Minimap (+5..+7) et du tiroir
		if M.mbtn.SetHitRectInsets then M.mbtn:SetHitRectInsets(-6, -6, -6, -6) end   -- zone de clic plus large que le dessin
		SUI.MiniRing.Drag(M.mbtn, "finder.angle", 200)                                -- glisser autour de la minicarte
	end
	local ff = getglobal("FriendsFrame")
	if ff and not M.sbtn then
		M.sbtn = M.MakeAccess(ff, 72)
		if M.sbtn.SetHitRectInsets then M.sbtn:SetHitRectInsets(-4, -4, -4, -4) end
		M.sbtn:SetPoint("TOPRIGHT", ff, "TOPRIGHT", -62, -14)
	end
	M.UpdateAccess()
end

function M.UpdateAccess()
	local mode = C.Get("finder.btn") or "both"
	local txt = L("mod.finder.btn.short")
	if M.hits > 0 then txt = txt .. " " .. M.hits end
	local mm = getglobal("Minimap")
	local b = M.mbtn
	if b then
		if M.on and (mode == "both" or mode == "minimap") then
			if b.curtxt ~= txt then
				b.curtxt = txt
				T.SetButtonText(b, txt)
			end
			if not b.ringDrag then SUI.MiniRing.Place(b, "finder.angle", 200) end
			b:Show()
		else
			b:Hide()
		end
	end
	b = M.sbtn
	if b then
		if M.on and (mode == "both" or mode == "social") then
			local t2 = L("mod.finder.btn.social")
			if M.hits > 0 then t2 = t2 .. " " .. M.hits end
			if b.curtxt ~= t2 then
				b.curtxt = t2
				T.SetButtonText(b, t2)
			end
			b:Show()
		else
			b:Hide()
		end
	end
end

-- ================================================================ diagnostic, repeinture
function M.Diag()
	local out = {}
	local list = { M.win, M.postwin, M.lw1, M.lw2, M.lw3, M.helpwin }
	for i = 1, 6 do
		local w = list[i]
		if w then
			local fixed = M.SyncLevels(w)
			local mouse = 0
			local k = w.kids
			for j = 1, getn(k) do
				if k[j]:IsMouseEnabled() then mouse = mouse + 1 end
			end
			tinsert(out, L("msg.finder.diag", w:GetName() or "?", w:GetFrameLevel() or 0, fixed, mouse))
		end
	end
	return out
end

function M.Repaint()
	M.epoch = M.epoch + 1
	if not M.on then return end
	if M.win and M.win:IsShown() then M.Render() end
	if M.lw1 and M.lw1:IsShown() then M.PickerFill(M.lw1.mode) end
	if M.lw2 and M.lw2:IsShown() then M.AlertsFill() end
	if M.lw3 and M.lw3:IsShown() then M.IgnoresFill() end
end

-- ================================================================ reglages
function M.OnKey(key, value)
	if not M.on then return end
	if key == nil then
		M.LoadIgnores()
		M.LoadAlerts()
		M.LoadAlias()
		M.LoadTpls()
		M.SetCap()
		M.chanOK = {}
	elseif key == "finder.ignored" then M.LoadIgnores()
	elseif key == "finder.alerts" then M.LoadAlerts()
	elseif key == "finder.alias" then M.LoadAlias()
	elseif key == "finder.tpls" then M.LoadTpls()
	elseif key == "finder.maxads" then M.SetCap()
	elseif key == "finder.chanskip" then M.chanOK = {}
	end
	M.Sync()
	if key == nil or key == "finder.look" or key == "finder.rows" or key == "finder.scale" then M.ApplyLook() end
	if key == nil or key == "finder.btn" or key == "finder.angle" then M.UpdateAccess() end
	M.dirty = true
	if M.win and M.win:IsShown() then M.Render() end
	if M.postwin and M.postwin:IsShown() then M.PostRecompose() end
end

-- ================================================================ commande /sui lfg
local function word1(rest)
	local sp = sfind(rest, " ", 1, true)
	if sp then return slower(ssub(rest, 1, sp - 1)), ssub(rest, sp + 1) end
	return slower(rest), ""
end

-- /sui lfg alert <instance> [tank|heal|dps] [lfm|lfg] [texte]
function M.AlertFromText(arg)
	local norm = normalize(arg)
	local n = splitWords(norm)
	local ix, role, kind = 0, "*", "*"
	local text = ""
	for i = 1, n do
		local w = WORDS[i]
		local ixw = V.instw[w] or M.uAlias[w]
		if ix == 0 and ixw then ix = ixw
		elseif V.role[w] and role == "*" then role = V.role[w]
		elseif w == "lfm" or w == "lfg" then kind = w
		elseif w == "donjons" or w == "dungeons" then ix = -1
		elseif w == "raids" or w == "raid" then ix = -2
		else text = (text == "") and w or (text .. " " .. w) end
	end
	return M.AddAlert(ix, role, kind, text)
end

function M.Command(rest)
	rest = rest or ""
	local w, arg = word1(rest)
	if w == "help" or w == "?" then
		SUI.Print(L("msg.finder.help"))
		return
	end
	if not M.on then
		SUI.Print(L("msg.finder.off"))
		return
	end
	if w == "" or w == "open" or w == "toggle" then M.Open("toggle")
	elseif w == "close" then M.Open("close")
	elseif w == "post" then
		M.Open("open")
		M.TogglePost()
	elseif w == "alerts" then
		M.Open("open")
		M.OpenAlerts()
	elseif w == "ignores" then
		M.Open("open")
		M.OpenIgnores()
	elseif w == "alert" then
		local w2, arg2 = word1(arg)
		if w2 == "clear" then
			for i = M.nalerts, 1, -1 do M.RemoveAlert(i) end
			SUI.Print(L("msg.finder.alert.cleared"))
		elseif w2 == "list" or w2 == "" then
			if M.nalerts == 0 then SUI.Print(L("msg.finder.alerts.empty")) end
			for i = 1, M.nalerts do
				SUI.Print(i .. ". " .. (M.alerts[i].on and L("msg.finder.alert.on") or L("msg.finder.alert.off")) .. " " .. M.AlertText(M.alerts[i]))
			end
		else
			local ok, why = M.AlertFromText(w2 == "add" and arg2 or arg)
			if ok then SUI.Print(L("msg.finder.alert.added", M.AlertText(M.alerts[M.nalerts])))
			else SUI.Print(L("msg.finder.alert.fail." .. why)) end
		end
	elseif w == "ignore" then
		if arg == "" then
			M.Open("open")
			M.OpenIgnores()
		elseif M.Ignore(arg) then SUI.Print(L("msg.finder.ign.added", arg)) end
	elseif w == "unignore" then
		if M.Unignore(arg) then SUI.Print(L("msg.finder.ign.removed", arg)) end
	elseif w == "clear" then
		SUI.Print(L("msg.finder.cleared", M.Clear()))
	elseif w == "status" then
		local s = M.stat
		SUI.Print(L("msg.finder.stat", M.Count(), s.seen, s.kept))
		SUI.Print(L("msg.finder.stat2", s.sale + s.guild, s.dup, s.alerts))
		SUI.Print(L(M.listening and "msg.finder.listening" or "msg.finder.notlistening"))
	elseif w == "alias" then
		local a1, a2 = word1(arg)
		if a1 == "clear" then
			C.SetBase("finder.alias", "")
			SUI.Print(L("msg.finder.alias.cleared"))
		elseif a1 ~= "" and IXKEY[slower(a2)] then
			local cur = C.Get("finder.alias") or ""
			C.SetBase("finder.alias", cur == "" and (a1 .. "=" .. slower(a2)) or (cur .. ";" .. a1 .. "=" .. slower(a2)))
			SUI.Print(L("msg.finder.alias.added", a1, M.InstName(IXKEY[slower(a2)])))
		else
			SUI.Print(L("msg.finder.alias.usage"))
		end
	elseif w == "quick" then
		C.SetBase("finder.quick", arg)
		if arg == "" then SUI.Print(L("msg.finder.quick.reset")) else SUI.Print(L("msg.finder.quick.set", arg)) end
	elseif w == "test" then
		local kind, why = M.Parse(arg)
		if not kind then
			SUI.Print(L("msg.finder.test.none", why or "?"))
		else
			SUI.Print(L("msg.finder.test.ok", L("msg.finder.kind." .. kind), M.InstName(P.i1), M.RolesText(P), P.places))
		end
	elseif w == "diag" then
		local out = M.Diag()
		for i = 1, getn(out) do SUI.Print(out[i]) end
	else
		SUI.Print(L("msg.finder.help"))
	end
end

-- ================================================================ cycle de vie
function M.Enable()
	M.on = true
	M.me = UnitName("player") or ""
	M.LoadIgnores()
	M.LoadAlerts()
	M.LoadAlias()
	M.LoadTpls()
	M.SetCap()
	M.chanOK = {}
	if not M.watching then
		M.watching = true
		C.Watch("finder.", M.OnKey)
		T.OnAccent(M.Repaint)
	end
	SUI.WhenSafe(M.BuildAccess)
	M.UpdateAccess()
	M.Sync()
end

function M.Disable()
	M.on = false
	if M.win then M.win:Hide() end
	if M.postwin then M.postwin:Hide() end
	if M.lw1 then M.lw1:Hide() end
	if M.lw2 then M.lw2:Hide() end
	if M.lw3 then M.lw3:Hide() end
	if M.helpwin then M.helpwin:Hide() end
	M.hits = 0
	M.UpdateAccess()
	M.Sync()
end

-- ================================================================ declaration
SUI.RegisterCategory("finder", 56)

local function opt(key, typ, order, def, extra)
	local o = { key = "finder." .. key, type = typ, cat = "finder", label = "opt.finder." .. key, tip = "tip.finder." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

SUI.RegisterModule("finder", {
	default = false,
	cost = "medium",
	options = {
		opt("listen", "choice", 10, "auto", { choices = { "auto", "always" }, simple = true }),
		opt("expire", "number", 20, 15, { min = 5, max = 60, step = 5, simple = true }),
		opt("maxads", "number", 30, 200, { min = 20, max = 200, step = 10 }),
		opt("src.channel", "bool", 40, true, { simple = true }),
		opt("src.yell", "bool", 50, true),
		opt("src.say", "bool", 60, false),
		opt("group", "bool", 70, true, { simple = true }),
		opt("sort", "choice", 80, "new", { choices = { "new", "level", "places" }, simple = true }),
		opt("look", "choice", 90, "cards", { choices = { "cards", "compact" }, simple = true }),
		opt("colors", "choice", 100, "kind", { choices = { "kind", "accent", "mono" } }),
		opt("stripe", "bool", 110, true),
		opt("fade", "bool", 120, true),
		opt("rows", "number", 130, 7, { min = 3, max = 12, step = 1 }),
		opt("scale", "number", 140, 1, { min = 0.8, max = 1.4, step = 0.05 }),
		opt("sound", "choice", 150, "tell", { choices = { "off", "tell", "raid", "quest" }, simple = true }),
		opt("alertprint", "bool", 160, true),
		opt("btn", "choice", 170, "both", { choices = { "both", "minimap", "social", "none" }, simple = true }),
		opt("angle", "number", 180, 200, { min = 0, max = 355, step = 5 }),
		opt("postcool", "number", 190, 60, { min = 30, max = 300, step = 10 }),
		opt("postlang", "choice", 200, "auto", { choices = { "auto", "fr", "en" } }),
		opt("poststyle", "choice", 210, "classic", { choices = { "classic", "short", "full" } }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : listes gerees par la fenetre.
SUI.Config.Register({ ["finder.ignored"] = "", ["finder.alerts"] = "", ["finder.tpls"] = ";;;", ["finder.chanskip"] = "",
	["finder.alias"] = "", ["finder.quick"] = "" })

SUI.RegisterCommand("lfg", function(rest) M.Command(rest or "") end, "help.finder")
