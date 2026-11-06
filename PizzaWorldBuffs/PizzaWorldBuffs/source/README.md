# 🍕 PizzaWorldBuffs

Addon that shows Onyxia/Nefarian head despawn timers and the last known Darkmoon Faire location. All this info is constantly being shared between all addon users so you will e.g. see timers for Ony/Nef head even if you didn't witness the buff drop yourself. See [below](#how-it-works) for more details on how it works.

<img src="img/frame.png" width="100%">

> [!IMPORTANT]
>
> **This addon does NOT show you when the next Dragonslayer buff will be triggered!** 
> 
> It only shows you when the window for the buff to be triggered will open up again, i.e. when the Ony/Nef heads will despawn from the SW/OG city gates. The actual buff is only triggered when a player turns in the head of Ony/Nef and the addon can't possibly know when that's going to happen.

## Install

### [⬇️ Download the latest version](https://codeberg.org/Pizzahawaii/PizzaWorldBuffs/releases/latest)

1. Download `PizzaWorldBuffs-<version>.zip` from the release page and extract it
2. Copy the `PizzaWorldBuffs` folder inside it to `<WoW>/Interface/AddOns`
3. (Re)start WoW

> [!WARNING]
> Extracting might give you a `PizzaWorldBuffs-<version>` folder with the actual `PizzaWorldBuffs` folder inside it. If so, copy the inner one. WoW only loads it as `AddOns/PizzaWorldBuffs/PizzaWorldBuffs.toc`, not `AddOns/PizzaWorldBuffs-<version>/PizzaWorldBuffs/PizzaWorldBuffs.toc`.

## Version Upgrade

