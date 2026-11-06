-- TargetFrameBuff: up to 32 buffs above and 16 debuffs below the default target
-- frame. With ClassicAPI it also adds countdowns, stack counts, removable-buff
-- highlights and optional cooldown sweeps. Version and author live in the .toc.

local lOriginal_TargetDebuffButton_Update = nil;
local TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS = 16;
local TARGETFRAMEBUFF_MAX_TARGET_BUFFS = 32;

-- Follow the client font so localized clients keep readable glyphs.
local TARGETFRAMEBUFF_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF";

-- How often the countdowns refresh, in seconds.
local TARGETFRAMEBUFF_TIMER_INTERVAL = 0.2;

local lBuffButtons = {};
local lDebuffButtons = {};
local lTimerElapsed = 0;
local lAuraElapsed = 0;
local lHasAuraDelta = false;
local lActiveTimers = {};
local lActiveTimerCount = 0;
local TargetFrameBuff_UpdateTimer;
-- Catch refreshes that change timing without a UNIT_AURA event.
local TARGETFRAMEBUFF_AURA_INTERVAL = 0.5;
local lHelpfulSlots = {};
local lHarmfulSlots = {};
local lRemovableColor = {r = 1, g = 0.82, b = 0};

-- Test mode (/tfb test): fake auras on whatever you are targeting, for checking
-- layout, timers, stacks and borders. Lasts until turned off or /reload.
local lTestMode = false;
local lTestBuffs = 32;
local lTestDebuffs = 16;
local lTestStart = 0;
local lTestElapsed = 0;
local TEST_ICONS = {
	"Interface\\Icons\\Spell_Holy_WordFortitude", "Interface\\Icons\\Spell_Nature_Regeneration",
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_FlameBolt",
	"Interface\\Icons\\Spell_Frost_FrostArmor02", "Interface\\Icons\\Spell_Nature_Slow",
	"Interface\\Icons\\Ability_Rogue_Rupture", "Interface\\Icons\\Spell_Holy_PowerWordShield"
};
local TEST_TYPES = {"Magic", "Curse", "Disease", "Poison"};
-- Mixed lengths so seconds, minutes, hours and the red warning all appear.
local TEST_DURATIONS = {10, 18, 45, 90, 300, 900, 1800, 3600, 7200};

-- Lua 5.0 has no % operator.
local function TargetFrameBuff_Mod(a, b)
	return a - b * math.floor(a / b);
end

-- Same values as UnitAura: name, icon, count, dispelType, duration, expiration,
-- source, removable. Each aura restarts when its time runs out.
local function TargetFrameBuff_TestAura(pass, index)
	local duration = TEST_DURATIONS[TargetFrameBuff_Mod(index * 2, table.getn(TEST_DURATIONS)) + 1];
	local expiration = lTestStart + duration * (math.floor((GetTime() - lTestStart) / duration) + 1);
	local count = 1;
	if (TargetFrameBuff_Mod(index, 4) == 0) then count = TargetFrameBuff_Mod(index, 7) + 2; end
	local dispelType = nil;
	if (pass == 2) then dispelType = TEST_TYPES[TargetFrameBuff_Mod(index, 5) + 1]; end
	local icon = TEST_ICONS[TargetFrameBuff_Mod(index, table.getn(TEST_ICONS)) + 1];
	return "Test aura "..index, icon, count, dispelType, duration, expiration, "player",
		(pass == 1 and TargetFrameBuff_Mod(index, 5) == 0);
end

local function TargetFrameBuff_Setting(key)
	if (TargetFrameBuffDB and TargetFrameBuffDB[key] ~= nil) then
		return TargetFrameBuffDB[key];
	end
	return TargetFrameBuffDefaults[key];
end


-- ClassicAPI (a 1.12 client DLL) backports C_UnitAuras, which reports when
-- each aura on the target expires. Without it, the addon works as before,
-- just without countdowns.
local function TargetFrameBuff_HasClassicAPI()
	return C_UnitAuras and C_UnitAuras.UnitAura and GameTooltip.SetUnitAura and true;
end


