-- WTBox: opt-in EN->ZH compose box on top of WoWTranslate's translation engine.
-- Normal chat is never touched. Open the box only when you want to say
-- something in Chinese: type English, Translate, review/edit, Send.
-- Styled via pfUI's API when pfUI is present, so it blends into the UI.

WTBoxDB = WTBoxDB or {}

local CHANNELS = {
    { key = "SAY",          label = "Say",     short = "S",  color = "|cffffffff" },
    { key = "YELL",         label = "Yell",    short = "Y",  color = "|cffff4040" },
    { key = "PARTY",        label = "Party",   short = "P",  color = "|cffaaaaff" },
    { key = "RAID",         label = "Raid",    short = "R",  color = "|cffff7f00" },
    { key = "BATTLEGROUND", label = "BG",      short = "BG", color = "|cffffc0c0" },
    { key = "GUILD",        label = "Guild",   short = "G",  color = "|cff40ff40" },
    { key = "OFFICER",      label = "Officer", short = "O",  color = "|cff40c040" },
    { key = "WHISPER",      label = "Whisper", short = "W",  color = "|cffff80ff" },
    { key = "CHANNEL",      label = "Channel", short = "Ch", color = "|cffffb380" },
}
local IDX = { SAY = 1, YELL = 2, PARTY = 3, RAID = 4, BATTLEGROUND = 5, GUILD = 6,
              OFFICER = 7, WHISPER = 8, CHANNEL = 9 }

-- ============================================================================
-- Localization + translation direction
-- ============================================================================
-- Direction comes live from WoWTranslate's config, so a Chinese player whose
-- WoWTranslate is set to zh->en outgoing gets a ZH->EN compose box for free.

local function GetLangs()
    local from = (WoWTranslateDB and WoWTranslateDB.outgoingFromLang) or "en"
    local to = (WoWTranslateDB and WoWTranslateDB.outgoingToLang) or "zh"
    return from, to
end

local LOCALES = {
    en = {
        langNames = { en = "EN", zh = "ZH" },
        translate = "Translate", verify = "Verify", send_fmt = "Send %s",
        nothing_send = "Nothing to send.",
        too_long_fmt = "too long: %d/%d",
        whisper_target = "Enter a whisper target.",
        channel_number = "Enter a channel number.",
        not_in_channel_fmt = "Not in channel '%s'.",
        dup_blocked = "Duplicate blocked (2s).",
        sent_fmt = "Sent to %s.",
        type_first = "Type something first.",
        wt_not_loaded = "WoWTranslate addon not loaded.",
        dll_not_responding = "WoWTranslate.dll not responding.",
        translating = "Translating...",
        bytes_ms_fmt = "%d/%d - %dms",
        bytes_glossary_fmt = "%d/%d - glossary",
        bytes_too_long_fmt = "%d/%d - too long!",
        error_fmt = "Error: %s",
        queue_full = "Queue full - try again.",
        nothing_verify = "Nothing to verify - translate first.",
        verifying = "verifying...",
        back_prefix = "back: ",
        verify_failed_fmt = "verify failed: %s",
        no_channels = "No channels joined.",
        unusable = {
            PARTY = "Not in a party.", RAID = "Not in a raid.",
            BATTLEGROUND = "Not in a battleground.",
            GUILD = "Not in a guild.", OFFICER = "Not in a guild.",
        },
        chShort = { SAY = "S", YELL = "Y", PARTY = "P", RAID = "R", BATTLEGROUND = "BG",
                    GUILD = "G", OFFICER = "O", WHISPER = "W", CHANNEL = "Ch" },
        chLabel = { SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid",
                    BATTLEGROUND = "BG", GUILD = "Guild", OFFICER = "Officer",
                    WHISPER = "Whisper", CHANNEL = "Channel" },
        pin = "Pin open", opacity = "Background opacity",
        width = "Width",
        immersive = "Immersive fade",
        immersive_tip = "Fade the box out gently after 10 seconds of no hover, typing, or activity. Hover it (or press your keybind) and it snaps back instantly.",
        style_fmt = "Style: %s",
        styleNames = { modern = "Modern", classic = "Classic", pfui = "pfUI" },
        style_tip = "Modern is the built-in flat look, Classic the standard Blizzard style; pfUI matches your pfUI setup (offered only while pfUI is loaded). Click Apply to reload the UI and activate it.",
        style_changed = "style: %s (applies after reload/relog)",
        apply = "Apply",
        reload_prompt = "Style changes take effect after a UI reload. Reload now?",
        ok = "OK", cancel = "Cancel",
        pin_tip = "Keep the box open permanently, even across logins. The x button only hides it until the next login.",
        settings_tooltip = "WTBox settings",
        loaded = "loaded. /wtb to open, /wtb help for options.",
        merged_fmt = " Merged %d custom glossary entries.",
        lang_set = "UI language: %s (takes effect after reload/relog)",
        help = {
            "/wtb            - toggle the box",
            "/wtb <text>     - open and translate <text>",
            "/wtb pin        - keep the box always open",
            "/wtb alpha <0-100> - background opacity",
            "/wtb lang en|zh|auto - UI language",
            "/wtb style modern|classic|pfui - look (after reload)",
            "/wtb reset      - reset position",
        },
    },
    zh = {
        langNames = { en = "英文", zh = "中文" },
        translate = "翻译", verify = "回译", send_fmt = "发%s",
        nothing_send = "没有可发送的内容。",
        too_long_fmt = "太长：%d/%d",
        whisper_target = "请输入密语对象。",
        channel_number = "请输入频道编号。",
        not_in_channel_fmt = "未加入频道'%s'。",
        dup_blocked = "重复已拦截(2秒)",
        sent_fmt = "已发送至%s。",
        type_first = "请先输入内容。",
        wt_not_loaded = "WoWTranslate 插件未加载。",
        dll_not_responding = "WoWTranslate.dll 无响应。",
        translating = "翻译中...",
        bytes_ms_fmt = "%d/%d - %dms",
        bytes_glossary_fmt = "%d/%d - 词典",
        bytes_too_long_fmt = "%d/%d - 太长！",
        error_fmt = "错误：%s",
        queue_full = "队列已满 - 请重试。",
        nothing_verify = "请先翻译再回译。",
        verifying = "回译中...",
        back_prefix = "回译: ",
        verify_failed_fmt = "回译失败: %s",
        no_channels = "未加入任何频道。",
        unusable = {
            PARTY = "未组队。", RAID = "不在团队中。",
            BATTLEGROUND = "不在战场中。",
            GUILD = "未加入公会。", OFFICER = "未加入公会。",
        },
        chShort = { SAY = "说", YELL = "喊", PARTY = "队", RAID = "团", BATTLEGROUND = "战",
                    GUILD = "会", OFFICER = "官", WHISPER = "密", CHANNEL = "频" },
        chLabel = { SAY = "说话", YELL = "大喊", PARTY = "小队", RAID = "团队",
                    BATTLEGROUND = "战场", GUILD = "公会", OFFICER = "官员",
                    WHISPER = "密语", CHANNEL = "频道" },
        pin = "常驻打开", opacity = "背景不透明度",
        width = "宽度",
        immersive = "沉浸淡出",
        immersive_tip = "闲置 10 秒（无悬停、无输入）后翻译框缓慢淡出；将鼠标移上去或按快捷键立即恢复。",
        style_fmt = "风格：%s",
        styleNames = { modern = "现代", classic = "经典", pfui = "pfUI" },
        style_tip = "现代为内置扁平风格，经典为暴雪默认样式；pfUI 匹配你的 pfUI 外观（仅在加载 pfUI 时可选）。点击应用按钮重载界面生效。",
        style_changed = "风格：%s（重载界面后生效）",
        apply = "应用",
        reload_prompt = "界面风格将在重载界面后生效。现在重载？",
        ok = "确定", cancel = "取消",
        pin_tip = "让翻译框保持常驻显示（重新登录后依然打开）。x 按钮只会隐藏到下次登录。",
        settings_tooltip = "WTBox 设置",
        loaded = "已加载。输入 /wtb 打开翻译框，/wtb help 查看命令。",
        merged_fmt = " 已合并 %d 条自定义词条。",
        lang_set = "界面语言：%s（重载界面或重新登录后生效）",
        help = {
            "/wtb            - 打开/关闭翻译框",
            "/wtb <文本>     - 打开并立即翻译<文本>",
            "/wtb pin        - 常驻显示翻译框",
            "/wtb alpha <0-100> - 背景不透明度",
            "/wtb lang en|zh|auto - 界面语言",
            "/wtb style modern|classic|pfui - 界面风格（重载后生效）",
            "/wtb reset      - 重置位置",
        },
    },
}

