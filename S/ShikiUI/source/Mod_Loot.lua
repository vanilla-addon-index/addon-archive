-- ShikiUI Loot : butin et jets (equivalent configurable de LootBlare + une partie de RollFor ; aucune ligne copiee).
-- Cout declare : LIGHT. Aucun OnUpdate : une seule minuterie partagee (SUI.Every), allumee SEULEMENT pendant un jet (0,25 s) ; hors jet le module
-- ne coute que ses evenements de discussion (un test de sous-chaine par message). Aucune table creee en combat : 60 emplacements de jets,
-- 20 lignes de fenetre et un anneau d'historique (jusqu'a 100 entrees) sont prealloues une fois (SUI.WhenSafe) puis reutilises.
-- FONCTIONS :
--  1. Fenetre des jets : s'ouvre quand UN SEUL objet (qualite >= loot.minquality) est lie dans un avertissement de raid (loot.trigger = ml |
--     warning | any), classe les jets "/roll" par type (plafond du jet : SR, MS, OS, TM, reglables) puis par valeur ; seul le premier jet de
--     chaque joueur compte (loot.firstonly) ; minuteur ; gagnant mis en avant ; annonce du gagnant (option, seulement si c'est nous qui avons
--     lance le jet ou si nous sommes le chef de butin) ; boutons de jet (RandomRoll(1, plafond)).
--  2. Regles de jet de groupe (Besoin / Cupidite / Passer) par qualite (loot.autogreen / autoblue / autoepic) et PAR OBJET (/sui loot rule).
--     RIEN d'automatique par defaut. La confirmation des objets lies au ramassage (CONFIRM_LOOT_ROLL) n'est donnee que si loot.autoconfirm.
--  3. Historique : qui a recu quoi (CHAT_MSG_LOOT), anneau en memoire (rien n'est ecrit dans ShikiUIDB hors regles : regle 11 de MODULES.md).
--  4. Fenetre de BUTIN compacte (remplace LootFrame quand loot.lootframe) : une seule fenetre, une ligne par objet (icone au lisere de
--     qualite, nom colore, bouton Prendre / Donner), pages au-dela de loot.lootrows lignes, echelle loot.lootscale, deplacable (Mover).
--     Chef de butin : le bouton ouvre la liste des candidats (GetMasterLootCandidate, couleur de classe) puis GiveMasterLoot ; confirmation
--     en deux clics pour les objets epiques (loot.lootconfirm). LootFrame n'est pas modifie : seuls ses evenements lui sont retires
--     (UnregisterEvent) et rendus a la coupure.
--  5. Fenetre des JETS DE GROUPE (remplace GroupLootFrame1-4 quand loot.rollframe) : une pile bornee (loot.rollmax) de lignes icone + nom +
--     minuteur + boutons Besoin / Cupidite / (Desenchantement) / Passer, et les choix des autres joueurs lus dans CHAT_MSG_LOOT (motifs
--     construits depuis les chaines LOOT_ROLL_* du client, avec repli FR / EN). loot.keepblizz garde AUSSI les fenetres Blizzard.
--     GroupLootFrame_OpenNewFrame est enveloppee a la main (pas de hooksecurefunc en 1.12) ; la confirmation des objets lies reste celle de Blizzard.
-- SOURCES (relevees dans les addons installes, jamais executees ici) : LootBlare (plafonds 101 / 100 / 99 / 50, un seul objet lie dans
--  l'avertissement, premier jet seul, motif "(%S+) rolls (%d+) %((%d+)%-(%d+)%)", GetLootMethod, RandomRoll(1, plafond)) ; RollFor (GetLootMethod,
--  GetMasterLootCandidate) ; _LazyPig (START_LOOT_ROLL, GetLootRollItemInfo, GetLootRollItemLink, RollOnLoot(id, 0 passer / 1 besoin / 2 cupidite),
--  CONFIRM_LOOT_ROLL).
-- NON VERIFIE EN JEU : evenements LOOT_OPENED / LOOT_SLOT_CLEARED / OPEN_MASTER_LOOT_LIST de LootFrame, GetLootThreshold, GetMasterLootCandidate
--  (1 a 40), chaines LOOT_ROLL_* (repli FR devine), retours 6 a 8 de GetLootRollItemInfo (Desenchantement), rollTime en ms ; tout (aucun client lance) ; RandomRoll (observe dans LootBlare / RollFor, extension Turtle) ; ConfirmLootRoll(id, type) ;
--  le 3e retour de GetLootMethod (indice de raid) ; les textes localises RANDOM_ROLL_RESULT / LOOT_ITEM* (repli sur l'anglais).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local floor, ceil = math.floor, math.ceil
local mmax = math.max
local sfind, ssub, slen, sgsub, slower, sformat = string.find, string.sub, string.len, string.gsub, string.lower, string.format

local M = {}
SUI.Loot = M

local MAXR = 60            -- jets gardes par objet (un raid de 40 + marge)
local MAXROWS = 20         -- lignes de la fenetre
local MAXHIST = 100        -- entrees de l'historique
local TICK = 0.25
local RTYPES = { "sr", "ms", "os", "tm" }
local ROLLNUM = { pass = 0, need = 1, greed = 2 }
-- couleurs de qualite d'objet portees par les liens du jeu (donnees du jeu)
local QCOL = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
M.RTYPES = RTYPES
M.ROLLNUM = ROLLNUM

M.on = false
M.state = "idle"       -- idle | rolling | ended
M.view = "rolls"       -- rolls | history
M.rolls = {}           -- emplacements reutilises { name, roll, typ, seq, class }
M.order = {}           -- references triees (type, valeur decroissante, ordre d'arrivee)
M.n = 0
M.seen = {}            -- nom -> true (premier jet seul)
M.seq = 0
M.lk = { link = "", str = "", name = "", q = -1, id = nil }     -- dernier lien analyse
M.item = { link = "", str = "", name = "", q = -1, id = nil }   -- objet en cours de jet
M.startAt, M.endAt, M.closeAt = 0, 0, 0
M.mine = false
M.winner = nil
M.rules = {}           -- id d'objet -> "need" | "greed" | "pass"
M.nrules = 0
M.auto = {}            -- rollID -> type de jet choisi automatiquement (pour la confirmation)
M.hist = {}            -- anneau { t, who, link, q }
M.hcount = 0           -- entrees valides
M.hhead = 0            -- derniere ecrite
M.rollPat = nil        -- motif localise des jets
M.lootPats = {}        -- motifs localises de l'historique
M.chatEvents = {}      -- evenements de discussion actuellement ecoutes
M.lootOn = false

-- fenetre de butin compacte
local LWMAX = 15           -- lignes preallouees de la fenetre de butin
local LSLOTS = 40          -- emplacements de butin memorises
local NCAND = 40           -- candidats du chef de butin
local LW_W, LROW_H = 250, 24
local LFEV = { "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED", "OPEN_MASTER_LOOT_LIST", "UPDATE_MASTER_LOOT_LIST" }
M.lw = nil             -- fenetre
M.lslots = {}          -- numeros d'emplacements visibles (preallouee)
M.lcount = 0
M.lpage = 0
M.lootOpen = false
M.lsel = nil           -- emplacement choisi (chef de butin)
M.armed = nil          -- candidat arme (confirmation en deux clics)
M.cls = {}             -- nom -> jeton de classe (reutilisee)
M.lreg = {}            -- evenements retires a LootFrame (pour les lui rendre)
M.lgrab = false

-- fenetre des jets de groupe
local RRMAX = 8            -- emplacements de jets de groupe
local RRES = 40            -- choix gardes par jet
local RR_W = 300
local RNAMES = 4           -- joueurs cites par ligne de resultats
local KKEY = { "need", "greed", "pass", "de" }                   -- sorte de choix 1 a 4
local KIND = { need = 1, greed = 2, pass = 3, de = 4 }
local RNUM = { pass = 0, need = 1, greed = 2, de = 3 }           -- numero donne a RollOnLoot
local RTOKIND = { [0] = 3, [1] = 1, [2] = 2, [3] = 4 }
local RBTN = { 1, 2, 3, 0 }                                       -- boutons : besoin, cupidite, desenchantement, passer
local RLINE = { 1, 2, 4, 3 }                                      -- lignes de resultats : besoin, cupidite, desenchantement, passer
M.rr = {}              -- emplacements (preallouee)
M.rord = {}            -- ordre d'affichage (preallouee)
M.nrr = 0              -- emplacements utilises
M.rseq = 0
M.rf = nil             -- conteneur
M.rpats = {}           -- motifs des messages de jet
M.wrapped = false

-- ---------------------------------------------------------------- utilitaires
-- Transforme une chaine de format du jeu ("%s rolls %d (%d-%d)") en motif Lua (sans %, dans le texte, seulement les specificateurs).
function M.MakePattern(fmt, loose)
	if type(fmt) ~= "string" then return nil end
	local p = sgsub(fmt, "([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	p = sgsub(p, "%%s", loose and "(.+)" or "(%%S+)")
	p = sgsub(p, "%%d", "(%%d+)")
	return "^" .. p .. "$"
end

local function setText(fs, text)
	if fs.cur ~= text then
		fs.cur = text
		fs:SetText(text)
	end
end

function M.Channel()
	local ch = C.Get("loot.channel")
	if ch == "auto" then
		if GetNumRaidMembers() > 0 then
			if IsRaidLeader() or IsRaidOfficer() then return "RAID_WARNING" end
			return "RAID"
		elseif GetNumPartyMembers() > 0 then
			return "PARTY"
		end
		return "SAY"
	end
	return string.upper(ch)
end

function M.IsPlayerML()
	local method, pid = GetLootMethod()
	return method == "master" and pid == 0
end

-- Le chef de butin est-il cet expediteur ? (LootBlare : indice de groupe ; l'indice de raid en 3e retour est NON VERIFIE)
function M.IsSenderML(sender)
	local method, pid, rid = GetLootMethod()
	if method ~= "master" then return false end
	if pid == 0 then return sender == UnitName("player") end
	if pid and UnitName("party" .. pid) == sender then return true end
	if rid and rid > 0 and UnitName("raid" .. rid) == sender then return true end
	return false
end

-- Premier lien d'objet du message dans M.lk ; retourne le nombre de liens trouves.
function M.ParseLinks(msg)
	local n, pos = 0, 1
	local lk = M.lk
	while true do
		local s, e, col, str, name = sfind(msg, "|c(%x%x%x%x%x%x%x%x)|H(item:[%d:%-]+)|h%[(.-)%]|h|r", pos)
		if not s then break end
		n = n + 1
		if n == 1 then
			lk.link = ssub(msg, s, e)
			lk.str = str
			lk.name = name
			lk.q = QCOL[slower(ssub(col, 3))] or -1
			local _, _, id = sfind(str, "^item:(%d+)")
			lk.id = tonumber(id)
		end
		pos = e + 1
	end
	return n
end

function M.ClassOf(who)
	if who == UnitName("player") then
		local _, tok = UnitClass("player")
		return tok
	end
	for i = 1, GetNumRaidMembers() do
		local name, _, _, _, _, file = GetRaidRosterInfo(i)
		if name == who then return file end
	end
	for i = 1, GetNumPartyMembers() do
		if UnitName("party" .. i) == who then
			local _, tok = UnitClass("party" .. i)
			return tok
		end
	end
	return nil
end

-- Type d'un jet : plafond egal a celui d'un type (le minimum doit etre 1) ; 0 si inconnu.
function M.TypeOf(lo, hi)
	if lo ~= 1 then return 0 end
	for i = 1, 4 do
		if hi == C.Get("loot.cap." .. RTYPES[i]) then return i end
	end
	return 0
end

local function before(a, b)
	if a.typ ~= b.typ then return a.typ < b.typ end
	if a.roll ~= b.roll then return a.roll > b.roll end
	return a.seq < b.seq
end

-- ---------------------------------------------------------------- jets
function M.ResetRolls()
	M.n = 0
	for i = getn(M.order), 1, -1 do M.order[i] = nil end
	for k, _ in pairs(M.seen) do M.seen[k] = nil end
	M.winner = nil
end

function M.AddRoll(who, roll, lo, hi)
	if M.state ~= "rolling" then return false end
	local typ = M.TypeOf(lo, hi)
	if typ == 0 then return false end
	if C.Get("loot.firstonly") then
		if M.seen[who] then return false end
		M.seen[who] = true
	end
	if M.n >= MAXR then return false end
	M.n = M.n + 1
	M.seq = M.seq + 1
	local s = M.rolls[M.n]
	if not s then M.n = M.n - 1 return false end
	s.name, s.roll, s.typ, s.seq, s.class = who, roll, typ, M.seq, M.ClassOf(who)
	local pos = M.n
	for j = 1, M.n - 1 do
		if before(s, M.order[j]) then pos = j break end
	end
	for j = M.n - 1, pos, -1 do M.order[j + 1] = M.order[j] end
	M.order[pos] = s
	M.Refresh()
	return true
end

function M.OnSystem(ev, msg)
	if not msg then return end
	if M.nrr > 0 then M.OnRollChat(ev, msg) end
	if M.state ~= "rolling" then return end
	local who, roll, lo, hi
	local p = M.rollPat
	if p then
		local _, _, a, b, c, d = sfind(msg, p)
		if a then who, roll, lo, hi = a, b, c, d end
	end
	if not who then
		local _, _, a, b, c, d = sfind(msg, "^(%S+) rolls (%d+) %((%d+)%-(%d+)%)$")
		who, roll, lo, hi = a, b, c, d
	end
	if who then M.AddRoll(who, tonumber(roll), tonumber(lo), tonumber(hi)) end
end

-- Un objet est lie : ouvre le jet. mine = c'est nous qui l'avons lance.
function M.Begin(mine)
	local lk = M.lk
	if lk.q >= 0 and lk.q < C.Get("loot.minquality") then return false end
	local now = GetTime()
	if M.state == "rolling" and M.item.str == lk.str and now - M.startAt < 2 then return false end
	M.ResetRolls()
	local it = M.item
	it.link, it.str, it.name, it.q, it.id = lk.link, lk.str, lk.name, lk.q, lk.id
	M.state = "rolling"
	M.startAt = now
	M.endAt = now + C.Get("loot.rolltime")
	M.mine = mine and true or false
	M.view = "rolls"
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(TICK, M.Tick, "loot.tick")
	M.Show()
	M.Refresh()
		-- son d'alerte : une session de jet commence, regarde la fenetre (RaidWarning : eprouve chez OctoWow)
		if C.Get("loot.sound") ~= false and PlaySoundFile then pcall(PlaySoundFile, "Sound\\Interface\\RaidWarning.wav") end
	return true
end

function M.End()
	if M.state ~= "rolling" then return end
	M.state = "ended"
	local w = M.order[1]
	M.winner = w
	M.closeAt = GetTime() + 10
	if w then
		local typeLabel = L("choice.loot.type." .. RTYPES[w.typ])
		if C.Get("loot.announcewinner") and (M.mine or M.IsPlayerML()) then
			SendChatMessage(L("msg.loot.winner", w.name, M.item.link, w.roll, typeLabel), M.Channel())
		end
	else
		SUI.Print(L("msg.loot.norolls", M.item.link))
	end
	M.Refresh()
end

function M.Stop()
	if M.state == "rolling" then M.End() end
end

function M.Close()
	M.state = "idle"
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	if M.frame then M.frame:Hide() end
end

function M.Tick()
	local now = GetTime()
	if M.state == "rolling" then
		if now >= M.endAt then M.End() else M.RefreshBar(now) end
	elseif M.state == "ended" then
		if C.Get("loot.autoclose") and now >= M.closeAt then M.Close() end
	else
		M.Close()
	end
end

-- Annonce un objet a tout le monde puis ouvre le jet chez nous.
function M.Announce(msg)
	if M.ParseLinks(msg or "") ~= 1 then
		SUI.Print(L("msg.loot.needlink"))
		return false
	end
	local text = L("msg.loot.announce", M.lk.link, C.Get("loot.rolltime")) .. " " ..
		L("msg.loot.announcecaps", C.Get("loot.cap.sr"), C.Get("loot.cap.ms"), C.Get("loot.cap.os"), C.Get("loot.cap.tm"))
	SendChatMessage(text, M.Channel())
	M.Begin(true)
	return true
end

-- Messages de discussion : un lien dans un avertissement de raid ouvre le jet.
function M.OnChat(ev, msg, sender)
	if not msg or not C.Get("loot.window") then return end
	if not sfind(msg, "|Hitem:", 1, true) then return end
	local trig = C.Get("loot.trigger")
	if trig == "ml" and not M.IsSenderML(sender) then return end
	if trig == "warning" and ev ~= "CHAT_MSG_RAID_WARNING" and ev ~= "CHAT_MSG_RAID_LEADER" then return end
	if M.ParseLinks(msg) ~= 1 then return end
	if sfind(msg, "^No one has nee") or sfind(msg, "has been sent to", 1, true) or sfind(msg, " received ", 1, true) then return end
	M.Begin(sender == UnitName("player"))
end

-- ---------------------------------------------------------------- regles de jet de groupe
local function ruleString()
	local parts = ""
	for id, act in pairs(M.rules) do
		if parts ~= "" then parts = parts .. "," end
		parts = parts .. id .. "=" .. act
	end
	return parts
end

function M.ReadRules()
	for k, _ in pairs(M.rules) do M.rules[k] = nil end
	M.nrules = 0
	local s = C.Get("loot.rules") or ""
	for id, act in string.gfind(s, "(%d+)=(%a+)") do
		if ROLLNUM[act] ~= nil and M.nrules < 60 then
			M.rules[tonumber(id)] = act
			M.nrules = M.nrules + 1
		end
	end
end

function M.SetRule(id, act)
	id = tonumber(id)
	if not id then return false end
	if act == "clear" then
		if M.rules[id] then M.nrules = M.nrules - 1 end
		M.rules[id] = nil
	elseif ROLLNUM[act] ~= nil then
		if not M.rules[id] then
			if M.nrules >= 60 then return false end
			M.nrules = M.nrules + 1
		end
		M.rules[id] = act
	else
		return false
	end
	C.SetBase("loot.rules", ruleString())
	return true
end

local QKEY = { [2] = "loot.autogreen", [3] = "loot.autoblue", [4] = "loot.autoepic" }

-- Action decidee pour un objet : regle par objet d'abord, puis regle de qualite ; nil = ne rien faire.
function M.RuleFor(id, quality)
	if id and M.rules[id] then return M.rules[id] end
	local key = QKEY[quality]
	if key then
		local a = C.Get(key)
		if a ~= "none" then return a end
	end
	return nil
end

function M.OnStartRoll(ev, rollID, rollTime)
	if not rollID then return end
	local _, name, _, quality = GetLootRollItemInfo(rollID)
	local link = GetLootRollItemLink(rollID)
	local _, _, id = sfind(link or "", "item:(%d+)")
	local act = M.RuleFor(tonumber(id), quality)
	if act then
		RollOnLoot(rollID, ROLLNUM[act])
		M.auto[rollID] = ROLLNUM[act]
		if C.Get("loot.automsg") then SUI.Print(L("msg.loot.auto", L("choice.loot.act." .. act), link or name or "?")) end
	end
	local row = M.Claim(rollID, rollTime)
	if row and act then M.RRMine(row, ROLLNUM[act]) end
end

function M.OnConfirm(ev, rollID, rollType)
	if not rollID or not C.Get("loot.autoconfirm") then return end
	if M.auto[rollID] ~= nil and M.auto[rollID] == rollType then
		local f = getglobal("ConfirmLootRoll")
		if f then f(rollID, rollType) end
		M.auto[rollID] = nil
	end
end

-- ---------------------------------------------------------------- historique
function M.HistAdd(who, link, q)
	if q >= 0 and q < C.Get("loot.histquality") then return end
	local size = C.Get("loot.historysize")
	local h = M.hhead + 1
	if h > size then h = 1 end
	M.hhead = h
	local e = M.hist[h]
	if not e then return end
	e.t, e.who, e.link, e.q = GetTime(), who, link, q
	if M.hcount < size then M.hcount = M.hcount + 1 end
end

-- i-eme entree depuis la plus recente (1 = derniere) ; nil si absente.
function M.HistGet(i)
	if i < 1 or i > M.hcount then return nil end
	local size = C.Get("loot.historysize")
	local idx = M.hhead - (i - 1)
	if idx < 1 then idx = idx + size end
	return M.hist[idx]
end

function M.HistClear()
	M.hcount = 0
	M.hhead = 0
	M.Refresh()
end

function M.OnLoot(ev, msg)
	if not msg or not C.Get("loot.history") then return end
	local who, link
	local pats = M.lootPats
	for i = 1, getn(pats) do
		local _, _, a, b = sfind(msg, pats[i][1])
		if a then
			if pats[i][2] then who, link = UnitName("player"), a else who, link = a, b end
			break
		end
	end
	if not who then return end
	if M.ParseLinks(link) < 1 then return end
	M.HistAdd(who, M.lk.link, M.lk.q)
	if M.view == "history" then M.Refresh() end
end

function M.BuildPatterns()
	M.rollPat = M.MakePattern(getglobal("RANDOM_ROLL_RESULT"))
	local list = M.lootPats
	for i = getn(list), 1, -1 do list[i] = nil end
	local self1 = getglobal("LOOT_ITEM_SELF")
	local other = getglobal("LOOT_ITEM")
	if type(self1) == "string" then tinsert(list, { M.MakePattern(self1, true), true }) end
	if type(other) == "string" then tinsert(list, { M.MakePattern(other, true), false }) end
	tinsert(list, { "^You receive loot: (.+)%.$", true })
	tinsert(list, { "^(.+) receives? loot: (.+)%.$", false })
end

-- ---------------------------------------------------------------- fenetre
local function rowColor(fs, r, g, b)
	fs:SetTextColor(r, g, b, 1)
end

function M.RefreshBar(now)
	if not M.frame then return end
	local total = C.Get("loot.rolltime")
	local left = M.endAt - (now or GetTime())
	if left < 0 then left = 0 end
	M.bar:SetMinMaxValues(0, total)
	M.bar:SetValue(left)
	setText(M.bar.text, sformat("%d", math.ceil(left)))
end

function M.Refresh()
	local f = M.frame
	if not f or not f:IsShown() then return end
	local it = M.item
	local rows = C.Get("loot.rows")
	local shown = 0
	if M.view == "history" then
		setText(f.title, L("msg.loot.history"))
		rowColor(f.title, T.c.text[1], T.c.text[2], T.c.text[3])
		M.bar:Hide()
		f.icon:Hide()
	else
		setText(f.title, it.name ~= "" and it.name or L("msg.loot.history"))
		local gi = getglobal("GetItemIcon")
		local tex = (gi and it.id) and gi(it.id) or nil
		if tex then f.icon:SetTexture(tex) ; f.icon:Show() else f.icon:Hide() end
		if it.q >= 0 then
			local r, g, b = GetItemQualityColor(it.q)
			rowColor(f.title, r, g, b)
		else
			rowColor(f.title, T.c.text[1], T.c.text[2], T.c.text[3])
		end
		if M.state == "rolling" then
			M.bar:Show()
			M.RefreshBar()
		else
			M.bar:Hide()
		end
	end
	for i = 1, MAXROWS do
		local row = f.rows[i]
		if i > rows then
			row:Hide()
		else
			local a, b, c, cr, cg, cb
			if M.view == "history" then
				local e = M.HistGet(i)
				if e then
					a, b, c = e.who, "", e.link
					cr, cg, cb = T.c.text[1], T.c.text[2], T.c.text[3]
				end
			else
				local s = M.order[i]
				if s then
					a, b, c = s.name, L("choice.loot.type." .. RTYPES[s.typ]), sformat("%d", s.roll)
					local cls = s.class and getglobal("RAID_CLASS_COLORS")
					cls = cls and cls[s.class]
					if cls then
						cr, cg, cb = cls.r, cls.g, cls.b      -- style:ok couleur de classe (donnee du jeu)
					elseif M.winner == s then
						cr, cg, cb = T.c.good[1], T.c.good[2], T.c.good[3]
					else
						cr, cg, cb = T.c.text[1], T.c.text[2], T.c.text[3]
					end
				end
			end
			if a then
				shown = shown + 1
				setText(row.name, a)
				setText(row.kind, b)
				setText(row.val, c)
				rowColor(row.name, cr, cg, cb)
				if M.view == "rolls" and M.winner == M.order[i] then
					rowColor(row.val, T.c.good[1], T.c.good[2], T.c.good[3])
				else
					rowColor(row.val, T.c.text[1], T.c.text[2], T.c.text[3])
				end
				row:Show()
			else
				row:Hide()
			end
		end
	end
	-- hauteur adaptee au contenu : pas de grand vide quand peu de jets
	local btns = C.Get("loot.buttons") and M.view == "rolls"
	local want = 46 + mmax(shown, 3) * 15 + (btns and 26 or 4)
	if M.frame:GetHeight() ~= want then M.frame:SetHeight(want) end
end

function M.Show()
	if not M.frame then return end
	M.ApplyOptions()
	M.frame:Show()
end

function M.ToggleHistory()
	if not M.frame then return end
	if M.view == "history" then
		M.view = "rolls"
		if M.state == "idle" then M.Close() return end
	else
		M.view = "history"
		M.frame:Show()
	end
	M.ApplyOptions()
	M.Refresh()
end

function M.ApplyOptions()
	local f = M.frame
	if not f then return end
	local rows = C.Get("loot.rows")
	local btns = C.Get("loot.buttons") and M.view == "rolls"
	for i = 1, 4 do
		if btns then f.roll[i]:Show() else f.roll[i]:Hide() end
	end
	f:SetHeight(46 + rows * 15 + (btns and 26 or 4))
	for i = 1, MAXROWS do
		f.rows[i]:ClearAllPoints()
		f.rows[i]:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(40 + (i - 1) * 15))
	end
	for i = 1, 4 do
		f.roll[i]:ClearAllPoints()
		f.roll[i]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8 + (i - 1) * 62, 6)
	end
	if M.frame:IsShown() then M.Refresh() end
end

-- Aspect commun (loot.bartex / loot.shape / loot.font / loot.fontsize) : police des textes, texture et forme des barres de minuteur.
local function lookText(fs, size)
	if SUI.Look then SUI.Look.ApplyText(fs, "loot", size) end
end

local function lookBar(bar, h)
	if SUI.Look then SUI.Look.ApplyBar(bar, "loot", { height = h, segments = 10 }) end
end

-- Dimensions de la fenetre de jets : largeur selon les 6 colonnes, hauteur selon les lignes affichees.
local COLW, COLGAP = 74, 6
function M.WinW()
	return 10 + 74 + getn(M.BLESS) * (COLW + COLGAP) + 10
end
function M.WinH()
	local vis = 0
	for i = 1, MAXROWS do
		local row = M.frame and M.frame.rows and M.frame.rows[i]
		if row and row.IsShown and row:IsShown() then vis = vis + 1 end
	end
	if vis < 3 then vis = 3 end
	return 46 + vis * 15 + (C.Get("loot.buttons") and 26 or 4)
end

function M.Build()
	if M.frame then return end
	local f = T.Panel(UIParent, 280, 220)
	f:SetFrameStrata("MEDIUM")
	f:EnableMouse(true)
	f:Hide()
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetWidth(20)
	f.icon:SetHeight(20)
	f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon:Hide()
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -7)
	f.close = T.Button(f, "x", 18, 16, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	f.hist = T.Button(f, L("msg.loot.btn.hist"), 44, 16, function() M.ToggleHistory() end)
	f.hist:SetPoint("RIGHT", f.close, "LEFT", -3, 0)
	f.title:SetWidth(148)
	-- survol de la zone titre / icone : infobulle du stat de l'objet en cours
	f.tip = CreateFrame("Button", nil, f)
	f.tip:SetWidth(210)
	f.tip:SetHeight(24)
	f.tip:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	f.tip:EnableMouse(true)
	f.tip:SetScript("OnEnter", function()
		if M.item and (M.item.id or (M.item.link ~= "" and string.find(M.item.link, "|H", 1, true))) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			-- lien standard item:ID en priorite ; certains addons (AtlasLoot) interceptent SetHyperlink et
			-- rejettent les liens de chat bruts : pcall pour ne jamais afficher d erreur a l ecran
			local ok = false
			if M.item.id then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. M.item.id) end
			if not ok and string.find(M.item.link, "|H", 1, true) then
				pcall(GameTooltip.SetHyperlink, GameTooltip, M.item.link)
			end
			GameTooltip:Show()
		end
	end)
	f.tip:SetScript("OnLeave", function() GameTooltip:Hide() end)
	lookText(f.title, 12)
	-- engrenage : ouvre les reglages du module, a gauche du bouton Historique
	T.GearButton(f, "loot", { size = 16, point = "TOPRIGHT", x = -72, y = -5, title = L("msg.loot.gear"),
		onCreate = function(g)
			g:ClearAllPoints()
			g:SetPoint("RIGHT", f.hist, "LEFT", -3, 0)
		end })
	local bar = T.Bar(f)
	bar:SetWidth(264)
	bar:SetHeight(10)
	bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
	bar.text = T.Text(bar, 9, T.c.text, "CENTER")
	bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	lookBar(bar, 10)
	lookText(bar.text, 9)
	M.bar = bar
	f.rows = {}
	for i = 1, MAXROWS do
		local row = CreateFrame("Frame", nil, f)
		row:SetWidth(264)
		row:SetHeight(14)
		row.name = T.Text(row, 11, T.c.text, "LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.name:SetWidth(130)
		row.kind = T.Text(row, 11, T.c.dim, "LEFT")
		row.kind:SetPoint("LEFT", row, "LEFT", 134, 0)
		row.val = T.Text(row, 11, T.c.text, "RIGHT")
		row.val:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		lookText(row.name, 11)
		lookText(row.kind, 11)
		lookText(row.val, 11)
		row:Hide()
		f.rows[i] = row
	end
	f.roll = {}
	for i = 1, 4 do
		local t = RTYPES[i]
		local b = T.Button(f, L("choice.loot.type." .. t), 58, 18, function()
			RandomRoll(1, C.Get("loot.cap." .. t))
		end)
		f.roll[i] = b
	end
	M.frame = f
	SUI.Layout.Register(f, "loot", "CENTER", 0, 120)
	local li = SUI.Layout.items["loot"]
	if li then li.mul = function() return C.Get("loot.scale") / 100 end end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- fenetre de butin compacte (corps, chef de butin)
function M.LootThreshold()
	local f = getglobal("GetLootThreshold")
	local q = f and f()
	if type(q) ~= "number" then return 2 end
	return q
end

function M.LootRows()
	local n = C.Get("loot.lootrows")
	if n > LWMAX then n = LWMAX end
	if n < 1 then n = 1 end
	return n
end

-- Emplacements du butin qui contiennent un objet ou de l'argent (comme LootFrame_Update).
function M.CollectSlots()
	local c = 0
	local n = GetNumLootItems()
	for slot = 1, n do
		if c < LSLOTS and (LootSlotIsItem(slot) or LootSlotIsCoin(slot)) then
			c = c + 1
			M.lslots[c] = slot
		end
	end
	M.lcount = c
end

function M.LootIsMaster()
	local method = GetLootMethod()
	return method == "master" and M.IsPlayerML()
end

function M.RefreshLoot()
	local f = M.lw
	if not f then return end
	M.CollectSlots()
	local per = M.LootRows()
	local total = M.lcount
	local pages = ceil(total / per)
	if pages < 1 then pages = 1 end
	if M.lpage >= pages then M.lpage = pages - 1 end
	if M.lpage < 0 then M.lpage = 0 end
	local ml = M.LootIsMaster()
	local thr = M.LootThreshold()
	local shown = 0
	for i = 1, LWMAX do
		local row = f.rows[i]
		local idx = M.lpage * per + i
		if i > per or idx > total then
			row.slot = nil
			row:Hide()
		else
			local slot = M.lslots[idx]
			local tex, name, qty, q = GetLootSlotInfo(slot)
			local isItem = LootSlotIsItem(slot)
			row.slot = slot
			if tex then row.icon:SetTexture(tex) end
			name = sgsub(name or "?", "\n", " ")
			if isItem and qty and qty > 1 then name = name .. " x" .. qty end
			setText(row.name, name)
			if isItem and q and q >= 0 then
				local r, g, b = GetItemQualityColor(q)
				row.name:SetTextColor(r, g, b, 1)
				row.qb:SetVertexColor(r, g, b, 1)
			else
				row.name:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
				row.qb:SetVertexColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
			end
			if ml and isItem and q and q >= thr then
				T.SetButtonText(row.btn, L("msg.loot.give"))
			else
				T.SetButtonText(row.btn, L("msg.loot.take"))
			end
			row:Show()
			shown = shown + 1
		end
	end
	setText(f.title, L("msg.loot.win", total))
	if pages > 1 then
		f.prev:Show()
		f.next:Show()
		f.pg:Show()
		setText(f.pg, L("msg.loot.page", M.lpage + 1, pages))
	else
		f.prev:Hide()
		f.next:Hide()
		f.pg:Hide()
	end
	f:SetHeight(28 + shown * LROW_H + (pages > 1 and 22 or 0) + 6)
end

function M.CloseCand()
	M.armed = nil
	if M.lw then M.lw.cand:Hide() end
end

-- Cache la fenetre ; close = fermer aussi le butin cote jeu (bouton, coupure du module).
function M.LootHide(close)
	local was = M.lootOpen
	M.lootOpen = false
	M.lsel = nil
	M.armed = nil
	if M.lw then
		M.lw.cand:Hide()
		M.lw:Hide()
	end
	if close and was then CloseLoot() end
end

function M.LootOpen()
	if not M.lw then return end
	M.lootOpen = true
	M.lpage = 0
	M.lsel = nil
	M.CloseCand()
	M.RefreshLoot()
	if M.lcount == 0 then
		M.LootHide(true)
		return
	end
	M.lw:Show()
end

function M.LootCleared(slot)
	if not M.lootOpen then return end
	if M.lsel == slot then M.CloseCand() end
	M.RefreshLoot()
	if M.lcount == 0 then M.LootHide(true) end
end

-- Pose le texte et la couleur des boutons de candidats (le bouton arme demande une confirmation).
function M.CandLabels()
	local cf = M.lw and M.lw.cand
	if not cf then return end
	for i = 1, NCAND do
		local b = cf.btns[i]
		if b:IsShown() then
			if M.armed == b then
				setText(b.label, L("msg.loot.sure"))
				b.label:SetTextColor(T.c.warn[1], T.c.warn[2], T.c.warn[3], 1)
			else
				setText(b.label, b.cname)
				local cc = b.ccls and getglobal("RAID_CLASS_COLORS")
				cc = cc and cc[b.ccls]
				if cc then
					b.label:SetTextColor(cc.r, cc.g, cc.b, 1)       -- style:ok couleur de classe (donnee du jeu)
				else
					b.label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
				end
			end
		end
	end
end

-- Liste des candidats du chef de butin pour un emplacement.
function M.OpenCand(slot)
	local f = M.lw
	if not f then return end
	local cf = f.cand
	M.lsel = slot
	M.armed = nil
	local cls = M.cls
	for k, _ in pairs(cls) do cls[k] = nil end
	for i = 1, GetNumRaidMembers() do
		local nm, _, _, _, _, file = GetRaidRosterInfo(i)
		if nm then cls[nm] = file end
	end
	for i = 1, GetNumPartyMembers() do
		local nm = UnitName("party" .. i)
		if nm then
			local _, tok = UnitClass("party" .. i)
			cls[nm] = tok
		end
	end
	local me = UnitName("player")
	if me then
		local _, tok = UnitClass("player")
		cls[me] = tok
	end
	local _, item, _, q = GetLootSlotInfo(slot)
	local c = 0
	for i = 1, NCAND do
		local nm = GetMasterLootCandidate(i)
		if nm then
			c = c + 1
			local b = cf.btns[c]
			local rw = floor((c - 1) / 4)
			local col = (c - 1) - rw * 4
			b.cidx = i
			b.cname = nm
			b.ccls = cls[nm]
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", cf, "TOPLEFT", 6 + col * 76, -(28 + rw * 18))
			b:Show()
		end
	end
	for i = c + 1, NCAND do
		cf.btns[i].cidx = nil
		cf.btns[i]:Hide()
	end
	if c == 0 then
		setText(cf.title, L("msg.loot.nocand"))
		cf.title:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
		cf:SetHeight(40)
	else
		setText(cf.title, L("msg.loot.giveto", (sgsub(item or "?", "\n", " "))))
		if q and q >= 0 then
			local r, g, b = GetItemQualityColor(q)
			cf.title:SetTextColor(r, g, b, 1)
		end
		cf:SetHeight(28 + ceil(c / 4) * 18 + 6)
	end
	M.CandLabels()
	cf:Show()
end

local function candClick(b)
	local slot, idx = M.lsel, b.cidx
	if not slot or not idx then return end
	if C.Get("loot.lootconfirm") then
		local _, _, _, q = GetLootSlotInfo(slot)
		if q and q >= 4 and M.armed ~= b then
			M.armed = b
			M.CandLabels()
			return
		end
	end
	GiveMasterLoot(slot, idx)
	M.CloseCand()
end

-- Clic sur une ligne : majuscule = lien dans le chat ; chef de butin + objet au-dessus du seuil = liste des candidats ; sinon on ramasse.
function M.LootAct(row)
	local slot = row and row.slot
	if not slot then return end
	local sh = getglobal("IsShiftKeyDown")
	if sh and sh() then
		local lk = GetLootSlotLink(slot)
		local eb = getglobal("ChatFrameEditBox")
		if lk and eb and eb:IsVisible() then eb:Insert(lk) end
		return
	end
	local _, _, _, q = GetLootSlotInfo(slot)
	if M.LootIsMaster() and LootSlotIsItem(slot) and q and q >= M.LootThreshold() then
		M.OpenCand(slot)
	else
		M.lsel = slot
		LootSlot(slot)
	end
end

local function lootBtnClick(b) M.LootAct(b.owner) end
local function lootRowClick() M.LootAct(this) end
local function lootClose() M.LootHide(true) end
local function lootPage(b)
	M.lpage = M.lpage + b.dir
	M.RefreshLoot()
end

local function itemTip(owner, str)
	local gt = getglobal("GameTooltip")
	if gt and str and str ~= "" then
		gt:SetOwner(owner, "ANCHOR_RIGHT")
		pcall(gt.SetHyperlink, gt, str)   -- pcall : AtlasLoot intercepte les tooltips
	end
end

local function lootEnter()
	local row = this
	row.hl:Show()
	if row.slot and LootSlotIsItem(row.slot) then
		local lk = GetLootSlotLink(row.slot)
		local _, _, str = sfind(lk or "", "(item:[%d:%-]+)")
		itemTip(row, str)
	end
end

local function lootLeave()
	this.hl:Hide()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

function M.BuildLoot()
	if M.lw then return end
	local f = T.Panel(UIParent, LW_W, 80)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:Hide()
	f.title = T.Text(f, 12, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
	f.title:SetWidth(LW_W - 60)
	f.close = T.Button(f, "x", 18, 16, lootClose)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
	lookText(f.title, 12)
	T.GearButton(f, "loot", { size = 16, point = "TOPRIGHT", x = -26, y = -6, title = L("msg.loot.gear") })
	f.rows = {}
	for i = 1, LWMAX do
		local row = CreateFrame("Button", nil, f)
		row:SetWidth(LW_W - 12)
		row:SetHeight(LROW_H)
		row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -(28 + (i - 1) * LROW_H))
		row:RegisterForClicks("LeftButtonUp")
		row.hl = row:CreateTexture(nil, "BACKGROUND")
		row.hl:SetAllPoints(row)
		row.hl:SetTexture(T.tex.white)
		row.hl:SetVertexColor(T.c.inset[1], T.c.inset[2], T.c.inset[3], 1)
		row.hl:Hide()
		row.qb = row:CreateTexture(nil, "BORDER")
		row.qb:SetTexture(T.tex.white)
		row.qb:SetWidth(22)
		row.qb:SetHeight(22)
		row.qb:SetPoint("LEFT", row, "LEFT", 1, 0)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetWidth(20)
		row.icon:SetHeight(20)
		row.icon:SetPoint("CENTER", row.qb, "CENTER", 0, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.name = T.Text(row, 11, T.c.text, "LEFT")
		row.name:SetPoint("LEFT", row, "LEFT", 30, 0)
		row.name:SetWidth(LW_W - 12 - 30 - 62)
		row.name:SetHeight(12)
		lookText(row.name, 11)
		row.btn = T.Button(row, L("msg.loot.take"), 56, 18, lootBtnClick)
		row.btn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.btn.owner = row
		row:SetScript("OnClick", lootRowClick)
		row:SetScript("OnEnter", lootEnter)
		row:SetScript("OnLeave", lootLeave)
		row:Hide()
		f.rows[i] = row
	end
	f.prev = T.Button(f, "<", 22, 16, lootPage)
	f.prev.dir = -1
	f.prev:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
	f.next = T.Button(f, ">", 22, 16, lootPage)
	f.next.dir = 1
	f.next:SetPoint("LEFT", f.prev, "RIGHT", 4, 0)
	f.pg = T.Text(f, 10, T.c.dim, "LEFT")
	f.pg:SetPoint("LEFT", f.next, "RIGHT", 6, 0)
	-- candidats du chef de butin
	local cf = T.Panel(f, 4 * 76 + 8, 60)
	cf:SetPoint("TOPLEFT", f, "TOPRIGHT", 3, 0)
	cf:EnableMouse(true)
	cf:Hide()
	cf.title = T.Text(cf, 11, T.c.text, "LEFT")
	cf.title:SetPoint("TOPLEFT", cf, "TOPLEFT", 8, -8)
	cf.title:SetWidth(4 * 76 - 30)
	cf.title:SetHeight(12)
	cf.close = T.Button(cf, "x", 18, 16, function() M.CloseCand() end)
	cf.close:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -5, -5)
	cf.btns = {}
	for i = 1, NCAND do
		local b = T.Button(cf, "", 72, 16, candClick)
		b:Hide()
		cf.btns[i] = b
	end
	f.cand = cf
	M.lw = f
	SUI.Layout.Register(f, "lootwin", "CENTER", -300, 40)
	local it = SUI.Layout.items["lootwin"]
	if it then it.mul = function() return C.Get("loot.lootscale") / 100 end end
	SUI.Layout.Apply("lootwin")
	if SUI.Mover and SUI.Mover.Register then SUI.Mover.Register("lootwin", f, { label = "mod.loot.mv.win" }) end
	M.GrabLoot()
end

-- Retire a LootFrame ses evenements (et les lui rend) : pas de fenetre Blizzard en double ; rien n'est modifie dans LootFrame lui-meme.
function M.GrabLoot()
	local lf = getglobal("LootFrame")
	if not lf then return end
	local want = M.on and M.lw ~= nil and C.Get("loot.lootframe")
	if want and not M.lgrab then
		for i = 1, getn(LFEV) do
			if lf:IsEventRegistered(LFEV[i]) then
				M.lreg[LFEV[i]] = true
				lf:UnregisterEvent(LFEV[i])
			end
		end
		M.lgrab = true
	elseif not want and M.lgrab then
		for i = 1, getn(LFEV) do
			if M.lreg[LFEV[i]] then
				lf:RegisterEvent(LFEV[i])
				M.lreg[LFEV[i]] = nil
			end
		end
		M.lgrab = false
	end
end

function M.OnLootEv(ev, a1)
	if not M.lw or not C.Get("loot.lootframe") then return end
	if ev == "LOOT_OPENED" then
		M.LootOpen()
	elseif ev == "LOOT_SLOT_CLEARED" then
		M.LootCleared(a1)
	elseif ev == "LOOT_CLOSED" then
		M.LootHide(false)
	elseif ev == "OPEN_MASTER_LOOT_LIST" then
		if M.lootOpen and M.lsel then M.OpenCand(M.lsel) end
	elseif ev == "UPDATE_MASTER_LOOT_LIST" then
		if M.lootOpen and M.lsel and M.lw.cand:IsShown() then M.OpenCand(M.lsel) end
	end
end

-- ---------------------------------------------------------------- fenetre des jets de groupe
-- Motif Lua + ordre des arguments depuis une chaine de format du jeu ("%s a choisi %s", "%2$s ... %1$s").
-- Retourne motif, ord (ord[j] = numero d'argument du j-eme groupe), nombre de groupes.
function M.MakeFmtPattern(fmt)
	if type(fmt) ~= "string" then return nil end
	local out, pos, n = "", 1, 0
	local ord = {}
	while true do
		local s, e, num, kind = sfind(fmt, "%%(%d*)%$?([sd])", pos)
		if not s then break end
		out = out .. sgsub(ssub(fmt, pos, s - 1), "([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
		n = n + 1
		if kind == "d" then out = out .. "(%d+)" else out = out .. "(.+)" end
		if num ~= "" then ord[n] = tonumber(num) else ord[n] = n end
		pos = e + 1
	end
	out = out .. sgsub(ssub(fmt, pos), "([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
	if n == 0 or n > 3 then return nil end
	return "^" .. out .. "$", ord, n
end

local function addFmt(fmt, typ, sub, who, item, val, isSelf)
	local pat, ord = M.MakeFmtPattern(fmt)
	if not pat then return end
	local inv = {}
	for j = 1, getn(ord) do inv[ord[j]] = j end
	if not inv[item] then return end
	tinsert(M.rpats, { pat = pat, typ = typ, sub = sub, iwho = who and inv[who] or nil, iitem = inv[item], ival = val and inv[val] or nil, self = isSelf })
end

-- motif brut : who / item / val = numeros de groupes du motif
local function addRaw(pat, typ, sub, who, item, val, isSelf)
	tinsert(M.rpats, { pat = pat, typ = typ, sub = sub, iwho = who, iitem = item, ival = val, self = isSelf })
end

function M.BuildRollPatterns()
	local list = M.rpats
	for i = getn(list), 1, -1 do list[i] = nil end
	-- ORDRE : les messages a la 2e personne et "tout le monde a passe" avant les motifs generiques ("(.+) passed on", "(.+) won")
	-- chaines du client (toute langue) : arguments = joueur, objet ; ou valeur, objet, joueur
	addFmt(getglobal("LOOT_ROLL_NEED_SELF"), "sel", "need", nil, 1, nil, true)
	addFmt(getglobal("LOOT_ROLL_GREED_SELF"), "sel", "greed", nil, 1, nil, true)
	addFmt(getglobal("LOOT_ROLL_DISENCHANT_SELF"), "sel", "de", nil, 1, nil, true)
	addFmt(getglobal("LOOT_ROLL_PASSED_SELF"), "sel", "pass", nil, 1, nil, true)
	addFmt(getglobal("LOOT_ROLL_YOU_WON"), "won", nil, nil, 1, nil, true)
	addFmt(getglobal("LOOT_ROLL_ALL_PASSED"), "allpass", nil, nil, 1, nil, false)
	addFmt(getglobal("LOOT_ROLL_NEED"), "sel", "need", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_GREED"), "sel", "greed", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_DISENCHANT"), "sel", "de", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_PASSED"), "sel", "pass", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_PASSED_AUTO"), "sel", "pass", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_PASSED_AUTO_FEMALE"), "sel", "pass", 1, 2, nil, false)
	addFmt(getglobal("LOOT_ROLL_ROLLED_NEED"), "roll", "need", 3, 2, 1, false)
	addFmt(getglobal("LOOT_ROLL_ROLLED_GREED"), "roll", "greed", 3, 2, 1, false)
	addFmt(getglobal("LOOT_ROLL_ROLLED_DE"), "roll", "de", 3, 2, 1, false)
	addFmt(getglobal("LOOT_ROLL_WON"), "won", nil, 1, 2, nil, false)
	-- repli anglais (1.12)
	addRaw("^You have selected Need for: (.+)$", "sel", "need", nil, 1, nil, true)
	addRaw("^You have selected Greed for: (.+)$", "sel", "greed", nil, 1, nil, true)
	addRaw("^You have selected Disenchant for: (.+)$", "sel", "de", nil, 1, nil, true)
	addRaw("^You passed on: (.+)$", "sel", "pass", nil, 1, nil, true)
	addRaw("^You won: (.+)$", "won", nil, nil, 1, nil, true)
	addRaw("^Everyone passed on: (.+)$", "allpass", nil, nil, 1, nil, false)
	addRaw("^(.+) has selected Need for: (.+)$", "sel", "need", 1, 2, nil, false)
	addRaw("^(.+) has selected Greed for: (.+)$", "sel", "greed", 1, 2, nil, false)
	addRaw("^(.+) has selected Disenchant for: (.+)$", "sel", "de", 1, 2, nil, false)
	addRaw("^(.+) passed on: (.+)$", "sel", "pass", 1, 2, nil, false)
	addRaw("^(.+) automatically passed on: (.+) because", "sel", "pass", 1, 2, nil, false)
	addRaw("^Need Roll %- (%d+) for (.+) by (.+)$", "roll", "need", 3, 2, 1, false)
	addRaw("^Greed Roll %- (%d+) for (.+) by (.+)$", "roll", "greed", 3, 2, 1, false)
	addRaw("^Disenchant Roll %- (%d+) for (.+) by (.+)$", "roll", "de", 3, 2, 1, false)
	addRaw("^(.+) won: (.+)$", "won", nil, 1, 2, nil, false)
	-- repli francais (accents absorbes par . et [^:]) : DEVINE, a verifier en jeu
	addRaw("^Vous avez choisi Besoin[^:]*: (.+)$", "sel", "need", nil, 1, nil, true)
	addRaw("^Vous avez choisi Cupidit[^:]*: (.+)$", "sel", "greed", nil, 1, nil, true)
	addRaw("^Vous avez choisi D[^:]*senchantement[^:]*: (.+)$", "sel", "de", nil, 1, nil, true)
	addRaw("^Vous avez pass[^:]*: (.+)$", "sel", "pass", nil, 1, nil, true)
	addRaw("^Vous avez gagn[^:]*: (.+)$", "won", nil, nil, 1, nil, true)
	addRaw("^Tout le monde a pass[^:]*: (.+)$", "allpass", nil, nil, 1, nil, false)
	addRaw("^(.+) a choisi Besoin[^:]*: (.+)$", "sel", "need", 1, 2, nil, false)
	addRaw("^(.+) a choisi Cupidit[^:]*: (.+)$", "sel", "greed", 1, 2, nil, false)
	addRaw("^(.+) a choisi D[^:]*senchantement[^:]*: (.+)$", "sel", "de", 1, 2, nil, false)
	addRaw("^(.+) a pass[^:]*: (.+)$", "sel", "pass", 1, 2, nil, false)
	addRaw("^Jet de [Bb]esoin[^%d]*(%d+) pour (.+) par (.+)$", "roll", "need", 3, 2, 1, false)
	addRaw("^Jet de [Cc]upidit[^%d]*(%d+) pour (.+) par (.+)$", "roll", "greed", 3, 2, 1, false)
	addRaw("^Jet de [Dd][^%d]*senchantement[^%d]*(%d+) pour (.+) par (.+)$", "roll", "de", 3, 2, 1, false)
	addRaw("^(.+) a gagn[^:]*: (.+)$", "won", nil, 1, 2, nil, false)
end

function M.RRFind(id)
	for i = 1, RRMAX do
		local s = M.rr[i]
		if s and s.used and s.id == id then return s end
	end
	return nil
end

-- Ligne de resultats d'une sorte de choix : "Besoin (3) : Alice 87, Bob 45 +1" ; nil si personne.
local function lineFor(s, kind)
	local cnt = 0
	for i = 1, s.nres do
		if s.res[i].kind == kind then cnt = cnt + 1 end
	end
	if cnt == 0 then return nil end
	for i = 1, s.nres do s.mark[i] = false end
	local txt, shown = "", 0
	while shown < RNAMES and shown < cnt do
		local best = nil
		for i = 1, s.nres do
			local e = s.res[i]
			if e.kind == kind and not s.mark[i] then
				if not best or e.roll > s.res[best].roll then best = i end
			end
		end
		if not best then break end
		s.mark[best] = true
		local e = s.res[best]
		if txt ~= "" then txt = txt .. ", " end
		txt = txt .. e.name
		if e.roll > 0 then txt = txt .. " " .. e.roll end
		shown = shown + 1
	end
	if cnt > shown then txt = txt .. " +" .. (cnt - shown) end
	return L("choice.loot.act." .. KKEY[kind]) .. " (" .. cnt .. ") : " .. txt
end

function M.RRTime(s, now)
	local r = s.frame
	if not r then return end
	local left = s.tEnd - (now or GetTime())
	if left < 0 then left = 0 end
	if s.winner then
		local tx = L("msg.loot.roll.won", s.winner)
		if s.wroll and s.wroll > 0 then tx = L("msg.loot.roll.won2", s.winner, s.wroll) end
		setText(r.time, tx)
		r.time:SetTextColor(T.c.good[1], T.c.good[2], T.c.good[3], 1)
	elseif s.allpass then
		setText(r.time, L("msg.loot.roll.allpass"))
		r.time:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	elseif s.done then
		setText(r.time, L("msg.loot.roll.ended"))
		r.time:SetTextColor(T.c.dim[1], T.c.dim[2], T.c.dim[3], 1)
	else
		setText(r.time, sformat("%d", ceil(left)))
		r.time:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
	end
	if s.done then
		r.bar:SetValue(0)
	else
		r.bar:SetMinMaxValues(0, s.total)
		r.bar:SetValue(left)
	end
end

function M.RRRefresh(s)
	local r = s.frame
	if not r or not s.used then return end
	local cnt = ""
	if s.count and s.count > 1 then cnt = " x" .. s.count end
	setText(r.name, s.name .. cnt)
	local cr, cg, cb = GetItemQualityColor(s.q)
	r.name:SetTextColor(cr, cg, cb, 1)
	r.qb:SetVertexColor(cr, cg, cb, 1)
	if s.tex then r.icon:SetTexture(s.tex) end
	-- boutons : seuls ceux qui sont permis, repartis sur la largeur
	local nb = 0
	for k = 1, 4 do
		local b = r.btn[k]
		local show = true
		if b.rnum == 1 then show = s.canNeed elseif b.rnum == 2 then show = s.canGreed elseif b.rnum == 3 then show = s.canDE end
		if show then
			nb = nb + 1
			b.pos = nb
		else
			b.pos = 0
			b:Hide()
		end
	end
	local w = floor((RR_W - 12 - (nb - 1) * 3) / nb)
	for k = 1, 4 do
		local b = r.btn[k]
		if b.pos > 0 then
			b:SetWidth(w)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", r, "TOPLEFT", 6 + (b.pos - 1) * (w + 3), -36)
			local chosen = (s.mine ~= nil and s.mine == b.rnum)
			T.SetSelected(b, chosen)
			if s.confirmed or s.done then
				b.disabled = true
				if chosen then b:SetAlpha(1) else b:SetAlpha(0.45) end
			else
				b.disabled = false
				b:SetAlpha(1)
			end
			b:Show()
		end
	end
	-- lignes de resultats (seulement celles qui ont des joueurs)
	local y = 58
	for k = 1, 4 do
		local ln = r.line[RLINE[k]]
		local tx = lineFor(s, RLINE[k])
		if tx then
			setText(ln, tx)
			ln:ClearAllPoints()
			ln:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -y)
			ln:Show()
			y = y + 12
		else
			ln:Hide()
		end
	end
	r:SetHeight(y + 4)
	M.RRTime(s)
end

function M.RRLayout()
	local rf = M.rf
	if not rf then return end
	local ord = M.rord
	local n = 0
	for i = 1, RRMAX do
		local s = M.rr[i]
		if s.used then
			n = n + 1
			local j = n
			while j > 1 and ord[j - 1].seq > s.seq do
				ord[j] = ord[j - 1]
				j = j - 1
			end
			ord[j] = s
		end
	end
	local y = 0
	for k = 1, n do
		local r = ord[k].frame
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", rf, "TOPLEFT", 0, -y)
		y = y + r:GetHeight() + 3
		r:Show()
	end
	for k = n + 1, RRMAX do ord[k] = false end
	for i = 1, RRMAX do
		local s = M.rr[i]
		if not s.used then s.frame:Hide() end
	end
	-- Hauteur FIXE (1) : le coin bas-gauche enregistre ne bouge pas et les lignes pendent dessous (ancrage TOPLEFT). Une hauteur
	-- suivant le contenu (y) faisait SAUTER la premiere ligne a chaque jet ajoute ou termine.
	if n > 0 then
		rf:Show()
	else
		rf:Hide()
	end
end

function M.RRFree(s)
	if not s.used then return end
	s.used = false
	s.nres = 0
	s.winner, s.mine = nil, nil
	if s.frame then s.frame:Hide() end
	M.nrr = M.nrr - 1
	if M.nrr <= 0 then
		M.nrr = 0
		if M.rtask then
			SUI.Cancel(M.rtask)
			M.rtask = nil
		end
		SUI.Off("CHAT_MSG_LOOT", M.OnRollChat)
	end
	M.RRLayout()
end

function M.RRClear()
	for i = 1, RRMAX do
		local s = M.rr[i]
		if s and s.used then M.RRFree(s) end
	end
	if M.rf then M.rf:Hide() end
end

-- Prend un jet de groupe en charge : retourne son emplacement, ou nil (module/fenetre coupe, limite atteinte, objet inconnu) -> Blizzard le montre.
function M.Claim(id, ms)
	if not id or not M.on or not M.rf or not C.Get("loot.rollframe") then return nil end
	local s = M.RRFind(id)
	if s then return s end
	local tex, name, count, quality, bop, cn, cg, cd = GetLootRollItemInfo(id)
	if not name then return nil end
	local free, oldest
	local used = 0
	for i = 1, RRMAX do
		local x = M.rr[i]
		if x.used then
			used = used + 1
			if x.done and (not oldest or x.seq < oldest.seq) then oldest = x end
		elseif not free then
			free = x
		end
	end
	if used >= C.Get("loot.rollmax") then
		if not oldest then return nil end
		M.RRFree(oldest)
		free = oldest
	end
	if not free then return nil end
	s = free
	M.rseq = M.rseq + 1
	local link = GetLootRollItemLink(id)
	local _, _, str, iid = sfind(link or "", "(item:(%d+)[%d:%-]*)")
	local total = tonumber(ms) or 60000
	if total > 1000 then total = total / 1000 end
	local now = GetTime()
	s.used, s.id, s.seq = true, id, M.rseq
	s.name, s.count, s.q, s.tex = name, count or 1, quality or 1, tex
	s.str, s.itemid = str or "", tonumber(iid)
	s.total, s.tEnd = total, now + total
	s.done, s.doneAt, s.mine, s.confirmed, s.winner, s.wroll, s.allpass = false, 0, nil, false, nil, 0, false
	s.nres = 0
	s.canNeed = not (cn == false or cn == 0)
	s.canGreed = not (cg == false or cg == 0)
	s.canDE = (cd == true or cd == 1)
	M.nrr = M.nrr + 1
	if M.nrr == 1 then
		if M.rtask then SUI.Cancel(M.rtask) end
		M.rtask = SUI.Every(TICK, M.RRTick, "loot.rolltick")
		SUI.On("CHAT_MSG_LOOT", M.OnRollChat)
	end
	M.RRRefresh(s)
	M.RRLayout()
	return s
end

function M.RRNote(s, who, kind, roll)
	if not who then return end
	local e = nil
	for i = 1, s.nres do
		if s.res[i].name == who then
			e = s.res[i]
			break
		end
	end
	if not e then
		if s.nres >= RRES then return end
		s.nres = s.nres + 1
		e = s.res[s.nres]
		e.name, e.roll = who, 0
	end
	e.kind = kind
	if roll and roll > 0 then e.roll = roll end
end

-- Notre propre choix (clic, regle automatique ou message du jeu).
function M.RRMine(s, rnum)
	s.mine = rnum
	M.RRNote(s, UnitName("player"), RTOKIND[rnum] or 3, 0)
	M.RRRefresh(s)
	M.RRLayout()
end

local function rollClick(b)
	local s = b.owner
	if not s or not s.used or s.done then return end
	RollOnLoot(s.id, b.rnum)
	M.RRMine(s, b.rnum)
end

local function rollTipEnter()
	itemTip(this, this.owner and this.owner.str)
end

local function rollTipLeave()
	local gt = getglobal("GameTooltip")
	if gt then gt:Hide() end
end

function M.OnCancelRoll(ev, id)
	local s = id and M.RRFind(id)
	if s and not s.done then
		s.done = true
		s.doneAt = GetTime()
		M.RRRefresh(s)
	end
end

function M.RRTick()
	local now = GetTime()
	local hold = C.Get("loot.rollhold")
	for i = 1, RRMAX do
		local s = M.rr[i]
		if s.used then
			if not s.done and now >= s.tEnd then
				s.done = true
				s.doneAt = now
				M.RRRefresh(s)
			end
			if s.done and now - s.doneAt >= hold then
				M.RRFree(s)
			else
				M.RRTime(s, now)
			end
		end
	end
end

-- Ligne correspondant a un objet : un jet encore ouvert d'abord (le plus ancien), sinon le plus recent deja termine.
function M.RRMatch(iid)
	local open, closed
	for i = 1, RRMAX do
		local s = M.rr[i]
		if s.used and s.itemid == iid then
			if not s.done then
				if not open or s.seq < open.seq then open = s end
			elseif not closed or s.seq > closed.seq then
				closed = s
			end
		end
	end
	return open or closed
end

local function pick(i, a, b, c)
	if i == 1 then return a elseif i == 2 then return b elseif i == 3 then return c end
	return nil
end

function M.RRApply(p, c1, c2, c3)
	local item = pick(p.iitem, c1, c2, c3)
	local _, _, iid = sfind(item or "", "item:(%d+)")
	iid = tonumber(iid)
	if not iid then return end
	local s = M.RRMatch(iid)
	if not s then return end
	local who = p.iwho and pick(p.iwho, c1, c2, c3) or nil
	if p.self then who = UnitName("player") end
	local typ = p.typ
	if typ == "sel" then
		M.RRNote(s, who, KIND[p.sub], 0)
		if p.self then
			s.mine = RNUM[p.sub]
			s.confirmed = true
		end
	elseif typ == "roll" then
		M.RRNote(s, who, KIND[p.sub], tonumber(pick(p.ival, c1, c2, c3)))
	elseif typ == "won" then
		s.winner = who
		s.wroll = 0
		for i = 1, s.nres do
			if s.res[i].name == who then s.wroll = s.res[i].roll end
		end
		s.done = true
		s.doneAt = GetTime()
	elseif typ == "allpass" then
		s.allpass = true
		s.done = true
		s.doneAt = GetTime()
	end
	M.RRRefresh(s)
	M.RRLayout()
end

-- Messages du jeu (CHAT_MSG_LOOT, CHAT_MSG_SYSTEM) : choix et jets des autres joueurs.
function M.OnRollChat(ev, msg)
	if M.nrr == 0 or not msg or not sfind(msg, "|Hitem:", 1, true) then return end
	local pats = M.rpats
	for i = 1, getn(pats) do
		local p = pats[i]
		local _, _, c1, c2, c3 = sfind(msg, p.pat)
		if c1 then
			M.RRApply(p, c1, c2, c3)
			return
		end
	end
end

-- GroupLootFrame_OpenNewFrame (appelee par UIParent_OnEvent) est enveloppee a la main : notre fenetre prend le jet, Blizzard le reste.
function M.WrapBlizz()
	if M.wrapped then return end
	local orig = getglobal("GroupLootFrame_OpenNewFrame")
	if type(orig) ~= "function" then return end
	M.wrapped = true
	M.origOpen = orig
	setglobal("GroupLootFrame_OpenNewFrame", function(id, ms)
		if M.on and M.rf and not C.Get("loot.keepblizz") and M.Claim(id, ms) then return end
		return M.origOpen(id, ms)
	end)
end

function M.BuildRollRow(parent, s)
	local r = T.Panel(parent, RR_W, 80)
	r:Hide()
	s.frame = r
	r.ib = CreateFrame("Button", nil, r)
	r.ib:SetWidth(28)
	r.ib:SetHeight(28)
	r.ib:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -6)
	r.ib.owner = s
	r.ib:SetScript("OnEnter", rollTipEnter)
	r.ib:SetScript("OnLeave", rollTipLeave)
	r.qb = r.ib:CreateTexture(nil, "BORDER")
	r.qb:SetTexture(T.tex.white)
	r.qb:SetAllPoints(r.ib)
	r.icon = r.ib:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(26)
	r.icon:SetHeight(26)
	r.icon:SetPoint("CENTER", r.ib, "CENTER", 0, 0)
	r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	r.name = T.Text(r, 12, T.c.text, "LEFT")
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 40, -7)
	r.name:SetWidth(RR_W - 40 - 110)
	r.name:SetHeight(14)
	lookText(r.name, 12)
	r.time = T.Text(r, 11, T.c.text, "RIGHT")
	r.time:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -8)
	r.time:SetWidth(104)
	r.time:SetHeight(12)
	lookText(r.time, 11)
	r.bar = T.Bar(r)
	r.bar:SetWidth(RR_W - 40 - 6)
	r.bar:SetHeight(6)
	r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 40, -24)
	lookBar(r.bar, 6)
	r.btn = {}
	for k = 1, 4 do
		local rn = RBTN[k]
		local lab = "de"
		if rn == 0 then lab = "pass" elseif rn == 1 then lab = "need" elseif rn == 2 then lab = "greed" end
		local b = T.Button(r, L("choice.loot.act." .. lab), 60, 18, rollClick)
		b.rnum = rn
		b.owner = s
		b.pos = 0
		r.btn[k] = b
	end
	r.line = {}
	r.line[1] = T.Text(r, 10, T.c.good, "LEFT")
	r.line[2] = T.Text(r, 10, T.c.warn, "LEFT")
	r.line[3] = T.Text(r, 10, T.c.dim, "LEFT")
	r.line[4] = T.Text(r, 10, T.c.text, "LEFT")
	for k = 1, 4 do
		r.line[k]:SetWidth(RR_W - 12)
		r.line[k]:SetHeight(12)
		lookText(r.line[k], 10)
		r.line[k]:Hide()
	end
