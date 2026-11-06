-- BananaBank Levelups: GZ-Popup, Stufe-60-Anzeige, GZ-Texte
-- Quellen: eigener Levelup (PLAYER_LEVEL_UP, wird an die Gilde gemeldet), Nachricht V~<Name>~<Stufe>
-- anderer Addon-Nutzer und der Vergleich der Gildenliste (alle 30 s). Eine Stufe wird nur einmal gemeldet.
-- Uebergabe aus BananaGuild: Ist BananaGuild vor 1.17.0 geladen, bleibt dieses Feature aus.

local BB = BananaBank
local UI = BB.UI
local C = UI.C
local T = function(k) return BB.T(k) end
local getn = table.getn
local WHITE, MEDIA = UI.WHITE, UI.MEDIA

UI.levelModule = true
BB.levelModule = true
BB.lv = { last = {}, done = {}, seeded = false }

local SCAN_EVERY = 30
local GUILD_FIXED = { 1, 17, 0 }   -- ab dieser BananaGuild-Version ist die GZ-Funktion dort entfernt
local TEXT_COUNT = 20
local TEXT_MAX = 150

-- ------------------------------------------------------------
-- Einstellungen und Freigabe
-- ------------------------------------------------------------
local function G()
  local db = BananaBankDB
  db.gz = db.gz or {}
  if db.gz.texts == nil then db.gz.texts = {} end
  return db.gz
end

function BB:GzOn() return G().on ~= false end
function BB:GzMode() return G().mode or "tens" end
function BB:GzSplash() return G().splash ~= false end

-- Version von BananaGuild als Text, wenn das Addon geladen ist, sonst nil
local function guildVersion()
  if not getglobal("BananaGuild") then return nil end
  local v
  if GetAddOnMetadata then
    local ok, r = pcall(GetAddOnMetadata, "BananaGuild", "Version")
    if ok then v = r end
  end
  return v or "?"
end

-- Hat BananaGuild die GZ-Funktion noch? Dann pausiert dieses Feature (Text der Version, sonst nil).
function BB:GuildHoldsGz()
  local lv = self.lv
  if lv.gchecked then return lv.gblock end
  local v = guildVersion()
  local block
  if v then
    local _, _, a, b, c = string.find(v, "^(%d+)%.(%d+)%.?(%d*)")
    if not a then
      block = v
    else
      a, b, c = tonumber(a), tonumber(b), tonumber(c) or 0
      local f = GUILD_FIXED
      if a < f[1] or (a == f[1] and (b < f[2] or (b == f[2] and c < f[3]))) then block = v end
    end
  end
  -- erst festhalten, wenn alle Addons geladen sind
  if BB.worldReady then
    lv.gchecked = true
    lv.gblock = block
  end
  return block
end

function BB:LevelActive()
  return self:Ready() and self:GzOn() and not self:GuildHoldsGz()
end

-- Bekommt diese Stufe ein Popup? Bei einem Sprung ueber mehrere Stufen zaehlt jede dazwischen.
function BB:LevelWanted(level, from)
  local mode = self:GzMode()
  if mode ~= "fives" and mode ~= "tens" then return true end
  local step = (mode == "tens") and 10 or 5
  local lo = from and (from + 1) or level
  for l = lo, level do
    if math.mod(l, step) == 0 then return true end
  end
  return false
end

-- ------------------------------------------------------------
-- GZ-Texte
-- ------------------------------------------------------------
function BB:GzDefault(i) return T("GZ_T" .. i) end

function BB:GzText(i)
  local t = G().texts[i]
  if t ~= nil then return t end
  return self:GzDefault(i)
end

function BB:GzPick()
  local list = {}
  for i = 1, TEXT_COUNT do
    local t = self:GzText(i)
    if t and t ~= "" then table.insert(list, t) end
  end
  local n = getn(list)
  if n == 0 then return "GZ {name}!" end
  local pick = math.random(n)
  if n > 1 and pick == self.lv.lastPick then pick = math.mod(pick, n) + 1 end
  self.lv.lastPick = pick
  return list[pick]
end

function BB:GzFill(text, name, level)
  text = string.gsub(text, "{name}", name or "")
  text = string.gsub(text, "{level}", tostring(level or ""))
  return text
end

