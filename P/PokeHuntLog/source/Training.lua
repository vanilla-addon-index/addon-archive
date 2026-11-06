-- PokeHuntLog: the Training panel and its reminders.
--
-- Pet abilities in this version of the game work in two steps: taming a beast that knows an ability rank
-- unlocks that rank for you, and then you spend the pet's training points at a pet trainer to teach it.
-- The log already records which beast each pet was tamed from, so it knows which ranks you have unlocked
-- and can point at a beast that knows the next one.
--
-- Hunter abilities can't be listed by an addon unless a trainer window is open, so the list is remembered
-- from the last time you spoke to one.

local HPL = PokeHuntLog

local GOLD = "|cffffd100"
local GREY = "|cff9d9d9d"
local GREEN = "|cff40ff40"
local ORANGE = "|cffff9933"
local WHITE = "|cffffffff"
local END = "|r"

local frame, panelText, viewButton, child
local remindedLevel, remindedPoints = nil, nil
HPL.trainingView = "pet"   -- "pet" or "abilities"

-- "Claw 2" -> "Claw", 2
local function SplitRank(text)
  if not text or text == "" then return nil end
  local _, _, name, rank = string.find(text, "^(.-)%s+(%d+)$")
  if not name then return text, 1 end
  return name, tonumber(rank)
end

-- What each pet knew when tamed, gathered across every character.
function HPL.UnlockedRanks()
  local unlocked = {}
  for charKey, list in pairs(HPL.db.pets) do
    for i = 1, table.getn(list) do
      local pet = list[i]
      local knows = pet.knows
      if not knows and pet.creature and HPL.knowsByCreature then
        knows = HPL.knowsByCreature[string.lower(pet.creature)]
      end
      local taught = HPL.ParseKnows(knows)
      for t = 1, table.getn(taught) do
        local name, rank = taught[t].name, taught[t].rank
        if not unlocked[name] or unlocked[name] < rank then
          unlocked[name] = rank
        end
      end
    end
  end
  return unlocked
end

-- Beasts that teach an ability rank, lowest level first.
function HPL.TeachersFor(abilityName, rank)
  local list = HPL.teachers and HPL.teachers[string.lower(abilityName) .. " " .. rank]
  if not list then return {} end
  local copy = {}
  for i = 1, table.getn(list) do copy[i] = list[i] end
  table.sort(copy, function(a, b) return a.lowLevel < b.lowLevel end)
  return copy
end

-- The lowest level beast that teaches this rank.
function HPL.WhereToUnlock(abilityName, rank)
  local teachers = HPL.TeachersFor(abilityName, rank)
  if table.getn(teachers) == 0 then return nil end
  local first = teachers[1]
  return { npc = { 0, first.name, first.level, first.zone, first.tag }, low = first.lowLevel }
end

local function PetPoints()
  local ok, total, spent = pcall(GetPetTrainingPoints)
  if not ok or not total then return nil end
  return total - (spent or 0), total, spent or 0
end

local function PetKnows()
  local known = {}
  local pet = HPL.activePet
  if pet and pet.spells then
    for i = 1, table.getn(pet.spells) do
      local name, rank = SplitRank(pet.spells[i])
      if name then known[name] = rank end
    end
  end
  return known
end

------------------------------------------------------------------------------------------------
-- Pet and hunter trainers: remembered from the last visit
------------------------------------------------------------------------------------------------

-- The kind of trainer is told by its list headers: pet trainers file everything under "Beast Training",
-- hunter trainers under the talent trees. Anyone else (professions, weapon masters) is ignored.
local TRAINER_HEADERS = {
  ["Beast Training"] = "pet",
  ["Beast Mastery"] = "hunter", ["Marksmanship"] = "hunter", ["Survival"] = "hunter",
}
HPL.TRAINER_LABELS = { pet = "Pet trainer", hunter = "Hunter trainer" }

local function TrainerRecords()
  if not HPL.db.trainers then HPL.db.trainers = {} end
  local key = HPL.CharKey()
  if not HPL.db.trainers[key] then HPL.db.trainers[key] = {} end
  return HPL.db.trainers[key]
end

