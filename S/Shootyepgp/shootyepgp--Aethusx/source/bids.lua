local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_bids = sepgp:NewModule("sepgp_bids", "AceDB-2.0", "AceEvent-2.0")

function sepgp_bids:OnEnable()
  if not T:IsRegistered("sepgp_bids") then
    T:Register("sepgp_bids",
      "children", function()
        T:SetTitle(L["shootyepgp bids"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_bids:Refresh() end
        )
      end      
    )
  end
  if not T:IsAttached("sepgp_bids") then
    T:Open("sepgp_bids")
  end
end

function sepgp_bids:OnDisable()
  self:CancelAutoHide()
  T:Close("sepgp_bids")
end

function sepgp_bids:Refresh()
  T:Refresh("sepgp_bids")
end

function sepgp_bids:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_bids" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_bids") then
            sepgp_bids:CancelAutoHide()
            T:Attach("sepgp_bids")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_bids:Top()
  if T:IsRegistered("sepgp_bids") and (T.registry.sepgp_bids.tooltip) then
    T.registry.sepgp_bids.tooltip.scroll=0
  end  
end

function sepgp_bids:Close()
  self:CancelAutoHide()
  if not T:IsAttached("sepgp_bids") then
    T:Attach("sepgp_bids")
  end
end

function sepgp_bids:StartAutoHide(duration)
  self:CancelAutoHide()
  self._autoHideEndTime = GetTime() + duration
  self:ScheduleRepeatingEvent("shootyepgpBidAutoHideRefresh", function()
    if not T:IsAttached("sepgp_bids") then
      sepgp_bids:Refresh()
    end
  end, 1)
  sepgp:ScheduleEvent("shootyepgpBidAutoHide", function()
    sepgp_bids:CancelAutoHide()
    if not T:IsAttached("sepgp_bids") then
      T:Attach("sepgp_bids")
    end
  end, duration)
end

function sepgp_bids:CancelAutoHide()
  self._autoHideEndTime = nil
  sepgp:CancelScheduledEvent("shootyepgpBidAutoHide")
  self:CancelScheduledEvent("shootyepgpBidAutoHideRefresh")
end

function sepgp_bids:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_bids") then
    T:Detach("sepgp_bids") -- show
    if (T:IsLocked("sepgp_bids")) then
      T:ToggleLocked("sepgp_bids")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_bids:Refresh()
    else
      T:Attach("sepgp_bids") -- hide
    end
  end  
end

function sepgp_bids:announceWinnerMS(name, pr)
  sepgp:widestAudience(string.format(L["Winning Mainspec Bid: %s (%.03f PR)"],name,pr))
end

function sepgp_bids:announceWinnerOS(name, pr)
  sepgp:widestAudience(string.format(L["Winning Offspec Bid: %s (%.03f PR)"],name,pr))
end

function sepgp_bids:countdownCounter()
  self._counter = (self._counter or 6) - 1
  if GetNumRaidMembers()>0 and self._counter > 0 then
    self._counterText = C:Yellow(tostring(self._counter))
    sepgp:widestAudience(tostring(self._counter))
    --SendChatMessage(tostring(self._counter),"RAID")
    self:Refresh()
  end
end

function sepgp_bids:countdownFinish(reset)
  if self:IsEventScheduled("shootyepgpBidCountdown") then
    self:CancelScheduledEvent("shootyepgpBidCountdown")
  end
  self._counter = 6
  if (reset) then
    self._counterText = C:Green("Starting")
  else
    self._counterText = C:Red("Finished")
  end
  self:Refresh()
end

function sepgp_bids:bidCountdown()
  self:countdownFinish(true)
  self:ScheduleRepeatingEvent("shootyepgpBidCountdown",self.countdownCounter,1,self)
  self:ScheduleEvent("shootyepgpBidCountdownFinish",self.countdownFinish,6,self)
end

local pr_sorter_bids = function(a,b)
  if sepgp_minep > 0 then
    local a_over = a[3]-sepgp_minep >= 0
    local b_over = b[3]-sepgp_minep >= 0
    if a_over and b_over or (not a_over and not b_over) then
      if a[5] ~= b[5] then
        return tonumber(a[5]) > tonumber(b[5])
      else
        return tonumber(a[3]) > tonumber(b[3])
      end
    elseif a_over and (not b_over) then
      return true
    elseif b_over and (not a_over) then
      return false
    end
  else
    if a[5] ~= b[5] then
      return tonumber(a[5]) > tonumber(b[5])
    else
      return tonumber(a[3]) > tonumber(b[3])
    end
  end
end

function sepgp_bids:BuildBidsTable()
  -- {name,class,ep,gp,ep/gp[,main]}
  table.sort(sepgp.bids_main, pr_sorter_bids)
  table.sort(sepgp.bids_off, pr_sorter_bids)
  return sepgp.bids_main, sepgp.bids_off
end

