-- =========================
-- QuestShell core_commands.lua
-- Slash commands (/qs, /questshell)
-- Vanilla/Turtle 1.12 (Lua 5.0) safe
-- =========================

-- Utilities -------------------------------------------------
local function S(s) return string.lower(s or "") end
local function P(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[QuestShell]|r "..tostring(msg)) end end
local function W(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[QuestShell]|r "..tostring(msg)) end end
local function N(v,def) v=tonumber(v); if v==nil then return def end return v end

local function EnsureUI()
    QS_EnsureDB()
    if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
end

-- (Tracker doesn’t expose a Toggle API; use the frame if present)
local function ToggleTracker()
    EnsureUI()
    local f = (getglobal and getglobal("QuestShellTracker")) or QuestShellTracker
    if not f then
        if QuestShellUI and QuestShellUI.Update then QuestShellUI.Update() end
        f = (getglobal and getglobal("QuestShellTracker")) or QuestShellTracker
    end
    if not f then W("Tracker frame not available.") return end
    if f:IsShown() then f:Hide() else f:Show() end
end

local function SetLocked(flag)
    QS_EnsureDB()
    QuestShellDB.ui.locked = (flag and true or false)
    P(flag and "Frames locked." or "Frames unlocked (drag with header).")
end

local function SetArrowEnabled(flag)
    QS_EnsureDB(); QuestShellDB.ui = QuestShellDB.ui or {}
    QuestShellDB.ui.arrowEnabled = (flag and true or false)
    if not flag and QuestShellUI and QuestShellUI.ArrowClear then QuestShellUI.ArrowClear() end
    if flag and QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
    P("Arrow "..(flag and "enabled" or "disabled")..".")
end

local function FontSet(scale)
    if not scale then W("Usage: /qs font <0.6-1.8> or /qs font +0.1") return end
    if string.sub(scale,1,1)=="+" or string.sub(scale,1,1)=="-" then
        local delta = tonumber(scale)
        local cur = (QuestShellDB and QuestShellDB.ui and QuestShellDB.ui.trackerFontScale) or 1.3
        scale = cur + (delta or 0)
    else
        scale = tonumber(scale)
    end
    if not scale then return end
    if scale < 0.6 then scale = 0.6 end
    if scale > 1.8 then scale = 1.8 end
    if QuestShellUI and QuestShellUI.SetFontScale then
        QuestShellUI.SetFontScale(scale)
        P("Font scale set to "..string.format("%.2f", scale))
    end
end

local function ListGuides()
    local names = {}
    local k
    for k,_ in pairs(QuestShellGuides or {}) do names[table.getn(names)+1] = k end
    table.sort(names, function(a,b)
        local A = QuestShellGuides[a]; local B = QuestShellGuides[b]
        local amin = (A and A.minLevel) or 0; local bmin = (B and B.minLevel) or 0
        if amin ~= bmin then return amin < bmin end
        local amax = (A and A.maxLevel) or 0; local bmax = (B and B.maxLevel) or 0
        if amax ~= bmax then return amax < bmax end
        return a < b
    end)
    if table.getn(names) == 0 then P("No guides found.") return end
    P("Guides:")
    local i = 1
    while names[i] do
        local g = QuestShellGuides[names[i]]
        local title = (g and g.title) or names[i]
        local lv = ""
        if g and (g.minLevel or g.maxLevel) then
            lv = " ("..tostring(g.minLevel or "?").."-"..tostring(g.maxLevel or "?")..")"
        end
        P(" - "..title..lv.."  |cffaaaaaa("..names[i]..")|r")
        i = i + 1
    end
end

local function Help()
    P("Commands:")
    P("  /qs lock            - Lock frames (no dragging)")
    P("  /qs unlock          - Unlock frames (drag headers)")
    P("  /qs menu            - Toggle guide menu")
    P("  /qs steps           - Toggle steps list")
    P("  /qs tracker         - Toggle tracker")
    P("  /qs arrow on|off    - Enable/disable arrow")
    P("  /qs font <n>|+d     - Set font scale (0.6-1.8) or relative (e.g. +0.1)")
    P("  /qs next            - Advance to next step")
    P("  /qs prev            - Go to previous step")
    P("  /qs step <n>        - Jump to step n")
    P("  /qs chap next|prev  - Change chapter")
    P("  /qs chap <n>        - Go to chapter n")
    P("  /qs load <key>      - Load guide by key (see /qs list)")
    P("  /qs list            - List guides")
    P("  /qs where           - Show current guide/chapter/step")
    P("  /qs help            - Show this help")
end

-- Step helpers ---------------------------------------------
local function StepNext()
    if QS_AdvanceStep then QS_AdvanceStep() else W("Advance not available.") end
end

local function StepPrev()
    local st = QS_GuideState and QS_GuideState() or nil
    local steps = QS_GuideData and QS_GuideData() or {}
    if not st or not steps then return end
    local n = table.getn(steps)
    local i = (st.currentStep or 1) - 1
    if i < 1 then i = 1 end
    st.currentStep = i
    if QuestShellUI_UpdateAll then QuestShellUI_UpdateAll() end
end

local function StepJump(n)
    n = N(n, nil); if not n then W("Usage: /qs step <number>") return end
    if QuestShell and QuestShell.JumpToStep then QuestShell.JumpToStep(n) end
end

local function ChapterNext()
    if not QuestShell or not QuestShell.SetChapter then return end
    local cur = QS_CurrentChapterIndex and QS_CurrentChapterIndex() or 1
    local total = QS_ChapterCount and QS_ChapterCount() or 1
    if cur < total then QuestShell.SetChapter(cur+1) else P("Already at last chapter.") end
end

local function ChapterPrev()
    if not QuestShell or not QuestShell.SetChapter then return end
    local cur = QS_CurrentChapterIndex and QS_CurrentChapterIndex() or 1
    if cur > 1 then QuestShell.SetChapter(cur-1) else P("Already at first chapter.") end
end

local function ChapterGoto(n)
    n = N(n, nil); if not n then W("Usage: /qs chap <number>") return end
    if QuestShell and QuestShell.SetChapter then QuestShell.SetChapter(n) end
end

local function LoadGuide(key)
    if not key or key == "" then W("Usage: /qs load <guideKey>. Use /qs list to see keys.") return end
    if QuestShell and QuestShell.LoadGuide then QuestShell.LoadGuide(key) end
end

local function WhereAmI()
    local g = QS_GuideMeta and QS_GuideMeta() or {}
    local ch = QS_CurrentChapterIndex and QS_CurrentChapterIndex() or 1
    local s  = QS_GuideState and QS_GuideState() or {}
    local stepIdx = s and s.currentStep or 1
    local step = QS_CurrentStep and QS_CurrentStep() or nil
    local t = (step and (step.type or "")).." "..(step and (step.title or "") or "")
    P("Guide: "..(g.title or "?").."  Chapter: "..tostring(ch).."  Step: "..tostring(stepIdx))
    if step and step.note then P("  "..step.note) end
end

-- Parser ----------------------------------------------------
local function RunCommand(msg)
    EnsureUI()
    local a,b,c,d,e = string.gfind(msg or "", "(%S+)%s*(%S*)%s*(%S*)%s*(%S*)%s*(.*)")()
    local cmd = S(a)

    if cmd == "" or cmd == "help" or cmd == "?" then Help(); return end

    if cmd == "lock"   then SetLocked(true);  return end
    if cmd == "unlock" then SetLocked(false); return end

    if cmd == "menu"   then if QuestShellUI and QuestShellUI.ToggleMenu then QuestShellUI.ToggleMenu() end; return end
    if cmd == "steps"  then if QuestShellUI and QuestShellUI.ToggleList then QuestShellUI.ToggleList() end; return end
    if cmd == "tracker" then ToggleTracker(); return end

    if cmd == "arrow" then
        local v = S(b)
        if v == "on" then SetArrowEnabled(true)
        elseif v == "off" then SetArrowEnabled(false)
        else
            QS_EnsureDB()
            local cur = (QuestShellDB and QuestShellDB.ui and QuestShellDB.ui.arrowEnabled) == true
            SetArrowEnabled(not cur)
        end
        return
    end

    if cmd == "font" then FontSet(b); return end

    if cmd == "next" then StepNext(); return end
    if cmd == "prev" then StepPrev(); return end
    if cmd == "step" then StepJump(b); return end

    if cmd == "chap" or cmd == "chapter" then
        local sub = S(b)
        if sub == "next" then ChapterNext()
        elseif sub == "prev" then ChapterPrev()
        else ChapterGoto(b) end
        return
    end

    if cmd == "load" then LoadGuide(b); return end
    if cmd == "list" then ListGuides(); return end
    if cmd == "where" then WhereAmI(); return end

    Help()
end

-- Register --------------------------------------------------
SlashCmdList = SlashCmdList or {}
SLASH_QUESTSHELL1 = "/qs"
SLASH_QUESTSHELL2 = "/questshell"
SlashCmdList["QUESTSHELL"] = RunCommand

-- Friendly boot message
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    P("Type |cffffff00/qs help|r for commands.")
end)