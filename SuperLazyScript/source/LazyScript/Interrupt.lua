lazyScript.metadata:updateRevisionFromKeyword("$Revision: 622 $")

-- Interrupt support

lazyScript.interrupt = {}

lazyScript.interrupt.targetCasting = nil
lazyScript.interrupt.castingDetectedAt = 0
lazyScript.interrupt.lastSpellInterrupted = nil


function lazyScript.interrupt.OnChatMsgSpell(arg1)
	local tName = UnitName("target")
	local spellCastOtherStart = lazyScript.getLocaleString("SPELLCASTOTHERSTART")
	local spellPerformOtherStart = lazyScript.getLocaleString("SPELLPERFORMOTHERSTART")
	if (not spellCastOtherStart) or (not spellPerformOtherStart) then
		lazyScript.d(INTERRUPTS_NOT_SUPPORTED)
		return
	end
	if (tName) then
		for idx, pat in ipairs({ spellCastOtherStart, spellPerformOtherStart }) do
			for mob, spell in string.gfind(arg1, pat) do
				if (mob == tName) then
					lazyScript.d(DETECTED_YOUR_TARGET..spell..SUGGEST_INTERRUPT)
					if (lazyScript.perPlayerConf.showTargetCasts) then
						lazyScript.p(tName..IS_CASTING..spell..".")
					end
					lazyScript.interrupt.targetCasting = spell
					lazyScript.interrupt.castingDetectedAt = GetTime()
					return
				end
			end
		end
	end
end

-- custom superwow integration; see modules/superwow.lua
function lazyScript.interrupt.OnSuperWoWSpell(spell, event)
	if not spell or type(spell) ~= "string" then return end
	if event == "START" then
		local tName = UnitName("target")
		lazyScript.d(DETECTED_YOUR_TARGET..spell..SUGGEST_INTERRUPT)
		if lazyScript.perPlayerConf and lazyScript.perPlayerConf.showTargetCasts and tName then
            lazyScript.p("SuperWoW: "..tName..IS_CASTING..spell..".")
        end
		lazyScript.interrupt.targetCasting = spell
		lazyScript.interrupt.castingDetectedAt = GetTime()
		return
	end

	-- terminate interrupt attempt when
	if event == "CAST" or event == "CHANNEL" or event == "FAIL" then
		if event == "FAIL" then
			local tName = UnitName("target")
			-- this is not suitable. fail event triggers if target dies while casting
			lazyScript.interrupt.lastSpellInterrupted = spell
			if lazyScript.perPlayerConf and lazyScript.perPlayerConf.showTargetCasts and tName then
            	lazyScript.p("SuperWoW: "..tName.." has failed to cast "..spell..".")
        	end
		end
		
		lazyScript.interrupt.targetCasting = nil
        lazyScript.interrupt.castingDetectedAt = 0
		return
	end
end


-- Interrupt Criteria Edit Box

lazyScript.interruptEditBox = {}

lazyScript.interruptEditBox.cancelEdit = false

function lazyScript.interruptEditBox.OnShow()
	local text = table.concat(lsConf.interruptExceptionCriteria, "\n")
	LazyScriptInterruptExceptionCriteriaEditFrameForm:SetText(text)
end

function lazyScript.interruptEditBox.OnHide()
	if (lazyScript.interruptEditBox.cancelEdit) then
		lazyScript.interruptEditBox.cancelEdit = false
		return
	end
	
	local text = LazyScriptInterruptExceptionCriteriaEditFrameForm:GetText()
	
	local args = {}
	for arg in string.gfind(text, "[^\r\n]+") do
		table.insert(args, arg)
	end
	lsConf.interruptExceptionCriteria = args
	
	lazyScript.p(GLOBAL_INTERRUPT_CRITERIA_UPDATED)
	lazyScript.masks.parsingInterruptExceptionCriteria = true
	lazyScript.parsedInterruptExceptionCriteriaCache = lazyScript.ParseForm("interruptExceptionCriteria", lsConf.interruptExceptionCriteria)
	lazyScript.masks.parsingInterruptExceptionCriteria = false
end