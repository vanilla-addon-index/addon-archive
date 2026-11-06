# SuperIgnore

An unlimited ignore list for **WoW Vanilla 1.12.1**, with timed ignores, reasons, and public-channel spam blocking.

## Ignore or Spam?

| Mode | What it does |
| --- | --- |
| **Ignore** | Blocks players according to your **Ignore Settings**. |
| **Spam** | Hides their public-channel messages while keeping whispers, group/raid, guild chat, and direct interactions available. |

Both modes support a duration and optional reason. The list separates **Ignore** and **Spam** entries.

## Getting started

1. Place the `SuperIgnore` folder in `Interface/AddOns` and enable the addon.
2. Right-click a player and choose **Ignore Player**.
3. Choose **Ignore** or **Spam**, a duration, and an optional reason, then press **Accept**.

You can also click **Ignore Player** in the ignore window and enter a name in the same popup.

**Default Ignore Time** starts at **Ask** on fresh installs. Each popup starts at **Forever**.

## Useful controls

- Right-click a list entry to change its mode, duration, or reason, or remove it.
- Click **SuperIgnore** in the ignore window to open settings.
- **Ignore Settings** and whisper options apply only to Ignore mode. Spam always hides public-channel messages.
- Click a player's log icon to review blocked messages.
- Enable **Debugger** for a session-wide log and behavior checks.

## Chat command

```text
/ignore Name [reason]
```

Toggles an entry; with **Ask** selected, adding a player opens the popup.

## Theme and compatibility

Matches [pfUI](https://github.com/brues-code/pfUI) when its SuperIgnore skin is enabled, including class-colored hover highlights. Supports WIM and WhisperFu.

## Preview
<img width="761" height="592" alt="WoW_07-10-26" src="https://github.com/user-attachments/assets/26beb9dc-00e5-4844-b6b0-76f0fbe92fdf" />
<img width="761" height="592" alt="WoW_07-10-26 (2)" src="https://github.com/user-attachments/assets/e4c91991-03fc-42ab-8698-dafa26be6138" />
