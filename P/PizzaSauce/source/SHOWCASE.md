# PizzaSauce Showcase

Everything here runs in-game on WoW 1.12. No mockups, no external tools.

Install [PizzaSauceDemos](https://codeberg.org/Pizzahawaii/PizzaSauceDemos) and type `/psd <name>` to try any of these live.

> [!NOTE]
> The code snippets below are **simplified** to show the key animation calls clearly. The real demos layer in extra effects (glow blooms, sparkle bursts, color flashes, etc.) that make them look as polished as the GIFs. Each demo has a **View source** link to the full, runnable code.
>
> Some demos use `TextHeight`, `Ballistic`, `AlphaTo` and `ScaleTo`. These are **custom types and helpers registered in the demo addon** via [`RegisterType`](docs/API.md#registertype) and [`RegisterHelper`](docs/API.md#registerhelper), not built-in PizzaSauce functions. They're good examples of how easy it is to extend PizzaSauce for your own needs.

## UI Animations

### Cast Bar

Smooth progress fill with a tracking spark. Pulse on success, shake on interrupt.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/castbar.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:SlideIn(frame, "DOWN", 25, 0.3, "outBack"),
  Sauce:Group({
    Sauce:Progress(bar, 100, 1.8, "linear"),
    Sauce:MoveTo(spark, { 106, 0 }, 1.8, "linear"),
  }),
  -- Success
  Sauce:Pulse(frame, 1.06, 0.3),
  -- or interrupt
  Sauce:Shake(frame, 5, 0.4),
  Sauce:FadeOut(frame, 0.3),
})
```

`/psd castbar` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/09_castbar.lua)

</td></tr></table>


### Loot Notifications

Items drop in with stagger, flash white on arrival, then slide out.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/loot.gif" width="100%">

</td><td>

```lua
Sauce:Stagger(lootFrames, function(frame)
  return Sauce:Sequence({
    Sauce:SlideIn(frame, "DOWN", 50, 0.3, "outCubic"),
    Sauce:Group({
      Sauce:SlideOut(frame, "LEFT", 280, 0.35),
      Sauce:FadeOut(frame, 0.35),
    }, { delay = 1.6 }),
  })
end, 0.1)
```

`/psd loot` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/05_loot.lua)

</td></tr></table>


### Buff Row

Buff lifecycle: staggered appear, refresh pulse, expiring breathe, reverse fadeout.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/buffs.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:Stagger(buffs, function(bf)
    return Sauce:ScaleIn(bf, 0.15, "outBack")
  end, 0.05),
  -- Refresh
  Sauce:Pulse(buffs[2], 1.5, 0.35),
  -- Expiring
  Sauce:Breathe(buffs[4], 0.3, 1.0, 0.6),
  -- Reverse fadeout
  Sauce:Stagger(reversed, function(bf)
    return Sauce:Group({
      Sauce:ScaleOut(bf, 0.2, "inBack"),
      Sauce:FadeOut(bf, 0.2),
    })
  end, 0.1),
})
```

`/psd buffs` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/11_buffs.lua)

</td></tr></table>


### Combo Points

Points build up with stagger, ripple pulse at 5/5, reverse teardown.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/combo.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:Stagger(points, function(cp)
    return Sauce:ScaleIn(cp, 0.18, "outBack")
  end, 0.22),
  -- 5/5 ripple
  Sauce:Stagger(points, function(cp)
    return Sauce:Pulse(cp, 1.5, 0.32)
  end, 0.045),
  -- Reverse teardown
  Sauce:Stagger(reversed, function(cp)
    return Sauce:Group({
      Sauce:SlideOut(cp, "UP", 30, 0.28, "inBack"),
      Sauce:FadeOut(cp, 0.28),
    })
  end, 0.07),
})
```

`/psd combo` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/07_combo.lua)

</td></tr></table>


### Raid Hit Indicators

Staggered HP drain, big hit with shake and red flash, heal recovery.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/raidhit.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  -- AoE: staggered drain + shake
  Sauce:Group({
    Sauce:Progress(bars[1], 72, 0.9, "outQuad"),
    Sauce:Progress(bars[2], 85, 1.1, "outQuad"),
    Sauce:Progress(bars[3], 88, 0.8, "outQuad"),
    Sauce:Shake(container, 3, 0.35),
  }),
  -- Big hit on bar 3
  Sauce:Group({
    Sauce:Progress(bars[3], 12, 0.55, "inCubic"),
    Sauce:Shake(bars[3], 7, 0.45),
  }),
  -- Heal
  Sauce:Progress(bars[3], 100, 1.4, "outCubic"),
})
```

`/psd raidhit` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/12_raidhit.lua)

</td></tr></table>


### Floating Combat Text

Hits float up and fade. Crits pop in at 2.5x with shake. Misses fade quickly. GIF captured from a real combat text addon built on PizzaSauce.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/PizzaSauceFCT.gif" width="100%">

