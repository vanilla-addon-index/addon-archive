local module, L = BigWigs:ModuleDeclaration("Broodcommander Axelus", "Onyxia's Lair")
local print = print or function(t) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(tostring(t)) end end

-- Allow both "Axelus" and "Broodcommander Axelus" lookups
if BigWigs and BigWigs.modules then
	BigWigs.modules["Axelus"] = module
end

-- module variables
module.revision = 30144
module.enabletrigger = { module.translatedName, "Broodcommander Axelus", "Axelus" }
module.toggleoptions = { "chains", "chainsmark", "chainsyou", "chainssay", "wipewarning", "warder", "tankdot", "bosskill" }

module.zonename = {
	AceLibrary("AceLocale-2.2"):new("BigWigs")["Onyxia's Lair"],
	AceLibrary("Babble-Zone-2.2")["Onyxia's Lair"],
}

-- module defaults
module.defaultDB = {
	chains = true,
	chainsmark = true,
	chainsyou = true,
	chainssay = true,
	wipewarning = true,
	warder = true,
	tankdot = true,
	bosskill = true,
}

-- localization
L:RegisterTranslations("enUS", function()
	return {
		cmd = "Axelus",

		chains_cmd = "chains",
		chains_name = "Chains Alert",
		chains_desc = "Warns for Chains cast (5s) and recurring cooldown (14.5s)",

		chainsmark_cmd = "chainsmark",
		chainsmark_name = "Chains Raid Target Marking",
		chainsmark_desc = "Automatically marks the 2 Searing Chains targets with Skull (8) and Cross (7), and removes marks on fade",

		chainsyou_cmd = "chainsyou",
		chainsyou_name = "Chains on YOU Alert",
		chainsyou_desc = "Warning sign and Alarm sound when you are chained",

		chainssay_cmd = "chainssay",
		chainssay_name = "Chains /say Chat Bubble",
		chainssay_desc = "Send a /say message when you are chained so nearby players see you immediately",

		wipewarning_cmd = "wipewarning",
		wipewarning_name = "Melted Chains Wipe Warning",
		wipewarning_desc = "Warns when Melted Chains (wipe mechanic) is cast or triggered",

		warder_cmd = "warder",
		warder_name = "Onyxian Warder Spawns",
		warder_desc = "Warns for Onyxian Warder add spawns and timers",

		tankdot_cmd = "tankdot",
		tankdot_name = "Tank DoT Warnings",
		tankdot_desc = "Warns for Tank DoT (47403) afflictions and durations",

		-- Triggers (Voice lines & Combat log)
		trigger_engage = "She must not be disturbed!",
		trigger_bossDeath = "Broodmother, they're... coming...",

		trigger_chainsCast = "begins to cast Chains",
		trigger_chainsCast2 = "begins to cast Searing Chains",
		trigger_chainsCast3 = "begins to cast Casting Chains",
		trigger_searingChainsYou = "You are afflicted by Searing Chains",
		trigger_searingChainsOther = "(.+) is afflicted by Searing Chains",
		trigger_searingChainsFadeYou = "Searing Chains fades from you",
		trigger_searingChainsFadeOther = "Searing Chains fades from (.+)",

		trigger_meltedChains = "Melted Chains",
		trigger_warderSpawn = "Onyxian Warder",

		trigger_tankDotYou = "You are afflicted by Searing Wound",
		trigger_tankDotOther = "(.+) is afflicted by Searing Wound",
		trigger_tankDotFadeYou = "Searing Wound fades from you",
		trigger_tankDotFadeOther = "Searing Wound fades from (.+)",

		-- Messages & Bars
		bar_chainsCast = "Casting Chains (5s)",
		msg_chainsCast = "Casting Chains - 5 sec cast!",
		bar_chainsCd = "Next Chains",
		msg_chainsSoon = "Chains soon - prepare to spread/break!",

		msg_chainsYou = "CHAINS ON YOU - BREAK THEM!",
		warn_chainsYou = "CHAINS ON YOU - BREAK THEM!",
		say_chains = "I AM CHAINED! RUN AWAY!",
		msg_chainsOther = "Chains on %s (Skull) & %s (Cross)!",
		msg_chainsSingle = "Chains on %s (%s)!",

		msg_meltedChains = "MELTED CHAINS! WIPE WARNING!",
		warn_meltedChains = "MELTED CHAINS - WIPE!",

		bar_warderSpawn = "Next Warder",
		msg_warderSoon = "Onyxian Warder spawning soon!",
		msg_warderSpawn = "Onyxian Warder spawned - Off-tank pick up!",

		bar_tankDot = "%s - Tank DoT",
		msg_tankDot = "Tank DoT on %s!",
		warn_tankDotYou = "TANK DOT - HEALS / DEFENSIVES!",
	}
end)

