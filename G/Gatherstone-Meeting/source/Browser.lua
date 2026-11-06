-- 添加屏蔽关键词状态 by 武藤纯子酱 2025.12.30
Meeting.blockWords = MEETING_DB.blockWords or {}
Meeting.blockDropdownState = {}  -- 屏蔽词下拉窗口状态
-- 在文件开头添加多选状态变量和下拉窗口状态 by 武藤纯子酱 2025.9.22
Meeting.multiSelect = {}
Meeting.searchInfo.codes = {}  -- 改为存储多个代码
Meeting.dropdownState = {}     -- 下拉窗口状态
-- 添加搜索文本状态 by 武藤纯子酱 2025.9.24
Meeting.searchInfo.text = ""   -- 搜索文本
Meeting.searchInfo.isComposing = false  -- 是否正在输入中文
Meeting.searchInfo.lastSearchText = ""  -- 上次搜索的文本
Meeting.searchInfo.timer = nil  -- 延迟搜索的计时器
local Menu = AceLibrary("Dewdrop-2.0")
local function CreateSyncTip()
    local tip = Meeting.GUI.CreateFrame({
        parent = Meeting.BrowserFrame,
        width = 200,
        height = 24,
        anchor = {
            point = "BOTTOMLEFT",
            relative = Meeting.BrowserFrame,
            relativePoint = "BOTTOMLEFT",
            x = 0,
            y = 4
        }
    })
    tip.text = Meeting.GUI.CreateText({
        parent = tip,
        text = "Syncing data...",
        fontSize = 10,
        width = 200,
        anchor = {
            point = "TOPLEFT",
            relative = tip,
            relativePoint = "TOPLEFT",
        }
    })
    tip:Show()
    local i = 0
    C_Timer.NewTicker(1, function()
        i = i + 1
        tip.text:SetText("Syncing data..." .. (math.mod(i, 2) == 0 and "" or "..."))
        if i >= 60 then
            tip:Hide()
            return
        end
    end, 60)
end
local browserFrame = Meeting.GUI.CreateFrame({
    parent = Meeting.MainFrame,
    width = 782,
    height = 390,
    anchor = {
        point = "TOPLEFT",
        relative = Meeting.MainFrame,
        relativePoint = "TOPLEFT",
        x = 18,
        y = -34
    }
})
browserFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
browserFrame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        CreateSyncTip()
    end
end)
Meeting.BrowserFrame = browserFrame
browserFrame:EnableMouse(true)
browserFrame:EnableMouseWheel(true)
local activityTypeTextFrame = Meeting.GUI.CreateText({
    parent = browserFrame,
    text = "Activity:",
    fontSize = 16,
    anchor = {
        point = "TOPLEFT",
        relative = browserFrame,
        relativePoint = "TOPLEFT",
        y = -18
    }
})
Meeting.searchInfo.category = ""
Meeting.searchInfo.code = ""
local matchs = {}
-- 修改 SetMathcKeyWords 函数支持跨类别多选 by 武藤纯子酱 2025.9.22
function SetMathcKeyWords()
    matchs = {}
    local nomatchs = {}  -- 存储排除关键词
    
    -- 添加任务链接匹配条件
    if Meeting.searchInfo.code == "QuestLink" then
        table.insert(matchs, "|Hquest:")
        return matchs, nomatchs
    end
    
    -- 处理多选情况 - 支持跨类别选择
    if next(Meeting.searchInfo.codes) then
        -- 遍历所有选中的活动代码
        for activityKey, isSelected in pairs(Meeting.searchInfo.codes) do
            if isSelected then
                -- 在所有类别中查找匹配的活动
                for _, category in ipairs(Meeting.Categories) do
                    for _, activity in ipairs(category.children) do
                        if activity.key == activityKey then
                            -- 添加匹配关键词
                            if activity.match then
                                for _, match in ipairs(activity.match) do
                                    table.insert(matchs, match)
                                end
                            end
                            
                            -- 添加排除关键词
                            if activity.nomatch then
                                for _, nomatch in ipairs(activity.nomatch) do
                                    table.insert(nomatchs, nomatch)
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    elseif Meeting.searchInfo.code ~= "" then
        -- 单个选择的情况
        local info = Meeting.GetActivityInfo(Meeting.searchInfo.code)
        if info.match then
            for _, v in ipairs(info.match) do
                table.insert(matchs, v)
            end
        end
        if info.nomatch then
            for _, v in ipairs(info.nomatch) do
                table.insert(nomatchs, v)
            end
        end
    end
    
    return matchs, nomatchs
