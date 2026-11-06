local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")
local _G = getfenv(0)

sepgp_standings = sepgp:NewModule("sepgp_standings", "AceDB-2.0")
local groupings = {
  "sepgp_groupbyclass",
  "sepgp_groupbyarmor",
  "sepgp_groupbyrole",
}
-- Column sorting state
local sort_column = "pr"  -- default sort by PR
local sort_direction = "desc"  -- default descending
local PLATE, MAIL, LEATHER, CLOTH = 4,3,2,1
local DPS, CASTER, HEALER, TANK = 4,3,2,1
local class_to_armor = {
  PALADIN = PLATE,
  WARRIOR = PLATE,
  HUNTER = MAIL,
  SHAMAN = MAIL,
  DRUID = LEATHER,
  ROGUE = LEATHER,
  MAGE = CLOTH,
  PRIEST = CLOTH,
  WARLOCK = CLOTH,
}
local armor_text = {
  [CLOTH] = L["CLOTH"],
  [LEATHER] = L["LEATHER"],
  [MAIL] = L["MAIL"],
  [PLATE] = L["PLATE"],
}
local class_to_role = {
  PALADIN = {HEALER,DPS,TANK,CASTER},
  PRIEST = {HEALER,CASTER},
  DRUID = {HEALER,TANK,DPS,CASTER},
  SHAMAN = {HEALER,DPS,CASTER},
  MAGE = {CASTER},
  WARLOCK = {CASTER},
  ROGUE = {DPS},
  HUNTER = {DPS},
  WARRIOR = {TANK,DPS},
}
local role_text = {
  [TANK] = L["TANK"],
  [HEALER] = L["HEALER"],
  [CASTER] = L["CASTER"],
  [DPS] = L["PHYS DPS"],
}
local shooty_export = CreateFrame("Frame", "shooty_exportframe", UIParent)
shooty_export:SetWidth(250)
shooty_export:SetHeight(150)
shooty_export:SetPoint('TOP', UIParent, 'TOP', 0,-80)
shooty_export:SetFrameStrata('DIALOG')
shooty_export:Hide()
shooty_export:SetBackdrop({
  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
  edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = {left = 5, right = 5, top = 5, bottom = 5}
  })
shooty_export:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
shooty_export:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
shooty_export.action = CreateFrame("Button","shooty_exportaction", shooty_export, "UIPanelButtonTemplate")
shooty_export.action:SetWidth(100)
shooty_export.action:SetHeight(22)
shooty_export.action:SetPoint("BOTTOM",0,-20)
shooty_export.action:SetText("Import")
shooty_export.action:Hide()
shooty_export.action:SetScript("OnClick",function() sepgp_standings.import() end)
shooty_export.title = shooty_export:CreateFontString(nil,"OVERLAY")
shooty_export.title:SetPoint("TOP",0,-5)
shooty_export.title:SetFont("Fonts\\ARIALN.TTF", 12)
shooty_export.title:SetWidth(200)
shooty_export.title:SetJustifyH("LEFT")
shooty_export.title:SetJustifyV("CENTER")
shooty_export.title:SetShadowOffset(1, -1)
shooty_export.edit = CreateFrame("EditBox", "shooty_exportedit", shooty_export)
shooty_export.edit:SetMultiLine(true)
shooty_export.edit:SetAutoFocus(true)
shooty_export.edit:EnableMouse(true)
shooty_export.edit:SetMaxLetters(0)
shooty_export.edit:SetHistoryLines(1)
shooty_export.edit:SetFont('Fonts\\ARIALN.ttf', 12, 'THINOUTLINE')
shooty_export.edit:SetWidth(290)
shooty_export.edit:SetHeight(190)
shooty_export.edit:SetScript("OnEscapePressed", function() 
    shooty_export.edit:SetText("")
    shooty_export:Hide() 
  end)
shooty_export.edit:SetScript("OnEditFocusGained", function()
  shooty_export.edit:HighlightText()
end)
shooty_export.edit:SetScript("OnCursorChanged", function() 
  shooty_export.edit:HighlightText()
end)
shooty_export.AddSelectText = function(txt)
  shooty_export.edit:SetText(txt)
  shooty_export.edit:HighlightText()
end
shooty_export.scroll = CreateFrame("ScrollFrame", "shooty_exportscroll", shooty_export, 'UIPanelScrollFrameTemplate')
shooty_export.scroll:SetPoint('TOPLEFT', shooty_export, 'TOPLEFT', 8, -30)
shooty_export.scroll:SetPoint('BOTTOMRIGHT', shooty_export, 'BOTTOMRIGHT', -30, 8)
shooty_export.scroll:SetScrollChild(shooty_export.edit)
sepgp:make_escable("shooty_exportframe","add")