-- timer, icon, and color variables (calibrated from Chronicle combat logs)
local timer = {
	chainsCast = 5,
	chainsCd = 14.5,     -- 14.5s interval start-to-start (12.5s - 17.0s in logs)
	chainsFirst = 12.5,   -- First Chains at exactly 12.5s on pull in logs
	warderFirst = 15,    -- First Onyxian Warder spawns at 15s in logs
	warderCd = 30,       -- Warder add cadence is ~30s in logs
	tankDotDur = 5,      -- Searing Wound debuff duration is exactly 5s (ticks twice for 1575 dmg)
	tankDotCd = 21,      -- Tank DoT recast interval is ~21s in logs
}

local icon = {
	chainsCast = "Spell_Nature_ChainLightning",
	chainsCd = "Spell_Fire_FlameBlades",
	chains = "INV_Misc_SteelWeaponChain",
	meltedChains = "Spell_Fire_SelfDestruct",
	warder = "Spell_Fire_Fire",
	tankDot = "Spell_Fire_Immolation",
}

local color = {
	chainsCast = "Orange",
	chainsCd = "Cyan",
	chains = "Red",
	meltedChains = "Red",
	warder = "Yellow",
	tankDot = "Magenta",
}

local spellId = {
	chainsCast = 41537,
	searingChains = 47406,
	tankDot = 47403,
	meltedChains = 48312,
}

local syncName = {
	chainsCast = "AxelusChainsCast" .. module.revision,
	chainsHit = "AxelusChainsHit" .. module.revision,
	chainsFade = "AxelusChainsFade" .. module.revision,
	meltedChains = "AxelusMeltedChains" .. module.revision,
	warderSpawn = "AxelusWarderSpawn" .. module.revision,
	tankDot = "AxelusTankDot" .. module.revision,
	tankDotFade = "AxelusTankDotFade" .. module.revision,
}

-- Tracking state
local activeChainsTargets = {}
local activeChainsMarks = {}

local function ResolvePlayerName(guidOrName)
	if not guidOrName then return nil end
	local playerName = UnitName("player")
	if guidOrName == "player" or guidOrName == playerName then
		return playerName
	end
	if type(guidOrName) == "string" and string.sub(guidOrName, 1, 2) == "0x" then
		-- SuperWoW accepts GUID in UnitName directly
		local name = UnitName(guidOrName)
		if name and name ~= "Unknown" and name ~= "" then
			return name
		end
		-- Scan raid roster for matching GUID (SuperWoW UnitExists returns exists, guid)
		local numRaid = GetNumRaidMembers()
		if numRaid and numRaid > 0 then
			for i = 1, numRaid do
				local unit = "raid" .. i
				local _, uGuid = UnitExists(unit)
				if uGuid == guidOrName then
					return UnitName(unit)
				end
			end
		end
		-- Scan party roster
		local numParty = GetNumPartyMembers()
		if numParty and numParty > 0 then
			for i = 1, numParty do
				local unit = "party" .. i
				local _, uGuid = UnitExists(unit)
				if uGuid == guidOrName then
					return UnitName(unit)
				end
			end
		end
		-- Check player
		local _, pGuid = UnitExists("player")
		if pGuid == guidOrName then
			return UnitName("player")
		end
	end
	return guidOrName
end

