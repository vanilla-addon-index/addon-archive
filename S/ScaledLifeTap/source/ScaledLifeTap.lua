-- ScaledLifeTap 4.2
-- Original by Kimilly (thanks to Aredia of Gilneas for the macro and research).
-- Casts the highest Life Tap rank whose mana return fits in your missing mana.
--
-- Macro:  /slt cast        (or the old  /script ScaledLifeTap_CastLifeTap()  )

local L = SCALEDLIFETAP_L
local Scanner = ScaledLifeTap_Scanner

-- Base health converted per rank, and spell damage coefficient per rank.
-- Coefficient is 0.8 reduced by the sub-level-20 penalty for ranks 1 (lvl 6) and 2 (lvl 16).
local BASE  = { 30, 75, 140, 220, 310, 424 }
local COEF  = { 0.38, 0.68, 0.8, 0.8, 0.8, 0.8 }

-- Spell ID of each Life Tap rank. With ClassicAPI these find the spellbook slot
-- directly (no rank text or spell name needed) and identify the spell in the combat log.
local RANK_SPELL_IDS = { 1454, 1455, 1456, 11687, 11688, 11689 }
local NUM_RANKS = table.getn(RANK_SPELL_IDS)
local ID_TO_RANK = {}
for r = 1, NUM_RANKS do ID_TO_RANK[RANK_SPELL_IDS[r]] = r end

