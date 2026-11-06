# Changelog

## 0.1.1

- Fix an animation started from inside a running animation's callback never playing when nothing else was animating

## 0.1.0

First public release.

- 32 convenience animations (fades, slides, bounces, shakes, flips, spins, typewriter, clipping, and more)
- 32 easing functions
- 3 composable primitives: Tween, Sequence, Group
- Auto-play with automatic deferral inside Sequence/Group
- Built-in delay support on all animations
- Zero idle cost (driver hides when nothing is animating)
- Extensible: RegisterType, RegisterEasing, RegisterHelper
- Tween setter methods (SetFrom, SetTo, SetDuration, SetDelay, SetTarget) for zero-allocation replay
- Loop and yoyo support on Sequence
