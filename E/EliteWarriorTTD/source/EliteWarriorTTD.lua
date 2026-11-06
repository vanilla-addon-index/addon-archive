local lastCheckTime = 0;
local checkInterval = 0.2;
EliteWarrior = EliteWarrior or {}
EliteWarriorTTDDB = EliteWarriorTTDDB or {}
EliteWarriorTTDDB.locked = EliteWarriorTTDDB.locked ~= false
EliteWarriorTTDDB.bossHistory = EliteWarriorTTDDB.bossHistory or {}
local fallbackPullStart = nil

local trackedBosses = {
    ["Ortorg the Ardent"] = true,
    ["Atressian"] = true,
    ["Onyxia"] = true
}

local activeBossName = nil
local activeBossPullStart = nil
local activeBossCheckpoints = {}


local defaultPosition = {
    point = "BOTTOMLEFT",
    relativePoint = "BOTTOMLEFT",
    x = math.floor(GetScreenWidth() * 0.475),
    y = math.floor(GetScreenHeight() * 0.21)
}

local function GetTTDPosition()
    return EliteWarriorTTDDB.position or defaultPosition
end

local ttdAnchor = CreateFrame("Frame", "EliteWarriorTTDAnchor", UIParent)
ttdAnchor:SetWidth(220)
ttdAnchor:SetHeight(120)
ttdAnchor:SetMovable(true)
ttdAnchor:EnableMouse(not EliteWarriorTTDDB.locked)
ttdAnchor:RegisterForDrag("LeftButton")
ttdAnchor:SetClampedToScreen(true)

local pos = GetTTDPosition()
ttdAnchor:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)

ttdAnchor:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

ttdAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    EliteWarriorTTDDB.position = {
        point = point,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs
    }
end)

EliteWarrior.TTD = CreateFrame("Frame", nil, UIParent);


local inCombat = false;

local textTimeTillDeath = UIParent:CreateFontString(nil,"OVERLAY","GameTooltipText")
textTimeTillDeath:SetFont("Fonts\\FRIZQT__.TTF", 99, "OUTLINE, MONOCHROME")
local textTimeTillDeathText = UIParent:CreateFontString(nil,"OVERLAY","GameTooltipText")
textTimeTillDeathText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE, MONOCHROME")

-- Globals Section
local timeSinceLastUpdate = 0;
local combatStart = GetTime();

local function TTD_Show()
    if (inCombat) then
        textTimeTillDeath:ClearAllPoints()
        textTimeTillDeath:SetPoint("BOTTOMLEFT", ttdAnchor, "BOTTOMLEFT", 0, 0)

        textTimeTillDeathText:ClearAllPoints()
        textTimeTillDeathText:SetPoint("BOTTOMLEFT", ttdAnchor, "BOTTOMLEFT", 0, 28)

        textTimeTillDeathText:SetText("Time Till Death:")
    end
end

local function TTD_Hide()
    textTimeTillDeath:SetText("-.--");
end
local function TTD_ShowMovePreview()
    textTimeTillDeath:ClearAllPoints()
    textTimeTillDeath:SetPoint("BOTTOMLEFT", ttdAnchor, "BOTTOMLEFT", 0, 0)
    textTimeTillDeath:SetText("-.--")

    textTimeTillDeathText:ClearAllPoints()
    textTimeTillDeathText:SetPoint("BOTTOMLEFT", ttdAnchor, "BOTTOMLEFT", 0, 28)
    textTimeTillDeathText:SetText("Time Till Death:")
end

local function IsTrackedBoss(name)
    return name and trackedBosses[name]
end

local function ResetActiveBoss()
    activeBossName = nil
    activeBossPullStart = nil
    activeBossCheckpoints = {}
end

local function GetHealthBucket(healthPercent)
    if not healthPercent then
        return nil
    end

    local bucket = math.floor(healthPercent / 10) * 10

    if bucket >= 100 then
        return nil
    end

    if bucket < 0 then
        bucket = 0
    end

    return bucket
end

local function StartBossTracking(targetName)
    if not IsTrackedBoss(targetName) then
        return
    end

    if activeBossName ~= targetName then
        activeBossName = targetName
        activeBossPullStart = GetTime()
        activeBossCheckpoints = {}
    end
end

local function TrackBossCheckpoint(targetName, healthPercent)
    if not IsTrackedBoss(targetName) or not activeBossPullStart then
        return
    end

    local bucket = GetHealthBucket(healthPercent)

    if not bucket or activeBossCheckpoints[bucket] then
        return
    end

    activeBossCheckpoints[bucket] = GetTime() - activeBossPullStart
end

local function SaveBossKill(targetName)
    if not IsTrackedBoss(targetName) then
        return false
    end

    EliteWarriorTTDDB.bossHistory = EliteWarriorTTDDB.bossHistory or {}

    local pullStart = activeBossPullStart or fallbackPullStart

    if not pullStart then
        return false
    end

    EliteWarriorTTDDB.bossHistory[targetName] = {
        lastKillDuration = GetTime() - pullStart,
        checkpoints = activeBossCheckpoints or {},
        killedAt = time()
    }

    fallbackPullStart = nil

    return true
end

local function GetCheckpointBasedTTD(targetName, healthPercent)
    local history = EliteWarriorTTDDB.bossHistory[targetName]

    -- First kill: ignore boss-alignment logic until we have saved history.
    if not history or not history.lastKillDuration or not history.checkpoints then
        return nil
    end

    local bucket = GetHealthBucket(healthPercent)

    if not bucket or not history.checkpoints[bucket] then
        return nil
    end

    return history.lastKillDuration - history.checkpoints[bucket]
end

