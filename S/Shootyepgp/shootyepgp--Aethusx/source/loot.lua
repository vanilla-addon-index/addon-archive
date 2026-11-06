local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")
local L = AceLibrary("AceLocale-2.2"):new("shootyepgp")

sepgp_loot = sepgp:NewModule("sepgp_loot", "AceDB-2.0")

-- Discord ANSI escape codes
local ESC = "\027"
local RESET = ESC.."[0m"
local BOLD = ESC.."[1m"

local function stripColor(s)
  local _, _, plain = string.find(s or "", "|c%x%x%x%x%x%x%x%x(.+)|r")
  return plain or s or ""
end

local function pad(s, w)
  local diff = w - string.len(s)
  if diff > 0 then return s .. string.rep(" ", diff) end
  return s
end
local function rpad(s, w)
  local diff = w - string.len(s)
  if diff > 0 then return string.rep(" ", diff) .. s end
  return s
end
local function dashes(w) return string.rep("-", w) end

-- ANSI color tables for Discord export (built once at load time)
local actionAnsi = {
  [sepgp.VARS.msgp]                  = ESC.."[32m",  -- green
  [sepgp.VARS.osgp]                  = ESC.."[36m",  -- cyan
  [sepgp.VARS.bankde]                = ESC.."[33m",  -- yellow
  [stripColor(sepgp.VARS.reminder)]  = ESC.."[31m",  -- red
}
local qualityAnsi = {}
do
  local ansiForQuality = {
    [2] = ESC.."[32m",   -- Uncommon (green)
    [3] = ESC.."[36m",   -- Rare (cyan)
    [4] = ESC.."[34m",   -- Epic (blue)
    [5] = ESC.."[1;33m", -- Legendary (bright orange)
  }
  for q, ansi in pairs(ansiForQuality) do
    local c = ITEM_QUALITY_COLORS[q]
    if c and c.hex then
      local _, _, hex = string.find(c.hex, "|cff(%x%x%x%x%x%x)")
      if hex then qualityAnsi[string.lower(hex)] = ansi end
    end
  end
end

function sepgp_loot:OnEnable()
  if not T:IsRegistered("sepgp_loot") then
    T:Register("sepgp_loot",
      "children", function()
        T:SetTitle(L["shootyepgp loot info"])
        self:OnTooltipUpdate()
      end,
      "showTitleWhenDetached", true,
      "showHintWhenDetached", true,
      "cantAttach", true,
      "menu", function()
        D:AddLine(
          "text", L["Refresh"],
          "tooltipText", L["Refresh window"],
          "func", function() sepgp_loot:Refresh() end
        )
        D:AddLine(
          "text", L["Export CSV"],
          "tooltipText", L["Export loot to csv."],
          "func", function() sepgp_loot:ExportCSV() end
        )
        D:AddLine(
          "text", L["Export Discord"],
          "tooltipText", L["Export loot for Discord."],
          "func", function() sepgp_loot:ExportDiscord() end
        )
        D:AddLine(
          "text", L["Clear"],
          "tooltipText", L["Clear Loot."],
          "func", function() sepgp_looted = {} sepgp_loot:Refresh() end
        )
      end
    )
  end
  if not T:IsAttached("sepgp_loot") then
    T:Open("sepgp_loot")
  end
end

function sepgp_loot:OnDisable()
  T:Close("sepgp_loot")
end

function sepgp_loot:Refresh()
  T:Refresh("sepgp_loot")
end

function sepgp_loot:setHideScript()
  local i = 1
  local tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  while (tablet) and i<100 do
    if tablet.owner ~= nil and tablet.owner == "sepgp_loot" then
      sepgp:make_escable(string.format("Tablet20DetachedFrame%d",i),"add")
      tablet:SetScript("OnHide",nil)
      tablet:SetScript("OnHide",function()
          if not T:IsAttached("sepgp_loot") then
            T:Attach("sepgp_loot")
            this:SetScript("OnHide",nil)
          end
        end)
      break
    end    
    i = i+1
    tablet = getglobal(string.format("Tablet20DetachedFrame%d",i))
  end  
end

function sepgp_loot:Top()
  if T:IsRegistered("sepgp_loot") and (T.registry.sepgp_loot.tooltip) then
    T.registry.sepgp_loot.tooltip.scroll=0
  end  
end

