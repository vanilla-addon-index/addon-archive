-- Vampify -- options window, built in DopingControl's visual language (gui/widgets.lua) so the two
-- addons read as the same toolkit rather than as a Blizzard dialog bolted onto a hand-rolled one.
--
-- Layout follows DopingControl's ui/options.lua pattern: a lazily-built frame, a layout cursor that
-- places widgets top-down, checkboxes with getter/setter pairs repopulated on OnShow, buttons via
-- VampifyWidgets.MakeButton, and a throttled info panel that only repaints text that changed
-- (VampifyWidgets.SetTextG). The info panel itself is specific to this addon -- there is no grid
-- here, just the source list and the honesty lines about what the number does and does not mean.
--
-- Pure-Lua 5.0 dofile-loadable: all WoW wiring behind "if CreateFrame then".

VampifyOptions = {}
local O = VampifyOptions

-- ---- WoW wiring ------------------------------------------------------------------------------

if CreateFrame then
    local W = VampifyWidgets
    local C = W.COLORS

    local frame
    local checkboxes = {}
    local infoFS
    local elapsed = 0
    local shareBuf = {}

    -- SCT color/position controls -- declared here (not local to build()) so refreshSwatch() and
    -- refreshEnabled() below can reach them from OnShow/OnUpdate as well as from the checkboxes'
    -- own setters. sliderPillH/sliderPanelBarH (2026-08-25) join the same list for the same reason
    -- -- refreshSliders() below needs to push their persisted values in on OnShow, same as
    -- sliderFont/sliderRise already do.
    local swatch, btnMove, btnPosReset, posLabel, sliderFont, sliderRise, btnDemo, btnOutline,
        sliderPillH, sliderPanelBarH, sliderDuration

    local function db() return VampifyConfig.get() end

    -- Same merge as core/commands.lua's recompute(): detected sources plus manual overrides. Kept
    -- here rather than reading commands.lua's private locals (there is nothing exported to read),
    -- so the info panel's Total/Floor line matches what the addon actually uses to size a hit.
    local function totals()
        local sources = VampifyDetect.getSources()
        local sum, n = VampifyDetect.summarise(sources)
        local cfg = VampifyConfig.getChar()
        if cfg and cfg.manual then
            for i = 1, table.getn(cfg.manual) do
                sum = sum + (cfg.manual[i] / 100)
                n = n + 1
            end
        end
        return sources, sum, n
    end

    -- ------------------------------------------------------------------
    -- widget helpers
    -- ------------------------------------------------------------------
    local checkCounter = 0
    local function CreateCheckbox(parent, label, getter, setter)
        checkCounter = checkCounter + 1
        local name = "VampifyOptionsCheck" .. checkCounter
        local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
        cb:SetWidth(24)
        cb:SetHeight(24)
        local text = getglobal(name .. "Text")
        text:SetText(label)
        W.ApplyFont(text, 11)
        W.SetTextColorG(text, C.ink)
        cb.vfLabelFS = text     -- exposed so a caller can chain another widget off the label's
                                 -- right edge (measured, not estimated -- see the SCT engine row)
        cb.vfGet = getter
        cb.vfSet = setter
        cb:SetScript("OnClick", function()
            this.vfSet(this:GetChecked() == 1)     -- GetChecked returns 1 | nil
        end)
        table.insert(checkboxes, cb)
        return cb
    end

    -- ------------------------------------------------------------------
    -- info panel text -- rebuilt only when this fires (throttled OnUpdate), never per damage event
    -- ------------------------------------------------------------------
    local infoLines = {}
    local floorBuf = {}     -- reused result table for the floor-share line below

    -- The upgrade verdict, THROTTLED to once a second and cached as a finished string.
    --
    -- WHY THROTTLED RATHER THAN COMPUTED ONCE ON OPEN. VampifyHistogram.compare is four passes over
    -- the whole recorded distribution -- the baseline plus three hypotheticals -- and this panel
    -- repaints twice a second for as long as it is open, so computing it per repaint would spend
    -- eight passes a second on a line whose answer moves about as fast as the player's gear does.
    -- But once-on-open would be worse in the case that matters: the panel is left open while
    -- fighting, the distribution keeps filling, and a verdict frozen at the moment of opening would
    -- be stale exactly when the player is watching it change. Once a second is two orders of
    -- magnitude cheaper than the alternative and still live.
    --
    -- Everything is held in ONE table rather than three locals on purpose: this file's enclosing
    -- closure is already wide, and Lua 5.0 caps locals and upvalues per function.
    local cmp = { buf = {}, text = nil, at = nil }
    local function upgradeLine()
        local now = GetTime and GetTime() or nil
        -- No GetTime (offline/stub): compute once and keep it, rather than every repaint.
        if cmp.text and (not now or (cmp.at and (now - cmp.at) < 1)) then return cmp.text end
        cmp.at, cmp.text = now, ""
        if not (VampifyHistogram and VampifyState and VampifyState.hist) then return cmp.text end
        -- Always at +1 point here. The panel states the CHOICE, not a shopping calculator; a player
        -- who wants a different step has /vf upgrade <pct>, which prints both scopes as well.
        local c = VampifyHistogram.compare(VampifyState.hist, VampifyState.sourcePercents, 1, cmp.buf)
        if not (c.hits and c.hits > 0) then return cmp.text end
        if c.winner == "swap" and c.swapIndex then
            cmp.text = string.format("Upgrade: swap your weakest source (%d%% -> %d%%) - worth"
                .." +%d HP here against +%d for one more 1%% source",
                c.swapFrom, c.swapTo, math.floor(c.swapDelta), math.floor(c.addDelta))
        elseif c.winner == "add" then
            cmp.text = string.format("Upgrade: one more 1%% source - worth +%d HP here against"
                .." +%d for swapping your weakest one",
                math.floor(c.addDelta), math.floor(c.swapDelta))
        else
            cmp.text = string.format("Upgrade: one more 1%% source and swapping your weakest one"
                .." are worth the same here (+%d HP each)", math.floor(c.addDelta))
        end
        return cmp.text
    end

    local function composeInfo()
        VampifyConst.resetList(infoLines)   -- nil-ing indices is not enough in 5.0; see const.lua

        local sources, sumPercent, nSources = totals()
        local n = table.getn(sources)
        for i = 1, n do
            table.insert(infoLines, string.format("Slot %d: %d%% (%s)",
                sources[i].slot, sources[i].percent, sources[i].kind))
        end
        table.insert(infoLines, string.format("Total: %.0f%% from %d sources", sumPercent * 100, nSources))
        table.insert(infoLines, string.format("Floor: %d HP per hit", nSources))
        -- How much of this session's healing the floor ACTUALLY paid, over the recorded hit
        -- distribution (core/histogram.lua) rather than as a per-hit minimum. A high share means
        -- the hits are small enough that every source is pinned at 1 HP, which is the regime where
        -- one MORE source beats swapping a weak one out. One pass over the distribution, cheap
        -- enough to run on every repaint; the verdict line below it is the expensive part and is
        -- throttled separately (see upgradeLine).
        if VampifyHistogram and VampifyState and VampifyState.hist then
            local t = VampifyHistogram.totals(VampifyState.hist, VampifyState.sourcePercents, floorBuf)
            if t.hits > 0 then
                table.insert(infoLines, string.format(
                    "Floor share: %d of %d HP (%.0f%%) over %d hits",
                    math.floor(t.floorHeal), math.floor(t.heal), t.floorShare * 100, t.hits))
            end
            -- The decision itself, so it is readable without typing anything. /vf upgrade still
            -- gives the full report: both scopes, a chosen step size, and the ceiling figure.
            local up = upgradeLine()
            if up ~= "" then table.insert(infoLines, up) end
        end

        local fight   = VampifyAggregate.fight(VampifyState)
        local session = VampifyAggregate.session(VampifyState)
        local eff = VampifyState.effHeal or 0
        local overheal = (fight.heal or 0) - eff
        if overheal < 0 then overheal = 0 end
        local ohPct = 0
        if fight.heal and fight.heal > 0 then ohPct = overheal / fight.heal * 100 end

        table.insert(infoLines, string.format("Fight: %d healed, %.2f%%",
            math.floor(fight.heal or 0), (fight.pct or 0) * 100))
        -- Overheal is CALCULATED from the health deficit at hit time, not measured -- Vampirism
        -- emits no heal event. The line right below says so; do not let the number alone imply
        -- more precision than that.
        table.insert(infoLines, string.format("Effective: %d healed, %d overheal (%.0f%%)",
            math.floor(eff), math.floor(overheal), ohPct))
        table.insert(infoLines, "|cff" .. string.format("%02x%02x%02x",
            C.faint.r * 255, C.faint.g * 255, C.faint.b * 255)
            .. "Overheal is derived from the health deficit at the time of the hit, not from a"
            .. " heal event - Vampirism emits none.|r")
        table.insert(infoLines, string.format("Session: %d healed, %.2f%%",
            math.floor(session.heal or 0), (session.pct or 0) * 100))

        local flag = VampifyDisplay.boundFlag(VampifyConst.FORMULA.channels, VampifyDamage.aoeAvailable())
        if flag == "lower" or flag == "uncertain" then
            table.insert(infoLines, "|cffe0c98aLower bound: DoT and PvP damage are unmeasured and excluded.|r")
        end
        if flag == "upper" or flag == "uncertain" then
            table.insert(infoLines, "|cffe0c98aUpper bound: no SPELL_GO seen, AoE damping not applied.|r")
        end
        if not VampifyDamage.damageSeen() then
            table.insert(infoLines, "|cffd05252No damage events received - nampower may be absent.|r")
        end

        return table.concat(infoLines, "\n")
    end

    -- The info panel grows and shrinks with what it has to say: the source list is as long as the
    -- player's gear, and the honesty lines come and go. A fixed frame height therefore cannot fit
    -- it -- reported in-game as text hanging out of the bottom edge.
    --
    -- Note the panel is measured, not estimated: 1.12 has no GetStringHeight (only GetStringWidth
    -- exists in Blizzard's own FrameXML), but a FontString with an explicit width lays its wrapped
    -- text out and reports the real height through GetHeight().
    local function fitHeight()
        if not (frame and infoFS) then return end
        local top, iTop, iH = frame:GetTop(), infoFS:GetTop(), infoFS:GetHeight()
        if not (top and iTop and iH) then return end
        local need = (top - iTop) + iH + 18          -- header block + text + bottom padding
        if need < 300 then need = 300 end            -- never collapse to nothing
        if math.abs(frame:GetHeight() - need) > 2 then frame:SetHeight(need) end
    end

    local function refreshInfo()
        if infoFS then
            W.SetTextG(infoFS, composeInfo())
            fitHeight()
        end
    end

    local function refreshChecks()
        local cfg = db()
        if not cfg then return end
        for i = 1, table.getn(checkboxes) do
            local cb = checkboxes[i]
            cb:SetChecked(cb.vfGet() and 1 or nil)
        end
    end

    -- Swatch background = the currently configured SCT color. Applies in both modes (see
    -- gui/fct.lua), so it is never part of refreshEnabled()'s greying below.
    local function refreshSwatch()
        if not swatch then return end
        local cfg = db()
        local col = cfg and cfg.sct and cfg.sct.color
        if col then swatch:SetBackdropColor(col.r, col.g, col.b, 1) end
    end

    -- Greys out the controls that are genuinely inert outside "Free anchor" mode: Blizzard mode
    -- owns its own position and timing (Blizzard_CombatText), and bar mode derives its position
    -- from VampifyDisplayFrame rather than the stored free position -- in both cases the slider/
    -- Move/Reset controls below have nothing to act on. NOT the color swatch, which still applies
    -- in all three modes.
    local function refreshEnabled()
        local cfg = db()
        local mode = cfg and cfg.sct and cfg.sct.mode
        -- Active only in "own" -- nil (fresh/unmigrated profile) and any unrecognised value fall
        -- back to enabled too, matching gui/sct.lua's resolveAnchorMode's "unknown -> free" rule.
        local posEnabled = (mode ~= "bar" and mode ~= "blizzard")

        if btnMove then W.SetButtonEnabled(btnMove, posEnabled) end
        if btnPosReset then W.SetButtonEnabled(btnPosReset, posEnabled) end
        if posLabel then W.SetTextColorG(posLabel, posEnabled and C.ink or C.faint) end
        -- The sliders shape THIS addon's own SCT only; Blizzard's owns its font and travel.
        -- NOT Enable()/Disable(): a Slider has neither in 1.12 (it threw in-game). See
        -- W.SetSliderEnabled, which follows Blizzard's own hide-the-thumb recipe.
        W.SetSliderEnabled(sliderRise, posEnabled)
        W.SetSliderEnabled(sliderFont, posEnabled)
        -- Fade duration is the same category as fontSize/rise above: it shapes OUR pooled
        -- FontStrings only (gui/sct.lua's S.spawn reads sct.duration into s.dur), so it follows
        -- the same posEnabled greying.
        W.SetSliderEnabled(sliderDuration, posEnabled)
        if btnDemo then W.SetButtonEnabled(btnDemo, posEnabled) end
        -- The outline shapes OUR numbers only; Blizzard's engine draws its own.
        if btnOutline then W.SetButtonEnabled(btnOutline, posEnabled) end
    end

    -- Push stored values into the sliders without letting OnValueChanged write them straight back.
    local function refreshSliders()
        if sliderFont then
            local v = sliderFont.vfGetter()
            sliderFont:SetValue(v)
            getglobal("VampifyOptionsFontSliderText"):SetText(sliderFont.vfLabel .. ": " .. v)
        end
        if sliderRise then
            local v = sliderRise.vfGetter()
            sliderRise:SetValue(v)
            getglobal("VampifyOptionsRiseSliderText"):SetText(sliderRise.vfLabel .. ": " .. v)
        end
        if sliderPillH then
            local v = sliderPillH.vfGetter()
            sliderPillH:SetValue(v)
            getglobal("VampifyOptionsPillHeightSliderText"):SetText(sliderPillH.vfLabel .. ": " .. v)
        end
        if sliderPanelBarH then
            local v = sliderPanelBarH.vfGetter()
            sliderPanelBarH:SetValue(v)
            getglobal("VampifyOptionsPanelBarHeightSliderText"):SetText(sliderPanelBarH.vfLabel .. ": " .. v)
        end
        if sliderDuration then
            local v = sliderDuration.vfGetter()
            sliderDuration:SetValue(v)
            getglobal("VampifyOptionsDurationSliderText"):SetText(
                sliderDuration.vfLabel .. ": " .. string.format(sliderDuration.vfFmt or "%s", v))
        end
    end

    -- ------------------------------------------------------------------
    -- frame
    -- ------------------------------------------------------------------
    local function build()
        if frame then return frame end

        local f = CreateFrame("Frame", "VampifyOptionsFrame", UIParent)
        f:SetWidth(340)
        f:SetHeight(608)      -- +42 (Fade duration slider) +26 (Text shadow checkbox) over the
                               -- previous 540; fitHeight() below still re-measures against the
                               -- real info-panel position on every OnShow, so this is only the
                               -- pre-first-show estimate, not the operative bound.
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        -- HIGH, deliberately NOT DIALOG. Blizzard's ColorPickerFrame lives at DIALOG, and a frame
        -- created later in the same strata draws on top of it -- so at DIALOG this window buried
        -- the very colour picker it opens (reported in-game). HIGH keeps us above the normal UI
        -- while leaving DIALOG to Blizzard's own popups, which is where they belong.
        f:SetFrameStrata("HIGH")
        f:SetBackdrop(W.PANEL_BACKDROP)
        f:SetBackdropColor(1, 1, 1, 0.97)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() this:StartMoving() end)
        f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

        -- title (gold), version alongside it
        local title = W.MakeText(f, 14, C.goldHi, "ARTWORK")
        title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
        title:SetText("Vampify v" .. VampifyConst.VERSION)

        -- close X
        local closeX = CreateFrame("Button", "VampifyOptionsCloseX", f, "UIPanelCloseButton")
        closeX:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

        -- layout cursor
        local x, y = 24, -46
        local function place(w, dy)
            w:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
            y = y + dy
        end

        -- ---- checkboxes -------------------------------------------------------------------
        -- Reads the stored preference rather than the frame, so it cannot drift from the minimap
        -- button (which writes the same field) and cannot report "off" merely because the bar is
        -- currently down for a reason of its own -- no sources equipped, or the inert verdict.
        local cbShow = CreateCheckbox(f, "Show display",
            function() local cfg = db(); return cfg and cfg.shown end,
            function(v)
                local cfg = db()
                if cfg then cfg.shown = v end
                if v then VampifyDisplay.show() else VampifyDisplay.hide() end
            end)
        place(cbShow, -26)
        W.AttachTooltip(cbShow, "Same as left-clicking the minimap button.")

        local cbLock = CreateCheckbox(f, "Lock display",
            function() local cfg = db(); return cfg and cfg.locked end,
            function(v) local cfg = db(); if cfg then cfg.locked = v end end)
        place(cbLock, -26)
        W.AttachTooltip(cbLock, "Prevents dragging the display frame around.")

        local cbMinimap = CreateCheckbox(f, "Minimap button",
            function() local cfg = db(); return cfg and cfg.minimap end,
            function(v)
                local cfg = db()
                if cfg then cfg.minimap = v end
                if VampifyMinimap and VampifyMinimap.update then VampifyMinimap.update() end
            end)
        place(cbMinimap, -26)

        local cbOverheal = CreateCheckbox(f, "Show overheal",
            function() local cfg = db(); return cfg and cfg.showOverheal end,
            function(v) local cfg = db(); if cfg then cfg.showOverheal = v end end)
        place(cbOverheal, -26)
        -- Tooltip text updated 2026-08-24 (Befund 2, pixel measurement pass): the compact bar no
        -- longer shows a "(N OH)" suffix at all (moved to the row-detail panel and the breakdown
        -- panel's Total line, to make room on an overflowing bar) -- this option's only remaining
        -- effect is the combat-text half, so the tooltip must not describe a bar effect that no
        -- longer exists.
        W.AttachTooltip(cbOverheal, "Spawns dimmed, parenthesized overheal numbers on the combat text.")

        -- "Show vampirism % on bar" (2026-08-25, feature request: "one more: show vampirism % on
        -- bar - with total%/source count"). This existed on the bar once before ("14.0% (9 Gear)")
        -- and was cut entirely during the 340px->160px compaction pass -- it now comes back as an
        -- OPT-IN toggle instead of a permanent segment. DEFAULT OFF (per the original suggestion,
        -- taken as decided rather than merely offered): the bar stays at its established narrow
        -- width for every existing player, and nobody is surprised by it growing on the very next
        -- login -- the same "an existing profile sees zero visible change until it explicitly opts
        -- in" principle this file's own sliders (pillHeight/panelBarHeight, added at the same time)
        -- already follow. gui/display.lua's V.update() calls V.formatSources(VampifyState.sourcePercents)
        -- for the actual text -- the SAME figure this window's own info panel already shows further
        -- down ("Total: N% from M sources" -- composeInfo() above), fed by the same
        -- VampifyDetect.getSources() + manual overrides core/commands.lua's recompute() already
        -- merges into sourcePercents -- not a second computation.
        local cbGearPct = CreateCheckbox(f, "Show vampirism % on bar",
            function() local cfg = db(); return cfg and cfg.showGearPct end,
            function(v)
                local cfg = db()
                if cfg then cfg.showGearPct = v end
                -- Immediate effect, no /reload -- V.update() already runs the segment's own
                -- show/hide + text + pill-width re-layout logic every tick; calling it once here
                -- (rather than waiting up to ~0.5s for the next throttled tick) matches this file's
                -- own "sofort" convention for every other live-applied option/slider.
                if VampifyDisplay and VampifyDisplay.update then VampifyDisplay.update() end
            end)
        place(cbGearPct, -26)
        W.AttachTooltip(cbGearPct, "Adds \"<total%> (<source count>)\" to the bar -- the sum of your"
            .. " equipped gear's Vampirism percentages and how many sources make it up. Same figure"
            .. " as the \"Total\" line in this window's own info panel below. The bar grows to fit it.")

        -- Same field (VampifyDB.perhitEnabled) /vf perhit on|off writes, core/commands.lua -- the
        -- two cannot drift, same as cbShow above and the minimap button's left-click both writing
        -- cfg.shown. The actual enable/disable side effect (not just the saved preference) is
        -- applied here directly, mirroring cbMinimap's direct VampifyMinimap.update() call below.
        local cbPerHit = CreateCheckbox(f, "Per-hit debug export",
            function() local cfg = db(); return cfg and cfg.perhitEnabled end,
            function(v)
                local cfg = db()
                if cfg then cfg.perhitEnabled = v end
                if not VampifyPerHit then return end
                if v then
                    if not VampifyPerHit.isEnabled() then VampifyPerHit.enable() end
                elseif VampifyPerHit.isEnabled() then
                    VampifyPerHit.disable(UnitHealth and UnitHealth("player"))
                end
            end)
        place(cbPerHit, -26)
        W.AttachTooltip(cbPerHit, "Writes one line per own hit to imports\\vampify_perhit_*.txt"
            .." for offline analysis (per-source Vampirism factor measurement). On by default.")

        local cbSct = CreateCheckbox(f, "Scrolling combat text",
            function() local cfg = db(); return cfg and cfg.sct and cfg.sct.enabled end,
            function(v)
                local cfg = db()
                if cfg and cfg.sct then cfg.sct.enabled = v end
            end)
        place(cbSct, -26)

        local cbCoalesce = CreateCheckbox(f, "One number per cast (not per hit)",
            function() local cfg = db(); return cfg and cfg.sct and cfg.sct.coalesce end,
            function(v)
                local cfg = db()
                if cfg and cfg.sct then cfg.sct.coalesce = v end
            end)
        place(cbCoalesce, -18)

        local coalesceHint = W.MakeText(f, 9, C.faint, "ARTWORK")
        coalesceHint:SetPoint("TOPLEFT", f, "TOPLEFT", x + 26, y)
        coalesceHint:SetWidth(268)
        coalesceHint:SetJustifyH("LEFT")
        coalesceHint:SetText("An AoE hitting five targets shows its summed return once instead of"
            .. " five times. Totals are unaffected - this only changes what is drawn.")
        y = y - 26

        -- ---- SCT engine (three mutually exclusive modes, VampifyDB.sct.mode) --------------------
        -- Not place()'s usual stacked column: three in a row reads as ONE choice, not three
        -- independent switches. A plain CheckButton has no native radio grouping in 1.12, so
        -- exclusivity is hand-rolled -- each setter writes cfg.sct.mode, then refreshChecks()
        -- resyncs every checkbox in the window from its own getter (checkboxes[] already holds all
        -- of them), which is also what snaps a click back to checked when it tried to uncheck the
        -- currently active mode (there is always exactly one -- "off" is not a fourth option here).
        local engineLabel = W.MakeText(f, 11, C.ink, "ARTWORK")
        place(engineLabel, -18)
        engineLabel:SetText("SCT engine")

        local function setEngineMode(v)
            local cfg = db()
            if cfg and cfg.sct then cfg.sct.mode = v end
            -- Dragging the free anchor only means anything in "own" mode -- leaving move mode
            -- engaged while switching away would leave it silently unreachable from the (now grey)
            -- Move button, so it is force-released the same moment the mode stops being "own".
            if v ~= "own" and VampifySCT and VampifySCT.isMoveMode and VampifySCT.isMoveMode() then
                VampifySCT.setMoveMode(false)
                if btnMove then btnMove.text:SetText("Move") end
            end
            refreshChecks()
            refreshEnabled()
            -- Hangs the anchor immediately instead of waiting for the next SCT emit -- see
            -- gui/sct.lua's S.applyPos/reanchor comments for why a forced, explicit call is needed
            -- here on top of spawn()'s own lazy re-check.
            if VampifySCT and VampifySCT.applyPos then VampifySCT.applyPos() end
        end

        local cbFree = CreateCheckbox(f, "Free anchor",
            function() local cfg = db(); local m = cfg and cfg.sct and cfg.sct.mode
                return m ~= "bar" and m ~= "blizzard" end,
            function(v) if v then setEngineMode("own") else refreshChecks() end end)
        place(cbFree, 0)   -- dy 0: cbBar/cbBlizzard below share this row, y advances once after all three
        W.AttachTooltip(cbFree, "Vampify's own combat text on a draggable anchor you position anywhere.")

        local cbBar = CreateCheckbox(f, "At the bar",
            function() local cfg = db(); return cfg and cfg.sct and cfg.sct.mode == "bar" end,
            function(v) if v then setEngineMode("bar") else refreshChecks() end end)
        cbBar:SetPoint("LEFT", cbFree.vfLabelFS, "RIGHT", 16, 0)
        W.AttachTooltip(cbBar, "Vampify's own combat text, anchored just above the display bar.")

        local cbBlizzard = CreateCheckbox(f, "Blizzard FCT",
            function() local cfg = db(); return cfg and cfg.sct and cfg.sct.mode == "blizzard" end,
            function(v) if v then setEngineMode("blizzard") else refreshChecks() end end)
        cbBlizzard:SetPoint("LEFT", cbBar.vfLabelFS, "RIGHT", 16, 0)
        W.AttachTooltip(cbBlizzard, "Blizzard's own combat text (Blizzard_CombatText) - only the"
            .." colour is ours, position and timing are Blizzard's.")
        y = y - 26

        local engineHint = W.MakeText(f, 9, C.faint, "ARTWORK")
        engineHint:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        engineHint:SetWidth(292)
        engineHint:SetJustifyH("LEFT")
        engineHint:SetText("Free anchor and At the bar both use Vampify's own combat text below;"
            .." Blizzard FCT hands numbers to Blizzard's engine instead.")
        y = y - 24

        -- ---- SCT color -----------------------------------------------------------------------
        swatch = CreateFrame("Button", "VampifyOptionsSctSwatch", f)
        swatch:SetWidth(16)
        swatch:SetHeight(16)
        swatch:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        swatch:SetBackdrop(W.SOLID_BACKDROP)
        swatch:SetBackdropBorderColor(C.goldSoft.r, C.goldSoft.g, C.goldSoft.b, 1)

        local swatchLabel = W.MakeText(f, 11, C.ink, "ARTWORK")
        swatchLabel:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
        swatchLabel:SetText("SCT color")

        -- Applies to both engines (gui/sct.lua and gui/fct.lua) -- never greyed by refreshEnabled().
        swatch:SetScript("OnClick", function()
            local cfg = db()
            if not (cfg and cfg.sct) then return end
            local c = cfg.sct.color

            -- Order matters and is verified against Blizzard 1.12.1 FrameXML (UIDropDownMenu.lua,
            -- FloatingChatFrame.lua): ColorPickerFrame:SetColorRGB() FIRES .func immediately, so
            -- func/opacityFunc/cancelFunc/previousValues must all be assigned BEFORE that call --
            -- otherwise either a stale callback from whichever addon used the picker last fires, or
            -- ours fires against state that is not set up yet. Do not reorder this "for tidiness".
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                c.r, c.g, c.b = r, g, b
                refreshSwatch()
            end
            ColorPickerFrame.hasOpacity = nil       -- no transparency slider needed
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.cancelFunc = function(prevVals)
                if prevVals then c.r, c.g, c.b = prevVals.r, prevVals.g, prevVals.b end
                refreshSwatch()
            end
            ColorPickerFrame.previousValues = { r = c.r, g = c.g, b = c.b }   -- named fields, not an array
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            -- Blizzard's 1.12 colour picker is not draggable out of the box, which is painful when
            -- it lands on top of what you are trying to recolour. Make it movable once, defensively
            -- (another addon may already have done it), and leave it that way -- this is a strict
            -- improvement for every consumer of the frame, not a behaviour change.
            if not ColorPickerFrame.vfMadeMovable then
                ColorPickerFrame.vfMadeMovable = true
                ColorPickerFrame:SetMovable(true)      -- already true in 1.12, but be explicit
                ColorPickerFrame:EnableMouse(true)
                -- The missing piece: 1.12's picker is movable but registers no drag handler, so
                -- nothing ever picks it up. Measured in-game: IsMovable() == 1, yet it would not
                -- budge.
                ColorPickerFrame:RegisterForDrag("LeftButton")
                ColorPickerFrame:SetScript("OnDragStart", function() this:StartMoving() end)
                ColorPickerFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
            end
            -- Raise it above this window explicitly. Measured in-game: the picker sits at strata
            -- MEDIUM, so moving our window down to HIGH was not enough -- HIGH still covers MEDIUM.
            -- A colour picker is modal in spirit; putting it on top is what the user expects, and
            -- it stays correct no matter what strata this window ends up at later.
            ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            ShowUIPanel(ColorPickerFrame)
        end)
        y = y - 26

        -- ---- SCT position ----------------------------------------------------------------------
        posLabel = W.MakeText(f, 11, C.ink, "ARTWORK")
        place(posLabel, -18)
        posLabel:SetText("SCT position")

        btnMove = W.MakeButton(f, "VampifyOptionsSctMove", "Move", 68, 20)
        btnMove:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        btnMove:SetScript("OnClick", function()
            if this.vfDisabled then return end
            if not (VampifySCT and VampifySCT.setMoveMode and VampifySCT.isMoveMode) then return end
            local on = not VampifySCT.isMoveMode()
            VampifySCT.setMoveMode(on)
            this.text:SetText(on and "Done" or "Move")
        end)

        -- No X/Y entry fields. They existed briefly and were removed on sight: after a drag the
        -- stored offsets are raw anchor coordinates (902.75 / -629.99 on a real screen), which
        -- carry no meaning for anyone positioning a frame by eye. Dragging IS the interface here;
        -- a number nobody can reason about is worse than no number.

        -- Demo: tuning colour, size and height is guesswork without numbers on screen, and nobody
        -- wants to pull a mob to check a slider. Fires a burst spread over a few seconds so spacing
        -- and fade are judgeable, not just the colour.
        btnDemo = W.MakeButton(f, "VampifyOptionsSctDemo", "Demo", 56, 20)
        btnDemo:SetPoint("LEFT", btnMove, "RIGHT", 10, 0)
        btnDemo:SetScript("OnClick", function()
            if this.vfDisabled then return end
            if VampifySCT and VampifySCT.demo then VampifySCT.demo(10) end
        end)

        btnPosReset = W.MakeButton(f, "VampifyOptionsSctPosReset", "Reset", 50, 20)
        btnPosReset:SetPoint("LEFT", btnDemo, "RIGHT", 10, 0)
        btnPosReset:SetScript("OnClick", function()
            if this.vfDisabled then return end
            local cfg = db()
            if not (cfg and cfg.sct) then return end
            local d = VampifyConfig.DEFAULTS.sct.pos
            cfg.sct.pos = { point = d.point, x = d.x, y = d.y }
            if VampifySCT and VampifySCT.applyPos then VampifySCT.applyPos() end
            -- (position fields removed; nothing to mirror)
        end)
        y = y - 34

        -- ---- SCT sliders -------------------------------------------------------------------
        -- Replaces the X/Y entry boxes: raw anchor offsets meant nothing to a human, whereas these
        -- two are the values you actually want to tune by eye.
        -- fmt (optional): a string.format pattern for the slider's own value, e.g. "%.1f" for a
        -- fractional-second slider (Fade duration below, step 0.1). Omitted, values print with a
        -- plain tostring -- unchanged behaviour for every integer-step slider that existed before it.
        local function makeSlider(name, label, lo, hi, step, getter, setter, fmt)
            local sl = CreateFrame("Slider", name, f, "OptionsSliderTemplate")
            sl:SetWidth(200)
            sl:SetHeight(16)
            sl:SetMinMaxValues(lo, hi)
            sl:SetValueStep(step)
            sl:SetPoint("TOPLEFT", f, "TOPLEFT", x + 6, y)
            getglobal(name .. "Low"):SetText(fmt and string.format(fmt, lo) or tostring(lo))
            getglobal(name .. "High"):SetText(fmt and string.format(fmt, hi) or tostring(hi))
            local cap = getglobal(name .. "Text")
            W.ApplyFont(cap, 11)
            sl.vfLabel = label
            sl.vfSetter = setter
            sl.vfGetter = getter
            sl.vfStep = step
            sl.vfFmt = fmt
            sl:SetScript("OnValueChanged", function()
                local v = this:GetValue()
                -- OptionsSliderTemplate does not quantise for us in 1.12; round to the slider's own
                -- step by hand. math.floor(v/step+0.5)*step generalises the old "nearest integer"
                -- rounding (which was step-1-only, hardcoded) to the fractional step a duration-in-
                -- seconds slider needs (0.1) -- and is a no-op for every existing step-1 slider.
                v = math.floor(v / this.vfStep + 0.5) * this.vfStep
                -- Round-trip a fractional value through its own format string (e.g. "%.1f") before
                -- storing it. The multiply above leaves binary-float noise (1.2000000000000002),
                -- which would both write an ugly value into SavedVariables and never compare equal
                -- to the plain decimal literal a getter's own fallback or a test uses -- the
                -- round-trip snaps it back to the canonical double for "1.2". No-op for integer
                -- sliders (fmt is nil there).
                local txt = this.vfFmt and string.format(this.vfFmt, v) or tostring(v)
                if this.vfFmt then v = tonumber(txt) end
                this.vfSetter(v)
                getglobal(this:GetName() .. "Text"):SetText(this.vfLabel .. ": " .. txt)
            end)
            y = y - 42
            return sl
        end

        sliderFont = makeSlider("VampifyOptionsFontSlider", "Font size", 8, 48, 1,
            function()
                local cfg = db()
                return (cfg and cfg.sct and cfg.sct.fontSize) or 16
            end,
            function(v)
                local cfg = db()
                if not (cfg and cfg.sct) then return end
                cfg.sct.fontSize = v
                if VampifySCT and VampifySCT.applyFont then VampifySCT.applyFont() end
            end)

        sliderRise = makeSlider("VampifyOptionsRiseSlider", "SCT height", 20, 320, 5,
            function()
                local cfg = db()
                return (cfg and cfg.sct and cfg.sct.rise) or 40
            end,
            function(v)
                local cfg = db()
                if not (cfg and cfg.sct) then return end
                cfg.sct.rise = v
            end)

        -- Fade duration -- how long a number stays on screen (gui/sct.lua's S.spawn does
        -- "s.dur = sct.duration or DUR_FALLBACK" fresh on every spawn, not cached, so no applyX
        -- entry point is needed here: the very next number picks up a changed value on its own,
        -- same as the rise slider above.
        sliderDuration = makeSlider("VampifyOptionsDurationSlider", "Fade duration", 0.5, 4.0, 0.1,
            function()
                local cfg = db()
                return (cfg and cfg.sct and cfg.sct.duration) or 1.5
            end,
            function(v)
                local cfg = db()
                if not (cfg and cfg.sct) then return end
                cfg.sct.duration = v
            end,
            "%.1f")
        W.AttachTooltip(sliderDuration, "How long a Vampify combat-text number stays on screen"
            .. " before fading out, in seconds.")

        -- Text effect. Cycles rather than three radio buttons: it is one setting with three steps,
        -- and the label always states the current one, so nothing is hidden behind a menu.
        local OUTLINES = { "THICKOUTLINE", "OUTLINE", "" }
        local OUTLINE_LABEL = { THICKOUTLINE = "Thick", OUTLINE = "Thin", [""] = "None" }
        local function outlineText()
            local cfg = db()
            local cur = (cfg and cfg.sct and cfg.sct.outline) or "THICKOUTLINE"
            return "Outline: " .. (OUTLINE_LABEL[cur] or "Thick")
        end
        btnOutline = W.MakeButton(f, "VampifyOptionsOutline", outlineText(), 120, 20)
        btnOutline:SetPoint("TOPLEFT", f, "TOPLEFT", x + 6, y)
        btnOutline:SetScript("OnClick", function()
            if this.vfDisabled then return end
            local cfg = db()
            if not (cfg and cfg.sct) then return end
            local cur = cfg.sct.outline or "THICKOUTLINE"
            local nxt = OUTLINES[1]
            for i = 1, table.getn(OUTLINES) do
                if OUTLINES[i] == cur then nxt = OUTLINES[math.mod(i, table.getn(OUTLINES)) + 1] end
            end
            cfg.sct.outline = nxt
            this.text:SetText(outlineText())
            if VampifySCT and VampifySCT.applyFont then VampifySCT.applyFont() end
            if VampifySCT and VampifySCT.demo then VampifySCT.demo(4) end   -- show the change at once
        end)
        O.refreshOutlineLabel = function()
            if btnOutline then btnOutline.text:SetText(outlineText()) end
        end
        y = y - 28

        -- Text shadow -- the other half of "readable over anything" alongside the outline above.
        -- Getter mirrors gui/sct.lua's own shadowOn(): default ON, an EXPLICIT false is what turns
        -- it off (a missing/unmigrated key must not read as off). applyFont() re-stamps every
        -- pooled FontString immediately, same as the outline cycle button above -- otherwise
        -- already-spawned slots would keep the old shadow state until the pool cycled.
        local cbShadow = CreateCheckbox(f, "Text shadow",
            function()
                local cfg = db()
                local sct = cfg and cfg.sct
                if sct and sct.shadow == false then return false end
                return true
            end,
            function(v)
                local cfg = db()
                if cfg and cfg.sct then cfg.sct.shadow = v end
                if VampifySCT and VampifySCT.applyFont then VampifySCT.applyFont() end
            end)
        place(cbShadow, -26)
        W.AttachTooltip(cbShadow, "Drops a shadow behind Vampify's own combat-text numbers, for"
            .. " readability over bright backgrounds. On by default.")

        -- ---- display size (2026-08-25, feature request: "two more sliders in the options that
        -- determine the height of the bar and the detail bars") -----------------------------------
        -- Two sliders, same makeSlider() recipe as the SCT ones above, driving VampifyDisplay's own
        -- PILL_H/BAR_H (compact-bar capsule) and ROW_H/SPLIT_ROW_H/DETAIL_LINE_H (breakdown-panel
        -- bars) -- see gui/display.lua's own comments on V.PILL_H_MIN/MAX and
        -- V.PANEL_BAR_H_MIN/MAX for exactly why those two ranges were chosen (the readable-text
        -- floor and the "too fat" ceiling it was named after). Bounds are read from VampifyDisplay itself
        -- rather than copied here a second time, so the two files cannot silently drift apart.
        -- Setters write the SavedVariables field AND call the matching VampifyDisplay.apply* entry
        -- point immediately -- same split the SCT sliders above already use (VampifySCT.applyFont/
        -- applyPos): this file owns persistence, gui/display.lua owns making the change visible with
        -- no /reload.
        local sizeLabel = W.MakeText(f, 11, C.ink, "ARTWORK")
        place(sizeLabel, -18)
        sizeLabel:SetText("Display size")

        sliderPillH = makeSlider("VampifyOptionsPillHeightSlider", "Bar height",
            (VampifyDisplay and VampifyDisplay.PILL_H_MIN) or 8,
            (VampifyDisplay and VampifyDisplay.PILL_H_MAX) or 40, 1,
            function()
                local cfg = db()
                return (cfg and cfg.pillHeight)
                    or (VampifyDisplay and VampifyDisplay.PILL_H_DEFAULT) or 10
            end,
            function(v)
                local cfg = db()
                if cfg then cfg.pillHeight = v end
                if VampifyDisplay and VampifyDisplay.applyPillHeight then
                    VampifyDisplay.applyPillHeight(v)
                end
            end)
        W.AttachTooltip(sliderPillH, "Height of the compact bar's capsule (the ST/AoE ratio pill)."
            .. " The bar itself and its drag-resize grip follow automatically.")

        sliderPanelBarH = makeSlider("VampifyOptionsPanelBarHeightSlider", "Detail bar height",
            (VampifyDisplay and VampifyDisplay.PANEL_BAR_H_MIN) or 10,
            (VampifyDisplay and VampifyDisplay.PANEL_BAR_H_MAX) or 40, 1,
            function()
                local cfg = db()
                return (cfg and cfg.panelBarHeight)
                    or (VampifyDisplay and VampifyDisplay.PANEL_BAR_H_DEFAULT) or 18
            end,
            function(v)
                local cfg = db()
                if cfg then cfg.panelBarHeight = v end
                if VampifyDisplay and VampifyDisplay.applyPanelBarHeight then
                    VampifyDisplay.applyPanelBarHeight(v)
                end
            end)
        W.AttachTooltip(sliderPanelBarH, "Height of the ability/split bars in the hover breakdown"
            .. " panel, and (scaled with them) the row-detail panel's own line height.")

        -- divider
        local divider = f:CreateTexture("VampifyOptionsDivider", "ARTWORK")
        divider:SetHeight(1)
        divider:SetWidth(292)
        divider:SetTexture(C.line.r, C.line.g, C.line.b)
        divider:SetPoint("TOPLEFT", f, "TOPLEFT", x, y - 4)
        y = y - 16

        -- ---- buttons ------------------------------------------------------------------------
        local btnReset = W.MakeButton(f, "VampifyOptionsResetTotals", "Reset totals", 138, 22)
        btnReset:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        -- Goes through the one reset path rather than repeating it. Reassigning VampifyState here
        -- would ORPHAN the per-spell tables: since persistence landed they point INTO
        -- VampifyCharDB, so a fresh state would keep recording to tables nothing saves, silently,
        -- until the next reload re-wired them. VampifyResetSession clears in place for exactly
        -- that reason. Scope is "session" -- a button labelled "Reset totals" must not wipe the
        -- lifetime set, which has to be asked for by name.
        btnReset:SetScript("OnClick", function()
            if VampifyResetSession then VampifyResetSession("session") end
            refreshInfo()
        end)

        local btnPos = W.MakeButton(f, "VampifyOptionsResetPos", "Reset position", 138, 22)
        btnPos:SetPoint("TOPLEFT", f, "TOPLEFT", x + 154, y)
        btnPos:SetScript("OnClick", function() VampifyDisplay.resetPos() end)
        y = y - 32

        -- divider before the info panel
        local divider2 = f:CreateTexture("VampifyOptionsDivider2", "ARTWORK")
        divider2:SetHeight(1)
        divider2:SetWidth(292)
        divider2:SetTexture(C.line.r, C.line.g, C.line.b)
        divider2:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        y = y - 12

        -- ---- info panel -----------------------------------------------------------------------
        infoFS = W.MakeText(f, 10, C.ink, "ARTWORK")
        infoFS:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        infoFS:SetWidth(292)
        infoFS:SetJustifyH("LEFT")
        infoFS:SetJustifyV("TOP")

        f:SetScript("OnShow", function()
            refreshChecks()
            refreshInfo()
            refreshSwatch()
            refreshSliders()
            if O.refreshOutlineLabel then O.refreshOutlineLabel() end
            refreshEnabled()
            if btnMove then
                local on = VampifySCT and VampifySCT.isMoveMode and VampifySCT.isMoveMode()
                btnMove.text:SetText(on and "Done" or "Move")
            end
            elapsed = 0
        end)

        -- Refreshed only while shown: a hidden frame never receives OnUpdate in 1.12, so this is
        -- naturally free at rest without an extra IsShown() guard. The swatch rides along on the
        -- same 0.5s tick. The sliders deliberately do NOT -- they are only pushed on OnShow, since
        -- writing to a slider fires OnValueChanged and would fight the user mid-drag.
        f:SetScript("OnUpdate", function()
            elapsed = elapsed + arg1
            if elapsed < 0.5 then return end
            elapsed = 0
            refreshInfo()
            -- (position fields removed; nothing to mirror)
        end)

        table.insert(UISpecialFrames, "VampifyOptionsFrame")

        frame = f
        f:Hide()
        return f
    end

    function O.toggle()
        local f = build()
        if f:IsShown() then f:Hide() else f:Show() end
    end
end