-- Tooltip for an aura read through ClassicAPI. auraIndex and auraFilter are in
-- ClassicAPI's HELPFUL/HARMFUL index space, so the tooltip always matches the
-- icon, even for a debuff the server parked in a buff slot.
local function TargetFrameBuff_AuraOnEnter()
	TargetFrameBuff_UpdateClassicAPI();
	if (not this.auraIndex) then GameTooltip:Hide(); return; end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 15, -25);
	if (lTestMode) then
		GameTooltip:SetText("Test "..(this.auraFilter == "HARMFUL" and "debuff " or "buff ")..this.auraIndex);
	else
		GameTooltip:SetUnitAura("target", this.auraIndex, this.auraFilter);
	end
	GameTooltip:Show();
end


-- Add a countdown label to a button. It sits on its own child frame, one level
-- above the button, so it draws over the icon and the debuff border.
local function TargetFrameBuff_AddTimer(button)
	local holder = CreateFrame("Frame", nil, button);
	holder:SetAllPoints(button);
	holder:SetFrameLevel(button:GetFrameLevel() + 2);

	local timer = holder:CreateFontString(nil, "OVERLAY");
	timer:SetFont(TARGETFRAMEBUFF_FONT, 9, "OUTLINE");
	timer:SetPoint("CENTER", button, "CENTER", 0, 0);
	timer:Hide();

	if (not button.auraCount) then
		button.auraCount = holder:CreateFontString(nil, "OVERLAY");
		button.auraCount:SetFont(TARGETFRAMEBUFF_FONT, 9, "OUTLINE");
		button.auraCount:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1);
		button.auraCount:Hide();
		local stockCount = getglobal(button:GetName().."Count");
		if (stockCount) then stockCount:Hide(); end
	end
	button.timer = timer;
	button.timerText = nil;
	button.expiration = 0;
end


-- hook original update-function
function TargetFrameBuff_OnLoad()
	local i, button, overlay;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		lBuffButtons[i] = getglobal("TargetFrameBuff"..i);
		button = lBuffButtons[i];
		overlay = CreateFrame("Frame", nil, button);
		overlay:SetAllPoints(button);
		overlay:SetFrameLevel(button:GetFrameLevel() + 2);
		button.auraCount = overlay:CreateFontString(nil, "OVERLAY");
		button.auraCount:SetFont(TARGETFRAMEBUFF_FONT, 9, "OUTLINE");
		button.auraCount:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1);
		button.auraCount:Hide();
		button.auraBorder = overlay:CreateTexture(nil, "OVERLAY");
		button.auraBorder:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays");
		button.auraBorder:SetTexCoord(0.296875, 0.5703125, 0, 0.515625);
		button.auraBorder:SetPoint("CENTER", button, "CENTER", 0, 0);
		button.auraBorder:SetWidth(23);
		button.auraBorder:SetHeight(23);
		button.auraBorder:Hide();
	end
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		lDebuffButtons[i] = getglobal("TargetFrameDebuff"..i);
	end

	if (TargetFrameBuff_HasClassicAPI()) then
		for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
			button = lBuffButtons[i];
			TargetFrameBuff_AddTimer(button);
			button:SetScript("OnEnter", TargetFrameBuff_AuraOnEnter);
			button:SetScript("OnUpdate", nil);
		end
		for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
			button = lDebuffButtons[i];
			TargetFrameBuff_AddTimer(button);
			button:SetScript("OnEnter", TargetFrameBuff_AuraOnEnter);
			button:SetScript("OnUpdate", nil);
		end
	end

	-- The instance lookup was introduced alongside UNIT_AURA_DELTA. Gate the
	-- custom registration so older clients never register an unknown event.
	lHasAuraDelta = TargetFrameBuff_HasClassicAPI() and C_UnitAuras.GetAuraDataByAuraInstanceID and true or false;
	if (lHasAuraDelta) then TargetFrameBuffFrame:RegisterEvent("UNIT_AURA_DELTA"); end
	TargetFrameBuffFrame:RegisterEvent("UNIT_AURA");
	TargetFrameBuffFrame:RegisterEvent("SPELLS_CHANGED");
	TargetFrameBuffFrame:RegisterEvent("UNIT_PET");
	TargetFrameBuffFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
	TargetFrameBuffFrame:SetScript("OnEvent", function()
		if (event == "PLAYER_TARGET_CHANGED" or event == "SPELLS_CHANGED"
			or (event == "UNIT_PET" and arg1 == "player")
			or (event == "UNIT_AURA_DELTA" and arg1 == "target")
			or (not lHasAuraDelta and event == "UNIT_AURA" and arg1 == "target")) then
			-- Rebuild the small display as one snapshot. Do not retain the delta's
			-- reused payload tables; removals can also reorder all filtered indices.
			TargetFrameBuff_Update();
		end
	end);

	lOriginal_TargetDebuffButton_Update = TargetDebuffButton_Update;
	TargetDebuffButton_Update = TargetFrameBuff_Update;

	lOriginal_TargetDebuffButton_Update();
	TargetFrameBuff_Restore();
	TargetFrameBuff_Update();
