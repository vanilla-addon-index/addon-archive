-- Community sync delivery: catch-up answers, send priority, repeats, length cap, status.
local AB = AshenBuilds
local sent = {}
AB.Print = function() end
GetChannelName = function() return 5, "AshenBuilds" end
SendChatMessage = function(msg) table.insert(sent, string.sub(msg, 8)) end
local function Pump(seconds) for i = 1, seconds do CLOCK = CLOCK + 1; RunFrame(1) end end
local function Channel(msg, from) FireEvent("CHAT_MSG_CHANNEL", "~ASHB1~" .. msg, from, "Common", "5. AshenBuilds", "", "", 0, 5, "AshenBuilds") end
local function Count(kind, name)
  local n = 0
  for _, m in ipairs(sent) do
    if string.sub(m, 1, 2) == kind .. "~" and (not name or string.find(m, "~" .. name .. "~", 1, true)) then n = n + 1 end
  end
  return n
end

FireEvent("PLAYER_ENTERING_WORLD"); Pump(30)
AB.current.class = "Warrior"; AB.current.race = "Human"; AB.current.level = 60
AshenBuildsDB.builds = AshenBuildsDB.builds or {}
local function Save(name) local b = AB:DeepCopy(AB.current); b.name = name; AshenBuildsDB.builds[name] = b end
Save("Fury Raid")

-- Publishing goes out at once and is repeated, so one lost message doesn't lose it.
sent = {}
AB:PublishBuild("Fury Raid"); Pump(2)
check("publish is sent right away", Count("P", "Fury Raid") == 1)
Pump(300)
check("publish is repeated twice more", Count("P", "Fury Raid") == 3)

-- The author answering a catch-up request includes their own builds, even while
-- their periodic re-announce is still cooling down.
Pump(1000)
Channel("Q~0~0~0~1.0.0", "Dave"); Pump(90)
Pump(660)
sent = {}
Channel("Q~0~0~0~1.0.0", "Casey"); Pump(90)
check("the author's answer names the requester", Count("R") == 1)
check("the author's answer carries their own build", Count("P", "Fury Raid") >= 1)

-- A publish jumps ahead of relay traffic already waiting to go out.
local c = AshenBuildsDB.community
local code = c.builds["Tester:Fury Raid"].code
for i = 1, 30 do
  c.builds["Other" .. i .. ":Build"] = {id = "Other" .. i .. ":Build", author = "Other" .. i, name = "Build", ver = time(), code = code, confirmed = true, seen = time()}
end
Pump(700); sent = {}
Channel("Q~0~0~0~1.0.0", "Erin"); Pump(20)
Save("Prot Tank"); AB:PublishBuild("Prot Tank"); Pump(3)
local position
for i, m in ipairs(sent) do if string.find(m, "~Prot Tank~", 1, true) and string.sub(m, 1, 2) == "P~" then position = i end end
check("publish goes out within a couple of messages", position and position <= Count("F") + 3 and Count("F") < 25)

-- Withdrawing is repeated too, and a republish cancels the pending repeats.
Pump(400); sent = {}
AB:UnpublishBuild("Prot Tank"); Pump(2)
check("withdrawal is sent right away", Count("U", nil) == 1)
Pump(100)
check("withdrawal is repeated", Count("U", nil) == 2)
AB:PublishBuild("Prot Tank"); Pump(300)
check("no withdrawal after the build is published again", Count("U", nil) == 2)

-- Messages too long to arrive intact are not sent at all.
Pump(400); sent = {}
local addon = 0
local realAddon = SendAddonMessage
IsInGuild = function() return 1 end
SendAddonMessage = function() addon = addon + 1 end
AB:ToggleVote("Other1:Build"); Pump(2)
check("votes use guild and channel", addon == 1 and Count("V") == 1)
c.builds["Tester:" .. string.rep("N", 32)] = {id = "Tester:" .. string.rep("N", 32), author = "Tester", name = string.rep("N", 32), ver = time(), code = string.rep("x", 230), confirmed = true, seen = time()}
addon = 0; sent = {}
AB:PublishBuild(string.rep("N", 32))
Pump(5)
check("an over-long message is not sent on any channel", addon == 0 and Count("P", string.rep("N", 32)) == 0)
IsInGuild = function() return nil end; SendAddonMessage = realAddon
Channel("Q~0~0~0~1.0.0", "Casey")

-- /ab sync status reports who we can reach.
local s = AB:GetSyncStatus()
check("status: channel joined", s.channel == "joined")
local heard = {}
for _, p in ipairs(s.peers) do heard[p.name] = p end
check("status: lists players heard on the channel", heard["Casey"] and heard["Casey"].via == "channel" and heard["Casey"].version == "1.0.0")
FireEvent("CHAT_MSG_ADDON", "ASHB", "Q~0~0~0~1.0.0", "GUILD", "Guildie")
heard = {}
for _, p in ipairs(AB:GetSyncStatus().peers) do heard[p.name] = p end
check("status: lists guild players", heard["Guildie"] and heard["Guildie"].via == "guild")
check("status: prints without errors", pcall(AB.PrintSyncStatus, AB))
check("/ab sync status works", pcall(SlashCmdList["ASHENBUILDS"], "sync status"))
