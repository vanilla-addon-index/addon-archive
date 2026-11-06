# pfUI Chat Scroll Button

A lightweight World of Warcraft Vanilla 1.12.1 addon that adds a pfUI-styled scroll-to-bottom button to chat windows.

When a chat window is scrolled up, a small button appears in its bottom-right corner. Click it to instantly return that chat window to its newest messages.

## Features

- pfUI-styled dark button with a mint border
- Uses pfUI's native down-arrow texture
- Appears only when a visible chat window is scrolled up
- Instantly scrolls the selected chat window to the bottom
- Renders beneath other game windows (such as bags) so it never overlaps them, regardless of what's open or the order things were opened in
- Border highlights on hover, matching pfUI's standard button style
- Glows and brightens its border only when there's an actual unread message waiting - scrolling up manually on your own doesn't trigger it
- Briefly pulses when a new message arrives in a scrolled-up chat window
- Does not pulse for the default Combat Log window
- Supports all seven standard Vanilla chat frames
- No configuration required

## Requirements

- World of Warcraft Vanilla 1.12.1
- pfUI

pfUI is a required dependency and must be enabled.

## Installation

1. Download the addon release and extract it.
2. Ensure the extracted addon folder is named exactly:

   ```text
   pfUI-chatscrollbutton
   ```

3. Place that folder inside:

   ```text
   World of Warcraft\Interface\AddOns\
   ```

4. The final path must be:

   ```text
   World of Warcraft\Interface\AddOns\pfUI-chatscrollbutton\
   ```

5. Ensure both pfUI and pfUI Chat Scroll Button are enabled on the character-selection AddOns screen.
6. Log in or reload the interface with `/reload`.

## How It Works

Scroll upward in a visible chat window. A small arrow button will appear in the bottom-right corner of that window.

Click the button to immediately return to the newest chat messages.

The button's border reflects its state: a dim gray border at rest, a brighter highlight while your cursor is over it, and a bright mint border whenever there's an actual unread message waiting - the mint highlight takes priority over the hover highlight, so it always stays visible as a notification even while you're hovering the button.

When a new message arrives while the chat window is scrolled up, the button gives one brief mint glow pulse in addition to the border highlight. The default Combat Log window does not pulse to avoid visual noise during combat.

The button always renders beneath other game windows, such as your bags, so it won't visually overlap them no matter what else is open.

## Compatibility

This addon is designed for:

- World of Warcraft Vanilla 1.12.1
- pfUI

It uses Vanilla-compatible Lua and does not require ClassicAPI or other external addons.

## Notes

The addon creates a button for each standard Vanilla chat frame, from `ChatFrame1` through `ChatFrame7`. The button only becomes visible for a chat frame that is currently visible and not at its scroll bottom.

The addon creates a small fixed set of UI elements and does not store chat history or create saved data.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Credits

Created by Vakos.

Designed to complement pfUI.

Developed with assistance from OpenAI Codex (GPT-5).
