-- ShikiUI ChatTabs : gestionnaire d'onglets / fenetres de chat (creer, renommer, fermer, reordonner), choix des types de messages et des canaux
-- de chaque onglet (modeles en un clic OU cases a cocher une par une), sauvegarde par personnage et restauration a la connexion.
-- Deux entrees : la page "Onglets de chat" du menu (Menu_Pages : sections ajoutees ici, aucun fichier du socle modifie) et un menu
-- contextuel (clic droit sur un onglet de la barre ShikiUI du module chat). Aucune minuterie permanente, aucun OnUpdate, rien en combat.
-- API 1.12 relevee dans pfUI\modules\chat.lua et _LazyPig (jamais executee ici) : NUM_CHAT_WINDOWS, ChatFrameN, GetChatWindowInfo (nom, taille, r, g, b,
--  alpha, visible), FCF_Close, FCF_SetWindowName, FCF_SelectDockFrame, FCF_DockUpdate, ChatFrame_AddMessageGroup, ChatFrame_RemoveAllMessageGroups,
--  ChatFrame_AddChannel, ChatFrame_RemoveChannel, ChatFrame_RemoveAllChannels, ChatFrame_ActivateCombatMessages, frame.messageTypeList,
--  GetChannelList, JoinChannelByName.
-- NON VERIFIE EN JEU : FCF_OpenNewWindow (nom et argument), ChatFrame_RemoveMessageGroup, frame.channelList (noms exacts : on compare en prefixe),
--  ChatTypeGroup (liste des groupes valides ; un groupe absent est ignore), les noms de groupes MONEY / OFFICER / CREATURE / MONSTER_* / CHANNEL,
--  la fermeture d'une fenetre (FCF_Close sur une fenetre ancree), l'ordre des onglets (seule la barre ShikiUI est reordonnee, pas le dock Blizzard),
--  la restauration a la connexion (le client garde deja ses fenetres : ici on ne fait que rejouer l'arrangement sauvegarde).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.ChatTabs = M

local getn, tinsert = table.getn, table.insert
local strfind, strsub, strlower, strlen, strgsub = string.find, string.sub, string.lower, string.len, string.gsub

local CW = 648
local MAXNAME = 16
local MAXREC = 8

M.on = false
M.sel = nil              -- fenetre choisie dans la page du menu
M.order = {}             -- ordre d'affichage (numeros de fenetres) ; vide = ordre naturel
M.restored = false
M.editText = ""
M.editFor = nil

-- ---------------------------------------------------------------- catalogue des types de messages (groupes du client 1.12)
M.TYPES = {
	{ id = "say", groups = { "SAY" } },
	{ id = "emote", groups = { "EMOTE" } },
	{ id = "yell", groups = { "YELL" } },
	{ id = "guild", groups = { "GUILD" } },
	{ id = "officer", groups = { "OFFICER", "GUILD_OFFICER" } },
	{ id = "whisper", groups = { "WHISPER" } },
	{ id = "party", groups = { "PARTY" } },
	{ id = "raid", groups = { "RAID", "RAID_LEADER", "RAID_WARNING" } },
	{ id = "bg", groups = { "BATTLEGROUND", "BATTLEGROUND_LEADER" } },
	{ id = "loot", groups = { "LOOT" } },
	{ id = "money", groups = { "MONEY" } },
	{ id = "xp", groups = { "COMBAT_XP_GAIN" } },
	{ id = "honor", groups = { "COMBAT_HONOR_GAIN" } },
	{ id = "faction", groups = { "COMBAT_FACTION_CHANGE" } },
	{ id = "skill", groups = { "SKILL" } },
	{ id = "combat", special = "combat" },
	{ id = "system", groups = { "SYSTEM" } },
	{ id = "creature", groups = { "CREATURE", "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE",
		"MONSTER_BOSS_WHISPER" } },
	{ id = "chnotice", groups = { "CHANNEL" } },
}
M.TYPE = {}
for i = 1, getn(M.TYPES) do M.TYPE[M.TYPES[i].id] = M.TYPES[i] end

-- Classes de canaux (reconnues par morceaux du nom : le client les traduit et ajoute la zone).
M.CHANCLASS = { "general", "trade", "lfg", "world", "defense", "custom" }

M.PRESETS = {
	{ id = "general", types = { "say", "emote", "yell", "guild", "officer", "whisper", "party", "raid", "bg", "system", "creature", "chnotice" },
		chan = { "general", "defense" } },
	{ id = "guild", types = { "guild", "officer" }, chan = {} },
	{ id = "world", types = { "chnotice" }, chan = { "world" } },
	{ id = "dungeon", types = { "party", "raid", "bg", "say" }, chan = {} },
	{ id = "group", types = { "party", "raid", "bg", "officer" }, chan = {} },
	{ id = "loot", types = { "loot", "money", "xp", "honor", "faction", "skill" }, chan = {} },
	{ id = "trade", types = { "chnotice" }, chan = "all" },
	{ id = "combat", types = { "combat" }, chan = {} },
	{ id = "social", types = { "whisper", "guild", "officer", "emote" }, chan = {} },
	{ id = "all", types = { "say", "emote", "yell", "guild", "officer", "whisper", "party", "raid", "bg", "loot", "money", "xp", "honor", "faction",
		"skill", "combat", "system", "creature", "chnotice" }, chan = "all" },
}
M.PRESET = {}
for i = 1, getn(M.PRESETS) do M.PRESET[M.PRESETS[i].id] = M.PRESETS[i] end

-- ---------------------------------------------------------------- aides
local function numWin()
	return getglobal("NUM_CHAT_WINDOWS") or 7
end

local function frameOf(i)
	return getglobal("ChatFrame" .. i)
end

-- Vrai si "frame" est atteinte en suivant les ancrages de "from" (from == frame compris) : ancrer frame sur from creerait un cycle
-- (erreur client "trying to anchor to itself"). Profondeur limitee.
local function anchorChain(from, frame, depth)
	if from == frame then return true end
	if depth > 10 or type(from) ~= "table" or not from.GetNumPoints or not from.GetPoint then return false end
	local n = from:GetNumPoints() or 0
	for i = 1, n do
		local _, rel = from:GetPoint(i)
		if type(rel) == "table" and anchorChain(rel, frame, depth + 1) then return true end
	end
	return false
end
M.AnchorCycle = function(frame, target) return anchorChain(target, frame, 0) end

-- Place une fenetre libre en cascade sous la fenetre principale. Ancrage sur UIParent en coordonnees absolues : jamais sur une autre
-- fenetre de chat (pas d'auto-ancrage, pas de cycle d'ancrage).
function M.Cascade(frame, k)
	if not frame then return end
	local main = frameOf(1)
	frame:ClearAllPoints()
	local l, t = nil, nil
	if main and main ~= frame and main.GetLeft and main.GetTop then
		l, t = main:GetLeft(), main:GetTop()
	end
	if l and t then
		local ms, fs = main:GetScale() or 1, frame:GetScale() or 1
		if fs <= 0 then fs = 1 end
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (l * ms + 28 * k) / fs, (t * ms - 28 * k) / fs)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 28 * k, -28 * k)
	end
end

local function cleanName(s)
	s = tostring(s or "")
	s = strgsub(s, "[;:,|~%c]", " ")
	s = strgsub(s, "^%s+", "")
	s = strgsub(s, "%s+$", "")
	if strlen(s) > MAXNAME then s = strsub(s, 1, MAXNAME) end
	return s
end
M.CleanName = cleanName

-- Appel protege d'une fonction du client (nom de globale) : une erreur est comptee, jamais propagee.
local function call(name, a, b)
	local fn = getglobal(name)
	if type(fn) ~= "function" then return false end
	local ok, err = pcall(fn, a, b)
	if not ok then SUI.Report("chattabs " .. tostring(name), err) end
	return ok
end

local function listHas(list, v)
	if type(list) ~= "table" then return false end
	for i = 1, getn(list) do
		if list[i] == v then return true end
	end
	return false
end

local function knownGroup(g)
	local tg = getglobal("ChatTypeGroup")
	if type(tg) == "table" then return tg[g] ~= nil end
	return true
end

-- Groupes a manipuler pour un type : ceux que le client connait ; si AUCUN n'est connu (nom different selon la version), on tente les noms bruts
-- plutot que de ne rien faire en silence.
local function usable(t)
	local out = {}
	for i = 1, getn(t.groups) do
		if knownGroup(t.groups[i]) then tinsert(out, t.groups[i]) end
	end
	if getn(out) == 0 then return t.groups end
	return out
end

local COMBAT_KEEP = { COMBAT_XP_GAIN = true, COMBAT_HONOR_GAIN = true, COMBAT_FACTION_CHANGE = true }
local function isCombatGroup(g)
	return strfind(g, "^COMBAT_") and not COMBAT_KEEP[g]
end

local function split(s, sep)
	local out, pos = {}, 1
	if s == "" then return out end
	while true do
		local a = strfind(s, sep, pos, true)
		if not a then
			tinsert(out, strsub(s, pos))
			break
		end
		tinsert(out, strsub(s, pos, a - 1))
		pos = a + 1
	end
	return out
end

-- ---------------------------------------------------------------- fenetres
function M.Ready()
	return frameOf(1) ~= nil and GetChatWindowInfo ~= nil
end

function M.IsCombatLog(i)
	local f = frameOf(i)
	if f and f.suiSkip then return true end
	local name = GetChatWindowInfo(i)
	local cl = getglobal("COMBAT_LOG")
	return (cl and name == cl) and true or false
end

-- Fenetres visibles : { { id, name, combat }, ... } dans l'ordre des numeros.
function M.Shown()
	local list = {}
	if not M.Ready() then return list end
	for i = 1, numWin() do
		local name, _, _, _, _, _, shown = GetChatWindowInfo(i)
		local fr = frameOf(i)
		-- le client ne marque "visible" que l'onglet selectionne : un onglet attache a la barre existe aussi (hors journal de combat)
		if not shown and fr and fr.isDocked and not M.IsCombatLog(i) then shown = 1 end
		if shown and name and name ~= "" then tinsert(list, { id = i, name = name, combat = M.IsCombatLog(i) }) end
	end
	return list
end