local L = LOCALES.en

local function LangName(code)
    return L.langNames[code] or string.upper(code)
end

-- UI language: explicit setting, else follow the translation direction
-- (outgoing FROM Chinese means a Chinese-speaking user)
local function ResolveLocale()
    local lang = WTBoxDB.uiLang
    if lang ~= "en" and lang ~= "zh" then
        local from = GetLangs()
        lang = (from == "zh") and "zh" or "en"
    end
    L = LOCALES[lang] or LOCALES.en
end

local MAX_CHAT_BYTES = 255
local frame, inputBox, previewBox, statusText, targetBox, translateButton
local verifyText, verifyButton
local settingsFrame, pinCheck, immersiveCheck, styleButton, applyButton, alphaSlider, alphaValueLabel
local widthSlider, widthValueLabel
local channelPopup
local channelButtons = {}
local bottomButtons = {}
local lastSendText, lastSendAt = nil, 0
local translating = false
local verifying = false
local manualChannel = false     -- user clicked a channel this open; smart-select stands down
local lastWhisperFrom = nil

-- ============================================================================
-- Immersive fade: when enabled, the box eases out after IDLE_SECONDS with no
-- hover/focus/activity, and eases back in on hover or keybind. The ticker
-- OnUpdate runs ONLY while the mode is on and the box is shown.
-- ============================================================================

local IDLE_SECONDS = 10
local FADE_OUT_TIME = 5
local FADE_IN_TIME = 0.2
local fade = { last = 0, target = 1, from = 1, start = 0, dur = 0, focused = false }
local fadeTicker

local function TouchActivity()
    fade.last = GetTime()
end

-- geometric hover test: works even at alpha 0 (OnEnter/OnLeave would also
-- misfire when the cursor moves onto child buttons)
local function IsOver(f)
    if not f or not f:IsVisible() or not f:GetLeft() then return false end
    local x, y = GetCursorPosition()
    local s = f:GetEffectiveScale()
    x = x / s
    y = y / s
    return x >= f:GetLeft() and x <= f:GetRight() and y >= f:GetBottom() and y <= f:GetTop()
end

-- ============================================================================
-- pfUI-aware styling helpers (fall back to plain style without pfUI)
-- ============================================================================

local function HasPfui()
    return pfUI and pfUI.api and pfUI.api.CreateBackdrop
end

-- pixel-perfect 1px border size; math adapted from pfUI (MIT, by Shagu)
local pixelSize
local function GetPixel()
    if pixelSize then return pixelSize end
    local scale = tonumber(GetCVar("uiScale")) or 1
    local _, _, _, h = string.find(GetCVar("gxResolution") or "", "(.+)x(.+)")
    h = tonumber(h)
    pixelSize = h and (768 / h / scale) or 1
    if pixelSize > 1 then pixelSize = 1 end
    if pixelSize < 0.5 then pixelSize = pixelSize * 2 end   -- HiDPI
    return pixelSize
end

-- Style is resolved ONCE at load ("pfui" | "modern" | "classic"): applying
-- it live would mean rebuilding every backdrop with leftover-texture edge
-- cases, while load-time styling is static draws - zero FPS cost forever.
local STYLE = "modern"
local function ResolveStyle()
    local s = WTBoxDB.style
    if s == "classic" or s == "modern" then
        STYLE = s
    else
        -- unset or pfui: pfUI when it is loaded, modern otherwise
        STYLE = HasPfui() and "pfui" or "modern"
    end
end

-- the style key shown/cycled in settings (pfui only offered while loaded)
local function CurrentStyleKey()
    local s = WTBoxDB.style
    if s == "pfui" and not HasPfui() then s = "modern" end
    if s ~= "modern" and s ~= "classic" and s ~= "pfui" then
        s = HasPfui() and "pfui" or "modern"
    end
    return s
end

local function SkinPanel(f, alpha)
    if STYLE == "pfui" then
        local ok = pcall(pfUI.api.CreateBackdrop, f, nil, nil, alpha or 0.85)
        if ok then return end
    end
    if STYLE == "classic" then
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.85)
        -- dark-tinted border: this is the original pre-theme look the users
        -- know; untinted it rendered as ugly white outlines on the small
        -- edit boxes. Classic's identity comes from the Blizzard-shaped
        -- buttons, not the panel border.
        f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        return
    end
    -- modern: flat fill with a pixel-perfect 1px border
    local px = GetPixel()
    f:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
        edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = px,
        insets = { left = -px, right = -px, top = -px, bottom = -px },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.85)
    f:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
end

