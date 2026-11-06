-- Ade Alts: sync
local AA = AdeAlts

----------------------------------------------------------------------
-- sync between accounts (guild / party / raid addon messages)
----------------------------------------------------------------------
local function Encode(c)
  local head = "C^" .. c.name .. "^" .. c.realm .. "^" .. (c.class or "") .. "^" .. (c.updated or 0) .. "^"
  local msgs, cur = {}, ""
  for key, exp in pairs(c.cds) do
    local pair = key .. "=" .. exp
    if string.len(head) + string.len(cur) + string.len(pair) + 1 > 240 then
      table.insert(msgs, head .. cur)
      cur = ""
    end
    if cur ~= "" then cur = cur .. "~" end
    cur = cur .. pair
  end
  table.insert(msgs, head .. cur)
  return msgs
end

function AA.Send(msg)
  if not (AA.db and AA.db.chat) then return end
  if IsInGuild and IsInGuild() then SendAddonMessage(AA.PREFIX, msg, "GUILD") end
  if GetNumRaidMembers() > 0 then
    SendAddonMessage(AA.PREFIX, msg, "RAID")
  elseif GetNumPartyMembers() > 0 then
    SendAddonMessage(AA.PREFIX, msg, "PARTY")
  end
end

function AA.Broadcast()
  if not AA.me then return end
  AA.lastBroadcast = GetTime()
  for _, m in ipairs(Encode(AA.me)) do AA.Send(m) end
end

function AA.ReceiveRecord(text)
  local _, _, name, realm, class, upd, body = string.find(text, "^C%^([^%^]*)%^([^%^]*)%^([^%^]*)%^(%d*)%^(.*)$")
  if not name or name == "" then return false end
  upd = tonumber(upd) or 0
  local k = name .. "-" .. realm
  if AA.db.ignored and AA.db.ignored[k] then return false end
  local c = AA.db.chars[k]
  if c and (c.updated or 0) > upd then return false end -- we already have newer data
  if not c then
    c = { name = name, realm = realm, class = class, cds = {}, remote = true }
    AA.db.chars[k] = c
  end
  if class ~= "" then c.class = class end
  c.cds = c.cds or {}
  for key, exp in string.gfind(body, "([^~=]+)=(%d+)") do
    c.cds[key] = tonumber(exp)
  end
  c.updated = upd
  AA.ClampRecord(c)
  return true
end

-- shared file between accounts on the same game folder (needs SuperWoW)
local function InvStr(list)
  if not list then return "" end
  local parts = {}
  for _, e in ipairs(list) do table.insert(parts, e[1] .. ":" .. e[2]) end
  return table.concat(parts, "~")
end

local function ParseInv(str)
  local list = {}
  for id, n in string.gfind(str or "", "(%d+):(%d+)") do
    table.insert(list, { tonumber(id), tonumber(n) })
  end
  return list
end

local function EncodeAlt(c)
  return "A^" .. c.name .. "^" .. c.realm .. "^" .. (c.class or "") .. "^" .. (c.level or 0) .. "^" .. (c.gold or 0)
    .. "^" .. (c.dataTs or 0) .. "^" .. (c.invTs or 0) .. "^" .. (c.bankTs or 0)
    .. "^" .. InvStr(c.inv) .. "^" .. InvStr(c.bank)
end

