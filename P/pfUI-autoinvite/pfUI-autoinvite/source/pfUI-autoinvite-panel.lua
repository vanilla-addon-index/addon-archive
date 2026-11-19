-- Panel entry for pfUI's info panels (bottom left/right bars, minimap bar).
-- Pick "Auto Invite" in pfUI Config > Panel for any panel slot.
-- Shows whether autoinvites are on; left click toggles them (same as /pfai),
-- right click opens the Auto Invite page of the pfUI config.

-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

if not pfUI.autoinvite then return end

local ENTRY = "autoinvite"
local LABEL = "Auto Invite"

-- offer the entry in the panel dropdowns of the config GUI
if pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.panel_values then
  local values, found = pfUI.gui.dropdowns.panel_values, nil
  for _, v in pairs(values) do
    if string.find(v, "^" .. ENTRY .. ":") then found = true end
  end
  if not found then table.insert(values, ENTRY .. ":" .. LABEL) end
end

if pfUI.panel and pfUI.panel.options then
  table.insert(pfUI.panel.options, ENTRY)
end

local function Tooltip()
  local c = C.autoinvite
  GameTooltip:ClearLines()
  GameTooltip_SetDefaultAnchor(GameTooltip, this)
  GameTooltip:AddLine("|cff555555" .. LABEL)
  GameTooltip:AddDoubleLine("Status", c.state == "1" and "|cff33ff33Enabled" or "|cffff5555Disabled")
  GameTooltip:AddDoubleLine("Phrase", c.phrase ~= "" and ("|cffffffff" .. c.phrase) or "|cffff5555not set")
  GameTooltip:AddDoubleLine("Group Type", "|cffffffff" .. (c.group_type == "party" and "Party" or "Raid"))
  local scan = {}
  if c.wchat == "1" then table.insert(scan, "Whispers") end
  if c.gchat == "1" then table.insert(scan, "Guild") end
  GameTooltip:AddDoubleLine("Scanning", "|cffffffff" .. (table.getn(scan) > 0 and table.concat(scan, ", ") or "nothing"))
  GameTooltip:AddDoubleLine("Guild Only", "|cffffffff" .. (c.guild_only == "1" and "Yes" or "No"))
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("Left Click", "|cffffffffEnable/Disable")
  GameTooltip:AddDoubleLine("Right Click", "|cffffffffOpen Settings")
  GameTooltip:Show()
end

local function OpenConfig()
  if not pfUI.gui then return end
  if pfUI.gui:IsShown() then pfUI.gui:Hide() return end
  local page = T["Thirdparty"] .. "/" .. (GetAddOnMetadata("pfUI-autoinvite", "X-LocalName") or LABEL)
  if pfUI.gui.OpenPage then
    pfUI.gui:OpenPage(page)
  else
    pfUI.gui:Show()
  end
end

local function Click()
  if arg1 == "RightButton" then
    GameTooltip:Hide()
    OpenConfig()
    return
  end
  SlashCmdList.PFAI("")
  -- refresh an open tooltip
  if GameTooltip:IsOwned(this) then Tooltip() end
end

function pfUI.autoinvite:UpdatePanel()
  if not pfUI.panel or not pfUI.panel.OutputPanel then return end
  local text = C.autoinvite.state == "1" and "|cff33ff33On" or "|cffff5555Off"
  pfUI.panel:OutputPanel(ENTRY, "Invite: " .. text, Tooltip, Click)

  -- panel buttons only take left clicks by default
  local p = pfUI.panel
  for _, f in pairs({ p.left and p.left.left, p.left and p.left.center, p.left and p.left.right,
      p.right and p.right.left, p.right and p.right.center, p.right and p.right.right, p.minimap }) do
    if f.initialized == ENTRY and not f.autoinviteClicks then
      f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      f.autoinviteClicks = true
    end
  end
end

-- refresh whenever the state changes (slash command, config GUI, panel click)
local UpdateConfig = pfUI.autoinvite.UpdateConfig
function pfUI.autoinvite:UpdateConfig()
  UpdateConfig(self)
  pfUI.autoinvite:UpdatePanel()
end

local widget = CreateFrame("Frame", "pfPanelWidgetAutoinvite", UIParent)
widget:RegisterEvent("PLAYER_ENTERING_WORLD")
widget:SetScript("OnEvent", function() pfUI.autoinvite:UpdatePanel() end)