local DEFAULTS = {
	overtap   = true,     -- cast rank 1 if no rank fits but mana is not full
	debug     = false,
	reserve   = 0,        -- never tap below this % of max health
	bonus     = 0,        -- extra spell damage to add (e.g. elixirs/buffs the scanner can't see)
	source    = "auto",   -- "auto" = ClassicAPI > Nampower > built-in; or force one (incl. bonusscanner)
	calibrate = true,     -- learn a mana correction from the actual mana each tap gives
	gainFactor = 1,
	samples   = 0,
	macroDisplay = true,  -- ClassicAPI: show the rank that would be cast on /slt cast macro buttons
	verifyShown  = false, -- the "spell data disagrees with built-in numbers" notice was shown once
	-- baseOverride = { [rank] = health } is created by /slt verify adopt
}

local spellIndex = {}     -- [rank] = spellbook index
local maxRank = 0
local spellsDirty = true
local talentMult, talentDirty = 1, true

local function msg(text) DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9ScaledLifeTap:|r " .. text) end
local function dbg(text) if SLT_Config and SLT_Config.debug then msg(text) end end

-- Base health for a rank: the built-in table unless /slt verify adopt replaced it.
local function baseOf(r)
	local o = SLT_Config and SLT_Config.baseOverride
	return (o and o[r]) or BASE[r]
end

local function isLifeTapId(id)
	id = tonumber(id)
	return id ~= nil and ID_TO_RANK[id] ~= nil
end

---------------------------------------------------------------------------
-- spellbook / talents (cached, refreshed on events)
---------------------------------------------------------------------------
-- Name scan: works everywhere, depends on the localized spell name and rank text.
local function scanSpellbookByName()
	local i = 1
	while true do
		local name, rankText = GetSpellName(i, BOOKTYPE_SPELL)
		if not name then break end      -- end of spellbook (v3 looped forever here)
		if name == L.LIFETAP then
			local _, _, r = string.find(rankText or "", "(%d+)")
			r = tonumber(r) or 1
			if BASE[r] then
				spellIndex[r] = i
				if r > maxRank then maxRank = r end
			end
		end
		i = i + 1
	end
end

-- ID scan (ClassicAPI): finds each known rank by spell ID. Takes precedence over
-- the name scan for the ranks it finds, so it also works when the name or rank
-- text doesn't match the locale tables.
local function scanSpellbookByID()
	if type(FindSpellBookSlotByID) ~= "function" then return end
	for r = 1, NUM_RANKS do
		local ok, slot, book = pcall(FindSpellBookSlotByID, RANK_SPELL_IDS[r])
		if ok and tonumber(slot) and (book == nil or book == BOOKTYPE_SPELL) then
			spellIndex[r] = tonumber(slot)
			if r > maxRank then maxRank = r end
		end
	end
end

local function scanSpellbook()
	for k in pairs(spellIndex) do spellIndex[k] = nil end
	maxRank = 0
	scanSpellbookByName()
	scanSpellbookByID()
	spellsDirty = false
end

local function scanTalents()
	talentMult = 1
	for tab = 1, (GetNumTalentTabs() or 0) do
		for t = 1, (GetNumTalents(tab) or 0) do
			local name, _, _, _, rank = GetTalentInfo(tab, t)
			if name == L.IMP_LIFETAP then
				talentMult = 1 + 0.1 * (rank or 0)
				talentDirty = false
				return
			end
		end
	end
	talentDirty = false
end

---------------------------------------------------------------------------
-- base health check against the game's own spell data (ClassicAPI)
-- C_Spell.GetSpellDescription gives the base-rank description text, e.g. the
-- "Converts N health into N mana" line, so the first number in it is the base
-- health of that rank. The check only reports; /slt verify adopt applies it.
---------------------------------------------------------------------------
local descCache, descText = {}, {}

local function hasDescription()
	return type(C_Spell) == "table" and type(C_Spell.GetSpellDescription) == "function"
end

local function descBase(r)
	if descCache[r] ~= nil then return descCache[r] or nil, descText[r] end
	if not hasDescription() then return nil end
	local ok, text = pcall(C_Spell.GetSpellDescription, RANK_SPELL_IDS[r])
	if not ok or type(text) ~= "string" or text == "" then return nil end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	local _, _, n = string.find(text, "(%d+)")
	n = tonumber(n)
	descCache[r] = n or false
	descText[r] = text
	return n, text
end

local function verifyBase(adopt)
	if not hasDescription() then
		msg("Checking the numbers needs ClassicAPI (C_Spell.GetSpellDescription).")
		return
	end
	local diffs, readable = 0, 0
	for r = 1, NUM_RANKS do
		local n, text = descBase(r)
		local used = baseOf(r)
		if not n then
			msg(string.format("Rank %d: no readable description", r))
		else
			readable = readable + 1
			if n == used then
				msg(string.format("Rank %d: %d health - OK", r, n))
			else
				diffs = diffs + 1
				msg(string.format("Rank %d: addon uses %d, spell data says %d  (%s)", r, used, n, string.sub(text, 1, 80)))
				if adopt then
					if n >= BASE[r] * 0.5 and n <= BASE[r] * 2 then
						SLT_Config.baseOverride = SLT_Config.baseOverride or {}
						SLT_Config.baseOverride[r] = n
						msg(string.format("  rank %d now uses %d", r, n))
					else
						msg(string.format("  rank %d: %d looks implausible, not adopted", r, n))
					end
				end
			end
		end
	end
	SLT_Config.verifyShown = true
	if readable == 0 then
		msg("No rank description could be read.")
	elseif diffs == 0 then
		msg("Built-in numbers match the spell data.")
	elseif not adopt then
		msg("/slt verify adopt  uses the spell data numbers;  /slt verify reset  goes back to the built-in ones.")
	end
end

-- Once per character: tell the player if the spell data disagrees with the table.
local autoVerified = false
local function autoVerify()
	if autoVerified then return end
	autoVerified = true
	if SLT_Config.verifyShown or not hasDescription() then return end
	local bad = 0
	for r = 1, NUM_RANKS do
		local n = descBase(r)
		if n and n ~= baseOf(r) then bad = bad + 1 end
	end
	if bad > 0 then
		SLT_Config.verifyShown = true
		msg(string.format("The game's spell data disagrees with the built-in Life Tap numbers for %d rank(s). Type /slt verify for details.", bad))
	end
end

---------------------------------------------------------------------------
-- spell damage
---------------------------------------------------------------------------
-- Each source returns (genericDamage, shadowDamage) or nil when unavailable.
-- ClassicAPI and Nampower read the client's own computed shadow spell damage,
-- which already includes gear, enchants, buffs and set bonuses.
local SOURCES = {
	classicapi = function()
		if type(GetSpellBonusDamage) ~= "function" then return nil end
		local ok, v = pcall(GetSpellBonusDamage, 6)          -- 6 = Shadow (1-based)
		if ok and tonumber(v) then return 0, tonumber(v) end
	end,
	nampower = function()
		if type(GetSpellPower) ~= "function" or type(GetNampowerVersion) ~= "function" then return nil end
		local ok, _, _, _, _, _, shadow = pcall(GetSpellPower)  -- 6th value = Shadow
		if ok and tonumber(shadow) then return 0, tonumber(shadow) end
	end,
	bonusscanner = function()
		if not (BonusScanner and BonusScanner.GetBonus and IsAddOnLoaded("BonusScanner")) then return nil end
		return tonumber(BonusScanner:GetBonus("DMG")) or 0, tonumber(BonusScanner:GetBonus("SHADOWDMG")) or 0
	end,
	internal = function() return Scanner:Get() end,
}
local SOURCE_NAMES = { classicapi = "ClassicAPI", nampower = "Nampower", bonusscanner = "BonusScanner", internal = "built-in scanner" }
-- BonusScanner is deliberately not in the auto order: it gives the same totals
-- as the built-in scanner on English clients and likely 0 on German/French ones.
-- It can still be forced with /slt source bonusscanner.
local AUTO_ORDER = { "classicapi", "nampower", "internal" }
local LIVE_SOURCES = { classicapi = true, nampower = true }   -- these already include buffs

function ScaledLifeTap_GetDamageBonus()
	local want = SLT_Config.source or "auto"
	local dmg, shadow, key
	if want ~= "auto" and SOURCES[want] then
		dmg, shadow = SOURCES[want]()
		key = want
	end
	if not dmg then
		for i = 1, table.getn(AUTO_ORDER) do
			key = AUTO_ORDER[i]
			dmg, shadow = SOURCES[key]()
			if dmg then break end
		end
	end
	local total = (dmg or 0) + (shadow or 0) + (SLT_Config.bonus or 0)
	return total, dmg or 0, shadow or 0, SOURCE_NAMES[key], LIVE_SOURCES[key]
end

---------------------------------------------------------------------------
-- mana check: compares predicted mana per Life Tap with what the server
-- actually gave, and learns a correction factor if your server's numbers
-- differ from standard 1.12. The actual amount comes from Nampower's
-- SPELL_ENERGIZE_BY_SELF event or ClassicAPI's combat log (SPELL_ENERGIZE).
---------------------------------------------------------------------------
local lastCast       -- { rank, predicted, time }
local warned = false

local combatLog       -- frame listening to ClassicAPI's combat log, only while a tap is pending

local function stopCombatLog()
	if combatLog then combatLog:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
end

local function onEnergize(spellId, powerType, amount, nameChecked)
	if not lastCast or powerType ~= 0 or not tonumber(amount) then return end
	if GetTime() - lastCast.time > 3 then lastCast = nil; stopCombatLog(); return end
	if not nameChecked then
		if not isLifeTapId(spellId) and type(GetSpellNameAndRankForId) == "function" then
			local ok, name = pcall(GetSpellNameAndRankForId, spellId)
			if not ok or name ~= L.LIFETAP then return end
		end
	end
	local base = lastCast.predicted / (SLT_Config.gainFactor or 1)
	lastCast = nil
	stopCombatLog()
	if base <= 0 or not SLT_Config.calibrate then return end
	local ratio = amount / base
	if ratio < 0.5 or ratio > 2 then return end           -- ignore nonsense
	-- smooth toward the observed ratio
	SLT_Config.gainFactor = (SLT_Config.gainFactor or 1) * 0.7 + ratio * 0.3
	SLT_Config.samples = (SLT_Config.samples or 0) + 1
	if not warned and SLT_Config.samples >= 3 and math.abs(SLT_Config.gainFactor - 1) > 0.03 then
		warned = true
		msg(string.format("Life Tap is giving %d%% of the predicted mana on this server; adjusting automatically (/slt calibrate reset to undo).",
			SLT_Config.gainFactor * 100 + 0.5))
	end
end

-- ClassicAPI combat log. COMBAT_LOG_EVENT_UNFILTERED fires for everything
-- near you, so the frame registers it only after a tap and drops it as soon
-- as the energize arrives (or 3 seconds pass).
local function hasCombatLog()
	return type(CombatLogGetCurrentEventInfo) == "function" and type(UnitGUID) == "function"
end

local function onCombatLog()
	local _, sub, _, src, _, _, _, _, _, _, _, spellId, spellName, _, amount, a16, a17 = CombatLogGetCurrentEventInfo()
	if sub ~= "SPELL_ENERGIZE" then return end
	if not (isLifeTapId(spellId) or spellName == L.LIFETAP) then return end
	if src ~= UnitGUID("player") then return end
	-- raw values after the spell fields, to confirm which one is the power type
	dbg(string.format("energize: amount=%s next=%s next2=%s", tostring(amount), tostring(a16), tostring(a17)))
	onEnergize(spellId, a16, amount, true)
end

local function watchCombatLog()
	if not hasCombatLog() then return end
	if not combatLog then
		combatLog = CreateFrame("Frame")
		combatLog:SetScript("OnEvent", onCombatLog)
	end
	combatLog:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	if C_Timer and C_Timer.After then C_Timer.After(3.5, stopCombatLog) end
end

---------------------------------------------------------------------------
-- rank selection
---------------------------------------------------------------------------
-- returns rank (or nil), hpCost, manaGain
function ScaledLifeTap_ChooseRank()
	if spellsDirty then scanSpellbook() end
	if talentDirty then scanTalents() end
	if maxRank == 0 then return nil end

	local bonus = ScaledLifeTap_GetDamageBonus()
	local mult = talentMult * (SLT_Config.gainFactor or 1)
	local hp = UnitHealth("player")
	local missing = UnitManaMax("player") - UnitMana("player")
	local floor = UnitHealthMax("player") * (SLT_Config.reserve or 0) / 100

	for r = maxRank, 1, -1 do
		if spellIndex[r] then
			local cost = baseOf(r) + COEF[r] * bonus
			local gain = cost * mult
			if hp - cost > floor and missing >= gain then return r, cost, gain, true end
		end
	end

	if SLT_Config.overtap and missing > 0 then
		local r = 1
		while r <= maxRank and not spellIndex[r] do r = r + 1 end
		if spellIndex[r] then
			local cost = baseOf(r) + COEF[r] * bonus
			if hp - cost > floor then return r, cost, cost * mult, false end
		end
	end
	return nil
end

function ScaledLifeTap_CastLifeTap()
	local r, cost, gain, fits = ScaledLifeTap_ChooseRank()
	if r then
		CastSpell(spellIndex[r], BOOKTYPE_SPELL)
		-- only fully-fitting casts are used for the mana check (overtap casts may hit the mana cap)
		if fits and SLT_Config.calibrate then
			lastCast = { rank = r, predicted = gain, time = GetTime() }
			watchCombatLog()
		else
			lastCast = nil
		end
		dbg(string.format("Rank %d: -%d hp, +%d mana", r, cost, gain))
	elseif maxRank == 0 then
		dbg("Life Tap not found in spellbook.")
	else
		dbg("No rank fits (mana full or health too low).")
	end
end

-- backwards compatibility with v3 macros
ScaledLifetap_CastLifeTap = ScaledLifeTap_CastLifeTap
function ScaledLifeTap_Debug(arg)
	if arg == nil then return SLT_Config.debug end
	SLT_Config.debug = (arg == 1 or arg == true)
end

---------------------------------------------------------------------------
-- macro button display (ClassicAPI): macros that contain "/slt cast" show the
-- Life Tap rank that would be cast right now (icon and tooltip), the same way
-- #showtooltip follows a /cast line. Updates are throttled and event driven.
---------------------------------------------------------------------------
local macroSlots = {}     -- macro indexes whose body calls /slt cast
local macroDirty = true
local lastShown           -- rank last published, so unchanged ranks cost nothing
local displayPending = false
local displayBroken = false

local function hasMacroDisplay()
	return type(C_Macro) == "table" and type(C_Macro.SetMacroDisplay) == "function"
end

local function findMacros()
	for k in pairs(macroSlots) do macroSlots[k] = nil end
	if type(GetMacroInfo) == "function" then
		for i = 1, 36 do
			local name, _, body = GetMacroInfo(i)
			if name and body then
				local b = string.lower(body)
				if string.find(b, "/slt cast", 1, true)
					or string.find(b, "/scaledlifetap cast", 1, true)
					or string.find(b, "scaledlifetap_castlifetap", 1, true) then
					table.insert(macroSlots, i)
				end
			end
		end
	end
	macroDirty = false
	lastShown = nil
end

-- Tries the spell ID first, then "Life Tap(Rank N)" built from the spellbook entry.
local function setMacroDisplay(slot, r)
	local ok, res = pcall(C_Macro.SetMacroDisplay, slot, RANK_SPELL_IDS[r])
	if ok and res ~= false then return true end
	if spellIndex[r] then
		local name, rankText = GetSpellName(spellIndex[r], BOOKTYPE_SPELL)
		if name then
			local value = name
			if rankText and rankText ~= "" then value = name .. "(" .. rankText .. ")" end
			ok, res = pcall(C_Macro.SetMacroDisplay, slot, value)
			if ok and res ~= false then return true end
		end
	end
	return false
end

local function publishDisplay()
	displayPending = false
	if displayBroken or not SLT_Config.macroDisplay or not hasMacroDisplay() then return end
	if macroDirty then findMacros() end
	if table.getn(macroSlots) == 0 then return end
	if spellsDirty then scanSpellbook() end
	if maxRank == 0 then return end
	local r = ScaledLifeTap_ChooseRank()
	if not r then r = maxRank end            -- nothing fits (mana full): show the top rank
	if r == lastShown then return end
	local failed = 0
	for i = 1, table.getn(macroSlots) do
		if not setMacroDisplay(macroSlots[i], r) then failed = failed + 1 end
	end
	if failed == table.getn(macroSlots) then
		displayBroken = true
		msg("ClassicAPI did not accept the macro display value; macro button display is off for this session. (/slt macrodisplay off to hide this)")
	else
		lastShown = r
		dbg(string.format("macro display: rank %d on %d macro(s)", r, table.getn(macroSlots) - failed))
	end
end

local function requestDisplay()
	if displayPending or displayBroken or not SLT_Config.macroDisplay or not hasMacroDisplay() then return end
	if not (C_Timer and C_Timer.After) then return end
	displayPending = true
	C_Timer.After(0.3, publishDisplay)
end

---------------------------------------------------------------------------
-- status / slash commands
---------------------------------------------------------------------------
local function onoff(v) return v and "|cff00ff00on|r" or "|cffff0000off|r" end

-- Status as plain lines, shared by /slt status and the options page.
-- summary: spell damage line, multiplier line. ranks: one line per known rank.
local function statusLines()
	if spellsDirty then scanSpellbook() end
	if talentDirty then scanTalents() end
	local total, dmg, shadow, source, live = ScaledLifeTap_GetDamageBonus()
	local summary, ranks = {}, {}
	if live then
		summary[1] = string.format("Spell damage: %d shadow (incl. buffs) + %d manual = %d  [%s]", shadow, SLT_Config.bonus or 0, total, source)
	else
		summary[1] = string.format("Spell damage: %d + %d shadow + %d manual = %d  [%s, gear only]", dmg, shadow, SLT_Config.bonus or 0, total, source)
	end
	local mult = talentMult * (SLT_Config.gainFactor or 1)
	summary[2] = string.format("Improved Life Tap x%.1f, server correction x%.3f (%d samples)",
		talentMult, SLT_Config.gainFactor or 1, SLT_Config.samples or 0)
	if maxRank == 0 then
		ranks[1] = "Life Tap is not in your spellbook."
	end
	for r = maxRank, 1, -1 do
		if spellIndex[r] then
			local cost = baseOf(r) + COEF[r] * total
			table.insert(ranks, string.format("Rank %d: -%d health, +%d mana", r, cost, cost * mult))
		end
	end
	return summary, ranks
end

local function printStatus()
	local summary, ranks = statusLines()
	for i = 1, table.getn(summary) do msg(summary[i]) end
	msg(string.format("overtap %s | reserve %d%% | mana check %s | macro display %s", onoff(SLT_Config.overtap), SLT_Config.reserve or 0, onoff(SLT_Config.calibrate), onoff(SLT_Config.macroDisplay)))
	for i = 1, table.getn(ranks) do msg("  " .. ranks[i]) end
end

---------------------------------------------------------------------------
-- small API for Options.lua
---------------------------------------------------------------------------
ScaledLifeTap = {
	DEFAULTS = DEFAULTS,
	StatusLines = statusLines,
	SourceNames = SOURCE_NAMES,
	IsSourceAvailable = function(key)
		if key == "auto" or key == "internal" then return true end
		return SOURCES[key] and SOURCES[key]() ~= nil
	end,
	IsLiveSource = function()
		local _, _, _, _, live = ScaledLifeTap_GetDamageBonus()
		return live and true or false
	end,
	CanCalibrate = function()
		return type(GetNampowerVersion) == "function" or hasCombatLog()
	end,
	CanMacroDisplay = hasMacroDisplay,
	RefreshMacroDisplay = function()
		lastShown = nil
		macroDirty = true
		displayBroken = false
		requestDisplay()
	end,
	ResetCalibration = function()
		SLT_Config.gainFactor, SLT_Config.samples = 1, 0
		warned = false
	end,
	Rescan = function()
		Scanner:MarkDirty(); spellsDirty = true; talentDirty = true
		lastShown = nil
		requestDisplay()
	end,
}

local function toggleArg(arg, current)
	if arg == "on" then return true elseif arg == "off" then return false end
	return not current
end

SLASH_SCALEDLIFETAP1 = "/slt"
SLASH_SCALEDLIFETAP2 = "/scaledlifetap"
SlashCmdList["SCALEDLIFETAP"] = function(input)
	local _, _, cmd, arg = string.find(string.lower(input or ""), "^%s*(%S*)%s*(.-)%s*$")
	if cmd == "cast" then
		ScaledLifeTap_CastLifeTap()
	elseif cmd == "status" then
		printStatus()
	elseif cmd == "overtap" then
		SLT_Config.overtap = toggleArg(arg, SLT_Config.overtap); msg("overtap " .. onoff(SLT_Config.overtap))
	elseif cmd == "debug" then
		SLT_Config.debug = toggleArg(arg, SLT_Config.debug); msg("debug " .. onoff(SLT_Config.debug))
	elseif cmd == "reserve" and tonumber(arg) then
		local v = math.max(0, math.min(90, tonumber(arg)))
		SLT_Config.reserve = v; msg("health reserve " .. v .. "%")
	elseif cmd == "bonus" and tonumber(arg) then
		SLT_Config.bonus = tonumber(arg); msg("manual spell damage bonus " .. SLT_Config.bonus)
	elseif cmd == "calibrate" and (arg == "on" or arg == "off" or arg == "") then
		SLT_Config.calibrate = toggleArg(arg, SLT_Config.calibrate); msg("mana check " .. onoff(SLT_Config.calibrate))
	elseif cmd == "calibrate" and arg == "reset" then
		ScaledLifeTap.ResetCalibration(); msg("mana correction reset")
	elseif cmd == "source" and (arg == "auto" or SOURCES[arg]) then
		SLT_Config.source = arg; Scanner:MarkDirty(); msg("damage source " .. arg)
	elseif cmd == "verify" and (arg == "" or arg == "adopt") then
		verifyBase(arg == "adopt")
		if arg == "adopt" then lastShown = nil; requestDisplay() end
	elseif cmd == "verify" and arg == "reset" then
		SLT_Config.baseOverride = nil; lastShown = nil; msg("Life Tap base numbers reset to the built-in table"); requestDisplay()
	elseif cmd == "macrodisplay" and (arg == "on" or arg == "off" or arg == "") then
		SLT_Config.macroDisplay = toggleArg(arg, SLT_Config.macroDisplay)
		msg("macro button display " .. onoff(SLT_Config.macroDisplay))
		if SLT_Config.macroDisplay then ScaledLifeTap.RefreshMacroDisplay() end
		if not hasMacroDisplay() then msg("(needs ClassicAPI; nothing happens without it)") end
	elseif cmd == "rescan" then
		ScaledLifeTap.Rescan(); printStatus()
	elseif cmd == "options" or cmd == "config" then
		if ScaledLifeTap.OpenOptions then ScaledLifeTap.OpenOptions() end
	else
		msg("commands:  (or open the options window with /slt options)")
		msg("  /slt cast  - cast the best Life Tap rank (put this in a macro)")
		msg("  /slt status  - show bonus, talent and per-rank numbers")
		msg("  /slt overtap [on|off]  - fall back to rank 1 when no rank fits (" .. onoff(SLT_Config.overtap) .. ")")
		msg("  /slt reserve <0-90>  - never tap below this % health (" .. (SLT_Config.reserve or 0) .. "%)")
		msg("  /slt bonus <n>  - extra spell damage to add, e.g. from elixirs (" .. (SLT_Config.bonus or 0) .. ")")
		msg("  /slt source auto|classicapi|nampower|bonusscanner|internal  - where spell damage comes from (" .. SLT_Config.source .. ")")
		msg("  /slt calibrate [on|off|reset]  - learn actual mana per tap (needs Nampower or ClassicAPI) (" .. onoff(SLT_Config.calibrate) .. ")")
		msg("  /slt verify [adopt|reset]  - compare the base health numbers with the game's spell data (needs ClassicAPI)")
		msg("  /slt macrodisplay [on|off]  - show the rank on /slt cast macro buttons (needs ClassicAPI) (" .. onoff(SLT_Config.macroDisplay) .. ")")
		msg("  /slt debug [on|off]  - print each cast (" .. onoff(SLT_Config.debug) .. ")")
		msg("  /slt rescan  - force a gear/spellbook/talent rescan")
		msg("  /slt options  - open the options window")
	end
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
SLT_Config = SLT_Config or {}

local f = CreateFrame("Frame", "ScaledLifeTapEventFrame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:RegisterEvent("CHARACTER_POINTS_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_MACROS")
f:RegisterEvent("UNIT_MANA")
f:RegisterEvent("UNIT_MAXMANA")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
-- Nampower custom event (registering it enables it on Nampower 4.5+; older
-- versions need  /run SetCVar("NP_EnableSpellEnergizeEvents","1")  ). Harmless otherwise.
pcall(f.RegisterEvent, f, "SPELL_ENERGIZE_BY_SELF")
f:SetScript("OnEvent", function()
	if event == "SPELL_ENERGIZE_BY_SELF" then
		onEnergize(arg3, arg4, arg5)
	elseif event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		if arg1 == "player" then requestDisplay() end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if arg1 == "player" then Scanner:MarkDirty(); requestDisplay() end
	elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
		spellsDirty = true
		requestDisplay()
	elseif event == "CHARACTER_POINTS_CHANGED" then
		talentDirty = true
		requestDisplay()
	elseif event == "UPDATE_MACROS" then
		macroDirty = true
		requestDisplay()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Scanner:MarkDirty(); spellsDirty = true; talentDirty = true
		macroDirty = true
		autoVerify()
		requestDisplay()
	elseif event == "VARIABLES_LOADED" then
		if type(SLT_Config) ~= "table" then SLT_Config = {} end
		-- v3 stored "overtapEnabled"
		if SLT_Config.overtapEnabled ~= nil and SLT_Config.overtap == nil then
			SLT_Config.overtap = SLT_Config.overtapEnabled
		end
		SLT_Config.overtapEnabled = nil
		for k, v in pairs(DEFAULTS) do
			if SLT_Config[k] == nil then SLT_Config[k] = v end
		end
	end
end)

-- make sure defaults exist even before VARIABLES_LOADED (e.g. when loaded late)
for k, v in pairs(DEFAULTS) do if SLT_Config[k] == nil then SLT_Config[k] = v end end