local function SkinButtonFrame(b, keepArt)
    if STYLE == "pfui" and pfUI.api.SkinButton then
        local ok = pcall(pfUI.api.SkinButton, b)
        if ok then return end
    end
    -- compact 8pt font objects (WTBoxFonts.xml) for all three states, so
    -- hover/disable can't snap the size back up
    local fN = getglobal("WTBoxButtonFont")
    local fH = getglobal("WTBoxButtonFontHighlight")
    local fD = getglobal("WTBoxButtonFontDisable")
    if fN then b:SetTextFontObject(fN) end
    if fH then b:SetHighlightFontObject(fH) end
    if fD then b:SetDisabledFontObject(fD) end
    -- keepArt: keep the Blizzard red button art (used for Apply, where the
    -- attention-grabbing color is wanted)
    if keepArt then return end
    if STYLE == "classic" then
        -- keep the Blizzard beveled button SHAPE, but mute the red art to a
        -- neutral charcoal: desaturate (where the GPU supports it) + darken
        local nt = b:GetNormalTexture()
        local pt = b:GetPushedTexture()
        if nt then
            pcall(nt.SetDesaturated, nt, 1)
            nt:SetVertexColor(0.55, 0.55, 0.55)
            nt:SetAlpha(0.9)
        end
        if pt then
            pcall(pt.SetDesaturated, pt, 1)
            pt:SetVertexColor(0.45, 0.45, 0.45)
            pt:SetAlpha(0.9)
        end
        return
    end
    -- modern: muted dark flat buttons
    b:SetNormalTexture("")
    b:SetPushedTexture("")
    b:SetDisabledTexture("")
    local px = GetPixel()
    b:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = false, tileSize = 0,
        edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = px,
        insets = { left = -px, right = -px, top = -px, bottom = -px },
    })
    b:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    b:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    b:SetHighlightTexture("Interface\\BUTTONS\\WHITE8X8")
    local hl = b:GetHighlightTexture()
    if hl then hl:SetAlpha(0.1) end
end

-- Background opacity: text is untouched, only the backdrop fades.
-- pfUI backdrops live on a child frame (f.backdrop) with no text on it,
-- so SetAlpha there fades background+border only. The fallback style
-- re-tints the backdrop color instead.
local function ApplyAlphaTo(f, alpha)
    if not f then return end
    if f.backdrop and f.backdrop.SetAlpha then
        f.backdrop:SetAlpha(alpha)
    elseif f.SetBackdropColor then
        f:SetBackdropColor(0.06, 0.06, 0.06, alpha)
    end
end

local function GetAlpha()
    local a = WTBoxDB.alpha
    if a == nil then a = 0.85 end
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    return a
end

local function ApplyAlpha()
    local a = GetAlpha()
    ApplyAlphaTo(frame, a)
    ApplyAlphaTo(inputBox, a)
    ApplyAlphaTo(previewBox, a)
    ApplyAlphaTo(targetBox, a)
    ApplyAlphaTo(settingsFrame, a)
end

-- Set the immersive fade level. The 1.12 client cascades SetAlpha as an
-- ABSOLUTE value into child frames, clobbering the backdrop-opacity setting -
-- so after each step the saved background opacity is re-applied, scaled by
-- the fade level.
local function ApplyFadeAlpha(v)
    frame:SetAlpha(v)
    local a = GetAlpha() * v
    ApplyAlphaTo(frame, a)
    ApplyAlphaTo(inputBox, a)
    ApplyAlphaTo(previewBox, a)
    ApplyAlphaTo(targetBox, a)
    ApplyAlphaTo(settingsFrame, a)
end

local function EnsureFadeTicker()
    if fadeTicker then return end
    fadeTicker = CreateFrame("Frame")
    fadeTicker:Hide()
    fadeTicker:SetScript("OnUpdate", function()
        local now = GetTime()
        if fade.focused or IsOver(frame) or IsOver(settingsFrame) or IsOver(channelPopup) then
            fade.last = now
        end
        local desired = ((now - fade.last) < IDLE_SECONDS) and 1 or 0
        if desired ~= fade.target then
            fade.target = desired
            fade.from = frame:GetAlpha()
            fade.start = now
            fade.dur = (desired == 1) and FADE_IN_TIME or FADE_OUT_TIME
        end
        if frame:GetAlpha() ~= fade.target then
            local p = (now - fade.start) / fade.dur
            if p >= 1 then
                ApplyFadeAlpha(fade.target)
            else
                -- smoothstep: ease in, ease out
                local e = p * p * (3 - 2 * p)
                ApplyFadeAlpha(fade.from + (fade.target - fade.from) * e)
            end
        end
    end)
end

local function ApplyImmersive()
    if WTBoxDB.immersive and frame and frame:IsVisible() then
        EnsureFadeTicker()
        TouchActivity()
        fade.target = 1
        ApplyFadeAlpha(1)
        fadeTicker:Show()
    else
        if fadeTicker then fadeTicker:Hide() end
        if frame then
            frame:SetAlpha(1)
            ApplyAlpha()   -- restore the exact saved backdrop opacity
        end
        fade.target = 1
    end
end

local function Status(msg, r, g, b)
    if statusText then
        statusText:SetText(msg or "")
        statusText:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
    end
    TouchActivity()   -- any feedback counts as activity for the immersive fade
end

-- Release keyboard back to the game. Safe to call with nothing focused.
local function ClearBoxFocus()
    if inputBox then inputBox:ClearFocus() end
    if previewBox then previewBox:ClearFocus() end
    if targetBox then targetBox:ClearFocus() end
end

-- Reflect current saved settings in the settings panel widgets
local function SyncSettingsUI()
    if not settingsFrame then return end
    pinCheck:SetChecked(WTBoxDB.pinned and 1 or nil)
    immersiveCheck:SetChecked(WTBoxDB.immersive and 1 or nil)
    if styleButton then
        styleButton:SetText(string.format(L.style_fmt, L.styleNames[CurrentStyleKey()]))
    end
    if applyButton then
        -- nothing to apply when the selected style is already active
        if CurrentStyleKey() == STYLE then
            applyButton:Disable()
        else
            applyButton:Enable()
        end
    end
    local pct = math.floor(GetAlpha() * 100 + 0.5)
    alphaSlider:SetValue(pct)
    alphaValueLabel:SetText(pct .. "%")
    if widthSlider then
        local w = WTBoxDB.width or 340
        widthSlider:SetValue(w)
        widthValueLabel:SetText(tostring(w))
    end
end

local function CycleStyle()
    local order = HasPfui() and { "modern", "classic", "pfui" } or { "modern", "classic" }
    local cur = CurrentStyleKey()
    local idx = 1
    for i = 1, table.getn(order) do
        if order[i] == cur then idx = i end
    end
    WTBoxDB.style = order[math.mod(idx, table.getn(order)) + 1]
    SyncSettingsUI()
end

-- ============================================================================
-- Screen bounds guard: after UI scale / resolution changes a saved position
-- can be entirely off-screen. If so, forget it and center the box.
-- ============================================================================

local function EnsureOnScreen()
    if not frame or not frame:GetLeft() then return end
    local fs = frame:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    local sw = UIParent:GetWidth() * us
    local sh = UIParent:GetHeight() * us
    local l = frame:GetLeft() * fs
    local r = frame:GetRight() * fs
    local b = frame:GetBottom() * fs
    local t = frame:GetTop() * fs
    if l < 0 or b < 0 or r > sw or t > sh then
        WTBoxDB.posX = nil
        WTBoxDB.posY = nil
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ============================================================================
-- Responsive layout: the channel row and the bottom button row flow like
-- text and wrap onto extra lines when the box is narrow; the frame height
-- follows. Runs only at build time and when the width slider moves.
-- ============================================================================