</td><td>

```lua
-- Normal hit
Sauce:Sequence({
  Sauce:FadeIn(frame, 0.1),
  Sauce:Group({
    Sauce:MoveTo(frame, { x, y + 48 }, 0.95, "outQuad"),
    Sauce:FadeOut(frame, 0.4, nil, { delay = 0.55 }),
  }),
})

-- Crit
Sauce:Sequence({
  Sauce:TextHeight(text, 70, 28, 0.2, "outBack"),
  Sauce:Shake(frame, 2.5, 0.8),
  Sauce:Group({
    Sauce:MoveTo(frame, { x, y + 80 }, 1.3, "outQuad"),
    Sauce:FadeOut(frame, 0.5, nil, { delay = 0.8 }),
  }),
})
```

`/psd fctlive` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/28_fctlive.lua)

</td></tr></table>


### Heartbeat Health Bar

Low-HP bar with a realistic double-pulse heartbeat rhythm. Loops until health recovers.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/heartbeat.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  -- Small beat (systole)
  Sauce:Size(bar, { w, h }, { w*1.03, h*1.15 }, 0.07, "outQuad"),
  Sauce:Size(bar, { w*1.03, h*1.15 }, { w, h }, 0.1, "inQuad"),
  Sauce:Delay(0.1),
  -- Big beat (diastole)
  Sauce:Size(bar, { w, h }, { w*1.05, h*1.3 }, 0.08, "outQuad"),
  Sauce:Size(bar, { w*1.05, h*1.3 }, { w, h }, 0.15, "inQuad"),
  Sauce:Delay(0.55),
}, { loop = 0 })
```

`/psd heartbeat` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/22_heartbeat.lua)

</td></tr></table>


## Alerts & Popups

### Boss Warning

DBM-style alert: slams in with overshoot, typewriter text, shake, pulse, urgency flash.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/bosswarn.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:SlideIn(frame, "UP", 60, 0.45, "outBack"),
  Sauce:Typewriter(text, "GET OUT OF THE FIRE!", 0.8),
  Sauce:Shake(frame, 6, 0.4),
  Sauce:Sequence({
    Sauce:Pulse(frame, 1.05, 0.4),
    Sauce:Pulse(frame, 1.05, 0.4),
    Sauce:Pulse(frame, 1.05, 0.4),
  }),
  Sauce:Flash(frame, 3, 1.2),
  Sauce:Group({
    Sauce:SlideOut(frame, "UP", 50, 0.5),
    Sauce:FadeOut(frame, 0.5),
  }),
})
```

`/psd bosswarn` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/10_bosswarn.lua)

</td></tr></table>


### Toast

Achievement popup: slide in, icon bounce with glow bloom, text fade-in, hold, dismiss.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/toast.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:SlideIn(toast, "UP", 80, 0.4, "outCubic"),
  Sauce:Group({
    Sauce:Shake(toast, 3, 0.15),
    Sauce:ScaleIn(icon, 0.3, "outBack"),
  }),
  Sauce:Delay(2.0),
  Sauce:Group({
    Sauce:SlideOut(toast, "UP", 60, 0.5),
    Sauce:FadeOut(toast, 0.5),
  }),
})
```

`/psd toast` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/08_toast.lua)

</td></tr></table>


## Particle Effects

### Level Up

Text slams in from 3x size with elastic bounce. 500 confetti particles burst outward.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/levelup.gif" width="100%">

</td><td>

```lua
-- Text slam: 3x -> 1x with elastic bounce
Sauce:TextHeight(text, 96, 32, 0.6, "outElastic")

-- Per particle: radial burst + fade
Sauce:Group({
  Sauce:Move(pf, { 0, 100 }, { tx, 100 + ty }, dur, "outCubic"),
  Sauce:AlphaTo(pf, 1, 0, dur, "inQuad"),
})
```

`/psd levelup` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/14_levelup.lua)

</td></tr></table>


### Countdown

3... 2... 1... GO! Each number slams in at 3.5x with elastic bounce. GO! triggers confetti with gravity.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/countdown.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  -- Each number: slam in huge, bounce to size
  Sauce:TextHeight(text, size*3.5, size, 0.7, "outElastic"),
  Sauce:FadeOut(frame, 0.25),
  -- ...repeat for 2, 1...
  -- GO! with confetti burst
  Sauce:Group({
    Sauce:TextHeight(text, size*4, size*1.5, 0.8, "outElastic"),
    Sauce:Shake(frame, 5, 0.35),
    Sauce:Group(confettiAnims),
  }),
})
```

`/psd countdown` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/19_countdown.lua)

</td></tr></table>


### Fireworks

Rockets launch upward one by one. Each explodes into 80 sparks with gravity and a bloom flash.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/fireworks.gif" width="100%">

</td><td>

