------------------------------------------------------
-- MetaHunt — Unified SavedVariables schema + migration engine
------------------------------------------------------
-- PURPOSE
--   Collapse every legacy / scattered SavedVariable into just TWO persisted
--   globals and one consistent shape, so old-addon names (FOM_*, ZHunterMod_Saved,
--   MTHSmartAmmo) and ad-hoc key styles disappear.
--
-- TARGET SHAPE (canonical)
--   MTH_SavedVariables (account-wide) = {
--     schemaVersion = <MTH_SV_SCHEMA_VERSION>,
--     modules = {
--       <id> = { schemaVersion = N, settings = { ...camelCase... }, <dataTables> },
--       feedomatic = { settings{...}, foodQuality, cooking, questFood,
--                      addedFoods, removedFoods, localeInfo },
--     },
--     messages = {...}, moduleStates = {...}, profiles = {...},
--     charSnapshots = {...}, versionCheck = {...},
--   }
--   MTH_CharSavedVariables (per-character) = {
--     schemaVersion = <MTH_SV_SCHEMA_VERSION>,
--     modules = {
--       <id> = { schemaVersion = N, settings{...}, <dataTables> },
--       zhunter = { buttons{...}, bar{...}, widgetSpawnLayout },
--       antidaze = { settings{ enabled } },
--       autostrip = { settings{ enabled, display }, frame{ point, relativePoint, x, y } },
--       minimapbutton = { settings{ angle } },
--     },
--     moduleStates = {...},
--     -- pet-system core stays at root (out of scope, heavily referenced):
--     MTH_Pets, feedTracking, petTraining, trainScan, stableScan, petSpellScan,
--   }
--
-- RULES
--   * One-shot, gated by schemaVersion on each root. Idempotent. Non-destructive
--     (data is COPIED into the new location before the old location is cleared).
--   * Lua 5.0-safe (no '#', no string.match/gmatch; pairs()/ipairs() only).
--   * Testable offline: MTH_SV_EnsureSchema(account, char) accepts explicit roots
--     (defaults to the live globals) and returns a report table.
------------------------------------------------------

MTH_SV_SCHEMA_VERSION = 1

------------------------------------------------------
-- Helpers
------------------------------------------------------

local function MTH_SV_IsTable(v)
	return type(v) == "table"
end

local function MTH_SV_DeepCopy(orig)
	if type(orig) ~= "table" then
		return orig
	end
	local copy = {}
	for k, v in pairs(orig) do
		copy[MTH_SV_DeepCopy(k)] = MTH_SV_DeepCopy(v)
	end
	return copy
end

