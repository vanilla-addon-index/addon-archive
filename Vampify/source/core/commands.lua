-- Vampify -- wiring and slash commands.
--
-- This file is the only place where the pure core meets the WoW-bound capture layer. Everything it
-- does is glue; if you are looking for behaviour, it is in model.lua (the formula) or detect.lua
-- (the sources).

VampifyState = VampifyAggregate.new()
-- The aggregate tracks totals; VampifyState.acc tracks a running sum of the SAME per-hit integers,
-- kept separately so the retroactive AoE correction (below) has one place to apply its delta and
-- core/watch.lua's I3 has something to check the emitted total against (see core/model.lua's
-- header for why this is a plain sum now, not a fractional carry).
VampifyState.acc     = VampifyModel.newAcc()
VampifyState.effHeal = 0
-- The DISTRIBUTION of triggering hits (core/histogram.lua), session and lifetime, alongside the
-- totals above. A total cannot answer "what would one more Vampirism source be worth" -- the floor
-- makes healing non-linear in damage, so the answer depends on how the damage was split across
-- hits, not just on how much of it there was. Created here like the accumulator; wireSession below
-- REPOINTS both at VampifyCharDB sub-tables, exactly as it does for the per-spell tables, so a
-- recorded hit is already a persisted write.
VampifyState.hist    = VampifyHistogram.new()
VampifyState.lfHist  = VampifyHistogram.new()

