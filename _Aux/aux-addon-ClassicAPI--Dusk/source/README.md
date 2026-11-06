# 🪙 aux — ClassicAPI

A performance-focused fork of **aux** for **World of Warcraft 1.12.1 / Turtle WoW**.

Focused on **stability, compatibility and lower runtime overhead** while keeping the original aux Auction House workflow intact.

> Despite the repository name, aux currently has **no hard ClassicAPI dependency**. `ShaguTweaks` remains optional and is only used as a vendor-value fallback when available.

## 🔌 Requirements

- **World of Warcraft 1.12.1 / Turtle WoW**
- Do not load another copy of aux at the same time
- **ShaguTweaks** — optional

## 📦 Installation

1. Download or clone the repository.
2. Rename the addon folder to **`aux-addon`**.
3. Copy it to:

```text
World of Warcraft\Interface\AddOns\aux-addon
```

4. Restart the game.

> The folder name must be `aux-addon` so it matches `aux-addon.toc`.

## ✨ Main changes

This fork keeps aux's original behaviour and focuses on targeted low-risk improvements:

- Bounded WDB item-cache scanning to avoid large synchronous warm-cache bursts.
- Merchant bag-value refresh changed from permanent polling to one-shot deferred updates.
- Reduced listener and scheduler bookkeeping overhead.
- Daily Auction House minimum cache to avoid repeated SavedVariables parsing.
- Reduced allocations in historical-value calculations.
- Search, Auctions and Bids validation throttled to **10 Hz** instead of every frame.
- Post-tab heavy UI work only runs when something actually changes.
- Autopricing reuses historical, vendor-charge and disenchant calculations.
- Reduced tooltip scans and temporary table creation.
- Auction-listing rendering stops once all visible rows are filled.
- Selection lookup returns immediately once the selected auction is found.
- LFT price-sharing handler rejects unrelated traffic earlier and reuses cached daily minimums.
- Disenchant tooltip calculations are skipped when both disenchant tooltip options are disabled.

