--                MODULE        SUBGROUP       ENTRY               VALUE
-- pfUI:UpdateConfig("module_template", nil, nil, 0)

-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

function pfUI.autoinvite:LoadConfig()
  pfUI:UpdateConfig("autoinvite", nil,           "state",            "0")
  pfUI:UpdateConfig("autoinvite", nil,           "match_case",       "0")
  pfUI:UpdateConfig("autoinvite", nil,           "gchat",            "0")
  pfUI:UpdateConfig("autoinvite", nil,           "wchat",            "1")
  pfUI:UpdateConfig("autoinvite", nil,           "guild_only",       "1")
  pfUI:UpdateConfig("autoinvite", nil,           "group_type",       "raid")
  pfUI:UpdateConfig("autoinvite", nil,           "phrase",           "")
  pfUI:UpdateConfig("autoinvite", nil,           "notification",     "1")
  pfUI:UpdateConfig("autoinvite", nil,           "reset_on_login",   "1")
  pfUI:UpdateConfig("autoinvite", nil,           "reloading",        "0")
end

pfUI.autoinvite:LoadConfig()

-- Keep autoinvites on through /reload, but turn them off on any other login
-- (logout, disconnect, crash, client restart). A reload is the only case that
-- goes through ReloadUI(), so flag it there; the flag is saved with the config.
if C.autoinvite.reset_on_login == "1" and C.autoinvite.reloading ~= "1" then
  C.autoinvite.state = "0"
end
C.autoinvite.reloading = "0"

local ReloadUI_orig = ReloadUI
_G.ReloadUI = function(a1, a2, a3)
  C.autoinvite.reloading = "1"
  return ReloadUI_orig(a1, a2, a3)
end