local function ReceiveAlt(text)
  local _, _, name, realm, class, lvl, gold, dts, its, bts, inv, bank =
    string.find(text, "^A%^([^%^]*)%^([^%^]*)%^([^%^]*)%^(%d*)%^(%d*)%^(%d*)%^(%d*)%^(%d*)%^([^%^]*)%^(.*)$")
  if not name or name == "" then return false end
  local k = name .. "-" .. realm
  if AA.db.ignored and AA.db.ignored[k] then return false end
  local c = AA.db.chars[k]
  if not c then
    c = { name = name, realm = realm, class = class, cds = {}, remote = true }
    AA.db.chars[k] = c
  end
  dts, its, bts = tonumber(dts) or 0, tonumber(its) or 0, tonumber(bts) or 0
  local ch = false
  if dts > (c.dataTs or 0) then
    c.dataTs = dts
    c.level = tonumber(lvl)
    c.gold = tonumber(gold)
    if class ~= "" then c.class = class end
    ch = true
  end
  if its > (c.invTs or 0) then
    c.invTs = its
    c.inv = ParseInv(inv)
    ch = true
  end
  if bts > (c.bankTs or 0) then
    c.bankTs = bts
    c.bank = ParseInv(bank)
    ch = true
  end
  return ch
end

local function ReceiveItem(text)
  local _, _, id, name, tex, q = string.find(text, "^I%^(%d+)%^([^%^]*)%^([^%^]*)%^(%d*)$")
  if not id then return end
  id = tonumber(id)
  AA.db.items = AA.db.items or {}
  local it = AA.db.items[id]
  if not it or not it.n or not it.t or it.t == "" then
    AA.db.items[id] = { n = name, t = tex, q = tonumber(q) or 1 }
  end
end

local function EncodeProf(c, pname, p)
  return "P^" .. c.name .. "^" .. c.realm .. "^" .. pname .. "^" .. (p.r or 0) .. "^" .. (p.m or 0)
    .. "^" .. (p.ts or 0) .. "^" .. (p.rts or 0) .. "^" .. table.concat(p.rec or {}, "~")
end

local function ReceiveProf(text)
  local _, _, name, realm, pname, r, m, ts, rts, rec =
    string.find(text, "^P%^([^%^]*)%^([^%^]*)%^([^%^]*)%^(%d*)%^(%d*)%^(%d*)%^(%d*)%^(.*)$")
  if not name or name == "" or pname == "" then return false end
  local gone = (tonumber(m) or 0) == 0 and (tonumber(r) or 0) == 0     -- tombstone: profession was dropped
  if not gone and AA.BadProf(pname, tonumber(m)) then return false end
  local k = name .. "-" .. realm
  if AA.db.ignored and AA.db.ignored[k] then return false end
  local c = AA.db.chars[k]
  if not c then
    c = { name = name, realm = realm, cds = {}, remote = true }
    AA.db.chars[k] = c
  end
  c.prof = c.prof or {}
  c.profGone = c.profGone or {}
  ts, rts = tonumber(ts) or 0, tonumber(rts) or 0
  if gone then
    if ts > (c.profGone[pname] or 0) then
      c.profGone[pname] = ts
      local p0 = c.prof[pname]
      if p0 and ts > (p0.ts or 0) then c.prof[pname] = nil end
      return true
    end
    return false
  end
  if ts <= (c.profGone[pname] or 0) then return false end     -- dropped after this data was written
  local p = c.prof[pname]
  if not p then
    p = {}
    c.prof[pname] = p
  end
  local ch = false
  if ts > (p.ts or 0) then
    p.ts = ts
    p.r = tonumber(r)
    p.m = tonumber(m)
    ch = true
  end
  if rts > (p.rts or 0) then
    p.rts = rts
    local list = {}
    for rn in string.gfind(rec, "[^~]+") do table.insert(list, rn) end
    p.rec = list
    p.sig = nil
    ch = true
  end
  return ch
end

local function EncodeEquip(c)
  local parts = {}
  for slot = 0, 19 do
    if c.equip and c.equip[slot] then table.insert(parts, slot .. "=" .. c.equip[slot]) end
  end
  return "E^" .. c.name .. "^" .. c.realm .. "^" .. (c.eqTs or 0) .. "^" .. table.concat(parts, "~")
end

