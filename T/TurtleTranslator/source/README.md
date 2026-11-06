# TurtleTranslator

**Turtle WoW** chat translation addon – translates incoming messages in real time using language detection and pivot translation (via English).

Built for Turtle WoW (1.12 client), supports multiple languages with customizable source/target filtering.

## Features

- Automatic language detection from incoming chat messages
- Translates messages in selected channels (whisper, say, yell, party, guild, emote, officer, raid, etc.)
- Choose target language (English, Spanish, French, German, Italian, Portuguese, Polish, Russian, Romanian, Czech)
- Select which source languages to translate from
- Movable window with drag-to-save position
- Debug mode for troubleshooting detection & translation

## Supported Languages

- English
- Spanish
- French
- German
- Italian
- Portuguese
- Polish
- Russian
- Romanian
- Czech

## Commands

- `/tt menu` or `/turtletranslator` or simply `/tt` – Open/close settings window
- `/tt debug` – Toggle debug messages (shows detection scores, skipped reasons, etc.)

## Installation

1. Download the latest release or clone the repository.
2. Extract/copy the `TurtleTranslator` folder into your Turtle WoW `Interface\AddOns\` directory.
3. Log in
4. Use `/tt menu` to configure channels, source/target languages.

## Settings

All settings are saved per account.

Main options:
- **Enable translation** – global on/off toggle
- **Channels** – which chat types should be translated
- **Translate messages to** – single target language
- **Translate messages from** – which languages to detect & translate (checkboxes, non-exclusive)

## Known Limitations

- Translation quality depends on dictionary completeness
- Detection is word-based and may misidentify very short or mixed messages
- No outgoing translation (only incoming messages)

## Development Notes

- Written for Lua 5.0
- Uses pivot translation (source → English → target) for most language pairs
- Lookups & translations tables expected in separate files (not included in this README)

Feel free to contribute translations, bug fixes or new features!