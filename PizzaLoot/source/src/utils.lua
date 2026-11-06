local PL = PizzaLoot
PL.utils = {}

local BASE_R, BASE_G, BASE_B = 0.04, 0.04, 0.06
local TINT = 0.22

local pixel

function PL.utils.strSplit(str, delimiter)
  if not str then return nil end
  local delimiter, fields = delimiter or ':', {}
  local pattern = string.format('([^%s]+)', delimiter)
  string.gsub(str, pattern, function(c) fields[table.getn(fields) + 1] = c end)
  return unpack(fields)
end

-- One physical screen pixel in UI units. The draw layer is always 768 units
-- tall whatever the UI scale, so that is what real pixels are measured against.
function PL.utils.pixel()
  if pixel then return pixel end

  local _, _, height = string.find(GetCVar('gxResolution') or '', 'x(%d+)')
  local scale = tonumber(GetCVar('uiScale'))
  if not height or not scale or scale <= 0 then return 1 end

  pixel = 768 / tonumber(height) / scale
  if pixel > 1 then pixel = 1 end
  return pixel
end

function PL.utils.snap(value)
  local p = PL.utils.pixel()
  return math.floor(value / p + 0.5) * p
end

function PL.utils.border(frame)
  local p = PL.utils.pixel()

  local function line(from, to)
    local texture = frame:CreateTexture(nil, 'BORDER')
    texture:SetTexture(0, 0, 0, 0.9)
    texture:SetPoint(from, frame, from, 0, 0)
    texture:SetPoint(to, frame, to, 0, 0)
    return texture
  end

  line('TOPLEFT', 'TOPRIGHT'):SetHeight(p)
  line('BOTTOMLEFT', 'BOTTOMRIGHT'):SetHeight(p)
  line('TOPLEFT', 'BOTTOMLEFT'):SetWidth(p)
  line('TOPRIGHT', 'BOTTOMRIGHT'):SetWidth(p)

  local highlight = frame:CreateTexture(nil, 'BORDER')
  highlight:SetTexture(1, 1, 1, 0.12)
  highlight:SetPoint('TOPLEFT', frame, 'TOPLEFT', p, -p)
  highlight:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -p, -p)
  highlight:SetHeight(p)
end

function PL.utils.tint(texture, accent)
  texture:SetTexture(1, 1, 1, 1)
  texture:SetGradientAlpha('HORIZONTAL',
    BASE_R + accent[1] * TINT, BASE_G + accent[2] * TINT, BASE_B + accent[3] * TINT, 0.92,
    BASE_R, BASE_G, BASE_B, 0.86)
end