local function ScanTrainer()
  if not HPL.db then return end
  local tradeOk, isTrade = pcall(IsTradeskillTrainer)
  if tradeOk and isTrade then return end
  local ok, count = pcall(GetNumTrainerServices)
  if not ok or not count or count == 0 then return end
  local services, kind = {}, nil
  for i = 1, count do
    local name, rank, category = GetTrainerServiceInfo(i)
    if category == "header" then
      kind = kind or TRAINER_HEADERS[name or ""]
    elseif name then
      local levelOk, level = pcall(GetTrainerServiceLevelReq, i)
      table.insert(services, {
        name = name, rank = rank, category = category, level = levelOk and level or nil,
      })
    end
  end
  if not kind then
    HPL.Debug("trainer ignored: not a pet or hunter trainer")
    return
  end
  if table.getn(services) == 0 then return end
  TrainerRecords()[kind] = { when = time(), zone = GetRealZoneText(), services = services }
  HPL.Debug(kind .. " trainer scan: " .. table.getn(services) .. " services")
end

-- What a trainer had that you (hunter trainer) or your pet (pet trainer) are now high enough level for.
local function TrainerReady(kind)
  local record = HPL.db.trainers and HPL.db.trainers[HPL.CharKey()] and HPL.db.trainers[HPL.CharKey()][kind]
  if not record then return nil end
  local level
  if kind == "pet" then
    level = UnitExists("pet") and UnitLevel("pet") or 0
  else
    level = UnitLevel("player") or 0
  end
  local ready, later = {}, {}
  for i = 1, table.getn(record.services) do
    local s = record.services[i]
    local label = s.name .. (s.rank and s.rank ~= "" and (" " .. s.rank) or "")
    if s.category == "available" or (s.level and s.level <= level and s.category ~= "used") then
      table.insert(ready, label)
    elseif s.category == "unavailable" and s.level then
      table.insert(later, { label = label, level = s.level })
    end
  end
  return ready, later, record
end

------------------------------------------------------------------------------------------------
-- Panel text
------------------------------------------------------------------------------------------------

function HPL.TrainingText()
  local lines = {}
  local function Line(text) table.insert(lines, text) end

  local pet = HPL.activePet
  local unlocked = HPL.UnlockedRanks()
  local known = PetKnows()

  Line(GOLD .. "Your pet" .. END)
  if pet and UnitExists("pet") then
    local available, total = PetPoints()
    Line(WHITE .. pet.name .. END .. GREY .. "  " .. tostring(pet.family) .. ", level " ..
      tostring(pet.level) .. END)
    if available then
      local text = available .. " of " .. total .. " training points unspent"
      if available > 0 then
        Line(GREEN .. text .. END .. GREY .. " - a pet trainer can spend them" .. END)
      else
        Line(GREY .. text .. END)
      end
    end
    if pet.spells and table.getn(pet.spells) > 0 then
      Line(GREY .. "Knows: " .. table.concat(pet.spells, ", ") .. END)
    end
  else
    Line(GREY .. "Call your pet to see what it can train." .. END)
  end

  -- What this pet's family can learn, and whether you have the rank unlocked.
  local family = pet and pet.family
  local info = family and HPL.FamilyInfo(family)
  if info and pet then
    Line(" ")
    Line(GOLD .. "What a " .. family .. " can learn" .. END)
    local all = {}
    for i = 1, table.getn(info.abilities or {}) do table.insert(all, info.abilities[i]) end
    for i = 1, table.getn(info.passives or {}) do table.insert(all, info.passives[i]) end
    for i = 1, table.getn(all) do
      local ability = all[i]
      local ranks = PokeHuntLog_Abilities and PokeHuntLog_Abilities[ability]
      local haveRank = unlocked[ability] or 0
      local knownRank = known[ability] or 0
      if ranks then
        -- The best rank this pet could train right now: unlocked by you and within its level.
        local best, nextUp
        for r = 1, table.getn(ranks) do
          local entry = ranks[r]
          if entry[1] <= haveRank and entry[2] <= (pet.level or 0) then
            best = entry
          elseif not nextUp and entry[1] > haveRank then
            nextUp = entry
          end
        end
        local text = WHITE .. ability .. END
        if best and best[1] > knownRank then
          text = text .. GREEN .. "  train rank " .. best[1] .. END .. GREY .. " (" .. best[3] .. " TP)" .. END
        elseif knownRank > 0 then
          text = text .. GREY .. "  knows rank " .. knownRank .. END
        else
          text = text .. GREY .. "  not unlocked yet" .. END
        end
        if nextUp then
          local where = HPL.WhereToUnlock(ability, nextUp[1])
          if where then
            text = text .. "\n" .. GREY .. "   rank " .. nextUp[1] .. ": tame " .. where.npc[2] ..
              " (" .. where.npc[3] .. ", " .. where.npc[4] .. ")" .. END
          end
        end
        Line(text)
      end
    end
  end

  local kinds = { "pet", "hunter" }
  for k = 1, 2 do
    local kind = kinds[k]
    Line(" ")
    Line(GOLD .. HPL.TRAINER_LABELS[kind] .. END)
    local ready, later, record = TrainerReady(kind)
    if not record then
      Line(GREY .. "Visit a " .. string.lower(HPL.TRAINER_LABELS[kind]) ..
        " once and the log will remember what it offers." .. END)
    else
      Line(GREY .. "Seen " .. HPL.FormatDate(record.when) .. (record.zone and (" in " .. record.zone) or "") .. END)
      if table.getn(ready) > 0 then
        Line(GREEN .. "Ready to learn: " .. END .. table.concat(ready, ", "))
      else
        Line(GREY .. "Nothing waiting at " .. (kind == "pet" and "your pet's" or "your") .. " level." .. END)
      end
      if table.getn(later) > 0 then
        table.sort(later, function(a, b) return a.level < b.level end)
        local upcoming = {}
        for i = 1, math.min(table.getn(later), 6) do
          table.insert(upcoming, later[i].label .. " (" .. later[i].level .. ")")
        end
        Line(GOLD .. "Coming up: " .. END .. table.concat(upcoming, ", "))
      end
    end
  end

  return table.concat(lines, "\n")
