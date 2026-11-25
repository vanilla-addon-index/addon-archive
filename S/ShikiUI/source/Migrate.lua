-- ShikiUI Migrate : coexistence avec pfUI et migration MODULE PAR MODULE (objectif : remplacer pfUI).
-- Principe : un module ShikiUI qui a un equivalent pfUI ATTEND tant que pfUI fait tourner cet equivalent (jamais deux jeux de cadres
-- empiles). L'utilisateur donne la main module par module avec /sui migrate take <module> (coupe l'equivalent pfUI pour ce personnage,
-- /reload) et peut revenir en arriere avec /sui migrate back <module>. Les cadres Blizzard ne sont masques que si pfUI ne s'en charge pas.
--
-- Signatures pfUI RELEVEES dans le code installe (C:\...\Interface\AddOns\pfUI), jamais executees dans le jeu par ce projet :
--   pfUI:RegisterModule("nom", fn) range fn dans pfUI.module["nom"] ; pfUI_config.disabled["nom"] == "1" => le module n'est pas lance ;
--   pfUI_config est une SavedVariablesPerCharacter ; les modules de cadres (player, target, ...) sortent tout de suite si
--   pfUI_config.unitframes.disable == "1" ; pfUI.module.player / target masquent PlayerFrame / TargetFrame (modules/player.lua, target.lua) ;
--   menu pfUI : /pfui > "Components" > "Modules" > case "Disable Module <nom>" (modules/gui.lua) ; /reload necessaire.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local Mg = {}
SUI.Migrate = Mg

local getn, tinsert = table.getn, table.insert

-- module ShikiUI -> modules pfUI qu'il remplace (noms enregistres par pfUI:RegisterModule = noms des fichiers de pfUI/modules)
Mg.MAP = {
	units = { "player", "target", "targettarget" },
}

-- modules pfUI qui construisent des cadres d'unites : ils ne tournent pas si pfUI_config.unitframes.disable == "1"
Mg.UF = { player = true, target = true, targettarget = true, targettargettarget = true, pet = true, pettarget = true, focus = true,
	group = true, raid = true }

-- modules pfUI qui masquent eux-memes les cadres Blizzard joueur / cible
Mg.BLIZZ = { "player", "target" }

Mg.boot = nil        -- instantane pris a PLAYER_LOGIN : ce que pfUI FAIT TOURNER dans cette session
Mg.present = false

local function isOn(v)
	return v == "1" or v == 1 or v == true
end

function Mg.Present()
	return type(pfUI) == "table" and type(pfUI.module) == "table"
end

-- pfUI lancera-t-il ce module a sa PROCHAINE lecture de configuration (au prochain /reload) ?
function Mg.ConfigRuns(name)
	if not Mg.Present() then return false end
	if pfUI.module[name] == nil then return false end
	local c = pfUI_config
	if type(c) == "table" then
		if type(c.disabled) == "table" and isOn(c.disabled[name]) then return false end
		if Mg.UF[name] and type(c.unitframes) == "table" and isOn(c.unitframes.disable) then return false end
	end
	return true
end

-- Appele a PLAYER_LOGIN (tous les addons sont charges, pfUI a deja lance ses modules).
function Mg.Boot()
	Mg.present = Mg.Present()
	Mg.boot = {}
	for _, list in pairs(Mg.MAP) do
		for i = 1, getn(list) do Mg.boot[list[i]] = Mg.ConfigRuns(list[i]) end
	end
	for i = 1, getn(Mg.BLIZZ) do Mg.boot[Mg.BLIZZ[i]] = Mg.ConfigRuns(Mg.BLIZZ[i]) end
end

-- Etat REEL de cette session (instantane de connexion) ; hors instantane : lecture directe.
function Mg.Running(name)
	if Mg.boot and Mg.boot[name] ~= nil then return Mg.boot[name] end
	return Mg.ConfigRuns(name)
end

function Mg.Holders(mod)
	local t = {}
	local list = Mg.MAP[mod]
	if not list then return t end
	for i = 1, getn(list) do
		if Mg.Running(list[i]) then tinsert(t, list[i]) end
	end
	return t
end

local function store()
	local db = SUI.Config.db
	if not db then return {} end
	local c = db.global.coexist
	if type(c) ~= "table" then
		c = {}
		db.global.coexist = c
	end
	for k, v in pairs(c) do
		if v ~= true or not Mg.MAP[k] then c[k] = nil end
	end
	return c
end

function Mg.Coexist(mod)
	return store()[mod] == true
end

-- Le module ShikiUI doit-il attendre (pfUI fait encore tourner son equivalent) ?
function Mg.Held(mod)
	if not Mg.MAP[mod] then return false end
	if getn(Mg.Holders(mod)) == 0 then return false end
	return not Mg.Coexist(mod)
end