function sepgp_loot:Toggle(forceShow)
  self:Top()
  if T:IsAttached("sepgp_loot") then
    T:Detach("sepgp_loot") -- show
    if (T:IsLocked("sepgp_loot")) then
      T:ToggleLocked("sepgp_loot")
    end
    self:setHideScript()
  else
    if (forceShow) then
      sepgp_loot:Refresh()
    else
      T:Attach("sepgp_loot") -- hide
    end
  end  
end

function sepgp_loot:BuildLootTable()
  table.sort(sepgp_looted, function(a,b)
    if (a[1] ~= b[1]) then return a[1] > b[1]
    else return a[2] > b[2] end
  end)
  return sepgp_looted
end

function sepgp_loot:ExportCSV()
  local export = getglobal("shooty_exportframe")
  if not export then return end
  export.action:Hide()
  export.hidePageButtons()
  export._readOnly = true
  export.title:SetText(C:Gold(L["Ctrl-C to copy. Esc to close."]))
  local t = self:BuildLootTable()
  local txt = "Time;Player;Item;Bind;GP;OffspecGP;Action\n"
  for i = 1, table.getn(t) do
    local timestamp, player, player_color, itemLink, bind, price, off_price, action = unpack(t[i])
    local plainPlayer = stripColor(player_color)
    local plainItem = itemLink or ""
    local _, _, itemName = string.find(itemLink or "", "|h%[(.+)%]|h")
    if itemName then plainItem = itemName end
    txt = string.format("%s%s;%s;%s;%s;%s;%s;%s\n",
      txt,
      timestamp or "",
      plainPlayer,
      plainItem,
      stripColor(bind),
      tostring(price or ""),
      tostring(off_price or ""),
      stripColor(action)
    )
  end
  export.AddSelectText(txt)
  export:Show()
end

