-- TurtlesEpoch: SoundPlayer.lua
-- Queue-based playback with portrait UI, skip/clear controls, and manifest durations.

local TT = TurtlesEpoch

TT.SoundQueue = TT.SoundQueue or {}
TT.CurrentSound = nil
TT.PortraitModelPool = TT.PortraitModelPool or {}

local QUESTION_MARK_MODEL = "Interface\\Buttons\\talktomequestionmark.mdx"
local QUEST_AVAILABLE_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local QUEST_ACTIVE_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local NARRATOR_BOOK_ICON  = "Interface\\Icons\\INV_Misc_Book_09"

local function IsNarratorEntry(entry)
    if not entry then return false end
    if entry.race == "Narrator" then return true end
    if entry.dialogType and string.find(entry.dialogType, "^book_") then return true end
    if entry.dialogType and string.find(entry.dialogType, "^item_") then return true end
    return false
end

local function GetFallbackIcon(entry)
    if entry and entry.dialogType == "quest_detail" then
        return QUEST_AVAILABLE_ICON
    end
    return QUEST_ACTIVE_ICON
end

local function EstimateDuration(text)
    local len = string.len(text or "")
    if len < 10 then return 2.0 end
    -- ~13 chars/sec with floor/ceiling guards
    local seconds = len / 13.0
    if seconds < 2.0 then seconds = 2.0 end
    if seconds > 90.0 then seconds = 90.0 end
    return seconds
end

local function AcquirePortraitModel()
    local model = nil
    if TT.PortraitModelPool and table.getn(TT.PortraitModelPool) > 0 then
        model = table.remove(TT.PortraitModelPool)
    else
        model = CreateFrame("PlayerModel", nil, UIParent)
        model:SetWidth(80)
        model:SetHeight(100)
        model:SetModel(QUESTION_MARK_MODEL)
        model:SetScript("OnShow", function() this:SetCamera(0) end)
    end

    model:SetParent(UIParent)
    model:ClearAllPoints()
    model:SetPoint("CENTER", UIParent, "CENTER", 10000, 10000)
    model:Hide()
    return model
end

local function ReleasePortraitModel(model)
    if not model then return end
    model:Hide()
    model:SetParent(UIParent)
    model:ClearAllPoints()
    model:SetPoint("CENTER", UIParent, "CENTER", 10000, 10000)
    table.insert(TT.PortraitModelPool, model)
end

local function CapturePortraitForEntry(entry)
    if not entry or entry.portraitModel or IsNarratorEntry(entry) then return end
    if not UnitExists("npc") then return end

    local model = AcquirePortraitModel()
    model:SetUnit("npc")
    model:SetCamera(0)
    entry.portraitModel = model
end

