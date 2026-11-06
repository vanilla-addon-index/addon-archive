# VimWowSettings

The options window the Vim mods share: **Esc > VimWow Options**, with a tab
for each installed mod (its options and key bindings) and a General tab
(High contrast). It does nothing alone; mods such as
[VimFinder](https://octowow.st/git/Lupo/VimFinder) need it.

- A World of Warcraft 1.12.1 (build 5875) client (`## Interface: 11200`).
- No DLL needed.

## Install

With Git, from your game folder:

```
cd Interface/AddOns
git clone https://octowow.st/git/Lupo/VimWowSettings.git
```

To update later, run `git pull` in the `VimWowSettings` folder.

Without Git, download the ZIP from this page, unzip it into
`Interface/AddOns/`, and rename the folder to exactly `VimWowSettings`.

At character select, under AddOns, make sure it is ticked. Its settings
are saved per account in `VimWowSettingsDB`.
