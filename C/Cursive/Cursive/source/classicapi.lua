-- Optional ClassicAPI bridge. Nampower remains the cast/range/GUID backend.
if not Cursive.nampower then return end
local slots, seen = {}, {}
local function Reconcile(unit)
	if not Cursive.db.profile.enabled or not Cursive.db.profile.useclassicapi then return end
	if not C_UnitAuras or not C_UnitAuras.GetAuraSlots or not C_UnitAuras.UnitAuraBySlot then return end
	if not unit or not UnitExists(unit) then return end
	local _, guid = UnitExists(unit)
	if not guid and UnitGUID then guid = UnitGUID(unit) end
	if not guid then return end
	local curses = Cursive.curses
	for key in pairs(seen) do seen[key] = nil end
	local _, count = C_UnitAuras.GetAuraSlots(unit, "HARMFUL", nil, nil, slots)
	if not count then return end -- no authoritative snapshot
	for i = 1, count do
		local name, icon, stacks, dispel, duration, expiration, source, removable, personal, id =
			C_UnitAuras.UnitAuraBySlot(unit, slots[i])
		local tracked = id and curses.trackedCurseIds[id]
		if tracked and source and (source == "player" or UnitIsUnit(source, "player")) then
			seen[tracked.name] = true
			if duration and duration > 0 and expiration and expiration > GetTime() then
				local data = curses.guids[guid] and curses.guids[guid][tracked.name]
				if not data then
					local pending = curses.pendingCast
                    curses:ApplyCurse(id, guid, expiration - duration, duration)
                    curses.pendingCast = pending
					data = curses.guids[guid][tracked.name]
				end
				data.start = expiration - duration
				data.duration = duration
				data.spellID = id
				data.rank = tracked.rank
				data.classicConfirmed = true
				Cursive.core.addGuid(guid)
			end
		end
	end
	local entries = curses.guids[guid]
	if entries then
		for name, data in pairs(entries) do
			-- Do not erase optimistic casts before the first confirming server aura.
			if data.classicConfirmed and data.currentPlayer and not seen[name] then
				curses:RemoveCurse(guid, name)
			end
		end
	end
end
Cursive.ReconcileClassicAuras = Reconcile
local bridge = CreateFrame("Frame")
bridge:RegisterEvent("PLAYER_TARGET_CHANGED")
bridge:RegisterEvent("UNIT_AURA")
bridge:RegisterEvent("PLAYER_ENTERING_WORLD")
if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
	bridge:RegisterEvent("UNIT_AURA_DELTA")
end
bridge:SetScript("OnEvent", function()
	if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then Reconcile("target")
	else Reconcile(arg1) end
end)