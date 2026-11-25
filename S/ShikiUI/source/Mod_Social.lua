-- ShikiUI Social : auto-invitation, marquage automatique et acceptation / refus automatiques (equivalent configurable d'AutoInvite,
-- d'AutoMarker et d'une partie de LazyPig ; reecrit, aucune ligne copiee). Aucun cadre : tout se regle par le menu et /sui social.
-- Cout declare : LIGHT. Chaque evenement n'est ecoute que si l'option qui en a besoin est active (SUI.On / SUI.Off a chaque changement de
-- reglage) : aucun evenement ecoute par defaut. Aucune creation de table dans un gestionnaire ; rien du tout en combat pour les messages de
-- discussion (l'auto-invitation attend la fin du combat). Le marquage reste a quelques appels d'API par survol (etat du groupe mis en cache).
-- SECURITE : TOUT est coupe par defaut. L'auto-invitation se remet a zero a chaque connexion (social.invite.reset) pour ne pas inviter
--  n'importe qui sans s'en souvenir. Les acceptations / refus automatiques affichent un AVERTISSEMENT quand on les active. Maintenir
--  MAJ (Shift) enfonce suspend toute decision automatique (invitation, duel, convocation, resurrection) : la fenetre normale reste.
-- AUTO-INVITATION : un message EXACTEMENT egal au mot-cle (social.keyword, "inv" par defaut, sans tenir compte de la casse), en chuchotement
--  ou en discussion de guilde, invite l'expediteur s'il n'est pas deja dans le groupe, pas ignore, pas invite depuis moins de social.invite.cool
--  secondes, et si l'on peut inviter (chef de groupe, chef ou officier de raid). Groupe plein : conversion en raid si social.invite.raid.
-- MARQUAGE : regles donnees par l'UTILISATEUR (/sui social mark add <nom> <icone>), jamais de donnees inventees : au survol ou a la selection
--  d'un monstre hostile de ce nom qui n'a pas d'icone, pose l'icone, si l'on est chef / officier (ou chef de groupe).
-- MOTS-CLES : social.keyword peut contenir plusieurs mots separes par ';' (le premier est le mot principal, M.keyword). FILTRES : listes blanche et
--  noire (social.invite.white / .black, noms separes par ';') et social.invite.filter (tous / guilde / guilde et amis / liste blanche seulement) :
--  liste noire = jamais invite ; liste blanche = toujours autorise. Tout se gere dans la page du menu (liste editable) ou par /sui social.
-- AUTOMATISMES (style LazyPig) : accepter les invitations de groupe (guilde / amis / tous), refuser celles des inconnus, refuser les duels,
--  refuser les invitations de guilde, accepter la convocation (3 s avant la fin), accepter la resurrection d'un membre du groupe.
-- SOURCES (relevees dans AutoInvite, AutoMarkerOW et _LazyPig installes, jamais executees ici) : PARTY_INVITE_REQUEST (arg1 = nom),
--  AcceptGroup, StaticPopup_Hide("PARTY_INVITE"), DUEL_REQUESTED + CancelDuel, RESURRECT_REQUEST + AcceptResurrect,
--  CONFIRM_SUMMON + GetSummonConfirmTimeLeft + ConfirmSummon, GetNumFriends / GetFriendInfo, IsInGuild / GetNumGuildMembers /
--  GetGuildRosterInfo, SetRaidTarget(unite, indice), GetRaidTargetIndex, CHAT_MSG_WHISPER / CHAT_MSG_GUILD (arg1 texte, arg2 expediteur).
-- NON VERIFIE EN JEU : tout ; InviteByName, ConvertToRaid, DeclineGroup, DeclineGuild, GUILD_INVITE_REQUEST, GetNumIgnores / GetIgnoreName,
--  IsRaidOfficer, PARTY_LEADER_CHANGED, la liste des fenetres a fermer (StaticPopup_Hide), le delai entre ConvertToRaid et l'invitation.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L

local getn, tinsert = table.getn, table.insert
local sfind, ssub, slower, sformat = string.find, string.sub, string.lower, string.format

local M = {}
SUI.Social = M

local MAXRULES = 60
local PARTY, RAID = {}, {}
for i = 1, 4 do PARTY[i] = "party" .. i end
for i = 1, 40 do RAID[i] = "raid" .. i end
M.ICONS = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, skull = 8 }
M.INAMES = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }

