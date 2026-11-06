PizzaPocket = CreateFrame('Frame', 'PizzaPocket', UIParent)
local PP = PizzaPocket

PP.Colors = {
  primary   = '|cffa050ff',
  secondary = '|cffffffff',
  grey      = '|cffaaaaaa',
  red       = '|cffc41e3a',
  gold      = '|cffffd700',
  silver    = '|cffc7c7cf',
  copper    = '|cffeda55f',
}

PP.PICK_POCKET = 'Pick Pocket'

PP.picked = {}
PP.debug = false

PP.utils = {}

function PP:Print(msg, withPrefix)
  local prefix = withPrefix == false and '' or PP.Colors.primary .. 'Pizza' .. PP.Colors.secondary .. 'Pocket:|r '
  DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

function PP:PrintClean(msg)
  PP:Print(msg, false)
end

function PP:Debug(msg)
  if PP.debug then PP:Print(msg) end
end

function PP.utils.strSplit(str, delimiter)
  if not str then return nil end
  delimiter = delimiter or ':'
  local fields = {}
  local pattern = string.format('([^%s]+)', delimiter)
  string.gsub(str, pattern, function (c) fields[table.getn(fields) + 1] = c end)
  return unpack(fields)
end

function PP.utils.buildPattern(fmt)
  local p = string.gsub(fmt, '([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
  p = string.gsub(p, '%%%%s', '(.-)')
  p = string.gsub(p, '%%%%d', '(%%d+)')
  return '^' .. p .. '$'
end

function PP.utils.coins(copper)
  local c = PP.Colors
  local sign = copper < 0 and c.red .. '-|r' or ''
  copper = math.floor(math.abs(copper) + 0.5)
  local g = math.floor(copper / 10000)
  local s = math.floor(math.mod(copper, 10000) / 100)
  local cu = math.mod(copper, 100)
  if g > 0 then return sign .. c.gold .. g .. 'g|r ' .. c.silver .. s .. 's|r' end
  if s > 0 then return sign .. c.silver .. s .. 's|r ' .. c.copper .. cu .. 'c|r' end
  return sign .. c.copper .. cu .. 'c|r'
end

function PP.utils.guid(unit)
  if UnitGUID then return UnitGUID(unit) end
  if GetUnitGUID then return GetUnitGUID(unit) end
  local _, guid = UnitExists(unit)
  return guid
end

function PP.utils.hasUnitXP()
  return pcall(UnitXP, 'nop', 'nop')
end

function PP:LoadDB()
  if type(PizzaPocketDB) ~= 'table' then PizzaPocketDB = {} end
  if PizzaPocketDB.showStats == nil then PizzaPocketDB.showStats = false end
  if PizzaPocketDB.autoStats == nil then PizzaPocketDB.autoStats = true end

  PizzaPocketDB.alltime = PP.stats.normalize(PizzaPocketDB.alltime)
  PP.stats.alltime = PizzaPocketDB.alltime

  PP.statsframe.restore()
  PP.gold.load()
end

PP:RegisterEvent('VARIABLES_LOADED')
PP:RegisterEvent('LOOT_OPENED')
PP:RegisterEvent('LOOT_CLOSED')
PP:RegisterEvent('ZONE_CHANGED_NEW_AREA')
PP:RegisterEvent('PLAYER_ENTERING_WORLD')
PP:RegisterEvent('CHAT_MSG_SPELL_SELF_DAMAGE')
PP:RegisterEvent('CHAT_MSG_SPELL_FAILED_LOCALPLAYER')
PP:RegisterEvent('UI_ERROR_MESSAGE')
PP:RegisterEvent('PARTY_MEMBERS_CHANGED')
PP:RegisterEvent('RAID_ROSTER_UPDATE')
PP:RegisterEvent('PLAYER_MONEY')
PP:RegisterEvent('CHAT_MSG_SYSTEM')
PP:RegisterEvent('PLAYER_LOGOUT')

PP:SetScript('OnEvent', function ()
  if event == 'LOOT_OPENED' then
    PP.stats.onLootOpened()
  elseif event == 'LOOT_CLOSED' then
    PP.finder.classic.onLootClosed()
  elseif event == 'CHAT_MSG_SPELL_SELF_DAMAGE'
      or event == 'CHAT_MSG_SPELL_FAILED_LOCALPLAYER' then
    PP.stats.onCombatMessage(arg1)
  elseif event == 'UI_ERROR_MESSAGE' then
    PP.stats.onErrorMessage(arg1)
  elseif event == 'VARIABLES_LOADED' then
    PP:LoadDB()
  elseif event == 'ZONE_CHANGED_NEW_AREA' then
    PP.picked = {}
    PP.gold.check()
    PP.statsframe.updateAuto()
  elseif event == 'PARTY_MEMBERS_CHANGED' or event == 'RAID_ROSTER_UPDATE' then
    PP.statsframe.updateAuto()
  elseif event == 'PLAYER_MONEY' then
    PP.gold.onMoney()
    PP.statsframe.update()
  elseif event == 'CHAT_MSG_SYSTEM' then
    PP.gold.onSystemMessage(arg1)
  elseif event == 'PLAYER_LOGOUT' then
    PP.gold.onLogout()
  elseif event == 'PLAYER_ENTERING_WORLD' then
    PP.gold.onEnteringWorld(arg1)
    PP.nameplates.hook()
    -- PizzaRota may have loaded after us, so look for its frame again.
    PP.statsframe.anchor()
    PP.statsframe.updateAuto()
  end
end)

PP:SetScript('OnUpdate', function ()
  PP.stats.poll()
end)
