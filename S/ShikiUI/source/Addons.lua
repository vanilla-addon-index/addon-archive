-- ShikiUI Addons : gestionnaire d'addons (page "Addons" du menu, famille Outils) et ensembles lies aux modes Normal / Raid.
-- API 1.12 utilisee : GetNumAddOns, GetAddOnInfo(i) (nom, titre, notes, actif, chargeable), EnableAddOn, DisableAddOn, ReloadUI, IsAddOnLoaded.
-- NON VERIFIE EN JEU : que GetAddOnInfo renvoie bien le nouvel etat "actif" avant le rechargement (on garde donc l'etat de depart
-- A.base pour compter les changements en attente), et que UpdateAddOnMemoryUsage / GetAddOnMemoryUsage existent (compteur facultatif).
-- Rien ne tourne hors de la page : pas de minuterie, la memoire n'est lue qu'au rendu de la page.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu
local C = SUI.Config

local getn, tinsert = table.getn, table.insert
local A = {}
SUI.Addons = A

A.CRITICAL = { "nampower", "perfboost", "superwow", "unitxp" }   -- noms (minuscules) dont la coupure demande deux clics
A.CONFIRM = 6              -- secondes pendant lesquelles le 2e clic est accepte
A.MAXSET = 256
A.filter = "all"           -- all | on | off | mine
A.query = ""
A.base = {}                -- etat de depart de chaque addon (premier passage de la session)
A.armed = nil              -- { name, at } : coupure d'un addon critique en attente du 2e clic
A.index = {}

local CW = 648
local ROWH = 28

-- ---------------------------------------------------------------- lecture de la liste
function A.Available()
	return (getglobal("GetNumAddOns") and getglobal("GetAddOnInfo")) and true or false
end

local function clean(s, fallback)
	if type(s) ~= "string" or s == "" then return fallback end
	s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
	s = string.gsub(s, "|r", "")
	return s
end

local function byTitle(a, b)
	local x, y = string.lower(a.title), string.lower(b.title)
	if x ~= y then return x < y end
	return a.name < b.name
end

-- Liste triee : { name, title, notes, on, loadable, loaded }
function A.Scan()
	local list = {}
	A.index = {}
	if not A.Available() then return list end
	local ok, n = pcall(GetNumAddOns)
	if not ok or type(n) ~= "number" then return list end
	for i = 1, n do
		local ok2, name, title, notes, enabled, loadable = pcall(GetAddOnInfo, i)
		if ok2 and type(name) == "string" then
			local e = { name = name, title = clean(title, name), notes = clean(notes, ""), on = enabled and true or false,
				loadable = loadable and true or false, loaded = false }
			if IsAddOnLoaded then
				local ok3, v = pcall(IsAddOnLoaded, name)
				e.loaded = ok3 and v and true or false
			end
			if A.base[name] == nil then A.base[name] = e.on end
			A.index[name] = i
			tinsert(list, e)
		end
	end
	table.sort(list, byTitle)
	return list
end

function A.IsCritical(name)
	local low = string.lower(tostring(name))
	if low == "shikiui" then return true end
	for i = 1, getn(A.CRITICAL) do
		if string.find(low, A.CRITICAL[i], 1, true) then return true end
	end
	return false
end

function A.IsMine(name)
	return string.sub(string.lower(tostring(name)), 1, 5) == "shiki"
end

function A.Match(e)
	local f = A.filter
	if f == "on" and not e.on then return false end
	if f == "off" and e.on then return false end
	if f == "mine" and not A.IsMine(e.name) then return false end
	local q = A.query
	if q ~= "" then
		if not string.find(string.lower(e.name), q, 1, true) and not string.find(string.lower(e.title), q, 1, true) then return false end
	end
	return true
end

function A.SetFilter(f)
	if f ~= "all" and f ~= "on" and f ~= "off" and f ~= "mine" then return end
	A.filter = f
	if M.frame and M.page == "addons" then M.Render() end
end

function A.SetQuery(q)
	q = string.lower(q or "")
	if q == A.query then return end
	A.query = q
	if M.frame and M.page == "addons" then M.Render() end
end

