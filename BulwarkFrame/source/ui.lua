-- BulwarkFrame - ui.lua
-- The frame: hit-threshold bar, expiry bar, swing line. WoW-API file (parse-checked only).
--
-- Three rules this file follows, all from hard-won ecosystem experience:
--   * every frame gets a name with the addon prefix, so pfDebug's profiler can attribute its
--     cost instead of lumping it under <unnamed>;
--   * nothing is allocated per OnUpdate frame -- no string building, no tables. Text is only
--     pushed when it actually changed, and the loop returns early when there is nothing to draw;
--   * when the buffer is down and we are out of combat the OnUpdate script is detached entirely
--     rather than left spinning -- whether the frame is hidden or merely idle on screen.

BulwarkFrame = BulwarkFrame or {}
local BF = BulwarkFrame
local C = BulwarkFrameCalc
local S = BulwarkFrameSwing

local frame, poolBar, poolText, timeBar, timeText, speedText, swingLine, swingMark, hintText
local demoTag
-- Which widget the swing marker rides on: its own line, or the expiry bar (pfUI mana-tick style).
local swingHost
local lastPoolText, lastTimeText, lastSpeedText = nil, nil, nil
local demo = nil          -- demo mode state, nil when off
local UPDATE_INTERVAL = 0.05
local sinceUpdate = 0

-- Colour-threshold configs, allocated once and refilled in place. Built as table literals inside
-- the update loop they were the only per-tick allocation left in this file: two tables every
-- 50 ms, created purely to be read twice and thrown away. calc.lua reads .red/.yellow and never
-- retains the table, so reusing one instance is safe.
local poolCfg = { red = 0, yellow = 0 }
local timeCfg = { red = 0, yellow = 0 }

-- ---- helpers ----------------------------------------------------------------------------

local function db() return BulwarkFrameDB end

-- Colour lookup that honours the user's configured colours. calc.lua decides WHICH bucket
-- (red/yellow/green); the RGB values come from the saved config, not from calc's constants.
local function bucketRGB(name)
    local d = db()
    local c = (name == "green" and d.colorGreen) or (name == "yellow" and d.colorYellow) or d.colorRed
    if type(c) ~= "table" then return 0.7, 0.7, 0.7 end
    return c[1] or 0.7, c[2] or 0.7, c[3] or 0.7
end

local function applyBackdrop(f, d)
    local bg = d.colorBg or { 0, 0, 0, 0.8 }
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(bg[1] or 0, bg[2] or 0, bg[3] or 0, bg[4] or 0.8)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

local function applyFont(fs, size)
    if not fs then return end
    if pfUI and pfUI.font_default then
        fs:SetFont(pfUI.font_default, size or 10, "OUTLINE")
    else
        fs:SetFont("Fonts\\FRIZQT__.TTF", size or 10, "OUTLINE")
    end
    -- Outline plus a hard shadow: the number sits ON the bar, so half of it is over the fill and
    -- half over the empty track. Either alone leaves one of the two halves muddy.
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

-- ---- construction -----------------------------------------------------------------------