function BB:SendGZ(name, level)
  local last = self.lv.latest
  name = name or (last and last.name)
  level = level or (last and last.level) or ""
  if not name then self:Print(T("LV_NONE")) return end
  if not IsInGuild() then return end
  SendChatMessage(self:GzFill(self:GzPick(), name, level), "GUILD")
end

-- ------------------------------------------------------------
-- Levelup erkannt
-- ------------------------------------------------------------
function BB:LevelUp(name, level, source, from)
  local lv = self.lv
  if not name or not level or level < 2 then return end
  if lv.done[name] and lv.done[name] >= level then return end
  lv.done[name] = level
  if (lv.last[name] or 0) < level then lv.last[name] = level end
  lv.latest = { name = name, level = level }
  if not self:LevelActive() then return end
  local isSelf = (name == self:Me())
  if level == 60 and self:GzSplash() then UI:LevelSplash(name) end
  if not isSelf and self:LevelWanted(level, from) then
    self:Print(string.format(T("LV_CHAT"), "|cffffd100" .. name .. "|r", level))
    UI:LevelToast(name, level)
  end
end

-- Vergleich mit der letzten Gildenliste (aus ReadRoster)
function BB:LevelScan()
  local lv = self.lv
  if not IsInGuild() or not GetNumGuildMembers then return end
  local n = GetNumGuildMembers(1) or 0
  if n <= 0 then return end
  local first = not lv.seeded
  local seen = {}
  for i = 1, n do
    local name, _, _, level = GetGuildRosterInfo(i)
    if name and level and level > 0 then
      seen[name] = true
      local old = lv.last[name]
      if old and level > old and not first then
        lv.last[name] = level
        self:LevelUp(name, level, "roster", old)
      elseif not old or level > old then
        lv.last[name] = level
      end
    end
  end
  -- wer nicht mehr in der Gilde ist, verliert seinen Stand: ein neu Eingeladener (oder jemand, der zurueckkommt)
  -- ist ein neues Mitglied mit seiner Stufe, kein Aufstieg
  for name in pairs(lv.last) do
    if not seen[name] then lv.last[name] = nil end
  end
  lv.seeded = true
end

-- Nachricht V~Name~Stufe von einem anderen Addon-Nutzer
function BB:OnLevelMessage(sender, msg)
  local _, _, who, lvl = string.find(msg, "^V~([^~]+)~(%d+)$")
  if not who or who ~= sender then return end
  self:LevelUp(who, tonumber(lvl), "msg")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function()
  local lvl = tonumber(arg1)
  if not lvl or not BB:Ready() then return end
  local me = BB:Me()
  if IsInGuild() then BB:Send("V~" .. me .. "~" .. lvl) end
  BB:LevelUp(me, lvl, "self")
end)

-- Gildenliste regelmaessig anfordern, damit Aufstiege auch ohne Addon beim Aufsteiger auffallen
local tick = CreateFrame("Frame")
local acc = 0
tick:SetScript("OnUpdate", function()
  acc = acc + arg1
  if acc < SCAN_EVERY then return end
  acc = 0
  if BB.worldReady and IsInGuild() and GuildRoster and BB:LevelActive() then GuildRoster() end
end)

-- ------------------------------------------------------------
-- Popup
-- ------------------------------------------------------------
local toast, toastQueue = nil, {}

local function sound()
  if PlaySoundFile then pcall(PlaySoundFile, "Sound\\Interface\\LevelUp.wav") end
end

local function toastNext()
  if getn(toastQueue) == 0 then toast:Hide() return end
  local item = table.remove(toastQueue, 1)
  toast.name, toast.level = item.name, item.level
  toast.text:SetText(string.format(T("LV_TOAST"), "|cffffd100" .. item.name .. "|r", item.level))
  toast.elapsed = 0
  toast:Show()
end

function UI:GzSetOff()
  G().on = false
  toastQueue = {}
  if toast then toast:Hide() end
  BB:Print(T("LV_OFF_MSG"))
  if self.set and self.set.cGz then self.set.cGz.Update() end
end