local function Relayout()
    if not frame or not inputBox then return end
    local W = WTBoxDB.width or 340
    if W < 220 then W = 220 elseif W > 420 then W = 420 end
    frame:SetWidth(W)
    local right = W - 8

    -- channel row(s): buttons + the target box flow left to right
    local x, y = 8, -24
    local rows = 1
    local function place(item, w, gap)
        if x + w > right and x > 8 then
            x = 8
            y = y - 20
            rows = rows + 1
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        x = x + w + gap
    end
    for i = 1, table.getn(channelButtons) do
        place(channelButtons[i], channelButtons[i]:GetWidth(), 2)
    end
    place(targetBox, targetBox:GetWidth(), 2)

    -- edit boxes and text widths
    local ebH = (STYLE == "classic") and 22 or 18
    local inner = W - 16
    local top = 24 + rows * 20 + 2
    inputBox:ClearAllPoints()
    inputBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -top)
    inputBox:SetWidth(inner)
    previewBox:SetWidth(inner)
    verifyText:SetWidth(inner - 4)
    statusText:SetWidth(math.max(60, W - 200))

    -- bottom button row(s)
    local bTop = top + ebH + 4 + ebH + 3 + 13 + 4
    x, y = 8, -bTop
    local bRows = 1
    for i = 1, table.getn(bottomButtons) do
        local b = bottomButtons[i]
        local w = b:GetWidth()
        if x + w > right and x > 8 then
            x = 8
            y = y - 21
            bRows = bRows + 1
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        x = x + w + 3
    end

    frame:SetHeight(bTop + bRows * 18 + (bRows - 1) * 3 + 7)
end

-- ============================================================================
-- Channel selection: quick buttons + context-aware preselect
-- ============================================================================

local function CurrentChannel()
    local i = WTBoxDB.channel or 1
    if not CHANNELS[i] then i = 1 end
    return CHANNELS[i], i
end

local function InBattleground()
    for i = 1, 3 do
        if GetBattlefieldStatus and GetBattlefieldStatus(i) == "active" then
            return true
        end
    end
    return false
end

-- Can this channel be used right now? Buttons stay in FIXED positions and
-- only dim when unusable - a re-flowing row would shift buttons under the
-- cursor mid-fight.
local function ChannelUsable(key)
    if key == "PARTY" then
        return GetNumPartyMembers() > 0
    elseif key == "RAID" then
        return GetNumRaidMembers() > 0
    elseif key == "BATTLEGROUND" then
        return InBattleground()
    elseif key == "GUILD" or key == "OFFICER" then
        return IsInGuild() and true or false
    end
    return true
end

-- Numbered channels renumber when one is left, so identity is stored by
-- NAME (WTBoxDB.channelName) and resolved to a number when needed.
local function FindChannelByName(wanted)
    local list = { GetChannelList() }
    for i = 1, table.getn(list), 2 do
        if list[i + 1] == wanted then return list[i] end
    end
    return nil
end

local function FindWorldChannel()
    local list = { GetChannelList() }
    for i = 1, table.getn(list), 2 do
        local name = list[i + 1]
        if type(name) == "string" and string.find(name, "World") then
            return list[i], name
        end
    end
    return nil
end

local function UpdateChannelButtons()
    if not targetBox then return end   -- UI not (fully) built yet
    local current, active = CurrentChannel()
    for i, b in ipairs(channelButtons) do
        local ch = CHANNELS[i]
        local short = L.chShort[ch.key] or ch.short
        if i == active then
            b:SetText(ch.color .. short .. "|r")
        elseif ChannelUsable(ch.key) then
            b:SetText("|cff777777" .. short .. "|r")
        else
            b:SetText("|cff3a3a3a" .. short .. "|r")
        end
    end
    if current.key == "WHISPER" then
        targetBox:Show()
        -- leftover channel number from Ch mode is not a name
        if tonumber(targetBox:GetText()) then targetBox:SetText("") end
        if targetBox:GetText() == "" and lastWhisperFrom then
            targetBox:SetText(lastWhisperFrom)
        end
    elseif current.key == "CHANNEL" then
        targetBox:Show()
        -- leftover whisper name is not a channel number
        if targetBox:GetText() ~= "" and not tonumber(targetBox:GetText()) then
            targetBox:SetText("")
        end
        if targetBox:GetText() == "" then
            local num = WTBoxDB.channelName and FindChannelByName(WTBoxDB.channelName)
            if not num then
                local id, name = FindWorldChannel()
                num = id
                if name then WTBoxDB.channelName = name end
            end
            if num then targetBox:SetText(tostring(num)) end
        end
    else
        targetBox:Hide()
    end
end

local function SelectChannel(i, manual)
    if manual and CHANNELS[i] and not ChannelUsable(CHANNELS[i].key) then
        Status(L.unusable[CHANNELS[i].key] or "?", 1, 0.4, 0.4)
        return
    end
    WTBoxDB.channel = i
    if manual then manualChannel = true end
    UpdateChannelButtons()
end

local function SmartSelect()
    if InBattleground() then
        SelectChannel(IDX.BATTLEGROUND)
    elseif GetNumRaidMembers() > 0 then
        SelectChannel(IDX.RAID)
    elseif GetNumPartyMembers() > 0 then
        SelectChannel(IDX.PARTY)
    else
        SelectChannel(IDX.SAY)
    end
end