```lua
-- Rocket launch
Sauce:Move(rocket, { x, -50 }, { x, 250 }, 0.6, "outCubic")

-- Per spark: ballistic arc + fade
Sauce:Group({
  Sauce:Ballistic(spark, { x, y }, dur, vx, vy, 220),
  Sauce:FadeTo(spark, 0, 0.5, "inQuad",
    { delay = dur - 0.5 }),
})
```

`/psd fireworks` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/15_fireworks.lua)

</td></tr></table>


### Shatter

Icon pops in, tension builds with escalating shake, then explodes into 64 fragments with gravity.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/shatter.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:Size(icon, { 4, 4 }, { 80, 80 }, 0.35, "outBack"),
  -- Escalating shake + red tint
  Sauce:Tween(icon, {
    type = "custom", from = 0, to = 1,
    duration = 1.2, easing = "inQuad",
    setter = function(_, v) shake(v * 8) end,
  }),
  -- 8x8 fragment burst with gravity
  Sauce:Group(fragmentAnims),
})
```

`/psd shatter` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/16_shatter.lua)

</td></tr></table>


### Shockwave

Bomb drops toward ground, impact flash, three expanding rings of particle dots.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/shockwave.gif" width="100%">

</td><td>

```lua
Sauce:Sequence({
  Sauce:Size(bomb, { 80, 120 }, { 2, 3 }, 3.5, "outCubic"),
  -- Impact: flash + 3 staggered particle rings
  Sauce:Group({
    Sauce:Sequence({
      Sauce:Color(flash, { 1, 1, 1, 0 }, { 1, 1, 1, 0.35 }, 0.03),
      Sauce:Color(flash, { 1, 1, 1, 0.35 }, { 1, 1, 1, 0 }, 0.2, "outQuad"),
    }),
    Sauce:Group(dotAnims),
  }),
})
```

`/psd shockwave` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/27_shockwave.lua)

</td></tr></table>


### Black Hole

200 particles spiral inward using a custom type. Accelerate, shrink, and brighten as they fall in.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/blackhole.gif" width="100%">

</td><td>

```lua
-- Per particle
Sauce:Group({
  Sauce:Tween(pf, {
    type = "spiral", from = 0, to = 1,
    duration = dur, easing = "inQuad",
    cx = 0, cy = 100, radius = radius,
    startAngle = angle, rotations = 2.5,
  }),
  Sauce:Size(pf, { s, s }, { 2, 2 }, dur, "inQuad"),
  Sauce:FadeTo(pf, 0, dur * 0.3, "inQuad",
    { delay = dur * 0.7 }),
})
```

`/psd blackhole` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/20_blackhole.lua)

</td></tr></table>


## Creative

### Magnetize

Items scatter with staggered fade-in, then fly to grid positions with outBack overshoot and elastic snap.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/magnetize.gif" width="100%">

</td><td>

```lua
-- Per item: fly to slot + snap feedback
Sauce:Sequence({
  Sauce:Move(item, scatter, gridSlot, 0.5, "outBack"),
  Sauce:Group({
    Sauce:ScaleTo(item, 1.25, 1, 0.3, "outElastic"),
  }),
})
```

`/psd magnetize` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/26_magnetize.lua)

</td></tr></table>


### Matrix Rain

Columns of green characters fall with white leading heads and gradient trails.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/matrix.gif" width="100%">

</td><td>

```lua
-- Per character: fall + fade, loop forever
Sauce:Sequence({
  Sauce:Group({
    Sauce:Move(char, { colX, top }, { colX, bottom }, dur, "linear"),
    Sauce:AlphaTo(char, 1, 0, dur, "inExpo"),
  }),
}, { loop = 0 })
```

`/psd matrix` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/18_matrix.lua)

</td></tr></table>


### Slot Machine

Reels spin with texcoord-driven scrolling and outQuint deceleration. Staggered stops with shake. Every 4th spin is a jackpot with confetti.

<table><tr><td width="50%">

<img src="https://codeberg.org/Pizzahawaii/media/raw/branch/main/PizzaSauce/slotmachine.gif" width="100%">

</td><td>

```lua
-- Reel spin via custom texcoord setter
Sauce:Tween(reel, {
  type = "custom",
  from = 0, to = reelSize,
  duration = 2.6, easing = "outQuint",
  setter = function(_, v)
    scrollTexCoords(v)
  end,
})

-- Stop feedback
Sauce:Shake(reel, 3, 0.15)

-- Jackpot: 300 confetti particles
Sauce:Group(confettiAnims)
```

`/psd slotmachine` · [View source](https://codeberg.org/Pizzahawaii/PizzaSauceDemos/src/branch/main/demos/24_slotmachine.lua)

</td></tr></table>


All demos are included in [PizzaSauceDemos](https://codeberg.org/Pizzahawaii/PizzaSauceDemos). Type `/psd <name>` in-game to run them.
