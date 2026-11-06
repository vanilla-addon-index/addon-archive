# BossTactics Addon

A lightweight, no-frills addon for World of Warcraft (1.12.1) that allows you to store and quickly post pre-defined boss tactics to the Raid Warning channel using simple slash commands.

## Installation

1.  Navigate to your World of Warcraft installation folder.
2.  Go into the `WoW` -> `Interface` -> `AddOns` directory.
3.  Place the `BossTactics` folder directly into the `AddOns` folder.
4.  Restart World of Warcraft completely.

## How to Use

The addon is controlled entirely through slash commands. The primary commands are `/bt` or `/bosstactics`.

### Main Command

The core function is to post a pre-defined tactic to the **Raid Warning** channel. You must be a Raid Leader or Assistant to use this feature.

**Syntax:**
`/bt "<Raid Name>" "<Boss Name>" "<Tactic Name>"`

-   **Quotes (`"`) are required** for any name that contains a space.
-   The command is not case-sensitive.

**Examples:**

-   To post the Mechanics for Lucifron in Molten Core:
    ```
    /bt "Molten Core" Lucifron Mechanics
    ```

-   To post the Mechanics for Onyxia:
    ```
    /bt "Onyxia's Lair" Onyxia Mechanics
    ```

### Help Command

If you forget the commands, you can type `/bt` or `/bt help` to see a reminder in your chat window.

---

## How to Add or Edit Tactics

All tactics are stored in a single, easy-to-edit file. You do not need any programming knowledge to change it.

1.  Navigate to your addon folder: `Interface\AddOns\BossTactics\`
2.  Open the file `BossTactics_data.lua` with a simple text editor (like Notepad on Windows, or TextEdit on Mac).

### Data Structure

Inside the file, you will see a structure that looks like this:

```lua
BossTactics.Data = {
    ["Raid Name"] = {
        ["Boss Name"] = {
            ["Tactic Name"] = "This is the message that gets posted.",
            ["Another Tactic"] = "Another message here.",
        },
    },
};