end

function M.BuildRolls()
	if M.rf then return end
	M.Prealloc()
	local rf = CreateFrame("Frame", nil, UIParent)
	rf:SetWidth(RR_W)
	rf:SetHeight(1)
	rf:SetFrameStrata("DIALOG")
	rf:Hide()
	for i = 1, RRMAX do M.BuildRollRow(rf, M.rr[i]) end
	M.rf = rf
	SUI.Layout.Register(rf, "lootroll", "CENTER", 0, 200)
	local it = SUI.Layout.items["lootroll"]
	if it then it.mul = function() return C.Get("loot.rollscale") / 100 end end
	SUI.Layout.Apply("lootroll")
	if SUI.Mover and SUI.Mover.Register then SUI.Mover.Register("lootroll", rf, { label = "mod.loot.mv.roll" }) end
	M.WrapBlizz()
end

-- Tables reutilisees : creees une seule fois, hors combat.
function M.Prealloc()
	if M.allocated then return end
	M.allocated = true
	for i = 1, MAXR do M.rolls[i] = { name = "", roll = 0, typ = 0, seq = 0 } end
	for i = 1, MAXHIST do M.hist[i] = { t = 0, who = "", link = "", q = -1 } end
	for i = 1, LSLOTS do M.lslots[i] = 0 end
	for i = 1, RRMAX do
		local s = { used = false, id = 0, seq = 0, nres = 0, res = {}, mark = {}, name = "", count = 1, q = 1, str = "", total = 60, tEnd = 0,
			done = false, doneAt = 0, confirmed = false, wroll = 0, allpass = false, canNeed = true, canGreed = true, canDE = false }
		for j = 1, RRES do
			s.res[j] = { name = "", kind = 0, roll = 0 }
			s.mark[j] = false
		end
		M.rr[i] = s
		M.rord[i] = false
	end