M.on = false
M.reg = {}              -- evenement -> true si ecoute
M.keyword = "inv"
M.keywords = { "inv" }
M.edit = { kw = "", rule = "", white = "", black = "" }
M.ruleIcon = 8
M.rules = {}            -- nom en minuscules -> icone
M.nrules = 0
M.lc = {}               -- cache des minuscules (survol sans allocation)
M.nlc = 0
M.canMark = false
M.coolName, M.coolTime = {}, {}   -- anneau des invitations recentes
M.ncool, M.chead = 0, 0
M.invited = 0
M.marked = 0
M.sessionDone = false
M.warned = false
M.summonTask = nil
M.combatQ = {}          -- invitations recues en combat : depilees au retour hors combat (32 max)
M.combatN = 0
M.fullWarned = false
M.pendingQ = {}        -- file d'attente des invitations pendant la conversion en raid (plusieurs "+1" peuvent arriver)
M.pendingSet = {}      -- dedoublonnage de la file
M.pendingArm = false   -- une seule minuterie de relance, posee au premier nom empile

-- ---------------------------------------------------------------- utilitaires
local function lower(name)
	local v = M.lc[name]
	if v then return v end
	v = slower(name)
	if M.nlc < 200 then
		M.nlc = M.nlc + 1
		M.lc[name] = v
	end
	return v
end

local function shift()
	return IsShiftKeyDown and IsShiftKeyDown()
end

-- Fonction du client si elle existe (certaines manquent selon la version) : jamais d'appel direct non garde.
local function api(name)
	local f = getglobal(name)
	if type(f) == "function" then return f end
	return nil
end

-- Demande la liste de guilde au serveur (sans elle GetGuildRosterInfo est vide et personne n'est reconnu comme membre de la guilde) ; au plus 1 fois par 30 s.
function M.RequestRoster()
	local gr, ig = api("GuildRoster"), api("IsInGuild")
	if not gr or not ig or not ig() then return end
	local now = GetTime()
	if M.rosterAt and now - M.rosterAt < 30 then return end
	M.rosterAt = now
	gr()
end

local function trim(s)
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

-- Le joueur nomme est-il dans mon groupe ou mon raid ?
function M.InGroup(name)
	local low = lower(name)
	local n = GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do
			local u = UnitName(RAID[i])
			if u and lower(u) == low then return true end
		end
		return false
	end
	for i = 1, GetNumPartyMembers() do
		local u = UnitName(PARTY[i])
		if u and lower(u) == low then return true end
	end
	return false
end

function M.GroupSize()
	local n = GetNumRaidMembers()
	if n > 0 then return n end
	local p = GetNumPartyMembers()
	if p > 0 then return p + 1 end
	return 1
end

function M.IsIgnored(name)
	local low = lower(name)
	local n, g = api("GetNumIgnores"), api("GetIgnoreName")
	if not n or not g then return false end
	for i = 1, n() do
		local u = g(i)
		if u and lower(u) == low then return true end
	end
	return false
end

-- "guild", "friend" ou "other"
function M.Relation(name)
	local low = lower(name)
	M.RequestRoster()
	if IsInGuild() then
		for i = 1, GetNumGuildMembers() do
			local u = GetGuildRosterInfo(i)
			if u and lower(u) == low then return "guild" end
		end
	end
	for i = 1, GetNumFriends() do
		local u = GetFriendInfo(i)
		if u and lower(u) == low then return "friend" end
	end
	return "other"
end

function M.CanInvite()
	if GetNumRaidMembers() > 0 then
		local off = api("IsRaidOfficer")
		return (IsRaidLeader() or (off and off())) and true or false
	end
	if GetNumPartyMembers() > 0 then return IsPartyLeader() end
	return true
end

-- ---------------------------------------------------------------- auto-invitation
function M.Cooling(name, now)
	local low = lower(name)
	local cool = C.Get("social.invite.cool")
	for i = 1, M.ncool do
		if M.coolName[i] == low and now - M.coolTime[i] < cool then return true end
	end
	return false
end

function M.MarkCool(name, now)
	local size = 40
	local h = M.chead + 1
	if h > size then h = 1 end
	M.chead = h
	M.coolName[h], M.coolTime[h] = lower(name), now
	if M.ncool < size then M.ncool = M.ncool + 1 end
end

function M.Invite(name)
	if SUI.InCombat() then return false end
	if name == UnitName("player") then return false end
	local now = GetTime()
	if M.Cooling(name, now) then return false end
	if M.InGroup(name) then return false end
	if M.IsIgnored(name) then return false end
	if not M.Allowed(name) then return false end
	if not M.CanInvite() then return false end
	local size = M.GroupSize()
	if size >= C.Get("social.invite.max") then
		if not M.fullWarned then
			M.fullWarned = true
			SUI.Print(L("msg.social.full", size))
		end
		return false
	end
	M.fullWarned = false
	if GetNumRaidMembers() == 0 and GetNumPartyMembers() >= 4 then
		if not C.Get("social.invite.raid") then
			if not M.fullWarned then
				M.fullWarned = true
				SUI.Print(L("msg.social.full", size))
			end
			return false
		end
		-- File d'attente : chaque "+1" recu pendant la conversion en raid est empile (sans cooldown :
		-- le cooldown n'est marque qu'a l'invitation REELLE, les ecrases n'etaient jamais invites).
		if not M.pendingSet[name] then
			M.pendingSet[name] = true
			tinsert(M.pendingQ, name)
		end
		if not M.pendingArm then
			M.pendingArm = true
			ConvertToRaid()
			SUI.After(1.5, M.InvitePending, "social.invite")
		end
		return true
	end
	M.MarkCool(name, now)
	InviteByName(name)
	M.invited = M.invited + 1
	SUI.Print(L("msg.social.invited", name))
	return true
