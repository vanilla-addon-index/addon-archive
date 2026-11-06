
local module, L = BigWigs:ModuleDeclaration("Ebonroc", "Blackwing Lair")

module.revision = 30146
module.enabletrigger = module.translatedName
module.toggleoptions = {"wingbuffet", "shadowflame", "curse", "sparks", "sparksyou", "bosskill"}

L:RegisterTranslations("enUS", function() return {
	cmd = "Ebonroc",

	wingbuffet_cmd = "wingbuffet",
	wingbuffet_name = "Wing Buffet Alert",
	wingbuffet_desc = "Warn for Wing Buffet",

	shadowflame_cmd = "shadowflame",
	shadowflame_name = "Shadow Flame Alert",
	shadowflame_desc = "Warn for Shadow Flame",

	curse_cmd = "curse",
	curse_name = "Shadow of Ebonroc Alert",
	curse_desc = "Warn for Shadow of Ebonroc",

	sparks_cmd = "sparks",
	sparks_name = "Shadowflame Sparks Bar",
	sparks_desc = "Warn for recurring Shadowflame Spark waves (every 8s) with wave numbered countdown bars",

	sparksyou_cmd = "sparksyou",
	sparksyou_name = "Shadowflame Spark Aggro Alert",
	sparksyou_desc = "Warn with sound alarm and warning icon when a Shadowflame Spark attacks or casts on YOU",
	
	
	trigger_wingBuffet = "Ebonroc begins to cast Wing Buffet.", --CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE
	bar_wingBuffetCast = "Casting Wing Buffet!",
	bar_wingBuffetCd = "Wing Buffet CD",
	msg_wingBuffetCast = "Casting Wing Buffet!",
	msg_wingBuffetSoon = "Wing Buffet in 2 seconds - Taunt now!",
	
	trigger_shadowFlameCast = "Ebonroc begins to cast Shadow Flame.", --CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE - seems to no longer appear in logs since 1.18
	bar_shadowFlameCast = "Casting Shadow Flame!",
	msg_shadowFlameCast = "Casting Shadow Flame!",
	trigger_shadowFlameHit = "Ebonroc's Shadow Flame hits", --CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE
	bar_shadowFlameCd = "Shadow Flame CD",
	
	trigger_shadowOfEbonrocYou = "You are afflicted by Shadow of Ebonroc.", --CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE
	trigger_shadowOfEbonrocOther = "(.+) is afflicted by Shadow of Ebonroc.", --CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE // CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE
	trigger_shadowOfEbonrocFade = "Shadow of Ebonroc fades from (.+).", --CHAT_MSG_SPELL_AURA_GONE_SELF // CHAT_MSG_SPELL_AURA_GONE_PARTY // CHAT_MSG_SPELL_AURA_GONE_OTHER
	msg_shadowOfEbonroc = " has Shadow of Ebonroc - Taunt!",
	bar_shadowOfEbonrocDur = " Shadow of Ebonroc",
	bar_shadowOfEbonrocCd = "Shadow of Ebonroc CD",
	
	trigger_sparkHit = "Shadowflame Spark", --CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS // CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE
	bar_sparksCd = "Sparks",
	bar_sparksCdCount = "Sparks (%d)",
	msg_sparksSoon = "Sparks in 2s",
	msg_sparksSoonCount = "Sparks (%d) in 2s",
	msg_sparksSpawn = "Sparks!",
	msg_sparksSpawnCount = "Sparks (%d)!",
	msg_sparksYou = "SPARK ON YOU!",
	msg_sparks = "Sparks: Immune - Dodge!",
} end)

local timer = {
	wingBuffetFirstCd = 30,
	wingBuffetCd = 29, --30sec - 1sec cast
	wingBuffetCast = 1,
	
	shadowFlameFirstCd = 16,
	shadowFlameCd = 14, --16 - 2sec cast
	shadowFlameCast = 2,
	
	shadowOfEbonrocCd = 8,
	shadowOfEbonrocDur = 8,

	sparksFirst = 16,
	sparksCd = 8,
}
local icon = {
	wingBuffet = "INV_Misc_MonsterScales_14",
	shadowFlame = "Spell_Fire_Incinerate",
	shadowOfEbonroc = "Spell_Shadow_GatherShadows",
	sparks = "Spell_Fire_SelfDestruct",
}
local color = {
	wingBuffetCd = "Cyan",
	wingBuffetCast = "Blue",
	
	shadowFlameCd = "Orange",
	shadowFlameCast = "Red",
	
	shadowOfEbonrocCd = "Black",
	shadowOfEbonrocDur = "Magenta",

	sparks = "Orange",
}
local syncName = {
	wingBuffet = "EbonrocWingBuffet"..module.revision,
	shadowFlameCast = "EbonrocShadowflame"..module.revision,
	shadowFlameHit = "EbonrocShadowflameHit"..module.revision,
	shadowOfEbonroc = "EbonrocShadow"..module.revision,
	shadowOfEbonrocFade = "EbonrocShadowFade"..module.revision,
	sparks = "EbonrocSparks"..module.revision,
}
local spellId = {
	shadowFlame = 22539,
	sparkSpell = 30207,
}