local function BuildFrame()
    if frame then return end
    local d = db()

    frame = CreateFrame("Frame", "BulwarkFrameMain", UIParent)
    frame:SetWidth(d.width)
    frame:SetHeight(60)
    -- The anchor is applied by ApplyLayout (called at the end of this function), so that reset and
    -- the options panel go through the SAME code path a fresh login does. Anchoring here as well
    -- would leave two placement sites and let them disagree.
    frame:SetScale(d.scale)
    frame:SetMovable(true)
    -- Without this the frame can be dragged until only a sliver is left on screen, and the
    -- documented rescue ('/bulwark reset') then has to be able to fetch it back.
    frame:SetClampedToScreen(true)
    frame:EnableMouse(not d.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() if not db().locked then this:StartMoving() end end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local point, _, relPoint, x, y = this:GetPoint()
        local dd = db()
        dd.point, dd.relPoint, dd.x, dd.y = point, relPoint, x, y
    end)

    -- Threshold bar: the primary readout. Fill = how full the buffer is.
    poolBar = CreateFrame("StatusBar", "BulwarkFramePoolBar", frame)
    poolBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    poolBar:SetMinMaxValues(0, 1)
    poolBar:SetValue(0)
    applyBackdrop(poolBar, d)

    poolText = poolBar:CreateFontString("BulwarkFramePoolText", "OVERLAY")
    poolText:SetPoint("CENTER", poolBar, "CENTER", 0, 0)
    applyFont(poolText, 10)

    -- Expiry bar: deliberately flatter than the threshold bar -- it is secondary information.
    timeBar = CreateFrame("StatusBar", "BulwarkFrameTimeBar", frame)
    timeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timeBar:SetMinMaxValues(0, 1)
    timeBar:SetValue(0)
    applyBackdrop(timeBar, d)

    timeText = timeBar:CreateFontString("BulwarkFrameTimeText", "OVERLAY")
    timeText:SetPoint("RIGHT", timeBar, "RIGHT", -3, 0)
    applyFont(timeText, 9)

    -- Current attack speed, on the left of the same bar the swing marker rides. It is the number
    -- the marker's travel time is derived from, so having it visible makes the animation checkable
    -- instead of something you have to trust -- and it shows haste changing live (Flurry drops it
    -- by a fifth, which is exactly what desynced the bar before).
    speedText = timeBar:CreateFontString("BulwarkFrameSpeedText", "OVERLAY")
    speedText:SetPoint("LEFT", timeBar, "LEFT", 3, 0)
    applyFont(speedText, 9)

    -- Swing line: a 1-2 px rule with a moving marker. Subordinate by construction, not by
    -- colour alone -- it must never compete with the threshold for attention.
    swingLine = CreateFrame("Frame", "BulwarkFrameSwingLine", frame)
    local lineTex = swingLine:CreateTexture("BulwarkFrameSwingLineTex", "BACKGROUND")
    lineTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    lineTex:SetVertexColor(0.25, 0.25, 0.28, 0.9)
    lineTex:SetAllPoints(swingLine)

    swingMark = swingLine:CreateTexture("BulwarkFrameSwingMark", "OVERLAY")
    swingMark:SetTexture("Interface\\Buttons\\WHITE8X8")

    -- One-line status, shown only when there is nothing else to show (no SuperWoW, buffer never
    -- seen, aura ids unconfirmed). An empty frame with no explanation reads as "addon broken".
    demoTag = frame:CreateFontString("BulwarkFrameDemoTag", "OVERLAY")
    demoTag:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 1)
    applyFont(demoTag, 9)
    demoTag:SetTextColor(1, 0.5, 0.2)
    demoTag:SetText("DEMO - synthetic values")
    demoTag:Hide()

    hintText = frame:CreateFontString("BulwarkFrameHintText", "OVERLAY")
    hintText:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    applyFont(hintText, 9)
    hintText:SetTextColor(0.7, 0.7, 0.75)
    hintText:Hide()

    BF.ApplyLayout()
end

-- Recomputes every size/position from the config. Called on load and after any options change,
-- so the panel needs no knowledge of the frame internals.
function BF.ApplyLayout()
    if not frame then return end
    local d = db()
    local w = d.width
    local y = 0

    frame:SetWidth(w)
    frame:SetScale(d.scale)
    frame:EnableMouse(not d.locked)
    -- Re-anchor from the saved placement. Without this, '/bulwark reset' (and the panel's Reset
    -- button) put CENTER/0/-120 back into the config while the frame itself stayed wherever it was
    -- dragged -- so the documented way to rescue a frame from the screen edge did nothing until
    -- the next login.
    frame:ClearAllPoints()
    frame:SetPoint(d.point or "CENTER", UIParent, d.relPoint or "CENTER", d.x or 0, d.y or 0)

    if d.showThreshold then
        poolBar:ClearAllPoints()
        poolBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        poolBar:SetWidth(w)
        poolBar:SetHeight(d.barHeight)
        poolBar:Show()
        y = y - d.barHeight - d.spacing
    else
        poolBar:Hide()
    end

    if d.showExpiry then
        timeBar:ClearAllPoints()
        timeBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
        timeBar:SetWidth(w)
        timeBar:SetHeight(d.timeBarHeight)
        timeBar:Show()
        y = y - d.timeBarHeight - d.spacing
    else
        timeBar:Hide()
    end

    -- Two ways to show the swing. Riding the expiry bar is pfUI's mana-tick idiom: no extra row,
    -- and the marker sits where the eye already is. Its own thin line stays available for anyone
    -- who wants the swing readable independently of whether a buffer is up.
    local rideExpiry = d.swingOnExpiryBar and d.showExpiry
    if d.showSwing then
        local sc = d.colorSwing or { 0.9, 0.9, 0.95 }
        swingMark:SetVertexColor(sc[1], sc[2], sc[3])
        swingMark:SetWidth(2)
        if rideExpiry then
            swingLine:Hide()
            swingHost = timeBar
            swingMark:SetParent(timeBar)
            swingMark:SetHeight(d.timeBarHeight)
        else
            swingLine:ClearAllPoints()
            swingLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
            swingLine:SetWidth(w)
            swingLine:SetHeight(d.swingHeight)
            swingLine:Show()
            swingHost = swingLine
            swingMark:SetParent(swingLine)
            swingMark:SetHeight(d.swingHeight + 2)
            y = y - d.swingHeight - d.spacing
        end
    else
        swingLine:Hide()
        swingMark:Hide()
    end

    if poolText then if d.showThresholdText then poolText:Show() else poolText:Hide() end end
    if timeText then if d.showExpiryText then timeText:Show() else timeText:Hide() end end
    if speedText then if d.showSpeedText then speedText:Show() else speedText:Hide() end end

    frame:SetHeight(math.max(8, -y))
    lastPoolText, lastTimeText, lastSpeedText = nil, nil, nil   -- force a text refresh next tick
