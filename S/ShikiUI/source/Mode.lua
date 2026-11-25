-- ShikiUI Mode : modes de jeu Normal / Raid (un "second profil" leger pour jouer en raid avec le moins d'addon possible).
-- Un mode n'est PAS un profil : c'est une couche par-dessus le profil actif (voir Config.lua : ecart utilisateur du mode > preset
-- role+classe > classe > role > generique > profil > defaut). Passer en Raid coupe les modules qui se declarent 'raid = "off"',
-- applique les presets livres (Cfg.AddPreset) et conserve les reglages que l'utilisateur change pendant qu'il est en Raid.
--
-- Bascule manuelle : /sui mode normal|raid|toggle, bouton de la fenetre. Bascule automatique (option, desactivee par defaut) :
-- entree en raid (instance de raid et / ou groupe de raid), retour au Normal un peu apres la sortie, UNIQUEMENT si c'est
-- l'automatique qui avait mis le mode Raid. Aucune bascule en combat (SUI.WhenSafe).
--
-- Liste d'addons externes a couper en raid : jamais appliquee toute seule. /sui mode addons affiche la liste ; "apply" prepare,
-- "confirm" execute DisableAddOn (apres confirmation explicite), puis /reload (ou "confirm reload" = ReloadUI) ; "restore" fait l'inverse.
--
-- APIs 1.12 utilisees, relevees dans des addons installes (jamais executees dans le jeu par ce projet) :
--   IsInInstance() -> inInstance, instanceType ("raid" | "party" | "pvp")        (LazyPig)
--   GetNumRaidMembers()                                                           (pfUI)
--   GetNumAddOns(), GetAddOnInfo(index) -> name, title, notes, DisableAddOn(nom), EnableAddOn(nom), ReloadUI()
--   evenements PLAYER_ENTERING_WORLD, RAID_ROSTER_UPDATE, PARTY_MEMBERS_CHANGED
-- NON VERIFIE en jeu : portee de DisableAddOn (personnage ou compte), valeurs de retour de GetAddOnInfo au-dela du nom, instanceType "arena".
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local Mode = {}
SUI.Mode = Mode

local getn, tinsert = table.getn, table.insert

Mode.autoSet = false       -- le mode courant a ete mis par l'automatique (donc l'automatique peut le defaire)
Mode.queued = nil          -- mode demande pendant un combat
Mode.leaveTask = nil
Mode.lastWanted = nil      -- derniere situation evaluee : l'automatique n'agit que quand elle CHANGE (un choix manuel tient jusque-la)
Mode.pending = nil         -- action sur les addons en attente de confirmation : { kind, names, at }
Mode.events = false

local CONFIRM_WINDOW = 30
local MAX_ADDONS = 40
local EVENTS = { "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED" }

-- ---------------------------------------------------------------- etat memorise (par personnage)
local function store()
	local db = C.db
	if not db then return nil end
	if type(db.modes) ~= "table" then db.modes = {} end
	return db.modes
end

local function save(mode, auto)
	local st = store()
	if not st then return end
	if mode == "normal" then
		st[C.CharKey()] = nil
	else
		st[C.CharKey()] = { m = mode, auto = auto and true or false }
	end
end

function Mode.Current()
	return C.mode
end

function Mode.Other()
	return C.mode == "normal" and "raid" or "normal"
end

function Mode.Name(mode)
	return L("mod.mode.name." .. tostring(mode))
end

-- ---------------------------------------------------------------- bascule
function Mode.Apply(mode, source)
	if not C.IsMode(mode) then return false end
	Mode.CancelLeave()
	Mode.queued = nil
	Mode.autoSet = (source == "auto" and mode ~= "normal")
	save(mode, Mode.autoSet)
	local changed = (C.mode ~= mode)
	C.SetMode(mode)
	if changed then
		C.Notify("mode", mode)
		SUI.Print(L("msg.mode.switched", Mode.Name(mode)))
		if mode == "raid" then Mode.Hint() end
		if SUI.Addons then SUI.Addons.OnMode(mode) end
	end
	return true
end

-- Retourne ok, cle de message. En combat la bascule attend la sortie de combat (derniere demande gagnante).
function Mode.Set(mode, source)
	if not C.IsMode(mode) then return false, "msg.mode.bad" end
	if SUI.InCombat() then
		Mode.queued = mode
		SUI.WhenSafe(function()
			if Mode.queued == mode then Mode.Apply(mode, source) end
		end)
		return true, "msg.mode.queued"
	end
	Mode.Apply(mode, source)
	return true, "msg.mode.switched"
end

function Mode.Toggle()
	return Mode.Set(Mode.Other(), "manual")
end

