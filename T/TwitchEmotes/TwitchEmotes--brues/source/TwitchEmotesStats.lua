-- Access the window by shift-clicking the minimap button.

TwitchEmoteStatistics = TwitchEmoteStatistics or {}


function TwitchEmotes_UpdateStats(emote, isSent)
    if not defaultpack[emote] then return end
    if not TwitchEmoteStatistics[emote] then
        TwitchEmoteStatistics[emote] = { 0, 0 }
    end
    local s = TwitchEmoteStatistics[emote]
    if isSent then s[1] = s[1] + 1 else s[2] = s[2] + 1 end
end

local texToEmote = nil
local function buildTexLookup()
    texToEmote = {}
    for emote, path in pairs(defaultpack) do
        local tga = path:match("(.*%.tga)")
        if tga then texToEmote[tga] = emote end
    end
end

function Emoticons_FilterMessage(msg, sender)
    local isSelf = (sender == UnitName("player"))
    local processed = Emoticons_RunReplacement(msg)
    if processed ~= msg then
        if not texToEmote then buildTexLookup() end
        local counted = {}
        for texPath in processed:gmatch("|T(.-)|t") do
            local tga = texPath:match("(.*%.tga)")
            if tga then
                local emote = texToEmote[tga]
                if emote and not counted[emote] then
                    TwitchEmotes_UpdateStats(emote, isSelf)
                    counted[emote] = true
                end
            end
        end
    end
    return processed
end


local NUM_LINES = 17
local LINE_H    = 16
local WIN_W     = 512
local WIN_H     = 516

local FALLBACK_TEX = "Interface\\AddOns\\TwitchEmotes\\Emotes\\1337.tga"

-- Same panel styling as the autocomplete popup.
local FEATURED_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local sentKeys     = {}
local seenKeys     = {}
local sentFiltered = {}
local seenFiltered = {}
local sentLines    = {}
local seenLines    = {}
local statsWin     = nil

local function emoteTga(emote)
    local path = emote and defaultpack[emote]
    return path and path:match("(.*%.tga)") or nil
end

local function emoteTexStr(emote, size)
    local tga = emoteTga(emote)
    if not tga then return "" end
    -- animated emote sheets: crop to frame 0 (the animator advances the frame)
    local a = TwitchEmotes_animation_metadata and TwitchEmotes_animation_metadata[tga]
    if a then
        return "|T" .. tga .. ":" .. size .. ":" .. size .. ":0:0:" ..
               a.imageWidth .. ":" .. a.imageHeight .. ":0:" ..
               a.frameWidth .. ":0:" .. a.frameHeight .. "|t"
    end
    return "|T" .. tga .. ":" .. size .. ":" .. size .. "|t"
end

