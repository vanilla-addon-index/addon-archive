<img src="https://i.postimg.cc/dVsnq11F/sdfsegt.png"/>
<img src="https://i.postimg.cc/rFLQPg2P/dfgsdf.png"/>

For faster scanning check out https://github.com/brues-code/AuctionQueryThrottle

# Relationships Auction Price

**Relationships Auction Price** is a lightweight Auction House addon for **OctoWoW** that combines a powerful Auction House scanner with informative item tooltips, giving you instant access to market prices without repeatedly searching the Auction House.

Designed to stay true to the original WoW interface, Relationships Auction Price adds a compact control panel directly above the Auction House, making it easy to perform scans while keeping Blizzard's default UI clean and familiar.

## Features

### 📊 Auction House Scanner

Build your own local Auction House database by scanning current listings.

* Full Auction House scans.
* Filtered scans by **item name** or **item class**.
* Automatically records buyout prices from all scanned auctions.
* Resume interrupted scans without losing progress.
* Stores data locally for fast tooltip lookups.

Because OctoWoW uses Auction House query throttling, a **complete scan takes approximately 1 hour** to finish. This is normal and ensures reliable data collection without disconnects.

### 🏷️ Enhanced Item Tooltips

Whenever you hover over an item, RAP displays Auction House pricing information directly in the tooltip.

Tooltip information includes:

* Highest recorded unit price
* Mid-market unit price
* Lowest recorded unit price
* Age of your most recent local scan
* Whether prices are from the included shared database or your own scans

This lets you quickly judge an item's approximate market value while looting, crafting, trading, or browsing your inventory.

### 📦 Included Price Database

The addon comes with a large built-in Auction House database, allowing tooltip prices to work immediately after installation without requiring an initial scan.

**However, Auction House prices constantly change.** The included database is simply a starting point and should not be considered permanently accurate.

For the best and most up-to-date pricing, it is **strongly recommended that you perform your own manual Auction House scan** after installing the addon. Your local scan data is automatically used alongside the shared data, ensuring your tooltips reflect your server's current market whenever possible.

## Clean Integration

Relationships Auction Price integrates naturally into the default Auction House.

The scanner panel sits neatly above the Browse tab and includes:

* Name filter
* Item class filter
* One-click Scan button
* Live scan status updates

No extra windows or complicated configuration are required.

## Ideal For

* Auction House traders
* Gold makers
* Farmers
* Crafters
* Players checking item values while questing or raiding
* Anyone who wants instant market information without searching every item manually

## Notes

* ✔ Includes a large shared pricing database out of the box.
* ✔ Local scans automatically supplement and update the included data.
* ✔ Full Auction House scans take **around 1 hour** to complete.
* ✔ Prices naturally become outdated as the market changes, so regular manual scans are recommended to keep your data accurate.
* ✔ Lightweight with minimal impact on performance.

Whether you're flipping valuable items, deciding what to vendor, or simply curious about an item's worth, **Relationships Auction Price** provides quick, reliable Auction House pricing directly where you need it—inside every item tooltip.

# Chat Commands

The addon provides the following slash commands:

| Command               | Description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| `/rap scan`           | Starts a full Auction House scan using the current filters.                              |
| `/rap fast`           | Starts a faster scan with reduced delay between pages.                                   |
| `/rap continue`       | Continues the last interrupted scan from the saved checkpoint.                           |
| `/rap stop`           | Stops the current scan. Partial results are preserved.                                   |
| `/rap clear`          | Clears all locally stored price data for the current realm and faction.                  |
| `/rap stats`          | Displays statistics for local and shared price data.                                     |
| `/rap show <itemID>`  | Shows stored data for a specific item ID.                                                |
| `/rap export`         | Exports collected data into `RAP_SHARED_DATA_EXPORT` for creating a new `PriceData.lua`. |
| `/rap exportstring`   | Exports data as a legacy string stored in `RelationshipsAuctionPriceDB.export`.          |
| `/rap name <text>`    | Applies a name filter to the next scan.                                                  |
| `/rap name clear`     | Removes the name filter.                                                                 |
| `/rap class <index>`  | Applies a class filter using the Auction House class index.                              |
| `/rap class clear`    | Removes the class filter.                                                                |
| `/rap continue clear` | Deletes the saved scan checkpoint so future scans start from page 1.                     |

---

# See The Results

After completing a scan:

1. Run:

```text
/reload
```

# Exporting Price Data

After completing a scan:

1. Run:

```text
/rap export
```

2. **Reload your UI** to save the export:

```text
/reload
```

> **⚠️ Important**
>
> You **must** use `/reload` after running `/rap export`.
>
> The export is only written to your SavedVariables file when the UI reloads (or you log out). Without reloading, no export data will be saved.

3. Open:

```text
WTF/Account/<YourAccount>/SavedVariables/RelationshipsAuctionPrice.lua
```

4. Copy the entire:

```lua
RAP_SHARED_DATA_EXPORT = {
    ...
}
```

5. Paste it into:

```text
AddOns/RelationshipsAuctionPrice/PriceData.lua
```

6. Rename:

```lua
RAP_SHARED_DATA_EXPORT
```

to

```lua
RAP_SHARED_DATA
```

Your shared pricing database is now ready for distribution.