-- Nombre d'addons dont l'etat differe de l'etat de depart de la session (donc rechargement necessaire).
function A.Changes(list)
	list = list or A.Scan()
	local n = 0
	for i = 1, getn(list) do
		local e = list[i]
		if A.base[e.name] ~= nil and A.base[e.name] ~= e.on then n = n + 1 end
	end
	return n
end

-- ---------------------------------------------------------------- actions
function A.Set(name, on)
	if on then
		if EnableAddOn then pcall(EnableAddOn, name) end
	else
		if DisableAddOn then pcall(DisableAddOn, name) end
	end
end

-- Bascule un addon dont l'etat actuel est cur. Retourne "armed" (coupure critique : 2e clic attendu) ou "done".
function A.Toggle(name, cur)
	if cur and A.IsCritical(name) then
		local now = GetTime()
		local a = A.armed
		if not (a and a.name == name and now - a.at <= A.CONFIRM) then
			A.armed = { name = name, at = now }
			SUI.Print(L("msg.addons.critical", name))
			return "armed"
		end
	end
	A.armed = nil
	A.Set(name, not cur)
	return "done"
end

function A.Reload()
	if SUI.InCombat() then
		SUI.Print(L("msg.addons.combat"))
		return false
	end
	if ReloadUI then ReloadUI() end
	return true
end

-- ---------------------------------------------------------------- ensembles lies aux modes (mm = "normal" | "raid")
local function setStore()
	local db = C.db
	if not db then return {} end
	local g = db.global
	if type(g.addonSets) ~= "table" then g.addonSets = {} end
	return g.addonSets
end

function A.ValidMode(mm)
	return C.IsMode and C.IsMode(mm) and true or false
end

-- Enregistre l'etat actuel (tous les addons) ; retourne le nombre d'addons memorises.
function A.SaveSet(mm)
	if not A.ValidMode(mm) then return nil end
	local list = A.Scan()
	local s = {}
	local n = 0
	for i = 1, getn(list) do
		if n < A.MAXSET then
			s[list[i].name] = list[i].on and 1 or 0
			n = n + 1
		end
	end
	setStore()[mm] = s
	return n
end

function A.SetSize(mm)
	local s = setStore()[mm]
	if type(s) ~= "table" then return nil end
	local n = 0
	for _, _ in pairs(s) do n = n + 1 end
	return n
end

-- Differences entre l'ensemble et l'etat actuel : liste de { name, want }. ShikiUI n'est jamais coupe par un ensemble.
function A.Diff(mm)
	local s = setStore()[mm]
	if type(s) ~= "table" then return nil end
	local res = {}
	local list = A.Scan()
	for i = 1, getn(list) do
		local e = list[i]
		local v = s[e.name]
		if v ~= nil then
			local want = (v == 1)
			if string.lower(e.name) == "shikiui" then want = true end
			if want ~= e.on then tinsert(res, { name = e.name, want = want }) end
		end
	end
	return res
end

-- Applique l'ensemble (sans recharger). Retourne le nombre de changements, ou nil s'il n'y a pas d'ensemble.
function A.ApplySet(mm)
	local d = A.Diff(mm)
	if not d then return nil end
	for i = 1, getn(d) do A.Set(d[i].name, d[i].want) end
	return getn(d)
end

-- Appele par Mode.Apply : rappelle discretement si l'ensemble du mode ne correspond pas aux addons actuels.
function A.OnMode(mm)
	local d = A.Diff(mm)
	if d and getn(d) > 0 then
		SUI.Print(L("msg.addons.diff", SUI.Mode.Name(mm), getn(d), mm))
	end
end

-- ---------------------------------------------------------------- memoire (facultative)
function A.MemAvailable()
	return (type(getglobal("GetAddOnMemoryUsage")) == "function" and type(getglobal("UpdateAddOnMemoryUsage")) == "function") and true or false
end

function A.MemRefresh()
	if A.MemAvailable() then pcall(getglobal("UpdateAddOnMemoryUsage")) end
end

function A.Mem(name)
	if not A.MemAvailable() then return nil end
	local ok, v = pcall(getglobal("GetAddOnMemoryUsage"), name)
	if ok and type(v) == "number" then return v end
	return nil
end