-- ---------------------------------------------------------------- bascule automatique
-- Retourne "raid" | "normal" selon le reglage mode.trigger, puis instance?, groupe?
function Mode.Wanted()
	local inInst, itype = IsInInstance()
	local byInst = (inInst and itype == "raid") and true or false
	local pvp = (itype == "pvp" or itype == "arena")
	local byGroup = (GetNumRaidMembers() > 0) and not pvp
	local trig = C.Get("mode.trigger")
	local want
	if trig == "instance" then
		want = byInst
	elseif trig == "group" then
		want = byGroup
	else
		want = byInst or byGroup
	end
	return want and "raid" or "normal", byInst, byGroup
end

function Mode.CancelLeave()
	if Mode.leaveTask then
		SUI.Cancel(Mode.leaveTask)
		Mode.leaveTask = nil
	end
end

local function leaveCheck()
	Mode.leaveTask = nil
	if C.mode == "raid" and Mode.autoSet and Mode.Wanted() == "normal" and C.Get("mode.auto") then
		Mode.Set("normal", "auto")
	end
end

function Mode.Evaluate(force)
	if not C.Get("mode.auto") then
		Mode.CancelLeave()
		return
	end
	local want = Mode.Wanted()
	if not force and want == Mode.lastWanted then return end
	Mode.lastWanted = want
	if want == "raid" then
		Mode.CancelLeave()
		if C.mode ~= "raid" and Mode.queued ~= "raid" then Mode.Set("raid", "auto") end
	elseif C.mode == "raid" and Mode.autoSet and not Mode.leaveTask and Mode.queued ~= "normal" then
		local d = C.Get("mode.delay")
		if d <= 0 then
			Mode.Set("normal", "auto")
		else
			Mode.leaveTask = SUI.After(d, leaveCheck, "mode.leave")
		end
	end
end

local function onEvent()
	Mode.Evaluate()
end

-- Les evenements ne sont ecoutes que si la bascule automatique est active (aucun cout sinon).
function Mode.SyncEvents()
	local want = C.Get("mode.auto") and true or false
	if want == Mode.events then return end
	Mode.events = want
	for i = 1, getn(EVENTS) do
		if want then SUI.On(EVENTS[i], onEvent) else SUI.Off(EVENTS[i], onEvent) end
	end
end

local function onKey(key, value)
	if key == nil or key == "mode.auto" or key == "mode.trigger" or key == "mode.delay" then
		Mode.SyncEvents()
		if C.Get("mode.auto") then Mode.Evaluate(key ~= nil) else Mode.CancelLeave() end
	end
end

-- A PLAYER_LOGIN, avant le demarrage des modules : relit le mode memorise, puis evalue l'automatique.
function Mode.Boot()
	local st = store()
	local rec = st and st[C.CharKey()]
	local m = "normal"
	Mode.autoSet = false
	if type(rec) == "table" and C.IsMode(rec.m) and rec.m ~= "normal" then
		m = rec.m
		Mode.autoSet = (rec.auto == true)
	end
	C.mode = m
	if not Mode.watching then
		Mode.watching = true
		C.Watch("mode.", onKey)
	end
	Mode.SyncEvents()
	Mode.lastWanted = nil
	if C.Get("mode.auto") then Mode.Evaluate(true) end
end

-- ---------------------------------------------------------------- liste des addons externes a couper en raid
local function listStore()
	local db = C.db
	if not db then return {} end
	local g = db.global
	if type(g.modeAddons) ~= "table" then g.modeAddons = {} end
	return g.modeAddons
end

local function doneStore()
	local db = C.db
	if not db then return {} end
	local g = db.global
	if type(g.modeDisabled) ~= "table" then g.modeDisabled = {} end
	return g.modeDisabled
end

local function validAddonName(name)
	if type(name) ~= "string" then return false end
	local len = string.len(name)
	if len < 1 or len > 48 then return false end
	if string.lower(name) == "shikiui" then return false end
	return string.find(name, "^[%w_%-%.]+$") ~= nil
end

function Mode.AddonList()
	local src = listStore()
	local t = {}
	for i = 1, getn(src) do
		if type(src[i]) == "string" and validAddonName(src[i]) then tinsert(t, src[i]) end
	end
	return t
end

-- Retourne ok, cle de message
function Mode.AddonAdd(name)
	if not validAddonName(name) then return false, "msg.mode.addon.bad" end
	local src = listStore()
	local low = string.lower(name)
	for i = 1, getn(src) do
		if string.lower(tostring(src[i])) == low then return false, "msg.mode.addon.exists" end
	end
	if getn(src) >= MAX_ADDONS then return false, "msg.mode.addon.full" end
	tinsert(src, name)
	return true, "msg.mode.addon.added"
