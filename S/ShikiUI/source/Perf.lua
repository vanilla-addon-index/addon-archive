-- ShikiUI Perf : moniteur (FPS, latence, memoire Lua, debit d'allocation), mode urgence, rapport par minuterie / evenement.
-- Limites connues du client 1.12 : pas de mesure CPU par addon ; les temps par minuterie (/sui perf profile) sont INDICATIFS.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local P = {}
SUI.Perf = P

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local HIST = 10

P.fps, P.lat, P.mem = 0, 0, 0
P.allocRate = 0
P.hist = {}
P.lowCount, P.highCount = 0, 0
P.autoTriggered = false
P.callbacks = {}
P.hud = nil

function P.OnEmergency(fn)
	tinsert(P.callbacks, fn)
end

function P.SetEmergency(on, auto)
	on = on and true or false
	if SUI.emergency == on then return end
	SUI.emergency = on
	SUI.rateMul = on and 2 or 1
	SUI.Reschedule()
	P.autoTriggered = (on and auto) and true or false
	for i = 1, getn(P.callbacks) do
		local ok, err = pcall(P.callbacks[i], on)
		if not ok then SUI.Report("emergency", err) end
	end
	SUI.Print(L(on and "msg.emergency.on" or "msg.emergency.off"))
end

local function hex(c)
	return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function level(v, good, warn, invert)
	local T = SUI.Theme.c
	if invert then
		if v <= good then return T.good elseif v <= warn then return T.warn end
		return T.bad
	end
	if v >= good then return T.good elseif v >= warn then return T.warn end
	return T.bad
end

function P.HudText()
	local mb = (P.mem or 0) / 1024
	return string.format("|cff%s%d|r fps  |cff%s%d|r ms  |cffa0a6b4%.1f Mo|r%s",
		hex(level(P.fps, 45, 25)), math.floor(P.fps + 0.5),
		hex(level(P.lat, 100, 250, true)), math.floor(P.lat + 0.5), mb,
		SUI.emergency and ("  |cff" .. hex(SUI.Theme.c.warn) .. "URGENCE|r") or "")
end

function P.EnsureHud()
	if P.hud then return P.hud end
	local T = SUI.Theme
	local f = CreateFrame("Frame", "ShikiUI_Hud", UIParent)
	f:SetWidth(210)
	f:SetHeight(20)
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	f.text = T.Text(f, 11, T.c.text, "CENTER")
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	P.hud = f
	SUI.Layout.Register(f, "hud", "TOP", 0, -8)
	return f
end

function P.UpdateHud()
	if not SUI.Config.Get("perf.hud") or (SUI.modules.perf and not SUI.modules.perf.enabled) then
		-- module coupe : le HUD ne doit jamais ressusciter via un watcher reste abonne
		if P.hud then P.hud:Hide() end
		return
	end
	if not P.hud then
		if SUI.InCombat() then return end     -- jamais de creation d'objets en combat : le prochain echantillon reessaie
		P.EnsureHud()
	end
	P.hud:Show()
	P.hud.text:SetText(P.HudText())
end

function P.Sample()
	local fps = GetFramerate() or 0
	local _, _, lat = GetNetStats()
	local mem = gcinfo() or 0
	P.fps, P.lat, P.mem = fps, lat or 0, mem
	local h = P.hist
	tinsert(h, mem)
	if getn(h) > HIST then tremove(h, 1) end
	local grow = 0
	for i = 2, getn(h) do
		local d = h[i] - h[i - 1]
		if d > 0 then grow = grow + d end
	end
	P.allocRate = (getn(h) > 1) and (grow / (getn(h) - 1)) or 0
	if SUI.Config.Get("perf.auto") then
		local th = SUI.Config.Get("perf.autofps") or 25
		if th > 45 then th = 45 end          -- un seuil au-dessus de 45 serait toujours atteint (jeu plafonne a 60 fps)
		if fps > 0 and fps < th then
			P.lowCount = P.lowCount + 1
			P.highCount = 0
		else
			P.lowCount = 0
			if fps >= th + 5 then P.highCount = P.highCount + 1 else P.highCount = 0 end
		end
		if not SUI.emergency and P.lowCount >= 8 then
			P.SetEmergency(true, true)
		elseif SUI.emergency and P.autoTriggered and P.highCount >= 10 then
			P.SetEmergency(false)
		end
	end
	P.UpdateHud()
end

-- Lignes de rapport (affichees par /sui perf).
function P.Report()
	local lines = {}
	tinsert(lines, L("perf.main", math.floor(P.fps + 0.5), math.floor(P.lat + 0.5), P.mem / 1024))
	tinsert(lines, L("perf.alloc", P.allocRate))
	tinsert(lines, L("perf.state", SUI.emergency and L("perf.on") or L("perf.off"), SUI.errCount, getn(SUI.tasks)))
	if SUI.lastErr then tinsert(lines, L("perf.lasterr", SUI.lastErr)) end
	local list = {}
	for i = 1, getn(SUI.tasks) do
		if not SUI.tasks[i].dead then tinsert(list, SUI.tasks[i]) end
	end
	table.sort(list, function(a, b) return a.calls > b.calls end)
	for i = 1, math.min(getn(list), 6) do
		local t = list[i]
		if SUI.profile and t.calls > 0 then
			tinsert(lines, L("perf.task.p", t.name, t.calls, (t.total / t.calls) * 1000))
		else
			tinsert(lines, L("perf.task", t.name, t.calls))
		end
	end
	local evs = {}
	for name, n in pairs(SUI.evCount) do tinsert(evs, { name = name, n = n }) end
	table.sort(evs, function(a, b) return a.n > b.n end)
	for i = 1, math.min(getn(evs), 5) do
		tinsert(lines, L("perf.event", evs[i].name, evs[i].n))
	end
	return lines
end

function P.SetProfile(on)
	SUI.profile = on and true or false
	for i = 1, getn(SUI.tasks) do
		SUI.tasks[i].calls = 0
		SUI.tasks[i].total = 0
	end
	SUI.evCount = {}
end

local function onKey(key, value)
	if key == nil or key == "perf.hud" then P.UpdateHud() end
end

SUI.RegisterCategory("perf", 3)
SUI.RegisterModule("perf", {
	default = true,
	core = true,
	cost = "light",
	options = {
		{ key = "perf.hud", type = "bool", cat = "perf", label = "opt.perf.hud", tip = "tip.perf.hud", default = false, simple = true, order = 10 },
		{ key = "perf.auto", type = "bool", cat = "perf", label = "opt.perf.auto", tip = "tip.perf.auto", default = false, simple = true, order = 20 },
		{ key = "perf.autofps", type = "number", cat = "perf", label = "opt.perf.autofps", tip = "tip.perf.autofps",
			min = 10, max = 45, step = 5, default = 25, order = 30 },
	},
	enable = function()
		P.task = SUI.Every(1, P.Sample, "perf.sample")
		if not P.watching then
			P.watching = true
			SUI.Config.Watch("perf.", onKey)
		end
		P.UpdateHud()
	end,
	disable = function()
		SUI.Cancel(P.task)
		if P.hud then P.hud:Hide() end
	end,
})
