-- AdeGear: talent-aware gear comparison for the 1.12 client.
-- Step 1 of 4: visual prototype (pfUI-style windows and tooltips, demo data only).
-- Target: Lua 5.0 (no # operator, no % operator, no string.gmatch, no select(), no varargs).

AdeGear = AdeGear or {}
local AG = AdeGear
AG.version = "1.1.1"

AG.defaults = {
  enabled = true,       -- show the comparison when hovering items
  showEquipped = true,  -- show the tooltip of the equipped item next to it
  shiftOnly = false,    -- only compare while Shift is held
  gsPos = "bottom",     -- GearScore label on the character window: bottom or top
  gearscore = true,     -- GearScore line on the tooltip of players you hover
  minimap = true,       -- minimap button
  minimapAngle = 225,   -- where it sits around the minimap (degrees)
  arrows = true,        -- upgrade arrows on item icons
  detail = 2,           -- 1 compact, 2 normal, 3 detailed
  look = "auto",        -- window look: auto (pfUI when loaded, else vanilla), pfui or blizzard (vanilla windows)          -- take colors and font from pfUI when it is loaded
  leveling = false,     -- tank/healer also count damage while leveling (off: only your role counts)
  playstyle = 1,        -- 1 solo, 2 dungeons (dungeons and raids: role only, no damage share)
  damageShare = 30,     -- percent of the value that goes to damage while leveling
  fadeLevel = 60,       -- the leveling mix is gone at this level
  wand = true,          -- casters count wand dps while leveling
  weaponScale = 0.3,    -- weapon dps and hit size count this much of their calculated value (/adeg weapon)
  role = "auto",        -- auto (from talents) or tank / heal / dmg, set with /adeg role
  testPanel = false,    -- test panel (what was understood about the item) instead of the comparison (old key "scan" is ignored)
}

function AG.Msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffAdeGear|r: " .. text)
end

function AG.Get(key)
  local db = AdeGearDB
  if db and db[key] ~= nil then return db[key] end
  return AG.defaults[key]
end

function AG.Set(key, value)
  AdeGearDB = AdeGearDB or {}
  AdeGearDB[key] = value
  if AG.OnConfig then AG.OnConfig(key, value) end
end

----------------------------------------------------------------------
-- Window positions (saved per window name)
----------------------------------------------------------------------

function AG.SavePos(frame)
  local name = frame:GetName()
  if not name then return end
  local point, rel, relPoint, x, y = frame:GetPoint(1)
  if not point then return end
  AdeGearDB = AdeGearDB or {}
  AdeGearDB.pos = AdeGearDB.pos or {}
  AdeGearDB.pos[name] = { point, relPoint, x, y }
end

-- returns true when a saved position was applied
function AG.LoadPos(frame)
  local name = frame:GetName()
  local p = name and AdeGearDB and AdeGearDB.pos and AdeGearDB.pos[name]
  if not p then return false end
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  return true
end

function AG.ResetPos()
  if AdeGearDB then AdeGearDB.pos = nil end
end

----------------------------------------------------------------------
-- Status line for bug reports
----------------------------------------------------------------------

function AG.Status()
  local modes = { "Solo", "Party", "Raids" }
  local at = "not found"
  if AdeTalents and AdeTalents.version then at = "v" .. tostring(AdeTalents.version) end
  local function OnOff(key) if AG.Get(key) then return "on" else return "off" end end
  AG.Msg("v" .. AG.version .. ", AdeTalents " .. at .. ", mode " .. (modes[AG.Get("playstyle")] or "?") .. ", role " .. tostring(AG.Get("role")))
  DEFAULT_CHAT_FRAME:AddMessage("  comparison " .. OnOff("enabled") .. ", arrows " .. OnOff("arrows") .. ", GearScore " .. OnOff("gearscore") .. ", minimap " .. OnOff("minimap") .. ", window look " .. AG.Look() .. " (setting " .. tostring(AG.Get("look")) .. "), pfUI " .. (type(pfUI_config) == "table" and "found" or "not found"))
  local unknown, manual = 0, 0
  if AdeGearDB and AdeGearDB.unparsed then for k, v in pairs(AdeGearDB.unparsed) do unknown = unknown + 1 end end
  if AdeGearDB and AdeGearDB.manual then for cls, t in pairs(AdeGearDB.manual) do for k, v in pairs(t) do manual = manual + 1 end end end
  local players = 0
  if AG.GearScore and AG.GearScore.CachedCount then players = AG.GearScore.CachedCount() end
  DEFAULT_CHAT_FRAME:AddMessage("  unknown tooltip lines: " .. unknown .. ", your own stat values: " .. manual .. ", players remembered by GearScore: " .. players)
  if AG.lastError then DEFAULT_CHAT_FRAME:AddMessage("  last error: " .. tostring(AG.lastError)) end
end

----------------------------------------------------------------------
-- Loading and slash command
----------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "AdeGear" then
    AdeGearDB = AdeGearDB or {}
    -- settings of old test versions that do nothing now
    AdeGearDB.scan = nil
    AdeGearDB.weights = nil
    -- window look: the old "use pfUI" checkbox and the flat choice became the look setting
    if AdeGearDB.pfui == false and (AdeGearDB.look == nil or AdeGearDB.look == "auto") then AdeGearDB.look = "blizzard" end
    if AdeGearDB.look == "flat" then AdeGearDB.look = "pfui" end
    AdeGearDB.pfui = nil
    AG.loaded = true
    AG.Msg("v" .. AG.version .. " loaded. /adeg shows the commands, the minimap button opens the options.")
  end
end)