-- TTD stands for Time Till Death
local function TTDLogic()
    if UnitIsEnemy("player","target") or UnitReaction("player","target") == 4 then
        local targetName = UnitName("target");
        local maxHP     = UnitHealthMax("target");
        local curHP     = UnitHealth("target");

        if not targetName or not maxHP or maxHP == 0 then
            return;
        end

        if targetName == 'Vaelastrasz the Corrupt' then
            maxHP = UnitHealthMax("target")*0.3;
        end;

        local EHealthPercent = curHP/maxHP*100;

        StartBossTracking(targetName);
        TrackBossCheckpoint(targetName, EHealthPercent);

        if EHealthPercent == 100 then
            if targetName ~= 'Spore' and
			   targetName ~= 'Fallout Slime' and
			   targetName ~= 'Plagued Champion' and
			   targetName ~= 'Living Dragonfire' and
			   targetName ~= 'Draconic Mana Gem' and
			   targetName ~= 'Onyxian Whelp' and
			   targetName ~= 'Adession' and
			   targetName ~= 'Vatryrion' and
			   targetName ~= 'Omevian' and
			   targetName ~= 'Hazerion'
			then
                -- may not want to restart combat if you tab to one of these monsters
                combatStart = GetTime();
            end
        end;
        if EHealthPercent then
            local missingHP = maxHP - curHP;
            local seconds   = timeSinceLastUpdate - combatStart; -- current length of the fight
            local checkpointRemainingSeconds = GetCheckpointBasedTTD(targetName, EHealthPercent);

			local liveTTD = (maxHP/(missingHP/seconds)-seconds)*0.90;

			if checkpointRemainingSeconds then
				remainingSeconds = (liveTTD * 0.5) + (checkpointRemainingSeconds * 0.5);
			else
				remainingSeconds = liveTTD;
			end

            if (remainingSeconds ~= remainingSeconds) then
                textTimeTillDeath:SetText("-.--")
            else
                if (remainingSeconds) then
                    textTimeTillDeath:SetText(string.format("%.2f",remainingSeconds));
                end
            end
        end
    end
end

function onUpdate(sinceLastUpdate)
    timeSinceLastUpdate = GetTime();
    if GetTime()-lastCheckTime >= checkInterval then
        if (lastCheckTime == 0) then
            lastCheckTime = GetTime();
        end
        TTDLogic();

        lastCheckTime = 0;
    end
end
EliteWarrior.TTD:SetScript("OnUpdate", function(self) if inCombat then onUpdate(timeSinceLastUpdate); end; end);

EliteWarrior.TTD:SetScript("OnShow", function(self)
    timeSinceLastUpdate = 0
end)


EliteWarrior.TTD:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
        combatStart = GetTime();
		fallbackPullStart = GetTime();
        inCombat = true;
        TTD_Show();
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false;
		combatStart = GetTime();
		TTD_Hide();
		ResetActiveBoss();
	elseif event == "PLAYER_DEAD" then
		inCombat = false;
		fallbackPullStart = nil;
		ResetActiveBoss();
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local eventType = arg2;
        local destName = arg7;

		if eventType == "UNIT_DIED" and IsTrackedBoss(destName) then
			local saved = SaveBossKill(destName);

			if saved then
				local data = EliteWarriorTTDDB.bossHistory[destName];

				if data and data.lastKillDuration then
					print(
						"EliteWarriorTTD saved kill timing for "
						.. destName
						.. ": "
						.. string.format("%.2f", data.lastKillDuration)
						.. "s"
					);
				else
					print("EliteWarriorTTD saved kill timing for " .. destName);
				end
			else
				print("EliteWarriorTTD saw death for " .. destName .. " but did not save.");
			end

			ResetActiveBoss();
		end
    end
end);

SLASH_ELITEWARRIORTTD1 = "/ttd"

SlashCmdList["ELITEWARRIORTTD"] = function(msg)
	if msg == "lock" then
		EliteWarriorTTDDB.locked = true
		ttdAnchor:EnableMouse(false)

		if not inCombat then
			TTD_Hide()
			textTimeTillDeathText:SetText("")
		end

		print("EliteWarriorTTD locked. Click-through enabled.")
	elseif msg == "unlock" then
		EliteWarriorTTDDB.locked = false
		ttdAnchor:EnableMouse(true)
		TTD_ShowMovePreview()
		print("EliteWarriorTTD unlocked. Drag the timer text to move it.")
    elseif msg == "reset" then
        EliteWarriorTTDDB.position = nil
        ttdAnchor:ClearAllPoints()
        ttdAnchor:SetPoint(defaultPosition.point, UIParent, defaultPosition.relativePoint, defaultPosition.x, defaultPosition.y)
        print("EliteWarriorTTD position reset")
	elseif msg == "history" then
		EliteWarriorTTDDB.bossHistory = EliteWarriorTTDDB.bossHistory or {}

		for bossName in pairs(trackedBosses) do
			local data = EliteWarriorTTDDB.bossHistory[bossName]

			if data and data.lastKillDuration then
				print(bossName .. " last kill: " .. string.format("%.2f", data.lastKillDuration) .. "s")
			else
				print(bossName .. " has no saved kill yet.")
			end
		end
    else
        print("/ttd unlock")
        print("/ttd lock")
        print("/ttd reset")
        print("/ttd history")
    end
end

EliteWarrior.TTD:RegisterEvent("PLAYER_REGEN_ENABLED");
EliteWarrior.TTD:RegisterEvent("PLAYER_REGEN_DISABLED");
EliteWarrior.TTD:RegisterEvent("PLAYER_DEAD");
EliteWarrior.TTD:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");