aux keeps the native Auction House query flow and waits for `CanSendAuctionQuery()` before requesting the next page. Optional client-side tools such as **[AuctionQueryThrottle](https://github.com/brues-code/AuctionQueryThrottle)** can reduce the vanilla 5-second client-side query delay on compatible servers. **Server-side rate limits still apply.** Embedded **ChatThrottleLib** remains unchanged for safe LFT price sharing.

## 🏛️ Auction House Features

### Search

- Automatic multi-page scanning
- Saved and favorite searches
- Search-history navigation
- Advanced filters and autocompletion
- Sorting across all scanned pages
- Historical-value percentage sorting
- Unit / stack price switching
- Quick Bid / Buyout
- Real Time mode
- Purchase Summary

### Post

- Automatic stack assembly and posting
- Existing-auction scan
- One-click undercut selection
- Per-item posting settings
- Optional bid-price listing
- Saved stack sizes
- Vendor and disenchant safeguards used by autopricing

### Auctions & Bids

- Dedicated active-auction and bid listings
- Quick Cancel / Bid / Buyout validation
- Grouped auction rows with expand / collapse support

## 📊 Price History

aux stores market information using two separate values:

- **Today** — the lowest unit buyout known for the current day
- **Value** — the long-term historical reference calculated from daily values

The daily minimum can come from your own Auction House scans or from compatible `AuxData` messages received through **LFT** when sharing is enabled.

At daily rollover, the minimum becomes a historical data point. aux keeps up to **11 daily values** and calculates an **age-weighted median** to keep the result stable without allowing repeated same-day scans to dominate the history.

Enable both tooltip values with:

```text
/aux tooltip value
/aux tooltip daily
```

## 🔗 LFT Price Sharing

Price sharing is enabled by default.

Toggle it with:

```text
/aux sharing
```

Messages use the format:

```text
AuxData,<item_key>,<unit_buyout_price>
```

Only a lower daily minimum is stored. Searches of **15 pages or more are not broadcast** to reduce LFT channel traffic.

## 🎨 Themes

aux includes two interface styles:

- **Blizzard** — default Blizzard-like theme
- **Modern** — original-style modern theme

Switch with:

```text
/aux theme
```

### Blizzard-like Theme

![Main Screen](https://i.imgur.com/8HTsH2D.png)
![Search Screen](https://i.imgur.com/iwrPHIE.png)
![Post Screen](https://i.imgur.com/mBVV7cf.png)

## 📝 Commands

| Command | Function |
|---|---|
| `/aux` | Show current settings |
| `/aux scale <factor>` | Change UI scale |
| `/aux undercut` | Toggle automatic undercutting |
| `/aux ignore owner` | Toggle waiting for auction owner names |
| `/aux post bid` | Toggle bid-price listing in Post |
| `/aux post duration 6` | Set 6-hour default duration |
| `/aux post duration 24` | Set 24-hour default duration |
| `/aux post duration 72` | Set 72-hour default duration |
| `/aux post stack` | Toggle saved stack size per item |
| `/aux crafting cost` | Toggle crafting-cost information |
| `/aux sharing` | Toggle LFT price sharing |
| `/aux theme` | Toggle Blizzard / Modern theme |
| `/aux show hidden` | Toggle hidden Post items |
| `/aux purchase summary` | Toggle Purchase Summary |
| `/aux tooltip value` | Toggle historical Value |
| `/aux tooltip daily` | Toggle Today value |
| `/aux tooltip merchant buy` | Toggle vendor-buy value |
| `/aux tooltip merchant sell` | Toggle vendor-sell value |
| `/aux tooltip disenchant value` | Toggle disenchant value |
| `/aux tooltip disenchant distribution` | Toggle disenchant distribution |
| `/aux clear item cache` | Clear aux item cache |
| `/aux populate wdb` | Populate local item cache |

## 🖱️ Useful Shortcuts

- **Double-click** a grouped auction row to expand / collapse it
- **Alt + Left-Click** selected row for Buyout / Cancel
- **Alt + Right-Click** selected row for Bid / Cancel
- **Right-Click** a row to search for that item
- **Ctrl + Click** a row to preview supported items
- **Shift + Click** a row to copy its link to chat
- **Left-Click** a header to sort
- **Right-Click** a price header to switch unit / stack pricing
- **Tab** accepts search autocompletion

## 🔎 Search Filters

Queries are separated by `;`, while individual filter parts use `/`.

Examples:

```text
felcloth/exact/stack/5
recipe/usable/not/libram
armor/cloth/50/intellect/stamina
```

The built-in **Filter Builder** can be used as a visual tutorial for more advanced filters and logical operators.

## ⚙️ Compatibility

- World of Warcraft 1.12.1
- Turtle WoW-style Auction House behaviour
- Turtle WoW custom-item cache / autocompletion support
- Optional ShaguTweaks vendor-value fallback
- Optional AuctionQueryThrottle support for faster client-side paging on compatible servers
- Existing aux SavedVariables format preserved
- Existing LFT `AuxData` message format preserved

## ⚠️ Notes

- aux follows the normal `CanSendAuctionQuery()` flow. AuctionQueryThrottle can remove the vanilla client-side 5-second floor on compatible servers, but **server-side throttles still apply**.
- `Today` is the **lowest price seen today**, not simply the most recently scanned listing.
- Turtle WoW deposit costs can differ from the locally displayed estimate.
- ChatThrottleLib is kept intact for safe chat-rate handling.

## 📸 Additional Screenshots

### Search Results

![Search Results](http://i.imgur.com/hI6ODqM.png)

### Saved Searches

![Saved Searches](http://i.imgur.com/dICDnxR.png)

### Filter Builder

![Filter Builder](http://i.imgur.com/8hilZc9.png)

## 🙏 Credits

Original **aux** by **shirsig**.

Turtle WoW adaptation and previous maintenance from **Otari98/aux-addon** and its contributors.

Blizzard-like theme by **Oldmana**.

Performance-focused maintenance of this fork by **Dusk-92**.