local function ReceiveEquip(text)
  local _, _, name, realm, ts, body = string.find(text, "^E%^([^%^]*)%^([^%^]*)%^(%d*)%^(.*)$")
  if not name or name == "" then return false end
  local k = name .. "-" .. realm
  if AA.db.ignored and AA.db.ignored[k] then return false end
  local c = AA.db.chars[k]
  if not c then
    c = { name = name, realm = realm, cds = {}, remote = true }
    AA.db.chars[k] = c
  end
  ts = tonumber(ts) or 0
  if ts <= (c.eqTs or 0) then return false end
  local eq = {}
  for slot, ref in string.gfind(body, "(%d+)=(%-?%d+:%-?%d+:%-?%d+:%-?%d+)") do
    eq[tonumber(slot)] = ref
  end
  c.equip = eq
  c.eqTs = ts
  return true
end

-- bag sizes / used slots: B^name^realm^invBagsTs^bankBagsTs^inv^bank
local function EncodeBags(c)
  return "B^" .. c.name .. "^" .. c.realm .. "^" .. (c.invBagsTs or 0) .. "^" .. (c.bankBagsTs or 0)
    .. "^" .. (c.invBags or "") .. "^" .. (c.bankBags or "")
end

local function ReceiveBags(text)
  local _, _, name, realm, its, bts, inv, bank =
    string.find(text, "^B%^([^%^]*)%^([^%^]*)%^(%d*)%^(%d*)%^([^%^]*)%^(.*)$")
  if not name or name == "" then return false end
  local k = name .. "-" .. realm
  if AA.db.ignored and AA.db.ignored[k] then return false end
  local c = AA.db.chars[k]
  if not c then
    c = { name = name, realm = realm, cds = {}, remote = true }
    AA.db.chars[k] = c
  end
  its, bts = tonumber(its) or 0, tonumber(bts) or 0
  local ch = false
  if its > (c.invBagsTs or 0) then
    c.invBagsTs = its
    c.invBags = inv
    ch = true
  end
  if bts > (c.bankBagsTs or 0) then
    c.bankBagsTs = bts
    c.bankBags = bank
    ch = true
  end
  return ch
end

local function FileRead(name)
  if not (ImportFile and ExportFile) then return nil end
  local ok, txt = pcall(ImportFile, name)
  if ok and txt and txt ~= "" then return txt end
  ok, txt = pcall(ImportFile, name .. ".txt")
  if ok and txt and txt ~= "" then return txt end
  return nil
end

local function MergeText(txt)
  local n = 0
  for line in string.gfind(txt, "[^\r\n]+") do
    local t = string.sub(line, 1, 2)
    if t == "C^" then
      if AA.ReceiveRecord(line) then n = n + 1 end
    elseif t == "A^" then
      if ReceiveAlt(line) then n = n + 1 end
    elseif t == "P^" then
      if ReceiveProf(line) then n = n + 1 end
    elseif t == "E^" then
      if ReceiveEquip(line) then n = n + 1 end
    elseif t == "B^" then
      if ReceiveBags(line) then n = n + 1 end
    elseif t == "I^" then
      ReceiveItem(line)
    end
  end
  return n
end

local legacyDone = false
AA.FileMerge = function()
  if not AA.db then return end
  local n = 0
  local txt = FileRead(AA.FILE)
  if txt then n = n + MergeText(txt) end
  if not legacyDone then
    legacyDone = true
    local old = FileRead(AA.LEGACY)
    if old then n = n + MergeText(old) end
  end
  if n > 0 then AA.Refresh() end
end

