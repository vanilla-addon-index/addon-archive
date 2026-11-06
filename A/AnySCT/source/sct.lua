-- AnySCT sct.lua -- floating combat text for the listed targetSCTs, styled after the client's own
-- world damage numbers.
--
-- Where a line appears is decided by AnySCT_Plates.Select (plates.lua): over the mob's nameplate
-- (top centre), clamped to the screen when the plate is off screen, or at the fixed anchor
-- AnySCTAnchor. Plate lines follow the plate every tick; anchor lines scroll from the anchor.
--
-- Engine: a fixed FontString pool and ONE shared OnUpdate that exists only while a line is in
-- flight (idle cost zero). Nothing is allocated per tick. This file only draws its own frames and
-- never touches Blizzard's CombatText, SHOW_COMBAT_TEXT or another SCT addon.

AnySCT_SCT = {}
local S = AnySCT_SCT

-- ONE table for every visual / motion parameter; the animation code reads only from here.
-- Values are measured engine parameters of the 1.12.1 client's own world text; colours and size match
-- the client's pet text. Retune by changing values here.
AnySCT_STYLE = {
    font = "CLIENT",            -- key of S.FONTS, or "CLIENT" = global DAMAGE_TEXT_FONT (pfUI honoured)
    lifetime = 1.5,             -- seconds, every text
    fadeIn = 0.15,              -- alpha 0 -> 1 over this many seconds
    fadeOutNumber = 0.76,       -- fade-out start (seconds); alpha reaches 0 at the lifetime
    fadeOutCrit = 1.0,
    fadeOutWord = 1.0,          -- Miss / Dodge / Parry / Block ...
    fadeOutAbsorb = 0.09,       -- "Absorb" is a quick flicker
    riseHeight = 120,           -- px a normal text rises (engine: 2 world units; screen distance varies)
    sizeScale = 0.018333,       -- text pixel size = scale x screen diagonal (1024x768 -> 23 px)
    critSizeScale = 0.0275,     -- crits (1024x768 -> 35 px)
    shadow = 0.002,             -- shadow offset, fraction of the viewport per axis (down-right)
    spread = 0,                 -- random horizontal px per line (the engine stacks instead)
    maxLines = 60,              -- total lines on screen (several mobs with bursts)
    maxPerTarget = 16,          -- lines per mob: lifetime 1.5 s x 9 hits/s = 14 live lines, none recycled early
    colorMelee = { 1.0, 0.518, 0.0 },   -- 0xFFFF8400
    colorSpell = { 1.0, 0.871, 0.0 },   -- 0xFFFFDE00
    -- crit size factor keyframes {fraction of the lifetime, factor on the crit size}; linear in
    -- between, last value held. {{0,1},{1,1}} turns the pop off.
    critKeyframes = { { 0, 0.1 }, { 0.1, 2.0 }, { 0.2, 1.0 }, { 1, 1.0 } },
    colorHeal = { 0.1, 1.0, 0.1 },      -- heals on a listed targetSCT
    glancingScale = 0.75,       -- only with the colour scheme on
}
local STYLE = AnySCT_STYLE

-- Option defaults follow the style table (core.lua loads first and owns the defaults table).
if AnySCT_DEFAULTS then
    AnySCT_DEFAULTS.colorMelee = STYLE.colorMelee
    AnySCT_DEFAULTS.colorSpell = STYLE.colorSpell
    AnySCT_DEFAULTS.colorHeal = STYLE.colorHeal
    AnySCT_DEFAULTS.riseHeight = STYLE.riseHeight
    AnySCT_DEFAULTS.jitter = STYLE.spread
    AnySCT_DEFAULTS.maxLines = STYLE.maxLines
    AnySCT_DEFAULTS.maxLinesPerTarget = STYLE.maxPerTarget
    AnySCT_DEFAULTS.font = STYLE.font
end

-- Piecewise-linear curve value at t. Pure, allocation-free.
function S.KeyScale(kf, t)
    local n = table.getn(kf)
    if t <= kf[1][1] then return kf[1][2] end
    for i = 2, n do
        local b = kf[i]
        if t <= b[1] then
            local a = kf[i - 1]
            local span = b[1] - a[1]
            if span <= 0 then return b[2] end
            return a[2] + (b[2] - a[2]) * ((t - a[1]) / span)
        end
    end
    return kf[n][2]
end

function S.CurveActive(kf)
    for i = 1, table.getn(kf) do
        if kf[i][2] ~= 1 then return true end
    end
    return false
end

function S.CurveAnimated(kf)
    for i = 2, table.getn(kf) do
        if kf[i][2] ~= kf[1][2] then return true end
    end
    return false
end

-- Text pixel size in UI units: scale x diagonal x factor. (pixels = units x effective scale, and
-- the diagonal in pixels = the UI-unit diagonal x effective scale, so the scale cancels.)
function S.TextSize(scale, factor, sw, sh)
    return scale * factor * math.sqrt(sw * sw + sh * sh)
end

S.COLORS = {
    heal     = STYLE.colorHeal,
    pet      = STYLE.colorMelee,
    spell    = STYLE.colorSpell,
    hit      = { 1.00, 1.00, 1.00 },
    crit     = { 1.00, 0.90, 0.15 },
    glancing = { 0.62, 0.62, 0.62 },
    crushing = { 1.00, 0.55, 0.10 },
    miss     = { 1.00, 0.25, 0.25 },
    dodge    = { 1.00, 0.25, 0.25 },
    parry    = { 1.00, 0.25, 0.25 },
    block    = { 0.35, 0.55, 1.00 },
    absorb   = { 0.75, 0.40, 1.00 },
    resist   = { 0.75, 0.40, 1.00 },
    immune   = { 0.75, 0.40, 1.00 },
    evade    = { 0.75, 0.40, 1.00 },
    deflect  = { 0.75, 0.40, 1.00 },
}