end

-- ---------------------------------------------------------------- evenements et reglages
local CHAT_ALL = { "CHAT_MSG_RAID_WARNING", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }

function M.RegisterChat()
	for i = 1, getn(CHAT_ALL) do SUI.Off(CHAT_ALL[i], M.OnChat) end
	if not M.on then return end
	local trig = C.Get("loot.trigger")
	local n = (trig == "any") and 5 or 2
	for i = 1, n do SUI.On(CHAT_ALL[i], M.OnChat) end
end

function M.RegisterHistory()
	SUI.Off("CHAT_MSG_LOOT", M.OnLoot)
	if M.on and C.Get("loot.history") then SUI.On("CHAT_MSG_LOOT", M.OnLoot) end
end

function M.OnKey(key, value)
	if key == nil or key == "loot.rules" then M.ReadRules() end
	if key == nil or key == "loot.trigger" then M.RegisterChat() end
	if key == nil or key == "loot.history" then M.RegisterHistory() end
	if (key == nil or key == "loot.window") and not C.Get("loot.window") and M.frame and M.frame:IsShown() then M.Close() end
	if key == nil or key == "loot.historysize" then
		local size = C.Get("loot.historysize")
		if M.hcount > size then M.hcount = size end
		if M.hhead > size then M.hhead = 0 M.hcount = 0 end
	end
	if key == nil or key == "loot.lootframe" then
		M.GrabLoot()
		if not C.Get("loot.lootframe") then M.LootHide(true) end
	end
	if (key == nil or key == "loot.lootscale") and SUI.Layout.items["lootwin"] then SUI.Layout.Apply("lootwin") end
	if (key == nil or key == "loot.rollscale") and SUI.Layout.items["lootroll"] then SUI.Layout.Apply("lootroll") end
	if (key == nil or key == "loot.scale") and SUI.Layout.items["loot"] then SUI.Layout.Apply("loot") end
	if key == "loot.rollframe" and not C.Get("loot.rollframe") then M.RRClear() end
	if key == "loot.lootrows" and M.lootOpen then M.RefreshLoot() end
	M.ApplyOptions()
