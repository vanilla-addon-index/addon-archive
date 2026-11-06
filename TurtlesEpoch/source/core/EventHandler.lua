-- TurtlesEpoch: EventHandler.lua
-- Hooks quest, gossip, and book events.
-- Extracts text after 0.1s delay, looks up NPC race, resolves quest sound paths.
-- Uses manifest hash matching as the primary resolver.

local TT = TurtlesEpoch

-- Coalescing guard: prevents multiple triggers from rapid-fire events
local delayActive = false

-- Book page tracking: ITEM_TEXT_BEGIN resets, ITEM_TEXT_READY increments
local bookPageCounter = 0

-- Quest sound path hash indexes: built at ADDON_LOADED time.
-- Keys are 8-char DJB2 hashes of quest titles; values are full manifest paths.
-- These allow fallback lookup when BuildSoundPath produces a wrong race/NPC dir.
local QUEST_HASH_INDEX = {
    quest_detail    = {},
    quest_progress  = {},
    quest_complete  = {},
    quest_greeting  = {},
}

-- NPC+dialogType index: maps "npcNorm|dialogType" -> array of all manifest paths.
-- Last-resort lookup when everything else misses.
local NPC_DIALOG_INDEX = {}

-- Normalize a quest title for resilient lookup against TT_QUEST_DETAIL_BY_NORM_TITLE.
-- Must match generate_voice.py normalize_lookup_title() exactly.
local function NormalizeLookupTitle(title)
    if not title or title == "" then return "" end
    title = strlower(title)
    -- Strip WoW color codes: |cXXXXXXXX and |r
    title = string.gsub(title, "|c%x%x%x%x%x%x%x%x", "")
    title = string.gsub(title, "|r", "")
    -- Replace non-alphanumeric non-space with space
    title = string.gsub(title, "[^%l%d%s]", " ")
    -- Collapse whitespace and trim
    title = string.gsub(title, "%s+", " ")
    title = string.gsub(title, "^%s+", "")
    title = string.gsub(title, "%s+$", "")
    return title
end