end
-- 修改菜单选项创建逻辑，添加全部选项 by 武藤纯子酱 2025.9.22
local options = {
    type = 'group',
    args = {
        ALL = {
            order = 1,
            type = "toggle",
            name = "All",
            desc = "All",
            get = function() 
                return Meeting.searchInfo.category == "" and Meeting.searchInfo.code == "" and not next(Meeting.searchInfo.codes)
            end,
            set = function()
                Meeting.searchInfo.category = ""
                Meeting.searchInfo.code = ""
                Meeting.searchInfo.codes = {}
                Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
                if searchInput then
                    searchInput:SetText("")  -- 清空搜索框
                end
                SetMathcKeyWords()
                Menu:Close()
                MeetingBworserSelectButton:SetText("Select Activity")
                Meeting.BrowserFrame:UpdateList(true)
            end,
        },
        -- 添加确认按钮
        CONFIRM_SELECTION = {
            order = 8,
            type = "execute",
            name = "Confirm Selection",
            desc = "Confirm selected dungeons",
            func = function()
                -- 获取选中的数量
                local count = 0
                for _ in pairs(Meeting.searchInfo.codes) do
                    count = count + 1
                end
                
                if count > 0 then
                    MeetingBworserSelectButton:SetText("Selected " .. count)
                    SetMathcKeyWords()
                    Meeting.BrowserFrame:UpdateList(true)
                    Menu:Close()
                    Meeting.dropdownState.isOpen = false
                    
                    -- 显示确认提示
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Confirmed selection of " .. count .. " dungeons")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Please select dungeons to filter")
                end
            end,
        },
        -- 添加清空按钮
        CLEAR_SELECTION = {
            order = 9,
            type = "execute",
            name = "Clear Selection",
            desc = "Clear all selected dungeons",
            func = function()
                Meeting.searchInfo.codes = {}
                Meeting.searchInfo.code = ""
                Meeting.searchInfo.category = ""
                Meeting.searchInfo.text = ""
                
                if searchInput then
                    searchInput:SetText("")  -- 清空搜索框
                end
                
                SetMathcKeyWords()
                MeetingBworserSelectButton:SetText("Select Activity")
                Meeting.BrowserFrame:UpdateList(true)
                Menu:Close()
                Meeting.dropdownState.isOpen = false
                
                -- 显示清空提示
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Cleared all dungeon selections")
            end,
        },
    },
}
-- 创建所有活动的扁平化列表，支持跨类别多选
local allActivities = {}
-- 首先收集所有活动
for i, category in ipairs(Meeting.Categories) do
    if not category.hide then
        -- 创建局部变量保存当前类别的引用，避免闭包问题
        local currentCategory = category
        
        -- 为每个类别添加"全部"选项
        options.args[category.key] = {
            order = i + 1,
            type = 'group',
            name = category.name,
            desc = category.name,
            args = {
                -- 添加类别级别的"全部"选项
                ["ALL_" .. category.key] = {
                    order = 1,
                    type = "toggle",
                    name = "All",
                    desc = "Select all activities in " .. category.name,
                    get = function()
                        -- 检查该类别下所有子选项是否都被选中
                        local allSelected = true
                        local anySelected = false
                        
                        -- 使用局部变量 currentCategory 而不是 category
                        if not currentCategory or not currentCategory.children then 
                            return false 
                        end
                        
                        for j, activity in ipairs(currentCategory.children) do
                            if Meeting.searchInfo.codes[activity.key] then
                                anySelected = true
                            else
                                allSelected = false
                            end
                        end
                        
                        -- 如果全部选中返回true，如果有选中但不是全部返回nil（显示为混合状态）
                        if allSelected and anySelected then
                            return true
                        elseif not anySelected then
                            return false
                        else
                            return nil  -- 混合状态
                        end
                    end,
					set = function(checked)
						local shouldSelect = true
						
						-- 检查当前是否已经全部选中
						local allCurrentlySelected = true
						for j, activity in ipairs(currentCategory.children) do
							if not Meeting.searchInfo.codes[activity.key] then
								allCurrentlySelected = false
								break
							end
						end
						
						-- 如果已经全部选中，则取消选中所有
						if allCurrentlySelected then
							shouldSelect = false
						end
						
						-- 设置该类别下所有活动的选中状态
						for j, activity in ipairs(currentCategory.children) do
							if shouldSelect then
								Meeting.searchInfo.codes[activity.key] = true
							else
								Meeting.searchInfo.codes[activity.key] = nil
							end
						end
						
						-- 更新多选模式状态
						if next(Meeting.searchInfo.codes) then
							Meeting.searchInfo.code = "MULTI"
							Meeting.searchInfo.category = ""
						else
							Meeting.searchInfo.code = ""
							Meeting.searchInfo.category = ""
						end
						
						Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
						if searchInput then
							searchInput:SetText("")  -- 清空搜索框
						end
						
						SetMathcKeyWords()
						Meeting.BrowserFrame:UpdateList(true)
						
						-- 更新按钮文本显示选中的数量
						local count = 0
						for _ in pairs(Meeting.searchInfo.codes) do
							count = count + 1
						end
						
						if count > 0 then
							MeetingBworserSelectButton:SetText("Selected " .. count)
						else
							MeetingBworserSelectButton:SetText("Select Activity")
						end
					end,
                    isNotRadio = true,  -- 允许混合状态显示
                }
            }
        }
        
        -- 添加类别下的具体活动
        for j, activity in ipairs(category.children) do
            local activityKey = activity.key
            local activityName = activity.name
            
            options.args[category.key].args[activityKey] = {
                order = j + 1,  -- 从2开始，1是"全部"选项
                type = "toggle",
                name = activityName,
                desc = activityName,
                get = function() 
                    return Meeting.searchInfo.codes[activityKey] or false
                end,
				set = function(checked)
					if checked then
						Meeting.searchInfo.codes[activityKey] = true
						Meeting.searchInfo.code = "MULTI"  -- 标记为多选模式
						Meeting.searchInfo.category = ""   -- 清空类别选择
					else
						Meeting.searchInfo.codes[activityKey] = nil
						-- 如果没有选中任何项目，清空多选
						if not next(Meeting.searchInfo.codes) then
							Meeting.searchInfo.code = ""
							Meeting.searchInfo.category = ""
						end
					end
					
					Meeting.searchInfo.text = ""  -- 清空搜索文本 by 武藤纯子酱 2025.9.24
					if searchInput then
						searchInput:SetText("")  -- 清空搜索框
					end
					
					SetMathcKeyWords()
					Meeting.BrowserFrame:UpdateList(true)
					
					-- 更新按钮文本显示选中的数量
					local count = 0
					for _ in pairs(Meeting.searchInfo.codes) do
						count = count + 1
					end
					
					if count > 0 then
						MeetingBworserSelectButton:SetText("Selected " .. count)
					else
						MeetingBworserSelectButton:SetText("Select Activity")
					end
				end,
            }
            
            -- 同时添加到扁平化列表
            allActivities[activityKey] = {
                category = category.key,
                name = activityName,
                order = i * 100 + j
            }
        end
    end
