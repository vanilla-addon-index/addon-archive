AutoQuest = AutoQuest or {}

-- Default values
local defaults = {
  debug = false,
  autoAccept = true,
  autoReward = true,
  autoRewardUnusableOnly = true,
  followTourGuide = true,
}

function AutoQuest:InitSettings()
  AutoQuestCharDB = AutoQuestCharDB or {}
  AutoQuest.Settings = AutoQuestCharDB
  
  setmetatable(AutoQuest.Settings, {
    __index = defaults
  })

  self.SettingsDefaultValues = defaults
  self.SavedVariablesInit = true
end

function AutoQuest:ResetSettings()
  AutoQuestCharDB = {}
  AutoQuest:InitSettings()
end

-- Getter
function AutoQuest:GetSetting(setting)
    return self.Settings[setting]
end

-- Setter
function AutoQuest:SetSetting(setting, value)
  self.Settings[setting] = value
end