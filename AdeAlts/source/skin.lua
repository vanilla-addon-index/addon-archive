-- Ade Alts: skin (window backgrounds: pfUI look or classic Blizzard look)
local AA = AdeAlts

-- backgrounds: only these colours change with the opacity setting (never icons / text) -----
local skinned = {}    -- frames that follow the opacity setting
local allskins = {}   -- every skinned frame (the style can be switched at any time)

-- pfUI look when pfUI is installed (and not switched off in the settings), Blizzard look otherwise
function AA.UsePf()
  if AA.db and AA.db.style == "blizz" then return false end
  return (pfUI and pfUI.api and pfUI.api.CreateBackdrop) and true or false
end

function AA.ApplySkin(rec)
  local fr = rec.f
  rec.pf = false
  if AA.UsePf() then
    if not fr.backdrop then pcall(pfUI.api.CreateBackdrop, fr) end
    if fr.backdrop and fr.backdrop.GetBackdropColor then
      if not rec.pfeff then
        local r, g, b, a0 = fr.backdrop:GetBackdropColor()
        rec.pfr, rec.pfg, rec.pfb, rec.pfeff = r or 0, g or 0, b or 0, a0 or 0.85   -- pfUI's own alpha counts as 100 %
      end
      fr:SetBackdrop(nil)
      fr.backdrop:Show()
      rec.pf = true
      rec.r, rec.g, rec.b, rec.eff = rec.pfr, rec.pfg, rec.pfb, rec.pfeff
      return
    end
  end
  if fr.backdrop then fr.backdrop:Hide() end
  if rec.top then
    -- classic dialog window
    fr:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    rec.r, rec.g, rec.b = 1, 1, 1
  else
    -- classic tooltip-style panel
    fr:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    rec.r, rec.g, rec.b = 0, 0, 0
  end
  rec.eff = rec.base
end

-- a = background alpha, fixed = ignores the opacity setting, top = main window (dialog look)
function AA.SkinFrame(fr, a, fixed, top)
  local rec = { f = fr, base = a or 0.9, top = top }
  fr.adeSkin = rec
  table.insert(allskins, rec)
  if not fixed then table.insert(skinned, rec) end
  AA.ApplySkin(rec)
  AA.PaintSkin(rec, 1)
end

-- chosen background colour (settings), or nil for the default
function AA.BgColor()
  local c = AA.db and AA.db.bg
  if c then return c[1], c[2], c[3] end
end

function AA.PaintSkin(rec, o)
  local cr, cg, cb = AA.BgColor()
  local r, g, b = cr or rec.r, cg or rec.g, cb or rec.b
  local target = rec.pf and rec.f.backdrop or rec.f
  target:SetBackdropColor(r, g, b, rec.eff * o)
end

function AA.ApplyOpacity(o)
  for _, rec in ipairs(skinned) do AA.PaintSkin(rec, o) end
end

-- opacity of one skinned frame (cooldowns window)
function AA.SetSkinAlpha(fr, o)
  if fr.adeSkin then AA.PaintSkin(fr.adeSkin, o) end
end

-- re-skin every window (style setting changed)
function AA.ApplyStyle()
  for _, rec in ipairs(allskins) do AA.ApplySkin(rec) end
  AA.ApplyOpacity((AA.db and AA.db.alpha) or 1)
  if AA.f then AA.SetSkinAlpha(AA.f, (AA.db and AA.db.cdalpha) or 1) end
end

function AA.ItemTip(b)
  local ref = b.itemStr
  if not ref and b.itemId then ref = b.itemId .. ":0:0:0" end
  if not ref then return end
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. ref)
  if not ok or GameTooltip:NumLines() == 0 then
    GameTooltip:ClearLines()
    GameTooltip:AddLine(b.itemId and AA.ItemName(b.itemId) or ref)
  end
  GameTooltip:Show()
end

function AA.ScrollWheel(sf, step)
  local sb = getglobal(sf:GetName() .. "ScrollBar")
  if sb then sb:SetValue(sb:GetValue() - arg1 * step * 2) end
end

function AA.ResetScroll(sf)
  local sb = getglobal(sf:GetName() .. "ScrollBar")
  if sb then sb:SetValue(0) end
end