function sepgp_bids:OnTooltipUpdate()
  if not (sepgp.bid_item and sepgp.bid_item.link) then return end
  local link = sepgp.bid_item.link
  local itemName = sepgp.bid_item.name
  local price = sepgp_prices:GetPrice(link,sepgp_progress)
  local offspec
  if not price then 
    price = "<n/a>"
    offspec = "<n/a>"
  else
    offspec = math.floor(price*sepgp_discount)
  end
  local bidcat = T:AddCategory(
      "columns", 3,    
      "text", C:Orange(L["Bid Item"]), "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["GP Cost"]),     "child_text2R", 50/255, "child_text2G", 205/255, "child_text2B", 50/255, "child_justify2", "RIGHT",
      "text3", C:Orange(L["OffSpec"]),  "child_text3R", 32/255, "child_text3G", 178/255, "child_text3B", 170/255, "child_justify3", "RIGHT",      
      "hideBlankLine", true
    )
  bidcat:AddLine(
      "text", itemName,
      "text2", price,
      "text3", offspec
    )
  if (IsRaidLeader() or sepgp:lootMaster()) then
    local countdownHeader = T:AddCategory(
        "columns", 2,
        "text","","child_textR",  1, "child_textG",  1, "child_textB",  1,"child_justify", "LEFT",
        "text2","","child_text2R",  1, "child_text2G",  1, "child_text2B",  1,"child_justify2", "CENTER",
        "hideBlankLine", true
      )
    countdownHeader:AddLine(
        "text", C:Green("Countdown"),
        "text2", self._counterText,
        "func", "bidCountdown", "arg1", self
      )
  end
  if self._autoHideEndTime then
    local remaining = math.max(0, math.ceil(self._autoHideEndTime - GetTime()))
    local autoHideCat = T:AddCategory(
        "columns", 2,
        "text","","child_textR",  1, "child_textG",  1, "child_textB",  1,"child_justify", "LEFT",
        "text2","","child_text2R",  1, "child_text2G",  1, "child_text2B",  1,"child_justify2", "CENTER",
        "hideBlankLine", true
      )
    autoHideCat:AddLine(
        "text", C:Silver(L["Auto-Hide Delay"]),
        "text2", string.format(L["|cff00ff00%02d|r|cffffffffsec|r"], remaining)
      )
  end
  local tm, to = self:BuildBidsTable()
  local msCount = table.getn(tm)
  local osCount = table.getn(to)
  local maincatHeader = T:AddCategory(
      "columns", 1,
      "text", string.format("%s %s", C:Gold("MAIN SPEC"), C:White("("..msCount..")"))
    ):AddLine("text","")
  local maincat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange(L["Name"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["ep"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange(L["gp"]),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange(L["pr"]),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange(L["Main"]),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT",
      "hideBlankLine", true
    )
  local is_leader = (IsRaidLeader() or sepgp:lootMaster())
  for i = 1, msCount do
    local name, class, ep, gp, pr, main = unpack(tm[i])
    local namedesc
    if (main) then
      namedesc = string.format("%s(%s)", C:Colorize(BC:GetHexColor(class), name), L["Alt"])
    else
      namedesc = C:Colorize(BC:GetHexColor(class), name)
    end
    local text2, text4
    if sepgp_minep > 0 and ep < sepgp_minep then
      text2 = C:Red(string.format("%d", ep))
      text4 = C:Red(string.format("%.4f", pr))
    else
      text2 = string.format("%d", ep)
      text4 = string.format("%.4f", pr)
    end
    if is_leader then
      maincat:AddLine(
        "text", namedesc,
        "text2", text2,
        "text3", string.format("%d", gp),
        "text4", text4,
        "text5", (main or ""),
        "func", "announceWinnerMS", "arg1", self, "arg2", name, "arg3", pr
      )
    else
      maincat:AddLine(
        "text", namedesc,
        "text2", text2,
        "text3", string.format("%d", gp),
        "text4", text4,
        "text5", (main or "")
      )
    end
  end
  if msCount == 0 then
    maincat:AddLine("text", C:Silver("--"))
  end
  local offcatHeader = T:AddCategory(
      "columns", 1,
      "text", string.format("%s %s", C:Silver("OFF SPEC"), C:White("("..osCount..")"))
    ):AddLine("text","")
  local offcat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange(L["Name"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["ep"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange(L["gp"]),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange(L["pr"]),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange(L["Main"]),     "child_text5R",   1, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT",
      "hideBlankLine", true
    )
  for i = 1, osCount do
    local name, class, ep, gp, pr, main = unpack(to[i])
    local namedesc
    if (main) then
      namedesc = string.format("%s(%s)", C:Colorize(BC:GetHexColor(class), name), L["Alt"])
    else
      namedesc = C:Colorize(BC:GetHexColor(class), name)
    end
    local text2, text4
    if sepgp_minep > 0 and ep < sepgp_minep then
      text2 = C:Red(string.format("%d", ep))
      text4 = C:Red(string.format("%.4f", pr))
    else
      text2 = string.format("%d", ep)
      text4 = string.format("%.4f", pr)
    end
    if is_leader then
      offcat:AddLine(
        "text", namedesc,
        "text2", text2,
        "text3", string.format("%d", gp),
        "text4", text4,
        "text5", (main or ""),
        "func", "announceWinnerOS", "arg1", self, "arg2", name, "arg3", pr
      )
    else
      offcat:AddLine(
        "text", namedesc,
        "text2", text2,
        "text3", string.format("%d", gp),
        "text4", text4,
        "text5", (main or "")
      )
    end
  end
  if osCount == 0 then
    offcat:AddLine("text", C:Silver("--"))
  end
  local closecat = T:AddCategory(
      "columns", 1,
      "text", "",
      "hideBlankLine", true
    )
  closecat:AddLine("text", "")
  closecat:AddLine(
      "text", C:Red("[ "..L["Close"].." ]"),
      "func", function()
        sepgp_bids:ScheduleEvent("shootyepgpBidsClose", sepgp_bids.Close, 0.05, sepgp_bids)
      end
    )
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted,sepgp_showbids
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
