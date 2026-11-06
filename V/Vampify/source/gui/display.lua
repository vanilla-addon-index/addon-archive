-- Vampify -- the one-line display.
--
-- Shows total + HPS + the equipped sources' combined Vamp percentage with their count. Per-source
-- detail lives in /vf status, not on screen.
--
-- Compact-bar rewrite (follow-up change request, 2026-08-22). The line used to open with a "> Vamp " prefix
-- (a bound glyph plus the addon's own name) and end with the SESSION heal/damage ratio
-- (stats.pct, still computed by VampifyAggregate.fight -- see V.format's own comment for why that
-- figure and the one shown here are not the same thing). Both are gone now, with nothing put back
-- in their place: the prefix
-- because the bar already IS Vampify (nothing else lives at that screen position), and the ratio
-- because it answers "how much came back this session" rather than "what is the gear configured to
-- return", which is what a player glancing at the bar while re-gearing actually wants. The bound
-- glyph itself (V.boundFlag) is untouched and still tested below -- only its wiring into this line
-- was removed; nothing currently calls it.

VampifyDisplay = {}
local V = VampifyDisplay

-- Which set the mouseover breakdown currently shows: "session" (since login, the default),
-- "lifetime" (never auto-resets), or "last" (the current-or-most-recently-completed fight, third
-- tab added 2026-08-25 -- "ebenso dritten detailtab einfuegen: last"). A field on V rather than a
-- file-local, so it is reachable from both V.build() and V.showTooltip() regardless of which is
-- defined first in this file -- see the comment on frame:SetScript("OnMouseUp", ...) below for why
-- that ordering actually bites in Lua 5.0. Not persisted: it is a display preference, not data, and
-- resets to "session" on reload.
--
-- Tab order [SESSION | LIFETIME | LAST], LAST appended rather than inserted first: SESSION stays
-- the login default (unchanged muscle memory for anyone already used to the two-tab toggle), and a
-- single right-click still lands on LIFETIME exactly as it always has -- LAST costs one extra click
-- to reach instead of reordering two tabs people already navigate today. Putting LAST first (it is
-- arguably the most frequently needed tab) is a reasonable alternative too; this is the more
-- conservative of the two, not the only defensible one.
V.tipScope = "session"

-- Normalizes any V.tipScope value to one of the three real scopes, defaulting an unrecognised or
-- nil value to "session" (the same "session is the safe default" convention
-- core/commands.lua's VampifyResetSession already uses for its own scope argument) -- a single
-- choke point so every reader below agrees on what an invalid scope means instead of each
-- reimplementing its own fallback.
function V.normalizeScope(scope)
    if scope == "lifetime" or scope == "last" then return scope end
    return "session"
end

-- True unless `scope` is "last" and the core-side last-fight read API has not shipped yet
-- (mandatory fallback for when core/ has not yet added last-fight support). Gated on
-- VampifyAggregate.resetScope's
-- PRESENCE specifically, not on VampifyAggregate.spellBreakdown's (which already existed, boolean-
-- only, before "last" existed) -- resetScope is a brand new symbol that ships in the exact same
-- core/aggregate.lua change as "last" scope support in every read function, so its presence is a
-- reliable, cheap capability probe: trusting spellBreakdown/splitTotals/spellSplit/
-- spellSourceBreakdown's OWN "last" branch without this guard would, against an un-upgraded core,
-- silently read a DIFFERENT scope's real data (a truthy third argument reads as lifetime under the
-- old boolean-only spellBreakdown; an unrecognised scope string falls through to session in the
-- other three) and label it "Last" -- wrong data shown with confidence is worse than an honest
-- empty panel, so this is checked before trusting any of the four "last" calls below.
function V.lastScopeReady()
    return VampifyAggregate ~= nil and type(VampifyAggregate.resetScope) == "function"
end