-- Ensure parent[key] is a table and return it.
local function MTH_SV_Ensure(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

-- Pick the first non-nil value from a list of candidates; else default.
local function MTH_SV_Coalesce(candidates, default)
	for _, v in ipairs(candidates) do
		if v ~= nil then
			return v
		end
	end
	return default
end

-- Copy every key from src into dst, applying a rename map (oldKey -> newKey).
-- Keys not present in the map keep their original name. Existing dst values win
-- (so re-running never clobbers already-migrated data). Returns count copied.
local function MTH_SV_CopyRenamed(src, dst, renameMap)
	local moved = 0
	if not MTH_SV_IsTable(src) then
		return moved
	end
	for oldKey, value in pairs(src) do
		local newKey = (renameMap and renameMap[oldKey]) or oldKey
		if dst[newKey] == nil then
			dst[newKey] = value
			moved = moved + 1
		end
	end
	return moved
end

-- Count entries in a table (Lua 5.0-safe).
local function MTH_SV_Count(t)
	local n = 0
	if MTH_SV_IsTable(t) then
		for _ in pairs(t) do
			n = n + 1
		end
	end
	return n
end

------------------------------------------------------
-- Per-module migrators
-- Each takes the relevant module store table (already ensured) plus context,
-- transforms in place, and records notes into the shared report.
------------------------------------------------------

-- SMARTAMMO (per-character)
--   OLD: modules.smartammo = { enabled, smartEnabled, reloadEnabled,
--                              weaponSwapEnabled, legacy = { MTHSmartAmmo = {
--                              enabled, reload, weaponSwap } } }
--        + optional global MTHSmartAmmo = { enabled, reload, weaponSwap }
--   NEW: modules.smartammo = { schemaVersion, settings = {
--                              smartEnabled, reloadEnabled, weaponSwapEnabled } }
local function MTH_SV_Migrate_SmartAmmo(store, globalMTHSmartAmmo, report)
	if not MTH_SV_IsTable(store) then
		return
	end
	local legacy = MTH_SV_IsTable(store.legacy) and store.legacy.MTHSmartAmmo or nil
	local g = MTH_SV_IsTable(globalMTHSmartAmmo) and globalMTHSmartAmmo or nil

	local settings = MTH_SV_Ensure(store, "settings")

	-- smartEnabled: modern flat -> settings -> legacy.enabled -> global.enabled -> old `enabled` -> true
	if settings.smartEnabled == nil then
		settings.smartEnabled = MTH_SV_Coalesce({
			store.smartEnabled,
			legacy and legacy.enabled,
			g and g.enabled,
			store.enabled,
		}, true) and true or false
	end
	if settings.reloadEnabled == nil then
		settings.reloadEnabled = MTH_SV_Coalesce({
			store.reloadEnabled,
			legacy and legacy.reload,
			g and g.reload,
		}, true) and true or false
	end
	if settings.weaponSwapEnabled == nil then
		settings.weaponSwapEnabled = MTH_SV_Coalesce({
			store.weaponSwapEnabled,
			legacy and legacy.weaponSwap,
			g and g.weaponSwap,
		}, true) and true or false
	end

	-- Clear the old flat/legacy shape now that settings holds the truth.
	store.legacy = nil
	store.enabled = nil
	store.smartEnabled = nil
	store.reloadEnabled = nil
	store.weaponSwapEnabled = nil
	store.schemaVersion = 1

	report.smartammo = "settings{smartEnabled=" .. tostring(settings.smartEnabled)
		.. ",reloadEnabled=" .. tostring(settings.reloadEnabled)
		.. ",weaponSwapEnabled=" .. tostring(settings.weaponSwapEnabled) .. "}"
end

-- AUTOQUEST (per-character)
--   OLD (canonical): MTH_CharSavedVariables.autoquest = { scorpokDrazial,
--        arrowsForSissies, scorpokTooltip, _migrated } mirrored into
--        modules.autoquest = { scorpokDrazial, arrowsForSissies, scorpokTooltip, enabled }
--        plus oldest legacy MTH_CharSavedVariables.questautomation.
--   NEW: modules.autoquest = { schemaVersion, settings = {
--        scorpokDrazial, arrowsForSissies, scorpokTooltip } }
local function MTH_SV_Migrate_AutoQuest(char, report)
	local modules = MTH_SV_Ensure(char, "modules")
	local store = MTH_SV_Ensure(modules, "autoquest")
	local settings = MTH_SV_Ensure(store, "settings")

	local root = MTH_SV_IsTable(char.autoquest) and char.autoquest or {}
	local qa = MTH_SV_IsTable(char.questautomation) and char.questautomation or {}

	local keys = { "scorpokDrazial", "arrowsForSissies", "scorpokTooltip" }
	for _, k in ipairs(keys) do
		if settings[k] == nil then
			settings[k] = MTH_SV_Coalesce({
				store[k], -- flat mirror on modules.autoquest
				root[k],  -- former canonical root .autoquest
				qa[k],    -- oldest legacy .questautomation
			}, false) and true or false
		end
	end

	-- Clear old / duplicate locations.
	store.scorpokDrazial = nil
	store.arrowsForSissies = nil
	store.scorpokTooltip = nil
	store._migrated = nil
	char.autoquest = nil
	char.questautomation = nil
	store.schemaVersion = 1

	report.autoquest = "settings{scorpokDrazial=" .. tostring(settings.scorpokDrazial)
		.. ",arrowsForSissies=" .. tostring(settings.arrowsForSissies)
		.. ",scorpokTooltip=" .. tostring(settings.scorpokTooltip) .. "}"
end

-- ANTIDAZE (per-character): char-root .antiDaze{enabled} -> modules.antidaze.settings{enabled}
local function MTH_SV_Migrate_AntiDaze(char, report)
	local modules = MTH_SV_Ensure(char, "modules")
	local store = MTH_SV_Ensure(modules, "antidaze")
	local settings = MTH_SV_Ensure(store, "settings")
	local old = MTH_SV_IsTable(char.antiDaze) and char.antiDaze or {}
	if settings.enabled == nil and old.enabled ~= nil then
		settings.enabled = old.enabled and true or false
	end
	char.antiDaze = nil
	store.schemaVersion = 1
	report.antidaze = "settings{enabled=" .. tostring(settings.enabled) .. "}"
end

-- AUTOSTRIP (per-character): char-root .autoStrip{autostrip,display,point,relativePoint,x,y}
--   -> modules.autostrip{autostrip,display,point,relativePoint,x,y}
--   (keys preserved verbatim; only the storage location moves under .modules)
local function MTH_SV_Migrate_AutoStrip(char, report)
	local modules = MTH_SV_Ensure(char, "modules")
	local store = MTH_SV_Ensure(modules, "autostrip")
	local old = MTH_SV_IsTable(char.autoStrip) and char.autoStrip or {}
	local carry = { "autostrip", "display", "point", "relativePoint", "x", "y" }
	for _, k in ipairs(carry) do
		if store[k] == nil and old[k] ~= nil then
			store[k] = old[k]
		end
	end
	char.autoStrip = nil
	store.schemaVersion = 1
	report.autostrip = "store{autostrip=" .. tostring(store.autostrip)
		.. ",display=" .. tostring(store.display) .. "}"
end

-- MINIMAPBUTTON (per-character): char-root .minimapButton{angle} -> modules.minimapbutton{angle}
local function MTH_SV_Migrate_MinimapButton(char, report)
	local modules = MTH_SV_Ensure(char, "modules")
	local store = MTH_SV_Ensure(modules, "minimapbutton")
	local old = MTH_SV_IsTable(char.minimapButton) and char.minimapButton or {}
	if store.angle == nil and old.angle ~= nil then
		store.angle = old.angle
	end
	char.minimapButton = nil
	store.schemaVersion = 1
	report.minimapbutton = "store{angle=" .. tostring(store.angle) .. "}"
end

-- FEEDOMATIC (account-wide): the 7 old FeedOMatic globals were stored under
--   modules.feedomatic.legacy.FOM_* (with _G.FOM_* bound as runtime aliases) and
--   duplicated at the account-root alias MTH_SavedVariables.feedomatic.
--   NEW: modules.feedomatic = { schemaVersion, settings, foodQuality, addedFoods,
--        removedFoods, cooking, questFood, localeInfo } — no .legacy wrapper, no root
--        alias. The _G.FOM_* globals stay as RUNTIME aliases (re-bound to these nested
--        tables by MTH_FeedOMatic_SyncSavedVariables) so FeedOMatic.lua is untouched.
local MTH_SV_FOM_MAP = {
	{ global = "FOM_Config", key = "settings" },
	{ global = "FOM_FoodQuality", key = "foodQuality" },
	{ global = "FOM_AddedFoods", key = "addedFoods" },
	{ global = "FOM_RemovedFoods", key = "removedFoods" },
	{ global = "FOM_Cooking", key = "cooking" },
	{ global = "FOM_QuestFood", key = "questFood" },
	{ global = "FOM_LocaleInfo", key = "localeInfo" },
}

local function MTH_SV_Migrate_FeedOMatic(account, report)
	local modules = MTH_SV_Ensure(account, "modules")
	local store = MTH_SV_Ensure(modules, "feedomatic")
	local legacy = MTH_SV_IsTable(store.legacy) and store.legacy or {}

	for _, m in ipairs(MTH_SV_FOM_MAP) do
		if store[m.key] == nil then
			local src = legacy[m.global]
			if type(src) ~= "table" and _G then
				src = _G[m.global]
			end
			if type(src) == "table" then
				store[m.key] = src
			end
		end
	end

	store.legacy = nil
	account.feedomatic = nil -- drop the account-root alias duplicate
	store.schemaVersion = 1
	report.feedomatic = "keys{settings,foodQuality,addedFoods,removedFoods,cooking,questFood,localeInfo}"
end

-- ZHUNTER (per-character): the zButton layout used to live in the TOC-declared
--   global ZHunterMod_Saved AND was mirrored into modules.zhunter (two on-disk
--   copies). NEW: modules.zhunter is the single canonical store (button tables,
--   _zbar, enabled, _mth_widget_spawn_layout_v1). ZHunterMod_Saved becomes a pure
--   RUNTIME alias re-bound by MTH_ZH_GetSavedRoot, and is dropped from the TOC.
--   The vestigial account-root alias MTH_SavedVariables.zhunter is removed too.
local function MTH_SV_Migrate_ZHunter(account, char, report)
	local modules = MTH_SV_Ensure(char, "modules")
	local store = MTH_SV_Ensure(modules, "zhunter")

	-- If the nested store is still empty but a per-char global carries data
	-- (legacy TOC copy present during the transition), adopt it once.
	if _G and MTH_SV_IsTable(_G.ZHunterMod_Saved) and _G.ZHunterMod_Saved ~= store then
		if MTH_SV_Count(store) == 0 then
			for k, v in pairs(_G.ZHunterMod_Saved) do
				store[k] = v
			end
		end
	end

	account.zhunter = nil -- drop the vestigial account-root alias duplicate
	report.zhunter = "modules.zhunter canonical; ZHunterMod_Saved -> runtime alias"
end

------------------------------------------------------
-- Orchestrator
------------------------------------------------------

-- MTH_SV_EnsureSchema(account, char)
--   account / char default to the live globals. Returns a report table.
--   Gated by schemaVersion on each root so it only runs once; idempotent anyway.
function MTH_SV_EnsureSchema(account, char)
	if account == nil then account = MTH_SavedVariables end
	if char == nil then char = MTH_CharSavedVariables end

	local report = { ran = false }

	if not MTH_SV_IsTable(account) or not MTH_SV_IsTable(char) then
		report.error = "roots unavailable"
		return report
	end

	local accountDone = (tonumber(account.schemaVersion) or 0) >= MTH_SV_SCHEMA_VERSION
	local charDone = (tonumber(char.schemaVersion) or 0) >= MTH_SV_SCHEMA_VERSION
	if accountDone and charDone then
		report.skipped = true
		return report
	end
	report.ran = true

	local accountModules = MTH_SV_Ensure(account, "modules")
	local charModules = MTH_SV_Ensure(char, "modules")

	-- Detect whether there is genuine legacy data to relocate BEFORE the migrators
	-- consume/delete it. On a brand-new install there is nothing to move, so we still
	-- stamp the schema (to avoid re-checking) but skip the player-facing announcement.
	local smartLegacy = MTH_SV_IsTable(charModules.smartammo) and charModules.smartammo.legacy or nil
	local feedLegacy = MTH_SV_IsTable(accountModules.feedomatic) and accountModules.feedomatic.legacy or nil
	report.changed = (account.feedomatic ~= nil)
		or (account.zhunter ~= nil)
		or (char.antiDaze ~= nil)
		or (char.autoStrip ~= nil)
		or (char.minimapButton ~= nil)
		or (char.autoquest ~= nil)
		or (char.questautomation ~= nil)
		or (feedLegacy ~= nil)
		or (smartLegacy ~= nil)
		or (_G ~= nil and (_G.FOM_Config ~= nil or _G.ZHunterMod_Saved ~= nil or _G.MTHSmartAmmo ~= nil))
		or false

	-- ---- account-wide modules ----
	MTH_SV_Migrate_FeedOMatic(account, report)

	-- ---- per-character modules ----
	MTH_SV_Migrate_SmartAmmo(
		MTH_SV_Ensure(charModules, "smartammo"),
		_G and _G.MTHSmartAmmo or nil,
		report
	)
	if _G then _G.MTHSmartAmmo = nil end

	MTH_SV_Migrate_AutoQuest(char, report)
	MTH_SV_Migrate_AntiDaze(char, report)
	MTH_SV_Migrate_AutoStrip(char, report)
	MTH_SV_Migrate_MinimapButton(char, report)
	MTH_SV_Migrate_ZHunter(account, char, report)

	-- ---- stamp ----
	account.schemaVersion = MTH_SV_SCHEMA_VERSION
	char.schemaVersion = MTH_SV_SCHEMA_VERSION

	-- ---- player-facing announcement (only when real legacy data was relocated) ----
	-- Guarded on MTH_Log so the offline test harness (no MetaHunt runtime) stays silent.
	if report.changed and type(MTH_Log) == "function" then
		local order = {
			"feedomatic", "smartammo", "autoquest",
			"antidaze", "autostrip", "minimapbutton", "zhunter",
		}
		local done = {}
		for _, id in ipairs(order) do
			if report[id] ~= nil then
				table.insert(done, id)
			end
		end
		MTH_Log("Tidying your saved settings into the new 2.0 layout (one-time)...")
		if table.getn(done) > 0 then
			MTH_Log("  consolidated: " .. table.concat(done, ", "))
		end
		MTH_Log("Saved-settings cleanup complete. Your options were carried over unchanged.")
	end

	return report
end

------------------------------------------------------
-- Load trigger
------------------------------------------------------
-- Run the migration exactly once, AFTER WoW has loaded MetaHunt's SavedVariables
-- from disk. ADDON_LOADED with arg1 == "MetaHunt" is the earliest point at which the
-- real account + per-character saved data is actually available. Running it any earlier
-- (e.g. from a top-level MTH:InitSavedVariables() at file-load) operates on the empty
-- default tables WoW then overwrites when it loads the SV file — which is exactly why
-- the migration used to re-announce every login and /reload. CreateFrame is guarded so
-- the offline test harness (no WoW API) simply skips this.
local MTH_SV_LoadFrame = CreateFrame and CreateFrame("Frame")
if MTH_SV_LoadFrame then
	MTH_SV_LoadFrame:RegisterEvent("ADDON_LOADED")
	MTH_SV_LoadFrame:SetScript("OnEvent", function()
		if event ~= "ADDON_LOADED" or arg1 ~= "MetaHunt" then
			return
		end
		MTH_SV_LoadFrame:UnregisterEvent("ADDON_LOADED")
		if MTH and MTH.InitSavedVariables then
			MTH:InitSavedVariables()
		end
		if type(MTH_SV_EnsureSchema) == "function" then
			MTH_SV_EnsureSchema(MTH_SavedVariables, MTH_CharSavedVariables)
		end
	end)
end
