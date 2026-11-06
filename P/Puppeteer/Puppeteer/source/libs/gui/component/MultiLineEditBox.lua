PTGuiMultiLineEditBox = PTGuiComponent:Extend("multi_line_editbox")
PTGuiMultiLineEditBox:Import(true, "SetText", "SetMultiLine", "SetAutoFocus", "SetFocus", "ClearFocus", "HighlightText")
PTGuiMultiLineEditBox:Import(false, "GetText", "IsMultiLine", "IsAutoFocus")
PTGuiMultiLineEditBox:ImportComponent("scroll_frame", true, "Show", "Hide", "ClearAllPoints")

function PTGuiMultiLineEditBox:New()
    local obj = setmetatable({}, self)
    obj:SetHandle(CreateFrame("Editbox", self:GenerateName(), nil))
    obj:GetHandle():SetFontObject(ChatFontNormal)
    obj:SetAutoFocus(false) -- Who actually wants this on by default??
    obj:SetMultiLine(true)
    local scrollFrame = PTGuiScrollFrame:New(obj)
    obj:GetHandle():SetPoint("TOPLEFT", 0, 0)
    obj:AddComponent("scroll_frame", scrollFrame)
    obj:SetPrimary()
    obj:SetScript("OnTextChanged", function()
        -- Stolen from SuperMacro
        local scrollBar = getglobal(this:GetParent():GetName().."ScrollBar")
        this:GetParent():UpdateScrollChildRect()

        local _, max = scrollBar:GetMinMaxValues()
        scrollBar.prevMaxValue = scrollBar.prevMaxValue or max

        if math.abs(scrollBar.prevMaxValue - scrollBar:GetValue()) <= 1 then
            -- if scroll is down and add new line then move scroll
            scrollBar:SetValue(max);
        end
        if max ~= scrollBar.prevMaxValue then
            -- save max value
            scrollBar.prevMaxValue = max
        end
    end, true)
    obj:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end, true)
    return obj
end

function PTGuiMultiLineEditBox:OnDispose()
    self.super.OnDispose(self)

    self:SetText("")
    self:SetAutoFocus(false)
end

function PTGuiMultiLineEditBox:GetScrollFrame()
    return self:GetComponent("scroll_frame")
end

function PTGuiMultiLineEditBox:SetParent(obj)
    self:GetScrollFrame():SetParent(obj)
end

function PTGuiMultiLineEditBox:SetWidth(width)
    self:GetScrollFrame():GetHandle():SetWidth(width)
    return self
end

function PTGuiMultiLineEditBox:SetHeight(height)
    self:GetScrollFrame():GetHandle():SetHeight(height)
    return self
end

function PTGuiMultiLineEditBox:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
    if type(relativeFrame) == "table" and relativeFrame.IsPuppeteerGui then
        relativeFrame = relativeFrame:GetAnchor()
    end
    self:GetScrollFrame():SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
    return self
end

PTGuiLib.RegisterComponent(PTGuiMultiLineEditBox)