function module:OnEnable()
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "CastEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF", "CastEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CastEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CastEvent")

	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "AfflictionEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "AfflictionEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "AfflictionEvent")

	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF", "AuraGoneEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_PARTY", "AuraGoneEvent")
	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER", "AuraGoneEvent")

	self:RegisterEvent("CHAT_MSG_MONSTER_YELL", "MonsterEvent")
	self:RegisterEvent("CHAT_MSG_MONSTER_EMOTE", "MonsterEvent")
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE", "MonsterEvent")

	if SUPERWOW_VERSION or SetAutoloot then
		self:RegisterEvent("UNIT_CASTEVENT")
	end

	self:ThrottleSync(3, syncName.chainsCast)
	self:ThrottleSync(0.5, syncName.chainsHit)
	self:ThrottleSync(0.5, syncName.chainsFade)
	self:ThrottleSync(3, syncName.meltedChains)
	self:ThrottleSync(5, syncName.warderSpawn)
	self:ThrottleSync(1, syncName.tankDot)
	self:ThrottleSync(1, syncName.tankDotFade)
end

function module:OnSetup()
	self.started = nil
	activeChainsTargets = {}
	activeChainsMarks = {}
end

function module:OnEngage()
	activeChainsTargets = {}
	activeChainsMarks = {}

	if self.db.profile.chains then
		self:Bar(L["bar_chainsCd"], timer.chainsFirst, icon.chainsCd, true, color.chainsCd)
		self:DelayedMessage(timer.chainsFirst - 3, L["msg_chainsSoon"], "Attention", false, nil, false)
	end

	if self.db.profile.warder then
		self:Bar(L["bar_warderSpawn"], timer.warderFirst, icon.warder, true, color.warder)
		self:DelayedMessage(timer.warderFirst - 5, L["msg_warderSoon"], "Attention", false, nil, false)
		self:ScheduleRepeatingEvent("AxelusWarderTimer", self.WarderSpawnLoop, timer.warderCd, self)
	end
end

function module:OnDisengage()
	self:CancelScheduledEvent("AxelusWarderTimer")
	for i = 1, 15 do
		self:CancelScheduledEvent("AxelusTest" .. i)
	end
	self:CancelDelayedMessage(L["msg_chainsSoon"])
	self:CancelDelayedMessage(L["msg_warderSoon"])
	self:RemoveBar(L["bar_chainsCast"])
	self:RemoveBar(L["bar_chainsCd"])
	self:RemoveBar(L["bar_warderSpawn"])
	self:RemoveWarningSign(icon.chains)
	self:RemoveWarningSign(icon.meltedChains)

	-- Clean up any residual raid markers placed by chains
	for player, _ in pairs(activeChainsTargets) do
		self:RemoveChainsMark(player)
	end
	activeChainsTargets = {}
	activeChainsMarks = {}
end

function module:CastEvent(msg)
	if not msg then return end

	-- Chains 5s cast trigger
	if string.find(msg, L["trigger_chainsCast"]) or string.find(msg, L["trigger_chainsCast2"]) or string.find(msg, L["trigger_chainsCast3"]) then
		self:Sync(syncName.chainsCast)
	end

	-- Melted Chains wipe ability
	if string.find(msg, L["trigger_meltedChains"]) then
		self:Sync(syncName.meltedChains)
	end
end

function module:AfflictionEvent(msg)
	if not msg then return end

	-- Searing Chains (47406) applied to self
	if string.find(msg, L["trigger_searingChainsYou"]) then
		self:Sync(syncName.chainsHit .. " " .. UnitName("player"))
	else
		-- Searing Chains (47406) applied to others
		local _, _, target = string.find(msg, L["trigger_searingChainsOther"])
		if target then
			self:Sync(syncName.chainsHit .. " " .. target)
		end
	end

	-- Melted Chains damage / wipe alert
	if string.find(msg, L["trigger_meltedChains"]) then
		self:Sync(syncName.meltedChains)
	end

	-- Tank DoT (47403)
	if string.find(msg, L["trigger_tankDotYou"]) then
		self:Sync(syncName.tankDot .. " " .. UnitName("player"))
	else
		local _, _, dotTarget = string.find(msg, L["trigger_tankDotOther"])
		if dotTarget then
			self:Sync(syncName.tankDot .. " " .. dotTarget)
		end
	end
end

function module:AuraGoneEvent(msg)
	if not msg then return end

	-- Searing Chains fade
	if string.find(msg, L["trigger_searingChainsFadeYou"]) then
		self:Sync(syncName.chainsFade .. " " .. UnitName("player"))
	else
		local _, _, target = string.find(msg, L["trigger_searingChainsFadeOther"])
		if target then
			self:Sync(syncName.chainsFade .. " " .. target)
		end
	end

	-- Tank DoT fade
	if string.find(msg, L["trigger_tankDotFadeYou"]) then
		self:Sync(syncName.tankDotFade .. " " .. UnitName("player"))
	else
		local _, _, dotTarget = string.find(msg, L["trigger_tankDotFadeOther"])
		if dotTarget then
			self:Sync(syncName.tankDotFade .. " " .. dotTarget)
		end
	end
