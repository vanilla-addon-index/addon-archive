-- Vampify -- dev-only per-hit debug export. Pure Lua ring buffer + line formatting (offline
-- tested), plus a thin session-local singleton and SuperWoW ExportFile flush.
--
-- WHAT THIS IS FOR. The v0.1/v0.2 formula (heal(D) = max(nSources, D * P * a)) uses ONE factor
-- per source, summed. Upgrading that to a PER-SOURCE factor needs exact measurements of what the
-- model predicted against what actually happened for every hit -- not the aggregated totals
-- /vf status already prints. This channel is that instrument: one line per own hit with the
-- inputs the model saw, the prediction it made, and the health readings around it, dumped to
-- <WoW>\imports\ for offline analysis.
--
-- INC / SELFHEAL / EXTHEAL RUN INDEPENDENTLY OF /vf watch AND GROUP STATUS (follow-up change
-- request, 2026-08-22). /vf watch on correctly REFUSES in a group -- the HP-reconciliation
-- BALANCE it computes is genuinely meaningless there (foreign healing, measured at +29..49%
-- phantom healing). That refusal is about watch's own verdict, not about whether the raw incoming/
-- healing numbers can be captured at all -- and this channel wants exactly those raw numbers,
-- group or not, watch-on or not, since they are what turns "some healing arrived and we don't know
-- why" into a measurable EXTHEAL line. So capture/incoming.lua now tracks two independent "wants"
-- (I.setWatchWanted / I.setPerHitWanted); whichever hit-line code in core/commands.lua feeds
-- PH.incoming/.selfheal/.extheal runs whenever EITHER wants the capture (I.isOn()), while the
-- watch balance itself (VampifyWatch.addWindow) stays gated on I.isWatchOn() specifically -- see
-- capture/incoming.lua's own header for the full mechanism and for the answer to "does Vampify see
-- foreign healing at all" (yes: SPELL_HEAL_BY_OTHER, always already registered; it was just being
-- folded into the self-heal total before this change, which is what the new EXTHEAL line fixes).
--
-- DEFAULT ON, PERSISTED (follow-up change request, 2026-08-22, overriding this addon's earlier
-- "dev-only, default off, never saved" stance for THIS specific channel by explicit developer
-- request): it is meant to run continuously across every session like a background capture addon's
-- capture, not be armed by hand. The persisted half of that --
-- VampifyDB.perhitEnabled and the auto-enable-on-login sync -- lives in core/commands.lua
-- (syncPerHit) and gui/options.lua (the "Per-hit debug export" checkbox); this module itself still
-- defaults its OWN in-memory VampifyPerHit._state to disabled (PH.newState()) and knows nothing
-- about VampifyConfig -- it only turns on when told to, the same as every other module here that
-- stays config-agnostic (core/model.lua, core/watch.lua). /vf perhit on|off|status
-- (core/commands.lua) remains the manual alternative and writes the same persisted field.
--
-- ARCHITECTURE. Same split as the rest of this addon: this file is pure and WoW-API-free except
-- for the disk flush at the bottom (mirrors core/const.lua's error capture and core/watch.lua's
-- watchLine, which are the same shape for the same reason). The actual per-hit DATA -- amount,
-- isAoE, spellId, the model's healFloat, sumPercent/nSources -- lives in core/commands.lua's
-- onDamage listener, which is "the only place where the pure core meets the WoW-bound capture
-- layer" (its own header comment). So commands.lua calls VampifyPerHit.hit(...)/.incoming(...)/
-- .selfheal(...)/.extheal(...)/.onTick(...) with values it already has; this file registers NO
-- event listeners of its own and needs no new ones in capture/*.lua.
--
-- hp_max (follow-up change request, 2026-08-22). Overheal windows are otherwise invisible to offline analysis: at
-- full health the Vampirism heal lands and immediately overflows, so hp_after - hp_before reads 0
-- even though pred_heal > 0 -- indistinguishable, from the numbers alone, from the heal genuinely
-- not landing (a real model deviation). hp_max fixes that: with hp_before/hp_max/pred_heal an
-- offline reader can tell "delta=0 because hp_before was already at/near hp_max" apart from
-- "delta=0 and hp_before had headroom -- something is actually wrong". Read via
-- UnitHealthMax("player") at the SAME point as hp_before (when the hit is recorded, not when the
-- window closes) -- hp_max does not change mid-fight under anything this addon cares about, so
-- there is no "before/after" question for it the way there is for hp itself, and reading it
-- alongside hp_before costs nothing new (no event, one more already-cheap API call at a point that
-- already reads UnitHealth).
--
-- hp_before / hp_after. Vampirism heals with NO event of its own (that is the addon's entire
-- reason to exist), so the only way to see it land is to read UnitHealth("player") before and
-- after. "Before" is the health at the moment this hit's damage event fires (before the healing
-- from THIS hit can possibly have landed). "After" is NOT available at that same instant --
-- 1.12's event order gives no signal for "the heal from this hit has now applied" -- so it is
-- read at the EARLIEST of two things that already exist in commands.lua: the next own damage
-- event (closing this hit's row the same way the HP-reconciliation watchdog already closes its
-- windows, core/watch.lua's "Stage 2" comment), or the next OnUpdate throttle tick (~0.25s) if no
-- further hit arrives in time. A hit right before combat ends is force-closed on
-- PLAYER_REGEN_ENABLED/PLAYER_DEAD (PH.closeWindow) so nothing is left pending across a long idle
-- period -- see PH.closeWindow's own comment for why that does NOT also force a disk write.
-- CONSEQUENCE FOR ANALYSIS: hp_after is a snapshot up to ~0.3s after the hit, not an
-- exact "immediately after this heal" read -- it can include a second hit's healing (or unrelated
-- incoming damage) if events land close together. Treat hp_after - hp_before as "what happened in
-- the window this hit opened", not as an exact isolation of this one heal; the /vf watch balance
-- (core/watch.lua) exists for the same reason and has the same caveat.
--
-- WHAT IS NOT COVERED. The retroactive AoE correction (VampifyDamage.onAoECorrection,
-- commands.lua) rewrites an already-recorded hit's healing after the fact once a second target
-- proves it was AoE -- but by the time that fires, this channel's line for the original hit may
-- already be flushed to disk. Reopening a flushed line is out of scope (this is an append-only
-- export, like every other channel in this addon); a hit that gets corrected will show its
-- ORIGINAL (non-AoE) aoe=0/pred_heal in its own HIT line. Cross-reference against
-- vampify_watch.txt / the session's own knowledge of which spells proc AoE if this matters to a
-- specific analysis.

VampifyPerHit = {}
local PH = VampifyPerHit

-- ---- pure: buffer + formatting ------------------------------------------------------------------

-- Hard safety cap on the in-memory buffer, independent of the flush thresholds below. Normal
-- operation flushes long before this; it exists so a flush that somehow never fires (ExportFile
-- missing, disk full) degrades into "oldest lines drop" instead of unbounded growth -- the same
-- discipline as core/watch.lua's WATCH_LOG_MAX, sized larger here because a per-hit line is
-- shorter and AoE grinding can produce 30-60 hits/sec.
local RING_CAP = 2000
PH.RING_CAP = RING_CAP

-- A hit is force-closed (hp_after read "now") if no further own hit arrives within this long.
-- Set just above the 0.25s display throttle commands.lua already runs PH.onTick from, so an
-- isolated hit's hp_after is captured on the very next tick rather than staying open until
-- whatever hit happens to come next (which could be seconds later, or never, in that fight).
local PENDING_TIMEOUT = 0.3
PH.PENDING_TIMEOUT = PENDING_TIMEOUT

function PH.newState()
    return {
        enabled      = false,
        sid          = nil,
        chunk        = 0,
        buf          = {},
        pending      = nil,
        totalHits    = 0,
        totalFlushed = 0,
        elapsed      = 0,
    }
end

-- Only acts on a TRANSITION. Turning on (re)seeds sid/chunk/buffer/counters -- a fresh instrument
-- read, not a continuation of whatever a previous /vf perhit on..off cycle left behind. Turning
-- off leaves sid/chunk/buf alone on purpose: the caller (PH.disable) still needs them to flush
-- the final chunk under the SAME sid/chunk index the session was using.
function PH.setEnabled(state, on, sid)
    on = on and true or false
    if on == state.enabled then return state.enabled end
    if on then
        state.sid, state.chunk = sid, 0
        VampifyConst.resetList(state.buf)   -- see resetList's own comment: nil-ing indices alone
                                            -- leaves table.getn reading a stale n in Lua 5.0
        state.pending = nil
        state.totalHits, state.totalFlushed, state.elapsed = 0, 0, 0
    end
    state.enabled = on
    return state.enabled
end

-- table.remove (not a hand-rolled shift) to evict the oldest line: it keeps `n` in step, the same
-- reasoning core/watch.lua's watchLine gives for using it over nil-ing indices by hand.
function PH.pushLine(state, line)
    table.insert(state.buf, line)
    if table.getn(state.buf) > RING_CAP then
        table.remove(state.buf, 1)
    end
end

-- The INDIVIDUAL source percentages of the hit, as "3/2/2/2".
--
-- WHY IT HAD TO BE ADDED (offline analysis, 2026-08-30). The line carried only the SUMMED
-- percentage P and the source count n, and the server truncates every source SEPARATELY
-- (core/model.lua's header): max(1, floor(pct_i * damage / 100)) per source. From P and n alone
-- that is not reconstructable -- an offline reader has to approximate the list as n equal shares,
-- which is exactly VampifyModel.heal's documented-inexact compatibility shape. Measured against
-- the recorded pred_heal over 4907 windows that approximation is off by 4.7 %, and 4.7 % is the
-- same order as the effects the analysis is trying to separate. With the real list the offline
-- model becomes exact instead of approximate, and the AoE-ordering question core/model.lua's
-- header leaves open (damp the damage, or damp each source's heal) becomes decidable from
-- recorded data rather than needing a new in-game measurement.
--
-- "%g", not "%d" or "%.2f": a source percentage is normally a small integer (3, 2, 2) and should
-- print as one, but nothing guarantees it -- a fractional percentage must survive rather than be
-- silently truncated into a wrong number.
--
-- Buffer-recycled like every other reused list here (VampifyConst.resetList's comment): this runs
-- once per own hit, and a fresh table per hit is avoidable churn on a channel that is meant to run
-- permanently. The caller's list is READ ONLY -- and the result is a STRING, which matters: the
-- live source list is itself a recycled buffer (core/commands.lua's sourcePercents, refilled in
-- place on every gear change), so a row may not hold a reference to it. Serialising here, at
-- record time, is what keeps a buffered row from silently re-reading a list that has since changed.
local pctBuf = {}
function PH.formatPercents(list)
    if not list then return "" end
    local n = table.getn(list)
    for i = table.getn(pctBuf), n + 1, -1 do pctBuf[i] = nil end
    table.setn(pctBuf, n)
    for i = 1, n do pctBuf[i] = string.format("%g", list[i] or 0) end
    return table.concat(pctBuf, "/", 1, n)
end

-- pcts / zone / cast are the three fields the offline analysis asked for (docs/
-- VAMPIRISM-MODELL-STAND §4). All three are optional: an older caller that does not supply them
-- still produces a well-formed line ("", "?" and 0), so the export never depends on every wiring
-- site having been updated in the same change.
--
-- cast=1 means a SPELL_GO_SELF for THIS spell id arrived shortly before this hit -- i.e. the player
-- CAST it. cast=0 means no cast announced it, which for a damaging spell is the signature of a
-- proc. That distinction is the whole point: hypothesis H2 says Vampirism is fed by the TRIGGER
-- PATH ("was this triggered by an aura") rather than by "is this an item proc", and the cast event
-- is the one observable in the client that separates the two paths for the same spell id. Without
-- it the offline classification has to be inferred from timing against Lightning Strike hits and
-- incoming damage, which is what the current analysis does and why it can only report AMBIG for
-- 13.4 % of Tidal Wave hits.
function PH.formatHitLine(row)
    return string.format(
        "HIT|t=%.3f|src=%s|dmg=%d|aoe=%d|P=%.4f|n=%d|pred_heal=%.4f|hp_before=%s|hp_after=%s|"
        .."hp_max=%s|acc_total=%.4f|crit=%d|pcts=%s|zone=%s|cast=%d",
        row.t, row.src, row.dmg, (row.aoe and 1 or 0), row.P, row.n, row.pred_heal,
        tostring(row.hp_before), tostring(row.hp_after), tostring(row.hp_max), row.acc_total,
        (row.crit and 1 or 0), row.pcts or "", row.zone or "?", (row.cast and 1 or 0))
end

function PH.formatIncomingLine(row)
    return string.format("INC|t=%.3f|dmg=%.4f", row.t, row.dmg)
end

function PH.formatSelfHealLine(row)
    return string.format("SELFHEAL|t=%.3f|heal=%.4f", row.t, row.heal)
end

-- Foreign healing landing on the player -- exactly the healing that contaminates a group /vf watch
-- window (see capture/incoming.lua's header comment), kept as its own line instead of folded into
-- SELFHEAL so it is measurable rather than invisible. Same shape/skip rule as formatSelfHealLine.
function PH.formatExternalHealLine(row)
    return string.format("EXTHEAL|t=%.3f|heal=%.4f", row.t, row.heal)
end

-- Closes whatever hit is currently open (if any): stamps hp_after, formats and pushes its line,
-- clears the pending slot. Called from three places: the NEXT hit (below), the OnUpdate timeout
-- (PH.tick), and a forced flush (PH.flushNow/PH.disable) -- exactly one of these will ever close
-- a given pending row, since each clears it before returning.
function PH.finalizePending(state, hpNow)
    local p = state.pending
    if not p then return false end
    p.hp_after = hpNow
    PH.pushLine(state, PH.formatHitLine(p))
    state.pending = nil
    return true
end

-- fields: t, src, dmg, aoe, P, n, pred_heal, acc_total, crit, pcts, zone, cast -- everything
-- except the health readings, which this function supplies itself: hp_before = hpNow and
-- hp_max = hpMaxNow are both stamped HERE, at the same point, and never touched again; hp_after
-- comes later, at finalize.
--
-- fields.pcts is the LIVE source-percent list and is serialised HERE, not held. The row can sit
-- pending (and then buffered) for a long time, and that list is a recycled buffer refilled in
-- place whenever gear changes -- keeping the reference would make an already-recorded hit report
-- whatever the source set happens to be at flush time. Same reasoning as the health readings
-- above: a value that describes THIS hit is captured at this hit.
function PH.recordHit(state, fields, hpNow, tNow, hpMaxNow)
    PH.finalizePending(state, hpNow)
    state.pending = {
        t = fields.t, src = fields.src, dmg = fields.dmg, aoe = fields.aoe,
        P = fields.P, n = fields.n, pred_heal = fields.pred_heal,
        acc_total = fields.acc_total, crit = fields.crit,
        pcts = PH.formatPercents(fields.pcts), zone = fields.zone, cast = fields.cast,
        hp_before = hpNow, hp_max = hpMaxNow, pendingAt = tNow,
    }
    state.totalHits = state.totalHits + 1
end

-- Force-closes a pending hit once it has sat open longer than PENDING_TIMEOUT with no follow-up
-- event to close it the normal way. Returns true if it actually closed one, for the tests.
function PH.tick(state, hpNow, tNow)
    if state.pending and (tNow - state.pending.pendingAt) >= PENDING_TIMEOUT then
        return PH.finalizePending(state, hpNow)
    end
    return false
end

-- Zero/nil incoming damage or self-heal in a window is the common case (most windows have
-- neither) and is skipped rather than emitted as a line of noise -- an absent INC/SELFHEAL line
-- for a given HIT IS the "nothing happened" signal for offline analysis.
function PH.recordIncoming(state, t, dmg)
    if not dmg or dmg == 0 then return false end
    PH.pushLine(state, PH.formatIncomingLine({ t = t, dmg = dmg }))
    return true
end

function PH.recordSelfHeal(state, t, heal)
    if not heal or heal <= 0 then return false end
    PH.pushLine(state, PH.formatSelfHealLine({ t = t, heal = heal }))
    return true
end

function PH.recordExternalHeal(state, t, heal)
    if not heal or heal <= 0 then return false end
    PH.pushLine(state, PH.formatExternalHealLine({ t = t, heal = heal }))
    return true
end

function PH.chunkName(sid, chunkIdx)
    return "vampify_perhit_" .. tostring(sid) .. "_" .. tostring(chunkIdx)
end

function PH.chunkHeader(version, sid, chunkIdx, lineCount)
    return string.format("addon=Vampify version=%s chunk=%d sid=%s lines=%d",
        tostring(version), chunkIdx, tostring(sid), lineCount)
end

-- Pure half of a flush: builds the chunk's name and full text (header + every buffered line),
-- advances the chunk index, and empties the buffer -- all without touching ExportFile, so it is
-- testable without any WoW stub. Returns (nil, nil) when there is nothing to flush.
function PH.takeFlushText(state, version)
    local lineCount = table.getn(state.buf)
    if lineCount == 0 then return nil, nil end
    local name = PH.chunkName(state.sid, state.chunk)
    local header = PH.chunkHeader(version, state.sid, state.chunk, lineCount)
    local text = header .. "\n" .. table.concat(state.buf, "\n") .. "\n"
    state.chunk = state.chunk + 1
    state.totalFlushed = state.totalFlushed + lineCount
    VampifyConst.resetList(state.buf)
    return name, text
end

-- ---- session-local singleton + disk flush --------------------------------------------------
--
-- The module's OWN default is still disabled -- every addon load starts VampifyPerHit._state at
-- PH.newState()'s enabled=false, and this file never reads VampifyConfig. What makes the channel
-- actually run every session is core/commands.lua's syncPerHit(), called on every
-- PLAYER_LOGIN/PLAYER_ENTERING_WORLD, which reads VampifyDB.perhitEnabled (core/config.lua,
-- default true) and calls PH.enable()/.disable() accordingly -- the same "module stays
-- config-agnostic, the wiring layer bridges to SavedVariables" split core/model.lua and the rest
-- of core/*.lua already use.

VampifyPerHit._state = PH.newState()

-- Flush when the buffer reaches this many lines, or this many seconds have passed, whichever
-- comes first -- the same two-trigger shape (flush-on-count / flush-on-timer) used by a companion
-- capture addon's own chunk-rotation library, the reference pattern this mirrors. Deliberately NOT
-- reusing that library itself: this channel needs neither its chunked wire protocol (nothing
-- ingests these chunks automatically) nor its multi-producer plumbing, and pulling it in would be
-- exactly the kind of heavy new subsystem this channel is meant to avoid.
--
-- SIZED FOR PERMANENT OPERATION (follow-up change request, 2026-08-22: default on, runs every session, not
-- just an armed-by-hand dev probe). LibEmpBus's own FLUSH_SEC=2 is right for ITS job -- feeding a
-- near-realtime backend watcher -- but nothing ingests these chunks automatically, and the addon
-- cannot delete old ones (no filesystem delete from Lua). A short interval that flushed whatever
-- was buffered, even one line, would turn "grind mobs one at a time so combat drops between
-- pulls" into a file per kill. 500/60s bounds a busy AoE pull to a handful of chunks (a line is
-- ~130 bytes; 500 lines is ~65 KB) while keeping the worst-case unflushed tail small if the
-- client vanishes without a clean logout (PLAYER_CAMPING/PLAYER_QUITING force a flush too, see
-- core/commands.lua). See the addon's PR notes for the resulting bytes/hour estimate.
PH.FLUSH_LINES = 500
PH.FLUSH_SECS  = 60

local function flushToDisk()
    if not ExportFile then return end          -- SuperWoW only; harmless without it
    local name, text = PH.takeFlushText(VampifyPerHit._state, VampifyConst.VERSION)
    -- ExportFile appends .txt itself -- name must NOT already carry it (see core/const.lua's
    -- writeErrors for the same gotcha).
    if name then ExportFile(name, text) end
end

function PH.isEnabled()
    return VampifyPerHit._state.enabled
end

function PH.status()
    local s = VampifyPerHit._state
    return {
        enabled      = s.enabled,
        sid          = s.sid,
        chunk        = s.chunk,
        buffered     = table.getn(s.buf),
        totalHits    = s.totalHits,
        totalFlushed = s.totalFlushed,
    }
end

-- time() is a WoW global (used the same way by a companion capture addon); math.floor(GetTime())
-- is the fallback for an environment that somehow has GetTime but not time(). Session id only
-- has to be unique enough to tell two /vf perhit on sessions' chunks apart on disk, not globally
-- unique.
function PH.enable()
    if PH.isEnabled() then return false end
    local sid = time and time() or math.floor(GetTime and GetTime() or 0)
    PH.setEnabled(VampifyPerHit._state, true, sid)
    return true
end

-- Finalizes whatever hit is still open and force-flushes the current chunk, THEN turns the
-- channel off -- so /vf perhit off never strands the last hit's hp_after in memory.
function PH.disable(hpNow)
    if not PH.isEnabled() then return false end
    PH.finalizePending(VampifyPerHit._state, hpNow)
    PH.setEnabled(VampifyPerHit._state, false)
    flushToDisk()
    return true
end

-- Same finalize+flush as disable(), without turning the channel off -- for a point that needs a
-- GUARANTEED write regardless of the size/time thresholds (currently only /vf perhit off and a
-- real logout/camp -- see core/commands.lua's PLAYER_CAMPING/PLAYER_QUITING handling).
function PH.flushNow(hpNow)
    if not PH.isEnabled() then return end
    PH.finalizePending(VampifyPerHit._state, hpNow)
    flushToDisk()
end

local function maybeFlush()
    if table.getn(VampifyPerHit._state.buf) >= PH.FLUSH_LINES then flushToDisk() end
end

-- Finalizes a pending hit WITHOUT forcing a disk write -- for combat end. A hit right before
-- PLAYER_REGEN_ENABLED must not be left open across what could be a long idle gap until the next
-- fight (same reasoning as flushNow), but forcing a chunk to disk on every single fight is exactly
-- the "file per kill" permanent-operation problem FLUSH_LINES/FLUSH_SECS above exist to avoid --
-- several short fights' hits accumulate in the SAME buffer until one of those thresholds fires
-- naturally. maybeFlush() still applies: a fight big enough to cross FLUSH_LINES on its own closes
-- its own chunk immediately, same as it would mid-fight.
function PH.closeWindow(hpNow)
    if not PH.isEnabled() then return end
    PH.finalizePending(VampifyPerHit._state, hpNow)
    maybeFlush()
end

-- fields: see PH.recordHit. Cost when the channel is off is one isEnabled() check and nothing
-- else -- no table built, no line formatted.
function PH.hit(fields, hpNow, tNow, hpMaxNow)
    if not PH.isEnabled() then return end
    PH.recordHit(VampifyPerHit._state, fields, hpNow, tNow, hpMaxNow)
    maybeFlush()
end

function PH.incoming(t, dmg)
    if not PH.isEnabled() then return end
    if PH.recordIncoming(VampifyPerHit._state, t, dmg) then maybeFlush() end
end

function PH.selfheal(t, heal)
    if not PH.isEnabled() then return end
    if PH.recordSelfHeal(VampifyPerHit._state, t, heal) then maybeFlush() end
end

function PH.extheal(t, heal)
    if not PH.isEnabled() then return end
    if PH.recordExternalHeal(VampifyPerHit._state, t, heal) then maybeFlush() end
end

-- Driven from the SAME 0.25s OnUpdate throttle core/commands.lua already runs everything else
-- from -- no new frame, per the project's OnUpdate-allocation rule. dt (elapsed since the last
-- tick) feeds the time-based flush trigger; hpNow/tNow close a pending hit that never got a
-- follow-up event (PH.tick's PENDING_TIMEOUT).
function PH.onTick(hpNow, tNow, dt)
    if not PH.isEnabled() then return end
    PH.tick(VampifyPerHit._state, hpNow, tNow)
    local s = VampifyPerHit._state
    s.elapsed = s.elapsed + (dt or 0)
    if s.elapsed >= PH.FLUSH_SECS then
        s.elapsed = 0
        flushToDisk()
    end
end
