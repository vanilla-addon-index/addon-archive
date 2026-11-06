-- ==========================================================
-- TITLES PROJECT: DATA & TABLES
-- ==========================================================
local FROG_LIST = { ["Azure Frog"]=1, ["Bullfrog"]=1, ["Dart Frog"]=1, ["Dream Frog"]=1, ["Golden Frog"]=1, ["Infinite Frog"]=1, ["Island Frog"]=1, ["Poison Frog"]=1, ["Pond Frog"]=1, ["Snow Frog"]=1, ["Tree Frog"]=1, ["Wood Frog"]=1, ["Jubling"]=1 }
local CAT_LIST = { ["Bombay"]=1, ["Black Tabby"]=1, ["Cornish Rex"]=1, ["Orange Tabby"]=1, ["Siamese"]=1, ["White Kitten"]=1, ["Mr. Bigglesworth"]=1, ["Midnight"]=1, ["Corrupted Kitten"]=1, ["White Tiger Cub"]=1, ["Silver Tabby"]=1 }
local SPIDER_LIST = { ["Araxxna's Hatchling"]=1, ["Cavernweb Hatchling"]=1, ["Maexxna's Hatchling"]=1, ["Razzashi Hatchling"]=1, ["Skitterweb Hatchling"]=1, ["Black Widow Hatchling"]=1, ["Darkmist Hatchling"]=1, ["Lava Hatchling"]=1, ["Mistbark Hatchling"]=1, ["Night Web Hatchling"]=1, ["Smolderweb Hatchling"]=1, ["Tarantula Hatchling"]=1, ["Timberweb Hatchling"]=1, ["Webwood Hatchling"]=1, ["Wildthorn Hatchling"]=1 }

-- SMART FILTER: Determines if a spell is likely a pet
local function IsProbablyAPet(id)
    local name = GetSpellName(id, BOOKTYPE_SPELL)
    if not name then return false end
    if FROG_LIST[name] or CAT_LIST[name] or SPIDER_LIST[name] then return true end
    for i = 1, GetNumSpellTabs() do
        local tabName, _, offset, num = GetSpellTabInfo(i)
        if tabName and (string.find(tabName, "Companion") or string.find(tabName, "Pet")) then
            if id > offset and id <= (offset + num) then return true end
        end
    end
    return false
end

-- Helper to find which tab a specific Spell ID belongs to
local function GetTabForSpellID(targetID)
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, num = GetSpellTabInfo(i)
        if targetID > offset and targetID <= (offset + num) then return i, offset end
    end
    return nil, 0
end

local function GetOwnedPets()
    local owned = {}
    for i = 1, 500 do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        owned[name] = true
    end
    return owned
end

local function TriggerPFQuestSearch(petName)
    if SlashCmdList["PFDB"] then SlashCmdList["PFDB"](petName)
    elseif pfQuest and pfQuest.gui then pfQuest.gui.Search:SetText(petName) pfQuest.gui:Show() end
end

-- ==========================================================
-- TITLES INTERFACE
-- ==========================================================
local TitlesFrame = CreateFrame("Frame", "TurtleTitlesFrame", UIParent)
TitlesFrame:SetWidth(300) TitlesFrame:SetHeight(280)
TitlesFrame:SetPoint("CENTER", UIParent, "CENTER")
TitlesFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
TitlesFrame:SetMovable(true) TitlesFrame:EnableMouse(true)
TitlesFrame:SetScript("OnMouseDown", function() this:StartMoving() end)
TitlesFrame:SetScript("OnMouseUp", function() this:StopMovingOrSizing() end)
TitlesFrame:Hide()

local DetailFrame = CreateFrame("Frame", "TurtleTitlesDetail", TitlesFrame)
DetailFrame:SetWidth(250) DetailFrame:SetHeight(320)
DetailFrame:SetPoint("LEFT", TitlesFrame, "RIGHT", 5, 0)
DetailFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
DetailFrame:Hide()

local detailTitle = DetailFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailTitle:SetPoint("TOP", DetailFrame, "TOP", 0, -10)

