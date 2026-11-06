-- PokeHuntLog: adds a line to a beast's tooltip saying whether you've caught its skin yet.

local HPL = PokeHuntLog

local busy = false

local function SkinLine()
  if not HPL.db or not HPL.db.settings.tooltip or not HPL.IsHunter() then return nil end
  if not UnitExists("mouseover") then return nil end
  if UnitIsPlayer("mouseover") or UnitPlayerControlled("mouseover") then return nil end
  local family = UnitCreatureFamily("mouseover")
  if not family then return nil end

  local name = UnitName("mouseover")
  local ids = HPL.NpcIdsFromGuid(HPL.UnitGuid("mouseover"))
  local skinId = HPL.ResolveSkin(family, name, ids)
  if not skinId then
    return "PokeHuntLog: " .. family .. ", skin not in the list", 0.6, 0.6, 0.6
  end
  local def = HPL.skinsById[skinId]
  if HPL.caught[skinId] then
    local c = HPL.caught[skinId]
    return "PokeHuntLog: " .. def.name .. " - caught (best " .. (c.maxLevel or 0) .. ")", 0.6, 0.6, 0.6
  end
  return "PokeHuntLog: " .. def.name .. " - NEW skin!", 0.25, 1, 0.25
end

local function AddSkinLine()
  if busy then return end
  busy = true
  local ok, line, r, g, b = pcall(SkinLine)
  if ok and line then
    GameTooltip:AddLine(line, r, g, b)
    GameTooltip:Show()
  end
  busy = false
end

function HPL.InitTooltip()
  local original = GameTooltip:GetScript("OnShow")
  GameTooltip:SetScript("OnShow", function()
    if original then original() end
    AddSkinLine()
  end)
end
