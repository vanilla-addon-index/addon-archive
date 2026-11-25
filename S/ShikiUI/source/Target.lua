-- ShikiUI Target : service de ciblage partage (ennemis proches, distance, ligne de vue, GUID, acquisition de cible).
-- Un seul endroit pour tout ce qui regarde "qui est autour de moi" : les modules (plaques, rotation, alertes, totems...) l'appellent
-- au lieu de refaire leur propre balayage. Rien ne tourne tout seul : un balayage n'a lieu que si un module le demande, au plus
-- une fois par T.TTL (0,4 s), et les resultats sont ranges dans des tableaux reutilises (pas d'allocation par ennemi).
-- Seul le balayage des plaques cree UNE table temporaire (WorldFrame:GetChildren() n'a pas d'autre forme en 1.12) : n'appelez
-- donc pas Scan / Count plus souvent que via SUI.Every(0.4, ...) et laissez le cache faire son travail.
--
-- Inspire de ShikiwaRotation (ShikiwaRotation_Regen.lua : ScanEnemies / CountEnemies, ShikiwaRotation.lua : AcquireNearestEnemy,
-- TargetGuid). Signatures REPRISES de ces addons, jamais executees dans le jeu par ce projet :
--   plaques de nom = enfants du WorldFrame, de type Button et affiches ; GUID de la plaque : plaque:GetName(1) (extension du client)
--   UnitReaction(guid, "player") <= 2 = hostile ; UnitIsDead(guid) ; UnitAffectingCombat(guid) -> 1 ou nil
--   UnitXP("distanceBetween", "player", guid) -> distance en yards (via SUI.Api.Distance pour les unites)
--   UnitExists("target") -> existe, guid (2e valeur avec SuperWoW) ; IsSpellInRange(sort, unite) -> 1 | 0 | nil
--   ClearTarget(), TargetNearestEnemy(), TargetNearestEnemyPlayer() (absente sur certains clients), TargetLastTarget()
-- NON VERIFIE en jeu : GetName(1) sur une plaque (resultat vide sans SuperWoW), UnitXP("inSight", "player", <guid>) avec un GUID.
-- Sans plaques lisibles (extension absente, plaques de nom masquees) le service se replie sur la cible actuelle : T.source = "target".
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local T = {}
SUI.Target = T

local getn = table.getn

T.TTL = 0.4
T.n = 0                    -- nombre d'entrees valides dans guid[] / dist[] / fight[] (le reste des tableaux est du passe)
T.guid = {}                -- guid (ou "target" en repli)
T.dist = {}                -- distance en yards, ou false si inconnue
T.fight = {}               -- true si l'ennemi est en combat
T.source = "none"          -- "plates" | "target" | "none"
T.known = false            -- au moins une distance connue
T.at = -10
T.scans = 0

local seen = {}
local seenN = 0
local SEEN_MAX = 300

local function getChildren()
	return { WorldFrame:GetChildren() }
end

local function plateGuid(plate)
	if not plate:IsObjectType("Button") or not plate:IsShown() then return nil end
	local g = plate:GetName(1)
	if type(g) ~= "string" or g == "0x0000000000000000" or not string.find(g, "^0x%x+$") then return nil end
	return g
end

-- Cible attaquable et vivante (meme definition que ShikiwaRotation.HarmTarget).
function T.Harm(unit)
	unit = unit or "target"
	return UnitExists(unit) and UnitCanAttack("player", unit) and (not UnitIsFriend("player", unit))
		and (not UnitIsDeadOrGhost(unit)) and true or false
end

-- GUID d'une unite (SuperWoW : 2e valeur de UnitExists ; Nampower : GetUnitGUID), nil si impossible.
function T.GUID(unit)
	if unit == "target" and UnitExists("target") then
		local _, g = UnitExists("target")
		if g then return g end
	end
	return SUI.Api.GUID(unit)
end

function T.Distance(unit)
	return SUI.Api.Distance(unit)
end

-- true / false si UnitXP repond, nil sinon.
function T.Sight(unit)
	return SUI.Api.InSight(unit)
end

function T.Behind(unit)
	return SUI.Api.Behind(unit)
end

-- 1 (a portee), 0 (hors de portee) ou nil (inconnu : fonction absente, sort inconnu, pas de cible).
function T.SpellInRange(spell, unit)
	unit = unit or "target"
	if type(IsSpellInRange) ~= "function" or not UnitExists(unit) then return nil end
	local ok, r = pcall(IsSpellInRange, spell, unit)
	if not ok then return nil end
	return r
end

-- ---------------------------------------------------------------- balayage des ennemis proches
local function readUnit(guid)
	local hostile = true
	local ok, reaction = pcall(UnitReaction, guid, "player")
	if ok and reaction then hostile = (reaction <= 2) end
	local alive = true
	local okD, dead = pcall(UnitIsDead, guid)
	if okD and dead then alive = false end
	local fighting = true
	if alive and hostile then
		local okC, inCombat = pcall(UnitAffectingCombat, guid)
		if okC then fighting = (inCombat == 1 or inCombat == true) end   -- nil = pas en combat
	end
	return hostile, alive, fighting
end

local function push(n, guid, dist, fighting)
	T.guid[n] = guid
	T.dist[n] = dist or false
	T.fight[n] = fighting and true or false
	if dist then T.known = true end
end

-- Remplit T.guid / T.dist / T.fight / T.n / T.source. Retourne T.n. Cache : au plus un balayage par T.TTL.
function T.Scan(now)
	now = now or GetTime()
	if now - T.at < T.TTL and now >= T.at then return T.n end
	T.at = now
	T.scans = T.scans + 1
	local n = 0
	T.known = false
	if seenN > SEEN_MAX then
		seen = {}
		seenN = 0
	end
	if WorldFrame then
		local ok, children = pcall(getChildren)
		if ok and children then
			for i = 1, getn(children) do
				local okG, guid = pcall(plateGuid, children[i])
				if okG and guid and seen[guid] ~= T.scans then
					if seen[guid] == nil then seenN = seenN + 1 end
					seen[guid] = T.scans
					local hostile, alive, fighting = readUnit(guid)
					if hostile and alive then
						n = n + 1
						local okX, d = pcall(UnitXP, "distanceBetween", "player", guid)
						push(n, guid, (okX and type(d) == "number") and d or nil, fighting)
					end
				end
			end
		end
	end
	if n > 0 then
		T.source = "plates"
	elseif T.Harm("target") then
		n = 1
		local d = SUI.Api.Distance("target")
		push(1, "target", d, SUI.InCombat() and UnitAffectingCombat("target") == 1)
		T.source = "target"
	else
		T.source = "none"
	end
	T.n = n
	return n
end

-- Nombre d'ennemis a moins de 'range' yards (seulement ceux en combat si fighting). Retourne n, exact :
--   nil, false  = impossible a savoir (aucun ennemi lisible ou aucune distance connue) : ne rien declencher ;
--   n, true     = compte fiable (plaques) ; n, false = borne basse (repli sur la cible seule).
function T.Count(range, fighting, now)
	T.Scan(now)
	if T.n == 0 then return nil, false end
	local c = 0
	local known = false
	for i = 1, T.n do
		if (not fighting) or T.fight[i] then
			local d = T.dist[i]
			if d then
				known = true
				if d <= range then c = c + 1 end
			end
		end
	end
	if not known then return nil, false end
	return c, (T.source == "plates")
end

-- Nombre d'ennemis visibles sans filtre de distance (repli degrade quand UnitXP manque).
function T.Visible(fighting, now)
	T.Scan(now)
	local c = 0
	for i = 1, T.n do
		if (not fighting) or T.fight[i] then c = c + 1 end
	end
	return c
end

-- Ennemi le plus proche de distance connue : guid, distance (nil si aucun).
function T.Nearest(fighting, now)
	T.Scan(now)
	local best, bd = nil, nil
	for i = 1, T.n do
		local d = T.dist[i]
		if d and ((not fighting) or T.fight[i]) and (bd == nil or d < bd) then
			best, bd = T.guid[i], d
		end
	end
	return best, bd
end

-- ---------------------------------------------------------------- acquisition de cible
-- Cible l'ennemi le plus proche. ClearTarget() d'abord : sans cela l'API avance vers la SUIVANTE du cycle ; si rien n'est trouve on
-- retrouve la cible precedente (TargetLastTarget) au lieu de la perdre. playersOnly : TargetNearestEnemyPlayer quand elle existe.
-- A l'appelant de ne pas l'appeler a chaque image (ShikiwaRotation espace ses rechangements de cible).
function T.Acquire(playersOnly)
	local had = UnitExists("target")
	ClearTarget()
	if playersOnly and type(TargetNearestEnemyPlayer) == "function" then
		TargetNearestEnemyPlayer()
	else
		TargetNearestEnemy()
	end
	if had and (not UnitExists("target")) and type(TargetLastTarget) == "function" then
		TargetLastTarget()
	end
	T.at = -10      -- le prochain balayage doit relire la situation
	return UnitExists("target") and true or false
end

-- ---------------------------------------------------------------- diagnostic (/sui target)
function T.Caps()
	local api = SUI.Api
	return WorldFrame ~= nil, api.superwow, api.unitxp
end

local function cmd(rest)
	local L = SUI.L
	local plates, sw, xp = T.Caps()
	SUI.Print(L("msg.target.caps", plates and "oui" or "non", sw and "oui" or "non", xp and "oui" or "non"))
	T.at = -10
	T.Scan()
	SUI.Print(L("msg.target.scan", T.source, T.n))
	for i = 1, T.n do
		if i > 8 then break end
		local d = T.dist[i]
		SUI.Print(L("msg.target.line", T.guid[i], d and string.format("%.1f", d) or "?", T.fight[i] and "oui" or "non"))
	end
end

SUI.RegisterCommand("target", cmd, "help.target")