end

-- 修改 selectButton 的点击事件 by 武藤纯子酱 2025.9.22
local selectButton = Meeting.GUI.CreateButton({
    name = "MeetingBworserSelectButton",
    parent = browserFrame,
    text = "Select Activity",
    type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
    width = 140,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = activityTypeTextFrame,
        relativePoint = "TOPRIGHT",
        x = 10,
        y = 4
    },
    click = function()
        if Meeting.dropdownState.isOpen then
            Menu:Close()
            Meeting.dropdownState.isOpen = false
        else
            Menu:Open(this)
            Meeting.dropdownState.isOpen = true
        end
    end
})
-- 添加搜索框 by 武藤纯子酱 2025.9.24
local searchInput = Meeting.GUI.CreateInput({
    parent = browserFrame,
    width = 200,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = selectButton,
        relativePoint = "TOPRIGHT",
        x = 20,
        y = 0
    },
    placeholder = "Search description...",
    limit = 50,
    multiLine = false
})
Meeting.GUI.SetBackground(searchInput, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)

-- 搜索框文本变化事件 - 修复删除字符残留问题
searchInput:SetScript("OnTextChanged", function()
    local text = this:GetText()
    if text then
        text = string.lower(text)
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        
        -- 检测是否包含中文字符（判断是否在输入中文）
        local hasChinese = string.find(text, "[^\1-\127]")
        
        -- 取消之前的延迟搜索计时器
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        if hasChinese then
            -- 如果有中文，可能是拼音输入法正在输入，延迟搜索
            Meeting.searchInfo.isComposing = true
            Meeting.searchInfo.lastSearchText = text
            
            -- 延迟5秒执行搜索，避免拼音干扰
            Meeting.searchInfo.timer = C_Timer.NewTimer(5, function()
                if Meeting.searchInfo.lastSearchText == text then
                    Meeting.searchInfo.text = text
                    Meeting.searchInfo.isComposing = false
                    Meeting.BrowserFrame:UpdateList(true)
                end
            end)
        else
            -- 纯英文、数字、符号，实时搜索
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    else
        -- 文本为空时立即搜索
        Meeting.searchInfo.text = ""
        Meeting.searchInfo.isComposing = false
        
        -- 取消之前的计时器
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        Meeting.BrowserFrame:UpdateList(true)
    end
end)
-- 修改输入法开始合成事件
searchInput:SetScript("OnChar", function(char)
    -- 检测到中文字符输入开始
    if char and string.byte(char) > 127 then
        Meeting.searchInfo.isComposing = true
    else
        -- 英文字符，立即处理
        Meeting.searchInfo.isComposing = false
        
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
    end
end)
-- 修改输入法结束合成事件
searchInput:SetScript("OnEditFocusLost", function()
    -- 取消之前的延迟搜索
    if Meeting.searchInfo.timer then
        Meeting.searchInfo.timer:Cancel()
        Meeting.searchInfo.timer = nil
    end
    
    -- 输入框失去焦点时，强制完成搜索
    if Meeting.searchInfo.isComposing then
        local text = this:GetText()
        if text then
            text = string.lower(text)
            text = string.gsub(text, "^%s*(.-)%s*$", "%1")
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    end
end)
-- 修改回车键确认搜索
searchInput:SetScript("OnEnterPressed", function()
    -- 取消之前的延迟搜索
    if Meeting.searchInfo.timer then
        Meeting.searchInfo.timer:Cancel()
        Meeting.searchInfo.timer = nil
    end
    
    local text = this:GetText()
    if text then
        text = string.lower(text)
        text = string.gsub(text, "^%s*(.-)%s*$", "%1")
        Meeting.searchInfo.text = text
        Meeting.searchInfo.isComposing = false
        Meeting.BrowserFrame:UpdateList(true)
    end
    this:ClearFocus()
end)
-- 修改搜索按钮点击事件
local searchButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Search",
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = searchInput,
        relativePoint = "TOPRIGHT",
        x = 5,
        y = 0
    },
    click = function()
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        local text = searchInput:GetText()
        if text then
            text = string.lower(text)
            text = string.gsub(text, "^%s*(.-)%s*$", "%1")
            Meeting.searchInfo.text = text
            Meeting.searchInfo.isComposing = false
            Meeting.BrowserFrame:UpdateList(true)
        end
    end
})
-- 修改清空搜索按钮
local clearSearchButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Clear",
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = searchButton,
        relativePoint = "TOPRIGHT",
        x = 5,
        y = 0
    },
    click = function()
        -- 取消之前的延迟搜索
        if Meeting.searchInfo.timer then
            Meeting.searchInfo.timer:Cancel()
            Meeting.searchInfo.timer = nil
        end
        
        Meeting.searchInfo.text = ""
        Meeting.searchInfo.isComposing = false
        searchInput:SetText("")
        Meeting.BrowserFrame:UpdateList(true)
    end
})