local function setTopEmote(tex, emote)
    local tga = emoteTga(emote)
    tex:SetTexture(tga or FALLBACK_TEX)
    -- store animdata so the animator can crop frames; frame 0 as the base
    tex.animdata = tga and TwitchEmotes_animation_metadata and TwitchEmotes_animation_metadata[tga]
    if tex.animdata then
        tex:SetTexCoord(0, tex.animdata.frameWidth / tex.animdata.imageWidth,
                        0, tex.animdata.frameHeight / tex.animdata.imageHeight)
    else
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function updateList(lines, sf, keys, statIdx)
    local offset = FauxScrollFrame_GetOffset(sf)
    FauxScrollFrame_Update(sf, #keys, NUM_LINES, LINE_H)
    local verb = (statIdx == 1) and "sent:" or "seen:"
    for i = 1, NUM_LINES do
        local idx = i + offset
        local fs  = lines[i]
        if idx <= #keys then
            local emote = keys[idx]
            fs:SetText(string.format(
                "|cffFFD700%d.|r %s |cff00FF00%s|r %s %dx",
                idx, emoteTexStr(emote, 16), emote, verb,
                TwitchEmoteStatistics[emote][statIdx]
            ))
            fs:Show()
        else
            fs:Hide()
        end
    end
end

local function applyFilter(text)
    text = (text or ""):lower()
    if text == "" then
        sentFiltered, seenFiltered = sentKeys, seenKeys
    else
        sentFiltered, seenFiltered = {}, {}
        for _, e in ipairs(sentKeys) do
            if e:lower():find(text, 1, true) then sentFiltered[#sentFiltered + 1] = e end
        end
        for _, e in ipairs(seenKeys) do
            if e:lower():find(text, 1, true) then seenFiltered[#seenFiltered + 1] = e end
        end
    end
    updateList(sentLines, statsWin.sentSF, sentFiltered, 1)
    updateList(seenLines, statsWin.seenSF, seenFiltered, 2)
end

local function computeStats()
    sentKeys, seenKeys = {}, {}
    local totalSent, totalSeen = 0, 0
    for emote, s in pairs(TwitchEmoteStatistics) do
        if defaultpack[emote] then
            if s[1] and s[1] > 0 then sentKeys[#sentKeys + 1] = emote; totalSent = totalSent + s[1] end
            if s[2] and s[2] > 0 then seenKeys[#seenKeys + 1] = emote; totalSeen = totalSeen + s[2] end
        end
    end
    table.sort(sentKeys, function(a, b)
        return TwitchEmoteStatistics[a][1] > TwitchEmoteStatistics[b][1]
    end)
    table.sort(seenKeys, function(a, b)
        return TwitchEmoteStatistics[a][2] > TwitchEmoteStatistics[b][2]
    end)

    statsWin.sentTitle:SetText("Sent " .. totalSent .. " emotes")
    statsWin.seenTitle:SetText("Seen " .. totalSeen .. " emotes")

    if sentKeys[1] then
        setTopEmote(statsWin.topSentTex, sentKeys[1]); statsWin.topSentTex:Show()
        statsWin.topSentCap:SetText(sentKeys[1] .. " sent " .. TwitchEmoteStatistics[sentKeys[1]][1] .. "x")
    else
        setTopEmote(statsWin.topSentTex, nil)
        statsWin.topSentCap:SetText("No emotes sent yet")
    end

    if seenKeys[1] then
        setTopEmote(statsWin.topSeenTex, seenKeys[1]); statsWin.topSeenTex:Show()
        statsWin.topSeenCap:SetText(seenKeys[1] .. " seen " .. TwitchEmoteStatistics[seenKeys[1]][2] .. "x")
    else
        setTopEmote(statsWin.topSeenTex, nil)
        statsWin.topSeenCap:SetText("No emotes seen yet")
    end
end

local function makeLineEntries(parent, xOff, yOff, lineTable)
    for i = 1, NUM_LINES do
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", xOff, yOff - (i - 1) * LINE_H)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        lineTable[i] = fs
    end
end

local LEFT_X  = 16
local RIGHT_X = 264
local LIST_Y  = -228

local function makeFeatured(f, label, centerX)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", f, "TOPLEFT", centerX, -52)
    title:SetText(label)

    -- a frame rather than a texture, so the emote can sit on its OVERLAY layer
    -- above the backdrop
    local border = CreateFrame("Frame", nil, f)
    border:SetSize(86, 86)
    border:SetPoint("CENTER", f, "TOPLEFT", centerX, -108)
    border:SetBackdrop(FEATURED_BACKDROP)
    border:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    border:SetBackdropBorderColor(1, 1, 1, 1)

    local tex = border:CreateTexture(nil, "OVERLAY")
    tex:SetSize(70, 70)
    tex:SetPoint("CENTER", border, "CENTER", 0, 0)

    local cap = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cap:SetPoint("CENTER", f, "TOPLEFT", centerX, -160)

    return tex, cap
end

local function buildWindow()
    local f = CreateFrame("Frame", "TwitchEmotesStatsFrame", UIParent)
    f:SetSize(WIN_W, WIN_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("TwitchEmotes usage data")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() f:Hide() end)

    f.topSentTex, f.topSentCap = makeFeatured(f, "Top sent", 128)
    f.topSeenTex, f.topSeenCap = makeFeatured(f, "Top seen", 384)

    -- search box
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", 14, -178)
    searchLabel:SetText("Search:")

    local searchBox = CreateFrame("EditBox", "TwitchEmotesStatsSearch", f, "InputBoxTemplate")
    searchBox:SetSize(180, 16)
    searchBox:SetAutoFocus(false)
    searchBox:SetPoint("TOPLEFT", 18, -192)
    searchBox:SetScript("OnTextChanged", function(self) applyFilter(self:GetText()) end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    f.searchBox = searchBox

    f.sentTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.sentTitle:SetPoint("TOPLEFT", LEFT_X - 1, -212)
    f.sentTitle:SetText("Sent")

    f.seenTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.seenTitle:SetPoint("TOPLEFT", RIGHT_X - 1, -212)
    f.seenTitle:SetText("Seen")

    makeLineEntries(f, LEFT_X,  LIST_Y, sentLines)
    makeLineEntries(f, RIGHT_X, LIST_Y, seenLines)

    local function wheel(self, delta)
        local bar = _G[self:GetName() .. "ScrollBar"]
        bar:SetValue(bar:GetValue() - delta * LINE_H)
    end

    local sentSF = CreateFrame("ScrollFrame", "TwitchEmotesStatsSentSF", f, "FauxScrollFrameTemplate")
    sentSF:SetSize(220, NUM_LINES * LINE_H)
    sentSF:SetPoint("TOPLEFT", LEFT_X - 8, LIST_Y)
    sentSF:EnableMouseWheel(true)
    sentSF:SetScript("OnMouseWheel", wheel)
    sentSF:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINE_H, function()
            updateList(sentLines, self, sentFiltered, 1)
        end)
    end)

    local seenSF = CreateFrame("ScrollFrame", "TwitchEmotesStatsSeenSF", f, "FauxScrollFrameTemplate")
    seenSF:SetSize(220, NUM_LINES * LINE_H)
    seenSF:SetPoint("TOPLEFT", RIGHT_X - 8, LIST_Y)
    seenSF:EnableMouseWheel(true)
    seenSF:SetScript("OnMouseWheel", wheel)
    seenSF:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINE_H, function()
            updateList(seenLines, self, seenFiltered, 2)
        end)
    end)

    f.sentSF = sentSF
    f.seenSF = seenSF
    f:Hide()
    return f
end

function TwitchStats_Toggle()
    if not statsWin then
        statsWin = buildWindow()
    end
    if statsWin:IsShown() then
        statsWin:Hide()
        return
    end
    computeStats()
    statsWin.searchBox:SetText("")
    sentFiltered, seenFiltered = sentKeys, seenKeys
    updateList(sentLines, statsWin.sentSF, sentFiltered, 1)
    updateList(seenLines, statsWin.seenSF, seenFiltered, 2)
    statsWin:Show()
end
