# QuestHaste

## Intro

QuestHaste is a small addon for vanilla World of Warcraft (1.12). It automatically accepts available quests and advances completed quests without requiring modifier keys.

Hold Shift while interacting with an NPC to pause automatic quest actions.

When a quest reaches the final reward pane, QuestHaste stops only if there is a reward choice.

## Behavior

When opening an NPC quest or gossip window, QuestHaste selects quests in this order:

1. Completed active quest
2. First available quest
3. First active quest

Quest pages are handled automatically:

| Page | Action |
| :--- | --- |
| Quest detail | Accepts the quest |
| Quest progress | Completes the quest if objectives are done |
| Quest reward | Completes automatically unless there is a reward choice |

## Chat Commands

| Command | Action |
| :--- | --- |
| `/qhaste usage` | Display usage instructions |
| `/qhaste pause` | Disable QuestHaste |
| `/qhaste resume` | Activate QuestHaste |
| `/qhaste complete` | Advance the currently visible quest dialog |

## Thanks

JuuJuu

## Change Log

### Version 0.4

* Added missing NPC dialog type.
* Now scans QuestLog for completed quests when opening a NPC dialog.
* Fixed error message for quests with reward choice.
