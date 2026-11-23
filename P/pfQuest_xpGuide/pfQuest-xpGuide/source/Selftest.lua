-- pfQuest xpGuide: /xpg selftest. Runs the zone logic, the wizard, the guide and the arrow inside the real game, and
-- writes what happened to the saved file (pfQuest_xpGuideDB.selftest) so a developer can read it after /reload.
-- Also keeps any Lua error that mentions pfQuest xpGuide in pfQuest_xpGuideDB.errors.

local ER = pfQuest_xpGuide

-- Remember errors from this addon, then hand them on to whatever shows errors normally.
local previousHandler = geterrorhandler and geterrorhandler()
if seterrorhandler then
  seterrorhandler(function(msg)
    msg = tostring(msg)
    if ER.db and (string.find(msg, "pfQuest_xpGuide", 1, true) or string.find(msg, "pfQuest-xpGuide", 1, true)) then
      if type(ER.db.errors) ~= "table" then ER.db.errors = {} end
      table.insert(ER.db.errors, date("%Y-%m-%d %H:%M") .. "  " .. msg)
      while table.getn(ER.db.errors) > 20 do table.remove(ER.db.errors, 1) end
      if ER.FastRoute and ER.FastRoute.OwnError then pcall(ER.FastRoute.OwnError) end
    end
    if previousHandler then previousHandler(msg) end
  end)
end

function ER.SelfTest()
  -- The steps below set the game's global `this` and `arg1` to click their own buttons. The slash command that
  -- started this runs inside the chat box's own handler, which still needs its `this` afterwards, so put both
  -- back at the end (otherwise ChatFrame.lua errors with "attempt to index field '?'").
  local keepThis, keepArg1 = this, arg1
  local results, failed = {}, 0
  local function Step(label, fn)
    local ok, err = pcall(fn)
    if ok then
      table.insert(results, label .. ": ok" .. (err and (" - " .. tostring(err)) or ""))
    else
      failed = failed + 1
      table.insert(results, label .. ": ERROR " .. tostring(err))
    end
  end

  Step("data loaded", function()
    local zones, quests = 0, 0
    for _, z in pairs(pfQuest_xpGuide_Zones or {}) do zones = zones + 1 quests = quests + table.getn(z.q) end
    assert(zones > 50 and quests > 4000, "Zones.lua is missing or short")
    assert(pfQuest_xpGuide_FastRoute, "FastRoute.lua is missing")
    return zones .. " zones, " .. quests .. " quests"
  end)
  Step("who you are", function()
    local race, class, faction = ER.PlayerMasks()
    return "race bit " .. race .. ", class bit " .. class .. ", mask " .. faction .. ", level " .. UnitLevel("player")
  end)
  Step("pfQuest", function()
    return "pfQuest " .. (pfQuest and "yes" or "no") .. ", pfMap " .. (pfMap and "yes" or "no") .. ", pfDB " .. (pfDB and "yes" or "no")
  end)

  Step("difficulty", function()
    local text = {}
    for _, key in ipairs(ER.MODE_ORDER) do
      local kept = 0
      for _, row in ipairs(ER.ZoneRows(ER.ZoneId(GetZoneText() or "") or 0) or {}) do
        if not ER.Steps.LeftByKinds(ER.Steps.Kinds(row.id), key) then kept = kept + 1 end
      end
      table.insert(text, ER.MODES[key].label .. " keeps " .. kept)
    end
    return table.concat(text, ", ")
  end)
  Step("wizard", function()
    assert(ER.ShowWizard and ER.WizardInfo, "Wizard.lua did not load")
    ER.ShowWizard()
    local w = ER.WizardInfo()
    assert(w and w.text and w.text ~= "", "the wizard has no text")
    getglobal("pfQuest_xpGuideWizardFrame"):Hide()
    return "opens and shows the " .. w.screen .. " screen"
  end)
  Step("guides", function()
    assert(ER.Steps and pfQuest_xpGuide_Guides, "Steps.lua or Data\\Guides.lua did not load")
    local mine = ER.Steps.Guides()
    assert(table.getn(mine) > 10, "only " .. table.getn(mine) .. " guides for this character")
    local best = ER.Steps.Suggest()[1]
    return table.getn(mine) .. " guides for you, suggested: " .. (best and (best.title or best.name) or "none")
  end)
  Step("guide running", function()
    if not ER.Steps.Running() then return "no guide running (pick one with /xpg to test this part)" end
    local step = ER.Steps.Current()
    local t = ER.Steps.Target()
    return (ER.Steps.Info().title or "?") .. ", step " .. ER.Steps.Position() .. " of " .. ER.Steps.Count() ..
      (step and (": " .. string.gsub(ER.Steps.Title(step), "|c%x%x%x%x%x%x%x%x", "")) or " (finished)") ..
      (t and (", arrow to " .. t.zone .. " " .. math.floor(t.x) .. "," .. math.floor(t.y)) or ", no arrow target")
  end)
  Step("arrow", function()
    assert(ER.ToggleArrow and ER.ArrowUpdate, "Arrow.lua did not load")
    ER.ArrowUpdate()
    local f = getglobal("pfQuest_xpGuideArrow")
    assert(f, "the arrow was not built")
    local size = pfQuest_xpGuide_ZoneSizes and pfQuest_xpGuide_ZoneSizes[GetZoneText()]
    local mode = ER.ArrowMode and ER.ArrowMode()
    local which = (mode == "smart" and "pfQuest's arrow, routed by SmartArrow, points the way, ")
      or (mode == "pf" and "pfQuest's arrow points the way, ") or ""
    return which .. (f:IsShown() and "shown" or "hidden") .. (ER.db.arrowOff and " (turned off with /xpg arrow)" or "") ..
      ", facing " .. (GetPlayerFacing and "from the game" or (pfQuestCompat and pfQuestCompat.GetPlayerFacing and "from pfQuest" or "from the minimap")) ..
      ", zone size " .. (size and (math.floor(size[1]) .. " x " .. math.floor(size[2]) .. " yards") or "unknown")
  end)

  ER.db.selftest = { when = date("%Y-%m-%d %H:%M"), version = ER.VERSION, failed = failed, results = results }
  ER.Print("self-test " .. ER.VERSION .. ": " .. (failed == 0 and "everything ran" or (failed .. " step(s) failed")) ..
    ". Details are saved when you " .. ER.GOLD .. "/reload" .. ER.END .. " or log out.")
  for _, line in ipairs(results) do DEFAULT_CHAT_FRAME:AddMessage("  " .. line) end
  this, arg1 = keepThis, keepArg1
end

ER.Loaded("Selftest.lua")