end

-- La conversion en raid est faite : invite TOUTE la file (une par personne, cooldown marque ici seulement).
function M.InvitePending()
	M.pendingArm = false
	if not M.on then
		M.pendingQ, M.pendingSet = {}, {}
		return
	end
	local n = getn(M.pendingQ)
	for i = 1, n do
		local name = M.pendingQ[i]
		M.pendingQ[i] = nil
		M.pendingSet[name] = nil
		local now = GetTime()
		if not M.Cooling(name, now) and not M.InGroup(name) and not M.IsIgnored(name) and M.Allowed(name) then
			M.MarkCool(name, now)
			InviteByName(name)
			M.invited = M.invited + 1
			SUI.Print(L("msg.social.invited", name))
		end
	end
end

function M.OnChat(ev, msg, sender)
	if type(msg) ~= "string" or type(sender) ~= "string" then return end
	if string.len(msg) > 40 then return end
	if not M.IsKeyword(slower(trim(msg))) then return end
	if SUI.InCombat() then
		-- en combat, l'invitation attend la fin du combat (annonce en tete de fichier) : file de 32, depilee hors combat
		if M.combatN < 32 then
			M.combatN = M.combatN + 1
			M.combatQ[M.combatN] = sender
		end
		return
	end
	M.Invite(sender)
end

function M.IsKeyword(word)
	for i = 1, getn(M.keywords) do
		if M.keywords[i] == word then return true end
	end
	return false
end

-- Liste de noms / mots stockee dans un reglage "a;b;c" (valeurs en minuscules).
function M.ListGet(key)
	local out = {}
	local s = C.Get(key) or ""
	local pos, n = 1, string.len(s)
	while pos <= n do
		local a = sfind(s, ";", pos, true)
		local piece
		if a then
			piece = ssub(s, pos, a - 1)
			pos = a + 1
		else
			piece = ssub(s, pos)
			pos = n + 1
		end
		if piece ~= "" then tinsert(out, piece) end
	end
	return out
end

function M.InList(key, low)
	local l = M.ListGet(key)
	for i = 1, getn(l) do
		if l[i] == low then return true end
	end
	return false
end

function M.ReadKeywords()
	local l = M.ListGet("social.keyword")
	if getn(l) == 0 then l = { "inv" } end
	M.keywords = l
	M.keyword = l[1]
end

local function validItem(v, maxlen)
	if v == "" or string.len(v) > maxlen or sfind(v, "[;=]") then return false end
	return true
end

-- Ajoute (add = true) ou retire un element d'une liste ; retourne true si la liste a change.
function M.ListEdit(key, value, add, maxlen)
	value = slower(trim(value or ""))
	if not validItem(value, maxlen or 40) then return false end
	local l = M.ListGet(key)
	local at
	for i = 1, getn(l) do
		if l[i] == value then at = i end
	end
	if add then
		if at or getn(l) >= MAXRULES then return false end
		tinsert(l, value)
	else
		if not at then return false end
		table.remove(l, at)
		if key == "social.keyword" and getn(l) == 0 then return false end
	end
	C.SetBase(key, table.concat(l, ";"))
	return true
end

function M.SetKeyword(word)
	word = slower(trim(word or ""))
	if word == "" or string.len(word) > 30 or sfind(word, ";", 1, true) then return false end
	C.SetBase("social.keyword", word)
	return true
end

