-- Ade Alts: ui_config
local AA = AdeAlts


-- settings window ------------------------------------------------------
AA.ApplyConfig = function()
  if not AA.db then return end
  AA.M:SetScale(AA.db.scale or 1)
  AA.M:SetAlpha(1)
  AA.ApplyOpacity(AA.db.alpha or 1)
  AA.SetSkinAlpha(AA.f, AA.db.cdalpha or 1)
  if AA.UpdateSwatch then AA.UpdateSwatch() end
  AA.Layout()
end

local cfg = CreateFrame("Frame", "AdeAltsConfig", UIParent)
cfg:SetWidth(280)
cfg:SetHeight(444)
cfg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
cfg:SetFrameStrata("DIALOG")
cfg:SetMovable(true)
cfg:EnableMouse(true)
cfg:RegisterForDrag("LeftButton")
cfg:SetScript("OnDragStart", function() this:StartMoving() end)
cfg:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
cfg:Hide()
AA.SkinFrame(cfg, 0.97, true, true)
table.insert(UISpecialFrames, "AdeAltsConfig")

local ctitle = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ctitle:SetPoint("TOPLEFT", cfg, "TOPLEFT", 16, -14)
ctitle:SetText("Ade Alts settings")
local cclose = CreateFrame("Button", nil, cfg, "UIPanelCloseButton")
cclose:SetPoint("TOPRIGHT", cfg, "TOPRIGHT", -4, -4)

local sliders = {}
local function SliderLabel(sl, v)
  if sl.kind == "pct" then
    return sl.label .. ": " .. math.floor(v * 100 + 0.5) .. "%"
  end
  return sl.label .. ": " .. math.floor(v + 0.5) .. " px"
end

local function MakeSlider(name, y, lo, hi, step, field, label, kind, default)
  local sl = CreateFrame("Slider", name, cfg, "OptionsSliderTemplate")
  sl:SetWidth(240)
  sl:SetHeight(16)
  sl:SetPoint("TOP", cfg, "TOP", 0, y)
  sl:SetMinMaxValues(lo, hi)
  sl:SetValueStep(step)
  if kind == "pct" then
    getglobal(name .. "Low"):SetText(math.floor(lo * 100 + 0.5) .. "%")
    getglobal(name .. "High"):SetText(math.floor(hi * 100 + 0.5) .. "%")
  else
    getglobal(name .. "Low"):SetText(lo)
    getglobal(name .. "High"):SetText(hi)
  end
  sl.field, sl.label, sl.kind, sl.step, sl.default = field, label, kind, step, default
  sl:SetScript("OnValueChanged", function()
    local v = this:GetValue()
    if this.kind == "pct" then
      v = math.floor(v * 100 + 0.5) / 100
    else
      v = math.floor(v / this.step + 0.5) * this.step
    end
    getglobal(this:GetName() .. "Text"):SetText(SliderLabel(this, v))
    if cfg.loading or not AA.db then return end
    AA.db[this.field] = v
    AA.ApplyConfig()
  end)
  table.insert(sliders, sl)
  return sl
end

MakeSlider("AdeAltsScaleSlider", -56, 0.7, 1.5, 0.05, "scale", "Window scale", "pct", 1)
MakeSlider("AdeAltsAlphaSlider", -106, 0.1, 1.0, 0.05, "alpha", "Background opacity", "pct", 1)
MakeSlider("AdeAltsWidthSlider", -156, 640, 1500, 10, "width", "Window width", "px", AA.DEF_W)
MakeSlider("AdeAltsHeightSlider", -206, 420, 1000, 10, "height", "Window height", "px", AA.DEF_H)
MakeSlider("AdeAltsCdAlphaSlider", -256, 0.1, 1.0, 0.05, "cdalpha", "Cooldowns window opacity", "pct", 1)