end

-- ---- update loop ------------------------------------------------------------------------

-- Reads either the live state or the demo generator. Returns stacks, timeLeft, maxHP, active.
local function currentInputs()
    if demo then
        local t = GetTime() - demo.start
        local cycle = math.mod(t, 12)
        local stacks, timeLeft
        if cycle < 8 then
            -- drain the pool over 8 s, expiry ticking down alongside
            stacks = math.floor(100 - (cycle / 8) * 100)
            timeLeft = 8 - cycle
        else
            stacks, timeLeft = 0, 0
        end
        return stacks, timeLeft, demo.maxHP, cycle < 8
    end
    local st = BF.state
    -- Interpolated remaining time: the aura is only re-read when the client fires an aura event,
    -- which is far coarser than the display. Counting down from the last reading makes the bar
    -- glide instead of stepping, and it re-syncs on every event, so it cannot drift.
    local remaining = st.timeLeft
    if remaining and remaining > 0 and st.timeLeftAt and st.timeLeftAt > 0 then
        remaining = remaining - (GetTime() - st.timeLeftAt)
        if remaining < 0 then remaining = 0 end
    end
    return st.stacks, remaining, st.maxHP, st.active
end

local sinceTimeScan = 0

local function updateDisplay()
    local d = db()
    -- Re-read the remaining time on a timer, not only when the client fires an aura event: a
    -- refresh of an aura that is already up does not reliably produce one, and the interpolation
    -- would then keep counting down through a buffer that was reset. Five times a second is far
    -- below what the eye resolves on an 8 second bar and costs one walk of the buff list.
    if not demo then
        sinceTimeScan = sinceTimeScan + UPDATE_INTERVAL
        if sinceTimeScan >= 0.2 then
            sinceTimeScan = 0
            if BF.ScanTime then BF.ScanTime() end
        end
    end
    local stacks, timeLeft, maxHP, active = currentInputs()

    -- Weapon speed is re-read on the throttled tick, NOT only when a swing lands. Reading it once
    -- per swing freezes whatever haste happened to be up at that moment: measured in game with
    -- Flurry rank 5 active the state held 2.24 s while the character had gone back to 2.69 s, so
    -- the marker finished a fifth of a second early and drifted out of sync with the real hits.
    -- This is the "rescales" reading that core/swing.lua deliberately leaves to the caller -- for a
    -- live readout it is the honest one: the bar should describe the swing you are in now.
    if not demo then
        local main = UnitAttackSpeed("player")
        if type(main) == "number" and main > 0 then BF.state.swingSpeed = main end
    end

    if d.showThreshold then
        local frac = C.barFraction(stacks)
        poolBar:SetValue(frac)
        poolCfg.red, poolCfg.yellow = d.poolRed, d.poolYellow
        local r, g, b = bucketRGB(C.poolColorName(frac, poolCfg))
        poolBar:SetStatusBarColor(r, g, b)
        if d.showThresholdText then
            local points = C.poolPoints(stacks, maxHP)
            local maxPoints = C.maxPool(maxHP)
            local txt
            if d.displayMode == "shield" then
                txt = C.fmtShieldPair(points, maxPoints)
            else
                txt = C.fmtThresholdPair(points, maxPoints, BF.currentRate(d))
            end
            if txt ~= lastPoolText then poolText:SetText(txt); lastPoolText = txt end
        end
    end

    if d.showExpiry then
        local tf = C.timeFraction(timeLeft, BF.BUFFER_DURATION)
        timeBar:SetValue(tf)
        timeCfg.red, timeCfg.yellow = d.timeRed, d.timeYellow
        local r, g, b = bucketRGB(C.timeColorName(timeLeft, timeCfg))
        -- Dimmed on purpose: same buckets, lower alpha, so the threshold bar stays the primary
        -- readout instead of two equally loud bars sitting on top of each other.
        timeBar:SetStatusBarColor(r, g, b, d.expiryAlpha or 0.65)
        if d.showExpiryText then
            local txt = C.fmtTime(timeLeft)
            if txt ~= lastTimeText then timeText:SetText(txt); lastTimeText = txt end
        end
        -- Attack speed on the left of the same bar. Only pushed when the string actually changes,
        -- so a steady speed costs nothing per tick.
        if d.showSpeedText then
            local sp = demo and 2.6 or BF.state.swingSpeed
            local txt = (type(sp) == "number" and sp > 0) and (string.format("%.2f", sp)) or ""
            if txt ~= lastSpeedText then speedText:SetText(txt); lastSpeedText = txt end
        end
    end

    return active