function sepgp_standings:Export()
  shooty_export.action:Hide()
  shooty_export.title:SetText(C:Gold(L["Ctrl-C to copy. Esc to close."]))
  local t = {}
  for i = 1, GetNumGuildMembers(1) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local ep = (sepgp:get_ep_v3(name,officernote) or 0) 
    local gp = (sepgp:get_gp_v3(name,officernote) or sepgp.VARS.basegp) 
    if ep > 0 then
      table.insert(t,{name,ep,gp,ep/gp})
    end
  end 
  table.sort(t, function(a,b)
      return tonumber(a[4]) > tonumber(b[4])
    end)
  shooty_export:Show()
  local txt = "Name;EP;GP;PR\n"
  for i,val in ipairs(t) do
    txt = string.format("%s%s;%d;%d;%.4f\n",txt,val[1],val[2],val[3],val[4])
  end
  shooty_export.AddSelectText(txt)
end

function sepgp_standings:Import()
  if not IsGuildLeader() then return end
  shooty_export.action:Show()
  shooty_export.title:SetText(C:Red("Ctrl-V to paste data. Esc to close."))
  shooty_export.AddSelectText(L.IMPORT_WARNING)
  shooty_export:Show()
end

function sepgp_standings.import()
  if not IsGuildLeader() then return end
  local text = shooty_export.edit:GetText()
  local t = {}
  local found
  for line in string.gfind(text,"[^\r\n]+") do
    local name,ep,gp,pr = sepgp:strsplit(";",line)
    ep,gp,pr = tonumber(ep),tonumber(gp),tonumber(pr)
    if (name) and (ep) and (gp) and (pr) then
      t[name]={ep,gp}
      found = true
    end
  end
  if (found) then
    local count = 0
    shooty_export.edit:SetText("")
    for i=1,GetNumGuildMembers(1) do
      local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
      local name_epgp = t[name]
      if (name_epgp) then
        count = count + 1
        sepgp:update_epgp_v3(name_epgp[1],name_epgp[2],i,name,officernote)
        t[name]=nil
      end
    end
    sepgp:defaultPrint(string.format(L["Imported %d members."],count))
    local report = string.format(L["Imported %d members.\n"],count)
    report = string.format(L["%s\nFailed to import:"],report)
    for name,epgp in pairs(t) do
      report = string.format("%s%s {%s:%s}\n",report,name,t[1],t[2])
    end
    shooty_export.AddSelectText(report)
  end
end

local class_cache = setmetatable({},{__index = function(t,k)
  local class
  if BC:HasReverseTranslation(k) then
    class = string.upper(BC:GetReverseTranslation(k))
  else
    class = string.upper(k)
  end
  if (class) then
    rawset(t,k,class)
    return class
  end
  return k
end})
function sepgp_standings:getArmorClass(class)
  class = class_cache[class]
  return class_to_armor[class] or 0
end

function sepgp_standings:getRolesClass(roster)
  local roster_num = table.getn(roster)
  for i=1,roster_num do
    local player = roster[i]
    local name, lclass, armor_class, ep, gp, pr, rankName = unpack(player)
    local class = class_cache[lclass]
    local roles = class_to_role[class]
    if not (roles) then
      player[3]=0
    else
      for i,role in ipairs(roles) do
        if i==1 then
          player[3]=role
        else
          table.insert(roster,{player[1],player[2],role,player[4],player[5],player[6],player[7]})
        end
      end
    end
  end
  return roster
end 

function sepgp_standings:OnEnable()
  if not T:IsRegistered("sepgp_standings") then
    T:Register("sepgp_standings",
      "children", function()
        T:SetTitle(L["shootyepgp standings"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", "Sort by EP",
          "tooltipText", "Sort standings by EP.",
          "checked", sort_column == "ep",
          "func", function() sepgp_standings:SetColumnSort("ep") end
        )
        D:AddLine(
          "text", "Sort by GP",
          "tooltipText", "Sort standings by GP.",
          "checked", sort_column == "gp",
          "func", function() sepgp_standings:SetColumnSort("gp") end
        )
        D:AddLine(
          "text", "Sort by PR",
          "tooltipText", "Sort standings by PR.",
          "checked", sort_column == "pr",
          "func", function() sepgp_standings:SetColumnSort("pr") end
        )
        D:AddLine()
        D:AddLine(
          "text", L["Raid Only"],
          "tooltipText", L["Only show members in raid."],
          "checked", sepgp_raidonly,
          "func", function() sepgp_standings:ToggleRaidOnly() end
        )
        D:AddLine(
          "text", L["Group by class"],
          "tooltipText", L["Group members by class."],
          "checked", sepgp_groupbyclass,
          "func", function() sepgp_standings:ToggleGroupBy("sepgp_groupbyclass") end
        )
        D:AddLine(
          "text", L["Group by armor"],
          "tooltipText", L["Group members by armor."],
          "checked", sepgp_groupbyarmor,
          "func", function() sepgp_standings:ToggleGroupBy("sepgp_groupbyarmor") end
        )
        D:AddLine(
          "text", L["Group by roles"],
          "tooltipText", L["Group members by roles."],
          "checked", sepgp_groupbyrole,
          "func", function() sepgp_standings:ToggleGroupBy("sepgp_groupbyrole") end
        )
        D:AddLine()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_standings:Refresh() end
        )
        D:AddLine(
          "text", L["Export"],
          "tooltipText", L["Export standings to csv."],
          "func", function() sepgp_standings:Export() end
        )
        if IsGuildLeader() then
          D:AddLine(
          "text", L["Import"],
          "tooltipText", L["Import standings from csv."],
          "func", function() sepgp_standings:Import() end
        )
        end
      end
    )
  end
  if not T:IsAttached("sepgp_standings") then
    T:Open("sepgp_standings")
  end
