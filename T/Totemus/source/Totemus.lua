Totemus = AceAddonClass:new({
	name          		= TOTEMUS_CONST.Title,
	description   		= TOTEMUS_CONST.Desc,
	version       		= TOTEMUS_CONST.Version,
	releaseDate   		= "",
	aceCompatible 		= 103,
	author        		= "Azgardian",
	email         		= "",
	website		     	= "http://www.wowace.com",
	category      		= "interface",
	db            		= AceDbClass:new("TotemusDB"),
	cmd           		= AceChatCmdClass:new(TOTEMUS_CONST.ChatCmd,TOTEMUS_CONST.ChatOpt),
	
	----------------------------
	--			Module Loadup			--
	----------------------------
	
	
	Initialize = function(self)
		self.Compost = CompostLib:GetInstance("compost-1")
		self.Metrognome = Metrognome:GetInstance("1")
		self.Metrognome:Register("Totemus", self.Heartbeat, TOTEMUS_CONST.UpdateInterval, self )
	end,
	
	Enable = function(self)
		if( UnitClass("player") == TOTEMUS_CONST.Pattern.Shaman ) then
			self.spells = {}

			self.timers = {}
			self.timerstext = "" 
			self.lastupdate = 0
			self.currentspell = {}
			self.mounttype = 0
			self.hearthstone = {}

			self.bufftype = 0
			self.shieldtype = ""
			self.button = ""
			if( not self:GetOpt("firsttimedone") ) then
				self:SetOpt("timers", TRUE)
				self:SetOpt("firsttimedone", TRUE)
			end

			self:ScanSpells()
			

			self:SetupFrames()
--			self.frames.shaman:Show()
			self.frames.main:Show()

			self:UpdateButtons()

			self:RegisterEvent("BAG_UPDATE")
			self:RegisterEvent("Totemus_BAG_UPDATE")

			self:RegisterEvent("SPELLS_CHANGED")
			self:RegisterEvent("LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED")

			self:RegisterEvent("SPELLCAST_START")
			self:RegisterEvent("SPELLCAST_FAILED")
			self:RegisterEvent("SPELLCAST_INTERRUPTED")
			--self:RegisterEvent("SPELLCAST_CHANNEL_START")
			-- self:RegisterEvent("SPELLCAST_CHANNEL_STOP")
			self:RegisterEvent("SPELLCAST_STOP")
			self:RegisterEvent("PLAYER_REGEN_ENABLED")

			self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
			self:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")

			self:Hook("CastSpell", "OnCastSpell", Totemus )
			self:Hook("CastSpellByName", "OnCastSpellByName", Totemus )
			self:Hook("UseAction", "OnUseAction", Totemus )
			--slef:Hook("OnMouseUp")
			-- self:Hook("UseContainerItem", "OnUseContainerItem" )
		
			if( self:GetOpt("timers") ) then
				self.Metrognome:Start("Totemus")
				self.frames.timers:Show()
			else
				self.frames.timers:Hide()
			end
		end
	end,
	
	Disable = function(self)
		if( UnitClass("player") == TOTEMUS_CONST.Pattern.Shaman ) then
			-- Stop the heartbeat and hide our main frame
			self.Metrognome:Stop("Totemus")
			self.frames.main:Hide()

			self.UnregisterAllEvents()

			self:Unhook("CastSpell")
			self:Unhook("CastSpellByName")
			self:Unhook("UseAction")
			-- self:Unhook("UseContainerItem")
		end
		
	end,

----------------------------
-- General               --
----------------------------


	GetGradient = function( self, perc )
		local gradient = "|CFF00FF00" -- BrightGreen
		
		if( perc < 10 ) then
			gradient = "|CFFFF0000" -- Red
		elseif( perc < 20 ) then
			gradient = "|CFFFF3300" -- RedOrange
		elseif( perc < 30 ) then
			gradient = "|CFFFF6600" -- DarkOrange
		elseif( perc < 40 ) then
			gradient = "|CFFFF9933" -- DirtyOrange
		elseif( perc < 50 ) then
			gradient = "|CFFFFCC00" -- DarkYellow
		elseif( perc < 60 ) then
			gradient = "|CFFFFFF66" -- LightYellow
		elseif( perc < 70 ) then
			gradient = "|CFFCCFF66" -- YellowGreen
		elseif( perc < 80 ) then
			gradient = "|CFF99FF66" -- LightGreen
		elseif( perc < 90 ) then
			gradient = "|CFF66FF66" -- LighterGreen
		end
		return gradient
	end,



	ScanHearth = function( self )
		local bag
		local itemLink
		self.Compost:Erase(self.hearthstone)
		--function UseContainerItemByName(search)
		--for bag = 0,4 do
		--	for slot = 1,GetContainerNumSlots(bag) do
		--		local item = GetContainerItemLink(bag,slot)
		--			if item and string.find(item,search) then
		--				UseContainerItem(bag,slot)
		--			end
		--	end
		--end
		--end

		for bag = 4, 0, -1 do
			local size = GetContainerNumSlots(bag)
			if (size > 0) then
				local slot
				for slot=1, size, 1 do
					if (GetContainerItemLink(bag,slot)) then
						itemLink = GetContainerItemLink(bag,slot)
						if( string.find( itemLink, TOTEMUS_CONST.Pattern.Hearthstone )) then
							self.hearthstone[0] = bag
							self.hearthstone[1] = slot
						end
					end
				end
			end
		end
	end,

	ScanSpells = function( self )

		local spellName, spellRank, spellTotal, id, rank, maxrank, rankedSpell
		local spellLevel = {}

		self.spells.normal = {}
		self.spells.timed = {}
		self.spells.timedid = {}
		self.spells.timedname = {}
		self.spells.timeddisplay = {}
		self.spells.timedrank = {}
		self.spells.menuslot = {}
		self.spells.bufftype = {}
		self.spells.bufftypebyspell = {}
		
		for id = 1, 480 do
			rankedSpell = nil
			spellName, spellRank = GetSpellName(id, "spell")
			--self:SendChatMessage(string.format( self.timers[mindex][sindex]["duration"] ) )
			
			if (spellName) then
			
				if( spellRank and spellRank ~= "" ) then 
					spellTotal = spellName .. " " .. spellRank
				else 
					spellTotal = spellName
				end
				--self:SendChatMessage(string.format( s ) )
				if( TOTEMUS_CONST.Spell[spellName] ) then
					self.spells.normal[TOTEMUS_CONST.Spell[spellName]] = id
					self.spells.menuslot[TOTEMUS_CONST.Spell[spellName]] = 4
					
				end
--				self:Msg("Spell: ##"..spellTotal.."##")
				if( TOTEMUS_CONST.RankedSpell[spellTotal] ) then
					local thistag, thislevel, thisbufftype
					thistag = TOTEMUS_CONST.RankedSpell[spellTotal][1]
					thislevel = TOTEMUS_CONST.RankedSpell[spellTotal][2]
					thisbufftype = TOTEMUS_CONST.RankedSpell[spellTotal][3]
					if( not spellLevel[thistag] or thislevel > spellLevel[thistag] ) then
						self.spells.normal[thistag] = id
						spellLevel[thistag] = thislevel
						if( thistag == "MOUNT" ) then
							self.mounttype = thislevel
						end
					end
				end

				if( TOTEMUS_CONST.RankedSpell[spellName] ) then
					rankedSpell = spellName
				end
				if( TOTEMUS_CONST.RankedSpell[spellTotal] ) then
					rankedSpell = spellTotal
				end

				if( rankedSpell ) then
				--self:Msg("im a ranked spell" )
					local thistag, thislevel, thisbufftype, thisduration
					thistag = TOTEMUS_CONST.RankedSpell[rankedSpell][1]
					thislevel = TOTEMUS_CONST.RankedSpell[rankedSpell][2]
					thisbufftype = TOTEMUS_CONST.RankedSpell[rankedSpell][3]
				self.spells.bufftypebyspell[strlower(rankedSpell)] = thisbufftype
					--self:Msg(TOTEMUS_CONST.RankedSpell[rankedSpell][3] )
					
						--self:Msg ("Registered t:")
					if( not spellLevel[thistag] or thislevel > spellLevel[thistag] ) then
							self.spells.normal[thistag] = id
							spellLevel[thistag] = thislevel
							self.spells.bufftype[thistag] = thisbufftype
							if( thistag == "MOUNT" ) then
								self.mounttype = thislevel
							end
						end
	
					end

				if( TOTEMUS_CONST.TimedSpell[spellName] ) then
					maxrank = 0
					if (string.find(spellRank, TOTEMUS_CONST.Pattern.Rank )) then
						for rank in string.gfind( spellRank, TOTEMUS_CONST.Pattern.Rank ) do
							rank = tonumber(rank)
							if( rank > maxrank ) then
								maxrank = rank
							end
						end
					end					
					if( maxrank == 0 ) then
						maxrank = 1
					end
					if( not spellLevel[spellName] or maxrank > spellLevel[spellName] ) then
						self.spells.timedname[strlower(spellName)] = strlower(spellTotal)
					end
					self.spells.timedid[id] = strlower(spellTotal)
					self.spells.timed[strlower(spellTotal)] = TOTEMUS_CONST.TimedSpell[spellName][maxrank]
					self.spells.timeddisplay[strlower(spellTotal)] = spellName
					self.spells.timedrank[id] = maxrank
					
					--self:Msg("im a timed spell" )
					--self:SendChatMessage(string.format( self.spells.bufftype ) )
					
				end
			end
		end
	end,	

	GetTargetInfo = function( self )

		local targetInfo = { }
	
		if( UnitExists("target") ) then
	
			targetInfo.Name = UnitName("target")
			targetInfo.Sex = UnitSex("target")
			targetInfo.Level = UnitLevel("target")
			if( targetInfo.Level == -1 ) then targetInfo.Level = "??" end

			targetInfo.Classification = UnitClassification("target")
			if( targetInfo.Classification == "worldboss" ) then
				targetInfo.Classification = "b+"
			elseif( targetInfo.Classification == "rareelite" ) then
				targetInfo.Classification = "r+"
			elseif( targetInfo.Classification == "elite" ) then
				targetInfo.Classification = "+"
			elseif( targetInfo.Classification == "rare" ) then
				targetInfo.Classification = "r"
			else 
				targetInfo.Classification = ""
			end

			targetInfo.IsPlayer = UnitIsPlayer("target")
			targetInfo.IsEnemy = UnitCanAttack("player", "target")
			targetInfo.Id = targetInfo.Name..targetInfo.Sex..targetInfo.Level
			targetInfo.Display = "["..targetInfo.Level..targetInfo.Classification.."] "..targetInfo.Name
		
			return targetInfo
		else
			return FALSE
		end
	
	end,

	RegisterSpellCast = function( self, spell )

		if( not self:GetOpt("timers") )	then return end

		if( self.currentspell.state and 
				self.currentspell.state == TOTEMUS_CONST.State.Start ) then
			-- We do nothing. This happens when you cast a spell with a duration and
			-- after that cast another spell, which attempt to register with the timers.
			-- the state will be > 1 when SPELLCAST_START has fired we are casting atm.
			-- so ignore this cast.
			return
		end

		-- We reset the current spellcast whatever happens next.
		self.Compost:Erase( self.currentspell )

		-- Only track spells we actually time
		if( not self.spells.timed[spell] ) then
			return
		end

		-- Determine element / "menu slot" from bufftypebyspell if possible
		local bufftype = nil
		if self.spells.bufftypebyspell and self.spells.bufftypebyspell[spell] then
			bufftype = self.spells.bufftypebyspell[spell]
		end

		self.bufftype = bufftype or self.bufftype or 0
		self.currentspell.menuslot = bufftype or self.currentspell.menuslot

		-- Build a minimal target (we mostly care about timers per element)
		local playerName = UnitName("player") or "player"
		local target = {
			Name    = playerName,
			Id      = playerName,
			Display = playerName,
		}

		self.currentspell.state        = TOTEMUS_CONST.State.Cast
		self.currentspell.target       = target
		self.currentspell.spell        = spell
		self.currentspell.spelldisplay = self.spells.timeddisplay[spell] or spell
		self.currentspell.duration     = self.spells.timed[spell]
	end,


	ClearTimers = function( self )
		local i,j
		for i in pairs( self.timers ) do
			for j in pairs( self.timers[i] ) do
				if( j ~= "name" and j ~= "nr" ) then
					Timex:DeleteSchedule("Totemus Timers "..i..j)
				end
			end
		end
		self.Compost:Erase( self.timers )
	end,

	TimerDeleteSpell = function( self, mindex, sindex )
		if( self.timers[mindex] ) then
			if( self.timers[mindex][sindex] ) then
				self.timers[mindex][sindex]["duration"] = nil
				self.timers[mindex][sindex] = nil 
				self.timers[mindex]["nr"] = self.timers[mindex]["nr"] - 1
			end
			if( self.timers[mindex]["nr"] < 1 ) then
				self.timers[mindex]["name"] = nil
				self.timers[mindex]["nr"] = nil
				self.timers[mindex] = nil
			end
		end
	end,

	TimerAddSpell = function( self )
		-- Prefer menuslot set in RegisterSpellCast; fall back to bufftype
		local mindex = self.currentspell.menuslot or self.bufftype
		local sindex = self.currentspell.spelldisplay or self.currentspell.spell
		local duration = self.currentspell.duration

		-- If we still don't have enough info, don't create a timer
		if not mindex or not sindex or not duration then
			return
		end

		--self:Msg("AddSpell menuslot "..mindex.." spell "..sindex)

		if( self.timers[mindex] ) then
			if( self.timers[mindex][sindex] ) then
				-- Update existing timer
				self.currentspell.state = TOTEMUS_CONST.State.Update
				self.currentspell.oldduration = Timex:ScheduleCheck("Totemus Timers "..mindex..sindex, TRUE)
				Timex:DeleteSchedule("Totemus Timers "..mindex..sindex )
				Timex:AddSchedule("Totemus Timers "..mindex..sindex, duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
				self.timers[mindex][sindex]["duration"] = duration
			else
				-- New spell in existing element column
				self.currentspell.state = TOTEMUS_CONST.State.NewSpell
				self.timers[mindex][sindex] = {}
				self.timers[mindex][sindex]["duration"] = duration
				self.timers[mindex]["nr"] = self.timers[mindex]["nr"] + 1
				Timex:AddSchedule("Totemus Timers "..mindex..sindex, duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
			end
		else
			-- First spell in this element column
			self.currentspell.state = TOTEMUS_CONST.State.NewSpell
			self.timers[mindex] = {}
			self.timers[mindex]["nr"] = 0
			self.timers[mindex]["name"] = self.currentspell.spell
			self.timers[mindex][sindex] = {}
			self.timers[mindex][sindex]["duration"] = duration
			self.timers[mindex]["nr"] = self.timers[mindex]["nr"] + 1
			Timex:AddSchedule("Totemus Timers "..mindex..sindex, duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
		end
	end,


	TimerAddBuff = function( self )
		local mindex = self.bufftype
		local sindex = self.currentspell.spelldisplay
		local spell_duration = self.currentspell.duration
		
		
		if( self.timers[mindex] ) then
			if( self.timers[mindex][sindex] ) then
				-- self:Msg("AddSpell Updating "..mindex..sindex )
				self.currentspell.state = TOTEMUS_CONST.State.Update
				self.currentspell.oldduration = Timex:ScheduleCheck("Totemus Timers "..mindex..sindex, TRUE)
				Timex:DeleteSchedule("Totemus Timers "..mindex..sindex )
				Timex:AddSchedule("Totemus Timers "..mindex..sindex, self.currentspell.duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
				self.timers[mindex][sindex]["duration"] = self.currentspell.duration
			else
				-- self:Msg("AddSpell Newspell "..mindex..sindex )
				Timex:DeleteSchedule("Totemus Timers "..mindex..sindex )
				self.currentspell.state = TOTEMUS_CONST.State.NewSpell	
				self.timers[mindex] = {}
				self.timers[mindex]["nr"] = 0
				self.timers[mindex]["name"] = sindex
				self.timers[mindex][sindex] = {}
				self.timers[mindex][sindex]["duration"] = self.currentspell.duration
				self.timers[mindex]["nr"] = self.timers[mindex]["nr"] + 1
				
				Timex:AddSchedule("Totemus Timers "..mindex..sindex, self.currentspell.duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
				--self:SendChatMessage(string.format( self.timers[mindex][sindex]["duration"] ) )
			end
		else
			 --self:Msg("AddSpell Newmonster&spell "..mindex..sindex )
			self.currentspell.state = TOTEMUS_CONST.State.NewSpell
			self.timers[mindex] = {}
			self.timers[mindex]["nr"] = 0
			self.timers[mindex]["name"] = sindex
			self.timers[mindex][sindex] = {}
			self.timers[mindex][sindex]["duration"] = self.currentspell.duration
			self.timers[mindex]["nr"] = self.timers[mindex]["nr"] + 1
			Timex:AddSchedule("Totemus Timers "..mindex..sindex, self.currentspell.duration, nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
	        --self:SendChatMessage(string.format( sindex) )
		end 
		
	
	end,
	
	TimerRollback = function( self )
		local mindex = self.currentspell.menuslot or self.bufftype
		local sindex = self.currentspell.spelldisplay
		local i
		if( not mindex or not sindex ) then return end
		if( self.currentspell.state == TOTEMUS_CONST.State.NewMonsterNewSpell ) then
			if( self.timers[mindex] and self.timers[mindex][sindex] ) then
				self.timers[mindex][sindex]["duration"] = nil
				self.timers[mindex][sindex] = nil
				self.timers[mindex]["name"] = nil
				self.timers[mindex]["nr"] = nil
				self.timers[mindex] = nil
				Timex:DeleteSchedule( "Totemus Timers "..mindex..sindex )
			end
		elseif( self.currentspell.state == TOTEMUS_CONST.State.NewSpell ) then
			if( self.timers[mindex] and self.timers[mindex][sindex] ) then
				self.timers[mindex][sindex]["duration"] = nil
				self.timers[mindex][sindex] = nil
				self.timers[mindex]["nr"] = self.timers[mindex]["nr"] - 1
				Timex:DeleteSchedule( "Totemus Timers "..mindex..sindex )
			end
		elseif( self.currentspell.state == TOTEMUS_CONST.State.Update ) then
			Timex:DeleteSchedule( "Totemus Timers "..mindex..sindex )
			Timex:AddSchedule( "Totemus Timers "..mindex..sindex, (self.currentspell.duration - self.currentspell.oldduration), nil, nil, Totemus.TimerDeleteSpell, Totemus, mindex, sindex )
		end
	end,

	SendChatMessage = function( self, msg )
		if (GetNumRaidMembers() > 0) then
			SendChatMessage(msg, "RAID");
		elseif (GetNumPartyMembers() > 0) then
			SendChatMessage(msg, "PARTY");
		else
			SendChatMessage(msg, "SAY");
		end
	end,
	
	BuildTime = function( self, duration )
		local minute
		if( duration > 59 ) then
			minute = floor( duration / 60 )
			duration = duration - (minute *60)
		else
			minute = 0
		end
		if( minute < 10 ) then minute = "0"..minute end
		if( duration < 10 ) then duration  = "0"..duration end
		return minute..":"..duration	
	end,

	castearthtotemonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "TOP_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castearthtotemonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castfiretotemonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "TOP_RIGHT")
			GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castfiretotemonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castwatertotemonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "TOP_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castwatertotemonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castairtotemonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "TOP_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castairtotemonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castweapononenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castweapononleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castshieldonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	castshieldonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	casthearthstoneonenter = function( self, spell_name,frame )
		GameTooltip:Hide()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:AddLine(spell_name)
        GameTooltip:Show()
	end,
	casthearthstoneonleave = function( self, spell_name,frame )
		GameTooltip:Hide()
	end,

	castearthtotem = function( self, spellid )
		
		CastSpell( spellid, BOOKTYPE_SPELL )
		self.bufftype = 1
		self:TimerAddBuff(spellid)
		if( self:GetOpt("closeonclick") ) then
			self:EarthTotemClicked()
		end
		self:EarthTotemClicked()
	end,
    
	castfiretotem = function( self, spellid )
		
		CastSpell( spellid, BOOKTYPE_SPELL )
		self.bufftype = 2
		self:TimerAddBuff(spellid)
		
		if( self:GetOpt("closeonclick") ) then
			self:FireTotemClicked()
		end
		self:FireTotemClicked()
	end,
	
	castairtotem = function( self, spellid )
		
		CastSpell( spellid, BOOKTYPE_SPELL )
		self.bufftype = 3
		self:TimerAddBuff(spellid)
		
		if( self:GetOpt("closeonclick") ) then
			self:AirTotemClicked()
		end
		self:AirTotemClicked()
	end,
	
	castwatertotem = function( self, spellid )
		
		CastSpell( spellid, BOOKTYPE_SPELL )
		self.bufftype = 4
		self:TimerAddBuff(spellid)

		if( self:GetOpt("closeonclick") ) then
			self:WaterTotemClicked()
		end
		self:WaterTotemClicked()
	end,
	
	castweapon = function( self, spellid, Spellbooktab )
		
		CastSpell( spellid, BOOKTYPE_SPELL )
		self.bufftype = 6
		self:TimerAddBuff(spellid)
		
		if( self:GetOpt("closeonclick") ) then
			self:WeaponBuffClicked()
		end
		self:WeaponBuffClicked()

	end,
	
	castshield = function( self, spellid, Spellbooktab )
		self.bufftype = 5
		CastSpell( spellid, BOOKTYPE_SPELL )
		self:TimerAddBuff(spellid)
		
		if( self:GetOpt("closeonclick") ) then
			self:ShieldBuffClicked()
		end
		self:ShieldBuffClicked()
		


	end,


	casthearthstone = function( self, spellid )
	    local name, stoneloc
	
		UseContainerItem(self.hearthstone[0],self.hearthstone[1])
		--UseItemByName( "HearthStone" )
		--stoneloc =  
        --UseInventoryItem(0,1);
		if( self:GetOpt("closeonclick") ) then
			self:HearthClicked()
		end
		self:HearthClicked()
	end,
	castastral = function( self, spellid )
		CastSpellByName( "Astral Recall" )
		--	self.shieldtype = "WS"
		--	self:TimerAddBuff(spellid)
					
		if( self:GetOpt("closeonclick") ) then
			self:HearthClicked()
		end
		self:HearthClicked()
	end,

----------------------------
-- GUI Updating Functions --
----------------------------

	SetupFrames = function( self )
		local x, y, etx, ftx, wtx, atx, stx, btx
		
		self.frames = {}
		self.frames.main = CreateFrame( "Frame", nil, UIParent )
		self.frames.main.owner = self
		self.frames.main:Hide()
		self.frames.main:EnableMouse(true)
		self.frames.main:SetMovable(true)
		self.frames.main:SetWidth(1)
		self.frames.main:SetHeight(1)
		if( self:GetOpt("mainx") and self:GetOpt("mainy") ) then
			x = self:GetOpt("mainx")
			y = self:GetOpt("mainy")
			self.frames.main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y )
		else
		self.frames.main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -150)
		end
		
		-- Graphical Shardcounter
		self.frames.shard = CreateFrame( "Button", nil, self.frames.main )
		self.frames.shard.owner = self
		self.frames.shard:SetWidth(80)
		self.frames.shard:SetHeight(80)
		self.frames.shard:SetPoint("CENTER", self.frames.main, "CENTER" )
		self.frames.shard:RegisterForDrag("LeftButton")
		self.frames.shard:SetScript("OnDragStart", function() this.owner.frames.main:StartMoving() end )
		self.frames.shard:SetScript("OnDragStop",
			function() 
				this.owner.frames.main:StopMovingOrSizing()
				local _,_,_,x,y = this.owner.frames.main:GetPoint("CENTER")
				this.owner:SetOpt("mainx", x)
				this.owner:SetOpt("mainy", y)
			end
		)		
		

		-- Text inside the counter		
		self.frames.shardtext = self.frames.shard:CreateFontString(nil, "OVERLAY")
		self.frames.shardtext.owner = self
		self.frames.shardtext:SetFontObject(GameFontNormalSmall)
		self.frames.shardtext:ClearAllPoints()
		self.frames.shardtext:SetTextColor(1, 1, 1, 1) 
		self.frames.shardtext:SetWidth(80)
		self.frames.shardtext:SetHeight(80)
		self.frames.shardtext:SetPoint("TOPLEFT", self.frames.shard, "TOPLEFT")
		self.frames.shardtext:SetJustifyH("CENTER")
		self.frames.shardtext:SetJustifyV("MIDDLE")

		--shaman icon
		--self.frames.shaman = CreateFrame("Button", nil, self.frames.main )
		--self.frames.shaman.owner = self
		--self.frames.shaman:SetWidth(80)
		--self.frames.shaman:SetHeight(80)
		--self.frames.shaman:SetPoint("CENTER", self.frames.main, "CENTER", 0 , 0 )
		--self.frames.shaman:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\SphereIcon" )
		--self.frames.shaman:Show()

		-- Earth Totems button
    
		self.frames.earthtotem = CreateFrame("Button", nil, self.frames.main )
		self.frames.earthtotem.owner = self
		
		self.frames.earthtotem:SetWidth(38)
		self.frames.earthtotem:SetHeight(38)
		self.frames.earthtotem:SetPoint("CENTER", self.frames.main, "CENTER", -19.3 , 46.19 )
		self.frames.earthtotem:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_EarthElemental_Totem" )
		self.frames.earthtotem:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		
		self.frames.earthtotem:SetScript("OnClick", function() this.owner:EarthTotemClicked() end )
        self.frames.earthtotem:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Earth Totems",self.frames.earthtotem) end) 
		self.frames.earthtotem:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Earth Totems",self.frames.earthtotem) end) 
			
		 
		-- Earth totem Menu 
		self.frames.earthtotemmenu = CreateFrame("Frame", nil, self.frames.earthtotem )
		self.frames.earthtotemmenu.owner = self
		self.frames.earthtotemmenu:SetWidth(1)
		self.frames.earthtotemmenu:SetHeight(1)
		self.frames.earthtotemmenu:SetPoint("TOPRIGHT", self.frames.earthtotem, "TOPLEFT" )
		
		self.frames.earthtotemmenu:Hide()
	
		local tmp_x
	    etx = 0
		-- Stone Skin
		self.frames.sst = CreateFrame("Button", nil, self.frames.earthtotemmenu )
		self.frames.sst.owner = self
		self.frames.sst:SetWidth(38)
		self.frames.sst:SetHeight(38)
		self.frames.sst:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\spell_nature_stoneskintotem")
		self.frames.sst:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.sst:SetPoint("TOPRIGHT", self.frames.earthtotemmenu, "TOPLEFT", etx, 6.5 )
		self.frames.sst:SetScript("OnClick", function() this.owner:castearthtotem( this.owner.spells.normal["SST"] ) end )
		self.frames.sst:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Stone Skin",self.frames.sst) end) 
		self.frames.sst:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Stone Skin",self.frames.sst) end) 
		
		tmp_x = etx
		
		-- Earth Bind Skin
		if( self.spells.normal["EBT"] ) then  etx = tmp_x - 32 end
		self.frames.ebt = CreateFrame("Button", nil, self.frames.earthtotemmenu )
		self.frames.ebt.owner = self
		self.frames.ebt:SetWidth(38)
		self.frames.ebt:SetHeight(38)
		self.frames.ebt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_StrengthOfEarthTotem02")
		self.frames.ebt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.ebt:SetPoint("TOPRIGHT", self.frames.earthtotemmenu, "TOPLEFT", etx, 6.5 )
		self.frames.ebt:SetScript("OnClick", function() this.owner:castearthtotem( this.owner.spells.normal["EBT"] ) end )
		self.frames.ebt:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Earth Bind",self.frames.ebt) end)
		self.frames.ebt:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Earth Bind",self.frames.ebt) end)
		tmp_x = etx

		-- Stoneclaw Skin
        if( self.spells.normal["SCT"] ) then  etx = tmp_x - 32 end
		self.frames.sct = CreateFrame("Button", nil, self.frames.earthtotemmenu )
				
		self.frames.sct.owner = self
		self.frames.sct:SetWidth(38)
		self.frames.sct:SetHeight(38)
		self.frames.sct:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_StoneClawTotem")
		self.frames.sct:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.sct:SetPoint("TOPRIGHT", self.frames.earthtotemmenu, "TOPLEFT", etx, 6.5 )
		self.frames.sct:SetScript("OnClick", function() this.owner:castearthtotem( this.owner.spells.normal["SCT"] ) end )
		self.frames.sct:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Stone Claw",self.frames.sct) end)
		self.frames.sct:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Stone Claw",self.frames.sct) end)
		tmp_x = etx

		-- strength of earth
        if( self.spells.normal["SOET"] ) then  etx = tmp_x - 32 end
		self.frames.soe = CreateFrame("Button", nil, self.frames.earthtotemmenu )
		self.frames.soe.owner = self
		self.frames.soe:SetWidth(38)
		self.frames.soe:SetHeight(38)
		self.frames.soe:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_EarthBindTotem")
		self.frames.soe:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.soe:SetPoint("TOPRIGHT", self.frames.earthtotemmenu, "TOPLEFT", etx, 6.5 )
		self.frames.soe:SetScript("OnClick", function() this.owner:castearthtotem( this.owner.spells.normal["SOET"] ) end )	
		self.frames.soe:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Strength of Earth",self.frames.soe) end)
		self.frames.soe:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Strength of Earth",self.frames.soe) end)
       	tmp_x = etx
		
		-- TRET Skin
		if( self.spells.normal["TRET"] ) then  etx = tmp_x -32 end
		self.frames.tret = CreateFrame("Button", nil, self.frames.earthtotemmenu )
		self.frames.tret.owner = self
		self.frames.tret:SetWidth(38)
		self.frames.tret:SetHeight(38)
		self.frames.tret:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_TremorTotem")
		self.frames.tret:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.tret:SetPoint("TOPRIGHT", self.frames.earthtotemmenu, "TOPLEFT", etx, 6.5 )
		self.frames.tret:SetScript("OnClick", function() this.owner:castearthtotem( this.owner.spells.normal["TRET"] ) end )		
		self.frames.tret:SetScript("OnEnter", function() this.owner:castearthtotemonenter("Tremor Totem",self.frames.tret) end)
		self.frames.tret:SetScript("OnLeave", function() this.owner:castearthtotemonleave("Tremor Totem",self.frames.tret) end)
		tmp_x = etx		

		-- Fire Totem button
		local tmp_x
	    ftx = 0

		self.frames.firetotem = CreateFrame("Button", nil, self.frames.main )
		self.frames.firetotem.owner = self
		self.frames.firetotem:SetWidth(38)
		self.frames.firetotem:SetHeight(38)
		self.frames.firetotem:SetPoint("CENTER", self.frames.main, "CENTER", -46.19, 19.13 )
		self.frames.firetotem:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Fire_Elemental_Totem" )
		self.frames.firetotem:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.firetotem:SetScript("OnClick", function() this.owner:FireTotemClicked() end )
		self.frames.firetotem:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Fire Totems",self.frames.firetotem) end)
		self.frames.firetotem:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Fire Totems",self.frames.firetotem) end)

		-- fire totem Menu 
		self.frames.firetotemmenu = CreateFrame("Frame", nil, self.frames.firetotem )
		self.frames.firetotemmenu.owner = self
		self.frames.firetotemmenu:SetWidth(1)
		self.frames.firetotemmenu:SetHeight(1)
		self.frames.firetotemmenu:SetPoint("TOPRIGHT", self.frames.firetotem, "TOPLEFT" )
		self.frames.firetotemmenu:Hide()
	
		-- searing
		self.frames.seat = CreateFrame("Button", nil, self.frames.firetotemmenu )
		self.frames.seat.owner = self
		self.frames.seat:SetWidth(38)
		self.frames.seat:SetHeight(38)
		self.frames.seat:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Fire_SearingTotem")
		self.frames.seat:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.seat:SetPoint("TOPRIGHT", self.frames.firetotemmenu, "TOPLEFT", ftx, 0 )
		self.frames.seat:SetScript("OnClick", function() this.owner:castfiretotem( this.owner.spells.normal["SEAT"] ) end )		
		self.frames.seat:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Searing",self.frames.seat) end)
		self.frames.seat:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Searing",self.frames.seat) end)
				
		-- Fire nova Skin	
		tmp_x = ftx
		if( self.spells.normal["FNT"] ) then  ftx = tmp_x - 32 end

		self.frames.fnt = CreateFrame("Button", nil, self.frames.firetotemmenu )
		self.frames.fnt.owner = self
		self.frames.fnt:SetWidth(38)
		self.frames.fnt:SetHeight(38)
		self.frames.fnt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Fire_SealOfFire")
		self.frames.fnt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.fnt:SetPoint("TOPRIGHT", self.frames.firetotemmenu, "TOPLEFT", ftx, 0 )
		self.frames.fnt:SetScript("OnClick", function() this.owner:castfiretotem( this.owner.spells.normal["FNT"] ) end )
		self.frames.fnt:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Fire Nova",self.frames.fnt) end)
		self.frames.fnt:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Fire Nova",self.frames.fnt) end)

		-- Frost Resist
		tmp_x = ftx
		if( self.spells.normal["FROT"] ) then  ftx = tmp_x - 32 end

		self.frames.frot = CreateFrame("Button", nil, self.frames.firetotemmenu )
		self.frames.frot.owner = self
		self.frames.frot:SetWidth(38)
		self.frames.frot:SetHeight(38)
		self.frames.frot:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_FrostResistanceTotem_01")
		self.frames.frot:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.frot:SetPoint("TOPRIGHT", self.frames.firetotemmenu, "TOPLEFT", ftx, 0 )
		self.frames.frot:SetScript("OnClick", function() this.owner:castfiretotem( this.owner.spells.normal["FROT"] ) end )	
		self.frames.frot:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Frost Resist",self.frames.frot) end)
		self.frames.frot:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Frost Resist",self.frames.frot) end)

		-- magma
		tmp_x = ftx
		if( self.spells.normal["MAGT"] ) then  ftx = tmp_x - 32 end

		self.frames.magt = CreateFrame("Button", nil, self.frames.firetotemmenu )
		self.frames.magt.owner = self
		self.frames.magt:SetWidth(38)
		self.frames.magt:SetHeight(38)
		self.frames.magt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Fire_SelfDestruct")
		self.frames.magt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.magt:SetPoint("TOPRIGHT", self.frames.firetotemmenu, "TOPLEFT", ftx, 0 )
		self.frames.magt:SetScript("OnClick", function() this.owner:castfiretotem( this.owner.spells.normal["MAGT"] ) end )
		self.frames.magt:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Magma",self.frames.magt) end)
		self.frames.magt:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Magma",self.frames.magt) end)
		
		
		-- Flametongue Skin
		tmp_x = ftx
		if( self.spells.normal["FTT"] ) then  ftx = tmp_x - 32 end
		
		self.frames.ftt = CreateFrame("Button", nil, self.frames.firetotemmenu )
		self.frames.ftt.owner = self
		self.frames.ftt:SetWidth(38)
		self.frames.ftt:SetHeight(38)
		self.frames.ftt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_GuardianWard")
		self.frames.ftt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.ftt:SetPoint("TOPRIGHT", self.frames.firetotemmenu, "TOPLEFT", ftx, 0 )
		self.frames.ftt:SetScript("OnClick", function() this.owner:castfiretotem( this.owner.spells.normal["FTT"] ) end )
		self.frames.ftt:SetScript("OnEnter", function() this.owner:castfiretotemonenter("Flametongue",self.frames.ftt) end)
		self.frames.ftt:SetScript("OnLeave", function() this.owner:castfiretotemonleave("Flametongue",self.frames.ftt) end)
		
	

		-- Air Totem button
		self.frames.airtotem = CreateFrame("Button", nil, self.frames.main )
		self.frames.airtotem.owner = self
		self.frames.airtotem:SetWidth(38)
		self.frames.airtotem:SetHeight(38)
		self.frames.airtotem:SetPoint("CENTER", self.frames.main, "CENTER", -19.13, -46.19 )
		self.frames.airtotem:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_Cyclone" )
		self.frames.airtotem:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.airtotem:SetScript("OnClick", function() this.owner:AirTotemClicked() end )
		self.frames.airtotem:SetScript("OnEnter", function() this.owner:castairtotemonenter("Air Totems",self.frames.airtotem) end)
		self.frames.airtotem:SetScript("OnLeave", function() this.owner:castairtotemonleave("Air Totems",self.frames.airtotem) end)

		-- Air totem Menu 
		self.frames.airtotemmenu = CreateFrame("Frame", nil, self.frames.airtotem )
		self.frames.airtotemmenu.owner = self
		self.frames.airtotemmenu:SetWidth(1)
		self.frames.airtotemmenu:SetHeight(1)
		self.frames.airtotemmenu:SetPoint("TOPRIGHT", self.frames.airtotem, "TOPLEFT" )
		self.frames.airtotemmenu:Hide()
		
		local tmp_x
	    atx = 0

		-- grounding
		self.frames.grdt = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.grdt.owner = self
		self.frames.grdt:SetWidth(38)
		self.frames.grdt:SetHeight(38)
		self.frames.grdt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_GroundingTotem")
		self.frames.grdt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.grdt:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.grdt:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["GRDT"] ) end )	
        self.frames.grdt:SetScript("OnEnter", function() this.owner:castairtotemonenter("Grounding",self.frames.grdt) end)
		self.frames.grdt:SetScript("OnLeave", function() this.owner:castairtotemonleave("Grounding",self.frames.grdt) end)

		-- Nat Resist
		tmp_x = atx
		if( self.spells.normal["NRT"] ) then  atx = tmp_x - 32 end

		self.frames.nrt = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.nrt.owner = self
		self.frames.nrt:SetWidth(38)
		self.frames.nrt:SetHeight(38)
		self.frames.nrt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_NatureResistanceTotem")
		self.frames.nrt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.nrt:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.nrt:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["NRT"] ) end )	
        self.frames.nrt:SetScript("OnEnter", function() this.owner:castairtotemonenter("Nature Resist",self.frames.nrt) end)
		self.frames.nrt:SetScript("OnLeave", function() this.owner:castairtotemonleave("Nature Resist",self.frames.nrt) end)
		
		-- WFT
		tmp_x = atx
		if( self.spells.normal["WFT"] ) then  atx = tmp_x - 32 end

		self.frames.wft = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.wft.owner = self
		self.frames.wft:SetWidth(38)
		self.frames.wft:SetHeight(38)
		self.frames.wft:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_Windfury")
		self.frames.wft:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.wft:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.wft:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["WFT"] ) end )	
        self.frames.wft:SetScript("OnEnter", function() this.owner:castairtotemonenter("Windfury",self.frames.wft) end)
		self.frames.wft:SetScript("OnLeave", function() this.owner:castairtotemonleave("Windfury",self.frames.wft) end)

		-- snetry
		tmp_x = atx
		if( self.spells.normal["SENT"] ) then  atx = tmp_x - 32 end

		self.frames.sent = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.sent.owner = self
		self.frames.sent:SetWidth(38)
		self.frames.sent:SetHeight(38)
		self.frames.sent:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_RemoveCurse")
		self.frames.sent:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.sent:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.sent:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["SENT"] ) end )	
        self.frames.sent:SetScript("OnEnter", function() this.owner:castairtotemonenter("Sentry",self.frames.sent) end)
		self.frames.sent:SetScript("OnLeave", function() this.owner:castairtotemonleave("Sentry",self.frames.sent) end)

		-- WWT
		tmp_x = atx
		if( self.spells.normal["WWT"] ) then  atx = tmp_x - 32 end
		
		self.frames.wwt = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.wwt.owner = self
		self.frames.wwt:SetWidth(38)
		self.frames.wwt:SetHeight(38)
		self.frames.wwt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_EarthBind")
		self.frames.wwt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.wwt:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.wwt:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["WWT"] ) end )	
        self.frames.wwt:SetScript("OnEnter", function() this.owner:castairtotemonenter("Wind Wall",self.frames.wwt) end)
		self.frames.wwt:SetScript("OnLeave", function() this.owner:castairtotemonleave("Wind Wall",self.frames.wwt) end)

		-- Grace of Air
		tmp_x = atx
		if( self.spells.normal["GOAT"] ) then  atx = tmp_x - 32 end

		self.frames.goat = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.goat.owner = self
		self.frames.goat:SetWidth(38)
		self.frames.goat:SetHeight(38)
		self.frames.goat:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_InvisibilityTotem")
		self.frames.goat:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.goat:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.goat:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["GOAT"] ) end )	
        self.frames.goat:SetScript("OnEnter", function() this.owner:castairtotemonenter("Grace of Air",self.frames.goat) end)
		self.frames.goat:SetScript("OnLeave", function() this.owner:castairtotemonleave("Grace of Air",self.frames.goat) end)
	
		-- tranquil
		tmp_x = atx
		if( self.spells.normal["TRAC"] ) then  atx = tmp_x - 32 end
		
		self.frames.trac = CreateFrame("Button", nil, self.frames.airtotemmenu )
		self.frames.trac.owner = self
		self.frames.trac:SetWidth(38)
		self.frames.trac:SetHeight(38)
		self.frames.trac:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_Brilliance")
		self.frames.trac:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.trac:SetPoint("TOPRIGHT", self.frames.airtotemmenu, "TOPLEFT", atx, -6.5 )
		self.frames.trac:SetScript("OnClick", function() this.owner:castairtotem( this.owner.spells.normal["TRAC"] ) end )	
        self.frames.trac:SetScript("OnEnter", function() this.owner:castairtotemonenter("Tranquil",self.frames.trac) end)
		self.frames.trac:SetScript("OnLeave", function() this.owner:castairtotemonleave("Tranquil",self.frames.trac) end)

		-- Water Totem button
		self.frames.watertotem = CreateFrame("Button", nil, self.frames.main )
		self.frames.watertotem.owner = self
		self.frames.watertotem:SetWidth(38)
		self.frames.watertotem:SetHeight(38)
		self.frames.watertotem:SetPoint("CENTER", self.frames.main, "CENTER", -46.19, -19.3  )
		self.frames.watertotem:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Spear_04" )
		self.frames.watertotem:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.watertotem:SetScript("OnClick", function() this.owner:WaterTotemClicked() end )
		self.frames.watertotem:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Water Totems",self.frames.firetotem) end)
		self.frames.watertotem:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Water Totems",self.frames.firetotem) end)
		
		self.frames.watertotemb = CreateFrame("Button", nil, self.frames.main )
		self.frames.watertotemb.owner = self
		self.frames.watertotemb:SetWidth(38)
		self.frames.watertotemb:SetHeight(38)
		self.frames.watertotemb:SetPoint("CENTER", self.frames.main, "CENTER", -40, -9 )
		--self.frames.watertotemb:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Spear_04" )
		
		local tmp_x
	    wtx = 0

		-- Water totem menu
		self.frames.watertotemmenu = CreateFrame("Frame", nil, self.frames.watertotem )
		self.frames.watertotemmenu.owner = self
		self.frames.watertotemmenu:SetWidth(1)
		self.frames.watertotemmenu:SetHeight(1)
		self.frames.watertotemmenu:SetPoint("TOPRIGHT", self.frames.watertotem, "TOPLEFT" )
		self.frames.watertotemmenu:Hide()
	
		-- healing stream totem

		self.frames.hst = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.hst.owner = self
		self.frames.hst:SetWidth(38)
		self.frames.hst:SetHeight(38)
		self.frames.hst:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Spear_04")
		self.frames.hst:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.hst:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.hst:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["HST"] ) end)
        self.frames.hst:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Healing Stream",self.frames.hst) end)
		self.frames.hst:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Healing Stream",self.frames.hst) end)

		-- posion totem
		tmp_x = wtx
		if( self.spells.normal["PCT"] ) then  wtx = tmp_x - 32 end

		self.frames.pct = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.pct.owner = self
		self.frames.pct:SetWidth(38)
		self.frames.pct:SetHeight(38)
		self.frames.pct:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_PoisonCleansingTotem")
		self.frames.pct:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.pct:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.pct:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["PCT"] ) end )		
        self.frames.pct:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Poison Cleanse",self.frames.pct) end)
		self.frames.pct:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Poison Cleanse",self.frames.pct) end)

		-- Mana stream totem
		tmp_x = wtx
		if( self.spells.normal["MST"] ) then  wtx = tmp_x - 32 end

		self.frames.mst = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.mst.owner = self
		self.frames.mst:SetWidth(38)
		self.frames.mst:SetHeight(38)
		self.frames.mst:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_ManaRegenTotem")
		self.frames.mst:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.mst:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.mst:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["MST"] ) end)
        self.frames.mst:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Mana Stream",self.frames.mst) end)
		self.frames.mst:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Mana Stream",self.frames.mst) end)
		
		-- FIRE Re totem
		tmp_x = wtx
		if( self.spells.normal["FRT"] ) then  wtx = tmp_x - 32 end
		
		self.frames.frt = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.frt.owner = self
		self.frames.frt:SetWidth(38)
		self.frames.frt:SetHeight(38)
		self.frames.frt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_FireResistanceTotem_01")
		self.frames.frt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.frt:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.frt:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["FRT"] ) end )	
        self.frames.frt:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Fire Resist",self.frames.frt) end)
		self.frames.frt:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Fire Resist",self.frames.frt) end)
		
		-- disease totem
		tmp_x = wtx
		if( self.spells.normal["DCT"] ) then  wtx = tmp_x - 32 end

		self.frames.dct = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.dct.owner = self
		self.frames.dct:SetWidth(38)
		self.frames.dct:SetHeight(38)
		self.frames.dct:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_DiseaseCleansingTotem")
		self.frames.dct:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.dct:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.dct:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["DCT"] ) end )		
        self.frames.dct:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Disease Cleanse",self.frames.dct) end)
		self.frames.dct:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Disease Cleanse",self.frames.dct) end)

		-- mana tide totem
		tmp_x = wtx
		if( self.spells.normal["MTT"] ) then  wtx = tmp_x - 32 end

		self.frames.mtt = CreateFrame("Button", nil, self.frames.watertotemmenu )
		self.frames.mtt.owner = self
		self.frames.mtt:SetWidth(38)
		self.frames.mtt:SetHeight(38)
		self.frames.mtt:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Frost_SummonWaterElemental")
		self.frames.mtt:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.mtt:SetPoint("TOPRIGHT", self.frames.watertotemmenu, "TOPLEFT", wtx, 0 )
		self.frames.mtt:SetScript("OnClick", function() this.owner:castwatertotem( this.owner.spells.normal["MTT"] ) end)
        self.frames.mtt:SetScript("OnEnter", function() this.owner:castwatertotemonenter("Mana Tide",self.frames.mtt) end)
		self.frames.mtt:SetScript("OnLeave", function() this.owner:castwatertotemonleave("Mana Tide",self.frames.mtt) end)


		-- Hearth  Totem button

		-- Mount button
		--[[self.frames.mount = CreateFrame("Button", nil, self.frames.main )
		self.frames.mount.owner = self
		self.frames.mount:SetWidth(38)
		self.frames.mount:SetHeight(38)
		self.frames.mount:SetPoint("CENTER", self.frames.main, "CENTER", 24, -36 )
		self.frames.mount:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\EmptyButton" )
		self.frames.mount:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.mount:SetScript("OnClick", function() this.owner:MountClicked() end ) --]]

		-- Pots button
		--self.frames.armor = CreateFrame("Button", nil, self.frames.main )
		--self.frames.armor.owner = self
		--self.frames.armor:SetWidth(38)
		--self.frames.armor:SetHeight(38)
		--self.frames.armor:SetPoint("CENTER", self.frames.main, "CENTER", 0, 45 )
		--self.frames.armor:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Potion_50" )
		--self.frames.armor:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		--self.frames.armor:SetScript("OnClick", function() this.owner:ArmorClicked() end )

		self.frames.hearth = CreateFrame("Button", nil, self.frames.main )
		self.frames.hearth.owner = self
		self.frames.hearth:RegisterForClicks("LeftButtonUp","RightButtonUp")
		self.frames.hearth:SetWidth(38)
		self.frames.hearth:SetHeight(38)
		self.frames.hearth:SetPoint("CENTER", self.frames.main, "CENTER", 19.13, 46.19 )
		self.frames.hearth:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Misc_Rune_01" )
		self.frames.hearth:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.hearth:SetScript("OnClick", function() this.owner:HearthClicked() end )
		self.frames.hearth:SetScript("OnEnter", function() this.owner:casthearthstoneonenter("GTFO",self.frames.hearth) end)
		self.frames.hearth:SetScript("OnLeave", function() this.owner:casthearthstoneonleave("GTFO",self.frames.hearth) end)

		-- hearth menu
		self.frames.hearthbuffmenu = CreateFrame("Frame", nil, self.frames.hearth )
		self.frames.hearthbuffmenu.owner = self
		self.frames.hearthbuffmenu:SetWidth(1)
		self.frames.hearthbuffmenu:SetHeight(1)
		self.frames.hearthbuffmenu:SetPoint("TOPRIGHT", self.frames.hearth, "TOPRIGHT" )
		self.frames.hearthbuffmenu:Hide()

		self.frames.stone = CreateFrame("Button", nil, self.frames.hearthbuffmenu )
		self.frames.stone.owner = self
		self.frames.stone:SetWidth(38)
		self.frames.stone:SetHeight(38)
		self.frames.stone:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\INV_Misc_Rune_01")
		self.frames.stone:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.stone:SetPoint("TOPRIGHT", self.frames.hearthbuffmenu, "TOPRIGHT", 32, 6.5 )
		self.frames.stone:SetScript("OnClick", function() this.owner:casthearthstone( this.owner.spells.normal["HEARTHSTONE"] ) end )		
		self.frames.stone:SetScript("OnEnter", function() this.owner:casthearthstoneonenter("Hearth",self.frames.stone) end)
		self.frames.stone:SetScript("OnLeave", function() this.owner:casthearthstoneonleave("Hearth",self.frames.stone) end)

	
		self.frames.astral = CreateFrame("Button", nil, self.frames.hearthbuffmenu )
		self.frames.astral.owner = self
		self.frames.astral:SetWidth(38)
		self.frames.astral:SetHeight(38)
		self.frames.astral:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_AstralRecal")
		self.frames.astral:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.astral:SetPoint("TOPRIGHT", self.frames.hearthbuffmenu, "TOPRIGHT", 64, 6.5 )
		self.frames.astral:SetScript("OnClick", function() this.owner:castastral( this.owner.spells.normal["ASTRAL"] ) end )		
		self.frames.astral:SetScript("OnEnter", function() this.owner:casthearthstoneonenter("Astral Recall",self.frames.astral) end)
		self.frames.astral:SetScript("OnLeave", function() this.owner:casthearthstoneonleave("Astral Recall",self.frames.astral) end)

		
		-- Weapon Buffs button
		self.frames.weaponbuff = CreateFrame("Button", nil, self.frames.main )
		self.frames.weaponbuff.owner = self
		self.frames.weaponbuff:SetWidth(38)
		self.frames.weaponbuff:SetHeight(38)
		self.frames.weaponbuff:SetPoint("CENTER", self.frames.main, "CENTER", 46.19, 19.13)
		self.frames.weaponbuff:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_ShamanRage" )
		self.frames.weaponbuff:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.weaponbuff:SetScript("OnClick", function() this.owner:WeaponBuffClicked() end )
		self.frames.weaponbuff:SetScript("OnEnter", function() this.owner:castweapononenter("Weapon Buffs",self.frames.weaponbuff) end)
		self.frames.weaponbuff:SetScript("OnLeave", function() this.owner:castweapononleave("Weapon Buffs",self.frames.weaponbuff) end)

		-- Weapon Buff menu
		self.frames.weaponbuffmenu = CreateFrame("Frame", nil, self.frames.weaponbuff )
		self.frames.weaponbuffmenu.owner = self
		self.frames.weaponbuffmenu:SetWidth(1)
		self.frames.weaponbuffmenu:SetHeight(1)
		self.frames.weaponbuffmenu:SetPoint("TOPRIGHT", self.frames.weaponbuff, "TOPRIGHT" )
		self.frames.weaponbuffmenu:Hide()

		self.frames.rbw = CreateFrame("Button", nil, self.frames.weaponbuffmenu )
		self.frames.rbw.owner = self
		self.frames.rbw:SetWidth(38)
		self.frames.rbw:SetHeight(38)
		self.frames.rbw:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_RockBiter")
		self.frames.rbw:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.rbw:SetPoint("TOPRIGHT", self.frames.weaponbuffmenu, "TOPRIGHT", 32, 0 )
		self.frames.rbw:SetScript("OnClick", function() this.owner:castweapon( this.owner.spells.normal["RBW"] ) end )		
        self.frames.rbw:SetScript("OnEnter", function() this.owner:castweapononenter("Rockbiter",self.frames.rbw) end)
		self.frames.rbw:SetScript("OnLeave", function() this.owner:castweapononleave("Rockbiter",self.frames.rbw) end)
		
		self.frames.ftw = CreateFrame("Button", nil, self.frames.weaponbuffmenu )
		self.frames.ftw.owner = self
		self.frames.ftw:SetWidth(38)
		self.frames.ftw:SetHeight(38)
		self.frames.ftw:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Fire_FlameTounge")
		self.frames.ftw:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.ftw:SetPoint("TOPRIGHT", self.frames.weaponbuffmenu, "TOPRIGHT", 64, 0 )
		self.frames.ftw:SetScript("OnClick", function() this.owner:castweapon( this.owner.spells.normal["FTW"] ) end )		
		self.frames.ftw:SetScript("OnEnter", function() this.owner:castweapononenter("Flametongue",self.frames.ftw) end)
		self.frames.ftw:SetScript("OnLeave", function() this.owner:castweapononleave("Flametongue",self.frames.ftw) end)
		
		self.frames.frbw = CreateFrame("Button", nil, self.frames.weaponbuffmenu )
		self.frames.frbw.owner = self
		self.frames.frbw:SetWidth(38)
		self.frames.frbw:SetHeight(38)
		self.frames.frbw:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Frost_FrostBrand")
		self.frames.frbw:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.frbw:SetPoint("TOPRIGHT", self.frames.weaponbuffmenu, "TOPRIGHT", 96, 0 )
		self.frames.frbw:SetScript("OnClick", function() this.owner:castweapon( this.owner.spells.normal["FRBW"] ) end )		
		self.frames.frbw:SetScript("OnEnter", function() this.owner:castweapononenter("Frostband",self.frames.frbw) end)
		self.frames.frbw:SetScript("OnLeave", function() this.owner:castweapononleave("Frostband",self.frames.frbw) end)
		
		self.frames.wfw = CreateFrame("Button", nil, self.frames.weaponbuffmenu )
		self.frames.wfw.owner = self
		self.frames.wfw:SetWidth(38)
		self.frames.wfw:SetHeight(38)
		self.frames.wfw:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_Windfury")
		self.frames.wfw:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.wfw:SetPoint("TOPRIGHT", self.frames.weaponbuffmenu, "TOPRIGHT", 128, 0 )
		self.frames.wfw:SetScript("OnClick", function() this.owner:castweapon( this.owner.spells.normal["WFW"] ) end )		
		self.frames.wfw:SetScript("OnEnter", function() this.owner:castweapononenter("Windfury",self.frames.wfw) end)
		self.frames.wfw:SetScript("OnLeave", function() this.owner:castweapononleave("Windfury",self.frames.wfw) end)
		
		-- Shield Buffs button
		self.frames.shieldbuff = CreateFrame("Button", nil, self.frames.main )
		self.frames.shieldbuff.owner = self
		self.frames.shieldbuff:SetWidth(38)
		self.frames.shieldbuff:SetHeight(38)
		self.frames.shieldbuff:SetPoint("CENTER", self.frames.main, "CENTER", 46.19, -19.13 )
		self.frames.shieldbuff:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_LightningShield" )
		self.frames.shieldbuff:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.shieldbuff:SetScript("OnClick", function() this.owner:ShieldBuffClicked() end )
		self.frames.shieldbuff:SetScript("OnEnter", function() this.owner:castshieldonenter("Shields",self.frames.shieldbuff) end)
		self.frames.shieldbuff:SetScript("OnLeave", function() this.owner:castshieldonleave("Shields",self.frames.shieldbuff) end)

		-- Shield Buff menu
		self.frames.shieldbuffmenu = CreateFrame("Frame", nil, self.frames.shieldbuff )
		self.frames.shieldbuffmenu.owner = self
		self.frames.shieldbuffmenu:SetWidth(1)
		self.frames.shieldbuffmenu:SetHeight(1)
		self.frames.shieldbuffmenu:SetPoint("TOPRIGHT", self.frames.shieldbuff, "TOPRIGHT" )
		self.frames.shieldbuffmenu:Hide()
		stx = 32

		self.frames.ls = CreateFrame("Button", nil, self.frames.shieldbuffmenu )
		self.frames.ls.owner = self
		self.frames.ls:SetWidth(38)
		self.frames.ls:SetHeight(38)
		self.frames.ls:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_LightningShield")
		self.frames.ls:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.ls:SetPoint("TOPRIGHT", self.frames.shieldbuffmenu, "TOPRIGHT", stx, 0 )
		self.frames.ls:SetScript("OnClick", function() this.owner:castshield( this.owner.spells.normal["LS"] ) end )		
		self.frames.ls:SetScript("OnEnter", function() this.owner:castshieldonenter("Lighting Sheild",self.frames.shieldbuff) end)
		self.frames.ls:SetScript("OnLeave", function() this.owner:castshieldonleave("Lighting Shield",self.frames.shieldbuff) end)

		tmp_x = stx
		if( self.spells.normal["WS"] ) then  stx = tmp_x + 32 end
	
		self.frames.ws = CreateFrame("Button", nil, self.frames.shieldbuffmenu )
		self.frames.ws.owner = self
		self.frames.ws:SetWidth(38)
		self.frames.ws:SetHeight(38)
		self.frames.ws:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Ability_Shaman_WaterShield")
		self.frames.ws:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.ws:SetPoint("TOPRIGHT", self.frames.shieldbuffmenu, "TOPRIGHT", stx, 0 )
		self.frames.ws:SetScript("OnClick", function() this.owner:castshield( this.owner.spells.normal["WS"] ) end )		
		self.frames.ws:SetScript("OnEnter", function() this.owner:castshieldonenter("Water Shield",self.frames.shieldbuff) end)
		self.frames.ws:SetScript("OnLeave", function() this.owner:castshieldonleave("Water Shield",self.frames.shieldbuff) end)

		tmp_x = stx
		if( self.spells.normal["ES"] ) then  stx = tmp_x + 32 end

		self.frames.es = CreateFrame("Button", nil, self.frames.shieldbuffmenu )
		self.frames.es.owner = self
		self.frames.es:SetWidth(38)
		self.frames.es:SetHeight(38)
		self.frames.es:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Spell_Nature_SkinofEarth")
		self.frames.es:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )
		self.frames.es:SetPoint("TOPRIGHT", self.frames.shieldbuffmenu, "TOPRIGHT", stx, 0 )
		self.frames.es:SetScript("OnClick", function() this.owner:castshield( this.owner.spells.normal["ES"] ) end )		
		self.frames.es:SetScript("OnEnter", function() this.owner:castshieldonenter("Earth",self.frames.shieldbuff) end)
		self.frames.es:SetScript("OnLeave", function() this.owner:castshieldonleave("Earth",self.frames.shieldbuff) end)


		-- Spelltimers
		self.frames.timers = CreateFrame("Button", nil, self.frames.main )
		self.frames.timers.owner = self
		self.frames.timers:SetMovable(true)
		self.frames.timers:EnableMouse(true)
		self.frames.timers:SetWidth(150)
		self.frames.timers:SetHeight(25)
		self.frames.timers:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
                                            tile = false, tileSize = 16, edgeSize = 16, 
                                            insets = { left = 5, right =5, top = 5, bottom = 5 }})


		self.frames.timers:SetBackdropColor( 0.7, 0, 0.7, 1 )
		self.frames.timers:SetBackdropBorderColor( 1, 1, 1, 1)
		if( self:GetOpt("timerx") and self:GetOpt("timery") ) then
			x = self:GetOpt("timerx")
			y = self:GetOpt("timery")
			self.frames.timers:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y )
		else
			self.frames.timers:SetPoint("TOPLEFT", self.frames.main, "BOTTOM", 60, 40)
		end
		self.frames.timers:RegisterForDrag("LeftButton")
		self.frames.timers:SetScript("OnDragStart", function() this:StartMoving() end )
		self.frames.timers:SetScript("OnDragStop", 
			function() 
				this:StopMovingOrSizing()
				local _,_,_,x,y = this:GetPoint("TOPLEFT")
				this.owner:SetOpt("timerx", x)
				this.owner:SetOpt("timery", y)
			end
		)
		
		self.frames.timersheader = self.frames.timers:CreateFontString(nil, "OVERLAY")
		self.frames.timersheader.owner = self
		self.frames.timersheader:SetFontObject(GameFontNormalSmall)
		self.frames.timersheader:ClearAllPoints()
		self.frames.timersheader:SetTextColor(0.8, 0.8, 1, 1)
		self.frames.timersheader:SetPoint("CENTER", self.frames.timers, "CENTER", 0, 1 )
		self.frames.timersheader:SetJustifyH("CENTER")
		self.frames.timersheader:SetJustifyV("MIDDLE")
		self.frames.timersheader:SetText( TOTEMUS_CONST.Timerheader )

		
		self.frames.timerstext = self.frames.timers:CreateFontString(nil, "OVERLAY")
		self.frames.timerstext.owner = self
		self.frames.timerstext:SetFontObject(GameFontNormalSmall)
		self.frames.timerstext:ClearAllPoints()
		self.frames.timerstext:SetTextColor(0.8, 0.8, 1, 1)
		self.frames.timerstext:SetPoint("TOPLEFT", self.frames.timers, "TOPLEFT", 10, -6 )
		self.frames.timerstext:SetJustifyH("LEFT")
		self.frames.timerstext:SetJustifyV("MIDDLE")
		self.frames.timerstext:SetWidth(200)
		self.frames.timerstext:SetText( "" )

		self:UpdateFrameLocks()
	end,

	UpdateShardCount = function( self )
		mana_perc = math.floor((UnitMana('player') * 16 / UnitManaMax('player')) + 0.5);
		mana_string = (math.floor((UnitMana('player') * 100 / UnitManaMax('player')) + 0.5))..'%\n'..UnitMana('player');
		self.shardcount = mana_string
		if( mana_perc >= 16 ) then
		    self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard16") 
		elseif ( mana_perc < 16 ) and ( mana_perc >= 15 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard15") 
		elseif ( mana_perc < 15 ) and ( mana_perc >= 14 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard14") 
		elseif ( mana_perc < 14 ) and ( mana_perc >= 13 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard13") 
		elseif ( mana_perc < 13 ) and ( mana_perc >= 12 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard12") 
		elseif ( mana_perc < 12 ) and ( mana_perc >= 11 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard11") 
		elseif ( mana_perc < 11 ) and ( mana_perc >= 10 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard10") 
		elseif ( mana_perc < 10 ) and ( mana_perc >= 9 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard9") 
		elseif ( mana_perc < 9 ) and ( mana_perc >= 8 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard8") 
		elseif ( mana_perc < 8 ) and ( mana_perc >= 7 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard7") 
		elseif ( mana_perc < 7 ) and ( mana_perc >= 6 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard6") 
		elseif ( mana_perc < 6 ) and ( mana_perc >= 5 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard5") 
		elseif ( mana_perc < 5 ) and ( mana_perc >= 4 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard4") 
		elseif ( mana_perc < 4 ) and ( mana_perc >= 3 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard3") 
		elseif ( mana_perc < 3 ) and ( mana_perc >= 2 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard2") 
		elseif ( mana_perc < 2 ) and ( mana_perc >= 1 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard1") 
		elseif ( mana_perc < 1 ) and ( mana_perc >= 0 ) then
			self.frames.shard:SetNormalTexture( "Interface\\AddOns\\Totemus\\Images\\Solid\\Shards\\Shard0") 
		end
		
		self.frames.shardtext:SetText(""..self.shardcount )		
	end,

	UpdateOtherButtons = function( self ) 
	
	--stength of earth
	if( not self.spells.normal["SOET"] ) then
			self.frames.soe:Hide()
		else
			self.frames.soe:Show()
	end

	-- stone claw
	if( not self.spells.normal["SCT"] ) then
			self.frames.sct:Hide()
		else
			self.frames.sct:Show()
	end
		
	--stone skin
	if( not self.spells.normal["SST"] ) then
			self.frames.sst:Hide()
		else
			self.frames.sst:Show()
	end
	--tremor totem
	if( not self.spells.normal["TRET"] ) then
			self.frames.tret:Hide()
		else
			self.frames.tret:Show()
	end
	--earth bind
	if( not self.spells.normal["EBT"] ) then
			self.frames.ebt:Hide()
		else
			self.frames.ebt:Show()
	end
	-- frost resist
	if( not self.spells.normal["FROT"] ) then
			self.frames.frot:Hide()
		else
			self.frames.frot:Show()
	end
	-- healing stream
	if( not self.spells.normal["HST"] ) then
			self.frames.hst:Hide()
		else
			self.frames.hst:Show()
	end
	-- mana spring
	if( not self.spells.normal["MST"] ) then
			self.frames.mst:Hide()
		else
			self.frames.mst:Show()
	end
	--mana tide
	if( not self.spells.normal["MTT"] ) then
			self.frames.mtt:Hide()
		else
			self.frames.mtt:Show()
	end
	-- disease
	if( not self.spells.normal["DCT"] ) then
			self.frames.dct:Hide()
		else
			self.frames.dct:Show()
	end
	-- grace of air
	if( not self.spells.normal["GOAT"] ) then
			self.frames.goat:Hide()
		else
			self.frames.goat:Show()
	end
	-- nature
	if( not self.spells.normal["NRT"] ) then
			self.frames.nrt:Hide()
		else
			self.frames.nrt:Show()
	end
	-- wind fury
	if( not self.spells.normal["WFT"] ) then
			self.frames.wft:Hide()
		else
			self.frames.wft:Show()
	end
	--wind wall
	if( not self.spells.normal["WWT"] ) then
			self.frames.wwt:Hide()
		else
			self.frames.wwt:Show()
	end
	-- fire nova 
	if( not self.spells.normal["FNT"] ) then
			self.frames.fnt:Hide()
		else
			self.frames.fnt:Show()
	end
	-- fire res 
	if( not self.spells.normal["FRT"] ) then
			self.frames.frt:Hide()
		else
			self.frames.frt:Show()
	end
	-- flame tongue
	if( not self.spells.normal["FTT"] ) then
			self.frames.ftt:Hide()
		else
			self.frames.ftt:Show()
	end
	-- tranquil
	if( not self.spells.normal["TRAC"] ) then
			self.frames.trac:Hide()
		else
			self.frames.trac:Show()
	end
	-- magma
	if( not self.spells.normal["MAGT"] ) then
			self.frames.magt:Hide()
		else
			self.frames.magt:Show()
	end
	-- searing
	if( not self.spells.normal["SEAT"] ) then
			self.frames.seat:Hide()
		else
			self.frames.seat:Show()
	end
	-- rockbiter
	if( not self.spells.normal["RBW"] ) then
			self.frames.rbw:Hide()
		else
			self.frames.rbw:Show()
	end
	-- flame tongue weaponbuff
	if( not self.spells.normal["FTW"] ) then
			self.frames.ftw:Hide()
		else
			self.frames.ftw:Show()
	end
	-- frost brand
	if( not self.spells.normal["FRBW"] ) then
			self.frames.frbw:Hide()
		else
			self.frames.frbw:Show()
	end
	-- wind fury we
	if( not self.spells.normal["WFW"] ) then
			self.frames.wfw:Hide()
		else
			self.frames.wfw:Show()
	end
	-- posion
	if( not self.spells.normal["PCT"] ) then
			self.frames.pct:Hide()
		else
			self.frames.pct:Show()
	end
	-- sentry
	if( not self.spells.normal["SENT"] ) then
			self.frames.sent:Hide()
		else
			self.frames.sent:Show()
	end
	-- grounding
	if( not self.spells.normal["GRDT"] ) then
			self.frames.grdt:Hide()
		else
			self.frames.grdt:Show()
	end

	-- lighting shield
	if( not self.spells.normal["LS"] ) then
			self.frames.ls:Hide()
		else
			self.frames.ls:Show()
	end

	-- water shield
	if( not self.spells.normal["WS"] ) then
			self.frames.ws:Hide()
		else
			self.frames.ws:Show()
	end

	-- earth shield
	if( not self.spells.normal["ES"] ) then
			self.frames.es:Hide()
		else
			self.frames.es:Show()
	end

	end,

	UpdateTimers = function( self )
		local mindex, sindex, duration, text, tleft, gradient
		
		self.timerstext = ""
		
		for mindex in pairs(self.timers) do
			if( self.timers[mindex]["name"] ) then
				self.timerstext = self.timerstext .. "\n\n".."|cffffffff"..self.timers[mindex]["name"].."|r"
				for sindex in pairs(self.timers[mindex]) do
					if( sindex ~= "name" and sindex ~= "nr" ) then
						duration = Timex:ScheduleCheck("Totemus Timers "..mindex..sindex, TRUE)
						--duration = 30
						if( duration ) then
							-- tleft = floor(self.timers[mindex][sindex]["duration"] - duration)
							tleft = floor( duration )
							text = self:BuildTime(tleft)
							gradient = self:GetGradient( floor((tleft/self.timers[mindex][sindex]["duration"])*100) )
							self.timerstext = self.timerstext .. "   "..gradient.." "..text.."|r"
						else
							self.timerstext = self.timerstext .. "\n  "..sindex.." no timer "
						end
					end
				end
			end
		end
		
		self.frames.timerstext:SetText(self.timerstext)
	end,

	UpdateButtons = function( self )
		--self:UpdateShardCount()
		--self:UpdateHealthstone()
		--self:UpdateSoulstone()
		--self:UpdateFirestone()
		--self:UpdateSpellstone()

		self:UpdateOtherButtons()
	end,

	UpdateFrameLocks = function( self )
		if( self:GetOpt("lock") ) then
			self.frames.timers:SetMovable(false)
			self.frames.timers:SetBackdrop(nil)
			self.frames.timers:SetBackdropColor(0,0,0,0)
			self.frames.timers:SetBackdropBorderColor(0,0,0,0)
			self.frames.main:SetMovable(false)
			self.frames.timers:RegisterForDrag()
			self.frames.shard:RegisterForDrag()
		else
			self.frames.timers:SetMovable(true)
			self.frames.timers:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
	                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
	                                            tile = false, tileSize = 16, edgeSize = 16, 
	                                            insets = { left = 5, right =5, top = 5, bottom = 5 }})
			self.frames.timers:SetBackdropColor( 0.00,	0.44,	0.87, 1 )
			self.frames.timers:SetBackdropBorderColor( 1, 1, 1, 1)
			self.frames.main:SetMovable(true)
			self.frames.timers:RegisterForDrag("LeftButton")
			self.frames.shard:RegisterForDrag("LeftButton")
		end
	end,
----------------------------
-- ButtonClicks           --
----------------------------

	HealthstoneClicked = function( self )
		if( self.healthstone[0] ~= nil ) then
			if( UnitExists("target") and UnitIsPlayer("target") and not UnitIsEnemy("target", "player") and UnitName("target") ~= UnitName("player") ) then
				if( not UnitCanCooperate("player", "target")) then
					self:Msg( TOTEMUS_CONST.Message.Busy )
				elseif (not CheckInteractDistance("target",2)) then
					self:Msg( TOTEMUS_CONST.Message.TooFarAway )
				else
					PickupContainerItem( self.healthstone[0], self.healthstone[1] )
					if ( CursorHasItem() ) then
						DropItemOnUnit("target")
						Timex:AddSchedule("Totemus Healthstone Trade", 3, nil, nil, "AcceptTrade", "" )
					end
				end
			elseif( (UnitHealth("player") < UnitHealthMax("player")) and GetContainerItemCooldown(self.healthstone[0],self.healthstone[1]) == 0) then
				UseContainerItem( self.healthstone[0], self.healthstone[1] )
			end
		else
			CastSpell( self.spells.normal["HEALTHSTONE"], BOOKTYPE_SPELL )
		end
	end,



	EarthTotemClicked = function( self )
	    --if( self.spells.normal["EARTH"] ) then
		--	CastSpell( self.spells.normal["EARTH"], BOOKTYPE_SPELL )
		--end
		if ( self.frames.earthtotemmenu.opened ) then
			self.frames.earthtotemmenu:Hide()
			self.frames.earthtotemmenu.opened = FALSE
		else
			self.frames.earthtotemmenu:Show()
			self.frames.earthtotemmenu.opened = TRUE
		end
	end,

    ETOnEnter = function(self)
        GameTooltip:Hide()
        GameTooltip:SetOwner(self.frames.earthtotemmenu, "ANCHOR_RIGHT")
        --GameTooltip:AddLine("|cFFFFFFFF" .. self.frames.earthtotemmenu.tooltipTitle)
        GameTooltip:AddLine("Earth Totems")
        GameTooltip:Show()
    end,
	
	ETOnExit = function(self)
        GameTooltip:Hide() 
    end,

	FireTotemClicked = function( self )
	    --if( self.spells.normal["EARTH"] ) then
		--	CastSpell( self.spells.normal["EARTH"], BOOKTYPE_SPELL )
		--end
		if( self.frames.firetotemmenu.opened ) then
			self.frames.firetotemmenu:Hide()
			self.frames.firetotemmenu.opened = FALSE
		else
			self.frames.firetotemmenu:Show()
			self.frames.firetotemmenu.opened = TRUE
		end
	end,

	AirTotemClicked = function( self )
	    --if( self.spells.normal["EARTH"] ) then
		--	CastSpell( self.spells.normal["EARTH"], BOOKTYPE_SPELL )
		--end
		if( self.frames.airtotemmenu.opened ) then
			self.frames.airtotemmenu:Hide()
			self.frames.airtotemmenu.opened = FALSE
		else
			self.frames.airtotemmenu:Show()
			self.frames.airtotemmenu.opened = TRUE
		end
	end,

	WaterTotemClicked = function( self )
	    --if( self.spells.normal["EARTH"] ) then
		--	CastSpell( self.spells.normal["EARTH"], BOOKTYPE_SPELL )
		--end
		if( self.frames.watertotemmenu.opened ) then
			self.frames.watertotemmenu:Hide()
			self.frames.watertotemmenu.opened = FALSE
		else
			self.frames.watertotemmenu:Show()
			self.frames.watertotemmenu.opened = TRUE
		end
	end,
	
	WeaponBuffClicked = function( self )
	    --if( self.spells.normal["EARTH"] ) then
		--	CastSpell( self.spells.normal["EARTH"], BOOKTYPE_SPELL )
		--end
		if( self.frames.weaponbuffmenu.opened ) then
			self.frames.weaponbuffmenu:Hide()
			self.frames.weaponbuffmenu.opened = FALSE
		else
			self.frames.weaponbuffmenu:Show()
			self.frames.weaponbuffmenu.opened = TRUE
		end
	end,
	
	ShieldBuffClicked = function( self )
		if( self.frames.shieldbuffmenu.opened ) then
			self.frames.shieldbuffmenu:Hide()
			self.frames.shieldbuffmenu.opened = FALSE
		else
			self.frames.shieldbuffmenu:Show()
			self.frames.shieldbuffmenu.opened = TRUE
		end
	end,
	
	MountClicked = function( self )
		if( self.spells.normal["MOUNT"] ) then
			CastSpell( self.spells.normal["MOUNT"], BOOKTYPE_SPELL )
		end
	end,
	
	HearthClicked = function( self, LeftButton )
		
	if( self.frames.hearthbuffmenu.opened ) then
			self.frames.hearthbuffmenu:Hide()
			self.frames.hearthbuffmenu.opened = FALSE
		else
			self.frames.hearthbuffmenu:Show()
			self.frames.hearthbuffmenu.opened = TRUE
		end
	    
	end,
	
			
----------------------------
-- WoW Event Handlers     --
----------------------------

	BAG_UPDATE = function( self )		
		local bag = arg1
		Timex:AddSchedule("Totemus Bag Update", 0.5, nil, nil, "Totemus_BAG_UPDATE", Totemus )
	end,

	SPELLS_CHANGED = function( self )
		self:ScanSpells()
		self:UpdateButtons()
	end,

	SPELLCAST_START = function( self )
		-- self:Msg("SPELLCAST_START: "..arg1 )
		if( self.currentspell.state ) then
			if( self.currentspell.state == TOTEMUS_CONST.State.Cast ) then
				self.currentspell.state = TOTEMUS_CONST.State.Start
				-- we have started casting
			else
				-- I want nothing do do with this cast
				self.Compost:Erase(self.currentspell)
			end
		end
		self.soulstonestate = nil
		if( arg1 == TOTEMUS_CONST.Pattern.SoulstoneResurrection ) then
			if( UnitName("target") ) then
				self.soulstonetimer = 1
				self.soulstonetarget = "["..UnitLevel("target").."] "..UnitName("target")
				self.soulstonename = UnitName("target")
				self:SendChatMessage(string.format( TOTEMUS_CONST.Message.PreSoulstone, UnitName("target") ) )
				
			end
		elseif( arg1 == TOTEMUS_CONST.Pattern.RitualOfSummoning ) then
			if( UnitName("target") ) then
				self:SendChatMessage(string.format( TOTEMUS_CONST.Message.PreSummon, UnitName("target") ) )
				self.presummoncount = self.shardcount
				self.summoning = true
				self.summonvictim = UnitName("target")
			end
		end
	end,

	SPELLCAST_FAILED = function( self )
		-- self:Msg("SPELLCAST_FAILED" )
		if( self.currentspell.state ) then
			self.currentspell.state = TOTEMUS_CONST.State.Failed
		end
	end,

	SPELLCAST_STOP = function( self )
		-- self:Msg("SPELLCAST_STOP" )
		if( self.currentspell.state and self.currentspell.state < TOTEMUS_CONST.State.Stop ) then
			self.currentspell.state = TOTEMUS_CONST.State.Stop
			self:TimerAddSpell()
		end
		if( self.soulstonetimer and self.soulstonetimer == 1 ) then
			self.soulstonetimer = 2
			self.soulstonestate = 1
			Timex:AddSchedule("Totemus Soulstone Timer", 1800, nil, nil, Totemus.DeleteSoulstoneTimer, Totemus )
			self:SendChatMessage(string.format( TOTEMUS_CONST.Message.Soulstone, self.soulstonename ) )		
		end
	end,

	SPELLCAST_INTERRUPTED = function( self )
		 self:Msg("SPELLCAST_INTERRUPTED" )
		if( self.currentspell.state and self.currentspell.state > TOTEMUS_CONST.State.Stop ) then
			self:TimerRollback()
		end
		if( self.soulstonetimer and self.soulstonestate ) then
			self.soulstonetimer = nil
			self.soulstonestate = nil
			Timex:DeleteSchedule("Totemus Soulstone Timer")
			self:SendChatMessage( TOTEMUS_CONST.Message.SoulstoneAborted )
		end
	end,

	SPELLCAST_CHANNEL_START = function( self )
		-- self:Msg("SPELLCAST_CHANNEL_START: "..arg1)
		if( self.currentspell.state ) then
			if( self.currentspell.state == TOTEMUS_CONST.State.Cast ) then
				self.currentspell.state = TOTEMUS_CONST.State.Start
				-- we have started casting
			end
		end
	end,

	SPELLCAST_CHANNEL_STOP = function( self )
		-- self:Msg("SPELLCAST_CHANNEL_STOP")
		if( self.summoning ) then
			self:ScanStones()
			if( self.shardcount >= self.summoncount ) then
				-- failed summoning
				self:SendChatMessage( string.format( TOTEMUS_CONST.Message.FailedSummon, self.summonvictim) )
			end
			self.summoning = nil
		end
	end,

	PLAYER_REGEN_ENABLED = function( self )
		self:ClearTimers()
	end,

	CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = function( self )
		if( self:GetOpt("shadowtrancesound") and string.find( arg1, TOTEMUS_CONST.Pattern.ShadowTrance ) ) then
			PlaySoundFile("Interface\\AddOns\\Totemus\\Sounds\\ShadowTrance.mp3")
		end
	end,

	CHAT_MSG_SPELL_SELF_DAMAGE = function( self )
		if( self.currentspell.state and self.currentspell.state > TOTEMUS_CONST.State.Stop ) then
			if( string.find( arg1, TOTEMUS_CONST.Pattern.Resisted ) or 
				string.find( arg1, TOTEMUS_CONST.Pattern.Immune ) ) then
				self:TimerRollback()
			end
		end		
	end,

----------------------------
-- My Event Handlers      --
----------------------------

	Totemus_BAG_UPDATE = function( self )
		self:ScanHearth()
		--self:UpdateShardCount()
		--self:UpdateHealthstone()
		--self:UpdateSoulstone()
		--self:UpdateSpellstone()
		--self:UpdateFirestone()
	end,


	Heartbeat = function( self)
		self:UpdateTimers()
		self:UpdateShardCount()
	end,

----------------------------
-- My Hooks               --
----------------------------
	
	OnCastSpell = function( self, spellid, spellbooktab )
		-- self:Msg( "OnCastSpell: "..spellid..", "..spellbooktab)

		self:CallHook("CastSpell", spellid, spellbooktab )

		if( self.spells.timedid[spellid] ) then
			self:RegisterSpellCast( self.spells.timedid[spellid] )
		end

	end,

	OnCastSpellByName = function( self, spellname )
		-- self:Msg("OnCastSpellByName: "..spellname )

		self:CallHook("CastSpellByName", spellname )

		if( self.spells.timed[strlower(spellname)] ) then
			self:RegisterSpellCast( strlower(spellname) )
		elseif( self.spells.timedname[strlower(spellname)] ) then
			self:RegisterSpellCast( self.spells.timedname[strlower(spellname)] )
		end

	end,

	OnUseAction = function( self, actionid, a2, a3)
		-- self:Msg("OnUseAction: "..actionid )

		self:CallHook("UseAction", actionid, a2, a3 )

		TotemusTooltip:SetAction(actionid)

		local lefttext = TotemusTooltipTextLeft1:GetText()
		local righttext = TotemusTooltipTextRight1:GetText()

		if( lefttext ) then

			if( righttext ) then
				righttext = lefttext.." "..righttext
			else
				righttext = lefttext
			end
			
			lefttext = strlower( lefttext )
			righttext = strlower( righttext )

			if( self.spells.timed[lefttext] ) then
				self:RegisterSpellCast( lefttext )
			elseif( self.spells.timed[righttext] ) then
				self:RegisterSpellCast( righttext ) 
			end
		end


	end,

	-- Not using this for now
	OnUseContainerItem = function( self, index, slot )
		self:Msg("OnUseContainerItem: "..index..", "..slot )
		return self:CallHook("UseContainerItem", index, slot )
	end,

----------------------------
-- Chat       	          --
----------------------------

	chatReset = function( self )
		self.frames.main:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -150)
		self.frames.timers:SetPoint("TOPLEFT", self.frames.main, "BOTTOM", 60, 40)
	end,

	chatFelDom = function( self, modifier ) 
		if( modifier == "ctrl" ) then
			self:SetOpt("feldommodifier", "ctrl")
		elseif( modifier == "alt" ) then
			self:SetOpt("feldommodifier", "alt") 
		elseif( modifier == "shift" ) then
			self:SetOpt("feldommodifier", "shift") 
		elseif( modifier == "none" ) then
			self:SetOpt("feldommodifier", nil )
		else
			self:Msg( TOTEMUS_CONST.Chat.FelDomValid )
		end
		if( self:GetOpt("feldommodifier") ) then
			self:Msg( TOTEMUS_CONST.Chat.FelDomModifier .. self:GetOpt("feldommodifier") )
		else
			self:Msg( TOTEMUS_CONST.Chat.FelDomModifier .. "none" )
		end
	end,


	chatCloseClick = function( self )
		self:TogOpt("closeonclick")
		self:Msg(TOTEMUS_CONST.Chat.CloseOnClick, ACEG_MAP_ONOFF[self:GetOpt("closeonclick") or 0])		
	end,


	chatShadowTranceSound = function( self )
		self:TogOpt("shadowtrancesound")
		self:Msg(TOTEMUS_CONST.Chat.ShadowTranceSound, ACEG_MAP_ONOFF[self:GetOpt("shadowtrancesound") or 0])
	end,
	
	chatSoulstoneSound = function( self )
		self:TogOpt("soulstonesound")
		self:Msg(TOTEMUS_CONST.Chat.SoulstoneSound, ACEG_MAP_ONOFF[self:GetOpt("soulstonesound") or 0])
	end,

	chatTimers = function( self )
		self:TogOpt("timers")
		self:Msg(TOTEMUS_CONST.Chat.Timers, ACEG_MAP_ONOFF[self:GetOpt("timers") or 0])
		if( self:GetOpt("timers") ) then
			self.Metrognome:Start("Totemus")
			self.frames.timers:Show()
		else
			self.Metrognome:Stop("Totemus")
			self.frames.timers:Hide()
		end
	end,


	chatLock = function( self )
		self:TogOpt("lock")
		self:Msg(TOTEMUS_CONST.Chat.Lock, ACEG_MAP_ONOFF[self:GetOpt("lock") or 0])
		self:UpdateFrameLocks()
	end,

	chatTexture = function( self, texture )
		if( texture == "default" ) then
			self:SetOpt("texture", nil)
		elseif( texture == "blue" ) then
			self:SetOpt("texture", "Blue")
		elseif( texture == "orange" ) then
			self:SetOpt("texture", "Orange")
		elseif( texture == "rose" ) then
			self:SetOpt("texture", "Rose")
		elseif( texture == "turquoise" ) then
			self:SetOpt("texture", "Turquoise")
		elseif( texture == "violet" ) then
			self:SetOpt("texture", "Violet")
		elseif( texture == "x" ) then
			self:SetOpt("texture", "X")
		else
			self:Msg( TOTEMUS_CONST.Chat.TextureValid )
		end
		if( self:GetOpt("texture") ) then
			self:Msg( TOTEMUS_CONST.Chat.Texture .. self:GetOpt("texture") )
		else
			self:Msg( TOTEMUS_CONST.Chat.Texture .. "default" )
		end
		--self:UpdateShardCount()
	end,




	Report = function( self )
		if( self:GetOpt("texture") ) then
			self:Msg( TOTEMUS_CONST.Chat.Texture .. self:GetOpt("texture") )
		else
			self:Msg( TOTEMUS_CONST.Chat.Texture .. "default" )
		end
		if( self:GetOpt("feldommodifier") ) then
			self:Msg( TOTEMUS_CONST.Chat.FelDomModifier .. self:GetOpt("feldommodifier") )
		else
			self:Msg( TOTEMUS_CONST.Chat.FelDomModifier .. "none" )
		end
		self:Msg(TOTEMUS_CONST.Chat.CloseOnClick, ACEG_MAP_ONOFF[self:GetOpt("closeonclick") or 0])
		self:Msg(TOTEMUS_CONST.Chat.SoulstoneSound, ACEG_MAP_ONOFF[self:GetOpt("soulstonesound") or 0])
		self:Msg(TOTEMUS_CONST.Chat.ShadowTranceSound, ACEG_MAP_ONOFF[self:GetOpt("shadowtrancesound") or 0])
		self:Msg(TOTEMUS_CONST.Chat.Lock, ACEG_MAP_ONOFF[self:GetOpt("lock") or 0])
	end,

	-- Command Reporting Closures

	GetOpt = function(self, path, var)
		if (not var) then var = path; path = nil; end
		local profilePath = path and {self.profilePath, path} or self.profilePath;
	   
		return self.db:get(profilePath, var)
	end,
	
	SetOpt = function(self, path, var, val)
		if (not val) then val = var; var = path; path = nil; end
		local profilePath = path and {self.profilePath, path} or self.profilePath;
	
		return self.db:set(profilePath, var, val)
	end,
	
	TogOpt = function(self, path, var)
		if (not var) then var = path; path = nil; end
		local profilePath = path and {self.profilePath, path} or self.profilePath;
	
		return self.db:toggle(profilePath, var)
	end,

	Msg = function(self, ...)
	   self.cmd:result(Totemus_MSG_COLOR, unpack(arg))
	end,
	
	Result = function(self, text, val, map)
	   if( map ) then val = map[val or 0] or val end
	   self.cmd:result(Totemus_MSG_COLOR, text, " ", ACEG_TEXT_NOW_SET_TO, " ",
		       format(Totemus_DISPLAY_OPTION, val or ACE_CMD_REPORT_NO_VAL)
		       )
	end,

	
	TogMsg = function(self, var, text)
	   local val = self:TogOpt(var)
	   self:Result(text, val, ACEG_MAP_ONOFF)
	   return val
	end,
	
	Error = function(self, ...)
	   local text = "";
	   for i=1,getn(arg) do
	      text = text .. arg[i]
	   end
	   error(Totemus_MSG_COLOR .. text, 2)
	end,
	
	
})


----------------------------------
--			Load this bitch up!			--
----------------------------------
Totemus:RegisterForLoad()

