-- ShikiUI Menu_Wizard : assistant d'installation a DEUX PARCOURS (M.ShowWizard, /sui wizard, bouton "Assistant" de l'accueil, premier lancement).
--   Rapide          : langue, role, style + taille d'interface, recapitulatif. Tout le reste = reglages conseilles par role.
--   Installation +  : Rapide + modules a activer (cartes, valeur conseillee par role), mise en page, reglages essentiels de quelques modules
--                     (barres, cadres d'unites, groupe / raid, compteurs / menace, minimap, chat), specialites (module "specs"), sauvegardes,
--                     suite, puis le recapitulatif "Voici ce qui va changer".
--   Guide           : langue, role, etape Guide (reglages conseilles du role, un apercu 2D SUI.Preview par ligne, "Changer ce choix"),
--                     recapitulatif. La page finale a des boutons "Ouvrir cette option" (SUI.Menu.OpenAt) ; /sui wizard la reprend.
-- On change de parcours a tout moment (bouton d'en-tete ou premiere page). Chaque etape a Passer (on ignore l'etape : ses choix reviennent a
-- l'etat d'avant) et Par defaut conseille (les valeurs conseillees pour le role), Precedent / Suivant.
-- PRINCIPE : rien n'est ecrit dans la configuration avant le clic sur "Appliquer" (recapitulatif). Les choix sont gardes dans M.ws.sel ; seul
-- le choix de la LANGUE est applique sur le champ (pour que l'assistant se lise dans la bonne langue) et restaure si on annule.
-- SECURITE : au clic sur "Appliquer", un instantane du profil est pris (Backup.lua, reason "wizard") ; "Tout annuler" (page finale) le restaure,
-- defait les prises en main pfUI (Migrate.Take / Both) et les liens de specialites crees. Annuler avant Appliquer ne change rien.
-- COHABITATION pfUI : l'etape "migrate" (si pfUI est la) garde son role : laisser la main, la prendre ou garder les deux. L'ancien import des
-- reglages pfUI n'existe plus.
-- Les modules des autres agents (meter, threat, specs...) ne sont JAMAIS requis : tout passe par SUI.modules[nom] et SUI.Config.meta[cle].
-- REGLE DE FERMETURE (client 1.12) : aucune fermeture creee dans une boucle ne lit la variable de la boucle ; la valeur est rangee sur le
-- bouton (b.n, b.pid, b.rid / b.oid...) et relue par le gestionnaire via son argument.
-- NIVEAUX : l'assistant est en FULLSCREEN_DIALOG a un niveau explicite tres haut (WLEVEL), donc au-dessus du menu leve et du mode deplacement.
-- NON VERIFIE EN JEU : la disposition (tailles de texte, coupure des FontStrings), les clics a la souris, la detection UnitXP au moment ou
-- l'assistant s'ouvre (1,5 s apres la connexion), le choix des modules / reglages conseilles par role (valeurs d'usage, pas des mesures).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local M = SUI.Menu

local getn, tinsert = table.getn, table.insert
local floor = math.floor

local WW, WH = 720, 580
local CX, CY, CW = 24, -152, 672
local WLEVEL = 400
local PERPAGE = 10

local STEP_IDS = { "welcome", "migrate", "role", "guide", "modules", "style", "layout", "essentials", "specs", "backup", "place", "summary" }
local QUICK = { welcome = true, migrate = true, role = true, style = true, summary = true }
-- Parcours GUIDE : role, puis les reglages conseilles montres un par un avec leur apercu 2D (SUI.Preview), puis recapitulatif.
local GUIDED = { welcome = true, migrate = true, role = true, guide = true, summary = true }
local PATHS = { "quick", "plus", "guided" }
local NOPEN = 4     -- boutons "Ouvrir cette option" de la page finale
local NGUIDE = 6    -- lignes de la page Guide
local PVW, PVH = 330, 230
local PACKS = { "essential", "complete", "light", "tank", "heal", "pvp", "all" }
local ESS = { "units", "actionbars", "castbar", "minimap", "tooltip", "chat", "bags", "loot", "perf" }
local LIGHT = { "units", "actionbars", "castbar", "minimap", "tooltip", "perf" }
local EXTRA = {
	tank = { "tanktools", "threat", "auras", "nameplates", "meter", "group", "raid" },
	heal = { "clickheal", "group", "raid", "auras", "meter" },
	pvp = { "nameplates", "auras", "group", "totems" },
}
local ROLE_ONLY = { tanktools = true, clickheal = true, totems = true }
local ROLE_PACK = { tank = "tank", heal = "heal", dps = "complete", pvp = "pvp" }
local SCALES = { 0.9, 1.0, 1.1 }
local SIZE_KEYS = { "wiz.size.small", "wiz.size.normal", "wiz.size.large" }
local KNOWN = { "pfUI", "ElvUI", "ShaguTweaks", "Bartender2", "Bartender3", "Dominos", "Bagnon", "Prat", "Chatter", "Recount", "DPSMate",
	"Omen", "KLHThreatMeter", "ThreatClassic2", "Skinner" }
local SPEC_ROLES = { "keep", "tank", "heal", "dps", "pvp" }

-- Reglages essentiels. Une ligne = un choix a quelques boutons. keys : cles de configuration (toutes recoivent la meme valeur) ; vals : valeur
-- de chaque option (meme ordre que opts) ; special : "bars" / "chat" = reglages d'ensemble (option "keep" = ne rien changer).
-- Une ligne ne s'affiche que si un module qui porte l'une de ses cles est present ET coche dans l'assistant.
local TABS = { "bars", "units", "group", "meter", "minimap", "chat" }
local ES = {
	{ id = "bars", tab = "bars", mod = "actionbars", special = "bars", opts = { "keep", "always", "combat", "incombat" } },
	{ id = "size", tab = "bars", keys = { "actionbars.size" }, opts = { "small", "normal", "large" }, vals = { 32, 36, 44 } },
	{ id = "micro", tab = "bars", keys = { "actionbars.micro" }, opts = { "always", "never" }, vals = { "always", "never" } },
	{ id = "xp", tab = "bars", keys = { "actionbars.xpbar" }, opts = { "slim", "hide", "blizz" }, vals = { "slim", "hide", "blizz" }, reload = true },
	{ id = "uwidth", tab = "units", keys = { "units.width" }, opts = { "small", "normal", "large" }, vals = { 150, 180, 220 } },
	{ id = "uhp", tab = "units", keys = { "units.hptext" }, opts = { "none", "percent", "value", "both" }, vals = { "none", "percent", "value", "both" } },
	{ id = "upower", tab = "units", keys = { "units.showpower" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "urange", tab = "units", keys = { "units.range" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "rsize", tab = "group", keys = { "raid.maxgroup" }, opts = { "r5", "r10", "r25", "r40" }, vals = { 1, 2, 5, 8 } },
	{ id = "dispel", tab = "group", keys = { "group.dispelmode", "raid.dispelmode" }, opts = { "known", "all", "off" }, vals = { "known", "all", "off" } },
	{ id = "donly", tab = "group", keys = { "group.dispelonly", "raid.dispelonly" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "debuffs", tab = "group", keys = { "group.debuffs", "raid.debuffs" }, opts = { "n0", "n1", "n2", "n3" }, vals = { 0, 1, 2, 3 } },
	{ id = "mwin", tab = "meter", keys = { "meter.windows" }, opts = { "n1", "n2", "n3" }, vals = { 1, 2, 3 } },
	{ id = "mhide", tab = "meter", keys = { "meter.hideooc" }, opts = { "off", "on" }, vals = { false, true } },
	{ id = "tshow", tab = "meter", keys = { "threat.show" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "twarn", tab = "meter", keys = { "threat.warn" }, opts = { "p75", "p85", "p95" }, vals = { 75, 85, 95 } },
	{ id = "tsound", tab = "meter", keys = { "threat.sound" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "shape", tab = "minimap", keys = { "minimap.shape" }, opts = { "round", "square" }, vals = { "round", "square" } },
	{ id = "clock", tab = "minimap", keys = { "minimap.clock" }, opts = { "off", "local", "server" }, vals = { "off", "local", "server" } },
	{ id = "coords", tab = "minimap", keys = { "minimap.coords" }, opts = { "on", "off" }, vals = { true, false } },
	{ id = "btnmode", tab = "minimap", keys = { "minimap.btnmode" }, opts = { "drawer", "hover", "hide" }, vals = { "drawer", "hover", "hide" } },
	{ id = "chat", tab = "chat", mod = "chat", special = "chat", opts = { "keep", "std", "quiet", "read" } },
}
-- Valeurs conseillees par role (id de ligne -> id d'option). Une ligne absente = on ne change rien. Valeurs d'usage, pas des mesures.
local REC = {
	tank = { tshow = "on", tsound = "on", twarn = "p85", mwin = "n1" },
	heal = { dispel = "known", donly = "on", debuffs = "n3", mwin = "n1", tshow = "off" },
	dps = { tshow = "on", tsound = "on", twarn = "p85", mwin = "n1", dispel = "known" },
	pvp = { dispel = "all", donly = "off", debuffs = "n3", tshow = "off" },
}
local CHAT = {
	std = { ["chat.stamp"] = true, ["chat.classcolor"] = true, ["chat.url"] = true, ["chat.shortchan"] = false, ["chat.background"] = false },
	quiet = { ["chat.stamp"] = false, ["chat.shortchan"] = true, ["chat.hidebuttons"] = true, ["chat.background"] = false },
	read = { ["chat.stamp"] = true, ["chat.classcolor"] = true, ["chat.background"] = true, ["chat.bgalpha"] = 0.6, ["chat.shortchan"] = false,
		["chat.fontsize"] = 12 },
}
local WB, WR, WA, WDEF, WPASS = {}, {}, {}, {}, {}

-- ---------------------------------------------------------------- petits outils de dessin
local function tx(parent, size, col, x, y, w, h, just)
	local fs = T.Text(parent, size, col, just or "LEFT")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if w then fs:SetWidth(w) end
	if h then fs:SetHeight(h) end
	fs:SetJustifyV("TOP")
	return fs
end

-- Bouton de l assistant : cible >= 24 px de haut (sinon rehaussee), retour visuel au survol (bordure d accent, par Theme.lua) ET a l appui (fond creux).
local MINH = 24
local function btn(parent, w, h, x, y, fn)
	if h < MINH then h = MINH end
	-- Chaque clic est note dans le journal (/sui errors) avec son libelle, et une erreur du bouton y est enregistree au lieu d'etre perdue.
	local b
	b = T.Button(parent, "", w, h, function(bb, a1)
		local lab = b and b.label and b.label.GetText and b.label:GetText() or "?"
		SUI.LogError("wizard clic", tostring(lab))
		local ok, err = pcall(fn, bb, a1)
		if not ok then SUI.Report("wizard bouton " .. tostring(lab), err) end
	end)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b:EnableMouse(true)
	b:SetFrameLevel(parent:GetFrameLevel() + 6)          -- au-dessus de tout cadre frere de la page
	if b.SetHitRectInsets then b:SetHitRectInsets(-2, -2, -2, -2) end   -- zone de clic un peu plus large que le dessin
	b:SetScript("OnMouseDown", function()
		local c = T.c.inset
		b:SetBackdropColor(c[1], c[2], c[3], c[4])
	 end)
	b:SetScript("OnMouseUp", function()
		local c = T.c.panel
		b:SetBackdropColor(c[1], c[2], c[3], c[4])
	end)
	return b
end

-- Ajoute un traitement au survol SANS perdre le retour visuel de Theme.lua (SetScript remplace le gestionnaire du bouton).
local function onHover(b, enter, leave)
	local oe, ol = b:GetScript("OnEnter"), b:GetScript("OnLeave")
	if not oe then
		oe = function()
			local r, g, bl = T.Accent()
			b:SetBackdropBorderColor(r, g, bl, 1)
		end
		ol = function()
			if b.selected then
				local r, g, bl = T.Accent()
				b:SetBackdropBorderColor(r, g, bl, 1)
			else
				local c = T.c.border
				b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
			end
		end
	end
	-- le bouton survole est passe aux rappels (this) : ne jamais relire la variable d'une boucle depuis le rappel
	b:SetScript("OnEnter", function()
		local me = this
		if oe then oe() end
		if enter then enter(me) end
	end)
	b:SetScript("OnLeave", function()
		local me = this
		if ol then ol() end
		if leave then leave(me) end
	end)
end

local function copyT(t)
	local c = {}
	if type(t) ~= "table" then return c end
	for k, v in pairs(t) do
		if type(v) == "table" then c[k] = copyT(v) else c[k] = v end
	end
	return c
end

local function tex(parent, layer)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(T.tex.white)
	return t
end

local function paint(t, c)
	t:SetVertexColor(c[1], c[2], c[3], 1)
end

local function accentOf(tok)
	local a = tok.accent
	if type(a) == "table" then return a[1], a[2], a[3] end
	if a == "class" and RAID_CLASS_COLORS then
		local _, class = UnitClass("player")
		local col = class and RAID_CLASS_COLORS[class]
		if col then return col.r, col.g, col.b end
	end
	local t = T.accents[a] or T.accents.blue
	return t[1], t[2], t[3]
end

local function modLabel(n)
	local s = M.ModName(n)
	local _, _, r = string.find(s, "^Module%s+(.+)$")
	if r then s = r end
	_, _, r = string.find(s, "^(.-)%s+module$")
	if r then s = r end
	s = M.Cap(s)
	if string.len(s) > 20 then s = string.sub(s, 1, 19) .. "." end
	return s
end

local function yn(on)
	return on and "[x] " or "[ ] "
end

local function sizeLabel(sc)
	for i = 1, 3 do
		if math.abs((sc or 1) - SCALES[i]) < 0.001 then return L(SIZE_KEYS[i]) end
	end
	return string.format("%.2f", sc or 1)
end

local function pathName(p, short)
	return L("mod.setup.path." .. (p or "plus") .. (short and ".s" or ".n"))
end

-- texte d'une option d'une ligne de reglages : cle propre a la ligne, sinon texte commun
local function optText(r, o)
	local k = "mod.setup.row." .. r.id .. "." .. o
	if M.Has(k) then return L(k) end
	return L("mod.setup.o." .. o)
end

local function optIndex(r, o)
	for i = 1, getn(r.opts) do
		if r.opts[i] == o then return i end
	end
	return nil
end

-- ---------------------------------------------------------------- reglages essentiels : quelles lignes, quelles cles
local function modOfKey(k)
	local _, _, m = string.find(k, "^(%w+)%.")
	return m
end

-- cles de la ligne dont le module existe et est coche dans l'assistant, et qui sont declarees
local function esKeys(r)
	local t = {}
	local sel = M.ws and M.ws.sel
	if not r.keys then return t end
	for i = 1, getn(r.keys) do
		local k = r.keys[i]
		local m = modOfKey(k)
		if m and SUI.modules[m] and (not sel or sel.mods[m]) and SUI.Config.meta[k] then tinsert(t, k) end
	end
	return t
end

function M.WizEsOn(r)
	local sel = M.ws.sel
	if r.special then
		return (SUI.modules[r.mod] and sel.mods[r.mod]) and true or false
	end
	return getn(esKeys(r)) > 0
end

function M.WizTabRows(tab)
	local t = {}
	for i = 1, getn(ES) do
		if ES[i].tab == tab and M.WizEsOn(ES[i]) then tinsert(t, ES[i]) end
	end
	return t
end

-- option qui correspond a la valeur actuelle de la configuration (nil = valeur personnalisee, ou valeurs differentes selon les cles de la
-- ligne ; "keep" pour les reglages d'ensemble)
local function esCur(r)
	if r.special then return "keep" end
	if not r.keys then return nil end
	local C = SUI.Config
	local found
	for i = 1, getn(r.keys) do
		local k = r.keys[i]
		if C.meta[k] then
			local v = C.Get(k)
			local here
			for j = 1, getn(r.opts) do
				if r.vals[j] == v then here = r.opts[j] end
			end
			if here == nil then return nil end
			if found ~= nil and found ~= here then return nil end
			found = here
		end
	end
	return found
end

-- ---------------------------------------------------------------- etat et choix
function M.WizInit()
	local C = SUI.Config
	local sel = { ui = {}, mods = {}, es = {}, spec = {} }
	sel.path = "plus"
	sel.locale = C.Get("ui.locale")
	sel.style = C.Get("style.name")
	sel.scale = C.Get("ui.scale")
	sel.layout = SUI.Layout and SUI.Layout.Current() or nil
	if SUI.layouts and SUI.layouts.shiki and (sel.layout == nil or sel.layout == "classic") then sel.layout = "shiki" end   -- installation neuve : disposition recommandee
	sel.modeauto = C.Get("mode.auto")
	sel.role = C.GetRole()
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		sel.mods[n] = C.Get("modules." .. n) and true or false
	end
	for i = 1, getn(ES) do sel.es[ES[i].id] = esCur(ES[i]) end
	sel.mig = "keep"
	sel.after = "move"
	M.ws = { sel = sel, orig = copyT(sel), modPage = 1, applied = false, touch = {}, tab = nil }
	-- premier lancement : un role est conseille d'office (DPS, le plus courant) et les valeurs qui vont avec sont preselectionnees
	if C.GetGlobal("firstRun") then
		if not sel.role then sel.role = "dps" end
		M.WizRecAll()
	end
end

function M.WizSteps()
	local t = {}
	local path = M.ws and M.ws.sel.path
	local only = (path == "quick" and QUICK) or (path == "guided" and GUIDED) or nil
	for i = 1, getn(STEP_IDS) do
		local id = STEP_IDS[i]
		if (not only or only[id]) and (not WA[id] or WA[id]()) then tinsert(t, id) end
	end
	return t
end

-- parcours courts (Rapide, Guide) : les reglages conseilles par role sont mis partout ou l'utilisateur n'a rien retouche
local function isShort(p)
	return p == "quick" or p == "guided"
end

-- l'etape Guide n'existe que dans le parcours Guide
function WA.guide()
	return M.ws and M.ws.sel.path == "guided" and true or false
end

function WA.migrate()
	local Mg = SUI.Migrate
	return (Mg and Mg.Present and Mg.Present()) and true or false
end

function WA.essentials()
	for i = 1, getn(ES) do
		if M.WizEsOn(ES[i]) then return true end
	end
	return false
end

function WA.specs()
	if not SUI.modules.specs or type(SUI.Specs) ~= "table" or type(SUI.Specs.Scan) ~= "function" then return false end
	local ok, s = pcall(SUI.Specs.Scan)
	return (ok and type(s) == "table" and s.n and s.n >= 1) and true or false
end

-- modules de pfUI qui ont un equivalent chez nous et dont l'etat demande un choix
function M.WizMigItems()
	local t = {}
	local Mg = SUI.Migrate
	if not Mg or not Mg.Present or not Mg.Present() then return t end
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		if Mg.MAP[n] then
			local st = Mg.State(n)
			if st ~= "free" and st ~= "shiki" then tinsert(t, { name = n, state = st }) end
		end
	end
	return t
end

function M.WizAddons()
	local t = {}
	if not IsAddOnLoaded then return t end
	for i = 1, getn(KNOWN) do
		local ok, v = pcall(IsAddOnLoaded, KNOWN[i])
		if ok and v then tinsert(t, KNOWN[i]) end
	end
	return t
end

-- packs : ensemble de modules (nom -> true), limite aux modules qui existent
function M.WizPackSet(id)
	local set = {}
	local sel = M.ws.sel
	local function put(list)
		for i = 1, getn(list) do
			if SUI.modules[list[i]] then set[list[i]] = true end
		end
	end
	if id == "all" then
		for i = 1, getn(SUI.moduleOrder) do set[SUI.moduleOrder[i]] = true end
	elseif id == "light" then
		put(LIGHT)
	elseif id == "essential" then
		put(ESS)
	elseif id == "complete" then
		for i = 1, getn(SUI.moduleOrder) do
			local n = SUI.moduleOrder[i]
			if not ROLE_ONLY[n] then set[n] = true end
		end
		if sel.role == "tank" and SUI.modules.tanktools then set.tanktools = true end
		if sel.role == "heal" and SUI.modules.clickheal then set.clickheal = true end
		if SUI.Config.class == "SHAMAN" and SUI.modules.totems then set.totems = true end
	else
		put(ESS)
		put(EXTRA[id] or {})
	end
	if SUI.Config.class == "PALADIN" and SUI.modules.pallypower and id ~= "light" then set.pallypower = true end
	return set
end

function M.WizApplyPack(id)
	local set = M.WizPackSet(id)
	local sel = M.ws.sel
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		sel.mods[n] = set[n] and true or false
	end
end

function M.WizCurrentPack()
	local sel = M.ws.sel
	for i = 1, getn(PACKS) do
		local set = M.WizPackSet(PACKS[i])
		local same = true
		for j = 1, getn(SUI.moduleOrder) do
			local n = SUI.moduleOrder[j]
			if (set[n] and true or false) ~= (sel.mods[n] and true or false) then same = false end
		end
		if same then return PACKS[i] end
	end
	return nil
end

-- ordre des cartes : modules conseilles pour le role d'abord (ordre stable : ne depend pas des coches)
function M.WizModOrder()
	local sel = M.ws.sel
	local list = {}
	if not sel.role then
		for i = 1, getn(SUI.moduleOrder) do tinsert(list, SUI.moduleOrder[i]) end
		return list, {}
	end
	local set = M.WizPackSet(ROLE_PACK[sel.role])
	for i = 1, getn(SUI.moduleOrder) do
		if set[SUI.moduleOrder[i]] then tinsert(list, SUI.moduleOrder[i]) end
	end
	for i = 1, getn(SUI.moduleOrder) do
		if not set[SUI.moduleOrder[i]] then tinsert(list, SUI.moduleOrder[i]) end
	end
	return list, set
end

-- ---------------------------------------------------------------- reglages conseilles
-- Modules : le pack du role (ou "Complet" sans role quand force).
function M.WizRecMods(force)
	local sel = M.ws.sel
	local role = sel.role
	if not role and force then role = "dps" end
	if role then M.WizApplyPack(ROLE_PACK[role]) end
end

-- Reglages essentiels : valeurs du role, le reste revient a l'etat d'avant.
function M.WizRecEs()
	local ws = M.ws
	local sel, orig = ws.sel, ws.orig
	local rec = (sel.role and REC[sel.role]) or {}
	for i = 1, getn(ES) do
		local id = ES[i].id
		local v = rec[id]
		if v == nil then v = orig.es[id] end
		sel.es[id] = v
	end
end

-- Tout ce que l'utilisateur n'a pas retouche a la main.
function M.WizRecAll()
	local touch = M.ws.touch
	if not touch.modules then M.WizRecMods(false) end
	if not touch.essentials then M.WizRecEs() end
end

function M.WizSetRole(r)
	local ws = M.ws
	local sel = ws.sel
	if sel.role == r then sel.role = nil else sel.role = r end
	M.WizRecAll()
	if M.wiz then M.WizRender() end
end

-- Parcours : "quick" ou "plus". Rapide = les reglages conseilles par role sont mis partout ou l'utilisateur n'a rien retouche.
function M.WizSetPath(p)
	local ws = M.ws
	if not ws or (p ~= "quick" and p ~= "plus" and p ~= "guided") then return end
	local sel = ws.sel
	sel.path = p
	if not ws.touch.place then sel.after = isShort(p) and "menu" or "move" end
	if isShort(p) then M.WizRecAll() end
	if M.wiz then
		M.WizStepFix(M.wiz.stepId)
		M.WizRender()
	end
end

-- Apres un changement de parcours : si l'etape courante n'existe plus, on va a la suivante qui existe.
function M.WizStepFix(oldId)
	local f = M.wiz
	if not f or not oldId or oldId == "done" then return end
	local steps = M.WizSteps()
	for i = 1, getn(steps) do
		if steps[i] == oldId then return end
	end
	local pos = 1
	for i = 1, getn(STEP_IDS) do
		if STEP_IDS[i] == oldId then pos = i end
	end
	for i = pos + 1, getn(STEP_IDS) do
		for j = 1, getn(steps) do
			if steps[j] == STEP_IDS[i] then
				f.stepId = STEP_IDS[i]
				return
			end
		end
	end
	f.stepId = steps[getn(steps)]
end

function M.WizEsSet(rid, oid)
	local ws = M.ws
	if not ws or not rid then return end
	ws.sel.es[rid] = oid
	ws.touch.essentials = true
	M.WizRender()
end

function M.WizModToggle(name)
	local ws = M.ws
	if not ws or not name then return end
	ws.sel.mods[name] = not ws.sel.mods[name]
	ws.touch.modules = true
	M.WizRender()
end

function M.WizSpecSet(i, role)
	local ws = M.ws
	if not ws or not i then return end
	if role == "keep" then role = nil end
	ws.sel.spec[i] = role
	-- une specialite liee n'a d'effet que si le module "specs" est actif
	if role and SUI.modules.specs and not ws.sel.mods.specs then ws.sel.mods.specs = true end
	M.WizRender()
end

-- Par defaut conseille : valeurs conseillees pour CETTE etape
function WDEF.welcome()
	local sel = M.ws.sel
	local code = "en"
	if type(GetLocale) == "function" and GetLocale() == "frFR" then code = "fr" end
	M.WizSetLocale(code)
	sel.path = "plus"
	if not M.ws.touch.place then sel.after = "move" end
end

function WDEF.migrate()
	M.ws.sel.mig = "keep"
end

function WDEF.role()
	local sel = M.ws.sel
	sel.role = M.ws.orig.role or "dps"
	M.WizRecAll()
end

function WDEF.modules()
	M.ws.touch.modules = nil
	M.WizRecMods(true)
end

function WDEF.style()
	local sel = M.ws.sel
	sel.style = SUI.Style.DEFAULT
	sel.scale = 1.0
end

function WDEF.layout()
	local sel = M.ws.sel
	sel.layout = nil
	sel.modeauto = true
end

function WDEF.essentials()
	M.ws.touch.essentials = nil
	M.WizRecEs()
end

function WDEF.specs()
	local sel = M.ws.sel
	sel.spec = {}
	local ok, s = pcall(SUI.Specs.Scan)
	if ok and type(s) == "table" and s.id and s.id > 0 and sel.role then sel.spec[s.id] = sel.role end
end

function WDEF.guide()
	M.ws.touch.essentials = nil
	M.WizRecEs()
end

function WDEF.backup()
end

function WDEF.place()
	local ws = M.ws
	ws.touch.place = nil
	ws.sel.after = isShort(ws.sel.path) and "menu" or "move"
end

-- Passer : l'etape est ignoree, ses choix reviennent a l'etat d'avant l'assistant
function WPASS.migrate()
	M.ws.sel.mig = "keep"
end

function WPASS.role()
	local ws = M.ws
	ws.sel.role = ws.orig.role
	M.WizRecAll()
end

function WPASS.modules()
	local ws = M.ws
	ws.sel.mods = copyT(ws.orig.mods)
	ws.touch.modules = true
end

function WPASS.style()
	local ws = M.ws
	ws.sel.style = ws.orig.style
	ws.sel.scale = ws.orig.scale
end

function WPASS.layout()
	local ws = M.ws
	ws.sel.layout = nil
	ws.sel.modeauto = ws.orig.modeauto
end

function WPASS.essentials()
	local ws = M.ws
	ws.sel.es = copyT(ws.orig.es)
	ws.touch.essentials = true
end

function WPASS.guide()
	local ws = M.ws
	ws.sel.es = copyT(ws.orig.es)
	ws.touch.essentials = true
end

function WPASS.specs()
	M.ws.sel.spec = {}
end

function M.WizDefault()
	local f = M.wiz
	local id = f and f.stepId
	if not id or not WDEF[id] then return end
	WDEF[id]()
	M.WizRender()
end

function M.WizPass()
	local f = M.wiz
	local id = f and f.stepId
	if not id or id == "summary" or id == "done" then return end
	if WPASS[id] then WPASS[id]() end
	M.WizGo(f.step + 1)
end

-- ---------------------------------------------------------------- construction
function M.BuildWizard()
	if M.wiz then return M.wiz end
	local f = CreateFrame("Frame", "ShikiUI_Wizard", UIParent)
	M.wiz = f
	f:SetWidth(WW)
	f:SetHeight(WH)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
	f:SetFrameStrata("FULLSCREEN_DIALOG")   -- au-dessus du menu (DIALOG) et de ses fenetres
	f:SetFrameLevel(WLEVEL)                 -- explicite : au-dessus du menu leve (mode deplacement) et des poignees du Mover
	f:SetToplevel(true)
	f:EnableMouse(true)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	f.title = tx(f, 18, T.c.text, 24, -14, 316, 24)
	f.pathBtn = btn(f, 226, 24, 346, -12, function() M.WizGo(1) end)
	f.dots = tx(f, 12, T.c.dim, WW - 24 - 120, -20, 120, 16, "RIGHT")
	f.prog = T.Bar(f)
	f.prog:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -46)
	f.prog:SetWidth(CW)
	f.prog:SetHeight(4)
	f.stepTitle = tx(f, 15, T.c.text, 24, -58, CW, 20)
	f.why = tx(f, 12, T.c.text, 24, -82, CW, 34)
	f.what = tx(f, 11, T.c.dim, 24, -116, CW, 30)
	f.pg = {}
	for i = 1, getn(STEP_IDS) + 1 do
		local id = STEP_IDS[i] or "done"
		local pg = CreateFrame("Frame", nil, f)
		pg:SetWidth(WW)
		pg:SetHeight(WH)
		pg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		pg:SetFrameLevel(f:GetFrameLevel() + 1)   -- niveaux explicites : pages < pied de page ; la page ne capte pas la souris (pas de EnableMouse)
		pg:Hide()
		f.pg[id] = pg
		WB[id](pg)
	end
	local fy = -(WH - 46)
	f.skip = btn(f, 92, 30, 24, fy, function() M.WizCancel() end)
	f.prevBtn = btn(f, 104, 30, 124, fy, function() M.WizGo(f.step - 1) end)
	f.defBtn = btn(f, 180, 30, WW - 24 - 130 - 8 - 90 - 8 - 180, fy, function() M.WizDefault() end)
	f.passBtn = btn(f, 90, 30, WW - 24 - 130 - 8 - 90, fy, function() M.WizPass() end)
	f.nextBtn = btn(f, 130, 30, WW - 24 - 130, fy, function() M.WizNext() end)
	f.pathBtn:SetFrameLevel(f:GetFrameLevel() + 20)
	f.skip:SetFrameLevel(f:GetFrameLevel() + 20)
	f.prevBtn:SetFrameLevel(f:GetFrameLevel() + 20)
	f.defBtn:SetFrameLevel(f:GetFrameLevel() + 20)
	f.passBtn:SetFrameLevel(f:GetFrameLevel() + 20)
	f.nextBtn:SetFrameLevel(f:GetFrameLevel() + 20)
	return f
end

-- Fenetre de taille fixe : reduite si l ecran est trop petit (comme le menu), sans suivre ui.scale.
function M.WizFit()
	local f = M.wiz
	if not f then return end
	local sc = math.min(1, UIParent:GetWidth() / (WW + 16), UIParent:GetHeight() / (WH + 16))
	if sc < 0.3 then sc = 0.3 end
	f:SetScale(sc)
end

function WB.welcome(pg)
	pg.langText = tx(pg, 12, T.c.text, CX, CY, CW, 16)
	pg.l = {}
	for i = 1, 2 do
		-- Valeur portee par le bouton (b.n) et relue dans le gestionnaire : dans le client 1.12 les fermetures d'une boucle for partagent la
		-- variable de boucle (tous les boutons agissaient comme le dernier). Meme regle pour toutes les boucles de ce fichier.
		pg.l[i] = btn(pg, 130, 28, CX + (i - 1) * 138, CY - 20, function(bb) M.WizLang(bb.n) end)
		pg.l[i].n = i
	end
	pg.pathTitle = tx(pg, 13, T.c.text, CX, CY - 62, CW, 18)
	pg.path = {}
	pg.pathDesc = {}
	for i = 1, 3 do
		pg.path[i] = btn(pg, 216, 34, CX + (i - 1) * 228, CY - 84, function(bb) M.WizSetPath(bb.pid) end)
		pg.path[i].pid = PATHS[i]
		pg.pathDesc[i] = tx(pg, 10, T.c.dim, CX + (i - 1) * 228, CY - 122, 216, 54)
	end
	pg.detTitle = tx(pg, 13, T.c.text, CX, CY - 178, CW, 18)
	pg.det = {}
	for i = 1, 4 do
		local y = CY - 198 - (i - 1) * 18
		pg.det[i] = { name = tx(pg, 12, T.c.text, CX, y, 120, 16), st = tx(pg, 12, T.c.dim, CX + 120, y, 90, 16),
			d = tx(pg, 11, T.c.dim, CX + 215, y, 457, 16) }
	end
	pg.addons = tx(pg, 11, T.c.text, CX, CY - 274, CW, 30)
	pg.warn = tx(pg, 11, T.c.warn, CX, CY - 308, CW, 44)
end

function WB.migrate(pg)
	pg.lines = {}
	for i = 1, 5 do pg.lines[i] = tx(pg, 11, T.c.text, CX, CY - (i - 1) * 16, CW, 16) end
	pg.mig = {}
	local ids = { "keep", "take", "both" }
	for i = 1, 3 do
		local id = ids[i]
		pg.mig[i] = btn(pg, 216, 28, CX + (i - 1) * 228, CY - 100, function(bb)
			M.ws.sel.mig = bb.id
			M.WizRender()
		end)
		pg.mig[i].id = id
	end
	pg.migDesc = tx(pg, 11, T.c.dim, CX, CY - 138, CW, 50)
end

function WB.role(pg)
	pg.rb = {}
	for i = 1, 4 do
		pg.rb[i] = btn(pg, 160, 36, CX + (i - 1) * 170, CY, function(bb)
			M.WizSetRole(SUI.Config.roleOrder[bb.n])
		end)
		pg.rb[i].n = i
	end
	pg.cls = tx(pg, 12, T.c.text, CX, CY - 48, CW, 16)
	pg.rows = {}
	for i = 1, 4 do
		local y = CY - 76 - (i - 1) * 54
		pg.rows[i] = { name = tx(pg, 12, T.c.text, CX, y, 110, 16), d = tx(pg, 11, T.c.dim, CX + 120, y, 552, 46) }
	end
	pg.reco = tx(pg, 12, T.c.text, CX, CY - 300, CW, 32)
end

function WB.modules(pg)
	pg.pk = {}
	for i = 1, getn(PACKS) do
		local b = btn(pg, 92, 26, CX + (i - 1) * 96, CY, function(bb)
			M.ws.touch.modules = true
			M.WizApplyPack(bb.pid)
			M.WizRender()
		end)
		b.pid = PACKS[i]
		onHover(b, function(me) pg.hint:SetText(L("mod.menu.wiz.pack.d." .. me.pid)) end, function() M.WizModHint() end)
		pg.pk[i] = b
	end
	pg.hint = tx(pg, 11, T.c.dim, CX, CY - 32, CW - 150, 28)
	pg.pageBtn = btn(pg, 140, 24, CX + CW - 140, CY - 34, function()
		local ws = M.ws
		local pages = floor((getn(SUI.moduleOrder) - 1) / PERPAGE) + 1
		ws.modPage = ws.modPage + 1
		if ws.modPage > pages then ws.modPage = 1 end
		M.WizRender()
	end)
	pg.slot = {}
	pg.sd = {}
	for i = 1, PERPAGE do
		local x = CX + SUI.Mod(i - 1, 2) * 342
		local y = CY - 64 - floor((i - 1) / 2) * 56
		local b = btn(pg, 330, 24, x, y, function(bb)
			if bb.mod then M.WizModToggle(bb.mod) end
		end)
		onHover(b, function(me)
			if me.mod then M.WizModInfo(me.mod) end
		end, function() M.WizModHint() end)
		pg.slot[i] = b
		pg.sd[i] = tx(pg, 10, T.c.dim, x + 2, y - 26, 326, 28)
	end
end

function WB.style(pg)
	pg.sb = {}
	for i = 1, 12 do
		local b = btn(pg, 160, 28, CX + SUI.Mod(i - 1, 4) * 170, CY - floor((i - 1) / 4) * 34, function(bb)
			if bb.id then
				M.ws.sel.style = bb.id
				M.WizRender()
			end
		end)
		onHover(b, function(me)
			if me.id then M.WizPreview(me.id) end
		end, function() M.WizPreview(M.ws.sel.style) end)
		pg.sb[i] = b
	end
	local pv = CreateFrame("Frame", nil, pg)
	pv:SetWidth(330)
	pv:SetHeight(170)
	pv:SetPoint("TOPLEFT", pg, "TOPLEFT", CX, CY - 114)
	pg.pv = pv
	pv.edge = tex(pv, "BACKGROUND")
	pv.edge:SetAllPoints(pv)
	pv.bg = tex(pv, "BORDER")
	pv.bg:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
	pv.bg:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -1, 1)
	pv.title = tex(pv)
	pv.title:SetHeight(22)
	pv.title:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
	pv.title:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -1, -1)
	pv.titleText = pv:CreateFontString(nil, "OVERLAY")
	pv.titleText:SetPoint("TOPLEFT", pv, "TOPLEFT", 8, -6)
	pv.titleText:SetFont(T.font, 11)
	pv.uEdge = tex(pv)
	pv.uEdge:SetWidth(200)
	pv.uEdge:SetHeight(26)
	pv.uEdge:SetPoint("TOPLEFT", pv, "TOPLEFT", 12, -34)
	pv.uBg = tex(pv)
	pv.uBg:SetPoint("TOPLEFT", pv.uEdge, "TOPLEFT", 1, -1)
	pv.uBg:SetPoint("BOTTOMRIGHT", pv.uEdge, "BOTTOMRIGHT", -1, 1)
	pv.fill = tex(pv, "OVERLAY")
	pv.fill:SetWidth(130)
	pv.fill:SetHeight(24)
	pv.fill:SetPoint("TOPLEFT", pv.uEdge, "TOPLEFT", 1, -1)
	pv.uName = pv:CreateFontString(nil, "OVERLAY")
	pv.uName:SetPoint("LEFT", pv.uEdge, "LEFT", 6, 0)
	pv.uName:SetFont(T.font, 11)
	pv.fill2 = tex(pv, "OVERLAY")
	pv.fill2:SetWidth(100)
	pv.fill2:SetHeight(6)
	pv.fill2:SetPoint("TOPLEFT", pv.uEdge, "BOTTOMLEFT", 1, -4)
	pv.sample = pv:CreateFontString(nil, "OVERLAY")
	pv.sample:SetPoint("TOPLEFT", pv, "TOPLEFT", 12, -88)
	pv.sample:SetFont(T.font, 14)
	pv.line = tex(pv)
	pv.line:SetHeight(2)
	pv.line:SetWidth(200)
	pv.line:SetPoint("TOPLEFT", pv, "TOPLEFT", 12, -116)
	pv.dimText = pv:CreateFontString(nil, "OVERLAY")
	pv.dimText:SetPoint("TOPLEFT", pv, "TOPLEFT", 12, -124)
	pv.dimText:SetFont(T.font, 10)
	pv.btnEdge = tex(pv)
	pv.btnEdge:SetWidth(70)
	pv.btnEdge:SetHeight(24)
	pv.btnEdge:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -12, 12)
	pv.btnBg = tex(pv, "OVERLAY")
	pv.btnBg:SetPoint("TOPLEFT", pv.btnEdge, "TOPLEFT", 1, -1)
	pv.btnBg:SetPoint("BOTTOMRIGHT", pv.btnEdge, "BOTTOMRIGHT", -1, 1)
	pv.btnText = pv:CreateFontString(nil, "OVERLAY")
	pv.btnText:SetPoint("CENTER", pv.btnEdge, "CENTER", 0, 0)
	pv.btnText:SetFont(T.font, 11)
	pg.name = tx(pg, 13, T.c.text, CX + 346, CY - 114, 326, 18)
	pg.desc = tx(pg, 11, T.c.dim, CX + 346, CY - 136, 326, 90)
	pg.sizeLabel = tx(pg, 12, T.c.text, CX + 346, CY - 232, 326, 16)
	pg.sz = {}
	for i = 1, 3 do
		pg.sz[i] = btn(pg, 100, 26, CX + 346 + (i - 1) * 108, CY - 252, function(bb)
			M.ws.sel.scale = SCALES[bb.n]
			M.WizRender()
		end)
		pg.sz[i].n = i
	end
	pg.sizeHint = tx(pg, 10, T.c.dim, CX + 346, CY - 284, 326, 30)
end

function WB.layout(pg)
	pg.lc = {}
	for i = 1, 8 do
		local b = CreateFrame("Button", nil, pg)
		b:SetWidth(160)
		b:SetHeight(88)
		b:SetPoint("TOPLEFT", pg, "TOPLEFT", CX + SUI.Mod(i - 1, 4) * 170, CY - floor((i - 1) / 4) * 96)
		T.Backdrop(b, T.c.panel, T.c.border)
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function()
			local x = this
			local sel = M.ws.sel
			if x.id then
				if sel.layout == x.id then sel.layout = nil else sel.layout = x.id end
				M.WizRender()
			end
		end)
		local pv = CreateFrame("Frame", nil, b)
		pv:SetWidth(144)
		pv:SetHeight(46)
		pv:SetPoint("TOP", b, "TOP", 0, -8)
		pv.edge = tex(pv, "BACKGROUND")
		pv.edge:SetAllPoints(pv)
		pv.bg = tex(pv, "BORDER")
		pv.bg:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
		pv.bg:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -1, 1)
		pv.rects = {}
		for j = 1, 12 do
			local r = tex(pv, "OVERLAY")
			r:SetWidth(14)
			r:SetHeight(6)
			r:Hide()
			pv.rects[j] = r
		end
		b:SetScript("OnMouseDown", function()
			local c = T.c.inset
			this:SetBackdropColor(c[1], c[2], c[3], c[4])
		end)
		b:SetScript("OnMouseUp", function()
			local c = T.c.panel
			this:SetBackdropColor(c[1], c[2], c[3], c[4])
		end)
		onHover(b)
		b.pv = pv
		b.name = T.Text(b, 12, T.c.text, "CENTER")
		b.name:SetPoint("BOTTOM", b, "BOTTOM", 0, 10)
		b.name:SetWidth(150)
		pg.lc[i] = b
	end
	pg.modeTitle = tx(pg, 13, T.c.text, CX, CY - 206, CW, 18)
	pg.mode = {}
	for i = 1, 2 do
		pg.mode[i] = btn(pg, 260, 28, CX + (i - 1) * 272, CY - 230, function(bb)
			M.ws.sel.modeauto = (bb.n == 1)
			M.WizRender()
		end)
		pg.mode[i].n = i
	end
	pg.modeDesc = tx(pg, 11, T.c.dim, CX, CY - 266, CW, 48)
	pg.hint = tx(pg, 10, T.c.dim, CX, CY - 330, CW, 16)
end

-- Reglages essentiels : un onglet par famille de modules, jusqu'a 5 lignes par onglet, et (onglet Groupe) un petit apercu du raid.
function WB.essentials(pg)
	pg.tabs = {}
	for i = 1, getn(TABS) do
		local b = btn(pg, 106, 26, CX + (i - 1) * 113, CY, function(bb)
			M.ws.tab = bb.tab
			M.WizRender()
		end)
		b.tab = TABS[i]
		pg.tabs[i] = b
	end
	pg.rows = {}
	for i = 1, 5 do
		local y = CY - 40 - (i - 1) * 58
		local row = { label = tx(pg, 13, T.c.text, CX, y, 210, 16), help = tx(pg, 10, T.c.dim, CX, y - 18, 210, 36), b = {} }
		for j = 1, 4 do
			row.b[j] = btn(pg, 108, 28, CX + 224 + (j - 1) * 116, y - 4, function(bb)
				M.WizEsSet(bb.rid, bb.oid)
			end)
		end
		pg.rows[i] = row
	end
	pg.none = tx(pg, 12, T.c.dim, CX, CY - 40, CW, 30)
	-- apercu du raid : 8 groupes de 5 cases, allumees selon la taille choisie
	local pv = CreateFrame("Frame", nil, pg)
	pv:SetWidth(CW)
	pv:SetHeight(58)
	pv:SetPoint("TOPLEFT", pg, "TOPLEFT", CX, CY - 276)
	pg.pv = pv
	pv.cells = {}
	for g = 1, 8 do
		for k = 1, 5 do
			local c = tex(pv, "ARTWORK")
			c:SetWidth(20)
			c:SetHeight(9)
			c:SetPoint("TOPLEFT", pv, "TOPLEFT", (g - 1) * 25, -(k - 1) * 11)
			pv.cells[(g - 1) * 5 + k] = c
		end
	end
	pv.txt = tx(pv, 11, T.c.dim, 214, 0, 458, 58)
end

function WB.specs(pg)
	pg.sl = {}
	pg.sr = {}
	for i = 1, 3 do
		local y = CY - 4 - (i - 1) * 74
		pg.sl[i] = tx(pg, 12, T.c.text, CX, y, CW, 16)
		pg.sr[i] = {}
		for j = 1, getn(SPEC_ROLES) do
			local b = btn(pg, 120, 28, CX + (j - 1) * 128, y - 22, function(bb)
				M.WizSpecSet(bb.si, bb.rn)
			end)
			b.si = i
			b.rn = SPEC_ROLES[j]
			pg.sr[i][j] = b
		end
	end
	pg.note = tx(pg, 11, T.c.dim, CX, CY - 236, CW, 60)
end

-- Etape Guide : a gauche un apercu 2D (SUI.Preview, lecture seule), a droite les reglages conseilles pour le role ; cliquer une ligne
-- montre son apercu, "Changer ce choix" passe a l'option suivante (rien n'est ecrit avant Appliquer).
function WB.guide(pg)
	pg.inst = {}
	pg.msg = tx(pg, 12, T.c.dim, CX, CY, CW, 60)
	local host = CreateFrame("Frame", nil, pg)
	host:SetWidth(PVW)
	host:SetHeight(PVH)
	host:SetPoint("TOPLEFT", pg, "TOPLEFT", CX, CY - 4)
	T.Backdrop(host, T.c.inset, T.c.border)
	pg.pvHost = host
	pg.nopv = tx(host, 11, T.c.dim, 12, -12, PVW - 24, 40)
	pg.pvTitle = tx(pg, 11, T.c.dim, CX, CY - 4 - PVH - 6, PVW, 16)
	pg.item = {}
	for i = 1, NGUIDE do
		local b = btn(pg, 326, 28, CX + 346, CY - 4 - (i - 1) * 34, function(bb)
			M.ws.gi = bb.n
			M.WizRender()
		end)
		b.n = i
		pg.item[i] = b
	end
	pg.cycle = btn(pg, 326, 28, CX + 346, CY - 4 - NGUIDE * 34, function() M.WizGuideCycle() end)
end

function WB.backup(pg)
	pg.explain = tx(pg, 12, T.c.text, CX, CY, CW, 62)
	pg.now = btn(pg, 330, 30, CX, CY - 72, function()
		local id = SUI.Backup.Create("manual", L("mod.menu.wiz.bk.label"))
		SUI.Print(L("msg.menu.bk.created", id))
		M.WizRender()
	end)
	pg.auto = btn(pg, 330, 30, CX + 342, CY - 72, function()
		SUI.Config.Set("backup.auto", not SUI.Config.Get("backup.auto"))
		M.WizRender()
	end)
	pg.keep = btn(pg, 216, 28, CX, CY - 114, function()
		local C = SUI.Config
		local v = C.Get("backup.keep")
		local list = { 3, 6, 10, 20 }
		local nx = list[1]
		for i = 1, 4 do
			if list[i] == v then nx = list[i + 1] or list[1] end
		end
		C.Set("backup.keep", nx)
		M.WizRender()
	end)
	pg.hours = btn(pg, 216, 28, CX + 228, CY - 114, function()
		local C = SUI.Config
		local v = C.Get("backup.hours")
		local list = { 0, 6, 12, 24, 72 }
		local nx = list[1]
		for i = 1, 5 do
			if list[i] == v then nx = list[i + 1] or list[1] end
		end
		C.Set("backup.hours", nx)
		M.WizRender()
	end)
	pg.logout = btn(pg, 216, 28, CX + 456, CY - 114, function()
		SUI.Config.Set("backup.logout", not SUI.Config.Get("backup.logout"))
		M.WizRender()
	end)
	pg.status = tx(pg, 12, T.c.text, CX, CY - 158, CW, 18)
	pg.rules = tx(pg, 11, T.c.dim, CX, CY - 186, CW, 110)
end

function WB.place(pg)
	pg.pb = {}
	local ids = { "move", "bind", "menu" }
	for i = 1, 3 do
		local id = ids[i]
		local y = CY - 30 - (i - 1) * 62
		pg.pb[i] = { b = btn(pg, 230, 32, CX, y, function(bb)
			M.ws.touch.place = true
			M.ws.sel.after = bb.pid
			M.WizRender()
		end), d = tx(pg, 11, T.c.dim, CX + 246, y - 2, 426, 52), id = id }
		pg.pb[i].b.pid = id
	end
	pg.title = tx(pg, 13, T.c.text, CX, CY, CW, 18)
	pg.cmds = tx(pg, 11, T.c.dim, CX, CY - 224, CW, 34)
end

function WB.summary(pg)
	pg.rows = {}
	for i = 1, 17 do
		local y = CY - (i - 1) * 16
		pg.rows[i] = { l = tx(pg, 11, T.c.dim, CX, y, 170, 14), v = tx(pg, 11, T.c.text, CX + 180, y, 492, 14) }
	end
	pg.note = tx(pg, 11, T.c.warn, CX, CY - 280, CW, 30)
	pg.safe = tx(pg, 11, T.c.dim, CX, CY - 314, CW, 32)
end

function WB.done(pg)
	pg.lines = tx(pg, 12, T.c.text, CX, CY, CW, 196)
	pg.openTitle = tx(pg, 12, T.c.text, CX, CY - 200, CW, 16)
	pg.openb = {}
	for i = 1, NOPEN do
		pg.openb[i] = btn(pg, 330, 26, CX + SUI.Mod(i - 1, 2) * 342, CY - 218 - floor((i - 1) / 2) * 30, function(bb) M.WizOpen(bb.key) end)
	end
	pg.reload = tx(pg, 12, T.c.warn, CX, CY - 282, CW, 32)
	pg.hint = tx(pg, 11, T.c.dim, CX, CY - 318, CW, 50)
end

-- ---------------------------------------------------------------- rendu
function M.WizGo(idx)
	local f = M.wiz
	local steps = M.WizSteps()
	if idx < 1 then idx = 1 end
	if idx > getn(steps) then idx = getn(steps) end
	f.stepId = steps[idx]
	M.WizRender()
end

function M.WizNext()
	local f = M.wiz
	if f.stepId == "done" then
		M.WizFinish()
	elseif f.stepId == "summary" then
		M.WizApply()
	else
		M.WizGo(f.step + 1)
	end
end

function M.WizRender()
	local f = M.wiz
	local steps = M.WizSteps()
	local n = getn(steps)
	local id = f.stepId or steps[1]
	local idx
	for i = 1, n do
		if steps[i] == id then idx = i end
	end
	if not idx and id ~= "done" then
		idx = 1
		id = steps[1]
	end
	f.stepId = id
	f.step = idx or (n + 1)
	f.title:SetText(L("wiz.title"))
	f.dots:SetText(L("mod.menu.wiz.step", idx or n, n))
	f.prog:SetMinMaxValues(0, n)
	f.prog:SetValue(idx or n)
	f.stepTitle:SetText(L("mod.setup.s." .. id .. ".name"))
	f.why:SetText(L("mod.setup.s." .. id .. ".why"))
	f.what:SetText(L("mod.setup.s." .. id .. ".what"))
	for k, pg in pairs(f.pg) do
		if k == id then pg:Show() else pg:Hide() end
	end
	if id == "done" then
		T.SetButtonText(f.skip, L("mod.menu.wiz.undo"))
		T.SetButtonText(f.nextBtn, L("mod.menu.wiz.done"))
		f.prevBtn:Hide()
		f.defBtn:Hide()
		f.passBtn:Hide()
		f.pathBtn:Hide()
	else
		T.SetButtonText(f.skip, L("mod.menu.wiz.cancel"))
		T.SetButtonText(f.nextBtn, id == "summary" and L("mod.menu.wiz.apply") or L("wiz.next"))
		T.SetButtonText(f.prevBtn, L("mod.menu.wiz.back"))
		T.SetButtonText(f.defBtn, L("mod.setup.default"))
		T.SetButtonText(f.passBtn, L("mod.setup.pass"))
		if idx and idx > 1 then f.prevBtn:Show() else f.prevBtn:Hide() end
		if id == "summary" then
			f.defBtn:Hide()
			f.passBtn:Hide()
		else
			f.defBtn:Show()
			f.passBtn:Show()
		end
		if id == "welcome" then
			f.pathBtn:Hide()
		else
			T.SetButtonText(f.pathBtn, L("mod.setup.path.change", pathName(M.ws and M.ws.sel.path, true)))
			f.pathBtn:Show()
		end
	end
	WR[id](f.pg[id])
end

function M.WizSetLocale(code)
	local sel = M.ws.sel
	sel.locale = code
	SUI.Config.Set("ui.locale", sel.locale)
	SUI.SetLocale(SUI.Config.Get("ui.locale"))
end

function M.WizLang(i)
	M.WizSetLocale((i == 1) and "fr" or "en")
	M.WizRender()
end

function WR.welcome(pg)
	local sel = M.ws.sel
	local Api = SUI.Api
	pg.langText:SetText(L("wiz.lang"))
	T.SetButtonText(pg.l[1], "Francais")
	T.SetButtonText(pg.l[2], "English")
	T.SetSelected(pg.l[1], sel.locale == "fr")
	T.SetSelected(pg.l[2], sel.locale == "en")
	pg.pathTitle:SetText(L("mod.setup.path.title"))
	for i = 1, 3 do
		local b = pg.path[i]
		T.SetButtonText(b, pathName(b.pid))
		T.SetSelected(b, sel.path == b.pid)
		pg.pathDesc[i]:SetText(L("mod.setup.path." .. b.pid .. ".d"))
	end
	pg.detTitle:SetText(L("mod.menu.wiz.det.title"))
	local ex = { { "SuperWoW", Api.superwow, "superwow" }, { "Nampower", Api.nampower, "nampower" }, { "UnitXP", Api.unitxp, "unitxp" },
		{ "ClassicAPI", Api.classic, "classic" } }
	for i = 1, 4 do
		local e, row = ex[i], pg.det[i]
		row.name:SetText(e[1])
		row.st:SetText(e[2] and L("mod.menu.home.pfui.yes") or L("mod.menu.home.pfui.no"))
		local col = e[2] and T.c.good or T.c.dim
		row.st:SetTextColor(col[1], col[2], col[3], 1)
		row.d:SetText(L("mod.menu.wiz.ext." .. e[3]))
	end
	local found = M.WizAddons()
	if getn(found) > 0 then
		pg.addons:SetText(L("mod.menu.wiz.det.addons", table.concat(found, ", ")))
	else
		pg.addons:SetText(L("mod.menu.wiz.det.noaddons"))
	end
	local other = false
	for i = 1, getn(found) do
		if found[i] ~= "pfUI" then other = true end
	end
	pg.warn:SetText(other and L("mod.menu.wiz.det.other") or (SUI.Migrate and SUI.Migrate.Present and SUI.Migrate.Present()) and L("mod.menu.wiz.det.pfui") or "")
end

function WR.migrate(pg)
	local sel = M.ws.sel
	local Mg = SUI.Migrate
	local items = M.WizMigItems()
	for i = 1, 5 do
		local it = items[i]
		if it then
			pg.lines[i]:SetText(L("migrate.line", it.name, L("migrate.state." .. it.state), table.concat(Mg.Holders(it.name), ", ")))
			pg.lines[i]:Show()
		else
			pg.lines[i]:Hide()
		end
	end
	if getn(items) == 0 then
		pg.lines[1]:SetText(L("mod.menu.wiz.mig.none"))
		pg.lines[1]:Show()
	end
	for i = 1, 3 do
		local b = pg.mig[i]
		T.SetButtonText(b, L("mod.menu.wiz.mig." .. b.id))
		T.SetSelected(b, sel.mig == b.id)
		if getn(items) > 0 then b:Show() else b:Hide() end
	end
	pg.migDesc:SetText(getn(items) > 0 and L("mod.menu.wiz.mig.d." .. sel.mig) or "")
end

-- apercu d'un style : dessine avec les jetons RESOLUS du style (rien n'est applique)
function M.WizPreview(id)
	local f = M.wiz
	local S = SUI.Style
	local pg = f.pg.style
	local pv = pg.pv
	if not S.styles[id] then id = S.DEFAULT end
	local tok = S.Resolve(id)
	local c = tok.c
	paint(pv.edge, c.border)
	paint(pv.bg, c.bg)
	paint(pv.title, c.panel)
	paint(pv.uEdge, c.border)
	paint(pv.uBg, c.inset)
	local ar, ag, ab = accentOf(tok)
	pv.fill:SetVertexColor(ar, ag, ab, 1)
	paint(pv.fill2, c.good)
	paint(pv.line, c.dim)
	paint(pv.btnEdge, c.border)
	paint(pv.btnBg, c.panel)
	local fonts = { pv.titleText, pv.uName, pv.sample, pv.dimText, pv.btnText }
	local sizes = { 11, 11, 14, 10, 11 }
	local cols = { c.text, c.text, c.text, c.dim, c.text }
	for i = 1, 5 do
		pcall(fonts[i].SetFont, fonts[i], tok.font or T.font, sizes[i] * tok.fontScale, tok.outline)
		fonts[i]:SetTextColor(cols[i][1], cols[i][2], cols[i][3], 1)
	end
	pv.titleText:SetText("ShikiUI")
	pv.uName:SetText(L("mod.menu.wiz.pv.unit"))
	pv.sample:SetText("Aa Bb 0123")
	pv.dimText:SetText(L("mod.menu.wiz.pv.dim"))
	pv.btnText:SetText(L("mod.menu.wiz.pv.btn"))
	pg.name:SetText(S.Label(id))
	pg.desc:SetText(S.Desc(id))
end

function WR.style(pg)
	local sel = M.ws.sel
	local S = SUI.Style
	for i = 1, 12 do
		local b = pg.sb[i]
		local id = S.names[i]
		b.id = id
		if id then
			T.SetButtonText(b, S.Label(id))
			T.SetSelected(b, sel.style == id)
			b:Show()
		else
			b:Hide()
		end
	end
	M.WizPreview(sel.style)
	-- VRAIE taille : l'apercu est mis a l'echelle choisie (Petite 0.9, Normale 1.0, Grande 1.1)
	do
		local sc = sel.scale or 1
		local pv2 = pg.pv
		pv2:ClearAllPoints()
		-- centre de la zone reservee (330 x 170 a partir de CX, CY-114) : le SetScale retrecit autour du centre, le cadre reste en place
		pv2:SetPoint("CENTER", pg, "TOPLEFT", CX + 165, CY - 114 - 85)
		pv2:SetScale(sc)
	end
	pg.sizeLabel:SetText(L("mod.menu.wiz.style.size"))
	for i = 1, 3 do
		T.SetButtonText(pg.sz[i], L(SIZE_KEYS[i]))
		T.SetSelected(pg.sz[i], math.abs((sel.scale or 1) - SCALES[i]) < 0.001)
	end
	pg.sizeHint:SetText(L("mod.menu.wiz.style.sizehint"))
end

function WR.layout(pg)
	local sel = M.ws.sel
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	-- ordre d'affichage : d'abord les mises en page completes (reset), puis les autres ; 8 boutons seulement
	local order, np = {}, 0
	local i2
	for i2 = 1, table.getn(SUI.layoutOrder) do
		local d = SUI.layouts[SUI.layoutOrder[i2]]
		if d and d.reset then np = np + 1 ; order[np] = SUI.layoutOrder[i2] end
	end
	for i2 = 1, table.getn(SUI.layoutOrder) do
		local d = SUI.layouts[SUI.layoutOrder[i2]]
		if not (d and d.reset) then np = np + 1 ; order[np] = SUI.layoutOrder[i2] end
	end
	for i = 1, 8 do
		local b = pg.lc[i]
		local id = order[i]
		b.id = id
		if id then
			local def = SUI.layouts[id]
			local pv = b.pv
			paint(pv.edge, T.c.border)
			paint(pv.bg, T.c.inset)
			local n = 0
			if type(def.pos) == "table" then
				-- ordre deterministe : unit.player d'abord (accent), puis cles triees (pairs = ordre aleatoire)
				local keys, nk = {}, 0
				local k2
				for k2 in pairs(def.pos) do nk = nk + 1 ; keys[nk] = k2 end
				table.sort(keys)
				local qn = {}
				if def.pos["unit.player"] then qn[table.getn(qn) + 1] = "unit.player" end
				for _, k2 in ipairs(keys) do
					if k2 ~= "unit.player" then qn[table.getn(qn) + 1] = k2 end
				end
				for _, key in ipairs(qn) do
					local e = def.pos[key]
					if n < 12 and type(e) == "table" and type(e[1]) == "number" and type(e[2]) == "number" then
						n = n + 1
						local x = (e[1] * sw + (e[3] or 0)) / sw * 144
						local y = (e[2] * sh + (e[4] or 0)) / sh * 46
						if x < 2 then x = 2 end
						if x > 128 then x = 128 end
						if y < 2 then y = 2 end
						if y > 38 then y = 38 end
						local r = pv.rects[n]
						r:ClearAllPoints()
						r:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", floor(x), floor(y))
						if key == "unit.player" then
							local ar, ag, ab = T.Accent()
							r:SetVertexColor(ar, ag, ab, 1)
						else
							paint(r, T.c.dim)
						end
						r:Show()
					end
				end
			end
			for j = n + 1, 12 do pv.rects[j]:Hide() end
			b.name:SetText(SUI.Layout.Label(id))
			T.SetSelected(b, sel.layout == id)
			b:Show()
		else
			b:Hide()
		end
	end
	pg.modeTitle:SetText(L("mod.menu.wiz.mode.title"))
	local has = SUI.Config.meta["mode.auto"] ~= nil
	for i = 1, 2 do
		local b = pg.mode[i]
		T.SetButtonText(b, L(i == 1 and "mod.menu.wiz.mode.auto" or "mod.menu.wiz.mode.manual"))
		T.SetSelected(b, (sel.modeauto and true or false) == (i == 1))
		if has then b:Show() else b:Hide() end
	end
	pg.modeDesc:SetText(has and L(sel.modeauto and "mod.menu.wiz.mode.d.auto" or "mod.menu.wiz.mode.d.manual") or "")
	pg.hint:SetText(L("mod.menu.wiz.layout.hint"))
end

function WR.role(pg)
	local sel = M.ws.sel
	local order = SUI.Config.roleOrder
	for i = 1, 4 do
		T.SetButtonText(pg.rb[i], L("role." .. order[i]))
		T.SetSelected(pg.rb[i], sel.role == order[i])
		pg.rows[i].name:SetText(L("role." .. order[i]))
		pg.rows[i].d:SetText(L("mod.menu.wiz.role.d." .. order[i]))
	end
	local cname
	if UnitClass then cname = UnitClass("player") end
	pg.cls:SetText(cname and L("mod.menu.wiz.role.class", cname) or L("mod.menu.wiz.role.noclass"))
	if sel.role then
		local key = isShort(sel.path) and "mod.setup.role.pack.q" or "mod.menu.wiz.role.pack"
		pg.reco:SetText(L(key, L("mod.menu.wiz.pack." .. ROLE_PACK[sel.role])))
	else
		pg.reco:SetText(L("mod.menu.wiz.role.keep"))
	end
end

function M.WizModHint()
	local pg = M.wiz.pg.modules
	local sel = M.ws.sel
	local on = 0
	for i = 1, getn(SUI.moduleOrder) do
		if sel.mods[SUI.moduleOrder[i]] then on = on + 1 end
	end
	local cur = M.WizCurrentPack()
	local pk = cur and L("mod.menu.wiz.mods.pack", L("mod.menu.wiz.pack." .. cur), L("mod.menu.wiz.pack.d." .. cur)) or L("mod.menu.wiz.mods.custom")
	pg.hint:SetText(L("mod.menu.wiz.mods.count", on, getn(SUI.moduleOrder)) .. "  " .. M.Short(pk, 150))
end

function M.WizModInfo(name)
	local pg = M.wiz.pg.modules
	local m = SUI.modules[name]
	if not m then return end
	local cost = L("mod.menu.cost", L("mod.menu.cost." .. (m.cost or "medium")))
	pg.hint:SetText(M.ModName(name) .. "  -  " .. cost)
end

function WR.modules(pg)
	local ws = M.ws
	local sel = ws.sel
	for i = 1, getn(PACKS) do
		T.SetButtonText(pg.pk[i], L("mod.menu.wiz.pack." .. PACKS[i]))
		T.SetSelected(pg.pk[i], M.WizCurrentPack() == PACKS[i])
	end
	M.WizModHint()
	local list, recset = M.WizModOrder()
	local total = getn(list)
	local pages = floor((total - 1) / PERPAGE) + 1
	if ws.modPage > pages then ws.modPage = 1 end
	if pages > 1 then
		T.SetButtonText(pg.pageBtn, L("mod.menu.wiz.mods.page", ws.modPage, pages))
		pg.pageBtn:Show()
	else
		pg.pageBtn:Hide()
	end
	local first = (ws.modPage - 1) * PERPAGE
	local Mg = SUI.Migrate
	for i = 1, PERPAGE do
		local b = pg.slot[i]
		local name = list[first + i]
		b.mod = name
		if name then
			local lab = yn(sel.mods[name]) .. modLabel(name)
			if recset[name] then lab = lab .. "  (" .. L("mod.setup.rec") .. ")" end
			T.SetButtonText(b, lab)
			T.SetSelected(b, sel.mods[name])
			local d = M.ModShort(name, 100)
			if Mg and Mg.Held and Mg.Held(name) then d = d .. "  " .. L("mod.menu.wiz.mods.wait") end
			pg.sd[i]:SetText(d)
			b:Show()
			pg.sd[i]:Show()
		else
			b:Hide()
			pg.sd[i]:Hide()
		end
	end
end

-- apercu du raid de l'onglet Groupe : 8 groupes de 5, allumes jusqu'a la taille choisie (ou actuelle)
function M.WizRaidMax()
	local sel = M.ws.sel
	local o = sel.es.rsize
	local r
	for i = 1, getn(ES) do
		if ES[i].id == "rsize" then r = ES[i] end
	end
	if o and r then
		local i = optIndex(r, o)
		if i then return r.vals[i] end
	end
	local v = SUI.Config.meta["raid.maxgroup"] and SUI.Config.Get("raid.maxgroup")
	if type(v) == "number" then return v end
	return 8
end

function WR.essentials(pg)
	local ws = M.ws
	local sel = ws.sel
	local first, cur
	for i = 1, getn(TABS) do
		local tab = TABS[i]
		local b = pg.tabs[i]
		if getn(M.WizTabRows(tab)) > 0 then
			if not first then first = tab end
			if ws.tab == tab then cur = tab end
			T.SetButtonText(b, L("mod.setup.tab." .. tab))
			T.SetSelected(b, ws.tab == tab)
			b:Show()
		else
			b:Hide()
		end
	end
	if not cur then
		ws.tab = first
		cur = first
		if cur then
			for i = 1, getn(TABS) do T.SetSelected(pg.tabs[i], TABS[i] == cur) end
		end
	end
	local rows = cur and M.WizTabRows(cur) or {}
	pg.none:SetText(cur and "" or L("mod.setup.es.none"))
	for i = 1, 5 do
		local row = pg.rows[i]
		local r = rows[i]
		if r then
			row.label:SetText(L("mod.setup.row." .. r.id .. ".label"))
			row.help:SetText(L("mod.setup.row." .. r.id .. ".help"))
			row.label:Show()
			row.help:Show()
			for j = 1, 4 do
				local b = row.b[j]
				local o = r.opts[j]
				if o then
					b.rid = r.id
					b.oid = o
					T.SetButtonText(b, optText(r, o))
					T.SetSelected(b, sel.es[r.id] == o)
					b:Show()
				else
					b.rid = nil
					b.oid = nil
					b:Hide()
				end
			end
		else
			row.label:Hide()
			row.help:Hide()
			for j = 1, 4 do
				row.b[j].rid = nil
				row.b[j].oid = nil
				row.b[j]:Hide()
			end
		end
	end
	-- apercu du raid
	local pv = pg.pv
	if cur == "group" then
		local mx = M.WizRaidMax()
		local ar, ag, ab = T.Accent()
		for g = 1, 8 do
			for k = 1, 5 do
				local c = pv.cells[(g - 1) * 5 + k]
				if g <= mx then
					c:SetVertexColor(ar, ag, ab, 1)
					if g == 1 and k == 4 then paint(c, T.c.bad) end
					if g == 2 and k == 2 then paint(c, T.c.warn) end
				else
					paint(c, T.c.inset)
				end
			end
		end
		pv.txt:SetText(L("mod.setup.pv.raid", mx * 5))
		pv:Show()
	else
		pv:Hide()
	end
end

function WR.specs(pg)
	local sel = M.ws.sel
	local Sp = SUI.Specs
	local ok, s = pcall(Sp.Scan)
	if not ok or type(s) ~= "table" then s = { n = 0, names = {}, pts = {} } end
	for i = 1, 3 do
		if i <= s.n then
			pg.sl[i]:SetText(L("mod.setup.spec.line", i, s.names[i] or "?", s.pts[i] or 0))
			pg.sl[i]:Show()
			for j = 1, getn(SPEC_ROLES) do
				local b = pg.sr[i][j]
				local rn = SPEC_ROLES[j]
				T.SetButtonText(b, rn == "keep" and L("mod.setup.o.keep") or L("role." .. rn))
				T.SetSelected(b, (sel.spec[i] or "keep") == rn)
				b:Show()
			end
		else
			pg.sl[i]:Hide()
			for j = 1, getn(SPEC_ROLES) do pg.sr[i][j]:Hide() end
		end
	end
	pg.note:SetText(L("mod.setup.spec.note"))
end

-- lignes de l'etape Guide : reglages conseilles pour le role dont le module est present et coche dans l'assistant
function M.WizGuideItems()
	local sel = M.ws.sel
	local t = {}
	local rec = (sel.role and REC[sel.role]) or {}
	for i = 1, getn(ES) do
		local r = ES[i]
		if getn(t) < NGUIDE and not r.special and rec[r.id] ~= nil and M.WizEsOn(r) then tinsert(t, r) end
	end
	return t
end

-- categorie d'apercu d'une ligne (premier module qui porte ses cles) ; nil si aucune
function M.WizRowCat(r)
	local k = esKeys(r)[1]
	return k and modOfKey(k) or nil
end

function M.WizGuideCycle()
	local ws = M.ws
	local items = M.WizGuideItems()
	local r = items[ws.gi or 1]
	if not r then return end
	local idx = optIndex(r, ws.sel.es[r.id]) or 0
	M.WizEsSet(r.id, r.opts[idx + 1] or r.opts[1])
end

-- apercu 2D de la ligne : instance SUI.Preview mise en cache par categorie ; l'option choisie est passee a Update (rien n'est applique)
function M.WizGuidePreview(pg, r)
	local P = SUI.Preview
	local sel = M.ws.sel
	for _, inst in pairs(pg.inst) do inst.root:Hide() end
	pg.pvTitle:SetText(L("mod.setup.guide.pvfor", L("mod.setup.row." .. r.id .. ".label")))
	pg.nopv:SetText("")
	local cat = M.WizRowCat(r)
	if not (P and cat and P.reg and P.reg[cat] and P.Instance) then
		pg.nopv:SetText(L("mod.setup.guide.nopv"))
		return
	end
	local inst = pg.inst[cat]
	if not inst then
		inst = P.Instance(cat, pg.pvHost, PVW - 2, PVH - 2, false)
		pg.inst[cat] = inst
	end
	if not inst then
		pg.nopv:SetText(L("mod.setup.guide.nopv"))
		return
	end
	inst.root:Show()
	local idx = optIndex(r, sel.es[r.id])
	local keys = esKeys(r)
	if idx then
		for j = 1, getn(keys) do inst.Update(keys[j], r.vals[idx]) end
	end
end

function WR.guide(pg)
	local ws = M.ws
	local sel = ws.sel
	local items = M.WizGuideItems()
	local n = getn(items)
	if (ws.gi or 0) < 1 or ws.gi > n then ws.gi = 1 end
	for i = 1, NGUIDE do
		local b, r = pg.item[i], items[i]
		if r then
			local o = sel.es[r.id] or REC[sel.role][r.id]
			T.SetButtonText(b, M.Short(L("mod.setup.guide.item", L("mod.setup.row." .. r.id .. ".label"), optText(r, o)), 46))
			T.SetSelected(b, ws.gi == i)
			b:Show()
		else
			b:Hide()
		end
	end
	if n == 0 then
		pg.msg:SetText(L(sel.role and "mod.setup.guide.none" or "mod.setup.guide.norole"))
		pg.msg:Show()
		pg.cycle:Hide()
		pg.pvHost:Hide()
		pg.pvTitle:SetText("")
		return
	end
	pg.msg:SetText("")
	pg.pvHost:Show()
	T.SetButtonText(pg.cycle, L("mod.setup.guide.change"))
	pg.cycle:Show()
	M.WizGuidePreview(pg, items[ws.gi])
end

function WR.backup(pg)
	local C = SUI.Config
	local B = SUI.Backup
	pg.explain:SetText(L("mod.menu.wiz.bk.explain"))
	T.SetButtonText(pg.now, L("mod.menu.bk.now"))
	T.SetButtonText(pg.auto, yn(C.Get("backup.auto")) .. L("mod.menu.bk.auto"))
	T.SetSelected(pg.auto, C.Get("backup.auto"))
	T.SetButtonText(pg.keep, L("mod.menu.bk.keep", C.Get("backup.keep")))
	local h = C.Get("backup.hours")
	T.SetButtonText(pg.hours, h == 0 and L("mod.menu.bk.hours.off") or L("mod.menu.bk.hours", h))
	T.SetButtonText(pg.logout, yn(C.Get("backup.logout")) .. L("mod.menu.bk.logout"))
	T.SetSelected(pg.logout, C.Get("backup.logout"))
	local list = B.List()
	if getn(list) > 0 then
		pg.status:SetText(L("mod.menu.wiz.bk.status", getn(list), B.Stamp(list[1].t)))
	else
		pg.status:SetText(L("msg.menu.bk.none"))
	end
	pg.rules:SetText(L("mod.menu.wiz.bk.rules"))
end

function WR.place(pg)
	local sel = M.ws.sel
	pg.title:SetText(L("mod.menu.wiz.place.after"))
	for i = 1, 3 do
		local row = pg.pb[i]
		T.SetButtonText(row.b, L("mod.menu.wiz.place." .. row.id))
		T.SetSelected(row.b, sel.after == row.id)
		row.d:SetText(L("mod.menu.wiz.place.d." .. row.id))
	end
	pg.cmds:SetText(L("mod.menu.wiz.place.cmds"))
end

-- ---------------------------------------------------------------- recapitulatif
-- Retourne { { libelle, valeur }, ... }, rechargement necessaire ?
-- Une ligne par changement important ; les reglages essentiels sont groupes par famille (une ligne par onglet), et s'il y a trop de lignes
-- pour la page ils sont resumes en une seule (rien d'important n'est coupe).
local SUMMAX = 17
local function cut(s, n)
	if string.len(s) > n then return string.sub(s, 1, n - 3) .. "..." end
	return s
end

function M.WizSummary()
	local C = SUI.Config
	local ws = M.ws
	local sel, orig = ws.sel, ws.orig
	local head, esrows, tail = {}, {}, {}
	local reload = false
	local function add(list, k, v)
		tinsert(list, { L("mod.menu.wiz.sum." .. k), v })
	end
	local keep = L("mod.menu.wiz.sum.unchanged")
	tinsert(head, { L("mod.setup.sum.path"), pathName(sel.path, true) })
	add(head, "locale", sel.locale == "fr" and "Francais" or "English")
	add(head, "style", SUI.Style.Label(sel.style))
	add(head, "size", sizeLabel(sel.scale))
	add(head, "role", sel.role and L("role." .. sel.role) or keep)
	if not isShort(sel.path) then
		add(head, "layout", sel.layout and SUI.Layout.Label(sel.layout) or keep)
		if C.meta["mode.auto"] then add(head, "mode", L(sel.modeauto and "mod.menu.wiz.mode.auto" or "mod.menu.wiz.mode.manual")) end
	end
	local on, off, plus, minus = 0, 0, "", ""
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		if sel.mods[n] then on = on + 1 else off = off + 1 end
		if sel.mods[n] ~= orig.mods[n] then
			if sel.mods[n] then plus = plus .. " +" .. modLabel(n) else minus = minus .. " -" .. modLabel(n) end
		end
	end
	add(head, "modules", L("mod.menu.wiz.sum.mods", on, off))
	if plus ~= "" or minus ~= "" then add(head, "changes", cut(string.sub(plus .. minus, 2), 90)) end
	local Mg = SUI.Migrate
	if Mg and Mg.Present and Mg.Present() then
		add(head, "mig", L("mod.menu.wiz.mig." .. sel.mig))
		if sel.mig ~= "keep" and getn(M.WizMigItems()) > 0 then reload = true end
	end
	for i = 1, 3 do
		if sel.spec[i] and WA.specs() then
			local nm = "#" .. i
			local ok, s = pcall(SUI.Specs.Scan)
			if ok and type(s) == "table" and s.names and s.names[i] then nm = s.names[i] end
			tinsert(head, { L("mod.setup.sum.spec", nm), L("role." .. sel.spec[i]) })
		end
	end
	-- reglages essentiels changes, par famille
	local count, names = 0, ""
	for ti = 1, getn(TABS) do
		local line, nline = "", 0
		for i = 1, getn(ES) do
			local r = ES[i]
			if r.tab == TABS[ti] and M.WizEsOn(r) then
				local v = sel.es[r.id]
				if v ~= nil and v ~= orig.es[r.id] and v ~= "keep" then
					nline = nline + 1
					line = line .. (line == "" and "" or " ; ") .. L("mod.setup.row." .. r.id .. ".label") .. " : " .. optText(r, v)
					if r.reload then reload = true end
				end
			end
		end
		if nline > 0 then
			count = count + nline
			names = names .. (names == "" and "" or ", ") .. L("mod.setup.tab." .. TABS[ti])
			tinsert(esrows, { L("mod.setup.tab." .. TABS[ti]), cut(line, 84) })
		end
	end
	add(tail, "backup", L("mod.menu.wiz.sum.bkval", C.Get("backup.auto") and L("mod.menu.val.on") or L("mod.menu.val.off")))
	add(tail, "after", L("mod.menu.wiz.place." .. sel.after))
	local rows = {}
	for i = 1, getn(head) do tinsert(rows, head[i]) end
	if getn(head) + getn(esrows) + getn(tail) > SUMMAX and count > 0 then
		tinsert(rows, { L("mod.setup.sum.es"), cut(L("mod.setup.sum.es.n", count, names), 84) })
	else
		for i = 1, getn(esrows) do tinsert(rows, esrows[i]) end
	end
	for i = 1, getn(tail) do tinsert(rows, tail[i]) end
	return rows, reload
end

function WR.summary(pg)
	local rows, reload = M.WizSummary()
	local n = getn(rows)
	if n > SUMMAX then
		-- vraiment trop de lignes pour la page : les dernieres sont resumees
		local extra = n - (SUMMAX - 1)
		for i = n, SUMMAX, -1 do table.remove(rows, i) end
		tinsert(rows, { "...", L("mod.setup.sum.more", extra) })
	end
	for i = 1, SUMMAX do
		local r, row = rows[i], pg.rows[i]
		if r then
			row.l:SetText(r[1])
			row.v:SetText(r[2])
			row.l:Show()
			row.v:Show()
		else
			row.l:Hide()
			row.v:Hide()
		end
	end
	pg.note:SetText(reload and L("mod.menu.wiz.sum.reload") or "")
	pg.safe:SetText(L("mod.menu.wiz.sum.safe"))
end

function WR.done(pg)
	local ws = M.ws
	local rows = ws.result or {}
	local s = L("mod.menu.wiz.done.n", ws.count or 0) .. "\n"
	local maxr = 11
	for i = 1, getn(rows) do
		if i <= maxr then s = s .. rows[i][1] .. " : " .. rows[i][2] .. "\n" end
	end
	if getn(rows) > maxr then s = s .. L("mod.setup.sum.more", getn(rows) - maxr) .. "\n" end
	pg.lines:SetText(s)
	-- boutons "Ouvrir cette option" : vont a la bonne ligne du menu (SUI.Menu.OpenAt)
	local tg = M.WizOpenTargets()
	pg.openTitle:SetText(getn(tg) > 0 and L("mod.setup.done.open") or "")
	for i = 1, NOPEN do
		local b, e = pg.openb[i], tg[i]
		if e then
			b.key = e[2]
			T.SetButtonText(b, M.Short(L("mod.setup.done.open.btn", e[1]), 44))
			b:Show()
		else
			b.key = nil
			b:Hide()
		end
	end
	pg.reload:SetText(ws.reload and L("mod.menu.wiz.sum.reload") or "")
	pg.hint:SetText(L("mod.menu.wiz.done.hint"))
end

-- Cibles des boutons "Ouvrir cette option" de la page finale : reglages essentiels changes (premiere cle), puis Styles / Modules
function M.WizOpenTargets()
	local ws = M.ws
	local sel, orig = ws.sel, ws.orig
	local es, extra, t = {}, {}, {}
	for i = 1, getn(ES) do
		local r = ES[i]
		local v = sel.es[r.id]
		if v ~= nil and v ~= "keep" and v ~= orig.es[r.id] and M.WizEsOn(r) then
			local key
			if r.special == "bars" then key = "actionbars."
			elseif r.special == "chat" then key = "chat."
			else key = esKeys(r)[1] end
			if key then tinsert(es, { L("mod.setup.row." .. r.id .. ".label"), key }) end
		end
	end
	if sel.style ~= orig.style or sel.scale ~= orig.scale then tinsert(extra, { L("mod.setup.done.open.styles"), "styles" }) end
	for i = 1, getn(SUI.moduleOrder) do
		local n = SUI.moduleOrder[i]
		if sel.mods[n] ~= orig.mods[n] then
			tinsert(extra, { L("mod.setup.done.open.modules"), "modules" })
			break
		end
	end
	for i = 1, getn(es) do
		if getn(t) < NOPEN - getn(extra) then tinsert(t, es[i]) end
	end
	for i = 1, getn(extra) do tinsert(t, extra[i]) end
	return t
end

-- Ouvre le menu a la ligne choisie. L'assistant est masque (il couvre le menu) mais sa page finale reste reprenable (/sui wizard).
function M.WizOpen(key)
	local f, ws = M.wiz, M.ws
	if not key or not f or not ws then return end
	if not M.OpenAt then return end
	SUI.Config.SetGlobal("firstRun", false)
	ws.parked = true
	f:Hide()
	M.OpenAt(key, { preview = true })
	SUI.Print(L("msg.menu.wiz.opened"))
end

-- ---------------------------------------------------------------- application, annulation, fin
function M.WizApply()
	local C = SUI.Config
	local ws = M.ws
	local sel, orig = ws.sel, ws.orig
	if SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return false
	end
	ws.backupId = SUI.Backup and SUI.Backup.Create("wizard", L("mod.menu.wiz.bk.before")) or nil
	ws.mig = {}
	ws.specs = {}
	local n = 0
	local function put(k, v)
		if v ~= nil and C.meta[k] and C.SetBase(k, v) then n = n + 1 end
	end
	local function guard(name, fn)
		local ok, err = pcall(fn)
		if not ok then SUI.Report("wizard " .. name, err) end
	end
	local rows, reload = M.WizSummary()
	-- 1. langue, style, taille, mode
	guard("look", function()
		if sel.locale ~= C.Get("ui.locale") then C.Set("ui.locale", sel.locale) end
		put("style.name", sel.style)
		put("ui.scale", sel.scale)
		if not isShort(sel.path) then put("mode.auto", sel.modeauto) end
	end)
	-- 2. role puis mise en page (seulement si l'utilisateur les a changes : on ne reecrase pas ses reglages sans raison)
	guard("role", function()
		if sel.role and sel.role ~= orig.role then
			C.ApplyRole(sel.role)
			n = n + 1
		end
	end)
	guard("layout", function()
		if not isShort(sel.path) and sel.layout and sel.layout ~= orig.layout and SUI.Layout then
			local ok, _, c = SUI.Layout.ApplyPreset(sel.layout)
			if ok then n = n + (c or 0) end
		end
	end)
	-- 3. modules
	guard("modules", function()
		for i = 1, getn(SUI.moduleOrder) do
			local name = SUI.moduleOrder[i]
			if sel.mods[name] ~= nil and sel.mods[name] ~= (C.Get("modules." .. name) and true or false) then put("modules." .. name, sel.mods[name]) end
		end
	end)
	-- 4. reglages essentiels (seulement les lignes dont le choix a change et dont le module est coche).
	-- EXCEPTION : les tailles (actionbars.size, units.width) s'appliquent MEME SI NON MODIFIEES : elles sont
	-- appliquees APRES la mise en page, dont les presets embarquent leurs propres tailles (ex: minimal = 150) ;
	-- le choix affiche dans l'assistant doit toujours gagner, sinon il semble ignore.
	guard("essentials", function()
		for i = 1, getn(ES) do
			local r = ES[i]
			local v = sel.es[r.id]
			local force = (r.id == "size" or r.id == "uwidth") and v ~= nil and v ~= "keep"
			if v ~= nil and (force or (v ~= orig.es[r.id] and v ~= "keep")) and M.WizEsOn(r) then
				if r.special == "bars" then
					for j = 1, getn(SUI.options) do
						local _, _, bar = string.find(SUI.options[j].key or "", "^actionbars%.([a-z0-9]+)%.show$")
						if bar then put(SUI.options[j].key, (bar == "main" or v == "always") and "always" or v) end
					end
				elseif r.special == "chat" then
					if CHAT[v] then
						for k, cv in pairs(CHAT[v]) do put(k, cv) end
					end
				else
					local idx = optIndex(r, v)
					local keys = esKeys(r)
					if idx then
						for j = 1, getn(keys) do put(keys[j], r.vals[idx]) end
					end
				end
			end
		end
	end)
	-- 5. pfUI : prise en main des modules
	local Mg = SUI.Migrate
	if Mg and sel.mig ~= "keep" then
		guard("migrate", function()
			local items = M.WizMigItems()
			for i = 1, getn(items) do
				local it = items[i]
				if sel.mig == "take" and (it.state == "wait" or it.state == "returning") then
					local ok = Mg.Take(it.name)
					if ok then tinsert(ws.mig, { it.name, "take" }) end
				elseif sel.mig == "both" and it.state == "wait" then
					local ok = Mg.Both(it.name)
					if ok then tinsert(ws.mig, { it.name, "both" }) end
				end
			end
		end)
	end
	-- 6. specialites : un jeu de reglages par specialite choisie (cree APRES le reste : il capture l'etat final)
	guard("specs", function()
		local Sp = SUI.Specs
		if type(Sp) ~= "table" or type(Sp.Capture) ~= "function" then return end
		for i = 1, 3 do
			local role = sel.spec[i]
			if role then
				local name = "Assist" .. i
				local suffix = 1
				while Sp.GetPreset(name) and suffix < 9 do
					suffix = suffix + 1
					name = "Assist" .. i .. "_" .. suffix
				end
				local prev = Sp.Assigned(i)
				local ok = Sp.Capture(name)
				if ok then
					Sp.SetField(name, "role", role)
					Sp.Link(i, name)
					tinsert(ws.specs, { i, name, prev })
					n = n + 1
				end
			end
		end
	end)
	ws.applied = true
	ws.count = n
	ws.reload = reload
	ws.result = rows
	SUI.Print(L("msg.menu.wiz.applied", n))
	M.wiz.stepId = "done"
	M.WizRender()
	return true
end

-- Annule tout ce que l'assistant a applique : restaure l'instantane pris avant, defait les prises en main pfUI et les liens de specialites.
function M.WizUndo()
	local ws = M.ws
	if not ws or not ws.applied or not ws.backupId then return false end
	local ok = SUI.Backup.Restore(ws.backupId)
	if not ok then return false end
	local Mg = SUI.Migrate
	for i = 1, getn(ws.mig or {}) do
		local it = ws.mig[i]
		if it[2] == "take" then Mg.Back(it[1]) else Mg.Hold(it[1]) end
	end
	local Sp = SUI.Specs
	if type(Sp) == "table" then
		for i = getn(ws.specs or {}), 1, -1 do
			local it = ws.specs[i]
			pcall(Sp.Delete, it[2])
			if it[3] then pcall(Sp.Link, it[1], it[3]) end
		end
	end
	ws.applied = false
	ws.mig = {}
	ws.specs = {}
	SUI.Config.SetGlobal("firstRun", false)
	M.wiz:Hide()
	SUI.Print(L("msg.menu.wiz.undone"))
	return true
end

-- Annuler (avant "Appliquer" : on ferme sans rien changer ; sur la page finale : tout restaurer)
function M.WizCancel()
	local ws = M.ws
	local f = M.wiz
	if f.stepId == "done" then
		M.WizUndo()
		return
	end
	if ws and ws.sel.locale ~= ws.orig.locale then
		SUI.Config.Set("ui.locale", ws.orig.locale)
		SUI.SetLocale(SUI.Config.Get("ui.locale"))
	end
	-- remettre proprement l etat du menu : le wizard a pu changer des reglages a la volee (langue, apercu),
	-- on force un rendu complet et la geometry renelle du menu a la fermeture
	M.ws = nil
	if M.frame and M.frame:IsShown() then
		M.ApplyScale()
		M.RebuildNav()
		M.Translate()
		M.Render()
	end
	SUI.Config.SetGlobal("firstRun", false)
	f:Hide()
	SUI.Print(L("msg.menu.wiz.cancel"))
end

function M.WizFinish()
	SUI.Config.SetGlobal("firstRun", false)
	if M.wiz then M.wiz:Hide() end
	local ws = M.ws
	if ws and ws.applied and SUI.Backup then SUI.Backup.AutoCreate("wizard", L("mod.menu.wiz.bk.after")) end
	local after = (ws and ws.applied and ws.sel.after) or "menu"
	if after == "move" and SUI.Mover then
		SUI.Mover.Enter()
	elseif after == "bind" and SUI.Bind then
		SUI.Bind.Enter()
	else
		M.Show("essential")
		M.Open("home")
	end
end

function M.ShowWizard(step)
	if not M.wiz and SUI.InCombat() then
		SUI.Print(L("msg.combat.locked"))
		return
	end
	M.BuildWizard()
	M.WizFit()
	-- reprise apres "Ouvrir cette option" : on revient a la page finale (Tout annuler / Terminer), une seule fois
	if M.ws and M.ws.applied and M.ws.parked and not M.wiz:IsShown() then
		M.ws.parked = nil
		M.wiz.stepId = "done"
		M.WizRender()
		M.wiz:Show()
		return
	end
	if not M.wiz:IsShown() or not M.ws then M.WizInit() end
	M.wiz.stepId = nil
	local steps = M.WizSteps()
	M.wiz.stepId = steps[step or 1] or steps[1]
	M.WizRender()
	M.wiz:Show()
end
