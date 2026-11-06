local AB = AshenBuilds

---------------------------------------------------------------------------
-- Dropdowns. One shared list frame serves every dropdown; a full-screen
-- catcher behind it closes the list when you click anywhere else.
---------------------------------------------------------------------------
local LIST_ROWS, ROW_H = 16, 18
local list, catcher

local function CloseDropdown()
  if list then list:Hide(); list.owner = nil end
  if catcher then catcher:Hide() end
end
AB.CloseDropdown = CloseDropdown

local function RenderList()
  local owner = list.owner; if not owner then return end
  local items, opts = list.items, owner.opts
  local i, row, entry, c
  for i = 1, LIST_ROWS do
    row = list.rows[i]; entry = items[list.offset + i]
    if entry then
      row.value = entry.value
      row.text:SetText(entry.text)
      c = entry.color or {1, 1, 1}; row.text:SetTextColor(c[1], c[2], c[3])
      if opts.isChecked and opts.isChecked(entry.value) then row.check:Show() else row.check:Hide() end
      row:Show()
    else
      row.value = nil; row:Hide()
    end
  end
  local total = table.getn(items)
  if total > LIST_ROWS then
    list.more:SetText((list.offset + 1) .. "-" .. math.min(total, list.offset + LIST_ROWS) .. " of " .. total .. "  (scroll)")
    list.more:Show()
  else
    list.more:Hide()
  end
end

local function CreateList()
  catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetFrameStrata("FULLSCREEN"); catcher:SetAllPoints(UIParent); catcher:EnableMouse(true)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp"); catcher:SetScript("OnClick", CloseDropdown); catcher:Hide()

  list = CreateFrame("Frame", "AshenBuildsDropdownList", UIParent)
  list:SetFrameStrata("FULLSCREEN_DIALOG"); list:EnableMouse(true); list:EnableMouseWheel(true)
  AB:StylePanel(list, "panel"); list:SetBackdropColor(0.04, 0.03, 0.025, 0.98)
  list.rows = {}
  local i
  for i = 1, LIST_ROWS do
    local r = CreateFrame("Button", nil, list); r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 5, -5 - (i - 1) * ROW_H); r:SetPoint("RIGHT", list, "RIGHT", -5, 0)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.check:SetWidth(16); r.check:SetHeight(16); r.check:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", r, "LEFT", 20, 0); r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0); r.text:SetJustifyH("LEFT")
    r:SetScript("OnClick", function()
      local owner = list.owner; if not owner or this.value == nil then return end
      owner.opts.onSelect(this.value)
      owner:Refresh()
      if owner.opts.multi then RenderList() else CloseDropdown() end
    end)
    list.rows[i] = r
  end
  list.more = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); list.more:SetPoint("BOTTOM", list, "BOTTOM", 0, 5)
  list:SetScript("OnMouseWheel", function()
    local max = math.max(0, table.getn(list.items) - LIST_ROWS)
    list.offset = list.offset - arg1 * 3
    if list.offset < 0 then list.offset = 0 elseif list.offset > max then list.offset = max end
    RenderList()
  end)
  list:Hide()
end

function AB:OpenDropdown(owner)
  if not list then CreateList() end
  CloseDropdown()
  list.owner = owner; list.items = owner.opts.items() or {}; list.offset = 0
  local shown = math.min(table.getn(list.items), LIST_ROWS)
  local extra = table.getn(list.items) > LIST_ROWS and 16 or 0
  -- The list lives on UIParent, so match the owning window's scale.
  list:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
  list:SetWidth(math.max(owner:GetWidth(), owner.opts.listWidth or 0)); list:SetHeight(shown * ROW_H + 10 + extra)
  list:ClearAllPoints(); list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  RenderList()
  catcher:Show(); list:Show()
end

-- opts: items() -> {{value=,text=,color=},...}; getText() -> label; onSelect(value);
-- isChecked(value) -> bool; multi=true keeps the list open for several picks.
function AB:CreateDropdown(parent, width, opts)
  local b = CreateFrame("Button", nil, parent); b:SetWidth(width); b:SetHeight(24)
  self:StylePanel(b, "slot")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", b, "LEFT", 8, 0); b.text:SetPoint("RIGHT", b, "RIGHT", -22, 0); b.text:SetJustifyH("LEFT")
  b.arrow = b:CreateTexture(nil, "OVERLAY"); b.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  b.arrow:SetWidth(18); b.arrow:SetHeight(18); b.arrow:SetPoint("RIGHT", b, "RIGHT", -3, 0)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b.opts = opts
  b.Refresh = function(self) self.text:SetText(self.opts.getText()) end
  b:SetScript("OnClick", function() if list and list.owner == this and list:IsShown() then CloseDropdown() else AB:OpenDropdown(this) end end)
  b:Refresh()
  return b
end

-- Small caption above a control.
function AB:Caption(parent, text, anchor, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", x or 0, y or 3); fs:SetText(text)
  return fs
end

function AB:CreateCheck(parent, label, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate"); c:SetWidth(22); c:SetHeight(22)
  c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.label:SetPoint("LEFT", c, "RIGHT", 1, 1); c.label:SetText(label)
  c:SetScript("OnClick", function() onClick(this:GetChecked() and true or false) end)
  return c
end

---------------------------------------------------------------------------
-- Prompt / confirm dialog: AB:ShowPrompt{title=, text=, edit=bool, default=,
-- accept="OK", onAccept=function(text) end}
---------------------------------------------------------------------------
function AB:CreatePromptDialog()
  local f = CreateFrame("Frame", "AshenBuildsPromptDialog", UIParent); f:SetWidth(420); f:SetHeight(160); f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  AB:WindowBackdrop(f)
  self:SetupWindow(f); f:Hide(); self.promptDialog = f
  self:ApplyEmberBackground(f, 10, 0.5, 0.5, 0.5); self:AddEmberHeader(f, 34)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOP", f, "TOP", 0, -18)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.text:SetPoint("TOP", f, "TOP", 0, -56); f.text:SetWidth(370)
  local edit = CreateFrame("EditBox", "AshenBuildsPromptEdit", f, "InputBoxTemplate"); edit:SetWidth(340); edit:SetHeight(24); edit:SetPoint("TOP", f.text, "BOTTOM", 0, -8); edit:SetAutoFocus(false); edit:SetMaxLetters(60); f.edit = edit
  local accept = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); accept:SetWidth(100); accept:SetHeight(24); accept:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -5, 18); self:SkinButton(accept, "ember"); f.accept = accept
  local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); cancel:SetWidth(100); cancel:SetHeight(24); cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 5, 18); cancel:SetText("Cancel"); self:SkinButton(cancel, "ember")
  cancel:SetScript("OnClick", function() f:Hide() end)
  local function Accept() local cb = f.onAccept; local text = f.edit:GetText(); f:Hide(); if cb then cb(text) end end
  accept:SetScript("OnClick", Accept)
  edit:SetScript("OnEnterPressed", Accept)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
end

function AB:ShowPrompt(o)
  if not self.promptDialog then self:CreatePromptDialog() end
  local f = self.promptDialog
  f.title:SetText(o.title or ""); f.text:SetText(o.text or ""); f.accept:SetText(o.accept or "OK"); f.onAccept = o.onAccept
  f:Show()
  if o.edit then f.edit:Show(); f.edit:SetText(o.default or ""); f.edit:SetFocus(); f.edit:HighlightText() else f.edit:Hide() end
end