end


-- Every pet ability, its ranks, and the beasts that teach each rank.
function HPL.AbilitiesText()
  local lines = {}
  local function Line(text) table.insert(lines, text) end
  local unlocked = HPL.UnlockedRanks()
  local playerLevel = UnitLevel("player") or 0

  Line(GREY .. "Taming a beast unlocks the ability rank it knows. A pet trainer then teaches it to any of " ..
    "your pets, for training points." .. END)
  Line(" ")

  local names = {}
  for ability in pairs(PokeHuntLog_Abilities or {}) do table.insert(names, ability) end
  table.sort(names)

  for n = 1, table.getn(names) do
    local ability = names[n]
    local ranks = PokeHuntLog_Abilities[ability]
    local families = HPL.FamiliesWithAbility(ability)
    local have = unlocked[ability] or 0
    local fromTrainer = HPL.TRAINER_ABILITIES[ability]
    local head = GOLD .. ability .. END
    if fromTrainer then head = head .. GREEN .. "   any pet trainer teaches this" .. END end
    Line(head .. GREY .. "   " .. table.concat(families, ", ") .. END)
    for r = 1, table.getn(ranks) do
      local rank, level, cost = ranks[r][1], ranks[r][2], ranks[r][3]
      local head = "  " .. WHITE .. "rank " .. rank .. END .. GREY .. "  pet lvl " .. level ..
        ", " .. cost .. " TP" .. END
      if have >= rank then
        Line(head .. GREEN .. "  unlocked" .. END)
      else
        local teachers = HPL.TeachersFor(ability, rank)
        if table.getn(teachers) == 0 then
          if fromTrainer then
            Line(head .. GREY .. "  buy it from a pet trainer" .. END)
          else
            Line(head .. GREY .. "  no beast in the list teaches this" .. END)
          end
        else
          local first = teachers[1]
          local more = ""
          if table.getn(teachers) > 1 then
            more = GREY .. " +" .. (table.getn(teachers) - 1) .. END
          end
          local mark = ""
          if first.lowLevel > 0 and first.lowLevel <= playerLevel then
            mark = GREEN .. " tameable now" .. END
          end
          Line(head .. "  " .. WHITE .. first.name .. END .. GREY .. " (" .. first.level .. ", " ..
            first.zone .. ")" .. END .. mark .. more)
        end
      end
    end
    Line(" ")
  end

  return table.concat(lines, "\n")
end

------------------------------------------------------------------------------------------------
-- Panel and reminders
------------------------------------------------------------------------------------------------

