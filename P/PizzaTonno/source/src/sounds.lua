local PT = PizzaTonno
PT.sounds = {}

-- FishingBuddy's mix: the bobber's splash over music and birdsong.
local FISHING = { SoundVolume = '1', MusicVolume = '0', AmbienceVolume = '0' }

-- The player's own volumes wait in the saved variables, so a logout while fishing can't lose them.
function PT.sounds.start()
  if not PizzaTonno_config.sounds or IsAddOnLoaded('FishingBuddy') then return end

  if not PizzaTonno_config.soundsBefore then
    local before = {}
    for cvar in pairs(FISHING) do before[cvar] = GetCVar(cvar) end
    PizzaTonno_config.soundsBefore = before
  end
  for cvar, value in pairs(FISHING) do SetCVar(cvar, value) end
end

local function restore()
  for cvar, value in pairs(PizzaTonno_config.soundsBefore or {}) do SetCVar(cvar, value) end
end

function PT.sounds.stop()
  restore()
  PizzaTonno_config.soundsBefore = nil
end

-- Restored for the next session but still kept: login puts the fishing mix back if the pole is on
-- and forgets them otherwise.
local frame = CreateFrame('Frame')
frame:RegisterEvent('PLAYER_LOGOUT')
frame:SetScript('OnEvent', restore)
