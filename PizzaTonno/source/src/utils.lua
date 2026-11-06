local PT = PizzaTonno
PT.utils = {}

function PT.utils.strSplit(str, delimiter)
  if not str then return nil end
  local delimiter, fields = delimiter or ':', {}
  local pattern = string.format('([^%s]+)', delimiter)
  string.gsub(str, pattern, function (c) fields[table.getn(fields) + 1] = c end)
  return unpack(fields)
end

function PT.utils.itemId(link)
  if not link then return end
  local _, _, id = string.find(link, 'item:(%d+)')
  return tonumber(id)
end

function PT.utils.percent(p)
  if p > 0 and p < 0.001 then return '<0.1%' end
  return string.format('%.1f%%', p * 100)
end

-- The range the true rate behind k hits in n tries lies in, 95% of the time (Wilson score
-- interval: unlike the textbook one it stays sensible for rare fish and few catches).
function PT.utils.likelyRange(k, n)
  local z2 = 1.96 * 1.96
  local p = k / n
  local center = (p + z2 / (2 * n)) / (1 + z2 / n)
  local half = math.sqrt(z2 * p * (1 - p) / n + z2 * z2 / (4 * n * n)) / (1 + z2 / n)
  return math.max(center - half, 0), math.min(center + half, 1)
end

-- 12345 -> '12,345'
function PT.utils.count(n)
  local text = tostring(math.floor(n))
  local grouped
  repeat
    text, grouped = string.gsub(text, '^(%d+)(%d%d%d)', '%1,%2')
  until grouped == 0
  return text
end

-- '3d 4h', '2h 14m', '14m' or '<1m'
function PT.utils.duration(seconds)
  local minutes = math.floor(seconds / 60)
  if seconds > 0 and minutes == 0 then return '<1m' end
  local days, hours = math.floor(minutes / 1440), math.floor(math.mod(minutes, 1440) / 60)
  if days > 0 then return days .. 'd ' .. hours .. 'h' end
  if hours > 0 then return hours .. 'h ' .. math.mod(minutes, 60) .. 'm' end
  return minutes .. 'm'
end
