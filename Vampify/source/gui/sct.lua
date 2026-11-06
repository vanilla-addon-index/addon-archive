-- Vampify -- scrolling combat text, our own.
--
-- Blizzard's FCT (gui/fct.lua) cannot be positioned or fully recolored by an addon --
-- Blizzard_CombatText owns its own frame, and its position is not settable from outside. This is
-- the alternative engine: a positionable anchor frame, a pooled set of FontStrings, and one shared
-- OnUpdate driving every number in flight. Which engine actually runs is chosen by
-- VampifyDB.sct.mode ("own" | "bar" | "blizzard") and dispatched from core/commands.lua -- "bar"
-- is this SAME engine and pool, just anchored to the display bar instead of a free-floating
-- position (see reanchor() below); this file does not know or care that the Blizzard alternative
-- exists.
--
-- Pure-Lua 5.0 dofile-loadable: VampifySCT exists at file scope, but every function that touches
-- the WoW API lives inside "if CreateFrame then" -- same shape as gui/display.lua and
-- gui/options.lua. resolveAnchorMode below is the one exception: it is pure decision logic (mode +
-- bar-frame-exists -> "bar" | "free"), so it lives outside the guard, offline-testable the same
-- way gui/display.lua's V.boundFlag is (tools/luatests/test_sct.lua).

VampifySCT = {}
local S = VampifySCT

-- Which anchor a given mode resolves to. "bar" only when the mode actually asks for it AND the
-- bar frame exists yet -- reanchor() below is the reason existence, not visibility, is the gate:
-- a hidden-but-created bar can still anchor to, a not-yet-created one cannot. Every other mode,
-- including nil (fresh/unmigrated profile) and any future/unknown value, resolves to the
-- free-floating anchor rather than erroring -- the safe, always-available fallback.
function S.resolveAnchorMode(mode, barExists)
    if mode == "bar" and barExists then return "bar" end
    return "free"
end

