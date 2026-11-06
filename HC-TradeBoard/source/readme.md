# HC TradeBoard 0.8.2

Version 0.8.2 adds one shared, rate-limited MawAddons peer version check. A newer peer version produces one update notice with `https://github.com/MawAddons/HC-Tradeboard`.

HC TradeBoard is a lightweight peer-synced market board for World of Warcraft 1.12.1. It has no central server: online clients exchange active listings and trade chains through a hidden custom chat channel named `TradeBoard`.

## Screenshots

| Browse and filter listings | Create and manage sale listings |
| --- | --- |
| ![Browse tab showing item, level, rarity, and trader filters](screenshots/browse.png) | ![My Listings tab showing the sale editor and active listings](screenshots/my-listings.png) |

| Build community trade chains | Find profession providers |
| --- | --- |
| ![Trade Chains tab showing the level 5 through 60 handoff path](screenshots/trade-chains.png) | ![Professions tab showing an online Alchemy provider](screenshots/professions.png) |

## Install

1. Copy the `HC-Tradeboard` folder into `World of Warcraft\Interface\AddOns\`.
2. Confirm the final path is `Interface\AddOns\HC-Tradeboard\HC-Tradeboard.toc`.
3. Start the 1.12.1 client and enable **HC TradeBoard** on the character-selection AddOns screen.
4. Log in. HC TradeBoard stays closed until you open it.

Use `/tb`, `/tradeboard`, or left-click the coin icon beside the minimap to hide or show it. Hold Ctrl and left-drag the coin to move it around the minimap.

Press **Esc** or the enlarged **X** button to close TradeBoard immediately, including during combat. Esc also closes the full window when one of TradeBoard's text fields has keyboard focus.

## Using it

- Open HC TradeBoard with `/tb`, `/tradeboard`, or the minimap coin.
- Use the **-** button to collapse TradeBoard to a draggable title bar. The window may be parked partly outside the game viewport; `/tb reset` restores it to the center.
- Open the gear button for Guild and World/Trade popup mute timers (5m, 10m, 60m, 2h, or until re-enabled), Wanted alerts, chain-spot opt-in, and window reset.
- Opening HC TradeBoard requests current peer data and refreshes at most every ten minutes while the window remains open. `/tb probe` and `/tb sync` remain available as diagnostic commands, with a short anti-spam cooldown.
- With HC TradeBoard open, Shift-left-click a bag item to load it into **My Listings**. You can also drag it onto the sale slot or arm one normal bag click. HC TradeBoard never opens the bags automatically.
- A character can publish any number of active sale listings using quantity and a total stack price. Scroll **My Active Listings**, then select one and click **Remove Selected** to withdraw it.
- In **Trade Chains**, use **List / Edit My Chain** to publish your chain or **Delete My Chain** to withdraw it.
- In **Professions**, use **List / Edit Mine** to publish services learned by the current character, including skill rank and an optional short note.
- The Professions tab includes the three guilds with the most distinct providers. Click a guild sigil to filter the service table; click it again to clear the filter.
- Press Enter to open normal chat, then Shift-left-click a listed item to insert its real item link.
- Guild item offers and tagged offers in World/Trade automatically open a compact loot window. Click an item to inspect it, or **Whisper** to draft a reply. The popup includes a duration dropdown and a source-aware **Mute Guild** or **Mute World/Trade** button. `/tb loot off` disables notifications; `/tb loot on` enables them again. The older `/tb guildloot` commands remain aliases for the same setting.
- The **Wanted** tab stores up to 50 account-wide item-name or item-link subscriptions. Matching WTS posts seen in World/Trade locally or through peers open a loot-style alert.
- The **Trade Chains** delivery desk tracks peer-shared requests through Requested, Picked Up, and Delivered, including quantity, customer, handoff characters, and a note. Players can opt in as a paid chain spot advertised at their current level +/-5.

## Features

- Browse, My Listings, Trade Chains, Professions, and World Trade tabs.
- A searchable World and Trade-channel archive retaining up to twelve hours and the newest 500 case-insensitive WTS, WTB, and LFW posts. It is shared with peers using duplicate suppression and includes inline hoverable/clickable item links. Idea credit: Svenne :)
- No automatic `/who` calls. Sellers with unknown levels have a `?` button for a player-initiated visible Who lookup. All lookup buttons share a 30-second countdown; buttons disappear once the level is known. Matching level, class, and guild data is shared across tabs and peers.
- Loot popups recognize whole words `anyone`, `anybody`, `any1`, `need`, `needs`, `free`, `giving`, and `giveaway`, plus `give away`, case-insensitively in Guild, World and Trade. Item names do not count as trigger words. An item link is required to open a popup. Guild WTS offers also trigger; public WTS-only posts continue to Browse. WTB requests are excluded.
- Loot popups label the source channel. Guild sender/message text is green; World/Trade text follows the channel's normal configured chat color. Item links retain their quality colors. Item-only followups within 60 seconds join the same sender's offer in the same channel. Contexts, grouping and duplicate detection are separated by channel, with bounded queues and no additional chat or peer traffic.
- Item-linked WTS/WTB chat messages appear as **Chat** offers in Browse. WTS item offers expire three hours after the original message, including those received from peers. WTB offers and recognized **Chat** services in Professions retain their twelve-hour lifetime. The World/Trade archive also remains twelve hours; rebuilding it never restores expired WTS offers.
- Browse displays at most one row per item name + character name, ignoring case, color codes and extra whitespace. Published listings take priority over chat offers; otherwise the newest original post supplies price, quantity and expiry, without adding quantities together. Filtering and counts use unique visible offers. Original records remain available for My Listings, withdrawals and the World/Trade archive.
- A classic minimap coin button for opening and closing HC TradeBoard.
- A compact/minimized title-bar mode, an unclamped draggable main window, and a gear-based settings panel.
- Conservative peer networking: five-second minimum spacing, at most eight hidden-channel messages per minute, a fifteen-second pause after player chat, coalesced records, and smaller sync snapshots.
- Search, category, rarity, trader-level, online, listing-type, and item-level filters.
- Simple Armor and Weapons subcategories without the full Auction House category tree.
- One AH-style filter row with **Level**, **Rarity**, and **Listing Type** dropdowns, Min/Max fields, Online and Clear. Level defaults to **All**; **My range** explicitly enables the seller-level +/-5 filter.
- Item metadata is normalized for both stock 1.12 and extended client APIs before filtering. Previously misclassified cached items repair automatically, including Armor > Mail.
- Click any table header to sort ascending or descending, including numeric total-price sorting.
- Compact AH-style layouts and classic WoW scrollbars across Browse, My Listings, Trade Chains, Professions, and World Trade.
- Hover a Browse result to see the normal WoW item-stat tooltip stacked above the HC TradeBoard listing summary.
- Item-stat tooltips pass raw `item:...` hyperlinks for compatibility with AtlasLoot tooltip hooks.
- Real bag-backed sale listings with quantity and gold/silver/copper total pricing; per-item price is calculated only in the tooltip.
- Saved personal listings and a saved 12-slot level 5-60 trade chain.
- Lightweight peer discovery, deduplicated and coalesced queues, conservative rate limiting, 15-minute announcements, and persistent offline caching. Background sends pause whenever the player chats, reducing the risk of server spam throttling.
- Listing broadcasts include the seller's current character level and item icon texture, with local item-cache refresh as a fallback.
- Offline listings remain available when **Online only** is unchecked, with dimmed rows and last-seen information.
- Peer-synced profession services with profession and guild filters, current skill rank, guild name, optional service notes, online/last-seen status, and direct whispering.
- Published profession rank changes are detected locally, debounced for 45 seconds, and coalesced so only professions whose rank changed are announced.
- Top-three guild provider cards count distinct characters and use a deterministic shared shield sigil derived from the guild name.
- Browse and Professions tables include Guild columns.
- The custom protocol channel is removed from the visible chat windows after joining.
- Visible network state and peer count in the HC TradeBoard status bar.
- A compact header label shows memory usage in MB. It samples at most every 30 seconds while the board is visible, with no forced garbage collection or background polling while closed. Hover for measurement scope and age. Clients with per-addon memory APIs show **Addon**; otherwise **Lua total** clearly identifies the shared Lua heap (Blizzard UI and all addons).
- Select a listing to open a whisper to its trader or request to add that trader to the friend list.
- The minimap-button position is saved between sessions.
- Combat-safe direct closing through Esc, the top-level X button, `/tb`, or the minimap coin.

## Current limitations

- Every player who wants to see or publish listings needs HC TradeBoard installed and must be able to join the same custom channel. Whether Horde and Alliance share that custom channel depends on the server implementation.
- Loot popups are local to clients running the addon and receiving the original Guild/World/Trade message. They infer offers from trigger words and cannot reliably distinguish all questions from giveaways; `anyone?` and `needs?` intentionally count. The word `free` inside an item link such as `[Free Action Potion]` does not trigger them.
- Stock 1.12 exposes required level but not actual item level in `GetItemInfo`; unavailable iLvl is shown as `-`. Uncached item categories become filterable when the client provides their metadata.
- The 30-second Who timer tracks lookups initiated by TradeBoard buttons; independent `/who` commands and server-specific throttles may impose an additional wait.
- Listings are an advertisement only. HC TradeBoard does not move items, money, or automate trades.
- Remote listings and profession services are cached locally and become offline after ten minutes without a refresh. They remain until an explicit withdrawal is received or the saved cache is cleared, so an undelivered withdrawal can leave an old offline advertisement visible.
- Version 0.6.0 uses the `TB2` protocol because listing prices changed from per-item to total price. Peers must update to 0.6.0 or newer to exchange data.
- Chat classification uses independent rules: Browse requires a real item link, while WTS/LFW profession imports use the first matching keyword (e.g. crusader, enchant, arcanite, transmute, mooncloth). A message can produce both an item offer and a service, and keywords inside item names can cause false service matches. Quantity/price extraction is best effort. WTS item offers expire after three hours; profession services and other chat-derived entries expire after twelve hours.
- SavedVariables are shared by characters on one WoW account. Separate accounts share the World/Trade archive and Who-derived data only while their clients can meet through the peer channel.
- Wanted subscriptions are private alerts, not published WTB listings. The listing editor still publishes SELL offers only.

## Regression checks

From the parent workspace directory, run `HC-Tradeboard/tests/data_regressions.lua`, `HC-Tradeboard/tests/browse_dedup_regressions.lua`, `HC-Tradeboard/tests/world_log_smoke.lua`, `HC-Tradeboard/tests/ui_smoke.lua`, and `HC-Tradeboard/tests/guild_loot_smoke.lua` with a Lua test runtime (Fengari supported). The checks cover legacy/modern item tuples, all categories, delayed item caching, ring retention after Who enrichment, shared cooldown, unique Browse results, dropdown interactions, and guild notifications. The UI checks use mocked game frames; final game rendering still needs a 1.12 client check.
