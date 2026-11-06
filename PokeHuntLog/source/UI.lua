-- PokeHuntLog: main window. Left: Type -> Family -> Skin list. Right: details for the selected row.

local HPL = PokeHuntLog

local WIDTH, HEIGHT = 700, 500
local ROW_HEIGHT, NUM_ROWS, ROW_WIDTH = 18, 20, 340
local DETAIL_WIDTH = 276
local MAX_WHERE_LINES = 6

local frame, scroll, detail, emptyText, summaryText, uncaughtCheck, searchBox
local buttons = {}
HPL.rows = {}
HPL.selected = nil      -- { kind = "skin", id = skinId } or { kind = "pet", pet = petRecord, charKey = key }
HPL.assigning = nil     -- pet record waiting for the player to click a skin

local GOLD = "|cffffd100"
local GREY = "|cff808080"
local GREEN = "|cff40ff40"
local ORANGE = "|cffff9933"
local WHITE = "|cffffffff"
local END = "|r"

local function Backdrop(f, dialog)
  if dialog then
    HPL.Opaque(f, 11)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  else
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  end
end

local function LevelText(level)
  if not level or level <= 0 then return "" end
  local color = (level >= HPL.MAX_LEVEL) and GREEN or WHITE
  return color .. level .. END .. GREY .. "/" .. HPL.MAX_LEVEL .. END
end

------------------------------------------------------------------------------------------------
-- Row list
------------------------------------------------------------------------------------------------

local function Contains(text, needle)
  return text and string.find(string.lower(text), needle, 1, true) ~= nil
end

-- Does this skin match what is typed in the search box? Skin name, family, creature names and zones count.
local function SkinMatches(def, needle)
  if Contains(def.name, needle) or Contains(def.family, needle) or Contains(def.model, needle) then
    return true
  end
  local npcs = def.npcs or {}
  for i = 1, table.getn(npcs) do
    if Contains(npcs[i][2], needle) or Contains(npcs[i][4], needle) then return true end
  end
  return false
end

function HPL.BuildRows()
  local rows = {}
  local s = HPL.db.settings
  local collapsed = s.collapsed
  local assigningFamily = HPL.assigning and HPL.assigning.family
  local needle = HPL.search and HPL.search ~= "" and string.lower(HPL.search) or nil

  for i = 1, table.getn(HPL.tree) do
    local t = HPL.tree[i]
    local ts = HPL.typeStats[t.name]
    local typeVisible = s.showUncaught or ts.caught > 0 or assigningFamily
    if typeVisible then
      local tkey = "t:" .. t.name
      -- A search builds the families into a holding table first, so a family with no hit is dropped
      -- instead of showing an empty row.
      local body = {}
      if not collapsed[tkey] or needle then
        for j = 1, table.getn(t.families) do
          local f = t.families[j]
          local fs = HPL.familyStats[t.name .. "/" .. f.name]
          local picking = assigningFamily == f.name
          if s.showUncaught or fs.caught > 0 or picking then
            local fkey = "f:" .. t.name .. "/" .. f.name
            local skinRows = {}
            if not collapsed[fkey] or picking or needle then
              for k = 1, table.getn(f.skins) do
                local id = f.skins[k]
                if (HPL.caught[id] or s.showUncaught or picking or needle) and
                  (not needle or SkinMatches(HPL.skinsById[id], needle)) then
                  table.insert(skinRows, { kind = "skin", id = id })
                end
              end
            end
            if not needle or table.getn(skinRows) > 0 then
              table.insert(body, { kind = "family", key = fkey, name = f.name, caught = fs.caught,
                total = fs.skins, best = fs.bestLevel, forced = (needle or picking) and true or nil,
                hits = table.getn(skinRows) })
              for k = 1, table.getn(skinRows) do table.insert(body, skinRows[k]) end
            end
          end
        end
      end
      if not needle or table.getn(body) > 0 then
        table.insert(rows, { kind = "type", key = tkey, name = t.name, caught = ts.caught,
          total = ts.skins, forced = needle and true or nil })
        for j = 1, table.getn(body) do table.insert(rows, body[j]) end
      end
    end
  end

  local unknown = HPL.unknownPets or {}
  if table.getn(unknown) > 0 then
    table.insert(rows, { kind = "header", key = "unknown", name = "Pets with unknown skin", total = table.getn(unknown) })
    if not collapsed["unknown"] then
      for i = 1, table.getn(unknown) do
        table.insert(rows, { kind = "pet", pet = unknown[i].pet, charKey = unknown[i].charKey })
      end
    end
  end

  HPL.rows = rows
end

local function IsSelected(r)
  local sel = HPL.selected
  if not sel then return false end
  if r.kind == "skin" then return sel.kind == "skin" and sel.id == r.id end
  if r.kind == "pet" then return sel.kind == "pet" and sel.pet == r.pet end
  return false
end

