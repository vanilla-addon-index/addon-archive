# GroupBuffToggle — developer and AI collaboration rules

**Human creative and decision-maker:** Babuni.  
**Current version:** 1.2.0 for WoW interface 11200. **License:** [MIT](LICENSE).

## Protect the small interaction concept

Group Buff Toggle is a *lightweight, optional*, native-looking information extension for the default party and target frames. Do not turn it into raid automation, buff assignment, casting/dispelling, a heavy settings window or a replacement unit-frame system without the creative's explicit direction.

The source defines two separate questions for each context:
1. **Are buff icons visible?** Party `enabled`, target `targetEnabled`.
2. **Is the corresponding Buffs checkbox visible?** `groupCheckbox`, `targetCheckbox`.

Both icon overlays **default false**; checkbox flags **default true**. Hiding a checkbox must not implicitly turn its overlay off. Preserve account-wide SavedVariables `GroupBuffsDB` and the full `/groupbuffs` commands and synonyms.

## Technical constraints and risks

- Read `GroupBuffToggle.lua`, `GroupBuffToggle.toc`, README, CONCEPT, ROADMAP, docs/ARCHITECTURE, docs/DECISIONS and docs/DEVLOG before changing implementation.
- Vanilla 1.12/Lua 5.0: uses implicit event/arg1/this and `math.mod`; modern client APIs are not a drop-in replacement.
- Supports **party1–party4**, not raid units. Frames are anchored to `PartyMemberFrame1–4` and `TargetFrame`; no guaranteed custom-unit-frame compatibility.
- Each enabled unit grid has **16 slots**, two rows of eight, 20px icons/2px spacing; `UnitBuff` supplies **texture** and GameTooltip supplies inspection. No timer/stack overlays currently.
- Party checkbox anchors under last visible populated party frame; target checkbox only appears for visible target/TargetFrame.
- Updates on load/world/party/aura events plus **0.5s periodic refresh**. Repeated repointing and scanning may be performance-sensitive in modified clients.
- This repository has an **existing MIT License**. Preserve its copyright/notice; don't incorrectly claim the project is unlicensed.
- September rename requires safe `OctoGroupBuffsDB → GroupBuffsDB` migration if older SavedVariables are present; use backups and don't run scripts on the only surviving files.

## Collaboration record and verification

For every substantial change capture creative goals, AI analysis and alternatives, creative iteration/corrections, explicit creative acceptance/rejection/deferral, actual files/commits and test results. Do not retroactively attribute the creative's original design to AI.

Testing should cover party change, target switching, tooltips, four independent switches, saved reloads and migration. Run the PowerShell fixture if environment permits; independently test intended client/version. Don't assert success based solely on source or historic release notes.

Update relevant README, CONCEPT, ROADMAP, CHANGELOG, AGENTS and docs/DEVLOG, docs/DECISIONS, docs/DESIGN, docs/ARCHITECTURE, docs/CONTENT, docs/AI_COLLABORATION with material implementations.

Do not publish raw private conversations, private SavedVariables, credentials or another player's character details. This October 27 audit is documentation-only; no behavior change is authorized.

## Repository-local documentation standard

Before writing or changing project documentation, read [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md). These rules travel with this repository and do not depend on the babuni.dev ChatGPT Project. Preserve all project-specific technical, creative, canon, safety, licensing, and historical rules in this file; follow the linked standard for public first-person narrative, human–AI attribution, concise development journals, decision records, and evidence-based verification. **Babuni** is the human creative; **babuni.dev** is the website/portfolio, not the person. Preserve third-party credits and historical legal notices. References above to a dated “documentation-only audit” describe that past task, not a permanent ban on later authorized implementation.
