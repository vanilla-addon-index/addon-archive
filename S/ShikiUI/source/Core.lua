-- ShikiUI Core : espace de noms, routeur d'evenements, minuterie partagee, modules.
-- WoW 1.12 / Lua 5.0 : pas de '#', pas de '%', pas de '...', pas de string.match / select.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
SUI.VERSION = "1.2.9"
SUI.rateMul = 1            -- 1 normal, 2 en mode urgence (les minuteries 'scalable' ralentissent)
SUI.emergency = false
SUI.debug = false
SUI.profile = false        -- mesure du temps par minuterie (indicatif, voir SPEC)
SUI.errCount = 0
SUI.lastErr = nil
SUI.handlers = {}
SUI.evCount = {}
SUI.tasks = {}
SUI.modules = {}
SUI.moduleOrder = {}
SUI.afterCombat = {}
SUI.commands = {}          -- commandes /sui ajoutees par les modules : nom -> { fn, help }
SUI.commandOrder = {}

local getn, tinsert, tremove = table.getn, table.insert, table.remove

function SUI.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff4dc4e8ShikiUI|r " .. tostring(msg))
end

-- Journal d'erreurs persistant : SUI.errlog (anneau de ERRMAX entrees) est range dans les variables sauvegardees
-- (ShikiUIDB.global.errlog) pour pouvoir relire les erreurs apres /reload ou une deconnexion. Entree : "temps|source|message".
local ERRMAX = 40
SUI.errlog = {}

function SUI.LogError(source, msg)
	local log = SUI.errlog
	local now = (time and time()) or 0
	local line = tostring(now) .. "|" .. tostring(source) .. "|" .. string.sub(tostring(msg), 1, 600)
	if log[getn(log)] == line then return end
	-- dedoublonnage : meme source + meme message a moins de 5 s d'ecart = spam (diagnostic repete),
	-- on remplace la derniere entree au lieu d'en empiler une nouvelle
	local last = log[getn(log)]
	if last then
		local _, _, lt, lsrc, lmsg = string.find(last, "^(%d+)|([^|]+)|(.*)$")
		if lt and lsrc == tostring(source) and lmsg == string.sub(tostring(msg), 1, 600) and now - tonumber(lt) < 5 then
			log[getn(log)] = line
			return
		end
	end
	tinsert(log, line)
	while getn(log) > ERRMAX do tremove(log, 1) end
	local C = SUI.Config
	if C and C.db and C.db.global then C.db.global.errlog = log end
end

-- Au login : reprend le journal de la session precedente (les entrees recentes passent apres).
function SUI.AttachErrorLog()
	local C = SUI.Config
	if not (C and C.db and C.db.global) then return end
	local old = C.db.global.errlog
	if type(old) == "table" and old ~= SUI.errlog then
		local merged = {}
		for i = 1, getn(old) do if type(old[i]) == "string" then tinsert(merged, old[i]) end end
		for i = 1, getn(SUI.errlog) do tinsert(merged, SUI.errlog[i]) end
		while getn(merged) > ERRMAX do tremove(merged, 1) end
		SUI.errlog = merged
	end
	C.db.global.errlog = SUI.errlog
end

-- Journal des changements de reglages (30 derniers) : ce que le menu a reellement ecrit, ou refuse. Lisible dans ShikiUIDB.global.optlog.
SUI.optlog = {}
function SUI.LogOpt(line)
	local log = SUI.optlog
	tinsert(log, tostring((time and time()) or 0) .. " " .. string.sub(tostring(line), 1, 160))
	while getn(log) > 30 do tremove(log, 1) end
	local C = SUI.Config
	if C and C.db and C.db.global then C.db.global.optlog = log end
end

function SUI.Report(where, err)
	SUI.errCount = SUI.errCount + 1
	SUI.lastErr = tostring(where) .. " : " .. tostring(err)
	SUI.LogError(where, err)
	if SUI.debug then
		SUI.Print("|cffff5555erreur|r " .. SUI.lastErr)
	end
end

-- Erreurs Lua non interceptees (scripts de cadres : OnClick, OnUpdate...) : le client appelle _ERRORMESSAGE. On garde celles qui
-- viennent de ShikiUI (le chemin du fichier est dans le message) et on rend la main au gestionnaire d'origine.
local prevErrHandler = _ERRORMESSAGE
function _ERRORMESSAGE(msg)
	local m = tostring(msg)
	if string.find(m, "ShikiUI", 1, true) then
		SUI.errCount = SUI.errCount + 1
		SUI.lastErr = "script : " .. m
		SUI.LogError("script", m)
	end
	if prevErrHandler then return prevErrHandler(msg) end