function sepgp_loot:ExportDiscord()
  local export = getglobal("shooty_exportframe")
  if not export then return end
  export.action:Hide()
  export._readOnly = true
  local t = self:BuildLootTable()

  -- First pass: extract data and measure column widths
  local rows = {}
  local wPlayer, wItem, wGP, wAction = 6, 4, 2, 6
  for i = 1, table.getn(t) do
    local timestamp, player, player_color, itemLink, bind, price, off_price, action = unpack(t[i])
    local plainPlayer = stripColor(player_color)
    local plainItem = itemLink or ""
    local itemHex
    local _, _, ihex, iname = string.find(itemLink or "", "|cff(%x%x%x%x%x%x)|H.+|h(%[.+%])|h|r")
    if iname then
      plainItem = iname
      itemHex = string.lower(ihex)
    end
    local plainAction = stripColor(action)
    local gpStr = tostring(price or "")
    table.insert(rows, {plainPlayer, plainItem, gpStr, plainAction, itemHex})
    if string.len(plainPlayer) > wPlayer then wPlayer = string.len(plainPlayer) end
    if string.len(plainItem) > wItem then wItem = string.len(plainItem) end
    if string.len(gpStr) > wGP then wGP = string.len(gpStr) end
    if string.len(plainAction) > wAction then wAction = string.len(plainAction) end
  end

  -- Build row strings
  local headerLine = BOLD .. pad("Player", wPlayer) .. " | " .. pad("Item", wItem) .. " | " .. rpad("GP", wGP) .. " | " .. "Action" .. RESET .. "\n"
  local separatorLine = dashes(wPlayer) .. "-|-" .. dashes(wItem) .. "-|-" .. dashes(wGP) .. "-|-" .. dashes(wAction) .. "\n"
  local rowStrings = {}
  for i = 1, table.getn(rows) do
    local r = rows[i]
    local iAnsi = qualityAnsi[r[5] or ""]
    local aAnsi = actionAnsi[r[4]]
    table.insert(rowStrings, pad(r[1], wPlayer) .. " | " .. (iAnsi or "") .. pad(r[2], wItem) .. (iAnsi and RESET or "") .. " | " .. rpad(r[3], wGP) .. " | " .. (aAnsi or "") .. r[4] .. (aAnsi and RESET or "") .. "\n")
  end

  -- Split rows into pages that fit Discord's 2000 char limit
  local DISCORD_LIMIT = 2000
  local TITLE_MAX = string.len("**Loot Report (99/99)**\n")
  local CODEBLOCK_OPEN = string.len("```ansi\n")
  local CODEBLOCK_CLOSE = string.len("```")
  local pageOverhead = TITLE_MAX + CODEBLOCK_OPEN + string.len(headerLine) + string.len(separatorLine) + CODEBLOCK_CLOSE
  local pages = {}
  local currentPage = {}
  local currentLen = pageOverhead
  for i = 1, table.getn(rowStrings) do
    local lineLen = string.len(rowStrings[i])
    if currentLen + lineLen > DISCORD_LIMIT and table.getn(currentPage) > 0 then
      table.insert(pages, currentPage)
      currentPage = {}
      currentLen = pageOverhead
    end
    table.insert(currentPage, rowStrings[i])
    currentLen = currentLen + lineLen
  end
  if table.getn(currentPage) > 0 then
    table.insert(pages, currentPage)
  end

  -- Build page strings
  local totalPages = table.getn(pages)
  local pageStrings = {}
  for p = 1, totalPages do
    local title = "**Loot Report**\n"
    if totalPages > 1 then
      title = string.format("**Loot Report (%d/%d)**\n", p, totalPages)
    end
    local txt = title .. "```ansi\n" .. headerLine .. separatorLine
    for _, line in ipairs(pages[p]) do
      txt = txt .. line
    end
    txt = txt .. "```"
    table.insert(pageStrings, txt)
  end

  -- Create page navigation buttons once
  if not export._nextPage then
    local function showPage(pg)
      local total = table.getn(export._pages)
      if pg < 1 then pg = total end
      if pg > total then pg = 1 end
      export._currentPage = pg
      export.AddSelectText(export._pages[pg])
      export.title:SetText(C:Gold(string.format(L["Page %d/%d - Ctrl-C to copy. Esc to close."], pg, total)))
    end
    export._prevPage = CreateFrame("Button", "shooty_exportprevpage", export, "UIPanelButtonTemplate")
    export._prevPage:SetWidth(100)
    export._prevPage:SetHeight(22)
    export._prevPage:SetPoint("BOTTOMLEFT", 8, -20)
    export._prevPage:SetScript("OnClick", function()
      showPage((export._currentPage or 1) - 1)
    end)
    export._nextPage = CreateFrame("Button", "shooty_exportnextpage", export, "UIPanelButtonTemplate")
    export._nextPage:SetWidth(100)
    export._nextPage:SetHeight(22)
    export._nextPage:SetPoint("BOTTOMRIGHT", -8, -20)
    export._nextPage:SetScript("OnClick", function()
      showPage((export._currentPage or 1) + 1)
    end)
  end

  -- Show first page
  export._pages = pageStrings
  export._currentPage = 1
  export.AddSelectText(pageStrings[1])

  if totalPages > 1 then
    export.title:SetText(C:Gold(string.format(L["Page %d/%d - Ctrl-C to copy. Esc to close."], 1, totalPages)))
    export._prevPage:SetText(L["Prev Page"])
    export._prevPage:Show()
    export._nextPage:SetText(L["Next Page"])
    export._nextPage:Show()
  else
    export.title:SetText(C:Gold(L["Ctrl-C to copy. Esc to close."]))
    export._prevPage:Hide()
    export._nextPage:Hide()
  end

  export:Show()
end

function sepgp_loot:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 5,
      "text",  C:Orange(L["Time"]),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange(L["Item"]),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   0, "child_justify2", "LEFT",
      "text3", C:Orange(L["Binds"]),  "child_text3R",   0, "child_text3G",   1, "child_text3B",   0, "child_justify3", "CENTER",
      "text4", C:Orange(L["Looter"]),  "child_text4R",   0, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT",
      "text5", C:Orange(L["GP Action"]),  "child_text5R",   0, "child_text5G",   1, "child_text5B",   0, "child_justify5", "RIGHT"         
    )
  local t = self:BuildLootTable()
  for i = 1, table.getn(t) do
    local timestamp,player,player_color,itemLink,bind,price,off_price,action = unpack(t[i])
    cat:AddLine(
      "text", timestamp,
      "text2", itemLink,
      "text3", bind,
      "text4", player_color,
      "text5", action
    )
  end
end

-- GLOBALS: sepgp_saychannel,sepgp_groupbyclass,sepgp_groupbyarmor,sepgp_groupbyrole,sepgp_raidonly,sepgp_decay,sepgp_minep,sepgp_reservechannel,sepgp_main,sepgp_progress,sepgp_discount,sepgp_log,sepgp_dbver,sepgp_looted
-- GLOBALS: sepgp,sepgp_prices,sepgp_standings,sepgp_bids,sepgp_loot,sepgp_reserves,sepgp_alts,sepgp_logs
