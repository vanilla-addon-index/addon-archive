# GroupBuffToggle — decisions register and alternatives

**Creative decision authority:** Babuni.dev. **Historical evidence:** dated Git diffs, existing README and source, not recovered private meeting transcripts.

## Visible implemented choices

| Date and evidence | Decision embodied by source | Scope |
| --- | --- | --- |
| Sep 10, `31411b3` | Put opt-in party and target **buff** icons beside the native frames | 16 icons per unit, 4 party + target |
| Sep 10, `31411b3` | **Both overlays default off**, separate checkboxes | Respect existing screen space |
| Sep 10, `c20bc18` | Add checkbox visibility as two independent preferences | Four keys instead of two, no coupling |
| Sep 10, `c20bc18` | Expand `/groupbuffs` from single toggle to explicit four-control commands | Named on/off/toggle and aliases |
| Sep 18, `59f9250` | Rename Octo Group Buff Toggle to provider-neutral Group Buff Toggle | Changed root SavedVariables; add migration |
| Oct 26, `6fd3590` | Update MIT copyright pseudonym to Babuni.dev | Explicit license preserved |

The Git dates support these changes. They do not establish which alternatives were considered in private or any specific earlier AI authorship.

## Tradeoffs visible in current design

**Checkbox vs icon-overlay independence.** Hiding the control does not hide the data. This supports minimalist UI arrangements but can be confusing unless documented. The README is corrected accordingly.

**Defaults.** The two buff displays default off, so install doesn't unexpectedly fill the screen. Checkbox visibility defaults on only when unit-frame context exists.

**Fixed native anchors.** Placing content near Blizzard party/target frames is simple and natural but creates a compatibility boundary with custom unit-frame replacements.

**Fixed 16-icon cap.** Two rows of eight produce predictable geometry. Additional buffs, stacks and expiry information are not shown.

**Event + 0.5s poll.** Occasional polling protects against events/visibility changes that don't arrive as expected in old clients, but means regular periodic work even when content is unchanged.

**Account-wide settings.** Same four preferences apply to every character; separate character profiles aren't part of today's design.

**Open source under MIT.** Unlike repositories missing licenses, this addon intentionally includes MIT terms. Current notice credits Babuni.dev; its legal terms are not to be silently altered by an AI collaborator.

## Pending questions — no implied approval

Should durations/stacks be displayed, or would that clutter the deliberately small strip? Should a user be able to change the icon count/size? Should a config window replace slash command controls? Would per-character profiles help? Should raid/custom party frames be supported? Should the poll become fully event-driven? These are creator decisions after tests, not items accepted in this session.

**Known source/document discrepancy resolved:** “two settings” in the previous README described only old display toggles, but current code has four persistent flags. The documentation edit clarifies this; there was **no functional code change**.
