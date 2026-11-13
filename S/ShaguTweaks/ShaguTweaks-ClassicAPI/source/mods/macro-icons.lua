local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API
local libspell = ShaguTweaks.libspell

local module = ShaguTweaks:register({
  title = T["Macro Icons"],
  description = T["Adds legacy --showtooltip and /pfcast icon hints. Current ClassicAPI handles ordinary macro icons and preserves manually chosen icons."],
  expansions = { ["vanilla"] = true, ["tbc"] = false },
  maintainer = "@shagu (GitHub)",
  category = T["Macro"],
  enabled = true,
})

local function EnableNativeIcons(self)
  if not API.macrodisplay then return false end
  -- Another macro parser owns its custom syntax and display decisions.
  if _G.CleveRoids or (type(_G.IsAddOnLoaded) == "function"
    and _G.IsAddOnLoaded("SuperCleveRoidMacros")) then return true end
  local entries, owned = {}, {}
  local driver = CreateFrame("Frame", "ShaguTweaksMacroIcons", UIParent)
  self.nativeDriver = driver
  local ticker
  local customEvents = { "MODIFIER_STATE_CHANGED", "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
  local function Release()
    if ticker then ticker:Cancel(); ticker = nil end
    for id in pairs(owned) do _G.C_Macro.SetMacroDisplay(id, nil); owned[id] = nil end
    entries = {}
  end
  local function Refresh()
    for id, entry in pairs(entries) do
      local value, unit = entry.value, nil
      if entry.conditional and type(_G.SecureCmdOptionParse) == "function" then
        value, unit = _G.SecureCmdOptionParse(value, true)
        value = value or false
      end
      if not entry.published or entry.lastValue ~= value or entry.lastUnit ~= unit then
        local resolved = _G.C_Macro.SetMacroDisplay(id, value, unit)
        entry.lastValue, entry.lastUnit = value, unit
        entry.published = value == false or resolved
      end
    end
  end
  local function Rebuild()
    if driver.rebuilding then return end
    driver.rebuilding = true
    Release()
    local maximum = math.max(_G.MAX_MACROS or 36,
      (_G.MAX_ACCOUNT_MACROS or 0) + (_G.MAX_CHARACTER_MACROS or 0))
    local conditional = false
    for id = 1, maximum do
      local name, _, body = GetMacroInfo(id)
      if name and body then
        local explicit, hint, pfcast
        for line in string.gfind(body, "[^\n]+") do
          local _, _, directive = string.find(line, "^%s*(#[^%s]+)")
          if directive == "#showtooltip" or directive == "#show" then explicit = true end
          local _, _, value = string.find(line, "%-%-showtooltip%s+(.+)")
          hint = hint or value
          if not pfcast then _, _, pfcast = string.find(line, "^%s*/pfcast%s+(.+)") end
        end
        -- Native directives always win. Normal macros need no Lua icon writes,
        -- action-bar scans or spellbook lookups at all.
        local value = not explicit and (hint or pfcast)
        if value then
          value = string.gsub(value, "%s+$", "")
          local hasConditions = string.find(value, "[", 1, true) ~= nil
          entries[id] = { value = value, conditional = hasConditions }
          owned[id] = true
          conditional = conditional or hasConditions
        end
      end
    end
    Refresh()
    -- Only conditional custom hints need periodic re-evaluation (e.g. stance
    -- or cooldown conditions). Ordinary native macros have no Lua poller.
    if conditional and _G.C_Timer and type(_G.C_Timer.NewTicker) == "function" then
      ticker = _G.C_Timer.NewTicker(.2, Refresh)
    end
    for _, name in ipairs(customEvents) do
      if conditional then driver:RegisterEvent(name) else driver:UnregisterEvent(name) end
    end
    if next(entries) then
      driver:RegisterEvent("SPELLS_CHANGED")
      if _G.C_EventUtils and type(_G.C_EventUtils.IsEventValid) == "function"
        and _G.C_EventUtils.IsEventValid("GET_ITEM_INFO_RECEIVED") then
        driver:RegisterEvent("GET_ITEM_INFO_RECEIVED")
      end
    else
      driver:UnregisterEvent("SPELLS_CHANGED")
      driver:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    driver.rebuilding = nil
  end
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("UPDATE_MACROS")
  driver:RegisterEvent("PLAYER_LOGOUT")
  driver:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_MACROS" then Rebuild()
    elseif event == "PLAYER_LOGOUT" then driver:UnregisterAllEvents(); Release()
    elseif event == "SPELLS_CHANGED" then
      for _, entry in pairs(entries) do entry.published = nil end
      Refresh()
    else Refresh() end
  end)
  Rebuild()
  return true
