# BigTimer

![BigTimer](https://github.com/TheRealFayz/BigTimer/blob/main/Images/BigTimer3.png?raw=true) ![BigTimer](https://github.com/TheRealFayz/BigTimer/blob/main/Images/BigTimer.png?raw=true) ![BigTimer](https://github.com/TheRealFayz/BigTimer/blob/main/Images/BigTimer2.png?raw=true)

A quick-access pull timer toolbar for **World of Warcraft 1.12** (Turtle WoW), with built-in raid target marking.
Requires the **BigWigs** addon with its Pulltimer plugin enabled.

You can also download BigTimer from OctoWoW's [Gitea](https://octowow.st/git/Fayz/BigTimer).

## Requirements
| Requirement | Notes |
|---|---|
| **BigWigs** | Must be loaded and enabled |
| **BigWigs Pulltimer plugin** | Must be enabled within BigWigs options |

## When the bar shows up
| Group | Who sees it |
|---|---|
| **Raid** | Raid leader or assist |
| **Party** | Party leader |

The bar hides itself when you are not in a group, or don't have the role above.

## Buttons
| Button | What it does |
|---|---|
| **10 / 15 / 20 / 30 / 60** | Starts a BigWigs pull timer for that many seconds |
| **Break** | Starts a break timer (length is set in Settings). BigWigs always labels the bar "Pull" |
| **Ready** | Sends a ready check |
| **X** | Cancels the pull timer. If no timer is running, BigWigs starts a 6 second pull instead |
| **Cfg** | Opens the settings window |

## Raid Marks
A strip of the 8 raid target icons sits inside the bar, in order from Skull to Star (Skull is always on the left, or on top when the bar is vertical), followed by a clear button.

* **Left-click** an icon to put that mark on your target
* **Left-click the same icon again** to remove it
* **Right-click** any icon, or click the **clear** button at the end, to clear your target's mark

The icons scale to fit the length of the bar and share its border.

## Settings
Click **Cfg** to open the settings window. You can drag it anywhere and close it with Escape.

* **Break Duration**: 1 to 10 minutes
* **Scale**: 25% to 200%. The bar stays in place while it resizes
* **Horizontal / Vertical**: switches the bar's layout
* **Lock Bar**: stops the bar from being dragged
* **Marks: Top / Bottom** (horizontal) or **Marks: Left / Right** (vertical): which side of the timer buttons the marks sit on. Each layout remembers its own side
* **Show Marks**: turns the raid mark strip on or off

The bar fades to 25% when your mouse isn't over it. All settings are saved per character.

## More addons by Fayz

All for OctoWoW and other 1.12 clients. A star on any of them is appreciated.

- **[TotemNesia](https://github.com/TheRealFayz/TotemNesia)** is a totem management addon for Shaman.
- **[SHAlts](https://github.com/TheRealFayz/SHAlts)** is an alt manager for OctoWoW and other 1.12 clients. It keeps track of everything your characters own and lets you look at any of them from one window, no matter which character you are playing.
- **[Arcanum](https://github.com/TheRealFayz/Arcanum)** helps Mages manage their spells and items.
- **[AutoSpam](https://github.com/TheRealFayz/AutoSpam)** posts your messages to chat channels at the interval you choose, from 1 to 10 minutes.
- **[SHPlates](https://github.com/TheRealFayz/SHPlates)** is a highly customizable nameplate addon. Server threat, cast bars, debuff timers, combo points, raid marks and per-spec settings. Know who has aggro before the mob gets to your healer.
- **[TimeToDrink](https://github.com/TheRealFayz/TimeToDrink)** tells the tank when the healer is low on mana. It watches the healer you choose and posts a warning to party chat when their mana drops below your threshold.
