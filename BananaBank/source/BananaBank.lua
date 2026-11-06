-- BananaBank Einstieg: Events und Befehle

local BB = BananaBank
local getn = table.getn
local started = false

-- Hello erst senden, wenn die Gildenliste da ist und den Bank-Rang zeigt
function BB:TryHello(n)
  if self:Ready() then
    self:SendHello()
  elseif n < 12 then
    self:RequestRoster()
    self:After(5, function() BB:TryHello(n + 1) end, "hello")
  end
end

-- Taschen oeffnen loest bei Bank-Chars eine Pruefung des Bestands aus (gesendet wird nur bei Aenderung)
function BB:HookBags()
  if self.bagsHooked then return end
  self.bagsHooked = true
  local names = { "ToggleBackpack", "ToggleBag", "OpenAllBags" }
  for i = 1, getn(names) do
    local name = names[i]
    local orig = getglobal(name)
    if type(orig) == "function" then
      setglobal(name, function(a, b, c)
        local r = orig(a, b, c)
        if BB:IsBank() and BB.worldReady then BB:ScheduleSnapshot(1) end
        return r
      end)
    end
  end
end

local ev = CreateFrame("Frame", "BananaBankEvents")
local EVENTS = {
  "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON",
  "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "UNIT_INVENTORY_CHANGED", "PLAYER_MONEY",
  "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED",
  "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE", "TRADE_TARGET_ITEM_CHANGED",
  "TRADE_PLAYER_ITEM_CHANGED", "TRADE_MONEY_CHANGED", "UI_INFO_MESSAGE",
  "AUCTION_ITEM_LIST_UPDATE", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_SHOW",
  "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
}
for i = 1, table.getn(EVENTS) do ev:RegisterEvent(EVENTS[i]) end

ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 ~= "BananaBank" then return end
    BB:InitDB()
    BB:ApplyLanguage()
    BB:HookMail()
    BB:HookBags()
    math.randomseed(time())

  elseif event == "PLAYER_ENTERING_WORLD" then
    if started then return end
    started = true
    BB.UI:Init()
    BB.UI:BuildMinimap()
    BB:Print(string.format(BB.T("MSG_LOADED"), BB.VERSION))
    BB:CheckModules()
    BB:RequestRoster()
    BB:After(6, function() BB:RequestRoster() end, "roster")
    BB:After(5, function() BB:QuestTick() end, "questbase")
    -- ab jetzt zaehlen Taschen-Ereignisse; einmal pruefen, ob sich seit dem Abmelden etwas geaendert hat
    BB:After(6, function()
      BB.worldReady = true
      BB:ScheduleSnapshot(1)
    end, "worldready")
    BB:After(12, function() BB:TryHello(1) end, "hello")

  elseif event == "CHAT_MSG_ADDON" then
    BB:OnAddonMessage(arg1, arg2, arg3, arg4)

  elseif event == "BANKFRAME_OPENED" then
    BB.bankOpen = true
    if BB:IsBank() then BB:ScheduleSnapshot(1) end
    BB.UI:Refresh()

  elseif event == "BANKFRAME_CLOSED" then
    -- Scan vor dem Schliessen-Flag, damit der Bankinhalt noch lesbar ist
    if BB:IsBank() and BB.bankOpen then BB:UpdateSnapshot(false) end
    BB.bankOpen = false
    if BB:IsBank() then BB:ScheduleSnapshot(1) end
    BB.UI:Refresh()

  elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED"
      or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") then
    -- Taschen anlegen oder tauschen aendert den Bestand ebenfalls (die Tasche im Einsatz zaehlt nicht mehr)
    -- auch bei geschlossener Bank: Post verschicken, Taschen oeffnen, Items abgeben ...
    if BB:IsBank() and BB.worldReady and not BB.job then BB:ScheduleSnapshot(3) end
    if BB.UI.page == "bank" then BB:After(0.5, function() BB.UI:Refresh() end, "bagrefresh") end

  elseif event == "PLAYER_MONEY" then
    if BB:IsBank() then
      local snap = BananaBankDB.snaps[BB:Me()]
      if snap then snap.gold = GetMoney() end
    end

  elseif event == "MAIL_SHOW" then
    BB.mailOpen = true
    -- neue Mitglieder kennen: Gildenliste beim Oeffnen des Postfachs auffrischen
    if BB:IsBank() then BB:RequestRoster() end
    if BB:IsBank() and GetInboxNumItems then
      local cnt = GetInboxNumItems()
      BB:MailLog("-", true, "", 0, 0, "open", tostring(cnt or 0))
    end
    BB.UI:Refresh()

  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
    if BB.ScanTradeSkills then BB:ScanTradeSkills() end

  elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
    if BB.ScanCrafts then BB:ScanCrafts() end

  elseif event == "MAIL_INBOX_UPDATE" then
    -- der Briefkasten hat sich geaendert: die naechste gleiche Entnahme ist ein neuer Brief, kein doppelter Aufruf
    BB.inboxSerial = (BB.inboxSerial or 0) + 1

  elseif event == "MAIL_CLOSED" then
    BB.mailOpen = false
    BB:Cancel("automail")
    BB.UI:Refresh()

  elseif event == "MAIL_SEND_SUCCESS" then
    BB:OnMailSent()
    if BB:IsBank() then BB:ScheduleSnapshot(2) end

  elseif event == "MAIL_FAILED" then
    BB:OnMailFailed()

  elseif event == "TRADE_SHOW" then
    BB:TradeShow()

  elseif event == "TRADE_ACCEPT_UPDATE" or event == "TRADE_TARGET_ITEM_CHANGED"
      or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
    BB:TradeCapture()

  elseif event == "UI_INFO_MESSAGE" then
    if arg1 == ERR_TRADE_COMPLETE and BB.trade then BB:TradeCommit() end

  elseif event == "TRADE_CLOSED" then
    BB:TradeClosed()

  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    BB:OnAuctionUpdate()

  elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
    BB:ReadRoster()
    BB.UI:Refresh()

  elseif event == "AUCTION_HOUSE_SHOW" then
    BB.ahOpen = true
    BB.UI:Refresh()

  elseif event == "AUCTION_HOUSE_CLOSED" then
    BB.ahOpen = false
    if BB.scan then BB:StopAHScan() end
  end