end


-- ShaguTweaks "Debuff Timer" wraps TargetDebuffButton_Update and adds its own
-- cooldown (button.cd), timer text and stack count to every debuff button. On
-- top of ours that doubles the timers, sweeps and stack numbers. Its field is
-- named cd (ours is cooldown), so seeing it is a locale-proof way to notice.
local lWarnedShagu = false;
local function TargetFrameBuff_CheckShagu()
	if (lDebuffButtons[1] and lDebuffButtons[1].cd and lDebuffButtons[1].timer) then
		lWarnedShagu = true;
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100TargetFrameBuff:|r ShaguTweaks Debuff Timer is also drawing timers, sweeps and stack counts on target debuffs, so they overlap. Disable it under ShaguTweaks > Unit Frames, or use /tfb timers off and /tfb sweeps off.");
	end
end

-- use extended update-function (original code from FrameXML/TargetFrame.lua)
function TargetFrameBuff_Update()
	if (TargetFrameBuff_HasClassicAPI() and lBuffButtons[1] and lBuffButtons[1].timer) then
		TargetFrameBuff_UpdateClassicAPI();
	else
		TargetFrameBuff_UpdateNative();
	end
	TargetFrameBuff_Layout();
	if (not lWarnedShagu) then TargetFrameBuff_CheckShagu(); end
	-- Draw countdowns right away instead of waiting for the next tick.
	lTimerElapsed = TARGETFRAMEBUFF_TIMER_INTERVAL;
end


-- Color a debuff border by debuff type (Magic, Curse, Disease, Poison).
-- Without this, a border keeps the color of whatever debuff last used that
-- slot, so debuffs show the wrong category.
local function TargetFrameBuff_ColorBorder(i, debuffType)
	local debuffBorder = getglobal("TargetFrameDebuff"..i.."Border");
	if (debuffBorder and DebuffTypeColor) then
		local color = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor["none"];
		if (color) then
			debuffBorder:SetVertexColor(color.r, color.g, color.b);
		end
	end
end


local function TargetFrameBuff_SetCount(i, count)
	local stockCount = getglobal("TargetFrameDebuff"..i.."Count");
	local debuffCount = lDebuffButtons[i].auraCount or stockCount;
	if (debuffCount ~= stockCount) then stockCount:Hide(); end
	if (count and count > 1) then
		debuffCount:SetText(count);
		debuffCount:Show();
	else
		debuffCount:Hide();
	end
end


-- Stock 1.12 path: UnitBuff/UnitDebuff, no timing data.
function TargetFrameBuff_UpdateNative()
	local button, buff, i;
	local maxBuffs = TargetFrameBuff_Setting("maxBuffs");
	local maxDebuffs = TargetFrameBuff_Setting("maxDebuffs");
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		if (lTestMode) then
			buff = nil;
			if (i <= lTestBuffs) then buff = TEST_ICONS[TargetFrameBuff_Mod(i, table.getn(TEST_ICONS)) + 1]; end
		else
			buff = UnitBuff("target", i);
		end
		button = lBuffButtons[i];
		if (buff and i <= maxBuffs) then
			getglobal("TargetFrameBuff"..i.."Icon"):SetTexture(buff);
			button:Show();
			button.id = i;
		else
			button:Hide();
		end
	end

	local debuff, debuffApplications, debuffType;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		if (lTestMode) then
			debuff, debuffApplications, debuffType = nil, nil, nil;
			if (i <= lTestDebuffs) then
				debuff = TEST_ICONS[TargetFrameBuff_Mod(i, table.getn(TEST_ICONS)) + 1];
				debuffApplications = TargetFrameBuff_Mod(i, 4) == 0 and 3 or 1;
				debuffType = TEST_TYPES[TargetFrameBuff_Mod(i, 5) + 1];
			end
		else
			debuff, debuffApplications, debuffType = UnitDebuff("target", i);
		end
		button = lDebuffButtons[i];
		if (debuff and i <= maxDebuffs) then
			TargetFrameBuff_ColorBorder(i, debuffType);
			TargetFrameBuff_SetCount(i, debuffApplications);
			getglobal("TargetFrameDebuff"..i.."Icon"):SetTexture(debuff);
			button:Show();
			button.id = i;
		else
			button:Hide();
		end
	end