-- Qui le filtre laisse-t-il inviter ? liste noire > liste blanche > filtre.
function M.Allowed(name)
	local low = lower(name)
	if M.InList("social.invite.black", low) then return false end
	if M.InList("social.invite.white", low) then return true end
	local f = C.Get("social.invite.filter")
	if f == "all" then return true end
	if f == "white" then return false end
	local rel = M.Relation(name)
	if f == "guild" then return rel == "guild" end
	return rel == "guild" or rel == "friend"
end

-- ---------------------------------------------------------------- marquage automatique
local function rulesString()
	local s = ""
	for name, icon in pairs(M.rules) do
		if s ~= "" then s = s .. ";" end
		s = s .. name .. "=" .. icon
	end
	return s
end

function M.ReadRules()
	for k, _ in pairs(M.rules) do M.rules[k] = nil end
	M.nrules = 0
	for name, icon in string.gfind(C.Get("social.mark.rules") or "", "([^;=]+)=(%d)") do
		local n = tonumber(icon)
		if n and n >= 1 and n <= 8 and not M.rules[name] and M.nrules < MAXRULES then
			M.rules[name] = n
			M.nrules = M.nrules + 1
		end
	end
end

function M.RuleAdd(name, icon)
	name = lower(trim(name or ""))
	if name == "" or sfind(name, "[;=]") or string.len(name) > 40 then return false end
	icon = tonumber(icon) or M.ICONS[slower(tostring(icon))]
	if not icon or icon < 1 or icon > 8 then return false end
	if not M.rules[name] then
		if M.nrules >= MAXRULES then return false end
		M.nrules = M.nrules + 1
	end
	M.rules[name] = icon
	C.SetBase("social.mark.rules", rulesString())
	return true
end

function M.RuleRemove(name)
	name = lower(trim(name or ""))
	if not M.rules[name] then return false end
	M.rules[name] = nil
	M.nrules = M.nrules - 1
	C.SetBase("social.mark.rules", rulesString())
	return true
end

-- Etat du groupe mis en cache : peut-on poser une icone ?
function M.UpdateCan()
	local can = false
	if C.Get("social.mark") then
		local n = GetNumRaidMembers()
		if n > 0 then
			local off = api("IsRaidOfficer")
			can = (IsRaidLeader() or (off and off())) and true or false
		elseif GetNumPartyMembers() > 0 then
			can = IsPartyLeader() and true or false
		end
		if can and C.Get("social.mark.where") == "instance" then
			local ii = api("IsInInstance")
			if ii then can = ii() and true or false end      -- fonction absente : on ne peut pas savoir, le choix "groupe" s'applique
		end
	end
	M.canMark = can
end

function M.TryMark(unit)
	if not M.canMark or M.nrules == 0 then return end
	if not UnitExists(unit) or UnitIsPlayer(unit) or UnitIsDead(unit) or not UnitCanAttack("player", unit) then return end
	local name = UnitName(unit)
	if not name then return end
	local icon = M.rules[lower(name)]
	if icon and not GetRaidTargetIndex(unit) then
		SetRaidTarget(unit, icon)
		M.marked = M.marked + 1
	end
end

function M.OnMouse() M.TryMark("mouseover") end
function M.OnTarget() M.TryMark("target") end

-- ---------------------------------------------------------------- acceptation / refus automatiques
function M.OnPartyInvite(ev, name)
	if type(name) ~= "string" or shift() then return end
	local mode = C.Get("social.auto.invite")
	local rel = M.Relation(name)
	local accept = mode == "all" or (mode == "guild" and rel == "guild") or (mode == "friends" and (rel == "guild" or rel == "friend"))
	if accept then
		AcceptGroup()
		StaticPopup_Hide("PARTY_INVITE")
		SUI.Print(L("msg.social.accepted", name))
	elseif C.Get("social.auto.decline") and rel == "other" then
		DeclineGroup()
		StaticPopup_Hide("PARTY_INVITE")
		SUI.Print(L("msg.social.declined", name))
	end
end

function M.OnDuel(ev, name)
	if shift() then return end
	CancelDuel()
	StaticPopup_Hide("DUEL_REQUESTED")
	SUI.Print(L("msg.social.duel", tostring(name)))
end

function M.OnGuildInvite(ev, name)
	if shift() then return end
	local dg = api("DeclineGuild")
	if not dg then return end
	dg()
	StaticPopup_Hide("GUILD_INVITE")
	SUI.Print(L("msg.social.guild", tostring(name)))
end

