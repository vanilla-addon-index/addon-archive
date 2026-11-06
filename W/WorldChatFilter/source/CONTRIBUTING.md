# Contributing to World Chat Filter

Missed advertisements, false positives, and compatibility reports are especially useful.

## What to include in an issue

- Client/server version (e.g., OctoWoW 1.18) and addon version.
- Chosen sensitivity and affected category.
- The World message that was incorrectly hidden or displayed (with names and private information removed).
- Output from `/wcf test <message>` and any relevant Lua errors.
- Whether it also happens with other chat addons disabled.

## Development guidelines

- Preserve the legacy Vanilla Lua/API compatibility.
- Filter only messages from the channel actually named `World`. **Never filter Trade, General, LookingForGroup, Guild, Party, or Whisper.**
- Prefer **general patterns and context** instead of blacklisting a guild or player name.
- Add both positive and negative regression examples when changing the classifier.
- Keep SavedVariables compatible across updates.

## Running tests

From the repository root, run `python tests/run_tests.py`. It requires a Lua interpreter available as `lua`, `lua5.1`, `lua5.4`, or `texlua` (or pass the path as the first argument). Tests are mocked and cannot replace in-game testing.