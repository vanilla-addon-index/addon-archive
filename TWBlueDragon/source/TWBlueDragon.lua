local TWBD = CreateFrame('Frame')

local TWWingsAnimation = CreateFrame("Frame")

TWBD:RegisterEvent("COMBAT_TEXT_UPDATE")
TWBD:RegisterEvent("PLAYER_REGEN_DISABLED")
TWBD:RegisterEvent("PLAYER_REGEN_ENABLED")
TWBD.combat = false

TWBD.icon = 'Interface\\Icons\\INV_Misc_Head_Dragon_Blue'
TWBD.DB_Name = 'Aura of the Blue Dragon'

TWBD.eIcon = 'Interface\\Icons\\Spell_Nature_Purge'
TWBD.eCount = 0
TWBD.eName = 'Epiphany'

TWBD.blIcon = "Interface\\Icons\\Spell_Nature_BloodLust"
TWBD.blStarted = false

TWBD.lastTimeLeft = 2000
TWBD.lastTime = 2000

TWBD.animFrame = 0
TWBD.maxAnimFrames = 40
TWBD.animate = false

TWBD:SetScript("OnUpdate", function()
    for j = 0, 8 do
        local d_timeleft = GetPlayerBuffTimeLeft(GetPlayerBuff(j, "HARMFUL"))
        local d_texture = GetPlayerBuffTexture(GetPlayerBuff(j, "HARMFUL"))

        if d_texture then
            if d_texture == TWBD.blIcon then
                if d_timeleft >= 59  and not TWBD.blStarted then
                    PlaySoundFile("Interface\\Addons\\TWBlueDragon\\sounds\\bfgdivision.ogg")
                    TWBD.blStarted = true
                end
                if d_timeleft == 1 then
                    TWBD.blStarted = false
                end
            end
        end
    end

    if not TWBD.combat then
        if getglobal('TWBlueDragon'):IsVisible() then
            getglobal('TWBlueDragon'):Hide()
        end
        return false
    end
    if TWBD.lastTime == GetTime() then
        return
    end
    for j = 0, 31 do
        local timeleft = GetPlayerBuffTimeLeft(GetPlayerBuff(j, "HELPFUL"))
        local texture = GetPlayerBuffTexture(GetPlayerBuff(j, "HELPFUL"))

        if texture then
            if texture == TWBD.icon then

                --proc during proc detection
                if math.floor(timeleft) > TWBD.lastTimeLeft then
                    TWBD.combatProcs = TWBD.combatProcs + 1
                    TWBD.animate = true
                end

                if TWBD.animate then
                    if TWBD.animFrame < TWBD.maxAnimFrames then
                        TWBD.animFrame = TWBD.animFrame + 1
                        getglobal('TWBlueDragonIcon'):SetWidth(64 + 16 * (TWBD.animFrame / TWBD.maxAnimFrames));
                        getglobal('TWBlueDragonIcon'):SetHeight(64 + 16 * (TWBD.animFrame / TWBD.maxAnimFrames));
                    else
                        TWBD.animate = false
                        TWBD.animFrame = 0
                        getglobal('TWBlueDragonIcon'):SetWidth(64);
                        getglobal('TWBlueDragonIcon'):SetHeight(64);
                    end
                end

                getglobal('TWBlueDragonTimeLeft'):SetText(math.floor(timeleft))
                getglobal('TWBlueDragonProcsPerCombat'):SetText(TWBD.combatProcs)

                TWBD.lastTimeLeft = math.floor(timeleft)
                TWBD.lastTime = GetTime()
            end
        end
    end
end)

TWBD.combatProcs = 0
TWBD.rejuvProcs = 0