function module:OnEnable()
	--self:RegisterEvent("CHAT_MSG_SAY", "Event") --Debug
	
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "Event") --trigger_shadowFlameHit, trigger_sparkHit
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "Event") --trigger_shadowFlameHit, trigger_sparkHit
	self:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "Event") --trigger_wingBuffet, trigger_shadowFlameCast, trigger_shadowFlameHit, trigger_sparkHit
	
	self:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "Event") --trigger_sparkHit
	self:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "Event") --trigger_sparkHit
	self:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS", "Event") --trigger_sparkHit

	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "Event") --trigger_shadowOfEbonrocYou
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "Event") --trigger_shadowOfEbonrocOther
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "Event") --trigger_shadowOfEbonrocOther
	
	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF", "Event") --trigger_shadowOfEbonrocFade
	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_PARTY", "Event") --trigger_shadowOfEbonrocFade
	self:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER", "Event") --trigger_shadowOfEbonrocFade
	
	if SUPERWOW_VERSION or SetAutoloot then
		self:RegisterEvent("UNIT_CASTEVENT")
	end
	
	self:ThrottleSync(3, syncName.wingBuffet)
	self:ThrottleSync(3, syncName.shadowFlameCast)
	self:ThrottleSync(3, syncName.shadowFlameHit)
	self:ThrottleSync(3, syncName.shadowOfEbonroc)
	self:ThrottleSync(3, syncName.shadowOfEbonrocFade)
	self:ThrottleSync(5, syncName.sparks)
end

function module:OnSetup()
	self.started = nil
	self.sparksWaveCount = 0
end

function module:OnDisengage()
	self:CancelScheduledEvent("EbonrocSparks")
	self:CancelDelayedMessage(L["msg_sparksSoon"])
	if self.sparksWaveCount and self.sparksWaveCount > 0 then
		self:CancelDelayedMessage(string.format(L["msg_sparksSoonCount"], self.sparksWaveCount + 1))
		self:RemoveBar(string.format(L["bar_sparksCdCount"], self.sparksWaveCount + 1))
		self:RemoveBar(string.format(L["bar_sparksCdCount"], self.sparksWaveCount))
	end
	self:RemoveBar(string.format(L["bar_sparksCdCount"], 1))
	self:RemoveBar(L["bar_sparksCd"])
	self:RemoveWarningSign(icon.sparks)
	self.sparksWaveCount = 0
end

function module:OnEngage()	
	if self.db.profile.wingbuffet then
		self:Bar(L["bar_wingBuffetCd"], timer.wingBuffetFirstCd, icon.wingBuffet, true, color.wingBuffetCd)
		self:DelayedMessage(timer.wingBuffetFirstCd - 2, L["msg_wingBuffetSoon"], "Attention", false, nil, false)
	end
	
	if self.db.profile.shadowflame then
		self:Bar(L["bar_shadowFlameCd"], timer.shadowFlameFirstCd, icon.shadowFlame, true, color.shadowFlameCd)
	end
	
	if self.db.profile.curse then
		self:Bar(L["bar_shadowOfEbonrocCd"], timer.shadowOfEbonrocCd, icon.shadowOfEbonroc, true, color.shadowOfEbonrocCd)
	end
	
	self.sparksWaveCount = 0
	if self.db.profile.sparks then
		self:Message(L["msg_sparks"], "Attention")
		self:Bar(string.format(L["bar_sparksCdCount"], 1), timer.sparksFirst, icon.sparks, true, color.sparks)
		self:ScheduleEvent("EbonrocSparks", self.SparksSpawn, timer.sparksFirst, self)
	end
end

function module:SparksSpawn(wave)
	if not self.db.profile.sparks then return end
	if wave and tonumber(wave) then
		self.sparksWaveCount = tonumber(wave)
	else
		self.sparksWaveCount = (self.sparksWaveCount or 0) + 1
	end

	self:CancelScheduledEvent("EbonrocSparks")
	self:CancelDelayedMessage(L["msg_sparksSoon"])
	self:CancelDelayedMessage(string.format(L["msg_sparksSoonCount"], self.sparksWaveCount))
	self:RemoveBar(string.format(L["bar_sparksCdCount"], self.sparksWaveCount))
	self:RemoveBar(L["bar_sparksCd"])
	
	self:Message(string.format(L["msg_sparksSpawnCount"], self.sparksWaveCount), "Attention", false, nil, false)
	self:Bar(string.format(L["bar_sparksCdCount"], self.sparksWaveCount + 1), timer.sparksCd, icon.sparks, true, color.sparks)
	self:ScheduleEvent("EbonrocSparks", self.SparksSpawn, timer.sparksCd, self)
end

