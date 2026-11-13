local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Macro Tweaks"],
  description = T["Adds missing interactive /equip, /use, attack and focus aliases using ClassicAPI's native parser when available, and keeps executed macro commands out of chat history."],
  expansions = { ["vanilla"] = true, ["tbc"] = false },
  maintainer = "@shagu (GitHub)",
  category = T["Macro"],
  enabled = true,
})

module.enable = function(self)
  if self.installed then return end
  self.installed = true
  if not API.nativemacrocommands then
    -- Only older APIs need interception; current ClassicAPI owns metadata.
    local hookSendChatMessage = _G.SendChatMessage
    local function IsShowTooltipMetadata(msg)
      if not msg then return false end

      local line = string.gsub(msg, "^%s+", "")
      line = string.gsub(line, "%s+$", "")

      return line == "#showtooltip"
        or string.find(line, "^#showtooltip%s+") ~= nil
    end

    function _G.SendChatMessage(msg, a1, a2, a3, a4, a5, a6, a7, a8)
      if IsShowTooltipMetadata(msg) then return end
      return hookSendChatMessage(msg, a1, a2, a3, a4, a5, a6, a7, a8)
    end
  end

  -- do not write executed macro commands into chat input history
  if not ChatFrameEditBox._AddHistoryLine then
    local userinput

    ChatFrameEditBox._AddHistoryLine = ChatFrameEditBox.AddHistoryLine
    ChatFrameEditBox.AddHistoryLine = function(self, text)
      if not userinput and text then
        if string.find(text, "^/run%s*") then return end
        if string.find(text, "^/script%s*") then return end
        if string.find(text, "^/cast%s*") then return end
        if string.find(text, "^/startattack%s*") then return end
        if string.find(text, "^/stopattack%s*") then return end
        if string.find(text, "^/focus%s*") then return end
        if string.find(text, "^/clearfocus%s*") then return end
      end
      ChatFrameEditBox._AddHistoryLine(self, text)
    end

    local OnEnter = ChatFrameEditBox:GetScript("OnEnterPressed")
    ChatFrameEditBox:SetScript("OnEnterPressed", function(a1,a2,a3,a4)
      userinput = true
      if OnEnter then OnEnter(a1,a2,a3,a4) end
      userinput = nil
    end)
  end

  local function GetBagItemName(bag, slot)
    local itemID = API.GetContainerItemID(bag, slot)
    local name = itemID and API.GetItemNameByID(itemID)
    if name then return name end

    local itemLink = API.GetContainerItemLink(bag, slot)
    local linkedID = itemLink and API.GetItemIDFromLink(itemLink)
    local itemName = linkedID and API.GetItemInfo(linkedID)
    return itemName
  end

  local function FindItem(item)
    local wanted = string.lower(item or "")
    for bag = 4, 0, -1 do
      for slot = 1, GetContainerNumSlots(bag) do
        local query = GetBagItemName(bag, slot)
        if query and string.lower(query) == wanted then
          return bag, slot
        end
      end
    end
  end

  -- ClassicAPI exposes several modern macro primitives as Lua functions but
  -- Vanilla does not register their familiar slash-command equivalents.
  --
  -- Use ShaguTweaks-specific command IDs instead of generic STARTATTACK/FOCUS
  -- keys. A SlashCmdList key can exist without the corresponding /command
  -- alias, so testing only SlashCmdList.STARTATTACK can silently skip a valid
  -- registration and leave Vanilla reporting "Type '/help'...".
  local function TrimUnit(msg)
    if not msg then return nil end
    local _, _, unit = string.find(msg, "^%s*(.-)%s*$")
    return unit ~= "" and unit or nil
  end

  local function IsSlashRegistered(command)
    command = string.lower(command)
    for key, value in pairs(_G) do
      if type(key) == "string"
        and string.find(key, "^SLASH_")
        and type(value) == "string"
        and string.lower(value) == command then
        return true
      end
    end
    return false
  end

  local function RegisterSlashAlias(id, command, handler)
    if IsSlashRegistered(command) then return end
    _G["SLASH_" .. id .. "1"] = command
    if API.nativemacrocommands then
      -- These commands are native macro primitives even if no interactive
      -- chat alias exists. Preserve conditions, item links and native targeting.
      _G.SlashCmdList[id] = function(msg)
        _G.RunMacroText(command .. " " .. (msg or ""))
      end
    else
      _G.SlashCmdList[id] = handler
    end
  end

  RegisterSlashAlias("SHAGUTWEAKS_STARTATTACK", "/startattack", function(msg)
    API.StartAttack(TrimUnit(msg))
  end)

  RegisterSlashAlias("SHAGUTWEAKS_STOPATTACK", "/stopattack", function()
    API.StopAttack()
  end)

  RegisterSlashAlias("SHAGUTWEAKS_FOCUS", "/focus", function(msg)
    API.FocusUnit(TrimUnit(msg))
  end)

  RegisterSlashAlias("SHAGUTWEAKS_CLEARFOCUS", "/clearfocus", function()
    API.ClearFocus()
  end)

  local function EquipOrUse(msg)
    if not msg or msg == "" then return end

    local bag, slot
    local _, _, parsedBag, parsedSlot = string.find(msg, "^(%d+)%s+(%d+)$")
    if parsedBag and parsedSlot then
      bag, slot = parsedBag, parsedSlot
    else
      local _, _, inventorySlot = string.find(msg, "^(%d+)$")
      if inventorySlot then
        slot = inventorySlot
      else
        bag, slot = FindItem(msg)
      end
    end

    bag = bag and tonumber(bag) or nil
    slot = slot and tonumber(slot) or nil

    if bag and slot then
      UseContainerItem(bag, slot)
    elseif slot then
      UseInventoryItem(slot)
    end
  end

  -- Keep the original Macro Tweaks conveniences, but do not steal /equip or
  -- /use from another addon that already registered either command.
  RegisterSlashAlias("SHAGUTWEAKS_EQUIP", "/equip", EquipOrUse)
  RegisterSlashAlias("SHAGUTWEAKS_USE", "/use", EquipOrUse)
end