function M.OnRez(ev, name)
	if type(name) ~= "string" or shift() then return end
	if not M.InGroup(name) then return end
	AcceptResurrect()
	StaticPopup_Hide("RESURRECT")
	StaticPopup_Hide("RESURRECT_NO_TIMER")
	StaticPopup_Hide("RESURRECT_NO_SICKNESS")
	SUI.Print(L("msg.social.rez", name))
end

function M.DoSummon()
	M.summonTask = nil
	if not M.on or not C.Get("social.auto.summon") or shift() then return end
	local gl, cs = api("GetSummonConfirmTimeLeft"), api("ConfirmSummon")
	if gl and cs and (gl() or 0) > 0 then
		cs()
		StaticPopup_Hide("CONFIRM_SUMMON")
		SUI.Print(L("msg.social.summon"))
	end
end

function M.OnSummon()
	local gl = api("GetSummonConfirmTimeLeft")
	local left = gl and gl()
	if not left or left <= 0 then return end
	local delay = left - 3
	if delay < 0 then delay = 0 end
	if M.summonTask then SUI.Cancel(M.summonTask) end
	M.summonTask = SUI.After(delay, M.DoSummon, "social.summon")
end

-- ---------------------------------------------------------------- cablage des evenements
local function want(ev, on, fn)
	if on and not M.reg[ev] then
		M.reg[ev] = fn
		SUI.On(ev, fn)
	elseif not on and M.reg[ev] then
		SUI.Off(ev, M.reg[ev])
		M.reg[ev] = nil
	end
end

function M.Rewire()
	local on = M.on
	local inv = on and C.Get("social.invite")
	local mark = on and C.Get("social.mark")
	want("CHAT_MSG_WHISPER", inv and C.Get("social.invite.whisper"), M.OnChat)
	want("CHAT_MSG_GUILD", inv and C.Get("social.invite.guild"), M.OnChat)
	want("UPDATE_MOUSEOVER_UNIT", mark, M.OnMouse)
	want("PLAYER_TARGET_CHANGED", mark, M.OnTarget)
	want("PARTY_MEMBERS_CHANGED", mark, M.UpdateCan)
	want("RAID_ROSTER_UPDATE", mark, M.UpdateCan)
	want("PARTY_LEADER_CHANGED", mark, M.UpdateCan)
	want("PLAYER_ENTERING_WORLD", mark, M.UpdateCan)
	local ai = C.Get("social.auto.invite")
	want("PARTY_INVITE_REQUEST", on and (ai ~= "off" or C.Get("social.auto.decline")), M.OnPartyInvite)
	want("DUEL_REQUESTED", on and C.Get("social.auto.duel"), M.OnDuel)
	want("GUILD_INVITE_REQUEST", on and C.Get("social.auto.guild"), M.OnGuildInvite)
	want("CONFIRM_SUMMON", on and C.Get("social.auto.summon"), M.OnSummon)
	want("RESURRECT_REQUEST", on and C.Get("social.auto.rez"), M.OnRez)
	if on and (C.Get("social.invite") or C.Get("social.auto.invite") ~= "off") then M.RequestRoster() end
	M.UpdateCan()
	if on and M.AutoActive() and not M.warned then
		M.warned = true
		SUI.Print(L("msg.social.warn"))
	end
end

function M.AutoActive()
	return C.Get("social.auto.invite") ~= "off" or C.Get("social.auto.decline") or C.Get("social.auto.duel") or C.Get("social.auto.guild")
		or C.Get("social.auto.summon") or C.Get("social.auto.rez")
end

function M.OnKey(key)
	if key == nil or key == "social.keyword" then M.ReadKeywords() end
	if key == nil or key == "social.mark.rules" then M.ReadRules() end
	if key ~= "social.keyword" and key ~= "social.mark.rules" then M.Rewire() end
end

function M.Enable()
	M.on = true
	if not M.sessionDone then
		M.sessionDone = true
		if C.Get("social.invite.reset") and C.Get("social.invite") then
			C.Set("social.invite", false)
			SUI.Print(L("msg.social.reset"))
		end
		local ia = getglobal("IsAddOnLoaded")
		if ia then
			local names = { "_LazyPig", "LazyPig", "AutoInvite", "AutoMarker", "AutoMarkerOW" }
			for i = 1, getn(names) do
				if ia(names[i]) then SUI.Print(L("msg.social.conflict", names[i])) end
			end
		end
	end
	M.ReadKeywords()
	M.ReadRules()
	if not M.watching then
		M.watching = true
		C.Watch("social.", M.OnKey)
		SUI.On("PLAYER_REGEN_ENABLED", M.OnRegen)
	end
	M.Rewire()