function A.MemText(kb)
	if kb >= 1024 then return L("mod.addons.mem.mb", string.format("%.1f", kb / 1024)) end
	return L("mod.addons.mem.kb", string.format("%d", kb))
end

-- ---------------------------------------------------------------- elements du menu
local NEW = M.New

local function wheel(f)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", M.OnWheel)
	return f
end

local function rowClick(r)
	local e = r.entry
	if not e then return end
	A.Toggle(e.name, e.on)
	M.Render()
end

function NEW.arow()
	local f = CreateFrame("Button", nil, M.child)
	f:SetFrameLevel(M.lvl + 1)
	T.Backdrop(f, T.c.panel, T.c.border)
	wheel(f)
	f:SetScript("OnClick", function() rowClick(this) end)
	f.chk = T.Check(f, function() rowClick(f) end)
	f.chk:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.name = T.Text(f, 11, T.c.text, "LEFT")
	f.name:SetPoint("LEFT", f, "LEFT", 34, 0)
	f.name:SetWidth(200)
	f.name:SetHeight(14)
	f.notes = T.Text(f, 10, T.c.dim, "LEFT")
	f.notes:SetPoint("LEFT", f, "LEFT", 240, 0)
	f.notes:SetWidth(240)
	f.notes:SetHeight(14)
	f.mem = T.Text(f, 10, T.c.dim, "RIGHT")
	f.mem:SetPoint("RIGHT", f, "RIGHT", -96, 0)
	f.mem:SetWidth(60)
	f.mem:SetHeight(14)
	f.tag = T.Text(f, 10, T.c.warn, "RIGHT")
	f.tag:SetPoint("RIGHT", f, "RIGHT", -8, 0)
	f.tag:SetWidth(84)
	f.tag:SetHeight(14)
	return f
end

function A.BindRow(r, e)
	r.entry = e
	T.SetCheck(r.chk, e.on)
	r.name:SetText(M.Short(e.title, 34))
	local col = e.on and T.c.text or T.c.dim
	if A.IsMine(e.name) and e.on then
		local ar, ag, ab = T.Accent()
		r.name:SetTextColor(ar, ag, ab, 1)
	else
		r.name:SetTextColor(col[1], col[2], col[3], 1)
	end
	r.notes:SetText(M.Short(e.notes, 44))
	local mem = e.on and A.Mem(e.name)
	r.mem:SetText(mem and A.MemText(mem) or "")
	local tag = ""
	local a = A.armed
	if a and a.name == e.name then
		tag = L("mod.addons.tag.confirm")
	elseif A.base[e.name] ~= nil and A.base[e.name] ~= e.on then
		tag = L("mod.addons.tag.reload")
	elseif e.on and not e.loadable then
		tag = L("mod.addons.tag.noload")
	end
	r.tag:SetText(tag)
end

local function onQuery()
	local f = this
	if f.silent then return end
	local q = f:GetText() or ""
	f.hint:SetText(q == "" and L("mod.addons.search") or "")
	A.SetQuery(q)
end

function NEW.aedit()
	local f = CreateFrame("Frame", nil, M.child)
	f:SetFrameLevel(M.lvl + 2)
	f.edit = T.Edit(f, CW, 22)
	f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.edit:SetMaxLetters(40)
	f.edit:SetScript("OnTextChanged", onQuery)
	f.edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
	f.edit:SetScript("OnEnterPressed", function() this:ClearFocus() end)
	f.hint = T.Text(f.edit, 11, T.c.dim, "LEFT")
	f.hint:SetPoint("LEFT", f.edit, "LEFT", 6, 0)
	f.edit.hint = f.hint
	return f
end

local function setLabel(key, mm)
	return L(key, SUI.Mode.Name(mm))
end

