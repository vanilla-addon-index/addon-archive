# Changelog

## 0.1.5 - 2026-11-06

- Create Order: duration 7 days in addition to 24 and 48 hours; time left of 48 hours and more reads in days ("6d 23h").
- Statistics: a left filter list like Browse (Volume / Fulfillment / Payment, All Time / 30 Days / 7 Days); the bottom bar shows the current choice and Close.
- Deliver and Retry ask first and say exactly what is sent (quantity, item, buyer, total C.O.D., number of mails); option "Confirm before delivering" (on by default).
- My Orders: Mark Received and Cancel Remaining explain themselves on hover, also while they are greyed out.
- Browse: clicking the deliver quantity selects it, so typing replaces the prefilled maximum.

## 0.1.4 - 2026-11-06

- Item tooltips list the open guild orders of the item: total open, best unit price and buyer, plus the top three orders (your own are marked). Works in bags, bank, character, loot, vendor, auction, trade, mail, crafting and chat links. Option "Show guild orders in item tooltips" (on by default).

## 0.1.3 - 2026-11-06

- Browse: the Deliv., Payout and Expires columns are shown (they stayed empty before).
- Browse: your own orders are marked "Yours" and are never deliverable (you cannot mail yourself); "Deliverable only" hides them.
- Browse: an order you cannot deliver right now shows its total value in grey under Payout.
- Options window: the empty slots of the bottom bar show the version and the buttons Defaults and Reset.

## 0.1.2 - 2026-11-06

- Options window in the Auction House style, with a UI scale slider (0.7 to 1.3, saved, applied live).
- Mailbox full: a refused delivery shows "Mailbox Full" and the rejected stack is taken out of the send slot.
- Orders can be cancelled while deliveries are in transit. Deliveries sent before the cancel stay valid, later ones are a mismatch.
- The window that the mailbox opened closes with the mailbox; a window you opened yourself stays open.
- Data is guild-scoped: orders and history are stored per realm and guild. A character without a guild has no market ("Join a guild to use EGM"). Orders of players who are not guild members are hidden, and nothing is relayed before the guild roster is known.

## 0.1.1 - 2026-11-05

- The trace export only runs with `/egm debug`.
- Create Order: delivery note at the bottom of the result list, 13 result rows.
- Inbox: the client's "(COD)" subject prefix is stripped so C.O.D. deliveries are recognized.
- Paying or returning a C.O.D. through the normal mailbox is recorded; "Mark Received" in My Orders for deliveries paid before EGM saw them.
- Statistics: meter layout with class colors, ranks and tooltips; online status updates at once.
- Fixes: addon messages no longer contain a bare pipe (WoW refused them), attaching works with other mail addons, item icon and stack size read in the 1.12 order.

## 0.1.0 - 2026-11-05

- First version: guild buy orders with C.O.D. delivery, event journal with guild sync, C.O.D. mail queue and inbox validation, Auction House style window with Browse, Create Order, My Orders and Statistics, minimap button and options.
