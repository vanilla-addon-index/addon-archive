# Performance

## TL;DR

- Simple animations (fades, slides, toasts) allocate **1-15 kB** each. Particle bursts go up to **130-370 kB**.
- Per-tick garbage is negligible (~1 kB over an animation's entire lifetime). Construction dominates.
- CPU cost: **~0.01 ms per active tween per tick**. 300 concurrent tweens used 18% of a 60fps frame budget in my test.
- Driver frame hides when idle, so no CPU cost when nothing is animating.
- I built a PizzaSauce FCT test addon and tested it vs MikScrollingBattleText over 3 min: comparable garbage (~65 vs ~70 MB), no observed stutters. But this was solo on a training dummy, not in a raid.
- For high-frequency use (combat text, rapid proc alerts), there's a [reuse pattern](#optimizing-for-memory-the-reuse-pattern) that avoids repeated construction.
- All measurements on a single machine, single client, not under raid load. See [caveats](#what-i-didnt-test).

## How I measured

**Memory:** `gcinfo()` before and after each construction, 500 iterations per test, `collectgarbage()` between every iteration to prevent heap buildup from skewing results. `gcinfo()` returns kB as integers in Lua 5.0, so there's inherent 1 kB granularity - at 500 iterations this averages out well enough. All 500 iterations registered positive deltas (zero missed), so GC interference wasn't a factor.

**CPU:** Hooked PizzaSauce's driver frame `OnUpdate` by wrapping the original with `debugprofilestart()`/`debugprofilestop()`. Measured over 3 seconds with 300 concurrent tweens running. This measures exactly PizzaSauce's tick function and nothing else.

**Environment:** TurtleWoW client (1.12-based, v1.18.0), full addon suite loaded, not in combat.

## Memory: construction cost

Every animation allocates memory when you construct it. This is the main cost. Per-tick garbage is negligible (~1 kB over an animation's entire lifetime) because the hot path does no allocations - interpolation is inlined, finished-animation bookkeeping uses a reusable scratch buffer.

### Simple animations (500 iterations)

| Animation | Per-construction |
|-----------|-----------------|
| Tween (alpha) | ~1.0 kB |
| Tween (position) | ~1.1 kB |
| FadeIn | ~1.5 kB |
| FadeOut | ~1.9 kB |
| SlideIn | ~3.2 kB |
| Seq(FadeIn, FadeOut) | ~4.3 kB |
| Bounce | ~7.9 kB |
| Shake | ~13.3 kB |
| Toast (slide + scale + typewriter + fade) | ~14.6 kB |

### Particle effects (500 iterations)

| Scenario | Total | Per-particle |
|----------|-------|--------------|
| Confetti burst (40 Ballistic + FadeTo) | ~136 kB | ~3.4 kB |
| Firework burst (80 Ballistic + FadeTo) | ~270 kB | ~3.4 kB |
| Black hole (50 particles, 4 tweens each) | ~371 kB | ~7.4 kB |

These numbers include the `table.insert` loop and the outer Group that wraps everything, not just PizzaSauce internals. That's intentional - it's what you'd actually write.

### What this means

**Normal UI stuff** (toasts, fades, slides, status bars): 1-15 kB per animation. Fire one every second and you're generating 1-15 kB/s of garbage. For reference, in my testing the idle garbage rate from other addons was around 30 kB/s, so this is small relative to that - but your addon suite and hardware are different, so take that comparison with a grain of salt.

**Particle bursts** (confetti, fireworks, shatter fragments): 130-370 kB as a one-time spike when the burst fires. It gets collected after the particles fade out. For occasional effects this is probably fine, but if you're firing particle bursts every few seconds in a loop, the spikes add up. Consider reducing particle count or using the reuse pattern below.

**High-frequency repeated construction** (floating combat text, rapid proc alerts): This is where construction cost starts to matter. Combat text might spawn 5-10 animations per second during intense combat. At ~6 kB per normal hit and ~36 kB per crit, that's 30-360 kB/s sustained over minutes-long fights. I tested this against MikScrollingBattleText over 3 minutes on a training dummy (fast-attacking rogue): PizzaSauce FCT produced ~70 MB of garbage vs MSBT's ~65 MB. I didn't observe any GC freezes or micro-stutters in either case, but this was solo on a dummy, not in a raid. This is the scenario most likely to benefit from the reuse pattern.

## CPU

300 concurrent tweens (100 frames, each with position + alpha + size):

| Metric | Value |
|--------|-------|
| Avg tick time | 3.0 ms |
| Min tick time | 2.9 ms |
| Max tick time | 9.2 ms |
| Per-tween cost | ~0.01 ms |
| % of 60fps frame budget | 18% |

The 9.2 ms max was the first tick (type init handlers capturing anchors, etc.). Steady state stays around 3 ms.

300 concurrent tweens is more than most addons would run. I'd guess a typical addon has 5-20 active at a time, which would extrapolate to ~0.2 ms per tick, roughly 1.2% of a 60fps frame budget. That said, I only measured at 300 - the per-tween cost might not scale linearly down to small counts.

When idle, the driver frame hides itself and `OnUpdate` doesn't fire, so there should be no CPU cost when nothing is animating.

### Caveats

The test frames were trivial 4x4 pixel squares. The PizzaSauce tick itself (interpolation, easing lookup, setting the value) is what I measured. But each tick also calls WoW API functions like `ClearAllPoints()` + `SetPoint()` for position tweens, `SetWidth()`/`SetHeight()` for size tweens, etc. The cost of those API calls on real frames (with children, textures, font strings) could be different. I didn't isolate that.

I also didn't test performance during actual heavy gameplay (raids, large battlegrounds) where the client is already under load. All measurements were done standing still with no combat happening (except the FCT comparison, which was on a training dummy).

## What I didn't test

- **Performance under real raid conditions.** The combat text comparison was solo on a training dummy. A 40-man raid with 20 addons competing for frame time is a different story. I don't have numbers for that.
- **Frame creation cost.** Particle effects don't just construct animations, they also create WoW frames and textures. `CreateFrame()` and `CreateTexture()` have their own costs that have nothing to do with PizzaSauce. If you're spawning 80 frames per firework burst, that's potentially more expensive than the animations themselves. I didn't separate these.
- **Long-running sessions.** I tested 3-minute combat windows. I don't know if there are slow leaks or accumulation effects over hour-long play sessions.
- **Interaction with GC pauses.** I observed no stutters, but I didn't measure GC pause duration directly. The WoW 1.12 client's garbage collector is incremental-ish, but large heaps can cause longer collection pauses that I wouldn't catch with this measurement approach.

## Optimizing for memory: the reuse pattern

If you're constructing the same animation over and over (combat text, proc alerts), you can build the animation tree once and replay it without allocating.

### How it works

Every Tween, Sequence, and Group has a `:Play()` method that resets internal state and replays from the beginning. The idea: build your animation tree once at load time with `defer = true`, keep references to tweens whose values need to change between replays, update them via setter methods, then call `:Play()` on the root.

### Simple case: nothing changes between replays

```lua
-- Build once
local fadeAnim = Sauce:FadeTo(myFrame, 0, 0.5, nil, { defer = true })

-- Replay whenever (zero allocation)
fadeAnim:Play()
```

### When values change between replays

Tweens have setter methods for updating values between replays:

- `tween:SetFrom(val)` - start value
- `tween:SetTo(val)` - end value
- `tween:SetDuration(val)` - how long
- `tween:SetDelay(val)` - delay before start
- `tween:SetTarget(val)` - the frame/texture being animated

For table-valued types (position `{ x, y }`, color `{ r, g, b, a }`), modify values inside the existing table rather than passing a new one. Reusing the same table avoids allocation.

```lua
-- Build once
local pos = { 100, 50 }
local slideTween = Sauce:Tween(myFrame, {
  type = "position",
  from = { 0, 0 },
  to = pos,
  duration = 0.5,
  defer = true,
})

-- Replay with different values (zero allocation)
pos[1] = 200
pos[2] = -30
slideTween:Play()
```

### Full example: reusable combat text pool

```lua
local pool = {}
local POOL_SIZE = 20

for i = 1, POOL_SIZE do
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetWidth(1) frame:SetHeight(1)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetFont("Fonts\\FRIZQT__.TTF", 16)
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame:Hide()

  local floatFrom = { 0, 0 }
  local floatTo = { 0, 60 }
  local floatTween = Sauce:Tween(frame, {
    type = "position",
    from = floatFrom,
    to = floatTo,
    duration = 1.2,
    defer = true,
  })
  local fadeOut = Sauce:FadeTo(frame, 0, 0.4, "inQuad", {
    delay = 0.8, defer = true,
  })

  local anim = Sauce:Group({
    floatTween,
    fadeOut,
  }, {
    defer = true,
    onStart = function() frame:SetAlpha(1); frame:Show() end,
    onFinish = function() frame:Hide() end,
  })

  pool[i] = {
    frame = frame,
    text = text,
    anim = anim,
    floatFrom = floatFrom,
    floatTo = floatTo,
  }
end

local poolIndex = 0

function ShowNumber(value, x, y)
  poolIndex = poolIndex + 1
  if poolIndex > POOL_SIZE then poolIndex = 1 end

  local entry = pool[poolIndex]
  entry.text:SetText(value)

  -- Update the existing tables in-place, no new allocations
  entry.floatFrom[1] = x
  entry.floatFrom[2] = y
  entry.floatTo[1] = x + (math.random() - 0.5) * 30
  entry.floatTo[2] = y + 60

  entry.anim:Play()
end
```

### What `:Play()` does internally

On a Sequence or Group: resets internal state, then recursively resets all children. On a Tween: clears elapsed time and progress flags. When the tween actually starts playing, `_start()` re-runs the type's `init()` handler, which reads the current from/to values. So any changes you made via setter methods (or in-place table edits) between replays get picked up.

### When to bother

For most addons, probably not worth the added complexity. A few kB of allocations a couple times a second is small in the scheme of things.

It's worth considering when:
- You're spawning animations at **5+ per second**, sustained (combat text, scrolling numbers)
- You're doing **repeated particle bursts** every few seconds (proc effects with many particles)
- You're seeing GC pressure in profiling and PizzaSauce construction is showing up as a contributor

If you're unsure, build normally first. Profile if something feels off, and refactor to the reuse pattern if the numbers point to it.