local function BuildQueueFrame()
    if TT.QueueFrame then return end

    local f = CreateFrame("Frame", "TurtlesEpochQueueFrame", UIParent)
    f:SetWidth(360)
    f:SetHeight(150)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:Hide()

    -- Restore saved position or use default
    local pos = TurtlesEpochDB and TurtlesEpochDB.windowPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    -- Make draggable
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = this:GetPoint()
        if TurtlesEpochDB then
            TurtlesEpochDB.windowPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- X close button (top-right corner, using standard WoW close button template)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 4, 4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- LEFT COLUMN: portrait only (x=10..72). The 3D model overflows its frame
    -- bounds vertically, so nothing else is anchored below it — all text lives
    -- in the right column starting at x=82 where overflow can't reach.

    -- 3D animated portrait (PlayerModel) for NPC voices.
    local portrait3D = CreateFrame("PlayerModel", nil, f)
    portrait3D:SetWidth(80)
    portrait3D:SetHeight(100)
    portrait3D:SetPoint("LEFT", f, "LEFT", 8, 0)
    portrait3D:SetModel(QUESTION_MARK_MODEL)
    portrait3D:SetScript("OnShow", function() this:SetCamera(0) end)
    f.Portrait3D = portrait3D

    -- 2D icon fallback for narrator/book entries.
    local portraitIcon = f:CreateTexture(nil, "ARTWORK")
    portraitIcon:SetWidth(80)
    portraitIcon:SetHeight(100)
    portraitIcon:SetPoint("LEFT", f, "LEFT", 8, 0)
    portraitIcon:Hide()
    f.PortraitIcon = portraitIcon

    -- RIGHT COLUMN (x=82 onward): title, npc name, buttons.

    -- Title: centered on full frame width
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetWidth(240)
    title:SetJustifyH("CENTER")
    f.Title = title

    -- NPC name: below title, same centering
    local npcLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    npcLabel:SetPoint("TOP", title, "BOTTOM", 0, -6)
    npcLabel:SetWidth(240)
    npcLabel:SetJustifyH("CENTER")
    npcLabel:SetNonSpaceWrap(false)
    f.NPCLabel = npcLabel

    -- Buttons: right-aligned at bottom of frame
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetWidth(86)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    clearBtn:SetText("Clear Queue")
    clearBtn:SetScript("OnClick", function()
        TT:ClearSoundQueue()
    end)

    local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skipBtn:SetWidth(66)
    skipBtn:SetHeight(22)
    skipBtn:SetPoint("RIGHT", clearBtn, "LEFT", -8, 0)
    skipBtn:SetText("Skip")
    skipBtn:SetScript("OnClick", function()
        TT:SkipCurrentSound()
    end)

    TT.QueueFrame = f
end

local function UpdatePortrait(entry)
    if not TT.QueueFrame then return end
    local p3D = TT.QueueFrame.Portrait3D
    local icon = TT.QueueFrame.PortraitIcon
    if not p3D or not icon then return end

    if TT.QueueFrame.ActivePortraitModel and TT.QueueFrame.ActivePortraitModel ~= entry.portraitModel then
        TT.QueueFrame.ActivePortraitModel:Hide()
        TT.QueueFrame.ActivePortraitModel = nil
    end

    if IsNarratorEntry(entry) then
        p3D:Hide()
        if TT.QueueFrame.ActivePortraitModel then
            TT.QueueFrame.ActivePortraitModel:Hide()
            TT.QueueFrame.ActivePortraitModel = nil
        end
        p3D:Hide()
        icon:SetTexture(NARRATOR_BOOK_ICON)
        icon:Show()
        return
    end

    if entry and entry.portraitModel then
        p3D:Hide()
        icon:Hide()
        entry.portraitModel:SetParent(TT.QueueFrame)
        entry.portraitModel:ClearAllPoints()
        entry.portraitModel:SetPoint("LEFT", TT.QueueFrame, "LEFT", 8, 0)
        entry.portraitModel:Show()
        TT.QueueFrame.ActivePortraitModel = entry.portraitModel
        return
    end

    -- Bind to the live npc when available. Once captured for the active entry,
    -- keep the portrait latched even after the dialog closes.
    if UnitExists("npc") then
        icon:Hide()
        p3D:SetUnit("npc")
        p3D:SetCamera(0)
        entry.hasPortraitSnapshot = true
        p3D:Show()
    elseif entry and entry.hasPortraitSnapshot then
        icon:Hide()
        p3D:Show()
    else
        p3D:Hide()
        icon:SetTexture(GetFallbackIcon(entry))
        icon:Show()
    end
end

function TT:StopCurrentSound()
    -- No StopSoundFile() in 1.12. Toggle MasterSoundEffects to force-stop playback.
    SetCVar("MasterSoundEffects", 0)
    SetCVar("MasterSoundEffects", 1)
end