end

function M.OnRegen()
	-- depile les invitations recues en combat (l'anti-doublon / cooldown de Invite fait le tri)
	local n = M.combatN
	M.combatN = 0
	for i = 1, n do
		if not SUI.InCombat() then M.Invite(M.combatQ[i]) end
		M.combatQ[i] = nil
	end
end

function M.Disable()
	M.on = false
	M.Rewire()
	M.canMark = false
	if M.summonTask then
		SUI.Cancel(M.summonTask)
		M.summonTask = nil
	end
	M.pendingName = nil
	M.combatN = 0
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnRegen)
	M.regenWatch = nil
end

-- ---------------------------------------------------------------- commandes
local function onoff(arg)
	arg = slower(arg or "")
	if arg == "on" then return true end
	if arg == "off" then return false end
	return nil
end

function M.Command(rest)
	local word, arg = rest, ""
	local sp = sfind(rest, " ", 1, true)
	if sp then
		word = ssub(rest, 1, sp - 1)
		arg = trim(ssub(rest, sp + 1))
	end
	word = slower(word)
	if word == "invite" then
		local v = onoff(arg)
		if v == nil then
			SUI.Print(L("msg.social.invite.state", C.Get("social.invite") and "on" or "off", M.keyword))
		else
			C.Set("social.invite", v)
			SUI.Print(L("msg.social.invite.state", v and "on" or "off", M.keyword))
		end
	elseif word == "word" then
		if M.SetKeyword(arg) then
			SUI.Print(L("msg.social.word", slower(trim(arg))))
		else
			SUI.Print(L("msg.social.badword"))
		end
	elseif word == "keywords" or word == "white" or word == "black" then
		local key = word == "keywords" and "social.keyword" or ("social.invite." .. word)
		local sub, name = arg, ""
		local sp3 = sfind(arg, " ", 1, true)
		if sp3 then
			sub = ssub(arg, 1, sp3 - 1)
			name = trim(ssub(arg, sp3 + 1))
		end
		sub = slower(sub)
		if sub == "add" then
			if M.ListEdit(key, name, true) then SUI.Print(L("msg.social.list.added", slower(name))) else SUI.Print(L("msg.social.list.bad")) end
		elseif sub == "remove" then
			if M.ListEdit(key, name, false) then SUI.Print(L("msg.social.list.removed", slower(name))) else SUI.Print(L("msg.social.list.bad")) end
		elseif sub == "clear" and word ~= "keywords" then
			C.SetBase(key, "")
			SUI.Print(L("msg.social.list.cleared"))
		else
			local l = M.ListGet(key)
			SUI.Print(L("msg.social.list.line", word, table.concat(l, ", ")))
		end
	elseif word == "mark" then
		local sub, rest2 = arg, ""
		local sp2 = sfind(arg, " ", 1, true)
		if sp2 then
			sub = ssub(arg, 1, sp2 - 1)
			rest2 = trim(ssub(arg, sp2 + 1))
		end
		sub = slower(sub)
		if sub == "add" then
			local _, _, name, icon = sfind(rest2, "^(.-)%s+(%S+)$")
			if name and M.RuleAdd(name, icon) then
				SUI.Print(L("msg.social.rule.added", lower(trim(name)), M.INAMES[M.rules[lower(trim(name))]]))
			else
				SUI.Print(L("msg.social.rule.bad"))
			end
		elseif sub == "remove" then
			if M.RuleRemove(rest2) then SUI.Print(L("msg.social.rule.removed")) else SUI.Print(L("msg.social.rule.unknown")) end
		elseif sub == "clear" then
			C.SetBase("social.mark.rules", "")
			SUI.Print(L("msg.social.rule.cleared"))
		elseif sub == "list" then
			if M.nrules == 0 then SUI.Print(L("msg.social.rule.none")) end
			for name, icon in pairs(M.rules) do SUI.Print(L("msg.social.rule.line", name, M.INAMES[icon])) end
		else
			local v = onoff(sub)
			if v ~= nil then C.Set("social.mark", v) end
			SUI.Print(L("msg.social.mark.state", C.Get("social.mark") and "on" or "off", M.nrules))
		end
	else
		SUI.Print(L("msg.social.status", C.Get("social.invite") and "on" or "off", C.Get("social.mark") and "on" or "off", M.invited, M.marked))
	end
end

