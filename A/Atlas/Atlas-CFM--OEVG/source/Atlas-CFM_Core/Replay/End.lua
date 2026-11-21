---
--- Replay\End.lua - [Atlas-CFM split] last file of Atlas-CFM_Core.
--- Restores the original CreateFrame (see Replay\Begin.lua). The startup event
--- replay itself is run by the stub once this addon has finished loading.
---

local R = AtlasCFM and AtlasCFM._Replay
if R and R.origCreateFrame then
    CreateFrame = R.origCreateFrame
end