-- Normalize quest text to a compact signature for TT_QUEST_*_BY_TEXTSIG lookup.
-- Must match generate_voice.py normalize_lookup_text_sig() exactly.
-- Text content is unique per quest even when titles collide — this is the
-- authoritative fallback when quest titles alone are ambiguous.
--
-- `subRace` / `subClass` control optional player race/class substitution.
-- We can't tell from runtime text alone whether a word like "human" came from
-- a `<race>` token or was a plain noun, so the caller tries multiple variants
-- and the first hit wins. See BuildTextSigCandidates below.
local function NormalizeLookupTextSig(text, subRace, subClass)
    if not text or text == "" then return "" end

    -- Escape Lua pattern special chars so player values are matched literally.
    local function escapePat(s)
        return string.gsub(s, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    end

    text = strlower(text)
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")

    -- Player NAME → "name" (always — names are unique enough not to collide).
    local playerName = UnitName("player") or ""
    if playerName ~= "" then
        text = string.gsub(text, escapePat(strlower(playerName)), "name")
    end

    -- Optional: player RACE → "race" (for <race>-token quests).
    if subRace then
        local playerRace = UnitRace("player") or ""
        if playerRace ~= "" then
            text = string.gsub(text, escapePat(strlower(playerRace)), "race")
        end
    end

    -- Optional: player CLASS → "class" (for <class>-token quests).
    if subClass then
        local playerClass = UnitClass("player") or ""
        if playerClass ~= "" then
            text = string.gsub(text, escapePat(strlower(playerClass)), "class")
        end
    end

    text = string.gsub(text, "[^%l%d%s]", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return strsub(text, 1, 220)
end

-- Build the set of candidate signature keys for a runtime dialog text.
-- Returns up to 4 distinct strings (duplicates removed) to look up in order.
-- Order matters for ambiguous cases — most specific first to maximize match
-- accuracy when both raw and substituted variants happen to exist.
local function BuildTextSigCandidates(text)
    local seen = {}
    local out = {}
    local function add(s)
        if s and s ~= "" and not seen[s] then
            seen[s] = true
            out[table.getn(out) + 1] = s
        end
    end
    add(NormalizeLookupTextSig(text, false, false))
    add(NormalizeLookupTextSig(text, true,  false))
    add(NormalizeLookupTextSig(text, false, true))
    add(NormalizeLookupTextSig(text, true,  true))
    return out
end

local function ResolveNarratorTextSound(title, pageNum)
    local keyStr = title .. "_page" .. pageNum
    local itemDialogType = "item_p" .. pageNum
    local bookDialogType = "book_p" .. pageNum
    local itemPath = TT:BuildSoundPath("Narrator", title, itemDialogType, keyStr)
    local bookPath = TT:BuildSoundPath("Narrator", title, bookDialogType, keyStr)

    if TT_VOICE_MANIFEST and TT_VOICE_MANIFEST[itemPath] then
        return itemDialogType, keyStr, itemPath
    end
    if TT_VOICE_MANIFEST and TT_VOICE_MANIFEST[bookPath] then
        return bookDialogType, keyStr, bookPath
    end

    return nil, keyStr, nil
end

local QUEST_DIALOG_TYPES = { "quest_detail", "quest_progress", "quest_complete", "quest_greeting" }

local function BuildQuestHashIndexes()
    local i
    for i = 1, table.getn(QUEST_DIALOG_TYPES) do
        QUEST_HASH_INDEX[QUEST_DIALOG_TYPES[i]] = {}
    end
    NPC_DIALOG_INDEX = {}
    if not TT_VOICE_MANIFEST then return end

    for path in pairs(TT_VOICE_MANIFEST) do
        for i = 1, table.getn(QUEST_DIALOG_TYPES) do
            local dt = QUEST_DIALOG_TYPES[i]
            local marker = dt .. "_"
            if strfind(path, marker) then
                -- Build QUEST_HASH_INDEX: hash -> path
                local startIdx = strfind(path, marker) + strlen(marker)
                local extPos = strfind(path, "%.ogg$") or strfind(path, "%.mp3$") or strfind(path, "%.wav$")
                if startIdx and extPos and startIdx < extPos then
                    local hash = strlower(strsub(path, startIdx, extPos - 1))
                    if hash ~= "" then
                        -- Multiple NPCs can share a hash (same quest text, different givers).
                        -- Store all candidates so the resolver can pick by NPC folder.
                        local existing = QUEST_HASH_INDEX[dt][hash]
                        if not existing then
                            QUEST_HASH_INDEX[dt][hash] = path
                        elseif type(existing) == "string" then
                            if existing ~= path then
                                QUEST_HASH_INDEX[dt][hash] = { existing, path }
                            end
                        else
                            -- already a table
                            local dup = false
                            local j
                            for j = 1, table.getn(existing) do
                                if existing[j] == path then dup = true; break end
                            end
                            if not dup then
                                existing[table.getn(existing) + 1] = path
                            end
                        end
                    end
                end

                -- Build NPC_DIALOG_INDEX: "npcNorm|dialogType" -> array of paths
                -- Path format: ...\sounds\race\npcnorm\dialogtype_hash.wav
                -- Extract npcNorm by finding the folder just before the filename.
                local slashPos = nil
                local pos = 1
                while true do
                    local found = strfind(path, "\\", pos)
                    if not found then break end
                    slashPos = found
                    pos = found + 1
                end
                if slashPos and slashPos > 1 then
                    local beforeFile = strsub(path, 1, slashPos - 1)
                    local slashPos2 = nil
                    local pos2 = 1
                    while true do
                        local found2 = strfind(beforeFile, "\\", pos2)
                        if not found2 then break end
                        slashPos2 = found2
                        pos2 = found2 + 1
                    end
                    if slashPos2 then
                        local npcNorm = strsub(beforeFile, slashPos2 + 1)
                        local key = npcNorm .. "|" .. dt
                        if not NPC_DIALOG_INDEX[key] then
                            NPC_DIALOG_INDEX[key] = {}
                        end
                        local arr = NPC_DIALOG_INDEX[key]
                        arr[table.getn(arr) + 1] = path
                    end
                end

                break  -- a path only matches one dialog type
            end
        end
    end
end

local function PickPathByNPC(entry, npcName)
    if type(entry) ~= "table" then return entry end
    local npcNorm = TT:NormalizeName(npcName or "")
    local matchStr = "\\" .. npcNorm .. "\\"
    local picked = nil
    local i
    for i = 1, table.getn(entry) do
        local p = entry[i]
        if p then
            if npcNorm ~= "" and npcNorm ~= "unknown" and strfind(p, matchStr, 1, true) then
                return p
            end
            if not picked then picked = p end
        end
    end
    return picked
end

local function ResolveQuestByManifestHash(dialogType, keyStr, npcName)
    local index = QUEST_HASH_INDEX[dialogType]
    if not index then return nil end
    local hash = strlower(TT:HashKey(keyStr or ""))
    return PickPathByNPC(index[hash], npcName)
end

-- Public: resolve a quest_detail sound path by title, for quest-log replay.
-- `descriptionText` is the quest description string from GetQuestLogQuestText();
-- when provided it's used for text-signature disambiguation of same-title quests.
-- `questID` is unused on 1.12 (no GetQuestID API) but accepted for API parity.
-- Returns soundPath, race, npcDisplayName  (or nil if not found).
function TT:ResolveQuestSoundPath(title, questID, descriptionText)
    if not title or title == "" then return nil end

    -- Try hash index (title_questID). On 1.12 questID is always 0 so this is
    -- the old title-only key, effectively.
    local keyStr = title .. "_" .. tostring(questID or 0)
    local hash = strlower(self:HashKey(keyStr))
    local soundPath = QUEST_HASH_INDEX["quest_detail"][hash]
    if type(soundPath) == "table" then soundPath = soundPath[1] end

    -- Also try the bare-title hash (legacy and because questID is always 0 here).
    if not soundPath or not TT_VOICE_MANIFEST or not TT_VOICE_MANIFEST[soundPath] then
        local titleHash = strlower(self:HashKey(title))
        local alt = QUEST_HASH_INDEX["quest_detail"][titleHash]
        if type(alt) == "table" then alt = alt[1] end
        if alt and TT_VOICE_MANIFEST and TT_VOICE_MANIFEST[alt] then
            soundPath = alt
        end
    end

    -- Fallback 1: text-signature lookup — authoritative disambiguator for
    -- same-title quest chains. The description text is unique per quest even
    -- when titles collide, so this reliably picks the correct voice file.
    if (not soundPath or not TT_VOICE_MANIFEST or not TT_VOICE_MANIFEST[soundPath])
        and TT_QUEST_DETAIL_BY_TEXTSIG
        and descriptionText and descriptionText ~= "" then
        local candidates = BuildTextSigCandidates(descriptionText)
        for i = 1, table.getn(candidates) do
            local entry = TT_QUEST_DETAIL_BY_TEXTSIG[candidates[i]]
            -- Multi-giver quests store a list; quest-log replay can use any.
            if type(entry) == "table" then entry = entry[1] end
            if entry and TT_VOICE_MANIFEST and TT_VOICE_MANIFEST[entry] then
                soundPath = entry
                break
            end
        end
    end

    -- Fallback 2: normalized-title lookup (last resort; picks one arbitrary
    -- quest when multiple share the same title).
    if (not soundPath or not TT_VOICE_MANIFEST or not TT_VOICE_MANIFEST[soundPath])
        and TT_QUEST_DETAIL_BY_NORM_TITLE then
        local normTitle = NormalizeLookupTitle(title)
        local candidate = TT_QUEST_DETAIL_BY_NORM_TITLE[normTitle]
        if candidate and TT_VOICE_MANIFEST and TT_VOICE_MANIFEST[candidate] then
            soundPath = candidate
        end
    end

    if not soundPath or not TT_VOICE_MANIFEST or not TT_VOICE_MANIFEST[soundPath] then
        return nil
    end

    -- Extract race and npc display name from path:
    -- sounds\{race}\{npc_normalized}\quest_detail_{hash}.wav
    local race, npcName = "Unknown", "Unknown"
    local p1 = strfind(soundPath, "\\")
    if p1 then
        local s1 = strsub(soundPath, p1 + 1)
        local p2 = strfind(s1, "\\")
        if p2 then
            race = strsub(s1, 1, p2 - 1)
            local s2 = strsub(s1, p2 + 1)
            local p3 = strfind(s2, "\\")
            if p3 then
                npcName = strsub(s2, 1, p3 - 1)
                npcName = string.gsub(npcName, "_", " ")
            end
        end
    end

    return soundPath, race, npcName
end

----------------------------------------------------------------------------
-- Quest ID helpers
----------------------------------------------------------------------------
-- Scan the quest log for a quest with the given title and return its ID.
-- Only works if the quest is currently in the player's log (i.e., accepted).
-- Reliable for QUEST_PROGRESS and QUEST_COMPLETE; not for QUEST_DETAIL offers.
-- Returns 0 on 1.12 clients that don't expose the questID field.
local function GetQuestIDFromLog(title)
    if not GetNumQuestLogEntries then return 0 end
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local qTitle, _, _, _, isHeader, _, _, qID = GetQuestLogTitle(i)
        if not isHeader and qTitle == title then
            return qID or 0
        end
    end
    return 0
end

----------------------------------------------------------------------------
-- 0.1s delay trigger (BetterQuest QueueTrigger pattern)
-- Quest/gossip text APIs are not populated immediately on event fire in 1.12.
-- We wait 0.1s before reading them.
----------------------------------------------------------------------------
local function QueueTrigger(npcName, eventType)
    -- Cut off any NPC greeting SFX that started playing on this event.
    -- In vanilla 1.12, PlaySoundFile also routes through MasterSoundEffects,
    -- so we can't keep it muted across the 0.1s delay — our own voice would
    -- be silent too. Instead we do a single toggle 0→1: this acts as the
    -- standard sound-stop hack and SFX is re-enabled immediately, leaving
    -- the channel ready for our own PlaySoundFile call after the delay.
    --
    -- Skip the toggle if we're already playing or have entries queued —
    -- the NPC greeting plays through the same SFX channel as our own voice,
    -- so toggling would briefly cut our currently-playing line.
    if TurtlesEpochDB and TurtlesEpochDB.muteNPCGreetings
       and not TT.CurrentSound
       and (not TT.SoundQueue or table.getn(TT.SoundQueue) == 0) then
        SetCVar("MasterSoundEffects", 0)
        SetCVar("MasterSoundEffects", 1)
    end

    if delayActive then return end
    delayActive = true

    local delayFrame = CreateFrame("Frame")
    local startTime = GetTime()

    delayFrame:SetScript("OnUpdate", function()
        if GetTime() - startTime < 0.1 then return end

        -- Tear down immediately
        this:SetScript("OnUpdate", nil)

        local text, title, dialogType

        if eventType == "QUEST_DETAIL" then
            text = GetQuestText()
            title = GetTitleText()
            dialogType = "quest_detail"

        elseif eventType == "QUEST_PROGRESS" then
            text = GetProgressText()
            title = GetTitleText()
            dialogType = "quest_progress"

        elseif eventType == "QUEST_COMPLETE" then
            text = GetRewardText()
            title = GetTitleText()
            dialogType = "quest_complete"

        elseif eventType == "QUEST_GREETING" then
            text = GetGreetingText()
            title = npcName or "Unknown"
            dialogType = "quest_greeting"

        elseif eventType == "GOSSIP_SHOW" then
            text = GetGossipText()
            title = npcName or "Unknown"
            dialogType = "gossip"
        end

        -- Resolve questID via quest log scan (works for progress/complete;
        -- returns 0 for QUEST_DETAIL offers and on 1.12 which lacks the field).
        local questID = 0
        if dialogType == "quest_progress" or dialogType == "quest_complete" then
            if title and title ~= "" then
                questID = GetQuestIDFromLog(title)
            end
        end

        if text and text ~= "" then
            TT:OnDialogText(npcName, title, text, dialogType, questID)
        else
            TT:Debug("No text for " .. tostring(eventType))
        end

        delayActive = false
    end)
end

----------------------------------------------------------------------------
-- Book/item text handler (no delay needed — text is ready on ITEM_TEXT_READY)
----------------------------------------------------------------------------
local function OnBookPage()
    local title = ItemTextTitleText and ItemTextTitleText:GetText()
    local text = ItemTextGetText()

    if not title or title == "" then
        TT:Debug("Book: no title")
        return
    end
    if not text or text == "" then
        TT:Debug("Book: no text on page " .. bookPageCounter)
        return
    end

    -- Books and inventory item texts both fire ITEM_TEXT_READY.
    -- Resolve to item_pN first, then book_pN, and skip entirely if neither exists.
    TT:OnDialogText("Narrator", title, text, "book_p" .. bookPageCounter)
end

----------------------------------------------------------------------------
-- Central handler: called when dialog text is successfully extracted.
-- Currently outputs debug info. Will trigger SoundPlayer in Step 6.
----------------------------------------------------------------------------
function TT:OnDialogText(npcName, title, text, dialogType, questID)
    local race, sex = self:DetectNPCRace("npc")
    local soundPath = nil

    -- For books/Narrator sources, force Narrator
    if dialogType and (strfind(dialogType, "^book_") or strfind(dialogType, "^item_")) then
        race = "Narrator"
        sex = "unknown"
        npcName = title  -- Use book title as "NPC name" for path
    end

    -- Check whether this voice profile is enabled in category toggles
    if not self:IsVoiceEnabledFor(race, npcName) then
        self:Debug("Voice disabled by settings: " .. tostring(race) .. " / " .. tostring(npcName))
        return
    end

    -- Build the predicted sound path
    local keyStr
    if strfind(dialogType, "^book_p") then
        local pageNum = strsub(dialogType, 7)  -- "book_p" is 6 chars, number starts at 7
        dialogType, keyStr, soundPath = ResolveNarratorTextSound(title, pageNum)
        if not dialogType then
            self:Debug("No narrator voice found for item/book text: " .. tostring(title) .. " page " .. tostring(pageNum))
            return
        end
    elseif strfind(dialogType, "^item_p") then
        local pageNum = strsub(dialogType, 7)  -- "item_p" is 6 chars, number starts at 7
        keyStr = title .. "_page" .. pageNum
    elseif strfind(dialogType, "^gossip") then
        -- Gossip: hash = normalized text (first 100 chars)
        keyStr = strlower(strsub(text, 1, 100))
        keyStr = string.gsub(keyStr, "%s+", " ")
        keyStr = string.gsub(keyStr, "[^%w%s]", "")
    else
        -- Quest: hash = title + questID (matches generate_voice.py key_str format).
        -- On 1.12 questID is 0 for QUEST_DETAIL offers (no API), so title_0
        -- often misses — the text-signature fallback below handles this.
        keyStr = title .. "_" .. tostring(questID or 0)
    end

    if not soundPath then
        soundPath = self:BuildSoundPath(race, npcName, dialogType, keyStr)
    end

    -- Fallback 1: hash index (handles race-folder mismatches and item-triggered quests)
    if TT_VOICE_MANIFEST and not TT_VOICE_MANIFEST[soundPath] and QUEST_HASH_INDEX[dialogType] then
        local remappedPath = ResolveQuestByManifestHash(dialogType, keyStr, npcName)
        if remappedPath and TT_VOICE_MANIFEST[remappedPath] then
            soundPath = remappedPath
            self:Debug("Hash index fallback used")
        end
    end

    -- Fallback 2: text-signature lookup — the correct disambiguator for same-title
    -- quest chains. The actual dialog text (description, reward, progress) is
    -- unique per quest even when titles collide, so normalising it gives a reliable
    -- per-quest key. Critical on 1.12 where GetQuestID() does not exist.
    if TT_VOICE_MANIFEST and not TT_VOICE_MANIFEST[soundPath] then
        local sigTable = nil
        if dialogType == "quest_detail" then
            sigTable = TT_QUEST_DETAIL_BY_TEXTSIG
        elseif dialogType == "quest_complete" then
            sigTable = TT_QUEST_COMPLETE_BY_TEXTSIG
        elseif dialogType == "quest_progress" then
            sigTable = TT_QUEST_PROGRESS_BY_TEXTSIG
        elseif dialogType == "quest_greeting" then
            sigTable = TT_QUEST_GREETING_BY_TEXTSIG
        end
        if sigTable and text and text ~= "" then
            local candidates = BuildTextSigCandidates(text)
            for i = 1, table.getn(candidates) do
                local picked = PickPathByNPC(sigTable[candidates[i]], npcName)
                if picked and TT_VOICE_MANIFEST[picked] then
                    soundPath = picked
                    self:Debug("Text-sig fallback (variant " .. i .. "): " .. tostring(picked))
                    break
                end
            end
        end
    end

    -- Fallback 3: NPC+dialogType index — last resort when text sig has no match
    -- (e.g. manual entries, gossip, or text that differs from crawl).
    -- WARNING: picks the first candidate; may be wrong for same-NPC/same-title
    -- quest chains that are NOT covered by the text-sig table above.
    if TT_VOICE_MANIFEST and not TT_VOICE_MANIFEST[soundPath] and QUEST_HASH_INDEX[dialogType] then
        local npcNorm = self:NormalizeName(npcName)
        local key = npcNorm .. "|" .. dialogType
        local candidates = NPC_DIALOG_INDEX[key]
        if candidates and candidates[1] then
            soundPath = candidates[1]
            self:Debug("NPC dialog index fallback (last-resort): " .. key .. " -> " .. soundPath)
        end
    end

    if TT_VOICE_MANIFEST and not TT_VOICE_MANIFEST[soundPath] then
        self:Debug("No voice file in manifest for: " .. tostring(soundPath))
        return
    end

    -- Truncate text for debug display
    local textPreview = strsub(text, 1, 80)
    if strlen(text) > 80 then textPreview = textPreview .. "..." end

    self:Debug("--- Dialog Event ---")
    self:Debug("  NPC: " .. tostring(npcName))
    self:Debug("  Race: " .. tostring(race) .. " | Sex: " .. tostring(sex))
    self:Debug("  Type: " .. tostring(dialogType))
    self:Debug("  Title: " .. tostring(title))
    self:Debug("  Text: " .. textPreview)
    self:Debug("  Path: " .. tostring(soundPath))

    -- Queue playback (Step 6)
    self:QueueEntryFromDialog(npcName, title, text, dialogType, race, soundPath)
end

----------------------------------------------------------------------------
-- Event frame: created on ADDON_LOADED, registers all dialog events
----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function CountKeys(tbl)
    local n = 0
    if not tbl then return 0 end
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "TurtlesEpoch" then
        -- Initialize SavedVariables
        TT:InitDB()

        -- Quest and gossip events
        local dialogFrame = CreateFrame("Frame")
        dialogFrame:RegisterEvent("QUEST_DETAIL")
        dialogFrame:RegisterEvent("QUEST_PROGRESS")
        dialogFrame:RegisterEvent("QUEST_COMPLETE")
        dialogFrame:RegisterEvent("QUEST_GREETING")
        dialogFrame:RegisterEvent("GOSSIP_SHOW")

        dialogFrame:SetScript("OnEvent", function()
            if not TurtlesEpochDB or not TurtlesEpochDB.enabled then return end
            QueueTrigger(UnitName("npc"), event)
        end)

        -- Book / item text events
        local bookFrame = CreateFrame("Frame")
        bookFrame:RegisterEvent("ITEM_TEXT_BEGIN")
        bookFrame:RegisterEvent("ITEM_TEXT_READY")

        bookFrame:SetScript("OnEvent", function()
            if not TurtlesEpochDB or not TurtlesEpochDB.enabled then return end

            if event == "ITEM_TEXT_BEGIN" then
                bookPageCounter = 1
                TT:Debug("Book opened — page counter reset")
            elseif event == "ITEM_TEXT_READY" then
                OnBookPage()
                bookPageCounter = bookPageCounter + 1
            end
        end)

        BuildQuestHashIndexes()

        TT:CreateMinimapButton()
        TT:Print("v" .. TT.VERSION .. " loaded (/tt for commands)")
        TT:Debug("=== STARTUP DEBUG ===")
        TT:Debug("TT_VOICE_MANIFEST: " .. tostring(CountKeys(TT_VOICE_MANIFEST)) .. " paths")
        TT:Debug("QUEST_HASH_INDEX[quest_detail]: " .. tostring(CountKeys(QUEST_HASH_INDEX["quest_detail"])) .. " hashes")
    end
end)