local function buildToast()
  toast = CreateFrame("Frame", "BananaBankLevelToast", UIParent)
  toast:SetWidth(390)
  toast:SetHeight(84)
  toast:SetPoint("TOP", UIParent, "TOP", 0, -170)
  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  toast:SetToplevel(true)
  toast:EnableMouse(true)
  toast:SetMovable(true)
  toast:RegisterForDrag("LeftButton")
  toast:SetScript("OnDragStart", function() this:StartMoving() end)
  toast:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  toast:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  toast:SetBackdropColor(0.03, 0.05, 0.13, 1)
  toast:SetBackdropBorderColor(0.9, 0.75, 0.2, 1)
  local icon = toast:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(MEDIA .. "GZLogo")
  icon:SetWidth(52)
  icon:SetHeight(52)
  icon:SetPoint("LEFT", toast, "LEFT", 10, 0)
  toast.text = UI:Font(toast, 13, C.text)
  toast.text:SetPoint("TOPLEFT", toast, "TOPLEFT", 72, -14)
  toast.text:SetWidth(308)
  toast.text:SetHeight(16)
  toast.text:SetJustifyH("LEFT")
  local gz = UI:Button(toast, 112, 22, "LV_BTN_GZ", function()
    BB:SendGZ(toast.name, toast.level)
    toastNext()
  end, "primary")
  gz:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 72, 12)
  local skip = UI:Button(toast, 78, 22, "LV_BTN_CLOSE", function() toastNext() end)
  skip:SetPoint("LEFT", gz, "RIGHT", 6, 0)
  local off = UI:Button(toast, 78, 22, "LV_BTN_OFF", function() UI:GzSetOff() end, "danger")
  off:SetPoint("LEFT", skip, "RIGHT", 6, 0)
  off:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(T("LV_OFF_TIP"), 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  off:SetScript("OnLeave", function() GameTooltip:Hide() end)
  toast.elapsed = 0
  toast:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + arg1
    if this.elapsed > 25 then toastNext() end
  end)
  toast:Hide()
end

function UI:LevelToast(name, level)
  if not toast then buildToast() end
  table.insert(toastQueue, { name = name, level = level })
  if not toast:IsVisible() then toastNext() end
  sound()
end

-- ------------------------------------------------------------
-- Stufe-60-Anzeige
-- ------------------------------------------------------------
local splash, splashQueue = nil, {}

local function splashNext()
  if getn(splashQueue) == 0 then splash:Hide() return end
  local name = table.remove(splashQueue, 1)
  splash.name = name
  splash.nameText:SetText(name)
  splash.sub:SetText(T("LV_SPLASH_SUB"))
  splash.elapsed = 0
  splash:SetAlpha(0)
  splash:Show()
  sound()
end

local function buildSplash()
  splash = CreateFrame("Frame", "BananaBankLevelSplash", UIParent)
  splash:SetWidth(520)
  splash:SetHeight(480)
  splash:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  splash:SetFrameStrata("FULLSCREEN_DIALOG")
  splash:EnableMouse(true)
  local logo = splash:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(MEDIA .. "GZLogo")
  logo:SetWidth(280)
  logo:SetHeight(280)
  logo:SetPoint("TOP", splash, "TOP", 0, 0)
  splash.nameText = splash:CreateFontString(nil, "OVERLAY")
  splash.nameText:SetFont(UI.FONT_TITLE, 44, "OUTLINE")
  splash.nameText:SetTextColor(1, 0.82, 0)
  splash.nameText:SetPoint("TOP", logo, "BOTTOM", 0, 0)
  splash.sub = splash:CreateFontString(nil, "OVERLAY")
  splash.sub:SetFont(UI.FONT, 24, "OUTLINE")
  splash.sub:SetTextColor(1, 1, 1)
  splash.sub:SetPoint("TOP", splash.nameText, "BOTTOM", 0, -6)
  local gz = UI:Button(splash, 140, 26, "LV_BTN_GZ", function() BB:SendGZ(splash.name, 60) end, "primary")
  gz:SetPoint("TOP", splash.sub, "BOTTOM", 0, -14)
  splash:SetScript("OnMouseUp", function() splashNext() end)
  splash.elapsed = 0
  splash:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + arg1
    local t = this.elapsed
    local a
    if t < 0.8 then a = t / 0.8
    elseif t < 8.8 then a = 1
    elseif t < 10.3 then a = 1 - (t - 8.8) / 1.5
    else splashNext() return end
    this:SetAlpha(a)
  end)
  splash:Hide()
