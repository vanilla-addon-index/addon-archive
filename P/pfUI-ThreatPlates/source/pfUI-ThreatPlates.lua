-- pfUI-ThreatPlates
-- Shows Turtle WoW threat (server side API used by TWThreat) on pfUI nameplates.
--
-- Data source (same as TWThreat):
--   request : SendAddonMessage("TWT_UDTSv4_TM", "limit=N", "RAID"|"PARTY")
--   answer  : CHAT_MSG_ADDON containing
--             "TWTv4=player:tank:threat:perc:melee[:...];..."        (current target)
--             "#TMTv1=creature:guid:player:perc;..."                 (every mob you tank)

if not pfUI then return end

pfUI:RegisterModule("threatplates", "vanilla", function()
  -- config defaults
  pfUI:UpdateConfig("threatplates", nil, "enable",     "1")
  pfUI:UpdateConfig("threatplates", nil, "role",       "auto")
  pfUI:UpdateConfig("threatplates", nil, "interval",   "1")
  pfUI:UpdateConfig("threatplates", nil, "limit",      "10")
  pfUI:UpdateConfig("threatplates", nil, "share",      "1")
  pfUI:UpdateConfig("threatplates", nil, "cache",      "3")
  -- 1.9.0: 1 s was too short, the default is now 3 s (one time migration of the old default)
  if not C.threatplates.cache_v2 then
    if C.threatplates.cache == "1" then C.threatplates.cache = "3" end
    C.threatplates.cache_v2 = "1"
  end
  pfUI:UpdateConfig("threatplates", nil, "experimental", "0")
  pfUI:UpdateConfig("threatplates", nil, "scanage",    "2")
  pfUI:UpdateConfig("threatplates", nil, "scaninterval", "1")
  pfUI:UpdateConfig("threatplates", nil, "showbar",    "1")
  pfUI:UpdateConfig("threatplates", nil, "barpos",     "ABOVE")
  pfUI:UpdateConfig("threatplates", nil, "baroffset",  "2")

  -- 1.4.0: the bar now sits above the health bar by default (one time migration)
  if not C.threatplates.barpos_v2 then
    if C.threatplates.barpos == "BOTTOM" then C.threatplates.barpos = "ABOVE" end
    C.threatplates.barpos_v2 = "1"
  end
  pfUI:UpdateConfig("threatplates", nil, "barheight",  "3")
  pfUI:UpdateConfig("threatplates", nil, "showtext",   "1")
  pfUI:UpdateConfig("threatplates", nil, "textpos",    "RIGHT")
  pfUI:UpdateConfig("threatplates", nil, "textsize",   "0")
  pfUI:UpdateConfig("threatplates", nil, "showname",   "1")
  pfUI:UpdateConfig("threatplates", nil, "aggrohp",    "1")
  pfUI:UpdateConfig("threatplates", nil, "tgtcolor",   "1")
  pfUI:UpdateConfig("threatplates", nil, "warnperc",   "80")
  pfUI:UpdateConfig("threatplates", nil, "hpsecure",   ".2,.8,.2,1")
  pfUI:UpdateConfig("threatplates", nil, "hpwarn",     "1,.55,0,1")
  pfUI:UpdateConfig("threatplates", nil, "hpdanger",   ".9,.1,.1,1")
  pfUI:UpdateConfig("threatplates", nil, "colorlow",   ".2,1,.2,1")
  pfUI:UpdateConfig("threatplates", nil, "colormid",   "1,1,.2,1")
  pfUI:UpdateConfig("threatplates", nil, "colorhigh",  "1,.2,.2,1")
  pfUI:UpdateConfig("threatplates", nil, "coloraggro", "1,0,1,1")
  pfUI:UpdateConfig("threatplates", nil, "colorlost",  "1,.5,0,1")

  local L = {
    ["AGGRO"] = "AGGRO",
    ["Enable"] = "Enable",
    ["Role"] = "Role",
    ["Auto"] = "Auto",
    ["Damage / Healer"] = "Damage / Healer",
    ["Tank"] = "Tank",
    ["Query Interval (seconds)"] = "Query Interval (seconds)",
    ["Threat Entries Requested"] = "Threat Entries Requested",
    ["Share Threat With Group"] = "Share Threat With Group",
    ["Show Threat Bar"] = "Show Threat Bar",
    ["Threat Bar Position"] = "Threat Bar Position",
    ["Inside Health Bar (Bottom)"] = "Inside Health Bar (Bottom)",
    ["Inside Health Bar (Top)"] = "Inside Health Bar (Top)",
    ["Below Health Bar"] = "Below Health Bar",
    ["Above Health Bar"] = "Above Health Bar",
    ["Threat Bar Spacing"] = "Threat Bar Spacing",
    ["Threat Bar Height"] = "Threat Bar Height",
    ["Show Threat Text"] = "Show Threat Text",
    ["Threat Text Position"] = "Threat Text Position",
    ["Right Of Health Bar"] = "Right Of Health Bar",
    ["Left Of Health Bar"] = "Left Of Health Bar",
    ["Center Of Health Bar"] = "Center Of Health Bar",
    ["Threat Text Size (0 = auto)"] = "Threat Text Size (0 = auto)",
    ["Tank: Show Next Player Name"] = "Tank: Show Next Player Name",
    ["Color Health Bar By Aggro"] = "Color Health Bar By Aggro",
    ["Warning Threshold (%)"] = "Warning Threshold (%)",
    ["Health Bar: Aggro Secured (Tank)"] = "Health Bar: Aggro Secured (Tank)",
    ["Health Bar: Warning"] = "Health Bar: Warning",
    ["Health Bar: Danger (Aggro Lost / Pulled)"] = "Health Bar: Danger (Aggro Lost / Pulled)",
    ["Low Threat Color"] = "Low Threat Color",
    ["Medium Threat Color"] = "Medium Threat Color",
    ["High Threat Color"] = "High Threat Color",
    ["Aggro Color (Damage / Healer)"] = "Aggro Color (Damage / Healer)",
    ["Lost Aggro Color (Tank)"] = "Lost Aggro Color (Tank)",
    ["Display"] = "Display",
    ["Colors"] = "Colors",
  }

  if GetLocale() == "frFR" then
    L["AGGRO"] = "AGGRO"
    L["Enable"] = "Activer"
    L["Role"] = "Rôle"
    L["Auto"] = "Auto"
    L["Damage / Healer"] = "DPS / Soigneur"
    L["Tank"] = "Tank"
    L["Query Interval (seconds)"] = "Intervalle des requêtes (secondes)"
    L["Threat Entries Requested"] = "Nombre d'entrées de menace demandées"
    L["Share Threat With Group"] = "Partager la menace avec le groupe"
    L["Show Threat Bar"] = "Afficher la barre de menace"
    L["Threat Bar Position"] = "Position de la barre de menace"
    L["Inside Health Bar (Bottom)"] = "Dans la barre de vie (bas)"
    L["Inside Health Bar (Top)"] = "Dans la barre de vie (haut)"
    L["Below Health Bar"] = "Sous la barre de vie"
    L["Above Health Bar"] = "Au-dessus de la barre de vie"
    L["Threat Bar Spacing"] = "Espacement de la barre de menace"
    L["Threat Bar Height"] = "Hauteur de la barre de menace"
    L["Show Threat Text"] = "Afficher le texte de menace"
    L["Threat Text Position"] = "Position du texte de menace"
    L["Right Of Health Bar"] = "À droite de la barre de vie"
    L["Left Of Health Bar"] = "À gauche de la barre de vie"
    L["Center Of Health Bar"] = "Au centre de la barre de vie"
    L["Threat Text Size (0 = auto)"] = "Taille du texte (0 = auto)"
    L["Tank: Show Next Player Name"] = "Tank : afficher le joueur suivant"
    L["Color Health Bar By Aggro"] = "Colorer la barre de vie selon l'aggro"
    L["Warning Threshold (%)"] = "Seuil d'alerte (%)"
    L["Health Bar: Aggro Secured (Tank)"] = "Barre de vie : aggro tenue (tank)"
    L["Health Bar: Warning"] = "Barre de vie : alerte"
    L["Health Bar: Danger (Aggro Lost / Pulled)"] = "Barre de vie : danger (aggro perdue / prise)"
    L["Low Threat Color"] = "Couleur menace faible"
    L["Medium Threat Color"] = "Couleur menace moyenne"
    L["High Threat Color"] = "Couleur menace élevée"
    L["Aggro Color (Damage / Healer)"] = "Couleur aggro (DPS / Soigneur)"
    L["Lost Aggro Color (Tank)"] = "Couleur aggro perdue (Tank)"
    L["Display"] = "Affichage"
    L["Colors"] = "Couleurs"
  end

  local THREAT_API = "TWTv4="
  local TANKMODE_API = "TMTv1="
  local UDTS = "TWT_UDTSv4_TM"
  local STALE = 3 -- seconds before data is considered outdated
  -- group sharing uses TWThreat's own channel and relay format, so that both addons
  -- understand each other (octo-addons TWThreat 1.3.0-octo1 and later)
  local COMM = "TWT"                 -- TWThreat addon message prefix
  local RELAY_API = "TWTRelayV2:"    -- TWTRelayV2:<mob>#name:tank:threat:perc:melee;...
  local TANK_API = "PFTPTankV1:"     -- PFTPTankV1:creature:guid:next:perc;...  (no TWThreat equivalent)
  local MAXLEN = 240                 -- same limit as TWThreat's relay

  local tp = CreateFrame("Frame", "pfThreatPlates", UIParent)
  pfUI.threatplates = tp

  local playername = UnitName("player")
  local superwow = SUPERWOW_VERSION or superwow_active
  -- ClassicAPI (used by the brues-code pfUI fork): UnitGUID + event driven nameplates
  local classicapi = C_NamePlate and C_NamePlate.GetNamePlateForUnit and UnitGUID and true
  local colors = {}

  -- data
  local target = { time = 0 }   -- threat list of current target
  local tanked = {}             -- [serverguid] = { creature, player, perc, time }
  -- threat of targets we just lost (target switched or cleared), kept for a short while
  -- [guid or "n:"..name] = { tank, mine, next, nextperc, expires }
  local recent = {}
  -- experimental scan: threat lists fetched by briefly targeting other mobs
  -- [guid] = { guid, name, tank, mine, next, nextperc, time }
  local scanned = {}
  local GRACE = 1               -- seconds added to the scan threshold: time to fetch the next list
  local scan = { state = nil, mute = 0, quiet = 0, nextat = 0 }

  -- shared by the group (and our own target list, merged in)
  -- [HEXGUID] = { tank, tanktime, remote, entries = { [player] = { perc, time, rtime } } }
  local lists = {}
  -- [serverguid] = { creature, tank, next, perc, time }   (tank mode lists of other tanks)
  local sharedtm = {}
  local tankedraw = {}          -- our own tank mode entries, ready to be shared
  local relayto = {}            -- healers that asked us to relay (/twthmt) while TWThreat is off

  -- -------------------------------------------------------------------------
  -- helpers
  -- -------------------------------------------------------------------------
  local function explode(str, sep)
    local res = {}
    local from = 1
    local s, e = strfind(str, sep, from, true)
    while s do
      table.insert(res, strsub(str, from, s - 1))
      from = e + 1
      s, e = strfind(str, sep, from, true)
    end
    table.insert(res, strsub(str, from))
    return res
  end

  -- exact hex -> decimal conversion for 64-bit guids (lua numbers lose precision)
  local function HexToDec(hex)
    local digits = { 0 }
    for i = 1, strlen(hex) do
      local carry = tonumber(strsub(hex, i, i), 16) or 0
      for j = 1, table.getn(digits) do
        local v = digits[j] * 16 + carry
        digits[j] = math.mod(v, 10000000)
        carry = floor(v / 10000000)
      end
      while carry > 0 do
        table.insert(digits, math.mod(carry, 10000000))
        carry = floor(carry / 10000000)
      end
    end

    local n = table.getn(digits)
    local out = tostring(digits[n])
    for j = n - 1, 1, -1 do
      out = out .. string.format("%07d", digits[j])
    end
    return out
  end

  local function StripZeros(str)
    local _, _, rest = strfind(str, "^0*(%d+)$")
    return rest or str
  end

  -- every representation a server guid could have for a given superwow guid
  local guidforms = {}
  local guidcount = 0
  local function GetGuidForms(guid)
    if guidforms[guid] then return guidforms[guid] end

    local hex = string.upper(guid)
    hex = string.gsub(hex, "^0X", "")
    local len = strlen(hex)

    local forms = { full = StripZeros(HexToDec(hex)), hex = hex }
    if len >= 8 then forms.low32 = tostring(tonumber(strsub(hex, len - 7), 16)) end
    if len >= 6 then forms.low24 = tostring(tonumber(strsub(hex, len - 5), 16)) end

    guidcount = guidcount + 1
    if guidcount > 500 then guidforms = {} guidcount = 1 end
    guidforms[guid] = forms
    return forms
  end

  local function NormalizeServerGuid(guid)
    if strfind(guid, "^0[xX]") then
      return StripZeros(HexToDec(strsub(guid, 3)))
    end
    return StripZeros(guid)
  end

  local function HexKey(guid)
    if not guid then return nil end
    local hex = string.gsub(string.upper(guid), "^0X", "")
    return hex
  end

  -- find the tank mode entry matching a nameplate in a [serverguid] table
  local function FindByServerGuid(tbl, guid, name)
    local data
    if guid then
      local forms = GetGuidForms(guid)
      data = tbl[forms.full] or tbl[forms.hex]
      if not data then
        local alt = (forms.low32 and tbl[forms.low32]) or (forms.low24 and tbl[forms.low24])
        if alt and (not name or alt.creature == name) then data = alt end
      end
    elseif name then
      -- no guid: only match when the creature name is unique
      local count = 0
      for _, d in pairs(tbl) do
        if d.creature == name then data = d count = count + 1 end
      end
      if count ~= 1 then data = nil end
    end
    return data
  end

  local function GroupChannel()
    if GetNumRaidMembers() > 0 then return "RAID" end
    if GetNumPartyMembers() > 0 then return "PARTY" end
    return nil
  end

  local function GuidOfUnit(unit)
    if UnitGUID then return UnitGUID(unit) end
    if not superwow then return nil end
    local _, guid = UnitExists(unit)
    return guid
  end

  local function GetTargetGuid()
    return GuidOfUnit("target")
  end

  local function UnitByName(name)
    local count = GetNumRaidMembers()
    if count > 0 then
      for i = 1, count do
        if UnitName("raid" .. i) == name then return "raid" .. i end
      end
    else
      for i = 1, GetNumPartyMembers() do
        if UnitName("party" .. i) == name then return "party" .. i end
      end
    end
    return nil
  end

  -- TWThreat with a working relay is loaded: it relays and answers /twthmt itself
  local function TWThreatRelays()
    return TWT and TWT.relayApi == RELAY_API
  end

  local function GetPlateGuid(plate)
    if plate.cachedGuid then return plate.cachedGuid end
    if plate.unit and UnitGUID then return UnitGUID(plate.unit) end
    if superwow and plate.parent and plate.parent.GetName then return plate.parent:GetName(1) end
    return nil
  end

  local function ThreatColor(perc)
    local low, mid, high = colors.low, colors.mid, colors.high
    if perc >= 100 then return high[1], high[2], high[3], high[4] end
    if perc <= 0 then return low[1], low[2], low[3], low[4] end

    local a, b, p
    if perc < 50 then
      a, b, p = low, mid, perc / 50
    else
      a, b, p = mid, high, (perc - 50) / 50
    end

    return a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p,
      a[3] + (b[3] - a[3]) * p, a[4] + (b[4] - a[4]) * p
  end

  -- -------------------------------------------------------------------------
  -- packet handling
  -- -------------------------------------------------------------------------
  local function RecentKey(guid, name)
    if guid then return guid end
    if name then return "n:" .. name end
    return nil
  end

  local function ScanOn()
    return C.threatplates.experimental == "1" and classicapi and TargetUnit and true or nil
  end

  -- how long a scanned list is displayed: the refresh threshold plus a margin, so the
  -- number is still there when the next scan of that mob comes back
  local function ScanLife()
    local age = tonumber(C.threatplates.scanage) or 2
    if age < .5 then age = .5 end
    return age + GRACE
  end

  -- how long the list of a lost target stays displayed ("cache" option; 0 = off).
  -- With the scan on it is at least as long as a scanned list, since the scan refreshes it.
  local function Linger()
    local linger = tonumber(C.threatplates.cache) or 0
    if linger > 0 and ScanOn() and ScanLife() > linger then linger = ScanLife() end
    return linger
  end

  -- keep the list of the target we are about to lose for Linger() seconds
  local function ArchiveTarget()
    local now = GetTime()
    local linger = Linger()
    local key = RecentKey(target.guid, target.name)
    if linger > 0 and key and target.tank and target.time + STALE > now then
      local expires = now + linger
      recent[key] = {
        tank = target.tank, mine = target.mine, next = target.next,
        nextperc = target.nextperc, expires = expires,
      }
    end
    target.time = 0
  end

  -- true when the data we hold belongs to another mob than the current target
  local function TargetChanged()
    if target.time == 0 then return false end
    local guid = GetTargetGuid()
    if guid and target.guid then return guid ~= target.guid end
    return UnitName("target") ~= target.name
  end

  local function HandleThreatPacket(packet)
    local _, e = strfind(packet, THREAT_API, 1, true)
    if not e then return end

    local now = GetTime()
    local dst = target
    if scan.state == "wait" then
      -- reply to the experimental scan: it describes the mob we targeted, not our real target
      dst = {}
    elseif now < scan.mute then
      return -- late reply of an aborted scan: it would land on the restored target
    elseif TargetChanged() then
      ArchiveTarget()
    end

    dst.time = now
    dst.guid = GetTargetGuid()
    dst.name = UnitName("target")
    dst.mine = nil
    dst.tank = nil
    dst.next = nil
    dst.nextperc = nil
    dst.list = {}

    for _, entry in pairs(explode(strsub(packet, e + 1), ";")) do
      local data = explode(entry, ":")
      if data[1] and data[2] and data[3] and data[4] and data[5] then
        local player, istank, perc = data[1], data[2] == "1", tonumber(data[4]) or 0

        if istank then dst.tank = player end
        if player == playername then dst.mine = perc end
        table.insert(dst.list, { player, perc, istank, tonumber(data[3]) or 0, data[5] == "1" })

        if player ~= playername and not istank and (not dst.nextperc or perc > dst.nextperc) then
          dst.next, dst.nextperc = player, perc
        end
      end
    end

    if dst ~= target then scan.result = dst end
  end

  local function HandleTankModePacket(packet)
    local _, e = strfind(packet, TANKMODE_API, 1, true)
    if not e then return end

    local now = GetTime()
    for key in pairs(tanked) do tanked[key] = nil end
    tankedraw = {}

    for _, entry in pairs(explode(strsub(packet, e + 1), ";")) do
      local data = explode(entry, ":")
      if data[1] and data[2] and data[3] and data[4] then
        table.insert(tankedraw, data[1] .. ":" .. data[2] .. ":" .. data[3] .. ":" .. floor((tonumber(data[4]) or 0) + .5) .. ";")
        tanked[NormalizeServerGuid(data[2])] = {
          creature = data[1],
          player = data[3],
          perc = tonumber(data[4]) or 0,
          time = now,
        }
      end
    end
  end

  -- -------------------------------------------------------------------------
  -- group sharing (TWThreat channel "TWT")
  --   TWTRelayV2:<mob>#name:tank:threat:perc:melee;...   threat list of the sender's target
  --   PFTPTankV1:creature:guid:next:perc;...             tank mode list (sender = tank)
  --   TWT_HMT:<tank> / TWT_HMT_OK:<healer> / TWT_HMT_REM:<tank>   healer master target
  -- the mob of a relay is the sender's current target, identified through its guid
  -- -------------------------------------------------------------------------
  local function MergeList(hex, tank, entries, remote)
    local now = GetTime()
    local rec = lists[hex]
    if not rec then
      rec = { entries = {} }
      lists[hex] = rec
    end

    if tank and tank ~= "" then rec.tank, rec.tanktime = tank, now end
    if remote then rec.remote = now end

    for _, entry in pairs(entries) do
      local e = rec.entries[entry[1]]
      if not e then
        e = {}
        rec.entries[entry[1]] = e
      end
      e.perc, e.time = entry[2], now
      if remote then e.rtime = now end
    end
  end

  local function Send(msg)
    local channel = GroupChannel()
    if channel then SendAddonMessage(COMM, msg, channel) end
  end

  local function ShareTarget()
    if not target.name or not target.list or table.getn(target.list) == 0 then return end

    local share = C.threatplates.share == "1"
    local healers = next(relayto) and true

    if not share and not healers then return end

    -- TWThreat already relays this very packet: don't send it twice
    --   - a healer picked us as master target (/twthmt)
    --   - TWThreat shares with the group itself (/twt share, octo-addons 1.3.0-octo2+)
    if TWThreatRelays() then
      if TWT.shouldRelay then return end
      if TWT.shouldShare and TWT_CONFIG and TWT_CONFIG.shareThreat then return end
    end

    -- skip when another player already shared the same mob with everything we know
    -- (never when a healer relies on us: TWThreat only accepts its own master target)
    if target.guid and not healers then
      local rec = lists[HexKey(target.guid)]
      local now = GetTime()
      local window = (tonumber(C.threatplates.interval) or 1) * .75
      if rec and rec.remote and now - rec.remote < window then
        local missing
        for _, entry in pairs(target.list) do
          local e = rec.entries[entry[1]]
          if not e or not e.rtime or now - e.rtime > window then missing = true break end
        end
        if not missing then return end
      end
    end

    table.sort(target.list, function(a, b) return a[2] > b[2] end)

    local msg = RELAY_API .. target.name .. "#"
    for _, entry in pairs(target.list) do
      local item = entry[1] .. ":" .. (entry[3] and "1" or "0") .. ":" .. floor(entry[4]) ..
        ":" .. floor(entry[2] + .5) .. ":" .. (entry[5] and "1" or "0") .. ";"
      if strlen(msg) + strlen(item) > MAXLEN then break end
      msg = msg .. item
    end
    Send(msg)
  end

  local function ShareTankMode()
    if C.threatplates.share ~= "1" or table.getn(tankedraw) == 0 then return end

    local msg = TANK_API
    local count = 0
    for _, item in pairs(tankedraw) do
      if count > 0 and strlen(msg) + strlen(item) > MAXLEN then
        Send(msg)
        msg, count = TANK_API, 0
      end
      msg = msg .. item
      count = count + 1
    end
    if count > 0 then Send(msg) end
  end

  local function HandleRelay(msg, sender)
    local body = strsub(msg, strlen(RELAY_API) + 1)
    local sep = strfind(body, "#", 1, true)
    if not sep then return end
    local mob = strsub(body, 1, sep - 1)

    -- the relayed mob is the sender's target: get its guid
    local unit = UnitByName(sender)
    if not unit or UnitName(unit .. "target") ~= mob then return end
    local guid = GuidOfUnit(unit .. "target")
    if not guid then return end

    local tank
    local entries = {}
    for _, item in pairs(explode(strsub(body, sep + 1), ";")) do
      local e = explode(item, ":")
      -- skip TWThreat's "-Pull Aggro at-" pseudo entry
      if e[1] and e[1] ~= "" and strsub(e[1], 1, 1) ~= "-" and e[4] then
        if e[2] == "1" then tank = e[1] end
        table.insert(entries, { e[1], tonumber(e[4]) or 0 })
      end
    end

    MergeList(HexKey(guid), tank, entries, true)
  end

  local function HandleTankShare(msg, sender)
    local now = GetTime()
    for _, item in pairs(explode(strsub(msg, strlen(TANK_API) + 1), ";")) do
      local e = explode(item, ":")
      if e[1] and e[2] and e[3] and e[4] then
        sharedtm[NormalizeServerGuid(e[2])] = {
          creature = e[1], tank = sender, next = e[3],
          perc = tonumber(e[4]) or 0, time = now,
        }
      end
    end
  end

  -- healer master target handshake, only while no relay capable TWThreat is loaded
  local function HandleHMT(msg, sender)
    if TWThreatRelays() then return end

    if strsub(msg, 1, 12) == "TWT_HMT_REM:" then
      if strsub(msg, 13) == playername then relayto[sender] = nil end
    elseif strsub(msg, 1, 8) == "TWT_HMT:" then
      if strsub(msg, 9) == playername then
        relayto[sender] = true
        Send("TWT_HMT_OK:" .. sender)
      end
    end
  end

  local function CleanRelayTo()
    for name in pairs(relayto) do
      if not UnitByName(name) then relayto[name] = nil end
    end
  end

  local function CleanShared()
    local now = GetTime()
    for hex, rec in pairs(lists) do
      for player, e in pairs(rec.entries) do
        if e.time + STALE < now then rec.entries[player] = nil end
      end
      if not next(rec.entries) then lists[hex] = nil end
    end
    for key, d in pairs(sharedtm) do
      if d.time + STALE < now then sharedtm[key] = nil end
    end
    for key, d in pairs(recent) do
      if d.expires < now then recent[key] = nil end
    end
    for key, d in pairs(scanned) do
      if d.time + ScanLife() < now then scanned[key] = nil end
    end
  end

  -- -------------------------------------------------------------------------
  -- nameplate widgets
  -- -------------------------------------------------------------------------
  local function SetupPlate(plate)
    local tpw = plate.threatplates
    if not tpw then
      tpw = {}
      tpw.bar = CreateFrame("StatusBar", nil, plate.health)
      tpw.bar:SetMinMaxValues(0, 100)
      tpw.bar.bg = tpw.bar:CreateTexture(nil, "BACKGROUND")
      tpw.bar.bg:SetAllPoints()
      tpw.bar.bg:SetTexture(0, 0, 0, .6)
      tpw.text = plate.health:CreateFontString(nil, "OVERLAY")
      plate.threatplates = tpw
    end

    local C = C.threatplates
    local health = plate.health
    local font = (pfUI_config.nameplates and pfUI_config.nameplates.use_unitfonts == "1") and pfUI.font_unit or pfUI.font_default
    local size = tonumber(C.textsize) or 0
    if size <= 0 then size = (tonumber(pfUI_config.global.font_unit_size) or 12) - 2 end

    tpw.bar:SetFrameLevel(health:GetFrameLevel() + 2)
    tpw.bar:SetStatusBarTexture(health:GetStatusBarTexture():GetTexture() or "Interface\\AddOns\\pfUI\\img\\bar")
    tpw.bar:ClearAllPoints()
    tpw.bar:SetHeight(tonumber(C.barheight) or 3)

    -- outside of the health bar: same border style as pfUI, clear of the health bar border
    local outside = C.barpos == "ABOVE" or C.barpos == "BELOW"
    local border = 1
    if GetBorderSize then
      local _, b = GetBorderSize("nameplates")
      border = tonumber(b) or 1
    end
    local gap = border * 2 + (tonumber(C.baroffset) or 0)

    if outside and CreateBackdrop and not tpw.bar.backdrop then
      CreateBackdrop(tpw.bar, border)
    end
    if tpw.bar.backdrop then
      if outside then tpw.bar.backdrop:Show() else tpw.bar.backdrop:Hide() end
    end

    if C.barpos == "ABOVE" then
      tpw.bar:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 0, gap)
      tpw.bar:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, gap)
    elseif C.barpos == "TOP" then
      tpw.bar:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
      tpw.bar:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
    elseif C.barpos == "BELOW" then
      tpw.bar:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -gap)
      tpw.bar:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -gap)
    else
      tpw.bar:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, 0)
      tpw.bar:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    end

    tpw.text:SetFont(font, size, "OUTLINE")
    tpw.text:ClearAllPoints()
    if C.textpos == "LEFT" then
      tpw.text:SetPoint("RIGHT", health, "LEFT", -18, 0)
      tpw.text:SetJustifyH("RIGHT")
    elseif C.textpos == "CENTER" then
      tpw.text:SetPoint("CENTER", health, "CENTER", 0, 0)
      tpw.text:SetJustifyH("CENTER")
    else
      tpw.text:SetPoint("LEFT", health, "RIGHT", 4, 0)
      tpw.text:SetJustifyH("LEFT")
    end

    tpw.config = tp.configversion
    return tpw
  end

  local function HidePlate(plate)
    local tpw = plate.threatplates
    if not tpw then return end
    tpw.bar:Hide()
    tpw.text:Hide()
    if tpw.colored then
      tpw.colored = nil
      tpw.r = nil
      -- let pfUI restore its own health bar color (the fork caches the last color)
      if plate.cache then plate.cache.r = nil end
      if pfUI.nameplates and pfUI.nameplates.OnDataChanged then
        pfUI.nameplates:OnDataChanged(plate)
      end
    end
    tpw.r = nil
  end

  -- builds the display for a threat list
  --   tank      : player holding aggro
  --   mine      : my threat % (nil when unknown)
  --   nextname  : highest player that is not the tank
  --   nextperc  : his threat %
  -- returns value, text, r, g, b, a  (or nil when nothing to show)
  -- aggro state of the last rendered plate, used for the health bar color:
  --   "secure" (tank holds, nobody close), "warn" (close to aggro swap), "danger" (aggro lost / pulled)
  local state

  local function WarnState(perc)
    return perc and perc >= (tonumber(C.threatplates.warnperc) or 80) and "warn" or nil
  end

  local function Render(tank, mine, nextname, nextperc)
    local role = C.threatplates.role
    local showname = C.threatplates.showname == "1"

    if tank == playername then
      if role == "dps" then
        state = "danger"
        return 100, L["AGGRO"], colors.aggro[1], colors.aggro[2], colors.aggro[3], colors.aggro[4]
      end
      local perc = nextperc or 0
      local text = floor(perc + .5) .. "%"
      if showname and nextname then text = nextname .. " " .. text end
      local r, g, b, a = ThreatColor(perc)
      state = WarnState(perc) or "secure"
      return perc, text, r, g, b, a
    elseif mine then
      if role == "tank" then
        state = "danger"
        local text = floor(mine + .5) .. "%"
        if showname and tank then text = tank .. " > " .. text end
        return mine, text, colors.lost[1], colors.lost[2], colors.lost[3], colors.lost[4]
      end
      local r, g, b, a = ThreatColor(mine)
      state = WarnState(mine)
      return mine, floor(mine + .5) .. "%", r, g, b, a
    end
  end

  local function RenderList(rec, now)
    if not rec.tank or not rec.tanktime or rec.tanktime + STALE < now then return nil end

    local mine, nextname, nextperc
    for player, e in pairs(rec.entries) do
      if e.time + STALE >= now then
        if player == playername then mine = e.perc end
        if player ~= rec.tank and player ~= playername and (not nextperc or e.perc > nextperc) then
          nextname, nextperc = player, e.perc
        end
      end
    end

    return Render(rec.tank, mine, nextname, nextperc)
  end

  -- returns value, text, r, g, b, a  (or nil when nothing to show)
  local function GetPlateThreat(plate)
    state = nil
    local now = GetTime()
    local name = plate.original and plate.original.name and plate.original.name:GetText()
    local guid = GetPlateGuid(plate)
    local role = C.threatplates.role
    local share = C.threatplates.share == "1"

    -- 1) detailed threat list of the current target (straight from the server)
    local istarget
    if target.time + STALE > now then
      if guid and target.guid then
        istarget = guid == target.guid
      else
        istarget = plate.istarget and name == target.name
      end
    end

    if istarget and target.tank then
      local value, text, r, g, b, a = Render(target.tank, target.mine, target.next, target.nextperc)
      if value then return value, text, r, g, b, a end
    end

    -- 1b) target we just lost: keep its last known threat for a moment
    local old
    if guid then old = recent[guid] elseif name then old = recent["n:" .. name] end
    if old and old.expires >= now then
      local value, text, r, g, b, a = Render(old.tank, old.mine, old.next, old.nextperc)
      if value then return value, text, r, g, b, a end
    end

    -- 2) our own tank mode list (every mob we are currently tanking)
    if role ~= "dps" then
      local data = FindByServerGuid(tanked, guid, name)
      if data and data.time + STALE > now then
        local text = floor(data.perc + .5) .. "%"
        if C.threatplates.showname == "1" and data.player ~= "" then text = data.player .. " " .. text end
        local r, g, b, a = ThreatColor(data.perc)
        state = WarnState(data.perc) or "secure"
        return data.perc, text, r, g, b, a
      end
    end

    -- 2b) threat list fetched by the experimental scan
    local sc = guid and scanned[guid]
    if sc and sc.tank and sc.time + ScanLife() > now then
      local value, text, r, g, b, a = Render(sc.tank, sc.mine, sc.next, sc.nextperc)
      if value then return value, text, r, g, b, a end
    end

    if not share then return nil end

    -- 3) threat list shared by a group member targeting this mob
    if guid then
      local rec = lists[HexKey(guid)]
      if rec then
        local value, text, r, g, b, a = RenderList(rec, now)
        if value then return value, text, r, g, b, a end
      end
    end

    -- 4) tank mode list shared by another tank: we only know the runner-up
    local data = FindByServerGuid(sharedtm, guid, name)
    if data and data.time + STALE > now and data.next == playername then
      return Render(data.tank, data.perc)
    end

    return nil
  end

  -- no threat data for this mob: tell from its target whether it is on us
  --   returns "secure" / "danger" (health bar color states) or nil (leave pfUI's color)
  local function MobTargetState(plate)
    if not UnitIsUnit then return nil end

    local unit
    if plate.unit and classicapi then
      unit = plate.unit
    else
      local guid = superwow and GetPlateGuid(plate)
      if guid then unit = guid elseif plate.istarget then unit = "target" end
    end
    if not unit then return nil end

    local ok, exists, ontome, incombat, attackable = pcall(function()
      local tgt = (unit == "target") and "targettarget" or (unit .. "target")
      return UnitExists(unit), UnitExists(tgt) and UnitIsUnit(tgt, "player"),
        UnitAffectingCombat(unit), UnitCanAttack("player", unit) and not UnitIsDead(unit)
    end)
    if not ok or not exists or not attackable or not incombat then return nil end

    if C.threatplates.role == "tank" then
      return ontome and "secure" or "danger"   -- a mob that is not on the tank has been lost
    end
    return ontome and "danger" or nil          -- dps / healer: only warn when a mob is on us
  end

  local function UpdatePlate(plate)
    if not plate.health or not plate:IsVisible() then return end

    local value, text, r, g, b, a = GetPlateThreat(plate)
    local tpw = plate.threatplates

    if not value then
      -- no threat information: only the health bar color, from who the mob targets
      state = nil
      if C.threatplates.tgtcolor == "1" and C.threatplates.aggrohp == "1" then state = MobTargetState(plate) end
      if not state then return HidePlate(plate) end
      if not tpw or tpw.config ~= tp.configversion then tpw = SetupPlate(plate) end
      tpw.bar:Hide()
      tpw.text:Hide()
    else
      if not tpw or tpw.config ~= tp.configversion then tpw = SetupPlate(plate) end

      if C.threatplates.showbar == "1" then
        tpw.bar:SetValue(value > 100 and 100 or value)
        tpw.bar:SetStatusBarColor(r, g, b, a)
        tpw.bar:Show()
      else
        tpw.bar:Hide()
      end

      if C.threatplates.showtext == "1" then
        tpw.text:SetText(text)
        tpw.text:SetTextColor(r, g, b, 1)
        tpw.text:Show()
      else
        tpw.text:Hide()
      end
    end

    local hp = C.threatplates.aggrohp == "1" and state and colors[state]
    if hp then
      tpw.r, tpw.g, tpw.b = hp[1], hp[2], hp[3]
      plate.health:SetStatusBarColor(hp[1], hp[2], hp[3], hp[4] or 1)
      -- invalidate pfUI's color cache so it repaints once we stop coloring
      if plate.cache then plate.cache.r = nil end
      tpw.colored = true
    elseif tpw.colored then
      -- back to the regular pfUI color
      tpw.colored, tpw.r = nil, nil
      if plate.cache then plate.cache.r = nil end
      if pfUI.nameplates and pfUI.nameplates.OnDataChanged then
        pfUI.nameplates:OnDataChanged(plate)
      end
    end
  end

  -- keep our health bar color when pfUI refreshes the plate
  if pfUI.nameplates and pfUI.nameplates.OnDataChanged then
    local hook = pfUI.nameplates.OnDataChanged
    pfUI.nameplates.OnDataChanged = function(self, plate)
      hook(self, plate)
      local tpw = plate and plate.threatplates
      if tpw and tpw.colored and tpw.r and C.threatplates.aggrohp == "1" then
        plate.health:SetStatusBarColor(tpw.r, tpw.g, tpw.b, 1)
        if plate.cache then plate.cache.r = nil end
      end
    end
  end

  -- -------------------------------------------------------------------------
  -- plate scanning / update loop
  -- -------------------------------------------------------------------------
  local plates = {}
  local childcount = 0

  local function AddPlate(frame)
    local plate = frame and frame.nameplate
    if plate and plate.health then plates[plate] = true end
  end

  local function ScanPlates()
    -- ClassicAPI: plates are tracked through NAME_PLATE_UNIT_ADDED / _REMOVED
    if classicapi then return end

    local count = WorldFrame:GetNumChildren()
    if count == childcount then return end
    childcount = count

    local children = { WorldFrame:GetChildren() }
    for i = 1, table.getn(children) do
      local frame = children[i]
      if frame.nameplate and frame.nameplate.health and not plates[frame.nameplate] then
        plates[frame.nameplate] = true
      end
    end
  end

  local function HideAll()
    for plate in pairs(plates) do HidePlate(plate) end
  end

  local function InGroup()
    return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
  end

  -- -------------------------------------------------------------------------
  -- experimental scan (ClassicAPI): briefly target mobs whose threat is outdated
  --   one mob per step: TargetUnit(nameplateN) -> ask the server -> restore the target
  -- -------------------------------------------------------------------------
  tp.lastquery = 0

  local function LastTrack(guid, name)
    local t = 0
    local sc = scanned[guid]
    if sc and sc.time > t then t = sc.time end
    if target.guid == guid and target.time > t then t = target.time end
    local rec = lists[HexKey(guid)]
    if rec and rec.tanktime and rec.tanktime > t then t = rec.tanktime end
    local d = FindByServerGuid(tanked, guid, name)
    if d and d.time > t then t = d.time end
    d = FindByServerGuid(sharedtm, guid, name)
    if d and d.time > t then t = d.time end
    return t
  end

  local function PickScanPlate(now)
    local age = tonumber(C.threatplates.scanage) or 2
    if age < .5 then age = .5 end

    local best, besttime, bestguid
    for plate in pairs(plates) do
      local unit = plate.unit
      if unit and plate.health and plate:IsVisible() and not plate.istarget then
        local guid = GetPlateGuid(plate)
        if guid and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit)
           and not UnitIsPlayer(unit) and UnitAffectingCombat(unit) then
          local name = plate.original and plate.original.name and plate.original.name:GetText()
          local t = LastTrack(guid, name)
          if now - t >= age and (not besttime or t < besttime) then best, besttime, bestguid = plate, t, guid end
        end
      end
    end
    return best, bestguid
  end

  local function ScanRestore()
    if scan.hadtarget then
      if GetTargetGuid() ~= scan.prev and TargetLastTarget then TargetLastTarget() end
      if scan.prev and GetTargetGuid() ~= scan.prev then
        -- last resort: target the previous mob through its nameplate
        for plate in pairs(plates) do
          if plate.unit and GetPlateGuid(plate) == scan.prev then TargetUnit(plate.unit) break end
        end
      end
    elseif UnitExists("target") then
      ClearTarget()
    end
  end

  local function ScanFinish(now)
    local res = scan.result
    if res and res.guid == scan.expect and res.tank then
      scanned[scan.expect] = res
      scan.mute = 0
    else
      scan.mute = now + .8
    end

    ScanRestore()
    scan.state, scan.result = nil, nil
    scan.quiet = now + .3 -- PLAYER_TARGET_CHANGED fires a bit later
    scan.nextat = now + (tonumber(C.threatplates.scaninterval) or 1)
  end

  local function ScanStart(now)
    if now - tp.lastquery < .6 then return end -- the reply to a regular query could still be on its way
    if SpellIsTargeting and SpellIsTargeting() then return end

    local plate, guid = PickScanPlate(now)
    if not plate then
      scan.nextat = now + .25
      return
    end

    scan.hadtarget = UnitExists("target") and true or nil
    scan.prev = scan.hadtarget and GetTargetGuid() or nil
    scan.expect, scan.result = guid, nil

    TargetUnit(plate.unit)
    if GetTargetGuid() ~= guid then
      ScanRestore()
      scan.quiet = now + .3
      scan.nextat = now + 1
      return
    end

    scan.state = "wait"
    scan.deadline = now + .7
    tp.lastquery = now
    SendAddonMessage(UDTS, "limit=" .. (tonumber(C.threatplates.limit) or 10), GetNumRaidMembers() > 0 and "RAID" or "PARTY")
  end

  tp.lastdraw = 0
  tp.lastclean = 0
  tp:SetScript("OnUpdate", function()
    local now = GetTime()

    -- query the server
    local interval = tonumber(C.threatplates.interval) or 1
    if interval < .3 then interval = .3 end
    if scan.state ~= "wait" and now - this.lastquery >= interval then
      this.lastquery = now
      if InGroup() and UnitAffectingCombat("player") then
        local limit = tonumber(C.threatplates.limit) or 10
        SendAddonMessage(UDTS, "limit=" .. limit, GetNumRaidMembers() > 0 and "RAID" or "PARTY")
      end
    end

    -- experimental: refresh the threat of mobs we have no recent data for
    if ScanOn() then
      if scan.state == "wait" then
        if scan.result or now >= scan.deadline then ScanFinish(now) end
      elseif now >= scan.nextat and InGroup() and UnitAffectingCombat("player") and not UnitIsDead("player") then
        ScanStart(now)
      end
    end

    -- refresh plates
    if now - this.lastdraw < .1 then return end
    this.lastdraw = now

    if now - this.lastclean > 5 then
      this.lastclean = now
      CleanShared()
    end

    ScanPlates()
    for plate in pairs(plates) do UpdatePlate(plate) end
  end)

  tp:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if not arg2 then return end

      if not strfind(arg2, THREAT_API, 1, true) then
        -- messages from other players on TWThreat's channel
        if arg1 ~= COMM or arg4 == playername then return end

        if strsub(arg2, 1, strlen(RELAY_API)) == RELAY_API then
          if C.threatplates.share == "1" then HandleRelay(arg2, arg4) tp.lastdraw = 0 end
        elseif strsub(arg2, 1, strlen(TANK_API)) == TANK_API then
          if C.threatplates.share == "1" then HandleTankShare(arg2, arg4) tp.lastdraw = 0 end
        elseif strsub(arg2, 1, 7) == "TWT_HMT" then
          HandleHMT(arg2, arg4)
        end
        return
      end

      local threat, tankmode = arg2, nil
      local split = strfind(arg2, "#", 1, true)
      if split then
        threat = strsub(arg2, 1, split - 1)
        tankmode = strsub(arg2, split + 1)
      end

      HandleThreatPacket(threat)
      if tankmode then
        HandleTankModePacket(tankmode)
      else
        -- we always ask for tank mode: no list means we tank nothing anymore
        for k in pairs(tanked) do tanked[k] = nil end
        tankedraw = {}
      end

      if scan.state ~= "wait" and GetTime() >= scan.mute then ShareTarget() end
      if tankmode then ShareTankMode() end

      tp.lastdraw = 0 -- redraw right away

    elseif event == "NAME_PLATE_UNIT_ADDED" then
      AddPlate(C_NamePlate.GetNamePlateForUnit(arg1))
      tp.lastdraw = 0

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      local frame = C_NamePlate.GetNamePlateForUnit(arg1)
      if frame and frame.nameplate then
        HidePlate(frame.nameplate)
        plates[frame.nameplate] = nil
      end

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
      CleanRelayTo()

    elseif event == "PLAYER_TARGET_CHANGED" then
      -- our own scan changes the target too: that is not a real target change
      if scan.state or GetTime() < scan.quiet then return end
      -- the old target's data is kept briefly (cache option), then it is dropped
      if TargetChanged() then ArchiveTarget() end
      tp.lastdraw = 0

    elseif event == "PLAYER_REGEN_ENABLED" then
      if scan.state then ScanFinish(GetTime()) end
      for k in pairs(scanned) do scanned[k] = nil end
      target.time = 0
      for k in pairs(recent) do recent[k] = nil end
      for k in pairs(tanked) do tanked[k] = nil end
      tankedraw = {}
      HideAll()
    end
  end)

  -- -------------------------------------------------------------------------
  -- config
  -- -------------------------------------------------------------------------
  tp.configversion = 0
  function tp:UpdateConfig()
    -- scan switched off while a mob is targeted: give the target back
    if scan.state and C.threatplates.experimental ~= "1" then ScanFinish(GetTime()) end
    colors.low   = { GetStringColor(C.threatplates.colorlow) }
    colors.mid   = { GetStringColor(C.threatplates.colormid) }
    colors.high  = { GetStringColor(C.threatplates.colorhigh) }
    colors.aggro = { GetStringColor(C.threatplates.coloraggro) }
    colors.lost  = { GetStringColor(C.threatplates.colorlost) }
    colors.secure = { GetStringColor(C.threatplates.hpsecure) }
    colors.warn   = { GetStringColor(C.threatplates.hpwarn) }
    colors.danger = { GetStringColor(C.threatplates.hpdanger) }

    self.configversion = self.configversion + 1

    if C.threatplates.enable == "1" then
      self:RegisterEvent("CHAT_MSG_ADDON")
      self:RegisterEvent("PLAYER_TARGET_CHANGED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("RAID_ROSTER_UPDATE")
      self:RegisterEvent("PARTY_MEMBERS_CHANGED")
      if classicapi then
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        -- pick up plates that are already shown
        if C_NamePlate.GetNamePlates then
          local list = C_NamePlate.GetNamePlates()
          if list then for _, frame in pairs(list) do AddPlate(frame) end end
        end
      end
      self:Show()
    else
      self:UnregisterAllEvents()
      self:Hide()
      HideAll()
    end

    for plate in pairs(plates) do
      if plate.threatplates then HidePlate(plate) end
    end
  end

  tp:UpdateConfig()

  -- -------------------------------------------------------------------------
  -- pfUI gui entry (Thirdparty > Threat Plates)
  -- -------------------------------------------------------------------------
  if pfUI.gui and pfUI.gui.CreateGUIEntry then
    local update = function() tp:UpdateConfig() end
    local CreateConfig = pfUI.gui.CreateConfig

    pfUI.gui.CreateGUIEntry(T["Thirdparty"], "Threat Plates", function()
      CreateConfig(update, L["Enable"], C.threatplates, "enable", "checkbox")
      CreateConfig(update, L["Role"], C.threatplates, "role", "dropdown", {
        "auto:" .. L["Auto"], "dps:" .. L["Damage / Healer"], "tank:" .. L["Tank"] })
      CreateConfig(update, L["Query Interval (seconds)"], C.threatplates, "interval")
      CreateConfig(update, L["Threat Entries Requested"], C.threatplates, "limit")
      CreateConfig(update, L["Share Threat With Group"], C.threatplates, "share", "checkbox")
      CreateConfig(update, L["Keep Threat After Target Loss (seconds, 0 = off)"], C.threatplates, "cache")
      CreateConfig(update, L["Experimental: Scan Other Mobs (switches target!)"], C.threatplates, "experimental", "checkbox")
      CreateConfig(update, L["Scan: Refresh Threat Older Than (seconds)"], C.threatplates, "scanage")
      CreateConfig(update, L["Scan: Seconds Between Two Mobs"], C.threatplates, "scaninterval")

      CreateConfig(nil, L["Display"], nil, nil, "header")
      CreateConfig(update, L["Show Threat Bar"], C.threatplates, "showbar", "checkbox")
      CreateConfig(update, L["Threat Bar Position"], C.threatplates, "barpos", "dropdown", {
        "ABOVE:" .. L["Above Health Bar"], "BELOW:" .. L["Below Health Bar"],
        "BOTTOM:" .. L["Inside Health Bar (Bottom)"], "TOP:" .. L["Inside Health Bar (Top)"] })
      CreateConfig(update, L["Threat Bar Height"], C.threatplates, "barheight")
      CreateConfig(update, L["Threat Bar Spacing"], C.threatplates, "baroffset")
      CreateConfig(update, L["Show Threat Text"], C.threatplates, "showtext", "checkbox")
      CreateConfig(update, L["Threat Text Position"], C.threatplates, "textpos", "dropdown", {
        "RIGHT:" .. L["Right Of Health Bar"], "LEFT:" .. L["Left Of Health Bar"],
        "CENTER:" .. L["Center Of Health Bar"] })
      CreateConfig(update, L["Threat Text Size (0 = auto)"], C.threatplates, "textsize")
      CreateConfig(update, L["Tank: Show Next Player Name"], C.threatplates, "showname", "checkbox")
      CreateConfig(update, L["Color Health Bar By Aggro"], C.threatplates, "aggrohp", "checkbox")
      CreateConfig(update, L["Color Health Bar Without Threat Data (mob target)"], C.threatplates, "tgtcolor", "checkbox")
      CreateConfig(update, L["Warning Threshold (%)"], C.threatplates, "warnperc")

      CreateConfig(nil, L["Colors"], nil, nil, "header")
      CreateConfig(update, L["Low Threat Color"], C.threatplates, "colorlow", "color")
      CreateConfig(update, L["Medium Threat Color"], C.threatplates, "colormid", "color")
      CreateConfig(update, L["High Threat Color"], C.threatplates, "colorhigh", "color")
      CreateConfig(update, L["Aggro Color (Damage / Healer)"], C.threatplates, "coloraggro", "color")
      CreateConfig(update, L["Lost Aggro Color (Tank)"], C.threatplates, "colorlost", "color")
      CreateConfig(update, L["Health Bar: Aggro Secured (Tank)"], C.threatplates, "hpsecure", "color")
      CreateConfig(update, L["Health Bar: Warning"], C.threatplates, "hpwarn", "color")
      CreateConfig(update, L["Health Bar: Danger (Aggro Lost / Pulled)"], C.threatplates, "hpdanger", "color")
    end)
  end
end)
