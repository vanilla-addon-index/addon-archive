-- ScaledLifeTap 4.1 - embedded gear scanner
-- A trimmed-down replacement for BonusScanner that only totals spell damage
-- and shadow damage. It scans lazily: equipment changes just mark the cache
-- dirty, and the actual tooltip scan happens the next time Life Tap is cast.
-- No OnUpdate handler, no per-frame work.

local L = SCALEDLIFETAP_L
local Scanner = {}
ScaledLifeTap_Scanner = Scanner

-- equipment slot ids worth scanning (shirt=4 and tabard=19 never carry spell damage)
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAX_AGE = 60   -- seconds; safety net for temporary enchants (wizard oil) expiring

local TIPNAME = "ScaledLifeTapScanTip"
local tip, lines
local dirty = true
local lastScan = -1000
local dmg, shadow = 0, 0

-- per-scan state
local curSet, countedSets = nil, {}

local find, sub, len, gsub = string.find, string.sub, string.len, string.gsub
local EQUIP, SET = L.EQUIP, L.SET
local EQUIP_LEN, SET_LEN = string.len(L.EQUIP), string.len(L.SET)

local function add(kind, value)
	value = tonumber(value)
	if not value then return end
	if kind == "D" then dmg = dmg + value elseif kind == "S" then shadow = shadow + value end
end

local function trim(s)
	s = gsub(s, "^%s+", "")
	s = gsub(s, "%s+$", "")
	s = gsub(s, "%.$", "")
	return s
end

-- "Shadow Damage", "Fire Damage", ... (BonusScanner's stage1/stage2 composite match)
local function checkToken(token, value)
	local kind = L.LOOKUP[token]
	if kind then add(kind, value); return true end
	local school
	for i = 1, table.getn(L.STAGE1) do
		if find(token, L.STAGE1[i][1], 1, 1) then school = L.STAGE1[i][2] end
	end
	if not school then return false end
	for i = 1, table.getn(L.STAGE2) do
		if find(token, L.STAGE2[i], 1, 1) then
			if school == "SHADOW" then add("S", value) end
			return true
		end
	end
	return false
end

-- "+30 Spell Damage", "Shadow Damage +20", "+8 Spell Damage and Healing/+5 Stamina"
local function checkGeneric(line)
	local found = false
	while len(line) > 0 do
		local part
		local pos = find(line, "/", 1, true)
		if pos then part, line = sub(line, 1, pos - 1), sub(line, pos + 1) else part, line = line, "" end
		part = trim(part)
		local _, _, value, token = find(part, "^%+(%d+)%%?(.*)$")
		if not value then _, _, token, value = find(part, "^(.*)%+(%d+)%%?$") end
		if token and value and checkToken(trim(token), value) then found = true end
	end
	return found
end

local function checkPassive(text)
	for i = 1, table.getn(L.PASSIVE) do
		local _, _, value = find(text, L.PASSIVE[i][1])
		if value then add(L.PASSIVE[i][2], value); return end
	end
	checkGeneric(text)
end

local function checkOther(line)
	for i = 1, table.getn(L.OTHER) do
		if find(line, L.OTHER[i][1]) then add("D", L.OTHER[i][2]); return true end
	end
	return false
end

local function scanLine(line)
	if sub(line, 1, EQUIP_LEN) == EQUIP then
		checkPassive(sub(line, EQUIP_LEN + 1))
	elseif sub(line, 1, SET_LEN) == SET then
		-- only active set bonuses start with "Set: "; count each set once
		if curSet and not countedSets[curSet] then checkPassive(sub(line, SET_LEN + 1)) end
	else
		local _, _, setName = find(line, L.SETNAME)
		if setName then
			curSet = setName
		elseif not checkGeneric(line) then
			checkOther(line)
		end
	end
end

local function ensureTooltip()
	if tip then return end
	tip = CreateFrame("GameTooltip", TIPNAME, nil, "GameTooltipTemplate")
	lines = {}
	for i = 1, 30 do lines[i] = getglobal(TIPNAME .. "TextLeft" .. i) end
end

function Scanner:Scan()
	ensureTooltip()
	dmg, shadow = 0, 0
	for k in pairs(countedSets) do countedSets[k] = nil end
	for s = 1, table.getn(SLOTS) do
		tip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
		tip:ClearLines()
		curSet = nil
		if tip:SetInventoryItem("player", SLOTS[s]) then
			local n = tip:NumLines()
			if n > 30 then n = 30 end
			for i = 2, n do
				local fs = lines[i]
				local text = fs and fs:GetText()
				if text then scanLine(text) end
			end
			if curSet then countedSets[curSet] = true end
		end
	end
	tip:Hide()
	dirty = false
	lastScan = GetTime()
end

function Scanner:MarkDirty() dirty = true end

-- returns generic spell damage, shadow spell damage
function Scanner:Get()
	if dirty or (GetTime() - lastScan) > MAX_AGE then self:Scan() end
	return dmg, shadow
end

-- exposed for tests / debugging: parse arbitrary tooltip lines
function Scanner:ParseLines(list)
	dmg, shadow, curSet = 0, 0, nil
	for k in pairs(countedSets) do countedSets[k] = nil end
	for i = 1, table.getn(list) do scanLine(list[i]) end
	dirty = true
	return dmg, shadow
end