-- ---------------------------------------------------------------- page du menu : listes editables (mots-cles, regles de marquage, listes blanche / noire)
-- Les sections sont ajoutees a la page de la categorie "social" (Menu_Pages : P.cat enrobee ici, aucun fichier du socle modifie).
local function menuKind(name, factory)
	local Mn = SUI.Menu
	Mn.New[name] = factory
	local have = false
	for i = 1, getn(Mn.KINDS) do
		if Mn.KINDS[i] == name then have = true end
	end
	if not have then tinsert(Mn.KINDS, name) end
	if not Mn.pools[name] then Mn.pools[name] = {} end
	if not Mn.used[name] then Mn.used[name] = 0 end
end

local function newEdit()
	local Mn = SUI.Menu
	local T = SUI.Theme
	local f = CreateFrame("Frame", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 2)
	f.edit = T.Edit(f, 250, 24)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.edit:SetMaxLetters(40)
	f.edit:SetScript("OnTextChanged", function()
		local e = this
		if not e.silent and e.key then M.edit[e.key] = e:GetText() or "" end
	end)
	f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	return f
end

local function newLabel()
	local Mn = SUI.Menu
	local T = SUI.Theme
	local f = CreateFrame("Frame", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", Mn.OnWheel)
	f.fs = T.Text(f, 11, T.c.text, "LEFT")
	f.fs:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.fs:SetWidth(280)
	f.fs:SetHeight(14)
	return f
end

local function rowBtn(x, w, label, fn)
	local Mn = SUI.Menu
	local b = Mn.Get("btn")
	if not b then return nil end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", Mn.child, "TOPLEFT", x, -Mn.y)
	b:SetWidth(w)
	b:SetHeight(24)
	b:Show()
	b.y, b.h = Mn.y, 24
	SUI.Theme.SetButtonText(b, label)
	b.fn = fn
	SUI.Theme.SetSelected(b, false)
	return b
end

-- Ligne d'une liste : texte a gauche, [bouton d'icone], bouton Retirer.
local function itemRow(text, onRemove, iconLabel, onIcon)
	local Mn = SUI.Menu
	local lab = Mn.Get("so_lbl")
	if not lab then return end
	Mn.Flow(lab, 1, 300, 24, 0, 4)
	lab.fs:SetText(text)
	local x = 306
	if onIcon then
		rowBtn(x, 110, iconLabel, onIcon)
		x = x + 114
	end
	rowBtn(x, 90, L("mod.social.remove"), onRemove)
	Mn.EndRow(4)
end

local function targetName(wantPlayer)
	if not UnitExists("target") then
		SUI.Print(L("msg.social.ui.notarget"))
		return nil
	end
	local isPlayer = UnitIsPlayer("target") and true or false
	if isPlayer ~= wantPlayer then
		SUI.Print(L(wantPlayer and "msg.social.ui.needplayer" or "msg.social.ui.needmob"))
		return nil
	end
	return UnitName("target")
end