-- Generic drop-up list shared by the Ch and W buttons.
-- items: array of { text = string, gold = boolean, func = function(item) }
local function OpenListPopup(anchor, items)
    if channelPopup and channelPopup:IsVisible() and channelPopup.anchor == anchor then
        channelPopup:Hide()
        return
    end
    if not channelPopup then
        channelPopup = CreateFrame("Frame", "WTBoxListPopup", frame)
        channelPopup:SetFrameStrata("DIALOG")
        channelPopup:SetFrameLevel(20)
        SkinPanel(channelPopup, 0.95)
        channelPopup.rows = {}
        -- invisible fullscreen catcher just below the popup: clicking
        -- anywhere outside the list closes it (Blizzard-dropdown pattern)
        local catcher = CreateFrame("Button", "WTBoxPopupCatcher", UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(10)
        catcher:SetAllPoints(UIParent)
        catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        catcher:Hide()
        catcher:SetScript("OnClick", function() channelPopup:Hide() end)
        channelPopup:SetScript("OnShow", function() catcher:Show() end)
        channelPopup:SetScript("OnHide", function() catcher:Hide() end)
    end
    channelPopup.anchor = anchor
    local count = table.getn(items)
    for idx = 1, count do
        local row = channelPopup.rows[idx]
        if not row then
            row = CreateFrame("Button", nil, channelPopup)
            row:SetWidth(150)
            row:SetHeight(16)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
            row:SetScript("OnEnter", function() this.label:SetTextColor(1, 1, 1) end)
            row:SetScript("OnLeave", function()
                this.label:SetTextColor(this.baseR, this.baseG, this.baseB)
            end)
            row:SetScript("OnClick", function()
                channelPopup:Hide()
                if this.item and this.item.func then this.item.func(this.item) end
            end)
            channelPopup.rows[idx] = row
        end
        row:SetPoint("TOPLEFT", channelPopup, "TOPLEFT", 4, -4 - (idx - 1) * 16)
        row.item = items[idx]
        row.label:SetText(items[idx].text)
        if items[idx].gold then
            row.baseR, row.baseG, row.baseB = 1, 0.82, 0
        else
            row.baseR, row.baseG, row.baseB = 0.8, 0.8, 0.8
        end
        row.label:SetTextColor(row.baseR, row.baseG, row.baseB)
        row:Show()
    end
    for j = count + 1, table.getn(channelPopup.rows) do
        channelPopup.rows[j]:Hide()
    end
    if count == 0 then return end
    channelPopup:SetWidth(158)
    channelPopup:SetHeight(count * 16 + 8)
    channelPopup:ClearAllPoints()
    channelPopup:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
    channelPopup:Show()
end

-- Ch drop-up: joined channels by name, built fresh from GetChannelList()
-- on each open (the list is empty-ish right after login, so never cache it)
local function OpenChannelPopup(anchor)
    local items = {}
    local list = { GetChannelList() }
    for i = 1, table.getn(list), 2 do
        local id, name = list[i], list[i + 1]
        if type(name) == "string" then
            table.insert(items, {
                text = id .. ". " .. name,
                gold = (name == WTBoxDB.channelName),
                id = id, name = name,
                func = function(item)
                    WTBoxDB.channelName = item.name
                    targetBox:SetText(tostring(item.id))
                    SelectChannel(IDX.CHANNEL, true)
                end,
            })
        end
    end
    if table.getn(items) == 0 then
        Status(L.no_channels, 1, 0.4, 0.4)
        return
    end
    OpenListPopup(anchor, items)
end

-- W drop-up: last 5 whisper contacts (incoming and outgoing), newest first
local MAX_RECENT_WHISPERS = 5
local function AddRecentWhisper(name)
    if not name or name == "" then return end
    WTBoxDB.recentWhispers = WTBoxDB.recentWhispers or {}
    local t = WTBoxDB.recentWhispers
    for i = table.getn(t), 1, -1 do
        if t[i] == name then table.remove(t, i) end
    end
    table.insert(t, 1, name)
    while table.getn(t) > MAX_RECENT_WHISPERS do
        table.remove(t)
    end
end

local function OpenWhisperPopup(anchor)
    local items = {}
    local t = WTBoxDB.recentWhispers or {}
    for i = 1, table.getn(t) do
        local name = t[i]
        table.insert(items, {
            text = name,
            gold = (targetBox and name == targetBox:GetText()),
            func = function(item)
                targetBox:SetText(item.text)
                SelectChannel(IDX.WHISPER, true)
            end,
        })
    end
    OpenListPopup(anchor, items)
end

-- ============================================================================
-- Core logic
-- ============================================================================

local function DoSend(text)
    if not text or text == "" then
        Status(L.nothing_send, 1, 0.4, 0.4)
        return
    end
    if string.len(text) > MAX_CHAT_BYTES then
        Status(string.format(L.too_long_fmt, string.len(text), MAX_CHAT_BYTES), 1, 0.4, 0.4)
        return
    end
    local ch = CurrentChannel()
    local target = nil
    if ch.key == "WHISPER" then
        target = targetBox:GetText()
        if not target or target == "" then
            Status(L.whisper_target, 1, 0.4, 0.4)
            targetBox:SetFocus()
            return
        end
    elseif ch.key == "CHANNEL" then
        local typed = tonumber(targetBox:GetText())
        local resolved = WTBoxDB.channelName and FindChannelByName(WTBoxDB.channelName)
        if typed and resolved and typed ~= resolved then
            -- user typed a different number on purpose: adopt that channel
            local _, newName = GetChannelName(typed)
            if newName and newName ~= "" then WTBoxDB.channelName = newName end
            target = typed
        else
            target = resolved or typed
        end
        if not target then
            if WTBoxDB.channelName then
                Status(string.format(L.not_in_channel_fmt, WTBoxDB.channelName), 1, 0.4, 0.4)
            else
                Status(L.channel_number, 1, 0.4, 0.4)
                targetBox:SetFocus()
            end
            return
        end
        targetBox:SetText(tostring(target))
        if not WTBoxDB.channelName then
            local _, nm = GetChannelName(target)
            if nm and nm ~= "" then WTBoxDB.channelName = nm end
        end
    end
    -- double-send guard: inputs persist after send, so Enter-Enter (or a
    -- lag double-tap) would post the same line twice
    local now = GetTime()
    if text == lastSendText and (now - lastSendAt) < 2 then
        Status(L.dup_blocked, 1, 0.8, 0.4)
        return
    end
    lastSendText = text
    lastSendAt = now
    SendChatMessage(text, ch.key, nil, target)
    -- message is out: give the keyboard back to the game immediately
    ClearBoxFocus()
    -- inputs are kept on purpose: re-send untranslated or to another channel
    Status(string.format(L.sent_fmt, L.chLabel[ch.key] or ch.label), 0.4, 1, 0.4)
end

-- sendAfter: translate and immediately post the result (Send CN with an
-- untranslated input) - saves the extra Translate click
local function DoTranslate(sendAfter)
    if translating then return end
    local text = inputBox:GetText()
    if not text or text == "" then
        Status(L.type_first, 1, 0.4, 0.4)
        inputBox:SetFocus()
        return
    end

    if not WoWTranslate_API then
        Status(L.wt_not_loaded, 1, 0.4, 0.4)
        return
    end
    if not WoWTranslate_API.IsAvailable() then
        WoWTranslate_API.CheckDLL()
        if not WoWTranslate_API.IsAvailable() then
            Status(L.dll_not_responding, 1, 0.4, 0.4)
            return
        end
    end

    -- WoWTranslate's out-glossaries are authored English-keyed -> Chinese,
    -- so only apply them when actually translating FROM English
    local fromLang = GetLangs()
    local toTranslate = text
    if fromLang == "en" then
        -- Whole-message glossary hit needs no machine translation at all
        if WoWTranslate_CheckOutGlossaryExact then
            local exact = WoWTranslate_CheckOutGlossaryExact(text)
            if exact then
                previewBox:SetText(exact)
                if sendAfter then
                    DoSend(exact)
                else
                    Status(string.format(L.bytes_glossary_fmt, string.len(exact), MAX_CHAT_BYTES), 0.4, 1, 0.4)
                end
                return
            end
        end
        -- Substitute known WoW terms before machine translation
        if WoWTranslate_CheckOutGlossaryPartial then
            local partial = WoWTranslate_CheckOutGlossaryPartial(text)
            if partial then toTranslate = partial end
        end
    end

    translating = true
    translateButton:Disable()
    if verifyText then verifyText:SetText("") end
    Status(L.translating, 0.8, 0.8, 0.4)

    local startedAt = GetTime()
    local ok = WoWTranslate_API.TranslateOutgoing(toTranslate, function(translation, err)
        translating = false
        translateButton:Enable()
        if err or not translation then
            Status(string.format(L.error_fmt, tostring(err)), 1, 0.4, 0.4)
        else
            previewBox:SetText(translation)
            local bytes = string.len(translation)
            local ms = math.floor((GetTime() - startedAt) * 1000 + 0.5)
            if bytes > MAX_CHAT_BYTES then
                Status(string.format(L.bytes_too_long_fmt, bytes, MAX_CHAT_BYTES), 1, 0.4, 0.4)
            elseif sendAfter then
                DoSend(translation)
            else
                Status(string.format(L.bytes_ms_fmt, bytes, MAX_CHAT_BYTES, ms), 0.4, 1, 0.4)
            end
        end
    end)

    if not ok then
        translating = false
        translateButton:Enable()
        Status(L.queue_full, 1, 0.4, 0.4)
    end
end

-- Back-translate the Chinese preview to English so the user can check it
-- in-game (the 1.12 client cannot copy Chinese to the clipboard).
local function DoVerify()
    if verifying then return end
    local text = previewBox:GetText()
    if not text or text == "" then
        Status(L.nothing_verify, 1, 0.4, 0.4)
        return
    end
    if not WoWTranslate_API or not WoWTranslate_API.IsAvailable() then
        Status(L.dll_not_responding, 1, 0.4, 0.4)
        return
    end

    verifying = true
    verifyButton:Disable()
    verifyText:SetText("|cff888888" .. L.verifying .. "|r")

    -- back-translate from the outgoing TARGET language; WoWTranslate's
    -- incoming target (the user's own language) is the destination
    local _, toLang = GetLangs()
    local ok = WoWTranslate_API.Translate(text, function(translation, err)
        verifying = false
        verifyButton:Enable()
        if err or not translation then
            verifyText:SetText("|cffff6060" .. string.format(L.verify_failed_fmt, tostring(err)) .. "|r")
        else
            verifyText:SetText("|cffaad8ff" .. L.back_prefix .. "|r" .. translation)
        end
    end, toLang)

    if not ok then
        verifying = false
        verifyButton:Enable()
        verifyText:SetText("|cffff6060could not queue verify request|r")
    end
end

-- ============================================================================
-- UI
-- ============================================================================

local function MakeEditBox(name, width)
    local eb = CreateFrame("EditBox", name, frame)
    eb:SetWidth(width)
    -- classic's bordered fields need more breathing room than the flat ones
    eb:SetHeight(STYLE == "classic" and 22 or 18)
    eb:SetFontObject(ChatFontNormal)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(255)
    SkinPanel(eb, 0.6)
    eb:SetTextInsets(5, 5, 0, 0)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function()
        fade.focused = true
        TouchActivity()
    end)
    eb:SetScript("OnEditFocusLost", function()
        fade.focused = false
        TouchActivity()
    end)
    -- double-click selects all; OnDoubleClick is Button-only in 1.12, so
    -- detect it manually from two OnMouseDown events in quick succession
    eb.lastClick = 0
    eb:SetScript("OnMouseDown", function()
        local now = GetTime()
        if now - this.lastClick < 0.4 then
            this:HighlightText()
        end
        this.lastClick = now
    end)
    return eb
end

local function MakeButton(name, width, text, onClick, parent, keepArt)
    local b = CreateFrame("Button", name, parent or frame, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(18)
    b:SetText(text)
    -- any button click releases the keyboard so game keybinds work again
    -- (combat!); handlers that deliberately focus a field run after and win
    b:SetScript("OnClick", function()
        ClearBoxFocus()
        TouchActivity()
        onClick()
    end)
    SkinButtonFrame(b, keepArt)
    return b
end

-- The UI is built by THREE functions instead of one: Lua 5.0 allows a
-- function to reference at most 32 outer locals (upvalues), and a single
-- big builder exceeds that - the client then refuses to load the whole
-- file. Keep each builder's outer-local footprint lean.
local function CreateMainUI()
    frame = CreateFrame("Frame", "WTBoxFrame", UIParent)
    frame:Hide()   -- frames spawn visible; hide FIRST so a failed build stays hidden
    frame:SetWidth(WTBoxDB.width or 340)
    frame:SetHeight(146)   -- placeholder; Relayout computes the real size
    SkinPanel(frame, 0.85)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        WTBoxDB.posX = x - ux
        WTBoxDB.posY = y - uy
    end)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    if WTBoxDB.posX then
        frame:SetPoint("CENTER", UIParent, "CENTER", WTBoxDB.posX, WTBoxDB.posY)
    else
        -- default: bottom right, just above pfUI's right chat dock
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -15, 235)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
    local dirFrom, dirTo = GetLangs()
    title:SetText("|cff33ffccWT|rBox  |cff666666" .. string.upper(dirFrom) .. ">" .. string.upper(dirTo) .. "|r")

    local close = MakeButton("WTBoxCloseButton", 16, "x", function() frame:Hide() end)
    close:SetHeight(16)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    -- quick channel buttons (positioned by Relayout)
    local widths = { 24, 24, 24, 24, 28, 24, 24, 24, 28 }
    for i = 1, 9 do
        local idx = i
        local b = MakeButton("WTBoxChan" .. CHANNELS[i].key, widths[i], CHANNELS[i].short,
            function() SelectChannel(idx, true) end)
        if CHANNELS[i].key == "CHANNEL" then
            -- clicking Ch opens a drop-up of joined channels to pick from
            b:SetScript("OnClick", function()
                ClearBoxFocus()
                OpenChannelPopup(this)
            end)
        elseif CHANNELS[i].key == "WHISPER" then
            -- clicking W selects whisper mode and offers recent contacts;
            -- with none yet, put the cursor straight into the target field
            b:SetScript("OnClick", function()
                ClearBoxFocus()
                SelectChannel(idx, true)
                local t = WTBoxDB.recentWhispers
                if t and table.getn(t) > 0 then
                    OpenWhisperPopup(this)
                else
                    targetBox:SetFocus()
                end
            end)
        end
        channelButtons[i] = b
    end

    targetBox = MakeEditBox("WTBoxTargetBox", 78)
    targetBox:SetMaxLetters(12)
    targetBox:SetScript("OnEnterPressed", function() inputBox:SetFocus() end)

    inputBox = MakeEditBox("WTBoxInputBox", 324)
    inputBox:SetTextInsets(5, 16, 0, 0)
    -- Escape releases focus only (MakeEditBox default); hiding the whole
    -- window on Escape threw players out of the box mid-thought
    -- Enter = translate AND post in one go: combat callouts are the default
    -- use case. The Translate button is the review-first path.
    inputBox:SetScript("OnEnterPressed", function() DoTranslate(true) end)

    -- subtle clear button inside the right end of the input
    local clearBtn = CreateFrame("Button", "WTBoxClearButton", frame)
    clearBtn:SetWidth(12)
    clearBtn:SetHeight(12)
    clearBtn:SetPoint("RIGHT", inputBox, "RIGHT", -3, 0)
    clearBtn:SetFrameLevel(inputBox:GetFrameLevel() + 2)
    local clearLabel = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- centered with a 1px upward nudge: the lowercase glyph + its shadow
    -- read visually low, noticeable in the taller classic input
    clearLabel:SetPoint("CENTER", clearBtn, "CENTER", 0, 1)
    clearLabel:SetText("|cff777777x|r")
    clearBtn:SetScript("OnClick", function()
        inputBox:SetText("")
        previewBox:SetText("")
        if verifyText then verifyText:SetText("") end
        Status("")
    end)
    clearBtn:SetScript("OnEnter", function() clearLabel:SetText("|cffffffffx|r") end)
    clearBtn:SetScript("OnLeave", function() clearLabel:SetText("|cff777777x|r") end)

    previewBox = MakeEditBox("WTBoxPreviewBox", 324)
    previewBox:SetPoint("TOPLEFT", inputBox, "BOTTOMLEFT", 0, -4)
    previewBox:SetScript("OnEnterPressed", function() DoSend(previewBox:GetText()) end)

    verifyText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verifyText:SetPoint("TOPLEFT", previewBox, "BOTTOMLEFT", 2, -3)
    verifyText:SetWidth(320)
    verifyText:SetHeight(13)   -- one line; the old 2-line reserve read as dead space
    verifyText:SetJustifyH("LEFT")
    verifyText:SetJustifyV("TOP")

    translateButton = MakeButton("WTBoxTranslateButton", 68, L.translate, DoTranslate)

    local sendTrans = MakeButton("WTBoxSendButton", 64, string.format(L.send_fmt, LangName(dirTo)), function()
        local preview = previewBox:GetText()
        if preview ~= "" then
            DoSend(preview)
        else
            -- nothing translated yet: translate the input and post directly
            DoTranslate(true)
        end
    end)

    local sendOrig = MakeButton("WTBoxSendENButton", 64, string.format(L.send_fmt, LangName(dirFrom)),
        function() DoSend(inputBox:GetText()) end)

    verifyButton = MakeButton("WTBoxVerifyButton", 50, L.verify, DoVerify)

    bottomButtons = { translateButton, sendTrans, sendOrig, verifyButton }

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, -8)
    statusText:SetJustifyH("RIGHT")
    statusText:SetWidth(140)
    -- one line, slightly smaller than the rest of the UI
    local sFont, _, sFlags = statusText:GetFont()
    if sFont then statusText:SetFont(sFont, 9, sFlags) end
    statusText:SetHeight(10)

    Relayout()
