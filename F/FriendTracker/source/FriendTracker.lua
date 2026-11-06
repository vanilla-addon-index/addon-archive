-- FriendTracker for Vanilla 1.12.1 (Lua 5.0)

-- Tabela de cores de classe do Vanilla 1.12.1
local CLASS_COLORS = {
    ["WARRIOR"] = "cffc79c6e",
    ["PALADIN"] = "cfff58cba",
    ["HUNTER"]  = "cffabd473",
    ["ROGUE"]   = "cfffff569",
    ["PRIEST"]  = "cffffffff",
    ["SHAMAN"]  = "cff0070de",
    ["MAGE"]    = "cff69ccf0",
    ["WARLOCK"] = "cff9482c9",
    ["DRUID"]   = "cffff7d0a"
}

-- Main Frame
local frame = CreateFrame("Frame", "FriendTrackerMainFrame", UIParent)
frame:SetWidth(300)
frame:SetHeight(380)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetMinResize(180, 120)
frame:SetMaxResize(600, 800)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

-- Guardar tamanho e posição da janela
local function SavePositionAndSize()
    if not FriendTrackerDB then FriendTrackerDB = {} end
    FriendTrackerDB.width = frame:GetWidth()
    FriendTrackerDB.height = frame:GetHeight()
    
    local cX, cY = frame:GetCenter()
    local uX, uY = UIParent:GetCenter()
    if cX and cY and uX and uY then
        FriendTrackerDB.x = cX - uX
        FriendTrackerDB.y = cY - uY
    end
end

-- Arrastar janela
frame:SetScript("OnDragStart", function()
    if not (FriendTrackerDB and FriendTrackerDB.locked) then
        this:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    SavePositionAndSize()
end)

-- Estilo pfUI (Fundo escuro semi-translúcido com borda fina)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
frame:SetBackdropColor(0, 0, 0, 0.75)
frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

-- Botão fechar estilo pfUI (Borda preta pura)
local closeBtn = CreateFrame("Button", nil, frame)
closeBtn:SetWidth(16)
closeBtn:SetHeight(16)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
closeBtn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
closeBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
closeBtn:SetBackdropBorderColor(0, 0, 0, 1)

local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 1)
closeText:SetText("x")
closeText:SetTextColor(0.8, 0.2, 0.2, 1)

closeBtn:SetScript("OnClick", function()
    this:GetParent():Hide()
end)
closeBtn:SetScript("OnEnter", function()
    this:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
end)
closeBtn:SetScript("OnLeave", function()
    this:SetBackdropBorderColor(0, 0, 0, 1)
end)

-- Invisible Catcher Frame para fechar o menu ao clicar fora (Padrão pfUI)
local contextCatcher = CreateFrame("Button", nil, UIParent)
contextCatcher:SetAllPoints(UIParent)
contextCatcher:SetFrameStrata("FULLSCREEN")
contextCatcher:Hide()

-- Menu de Contexto (Whisper e Invite)
local contextMenu = CreateFrame("Frame", "FriendTrackerContextMenu", UIParent)
contextMenu:SetWidth(120)
contextMenu:SetHeight(44)
contextMenu:SetFrameStrata("FULLSCREEN_DIALOG")
contextMenu:Hide()
contextMenu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
contextMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
contextMenu:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

local activeFriendName = nil

local function HideContextMenu()
    contextMenu:Hide()
    contextCatcher:Hide()
end

contextCatcher:SetScript("OnClick", function()
    HideContextMenu()
end)

local function CreateMenuButton(parent, label, yOffset, onClickFunc)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(112)
    btn:SetHeight(18)
    btn:SetPoint("TOP", parent, "TOP", 0, yOffset)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = false, tileSize = 0, edgeSize = 0 })
    btn:SetBackdropColor(0, 0, 0, 0)

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", btn, "LEFT", 8, 0)
    txt:SetText(label)

    btn:SetScript("OnEnter", function()
        this:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    end)
    btn:SetScript("OnLeave", function()
        this:SetBackdropColor(0, 0, 0, 0)
    end)
    btn:SetScript("OnClick", function()
        onClickFunc()
        HideContextMenu()
    end)
    return btn
end

CreateMenuButton(contextMenu, "Whisper", -4, function()
    if activeFriendName then ChatFrame_OpenChat("/w " .. activeFriendName .. " ") end
end)
CreateMenuButton(contextMenu, "Invite to Party", -23, function()
    if activeFriendName then InviteByName(activeFriendName) end
end)

local function ShowContextMenu(name)
    activeFriendName = name
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    contextMenu:ClearAllPoints()
    contextMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    contextCatcher:Show()
    contextMenu:Show()
end

-- Pega para redimensionar
local resizeBtn = CreateFrame("Button", nil, frame)
resizeBtn:SetWidth(12)
resizeBtn:SetHeight(12)
resizeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeBtn:SetScript("OnMouseDown", function()
    if not (FriendTrackerDB and FriendTrackerDB.locked) then
        this:GetParent():StartSizing("BOTTOMRIGHT")
    end
end)
resizeBtn:SetScript("OnMouseUp", function()
    this:GetParent():StopMovingOrSizing()
    SavePositionAndSize()
end)

