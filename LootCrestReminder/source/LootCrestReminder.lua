-- Bosses in Turtle DB that drop crests of valor, crests of heroism and the items for the MC weekely Q.
local lootCrestReminder = CreateFrame("Frame", "lootCrestReminder")
LootCrestReminderDB = LootCrestReminderDB or {}
--variables to track the frame and animation state
local LootAlertFrame = nil
local fadeStartTime = nil
local totalDuration = 15 -- 15 seconds total
local fadeSpeed = 2 -- How fast the fade cycles (lower = slower)
local soundTimes = {0, 3, 6, 9, 12}
local playedSounds = {}
local LootCrestReminderSound = true

-- ######## NEED TO ADD A CHECK FOR QUEST COMPLETE AND DO NOT SHOW REMINDER
-- ####### LOOTING CREST SHOULD STOP THE REMINDER

lootCrestReminder.Bosses = {
    --Test
    'Earthborer', 'Molten Elemental',
    --Hateforge Quarry 50-60
    'High Foreman Bargul Blackhammer', 'Har\'gesh Doomcaller',

    --Temple of Atal’Hakkar – 55-60
    'Shade of Eranikus',

    --Blackrock Depths – 52-60
    'Emperor Dagran Thaurissan', 'Ambassador Flamelash',
    --Lower Blackrock Spire – 55-60
    'Mother Smolderweb', 'Overlord Wyrmthalak', 'Highlord Omokk', 'Urok Doomhowl', 'Quartermaster Zigris', 'Halycon', 'Gizrul the Slavener', 'War Master Voone', 'Shadon Hunter Vosh\'gajin',

    --Upper Blackrock Spire – 55-60
    'Jed Runewatcher', 'Gyth', 'Warchief Rend Blackhand',
    'Pyroguard Emberseer', 'Solakar Flamewreath', 'Goraluk Anvilcrack',
    'The Beast', 'General Drakkisath',

    --Dire Maul – 55-60

    'Guard Mol\'dar', 'Stomper Kreeg', 'Guard Fengus', 'Guard Slip\'kik', 'Captain Kromcrush', 'Cho\'Rush the Observer', 'King Gordok',
    'Pusilin', 'Zevrim Thornhoof', 'Hydrospawn', 'Alzzin the Wildshaper',
    'Tendris Warpwood', 'Illyanna Ravenoak', 'Magister Kalendris', 'Immol\'thar', 'Prince Tortheldrin',

    --Scholomance – 58 - 60
    'Marduk Blackpool', 'Doctor Theolen Krastinov', 'Lorekeeper Polkelt', 'The Ravenian', 'Darkmaster Gandling', 'Jandice Barov', 'Rattlegore', 
    'Instructor Malicia', 'Vectus', 'Ras Frostwhisper', 'Lady Illucia Barov', 'Lord Alexei Barov',

    --Stratholme – 58 - 60
    'The Unforgiven', 'Cannon Master Wiley', 'Grand Crusader Dathrohan', 'Timmy the Cruel',
    'Archivist Galford', 'Malor the Zealous', 'Hearthsinger Forresten', 'Skul',
    'Magistrate Barthilas', 'Ramstein the Gorger', 'Nerub\'enkan', 'Maleki the Pallid', 'Baroness Anastari', 'Baron Rivendare', 'Stonespire',

    --Zul'Gurub
    'High Priestess Jeklik', 'High Priest Venoxis', 'High Priestess Mar\'li', 'High Priest Thekal',
    'High Priestess Arlokk', 'Gahz\'ranka', 'Gri\'lek', 'Renataki', 'Wushoolay', 'Hakkar the Soulflayer',

    --Ruins of Ahn'Qiraj
    'Kurinnaxx', 'General Rajaxx', 'Moam', 'Buru the Gorger', 'Ayamiss the Hunter', 'Ossirian the Unscarred',

    --Molten Core
    'Incindis', 'Sourcerer-Thane Thaurissan',
}

lootCrestReminder:Hide()

lootCrestReminder:RegisterEvent("ADDON_LOADED")
lootCrestReminder:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")

lootCrestReminder:RegisterEvent("PLAYER_TARGET_CHANGED")

lootCrestReminder:SetScript("OnEvent", function()

    if event == "ADDON_LOADED" and arg1 == "LootCrestReminder" then        
        -- Initialize saved variables if they don't exist
        if not LootCrestReminderDB.framePosition then
            LootCrestReminderDB.framePosition = {
                point = "CENTER",
                relativeTo = "UIParent",
                relativePoint = "CENTER",
                xOffset = 0,
                yOffset = 0
            }
        end
    end

    if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        for i, boss in lootCrestReminder.Bosses do
            if arg1 == boss .. ' dies.' then
                if QuestChecker then
                    local currentZone = GetRealZoneText()
                    if currentZone == "Zul'Gurrub" or currentZone == "Ruins of Ahn'Qiraj" or currentZone == "Lower Karazhan Halls" then
                        ShowLootAlert("Crest of Heroism")
                    elseif currentZone == "Molten Core" then
                        ShowLootAlert("for Molten Assault quest")
                    elseif currentZone == "Ragefire Chasm" then
                        ShowLootAlert("Sword of a Thousand Truths")
                    else -- Dungeon quest
                        ShowLootAlert("Crest of Valor")
                    end
                end
                return true
            end
        end
    end

    if event == "PLAYER_TARGET_CHANGED" and UnitName("player") == "Shamdamage" then
        print("Target change test")
        if QuestChecker then
            print("We have one of the required quests")
            ShowLootAlert("Crest of Valor")
        end
    end

end)

-- Slash command registrations
SLASH_LCR1 = "/lcr"
SLASH_LCR2 = "/lootcrestreminder"