end


-- Slot ids are used only during this scan, never cached on buttons.
local function TargetFrameBuff_Sweep(button, duration, expiration)
	local enabled = TargetFrameBuff_Setting("sweeps");
	if (enabled and not button.cooldown and not button.noCooldown) then
		local ok, cd = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate");
		if (ok and cd and cd.SetCooldown) then
			button.cooldown = cd;
			cd:SetAllPoints(button);
			cd:SetFrameLevel(button:GetFrameLevel() + 1);
			cd:SetReverse(true);
			cd:SetDrawEdge(true);
			if (cd.SetHideCountdownNumbers) then cd:SetHideCountdownNumbers(true); end
			if (cd.SetDrawBling) then cd:SetDrawBling(false); end
			cd:Hide();
		else
			button.noCooldown = true;
		end
	end
	local cd = button.cooldown;
	if (not cd) then return; end
	if (not enabled or not duration or duration <= 0 or not expiration or expiration <= GetTime()) then
		if (cd.Clear) then cd:Clear(); else cd:Hide(); end
		button.sweepExpiration = nil;
	elseif (button.sweepExpiration ~= expiration or button.sweepDuration ~= duration) then
		cd:SetCooldown(expiration - duration, duration);
		button.sweepExpiration = expiration;
		button.sweepDuration = duration;
	end
end

local function TargetFrameBuff_HideAura(button)
	button.expiration = 0;
	button.auraIndex = nil;
	button.auraFilter = nil;
	button.timerText = nil;
	button.timer:Hide();
	if (button.cooldown) then
		if (button.cooldown.Clear) then button.cooldown:Clear(); else button.cooldown:Hide(); end
	end
	button.sweepExpiration = nil;
	if (button.auraCount) then button.auraCount:Hide(); end
	if (button.auraBorder) then button.auraBorder:Hide(); end
	if (GameTooltip:IsOwned(button)) then GameTooltip:Hide(); end
	button:Hide();
end

local function TargetFrameBuff_ShowAura(button, filter, index, icon, count, dispelType, duration, expiration, removable)
	if (button.auraIcon ~= icon) then
		getglobal(button:GetName().."Icon"):SetTexture(icon);
		button.auraIcon = icon;
	end
	button.auraFilter = filter;
	button.auraIndex = index;
	button.id = index;
	button.expiration = expiration or 0;
	if (button.auraCount) then
		if (count and count > 1) then
			button.auraCount:SetText(count);
			button.auraCount:Show();
		else
			button.auraCount:Hide();
		end
	end
	if (button.auraBorder) then
		local color;
		if (filter == "HARMFUL") then
			color = DebuffTypeColor[dispelType or "none"] or DebuffTypeColor["none"];
		elseif (removable and TargetFrameBuff_Setting("highlight")) then
			color = lRemovableColor;
		end
		if (color) then
			button.auraBorder:SetVertexColor(color.r, color.g, color.b);
			button.auraBorder:Show();
		else
			button.auraBorder:Hide();
		end
	end
	TargetFrameBuff_Sweep(button, duration, expiration);
	button:Show();
	if (TargetFrameBuff_Setting("timers") and button.expiration > GetTime()) then
		lActiveTimerCount = lActiveTimerCount + 1;
		lActiveTimers[lActiveTimerCount] = button;
		TargetFrameBuff_UpdateTimer(button, GetTime());
	else
		button.timerText = nil;
		button.timer:Hide();
	end
	if (GameTooltip:IsOwned(button) and not lTestMode) then
		GameTooltip:SetUnitAura("target", index, filter);
	end
end