To update to the latest version, delete your `<WoW>/Interface/AddOns/PizzaWorldBuffs` folder and follow the [installation steps](#install) again.

If updating to the latest version causes any issues, delete `<WoW>/WTF/Account/<Account>/<Server>/<Character>/SavedVariables/PizzaWorldBuffs.lua` and restart WoW. If the problems persist, please [create an issue](https://codeberg.org/Pizzahawaii/PizzaWorldBuffs/issues/new).

Check the [commit history](https://codeberg.org/Pizzahawaii/PizzaWorldBuffs/commits/branch/main) to see the latest changes.

## Commands

```
/wb                    Show all commands
/wb show               Show the addon
/wb hide               Hide the addon
/wb toggle             Toggle show/hide the addon
/wb lock <1 or 0>      1 to lock PizzaWorldBuffs frame, 0 to unlock it
/wb header <1 or 0>    1 to show PizzaWorldBuffs header, 0 to hide it
/wb dmf <1 or 0>       1 to show Darkmoon Faire location, 0 to hide it
/wb all <1 or 0>       1 to show timers for both factions, 0 to only show timers for your faction
/wb mapHeads <1 or 0>  1 to show Ony/Nef head timers on the SW/OG map, 0 to hide them
/wb logout <1 or 0>    1 to log out automatically after receiving the next buff, 0 to stay logged in
/wb exit <1 or 0>      1 to exit game automatically after receiving the next buff, 0 to stay logged in
/wb reset              Reset PizzaWorldBuffs frames to their default positions
/wb fontSize <size>    Change the font size of the PizzaWorldBuff frame (Default: 14)
/wb align <x>          Change text alignment. Valid options: left, center, right (Default: center)
/wb dmfbuffs           Show a list of all available Darkmoon Faire buffs
/wb horizontal         This command alligns the text to a horizontal position
/wb vertical           This command alligns the text to a vertical position
/wb version            Show current PizzaWorldBuffs version

```

## Reporting Timers

<img src="img/timer_report.png">

You can report your timers via chat in different ways. If your chat edit box is open (`Enter`), clicking one of your timers while holding `Shift` will paste it into the edit box so you only have to press Enter again to share it. This also works for [WIM](https://github.com/shirsig/WIM) chat windows, but only if one of those WIM edit boxes is currently focussed.

Additionally, if the default chat edit box is not open and no WIM edit box is focussed, you can use the following shortcuts for convenient timer reporting:

- `Shift-Leftclick` immediately reports the timer in `/say`
- `Shift-Rightclick` immediately reports the timer in `/guild`
- `Shift-Middleclick` immediately reports the timer in `/h`

> [!TIP]
> If you get asked which addon you're using for buff timers, try shift-clicking the "PizzaWorldBuffs" header! 😉

## How it Works

PizzaWorldBuffs uses different triggers for detecting Dragonslayer buffs and Darkmoon Faire location. When one of those is detected on your character, the addon continuously broadcasts that information to all other addon users in the background. On the flipside, when the addon receives previously unknown (to you) buff/DMF information from other players, it stores that info for you and also shares it with other players again from that point on.

### Ony/Nef Head Timer Detection

To detect that an Ony/Nef buff popped, the addon uses the SW/OG-wide messages yelled by NPCs when someone triggers the buff. Once detected, it stores and broadcasts the server time at which the head will despawn again (i.e. 2 hours from now) and uses that for the countdown timer.

### DMF Location Detection

The location of the Darkmoon Faire is detected, stored and broadcasted when you move your mouse cursor over any of the DMF NPCs.

### Data Storing & Sharing

All data is stored persistently, so you will keep it even after relogging or reloading your UI. All the information is (eventually) propagated to and reshared by everyone who's using the addon. So the data will continue to be broadcasted, even after the player who originally found the buff or DMF location has logged off.

### Buff Timer Color-Coding

A boss name's color designates the faction/city where the buff was triggered:

- **Blue:** Alliance (Stormwind)
- **Red:** Horde (Orgrimmar)

The color of the timer itself denotes how confident the addon is in the correctness of that specific timer:

- **Green:** High confidence *(You have witnessed that buff yourself)*
- **Orange:** Medium confidence *(The person you received the timer from has witnessed that buff themselves)*
- **Red:** Low confidence *(Neither you nor the person you received the timer from have actually witnessed that buff)*

### Buff Timer Prioritization

The addon only accepts timers it receives from other players if it has the same or higher confidence in them than in your current timer for the respective boss/faction. If you currently don't have any timer for that boss/faction, the addon accepts any timer it receives. Timers you witnessed yourself are always accepted.

## FAQ

### Q: Why don't I have a timer even though someone told me that buff just triggered?

Most likely because the person who told you doesn't use PizzaWorldBuffs, see [How it Works](#how-it-works).

### Q: The Darkmoon Faire is not there, even though PizzaWorldBuffs told me it was.

PizzaWorldBuffs only shows the last known DMF location, it doesn't guarantee that the faire is still there. You can check how long ago the faire was seen at the location the addon shows you by moving your mouse cursor over it.

Note that DMF takes a break and shuts down every Wednesday and moves its location every Sunday at midnight (server time).

### Q: Why doesn't PizzaWorldBuffs show me some of the data I know it shows to other players?

It can take some time for all the data to be shared with other players, so you might have to wait a little bit. If you still don't see it after 3 minutes, please [create an issue](https://codeberg.org/Pizzahawaii/PizzaWorldBuffs/issues/new).

### Q: I don't ever see any data at all. No buff timers and no DMF location.

Try relogging or running `/join LFT`. If that doesn't help, please [create an issue](https://codeberg.org/Pizzahawaii/PizzaWorldBuffs/issues/new).

The addon uses a hidden `LFT` chat channel to receive data from and share data with other players. It should automatically join that channel whenever the addon is loaded. But if it doesn't, maybe one of your other addons is interfering. You can check if you're in that channel by right-clicking your chat tab and selecting "Channels". You can also try disabling all other addons.

### Q: What's that font in the screenshots?

It's [Sniglet](https://fonts.google.com/specimen/Sniglet) (included in [pfUI-fonts](https://github.com/shagu/pfUI-fonts))

### Q: What's the best pizza topping?

🍍

## Contact

You're always more than welcome to ask questions or provide any kind of feedback.

- **Discord**: Pizzahawaii
- **Nordanaar**: Pizzahawaii, Pizzamista, Pizzapimp<br />If you see anyone whose name starts with 'Pizza', chances are it's me. 

❤️ [Shagu](https://github.com/shagu) - Thanks for all the help!