-- pfUI masque-t-il lui-meme les cadres Blizzard joueur / cible ? Alors ShikiUI n'y touche pas.
function Mg.BlizzOwned()
	for i = 1, getn(Mg.BLIZZ) do
		if Mg.Running(Mg.BLIZZ[i]) then return true end
	end
	return false
end

-- Etat d'un module ShikiUI : free | shiki | wait | leaving | returning | both
function Mg.State(mod)
	local list = Mg.MAP[mod]
	if not list then return "free" end
	if not Mg.present and not Mg.Present() then return "free" end
	local holders = Mg.Holders(mod)
	local willRun = 0
	for i = 1, getn(list) do
		if Mg.ConfigRuns(list[i]) then willRun = willRun + 1 end
	end
	if getn(holders) == 0 then
		if willRun > 0 then return "returning" end
		return "shiki"
	end
	if Mg.Coexist(mod) then return "both" end
	if willRun == 0 then return "leaving" end
	return "wait"
end

-- Nombre de modules ShikiUI (enregistres) qui attendent pfUI.
function Mg.HeldCount()
	local n = 0
	for i = 1, getn(SUI.moduleOrder) do
		if Mg.Held(SUI.moduleOrder[i]) then n = n + 1 end
	end
	return n
end

-- ---------------------------------------------------------------- actions
local function notifyAll()
	SUI.Config.Notify(nil, nil)
end

local function setDisabled(mod, value)
	if not Mg.MAP[mod] then return false, "migrate.unknown" end
	if not Mg.Present() or type(pfUI_config) ~= "table" then return false, "migrate.nopfui" end
	if type(pfUI_config.disabled) ~= "table" then pfUI_config.disabled = {} end
	local done = {}
	local list = Mg.MAP[mod]
	for i = 1, getn(list) do
		if pfUI.module[list[i]] ~= nil then
			pfUI_config.disabled[list[i]] = value
			tinsert(done, list[i])
		end
	end
	if getn(done) == 0 then return false, "migrate.nopfui" end
	return true, nil, table.concat(done, ", ")
end

-- "ShikiUI prend la main" : coupe l'equivalent pfUI (ce personnage), actif apres /reload.
function Mg.Take(mod)
	local ok, key, names = setDisabled(mod, "1")
	if not ok then return false, key end
	store()[mod] = nil
	SUI.Config.SetBase("modules." .. mod, true)   -- le profil de base, jamais la couche du mode courant
	notifyAll()
	return true, "migrate.take.done", names
end

-- Retour arriere : pfUI reprend le module au prochain /reload (ShikiUI s'efface tout seul a ce moment).
function Mg.Back(mod)
	local ok, key, names = setDisabled(mod, "0")
	if not ok then return false, key end
	store()[mod] = nil
	notifyAll()
	return true, "migrate.back.done", names
end

-- Coexistence voulue (essai de placement) : les deux affichent leurs cadres.
function Mg.Both(mod)
	if not Mg.MAP[mod] then return false, "migrate.unknown" end
	store()[mod] = true
	notifyAll()
	return true, "migrate.both.done", mod
end

function Mg.Hold(mod)
	if not Mg.MAP[mod] then return false, "migrate.unknown" end
	store()[mod] = nil
	notifyAll()
	return true, "migrate.hold.done", mod
end

function Mg.Names()
	local t = {}
	for k, _ in pairs(Mg.MAP) do tinsert(t, k) end
	table.sort(t)
	return table.concat(t, ", ")
end

-- ---------------------------------------------------------------- rapport (/sui migrate)
function Mg.Report()
	local L = SUI.L
	local out = {}
	if not Mg.present and not Mg.Present() then
		tinsert(out, L("migrate.none"))
		return out
	end
	local running, covered = 0, 0
	local mapped = {}
	for _, list in pairs(Mg.MAP) do
		for i = 1, getn(list) do mapped[list[i]] = true end
	end
	if Mg.Present() then
		for name, _ in pairs(pfUI.module) do
			if Mg.ConfigRuns(name) then
				running = running + 1
				if mapped[name] then covered = covered + 1 end
			end
		end
	end
	tinsert(out, L("migrate.head", running))
	for i = 1, getn(SUI.moduleOrder) do
		local mod = SUI.moduleOrder[i]
		if Mg.MAP[mod] then
			local st = Mg.State(mod)
			local holders = Mg.Holders(mod)
			tinsert(out, L("migrate.line", mod, L("migrate.state." .. st), getn(holders) > 0 and table.concat(holders, ", ") or "-"))
		end
	end
	tinsert(out, L("migrate.rest", running - covered))
	if SUI.Config.Get("units.hideblizz") and Mg.BlizzOwned() then tinsert(out, L("migrate.blizz")) end
	tinsert(out, L("migrate.usage"))
	return out
end
