local floatFrame = Meeting.GUI.CreateButton({
    name = "MettingFloatFrame",
    width = 100,
    height = 20,
    text = "Meeting",
    type = Meeting.GUI.BUTTON_TYPE.NORMAL,
    anchor = {
        point = "TOP",
    },
    movable = true,
    click = function()
        Meeting:Toggle()
    end
})
--Meeting.GUI.SetBackground(floatFrame, Meeting.GUI.Theme.Black)
floatFrame:SetFrameStrata("DIALOG")
floatFrame:SetPoint("TOP", 0, -20)
floatFrame:SetNormalTexture(nil)
floatFrame:SetHighlightTexture(nil)
floatFrame:SetPushedTexture(nil)
floatFrame:SetBackdrop(nil)

-- 添加贴图
local icon = floatFrame:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\Meeting\\assets\\LFG.blp")
icon:SetWidth(28)
icon:SetHeight(28)
icon:SetPoint("LEFT", floatFrame, "LEFT", 2, -1)
--设置颜色为淡蓝色
icon:SetVertexColor(0.5, 0.9, 1)

floatFrame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT", 85, -5)
    local activity = Meeting:FindActivity(Meeting.player)
    GameTooltip:SetText((activity and table.getn(activity.applicantList) or 0) .. " applicants", 1, 1, 1, 1)
    GameTooltip:AddLine(table.getn(Meeting.activities) .. " activities", 1, 1, 1, 1)
    GameTooltip:Show()
end)
floatFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

Meeting.FloatFrame = floatFrame
local flashing = false
local flashElapsed = 0
local flashSpeed = 1 -- 闪烁速度（秒）
local lastUpdate = 0

local function StartFlashing()
    if not flashing then
        flashing = true
        lastUpdate = GetTime() -- 初始化
        floatFrame:SetScript("OnUpdate", function(self)
            local now = GetTime()
            local elapsed = now - lastUpdate
            lastUpdate = now
            flashElapsed = flashElapsed + elapsed
            local alpha = 0.5 + 0.5 * math.abs(math.sin(flashElapsed * math.pi / flashSpeed))
            icon:SetAlpha(alpha)
        end)
    end
end

local function StopFlashing()
    if flashing then
        flashing = false
        floatFrame:SetScript("OnUpdate", nil)
        icon:SetAlpha(1)
        flashElapsed = 0
    end
end

function floatFrame.Update()
    if not floatFrame:IsShown() then
        StopFlashing()
        return
    end
    local activity = Meeting.joinedActivity or Meeting:FindActivity(Meeting.player)
    local n = activity and table.getn(activity.applicantList) or 0
    -- 只显示数字，不显示“集合石”
    floatFrame:SetText("   Meeting")
    floatFrame:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    if n > 0 then
        StartFlashing()
    else
        StopFlashing()
    end
end