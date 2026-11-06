local frame

SLASH_TRAILBLAZER1 = "/trailblazer"
SLASH_TRAILBLAZER2 = "/tb"

SlashCmdList["TRAILBLAZER"] = function(msg)
    if msg == "fav" then
        if frame and frame:IsShown() then
            frame:Hide()
        else
            if not frame then CreateUIFrame() end
            frame:Show()
        end
    else
        RNDMOUNT()
    end
end

local function tableLength(t)
    if type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function CreateMountList()
    local scrollFrame = CreateFrame("ScrollFrame", "TrailblazerScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(240)
    scrollFrame:SetScrollChild(content)

    local mounts = {
        normal = {},
        aq = {},
    }

    for tab = 1, GetNumSpellTabs() do
        local name, _, offset, numSpells = GetSpellTabInfo(tab)
        if string.find(string.lower(name), "mount") then
            for i = offset + 1, offset + numSpells do
                local spellName = GetSpellName(i, "spell")
                if spellName then
                    if string.find(spellName, "Qiraji") then
                        table.insert(mounts.aq, spellName)
					else
                        table.insert(mounts.normal, spellName)
                    end
                end
            end
            break
        end
    end

    local yOffset = 20
    local function AddCategory(title, mountList)
        if tableLength(mountList) == 0 then return end

        local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        header:SetText(title)
        yOffset = yOffset + 20

        for i, mountName in ipairs(mountList) do
            local cleanTitle = string.gsub(title, "%W", "")
			local check = CreateFrame("CheckButton", "TrailblazerCheck"..cleanTitle..i, content, "UICheckButtonTemplate")

            check:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
            local label = getglobal(check:GetName().."Text")
			label:SetText(mountName)
			label:SetFont("Fonts\\FRIZQT__.TTF", 12)

            check:SetChecked(Trailblazer_Favs and Trailblazer_Favs[mountName] or false)
			
			local nameCopy = mountName
            check:SetScript("OnClick", function()
                if not Trailblazer_Favs then Trailblazer_Favs = {} end
                if this:GetChecked() then
                    Trailblazer_Favs[nameCopy] = true
                else
                    Trailblazer_Favs[nameCopy] = nil
                end
            end)
            yOffset = yOffset + 20
        end
		
		yOffset = yOffset + 20
    end

    AddCategory("Normal", mounts.normal)
    AddCategory("Ahn'qiraj", mounts.aq)


    content:SetHeight(yOffset + 10)
end

function CreateUIFrame()
    frame = CreateFrame("Frame", "TrailblazerUIFrame", UIParent)
    frame:SetWidth(300)
    frame:SetHeight(400)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("Trailblazer")
	title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
	local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
	subtitle:SetText("Choose your favorite mounts:")
	subtitle:SetFont("Fonts\\FRIZQT__.TTF", 14)
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

	CreateMountList()
	
    frame:Hide()
end

function RNDMOUNT()
    local zoneName = GetRealZoneText()
    local isAQ = (zoneName == "Ahn'Qiraj")
    local validMounts = {}

    for tab = 1, GetNumSpellTabs() do
        local name, _, offset, numSpells = GetSpellTabInfo(tab)
        if string.find(string.lower(name), "mount") then
            for i = offset + 1, offset + numSpells do
                local spellName = GetSpellName(i, "spell")
                if spellName then
                    local isAQMount = string.find(spellName, "Qiraji")
                    if (isAQ and isAQMount) or (not isAQ and not isAQMount) then
                        table.insert(validMounts, spellName)
                    end
                end
            end
            break
        end
    end

    local favMounts = {}
    if Trailblazer_Favs then
        for _, mountName in ipairs(validMounts) do
            if Trailblazer_Favs[mountName] then
                table.insert(favMounts, mountName)
            end
        end
    end

    local favCount = tableLength(favMounts)
    local mountList = (favCount > 0) and favMounts or validMounts

    local mountCount = tableLength(mountList)
    if mountCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Trailblazer] No mount found!")
        return
    end

    local index = math.random(1, mountCount)
    local chosenMount = mountList[index]
    CastSpellByName(chosenMount)
end
