PTSpellBindInterface = PTGuiComponent:Extend("puppeteer_spell_bind_interface")

function PTSpellBindInterface:New()
    local obj = setmetatable({}, self)
    local frame = CreateFrame("Frame", self:GenerateName())
    obj:SetHandle(frame)

    local buttonLabel = PTGuiLib.Get("text", frame)
        :SetText("Button")
        :SetWidth(65)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 5, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
    local typeLabel = PTGuiLib.Get("text", frame)
        :SetText("Type")
        :SetWidth(40)
        :SetPoint("LEFT", buttonLabel, "RIGHT", 20, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")
    local bindingLabel = PTGuiLib.Get("text", frame)
        :SetText("Binding")
        :SetWidth(210)
        :SetPoint("LEFT", typeLabel, "RIGHT", 20, 0)
        :SetFontSize(14)
        :SetFontFlags("OUTLINE")

    local bindingScrollFrame = PTGuiLib.Get("scroll_frame", frame)
        :SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
        :SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        :SetSimpleBackground()
    obj:AddComponent("ScrollFrame", bindingScrollFrame)
    obj:AddComponent("LeftLabel", buttonLabel)

    obj.Lines = {}
    obj.LineMap = {}

    return obj
end

function PTSpellBindInterface:OnAcquire()
    self.super.OnAcquire(self)
    self:GetScrollFrame():FixNextUpdate()
end

function PTSpellBindInterface:OnDispose()
    self:ClearSpellLines()
    self.super.OnDispose(self)
end

PTSpellBindInterface:CreateGetter("ScrollFrame")
PTSpellBindInterface:CreateGetter("LeftLabel")

function PTSpellBindInterface:SetLeftLabel(text)
    self:GetLeftLabel():SetText(text)
    return self
end

function PTSpellBindInterface:SetBindings(bindings)
    self.Bindings = bindings
    for id, line in pairs(self.LineMap) do
        line:SetBinding(bindings[id])
    end
end

function PTSpellBindInterface:GetSpellLine(id)
    return self.LineMap[id]
end

function PTSpellBindInterface:SwapIndexes(index1, index2)
    self.Lines[index1], self.Lines[index2] = self.Lines[index2], self.Lines[index1]
    self.Bindings[index1], self.Bindings[index2] = self.Bindings[index2], self.Bindings[index1]
    self:UpdateLinePositions()
end

function PTSpellBindInterface:AddSpellLine(id, label)
    local line = PTGuiLib.Get("puppeteer_spell_line", self:GetScrollFrame())
            :SetSize(380, 25)
            :SetLabel(label)
            :SetControlHandler(self)

    table.insert(self.Lines, line)
    if id then
        self.LineMap[id] = line
    end

    self:UpdateLinePositions()
    return line
end

function PTSpellBindInterface:RemoveSpellLineByID(id, noDispose)
    local line = self.LineMap[id]
    self.LineMap[id] = nil
    PTUtil.RemoveElement(self.Lines, line)
    if not noDispose then
        line:Dispose()
    end

    self:UpdateLinePositions()
end

function PTSpellBindInterface:RemoveSpellLine(line)
    for id, l in pairs(self.LineMap) do
        if line == l then
            self.LineMap[id] = nil
        end
    end
    PTUtil.RemoveElement(self.Lines, line)
    line:Dispose()

    self:UpdateLinePositions()
end

function PTSpellBindInterface:ClearSpellLines()
    for _, line in ipairs(self.Lines) do
        line:Dispose()
    end
    PTUtil.ClearTable(self.Lines)
    PTUtil.ClearTable(self.LineMap)
end

function PTSpellBindInterface:UpdateLinePositions()
    local INTERVAL = 26
    for i, line in ipairs(self.Lines) do
        line:SetPoint("TOPLEFT", self:GetScrollFrame(), "TOPLEFT", 5, -5 - (INTERVAL * (i - 1)))
    end
    self:GetScrollFrame():UpdateScrollChildRect()
end

-- Control handler functions

function PTSpellBindInterface:OnLineDelete(line)
    local index = PTUtil.IndexOf(self.Lines, line)
    self:RemoveSpellLine(line)
    table.remove(self.Bindings, index)
end

function PTSpellBindInterface:OnLineUp(line)
    local index = PTUtil.IndexOf(self.Lines, line)
    if IsShiftKeyDown() then
        for i = index, 2, -1 do
            self:SwapIndexes(i, i - 1)
        end
    elseif index > 1 and table.getn(self.Lines) > 1 then
        self:SwapIndexes(index, index - 1)
    end
end

function PTSpellBindInterface:OnLineDown(line)
    local index = PTUtil.IndexOf(self.Lines, line)
    local lineCount = table.getn(self.Lines)
    if IsShiftKeyDown() then
        for i = index, lineCount - 1 do
            self:SwapIndexes(i, i + 1)
        end
    elseif index < table.getn(self.Lines) then
        self:SwapIndexes(index, index + 1)
    end
end

-- End of control handler functions

PTGuiLib.RegisterComponent(PTSpellBindInterface)