SlashCmdList["LCR"] = function(cmd)
    if cmd == "sound" then
        -- Toggle sound setting
        LootCrestReminderSound = not LootCrestReminderSound
        if LootCrestReminderSound then
            print("|cFFFFFF00[LCR]|r Sound effects |cFF00FF00enabled|r")
        else
            print("|cFFFFFF00[LCR]|r Sound effects |cFFFF0000disabled|r")
        end
    elseif cmd == "help" or cmd == "" then
        -- Show help information
        print("|cFFFFFF00[Loot Crest Reminder]|r Available commands:")
        print("|cFFFFFF00/lcr sound|r - Toggle sound effects on/off")
        print("|cFFFFFF00/lcr help|r - Show this help message")
        print(" ")
        print("Current settings:")
        if LootCrestReminderSound then
            print("Sound effects: |cFF00FF00enabled|r")
        else
            print("Sound effects: |cFFFF0000disabled|r")
        end
    else
        print("|cFFFFFF00[LCR]|r Unknown command. Type |cFFFFFF00/lcr help|r for available commands.")
    end
end


function QuestChecker() -- maybe supply name as an input param?
    local targetQuests = {"Call to Arms: Dungeon Delving", "Call to Arms: Cleansing the Corruption", "Call to Arms: Molten Assault"}
    
    -- Get the number of quests in the player's quest log
    local numQuests = GetNumQuestLogEntries()
    
    -- Loop through all quests in the quest log
    for i = 1, numQuests do
        -- Select the quest at index i
        SelectQuestLogEntry(i)
        
        -- Get the quest ID for the selected quest
        local questID = GetQuestLogSelection()

        local title, level, questTag, isHeader, _, isComplete = GetQuestLogTitle(questID)
        if not isHeader then
            --print("Quest Name is: " .. title)
        end
        
        -- Check if this quest ID matches any of our target IDs
        for j = 1, table.getn(targetQuests) do
            if title == targetQuests[j] then
                return true
            end
        end
    end
    
    -- If we get here, none of the target quests were found
    return false
end

function ShowLootAlert(itemName)
    playedSounds = {}
    -- Create the frame if it doesn't exist
    if not LootAlertFrame then
        LootAlertFrame = CreateFrame("Frame", "LootAlertFrame", UIParent)
        LootAlertFrame:SetWidth(400)
        LootAlertFrame:SetHeight(100)
        
        -- Set position from saved variables
        local pos = LootCrestReminderDB.framePosition
        LootAlertFrame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.xOffset, pos.yOffset)
        
        -- Enable mouse interaction for dragging
        LootAlertFrame:EnableMouse(true)
        LootAlertFrame:SetMovable(true)
        
        -- Create the font string
        LootAlertFrame.text = LootAlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        LootAlertFrame.text:SetPoint("CENTER", LootAlertFrame, "CENTER", 0, 0)
        LootAlertFrame.text:SetText("Loot the " .. itemName)
        LootAlertFrame.text:SetTextColor(1, 1, 0, 1) -- Yellow color
        
        -- Create background for better visibility (optional)
        LootAlertFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        LootAlertFrame:SetBackdropColor(0, 0, 0, 0.8)
        LootAlertFrame:SetBackdropBorderColor(1, 1, 0, 0.8)
        
        -- Set up drag functionality with shift key requirement
        LootAlertFrame:SetScript("OnMouseDown", function()
            if IsShiftKeyDown() and arg1 == "LeftButton" then
                this:StartMoving()
            end
        end)
        
        LootAlertFrame:SetScript("OnMouseUp", function()
            if arg1 == "LeftButton" then
                this:StopMovingOrSizing()
                -- Save the new position
                SaveFramePosition()
            end
        end)
    else
        -- Update the text for existing frame
        LootAlertFrame.text:SetText("Loot the " .. itemName)
    end
    
    -- Show the frame and start the animation
    LootAlertFrame:Show()
    fadeStartTime = GetTime()
    
    -- Start the update script
    LootAlertFrame:SetScript("OnUpdate", LootAlert_OnUpdate)
end

function LootAlert_OnUpdate()
    local currentTime = GetTime()
    local elapsedTime = currentTime - fadeStartTime
    
    -- Check for sound triggers at specific intervals
    if LootCrestReminderSound then
        for i = 1, table.getn(soundTimes) do
            local soundTime = soundTimes[i]
            if elapsedTime >= soundTime and not playedSounds[soundTime] then
                PlaySoundFile("Interface\\Addons\\LootCrestReminder\\media\\Bounce.mp3")
                playedSounds[soundTime] = true
            end
        end
    end
    
    -- Check if 15 seconds have passed
    if elapsedTime >= totalDuration then
        LootAlertFrame:Hide()
        LootAlertFrame:SetScript("OnUpdate", nil)
        return
    end
    
    -- Calculate fade alpha using sine wave for smooth in/out effect
    local fadePhase = elapsedTime * fadeSpeed
    local alpha = (math.sin(fadePhase) + 1) * 0.5 -- Converts -1,1 range to 0,1
    
    -- Apply minimum alpha so text doesn't completely disappear
    alpha = math.max(alpha, 0.3)
    
    -- Set the alpha for both text and frame
    LootAlertFrame.text:SetAlpha(alpha)
    LootAlertFrame:SetAlpha(alpha * 0.8) -- Frame slightly more transparent
end

function SaveFramePosition()
    if LootAlertFrame then
        local point, relativeTo, relativePoint, xOffset, yOffset = LootAlertFrame:GetPoint()
        LootCrestReminderDB.framePosition = {
            point = point,
            relativeTo = "UIParent", -- Always save relative to UIParent for consistency
            relativePoint = relativePoint,
            xOffset = xOffset,
            yOffset = yOffset
        }
    end
end









            