TWBD:SetScript("OnEvent", function()
    if event then
        if event == "PLAYER_REGEN_ENABLED" then
            --left combat
            if TWBD.combatProcs > 0 then

                if BCS:GetManaRegen() then
                    local base, _, mp5 = BCS:GetManaRegen()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[TWBlueDragon]" .. FONT_COLOR_CODE_CLOSE .. ": " .. TWBD.combatProcs .. ' blue dragon procs for ' ..  (base+mp5) * 3 *  TWBD.combatProcs .. ' mana last fight.', 0, 1, 0)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[TWBlueDragon]" .. FONT_COLOR_CODE_CLOSE .. ": " .. TWBD.combatProcs .. ' time(s) last fight.', 0, 1, 0)
                end

            end
            if TWBD.rejuvProcs > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[TWBlueDragon]" .. FONT_COLOR_CODE_CLOSE .. ": " .. TWBD.rejuvProcs .. ' rejuv procs for '.. TWBD.rejuvProcs * 60 ..' mana last fight.', 0, 1, 0)
            end
            if TWBD.eCount > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[TWBlueDragon]" .. FONT_COLOR_CODE_CLOSE .. ": " .. TWBD.eCount .. ' Epiphany procs for '.. TWBD.eCount * 6 * 24 ..' mana last fight.', 0, 1, 0)
            end
            TWBD.combatProcs = 0
            TWBD.rejuvProcs = 0
            TWBD.combat = false
            TWBD.lastTimeLeft = 2000
            TWBD.eCount = 0
        end
        if event == "PLAYER_REGEN_DISABLED" then
            --entered combat
            TWBD.combatProcs = 0
            TWBD.rejuvProcs = 0
            TWBD.combat = true
            TWBD.eCount = 0
        end
        if event == "COMBAT_TEXT_UPDATE" and arg1 == "AURA_START" and arg2 == TWBD.eName then
            if not TWBD.combat then
                return false
            end
            TWBD.eCount = TWBD.eCount + 1
        end
        if event == "COMBAT_TEXT_UPDATE" and arg1 == "AURA_START" and arg2 == TWBD.DB_Name then
            if not TWBD.combat then
                return false
            end
            --getglobal('TWBlueDragon'):Show()
            getglobal('TWBlueDragon'):SetAlpha(0.5)
            TWBD.combatProcs = TWBD.combatProcs + 1
            TWWingsAnimation.blueDragon = true
            TWWingsAnimation:Show()
        end
        if event == "COMBAT_TEXT_UPDATE" and arg1 == "AURA_END" and arg2 == TWBD.DB_Name then
            getglobal('TWBlueDragon'):Hide()
            TWBD.lastTimeLeft = 2000

            TWWingsAnimation.blueDragon = false
            TWWingsAnimation:Hide()
        end
        if event == "COMBAT_TEXT_UPDATE" and arg1 == "MANA" then
            if arg2 == '60' then
                TWBD.rejuvProcs = TWBD.rejuvProcs + 1
            end
        end
    end
end)

TWWingsAnimation:Hide()
TWWingsAnimation.innerFocus = false
TWWingsAnimation.blueDragon = false

TWWingsAnimation.scale = 1
TWWingsAnimation.direction = 1

TWWingsAnimation:SetScript("OnShow", function()
    this.startTime = GetTime()
    if TWWingsAnimation.innerFocus then
        getglobal('TWBDWingsTTop'):Show()
    else
        getglobal('TWBDWingsTTop'):Hide()
    end
    if TWWingsAnimation.blueDragon then
        getglobal('TWBDWingsTLeft'):Show()
        getglobal('TWBDWingsTRight'):Show()
    else
        getglobal('TWBDWingsTLeft'):Hide()
        getglobal('TWBDWingsTRight'):Hide()
    end
end)

TWWingsAnimation:SetScript("OnHide", function()
    TWWingsAnimation.scale = 1
    TWWingsAnimation.direction = 1

    getglobal('TWBDWingsTTop'):Hide()
    getglobal('TWBDWingsTLeft'):Hide()
    getglobal('TWBDWingsTRight'):Hide()
end)

TWWingsAnimation:SetScript("OnUpdate", function()
    local plus = 0.02 --seconds
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        TWWingsAnimation.scale = TWWingsAnimation.scale + 0.005 * TWWingsAnimation.direction

        if TWWingsAnimation.scale >= 1.1 then
            TWWingsAnimation.direction = -1
        end
        if TWWingsAnimation.scale <= 1 then
            TWWingsAnimation.direction = 1
        end
        getglobal('TWBDWingsTLeft'):SetHeight(56 + TWWingsAnimation.scale * 200)
        getglobal('TWBDWingsTRight'):SetHeight(56 + TWWingsAnimation.scale * 200)
        getglobal('TWBDWings'):SetAlpha(2 - TWWingsAnimation.scale)
        this.startTime = GetTime()
    end
end)

function start_wings_anim()
    TWWingsAnimation.blueDragon = true
    TWWingsAnimation:Show()
end