end

-- The swing marker is updated on EVERY frame, not on the throttled tick: at 20 Hz a marker that
-- travels the whole bar in ~2.7 s visibly steps instead of gliding. It is cheap enough to justify
-- -- one SetPoint, no string building, no table allocation, and nothing at all while idle because
-- the OnUpdate script is detached when the frame has nothing to show.
local function updateSwingMarker()
    local d = db()
    if not d.showSwing then return end
    local st = BF.state
    local speed = demo and 2.6 or st.swingSpeed
    local lastAt = demo and (GetTime() - math.mod(GetTime() - demo.start, 2.6)) or st.lastSwingAt
    if not (S.hasSwung(lastAt) and speed and speed > 0) then
        swingMark:Hide()
        return
    end
    local p = S.progress(lastAt, GetTime(), speed, st.swingOffset)
    -- SetPoint replaces the existing anchor of the same type, so ClearAllPoints per frame is
    -- unnecessary work.
    swingMark:SetPoint("LEFT", swingHost, "LEFT", p * (d.width - 2), 0)
    swingMark:Show()
end

-- Decides whether the frame should be on screen at all, and keeps the OnUpdate script attached
-- only while it has something to do.
function BF.RequestUpdate()
    if not frame then return end
    local d = db()
    local st = BF.state

    -- The deliberate hide is honoured FIRST, ahead of demo mode and ahead of the environment
    -- hint. Checked further down it was unreachable whenever SuperWoW was missing, so the
    -- "SuperWoW required" frame could not be dismissed at all: right-clicking the minimap button
    -- flipped the flag and announced "hidden" while the frame stayed on screen.
    if d.hidden then
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        return
    end

    if demo then
        frame:Show()
        if not frame:GetScript("OnUpdate") then frame:SetScript("OnUpdate", BF.OnUpdate) end
        return
    end

    if not BF.envOk then
        frame:Show()
        hintText:Show()
        hintText:SetText("SuperWoW required")
        frame:SetScript("OnUpdate", nil)
        return
    end

    local shouldShow = st.active or st.inCombat or not d.hideWhenInactive
    if d.hideOutOfCombat and not st.inCombat then shouldShow = false end

    if shouldShow then
        hintText:Hide()
        frame:Show()
        -- "On screen" and "has work to do" are different questions. With hideWhenInactive off
        -- (the default) the frame stays visible while idle -- but once the buffer is down and
        -- combat has ended there is nothing left to animate, so the OnUpdate script is still
        -- detached: it was otherwise left spinning from login to logout, redrawing a saturated
        -- swing marker every rendered frame and walking the whole buff list five times a second
        -- for a readout that cannot change. The aura, combat and swing handlers in data.lua each
        -- end in a RequestUpdate call and re-attach it, so nothing has to poll for the wakeup.
        --
        -- A swing still in flight counts as work even with the buffer down and combat over:
        -- auto-attacking out of combat is ordinary play, and parking on it would freeze the
        -- marker where it stood. Once progress saturates this stops being true and the loop's
        -- own RequestUpdate call parks it.
        local swinging = d.showSwing and st.swingSpeed and st.swingSpeed > 0
            and S.hasSwung(st.lastSwingAt)
            and S.progress(st.lastSwingAt, GetTime(), st.swingSpeed, st.swingOffset) < 1
        if st.active or st.inCombat or swinging then
            if not frame:GetScript("OnUpdate") then frame:SetScript("OnUpdate", BF.OnUpdate) end
        else
            frame:SetScript("OnUpdate", nil)
            -- One last pass, unconditionally: the frame is visible and nothing will tick it, so
            -- it has to be left parked on the correct final state rather than on empty text.
            updateDisplay()
            updateSwingMarker()
        end
    else
        frame:Hide()
        frame:SetScript("OnUpdate", nil)     -- idle costs nothing at all
    end
