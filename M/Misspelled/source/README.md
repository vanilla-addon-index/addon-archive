# Misspelled

Misspelled is a chat spellchecker for World of Warcraft 1.12.1. It checks words as you type, highlights misspellings in the chat edit box, and offers spelling suggestions from a right-click menu.

## Requirements

- A 1.12.1 client with [ClassicAPI](https://github.com/brues-code/ClassicAPI) installed and enabled. ClassicAPI provides the Lua and interface compatibility this backport uses.
- The addon folder installed at `Interface/AddOns/Misspelled`.

## Features

- Checks chat text as each word is completed.
- Highlights misspelled words and offers suggestions in the edit box context menu.
- Supports US and UK English, German, Spanish, French, Italian, and experimental Russian dictionaries.
- Learns your friends' and guild members' names as valid words.
- Lets you add words to a personal dictionary and remove saved words from the addon options.

Select a dictionary in the Interface options under AddOns. Reload the UI after changing dictionaries. Spell checking waits for a word separator, so the final word in the edit box is checked when you type punctuation or a space.

## Credits

Misspelled was originally created by Nathan Pieper. It uses Hunspell-style compressed dictionaries and includes the original language dictionaries and spelling logic.
