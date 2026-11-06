-- =========================
-- QuestShell core_debug.lua
-- Lightweight debug logger + wrappers + event probe (Vanilla/Turtle safe)
-- =========================
QuestShell = QuestShell or {}
if QuestShell.debug == nil then QuestShell.debug = false end

local function _chat(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffcc66ff[QuestShell:DBG]|r "..tostring(msg)) end
end
local function dprint(msg) if QuestShell.debug then _chat(msg) end end

-- describe one step
local function describe(idx)
    local steps = (QS_GuideData and QS_GuideData()) or {}
    local s = steps[idx]
    if not s then return "["..tostring(idx).."] <none>" end
    local el = (not QS_StepIsEligible or QS_StepIsEligible(s)) and "eligible" or "gated"
    return "["..idx.."] "..(s.type or "?").." | "..(s.title or "").." | "..el
end

-- late hook installer
local hooked = false
local function try_hook()
    if hooked then return end
    if QS_AdvanceStep and QS_UI_SetStepCompleted and QuestShellUI_UpdateAll then
        hooked = true
        local orig_adv  = QS_AdvanceStep
        QS_AdvanceStep = function(mark)
            local st = QS_GuideState and QS_GuideState() or {}
            local before = st and st.currentStep or 0
            dprint("QS_AdvanceStep("..tostring(mark)..") BEFORE: "..describe(before))
            local r = orig_adv(mark)
            st = QS_GuideState and QS_GuideState() or {}
            local after  = st and st.currentStep or 0
            dprint("QS_AdvanceStep AFTER:  "..describe(after))
            return r
        end

        local orig_set = QS_UI_SetStepCompleted
        QS_UI_SetStepCompleted = function(i, v)
            dprint("QS_UI_SetStepCompleted("..tostring(i)..","..tostring(v)..")  "..describe(i or 0))
            return orig_set(i, v)
        end

        local orig_upd = QuestShellUI_UpdateAll
        QuestShellUI_UpdateAll = function()
            local st = QS_GuideState and QS_GuideState() or {}
            local cur = st and st.currentStep or 0
            dprint("UI_UpdateAll cur="..tostring(cur).." "..describe(cur))
            return orig_upd()
        end

        dprint("Debug hooks installed.")
    end
end

local hookFrame = CreateFrame("Frame", "QuestShellDebugHooker")
hookFrame:SetScript("OnUpdate", function() try_hook() end)

-- Event probe
local probe = CreateFrame("Frame", "QuestShellDebugProbe")
probe:RegisterEvent("QUEST_DETAIL")
probe:RegisterEvent("QUEST_ACCEPTED")
probe:RegisterEvent("QUEST_LOG_UPDATE")
probe:RegisterEvent("PLAYER_ENTERING_WORLD")
probe:SetScript("OnEvent", function()
    if not QuestShell.debug then return end
    local st = QS_GuideState and QS_GuideState() or {}
    local cur = st and st.currentStep or 0
    if event == "QUEST_DETAIL" then
        local t = (GetTitleText and GetTitleText()) or "<nil>"
        dprint("EV QUEST_DETAIL  title='"..t.."'  cur="..tostring(cur).." "..describe(cur))
    elseif event == "QUEST_ACCEPTED" then
        local t = (arg1 and GetQuestLogTitle and select(1, GetQuestLogTitle(arg1))) or "<nil>"
        dprint("EV QUEST_ACCEPTED idx="..tostring(arg1).." title='"..t.."' cur="..tostring(cur).." "..describe(cur))
    elseif event == "QUEST_LOG_UPDATE" then
        dprint("EV QUEST_LOG_UPDATE cur="..tostring(cur).." "..describe(cur))
    else
        dprint("EV "..tostring(event).." cur="..tostring(cur).." "..describe(cur))
    end
end)