function HPL.UpdateList()
  if not frame then return end
  local rows = HPL.rows
  local total = table.getn(rows)
  FauxScrollFrame_Update(scroll, total, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(scroll)
  local collapsed = HPL.db.settings.collapsed

  for i = 1, NUM_ROWS do
    local btn = buttons[i]
    local r = rows[i + offset]
    btn.entry = r
    if not r then
      btn:Hide()
    else
      local indent, iconPath, label, right, expand = 0, nil, "", "", ""
      btn.icon:SetVertexColor(1, 1, 1)

      if r.kind == "type" or r.kind == "header" then
        expand = (collapsed[r.key] and not r.forced) and "+" or "-"
        if r.kind == "type" then
          label = GOLD .. r.name .. END
          right = WHITE .. r.caught .. END .. GREY .. " / " .. r.total .. END
        else
          label = ORANGE .. r.name .. END
          right = WHITE .. r.total .. END
        end
      elseif r.kind == "family" then
        indent = 12
        expand = (collapsed[r.key] and not r.forced) and "+" or "-"
        iconPath = HPL.FamilyIcon(r.name)
        label = (r.caught > 0 and WHITE or GREY) .. r.name .. END
        local role = HPL.FamilyRole(r.name)
        if role then
          label = label .. "  " .. (HPL.ROLE_COLORS[role] or GREY) .. role .. END
        end
        right = WHITE .. r.caught .. END .. GREY .. "/" .. r.total .. END
        if r.best > 0 then
          right = right .. GREY .. "  best " .. END .. LevelText(r.best)
        end
      elseif r.kind == "skin" then
        indent = 30
        local def = HPL.skinsById[r.id]
        local c = HPL.caught[r.id]
        iconPath = HPL.FamilyIcon(def.family)
        if c then
          label = WHITE .. def.name .. END
          right = LevelText(c.maxLevel)
        else
          label = GREY .. def.name .. END
          btn.icon:SetVertexColor(0.35, 0.35, 0.35)
        end
        if HPL.assigning and HPL.assigning.family == def.family then
          label = GREEN .. "> " .. END .. label
        end
      elseif r.kind == "pet" then
        indent = 12
        iconPath = HPL.FamilyIcon(r.pet.family)
        label = WHITE .. tostring(r.pet.name) .. END .. GREY .. " (" .. tostring(r.pet.family) .. ")" .. END
        right = LevelText(r.pet.level) .. GREY .. "  " .. HPL.CharName(r.charKey) .. END
      end

      btn.expand:SetText(expand)
      btn.expand:SetPoint("LEFT", btn, "LEFT", indent, 0)
      if iconPath then
        btn.icon:SetTexture(iconPath)
        btn.icon:SetPoint("LEFT", btn, "LEFT", indent + (expand ~= "" and 12 or 0), 0)
        btn.icon:Show()
        btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
      else
        btn.icon:Hide()
        btn.label:SetPoint("LEFT", btn, "LEFT", indent + 14, 0)
      end
      btn.label:SetText(label)
      btn.right:SetText(right)
      if IsSelected(r) then btn.selectedTex:Show() else btn.selectedTex:Hide() end
      btn:Show()
    end
  end

  if total == 0 then emptyText:Show() else emptyText:Hide() end
end

local function OnRowClick(btn, mouseButton)
  local r = btn.entry
  if not r then return end
  if mouseButton == "RightButton" and HPL.assigning then
    HPL.assigning = nil
    HPL.RefreshUI()
    return
  end

  if r.kind == "type" or r.kind == "family" or r.kind == "header" then
    local collapsed = HPL.db.settings.collapsed
    if collapsed[r.key] then collapsed[r.key] = nil else collapsed[r.key] = true end
  elseif r.kind == "skin" then
    local pet = HPL.assigning
    local def = HPL.skinsById[r.id]
    if pet then
      if def.family ~= pet.family then
        HPL.Print("pick a " .. tostring(pet.family) .. " skin for " .. tostring(pet.name) .. " (right-click to cancel).")
        return
      end
      pet.skin = r.id
      pet.match = "manual"
      HPL.assigning = nil
      HPL.Print(pet.name .. " is now logged as " .. def.name .. ".")
      HPL.selected = { kind = "skin", id = r.id }
      HPL.Changed()
      return
    end
    HPL.selected = { kind = "skin", id = r.id }
  elseif r.kind == "pet" then
    HPL.selected = { kind = "pet", pet = r.pet, charKey = r.charKey }
  end
  HPL.RefreshUI()
end

------------------------------------------------------------------------------------------------
-- Detail panel
------------------------------------------------------------------------------------------------

local function Line(lines, text)
  table.insert(lines, text)
end

local function StatsText(stats)
  if not stats then return nil end
  local parts = {}
  if stats.ap then table.insert(parts, "AP " .. math.floor(stats.ap)) end
  if stats.dmgLow and stats.dmgHigh then
    table.insert(parts, "dmg " .. math.floor(stats.dmgLow) .. "-" .. math.floor(stats.dmgHigh))
  end
  if stats.speed and stats.speed > 0 then table.insert(parts, "speed " .. string.format("%.1f", stats.speed)) end
  if stats.health then table.insert(parts, math.floor(stats.health) .. " hp") end
  if stats.armor then table.insert(parts, math.floor(stats.armor) .. " armour") end
  if table.getn(parts) == 0 then return nil end
  return table.concat(parts, ", ")
end

local function StatsLine2(stats)
  if not stats or not stats.sta then return nil end
  return "str " .. math.floor(stats.str or 0) .. ", agi " .. math.floor(stats.agi or 0) ..
    ", sta " .. math.floor(stats.sta or 0)
end

-- The best pet of this skin that has stats recorded.
local function BestPetWithStats(caught)
  local best
  for i = 1, table.getn(caught.pets) do
    local pet = caught.pets[i].pet
    if pet.stats and (not best or (pet.level or 0) >= (best.level or 0)) then best = pet end
  end
  return best
end

-- One "where to tame" line: creature, level, rare or elite tag, fast attack speed, zone.
local function NpcLine(npc)
  local playerLevel = UnitLevel("player") or 0
  local low = HPL.LowLevel(npc[3])
  local extra = ""
  if npc[3] and npc[3] ~= "" then extra = extra .. " " .. npc[3] end
  if npc[5] and npc[5] ~= "" then extra = extra .. " " .. npc[5] end
  if npc[6] and npc[6] > 0 and npc[6] < 2 then
    extra = extra .. " " .. string.format("%.1f", npc[6]) .. "s"
  end
  local line = WHITE .. tostring(npc[2]) .. END .. GREY .. extra .. "  " .. tostring(npc[4]) .. END
  if low > 0 and low <= playerLevel then
    line = line .. GREEN .. "  tameable now" .. END
  end
  return line
end

-- Tooltip shown when hovering a row in the list.
function HPL.RowTooltip(btn)
  local r = btn.entry
  if not r then return end
  GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
  if r.kind == "family" then
    local info = HPL.FamilyInfo(r.name)
    local role = HPL.FamilyRole(r.name)
    GameTooltip:SetText(r.name .. (role and ("  -  " .. role) or ""))
    if info then
      GameTooltip:AddLine("Health " .. math.floor(info.health * 100) .. "%, armour " ..
        math.floor(info.armor * 100) .. "%, damage " .. math.floor(info.damage * 100) .. "%", 1, 1, 1)
      local abilities = info.abilities or {}
      for i = 1, table.getn(abilities) do
        local note = HPL.ABILITY_NOTES[abilities[i]]
        GameTooltip:AddLine(abilities[i] .. (note and (" - " .. note) or ""), 0.8, 0.8, 0.8)
      end
      if info.diet and table.getn(info.diet) > 0 then
        GameTooltip:AddLine("Eats: " .. table.concat(info.diet, ", "), 0.6, 0.85, 0.6)
      end
    end
    GameTooltip:AddLine(r.caught .. " of " .. r.total .. " skins caught", 1, 0.82, 0)
  elseif r.kind == "skin" then
    local def = HPL.skinsById[r.id]
    local c = HPL.caught[r.id]
    GameTooltip:SetText(def.name)
    local sub = def.family
    if HPL.ModelLabel(def) then sub = sub .. " - " .. HPL.ModelLabel(def) end
    GameTooltip:AddLine(sub, 0.8, 0.8, 0.8)
    if c then
      GameTooltip:AddLine("Caught. Best level " .. c.maxLevel .. " (" .. tostring(c.maxPet) .. ")", 0.25, 1, 0.25)
      local best = BestPetWithStats(c)
      local stats = best and StatsText(best.stats)
      if stats then GameTooltip:AddLine(stats, 1, 1, 1) end
    else
      GameTooltip:AddLine("Not caught yet", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(table.getn(def.npcs or {}) .. " creatures have this look", 0.6, 0.6, 0.6)
  elseif r.kind == "pet" then
    GameTooltip:SetText(tostring(r.pet.name))
    if r.pet.creature then GameTooltip:AddLine("Tamed from " .. r.pet.creature, 0.8, 0.8, 0.8) end
    if r.pet.firstName then GameTooltip:AddLine("First called " .. r.pet.firstName, 0.8, 0.8, 0.8) end
    local stats = StatsText(r.pet.stats)
    if stats then GameTooltip:AddLine(stats, 1, 1, 1) end
  else
    GameTooltip:Hide()
    return
  end
  GameTooltip:Show()
end

local function OverviewText()
  local t = HPL.totals
  local chars = 0
  for _ in pairs(HPL.db.pets) do chars = chars + 1 end
  local lines = {}
  Line(lines, GOLD .. "Skins caught: " .. END .. t.caught .. " / " .. t.skins ..
    " (" .. HPL.Percent(t.caught, t.skins) .. "%)")
  Line(lines, GOLD .. "Families started: " .. END .. t.familiesCaught .. " / " .. t.families)
  Line(lines, GOLD .. "Tames logged: " .. END .. HPL.db.stats.tames)
  Line(lines, GOLD .. "Highest pet level: " .. END .. (t.bestLevel > 0 and LevelText(t.bestLevel) or "-"))
  Line(lines, GOLD .. "Hunters logged: " .. END .. chars)
  local zone = GetRealZoneText()
  local zoneCaught, zoneTotal, zoneMissing = HPL.ZoneProgress(zone)
  if zoneTotal then
    Line(lines, " ")
    Line(lines, GOLD .. "In " .. zone .. ": " .. END .. zoneCaught .. " / " .. zoneTotal .. " skins caught")
    local names = {}
    for i = 1, math.min(table.getn(zoneMissing), 4) do
      table.insert(names, HPL.skinsById[zoneMissing[i]].name)
    end
    if table.getn(names) > 0 then
      local more = ""
      if table.getn(zoneMissing) > 4 then more = ", ..." end
      Line(lines, GREY .. "Still here: " .. table.concat(names, ", ") .. more .. END)
    end
  end
  Line(lines, " ")
  Line(lines, "Click a skin to see its details. Tick " .. WHITE .. "Show uncaught" .. END ..
    " to browse every skin and where to tame it.")
  if not HPL.db.settings.showUncaught then
    Line(lines, " ")
    Line(lines, GREY .. "Skins you haven't caught are hidden." .. END)
  end
  return table.concat(lines, "\n")
end

local function SkinText(def)
  local c = HPL.caught[def.id]
  local lines = {}
  local modelName = HPL.ModelLabel(def) and (" - " .. HPL.ModelLabel(def)) or ""
  Line(lines, GREY .. def.type .. " / " .. def.family .. modelName .. END)
  if def.custom then
    Line(lines, ORANGE .. "Found in game (not in the skin database)" .. END)
  end
  if c then
    Line(lines, GREEN .. "Caught" .. END)
    Line(lines, GOLD .. "Highest level: " .. END .. LevelText(c.maxLevel) ..
      GREY .. "  " .. tostring(c.maxPet) .. ", " .. HPL.CharName(c.maxChar) .. END)
    if c.firstTime then
      local verb = c.firstWitnessed and "First tamed: " or "First logged: "
      local where = c.firstZone and (" in " .. c.firstZone) or ""
      Line(lines, GOLD .. verb .. END .. HPL.FormatDate(c.firstTime) .. " by " .. HPL.CharName(c.firstChar) .. where)
    end
    if c.firstCreature then
      Line(lines, GOLD .. "Tamed from: " .. END .. c.firstCreature)
    end
    local names = {}
    for i = 1, table.getn(c.pets) do
      local p = c.pets[i]
      local from = p.pet.creature and (", " .. p.pet.creature) or ""
      table.insert(names, tostring(p.pet.name) .. " (" .. (p.pet.level or "?") .. from .. ")")
    end
    Line(lines, GOLD .. "Pets: " .. END .. table.concat(names, ", "))
  else
    Line(lines, GREY .. "Not caught yet" .. END)
  end

  local info = HPL.FamilyInfo(def.family)
  local role = HPL.FamilyRole(def.family)
  if info and role then
    Line(lines, " ")
    Line(lines, GOLD .. "Role: " .. END .. (HPL.ROLE_COLORS[role] or WHITE) .. role .. END ..
      GREY .. "  health " .. math.floor(info.health * 100) .. "%, armour " .. math.floor(info.armor * 100) ..
      "%, damage " .. math.floor(info.damage * 100) .. "%" .. END)
    Line(lines, GOLD .. "Can learn: " .. END .. table.concat(info.abilities or {}, ", "))
  end

  if c then
    local best = BestPetWithStats(c)
    local stats = best and StatsText(best.stats)
    if stats then
      Line(lines, GOLD .. "Your best: " .. END .. stats)
      local more = StatsLine2(best.stats)
      if more then Line(lines, GREY .. more .. END) end
    end
  end

  local npcs = def.npcs or {}
  if table.getn(npcs) > 0 then
    Line(lines, " ")
    Line(lines, GOLD .. "Where to tame:" .. END)
    for i = 1, math.min(table.getn(npcs), MAX_WHERE_LINES) do
      Line(lines, NpcLine(npcs[i]))
    end
    if table.getn(npcs) > MAX_WHERE_LINES then
      Line(lines, GREY .. "...and " .. (table.getn(npcs) - MAX_WHERE_LINES) .. " more" .. END)
    end
  end
  return table.concat(lines, "\n")
end

local function PetText(sel, guesses)
  local pet = sel.pet
  local lines = {}
  Line(lines, GREY .. tostring(pet.ctype or "Beast") .. " / " .. tostring(pet.family) .. END)
  Line(lines, GOLD .. "Level: " .. END .. LevelText(pet.level))
  Line(lines, GOLD .. "Hunter: " .. END .. HPL.CharName(sel.charKey))
  if pet.creature then
    Line(lines, GOLD .. "Tamed from: " .. END .. pet.creature)
  end
  if pet.firstName then
    Line(lines, GOLD .. "First called: " .. END .. pet.firstName)
  end
  if pet.firstSeen or pet.tamed then
    Line(lines, GOLD .. "First logged: " .. END .. HPL.FormatDate(pet.tamed or pet.firstSeen))
  end
  local stats = StatsText(pet.stats)
  if stats then
    Line(lines, GOLD .. "Stats: " .. END .. stats)
    local more = StatsLine2(pet.stats)
    if more then Line(lines, GREY .. more .. END) end
  end
  if pet.spells and table.getn(pet.spells) > 0 then
    Line(lines, GOLD .. "Knows: " .. END .. table.concat(pet.spells, ", "))
  end
  Line(lines, " ")
  if HPL.assigning == pet then
    Line(lines, GREEN .. "Click one of the " .. tostring(pet.family) .. " skins in the list." .. END)
    Line(lines, GREY .. "Summon the pet to compare it with the 3D view. Right-click the list to cancel." .. END)
  else
    local level = pet.firstLevel or pet.level or 0
    if table.getn(guesses) == 1 then
      local g = guesses[1]
      local names = {}
      for i = 1, math.min(table.getn(g.npcs), 2) do
        table.insert(names, g.npcs[i][2] .. " (" .. g.npcs[i][3] .. ", " .. g.npcs[i][4] .. ")")
      end
      Line(lines, GOLD .. "Best guess: " .. END .. GREEN .. HPL.skinsById[g.skin].name .. END)
      Line(lines, GREY .. "At level " .. level .. " it knew what only " .. table.concat(names, " or ") ..
        " teaches." .. END)
      Line(lines, " ")
      Line(lines, "Press " .. WHITE .. "Use guess" .. END .. " to log it as that, or " .. WHITE .. "Assign skin" .. END ..
        " to pick one yourself.")
    else
      if table.getn(guesses) > 1 then
        local names = {}
        for i = 1, table.getn(guesses) do table.insert(names, HPL.skinsById[guesses[i].skin].name) end
        Line(lines, GOLD .. "Could be: " .. END .. table.concat(names, ", "))
        Line(lines, GREY .. "going by what it knew at level " .. level .. "." .. END)
      else
        Line(lines, "The log couldn't tell which skin this pet has. It was probably tamed before the addon " ..
          "was installed, or renamed while it was turned off.")
      end
      Line(lines, " ")
      Line(lines, "Press " .. WHITE .. "Assign skin" .. END .. " and pick the matching " .. tostring(pet.family) ..
        " skin from the list.")
    end
  end
  return table.concat(lines, "\n")
end

function HPL.RefreshModel()
  if not frame or not frame:IsShown() then return end
  local sel = HPL.selected
  local active = HPL.activePet
  local show = false
  if active and UnitExists("pet") and sel then
    if sel.kind == "skin" and active.skin == sel.id then show = true end
    if sel.kind == "pet" and sel.pet == active then show = true end
  end
  if show then
    detail.model:SetUnit("pet")
    detail.model:Show()
    detail.bigIcon:Hide()
    detail.modelHint:Hide()
  else
    detail.model:Hide()
    local family
    if sel and sel.kind == "skin" then family = HPL.skinsById[sel.id].family end
    if sel and sel.kind == "pet" then family = sel.pet.family end
    detail.bigIcon:SetTexture(family and HPL.FamilyIcon(family) or "Interface\\Icons\\Ability_Hunter_BeastTaming")
    if sel and sel.kind == "skin" and not HPL.caught[sel.id] then
      detail.bigIcon:SetVertexColor(0.35, 0.35, 0.35)
    else
      detail.bigIcon:SetVertexColor(1, 1, 1)
    end
    detail.bigIcon:Show()
    if sel then detail.modelHint:Show() else detail.modelHint:Hide() end
  end
end

function HPL.UpdateDetail()
  if not frame then return end
  local sel = HPL.selected
  if sel and sel.kind == "skin" and not HPL.skinsById[sel.id] then sel = nil end
  if sel and sel.kind == "pet" and sel.pet.skin then
    sel = { kind = "skin", id = sel.pet.skin }
  end
  HPL.selected = sel

  detail.assign:Hide()
  detail.guess:Hide()
  detail.forget:Hide()
  if not sel then
    detail.title:SetText("Your collection")
    detail.text:SetText(OverviewText())
  elseif sel.kind == "skin" then
    local def = HPL.skinsById[sel.id]
    detail.title:SetText(def.name)
    detail.text:SetText(SkinText(def))
  else
    local guesses = HPL.GuessSkin(sel.pet)
    detail.title:SetText(tostring(sel.pet.name))
    detail.text:SetText(PetText(sel, guesses))
    detail.assign:SetText(HPL.assigning == sel.pet and "Cancel" or "Assign skin")
    detail.assign:Show()
    detail.forget:Show()
    if table.getn(guesses) == 1 and HPL.assigning ~= sel.pet then
      detail.guess.skin = guesses[1].skin
      detail.guess:Show()
    end
  end
  HPL.RefreshModel()
end

function HPL.RefreshUI()
  if not frame or not frame:IsShown() then return end
  summaryText:SetText(GOLD .. "Skins: " .. END .. HPL.totals.caught .. "/" .. HPL.totals.skins ..
    " (" .. HPL.Percent(HPL.totals.caught, HPL.totals.skins) .. "%)" ..
    GOLD .. "     Tames: " .. END .. HPL.db.stats.tames)
  uncaughtCheck:SetChecked(HPL.db.settings.showUncaught)
  HPL.BuildRows()
  HPL.UpdateDetail()
  HPL.UpdateList()
end

------------------------------------------------------------------------------------------------
-- Window creation
------------------------------------------------------------------------------------------------

-- Tooltip on a button or box, so short labels can still be explained.
local function Explain(widget, title, body)
  widget:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText(title)
    if body then GameTooltip:AddLine(body, 1, 1, 1, 1) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Your collection as plain text, for pasting somewhere else.
function HPL.ExportText()
  local lines = {}
  table.insert(lines, "PokeHuntLog v" .. HPL.VERSION .. ": " .. HPL.totals.caught .. "/" .. HPL.totals.skins .. " skins (" ..
    HPL.Percent(HPL.totals.caught, HPL.totals.skins) .. "%), " .. HPL.db.stats.tames .. " tames logged")
  for i = 1, table.getn(HPL.tree) do
    local t = HPL.tree[i]
    for j = 1, table.getn(t.families) do
      local f = t.families[j]
      local names = {}
      for k = 1, table.getn(f.skins) do
        local c = HPL.caught[f.skins[k]]
        if c then
          table.insert(names, HPL.skinsById[f.skins[k]].name .. " (" .. c.maxLevel .. ")")
        end
      end
      if table.getn(names) > 0 then
        local stats = HPL.familyStats[t.name .. "/" .. f.name]
        table.insert(lines, f.name .. " " .. stats.caught .. "/" .. stats.skins .. ": " ..
          table.concat(names, ", "))
      end
    end
  end
  local unknown = table.getn(HPL.unknownPets or {})
  if unknown > 0 then
    table.insert(lines, unknown .. " pet(s) still waiting for a skin to be assigned.")
  end
  return table.concat(lines, "\n")
end

local exportFrame
function HPL.ShowExport()
  if not HPL.db then return end
  if not exportFrame then
    exportFrame = CreateFrame("Frame", "PokeHuntLogExportFrame", UIParent)
    exportFrame:SetWidth(460)
    exportFrame:SetHeight(360)
    exportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    exportFrame:SetFrameStrata("DIALOG")
    exportFrame:EnableMouse(true)
    exportFrame:SetMovable(true)
    exportFrame:RegisterForDrag("LeftButton")
    exportFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    exportFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    Backdrop(exportFrame, true)
    table.insert(UISpecialFrames, "PokeHuntLogExportFrame")

    local title = exportFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", exportFrame, "TOP", 0, -18)
    title:SetText("Your collection as text")

    local hint = exportFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
    hint:SetText(GREY .. "Press Ctrl+C to copy, then Escape to close." .. END)

    local close = CreateFrame("Button", "PokeHuntLogExportCloseButton", exportFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", exportFrame, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() exportFrame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "PokeHuntLogExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 22, -64)
    scroll:SetWidth(392)
    scroll:SetHeight(266)

    local box = CreateFrame("EditBox", "PokeHuntLogExportBox", scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetWidth(392)
    box:SetHeight(600)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
    scroll:SetScrollChild(box)
    exportFrame.box = box
  end
  exportFrame.box:SetText(HPL.ExportText())
  exportFrame.box:HighlightText()
  exportFrame:Show()
  exportFrame.box:SetFocus()
end

local function CreateRow(i)
  local btn = CreateFrame("Button", "PokeHuntLogRow" .. i, frame)
  btn:SetWidth(ROW_WIDTH)
  btn:SetHeight(ROW_HEIGHT)
  btn:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:SetFrameLevel(frame:GetFrameLevel() + 3)

  local hl = btn:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  hl:SetBlendMode("ADD")
  hl:SetAllPoints(btn)

  btn.selectedTex = btn:CreateTexture(nil, "BACKGROUND")
  btn.selectedTex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  btn.selectedTex:SetBlendMode("ADD")
  btn.selectedTex:SetVertexColor(1, 0.82, 0)
  btn.selectedTex:SetAllPoints(btn)
  btn.selectedTex:Hide()

  btn.expand = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  btn.expand:SetWidth(12)
  btn.expand:SetPoint("LEFT", btn, "LEFT", 0, 0)

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetWidth(16)
  btn.icon:SetHeight(16)
  btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  btn.right = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  btn.right:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
  btn.right:SetJustifyH("RIGHT")

  btn.label = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  btn.label:SetJustifyH("LEFT")
  btn.label:SetPoint("RIGHT", btn.right, "LEFT", -6, 0)

  btn:SetScript("OnClick", function() OnRowClick(this, arg1) end)
  btn:SetScript("OnEnter", function() HPL.RowTooltip(this) end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return btn
end

local function CreateWindow()
  frame = CreateFrame("Frame", "PokeHuntLogFrame", UIParent)
  frame:SetWidth(WIDTH)
  frame:SetHeight(HEIGHT)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  Backdrop(frame, true)
  frame:Hide()

  local pos = HPL.db.settings.position
  if type(pos) == "table" and pos.point then
    frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end

  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    local point, _, relPoint, x, y = this:GetPoint()
    HPL.db.settings.position = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  frame:SetScript("OnShow", function() HPL.RefreshUI() end)
  frame:SetScript("OnHide", function() HPL.assigning = nil end)
  table.insert(UISpecialFrames, "PokeHuntLogFrame")

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("PokeHuntLog")

  local close = CreateFrame("Button", "PokeHuntLogCloseButton", frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() frame:Hide() end)

  local credit = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  credit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 46)
  credit:SetText(GREY .. "Made by " .. END .. "|cffabd473stealthzi" .. END .. GREY .. "   v" .. HPL.VERSION .. END)

  local collapseButton = CreateFrame("Button", "PokeHuntLogCollapseButton", frame, "UIPanelButtonTemplate")
  collapseButton:SetWidth(110)
  collapseButton:SetHeight(22)
  collapseButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
  collapseButton:SetText("Collapse all")
  collapseButton:SetScript("OnClick", function() HPL.ToggleCollapseAll() end)

  local trainingButton = CreateFrame("Button", "PokeHuntLogTrainingButton", frame, "UIPanelButtonTemplate")
  trainingButton:SetWidth(110)
  trainingButton:SetHeight(22)
  trainingButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -254, 18)
  trainingButton:SetText("Training")
  trainingButton:SetScript("OnClick", function() HPL.ToggleTraining() end)
  Explain(trainingButton, "Training", "Training points, what your pet can learn, and what your hunter trainer has waiting.")

  local exportButton = CreateFrame("Button", "PokeHuntLogExportButton", frame, "UIPanelButtonTemplate")
  exportButton:SetWidth(110)
  exportButton:SetHeight(22)
  exportButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -136, 18)
  exportButton:SetText("Export")
  exportButton:SetScript("OnClick", function() HPL.ShowExport() end)
  Explain(exportButton, "Export", "Your collection as text, ready to copy into Discord or a forum post.")

  local helpButton = CreateFrame("Button", "PokeHuntLogHelpButton", frame, "UIPanelButtonTemplate")
  helpButton:SetWidth(110)
  helpButton:SetHeight(22)
  helpButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
  helpButton:SetText("Help")
  helpButton:SetScript("OnClick", function() HPL.ToggleHelp() end)

  summaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  summaryText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -48)
  summaryText:SetJustifyH("LEFT")

  local searchLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 214, -48)
  searchLabel:SetText(GREY .. "Search" .. END)

  searchBox = CreateFrame("EditBox", "PokeHuntLogSearchBox", frame, "InputBoxTemplate")
  searchBox:SetWidth(190)
  searchBox:SetHeight(18)
  searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 266, -44)
  searchBox:SetAutoFocus(false)
  searchBox:SetScript("OnTextChanged", function()
    HPL.search = this:GetText()
    HPL.RefreshUI()
  end)
  searchBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  searchBox:SetScript("OnEscapePressed", function()
    this:SetText("")
    this:ClearFocus()
  end)
  Explain(searchBox, "Search", "Type a skin, creature or zone name, for example durotar or bear.")

  uncaughtCheck = CreateFrame("CheckButton", "PokeHuntLogUncaughtCheck", frame, "UICheckButtonTemplate")
  uncaughtCheck:SetWidth(24)
  uncaughtCheck:SetHeight(24)
  uncaughtCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 490, -42)
  local checkLabel = getglobal("PokeHuntLogUncaughtCheckText")
  if checkLabel then
    checkLabel:SetText("Uncaught")
  end
  Explain(uncaughtCheck, "Show uncaught skins", "Lists every skin in the game, greyed out, with where to tame it.")
  uncaughtCheck:SetScript("OnClick", function()
    HPL.db.settings.showUncaught = this:GetChecked() and true or false
    HPL.Changed()
  end)

  -- List
  local listBg = CreateFrame("Frame", nil, frame)
  listBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -68)
  listBg:SetWidth(ROW_WIDTH + 34)
  listBg:SetHeight(NUM_ROWS * ROW_HEIGHT + 12)
  Backdrop(listBg, false)
  listBg:SetFrameLevel(frame:GetFrameLevel() + 1)

  scroll = CreateFrame("ScrollFrame", "PokeHuntLogListScroll", frame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 6, -6)
  scroll:SetWidth(ROW_WIDTH)
  scroll:SetHeight(NUM_ROWS * ROW_HEIGHT)
  scroll:SetFrameLevel(frame:GetFrameLevel() + 2)
  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(ROW_HEIGHT, HPL.UpdateList)
  end)

  for i = 1, NUM_ROWS do
    buttons[i] = CreateRow(i)
  end

  emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  emptyText:SetPoint("TOPLEFT", listBg, "TOPLEFT", 16, -40)
  emptyText:SetWidth(ROW_WIDTH - 20)
  emptyText:SetJustifyH("LEFT")
  emptyText:SetText("No pets logged yet.\n\nTame a beast, or call your pet, and it will show up here.\n\n" ..
    "Tick Show uncaught to browse every skin in the game.")
  emptyText:Hide()

  -- Detail panel
  detail = CreateFrame("Frame", nil, frame)
  detail:SetPoint("TOPLEFT", listBg, "TOPRIGHT", 8, 0)
  detail:SetWidth(DETAIL_WIDTH)
  detail:SetHeight(NUM_ROWS * ROW_HEIGHT + 12)
  Backdrop(detail, false)

  detail.model = CreateFrame("PlayerModel", nil, detail)
  detail.model:SetPoint("TOP", detail, "TOP", 0, -8)
  detail.model:SetWidth(DETAIL_WIDTH - 16)
  detail.model:SetHeight(118)
  detail.model.facing = 0
  detail.model:SetScript("OnUpdate", function()
    this.facing = this.facing + arg1 * 0.6
    this:SetFacing(this.facing)
  end)
  detail.model:Hide()

  detail.bigIcon = detail:CreateTexture(nil, "ARTWORK")
  detail.bigIcon:SetWidth(56)
  detail.bigIcon:SetHeight(56)
  detail.bigIcon:SetPoint("TOP", detail, "TOP", 0, -28)
  detail.bigIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  detail.modelHint = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.modelHint:SetPoint("TOP", detail.bigIcon, "BOTTOM", 0, -8)
  detail.modelHint:SetWidth(DETAIL_WIDTH - 20)
  detail.modelHint:SetTextColor(0.5, 0.5, 0.5)
  detail.modelHint:SetText("Summon this pet to see it in 3D")

  detail.title = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  detail.title:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -132)
  detail.title:SetWidth(DETAIL_WIDTH - 20)
  detail.title:SetJustifyH("LEFT")

  detail.text = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  detail.text:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -6)
  detail.text:SetWidth(DETAIL_WIDTH - 20)
  detail.text:SetHeight(NUM_ROWS * ROW_HEIGHT - 160)
  detail.text:SetJustifyH("LEFT")
  detail.text:SetJustifyV("TOP")

  detail.assign = CreateFrame("Button", "PokeHuntLogAssignButton", detail, "UIPanelButtonTemplate")
  detail.assign:SetWidth(84)
  detail.assign:SetHeight(22)
  detail.assign:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 8, 8)
  detail.assign:SetText("Assign skin")
  detail.assign:SetScript("OnClick", function()
    local sel = HPL.selected
    if not sel or sel.kind ~= "pet" then return end
    if HPL.assigning == sel.pet then
      HPL.assigning = nil
    else
      HPL.assigning = sel.pet
      HPL.db.settings.collapsed["t:" .. (sel.pet.ctype or "Beast")] = nil
    end
    HPL.RefreshUI()
  end)

  detail.guess = CreateFrame("Button", "PokeHuntLogGuessButton", detail, "UIPanelButtonTemplate")
  detail.guess:SetWidth(84)
  detail.guess:SetHeight(22)
  detail.guess:SetPoint("LEFT", detail.assign, "RIGHT", 4, 0)
  detail.guess:SetText("Use guess")
  detail.guess:SetScript("OnClick", function()
    local sel = HPL.selected
    local def = this.skin and HPL.skinsById[this.skin]
    if not sel or sel.kind ~= "pet" or not def then return end
    sel.pet.skin = this.skin
    sel.pet.match = "guess"
    HPL.Print(tostring(sel.pet.name) .. " is now logged as " .. def.name .. ".")
    HPL.selected = { kind = "skin", id = this.skin }
    HPL.Changed()
  end)

  detail.forget = CreateFrame("Button", "PokeHuntLogForgetButton", detail, "UIPanelButtonTemplate")
  detail.forget:SetWidth(84)
  detail.forget:SetHeight(22)
  detail.forget:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -8, 8)
  detail.forget:SetText("Forget pet")
  detail.forget:SetScript("OnClick", function()
    local sel = HPL.selected
    if not sel or sel.kind ~= "pet" then return end
    if not IsShiftKeyDown() then
      HPL.Print("hold Shift and click Forget pet to remove " .. tostring(sel.pet.name) .. " from the log.")
      return
    end
    local list = HPL.db.pets[sel.charKey] or {}
    for i = 1, table.getn(list) do
      if list[i] == sel.pet then
        table.remove(list, i)
        break
      end
    end
    if HPL.activePet == sel.pet then HPL.activePet = nil end
    HPL.assigning = nil
    HPL.selected = nil
    HPL.Changed()
  end)
end

-- Collapse every family and type, or open them all again.
function HPL.ToggleCollapseAll()
  local collapsed = HPL.db.settings.collapsed
  local anyOpen = false
  for i = 1, table.getn(HPL.tree) do
    local t = HPL.tree[i]
    if not collapsed["t:" .. t.name] then anyOpen = true end
    for j = 1, table.getn(t.families) do
      if not collapsed["f:" .. t.name .. "/" .. t.families[j].name] then anyOpen = true end
    end
  end
  for i = 1, table.getn(HPL.tree) do
    local t = HPL.tree[i]
    collapsed["t:" .. t.name] = anyOpen or nil
    for j = 1, table.getn(t.families) do
      collapsed["f:" .. t.name .. "/" .. t.families[j].name] = anyOpen or nil
    end
  end
  if anyOpen then collapsed["unknown"] = nil end
  HPL.RefreshUI()
end

function HPL.ToggleWindow()
  if not HPL.db then return end
  if not frame then CreateWindow() end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end
