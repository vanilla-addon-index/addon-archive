# GroupBuffToggle — interface and interaction design

**Creative director:** Babuni.dev. **Evidence:** original README, current code and the two September 10 commits.

## A native UI affordance, not another configuration window

The addon uses Blizzard's familiar **UICheckButtonTemplate** and a small **Buffs** label placed where players are already looking: below their visible party frame stack and beside their current target. No new floating options panel, media bundle or unfamiliar controls are required.

The content sits **to the right** of existing unit frames, so health and resource bars aren't covered. Four possible party grids and one target grid each have two rows of eight small icons (16 total per unit). Buff buttons can be hovered for familiar native tooltips. This uses the game visual language rather than inventing a new type of aura graphic.

## Opt-in by default

A central design decision is that **buff overlays default off**. The user must tick a checkbox or enable a slash setting to alter the information density of the game UI. The checkboxes can be offered when units exist, even if the overlay itself is currently off.

This small restraint is significant. Unit frames are already visually busy; adding 16 icons for each member without invitation might create a disruptive change. The creator's solution keeps the new information available but doesn't insist on showing it.

## The September 10 interaction refinement

The first version had only two persistent visibility flags for party and target buffs. The same-day **“Add independent slash controls”** revision introduced two additional settings controlling **the visibility of the checkboxes**. The player can choose to show buffs while removing the toggle itself, or keep the control present but leave the icons hidden.

That creates four independent states rather than two, with clear direct `/groupbuffs` commands to access each. It is an example of making a small interface less intrusive through a second design pass rather than making it larger.

## Context matters for placement

The party checkbox follows the **last visible party-member frame** in the normal vertical stack; there is no party checkbox when no appropriate unit frame exists. The target checkbox follows the target frame and is shown only when a target exists. These rules keep controls from floating around the screen unattached to any subject.

The icon grids also hide when their corresponding units or Blizzard frames aren't shown. Each refresh reanchors positions to the currently available frames, supporting changing roster layouts within the default UI.

## Visual details and limits

Each buff icon is **20 px**, with a small **2 px** gap, cropped to remove empty texture edges and shown with a quiet gray border. The code uses a native texture sheet named `UI-Debuff-Overlays` as a *decorative frame*, but does not query debuffs. No durations, stacks, counters, expiration effects, sorting or aura type labels are currently drawn.

The amount and placement of information is intentionally fixed; an expanded raid layout would be a separate approved feature, not a small styling tweak.

## Future tests, not design claims

The icon-only layout should be examined at low resolutions, large UI scales, for color-vision accessibility, and with other buffs already present around unit frames. Check whether the target grid overlaps default status elements and whether tooltip hit areas remain easy to use. No screenshot or game-client usability test is in the current repo, and none was conducted during this audit.
