-- SIM DPS button, progress bar, result tooltip, settings, combat log and cancel.
local AB, S = AshenBuilds, AshenSim
local lines = {}
GameTooltip.AddLine = function(self, t) table.insert(lines, t) end
GameTooltip.AddDoubleLine = function(self, a, b) table.insert(lines, a .. " | " .. b) end
GameTooltip.SetText = function(self, t) lines = {t} end

SlashCmdList["ASHENBUILDS"]("")
check("sim panel exists", AB.simPanel ~= nil)
local b = AB.current
b.class = "Warrior"; b.race = "Human"; b.level = 60
b.items = {HEAD = 12640, NECK = 15411, SHOULDER = 12927, BACK = 13340, CHEST = 11726, WRIST = 12936, HANDS = 14551, WAIST = 13959,
  LEGS = 15062, FEET = 14616, FINGER1 = 17713, FINGER2 = 13098, TRINKET1 = 11815, TRINKET2 = 13965, MAINHAND = 12940, OFFHAND = 15806}
b.enchants = {MAINHAND = 10, OFFHAND = 10}
AB:RefreshUI()
S.Warrior.GetSettings().iterations = 200

Click(AB.simPanel.run)
check("running after SIM DPS", S.IsRunning() and AB.simPanel.run:GetText() == "CANCEL")
local frames, sawBar = 0, false
while S.IsRunning() and frames < 5000 do
  RunFrame(); frames = frames + 1
  if AB.simPanel.bar:IsShown() and string.find(AB.simPanel.bar.text:GetText() or "", "%%") then sawBar = true end
end
check("progress bar shows a percentage", sawBar)
check("spread over several frames", frames > 1)
check("finishes", not S.IsRunning())
local value = AB.simPanel.result.value:GetText() or ""
check("shows the DPS", string.find(value, "DPS") ~= nil)

AB.simPanel.result:GetScript("OnEnter")()
local text = table.concat(lines, "\n")
check("tooltip has the damage breakdown", string.find(text, "DAMAGE") and string.find(text, "Main Hand"))
check("tooltip has the attack table and rage", string.find(text, "ATTACK TABLE") and string.find(text, "RAGE PER FIGHT"))

local first = value
Click(AB.simPanel.run); while S.IsRunning() do RunFrame() end
check("same build and settings give the same result", AB.simPanel.result.value:GetText() == first)

b.enchants.OFFHAND = nil; AB:RefreshUI()
check("changing the build marks the result stale", string.find(AB.simPanel.result.sub:GetText() or "", "Build changed") ~= nil)
Click(AB.simPanel.run); while S.IsRunning() do RunFrame() end
AB.simPanel.result:GetScript("OnEnter")()
check("paired comparison shown after a build change", string.find(table.concat(lines, "\n"), "Change vs last build") ~= nil)

AB:OpenSimSettings()
check("settings window opens", AB.simSettingsFrame and AB.simSettingsFrame:IsShown())
AB:ShowSimLog()
check("combat log opens with a fight", AB.simLogFrame:IsShown() and string.find(AB.simLogFrame.edit:GetText() or "", "Fight 1") ~= nil)

Click(AB.simPanel.run); Click(AB.simPanel.run)
check("cancel stops the run", not S.IsRunning())
b.class = "Mage"; AB:RefreshUI()
check("unsupported class says so", string.find(AB.simPanel.result.sub:GetText() or "", "Mage sim coming later") ~= nil)