-- Refresh icons, counts and expiration together so index reordering cannot
-- attach a new aura's timer to an old icon. Older ClassicAPI uses the same
-- presentation path, with its positional index getter.
function TargetFrameBuff_UpdateClassicAPI()
	local oldTimerCount = lActiveTimerCount;
	lActiveTimerCount = 0;
	lAuraElapsed = 0;
	local numBuffs, numDebuffs = 0, 0;
	local pass, filter, slots, n, index, token;
	local name, icon, count, dispelType, duration, expiration, source, removable;
	local batched = C_UnitAuras.GetAuraSlots and C_UnitAuras.UnitAuraBySlot;
	local maxBuffs = TargetFrameBuff_Setting("maxBuffs");
	local maxDebuffs = TargetFrameBuff_Setting("maxDebuffs");
	for pass = 1, 2 do
		if (pass == 1) then
			filter, slots = "HELPFUL", lHelpfulSlots;
		else
			filter, slots = "HARMFUL", lHarmfulSlots;
		end
		if (lTestMode) then
			n = (pass == 1) and lTestBuffs or lTestDebuffs;
		elseif (batched) then
			token, n = C_UnitAuras.GetAuraSlots("target", filter, nil, nil, slots);
		else
			n = TARGETFRAMEBUFF_MAX_TARGET_BUFFS + TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS;
		end
		for index = 1, n do
			if (lTestMode) then
				name, icon, count, dispelType, duration, expiration, source, removable = TargetFrameBuff_TestAura(pass, index);
			elseif (batched) then
				name, icon, count, dispelType, duration, expiration, source, removable = C_UnitAuras.UnitAuraBySlot("target", slots[index]);
			else
				name, icon, count, dispelType, duration, expiration, source, removable = C_UnitAuras.UnitAura("target", index, filter);
			end
			if (not name and not icon) then break; end
			if (pass == 2 and index <= maxDebuffs and index <= TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS) then
				numDebuffs = index;
				TargetFrameBuff_ColorBorder(index, dispelType);
				TargetFrameBuff_SetCount(index, count);
				TargetFrameBuff_ShowAura(lDebuffButtons[index], filter, index, icon, count, dispelType, duration, expiration, removable);
			elseif (pass == 2 and maxDebuffs < TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS) then
				-- A lowered debuff limit means no debuffs spill into the buff row.
				break;
			elseif (numBuffs < maxBuffs) then
				numBuffs = numBuffs + 1;
				TargetFrameBuff_ShowAura(lBuffButtons[numBuffs], filter, index, icon, count, dispelType, duration, expiration, removable);
			else
				break;
			end
		end
	end
	for index = numBuffs + 1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		TargetFrameBuff_HideAura(lBuffButtons[index]);
	end
	for index = numDebuffs + 1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		TargetFrameBuff_HideAura(lDebuffButtons[index]);
	end
	for index = lActiveTimerCount + 1, oldTimerCount do
		lActiveTimers[index] = nil;
	end
end

function TargetFrameBuff_Layout()
	local button;

	-- Position buffs above target frame
	TargetFrameBuff1:ClearAllPoints();
	TargetFrameBuff1:SetPoint("BOTTOMLEFT", "TargetFrame", "TOPLEFT", 5, -10);

	-- Debuff 1 keeps the stock anchor so it sits flush under the target frame.
	-- Remaining debuffs use a 4-4-8 layout (three rows).
	for i=2, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		button = lDebuffButtons[i];
		if button then
			button:ClearAllPoints();
			if i == 5 then
				-- Row 2: Start below button 1
				button:SetPoint("TOPLEFT", "TargetFrameDebuff1", "BOTTOMLEFT", 0, -2);
			elseif i == 9 then
				-- Row 3: Start below button 5
				button:SetPoint("TOPLEFT", "TargetFrameDebuff5", "BOTTOMLEFT", 0, -2);
			else
				-- Position horizontally relative to previous button
				button:SetPoint("LEFT", "TargetFrameDebuff"..(i-1), "RIGHT", 3, 0);
			end
		end
	end
end


-- "1h", "12m", "45", ... rounded up, so a countdown never shows 0 while
-- the aura is still up.
local function TargetFrameBuff_FormatTime(remaining)
	if (remaining >= 3600) then
		return math.ceil(remaining / 3600).."h";
	elseif (remaining >= 60) then
		return math.ceil(remaining / 60).."m";
	end
	return tostring(math.ceil(remaining));