-- Fenetres visibles dans l'ordre d'affichage (M.order d'abord, le reste par numero).
function M.Ordered()
	local list = M.Shown()
	local out, used = {}, {}
	for k = 1, getn(M.order) do
		for j = 1, getn(list) do
			if list[j].id == M.order[k] and not used[j] then
				used[j] = true
				tinsert(out, list[j])
			end
		end
	end
	for j = 1, getn(list) do
		if not used[j] then tinsert(out, list[j]) end
	end
	return out
end

-- Ordre du dock Blizzard : DOCKED_CHAT_FRAMES (tableau de frames, releve dans pfUI) est permute sur place pour suivre l'ordre d'affichage,
-- puis FCF_SaveDock / FCF_DockUpdate. Les frames non ancrees ne sont pas touchees.
function M.ApplyDockOrder()
	local dock = getglobal("DOCKED_CHAT_FRAMES")
	if type(dock) ~= "table" or getn(dock) < 2 then return false end
	local rank = {}
	local ord = M.Ordered()
	for i = 1, getn(ord) do rank[ord[i].id] = i end
	local frames, slots = {}, {}
	for i = 1, getn(dock) do
		tinsert(frames, dock[i])
		tinsert(slots, i)
	end
	local function rk(f)
		local id = f and f.GetID and f:GetID()
		if id == 1 then return 0 end                -- ChatFrame1 reste l'ancre du dock : jamais deplacee
		return (id and rank[id]) or 99
	end
	table.sort(frames, function(a, b)
		local ra, rb = rk(a), rk(b)
		if ra ~= rb then return ra < rb end
		return (a.GetID and a:GetID() or 0) < (b.GetID and b:GetID() or 0)
	end)
	-- jamais deux fois la meme fenetre dans le dock (une fenetre ancree a elle-meme) : doublons retires
	local seen, uniq = {}, {}
	for i = 1, getn(frames) do
		if frames[i] and not seen[frames[i]] then
			seen[frames[i]] = true
			tinsert(uniq, frames[i])
		end
	end
	for i = 1, getn(uniq) do dock[i] = uniq[i] end
	for i = getn(dock), getn(uniq) + 1, -1 do table.remove(dock, i) end
	call("FCF_SaveDock")
	call("FCF_DockUpdate")
	return true
end

function M.PushOrder()
	if SUI.Chat and SUI.Chat.SetOrder then SUI.Chat.SetOrder(M.order) end
	M.ApplyDockOrder()
end

-- Une fenetre toute neuve doit avoir SA place : ancree au dock si possible, sinon decalee de la fenetre principale.
function M.EnsurePlaced(frame, id)
	if not frame then return end
	if not frame.isDocked then call("FCF_DockFrame", frame) end
	if id ~= 1 then M.Unlock(frame) end
	if frame.isDocked then return end
	M.Cascade(frame, getn(M.Shown()))
	if frame.SetUserPlaced then frame:SetUserPlaced(true) end
	M.placed = (M.placed or 0) + 1
	if id ~= 1 then M.Float(id) end
end

local function selectDock(frame)
	call("FCF_SelectDockFrame", frame)
	if SUI.Chat then SUI.Chat.selected = frame end
end

-- ---------------------------------------------------------------- fenetres libres : deverrouillees, deplacables (Mover), redimensionnables
function M.MoverKey(id)
	return "chat.win" .. id
end

-- Deverrouille une fenetre : le client la verrouille par defaut (FCF_SetLocked), ce qui bloque aussi le glisser de l'onglet.
function M.Unlock(frame)
	if not frame then return end
	call("FCF_SetLocked", frame, nil)
	if frame.SetMovable then frame:SetMovable(true) end
	if frame.SetResizable then frame:SetResizable(true) end
	if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	frame.suiUnlocked = true
end

function M.Unfloat(id)
	local key = M.MoverKey(id)
	local lay = SUI.Layout
	if lay and lay.items and lay.items[key] then
		lay.items[key] = nil
		local f = frameOf(id)
		if f then
			f.layoutKey = nil
			-- la fenetre rattachee retrouve l'echelle qu'elle avait avant d'etre libre (celle du dock)
			if f.suiPreScale then f:SetScale(f.suiPreScale) end
			f.suiPreScale = nil
		end
	end
	local mv = SUI.Mover
	if mv and mv.items and mv.items[key] then
		local rec = mv.items[key]
		if rec.handle and rec.handle.Hide then rec.handle:Hide() end
		mv.items[key] = nil
		for i = getn(mv.order), 1, -1 do
			if mv.order[i] == key then table.remove(mv.order, i) end
		end
	end
end

-- Une fenetre NON attachee a la barre recoit une poignee du Mover nommee d'apres son onglet (position sauvegardee par personnage).
-- Attachee : plus de poignee (le client gere la position du dock).
function M.Float(id)
	local frame = frameOf(id)
	if id == 1 or not frame or not SUI.Mover or not SUI.Mover.Register then return false end
	if frame.isDocked then
		M.Unfloat(id)
		return false
	end
	local w = M.IsShown(id)
	local key = M.MoverKey(id)
	local lay = SUI.Layout
	local it = lay and lay.items and lay.items[key]
	local fresh = not (it and it.frame == frame)
	local l, b = frame:GetLeft(), frame:GetBottom()
	if fresh then frame.suiPreScale = frame:GetScale() or 1 end
	local ok = SUI.Mover.Register(key, frame, { point = "BOTTOMLEFT", x = l or 40, y = b or 200, label = w and w.name or ("Chat " .. id),
		scale = false }) and true or false
	-- Le Layout met le cadre a l'echelle ui.scale x echelle du Mover : une fenetre de chat libre changerait de taille (et ne ressemblerait plus
	-- a la fenetre principale, qui garde l'echelle du client). On compense : elle garde l'echelle qu'elle avait, la poignee suit sa taille reelle.
	if ok and frame.suiPreScale and lay and lay.items[key] then      -- aussi a un nouvel appel : Register recree l'entree et perd mul
		local pre = frame.suiPreScale or 1
		lay.items[key].mul = function()
			local ui = C.Get("ui.scale") or 1
			if ui <= 0 then ui = 1 end
			return pre / ui
		end
		lay.Apply(key)
	end
	return ok
end

-- Met a jour poignees et verrous de toutes les fenetres creees (appele apres creation, renommage, restauration).
function M.Refloat()
	local list = M.Shown()
	for i = 1, getn(list) do
		local w = list[i]
		if w.id ~= 1 and not w.combat then
			M.Unlock(frameOf(w.id))
			M.Float(w.id)
		end
	end
end

function M.Detach(id)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local w = M.IsShown(id)
	if not w then return false, "msg.chattabs.nowin" end
	local frame = frameOf(id)
	if id == 1 or w.combat or not frame or not frame.isDocked then return false, "msg.chattabs.nodetach" end
	call("FCF_UnDockFrame", frame)
	if frame.isDocked then return false, "msg.chattabs.nodetach" end
	call("FCF_SaveDock")
	call("FCF_DockUpdate")
	M.Cascade(frame, getn(M.Shown()))
	if frame.SetUserPlaced then frame:SetUserPlaced(true) end
	frame:Show()
	M.Unlock(frame)
	M.Float(id)
	M.PushOrder()
	M.Touch()
	return true
end

function M.Attach(id)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local w = M.IsShown(id)
	if not w then return false, "msg.chattabs.nowin" end
	local frame = frameOf(id)
	if id == 1 or w.combat or not frame then return false, "msg.chattabs.noattach" end
	if not frame.isDocked then call("FCF_DockFrame", frame) end
	if not frame.isDocked then return false, "msg.chattabs.noattach" end
	M.Unfloat(id)
	call("FCF_SaveDock")
	call("FCF_DockUpdate")
	M.PushOrder()
	selectDock(frame)
	M.Touch()
	return true
end

-- "Ranger" : toutes les fenetres creees sont deverrouillees ; les fenetres libres sont ramenees en cascade sous la fenetre principale
-- (position du Mover effacee), les attachees remises dans l'ordre de la barre. Retourne le nombre de fenetres rangees.
function M.Tidy()
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local list = M.Ordered()
	local n, k = 0, 0
	for i = 1, getn(list) do
		local w = list[i]
		local frame = frameOf(w.id)
		if w.id ~= 1 and not w.combat and frame then
			M.Unlock(frame)
			if not frame.isDocked then
				k = k + 1
				local mk = M.MoverKey(w.id)
				M.Cascade(frame, k)
				M.Float(w.id)
				if SUI.Mover and SUI.Mover.items and SUI.Mover.items[mk] and C.ClearPosAll then
					C.ClearPosAll(mk)
					local it = SUI.Layout and SUI.Layout.items[mk]
					if it then
						it.x = frame:GetLeft() or it.x
						it.y = frame:GetBottom() or it.y
					end
				end
			end
			n = n + 1
		end
	end
	M.PushOrder()
	call("FCF_DockUpdate")
	M.Touch()
	return true, n
end

function M.IsShown(id)
	local list = M.Shown()
	for i = 1, getn(list) do
		if list[i].id == id then return list[i] end
	end
	return nil
end

-- ---------------------------------------------------------------- types de messages et canaux d'une fenetre
-- Ce client regroupe certains types (ChatTypeGroup["PARTY"] contient aussi Raid et Champ de bataille, "SAY" les Emotes, "GUILD" les Officiers) :
-- un type dont AUCUN groupe n'existe seul ne peut pas etre coche a part ; on ne l'affiche pas (la case ne reagirait jamais).
function M.TypeKnown(t)
	if t.special or not t.groups then return true end
	local tg = getglobal("ChatTypeGroup")
	if type(tg) ~= "table" then return true end
	for i = 1, getn(t.groups) do
		if tg[t.groups[i]] ~= nil then return true end
	end
	return false
end

function M.TypeOn(frame, t)
	local list = frame and frame.messageTypeList
	if type(list) ~= "table" then return false end
	if t.special == "combat" then
		for i = 1, getn(list) do
			if isCombatGroup(list[i]) then return true end
		end
		return false
	end
	local gs = usable(t)
	for i = 1, getn(gs) do
		if not listHas(list, gs[i]) then return false end
	end
	return getn(gs) > 0
end

function M.SetType(frame, t, on)
	if not frame or type(frame.messageTypeList) ~= "table" then return false end
	local list = frame.messageTypeList
	if t.special == "combat" then
		if on then
			local keep = { xp = M.TypeOn(frame, M.TYPE.xp), honor = M.TypeOn(frame, M.TYPE.honor), faction = M.TypeOn(frame, M.TYPE.faction) }
			call("ChatFrame_ActivateCombatMessages", frame)
			for k, v in pairs(keep) do
				if not v then M.SetType(frame, M.TYPE[k], false) end
			end
		else
			local drop = {}
			for i = 1, getn(list) do
				if isCombatGroup(list[i]) then tinsert(drop, list[i]) end
			end
			for i = 1, getn(drop) do call("ChatFrame_RemoveMessageGroup", frame, drop[i]) end
		end
		return true
	end
	local gs = usable(t)
	for i = 1, getn(gs) do
		local g = gs[i]
		if on and not listHas(list, g) then
			call("ChatFrame_AddMessageGroup", frame, g)
		elseif not on and listHas(list, g) then
			call("ChatFrame_RemoveMessageGroup", frame, g)
		end
	end
	return true
end

-- Canaux rejoints : noms (le client les fournit par paires numero, nom).
function M.JoinedChannels()
	local out = {}
	local gl = getglobal("GetChannelList")
	if type(gl) ~= "function" then return out end
	local t = { gl() }
	for i = 1, getn(t) do
		local v = t[i]
		if type(v) == "string" and v ~= "" and not strfind(v, "[;:,~|]") and strlen(v) <= 40 and getn(out) < 20 then tinsert(out, v) end
	end
	return out
end

function M.ChanClass(name)
	local low = strlower(name)
	if strfind(low, "trade", 1, true) or strfind(low, "commerce", 1, true) then return "trade" end
	if strfind(low, "lookingforgroup", 1, true) or strfind(low, "recherche", 1, true) or strfind(low, "lfg", 1, true) then return "lfg" end
	if strfind(low, "world", 1, true) then return "world" end
	if strfind(low, "defense", 1, true) or strfind(low, "fense", 1, true) then return "defense" end
	if strfind(low, "^general") or strfind(low, "^g.*ral") then return "general" end
	return "custom"
end

-- Entree de frame.channelList qui correspond au canal (egalite ou prefixe, sans tenir compte de la casse), ou nil.
function M.ChannelEntry(frame, name)
	local list = frame and frame.channelList
	if type(list) ~= "table" then return nil end
	local low = strlower(name)
	for i = 1, getn(list) do
		local c = strlower(tostring(list[i]))
		if c ~= "" and (c == low or strfind(low, c, 1, true) == 1) then return list[i] end
	end
	return nil
end

function M.ChannelOn(frame, name)
	return M.ChannelEntry(frame, name) ~= nil
end

function M.SetChannel(frame, name, on)
	if not frame then return false end
	local cur = M.ChannelEntry(frame, name)
	if on and not cur then
		call("ChatFrame_AddChannel", frame, name)
	elseif not on and cur then
		call("ChatFrame_RemoveChannel", frame, cur)
	end
	return true
end

-- Remplace tout le contenu d'une fenetre par un modele.
function M.ApplyPreset(id, win)
	local p = M.PRESET[id]
	local frame = frameOf(win)
	if not p or not frame or M.IsCombatLog(win) then return false end
	call("ChatFrame_RemoveAllMessageGroups", frame)
	call("ChatFrame_RemoveAllChannels", frame)
	for i = 1, getn(p.types) do M.SetType(frame, M.TYPE[p.types[i]], true) end
	local chans = M.JoinedChannels()
	for i = 1, getn(chans) do
		if p.chan == "all" or (type(p.chan) == "table" and listHas(p.chan, M.ChanClass(chans[i]))) then
			M.SetChannel(frame, chans[i], true)
		end
	end
	return true
end

-- ---------------------------------------------------------------- sauvegarde par personnage (chaine dans la base, cle globale)
local function saveKey()
	return "chattabs.layout." .. C.CharKey()
end

-- v1;id:nom:G1,G2:canal1,canal2;id:nom:...   (fenetres dans l'ordre d'affichage, journal de combat exclu)
function M.Snapshot()
	local parts = { "v1" }
	local ord = M.Ordered()
	for i = 1, getn(ord) do
		local w = ord[i]
		if not w.combat then
			local f = frameOf(w.id)
			local gs, cs = {}, {}
			if f and type(f.messageTypeList) == "table" then
				for k = 1, getn(f.messageTypeList) do
					if type(f.messageTypeList[k]) == "string" and strfind(f.messageTypeList[k], "^[A-Z_]+$") then tinsert(gs, f.messageTypeList[k]) end
				end
			end
			if f and type(f.channelList) == "table" then
				for k = 1, getn(f.channelList) do
					local c = f.channelList[k]
					if type(c) == "string" and c ~= "" and not strfind(c, "[;:,~|]") then tinsert(cs, c) end
				end
			end
			tinsert(parts, w.id .. ":" .. cleanName(w.name) .. ":" .. table.concat(gs, ",") .. ":" .. table.concat(cs, ","))
		end
	end
	return table.concat(parts, ";")
end

-- Chaine -> liste de { id, name, groups, chans } validee, ou nil.
function M.Parse(s)
	if type(s) ~= "string" or strsub(s, 1, 3) ~= "v1;" or strlen(s) > 4000 then return nil end
	local recs = split(strsub(s, 4), ";")
	local out = {}
	local seen = {}
	for i = 1, getn(recs) do
		local f = split(recs[i], ":")
		local id = tonumber(f[1])
		if getn(f) == 4 and id and id >= 1 and id <= numWin() and id == math.floor(id) and not seen[id] and getn(out) < MAXREC then
			local name = cleanName(f[2])
			local gs, cs = {}, {}
			local gl, cl = split(f[3], ","), split(f[4], ",")
			for k = 1, getn(gl) do
				if strfind(gl[k], "^[A-Z_]+$") and strlen(gl[k]) <= 40 and getn(gs) < 64 then tinsert(gs, gl[k]) end
			end
			for k = 1, getn(cl) do
				if cl[k] ~= "" and strlen(cl[k]) <= 40 and getn(cs) < 20 then tinsert(cs, cl[k]) end
			end
			if name ~= "" then
				seen[id] = true
				tinsert(out, { id = id, name = name, groups = gs, chans = cs })
			end
		end
	end
	if getn(out) == 0 then return nil end
	return out
end

function M.Save()
	if not M.Ready() or not M.CharReady() then return false end
	local snap = M.Snapshot()
	if not strfind(snap, ";", 1, true) then return false end   -- aucune fenetre lisible : on garde la sauvegarde existante
	C.SetGlobal(saveKey(), snap)
	return true
end

function M.Load()
	if not M.CharReady() then return nil end
	return M.Parse(C.GetGlobal(saveKey()))
end

function M.HasSaved()
	return M.Load() ~= nil
end

-- ---------------------------------------------------------------- actions (chacune refuse en combat et sans interface de chat)
function M.CanAct()
	if SUI.InCombat() then return false, "msg.chattabs.combat" end
	if not M.Ready() then return false, "msg.chattabs.noframes" end
	return true
end

function M.Touch()
	if SUI.Chat then SUI.Chat.dirty = true end
	if M.on and C.Get("chattabs.autosave") then M.Save() end
	local Mn = SUI.Menu
	if Mn and Mn.frame and Mn.frame:IsShown() and Mn.page == "cat" and Mn.cat == "chattabs" then Mn.Render() end
	if M.pop and M.pop:IsShown() then M.PopFill() end
end

-- Cree une fenetre ; retourne son numero ou nil, cle de message.
function M.Create(name, presetId)
	local ok, key = M.CanAct()
	if not ok then return nil, key end
	local fn = getglobal("FCF_OpenNewWindow")
	if type(fn) ~= "function" then return nil, "msg.chattabs.noapi" end
	local before = {}
	local list = M.Ordered()
	local base = {}
	for i = 1, getn(list) do
		before[list[i].id] = true
		base[i] = list[i].id
	end
	name = cleanName(name)
	if name == "" then name = L("mod.chattabs.newname", getn(list) + 1) end
	local pok, err = pcall(fn, name)
	if not pok then
		SUI.Report("chattabs", err)
		return nil, "msg.chattabs.noapi"
	end
	local id
	list = M.Shown()
	for i = 1, getn(list) do
		if not before[list[i].id] and not list[i].combat then id = list[i].id end
	end
	if not id then
		-- secours : le client a peut-etre ouvert la fenetre sans que GetChatWindowInfo la dise "visible" : on la reconnait par son nom
		-- ou parce qu'elle est maintenant attachee / affichee alors qu'elle ne l'etait pas.
		for i = 1, numWin() do
			if not before[i] and not M.IsCombatLog(i) then
				local f = frameOf(i)
				local nm = GetChatWindowInfo(i)
				if f and nm and strlower(tostring(nm)) == strlower(name) and (f.isDocked or (f.IsShown and f:IsShown())) then
					id = i
					break
				end
			end
		end
		if id then SUI.LogError("chattabs create", "fenetre " .. id .. " reconnue par secours (GetChatWindowInfo ne la disait pas visible)") end
	end
	if not id then
		SUI.LogError("chattabs create", "aucune nouvelle fenetre apres FCF_OpenNewWindow(" .. tostring(name) .. ")")
		pcall(M.RawState, "echec create " .. tostring(name))
		return nil, "msg.chattabs.full"
	end
	local frame = frameOf(id)
	call("FCF_SetWindowName", frame, name)
	call("ChatFrame_RemoveAllMessageGroups", frame)
	call("ChatFrame_RemoveAllChannels", frame)
	M.EnsurePlaced(frame, id)
	if presetId and M.PRESET[presetId] then M.ApplyPreset(presetId, id) end
	tinsert(base, id)
	M.order = base
	M.PushOrder()
	selectDock(frame)
	M.sel = id
	M.Touch()
	return id
end

function M.Rename(id, name)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	name = cleanName(name)
	if name == "" then return false, "msg.chattabs.badname" end
	local w = M.IsShown(id)
	if not w then return false, "msg.chattabs.nowin" end
	if w.combat then return false, "msg.chattabs.combatlog" end
	call("FCF_SetWindowName", frameOf(id), name)
	if SUI.Mover and SUI.Mover.items and SUI.Mover.items[M.MoverKey(id)] then M.Float(id) end
	M.Touch()
	return true
end

-- Onglets usuels proposes (cases a cocher de la page et du menu clic droit). "general" = la fenetre principale, toujours presente.
M.USUAL = {
	{ id = "general", main = true },
	{ id = "guild", preset = "guild" },
	{ id = "world", preset = "world" },
	{ id = "dungeon", preset = "dungeon" },
	{ id = "trade", preset = "trade" },
	{ id = "loot", preset = "loot" },
	{ id = "combat", preset = "combat" },
	{ id = "whisper", preset = "social" },
}
M.USUAL_ID = {}
for i = 1, getn(M.USUAL) do M.USUAL_ID[M.USUAL[i].id] = M.USUAL[i] end
M.USUALDEF = { guild = true, world = true, dungeon = true }      -- selection recommandee
M.ALIAS = { guilde = "guild", monde = "world", donjon = "dungeon", groupe = "dungeon", group = "dungeon", commerce = "trade", butin = "loot",
	chuchotements = "whisper", chuchotement = "whisper", whispers = "whisper", social = "whisper", general = "general" }
M.picks = {}
for k, v in pairs(M.USUALDEF) do M.picks[k] = v end

function M.PickedList()
	local out = {}
	for i = 1, getn(M.USUAL) do
		local u = M.USUAL[i]
		if not u.main and M.picks[u.id] then tinsert(out, u.id) end
	end
	return out
end

function M.UsualName(id)
	return L("mod.chattabs.setup." .. id)
end

-- Un onglet de ce nom existe-t-il deja (comparaison sans casse) ?
function M.HasTab(id)
	local u = M.USUAL_ID[id]
	if not u then return false end
	if u.main then return true end
	local low = strlower(M.UsualName(id))
	local shown = M.Shown()
	for i = 1, getn(shown) do
		if strlower(shown[i].name) == low then return true end
	end
	return false
end

function M.FreeSlots()
	local n = numWin() - getn(M.Shown())
	if n < 0 then n = 0 end
	return n
end

-- Cree d'un coup les onglets usuels demandes (liste d'identifiants de M.USUAL ; sans liste : Guilde, Monde, Donjon). Ceux dont le nom existe
-- deja sont ignores. Retourne true, crees, deja presents, impossibles (plus de fenetre libre...).
function M.Setup(ids)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	if type(ids) ~= "table" then
		ids = {}
		for i = 1, getn(M.USUAL) do
			if M.USUALDEF[M.USUAL[i].id] then tinsert(ids, M.USUAL[i].id) end
		end
	end
	local made, kept, failed = 0, 0, 0
	for i = 1, getn(ids) do
		local u = M.USUAL_ID[ids[i]]
		if u and not u.main then
			if M.HasTab(u.id) then
				kept = kept + 1
			else
				local nid, nkey = M.Create(M.UsualName(u.id), u.preset)
				if nid then
					made = made + 1
				else
					failed = failed + 1
					M.lastFail = tostring(nkey)
					SUI.LogError("chattabs setup", tostring(u.id) .. " : " .. tostring(nkey))
				end
			end
		end
	end
	return true, made, kept, failed
