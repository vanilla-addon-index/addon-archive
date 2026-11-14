# AdeTalentPlanner

A talent planner for WoW 1.12 (vanilla). It replaces SpecialTalent + SpecialTalentUI with one addon. It shows all three trees in one window, lets you link talents and builds in chat, and shares your builds between all your characters and accounts.

## Install

1. Copy the `AdeTalentPlanner` folder into `Interface\AddOns\`.
2. **Disable SpecialTalent and SpecialTalentUI.** Both addons take over the talent key, so they can't run alongside this one.
3. Optional: **AdeTalents**. It gives exact talent text for every planned rank.
4. Optional but recommended: [SuperWoW](https://github.com/balakethelock/SuperWoW). It adds real talent links and sharing between accounts (see below).

Your talent key (N) and the talent micro button open this window. You can also type `/adetp`.

## Window

- **Mode: Learning / Planning**: Learning mode shows your real talents, and clicking a talent learns it. Planning mode lets you plan points without spending them.
- **Learning mode**: Ctrl-click learns a talent. This guard is on by default, and you can turn it off with the "Ctrl-click to learn" box. Talents that are planned but not learned yet have a **cyan frame**, so you can see what to take next while you level.
- **Planning mode**:
  - Left-click or wheel up adds a point.
  - Right-click or wheel down removes a point.
  - Ctrl-click learns the talent for real.
  - The normal rules apply: 5 points per tier, prerequisites must be maxed, and 51 points at most (`/adetp maxpoints N` changes the limit). You can't remove a point if another planned talent depends on it.
- **Shift-click any talent** to put it in chat.
- Each talent shows the planned rank in cyan (bottom left) and the learned rank in yellow/green (bottom right).
- **Tooltips in Planning mode** show the text for your **planned** rank, plus the next rank and any requirements your plan doesn't meet yet (in red). The text comes from **AdeTalents** if it's installed and has data for that class. Otherwise it comes from the talent's spell (needs SuperWoW). If neither is available, you get the game's normal tooltip. Learning mode always shows the game's tooltip for your real rank.
- **Build buttons**:
  - `<` and `>` switch between builds.
  - New, Copy and Rename do what they say.
  - "From spec" saves your learned talents as a new build.
  - Delete removes a build. Reset clears all planned points, and the small `x` on a tree clears just that tree.
  - Link puts the build in chat.
- **Class**: left-click goes to the next class and right-click to the previous one. You can plan builds for any class you have logged in at least once.
- **Look: pfUI / Blizzard**: by default the window uses the pfUI style when pfUI is loaded and the normal Blizzard style otherwise. The button switches between the two and reloads your UI to apply it. `/adetp style auto` goes back to automatic.
- Drag the window to move it. `/adetp scale 0.8` makes it smaller.

## Builds are shared

Builds are stored **per class, not per character**. Every Hunter you have sees the same Hunter builds. Each character remembers which build it had selected last.

- **Same account**: works out of the box (account-wide SavedVariables).
- **Other accounts (needs SuperWoW)**: builds, talent trees and talent link data are also written to `<WoW folder>\imports\AdeTalentPlanner`. Any account on the same WoW install reads that file when it logs in and merges it. For each build, the newest change wins, and deleting a build on one account deletes it everywhere. The addon reads the file again right before every write, so two clients running at once don't wipe each other's builds. `/adetp sync` forces a sync.

## Chat links

**Single talent (Shift-click):** With SuperWoW, the addon finds the spell behind each talent rank once after login. This takes about a second in the background. The talent is then linked as a normal spell link, which **everyone can click and see the tooltip, even without this addon**. Without SuperWoW, or if no spell is found, it puts plain text like `[Monster Slaying 1/3]` in chat instead.

**Whole build (Link button or `/adetp link`):** Puts something like `[Hunter: Raid MM (0/31/20)]` in chat. Players who have this addon can click it to open the build, look at it in the window, and press **Save build** to keep it. In Learning mode, Link sends your learned talents. In Planning mode it sends the build you're looking at. Shift-click a build link while typing to repost it.

If your server blocks custom links (your message doesn't show up, or the link is gone), use `/adetp linkmode plain`. The build is then sent as text like `[AdeTP:HUNTER:0503-05053-...:Raid MM]`. Players with the addon see it as a clickable link anyway. `/adetp linkmode link` switches back.

## Viewing other classes

The 1.12 game only gives talent data for your own class. So the addon saves each class's trees when you log in a character of that class. With SuperWoW, logging in on any account counts. If someone links a build for a class you haven't logged in yet, you can still save it, and it shows up once you log in that class.

## Commands

| Command | What it does |
| --- | --- |
| `/adetp` | open or close the window |
| `/adetp link` | link the shown build in chat |
| `/adetp linkmode link` or `/adetp linkmode plain` | clickable link, or a text code for strict servers |
| `/adetp scale 0.4-1.5` | window size |
| `/adetp ctrl` | turn Ctrl-click-to-learn on or off |
| `/adetp maxpoints N` | max planned points (default 51) |
| `/adetp style auto`, `/adetp style blizz` or `/adetp style pfui` | window look (auto = pfUI if loaded), applies after `/reload` |
| `/adetp sync` | sync with other accounts now (SuperWoW) |
| `/adetp scan` | find the talent spells again for links (SuperWoW) |
| `/adetp scanmax N` | highest spell id to search (default 60000; raise it if a custom server's talents don't link) |
| `/adetp importold` | import this character's SpecialTalentUI plans |

## Importing from SpecialTalentUI

1. Enable **only** SpecialTalentUI (not SpecialTalent) together with this addon, and log in.
2. Run `/adetp importold` on each character whose plans you want to keep.
3. Disable SpecialTalentUI and `/reload`.
