--[[
PandaQuest / Quest/ServerQuestQuery.lua

Turtle's pfQuest extension asks the server for completed quests by sending
`.queststatus` as GUILD chat and collecting CHAT_MSG_ADDON packets whose prefix
is TWQUEST. The server sends space-separated quest IDs in chunks, with no total
and no final packet. This module keeps the same three-second quiet-period rule,
but assembles and expands the response off to the side before atomically
replacing PandaQuest's saved history.
]]

local PQ = PandaQuest
local Client = PQ.Client
local ServerQuestQuery = PQ:NewModule("ServerQuestQuery")

local JOB = "quest.serverhistory"
local PREFIX = "TWQUEST"
local COMMAND = ".queststatus"
local CHANNEL = "GUILD"
local QUIET_SECONDS = 3
local FIRST_PACKET_TIMEOUT = 12
local TICK_INTERVAL = 0.05
local APPLY_PER_TICK = 80
local FULL_TURN = math.pi * 2

ServerQuestQuery.running = false
ServerQuestQuery.phase = "idle"
ServerQuestQuery.progress = 0
ServerQuestQuery.angle = 0
ServerQuestQuery.statusCallback = nil

local function Notify()
    local callback = ServerQuestQuery.statusCallback
    if type(callback) == "function" then
        pcall(callback)
    end
end

local function StopJob()
    local driver = PQ:GetModule("Driver")
    if driver then
        driver:Unschedule(JOB)
    end
end

local function Fail(reason)
    ServerQuestQuery.running = false
    ServerQuestQuery.phase = "failed"
    ServerQuestQuery.failure = reason
    ServerQuestQuery.progress = 0
    StopJob()
    PQ:Warn(PQ.L(reason))
    Notify()
end

local function AddQueued(questId)
    if type(questId) ~= "number" or questId < 1
        or ServerQuestQuery.queued[questId] then
        return false
    end
    ServerQuestQuery.queued[questId] = true
    table.insert(ServerQuestQuery.queue, questId)
    return true
end

local function AddRelations(relations)
    if type(relations) ~= "table" then
        return
    end
    local index = 1
    local total = table.getn(relations)
    while index <= total do
        AddQueued(relations[index])
        index = index + 1
    end
end

local function Finish()
    local history = PQ:GetModule("QuestHistory")
    if not history then
        Fail("SERVER_QUERY_FAILED_HISTORY")
        return
    end
    local ok, count = history:ReplaceFromServer(ServerQuestQuery.snapshot,
        Client.EpochTime())
    if not ok then
        Fail("SERVER_QUERY_FAILED_SAVE")
        return
    end
    ServerQuestQuery.running = false
    ServerQuestQuery.phase = "done"
    ServerQuestQuery.progress = 100
    ServerQuestQuery.finishedCount = count
    StopJob()
    PQ:Print(PQ.L("SERVER_QUERY_DONE", tostring(count)))
    Notify()
end

local function ProcessApplyBatch()
    local database = PQ:GetModule("Database")
    local processed = 0
    local total = table.getn(ServerQuestQuery.queue)
    while processed < APPLY_PER_TICK and ServerQuestQuery.processIndex <= total do
        local questId = ServerQuestQuery.queue[ServerQuestQuery.processIndex]
        ServerQuestQuery.snapshot[questId] = 1
        local record = database and database:GetQuest(questId)
        if type(record) == "table" then
            AddRelations(record.close)
            AddRelations(record.pre)
        end
        ServerQuestQuery.processIndex = ServerQuestQuery.processIndex + 1
        processed = processed + 1
        total = table.getn(ServerQuestQuery.queue)
    end
    if ServerQuestQuery.processIndex > total then
        Finish()
        return
    end
    local completed = ServerQuestQuery.processIndex - 1
    local progress = 75 + math.floor(completed / total * 24)
    if progress > ServerQuestQuery.progress then
        ServerQuestQuery.progress = progress
    end
end

local function BeginApply()
    ServerQuestQuery.phase = "applying"
    ServerQuestQuery.snapshot = {}
    ServerQuestQuery.processIndex = 1
    if ServerQuestQuery.progress < 75 then
        ServerQuestQuery.progress = 75
    end
end

function ServerQuestQuery:Tick()
    if not self.running then
        StopJob()
        return
    end
    local now = Client.Now()
    if type(now) ~= "number" then
        Fail("SERVER_QUERY_FAILED_CLOCK")
        return
    end
    self.angle = math.mod((now - self.startedAt) / 1.2 * FULL_TURN, FULL_TURN)
    if self.phase == "waiting" then
        local elapsed = now - self.startedAt
        if elapsed >= FIRST_PACKET_TIMEOUT then
            Fail("SERVER_QUERY_FAILED_NO_REPLY")
            return
        end
        local progress = 5 + math.floor(elapsed / FIRST_PACKET_TIMEOUT * 15)
        if progress > self.progress then self.progress = progress end
    elseif self.phase == "receiving" then
        local quiet = now - self.lastPacketAt
        if quiet >= QUIET_SECONDS then
            BeginApply()
        else
            local progress = 25 + math.floor(quiet / QUIET_SECONDS * 49)
            if progress > self.progress then self.progress = progress end
        end
    elseif self.phase == "applying" then
        ProcessApplyBatch()
    end
    Notify()
