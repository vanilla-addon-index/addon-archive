# BetterHelp

A World of Warcraft 1.12 addon that enhances the `/help` command to display all available slash commands from your installed addons.

## Features

- **Lists all slash commands** - Shows every registered slash command from all your addons
- **Search/filter** - Filter commands by name (e.g., `/help aux` to find all aux-addon commands)
- **Non-destructive** - Preserves the original `/help` output, appending it after the command list
- **Multiple triggers** - Shows all aliases for each command (e.g., `/aux`, `/auc`)

## Installation

1. Download or clone this repository
2. Copy the `BetterHelp` folder to your `Interface\AddOns` directory
3. Restart WoW or `/reload` if already in-game

## Usage

| Command          | Description                                |
| ---------------- | ------------------------------------------ |
| `/help`          | List all slash commands + original help    |
| `/?`             | Same as /help                              |
| `/slashlist`     | List all slash commands (no original help) |
| `/sl`            | Short alias for /slashlist                 |
| `/help <filter>` | Filter commands (e.g., `/help pfui`)       |

## Examples

```
/help           -- Show all commands
/help aux       -- Show commands containing "aux"
/sl raid        -- Show commands containing "raid"
```

## Output Format

Commands are displayed in yellow with their internal name in gray:

```
/aux, /auc (AUX)
/pfui (PFUI)
/reload, /rl (RELOAD)
```

## Compatibility

- **Client Version**: 1.12.1 (Vanilla)
- **Tested On**: Turtle WoW

Should work on any 1.12.1 client or private server.

## License

MIT License - Feel free to use, modify, and distribute.