-- Text colour r, g, b. Precedence:
--   1. heal colour (ckey "heal")
--   2. the listed source's own colour (option colorPerTarget on and res.srcRgb set); the same colour
--      for numbers, words and spells, whatever the colour scheme says
--   3. ckey "pet" / "spell" (colour scheme off): the class colour of the source when the option is on
--      and the class is known (pets and totems carry their owner's), else the configured melee /
--      spell colour
--   4. every other key: a per-kind colour of the colourize scheme.
function S.PickColour(res, opt, ckey)
    if ckey == "heal" then
        local h = opt.colorHeal or S.COLORS.heal
        return h[1], h[2], h[3]
    end
    if opt.colorPerTarget and res.srcRgb then
        local c = res.srcRgb
        return c[1], c[2], c[3]
    end
    if ckey == "pet" or ckey == "spell" then
        if opt.classColours and res.class and RAID_CLASS_COLORS then
            local rc = RAID_CLASS_COLORS[res.class]
            if rc then return rc.r, rc.g, rc.b end
        end
        local c = (ckey == "spell") and opt.colorSpell or opt.colorMelee
        if c then return c[1], c[2], c[3] end
    end
    local c = S.COLORS[ckey] or S.COLORS.pet
    return c[1], c[2], c[3]
end

-- Pure: GO / WAIT label text. srcName / mobName are optional prefixes.
--   GO +4210              (buffer = threat distance to pulling aggro)
--   WAIT 1250 / 3000      (buffer / required buffer)
function S.ThreatText(status, buffer, need, srcName, mobName)
    local b = math.floor((buffer or 0) + 0.5)
    local t
    if status == "GO" then
        t = "GO +" .. b
    else
        t = "WAIT " .. b .. " / " .. math.floor((need or 0) + 0.5)
    end
    if srcName then t = srcName .. " " .. t end
    if mobName then t = mobName .. ": " .. t end
    return t
end

S.WORDS = {
    miss = "Miss", dodge = "Dodge", parry = "Parry", block = "Block", absorb = "Absorb",
    resist = "Resist", immune = "Immune", evade = "Evade", deflect = "Deflect",
}

S.FONTS = {
    FRIZQT = "Fonts\\FRIZQT__.TTF",
    SKURRI = "Fonts\\skurri.ttf",
    ARIALN = "Fonts\\ARIALN.TTF",
}

function S.FontPath(choice)
    if choice == "CLIENT" then
        if type(DAMAGE_TEXT_FONT) == "string" then return DAMAGE_TEXT_FONT end
        return S.FONTS.FRIZQT
    end
    return S.FONTS[choice] or S.FONTS.FRIZQT
end

-- Pure: result + options + display mode -> text, colour key, isWord, size multiplier, suffix.
-- Numbers are bare. Mode 3 (fixed anchor) always names the mob: the position no longer identifies it.
function S.Format(res, opt, mode)
    local kind = res.kind
    local word = S.WORDS[kind]
    local amount = res.amount or 0
    local text
    local isWord = false
    if word and (amount <= 0 or opt.colourize) then
        isWord = true
        if amount > 0 then text = word .. " " .. amount else text = word end
    else
        text = tostring(amount)
    end
    if opt.markGlancing and (kind == "glancing" or kind == "crushing") then
        text = text .. " " .. kind
    end
    local mul = 1
    if kind == "glancing" and opt.colourize then mul = STYLE.glancingScale end
    local suffix
    if kind == "heal" then
        text = "+" .. text
        if opt.healShowHealer and res.healer then suffix = res.healer end
    elseif opt.showSpellName and res.spell then
        suffix = res.spell
    end
    -- the listed source's name comes first: Source - Spell - Victim (never on heals: the text is over it)
    if kind ~= "heal" and res.source then
        local sm = opt.sourceNameMode
        if sm == "always" or (sm == "multi" and res.srcMulti) then
            local nm = res.source
            if res.srcPet then nm = nm .. " (" .. res.srcPet .. ")" end
            if suffix then suffix = nm .. " - " .. suffix else suffix = nm end
        end
    end
    if res.mobName and (opt.mobNameMode == "always" or (mode == 3 and opt.mobNameMode == "anchor")) then
        if suffix then suffix = suffix .. " - " .. res.mobName else suffix = res.mobName end
    end
    local colourKey = (res.spell or res.spellId) and "spell" or "pet"
    if kind == "heal" then colourKey = "heal"
    elseif opt.colourize then colourKey = kind end
    return text, colourKey, isWord, mul, suffix
end

-- Demo threat preview: the buffer climbs from ~300 to 1.3x the required lead over the burst (f 0..1).
function S.DemoThreat(f, need)
    need = need or 1500
    local start = (need > 300) and 300 or need * 0.2
    if f < 0 then f = 0 elseif f > 1 then f = 1 end
    local b = start + (need * 1.3 - start) * f
    return (b >= need) and "GO" or "WAIT", b, need
end
-- Demo timeline: see S.BuildDemo. Event tables are reused on every run (no allocation while it plays).
-- Fixed-anchor box and the GO / WAIT label sitting inside it (rough glyph width: 0.62 x size per char).
S.ANCHOR_W, S.ANCHOR_H, S.ANCHOR_LABEL_SIZE, S.PLATE_LABEL_SIZE = 200, 30, 12, 14
function S.EstTextWidth(text, size) return string.len(text) * size * 0.62 end
-- Where anchor-mode damage lines start so they clear the box (and the list label above it).
function S.AnchorLineOffset(showLabel) return showLabel and 16 or 2 end
-- ---- stack geometry -------------------------------------------------------------------------
-- A line occupies [bottom - suffixH, bottom + numberH]: the number sits on its anchor point, the
-- suffix (spell / name) hangs below it. Crits are reserved at the peak of their size pop. A new line
-- is inserted at the bottom; every older line of the same mob moves up by the new line's height plus
-- the suffix height of the line directly above it, which is what makes the new line fit under it.
function S.CritPeak(kf)
    local m = 1
    for i = 1, table.getn(kf) do if kf[i][2] > m then m = kf[i][2] end end
    return m
end
-- Distance of a line's anchor point from its start: the same rise rate for every line of a tower, so
-- older lines (larger t) only ever move away from newer ones.
function S.LineOffset(t, dur, rise, push) return t / dur * rise + push end
function S.NumberHeight(base, isCrit, peak) return isCrit and base * peak or base end
function S.SuffixHeight(base, hasSuffix)
    if not hasSuffix then return 0 end
    local sz = math.floor(base * 0.3)
    if sz < 10 then sz = 10 end
    return sz + 2
end
function S.StackAdvance(base, isCrit, peak, prevSuffixH)
    return S.NumberHeight(base, isCrit, peak) + (prevSuffixH or 0)
end
-- A crit of a tiny proc must not pop at full crit size: scale by the amount against the source's
-- running average hit (0.5 .. 1).
function S.CritFactor(amount, ref)
    if not ref or ref <= 0 then return 1 end
    local f = (amount or 0) / ref
    if f > 1 then return 1 end
    if f < 0.5 then return 0.5 end
    return f
end
function S.UpdateRef(ref, amount)
    if not ref then return amount end
    return ref + (amount - ref) * 0.1
end

-- ---- merging identical attacks ---------------------------------------------------------------
-- Is the result a word (Miss / Dodge / ...)? Same rule as S.Format.
function S.IsWordResult(res, opt)
    return (S.WORDS[res.kind] ~= nil) and (((res.amount or 0) <= 0) or (opt.colourize and true or false))
end

-- Result class that must match to merge: normal hits (glancing / crushing too) and crits stay apart.
function S.MergeClass(res)
    local k = res.kind
    if k == "crit" or res.crit then return "crit" end
    if k == "hit" or k == "glancing" or k == "crushing" then return "hit" end
    return k
end

-- Does line slot s (fields mKey, mWord, mCls, mSrc, mSpell, mHealer, mPet, t) absorb this result?
-- key = the place/victim key of the line (guid, name or "anchor"); words ignore the spell.
function S.MergeMatches(s, res, key, isWord, window)
    if not s.active or s.mKey ~= key or s.mWord ~= isWord or s.t > window then return false end
    if s.mCls ~= S.MergeClass(res) or s.mSrc ~= res.source or s.mPet ~= res.srcPet then return false end
    if isWord then return true end
    return s.mSpell == (res.spellId or res.spell) and s.mHealer == res.healer
end

function S.MergeLabel(text, count, showCount)
    if showCount and count > 1 then return text .. " x" .. count end
    return text
end

S.DEMO_BURST_LEN = 2.5

-- Demo source: the first listed targetSCT (name, class, own colour); without one a generic shaman tank.
S.DEMO_FALLBACK_NAME = "Shemp"  -- leak-gate: allow
S.DEMO_VICTIM = "Training Dummy"
function S.DemoSource(st)
    local e = st and st.order and st.byName and st.byName[st.order[1]]
    if e then
        return e.name, e.class, e.rgb, table.getn(st.order) > 1
    end
    return S.DEMO_FALLBACK_NAME, "SHAMAN", { 0, 0.44, 0.87 }, false
end

-- Burst skill sets per class. Entry: { spell (nil = white hit, "@kind" = miss word), weight, typical
-- amount, upper typical amount, typical crit amount, crit % , windfury-style extra hits }.
-- SHAMAN: shares and amounts from recorded tanking fights in dungeons and raids, last 30 days
-- (Stormstrike and Earth Shock are boosted so the preview shows them; crit rates are raised to
-- make a few crits visible). Every other class: plausible level-60 tank numbers, ESTIMATES.
S.DEMO_SETS = {
    SHAMAN = {
        { "Fire Strike", 51, 2, 2, 3, 10 }, { "Lightning Strike", 15, 3, 3, 5, 12 },
        { "Tidal Wave", 10, 29, 31, 43, 10 }, { nil, 9, 97, 118, 216, 22, 2 },
        { "Engulfing Shadows", 6, 100, 100, 100, 0 }, { "Ancient Accord", 3, 100, 110, 150, 6 },
        { "Thundercall", 2, 39, 56, 56, 0 }, { "Earth Shock", 8, 666, 760, 992, 15 },
        { "Stormstrike", 10, 117, 140, 241, 30 }, { "Flame Shock", 2, 85, 100, 458, 5 },
        { "@miss", 1 }, { "@dodge", 1 }, { "@parry", 1 }, { "@block", 1 }, { "@resist", 1 },
    },
    WARRIOR = {
        { nil, 28, 150, 190, 320, 25 }, { "Heroic Strike", 20, 280, 340, 560, 25 },
        { "Revenge", 14, 350, 420, 700, 25 }, { "Shield Slam", 14, 480, 560, 900, 25 },
        { "Sunder Armor", 10, 60, 60, 60, 0 }, { "@miss", 1 }, { "@dodge", 1 }, { "@parry", 1 }, { "@block", 1 },
    },
    DRUID = {
        { nil, 24, 120, 150, 260, 25 }, { "Maul", 22, 260, 320, 520, 25 }, { "Swipe", 30, 90, 110, 190, 25 },
        { "Lacerate", 12, 70, 70, 70, 0 }, { "@miss", 1 }, { "@dodge", 1 }, { "@parry", 1 }, { "@block", 1 },
    },
    PALADIN = {
        { nil, 28, 140, 175, 300, 25 }, { "Holy Shield", 18, 100, 120, 200, 0 },
        { "Consecration", 16, 70, 70, 70, 0 }, { "Seal of Righteousness", 22, 90, 110, 190, 25 },
        { "Hammer of the Righteous", 8, 320, 380, 640, 25 }, { "@miss", 1 }, { "@dodge", 1 }, { "@parry", 1 }, { "@block", 1 },
    },
}
function S.DemoSet(class)
    return S.DEMO_SETS[class or ""] or S.DEMO_SETS.WARRIOR
end

-- Timeline: a 2.5 s burst starting at once, of ~9 slots/s picked from the class set
-- by weight (deterministic credit round robin, so rare skills still show up). Each entry: t, f (0..1
-- through the burst, nil before it), sn (spell name or nil), res (event table, reused every run).
function S.BuildDemo(class)
    local set = S.DemoSet(class)
    local list, n = {}, 0
    local t0
    local function add(t, kind, amount, sn)
        n = n + 1
        list[n] = { t = t, sn = sn, res = { kind = kind, amount = amount } }
        if t0 then list[n].f = (t - t0) / S.DEMO_BURST_LEN end
    end
    t0 = 0
    local total = 0
    local credit, uses, critAcc = {}, {}, {}
    for i = 1, table.getn(set) do
        total = total + set[i][2]
        credit[i], uses[i], critAcc[i] = 0, 0, 60
    end
    local count = 22
    -- every word of the set is guaranteed to appear once, spread over the burst
    local forced, words = {}, {}
    for i = 1, table.getn(set) do
        if set[i][1] and string.sub(set[i][1], 1, 1) == "@" then table.insert(words, i) end
    end
    local nw = table.getn(words)
    for j = 1, nw do forced[3 + math.floor((j - 1) * (count - 4) / nw)] = words[j] end
    for slot = 1, count do
        local t = t0 + (slot - 1) * S.DEMO_BURST_LEN / count
        local best = 1
        for i = 1, table.getn(set) do
            credit[i] = credit[i] + set[i][2]
            if credit[i] > credit[best] then best = i end
        end
        credit[best] = credit[best] - total
        if forced[slot] then best = forced[slot] end
        local d = set[best]
        uses[best] = uses[best] + 1
        local word = d[1] and string.sub(d[1], 1, 1) == "@" and string.sub(d[1], 2)
        if word then
            add(t, word, 0)
        else
            local crit = false
            local rate = d[6] or 0
            if rate > 0 then
                critAcc[best] = critAcc[best] + rate
                if critAcc[best] >= 100 then critAcc[best] = critAcc[best] - 100; crit = true end
            end
            local amount = crit and d[5] or ((math.mod(uses[best], 2) == 1) and d[3] or d[4])
            add(t, crit and "crit" or "hit", amount, d[1])
            if not d[1] and d[7] and uses[best] == 2 then   -- an extra attack in the same frame
                for _ = 1, d[7] do add(t, "hit", d[3], nil) end
            end
        end
    end
    return list, n, list[n].t + 1.5
end

if CreateFrame then
    local W = AnySCT_W
    local C = AnySCT_Core
    local P = AnySCT_Plates

    local POOL_MAX = 100    -- slot tables only; FontStrings are created on first use (ensureFs)
    local critAnimated = S.CurveAnimated(STYLE.critKeyframes)
    local critActive = S.CurveActive(STYLE.critKeyframes)
    local avgHit = {}           -- per source: running average hit, for the crit pop scale
    local critPeak = S.CritPeak(STYLE.critKeyframes)
    local GAP = 3               -- px between the plate top and the text

    local anchor, float, listLabel
    local moveMode = false
    local activeCount = 0

    local slots = {}
    local freeStack, freeTop = {}, 0
    for i = 1, POOL_MAX do
        slots[i] = { active = false, fs = nil, sfx = nil, t = 0, dur = 1.5, rise = 120, dir = 1,
                     dx = 0, push = 0, base = 24, crit = false, key = nil, fadeOut = 1,
                     plate = nil, guidNorm = nil, lastX = nil, lastY = nil, lastW = 0, lastH = 0 }
        freeTop = freeTop + 1
        freeStack[freeTop] = i
    end

    local function opt(key) return C.Opt(key) end

    local function setFont(fs, size)
        fs:SetFont(S.FontPath(opt("font")), size)   -- no outline: the engine text uses a shadow
    end

    local function applyMoveVisuals()
        if moveMode then
            anchor:EnableMouse(true)
            anchor:SetBackdropColor(0.05, 0.08, 0.12, 0.8)
            anchor:SetBackdropBorderColor(0.9, 0.78, 0.49, 1)
        else
            anchor:EnableMouse(false)
            anchor:SetBackdropColor(0, 0, 0, 0)
            anchor:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    local dragging = false

    -- UIParent's rect in the same coordinate system as the anchor's (see C.AnchorPosFromCenter).
    function S.ScreenRect()
        local l, b, r, t = UIParent:GetLeft(), UIParent:GetBottom(), UIParent:GetRight(), UIParent:GetTop()
        if not (l and b and r and t) then
            l, b, r, t = 0, 0, UIParent:GetWidth(), UIParent:GetHeight()
        end
        return l, b, r, t
    end

    function S.IsDragging() return dragging end

    local function placeAnchor()
        local pos = opt("pos") or AnySCT_DEFAULTS.pos
        anchor:ClearAllPoints()
        anchor:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x, pos.y)
    end

    local onUpdate, followUpdate

    local function build()
        if anchor then return anchor end
        -- container of every floating line; SetClampedToScreen is a second safety net
        float = CreateFrame("Frame", "AnySCTFloat", UIParent)
        float:SetAllPoints(UIParent)
        float:SetFrameStrata("HIGH")
        float:EnableMouse(false)
        float:SetClampedToScreen(true)

        local a = CreateFrame("Frame", "AnySCTAnchor", UIParent)
        a:SetWidth(S.ANCHOR_W)
        a:SetHeight(S.ANCHOR_H)
        a:SetFrameStrata("HIGH")
        a:SetFrameLevel(10)
        a:SetMovable(true)
        a:EnableMouse(false)
        a:SetClampedToScreen(true)
        a:RegisterForDrag("LeftButton")
        a:SetBackdrop(W.SOLID_BACKDROP)
        a:SetScript("OnDragStart", function()
            if moveMode then
                dragging = true
                this:StartMoving()
            end
        end)
        a:SetScript("OnDragStop", function()
            this:StopMovingOrSizing()
            dragging = false
            local cx, cy = this:GetCenter()
            if not cx then return end
            local l, b, r, t = S.ScreenRect()
            C.SetOpt("pos", C.AnchorPosFromCenter(cx, cy, (l + r) / 2, (b + t) / 2))
        end)
        anchor = a

        listLabel = a:CreateFontString("AnySCTLabel", "OVERLAY")
        W.ApplyFont(listLabel, 11, "OUTLINE")
        listLabel:SetPoint("BOTTOM", a, "TOP", 0, 2)
        placeAnchor()
        a:Show()
        applyMoveVisuals()
        S.UpdateLabel()
        return a
    end
    S.Build = build

    function S.UpdateLabel()
        if not anchor then return end
        if not opt("showLabel") then listLabel:Hide() return end
        listLabel:Show()
        local st = C.state
        if table.getn(st.order) == 0 then
            listLabel:SetText("targetSCTs: none")
            listLabel:SetTextColor(0.55, 0.55, 0.55)
        else
            listLabel:SetText("targetSCTs: " .. table.concat(st.order, ", "))
            listLabel:SetTextColor(1, 1, 1)
        end
    end

    -- ---- pool ---------------------------------------------------------------------------------
    local function ensureFs(i)
        local s = slots[i]
        if s.fs then return end
        s.fs = float:CreateFontString("AnySCTNum" .. i, "OVERLAY")
        s.sfx = float:CreateFontString("AnySCTSfx" .. i, "OVERLAY")
    end

    -- Free slot; at a cap (total maxLines, or maxLinesPerTarget lines of one mob) the oldest
    -- matching line is recycled. key identifies the mob (guid, name, or "anchor").
    local function acquire(key)
        local maxLines = opt("maxLines") or STYLE.maxLines
        if maxLines > POOL_MAX then maxLines = POOL_MAX end
        local perTarget = opt("maxLinesPerTarget") or STYLE.maxPerTarget
        local same = 0
        for i = 1, POOL_MAX do
            if slots[i].active and slots[i].key == key then same = same + 1 end
        end
        if same < perTarget and freeTop > 0 and activeCount < maxLines then
            local i = freeStack[freeTop]
            freeStack[freeTop] = nil
            freeTop = freeTop - 1
            activeCount = activeCount + 1
            return i
        end
        local oldest, oldestT = 1, -1
        for i = 1, POOL_MAX do
            local sl = slots[i]
            if sl.active and (same < perTarget or sl.key == key) and sl.t > oldestT then
                oldestT = sl.t; oldest = i
            end
        end
        return oldest
    end

    local function release(i)
        freeTop = freeTop + 1
        freeStack[freeTop] = i
        activeCount = activeCount - 1
    end

    onUpdate = function()
        local dt = arg1
        local any = false
        local margin = opt("edgeMargin") or 40
        local xo, yo = opt("xOffset") or 0, opt("yOffset") or 0
        local needScan = false
        for i = 1, POOL_MAX do
            local s = slots[i]
            if s.active then
                s.t = s.t + dt
                if s.t >= s.dur then
                    s.active = false
                    s.fs:Hide()
                    s.sfx:Hide()
                    release(i)
                else
                    any = true
                    local t = s.t
                    local a = 1
                    if t < STYLE.fadeIn then a = t / STYLE.fadeIn end
                    if t > s.fadeOut then a = a * (s.dur - t) / (s.dur - s.fadeOut) end
                    local rise = s.rise
                    -- crits rise with the tower like every other line: a line that stood still would
                    -- let the newer, rising lines below it run into it
                    if s.crit then
                        if critAnimated then
                            s.fs:SetTextHeight(s.base * S.KeyScale(STYLE.critKeyframes, t / s.dur))
                        end
                    end
                    local off = S.LineOffset(t, s.dur, rise, s.push) * s.dir
                    s.fs:ClearAllPoints()
                    if s.plate then
                        needScan = true
                        P.FollowLine(s)
                        local x, y = s.lastX + xo + s.dx, s.lastY + GAP + yo + off
                        if not (s.lastX >= margin and s.lastX <= s.lastW - margin
                            and s.lastY >= margin and s.lastY <= s.lastH - margin) then
                            x, y = AnySCT_ClampToScreen(x, y, s.lastW, s.lastH, margin)
                        end
                        -- a tall stack of a burst never leaves the screen at the top
                        if y > s.lastH - margin then y = s.lastH - margin end
                        s.fs:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y)
                    else
                        if s.dir < 0 then
                            s.fs:SetPoint("TOP", anchor, "BOTTOM", s.dx, off - 2)
                        else
                            s.fs:SetPoint("BOTTOM", anchor, "TOP", s.dx, off + S.AnchorLineOffset(opt("showLabel")))
                        end
                    end
                    s.fs:SetAlpha(a)
                    s.fs:SetShadowColor(0, 0, 0, a)
                    s.sfx:SetAlpha(a)
                end
            end
        end
        if needScan then P.Scan(false) end    -- 0.2 s cadence, keeps the scan generation moving
        if not any then float:SetScript("OnUpdate", nil) end
    end

    -- Spawn one line. mode/plate/px.. come from P.Select (mode 3 = fixed anchor).
    local function spawn(res, mode, plate, px, py, pw, ph)
        local o = C.Opts()
        local key = res.mobGuid or res.mobName or "anchor"
        if mode == 3 then key = "anchor" end
        local isWord0 = S.IsWordResult(res, o)
        if o.mergeHits ~= false then
            local window = o.mergeWindow or 0.4
            for j = 1, POOL_MAX do
                local m = slots[j]
                if m.active and S.MergeMatches(m, res, key, isWord0, window) then
                    -- fold into the live line: same position and fade, only the text changes
                    if not isWord0 then
                        m.mSum = m.mSum + (res.amount or 0)
                        m.mCount = m.mCount + 1
                        local a0 = res.amount
                        res.amount = m.mSum
                        local text = S.Format(res, o, mode)
                        res.amount = a0
                        text = S.MergeLabel(text, m.mCount, o.mergeCount)
                        if text ~= m.mText then
                            m.mText = text
                            m.fs:SetText(text)
                        end
                    end
                    C.Ledger(res, "merged")
                    return
                end
            end
        end
        local i = acquire(key)
        local s = slots[i]
        s.mKey, s.mWord, s.mCls, s.mSrc, s.mPet = key, isWord0, S.MergeClass(res), res.source, res.srcPet
        s.mSpell, s.mHealer = res.spellId or res.spell, res.healer
        s.mSum, s.mCount = res.amount or 0, 1
        C.Ledger(res, s.active and "shown+recycled" or "shown")
        s.key = key
        ensureFs(i)
        local text, ckey, isWord, mul, suffix = S.Format(res, o, mode)
        local fs, sfx = s.fs, s.sfx

        local sw, sh = GetScreenWidth(), GetScreenHeight()
        s.crit = (res.kind == "crit") or (res.crit and true or false)
        local scale = s.crit and STYLE.critSizeScale or STYLE.sizeScale
        local factor = isWord and (o.wordFactor or 1) or (o.sizeFactor or 1)
        local base = S.TextSize(scale, factor, sw, sh)
        s.base = base * mul

        -- tiny crits (procs) pop smaller: scale by the amount against the source's running average hit
        local refKey = res.source or "?"
        if not isWord and res.kind ~= "heal" then
            if s.crit then s.base = s.base * S.CritFactor(res.amount, avgHit[refKey]) end
            avgHit[refKey] = S.UpdateRef(avgHit[refKey], res.amount or 0)
        end
        s.sfxH = S.SuffixHeight(s.base, suffix ~= nil)

        -- older lines of the same mob make room for this line's real height (crit peak included) plus
        -- the suffix hanging below the line right above it
        local prevSfx, prevT = 0, nil
        for j = 1, POOL_MAX do
            local m = slots[j]
            if m.active and m.key == key and j ~= i and (not prevT or m.t < prevT) then
                prevT, prevSfx = m.t, m.sfxH or 0
            end
        end
        local adv = S.StackAdvance(s.base, s.crit, critPeak, prevSfx)
        for j = 1, POOL_MAX do
            if slots[j].active and slots[j].key == key and j ~= i then slots[j].push = slots[j].push + adv end
        end

        s.active = true
        s.t = 0
        s.push = 0
        s.dur = STYLE.lifetime
        s.rise = o.riseHeight or STYLE.riseHeight
        s.dir = (o.direction == "down") and -1 or 1
        local jt = o.jitter or 0
        if jt > 0 then s.dx = math.random(-jt, jt) else s.dx = 0 end
        if isWord then
            s.fadeOut = (res.kind == "absorb") and STYLE.fadeOutAbsorb or STYLE.fadeOutWord
        elseif s.crit then
            s.fadeOut = STYLE.fadeOutCrit
        else
            s.fadeOut = STYLE.fadeOutNumber
        end
        if mode == 3 then
            s.plate, s.guidNorm, s.valid = nil, nil, false
        else
            s.plate = plate
            s.guidNorm = res.mobGuid and C.NormGuid(res.mobGuid) or nil
            s.lastX, s.lastY, s.lastW, s.lastH = px, py, pw, ph
            s.gen, s.valid = P.gen, true
        end

        local dxs, dys = STYLE.shadow * sw, STYLE.shadow * sh
        setFont(fs, s.base)
        if s.crit and critActive then
            fs:SetTextHeight(s.base * S.KeyScale(STYLE.critKeyframes, 0))
        else
            fs:SetTextHeight(s.base)
        end
        fs:SetShadowOffset(dxs, -dys)
        local cr, cg, cb = S.PickColour(res, o, ckey)
        fs:SetTextColor(cr, cg, cb)
        fs:SetText(text)
        s.mText = text
        fs:SetAlpha(0)
        fs:SetShadowColor(0, 0, 0, 0)
        fs:Show()

        if suffix then
            sfx:SetFont(S.FontPath(o.font), math.max(10, math.floor(s.base * 0.3)))
            sfx:SetShadowOffset(dxs, -dys)
            sfx:SetShadowColor(0, 0, 0, 1)
            sfx:SetTextColor(cr, cg, cb)
            sfx:SetText(suffix)
            sfx:ClearAllPoints()
            sfx:SetPoint("TOP", fs, "BOTTOM", 0, 0)
            sfx:SetAlpha(0)
            sfx:Show()
        else
            sfx:Hide()
        end
        float:SetScript("OnUpdate", onUpdate)
    end

    function S.Show(res)
        if not res then return end
        build()
        local o = C.Opts()
        local plate
        if o.placement ~= "anchor" and (res.mobGuid or res.mobName) then
            plate = P.Find(res.mobGuid, res.mobName, res.mobUnit)
        end
        local mode, px, py, pw, ph, also = P.Places(plate, o)
        if C.debug then
            C.Dbg("place " .. tostring(res.mobName) .. ": " .. (plate and "plate found" or "no plate")
                .. ", mode " .. tostring(mode) .. (mode == 0 and " (hidden by option)" or ""))
        end
        if mode == 0 then
            C.Ledger(res, "dropped:placement")
            return
        end
        spawn(res, mode, plate, px, py, pw, ph)
        if also then spawn(res, 3) end     -- "Nameplate + anchor": a second, separately capped stack
    end

    function S.OptionChanged(key)
        if not anchor then return end
        if (key == "all" or key == "pos") and not dragging then placeAnchor() end
        S.UpdateLabel()
    end

    -- ---- GO / WAIT threat label ------------------------------------------------------------------
    -- ONE label over the nameplate of the PLAYER's target. core.lua decides status and numbers
    -- (C.ThreatDecide); this only draws. The follow OnUpdate is attached only while the label is shown.
    local TL = { fs = nil, shown = false, plate = nil, status = nil, text = nil, lastText = nil,
                 lastMode = 0, lastName = nil, mobName = nil, guid = nil }
    local TL2 = { fs = nil, lastText = nil, lastMode = 0, lastName = nil }   -- anchor copy ("both")
    local followFrame
    local findAcc = 0

    -- status nil hides the label.
    function S.SetThreat(status, buffer, need, srcName)
        if not anchor then return end
        if not status then
            if TL.shown then
                TL.shown = false
                if TL.fs then TL.fs:Hide() end
                if TL2.fs then TL2.fs:Hide() end
            end
            if followFrame then followFrame:SetScript("OnUpdate", nil) end
            return
        end
        if not TL.fs then
            TL.fs = float:CreateFontString("AnySCTThreatLabel", "OVERLAY")
            TL.fs:SetFont(S.FontPath(opt("font")), 14, "OUTLINE")
        end
        TL.status = status
        TL.text = S.ThreatText(status, buffer, need, srcName, nil)
        TL.shown = true
        findAcc = 1                      -- look the plate up on the next frame
        if not followFrame then followFrame = CreateFrame("Frame", "AnySCTFollowFrame", UIParent) end
        followFrame:SetScript("OnUpdate", followUpdate)
    end

    -- Draw the label fs (state record L) for a placement mode; text and font change only on change.
    local function drawLabel(L, fs, mode, px, py, pw, ph, margin, lift)
        local size = (mode == 3) and S.ANCHOR_LABEL_SIZE or S.PLATE_LABEL_SIZE
        if size ~= L.size then
            L.size = size
            fs:SetFont(S.FontPath(opt("font")), size, "OUTLINE")
            L.lastText = nil
        end
        local name = (mode == 3) and TL.mobName or nil
        if TL.text ~= L.lastText or mode ~= L.lastMode or name ~= L.lastName then
            L.lastText, L.lastMode, L.lastName = TL.text, mode, name
            fs:SetText(name and (name .. ": " .. TL.text) or TL.text)
            if TL.status == "GO" then fs:SetTextColor(0.2, 1, 0.2) else fs:SetTextColor(1, 0.6, 0.1) end
        end
        fs:ClearAllPoints()
        if mode == 3 then
            fs:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        else
            local x, y = px, py + lift
            if mode == 2 then x, y = AnySCT_ClampToScreen(x, y, pw, ph, margin) end
            fs:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y)
        end
        fs:Show()
    end

    followUpdate = function()
        if not TL.shown then return end
        findAcc = findAcc + arg1
        local o = C.Opts()
        if findAcc >= 0.5 then
            findAcc = 0
            TL.plate = nil
            TL.mobName = UnitName("target")
            TL.guid = C.ResolveGuid("target")
            if o.placement ~= "anchor" and not TL.forceAnchor then TL.plate = P.Find(TL.guid, TL.mobName, "target") end
        end
        local margin = o.edgeMargin or 40
        local lift = S.TextSize(STYLE.sizeScale, o.sizeFactor or 1, GetScreenWidth(), GetScreenHeight()) + 6
        local mode, px, py, pw, ph, also = P.Places(TL.plate, o)
        if mode == 0 then
            TL.fs:Hide()
            if TL2.fs then TL2.fs:Hide() end
            return
        end
        drawLabel(TL, TL.fs, mode, px, py, pw, ph, margin, lift)
        if also then
            if not TL2.fs then
                TL2.fs = float:CreateFontString("AnySCTThreatLabel2", "OVERLAY")
                TL2.fs:SetFont(S.FontPath(opt("font")), S.ANCHOR_LABEL_SIZE, "OUTLINE")
            end
            drawLabel(TL2, TL2.fs, 3, nil, nil, nil, nil, margin, lift)
        elseif TL2.fs then
            TL2.fs:Hide()
        end
    end

    -- ---- demo / move / memory ------------------------------------------------------------------
    -- Fixed sequence for side-by-side comparison with the player's own real numbers, then the burst.
    local demoCache = {}
    local DEMO, DEMO_N, DEMO_END
    local demoIdx, demoT, demoTicker, demoAtAnchor = 1, 0, nil, false
    local dSrc, dClass, dRgb, dMulti, dVictim = nil, nil, nil, false, nil

    local function demoOnUpdate()
        demoT = demoT + arg1
        local showName = opt("showSpellName")
        while demoIdx <= DEMO_N and DEMO[demoIdx].t <= demoT do
            local e = DEMO[demoIdx]
            local res = e.res
            demoIdx = demoIdx + 1
            -- same fields a real event carries (C.Emit), so every display setting applies
            res.source, res.srcRgb, res.srcMulti, res.class = dSrc, dRgb, dMulti, dClass
            res.spell = (e.sn and showName) and e.sn or nil
            res.spellId = e.sn and 1 or nil
            res.mobGuid, res.mobName, res.mobUnit = nil, dVictim, nil
            if not demoAtAnchor and UnitExists("target") then
                res.mobGuid = C.ResolveGuid("target")
                res.mobName = UnitName("target")
                res.mobUnit = "target"
                S.Show(res)
            else
                spawn(res, 3)
            end
            if e.f then
                -- the GO / WAIT preview rides the burst (real label code path, even with threatGo off)
                local status, buf, need = S.DemoThreat(e.f, opt("threatGoLead"))
                S.SetThreat(status, buf, need, C.ThreatSrcName and C.ThreatSrcName(dSrc))
            end
        end
        if demoT >= DEMO_END then
            TL.forceAnchor = false
            S.SetThreat(nil)
            this:SetScript("OnUpdate", nil)
        end
    end

    -- /asct demo plays at the nameplate of the current target (the same placement rules as real
    -- events); without a target, or with atAnchor, at the fixed anchor. A second call restarts it.
    function S.Demo(atAnchor)
        build()
        demoIdx, demoT = 1, 0
        demoAtAnchor = atAnchor and true or false
        dSrc, dClass, dRgb, dMulti = S.DemoSource(C.state)
        dVictim = UnitExists("target") and UnitName("target") or S.DEMO_VICTIM
        local key = S.DEMO_SETS[dClass or ""] and dClass or "WARRIOR"
        if not demoCache[key] then
            local l, n, e = S.BuildDemo(key)
            demoCache[key] = { l, n, e }
        end
        DEMO, DEMO_N, DEMO_END = demoCache[key][1], demoCache[key][2], demoCache[key][3]
        TL.forceAnchor = demoAtAnchor
        S.SetThreat(nil)
        if not demoTicker then demoTicker = CreateFrame("Frame", "AnySCTDemoFrame", UIParent) end
        demoTicker:SetScript("OnUpdate", demoOnUpdate)
    end

    function S.FontStringCount()
        local n = 1   -- the targetSCT list label
        for i = 1, POOL_MAX do
            if slots[i].fs then n = n + 2 end
        end
        if TL.fs then n = n + 1 end
        return n
    end

    -- /asct mem: gcinfo() is KB in use. Phase 1: 10 s idle. Phase 2: a demo burst.
    local memFrame, memPhase, memT, memStart = nil, 0, 0, 0
    function S.Mem()
        build()
        if not memFrame then memFrame = CreateFrame("Frame", "AnySCTMemFrame", UIParent) end
        C.Print("memory now " .. gcinfo() .. " KB, " .. S.FontStringCount() .. " FontStrings; measuring 10 s idle ...")
        memPhase, memT, memStart = 1, 0, gcinfo()
        memFrame:SetScript("OnUpdate", function()
            memT = memT + arg1
            if memPhase == 1 and memT >= 10 then
                C.Print("idle 10 s: " .. (gcinfo() - memStart) .. " KB change; starting demo burst ...")
                memPhase, memT, memStart = 2, 0, gcinfo()
                S.Demo(true)
            elseif memPhase == 2 and memT >= 7 then
                C.Print("demo burst: " .. (gcinfo() - memStart) .. " KB change; now " .. gcinfo()
                    .. " KB, " .. S.FontStringCount() .. " FontStrings")
                memPhase = 0
                this:SetScript("OnUpdate", nil)
            end
        end)
    end

    function S.SetMoveMode(on)
        build()
        moveMode = on and true or false
        applyMoveVisuals()
        if moveMode then
            S.Demo(true)
            C.Print("anchor unlocked: drag the box, then /anysct lock")
        else
            C.Print("anchor locked")
        end
        if AnySCT_Options and AnySCT_Options.refresh then AnySCT_Options.refresh() end
    end

    function S.IsMoveMode() return moveMode end
    function S.ToggleMove() S.SetMoveMode(not moveMode) end
end