-- 添加屏蔽关键词按钮 by 武藤纯子酱 2025.12.30
local blockButton = Meeting.GUI.CreateButton({
    name = "MeetingBlockButton",
    parent = browserFrame,
    text = "Block Words",
    type = Meeting.GUI.BUTTON_TYPE.DANGER,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = clearSearchButton,
        relativePoint = "TOPRIGHT",
        x = 20,
        y = 0
    },
    click = function()
        if Meeting.blockDropdownState.isOpen then
            Menu:Close()
            Meeting.blockDropdownState.isOpen = false
        else
            -- 创建屏蔽词菜单
            local blockOptions = {
                type = 'group',
                args = {
                    TITLE = {
                        order = 1,
                        type = "header",
                        name = "Block Words Management",
                    },
                    ADD_BLOCK = {
                        order = 5,
                        type = "execute",  -- 改为execute，然后弹出输入框
                        name = "Add Block Word",
                        desc = "Enter keyword to block",
                        func = function()
                            -- 创建添加屏蔽词的输入对话框
                            local dialog = Meeting.GUI.CreateDialog({
                                parent = Meeting.BrowserFrame,
                                anchor = {
                                    point = "CENTER",
                                    relative = Meeting.BrowserFrame,
                                    relativePoint = "CENTER",
                                    x = 0,
                                    y = 0
                                },
                                title = "Add Block Word",
                                width = 300,
                                height = 100,
                                onCustomFrame = function(parent, anchor)
                                    local frame = Meeting.GUI.CreateFrame({
                                        parent = parent,
                                        width = 280,
                                        height = 40,
                                        anchor = {
                                            point = "TOPLEFT",
                                            relative = anchor,
                                            relativePoint = "BOTTOMLEFT",
                                            x = 0,
                                            y = -10
                                        }
                                    })
                                    
                                    local input = Meeting.GUI.CreateInput({
                                        parent = frame,
                                        width = 280,
                                        height = 20,
                                        anchor = {
                                            point = "TOPLEFT",
                                            relative = frame,
                                            relativePoint = "TOPLEFT",
                                            x = 0,
                                            y = 0
                                        },
                                        limit = 50,
                                        multiLine = false
                                    })
                                    Meeting.GUI.SetBackground(input, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)
                                    input:SetFocus()
                                    
                                    return frame
                                end,
                                _confirm = function()
                                    local input = this:GetParent():GetChildren()
                                    while input and not input.GetText do
                                        input = input:GetChildren()
                                    end
                                    if input and input.GetText then
                                        local value = input:GetText()
                                        if value and value ~= "" then
                                            value = string.trim(value)
                                            local exists = false
                                            for _, word in ipairs(Meeting.blockWords) do
                                                if word == value then
                                                    exists = true
                                                    break
                                                end
                                            end
                                            
                                            if not exists then
                                                table.insert(Meeting.blockWords, value)
                                                MEETING_DB.blockWords = Meeting.blockWords
                                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Added block word: " .. value)
                                                
                                                -- 重新过滤活动列表
                                                Meeting:ReFilterActivities()
                                            else
                                                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Meeting|r: Block word already exists: " .. value)
                                            end
                                        end
                                    end
									Menu:Close()
                                end
                            })
                            dialog:SetPoint("CENTER", Meeting.BrowserFrame, "CENTER", 0, 0)
                        end
                    },
                    CLEAR_ALL = {
                        order = 10,
                        type = "execute",
                        name = "Clear All Block Words",
                        desc = "Clear all set block words",
                        func = function()
                            Meeting.blockWords = {}
                            MEETING_DB.blockWords = Meeting.blockWords
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Cleared all block words")
                            Meeting:ReFilterActivities()
							Menu:Close()
                        end,
                    },
                    RESET = {
                        order = 15,
                        type = "execute",
                        name = "Reset Block Words",
                        desc = "Reset block words to default",
                        func = function()
							MEETING_DB.blockWords = { -- 新增重置默认屏蔽词 by 武藤纯子酱 2025.12.30
								'加速器',
								'淘宝',
								'代充',
								'代练'
							}
							Meeting.blockWords = MEETING_DB.blockWords -- 新增读取配置文件中的屏蔽关键词 by 武藤纯子酱 2025.12.30
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Reset block words")
                            Meeting:ReFilterActivities()
							Menu:Close()
                        end,
                    },
                    SEPARATOR1 = {
                        order = 20,
                        type = "header",
                        name = " ",
                    },
                    LIST_TITLE = {
                        order = 25,
                        type = "header",
                        name = "Current Block Words (" .. table.getn(Meeting.blockWords) .. ")",
                    },
                }
            }
            
            -- 动态添加当前屏蔽词列表
            local order = 50
            for i, word in ipairs(Meeting.blockWords) do
				local blockword = word
                blockOptions.args["BLOCK_" .. i] = {
                    order = order,
                    type = "execute",
                    name = word,
                    desc = "Click to delete",
                    func = function()
						for i, word in ipairs(Meeting.blockWords) do
							if word == blockword then
								table.remove(Meeting.blockWords, i)
								found = true
								break
							end
						end
                        MEETING_DB.blockWords = Meeting.blockWords
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Meeting|r: Deleted block word: " .. blockword)
                        Meeting:ReFilterActivities()
                    end,
                }
                order = order + 1
            end
            
            -- 如果没有屏蔽词，显示提示
            if table.getn(Meeting.blockWords) == 0 then
                blockOptions.args.NO_BLOCKS = {
                    order = 55,
                    type = "header",
                    name = "|cffccccccNo block words|r",
                }
            end
            
            -- 注册并打开菜单
            Menu:Register(this,
                'children', function()
                    Menu:FeedAceOptionsTable(blockOptions)
                end,
                'cursorX', true,
                'cursorY', true,
                'dontHook', true,
                'onClose', function()
                    Meeting.blockDropdownState.isOpen = false
                end
            )
            
            Menu:Open(this)
            Meeting.blockDropdownState.isOpen = true
        end
    end
})