end

function module:MonsterEvent(msg)
	if not msg then return end

	if msg == L["trigger_engage"] then
		module:SendEngageSync()
	elseif msg == L["trigger_bossDeath"] then
		module:SendBossDeathSync()
	elseif string.find(msg, L["trigger_warderSpawn"]) then
		self:Sync(syncName.warderSpawn)
	end
end

function module:UNIT_CASTEVENT(caster, target, action, spell, castTime)
	if not spell then return end

	-- Spell 41537: Chains 5s cast
	if spell == spellId.chainsCast and action == "START" then
		self:Sync(syncName.chainsCast)
		return
	end

	-- Spell 47406: Searing Chains debuff
	if spell == spellId.searingChains then
		if action == "CAST" or action == "START" then
			if target then
				local targetName = ResolvePlayerName(target)
				if targetName then
					self:Sync(syncName.chainsHit .. " " .. targetName)
				end
			end
		end
		return
	end

	-- Spell 48312: Melted Chains
	if spell == spellId.meltedChains then
		self:Sync(syncName.meltedChains)
		return
	end

	-- Spell 47403: Tank DoT
	if spell == spellId.tankDot then
		if target then
			local targetName = ResolvePlayerName(target)
			if targetName then
				self:Sync(syncName.tankDot .. " " .. targetName)
			end
		end
		return
	end
end

function module:BigWigs_RecvSync(sync, rest, nick)
	if sync == syncName.chainsCast then
		self:ChainsCast()
	elseif sync == syncName.chainsHit and rest then
		self:ChainsHit(rest)
	elseif sync == syncName.chainsFade and rest then
		self:ChainsFade(rest)
	elseif sync == syncName.meltedChains then
		self:MeltedChains()
	elseif sync == syncName.warderSpawn then
		self:WarderSpawned()
	elseif sync == syncName.tankDot and rest then
		self:TankDot(rest)
	elseif sync == syncName.tankDotFade and rest then
		self:TankDotFade(rest)
	end
end

-- 1. Chains 5s Warning Bar & 4. Recurring Chains Cooldown Bar (14.5s)
function module:ChainsCast()
	if self.db.profile.chains then
		self:RemoveBar(L["bar_chainsCd"])
		self:Bar(L["bar_chainsCast"], timer.chainsCast, icon.chainsCast, true, color.chainsCast)
		self:Message(L["msg_chainsCast"], "Urgent", false, nil, false)

		-- Start recurring 14.5s cooldown for next Chains (measured start-to-start in logs)
		self:Bar(L["bar_chainsCd"], timer.chainsCd, icon.chainsCd, true, color.chainsCd)
		self:DelayedMessage(timer.chainsCd - 3, L["msg_chainsSoon"], "Attention", false, nil, false)
	end

	-- Clean up any lingering marks from prior wave before reassigning
	for p, _ in pairs(activeChainsTargets) do
		if self.db.profile.chainsmark then
			self:RemoveChainsMark(p)
		end
	end
	activeChainsTargets = {}
	activeChainsMarks = {}
end

-- 2. Automatic 2-Player Raid Target Marking & 3. Personal Alert
function module:ChainsHit(player)
	player = ResolvePlayerName(player)
	if not player then return end

	if not activeChainsTargets[player] then
		-- Assign Skull (8) to first player, Cross (7) to second player
		local mark = 8
		local markName = "Skull"
		if activeChainsMarks[8] then
			mark = 7
			markName = "Cross"
		end

		activeChainsTargets[player] = mark
		activeChainsMarks[mark] = player

		if self.db.profile.chainsmark then
			self:SetChainsMark(player, mark)
		end

		-- Announce chained players (established BigWigs pattern like Geddon/Vaelastrasz/Hakkar)
		if self.db.profile.chains then
			if activeChainsMarks[8] and activeChainsMarks[7] then
				self:Message(string.format(L["msg_chainsOther"], activeChainsMarks[8], activeChainsMarks[7]), "Important", false, nil, false)
			else
				self:Message(string.format(L["msg_chainsSingle"], player, markName), "Urgent", false, nil, false)
			end
		end
	end

	-- Personal Alert: Screen warning sign + alarm sound + /say bubble
	if player == UnitName("player") then
		if self.db.profile.chainsyou then
			self:Message(L["msg_chainsYou"], "Personal", true, "Alarm")
			self:WarningSign(icon.chains, 5, true, L["warn_chainsYou"])
			self:Sound("Alarm")
		end
		if self.db.profile.chainssay then
			SendChatMessage(L["say_chains"], "SAY")
		end
	end
