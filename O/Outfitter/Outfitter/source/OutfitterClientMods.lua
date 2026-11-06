-- OutfitterClientMods.lua
--
-- Optional integration with 1.12.1 client mods. Every helper here has a
-- plain-vanilla fallback, so Outfitter behaves exactly as before when no
-- client mod is installed.
--
--   SuperWoW   : UnitBuff() 3rd return = aura spell ID, IsMounted(),
--                IsSwimming(), UnitExists() 2nd return = GUID
--   ClassicAPI : C_UnitAuras.GetAuraDataByIndex() (spellId + name),
--                IsMounted(), IsSwimming(), UnitGUID()
--   Nampower   : detected and reported only. Its item/cast/spell-queue API
--                has no task inside Outfitter that it does better.
--   UnitXP SP3 : detected and reported only. Distance, line of sight and
--                camera functions have no use in an equipment manager.
--
-- Lua 5.0 (no select(), no #, no varargs expressions).

Outfitter_ClientMods = {
	SuperWoW = false,
	ClassicAPI = false,
	Nampower = false,
	UnitXP = false,
	Detected = false,
};

local OCM = Outfitter_ClientMods;

function Outfitter_DetectClientMods()
	OCM.SuperWoW = (SUPERWOW_VERSION ~= nil) or (SUPERWOW_STRING ~= nil);

	OCM.ClassicAPI = (CLASSIC_API_VERSION ~= nil)
			or (type(C_UnitAuras) == "table" and type(C_UnitAuras.GetAuraDataByIndex) == "function");

	OCM.Nampower = type(GetNampowerVersion) == "function";

	OCM.UnitXP = false;
	if type(UnitXP) == "function" then
		-- UnitXP("nop", "nop") is the documented presence check; it raises if the dll is missing
		local vOK = pcall(UnitXP, "nop", "nop");
		OCM.UnitXP = vOK and true or false;
	end

	-- Capabilities actually used by Outfitter

	OCM.HasIsMounted = type(IsMounted) == "function" and (OCM.SuperWoW or OCM.ClassicAPI);
	OCM.HasIsSwimming = type(IsSwimming) == "function" and (OCM.SuperWoW or OCM.ClassicAPI);
	OCM.HasAuraSpellID = OCM.SuperWoW or OCM.ClassicAPI;
	OCM.HasGUID = OCM.SuperWoW or (OCM.ClassicAPI and type(UnitGUID) == "function");

	OCM.Detected = true;
end

-- Returns texture, spellID[, name] for the player's buff at pIndex (1-based).
-- spellID is nil when no client mod provides it.

function Outfitter_GetPlayerBuffInfo(pIndex)
	if OCM.SuperWoW then
		local vTexture, vCount, vSpellID = UnitBuff("player", pIndex);
		return vTexture, vSpellID;
	end

	if OCM.ClassicAPI then
		local vTexture = UnitBuff("player", pIndex);

		if not vTexture then
			return nil;
		end

		local vOK, vData = pcall(C_UnitAuras.GetAuraDataByIndex, "player", pIndex, "HELPFUL");

		if vOK and type(vData) == "table" then
			-- name lets the caller confirm the two APIs agree on this index
			return vTexture, vData.spellId, vData.name;
		end

		return vTexture, nil;
	end

	return UnitBuff("player", pIndex), nil;
end

-- Returns true/false when a client mod can answer, nil when unknown

function Outfitter_ClientIsMounted()
	if not OCM.HasIsMounted then
		return nil;
	end

	local vOK, vResult = pcall(IsMounted);

	if not vOK then
		return nil;
	end

	return vResult and vResult ~= 0 and true or false;
end

function Outfitter_ClientIsSwimming()
	if not OCM.HasIsSwimming then
		return nil;
	end

	local vOK, vResult = pcall(IsSwimming);

	if not vOK then
		return nil;
	end

	return vResult and vResult ~= 0 and true or false;
end

-- Stable identity for a unit: GUID when available, otherwise name..level

function Outfitter_GetUnitIdentity(pUnit)
	if not UnitExists(pUnit) then
		return nil;
	end

	if OCM.ClassicAPI and type(UnitGUID) == "function" then
		local vOK, vGUID = pcall(UnitGUID, pUnit);

		if vOK and vGUID then
			return vGUID;
		end
	end

	if OCM.SuperWoW then
		local vExists, vGUID = UnitExists(pUnit);

		if vGUID then
			return vGUID;
		end
	end

	return (UnitName(pUnit) or "?") .. ":" .. (UnitLevel(pUnit) or 0);
end

function Outfitter_ClientModsSummary()
	if not OCM.Detected then
		Outfitter_DetectClientMods();
	end

	local function YesNo(pValue)
		if pValue then
			return GREEN_FONT_COLOR_CODE .. "yes" .. FONT_COLOR_CODE_CLOSE;
		end
		return GRAY_FONT_COLOR_CODE .. "no" .. FONT_COLOR_CODE_CLOSE;
	end

	DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE .. "Outfitter client mod support:" .. FONT_COLOR_CODE_CLOSE);
	DEFAULT_CHAT_FRAME:AddMessage("  SuperWoW: " .. YesNo(OCM.SuperWoW) .. "   ClassicAPI: " .. YesNo(OCM.ClassicAPI)
			.. "   Nampower: " .. YesNo(OCM.Nampower) .. "   UnitXP SP3: " .. YesNo(OCM.UnitXP));
	DEFAULT_CHAT_FRAME:AddMessage("  Mount detection: " .. (OCM.HasIsMounted and "client flag" or "buff tooltip text"));
	DEFAULT_CHAT_FRAME:AddMessage("  Swimming detection: " .. (OCM.HasIsSwimming and "client flag (surface + underwater)" or "breath timer (underwater only)"));
	DEFAULT_CHAT_FRAME:AddMessage("  Buff tooltip scans: " .. (OCM.HasAuraSpellID and "cached per spell ID" or "every aura change"));
	DEFAULT_CHAT_FRAME:AddMessage("  Target identity: " .. (OCM.HasGUID and "GUID" or "name + level"));
end