-- 修改菜单注册，添加关闭时的回调 by 武藤纯子酱 2025.9.22
Menu:Register(selectButton,
    'children', function()
        Menu:FeedAceOptionsTable(options)
    end,
    'cursorX', true,
    'cursorY', true,
    'dontHook', true,
    'onClose', function()
        Meeting.dropdownState.isOpen = false
    end
)

local refreshButton = Meeting.GUI.CreateButton({
    parent = browserFrame,
    text = "Refresh",
    type = Meeting.GUI.BUTTON_TYPE.SUCCESS,
    width = 80,
    height = 24,
    anchor = {
        point = "TOPRIGHT",
        relative = browserFrame,
        relativePoint = "TOPRIGHT",
        x = 0,
        y = -18
    },
    click = function()
        Meeting.BrowserFrame:UpdateList(true)
    end
})

local activityListHeaderFrame = Meeting.GUI.CreateFrame({
    parent = browserFrame,
    width = 746,
    height = 44,
    anchor = {
        point = "TOPLEFT",
        relative = browserFrame,
        relativePoint = "TOPLEFT",
        x = 18,
        y = -56
    }
})

local activityTypeText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Activity",
    fontSize = 14,
    width = 135,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = activityListHeaderFrame,
        relativePoint = "TOPLEFT",
    }
})

local modeText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Mode",
    fontSize = 14,
    width = 60,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = activityTypeText,
        relativePoint = "TOPRIGHT",
    }
})

local membersText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Members",
    fontSize = 14,
    width = 80,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = modeText,
        relativePoint = "TOPRIGHT",

    }
})

local leaderText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Leader",
    fontSize = 14,
    width = 100,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = membersText,
        relativePoint = "TOPRIGHT",
    }
})

local commentText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Note",
    fontSize = 14,
    width = 300,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = leaderText,
        relativePoint = "TOPRIGHT",
    }
})

local actionText = Meeting.GUI.CreateText({
    parent = activityListHeaderFrame,
    text = "Action",
    fontSize = 14,
    width = 150,
    height = 24,
    anchor = {
        point = "TOPLEFT",
        relative = commentText,
        relativePoint = "TOPRIGHT",
    }
})

local hoverBackgrop = {
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeSize = 24,
    insets = { left = -1, right = -1, top = -1, bottom = -1 },
}