end

-- ---------------------------------------------------------------- fermeture fiable (retrait de l'arrangement sauvegarde)
-- AUDIT "je ne peux pas supprimer un onglet" : le mal venait de l'arrangement SAUVEGARDE par personnage. Fermer un onglet par le menu du jeu
-- (clic droit sur l'onglet Blizzard) ne passait pas par ce module, et meme par lui la sauvegarde n'etait corrigee que si la sauvegarde automatique
-- etait allumee : a la connexion suivante M.Restore rouvrait l'onglet "supprime". Maintenant : (1) M.Close retire TOUJOURS la fenetre de l'arrangement
-- sauvegarde ; (2) FCF_Close du jeu est enveloppe a la main (pas de hooksecurefunc en 1.12) : toute fenetre qui disparait est oubliee, une fois la
-- connexion terminee (M.restored) pour ne pas effacer l'arrangement pendant le chargement ; (3) si le client garde la fenetre apres FCF_Close, on la
-- masque nous-memes (FCF_UnDockFrame, Hide, SetChatWindowShown) et on dit clairement si c'est impossible ; (4) Restore reconnait une fenetre deja
-- ouverte du meme nom (pas de doublon "guilde"). Rien de propre a la specialisation ou au profil n'entre en jeu : l'arrangement est stocke par
-- personnage (C.CharKey) et ne depend ni du profil ShikiUI ni de la specialisation ; /sui chattabs check montre ce qui est enregistre.
local UNKNOWN_NAMES = { ["Unknown"] = true, ["UNKNOWN"] = true, ["Unknown Entity"] = true, [""] = true }

-- Le personnage est-il connu du client ? Sinon la cle de sauvegarde serait fausse ("?-?").
function M.CharReady()
	local n = UnitName and UnitName("player")
	return type(n) == "string" and not UNKNOWN_NAMES[n]
end

function M.Serialize(recs)
	local parts = { "v1" }
	for i = 1, getn(recs) do
		local r = recs[i]
		tinsert(parts, r.id .. ":" .. cleanName(r.name) .. ":" .. table.concat(r.groups, ",") .. ":" .. table.concat(r.chans, ","))
	end
	return table.concat(parts, ";")
end

-- Retire la fenetre "id" de l'arrangement sauvegarde (sauvegarde automatique allumee ou non). Retourne true si quelque chose a ete retire.
function M.Unsave(id)
	if not M.CharReady() then return false end
	local recs = M.Load()
	if not recs then return false end
	local out = {}
	for i = 1, getn(recs) do
		if recs[i].id ~= id then tinsert(out, recs[i]) end
	end
	if getn(out) == getn(recs) then return false end
	if getn(out) == 0 then C.SetGlobal(saveKey(), nil) else C.SetGlobal(saveKey(), M.Serialize(out)) end
	return true
end

-- Oublie une fenetre fermee : ordre, poignee, selection, arrangement sauvegarde, barre de chat.
function M.Forget(id)
	for i = getn(M.order), 1, -1 do
		if M.order[i] == id then table.remove(M.order, i) end
	end
	M.Unfloat(id)
	M.Unsave(id)
	if M.sel == id then M.sel = nil end
	if SUI.Chat then SUI.Chat.dirty = true end
end

function M.IsSelected(frame)
	if not frame then return false end
	if getglobal("SELECTED_CHAT_FRAME") == frame then return true end
	return (SUI.Chat and SUI.Chat.selected == frame) and true or false
end

-- Le client garde la fenetre apres FCF_Close : on la defait nous-memes.
function M.ForceHide(id)
	local frame = frameOf(id)
	if not frame then return end
	call("FCF_UnDockFrame", frame)
	if frame.Hide then frame:Hide() end
	local tab = getglobal("ChatFrame" .. id .. "Tab")
	if tab and tab.Hide then tab:Hide() end
	local sw = getglobal("SetChatWindowShown")
	if type(sw) == "function" then
		local ok, err = pcall(sw, id, 0)
		if not ok then SUI.Report("chattabs SetChatWindowShown", err) end
	end
	call("FCF_SaveDock")
	call("FCF_DockUpdate")
end

-- { [id] = nom } des fenetres visibles hors journal de combat.
function M.ShownSet()
	local set = {}
	local list = M.Shown()
	for i = 1, getn(list) do
		if not list[i].combat then set[list[i].id] = list[i].name end
	end
	return set
end

-- Enveloppe FCF_Close (menu du jeu, autres addons) : apres l'appel, toute fenetre qui n'est plus visible est oubliee. Inerte module coupe,
-- en combat (aucune table creee), pendant nos propres fermetures (M.inClose) et avant la fin de la connexion (M.restored).
function M.WrapClose()
	local cur = getglobal("FCF_Close")
	if type(cur) ~= "function" or cur == M.closeWrap then return false end
	M.closeOrig = cur
	M.closeWrap = function(a, b)
		local orig = M.closeOrig
		if not M.on or M.inClose or not M.restored or SUI.InCombat() then
			return orig(a, b)
		end
		local before = M.ShownSet()
		orig(a, b)
		local after = M.ShownSet()
		for id, name in pairs(before) do
			if not after[id] and id ~= 1 then
				M.Forget(id)
				M.closedByClient = (M.closedByClient or 0) + 1
			end
		end
		M.Touch()
	end
	setglobal("FCF_Close", M.closeWrap)
	return true
end

-- Numero d'une fenetre a partir de ce que tape le joueur : un numero, un nom d'onglet, ou un nom usuel (guilde, monde...).
function M.FindWindow(s)
	s = strlower(tostring(s or ""))
	if s == "" then return nil end
	local n = tonumber(s)
	if n and n == math.floor(n) and n >= 1 and n <= numWin() then return n end
	local alias = M.ALIAS[s]
	local usual = alias and M.USUAL_ID[alias] and strlower(M.UsualName(alias)) or nil
	local list = M.Shown()
	local best
	for i = 1, getn(list) do
		local w = list[i]
		local nm = strlower(w.name)
		if (nm == s or (usual and nm == usual)) and not w.combat then
			if not best or w.id > best then best = w.id end        -- doublons : le plus recent d'abord
		end
	end
	return best
end

-- Ferme les doublons (meme nom, sans tenir compte de la casse) : la fenetre au plus petit numero reste. Retourne le nombre de fermees.
function M.Dedupe()
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local seen, kill = {}, {}
	local list = M.Shown()
	for i = 1, getn(list) do
		local w = list[i]
		if not w.combat then
			local nm = strlower(w.name)
			if seen[nm] and w.id ~= 1 then tinsert(kill, w.id) else seen[nm] = true end
		end
	end
	local n = 0
	for i = 1, getn(kill) do
		if M.Close(kill[i]) then n = n + 1 end
	end
	return true, n
end

-- /sui chattabs check : ce qui est enregistre pour ce personnage, ce qui serait rouvert a la prochaine connexion, les doublons.
function M.CheckState()
	local out = {}
	local function add(s)
		tinsert(out, s)
		SUI.Print(s)
	end
	local function onoff(v) return v and L("mod.chattabs.v.on") or L("mod.chattabs.v.off") end
	add(L("msg.chattabs.chk.head", C.CharKey(), numWin(), onoff(C.Get("chattabs.autosave")), onoff(C.Get("chattabs.restore"))))
	local recs = M.Load()
	local ghosts = 0
	if not recs then
		add(L("msg.chattabs.chk.nosaved"))
	else
		for i = 1, getn(recs) do
			local r = recs[i]
			if M.IsShown(r.id) then
				add(L("msg.chattabs.chk.open", r.id, r.name))
			else
				ghosts = ghosts + 1
				add(L("msg.chattabs.chk.ghost", r.id, r.name))
			end
		end
	end
	if ghosts > 0 then add(L("msg.chattabs.chk.ghosthint")) end
	local names, dups = {}, 0
	local list = M.Shown()
	for i = 1, getn(list) do
		if not list[i].combat then
			local nm = strlower(list[i].name)
			names[nm] = (names[nm] or 0) + 1
			if names[nm] == 2 then
				dups = dups + 1
				add(L("msg.chattabs.chk.dup", list[i].name))
			end
		end
	end
	if dups > 0 then add(L("msg.chattabs.chk.duphint")) end
	local others = 0
	local g = C.db and C.db.global
	if type(g) == "table" then
		for k, _ in pairs(g) do
			if type(k) == "string" and strfind(k, "^chattabs%.layout%.") and k ~= saveKey() then others = others + 1 end
		end
	end
	add(L("msg.chattabs.chk.others", others))
	if ghosts == 0 and dups == 0 then add(L("msg.chattabs.chk.ok")) end
	M.lastCheck = out
	return out, ghosts, dups
end

-- /sui chattabs forget <n|tout> : oublie une fenetre de l'arrangement sauvegarde (sans la fermer) ou tout l'arrangement.
function M.ForgetSaved(what)
	if what == "all" then
		C.SetGlobal(saveKey(), nil)
		return true
	end
	return M.Unsave(what)
end

function M.Close(id)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local w = M.IsShown(id)
	if not w then return false, "msg.chattabs.nowin" end
	if id == 1 then return false, "msg.chattabs.main" end
	if w.combat then return false, "msg.chattabs.combatlog" end
	local frame = frameOf(id)
	local wasSel = M.IsSelected(frame)
	M.Unfloat(id)
	M.inClose = true
	call("FCF_Close", frame)
	call("FCF_DockUpdate")
	if M.IsShown(id) then M.ForceHide(id) end         -- le client a garde la fenetre : on la defait nous-memes
	M.inClose = false
	if M.IsShown(id) then
		SUI.LogError("chattabs close", "fenetre " .. id .. " (" .. tostring(w.name) .. ") toujours visible apres FCF_Close et le masquage de secours")
		pcall(M.RawState, "echec close " .. id)
		if frame and not frame.isDocked then M.Float(id) end
		return false, "msg.chattabs.closefail"
	end
	M.Forget(id)
	M.PushOrder()
	if wasSel then selectDock(frameOf(1)) end
	SUI.Print(L("msg.chattabs.closed", w.name))
	M.Touch()
	return true
end

-- dir = -1 (vers la gauche) ou 1 (vers la droite) dans la barre.
function M.Move(id, dir)
	local ord = M.Ordered()
	local pos
	for i = 1, getn(ord) do
		if ord[i].id == id then pos = i end
	end
	if not pos then return false, "msg.chattabs.nowin" end
	local to = pos + dir
	if to < 1 or to > getn(ord) then return false end
	local a, b = ord[pos], ord[to]
	ord[pos], ord[to] = b, a
	local ids = {}
	for i = 1, getn(ord) do ids[i] = ord[i].id end
	M.order = ids
	M.PushOrder()
	M.Touch()
	return true
end

function M.DoPreset(id, presetId)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	if not M.IsShown(id) then return false, "msg.chattabs.nowin" end
	if M.IsCombatLog(id) then return false, "msg.chattabs.combatlog" end
	if not M.ApplyPreset(presetId, id) then return false, "msg.chattabs.nopreset" end
	M.Touch()
	return true
end

function M.DoType(id, typeId, on)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local t = M.TYPE[typeId]
	if not t or not M.IsShown(id) then return false, "msg.chattabs.nowin" end
	if M.IsCombatLog(id) then return false, "msg.chattabs.combatlog" end
	M.SetType(frameOf(id), t, on)
	M.Touch()
	return true
end

function M.DoChannel(id, name, on)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	if not M.IsShown(id) then return false, "msg.chattabs.nowin" end
	if M.IsCombatLog(id) then return false, "msg.chattabs.combatlog" end
	M.SetChannel(frameOf(id), name, on)
	M.Touch()
	return true
end

-- Rejoue l'arrangement sauvegarde : ouvre les fenetres manquantes, renomme, remet types et canaux, retablit l'ordre.
function M.Restore()
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local recs = M.Load()
	if not recs then return false, "msg.chattabs.nosaved" end
	local target = {}
	local taken = {}
	local opened = {}
	-- 1) une fenetre deja ouverte du MEME NOM est reprise d'abord (pas de doublon "guilde", meme si le numero a change)
	for i = 1, getn(recs) do
		local low = strlower(recs[i].name)
		local cur = M.Shown()
		for k = 1, getn(cur) do
			if not target[i] and not cur[k].combat and not taken[cur[k].id] and strlower(cur[k].name) == low then
				target[i] = cur[k].id
				taken[cur[k].id] = true
			end
		end
	end
	-- 2) sinon la fenetre de meme numero (elle sera renommee)
	for i = 1, getn(recs) do
		if not target[i] then
			local w = M.IsShown(recs[i].id)
			if w and not w.combat and not taken[recs[i].id] then
				target[i] = recs[i].id
				taken[recs[i].id] = true
			end
		end
	end
	for i = 1, getn(recs) do
		if not target[i] then
			local before = {}
			local list = M.Shown()
			for k = 1, getn(list) do before[list[k].id] = true end
			local fn = getglobal("FCF_OpenNewWindow")
			if type(fn) == "function" then pcall(fn, recs[i].name) end
			list = M.Shown()
			for k = 1, getn(list) do
				if not before[list[k].id] and not list[k].combat and not taken[list[k].id] then
					target[i] = list[k].id
					taken[list[k].id] = true
					opened[list[k].id] = true
				end
			end
		end
	end
	local order = {}
	for i = 1, getn(recs) do
		local id = target[i]
		if id then
			local r = recs[i]
			local frame = frameOf(id)
			if opened[id] then M.EnsurePlaced(frame, id) end
			local w = M.IsShown(id)
			if w and w.name ~= r.name then call("FCF_SetWindowName", frame, r.name) end
			call("ChatFrame_RemoveAllMessageGroups", frame)
			call("ChatFrame_RemoveAllChannels", frame)
			for k = 1, getn(r.groups) do
				call("ChatFrame_AddMessageGroup", frame, r.groups[k])
			end
			for k = 1, getn(r.chans) do call("ChatFrame_AddChannel", frame, r.chans[k]) end
			tinsert(order, id)
		end
	end
	-- les fenetres hors arrangement (journal de combat, fenetres non sauvegardees) gardent leur rang ; les autres suivent l'ordre restaure
	local inOrder = {}
	for i = 1, getn(order) do inOrder[order[i]] = true end
	local final, nxt = {}, 1
	local cur = M.Ordered()
	for i = 1, getn(cur) do
		local w = cur[i]
		if w.combat or not (inOrder[w.id] or taken[w.id]) then
			tinsert(final, w.id)
		elseif nxt <= getn(order) then
			tinsert(final, order[nxt])
			nxt = nxt + 1
		end
	end
	while nxt <= getn(order) do
		tinsert(final, order[nxt])
		nxt = nxt + 1
	end
	M.order = final
	M.PushOrder()
	call("FCF_DockUpdate")
	M.Refloat()
	if SUI.Chat then SUI.Chat.dirty = true end
	return true, getn(order)
