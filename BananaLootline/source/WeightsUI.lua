------------------------------------------------------------------
-- BananaLootline - WeightsUI.lua
--
-- Seitenmenue "Statgewichte" links am Hauptfenster. Eine Lasche mit
-- Pfeil im linken Zwischenrand klappt es auf. Die Werte sind die
-- internen Gewichte (keine Umrechnung) und gelten pro Charakter.
------------------------------------------------------------------

local BLL = BananaLootline
BLL.WeightsUI = {}
local X = BLL.WeightsUI

local WIDTH = 300
local ROWS, ROW_H = 30, 18

-- Reihenfolge und Gruppen im Menue
X.GROUPS = {
  { key = "WT_G_PRIMARY", stats = { "STR", "AGI", "STA", "INT", "SPI" } },
  { key = "WT_G_ATTACK",  stats = { "AP", "RAP", "HIT", "CRIT", "WEAPON_DPS", "MELEE_DPS" } },
  { key = "WT_G_SPELL",   stats = { "SPELLPOWER", "HEALPOWER", "SPELLHIT", "SPELLCRIT", "MP5",
                                    "SPELLPOWER_ARCANE", "SPELLPOWER_FIRE", "SPELLPOWER_FROST",
                                    "SPELLPOWER_HOLY", "SPELLPOWER_NATURE", "SPELLPOWER_SHADOW" } },
  { key = "WT_G_DEFENSE", stats = { "ARMOR", "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE",
                                    "HEALTH", "HP5", "MANA" } },
  { key = "WT_G_RESIST",  stats = { "RES_FIRE", "RES_FROST", "RES_NATURE", "RES_SHADOW", "RES_ARCANE" } },
}

local function Class() return BLL.player and BLL.player.class end

-- Zahl kurz darstellen: 1.50 -> 1.5, 2.00 -> 2
function X:Format(v)
  if not v then return "" end
  local s = string.format("%.2f", v)
  s = string.gsub(s, "0+$", "")
  s = string.gsub(s, "%.$", "")
  return s
end

-- Gewichte der geltenden Spec ohne eigene Aenderungen
function X:Base()
  local W = BLL.Weights
  return W:BaseFor(Class(), (W:ActiveTab()))
end

-- Arbeitskopie laden: eigene Gewichte, sonst die der Spec. preset (Nummer
-- eines Talentbaums) laedt dessen Werte, gespeichert wird erst mit
-- "Uebernehmen".
function X:Load(preset)
  local W = BLL.Weights
  local src
  if preset then
    src = W:BaseFor(Class(), preset)
  else
    src = W:Custom() or self:Base()
  end
  self.work = {}
  for k, v in pairs(src) do self.work[k] = v end
  self.preset = preset
end

-- Unterscheidet sich die Arbeitskopie von den Spec-Gewichten?
function X:Differs(a, b)
  for k, v in pairs(a) do
    if v ~= 0 and (b[k] or 0) ~= v then return true end
  end
  for k, v in pairs(b) do
    if v ~= 0 and (a[k] or 0) ~= v then return true end
  end
  return false
end

function X:Apply()
  if not self.work then self:Load() end
  local W = BLL.Weights
  if self:Differs(self.work, self:Base()) then
    W:SetAll(self.work)
    BLL:Print(BLL.L["WT_SAVED"])
  else
    W:SetAll(nil)
    BLL:Print(BLL.L["WT_SAME"])
  end
  self:Rerun()
end

function X:Reset()
  BLL.Weights:Reset()
  self:Load()
  BLL:Print(BLL.L["WEIGHTS_RESET"])
  self:Rerun()
end

function X:Rerun()
  BLL.Weights:Get()
  if BLL.Candidates and BLL.Candidates.Run then
    BLL.Candidates:Run()
  elseif BLL.UI and BLL.UI.Refresh then
    BLL.UI:Refresh()
  end
  self:Refresh()
end

-- Zeilen fuer die Anzeige: Kopfzeile je Gruppe, dann die Stats
function X:Entries()
  local out = {}
  for _, g in ipairs(self.GROUPS) do
    table.insert(out, { head = g.key })
    for _, s in ipairs(g.stats) do table.insert(out, { stat = s }) end
  end
  return out