-- ---------------------------------------------------------------- la page
function M.Pages.addons()
	local list = A.Scan()
	local nchg = A.Changes(list)
	M.HeadBtn(nchg > 0 and L("mod.addons.btn.apply.n", nchg) or L("mod.addons.btn.apply"), 190, function() A.Reload() end, nchg > 0)
	M.SetHead(L("mod.menu.nav.addons"), L("mod.addons.desc"))
	if not A.Available() then
		M.Para(L("mod.addons.unavailable"), 30)
		return
	end
	-- recherche et filtres
	M.Section(L("mod.addons.sec.filters"), tostring(getn(list)))
	local ed = M.Get("aedit")
	if ed then
		M.Flow(ed, 1, CW, 22, 0, 8)
		ed.edit.silent = true
		if (ed.edit:GetText() or "") ~= A.query then ed.edit:SetText(A.query) end
		ed.edit.silent = false
		ed.hint:SetText(A.query == "" and L("mod.addons.search") or "")
		M.EndRow(8)
	end
	local ids = { "all", "on", "off", "mine" }
	for i = 1, 4 do
		local id = ids[i]
		M.GridBtn(L("mod.addons.f." .. id), 4, 153, 26, function() A.SetFilter(id) end, A.filter == id)
	end
	M.EndRow(8)
	M.Para(nchg > 0 and L("mod.addons.pending", nchg) or L("mod.addons.nopending"), 18, nchg > 0 and T.c.warn or T.c.dim)
	if A.MemAvailable() then
		A.MemRefresh()
		local total = 0
		for i = 1, getn(list) do total = total + (A.Mem(list[i].name) or 0) end
		M.Para(L("mod.addons.mem.total", A.MemText(total)), 18)
	else
		M.Para(L("mod.addons.mem.na"), 18)
	end
	-- ensembles
	M.Section(L("mod.addons.sec.sets"))
	local modes = { "normal", "raid" }
	for i = 1, 2 do
		local mm = modes[i]
		local n = A.SetSize(mm)
		M.Para(L("mod.addons.set.info", SUI.Mode.Name(mm), n and L("mod.addons.set.count", n) or L("mod.addons.set.none")), 16)
	end
	for i = 1, 2 do
		local mm = modes[i]
		M.GridBtn(setLabel("mod.addons.set.save", mm), 2, 318, 26, function()
			local n = A.SaveSet(mm)
			if n then SUI.Print(L("msg.addons.saved", SUI.Mode.Name(mm), n)) end
			M.Render()
		end)
	end
	M.EndRow(8)
	for i = 1, 2 do
		local mm = modes[i]
		M.GridBtn(setLabel("mod.addons.set.use", mm), 2, 318, 26, function()
			local n = A.ApplySet(mm)
			if n then SUI.Print(L("msg.addons.applied", SUI.Mode.Name(mm), n)) else SUI.Print(L("msg.addons.noset", SUI.Mode.Name(mm))) end
			M.Render()
		end)
	end
	M.EndRow(8)
	-- la liste
	local shown = {}
	for i = 1, getn(list) do
		if A.Match(list[i]) then tinsert(shown, list[i]) end
	end
	M.Section(L("mod.addons.sec.list"), tostring(getn(shown)))
	if getn(shown) == 0 then
		M.Para(L("mod.addons.empty"), 18)
		return
	end
	for i = 1, getn(shown) do
		local r = M.Get("arow")
		if not r then break end
		M.Flow(r, 1, CW, ROWH, 0, 4)
		A.BindRow(r, shown[i])
	end
	M.EndRow(4)
end

-- ---------------------------------------------------------------- commande
function A.Command(rest)
	rest = rest or ""
	local _, _, cmd, arg = string.find(rest, "^(%S*)%s*(%S*)")
	cmd = string.lower(cmd or "")
	arg = string.lower(arg or "")
	if cmd == "" then
		M.Show("addons")
	elseif cmd == "reload" then
		A.Reload()
	elseif cmd == "save" or cmd == "apply" then
		if arg == "" then arg = C.mode end
		if not A.ValidMode(arg) then
			SUI.Print(L("msg.addons.bad"))
		elseif cmd == "save" then
			local n = A.SaveSet(arg)
			SUI.Print(L("msg.addons.saved", SUI.Mode.Name(arg), n or 0))
		else
			local n = A.ApplySet(arg)
			if n then SUI.Print(L("msg.addons.applied", SUI.Mode.Name(arg), n)) else SUI.Print(L("msg.addons.noset", SUI.Mode.Name(arg))) end
		end
	else
		M.Show("addons")
	end
end

SUI.RegisterCommand("addons", A.Command, "help.addons")
