# SafeShift Turtle WoW Edition
SafeShift-TWoW fixes the issue from the original 'SafeShift' addon, where in vanilla WoW you had to shift out of your current form before switching to another (e.g., cat form -> human form -> bear form), by allowing direct form switching (e.g., cat form -> bear form) without needing to shift out first.

## Installation
Extract into your "World of Warcraft/Interface/Addons" folder. If downloaded directly, rename "SafeShift-TWoW-main" to "SafeShift-TWoW".

## Features
* Switch between forms without manually unshifting (example: while in bear form, spam travel form key to shift to travel form).
* Configurable safety period during which you can't unshift. This prevents accidentally unshifting while mashing a shapeshift key.

## Usage
* /safeshift - lists commands and shows current safety setting.
* /safeshift [cat | bear | direbear | travel | moonkin | aquatic] - safely shift into form without unshifting for the set period.
* /safeshift [cd | cooldown] <value in seconds> - sets the safe period during which you may not unshift. Default: 0.5 seconds.