end

function Mode.AddonRemove(name)
	local src = listStore()
	local low = string.lower(tostring(name))
	for i = getn(src), 1, -1 do
		if string.lower(tostring(src[i])) == low then
			table.remove(src, i)
			return true, "msg.mode.addon.removed"
		end
	end
	return false, "msg.mode.addon.unknown"
end

-- Addons installes : minuscule -> nom exact ; nil si l'API n'existe pas.
function Mode.Installed()
	if not GetNumAddOns or not GetAddOnInfo then return nil end
	local t = {}
	local ok, n = pcall(GetNumAddOns)
	if not ok or type(n) ~= "number" then return nil end
	for i = 1, n do
		local ok2, name = pcall(GetAddOnInfo, i)
		if ok2 and type(name) == "string" then t[string.lower(name)] = name end
	end
	return t
end

local function isLoaded(name)
	if not IsAddOnLoaded then return false end
	local ok, v = pcall(IsAddOnLoaded, name)
	return ok and v and true or false
end

-- Lignes d'etat de la liste : { name, installed (true|false|nil), loaded, byUs }
function Mode.AddonStates()
	local inst = Mode.Installed()
	local done = doneStore()
	local out = {}
	local list = Mode.AddonList()
	for i = 1, getn(list) do
		local real = inst and inst[string.lower(list[i])]
		local installed = nil
		if inst then installed = (real ~= nil) end
		tinsert(out, { name = real or list[i], installed = installed, loaded = real and isLoaded(real) or false,
			byUs = done[real or list[i]] == true })
	end
	return out
end

-- Message discret a l'entree en Raid : combien d'addons de la liste tournent encore.
function Mode.Hint()
	local n = 0
	local st = Mode.AddonStates()
	for i = 1, getn(st) do
		if st[i].loaded and not st[i].byUs then n = n + 1 end
	end
	if n > 0 then SUI.Print(L("msg.mode.addon.hint", n)) end
	return n
end

-- Prepare une action ("disable" | "restore") : rien n'est touche avant Mode.Confirm. Retourne les noms concernes.
function Mode.Prepare(kind)
	local names = {}
	local st = Mode.AddonStates()
	local done = doneStore()
	for i = 1, getn(st) do
		local s = st[i]
		if kind == "disable" then
			if s.installed and not s.byUs then tinsert(names, s.name) end
		else
			if done[s.name] then tinsert(names, s.name) end
		end
	end
	if kind == "restore" then
		-- noms coupes par nous puis retires de la liste : on les restaure aussi
		for name, _ in pairs(done) do
			local seen = false
			for i = 1, getn(names) do
				if names[i] == name then seen = true end
			end
			if not seen then tinsert(names, name) end
		end
	end
	table.sort(names)
	if getn(names) == 0 then
		Mode.pending = nil
		return names
	end
	Mode.pending = { kind = kind, names = names, at = GetTime() }
	return names
end

function Mode.Cancel()
	Mode.pending = nil
end

-- Execute l'action preparee si elle est recente. Retourne ok, cle de message, nombre. ReloadUI seulement si reload == true.
function Mode.Confirm(reload)
	local p = Mode.pending
	if not p then return false, "msg.mode.addon.nopending", 0 end
	if GetTime() - p.at > CONFIRM_WINDOW then
		Mode.pending = nil
		return false, "msg.mode.addon.expired", 0
	end
	Mode.pending = nil
	local done = doneStore()
	local n = 0
	for i = 1, getn(p.names) do
		local name = p.names[i]
		if p.kind == "disable" then
			if DisableAddOn then
				local ok = pcall(DisableAddOn, name)
				if ok then
					done[name] = true
					n = n + 1
				end
			end
		else
			if EnableAddOn then
				local ok = pcall(EnableAddOn, name)
				if ok then
					done[name] = nil
					n = n + 1
				end
			end
		end
	end
	if reload and ReloadUI and n > 0 then ReloadUI() end
	return true, p.kind == "disable" and "msg.mode.addon.disabled" or "msg.mode.addon.restored", n
end

-- ---------------------------------------------------------------- resume pour /sui status et le menu
function Mode.StatusLine()
	local how = C.Get("mode.auto") and L("mod.mode.auto") or L("mod.mode.manual")
	return L("msg.mode.status", Mode.Name(C.mode), how)
end

-- Etat des modules dans chaque mode, sans changer de mode : { name, cost, normal = bool, raid = bool }
function Mode.ModuleTable()
	local t = {}
	for i = 1, getn(SUI.moduleOrder) do
		local name = SUI.moduleOrder[i]
		local m = SUI.modules[name]
		tinsert(t, { name = name, cost = m.cost, normal = C.GetIn("normal", "modules." .. name), raid = C.GetIn("raid", "modules." .. name) })
	end
	return t