if CreateFrame then
    local W = VampifyWidgets
    local C = W.COLORS

    local POOL_MAX     = 20
    local DUR_FALLBACK = 1.5

    -- Crit pop, in multiples of the configured font size. Ratios taken from Blizzard's own combat
    -- text: MINHEIGHT 30 and MAXHEIGHT 60 against a base of 25, grown over 0.05s and shrunk back by
    -- 0.2s (Blizzard_CombatText.lua:4-8).
    local CRIT_MIN    = 30 / 25
    local CRIT_MAX    = 60 / 25
    local CRIT_GROW   = 0.05
    local CRIT_SHRINK = 0.2

    local anchor, label
    local moveMode = false
    local spawnCounter = 0
    -- Cache of the last anchor mode actually applied ("bar" | "free" | nil before the first
    -- build). Lets reanchor() below be a cheap no-op on every spawn once nothing has changed,
    -- instead of an unconditional ClearAllPoints+SetPoint per number -- which matters because it
    -- would otherwise fight an in-progress free-anchor drag. It cannot: the mode cannot change
    -- mid-drag (moveMode is only reachable in "own" mode, see S.setMoveMode below), so a drag never
    -- sees anchorMode flip underneath it.
    local lastAnchorMode = nil

    -- Fixed-size slot pool: a pre-sized array of records, each either idle or carrying one number.
    -- Free slots live on a manual LIFO stack (freeStack/freeTop) -- push/pop by hand, never
    -- table.insert/table.remove/table.getn, so there is no growing "n" field and no need for
    -- VampifyConst.resetList (core/const.lua): the Lua-5.0 trap that helper guards against simply
    -- does not exist in this design.
    local slots = {}
    local freeStack, freeTop = {}, 0
    for i = 1, POOL_MAX do
        slots[i] = { active = false, fs = nil, t = 0, dur = DUR_FALLBACK, dx = 0, dy0 = 0,
                     alphaMul = 1, crit = false, base = 16 }
        freeTop = freeTop + 1
        freeStack[freeTop] = i
    end

    local function db() return VampifyConfig.get() end

    -- Only the border/background/label are hidden in normal operation -- the frame itself always
    -- stays shown, because the pooled FontStrings are its children and a hidden parent would hide
    -- them too. "Invisible" here means alpha 0, not SetBackdrop(nil).
    local function applyMoveVisuals()
        if moveMode then
            anchor:EnableMouse(true)
            anchor:SetBackdropColor(0.08, 0.09, 0.12, 0.85)
            anchor:SetBackdropBorderColor(C.gold.r, C.gold.g, C.gold.b, 1)
            if label then label:Show() end
        else
            anchor:EnableMouse(false)
            anchor:SetBackdropColor(0, 0, 0, 0)
            anchor:SetBackdropBorderColor(0, 0, 0, 0)
            if label then label:Hide() end
        end
    end

    -- Applies the resolved anchor mode to the live frame -- "bar" hangs the anchor off
    -- VampifyDisplayFrame's top edge (numbers rise FROM the bar's top upward, matching every other
    -- rising-number layout in this file); anything else restores the stored free position, the
    -- same positioning logic build() always used. `force` bypasses the lastAnchorMode cache: used
    -- for the initial build() placement and for an explicit runtime switch (S.applyPos, called from
    -- gui/options.lua on every mode-radio click and on Reset) so the anchor moves immediately
    -- instead of waiting for the next spawn. Without force, a spawn's routine call is a no-op
    -- unless the resolved mode actually changed since last time -- see lastAnchorMode's comment.
    local function reanchor(force)
        local cfg = db()
        local mode = cfg and cfg.sct and cfg.sct.mode
        local barExists = getglobal("VampifyDisplayFrame") and true or false
        local anchorMode = S.resolveAnchorMode(mode, barExists)
        if not force and anchorMode == lastAnchorMode then return end
        lastAnchorMode = anchorMode
        anchor:ClearAllPoints()
        if anchorMode == "bar" then
            anchor:SetPoint("BOTTOM", VampifyDisplayFrame, "TOP", 0, 6)
        else
            local pos = (cfg and cfg.sct and cfg.sct.pos) or { point = "CENTER", x = -180, y = 0 }
            anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end

    local function build()
        if anchor then return anchor end

        local a = CreateFrame("Frame", "VampifySCTAnchor", UIParent)
        a:SetWidth(140)
        a:SetHeight(30)
        -- HIGH, not the default MEDIUM/level 1 -- MEDIUM disappears under pfUI, the exact failure
        -- gui/display.lua already hit and documented there.
        a:SetFrameStrata("HIGH")
        a:SetFrameLevel(10)
        a:SetMovable(true)
        a:EnableMouse(false)     -- normal operation: out of the mouse's way entirely
        a:SetClampedToScreen(true)
        a:RegisterForDrag("LeftButton")
        a:SetBackdrop(W.SOLID_BACKDROP)

        a:SetScript("OnDragStart", function()
            if moveMode then this:StartMoving() end
        end)
        a:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            local point, _, _, x, y = this:GetPoint()
            local c = db()
            if c and c.sct then c.sct.pos = { point = point, x = x, y = y } end
        end)

        label = a:CreateFontString("VampifySCTAnchorLabel", "OVERLAY")
        W.ApplyFont(label, 10)
        W.SetTextColorG(label, C.goldHi)
        label:SetPoint("CENTER", a, "CENTER", 0, 0)
        label:SetText("Vampify SCT")
        label:Hide()

        anchor = a
        -- Initial placement: bar anchor if mode == "bar" AND VampifyDisplayFrame already exists at
        -- this point, else the stored free position. If the bar has not been created yet (load
        -- order), this falls back to free without error -- spawn()'s own reanchor() call re-checks
        -- on every emit, lazily, so the very next number picks up the bar once it exists.
        reanchor(true)
        anchor:Show()     -- always shown; see applyMoveVisuals for why
        applyMoveVisuals()
        return a
    end

    local function fontSize()
        local cfg = db()
        local sct = cfg and cfg.sct
        return (sct and sct.fontSize) or 16
    end

    -- Outline flag and shadow, the two halves of "readable over anything". Stored as a string
    -- because that is exactly what SetFont's third argument takes; "" means no outline.
    local function outlineFlag()
        local cfg = db()
        local sct = cfg and cfg.sct
        local f = sct and sct.outline
        if f == "" then return nil end
        return f or "THICKOUTLINE"
    end

    local function shadowOn()
        local cfg = db()
        local sct = cfg and cfg.sct
        if sct and sct.shadow == false then return false end
        return true
    end

    -- How far a number travels over its lifetime. Doubles as the crowding control: a taller rise
    -- spreads a burst over more vertical space, which is exactly what the user asked this slider
    -- for -- so the numbers don't overlap so heavily and have more room.
    local function riseHeight()
        local cfg = db()
        local sct = cfg and cfg.sct
        return (sct and sct.rise) or 40
    end

    local function ensureFs(i)
        local s = slots[i]
        if s.fs then return s.fs end
        local fs = anchor:CreateFontString("VampifySCTNum"..i, "OVERLAY")
        W.ApplyFont(fs, fontSize(), outlineFlag())
        W.ApplyShadow(fs, shadowOn())
        s.fs = fs
        return fs
    end

    -- Re-apply the font to every pooled FontString. Called when the size slider moves: the pool is
    -- built lazily and lives for the session, so without this only numbers spawned from fresh
    -- slots would pick up the new size.
    function S.applyFont()
        local sz, fl, sh = fontSize(), outlineFlag(), shadowOn()
        for i = 1, POOL_MAX do
            if slots[i] and slots[i].fs then
                W.ApplyFont(slots[i].fs, sz, fl)
                W.ApplyShadow(slots[i].fs, sh)
            end
        end
    end

    -- Pop a free slot off the LIFO stack -- O(1), no table.remove/table.getn. Only when the stack
    -- is empty (all 20 numbers in flight at once) does this fall back to an O(n) scan, and even
    -- then it picks the oldest-active slot: closest to fading out anyway, so recycling it is the
    -- least noticeable choice.
    local function acquire()
        if freeTop > 0 then
            local i = freeStack[freeTop]
            freeStack[freeTop] = nil
            freeTop = freeTop - 1
            return i
        end
        local oldest, oldestT = 1, -1
        for i = 1, POOL_MAX do
            if slots[i].t > oldestT then oldestT = slots[i].t; oldest = i end
        end
        return oldest
    end

    -- Push a slot back onto the free stack once its number has fully faded.
    local function release(i)
        freeTop = freeTop + 1
        freeStack[freeTop] = i
    end

    -- The one shared animation driver for every active number. Attached on the first spawn,
    -- detached the moment nothing is left in flight -- an idle SCT costs nothing.
    local function onUpdate()
        local dt = arg1
        local any = false
        for i = 1, POOL_MAX do
            local s = slots[i]
            if s.active then
                s.t = s.t + dt
                if s.t >= s.dur then
                    s.active = false
                    s.fs:Hide()
                    release(i)
                else
                    any = true
                    local frac = s.t / s.dur
                    -- Rises sct.rise px over its lifetime; dy0 is an extra starting offset that decays to
                    -- zero as frac -> 1, so a burst of simultaneous numbers starts spread out and
                    -- converges onto the same rising line instead of stacking exactly on top of
                    -- each other for their whole arc. UNVERIFIED: this staggering is not backed by
                    -- any researched pattern (none exists for this in the wow-domain knowledge base
                    -- at time of writing) -- it is a simple, untested heuristic. Watch it in-game.
                    local rise = s.rise
                    if s.crit then
                        -- Blizzard pins a crit at its start position; here it still drifts, but far
                        -- less, so it reads as "popped in place" without freezing on screen.
                        rise = s.rise * 0.25
                        -- Grow, then shrink back -- the pop that distinguishes a crit from a big
                        -- normal number.
                        local h
                        if s.t < CRIT_GROW then
                            h = CRIT_MIN + (CRIT_MAX - CRIT_MIN) * (s.t / CRIT_GROW)
                        elseif s.t < CRIT_SHRINK then
                            h = CRIT_MAX - (CRIT_MAX - CRIT_MIN)
                                * ((s.t - CRIT_GROW) / (CRIT_SHRINK - CRIT_GROW))
                        else
                            h = CRIT_MIN
                        end
                        s.fs:SetTextHeight(s.base * h)
                    end
                    local y = frac * rise + s.dy0 * (1 - frac)
                    s.fs:ClearAllPoints()
                    s.fs:SetPoint("CENTER", anchor, "CENTER", s.dx, y)
                    s.fs:SetAlpha((1 - frac) * s.alphaMul)
                end
            end
        end
        if not any then anchor:SetScript("OnUpdate", nil) end
    end

    -- The path that actually spawns a number. S.emit gates this on cfg.sct.enabled; S.demo calls it
    -- directly so positioning still works while SCT is switched off in the options window.
    local function spawn(amount, isOverheal, isCrit)
        build()
        -- Lazy re-check, not OnUpdate polling: cheap no-op once the resolved anchor mode has not
        -- changed (see lastAnchorMode), but catches a bar that came into existence after this
        -- anchor was first built (load-order dependent) on the very next number spawned.
        reanchor()
        local cfg = db()
        local sct = cfg and cfg.sct
        if not sct then return end

        local i = acquire()
        local s = slots[i]
        local fs = ensureFs(i)

        s.active = true
        s.t      = 0
        s.dur    = sct.duration or DUR_FALLBACK
        s.rise   = riseHeight()

        spawnCounter = spawnCounter + 1
        -- Stagger scales with the rise: a taller column gets proportionally wider lanes and bigger
        -- starting offsets, so raising the slider genuinely buys room instead of just stretching
        -- the same crowding over a longer arc.
        local spread = s.rise / 40
        if math.mod(spawnCounter, 2) == 0 then s.dx = 12 * spread else s.dx = -12 * spread end
        s.dy0 = math.mod(spawnCounter, 3) * 6 * spread
        if isOverheal then s.alphaMul = 0.5 else s.alphaMul = 1 end

        -- Vampirism itself never crits. A return CAUSED by a crit is marked the way the client's
        -- own combat text marks one -- and that is not merely "bigger": Blizzard grows the number,
        -- shrinks it back, and keeps it in place instead of scrolling it away
        -- (Blizzard_CombatText.lua:280-282, 336-339). Copying the behaviour, not just the size, is
        -- what makes it read as a crit at a glance.
        s.crit = isCrit and true or false
        s.base = fontSize()
        W.ApplyFont(fs, s.base, outlineFlag())
        W.ApplyShadow(fs, shadowOn())
        if s.crit then
            -- SetTextHeight scales the rendered text without touching the font object, which is why
            -- Blizzard animates with it rather than re-applying a font every frame.
            fs:SetTextHeight(s.base * CRIT_MIN)
        else
            fs:SetTextHeight(s.base)
        end

        local col = sct.color or { r = 0.4, g = 0.9, b = 0.4 }
        fs:SetTextColor(col.r, col.g, col.b)
        -- Overheal is parenthesized rather than minus-prefixed: it is still healing, and a leading
        -- "-" would read as damage at a glance. The halved alpha above is the other half of telling
        -- it apart from a real crossing.
        if isOverheal then
            fs:SetText("("..amount..")")
        else
            fs:SetText("+"..amount)
        end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", anchor, "CENTER", s.dx, 0)
        fs:SetAlpha(1 * s.alphaMul)
        fs:Show()

        anchor:SetScript("OnUpdate", onUpdate)
    end

    -- amount is the integer to show -- an accumulator crossing for real heals (core/model.lua),
    -- a per-hit floored amount for overheal (core/commands.lua) -- never a raw float. Zero
    -- crossings are not emitted: the accumulator does not cross an integer on every hit, and a
    -- stream of "+0" would just be noise (the same rule gui/fct.lua enforced before it).
    function S.emit(amount, isOverheal, isCrit)
        if not amount or amount <= 0 then return end
        local cfg = db()
        if not cfg or not cfg.sct or not cfg.sct.enabled then return end
        spawn(amount, isOverheal, isCrit)
    end

    -- Three sample numbers so the user can see where they land while dragging the anchor. Bypasses
    -- the enabled gate on purpose: positioning must work even with SCT switched off.
    -- A burst spread over a couple of seconds, not three numbers at once: the whole point of the
    -- demo is to judge spacing, rise and fade while tuning the sliders, and all three of those are
    -- only visible when numbers arrive the way they do in a fight. Runs on its own ticker frame so
    -- it cannot interfere with the animation driver, and detaches itself when finished.
    local demoLeft, demoAcc, demoTicker = 0, 0, nil

    function S.demo(count)
        build()
        demoLeft = count or 10
        demoAcc  = 0
        if not demoTicker then
            demoTicker = CreateFrame("Frame", "VampifySCTDemoFrame", UIParent)
        end
        demoTicker:SetScript("OnUpdate", function()
            demoAcc = demoAcc + arg1
            if demoAcc < 0.25 then return end
            demoAcc = 0
            if demoLeft <= 0 then
                this:SetScript("OnUpdate", nil)
                return
            end
            demoLeft = demoLeft - 1
            -- Every style the real thing can produce, because a demo that only shows one of them
            -- lets you tune half the appearance: plain returns, dimmed overheal in parentheses, and
            -- crit-caused returns in the larger font. Crits carry a bigger number, since a crit is
            -- a bigger hit and therefore a bigger return.
            local phase   = math.mod(demoLeft, 5)
            local isOver  = (phase == 0)
            local isCrit  = (phase == 2 or phase == 3)
            local n = math.mod(demoLeft, 4) + 3
            if isCrit then n = n * 2 end
            spawn(n, isOver, isCrit)
        end)
    end

    -- Returns true on success. Refuses to turn ON while anchored to the bar (mode == "bar") --
    -- dragging is meaningless there, the anchor point is derived from VampifyDisplayFrame, not a
    -- stored position -- and returns false plus a one-line reason instead, so callers (currently
    -- core/commands.lua's "/vf sctmove") can tell the player why nothing happened. Turning OFF is
    -- always allowed; there is nothing to refuse there.
    function S.setMoveMode(on)
        build()
        if on then
            local cfg = db()
            local mode = cfg and cfg.sct and cfg.sct.mode
            if mode == "bar" then
                return false, "SCT is anchored to the bar in this mode -- switch to \"Free anchor\""
                    .." in Options to move it."
            end
        end
        moveMode = on and true or false
        applyMoveVisuals()
        if moveMode then S.demo() end
        return true
    end

    function S.isMoveMode()
        return moveMode
    end

    -- Explicit, forced re-anchor: called from gui/options.lua on every engine-mode radio click and
    -- on "Reset" -- both want the anchor to move at once, not wait for the next spawn's lazy check.
    function S.applyPos()
        build()
        reanchor(true)
    end
end
