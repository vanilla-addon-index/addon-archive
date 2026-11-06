-- Ade Alts: events
local AA = AdeAlts

----------------------------------------------------------------------
-- driver: timers, ready alerts, delayed broadcast
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
local acc, filet, metat = 0, 0, 0
driver:SetScript("OnUpdate", function()
  acc = acc + arg1
  if acc < 1 then return end
  acc = 0
  local now = GetTime()

  for i = table.getn(AA.timers), 1, -1 do
    local t = AA.timers[i]
    if t and t.t <= now then
      table.remove(AA.timers, i)
      t.fn()
    end
  end

  if not AA.me then return end

  if AA.bagDirty then
    AA.bagDirty = false
    AA.ScanBags()
    AA.ScanSelf()
  end

  if AA.fileDirty and now - AA.lastFileWrite > 10 then
    AA.FileSync()
  end

  -- ready alerts for the logged-in character
  local nowt = time()
  for key, exp in pairs(AA.me.cds) do
    if exp > 0 and exp <= nowt then
      AA.Print("|cff40ff40" .. key .. " is ready!|r")
      AA.me.cds[key] = 0
      AA.me.updated = time()
      AA.dirty = true
    end
  end

  metat = metat + 1
  if metat >= 30 then
    metat = 0
    AA.ScanSelf()
  end

  filet = filet + 1
  if filet >= 20 then
    filet = 0
    AA.FileMerge()
  end

  if AA.dirty and now - AA.lastBroadcast > 3 then
    AA.dirty = false
    AA.Broadcast()
    AA.FileSync()
  end
end)

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("TRADE_SKILL_SHOW")
ev:RegisterEvent("TRADE_SKILL_UPDATE")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("BAG_UPDATE_COOLDOWN")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:RegisterEvent("BANKFRAME_CLOSED")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
ev:RegisterEvent("SKILL_LINES_CHANGED")
ev:RegisterEvent("CRAFT_SHOW")
ev:RegisterEvent("CRAFT_UPDATE")
ev:RegisterEvent("CHAT_MSG_ADDON")

ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == AA.ADDON then
      if not AdeAltsDB then
        -- migrate from the old ProfCD Tracker saved variables, if present
        AdeAltsDB = ProfCDTrackerDB or {}
      end
      ProfCDTrackerDB = nil
      AA.db = AdeAltsDB
      AA.db.chars = AA.db.chars or {}
      AA.db.items = AA.db.items or {}
      -- drop the hunter Survival talent line that older versions stored as a profession
      for _, ch in pairs(AA.db.chars) do
        local sv = ch.prof and ch.prof.Survival
        if sv and AA.BadProf("Survival", sv.m) then ch.prof.Survival = nil end
      end
      AA.ApplyStyle()
      AA.ApplyConfig()
      AA.db.angle = AA.db.angle or 200
      if AA.db.hidden then AA.btn:Hide() end
      AA.PlaceButton()
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    if not AA.db then return end
    if not AA.loaded then
      AA.loaded = true
      local name = UnitName("player")
      local realm = GetRealmName()
      local _, class = UnitClass("player")
      AA.myKey = name .. "-" .. realm
      AA.me = AA.db.chars[AA.myKey]
      if not AA.me then
        AA.me = { name = name, realm = realm, cds = {} }
        AA.db.chars[AA.myKey] = AA.me
      end
      AA.me.class = class
      AA.me.remote = nil
      AA.me.updated = AA.me.updated or time()
      if AA.ClampRecord(AA.me) then AA.me.updated = time(); AA.dirty = true end
      AA.me.cds = AA.me.cds or {}
      AA.StyleButton()
      AA.enterTime = GetTime()
      AA.After(2, function() AA.ScanBags(); AA.ScanSelf() end)
      AA.After(5, function() AA.ScanSelf() end)
      AA.After(8, function() AA.ScanSelf() end)
      AA.After(13, function() AA.ScanSelf() end)
      AA.After(20, function() AA.ScanSelf() end)
      AA.After(4, AA.DockInPfUI)
      AA.After(10, function() AA.Send("R"); AA.Broadcast() end)
      AA.After(3, AA.FileSync)
      AA.After(6, AA.ShowReadyAlert)
    end
    AA.bagDirty = true

  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
    AA.ScanTradeSkills()

  elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    AA.ScanCrafts()

  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" then AA.bagDirty = true end

  elseif event == "SKILL_LINES_CHANGED" then
    AA.bagDirty = true

  elseif event == "BANKFRAME_OPENED" then
    AA.bankOpen = true
    AA.bagDirty = true
  elseif event == "BANKFRAME_CLOSED" then
    AA.ScanSelf()
    AA.bankOpen = false
  elseif event == "PLAYER_MONEY" or event == "PLAYER_LEVEL_UP" then
    AA.bagDirty = true
  elseif event == "PLAYER_LOGOUT" then
    if AA.me then AA.FileSync() end
  elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" then
    AA.bagDirty = true

  elseif event == "CHAT_MSG_ADDON" then
    if arg1 == AA.PREFIX and AA.db and AA.db.chat and arg4 ~= UnitName("player") then
      if arg2 == "R" then
        if AA.me and GetTime() - AA.lastReply > 5 then
          AA.lastReply = GetTime()
          AA.Broadcast()
        end
      else
        AA.ReceiveRecord(arg2)
        AA.Refresh()
      end
    end
  end
