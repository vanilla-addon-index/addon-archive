-- ShikiUI Raid : cadres de raid (jusqu'a 40) ULTRA LEGERS, construits sur le moteur partage SUI.GroupEngine (Mod_Group.lua).
-- Le moteur n'est lu qu'a l'activation (jamais au chargement) : aucune dependance d'ordre de fichiers, mais ce module a besoin de
-- Mod_Group.lua present pour fonctionner (sinon il se signale et reste inactif).
-- Cout declare : HEAVY (jusqu'a 40 cadres de 5 frames, 3 icones de debuff et 3 de buff chacun, construits UNE fois hors combat).
-- Raid 40, regles tenues (voir l'en-tete de Mod_Group.lua pour le detail) : un seul evenement touche un seul cadre ; file preallouee
--   videe par une minuterie partagee avec budget par passage (raid.budget) ; tour lent en rotation (raid.slowstep cadres par passage :
--   portee, mort / hors ligne, aggro, soins entrants) ; puissance coupee par defaut (aucun evenement UNIT_MANA... ecoute tant que
--   raid.powerheight vaut 0) ; auras ecoutees seulement si des icones, la dissipation ou une alerte les demandent ; aucune table ni frame
--   creee en combat ; textes reecrits seulement s'ils changent.
-- Tri : par groupe (une colonne par sous-groupe non vide, sous-groupes au-dela de raid.maxgroup masques), role, classe, nom ou ordre du
--   raid. Roles : liste manuelle (/sui raid role Nom t|h|d|none) ou devinette par classe (raid.roleguess).
-- Alertes de debuffs : fragments de texture (/sui raid alert add|del|list|scan) ; chaque nouvelle alerte appelle les crochets
--   SUI.GroupEngine.OnAlert(fn) : POINT D'ENTREE du futur DebuffAlert configurable (modules "alerts" / "debuffs").
-- Equivalent pfUI : module "raid" (cadres de raid ; l'utilisateur les a coupes chez pfUI, Puppeteer fait le raid et les soins : ce module
--   reste COUPE par defaut tant que l'utilisateur ne l'allume pas, "pont Puppeteer d'abord" selon PARITY.md).
-- NON VERIFIE EN JEU : tout (voir Mod_Group.lua : jetons d'unite raidN / player, evenements, GetRaidRosterInfo, etc.).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L

local sfind = string.find

local M = {}
SUI.Raid = M

M.on = false
M.g = nil

function M.Instance()
	if M.g then return M.g end
	local E = SUI.GroupEngine
	if not E then
		SUI.Report("raid", "moteur de cadres absent (Mod_Group.lua)")
		return nil
	end
	M.g = E.New({ name = "raid", title = "Raid", prefix = "raid.", kind = "raid", max = 40, maxDeb = 3, maxBuf = 3, maxHot = 3, layoutKey = "raid",
		defX = 20, defY = -120 })
	M.g.units = E.RAID_UNITS
	return M.g
end

function M.OnKey(key, value)
	if not M.on or not M.g then return end
	if key == nil or key == "ui.locked" or key == "ui.locale" or sfind(key, "^raid%.") then SUI.GroupEngine.OnKey(M.g, key) end
end

function M.Enable()
	local g = M.Instance()
	if not g then return end
	local E = SUI.GroupEngine
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("", M.OnKey)
	end
	SUI.WhenSafe(function()
		if not M.on then return end
		E.ReadConfig(g)
		E.Build(g)
		E.Activate(g)
	end)
end

function M.Disable()
	M.on = false
	if M.g and SUI.GroupEngine then SUI.GroupEngine.Deactivate(M.g) end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("raid", 46)

local function opt(key, typ, order, def, extra)
	local o = { key = "raid." .. key, type = typ, cat = "raid", label = "opt.raid." .. key, tip = "tip.raid." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local RAID_OPTIONS = {
		opt("maxgroup", "number", 10, 8, { min = 1, max = 8, step = 1, simple = true }),
		opt("width", "number", 20, 64, { min = 40, max = 140, step = 2, simple = true }),
		opt("height", "number", 30, 28, { min = 14, max = 60, step = 2, simple = true }),
		opt("powerheight", "number", 40, 0, { min = 0, max = 8, step = 1 }),
		opt("manabar", "choice", 41, "healers", { choices = { "none", "healers", "casters", "all" } }),
		opt("manahunter", "bool", 42, false),
		opt("manatext", "bool", 43, false),
		opt("spacing", "number", 50, 1, { min = 0, max = 10, step = 1 }),
		opt("groupgap", "number", 60, 6, { min = 0, max = 30, step = 1 }),
		opt("sort", "choice", 70, "group", { choices = { "group", "role", "class", "name", "none" }, simple = true }),
		opt("orient", "choice", 80, "vertical", { choices = { "vertical", "horizontal" }, simple = true }),
		opt("perline", "number", 90, 5, { min = 1, max = 40, step = 1 }),
		opt("hpcolor", "choice", 100, "class", { choices = { "class", "health", "style", "custom" } }),
		opt("hptext", "choice", 110, "deficit", { choices = { "none", "percent", "value", "deficit", "deficitpct", "both" }, simple = true }),
		opt("namelen", "number", 120, 6, { min = 3, max = 12, step = 1 }),
		opt("nameanchor", "choice", 121, "topleft", { choices = { "topleft", "topcenter", "topright", "left", "center", "right", "bottomleft", "bottomcenter", "bottomright" }, simple = true }),
		opt("nameicons", "choice", 122, "dispel", { choices = { "off", "dispel", "fx", "both" } }),
		opt("range", "bool", 130, true, { simple = true }),
		opt("rangeyd", "number", 140, 40, { min = 10, max = 60, step = 5 }),
		opt("outalpha", "number", 150, 0.45, { min = 0.2, max = 1, step = 0.05 }),
		opt("debuffs", "number", 160, 2, { min = 0, max = 3, step = 1, simple = true }),
		opt("buffs", "number", 170, 0, { min = 0, max = 3, step = 1 }),
		opt("hots", "number", 172, 2, { min = 0, max = 3, step = 1, simple = true }),
		opt("hotall", "bool", 174, false),
		opt("iconsize", "number", 180, 10, { min = 8, max = 18, step = 1 }),
		opt("dispelmode", "choice", 190, "known", { choices = { "known", "all", "off" }, simple = true }),
		opt("dispelonly", "bool", 200, true),
		opt("dispelstyle", "choice", 202, "both", { choices = { "split", "stripe", "frame", "both", "none" }, simple = true }),
		opt("dispelprio", "choice", 204, "magic", { choices = { "magic", "curse", "poison", "disease" } }),
		opt("dispelbig", "bool", 205, true, { simple = true }),
		opt("dispelsize", "number", 206, 18, { min = 10, max = 28, step = 1 }),
		opt("dispelpos", "choice", 207, "right", { choices = { "center", "right", "left" } }),
		opt("dispelbigmax", "number", 207.1, 1, { min = 1, max = 3, step = 1 }),
		opt("dispelsmall", "bool", 207.2, false, { simple = true }),
		opt("dispelsmallpos", "choice", 207.3, "bottomleft", { choices = { "bottomleft", "bottomright", "topright" } }),
		opt("dispelsmallsize", "number", 207.4, 9, { min = 6, max = 14, step = 1 }),
		opt("dispelthick", "number", 207.5, 2, { min = 1, max = 4, step = 1 }),
		opt("fxframes", "bool", 211, true, { simple = true }),
		opt("fxsize", "number", 212, 16, { min = 12, max = 32, step = 1 }),
		opt("fxpos", "choice", 213, "left", { choices = { "left", "center", "right" } }),
		opt("fxmax", "number", 214, 1, { min = 1, max = 3, step = 1 }),
		opt("aggroframes", "bool", 215, true, { simple = true }),
		opt("tankhots", "number", 173, 0, { min = 0, max = 3, step = 1 }),
		opt("hotwarn", "number", 175, 3, { min = 0, max = 10, step = 1 }),
		opt("lowhp", "number", 112, 0, { min = 0, max = 80, step = 5 }),
		opt("aggro", "bool", 210, true),
		opt("incoming", "bool", 220, true),
		opt("incsrc", "choice", 221, "all", { choices = { "me", "all" } }),
		opt("resinfo", "bool", 225, true),
		opt("roletag", "bool", 230, false),
		opt("leader", "bool", 240, true),
		opt("marks", "bool", 250, true),
		opt("target", "bool", 260, true),
		opt("tooltip", "bool", 270, true),
		opt("alerts", "bool", 280, true),
		opt("alertsound", "choice", 290, "none", { choices = { "none", "self", "any" } }),
		opt("alertlist", "string", 300, ""),
		opt("roles", "string", 310, ""),
		opt("roleguess", "choice", 320, "none", { choices = { "none", "class" } }),
		opt("budget", "number", 330, 12, { min = 1, max = 40, step = 1 }),
		opt("slowstep", "number", 340, 10, { min = 1, max = 40, step = 1 }),
		-- 5e passe (soigneur) : disposition, textes, transparences, ligne de vue, couleurs, listes de HoT
		opt("fill", "choice", 91, "tl", { choices = { "tl", "tr", "bl", "br" } }),
		opt("hpcustom", "color", 101, ""),
		opt("deadcolor", "color", 102, ""),
		opt("inccolor", "color", 103, ""),
		opt("hppos", "choice", 111, "right", { choices = { "topleft", "topcenter", "topright", "left", "center", "right", "bottomleft", "bottomcenter", "bottomright" }, simple = true }),
		opt("manapos", "choice", 64, "center", { choices = { "left", "center", "right" } }),
		opt("manacontent", "choice", 65, "percent", { choices = { "percent", "value", "deficit" } }),
		opt("deadalpha", "number", 151, 0, { min = 0, max = 1, step = 0.05 }),
		opt("offalpha", "number", 152, 0, { min = 0, max = 1, step = 0.05 }),
		opt("los", "bool", 153, false),
		opt("losalpha", "number", 154, 0.6, { min = 0.1, max = 1, step = 0.05 }),
		opt("markpos", "choice", 251, "topleft", { choices = { "topleft", "topcenter", "center" } }),
		opt("marksize", "number", 252, 0, { min = 0, max = 24, step = 1 }),
		opt("hotlist", "string", 176, ""),
		opt("hotoff", "string", 177, ""),
		opt("grpperline", "number", 61, 8, { min = 1, max = 8, step = 1 }),
		opt("grouptitle", "bool", 62, false),
		opt("autosize", "bool", 31, false, { simple = true }),
		opt("scale20", "number", 32, 0.9, { min = 0.4, max = 1.2, step = 0.05 }),
		opt("scale25", "number", 33, 0.8, { min = 0.4, max = 1.2, step = 0.05 }),
		opt("scale40", "number", 34, 0.7, { min = 0.4, max = 1.2, step = 0.05 }),
		-- 6e passe : role / chef place et dimensionne
		opt("tagpos", "choice", 231, "topright", { choices = { "topright", "topleft", "bottomright", "bottomleft" } }),
		opt("tagsize", "number", 232, 9, { min = 7, max = 16, step = 1 }),
}
-- Aspect : texture des barres, police et taille des textes (raid.bartex / raid.font / raid.fontsize).
if SUI.Look then
	local lk = SUI.Look.Options("raid", { bar = true, font = true, cat = "raid", order = 820 })
	for i = 1, table.getn(lk) do table.insert(RAID_OPTIONS, lk[i]) end
end

SUI.RegisterModule("raid", {
	default = false,
	cost = "heavy",
	options = RAID_OPTIONS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : le module "raid".
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.raid then SUI.Migrate.MAP.raid = { "raid" } end

-- Mode Raid : un debuff, un HoT, plus de cadres par passage, tour lent un peu plus serre.
SUI.Config.AddPreset("raid", "*", { ["raid.debuffs"] = 1, ["raid.hots"] = 1, ["raid.budget"] = 16, ["raid.slowstep"] = 8, ["raid.powerheight"] = 0 })

SUI.RegisterCommand("raid", function(rest)
	local E = SUI.GroupEngine
	local g = M.g
	if not E or not g then
		SUI.Print(L("msg.raid.inactive"))
		return
	end
	local w = E.Words(rest)
	if w[1] == "alert" then
		E.CmdAlert(g, w)
	elseif w[1] == "role" then
		E.CmdRole(g, { "role", w[2], w[3] })
	else
		SUI.Print(L("msg.raid.info", g.nOrder, g.qn, g.nAlerts))
	end
end, "help.raid")