-- Ligne d'ajout : saisie, [choix d'icone], Ajouter, Cible actuelle.
local function addRow(key, onAdd, wantPlayer, iconLabel, onIcon)
	local Mn = SUI.Menu
	local ed = Mn.Get("so_edit")
	if not ed then return end
	Mn.Flow(ed, 1, 250, 24, 0, 6)
	ed.edit.key = key
	ed.edit.silent = true
	if (ed.edit:GetText() or "") ~= M.edit[key] then ed.edit:SetText(M.edit[key]) end
	ed.edit.silent = false
	local x = 256
	if onIcon then
		rowBtn(x, 104, iconLabel, onIcon)
		x = x + 108
	end
	rowBtn(x, 90, L("mod.social.add"), function() onAdd(M.edit[key]) end)
	-- "Cible actuelle" : seulement pour les listes de joueurs et les regles de monstres (un mot-cle n'a pas de cible)
	if wantPlayer ~= nil then
		rowBtn(x + 94, 140, L("mod.social.addtarget"), function()
			local n = targetName(wantPlayer)
			if n then onAdd(n) end
		end)
	end
	Mn.EndRow(6)
end

local function renderAfter(ok)
	if not ok then SUI.Print(L("msg.social.list.bad")) end
	local Mn = SUI.Menu
	if Mn.frame and Mn.frame:IsShown() then Mn.Render() end
end

local function simpleList(title, help, key, editKey, wantPlayer)
	local Mn = SUI.Menu
	local l = M.ListGet(key)
	Mn.Section(title, tostring(getn(l)))
	Mn.Para(help, 30)
	if getn(l) == 0 then Mn.Para(L("mod.social.empty"), 18) end
	for i = 1, getn(l) do
		local name = l[i]
		itemRow(name, function() renderAfter(M.ListEdit(key, name, false)) end)
	end
	addRow(editKey, function(v)
		local ok = M.ListEdit(key, v, true)
		if ok then M.edit[editKey] = "" end
		renderAfter(ok)
	end, wantPlayer)
end

function M.Page()
	local Mn = SUI.Menu
	local mod = SUI.modules.social
	if not mod or not mod.enabled then
		Mn.Para(L("mod.social.disabled"), 34, SUI.Theme.c.warn)
		return
	end
	-- mots-cles
	simpleList(L("mod.social.sec.keywords"), L("mod.social.help.keywords"), "social.keyword", "kw", nil)
	-- regles de marquage
	local names = {}
	for name, _ in pairs(M.rules) do tinsert(names, name) end
	table.sort(names)
	Mn.Section(L("mod.social.sec.rules"), tostring(getn(names)))
	Mn.Para(L("mod.social.help.rules"), 30)
	if getn(names) == 0 then Mn.Para(L("mod.social.empty"), 18) end
	for i = 1, getn(names) do
		local name = names[i]
		local icon = M.rules[name]
		itemRow(name, function() renderAfter(M.RuleRemove(name)) end, L("mod.social.icon." .. M.INAMES[icon]), function()
			local nxt = icon + 1
			if nxt > 8 then nxt = 1 end
			renderAfter(M.RuleAdd(name, nxt))
		end)
	end
	addRow("rule", function(v)
		local ok = M.RuleAdd(v, M.ruleIcon)
		if ok then M.edit.rule = "" end
		renderAfter(ok)
	end, false, L("mod.social.icon." .. M.INAMES[M.ruleIcon]), function()
		M.ruleIcon = M.ruleIcon + 1
		if M.ruleIcon > 8 then M.ruleIcon = 1 end
		renderAfter(true)
	end)
	if Mn.mode == "all" then
		simpleList(L("mod.social.sec.white"), L("mod.social.help.white"), "social.invite.white", "white", true)
		simpleList(L("mod.social.sec.black"), L("mod.social.help.black"), "social.invite.black", "black", true)
	else
		local n = Mn.Get("note")
		if n then
			Mn.Flow(n, 1, 648, 38, 0, 10)
			n.fs:SetText(L("mod.social.hidden"))
			SUI.Theme.SetButtonText(n.btn, L("mod.menu.showall"))
			n.btn.fn = function() Mn.SetMode("all") end
			Mn.EndRow(10)
		end
	end
end

function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	menuKind("so_edit", newEdit)
	menuKind("so_lbl", newLabel)
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "social" then M.Page() end
		orig()
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("social", 31)

local function opt(key, typ, order, def, extra)
	local o = { key = "social." .. key, type = typ, cat = "social", label = "opt.social." .. key, tip = "tip.social." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("social", {
	default = false,
	cost = "light",
	options = {
		opt("invite", "bool", 10, false, { simple = true }),
		opt("invite.whisper", "bool", 11, true),
		opt("invite.guild", "bool", 12, true),
		opt("invite.raid", "bool", 13, false),
		opt("invite.max", "number", 14, 40, { min = 5, max = 40, step = 1 }),
		opt("invite.cool", "number", 15, 30, { min = 10, max = 120, step = 5 }),
		opt("invite.reset", "bool", 16, true),
		opt("invite.filter", "choice", 17, "all", { choices = { "all", "guild", "friends", "white" } }),
		opt("mark", "bool", 20, false, { simple = true }),
		opt("mark.where", "choice", 21, "group", { choices = { "group", "instance" } }),
		opt("auto.invite", "choice", 30, "off", { choices = { "off", "guild", "friends", "all" }, simple = true }),
		opt("auto.decline", "bool", 31, false),
		opt("auto.duel", "bool", 32, false, { simple = true }),
		opt("auto.guild", "bool", 33, false),
		opt("auto.summon", "bool", 34, false),
		opt("auto.rez", "bool", 35, false),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Donnees (pas des reglages de menu) : mot-cle d'auto-invitation et regles de marquage "nom=icone;nom=icone".
SUI.Config.Register({ ["social.keyword"] = "inv", ["social.mark.rules"] = "", ["social.invite.white"] = "", ["social.invite.black"] = "" })

M.HookMenu()

-- Equivalent pfUI : aucun module d'auto-invitation / marquage releve dans pfUI\modules (pas de ligne Migrate.MAP).

SUI.RegisterCommand("social", function(rest) M.Command(rest or "") end, "help.social")