-- background colour (standard colour picker) -------------------------------
local swlabel = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
swlabel:SetPoint("TOPLEFT", cfg, "TOPLEFT", 20, -304)
swlabel:SetText("Background color")
local swatch = CreateFrame("Button", nil, cfg)
swatch:SetWidth(36)
swatch:SetHeight(18)
swatch:SetPoint("TOPRIGHT", cfg, "TOPRIGHT", -20, -302)
swatch:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 10,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
swatch:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

AA.UpdateSwatch = function()
  local r, g, b = AA.BgColor()
  swatch:SetBackdropColor(r or 0, g or 0, b or 0, 1)
end

swatch:SetScript("OnClick", function()
  if not AA.db then return end
  local pr, pg, pb = AA.BgColor()
  pr, pg, pb = pr or 0, pg or 0, pb or 0
  local had = AA.db.bg
  ColorPickerFrame:Hide()
  ColorPickerFrame.hasOpacity = nil
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.func = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    AA.db.bg = { r, g, b }
    AA.ApplyConfig()
  end
  ColorPickerFrame.cancelFunc = function()
    AA.db.bg = had
    AA.ApplyConfig()
  end
  ColorPickerFrame.previousValues = { r = pr, g = pg, b = pb }
  ColorPickerFrame:SetColorRGB(pr, pg, pb)
  ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  ColorPickerFrame:Show()
end)

-- window style: Auto (pfUI when installed) / Blizzard / pfUI
local stylabel = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
stylabel:SetPoint("TOPLEFT", cfg, "TOPLEFT", 20, -344)
stylabel:SetText("Window style")
local stybtn = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
stybtn:SetWidth(100)
stybtn:SetHeight(22)
stybtn:SetPoint("TOPRIGHT", cfg, "TOPRIGHT", -20, -340)
local stynote = cfg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
stynote:SetPoint("TOPLEFT", cfg, "TOPLEFT", 20, -368)
stynote:SetWidth(240)
stynote:SetJustifyH("LEFT")
stynote:SetText("Auto: pfUI look if pfUI is installed, classic Blizzard look otherwise.")

AA.UpdateStyleBtn = function()
  local st = AA.db and AA.db.style
  stybtn:SetText((st == "blizz" and "Blizzard") or (st == "pfui" and "pfUI") or "Auto")
end
stybtn:SetScript("OnClick", function()
  if not AA.db then return end
  local st = AA.db.style
  if st == nil then AA.db.style = "blizz" elseif st == "blizz" then AA.db.style = "pfui" else AA.db.style = nil end
  AA.ApplyStyle()
  AA.UpdateStyleBtn()
end)

local function LoadConfigUI()
  AA.UpdateSwatch()
  AA.UpdateStyleBtn()
  cfg.loading = true
  for _, sl in ipairs(sliders) do
    local v = (AA.db and AA.db[sl.field]) or sl.default
    sl:SetValue(v)
    getglobal(sl:GetName() .. "Text"):SetText(SliderLabel(sl, v))
  end
  cfg.loading = false
end
cfg:SetScript("OnShow", LoadConfigUI)

local creset = CreateFrame("Button", nil, cfg, "UIPanelButtonTemplate")
creset:SetWidth(90)
creset:SetHeight(22)
creset:SetPoint("BOTTOM", cfg, "BOTTOM", 0, 16)
creset:SetText("Reset")
creset:SetScript("OnClick", function()
  for _, sl in ipairs(sliders) do AA.db[sl.field] = sl.default end
  AA.db.bg = nil
  AA.db.style = nil
  AA.ApplyStyle()
  AA.ApplyConfig()
  LoadConfigUI()
end)

local setbtn = CreateFrame("Button", nil, AA.M, "UIPanelButtonTemplate")
setbtn:SetWidth(80)
setbtn:SetHeight(20)
setbtn:SetPoint("RIGHT", AA.cdbtn, "LEFT", -6, 0)
setbtn:SetText("Settings")
setbtn:SetScript("OnClick", function()
  if cfg:IsVisible() then cfg:Hide() else cfg:Show() end
end)

AA.ToggleManager = function()
  if AA.M:IsVisible() then AA.M:Hide() else AA.M:Show() end
end