local petButtons = {}
local function GetPetButton(index)
    if not petButtons[index] then
        local b = CreateFrame("Button", nil, DetailFrame)
        b:SetWidth(220) b:SetHeight(16)
        b:SetPoint("TOPLEFT", DetailFrame, "TOPLEFT", 15, -25 - (index * 18))
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetAllPoints() b.text:SetJustifyH("LEFT")
        b:SetScript("OnEnter", function() if this.isMissing then this.text:SetTextColor(1, 1, 1) end end)
        b:SetScript("OnLeave", function() if this.isMissing then this.text:SetTextColor(1, 0, 0) end end)
        b:SetScript("OnClick", function() if this.isMissing then TriggerPFQuestSearch(this.petName) end end)
        petButtons[index] = b
    end
    return petButtons[index]
end

local function ShowDetails(titleName, dataList)
    detailTitle:SetText(titleName)
    local owned = GetOwnedPets()
    for _, btn in pairs(petButtons) do btn:Hide() end
    local i = 1
    for petName in pairs(dataList) do
        local btn = GetPetButton(i)
        btn.petName = petName
        if owned[petName] then btn.text:SetText("|cff00ff00[X] " .. petName .. "|r") btn.isMissing = false
        else btn.text:SetText("|cffff0000[ ] " .. petName .. "|r") btn.isMissing = true end
        btn:Show() i = i + 1
    end
    DetailFrame:Show()
end

local function CreatePetBar(name, yOffset, maxVal, color, dataList)
    local row = CreateFrame("Button", nil, TitlesFrame)
    row:SetWidth(260) row:SetHeight(45)
    row:SetPoint("TOPLEFT", TitlesFrame, "TOPLEFT", 20, yOffset)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    label:SetText(name)
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetWidth(250) bar:SetHeight(16)
    bar:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(color.r, color.g, color.b)
    bar:SetMinMaxValues(0, maxVal)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar) bg:SetTexture(0, 0, 0, 0.5)
    local txt = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("CENTER", bar, "CENTER", 0, 0)
    row:SetScript("OnClick", function() ShowDetails(name, dataList) end)
    return bar, txt
end

local barFrog, txtFrog = CreatePetBar("Lord of the Frogs", -50, 13, {r=0.2, g=0.8, b=0.2}, FROG_LIST)
local barCat, txtCat = CreatePetBar("Crazy Cat Lady", -110, 11, {r=1, g=0.5, b=0}, CAT_LIST)
local barSpider, txtSpider = CreatePetBar("Itsy Bitsy Hero", -170, 15, {r=0.6, g=0.3, b=0.8}, SPIDER_LIST)

local function UpdatePetStats()
    local owned = GetOwnedPets()
    local fCount, cCount, sCount = 0, 0, 0
    for name in pairs(owned) do
        if FROG_LIST[name] then fCount = fCount + 1 end
        if CAT_LIST[name] then cCount = cCount + 1 end
        if SPIDER_LIST[name] then sCount = sCount + 1 end
    end
    barFrog:SetValue(fCount) txtFrog:SetText(fCount.." / 13")
    barCat:SetValue(cCount) txtCat:SetText(cCount.." / 11")
    barSpider:SetValue(sCount) txtSpider:SetText(sCount.." / 15")
end

TitlesFrame:SetScript("OnShow", function() UpdatePetStats() end)
TitlesFrame:SetScript("OnHide", function() DetailFrame:Hide() end)
local closeBtn = CreateFrame("Button", nil, TitlesFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", TitlesFrame, "TOPRIGHT", -5, -5)

-- ==========================================================
-- GLOBAL PET SEARCH BAR (BI-DIRECTIONAL NAVIGATION)
-- ==========================================================
local lastSearchText, currentMatchIndex = "", 0
local searchBox = CreateFrame("EditBox", "TurtlePetSearchBox", SpellBookFrame, "InputBoxTemplate")
searchBox:SetWidth(130) searchBox:SetHeight(24)
searchBox:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -55, -45)
searchBox:SetAutoFocus(false)
searchBox:SetText("Search Pet...")

local projectBtn = CreateFrame("Button", "TurtleProjectButton", SpellBookFrame, "UIPanelButtonTemplate")
projectBtn:SetWidth(50) projectBtn:SetHeight(24)
projectBtn:SetPoint("RIGHT", searchBox, "LEFT", -55, 0)
projectBtn:SetText("Titles") 
projectBtn:SetScript("OnClick", function() if TitlesFrame:IsVisible() then TitlesFrame:Hide() else TitlesFrame:Show() end end)

