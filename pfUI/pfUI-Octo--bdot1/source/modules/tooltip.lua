pfUI:RegisterModule("tooltip", "vanilla:tbc", function ()
  local rawborder, default_border = GetBorderSize()

  pfUI.tooltip = CreateFrame('Frame', "pfTooltip", GameTooltip)
  pfUI.tooltip.anchorframe = CreateFrame('Frame', "pfTooltipAnchor", UIParent)
  pfUI.tooltip.anchorframe:SetWidth(128)
  pfUI.tooltip.anchorframe:SetHeight(72)
  pfUI.tooltip.anchorframe:SetPoint("TOP", UIParent, "TOP", 0, -50)
  pfUI.tooltip.anchorframe:Hide()
  -- octo (25 Oct 2026, user: "when resizing the tooltip the tooltip ingame
  -- should get bigger or smaller as well"): the anchor box's size in layout
  -- mode is the size of the game's tooltips
  local function TipScale(scale)
    scale = tonumber(scale) or 1
    for _, n in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
      local t = _G[n]
      if t and t.SetScale then t:SetScale(scale) end
    end
  end
  pfUI.tooltip.TipScale = TipScale
  -- (every way the box is sized - the wheel, a reset, a UI layout - goes through SetScale)
  local setScale = pfUI.tooltip.anchorframe.SetScale
  pfUI.tooltip.anchorframe.SetScale = function(self, scale)
    setScale(self, scale)
    TipScale(scale)
  end
  UpdateMovable(pfUI.tooltip.anchorframe)
  TipScale(pfUI.tooltip.anchorframe:GetScale())

  function pfUI.tooltip:GetAnchorPoint()
    local prefix = "TOP"
    local suffix = "RIGHT"
    local px, py = UIParent:GetCenter()
    local tx, ty = this.anchorframe:GetCenter()
    if (tx < px) then
      suffix = "LEFT"
    end
    if (ty < py) then
      prefix = "BOTTOM"
    end
    return prefix..suffix
  end

  if C.tooltip.position == "cursor" then
    function _G.GameTooltip_SetDefaultAnchor(tooltip, parent)
      tooltip:SetOwner(parent, "ANCHOR_CURSOR")
      if C.tooltip.cursoralign ~= "native" then
        -- create mouse follow frame
        if not tooltip.cursor then
          tooltip.cursor = CreateFrame("Frame", nil, UIParent)
          tooltip.cursor:SetWidth(tonumber(C.tooltip.cursoroffset) * 2)
          tooltip.cursor:SetHeight(tonumber(C.tooltip.cursoroffset) * 2)
          tooltip.cursor:SetScript("OnUpdate", function()
            local scale = UIParent:GetScale()
            local x, y = GetCursorPosition()
            this:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/scale, y/scale)
            if C.tooltip.cursoralign == "top" then
              tooltip.cursor:SetWidth(tooltip:GetWidth())
            end
          end)
        end

        -- adjust tooltip to mouse frame
        if C.tooltip.cursoralign == "top" then
          tooltip:SetPoint("BOTTOMLEFT", tooltip.cursor, "TOPLEFT", 0, 0)
        elseif C.tooltip.cursoralign == "left" then
          tooltip:SetPoint("BOTTOMRIGHT", tooltip.cursor, "LEFT", 0, 0)
        elseif C.tooltip.cursoralign == "right" then
          tooltip:SetPoint("BOTTOMLEFT", tooltip.cursor, "RIGHT", 0, 0)
        end
      end
    end
  end

  local units = { "mouseover", "player", "pet", "target", "party", "partypet", "raid", "raidpet" }
  function pfUI.tooltip:GetUnit()
    pfUI.tooltip.unit = "none"

    for i, unit in pairs(units) do
      if unit == "party" or unit == "partypet" then
        for i=1,4 do
          if UnitExists(unit .. i) and ( UnitName(unit .. i) == GameTooltipTextLeft1:GetText() or UnitPVPName(unit .. i) == GameTooltipTextLeft1:GetText() ) then
            pfUI.tooltip.unit = unit .. i
            return pfUI.tooltip.unit
          end
        end
      elseif unit == "raid" or unit == "raidpet" then
        for i=1,40 do
          if UnitExists(unit .. i) and ( UnitName(unit .. i) == GameTooltipTextLeft1:GetText() or UnitPVPName(unit .. i) == GameTooltipTextLeft1:GetText() ) then
            pfUI.tooltip.unit = unit .. i
            return pfUI.tooltip.unit
          end
        end
      else
        if UnitExists(unit) and ( UnitName(unit) == GameTooltipTextLeft1:GetText() or UnitPVPName(unit) == GameTooltipTextLeft1:GetText() ) then
          pfUI.tooltip.unit = unit
          return pfUI.tooltip.unit
        end
      end
    end
    return pfUI.tooltip.unit
  end

  pfUI.tooltip.dodge = {
    "pfPanelRight", "pfChatRight"
  }

  if C.appearance.bags.movable == "0" then
    table.insert(pfUI.tooltip.dodge, "pfBag")
  end

  pfUI.tooltip:SetAllPoints()
  pfUI.tooltip:SetScript("OnShow", function()
      pfUI.tooltip:Update()
      if GameTooltip:GetAnchorType() == "ANCHOR_NONE" then
        GameTooltip:ClearAllPoints()
        if C.tooltip.position == "bottom" then
          if pfUI.panel and pfUI.panel.right:IsShown() then
            GameTooltip:SetPoint("BOTTOMRIGHT", pfUI.panel.right, "TOPRIGHT", 0, default_border*2)
          else
            GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
          end
        elseif C.tooltip.position == "chat" then
          local anchor = nil

          for _, frame in pairs(pfUI.tooltip.dodge) do
            if _G[frame] and _G[frame]:IsShown() then
              anchor = _G[frame]
            end
          end

          if anchor then
            GameTooltip:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, default_border*3)
          else
            GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -5, 5)
          end
        elseif C.tooltip.position == "free" then
          local point = this:GetAnchorPoint()
          if point then
            GameTooltip:SetPoint(point, this.anchorframe, point, 0, 0)
          end
        end
      end
    end)

  pfUI.tooltipStatusBar = CreateFrame('Frame', nil, GameTooltipStatusBar)
  pfUI.tooltipStatusBar:SetPoint("TOPLEFT", 0, 8)
  pfUI.tooltipStatusBar:SetPoint("TOPRIGHT", 0, 8)
  pfUI.tooltipStatusBar:SetHeight(12)
  pfUI.tooltipStatusBar:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  pfUI.tooltipStatusBar:SetScript("OnEvent", function()
    this.name = UnitName("mouseover")
    this.level = UnitLevel("mouseover")
  end)

  pfUI.tooltipStatusBar.text = CreateFrame("Frame", nil, pfUI.tooltipStatusBar)
  pfUI.tooltipStatusBar.text:SetFrameLevel(16)
  pfUI.tooltipStatusBar.text:SetAllPoints()

  pfUI.tooltipStatusBar.HP = pfUI.tooltipStatusBar.text:CreateFontString("Status", "OVERLAY", "GameFontNormal")
  pfUI.tooltipStatusBar.HP:SetAllPoints()
  pfUI.tooltipStatusBar.HP:SetNonSpaceWrap(false)
  pfUI.tooltipStatusBar.HP:SetFontObject(GameFontWhite)
  pfUI.tooltipStatusBar.HP:SetFont(C.tooltip.font_tooltip, C.tooltip.font_tooltip_size + 2, "OUTLINE")

  if GameTooltip.SetClampRectInsets then
    GameTooltip:SetClampRectInsets(0, 0, 16, 0)
  else
    GameTooltipStatusBar:SetClampedToScreen(true)
    pfUI.tooltipStatusBar:SetClampedToScreen(true)
  end

  pfUI.tooltipStatusBar:SetScript("OnUpdate", function()
    local hp = GameTooltipStatusBar:GetValue()
    local _, hpmax = GameTooltipStatusBar:GetMinMaxValues()
    -- the text again only when the health or the unit changed (it was every frame)
    if hp == this.lasthp and hpmax == this.lastmax and this.name == this.lastname and (this.retext or 0) > GetTime() then return end
    this.lasthp, this.lastmax, this.lastname, this.retext = hp, hpmax, this.name, GetTime() + .5
    local rhp, rhpmax, estimated

    if hpmax > 100 or (round(hpmax/100*hp) ~= hp) then
      rhp, rhpmax = hp, hpmax
    elseif pfUI.libhealth and pfUI.libhealth.enabled then
      rhp, rhpmax, estimated = pfUI.libhealth:GetUnitHealthByName(this.name, this.level, tonumber(hp), tonumber(hpmax))
    elseif MobHealthFrame then
      local index = (this.name or "") .. ":" .. (this.level or "")
      local ppp = MobHealth_PPP(index)
      if perc and ppp and ppp > 0 and not UnitIsUnit("mouseover", "pet") then
        rhp = round(hp * ppp)
        rhpmax = round(100 * ppp)
        estimated = true
      end
    end

    if C.tooltip.alwaysperc == "0" and ( estimated or hpmax > 100 or round(hpmax/100*hp) ~= hp ) then
      pfUI.tooltipStatusBar.HP:SetText(string.format("%s / %s", Abbreviate(rhp), Abbreviate(rhpmax)))
    elseif hpmax > 0 then
      pfUI.tooltipStatusBar.HP:SetText(string.format("%s%%", ceil(hp/hpmax*100)))
    else
      pfUI.tooltipStatusBar.HP:SetText("")
    end
  end)

  GameTooltipStatusBar:SetHeight(8)
  GameTooltipStatusBar:ClearAllPoints()
  GameTooltipStatusBar:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 0, default_border)
  GameTooltipStatusBar:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", 0, default_border)
  GameTooltipStatusBar:SetStatusBarTexture(pfUI.media[C.tooltip.statusbar.texture])
  CreateBackdrop(GameTooltipStatusBar, nil, nil, tonumber(C.tooltip.alpha))
  CreateBackdropShadow(GameTooltipStatusBar)

  GameTooltipStatusBar.SetStatusBarColor_orig = GameTooltipStatusBar.SetStatusBarColor
  GameTooltipStatusBar.SetStatusBarColor = function() return end

  function pfUI.tooltip:Update()
      local unit = pfUI.tooltip:GetUnit()
      if unit == "none" then
        -- process item tooltips
        if C.tooltip.itemid == "1" and libtooltip:GetItemID() then
          GameTooltip:AddLine(T["ItemID"] .. ": " .. libtooltip:GetItemID(), .25,.5,1)
          GameTooltip:Show()
        end

        return
      end

      local pvpname = UnitPVPName(unit)
      local name = UnitName(unit)
      local target = UnitName(unit .. "target")
      local _, targetClass = UnitClass(unit .. "target")
      local targetReaction = UnitReaction("player",unit .. "target")
      local _, class = UnitClass(unit)
      local guild, rankstr, rankid = GetGuildInfo(unit)
      local reaction = UnitReaction(unit, "player")
      local pvptitle = gsub(gsub(pvpname or name, name, "", 1), "^%s*(.-)%s*$", "%1")
      local hp = UnitHealth(unit)
      local hpm = UnitHealthMax(unit)

      if name then
        if UnitIsPlayer(unit) and class then
          local color = RAID_CLASS_COLORS[class]
          GameTooltipStatusBar:SetStatusBarColor_orig(color.r, color.g, color.b)
          GameTooltip:SetBackdropBorderColor(color.r, color.g, color.b)
          if color and color.r then
            GameTooltipTextLeft1:SetText(rgbhex(color.r, color.g, color.b, color.a) .. name)
          else
            GameTooltipTextLeft1:SetText("|cff999999" .. name)
          end
        elseif reaction then
          local color = UnitReactionColor[reaction]
          GameTooltipStatusBar:SetStatusBarColor_orig(color.r, color.g, color.b)
          GameTooltip:SetBackdropBorderColor(color.r, color.g, color.b)
        end
        if pvptitle ~= name and pvptitle ~= "" then
          GameTooltip:AppendText(" |cff666666["..pvptitle.."]|r")
        end
      end

      if guild then
        local rank = ""
        local lead = ""
        if C.tooltip.extguild == "1" then
          if rankstr then rank = " |cffaaaaaa(" .. rankstr .. ")"  end
          if rankid and rankid == 0 then lead = "|cffffcc00*|r" end
        end

        GameTooltip:AddLine("<" .. guild .. ">" .. lead .. rank, 0.3, 1, 0.5)
      end

      if target then
        if UnitIsPlayer(unit .. "target") and targetClass then
          local color = RAID_CLASS_COLORS[targetClass]
          GameTooltip:AddLine(target, color.r, color.g, color.b)
        elseif targetReaction then
          local color = UnitReactionColor[targetReaction]
          if color then
            GameTooltip:AddLine(target, color.r, color.g, color.b)
          else
            GameTooltip:AddLine(target, .5, .5, .5)
          end
        end
      end

      if hp and hpm then
        if hp >= 1000 then hp = round(hp / 1000, 1) .. "k" end
        if hpm >= 1000 then hpm = round(hpm / 1000, 1) .. "k" end
        pfUI.tooltipStatusBar.HP:SetText(hp .. " / " .. hpm)
      end
      GameTooltip:Show()
    end

  -- Octo: who cast a buff / debuff (and, with "Show Item IDs", its spell id) on
  -- every unit aura tooltip. ClassicAPI only knows casts it saw this session;
  -- without ClassicAPI nothing is added.
  if libclient then
    local function AddCaster(tip, unit, index, harmful)
      if C.tooltip.auracaster ~= "1" or not unit or not index or not libclient.HasClassicAPI() then return end
      local tex
      if harmful then tex = UnitDebuff(unit, index) else tex = UnitBuff(unit, index) end
      local name, _, _, caster, spellId = libclient.Aura(unit, index, harmful, tex)
      if not name then return end
      local added
      local who = caster and UnitExists(caster) and UnitName(caster)
      if who then
        local _, class = UnitClass(caster)
        local col = class and RAID_CLASS_COLORS[class]
        tip:AddLine(T["Cast by"] .. " " .. who, col and col.r or 1, col and col.g or .82, col and col.b or 0)
        added = true
      end
      if C.tooltip.itemid == "1" and spellId then
        tip:AddLine(T["Spell ID"] .. ": " .. spellId, .6, .6, .6)
        added = true
      end
      if added then tip:Show() end
    end

    for _, kind in pairs({ "SetUnitBuff", "SetUnitDebuff" }) do
      local orig = GameTooltip[kind]
      local harmful = kind == "SetUnitDebuff"
      if orig then
        GameTooltip[kind] = function(self, unit, index, a, b)
          local r = orig(self, unit, index, a, b)
          AddCaster(self, unit, index, harmful)
          return r
        end
      end
    end
  end

  -- octo: how many of an item you have, in bags / bank / worn (from the
  -- ClassicAPI pfUI fork's item count). ClassicAPI counts the bank even when it
  -- is shut; without it the bags and worn items are counted, the bank only
  -- while it is open.
  if C.tooltip.itemcount == "1" then
    local function Count(id)
      local bags, bank, worn = 0, 0, 0
      local pattern = "item:" .. id .. ":"
      local function In(bag)
        local n = 0
        for slot = 1, GetContainerNumSlots(bag) do
          local link = GetContainerItemLink(bag, slot)
          if link and string.find(link, pattern, 1, true) then
            local _, c = GetContainerItemInfo(bag, slot)
            n = n + (c or 1)
          end
        end
        return n
      end
      for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and string.find(link, pattern, 1, true) then worn = worn + 1 end
      end
      local total
      if C_Item and C_Item.GetItemCount then
        local ok, all = pcall(C_Item.GetItemCount, id, true)
        local ok2, carried = pcall(C_Item.GetItemCount, id, false)
        if ok and ok2 and all and carried then
          -- (ClassicAPI's carried count includes the worn ones)
          bags = math.max(0, carried - worn)
          bank = math.max(0, all - carried)
          total = all
        end
      end
      if not total then
        for bag = 0, 4 do bags = bags + In(bag) end
        if BankFrame and BankFrame:IsShown() then
          bank = In(-1)
          for bag = 5, 10 do bank = bank + In(bag) end
        end
        total = bags + bank + worn
      end
      return bags, bank, worn, total
    end

    local function AddCount(frame, id)
      if not id then return end
      local bags, bank, worn, total = Count(id)
      if total < 1 then return end
      frame:AddLine(" ")
      if bags > 0 then frame:AddDoubleLine(T["Bags"] .. ":", bags, .7, .7, .7, 1, 1, 1) end
      if bank > 0 then frame:AddDoubleLine(T["Bank"] .. ":", bank, .7, .7, .7, 1, 1, 1) end
      if worn > 0 then frame:AddDoubleLine(T["Equipped"] .. ":", worn, .7, .7, .7, 1, 1, 1) end
      local kinds = (bags > 0 and 1 or 0) + (bank > 0 and 1 or 0) + (worn > 0 and 1 or 0)
      if kinds > 1 then frame:AddDoubleLine(T["Total"] .. ":", total, .7, .7, .7, 1, 1, 1) end
      frame:Show()
    end

    local counter = CreateFrame("Frame", nil, GameTooltip)
    counter:SetScript("OnShow", function()
      if libtooltip and libtooltip:GetItemLink() then AddCount(GameTooltip, libtooltip:GetItemID()) end
    end)

    local HookSetItemRef = SetItemRef
    _G.SetItemRef = function(link, text, button)
      HookSetItemRef(link, text, button)
      local _, _, id = string.find(link or "", "item:(%d+)")
      if id and not IsShiftKeyDown() and not IsControlKeyDown() and ItemRefTooltip:IsShown() then
        AddCount(ItemRefTooltip, tonumber(id))
      end
    end
  end
end)