end

function M.Enable()
	M.on = true
	M.ReadRules()
	M.BuildPatterns()
	SUI.WhenSafe(M.Prealloc)
	M.BuildRollPatterns()
	SUI.WhenSafe(M.Build)
	SUI.WhenSafe(M.BuildLoot)
	SUI.WhenSafe(M.BuildRolls)
	SUI.On("CHAT_MSG_SYSTEM", M.OnSystem)
	SUI.On("START_LOOT_ROLL", M.OnStartRoll)
	SUI.On("CANCEL_LOOT_ROLL", M.OnCancelRoll)
	SUI.On("CONFIRM_LOOT_ROLL", M.OnConfirm)
	for i = 1, getn(LFEV) do SUI.On(LFEV[i], M.OnLootEv) end
	M.GrabLoot()
	M.RegisterChat()
	M.RegisterHistory()
	if not M.watching then
		M.watching = true
		C.Watch("loot.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("CHAT_MSG_SYSTEM", M.OnSystem)
	SUI.Off("START_LOOT_ROLL", M.OnStartRoll)
	SUI.Off("CANCEL_LOOT_ROLL", M.OnCancelRoll)
	SUI.Off("CONFIRM_LOOT_ROLL", M.OnConfirm)
	for i = 1, getn(LFEV) do SUI.Off(LFEV[i], M.OnLootEv) end
	M.RegisterChat()
	M.RegisterHistory()
	M.Close()
	M.LootHide(true)
	M.GrabLoot()
	M.RRClear()
	M.ResetRolls()
	for k, _ in pairs(M.auto) do M.auto[k] = nil end
end

-- ---------------------------------------------------------------- commandes
local function actLabel(a) return L("choice.loot.act." .. a) end

function M.Command(rest)
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = ssub(rest, sp + 1)
	end
	word = slower(word)
	if word == "start" then
		M.Announce(arg)
	elseif word == "stop" then
		M.Stop()
	elseif word == "show" then
		if M.frame then
			M.view = (M.state == "idle") and "history" or "rolls"
			M.frame:Show()
			M.ApplyOptions()
		end
	elseif word == "hide" then
		M.Close()
	elseif word == "history" then
		local n = tonumber(arg) or 10
		if M.hcount == 0 then SUI.Print(L("msg.loot.hist.none")) end
		for i = 1, n do
			local e = M.HistGet(i)
			if not e then break end
			SUI.Print(L("msg.loot.hist.line", e.who, e.link))
		end
	elseif word == "clear" then
		M.HistClear()
		SUI.Print(L("msg.loot.cleared"))
	elseif word == "rule" then
		local target, act = arg, ""
		local s2 = sfind(arg, " ([%a]+)$")
		if s2 then
			act = ssub(arg, s2 + 1)
			target = ssub(arg, 1, s2 - 1)
		end
		act = slower(act)
		local _, _, id = sfind(target, "item:(%d+)")
		if not id then _, _, id = sfind(target, "^%s*(%d+)%s*$") end
		if id and M.SetRule(id, act) then
			if act == "clear" then SUI.Print(L("msg.loot.rule.cleared", id)) else SUI.Print(L("msg.loot.rule.set", id, actLabel(act))) end
		else
			SUI.Print(L("msg.loot.rule.bad"))
		end
	elseif word == "rules" then
		if arg == "clear" then
			C.SetBase("loot.rules", "")
			SUI.Print(L("msg.loot.rules.none"))
			return
		end
		if M.nrules == 0 then SUI.Print(L("msg.loot.rules.none")) end
		for id, act in pairs(M.rules) do SUI.Print(L("msg.loot.rules.line", id, actLabel(act))) end
	else
		SUI.Print(L("msg.loot.status", M.state, M.hcount, M.nrules))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("loot", 30)

local function opt(key, typ, order, def, extra)
	local o = { key = "loot." .. key, type = typ, cat = "loot", label = "opt.loot." .. key, tip = "tip.loot." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local function actText(o, v) return L("choice.loot.act." .. v) end
local function trigText(o, v) return L("choice.loot.trig." .. v) end
local function chanText(o, v) return L("choice.loot.chan." .. v) end
local ACTS = { "none", "need", "greed", "pass" }

local LOOT_OPTIONS = {
		opt("window", "bool", 10, true, { simple = true }),
		opt("trigger", "choice", 20, "ml", { choices = { "ml", "warning", "any" }, choiceText = trigText, simple = true }),
		opt("minquality", "number", 30, 2, { min = 0, max = 5, step = 1, simple = true }),
		opt("rolltime", "number", 40, 15, { min = 5, max = 60, step = 1, simple = true }),
		opt("autoclose", "bool", 50, true),
		opt("firstonly", "bool", 60, true),
		opt("buttons", "bool", 70, true, { simple = true }),
		opt("rows", "number", 80, 10, { min = 4, max = 20, step = 1 }),
		opt("cap.sr", "number", 90, 101, { min = 2, max = 1000, step = 1 }),
		opt("cap.ms", "number", 100, 100, { min = 2, max = 1000, step = 1 }),
		opt("cap.os", "number", 110, 99, { min = 2, max = 1000, step = 1 }),
		opt("cap.tm", "number", 120, 50, { min = 2, max = 1000, step = 1 }),
		opt("announcewinner", "bool", 130, false, { simple = true }),
		opt("channel", "choice", 140, "auto", { choices = { "auto", "raid", "party", "say" }, choiceText = chanText }),
		opt("history", "bool", 150, true, { simple = true }),
		opt("historysize", "number", 160, 50, { min = 10, max = 100, step = 10 }),
		opt("histquality", "number", 170, 2, { min = 0, max = 5, step = 1 }),
		opt("autogreen", "choice", 180, "none", { choices = ACTS, choiceText = actText, simple = true }),
		opt("autoblue", "choice", 190, "none", { choices = ACTS, choiceText = actText }),
		opt("autoepic", "choice", 200, "none", { choices = ACTS, choiceText = actText }),
		opt("autoconfirm", "bool", 210, false),
		opt("automsg", "bool", 220, true),
		opt("lootframe", "bool", 300, true, { simple = true }),
		opt("lootrows", "number", 310, 8, { min = 3, max = 15, step = 1 }),
		opt("lootscale", "number", 320, 100, { min = 60, max = 150, step = 10 }),
		opt("lootconfirm", "bool", 330, true),
		opt("rollframe", "bool", 340, true, { simple = true }),
		opt("rollmax", "number", 350, 4, { min = 1, max = 8, step = 1 }),
		opt("rollscale", "number", 360, 100, { min = 60, max = 150, step = 10 }),
		opt("scale", "number", 365, 100, { min = 60, max = 150, step = 10 }),
		opt("icon", "bool", 366, true, { simple = true }),
		opt("iconsize", "number", 367, 20, { min = 14, max = 32, step = 2 }),
		opt("sound", "bool", 368, true, { simple = true }),
		opt("rollhold", "number", 370, 4, { min = 2, max = 30, step = 1 }),
		opt("keepblizz", "bool", 380, false),
}
-- Options communes du socle : texture et forme des barres de minuteur des jets, police et taille des textes.
if SUI.Look then
	local lo = SUI.Look.Options("loot", { bar = true, shape = true, font = true, cat = "loot", order = 820 })
	for i = 1, getn(lo) do tinsert(LOOT_OPTIONS, lo[i]) end
end

SUI.RegisterModule("loot", {
	default = false,
	cost = "light",
	options = LOOT_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnee (pas un reglage de menu) : regles par objet "id=action,..." ; modifiee par /sui loot rule, ecrite dans le profil.
SUI.Config.Register({ ["loot.rules"] = "" })

-- Equivalents pfUI : modules "loot" et "roll" (releves dans pfUI\modules) ; ShikiUI attend tant que pfUI les fait tourner.
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.loot then SUI.Migrate.MAP.loot = { "loot", "roll" } end

-- Mode Raid : plus de lignes (liste de jets plus longue).
SUI.Config.AddPreset("raid", "*", { ["loot.rows"] = 16 })

SUI.RegisterCommand("loot", function(rest) M.Command(rest or "") end, "help.loot")
