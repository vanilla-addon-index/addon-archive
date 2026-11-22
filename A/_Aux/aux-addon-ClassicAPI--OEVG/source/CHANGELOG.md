# Changelog

## [1.0.4] - 2026-11-21

### Hotfixes - 2026-11-22

- Extend price tooltips to both sides of trades, plus outgoing mail and buyback on clients with the corresponding item-link APIs.
- Show stack totals for Vendor and Aux prices when Shift is held over items in the main bank slots.

### Initial release

- Show Aux auction estimates and vendor sell prices in loot roll item tooltips using the existing tooltip settings.

## [1.0.3] - 2026-11-09
- Skip the ShaguTweaks vendor-price fallback when its price table or item price is unavailable.
- Add optional local auction price sharing between accounts using Nampower. Merge price history by market and day on login and auction house close.
- Compact the Saved Searches footer buttons to clear the gold display.
- Add a scrollable Purchase Summary sidebar, grouped buying, item favorites, Clear Recent Searches, and the per-stack vendor comparison in Post.
- Guard Post settings and saved bid/buyout selections when there is no selected item.
- Add on-demand profiling for auction tooltip reads, record and display sorting, and Post bag rebuilds, with optional ClassicAPI memory snapshots.
- Reuse a ClassicAPI bag slot buffer in Post and keep the legacy reads for incomplete slot data and clients without the API. Posting eligibility and charge checks still use the existing tooltip path.
- Verified that Aux's Ctrl-click already uses the dressing-room entry point enhanced by ClassicAPI.

## [1.0.2] - 2026-11-06
- Purchase Summary rows grow to fit wrapped item names and count/price text.
- Retains the prior local tooltip, ClassicAPI vendor price, outline-drag and dark-background changes.

## [1.0.1] - 2026-09-06

Tooltip readability update preserving the existing aux pricing model and Auction House workflow.

### Tooltips

- Replaced colored decimal-style AUX money strings with Blizzard gold, silver and copper coin icons.
- Money values now use white tooltip text and right-aligned Auctionator-style positioning.
- Renamed the visible `Value:` tooltip label to `Auction:` while keeping the existing internal `settings.value` and historical pricing logic unchanged.
- Added dynamic tooltip width handling for large prices and reset the minimum width when the tooltip closes.
- Preserved integer copper display for fractional internal disenchant expectations.

### Compatibility & validation

- No changes to SavedVariables, price history, LFT `AuxData` sharing, Auction House throttling or posting behaviour.
- No new `OnUpdate` handler or permanent polling was introduced.
- Validated in-game on WoW 1.12.1 / Turtle WoW, including different price sizes and native tooltip money display.

## [1.0.0] - 2026-09-05

First formal release of the performance-focused `aux-addon-ClassicAPI` fork for World of Warcraft 1.12.1 / Turtle WoW.

### Performance

- Reworked listener bookkeeping to avoid repeated full listener scans and unregister unused events earlier.
- Thread scheduler now stops its `OnUpdate` handler when no live work remains.
- Bounded WDB item-cache scanning to avoid large synchronous warm-cache bursts.
- Replaced permanent merchant polling with one-shot deferred inventory refreshes.
- Added a daily-minimum price cache to avoid repeated SavedVariables history parsing.
- Reduced temporary allocations in historical-value calculations while preserving the existing weighted-median behaviour.
- Throttled Search, Auctions and Bids selection validation to 10 Hz instead of every frame.
- Post-tab heavy UI work now runs only when its state actually changes.
- Autopricing reuses historical-value, charge and disenchant calculations instead of repeating them.
- Reduced tooltip string work and temporary table creation.
- Auction listing rendering stops once all visible rows are filled.
- Selection lookup returns immediately after the selected auction is found.
- LFT price-sharing handling rejects unrelated traffic earlier and reuses cached daily minimums.
- Disenchant tooltip calculations are skipped when both disenchant tooltip options are disabled.

### History & LFT sharing

- Preserved the existing daily-minimum history format and SavedVariables schema.
- `Today` remains the lowest known unit buyout for the current day.
- `Value` remains the long-term historical reference based on up to 11 daily values and an age-weighted median.
- Compatible `AuxData,<item_key>,<unit_buyout_price>` messages received through LFT can update the current daily minimum.
- Searches of 15 pages or more are not broadcast through LFT to reduce channel traffic.
- Embedded ChatThrottleLib behaviour is intentionally unchanged.

### Auction House behaviour

- Auction House server request throttling and query delays are intentionally unchanged.
- Bid, Buyout and Cancel actions retain synchronous validation before execution.
- Existing posting formulas, undercut rules and pricing thresholds are preserved.
- Existing auction grouping, sorting and expand/collapse behaviour is preserved.

### Tooltips & item handling

- Preserved normal tooltip text, colors, requirements and durability checks.
- Durability scanning is only performed where strict auctionability checks require it.
- Optional disenchant value and distribution output remains unchanged when enabled.

### Documentation

- Reworked the README in a compact ShaguTweaks-style format.
- Added documentation for `Value` vs `Today`, LFT price sharing, commands, shortcuts and performance changes.
- Corrected documented posting durations to 6 / 24 / 72 hours.
- Clarified that the repository currently has no hard ClassicAPI dependency and that ShaguTweaks remains optional.

### Validation

The performance changes were tested incrementally in-game on WoW 1.12.1 / Turtle WoW, including Auction House search, Real Time mode, Bid, Buyout, Cancel, Post, merchant updates, tooltips, history and LFT sharing paths.
