# 41's Combat Alert

41's Combat Alert is a World of Warcraft 1.12.1 addon that shows an on-screen
alert, plays a sound, and/or reports to chat when a combat-log message matches
one of your patterns.

## Installation

Copy the 41sCombatAlert folder into:

    Interface\AddOns\

Then restart WoW or reload the UI.

## Opening the configuration window

Use:

    /foca

You can also click the minimap icon to open or close the configuration window.

## Patterns

* is the only wildcard. It matches zero or more arbitrary characters.
Matching is case-insensitive.

currentpet is replaced with your current pet's name. A pattern containing
currentpet cannot match when you have no pet.

Examples:

    currentpet*torment*resisted*
    your taunt was resisted*

### Exceptions

Use the **Except** field to stop an alert when the message contains an
exception. Separate multiple exceptions with |; spaces around | are ignored.
Exceptions are plain text: * has no wildcard meaning there.

Example:

    Pattern:  you gain*
    Except:   thorns|rejuvenation

### Spellcast-start patterns

You can also react to the start of your own casts:

    SPELLCAST_START Fireball
    SPELLCAST_START *
    SPELLCAST_CHANNEL_START Mind Flay

SPELLCAST_START is sent for spells with a cast time, not instant spells.
SPELLCAST_CHANNEL_START is sent when a channel begins.

On some Turtle WoW-based clients, a channel-start event supplies the generic
text Channeling rather than the spell name. In that case, use:

    SPELLCAST_CHANNEL_START *

## Alert actions

Each alert can independently use the following actions:

- **Enable** — Turns the alert on or off.
- **Text** — Shows the Text field on screen.
- **Sound** — Plays the selected sound.
- **Report** — Sends the Text field to Party, Raid, Say, Yell, Guild, and/or a
  joined custom channel.

More than one report destination may be selected. Party and Raid reports are
sent only when you are in a party or raid. Enter the name of a joined channel
in the **Ch:** field to report there too.

Each alert has a **Test** button that tests its enabled Text, Sound, and Report
actions. The editor shows four alerts per page; use **Previous** and **Next**
to change pages. Use the up and down buttons on the left side of an alert to
change its order. Parent alerts move as groups with their children; child
alerts move within their own parent group.

## Text tokens

These tokens work in both on-screen Text and chat reports:

- %t — Your current target's name
- %tt — Your target's target's name
- %p — Your player name
- %pet — Your current pet's name

## Sounds

Choose one source in the **Sound** dropdown:

- **Sound A–F** use the included SoundA.wav through SoundF.wav files.
- **Custom File** uses a WAV file under the addon's Sounds folder. Enter its
  path in the **File** field, for example MySound.wav or Boss\MySound.wav.
- **MPQ Path** uses a WAV path inside the WoW client archives. Enter it in the
  **MPQ** field, for example:

      Sound\Interface\RaidWarning.wav

The MPQ field is not a Windows file path. You can browse known WoW sound paths
at [wow-sounds](https://github.com/fondlez/wow-sounds).

You may replace the included Sound A–F files with your own WAV files.

## Sequences and random groups

Press **Sequence** or **Random** on a parent alert to add a child alert. A child
inherits its parent's Pattern, which cannot be edited, but it can have its own
Text, Sound, and Report settings.

The parent is included as the first possible reaction:

- **Sequence** plays the parent, then enabled child reactions in order, and
  repeats from the beginning.
- **Random** chooses randomly between the parent and enabled child reactions.

## Account, character, and shared-character alerts

Both Account and Character alerts are active for the current character.

- **Account** alerts are used by every character on the account.
- **Character** alerts normally belong only to the current character.

Character data is stored inside the account SavedVariables data, but is kept
separate by realm and character name.

### Copy

On the **Character** tab, select an independent character in the dropdown and
press **Copy** to copy all of that character's alerts to the current
character. The original alerts remain unchanged.

### Share

On the **Character** tab, select an independent character and press **Share**
to make that selected character the parent of the current character.

The current character becomes a child and directly uses the parent's Character
alerts. Changes made on the parent—including adding, editing, and deleting
alerts—are automatically used by every child of that parent. A child is removed
from the dropdown because it is no longer an independent alert source.

While the current character is a child, **Share** changes to **Stop Share**.
Press it to remove the parent link and return to that character's own saved
alerts. Those original alerts are preserved while sharing is active.

## Starter examples

The Taunt-resisted example is enabled by default, uses Text and Sound, and
reports to Party.

## License

This project is licensed under the [MIT License](LICENSE).
