-- ShikiUI Cmd : commandes /sui et /shikiui.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local C = SUI.Config

local getn = table.getn

local function out(msg)
	SUI.Print(msg)
end

-- Premier mot (en minuscules sauf keepCase) et le reste de la ligne.
local function split(s, keepCase)
	local _, _, w, rest = string.find(s or "", "^%s*(%S+)%s*(.*)$")
	if not w then return "", "" end
	if not keepCase then w = string.lower(w) end
	return w, rest or ""
end

-- 12 lignes du socle, puis une ligne par commande de module qui en declare une (SUI.RegisterCommand).
local function help()
	for i = 1, 12 do out(L("help." .. i)) end
	for i = 1, getn(SUI.commandOrder) do
		local c = SUI.commands[SUI.commandOrder[i]]
		if c and c.help then out(L(c.help)) end
	end
end

local function migrateCmd(rest)
	local Mg = SUI.Migrate
	local sub, arg = split(rest)
	if sub == "" or sub == "status" then
		local lines = Mg.Report()
		for i = 1, getn(lines) do out(lines[i]) end
		return
	end
	local fn
	if sub == "take" then fn = Mg.Take
	elseif sub == "back" then fn = Mg.Back
	elseif sub == "both" then fn = Mg.Both
	elseif sub == "hold" then fn = Mg.Hold
	end
	if not fn then
		out(L("migrate.usage"))
		return
	end
	local ok, key, names = fn(arg)
	if not ok then
		out(L(key, Mg.Names()))
	else
		out(L(key, names))
	end
end

local function status()
	local api = SUI.Api
	out(L("status.version", SUI.VERSION))
	out(L("menu.ext", api.Summary() or L("menu.none")))
	local ints = api.Integrations()
	out(L("menu.integ", getn(ints) > 0 and table.concat(ints, ", ") or L("menu.none")))
	out(L("status.profile", C.curName, C.GetRole() or "-", SUI.locale))
	local mods = {}
	for i = 1, getn(SUI.moduleOrder) do
		local m = SUI.modules[SUI.moduleOrder[i]]
		local held = SUI.Migrate and SUI.Migrate.Held(SUI.moduleOrder[i])
		table.insert(mods, SUI.moduleOrder[i] .. "=" .. (m.enabled and "on" or (held and "wait" or "off")))
	end
	out(L("status.modules", table.concat(mods, " ")))
	out(L("status.api", api.unitxp and "oui" or "non", api.sightSafe and "oui" or "non"))
end

local function profileCmd(rest)
	local sub, arg = split(rest)
	if sub == "" or sub == "list" then
		out(L("profile.list", table.concat(C.ListProfiles(), ", "), C.curName))
	elseif sub == "use" then
		local ok, key = C.UseProfile(arg)
		out(L(key, arg))
	elseif sub == "new" then
		local name, from = split(arg, true)
		local ok, key
		if from ~= "" then
			ok, key = C.NewProfile(name, from)
		else
			ok, key = C.NewProfile(name)
		end
		out(L(key, name))
	elseif sub == "delete" then
		local ok, key = C.DeleteProfile(arg)
		out(L(key, arg))
	elseif sub == "reset" then
		C.ResetProfile()
		out(L("msg.reset.done"))
	else
		out(L("help.7"))
	end
end

local function perfCmd(rest)
	local sub, arg = split(rest)
	if sub == "profile" then
		SUI.Perf.SetProfile(arg ~= "off")
		out(L(SUI.profile and "perf.profile.on" or "perf.profile.off"))
		return
	elseif sub == "reset" then
		SUI.Perf.SetProfile(SUI.profile)
		out(L("perf.reset"))
		return
	end
	local lines = SUI.Perf.Report()
	for i = 1, getn(lines) do out(lines[i]) end
end

local function handler(msg)
	local cmd, rest = split(msg)
	if cmd == "" then
		SUI.Menu.Toggle()
	elseif cmd == "simple" or cmd == "expert" then
		SUI.Menu.Show(cmd)
	elseif cmd == "wizard" then
		SUI.Menu.ShowWizard(1)
	elseif cmd == "status" then
		status()
	elseif cmd == "perf" then
		perfCmd(rest)
	elseif cmd == "emergency" then
		local sub = split(rest)
		SUI.Perf.SetEmergency(sub == "" and not SUI.emergency or sub == "on")
	elseif cmd == "lock" then
		if SUI.Mover.active then
			SUI.Mover.Exit(true)
		else
			C.Set("ui.locked", true)
			out(L("msg.lock.on"))
		end
	elseif cmd == "unlock" then
		SUI.Mover.Enter()
	elseif cmd == "profile" then
		profileCmd(rest)
	elseif cmd == "role" then
		local role = split(rest)
		if C.ApplyRole(role) then out(L("msg.role.applied", L("role." .. role))) else out(L("help.8")) end
	elseif cmd == "export" then
		SUI.Menu.ShowTransfer("export")
	elseif cmd == "import" then
		if rest ~= "" then SUI.Menu.DoImport(rest) else SUI.Menu.ShowTransfer("import") end
	elseif cmd == "lang" then
		local code = split(rest)
		if code == "fr" or code == "en" then
			C.Set("ui.locale", code)
			out(L("msg.lang", code))
		else
			out(L("help.9"))
		end
	elseif cmd == "migrate" then
		migrateCmd(rest)
	elseif cmd == "debug" then
		local sub = split(rest)
		SUI.debug = (sub == "" and not SUI.debug) or sub == "on"
		out(L(SUI.debug and "msg.debug.on" or "msg.debug.off"))
	elseif cmd == "help" then
		help()
	elseif SUI.commands[cmd] then
		local ok, err = pcall(SUI.commands[cmd].fn, rest)
		if not ok then SUI.Report("commande " .. cmd, err) end
	else
		out(L("msg.unknown.cmd"))
	end
