local Message = {}

Meeting.Message = Message
Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
local EVENTS = {
    CREATE = "C",
    REQUEST = "R",
    DECLINE = "D",
    MEMBERS = "M",
    CLOSE = "L",
    VERSION = "V",
}

local function CheckBlockWords(playerName, message)
    -- 如果玩家是自己，不屏蔽
    if playerName == Meeting.player then
        return false
    end
    
    -- 检查消息是否为空
    if not message or message == "" or message == "_" then
        return false
    end
    
    -- 检查屏蔽词列表是否存在
    if not Meeting.blockWords or table.getn(Meeting.blockWords) == 0 then
        return false
    end
    
    -- 转换为小写进行不区分大小写的匹配
    local lowerMessage = string.lower(message)
    
    -- 检查每个屏蔽词
    for _, word in ipairs(Meeting.blockWords) do
        if word and word ~= "" then
            local lowerWord = string.lower(word)
            if string.find(lowerMessage, lowerWord) then
                return true
            end
        end
    end
    
    return false
end

Meeting.CheckBlockWords = CheckBlockWords

function Message.OnRecv(playerName, data)
    local _, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7 = string.meetingsplit(data, ":")
    if event == EVENTS.CREATE then
        -- 检查活动说明中的屏蔽词
        if CheckBlockWords(playerName, arg2) then
            return
        end
        -- 检查队长名字中的屏蔽词
        if CheckBlockWords(playerName, playerName) then
            return
        end
        Meeting:OnCreate(playerName, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
    elseif event == EVENTS.REQUEST then
        Meeting:OnRequest(playerName, arg1, arg2, arg3, arg4, arg5, arg6)
    elseif event == EVENTS.DECLINE then
        Meeting:OnDecline(playerName, arg1)
    elseif event == EVENTS.MEMBERS then
        Meeting:OnMembers(playerName, arg1, arg2)
    elseif event == EVENTS.CLOSE then
        Meeting:OnClose(playerName)
    elseif event == EVENTS.VERSION then
        Meeting:OnVersion(arg1)
    end
end

local matchText = {}
for _, category in ipairs(Meeting.Categories) do
    for _, value in ipairs(category.children) do
        if value.match then
            for _, match in ipairs(value.match) do
                table.insert(matchText, match)
            end
        end
    end
end

local distinct = {}
for _, v in ipairs(matchText) do
    if not distinct[v] then
        distinct[v] = true
    end
end
matchText = {}
for k, _ in pairs(distinct) do
    table.insert(matchText, k)
end
distinct = nil

function Message.OnRecvFormChat(channel, playerName, message)
    -- 新增任务链接检测逻辑
	if string.find(message, "|Hquest:") then
		-- 安全解析任务链接：确保括号配对
		local questStart = string.find(message, "|Hquest:")
		if questStart then
			-- 查找对应的"]"
			local bracketStart = string.find(message, "%[", questStart)
			if bracketStart then
				local bracketEnd = string.find(message, "%]", bracketStart)
				if bracketEnd then
					-- 继续查找"|h"结束位置，确保格式完整
					local pipeHStart = string.find(message, "|h", bracketEnd)
					if pipeHStart then
						-- 截取完整的任务链接部分（从questStart开始）
						local linkPart = string.sub(message, questStart)
						-- 查找链接结束位置
						local linkEnd = string.find(linkPart, "|h")
						if linkEnd then
							linkPart = string.sub(linkPart, 1, linkEnd + 1) -- 包含|h
							
							-- 现在我们可以安全解析
							-- 注意：魔兽世界1.12的任务链接格式是：|Hquest:id:level|h[name]|h
							local _, _, questID, questLevel, questName = string.find(
								linkPart, 
								"|Hquest:(%d+):(%d+)|h%[([^%]]*)%]|h"
							)
							
							-- 如果解析成功
							if questID and questLevel and questName then
								-- 自动创建任务追踪活动
								Meeting:OnCreate(playerName, "QuestLink", 
									questName,                    -- 任务名字
									questLevel,                   -- 任务等级
									"0",                          -- 职业占位
									"0",                          -- 人数占位
									"0",                          -- 硬核模式
									questID                       -- 使用任务ID作为分类标识
								)
								return
							end
						end
					end
				end
			end
		end
	end

    local activity = Meeting:FindActivity(playerName)
    if activity and not activity:IsChat() then
        return
    end
    if string.find(message, "求组") or string.find(message, "lfg") or string.find(message, "lfm") then
        return
    end
    if CheckBlockWords(playerName, message) then
        return
    end
    -- 修改匹配逻辑，添加多选状态检查和排除检查
    local lowerMessage = string.lower(message)
    
    -- 获取当前的多选状态和排除关键词
    local matchs, nomatchs = SetMathcKeyWords()
    
    -- 如果没有选择任何活动类型，或者选择了"全部"，则匹配所有
    local shouldMatchAll = Meeting.searchInfo.category == "" or 
                          (Meeting.searchInfo.category ~= "" and Meeting.searchInfo.code == "" and not next(Meeting.searchInfo.codes))
    
    -- 先检查排除关键词
    for _, nomatch in ipairs(nomatchs) do
        if string.find(lowerMessage, nomatch) then
            return  -- 如果包含排除关键词，不创建活动
        end
    end
    
    -- 如果选择了"全部"或者没有选择任何过滤条件，使用原来的匹配逻辑
    if shouldMatchAll then
        for _, v in ipairs(matchText) do
            if string.find(lowerMessage, v) then
                Meeting:OnCreate(playerName, string.upper(channel), message, "0", "0", "0",
                    channel == "hardcore" and "1" or "0")
                return
            end
        end
    else
        -- 多选状态下的匹配逻辑
        for _, match in ipairs(matchs) do
            if string.find(lowerMessage, match) then
                Meeting:OnCreate(playerName, string.upper(channel), message, "0", "0", "0",
                    channel == "hardcore" and "1" or "0")
                return
            end
        end
    end
end

function Message.Send(event, msg)
    local channel = GetChannelName(Meeting.channel)
    if channel ~= 0 then
        SendChatMessage("Meeting:" .. event .. ":" .. msg, "CHANNEL", nil, channel)
    else
        print("Please join " .. Meeting.channel .. " channel")
    end
end

function Message.CreateActivity(code, comment)
    local data = string.format("%s:%s:%d:%d:%d:%d:%s", code,
        string.isempty(comment) and "_" or comment, UnitLevel("player"),
        Meeting.ClassToNumber(Meeting.playerClass),
        table.getn(Meeting.members) + 1, Meeting.playerIsHC and 1 or 0, Meeting.EncodeGroupClass())
    MEETING_DB.activity = {
        code = code,
        comment = comment,
        lastTime = time()
    }
    Message.InvokeSyncActivityTimer()
    Message.Send(EVENTS.CREATE, data)
end

function Message.Request(id, comment, role)
    local data = string.format("%s:%d:%d:%d:%s:%d", id, UnitLevel("player"),
        Meeting.ClassToNumber(Meeting.playerClass), Meeting.GetPlayerScore(), string.isempty(comment) and "_" or comment,
        role)
    Message.Send(EVENTS.REQUEST, data)
end

function Message.Decline(name)
    Message.Send(EVENTS.DECLINE, string.format("%s", name))
end

function Message.SyncMembers(members)
    Message.Send(EVENTS.MEMBERS, string.format("%d:%s", members, Meeting.EncodeGroupClass()))
end

function Message.CloseActivity(leave)
    Message.Send(EVENTS.CLOSE, "")
    if not leave then
        MEETING_DB.activity = nil
    end
end

function Message.SendVersion()
    Message.Send(EVENTS.VERSION, Meeting.VERSION.MAJOR .. "." .. Meeting.VERSION.MINOR .. "." .. Meeting.VERSION.PATCH)
end

local syncTimer = nil

function Message.InvokeSyncActivityTimer()
    if syncTimer then
        syncTimer:Cancel()
    end

    syncTimer = C_Timer.NewTicker(60, function()
        if Meeting.isAFK then
            return
        end
        local activity = Meeting:FindActivity(Meeting.player)
        if activity then
            Message.CreateActivity(activity.code, activity.comment)
        end
    end, -1)
end