end

local function CreateSettingsUI()
    -- settings panel (expands below the box via the cfg button, or above
    -- when the box sits too close to the bottom of the screen)
    settingsFrame = CreateFrame("Frame", "WTBoxSettings", frame)
    settingsFrame:SetWidth(340)
    settingsFrame:SetHeight(124)
    settingsFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
    SkinPanel(settingsFrame, 0.85)
    settingsFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    settingsFrame:Hide()

    pinCheck = CreateFrame("CheckButton", "WTBoxPinCheck", settingsFrame, "UICheckButtonTemplate")
    pinCheck:SetWidth(20)
    pinCheck:SetHeight(20)
    pinCheck:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 8, -6)
    getglobal("WTBoxPinCheckText"):SetText(L.pin)
    pinCheck:SetScript("OnClick", function()
        WTBoxDB.pinned = this:GetChecked() and true or false
    end)
    pinCheck:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.pin, 1, 1, 1)
        GameTooltip:AddLine(L.pin_tip, nil, nil, nil, 1)
        GameTooltip:Show()
    end)
    pinCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    immersiveCheck = CreateFrame("CheckButton", "WTBoxImmersiveCheck", settingsFrame, "UICheckButtonTemplate")
    immersiveCheck:SetWidth(20)
    immersiveCheck:SetHeight(20)
    immersiveCheck:SetPoint("TOPLEFT", pinCheck, "BOTTOMLEFT", 0, -2)
    getglobal("WTBoxImmersiveCheckText"):SetText(L.immersive)
    immersiveCheck:SetScript("OnClick", function()
        WTBoxDB.immersive = this:GetChecked() and true or false
        ApplyImmersive()
    end)
    immersiveCheck:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.immersive, 1, 1, 1)
        GameTooltip:AddLine(L.immersive_tip, nil, nil, nil, 1)
        GameTooltip:Show()
    end)
    immersiveCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- parented to the settings panel (not the main frame) so they hide with it
    styleButton = MakeButton("WTBoxStyleButton", 100, "", CycleStyle, settingsFrame)
    styleButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -66, -30)
    styleButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this:GetText(), 1, 1, 1)
        GameTooltip:AddLine(L.style_tip, nil, nil, nil, 1)
        GameTooltip:Show()
    end)
    styleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    StaticPopupDialogs["WTBOX_RELOAD_UI"] = {
        text = L.reload_prompt,
        button1 = L.ok,
        button2 = L.cancel,
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    applyButton = MakeButton("WTBoxStyleApplyButton", 50, L.apply, function()
        StaticPopup_Show("WTBOX_RELOAD_UI")
    end, settingsFrame, true)
    applyButton:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -12, -30)

    widthSlider = CreateFrame("Slider", "WTBoxWidthSlider", settingsFrame, "OptionsSliderTemplate")
    widthSlider:SetWidth(200)
    widthSlider:SetHeight(16)
    widthSlider:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 14, 44)
    widthSlider:SetMinMaxValues(220, 420)
    widthSlider:SetValueStep(10)
    getglobal("WTBoxWidthSliderLow"):SetText("")
    getglobal("WTBoxWidthSliderHigh"):SetText("")
    getglobal("WTBoxWidthSliderText"):SetText(L.width)
    widthSlider:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue() / 10 + 0.5) * 10
        WTBoxDB.width = v
        Relayout()   -- applies live: cheap repositioning, no rebuild
        if widthValueLabel then widthValueLabel:SetText(tostring(v)) end
    end)

    widthValueLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widthValueLabel:SetPoint("LEFT", widthSlider, "RIGHT", 10, 0)

    alphaSlider = CreateFrame("Slider", "WTBoxAlphaSlider", settingsFrame, "OptionsSliderTemplate")
    alphaSlider:SetWidth(200)
    alphaSlider:SetHeight(16)
    alphaSlider:SetPoint("BOTTOMLEFT", settingsFrame, "BOTTOMLEFT", 14, 10)
    alphaSlider:SetMinMaxValues(0, 100)
    alphaSlider:SetValueStep(5)
    getglobal("WTBoxAlphaSliderLow"):SetText("")
    getglobal("WTBoxAlphaSliderHigh"):SetText("")
    getglobal("WTBoxAlphaSliderText"):SetText(L.opacity)
    alphaSlider:SetScript("OnValueChanged", function()
        local v = math.floor(this:GetValue() + 0.5)
        WTBoxDB.alpha = v / 100
        ApplyAlpha()
        if alphaValueLabel then alphaValueLabel:SetText(v .. "%") end
    end)

    alphaValueLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaValueLabel:SetPoint("LEFT", alphaSlider, "RIGHT", 10, 0)

    local verText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verText:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -8, -8)
    local vFont, _, vFlags = verText:GetFont()
    if vFont then verText:SetFont(vFont, 9, vFlags) end
    local version = GetAddOnMetadata and GetAddOnMetadata("WTBox", "Version")
    verText:SetText("|cff555555v" .. (version or "?") .. "|r")

    local function ToggleSettingsPanel()
        if settingsFrame:IsVisible() then
            settingsFrame:Hide()
            return
        end
        SyncSettingsUI()
        -- open below when there is room on screen, otherwise above
        settingsFrame:ClearAllPoints()
        local fs = frame:GetEffectiveScale()
        local bottom = (frame:GetBottom() or 0) * fs
        if bottom >= 132 * fs then
            settingsFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        else
            settingsFrame:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
        end
        settingsFrame:Show()
    end

    -- settings button in the same skinned style as the close button
    local cfg = MakeButton("WTBoxCfgButton", 22, "...", ToggleSettingsPanel)
    cfg:SetHeight(16)
    cfg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -23, -5)
    cfg:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:SetText(L.settings_tooltip)
        GameTooltip:Show()
    end)
    cfg:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function WireFrameScripts()
    -- Keyboard scoping: only a direct click into a text field captures the
    -- keyboard. Clicking the box background or the game world releases it.
    frame:SetScript("OnMouseDown", ClearBoxFocus)
    local origWorldClick = WorldFrame:GetScript("OnMouseDown")
    WorldFrame:SetScript("OnMouseDown", function()
        if origWorldClick then origWorldClick() end
        ClearBoxFocus()
    end)

    -- OnShow/OnHide are registered LAST: they touch widgets built above, so
    -- they must never be able to run against a partially built UI
    frame:SetScript("OnShow", function()
        WTBoxDB.open = true          -- remembered across relogs
        EnsureOnScreen()
        if not manualChannel then SmartSelect() end
        UpdateChannelButtons()
        ApplyImmersive()
    end)
    frame:SetScript("OnHide", function()
        WTBoxDB.open = false
        manualChannel = false
        ApplyImmersive()   -- stops the fade ticker while hidden
    end)

    ApplyAlpha()
    UpdateChannelButtons()