end


TargetFrameBuff_UpdateTimer = function(button, now)
	if (not button:IsShown() or not button.auraIndex) then
		return;
	end

	local size = TargetFrameBuff_Setting("timerSize");
	if (button.timerSize ~= size) then
		button.timer:SetFont(TARGETFRAMEBUFF_FONT, size, "OUTLINE");
		button.timerSize = size;
	end

	local remaining = button.expiration - now;
	if (not TargetFrameBuff_Setting("timers") or button.expiration <= 0 or remaining <= 0) then
		if (button.timerText) then
			button.timerText = nil;
			button.timer:Hide();
		end
		return;
	end

	local text = TargetFrameBuff_FormatTime(remaining);
	if (text ~= button.timerText) then
		button.timerText = text;
		button.timer:SetText(text);
		button.timer:Show();
	end
	if (remaining <= TargetFrameBuff_Setting("warning")) then
		button.timer:SetTextColor(1, 0.1, 0.1);
	else
		button.timer:SetTextColor(1, 1, 1);
	end
end


-- Driven by TargetFrameBuffFrame, which is parented to TargetFrame, so this
-- only runs while you have a target.
function TargetFrameBuff_OnUpdate(elapsed)
	if (lTestMode) then
		lTestElapsed = lTestElapsed + (elapsed or 0);
		if (lTestElapsed >= 1) then
			lTestElapsed = 0;
			TargetFrameBuff_Update();
		end
	end
	if (not lBuffButtons[1] or not lBuffButtons[1].timer or not TargetFrameBuff_HasClassicAPI()) then
		return;
	end
	elapsed = elapsed or 0;
	lAuraElapsed = lAuraElapsed + elapsed;
	if (not lHasAuraDelta and lAuraElapsed >= TARGETFRAMEBUFF_AURA_INTERVAL) then
		TargetFrameBuff_UpdateClassicAPI();
	end
	if (lActiveTimerCount == 0) then
		lTimerElapsed = 0;
		return;
	end
	lTimerElapsed = lTimerElapsed + elapsed;
	if (lTimerElapsed < TARGETFRAMEBUFF_TIMER_INTERVAL) then return; end
	lTimerElapsed = 0;
	local now = GetTime();
	local i = lActiveTimerCount;
	while (i >= 1) do
		local button = lActiveTimers[i];
		TargetFrameBuff_UpdateTimer(button, now);
		if (not button:IsShown() or button.expiration <= now or not TargetFrameBuff_Setting("timers")) then
			lActiveTimers[i] = lActiveTimers[lActiveTimerCount];
			lActiveTimers[lActiveTimerCount] = nil;
			lActiveTimerCount = lActiveTimerCount - 1;
		end
		i = i - 1;
	end
end

function TargetFrameBuff_Restore()
	-- Resize debuffs to full size
	local button, debuffFrame;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		button = getglobal("TargetFrameDebuff"..i);
		if button then
			debuffFrame = getglobal("TargetFrameDebuff"..i.."Border");
			button:SetWidth(21);
			button:SetHeight(21);
			if debuffFrame then
				debuffFrame:SetWidth(23);
				debuffFrame:SetHeight(23);
			end
		end
	end
end


-- Turn test mode on or off. buffs (0-32) and debuffs (0-32) are optional; debuffs
-- past 16 spill into the buff row, as real ones do with ClassicAPI.
function TargetFrameBuff_SetTest(enabled, buffs, debuffs)
	lTestMode = enabled and true or false;
	if (buffs) then lTestBuffs = math.max(0, math.min(TARGETFRAMEBUFF_MAX_TARGET_BUFFS, math.floor(buffs))); end
	if (debuffs) then lTestDebuffs = math.max(0, math.min(TARGETFRAMEBUFF_MAX_TARGET_BUFFS, math.floor(debuffs))); end
	lTestStart = GetTime();
	lTestElapsed = 0;
	if (lTestMode and UnitExists and TargetUnit and not UnitExists("target")) then
		TargetUnit("player");
	end
	TargetFrameBuff_Update();
	return lTestMode, lTestBuffs, lTestDebuffs;
end

function TargetFrameBuff_IsTest()
	return lTestMode;
end
