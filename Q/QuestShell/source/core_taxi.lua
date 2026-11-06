-- =========================
-- QuestShell — Taxi support (Vanilla/Turtle 1.12)
-- Step types handled:
--   FLIGHTPATH : completes when taxi map opens (or when we open it for you).
--   FLY        : auto-opens taxi, auto-picks destination by name, completes on takeoff.
-- Notes:
--   * 1.12-safe: uses unpack(arg), event var 'event', gossip button scan.
-- =========================

local function dbg(...)
    if QuestShellDBG and QuestShellDBG.log then
        QuestShellDBG.log("taxi", unpack(arg))
    end
end

-- ---- Saved toggle ----
local function EnsureDB()
    QuestShellDB = QuestShellDB or {}
    QuestShellDB.ui = QuestShellDB.ui or {}
    if QuestShellDB.ui.autoFlyPick == nil then QuestShellDB.ui.autoFlyPick = true end
end
EnsureDB()

-- ---- helpers ----
local function _curIndex()
    local st = QS_GuideState and QS_GuideState() or nil
    return (st and st.currentStep) or 1
end

local function _curStep()
    return QS_CurrentStep and QS_CurrentStep() or nil
end

local function _completeCurrent()
    local i = _curIndex()
    if QS_UI_SetStepCompleted then QS_UI_SetStepCompleted(i, true) end
end

local function _norm(s)
    s = tostring(s or "")
    s = string.lower(s)
    s = string.gsub(s, "[^%w]", "")
    return s
end

local function _FindTaxiNodeIndexByName(dest)
    if not dest or dest == "" then return nil end
    local want = _norm(dest)
    local n = (NumTaxiNodes and NumTaxiNodes()) or 0

    local i = 1
    while i <= n do
        local nm = TaxiNodeName and TaxiNodeName(i)
        local typ = TaxiNodeGetType and TaxiNodeGetType(i)
        if nm and typ == "REACHABLE" and _norm(nm) == want then
            return i, nm
        end
        i = i + 1
    end

    i = 1
    while i <= n do
        local nm = TaxiNodeName and TaxiNodeName(i)
        local typ = TaxiNodeGetType and TaxiNodeGetType(i)
        if nm and typ == "REACHABLE" then
            local nn = _norm(nm)
            if string.find(nn, want, 1, true) or string.find(want, nn, 1, true) then
                return i, nm
            end
        end
        i = i + 1
    end
    return nil, nil
end

-- capture picked destination so we can verify
local _QS_Orig_TakeTaxiNode = TakeTaxiNode
local _lastChosenDest = nil

TakeTaxiNode = function(index)
    if TaxiNodeName then
        local name = TaxiNodeName(index)
        if name and name ~= "" then _lastChosenDest = name end
        dbg("TakeTaxiNode ->", name or "?")
    end
    return _QS_Orig_TakeTaxiNode(index)
end

-- ---- event frame + small OnUpdate watcher to detect takeoff ----
local f = CreateFrame("Frame")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("TAXIMAP_OPENED")
f:RegisterEvent("TAXIMAP_CLOSED")
f:RegisterEvent("PLAYER_CONTROL_LOST")   -- sometimes fires on takeoff
f:RegisterEvent("PLAYER_CONTROL_GAINED") -- landing

local _watchRemain = 0  -- seconds to keep polling UnitOnTaxi after closing the map / selecting node

f:SetScript("OnUpdate", function()
    if _watchRemain and _watchRemain > 0 then
        local dt = arg1 or 0
        _watchRemain = _watchRemain - dt
        if UnitOnTaxi and UnitOnTaxi("player") then
            local s = _curStep()
            if s and string.upper(s.type or "") == "FLY" then
                dbg("OnUpdate: detected UnitOnTaxi -> completing FLY")
                _completeCurrent()
            end
            _watchRemain = 0
        elseif _watchRemain <= 0 then
            _watchRemain = 0
        end
    end
end)

f:SetScript("OnEvent", function()
    if event == "GOSSIP_SHOW" then
        -- If the step is FLIGHTPATH/FLY: auto-click the taxi option "I need a ride"
        local s = _curStep()
        local t = s and string.upper(s.type or "") or ""
        if t == "FLIGHTPATH" or t == "FLY" then
            -- (optional) NPC name check, if given
            local okNPC = true
            if s and s.npc and s.npc.name and GossipFrameNpcNameText and GossipFrameNpcNameText.GetText then
                local seen = GossipFrameNpcNameText:GetText() or ""
                okNPC = (string.lower(seen) == string.lower(s.npc.name))
            end
            if okNPC then
                -- scan the prebuilt 1.12 gossip buttons for keywords
                local i = 1
                local clicked = false
                while i <= 32 do
                    local btn = getglobal and getglobal("GossipTitleButton"..i)
                    if not btn or not btn:IsShown() then break end
                    local txt = btn:GetText() or ""
                    local l = string.lower(txt)
                    if string.find(l, "ride", 1, true) or string.find(l, "taxi", 1, true) or string.find(l, "flight", 1, true) or string.find(l, "fly", 1, true) then
                        btn:Click()
                        clicked = true
                        dbg("Clicked taxi gossip:", txt)
                        break
                    end
                    i = i + 1
                end
            end
        end

    elseif event == "TAXIMAP_OPENED" then
        EnsureDB()
        local s = _curStep()
        local t = s and string.upper(s.type or "") or ""

        if t == "FLIGHTPATH" then
            dbg("Completing FLIGHTPATH (taxi opened)")
            _completeCurrent()
            return
        end

        if t == "FLY" and QuestShellDB.ui.autoFlyPick then
            local dest = s.destination or ""
            if dest ~= "" then
                local idx, nm = _FindTaxiNodeIndexByName(dest)
                if idx then
                    dbg("Auto-picking taxi node:", nm)
                    _lastChosenDest = nm
                    TakeTaxiNode(idx)
                    _watchRemain = 10  -- start watcher now; some clients skip PLAYER_CONTROL_LOST
                else
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200QuestShell:|r Taxi destination '"..dest.."' not found or not reachable.")
                    end
                end
            end
        end

    elseif event == "TAXIMAP_CLOSED" then
        -- User may have clicked manually; start a short watcher to detect takeoff.
        _watchRemain = 10

    elseif event == "PLAYER_CONTROL_LOST" then
        -- Many clients fire this right at takeoff; complete FLY step.
        local s = _curStep()
        if s and string.upper(s.type or "") == "FLY" then
            local want = s.destination or ""
            local got  = _lastChosenDest or ""
            if want == "" or (got ~= "" and string.lower(want) == string.lower(got)) then
                dbg("PLAYER_CONTROL_LOST: completing FLY")
                _completeCurrent()
            end
        end

    elseif event == "PLAYER_CONTROL_GAINED" then
        _lastChosenDest = nil
        _watchRemain = 0
    end
end)