local function CreatePanel()
  frame = CreateFrame("Frame", "PokeHuntLogTrainingFrame", UIParent)
  frame:SetWidth(620)
  frame:SetHeight(520)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  HPL.Opaque(frame, 11)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:Hide()
  table.insert(UISpecialFrames, "PokeHuntLogTrainingFrame")

  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", frame, "TOP", 0, -18)
  title:SetText("Training")
  local version = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  version:SetPoint("TOP", title, "BOTTOM", 0, -2)
  version:SetText(GREY .. "PokeHuntLog v" .. HPL.VERSION .. END)

  local close = CreateFrame("Button", "PokeHuntLogTrainingCloseButton", frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() frame:Hide() end)

  local scroll = CreateFrame("ScrollFrame", "PokeHuntLogTrainingScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
  scroll:SetWidth(550)
  scroll:SetHeight(392)

  child = CreateFrame("Frame", "PokeHuntLogTrainingChild", scroll)
  child:SetWidth(550)
  child:SetHeight(1200)
  scroll:SetScrollChild(child)

  panelText = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  panelText:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
  panelText:SetWidth(544)
  panelText:SetJustifyH("LEFT")
  panelText:SetJustifyV("TOP")

  viewButton = CreateFrame("Button", "PokeHuntLogTrainingViewButton", frame, "UIPanelButtonTemplate")
  viewButton:SetWidth(130)
  viewButton:SetHeight(22)
  viewButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)
  viewButton:SetScript("OnClick", function()
    if HPL.trainingView == "pet" then HPL.trainingView = "abilities" else HPL.trainingView = "pet" end
    HPL.ShowTraining()
  end)
end

-- The panel holds either view; the scroll child grows to fit whichever is showing.
local function FillPanel()
  local text, lineCount
  if HPL.trainingView == "abilities" then
    text = HPL.AbilitiesText()
    viewButton:SetText("Show my pet")
  else
    text = HPL.TrainingText()
    viewButton:SetText("All abilities")
  end
  panelText:SetText(text)
  lineCount = 1
  for _ in string.gfind(text, "\n") do lineCount = lineCount + 1 end
  child:SetHeight(math.max(400, lineCount * 14 + 40))
end

function HPL.ShowTraining()
  if not HPL.db then return end
  if not frame then CreatePanel() end
  FillPanel()
  frame:Show()
end

function HPL.ToggleTraining()
  if frame and frame:IsShown() then
    frame:Hide()
  else
    HPL.ShowTraining()
  end
end

-- Chat reminders: unspent training points, and abilities waiting at the trainer.
function HPL.TrainingReminder()
  if not HPL.db or not HPL.db.settings.trainerReminder or not HPL.IsHunter() then return end
  local level = UnitLevel("player") or 0

  local available = PetPoints()
  if available and available > 0 and UnitExists("pet") and remindedPoints ~= available then
    remindedPoints = available
    HPL.Print(available .. " unspent pet training points. A pet trainer can turn them into new abilities " ..
      "(/petlog training).")
  end

  if remindedLevel ~= level then
    local kinds = { "pet", "hunter" }
    for k = 1, 2 do
      local ready = TrainerReady(kinds[k])
      if ready and table.getn(ready) > 0 then
        remindedLevel = level
        HPL.Print(table.getn(ready) .. " ability(s) waiting at your " .. string.lower(HPL.TRAINER_LABELS[kinds[k]]) ..
          ": " .. table.concat(ready, ", ") .. ".")
      end
    end
  end
end

function HPL.InitTraining()
  local f = CreateFrame("Frame")
  local events = { "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "UNIT_PET" }
  for i = 1, table.getn(events) do
    pcall(f.RegisterEvent, f, events[i])
  end
  f:SetScript("OnEvent", function()
    if event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
      HPL.After(0.5, function() ScanTrainer() end)
    elseif event == "PLAYER_LEVEL_UP" then
      remindedLevel = nil
      HPL.After(3, function() HPL.TrainingReminder() end)
    elseif event == "PLAYER_ENTERING_WORLD" then
      HPL.After(8, function() HPL.TrainingReminder() end)
    elseif event == "UNIT_PET" and arg1 == "player" then
      HPL.After(4, function() HPL.TrainingReminder() end)
    end
    if frame and frame:IsShown() then
      FillPanel()
    end
  end)
end