function module:Event(msg)
	if not msg then return end

	if msg == L["trigger_wingBuffet"] then
		self:Sync(syncName.wingBuffet)
	
	elseif msg == L["trigger_shadowFlameCast"] then
		self:Sync(syncName.shadowFlameCast)
	
	elseif string.find(msg, L["trigger_shadowFlameHit"]) then
		self:Sync(syncName.shadowFlameHit)
	
	elseif msg == L["trigger_shadowOfEbonrocYou"] then
		self:Sync(syncName.shadowOfEbonroc .. " " .. UnitName("Player"))
	
	elseif string.find(msg, L["trigger_shadowOfEbonrocOther"]) then
		local _,_,shadowOfEbonrocPlayer,_ = string.find(msg, L["trigger_shadowOfEbonrocOther"])
		self:Sync(syncName.shadowOfEbonroc .. " " .. shadowOfEbonrocPlayer)
		
	elseif string.find(msg, L["trigger_shadowOfEbonrocFade"]) then
		local _,_,shadowOfEbonrocFadePlayer,_ = string.find(msg, L["trigger_shadowOfEbonrocFade"])
		if shadowOfEbonrocFadePlayer == "you" then shadowOfEbonrocFadePlayer = UnitName("Player") end
		self:Sync(syncName.shadowOfEbonrocFade .. " " .. shadowOfEbonrocFadePlayer)

	elseif string.find(msg, L["trigger_sparkHit"]) then
		local warnYou = self.db.profile.sparksyou
		if warnYou == nil then warnYou = self.db.profile.sparks end
		if warnYou and (string.find(msg, " hits you") or string.find(msg, " crits you") or string.find(msg, " you for ") or string.find(msg, "attacks. You")) then
			self:Message(L["msg_sparksYou"], "Personal", true, "Alarm")
			self:WarningSign(icon.sparks, 2)
		end
	end
end

function module:UNIT_CASTEVENT(caster,target,action,spell,castTime)
	if not spell then return end

	if spell == spellId.shadowFlame and action == "START" then
		self:Sync(syncName.shadowFlameCast)
		self:DelayedSync(castTime/1000, syncName.shadowFlameHit)
		return
	elseif spell == spellId.sparkSpell then
		local _, playerGuid = UnitExists("player")
		local warnYou = self.db.profile.sparksyou
		if warnYou == nil then warnYou = self.db.profile.sparks end
		if warnYou and target and (target == playerGuid or target == UnitName("player") or UnitIsUnit(target, "player")) then
			self:Message(L["msg_sparksYou"], "Personal", true, "Alarm")
			self:WarningSign(icon.sparks, 2)
		end
		return
	end
end


function module:BigWigs_RecvSync(sync, rest, nick)
	if sync == syncName.wingBuffet and self.db.profile.wingbuffet then
		self:WingBuffet()
	elseif sync == syncName.shadowFlameCast and self.db.profile.shadowflame then
		self:RemoveBar(L["bar_shadowFlameCd"])
		self:Bar(L["bar_shadowFlameCast"], timer.shadowFlameCast, icon.shadowFlame, true, color.shadowFlameCast)
		self:Message(L["msg_shadowFlameCast"], "Urgent", false, nil, false)
	elseif sync == syncName.shadowFlameHit and self.db.profile.shadowflame then
		self:RemoveBar(L["bar_shadowFlameCd"])
		self:Bar(L["bar_shadowFlameCd"], timer.shadowFlameCd, icon.shadowFlame, true, color.shadowFlameCd)
	elseif sync == syncName.shadowOfEbonroc and rest and self.db.profile.curse then
		self:ShadowOfEbonroc(rest)
	elseif sync == syncName.shadowOfEbonrocFade and rest and self.db.profile.curse then
		self:ShadowOfEbonrocFade(rest)
	elseif sync == syncName.sparks and self.db.profile.sparks then
		self:SparksSpawn(rest)
	end
end


function module:WingBuffet()
	self:CancelDelayedMessage(L["msg_wingBuffetSoon"])
	self:RemoveBar(L["bar_wingBuffetCd"])
	
	self:Bar(L["bar_wingBuffetCast"], timer.wingBuffetCast, icon.wingBuffet, true, color.wingBuffetCast)
	
	self:DelayedBar(timer.wingBuffetCast, L["bar_wingBuffetCd"], timer.wingBuffetCd, icon.wingBuffet, true, color.wingBuffetCd)
	self:DelayedMessage(timer.wingBuffetCast + timer.wingBuffetCd - 2, L["msg_wingBuffetSoon"], "Attention", false, nil, false)
end

function module:ShadowOfEbonroc(rest)
	self:RemoveBar(L["bar_shadowOfEbonrocCd"])
	
	self:Bar(rest..L["bar_shadowOfEbonrocDur"], timer.shadowOfEbonrocDur, icon.shadowOfEbonroc, true, color.shadowOfEbonrocDur)
	self:Message(rest..L["msg_shadowOfEbonroc"], "Important", false, nil, false)
	
	if rest == UnitName("Player") then
		self:WarningSign(icon.shadowOfEbonroc, timer.shadowOfEbonrocDur)
	end
end

function module:ShadowOfEbonrocFade(rest)
	self:RemoveBar(rest..L["bar_shadowOfEbonrocDur"])
	
	if rest == UnitName("Player") then
		self:RemoveWarningSign(icon.shadowOfEbonroc)
	end
end
