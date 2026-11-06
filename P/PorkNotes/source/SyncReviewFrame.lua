local frame = CreateFrame("Frame", "PorkNotes_SyncReviewFrame", UIParent)
frame:SetWidth(420)
frame:SetHeight(220)
frame:SetFrameStrata("DIALOG")
frame:SetPoint("CENTER", UIParent, "CENTER")
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    PorkNotes.SetSetting("SyncReviewFramePos", point .. "," .. relativePoint .. "," .. math.floor(x) .. "," .. math.floor(y))
end)
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
frame:SetBackdropColor(0, 0, 0, 0.85)
frame:Hide()

frame:SetScript("OnShow", function()
    PlaySound("igMainMenuOpen")
end)

frame:SetScript("OnHide", function()
    PlaySound("igMainMenuClose")
end)

tinsert(UISpecialFrames, frame:GetName())

-- Title
local titleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleLabel:SetPoint("TOP", 0, -15)
titleLabel:SetText("|cFFD893EDPork|r|cFFFFBB00Notes|r - Sync Review")

-- Queue counter
local queueLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
queueLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -15)
queueLabel:SetTextColor(0.6, 0.6, 0.6)

-- Player name
local playerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
playerLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -38)
playerLabel:SetTextColor(0.847, 0.576, 0.929)

-- Sender info
local senderLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
senderLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -54)
senderLabel:SetTextColor(0.6, 0.6, 0.6)

-- Divider
local divider = frame:CreateTexture(nil, "BACKGROUND")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -66)
divider:SetTexture(0.3, 0.3, 0.3, 0.8)

-- Two panel containers
local leftPanel = CreateFrame("Frame", nil, frame)
leftPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -74)
leftPanel:SetWidth(175)
leftPanel:SetHeight(100)
leftPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
leftPanel:SetBackdropColor(0, 0, 0, 0.4)

local rightPanel = CreateFrame("Frame", nil, frame)
rightPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -74)
rightPanel:SetWidth(175)
rightPanel:SetHeight(100)
rightPanel:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
rightPanel:SetBackdropColor(0, 0, 0, 0.4)

-- Panel headers
local leftHeader = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
leftHeader:SetPoint("TOPLEFT", 6, -6)
leftHeader:SetTextColor(0.4, 0.8, 0.4)
leftHeader:SetText("Your note")

local rightHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rightHeader:SetPoint("TOPLEFT", 6, -6)
rightHeader:SetTextColor(0.4, 0.6, 1)
rightHeader:SetText("Incoming")

-- Panel note text
local leftNoteLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
leftNoteLabel:SetPoint("TOPLEFT", 6, -20)
leftNoteLabel:SetWidth(163)
leftNoteLabel:SetJustifyH("LEFT")
leftNoteLabel:SetTextColor(0.9, 0.9, 0.9)

local rightNoteLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rightNoteLabel:SetPoint("TOPLEFT", 6, -20)
rightNoteLabel:SetWidth(163)
rightNoteLabel:SetJustifyH("LEFT")
rightNoteLabel:SetTextColor(0.9, 0.9, 0.9)

-- Panel date labels
local leftDateLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
leftDateLabel:SetPoint("BOTTOMLEFT", 6, 6)
leftDateLabel:SetTextColor(0.5, 0.5, 0.5)

local rightDateLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rightDateLabel:SetPoint("BOTTOMLEFT", 6, 6)
rightDateLabel:SetTextColor(0.5, 0.5, 0.5)

-- Buttons
local keepMineButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
keepMineButton:SetWidth(120)
keepMineButton:SetHeight(24)
keepMineButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
keepMineButton:SetText("Keep mine")

local acceptTheirsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
acceptTheirsButton:SetWidth(120)
acceptTheirsButton:SetHeight(24)
acceptTheirsButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
acceptTheirsButton:SetText("Accept theirs")

local skipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
skipButton:SetWidth(80)
skipButton:SetHeight(24)
skipButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
skipButton:SetText("Skip")

-- State
local currentIndex = 1

local function FormatDate(timestamp)
    if not timestamp then return "unknown" end
    return date("%Y-%m-%d", timestamp)
end

local function LoadReview(index)
    local reviews = PorkNotes.GetPendingSyncReviews()
    if not reviews or table.getn(reviews) == 0 then
        frame:Hide()
        return
    end

    local review = reviews[index]
    if not review then
        frame:Hide()
        return
    end

    local total = table.getn(reviews)
    queueLabel:SetText(index .. " / " .. total)
    playerLabel:SetText(review.playername)
    senderLabel:SetText("Sent by: " .. (review.senderName or "unknown"))

    local localNote    = review.localNote
    local incomingNote = review.incomingNote

    leftNoteLabel:SetText(localNote and localNote.text or "(empty)")
    leftDateLabel:SetText(FormatDate(localNote and (localNote.updated or localNote.created)))

    rightNoteLabel:SetText(incomingNote and incomingNote.text or "(empty)")
    rightDateLabel:SetText(FormatDate(incomingNote and (incomingNote.updated or incomingNote.created)))
    rightHeader:SetText("Incoming from " .. (review.senderName or "unknown"))
end

keepMineButton:SetScript("OnClick", function()
    PorkNotes.ResolveSyncReview(currentIndex, false)
    local reviews = PorkNotes.GetPendingSyncReviews()
    if reviews and table.getn(reviews) > 0 then
        LoadReview(currentIndex)
    else
        frame:Hide()
    end
end)

acceptTheirsButton:SetScript("OnClick", function()
    PorkNotes.ResolveSyncReview(currentIndex, true)
    local reviews = PorkNotes.GetPendingSyncReviews()
    if reviews and table.getn(reviews) > 0 then
        LoadReview(currentIndex)
    else
        frame:Hide()
    end
end)

skipButton:SetScript("OnClick", function()
    local reviews = PorkNotes.GetPendingSyncReviews()
    local total = reviews and table.getn(reviews) or 0
    if currentIndex < total then
        currentIndex = currentIndex + 1
        LoadReview(currentIndex)
    else
        currentIndex = 1
        LoadReview(currentIndex)
    end
end)

PorkNotes.ShowSyncReviewFrame = function()
    currentIndex = 1
    local reviews = PorkNotes.GetPendingSyncReviews()
    if not reviews or table.getn(reviews) == 0 then return end
    LoadReview(currentIndex)
    frame:ClearAllPoints()
    local saved = PorkNotes.GetSetting("SyncReviewFramePos", nil)
    if saved then
        local _, _, point, relativePoint, x, y = string.find(saved, "([^,]+),([^,]+),(-?%d+),(-?%d+)")
        if point then
            frame:SetPoint(point, UIParent, relativePoint, tonumber(x), tonumber(y))
        else
            frame:SetPoint("CENTER", UIParent)
        end
    else
        frame:SetPoint("CENTER", UIParent)
    end
    frame:Show()
end