end

local function CreateUI()
    CreateMainUI()
    CreateSettingsUI()
    WireFrameScripts()
end

local function ToggleBox(prefill)
    if not frame then return end
    if frame:IsVisible() and (not prefill or prefill == "") then
        if not WTBoxDB.pinned then
            frame:Hide()
        else
            -- pinned: /wtb still rescues a box stranded off-screen
            EnsureOnScreen()
        end
        return
    end
    -- never auto-grab the keyboard: focus comes only from clicking a field
    frame:Show()
    if prefill and prefill ~= "" then
        inputBox:SetText(prefill)
        DoTranslate()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_WHISPER" then
        lastWhisperFrom = arg2
        AddRecentWhisper(arg2)
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        AddRecentWhisper(arg2)
    elseif event == "VARIABLES_LOADED" then
        local wasOpen = WTBoxDB.open
        ResolveLocale()
        ResolveStyle()
        -- pcall so a build error reports its REAL origin instead of leaving a
        -- half-built UI that throws confusing follow-up errors on every event
        local ok, err = pcall(CreateUI)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4040WTBox failed to build its UI:|r " .. tostring(err))
            if frame then frame:Hide() end
            return
        end
        local n = 0
        if WTBox_MergeGlossaries then n = WTBox_MergeGlossaries() end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccWTBox|r " .. L.loaded ..
            (n > 0 and string.format(L.merged_fmt, n) or "") ..
            " |cff666666(" .. STYLE .. ")|r")
        if WTBoxDB.pinned or wasOpen then
            frame:Show()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- new zone/instance = new context: re-arm smart preselect
        manualChannel = false
        if frame and frame:IsVisible() then
            -- at login OnShow fires before layout, so GetLeft() is nil and the
            -- off-screen check can't run there; by now geometry is real
            EnsureOnScreen()
            SmartSelect()
        end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE"
        or event == "UPDATE_BATTLEFIELD_STATUS" or event == "PLAYER_GUILD_UPDATE" then
        -- these fire in bursts (once per member on raid formation), so the
        -- handler must stay an idempotent repaint - never layout changes
        if frame and frame:IsVisible() then
            if manualChannel then
                UpdateChannelButtons()
            else
                SmartSelect()
            end
        end
    end