end

function BF.OnUpdate()
    updateSwingMarker()
    sinceUpdate = sinceUpdate + arg1
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local active = updateDisplay()
    -- Re-evaluated whatever hideWhenInactive says: with it off the frame stays on screen, but the
    -- loop still has nothing left to do, and RequestUpdate is what parks it. Gating this on the
    -- setting is why the handler used to run for the whole session in the default configuration.
    if not demo and not active and not BF.state.inCombat then
        BF.RequestUpdate()
    end
end

-- ---- demo mode --------------------------------------------------------------------------

-- Runs the display off a synthetic 12 second cycle so the layout and colours can be judged
-- without a shaman, a fight, or the aura question being settled. This is the difference between
-- "looks about right in my head" and actually seeing the red/yellow/green transitions.
function BF.ToggleDemo(on)
    if on == nil then on = (demo == nil) end
    if on then
        demo = { start = GetTime(), maxHP = (UnitHealthMax("player") or 4588) }
        if demo.maxHP <= 0 then demo.maxHP = 4588 end
        -- Turning demo on is an explicit "show me the frame", so it clears the manual hide.
        -- RequestUpdate honours that hide FIRST (it has to -- otherwise the "SuperWoW required"
        -- frame cannot be dismissed), which meant '/bulwark demo' over a minimap-hidden frame
        -- reported "demo on", drew nothing, ticked nothing, and left the user silently parked in
        -- demo mode until they un-hid the frame. Clearing the flag here keeps the precedence
        -- where it belongs and still makes the command deliver what it announces.
        db().hidden = false
        -- Synthetic numbers MUST be labelled as such. Unlabelled demo data is indistinguishable
        -- from a live readout that happens to be wrong, and that is the one failure this addon
        -- exists to avoid.
        if demoTag then demoTag:Show() end
    else
        demo = nil
        if demoTag then demoTag:Hide() end
        lastPoolText, lastTimeText, lastSpeedText = nil, nil, nil
    end
    BF.RequestUpdate()
    return demo ~= nil
end

function BF.IsDemo() return demo ~= nil end

-- Deliberate show/hide, saved. Separate from the automatic hiding: this is the user saying "get
-- out of the way", not the addon deciding there is nothing to show.
function BF.ToggleFrame(on)
    local d = db()
    if on == nil then on = d.hidden and true or false end
    d.hidden = not on
    BF.RequestUpdate()
    return not d.hidden
end

-- ---- lifecycle --------------------------------------------------------------------------

function BF.InitUI()
    BF.ensureDefaults()
    BuildFrame()
    local ok = BulwarkFrameEnv.check(SUPERWOW_VERSION)
    BF.envOk = ok
    BF.state.maxHP = UnitHealthMax("player") or 0
    -- Seeded here as well as in the PLAYER_ENTERING_WORLD handler: this runs off PLAYER_LOGIN and
    -- the order of the two is not guaranteed. PLAYER_REGEN_DISABLED only fires on ENTERING combat,
    -- so without a live read a /reload taken mid-fight leaves "Combat only" users with no frame
    -- for the rest of the encounter.
    BF.state.inCombat = UnitAffectingCombat("player") and true or false
    BF.CapturePlayerGuid()
    if ok then
        BF.RefreshSwingInputs()
        BF.ScanAuras()
    end
    BF.RequestUpdate()
end

function BF.GetFrame() return frame end