local function CreateRequestPrompt(config)
    config.width = config.width or 300
    config.height = 185

    if not MEETING_DB.role or MEETING_DB.role == 0 then
        MEETING_DB.role = Meeting.GetClassRole(Meeting.playerClass)
    end

    config.onCustomFrame = function(parent, anchor)
        local frame = Meeting.GUI.CreateFrame({
            parent = parent,
            width = config.width - 20,
            height = 100,
            anchor = {
                point = "TOPLEFT",
                relative = anchor,
                relativePoint = "BOTTOMLEFT",
                x = 0,
                y = -10
            }
        })

        local roleEnable = Meeting.GetClassRole(Meeting.playerClass)

        local function createRole(role, anchor)
            local enable = bit.band(roleEnable, role) == role
            local ckecked = bit.band(MEETING_DB.role, role) == role

            local roleFrame = Meeting.GUI.CreateButton({
                parent = frame,
                width = 40,
                height = 40,
                anchor = anchor,
                disabled = not enable,
                click = function()
                    local ckeck = this.checkButton:GetChecked()
                    if bit.band(MEETING_DB.role, role) == role then
                        MEETING_DB.role = bit.bxor(MEETING_DB.role, role)
                    else
                        MEETING_DB.role = bit.bor(MEETING_DB.role, role)
                    end
                    this.checkButton:SetChecked(not ckeck)
                end
            })

            local tankTexture = roleFrame:CreateTexture()
            local textureName = "damage"
            if role == Meeting.Role.Tank then
                textureName = "tank"
            elseif role == Meeting.Role.Healer then
                textureName = "healer"
            end
            tankTexture:SetTexture("Interface\\AddOns\\Meeting\\assets\\" .. textureName .. ".blp")
            tankTexture:SetWidth(40)
            tankTexture:SetHeight(40)
            tankTexture:SetPoint("TOPLEFT", roleFrame, "TOPLEFT", 0, 0)
            if not enable then
                tankTexture:SetVertexColor(0.2, 0.2, 0.2, 1)
            else
                roleFrame.checkButton = Meeting.GUI.CreateCheck({
                    parent = roleFrame,
                    width = 20,
                    height = 20,
                    anchor = {
                        point = "BOTTOMRIGHT",
                        relative = roleFrame,
                        relativePoint = "BOTTOMRIGHT",
                        x = 0,
                        y = 0
                    },
                    checked = enable and ckecked,
                    click = function(checked)
                        if bit.band(MEETING_DB.role, role) == role then
                            MEETING_DB.role = bit.bxor(MEETING_DB.role, role)
                        else
                            MEETING_DB.role = bit.bor(MEETING_DB.role, role)
                        end
                    end
                })
            end
            return roleFrame
        end

        local tank = createRole(Meeting.Role.Tank, {
            point = "TOPLEFT",
            relative = frame,
            relativePoint = "TOPLEFT",
            x = 70,
            y = 0
        })

        local healer = createRole(Meeting.Role.Healer, {
            point = "TOPLEFT",
            relative = tank,
            relativePoint = "TOPRIGHT",
            x = 10,
            y = 0

        })

        local damage = createRole(Meeting.Role.Damage, {
            point = "TOPLEFT",
            relative = healer,
            relativePoint = "TOPRIGHT",
            x = 10,
            y = 0
        })

        local commentFrame = Meeting.GUI.CreateText({
            parent = frame,
            anchor = {
                point = "TOPLEFT",
                relative = tank,
                relativePoint = "BOTTOMLEFT",
                x = -70,
                y = -5
            },
            text = "Note",
        })

        local input = Meeting.GUI.CreateInput({
            parent = frame,
            width = config.width - 20,
            height = 20,
            anchor = {
                point = "TOPLEFT",
                relative = commentFrame,
                relativePoint = "BOTTOMLEFT",
                x = 0,
                y = -10
            },
            limit = 128,
            multiLine = false
        })
        Meeting.GUI.SetBackground(input, Meeting.GUI.Theme.Black, Meeting.GUI.Theme.White)

        config._confirm = function()
            local text = input:GetText()
            text = string.gsub(text, ":", "：")
            config.confirm(text, MEETING_DB.role)
        end

        return frame
    end

    return Meeting.GUI.CreateDialog(config)
end