end

function ServerQuestQuery:OnAddonMessage(prefix, message)
    if not self.running or (self.phase ~= "waiting" and self.phase ~= "receiving")
        or prefix ~= PREFIX then
        return
    end
    self.phase = "receiving"
    self.packets = self.packets + 1
    self.lastPacketAt = Client.Now() or self.startedAt
    if type(message) == "string" then
        local value
        for value in string.gfind(message, "(%d+)") do
            local questId = tonumber(value)
            if AddQueued(questId) then
                self.receivedCount = self.receivedCount + 1
            end
        end
    end
    local floor = 20 + self.packets * 2
    if floor > 55 then floor = 55 end
    if floor > self.progress then self.progress = floor end
    Notify()
end

function ServerQuestQuery:Start()
    if self.running then
        return false
    end
    if self.eventAccepted == false then
        Fail("SERVER_QUERY_FAILED_EVENT")
        return false
    end
    local now = Client.Now()
    if type(now) ~= "number" then
        Fail("SERVER_QUERY_FAILED_CLOCK")
        return false
    end
    self.running = true
    self.phase = "waiting"
    self.failure = nil
    self.progress = 5
    self.angle = 0
    self.startedAt = now
    self.lastPacketAt = nil
    self.packets = 0
    self.receivedCount = 0
    self.finishedCount = nil
    self.queue = {}
    self.queued = {}
    self.snapshot = nil
    self.processIndex = nil
    if not Client.SendChatMessage(COMMAND, CHANNEL) then
        Fail("SERVER_QUERY_FAILED_SEND")
        return false
    end
    local driver = PQ:GetModule("Driver")
    if not driver or not driver:Schedule(JOB, TICK_INTERVAL,
        function() ServerQuestQuery:Tick() end) then
        Fail("SERVER_QUERY_FAILED_DRIVER")
        return false
    end
    PQ:Print(PQ.L("SERVER_QUERY_STARTED"))
    Notify()
    return true
end

local function AgeText(timestamp)
    local now = Client.EpochTime()
    if type(timestamp) ~= "number" or type(now) ~= "number" or now < timestamp then
        return PQ.L("SERVER_QUERY_AGE_UNKNOWN")
    end
    local seconds = now - timestamp
    if seconds < 60 then
        return PQ.L("SERVER_QUERY_AGE_MOMENTS")
    elseif seconds < 3600 then
        return PQ.LN("SERVER_QUERY_AGE_MINUTES", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return PQ.LN("SERVER_QUERY_AGE_HOURS", math.floor(seconds / 3600))
    end
    return PQ.LN("SERVER_QUERY_AGE_DAYS", math.floor(seconds / 86400))
end

function ServerQuestQuery:GetFreshnessText()
    local history = PQ:GetModule("QuestHistory")
    local info = history and history:GetServerSyncInfo()
    if not info or not info.available then
        return PQ.L("SERVER_QUERY_NEVER")
    end
    local age = AgeText(info.queriedAt)
    if info.matches then
        return PQ.L("SERVER_QUERY_UP_TO_DATE", age, tostring(info.count))
    end
    return PQ.L("SERVER_QUERY_OUTDATED", age, tostring(info.currentCount),
        tostring(info.count))
end

function ServerQuestQuery:GetDetailText()
    if self.phase == "waiting" then
        return PQ.L("SERVER_QUERY_STATUS_WAITING")
    elseif self.phase == "receiving" then
        return PQ.L("SERVER_QUERY_STATUS_RECEIVING", tostring(self.packets),
            tostring(self.receivedCount))
    elseif self.phase == "applying" then
        return PQ.L("SERVER_QUERY_STATUS_APPLYING",
            tostring((self.processIndex or 1) - 1), tostring(table.getn(self.queue)))
    elseif self.phase == "done" then
        return PQ.L("SERVER_QUERY_STATUS_DONE", tostring(self.finishedCount or 0))
    elseif self.phase == "failed" then
        return PQ.L(self.failure or "SERVER_QUERY_FAILED_NO_REPLY")
    end
    return PQ.L("SERVER_QUERY_STATUS_READY")
end

function ServerQuestQuery:GetButtonText()
    if self.running then
        return PQ.L("SERVER_QUERY_BUTTON_BUSY")
    end
    return PQ.L("SERVER_QUERY_BUTTON")
end

function ServerQuestQuery:SetStatusCallback(callback)
    self.statusCallback = type(callback) == "function" and callback or nil
    Notify()
end

function ServerQuestQuery:OnEnable()
    local events = PQ:GetModule("Events")
    if events then
        self.eventAccepted = events:Register("CHAT_MSG_ADDON",
            function(event, prefix, message)
                ServerQuestQuery:OnAddonMessage(prefix, message)
            end)
    else
        self.eventAccepted = false
    end
end