local counterText = searchBox:CreateFontString("TurtlePetCounter", "OVERLAY", "GameFontNormalSmall")
counterText:SetPoint("LEFT", projectBtn, "RIGHT", 2, 0)
counterText:SetPoint("RIGHT", searchBox, "LEFT", -2, 0)
counterText:SetJustifyH("CENTER")
counterText:SetText("")

local highlighter = CreateFrame("Frame", "TurtlePetHighlight", SpellBookFrame)
highlighter:SetWidth(46) highlighter:SetHeight(46)
highlighter:SetFrameStrata("TOOLTIP") highlighter:Hide()
local highlightTex = highlighter:CreateTexture(nil, "OVERLAY")
highlightTex:SetAllPoints(highlighter)
highlightTex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
highlightTex:SetBlendMode("ADD")

local function ResetSearch()
    searchBox:SetText("Search Pet...")
    counterText:SetText("")
    highlighter:Hide()
    lastSearchText, currentMatchIndex = "", 0
end

local clearBtn = CreateFrame("Button", nil, searchBox)
clearBtn:SetWidth(16) clearBtn:SetHeight(16)
clearBtn:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
clearBtn:SetAlpha(0.5)
clearBtn:SetScript("OnClick", function() ResetSearch() searchBox:ClearFocus() end)

searchBox:SetScript("OnEditFocusGained", function() if this:GetText() == "Search Pet..." then this:SetText("") end end)
searchBox:SetScript("OnEditFocusLost", function() if this:GetText() == "" then this:SetText("Search Pet...") end end)

searchBox:SetScript("OnEnterPressed", function()
    local text = string.lower(this:GetText())
    highlighter:Hide()
    if text == "" or text == "search pet..." then counterText:SetText("") return end
    if text ~= lastSearchText then lastSearchText = text currentMatchIndex = 0 end
    
    local matches, count = {}, 0
    for i = 1, 500 do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if IsProbablyAPet(i) and string.find(string.lower(name), text, 1, true) then
            count = count + 1 matches[count] = i
        end
    end

    if count == 0 then counterText:SetText("0") counterText:SetTextColor(1,0,0) return end
    currentMatchIndex = currentMatchIndex + 1
    if currentMatchIndex > count then currentMatchIndex = 1 end
    counterText:SetText(currentMatchIndex.."/"..count) counterText:SetTextColor(1, 0.8, 0)
    
    local targetID = matches[currentMatchIndex]
    local correctTab, tabOffset = GetTabForSpellID(targetID)
    
    if correctTab then
        local tabBtn = getglobal("SpellBookSkillLineTab"..correctTab)
        if tabBtn then tabBtn:Click() end
    end

    -- Bi-Directional Navigator
    local navigator = CreateFrame("Frame")
    navigator.timer, navigator.targetID = 0, targetID
    navigator:SetScript("OnUpdate", function()
        this.timer = this.timer + arg1
        if this.timer > 0.05 then
            this.timer = 0
            local found = false
            for b = 1, 12 do
                local btn = getglobal("SpellButton"..b)
                if btn and btn:IsVisible() then
                    local bID = SpellBook_GetSpellID(btn:GetID())
                    if bID == this.targetID then
                        highlighter:SetPoint("CENTER", btn, "CENTER", 0, 0)
                        highlighter:Show() found = true break
                    end
                end
            end

            if found then 
                this:SetScript("OnUpdate", nil) 
            else
                -- Determine if we need to flip forward or backward
                local currentFirstID = SpellBook_GetSpellID(getglobal("SpellButton1"):GetID())
                if currentFirstID > this.targetID then
                    local prevBtn = getglobal("SpellBookPrevPageButton")
                    if prevBtn and prevBtn:IsEnabled() == 1 then prevBtn:Click() else this:SetScript("OnUpdate", nil) end
                else
                    local nextBtn = getglobal("SpellBookNextPageButton")
                    if nextBtn and nextBtn:IsEnabled() == 1 then nextBtn:Click() else this:SetScript("OnUpdate", nil) end
                end
            end
        end
    end)
end)

searchBox:SetScript("OnEscapePressed", function() ResetSearch() this:ClearFocus() end)

local originalUpdate = SpellBookFrame_Update
SpellBookFrame_Update = function()
    if highlighter then highlighter:Hide() end
    if originalUpdate then originalUpdate() end
end