end

function sepgp_standings:OnDisable()
  T:Close("sepgp_standings")
end

function sepgp_standings:Refresh()
  T:Refresh("sepgp_standings")
end

function sepgp_standings:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_standings" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_standings") then
            T:Attach("sepgp_standings")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_standings:Top()
  if T:IsRegistered("sepgp_standings") and (T.registry.sepgp_standings.tooltip) then
    T.registry.sepgp_standings.tooltip.scroll=0
  end  
end

function sepgp_standings:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_standings") then
    T:Detach("sepgp_standings")
    if (T:IsLocked("sepgp_standings")) then
      T:ToggleLocked("sepgp_standings")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_standings:Refresh()
    else
      T:Attach("sepgp_standings")
    end
  end  
end

function sepgp_standings:ToggleGroupBy(setting)
  for _,value in ipairs(groupings) do
    if value ~= setting then
      _G[value] = false
    end
  end
  _G[setting] = not _G[setting]
  self:Top()
  self:Refresh()
end

function sepgp_standings:ToggleRaidOnly()
  sepgp_raidonly = not sepgp_raidonly
  self:Top()
  sepgp:SetRefresh(true)
end

local pr_sorter_standings = function(a,b)
  if sepgp_minep > 0 then
    local a_over = a[4]-sepgp_minep >= 0
    local b_over = b[4]-sepgp_minep >= 0
    if a_over and b_over or (not a_over and not b_over) then
      if a[6] ~= b[6] then
        return tonumber(a[6]) > tonumber(b[6])
      else
        return tonumber(a[4]) > tonumber(b[4])
      end
    elseif a_over and (not b_over) then
      return true
    elseif b_over and (not a_over) then
      return false
    end
  else
    if a[6] ~= b[6] then
      return tonumber(a[6]) > tonumber(b[6])
    else
      return tonumber(a[4]) > tonumber(b[4])
    end
  end
end

-- Column sorting functions
local function sort_by_ep(a, b)
  if sort_direction == "desc" then
    return tonumber(a[4]) > tonumber(b[4])
  else
    return tonumber(a[4]) < tonumber(b[4])
  end
end

local function sort_by_gp(a, b)
  if sort_direction == "desc" then
    return tonumber(a[5]) > tonumber(b[5])
  else
    return tonumber(a[5]) < tonumber(b[5])
  end
end

local function sort_by_pr(a, b)
  if sort_direction == "desc" then
    return tonumber(a[6]) > tonumber(b[6])
  else
    return tonumber(a[6]) < tonumber(b[6])
  end
end

-- Toggle column sort
function sepgp_standings:SetColumnSort(column)
  if sort_column == column then
    -- Toggle direction if clicking same column
    if sort_direction == "desc" then
      sort_direction = "asc"
    else
      sort_direction = "desc"
    end
  else
    -- New column, default to descending
    sort_column = column
    sort_direction = "desc"
  end
  self:Top()
  self:Refresh()
end

-- Sort functions for Tablet callbacks
function sepgp_standings:SortByEP()
  self:SetColumnSort("ep")
end

function sepgp_standings:SortByGP()
  self:SetColumnSort("gp")
end

function sepgp_standings:SortByPR()
  self:SetColumnSort("pr")
end