end

function SUI.Mod(a, m)
	return a - math.floor(a / m) * m
end

function SUI.Round(n, d)
	local k = 10 ^ (d or 0)
	return math.floor(n * k + 0.5) / k
end

function SUI.InCombat()
	return UnitAffectingCombat("player") and true or false
end

-- Execute fn tout de suite hors combat, sinon des la sortie de combat.
function SUI.WhenSafe(fn)
	if SUI.InCombat() then
		tinsert(SUI.afterCombat, fn)
	else
		fn()
	end
end

-- ---------------------------------------------------------------- routeur d'evenements (une seule frame)
local evFrame = CreateFrame("Frame", "ShikiUI_Events", UIParent)
SUI.evFrame = evFrame

function SUI.On(event, fn)
	local h = SUI.handlers[event]
	if not h then
		h = {}
		SUI.handlers[event] = h
		evFrame:RegisterEvent(event)
	end
	for i = 1, getn(h) do
		if h[i] == fn then return end
	end
	tinsert(h, fn)
end

local dispatching = 0     -- > 0 pendant la distribution d'un evenement : Off() ne decale plus la liste
local purgeNeeded = false

local function removeFrom(event, h)
	for i = getn(h), 1, -1 do
		if not h[i] then tremove(h, i) end
	end
	if getn(h) == 0 and SUI.handlers[event] == h then
		SUI.handlers[event] = nil
		evFrame:UnregisterEvent(event)
	end
end

function SUI.Off(event, fn)
	local h = SUI.handlers[event]
	if not h then return end
	if dispatching > 0 then
		for i = 1, getn(h) do
			if h[i] == fn then h[i] = false end
		end
		purgeNeeded = true
		return
	end
	for i = getn(h), 1, -1 do
		if h[i] == fn then tremove(h, i) end
	end
	removeFrom(event, h)
end

local function dispatch()
	local h = SUI.handlers[event]
	if not h then return end
	SUI.evCount[event] = (SUI.evCount[event] or 0) + 1
	local ev, a1, a2, a3, a4 = event, arg1, arg2, arg3, arg4
	dispatching = dispatching + 1
	for i = 1, getn(h) do
		local fn = h[i]
		if fn then
			local ok, err = pcall(fn, ev, a1, a2, a3, a4)
			if not ok then SUI.Report("event " .. ev, err) end
		end
	end
	dispatching = dispatching - 1
	if dispatching == 0 and purgeNeeded then
		purgeNeeded = false
		for name, list in pairs(SUI.handlers) do removeFrom(name, list) end
	end
end
evFrame:SetScript("OnEvent", dispatch)

-- ---------------------------------------------------------------- minuterie partagee (un seul OnUpdate)
-- Sans parent : la carte du monde masque UIParent, et un OnUpdate sous un parent cache ne tourne plus (les epingles du Codex n etaient jamais posees).
local tickFrame = CreateFrame("Frame", "ShikiUI_Tick", nil)
SUI.tickFrame = tickFrame
local minNext = 1e9

local function addTask(t)
	tinsert(SUI.tasks, t)
	if t.nextAt < minNext then minNext = t.nextAt end
	return t
end

-- Appelle fn toutes les 'interval' secondes. scalable : l'intervalle double en mode urgence.
function SUI.Every(interval, fn, name, scalable)
	return addTask({ fn = fn, interval = interval, name = name or "?", scalable = scalable, calls = 0, total = 0,
		nextAt = GetTime() + interval })
end

function SUI.After(delay, fn, name)
	return addTask({ fn = fn, interval = delay, once = true, name = name or "after", calls = 0, total = 0,
		nextAt = GetTime() + delay })
end

function SUI.Cancel(t)
	if t then t.dead = true end
end