local function ApplyLockState()
    if not FriendTrackerDB then return end
    if FriendTrackerDB.locked then
        resizeBtn:Hide()
    else
        resizeBtn:Show()
    end
end

-- Título a dourado
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
title:SetText("Online Friends")
title:SetTextColor(1, 0.82, 0, 1)

-- ScrollFrame sem a barra metálica
local scrollFrame = CreateFrame("ScrollFrame", "FriendTrackerScrollFrame", frame)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -32)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(280)
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

frame:SetScript("OnSizeChanged", function()
    if scrollFrame and content then
        content:SetWidth(scrollFrame:GetWidth())
    end
end)

-- Scroll com roda do rato
local function OnScrollWheel()
    local current = scrollFrame:GetVerticalScroll()
    local maxScroll = scrollFrame:GetVerticalScrollRange()
    local step = 20
    if arg1 > 0 then
        scrollFrame:SetVerticalScroll(math.max(0, current - step))
    elseif arg1 < 0 then
        scrollFrame:SetVerticalScroll(math.min(maxScroll, current + step))
    end
    HideContextMenu()
end

frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", OnScrollWheel)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", OnScrollWheel)

-- Linhas de amigos
local friendRows = {}

local function GetOrCreateRow(index)
    if not friendRows[index] then
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * 18)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        row:EnableMouse(true)

        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        row:SetBackdropColor(0, 0, 0, 0)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", row, "LEFT", 5, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        -- Deteção direta de cliques no rato
        row:SetScript("OnMouseUp", function()
            if not this.friendName then return end
            if arg1 == "LeftButton" then
                HideContextMenu()
                ChatFrame_OpenChat("/w " .. this.friendName .. " ")
            elseif arg1 == "RightButton" then
                ShowContextMenu(this.friendName)
            end
        end)

        row:SetScript("OnEnter", function()
            if this.friendName then
                this:SetBackdropColor(1, 1, 1, 0.08)
            end
        end)
        row:SetScript("OnLeave", function()
            this:SetBackdropColor(0, 0, 0, 0)
        end)

        friendRows[index] = row
    end
    return friendRows[index]
end

-- Atualizar lista de amigos
local function UpdateFriendList()
    if not frame:IsShown() then return end

    ShowFriends()

    local numFriends = GetNumFriends()
    local onlineCount = 0

    for _, row in ipairs(friendRows) do
        row:Hide()
    end

    for i = 1, numFriends do
        local name, level, class, area, connected, status = GetFriendInfo(i)

        if connected then
            onlineCount = onlineCount + 1
            local row = GetOrCreateRow(onlineCount)
            row.friendName = name

            local nameStr = name or "Unknown"
            local areaStr = (area and area ~= "") and area or "Unknown Zone"
            local levelStr = level and ("[" .. level .. "]") or ""

            local classColor = "cffffffff"
            if class then
                local upperClass = string.upper(class)
                if CLASS_COLORS[upperClass] then
                    classColor = CLASS_COLORS[upperClass]
                end
            end

            row.text:SetText(string.format("%s |%s%s|r - |cff00ff00%s|r", levelStr, classColor, nameStr, areaStr))
            row:Show()
        end
    end

    title:SetText(string.format("Online Friends (%d)", onlineCount))

    content:SetHeight(math.max(1, onlineCount * 18))

    if onlineCount == 0 then
        local row = GetOrCreateRow(1)
        row.friendName = nil
        row.text:SetText("|cff808080No friends online.|r")
        row:Show()
    end
end

-- Eventos
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("FRIENDLIST_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "FriendTracker" then
        if not FriendTrackerDB then
            FriendTrackerDB = {
                x = 0,
                y = 0,
                width = 300,
                height = 380,
                locked = false
            }
        end

        if FriendTrackerDB.width and FriendTrackerDB.height then
            frame:SetWidth(FriendTrackerDB.width)
            frame:SetHeight(FriendTrackerDB.height)
        end

        if FriendTrackerDB.x and FriendTrackerDB.y then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", FriendTrackerDB.x, FriendTrackerDB.y)
        end

        ApplyLockState()
    elseif event == "PLAYER_LOGIN" or event == "FRIENDLIST_UPDATE" then
        UpdateFriendList()
    end
end)

frame:SetScript("OnShow", function()
    ShowFriends()
    UpdateFriendList()
end)

frame:SetScript("OnHide", function()
    HideContextMenu()
end)

-- Slash Command (/ofriends)
SLASH_FRIENDTRACKER1 = "/ofriends"
SlashCmdList["FRIENDTRACKER"] = function(msg)
    local cmd = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    if cmd == "lock" then
        FriendTrackerDB.locked = true
        ApplyLockState()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100FriendTracker|r: Window position locked.")
    elseif cmd == "unlock" then
        FriendTrackerDB.locked = false
        ApplyLockState()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100FriendTracker|r: Window position unlocked.")
    elseif cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100FriendTracker Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage(" - |cffffffff/ofriends|r: Toggle window")
        DEFAULT_CHAT_FRAME:AddMessage(" - |cffffffff/ofriends lock|r: Lock position & size")
        DEFAULT_CHAT_FRAME:AddMessage(" - |cffffffff/ofriends unlock|r: Unlock position & size")
    else
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end
end