local function FileWrite()
  if not (ImportFile and ExportFile) or not AA.db then return end
  local parts, seen = {}, {}
  for k, c in pairs(AA.db.chars) do
    for _, m in ipairs(Encode(c)) do table.insert(parts, m) end
    if c.dataTs or c.invTs or c.bankTs then table.insert(parts, EncodeAlt(c)) end
    local lists = { c.inv or {}, c.bank or {} }
    for _, list in ipairs(lists) do
      for _, e in ipairs(list) do seen[e[1]] = true end
    end
    if c.prof then
      for pname, p in pairs(c.prof) do table.insert(parts, EncodeProf(c, pname, p)) end
    end
    for pname, gts in pairs(c.profGone or {}) do
      if not (c.prof and c.prof[pname]) then
        table.insert(parts, "P^" .. c.name .. "^" .. c.realm .. "^" .. pname .. "^0^0^" .. gts .. "^0^")
      end
    end
    if c.invBags or c.bankBags then table.insert(parts, EncodeBags(c)) end
    if c.equip then
      table.insert(parts, EncodeEquip(c))
      for slot, ref in pairs(c.equip) do
        local _, _, sid = string.find(ref, "^(%d+)")
        if sid then seen[tonumber(sid)] = true end
      end
    end
  end
  if AA.db.items then
    for id in pairs(seen) do
      local it = AA.db.items[id]
      if it and it.n then
        table.insert(parts, "I^" .. id .. "^" .. it.n .. "^" .. (it.t or "") .. "^" .. (it.q or 1))
      end
    end
  end
  pcall(ExportFile, AA.FILE, table.concat(parts, "\n"))
  AA.fileDirty = false
  AA.lastFileWrite = GetTime()
end

AA.FileSync = function()
  AA.FileMerge()
  FileWrite()
end

local function ExportString()
  local parts = {}
  for k, c in pairs(AA.db.chars) do
    for _, m in ipairs(Encode(c)) do table.insert(parts, m) end
  end
  return table.concat(parts, "#")
end

local function ImportString(text)
  local n = 0
  for rec in string.gfind(text, "[^#]+") do
    if AA.ReceiveRecord(rec) then n = n + 1 end
  end
  return n
end

-- export / import box
local io = CreateFrame("Frame", "AdeAltsIO", UIParent)
io:SetWidth(440)
io:SetHeight(90)
io:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
io:SetFrameStrata("DIALOG")
io:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
io:SetBackdropColor(0, 0, 0, 0.95)
io:EnableMouse(true)
io:Hide()
table.insert(UISpecialFrames, "AdeAltsIO")

local iotitle = io:CreateFontString(nil, "OVERLAY", "GameFontNormal")
iotitle:SetPoint("TOPLEFT", io, "TOPLEFT", 12, -10)
iotitle:SetText("Copy (Ctrl+C) to export, or paste (Ctrl+V) and press Import")

local eb = CreateFrame("EditBox", "AdeAltsIOEdit", io)
eb:SetWidth(410)
eb:SetHeight(22)
eb:SetPoint("TOPLEFT", io, "TOPLEFT", 15, -30)
eb:SetFontObject(ChatFontNormal)
eb:SetAutoFocus(false)
eb:SetMaxLetters(0)
eb:SetTextInsets(4, 4, 2, 2)
eb:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 8,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
eb:SetBackdropColor(0.1, 0.1, 0.1, 1)
eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)

local bimp = CreateFrame("Button", nil, io, "UIPanelButtonTemplate")
bimp:SetWidth(90); bimp:SetHeight(22)
bimp:SetPoint("BOTTOMLEFT", io, "BOTTOMLEFT", 15, 10)
bimp:SetText("Import")
bimp:SetScript("OnClick", function()
  local n = ImportString(eb:GetText() or "")
  AA.Print("imported " .. n .. " record(s).")
  AA.Refresh()
end)

local bclose = CreateFrame("Button", nil, io, "UIPanelButtonTemplate")
bclose:SetWidth(90); bclose:SetHeight(22)
bclose:SetPoint("BOTTOMRIGHT", io, "BOTTOMRIGHT", -15, 10)
bclose:SetText("Close")
bclose:SetScript("OnClick", function() io:Hide() end)

function AA.ShowIO(exportMode)
  io:Show()
  if exportMode then
    eb:SetText(ExportString())
    eb:SetFocus()
    eb:HighlightText()
  else
    eb:SetText("")
    eb:SetFocus()
  end
end

