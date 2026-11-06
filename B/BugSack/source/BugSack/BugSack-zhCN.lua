-- zhCN translation by Thomas Mo

local L = AceLibrary("AceLocale-2.2"):new("BugSack")

L:RegisterTranslations("zhCN", function()
   return {
      -- Bindings
      ["Show Current Error"] = "显示当前错误",
      ["Show Session Errors"] = "显示本次会话错误",

      -- Command descriptions
      ["Show sack"] = "显示错误袋",
      ["Show errors in the sack."] = "显示错误袋中的错误。",
      ["Current error"] = "当前错误",
      ["Show the current error."] = "显示当前错误。",
      ["Current session"] = "当前会话",
      ["Show errors from the current session."] = "显示当前会话中的错误。",
      ["Previous session"] = "上一次会话",
      ["Show errors from the previous session."] = "显示上一次会话中的错误。",
      ["By session number"] = "按会话编号",
      ["Show errors by session number."] = "按会话编号显示错误。",
      ["All errors"] = "所有错误",
      ["Show all errors."] = "显示所有错误。",

      ["List errors"] = "列出错误",
      ["List errors to the chat frame."] = "在聊天窗口列出错误。",
      ["List the current error."] = "列出当前错误。",
      ["List errors from the current session."] = "列出当前会话的错误。",
      ["List errors from the previous session."] = "列出上一次会话的错误。",
      ["List errors by session number."] = "按会话编号列出错误。",
      ["List all errors."] = "列出所有错误。",

      ["Auto popup"] = "自动弹出",
      ["Toggle auto BugSack frame popup."] = "切换是否自动弹出 BugSack 窗体。",
      ["Chatframe output"] = "聊天窗口输出",
      ["Print a warning to the chat frame when an error occurs."] = "发生错误时在聊天窗口提示警告。",
      ["Errors to chatframe"] = "将错误输出到聊天窗口",
      ["Print the full error message to the chat frame instead of just a warning."] = "在聊天窗口显示完整错误信息，而不仅是警告。",
      ["Mute"] = "静音",
      ["Toggle an audible warning everytime an error occurs."] = "切换错误发生时是否播放提示音。",
      ["Save errors"] = "保存错误",
      ["Toggle whether to save errors to your SavedVariables\\!BugGrabber.lua file."] = "切换是否将错误保存到 SavedVariables\\!BugGrabber.lua。",
      ["Limit"] = "限制",
      ["Set the limit on the nr of errors saved."] = "设置保存错误数量上限。",

      ["Generate bug"] = "生成错误",
      ["Generate a fake bug for testing."] = "生成一个用于测试的假错误。",
      ["Script bug"] = "脚本错误",
      ["Generate a script bug."] = "生成一个脚本错误。",
      ["Addon bug"] = "插件错误",
      ["Generate an addon bug."] = "生成一个插件错误。",

      ["Clear errors"] = "清除错误",
      ["Clear out the errors database."] = "清空错误数据库。",

      -- Chat messages
      ["You have no errors, yay!"] = "你没有任何错误，耶！",
      ["List of errors:"] = "错误列表：",
      ["An error has been generated."] = "已生成一个错误。",
      ["BugSack generated this fake error."] = "BugSack 生成了这个假错误。",
      ["All errors were wiped."] = "所有错误已清除。",
      ["An error has been recorded."] = "已记录一个错误。",
      ["%d errors have been recorded."] = "已记录 %d 个错误。",

      -- Frame messages,
      [" (... more ...)"] = "（... 更多 ...）",
      ["No errors found"] = "未发现错误",
      ["Error %d of %d"] = "第 %d/%d 个错误",
      [" (viewing last error)"] = "（查看最后一个错误）",
      [" (viewing session errors)"] = "（查看本次会话错误）",
      [" (viewing previous session errors)"] = "（查看上一次会话错误）",
      [" (viewing all errors)"] = "（查看所有错误）",
      [" (viewing errors for session %d)"] = "（查看第 %d 次会话的错误）",

      -- FuBar plugin
      ["Click to open the BugSack frame with the last error."] = "点击打开 BugSack 窗体并显示最后一个错误。",
   }
end)

if GetLocale() == "zhCN" then
	BugSackNextButton:SetText("下一页")
	BugSackLastButton:SetText("最后")
	BugSackPrevButton:SetText("上一页")
	BugSackFirstButton:SetText("第一页")
end