function TT:UpdateQueueFrame(skipPortraitRefresh)
    BuildQueueFrame()
    if not self.QueueFrame then return end

    if not self.CurrentSound then
        self.QueueFrame:Hide()
        return
    end

    local qCount = table.getn(self.SoundQueue or {})
    local current = self.CurrentSound

    self.QueueFrame.Title:SetText(current.title or "")

    -- NPC name below portrait (truncated to fit)
    local npcName = current.npcName or ""
    if IsNarratorEntry(current) then
        npcName = ""
    end
    self.QueueFrame.NPCLabel:SetText(npcName)

    self:Debug("queued: " .. qCount .. " | type: " .. tostring(current.dialogType))
    if not skipPortraitRefresh then
        UpdatePortrait(current)
    end
    self.QueueFrame:Show()
end

function TT:PlayNextInQueue()
    if self.CurrentSound then return end

    if not self.SoundQueue or table.getn(self.SoundQueue) == 0 then
        self.CurrentSound = nil
        self:UpdateQueueFrame()
        return
    end

    local nextEntry = table.remove(self.SoundQueue, 1)
    self.CurrentSound = nextEntry

    PlaySoundFile(nextEntry.soundPath)

    local now = GetTime()
    nextEntry.startTime = now
    nextEntry.endTime = now + (nextEntry.duration or EstimateDuration(nextEntry.text))

    self:UpdateQueueFrame()
    self:Debug("Playing: " .. tostring(nextEntry.soundPath))
end

function TT:EnqueueSound(entry)
    if not entry or not entry.soundPath then return end

    if not self.SoundQueue then
        self.SoundQueue = {}
    end

    CapturePortraitForEntry(entry)

    table.insert(self.SoundQueue, entry)
    self:Debug("Queued: " .. tostring(entry.soundPath) .. " (" .. table.getn(self.SoundQueue) .. " in queue)")

    if not self.CurrentSound then
        self:PlayNextInQueue()
    else
        self:UpdateQueueFrame(true)
    end
end

function TT:SkipCurrentSound()
    if not self.CurrentSound then return end
    local old = self.CurrentSound
    self:StopCurrentSound()
    self.CurrentSound = nil
    if old and old.portraitModel then
        ReleasePortraitModel(old.portraitModel)
        old.portraitModel = nil
    end
    self:PlayNextInQueue()
end

function TT:ClearSoundQueue()
    local i = 0
    if self.CurrentSound and self.CurrentSound.portraitModel then
        ReleasePortraitModel(self.CurrentSound.portraitModel)
        self.CurrentSound.portraitModel = nil
    end
    if self.SoundQueue then
        for i = 1, table.getn(self.SoundQueue) do
            if self.SoundQueue[i] and self.SoundQueue[i].portraitModel then
                ReleasePortraitModel(self.SoundQueue[i].portraitModel)
                self.SoundQueue[i].portraitModel = nil
            end
        end
    end
    self.SoundQueue = {}
    if self.CurrentSound then
        self:StopCurrentSound()
        self.CurrentSound = nil
    end
    self:UpdateQueueFrame()
    self:Debug("Queue cleared")
end

function TT:QueueEntryFromDialog(npcName, title, text, dialogType, race, soundPath)
    local duration = nil
    if TT_VOICE_MANIFEST then
        duration = TT_VOICE_MANIFEST[soundPath]
    end
    if not duration then
        duration = EstimateDuration(text)
    end

    -- Portrait is updated at playback time (PlayNextInQueue → UpdateQueueFrame),
    -- not at queue time, so queuing a second NPC never overwrites the current portrait.

    self:EnqueueSound({
        npcName = npcName,
        title = title,
        text = text,
        dialogType = dialogType,
        race = race,
        soundPath = soundPath,
        duration = duration,
    })
end

-- Playback ticker: transition to next queue entry when duration elapses
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
    if not TT or not TT.CurrentSound then return end

    if GetTime() >= (TT.CurrentSound.endTime or 0) then
        local old = TT.CurrentSound
        TT.CurrentSound = nil
        if old and old.portraitModel then
            ReleasePortraitModel(old.portraitModel)
            old.portraitModel = nil
        end
        TT:PlayNextInQueue()
    end
end)