-- Rotates through the tab order [SESSION | LIFETIME | LAST] -- the single right-click handler on
-- the compact bar (V.build's frame:OnMouseUp) and every scope-toggle button's own OnClick funnel
-- through this one function, so the two input paths can never disagree on what "next scope" means.
-- Pure (no WoW call, no VampifyAggregate read) and offline-testable on its own.
function V.nextScope(scope)
    if scope == "session" then return "lifetime" end
    if scope == "lifetime" then return "last" end
    return "session"
end

-- Each ability's share of the TOTAL Vampirism healing, in percent, one decimal.
--
-- Moved to core/model.lua as VampifyModel.shareOfTotal (2026-08-24) -- core/aggregate.lua needed
-- the same largest-remainder rounding and calling this gui/ function from core/ was backwards
-- (core/ must not depend on gui/). Kept here as a thin alias: everything in this file already
-- calls it as V.shareOfTotal, and the offline tests reference that name directly.
V.shareOfTotal = VampifyModel.shareOfTotal

-- Copies V.shareOfTotal's per-row percentages into a CALLER-OWNED buffer, immediately, before
-- anything else runs. Exists because of an in-game bug (2026-08-24, post-mockup pass): V.shareOfTotal
-- (== VampifyModel.shareOfTotal, core/model.lua:255-307) returns a POOLED, MODULE-LEVEL buffer --
-- not a copy -- and VampifyAggregate.spellSplit/.splitTotals/.spellSourceBreakdown ALSO call into
-- that exact same pooled function internally, for their own unrelated ST/AoE-of-ONE-row rounding
-- (core/aggregate.lua's local roundSplit). A caller that reads V.shareOfTotal's result across a
-- loop that ALSO calls any of those three functions (as the row loop below now does, for each
-- row's two-color bar) gets the buffer overwritten -- and truncated to a couple of elements --
-- out from under it after the very first iteration: every row after the first read a stale or
-- absent value. Reproduced and pinned by an existing regression test (that test's own header
-- comment has the full trace).
-- Every call site that reads a share array across more than one statement now snapshots it here
-- FIRST -- see V.showTooltip and V.buildDetailLines below.
function V.snapshotShares(shares, n, out)
    out = out or {}
    local i
    for i = 1, n do out[i] = shares[i] or 0 end
    for i = n + 1, table.getn(out) do out[i] = nil end
    return out
end


function V.boundFlag(channels, aoeAvailable)
    local lower = false
    if channels then
        for _, state in pairs(channels) do
            if state == "undecided" then lower = true end
        end
    end
    local upper = not aoeAvailable
    if lower and upper then return "uncertain" end
    if lower then return "lower" end
    if upper then return "upper" end
    return nil
end

-- Sum + round pass for V.formatSources below -- the compact bar's own gear-percent segment reuses
-- V.formatSources directly (2026-08-24 in-game feedback pass dropped a separate, "Gear"-suffixed
-- wording that used to live here: a redundant unit suffix, since
-- V.formatSources's bare "9% (4)" already says the same thing shorter). Whole number when it lands
-- exactly on one, otherwise one decimal place (rounded to one decimal first, which also kills the float noise a
-- repeated sum can pick up).
local function sumSourcesPct(sources)
    sources = sources or {}
    local n = table.getn(sources)
    local sum = 0
    for i = 1, n do sum = sum + (sources[i] or 0) end
    local r = math.floor(sum * 10 + 0.5) / 10
    local pctStr
    if r == math.floor(r) then
        pctStr = string.format("%d%%", r)
    else
        pctStr = string.format("%.1f%%", r)
    end
    return pctStr, n
end

-- sources: the per-source percent list (e.g. {3, 2, 2, 2}) that feeds core/commands.lua's own
-- sourcePercents -- VampifyDetect.getSources() plus manual overrides, reached here via
-- VampifyState.sourcePercents (see commands.lua's comment on that assignment). Summed and counted
-- HERE rather than read back from commands.lua's sumPercent/nSources fraction: those are computed
-- as sum/100 in capture/detect.lua's D.summarise and would have to be multiplied by 100 again to
-- get back to percent units, a round-trip this function has no reason to repeat when the source
-- list it needs anyway is right there.
function V.formatSources(sources)
    local pctStr, n = sumSourcesPct(sources)
    return pctStr.." ("..n..")"
end

-- stats.overheal is optional: nil or 0 leaves the line exactly as it was before overheal existed
-- (callers that never set it, and the existing tests, must see no difference). Vampirism emits no
-- heal event, so overheal here is CALCULATED from the health deficit at hit time (see
-- VampifyModel.effective / VampifyState.effHeal), not measured -- it is exactly as trustworthy as
-- that deficit read, no more.
--
-- sources is passed straight to V.formatSources -- see that function's comment for where it comes
-- from and why it replaces stats.pct (the session heal/damage ratio) on this line.
function V.format(stats, sources)
    stats = stats or {}
    local oh = ""
    if stats.overheal and stats.overheal > 0 then
        oh = string.format(" (%d OH)", math.floor(stats.overheal))
    end
    return string.format("%d%s | %.1f HPS | %s",
        math.floor(stats.heal or 0), oh, stats.hps or 0, V.formatSources(sources))
end

-- ---- compact-bar segment formatters (mockup redesign, 2026-08-24) -----------------------------
--
-- The bar used to be ONE FontString rendering V.format's whole line. The mockup segments it --
-- heal(+OH), an ST/AoE badge group, "<hps> HPS" (colored), then the gear percent -- each of which
-- needs its OWN FontString so it can be individually colored, hidden, or reflowed when a segment
-- is absent. These are the pure text pieces the WoW-wiring shell below (V.build/V.update) places
-- into that many FontStrings; V.format itself is UNCHANGED (still the old single-line text) --
-- nothing in this file calls it any more, but an existing regression test still pins
-- its exact behaviour, so it stays rather than being repurposed out from under that test.

-- "608" -- no "Heal" word and no icon (2026-08-24, in-game feedback pass: the leading
-- blood-drop icon was purely decorative, and the word was redundant with it -- the number is the
-- first, most prominent thing on the bar in a Vampirism-only addon; nothing else it could be
-- needs saying).
--
-- The "(N OH)" suffix this used to carry is GONE (2026-08-24 pixel measurement pass: the
-- bar's plain text alone measured 457px against a 340px frame, and this suffix was pure length
-- with no length budget to spend -- the same figure already lives in the row-detail panel and the
-- breakdown panel's own Total line, so nothing is actually lost, only de-duplicated off the
-- bar). stats.overheal itself is intentionally left untouched by this change -- V.update still
-- computes it (cfg.showOverheal also drives a SEPARATE combat-text feature outside this file, see
-- gui/options.lua's cbOverheal), this function just no longer reads it.
function V.formatHealSegment(stats)
    stats = stats or {}
    return V.formatAmount(stats.heal or 0)
end

-- "27.2 HPS" -- its own segment (rather than folded into V.format's one string) so the WoW-wiring
-- shell can color it independently (green, per the mockup) without re-coloring the rest of the bar.
-- Kept its unit suffix (unlike the heal/gear segments) -- "HPS" is not redundant here, it is the
-- one thing telling this number apart from every OTHER bare number on the bar.
function V.formatHpsSegment(stats)
    stats = stats or {}
    return string.format("%.1f HPS", stats.hps or 0)
end

-- ST/AoE badge-group text for the compact bar, from VampifyAggregate.splitTotals's `out` shape
-- (out.stHeal, .aoeHeal, .total, .stPct, .aoePct -- the VampifyAggregate.splitTotals interface this
-- file programs against). `out` is the ALREADY-POPULATED table (the
-- WoW-wiring shell calls splitTotals itself and passes the result here), not the function -- same
-- injection convention as V.buildDetailLines' ctx.* callbacks, kept pure and testable with a plain
-- stub table. Returns nil, nil when there is nothing to show: out itself absent (splitTotals not
-- wired up yet -- the fallback contract, "badge group hidden, rest of the bar stays") or
-- out.total <= 0 (nothing measured yet -- must not fabricate a 0 ST / 0 AoE badge pair).
--
-- History: first shortened from "29.7k ST | 2.9k AoE (9%)" (measured 119px for the AoE half
-- ALONE) down to bare k-notation amounts as the pill's adjoining value label; NOW UNUSED by the
-- wiring entirely (2026-08-24, fourth correction, in-game report: the adjoining numbers were
-- redundant with the pill and the main reason the bar overshot its own compactness target). Kept as
-- a pure, tested formatter (same convention as V.format above -- a prior generation's bar text,
-- superseded but not deleted) in case some future compact surface wants bare ST/AoE k-values
-- again without a third competing formatter being written from scratch.
function V.formatBadgeGroup(out)
    if not out or not out.total or out.total <= 0 then return nil, nil end
    return V.formatAmount(out.stHeal or 0), V.formatAmount(out.aoeHeal or 0)
end

-- ---- two-color proportional bar geometry -------------------------------------------------------
--
-- Shared pixel-width math for every two-color bar this redesign adds: the breakdown panel's own
-- ST/AoE split row, and each ability row's two-color fill (see V.buildDetailLines' neighbourhood
-- below for -- no, see the WoW-wiring shell's setRow -- where both call this).
--
-- rightW is the COMPLEMENT of leftW (maxW - leftW), never independently rounded off leftPct's own
-- twin percentage -- that is what keeps a 100/0 or 0/100 split exact (no stray 1px sliver of the
-- empty color) and guarantees the two segments always tile the full maxW with no gap or overlap
-- regardless of rounding noise in leftPct/rightPct themselves not summing to exactly 100.
-- maxW <= 0, or both percentages <= 0 (nothing to show -- e.g. a spell with zero recorded heal),
-- returns 0, 0 -- callers are expected to have already decided whether to draw/show the bar at all
-- (see the panel's total==0 guard in V.showTooltip below), but this stays safe even if one calls it
-- anyway rather than divide-by-zero or hand back a negative width.
function V.splitBarWidths(maxW, leftPct, rightPct)
    maxW = maxW or 0
    leftPct = leftPct or 0
    rightPct = rightPct or 0
    if maxW <= 0 or (leftPct <= 0 and rightPct <= 0) then return 0, 0 end
    local leftW = math.floor(maxW * (leftPct / 100) + 0.5)
    if leftW < 0 then leftW = 0 end
    if leftW > maxW then leftW = maxW end
    return leftW, maxW - leftW
end

-- V.pillSegments (the cap-width-clamp math for the compact-bar pill's rounded ends) is REMOVED
-- (in-game correction: drop the rounded ends entirely -- the pill lost its end caps
-- entirely, see gui/display.lua's layoutPill/buildPill for the current rectangular shape). Its
-- whole reason to exist was deciding how a share narrower than one cap gets clamped up, and how a
-- share of exactly 0 recolors its own now-orphaned cap -- neither question exists any more with no
-- caps to clamp or recolor. The pill's geometry is now exactly V.splitBarWidths above (unchanged),
-- already used elsewhere in this file for the same "two segments summing to a bar width" shape and
-- already covered by the existing splitBarWidths regression tests -- nothing else needed
-- porting. The old test file that tested only this function is deleted along
-- with it rather than left testing a function that no longer exists.

-- x-offset (from whatever origin `rightEdge`/`minX` are themselves measured from) to draw a
-- RIGHT-ANCHORED label of pixel width `textW`, so its right edge lands `pad` px inside `rightEdge`
-- -- regardless of how narrow the color segment it visually sits over is. Fixes a real bug (in-game
-- report, 2026-08-24): the split row's AoE label used to anchor to its OWN segment's left edge, so at a
-- narrow AoE share the label (wider than its own segment) ran out past the panel's right border.
-- Anchoring the label to a FIXED boundary (the bar's own right edge, not the segment's) instead
-- means it can never run off that side no matter how small the segment gets.
-- Clamped at the OTHER end too (`minX`) -- a label wider than the whole available span is pushed
-- back to minX rather than given a negative offset, which would run it off the panel's LEFT side
-- instead: "never overflow" means both directions, not just the one that was reported.
function V.rightAnchoredLabelX(rightEdge, textW, pad, minX)
    pad = pad or 0
    minX = minX or 0
    local x = (rightEdge or 0) - pad - (textW or 0)
    if x < minX then x = minX end
    return x
end

-- Chooses which of the split row's two label variants fits INSIDE a color segment of width segW,
-- so the label never lies about which segment it belongs to by spilling onto its neighbour
-- (2026-08-24 pixel measurement pass, Finding 5: the label must stay inside its own color segment
-- -- measured, the AoE label used to right-anchor to the BAR's fixed right edge
-- (V.rightAnchoredLabelX above) regardless of its OWN segment's width, so a narrow AoE share
-- (9%) put 42 of the label's pixels on top of the blue ST fill it does not belong to).
-- V.rightAnchoredLabelX is NOT wrong and stays in use elsewhere (the panel's row-detail value
-- labels, which sit on a FIXED-width row, not a variable-width color segment) -- this is a
-- different problem: here the available space itself shrinks with the segment.
--
-- Two-tier degradation, both measured against the ACTUAL segment (not the whole bar):
--   1. full   "Single-Target: 29.7k (91%)" -- used if it fits with `pad` clearance on both sides
--   2. short  "29.7k"                       -- the bare amount, if the full label does not fit
--   3. nil                                  -- neither fits (segment too thin even for the bare
--      amount) -- caller hides the label rather than draw truncated/overlapping text; the
--      segment's own COLOR still shows something is there, which is honest -- a hidden number
--      beats a lying one.
-- textWidthFn(text) -- injected (FontString:GetStringWidth in production) so this stays pure.
function V.pickSplitLabel(fullText, shortText, segW, pad, textWidthFn)
    pad = pad or 0
    segW = segW or 0
    local fullW = textWidthFn(fullText)
    if segW >= fullW + 2 * pad then return fullText, fullW end
    local shortW = textWidthFn(shortText)
    if segW >= shortW + 2 * pad then return shortText, shortW end
    return nil, nil
end

-- "575" (< 1000, unabbreviated) / "14.0k" (1000 <= |n| < 1,000,000, one decimal) / "8.8M"
-- (|n| >= 1,000,000, one decimal).
--
-- THE addon-wide large-number formatter (2026-08-24 in-game feedback, superseding an
-- earlier thousands-separator ask: switch to a "k" suffix once a value reaches the thousands -- and,
-- for the million range, use "8.8M" rather than the ugly "8790.0k" that "k" alone would produce
-- for 8790016). Used
-- EVERYWHERE a large number is shown -- compact bar, split row, ability rows, the panel's Total
-- line, the row-detail panel -- rather than a second, competing formatter per screen: this file
-- used to have a narrower version of exactly this ("V.formatSplitAmount", the split row's own two
-- labels only) which is now just this function under its general name; every other call site
-- switched to it rather than growing its own.
--
-- One decimal at both the k and M scale -- enough to tell close values apart (14.0k vs 14.3k)
-- without turning into a second exact number; the whole point is a number a reader can take in at
-- a glance. Ratio is deliberately NOT this formatter's job any more (follow-up in-game feedback,
-- 2026-08-24: the ratio is already readable straight off the graphical bar)
-- -- the bar length already carries that, so this only ever needs to carry the MAGNITUDE.
-- 1,000,000 (not "whenever the k-form would print 4+ integer digits") is the fixed M threshold --
-- a predictable cutover a reader can learn once, rather than one that moves around depending on
-- the exact value.
--
-- Handles a negative input (sign preserved, magnitude formatted the same way) even though nothing
-- in this addon's own data can currently go negative -- cheap defensiveness, not a real case.
function V.formatAmount(n)
    n = n or 0
    local sign = ""
    if n < 0 then
        sign = "-"
        n = -n
    end
    if n >= 1000000 then
        return sign .. string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return sign .. string.format("%.1fk", n / 1000)
    end
    -- Floored, not rounded, below 1000 -- matches this addon's own established convention
    -- (V.format's overheal branch, V.formatIdLine, ... all "floored, matching the accumulator,
    -- never rounded up") for exact, unabbreviated numbers: a displayed figure must never claim
    -- more than what has actually accumulated. Abbreviated k/M values above DO round (a normal
    -- printf %.1f) -- losing sub-unit precision is already the deal at that scale, and this
    -- matches the pre-existing formatSplitAmount behaviour nothing ever complained about.
    return sign .. tostring(math.floor(n))
end

-- "Single-Target: 28.4k (61%)" / "AoE Cleave: 18.2k (39%)" -- the split row's own two half-labels.
function V.formatSplitLabel(kind, heal, pct)
    return string.format("%s: %s (%d%%)", kind, V.formatAmount(heal), math.floor((pct or 0) + 0.5))
end

-- Two spell ids can carry the same name (two ranks of Lightning Strike showed up as separate rows
-- in-game). Merges the per-spell breakdown (VampifyAggregate.spellBreakdown's rows, keyed by spell
-- id) onto the name the player actually distinguishes -- but keeps every merged-away id reachable,
-- as out[j].ids, a list of { spell, damage, heal, overheal, hits }, biggest healer first WITHIN the
-- row. A single-spell row still gets a one-element ids list, so a caller never has to special-case
-- "was this name backed by one spell or several".
--
-- File scope rather than nested inside the CreateFrame block below (where it used to live, as a
-- bare local): it is pure Lua over its two table arguments plus VampifyConst, exactly like
-- V.shareOfTotal/V.formatSources/V.format above, and belongs with them so it can be exercised
-- offline without a CreateFrame stub.
--
-- POOLING at both levels, same convention as VampifyAggregate.spellBreakdown and VampifyConst.
-- resetList: the panel repaints on every hover-enter, on the right-click scope toggle, and --
-- while pinned -- at most once a second via V.update's own gate (V.shouldRepaintPin, see below),
-- so neither the row entries nor their ids sublists are rebuilt from scratch when the ability set
-- is unchanged from the previous call -- only a comparator would need to look past
-- `used`/`table.getn`, and this file's own sort loops already do.
local function mergeIdEntry(ids, idx, r)
    local e = ids[idx]
    if not e then e = {}; ids[idx] = e end
    e.spell = r.spell
    e.damage = r.damage
    e.heal = r.heal
    e.overheal = r.overheal or 0
    e.hits = r.hits or 0
    return e
end

function V.mergeByName(rows, out)
    local n, used = table.getn(rows), 0
    for i = 1, n do
        local r = rows[i]
        local name = VampifyConst.spellName(r.spell)
        local hit = nil
        for j = 1, used do
            if out[j].name == name then hit = out[j]; break end
        end
        if hit then
            hit.damage   = hit.damage + r.damage
            hit.heal     = hit.heal + r.heal
            hit.overheal = hit.overheal + (r.overheal or 0)
            hit.hits     = hit.hits + (r.hits or 0)
            local idsN = table.getn(hit.ids)
            mergeIdEntry(hit.ids, idsN + 1, r)
            table.setn(hit.ids, idsN + 1)
        else
            used = used + 1
            local e = out[used]
            if not e then e = { ids = {} }; out[used] = e end
            e.name     = name
            e.damage   = r.damage
            e.heal     = r.heal
            e.overheal = r.overheal or 0
            e.hits     = r.hits or 0
            VampifyConst.resetList(e.ids)
            mergeIdEntry(e.ids, 1, r)
            table.setn(e.ids, 1)
        end
    end
    for i = used + 1, table.getn(out) do out[i] = nil end
    table.setn(out, used)

    -- Re-sort after merging: two merged halves can outrank a row that was above both.
    for i = 2, used do
        local e, j = out[i], i - 1
        while j >= 1 and out[j].heal < e.heal do out[j + 1] = out[j]; j = j - 1 end
        out[j + 1] = e
    end

    -- Within each row, the ids sublist is sorted biggest healer first too -- independent of the
    -- row order above, since a row's own rank says nothing about which of its ids contributed most.
    for i = 1, used do
        local ids = out[i].ids
        local m = table.getn(ids)
        for a = 2, m do
            local e, b = ids[a], a - 1
            while b >= 1 and ids[b].heal < e.heal do ids[b + 1] = ids[b]; b = b - 1 end
            ids[b + 1] = e
        end
    end
    return out
end

-- Each row's share of the LARGEST single row's heal, in percent (0..100, the biggest row always
-- reads 100) -- NOT share of the total (that is still V.shareOfTotal/VampifyModel.shareOfTotal,
-- untouched, still used for the id-level percentages in the row-detail panel). This is BAR-LENGTH
-- math only (2026-08-24 pixel measurement pass, Finding 1): share-of-total was being used to
-- size the ability-row bars, so even the single largest ability only ever reached ~19% of the
-- panel's width -- 80% of every bar's own space sat empty, and the ability NAME (drawn to the
-- right of the bar in the old column layout, now drawn INSIDE it, see setRow below) overran the
-- bar in 9 of 10 rows because the bar itself was starved of the width the name needed to sit
-- inside. Share-of-max fixes that by construction: the biggest healer gets the FULL row width, and
-- every other row is sized relative to it -- the same normalization Details!/Recount/ShaguDPS use,
-- and the reason "icon+name inside the bar" works there. The underlying PERCENT-OF-TOTAL figure
-- (what actually gets shown, where it is still shown -- e.g. via V.shareOfTotal for id-level
-- shares) is completely unchanged by this function; only how a row's LENGTH is derived changes.
--
-- out: caller-owned, filled in place (positions 1..n set, anything past n cleared) -- no pooled
-- module-level buffer of its own, unlike VampifyModel.shareOfTotal, precisely BECAUSE that pooled-
-- buffer design already caused one real in-game bug (see V.snapshotShares' own header
-- comment for the full trace) -- this function sidesteps the whole hazard class by never owning
-- state a second caller could read out from under a first one.
function V.shareOfMax(rows, out)
    out = out or {}
    local n = table.getn(rows)
    local maxHeal = 0
    local i
    for i = 1, n do
        local h = rows[i].heal or 0
        if h > maxHeal then maxHeal = h end
    end
    for i = 1, n do
        if maxHeal > 0 then
            out[i] = ((rows[i].heal or 0) / maxHeal) * 100
        else
            out[i] = 0
        end
    end
    for i = n + 1, table.getn(out) do out[i] = nil end
    return out
end

-- How many individual ability rows the breakdown panel draws before collapsing the rest into one
-- "Other (N)" row (Finding 4, 2026-08-24: a real character's ~21 tracked abilities would draw
-- a 581px-tall panel with sub-4px slivers for the smallest rows). ONE named constant, so the panel
-- height/row count is changed in exactly one place, not re-derived at each call site.
V.TOP_ROWS = 8

-- Caps `merged` (V.mergeByName's already-sorted, biggest-healer-first output) at V.TOP_ROWS real
-- rows, folding whatever is left into ONE synthetic "Other (N)" row at the end -- summed damage/
-- heal/overheal/hits, and every folded-away row's OWN ids concatenated onto the Other row's ids
-- list (reusing mergeIdEntry, the same per-id copy mergeByName itself uses). That last part is
-- what makes "hover the Other row and see what is in it" work for free: V.buildDetailLines already
-- walks entry.ids and resolves each id's own name/damage/heal via ctx.nameFn -- an id merged in
-- from a folded-away ability is a real spell id with real per-ability numbers, so the existing
-- detail-panel code lists it correctly with no special-casing, exactly as if it were one more rank
-- of a multi-rank spell (which is the whole reason mergeIdEntry already existed).
--
-- out[V.TOP_ROWS + 1] (the Other row itself, when one exists) is a POOLED, PERSISTENT table reused
-- across repaints, same convention as mergeByName's own out[used] reuse above -- only its fields
-- are overwritten each call, the table identity itself does not change. rowMeta.isOther (read by
-- setRow in the WoW-wiring shell below) is what tells the Other row apart from a real ability row
-- so it renders in a distinct neutral color rather than a fabricated ST/AoE split of a row that,
-- by construction, mixes many unrelated abilities (visually more subdued, since it mixes ST and
-- AoE).
function V.buildTopRows(merged, n, out)
    n = n or V.TOP_ROWS
    out = out or {}
    local total = table.getn(merged)
    local keep = total
    if keep > n then keep = n end
    local i
    for i = 1, keep do
        out[i] = merged[i]
    end
    if total > n then
        local other = out[n + 1]
        if not other then other = { ids = {}, isOther = true }; out[n + 1] = other end
        other.name = "Other (" .. (total - n) .. ")"
        other.damage, other.heal, other.overheal, other.hits = 0, 0, 0, 0
        other.isOther = true
        VampifyConst.resetList(other.ids)
        local idsUsed = 0
        for i = n + 1, total do
            local r = merged[i]
            other.damage   = other.damage + r.damage
            other.heal     = other.heal + r.heal
            other.overheal = other.overheal + (r.overheal or 0)
            other.hits     = other.hits + (r.hits or 0)
            local ids = r.ids
            local m = table.getn(ids)
            local j
            for j = 1, m do
                idsUsed = idsUsed + 1
                mergeIdEntry(other.ids, idsUsed, ids[j])
            end
        end
        table.setn(other.ids, idsUsed)
        table.setn(out, n + 1)
    else
        for i = keep + 1, table.getn(out) do out[i] = nil end
        table.setn(out, keep)
    end
    return out
end

-- ---- row-detail panel: pure text-building --------------------------------------------------
--
-- The row-detail panel (hover a data row in the PINNED breakdown -> a second panel with per-id
-- origin, hit averages, effective rate, overheal, and the other scope's totals) is built from the
-- functions below, every one of them pure Lua returning a string (or nil, meaning "the frame layer
-- omits this line"). None of them touch CreateFrame, VampifyConst, or any WoW API -- the data they
-- need (item-origin lookup, spellbook name set, spell-name lookup) is INJECTED by the caller, same
-- reasoning as VampifyConst.spellName being reached for only inside mergeByName above and not
-- baked into these. That keeps them exercisable offline exactly like V.shareOfTotal/V.format, and
-- keeps the WoW-API shell (further down, inside the CreateFrame guard) a thin adapter that only
-- supplies the real functions/tables and calls these to get text.

-- id -> { kind = "item"|"ability"|"unknown", label = <string already worded for display> }.
--
-- itemOriginFn(id): the item-proc lookup (VampifyConst.itemProcOrigin in production) -- returns an
-- item name or nil. Tried FIRST: a proc id can never itself be a spellbook entry, but if some
-- future id were resolvable both ways, the item is the more specific fact and
-- wins.
-- spellbookSet: a set (name -> true) of the player's current spellbook, built by the WoW-API shell
-- from GetSpellName(i, BOOKTYPE_SPELL); membership is checked by NAME, not id, because spellbook
-- slot indices are not spell ids and the shell has no cheaper way to ask "is this ability mine".
-- nameFn(id): VampifyConst.spellName in production -- may return nil for an unresolved id, which
-- must read as "no spellbook match", not error.
function V.resolveOrigin(id, itemOriginFn, spellbookSet, nameFn)
    local itemName = itemOriginFn and itemOriginFn(id)
    if itemName then
        return { kind = "item", label = "Item: " .. itemName }
    end
    local name = nameFn and nameFn(id)
    if name and spellbookSet and spellbookSet[name] then
        return { kind = "ability", label = "Class ability" }
    end
    return { kind = "unknown", label = "origin unknown (#" .. tostring(id) .. ")" }
end

-- One ability-id's own line: "<name> (#<id>)  <damage> dmg, <heal> vamp, <share>%". damage/heal
-- go through V.formatAmount (k/M-notation once they run large, 2026-08-24 in-game feedback --
-- see that function's own header comment); share is already a percent (largest-remainder rounded
-- by V.shareOfTotal, one decimal here to match the main panel's own percent column).
function V.formatIdLine(name, id, damage, heal, sharePct)
    return string.format("%s (#%d)  %s dmg, %s vamp, %.1f%%",
        name, id, V.formatAmount(damage or 0), V.formatAmount(heal or 0), sharePct or 0)
end

-- "hits: <n>  (avg <dmg/hit> dmg -> <heal/hit> vamp per hit)", or an explicit not-recorded line
-- for hits == 0 -- legacy rows (persisted before the hit counter existed) carry hits == 0, not
-- nil (see VampifyAggregate.spellBreakdown's own comment), so this must not read hits == 0 as
-- "zero hits landed" and print a bogus "avg 0 dmg -> 0 vamp".
function V.formatHitsLine(hits, damage, heal)
    hits = hits or 0
    if hits <= 0 then return "hits: not recorded yet" end
    return string.format("hits: %d  (avg %s dmg -> %s vamp per hit)",
        hits, V.formatAmount((damage or 0) / hits), V.formatAmount((heal or 0) / hits))
end

-- Classifies a row's effective return rate against the equipped gear's source total: "floor" when
-- the row returns MORE than gear would predict (the per-hit floor is binding -- small hits still
-- return at least one HP per source), "aoe" when it returns LESS, "neutral" within +/-0.2
-- percentage points of gear (the tolerance band matches the panel's own note text on the main
-- breakdown, gui/display.lua's V.showTooltip).
--
-- NAMING NOTE (bug fix, in-game report 2026-08-25, Earth Shock #10414 -- a pure single-target
-- spell whose detail panel showed "(AoE damping)" purely because its measured rate sat below gear,
-- with no AoE hit ever recorded for it): "aoe" here is ONLY a numeric direction (below gear beyond
-- tolerance), never a causal claim by itself. AoE damping is one of SEVERAL possible reasons a rate
-- can sit below its gear nominal -- a lower spell rank (smaller hits let the per-hit floor bite
-- harder, or simply a different true rate), a per-source floor rounding a small hit up, a gear
-- change mid-session against a now-stale nominal, or partial resist/absorb bookkeeping -- and this
-- function has no way to tell which. V.formatRateLine below is the one place that turns "aoe" into
-- WORDS, and it now only says "AoE damping" when the caller hands it POSITIVE evidence (an actual
-- classified AoE hit) that AoE is the real cause -- see its own comment.
function V.classifyRate(effectivePct, gearPct)
    local diff = effectivePct - gearPct
    if diff > 0.2 then return "floor" end
    if diff < -0.2 then return "aoe" end
    return "neutral"
end

-- Effective return rate, in percent, from heal/damage -- shared by V.formatRateLine and
-- V.formatFloorBadge below so both agree on the same number without either recomputing it
-- differently. 0 for zero/negative damage rather than dividing by zero.
function V.effectiveRatePct(heal, damage)
    if not damage or damage <= 0 then return 0 end
    return (heal or 0) / damage * 100
end

-- "Return: <eff>% vs <gearPct>% Nominal" plus an explanatory parenthetical when applicable, or nil
-- when there is no gear percent to compare against (an empty/zero VampifyState.sourcePercents
-- omits the line entirely rather than printing "vs 0% Nominal", which would misread as "everything
-- is AoE-damped"). Badge-worded (2026-08-24 badge pass) -- the floor-binding case used
-- to carry its own parenthetical here too; it is now the separate standalone V.formatFloorBadge
-- below, so a floor-binding row does not say the same thing twice across two lines.
--
-- hasAoeHits/idCount (bug fix, in-game report 2026-08-25 -- see V.classifyRate's own comment
-- for the Earth Shock symptom this answers): the parenthetical is now chosen by CHECKING PROVABLE
-- causes, in order, never by guessing from the rate alone --
--   1. hasAoeHits true (this row has at least one hit VampifyAggregate.spellSplit actually
--      classified as off-target, in the CURRENT scope): "(AoE damping)" -- the one case with direct
--      evidence.
--   2. hasAoeHits false but idCount > 1 (the row merges more than one spell id -- V.mergeByName
--      folds every rank of the same-named spell into one row): "(mixed ranks)" -- downranking is a
--      real, PROVABLE-FROM-THE-DATA alternative cause (a lower rank's smaller hits
--      let the per-hit floor bite harder, dragging a blended average down even with zero AoE) --
--      more than one id under one name IS direct evidence multiple ranks were actually cast, not a
--      guess.
--   3. Neither: "(unexplained)" -- chosen over silently dropping the parenthetical (which would
--      read as "this number is unremarkable") and over asserting either cause without evidence --
--      an honest "we do not know why" beats a confident wrong answer.
function V.formatRateLine(heal, damage, gearPct, hasAoeHits, idCount)
    if not gearPct or gearPct <= 0 then return nil end
    local eff = V.effectiveRatePct(heal, damage)
    local cls = V.classifyRate(eff, gearPct)
    local suffix = ""
    if cls == "aoe" then
        if hasAoeHits then
            suffix = "  (AoE damping)"
        elseif idCount and idCount > 1 then
            suffix = "  (mixed ranks)"
        else
            suffix = "  (unexplained)"
        end
    end
    return string.format("Return: %.1f%% vs %.1f%% Nominal%s", eff, gearPct, suffix)
end

-- One merged-id's OWN effective return rate ("-> 12.3% return this rank"), shown ONLY for a row
-- that merges more than one spell id (V.buildDetailLines gates the call on idCount > 1) -- a
-- single-id row already gets this exact number from the row-level "Return: X% vs Y% Nominal" line,
-- so repeating it per id there would say the same thing twice. For a multi-rank row the row-level
-- rate is a BLENDED average across differently-sized hits (see V.formatRateLine's "(mixed ranks)"
-- comment); this exposes each rank's own number so a player can see directly whether one specific
-- rank is the one dragging the blend down, rather than only being told the blend exists. nil for
-- zero/negative damage (no rate to show), same guard as V.effectiveRatePct.
function V.formatIdRateLine(heal, damage)
    if not damage or damage <= 0 then return nil end
    return string.format("  -> %.1f%% return this rank", (heal or 0) / damage * 100)
end

-- "Multiple ranks combined (N)" note, shown once near the top of a merged row's detail (right after
-- the split-status note) when idCount > 1 -- nil for a single-id row (nothing to disclose). Pure
-- disclosure, not a diagnosis: it states the provable fact (more than one spell id landed under
-- this name) without claiming that fact explains any particular number -- V.formatRateLine's own
-- "(mixed ranks)" parenthetical is where that connection, when applicable, actually gets made.
function V.formatMultiRankNote(idCount)
    if not idCount or idCount <= 1 then return nil end
    return "Multiple ranks combined (" .. idCount .. ") -- the return rate below is a blended"
        .. " average across differently-sized hits; see each rank's own line for its individual rate."
end

-- Greedy word wrap into pieces that each measure at most maxWidth.
--
-- Exists because gui/display.lua's row-detail panel lays its lines out on a fixed cursor -- one
-- DETAIL_LINE_H slot per line ENTRY -- while a FontString handed a long string wraps on its own and
-- silently grows past that slot, drawing the next entry on top of its own overflow (in-game report,
-- 2026-08-25: overlapping text, the "Multiple ranks combined (13)" note over the two rows
-- below it). Splitting the entry BEFORE it reaches the cursor makes the renderer's "one entry = one
-- slot" assumption true instead of merely assumed; it is not a workaround for a missing measurement
-- API, it is the layout contract.
--
-- Deliberately NOT built on the client measuring the wrapped result for us: 1.12 has no
-- GetStringHeight (that is a 2.3.0 addition), and FontString:GetHeight() does not reliably report a
-- wrapped height -- both confirmed in-game. GetStringWidth, which
-- this function's `measure` is in the client, DOES exist and returns the string's SINGLE-LINE width
-- regardless of any SetWidth -- exactly the primitive a greedy wrap needs.
--
-- measure(text) -> width. Any measure that cannot answer (returns nil -- GetStringWidth does that
-- before a region's first render pass) collapses the whole thing to one unsplit piece, which is the
-- safe direction: the caller is expected to supply its own fallback metric for that case rather
-- than have this function invent one. Always returns at least one piece, so a caller iterating the
-- result can never silently lose a line (and, with it, that line's bar).
function V.wrapText(text, maxWidth, measure)
    if not text or text == "" then return { "" } end
    if not maxWidth or maxWidth <= 0 or not measure then return { text } end
    local probe = measure(text)
    if not probe then return { text } end
    if probe <= maxWidth then return { text } end

    -- Splits one word that does not fit on a line of its own into character-sized chunks. Without
    -- this the piece would be handed to the client over-long and wrapped THERE, which is the very
    -- overflow this function exists to prevent. Grows a chunk one character at a time and closes it
    -- one character before it would break the budget; a budget too narrow for even one character
    -- would loop forever, so a chunk is never allowed to close empty.
    local function splitWord(word, out)
        local chunk = ""
        local i
        for i = 1, string.len(word) do
            local ch = string.sub(word, i, i)
            local grown = chunk .. ch
            if chunk ~= "" and measure(grown) > maxWidth then
                table.insert(out, chunk)
                chunk = ch
            else
                chunk = grown
            end
        end
        if chunk ~= "" then table.insert(out, chunk) end
    end

    local out = {}
    local line = ""
    -- string.gfind, not gmatch: gmatch is 5.1+ and is a nil call under the client's Lua 5.0.
    local word
    for word in string.gfind(text, "%S+") do
        if line == "" then
            if measure(word) > maxWidth then
                splitWord(word, out)
                -- splitWord's last chunk stays open as the current line, so the next word can still
                -- join it rather than starting a needless new one.
                line = out[table.getn(out)] or ""
                table.remove(out)
            else
                line = word
            end
        elseif measure(line .. " " .. word) <= maxWidth then
            line = line .. " " .. word
        else
            table.insert(out, line)
            if measure(word) > maxWidth then
                splitWord(word, out)
                line = out[table.getn(out)] or ""
                table.remove(out)
            else
                line = word
            end
        end
    end
    if line ~= "" then table.insert(out, line) end
    if table.getn(out) == 0 then return { text } end
    return out
end

-- Standalone "[Floor Active]" marker for a row whose effective return sits above gear beyond
-- V.classifyRate's tolerance band -- the per-hit floor is binding (small hits still return at least
-- one HP per source). Same gating as V.formatRateLine (no gear percent -> nil) and the same
-- effective-rate math (V.effectiveRatePct); kept as its own function rather than a second return
-- value off formatRateLine so both stay a plain string-or-nil the frame layer can push() as-is.
function V.formatFloorBadge(heal, damage, gearPct)
    if not gearPct or gearPct <= 0 then return nil end
    local eff = V.effectiveRatePct(heal, damage)
    if V.classifyRate(eff, gearPct) ~= "floor" then return nil end
    return "[Floor Active]"
end

-- "<oh> HP (<oh/heal>% lost)", or nil when there is nothing to report -- mirrors V.format's own
-- overheal branch (gui/display.lua above), which likewise shows nothing for oh <= 0 rather than an
-- "(0 OH)" that would clutter every row.
function V.formatOverhealLine(oh, heal)
    oh = oh or 0
    if oh <= 0 then return nil end
    local pct = 0
    if heal and heal > 0 then pct = oh / heal * 100 end
    return string.format("%s HP (%.1f%% lost)", V.formatAmount(oh), pct)
end

-- The row's twin figure from the OTHER scope (session<->lifetime): "<scope>: <dmg> dmg, <heal>
-- vamp" when a same-named row exists there, else "no <scope> data". `row` is nil or a merged row
-- (same shape as V.mergeByName's output) already looked up by the caller in a SEPARATE pooled
-- buffer -- see the WoW-wiring section below for why it must not reuse tipBuf/mergeBuf.
function V.formatOtherScopeLine(scopeName, row)
    if not row then return "no " .. scopeName .. " data" end
    return string.format("%s: %s dmg, %s vamp",
        scopeName, V.formatAmount(row.damage or 0), V.formatAmount(row.heal or 0))
end

-- Combines an already-resolved origin (V.resolveOrigin's return shape) with the id it belongs to
-- into ONE self-contained badge line -- "[Item: <name>] #<spellid>" / "[Class ability] #<spellid>"
-- -- so a reader looking at just this line does not have to glance back at the id line above it to
-- know which spell id it is talking about (2026-08-24 badge pass -- the two used to be
-- separate, only loosely connected lines).
--
-- Returns NIL (no line at all) for kind=="unknown" -- in-game correction: why does this show
-- "origin unknown"? (asked about spell 41825 "Tidal Wave"). Investigated: V.resolveOrigin has only
-- two positive buckets (an item-proc match via C.ORIGINS, or a name match against the player's
-- VISIBLE spellbook via GetSpellName) -- neither is a bug, but together they cannot see a genuine
-- third category: a hidden/passive proc effect that is never granted to the spellbook at all
-- (verified: 41825 is a custom server-side passive damage proc off the Water Shield buff,
-- not a talent and not a castable spell -- structurally invisible to GetSpellName's walk; no known
-- 1.12 API or list closes this gap, and building one is a separate, larger task, not this fix).
-- "[origin unknown] #41825" read as "we don't even know what this spell is" -- false, its NAME is
-- already shown correctly one line above (V.formatIdLine). The honest fix, per the agreed fallback
-- (show the spell name and id without the misleading origin claim): make no origin claim
-- at all when there is none to make, rather than dress up "we could not classify this" as if it
-- were "we do not know what this is". The caller's own push() helper already no-ops on a nil text
-- (V.buildDetailLines), so returning nil here is enough to simply omit the line.
function V.formatOriginBadge(origin, spellId)
    if origin.kind == "item" or origin.kind == "ability" then
        return "[" .. origin.label .. "] #" .. tostring(spellId)
    end
    return nil
end

-- One row from ctx.sourceBreakdownFn's per-id item-source breakdown (the pure-function contract for
-- the not-yet-built VampifyAggregate.spellSourceBreakdown -- see V.buildDetailLines below for the
-- fallback when it is absent). Expected row shape: { label, heal, share (0..100), floorHits, ... }.
-- "<label>  <heal> HP  <share>%" plus an inline "[Floor Active]" marker when the row reports floor
-- hits. share is also carried on the pushed line's own `bar` field (see V.buildDetailLines) -- the
-- WoW-wiring shell draws a mini fill bar from that; this function only ever produces text.
function V.formatSourceRowLine(row)
    local mark = ""
    if row.floorHits and row.floorHits > 0 then mark = "  [Floor Active]" end
    return string.format("%s  %s HP  %.1f%%%s",
        row.label or "?", V.formatAmount(row.heal or 0), row.share or 0, mark)
end

-- "Target split not yet determined for this source." -- shown in the row-detail panel for a row
-- whose main-panel bar is drawn in the NEUTRAL goldSoft color (hasSplit=false) rather than red/
-- blue, so the color difference has a stated reason instead of just looking different with none.
-- In-game correction (about Lightning Strike and Frostbrand Attack specifically): why do those
-- show a brown tint instead of the usual red?
--
-- INVESTIGATED, not assumed: this is NOT a proc-vs-direct-cast classification bug. Read core/
-- commands.lua's onDamage listener (core/, out of scope to change here) -- there is exactly ONE
-- call path from VampifyDamage.onDamage into VampifyAggregate.recordSpell, and it computes
-- notOnTarget (true/false, never nil) for EVERY landed hit regardless of spell id -- procs and
-- direct casts both go through capture/damage.lua's single emit() and this one recordSpell call,
-- no spell-id-based branching anywhere in that path. core/aggregate.lua's A.recordSpell only sets
-- spSplitSeen[k]=true once a hit with a KNOWN notOnTarget has actually LANDED for that spell id
-- since the ST/AoE split feature's own redefinition (its own header comment names this "legacy"
-- case explicitly: a row untouched since the redefinition reads as hasSplit=false, not as "this
-- spell cannot be classified"). Both named abilities are low-frequency item/weapon procs (Storm
-- Gauntlets' Lightning Strike, a weapon enchant's Frostbrand Attack) -- their EXISTING accumulated
-- totals most likely predate a fresh proc landing since that redefinition, which is a data-recency
-- fact, not a defect. Noted for the core/ side's own records; this note is the gui/-
-- side mitigation for the case where that fact holds: explain the color instead of leaving it
-- unexplained.
--
-- Excludes the "Other (N)" row (isOther) -- that row's own grey fill is a DIFFERENT, already-
-- understood case (deliberately mixed abilities, Finding 4), not "not yet determined".
function V.formatSplitStatusNote(hasSplit, isOther)
    if hasSplit or isOther then return nil end
    return "Target split not yet determined for this source (no classified hit landed yet)."
end

-- Assembles the WHOLE detail panel's content for one merged row (V.mergeByName's output shape),
-- in the order the panel prints them: name header, then (if the row's own bar is drawn neutral
-- rather than red/blue -- see V.formatSplitStatusNote above) a note explaining why, then per-id
-- lines (own numbers + indented origin), then the row's hit average, effective rate vs gear,
-- overheal, and the other scope's total. Returns an array of
-- { text = <string>, color = <VampifyWidgets.COLORS key as a string> } -- a color KEY rather than
-- the color table itself, so this stays a pure function of its arguments (no W/VampifyWidgets
-- reference) and the frame layer resolves W.COLORS[key] at render time. ctx fields: itemOriginFn,
-- spellbookSet, nameFn (passed straight through to V.resolveOrigin), gearPct, otherScopeName,
-- otherScopeRow (see V.formatRateLine/V.formatOtherScopeLine above for their meaning), hasSplit
-- (the SAME hasSplit the main panel's own bar color already used for this row -- see
-- V.formatSplitStatusNote's own header comment for why the two must never disagree).
-- ctx.sourceBreakdownFn: OPTIONAL injected function(spellId) -> a table shaped like
-- VampifyAggregate.spellSourceBreakdown's `out` (rows 1..out.n, each { label, heal, share, ... }),
-- or nil. Same injection convention as ctx.itemOriginFn/ctx.spellbookSet/ctx.nameFn above -- this
-- function never calls VampifyAggregate itself, so it stays pure and testable with a plain stub.
-- Absent, or returning nil/n==0, simply omits the item-source section for that id -- the rest of
-- the panel (name, id lines, origins, hits, rate, overheal, other-scope) never depends on it.
function V.buildDetailLines(entry, ctx)
    local lines, n = {}, 0
    local function push(text, color, bar)
        if not text then return end
        n = n + 1
        lines[n] = { text = text, color = color, bar = bar }
    end

    local ids = entry.ids or {}
    local m = table.getn(ids)

    push(entry.name, "goldHi")
    push(V.formatSplitStatusNote(ctx.hasSplit, entry.isOther), "faint")
    -- Downranking disclosure (2026-08-25, same in-game report as the Earth Shock AoE-damping
    -- fix): a row this many ids merges genuinely COMBINED more than one spell rank -- see
    -- V.formatMultiRankNote's own header comment. Placed right after the split-status note (both
    -- are "here is a caveat about the number below", read together before the per-id lines).
    push(V.formatMultiRankNote(m), "faint")

    -- Snapshotted immediately -- ctx.sourceBreakdownFn (called inside this same loop, below) is
    -- bound to VampifyAggregate.spellSourceBreakdown in production, which ALSO calls into
    -- VampifyModel.shareOfTotal's pooled buffer internally. See V.snapshotShares' own header
    -- comment for the full hazard and V.showTooltip below for the sibling instance of this fix.
    local shares = V.snapshotShares(V.shareOfTotal(ids), m, {})
    for i = 1, m do
        local idE = ids[i]
        local name = (ctx.nameFn and ctx.nameFn(idE.spell)) or "?"
        push(V.formatIdLine(name, idE.spell, idE.damage, idE.heal, shares[i] or 0), "ink")
        local origin = V.resolveOrigin(idE.spell, ctx.itemOriginFn, ctx.spellbookSet, ctx.nameFn)
        local color = "dim"
        if origin.kind == "item" then color = "goldSoft"
        elseif origin.kind == "unknown" then color = "faint" end
        -- formatOriginBadge returns nil for kind=="unknown" now (no misleading claim to print) --
        -- guard the concatenation itself, not just push()'s own nil-guard: "  " .. nil would throw
        -- before push ever saw the nil (Lua evaluates concat's operands before the call).
        local badge = V.formatOriginBadge(origin, idE.spell)
        if badge then push("  " .. badge, color) end
        -- Per-rank rate, ONLY when there is more than one rank to distinguish (V.formatIdRateLine
        -- itself has no such gate -- a single-id row already gets this exact figure from the
        -- row-level Return line below, see that function's own comment).
        if m > 1 then push(V.formatIdRateLine(idE.heal, idE.damage), "dim") end

        if ctx.sourceBreakdownFn then
            local src = ctx.sourceBreakdownFn(idE.spell)
            if src and src.n and src.n > 0 then
                push("  Sources:", "faint")
                local si
                for si = 1, src.n do
                    local row = src[si]
                    push("    " .. V.formatSourceRowLine(row), "dim", row.share)
                end
            end
        end
    end

    push(V.formatHitsLine(entry.hits, entry.damage, entry.heal), "dim")
    push(V.formatRateLine(entry.heal, entry.damage, ctx.gearPct, ctx.hasAoeHits, m), "ink")
    push(V.formatFloorBadge(entry.heal, entry.damage, ctx.gearPct), "warn")
    push(V.formatOverhealLine(entry.overheal, entry.heal), "warn")
    push(V.formatOtherScopeLine(ctx.otherScopeName, ctx.otherScopeRow), "dim")

    return lines
end

-- Pure time-gate for the breakdown panel's periodic self-repaint WHILE SHOWN (2026-08-23,
-- originally the pin feature's own follow-up: with no button and no event driving a repaint, the
-- panel was a frozen snapshot of the moment it was last hovered). Kept under its original name
-- (V.shouldRepaintPin/V.PIN_REPAINT_INTERVAL -- an existing regression test pins both)
-- even though the 2026-08-24 hover-chain redesign replaced the PIN it was originally gated on with
-- "shown at all" (see V.update below) -- the gate itself is unchanged, only what triggers it.
-- V.update (WoW wiring below) is already called ~2x/s by the throttle in core/commands.lua -- NOT
-- changed here, this addon has no business touching that file's cadence -- and calls this on every
-- one of those ticks to decide whether ANOTHER repaint is due, at most once a second, independent
-- of and slower than that outer throttle. Pure function of (last repaint time, now) so the gate
-- itself is testable without GetTime()/a frame.
V.PIN_REPAINT_INTERVAL = 1.0
function V.shouldRepaintPin(lastTime, now)
    return (now - (lastTime or 0)) >= V.PIN_REPAINT_INTERVAL
end

-- ---- hover chain: pure state machine (mockup redesign, 2026-08-24; pulled out of the WoW-wiring
-- section 2026-08-24 after an in-game "stuck open" report -- see this block's own trailing comment
-- for the investigation) --------------------------------------------------------------------------
--
-- Replaces the old click-to-pin mechanism (V.tipPinned/releaseTipPin) with a hover-intent chain
-- modelled on Blizzard's own nested-submenu timer, FrameXML/UIDropDownMenu.lua:70-102
-- (UIDropDownMenu_Start/StopCounting + _OnUpdate) -- ONE shared countdown across the whole panel
-- chain (bar -> breakdown -> row detail -> a future "detail of detail"), started by ANY level's
-- OnLeave and stopped by ANY level's OnEnter. That single shared flag is exactly what makes moving
-- the mouse from one panel to an ADJACENT one (their screen rects touch but do not overlap -- the
-- row-detail panel sits beside the breakdown panel, not inside it) safe: the leaving frame's
-- OnLeave starts the timer, the arriving frame's OnEnter cancels it again before a tick ever finds
-- showTimer has actually run out.
--
-- Diverges from Blizzard's own OnUpdate on purpose (2026-08-24): Blizzard always hides the
-- WHOLE menu regardless of which submenu was left (menus are click-to-act -- abandoning any part
-- of the chain means abandoning the interaction). This is a read-only DATA panel instead: leaving
-- the row-detail panel while the mouse is still on the breakdown panel must close only the detail
-- panel, not the breakdown underneath it. leave(level) remembers which level was left; tick, on
-- expiry, closes that level and everything nested under it -- but never level 1 (the compact bar
-- itself), which this mechanism only ever triggers OFF of, never hides: the bar's own shown/hidden
-- state is V.show()/V.hide(), independent of hovering.
--
-- A CONSTRUCTOR (V.newChain), not a singleton table -- unlike this file's other WoW-bound pooled
-- state (tipRows, mergeBuf, ...), this is pure data + pure functions, no CreateFrame anywhere in
-- it, so an offline test can build a FRESH chain per test instead of sharing one mutable global
-- across the whole suite. The real addon still only ever builds ONE (inside the CreateFrame guard
-- below), same as before.
function V.newChain()
    return { levels = {}, maxLevel = 0, isCounting = false, showTimer = 0, pendingCloseFrom = nil }
end

V.HOVER_GRACE = 0.5

-- level: 2 = breakdown panel, 3 = row detail (a future level 4, "detail of detail", is a single
-- V.chainRegister call away -- V.chainTick's own loop already adapts to chain.maxLevel, no other
-- change needed). Level 1 (the bar) is never registered -- see the header comment above for why it
-- is never a close target.
function V.chainRegister(chain, level, hideFn)
    chain.levels[level] = hideFn
    if level > chain.maxLevel then chain.maxLevel = level end
end

-- OnEnter anywhere in the chain -- stops the ONE shared countdown, wherever it currently targets.
-- No level argument: Blizzard's own StopCounting does not take one either (it walks to the root
-- and clears one shared flag), and this file's countdown is exactly as shared.
function V.chainEnter(chain)
    chain.isCounting = false
end

-- OnLeave anywhere in the chain -- (re)starts the shared countdown, targeting a close FROM this
-- level DOWNWARD once it expires (see V.chainTick below).
function V.chainLeave(chain, level)
    chain.pendingCloseFrom = level
    chain.showTimer = V.HOVER_GRACE
    chain.isCounting = true
end

-- Ticked every frame from the bar's own OnUpdate (see V.build) -- a single field read the
-- overwhelming majority of frames, since isCounting is only true while a leave() is pending and
-- has not since been cancelled by a later enter() (this file's own guardrail on a sparing
-- OnUpdate handler -- this is the "early return" it asks for).
function V.chainTick(chain, elapsed)
    if not chain.isCounting then return end
    chain.showTimer = chain.showTimer - (elapsed or 0)
    if chain.showTimer < 0 then
        chain.isCounting = false
        local from = chain.pendingCloseFrom
        chain.pendingCloseFrom = nil
        if from then
            local start = from
            if start < 2 then start = 2 end
            local i
            for i = start, chain.maxLevel do
                local hideFn = chain.levels[i]
                if hideFn then hideFn() end
            end
        end
    end
end

-- ---- hover chain: in-game "stuck open" investigation (2026-08-24) ---------------------------
--
-- Report (in-game, one of several offered symptom descriptions): a panel gets stuck open -- it no
-- longer closes when the mouse leaves, or a detail panel stays visible while the panel above it
-- has already closed.
--
-- CHECKED AND RULED OUT (with evidence, not assumed): the strongest initial suspicion --
-- that the OnUpdate handler unregisters itself (SetScript(nil)) when idle and is not reliably
-- re-registered on the next OnLeave. Grepped the whole file for "SetScript(nil)": zero matches.
-- The handler was ALREADY written as a registered-forever, cheap-early-return handler (V.chainTick
-- itself, first line: "if not chain.isCounting then return end") -- the unregister/reregister
-- pattern was never implemented in the first place, so it cannot be the cause here.
--
-- FOUND (by reading, not guessed): several mouse-enabled BUTTON children sit INSIDE chain-
-- registered frames' own rectangles (the bar's options/reset buttons inside `frame`; the
-- breakdown panel's [SESSION|LIFETIME] toggle inside `tip`) without their own OnEnter calling
-- chainEnter. WoW 1.12's OnEnter/OnLeave are tied to which frame currently HAS MOUSE FOCUS (the
-- topmost mouse-enabled frame under the cursor), not simple bounding-box containment -- hovering
-- ANY mouse-enabled child transfers focus away from its parent and fires the PARENT's OnLeave,
-- even though the cursor never left the parent's own rectangle. (This is exactly why Blizzard's
-- own UIDropDownMenu needs its StartCounting/StopCounting parent-walk in the first place -- see
-- FrameXML/UIDropDownMenu.lua:86-102 -- proving the quirk is real, not a guess: if OnEnter/OnLeave
-- were pure per-frame bounding-box events, that walk would serve no purpose.) A parent's OnLeave
-- firing this way, with no corresponding chainEnter on the child that stole focus, arms a close
-- countdown while the mouse is still genuinely on/inside that parent -- verified by reading every
-- CreateFrame("Button"/EnableMouse(true) call site in this file (see the fix below for the ones
-- that were missing the wiring). This class of bug matches "panel closes when it should not" more
-- directly than "stays open when it should not", so it is FIXED (wired below) as a real defect,
-- but is not asserted as the single root cause of the exact report above -- see the next paragraph
-- for why that could not be fully proven from code alone.
--
-- COULD NOT FULLY VERIFY (said explicitly, not papered over): the precise WoW-engine mechanism
-- that leaves a panel visibly open with the mouse confirmed elsewhere cannot be reproduced or
-- single-stepped outside a running client -- OnEnter/OnLeave pairing is known to be unreliable for
-- overlapping frames in 1.12. Two responses to that: (1) the sibling-button gap above is a real,
-- demonstrable defect in the same neighbourhood, now fixed; (2) a geometric self-healing safety net
-- (MouseIsOver, WoW-wiring section below) that corrects the OBSERVABLE symptom directly, independent
-- of which exact OnEnter/OnLeave pairing failed to fire -- chosen deliberately over "just raise
-- HOVER_GRACE" or an unconditional force-hide bolted on without understanding why (both explicitly
-- rejected as symptom-masking). MouseIsOver tests screen-space containment, not mouse focus, so
-- it is immune to the exact nested-focus quirk above by construction, including for any FUTURE
-- child button this file's enter/leave wiring forgets.

-- ---- WoW wiring ------------------------------------------------------------------------------

if CreateFrame then
    -- Hoisted to this scope on purpose: the breakdown panel's builders live outside V.build(), and
    -- a `local W` inside build() is invisible to them (caught in-game: "attempt to index global W").
    local W = VampifyWidgets
    local frame
    -- Watchdog marker. A Button rather than a FontString so it can own mouse events of its own, and
    -- anchored OUTSIDE the bar's right edge so it cannot collide with the text or the two buttons.
    local warnBtn, warnMsg = nil, nil

    -- ---- hover chain: WoW-wiring instance -----------------------------------------------------
    --
    -- The state machine itself (V.newChain/chainRegister/chainEnter/chainLeave/chainTick) is pure
    -- and lives above the "WoW wiring" divider, offline-testable -- see its own header comment for
    -- the design; a dedicated regression test suite covers the state machine. This
    -- is the ONE real instance the addon builds; everything below just calls the pure functions on
    -- it and supplies the WoW-bound inputs (frame scripts, hideFn closures, MouseIsOver).
    local Chain = V.newChain()

    -- Forward-declared, assigned near the bottom of this section once `tip`/`detail` exist as real
    -- locals (same reason V.chainRegister's own two hideFn calls are deferred there -- see that
    -- comment) -- but the OnUpdate handler that CALLS it is wired much earlier, inside V.build.
    -- Lua closures capture the VARIABLE, not today's value, so `frame`'s OnUpdate below sees
    -- whatever this holds AT CALL TIME, same pattern this file already uses for `frame`/`tip`/
    -- `detail` themselves (declared nil, assigned later, read through the upvalue everywhere).
    local rescueCheck

    -- level: 2 = breakdown panel, 3 = row detail (a future level 4, "detail of detail", is a single
    -- V.chainRegister call away). Level 1 (the bar) is never registered -- see V.newChain's own
    -- header comment for why it is never a close target. Registered from inside V.build (see
    -- below) rather than at this outer scope, so the hideFn closures below can safely capture
    -- `tip`/`detail` -- those locals are not declared yet at THIS point in the file (the
    -- breakdown-panel section comes later); capturing them here would silently resolve to globals
    -- instead, the exact 5.0/lexical-scope trap this file's own header comment on `local W` above
    -- warns about. V.build/V.chainRegister itself only ever RUNS after the whole file (and
    -- therefore every later local) has finished loading.

    -- Solid-color 1px divider between compact-bar segments -- ARTWORK layer (drawn above the bar's
    -- BACKDROP but the segment FontStrings, all OVERLAY, still draw above it regardless of creation
    -- order -- see this file's own draw-layer note near the top of the WoW-wiring section).
    -- Anchored once at creation; V.build's layoutBarSegments re-anchors it for real every time the
    -- badge group's shown state might have changed.
    local function makeBarSeparator(parent, name)
        local t = parent:CreateTexture(name, "ARTWORK")
        t:SetTexture(W.COLORS.line.r, W.COLORS.line.g, W.COLORS.line.b)
        t:SetWidth(1)
        -- 14 -> 10 alongside the BAR_H cut (14px left almost no margin on a 16px-tall bar and
        -- visually dominated the row) -- now matches the pill's own height exactly.
        t:SetHeight(10)
        t:SetPoint("LEFT", parent, "LEFT", 0, 0)
        return t
    end

    -- Compact-bar ST/AoE indicator -- a RECTANGULAR bar, no rounded caps (in-game correction: the
    -- rounded ends never achieved the intended 3D effect despite repeated attempts, so the rounding
    -- was dropped entirely). At the 10px display height the
    -- cap was only 5px wide -- too little area for a rounding to read as a curved glass end; it
    -- read as a clipped corner instead, and the effect that worked at PILL_H=24 does not scale
    -- down. TWO-COLOR: left = Vamp healing landed on the player's CURRENT TARGET ("ST" in
    -- A.splitTotals' own field names, its semantics already redefined to exactly this -- see
    -- core/aggregate.lua's A.splitTotals header), right = everything else.
    --
    -- Cap textures (pill_fill_cap/pill_shade_cap/pill_shine_cap) are NO LONGER DRAWN -- neither
    -- end, no mirrored variant either. Only the MID tile per layer (pill_fill_mid/
    -- pill_shade_mid/pill_shine_mid) is used, stretched across the pill's FULL width -- it is
    -- horizontally uniform by construction (measured stretch-invariant, 0px difference across a
    -- long pill's own width), so it carries any width
    -- without distortion or a seam. All the cap-width clamp math this used to need (PILL_CAP_W,
    -- the 0%/100% false-colored-cap special case) is GONE along with the caps themselves -- V.
    -- pillSegments existed only to decide that clamp and has been removed from this file (its
    -- geometry need is now exactly V.splitBarWidths, already used elsewhere in this file for the
    -- same "two segments summing to a bar width" shape, and already covered by
    -- the existing splitBarWidths regression tests).
    --
    -- Draw order per pill is FILL -> SHADE -> SHINE (shine drawn first would be dampened by
    -- shade's own alpha-over) and is now carried by three SEPARATE draw layers (BORDER / ARTWORK /
    -- OVERLAY), not by creation order. The claim this comment used to make -- that textures on the
    -- same layer draw in CREATION order on a 1.12 client -- is FALSE, and was always false here:
    -- same-layer order is undefined and re-rolls on every /reload (in-game
    -- verified). Draw-layer SUBLEVELS are not an escape either -- the parameter exists in the
    -- signature but this client silently discards it (confirmed on this client). Cross-LAYER order, which
    -- this now uses, IS deterministic. The pill's two value FontStrings stay on OVERLAY alongside
    -- SHINE and still draw above it: FontStrings always draw above textures of the same layer
    -- (confirmed on this client). The 3D/glass impression comes ENTIRELY from the
    -- vertical bulge gradient (SHADE) and the specular streak (SHINE), the two effects that still
    -- carry at 10px height -- exactly the reasoning behind dropping the end rounding rather than
    -- trying to rescue it further.
    --
    -- Degradation: WoW 1.12 has no "does this file exist" check available to an addon -- a missing
    -- SetTexture path never errors, it just renders nothing for that piece -- so an undeployed
    -- texture degrades to an invisible layer, never a broken/erroring frame. The three cap TGAs
    -- stay on disk (harmless) but nothing in this file references them any more -- grepped clean.
    local PILL_TEX_DIR = "Interface\\AddOns\\Vampify\\textures\\"
    -- PILL_H is now a SLIDER-DRIVEN, SavedVariables-backed value (2026-08-25, in-game report: add
    -- two more sliders in the options that control the bar height and the detail bars' height) -- was a flat
    -- constant before this change; still declared `local` at this outer scope (same forward-
    -- reference/mutable-shared-local pattern this file already uses for PANEL_W, see that
    -- variable's own header comment) so every function below that already reads it as an upvalue
    -- (buildPill, layoutPill's own height math via BAR_H, etc.) keeps working unchanged, and simply
    -- sees whatever V.applyPillHeight (further down) last set it to.
    --
    -- Bounds, exposed as V.PILL_H_MIN/V.PILL_H_MAX so gui/options.lua's slider uses the SAME two
    -- numbers rather than a second hand-copied pair that could drift: 8 is the measured floor below
    -- which the pill's own 9px THICKOUTLINE text (buildPill below) stops being legible; the
    -- slider's own
    -- SetMinMaxValues enforces this floor directly (values below it are simply unreachable, not
    -- separately hidden/faded at render time). 18 caps it at TODAY's breakdown-panel row height
    -- (V.PANEL_BAR_H_DEFAULT below) rather than the previous 24px ceiling for panel bars -- the
    -- compact bar exists to be the small always-on-screen element, so it must never grow taller
    -- than the detail panel's own rows or it stops reading as "compact" at all. 10 (a proven
    -- compact health-bar height, and this addon's own long-standing default) is the shipped default.
    -- Ceiling raised 18 -> 40 (2026-08-25, after the barBg/layer fix above, in-game report: raise
    -- the height ceiling to 40 and give both sliders the same maximum -- unified with
    -- V.PANEL_BAR_H_MAX below, which now also reads 40). Floor (8, the measured THICKOUTLINE-text
    -- legibility floor) and DEFAULT (10, unchanged shipped default) are untouched -- this only
    -- widens how far a player can drag the slider, an existing player's saved value and the
    -- shipped default both read exactly as before.
    V.PILL_H_MIN, V.PILL_H_MAX, V.PILL_H_DEFAULT = 8, 40, 10
    local function clampPillH(h)
        h = h or V.PILL_H_DEFAULT
        if h < V.PILL_H_MIN then h = V.PILL_H_MIN end
        if h > V.PILL_H_MAX then h = V.PILL_H_MAX end
        return h
    end
    local PILL_H = V.PILL_H_DEFAULT
    local PILL_MIN_W, PILL_DEFAULT_W = 70, 170
    -- PILL_GRIP_CEILING_W: a sanity ceiling for the resize GRIP's drag range only (SetMaxResize,
    -- BAR_MAX_W below) -- NOT a clamp on the live pill's own width any more. In-game correction:
    -- why is there still free space right of the icons when the bar is dragged to its widest?
    -- -- root cause: recomputePillW used to clamp `pillW > PILL_MAX_W=420` even
    -- though the frame itself could be dragged wider than reserve+420, leaving the excess as
    -- unclaimed space past the options button. There is no content-driven reason the pill should
    -- not be allowed to grow arbitrarily long, so the decision was to lift that ceiling:
    -- the pill absorbs 100% of whatever the bar's own current width leaves
    -- over, unconditionally -- recomputePillW below no longer clamps the top at all. This constant
    -- only bounds how far the GRIP ITSELF can be dragged in the first place (a resize API needs
    -- some finite SetMaxResize value) -- 2000px is far past any reasonable on-screen bar size, a
    -- guard against a wild drag, not a content-driven limit.
    local PILL_GRIP_CEILING_W = 2000
    -- RED/BLUE now read from W.COLORS.targetRed/restBlue (gui/widgets.lua) -- the ONE shared
    -- source, not a second local definition. In-game correction (same pass as the panel-bar
    -- glass optic): use the same red/blue color coding as the bar for the breakdown panel too
    -- -- moving the values into W.COLORS is what makes that a single source of truth instead of two
    -- tables that could silently drift apart (grep-verified, this file no longer defines a color
    -- literal for either). See widgets.lua's own comment on targetRed/restBlue for the full history
    -- (darkened from a brighter first draft, verified 3.94:1 -> passing).

    -- Builds one glass bar's four texture layers (fillSt, fillAoe, shadeMid, shineMid -- one MID
    -- tile per FILL side plus one each for the color-neutral SHADE/SHINE bands, no caps at all any
    -- more) plus its two value FontStrings. Only ever created once per pill instance -- layoutPill
    -- below resizes/repositions/recolors/shows/hides these, never creates new ones (same pooling
    -- convention as every other reused widget in this file). EnableMouse(true): the pill is the
    -- SOLE hover-trigger for the breakdown panel (hover-chain level 2, wired in V.build).
    local function buildPill(parent, name)
        local p = CreateFrame("Frame", name, parent)
        p:SetHeight(PILL_H)
        p:EnableMouse(true)

        local function layer(nm, blend)
            local t = p:CreateTexture(name .. nm, "BORDER")
            t:SetTexture(PILL_TEX_DIR .. "pill_fill_mid")
            if blend then t:SetBlendMode(blend) end
            t:SetHeight(PILL_H)
            return t
        end

        -- ---- FILL (colorable via SetVertexColor) -- two segments, red then blue ----
        p.fillMidSt  = layer("FillMidSt")
        p.fillMidAoe = layer("FillMidAoe")

        -- ---- SHADE (neutral, drawn over the fill) -- ONE piece, full width ----
        p.shadeMid = p:CreateTexture(name .. "ShadeMid", "ARTWORK")   -- one layer above the fills
        p.shadeMid:SetTexture(PILL_TEX_DIR .. "pill_shade_mid")
        p.shadeMid:SetHeight(PILL_H)

        -- ---- SHINE (neutral, ADD-blended, drawn last so shade never dampens the gloss) ----
        p.shineMid = p:CreateTexture(name .. "ShineMid", "OVERLAY")   -- one layer above the shade
        p.shineMid:SetTexture(PILL_TEX_DIR .. "pill_shine_mid")
        p.shineMid:SetBlendMode("ADD")
        p.shineMid:SetHeight(PILL_H)

        -- ---- VALUES (OVERLAY FontStrings -- they share the layer with SHINE and still draw above
        -- it: FontStrings always draw above textures of the same layer, confirmed on this client) ----
        -- THICKOUTLINE + a dark drop shadow -- the confirmed 1.12 fix for text sitting on top of a
        -- gradient/gloss surface (the pill's own shine band peaks near-white right under the top
        -- glyph rows; a flat text color alone measured well under 4.5:1 there in the design-review
        -- pass -- see render_glasspill.js's drawValueText comment for the measured trace this
        -- mirrors). W.ApplyShadow applies exactly SetShadowColor(0,0,0,0.9)/SetShadowOffset(1,-1).
        -- Font size 9 -- the proven size for text drawn ON a 10px-tall bar, taken from a shipping
        -- bar addon of the same weight class rather than guessed.
        p.textRed  = p:CreateFontString(name .. "TextRed", "OVERLAY")
        p.textBlue = p:CreateFontString(name .. "TextBlue", "OVERLAY")
        W.ApplyFont(p.textRed, 9, "THICKOUTLINE")
        W.ApplyFont(p.textBlue, 9, "THICKOUTLINE")
        W.ApplyShadow(p.textRed, true)
        W.ApplyShadow(p.textBlue, true)
        W.SetTextColorG(p.textRed, W.COLORS.barText)
        W.SetTextColorG(p.textBlue, W.COLORS.barText)
        return p
    end

    -- Centers `label` inside the color segment [segStartX, segStartX+segW) (a coordinate local to
    -- `p`'s own LEFT edge), or hides `fs` entirely if it does not fit -- "passt ein Wert nicht in
    -- seine Haelfte, wird ER ausgeblendet", never truncated. This is V.pickSplitLabel's own fit
    -- formula (segW >= textW + 2*pad) applied to a single candidate rather than a two-tier
    -- full/short degradation -- called inline (not through V.pickSplitLabel's textWidthFn hook)
    -- because that hook would need a fresh closure over `fs` every call on a path V.update runs a
    -- couple of times a second; the formula itself is unchanged from that pure, tested function.
    local function placeLabel(p, fs, label, segStartX, segW)
        if not label or label == "" or segW <= 0 then fs:Hide(); return end
        fs:SetText(label)
        local tw = fs:GetStringWidth()
        if segW < tw + 8 then fs:Hide(); return end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", p, "LEFT", segStartX + segW / 2, 0)
        fs:Show()
    end

    -- Turns (stPct, aoePct) into real widget calls: pill width, the two colored FILL segments
    -- (via V.splitBarWidths -- pure, tested, already used elsewhere in this file for the exact
    -- same "two segments summing to a bar width" shape, no cap-clamp math needed now that there
    -- are no caps), the full-width neutral SHADE/SHINE bands, and the two value labels. Resizable:
    -- `pillW` is a parameter, not a fixed constant -- this is the one function the drag-resize
    -- grip (V.build) and V.update both call to reflow the pill at its current width.
    local function layoutPill(p, pillW, stPct, aoePct, redLabel, blueLabel)
        p:SetWidth(pillW)
        if pillW <= 0 then
            p.fillMidSt:Hide(); p.fillMidAoe:Hide()
            p.shadeMid:Hide(); p.shineMid:Hide()
            p.textRed:Hide(); p.textBlue:Hide()
            return
        end
        local stW, aoeW = V.splitBarWidths(pillW, stPct, aoePct)

        -- ---- FILL: two segments, red from the left edge, blue from where red ends. Either can
        -- be exactly 0 (0%/100% split) -- no cap to recolor any more, so a 0-width segment simply
        -- hides, nothing is left in the wrong color anywhere. ----
        if stW > 0 then
            p.fillMidSt:ClearAllPoints()
            p.fillMidSt:SetPoint("LEFT", p, "LEFT", 0, 0)
            p.fillMidSt:SetWidth(stW)
            p.fillMidSt:SetVertexColor(W.COLORS.targetRed.r, W.COLORS.targetRed.g, W.COLORS.targetRed.b)
            p.fillMidSt:Show()
        else
            p.fillMidSt:Hide()
        end
        if aoeW > 0 then
            p.fillMidAoe:ClearAllPoints()
            p.fillMidAoe:SetPoint("LEFT", p, "LEFT", stW, 0)
            p.fillMidAoe:SetWidth(aoeW)
            p.fillMidAoe:SetVertexColor(W.COLORS.restBlue.r, W.COLORS.restBlue.g, W.COLORS.restBlue.b)
            p.fillMidAoe:Show()
        else
            p.fillMidAoe:Hide()
        end

        -- ---- SHADE + SHINE: neutral, full pill width regardless of the color split (measured
        -- stretch-invariant against the real textures). ----
        p.shadeMid:ClearAllPoints(); p.shadeMid:SetPoint("LEFT", p, "LEFT", 0, 0)
        p.shadeMid:SetWidth(pillW); p.shadeMid:Show()
        p.shineMid:ClearAllPoints(); p.shineMid:SetPoint("LEFT", p, "LEFT", 0, 0)
        p.shineMid:SetWidth(pillW); p.shineMid:Show()

        -- ---- VALUES: left = current-target amount, right = everything-else amount. ----
        placeLabel(p, p.textRed, redLabel, 0, stW)
        placeLabel(p, p.textBlue, blueLabel, stW, aoeW)
    end

    -- ---- shared glass-bar helper (breakdown-panel split row, ability rows, item-detail mini bars
    -- -- in-game report: the detail panel's bars should use the same glass treatment
    -- ) -------------------------------------------------------------------------------------
    --
    -- Same three-layer FILL -> SHADE -> SHINE stack as the compact bar's own pill above,
    -- generalized to up to TWO colorable fill segments (a single-color bar just leaves the second
    -- width at 0) plus one shade/shine pair spanning the bar's own CURRENT total width -- never
    -- assumed to be the panel's full width, since each of this file's three bar contexts sizes its
    -- bar differently (the split row and ability rows to a computed share, the item-detail mini
    -- bars to one source's own percent). No caps here either -- these were already flat rectangles
    -- before this pass, matching the compact bar's own post-correction shape, so there was no
    -- rounding to remove in the first place.
    -- Draw layers (2026-08-25, second pass -- a full audit of every CreateTexture in this file
    -- after the first pass fixed only the case that had actually been reported):
    --
    -- Ground truth, all in-game verified: draw order between multiple textures on the
    -- SAME layer and the SAME parent frame is UNDEFINED on this client and re-rolls on every
    -- /reload; the sublevel parameter of SetDrawLayer is silently discarded, so it
    -- is not an escape hatch; order BETWEEN layers
    -- (BACKGROUND < BORDER < ARTWORK < OVERLAY) IS deterministic; HIGHLIGHT is
    -- unusable for permanent art, it only renders under the mouse; and FontStrings
    -- always draw above textures of the same layer, which is what lets every label
    -- in this file share OVERLAY with a texture and still win.
    --
    -- The first pass moved these four textures off BACKGROUND because r.barBg competed with them
    -- there (in-game report: ability-row bars invisible, icon/name/value still drawn), and then explicitly
    -- left TWO known collisions open -- fill vs. shade vs. shine among themselves, and the same
    -- pattern in buildPill. The audit confirmed both geometrically and found a third the first
    -- pass had asserted was impossible: buildTipFill's own panel background (fillA/fillB plus four
    -- corners, alpha 0.94, spanning the whole panel) sits on BACKGROUND on `tip` too, overlapping
    -- every row's r.barBg -- so the empty track could disappear under the panel fill on an
    -- unlucky load, the same failure the first pass had just fixed one layer down.
    --
    -- The rule now, uniform across all three bar contexts (compact-bar pill, panel rows, row
    -- detail): a glass bar owns BORDER (fill), ARTWORK (shade) and OVERLAY (shine) on its own
    -- parent, one layer each, so its internal order is carried by the layer system rather than by
    -- creation order. Labels stay FontStrings on OVERLAY and still draw over the shine. What has
    -- to sit ABOVE a bar and is NOT a FontString -- only the row icons -- moves to a child frame
    -- (tipIcons), since frame level dominates draw layer and is deterministic. The two remaining
    -- BACKGROUND users on `tip` (the panel fill and its corners) draw identical colour at identical
    -- alpha, so their mutual order is unobservable; r.barBg no longer joins them because it is now
    -- laid out beside the fill rather than beneath it (see setRow).
    local function buildGlassBar(parent, name)
        local g = {}
        local function layer(nm, file, drawLayer, blend)
            local t = parent:CreateTexture(name .. nm, drawLayer)
            t:SetTexture(PILL_TEX_DIR .. file)
            if blend then t:SetBlendMode(blend) end
            return t
        end
        -- One draw layer per role, NOT creation order (see this function's own header above).
        -- fillA/fillB share BORDER because they are laid out SIDE BY SIDE and therefore never
        -- overlap each other -- the only same-layer pairing here that is safe by geometry.
        g.fillA = layer("FillA", "pill_fill_mid", "BORDER")
        g.fillB = layer("FillB", "pill_fill_mid", "BORDER")
        g.shade = layer("Shade", "pill_shade_mid", "ARTWORK")
        g.shine = layer("Shine", "pill_shine_mid", "OVERLAY", "ADD")
        return g
    end

    -- Lays out a glass bar TOPLEFT-anchored to `parent` at (x, y) -- this file's own convention at
    -- every one of the three call sites -- with height h: fillA (width wA, color cA, alpha
    -- fillAlpha) then fillB (width wB, color cB) immediately after it. Pass wB=0/cB=nil for a
    -- single-color bar (the "Other (N)" row, a no-split ability row, an item-detail mini bar) --
    -- fillB then simply never shows. Shade/shine span the FULL wA+wB, matching the compact bar's
    -- own "neutral bands span the whole bar regardless of the color split" rule (measured stretch-
    -- invariant). Hides everything when wA+wB <= 0.
    local function layoutGlassBar(g, parent, x, y, h, wA, cA, wB, cB, fillAlpha)
        wA = wA or 0
        wB = wB or 0
        local totalW = wA + wB
        if totalW <= 0 then
            g.fillA:Hide(); g.fillB:Hide(); g.shade:Hide(); g.shine:Hide()
            return
        end
        if wA > 0 then
            g.fillA:ClearAllPoints()
            g.fillA:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            g.fillA:SetWidth(wA); g.fillA:SetHeight(h)
            g.fillA:SetVertexColor(cA.r, cA.g, cA.b)
            g.fillA:SetAlpha(fillAlpha or 1)
            g.fillA:Show()
        else
            g.fillA:Hide()
        end
        if wB > 0 then
            g.fillB:ClearAllPoints()
            g.fillB:SetPoint("TOPLEFT", parent, "TOPLEFT", x + wA, y)
            g.fillB:SetWidth(wB); g.fillB:SetHeight(h)
            g.fillB:SetVertexColor(cB.r, cB.g, cB.b)
            g.fillB:SetAlpha(fillAlpha or 1)
            g.fillB:Show()
        else
            g.fillB:Hide()
        end
        g.shade:ClearAllPoints()
        g.shade:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        g.shade:SetWidth(totalW); g.shade:SetHeight(h)
        g.shade:Show()
        g.shine:ClearAllPoints()
        g.shine:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        g.shine:SetWidth(totalW); g.shine:SetHeight(h)
        g.shine:Show()
    end

    -- ---- HPS: plain text only ------------------------------------------------------------------
    --
    -- The HPS glass orb (Variant B) is REMOVED, in-game correction: drop the orb over the HPS
    -- value entirely. No replacement widget -- just
    -- frame.vfHpsText, a FontString built inline in V.build (same convention as vfHealText),
    -- driven by the same V.formatHpsSegment this file already had (that pure function is
    -- unchanged -- only the WoW-wiring shell that used to draw it under an orb is gone). The
    -- hps_orb_fill/shade/shine.tga files stay on disk (harmless) but nothing in this file
    -- references them any more -- grepped clean.
    --
    -- This also collapses the bar back to ONE line (no more orb-plus-label stack), which is what
    -- lets BAR_H shrink back down below -- see BAR_H's own comment further down.

    -- ---- bar layout: dynamic pill width (drag-resize) ------------------------------------------
    --
    -- In-game correction (same pass): why is there so much free space to the right of the two
    -- buttons? -- root-caused by reading the code, not guessed: pillW used to be derived as
    -- `frame:GetWidth() - FIXED_RESERVE`, and FIXED_RESERVE budgeted a FIXED, deliberately
    -- generous HEAL_TEXT_W (56px) for the heal number's own slot -- worst-case width for a 6-char
    -- amount like "999.9k". A REAL heal total is usually much shorter ("608" ~ 20px), and because
    -- the frame's own width is the fixed/dragged value while the content chain flows from real
    -- (shorter) text, the unused slack between the budget and the real text width showed up as
    -- dead space at the bar's own right edge -- nothing ever reclaimed it. Ruled out by reading
    -- the code: the resize grip is a pure overlay (BOTTOMRIGHT, no anchor participation, does not
    -- reserve space -- see the grip's own comment in V.build) and there is no orphaned
    -- since-removed segment left in the anchor chain (layoutBarSegments' history checked against
    -- the current chain -- every constant it still adds is either a real, currently-drawn segment
    -- or BAR_MARGIN_R itself, a deliberate small trailing margin, not a bug-sized gap).
    --
    -- Fix: Variante (b) -- the bar keeps its own set/dragged width, and the PILL absorbs whatever
    -- space the fixed segments do not use, computed from their REAL GetStringWidth() every time
    -- either the frame is resized or the heal/HPS text changes (recomputePillW, called from
    -- OnSizeChanged AND V.update, not just one of the two -- a heal total gaining a digit mid-fight
    -- must reclaim/give back pill width exactly like a manual resize does). Chosen over (a)
    -- (frame width derived from content) because it matches the stated resize mental model
    -- more directly (when dragging, it is mainly the pill that lengthens) -- under (b) that is
    -- literally true of EVERY width the pill ends up at, not just the ones the user dragged to.
    local BAR_MARGIN_L, BAR_MARGIN_R = 6, 8
    local GAP, SEP_W = 5, 1
    -- Buttons shrunk 16 -> 14 alongside the BAR_H cut below (a 16px button on a ~16px-tall bar left
    -- no vertical margin at all).
    local BTN_W, BTN_GAP = 14, 4
    -- The part of the layout that is NEVER text -- margins, separators, gaps, buttons. Text widths
    -- (heal, HPS) are added to this at LIVE render time (recomputePillW below), never budgeted
    -- here -- that budgeting is exactly what caused the dead-space bug above.
    local FIXED_RESERVE_STATIC =
        BAR_MARGIN_L + GAP + SEP_W + GAP                     -- up to the pill's own left edge
        + GAP + SEP_W + GAP                                  -- pill's right edge .. HPS text
        + GAP + BTN_W + BTN_GAP + BTN_W + BAR_MARGIN_R        -- .. reset .. options .. margin
    -- MEASURED, not estimated -- used ONLY to pick a sensible persisted/default bar WIDTH and the
    -- resize grip's SetMinResize/SetMaxResize bounds, never for the live pill layout itself
    -- (recomputePillW always reads the real text widths at render time regardless of what these
    -- say). In-game correction: take the "EST" suffix literally -- measure the actually-required
    -- width via GetStringWidth() of the actually-set string, not an assumed placeholder --
    -- these used to be two hand-typed guesses (40/36).
    -- Now a hidden probe FontString (the measure-with-an-offscreen-FontString pattern shipping
    -- bar addons use) measures the REAL pixel width, in this bar's own font, of
    -- the widest string V.formatAmount/V.formatHpsSegment can realistically produce -- generated
    -- from those SAME formatting functions (not hand-typed text), so a probe can never quietly
    -- drift out of sync with a future format change.
    --
    -- Measured ONCE here at load time, not re-measured every time the heal/HPS text changes --
    -- a deliberately calmer alternative, chosen over a live per-value remeasure:
    -- a running fight's heal number changing width every tick would otherwise nudge these DRAG
    -- BOUNDS constantly, felt as jitter, for zero benefit -- the live pill already reflows off the
    -- REAL current text every frame via recomputePillW below regardless of what these say, so a
    -- bound that is a little more generous than a small in-progress value strictly needs costs
    -- nothing but a few unused px of resize headroom (an accepted tradeoff).
    -- Parented to UIParent, not `frame` -- this block runs once at file load, before V.build() has
    -- ever created the real bar frame; a FontString's own GetStringWidth() does not depend on its
    -- parent's size, so any always-available frame works equally well here.
    local healProbe = W.MakeText(UIParent, 9, W.COLORS.goldHi, "OVERLAY")
    healProbe:SetText(V.formatAmount(9999900000))   -- "9999.9M" -- a deliberately absurd ceiling
    local HEAL_TEXT_W_EST = healProbe:GetStringWidth() or 40
    healProbe:Hide()
    local hpsProbe = W.MakeText(UIParent, 9, W.COLORS.ink, "OVERLAY")
    hpsProbe:SetText(V.formatHpsSegment({ hps = 99999.9 }))   -- "99999.9 HPS"
    local HPS_TEXT_W_EST = hpsProbe:GetStringWidth() or 36
    hpsProbe:Hide()
    local FIXED_RESERVE_EST = FIXED_RESERVE_STATIC + HEAL_TEXT_W_EST + HPS_TEXT_W_EST
    local BAR_MIN_W     = FIXED_RESERVE_EST + PILL_MIN_W
    local BAR_MAX_W     = FIXED_RESERVE_EST + PILL_GRIP_CEILING_W
    local BAR_DEFAULT_W = FIXED_RESERVE_EST + PILL_DEFAULT_W
    -- One line again (no more orb-plus-label stack) -- BAR_H is just the pill's own height plus a
    -- small vertical margin, in the same weight class as a 16px full player row (a 10px bar plus
    -- its borders, gap and power strip), not a guess at "slim".
    local BAR_V_PAD = 3
    local BAR_H = PILL_H + 2 * BAR_V_PAD

    -- Real GetStringWidth() reads off the bar's own heal/HPS FontStrings -- see this block's own
    -- header comment for why this replaced a fixed per-segment budget. Returns the pill width to
    -- use RIGHT NOW; does not itself call layoutPill (callers decide when to actually redraw, same
    -- separation V.update's other change-gated segments already use).
    -- pctExtra (2026-08-25, "show vampirism % on bar" option): the gear%-on-bar segment's own
    -- width budget is CONDITIONAL, read live from config here rather than folded into the
    -- unconditional FIXED_RESERVE_STATIC/FIXED_RESERVE_EST -- the default-off reasoning
    -- (so the bar stays narrow) means an existing player who never enables this option
    -- must lose NOTHING to it: BAR_MIN_W/BAR_DEFAULT_W (both derived from FIXED_RESERVE_EST) stay
    -- exactly what they were before this option existed. When the option IS on, this reserves its
    -- separator (GAP+SEP_W+GAP, the same per-segment margin every other separator already costs)
    -- plus the text's REAL current width -- same "read the actual FontString, not an estimate"
    -- convention healW/hpsW already use.
    local function recomputePillW(bar)
        local healW = bar.vfHealText:GetStringWidth() or 0
        local hpsW  = bar.vfHpsText:GetStringWidth() or 0
        local pctExtra = 0
        local cfg = VampifyConfig.get()
        if cfg and cfg.showGearPct and bar.vfPctText then
            pctExtra = GAP + SEP_W + GAP + (bar.vfPctText:GetStringWidth() or 0)
        end
        local pillW = bar:GetWidth() - FIXED_RESERVE_STATIC - healW - hpsW - pctExtra
        if pillW < PILL_MIN_W then pillW = PILL_MIN_W end
        -- No upper clamp any more -- the pill absorbs 100% of whatever the bar's own current width
        -- leaves over (in-game correction: the pill should absorb whatever is left over -- there is
        -- no content-driven reason it should not grow arbitrarily long). This is
        -- what fixes the dead-space-at-max-width report: previously a bar dragged wide enough that
        -- frame:GetWidth() - reserve exceeded the old PILL_MAX_W=420 left the excess unclaimed
        -- past the options button, worst right at PILL_GRIP_CEILING_W (the resize grip's own drag
        -- ceiling, unrelated to this computation now).
        bar.vfPillW = pillW
        return pillW
    end

    -- Live-apply entry point for the "Bar height" options slider (2026-08-25) -- called by
    -- gui/options.lua's slider setter AFTER it has already written the new value to
    -- VampifyConfig.get().pillHeight (same split this file's SCT sliders already use: the OPTIONS
    -- setter owns persistence, this function only owns making the CURRENTLY BUILT frame reflect it
    -- immediately, with no /reload). A no-op (besides updating the shared PILL_H/BAR_H locals) if
    -- V.build() has not run yet -- the next V.build() call reads the persisted config value itself
    -- (see its own PILL_H = clampPillH(...) line above), so nothing is lost by calling this before
    -- the frame exists.
    --
    -- Re-derives and re-applies every piece of geometry this file's own comments say depends on
    -- PILL_H/BAR_H: the frame's own height AND its resize-grip bounds (SetMinResize/SetMaxResize --
    -- explicitly including the resize-grip bounds, per request), the two separators (makeBarSeparator's
    -- initial height cannot see PILL_H as a real upvalue -- see V.build's own comment on this), and
    -- the pill's four height-bearing texture layers (buildPill built them once; layoutPill itself
    -- only ever re-touches WIDTH, never height, so those four SetHeight calls have to happen here
    -- explicitly) followed by ONE recomputePillW+layoutPill pass so the pill's own WIDTH and its two
    -- value labels re-flow against the frame's current width immediately, using the same cached
    -- vfLastStPct/vfLastAoePct/vfLastRedLabel/vfLastBlueLabel the drag-resize grip's own
    -- OnSizeChanged handler already relies on (V.update fills these on every repaint).
    function V.applyPillHeight(newH)
        PILL_H = clampPillH(newH)
        BAR_H = PILL_H + 2 * BAR_V_PAD
        if not frame then return end
        frame:SetHeight(BAR_H)
        frame:SetMinResize(BAR_MIN_W, BAR_H)
        frame:SetMaxResize(BAR_MAX_W, BAR_H)
        if frame.vfSep1 then frame.vfSep1:SetHeight(PILL_H) end
        if frame.vfSep2 then frame.vfSep2:SetHeight(PILL_H) end
        -- Fix (2026-08-25, found while auditing "does every pill-height-dependent widget actually
        -- track PILL_H live" -- same bug class as the rowHoverFrame height fix elsewhere in this
        -- file today): vfSep3 (the gear%-on-bar segment's own separator, cfg.showGearPct) is built
        -- and height-set once inside V.build(), but was missing from this refresh -- a live
        -- pillHeight slider drag left it visually the wrong height while vfSep1/vfSep2 followed
        -- correctly. nil-guarded like its two siblings above: absent on any build that predates this
        -- field, or before V.build() has created it yet.
        if frame.vfSep3 then frame.vfSep3:SetHeight(PILL_H) end
        local p = frame.vfPill
        if p then
            p:SetHeight(PILL_H)
            if p.fillMidSt  then p.fillMidSt:SetHeight(PILL_H) end
            if p.fillMidAoe then p.fillMidAoe:SetHeight(PILL_H) end
            if p.shadeMid   then p.shadeMid:SetHeight(PILL_H) end
            if p.shineMid   then p.shineMid:SetHeight(PILL_H) end
            local pillW = recomputePillW(frame)
            layoutPill(p, pillW, frame.vfLastStPct or 0, frame.vfLastAoePct or 0,
                frame.vfLastRedLabel, frame.vfLastBlueLabel)
        end
    end

    -- Sequential re-anchor for the compact bar's segments -- run once at build time and again every
    -- V.update whenever the pill's shown/hidden state might have changed (splitTotals only just
    -- having become available, or gone quiet again). Each visible segment anchors to the RIGHT of
    -- the previous one, so a missing segment (no splitTotals -- the fallback contract) collapses
    -- cleanly instead of leaving a gap. The HPS text (unlike the pill) is unconditional.
    -- showPct (2026-08-25, "show vampirism % on bar" option): a THIRD conditional segment, same
    -- shape as the pill's own conditional slot -- chained onto the RIGHT of HPS text via its own
    -- separator (vfSep3) when on, collapsed entirely when off (the fallback/default state -- see
    -- V.build's own cfg.showGearPct comment for why default-off must cost existing users nothing).
    -- The reset/options buttons used to anchor to a FIXED target (frame.vfHpsText, set once at
    -- creation) because HPS text was always the last segment -- that stopped being true the moment
    -- a fourth, optional segment could sit after it, so the reset button (frame.vfResetBtn, a field
    -- only from this change onward -- see its own creation comment in V.build) is now re-anchored
    -- HERE, to whichever segment ends up last (`prev`) -- the options button needs no change of its
    -- own, it is anchored RELATIVE TO the reset button and therefore already follows it.
    local function layoutBarSegments(bar, showBadge, showPct)
        bar.vfHealText:ClearAllPoints()
        bar.vfHealText:SetPoint("LEFT", bar, "LEFT", BAR_MARGIN_L, 0)
        local prev = bar.vfHealText
        if showBadge then
            bar.vfSep1:ClearAllPoints()
            bar.vfSep1:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
            bar.vfSep1:Show()
            bar.vfPill:ClearAllPoints()
            bar.vfPill:SetPoint("LEFT", bar.vfSep1, "RIGHT", GAP, 0)
            bar.vfPill:Show()
            prev = bar.vfPill
        else
            bar.vfSep1:Hide()
            bar.vfPill:Hide()
        end
        bar.vfSep2:ClearAllPoints()
        bar.vfSep2:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        bar.vfSep2:Show()
        bar.vfHpsText:ClearAllPoints()
        bar.vfHpsText:SetPoint("LEFT", bar.vfSep2, "RIGHT", GAP, 0)
        bar.vfHpsText:Show()
        prev = bar.vfHpsText
        if showPct and bar.vfSep3 and bar.vfPctText then
            bar.vfSep3:ClearAllPoints()
            bar.vfSep3:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
            bar.vfSep3:Show()
            bar.vfPctText:ClearAllPoints()
            bar.vfPctText:SetPoint("LEFT", bar.vfSep3, "RIGHT", GAP, 0)
            bar.vfPctText:Show()
            prev = bar.vfPctText
        else
            if bar.vfSep3 then bar.vfSep3:Hide() end
            if bar.vfPctText then bar.vfPctText:Hide() end
        end
        if bar.vfResetBtn then
            bar.vfResetBtn:ClearAllPoints()
            bar.vfResetBtn:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
        end
    end

    -- ---- per-segment tooltips (2026-08-25, in-game report: what does the first number in
    -- the Vampify bar mean, and why does it have no explanatory tooltip?) -------------------------
    --
    -- Every bar segment is a plain FontString (heal/HPS/gear%) or a composite Frame (the pill) --
    -- FontStrings are never mouse-interactive in WoW 1.12 (no EnableMouse), so each text segment
    -- gets wrapped in its own small invisible Frame whose rect TRACKS the FontString's own current
    -- one via SetAllPoints -- a live anchor relationship, not a one-time snapshot, so it keeps
    -- fitting the text exactly as SetText changes its width every tick, with no extra
    -- repositioning call needed anywhere else (confirmed against this file's own anchor-chain
    -- convention -- every other segment already relies on the same "SetPoint tracks the target
    -- live" anchor behaviour, e.g. the reset button's own dynamic re-anchor just above).
    --
    -- Deliberately NOT wired into the hover Chain (V.chainEnter/V.showTooltip) -- by design,
    -- the PILL is the SOLE trigger for the breakdown panel (see
    -- frame.vfPill's own OnEnter/OnLeave comment in V.build). Since `frame` itself carries no
    -- OnEnter/OnLeave tied to the Chain (only the pill does -- see this file's own header comment
    -- on that redesign), a sibling hover frame here stealing mouse focus from `frame` has nothing
    -- chained to disturb: it can only ever show/hide a plain GameTooltip, never open or close the
    -- panel. The pill's OWN new tooltip (added directly into its EXISTING OnEnter/OnLeave in
    -- V.build below, not a second overlapping frame here) works the same way for the same reason.
    --
    -- buildFn is called ONCE per hover (OnEnter), never per frame -- building a few AddLine calls on
    -- an event that fires when the mouse enters a ~20px-wide segment is not the "no allocation in
    -- the render loop" case this file's own header warns about (that rule targets OnUpdate, which
    -- this is not).
    -- ---- dragging the bar ----------------------------------------------------------------------
    --
    -- The bar is movable, but the drag is only half the story: several mouse-enabled CHILD frames
    -- sit on top of it -- an invisible tooltip hitbox over every text segment, the pill, and the
    -- three small buttons. A child with the mouse enabled CONSUMES the drag on this client, and
    -- 1.12 has no mouse-propagation switch (SetPropagateMouseClicks is a later patch; confirmed
    -- to have no 1.12 equivalent). Each such child was therefore a dead spot on
    -- an otherwise draggable bar -- reported in-game (2026-08-25) for the leftmost segment,
    -- the last fight's vamp value, and then stated as the general rule: the WHOLE bar drags when it
    -- is not locked.
    --
    -- The fix is the pattern real 1.12 addons use for exactly this (a resize grip driving
    -- its parent the same way, and a drag overlay doing it for moving): the child registers
    -- the drag itself and moves the BAR, not itself. SetMovable stays on the bar alone -- a
    -- forwarding child never needs it, since it is never the thing being moved.
    --
    -- Centralised in these three functions rather than repeated per child on purpose: the lock
    -- check and the position write have to be identical everywhere, or "locked" would be true for
    -- the bar's own surface and a lie for most of its area, and a drag that ended on a button would
    -- silently fail to persist. The bar's own handlers below use the same two functions.
    local function beginBarDrag()
        local c = VampifyConfig.get()
        if c and c.locked then return end
        if frame then frame:StartMoving() end
    end
    local function endBarDrag()
        if not frame then return end
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint()
        local c = VampifyConfig.get()
        if c then c.pos = { point = point, x = x, y = y } end
    end
    -- Deliberately NOT applied to the resize grip: that one owns its mouse to SIZE the bar, and is
    -- the single child for which swallowing the drag is the correct behaviour.
    local function makeBarDraggable(child)
        if not child then return end
        child:RegisterForDrag("LeftButton")
        child:SetScript("OnDragStart", beginBarDrag)
        child:SetScript("OnDragStop", endBarDrag)
    end

    local function attachSegmentTooltip(name, parent, fs, anchor, buildFn)
        local h = CreateFrame("Frame", name, parent)
        h:SetAllPoints(fs)
        h:EnableMouse(true)
        h:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, anchor)
            buildFn()
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- A hitbox exists to show a tooltip; it must not also cost the bar a grab point. Tooltip
        -- and drag coexist on one frame without interfering (OnEnter/OnLeave and
        -- OnDragStart/OnDragStop are independent script slots).
        makeBarDraggable(h)
        return h
    end

    function V.build()
        if frame then return frame end
        local cfg = VampifyConfig.get()
        -- Persisted width (drag-resize grip, below) -- clamped defensively even though the grip
        -- itself already clamps via SetMinResize/SetMaxResize, in case a SavedVariables file was
        -- hand-edited or carried over from a build with different bounds.
        local BAR_W = (cfg and cfg.size and cfg.size.w) or BAR_DEFAULT_W
        if BAR_W < BAR_MIN_W then BAR_W = BAR_MIN_W end
        if BAR_W > BAR_MAX_W then BAR_W = BAR_MAX_W end

        -- Persisted pill height (2026-08-25 slider) -- applied here, BEFORE any height-dependent
        -- geometry below reads PILL_H/BAR_H, same "read config once at real construction time, not
        -- at file-load time" reasoning as BAR_W just above (SavedVariables is not populated yet when
        -- this file's own top-level code -- PILL_H's original `local` -- ran at addon load). No
        -- config value yet (cfg.pillHeight is nil for every profile saved before this slider
        -- existed) reads as V.PILL_H_DEFAULT via clampPillH's own fallback, matching this addon's
        -- unchanged shipped default exactly -- an existing player sees no visible change until they
        -- actually drag the new slider.
        PILL_H = clampPillH(cfg and cfg.pillHeight)
        BAR_H = PILL_H + 2 * BAR_V_PAD

        frame = CreateFrame("Frame", "VampifyDisplayFrame", UIParent)
        frame:SetWidth(BAR_W)
        frame:SetHeight(BAR_H)
        -- Strata HIGH, not the default MEDIUM/level 1: at MEDIUM the frame loses every overlap and
        -- disappears under pfUI's bars -- observed in-game, reporting shown/visible/alpha 1 while
        -- being nowhere on screen.
        frame:SetFrameStrata("HIGH")
        frame:SetFrameLevel(10)
        -- A backdrop, because a bare FontString over a busy UI is findable only if you already
        -- know where it is. Same visual language as the options window and the minimap button --
        -- the slim 1px variant, since a bar this size would drown in the full panel border.
        frame:SetBackdrop(W.SOLID_BACKDROP)
        frame:SetBackdropColor(0.055, 0.067, 0.086, 0.85)
        frame:SetBackdropBorderColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b, 1)
        -- Soft shadow when pfUI is loaded, silently absent otherwise -- see W.ApplyBackdropShadow's
        -- own comment; corners stay square regardless (1.12 has no 9-slice/corner-radius asset, see
        -- this file's header brief -- not attempted here).
        W.ApplyBackdropShadow(frame)
        frame:SetMovable(true)
        -- Drag-resize (a dedicated grip, not the whole bar -- see the grip built near
        -- the end of this function). SetResizable/StartSizing/SetMinResize/SetMaxResize are real
        -- 1.12 APIs (confirmed against another shipping 1.12 addon's own window-resize code, the
        -- same client generation this addon targets -- some stale notes claim TBC+-only, which does
        -- not hold up against that shipping addon's source). Height is NOT resizable (min==max==BAR_H) -- only width, so the
        -- grip lengthens the pill without the bar growing taller.
        frame:SetResizable(true)
        frame:SetMinResize(BAR_MIN_W, BAR_H)
        frame:SetMaxResize(BAR_MAX_W, BAR_H)
        frame:EnableMouse(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag("LeftButton")

        local pos = (cfg and cfg.pos) or { point = "CENTER", x = 0, y = -150 }
        frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

        frame:SetScript("OnDragStart", beginBarDrag)
        frame:SetScript("OnDragStop", endBarDrag)

        -- ---- compact bar: heal ------------------------------------------------------------------
        -- No leading icon (removed 2026-08-24, in-game feedback: purely decorative, the number
        -- next to it already says everything it could -- see V.formatHealSegment's own comment).
        -- No trailing OH either any more -- see V.formatHealSegment's own comment for that removal.
        -- Font 11 -> 9 (in-game height-correction pass): matches BAR_H's own shrink to the
        -- 10px-pill weight class -- an 11pt number no longer fits a ~16px-tall bar comfortably.
        frame.vfHealText = W.MakeText(frame, 9, W.COLORS.goldHi, "OVERLAY")
        -- Tooltip (2026-08-25, in-game report: what does the first number mean, and why does it
        -- have no explanatory tooltip?). TRACED, not guessed: this number is V.formatHealSegment(stats)
        -- where stats = VampifyAggregate.fight(VampifyState) (see V.update below) -- the CURRENT
        -- FIGHT's own healing total (core/aggregate.lua's fHeal), reset to 0 the instant a NEW
        -- fight starts (the first hit after being fully out of combat -- core/commands.lua's
        -- beginFight) and otherwise frozen at that fight's final total from the moment it ends
        -- until the next one begins. This is a DIFFERENT time window than the two-color pill next
        -- to it (SESSION totals, VampifyAggregate.splitTotals("session", ...) -- see the pill's own
        -- tooltip below) -- reading "0" here next to a large pill number is not a bug, it means no
        -- fight is currently contributing to THIS number while the session total keeps its history.
        attachSegmentTooltip("VampifyDisplayHealHover", frame, frame.vfHealText, "ANCHOR_TOP", function()
            GameTooltip:AddLine("Vampirism healing")
            GameTooltip:AddLine("This fight only. Resets to 0 the moment a new fight starts,"
                .. " and freezes at that fight's total once it ends, until the next one begins.",
                0.8, 0.8, 0.8, 1)
            GameTooltip:AddLine("For running totals across the whole session or character, hover"
                .. " the two-color pill (if shown) for the full breakdown, or check /vf status.", 0.6, 0.6, 0.6, 1)
        end)

        frame.vfSep1 = makeBarSeparator(frame, "VampifyDisplaySep1")
        -- makeBarSeparator hardcodes an initial 10px height (its own textually-earlier declaration
        -- cannot see PILL_H as a real upvalue -- see this file's own W-hoisting/lexical-scope trap
        -- note near V.build's `local W` above) -- corrected here, and again live by
        -- V.applyPillHeight, to the CONFIG-DRIVEN PILL_H this function just set above.
        frame.vfSep1:SetHeight(PILL_H)

        -- ---- ST/AoE pill -- replaces the old icon+text badge group entirely (2026-08-24, in-game
        -- report: the icons are not strictly necessary either -- a neat two-color pill shape that
        -- shows the ratio) -- see buildPill's own header comment for the shape/texture
        -- story and its "sole hover-trigger" role. Hidden whenever VampifyAggregate.splitTotals is
        -- absent or reports nothing measured -- see V.update's showBadge gate and
        -- V.formatBadgeGroup's own fallback contract (name kept: still "is there anything to show
        -- at all", just for the pill now instead of a text badge).
        frame.vfPill = buildPill(frame, "VampifyDisplayPill")
        -- The pill is mouse-enabled as the sole hover-trigger for the breakdown panel, which also
        -- made the widest part of the bar undraggable until now.
        makeBarDraggable(frame.vfPill)

        -- Sole hover-trigger for the breakdown panel now (hover-chain level 2) -- 2026-08-24,
        -- in-game report: the detail list should only open when the mouse is over this "pill",
        -- not over the other elements. `frame` itself no longer opens anything on hover (see this file's own
        -- OnEnter/OnLeave comment further down) -- only the pill does.
        frame.vfPill:SetScript("OnEnter", function()
            V.chainEnter(Chain)
            V.showTooltip()
            -- Native GameTooltip ALONGSIDE the custom breakdown panel above (2026-08-25, in-game
            -- report: the two-color pill should also show the two values and the share) -- ANCHOR_TOP,
            -- opening ABOVE the pill, because the breakdown panel itself always opens BELOW the bar
            -- (V.showTooltip's own tip:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", ...)) -- the two
            -- therefore never overlap, and neither call interferes with the other: V.showTooltip()
            -- above already owns opening/positioning the panel, this only ADDS a second, native
            -- readout next to the cursor. Reads the SAME cached frame.vfLast* fields the
            -- resize-grip's own OnSizeChanged handler already relies on (set once per V.update
            -- tick, see that function's own comment) rather than recomputing anything.
            -- SESSION-scoped (V.update's own splitOut = VampifyAggregate.splitTotals("session",
            -- ...)) -- a DIFFERENT time window than the heal number to the pill's own left (that
            -- segment is THIS FIGHT only, see its own tooltip) -- said explicitly so the two
            -- numbers on this one bar are never mistaken for the same window.
            GameTooltip:SetOwner(this, "ANCHOR_TOP")
            GameTooltip:AddLine("Single-Target / AoE split -- this session")
            GameTooltip:AddLine("Red = healing from hits that landed on your CURRENT target."
                .. " Blue = everything else (no target, or a different unit).", 0.8, 0.8, 0.8, 1)
            if frame.vfLastRedLabel then
                GameTooltip:AddLine(string.format("Single-Target: %s (%.0f%%)",
                    frame.vfLastRedLabel, frame.vfLastStPct or 0),
                    W.COLORS.targetRed.r, W.COLORS.targetRed.g, W.COLORS.targetRed.b)
                GameTooltip:AddLine(string.format("AoE / other: %s (%.0f%%)",
                    frame.vfLastBlueLabel or "0", frame.vfLastAoePct or 0),
                    W.COLORS.restBlue.r, W.COLORS.restBlue.g, W.COLORS.restBlue.b)
            else
                GameTooltip:AddLine("Nothing measured yet this session.", 0.6, 0.6, 0.6, 1)
            end
            GameTooltip:Show()
        end)
        frame.vfPill:SetScript("OnLeave", function()
            V.chainLeave(Chain, 2)
            GameTooltip:Hide()
        end)

        frame.vfSep2 = makeBarSeparator(frame, "VampifyDisplaySep2")
        frame.vfSep2:SetHeight(PILL_H)

        -- ---- HPS: plain text, no orb (removed in-game correction pass -- see this block's own
        -- header comment above buildPill/layoutBarSegments for the full history). Unconditional:
        -- the bar has no hard width ceiling forcing it off, so it always shows.
        frame.vfHpsText = W.MakeText(frame, 9, W.COLORS.ink, "OVERLAY")
        attachSegmentTooltip("VampifyDisplayHpsHover", frame, frame.vfHpsText, "ANCHOR_TOP", function()
            GameTooltip:AddLine("Healing per second")
            GameTooltip:AddLine("Same window as the heal number to its left -- this fight's own"
                .. " total healing divided by the fight's elapsed time so far.", 0.8, 0.8, 0.8, 1)
        end)

        -- ---- gear%-on-bar segment (2026-08-25 option, "show vampirism % on bar", off by default
        -- -- see the checkbox's own comment in gui/options.lua for the default's reasoning) --
        -- "<Total%> (<source count>)", e.g. "14.0% (9)". Text/color/format are V.formatSources
        -- VERBATIM (already used by gui/options.lua's own info panel and this file's row-detail
        -- rate line -- the same figure, not recomputed) -- this is not a new
        -- computation, only a new PLACE the same figure is drawn. Created unconditionally (so
        -- layoutBarSegments/recomputePillW can rely on the fields always existing, same convention
        -- as vfSep1/vfPill's own always-created-but-conditionally-shown pattern) but left EMPTY and
        -- hidden until V.update's own showPct gate turns it on -- see that function's own comment.
        frame.vfSep3 = makeBarSeparator(frame, "VampifyDisplaySep3")
        frame.vfSep3:SetHeight(PILL_H)
        frame.vfPctText = W.MakeText(frame, 9, W.COLORS.dim, "OVERLAY")
        attachSegmentTooltip("VampifyDisplayPctHover", frame, frame.vfPctText, "ANCHOR_TOP", function()
            GameTooltip:AddLine("Equipped Vampirism total")
            GameTooltip:AddLine("Sum of your equipped gear's Vampirism percentages across every"
                .. " detected source, and how many sources that is -- the same \"Total%\" figure"
                .. " shown in Options.", 0.8, 0.8, 0.8, 1)
            local sources = VampifyState and VampifyState.sourcePercents
            if sources then
                GameTooltip:AddLine("Currently: " .. V.formatSources(sources), 0.6, 0.6, 0.6, 1)
            end
        end)

        -- Initial pill-width guess -- both text FontStrings exist now (empty, so this reads as the
        -- most generous possible guess, clamped) -- corrected for real on the first V.update tick,
        -- same as before.
        recomputePillW(frame)

        layoutBarSegments(frame, false, false)

        -- Reset button, same face family as the options one -- anchored to the bar's own LAST
        -- CONTENT segment, not a fixed frame-relative position (a fixed "RIGHT of frame" anchor
        -- would let the button's own opaque fill paint over live content once a segment ran close
        -- to the bar's edge -- anchoring to real content instead means it never can, regardless of
        -- how wide any individual segment's text turns out to be in-game). The initial anchor below
        -- targets HPS text (today's last segment); frame.vfResetBtn (2026-08-25, added for the new
        -- optional gear%-on-bar segment) lets layoutBarSegments re-anchor this button dynamically
        -- to whichever segment ends up last once that option can push HPS out of that spot -- see
        -- layoutBarSegments' own comment. Options button (below) then chains off THIS one,
        -- preserving the old visual order (reset left of options).
        local rst = CreateFrame("Button", "VampifyDisplayResetButton", frame)
        makeBarDraggable(rst)
        frame.vfResetBtn = rst
        rst:SetWidth(BTN_W)
        rst:SetHeight(BTN_W)
        rst:SetPoint("LEFT", frame.vfHpsText, "RIGHT", GAP, 0)
        rst:SetBackdrop(W.SOLID_BACKDROP)
        rst:SetBackdropColor(0, 0, 0, 0)
        rst:SetBackdropBorderColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b, 1)

        local ricon = rst:CreateTexture("VampifyDisplayResetIcon", "ARTWORK")
        ricon:SetTexture("Interface\\Icons\\Spell_ChargeNegative")
        ricon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ricon:SetPoint("TOPLEFT", rst, "TOPLEFT", 1, -1)
        ricon:SetPoint("BOTTOMRIGHT", rst, "BOTTOMRIGHT", -1, 1)
        ricon:SetVertexColor(0.75, 0.75, 0.75)

        -- No V.chainEnter(Chain) here any more (2026-08-24, change 2): the pill is now the
        -- SOLE hover-trigger for the breakdown panel, and `frame` itself no longer opens/arms
        -- anything on hover (see the pill's own OnEnter/OnLeave in the ST/AoE pill block above,
        -- and this file's own removed frame:OnEnter/OnLeave below) -- this button hovering `frame`
        -- underneath it can no longer arm a close countdown that needs cancelling. Keeping the
        -- call would have been actively WRONG under the new design, not just redundant: it would
        -- cancel a close countdown armed by leaving the PILL/panel/detail chain just because the
        -- mouse happens to be sitting on this unrelated button elsewhere on the bar.
        rst:SetScript("OnEnter", function()
            this:SetBackdropBorderColor(W.COLORS.gold.r, W.COLORS.gold.g, W.COLORS.gold.b, 1)
            getglobal("VampifyDisplayResetIcon"):SetVertexColor(1, 1, 1)
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Reset session")
            GameTooltip:AddLine("Clears totals and the per-ability breakdown.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        rst:SetScript("OnLeave", function()
            this:SetBackdropBorderColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b, 1)
            getglobal("VampifyDisplayResetIcon"):SetVertexColor(0.75, 0.75, 0.75)
            GameTooltip:Hide()
        end)
        rst:SetScript("OnClick", function()
            if VampifyResetSession then VampifyResetSession() end
        end)

        -- Small options button on the bar itself: the minimap button is easy to lose among a dozen
        -- others, and the bar is the thing the user is already looking at.
        -- Same face as the minimap button: identical icon and identical crop, so the two read as
        -- one addon rather than two. Only the frame around it differs, because a bar this thin has
        -- no room for the 54px minimap ring. Anchored to the reset button (see its own comment
        -- above for why this chains off real content instead of a fixed frame-edge position).
        local opt = CreateFrame("Button", "VampifyDisplayOptionsButton", frame)
        makeBarDraggable(opt)
        opt:SetWidth(BTN_W)
        opt:SetHeight(BTN_W)
        opt:SetPoint("LEFT", rst, "RIGHT", BTN_GAP, 0)
        opt:SetBackdrop(W.SOLID_BACKDROP)
        opt:SetBackdropColor(0, 0, 0, 0)
        opt:SetBackdropBorderColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b, 1)

        local icon = opt:CreateTexture("VampifyDisplayOptionsIcon", "ARTWORK")
        icon:SetTexture("Interface\\Icons\\Spell_Shadow_LifeDrain02")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- same crop as gui/minimap.lua
        icon:SetPoint("TOPLEFT", opt, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", opt, "BOTTOMRIGHT", -1, 1)
        icon:SetVertexColor(0.75, 0.75, 0.75)      -- resting: slightly dimmed

        -- No V.chainEnter(Chain) here either -- same reasoning as the reset button's own comment
        -- above.
        opt:SetScript("OnEnter", function()
            this:SetBackdropBorderColor(W.COLORS.gold.r, W.COLORS.gold.g, W.COLORS.gold.b, 1)
            getglobal("VampifyDisplayOptionsIcon"):SetVertexColor(1, 1, 1)
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Vampify")
            GameTooltip:AddLine("Click to open the options.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        opt:SetScript("OnLeave", function()
            this:SetBackdropBorderColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b, 1)
            getglobal("VampifyDisplayOptionsIcon"):SetVertexColor(0.75, 0.75, 0.75)
            GameTooltip:Hide()
        end)
        opt:SetScript("OnClick", function()
            if VampifyOptions and VampifyOptions.toggle then VampifyOptions.toggle() end
        end)

        -- The watchdog otherwise only speaks when it finds something, which makes "nothing wrong"
        -- and "not running" look identical. This marker is the visible difference: absent while the
        -- checks hold, present the moment one does not.
        warnBtn = CreateFrame("Button", "VampifyDisplayWarnButton", frame)
        makeBarDraggable(warnBtn)
        warnBtn:SetWidth(BTN_W)
        warnBtn:SetHeight(BTN_W)
        warnBtn:SetPoint("LEFT", frame, "RIGHT", 4, 0)
        local wt = W.MakeText(warnBtn, 11, W.COLORS.gold, "OVERLAY")
        wt:SetPoint("CENTER", warnBtn, "CENTER", 0, 0)
        wt:SetText("!")
        wt:SetTextColor(1, 0.35, 0.35)
        warnBtn:SetScript("OnEnter", function()
            if not warnMsg then return end
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
            GameTooltip:AddLine("Vampify watchdog", 1, 0.8, 0.2)
            -- Wrapped: these lines are sentences, not labels, and an unwrapped one runs off screen.
            GameTooltip:AddLine(warnMsg, 1, 0.5, 0.5, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("This flags an inconsistency in Vampify's own numbers.", 0.7, 0.7, 0.7, 1)
            GameTooltip:Show()
        end)
        warnBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        warnBtn:Hide()

        -- `frame` itself no longer opens the breakdown panel on hover (2026-08-24, change 2,
        -- in-game report: the detail list should only open when the mouse is over this "pill",
        -- not over the other elements) -- that trigger now lives solely on frame.vfPill's own OnEnter/
        -- OnLeave (see the ST/AoE pill block above). `frame` keeps no chain-related script at all:
        -- it is still mouse-enabled (EnableMouse(true) above) for dragging, and still owns
        -- OnMouseUp (right-click, below) and OnUpdate (chain ticking, below), neither of which is
        -- a hover trigger. This also RETIRES the button focus-steal workaround the old design
        -- needed (see the reset/options buttons' own comments above): with no OnLeave left on
        -- `frame` for a button's mouse focus to steal, there is nothing left for them to interfere
        -- with.
        --
        -- Right-click rotates the breakdown through session -> lifetime -> last -> session
        -- (extended 2026-08-25 for the third "last" tab -- V.nextScope is the one
        -- shared rotation rule, also used by nothing else needing to guess this order twice), and
        -- DELIBERATELY stays bound to the WHOLE bar rather than moving to just the pill (no
        -- explicit ask either way for this one; least-surprising choice, decided here): it is a click,
        -- not a hover, so it cannot re-trigger the button-focus-steal problem the hover trigger had,
        -- and a user is not expecting a narrow "must land exactly on the pill" target for a
        -- right-click on what is still, visually, one draggable bar -- the pill is a ST/AoE ratio
        -- indicator, not (in the player's mental model) the whole bar's hit-test area.
        -- V.showTooltip (not the bare local `tip`) is called deliberately -- `tip` is declared with
        -- `local` further down this same file, textually AFTER V.build(), so referencing it here
        -- would resolve to a global instead of the tooltip's real upvalue -- see the W-hoisting
        -- comment on VampifyWidgets above for the mirror-image version of this same 5.0/lexical-
        -- scope trap, caught in-game once already. Safe to call even if the panel is not currently
        -- open (a right-click while only, say, the heal number is hovered) -- V.showTooltip lazily
        -- builds/shows on its own regardless of the pill's own hover state.
        frame:SetScript("OnMouseUp", function()
            if arg1 == "RightButton" then
                V.tipScope = V.nextScope(V.normalizeScope(V.tipScope))
                V.showTooltip()
            end
        end)

        -- Drives the hover chain's shared countdown (see the Chain block above) -- a single field
        -- read on every frame the countdown is not running, which is the overwhelming majority of
        -- them. 1.12's OnUpdate carries its elapsed time as the global arg1, not a function
        -- parameter (confirmed against the offline test harness's own client stub, which calls
        -- OnUpdate handlers with no arguments and sets arg1 itself, mirroring the client).
        --
        -- Also drives the geometric self-healing safety net (rescueCheck, assigned further down
        -- this section once `tip`/`detail` exist -- see its own header comment) -- nil-guarded
        -- since it is not assigned yet the first several times this handler runs after V.build().
        frame:SetScript("OnUpdate", function()
            V.chainTick(Chain, arg1)
            if rescueCheck then rescueCheck(arg1) end
        end)

        -- ---- drag-resize grip (a corner handle, the way a resizable window offers one) ----
        -- A dedicated corner handle, not the whole bar (the whole bar already owns left-drag-to-
        -- MOVE) -- three small dots, same recipe as the bar's own separators (WHITE8X8, tinted),
        -- so it needs no extra texture asset and degrades to nothing (never an error) if that base
        -- Blizzard texture were ever missing. SetFrameLevel above the bar's own content so a row of
        -- buttons this close to the corner cannot steal its mouse focus.
        -- Shrunk 12x12 -> 8x8 alongside the BAR_H cut (a 12px grip on a 16px bar left almost no
        -- clearance). Still a pure OVERLAY -- BOTTOMRIGHT-anchored on top of existing content, not
        -- part of the anchor chain, so it never reserves its own layout space (confirmed by reading
        -- the anchor chain: nothing anchors FROM the grip, only the grip anchors TO the frame) --
        -- this is already exactly the "overlays the content instead of claiming its own layout
        -- space" shape asked for when the dead-space bug was investigated; the grip was cleared as a cause
        -- of that bug for the same reason.
        local grip = CreateFrame("Frame", "VampifyDisplayResizeGrip", frame)
        grip:SetWidth(8)
        grip:SetHeight(8)
        grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        grip:EnableMouse(true)
        grip:SetFrameLevel(frame:GetFrameLevel() + 10)
        local function gripDot(ox, oy)
            local t = grip:CreateTexture(nil, "OVERLAY")
            t:SetTexture(W.SOLID_TEX)
            t:SetWidth(1)
            t:SetHeight(1)
            t:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", ox, oy)
            t:SetVertexColor(W.COLORS.goldSoft.r, W.COLORS.goldSoft.g, W.COLORS.goldSoft.b)
        end
        gripDot(-1, -1); gripDot(-1, -4); gripDot(-4, -1)

        grip:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine("Drag to resize")
            GameTooltip:AddLine("Mainly lengthens the pill.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- StartSizing("RIGHT") grows/shrinks from the bar's own right edge only -- the left edge
        -- (and therefore the bar's drag-to-move anchor) stays put, matching "waechst hauptsaechlich
        -- die Kapsel" without the whole bar visibly relocating under the user's cursor.
        grip:SetScript("OnMouseDown", function()
            local c = VampifyConfig.get()
            if not (c and c.locked) then frame:StartSizing("RIGHT") end
        end)
        grip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            local c = VampifyConfig.get()
            if c then c.size = { w = frame:GetWidth() } end
        end)

        -- OnSizeChanged fires continuously WHILE StartSizing is dragging, not only on release --
        -- reflowing the pill here (not just on mouse-up) is what makes the resize feel live rather
        -- than snapping into place afterwards. Only the pill's own width is recomputed; every other
        -- segment cascades automatically through its own relative SetPoint anchor (to the pill, or
        -- to whatever sits after it), so nothing else needs a manual re-layout call here. Guarded
        -- against firing before frame.vfPill exists: the script is attached only here, after every
        -- child is already built, so in practice this guard is pure insurance against a future
        -- caller resizing the frame some other way.
        frame:SetScript("OnSizeChanged", function()
            if not this.vfPill then return end
            local pillW = recomputePillW(this)
            layoutPill(this.vfPill, pillW, this.vfLastStPct or 0, this.vfLastAoePct or 0,
                this.vfLastRedLabel, this.vfLastBlueLabel)
        end)

        return frame
    end

    -- ---- the breakdown panel -------------------------------------------------------------------
    --
    -- A custom frame rather than GameTooltip: Blizzard's tooltip only knows a left and a right
    -- column, and with a proportional font that would not have lined up cleanly even for the OLD
    -- column-table layout. Variant B2 (below) has no columns left at all -- see PANEL_W's own
    -- comment for why.
    --
    -- The panel wears the SLIM backdrop, not the options window's heavy panel border: it is a
    -- hover readout, not a window, and it was asked to be more subtle than the options menu. That
    -- also fixes the padding problem the heavy border caused -- its texture is 16px wide, so text
    -- at 12px inset ran underneath it on all four sides. A 1px border needs far less clearance.
    local PAD      = 12
    -- Bumped again, 13 -> 16 -> 18 (2026-08-24 pixel measurement pass, Finding 3): each row IS a
    -- bar now, with icon+name+value drawn directly inside its solid fill (see setRow below) --
    -- needs a bit more vertical breathing room than the old "faint bar behind a column of text"
    -- layout did.
    --
    -- ROW_H is now SLIDER-DRIVEN, SavedVariables-backed (2026-08-25, in-game report: control the
    -- detail bars' height too -- was a flat constant before this change). SPLIT_ROW_H (declared further down, kept
    -- EQUAL to ROW_H -- they already were, coincidentally, before this slider existed) and
    -- DETAIL_LINE_H (the row-detail panel's own line height, a smaller metric even at their shared
    -- default) both move with it -- see V.applyPanelBarHeight, defined once DETAIL_LINE_H itself
    -- exists, for the exact derivation and DETAIL_LINE_H's own floor.
    --
    -- Bounds, exposed as V.PANEL_BAR_H_MIN/MAX so gui/options.lua's slider uses these SAME two
    -- numbers rather than a second hand-copied pair: 10 and 24 are the named bounds from the
    -- in-game feedback pass this slider answers (below roughly 8px it became unreadable, for a
    -- THINNER bar than
    -- this one -- these rows carry a full name+value FontString pair under THICKOUTLINE+shadow, not
    -- just the pill's two short numbers, so the floor sits a little higher at 10 -- above roughly
    -- 24px it looked too thick, taken as the literal ceiling). The slider's own SetMinMaxValues enforces
    -- both directly (values outside them are simply unreachable, not separately hidden/faded at
    -- render time). 18 is the shipped default, unchanged from before this slider existed.
    -- Ceiling raised 24 -> 40 (2026-08-25, same ask as V.PILL_H_MAX above, in-game report: give
    -- both sliders the same maximum). Floor (10) and DEFAULT (18, the shipped default) are
    -- untouched. DETAIL_LINE_H (V.applyPanelBarHeight below) derives off this at a fixed 12/18
    -- ratio with no ceiling of its own -- at newH=40 that is 40*12/18=26.67 -> 27, comfortably
    -- inside a readable range, not re-derived here.
    V.PANEL_BAR_H_MIN, V.PANEL_BAR_H_MAX, V.PANEL_BAR_H_DEFAULT = 10, 40, 18
    local function clampPanelBarH(h)
        h = h or V.PANEL_BAR_H_DEFAULT
        if h < V.PANEL_BAR_H_MIN then h = V.PANEL_BAR_H_MIN end
        if h > V.PANEL_BAR_H_MAX then h = V.PANEL_BAR_H_MAX end
        return h
    end
    -- Starts at the flat default, same as PILL_H originally did -- this whole section runs at FILE
    -- LOAD time (a sibling of V.build() in this outer `if CreateFrame then` block, not inside it),
    -- before SavedVariables is necessarily wired up. The PERSISTED value is applied for real by
    -- V.applyPanelBarHeight, called once from buildTip() below (built lazily on first hover, well
    -- after login) -- same two-stage pattern V.build() itself uses for PILL_H (see its own comment).
    local ROW_H    = V.PANEL_BAR_H_DEFAULT
    -- Variant B2, the chosen target layout (Finding 3, 2026-08-24 pixel measurement pass):
    -- NO column table any more -- Damage/Vamp/OH/% as separate text columns are gone for good.
    -- Each row is one bar (length = share of the LARGEST row's heal, see V.shareOfMax above),
    -- icon+name drawn inside at its left edge, ONE right-anchored vamp-heal value (k-notation) at
    -- the row's own fixed right edge.
    --
    -- PANEL_W now follows the compact bar's own CURRENT (drag-resized) width, not a fixed constant
    -- (in-game correction: when the bar is dragged bigger/smaller, the detail window should get
    -- more/less space too). Floored at MIN_PANEL_W so the icon/name/value
    -- columns can never collapse into an unreadable sliver when the bar itself is dragged down to
    -- its own small end (BAR_MIN_W, driven by PILL_MIN_W=70, is well under a usable panel width).
    -- MIN_PANEL_W = PAD + an icon-width column (ROW_H) + a readable minimum name width (~70px,
    -- enough for a short ability name without truncating on every row) + ROW_VALUE_RESERVE + PAD,
    -- rounded up for comfort -- checked against a rendered narrow-width pass, not
    -- just the arithmetic. Recomputed every repaint (V.showTooltip) via computePanelW() below, and
    -- live while the resize grip is being dragged (see reflowPanels, assigned near V.showRowDetail)
    -- -- PANEL_W itself stays a plain reassignable local, same forward-reference pattern this file
    -- already uses for `frame`/`tip`/`detail` (declared once, read through the upvalue everywhere).
    local MIN_PANEL_W = 220
    local PANEL_W = MIN_PANEL_W
    local function computePanelW()
        local w = (frame and frame:GetWidth()) or MIN_PANEL_W
        if w < MIN_PANEL_W then w = MIN_PANEL_W end
        return w
    end

    -- Reserved at the row's right edge for its own value label ("14.0k", "8.8M", ...) plus a
    -- little breathing room -- the ability-row name's own width is capped to leave this much
    -- clear so a long name can never run underneath/behind the value text. Generous on purpose:
    -- the widest realistic label this addon prints here is an M-scale amount ("123.4M"), and
    -- V.formatAmount never grows past one decimal digit at any scale (see its own header comment).
    local ROW_VALUE_RESERVE = 54
    -- Vertical gap between adjacent ability-row bars (2026-08-24, pixel-level review of a rendered
    -- breakdown panel): with no gap at all, adjacent rows' solid fills
    -- (each ROW_H - 2 tall) left only a bare 2px seam between them -- visually one stacked block
    -- rather than distinguishable rows, unlike the ~12px the split row above already keeps clear
    -- of the first ability row. A modest, not decorative, gap: just enough that the eye can find
    -- where one row ends and the next begins.
    local ROW_GAP = 2

    local tip, tipRows, tipHead, tipNote, tipFooter = nil, {}, nil, nil, nil
    local tipIcons = nil   -- see its own CreateFrame below: the one thing that must outrank a bar
    local tipBuf, mergeBuf = {}, {}
    -- Pooled `out` table for VampifyAggregate.splitTotals -- the panel's own ST/AoE split row (see
    -- buildTip's tip.vfSplit* widgets and renderSplitRow further down). Same convention as
    -- tipBuf/mergeBuf above: one reused table, refilled every V.showTooltip repaint, never rebuilt.
    local splitBuf = {}
    -- Pooled output of V.buildTopRows (Finding 4: top V.TOP_ROWS abilities + one collapsed "Other"
    -- row) and V.shareOfMax (Finding 1: bar LENGTH normalized to the largest row, not the total --
    -- see both functions' own header comments). Neither of these shares a pooled buffer with
    -- VampifyAggregate.spellSplit/spellSourceBreakdown the way the old V.shareOfTotal-in-this-loop
    -- call used to (see git history for that earlier pooled-buffer bug, covered by an existing
    -- regression test) -- both are owned entirely by THIS file, so there is
    -- no cross-module aliasing hazard left to snapshot against here.
    local topRowsBuf, shareMaxBuf = {}, {}

    -- Per-data-row invisible mouse frames (pin-only, see buildTip's tip:EnableMouse comment and the
    -- setRow-adjacent loop in V.showTooltip below) and the row index they currently represent --
    -- rowEntryMap[i] is the SAME merged-row table mergeBuf[i] holds, so V.showRowDetail(i) below
    -- never re-merges, it only reads what the last repaint already computed. repaintVersion is
    -- bumped once per V.showTooltip() call and lets V.showRowDetail's own change-guard tell "still
    -- looking at the row from the SAME repaint" apart from "the data underneath this row index may
    -- have changed since" -- see V.showRowDetail's comment for why an index alone is not enough.
    --
    -- hoveredRowIndex: the row index the mouse is CURRENTLY sitting over (set/cleared by
    -- rowHoverFrame's OnEnter/OnLeave below), separate from detailLastIndex below (which is a
    -- "what did we last RENDER" cache key, not a "is the mouse still there" fact). V.showTooltip
    -- reads this to refresh an actively-hovered row's detail panel in place across a periodic
    -- pinned repaint instead of hiding it and waiting for a fresh OnEnter that will never come
    -- while the mouse hasn't moved.
    --
    -- lastPinRepaintTime: GetTime() of the last periodic repaint V.update triggered while pinned
    -- (see V.update below) -- paired with the pure V.shouldRepaintPin gate so the panel refreshes
    -- at most once a second while pinned, matching V.update's own throttle rather than the raw
    -- ~2/s rate commands.lua calls V.update at.
    local tipRowHovers, rowEntryMap, repaintVersion, hoveredRowIndex, lastPinRepaintTime =
        {}, {}, 0, nil, 0

    -- The row-DETAIL panel's own frame and its state, declared HERE rather than down next to
    -- buildDetail (where they used to live) so they are already real upvalues -- not a same-named
    -- GLOBAL that happens to read nil -- for V.showTooltip and V.hideTooltip below, both of which
    -- are defined textually BEFORE the "row-detail panel: WoW-wiring shell" section. This is
    -- exactly the Lua 5.0/lexical-scope trap this file's own W-hoisting comment (see V.build above)
    -- warns about, and it bit for real here (adversarial review, 2026-08-23): `if detail then
    -- detail:Hide() end` in both of those functions was silently reading an always-nil global and
    -- never hiding anything.
    -- detailLastIndex/detailLastVersion: the last row shown, as (data-row index, repaintVersion) --
    -- see repaintVersion's own comment just above for why BOTH are needed: the index alone cannot
    -- tell "still hovering the same row" from "hovering a DIFFERENT row that reused the same pool
    -- slot after a repaint".
    local detail, detailLinesFS, detailLinesBar, detailLastIndex, detailLastVersion =
        nil, {}, {}, nil, nil

    -- Rounded panel corners (2026-08-24, precise build instructions from the separate
    -- texture-authoring pass -- panel_corner.tga, 16x16, ONE rounded corner as a white+alpha mask, under
    -- gui/'s textures/ folder). Composition: the fill is TWO rectangles, NOT one -- RectA (full
    -- width, top/bottom inset by the corner radius) and RectB (full height, left/right inset by
    -- it) -- deliberately leaving the four cornerRadius x cornerRadius squares at the panel's
    -- corners UNPAINTED by either rect (a single full-size rect would paint square corners UNDER
    -- the rounded mask, which would then show through as a hard square edge behind the curve).
    -- Those four squares are then covered by panel_corner, tinted to the fill color and mirrored
    -- via SetTexCoord (the mask is opaque at texel (0,0) and transparent at the opposite corner,
    -- so mirroring alone reorients it -- no rotation needed, per the build instructions).
    --
    -- The frame's own SetBackdrop stays -- for the 1px BORDER line only (SetBackdropColor alpha
    -- 0, so its own square bg fill draws nothing) -- same "border-only backdrop drawn OVER
    -- separate BACKGROUND-layer fills" convention this file already uses for the split row's
    -- vfSplitFrame. The border itself stays square (1.12's backdrop border system has no concept
    -- of corner radius) -- a known, minor visual mismatch against the now-rounded fill, not
    -- attempted here (no vector line primitive exists to draw a rounded border instead).
    --
    -- Degradation: a missing/not-yet-restarted panel_corner.tga renders that corner's own mask as
    -- nothing (WoW 1.12 never errors on a missing texture path) -- the two rects underneath
    -- already cover most of the panel, so the visible result is a small transparent notch at that
    -- corner, never a broken or invisible frame.
    local PANEL_CORNER_R = 8
    local PANEL_CORNER_TEX = "Interface\\AddOns\\Vampify\\textures\\panel_corner"
    local function buildTipFill(t)
        local r, g, b, a = 0.043, 0.052, 0.068, 0.94
        t.fillA = t:CreateTexture("VampifyBarTooltipFillA", "BACKGROUND")
        t.fillA:SetTexture(r, g, b, a)
        t.fillB = t:CreateTexture("VampifyBarTooltipFillB", "BACKGROUND")
        t.fillB:SetTexture(r, g, b, a)
        local function corner(name)
            local c = t:CreateTexture(name, "BACKGROUND")
            c:SetTexture(PANEL_CORNER_TEX)
            c:SetVertexColor(r, g, b)
            c:SetAlpha(a)
            c:SetWidth(PANEL_CORNER_R)
            c:SetHeight(PANEL_CORNER_R)
            return c
        end
        -- SetTexCoord(left, right, top, bottom) -- swapping a pair mirrors that axis. The mask's
        -- own opaque corner is texel (0,0); each call below reorients it to whichever of the
        -- panel's four corners that texture instance sits in (verbatim from the build instructions).
        t.cornerBR = corner("VampifyBarTooltipCornerBR"); t.cornerBR:SetTexCoord(0, 1, 0, 1)
        t.cornerTR = corner("VampifyBarTooltipCornerTR"); t.cornerTR:SetTexCoord(0, 1, 1, 0)
        t.cornerBL = corner("VampifyBarTooltipCornerBL"); t.cornerBL:SetTexCoord(1, 0, 0, 1)
        t.cornerTL = corner("VampifyBarTooltipCornerTL"); t.cornerTL:SetTexCoord(1, 0, 1, 0)
    end

    -- Re-anchors the fill for the panel's CURRENT width (fixed, PANEL_W) and height (variable --
    -- the panel grows/shrinks with its own row count every repaint, see tip:SetHeight(-y) in
    -- V.showTooltip below, which calls this right after). Guards h < 2*PANEL_CORNER_R (a panel
    -- shorter than both corners stacked) by clamping so RectA never inverts to a negative height.
    local function layoutTipFill(t, w, h)
        local r = PANEL_CORNER_R
        if h < 2 * r then h = 2 * r end
        t.fillA:ClearAllPoints()
        t.fillA:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -r)
        t.fillA:SetWidth(w)
        t.fillA:SetHeight(h - 2 * r)
        t.fillB:ClearAllPoints()
        t.fillB:SetPoint("TOPLEFT", t, "TOPLEFT", r, 0)
        t.fillB:SetWidth(w - 2 * r)
        t.fillB:SetHeight(h)
        t.cornerTL:ClearAllPoints(); t.cornerTL:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
        t.cornerTR:ClearAllPoints(); t.cornerTR:SetPoint("TOPRIGHT", t, "TOPRIGHT", 0, 0)
        t.cornerBL:ClearAllPoints(); t.cornerBL:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
        t.cornerBR:ClearAllPoints(); t.cornerBR:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
    end

    -- ---- lifetime reset confirmation (2026-08-25, StaticPopupDialogs -- verified 1.12 pattern
    -- ) -------------------------------------------------------------------------
    --
    -- StaticPopupDialogs is Blizzard's own GLOBAL table (FrameXML/StaticPopup.xml/.lua) -- every
    -- addon that wants a confirm dialog inserts its own key into it, so this is a plain table
    -- assignment, not a CreateFrame, and only needs to run ONCE regardless of how many times
    -- V.build()/buildTip() run. The text below spells out exactly what is destroyed (so the
    -- warning is concrete rather than vague) rather than a generic "are you sure?" -- see
    -- core/aggregate.lua's A.resetScope header comment for the authoritative list of what
    -- resetScope("lifetime") actually clears; this string is kept in sync with that comment by hand
    -- (both are prose, there is no shared constant to drift out of sync silently either way).
    -- timeout=0 (never auto-closes/auto-accepts -- a nonzero timeout risks resolving a DESTRUCTIVE
    -- action on its own) and whileDead=1 (a ghost can still open the breakdown panel and click this)
    -- are the two fields that actually matter for a destructive
    -- confirm; button1/button2 use the localized YES/NO globals, matching Blizzard's own dialogs.
    --
    -- Guarded on StaticPopupDialogs existing (belt and braces, same "degrade quietly, never error"
    -- ethos this file uses for every other optional/host-provided piece -- e.g. buildTipFill's own
    -- missing-texture comment): the real client always defines it before any addon loads, but this
    -- whole `if CreateFrame then` section is written to survive a future offline stub that defines
    -- CreateFrame without also defining every FrameXML global.
    if StaticPopupDialogs then
        StaticPopupDialogs["VAMPIFY_RESET_LIFETIME"] = {
            text = "Permanently delete ALL lifetime Vampify data?\n\nThis erases healing, damage, "
                .. "overheal, hit counts, the per-source breakdown, and the Single-Target/AoE split "
                .. "-- accumulated across every session since this character existed. There is no undo.",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                if VampifyResetSession then VampifyResetSession("lifetime") end
                V.showTooltip()
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
    end

    local function buildTip()
        if tip then return tip end
        -- Applies the PERSISTED panel-bar-height slider value the first time this panel is ever
        -- actually built (lazily, on first hover -- well after login, when SavedVariables is
        -- reliably wired up) -- see ROW_H's own declaration comment for why reading config any
        -- earlier, at this section's own file-load time, would not have worked. V.applyPanelBarHeight
        -- is a GLOBAL table field (V.*), not a local -- calling it here despite being textually
        -- DEFINED further down this same file is safe: it resolves through the VampifyDisplay table
        -- at call time, not through Lua's compile-time local/upvalue resolution (unlike this file's
        -- own local-forward-reference traps, which this deliberately is not one of).
        do
            local cfg = VampifyConfig and VampifyConfig.get and VampifyConfig.get()
            V.applyPanelBarHeight(cfg and cfg.panelBarHeight)
        end
        tip = CreateFrame("Frame", "VampifyBarTooltip", UIParent)
        tip:SetWidth(PANEL_W)
        tip:SetHeight(80)
        -- DIALOG, deliberately NOT "TOOLTIP" (in-game report, 2026-08-25, screenshot: the
        -- "Reset lifetime" tooltip drawn UNDER this panel). GameTooltip lives in the TOOLTIP strata;
        -- a frame of ours in that same strata competes with it on frame level alone, and this one
        -- won -- so every tooltip raised while the breakdown panel is open, including the ones this
        -- panel's OWN rows raise, was liable to be buried by it. DIALOG sits above HIGH (the display
        -- bar, the minimap button, the options window) and below TOOLTIP, which is exactly the
        -- ordering this panel wants: over the whole UI, under anything explaining it. The explicit
        -- level makes the panel-vs-detail order deterministic too -- two frames sharing a strata AND
        -- a level have undefined draw order on this client, same class of bug as same-layer
        -- textures.
        tip:SetFrameStrata("DIALOG")
        tip:SetFrameLevel(20)
        -- Border only -- alpha-0 background (the backdrop system's own square bg fill draws
        -- nothing), so the visible fill is buildTipFill's rounded-corner composition on the
        -- BACKGROUND layer. Those two are the ONLY BACKGROUND users left on this frame, and they
        -- paint identical colour at identical alpha, so their mutual order is unobservable -- the
        -- one same-layer pairing in this file that needs no separation.
        tip:SetBackdrop(W.SOLID_BACKDROP)
        tip:SetBackdropColor(0, 0, 0, 0)
        tip:SetBackdropBorderColor(W.COLORS.line.r, W.COLORS.line.g, W.COLORS.line.b, 1)
        buildTipFill(tip)
        -- The ONE region that has to draw above a row's glass bar and is not a FontString: the
        -- ability icon, which sits inside the bar's left edge. With the bar occupying BORDER /
        -- ARTWORK / OVERLAY on `tip` (see buildGlassBar's header), there is no layer left above it
        -- -- HIGHLIGHT would only render under the mouse. Frame level dominates
        -- draw layer and IS deterministic, so a child frame one level up settles it once for every
        -- row. Absolute level, not parent-relative arithmetic, per the same finding
        -- above -- tip's own level is set explicitly just above.
        tipIcons = CreateFrame("Frame", "VampifyBarTooltipIcons", tip)
        tipIcons:SetAllPoints(tip)
        tipIcons:SetFrameLevel(21)
        layoutTipFill(tip, PANEL_W, 80)
        W.ApplyBackdropShadow(tip)
        -- Always mouse-enabled now (2026-08-24 hover-chain redesign -- was EnableMouse(false)
        -- click-through unless pinned; the pin mechanism is gone, see the Chain block on V.build
        -- above). Interactive at all times so the mouse can move from a row into this panel and on
        -- into the row-detail panel beside it without either one vanishing underfoot.
        tip:EnableMouse(true)
        tip:SetScript("OnEnter", function() V.chainEnter(Chain) end)
        tip:SetScript("OnLeave", function() V.chainLeave(Chain, 2) end)
        tip:Hide()

        tipHead = W.MakeText(tip, 11, W.COLORS.goldHi, "OVERLAY")
        tipHead:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, -10)
        tipHead:SetText("Vampify")

        -- Interactive [SESSION | LIFETIME | LAST] scope switch (2026-08-24 badge pass,
        -- extended 2026-08-25 for the third "last" tab, in-game report: add a third detail tab for
        -- "last" the same way). The LOGIC already existed (V.tipScope, toggled so far only by right-clicking the
        -- bar itself -- that keeps working unchanged, see frame:SetScript("OnMouseUp", ...) on
        -- V.build above); this only adds a second, clickable way to reach it from inside the panel.
        -- THREE Buttons rather than one cycling toggle: a single toggle cannot show all three
        -- options' state at once, and the point of a segmented control is that the reader can see
        -- the roads not taken. Attached as fields on `tip` (tip.vfScopeSessionBtn/
        -- vfScopeLifetimeBtn/vfScopeLastBtn) rather than new top-level upvalues of this block --
        -- V.showTooltip already reaches everything it needs to through the `tip` upvalue it already
        -- has, so this adds no new upvalue to that (already upvalue-heavy) closure, per this file's
        -- own Lua 5.0 upvalue-limit note.
        --
        -- Width shrunk 56 -> 50 and the labels lost their bracket-framing on the two ends that used
        -- to carry it ("[SESSION"/"LIFETIME]") -- a third segment needs the bracket pair to wrap the
        -- WHOLE row, not the middle-but-now-not-middle second one, and re-deriving which segment is
        -- an end from `x` here would be more state than the visual win is worth; a plain "SESSION" /
        -- "LIFETIME" / "LAST" reads as a three-way toggle on its own once the active one is
        -- highlighted gold (below) -- the row's own SHAPE (three buttons in a line) already carries
        -- the "these are alternatives" meaning the brackets used to add.
        local SCOPE_BTN_W, SCOPE_BTN_GAP = 50, 4
        local function scopeBtn(name, label, x, scope)
            local b = CreateFrame("Button", name, tip)
            b:SetWidth(SCOPE_BTN_W)
            b:SetHeight(12)
            b:SetPoint("TOPRIGHT", tip, "TOPRIGHT", x, -10)
            b.vfScope = scope
            b.vfText = W.MakeText(b, 9, W.COLORS.dim, "OVERLAY")
            b.vfText:SetPoint("RIGHT", b, "RIGHT", 0, 0)
            b.vfText:SetJustifyH("RIGHT")
            b.vfText:SetText(label)
            -- Stuck-panel fix (2026-08-24): this button sits INSIDE `tip`'s own rectangle
            -- and is independently mouse-enabled -- hovering it steals mouse focus from `tip` the
            -- same way the bar's options/reset buttons do from `frame` (see V.newChain's own
            -- header comment). Without this, hovering the scope toggle could arm a close countdown
            -- for the whole panel while the cursor never left it.
            b:SetScript("OnEnter", function() V.chainEnter(Chain) end)
            b:SetScript("OnClick", function()
                V.tipScope = this.vfScope
                V.showTooltip()
            end)
            return b
        end
        tip.vfScopeSessionBtn = scopeBtn("VampifyBarScopeSession", "SESSION", -PAD - 2 * (SCOPE_BTN_W + SCOPE_BTN_GAP), "session")
        tip.vfScopeLifetimeBtn = scopeBtn("VampifyBarScopeLifetime", "LIFETIME", -PAD - (SCOPE_BTN_W + SCOPE_BTN_GAP), "lifetime")
        tip.vfScopeLastBtn = scopeBtn("VampifyBarScopeLast", "LAST", -PAD, "last")

        -- ---- per-scope reset button (add a reset button for session and lifetime too, 2026-08-25) --------
        --
        -- ONE button, not three: exactly one scope is ever visible at a time (the toggle row just
        -- above), so "reset THIS scope" only ever needs to act on V.tipScope -- three permanently
        -- visible buttons would crowd this already-tight header row (see the scope toggle's own
        -- width math above -- three buttons already nearly reach MIN_PANEL_W=220's own inner span)
        -- for no behavioural difference. The button's own LABEL names the active scope ("Reset
        -- session"/"Reset lifetime"/"Reset last", set every repaint in V.showTooltip below) so what
        -- it is about to do is never ambiguous just because it is one control instead of three.
        --
        -- SESSION and LAST reset with a single click, no confirmation dialog (the call made here --
        -- session and last only need a lighter safeguard, or none at all): both are
        -- inherently transient -- session dies on the very next /reload or relogin regardless, and
        -- "last" dies on the very next fight regardless of whether this button is ever clicked (see
        -- core/aggregate.lua's A.startFight) -- so an accidental click loses nothing that a few more
        -- minutes of normal play would not already have discarded on its own, and the panel
        -- immediately repainting to an empty scope is its own obvious feedback.
        --
        -- LIFETIME is the one irreversible case (months of SavedVariables data, no upstream backup
        -- -- see core/aggregate.lua's A.resetScope header comment) and is gated behind a
        -- StaticPopupDialogs confirmation, the standard 1.12 pattern
        -- -- timeout=0 so the dialog can never auto-accept on its own, matching that the
        -- consequence is permanent. Registered once, at file scope (VAMPIFY_RESET_LIFETIME below,
        -- next to buildTip) rather than inside this function -- StaticPopupDialogs is a Blizzard
        -- GLOBAL table every addon shares, so this only ever needs to run once regardless of how
        -- many times buildTip() is (not) re-entered.
        --
        -- Falls back to DISABLED, not hidden -- a player who has never opened "last" yet should
        -- still see the control exists -- with a tooltip explaining why, when VampifyResetSession is
        -- entirely absent, or (last scope only) when V.lastScopeReady() is false -- the mandatory
        -- fallback per this file's own coordination contract with core/ (see V.lastScopeReady's own
        -- comment for why an un-upgraded core cannot safely be trusted with a "last" reset either).
        tip.vfResetBtn = CreateFrame("Button", "VampifyBarResetBtn", tip)
        tip.vfResetBtn:SetWidth(96)
        tip.vfResetBtn:SetHeight(11)
        tip.vfResetBtn:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -PAD, -24)
        tip.vfResetBtn.vfText = W.MakeText(tip.vfResetBtn, 9, W.COLORS.dim, "OVERLAY")
        tip.vfResetBtn.vfText:SetPoint("RIGHT", tip.vfResetBtn, "RIGHT", 0, 0)
        tip.vfResetBtn.vfText:SetJustifyH("RIGHT")
        tip.vfResetBtn:SetScript("OnEnter", function()
            V.chainEnter(Chain)
            if this.vfDisabled then return end
            GameTooltip:SetOwner(this, "ANCHOR_LEFT")
            GameTooltip:AddLine("Reset " .. V.normalizeScope(V.tipScope))
            if V.normalizeScope(V.tipScope) == "lifetime" then
                GameTooltip:AddLine("Permanently deletes ALL lifetime totals. Asks first.", 0.9, 0.5, 0.5, 1)
            else
                GameTooltip:AddLine("Clears this scope's totals and per-ability breakdown.", 0.8, 0.8, 0.8, 1)
            end
            GameTooltip:Show()
        end)
        tip.vfResetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tip.vfResetBtn:SetScript("OnClick", function()
            if this.vfDisabled then return end
            local scope = V.normalizeScope(V.tipScope)
            if scope == "lifetime" then
                if StaticPopup_Show then StaticPopup_Show("VAMPIFY_RESET_LIFETIME") end
            else
                if VampifyResetSession then VampifyResetSession(scope) end
                V.showTooltip()
            end
        end)

        -- ---- ST/AoE split row (mockup redesign, 2026-08-24, revised same day per in-game
        -- feedback) -- ONE continuous two-color bar spanning the full panel width, ST (blue) up to
        -- the share boundary, AoE (orange) from there to the end -- one bar, two colors, no gap
        -- and no two separate boxes. The two fill textures
        -- still tile the width exactly (V.splitBarWidths guarantees rightW = maxW - leftW, zero
        -- gap/overlap) -- what makes it read as ONE bar rather than two boxes is (a) a single
        -- shared border frame (vfSplitFrame below) drawn OVER both fills, framing the combined
        -- span as one control, and (b) a much less translucent fill. Hidden entirely by
        -- renderSplitRow (further down) when VampifyAggregate.splitTotals is absent or reports
        -- nothing measured (out.total <= 0) -- see that function and V.splitBarWidths' own header
        -- comments for the total==0/100/0/0/100 guards.
        --
        -- Glass bar (in-game correction, same pass as the compact bar's own rectangular pill --
        -- in-game report: the detail panel's bars should use the same glass treatment). Fill colors
        -- unchanged from the earlier flat-color pass (Finding 5: stBlue/aoeOrange at alpha 0.8 measured
        -- white-text contrast 3.29:1/2.74:1, under the 4.5:1 floor -- the darker *Fill variants at
        -- alpha 1 fixed that, verified 6.01:1/5.15:1) -- now layered under SHADE+SHINE the same way
        -- the pill is, re-measured per glyph row below rather than assumed still valid under the new gradient.
        tip.vfSplitBar = buildGlassBar(tip, "VampifyBarTipSplit")

        -- Border-only backdrop (no bgFile -- see W.SOLID_BACKDROP's own two-texture recipe for
        -- comparison, this omits the bg half on purpose) sized to the WHOLE split row, parented to
        -- `tip`. FrameLevel explicitly raised above `tip`'s own -- not left to whatever a child
        -- frame's default happens to be -- so its border is guaranteed to draw ON TOP of the two
        -- BACKGROUND-layer fill textures above (which live directly on `tip`, at `tip`'s own
        -- level), framing them as one bordered strip rather than two borderless patches.
        tip.vfSplitFrame = CreateFrame("Frame", "VampifyBarTipSplitFrame", tip)
        tip.vfSplitFrame:SetFrameLevel((tip:GetFrameLevel() or 0) + 1)
        tip.vfSplitFrame:SetBackdrop({
            edgeFile = W.SOLID_TEX, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        tip.vfSplitFrame:SetBackdropBorderColor(W.COLORS.line.r, W.COLORS.line.g, W.COLORS.line.b, 1)
        -- Explicitly non-mouse-capturing (stuck-panel investigation, 2026-08-24): plain
        -- Frames default to EnableMouse(false) already, so this is not believed to have been the
        -- cause -- but this frame sits ABOVE the fill textures at a raised FrameLevel and directly
        -- over `tip`'s own content, exactly the shape of frame that WOULD steal mouse focus (see
        -- V.newChain's own header comment) if it were ever mouse-enabled by a future edit. A purely
        -- decorative frame must never be able to. Explicit, not relied-upon-by-default.
        tip.vfSplitFrame:EnableMouse(false)

        -- No ST/AoE icons here any more (2026-08-24, third correction, in-game report: the ST/AoE
        -- icons are not needed -- explicitly about the icons THEMSELVES, not just their
        -- position on the bar). The split row's meaning is carried by COLOR (blue = Single-Target,
        -- orange = AoE, same convention as every other two-color bar in this file) and by the text
        -- label itself -- not by decoration. This does NOT apply to the per-ABILITY row icons
        -- (VampifyConst.spellIcon, setRow below) -- those were explicitly requested (prefix each
        -- ability name with its item/skill icon).

        -- barText (near-white) + OUTLINE font flag, not W.COLORS.ink (2026-08-24, Finding 5):
        -- this text sits directly on the solid targetRed/restBlue fill above it now, and the
        -- OUTLINE flag is the 1px dark outline that was explicitly asked to be kept IN ADDITION to
        -- the contrast fix -- W.ApplyFont's third argument is a real SetFont flag ("OUTLINE"/"THICKOUTLINE"),
        -- not decoration this file invented.
        tip.vfSplitStText = tip:CreateFontString("VampifyBarTipSplitStText", "OVERLAY")
        W.ApplyFont(tip.vfSplitStText, 10, "OUTLINE")
        tip.vfSplitStText:SetTextColor(W.COLORS.barText.r, W.COLORS.barText.g, W.COLORS.barText.b)
        tip.vfSplitStText:SetJustifyH("LEFT")
        tip.vfSplitAoeText = tip:CreateFontString("VampifyBarTipSplitAoeText", "OVERLAY")
        W.ApplyFont(tip.vfSplitAoeText, 10, "OUTLINE")
        tip.vfSplitAoeText:SetTextColor(W.COLORS.barText.r, W.COLORS.barText.g, W.COLORS.barText.b)
        tip.vfSplitAoeText:SetJustifyH("LEFT")

        -- Footer summary line ("Total: <heal> HP | <damage> DMG | <pct>%"), replacing what used to
        -- be a columnar "Total" data row (setRow's own column layout reads oddly as a sentence) --
        -- see the V.showTooltip totals block below for where it is filled in.
        tipFooter = W.MakeText(tip, 11, W.COLORS.goldHi, "OVERLAY")
        tipFooter:SetJustifyH("LEFT")

        tipNote = W.MakeText(tip, 9, W.COLORS.faint, "OVERLAY")
        tipNote:SetWidth(PANEL_W - 2 * PAD)
        tipNote:SetJustifyH("LEFT")
        return tip
    end

    -- Max pixel width of every fill bar in this panel (the split row and each ability row's own
    -- two-color fill) -- the panel width minus equal padding on both sides. A FUNCTION, not a
    -- constant, now that PANEL_W itself varies with the bar's own drag-resized width -- a one-time
    -- snapshot here would have frozen every row bar at whatever PANEL_W happened to be at addon
    -- load. Renamed from the earlier flat `BAR_MAX_W` (which shadowed the unrelated compact-bar
    -- resize-grip constant of the same name declared further up this file -- confusing, and now
    -- doubly wrong since one is a constant and this one is not) to make that no longer possible.
    local function rowBarMaxW()
        return PANEL_W - 2 * PAD
    end
    local SPLIT_ROW_H = 18

    -- Renders the ST/AoE split row at vertical position y and returns the y for whatever comes
    -- next -- unchanged (no space consumed) when there is nothing to show, so an empty breakdown
    -- does not leave a blank bar-shaped gap above the "Ability" header. scope: "session",
    -- "lifetime", or "last", matching V.tipScope's own values (VampifyAggregate.splitTotals's
    -- contract). active: false ONLY for scope=="last" against an un-upgraded core (V.showTooltip's
    -- own scopeActive, threaded through so this function never actually calls
    -- splitTotals("last", ...) against a core that has not shipped "last" support -- see
    -- V.lastScopeReady's own comment for why that specific call is unsafe to make on faith).
    -- Renders as "nothing to show" (out stays nil) -- the exact same path an empty/zero
    -- splitTotals result already takes.
    local function renderSplitRow(y, scope, active)
        local out = nil
        if active and VampifyAggregate and VampifyAggregate.splitTotals then
            out = VampifyAggregate.splitTotals(scope, splitBuf)
        end
        local barMaxW = rowBarMaxW()
        -- Text vertically CENTERED in the bar's own SPLIT_ROW_H band, not top-aligned (in-game
        -- correction: the label should also sit vertically centered in the bar, not pinned to its
        -- top edge) -- a "LEFT"-point anchor (WoW's vertical-middle
        -- anchor point) at this y offset, rather than "TOPLEFT" at the row's raw y. This also moves
        -- the glyphs out from directly under the SHINE gloss band (which peaks near the bar's own
        -- TOP), which is what the earlier per-glyph-row contrast measurement was fighting -- a
        -- re-measurement after this change confirmed the new numbers.
        local textMidY = y - SPLIT_ROW_H / 2
        if not out or not out.total or out.total <= 0 then
            layoutGlassBar(tip.vfSplitBar, tip, PAD, y, SPLIT_ROW_H, 0, nil, 0, nil)
            tip.vfSplitStText:Hide(); tip.vfSplitAoeText:Hide()
            tip.vfSplitFrame:Hide()
            return y
        end

        local stW, aoeW = V.splitBarWidths(barMaxW, out.stPct or 0, out.aoePct or 0)

        -- RED = Single-Target (healing on the player's current target), BLUE = everything else --
        -- same two colors and the same semantics as the compact bar's own pill (in-game correction:
        -- use the same red/blue color coding as the bar), read from the ONE
        -- shared W.COLORS.targetRed/restBlue source (gui/widgets.lua) rather than a second,
        -- panel-only color pair that could drift from the pill's.
        layoutGlassBar(tip.vfSplitBar, tip, PAD, y, SPLIT_ROW_H,
            stW, W.COLORS.targetRed, aoeW, W.COLORS.restBlue)

        -- One shared border spanning BOTH fills (PAD to PAD+barMaxW, always the same total span
        -- regardless of the stW/aoeW split -- V.splitBarWidths guarantees stW+aoeW==barMaxW) --
        -- what makes this read as ONE bar rather than two separate boxes (item 3, 2026-08-24).
        tip.vfSplitFrame:ClearAllPoints()
        tip.vfSplitFrame:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, y)
        tip.vfSplitFrame:SetWidth(barMaxW)
        tip.vfSplitFrame:SetHeight(SPLIT_ROW_H)
        tip.vfSplitFrame:Show()

        -- ST label: LEFT-anchored to the bar's own FIXED left edge, but the LABEL TEXT ITSELF is
        -- now chosen against the ST segment's own width (V.pickSplitLabel, Finding 5) -- full
        -- wording, the bare amount, or hidden entirely, whichever actually fits inside stW without
        -- spilling onto the AoE segment to its right. Symmetric with the AoE side below: the
        -- report was specifically about the AoE label overlapping the ST fill, but the same
        -- overlap is geometrically possible in the other direction at a very small ST share, so
        -- both sides get the same protection rather than only the one that was already caught.
        if stW > 0 then
            local avail = stW - 6
            local full = V.formatSplitLabel("Single-Target", out.stHeal, out.stPct)
            local short = V.formatAmount(out.stHeal or 0)
            local chosen = V.pickSplitLabel(full, short, avail, 2, function(t)
                tip.vfSplitStText:SetText(t)
                return tip.vfSplitStText:GetStringWidth() or 0
            end)
            if chosen then
                tip.vfSplitStText:SetText(chosen)
                tip.vfSplitStText:ClearAllPoints()
                tip.vfSplitStText:SetPoint("LEFT", tip, "TOPLEFT", PAD + 3, textMidY)
                tip.vfSplitStText:Show()
            else
                -- Segment too thin even for the bare amount -- the fill color alone still shows a
                -- Single-Target share exists; no truncated/overlapping text is drawn.
                tip.vfSplitStText:Hide()
            end
        else
            tip.vfSplitStText:Hide()
        end

        -- AoE label: RIGHT-anchored to the bar's own FIXED right edge (PAD+barMaxW, independent
        -- of aoeW -- V.rightAnchoredLabelX, item-2 fix, in-game report: "AoE Cleave" ran outside the
        -- window), but which TEXT gets drawn there is now chosen against the AoE segment's
        -- own width first (V.pickSplitLabel, Finding 5) -- fixing a SECOND, different bug the first
        -- fix did not cover: at a narrow AoE share the full label was wider than its own orange
        -- segment, so up to 42px of it sat on top of the neighbouring BLUE fill instead (measured,
        -- from the screenshot: label right-edge-anchored at x=306, orange segment starting at
        -- x=348). The label must stay inside the color it is labelling, so the anchor point itself
        -- also has to depend on the segment now (unitX computed from the CHOSEN text's own width).
        if aoeW > 0 then
            local avail = aoeW - 6
            local full = V.formatSplitLabel("AoE Cleave", out.aoeHeal, out.aoePct)
            local short = V.formatAmount(out.aoeHeal or 0)
            local chosen, chosenW = V.pickSplitLabel(full, short, avail, 2, function(t)
                tip.vfSplitAoeText:SetText(t)
                return tip.vfSplitAoeText:GetStringWidth() or 0
            end)
            if chosen then
                local rightEdge = PAD + barMaxW
                -- minX clamped to the segment's OWN left edge (PAD + stW), not the panel's -- a
                -- label that just barely fits inside aoeW must never be pulled left of where the
                -- AoE segment actually starts, which V.rightAnchoredLabelX's own minX (previously
                -- always PAD, the panel's edge) did not guarantee.
                local textX = V.rightAnchoredLabelX(rightEdge, chosenW, 3, PAD + stW)
                tip.vfSplitAoeText:SetText(chosen)
                tip.vfSplitAoeText:ClearAllPoints()
                tip.vfSplitAoeText:SetPoint("LEFT", tip, "TOPLEFT", textX, textMidY)
                tip.vfSplitAoeText:Show()
            else
                tip.vfSplitAoeText:Hide()
            end
        else
            tip.vfSplitAoeText:Hide()
        end

        return y - SPLIT_ROW_H - 4
    end

    -- barShare: this row's percent share of the breakdown total (0..100), or nil/false for a row
    -- that gets no fill bar (the header row, and the diagnostic "check" row). The bar is r.bar, a
    -- pooled glass bar (buildGlassBar/layoutGlassBar above) with up to two colored FILL segments
    -- (blue Single-Target, orange AoE) tiling the row's own width side by side, plus a shared
    -- SHADE/SHINE pair over the whole thing -- see V.splitBarWidths' own header comment for the
    -- underlying geometry -- a row is colored
    -- PROPORTIONALLY rather than as one or the other: the same ability can classify some hits
    -- Single-Target and others AoE, hit by hit. The bar occupies BORDER/ARTWORK/OVERLAY (see
    -- buildGlassBar's header); the row's FontString cells share OVERLAY with its shine and still
    -- draw above it, since FontStrings always outrank textures of the same layer.
    --
    -- rowMeta: nil for rows with no icon/split (the header and the diagnostic "check" row -- same
    -- rows that pass barShare nil/false), otherwise { icon = <texture path or nil>, hasSplit,
    -- stPct, aoePct }. icon absent falls back to "no icon, name starts at the column's own left
    -- edge" (the fallback contract defined above); hasSplit false paints
    -- the WHOLE bar in a neutral color instead of blue/orange, rather than mislabel an
    -- unclassified row as 100% Single-Target.
    -- Variant B2 row (Finding 3, 2026-08-24 pixel measurement pass): the row IS the bar --
    -- icon+name drawn INSIDE its left edge, one right-anchored vamp-heal value at the row's own
    -- fixed right edge, no column table (COLS is gone, see this section's own header comment).
    -- barShare is now expected to be a SHARE-OF-MAX percent (V.shareOfMax, not V.shareOfTotal --
    -- see that function's own header for why bar LENGTH changed basis, Finding 1); the underlying
    -- percent-of-total figure this addon actually reports elsewhere is untouched by this rename.
    -- `value` is a pre-formatted string (or nil/"" to omit) -- callers pass V.formatAmount(...)
    -- themselves, this function does no formatting of its own, same convention as before.
    -- rowMeta.isOther (set by V.buildTopRows) selects the neutral otherGrey fill instead of a
    -- fabricated ST/AoE split for the collapsed "Other (N)" row (Finding 4).
    local function setRow(idx, y, name, value, barShare, rowMeta, textColorKey)
        local r = tipRows[idx]
        if not r then
            r = {}
            -- THICKOUTLINE + shadow, not plain OUTLINE: measured via a
            -- worst-over-every-glyph-offset sweep (in-game correction: measure the contrast
            -- row-by-row, and use THICKOUTLINE plus a shadow if needed) -- plain OUTLINE
            -- on the targetRed glass bar at ROW_H-2=16px measured 4.41:1, just under the 4.5:1
            -- floor, right where the shine band's peak collides with the name text's own top
            -- glyph rows (same failure mode as the pill's own text, see buildPill's comment). Kept
            -- ON TOP of the vertical-centering fix below (in-game feedback: keep the thick outline
            -- anyway, it does not hurt) rather than removed now that centering alone may clear
            -- the floor -- a re-measurement confirmed the combined numbers.
            r.nameFS = tip:CreateFontString("VampifyBarTipR" .. idx .. "Name", "OVERLAY")
            W.ApplyFont(r.nameFS, 10, "THICKOUTLINE")
            W.ApplyShadow(r.nameFS, true)
            r.nameFS:SetJustifyH("LEFT")
            r.valueFS = tip:CreateFontString("VampifyBarTipR" .. idx .. "Value", "OVERLAY")
            W.ApplyFont(r.valueFS, 10, "THICKOUTLINE")
            W.ApplyShadow(r.valueFS, true)
            r.valueFS:SetJustifyH("RIGHT")
            -- Parented to tipIcons (one frame level above `tip`), NOT to `tip` -- the bar it sits
            -- on now owns every layer from BORDER up. Still ANCHORED to `tip` below, which is
            -- legal and keeps every row's geometry expressed against the panel it belongs to.
            r.icon = tipIcons:CreateTexture("VampifyBarTipR" .. idx .. "Icon", "ARTWORK")
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            -- BORDER, the same layer the bar's own fill segments use -- safe because it is laid
            -- out BESIDE them (the empty remainder of the track) rather than beneath them, so the
            -- two never overlap and their mutual order is never asked. On BACKGROUND it shared a
            -- layer with buildTipFill's panel background and could vanish underneath it.
            r.barBg = tip:CreateTexture("VampifyBarTipR" .. idx .. "BarBg", "BORDER")
            -- Glass bar (in-game report: the detail panel's bars should use the same glass
            -- treatment) -- replaces the old flat r.barSt/r.barAoe pair. r.barBg (above, UNCHANGED)
            -- stays a plain flat translucent backdrop -- it represents the row's EMPTY track, not
            -- a value, the same reasoning a normal health bar's empty portion stays flat.
            r.bar = buildGlassBar(tip, "VampifyBarTipR" .. idx .. "Bar")
            tipRows[idx] = r
        end

        local barMaxW = rowBarMaxW()
        -- Text vertically CENTERED in the bar's own (ROW_H - 2)-tall band, not top-aligned -- same
        -- fix and same reasoning as renderSplitRow's own textMidY above (in-game correction: the
        -- label should also sit vertically centered in the bar).
        local textMidY = y - (ROW_H - 2) / 2

        local hasIcon = rowMeta and rowMeta.icon
        local nameX = PAD
        if hasIcon then
            r.icon:SetTexture(rowMeta.icon)
            r.icon:ClearAllPoints()
            r.icon:SetWidth(ROW_H - 3)
            r.icon:SetHeight(ROW_H - 3)
            r.icon:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, y)
            r.icon:Show()
            nameX = PAD + ROW_H
        else
            -- No icon (the fallback contract): text starts at the row's own left edge instead of
            -- leaving a blank icon-shaped hole -- the text shifts left rather than leaving a
            -- placeholder gap.
            r.icon:Hide()
        end

        r.nameFS:ClearAllPoints()
        r.nameFS:SetPoint("LEFT", tip, "TOPLEFT", nameX, textMidY)
        -- Capped so a long name can never run underneath the right-anchored value -- see
        -- ROW_VALUE_RESERVE's own comment. PANEL_W itself is live (computePanelW(), reassigned at
        -- the top of V.showTooltip every repaint) -- this line already reads it fresh every call,
        -- no separate wiring needed for the name column to follow a resized panel.
        r.nameFS:SetWidth(PANEL_W - nameX - ROW_VALUE_RESERVE)
        r.nameFS:SetText(name)
        local textColor = (textColorKey and W.COLORS[textColorKey]) or W.COLORS.barText
        r.nameFS:SetTextColor(textColor.r, textColor.g, textColor.b)
        r.nameFS:Show()

        if value and value ~= "" then
            r.valueFS:SetText(value)
            r.valueFS:ClearAllPoints()
            local valW = r.valueFS:GetStringWidth() or 0
            r.valueFS:SetPoint("LEFT", tip, "TOPLEFT",
                V.rightAnchoredLabelX(PAD + barMaxW, valW, 4, nameX), textMidY)
            r.valueFS:SetTextColor(textColor.r, textColor.g, textColor.b)
            r.valueFS:Show()
        else
            r.valueFS:Hide()
        end

        -- The row's EMPTY track -- drawn as the REMAINDER beside the fill, not as a full-width
        -- slab beneath it. Same look (the fill covers it at alpha 0.95 either way), but it now
        -- shares BORDER with the fill segments without ever overlapping them, which is what lets
        -- the whole row live on deterministic layers -- see r.barBg's own creation comment.
        local filledW = 0
        if barShare and barShare > 0 then filledW = barMaxW * (barShare / 100) end
        if filledW > barMaxW then filledW = barMaxW end
        r.barBg:ClearAllPoints()
        if filledW < barMaxW then
            r.barBg:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD + filledW, y)
            r.barBg:SetHeight(ROW_H - 2)
            r.barBg:SetWidth(barMaxW - filledW)
            r.barBg:SetTexture(W.COLORS.panel2.r, W.COLORS.panel2.g, W.COLORS.panel2.b)
            r.barBg:SetAlpha(0.5)
            r.barBg:Show()
        else
            -- A row at 100% has no empty remainder to draw.
            r.barBg:Hide()
        end

        if barShare and barShare > 0 then
            local totalW = filledW
            if rowMeta and rowMeta.isOther then
                -- Finding 4: the collapsed "Other (N)" row mixes many unrelated abilities' ST/AoE
                -- hits -- a real split would be computable (rowSplit sums per-id the same way for
                -- ANY ids list) but is deliberately NOT drawn: visually more subdued, since it
                -- mixes ST and AoE -- one flat neutral fill (now under the same glass SHADE/
                -- SHINE as every other bar in the panel), on purpose, not a fallback.
                layoutGlassBar(r.bar, tip, PAD, y, ROW_H - 2, totalW, W.COLORS.otherGrey, 0, nil, 0.95)
            else
                local stPct, aoePct, hasSplit = 100, 0, false
                if rowMeta then
                    hasSplit = rowMeta.hasSplit and true or false
                    if hasSplit then
                        stPct = rowMeta.stPct or 0
                        aoePct = rowMeta.aoePct or 0
                    end
                end
                if hasSplit then
                    local stW, aoeW = V.splitBarWidths(totalW, stPct, aoePct)
                    -- RED/BLUE, same shared W.COLORS.targetRed/restBlue as the pill and the split
                    -- row above -- see renderSplitRow's own comment for the unification rationale.
                    layoutGlassBar(r.bar, tip, PAD, y, ROW_H - 2,
                        stW, W.COLORS.targetRed, aoeW, W.COLORS.restBlue, 0.95)
                else
                    -- No per-hit classification for this row (yet, or the aggregate function is
                    -- not wired up) -- ONE neutral-colored bar, never a fabricated all-blue "100%
                    -- ST". goldSoft, not otherGrey -- a DIFFERENT neutral, so "no data yet" (this
                    -- case) never reads the same as "deliberately mixed" (the Other row above).
                    layoutGlassBar(r.bar, tip, PAD, y, ROW_H - 2, totalW, W.COLORS.goldSoft, 0, nil, 0.95)
                end
            end
        else
            layoutGlassBar(r.bar, tip, PAD, y, ROW_H - 2, 0, nil, 0, nil)
        end
    end

    -- One invisible full-width mouse frame per DATA row (real ability rows only -- never the
    -- header/Total/check rows, since only the data-row loop in V.showTooltip below calls this).
    -- `i` here is the data-row index (1..n into `merged`), stable across repaints -- pool slot i
    -- always represents data row i, only the CONTENT that row's index maps to changes between
    -- repaints (tracked via rowEntryMap/repaintVersion, see their comment above).
    local function rowHoverFrame(i)
        local h = tipRowHovers[i]
        if h then return h end
        h = CreateFrame("Frame", "VampifyBarTipRowHover" .. i, tip)
        h:SetHeight(ROW_H)
        -- Explicit, absolute level -- above tipIcons (21), which is above the panel (20). Two
        -- sibling frames left on the SAME level have undefined draw order just like two textures
        -- on the same layer do, and a hover cue that must read as "over this
        -- row" is exactly the kind of thing that must not be left to chance.
        h:SetFrameLevel(22)
        h.vfRowIndex = i
        -- Subtle: a near-invisible highlight, not a real selection color -- this is a hover cue
        -- for a data table, not a button.
        local hl = h:CreateTexture("VampifyBarTipRowHoverHL" .. i, "BACKGROUND")
        hl:SetTexture(1, 1, 1)
        hl:SetAlpha(0.06)
        hl:SetAllPoints(h)
        hl:Hide()
        h.vfHighlight = hl
        -- V.chainEnter(Chain) stops the shared hover-chain countdown -- a row is the entry point INTO
        -- the row-detail panel (level 3), so hovering one must cancel any close pending from a
        -- shallower level too (by design: entering anywhere in the chain stops it). The detail
        -- panel's own content still shows/refreshes immediately on every row hover, same as before
        -- -- only the CLOSE got a grace period (see OnLeave below), not the show.
        h:SetScript("OnEnter", function()
            this.vfHighlight:Show()
            hoveredRowIndex = this.vfRowIndex
            V.chainEnter(Chain)
            V.showRowDetail(this.vfRowIndex)
        end)
        -- Used to call V.hideRowDetail() immediately here (2026-08-24 mockup pass: called
        -- hideRowDetail immediately, with no grace period) -- that made the detail panel unreachable, since
        -- moving the mouse off a row and towards the (separate, adjacent) detail panel always
        -- crosses this OnLeave first. V.chainLeave(Chain, 3) instead gives it HOVER_GRACE seconds to reach
        -- the detail panel (or another row) before Chain.tick actually closes it -- see the Chain
        -- block on V.build above.
        h:SetScript("OnLeave", function()
            this.vfHighlight:Hide()
            -- Guarded rather than an unconditional nil: an OnLeave firing for a DIFFERENT pool
            -- slot than the one currently recorded as hovered (possible once frames get reused
            -- across repaints) must not clobber a hover that is genuinely still active elsewhere.
            if hoveredRowIndex == this.vfRowIndex then hoveredRowIndex = nil end
            V.chainLeave(Chain, 3)
        end)
        tipRowHovers[i] = h
        return h
    end

    -- One merged row's aggregate ST/AoE split, accumulated across every id folded into it -- a
    -- merged row can carry more than one rank (see V.mergeByName), and each id's own hits were
    -- classified independently, so the row's true split is the SUM of its ids' splits, not just
    -- the first id's. Calls VampifyAggregate.spellSplit once per id, via the same
    -- (spellId, scope, out) -> out.stHeal/.aoeHeal/.hasSplit interface contract used throughout
    -- this file. Reuses ONE pooled `out` table across the whole loop (RowSplitState.buf below) -- safe
    -- because each call's fields are read into locals before the next call overwrites it.
    --
    -- Returns hasSplit=false as soon as EITHER the function is absent (not wired up yet) OR any id
    -- in the row reports hasSplit=false -- a row is only trustworthy as blue/orange-coded when
    -- EVERY one of its ids actually classified its hits, not when some did and some silently
    -- defaulted to zero (the fallback contract described above).
    --
    -- aoeHits (2026-08-25, Earth Shock AoE-damping bug fix): summed across every id regardless of
    -- `ok` -- this is the row's own count of hits VampifyAggregate.spellSplit positively classified
    -- as off-target in this scope, the PROOF V.formatRateLine's "(AoE damping)" wording now
    -- requires before it prints that specific claim (see that function's own comment). Kept
    -- independent of the hasSplit/ok gate above on purpose: hasSplit governs whether the ROW'S BAR
    -- COLOR is trustworthy (needs every id classified), but "was any AoE hit ever recorded for this
    -- row" is a weaker, still-honest question that a partially-classified row can still answer
    -- truthfully from whatever part of it IS classified.
    --
    -- scope=="last" is gated behind V.lastScopeReady() here, the one place every "last"-scope
    -- VampifyAggregate.spellSplit call in this file funnels through -- see that function's own
    -- comment for why trusting an un-upgraded core's "last" branch is unsafe.
    local RowSplitState = { buf = {} }
    local function rowSplit(entry, scope)
        if not (VampifyAggregate and VampifyAggregate.spellSplit) then
            return { hasSplit = false, aoeHits = 0 }
        end
        if scope == "last" and not V.lastScopeReady() then
            return { hasSplit = false, aoeHits = 0 }
        end
        local ids = entry.ids or {}
        local n = table.getn(ids)
        if n == 0 then return { hasSplit = false, aoeHits = 0 } end
        local stHeal, aoeHeal, aoeHits, ok = 0, 0, 0, true
        local i
        for i = 1, n do
            local out = VampifyAggregate.spellSplit(ids[i].spell, scope, RowSplitState.buf)
            if not out or not out.hasSplit then
                ok = false
            else
                stHeal = stHeal + (out.stHeal or 0)
                aoeHeal = aoeHeal + (out.aoeHeal or 0)
            end
            if out then aoeHits = aoeHits + (out.aoeHits or 0) end
        end
        if not ok then return { hasSplit = false, aoeHits = aoeHits } end
        local total = stHeal + aoeHeal
        local stPct = 0
        if total > 0 then stPct = stHeal / total * 100 end
        return { hasSplit = true, stPct = stPct, aoePct = 100 - stPct, aoeHits = aoeHits }
    end

    -- Pooled per-row { icon, hasSplit, stPct, aoePct } tables, passed to setRow as rowMeta -- same
    -- pooling convention as tipRows/tipRowHovers above, refilled every repaint rather than
    -- rebuilt.
    local rowMetaBuf = {}
    local function getRowMeta(idx)
        local m = rowMetaBuf[idx]
        if not m then m = {}; rowMetaBuf[idx] = m end
        return m
    end

    function V.showTooltip()
        buildTip()
        -- PANEL_W re-derived from the bar's own CURRENT width every repaint (in-game correction:
        -- when the bar is dragged bigger/smaller, the detail window should get more/less space
        -- too) -- buildTip() only sets tip's width once at first construction, so this
        -- explicit re-application is what actually keeps the frame in sync on every later repaint
        -- (a drag-resize while the panel is closed, or several repaints since the panel was built).
        PANEL_W = computePanelW()
        tip:SetWidth(PANEL_W)
        tipNote:SetWidth(PANEL_W - 2 * PAD)
        -- Every repaint invalidates the previously shown row detail -- the DATA a row index maps
        -- to may have changed (new hits landed, scope toggled) -- and V.showRowDetail's own
        -- change-guard compares against repaintVersion (bumped below) to tell "still the same
        -- repaint" from "something moved underneath". That normally means hovering the row again
        -- is what brings the detail panel back -- but while PINNED, V.update's periodic repaint
        -- (see below) happens with the mouse sitting still over the SAME row the whole time, so no
        -- fresh OnEnter is ever coming. Snapshotting the currently-hovered row's NAME here, before
        -- rowEntryMap is overwritten below, lets the end of this function tell "the row I was
        -- looking at is still there, just updated -- refresh it in place" from "the row set
        -- reshuffled under it -- nothing sane to refresh against, hide instead" (adversarial
        -- review, 2026-08-23: an unconditional hide here made a periodic pinned repaint flicker
        -- the detail panel shut every second even with the mouse never moving).
        local hoverIdx = hoveredRowIndex
        local hoverName = hoverIdx and rowEntryMap[hoverIdx] and rowEntryMap[hoverIdx].name
        repaintVersion = repaintVersion + 1
        local C = W.COLORS
        local scope = V.normalizeScope(V.tipScope)
        -- lastReady/scopeActive: see V.lastScopeReady's own header comment. scopeActive is false
        -- ONLY for scope=="last" against an un-upgraded core -- every other scope is always active.
        local lastReady = V.lastScopeReady()
        local scopeActive = (scope ~= "last") or lastReady

        -- tipHead: static "Vampify", except a live-fight indicator while actually looking at the
        -- running fight (core-side design, 2026-08-25: "last" fills LIVE while
        -- VampifyState.fActive is true and freezes the instant the fight ends -- the numbers can
        -- change while the player is looking at them, which must be visible, and ONLY while that is
        -- actually still true). The scope BUTTON's own label stays the static "LAST" at all times
        -- (see that button's own comment for why relabeling the nav control itself was rejected).
        if scope == "last" and VampifyState and VampifyState.fActive then
            tipHead:SetText("Vampify -- fight in progress")
        else
            tipHead:SetText("Vampify")
        end

        -- Highlights exactly the active tab -- three-way now, was a plain if/else before "last".
        local function scopeHighlight(btn, active)
            local col = active and C.goldHi or C.dim
            btn.vfText:SetTextColor(col.r, col.g, col.b)
        end
        scopeHighlight(tip.vfScopeSessionBtn, scope == "session")
        scopeHighlight(tip.vfScopeLifetimeBtn, scope == "lifetime")
        scopeHighlight(tip.vfScopeLastBtn, scope == "last")

        -- Reset button: label always names the active scope; disabled (mandatory fallback, greyed
        -- out rather than hidden -- see this button's own build-time comment) when the reset path
        -- itself is unavailable -- VampifyResetSession entirely absent, or (last scope only) the
        -- core-side last-scope reset has not shipped yet.
        local resetDisabled = (not VampifyResetSession) or (scope == "last" and not lastReady)
        tip.vfResetBtn.vfDisabled = resetDisabled
        tip.vfResetBtn.vfText:SetText("Reset " .. scope)
        if resetDisabled then
            tip.vfResetBtn.vfText:SetTextColor(C.dim.r * 0.5, C.dim.g * 0.5, C.dim.b * 0.5)
        elseif scope == "lifetime" then
            -- Warm/red tint on the ONE destructive option, matching this file's existing convention
            -- for a caution color (W.COLORS.warn's own hue) -- a visual hint that this one button
            -- behaves differently before the player even clicks it.
            tip.vfResetBtn.vfText:SetTextColor(1, 0.55, 0.5)
        else
            tip.vfResetBtn.vfText:SetTextColor(C.dim.r, C.dim.g, C.dim.b)
        end

        -- merged/n: EMPTY (not an error, not another scope's data) when scope=="last" but the
        -- core-side support has not shipped -- see V.lastScopeReady's own comment for why an
        -- un-upgraded core must not be trusted with a truthy/unrecognised third argument here.
        -- tipBuf is a POOLED buffer already carrying a real `n` from its last successful fill (every
        -- A.spellBreakdown call ends with table.setn(out, n)) -- table.setn(tipBuf, 0) is the same
        -- "reuse, don't reallocate" convention this file already uses everywhere else, and
        -- V.mergeByName only ever reads indices 1..table.getn(rows), so the stale entries past that
        -- point are simply never looked at.
        local merged
        if scopeActive then
            merged = V.mergeByName(VampifyAggregate.spellBreakdown(VampifyState, tipBuf, scope), mergeBuf)
        else
            table.setn(tipBuf, 0)
            merged = V.mergeByName(tipBuf, mergeBuf)
        end
        local n = table.getn(merged)
        -- y start dropped 30 -> 40 to leave room for the new per-scope reset button row (built in
        -- buildTip at y=-24, height 11) between the scope toggle and the split row.
        local y = -40

        y = renderSplitRow(y, scope, scopeActive)

        -- No "Ability | Damage | Vamp | OH" column-header row any more -- Variant B2 has no
        -- columns to label (Finding 3); the panel goes straight from the split row into the ability
        -- bars themselves.
        local used = 0

        -- Totals are still computed from the FULL merged set (every tracked ability, not just the
        -- ones actually drawn) -- the footer must equal the TRUE total regardless of how many rows
        -- V.TOP_ROWS collapses into "Other" below; only the DRAWN rows are capped, never the sum.
        local tDmg, tHeal, tOh = 0, 0, 0
        for i = 1, n do
            tDmg  = tDmg + merged[i].damage
            tHeal = tHeal + merged[i].heal
            tOh   = tOh + merged[i].overheal
        end

        -- Finding 4: cap the drawn rows at V.TOP_ROWS real abilities + one collapsed "Other (N)"
        -- row for the rest (see V.buildTopRows' own header comment for why this is safe to hover
        -- for detail too). Finding 1: bar LENGTH is now the shown set's own share-of-MAX (the
        -- biggest bar always reaches the full row width), computed over exactly the rows drawn --
        -- see V.shareOfMax's own header comment for why that self-reference is correct even when
        -- the Other row's summed heal happens to exceed every individual top-8 ability's own.
        local topRows = V.buildTopRows(merged, V.TOP_ROWS, topRowsBuf)
        local shownN = table.getn(topRows)
        local shareMax = V.shareOfMax(topRows, shareMaxBuf)

        for i = 1, shownN do
            local r = topRows[i]
            local barShare = shareMax[i] or 0
            used = used + 1
            local meta = getRowMeta(used)
            if r.isOther then
                meta.icon = nil
                meta.isOther = true
                meta.hasSplit = false
            else
                meta.icon = VampifyConst.spellIcon and r.ids[1] and VampifyConst.spellIcon(r.ids[1].spell)
                meta.isOther = false
                local sp = rowSplit(r, scope)
                meta.hasSplit = sp.hasSplit
                meta.stPct = sp.stPct
                meta.aoePct = sp.aoePct
            end
            setRow(used, y, r.name, V.formatAmount(r.heal), barShare, meta, "barText")
            -- rowEntryMap[i] IS topRows[i] (topRowsBuf's own pooled entry -- a real merged row for
            -- 1..V.TOP_ROWS, or the pooled Other-row accumulator past that point) -- see the
            -- field's declaration above for why V.showRowDetail must never re-merge from this.
            rowEntryMap[i] = r
            local h = rowHoverFrame(i)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", tip, "TOPLEFT", 0, y)
            h:SetWidth(PANEL_W)
            -- Fix (2026-08-25, found alongside the barBg/glass-bar layer bug above): rowHoverFrame's
            -- OWN pooling block only ever sets this frame's HEIGHT once, at first creation
            -- (h:SetHeight(ROW_H) inside its "if not h then" guard) -- every OTHER per-call geometry
            -- (position, width) is already refreshed here on every repaint, but height was not, so a
            -- live panelBarHeight change left every ALREADY-POOLED row's hover rect frozen at
            -- whatever ROW_H happened to be the first time that row index was ever drawn. Refreshed
            -- HERE, alongside width/position, for the same reason those are: PANEL_W/ROW_H are both
            -- live values this function already re-reads every repaint.
            h:SetHeight(ROW_H)
            h:EnableMouse(true)
            h:Show()
            y = y - ROW_H - ROW_GAP
        end
        -- Hide/disable hover frames left over from a previous, longer breakdown.
        for i = shownN + 1, table.getn(tipRowHovers) do
            tipRowHovers[i]:Hide()
            tipRowHovers[i]:EnableMouse(false)
            rowEntryMap[i] = nil
        end

        -- The total's share is 100 by definition -- but only claim it when there is something to
        -- share out, so an empty breakdown does not print a full hundred percent. The figures
        -- themselves are the SUM OF THE ROWS (computed above, before the rows were drawn). A footer
        -- that does not equal its own rows is the classic way for a display to lie quietly.
        -- A single-line footer ("Total: <heal> HP | <damage> DMG | <pct>%"), not a columnar setRow
        -- row -- 2026-08-24 badge pass. tOh is folded into the panel's own note text
        -- rather than repeated here; every row above already shows its own OH column.
        -- LAST scope's footer uses VampifyAggregate.fight(VampifyState) instead of the summed rows
        -- (core-side design, 2026-08-25: the header figures are already served by the existing
        -- fight() function, no new plumbing needed) -- fHeal/fDmg already track exactly the CURRENT-OR-
        -- LAST fight's grand totals with the same live/freeze lifecycle "last" itself has, so this
        -- is the SAME figure the per-spell rows sum to, just read from the existing scalar rather
        -- than re-derived. Also shows HPS here (session/lifetime do not -- the compact bar's own
        -- line already carries a session HPS figure, so repeating it there would say the same thing
        -- twice; "last" has no such existing HPS readout anywhere else, and it is the one figure
        -- that answers "how did THIS fight go" at a glance).
        if scope == "last" then
            local fight = (scopeActive and VampifyAggregate.fight and VampifyAggregate.fight(VampifyState)) or nil
            local fHeal, fDmg, fHps = 0, 0, 0
            if fight then fHeal, fDmg, fHps = fight.heal or 0, fight.damage or 0, fight.hps or 0 end
            y = y - 4
            tipFooter:SetText(string.format("Total: %s HP | %s DMG | %.1f HPS",
                V.formatAmount(fHeal), V.formatAmount(fDmg), fHps))
        else
            local tPct = 0
            if tHeal > 0 then tPct = 100 end
            y = y - 4
            tipFooter:SetText(string.format("Total: %s HP | %s DMG | %.1f%%",
                V.formatAmount(tHeal), V.formatAmount(tDmg), tPct))
        end
        -- Width-capped to the (now variable) panel width so this line WORD-WRAPS at a narrow
        -- drag-width instead of overflowing past the panel's own right edge (item 1, in-game
        -- report: the Total line must resize along with it too) -- same treatment tipNote already had. Real
        -- GetHeight() drives the y-advance below (was a fixed ROW_H, assuming always one line) so
        -- a wrapped two-line total still leaves the right amount of clearance before whatever
        -- comes next, the same measured-not-assumed spacing tipNote's own advance already uses.
        tipFooter:SetWidth(PANEL_W - 2 * PAD)
        tipFooter:ClearAllPoints()
        tipFooter:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, y)
        y = y - tipFooter:GetHeight() - 6

        -- ...and the independently kept session total is used as a CHECK on it -- but ONLY for the
        -- session scope. That separately-kept total (VampifyAggregate.session) is a running number
        -- fed by A.record on every hit; there is no lifetime OR last equivalent (the design asks to
        -- persist the three per-spell tables, not a fourth running total per scope),
        -- so outside session the per-spell rows ARE the only record and there is nothing
        -- independent to check them against. Comparing another scope's rows to the session total
        -- would compare two different scopes and read as a false alarm every time they differ,
        -- which they usually do.
        if scope == "session" then
            -- The two are fed from different calls (record vs recordSpell), so a divergence beyond
            -- rounding slack means one path is dropping or double-counting events. Saying so beats
            -- showing a number that quietly disagrees with itself.
            local session = VampifyAggregate.session(VampifyState)
            local dDmg  = math.abs((session.damage or 0) - tDmg)
            local dHeal = math.abs((session.heal or 0) - tHeal)
            if dDmg > 1 or dHeal > 1 then
                used = used + 1
                -- Diagnostic row: no columns to put the two numbers in any more (Finding 3), so
                -- both are folded into the name text itself -- no bar (barShare nil), no rowMeta
                -- (no icon, no ST/AoE fill).
                setRow(used, y, "check: session totals differ (dmg " ..
                       V.formatAmount(session.damage or 0) .. ", heal " ..
                       V.formatAmount(session.heal or 0) .. ")", nil, nil, nil, "bad")
                y = y - ROW_H - 2
            end
        end

        -- Hide any rows left over from a previous, longer breakdown (icon + both bar halves too).
        for i = used + 1, table.getn(tipRows) do
            local rr = tipRows[i]
            rr.nameFS:Hide()
            rr.valueFS:Hide()
            if rr.icon then rr.icon:Hide() end
            if rr.barBg then rr.barBg:Hide() end
            if rr.bar then layoutGlassBar(rr.bar, tip, PAD, 0, ROW_H - 2, 0, nil, 0, nil) end
        end

        -- Right-click hint (no visible button, see the OnMouseUp comment above -- this text is its
        -- only affordance) and a hover hint for the row-detail/detail-of-detail chain (2026-08-24:
        -- replaces the old click-to-pin hint now that hovering, not pinning, keeps this panel open
        -- -- see the Chain block on V.build above). Names the ACTUAL next scope (V.nextScope, the
        -- same rotation the click itself uses) rather than a fixed two-way phrasing -- with three
        -- scopes now, "for session totals"/"for lifetime totals" stopped being an exhaustive pair.
        local switchHint = " Right-click the bar for " .. V.nextScope(scope) .. " totals."
        local hoverHint = " Hover a row for details, and the detail panel for more."
        local noteText
        if n == 0 then
            if scope == "last" then
                -- Mandatory-fallback wording (this file's own coordination contract with core/) --
                -- also the ordinary state right after every /reload ("last" is
                -- deliberately volatile, never persisted, by design) and before a session's first hit, neither
                -- of which is an error -- must not read as one.
                noteText = "No fight recorded yet. This fills in once your current fight lands its"
                    .. " first hit, and clears again the moment your next fight starts." .. switchHint
            else
                noteText = "No damage recorded yet. Percentages above the source total are the"
                    .. " per-hit floor: with " .. tostring(table.getn(VampifyDetect.getSources()))
                    .. " sources every hit returns at least that many HP." .. switchHint
            end
        elseif scope == "lifetime" then
            -- Required disclaimer: the lifetime set spans every gear state
            -- this character has ever fought in, by construction -- it is a volume figure, not a
            -- rate, and must not be read against the CURRENT gear's source percentage.
            noteText = "Lifetime totals mix every gear state Vampirism has ever been worn"
                .. " in on this character. This is a running VOLUME, not a rate -- do not compare"
                .. " it against the current gear's source percentage." .. switchHint
        elseif scope == "last" then
            noteText = "Shows the current or most recently completed fight -- live while it is"
                .. " still running, frozen once it ends, and cleared again at the start of the"
                .. " next one. Never saved across a /reload." .. switchHint
        else
            -- Bug fix (in-game report 2026-08-25, Earth Shock #10414 -- see V.classifyRate's
            -- own comment): no longer asserts AoE damping as the ONE reason a value sits below the
            -- gear total -- that claim now only appears per-row, and only when the row's own detail
            -- panel actually has evidence for it (V.formatRateLine).
            noteText = "A value above the gear total is the per-hit floor (small hits still"
                .. " return one HP per source); a value below it can mean AoE damping, a lower"
                .. " spell rank, or an unexplained gap -- see each row's own detail panel." .. switchHint
        end
        tipNote:SetText(noteText .. hoverHint)
        tipNote:ClearAllPoints()
        tipNote:SetPoint("TOPLEFT", tip, "TOPLEFT", PAD, y)
        -- Measured after the point is set, and with a full PAD of clearance, so the last line
        -- cannot sit under the bottom border.
        y = y - tipNote:GetHeight() - PAD

        tip:SetHeight(-y)
        layoutTipFill(tip, PANEL_W, -y)
        tip:ClearAllPoints()
        tip:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
        tip:Show()

        -- Refresh (or release) the row-detail panel for whatever was actively hovered BEFORE this
        -- repaint (hoverIdx/hoverName, captured at the top -- see that comment for the flicker this
        -- avoids). rowEntryMap now holds the NEW data (rebuilt by the row loop above). A name match
        -- at the same pool slot means "same ability, just updated numbers" -- V.showRowDetail
        -- rebuilds the panel's content once, since repaintVersion moved past what it last rendered.
        -- Anything else (the row is gone, or that slot now holds a DIFFERENT ability -- the set
        -- reshuffled, or the scope was switched) has nothing sane to refresh against, so hide
        -- rather than show a detail panel for the wrong row.
        if hoverIdx and rowEntryMap[hoverIdx] and rowEntryMap[hoverIdx].name == hoverName then
            V.showRowDetail(hoverIdx)
        elseif detail then
            detail:Hide()
        end
    end

    -- Hides the row-detail panel alongside the main one: it is meaningless without it, and
    -- V.showRowDetail's own change-guard (repaintVersion) does not by itself hide a stale one --
    -- see its comment for why that guard is a "don't rebuild", not a "don't show", check.
    -- Unconditional now (2026-08-24 hover-chain redesign removed the pin guard this used to have --
    -- see the Chain block on V.build above; graceful, delayed closing is Chain.tick's job, this is
    -- the immediate/forced kind, called from V.hide() below and from the Chain's own level-2
    -- hideFn).
    function V.hideTooltip()
        if tip then tip:Hide() end
        V.hideRowDetail()
    end

    -- ---- row-detail panel: WoW-wiring shell -----------------------------------------------------
    --
    -- Thin adapters over the pure functions above (V.resolveOrigin, V.buildDetailLines, etc.):
    -- this half supplies the WoW-API-bound inputs those need (the item-origin lookup, the player's
    -- spellbook name set, VampifyState's live source percents, the other scope's matching row) and
    -- renders the resulting line array into pooled FontStrings. No logic lives here that the pure
    -- functions could have done instead -- see this section's header comment on those for why.

    -- Spellbook name cache: built lazily on first need (never at load, and NEVER re-scanned every
    -- OnEnter -- a spellbook scan is a real loop over GetSpellName, and a hovered row can re-enter
    -- many times a second while the mouse sits still). Invalidated by SPELLS_CHANGED (new rank
    -- learned, etc.) via the small named watcher frame below, not polled.
    local spellbookSet, spellbookDirty = nil, true

    local function buildSpellbookSet()
        local set, i = {}, 1
        while true do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if not name then break end
            set[name] = true
            i = i + 1
        end
        return set
    end

    local function getSpellbookSet()
        if spellbookDirty or not spellbookSet then
            spellbookSet = buildSpellbookSet()
            spellbookDirty = false
        end
        return spellbookSet
    end

    local spellbookWatcher = CreateFrame("Frame", "VampifyBarSpellbookWatcher", UIParent)
    spellbookWatcher:RegisterEvent("SPELLS_CHANGED")
    spellbookWatcher:SetScript("OnEvent", function() spellbookDirty = true end)

    -- Sums VampifyState.sourcePercents the same way V.update already does for the bar's own line
    -- (via V.formatSources) -- same source of truth, not a second read path that could disagree
    -- with it. 0 for an empty/missing list, which V.formatRateLine reads as "omit the rate line".
    local function sumSourcePercents()
        local s = VampifyState and VampifyState.sourcePercents
        if not s then return 0 end
        local sum, i = 0, nil
        for i = 1, table.getn(s) do sum = sum + (s[i] or 0) end
        return sum
    end

    -- Which scope's twin figure to show alongside the one currently viewed -- with only two scopes
    -- this used to just be "the other one"; with three, "other" is no longer unambiguous, so this
    -- names a fixed choice instead of guessing. SESSION is the comparison point whenever it is not
    -- itself the active scope (viewing "last", session is the closest, most relevant baseline --
    -- "how does this fight compare to my average this session"; viewing "lifetime", session is
    -- likewise the more immediately useful of the two alternatives) -- LIFETIME is shown only while
    -- actively viewing session, matching this line's original pre-"last" behaviour exactly.
    local function otherScopeFor(scope)
        if scope == "session" then return "lifetime" end
        return "session"
    end

    -- The row's twin figure from the OTHER scope (otherScopeFor above). OWN pooled buffers
    -- (detailScopeBuf/detailScopeMergeBuf) -- never tipBuf/mergeBuf, which the MAIN panel's
    -- current-scope repaint holds and must not have overwritten out from under it by a row hover in
    -- between repaints. otherScope is always "session" or "lifetime" (never "last" -- see
    -- otherScopeFor above), so this never needs V.lastScopeReady's gate itself.
    local detailScopeBuf, detailScopeMergeBuf = {}, {}

    local function findOtherScopeRow(name, otherScope)
        local rows = VampifyAggregate.spellBreakdown(VampifyState, detailScopeBuf, otherScope)
        local merged = V.mergeByName(rows, detailScopeMergeBuf)
        local n = table.getn(merged)
        local i
        for i = 1, n do
            if merged[i].name == name then return merged[i] end
        end
        return nil
    end

    -- Per-id item-source breakdown, injected into V.buildDetailLines via ctx.sourceBreakdownFn (see
    -- that function's own comment for the pure-function contract it expects). Bound to
    -- VampifyAggregate.spellSourceBreakdown(spellId, scope, out). Guarded so its absence, an empty
    -- result (out.n == 0 -- e.g. no per-item attribution recorded yet for this spell id), OR
    -- scope=="last" against an un-upgraded core (V.lastScopeReady -- see its own comment; this is
    -- the CURRENTLY-viewed scope here, unlike otherScopeFor's result above, so it genuinely can be
    -- "last") all degrade the same way: "the item-source section is simply not shown" for that id
    -- rather than an error or mislabeled data -- see V.buildDetailLines for the fallback itself; the
    -- rest of the detail panel never depends on this. Own pooled buffer (sourceBreakdownBuf), same
    -- convention as detailScopeBuf above -- the aggregate function owns resetting/filling it, this
    -- file only ever reads it back.
    local sourceBreakdownBuf = {}
    local function getSourceBreakdown(spellId, scope)
        if not (VampifyAggregate and VampifyAggregate.spellSourceBreakdown) then return nil end
        if scope == "last" and not V.lastScopeReady() then return nil end
        local out = VampifyAggregate.spellSourceBreakdown(spellId, scope, sourceBreakdownBuf)
        if not out or not out.n or out.n == 0 then return nil end
        return out
    end

    -- DETAIL_PAD stays a fixed constant; DETAIL_LINE_H is now SLIDER-DRIVEN (2026-08-25, same
    -- "Bar height" slider that drives ROW_H/SPLIT_ROW_H above -- see V.applyPanelBarHeight just
    -- below for the exact derivation). The panel's own WIDTH is a separate, older story -- no
    -- longer a fixed DETAIL_W constant, it tracks PANEL_W directly (in-game correction: all panel
    -- elements need to resize together, including the detail panel on row hover), the SAME
    -- dynamic value the breakdown panel itself uses (computePanelW(), reassigned every
    -- V.showTooltip repaint and live while the resize grip is dragged -- see reflowPanels below).
    -- Coupling the two to the identical value, rather than a second independently-scaled number,
    -- is what keeps them visually consistent at every drag width, not just the two constants
    -- (300/260) that happened to look similar before this pass.
    local DETAIL_PAD, DETAIL_LINE_H = 10, 12

    -- Live-apply entry point for the "Panel bar height" options slider (2026-08-25) -- moves
    -- ROW_H/SPLIT_ROW_H (the ability-row and split-row bars, kept EQUAL -- they already
    -- coincidentally were, before this slider existed) together with the slider value, and
    -- DETAIL_LINE_H (the row-detail panel's own line height -- smaller even at the shared default,
    -- 12 vs 18) at a fixed 12/18 RATIO off it, floored at 10 REGARDLESS of how low ROW_H itself
    -- goes: DETAIL_LINE_H is fundamentally a TEXT-LINE-height metric (most of its rows are plain
    -- text, not bars, unlike ROW_H's rows which always are one) -- proportional scaling alone would
    -- put it under its own 10px readability floor (V.PANEL_BAR_H_MIN=10 * 12/18 = 6.67) well before
    -- ROW_H reaches its own floor, so it gets an independent clamp rather than inheriting ROW_H's.
    --
    -- Called by gui/options.lua's slider setter AFTER it has already written the new value to
    -- VampifyConfig.get().panelBarHeight (same split V.applyPillHeight above and this file's SCT
    -- sliders already use), and once from buildTip() itself (below) to apply the PERSISTED value
    -- the first time the panel is actually built (buildTip runs lazily, well after login -- see
    -- ROW_H's own declaration comment for why the config read could not simply happen there).
    -- Redraws the panel immediately if it is currently open (tip:IsShown()) -- V.showTooltip already
    -- reads ROW_H/SPLIT_ROW_H/DETAIL_LINE_H fresh on every repaint (same "mutate a shared local, let
    -- existing repaint-idempotent functions pick it up" pattern this file already uses for PANEL_W),
    -- so a single re-invocation is enough; V.showTooltip's own tail already re-shows the hovered
    -- row's detail panel too, so a separate detail-panel call is not needed here.
    function V.applyPanelBarHeight(newH)
        newH = clampPanelBarH(newH)
        ROW_H = newH
        SPLIT_ROW_H = newH
        DETAIL_LINE_H = math.floor(newH * 12 / 18 + 0.5)
        if DETAIL_LINE_H < 10 then DETAIL_LINE_H = 10 end
        if tip and tip:IsShown() then V.showTooltip() end
    end

    local function buildDetail()
        if detail then return detail end
        detail = CreateFrame("Frame", "VampifyBarRowDetail", UIParent)
        detail:SetWidth(PANEL_W)
        detail:SetHeight(10)
        -- DIALOG + a level above the breakdown panel's own 20 -- see tip's own strata comment for
        -- why not TOOLTIP. This panel is opened FROM a row of that one and must sit over it.
        detail:SetFrameStrata("DIALOG")
        detail:SetFrameLevel(30)
        detail:SetBackdrop(W.SOLID_BACKDROP)
        detail:SetBackdropColor(0.043, 0.052, 0.068, 0.94)
        detail:SetBackdropBorderColor(W.COLORS.line.r, W.COLORS.line.g, W.COLORS.line.b, 1)
        W.ApplyBackdropShadow(detail)
        -- Mouse-enabled now (2026-08-24 hover-chain redesign -- was EnableMouse(false)
        -- click-through, which made this panel impossible to reach with the mouse at all). Its own
        -- OnEnter/OnLeave join the shared hover chain the same way the breakdown panel's do
        -- (V.chainEnter(Chain) on entry cancels any pending close; V.chainLeave(Chain, 3) on exit gives the mouse
        -- HOVER_GRACE seconds to land back on a row or on this panel again before it actually
        -- closes) -- what makes the requested behavior possible: as long as the mouse stays over
        -- the detail window, a future "details of details" panel could be shown too. A future level-4
        -- "detail of detail" panel would join the same chain the same way: V.chainRegister(Chain, 4, ...)
        -- plus these same two lines on its own frame.
        detail:EnableMouse(true)
        detail:SetScript("OnEnter", function() V.chainEnter(Chain) end)
        detail:SetScript("OnLeave", function() V.chainLeave(Chain, 3) end)
        detail:Hide()
        return detail
    end

    local function detailLineFS(idx)
        -- THICKOUTLINE + shadow, not plain (was: no outline flag at all). Measured via a
        -- worst-over-every-glyph-offset sweep (in-game correction: measure the contrast
        -- row-by-row, and use THICKOUTLINE plus a shadow if needed):
        -- the dim-colored source-row text on the goldSoft@0.3 glass mini-bar measured 1.66:1,
        -- far under the 4.5:1 floor -- a flat font on a gloss-topped bar is simply unreadable at
        -- this size. Applied to every line (the FontString is pooled by row index and reused for
        -- both bar-bearing and plain rows -- font flags are set once at creation, not per-render),
        -- consistent with the same fix already applied to the pill's own text and the ability-row
        -- text above.
        local fs = detail:CreateFontString("VampifyBarRowDetailLine" .. idx, "OVERLAY")
        W.ApplyFont(fs, 10, "THICKOUTLINE")
        W.ApplyShadow(fs, true)
        fs:SetWidth(PANEL_W - 2 * DETAIL_PAD)
        fs:SetJustifyH("LEFT")
        return fs
    end

    -- One pooled mini GLASS bar per detail line -- only shown for lines that carry a `bar` share
    -- (currently just the item-source rows, see V.buildDetailLines/V.formatSourceRowLine).
    -- In-game report: the detail panel's bars should use the same glass treatment -- same
    -- FILL -> SHADE -> SHINE stack as every other bar in this file now (buildGlassBar above),
    -- single-color (no ST/AoE split at this level), kept at its earlier alpha 0.3 on the FILL
    -- layer only (layoutGlassBar's fillAlpha param) -- this is meant to read as a subtle
    -- highlight strip behind the line's own text, not a bold value bar like the panel's ability
    -- rows, and alpha 0.3 is what carried that subdued look before; the shade/shine layers keep
    -- their own baked alpha unchanged; still verified >=4.5:1 worst-case row. BACKGROUND layer, same reasoning as the main
    -- breakdown panel's own row bars (setRow above): the FontString it sits behind is OVERLAY, so
    -- draw order is guaranteed regardless of which was created first.
    local function detailBarTex(idx)
        return buildGlassBar(detail, "VampifyBarRowDetailBar" .. idx)
    end

    -- Font-metric probe for V.wrapText below. A FontString carrying the SAME font and flags as the
    -- real detail lines (detailLineFS above) -- a THICKOUTLINE glyph is wider than a plain one, so
    -- measuring with anything else would under-measure and let a piece wrap in the client after
    -- all. Deliberately NOT :Hide()n: GetStringWidth is only valid once a region has been through a
    -- render pass, and a hidden region never gets one. It is emptied at the end
    -- of every render instead, which draws nothing while keeping it a live, measurable region.
    local measureFS
    local function measureWidth(text)
        if text == "" then return 0 end
        if not measureFS then
            measureFS = detail:CreateFontString("VampifyBarRowDetailMeasure", "OVERLAY")
            W.ApplyFont(measureFS, 10, "THICKOUTLINE")
            measureFS:SetPoint("TOPLEFT", detail, "TOPLEFT", DETAIL_PAD, 0)
        end
        measureFS:SetText(text)
        local w = measureFS:GetStringWidth()
        if w and w > 0 then return w end
        -- Before the panel's first render pass the client has no metric to give (same reason), and
        -- V.wrapText's own nil handling would then leave the line unsplit -- the overflow this all
        -- exists to prevent. 7px per character at font size 10 is deliberately WIDE (the real
        -- average is nearer 5): over-estimating splits a line earlier than needed, which costs a
        -- little vertical space; under-estimating puts text back on top of text.
        return string.len(text) * 7
    end

    -- Splits every line entry into pieces that each fit ONE slot, so the fixed-cursor layout below
    -- can keep advancing by exactly DETAIL_LINE_H per entry. The bar (and only the bar) stays on
    -- the entry's FIRST piece -- a bar repeated behind every continuation line would read as
    -- several sources rather than one wrapped one.
    local wrapBuf = {}
    local function wrapLines(lines)
        local avail = PANEL_W - 2 * DETAIL_PAD
        local out = wrapBuf
        local i
        for i = table.getn(out), 1, -1 do table.remove(out, i) end
        for i = 1, table.getn(lines) do
            local ln = lines[i]
            local pieces = V.wrapText(ln.text, avail, measureWidth)
            local j
            for j = 1, table.getn(pieces) do
                table.insert(out, { text = pieces[j], color = ln.color,
                                    bar = (j == 1) and ln.bar or nil })
            end
        end
        return out
    end

    local function renderDetailLines(rawLines)
        -- Re-synced every repaint, not just at buildDetail()'s one-time construction -- PANEL_W is
        -- now live (drag-resize), so a panel built at one width and later shown again after a
        -- resize must pick up the new width, not the one frozen at its first CreateFrame call.
        detail:SetWidth(PANEL_W)
        local lines = wrapLines(rawLines)
        local n = table.getn(lines)
        local y = -DETAIL_PAD
        local barMaxW = PANEL_W - 2 * DETAIL_PAD
        -- Text vertically CENTERED in each line's own DETAIL_LINE_H-tall row slot, not top-aligned
        -- (in-game correction: the label should also sit vertically centered in the bar) --
        -- applied uniformly to EVERY line (bar-bearing or not), since detailLineFS's
        -- pooled FontString is reused across both kinds of row and its font is only set once at
        -- creation; a bar-less line still occupies the same DETAIL_LINE_H slot visually, so
        -- centering it the same way keeps every line's text at a consistent baseline.
        local textMidYOffset = -(DETAIL_LINE_H - 1) / 2
        local i
        for i = 1, n do
            local fs = detailLinesFS[i]
            if not fs then fs = detailLineFS(i); detailLinesFS[i] = fs end
            -- Live width re-sync (see detail:SetWidth above -- same reasoning, pooled FontStrings
            -- were only ever sized once at creation).
            fs:SetWidth(PANEL_W - 2 * DETAIL_PAD)
            local ln = lines[i]
            local c = W.COLORS[ln.color] or W.COLORS.ink
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", detail, "TOPLEFT", DETAIL_PAD, y + textMidYOffset)
            fs:SetText(ln.text)
            fs:SetTextColor(c.r, c.g, c.b)
            fs:Show()

            local bar = detailLinesBar[i]
            if not bar then bar = detailBarTex(i); detailLinesBar[i] = bar end
            if ln.bar and ln.bar > 0 then
                layoutGlassBar(bar, detail, DETAIL_PAD, y, DETAIL_LINE_H - 1,
                    barMaxW * (ln.bar / 100), W.COLORS.goldSoft, 0, nil, 0.3)
            else
                layoutGlassBar(bar, detail, DETAIL_PAD, y, DETAIL_LINE_H - 1, 0, nil, 0, nil)
            end
            y = y - DETAIL_LINE_H
        end
        for i = n + 1, table.getn(detailLinesFS) do detailLinesFS[i]:Hide() end
        for i = n + 1, table.getn(detailLinesBar) do
            layoutGlassBar(detailLinesBar[i], detail, DETAIL_PAD, 0, DETAIL_LINE_H - 1, 0, nil, 0, nil)
        end
        detail:SetHeight(n * DETAIL_LINE_H + 2 * DETAIL_PAD)
        -- Emptied, not hidden -- see measureWidth's own comment: a hidden region stops being
        -- measurable, an empty one just draws nothing.
        if measureFS then measureFS:SetText("") end
    end

    -- Right of the main panel by default; left if there is no room. "No room" is measured simply
    -- (deliberately kept simple) -- tip and detail are both parented straight to UIParent
    -- with no SetScale of their own, so they share UIParent's effective scale and tip:GetRight()
    -- can be compared directly against UIParent:GetWidth() without a separate scale correction.
    local function positionDetail()
        detail:ClearAllPoints()
        local tipRight = tip:GetRight() or 0
        local screenW = UIParent:GetWidth() or 1024
        if tipRight + PANEL_W + 4 <= screenW then
            detail:SetPoint("TOPLEFT", tip, "TOPRIGHT", 4, 0)
        else
            detail:SetPoint("TOPRIGHT", tip, "TOPLEFT", -4, 0)
        end
    end

    -- i: a data-row index into rowEntryMap (1..n from the last V.showTooltip repaint), NOT a
    -- spell id. Called from a row-hover frame's OnEnter (see rowHoverFrame above) -- never
    -- re-merges; rowEntryMap[i] already holds this repaint's merged row (see its declaration).
    function V.showRowDetail(i)
        local entry = rowEntryMap[i]
        if not entry then return end
        buildDetail()
        if detailLastIndex == i and detailLastVersion == repaintVersion then
            -- Same row, same repaint -- nothing has changed since the last time this was shown,
            -- so only make sure it is visible (it may have been hidden by an intervening OnLeave).
            detail:Show()
            return
        end
        detailLastIndex, detailLastVersion = i, repaintVersion

        local scope = V.normalizeScope(V.tipScope)
        local otherScope = otherScopeFor(scope)
        -- hasSplit/hasAoeHits, same call/scope setRow's own bar-color decision already uses
        -- (rowSplit above) -- so the detail panel's explanation and the main panel's bar color can
        -- never disagree. hasSplit: in-game correction: why do Lightning Strike and
        -- Frostbrand Attack show a brown tint instead of the usual red? -- see V.formatSplitStatusNote's
        -- own header comment for the investigation (not a proc-classification bug; explained
        -- there). hasAoeHits/idCount (2026-08-25, Earth Shock AoE-damping bug fix -- see
        -- V.classifyRate's own comment): the two PROVABLE causes V.formatRateLine now checks before
        -- it will print "(AoE damping)"/"(mixed ranks)" at all.
        local sp = rowSplit(entry, scope)
        local ctx = {
            itemOriginFn = VampifyConst.itemProcOrigin,
            spellbookSet = getSpellbookSet(),
            nameFn = VampifyConst.spellName,
            gearPct = sumSourcePercents(),
            otherScopeName = otherScope,
            otherScopeRow = findOtherScopeRow(entry.name, otherScope),
            sourceBreakdownFn = function(spellId) return getSourceBreakdown(spellId, scope) end,
            hasSplit = sp.hasSplit,
            hasAoeHits = (sp.aoeHits or 0) > 0,
        }
        renderDetailLines(V.buildDetailLines(entry, ctx))
        positionDetail()
        detail:Show()
    end

    function V.hideRowDetail()
        if detail then detail:Hide() end
    end

    -- A frame that cannot be found is a frame that does not exist. /vf pos brings it home. Also
    -- resets the DRAG-RESIZED width back to the default -- a frame reset to a default position but
    -- still stuck at some earlier resized width is only half found.
    function V.resetPos()
        V.build()
        local cfg = VampifyConfig.get()
        local d = VampifyConfig.DEFAULTS.pos
        if cfg then
            cfg.pos = { point = d.point, x = d.x, y = d.y }
            cfg.size = { w = BAR_DEFAULT_W }
            -- Bringing a lost frame home means wanting to see it. Recorded as the preference and
            -- not only shown, or core/commands.lua would hide it again on the next loading screen
            -- and /vf pos would look like it had done nothing.
            cfg.shown = true
        end
        -- Size before position (SetPoint's own clamp-to-screen math reads the frame's CURRENT
        -- size) -- same order V.build already uses when restoring both from SavedVariables.
        frame:SetWidth(BAR_DEFAULT_W)
        frame:ClearAllPoints()
        frame:SetPoint(d.point, UIParent, d.point, d.x, d.y)
        frame:Show()
    end

    -- Called from the throttle in commands.lua, never from the damage path: that path may fire 60
    -- times a second and the eye cannot read that. SetText only on a real change, so an idle
    -- display costs nothing.
    function V.update()
        if not frame or not frame:IsShown() then return end
        -- fight() returns VampifyState's reused _fight table -- setting overheal on it here is an
        -- extra field on an existing table, not a new allocation, and aggregate.lua never reads it.
        local stats = VampifyAggregate.fight(VampifyState)
        local cfg = VampifyConfig.get()
        if cfg and cfg.showOverheal then
            local oh = (stats.heal or 0) - (VampifyState.effHeal or 0)
            if oh < 0 then oh = 0 end     -- rounding slack must never go negative
            stats.overheal = oh
        else
            -- stats is the reused _fight table -- must be cleared, not just left unset, or a value
            -- from a moment when the option was on would linger and keep showing.
            stats.overheal = nil
        end
        -- ---- compact-bar segments (mockup redesign, 2026-08-24) -----------------------------
        -- Each segment's own SetText only on a real change (this function's own header comment's
        -- "change-gating" convention), same as the old single-FontString `lastText` compare it
        -- replaces -- one cache per segment now that there are several.
        local healStr = V.formatHealSegment(stats)
        if healStr ~= frame.vfLastHeal then
            frame.vfLastHeal = healStr
            frame.vfHealText:SetText(healStr)
        end

        -- HPS: plain text, change-guarded (no orb any more -- see this file's own header comment
        -- on the "HPS: plain text only" block near buildPill for the removal history).
        W.SetTextG(frame.vfHpsText, V.formatHpsSegment(stats))

        -- Re-derive the pill's width from the REAL heal/HPS text widths just set above -- not only
        -- on a resize (OnSizeChanged) but every tick, so a heal total gaining or losing a digit
        -- reclaims/gives back exactly that much pill width immediately, the same dead-space fix
        -- applies in both directions (see recomputePillW's own header comment for the full story).
        local pillW = recomputePillW(frame)

        -- ST/AoE pill -- absent (VampifyAggregate.splitTotals not wired up, or out.total <= 0)
        -- reads as "hide the pill, rest of the bar stays" (the fallback contract). Gear% has no
        -- bar segment either -- V.formatSources is not called from here (still shown in the
        -- row-detail panel's own rate line, V.formatRateLine's "vs X% Nominal").
        local splitOut = nil
        if VampifyAggregate and VampifyAggregate.splitTotals then
            if not frame.vfBadgeSplitBuf then frame.vfBadgeSplitBuf = {} end
            splitOut = VampifyAggregate.splitTotals("session", frame.vfBadgeSplitBuf)
        end
        local showBadge = (splitOut and splitOut.total and splitOut.total > 0) and true or false
        if showBadge then
            local redLabel  = V.formatAmount(splitOut.stHeal or 0)
            local blueLabel = V.formatAmount(splitOut.aoeHeal or 0)
            -- Snapshotted on `frame` so OnSizeChanged (the resize grip, live during a drag) can
            -- re-run layoutPill at the CURRENT pill width without waiting for the next V.update
            -- tick, using the last data this tick already computed.
            frame.vfLastStPct, frame.vfLastAoePct = splitOut.stPct, splitOut.aoePct
            frame.vfLastRedLabel, frame.vfLastBlueLabel = redLabel, blueLabel
            layoutPill(frame.vfPill, pillW, splitOut.stPct, splitOut.aoePct, redLabel, blueLabel)
        end
        -- ---- gear%-on-bar segment (2026-08-25 option) -------------------------------------------
        -- Same figure V.formatSources already computes for other callers (the row-detail rate line,
        -- gui/options.lua's own info panel) -- VampifyState.sourcePercents, not recomputed here.
        -- Cleared (SetText("")) rather than merely left stale when the option is off, so
        -- recomputePillW's own GetStringWidth() read reads 0 for a hidden segment instead of
        -- whatever text happened to be set the last time the option was on.
        local showPct = (cfg and cfg.showGearPct) and true or false
        if showPct then
            local pctStr = V.formatSources(VampifyState and VampifyState.sourcePercents)
            if pctStr ~= frame.vfLastPct then
                frame.vfLastPct = pctStr
                frame.vfPctText:SetText(pctStr)
            end
        elseif frame.vfLastPct ~= nil then
            frame.vfLastPct = nil
            frame.vfPctText:SetText("")
        end

        if showBadge ~= frame.vfLastShowBadge or showPct ~= frame.vfLastShowPct then
            frame.vfLastShowBadge = showBadge
            frame.vfLastShowPct = showPct
            layoutBarSegments(frame, showBadge, showPct)
            -- The gear% segment's own width just changed the pill's available space (recomputePillW
            -- already reads cfg.showGearPct live -- see its own comment) -- re-run it and the pill
            -- layout immediately rather than waiting one more tick for the width to catch up, same
            -- "no visible stale frame" reasoning V.show()'s own forced-repaint comment gives.
            pillW = recomputePillW(frame)
            if showBadge then
                layoutPill(frame.vfPill, pillW, frame.vfLastStPct or 0, frame.vfLastAoePct or 0,
                    frame.vfLastRedLabel, frame.vfLastBlueLabel)
            end
        end

        -- While the breakdown panel is SHOWN (hover-chain redesign, 2026-08-24 -- was "while
        -- pinned"; hovering, not pinning, is what keeps it open now, see the Chain block on
        -- V.build), it has no other driver keeping it current -- no button, no event of its own --
        -- so it would otherwise stay a frozen snapshot of the moment it was last hovered
        -- (adversarial review, 2026-08-23, originally against the pin feature; the same gap exists
        -- for a long hover). Piggybacked on this function (already called ~2x/s by the throttle in
        -- core/commands.lua, which stays untouched) rather than a new OnUpdate/ticker of this
        -- file's own, gated to at most once a second via V.shouldRepaintPin/lastPinRepaintTime --
        -- the panel is heavier than the compact bar's own segments above and does not need that
        -- throttle's full rate.
        if tip and tip:IsShown() then
            local now = GetTime()
            if V.shouldRepaintPin(lastPinRepaintTime, now) then
                lastPinRepaintTime = now
                V.showTooltip()
            end
        end
    end

    function V.show()
        V.build()
        frame:Show()
        -- Force one full repaint of every segment after re-arming, same reasoning the old single
        -- `lastText = nil` had: a value that happens to already match the pooled cache would
        -- otherwise be skipped by V.update's own change-gating even though the FontStrings were
        -- just hidden along with the whole bar and need their text set again.
        -- vfLastHeal (the manual change-guard above) and vfLastShowBadge/vfLastShowPct (the pill's
        -- and the gear%-segment's own shown/hidden caches, 2026-08-25) are the only caches that
        -- need a forced reset here -- the HPS label goes through W.SetTextG, whose own guard lives
        -- on the FontString itself and needs no help: that FontString was never hidden along with
        -- the bar (only `frame` was), so its rendered text was never stale to begin with. Same for
        -- vfLastPct's own text guard -- only its SHOWN/HIDDEN layout cache needs forcing here.
        frame.vfLastHeal, frame.vfLastShowBadge, frame.vfLastShowPct = nil, nil, nil
        -- The marker is hidden along with the bar, so an open finding has to be restored with it.
        if warnMsg and warnBtn then warnBtn:Show() end
        V.update()
    end

    -- msg = the finding in plain words, or nil to clear. Held as text rather than as a code so the
    -- marker never has to know what the watchdog checks.
    function V.setWatchFlag(msg)
        warnMsg = msg
        if not warnBtn then return end
        if msg then warnBtn:Show() else warnBtn:Hide() end
    end

    function V.hide()
        if frame then frame:Hide() end
        if warnBtn then warnBtn:Hide() end
        -- The breakdown panel is a separate frame and does not inherit the bar's visibility. If the
        -- bar is hidden mid-hover, OnLeave never fires (V.chainLeave(Chain, 1) never runs, so the grace
        -- timer never starts either) and the panel would otherwise stay on screen with nothing
        -- under it. Cosmetic, but it outlives the thing it belongs to -- hidden immediately here
        -- rather than left to the hover chain's own grace period.
        if V.hideTooltip then V.hideTooltip() end
    end

    -- Registered here (the end of the whole WoW-wiring section) rather than up in V.build, and as a
    -- plain top-level statement rather than inside a function: `tip` must already be a declared
    -- local for the closure below to capture the real upvalue instead of silently reading a global
    -- -- exactly the 5.0/lexical-scope trap this file's own header comment (see `local W` near the
    -- top of this section) warns about -- and that is only true once the "breakdown panel" section
    -- above has run its `local tip, tipRows, ...` line. By this point in the file it has.
    V.chainRegister(Chain, 2, function() if tip then tip:Hide() end end)
    V.chainRegister(Chain, 3, function() V.hideRowDetail() end)

    -- ---- geometric self-healing safety net (2026-08-24 stuck-panel report) -----------------
    --
    -- The enter/leave bookkeeping above is now believed correct (the sibling-button gap found and
    -- fixed, see V.newChain's own trailing "investigation" comment) -- but it could NOT be fully
    -- verified in-game (no running client to single-step here), and 1.12's OnEnter/OnLeave pairing
    -- is independently known to sometimes simply not fire for overlapping frames. Rather than paper
    -- over an unproven root cause with a longer grace period or an unconditional force-hide (both
    -- explicitly rejected -- they would only hide the symptom), this corrects the OBSERVABLE state
    -- directly: periodically confirm the mouse is ACTUALLY still over some visible chain member:
    -- MouseIsOver(frame) tests screen-space containment, not "which frame currently has mouse
    -- focus" -- immune BY CONSTRUCTION to the nested-focus quirk above, including for any future
    -- child button this file's enter/leave wiring forgets to wire.
    --
    -- Throttled (RESCUE_INTERVAL), not run every OnUpdate tick: it exists to catch a MISSED event,
    -- not to drive the normal-case UX (V.chainTick's own enter/leave path already does that,
    -- promptly), so it can afford to be slow -- and doing so keeps this cheap in the overwhelming
    -- majority of frames (see this file's own guardrail on a sparing OnUpdate handler). Does
    -- nothing at all while nothing is shown (the common case whenever the mouse is nowhere near
    -- the addon).
    local RESCUE_INTERVAL = 0.5
    local rescueTimer = 0
    rescueCheck = function(elapsed)
        local anyShown = (tip and tip:IsShown()) or (detail and detail:IsShown())
        if not anyShown then
            rescueTimer = 0
            return
        end
        rescueTimer = rescueTimer + (elapsed or 0)
        if rescueTimer < RESCUE_INTERVAL then return end
        rescueTimer = 0

        local overAny = (frame:IsShown() and MouseIsOver(frame))
            or (tip and tip:IsShown() and MouseIsOver(tip))
            or (detail and detail:IsShown() and MouseIsOver(detail))
        if not overAny then
            -- Self-heal: force everything closed, the same way V.chainTick's own expiry would --
            -- the hard requirement is that NOTHING stays visible with the mouse confirmed
            -- elsewhere, regardless of which bookkeeping path failed to notice.
            if tip then tip:Hide() end
            V.hideRowDetail()
            Chain.isCounting = false
            Chain.pendingCloseFrom = nil
        end
    end
end