local activityListFrame = Meeting.GUI.CreateListFrame({
    name = "MeetingActivityListFrame",
    parent = browserFrame,
    width = 746,
    height = 240,
    anchor = {
        point = "TOPLEFT",
        relative = activityListHeaderFrame,
        relativePoint = "BOTTOMLEFT",
        x = 0,
        y = 0
    },
    step = 24,
    display = 10,
    cell = function(f)
        f.OnHover = function(this, isHover)
            if isHover then
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT", 40)
                GameTooltip:SetText(this.name, 1, 1, 1, 1)
                local classColor = this.activity.classColor
                GameTooltip:AddLine(this.leader, classColor.r, classColor.g, classColor.b, 1)

                if this.level ~= nil and this.level > 0 then
                    local color = GetDifficultyColor(this.level)
                    GameTooltip:AddLine(
                        format('%s |cff%02x%02x%02x%s|r', LEVEL, color.r * 255, color.g * 255, color.b * 255,
                            this.level), 1, 1, 1)
                end

                if this.comment ~= "_" then
                    GameTooltip:AddLine(this.comment, 0.75, 0.75, 0.75, 1)
                end

                local classMap = this.activity:GetClassMap()
                if classMap then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("-- 成员 --", 0.75, 0.75, 0.75, 1)
                    for k, v in pairs(classMap) do
                        local clsname = Meeting.GetClassLocaleName(k)
                        GameTooltip:AddLine(clsname .. " " .. v .. "个", 1, 1, 1, 1)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("<双击>悄悄话", 1, 1, 1, 1)
                GameTooltip:SetWidth(220)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
        f:SetScript("OnDoubleClick", function()
            if this.leader == Meeting.player then
                return
            end
            ChatFrame_OpenChat("/w " .. this.leader, SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME)
        end)

        f.nameFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 135,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f,
                relativePoint = "TOPLEFT",
                x = 0,
                y = -6
            }
        })

        f.hcFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 60,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.nameFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.membersFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            width = 80,
            height = 24,
            fontSize = 14,
            anchor = {
                point = "TOPLEFT",
                relative = f.hcFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.leaderFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 100,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.membersFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.commentFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            width = 300,
            height = 24,
            anchor = {
                point = "TOPLEFT",
                relative = f.leaderFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.statusFrame = Meeting.GUI.CreateText({
            parent = f,
            text = "",
            fontSize = 14,
            color = { r = 0, g = 1, b = 0 },
            anchor = {
                point = "TOPLEFT",
                relative = f.commentFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 0
            }
        })

        f.requestButton = Meeting.GUI.CreateButton({
            parent = f,
            text = "Apply",
            width = 60,
            height = 18,
            type = Meeting.GUI.BUTTON_TYPE.PRIMARY,
            anchor = {
                point = "TOPLEFT",
                relative = f.commentFrame,
                relativePoint = "TOPRIGHT",
                x = 0,
                y = 2
            },
            click = function()
                if f.isChat then
                    ChatFrame_OpenChat("/w " .. f.leader, SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME)
                else
                    local frame = CreateRequestPrompt({
                        parent = Meeting.BrowserFrame,
                        anchor = {
                            point = "CENTER",
                            relative = Meeting.BrowserFrame,
                            relativePoint = "CENTER",
                            x = 0,
                            y = 0
                        },
                        title = "申请加入" .. f.name,
                        confirm = function(text, role)
                            Meeting.Message.Request(f.id, text, role)
                            local activity = Meeting:FindActivity(f.id)
                            activity.applicantStatus = Meeting.APPLICANT_STATUS.Invited
                            Meeting.BrowserFrame:UpdateActivity(activity)
                            f.requestButton:Disable()
                        end
                    })
                    frame:SetPoint("TOP", Meeting.BrowserFrame, "TOP", 0, -50)
                end
            end
        })
    end
})

local function ReloadCell(frame, activity)
	if not frame then return end
    local info = Meeting.GetActivityInfo(activity.code)
    frame.nameFrame:SetText(info.name)
    frame.hcFrame:SetText(activity.isHC and "HC" or "")
    frame.leaderFrame:SetText(activity.unitname)
    local classColor = activity.classColor
    frame.leaderFrame:SetTextColor(classColor.r, classColor.g, classColor.b)
    local maxMambers = Meeting.GetActivityMaxMembers(activity.code)
    local isChat = activity:IsChat()
    if isChat then
        frame.membersFrame:SetText("-")
    else
        frame.membersFrame:SetText(activity.members .. "/" .. maxMambers)
    end

    frame.commentFrame:SetText(activity.comment ~= "_" and activity.comment or "")

    if activity.unitname == Meeting.player or (Meeting.joinedActivity and Meeting.joinedActivity.unitname == activity.unitname) then
        frame.statusFrame:SetText("Joined")
        frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
            Meeting.GUI.Theme.Green.b)
        frame.statusFrame:Show()
        frame.requestButton:Hide()
    else
        if activity.applicantStatus == Meeting.APPLICANT_STATUS.Invited then
            frame.statusFrame:SetText("Applied")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
                Meeting.GUI.Theme.Green.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        elseif activity.applicantStatus == Meeting.APPLICANT_STATUS.Declined then
            frame.statusFrame:SetText("Declined")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Red.r, Meeting.GUI.Theme.Red.g, Meeting.GUI.Theme.Red.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        elseif activity.applicantStatus == Meeting.APPLICANT_STATUS.Joined then
            frame.statusFrame:SetText("Joined")
            frame.statusFrame:SetTextColor(Meeting.GUI.Theme.Green.r, Meeting.GUI.Theme.Green.g,
                Meeting.GUI.Theme.Green.b)
            frame.statusFrame:Show()
            frame.requestButton:Hide()
        else
            frame.statusFrame:Hide()
            frame.requestButton:Show()
            if isChat then
                frame.requestButton:Enable()
                frame.requestButton:SetText("Whisper")
            elseif activity.members >= maxMambers then
                frame.requestButton:Disable()
                frame.requestButton:SetText("Full")
            else
                frame.requestButton:Enable()
                frame.requestButton:SetText("Apply")
            end
        end
    end

    frame.activity = activity
    frame.id = activity.unitname
    frame.name = info.name
    frame.isChat = isChat
    frame.leader = activity.unitname
    frame.level = activity.level
    frame.comment = activity.comment