end

function module:ChainsFade(player)
	player = ResolvePlayerName(player)
	if not player then return end

	if activeChainsTargets[player] then
		local mark = activeChainsTargets[player]
		activeChainsMarks[mark] = nil
		activeChainsTargets[player] = nil

		if self.db.profile.chainsmark then
			self:RemoveChainsMark(player)
		end
	end

	if player == UnitName("player") then
		self:RemoveWarningSign(icon.chains)
	end
end

function module:SetChainsMark(player, mark)
	local canMark = IsRaidLeader() or IsRaidOfficer() or BigWigs.markUnitsWhenNotRaidLeader or (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0)
	if not canMark then return end

	local success = self:SetRaidTargetForPlayer(player, mark)

	-- Fallback if SetRaidTargetForPlayer was raid leader only, or for party/solo
	if not success then
		local numRaid = GetNumRaidMembers()
		if numRaid and numRaid > 0 then
			for i = 1, numRaid do
				local unit = "raid" .. i
				if UnitName(unit) == player then
					SetRaidTarget(unit, mark)
					break
				end
			end
		elseif UnitName("player") == player then
			SetRaidTarget("player", mark)
		else
			for i = 1, GetNumPartyMembers() do
				local unit = "party" .. i
				if UnitName(unit) == player then
					SetRaidTarget(unit, mark)
					break
				end
			end
		end
	end
end

function module:RemoveChainsMark(player)
	local canMark = IsRaidLeader() or IsRaidOfficer() or BigWigs.markUnitsWhenNotRaidLeader or (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0)
	if not canMark then return end

	local success = self:RestorePreviousRaidTargetForPlayer(player)

	-- Fallback if RestorePreviousRaidTargetForPlayer was raid leader only, or for party/solo
	if not success then
		local numRaid = GetNumRaidMembers()
		if numRaid and numRaid > 0 then
			for i = 1, numRaid do
				local unit = "raid" .. i
				if UnitName(unit) == player then
					SetRaidTarget(unit, 0)
					break
				end
			end
		elseif UnitName("player") == player then
			SetRaidTarget("player", 0)
		else
			for i = 1, GetNumPartyMembers() do
				local unit = "party" .. i
				if UnitName(unit) == player then
					SetRaidTarget(unit, 0)
					break
				end
			end
		end
	end
end

-- 5. Wipe Warning: Alert for 48312 (Melted Chains)
function module:MeltedChains()
	if not self.db.profile.wipewarning then return end

	self:Message(L["msg_meltedChains"], "Important", false, nil, false)
	self:WarningSign(icon.meltedChains, 4, true, L["warn_meltedChains"])
	self:Sound("Beware")
end

-- 6. Warder Spawn Timers
function module:WarderSpawnLoop()
	if not self.db.profile.warder then return end
	self:Bar(L["bar_warderSpawn"], timer.warderCd, icon.warder, true, color.warder)
	self:DelayedMessage(timer.warderCd - 5, L["msg_warderSoon"], "Attention", false, nil, false)
end

function module:WarderSpawned()
	if not self.db.profile.warder then return end
	self:Message(L["msg_warderSpawn"], "Important", false, nil, false)
	self:RemoveBar(L["bar_warderSpawn"])
	self:Bar(L["bar_warderSpawn"], timer.warderCd, icon.warder, true, color.warder)
	self:DelayedMessage(timer.warderCd - 5, L["msg_warderSoon"], "Attention", false, nil, false)
end

