-- ShikiUI Api : detection de SuperWoW / Nampower / UnitXP / ClassicAPI et repli sur l'API 1.12 standard.
-- Chaque appel d'extension est protege (pcall) et possede un repli. Rien n'est suppose present.
-- Signatures utilisees (relevees dans les addons reels installes : pfUI, Puppeteer, SuperCleveRoidMacros, SuperAPI) :
--   SUPERWOW_VERSION (global), UnitExists(unit) -> exists, guid  (SuperWoW)
--   GetNampowerVersion() -> major, minor, patch ; GetUnitGUID(unit) (Nampower 3.0+) ; SetMouseoverUnit(unit)
--   UnitXP("distanceBetween", u1, u2) ; UnitXP("inSight", u1, u2) ; UnitXP("behind", u1, u2) ; sonde pcall(UnitXP, "nop", "nop")
--   CLASSIC_API_VERSION = X*10000 + Y*100 + Z ; C_NamePlate.GetNamePlateGUIDs() ; frame:RegisterUnitEvent (>= 1.15.0)
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local Api = {}
SUI.Api = Api

Api.superwow = false
Api.swVersion = nil
Api.nampower = false
Api.npVersion = nil          -- "major.minor.patch"
Api.npMajor = 0
Api.classic = false
Api.classicVersion = 0
Api.unitxp = false
Api.sightSafe = false        -- UnitXP("inSight") n'est appele que quelques secondes apres l'entree dans le monde
Api.sightSafeAt = nil
Api.feat = {}

local SIGHT_DELAY = 3
local CLASSIC_UNITEVENT = 11500   -- 1.15.0 : frame:RegisterUnitEvent

function Api.Detect()
	Api.superwow = (SUPERWOW_VERSION ~= nil) or (SetAutoloot ~= nil and SpellInfo ~= nil)
	Api.swVersion = SUPERWOW_VERSION and tonumber(SUPERWOW_VERSION) or nil
	Api.nampower = false
	Api.npVersion = nil
	Api.npMajor = 0
	if GetNampowerVersion then
		local ok, major, minor, patch = pcall(GetNampowerVersion)
		if ok and major then
			Api.nampower = true
			Api.npMajor = tonumber(major) or 0
			Api.npVersion = tostring(major) .. "." .. tostring(minor or 0) .. "." .. tostring(patch or 0)
		end
	end
	Api.classic = (type(CLASSIC_API_VERSION) == "number")
	Api.classicVersion = Api.classic and CLASSIC_API_VERSION or 0
	local f = Api.feat
	f.guid = Api.superwow or (GetUnitGUID ~= nil)
	f.mouseover = (SetMouseoverUnit ~= nil)
	f.unitEventFilter = Api.classic and Api.classicVersion >= CLASSIC_UNITEVENT
	f.nameplateGuids = (C_NamePlate ~= nil and C_NamePlate.GetNamePlateGUIDs ~= nil)
	f.spellQueue = Api.nampower
end

-- Appele a PLAYER_ENTERING_WORLD : UnitXP est teste ici, et la ligne de vue seulement apres un delai.
function Api.OnWorld()
	Api.unitxp = false
	if UnitXP and (pcall(UnitXP, "nop", "nop")) then
		-- Garde-fou : le UnitXP d'origine (experience) accepte n'importe quels arguments. On exige donc
		-- aussi un horodatage de version numerique, ou une reponse booleenne de "inSight".
		local ok, v = pcall(UnitXP, "version", "coffTimeDateStamp")
		if ok and type(v) == "number" and v > 1000000000 then
			Api.unitxp = true
		else
			local ok2, s = pcall(UnitXP, "inSight", "player", "player")
			Api.unitxp = (ok2 and type(s) == "boolean") and true or false
		end
	end
	Api.sightSafe = false
	Api.sightSafeAt = GetTime() + SIGHT_DELAY
end

local function sightOk()
	if not Api.unitxp then return false end
	if not Api.sightSafe then
		if Api.sightSafeAt and GetTime() >= Api.sightSafeAt then Api.sightSafe = true end
	end
	return Api.sightSafe
end

-- Distance en yards : retourne distance, source ("xp" | "pos" | "band"). En repli, 'band' : 10 / 28 / nil (au-dela).
function Api.Distance(unit)
	if not UnitExists(unit) then return nil, nil end
	if Api.unitxp then
		local ok, d = pcall(UnitXP, "distanceBetween", "player", unit)
		if ok and type(d) == "number" then return d, "xp" end
	end
	if Api.superwow and UnitPosition then
		local ok, x1, y1, z1 = pcall(UnitPosition, "player")
		local ok2, x2, y2, z2 = pcall(UnitPosition, unit)
		if ok and ok2 and x1 and x2 and z1 and z2 then
			local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
			return math.sqrt(dx * dx + dy * dy + dz * dz), "pos"
		end
	end
	if CheckInteractDistance then
		if CheckInteractDistance(unit, 3) then return 10, "band" end
		if CheckInteractDistance(unit, 4) then return 28, "band" end
		return nil, "band"
	end
	return nil, nil
end

function Api.FormatDistance(d, src)
	if src == "xp" or src == "pos" then
		return string.format("%d yd", math.floor(d + 0.5))
	elseif src == "band" then
		if d == 10 then return "<10 yd" end
		if d == 28 then return "10-28 yd" end
		return ">28 yd"
	end
	return ""
end

-- true / false si UnitXP repond, nil sinon.
function Api.InSight(unit)
	if not sightOk() then return nil end
	local ok, v = pcall(UnitXP, "inSight", "player", unit)
	if not ok then return nil end
	if v == nil then return nil end
	return v and true or false
end

-- true si le JOUEUR est derriere 'unit' ; nil si UnitXP absent.
function Api.Behind(unit)
	if not sightOk() then return nil end
	local ok, v = pcall(UnitXP, "behind", "player", unit)
	if not ok or v == nil then return nil end
	return v == true or v == 1   -- l'extension peut repondre un entier
end

function Api.GUID(unit)
	if GetUnitGUID then
		local ok, g = pcall(GetUnitGUID, unit)
		if ok and g then return g end
	end
	if Api.superwow then
		local exists, g = UnitExists(unit)
		if exists and g then return g end
	end
	return nil
end

function Api.SetMouseover(unit)
	if SetMouseoverUnit then
		if unit then pcall(SetMouseoverUnit, unit) else pcall(SetMouseoverUnit) end
	end
end

-- Resume lisible pour /sui status et le message de demarrage.
function Api.Summary()
	local t = {}
	if Api.superwow then table.insert(t, "SuperWoW" .. (Api.swVersion and (" " .. tostring(Api.swVersion)) or "")) end
	if Api.nampower then table.insert(t, "Nampower " .. Api.npVersion) end
	if Api.unitxp then table.insert(t, "UnitXP") end
	if Api.classic then table.insert(t, "ClassicAPI " .. tostring(Api.classicVersion)) end
	if table.getn(t) == 0 then return nil end
	return table.concat(t, ", ")
end

-- Addons Shiki* reconnus (integration par detection, aucune dependance dure).
function Api.Integrations()
	local t = {}
	if ShikiwaRotation then table.insert(t, "ShikiwaRotation") end
	if ShikaSwap then table.insert(t, "ShikaSwap") end
	if ShikiwaSignal then table.insert(t, "ShikiwaSignal") end
	if IsAddOnLoaded and IsAddOnLoaded("ShikiwaHeal") then table.insert(t, "ShikiwaHeal") end
	return t
end
