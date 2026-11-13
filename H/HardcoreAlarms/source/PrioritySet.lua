HardcoreAlarmsPrioritySet = {}

function HardcoreAlarmsPrioritySet:SetPrint(callback)
    if callback == nil then
        self.print = nil
    else
        self.print = callback
    end
end

-- Safe call helper for listener
function HardcoreAlarmsPrioritySet:Print(msg)
    if type(self.print) ~= "function" then return end
    pcall(self.print, msg)
end

function HardcoreAlarmsPrioritySet:New()
    local obj = { values = {} }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function HardcoreAlarmsPrioritySet:Add(value, questId)
    if type(value) == "number" then
        --HardcoreAlarmsPrioritySet:Print("State added: " .. value)
        local before = self.values[value]
        if questId then
            self.values[value] = questId
        else
            self.values[value] = true
        end
        local after = self.values[value]
        if before ~= after then
            self:SafeCallListener()
        end
    end
end

function HardcoreAlarmsPrioritySet:Remove(value)
    if self.values[value] then
        self.values[value] = nil
        self:SafeCallListener()
    end
end

function HardcoreAlarmsPrioritySet:RemoveAll()
    self.values = {}
    self:SafeCallListener()
end

-- New: return array of active states sorted highest-first
function HardcoreAlarmsPrioritySet:GetAllActiveStates()
    local list = {}
    for state, id in pairs(self.values) do
        table.insert(list, { state = state, id = id })
    end
    table.sort(list, function(a, b) return a.state > b.state end) -- highest priority first
    return list
end

-- Helper to check membership quickly
function HardcoreAlarmsPrioritySet:Contains(value)
    return self.values[value] ~= nil
end

-- Register a listener: function(self, newHighestPriority, newHighestId)
function HardcoreAlarmsPrioritySet:SetOnChanged(callback)
    if callback == nil then
        self.onChanged = nil
    else
        self.onChanged = callback
    end
end

-- Safe call helper for listener
function HardcoreAlarmsPrioritySet:SafeCallListener()
    if type(self.onChanged) ~= "function" then return end
    pcall(self.onChanged, self)
end

function HardcoreAlarmsPrioritySet:PrintAll()
    for key in pairs(self.values) do
        print(key)
    end
end