end

module.enable = function(self)
  if self.installed then return end
  self.installed = true
  if EnableNativeIcons(self) then return end
  local gfind = string.gmatch or string.gfind

  local function BuildMacroCache()
    local cache = {}
    for macroSlot = 1, 36 do
      local name, _, body = GetMacroInfo(macroSlot)
      if name and body then
        cache[name] = { id = macroSlot, body = body }
      end
    end
    return cache
  end

  local function GetMacroData(actionSlot, cache)
    local actionType, id = API.GetActionInfo(actionSlot)
    if actionType == "macro" and id then
      local _, _, body = GetMacroInfo(id)
      if body then return id, body end
    end

    local macroName = GetActionText(actionSlot)
    local entry = macroName and cache[macroName]
    if entry then return entry.id, entry.body end
  end

  local function ParseSpellText(match)
    if not match then return end
    local _, _, spell, rank = string.find(match, "(.+)%((.+)%)")
    return spell or match, rank
  end

  local function ResolveSpell(body, macroSlot)
    if not body then return end

    local customTooltip
    local fallback

    for line in gfind(body, "[^%\n]+") do
      -- Explicit #showtooltip always wins.
      local _, _, match = string.find(line, "^#showtooltip%s+(.+)")
      if match then
        return ParseSpellText(match)
      end

      -- Preserve the historical ShaguTweaks custom override.
      if not customTooltip then
        _, _, customTooltip = string.find(line, "%-%-showtooltip%s+(.+)")
      end

      -- Keep text parsing as a fallback for old/stale macro caches and /pfcast.
      if not fallback then
        _, _, fallback = string.find(line, "^/cast%s+(.+)")
      end
      if not fallback then
        _, _, fallback = string.find(line, "^/pfcast%s+(.+)")
      end
      if not fallback then
        _, _, fallback = string.find(line, "CastSpellByName%(%\"(.+)%\"%)")
      end
    end

    if customTooltip then
      return ParseSpellText(customTooltip)
    end

    -- ClassicAPI already resolves and caches the macro's primary spell.
    -- This is the correct modern behavior for a bare "#showtooltip" line and
    -- also covers /castsequence, CastSpellByName and CastSpellNoToggle.
    if macroSlot then
      local spell, rank = API.GetMacroSpell(macroSlot)
      if spell then
        return spell, rank ~= "" and rank or nil
      end
    end

    return ParseSpellText(fallback)
  end

  local function ButtonMacroScan(bar, macroCache)
    if not bar:IsVisible() then return end

    local prefix = bar:GetName()
    prefix = bar == MainMenuBar and "Action" or prefix
    prefix = bar == BonusActionBarFrame and "BonusAction" or prefix

    for index = 1, 12 do
      local button = _G[prefix.."Button"..index]
      local icon = _G[prefix.."Button"..index.."Icon"]
      if not button then break end

      local actionSlot = ActionButton_GetPagedID(button)
      local texture = GetActionTexture(actionSlot)
      button.spellslot, button.booktype = nil, nil

      local macroSlot, body = GetMacroData(actionSlot, macroCache)
      local spell, rank = ResolveSpell(body, macroSlot)
      if spell then
        button.spellslot, button.booktype = libspell.GetSpellIndex(spell, rank)

        if button.spellslot and button.booktype then
          texture = GetSpellTexture(button.spellslot, button.booktype) or texture
        end
      end

      if icon and texture and texture ~= icon:GetTexture() then
        icon:SetTexture(texture)
      end
    end
  end

  local bars = {
    MainMenuBar, BonusActionBarFrame, MultiBarRight, MultiBarLeft,
    MultiBarBottomRight, MultiBarBottomLeft
  }

  local macroicons = CreateFrame("Frame", "ShaguTweaksMacroIcons", UIParent)
  macroicons:RegisterEvent("PLAYER_ENTERING_WORLD")
  macroicons:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  macroicons:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
  macroicons:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
  macroicons:RegisterEvent("ACTIONBAR_SHOWGRID")
  macroicons:RegisterEvent("UPDATE_MACROS")
  macroicons:SetScript("OnEvent", function()
    local macroCache = BuildMacroCache()
    for _, bar in ipairs(bars) do
      ButtonMacroScan(bar, macroCache)
    end
  end)
end