end)

-- ------------------------------------------------------------
-- Befehle
-- ------------------------------------------------------------
SLASH_BANANABANK1 = "/bb"
SLASH_BANANABANK2 = "/bananabank"
SlashCmdList["BANANABANK"] = function(msg)
  msg = msg or ""
  -- Rangnamen brauchen die Gross-/Kleinschreibung, deshalb rest im Original
  local _, _, rawCmd, rest = string.find(msg, "^(%S*)%s*(.-)$")
  local cmd = string.lower(rawCmd or "")
  rest = rest or ""
  local restLower = string.lower(rest)
  if cmd == "" or cmd == "show" then
    BB.UI:Toggle()
  elseif cmd == "anleitung" or cmd == "guide" or cmd == "tutorial" then
    BB.UI:Init()
    BB.UI:ToggleHelp()
  elseif cmd == "setbank" then
    BB:SetBank(true)
  elseif cmd == "removebank" then
    BB:SetBank(false)
  elseif cmd == "scan" then
    if BB:IsBank() then BB:UpdateSnapshot(true) else BB:Print(BB.T("ERR_NOT_BANK")) end
  elseif cmd == "quests" or cmd == "quest" then
    BB.UI:Init()
    BB.UI.frame:Show()
    BB.UI:ShowPage("quests")
  elseif cmd == "banks" or cmd == "banken" then
    if not BB:IsBank() then BB:Print(BB.T("ERR_NOT_BANK")) return end
    BB.UI:Init()
    BB.UI.frame:Show()
    BB.UI:ShowPage("banks")
  elseif cmd == "totals" or cmd == "summen" then
    BB.UI:OpenTotalsWindow("in")
  elseif cmd == "tracker" then
    BB.UI:ToggleQuestTracker()
  elseif cmd == "questlog" then
    BB:PrintQuestLog(rest)
  elseif cmd == "rights" or cmd == "rechte" then
    BB:PrintRights(rest)
  elseif cmd == "craft" then
    BB:PrintCraft(rest)
  elseif cmd == "items" or cmd == "load" then
    if BB.UI.PreloadStart then BB.UI:PreloadStart(true) end
  elseif cmd == "reissue" or cmd == "neu" then
    -- /bb reissue <Code> [Item] [Anzahl]
    local _, _, code, tail = string.find(rest or "", "^(%S+)%s*(.*)$")
    local r
    for c, req in pairs(BananaBankDB.reqs) do
      if code and string.lower(c) == string.lower(code) then r = req end
    end
    if not r then BB:Print("/bb reissue <Code> [Item] [Anzahl]") return end
    local item, num = tail, nil
    local _, _, it2, n2 = string.find(tail or "", "^(.-)%s+(%d+)$")
    if it2 then item, num = it2, tonumber(n2) end
    BB:Reissue(r, item, num)
  elseif cmd == "overview" or cmd == "uebersicht" then
    if BB.UI.OpenSendOverview then BB.UI:OpenSendOverview() end
  elseif cmd == "nocod" or cmd == "ohnenachnahme" then
    local r
    for c, req in pairs(BananaBankDB.reqs) do
      if string.lower(c) == string.lower(rest or "") then r = req end
    end
    if not r then BB:Print("/bb nocod <Code>") return end
    BB:SetNoCod(r)
  elseif cmd == "sent" or cmd == "versendet" then
    -- /bb sent <Code> [Anzahl]: Anfrage als versendet buchen; mit Anzahl (nur bei einem Item) gilt der Rest als nicht lieferbar
    local _, _, code, num = string.find(rest, "^(%S+)%s*(%d*)$")
    local r
    if code then
      for c, req in pairs(BananaBankDB.reqs) do
        if string.lower(c) == string.lower(code) then r = req end
      end
    end
    if not r then BB:Print("/bb sent <Code> [Anzahl]") return end
    if r.s ~= "confirmed" then BB:Print(string.format(BB.T("MSG_SENT_NEED_CONFIRMED"), r.id)) return end
    local amount = tonumber(num)
    if amount and BB.Count(r.items) ~= 1 then BB:Print(BB.T("MSG_SENT_ONE_ITEM")) return end
    BB:MarkSent(r, amount)
  elseif cmd == "reserved" or cmd == "reserviert" then
    BB:PrintReserved(rest)
  elseif cmd == "why" or cmd == "warum" then
    BB:PrintWhy(rest)
  elseif cmd == "maildebug" then
    local info = BB:MailDebugInfo()
    for i = 1, table.getn(info) do BB:Print(info[i]) end
  elseif cmd == "abgleich" or cmd == "reconcile" then
    local _, _, sub, who, nums = string.find(rest, "^(%S+)%s+(%S+)%s+(.+)$")
    if sub and (string.lower(sub) == "buchen" or string.lower(sub) == "book") then
      BB:ReconcileBook(who, nums)
    else
      BB:PrintReconcile(rest)
    end
  elseif cmd == "maillog" or cmd == "postlog" then
    BB:PrintMailLog(rest)
  elseif cmd == "ledger" or cmd == "buch" then
    BB:PrintLedger(rest)
  elseif cmd == "credit" then
    BB:CreditQuestDeliveries()
  elseif cmd == "book" then
    local _, _, player, cnt, item = string.find(rest, "^(%S+)%s+(%d+)%s+(.+)$")
    BB:ManualBook(player, cnt, item)
  elseif cmd == "stock" then
    BB:StockDebug(rest)
  elseif cmd == "find" then
    BB:FindItems(rest)
  elseif cmd == "status" then
    BB:Status()
  elseif cmd == "unhide" then
    BananaBankDB.hidden = {}
    BB:Print(BB.T("MSG_UNHIDDEN"))
    BB.UI:Refresh()
  elseif cmd == "ahscan" then
    BB:StartAHScan()
  elseif cmd == "prices" or cmd == "preise" then
    BB.UI:Init()
    BB.UI.frame:Show()
    BB.UI:ShowPage("prices")
  elseif cmd == "sync" then
    if not BB:Ready() then BB:Print("|cffff4040" .. string.format(BB.T("ERR_RANK_MISSING"), BB.BANK_RANK_LABEL) .. "|r") return end
    BB:SendHello()
    BB:Print(BB.T("MSG_SYNC"))
  elseif cmd == "lang" then
    if restLower == "de" then BB.UI:SetLanguage("deDE")
    elseif restLower == "en" then BB.UI:SetLanguage("enUS")
    else BB.UI:SetLanguage("auto") end
  elseif cmd == "minimap" then
    BananaBankDB.minimap.hide = not BananaBankDB.minimap.hide
    if BananaBankDB.minimap.hide then BB.UI.minimap:Hide() else BB.UI.minimap:Show() end
  elseif cmd == "debug" then
    BananaBankDB.debug = not BananaBankDB.debug
    BB:Print("Debug: " .. (BananaBankDB.debug and "an/on" or "aus/off"))
  elseif cmd == "gz" then
    if restLower == "test" or restLower == "test60" then
      if BB.UI.LevelTest then BB.UI:LevelTest(restLower == "test60") end
    elseif restLower == "status" then
      local held = BB.GuildHoldsGz and BB:GuildHoldsGz()
      if held then BB:Print(string.format(BB.T("LV_BLOCKED"), held))
      else BB:Print(BB.T(BB:GzOn() and "LV_STATUS_ON" or "LV_STATUS_OFF")) end
    elseif BB.SendGZ then
      BB:SendGZ(rest ~= "" and rest or nil)
    end
  elseif cmd == "support" or cmd == "spenden" then
    BB.UI:ShowThanks()
  else
    BB:Print(BB.T("HELP"))
  end
end
