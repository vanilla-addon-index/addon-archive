-- pfUI Octo combat text: the stand-in for OctoBG's core.
--
-- The combat text engine (sct-engine.lua) and its message types
-- (sct-events.lua) come from the OctoBG addon (the user's own, combat text
-- since 14 Oct 2026) almost unchanged. They talk to "B" - OctoBG's core.
-- This file is that B for pfUI: an event bus (B:On / B:Fire), timers
-- (B:Every), printing, settings (B.db.sct = pfUI_config.sct, real Lua values,
-- set up by the "sct" module in sct.lua), and the few helpers they use
-- (U.GuidOf, U.Panel for the five text areas as pfUI movers, fonts).
-- OctoBG hands its combat text over when this one runs (pfUI.sct.running).

local B = { DEFAULTS = { sct = { events = {} } }, active = true, Tracker = { units = {} }, errors = {} }
pfUI.sctB = B
local U = {}
B.U = U

U.MEDIA = "Interface\\AddOns\\" .. (pfUI.name or "pfUI") .. "\\img\\sct\\"
U.PI = 3.14159265358979

-- ---------------------------------------------------------------- output

function B:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|rUI |cffaaaaaacombat text:|r " .. tostring(msg))
end

-- each error once (at most 30), as OctoBG did
local nerr = 0
function B:Error(err)
  err = tostring(err)
  if self.errors[err] or nerr >= 30 then return end
  self.errors[err] = true
  nerr = nerr + 1
  self:Print("|cffff5555error:|r " .. err)
end

-- ---------------------------------------------------------------- event bus

local frame = CreateFrame("Frame", "pfSCTCore")
local handlers = {}

function B:On(ev, fn)
  if not handlers[ev] then
    handlers[ev] = {}
    -- internal messages share the bus; their names start with OBG_
    -- (guarded: an event this client or its DLLs lack must not stop the file)
    if string.sub(ev, 1, 4) ~= "OBG_" then pcall(frame.RegisterEvent, frame, ev) end
  end
  table.insert(handlers[ev], fn)
end

local function Dispatch(ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
  local list = handlers[ev]
  if not list or not B.db then return end   -- nothing runs before the settings exist
  for i = 1, table.getn(list) do
    local ok, err = pcall(list[i], ev, a1, a2, a3, a4, a5, a6, a7, a8, a9)
    if not ok then B:Error(err) end
  end
end
B.Dispatch = Dispatch

frame:SetScript("OnEvent", function()
  Dispatch(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
end)

function B:Fire(msg, a1, a2, a3, a4)
  Dispatch(msg, a1, a2, a3, a4)
end

-- ---------------------------------------------------------------- timers

local tickers = {}
function B:Every(interval, fn)
  table.insert(tickers, { iv = interval, t = 0, fn = fn })
end

frame:SetScript("OnUpdate", function()
  if not B.db then return end
  local e = arg1 or 0
  for i = 1, table.getn(tickers) do
    local tk = tickers[i]
    tk.t = tk.t + e
    if tk.t >= tk.iv then
      tk.t = 0
      local ok, err = pcall(tk.fn)
      if not ok then B:Error(err) end
    end
  end
end)

-- ---------------------------------------------------------------- GUIDs

-- GUID of a unit token: nampower's GetUnitGUID, else SuperWoW's UnitExists
function U.GuidOf(unit)
  if not unit then return nil end
  if GetUnitGUID then
    local g = GetUnitGUID(unit)
    if g then return g end
  end
  local _, g = UnitExists(unit)
  if type(g) == "string" then return g end
  return nil
end

function U.IsGuid(g)
  return type(g) == "string" and string.find(g, "^0[xX]%x+$") ~= nil
end

function U.GuidExists(guid)
  if not U.IsGuid(guid) then return false end
  if GetUnitGUID then return GetUnitGUID(guid) ~= nil end
  return UnitExists(guid) and true or false
end

-- ---------------------------------------------------------------- fonts

-- a font path that loads, else the fallback (OctoBG's SpyData.Font)
local probe, fontOK = nil, {}
local function FontOK(path)
  if not path or path == "" then return false end
  if fontOK[path] ~= nil then return fontOK[path] end
  if not probe then probe = UIParent:CreateFontString(nil, "OVERLAY") end
  probe:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  probe:SetFont(path, 12, "")
  local now = probe:GetFont()
  local function N(s) return string.lower(string.gsub(s or "", "/", "\\")) end
  local ok = type(now) == "string" and N(now) == N(path)
  fontOK[path] = ok
  return ok
end
B.SpyData = { Font = function(path, fallback)
  if FontOK(path) then return path end
  if FontOK(fallback) then return fallback end
  return pfUI.font_default or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end }

-- ---------------------------------------------------------------- areas as pfUI movers

-- The five text areas: plain frames placed by the engine (CT:PlaceArea, by
-- their centre), registered as pfUI movers so /moveui drags them. pfUI's
-- layout mode calls frame:OnMove() after a drop: the engine's afterMove reads
-- the new centre back into the area's x / y.
B.panelNames = {}
function U.Panel(name, key, label, w, h, defPoint, defX, defY)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(w)
  f:SetHeight(h)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f.key, f.defPoint, f.defX, f.defY, f.label = key, defPoint, defX, defY, label or key
  f:SetPoint(defPoint, UIParent, defPoint, defX, defY)
  f.OnMove = function(self) if self.afterMove then self.afterMove(self) end end
  B.panelNames[key] = name
  return f
end