end

function UI:LevelSplash(name)
  if not splash then buildSplash() end
  table.insert(splashQueue, name or "?")
  if not splash:IsVisible() then splashNext() end
end

-- ------------------------------------------------------------
-- Dialog: GZ-Texte anpassen
-- ------------------------------------------------------------
local ROWS, ROW_H = 8, 38

function UI:BuildGzTexts()
  if self.gzWin then return end
  local f = CreateFrame("Frame", "BananaBankGzTexts", UIParent)
  self.gzWin = f
  f:SetWidth(520)
  f:SetHeight(120 + ROWS * ROW_H + 40)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  -- ueber dem Einstellungsfenster (gleiche Ebene wuerde dessen Inhalt durchscheinen lassen)
  f:SetFrameStrata("TOOLTIP")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetBackdrop({
    bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(0.015, 0.025, 0.06, 1)
  self:Solid(f, 12, 1)
  f:Hide()
  tinsert(UISpecialFrames, "BananaBankGzTexts")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  local title = self:Font(f, 20, C.gold, UI.FONT_TITLE)
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -20)
  self:Loc(title, "GZ_TITLE")
  self:GlowLine(f, -50, 20, -20)
  local hint = self:Font(f, 10, C.muted)
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -58)
  hint:SetWidth(468)
  hint:SetHeight(28)
  hint:SetJustifyV("TOP")
  self:Loc(hint, "GZ_HINT")

  local sf = CreateFrame("ScrollFrame", "BananaBankGzScroll", f, "FauxScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -92)
  sf:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -50, -92 - ROWS * ROW_H)
  sf:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(ROW_H, function() UI:RefreshGzTexts() end)
  end)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function()
    local sb = getglobal("BananaBankGzScrollScrollBar")
    if sb then sb:SetValue(sb:GetValue() - arg1 * ROW_H) end
  end)
  f.sf = sf
  f.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(ROW_H - 4)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -92 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -64, -92 - (i - 1) * ROW_H)
    row.num = self:Font(row, 11, C.goldDim)
    row.num:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.num:SetWidth(24)
    row.num:SetJustifyH("RIGHT")
    row.box = self:EditBox("BananaBankGzEdit" .. i, row, 330)
    row.box:SetMaxLetters(TEXT_MAX)
    row.box:SetPoint("LEFT", row, "LEFT", 34, 0)
    row.box:SetScript("OnTextChanged", function()
      if this.loading or not this.idx then return end
      local txt = this:GetText() or ""
      local idx = this.idx
      if txt == BB:GzDefault(idx) then G().texts[idx] = nil else G().texts[idx] = txt end
    end)
    row.reset = self:Button(row, 46, 20, "GZ_ROW_RESET", function()
      if this:GetParent().box.idx then
        G().texts[this:GetParent().box.idx] = nil
        UI:RefreshGzTexts()
      end
    end, "flat")
    row.reset:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
    f.rows[i] = row
  end
  local all = self:Button(f, 160, 22, "GZ_RESET_ALL", function()
    G().texts = {}
    UI:RefreshGzTexts()
  end)
  all:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 22)
  local done = self:Button(f, 120, 22, "GZ_DONE", function() f:Hide() end, "primary")
  done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 22)
end

function UI:RefreshGzTexts()
  local f = self.gzWin
  if not f then return end
  FauxScrollFrame_Update(f.sf, TEXT_COUNT, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(f.sf)
  if type(offset) ~= "number" then offset = 0 end
  for i = 1, ROWS do
    local row = f.rows[i]
    local idx = offset + i
    row.box.loading = true
    row.box.idx = idx
    row.num:SetText(idx .. ".")
    row.box:SetText(BB:GzText(idx) or "")
    row.box:SetCursorPosition(0)
    row.box.loading = nil
  end
end

function UI:OpenGzTexts()
  self:BuildGzTexts()
  self.gzWin:Show()
  self:RefreshGzTexts()
end

-- Test: /bb gz test [60]
function UI:LevelTest(sixty)
  local me = BB:Me()
  if sixty then
    UI:LevelSplash(me)
  else
    UI:LevelToast(me, 40)
  end
end
