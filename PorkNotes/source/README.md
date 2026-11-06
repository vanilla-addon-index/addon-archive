# PorkNotes

Write notes about other players.

An addon for TurtleWoW (1.12 / Lua 5.0).

Based on [CaramelNotes](https://github.com/MrToffee/CaramelNotes) by MrToffee.

## Installation

### GitAddonsManager

1. Open GitAddonsManager and click the + to download an addon from a git repository.
2. Paste the git link to this repository into the prompt. (https://github.com/porkfriedlumpia/PorkNotes.git)
3. Press OK and the addon will download automatically to your AddOns directory.
4. Log in and type `/pn` or `/porknotes` to open

### Manual installation

1. Download and extract the zip
2. Rename the folder to `PorkNotes` if it isn't already
3. Place the `PorkNotes` folder in your `Interface/AddOns` directory
4. Log in and type `/pn` or `/porknotes` to open

## Commands

- `/porknotes` or `/pn` — Open the notes window
- `/pn import` — Import notes from CaramelNotes

## Features

- Write and store notes for any player
- Notes appear in player tooltips on hover
- Chat alerts when a noted player sends a message, with a clickable link to edit their note
- Right-click any player to add or edit their note
- Minimap button for quick access — left click opens notes, right click opens settings
- World and LookingForGroup channel alerts route to a configurable chat frame
- Player notes sync via Party, Raid, Guild and Battleground channel addon messages
- Review frame for synced messages with automatic visibility toggle and chat alert link
- Settings window to configure tooltip display, chat alerts, sync behavior, history limits, and more

## Importing from CaramelNotes

If you have existing notes in CaramelNotes you can import them into PorkNotes in a few steps:

1. **(Not necessary if you already have CaramelNotes installed.)** Download and install the CaramelNotes compatibility release: [CaramelNotes 1.3.1](https://github.com/porkfriedlumpia/PorkNotes/archive/refs/tags/CaramelNotes.zip)
2. Extract the folder to your AddOns directory and rename it to `CaramelNotes`
3. Make sure both PorkNotes and CaramelNotes are enabled in your addon list
4. Log in to the game
5. Type `/pn import` in chat, or click **Import from CaramelNotes** in the PorkNotes settings window
6. Your notes will be imported — any players you already have notes for in PorkNotes will be skipped
7. Once the import is complete you can disable or uninstall CaramelNotes

## Images

### Main window (`/pn or /porknotes`)

![image](https://private-user-images.githubusercontent.com/268243004/563869082-df971bcd-0fbc-493f-bc77-49753f2935e6.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzM2MjU3MTUsIm5iZiI6MTc3MzYyNTQxNSwicGF0aCI6Ii8yNjgyNDMwMDQvNTYzODY5MDgyLWRmOTcxYmNkLTBmYmMtNDkzZi1iYzc3LTQ5NzUzZjI5MzVlNi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMzE2JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDMxNlQwMTQzMzVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1mM2E3OTAzMjZiZGU2NzBmZmE5ZDM2NzdkNTc0Y2IyODBlZDc1ZmJiZWNhMTQ4ZmQxYzQ3NWE1NzlkNWVkYzg3JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.6Zg1gq828ffI4rRvJbXYjgDOC_OAtxxSwCssYmRWV5w)

### Right-click menu on players

![image](https://private-user-images.githubusercontent.com/268243004/563680569-ab873bbd-27b5-49c5-881a-949d894f99d0.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzM1NjA0MzEsIm5iZiI6MTc3MzU2MDEzMSwicGF0aCI6Ii8yNjgyNDMwMDQvNTYzNjgwNTY5LWFiODczYmJkLTI3YjUtNDljNS04ODFhLTk0OWQ4OTRmOTlkMC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMzE1JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDMxNVQwNzM1MzFaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT03MmM2ZWIzMDU1ZTJjOWY5ZDY5Y2Y0NjQ0N2IyYjk0YjVlMmQwNjZhNTc3ZWRmYjMzYWE3NWY5NTc5NTk3MGQ3JlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.SUoVCOuYuMBI_Gdj5aHiLfXyGctG9-YC1LCPdvOjf9A)

### Note alerts in chat

![image](https://private-user-images.githubusercontent.com/268243004/563680570-a4470726-233b-44ea-9b7f-f8d98fdb78a4.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzM1NjA0MzEsIm5iZiI6MTc3MzU2MDEzMSwicGF0aCI6Ii8yNjgyNDMwMDQvNTYzNjgwNTcwLWE0NDcwNzI2LTIzM2ItNDRlYS05YjdmLWY4ZDk4ZmRiNzhhNC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMzE1JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDMxNVQwNzM1MzFaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT0zZWE2ZDk2ZjUwZTM1ODVhMmQyMWFmMzM1M2VkYzIwZTM2OTU0MjRiODczMTZlYjkxZjExY2FiNjliZDU1MGVhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.KKWWSNF-F8quiZcacuGbPtewO3cEIpnzofVaRJP1FKo)

### Minimap button

![image](https://private-user-images.githubusercontent.com/268243004/563680571-d5482881-93d4-4a05-9f91-c4a0f04fd5f1.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzM1NjA0MzEsIm5iZiI6MTc3MzU2MDEzMSwicGF0aCI6Ii8yNjgyNDMwMDQvNTYzNjgwNTcxLWQ1NDgyODgxLTkzZDQtNGEwNS05ZjkxLWM0YTBmMDRmZDVmMS5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMzE1JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDMxNVQwNzM1MzFaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT00M2E1ZjAyY2FmNTlmNDk1ODhjOWM5YmI0ZTIwNjEzY2I1MDhjYjk1ZDNhYmI2MWY1YWQwOGRjZjY3ODdiNzJjJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.sreCFwtPC0IegBcsK4UcADI28yIMCOWBV85li5Xe0j4)

## Credits

- Original addon [CaramelNotes](https://github.com/MrToffee/CaramelNotes) by MrToffee