SLASH_ADEGEAR1 = "/adeg"
SLASH_ADEGEAR2 = "/adegear"
SlashCmdList["ADEGEAR"] = function(msg)
  msg = string.lower(msg or "")
  if msg == "options" or msg == "config" then
    AG.Options.Toggle()
  elseif string.find(msg, "^skin") then
    local s, e, v = string.find(msg, "^skin%s+(%a+)")
    if v == "pfui" or v == "flat" then
      AG.Set("look", "pfui")
    elseif v == "blizzard" or v == "vanilla" then
      AG.Set("look", "blizzard")
    elseif v == "auto" then
      AG.Set("look", "auto")
    end
    local found = "no"
    if type(pfUI_config) == "table" then found = "yes" end
    AG.Msg("window look: " .. AG.Look() .. " (setting " .. tostring(AG.Get("look")) .. ", pfUI found: " .. found .. "). /adeg skin auto|pfui|vanilla, then /reload")
  elseif msg == "scan" then
    AG.Set("testPanel", not AG.Get("testPanel"))
    if AG.Get("testPanel") then AG.Msg("test panel: on (shows what was understood, instead of the comparison)") else AG.Msg("test panel: off, comparison on") end
    AG.Inspect.Hide()
  elseif msg == "item" then
    AG.Inspect.Dump(AG.Inspect.last)
  elseif string.find(msg, "^equipped") then
    local s, e, id = string.find(msg, "^equipped%s+(%d+)")
    if id then
      AG.Inspect.Dump(AG.Items.FromSlot(tonumber(id)))
    else
      AG.Msg("usage: /adeg equipped <slot number>, for example 16 = main hand, 5 = chest")
    end
  elseif msg == "weights" then
    AG.Weights.Print()
  elseif msg == "role why" then
    AG.Char.RoleWhy()
  elseif string.find(msg, "^role") then
    local s, e, r = string.find(msg, "^role%s+(%a+)")
    if r == "tank" or r == "heal" or r == "dmg" or r == "auto" then
      AG.Set("role", r)
      AG.Msg("role: " .. r)
      if AG.Inspect and AG.Inspect.Hide then AG.Inspect.Hide() end
    else
      AG.Msg("usage: /adeg role auto | heal | dmg | tank  (now: " .. tostring(AG.Get("role")) .. ")")
    end
  elseif string.find(msg, "^weapon") then
    local s, e, v = string.find(msg, "^weapon%s+([%d%.]+)")
    v = tonumber(v)
    if v and v >= 0 and v <= 2 then
      AG.Set("weaponScale", v)
      AG.Msg("weapon values now count x" .. v)
    else
      AG.Msg("usage: /adeg weapon <0 to 2>, how much weapon dps counts compared to the calculation (now: x" .. tostring(AG.Get("weaponScale")) .. ", 1 = full)")
    end
  elseif msg == "best" then
    AG.Arrows.Best()
  elseif msg == "arrows" then
    AG.Set("arrows", not AG.Get("arrows"))
    if AG.Get("arrows") then AG.Msg("upgrade arrows: on") else AG.Msg("upgrade arrows: off") end
  elseif msg == "gs" or msg == "gearscore" then
    AG.GearScore.Toggle()
  elseif msg == "gs reset" or msg == "gearscore reset" then
    local n = AG.GearScore.Reset()
    AG.Msg("GearScore memory cleared (" .. n .. " players); hover them again to read their gear")
  elseif msg == "gs top" or msg == "gs bottom" then
    if AdeGearDB then AdeGearDB.gsOffset = nil end
    AG.Set("gsPos", string.sub(msg, 4))
    AG.Msg("GearScore on the character window: " .. string.sub(msg, 4))
  elseif msg == "gs off" or msg == "gs on" then
    AG.Set("gearscore", msg == "gs on")
    AG.Msg("GearScore on the player tooltip: " .. string.sub(msg, 4))
  elseif msg == "minimap round" or msg == "minimap square" then
    AG.Set("minimapShape", string.sub(msg, 9))
    AG.Minimap.Place()
    AG.Msg("minimap button follows a " .. string.sub(msg, 9) .. " minimap")
  elseif msg == "minimap" then
    AG.Set("minimap", not AG.Get("minimap"))
    if AG.Get("minimap") then AG.Msg("minimap button: on") else AG.Msg("minimap button: off (/adeg minimap brings it back)") end
  elseif msg == "arrows debug" then
    AG.Arrows.Debug()
  elseif msg == "set" then
    AG.Compare.SetDebug()
  elseif msg == "error" then
    AG.Msg("last comparison error: " .. tostring(AG.lastError or "none"))
  elseif msg == "me" then
    AG.Char.Print()
  elseif msg == "unparsed" then
    AG.Inspect.Unparsed()
  elseif msg == "unparsed clear" then
    if AdeGearDB then AdeGearDB.unparsed = nil end
    AG.Msg("the list of unknown tooltip lines is empty now")
  elseif msg == "status" then
    AG.Status()
  elseif msg == "reset" then
    AG.ResetPos()
    AG.Msg("window positions reset, type /reload")
  else
    AG.Msg("v" .. AG.version .. " commands (everything is also in the options window, minimap button)")
    local function H(t) DEFAULT_CHAT_FRAME:AddMessage("  " .. t) end
    H("/adeg options - options window")
    H("/adeg role auto|heal|dmg|tank - force the role; /adeg role why - which talents decide it")
    H("/adeg weights - what one point of each stat is worth to you, and why")
    H("/adeg best - upgrades waiting in your bags")
    H("/adeg gs - your GearScore per item; /adeg gs reset - forget other players; /adeg gs on|off; /adeg gs top|bottom")
    H("/adeg arrows - upgrade arrows on bag icons on/off")
    H("/adeg minimap - minimap button on/off; /adeg minimap round|square - its shape")
    H("/adeg weapon <0-2> - how much weapon dps counts compared to the calculation")
    H("/adeg skin auto|pfui|vanilla - window look (auto: pfUI when it is loaded, else vanilla windows); then /reload")
    H("/adeg reset - forget saved window positions")
    H("Testing and bug reports:")
    H("/adeg status - one-line summary of versions and settings")
    H("/adeg me - what the addon reads about your character")
    H("/adeg unparsed - tooltip lines the parser did not know (then /reload and send the saved variables file); /adeg unparsed clear")
    H("/adeg item, /adeg equipped <slot> - what was understood about an item; /adeg set - set bonus details")
    H("/adeg scan - test panel instead of the comparison; /adeg error - last error")
  end
end