function sepgp_standings:BuildStandingsTable()
  local t = { }
  local r = { }
  if (sepgp_raidonly) and GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers(true) do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i) 
      r[name] = true
    end
  end
  sepgp.alts = {}
  for i = 1, GetNumGuildMembers(1) do
    local name, rankName, rankIndex, level, class, zone, note, officernote, connected, status = GetGuildRosterInfo(i)
    local ep = (sepgp:get_ep_v3(name,officernote) or 0) 
    local gp = (sepgp:get_gp_v3(name,officernote) or sepgp.VARS.basegp)
    local main, main_class, main_rank = sepgp:parseAlt(name,officernote)
    if (main) then
      if ((self._playerName) and (name == self._playerName)) then
        if (not sepgp_main) or (sepgp_main and sepgp_main ~= main) then
          sepgp_main = main
          self:defaultPrint(L["Your main has been set to %s"],sepgp_main)
        end
      end
      main = C:Colorize(BC:GetHexColor(main_class), main)
      sepgp.alts[main] = sepgp.alts[main] or {}
      sepgp.alts[main][name] = class
    end
    local armor_class = self:getArmorClass(class)
    if ep > 0 then
      if (sepgp_raidonly) and next(r) then
        if r[name] then
          table.insert(t,{name,class,armor_class,ep,gp,ep/gp,rankName})
        end
      else
        table.insert(t,{name,class,armor_class,ep,gp,ep/gp,rankName})
      end
    end
  end
  -- Determine which sort function to use based on selected column
  local sort_func
  if sort_column == "ep" then
    sort_func = sort_by_ep
  elseif sort_column == "gp" then
    sort_func = sort_by_gp
  elseif sort_column == "pr" then
    sort_func = sort_by_pr
  else
    sort_func = pr_sorter_standings
  end

  if (sepgp_groupbyclass) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] > b[2]
      else return sort_func(a,b) end
    end)
  elseif (sepgp_groupbyarmor) then
    table.sort(t, function(a,b)
      if (a[3] ~= b[3]) then return a[3] > b[3]
      else return sort_func(a,b) end
    end)
  elseif (sepgp_groupbyrole) then
    t = self:getRolesClass(t)
    table.sort(t, function(a,b)
      if (a[3] ~= b[3]) then return a[3] > b[3]
      else return sort_func(a,b) end
    end)
  else
    table.sort(t, sort_func)
  end
  return t
end

function sepgp_standings:OnTooltipUpdate()
  -- Build column headers with sort indicators
  local ep_indicator = ""
  local gp_indicator = ""
  local pr_indicator = ""

  if sort_column == "ep" then
    if sort_direction == "desc" then
      ep_indicator = " \226\150\188"  -- down arrow
    else
      ep_indicator = " \226\150\178"  -- up arrow
    end
  end

  if sort_column == "gp" then
    if sort_direction == "desc" then
      gp_indicator = " \226\150\188"
    else
      gp_indicator = " \226\150\178"  -- up arrow
    end
  end

  if sort_column == "pr" then
    if sort_direction == "desc" then
      pr_indicator = " \226\150\188"
    else
      pr_indicator = " \226\150\178"  -- up arrow
    end
  end

  local cat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange(L["Name"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["ep"] .. ep_indicator),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange(L["gp"] .. gp_indicator),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange(L["pr"] .. pr_indicator),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  local separator
  for i = 1, table.getn(t) do
    local name, class, armor_class, ep, gp, pr, rankName = unpack(t[i])
    if (sepgp_groupbyarmor) or (sepgp_groupbyrole) then
      if not (separator) then
        if (sepgp_groupbyarmor) then
          separator = armor_text[armor_class]
        elseif (sepgp_groupbyrole) then
          separator = role_text[armor_class]
        end
        if (separator) then
          cat:AddLine(
            "text", C:Green(separator),
            "text2", "",
            "text3", "",
            "text4", ""
          )
        end
      else
        local last_separator = separator
        if (sepgp_groupbyarmor) then
          separator = armor_text[armor_class]
        elseif (sepgp_groupbyrole) then
          separator = role_text[armor_class]
        end
        if (separator) and (separator ~= last_separator) then
          cat:AddLine(
            "text", C:Green(separator),
            "text2", "",
            "text3", "",
            "text4", ""
          )          
        end
      end
    end
    local text = C:Colorize(BC:GetHexColor(class), name) .. " " .. C:Colorize("aaaaaa", "("..rankName..")")
    local text2, text4
    if sepgp_minep > 0 and ep < sepgp_minep then
      text2 = C:Red(string.format("%d", ep))
      text4 = C:Red(string.format("%.4f", pr))
    else
      text2 = string.format("%d", ep)
      text4 = string.format("%.4f", pr)
    end
    local text3 = string.format("%d", gp)
    if ((sepgp._playerName) and sepgp._playerName == name) or ((sepgp_main) and sepgp_main == name) then
      text = string.format("(*)%s",text)
      local pr_decay = sepgp:capcalc(ep,gp)
      if pr_decay < 0 then
        text4 = string.format("%s(|cffff0000%.4f|r)",text4,pr_decay)
      end
    end
    cat:AddLine(
      "text", text,
      "text2", text2,
      "text3", text3,
      "text4", text4
    )
  end
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