-- 6. Tank DoT (47403) Warnings
function module:TankDot(player)
	if not self.db.profile.tankdot then return end

	local barText = string.format(L["bar_tankDot"], player)
	self:RemoveBar(barText)
	self:Bar(barText, timer.tankDotDur, icon.tankDot, true, color.tankDot)
	self:Message(string.format(L["msg_tankDot"], player), "Important", false, nil, false)

	if player == UnitName("player") then
		self:WarningSign(icon.tankDot, 3, false, L["warn_tankDotYou"])
		self:Sound("Info")
	end
end

function module:TankDotFade(player)
	if not self.db.profile.tankdot then return end

	local barText = string.format(L["bar_tankDot"], player)
	self:RemoveBar(barText)

	if player == UnitName("player") then
		self:RemoveWarningSign(icon.tankDot)
	end
end

-- Test Harness (In-Game / Simulation)
function module:Test()
	BigWigs:ToggleActive(true)
	self:Engage()

	local player = UnitName("player") or "Player"
	local friend = UnitName("party1") or UnitName("raid1") or "RaidMember1"
	local tank = "TankOne"

	print("--- BigWigs Broodcommander Axelus Encounter Test Started ---")

	local events = {
		-- 1s: Engage Yell
		{ time = 1, func = function()
			print("Test [1s]: Engage yell")
			self:TriggerEvent("CHAT_MSG_MONSTER_YELL", "She must not be disturbed!")
		end },

		-- 3s: Chains 5s Cast Begins (Warning Bar: "Casting Chains (5s)")
		{ time = 3, func = function()
			print("Test [3s]: Axelus begins casting Chains (5s)")
			self:TriggerEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "Broodcommander Axelus begins to cast Chains.")
		end },

		-- 8s: Chains Hits (Player + Friend) -> Skull (8) on Player, Cross (7) on Friend + Personal Alert
		{ time = 8, func = function()
			print("Test [8s]: Searing Chains hits " .. player .. " and " .. friend)
			self:TriggerEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "You are afflicted by Searing Chains.")
			self:TriggerEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", friend .. " is afflicted by Searing Chains.")
		end },

		-- 14s: Chains Fade -> Raid markers removed, Warning sign cleared
		{ time = 14, func = function()
			print("Test [14s]: Searing Chains fades from players")
			self:TriggerEvent("CHAT_MSG_SPELL_AURA_GONE_SELF", "Searing Chains fades from you.")
			self:TriggerEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER", "Searing Chains fades from " .. friend .. ".")
		end },

		-- 16s: Tank DoT on Main Tank
		{ time = 16, func = function()
			print("Test [16s]: Tank DoT applied to " .. tank)
			self:TriggerEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", tank .. " is afflicted by Searing Wound.")
		end },

		-- 20s: Onyxian Warder Add Spawns
		{ time = 20, func = function()
			print("Test [20s]: Onyxian Warder spawned")
			self:TriggerEvent("CHAT_MSG_MONSTER_EMOTE", "Onyxian Warder emerges from the shadows!")
		end },

		-- 23s: Next Chains Cast Begins (recurring cooldown)
		{ time = 23, func = function()
			print("Test [23s]: Next Chains cast begins")
			self:TriggerEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "Broodcommander Axelus begins to cast Chains.")
		end },

		-- 28s: Melted Chains Wipe Warning (Spell 48312)
		{ time = 28, func = function()
			print("Test [28s]: Melted Chains wipe warning")
			self:TriggerEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "Broodcommander Axelus's Melted Chains hits Raid for 5000 Fire damage.")
		end },

		-- 32s: Death Yell / Kill
		{ time = 32, func = function()
			print("Test [32s]: Boss defeated")
			self:TriggerEvent("CHAT_MSG_MONSTER_YELL", "Broodmother, they're... coming...")
		end },

		-- 35s: Disengage Cleanup
		{ time = 35, func = function()
			print("Test [35s]: End of Axelus simulation")
			module:Disengage()
		end },
	}

	-- Schedule each event spaced out across time
	for i, event in ipairs(events) do
		self:ScheduleEvent("AxelusTest" .. i, event.func, event.time)
	end

	self:Message(module.translatedName .. " simulation test started (35s sequence)", "Positive")
	return true
end
-- /run BigWigs:GetModule("Axelus"):Test()
-- /run BigWigs:GetModule("Broodcommander Axelus"):Test()