end

------------------------------------------------------------------
-- Oberflaeche
------------------------------------------------------------------

local function Label(stat)
  if BLL.UI and BLL.UI.StatLabel then return BLL.UI.StatLabel(stat) end
  return stat
end

function X:Init()
  local main = BananaLootlineFrame
  if self.panel or not main then return end
  local L = BLL.L

  -- Die Lasche sitzt im linken Zwischenrand zwischen Fensterkante und
  -- Slot-Spalte, senkrecht mittig zur Puppe.
  local doll = BLL.UI and BLL.UI.doll
  local tab = CreateFrame("Button", "BananaLootlineWeightsTab", main)
  tab:SetWidth(12); tab:SetHeight(56)
  if doll then
    tab:SetPoint("RIGHT", doll, "LEFT", -1, 0)
  else
    tab:SetPoint("LEFT", main, "LEFT", 3, 0)
  end
  tab:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  tab:SetBackdropColor(0.45, 0.05, 0.05, 1)
  tab:SetBackdropBorderColor(0.78, 0.63, 0.24, 1)
  tab:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  local arrow = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  arrow:SetPoint("CENTER", tab, "CENTER", 0, 0)
  tab.arrow = arrow
  tab:SetScript("OnClick", function() X:Toggle() end)
  tab:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(BLL.L["WT_TITLE"])
    GameTooltip:AddLine(BLL.L["WT_TIP"], 0.8, 0.8, 0.8, 1)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.tab = tab

  local p = CreateFrame("Frame", "BananaLootlineWeights", main)
  p:SetWidth(WIDTH); p:SetHeight(main:GetHeight() - 40)
  p:SetPoint("TOPRIGHT", main, "TOPLEFT", -2, -20)
  p:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  p:SetBackdropColor(0, 0, 0, 1)
  p:EnableMouse(true)
  p:Hide()

  local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -14)
  title:SetTextColor(1, 0.82, 0)
  title:SetText(L["WT_TITLE"])

  local sub = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetWidth(WIDTH - 28)
  sub:SetJustifyH("LEFT")
  p.sub = sub

  -- Vorlage: Werte eines Talentbaums der Klasse in die Felder laden
  local presetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  presetBtn:SetWidth(WIDTH - 28); presetBtn:SetHeight(20)
  presetBtn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -6)
  p.presetBtn = presetBtn
  local dd = CreateFrame("Frame", "BananaLootlineWeightsDD", p, "UIDropDownMenuTemplate")
  dd:Hide()
  dd.initialize = function()
    local W = BLL.Weights
    local specs = W.SPECS[Class() or ""] or {}
    local head = {}
    head.text = BLL.L["WT_PRESET"]; head.isTitle = 1; head.notCheckable = 1
    UIDropDownMenu_AddButton(head)
    for i = 1, 3 do
      if specs[i] then
        local info = {}
        info.text = W:SpecName(specs[i].name)
        info.value = i
        info.func = function()
          if CloseDropDownMenus then CloseDropDownMenus() end
          X:Load(this.value)
          X:Refresh()
        end
        UIDropDownMenu_AddButton(info)
      end
    end
  end
  presetBtn:SetScript("OnClick", function()
    pcall(ToggleDropDownMenu, 1, nil, dd, presetBtn, 0, 0)
  end)

  local top = -96
  p.rows = {}
  for i = 1, ROWS do
    local r = CreateFrame("Frame", nil, p)
    r:SetWidth(WIDTH - 24); r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", p, "TOPLEFT", 12, top - (i - 1) * ROW_H)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints(r)
    bg:SetVertexColor(0.25, 0.20, 0.06, 0.6)
    r.bg = bg
    local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", r, "LEFT", 4, 0)
    t:SetJustifyH("LEFT")
    r.text = t
    local base = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    base:SetPoint("RIGHT", r, "RIGHT", -64, 0)
    base:SetJustifyH("RIGHT")
    r.base = base
    local e = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
    e:SetWidth(46); e:SetHeight(16)
    e:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(6)
    e:SetScript("OnTextChanged", function()
      if X.filling or not this.stat or not X.work then return end
      local v = tonumber(this:GetText())
      X.work[this.stat] = (v and v ~= 0) and v or nil
      X:Mark(this:GetParent())
    end)
    e:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    e:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    e:SetScript("OnTabPressed", function() this:ClearFocus() end)
    r.edit = e
    r:Hide()
    p.rows[i] = r
  end
  p:EnableMouseWheel(true)
  p:SetScript("OnMouseWheel", function()
    X.offset = math.max(0, (X.offset or 0) - (arg1 or 0) * 3)
    X:Refresh()
  end)

  local apply = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  apply:SetWidth(120); apply:SetHeight(22)
  apply:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 14)
  apply:SetText(L["WT_APPLY"])
  apply:SetScript("OnClick", function() X:Apply() end)
  local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  reset:SetWidth(120); reset:SetHeight(22)
  reset:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -14, 14)
  reset:SetText(L["WT_RESET"])
  reset:SetScript("OnClick", function() X:Reset() end)

  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", apply, "TOPLEFT", 0, 6)
  hint:SetWidth(WIDTH - 28)
  hint:SetJustifyH("LEFT")
  hint:SetText(L["WT_HINT"])

  self.panel = p
  if BananaLootlineDB and BananaLootlineDB.weightsOpen then p:Show() end
  self:Refresh()