end

-- Retour a l'arrangement du client : fenetre 1 = tout sauf le combat, journal de combat intact, les autres fermees ; sauvegarde effacee.
function M.Reset()
	local ok, key = M.CanAct()
	if not ok then return false, key end
	local list = M.Shown()
	M.inClose = true
	for i = 1, getn(list) do
		if list[i].id ~= 1 and not list[i].combat then
			M.Unfloat(list[i].id)
			call("FCF_Close", frameOf(list[i].id))
		end
	end
	M.inClose = false
	local frame = frameOf(1)
	call("FCF_SetWindowName", frame, getglobal("GENERAL") or "General")
	M.ApplyPreset("all", 1)
	M.SetType(frame, M.TYPE.combat, false)
	call("FCF_DockUpdate")
	M.order = {}
	M.PushOrder()
	M.sel = nil
	C.SetGlobal(saveKey(), nil)
	selectDock(frame)
	M.Touch()
	return true
end

function M.AutoRestore()
	M.restoreTask = nil
	if not M.on or M.restored then return end
	if SUI.InCombat() then
		SUI.WhenSafe(M.AutoRestore)
		return
	end
	M.restored = true
	local did = false
	if C.Get("chattabs.restore") and M.HasSaved() then
		local ok, n = M.Restore()
		if ok then
			did = true
			SUI.Print(L("msg.chattabs.restored", n))
		end
	end
	if not did then
		if C.Get("chattabs.autosetup") then M.AutoSetup() else M.Hint() end
	end
	M.TidyFloating()
	M.FlushDedicated()