end)

----------------------------------------------------------------------
-- slash commands
----------------------------------------------------------------------
SLASH_PROFCD1 = "/pcd"
SLASH_PROFCD2 = "/profcd"
SLASH_PROFCD3 = "/cdt"
SLASH_PROFCD4 = "/ade"
SLASH_PROFCD5 = "/adealts"
SlashCmdList["PROFCD"] = function(msg)
  msg = msg or ""
  local _, _, cmd, arg = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "show" or cmd == "toggle" or cmd == "alts" then
    AA.ToggleManager()
  elseif cmd == "cd" or cmd == "cooldowns" then
    AA.ToggleWindow()
  elseif cmd == "find" and arg ~= "" then
    AA.sbox:SetText(arg)
    if not AA.M:IsVisible() then AA.M:Show() end
  elseif cmd == "list" then
    for _, e in ipairs(AA.Entries()) do AA.Print(e.l .. "  " .. e.r) end
  elseif cmd == "sync" then
    AA.Send("R")
    AA.Broadcast()
    AA.FileSync()
    AA.Print("synced (shared file: " .. ((ImportFile and ExportFile) and "on" or "off") .. ", chat sync " .. (AA.db.chat and "on" or "off") .. ").")
  elseif cmd == "scan" then
    AA.Print("client reports: level=" .. tostring(UnitLevel("player")) .. " gold(copper)=" .. tostring(GetMoney()))
    AA.ScanSelf()
    AA.ScanBags(true)
    AA.FileSync()
  elseif cmd == "status" then
    if ImportFile and ExportFile then
      AA.Print("SuperWoW file sync: |cff40ff40ON|r (imports\\" .. AA.FILE .. ".txt, shared by all accounts in this game folder)")
    else
      AA.Print("SuperWoW file sync: |cffff6060OFF|r (SuperWoW not detected). Only guild/party/raid chat sync works.")
    end
    local n = 0
    for k in pairs(AA.db.chars) do n = n + 1 end
    AA.Print(n .. " character(s) known.")
  elseif cmd == "export" then
    AA.ShowIO(true)
  elseif cmd == "import" then
    AA.ShowIO(false)
  elseif cmd == "minimap" then
    AA.db.hidden = not AA.db.hidden
    if AA.db.hidden then AA.btn:Hide() else AA.btn:Show(); AA.After(1, AA.DockInPfUI) end
    AA.Print("minimap button " .. (AA.db.hidden and "hidden" or "shown") .. ".")
  elseif cmd == "alert" then
    AA.db.noAlert = not AA.db.noAlert
    AA.Print("login alert " .. (AA.db.noAlert and "disabled" or "enabled") .. ".")
  elseif cmd == "test" then
    AA.ShowReadyAlert(true)
  elseif cmd == "debug" then
    local found = 0
    for bag = 0, 4 do
      for slot = 1, GetContainerNumSlots(bag) do
        local link = GetContainerItemLink(bag, slot)
        local it = AA.ItemFromLink(link)
        if it then
          found = found + 1
          local st, du = GetContainerItemCooldown(bag, slot)
          AA.Print(it.key .. " in bag " .. bag .. " slot " .. slot .. ": start=" .. tostring(st) .. " duration=" .. tostring(du) .. " now=" .. GetTime() .. " remaining=" .. tostring((st or 0) + (du or 0) - GetTime()))
        end
      end
    end
    if found == 0 then AA.Print("no tracked item found in bags 0-4 (is it in the bank?)") end
    for key, exp in pairs(AA.me.cds) do
      AA.Print("stored " .. key .. ": " .. (exp > 0 and (AA.FormatTime(exp - time()) .. " left") or "ready"))
    end
    AA.Print("file sync: " .. ((ImportFile and ExportFile) and "on" or "off"))
  elseif cmd == "bags" then
    for bag = 0, 10 do
      local nm = GetBagName and GetBagName(bag)
      local inv = ""
      if bag >= 1 and bag <= 4 then inv = tostring(ContainerIDToInventoryID(bag))
      elseif bag >= 5 and BankButtonIDToInvSlotID then inv = tostring(BankButtonIDToInvSlotID(bag - 4, 1)) end
      local l = inv ~= "" and GetInventoryItemLink("player", tonumber(inv)) or nil
      local _, _, ln = string.find(l or "", "%[(.-)%]")
      AA.Print("bag " .. bag .. ": name=" .. tostring(nm) .. " slots=" .. tostring(GetContainerNumSlots(bag)) .. " invslot=" .. inv .. " link=" .. tostring(ln))
    end
  elseif cmd == "reset" then
    for k in pairs(AA.me.cds) do AA.me.cds[k] = 0 end
    AA.dirty = true
    AA.Print("cooldowns of this character reset to Ready.")
  elseif cmd == "del" and arg ~= "" then
    local a = string.lower(arg)
    local n = 0
    AA.db.ignored = AA.db.ignored or {}
    for k, c in pairs(AA.db.chars) do
      if k ~= AA.myKey and (string.lower(c.name) == a or string.lower(k) == a) then
        AA.db.chars[k] = nil
        AA.db.ignored[k] = true     -- do not accept this character again from chat / shared file
        n = n + 1
      end
    end
    AA.Print("removed " .. n .. " character(s) and ignoring them from now on (/ade unignore <name> undoes it).")
    AA.fileDirty = true
    AA.Refresh()
    if AA.RefreshManager then AA.RefreshManager() end
  elseif cmd == "unignore" and arg ~= "" then
    local a = string.lower(arg)
    local n = 0
    for k in pairs(AA.db.ignored or {}) do
      if string.lower(k) == a or string.lower(string.gsub(k, "%-.*$", "")) == a then
        AA.db.ignored[k] = nil
        n = n + 1
      end
    end
    AA.Print("no longer ignoring " .. n .. " character(s).")
  elseif cmd == "style" then
    local a = string.lower(arg or "")
    if a == "blizz" or a == "blizzard" then AA.db.style = "blizz"
    elseif a == "pfui" then AA.db.style = "pfui"
    elseif a == "auto" then AA.db.style = nil
    else
      AA.Print("window style: " .. (AA.db.style or "auto") .. "  -  use /ade style auto | blizz | pfui")
      return
    end
    AA.ApplyStyle()
    if AA.UpdateStyleBtn then AA.UpdateStyleBtn() end
    AA.Print("window style: " .. (AA.db.style or "auto") .. (AA.UsePf() and " (pfUI look)" or " (Blizzard look)"))
  elseif cmd == "chat" then
    AA.db.chat = not AA.db.chat
    AA.Print("guild / party / raid sync " .. (AA.db.chat and "|cff40ff40ON|r (cooldowns are sent to and accepted from guild / party / raid)" or "|cffff6060OFF|r (default; nothing is sent or accepted from chat)") .. ".")
  else
    AA.Print("/ade - alts window | cd (cooldowns) | find <item> | list | sync | scan | status | debug | bags | chat | unignore <name> | export | import | minimap | alert | reset | del <name>")
  end
end

