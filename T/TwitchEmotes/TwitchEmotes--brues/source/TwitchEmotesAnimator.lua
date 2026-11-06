-- Animated emotes are sprite sheets; TwitchEmotes_animation_metadata
-- (Emotes.lua) maps each sheet's texture path to its frame layout. ClassicAPI's
-- inline-texture renderer supports the extended
-- |Tpath:w:h:0:0:imgW:imgH:left:right:top:bottom|t form (sprite-sheet crop), so
-- we animate by re-SetText-ing each visible FontString ~30fps with the current
-- frame's crop. On 1.12 a ScrollingMessageFrame's visible lines are real
-- CSimpleFontStrings exposed as the ChatFrame's FontString regions, so they can
-- be rewritten in place — the same way the retail TwitchEmotesAnimator does it.

local TWITCHEMOTES_T = 0
local sinceUpdate = 0

local function GetCurrentFrameNum(animdata)
    if animdata.pingpong then
        local v = math.floor((TWITCHEMOTES_T * animdata.framerate) % ((animdata.nFrames * 2) - 1))
        if v > animdata.nFrames then
            v = animdata.nFrames - (v % animdata.nFrames)
        end
        return v
    end
    return math.floor((TWITCHEMOTES_T * animdata.framerate) % animdata.nFrames)
end

-- Frames run row-major across however many columns the sheet is wide, since a
-- run longer than 32 frames outgrows the 1024px decode scratch as one strip.
-- Older sheets are packed more densely than that: before ClassicAPI's texture
-- dimension gate a sheet skinnier than 16:1 drew nothing, so runs wrapped at 16
-- frames. Deriving the column count from the sheet handles either.
local function GetFrameRect(animdata, framenum)
    local cols = math.floor(animdata.imageWidth / animdata.frameWidth)
    if cols < 1 then cols = 1 end
    local left = (framenum % cols) * animdata.frameWidth
    local top = math.floor(framenum / cols) * animdata.frameHeight
    return left, left + animdata.frameWidth, top, top + animdata.frameHeight
end

-- Crop a Texture (not inline text) to its animdata's current frame.
local function CropToCurrentFrame(tex, animdata)
    local left, right, top, bottom = GetFrameRect(animdata, GetCurrentFrameNum(animdata))
    tex:SetTexCoord(left / animdata.imageWidth, right / animdata.imageWidth,
                    top / animdata.imageHeight, bottom / animdata.imageHeight)
end

-- The crop bounds are texel offsets, so emit them as integers rather than
-- letting a float from the frame maths stringify into the payload.
local function BuildFrameString(imagepath, animdata, framenum, w, h)
    local left, right, top, bottom = GetFrameRect(animdata, framenum)
    return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(imagepath, w, h,
                         animdata.imageWidth, animdata.imageHeight,
                         left, right, top, bottom)
end

-- escape the pattern-magic chars that can appear in an emote escape (paths use
-- '+' and '-'); '.' is left as-is to match the retail animator.
local function escpattern(s)
    return (s:gsub("%+", "%%+"):gsub("%-", "%%-"))
end

-- Rewrite every animated emote escape in the fontstring to its current frame.
local function UpdateFontString(fontstring, w, h)
    local txt = fontstring:GetText()
    if txt == nil then return end
    for emoteStr in txt:gmatch("(|TInterface\\AddOns\\TwitchEmotes\\Emotes.-|t)") do
        local imagepath = emoteStr:match("|T(Interface\\AddOns\\TwitchEmotes\\Emotes.-%.tga).-|t")
        local animdata = imagepath and TwitchEmotes_animation_metadata[imagepath]
        if animdata then
            local framenum = GetCurrentFrameNum(animdata)
            txt = txt:gsub(escpattern(emoteStr), BuildFrameString(imagepath, animdata, framenum, w, h))
            fontstring:SetText(txt)
        end
    end
end

local anim = CreateFrame("Frame")
anim:SetScript("OnUpdate", function(self, elapsed)
    TWITCHEMOTES_T = TWITCHEMOTES_T + elapsed
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < 0.033 then return end   -- ~30fps
    sinceUpdate = 0

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and cf:IsShown() then
            for j = 1, cf:GetNumRegions() do
                local region = select(j, cf:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    UpdateFontString(region, 28, 28)
                end
            end
        end
    end

    -- Autocomplete suggestion icons are Textures, not inline text: crop each
    -- animated one's current frame via SetTexCoord.
    local ac = TwitchEmotesACPopup
    if ac and ac:IsShown() and ac.btns then
        for _, b in ipairs(ac.btns) do
            if b:IsShown() and b.animdata then
                CropToCurrentFrame(b.ico, b.animdata)
            end
        end
    end

    -- Open dropdown menus: emote rows are inline-text FontStrings.
    for level = 1, (UIDROPDOWNMENU_MAXLEVELS or 3) do
        local list = _G["DropDownList" .. level]
        if list and list:IsShown() then
            for i = 1, (UIDROPDOWNMENU_MAXBUTTONS or 40) do
                local btn = _G["DropDownList" .. level .. "Button" .. i]
                if btn and btn:IsShown() then
                    local fs = btn:GetFontString()
                    if fs then UpdateFontString(fs, 28, 28) end
                end
            end
        end
    end

    -- Chat bubbles: our own overlay FontString carries the emote text.
    if C_ChatBubbles then
        for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles()) do
            local ov = bubble.tweOverlay
            if ov and ov:IsShown() then
                UpdateFontString(ov, 28, 28)
            end
        end
    end

    -- Stats screen: featured emotes are Textures; the sent/seen lists are
    -- inline-text FontString regions of the frame.
    local sw = TwitchEmotesStatsFrame
    if sw and sw:IsShown() then
        if sw.topSentTex and sw.topSentTex.animdata then CropToCurrentFrame(sw.topSentTex, sw.topSentTex.animdata) end
        if sw.topSeenTex and sw.topSeenTex.animdata then CropToCurrentFrame(sw.topSeenTex, sw.topSeenTex.animdata) end
        for j = 1, sw:GetNumRegions() do
            local region = select(j, sw:GetRegions())
            if region and region:GetObjectType() == "FontString" then
                UpdateFontString(region, 16, 16)
            end
        end
    end
end)