end

-- Une seule fois par personnage : les fenetres de chat laissees flottantes par le jeu (ex. "Loot & Spam", grand cadre noir a droite de l'ecran)
-- sont rattachees a la barre d'onglets. Elles restent detachables ensuite (bouton Detacher) ; rien n'est touche une fois le menage fait.
function M.TidyFloating()
	local key = "chattabs.tidy." .. C.CharKey()
	if C.GetGlobal(key) then return false end
	C.SetGlobal(key, 1)
	local list = M.Shown()
	local n = 0
	for i = 1, getn(list) do
		local w = list[i]
		local fr = frameOf(w.id)
		if w.id ~= 1 and not w.combat and fr and not fr.isDocked then
			local ok = M.Attach(w.id)
			if ok then n = n + 1 end
		end
	end
	return n > 0
end

local function plainCount()
	local n = 0
	local shown = M.Shown()
	for i = 1, getn(shown) do
		if not shown[i].combat then n = n + 1 end
	end
	return n
end

-- Option "Creer les onglets usuels au premier lancement" : une seule fois par personnage, seulement s'il n'y a que la fenetre principale.
function M.AutoSetup()
	local key = "chattabs.setupdone." .. C.CharKey()
	if C.GetGlobal(key) then return false end
	C.SetGlobal(key, 1)
	if plainCount() > 1 then return false end
	local ok, made = M.Setup()
	if ok and made and made > 0 then SUI.Print(L("msg.chattabs.autosetup", made)) end
	return ok
end

-- Sans l'option : un seul message d'astuce par personnage quand il n'y a qu'un onglet.
function M.Hint()
	local key = "chattabs.hint." .. C.CharKey()
	if C.GetGlobal(key) or plainCount() > 1 then return false end
	C.SetGlobal(key, 1)
	SUI.Print(L("msg.chattabs.hint"))
	return true
end

-- ---------------------------------------------------------------- canaux dedies (un canal personnalise = un onglet)
-- Option chattabs.dedicated : quand on rejoint un canal personnalise (World...), ShikiUI l'attache a UN onglet du meme nom (cree au besoin)
-- et le retire des autres (General en tete) : les messages n'apparaissent plus que dans cet onglet. Memorise par personnage
-- (cle globale chattabs.dedic.<perso> = "canal=onglet;..."). Les canaux de base (General, Commerce, Recherche de groupe, Defense) sont laisses.
function M.BaseName(s)
	s = tostring(s or "")
	s = strgsub(s, "^%s*%d+%.%s*", "")
	return cleanName(s)
end

local function dedicKey()
	return "chattabs.dedic." .. C.CharKey()
end

function M.DedicMap()
	local map = {}
	local s = C.GetGlobal(dedicKey())
	if type(s) ~= "string" then return map end
	local recs = split(s, ";")
	for i = 1, getn(recs) do
		local a = strfind(recs[i], "=", 1, true)
		if a then
			local k, v = strsub(recs[i], 1, a - 1), strsub(recs[i], a + 1)
			if k ~= "" and v ~= "" and strlen(k) <= 40 then map[k] = v end
		end
	end
	return map
end

function M.DedicSave(map)
	local parts, n = {}, 0
	for k, v in pairs(map) do
		n = n + 1
		if n <= 20 then tinsert(parts, k .. "=" .. strgsub(v, "=", " ")) end
	end
	table.sort(parts)
	C.SetGlobal(dedicKey(), table.concat(parts, ";"))
end

-- Un canal est "dedicable" s'il est personnalise (World compris).
function M.Dedicable(name)
	local cl = M.ChanClass(name)
	return cl == "world" or cl == "custom"
end

local function windowByName(name)
	local low = strlower(name)
	local list = M.Shown()
	for i = 1, getn(list) do
		if not list[i].combat and strlower(list[i].name) == low then return list[i] end
	end
	return nil
end

-- Attache le canal a l'onglet "tab" (cree si absent) et le retire des autres fenetres. Retourne ok|false, cle ou "a-change".
function M.Dedicate(chan, tab)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	chan = M.BaseName(chan)
	tab = M.BaseName(tab or chan)
	if chan == "" or tab == "" then return false, "msg.chattabs.badname" end
	local keepSel = getglobal("SELECTED_CHAT_FRAME")
	local changed = false
	local w = windowByName(tab)
	local id
	if w then
		id = w.id
	else
		local nid, k2 = M.Create(tab)
		if not nid then return false, k2 end
		id = nid
		changed = true
		-- la creation selectionne le nouvel onglet : on rend la main a celui que le joueur regardait
		if keepSel then selectDock(keepSel) end
	end
	local frame = frameOf(id)
	if not M.ChannelOn(frame, chan) then changed = true end
	M.SetChannel(frame, chan, true)
	local list = M.Shown()
	for i = 1, getn(list) do
		if list[i].id ~= id and not list[i].combat then
			local f = frameOf(list[i].id)
			if M.ChannelOn(f, chan) then
				M.SetChannel(f, chan, false)
				changed = true
			end
		end
	end
	local map = M.DedicMap()
	if map[strlower(chan)] ~= tab then
		map[strlower(chan)] = tab
		M.DedicSave(map)
	end
	M.Touch()
	return true, changed
end

-- Annule : le canal revient dans la fenetre principale et n'est plus memorise.
function M.Undedicate(chan)
	local ok, key = M.CanAct()
	if not ok then return false, key end
	chan = M.BaseName(chan)
	local map = M.DedicMap()
	local tab = map[strlower(chan)]
	if not tab then return false, "msg.chattabs.dedicnone" end
	map[strlower(chan)] = nil
	M.DedicSave(map)
	local w = windowByName(tab)
	if w and w.id ~= 1 then M.SetChannel(frameOf(w.id), chan, false) end
	M.SetChannel(frameOf(1), chan, true)
	M.Touch()
	return true
end

M.dedicPending = {}

local function dedicRun(chan)
	local tab = M.DedicMap()[strlower(chan)] or chan
	SUI.WhenSafe(function()
		if not M.on or not C.Get("chattabs.dedicated") then return end
		local ok, changed = M.Dedicate(chan, tab)
		if ok and changed then SUI.Print(L("msg.chattabs.dedic", chan, tab)) end
	end)
end

-- Mise en place des canaux deja rejoints : ceux memorises ou en attente (ou tous les canaux personnalises si all).
function M.FlushDedicated(all)
	if not M.on or not C.Get("chattabs.dedicated") then return end
	local map = M.DedicMap()
	local chans = M.JoinedChannels()
	for i = 1, getn(chans) do
		local low = strlower(chans[i])
		if M.Dedicable(chans[i]) and (all or map[low] or M.dedicPending[low]) then dedicRun(chans[i]) end
	end
	M.dedicPending = {}
end

-- CHAT_MSG_CHANNEL_NOTICE : arg1 = YOU_JOINED / YOU_CHANGED, arg4 = "2. World".
function M.OnNotice(ev, a1, a2, a3, a4)
	if not M.on or not C.Get("chattabs.dedicated") then return end
	if a1 ~= "YOU_JOINED" and a1 ~= "YOU_CHANGED" then return end
	local name = M.BaseName(a4)
	if name == "" or not M.Dedicable(name) then return end
	if not M.restored then
		M.dedicPending[strlower(name)] = true     -- l'arrangement sauvegarde n'est pas encore rejoue : on attend
		return
	end
	-- le client ajoute lui-meme le canal a la fenetre principale a l'arrivee de la notice : on passe apres lui
	SUI.After(0.5, function() dedicRun(name) end, "chattabs.dedic." .. strlower(name))
end

-- Fenetre a afficher quand le joueur clique un canal : nil si la fenetre courante le montre deja (ou si aucune ne le montre).
function M.FrameForChannel(name)
	if not M.on or not name or name == "" then return nil end
	local cur = getglobal("SELECTED_CHAT_FRAME")
	if cur and M.ChannelOn(cur, name) then return nil end
	local list = M.Ordered()
	for i = 1, getn(list) do
		if not list[i].combat then
			local f = frameOf(list[i].id)
			if f and M.ChannelOn(f, name) then return f end
		end
	end
	return nil
end

-- Etat BRUT de toutes les fenetres de chat (diagnostic) : une ligne par fenetre, rangee dans les variables sauvegardees
-- (ShikiUIDB.global.chattabs.dump) pour etre relue apres /reload. Aucune hypothese : on note ce que le client repond.
function M.RawState(tag)
	local out = {}
	local function b(v) return v and "1" or "0" end
	tinsert(out, "etat " .. tostring(tag) .. " numWin=" .. tostring(numWin()) .. " combat=" .. b(SUI.InCombat()))
	local dock = getglobal("DOCKED_CHAT_FRAMES")
	if type(dock) == "table" then
		local ids = {}
		for i = 1, getn(dock) do tinsert(ids, tostring(dock[i] and dock[i].GetID and dock[i]:GetID() or "?")) end
		tinsert(out, "DOCKED_CHAT_FRAMES=" .. table.concat(ids, ","))
	else
		tinsert(out, "DOCKED_CHAT_FRAMES=absent")
	end
	tinsert(out, "M.order=" .. table.concat(M.order or {}, ","))
	for i = 1, numWin() do
		local name, size, r, g, bl, a, shown, locked, docked = GetChatWindowInfo(i)
		local f = frameOf(i)
		local tab = getglobal("ChatFrame" .. i .. "Tab")
		local bt = SUI.Chat and SUI.Chat.tabs and SUI.Chat.tabs[i]
		local nmsg = (f and type(f.messageTypeList) == "table") and getn(f.messageTypeList) or -1
		tinsert(out, "W" .. i .. " nom=" .. tostring(name) .. " info.shown=" .. tostring(shown) .. " info.docked=" .. tostring(docked)
			.. " isDocked=" .. tostring(f and f.isDocked) .. " frameShown=" .. b(f and f.IsShown and f:IsShown())
			.. " tabShown=" .. b(tab and tab.IsShown and tab:IsShown()) .. " barSlot=" .. tostring(bt and bt.slot)
			.. " msgGroups=" .. nmsg .. " combatlog=" .. b(M.IsCombatLog(i)))
	end
	C.SetGlobal("chattabs.dump", out)
	M.lastRaw = out
	return out
end

function M.OnEnter()
	M.WrapClose()
	if M.restored or M.restoreTask then return end
	M.restoreTask = SUI.After(4, M.AutoRestore, "chattabs.restore")
	SUI.After(9, function() pcall(M.RawState, "login") end, "chattabs.rawstate")
end

local function say(ok, key, a)
	if not ok and key then SUI.Print(L(key, a)) end
	return ok
end

-- Message apres M.Setup.
function M.SetupReport(ok, made, kept, failed)
	if not say(ok, made) then return false end
	SUI.Print(L("msg.chattabs.setupdone", made, kept or 0, failed or 0))
	if failed and failed > 0 then
		SUI.Print(L("msg.chattabs.full"))
		SUI.Print("(" .. tostring(M.lastFail) .. ")")
	end
	return true
end

-- ---------------------------------------------------------------- menu contextuel (clic droit sur un onglet de la barre ShikiUI)
local POPN = 24

function M.BuildPopup()
	if M.pop then return end
	local f = T.Panel(UIParent, 250, 120)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(200)
	f:EnableMouse(true)
	f:Hide()
	M.pop = f
	f.title = T.Text(f, 11, T.c.dim, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
	f.title:SetWidth(234)
	f.title:SetHeight(14)
	f.btns = {}
	for i = 1, POPN do
		local b = T.Button(f, "", 116, 20, function(btn)
			if btn.fn then btn.fn() end
		end)
		b:Hide()
		f.btns[i] = b
	end
	f.edit = T.Edit(f, 234, 22)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
	f.edit:SetMaxLetters(MAXNAME)
	f.edit:SetScript("OnEnterPressed", function() M.PopEditOk() end)
	f.edit:SetScript("OnEscapePressed", function() M.PopClose() end)
	f.edit:Hide()
	local cat = CreateFrame("Button", nil, UIParent)
	cat:SetAllPoints(UIParent)
	cat:SetFrameStrata("FULLSCREEN_DIALOG")
	cat:SetFrameLevel(190)
	cat:EnableMouse(true)
	cat:SetScript("OnClick", function() M.PopClose() end)
	cat:Hide()
	M.popCatcher = cat
	f:SetScript("OnHide", function()
		M.popCatcher:Hide()
		M.pop.edit:ClearFocus()
	end)
	setglobal("ShikiUI_ChatTabMenu", f)
end

function M.PopClose()
	M.popArm = nil
	if M.pop then M.pop:Hide() end
end

function M.PopGo(page, mode)
	M.popPage = page
	M.popMode = mode
	M.popArm = nil
	M.PopFill()
end

function M.PopEditOk()
	local text = M.pop.edit:GetText() or ""
	local id = M.popWin
	if M.popMode == "rename" then
		say(M.Rename(id, text))
	else
		say(M.Create(text))
	end
	M.PopClose()
end

-- Liste des lignes du menu pour la page courante : { label, fn, selected }.
function M.PopItems()
	local items = {}
	local id = M.popWin
	local w = M.IsShown(id)
	local page = M.popPage
	local function add(label, fn, sel)
		tinsert(items, { label = label, fn = fn, sel = sel })
	end
	if not w then return items end
	if page == "main" then
		if not w.combat then add(L("mod.chattabs.pop.rename"), function() M.PopGo("edit", "rename") end) end
		add(L("mod.chattabs.pop.new"), function() M.PopGo("edit", "new") end)
		add(L("mod.chattabs.pop.setup"), function() M.PopGo("setup") end)
		if id ~= 1 and not w.combat then
			add(M.popArm == "close" and L("mod.chattabs.pop.confirm") or L("mod.chattabs.pop.close"), function()
				if M.popArm == "close" then
					say(M.Close(id))
					M.PopClose()
				else
					M.popArm = "close"
					M.PopFill()
				end
			end)
		end
		if id ~= 1 and not w.combat then
			local fr = frameOf(id)
			if fr and fr.isDocked then
				add(L("mod.chattabs.pop.detach"), function()
					if say(M.Detach(id)) then
						SUI.Print(L("msg.chattabs.detached", id))
						M.PopClose()
					end
				end)
			else
				add(L("mod.chattabs.pop.attach"), function()
					if say(M.Attach(id)) then
						SUI.Print(L("msg.chattabs.attached", id))
						M.PopClose()
					end
				end)
			end
			-- affectation a la barre d'onglets 2 (la fenetre garde sa place, seuls ses onglets changent de barre)
			if SUI.Chat and SUI.Chat.InBar2 and SUI.Chat.SetBar then
				if SUI.Chat.InBar2(id) then
					add(L("mod.chattabs.pop.bar1"), function()
						if say(SUI.Chat.SetBar(id, false)) then M.PopClose() end
					end)
				else
					add(L("mod.chattabs.pop.bar2"), function()
						if say(SUI.Chat.SetBar(id, true)) then M.PopClose() end
					end)
				end
			end
		end
		add(L("mod.chattabs.pop.tidy"), function()
			local ok, n = M.Tidy()
			if say(ok, n) then SUI.Print(L("msg.chattabs.tidied", n)) end
			M.PopClose()
		end)
		add(L("mod.chattabs.pop.left"), function() say(M.Move(id, -1)) end)
		add(L("mod.chattabs.pop.right"), function() say(M.Move(id, 1)) end)
		if not w.combat then
			add(L("mod.chattabs.pop.presets"), function() M.PopGo("presets") end)
			add(L("mod.chattabs.pop.types"), function() M.PopGo("types") end)
			add(L("mod.chattabs.pop.chans"), function() M.PopGo("chans") end)
		end
		add(L("mod.chattabs.pop.manager"), function()
			M.sel = id
			M.PopClose()
			M.OpenManager()
		end)
	elseif page == "setup" then
		for i = 1, getn(M.USUAL) do
			local u = M.USUAL[i]
			if not u.main then
				local has = M.HasTab(u.id)
				local on = has or M.picks[u.id]
				add((on and "[x] " or "[  ] ") .. M.UsualName(u.id), function()
					if not has then M.picks[u.id] = (not M.picks[u.id]) or nil end
					M.PopFill()
				end, on)
			end
		end
		add(L("mod.chattabs.setup.go"), function()
			M.SetupReport(M.Setup(M.PickedList()))
			M.PopClose()
		end)
		add(L("mod.chattabs.pop.back"), function() M.PopGo("main") end)
	elseif page == "presets" then
		for i = 1, getn(M.PRESETS) do
			local pid = M.PRESETS[i].id
			add(L("mod.chattabs.preset." .. pid), function() say(M.DoPreset(id, pid)) end)
		end
		add(L("mod.chattabs.pop.back"), function() M.PopGo("main") end)
	elseif page == "types" then
		local frame = frameOf(id)
		for i = 1, getn(M.TYPES) do
			local t = M.TYPES[i]
			if M.TypeKnown(t) then
			local on = M.TypeOn(frame, t)
			add((on and "[x] " or "[  ] ") .. L("mod.chattabs.type." .. t.id), function() say(M.DoType(id, t.id, not on)) end, on)
			end
		end
		add(L("mod.chattabs.pop.back"), function() M.PopGo("main") end)
	elseif page == "chans" then
		local frame = frameOf(id)
		local chans = M.JoinedChannels()
		if getn(chans) == 0 then add(L("mod.chattabs.nochans"), function() end) end
		for i = 1, getn(chans) do
			local name = chans[i]
			local on = M.ChannelOn(frame, name)
			add((on and "[x] " or "[  ] ") .. M.ShortChan(name), function() say(M.DoChannel(id, name, not on)) end, on)
		end
		add(L("mod.chattabs.pop.back"), function() M.PopGo("main") end)
	end
	return items
end

function M.ShortChan(name)
	if strlen(name) > 14 then return strsub(name, 1, 13) .. "." end
	return name
end

function M.PopFill()
	local f = M.pop
	if not f then return end
	local w = M.IsShown(M.popWin)
	if not w then
		M.PopClose()
		return
	end
	f.title:SetText(w.name)
	local top = 26
	local items
	if M.popPage == "edit" then
		items = {}
		f.edit:Show()
		tinsert(items, { label = L("mod.chattabs.pop.ok"), fn = function() M.PopEditOk() end })
		tinsert(items, { label = L("mod.chattabs.pop.back"), fn = function() M.PopGo("main") end })
		top = 54
		if M.popFresh then
			M.popFresh = false
			f.edit:SetText(M.popMode == "rename" and w.name or "")
			f.edit:SetFocus()
		end
	else
		f.edit:Hide()
		items = M.PopItems()
	end
	local n = getn(items)
	if n > POPN then n = POPN end
	for i = 1, POPN do
		local b = f.btns[i]
		if i <= n then
			local it = items[i]
			local col = SUI.Mod(i - 1, 2)
			local row = (i - 1 - col) / 2
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + col * 120, -top - row * 22)
			T.SetButtonText(b, it.label)
			b.fn = it.fn
			T.SetSelected(b, it.sel)
			b:Show()
		else
			b:Hide()
		end
	end
	local rows = math.floor((n + 1) / 2)
	f:SetHeight(top + rows * 22 + 8)
end

-- Appele par le module chat (clic droit sur l'onglet de la fenetre idx). Retourne true si le clic est traite.
function M.TabMenu(idx, anchor)
	if not M.on or not M.pop or not C.Get("chattabs.menu") or SUI.InCombat() then return false end
	M.popWin = idx
	M.popPage = "main"
	M.popMode = nil
	M.popArm = nil
	M.popFresh = true
	if not M.special then
		M.special = true
		tinsert(UISpecialFrames, "ShikiUI_ChatTabMenu")      -- Echap ferme le menu (inscrit a la 1re ouverture : le menu principal garde la 1re place)
	end
	M.pop:ClearAllPoints()
	M.pop:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
	M.popCatcher:Show()
	M.pop:Show()
	M.PopFill()
	return true
end

function M.OpenManager()
	if SUI.Menu and SUI.Menu.Show then SUI.Menu.Show("chattabs") end
end

-- ---------------------------------------------------------------- page du menu (sections ajoutees a la page de la categorie)
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

local function wheelOn(f)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", SUI.Menu.OnWheel)
	return f
end

-- Case a cocher avec libelle : f.fn(on) est appelee au clic.
local function newCheckRow()
	local Mn = SUI.Menu
	local f = CreateFrame("Button", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	wheelOn(f)
	f:SetScript("OnClick", function()
		local s = this
		if s.fn then s.fn(not s.chk.on) end
	end)
	f.chk = T.Check(f, function(on)
		if f.fn then f.fn(on) end
	end)
	f.chk:SetPoint("LEFT", f, "LEFT", 6, 0)
	f.txt = T.Text(f, 11, T.c.text, "LEFT")
	f.txt:SetPoint("LEFT", f, "LEFT", 30, 0)
	f.txt:SetWidth(170)
	f.txt:SetHeight(14)
	return f
end

local function newEditRow()
	local Mn = SUI.Menu
	local f = CreateFrame("Frame", nil, Mn.child)
	f:SetFrameLevel(Mn.lvl + 2)
	f.edit = T.Edit(f, 250, 24)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.edit:SetMaxLetters(MAXNAME)
	f.edit:SetScript("OnTextChanged", function()
		local e = this
		if not e.silent then M.editText = e:GetText() or "" end
	end)
	f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	return f
end

local function rowBtn(x, w, h, label, fn, selected)
	local Mn = SUI.Menu
	local b = Mn.Get("btn")
	if not b then return nil end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", Mn.child, "TOPLEFT", x, -Mn.y)
	b:SetWidth(w)
	b:SetHeight(h)
	b:Show()
	b.y, b.h = Mn.y, h
	T.SetButtonText(b, label)
	b.fn = fn
	T.SetSelected(b, selected)
	return b
end

local function selWindow(wins)
	local ok = false
	for i = 1, getn(wins) do
		if wins[i].id == M.sel then ok = true end
	end
	if not ok then
		M.sel = nil
		for i = 1, getn(wins) do
			if not M.sel and not wins[i].combat then M.sel = wins[i].id end
		end
		if not M.sel and wins[1] then M.sel = wins[1].id end
	end
	for i = 1, getn(wins) do
		if wins[i].id == M.sel then return wins[i] end
	end
	return nil
end

local function windowRow(w, pos, total)
	local Mn = SUI.Menu
	local id = w.id
	local label = w.name
	if w.combat then label = label .. "  (" .. L("mod.chattabs.combatlog") .. ")" end
	local first = Mn.Get("btn")
	if not first then return end
	Mn.Flow(first, 1, 300, 26, 0, 4)
	T.SetButtonText(first, label)
	first.fn = function()
		M.sel = id
		M.editFor = nil
		Mn.Render()
	end
	T.SetSelected(first, M.sel == id)
	local x = 306
	if pos > 1 then
		rowBtn(x, 80, 26, L("mod.chattabs.left"), function() say(M.Move(id, -1)) end, false)
		x = x + 84
	end
	if pos < total then
		rowBtn(x, 80, 26, L("mod.chattabs.right"), function() say(M.Move(id, 1)) end, false)
		x = x + 84
	end
	if id ~= 1 and not w.combat then
		rowBtn(x, 90, 26, L("mod.chattabs.close"), function(b)
			Mn.ConfirmClick(b, "ct:close:" .. id, L("mod.chattabs.close"), function() say(M.Close(id)) end)
		end, false)
	end
	Mn.EndRow(4)
end

local function editRow(sel)
	local Mn = SUI.Menu
	local ed = Mn.Get("ct_edit")
	if not ed then return end
	Mn.Flow(ed, 1, 250, 24, 0, 6)
	if M.editFor ~= (sel and sel.id) then
		M.editFor = sel and sel.id
		M.editText = (sel and not sel.combat) and sel.name or ""
	end
	ed.edit.silent = true
	if (ed.edit:GetText() or "") ~= M.editText then ed.edit:SetText(M.editText) end
	ed.edit.silent = false
	if sel and not sel.combat then
		rowBtn(256, 130, 24, L("mod.chattabs.rename"), function() say(M.Rename(sel.id, M.editText)) end, false)
	end
	rowBtn(390, 150, 24, L("mod.chattabs.create"), function() say(M.Create(M.editText)) end, false)
	Mn.EndRow(6)
end

local function checkCells(items, cols, w, gx)
	local Mn = SUI.Menu
	for i = 1, getn(items) do
		local c = Mn.Get("ct_chk")
		if not c then break end
		Mn.Flow(c, cols, w, 24, gx, 4)
		c.txt:SetWidth(w - 36)
		c.txt:SetText(items[i].label)
		T.SetCheck(c.chk, items[i].on)
		c.fn = items[i].fn
	end
	Mn.EndRow(4)
end

function M.Page()
	local Mn = SUI.Menu
	local mod = SUI.modules.chattabs
	if not mod or not mod.enabled then
		Mn.Para(L("mod.chattabs.disabled"), 34, T.c.warn)
		return
	end
	if not M.Ready() then
		Mn.Para(L("mod.chattabs.noframes"), 34, T.c.warn)
		return
	end
	local wins = M.Ordered()
	local sel = selWindow(wins)
	-- demarrage rapide : onglets usuels a cocher + gros bouton
	Mn.Section(L("mod.chattabs.sec.quick"), getn(wins) .. "/" .. numWin())
	Mn.Para(L("mod.chattabs.help.quick", M.FreeSlots()), 42)
	local usual = {}
	for i = 1, getn(M.USUAL) do
		local u = M.USUAL[i]
		local has = M.HasTab(u.id)
		local label = M.UsualName(u.id)
		if has then label = label .. " *" end
		tinsert(usual, { label = label, on = has or M.picks[u.id] and true or false, fn = function(on)
			if not has then M.picks[u.id] = on and true or nil end
			Mn.Render()
		end })
	end
	checkCells(usual, 4, 153, 12)
	Mn.GridBtn(L("mod.chattabs.setup.go"), 1, CW, 40, function()
		M.SetupReport(M.Setup(M.PickedList()))
		Mn.Render()
	end)
	Mn.EndRow(10)
	Mn.Section(L("mod.chattabs.sec.tabs"), tostring(getn(wins)))
	Mn.Para(L("mod.chattabs.help.tabs"), 30)
	for i = 1, getn(wins) do windowRow(wins[i], i, getn(wins)) end
	Mn.Para(L("mod.chattabs.help.name"), 18)
	editRow(sel)
	-- modeles
	Mn.Section(L("mod.chattabs.sec.presets"), sel and sel.name or "")
	if not sel or sel.combat then
		Mn.Para(L("mod.chattabs.nopresetwin"), 30)
	else
		Mn.Para(L("mod.chattabs.help.presets", sel.name), 30)
		for i = 1, getn(M.PRESETS) do
			local pid = M.PRESETS[i].id
			Mn.GridBtn(L("mod.chattabs.preset." .. pid), 4, 153, 28, function() say(M.DoPreset(sel.id, pid)) end)
		end
		Mn.EndRow(8)
	end
	-- sauvegarde
	Mn.Section(L("mod.chattabs.sec.save"))
	Mn.Para(M.HasSaved() and L("mod.chattabs.saved.yes") or L("mod.chattabs.saved.no"), 18)
	Mn.GridBtn(L("mod.chattabs.save"), 3, 208, 28, function()
		say(M.CanAct())
		if M.Save() then SUI.Print(L("msg.chattabs.saved")) end
		Mn.Render()
	end)
	Mn.GridBtn(L("mod.chattabs.restore"), 3, 208, 28, function()
		local ok, a = M.Restore()
		if ok then SUI.Print(L("msg.chattabs.restored", a)) else say(ok, a) end
		Mn.Render()
	end)
	Mn.GridBtn(L("mod.chattabs.reset"), 3, 208, 28, function(b)
		Mn.ConfirmClick(b, "ct:reset", L("mod.chattabs.reset"), function()
			if say(M.Reset()) then SUI.Print(L("msg.chattabs.reset")) end
		end)
	end)
	Mn.EndRow(8)
	-- fenetres libres, rangement, diagnostic
	local selFrame = sel and frameOf(sel.id)
	local canDetach = sel and sel.id ~= 1 and not sel.combat and selFrame
	local attached = selFrame and selFrame.isDocked
	Mn.GridBtn(attached and L("mod.chattabs.pop.detach") or L("mod.chattabs.pop.attach"), 3, 208, 28, function()
		if not canDetach then return end
		if attached then
			if say(M.Detach(sel.id)) then SUI.Print(L("msg.chattabs.detached", sel.id)) end
		elseif say(M.Attach(sel.id)) then
			SUI.Print(L("msg.chattabs.attached", sel.id))
		end
		Mn.Render()
	end)
	Mn.GridBtn(L("mod.chattabs.tidy"), 3, 208, 28, function()
		local ok, n = M.Tidy()
		if say(ok, n) then SUI.Print(L("msg.chattabs.tidied", n)) end
		Mn.Render()
	end)
	Mn.GridBtn(L("mod.chattabs.dump"), 3, 208, 28, function() M.Dump() end)
	Mn.EndRow(8)
	Mn.GridBtn(L("mod.chattabs.check"), 3, 208, 28, function() M.CheckState() end)
	Mn.GridBtn(L("mod.chattabs.dedupe"), 3, 208, 28, function(b)
		Mn.ConfirmClick(b, "ct:dedupe", L("mod.chattabs.dedupe"), function()
			local dok, n = M.Dedupe()
			if say(dok, n) then SUI.Print(L("msg.chattabs.deduped", n)) end
			Mn.Render()
		end)
	end)
	Mn.GridBtn(L("mod.chattabs.forget"), 3, 208, 28, function(b)
		Mn.ConfirmClick(b, "ct:forget", L("mod.chattabs.forget"), function()
			M.ForgetSaved("all")
			SUI.Print(L("msg.chattabs.forgot"))
			Mn.Render()
		end)
	end)
	Mn.EndRow(8)
	Mn.Para(L("mod.chattabs.help.check"), 30)
	-- cases a cocher : types et canaux de l'onglet choisi (toujours affichees : c'est le coeur de la configuration)
	if not sel or sel.combat then return end
	local frame = frameOf(sel.id)
	Mn.Section(L("mod.chattabs.sec.types"), sel.name)
	local items = {}
	local merged = false
	for i = 1, getn(M.TYPES) do
		local t = M.TYPES[i]
		if M.TypeKnown(t) then
			tinsert(items, { label = L("mod.chattabs.type." .. t.id), on = M.TypeOn(frame, t), fn = function(on) say(M.DoType(sel.id, t.id, on)) end })
		else
			merged = true
		end
	end
	checkCells(items, 3, 208, 12)
	if merged then Mn.Para(L("mod.chattabs.help.merged"), 30) end
	Mn.Section(L("mod.chattabs.sec.chans"), sel.name)
	local chans = M.JoinedChannels()
	if getn(chans) == 0 then
		Mn.Para(L("mod.chattabs.nochans"), 18)
	else
		Mn.Para(L("mod.chattabs.help.chans"), 30)
		items = {}
		for i = 1, getn(chans) do
			local name = chans[i]
			tinsert(items, { label = name, on = M.ChannelOn(frame, name), fn = function(on) say(M.DoChannel(sel.id, name, on)) end })
		end
		checkCells(items, 2, 318, 12)
	end
end

-- Ajoute la page du gestionnaire a la categorie "chattabs" (autour de la page standard : reglages en dessous).
function M.HookMenu()
	local Mn = SUI.Menu
	if not Mn or not Mn.Pages or M.hooked then return end
	M.hooked = true
	menuKind("ct_chk", newCheckRow)
	menuKind("ct_edit", newEditRow)
	local orig = Mn.Pages.cat
	Mn.Pages.cat = function()
		if Mn.cat == "chattabs" then M.Page() end
		orig()
	end
	for i = 1, getn(Mn.FAMILIES) do
		local fam = Mn.FAMILIES[i]
		if fam.id == "interface" then
			local have = false
			for j = 1, getn(fam.cats) do
				if fam.cats[j] == "chattabs" then have = true end
			end
			if not have then tinsert(fam.cats, "chattabs") end
		end
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	if key == "chattabs.dedicated" and value and M.on and M.restored then M.FlushDedicated(true) end
	if M.on and SUI.Chat then
		if C.Get("chattabs.menu") then SUI.Chat.tabMenu = M.TabMenu else SUI.Chat.tabMenu = nil end
	end
end

function M.Enable()
	M.on = true
	M.WrapClose()
	SUI.WhenSafe(M.BuildPopup)
	if SUI.Chat then
		SUI.Chat.tabMenu = C.Get("chattabs.menu") and M.TabMenu or nil
		M.PushOrder()
	end
	SUI.On("PLAYER_ENTERING_WORLD", M.OnEnter)
	SUI.On("CHAT_MSG_CHANNEL_NOTICE", M.OnNotice)
	if not M.watching then
		M.watching = true
		C.Watch("chattabs.", M.OnKey)
	end
	M.OnEnter()
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnEnter)
	SUI.Off("CHAT_MSG_CHANNEL_NOTICE", M.OnNotice)
	SUI.Cancel(M.restoreTask)
	M.restoreTask = nil
	if SUI.Chat then
		SUI.Chat.tabMenu = nil
		if SUI.Chat.SetOrder then SUI.Chat.SetOrder(nil) end
	end
	M.PopClose()
end

-- ---------------------------------------------------------------- commande
-- Diagnostic : pour chaque fenetre, les groupes de messages et canaux REELLEMENT actifs cote client (frame.messageTypeList / channelList),
-- et si le client connait les groupes de la guilde (ChatTypeGroup).
local function state3(frame, t)
	if not frame or type(frame.messageTypeList) ~= "table" then return L("mod.chattabs.v.unk") end
	if M.TypeOn(frame, t) then return L("mod.chattabs.v.on") end
	return L("mod.chattabs.v.off")
end

function M.Dump()
	local out = {}
	local tg = getglobal("ChatTypeGroup")
	local function known(g)
		if type(tg) ~= "table" then return L("mod.chattabs.v.unk") end
		return tg[g] ~= nil and L("mod.chattabs.v.on") or L("mod.chattabs.v.off")
	end
	local list = M.Shown()
	for i = 1, getn(list) do
		local w = list[i]
		local frame = frameOf(w.id)
		local st = (frame and frame.isDocked) and L("mod.chattabs.state.docked") or L("mod.chattabs.state.floating")
		local line = L("msg.chattabs.dump.win", w.id, w.name, st)
		SUI.Print(line)
		tinsert(out, line)
		local gs = frame and type(frame.messageTypeList) == "table" and table.concat(frame.messageTypeList, ",") or ""
		if gs == "" then gs = L("mod.chattabs.dump.none") end
		local cs = frame and type(frame.channelList) == "table" and table.concat(frame.channelList, ",") or ""
		if cs == "" then cs = L("mod.chattabs.dump.none") end
		line = L("msg.chattabs.dump.groups", gs)
		SUI.Print(line)
		tinsert(out, line)
		line = L("msg.chattabs.dump.chans", cs)
		SUI.Print(line)
		tinsert(out, line)
		line = L("msg.chattabs.dump.guild", state3(frame, M.TYPE.guild), state3(frame, M.TYPE.officer))
		SUI.Print(line)
		tinsert(out, line)
	end
	local line = L("msg.chattabs.dump.api", known("GUILD"), known("OFFICER"))
	SUI.Print(line)
	tinsert(out, line)
	M.lastDump = out
	return out
end

local function windowArg(s)
	local n = tonumber(s)
	if n and n == math.floor(n) and n >= 1 and n <= numWin() then return n end
	return nil
end

function M.Command(rest)
	rest = rest or ""
	local _, _, word, arg = strfind(rest, "^(%S*)%s*(.-)%s*$")
	word = strlower(word or "")
	arg = arg or ""
	if word == "" or word == "menu" then
		M.OpenManager()
	elseif word == "list" then
		local ord = M.Ordered()
		for i = 1, getn(ord) do SUI.Print(L("msg.chattabs.line", ord[i].id, ord[i].name)) end
	elseif word == "new" then
		local _, _, name, preset = strfind(arg, "^(.-)%s*(%S*)$")
		if preset ~= "" and not M.PRESET[strlower(preset)] then
			name = arg
			preset = nil
		end
		local id, key = M.Create(name, preset and preset ~= "" and strlower(preset) or nil)
		if id then SUI.Print(L("msg.chattabs.created", id)) else say(false, key) end
	elseif word == "rename" then
		local _, _, n, name = strfind(arg, "^(%S+)%s+(.+)$")
		local id = windowArg(n)
		if not id then SUI.Print(L("msg.chattabs.usage")) else say(M.Rename(id, name)) end
	elseif word == "close" then
		local id = M.FindWindow(arg)
		if not id then SUI.Print(L("msg.chattabs.usage")) else say(M.Close(id)) end
	elseif word == "check" then
		M.CheckState()
	elseif word == "dedupe" then
		local dok, n = M.Dedupe()
		if say(dok, n) then SUI.Print(L("msg.chattabs.deduped", n)) end
	elseif word == "forget" then
		if strlower(arg) == "all" or strlower(arg) == "tout" then
			M.ForgetSaved("all")
			SUI.Print(L("msg.chattabs.forgot"))
		else
			local id = windowArg(arg)
			if not id then SUI.Print(L("msg.chattabs.usage")) elseif M.ForgetSaved(id) then SUI.Print(L("msg.chattabs.forgot1", id)) else SUI.Print(L("msg.chattabs.forgot0", id)) end
		end
	elseif word == "preset" then
		local _, _, n, pid = strfind(arg, "^(%S+)%s+(%S+)$")
		local id = windowArg(n)
		if not id or not pid or not M.PRESET[strlower(pid)] then
			SUI.Print(L("msg.chattabs.usage"))
		elseif say(M.DoPreset(id, strlower(pid))) then
			SUI.Print(L("msg.chattabs.applied", id, strlower(pid)))
		end
	elseif word == "detach" or word == "attach" then
		local id = windowArg(arg)
		if not id then
			SUI.Print(L("msg.chattabs.usage"))
		else
			local fn = M.Detach
			local okm = "msg.chattabs.detached"
			if word == "attach" then
				fn = M.Attach
				okm = "msg.chattabs.attached"
			end
			if say(fn(id)) then SUI.Print(L(okm, id)) end
		end
	elseif word == "setup" then
		local ids, pos = {}, 1
		while true do
			local a, b, wd = strfind(arg, "(%S+)", pos)
			if not a then break end
			pos = b + 1
			wd = strlower(wd)
			if wd == "all" or wd == "tout" then
				ids = {}
				for i = 1, getn(M.USUAL) do tinsert(ids, M.USUAL[i].id) end
				break
			end
			wd = M.ALIAS[wd] or wd
			if M.USUAL_ID[wd] then tinsert(ids, wd) end
		end
		if getn(ids) == 0 then ids = nil end
		M.SetupReport(M.Setup(ids))
	elseif word == "tidy" then
		local ok, n = M.Tidy()
		if say(ok, n) then SUI.Print(L("msg.chattabs.tidied", n)) end
	elseif word == "state" then
		local st = M.RawState("commande")
		for i = 1, getn(st) do SUI.Print(st[i]) end
	elseif word == "dump" then
		M.Dump()
	elseif word == "save" then
		if say(M.CanAct()) and M.Save() then SUI.Print(L("msg.chattabs.saved")) end
	elseif word == "restore" then
		local ok, a = M.Restore()
		if ok then SUI.Print(L("msg.chattabs.restored", a)) else say(ok, a) end
	elseif word == "reset" then
		if say(M.Reset()) then SUI.Print(L("msg.chattabs.reset")) end
	elseif word == "chan" then
		local _, _, chan, tab = strfind(arg, "^(%S+)%s*(.-)$")
		if not chan then
			SUI.Print(L("msg.chattabs.usage"))
		elseif strlower(tab) == "off" then
			if say(M.Undedicate(chan)) then SUI.Print(L("msg.chattabs.dedicoff", M.BaseName(chan))) end
		else
			if tab == "" then tab = chan end
			local ok, ch = M.Dedicate(chan, tab)
			if say(ok, ch) then SUI.Print(L("msg.chattabs.dedic", M.BaseName(chan), M.BaseName(tab))) end
		end
	else
		SUI.Print(L("msg.chattabs.usage"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("chattabs", 49)

SUI.RegisterModule("chattabs", {
	default = true,
	cost = "light",
	options = {
		{ key = "chattabs.menu", type = "bool", cat = "chattabs", label = "opt.chattabs.menu", tip = "tip.chattabs.menu", default = true,
			simple = true, order = 10 },
		{ key = "chattabs.restore", type = "bool", cat = "chattabs", label = "opt.chattabs.restore", tip = "tip.chattabs.restore",
			default = true, simple = true, order = 20 },
		{ key = "chattabs.autosetup", type = "bool", cat = "chattabs", label = "opt.chattabs.autosetup", tip = "tip.chattabs.autosetup",
			default = false, simple = true, order = 15 },
		{ key = "chattabs.dedicated", type = "bool", cat = "chattabs", label = "opt.chattabs.dedicated", tip = "tip.chattabs.dedicated",
			default = true, simple = true, order = 25 },
		{ key = "chattabs.autosave", type = "bool", cat = "chattabs", label = "opt.chattabs.autosave", tip = "tip.chattabs.autosave",
			default = true, order = 30 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

M.HookMenu()

SUI.RegisterCommand("chattabs", function(rest) M.Command(rest or "") end, "help.chattabs")