end

SLASH_SHIKIUI1 = "/sui"
SLASH_SHIKIUI2 = "/shikiui"
SlashCmdList["SHIKIUI"] = handler
SUI.Command = handler

-- /sui errors [list | clear | test] : journal d'erreurs persistant (voir SUI.LogError dans Core.lua).
SUI.RegisterCommand("errors", function(rest)
	local sub = split(rest)
	local log = SUI.errlog
	if sub == "clear" then
		for i = getn(log), 1, -1 do table.remove(log, i) end
		out(L("errors.cleared"))
	elseif sub == "test" then
		SUI.Report("test", "erreur de test (/sui errors test)")
		out(L("errors.tested"))
	else
		out(L("errors.count", getn(log), SUI.errCount))
		local from = getn(log) - 9
		if from < 1 then from = 1 end
		for i = from, getn(log) do out(log[i]) end
	end
end, "help.errors")

-- /sui menudiag : diagnostic immediat du menu (options non cliquables) : empilement du menu et liste des cadres visibles, captant la souris,
-- plus hauts que lui (strate puis niveau). Resultat aussi range dans le journal (/sui errors).
local STRATA_RANK = { WORLD = 1, BACKGROUND = 2, LOW = 3, MEDIUM = 4, HIGH = 5, DIALOG = 6, FULLSCREEN = 7, FULLSCREEN_DIALOG = 8, TOOLTIP = 9 }
SUI.RegisterCommand("menudiag", function(rest)
	local mn = SUI.Menu
	local f = mn and mn.frame
	if not f then
		out("menudiag : menu non construit (ouvre /sui d abord)")
		return
	end
	local function rank(fr) return (STRATA_RANK[fr:GetFrameStrata()] or 0) * 100000 + fr:GetFrameLevel() end
	local function info(fr)
		return tostring(fr:GetName() or "?") .. "(" .. tostring(fr:GetFrameStrata()) .. " L" .. tostring(fr:GetFrameLevel()) .. ")"
	end
	local lines = {}
	table.insert(lines, "menu " .. info(f) .. " raised=" .. tostring(mn.raised) .. " lvl=" .. tostring(mn.lvl) .. " shown=" .. tostring(f:IsShown()))
	if mn.child then table.insert(lines, "contenu " .. info(mn.child) .. " page=" .. tostring(mn.page)) end
	local mv = SUI.Mover
	table.insert(lines, "mover actif=" .. tostring(mv and mv.active) .. " voile=" .. tostring(mv and mv.veil and mv.veil:IsShown()) .. " ctx=" .. tostring(mv and mv.ctxCatcher and mv.ctxCatcher:IsShown()))
	table.insert(lines, "catcher liste=" .. tostring(f.catcher and f.catcher:IsShown()) .. " liste=" .. tostring(f.drop and f.drop:IsShown()))
	local ref = rank(f)
	local kid = UIParent and { UIParent:GetChildren() } or {}
	local n = 0
	for i = 1, getn(kid) do
		local c = kid[i]
		if c ~= f and c.IsShown and c:IsShown() and c.IsMouseEnabled and c:IsMouseEnabled() and rank(c) > ref then
			local w, h = c:GetWidth() or 0, c:GetHeight() or 0
			if n < 8 then table.insert(lines, "AU-DESSUS : " .. info(c) .. " " .. math.floor(w) .. "x" .. math.floor(h)) end
			n = n + 1
		end
	end
	table.insert(lines, "cadres souris-actifs au-dessus du menu : " .. n)
	for i = 1, getn(lines) do
		out(lines[i])
		SUI.LogError("menudiag", lines[i])
	end
end, "help.menudiag")

-- /sui focus [secondes] : dans N secondes (4 par defaut), dit quel cadre est sous la souris (chaine de parents, strate, niveau).
-- Sert a trouver ce qui capte un clic. Le resultat est aussi range dans le journal (/sui errors).
SUI.RegisterCommand("focus", function(rest)
	local n = tonumber((split(rest))) or 4
	if n < 1 then n = 1 elseif n > 15 then n = 15 end
	out(L("focus.wait", n))
	SUI.After(n, function()
		local f = GetMouseFocus and GetMouseFocus()
		if not f then
			out(L("focus.none"))
			return
		end
		local parts, p, guard = {}, f, 0
		while p and guard < 6 do
			local nm = (p.GetName and p:GetName()) or "?"
			local ty = (p.GetObjectType and p:GetObjectType()) or "?"
			table.insert(parts, nm .. "(" .. ty .. " L" .. tostring(p.GetFrameLevel and p:GetFrameLevel() or "?") .. " " .. tostring(p.GetFrameStrata and p:GetFrameStrata() or "?") .. ")")
			p = p.GetParent and p:GetParent() or nil
			guard = guard + 1
		end
		local msg = table.concat(parts, " < ")
		out(L("focus.is", msg))
		SUI.LogError("focus", msg)
	end, "focus")
end, "help.focus")