local sumPercent, nSources = 0, 0
-- The REAL per-source percent list (e.g. {3, 2, 2, 2}), rebuilt by recompute() below alongside
-- sumPercent/nSources. This -- not the summed sumPercent -- is what feeds the model now
-- (core/model.lua's M.healPerSources): the server truncates each source independently, and a
-- summed percentage cannot be truncated back into that after the fact (see model.lua's header).
-- sumPercent/nSources remain for the places that only ever wanted the aggregate (the status line,
-- the options info panel, I4's epoch comparison, /vf source add's zero-percent guard) -- they are
-- still meaningful numbers, just no longer the model's own input.
local sourcePercents = {}
-- Same table, reachable from gui/display.lua (follow-up change request, 2026-08-22, compact bar). Assigned
-- ONCE, here: recompute() below refills sourcePercents in place via VampifyConst.resetList (never
-- replaces the table), so this reference stays valid for the addon's whole lifetime and the bar
-- always sees the current source set without commands.lua having to push updates anywhere.
VampifyState.sourcePercents = sourcePercents
-- Parallel to sourcePercents (SAME indices, rebuilt alongside it in recompute() below): the STABLE
-- identity + human label core/aggregate.lua's A.recordSourceBreakdown needs per source, since the
-- index into sourcePercents itself is not stable across a gear change (see A.sourceKey's own
-- comment for why). meta[i] = { key = A.sourceKey(...), label = A.sourceLabel(...) }.
local sourceMeta = {}
-- Module-local scratch pad for the per-hit source breakdown (core/model.lua's M.healBreakdown),
-- reused across every damage event -- the hot path below must not allocate.
local breakdownBuf = {}

-- The player's CURRENT target's GUID, read FRESH at the moment a hit lands -- feeds the ST/AoE
-- split below (2026-08-24, redefined: ST = healing from hits on the current target,
-- INCLUDING an AoE spell's own share of a hit on that one target; AoE = everything else, and a hit
-- with no current target equipped at all counts entirely as AoE by explicit ruling -- there
-- is then no "current target" for a ST figure to describe). Deliberately NOT cached across hits:
-- the comparison has to use whatever target was current AT THE MOMENT THIS HIT LANDED, and a mid-
-- fight target switch must not retroactively move an already-recorded hit from one bucket to the
-- other -- reading fresh every time is what guarantees that by construction, no invalidation logic
-- needed.
--
-- Same SuperWoW pattern capture/incoming.lua already uses for the PLAYER's own GUID
-- (`local _, gg = UnitExists("player")`, that file's readGuid): UnitExists returns the unit's GUID
-- as a second value under SuperWoW. pcall-wrapped for the same reason -- without SuperWoW,
-- UnitExists returns only one value, and the second read must not error, it must just come back
-- nil, which this function then reads (correctly) as "no known current target".
local function currentTargetGuid()
    local g
    pcall(function() local _, gg = UnitExists("target"); g = gg end)
    return g
end
-- Bumped whenever the detected source set changes; a fight remembers the epoch it began in, so a
-- gear swap mid-fight becomes visible as a mismatch (watchdog I4) instead of quietly mixing two
-- figures into one percentage. Declared here rather than beside the rest of the watchdog state
-- because recompute() below already needs it.
local sourceEpoch, fightEpoch = 0, 0
-- Watchdog counters for I3 (shown integers vs. the accumulator). Declared up here, ABOVE
-- VampifyResetSession, because that function has to clear them together with the accumulator --
-- it zeroed the accumulator alone, the counters kept running, and the check then reported a gap
-- that was real: after a reset the two no longer described the same span. Found in the field by
-- the check itself.
--
-- aoeCorrectedShown is the number of INTEGERS the retroactive AoE corrections took off the
-- accumulator, counted where they were applied. It is deliberately not the sum of the float deltas:
-- see the correction listener below for why that sum cannot be used to reconstruct what was shown.
local emittedFight, aoeCorrectedShown = 0, 0

-- spellId -> the time its last CREDITED hit was recorded. Read by the retroactive AoE correction
-- below, which may only take healing back out of a row it actually put in. The correction cannot
-- work that out for itself: by the time it runs, the reason the hit was dropped is gone (no source
-- set committed yet, the spell excluded since, a reset in between), so the damage listener records
-- the fact instead. Keyed by spell id, i.e. bounded by the spellbook plus a handful of item procs
-- -- the same bound that lets the coalescing buckets below skip an eviction sweep.
--
-- Declared up here, like the counters above, because VampifyResetSession has to clear it: a reset
-- empties the rows, so nothing recorded before it may be corrected after it.
local creditedAt = {}

local function print_(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r "..msg) end
end

-- ---- visibility --------------------------------------------------------------------------------
--
-- Three different questions, and conflating them is what made a hide unstick:
--   * nSources > 0    a capability. With nothing equipped there is no number, whatever anyone wants.
--   * cfg.shown       the user's PREFERENCE (minimap button, "Show display" checkbox).
--   * inertWarned     the addon's own refusal to show a number it does not trust (see the OnUpdate
--                     verdict below). Not a preference either -- it must outlive a loading screen.
-- Everything that used to call VampifyDisplay.show()/hide() on its own account goes through here,
-- so no automatic path can quietly overrule any of the three. Before this, recompute() ended in an
-- unconditional show() and ran on every zone, boat, instance and gear change: a hidden bar came
-- back after every portal, and so did a bar the inert verdict had hidden on purpose -- with the
-- verdict's latch still closed, so the diagnosis could not even be repeated.
local inertWarned = false

local function applyVisibility()
    -- cfg is nil until the ADDON_LOADED migration runs; default to shown, as the schema does.
    local cfg = VampifyConfig.get()
    if nSources > 0 and not inertWarned and (not cfg or cfg.shown) then
        VampifyDisplay.show()
    else
        VampifyDisplay.hide()
    end
end

-- ---- source set ------------------------------------------------------------------------------

local function recompute()
    local sources = VampifyDetect.getSources()
    local sum, n = VampifyDetect.summarise(sources)

    -- The real per-source percent list, rebuilt fresh here alongside the aggregate above. Read
    -- straight from sources[i].percent -- VampifyDetect already carries the individual values, it
    -- was only ever summarise() that collapsed them. resetList (not a bare {}), like every other
    -- reused list buffer in this addon: table.insert's stale `n` would otherwise show through the
    -- next rebuild (see VampifyConst.resetList's own comment).
    VampifyConst.resetList(sourcePercents)
    VampifyConst.resetList(sourceMeta)
    for i = 1, table.getn(sources) do
        table.insert(sourcePercents, sources[i].percent)
        table.insert(sourceMeta, {
            key   = VampifyAggregate.sourceKey(sources[i].slot, sources[i].kind),
            label = VampifyAggregate.sourceLabel(sources[i].slot, sources[i].percent),
        })
    end

    -- Manual overrides exist as a fallback for the day the tooltip wording changes. They add to
    -- the detected set rather than replacing it -- in BOTH the aggregate and the per-source list,
    -- so the model and the status line never disagree about what a manual source contributed.
    --
    -- Identity for a manual entry: its APPEND index into cfg.manual, not a slot (capture/detect.lua
    -- never gives a manual override one). Weaker than a real slot -- see core/aggregate.lua's own
    -- comment on A.sourceKey -- but cfg.manual only ever grows (table.insert, /vf source add) or is
    -- wiped whole (cfg.manual = {}, /vf source clear), never reordered or spliced, so the index is
    -- stable for as long as the manual list itself is not cleared.
    local cfg = VampifyConfig.getChar()
    if cfg and cfg.manual then
        for i = 1, table.getn(cfg.manual) do
            sum = sum + (cfg.manual[i] / 100)
            n = n + 1
            table.insert(sourcePercents, cfg.manual[i])
            table.insert(sourceMeta, {
                key   = "manual:" .. i,
                label = "Manual +" .. cfg.manual[i] .. "%",
            })
        end
    end

    -- A CHANGE of the source set opens a new epoch. Compared before assigning, and only on a real
    -- difference: recompute runs on every inventory event, and bumping unconditionally would make
    -- every fight look like it straddled a gear swap.
    if sum ~= sumPercent or n ~= nSources then
        sourceEpoch = sourceEpoch + 1
    end
    sumPercent, nSources = sum, n
    applyVisibility()
end

if VampifyDetect.onChange then VampifyDetect.onChange(recompute) end

-- Single dispatch point between the two SCT engines: gui/sct.lua (mode "own" or "bar", positionable
-- and fully colored -- "bar" is the same engine anchored to the display bar instead of a free
-- position, gui/sct.lua's own concern) and gui/fct.lua (mode "blizzard", Blizzard_CombatText --
-- position/timing are Blizzard's, only the color is ours). Everything but "blizzard" falls through
-- to VampifySCT.emit unchanged, so this dispatch needed no edit to support "bar". Everything
-- upstream of this just calls emitSct(); nothing else in the file needs to know which engine is live.
local function emitSct(amount, isOverheal, isCrit)
    local cfg = VampifyConfig.get()
    local mode = cfg and cfg.sct and cfg.sct.mode
    if mode == "blizzard" then
        -- Blizzard's engine has no overheal styling of its own (no parentheses/dimming channel);
        -- an overheal number rides through it looking like a real heal. Degraded, not wrong.
        VampifyFct.emit(amount, isCrit)
    else
        VampifySCT.emit(amount, isOverheal, isCrit)
    end
end

-- One reset, used by both /vf reset and the bar's reset icon. A second copy would drift: the bar
-- button would forget the accumulator or the per-spell breakdown the day one of them is added.
--
-- scope: "session" (default), "lifetime", or "both". VampifyState is never REPLACED here (the old
-- `VampifyState = VampifyAggregate.new()` behaviour) -- its per-spell tables may be pointing at a
-- SavedVariables sub-table (see wireSession below), and reassigning the whole state would silently
-- orphan that table instead of clearing it. Every branch below clears fields on the SAME object,
-- via VampifyAggregate helpers that themselves clear in place.
--
-- The default is "session" ON PURPOSE, even though the old unscoped behaviour cleared everything
-- there was to clear at the time. That is no longer true now that a lifetime set exists: a
-- destructive default would make existing "/vf reset" muscle memory silently wipe totals meant to
-- survive forever. The more destructive scopes ("lifetime", "both") must be asked for by name.
--
-- "last" (2026-08-25, third detail tab): unlike session/lifetime/both, this scope clears ONLY
-- VampifyAggregate's last-fight tables (via A.resetScope("last")) -- there is no watchdog
-- accumulator, histogram or emittedFight counter tied to that scope to clear alongside it (those
-- all belong to the fHeal/fDmg fight-scalar lifecycle, which A.startFight already resets on its own
-- at the next fight boundary; see A.startFight's own comment). Not folded into "both": "both" is the
-- existing, load-bearing session+lifetime combination every call site above already relies on, and
-- adding a third bucket to it would silently make "both" more destructive for every existing caller.
--
-- The session/lifetime branches below now DELEGATE their aggregate-level clearing to
-- VampifyAggregate.resetScope (2026-08-25) instead of calling A.resetTotals/resetSpells/
-- resetLifetime directly -- same two calls, same order, so this is not a behaviour change, just one
-- fewer place that has to agree on what "reset this scope" means at the aggregate level. Everything
-- below the delegation (accumulator, histogram, watchdog counters, creditedAt) is watchdog/telemetry
-- state that lives in THIS file, not in core/aggregate.lua, and stays here.
function VampifyResetSession(scope)
    scope = scope or "session"
    if scope == "session" or scope == "both" then
        VampifyAggregate.resetScope("session")
        VampifyState.acc = VampifyModel.newAcc()
        VampifyState.effHeal = 0
        -- Must move with the totals for the same reason the accumulator does: the histogram and
        -- the session total have to describe the SAME span, or the upgrade preview computed from
        -- one would be compared against the other. Cleared in place -- it may be the persisted
        -- table (see wireSession below).
        VampifyHistogram.reset(VampifyState.hist)
        -- Must move with the accumulator: I3 compares the two, and a reset that touches only one
        -- of them makes every later comparison meaningless.
        emittedFight, aoeCorrectedShown = 0, 0
        -- Same reasoning one level down: the rows this reset just emptied must not be corrected by
        -- a derive window that is still in flight. Cleared in place, not replaced -- the correction
        -- listener holds this table as an upvalue.
        for k in pairs(creditedAt) do creditedAt[k] = nil end
    end
    if scope == "lifetime" or scope == "both" then
        VampifyAggregate.resetScope("lifetime")
        VampifyHistogram.reset(VampifyState.lfHist)
    end
    if scope == "last" then
        VampifyAggregate.resetScope("last")
    end
    if DEFAULT_CHAT_FRAME then
        if scope == "both" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r session and lifetime totals reset.")
        elseif scope == "lifetime" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r lifetime total reset.")
        elseif scope == "last" then
            DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r last-fight breakdown reset.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffVampify|r session reset.")
        end
    end
end

-- ---- per-cast coalescing -----------------------------------------------------------------------
--
-- One AoE cast on five targets is five damage events, and therefore five floating numbers. With
-- sct.coalesce on, the numbers of a single cast are summed and shown ONCE -- "on cast" instead of
-- "on hit". Only the DISPLAY changes: the model still runs per hit, so totals, HPS and the carry
-- accumulator are bit-for-bit identical either way.
--
-- Keyed by spellId, which is what identifies a cast; auto attacks carry no spellId and are never
-- coalesced. The bucket table is bounded by the player's spellbook, not by mob GUIDs, so it needs
-- no eviction sweep.
local pendHeal, pendOver, pendAt, pendCrit = {}, {}, {}, {}
local COALESCE_WINDOW = 0.35     -- a cast's damage events all land well inside this

local function coalesceOn()
    local cfg = VampifyConfig.get()
    return cfg and cfg.sct and cfg.sct.coalesce and true or false
end

-- Emits every bucket whose cast has gone quiet. Driven from the 0.25s display throttle, so a cast
-- shows up about a third of a second late -- imperceptible next to the 1.5s the number floats for.
local function flushCoalesced(now, force)
    -- Clearing keys during a pairs() traversal is defined behaviour in Lua (only ADDING keys mid-
    -- traversal is not), so emptying a bucket in place here is safe.
    for spell, at in pairs(pendAt) do
        if force or (now - at) >= COALESCE_WINDOW then
            local h, o, c = pendHeal[spell] or 0, pendOver[spell] or 0, pendCrit[spell]
            pendHeal[spell], pendOver[spell], pendAt[spell], pendCrit[spell] = nil, nil, nil, nil
            if h > 0 then emitSct(h, false, c) end
            if o > 0 then emitSct(o, true, c) end
        end
    end
end

-- ---- the damage path -------------------------------------------------------------------------

local function beginFight(now)
    VampifyAggregate.startFight(VampifyState, now)
    -- The carry restarts per fight. Whether the server does the same is UNKNOWN -- this is a
    -- choice, not a measurement. It bounds any resulting error to under 1 HP per fight, and the
    -- session total is unaffected because the aggregate sums the float heal, not the increments.
    VampifyState.acc = VampifyModel.newAcc()
    VampifyState.effHeal = 0
    -- The watchdog's I3 compares displayed integers against the accumulator, and the accumulator
    -- restarts here -- so the counter it is compared against has to restart with it.
    emittedFight = 0
    aoeCorrectedShown = 0
    fightEpoch = sourceEpoch
end

-- ---- the watchdog ------------------------------------------------------------------------------
--
-- Stage 1 (invariants) runs on a slow timer over our own numbers. Stage 2 (the HP reconciliation)
-- closes one window per own hit: the window opened by the PREVIOUS hit, because the healing that
-- hit caused needs time to reach the health bar. Neither ever writes a number into the display --
-- both are alarms (spec 2.1).
local balance = VampifyWatch.newBalance()
local findings = {}
local lastHp, lastAt, lastExpected = nil, nil, nil
local nextCheck = 0
local WATCH_INTERVAL = 15          -- slow on purpose: findings are read by a human, not a loop

-- ---- the zone, for the per-hit export ---------------------------------------------------------
--
-- Cached rather than read per hit. GetRealZoneText() is cheap but it RETURNS A STRING, and a
-- string per damage event is exactly the per-frame allocation this project forbids in hot paths
-- (30-60 hits/sec during an AoE pull). The zone changes on a loading screen and nowhere else, so
-- it is refreshed from the two events that already fire there.
--
-- WHY IT IS RECORDED AT ALL: an offline analysis could not answer "use only the Shadowfang Keep
-- data" -- the export had no way to tell one grinding session's zone from another's, and mob
-- level (and therefore hit size, and therefore how often the per-source floor of 1 dominates the
-- percentage) varies enormously between them. See docs/VAMPIRISM-MODELL-STAND §4.
--
-- Pipes are stripped because "|" is this format's field separator; no real zone name contains one,
-- but a parser that splits on "|" must not be able to be broken by a name at all.
local zoneName = "?"
local function refreshZone()
    local z = GetRealZoneText and GetRealZoneText()
    if not z or z == "" then z = GetZoneText and GetZoneText() end
    if not z or z == "" then zoneName = "?" return end
    zoneName = string.gsub(z, "|", "")
end

-- print_ already prefixes "Vampify", so this must not repeat it -- the first field build did, and
-- the result read "Vampify Vampify watch:".
--
-- The file half is a ROLLING LOG, not a single line. ExportFile overwrites -- it has no append
-- mode -- so handing it one bare finding erased the previous one, and the file ended up holding
-- whichever finding happened to fire last while the earlier (often more serious) one left no trace
-- on disk at all. Same discipline as the error capture in core/const.lua, which this comment used
-- to claim without doing: rebuild the whole text on every write, with a self-identifying header.
-- Bounded so a flapping finding cannot grow it without limit.
local watchLog, WATCH_LOG_MAX = {}, 50

local function watchLine(text)
    print_("|cffffcc00watchdog:|r " .. text)
    if not ExportFile then return end          -- SuperWoW only; harmless without it
    local stamp = date and date("%H:%M:%S") or string.format("%.1f", GetTime and GetTime() or 0)
    table.insert(watchLog, "[" .. stamp .. "] " .. text)
    -- table.remove, not a hand-rolled shift: it keeps `n` in step, which table.getn reads.
    while table.getn(watchLog) > WATCH_LOG_MAX do table.remove(watchLog, 1) end
    ExportFile("vampify_watch", "addon=Vampify version=" .. tostring(VampifyConst.VERSION)
                                .. "\n" .. table.concat(watchLog, "\n"))
end

-- Written for someone reading their chat frame mid-fight, not for whoever wrote the check. Each
-- line says what is inconsistent and what it means for the number on screen -- a finding nobody can
-- act on is noise, and noise trains you to ignore the next one.
local function describe(f)
    if f.id == "I1" then
        return string.format("the per-ability rows add up to %.0f but the session total says %.0f "
                             .. "-- one of the two is wrong", f.a, f.b)
    elseif f.id == "I2" then
        return string.format("%s shows more overhealing than healing -- the split is broken",
                             VampifyConst.spellName(f.spell))
    elseif f.id == "I3" then
        return string.format("the floating numbers add up to %d but the running total is at %d "
                             .. "-- some were shown twice or not at all", f.a, f.b)
    elseif f.id == "I4" then
        return "your gear changed during this fight -- its percentage mixes two different setups"
    elseif f.id == "I5" then
        return "you are hitting several targets but the client never reported the area-damage "
               .. "event, so the 30% reduction cannot be applied -- the total reads HIGH"
    elseif f.id == "H1" then
        return string.format("over %d checks only %.0f%% of the healing credited here actually "
                             .. "reached your health bar -- something in the breakdown may not "
                             .. "return any healing at all", f.windows, f.ratio * 100)
    elseif f.id == "H2" then
        return string.format("over %d checks %.0f%% more healing arrived than this addon can "
                             .. "explain -- a source is being missed", f.windows, f.ratio * 100)
    elseif f.id == "H3" then
        return "self-check failed: incoming damage is not being read correctly, so the two checks "
               .. "above cannot be trusted and are being withheld"
    end
    return f.id
end

-- Whether multi-target damage was ever seen. Set by the AoE derivation rather than by
-- SPELL_GO_SELF -- if the cast event were arriving, there would be nothing for I5 to warn about.
-- (emittedFight and aoeCorrectedShown are declared further up, next to the reset that has to clear
-- them.)
local multiTargetSeen = false

local watcher = VampifyWatch.new()
local watchCtx = { rows = nil, rowCount = 0 }
local rowBuf = {}
-- The stage-2 verdicts carry no isNew of their own -- they are computed from the running sums, so
-- they would repeat on every interval once they fire. Reported once per session instead.
local reportedOnce = {}

-- The control comes FIRST and suppresses the verdicts: if the two branches disagree, the reading of
-- incoming damage is wrong, and an H1/H2 built on it would be a confident wrong answer -- which is
-- worse than none. This is the lesson two earlier analyses paid for.
local function runWatch()
    watchCtx.rows           = VampifyAggregate.spellBreakdown(VampifyState, rowBuf)
    watchCtx.rowCount       = table.getn(rowBuf)
    watchCtx.sessionHeal    = VampifyState.sHeal
    watchCtx.emitted        = emittedFight
    watchCtx.accTotal       = VampifyState.acc and VampifyState.acc.total or 0
    watchCtx.correctedShown = aoeCorrectedShown
    -- I4 only means anything WHILE a fight is running. Out of combat, changing gear is the normal
    -- thing to do, and the fight epoch keeps its last value -- so comparing the two outside a fight
    -- reports every single swap, forever, and no reset clears it because the epochs are not what a
    -- reset touches. Reported in the field within minutes of shipping.
    if VampifyState.fActive then
        watchCtx.fightEpoch  = fightEpoch
        watchCtx.sourceEpoch = sourceEpoch
    else
        watchCtx.fightEpoch, watchCtx.sourceEpoch = nil, nil
    end
    watchCtx.aoeAvailable    = VampifyDamage.aoeAvailable()
    watchCtx.multiTargetSeen = multiTargetSeen

    local n = VampifyWatch.check(watcher, watchCtx, findings)
    local flag = nil
    for i = 1, n do
        local d = describe(findings[i])
        if findings[i].isNew then watchLine(d) end
        -- The marker shows the FIRST finding: they are emitted in check order, and I1 (the totals
        -- disagreeing) is the one that makes every other number suspect.
        if not flag then flag = d end
    end
    -- Cleared on a clean pass, so the marker tracks the current state rather than the worst thing
    -- that ever happened. Chat says it once; the marker says whether it is still true.
    if VampifyDisplay.setWatchFlag then VampifyDisplay.setWatchFlag(flag) end

    local control = VampifyWatch.crossCheck(balance, 30, 0.25)
    if control then
        if not reportedOnce[control.id] then
            reportedOnce[control.id] = true
            watchLine(describe(control))
        end
        return                      -- verdicts built on a failed control are not reported at all
    end
    local verdict = VampifyWatch.alarm(balance, 30, 0.25)
    if verdict and not reportedOnce[verdict.id] then
        reportedOnce[verdict.id] = true
        watchLine(describe(verdict))
    end
end

if VampifyDamage.onDamage then
    VampifyDamage.onDamage(function(amount, isAoE, targetGuid, spellId, isCrit)
        -- Dormant: with no sources there is no work and no allocation.
        if nSources <= 0 then return end

        -- Damage that cannot trigger Vampirism is dropped ENTIRELY -- not just its healing. Its
        -- damage would otherwise sit in the denominator of every percentage and drag the headline
        -- number below the truth. See VampifyConst.NO_TRIGGER.
        if not VampifyConst.triggersVampirism(spellId) then return end

        -- A damage event outside an active fight means the fight boundary was missed -- a /reload
        -- mid-combat, or a packet arriving after PLAYER_REGEN_ENABLED. Start a fight rather than
        -- adding to the previous one, which would silently inflate a total already shown as final.
        if not VampifyState.fActive then beginFight(GetTime()) end

        -- sourcePercents, not sumPercent/nSources: the server truncates each source
        -- INDEPENDENTLY (core/model.lua's header), so the real per-source list is what the model
        -- needs now. inc and healFloat are the SAME number always (see M.add's own comment) --
        -- kept as two names because everything below still reads them as two different things.
        local inc, healFloat = VampifyModel.add(VampifyState.acc, amount, sourcePercents, isAoE)

        -- The per-source breakdown of the SAME hit, for the UI's "item X contributed Y to THIS
        -- spell" question (core/aggregate.lua's A.spellSourceBreakdown). Deliberately a SEPARATE
        -- call rather than a change to M.add's return shape above: M.add's arithmetic (and
        -- therefore VampifyState.acc.total / spHeal) must stay bit-for-bit what it already is, and
        -- computing the breakdown here cannot perturb that -- it only reads sourcePercents/factor a
        -- second time into a scratch buffer. Same factor logic as M.add uses internally (core/
        -- model.lua) and the retroactive AoE correction below duplicates for the same reason: the
        -- arithmetic itself lives in exactly one place (M.healBreakdown), so a second caller
        -- deriving the same factor is not a second copy of the truncation logic.
        local aoeFactor = 1
        if isAoE then aoeFactor = VampifyConst.FORMULA.aoeFactor end
        VampifyModel.healBreakdown(amount, sourcePercents, aoeFactor, breakdownBuf)
        VampifyAggregate.recordSourceBreakdown(VampifyState, spellId, breakdownBuf, sourceMeta)

        -- Dev-only per-hit debug export (core/perhit.lua). PH.hit no-ops in one check when
        -- /vf perhit is off (the default), so this costs nothing on the normal path.
        if VampifyPerHit.isEnabled() then
            VampifyPerHit.hit({
                t         = GetTime(),
                src       = VampifyConst.spellName(spellId or VampifyAggregate.MELEE),
                dmg       = amount,
                aoe       = isAoE,
                P         = sumPercent,
                n         = nSources,
                pred_heal = healFloat,
                acc_total = VampifyState.acc.total,
                crit      = isCrit,
                -- The three fields the offline analysis was missing (docs/VAMPIRISM-MODELL-STAND
                -- §4). pcts hands over the LIVE list -- PH.recordHit serialises it immediately
                -- rather than holding the reference, which matters because this very table is
                -- refilled in place on every gear change (see recompute above).
                pcts      = sourcePercents,
                zone      = zoneName,
                cast      = VampifyDamage.castSeenFor and VampifyDamage.castSeenFor(spellId, GetTime()),
            }, UnitHealth and UnitHealth("player"), GetTime(), UnitHealthMax and UnitHealthMax("player"))
        end

        VampifyAggregate.record(VampifyState, inc, healFloat, amount, GetTime())
        -- Session-scoped per-ability totals for the bar's mouseover breakdown. Overheal is added
        -- further down, once the health deficit for this hit is known.

        -- Effective (what actually landed) is tracked alongside gross, because a heal at full
        -- health returns nothing. Gross is what the display shows; effective is in /vf status.
        local effInc = 0
        if UnitHealth and UnitHealthMax then
            local deficit = UnitHealthMax("player") - UnitHealth("player")
            effInc = VampifyModel.effective(healFloat, deficit)
            VampifyState.effHeal = VampifyState.effHeal + effInc
        end

        -- Per-hit overheal, not the cumulative fight-total kind the display/options info panel
        -- show: healFloat is this hit's raw float heal, effInc is the slice of it that actually
        -- landed (both computed above), so the remainder is what this hit overhealed by. Floored
        -- like every other number shown, and only emitted if that floor is actually positive --
        -- sub-1 overheal is real but not worth a "+0"-shaped number on screen.
        --
        -- notOnTarget (core/aggregate.lua's A.recordSpell, ST/AoE split): true unless THIS hit's own
        -- targetGuid matches the CURRENT target's GUID, read fresh right here -- see
        -- currentTargetGuid's own comment for why fresh-per-hit is what makes a mid-fight target
        -- switch leave already-recorded hits alone. Deliberately NOT `isAoE` (the deriveAoE
        -- area-damage classification a few lines up) -- that drives the AoE-DAMPING factor in the
        -- healing math above and is a different axis entirely; see A.recordSpell's header for the
        -- full history of why these two used to be conflated and no longer are.
        local notOnTarget = true
        local curTarget = currentTargetGuid()
        if curTarget and targetGuid and targetGuid == curTarget then notOnTarget = false end
        VampifyAggregate.recordSpell(VampifyState, spellId, healFloat, amount, healFloat - effInc, notOnTarget)
        -- The hit's SIZE, into both scopes' distributions -- one table-index increment each, no
        -- allocation (core/histogram.lua). Deliberately fed the same `amount` and `isAoE` the model
        -- was given a few lines up, and from BELOW every drop above (no sources, excluded spell),
        -- so the histogram describes exactly the hits that were credited and nothing else. That
        -- identity is what makes the upgrade preview's baseline reproduce the real total.
        VampifyHistogram.add(VampifyState.hist, amount, isAoE)
        VampifyHistogram.add(VampifyState.lfHist, amount, isAoE)
        -- The row for this spell now holds this hit. That is what the retroactive AoE correction
        -- below needs to know before it takes any of it back, and here -- past every drop -- is the
        -- only place that knows it.
        creditedAt[spellId or VampifyAggregate.MELEE] = GetTime()

        -- I6: with sources equipped, a hit that dealt damage cannot return nothing -- the floor is
        -- the source count. Checked here rather than over the breakdown, where the zero would
        -- already have been averaged away.
        -- Reported once per session, like the stage-2 verdicts: W.checkHit is an unthrottled
        -- predicate over a single hit and carries no isNew of its own, so an unguarded call would
        -- repeat per damage event -- a chat flood, and 30-60 rolls of the file log per second.
        if not reportedOnce["I6"] and VampifyWatch.checkHit(amount, nSources, healFloat) then
            reportedOnce["I6"] = true
            watchLine(string.format("a %d damage hit returned nothing with %d sources equipped "
                                    .. "-- the formula was bypassed", amount, nSources))
        end

        -- Stage 2 closes the window the PREVIOUS hit opened: the healing that hit caused needs time
        -- to reach the bar, so it can only be measured against the health read at the next one.
        --
        -- VampifyIncoming.isOn() is now true whenever EITHER /vf watch OR the per-hit export wants
        -- the underlying capture (capture/incoming.lua's watchWanted/perhitWanted split,
        -- follow-up change request, 2026-08-22) -- so this window-tracking block itself runs for
        -- either reason. The two consumers below are gated SEPARATELY: the watch balance only on
        -- I.isWatchOn() (watch's own group-refusal guard, unchanged), the per-hit lines only on
        -- VampifyPerHit.isEnabled() (no group/watch dependency at all -- that decoupling is the
        -- entire point of the split).
        if VampifyIncoming and VampifyIncoming.isOn() and UnitHealth and UnitHealthMax then
            local hpNow, now = UnitHealth("player"), GetTime()
            if lastHp then
                local incDmg, selfHeal, extHeal = VampifyIncoming.take()
                if VampifyIncoming.isWatchOn() then
                    VampifyWatch.addWindow(balance, lastHp, hpNow, UnitHealthMax("player"),
                                           incDmg, (selfHeal or 0) + (extHeal or 0), lastExpected,
                                           now - lastAt, VampifyIncoming.inGroup())
                end
                -- Same window the reconciliation above closes when watch wants it -- no new event
                -- registration either way: this rides VampifyIncoming.take(), which now accumulates
                -- whenever perhit OR watch wants it, independent of group status or watch's guard.
                if VampifyPerHit.isEnabled() then
                    VampifyPerHit.incoming(now, incDmg)
                    VampifyPerHit.selfheal(now, selfHeal)
                    VampifyPerHit.extheal(now, extHeal)
                end
            else
                VampifyIncoming.take()      -- discard whatever accumulated before the first window
            end
            lastHp, lastAt, lastExpected = hpNow, now, effInc
        end

        -- Split the shown integer into the part that LANDED and the part that overhealed. These
        -- partition it -- emitting the full amount and an overheal number beside it made one hit
        -- look like two, which is why at full health nothing appeared in parentheses.
        local cfg = VampifyConfig.get()
        local landedAmt, overhealAmt = VampifyModel.splitOverheal(inc, healFloat, effInc)
        if not (cfg and cfg.showOverheal) then
            -- Overheal display off: show the whole return as healing, as before.
            landedAmt, overhealAmt = inc, 0
        end

        -- Counted before the coalescing branch, so buffering a cast's numbers does not look like
        -- losing them. This is the figure I3 holds against the accumulator; the split sits between
        -- the two, which is what makes the comparison worth making rather than circular.
        emittedFight = emittedFight + landedAmt + overhealAmt

        if spellId and coalesceOn() then
            -- Sum into this cast's bucket; the throttle flushes it once the cast goes quiet. A cast
            -- counts as a crit if any of its hits was one.
            pendHeal[spellId] = (pendHeal[spellId] or 0) + landedAmt
            pendOver[spellId] = (pendOver[spellId] or 0) + overhealAmt
            pendAt[spellId]   = GetTime()
            if isCrit then pendCrit[spellId] = true end
        else
            if landedAmt > 0 then emitSct(landedAmt, false, isCrit) end
            if overhealAmt > 0 then emitSct(overhealAmt, true, isCrit) end
        end
    end)
end

-- ---- retroactive AoE correction ----------------------------------------------------------------
--
-- An item proc has no cast, so no SPELL_GO_SELF announces it and its first hit is credited at the
-- full rate. The second target proves it was area damage -- after the fact. The correction goes
-- through the accumulator as an exact integer delta (VampifyModel.healPerSources at the AoE factor
-- minus at 1) rather than by rewriting the hit -- there is nothing to "rewrite" the display of,
-- since the original hit's SCT number already showed the exact amount it was credited (spec 4.2).
--
-- effHeal is deliberately NOT corrected. It was capped by the health deficit at the moment of that
-- hit, which is gone; a proportional guess would look precise without being it. Gross and per-spell
-- figures are exact, /vf status' effective figure runs at most a fraction high on proc AoE.
if VampifyDamage.onAoECorrection then
    VampifyDamage.onAoECorrection(function(amount, targetGuid, spellId, isCrit)
        -- The same exclusion the damage listener applies, and BEFORE multiTargetSeen on purpose.
        -- Every hit of an excluded spell was dropped whole, so a correction here would subtract
        -- healing that was never credited -- driving the row, the session total and the persisted
        -- lifetime set negative for exactly the multi-target damage-shield case NO_TRIGGER exists
        -- for. And a spell that cannot trigger Vampirism needs no AoE damping either, so it must
        -- not raise I5 ("damping was needed and unavailable") on its own account.
        if not VampifyConst.triggersVampirism(spellId) then return end
        -- Seen at all: this is what tells I5 that AoE damping was needed while unavailable. Above
        -- the credit check below on purpose: whether WE booked the first hit says nothing about
        -- whether area damage happened, which is all I5 is about.
        multiTargetSeen = true
        if nSources <= 0 then return end

        -- Only a hit that was actually CREDITED may be corrected. The exclusion guard above closes
        -- one way the first hit can be dropped; it is not the only one. The damage listener also
        -- drops every hit while no source set has been committed yet (the seconds after a loading
        -- screen, while detect.lua is still retrying an uncached tooltip), and a reset can empty
        -- the row between the two hits of a burst -- during AoE grinding the derive windows are
        -- continuous, so that is ordinary, not a race. In each case the reason is gone by the time
        -- this listener runs, so it does not re-derive eligibility; it reads what the damage
        -- listener recorded. One check for every reason there is, including the next one.
        --
        -- Subtracting healing that was never added drove the row, the session total and the
        -- PERSISTED lifetime set negative: overheal above healing, which is what I2 calls a broken
        -- split, in a table nothing clears but /vf reset lifetime.
        local k = spellId or VampifyAggregate.MELEE
        local creditAt = creditedAt[k]
        if not creditAt then return end
        if (GetTime() - creditAt) > VampifyDamage.DERIVE_WINDOW then return end

        -- The histogram learns the reclassification too, and BEFORE the delta==0 shortcut below:
        -- whether the healing happens to change is a separate question from which side of the
        -- distribution the hit belongs on. Left uncorrected, the histogram would keep calling a
        -- hit "normal" that was paid as AoE, and its baseline would stop reproducing the credited
        -- total -- the one property every upgrade figure rests on.
        VampifyHistogram.reclassify(VampifyState.hist, amount)
        VampifyHistogram.reclassify(VampifyState.lfHist, amount)

        local delta = VampifyModel.healPerSources(amount, sourcePercents, VampifyConst.FORMULA.aoeFactor)
                    - VampifyModel.healPerSources(amount, sourcePercents, 1)
        if delta == 0 then return end

        if VampifyState.acc then
            VampifyState.acc.total = VampifyState.acc.total + delta
            -- Heals are exact integers now (core/model.lua's header -- no more fractional carry),
            -- so delta itself is ALWAYS a whole number: the number of integers this correction
            -- removes from what was already shown is exactly -delta, with no floor-straddling
            -- reconstruction needed (the old accumulator's fractional part could make that
            -- reconstruction off by one; there is no fractional part left to straddle).
            aoeCorrectedShown = aoeCorrectedShown - delta
        end

        -- Overheal is a PART of the row's healing, so healing taken back has to take its share of
        -- overheal with it -- otherwise the row reads overheal > heal, which is precisely what the
        -- watchdog's I2 calls a broken split, and at (or near) full health that is every row. The
        -- exact per-hit split is unrecoverable at this point: the health deficit at that hit is
        -- gone, which is the same reason effHeal is left alone above. The row's own pre-correction
        -- ratio is the honest approximation, and it is exact in the full-health case that produced
        -- the false alarm. (`k` is the row key resolved with the credit check above.)
        --
        -- What this scaling does NOT do is guarantee the result is a valid row. That rests on the
        -- credit check above -- on the row having received this hit in the first place -- and an
        -- earlier version of this file asserted the guarantee outright ("h + delta >= 0 is assured")
        -- on the strength of the exclusion guard alone, which assures nothing of the kind. The
        -- shape (0 <= overheal <= heal) is therefore also ENFORCED where it is written, in
        -- VampifyAggregate.recordSpell, on the negative-delta path only.
        local h, share = VampifyState.spHeal[k] or 0, 0
        if h > 0 then share = (VampifyState.spOver[k] or 0) / h end
        if share > 1 then share = 1 end

        -- Routed through the normal recording calls so both the session and lifetime sets are
        -- adjusted by the same code that filled them. inc is 0: nothing new is shown for this.
        VampifyAggregate.record(VampifyState, 0, delta, 0, nil)
        VampifyAggregate.recordSpell(VampifyState, spellId, delta, 0, delta * share)
    end)
end

-- ---- persistence: two per-spell sets in VampifyCharDB, wired by reference ----------------------
--
-- core/aggregate.lua stays WoW-API-free, so it does not know about SavedVariables; its per-spell
-- tables (spHeal/spDmg/spOver/spHits, and their lifetime twins) start out as the plain local tables
-- A.new() creates. wireSession() below REPOINTS them, once, at sub-tables of VampifyCharDB, so
-- every A.recordSpell call from that moment on is already a SavedVariables write -- no explicit
-- save step, no allocation beyond the one-time reassignment (spec 2026-08-10 sec 3).
--
-- Reload vs. login -- the criterion and its reasoning:
--
-- PLAYER_LOGIN CANNOT ANSWER THIS, and an earlier version of this file that branched on it wiped
-- the session breakdown on every single /reload -- the exact loss this persistence exists to
-- prevent. 1.12 fires PLAYER_LOGIN on a UI reload as well, immediately before
-- PLAYER_ENTERING_WORLD, so it carries no login-vs-reload information at all. That is not a
-- reading of documentation: another addon on the same machine builds its reload detector on exactly
-- this (writes a fresh session id from its PLAYER_LOGIN handler, and a CHANGED id is what proves a
-- /reload happened), and installed 1.12 addons initialise from it -- aux-addon prints its load banner from
-- PLAYER_LOGIN, which appears after every reload. PLAYER_ENTERING_WORLD fires on every path
-- (login, reload AND every zone change), so it proves nothing on its own either.
--
-- What DOES separate the two is the logout. PLAYER_CAMPING and PLAYER_QUITING are raised when the
-- server accepts a logout or quit request (1.12 FrameXML shows the camp/quit countdown from them);
-- a /reload asks the server for nothing and raises neither. So the marker goes there, which is also
-- what the design doc originally prescribed. LOGOUT_CANCEL takes it back if the player changes
-- their mind, and wireSession consumes it unconditionally, so a marker can never go stale.
--
-- The marker HAS holes -- a crash, a dropped connection, or any exit that never reaches those
-- events leaves none behind. That is the SAFE direction on purpose: with no marker the session is
-- CONTINUED (an over-counted session) rather than a breakdown destroyed that nothing can recover.
-- The LIFETIME set is not conditioned on this criterion at all (see below), so none of this can
-- cost it anything.
local sessionWired = false

local function wireSession()
    if sessionWired then return end
    local cfg = VampifyConfig.getChar()
    if not cfg then return end     -- config not migrated yet -- retry on the next PLAYER_ENTERING_WORLD
    sessionWired = true

    -- Consumed whichever branch runs: a marker must not outlive the load that read it, or the next
    -- reload after a cancelled-but-marked logout would be taken for a login.
    local afterLogout = cfg.loggingOut
    cfg.loggingOut = nil

    if afterLogout then
        -- Genuine login: the session set starts over. Cleared IN PLACE, not by replacing the
        -- table with a new {} -- see A.resetSpells' comment for why that distinction matters here.
        for k in pairs(cfg.session.heal)     do cfg.session.heal[k]     = nil end
        for k in pairs(cfg.session.damage)   do cfg.session.damage[k]   = nil end
        for k in pairs(cfg.session.overheal) do cfg.session.overheal[k] = nil end
        for k in pairs(cfg.session.hits)     do cfg.session.hits[k]     = nil end
        -- The ST/AoE split twins start over on the same criterion, for the same reason -- otherwise
        -- a genuine login would keep last session's AoE-only figures sitting above a freshly-zeroed
        -- session total, which A.spellSplit's defensive clamp would then have to paper over.
        for k in pairs(cfg.session.healAoe)   do cfg.session.healAoe[k]   = nil end
        for k in pairs(cfg.session.damageAoe) do cfg.session.damageAoe[k] = nil end
        for k in pairs(cfg.session.hitsAoe)   do cfg.session.hitsAoe[k]   = nil end
        for k in pairs(cfg.session.splitSeen) do cfg.session.splitSeen[k] = nil end
        -- The session DISTRIBUTION starts over on the same criterion and for the same reason: it
        -- describes the same span the session rows do, and a distribution outliving the totals it
        -- belongs to would answer "what is an upgrade worth this session" from last session's hits.
        VampifyHistogram.reset(cfg.session.hist)
    end
    -- Reload path (no marker): the session tables are left exactly as SavedVariables handed them
    -- back. That IS "continuing the session" -- there is nothing else to do here.

    VampifyState.spHeal, VampifyState.spDmg, VampifyState.spOver =
        cfg.session.heal, cfg.session.damage, cfg.session.overheal
    VampifyState.spHits = cfg.session.hits
    VampifyState.lfHeal, VampifyState.lfDmg, VampifyState.lfOver =
        cfg.lifetime.heal, cfg.lifetime.damage, cfg.lifetime.overheal
    VampifyState.lfHits = cfg.lifetime.hits
    -- Same aliasing for the ST/AoE split tables (core/aggregate.lua's A.recordSpell/A.spellSplit),
    -- same reasoning: every A.recordSpell call from here on is already a SavedVariables write.
    VampifyState.spHealAoe, VampifyState.spDmgAoe, VampifyState.spHitsAoe, VampifyState.spSplitSeen =
        cfg.session.healAoe, cfg.session.damageAoe, cfg.session.hitsAoe, cfg.session.splitSeen
    VampifyState.lfHealAoe, VampifyState.lfDmgAoe, VampifyState.lfHitsAoe, VampifyState.lfSplitSeen =
        cfg.lifetime.healAoe, cfg.lifetime.damageAoe, cfg.lifetime.hitsAoe, cfg.lifetime.splitSeen
    -- Same aliasing for the two histograms. The tables the config migration created (or filled in
    -- for a character db that predates the feature -- core/config.lua's CHAR_DEFAULTS) become THE
    -- histograms from here on; the ones VampifyState was created with are dropped.
    VampifyState.hist, VampifyState.lfHist = cfg.session.hist, cfg.lifetime.hist

    -- sHeal/sDmg (the SEPARATELY kept session total the tooltip's cross-check compares the
    -- per-spell rows against, gui/display.lua) are plain numbers, not tables, so they cannot be
    -- aliased the way the per-spell tables just were -- they need reseeding from whatever the
    -- per-spell session table now holds, or they would read 0 against a non-empty breakdown right
    -- after a reload and raise a false alarm on the very first hover.
    VampifyAggregate.seedSessionTotals(VampifyState)
end

-- ---- per-hit export enable/disable, coupled to the incoming capture's "perhit" want ------------
--
-- File scope, not nested inside "if CreateFrame then" below: it is used both by syncPerHit()
-- (which IS inside that block) and by the /vf perhit slash handler (which is not -- the slash
-- commands are wired unconditionally further down). One place that flips VampifyPerHit AND
-- VampifyIncoming's perhitWanted together, so the two can never drift -- forgetting the second
-- call at just one of the two call sites would either leave INC/SELFHEAL/EXTHEAL silently absent
-- (perhit on, incoming not wanted) or leave the _OTHER events registered forever after perhit off
-- (incoming still wanted, nothing consuming it).
local function applyPerHitWant(want, hpNow)
    if want then
        if not VampifyPerHit.isEnabled() then VampifyPerHit.enable() end
    else
        if VampifyPerHit.isEnabled() then VampifyPerHit.disable(hpNow) end
    end
    if VampifyIncoming and VampifyIncoming.setPerHitWanted then
        VampifyIncoming.setPerHitWanted(want)
    end
end

-- ---- fight boundaries and the display throttle -------------------------------------------------

if CreateFrame then
    local f = CreateFrame("Frame", "VampifyCoreFrame")
    local elapsed = 0

    -- Both PLAYER_LOGIN and PLAYER_ENTERING_WORLD: the two together cover every path into the
    -- world, and a reloaded session with a stale source set would compute against the wrong gear.
    -- Neither says WHICH path it was -- see wireSession above for what does.
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entering combat
    f:RegisterEvent("PLAYER_REGEN_ENABLED")    -- leaving combat
    f:RegisterEvent("PLAYER_DEAD")
    -- The logout marker wireSession reads. A /reload raises none of these three.
    f:RegisterEvent("PLAYER_CAMPING")
    f:RegisterEvent("PLAYER_QUITING")
    f:RegisterEvent("LOGOUT_CANCEL")
    -- Fires on every loading screen and on every zone border crossed on foot -- the only two ways
    -- the cached zone name above can go stale.
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    -- The running count of combat seconds the "no damage events at all" verdict is given from.
    -- Declared out here rather than beside the OnUpdate that uses it because the combat-end branch
    -- below has to reset it -- 20 seconds means 20 seconds of ONE fight, not a session-long sum of
    -- unrelated pulls. (The latch itself, inertWarned, lives at file scope: applyVisibility above
    -- has to see it, or a loading screen would put the untrusted zero straight back on screen.)
    local combatSecs = 0

    -- Applies the persisted preference (VampifyDB.perhitEnabled, default true -- core/config.lua)
    -- to the actual channel state via applyPerHitWant (above), which is idempotent, so calling it
    -- on every PLAYER_ENTERING_WORLD -- not just login/reload, every zone change too -- is
    -- harmless; it exists so a login before the config migration has run cannot silently skip
    -- turning the channel on. Mirrors /vf perhit on|off below, which is the other writer of this
    -- same field.
    local function syncPerHit()
        local cfg = VampifyConfig.get()
        if not cfg then return end
        applyPerHitWant(cfg.perhitEnabled, UnitHealth and UnitHealth("player"))
    end

    f:SetScript("OnEvent", function()
        if event == "PLAYER_CAMPING" or event == "PLAYER_QUITING" or event == "LOGOUT_CANCEL" then
            local c = VampifyConfig.getChar()
            if c then
                if event == "LOGOUT_CANCEL" then c.loggingOut = nil else c.loggingOut = true end
            end
            -- A real logout/camp request (never a cancel) is the one point that MUST guarantee a
            -- write: whatever is still buffered would otherwise be lost the moment the client
            -- closes -- ExportFile writes immediately on call, but nothing has called it yet for
            -- these lines. The SavedVariables persistence marker above has the same "holes on a
            -- hard crash" caveat (wireSession's comment); this is the same tradeoff for the
            -- per-hit channel, not a new one.
            if event ~= "LOGOUT_CANCEL" and VampifyPerHit.isEnabled() then
                VampifyPerHit.flushNow(UnitHealth and UnitHealth("player"))
            end
            return
        end
        if event == "ZONE_CHANGED_NEW_AREA" then
            refreshZone()
            return
        end
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            if event == "PLAYER_ENTERING_WORLD" then wireSession() end
            refreshZone()
            recompute()
            syncPerHit()
            if VampifyMinimap and VampifyMinimap.update then VampifyMinimap.update() end
            -- A /reload mid-combat never delivers PLAYER_REGEN_DISABLED, so fStart would stay at 0
            -- and HPS would be computed against the whole client uptime.
            if UnitAffectingCombat and UnitAffectingCombat("player") then beginFight(GetTime()) end
        elseif event == "PLAYER_REGEN_DISABLED" then
            beginFight(GetTime())
        elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_DEAD" then
            flushCoalesced(GetTime(), true)   -- do not strand a cast's number at combat end
            VampifyAggregate.endFight(VampifyState, GetTime())
            combatSecs = 0                    -- the inert verdict counts ONE fight, not their sum
            VampifyDisplay.update()
            -- Closes the last hit's pending hp_after window WITHOUT forcing a disk write --
            -- core/perhit.lua's PH.closeWindow. Grinding mobs one at a time drops combat between
            -- every pull, and forcing a full chunk flush here would turn that into a file per kill;
            -- several short fights' hits accumulate in the SAME buffer until FLUSH_LINES/FLUSH_SECS
            -- fires naturally (or a real logout forces it, above).
            if VampifyPerHit.isEnabled() then
                VampifyPerHit.closeWindow(UnitHealth and UnitHealth("player"))
            end
        end
    end)

    f:SetScript("OnUpdate", function()
        elapsed = elapsed + arg1
        if elapsed < 0.25 then return end

        -- The watchdog rides this throttle rather than owning a frame: it runs on its own slow
        -- interval, and one OnUpdate handler is cheaper than two (a lesson from profiling a sibling
        -- addon, where parallel per-window handlers tripled the call count).
        local nowT = GetTime()
        if nowT >= nextCheck then
            nextCheck = nowT + WATCH_INTERVAL
            if nSources > 0 then runWatch() end
        end

        -- nampower cannot be queried, only observed (see damage.lua). If the player has Vampirism
        -- sources and has been in combat for a while without a single own-damage event, the
        -- capture layer may be inert -- say so once, rather than displaying a confident zero.
        --
        -- This is a diagnosis made from SILENCE, and silence is weak evidence: being attacked while
        -- feared, stunned, mounted or letting a pet tank produces exactly the same reading. Three
        -- things bound it, all of them because it was a confident wrong answer without them:
        --   * the timer counts ONE fight -- reset at combat end above, not a session-long sum;
        --   * a SPELL_GO_SELF that has arrived (aoeAvailable) is positive proof that nampower is
        --     loaded and its events are on, which makes the verdict provably false;
        --   * the latch releases the moment a damage event does arrive, so a wrong verdict repairs
        --     itself instead of keeping the bar hidden for the rest of the session.
        if inertWarned and VampifyDamage.damageSeen() then
            inertWarned, combatSecs = false, 0
            -- Through applyVisibility, not a bare show(): a bar the USER hid must stay hidden.
            applyVisibility()
        elseif not inertWarned and nSources > 0 and UnitAffectingCombat and UnitAffectingCombat("player") then
            combatSecs = combatSecs + elapsed
            if combatSecs > 20 and not VampifyDamage.damageSeen()
               and not VampifyDamage.aoeAvailable() then
                inertWarned = true
                print_("no own-damage events received in this fight -- nampower may be absent or"
                       .." its events are off.")
                print_("the number would be a confident zero, so the display stays hidden.")
                applyVisibility()
            end
        end

        -- Dev-only per-hit channel: closes a hit that never got a follow-up event (see
        -- core/perhit.lua's PENDING_TIMEOUT) and drives its time-based flush. Rides this same
        -- throttle rather than its own OnUpdate, for the same reason the watchdog above does.
        if VampifyPerHit.isEnabled() then
            VampifyPerHit.onTick(UnitHealth and UnitHealth("player"), nowT, elapsed)
        end

        elapsed = 0
        flushCoalesced(GetTime(), false)
        VampifyDisplay.update()
    end)
end

-- ---- slash commands ----------------------------------------------------------------------------

local shareBuf = {}
local excludeBuf = {}
-- One result table per scope, reused: /vf upgrade prints both, and VampifyHistogram.compare fills
-- whatever it is handed rather than building a new one.
local cmpSession, cmpLifetime = {}, {}

local function status()
    local sources = VampifyDetect.getSources()
    local n = table.getn(sources)
    -- "at least N" not "floor N": each source now floors its OWN contribution at 1 (see
    -- core/model.lua), so the per-hit minimum is still exactly nSources (one per source, summed)
    -- for any hit above the damage<=1 proc-fail cutoff -- same number as before, different reason.
    print_("version "..VampifyConst.VERSION.."  --  "..n.." detected source(s), "
           ..string.format("%.0f%%", sumPercent * 100).." total, at least "..nSources.." per hit")
    for i = 1, n do
        print_(string.format("  slot %d: %d%% (%s)", sources[i].slot, sources[i].percent, sources[i].kind))
    end
    local cfg = VampifyConfig.getChar()
    if cfg and cfg.manual and table.getn(cfg.manual) > 0 then
        for i = 1, table.getn(cfg.manual) do
            print_("  manual override: "..cfg.manual[i].."%")
        end
    end

    local fight   = VampifyAggregate.fight(VampifyState)
    local session = VampifyAggregate.session(VampifyState)
    -- Overheal is CALCULATED (deficit at hit time), not measured -- Vampirism emits no heal event.
    -- Floored, like every other total here, never rounded up.
    local eff = VampifyState.effHeal or 0
    local overheal = fight.heal - eff
    if overheal < 0 then overheal = 0 end
    local ohPct = 0
    if fight.heal > 0 then ohPct = overheal / fight.heal * 100 end
    print_(string.format("fight:   %d healed, %d effective, %d overheal (%.0f%%) over %d damage,"
           .." %.1f HPS, %.2f%%",
        math.floor(fight.heal), math.floor(eff), math.floor(overheal), ohPct,
        fight.damage, fight.hps, fight.pct * 100))
    print_(string.format("session: %d healed over %d damage, %.2f%%",
        math.floor(session.heal), session.damage, session.pct * 100))

    -- Per-source breakdown. Sources are summed BEFORE rounding, so there is no per-source integer
    -- to attribute -- these are proportional shares of the fight total, not separate heals.
    if n > 0 and fight.heal > 0 then
        VampifyAggregate.shares(VampifyState, sources, shareBuf)
        for i = 1, table.getn(shareBuf) do
            print_(string.format("  share slot %d: %.1f HP (%.0f%% of the total)",
                sources[i].slot, shareBuf[i].heal, shareBuf[i].share * 100))
        end
    end

    local g, b, a, r = VampifyDamage.mitigation()
    if b + a + r > 0 then
        print_(string.format("mitigation seen: %d blocked, %d absorbed, %d resisted of %d gross"
            .." (damageBase=%s)", b, a, r, g, VampifyConst.FORMULA.damageBase))
    end
    if not VampifyDamage.damageSeen() then
        print_("no own-damage events received yet -- nampower may be absent.")
    end

    local flag = VampifyDisplay.boundFlag(VampifyConst.FORMULA.channels, VampifyDamage.aoeAvailable())
    if flag == "lower" or flag == "uncertain" then
        print_("|cffffff00>|r the total is a LOWER bound: DoT and PvP damage are unmeasured and excluded.")
    end
    if flag == "upper" or flag == "uncertain" then
        print_("|cffffff00<|r the total is an UPPER bound: no SPELL_GO seen, so AoE damping is not applied.")
    end
end

-- ---- /vf upgrade -- what a Vampirism upgrade would have been worth on the hits that fell --------
--
-- The question this answers cannot be answered from any total (core/histogram.lua's header): while
-- pct*D/100 < 1 a source pays its floor of 1 whatever its percentage is, so on small hits MANY
-- SMALL sources beat FEW LARGE ones, and on big hits it reverses (truncation lets a fatter source
-- keep remainders two thinner ones each throw away). Which regime a player is in is invisible from
-- the numbers this addon showed before, and it is exactly what "+1% enchant or the bigger item"
-- turns on. Both variants are computed by replaying the RECORDED hits through the same model the
-- live path uses -- never on a worked example.
local function upgradeScope(label, hist, p, out)
    local c = VampifyHistogram.compare(hist, sourcePercents, p, out)
    if c.hits <= 0 then
        print_(label .. ": no hits recorded yet.")
        return c
    end
    print_(string.format("%s: %d hits, %d healed, %d of it from the floor (%.0f%%)",
        label, c.hits, math.floor(c.heal), math.floor(c.floorHeal), c.floorShare * 100))
    -- These two lines are the decision, and they are printed ADJACENT on purpose: both buy the
    -- same nominal point of total percentage, and the whole point of the feature is how far apart
    -- they can be worth. Anything between them would break the comparison the eye is meant to make.
    -- Padded to a common label width so the three figures form a column. The chat font is
    -- proportional, so this is approximate rather than exact -- close enough to read down.
    local function option(label, delta, pct)
        print_(string.format("    %-34s +%d (+%.1f%%)", label, math.floor(delta), pct))
    end
    option(string.format("one more %d%% source:", p), c.addDelta, c.addPct)
    if c.swapIndex then
        option(string.format("swap your weakest (%d%% -> %d%%):", c.swapFrom, c.swapTo),
               c.swapDelta, c.swapPct)
    end
    -- The ceiling, printed after and labelled as one: raising the STRONGEST source is the most a
    -- point can ever be worth on these hits, but no shop sells it (see core/histogram.lua's
    -- header). It is a bound on the two above, not a third option.
    if c.upIndex then
        option(string.format("ceiling, a stronger source (%d%% -> %d%%):", c.upFrom, c.upTo),
               c.upDelta, c.upPct)
    end
    return c
end

local function upgradeReport(p)
    p = p or 1
    if nSources <= 0 then
        print_("upgrade: no Vampirism sources detected, so there is nothing to compare against.")
        return
    end
    print_(string.format("upgrade preview at +%d%% -- computed on the hits you actually took,"
                         .." not on an example.", p))
    local s = upgradeScope("session", VampifyState.hist, p, cmpSession)
    upgradeScope("lifetime", VampifyState.lfHist, p, cmpLifetime)
    -- The verdict, from the SESSION scope: it describes what the player is doing now, whereas the
    -- lifetime distribution mixes every kind of content they have ever fought in.
    --
    -- Decided between the two BUYABLE options only -- one more source against the swap. The
    -- ceiling line is not in the running; see core/histogram.lua's G.compare header.
    if s and s.hits > 0 then
        local by = math.floor(s.winnerBy)
        if s.winner == "add" then
            print_(string.format("  |cffe0c98a->|r one MORE source wins by %d HP (+%d against +%d):"
                   .." your hits are small enough that the floor dominates.",
                   by, math.floor(s.addDelta), math.floor(s.swapDelta)))
        elseif s.winner == "swap" then
            print_(string.format("  |cffe0c98a->|r the SWAP wins by %d HP (+%d against +%d):"
                   .." your hits are big enough that the percentage dominates.",
                   by, math.floor(s.swapDelta), math.floor(s.addDelta)))
        else
            print_(string.format("  |cffe0c98a->|r on these hits one more source and the swap are"
                   .." worth exactly the same (+%d each).", math.floor(s.addDelta)))
        end
    end
end

local function help()
    print_("/vf status            -- sources and totals")
    print_("/vf reset [session|lifetime|last|both]")
    print_("                      -- clear totals; default is session only (lifetime is untouched)."
           .." 'last' clears only the last-fight breakdown; 'both' means session+lifetime, not 'last'")
    print_("/vf pos               -- move the display back to its default position")
    print_("/vf lock              -- toggle frame dragging")
    print_("/vf fct / sct         -- toggle scrolling combat text (either engine)")
    print_("/vf sct duration <s>  -- SCT fade duration, 0.5-4.0 seconds")
    print_("/vf sct shadow on|off -- SCT text shadow")
    print_("/vf sctmove           -- move our own SCT anchor (options window has the same button)")
    print_("/vf options           -- open the options window")
    print_("/vf source add <pct>  -- add a manual source, if tooltip detection fails")
    print_("/vf source clear      -- drop all manual sources")
    print_("/vf exclude add <id>     -- stop a spell from triggering Vampirism, from now on")
    print_("/vf exclude remove <id> -- undo a runtime exclusion (built-ins cannot be removed)")
    print_("/vf exclude list         -- show excluded spells, built-in and runtime")
    print_("/vf perhit on|off|status -- per-hit debug export, default ON, setting is saved")
    print_("/vf upgrade [pct]     -- how much of your healing is the floor, and whether one more"
           .." source or swapping your weakest one is worth more (default +1%)")
end

SLASH_VAMPIFY1 = "/vampify"
SLASH_VAMPIFY2 = "/vf"
SlashCmdList = SlashCmdList or {}
SlashCmdList["VAMPIFY"] = function(msg)
    msg = string.lower(msg or "")
    -- Lua 5.0 has no pattern-matching shorthand, so captures come from string.find.
    local _, _, cmd, rest = string.find(msg, "^(%a*)%s*(.*)$")
    cmd = cmd or ""

    if cmd == "status" or cmd == "" then
        status()
    elseif cmd == "watch" then
        local _, _, arg = string.find(rest, "^(%a*)")
        arg = arg or ""
        if arg == "on" or arg == "off" then
            local want = (arg == "on")
            if want and VampifyIncoming.inGroup() then
                print_("watch: you are in a group -- foreign healing makes the balance"
                       .." meaningless, so this stays off. Try again when solo.")
            elseif VampifyIncoming.setWatchWanted(want) == want then
                lastHp, lastAt, lastExpected = nil, nil, nil   -- no window straddles the switch
                print_("watch: HP reconciliation " .. arg .. ".")
            else
                print_("watch: could not switch -- SuperWoW is needed for the player GUID.")
            end
        else
            local b = balance
            print_(string.format("watch: %s, %d clean windows (%d without incoming damage)",
                                 VampifyIncoming.isWatchOn() and "on" or "off", b.n, b.zeroN))
            print_(string.format("       discarded: %d at full health, %d in a group, %d too long, "
                                 .. "%d expecting nothing", b.rejected.cap, b.rejected.group,
                                 b.rejected.idle, b.rejected.noExpect))
            -- Deliberately no ratio here. It is an alarm input, not a measurement, and printing it
            -- would invite exactly the reading the whole design refuses (spec 2.1).
            runWatch()
        end
    elseif cmd == "reset" then
        local _, _, scopeArg = string.find(rest, "^(%a*)")
        scopeArg = scopeArg or ""
        if scopeArg == "" or scopeArg == "session" then
            VampifyResetSession("session")
        elseif scopeArg == "lifetime" then
            VampifyResetSession("lifetime")
        elseif scopeArg == "last" then
            VampifyResetSession("last")
        elseif scopeArg == "both" then
            VampifyResetSession("both")
        else
            print_("/vf reset [session|lifetime|last|both] -- default is session, lifetime is untouched")
        end
    elseif cmd == "pos" then
        VampifyDisplay.resetPos()
        print_("display moved back to its default position.")
    elseif cmd == "lock" then
        local cfg = VampifyConfig.get()
        if not cfg then print_("config not loaded yet.") return end
        cfg.locked = not cfg.locked
        print_(cfg.locked and "frame locked." or "frame unlocked.")
    elseif cmd == "fct" or cmd == "sct" then
        local cfg = VampifyConfig.get()
        if not cfg or not cfg.sct then print_("config not loaded yet.") return end
        -- Bare "/vf sct" / "/vf fct" keeps its original meaning (toggle enabled); "sct <sub> <val>"
        -- is the same sub/val dispatch pattern /vf source and /vf exclude already use above. %S*
        -- rather than %d* for val: duration needs a decimal ("1.5"), shadow needs a word (on/off).
        local _, _, sub, val = string.find(rest, "^(%a*)%s*(%S*)")
        if sub == "" then
            cfg.sct.enabled = not cfg.sct.enabled
            if cfg.sct.enabled and cfg.sct.mode == "blizzard" and SHOW_COMBAT_TEXT ~= "1" then
                print_("scrolling combat text ON -- but Blizzard's own combat text is disabled in its"
                       .." options, so nothing will show in blizzard mode.")
            else
                print_(cfg.sct.enabled and "scrolling combat text ON." or "scrolling combat text OFF.")
            end
        elseif sub == "duration" then
            local s = tonumber(val)
            if not s or s < 0.5 or s > 4.0 then
                print_("/vf sct duration <seconds> -- 0.5 to 4.0, e.g. /vf sct duration 1.5")
            else
                cfg.sct.duration = s
                print_("SCT fade duration set to "..s.."s.")
            end
        elseif sub == "shadow" then
            if val == "on" then
                cfg.sct.shadow = true
            elseif val == "off" then
                cfg.sct.shadow = false
            else
                print_("/vf sct shadow on|off")
                return
            end
            if VampifySCT and VampifySCT.applyFont then VampifySCT.applyFont() end
            print_(cfg.sct.shadow and "SCT text shadow ON." or "SCT text shadow OFF.")
        else
            help()
        end
    elseif cmd == "sctmove" then
        if not (VampifySCT and VampifySCT.setMoveMode and VampifySCT.isMoveMode) then
            print_("SCT not loaded yet.")
            return
        end
        local on = not VampifySCT.isMoveMode()
        -- setMoveMode refuses to turn ON while anchored to the bar (mode == "bar") -- dragging is
        -- meaningless there -- and hands back a reason instead. Turning OFF always succeeds.
        local ok, why = VampifySCT.setMoveMode(on)
        if not ok then
            print_(why or "SCT move mode is unavailable right now.")
        else
            print_(on and "SCT move mode ON -- drag the anchor, /vf sctmove again when done."
                      or "SCT move mode OFF.")
        end
    elseif cmd == "options" then
        if VampifyOptions and VampifyOptions.toggle then
            VampifyOptions.toggle()
        else
            print_("options window not loaded.")
        end
    elseif cmd == "source" then
        local cfg = VampifyConfig.getChar()
        if not cfg then print_("config not loaded yet.") return end
        if not cfg.manual then cfg.manual = {} end
        local _, _, sub, val = string.find(rest, "^(%a+)%s*(%d*)")
        if sub == "add" then
            local pct = tonumber(val)
            -- Reject 0: it would raise nSources without raising sumPercent, so the per-hit floor
            -- (which IS the source count) would silently add 1 HP to every hit forever.
            if not pct or pct <= 0 then
                print_("a manual source needs a percentage above zero, e.g. /vf source add 3")
            else
                table.insert(cfg.manual, pct)
                print_("manual source added: "..pct.."%")
                recompute()
            end
        elseif sub == "clear" then
            cfg.manual = {}
            print_("manual sources cleared.")
            recompute()
        else
            help()
        end
    elseif cmd == "exclude" then
        local cfgc = VampifyConfig.getChar()
        if not cfgc then print_("config not loaded yet.") return end
        local _, _, sub, val = string.find(rest, "^(%a*)%s*(%d*)")
        if sub == "" then sub = "list" end

        if sub == "add" then
            local id = tonumber(val)
            if not id or id <= 0 then
                print_("/vf exclude add <spellId> -- needs a numeric spell id, e.g. /vf exclude add 16624")
            else
                local ok, why = VampifyConst.addNoTrigger(id, cfgc)
                if ok then
                    -- Forward-only: this changes what counts as triggering from now on, but does
                    -- not reach back into totals already recorded for earlier hits. The current
                    -- session total already reflects whatever this spell contributed before it was
                    -- spotted and excluded; /vf reset remains the explicit way to discard that.
                    -- Retroactively subtracting it would need a per-spell breakdown of the
                    -- session's EFFECTIVE (deficit-clipped) healing, which is only tracked as a
                    -- single running total (VampifyState.effHeal in this file), not per spell --
                    -- correcting the gross total while leaving effective/overheal inconsistent
                    -- would be worse than leaving both alone.
                    print_("excluded "..VampifyConst.spellName(id).." (#"..id..") from Vampirism"
                           .." triggering, from now on. /vf reset clears the current session if it"
                           .." already includes this spell.")
                elseif why == "builtin" then
                    print_(VampifyConst.spellName(id).." (#"..id..") is already excluded (built in).")
                elseif why == "already" then
                    print_(VampifyConst.spellName(id).." (#"..id..") is already excluded.")
                end
            end
        elseif sub == "remove" then
            local id = tonumber(val)
            if not id then
                print_("/vf exclude remove <spellId>")
            elseif VampifyConst.NO_TRIGGER[id] then
                print_(VampifyConst.spellName(id).." (#"..id..") is a built-in exclusion and cannot be removed.")
            elseif VampifyConst.removeNoTrigger(id, cfgc) then
                print_("removed "..VampifyConst.spellName(id).." (#"..id..") from the exclusion list,"
                       .." from now on.")
            else
                print_(VampifyConst.spellName(id).." (#"..id..") was not excluded.")
            end
        elseif sub == "list" then
            local list = VampifyConst.listNoTrigger(cfgc, excludeBuf)
            local n = table.getn(list)
            if n == 0 then
                print_("no excluded spells.")
            else
                print_(n.." excluded spell(s):")
                for i = 1, n do
                    local e = list[i]
                    print_("  #"..e.id.." "..VampifyConst.spellName(e.id)..(e.builtin and " (built in)" or " (runtime)"))
                end
            end
        else
            print_("/vf exclude add <id> | remove <id> | list")
        end
    elseif cmd == "upgrade" then
        -- Optional size in whole percent. Anything unparseable or non-positive falls back to 1
        -- rather than erroring: 1% is the smallest real source that exists (the bracer and boot
        -- enchants), which makes it both the default and the only sensible fallback.
        local _, _, val = string.find(rest, "^(%d*)")
        local p = tonumber(val)
        if not p or p <= 0 then p = 1 end
        upgradeReport(p)
    elseif cmd == "perhit" then
        local _, _, arg = string.find(rest, "^(%a*)")
        arg = arg or ""
        if arg == "on" then
            local cfg = VampifyConfig.get()
            if cfg then cfg.perhitEnabled = true end       -- survives /reload and the next login
            if VampifyPerHit.isEnabled() then
                print_("perhit: already on.")
            else
                applyPerHitWant(true)
                print_("perhit: ON -- session "..tostring(VampifyPerHit.status().sid)
                       ..". Chunks flush to imports\\vampify_perhit_*.txt.")
            end
        elseif arg == "off" then
            local cfg = VampifyConfig.get()
            if cfg then cfg.perhitEnabled = false end       -- survives /reload and the next login
            if not VampifyPerHit.isEnabled() then
                print_("perhit: already off.")
            else
                applyPerHitWant(false, UnitHealth and UnitHealth("player"))
                print_("perhit: OFF -- final chunk flushed.")
            end
        else
            local st = VampifyPerHit.status()
            print_(string.format("perhit: %s -- %d hit(s) recorded, %d line(s) buffered, "
                   .."%d chunk(s) flushed this session",
                   st.enabled and "on" or "off", st.totalHits, st.buffered, st.chunk))
        end
    else
        help()
    end
end