local function tick()
	local now = GetTime()
	if now < minNext then return end
	local tasks = SUI.tasks
	local newMin = 1e9
	local i = 1
	while i <= getn(tasks) do
		local t = tasks[i]
		if t.dead then
			tremove(tasks, i)
		else
			if now >= t.nextAt then
				local t0 = SUI.profile and GetTime() or nil
				local ok, err = pcall(t.fn)
				if not ok then SUI.Report("task " .. t.name, err) end
				t.calls = t.calls + 1
				if t0 then t.total = t.total + (GetTime() - t0) end
				if t.once then
					t.dead = true
				else
					t.nextAt = now + t.interval * (t.scalable and SUI.rateMul or 1)
				end
			end
			if t.dead then
				tremove(tasks, i)
			else
				if t.nextAt < newMin then newMin = t.nextAt end
				i = i + 1
			end
		end
	end
	minNext = newMin
end
tickFrame:SetScript("OnUpdate", tick)

-- Force un recalcul de l'echeance suivante (apres un changement de rateMul).
function SUI.Reschedule()
	local now = GetTime()
	minNext = 1e9
	for i = 1, getn(SUI.tasks) do
		local t = SUI.tasks[i]
		if not t.dead then
			local due = now + t.interval * (t.scalable and SUI.rateMul or 1)
			if due < t.nextAt then t.nextAt = due end
			if t.nextAt < minNext then minNext = t.nextAt end
		end
	end
end

-- ---------------------------------------------------------------- commandes ajoutees par les modules
-- SUI.RegisterCommand("nom", function(reste) ... end, "help.nom") : /sui nom <reste>. Le nom (minuscules, sans espace) ne peut pas
-- etre un mot reserve ni deja pris ; helpKey (facultative) est la cle de traduction de la ligne ajoutee a /sui help.
SUI.reservedCommands = { simple = true, expert = true, wizard = true, status = true, perf = true, emergency = true, lock = true,
	unlock = true, profile = true, role = true, export = true, import = true, lang = true, migrate = true, debug = true,
	help = true }

function SUI.RegisterCommand(name, fn, helpKey)
	if type(name) ~= "string" or not string.find(name, "^[a-z][a-z0-9]*$") or type(fn) ~= "function" then return false, "bad" end
	if SUI.reservedCommands[name] or SUI.commands[name] then return false, "taken" end
	SUI.commands[name] = { fn = fn, help = helpKey }
	tinsert(SUI.commandOrder, name)
	return true
end