end

local activities = {}

function Meeting.BrowserFrame:UpdateList(force, scroll)
    if not Meeting.MainFrame:IsShown() or not Meeting.BrowserFrame:IsShown() then
        return
    end
    if not scroll then
        if not force then
            if Meeting.isHover then
                Meeting.GUI.SetBackground(refreshButton, Meeting.GUI.Theme.Red)
                return
            end
        end
        Meeting.GUI.SetBackground(refreshButton, Meeting.GUI.Theme.Green)
        activities = {}
        
        -- 修改搜索逻辑，移除类别限制
        local function search(activity)
            -- 如果有多选，使用多选逻辑
            if next(Meeting.searchInfo.codes) then
                return Meeting.searchInfo.codes[activity.code] or false
            -- 如果有单个选择
            elseif Meeting.searchInfo.code ~= "" then
                return Meeting.searchInfo.code == activity.code
            -- 如果选择了类别但没有选择具体活动
            elseif Meeting.searchInfo.category ~= "" then
                return Meeting.searchInfo.category == activity.category
            -- 全部显示
            else
                return true
            end
        end
        
        -- 修改匹配逻辑，添加排除检查
        local function match(activity, matchs, nomatchs)
			if not activity or not activity.comment then return false end
		
            local lower = string.lower(activity.comment)
            
			if not lower then return false end
			
            -- 先检查排除关键词
            for _, nomatch in ipairs(nomatchs) do
                if string.find(lower, nomatch) then
                    return false  -- 如果包含排除关键词，不匹配
                end
            end
            
            -- 再检查匹配关键词
            for _, match in ipairs(matchs) do
                if string.find(lower, match) then
                    return true
                end
            end
            
            return false
        end
        
        -- 添加搜索文本过滤函数 by 武藤纯子酱 2025.9.24
        local function textSearch(activity)
            if Meeting.searchInfo.text == "" then
                return true  -- 没有搜索文本，显示所有
            end
            
            -- 在活动说明中搜索
            local commentMatch = activity.comment and 
                                string.find(string.lower(activity.comment), Meeting.searchInfo.text, 1, true)
            
            -- 在队长名字中搜索
            local leaderMatch = activity.unitname and 
                               string.find(string.lower(activity.unitname), Meeting.searchInfo.text, 1, true)
            
            -- 在活动名称中搜索
            local activityInfo = Meeting.GetActivityInfo(activity.code)
            local activityNameMatch = activityInfo and activityInfo.name and
                                     string.find(string.lower(activityInfo.name), Meeting.searchInfo.text, 1, true)
            
            return commentMatch or leaderMatch or activityNameMatch
        end
        
        -- 获取匹配和排除关键词
        local matchs, nomatchs = SetMathcKeyWords()
        
        local function matchActivity(activity)
            return match(activity, matchs, nomatchs)
        end
        
        for _, activity in ipairs(Meeting.activities) do
			-- 添加屏蔽词检查
			local shouldShow = true
			
			-- 检查队长名字中的屏蔽词
			if Meeting.CheckBlockWords(activity.unitname, activity.unitname) then
				shouldShow = false
			end
			
			-- 检查活动说明中的屏蔽词
			if shouldShow and Meeting.CheckBlockWords(activity.unitname, activity.comment) then
				shouldShow = false
			end

			if shouldShow then
				if activity:IsChat() then
					-- 聊天活动的特殊处理
					if next(Meeting.searchInfo.codes) or Meeting.searchInfo.code ~= "" then
						if matchActivity(activity) and textSearch(activity) then  -- 添加搜索过滤
							table.insert(activities, activity)
						end
					else
						if search(activity) and textSearch(activity) then  -- 添加搜索过滤
							table.insert(activities, activity)
						end
					end
				else
					-- 普通活动的处理
					if search(activity) and textSearch(activity) then  -- 添加搜索过滤
						table.insert(activities, activity)
					end
				end
			end
        end
    end
    activityListFrame:Reload(table.getn(activities), function(frame, index)
        ReloadCell(frame, activities[index])
    end)
    
    -- 更新搜索结果显示 by 武藤纯子酱 2025.9.24
    if Meeting.searchInfo.text ~= "" then
        searchInput:SetText(Meeting.searchInfo.text)
    end
end

activityListFrame.OnScroll = Meeting.BrowserFrame.UpdateList

function Meeting.BrowserFrame:UpdateActivity(activity)
    local index = -1
    for i, value in ipairs(activities) do
        if value.unitname == activity.unitname then
            index = i
            break
        end
    end
    if index == -1 then
        return
    end

    local offset = FauxScrollFrame_GetOffset(activityListFrame) + 1
    if index < offset or index > offset + table.getn(activityListFrame.pool) then
        return
    end

    local frame = activityListFrame.pool[index - offset + 1]
    ReloadCell(frame, activity)
end
