# 🍕 PizzaSauce

**Smooth, declarative animations for WoW 1.12.1 addons.**

[Showcase](SHOWCASE.md) · [Demos & Tutorial](https://codeberg.org/Pizzahawaii/PizzaSauceDemos) · [API Reference](docs/API.md) · [Performance](docs/Performance.md) · [Changelog](CHANGELOG.md)

> [!NOTE]
> **This is v0.1.0**, the first public release. The API is designed to be stable, but nobody besides me has used this in the wild yet. Try it out, build something cool, and if anything feels off or you run into rough edges, [open an issue](https://codeberg.org/Pizzahawaii/PizzaSauce/issues). I'd rather fix API problems now than carry them forever.

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/magnetize.gif" width="604"> <img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/blackhole.gif" width="604">

Vanilla WoW has no animation API. You want a frame to slide in? Cool, write an `OnUpdate` handler, track elapsed time, lerp the position, clean up after yourself. Want to chain two animations? Now you're managing state machines. Want easing? Break out the math textbook.

PizzaSauce handles all of that so you don't have to.

```lua
local Sauce = PizzaSauce

-- Fade in a frame
Sauce:FadeIn(myFrame, 0.5)

-- Chain animations together
Sauce:Sequence({
  Sauce:SlideIn(myFrame, "RIGHT", 200, 0.4, "outCubic"),
  Sauce:Pulse(myFrame, 1.4, 0.4, { delay = 0.3 }),
  Sauce:FadeOut(myFrame, 0.5),
})
```

> **[Full Showcase with GIFs](SHOWCASE.md)** if you want to see what it looks like in action.

## What's in the box

- **32 animations** - fades, slides, bounces, shakes, flips, spins, typewriter text, and more
- **32 easing functions** - the full jQuery UI set (quad, cubic, elastic, bounce, back, etc.)
- **3 composable primitives** - `Tween`, `Sequence`, `Group`
- **Auto-play** - call an animation and it plays. Nest it inside a Sequence and it defers. You don't have to think about it.
- **Built-in delay** - every animation takes a `delay` option, no wrapper needed
- **Zero idle cost** - one shared `OnUpdate` driver, hides itself when nothing is animating
- **Lightweight** - no per-tick allocations, ~0.01 ms per tween per tick. [Benchmarks and caveats](docs/Performance.md)
- **Time-based** - smooth at any framerate
- **Extensible** - register your own animation types and easing functions

## Installation

PizzaSauce is an embeddable library, not a standalone addon. You ship a copy with your addon.

1. Download `PizzaSauce.lua` from the [latest release](https://codeberg.org/Pizzahawaii/PizzaSauce/releases/latest)
2. Put it next to your addon's `.toc` file (e.g. `Interface/AddOns/MyAddon/PizzaSauce.lua`)
3. Add it to your `.toc` **before** your own files:

```
## Interface: 11200
## Title: My Addon

PizzaSauce.lua
MyAddon.lua
```

4. Grab a local reference at the top of your lua files:

```lua
local Sauce = PizzaSauce
```

> [!WARNING]
> The `PizzaSauce` global gets overwritten every time another addon loads its own copy. `local Sauce = PizzaSauce` captures your instance before that happens (and is faster too). Always do this.

### Multiple addons using PizzaSauce

Each copy of `PizzaSauce.lua` creates a fresh, isolated instance. No version guards, no shared state. Two addons can embed completely different versions and they won't interfere with each other. The global is just a handoff point.

## Examples

### One-liners

Most things you'd want to animate are a single call.

```lua
Sauce:FadeIn(myFrame, 0.5)                      -- fade from invisible to visible
Sauce:SlideIn(myFrame, "RIGHT", 200, 0.4)       -- slide in from the left
Sauce:Pulse(myFrame, 1.3, 0.4)                  -- quick scale bump
Sauce:Progress(healthBar, 0, 1.5, "outCubic")   -- smooth status bar drain
Sauce:Shake(myFrame, 6, 0.3)                    -- error feedback
```

### Chaining with Sequence

Play animations one after another. Slide a tooltip in, hold it, then dismiss it.

```lua
Sauce:Sequence({
  Sauce:SlideIn(tooltip, "DOWN", 40, 0.3, "outCubic"),
  Sauce:FadeOut(tooltip, 0.4, nil, { delay = 2.0 }),
})
```

### Parallel with Group

Run animations at the same time. Slide and fade out together for a smooth exit.

```lua
Sauce:Group({
  Sauce:SlideOut(lootFrame, "LEFT", 300, 0.4, "inCubic"),
  Sauce:FadeOut(lootFrame, 0.4),
})
```

### Staggered cascade

Animate a list of frames with a time offset between each. Great for menus, buff rows, combo points.

```lua
Sauce:Stagger(menuFrames, function(frame)
  return Sauce:ScaleIn(frame, 0.3, "outBack")
end, 0.08)
```

### Looping

Breathe a glow in and out forever until cancelled.

```lua
Sauce:Breathe(glowFrame, 0.2, 1.0, 2.0)

-- Stop whenever
Sauce:Stop(glowFrame)
```

### Custom animation types

PizzaSauce doesn't know how to animate font size out of the box, but you can teach it in a few lines. Register a type once, then use it anywhere.

```lua
Sauce:RegisterType("textheight", {
  init = function(target, from)
    return from or target:GetTextHeight()
  end,
  apply = function(target, from, to, t)
    local size = from + (to - from) * t
    target:SetTextHeight(math.max(1, size))
  end,
})

-- Now use it like any built-in type
Sauce:Tween(myText, { type = "textheight", to = 36, duration = 0.4, easing = "outElastic" })
```

Custom easings and helper functions work the same way. See [Extending PizzaSauce](docs/API.md#extending-pizzasauce) in the API docs.

## Animation Reference

| Category | Functions |
|----------|-----------|
| **Alpha** | `FadeIn` `FadeOut` `FadeTo` `Flash` `Breathe` |
| **Scale** | `ScaleIn` `ScaleOut` `Pulse` `Rubber` `Flip` |
| **Position** | `Move` `MoveTo` `SlideIn` `SlideOut` `Bounce` `Shake` `FlyTo` |
| **Rotation** | `Spin` |
| **Color** | `Color` `ColorFlash` |
| **Size** | `Size` `Morph` |
| **Value** | `Progress` |
| **Text** | `Typewriter` |
| **Clipping** | `Reveal` `Conceal` `WipeIn` `WipeOut` |
| **Meta** | `Stagger` `Delay` `Run` `Stop` |

Full details: [docs/API.md](docs/API.md)

## Composing Animations

Three primitives, nest them however you want:

- **`Tween`** - animates one property from A to B
- **`Sequence`** - runs children one after another
- **`Group`** - runs children in parallel

```lua
-- Slide + fade at the same time, then bounce
Sauce:Sequence({
  Sauce:Group({
    Sauce:SlideIn(frame, "LEFT", 100, 0.3),
    Sauce:FadeIn(frame, 0.3),
  }),
  Sauce:Bounce(frame, 20, 3, 0.5),
})
```

### Delays

Every animation takes a `delay` option. No need to wrap things in sequences just to add a pause:

```lua
Sauce:FadeIn(frame1, 0.3)
Sauce:FadeIn(frame2, 0.3, nil, { delay = 0.1 })
Sauce:FadeIn(frame3, 0.3, nil, { delay = 0.2 })
```

Inside a Sequence, `delay` on a child acts as a gap before it starts:

```lua
Sauce:Sequence({
  Sauce:FadeOut(frame, 0.3),
  Sauce:FadeIn(frame, 0.3, nil, { delay = 1.0 }),
})
```

### Auto-play

Standalone calls like `Sauce:FadeIn(...)` play immediately. Inside `Sequence` or `Group`, children defer automatically. If you want to build something now and play it later:

```lua
local anim = Sauce:FadeIn(frame, 0.5, nil, { defer = true })
-- later...
anim:Play()
```

You don't need `defer` inside `Stagger` callbacks, that's handled for you.

## Easings

32 built-in easings. Pass them by name:

```lua
Sauce:MoveTo(frame, { 100, 50 }, 0.5, "outBack")
Sauce:FadeIn(frame, 0.3, "outElastic")
```

`linear`, `swing`, `inQuad`, `outQuad`, `inOutQuad`, `inCubic`, `outCubic`, `inOutCubic`, `inQuart`, `outQuart`, `inOutQuart`, `inQuint`, `outQuint`, `inOutQuint`, `inSine`, `outSine`, `inOutSine`, `inExpo`, `outExpo`, `inOutExpo`, `inCirc`, `outCirc`, `inOutCirc`, `inElastic`, `outElastic`, `inOutElastic`, `inBack`, `outBack`, `inOutBack`, `inBounce`, `outBounce`, `inOutBounce`

Or pass a function: `function(t) return t * t end`

### Custom easings

An easing maps linear `t` (0 to 1) to a curve. Values outside 0-1 are fine, that's how elastic and back easings overshoot.

```lua
Sauce:RegisterEasing("smoothStep", function(t)
  return t * t * (3 - 2 * t)
end)
```

## Disclaimer

This project is for educational and research purposes only. It is not affiliated with or endorsed by Blizzard Entertainment. Use of this software is at your own discretion and risk.

## Building from Source

Source files live in `src/`. The build concatenates them into a single file:

```bash
./build.sh    # -> dist/PizzaSauce.lua
```