end

-- ---------------------------------------------------------------- commande /sui mode
local function out(msg)
	SUI.Print(msg)
end

local function firstWord(s)
	local _, _, w, rest = string.find(s or "", "^%s*(%S+)%s*(.*)$")
	if not w then return "", "" end
	return string.lower(w), rest or ""
end

local function addonsCmd(rest)
	local sub, arg = firstWord(rest)
	if sub == "add" then
		local ok, key = Mode.AddonAdd(arg)
		out(L(key, arg))
	elseif sub == "remove" then
		local ok, key = Mode.AddonRemove(arg)
		out(L(key, arg))
	elseif sub == "apply" or sub == "restore" then
		local names = Mode.Prepare(sub == "apply" and "disable" or "restore")
		if getn(names) == 0 then
			out(L("msg.mode.addon.nothing"))
		else
			out(L(sub == "apply" and "msg.mode.addon.askdisable" or "msg.mode.addon.askrestore", table.concat(names, ", ")))
		end
	elseif sub == "confirm" then
		local reload = (string.lower(arg) == "reload")
		local ok, key, n = Mode.Confirm(reload)
		if ok then out(L(key, n) .. (reload and "" or " " .. L("msg.mode.addon.needreload"))) else out(L(key)) end
	elseif sub == "cancel" then
		Mode.Cancel()
		out(L("msg.mode.addon.cancelled"))
	else
		local st = Mode.AddonStates()
		if getn(st) == 0 then
			out(L("msg.mode.addon.empty"))
		else
			for i = 1, getn(st) do
				local s = st[i]
				local state
				if s.installed == false then state = L("mod.mode.addon.absent")
				elseif s.byUs then state = L("mod.mode.addon.off")
				elseif s.loaded then state = L("mod.mode.addon.on")
				else state = "?" end
				out(L("msg.mode.addon.line", s.name, state))
			end
		end
		out(L("help.mode.addons"))
	end
end

function Mode.Command(rest)
	local sub, arg = firstWord(rest)
	if sub == "" then
		out(Mode.StatusLine())
		out(L("help.mode"))
	elseif sub == "normal" or sub == "raid" or sub == "toggle" then
		local target = (sub == "toggle") and Mode.Other() or sub
		if C.mode == target and Mode.queued == nil then
			out(L("msg.mode.already", Mode.Name(target)))
		else
			local ok, key = Mode.Set(target, "manual")
			if key == "msg.mode.queued" then out(L(key, Mode.Name(target))) end
		end
	elseif sub == "auto" then
		local v = (string.lower(arg) == "on") or (arg == "" and not C.Get("mode.auto"))
		C.Set("mode.auto", v)
		out(L(v and "msg.mode.auto.on" or "msg.mode.auto.off"))
	elseif sub == "reset" then
		local m = (arg ~= "") and string.lower(arg) or C.mode
		if C.ResetMode(m) then out(L("msg.mode.reset", Mode.Name(m))) else out(L("msg.mode.bad", m)) end
	elseif sub == "info" then
		local tbl = Mode.ModuleTable()
		for i = 1, getn(tbl) do
			local r = tbl[i]
			out(L("msg.mode.info", r.name, L("mod.mode.cost." .. r.cost), r.normal and "on" or "off", r.raid and "on" or "off"))
		end
	elseif sub == "addons" then
		addonsCmd(arg)
	else
		out(L("help.mode"))
	end
end

-- ---------------------------------------------------------------- reglages et commande
SUI.RegisterCategory("mode", 4)
SUI.RegisterOption({ key = "mode.auto", type = "bool", cat = "mode", label = "opt.mode.auto", tip = "tip.mode.auto",
	default = false, global = true, simple = true, order = 10 })
SUI.RegisterOption({ key = "mode.trigger", type = "choice", cat = "mode", label = "opt.mode.trigger", tip = "tip.mode.trigger",
	choices = { "instance", "group", "both" }, default = "both", global = true, order = 20 })
SUI.RegisterOption({ key = "mode.delay", type = "number", cat = "mode", label = "opt.mode.delay", tip = "tip.mode.delay",
	min = 0, max = 120, step = 5, default = 10, global = true, order = 30 })

-- Reglages livres pour le mode Raid (ce sont des choix d'interface, modifiables : un ecart de l'utilisateur gagne toujours).
C.AddPreset("raid", "*", { ["units.smooth"] = false })

SUI.RegisterCommand("mode", Mode.Command, "help.mode")