end

function X:Toggle()
  if not self.panel then return end
  if self.panel:IsVisible() then
    self.panel:Hide()
  else
    self:Load()
    self.panel:Show()
  end
  BananaLootlineDB.weightsOpen = self.panel:IsVisible() and true or nil
  self:Refresh()
end

-- Geaenderte Werte (gegenueber der Spec) orange
function X:Mark(r)
  local stat = r.edit.stat
  if not stat then return end
  local base = self.baseCache or self:Base()
  local v, b = self.work[stat] or 0, base[stat] or 0
  if v ~= b then
    r.edit:SetTextColor(1, 0.53, 0)
    r.base:SetText(b ~= 0 and ("(" .. self:Format(b) .. ")") or "(-)")
  else
    r.edit:SetTextColor(1, 1, 1)
    r.base:SetText("")
  end
end

function X:Refresh()
  if self.tab then
    self.tab.arrow:SetText((self.panel and self.panel:IsVisible()) and ">" or "<")
  end
  local p = self.panel
  if not p or not p:IsVisible() then return end
  if not self.work then self:Load() end
  local W, L = BLL.Weights, BLL.L
  W:Get()

  local specs = W.SPECS[Class() or ""] or {}
  local sub = (UnitClass and UnitClass("player") or (Class() or "?"))
    .. (W.activeSpec and (" - " .. W.activeSpec) or "")
  if W.customWeights then sub = sub .. "  |cffff8800(" .. L["CUSTOM_WEIGHTS"] .. ")|r" end
  p.sub:SetText(sub)
  local pname = self.preset and specs[self.preset] and W:SpecName(specs[self.preset].name)
  p.presetBtn:SetText(L["WT_PRESET"] .. ": " .. (pname or L["WT_PRESET_NONE"]))

  self.baseCache = self:Base()
  local list = self:Entries()
  local n = table.getn(list)
  self.offset = math.min(self.offset or 0, math.max(0, n - ROWS))
  self.filling = true
  for i = 1, ROWS do
    local r = p.rows[i]
    local e = list[i + self.offset]
    if not e then
      r:Hide()
    elseif e.head then
      r.text:SetText("|cffffcc00" .. L[e.head] .. "|r")
      r.bg:Show()
      r.base:SetText("")
      r.edit.stat = nil
      r.edit:ClearFocus()
      r.edit:Hide()
      r:Show()
    else
      r.text:SetText(Label(e.stat))
      r.bg:Hide()
      r.edit.stat = e.stat
      r.edit:SetText(self:Format(self.work[e.stat]))
      r.edit:Show()
      self:Mark(r)
      r:Show()
    end
  end
  self.filling = nil
end
