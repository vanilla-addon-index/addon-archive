-- Community sync hardening: bad messages, version notice, channel opt-out, moderation.
local AB = AshenBuilds
local printed = {}
AB.Print = function(msg) table.insert(printed, msg) end

-- A message that makes the handler fail must not raise an error for the receiver.
local real = AB.HandleCommunityMessage
AB.HandleCommunityMessage = function() error("boom") end
local ok = pcall(FireEvent, "CHAT_MSG_ADDON", "ASHB", "P~x", "GUILD", "Griefer")
check("a failing message is dropped silently", ok)
AB.HandleCommunityMessage = real
local garbage = {"", "~", "P", "P~~~~~", "Q~zz~~~~~", "X~a~b~!!!,.,..", "Y~a~b~1", "F~~~~~", "V~a~b~1~notanumber", "R~Me~???", string.rep("~", 400)}
local allOk = true
for _, m in ipairs(garbage) do if not pcall(FireEvent, "CHAT_MSG_ADDON", "ASHB", m, "GUILD", "Fuzzer") then allOk = false end end
check("malformed messages never raise errors", allOk)

-- Newer version in someone's sync request: tell the player once.
printed = {}
FireEvent("CHAT_MSG_ADDON", "ASHB", "Q~1~1~1~99.0.0", "GUILD", "Newer")
FireEvent("CHAT_MSG_ADDON", "ASHB", "Q~1~1~1~99.0.0", "GUILD", "Newer2")
local notices = 0
for _, m in ipairs(printed) do if string.find(m, "newer Ashen Builds") then notices = notices + 1 end end
check("newer version announced once", notices == 1)
printed = {}
FireEvent("CHAT_MSG_ADDON", "ASHB", "Q~1~1~1~0.9.7", "GUILD", "Older")
check("older versions do not trigger the notice", table.getn(printed) == 0)
check("version is 1.0.0", AB.VERSION == "1.0.0")

-- Opting out of the realm channel.
local left = false
LeaveChannelByName = function() left = true end
GetChannelName = function() return 5 end
AB:SetChannelSync(false)
check("/ab sync off saves the setting", AshenBuildsDB.settings.syncChannel == false and not AB:IsChannelSyncOn())
check("/ab sync off leaves the channel", left)
local sent = 0
SendChatMessage = function() sent = sent + 1 end
AB:RequestCommunitySync(true)
for i = 1, 5 do RunFrame(2) end
check("nothing is sent to the channel when off", sent == 0)
AB:SetChannelSync(true)
check("/ab sync on turns it back on", AB:IsChannelSyncOn())
GetChannelName = function() return 0 end

-- Moderation: hidden players and flagged names are not listed; search matches what is shown.
local c = AshenBuildsDB.community
local function add(author, name) c.builds[author .. ":" .. name] = {author = author, name = name, ver = time(), seen = time(), code = "x", confirmed = true, level = 60, race = "Human", class = "Warrior", spec = "Arms"} end
add("Friendly", "Fury Raid Build"); add("Spammer", "Buy Gold Build"); add("Rude", "Fucking Fury")
local function names()
  local t = {}
  for _, e in ipairs(AB:GetFilteredCommunityBuilds()) do t[e.name] = true end
  return t
end
local before = names()
check("flagged build names are hidden", not before["Fucking Fury"])
check("normal builds are listed", before["Fury Raid Build"] and before["Buy Gold Build"])
AB:HideAuthor("Spammer", true)
check("hiding a player removes their builds", not names()["Buy Gold Build"])
SlashCmdList["ASHENBUILDS"]("unhide spammer")
check("/ab unhide shows them again", names()["Buy Gold Build"])