-- ---------------------------------------------------------------- modules (charges a la demande)
-- def : { default = true|false, cost = "light"|"medium"|"heavy" (poids a l'execution, obligatoire), raid = "off" (coupe en mode Raid),
--         options = { ... }, init, enable, disable, shutdown, core = true (modules du socle seulement) }
-- Un nom de module est en minuscules ([a-z][a-z0-9]*), unique, et ne reprend pas une famille de textes (msg, opt, tip...).
SUI.COSTS = { light = true, medium = true, heavy = true }
SUI.reservedModules = { ui = true, modules = true, mode = true, target = true, msg = true, help = true, menu = true,
	transfer = true, wiz = true, cat = true, role = true, unit = true, perf = true, status = true, opt = true, tip = true,
	choice = true, profile = true, mod = true, hdr = true, style = true, layout = true }

function SUI.RegisterModule(name, def)
	if type(name) ~= "string" or not string.find(name, "^[a-z][a-z0-9]*$") or type(def) ~= "table" then
		SUI.Report("module", "nom de module invalide : " .. tostring(name))
		return false
	end
	if SUI.modules[name] then
		SUI.Report("module", "module deja enregistre : " .. name)
		return false
	end
	if SUI.reservedModules[name] and not def.core then
		SUI.Report("module", "nom de module reserve : " .. name)
		return false
	end
	if not SUI.COSTS[def.cost] then
		SUI.Report("module", "cost manquant ou invalide : " .. name)
		def.costMissing = true
		def.cost = "medium"
	end
	def.name = name
	SUI.modules[name] = def
	tinsert(SUI.moduleOrder, name)
	SUI.RegisterOption({ key = "modules." .. name, type = "bool", cat = "modules", label = "opt.modules." .. name,
		tip = "tip.modules." .. name, default = (def.default ~= false), order = getn(SUI.moduleOrder) })
	if def.options then
		for i = 1, getn(def.options) do
			SUI.RegisterOption(def.options[i])
		end
	end
	if SUI.Config.db then SUI.Config.RebuildPresets() end
	return true
end

function SUI.EnableModule(name)
	local m = SUI.modules[name]
	if not m then return false end
	if not m.inited then
		m.inited = true
		if m.init then
			local ok, err = pcall(m.init, m)
			if not ok then SUI.Report("init " .. name, err) end
		end
	end
	if not m.enabled then
		m.enabled = true
		if m.enable then
			local ok, err = pcall(m.enable, m)
			if not ok then SUI.Report("enable " .. name, err) end
		end
	end
	return true
end

function SUI.DisableModule(name)
	local m = SUI.modules[name]
	if not m or not m.enabled then return false end
	m.enabled = false
	if m.disable then
		local ok, err = pcall(m.disable, m)
		if not ok then SUI.Report("disable " .. name, err) end
	end
	return true
end

-- Un module voulu par l'utilisateur ne demarre pas tant que pfUI fait tourner son equivalent (voir Migrate.lua).
function SUI.ModuleWanted(name)
	if not SUI.Config.Get("modules." .. name) then return false end
	if SUI.Migrate and SUI.Migrate.Held(name) then return false end
	return true
end

local function onModuleKey(key, value)
	if not key then
		-- changement de profil / reinitialisation / import : on realigne tous les modules
		for i = 1, getn(SUI.moduleOrder) do
			local n = SUI.moduleOrder[i]
			if SUI.ModuleWanted(n) then SUI.EnableModule(n) else SUI.DisableModule(n) end
		end
		return
	end
	local name = string.sub(key, 9)
	if not SUI.modules[name] then return end
	if value and SUI.ModuleWanted(name) then SUI.EnableModule(name) else SUI.DisableModule(name) end
end

-- ---------------------------------------------------------------- demarrage
local function onAddonLoaded(ev, a1)
	if a1 ~= "ShikiUI" then return end
	SUI.Config.Init()
	if SUI.Style then SUI.Style.LoadUser() end
	SUI.Off("ADDON_LOADED", onAddonLoaded)
end

local function onLogin()
	SUI.Config.SelectProfile()
	SUI.AttachErrorLog()
	SUI.SetLocale(SUI.Config.Get("ui.locale"))
	SUI.Api.Detect()
	if SUI.Migrate then SUI.Migrate.Boot() end
	if SUI.Mode then SUI.Mode.Boot() end
	if SUI.Style then SUI.Style.Boot() end
	SUI.Config.Watch("modules.", onModuleKey)
	for i = 1, getn(SUI.moduleOrder) do
		local name = SUI.moduleOrder[i]
		if SUI.ModuleWanted(name) then SUI.EnableModule(name) end
	end
	SUI.Print(SUI.L("msg.loaded", SUI.VERSION))
	if SUI.Config.GetGlobal("firstRun") then
		-- premiere installation : la mise en page "Shiki : classique" est appliquee d office (l assistant peut en choisir une autre)
		SUI.After(1.5, function()
			if not SUI.noAutoPreset and SUI.Layout and SUI.Layout.ApplyPreset and not (SUI.Config.cur and SUI.Config.cur.layout) then
				pcall(SUI.Layout.ApplyPreset, "shiki")
				if SUI.ApplyStarter then pcall(SUI.ApplyStarter) end
			end
			SUI.Menu.ShowWizard()
		end, "wizard")
	end
end

local function onWorld()
	SUI.Api.OnWorld()
end

local function onRegen(ev)
	if ev == "PLAYER_REGEN_ENABLED" then
		local q = SUI.afterCombat
		SUI.afterCombat = {}
		for i = 1, getn(q) do
			local ok, err = pcall(q[i])
			if not ok then SUI.Report("aftercombat", err) end
		end
	end
end

-- Au PLAYER_LOGOUT on detache tout : certains clients plantent a la fermeture sinon (observe par d'autres addons, cause non verifiee).
local function onLogout()
	SUI.shutdown = true
	for i = 1, getn(SUI.moduleOrder) do
		local m = SUI.modules[SUI.moduleOrder[i]]
		if m and m.shutdown then pcall(m.shutdown, m) end
	end
	evFrame:UnregisterAllEvents()
	evFrame:SetScript("OnEvent", nil)
	tickFrame:SetScript("OnUpdate", nil)
end

SUI.On("ADDON_LOADED", onAddonLoaded)
SUI.On("PLAYER_LOGIN", onLogin)
SUI.On("PLAYER_ENTERING_WORLD", onWorld)
SUI.On("PLAYER_REGEN_ENABLED", onRegen)
SUI.On("PLAYER_LOGOUT", onLogout)
