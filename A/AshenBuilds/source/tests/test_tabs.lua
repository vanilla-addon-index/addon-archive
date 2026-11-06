-- Tabs: Talents, Item Database, Saved Builds and Community are pages inside the main window.
local AB = AshenBuilds
SlashCmdList["ASHENBUILDS"]("")
local oldSet = AB.SetTabActive
AB.SetTabActive = function(self, b, on) b._tabActive = on; return oldSet(self, b, on) end
AB:RefreshTabStates()
local function planner() return AB.plannerPage:IsShown() end
local function active(b) return b._tabActive end

check("starts on the planner", planner() and active(AB.plannerButton))
check("pages live inside the main window", AB.talentFrame:GetParent() == AB.frame and AB.itemBrowser:GetParent() == AB.frame
  and AB.buildBrowser:GetParent() == AB.frame and AB.communityFrame:GetParent() == AB.frame)
check("gear, stats and SIM DPS belong to the Planner page", AB.slotButtons.HEAD:GetParent() == AB.plannerPage and AB.simPanel:GetParent() == AB.plannerPage)
check("talent trees fit without scaling", AB.talentFrame:GetScale() == 1 and AB.frame:GetWidth() >= AB.talentFrame:GetWidth())

Click(AB.talentOpenButton)
check("Talents tab hides the planner", AB.talentFrame:IsShown() and not planner() and active(AB.talentOpenButton) and not active(AB.plannerButton))
Click(AB.communityButton)
check("Community replaces Talents", AB.communityFrame:IsShown() and not AB.talentFrame:IsShown())
Click(AB.savedBuildsButton)
check("Saved Builds replaces Community", AB.buildBrowser:IsShown() and not AB.communityFrame:IsShown())
Click(AB.itemDatabaseButton)
check("Item Database replaces Saved Builds", AB.itemBrowser:IsShown() and not AB.buildBrowser:IsShown())
check("full height while a page is open", AB.frame:GetHeight() == 900)
for _, w in ipairs({AB.itemBrowser, AB.buildBrowser, AB.communityFrame}) do
  local pts = {}
  for _, q in ipairs(w._points or {}) do table.insert(pts, q[1]) end
  check(w:GetName() .. " fills the page area", table.concat(pts, ",") == "TOPLEFT,BOTTOMRIGHT")
end
Click(AB.plannerButton)
check("Planner tab returns to the planner", planner() and not AB.itemBrowser:IsShown() and active(AB.plannerButton))

Click(AB.slotButtons.HEAD)
check("a gear slot opens the Item Database for it", AB.itemBrowser:IsShown() and AB.browserSlot == "HEAD")
local row = AB.itemRows[1]
if row and row.itemID then Click(row) end
check("picking an item returns to the planner", planner() and AB.current.items.HEAD ~= nil)

local found = false
for _, n in ipairs(UISpecialFrames) do if n == "AshenBuildsItemBrowser" or n == "AshenBuildsTalentFrame" then found = true end end
check("Escape closes the planner, not a single page", not found)

local function walk(f, lvl, bad)
  for _, k in ipairs({f:GetChildren()}) do
    if k:GetFrameLevel() <= lvl then table.insert(bad, k) end
    walk(k, k:GetFrameLevel(), bad)
  end
end
for _, w in ipairs({AB.talentFrame, AB.communityFrame, AB.buildBrowser, AB.itemBrowser}) do
  local bad = {}; walk(w, w:GetFrameLevel(), bad)
  check(w:GetName() .. " contents draw above it", table.getn(bad) == 0)
end

local dressed = 0
local oldSV = AB.SetStatsView
AB.SetStatsView = function(self, v) if v == "preview" then dressed = dressed + 1 end; return oldSV(self, v) end
AB:SetStatsView("preview"); dressed = 0
Click(AB.talentOpenButton); Click(AB.plannerButton)
check("3D preview is dressed again on return", dressed == 1)