end)

-- Keybinding entry points (Bindings.xml). A deliberate keypress is consent
-- to type, so this is the one path that auto-focuses the input.
BINDING_HEADER_WTBOX = "WTBox"
BINDING_NAME_WTBOX_TOGGLE = "Open box + focus input"
function WTBox_Hotkey()
    -- act on key UP only: focusing during key-down would let that key's
    -- character event land in the freshly focused input box
    if keystate ~= "up" then return end
    if not frame then return end
    frame:Show()
    inputBox:SetFocus()
end

SLASH_WTBOX1 = "/wtb"
SLASH_WTBOX2 = "/tbox"
SlashCmdList["WTBOX"] = function(msg)
    if msg == "pin" then
        WTBoxDB.pinned = not WTBoxDB.pinned
        SyncSettingsUI()
        if WTBoxDB.pinned then
            if frame then frame:Show() end
            DEFAULT_CHAT_FRAME:AddMessage("WTBox: pinned - stays open (also across logins). /wtb pin to unpin.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("WTBox: unpinned.")
        end
    elseif msg == "reset" then
        WTBoxDB.posX = nil
        WTBoxDB.posY = nil
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -15, 235)
            frame:Show()
        end
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccWTBox|r commands:")
        for i = 1, table.getn(L.help) do
            DEFAULT_CHAT_FRAME:AddMessage(L.help[i])
        end
    elseif msg == "style modern" or msg == "style classic" or msg == "style pfui" then
        WTBoxDB.style = string.sub(msg, 7)
        SyncSettingsUI()
        DEFAULT_CHAT_FRAME:AddMessage("WTBox: " ..
            string.format(L.style_changed, L.styleNames[CurrentStyleKey()]))
    elseif msg == "lang en" or msg == "lang zh" or msg == "lang auto" then
        local lang = string.sub(msg, 6)
        if lang == "auto" then
            WTBoxDB.uiLang = nil
        else
            WTBoxDB.uiLang = lang
        end
        DEFAULT_CHAT_FRAME:AddMessage("WTBox: " .. string.format(L.lang_set, lang))
    else
        local handled = false
        for num in string.gfind(msg, "^alpha (%d+)$") do
            local a = tonumber(num)
            if a then
                if a > 100 then a = 100 end
                WTBoxDB.alpha = a / 100
                ApplyAlpha()
                SyncSettingsUI()
                DEFAULT_CHAT_FRAME:AddMessage("WTBox: background opacity " .. a .. "%")
            end
            handled = true
        end
        if not handled then
            ToggleBox(msg)
        end
    end
end
