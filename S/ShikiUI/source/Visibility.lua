-- ShikiUI Visibility : visibilite conditionnelle PARTAGEE (combat, groupe, raid, instance, PvP, specialisation, cible).
-- Un SEUL evaluateur pour tous les cadres : les evenements ne sont ecoutes que tant qu'au moins un cadre est enregistre (cout nul sinon),
-- aucune frame ni minuterie permanente (une minuterie de fondu n'existe que pendant un fondu), rien n'est cree en combat.
--
-- API (un module la consomme ainsi) :
--   options (liste options du module) :  SUI.Visibility.Options("meter")  -> { <meter.vis>, <meter.fade> }   (descripteurs, a ajouter a
--        la liste 'options' du module, comme opt()). Parametres facultatifs : Options(prefix, { cat = "meter", order = 800, default = "always", simple = false }).
--   enregistrer un cadre :  SUI.Visibility.Add(frame, "meter", { mode = "alpha", module = "meter", alpha = 1, protected = false,
--        onChange = function(visible, frame) end })
--        mode "alpha" (defaut) : seule l'opacite change (Show/Hide du module jamais touches : aucun conflit avec la logique du module) ;
--        mode "show"  : Show / Hide reels apres le fondu (pour un cadre qui capte la souris) ; le module ne doit alors plus le montrer
--                       contre l'avis de SUI.Visibility.Allowed(frame) ;
--        module       : nom du module ; s'il est coupe, le cadre est laisse tranquille (opacite d'origine) ;
--        alpha        : opacite "pleine" du cadre (defaut : son opacite a l'enregistrement) ; SUI.Visibility.SetBase(frame, a) pour la changer ;
--        protected    : true = jamais de Show/Hide en combat (differe a la sortie de combat via SUI.WhenSafe) ; l'opacite change quand meme ;
--        onChange     : appelee a chaque CHANGEMENT d'etat voulu (et a l'enregistrement) avec visible = true / false.
--        Si le module a enregistre ses options par Options(), rien d'autre a faire ; sinon Add() declare <prefix>.vis et <prefix>.fade lui-meme.
--   retirer :  SUI.Visibility.Remove(frame)         (a la coupure du module : l'opacite d'origine est restauree, les evenements sont
--                                                    detaches quand le dernier cadre part)
--   interroger :  SUI.Visibility.Allowed(frame) -> true / false  (vrai si inconnu) ;  SUI.Visibility.Match(choix) -> true / false
--   recalculer :  SUI.Visibility.Refresh()          (apres un changement que l'evaluateur ne voit pas : ex. fin du mode deplacement)
--   liste des choix :  SUI.Visibility.CHOICES = { "always", "combat", "ooc", "group", "raid", "instance", "pvp", "solo", "target",
--        "spec:1", "spec:2", "spec:3", "never" }   (textes FR / EN : choice.visibility.vis.<choix>)
-- Le mode deplacement (SUI.Mover.active) force la visibilite : on peut toujours positionner un element masque.
-- Specialisation : lue dans SUI.Specs.cur (module specs) ; inconnue = visible (jamais masquer ce que l'utilisateur ne peut pas re-afficher).
-- Instance / PvP : IsInInstance() s'il existe dans le client (NON VERIFIE en jeu sur Turtle WoW), sinon jamais "instance" ni "pvp".
-- Lua 5.0 : pas de '#', '%', '...'.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local V = {}
SUI.Visibility = V

local getn, tinsert, tremove = table.getn, table.insert, table.remove
local floor = math.floor

V.CHOICES = { "always", "combat", "ooc", "group", "raid", "instance", "pvp", "solo", "target", "spec:1", "spec:2", "spec:3", "never" }
V.DEFAULT_FADE = 0.15
V.items = {}            -- liste des entrees
V.byFrame = {}          -- cadre -> entree
V.fading = {}           -- entrees en cours de fondu
V.needTarget = false
V.evals = 0             -- nombre d'evaluations (diagnostic / tests)

local function L(key, a)
	return SUI.L(key, a)
end

-- ---------------------------------------------------------------- options (descripteurs)
local function choiceText(o, v)
	local _, _, n = string.find(v, "^spec:(%d+)$")
	if n then
		local txt = L("choice.visibility.vis.spec", tonumber(n))
		local sp = SUI.Specs and SUI.Specs.cur
		local name = sp and sp.names and sp.names[tonumber(n)]
		if name and not string.find(name, "^#") then txt = txt .. " - " .. name end
		return txt
	end
	return L("choice.visibility.vis." .. v)
end

local function prefixCat(prefix)
	local _, _, c = string.find(prefix, "^([^.]+)")
	return c or prefix
end

-- Descripteurs des deux options communes. o : { cat, order, default, simple } (tout facultatif).
function V.Options(prefix, o)
	o = o or {}
	local cat = o.cat or prefixCat(prefix)
	local order = o.order or 800
	return {
		{ key = prefix .. ".vis", type = "choice", cat = cat, label = "opt.visibility.vis", tip = "tip.visibility.vis",
			choices = V.CHOICES, default = o.default or "always", order = order, simple = o.simple and true or nil, choiceText = choiceText },
		{ key = prefix .. ".fade", type = "number", cat = cat, label = "opt.visibility.fade", tip = "tip.visibility.fade",
			min = 0, max = 2, step = 0.05, default = V.DEFAULT_FADE, order = order + 1 },
	}
end

-- Declare les options si le module ne l'a pas fait (Add les rend ainsi toujours valides).
local function ensureOptions(prefix, cat)
	local C = SUI.Config
	if C.meta[prefix .. ".vis"] and C.meta[prefix .. ".fade"] then return end
	local d = V.Options(prefix, { cat = cat })
	for i = 1, getn(d) do
		if not C.meta[d[i].key] then SUI.RegisterOption(d[i]) end
	end
end

-- ---------------------------------------------------------------- contexte et conditions
local function numOf(fn)
	if type(fn) ~= "function" then return 0 end
	local ok, n = pcall(fn)
	if ok and type(n) == "number" then return n end
	return 0
end

-- Etat du monde, calcule UNE fois par evaluation. combat : valeur imposee par l'evenement (le jeu peut etre en retard), sinon lue.
local function context(combat)
	local ctx = {}
	if combat == nil then combat = SUI.InCombat() end
	ctx.combat = combat and true or false
	ctx.raid = numOf(GetNumRaidMembers) > 0
	ctx.group = ctx.raid or numOf(GetNumPartyMembers) > 0
	ctx.solo = not ctx.group
	local inst = getglobal("IsInInstance")
	local inside, kind = false, nil
	if type(inst) == "function" then
		local ok, a, b = pcall(inst)
		if ok and a and a ~= 0 then inside, kind = true, b end
	end
	ctx.instance = inside and (kind == "party" or kind == "raid" or kind == nil) and true or false
	ctx.pvp = inside and (kind == "pvp" or kind == "arena") and true or false
	ctx.target = UnitExists("target") and true or false
	local sp = SUI.Specs and SUI.Specs.cur
	ctx.spec = sp and tonumber(sp.id) and sp.id > 0 and sp.id or nil
	return ctx
end

-- Le choix est-il satisfait ? (choix inconnu ou vide : visible)
local function matches(choice, ctx)
	if choice == nil or choice == "always" then return true end
	if choice == "never" then return false end
	if choice == "combat" then return ctx.combat end
	if choice == "ooc" then return not ctx.combat end
	if choice == "group" then return ctx.group end
	if choice == "raid" then return ctx.raid end
	if choice == "solo" then return ctx.solo end
	if choice == "instance" then return ctx.instance end
	if choice == "pvp" then return ctx.pvp end
	if choice == "target" then return ctx.target end
	local _, _, n = string.find(choice, "^spec:(%d+)$")
	if n then
		if ctx.spec == nil then return true end
		return ctx.spec == tonumber(n)
	end
	return true
end

function V.Match(choice)
	return matches(choice, context())
end

-- ---------------------------------------------------------------- application (opacite / Show / Hide)
local function applyShown(it)
	local f = it.frame
	if it.want then
		if not f:IsShown() then f:Show() end
	elseif it.cur <= 0 and f:IsShown() then
		f:Hide()
	end
end

local function syncShown(it)
	if it.mode ~= "show" then return end
	if it.protected then
		SUI.WhenSafe(function() applyShown(it) end)
	else
		applyShown(it)
	end
end

local function setAlpha(it, a)
	it.cur = a
	it.frame:SetAlpha(a)
end

local function fadeTime(it)
	local d = SUI.Config.Get(it.prefix .. ".fade")
	if type(d) ~= "number" then d = V.DEFAULT_FADE end
	return d
end

local function stepFade()
	local now = GetTime()
	local dt = now - (V.last or now)
	V.last = now
	if dt > 0.25 then dt = 0.25 end
	local list = V.fading
	local i = 1
	while i <= getn(list) do
		local it = list[i]
		if type(it.cur) ~= "number" then it.cur = it.target or 1 end
		if type(it.target) ~= "number" then it.target = it.cur end
		local delta = (it.speed or 1) * dt
		local done = false
		if it.cur < it.target then
			local a = it.cur + delta
			if a >= it.target then a = it.target done = true end
			setAlpha(it, a)
		else
			local a = it.cur - delta
			if a <= it.target then a = it.target done = true end
			setAlpha(it, a)
		end
		if done then
			it.fading = false
			tremove(list, i)
			syncShown(it)
		else
			i = i + 1
		end
	end
	if getn(list) == 0 then
		SUI.Cancel(V.task)
		V.task = nil
		V.last = nil
	end
end

local function startFade(it, secs)
	it.speed = (it.base > 0 and it.base or 1) / secs
	if not it.fading then
		it.fading = true
		tinsert(V.fading, it)
	end
	if not V.task then
		V.last = GetTime()
		V.task = SUI.Every(0.03, stepFade, "visfade")
	end
end

-- Pose l'etat voulu d'une entree. first : premiere evaluation (pas de fondu au chargement).
local function setWant(it, want, first)
	local changed = (it.want ~= want)
	it.want = want
	it.target = want and it.base or 0
	if it.cur == nil then it.cur = it.frame:GetAlpha() end
	if it.mode == "show" and want and not it.frame:IsShown() then
		-- on montre d'abord (a l'opacite 0 sauf au chargement), puis on fond
		if not first then setAlpha(it, 0) end
		syncShown(it)
	end
	local secs = fadeTime(it)
	if first or secs <= 0 or (it.cur == it.target) then
		if it.fading then
			it.fading = false
			for i = getn(V.fading), 1, -1 do
				if V.fading[i] == it then tremove(V.fading, i) end
			end
		end
		setAlpha(it, it.target)
		syncShown(it)
	else
		startFade(it, secs)
	end
	if changed and it.onChange then
		local ok, err = pcall(it.onChange, want, it.frame)
		if not ok then SUI.Report("visibility", err) end
	end
end

local function moduleOff(it)
	local m = it.module and SUI.modules[it.module]
	return m and not m.enabled
end

local function evalItem(it, ctx, first)
	if moduleOff(it) then
		if it.managed then
			it.managed = false
			it.want = nil
			-- un fondu en cours laisserait l'entree dans V.fading : stepFade remettrait l'alpha a 0
			-- sur le cadre qui vient d'etre rendu au module (re-apparition invisible)
			if it.fading then
				it.fading = false
				for j = getn(V.fading), 1, -1 do
					if V.fading[j] == it then tremove(V.fading, j) end
				end
			end
			it.frame:SetAlpha(it.base)
			it.cur = nil
		end
		return
	end
	local want
	if SUI.Mover and SUI.Mover.active then
		want = true
	else
		local choice = SUI.Config.Get(it.prefix .. ".vis")
		want = matches(choice, ctx)
		if choice == "target" then V.needTarget = true end
	end
	local was = it.managed
	it.managed = true
	setWant(it, want, first or not was or it.want == nil)
end

-- ---------------------------------------------------------------- evaluateur partage
function V.Refresh(combat)
	if getn(V.items) == 0 then return end
	V.evals = V.evals + 1
	V.needTarget = false
	local ctx = context(combat)
	for i = 1, getn(V.items) do
		local ok, err = pcall(evalItem, V.items[i], ctx, false)
		if not ok then SUI.Report("visibility", err) end
	end
end

local function pendingRun()
	V.pending = false
	V.Refresh()
end

-- Evenements en rafale (groupe, zone, talents) : un seul recalcul differe.
local function schedule()
	if V.pending then return end
	V.pending = true
	SUI.After(0.1, pendingRun, "vis")
end

local function onEvent(ev)
	if ev == "PLAYER_REGEN_DISABLED" then
		V.Refresh(true)
	elseif ev == "PLAYER_REGEN_ENABLED" then
		V.Refresh(false)
	elseif ev == "PLAYER_TARGET_CHANGED" then
		if V.needTarget then schedule() end
	else
		schedule()
	end
end

V.EVENTS = { "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "CHARACTER_POINTS_CHANGED", "UPDATE_BATTLEFIELD_STATUS" }

local function onConfig(key)
	if key == nil or key == "mode" or key == "ui.locked" or string.find(key, ".vis", 1, true) then
		V.Refresh()
	end
end

local function attach()
	if V.attached then return end
	V.attached = true
	for i = 1, getn(V.EVENTS) do SUI.On(V.EVENTS[i], onEvent) end
	SUI.Config.Watch("", onConfig)
end

local function detach()
	if not V.attached then return end
	V.attached = false
	for i = 1, getn(V.EVENTS) do SUI.Off(V.EVENTS[i], onEvent) end
	SUI.Config.Unwatch(onConfig)
	if V.task then
		SUI.Cancel(V.task)
		V.task = nil
		V.last = nil
	end
	V.fading = {}
	V.pending = false
end

-- ---------------------------------------------------------------- API
function V.Add(frame, prefix, opts)
	if type(frame) ~= "table" or type(prefix) ~= "string" or not frame.SetAlpha then return false end
	opts = opts or {}
	ensureOptions(prefix, opts.cat)
	local it = V.byFrame[frame]
	if not it then
		it = { frame = frame, cur = nil, base = 1 }
		V.byFrame[frame] = it
		tinsert(V.items, it)
	end
	it.prefix = prefix
	it.mode = (opts.mode == "show") and "show" or "alpha"
	it.module = opts.module
	it.protected = opts.protected and true or false
	it.onChange = opts.onChange
	it.base = tonumber(opts.alpha) or frame:GetAlpha() or 1
	if it.base <= 0 then it.base = 1 end
	it.want, it.managed = nil, false
	attach()
	local ok, err = pcall(evalItem, it, context(), true)
	if not ok then SUI.Report("visibility", err) end
	return true
end

function V.Remove(frame)
	local it = V.byFrame[frame]
	if not it then return false end
	V.byFrame[frame] = nil
	for i = getn(V.items), 1, -1 do
		if V.items[i] == it then tremove(V.items, i) end
	end
	for i = getn(V.fading), 1, -1 do
		if V.fading[i] == it then tremove(V.fading, i) end
	end
	it.fading = false
	if it.managed then it.frame:SetAlpha(it.base) end
	if getn(V.items) == 0 then detach() end
	return true
end

-- Vrai si le cadre doit etre visible selon la regle (vrai aussi s'il n'est pas enregistre ou pas encore evalue).
function V.Allowed(frame)
	local it = V.byFrame[frame]
	if not it or it.want == nil then return true end
	return it.want
end

-- Change l'opacite "pleine" d'un cadre enregistre (le module a un reglage d'opacite propre).
function V.SetBase(frame, a)
	local it = V.byFrame[frame]
	if not it or type(a) ~= "number" or a <= 0 then return end
	it.base = a
	if it.want then
		it.target = a
		if not it.fading then setAlpha(it, a) end
	end
end

function V.Count()
	return getn(V.items)
end
